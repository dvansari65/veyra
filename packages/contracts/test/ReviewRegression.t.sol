// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { BaseTest } from "./Base.t.sol";
import { ILendingAdapter } from "../src/interfaces/ILendingAdapter.sol";
import { ReservationManager } from "../src/ReservationManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @dev Simulates an upgradeable integration changing its advertised pointers after a buyer signs up.
contract MutableIntegration is ILendingAdapter {
    address public market;
    address public core;
    address public oracle;
    address public debtAsset;
    address public collateral;
    ReservationManager private immutable actualCore;
    LoanView private snapshot;

    constructor(ReservationManager c) {
        actualCore = c;
        market = address(this);
        core = address(c);
        oracle = address(c.oracle());
        debtAsset = address(c.debtToken());
        collateral = address(c.collateralToken());
        snapshot = LoanView(address(123), 100e18, 5_000e6, 5_250e6, block.timestamp + 30 days, true);
    }

    function changePointer(uint256 field, address replacement) external {
        if (field == 0) market = replacement;
        else if (field == 1) core = replacement;
        else if (field == 2) oracle = replacement;
        else if (field == 3) debtAsset = replacement;
        else collateral = replacement;
    }

    function accept(uint256 offerId) external {
        actualCore.debtToken().approve(address(actualCore), type(uint256).max);
        actualCore.reserve(offerId, 1, type(uint256).max);
    }

    function setSnapshot(LoanView calldata l) external {
        snapshot = l;
    }

    function release() external {
        actualCore.release(1);
    }

    function loan(uint256) external view returns (LoanView memory) {
        return snapshot;
    }

    function execute(uint256, address buyer, uint256 amount, uint256) external {
        require(msg.sender == address(actualCore));
        snapshot.active = false;
        snapshot.debt = 0;
        snapshot.collateralAmount = 0;
        require(actualCore.collateralToken().transfer(buyer, amount));
    }
}

contract ReviewRegressionTest is BaseTest {
    bytes4 private constant INVALID_INTEGRATION = bytes4(keccak256("InvalidIntegration()"));
    MutableIntegration private integration;
    uint256 private customOffer;
    bytes32 private reservationKey;

    function setUp() public override {
        super.setUp();
        integration = new MutableIntegration(core);
        usd.mint(address(integration), 1_000e6);
        hype.mint(address(integration), 100e18);
        vm.prank(buyer);
        customOffer =
            core.createOffer(address(integration), 10_000e6, block.timestamp + 90 days, 90 days, 500, 100);
        reservationKey = core.key(address(integration), 1);
    }

    function testFuzzChangedIntegrationRejectedBeforeAcceptance(uint8 rawField) public {
        integration.changePointer(uint256(rawField) % 5, outsider);
        vm.expectRevert(INVALID_INTEGRATION);
        integration.accept(customOffer);
        assertEq(core.reserved(buyer), 0);
        assertEq(core.totalFees(), 0);
    }

    function testFuzzChangedIntegrationCannotSettleAcceptedTerms(uint8 rawField) public {
        integration.accept(customOffer);
        integration.changePointer(uint256(rawField) % 5, outsider);
        atMaturity();
        vm.expectRevert(INVALID_INTEGRATION);
        core.settle(reservationKey);
        assertEq(usd.balanceOf(outsider), 0);
        assertEq(core.reserved(buyer), 5_250e6);
        assertTrue(integration.loan(1).active);
    }

    function testReleaseRejectsOutstandingCollateralSnapshot() public {
        integration.accept(customOffer);
        ILendingAdapter.LoanView memory l = integration.loan(1);
        l.active = false;
        l.debt = 0;
        integration.setSnapshot(l);
        vm.expectRevert(ReservationManager.InvalidLoan.selector);
        integration.release();
        assertEq(core.reserved(buyer), 5_250e6);
    }

    function testConfigurationChangeDoesNotBlockRepaidRelease() public {
        integration.accept(customOffer);
        integration.changePointer(0, outsider);
        ILendingAdapter.LoanView memory l = integration.loan(1);
        l.active = false;
        l.debt = 0;
        l.collateralAmount = 0;
        integration.setSnapshot(l);
        vm.warp(block.timestamp + 2 hours); // Feeds stale; release must not consult price/configuration.
        integration.release();
        assertEq(core.reserved(buyer), 0);
    }

    function testConfigurationChangeDoesNotBlockExpiry() public {
        integration.accept(customOffer);
        integration.changePointer(0, outsider);
        vm.warp(core.expiryOf(reservationKey));
        core.expire(reservationKey);
        assertEq(core.reserved(buyer), 0);
        assertTrue(integration.loan(1).active);
    }

    function testRestoredConfigurationAllowsOriginalSettlement() public {
        integration.accept(customOffer);
        integration.changePointer(0, outsider);
        integration.changePointer(0, address(integration));
        atMaturity();
        uint256 beforeMarket = usd.balanceOf(address(integration));
        (uint256 payment, uint256 amount) = core.settle(reservationKey);
        assertEq(usd.balanceOf(address(integration)), beforeMarket + payment);
        assertEq(hype.balanceOf(buyer), amount);
        assertEq(usd.balanceOf(outsider), 0);
    }
}
