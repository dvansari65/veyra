'use client';

import { useEffect, useRef, useState } from 'react';
import Image from 'next/image';
import { Arrow } from './brand';

export function Navigation({ documentation }: { documentation: string }) {
  const [open, setOpen] = useState(false);
  const toggle = useRef<HTMLButtonElement>(null);
  const header = useRef<HTMLElement>(null);
  useEffect(() => {
    if (!open) return;
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setOpen(false);
        toggle.current?.focus();
      }
    };
    const onPointer = (event: PointerEvent) => {
      if (!header.current?.contains(event.target as Node)) setOpen(false);
    };
    const desktop = window.matchMedia('(min-width: 761px)');
    const onDesktop = () => {
      if (desktop.matches) setOpen(false);
    };
    document.addEventListener('keydown', onKey);
    document.addEventListener('pointerdown', onPointer);
    desktop.addEventListener('change', onDesktop);
    return () => {
      document.removeEventListener('keydown', onKey);
      document.removeEventListener('pointerdown', onPointer);
      desktop.removeEventListener('change', onDesktop);
    };
  }, [open]);
  return (
    <header ref={header} className="site-header">
      <div className="header-inner shell">
        <a className="brand navbar-brand" href="#top" aria-label="Veyra home">
          <Image
            className="navbar-mascot"
            src="/veyra-gecko-navbar.webp"
            width={56}
            height={56}
            alt=""
            loading="eager"
            unoptimized
            draggable={false}
          />
          <span className="navbar-wordmark">veyra.</span>
        </a>
        <nav className="desktop-nav" aria-label="Main navigation">
          <a href="#how-it-works">How it works</a>
          <a href="#built-for">Who it’s for</a>
          <a href="#faq">FAQs</a>
        </nav>
        <a className="button button-nav" href={documentation}>
          Read the docs <Arrow diagonal />
        </a>
        <button
          ref={toggle}
          className="menu-toggle"
          aria-expanded={open}
          aria-controls="mobile-navigation"
          aria-label={open ? 'Close navigation' : 'Open navigation'}
          onClick={() => setOpen(!open)}
        >
          <span />
          <span />
        </button>
      </div>
      <nav
        id="mobile-navigation"
        className="mobile-nav"
        aria-label="Mobile navigation"
        hidden={!open}
        onClick={() => setOpen(false)}
        onBlur={(event) => {
          if (!event.currentTarget.contains(event.relatedTarget as Node)) setOpen(false);
        }}
      >
        <a href="#how-it-works">How it works</a>
        <a href="#built-for">Who it’s for</a>
        <a href="#faq">FAQs</a>
        <a href={documentation}>
          Read the docs <Arrow diagonal />
        </a>
      </nav>
    </header>
  );
}
