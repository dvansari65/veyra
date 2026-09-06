// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;
import { Test } from "forge-std/Test.sol";
import { BaseTest } from "../Base.t.sol";
import { ReservationManager } from "../../src/ReservationManager.sol";
import { DemoLendingMarket } from "../../src/DemoLendingMarket.sol";
import { ILendingAdapter } from "../../src/interfaces/ILendingAdapter.sol";
import { MockToken } from "../../src/mocks/MockToken.sol";
import { MockFeed } from "../../src/mocks/MockFeed.sol";

/// @dev A bounded state machine. Preconditions avoid expected reverts; unexpected reverts fail the campaign.
contract Handler is Test {
    ReservationManager public core;
    DemoLendingMarket[2] public markets;
    uint256[2] public offers;
    uint256[2] public secondOffers;
    MockToken public usd;
    MockFeed public cf;
    MockFeed public df;
    address public buyer;
    address public secondBuyer;
    address public borrower;
    address public lender;
    uint256 public deposited = 200_000e6;
    uint256 public withdrawn;
    uint256 public spent;
    uint256 public loansOpened;
    mapping(address => uint256) public depositsBy;
    mapping(address => uint256) public withdrawalsBy;
    mapping(address => uint256) public spendBy;

    struct Ref {
        uint256 marketIndex;
        uint256 id;
        bytes32 key;
        address buyer;
        uint256 allocation;
        uint256 principal;
    }
    Ref[] internal refs;

    constructor(
        ReservationManager c,
        DemoLendingMarket a,
        DemoLendingMarket b,
        uint256 oa,
        uint256 ob,
        MockToken u,
        MockFeed f1,
        MockFeed f2,
        address buy,
        address borrow_,
        address lend
    ) {
        core = c;
        markets = [a, b];
        offers = [oa, ob];
        usd = u;
        cf = f1;
        df = f2;
        buyer = buy;
        secondBuyer = makeAddr("second invariant buyer");
        borrower = borrow_;
        lender = lend;
        depositsBy[buyer] = 100_000e6;
        depositsBy[secondBuyer] = 100_000e6;
        usd.mint(secondBuyer, 100_000e6);
        vm.startPrank(secondBuyer);
        usd.approve(address(core), type(uint256).max);
        core.deposit(100_000e6);
        secondOffers[0] =
            core.createOffer(address(a.adapter()), 100_000e6, block.timestamp + 365 days, 366 days, 500, 100);
        secondOffers[1] =
            core.createOffer(address(b.adapter()), 100_000e6, block.timestamp + 365 days, 366 days, 500, 100);
        vm.stopPrank();
    }

    function deposit(uint256 raw) external {
        uint256 amount = bound(raw, 1, 10_000e6);
        address actor = raw % 2 == 0 ? buyer : secondBuyer;
        usd.mint(actor, amount);
        vm.prank(actor);
        core.deposit(amount);
        deposited += amount;
        depositsBy[actor] += amount;
    }

    function withdraw(uint256 raw) external {
        address actor = raw % 2 == 0 ? buyer : secondBuyer;
        uint256 available = core.available(actor);
        if (available == 0) return;
        uint256 amount = bound(raw, 1, available);
        vm.prank(actor);
        core.withdraw(amount);
        withdrawn += amount;
        withdrawalsBy[actor] += amount;
    }

    function advance(uint256 raw, uint256 price) external {
        vm.warp(block.timestamp + bound(raw, 0, 3 days));
        cf.set(int256(bound(price, 1e8, 150e8)), block.timestamp);
        df.set(1e8, block.timestamp);
    }

    function borrow(uint256 marketRaw, uint256 raw) external {
        if (refs.length >= 100 || block.timestamp >= 1_000_000 + 365 days) return;
        uint256 index = marketRaw % 2;
        address actor = marketRaw / 2 % 2 == 0 ? buyer : secondBuyer;
        DemoLendingMarket m = markets[index];
        uint256 principal = bound(raw, 1e6, 10_000e6);
        uint256 allocation = m.maximumDebt(principal);
        if (principal > m.liquidity() || allocation > core.available(actor)) return;
        cf.set(100e8, block.timestamp);
        df.set(1e8, block.timestamp);
        vm.prank(borrower);
        uint256 id = m.borrow(
            1_000e18, principal, 1 days, actor == buyer ? offers[index] : secondOffers[index], 1_000e6
        );
        refs.push(Ref(index, id, core.key(address(m.adapter()), id), actor, allocation, principal));
        loansOpened++;
    }

    function repay(uint256 raw) external {
        if (refs.length == 0) return;
        Ref memory r = refs[raw % refs.length];
        DemoLendingMarket m = markets[r.marketIndex];
        if (!m.loanView(r.id).active) return;
        usd.mint(borrower, m.currentDebt(r.id));
        vm.prank(borrower);
        m.repay(r.id);
    }

    function expire(uint256 raw) external {
        if (refs.length == 0) return;
        Ref memory r = refs[raw % refs.length];
        if (core.state(r.key) != ReservationManager.State.Active || block.timestamp < core.expiryOf(r.key)) {
            return;
        }
        core.expire(r.key);
    }

    function settle(uint256 raw) external {
        if (refs.length == 0) return;
        Ref memory r = refs[raw % refs.length];
        if (core.state(r.key) != ReservationManager.State.Active || block.timestamp >= core.expiryOf(r.key)) {
            return;
        }
        ILendingAdapter.LoanView memory l = markets[r.marketIndex].loanView(r.id);
        cf.set(cf.answer(), block.timestamp);
        df.set(1e8, block.timestamp);
        if (
            block.timestamp < l.maturity && l.debt <= core.oracle().value(l.collateralAmount) * 8_000 / 10_000
        ) return;
        (uint256 payment,) = core.settle(r.key);
        spent += payment;
        spendBy[r.buyer] += payment;
    }

    function recover(uint256 raw) external {
        if (refs.length == 0) return;
        Ref memory r = refs[raw % refs.length];
        if (!markets[r.marketIndex].loanView(r.id).active || block.timestamp < core.expiryOf(r.key)) return;
        vm.prank(lender);
        markets[r.marketIndex].recoverUncovered(r.id);
    }

    function allocationSum(address actor) external view returns (uint256 sum) {
        for (uint256 i; i < refs.length; ++i) {
            Ref memory r = refs[i];
            if (
                (actor == address(0) || r.buyer == actor)
                    && core.state(r.key) == ReservationManager.State.Active
            ) {
                sum += r.allocation;
            }
        }
    }

    function principalSum(uint256 marketIndex) external view returns (uint256 sum) {
        for (uint256 i; i < refs.length; ++i) {
            Ref memory r = refs[i];
            if (r.marketIndex == marketIndex && markets[marketIndex].loanView(r.id).active) {
                sum += r.principal;
            }
        }
    }

    /// @dev Surplus tokens must not create a buyer balance or a lender withdrawal entitlement.
    function donate(uint256 raw) external {
        uint256 amount = bound(raw, 1, 1_000e6);
        usd.mint(address(this), amount);
        require(usd.transfer(address(core), amount));
        DemoLendingMarket m = markets[raw % 2];
        MockToken c = MockToken(address(m.collateralToken()));
        c.mint(address(this), 1e18);
        require(c.transfer(address(m), 1e18));
    }

    function collateralSum(uint256 marketIndex) external view returns (uint256 sum) {
        for (uint256 i; i < refs.length; ++i) {
            Ref memory r = refs[i];
            if (r.marketIndex == marketIndex) sum += markets[marketIndex].loanView(r.id).collateralAmount;
        }
    }
}

contract CustodyInvariantTest is BaseTest {
    Handler internal handler;

    function setUp() public override {
        super.setUp();
        handler = new Handler(core, market, marketB, offer, offerB, usd, cf, df, buyer, borrower, lender);
        targetContract(address(handler));
        bytes4[] memory selectors = new bytes4[](9);
        selectors[0] = Handler.deposit.selector;
        selectors[1] = Handler.withdraw.selector;
        selectors[2] = Handler.advance.selector;
        selectors[3] = Handler.borrow.selector;
        selectors[4] = Handler.repay.selector;
        selectors[5] = Handler.expire.selector;
        selectors[6] = Handler.settle.selector;
        selectors[7] = Handler.recover.selector;
        selectors[8] = Handler.donate.selector;
        targetSelector(FuzzSelector(address(handler), selectors));
    }

    function invariantCustodyCoversAllLiabilities() public view {
        assertGe(usd.balanceOf(address(core)), core.totalAvailable() + core.totalReserved());
        address secondBuyer = handler.secondBuyer();
        assertEq(core.totalAvailable(), core.available(buyer) + core.available(secondBuyer));
        assertEq(core.totalReserved(), core.reserved(buyer) + core.reserved(secondBuyer));
        assertGe(usd.balanceOf(address(market)), market.liquidity());
    }

    function invariantAllocationSumMatchesExclusiveReservations() public view {
        assertEq(handler.allocationSum(address(0)), core.totalReserved());
        assertEq(handler.allocationSum(buyer), core.reserved(buyer));
        assertEq(handler.allocationSum(handler.secondBuyer()), core.reserved(handler.secondBuyer()));
    }

    function invariantConservationOfBuyerCapital() public view {
        assertEq(
            core.totalAvailable() + core.totalReserved(),
            handler.deposited() - handler.withdrawn() - handler.spent()
        );
        assertLe(core.totalReserved(), handler.deposited() - handler.withdrawn() - handler.spent());
        assertBuyerConservation(buyer);
        assertBuyerConservation(handler.secondBuyer());
    }

    function assertBuyerConservation(address actor) internal view {
        assertEq(
            core.available(actor) + core.reserved(actor),
            handler.depositsBy(actor) - handler.withdrawalsBy(actor) - handler.spendBy(actor)
        );
    }

    function invariantBorrowerCollateralFullyBacked() public view {
        assertGe(hype.balanceOf(address(market)), handler.collateralSum(0));
        assertGe(hype.balanceOf(address(marketB)), handler.collateralSum(1));
        assertGe(usd.balanceOf(address(marketB)), marketB.liquidity());
    }

    function invariantOutstandingPrincipalMatchesActiveLoans() public view {
        assertEq(market.outstandingPrincipal(), handler.principalSum(0));
        assertEq(marketB.outstandingPrincipal(), handler.principalSum(1));
    }
}
