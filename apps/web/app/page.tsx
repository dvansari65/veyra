import Image from 'next/image';
import type { ReactElement } from 'react';
import { Arrow, Check, ReserveIcon } from '@/components/brand';
import { Navigation } from '@/components/navigation';
import { PageMotion } from '@/components/motion';
import { Faq } from '@/components/faq';
import footerSignature from '@/public/veyra-footer-signature.webp';
import footerSignatureSmall from '@/public/veyra-footer-signature-640.webp';
import footerSignatureMedium from '@/public/veyra-footer-signature-1280.webp';

const repository = 'https://github.com/dvansari65/veyra';
const documentation = `${repository}/blob/main/docs/CONTRACTS.md`;

const steps = [
  {
    title: 'Commit capital.',
    body: 'Buyers deposit stablecoins and choose the collateral, discount, duration, and adapter they accept.',
    tag: 'Buyer → Funded offer',
  },
  {
    title: 'Reserve before lending.',
    body: 'A participating market reserves buyer capital for one loan before disbursing principal. The lender funds the loan separately.',
    tag: 'Market → Exclusive reservation',
  },
  {
    title: 'Settle in one transaction.',
    body: 'On an eligible liquidation, reserved funds and collateral change hands atomically. Repayment releases the reservation.',
    tag: 'Reserved funds ↔ Collateral',
  },
];

const questions = [
  {
    question: 'What does Veyra actually do?',
    answer:
      'Veyra is a capital reservation protocol for lending markets. It connects buyers willing to purchase collateral with markets that want committed buying liquidity before issuing a loan. The buyer’s allocation is reserved exclusively for that loan until settlement, repayment, or expiry.',
  },
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
    question: 'Does reserved liquidity guarantee debt recovery?',
    answer:
      'No. Veyra reserves buying liquidity. If the collateral’s purchase value is lower than the debt, the market can still incur a loss. Smart-contract, oracle, token, adapter, and execution risks remain.',
  },
  {
    question: 'What happens when a reservation expires?',
    answer:
      'At expiry, anyone can release the allocation back to the buyer’s available balance. Expiry does not automatically liquidate or close the loan. The lending market must account for any uncovered debt.',
  },
  {
    question: 'Can I use Veyra today?',
    answer:
      'Veyra is in development, with test assets and a reference lending market. It has not been independently audited or deployed for production. Wallet connection and live contract interaction are not yet available. Veyra is designed for HyperEVM and does not integrate with Hyperliquid’s native perpetual liquidation system.',
  },
];

export default function Home() {
  return (
    <div id="top" className="site">
      <PageMotion />
      <a className="skip-link" href="#main">
        Skip to content
      </a>
      <Navigation documentation={documentation} />
      <main id="main">
        <section className="hero-section" aria-labelledby="hero-title">
          <div className="hero shell">
            <h1 id="hero-title" className="hero-title">
              <span className="hero-line">Reserve first.</span>
              <span className="hero-line hero-line-accent">Lend next.</span>
            </h1>
            <div className="hero-bottom">
              <figure className="hero-commitments">
                <div className="hero-links" aria-hidden="true">
                  <span className="hero-link">
                    <span className="hero-link-shape" />
                  </span>
                  <span className="hero-link">
                    <span className="hero-link-shape" />
                  </span>
                  <span className="hero-link">
                    <span className="hero-link-shape" />
                  </span>
                </div>
                <figcaption className="hero-enter">
                  Buyer commitments. Connected to lending.
                </figcaption>
              </figure>
              <div className="hero-copy">
                <p className="hero-description hero-enter">
                  Put collateral buyers in place before a loan begins. Veyra reserves their capital
                  for one loan, while lenders fund the loan separately.
                </p>
                <div className="hero-actions hero-enter">
                  <a className="button button-primary" href="#how-it-works">
                    Explore the protocol <Arrow diagonal />
                  </a>
                </div>
              </div>
            </div>
            <div className="hero-meta hero-enter">
              <p>Designed for HyperEVM</p>
              <p>In development · Unaudited</p>
            </div>
          </div>
        </section>
        <div className="principles shell" aria-label="Protocol principles">
          <span>
            <Check /> Funded before origination
          </span>
          <span>
            <Check /> Exclusively reserved
          </span>
          <span>
            <Check /> Atomic settlement
          </span>
          <a href="#how-it-works">
            Discover how <Arrow down />
          </a>
        </div>
        <ScrollSection distance={56}>
          <section
            id="how-it-works"
            className="section shell protocol-section"
            aria-labelledby="protocol-title"
          >
            <div className="section-intro" data-reveal>
              <div>
                <p className="eyebrow section-label">
                  <span>01</span> How it works
                </p>
                <h2 id="protocol-title">
                  Buying liquidity.
                  <br />
                  <span>Already in place.</span>
                </h2>
              </div>
              <p className="section-description">
                Liquidation needs a buyer. Veyra brings that commitment forward, connecting funded
                collateral buyers with lending markets before a loan is issued.
              </p>
            </div>
            <div className="steps-grid">
              {steps.map((step, index) => (
                <article className="step-card" key={step.title} data-reveal>
                  <div className="step-top">
                    <span className="step-number">0{index + 1}</span>
                    <StepDiagram step={index} />
                  </div>
                  <h3>{step.title}</h3>
                  <p>{step.body}</p>
                  <div className="step-tag">{step.tag}</div>
                </article>
              ))}
            </div>
            <div className="protocol-note" data-reveal>
              <ReserveIcon />
              <p>
                <strong>One allocation. One commitment.</strong> Reserved capital cannot back
                another loan at the same time.
              </p>
              <a className="text-link" href={documentation}>
                Under the hood <Arrow diagonal />
              </a>
            </div>
          </section>
        </ScrollSection>
        <ScrollSection distance={64}>
          <section id="built-for" className="audience-section" aria-labelledby="audience-title">
            <div className="section shell">
              <div className="section-intro" data-reveal>
                <div>
                  <p className="eyebrow section-label">
                    <span>02</span> Who it’s for
                  </p>
                  <h2 id="audience-title">
                    Two sides.
                    <br />
                    <span>One clear commitment.</span>
                  </h2>
                </div>
                <p className="section-description">
                  A shared foundation for buyers who want defined purchase terms and markets that
                  want buying liquidity reserved ahead of time.
                </p>
              </div>
              <div className="audience-grid">
                <article className="audience-card" data-reveal>
                  <div className="audience-card-top">
                    <span className="role-icon">
                      <BuyerIcon />
                    </span>
                    <span className="eyebrow">Collateral buyers</span>
                  </div>
                  <h3>
                    Put your capital
                    <br />
                    behind your terms.
                  </h3>
                  <p>
                    Define what you’re willing to buy and the terms you accept. Receive a
                    reservation fee for committing your buying capacity.
                  </p>
                  <ul>
                    <li>
                      <Check /> Choose collateral and purchase discount
                    </li>
                    <li>
                      <Check /> Set allocation and duration limits
                    </li>
                    <li>
                      <Check /> Withdraw available, unreserved capital
                    </li>
                  </ul>
                  <a href={`${documentation}#offers-and-acceptance`} className="text-link">
                    Understand buyer offers <Arrow diagonal />
                  </a>
                </article>
                <article className="audience-card" data-reveal>
                  <div className="audience-card-top">
                    <span className="role-icon">
                      <MarketIcon />
                    </span>
                    <span className="eyebrow">Lending markets</span>
                  </div>
                  <h3>
                    Start every loan
                    <br />
                    with a buyer in place.
                  </h3>
                  <p>
                    Reserve buying capacity at origination through a market-specific adapter, with
                    settlement terms fixed for the life of the reservation.
                  </p>
                  <ul>
                    <li>
                      <Check /> Reserve before principal is disbursed
                    </li>
                    <li>
                      <Check /> Exchange capital and collateral atomically
                    </li>
                    <li>
                      <Check /> Release the reservation on repayment
                    </li>
                  </ul>
                  <a href={`${documentation}#deployment-and-authority`} className="text-link">
                    Explore market integration <Arrow diagonal />
                  </a>
                </article>
              </div>
              <p className="audience-footnote">
                Buyers select and trust a specific adapter. Reserved liquidity does not guarantee
                full debt recovery.
              </p>
            </div>
          </section>
        </ScrollSection>
        <ScrollSection distance={28}>
          <section className="section shell faq-section" id="faq" aria-labelledby="faq-title">
            <div className="faq-heading" data-reveal>
              <p className="eyebrow section-label">
                <span>03</span> The details
              </p>
              <h2 id="faq-title">
                Good questions.
                <br />
                <span>Clear answers.</span>
              </h2>
              <p className="section-description">
                A closer look at the protocol, the commitments, and what’s being built.
              </p>
              <a className="text-link" href={documentation}>
                Read the full documentation <Arrow diagonal />
              </a>
            </div>
            <Faq questions={questions} />
          </section>
        </ScrollSection>
        <ScrollSection distance={40}>
          <section className="closing-section shell" aria-labelledby="closing-title">
            <div className="closing-panel" data-reveal>
              <div className="closing-copy">
                <h2 id="closing-title">
                  Commit first.
                  <br />
                  <span>Build from there.</span>
                </h2>
              </div>
              <div className="closing-details">
                <p>Explore the design behind Veyra and follow the protocol as it takes shape.</p>
                <div className="closing-actions">
                  <a className="button button-primary" href={documentation}>
                    Explore the docs <Arrow diagonal />
                  </a>
                  <a className="text-link" href={repository}>
                    View on GitHub <Arrow diagonal />
                  </a>
                </div>
              </div>
            </div>
          </section>
        </ScrollSection>
      </main>
      <ScrollSection distance={32} settle>
        <footer className="site-footer">
          <div className="shell">
            <div className="footer-divider" aria-hidden="true">
              <svg viewBox="0 0 224 32" preserveAspectRatio="none" fill="none" focusable="false">
                <path
                  className="footer-divider-inset"
                  d="M24 24C56 24 64 8 88 8H136C160 8 168 24 200 24C168 24 160 14 136 14H88C64 14 56 24 24 24Z"
                />
                <path
                  d="M0 24H24C56 24 64 8 88 8H136C160 8 168 24 200 24H224"
                  stroke="currentColor"
                  vectorEffect="non-scaling-stroke"
                />
              </svg>
            </div>
            <div className="footer-top" data-reveal>
              <div className="footer-intro">
                <p className="footer-tagline">
                  Committed capital.
                  <br />A stronger starting point.
                </p>
                <p className="footer-network">
                  A capital reservation protocol, designed for HyperEVM.
                </p>
              </div>
              <nav className="footer-nav" aria-label="Footer navigation">
                <div className="footer-link-group">
                  <h2>Protocol</h2>
                  <a href="#how-it-works">
                    How it works <Arrow />
                  </a>
                  <a href="#built-for">
                    Who it’s for <Arrow />
                  </a>
                  <a href="#faq">
                    Common questions <Arrow />
                  </a>
                </div>
                <div className="footer-link-group">
                  <h2>Resources</h2>
                  <a href={documentation}>
                    Documentation <Arrow diagonal />
                  </a>
                  <a href={repository}>
                    GitHub <Arrow diagonal />
                  </a>
                  <a href={`${documentation}#security-boundaries`}>
                    Security &amp; risks <Arrow diagonal />
                  </a>
                </div>
              </nav>
            </div>
            <div className="footer-signature" data-reveal aria-hidden="true">
              <picture>
                <source
                  type="image/webp"
                  srcSet={`${footerSignatureSmall.src} ${footerSignatureSmall.width}w, ${footerSignatureMedium.src} ${footerSignatureMedium.width}w, ${footerSignature.src} ${footerSignature.width}w`}
                  sizes="(max-width: 760px) calc(100vw - 40px), (max-width: 1100px) calc(100vw - 64px), (max-width: 1392px) calc(100vw - 112px), 1280px"
                />
                <Image
                  className="footer-signature-art"
                  src={footerSignature}
                  alt=""
                  loading="lazy"
                  unoptimized
                  draggable={false}
                />
              </picture>
            </div>
          </div>
        </footer>
      </ScrollSection>
    </div>
  );
}

function ScrollSection({
  children,
  distance,
  settle = false,
}: {
  children: ReactElement;
  distance: number;
  settle?: boolean;
}) {
  return (
    <div
      className="scroll-section"
      data-scroll-section
      data-scroll-distance={distance}
      data-scroll-settle={settle || undefined}
    >
      {children}
    </div>
  );
}

function StepDiagram({ step }: { step: number }) {
  return (
    <svg
      className="step-diagram"
      width="128"
      height="78"
      viewBox="0 0 128 78"
      fill="none"
      aria-hidden="true"
    >
      {step === 0 ? (
        <>
          <path
            d="m30 38 34-17 34 17-34 17-34-17Z"
            fill="var(--accent)"
            stroke="currentColor"
            strokeWidth="1.25"
          />
          <path d="m30 46 34 17 34-17M30 54l34 17 34-17" stroke="currentColor" strokeWidth="1.25" />
          <path d="M64 4v13m-4-4 4 4 4-4" stroke="currentColor" strokeWidth="1.25" />
        </>
      ) : step === 1 ? (
        <>
          <rect
            x="29"
            y="16"
            width="70"
            height="47"
            rx="10"
            stroke="currentColor"
            strokeWidth="1.25"
          />
          <rect
            x="37"
            y="24"
            width="25"
            height="31"
            rx="6"
            fill="var(--accent)"
            stroke="currentColor"
            strokeWidth="1.25"
          />
          <path d="M72 26h18M72 33h12M72 46h18M72 53h12" stroke="var(--green)" strokeWidth="1.25" />
          <path d="m43 39 4 4 8-9" stroke="currentColor" strokeWidth="1.25" />
        </>
      ) : (
        <>
          <rect
            x="12"
            y="28"
            width="30"
            height="30"
            rx="10"
            fill="var(--accent)"
            stroke="currentColor"
            strokeWidth="1.25"
          />
          <path
            d="m87 28 27 0-8 30H79l8-30Z"
            fill="var(--wash)"
            stroke="currentColor"
            strokeWidth="1.25"
          />
          <path
            d="M47 35h25l-4-4m4 4-4 4M74 49H49l4-4m-4 4 4 4M46 17l6-5h23l6 5M49 67h27"
            stroke="currentColor"
            strokeWidth="1.25"
          />
        </>
      )}
    </svg>
  );
}

function BuyerIcon() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d="m3 9 9-5 9 5-9 5-9-5Zm0 5 9 5 9-5M3 18l9 5 9-5"
        stroke="currentColor"
        strokeWidth="1.4"
        strokeLinejoin="round"
      />
    </svg>
  );
}
function MarketIcon() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d="M4 21V9h7v12m0-17h9v17M2 21h20M7 12v2m0 3v2m8-12v2m2-2v2m-2 3v2m2-2v2m-2 3v2m2-2v2"
        stroke="currentColor"
        strokeWidth="1.4"
      />
    </svg>
  );
}
