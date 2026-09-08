'use client';

import { useEffect } from 'react';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

export function PageMotion() {
  useEffect(() => {
    gsap.registerPlugin(ScrollTrigger);
    const site = document.querySelector<HTMLElement>('.site');
    if (!site) return;
    const media = gsap.matchMedia(site);
    media.add('(prefers-reduced-motion: no-preference)', () => {
      // Measure a stationary wrapper; animate its section independently of child reveals.
      gsap.utils.toArray<HTMLElement>('[data-scroll-section]', site).forEach((stage) => {
        const section = stage.firstElementChild;
        if (!(section instanceof HTMLElement)) return;
        const distance = Number(stage.dataset.scrollDistance) || 40;
        const travel = () => Math.round(distance * (window.innerWidth <= 760 ? 0.35 : 1));
        const settle = stage.dataset.scrollSettle === 'true';

        gsap.fromTo(
          section,
          { y: travel },
          {
            y: () => (settle ? 0 : -travel()),
            ease: 'none',
            scrollTrigger: {
              trigger: stage,
              start: 'clamp(top bottom)',
              end: settle ? 'clamp(bottom bottom)' : 'clamp(bottom top)',
              scrub: 0.85,
              invalidateOnRefresh: true,
            },
          },
        );
      });

      const intro = gsap.timeline({ defaults: { ease: 'power3.out', duration: 0.8 } });
      intro
        .from('.hero-line', { y: 28, opacity: 0, stagger: 0.09, clearProps: 'all' })
        .from('.hero-enter', { y: 15, opacity: 0, stagger: 0.07, clearProps: 'all' }, 0.12)
        .from(
          '.hero-link',
          { x: -24, y: 14, opacity: 0, stagger: 0.09, duration: 0.9, clearProps: 'all' },
          0.18,
        );

      gsap.utils.toArray<HTMLElement>('[data-reveal]', site).forEach((element) => {
        gsap.from(element, {
          y: 24,
          opacity: 0,
          duration: 0.75,
          ease: 'power2.out',
          clearProps: 'all',
          scrollTrigger: { trigger: element, start: 'top 94%', once: true },
        });
      });
      gsap.from('.protocol-note', {
        '--line-progress': 0,
        duration: 1.3,
        ease: 'power2.out',
        scrollTrigger: { trigger: '.protocol-note', start: 'top 90%', once: true },
      });
      gsap.fromTo(
        '.scroll-progress',
        { scaleX: 0 },
        {
          scaleX: 1,
          ease: 'none',
          scrollTrigger: { trigger: site, start: 'top top', end: 'bottom bottom', scrub: 0.25 },
        },
      );

      const focusReveal = (event: FocusEvent) => {
        const container = (event.target as Element | null)?.closest<HTMLElement>('[data-reveal]');
        if (container) {
          gsap.killTweensOf(container);
          gsap.set(container, { clearProps: 'all' });
        }
      };
      site.addEventListener('focusin', focusReveal);
      const refresh = () => ScrollTrigger.refresh();
      site.addEventListener('toggle', refresh, true);
      site.addEventListener('faq:layout', refresh);
      document.fonts.ready.then(() => {
        if (site.isConnected) refresh();
      });
      return () => {
        site.removeEventListener('focusin', focusReveal);
        site.removeEventListener('toggle', refresh, true);
        site.removeEventListener('faq:layout', refresh);
      };
    });
    media.add('(min-width: 1024px) and (prefers-reduced-motion: no-preference)', () => {
      gsap.to('.hero-links', {
        y: -16,
        ease: 'none',
        scrollTrigger: { trigger: '.hero', start: 'top top', end: 'bottom top', scrub: 0.8 },
      });
    });
    return () => media.revert();
  }, []);

  return <div className="scroll-progress" aria-hidden="true" />;
}
