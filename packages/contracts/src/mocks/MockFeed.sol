// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;
import { IAggregator } from "../PriceOracle.sol";

/// @notice TEST ONLY: anyone can manipulate every feed field. Never use for real funds.
contract MockFeed is IAggregator {
    uint8 public immutable decimals;
    int256 public answer;
    uint256 public updatedAt;
    uint80 public roundId = 1;
    uint80 public answeredInRound = 1;

    constructor(uint8 decimals_, int256 answer_) {
        decimals = decimals_;
        set(answer_, block.timestamp);
    }

    function set(int256 answer_, uint256 updated_) public {
        answer = answer_;
        updatedAt = updated_;
    }

    function setRound(uint80 round_, uint80 answered_) external {
        roundId = round_;
        answeredInRound = answered_;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (roundId, answer, updatedAt, updatedAt, answeredInRound);
    }
}
