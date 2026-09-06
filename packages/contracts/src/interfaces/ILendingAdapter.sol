// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

/// @notice Trusted, buyer-selected integration boundary. Snapshot debt must be capped by maxDebt.
interface ILendingAdapter {
    struct LoanView {
        address borrower;
        uint256 collateralAmount;
        uint256 debt;
        uint256 maxDebt;
        uint256 maturity;
        bool active;
    }

    function market() external view returns (address);
    function core() external view returns (address);
    function oracle() external view returns (address);
    function debtAsset() external view returns (address);
    function collateral() external view returns (address);
    /// @notice Return the loan ledger snapshot. A terminal loan must report inactive, zero debt and
    /// zero collateralAmount; historical borrower, maximum debt and maturity may remain recorded.
    function loan(uint256 id) external view returns (LoanView memory);
    /// @dev Must terminally close the loan, return surplus to borrower and record any shortfall.
    function execute(uint256 id, address buyer, uint256 collateralAmount, uint256 payment) external;
}
