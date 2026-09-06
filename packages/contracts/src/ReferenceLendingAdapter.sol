// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { ILendingAdapter } from "./interfaces/ILendingAdapter.sol";
import { ReservationManager } from "./ReservationManager.sol";

interface IReferenceMarket {
    function loanView(uint256 id) external view returns (ILendingAdapter.LoanView memory);
    function executePurchase(uint256 id, address buyer, uint256 amount, uint256 payment) external;
}

/// @notice Immutable connector for DemoLendingMarket only; never transfers debt to the collateral buyer.
/// @dev Deployed by the market constructor. No operator or replaceable integration pointers.
contract ReferenceLendingAdapter is ILendingAdapter, ReentrancyGuard {
    using SafeERC20 for IERC20;
    error Unauthorized();
    address public immutable market;
    address public immutable core;
    address public immutable oracle;
    address public immutable debtAsset;
    address public immutable collateral;

    constructor(ReservationManager core_) {
        market = msg.sender;
        core = address(core_);
        oracle = address(core_.oracle());
        debtAsset = address(core_.debtToken());
        collateral = address(core_.collateralToken());
    }

    /// @dev Market prefunds the exact fee from its borrowing caller before invoking this function.
    function reserve(uint256 offerId, uint256 id, uint256 feeLimit) external nonReentrant returns (bytes32) {
        if (msg.sender != market) revert Unauthorized();
        uint256 fee = ReservationManager(core).feeFor(offerId, loan(id).maxDebt);
        IERC20(debtAsset).forceApprove(core, fee);
        bytes32 k = ReservationManager(core).reserve(offerId, id, feeLimit);
        IERC20(debtAsset).forceApprove(core, 0);
        return k;
    }

    function release(uint256 id) external nonReentrant {
        if (msg.sender != market) revert Unauthorized();
        ReservationManager(core).release(id);
    }

    function loan(uint256 id) public view returns (LoanView memory) {
        return IReferenceMarket(market).loanView(id);
    }

    function execute(uint256 id, address buyer, uint256 amount, uint256 payment) external nonReentrant {
        if (msg.sender != core) revert Unauthorized();
        IReferenceMarket(market).executePurchase(id, buyer, amount, payment);
    }
}
