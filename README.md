# Veyra

**Reserve funded collateral buyers before issuing loans.**

Veyra is a proposed liquidation liquidity marketplace on HyperEVM. It connects lending markets with buyers who commit stablecoins to purchase collateral under agreed conditions. Participating lenders can reserve that capacity before extending credit, with shared accounting designed to prevent the same funds from backing multiple commitments.

> **Status: design stage.** This repository currently contains project documentation. Smart contracts, lending integrations, a frontend, and deployments have not been implemented.

## Why Veyra

A collateral valuation describes what an asset is worth according to a pricing mechanism. It does not establish that a buyer will purchase a specific quantity when a loan needs liquidation.

Veyra aims to make that buying capacity explicit: funded, allocated to a lending obligation, and governed by purchase terms agreed in advance. Lenders gain visibility into reserved capacity, while buyers receive reservation fees in exchange for committing capital and accepting collateral purchase risk.

## How it works

1. **Fund an offer.** A buyer deposits supported stablecoins and defines acceptable collateral, purchase pricing, maximum spend, reservation duration, and fees.
2. **Reserve capacity.** An integrated lending market allocates available funds to a specific loan or bounded set of obligations before issuing credit.
3. **Maintain the commitment.** Reserved funds remain unavailable for withdrawal or allocation elsewhere while the commitment is active.
4. **Execute an eligible purchase.** When the lending market's liquidation rules and the reservation's purchase conditions are satisfied, an execution transaction exchanges committed funds for the specified collateral through the market integration.
5. **Release or renew.** Repayment or another permitted release condition frees the allocation. Reservations approaching expiry require explicit renewal or replacement handling.

The lender supplies the borrower's loan. The buyer's reserved funds finance a potential collateral purchase; they are separate from the loan principal.

### Example

A buyer deposits **100,000 USDC**. Market A reserves **70,000 USDC**, leaving **30,000 USDC** available for Market B. An attempt by Market B to reserve **40,000 USDC** must fail.

If a qualifying liquidation in Market A requires a **20,000 USDC** purchase, settlement transfers that amount in exchange for the agreed collateral. The remaining allocation is updated according to the reservation terms.

These amounts illustrate reservation accounting, not recommended lending parameters or promised returns.

## Participants

| Participant | Role |
| --- | --- |
| Borrower | Deposits collateral and borrows from a participating lending market. |
| Lending market | Issues loans, defines liquidation eligibility, and integrates reservation and settlement checks. |
| Collateral buyer | Commits purchase capital, receives agreed fees, and takes ownership of purchased collateral. |
| Transaction executor | Submits eligible settlement transactions; contracts must verify the conditions independently. |

## Planned architecture

| Component | Responsibility |
| --- | --- |
| Funding vault | Custody supported buyer assets and account for available and reserved balances. |
| Reservation registry | Record commitments, allocate capacity, and enforce lifecycle transitions. |
| Lending adapter | Connect a market's loan creation, repayment, and liquidation logic to reservations. |
| Settlement contracts | Validate purchase conditions and coordinate payment and collateral delivery. |
| Web application | Let buyers publish offers and lenders inspect capacity, terms, fees, and reservations. |

### HyperEVM deployment

The planned contracts will run on **HyperEVM**, Hyperliquid's EVM execution environment. The initial scope is a lending market and funded purchase settlement on HyperEVM.

HyperCore market data and trading may support later extensions. Those integrations require separate validation of asset support, execution timing, and failure handling. The base design does not require a HyperCore trade to fill in order to honor a funded purchase commitment.

Veyra does not currently integrate with Hyperliquid's native perpetual liquidation system or any existing lending protocol.

## Core design requirements

- **Funded commitments:** Active allocations must never exceed assets held for those commitments, accounted for separately by funding asset.
- **Exclusive allocation:** A unit of reserved capital cannot support another active reservation within Veyra.
- **Binding terms:** Collateral, pricing rules, maximum spend, expiry, and fees must be explicit and protected against unilateral changes during an active commitment.
- **Verified eligibility:** A price movement alone must not authorize a purchase. Settlement must satisfy the integrated lending market's liquidation rules and the reservation terms.
- **Single settlement:** Repeated calls must not pay twice for the same purchase or reuse already consumed capacity.
- **Payment against delivery:** Settlement must enforce delivery of the agreed collateral in exchange for payment. The initial same-chain design should make both transfers atomic.
- **Controlled release:** Repayment, partial settlement, cancellation, and expiry must have explicit rules for releasing funds.
- **Safe expiry handling:** Reservation expiry must not itself liquidate a healthy loan. The lending integration must define how continuing loans are handled when coverage ends.

These are implementation and verification targets, not guarantees provided by the current repository. Double-booking prevention applies to funds held and accounted for by Veyra; it does not establish exclusivity over unrelated external assets.

## Economics and risk

Buyers would earn negotiated reservation fees for tying up capital and accepting a conditional obligation to buy collateral. The fee payer and payment schedule must be agreed by each participating market. A potential protocol revenue model is a disclosed share of those fees.

The central economic question is whether fees can attract buyers at a cost lenders are willing to pay. Purchased collateral may fall further in value, and resale liquidity may be limited. Reserved buying capacity does not guarantee full debt recovery or eliminate bad debt.

Pricing integrity, supported token behavior, contract correctness, transaction execution, and reservation expiry are all material design concerns. Reserved capital must remain available for its commitment rather than being silently reused for lending, trading, or other strategies.

## Development roadmap

- [ ] Validate purchase terms and fee expectations with a lending team and prospective buyers.
- [ ] Specify reservation states, pricing rules, expiry policy, and accounting invariants.
- [ ] Implement funding, reservation, and settlement contracts.
- [ ] Build a reference lending market and adapter for the complete loan lifecycle.
- [ ] Test overbooking, partial purchases, duplicate execution, repayment, expiry, and invalid liquidation attempts.
- [ ] Deliver a HyperEVM testnet demo with a buyer and lender interface.
- [ ] Pilot an integration with a lending protocol and evaluate the economics.
- [ ] Complete independent security review before accepting production funds.

## Repository and development

```text
.
├── README.md
└── .gitignore
```

There is no runnable application, dependency installation, test suite, or deployment address yet. Setup commands will be added with the first implementation.

Design feedback and integration proposals are welcome through [GitHub issues](https://github.com/dvansari65/veyra/issues). Useful proposals identify the lending market, collateral and funding assets, required purchase terms, and integration constraints.

## References

- [HyperEVM developer documentation](https://hyperliquid.gitbook.io/hyperliquid-docs/for-developers/hyperevm)
- [Interacting with HyperCore](https://hyperliquid.gitbook.io/hyperliquid-docs/for-developers/hyperevm/interacting-with-hypercore)

## License

No license has been selected yet. This repository does not currently grant an open-source license.
