// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;
import { Deployment } from "./Deploy.s.sol";
import { console2 } from "forge-std/Script.sol";
import { BuyerVault } from "../src/BuyerVault.sol";

/// @notice Local simulation only: buyer funding, two markets, rejected overbooking, repayment and liquidation.
contract Demo is Deployment {
    function run() external {
        require(block.chainid == 31337, "Run this simulation locally");
        address buyer = address(0xB0B);
        address borrower = address(0xB0A);
        address lender = address(0xA11CE);
        deployMocks(lender);
        usd.mint(buyer, 100_000e6);
        usd.mint(lender, 200_000e6);
        usd.mint(borrower, 2_000e6);
        hype.mint(borrower, 3_000e18);
        vm.startPrank(lender);
        usd.approve(address(market), 100_000e6);
        market.fund(100_000e6);
        usd.approve(address(marketB), 100_000e6);
        marketB.fund(100_000e6);
        vm.stopPrank();
        vm.startPrank(buyer);
        usd.approve(address(core), 100_000e6);
        core.deposit(100_000e6);
        uint256 offerA = core.createOffer(
            address(market.adapter()), 100_000e6, block.timestamp + 90 days, 90 days, 500, 100
        );
        uint256 offerB = core.createOffer(
            address(marketB.adapter()), 100_000e6, block.timestamp + 90 days, 90 days, 500, 100
        );
        vm.stopPrank();
        vm.startPrank(borrower);
        usd.approve(address(market), type(uint256).max);
        usd.approve(address(marketB), type(uint256).max);
        hype.approve(address(market), type(uint256).max);
        hype.approve(address(marketB), type(uint256).max);
        uint256 first = market.borrow(2_000e18, 66_666e6, 30 days, offerA, 1_000e6);
        vm.expectRevert(BuyerVault.InsufficientAvailable.selector);
        marketB.borrow(1_000e18, 38_095e6, 30 days, offerB, 1_000e6);
        vm.stopPrank();
        require(core.reserved(buyer) == 69_999_300_000, "Allocation mismatch");
        require(marketB.nextLoanId() == 1, "Failed loan was not rolled back");
        console2.log("Buyer deposited: 100,000 tUSDC; lender separately funded each market");
        console2.log("Market A reserved: 69,999.30 tUSDC; Market B overbooking correctly rejected");
        vm.prank(borrower);
        market.repay(first);
        require(core.reserved(buyer) == 0 && hype.balanceOf(borrower) == 3_000e18, "Repayment failed");
        console2.log("First loan repaid; reservation released; collateral returned");
        vm.prank(borrower);
        uint256 second = market.borrow(100e18, 5_000e6, 30 days, offerA, 100e6);
        collateralFeed.set(40e8, block.timestamp);
        (uint256 paid, uint256 purchased) = core.settle(core.key(address(market.adapter()), second));
        require(paid == 3_800e6 && purchased == 100e18, "Liquidation mismatch");
        require(market.totalBadDebt() == 1_200e6, "Shortfall mismatch");
        require(
            usd.balanceOf(address(core)) == core.totalAvailable() + core.totalReserved(), "Custody mismatch"
        );
        console2.log("Second loan liquidated: buyer paid 3,800 tUSDC and received 100 tWHYPE");
        console2.log("Lender shortfall recorded: 1,200 tUSDC; remaining buyer capital: 96,200 tUSDC");
        console2.log("All demo assertions passed. Simulation only; no transactions broadcast.");
    }
}
