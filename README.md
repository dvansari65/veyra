# Veyra

Reserve funded collateral buyers **before** a participating lending market issues loans.

The first Solidity implementation is here: buyer custody, immutable offers, exclusive reservations, oracle pricing, atomic settlement, a reference lending market and adapter, and Foundry tests. Target: **Hyperliquid's HyperEVM**. No live deployment or existing lending-protocol integration is claimed.

**Current phase: smart contracts only.** The later frontend will use **TypeScript + Next.js**. There is no placeholder frontend or SDK. Tooling uses Node.js and Foundry; no Python is required.

## Run

Prerequisites: Node.js 22.19+, pnpm 10.15.1, Foundry 1.7.1. The compiler installer supports macOS (Rosetta for Apple Silicon) and Linux x86_64.

```sh
pnpm run setup                 # locked dependencies + checksum-verified local Solidity compiler
pnpm check                 # format, build with sizes, unit/fuzz/invariant tests
pnpm demo                  # local end-to-end simulation, no broadcast
pnpm --filter @veyra/contracts deploy:dry
```

Solidity 0.8.30, Cancun, optimizer 200. OpenZeppelin Contracts 5.4.0 and forge-std 1.9.7 (commit pinned) are locked. Compiler and package cache stay in ignored `.tooling/`.

## How funds move

1. A **lender** separately funds the lending market.
2. A **buyer** deposits stablecoins in Veyra and publishes an offer authorizing a specific adapter.
3. A **borrower** posts collateral and authorizes an upfront fee with a maximum limit. The market reserves the loan's maximum contractual debt before disbursing lender principal. Failure rolls everything back.
4. An executor can settle an eligible loan. Veyra pays with reserved buyer capital; the market delivers collateral to the buyer and returns surplus collateral to the borrower in the same transaction.
5. Repayment releases the reservation. Expiry unlocks buyer funds but does not itself close or liquidate the loan.

Buyer capital is **not** the original loan principal. A reservation supplies buying liquidity; collateral losses can still cause lender bad debt.

## Contracts

| Contract | Responsibility |
| --- | --- |
| `BuyerVault` | Internal custody/accounting base: available versus reserved balances; available-only withdrawals |
| `ReservationManager` | Deployable core: offers, reservations, fee collection, expiry, repayment release and settlement under one reentrancy guard |
| `PriceOracle` | Immutable asset pair, two USD feeds, decimals, rounding and feed validity checks |
| `ReferenceLendingAdapter` | Immutable, authenticated bridge to one reference market |
| `DemoLendingMarket` | Lender liquidity, fixed-term debt, borrower collateral, repayments and explicit shortfalls |
| `src/mocks/*` | Clearly test-only, freely mintable tokens and mutable feeds |

No upgrade proxy, admin drain, mutable active terms, yield strategy or protocol fee recipient. Upfront fees go directly to the buyer and are tracked separately from capital. The core consolidates the planned SettlementEngine to avoid cross-module accounting and locking complexity.

## Demo

`pnpm demo` verifies these steps with assertions:

- Buyer funds 100,000 test USDC; lender independently funds two markets.
- Market A reserves 69,999.30; Market B's attempt to reserve another 39,999.75 reverts atomically.
- First loan is repaid; capacity is released and collateral returned.
- A second loan liquidates after a mock price decline. Buyer pays 3,800 test USDC for 100 test wrapped HYPE; market records a 1,200 shortfall.

The mock tokens are **not real USDC or wrapped HYPE**, and the mutable feeds are unsuitable for real funds.

## Layout and documentation

```text
packages/contracts/    Solidity sources, Foundry tests and scripts
scripts/               Node.js compiler setup
.github/workflows/     Contract verification CI
docs/                 Contract specification and development notes
```

- [Contract specification and trust boundaries](docs/CONTRACTS.md)
- [Development, verification and test deployment](docs/DEVELOPMENT.md)
- [Follow-up contract review and reproduced findings](docs/REVIEW.md)

## Scope and limitations

V1 supports one asset pair per core, one buyer reservation per loan, fixed-duration capped-interest loans, full repayment and terminal liquidation. Partial liquidation, top-ups, renewal/replacement, LP share accounting, frontend and SDK are deferred.

Adapters are explicitly trusted by buyers. The core cannot make a dishonest integration's reported debt truthful. Real integrations need protocol-specific validation, real token/feed address verification and independent security review. No integration with Hyperliquid's native perpetual liquidation system is claimed.

**Unaudited. Passing tests are not a security guarantee. No production deployment or real funds.**

## License

No license has been selected. Project sources use `SPDX-License-Identifier: UNLICENSED`; this does not grant an open-source license. Dependencies retain their own licenses.
