import type { Metadata } from 'next';
import '@fontsource-variable/manrope';
import '@fontsource/instrument-serif/latin-400-italic.css';
import './globals.css';

export const metadata: Metadata = {
  title: 'Veyra — A buyer. Before the loan.',
  description:
    'Funded collateral buyers, reserved before loans begin. Veyra is building committed liquidation liquidity for lending markets on HyperEVM.',
  robots: { index: true, follow: true },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
