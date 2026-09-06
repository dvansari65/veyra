// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;
import { BaseTest } from "./Base.t.sol";
import { MockToken } from "../src/mocks/MockToken.sol";
import { ExactTransfer } from "../src/libraries/ExactTransfer.sol";
import { ReservationManager } from "../src/ReservationManager.sol";
import { ILendingAdapter } from "../src/interfaces/ILendingAdapter.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract CallbackToken is MockToken {
    address public target;
    bytes public data;
    bool public callbackSucceeded;
    bytes public callbackResult;
    uint256 public attempts;
    bool private busy;
    address public blockedRecipient;
    bool public taxed;
    constructor(uint8 d) MockToken("Adversarial test token", "EVIL", d) { }

    function arm(address target_, bytes calldata data_) external {
        target = target_;
        data = data_;
    }

    function blockRecipient(address who) external {
        blockedRecipient = who;
    }

    function setTax(bool on) external {
        taxed = on;
    }

    function _update(address from, address to, uint256 amount) internal override {
        require(to != blockedRecipient || to == address(0), "blocked delivery");
        super._update(from, to, amount);
        if (from != address(0) && to != address(0) && taxed && amount > 0) super._update(to, address(0), 1);
        if (from != address(0) && target != address(0) && !busy) {
            busy = true;
            attempts++;
            (callbackSucceeded, callbackResult) = target.call(data);
            busy = false;
        }
    }
}

/// @dev Deliberately dishonest integration; it cannot affect buyers who have not selected it.
contract DishonestAdapter is ILendingAdapter {
    address public immutable market;
    address public immutable core;
    address public immutable oracle;
    address public immutable debtAsset;
    address public immutable collateral;
    LoanView internal snapshot;
    bool public callbackSucceeded;
    bytes public callback;
    bool public deliver;

    constructor(ReservationManager c) {
        market = address(this);
        core = address(c);
        oracle = address(c.oracle());
        debtAsset = address(c.debtToken());
        collateral = address(c.collateralToken());
        snapshot = LoanView(address(123), 100e18, 5_000e6, 5_250e6, block.timestamp + 30 days, true);
    }

    function accept(uint256 offer, uint256 id) external {
        IERC20(debtAsset).approve(core, type(uint256).max);
        ReservationManager(core).reserve(offer, id, type(uint256).max);
    }

    function release(uint256 id) external {
        ReservationManager(core).release(id);
    }

    function loan(uint256) external view returns (LoanView memory) {
        return snapshot;
    }

    function setLoan(LoanView calldata l) external {
        snapshot = l;
    }

    function arm(bytes calldata data, bool deliver_) external {
        callback = data;
        deliver = deliver_;
    }

    function execute(uint256, address buyer_, uint256 amount, uint256) external {
        require(msg.sender == core);
        if (callback.length > 0) (callbackSucceeded,) = core.call(callback);
        snapshot.active = false;
        snapshot.debt = 0;
        snapshot.collateralAmount = 0;
        if (deliver) IERC20(collateral).transfer(buyer_, amount);
    }
}

contract AdversarialTest is BaseTest {
    function newDebtToken() internal override returns (MockToken) {
        return new CallbackToken(6);
    }

    function newCollateralToken() internal override returns (MockToken) {
        return new CallbackToken(18);
    }

    function testDepositAndWithdrawalCallbacksCannotReenterCore() public {
        usd.mint(buyer, 100e6);
        CallbackToken(address(usd)).arm(address(core), abi.encodeCall(core.deposit, (1)));
        vm.prank(buyer);
        core.deposit(100e6);
        assertFalse(CallbackToken(address(usd)).callbackSucceeded());
        assertEq(
            CallbackToken(address(usd)).callbackResult(),
            abi.encodeWithSelector(ReentrancyGuard.ReentrancyGuardReentrantCall.selector)
        );
        assertEq(CallbackToken(address(usd)).attempts(), 1);
        CallbackToken(address(usd)).arm(address(core), abi.encodeCall(core.withdraw, (1)));
        vm.prank(buyer);
        core.withdraw(100e6);
        assertFalse(CallbackToken(address(usd)).callbackSucceeded());
        assertEq(
            CallbackToken(address(usd)).callbackResult(),
            abi.encodeWithSelector(ReentrancyGuard.ReentrancyGuardReentrantCall.selector)
        );
        assertCustody();
    }

    function testTaxedDepositRejectedWithoutCrediting() public {
        CallbackToken(address(usd)).setTax(true);
        usd.mint(buyer, 100e6);
        vm.prank(buyer);
        vm.expectRevert(ExactTransfer.InexactTransfer.selector);
        core.deposit(100e6);
        assertEq(core.available(buyer), 100_000e6);
        assertCustody();
    }

    function testTaxedCollateralAndFeeRejectedAtomically() public {
        CallbackToken(address(hype)).setTax(true);
        vm.prank(borrower);
        vm.expectRevert(ExactTransfer.InexactTransfer.selector);
        market.borrow(100e18, 5_000e6, 30 days, offer, 100e6);
        CallbackToken(address(hype)).setTax(false);
        CallbackToken(address(usd)).setTax(true);
        vm.prank(borrower);
        vm.expectRevert(ExactTransfer.InexactTransfer.selector);
        market.borrow(100e18, 5_000e6, 30 days, offer, 100e6);
        assertEq(core.reserved(buyer), 0);
        assertEq(core.totalFees(), 0);
        assertEq(hype.balanceOf(address(market)), 0);
    }

    function testRevertingBuyerDeliveryRollsBackPaymentAndAllStates() public {
        (uint256 id, bytes32 k) = open();
        refresh(40e8);
        CallbackToken(address(hype)).blockRecipient(buyer);
        vm.expectRevert("blocked delivery");
        core.settle(k);
        assertTrue(market.loanView(id).active);
        assertEq(uint256(core.state(k)), uint256(ReservationManager.State.Active));
        assertEq(core.reserved(buyer), 5_250e6);
        assertEq(market.liquidity(), 95_000e6);
        assertEq(usd.balanceOf(address(market)), 95_000e6);
        assertEq(market.totalBadDebt(), 0);
        assertCustody();
    }

    function testRevertingSurplusReturnRollsBackBuyerDelivery() public {
        (, bytes32 k) = open();
        atMaturity();
        CallbackToken(address(hype)).blockRecipient(borrower);
        vm.expectRevert("blocked delivery");
        core.settle(k);
        assertEq(hype.balanceOf(buyer), 0);
        assertEq(core.reserved(buyer), 5_250e6);
        assertCustody();
    }

    function testSettlementCallbacksCannotRepayOrSettleTwice() public {
        (uint256 id, bytes32 k) = open();
        atMaturity();
        CallbackToken(address(usd)).arm(address(core), abi.encodeCall(core.settle, (k)));
        CallbackToken(address(hype)).arm(address(market), abi.encodeCall(market.repay, (id)));
        core.settle(k);
        assertFalse(CallbackToken(address(usd)).callbackSucceeded());
        assertFalse(CallbackToken(address(hype)).callbackSucceeded());
        assertEq(
            CallbackToken(address(usd)).callbackResult(),
            abi.encodeWithSelector(ReentrancyGuard.ReentrancyGuardReentrantCall.selector)
        );
        assertEq(
            CallbackToken(address(hype)).callbackResult(),
            abi.encodeWithSelector(ReentrancyGuard.ReentrancyGuardReentrantCall.selector)
        );
        assertGt(CallbackToken(address(hype)).attempts(), 0);
        assertCustody();
    }

    function testRepaymentCallbackCannotSettle() public {
        (uint256 id, bytes32 k) = open();
        atMaturity();
        CallbackToken(address(usd)).arm(address(core), abi.encodeCall(core.settle, (k)));
        vm.prank(borrower);
        market.repay(id);
        assertFalse(CallbackToken(address(usd)).callbackSucceeded());
        assertEq(uint256(core.state(k)), uint256(ReservationManager.State.Repaid));
        assertCustody();
    }

    function testBuyerCanAlsoBeBorrowerAndReceiveSurplus() public {
        hype.mint(buyer, 100e18);
        usd.mint(buyer, 100e6);
        vm.startPrank(buyer);
        hype.approve(address(market), type(uint256).max);
        usd.approve(address(market), type(uint256).max);
        uint256 id = market.borrow(100e18, 5_000e6, 30 days, offer, 100e6);
        vm.stopPrank();
        atMaturity();
        core.settle(core.key(address(market.adapter()), id));
        assertEq(hype.balanceOf(buyer), 100e18);
        assertCustody();
    }

    function makeDishonest() internal returns (DishonestAdapter a, uint256 o) {
        a = new DishonestAdapter(core);
        usd.mint(address(a), 1_000e6);
        vm.prank(buyer);
        o = core.createOffer(address(a), 10_000e6, block.timestamp + 90 days, 90 days, 500, 100);
    }

    function testDishonestAdapterCannotUseAnotherAdaptersOffer() public {
        (DishonestAdapter a,) = makeDishonest();
        vm.expectRevert(ReservationManager.Unauthorized.selector);
        a.accept(offer, 1);
        assertEq(core.reserved(buyer), 0);
    }

    function testDishonestDeliveryAndDuplicateLoanRevert() public {
        (DishonestAdapter a, uint256 o) = makeDishonest();
        a.accept(o, 1);
        bytes32 k = core.key(address(a), 1);
        vm.expectRevert(ReservationManager.InvalidLoan.selector);
        a.accept(o, 1);
        vm.expectRevert(ReservationManager.InvalidLoan.selector);
        a.release(1);
        atMaturity();
        vm.expectRevert(ReservationManager.DeliveryFailed.selector);
        core.settle(k);
        assertEq(core.reserved(buyer), 5_250e6);
        assertEq(usd.balanceOf(address(a)), 1_000e6 - 52_500_000);
        assertCustody();
    }

    function testAdapterCallbackCannotMutateCoreDuringSettlement() public {
        open();
        (DishonestAdapter a, uint256 o) = makeDishonest();
        a.accept(o, 1);
        bytes32 k = core.key(address(a), 1);
        hype.mint(address(a), 100e18);
        a.arm(
            abi.encodeCall(
                core.createOffer,
                (address(a), 10_000e6, block.timestamp + 90 days, 90 days, uint16(500), uint16(100))
            ),
            true
        );
        atMaturity();
        core.settle(k);
        assertFalse(a.callbackSucceeded());
        assertEq(core.reserved(buyer), 5_250e6);
        assertCustody();
    }

    function testImmutableSnapshotDebtBorrowerAndMaturity() public {
        (DishonestAdapter a, uint256 o) = makeDishonest();
        a.accept(o, 1);
        bytes32 k = core.key(address(a), 1);
        ILendingAdapter.LoanView memory l = a.loan(1);
        l.debt = l.maxDebt + 1;
        a.setLoan(l);
        vm.expectRevert(ReservationManager.InvalidLoan.selector);
        core.settle(k);
        l.debt = 5_000e6;
        l.maturity -= 1;
        a.setLoan(l);
        vm.expectRevert(ReservationManager.InvalidLoan.selector);
        core.settle(k);
        l.maturity += 1;
        l.borrower = outsider;
        a.setLoan(l);
        vm.expectRevert(ReservationManager.InvalidLoan.selector);
        core.settle(k);
    }

    function testNoThirdPartyAllowanceChargedByUntrustedAdapter() public {
        (DishonestAdapter a, uint256 o) = makeDishonest();
        deal(address(usd), address(a), 0);
        vm.prank(borrower);
        usd.approve(address(core), type(uint256).max);
        uint256 beforeBalance = usd.balanceOf(borrower);
        vm.expectRevert();
        a.accept(o, 1);
        assertEq(usd.balanceOf(borrower), beforeBalance);
        assertEq(core.reserved(buyer), 0);
    }
}
