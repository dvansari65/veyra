// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @notice Minimal Chainlink-compatible USD feed surface. Availability on HyperEVM must be verified separately.
interface IAggregator {
    function decimals() external view returns (uint8);
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
}

/// @notice Immutable collateral/debt pair using two USD feeds, including the stablecoin's actual USD price.
/// @dev Quotes are debt-token base units per whole collateral token. All value calculations round down.
contract PriceOracle {
    error InvalidPrice();
    error InvalidConfig();
    address public immutable collateral;
    address public immutable debtAsset;
    IAggregator public immutable collateralFeed;
    IAggregator public immutable debtFeed;
    uint256 public immutable collateralUnit;
    uint256 public immutable debtUnit;
    uint256 public immutable collateralFeedUnit;
    uint256 public immutable debtFeedUnit;
    uint256 public immutable maxAge;

    constructor(
        address collateral_,
        address debt_,
        IAggregator collateralFeed_,
        IAggregator debtFeed_,
        uint256 maxAge_
    ) {
        if (collateral_ == debt_ || maxAge_ == 0) revert InvalidConfig();
        collateral = collateral_;
        debtAsset = debt_;
        collateralFeed = collateralFeed_;
        debtFeed = debtFeed_;
        collateralUnit = _unit(IERC20Metadata(collateral_).decimals());
        debtUnit = _unit(IERC20Metadata(debt_).decimals());
        collateralFeedUnit = _unit(collateralFeed_.decimals());
        debtFeedUnit = _unit(debtFeed_.decimals());
        maxAge = maxAge_;
    }

    /// @return Debt base units per whole collateral token, rounded down; zero quotes are rejected.
    function price() public view returns (uint256) {
        uint256 c = _read(collateralFeed);
        uint256 d = _read(debtFeed);
        uint256 result = Math.mulDiv(c, debtFeedUnit * debtUnit, d * collateralFeedUnit);
        if (result == 0) revert InvalidPrice();
        return result;
    }

    function value(uint256 collateralAmount) external view returns (uint256) {
        return Math.mulDiv(collateralAmount, price(), collateralUnit);
    }

    function _read(IAggregator feed) private view returns (uint256) {
        (uint80 round, int256 answer,, uint256 updated, uint80 answered) = feed.latestRoundData();
        // Bound magnitudes so normalization products cannot overflow; reject invalid/incomplete rounds.
        if (
            answer <= 0 || uint256(answer) > 1e36 || round == 0 || answered < round || updated == 0
                || updated > block.timestamp || block.timestamp - updated > maxAge
        ) revert InvalidPrice();
        return uint256(answer);
    }

    function _unit(uint8 decimals_) private pure returns (uint256) {
        if (decimals_ > 18) revert InvalidConfig();
        return 10 ** decimals_;
    }
}
