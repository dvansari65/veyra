// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;
import { Script, console2 } from "forge-std/Script.sol";
import { MockToken } from "../src/mocks/MockToken.sol";
import { MockFeed } from "../src/mocks/MockFeed.sol";
import { PriceOracle } from "../src/PriceOracle.sol";
import { ReservationManager } from "../src/ReservationManager.sol";
import { DemoLendingMarket } from "../src/DemoLendingMarket.sol";

abstract contract Deployment is Script {
    MockToken internal usd;
    MockToken internal hype;
    MockFeed internal collateralFeed;
    MockFeed internal debtFeed;
    PriceOracle internal oracle;
    ReservationManager internal core;
    DemoLendingMarket internal market;
    DemoLendingMarket internal marketB;

    function deployMocks(address lender) internal {
        require(block.chainid == 31337 || block.chainid == 998, "Test chains only");
        usd = new MockToken("Veyra TEST USDC", "tUSDC", 6);
        hype = new MockToken("Veyra TEST Wrapped HYPE", "tWHYPE", 18);
        collateralFeed = new MockFeed(8, 100e8);
        debtFeed = new MockFeed(8, 1e8);
        oracle = new PriceOracle(address(hype), address(usd), collateralFeed, debtFeed, 1 hours);
        core = new ReservationManager(oracle);
        market = new DemoLendingMarket(core, lender);
        marketB = new DemoLendingMarket(core, lender);
    }

    function logAddresses() internal view {
        console2.log("TEST USDC", address(usd));
        console2.log("TEST wrapped HYPE", address(hype));
        console2.log("Mutable TEST collateral feed", address(collateralFeed));
        console2.log("Mutable TEST debt feed", address(debtFeed));
        console2.log("PriceOracle", address(oracle));
        console2.log("ReservationManager (includes vault and settlement)", address(core));
        console2.log("Demo market A", address(market));
        console2.log("Reference adapter A", address(market.adapter()));
        console2.log("Demo market B", address(marketB));
        console2.log("Reference adapter B", address(marketB.adapter()));
    }
}

/// @notice Test-only deployment. Default invocation simulates; broadcasting is a separate explicit CLI action.
contract Deploy is Deployment {
    function run() external {
        address lender = block.chainid == 998 ? vm.envAddress("LENDER") : vm.envOr("LENDER", address(0xA11CE));
        vm.startBroadcast();
        deployMocks(lender);
        vm.stopBroadcast();
        logAddresses();
        console2.log("Immutable lender (set LENDER before testnet deployment)", lender);
    }
}
