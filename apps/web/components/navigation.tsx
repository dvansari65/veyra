'use client';

import { useEffect, useRef, useState } from 'react';
import { Arrow, Mark } from './icons';

const links = [
  ['The protocol', '#protocol'],
  ['How it works', '#how-it-works'],
  ['For participants', '#participants'],
] as const;

export function Navigation() {
  const [open, setOpen] = useState(false);
  const toggle = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    if (!open) return;
    const close = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setOpen(false);
        toggle.current?.focus();
      }
    };
    window.addEventListener('keydown', close);
    return () => window.removeEventListener('keydown', close);
  }, [open]);

  return (
    <header className="site-header">
      <a className="wordmark" href="#top" aria-label="Veyra home" onClick={() => setOpen(false)}>
        <Mark />
        veyra<span>.</span>
      </a>
      <nav className="desktop-nav" aria-label="Main navigation">
        {links.map(([label, href]) => (
          <a key={href} href={href}>
            {label}
          </a>
        ))}
      </nav>
      <a
        className="header-cta"
        href="https://github.com/dvansari65/veyra"
        target="_blank"
        rel="noreferrer"
      >
        Explore Veyra <Arrow diagonal />
      </a>
      <button
        ref={toggle}
        className="menu-toggle"
        aria-expanded={open}
        aria-controls="mobile-nav"
        aria-label={open ? 'Close navigation' : 'Open navigation'}
        onClick={() => setOpen(!open)}
      >
        <span />
        <span />
      </button>
      <nav id="mobile-nav" className="mobile-nav" aria-label="Mobile navigation" hidden={!open}>
        {links.map(([label, href]) => (
          <a key={href} href={href} onClick={() => setOpen(false)}>
            {label}
            <Arrow />
          </a>
        ))}
        <a
          href="https://github.com/dvansari65/veyra"
          target="_blank"
          rel="noreferrer"
          onClick={() => setOpen(false)}
        >
          View on GitHub
          <Arrow diagonal />
        </a>
      </nav>
    </header>
  );
}
