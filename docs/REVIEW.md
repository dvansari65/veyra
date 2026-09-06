# Follow-up smart-contract review — 2026-09-06

## Result and scope

Two core validation gaps were reproduced and fixed. The shipped ReferenceLendingAdapter has immutable pointers and DemoLendingMarket reports zero collateral on closure, so neither reproduction is an exploit against that unchanged reference integration. Both reproduce with a nonconforming, buyer-selected adapter. This distinction matters: the review does not establish a critical vulnerability in the reference market or make arbitrary adapters trustworthy.

Reviewed the production Solidity sources, reference adapter/market lifecycle, oracle normalization, fee authorization, allocation accounting, token-transfer boundaries, unit/fuzz/invariant tests and contract documentation. No changes were made to lending economics, interest, LTVs, discounts, expiry policy, frontend or deployment targets.

## R1 — Integration configuration was not bound through the lifecycle

**Confirmed conditional integration risk; fixed.** Before this change, `createOffer` validated the adapter's advertised core, oracle, token pair and market. Neither `reserve` nor `settle` repeated those checks, and settlement obtained the payment destination from a fresh `adapter.market()` call rather than accepted terms.

Reproduction against the original sources: create and accept an offer through a mutable integration; change its advertised market; settle at maturity while delivering the expected collateral. The original core successfully sent **5,000 test USDC to the replacement address**, while the originally selected market received none. Separately, the regression tests showed changed oracle/debt-asset pointers were accepted without reverting. These require a mutable or dishonest selected adapter; an unrelated caller cannot change the immutable reference adapter.

Fix: store the market in both Offer and Reservation, revalidate advertised market/core/oracle/asset pointers before acceptance and settlement, and send payment only to the stored market. Configuration drift reverts with `InvalidIntegration`. Repayment release and expiry deliberately remain independent of these pointer checks and of fresh prices, so drift does not by itself trap releasable capital.

Tests: `testFuzzChangedIntegrationRejectedBeforeAcceptance`, `testFuzzChangedIntegrationCannotSettleAcceptedTerms`, and positive tests covering restoration, repayment release and expiry. The five advertised pointer fields are exercised by fuzz inputs. The two negative regression tests failed on the original code and pass after the fix.

## R2 — Repayment release accepted an inconsistent terminal snapshot

**Confirmed validation inconsistency; fixed.** `settle` required the final snapshot to be inactive with zero debt and collateral. `release` previously checked only inactive/zero debt, accepting a snapshot that still attributed collateral to the loan.

Reproduction: accept a reservation, report inactive/zero debt while leaving 100 collateral tokens on the loan snapshot, then release. The original core released the allocation and marked it Repaid. This is not proof that a third party can seize reference-market collateral: the issue is accepting a nonconforming adapter's terminal report.

Fix: require zero collateral in addition to inactive/zero debt for repayment release. Document the common terminal snapshot contract in ILendingAdapter. The reference market already meets it. `testReleaseRejectsOutstandingCollateralSnapshot` failed before the fix and passes afterward.

## T1 — Callback tests could pass without the intended guards

**Confirmed test weakness; fixed.** The original deposit/withdraw callback test asserted only that the nested call failed. Its callback actor lacked an allowance/balance, so the call could fail for reasons unrelated to reentrancy protection.

Mutation check in an isolated, ignored copy: remove the vault's deposit/withdraw `nonReentrant` modifiers. The old test still **passed**; the strengthened test **failed** because it observed an allowance error rather than `ReentrancyGuardReentrantCall`. The production guards were never removed. Callback fixtures now retain return data, and the relevant tests assert the exact OpenZeppelin guard error, including settlement callbacks into core/market.

## T2 — Accounting coverage and donation consistency

The original stateful campaign used only one buyer. It could verify aggregate conservation but could not detect attribution moving between buyers. The campaign now uses **two buyers and two markets**, checks each buyer's available/reserved balances against independent deposit/withdraw/spend records, compares active allocations against amounts recorded at issuance, and checks outstanding principal against active loan inputs.

The previous collateral equality invariant also excluded unsolicited donations even though donations are documented as surplus. The campaign now includes donations and asserts collateral custody **covers** loan liabilities. Donations must not credit available buyer balances or lender liquidity. Production accounting did not need a change.

## Final verification

- `FOUNDRY_PROFILE=ci pnpm check`: **56 tests passed**, zero failed. Formatting and compilation passed.
- Five fuzz tests: 2,048 inputs each.
- Five stateful invariants: 256 runs × 128 calls = 32,768 handler calls per invariant, zero unexpected handler reverts. Handler calls include bounded no-ops when lifecycle preconditions are absent; this is not a formal proof.
- `pnpm demo`: all end-to-end assertions passed, including cross-market overbooking rejection, repayment, liquidation and shortfall accounting.
- Deployment dry run passed. Nothing was broadcast.
- Runtime bytecode: ReservationManager **10,424 bytes**, DemoLendingMarket **8,164**, ReferenceLendingAdapter **2,537**, PriceOracle **1,653**. All remain below 24,576 bytes.

The Offer/Reservation getter ABI now includes the pinned market field. Future clients must use rebuilt ABIs. There are no existing live deployments or frontend clients in this repository to migrate.

## Remaining boundaries

No confirmed critical/high-severity exploit was found in the immutable reference integration during this review. That is a bounded review result, not a security guarantee or independent audit.

Adapters still supply trusted loan snapshots and can lie while keeping their public configuration getters unchanged. Exact token balance checks assume honest, conventional non-rebasing tokens; blacklists/pauses or blocked collateral recipients can prevent completion. Oracle freshness is not proof of price correctness. The freely mutable feeds/tokens remain test-only. Feed outages can block liquidation while repayment/expiry remain available; missed execution can leave uncovered debt. Existing protocol integrations, production feed/token verification and independent security review remain outstanding.
