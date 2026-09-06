# Development and verification

## Stack and reproducibility

Smart contracts: Solidity 0.8.30, Foundry 1.7.1, OpenZeppelin 5.4.0. Future frontend: TypeScript + Next.js; implementation is deferred. Node.js 22.19+ and pnpm 10.15.1 drive workspace commands. No Python dependency.

Run `pnpm run setup` from repository root. It installs the frozen pnpm lockfile and verifies/downloads native solc into `.tooling/solc` against a platform-specific SHA-256. forge-std is pinned to commit `77041d2ce690e692d6e03cc812b57d1ddaa4d505` (1.9.7). `.npmrc` fixes the hoisted dependency layout used by Foundry remappings. No global compiler installation is required. Apple Silicon needs Rosetta for the upstream macOS x86_64 solc binary; Linux setup requires x86_64.

Commands:

```sh
pnpm format
pnpm check
FOUNDRY_PROFILE=ci pnpm test
pnpm demo
pnpm --filter @veyra/contracts deploy:dry
```

Default fuzz campaigns use 256 cases and invariants use 128 runs × 64 calls. CI uses 2,048 fuzz cases and 256 invariant runs × 128 calls, with unexpected handler reverts treated as failures. Five invariants exercise changing prices/time, two buyers, deposits, withdrawals, donations, borrowing through two markets, repayment, expiry, liquidation and uncovered recovery. Per-buyer conservation and outstanding principal are checked independently. Invariants are randomized checks, not formal proofs.

Tests cover authorization, borrower fee limits, cross-market rollback, same IDs across markets, available-only withdrawals, immutable accepted terms, cancellation, repayment/settlement ordering, expiry boundaries, stale/future/invalid feeds, stablecoin depeg, decimal fuzzing, capped interest, rounding, shortfalls, duplicate settlement, malicious token/adapter callbacks and failed collateral delivery. Build emits deployable bytecode sizes. Foundry's timestamp lint warnings are expected at explicit oracle/deadline boundaries and are not hidden; their implications are documented in the specification.

## Test-only deployment

The deployment script creates **new mock assets and mutable feeds** and permits only local chain 31337 or HyperEVM testnet 998. It refuses mainnet. No existing asset/feed addresses are assumed. The configured Cancun target matches [Hyperliquid's documented HyperEVM execution version](https://hyperliquid.gitbook.io/hyperliquid-docs/for-developers/hyperevm), which also documents chain ID 998 and testnet RPC.

Local dry run (no account or funds required):

```sh
pnpm --filter @veyra/contracts deploy:dry
```

To simulate deployment against testnet, first set `LENDER` to the intended immutable lender wallet and run from `packages/contracts`:

```sh
forge script script/Deploy.s.sol:Deploy \
  --rpc-url https://rpc.hyperliquid-testnet.xyz/evm -vvv
```

This simulates only. A separately authorized testnet broadcast can add `--broadcast --account <local-keystore-name>` with an appropriately funded test wallet. Do not put private keys in source code or command-line history. The default lender `0xA11CE` is for local simulation only; the script requires explicit LENDER on testnet. `--account` refers to a local Foundry keystore, not a repository secret.

The local `Demo` script uses simulated actors and mock price changes, and cannot be broadcast as a real multi-wallet workflow. It asserts independent lender/buyer funding, overbooking rejection, repayment, liquidation, shortfall and final custody conservation. Printed dry-run addresses are simulation outputs, not deployed addresses.

Nothing has been broadcast or production-deployed. No explorer verification or real integration is claimed. Before a real asset integration, confirm token/feed addresses and behavior on the intended chain, implement the actual protocol's adapter, calibrate economic parameters and obtain independent security review. No repository license has been chosen.

## Initial verification result — 2026-09-06 (before follow-up review)

Local `FOUNDRY_PROFILE=ci pnpm check` passed: **49 tests**, including three fuzz tests with 2,048 inputs each and four invariants with 256 runs / 32,768 handler calls each, with zero handler reverts. Formatting and build passed. Both the end-to-end demo and deployment simulation passed; no transactions were broadcast.

Deployable runtime sizes: ReservationManager 10,167 bytes; DemoLendingMarket 8,164; ReferenceLendingAdapter 2,537; PriceOracle 1,653. Each is below the 24,576-byte EVM runtime limit. These checks do not constitute an audit or formal verification.

## Follow-up review verification

After the [follow-up review](REVIEW.md), the CI-profile check passes **56 tests**, with five fuzz tests and five stateful invariants. The latter now cover two buyers, two markets, donations and outstanding principal. Runtime core size is now **10,424 bytes**; the other production runtime sizes above are unchanged. Demo and deployment simulation both pass. See the review for before/after reproductions, the isolated guard-mutation test and remaining trust boundaries.
