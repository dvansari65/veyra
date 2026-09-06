'use client';

import { useEffect } from 'react';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

export function Motion() {
  useEffect(() => {
    gsap.registerPlugin(ScrollTrigger);
    const media = gsap.matchMedia();

    media.add('(prefers-reduced-motion: no-preference)', () => {
      gsap
        .timeline({ defaults: { ease: 'power3.out' } })
        .from('.hero-line > *', { yPercent: 105, duration: 1.2, stagger: 0.12 })
        .from('.hero-reveal', { y: 18, opacity: 0, duration: 0.8, stagger: 0.1 }, 0.35)
        .from('.reserve-visual', { y: 24, opacity: 0, duration: 1.2 }, 0.3);

      gsap.utils.toArray<HTMLElement>('[data-reveal]').forEach((element) => {
        gsap.from(element, {
          y: 24,
          opacity: 0,
          duration: 0.8,
          ease: 'power2.out',
          scrollTrigger: { trigger: element, start: 'top 94%', once: true },
        });
      });

      gsap.from('.step-track > span', {
        scaleY: 0,
        transformOrigin: 'top',
        ease: 'none',
        scrollTrigger: { trigger: '.steps', start: 'top 65%', end: 'bottom 75%', scrub: 0.4 },
      });
    });

    return () => media.revert();
  }, []);

  return null;
}
