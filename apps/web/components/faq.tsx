'use client';

import { useEffect, useRef } from 'react';
import gsap from 'gsap';

type Question = { question: string; answer: string };
type Row = {
  hitArea: HTMLElement;
  disclosure: HTMLDetailsElement;
  summary: HTMLElement;
  answer: HTMLElement;
  vertical: HTMLElement;
  motion?: gsap.core.Timeline;
};

export function Faq({ questions }: { questions: Question[] }) {
  const listRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const list = listRef.current;
    if (!list) return;

    const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
    const hoverPointer = window.matchMedia('(hover: hover) and (pointer: fine)');
    const rows: Row[] = Array.from(list.querySelectorAll<HTMLElement>('.faq-item')).map(
      (hitArea) => ({
        hitArea,
        disclosure: hitArea.querySelector<HTMLDetailsElement>('details')!,
        summary: hitArea.querySelector<HTMLElement>('summary')!,
        answer: hitArea.querySelector<HTMLElement>('.faq-answer')!,
        vertical: hitArea.querySelector<HTMLElement>('.faq-plus-vertical')!,
      }),
    );
    let active = rows.find((row) => row.disclosure.open) ?? null;
    let candidate: Row | null = null;
    let dismissed: Row | null = null;
    let hoverTimer: ReturnType<typeof setTimeout> | undefined;
    let resizeFrame = 0;
    let layoutFrame = 0;
    let pointer: { x: number; y: number } | null = null;

    const shift = () => -parseFloat(getComputedStyle(list).getPropertyValue('--faq-shift'));
    const closedHeight = (row: Row) => row.summary.getBoundingClientRect().height + 2;
    const openHeight = (row: Row) => closedHeight(row) + row.answer.scrollHeight;
    const notifyLayout = () => {
      cancelAnimationFrame(layoutFrame);
      layoutFrame = requestAnimationFrame(() => {
        list.dispatchEvent(new Event('faq:layout', { bubbles: true }));
      });
    };
    const cancelHover = () => {
      clearTimeout(hoverTimer);
      candidate = null;
    };
    const setExpanded = (row: Row, expanded: boolean) => {
      row.summary.setAttribute('aria-expanded', String(expanded));
      row.answer.setAttribute('aria-hidden', String(!expanded));
      row.answer.inert = !expanded;
    };
    const settle = (row: Row, expanded: boolean) => {
      row.motion?.kill();
      row.disclosure.open = expanded;
      row.disclosure.dataset.active = String(expanded);
      setExpanded(row, expanded);
      gsap.set(row.disclosure, { x: expanded ? shift() : 0, clearProps: 'height' });
      gsap.set(row.answer, { opacity: expanded ? 1 : 0, y: expanded ? 0 : 6 });
      gsap.set(row.vertical, { scaleY: expanded ? 0 : 1 });
    };

    const animate = (row: Row, expanded: boolean) => {
      row.motion?.kill();
      row.disclosure.dataset.active = String(expanded);
      if (reducedMotion.matches) {
        settle(row, expanded);
        notifyLayout();
        return;
      }

      // Preserve the current rendered height when an interaction reverses mid-animation.
      gsap.set(row.disclosure, { height: row.disclosure.getBoundingClientRect().height });
      const timeline = gsap.timeline({
        onComplete: () => {
          row.disclosure.open = expanded;
          gsap.set(row.disclosure, { clearProps: 'height' });
          notifyLayout();
        },
      });
      row.motion = timeline;

      if (expanded) {
        // Move the whole bordered surface first; its stationary wrapper remains the hit area.
        timeline
          .to(row.disclosure, { x: shift(), duration: 0.28, ease: 'power3.out' })
          .call(() => {
            row.disclosure.open = true;
            setExpanded(row, true);
          })
          .to(row.disclosure, {
            height: () => openHeight(row),
            duration: 0.48,
            ease: 'power3.inOut',
          })
          .to(row.vertical, { scaleY: 0, duration: 0.28, ease: 'power2.inOut' }, '<')
          .to(row.answer, { opacity: 1, y: 0, duration: 0.34, ease: 'power2.out' }, '<0.09');
      } else {
        setExpanded(row, false);
        timeline
          .to(row.answer, { opacity: 0, y: 6, duration: 0.18, ease: 'power2.in' }, 0)
          .to(row.vertical, { scaleY: 1, duration: 0.24, ease: 'power2.inOut' }, 0)
          .to(
            row.disclosure,
            { height: closedHeight(row), duration: 0.42, ease: 'power3.inOut' },
            0,
          )
          .to(row.disclosure, { x: 0, duration: 0.32, ease: 'power3.out' }, 0.1);
      }
    };
    const activate = (next: Row | null) => {
      cancelHover();
      if (next === active) return;
      const previous = active;
      active = next;
      if (previous) animate(previous, false);
      if (next) animate(next, true);
    };
    const rowFor = (target: EventTarget | null) =>
      target instanceof Element ? rows.find((row) => row.hitArea.contains(target)) : undefined;

    const onPointerMove = (event: PointerEvent) => {
      if (event.pointerType !== 'mouse' || !hoverPointer.matches || event.buttons) return;
      const moved =
        !pointer || Math.hypot(event.clientX - pointer.x, event.clientY - pointer.y) > 2;
      if (!moved) return;
      pointer = { x: event.clientX, y: event.clientY };
      const row = rowFor(event.target);
      if (row !== dismissed) dismissed = null;
      if (row && row === dismissed) {
        cancelHover();
        return;
      }
      if (!row || row === active) {
        cancelHover();
        return;
      }
      // Don't let a stationary pointer open rows that move beneath it during reflow.
      if (candidate === row) return;
      cancelHover();
      candidate = row;
      hoverTimer = setTimeout(() => activate(row), 100);
    };
    const onPointerLeave = () => {
      cancelHover();
      pointer = null;
      dismissed = null;
    };
    const onClick = (event: MouseEvent) => {
      if (!(event.target instanceof Element) || !event.target.closest('summary')) return;
      const row = rowFor(event.target);
      if (!row) return;
      event.preventDefault();
      // A click during the initial hover slide should complete the opening, not cancel it.
      if (row === active && !row.disclosure.open) {
        cancelHover();
        return;
      }
      dismissed = row === active ? row : null;
      activate(row === active ? null : row);
    };
    const onKeyDown = (event: KeyboardEvent) => {
      cancelHover();
      if (event.key === 'Escape' && active) {
        event.preventDefault();
        const summary = active.summary;
        dismissed = active;
        activate(null);
        summary.focus({ preventScroll: true });
      }
    };
    const finishAtCurrentSize = () => {
      cancelHover();
      rows.forEach((row) => settle(row, row === active));
      notifyLayout();
    };
    const onResize = () => {
      cancelAnimationFrame(resizeFrame);
      resizeFrame = requestAnimationFrame(finishAtCurrentSize);
    };

    rows.forEach((row) => {
      // Keep native exclusivity until hydration; coordinate closing animations ourselves after it.
      row.disclosure.removeAttribute('name');
      settle(row, row === active);
    });
    list.dataset.enhanced = 'true';
    list.addEventListener('pointermove', onPointerMove);
    list.addEventListener('pointerleave', onPointerLeave);
    list.addEventListener('click', onClick);
    list.addEventListener('keydown', onKeyDown);
    window.addEventListener('resize', onResize);
    reducedMotion.addEventListener('change', finishAtCurrentSize);
    hoverPointer.addEventListener('change', cancelHover);

    return () => {
      cancelHover();
      cancelAnimationFrame(resizeFrame);
      cancelAnimationFrame(layoutFrame);
      list.removeEventListener('pointermove', onPointerMove);
      list.removeEventListener('pointerleave', onPointerLeave);
      list.removeEventListener('click', onClick);
      list.removeEventListener('keydown', onKeyDown);
      window.removeEventListener('resize', onResize);
      reducedMotion.removeEventListener('change', finishAtCurrentSize);
      hoverPointer.removeEventListener('change', cancelHover);
      rows.forEach((row) => {
        row.motion?.kill();
        row.disclosure.open = row === active;
        row.disclosure.setAttribute('name', 'veyra-faq');
        row.disclosure.removeAttribute('data-active');
        row.summary.removeAttribute('aria-expanded');
        row.answer.removeAttribute('aria-hidden');
        row.answer.inert = false;
        gsap.set([row.disclosure, row.answer, row.vertical], {
          clearProps: 'height,transform,opacity',
        });
      });
      delete list.dataset.enhanced;
    };
  }, [questions]);

  return (
    <div className="faq-list" ref={listRef} data-reveal>
      {questions.map((item, index) => (
        <div className="faq-item" key={item.question}>
          <details className="faq-disclosure" name="veyra-faq">
            <summary aria-controls={`faq-answer-${index}`}>
              <span>{item.question}</span>
              <span className="faq-plus" aria-hidden="true">
                <span className="faq-plus-horizontal" />
                <span className="faq-plus-vertical" />
              </span>
            </summary>
            <div className="faq-answer" id={`faq-answer-${index}`}>
              <p>{item.answer}</p>
            </div>
          </details>
        </div>
      ))}
    </div>
  );
}
