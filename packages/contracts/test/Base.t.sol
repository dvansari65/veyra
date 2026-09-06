// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;
import { Test } from "forge-std/Test.sol";
import { MockToken } from "../src/mocks/MockToken.sol";
import { MockFeed } from "../src/mocks/MockFeed.sol";
import { PriceOracle } from "../src/PriceOracle.sol";
import { BuyerVault } from "../src/BuyerVault.sol";
import { ReservationManager } from "../src/ReservationManager.sol";
import { DemoLendingMarket } from "../src/DemoLendingMarket.sol";
import { ReferenceLendingAdapter } from "../src/ReferenceLendingAdapter.sol";
import { ILendingAdapter } from "../src/interfaces/ILendingAdapter.sol";

abstract contract BaseTest is Test {
    MockToken internal usd;
    MockToken internal hype;
    MockFeed internal cf;
    MockFeed internal df;
    PriceOracle internal oracle;
    ReservationManager internal core;
    DemoLendingMarket internal market;
    DemoLendingMarket internal marketB;
    address internal buyer = makeAddr("buyer");
    address internal borrower = makeAddr("borrower");
    address internal lender = makeAddr("lender");
    address internal outsider = makeAddr("outsider");
    uint256 internal offer;
    uint256 internal offerB;

    function setUp() public virtual {
        vm.warp(1_000_000);
        usd = newDebtToken();
        hype = newCollateralToken();
        cf = new MockFeed(8, 100e8);
        df = new MockFeed(8, 1e8);
        oracle = new PriceOracle(address(hype), address(usd), cf, df, 1 hours);
        core = new ReservationManager(oracle);
        market = new DemoLendingMarket(core, lender);
        marketB = new DemoLendingMarket(core, lender);
        usd.mint(buyer, 100_000e6);
        usd.mint(lender, 200_000e6);
        usd.mint(borrower, 100_000e6);
        hype.mint(borrower, 100_000e18);
        vm.startPrank(buyer);
        usd.approve(address(core), type(uint256).max);
        core.deposit(100_000e6);
        offer = core.createOffer(
            address(market.adapter()), 100_000e6, block.timestamp + 365 days, 366 days, 500, 100
        );
        offerB = core.createOffer(
            address(marketB.adapter()), 100_000e6, block.timestamp + 365 days, 366 days, 500, 100
        );
        vm.stopPrank();
        vm.startPrank(lender);
        usd.approve(address(market), type(uint256).max);
        usd.approve(address(marketB), type(uint256).max);
        market.fund(100_000e6);
        marketB.fund(100_000e6);
        vm.stopPrank();
        vm.startPrank(borrower);
        hype.approve(address(market), type(uint256).max);
        hype.approve(address(marketB), type(uint256).max);
        usd.approve(address(market), type(uint256).max);
        usd.approve(address(marketB), type(uint256).max);
        vm.stopPrank();
    }

    function newDebtToken() internal virtual returns (MockToken) {
        return new MockToken("Test USDC", "tUSDC", 6);
    }

    function newCollateralToken() internal virtual returns (MockToken) {
        return new MockToken("Test Wrapped HYPE", "tWHYPE", 18);
    }

    function open() internal returns (uint256 id, bytes32 k) {
        vm.prank(borrower);
        id = market.borrow(100e18, 5_000e6, 30 days, offer, 100e6);
        k = core.key(address(market.adapter()), id);
    }

    function refresh(int256 price_) internal {
        cf.set(price_, block.timestamp);
        df.set(1e8, block.timestamp);
    }

    function atMaturity() internal {
        vm.warp(block.timestamp + 30 days);
        refresh(100e8);
    }

    function assertCustody() internal view {
        assertGe(usd.balanceOf(address(core)), core.totalAvailable() + core.totalReserved());
        assertEq(core.totalAvailable(), core.available(buyer));
        assertEq(core.totalReserved(), core.reserved(buyer));
        assertGe(usd.balanceOf(address(market)), market.liquidity());
    }
}
