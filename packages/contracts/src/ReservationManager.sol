// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BuyerVault } from "./BuyerVault.sol";
import { PriceOracle } from "./PriceOracle.sol";
import { ILendingAdapter } from "./interfaces/ILendingAdapter.sol";
import { ExactTransfer } from "./libraries/ExactTransfer.sol";

/// @notice Immutable buyer offers, reservations and atomic settlement for one asset pair.
/// @dev SettlementEngine is deliberately consolidated here to share custody accounting and one lock.
/// Buyers explicitly trust each offer's adapter. No governance may rewrite accepted terms.
contract ReservationManager is BuyerVault {
    using ExactTransfer for IERC20;
    error Unauthorized();
    error InvalidTerms();
    error InvalidIntegration();
    error InvalidLoan();
    error Inactive();
    error NotExpired();
    error NotLiquidatable();
    error DeliveryFailed();
    error DustPurchase();

    uint256 public constant BPS = 10_000;
    uint256 public constant LIQUIDATION_LTV = 8_000;
    uint256 public constant ADMISSION_LTV = 6_000;
    uint256 public constant EXECUTION_WINDOW = 2 days;
    PriceOracle public immutable oracle;
    IERC20 public immutable collateralToken;
    uint256 public nextOfferId = 1;

    enum State {
        None,
        Active,
        Repaid,
        Expired,
        Settled
    }

    struct Offer {
        address buyer;
        address adapter;
        address market;
        uint256 maxPerLoan;
        uint256 validUntil;
        uint256 maxDuration;
        uint16 discountBps;
        uint16 feeBps;
        bool cancelled;
    }

    struct Reservation {
        address buyer;
        address adapter;
        address market;
        uint256 loanId;
        uint256 allocation;
        uint256 expiry;
        address borrower;
        uint256 collateralAmount;
        uint16 discountBps;
        State state;
    }
    mapping(uint256 => Offer) public offers;
    mapping(bytes32 => Reservation) public reservations;
    mapping(address => uint256) public feesEarned;
    uint256 public totalFees;

    event OfferCreated(uint256 indexed offerId, address indexed buyer, address indexed adapter);
    event OfferCancelled(uint256 indexed offerId);
    event Reserved(
        bytes32 indexed key, uint256 indexed offerId, uint256 allocation, uint256 expiry, uint256 fee
    );
    event Released(bytes32 indexed key, State state);
    event Settled(bytes32 indexed key, uint256 payment, uint256 collateralAmount, uint256 shortfall);

    constructor(PriceOracle oracle_) BuyerVault(IERC20(oracle_.debtAsset())) {
        oracle = oracle_;
        collateralToken = IERC20(oracle_.collateral());
    }

    /// @notice Publish a reusable offer for a specific trusted adapter and its current market.
    /// Funds lock only on acceptance; subsequent configuration changes cannot retarget the offer.
    /// @param maxPerLoan Maximum capped debt accepted per loan; global available capital is also enforced.
    /// @param maxDuration Maximum time from acceptance through expiry, including the execution window.
    function createOffer(
        address adapter,
        uint256 maxPerLoan,
        uint256 validUntil,
        uint256 maxDuration,
        uint16 discountBps,
        uint16 feeBps
    ) external nonReentrant returns (uint256 id) {
        if (
            maxPerLoan == 0 || validUntil <= block.timestamp || maxDuration <= EXECUTION_WINDOW
                || maxDuration > 367 days || discountBps > 2_000 || feeBps > 1_000
        ) revert InvalidTerms();
        ILendingAdapter a = ILendingAdapter(adapter);
        address market = a.market();
        _validateIntegration(a, market);
        id = nextOfferId++;
        offers[id] = Offer(
            msg.sender, adapter, market, maxPerLoan, validUntil, maxDuration, discountBps, feeBps, false
        );
        emit OfferCreated(id, msg.sender, adapter);
    }

    /// @notice Stops future acceptance only. Active commitments remain binding.
    function cancelOffer(uint256 id) external nonReentrant {
        if (offers[id].buyer != msg.sender) revert Unauthorized();
        offers[id].cancelled = true;
        emit OfferCancelled(id);
    }

    function key(address adapter, uint256 loanId) public pure returns (bytes32) {
        return keccak256(abi.encode(adapter, loanId));
    }

    function feeFor(uint256 offerId, uint256 allocation) public view returns (uint256) {
        return Math.mulDiv(allocation, offers[offerId].feeBps, BPS, Math.Rounding.Ceil);
    }

    /// @notice Accept only from the named adapter. Fee comes from that caller, never a third-party allowance.
    /// @dev Reference adapter authenticates its market, which obtains fees from its borrowing caller.
    function reserve(uint256 offerId, uint256 loanId, uint256 feeLimit)
        external
        nonReentrant
        returns (bytes32 k)
    {
        Offer memory o = offers[offerId];
        if (msg.sender != o.adapter) revert Unauthorized();
        if (o.cancelled || block.timestamp >= o.validUntil) revert InvalidTerms();
        _validateIntegration(ILendingAdapter(msg.sender), o.market);
        ILendingAdapter.LoanView memory l = ILendingAdapter(msg.sender).loan(loanId);
        uint256 expiry = l.maturity + EXECUTION_WINDOW;
        if (
            !l.active || l.borrower == address(0) || l.debt == 0 || l.debt > l.maxDebt
                || l.maxDebt > o.maxPerLoan || l.maturity <= block.timestamp
                || expiry > block.timestamp + o.maxDuration
                || l.maxDebt > Math.mulDiv(oracle.value(l.collateralAmount), ADMISSION_LTV, BPS)
        ) revert InvalidLoan();
        k = key(msg.sender, loanId);
        if (reservations[k].state != State.None) revert InvalidLoan();
        uint256 fee = feeFor(offerId, l.maxDebt);
        if (fee > feeLimit) revert InvalidTerms();
        _reserve(o.buyer, l.maxDebt);
        reservations[k] = Reservation(
            o.buyer,
            msg.sender,
            o.market,
            loanId,
            l.maxDebt,
            expiry,
            l.borrower,
            l.collateralAmount,
            o.discountBps,
            State.Active
        );
        feesEarned[o.buyer] += fee;
        totalFees += fee;
        debtToken.pull(msg.sender, o.buyer, fee);
        emit Reserved(k, offerId, l.maxDebt, expiry, fee);
    }

    /// @notice Repayment release requires an inactive loan with zero debt/collateral, and never needs a fresh price.
    function release(uint256 loanId) external nonReentrant {
        bytes32 k = key(msg.sender, loanId);
        Reservation storage r = reservations[k];
        if (r.adapter != msg.sender) revert Unauthorized();
        ILendingAdapter.LoanView memory l = ILendingAdapter(msg.sender).loan(loanId);
        if (l.active || l.debt != 0 || l.collateralAmount != 0) revert InvalidLoan();
        if (r.state == State.Expired) return;
        if (r.state != State.Active) revert Inactive();
        r.state = State.Repaid;
        _finish(r.buyer, r.allocation, 0);
        emit Released(k, State.Repaid);
    }

    /// @notice Anyone can unlock at expiry. This does not change the loan or trigger liquidation.
    function expire(bytes32 k) external nonReentrant {
        Reservation storage r = reservations[k];
        if (r.state != State.Active) revert Inactive();
        if (block.timestamp < r.expiry) revert NotExpired();
        r.state = State.Expired;
        _finish(r.buyer, r.allocation, 0);
        emit Released(k, State.Expired);
    }

    function state(bytes32 k) external view returns (State) {
        return reservations[k].state;
    }

    function expiryOf(bytes32 k) external view returns (uint256) {
        return reservations[k].expiry;
    }

    /// @notice Permissionless executor purchase. Revalidates debt, default, price and delivery on-chain.
    /// @dev Full-debt purchase rounds required collateral up; insufficient collateral rounds payment down.
    function settle(bytes32 k) external nonReentrant returns (uint256 payment, uint256 amount) {
        Reservation storage r = reservations[k];
        if (r.state != State.Active || block.timestamp >= r.expiry) revert Inactive();
        ILendingAdapter a = ILendingAdapter(r.adapter);
        _validateIntegration(a, r.market);
        ILendingAdapter.LoanView memory l = a.loan(r.loanId);
        if (
            !l.active || l.debt == 0 || l.debt > r.allocation || l.maxDebt != r.allocation
                || l.maturity + EXECUTION_WINDOW != r.expiry || l.borrower != r.borrower
                || l.collateralAmount != r.collateralAmount
        ) revert InvalidLoan();
        uint256 p = oracle.price();
        uint256 unit = oracle.collateralUnit();
        uint256 value = Math.mulDiv(l.collateralAmount, p, unit);
        if (block.timestamp < l.maturity && l.debt <= Math.mulDiv(value, LIQUIDATION_LTV, BPS)) {
            revert NotLiquidatable();
        }
        uint256 purchasePrice = Math.mulDiv(p, BPS - r.discountBps, BPS);
        if (purchasePrice == 0) revert DustPurchase();
        uint256 fullCost = Math.mulDiv(l.collateralAmount, purchasePrice, unit);
        if (fullCost >= l.debt) {
            payment = l.debt;
            amount = Math.mulDiv(payment, unit, purchasePrice, Math.Rounding.Ceil);
        } else {
            payment = fullCost;
            amount = l.collateralAmount;
        }
        // No free seizure for a quote smaller than one debt-token base unit.
        if (payment == 0 || amount == 0) revert DustPurchase();
        r.state = State.Settled;
        _finish(r.buyer, r.allocation, payment);
        uint256 beforeBuyer = collateralToken.balanceOf(r.buyer);
        // Pay the accepted market, never a destination selected by a later adapter configuration change.
        debtToken.push(r.market, payment);
        a.execute(r.loanId, r.buyer, amount, payment);
        ILendingAdapter.LoanView memory afterLoan = a.loan(r.loanId);
        if (
            collateralToken.balanceOf(r.buyer) < beforeBuyer + amount || afterLoan.active
                || afterLoan.debt != 0 || afterLoan.collateralAmount != 0
        ) revert DeliveryFailed();
        emit Settled(k, payment, amount, l.debt - payment);
    }

    /// @dev Recheck integration pointers before locking/spending capital. Release and expiry deliberately
    /// do not depend on these pointers so configuration drift cannot trap otherwise releasable capital.
    /// These checks detect advertised configuration drift, not an adapter lying about its implementation.
    function _validateIntegration(ILendingAdapter adapter, address market) private view {
        if (
            market == address(0) || adapter.market() != market || adapter.core() != address(this)
                || adapter.oracle() != address(oracle) || adapter.debtAsset() != address(debtToken)
                || adapter.collateral() != address(collateralToken)
        ) revert InvalidIntegration();
    }
}
