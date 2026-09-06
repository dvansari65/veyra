# Veyra V1 contract specification

## Deployment and authority

A core is immutable and serves exactly one collateral/debt-token pair through one immutable PriceOracle. Deploy oracle, ReservationManager, then each DemoLendingMarket; the market constructor deploys its own ReferenceLendingAdapter. BuyerVault is an abstract base, not an independently permissioned custody contract. Settlement executes inside ReservationManager under the same lock as deposits, withdrawals and reservations.

There is no owner, upgrade mechanism, sweep function, protocol fee cut or market allowlist administrator. A buyer selects the **specific adapter address** in each offer. That is a trust decision, not permissionless verification of arbitrary loan ledgers. Another adapter cannot accept that offer. Reference adapters have immutable market/core/pair pointers and accept reservation/release calls only from their own market; execution is core-only.

The immutable lender can fund/withdraw idle market cash and recover collateral of uncovered defaulted loans. It cannot withdraw active borrower collateral or buyer custody. In-kind recoveries are separate from stablecoin liquidity.

## Offers and acceptance

Offer fields: buyer, adapter, pinned market, maximum allocation per loan, acceptance deadline, maximum reservation duration, discount (0–2,000 bps) and fee rate (0–1,000 bps). The duration limit includes the two-day execution window and cannot exceed 367 days. Offers are reusable while valid, subject to the buyer's globally available balance. A per-loan limit is not a cumulative offer budget. Publishing does not lock capital. Buyers must choose fees appropriate to the accepted adapter's borrower admission policy; any borrower admitted by the reference market can use its valid offers.

Only the buyer can cancel an offer. Cancellation prevents future acceptance but cannot cancel existing commitments. Accepted terms, including the market payment destination, are copied into the reservation and cannot be edited. The core validates the adapter's advertised market, core, oracle and token pointers when creating the offer, accepting it and settling. A changed configuration fails with InvalidIntegration. This detects reported configuration drift; it cannot detect an adapter lying while preserving those getters. There is no renewal in V1.

Reservation identity is `keccak256(abi.encode(adapter, loanId))`; even a terminal identity cannot be reused. At acceptance the core checks the adapter snapshot is active, identifies a borrower, has positive current debt no larger than capped debt, is within offer size/duration, and has future maturity. Maximum debt must be at most 60% of current oracle collateral value. The core reserves **maximum contractual debt**, not just principal.

The reference market calls `borrow` on behalf of `msg.sender` only. The borrower authorizes its collateral and fee transfers with market allowances and a transaction-specific `feeLimit`. Fee = ceil(allocation × feeBps / 10,000). Market moves the exact fee from borrower to adapter; adapter temporarily approves that fee to the core; core moves it from the adapter to the buyer. Approval is reset afterward. The core never pulls a fee from an arbitrary third-party fee payer. Fees are upfront/non-refundable, paid out directly, and counted in `feesEarned`/`totalFees`, outside vault liabilities.

Collateral transfer, fee payment, reservation and principal disbursement all share one transaction. Reverting any step rolls back the whole loan.

## Accounting

For each buyer: `available` can be withdrawn or allocated; `reserved` can only be released or consumed by a terminal core operation. The core holds all buyer capital without lending it out or investing it.

Required invariants:

- Debt-token custody >= totalAvailable + totalReserved.
- Sum of active reservation allocations = totalReserved.
- Sum of buyer balances = corresponding totals.
- Available + reserved = deposits − withdrawals − settlement spend; paid fees are excluded.
- Reference market collateral custody is at least collateral still attributed to active loans; unsolicited donations are surplus.
- Market debt-token custody >= accounted lender liquidity.

Direct unsolicited donations create surplus, never credit a buyer or lender, and have no sweep mechanism. No unbounded loops exist in production state transitions. Test invariant enumeration is deliberately bounded and off-chain.

## Reference debt and defaults

One lender supplies original principal. Loan duration is 1–365 days. The demo term interest is a **fixed 5% of principal for the complete term**, not an APR: maximum debt = principal + ceil(principal × 500 / 10,000). Accrued interest = ceil(maximum interest × min(elapsed, duration) / duration). No interest accrues after maturity.

Admission checks capped debt <= floor(collateral value × 6,000 / 10,000). Eligible liquidation means maturity has arrived **or** current debt > floor(current collateral value × 8,000 / 10,000). Equality at the health threshold is healthy before maturity. These are reference parameters, not production risk recommendations.

## Pricing and atomic settlement

PriceOracle reads collateral/USD **and debt token/USD**, accounting for a stablecoin depeg. Feed and token decimals must be <=18. Positive feed answers are bounded at 1e36; round identifiers must be nonzero and answered round must not trail current round. Updated timestamp must be nonzero, not in the future, and no older than maxAge (age == maxAge is accepted).

`price = floor(collateralUSD × debtFeedUnit × debtTokenUnit / (debtUSD × collateralFeedUnit))`, expressed in debt-token base units per whole collateral token. Normalized zero quotes revert. Pair value rounds down. Feed addresses, decimals and maxAge are immutable. The interface is Chainlink-compatible; this repository does not assert any real feed deployment exists for the selected assets on HyperEVM.

A settlement executor pays gas and calls `settle`; contracts do not schedule their own execution. The core rechecks active/unexpired commitment, active loan, immutable borrower/collateral amount/maturity, capped debt and current debt limit, eligibility, and fresh price. Snapshot authenticity remains an adapter trust boundary.

Purchase price = floor(price × (10,000 − discountBps) / 10,000). If full collateral purchase value covers current debt, payment equals debt and purchased collateral = ceil(debt × collateralUnit / purchasePrice). Only that amount is delivered to the buyer; surplus returns to borrower. Otherwise, all collateral is delivered, payment = floor(collateral amount × purchasePrice / collateralUnit), and unpaid debt becomes explicit bad debt. The buyer takes collateral outright, never the borrower's debt.

Rounding favors conservative valuation and allows less than one collateral base unit of overdelivery on full-debt purchases. Zero purchase price, zero payment or zero purchased amount reverts; dust cannot be seized for free. Tiny unpurchasable positions can repay or follow the uncovered-default path after expiry. Debt-token and collateral decimals are handled in base units throughout.

Core updates terminal accounting, transfers the exact stablecoin payment to the market pinned in the reservation, then invokes delivery. The market credits liquidity, closes the loan, records any shortfall and returns surplus. Core verifies buyer balance increased by at least purchased collateral (it can increase further if buyer is also borrower) and the final loan snapshot is inactive with zero debt/collateral. Any failed token transfer, short delivery or callback reverts every effect, including payment.

## Lifecycle boundaries and races

`None → Active → Repaid | Expired | Settled`.

- Only the original adapter can request repayment release; snapshot must be inactive with zero debt and zero collateral. No price or integration-pointer validation is read on release, so changed integration configuration does not itself prevent releasing an otherwise terminal loan.
- Reservation expiry = loan maturity + two days. Settlement requires `now < expiry`; permissionless expiry release requires `now >= expiry`.
- Expiry releases capacity and does not mutate a loan. An expired reservation can no longer settle.
- Repayment still works after expiry, including if nobody has yet called `expire`. An already Expired reservation stays Expired in core history; market events record the later repayment.
- After both maturity and expiry, the lender may `recoverUncovered`: close the loan and receive collateral in kind. Full unpaid debt is recorded as **gross bad debt** with separate recovered collateral quantity. No imaginary stablecoin recovery is credited. Price freshness is not required for this transfer.
- Repayment, settlement and uncovered recovery are terminal alternatives. Transaction ordering determines which succeeds; subsequent terminal actions revert. Duplicate settlements and duplicate reservations fail.

Renewal, replacement capacity, partial repayment/liquidation, borrowing top-ups and reassignment of active commitments are not implemented.

## Security boundaries

Supported tokens must honestly report balances and provide conventional non-rebasing, exact ERC-20 transfers. ExactTransfer checks both sender and recipient deltas and rejects observable taxes/short delivery; it cannot secure arbitrarily dishonest balance reporting, changing token semantics or rebases. Blacklisting/paused tokens can block settlement or repayment. Every mutating entry point across custody, core, market and adapter is guarded, and terminal effects precede token callbacks.

Freshness and round checks do not prove a fresh price is economically correct. Feed manipulation, governance compromise or poor liquidity can still harm both parties. MockFeed is intentionally permissionless/mutable and MockToken permissionlessly mintable. They are exclusively for demonstrations/tests. Production integration requires separately verified addresses, feed behavior and bounds, liquidity/risk calibration, and independent review.

A dishonest buyer-selected adapter can fabricate eligibility or refuse service. Delivery checks prevent payment without observable collateral delivery but do not make arbitrary adapters truthful. A malicious adapter cannot accept a different adapter's offers, pull fees from arbitrary approved accounts, or bypass global vault balances.

Transaction timestamps govern freshness and multi-day deadlines. Small validator timestamp variation and absent executors remain execution risks. Unused capital unlocks at expiry even if a lender missed liquidation. Reserved liquidity is not guaranteed debt recovery. There is no integration with HyperCore perpetual liquidations.
