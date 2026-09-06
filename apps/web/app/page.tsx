import { Arrow, Mark } from '@/components/icons';
import { Motion } from '@/components/motion';
import { Navigation } from '@/components/navigation';
import { ReserveVisual } from '@/components/reserve-visual';

const repository = 'https://github.com/dvansari65/veyra';
const documentation = `${repository}/blob/main/docs/CONTRACTS.md`;

const steps = [
  {
    title: 'A buyer commits.',
    body: 'Deposit stablecoins. Choose the collateral, discount, and duration you accept. Your available capital backs your offers.',
    detail: '01 / DEFINE THE TERMS',
  },
  {
    title: 'A market reserves.',
    body: 'Before issuing a loan, the market reserves buyer capital exclusively for that loan. The lender supplies the loan principal separately.',
    detail: '02 / SET CAPITAL ASIDE',
  },
  {
    title: 'Both sides settle.',
    body: 'When an eligible liquidation is executed, reserved funds and collateral change hands in one transaction. Repayment releases the reservation.',
    detail: '03 / COMPLETE THE EXCHANGE',
  },
];

const questions = [
  {
    question: 'Is buyer capital used to fund the loan?',
    answer:
      'No. The lender supplies the original loan principal. Buyers separately deposit stablecoins for a potential collateral purchase. Reserved buyer capital stays in the Veyra vault until settlement or release.',
  },
  {
    question: 'How do collateral buyers earn?',
    answer:
      'Buyers receive an agreed upfront, non-refundable reservation fee. If a qualifying liquidation is executed during the reservation, they purchase collateral at the agreed oracle-based discount. They take ownership of collateral, not the borrower’s debt.',
  },
  {
    question: 'Does this guarantee full debt recovery?',
    answer:
      'No. Veyra reserves buying liquidity. If the collateral’s purchase value is lower than the debt, the market can still incur a loss. Smart-contract, oracle, token, adapter, and execution risks remain.',
  },
  {
    question: 'What happens when a reservation expires?',
    answer:
      'At expiry, anyone can release the allocation back to the buyer’s available balance. Expiry does not automatically liquidate or close the loan. The lending market must account for any uncovered debt.',
  },
  {
    question: 'Is Veyra live?',
    answer:
      'Veyra is in development, with test assets and a reference lending market. It has not been independently audited or deployed for production. It is designed for HyperEVM and does not integrate with Hyperliquid’s native perpetual liquidation system.',
  },
];

export default function Home() {
  return (
    <>
      <a className="skip-link" href="#main">
        Skip to content
      </a>
      <Navigation />
      <main id="main">
        <section className="hero shell" id="top" aria-labelledby="hero-title">
          <div className="hero-copy">
            <p className="eyebrow hero-reveal">
              <span className="status-dot" /> COMMITTED LIQUIDITY, BY DESIGN
            </p>
            <h1 id="hero-title">
              <span className="hero-line">
                <span>A buyer.</span>
              </span>
              <span className="hero-line">
                <span>Before</span>
              </span>
              <span className="hero-line">
                <em>the loan.</em>
              </span>
            </h1>
            <div className="hero-intro hero-reveal">
              <p>
                Better lending starts on the other side.
                <br />
                Reserve funded collateral buyers before
                <br className="desktop-break" /> a loan ever begins.
              </p>
              <a className="button" href="#protocol">
                Meet Veyra <Arrow diagonal />
              </a>
            </div>
          </div>
          <ReserveVisual />
          <div className="hero-bottom hero-reveal">
            <span>LIQUIDATION LIQUIDITY. ARRANGED IN ADVANCE.</span>
            <a href="#protocol">
              Explore the idea <span aria-hidden="true">↓</span>
            </a>
          </div>
        </section>

        <section className="thesis" id="protocol" aria-labelledby="thesis-title">
          <div className="shell thesis-grid">
            <div className="section-index" data-reveal>
              <span className="eyebrow">01 / THE PRINCIPLE</span>
              <Mark />
            </div>
            <div>
              <h2 id="thesis-title" data-reveal>
                A price tells you what
                <br />
                collateral is worth.
                <br />
                <em>A buyer makes it liquid.</em>
              </h2>
              <div className="thesis-detail" data-reveal>
                <span className="small-rule" aria-hidden="true" />
                <p>
                  When markets move, finding a buyer shouldn’t be the first step. Veyra gives
                  lending markets a way to reserve funded purchase capacity before extending credit.
                </p>
              </div>
            </div>
          </div>
        </section>

        <section className="mechanism shell" id="how-it-works" aria-labelledby="mechanism-title">
          <div className="mechanism-intro" data-reveal>
            <span className="eyebrow">02 / THE MECHANISM</span>
            <h2 id="mechanism-title">
              An agreement.
              <br />
              <em>Backed by capital.</em>
            </h2>
            <p>
              Three steps connect willing buyers
              <br className="desktop-break" /> with markets that plan ahead.
            </p>
            <a className="text-link" href={documentation} target="_blank" rel="noreferrer">
              Read the specification <Arrow diagonal />
            </a>
            <div
              className="allocation"
              aria-label="Buyer deposits are split between available capital and capital reserved for individual loans."
            >
              <div className="allocation-top">
                <span>BUYER CAPITAL</span>
                <span aria-hidden="true">↘</span>
              </div>
              <div className="allocation-bars" aria-hidden="true">
                {Array.from({ length: 18 }, (_, index) => (
                  <span key={index} className={index < 10 ? 'allocated' : ''} />
                ))}
              </div>
              <div className="allocation-key">
                <span>
                  <i /> Reserved
                </span>
                <span>
                  <i /> Available
                </span>
              </div>
              <p>One allocation. One loan.</p>
            </div>
          </div>
          <div className="steps">
            <div className="step-track" aria-hidden="true">
              <span />
            </div>
            {steps.map((step) => (
              <article className="step" key={step.title} data-reveal>
                <span className="eyebrow">{step.detail}</span>
                <h3>{step.title}</h3>
                <p>{step.body}</p>
              </article>
            ))}
            <p className="expiry-note">
              At expiry, an allocation can be released. The loan remains the market’s
              responsibility.
            </p>
          </div>
        </section>

        <section className="participants" id="participants" aria-labelledby="participants-title">
          <div className="shell">
            <div className="participants-heading" data-reveal>
              <span className="eyebrow">03 / A MARKET WITH TWO SIDES</span>
              <h2 id="participants-title">
                Your capital.
                <br />
                <em>A clearer commitment.</em>
              </h2>
            </div>
            <div className="participant-grid">
              <article data-reveal>
                <div className="participant-label">
                  <span className="bracket-number">[ A ]</span>
                  <span className="eyebrow">COLLATERAL BUYERS</span>
                </div>
                <h3>
                  Be the buyer
                  <br />
                  you’d want to find.
                </h3>
                <p>
                  Choose assets you’re willing to own and the terms that work for you. Receive a
                  reservation fee for committing capital to a potential purchase.
                </p>
                <a
                  className="text-link"
                  href={`${documentation}#offers-and-acceptance`}
                  target="_blank"
                  rel="noreferrer"
                >
                  Explore buyer commitments <Arrow diagonal />
                </a>
              </article>
              <article data-reveal>
                <div className="participant-label">
                  <span className="bracket-number">[ B ]</span>
                  <span className="eyebrow">LENDING MARKETS</span>
                </div>
                <h3>
                  Plan the exit.
                  <br />
                  Then make the loan.
                </h3>
                <p>
                  Bring exclusive buyer reservations into your lending flow. Commit purchase
                  capacity at issuance, with settlement that exchanges funds and collateral
                  together.
                </p>
                <a
                  className="text-link"
                  href={`${repository}/tree/main/packages/contracts/src`}
                  target="_blank"
                  rel="noreferrer"
                >
                  Explore the reference contracts <Arrow diagonal />
                </a>
              </article>
            </div>
            <div className="participants-foot" data-reveal>
              <span className="status-dot" />
              <p>Funded buying capacity. Reserved for one loan. Never double-booked.</p>
            </div>
          </div>
        </section>

        <section className="faq shell" id="questions" aria-labelledby="faq-title">
          <div data-reveal>
            <span className="eyebrow">04 / THE DETAILS</span>
            <h2 id="faq-title">
              Worth
              <br />
              <em>understanding.</em>
            </h2>
            <a className="text-link" href={documentation} target="_blank" rel="noreferrer">
              Go deeper in the docs <Arrow diagonal />
            </a>
          </div>
          <div className="faq-list" data-reveal>
            {questions.map(({ question, answer }, index) => (
              <details key={question}>
                <summary>
                  <span className="faq-number">0{index + 1}</span>
                  <span>{question}</span>
                  <span className="faq-icon" aria-hidden="true" />
                </summary>
                <p>{answer}</p>
              </details>
            ))}
          </div>
        </section>
      </main>

      <footer className="site-footer">
        <div className="shell">
          <div className="footer-top" data-reveal>
            <div>
              <span className="eyebrow">THE NEXT STEP STARTS HERE.</span>
              <h2>
                See what’s
                <br />
                <em>taking shape.</em>
              </h2>
            </div>
            <div className="footer-invitation">
              <a className="button" href={repository} target="_blank" rel="noreferrer">
                Explore Veyra on GitHub <Arrow diagonal />
              </a>
              <p>
                In development on HyperEVM.
                <br />
                Unaudited. Not available for production use.
              </p>
            </div>
          </div>
          <div className="footer-brand" aria-hidden="true">
            veyra<span>↗</span>
          </div>
          <div className="footer-bottom">
            <span>© {new Date().getFullYear()} Veyra</span>
            <nav aria-label="Footer navigation">
              <a href={documentation} target="_blank" rel="noreferrer">
                Documentation <Arrow diagonal />
              </a>
              <a href={repository} target="_blank" rel="noreferrer">
                GitHub <Arrow diagonal />
              </a>
            </nav>
            <a href="#top">Back to top ↑</a>
          </div>
        </div>
      </footer>
      <Motion />
    </>
  );
}
