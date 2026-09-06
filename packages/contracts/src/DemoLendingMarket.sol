// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { ExactTransfer } from "./libraries/ExactTransfer.sol";
import { ILendingAdapter } from "./interfaces/ILendingAdapter.sol";
import { ReservationManager } from "./ReservationManager.sol";
import { ReferenceLendingAdapter } from "./ReferenceLendingAdapter.sol";

/// @notice Reference fixed-duration lending market with one immutable liquidity provider.
/// @dev Demo economics: 60% admission LTV on capped debt, 80% liquidation LTV, 5% total term interest.
/// Buyer capital is held exclusively by Veyra and never funds loan issuance.
contract DemoLendingMarket is ReentrancyGuard {
    using ExactTransfer for IERC20;
    error Unauthorized();
    error InvalidLoan();
    error FeeTooHigh();
    error InsufficientLiquidity();
    error InvalidSettlement();

    uint256 public constant TERM_INTEREST_BPS = 500;
    ReservationManager public immutable core;
    ReferenceLendingAdapter public immutable adapter;
    IERC20 public immutable debtToken;
    IERC20 public immutable collateralToken;
    address public immutable lender;
    uint256 public nextLoanId = 1;
    uint256 public liquidity;
    uint256 public outstandingPrincipal;
    uint256 public totalBadDebt;
    uint256 public collateralRecoveredInKind;

    enum Status {
        None,
        Active,
        Repaid,
        Liquidated,
        WrittenOff
    }

    struct Loan {
        address borrower;
        uint256 principal;
        uint256 maxDebt;
        uint256 collateralAmount;
        uint256 start;
        uint256 maturity;
        bytes32 reservationKey;
        Status status;
    }
    mapping(uint256 => Loan) public loans;
    event Funded(uint256 amount);
    event LiquidityWithdrawn(uint256 amount);
    event Borrowed(uint256 indexed id, address indexed borrower, uint256 principal, bytes32 reservationKey);
    event Repaid(uint256 indexed id, uint256 debt);
    event Liquidated(uint256 indexed id, uint256 payment, uint256 shortfall);
    event WrittenOff(uint256 indexed id, uint256 grossBadDebt, uint256 collateralRecovered);

    constructor(ReservationManager core_, address lender_) {
        if (lender_ == address(0)) revert Unauthorized();
        core = core_;
        lender = lender_;
        debtToken = core_.debtToken();
        collateralToken = core_.collateralToken();
        adapter = new ReferenceLendingAdapter(core_);
    }

    function fund(uint256 amount) external nonReentrant {
        if (msg.sender != lender) revert Unauthorized();
        if (amount == 0) revert InvalidLoan();
        liquidity += amount;
        debtToken.pull(msg.sender, address(this), amount);
        emit Funded(amount);
    }

    /// @notice Only idle lender cash is withdrawable; borrower collateral has no withdrawal privilege.
    function withdrawLiquidity(uint256 amount) external nonReentrant {
        if (msg.sender != lender) revert Unauthorized();
        if (amount == 0 || amount > liquidity) revert InsufficientLiquidity();
        liquidity -= amount;
        debtToken.push(lender, amount);
        emit LiquidityWithdrawn(amount);
    }

    function maximumDebt(uint256 principal) public pure returns (uint256) {
        return principal + Math.mulDiv(principal, TERM_INTEREST_BPS, 10_000, Math.Rounding.Ceil);
    }

    /// @notice Caller posts collateral, pays a bounded non-refundable fee and receives lender principal atomically.
    /// @param feeLimit Maximum fee authorized by this caller in debt-token base units.
    function borrow(
        uint256 collateralAmount,
        uint256 principal,
        uint256 duration,
        uint256 offerId,
        uint256 feeLimit
    ) external nonReentrant returns (uint256 id) {
        if (principal == 0 || collateralAmount == 0 || duration < 1 days || duration > 365 days) revert InvalidLoan();
        if (principal > liquidity) revert InsufficientLiquidity();
        uint256 cap = maximumDebt(principal);
        // Core independently repeats admission validation against the snapshot.
        if (cap > Math.mulDiv(core.oracle().value(collateralAmount), core.ADMISSION_LTV(), 10_000)) {
            revert InvalidLoan();
        }
        uint256 fee = core.feeFor(offerId, cap);
        if (fee > feeLimit) revert FeeTooHigh();
        id = nextLoanId++;
        loans[id] = Loan(
            msg.sender,
            principal,
            cap,
            collateralAmount,
            block.timestamp,
            block.timestamp + duration,
            bytes32(0),
            Status.Active
        );
        liquidity -= principal;
        outstandingPrincipal += principal;
        collateralToken.pull(msg.sender, address(this), collateralAmount);
        debtToken.pull(msg.sender, address(adapter), fee);
        bytes32 k = adapter.reserve(offerId, id, feeLimit);
        loans[id].reservationKey = k;
        debtToken.push(msg.sender, principal);
        emit Borrowed(id, msg.sender, principal, k);
    }

    /// @notice Linear term interest rounded up, capped permanently at maturity; no post-maturity accrual.
    function currentDebt(uint256 id) public view returns (uint256) {
        Loan memory l = loans[id];
        if (l.status != Status.Active) return 0;
        uint256 elapsed = Math.min(block.timestamp - l.start, l.maturity - l.start);
        return
            l.principal
                + Math.mulDiv(l.maxDebt - l.principal, elapsed, l.maturity - l.start, Math.Rounding.Ceil);
    }

    function loanView(uint256 id) external view returns (ILendingAdapter.LoanView memory) {
        Loan memory l = loans[id];
        return ILendingAdapter.LoanView(
            l.borrower, l.collateralAmount, currentDebt(id), l.maxDebt, l.maturity, l.status == Status.Active
        );
    }

    /// @notice Anyone can repay using their own allowance; collateral always returns to the borrower.
    /// @dev Works after reservation expiry and during oracle outages.
    function repay(uint256 id) external nonReentrant {
        Loan storage l = loans[id];
        if (l.status != Status.Active) revert InvalidLoan();
        uint256 debt = currentDebt(id);
        uint256 amount = l.collateralAmount;
        l.status = Status.Repaid;
        l.collateralAmount = 0;
        outstandingPrincipal -= l.principal;
        liquidity += debt;
        debtToken.pull(msg.sender, address(this), debt);
        adapter.release(id);
        collateralToken.push(l.borrower, amount);
        emit Repaid(id, debt);
    }

    /// @notice Adapter-only terminal purchase; payment must already be delivered by the core.
    /// @dev Independent eligibility and pricing verification in core precedes this authenticated callback.
    function executePurchase(uint256 id, address buyer, uint256 amount, uint256 payment)
        external
        nonReentrant
    {
        if (msg.sender != address(adapter)) revert Unauthorized();
        Loan storage l = loans[id];
        uint256 debt = currentDebt(id);
        if (
            l.status != Status.Active || core.state(l.reservationKey) != ReservationManager.State.Settled
                || amount == 0 || amount > l.collateralAmount || payment == 0 || payment > debt
                || debtToken.balanceOf(address(this)) < liquidity + payment
        ) revert InvalidSettlement();
        uint256 surplus = l.collateralAmount - amount;
        l.status = Status.Liquidated;
        l.collateralAmount = 0;
        outstandingPrincipal -= l.principal;
        liquidity += payment;
        totalBadDebt += debt - payment;
        collateralToken.push(buyer, amount);
        collateralToken.push(l.borrower, surplus);
        emit Liquidated(id, payment, debt - payment);
    }

    /// @notice After default AND expiry, lender can close uncovered debt and recover collateral in kind.
    /// @dev Records the entire unpaid debt as gross bad debt; no speculative USD credit for recovered tokens.
    /// Expiry alone never changes a loan. Repayment remains available until this terminal action wins the race.
    function recoverUncovered(uint256 id) external nonReentrant {
        if (msg.sender != lender) revert Unauthorized();
        Loan storage l = loans[id];
        if (
            l.status != Status.Active || block.timestamp < l.maturity
                || block.timestamp < core.expiryOf(l.reservationKey)
        ) revert InvalidLoan();
        if (core.state(l.reservationKey) == ReservationManager.State.Active) core.expire(l.reservationKey);
        uint256 debt = currentDebt(id);
        uint256 amount = l.collateralAmount;
        l.status = Status.WrittenOff;
        l.collateralAmount = 0;
        outstandingPrincipal -= l.principal;
        totalBadDebt += debt;
        collateralRecoveredInKind += amount;
        adapter.release(id);
        collateralToken.push(lender, amount);
        emit WrittenOff(id, debt, amount);
    }
}
