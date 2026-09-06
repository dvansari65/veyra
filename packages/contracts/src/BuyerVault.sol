// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { ExactTransfer } from "./libraries/ExactTransfer.sol";

/// @notice Custody and exclusive allocation of one debt token; inherited by the sole reservation core.
/// @dev Internal allocation methods share the core's reentrancy guard. No owner, sweep, or upgrade path.
abstract contract BuyerVault is ReentrancyGuard {
    using ExactTransfer for IERC20;
    error InsufficientAvailable();
    error InvalidAmount();
    IERC20 public immutable debtToken;
    mapping(address => uint256) public available;
    mapping(address => uint256) public reserved;
    uint256 public totalAvailable;
    uint256 public totalReserved;

    event Deposited(address indexed buyer, uint256 amount);
    event Withdrawn(address indexed buyer, uint256 amount);

    constructor(IERC20 token) {
        debtToken = token;
    }

    /// @notice Credit only the caller. Capital remains here until withdrawal or an authorized settlement.
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        available[msg.sender] += amount;
        totalAvailable += amount;
        debtToken.pull(msg.sender, address(this), amount);
        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (amount > available[msg.sender]) revert InsufficientAvailable();
        available[msg.sender] -= amount;
        totalAvailable -= amount;
        debtToken.push(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function _reserve(address buyer, uint256 amount) internal {
        if (amount > available[buyer]) revert InsufficientAvailable();
        available[buyer] -= amount;
        totalAvailable -= amount;
        reserved[buyer] += amount;
        totalReserved += amount;
    }

    /// @dev Releases the entire terminal allocation; the unspent part becomes available again.
    function _finish(address buyer, uint256 allocation, uint256 spend) internal {
        reserved[buyer] -= allocation;
        totalReserved -= allocation;
        available[buyer] += allocation - spend;
        totalAvailable += allocation - spend;
    }
}
