// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;
import { BaseTest } from "./Base.t.sol";
import { MockToken } from "../src/mocks/MockToken.sol";
import { MockFeed } from "../src/mocks/MockFeed.sol";
import { PriceOracle } from "../src/PriceOracle.sol";

contract OracleTest is BaseTest {
    function testStablecoinDepegAndMixedFeedDecimals() public {
        df.set(80_000_000, block.timestamp);
        assertEq(oracle.price(), 125e6);
        MockFeed c = new MockFeed(18, 100e18);
        PriceOracle o = new PriceOracle(address(hype), address(usd), c, df, 1 hours);
        assertEq(o.price(), 125e6);
        assertEq(o.value(15e17), 187_500_000);
    }

    function testFreshnessBoundaryAndFuture() public {
        vm.warp(block.timestamp + 1 hours);
        assertEq(oracle.price(), 100e6);
        vm.warp(block.timestamp + 1);
        vm.expectRevert(PriceOracle.InvalidPrice.selector);
        oracle.price();
        cf.set(100e8, block.timestamp + 1);
        df.set(1e8, block.timestamp);
        vm.expectRevert(PriceOracle.InvalidPrice.selector);
        oracle.price();
    }

    function testBadAnswersAndRounds() public {
        cf.set(0, block.timestamp);
        vm.expectRevert(PriceOracle.InvalidPrice.selector);
        oracle.price();
        cf.set(-1, block.timestamp);
        vm.expectRevert(PriceOracle.InvalidPrice.selector);
        oracle.price();
        cf.set(100e8, 0);
        vm.expectRevert(PriceOracle.InvalidPrice.selector);
        oracle.price();
        cf.set(100e8, block.timestamp);
        cf.setRound(2, 1);
        vm.expectRevert(PriceOracle.InvalidPrice.selector);
        oracle.price();
        cf.setRound(0, 0);
        vm.expectRevert(PriceOracle.InvalidPrice.selector);
        oracle.price();
        cf.setRound(1, 1);
        df.set(-1, block.timestamp);
        vm.expectRevert(PriceOracle.InvalidPrice.selector);
        oracle.price();
    }

    function testRejectOversizedAndZeroNormalizedPrice() public {
        cf.set(1e36 + 1, block.timestamp);
        vm.expectRevert(PriceOracle.InvalidPrice.selector);
        oracle.price();
        cf.set(1, block.timestamp);
        df.set(1e36, block.timestamp);
        vm.expectRevert(PriceOracle.InvalidPrice.selector);
        oracle.price();
    }

    function testInvalidConfiguration() public {
        MockToken highDecimals = new MockToken("Invalid", "BAD", 19);
        vm.expectRevert(PriceOracle.InvalidConfig.selector);
        new PriceOracle(address(highDecimals), address(usd), cf, df, 1 hours);
        vm.expectRevert(PriceOracle.InvalidConfig.selector);
        new PriceOracle(address(usd), address(usd), cf, df, 1 hours);
        vm.expectRevert(PriceOracle.InvalidConfig.selector);
        new PriceOracle(address(hype), address(usd), cf, df, 0);
        MockFeed highFeed = new MockFeed(19, 1);
        vm.expectRevert(PriceOracle.InvalidConfig.selector);
        new PriceOracle(address(hype), address(usd), highFeed, df, 1 hours);
    }

    function testStaleSettlementLeavesAllStateIntact() public {
        (, bytes32 k) = open();
        vm.warp(block.timestamp + 2 hours);
        uint256 allocation = core.reserved(buyer);
        vm.expectRevert(PriceOracle.InvalidPrice.selector);
        core.settle(k);
        assertEq(core.reserved(buyer), allocation);
        assertEq(hype.balanceOf(address(market)), 100e18);
        assertCustody();
    }

    function testFuzzTokenAndFeedDecimals(uint8 cd, uint8 dd, uint8 cfd, uint8 dfd) public {
        cd = uint8(bound(cd, 0, 18));
        dd = uint8(bound(dd, 0, 18));
        cfd = uint8(bound(cfd, 0, 18));
        dfd = uint8(bound(dfd, 0, 18));
        MockToken c = new MockToken("C", "C", cd);
        MockToken d = new MockToken("D", "D", dd);
        MockFeed f1 = new MockFeed(cfd, int256(100 * 10 ** uint256(cfd)));
        MockFeed f2 = new MockFeed(dfd, int256(2 * 10 ** uint256(dfd)));
        PriceOracle o = new PriceOracle(address(c), address(d), f1, f2, 1 hours);
        assertEq(o.price(), 50 * 10 ** uint256(dd));
        assertEq(o.value(3 * 10 ** uint256(cd)), 150 * 10 ** uint256(dd));
    }
}
