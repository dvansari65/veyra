// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;
import { BaseTest } from "./Base.t.sol";
import { BuyerVault } from "../src/BuyerVault.sol";
import { ReservationManager } from "../src/ReservationManager.sol";
import { DemoLendingMarket } from "../src/DemoLendingMarket.sol";
import { ReferenceLendingAdapter } from "../src/ReferenceLendingAdapter.sol";
import { PriceOracle } from "../src/PriceOracle.sol";
import { ILendingAdapter } from "../src/interfaces/ILendingAdapter.sol";

contract LifecycleTest is BaseTest {
    function testLoanUsesLenderFundsAndFeeIsSeparate() public {
        uint256 beforeBorrower = usd.balanceOf(borrower);
        (uint256 id,) = open();
        assertEq(market.currentDebt(id), 5_000e6);
        assertEq(core.reserved(buyer), 5_250e6);
        assertEq(core.available(buyer), 94_750e6);
        assertEq(usd.balanceOf(address(core)), 100_000e6);
        assertEq(usd.balanceOf(buyer), 52_500_000);
        assertEq(core.feesEarned(buyer), 52_500_000);
        assertEq(core.totalFees(), 52_500_000);
        assertEq(usd.balanceOf(borrower), beforeBorrower + 5_000e6 - 52_500_000);
        assertEq(market.liquidity(), 95_000e6);
        assertEq(hype.balanceOf(address(market)), 100e18);
        assertEq(usd.allowance(address(market.adapter()), address(core)), 0);
        assertCustody();
    }

    function testCrossMarketOverbookingRevertsEntireLoan() public {
        vm.prank(borrower);
        market.borrow(2_000e18, 66_666e6, 30 days, offer, 1_000e6);
        uint256 beforeCollateral = hype.balanceOf(borrower);
        uint256 beforeUSD = usd.balanceOf(borrower);
        uint256 beforeFees = core.totalFees();
        vm.prank(borrower);
        vm.expectRevert(BuyerVault.InsufficientAvailable.selector);
        marketB.borrow(1_000e18, 38_095e6, 30 days, offerB, 1_000e6);
        assertEq(marketB.nextLoanId(), 1);
        assertEq(marketB.outstandingPrincipal(), 0);
        assertEq(marketB.liquidity(), 100_000e6);
        assertEq(hype.balanceOf(borrower), beforeCollateral);
        assertEq(usd.balanceOf(borrower), beforeUSD);
        assertEq(core.totalFees(), beforeFees);
        assertEq(usd.balanceOf(address(marketB.adapter())), 0);
        assertCustody();
    }

    function testSameLoanNumberDifferentMarketsIndependent() public {
        (, bytes32 ka) = open();
        vm.prank(borrower);
        uint256 id = marketB.borrow(100e18, 5_000e6, 30 days, offerB, 100e6);
        bytes32 kb = core.key(address(marketB.adapter()), id);
        assertTrue(ka != kb);
        assertEq(core.reserved(buyer), 10_500e6);
        assertCustody();
    }

    function testWithdrawOnlyAvailable() public {
        open();
        vm.startPrank(buyer);
        vm.expectRevert(BuyerVault.InsufficientAvailable.selector);
        core.withdraw(94_750e6 + 1);
        core.withdraw(94_750e6);
        vm.stopPrank();
        assertEq(usd.balanceOf(address(core)), 5_250e6);
        assertCustody();
    }

    function testCancelDoesNotReleaseActiveReservation() public {
        (, bytes32 k) = open();
        vm.prank(buyer);
        core.cancelOffer(offer);
        assertEq(uint256(core.state(k)), uint256(ReservationManager.State.Active));
        assertEq(core.reserved(buyer), 5_250e6);
        vm.prank(borrower);
        vm.expectRevert(ReservationManager.InvalidTerms.selector);
        market.borrow(100e18, 5_000e6, 30 days, offer, 100e6);
        refresh(50e8);
        core.settle(k);
        assertCustody();
    }

    function testRepayWithoutFreshPriceReleasesAndReturnsCollateral() public {
        (uint256 id, bytes32 k) = open();
        vm.warp(block.timestamp + 15 days);
        assertEq(market.currentDebt(id), 5_125e6);
        vm.prank(borrower);
        market.repay(id);
        assertEq(hype.balanceOf(borrower), 100_000e18);
        assertEq(core.available(buyer), 100_000e6);
        assertEq(core.reserved(buyer), 0);
        assertEq(core.feesEarned(buyer), 52_500_000);
        assertEq(market.liquidity(), 100_125e6);
        assertEq(uint256(core.state(k)), uint256(ReservationManager.State.Repaid));
        vm.expectRevert(ReservationManager.Inactive.selector);
        core.settle(k);
        assertCustody();
    }

    function testHealthyCannotSettleAndMaturityCan() public {
        (, bytes32 k) = open();
        vm.expectRevert(ReservationManager.NotLiquidatable.selector);
        core.settle(k);
        atMaturity();
        (uint256 payment, uint256 amount) = core.settle(k);
        assertEq(payment, 5_250e6);
        assertEq(amount, (payment * 1e18 + 95e6 - 1) / 95e6);
        assertEq(hype.balanceOf(buyer), amount);
        assertEq(hype.balanceOf(borrower), 100_000e18 - amount);
        assertEq(market.totalBadDebt(), 0);
        assertEq(market.outstandingPrincipal(), 0);
        assertCustody();
    }

    function testUnderwaterShortfallAndDuplicateSettlement() public {
        (uint256 id, bytes32 k) = open();
        refresh(40e8);
        (uint256 payment, uint256 amount) = core.settle(k);
        assertEq(payment, 3_800e6);
        assertEq(amount, 100e18);
        assertEq(market.totalBadDebt(), 1_200e6);
        assertEq(core.available(buyer), 96_200e6);
        assertEq(core.reserved(buyer), 0);
        assertEq(market.currentDebt(id), 0);
        vm.expectRevert(ReservationManager.Inactive.selector);
        core.settle(k);
        vm.expectRevert(DemoLendingMarket.InvalidLoan.selector);
        market.repay(id);
        assertCustody();
    }

    function testLiquidationThresholdEqualityHealthy() public {
        (, bytes32 k) = open();
        refresh(62_5000_0000); // $62.50 -> 80% of $6,250 == $5,000 debt
        vm.expectRevert(ReservationManager.NotLiquidatable.selector);
        core.settle(k);
        refresh(62_4999_0000);
        core.settle(k);
    }

    function testExpiryBoundaryUnlocksWithoutChangingLoan() public {
        (uint256 id, bytes32 k) = open();
        uint256 expiry = core.expiryOf(k);
        vm.warp(expiry - 1);
        vm.expectRevert(ReservationManager.NotExpired.selector);
        core.expire(k);
        vm.warp(expiry);
        refresh(100e8);
        vm.expectRevert(ReservationManager.Inactive.selector);
        core.settle(k);
        core.expire(k);
        assertTrue(market.loanView(id).active);
        assertEq(core.reserved(buyer), 0);
        assertEq(market.currentDebt(id), 5_250e6);
        vm.prank(borrower);
        market.repay(id);
        assertEq(market.currentDebt(id), 0);
        assertCustody();
    }

    function testSettlementJustBeforeExpiry() public {
        (, bytes32 k) = open();
        vm.warp(core.expiryOf(k) - 1);
        refresh(100e8);
        core.settle(k);
        vm.expectRevert(ReservationManager.Inactive.selector);
        core.expire(k);
    }

    function testExpiredButUnreleasedRepayment() public {
        (uint256 id, bytes32 k) = open();
        vm.warp(core.expiryOf(k) + 10 days);
        assertEq(market.currentDebt(id), 5_250e6);
        vm.prank(borrower);
        market.repay(id);
        assertEq(uint256(core.state(k)), uint256(ReservationManager.State.Repaid));
        assertCustody();
    }

    function testUncoveredRecoveryOnlyAfterDefaultAndExpiry() public {
        (uint256 id, bytes32 k) = open();
        vm.prank(lender);
        vm.expectRevert(DemoLendingMarket.InvalidLoan.selector);
        market.recoverUncovered(id);
        vm.warp(core.expiryOf(k));
        vm.prank(outsider);
        vm.expectRevert(DemoLendingMarket.Unauthorized.selector);
        market.recoverUncovered(id);
        vm.prank(lender);
        market.recoverUncovered(id);
        assertEq(market.totalBadDebt(), 5_250e6);
        assertEq(market.collateralRecoveredInKind(), 100e18);
        assertEq(hype.balanceOf(lender), 100e18);
        assertEq(core.reserved(buyer), 0);
        assertFalse(market.loanView(id).active);
        assertCustody();
    }

    function testUnauthorizedCoreAdapterAndMarketCalls() public {
        ReferenceLendingAdapter adapter = market.adapter();
        (uint256 id, bytes32 k) = open();
        vm.startPrank(outsider);
        vm.expectRevert(ReservationManager.Unauthorized.selector);
        core.reserve(offer, id, 100e6);
        vm.expectRevert(ReservationManager.Unauthorized.selector);
        core.release(id);
        vm.expectRevert(ReservationManager.Unauthorized.selector);
        core.cancelOffer(offer);
        vm.expectRevert(ReferenceLendingAdapter.Unauthorized.selector);
        adapter.reserve(offer, id, 100e6);
        vm.expectRevert(ReferenceLendingAdapter.Unauthorized.selector);
        adapter.release(id);
        vm.expectRevert(ReferenceLendingAdapter.Unauthorized.selector);
        adapter.execute(id, buyer, 1, 1);
        vm.expectRevert(DemoLendingMarket.Unauthorized.selector);
        market.executePurchase(id, buyer, 1, 1);
        vm.expectRevert(DemoLendingMarket.Unauthorized.selector);
        market.withdrawLiquidity(1);
        vm.stopPrank();
        assertEq(uint256(core.state(k)), uint256(ReservationManager.State.Active));
    }

    function testFeeLimitAndWrongMarketOfferRollback() public {
        vm.startPrank(borrower);
        vm.expectRevert(DemoLendingMarket.FeeTooHigh.selector);
        market.borrow(100e18, 5_000e6, 30 days, offer, 52_500_000 - 1);
        vm.expectRevert(ReservationManager.Unauthorized.selector);
        marketB.borrow(100e18, 5_000e6, 30 days, offer, 100e6);
        vm.stopPrank();
        assertEq(core.totalFees(), 0);
        assertEq(market.nextLoanId(), 1);
        assertEq(hype.balanceOf(borrower), 100_000e18);
    }

    function testRevertingPrincipalTransferRollsBackReservationAndFee() public {
        // Removes token cash without changing market bookkeeping, exercising the final disbursement failure.
        deal(address(usd), address(market), 0);
        vm.prank(borrower);
        vm.expectRevert();
        market.borrow(100e18, 5_000e6, 30 days, offer, 100e6);
        assertEq(core.reserved(buyer), 0);
        assertEq(core.totalFees(), 0);
        assertEq(hype.balanceOf(borrower), 100_000e18);
        assertEq(market.nextLoanId(), 1);
    }

    function testAdmissionIncludesInterestAndOfferLifetime() public {
        vm.prank(borrower);
        vm.expectRevert(DemoLendingMarket.InvalidLoan.selector);
        market.borrow(100e18, 6_000e6, 30 days, offer, 100e6);
        vm.warp(block.timestamp + 365 days);
        refresh(100e8);
        vm.prank(borrower);
        vm.expectRevert(ReservationManager.InvalidTerms.selector);
        market.borrow(100e18, 5_000e6, 30 days, offer, 100e6);
    }

    function testFuzzDebtCappedAndRepayment(uint256 elapsed) public {
        (uint256 id,) = open();
        elapsed = bound(elapsed, 0, 1_000 days);
        vm.warp(block.timestamp + elapsed);
        uint256 debt = market.currentDebt(id);
        assertGe(debt, 5_000e6);
        assertLe(debt, 5_250e6);
        vm.prank(borrower);
        market.repay(id);
        assertCustody();
    }

    function testFuzzSettlementRounding(uint256 p) public {
        (, bytes32 k) = open();
        atMaturity();
        p = bound(p, 1e6, 1_000e8);
        refresh(int256(p));
        uint256 price = oracle.price() * 9_500 / 10_000;
        (uint256 payment, uint256 amount) = core.settle(k);
        assertLe(payment, 5_250e6);
        assertLe(amount, 100e18);
        assertEq(market.totalBadDebt(), 5_250e6 - payment);
        if (payment == 5_250e6) {
            assertGe(amount * price, payment * 1e18);
            assertLt((amount - 1) * price, payment * 1e18);
        } else {
            assertEq(amount, 100e18);
            assertEq(payment, amount * price / 1e18);
        }
        assertCustody();
    }

    function testDustCannotSeizeCollateralForZeroPayment() public {
        (uint256 id, bytes32 k) = open();
        atMaturity();
        refresh(100); // Normalized oracle quote is one USDC base unit; discount rounds it to zero.
        vm.expectRevert(ReservationManager.DustPurchase.selector);
        core.settle(k);
        assertTrue(market.loanView(id).active);
        assertEq(hype.balanceOf(buyer), 0);
        assertCustody();
    }

    function testFeeAndInterestRoundUpAtBaseUnit() public {
        vm.prank(borrower);
        uint256 id = market.borrow(1e18, 1, 1 days, offer, 1);
        assertEq(core.feesEarned(buyer), 1);
        assertEq(core.reserved(buyer), 2);
        vm.warp(block.timestamp + 1);
        assertEq(market.currentDebt(id), 2);
        vm.prank(borrower);
        market.repay(id);
        assertCustody();
    }

    function testMaximumDurationIncludesExecutionWindow() public {
        address adapter = address(market.adapter());
        vm.prank(buyer);
        uint256 longOffer = core.createOffer(adapter, 10_000e6, block.timestamp + 1 days, 367 days, 500, 100);
        vm.prank(borrower);
        uint256 id = market.borrow(100e18, 5_000e6, 365 days, longOffer, 100e6);
        assertEq(core.expiryOf(core.key(address(market.adapter()), id)), block.timestamp + 367 days);
    }

    function testShortOfferDurationCannotLeaveLoanUncoveredAtIssuance() public {
        address adapter = address(market.adapter());
        vm.prank(buyer);
        uint256 shortOffer = core.createOffer(adapter, 10_000e6, block.timestamp + 1 days, 31 days, 500, 100);
        vm.prank(borrower);
        vm.expectRevert(ReservationManager.InvalidLoan.selector);
        market.borrow(100e18, 5_000e6, 30 days, shortOffer, 100e6);
        assertEq(market.nextLoanId(), 1);
    }

    function testAnotherBuyerCannotWithdrawOrSpendFirstBuyersBalance() public {
        open();
        usd.mint(outsider, 1_000e6);
        vm.startPrank(outsider);
        usd.approve(address(core), type(uint256).max);
        core.deposit(1_000e6);
        vm.expectRevert(BuyerVault.InsufficientAvailable.selector);
        core.withdraw(1_000e6 + 1);
        core.withdraw(1_000e6);
        vm.stopPrank();
        assertEq(core.reserved(buyer), 5_250e6);
        assertEq(core.available(outsider), 0);
        assertCustody();
    }

    function testInvalidOfferAndZeroVaultAmounts() public {
        vm.startPrank(buyer);
        vm.expectRevert(BuyerVault.InvalidAmount.selector);
        core.deposit(0);
        vm.expectRevert(BuyerVault.InvalidAmount.selector);
        core.withdraw(0);
        address adapter = address(market.adapter());
        vm.expectRevert(ReservationManager.InvalidTerms.selector);
        core.createOffer(adapter, 1, block.timestamp + 1 days, 3 days, 2_001, 100);
        vm.expectRevert(ReservationManager.InvalidTerms.selector);
        core.createOffer(adapter, 1, block.timestamp + 1 days, 3 days, 500, 1_001);
        vm.stopPrank();
    }
}
