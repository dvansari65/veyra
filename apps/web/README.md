# Veyra landing page

A static Next.js App Router site in TypeScript. This application covers the landing page only; contract interaction and wallet connection are outside its scope.

## Development

From the repository root:

```sh
pnpm install --frozen-lockfile
pnpm dev
pnpm check:web
```

`check:web` generates route types, checks TypeScript and formatting, then creates the production export in `apps/web/out/`. Host that directory on a static web server. There is no `next start` server for this static export.

## Structure

- `app/`: server-rendered page, shared styles, metadata, and favicon.
- `components/`: navigation, SVG brand marks, hero figure, and GSAP motion.
- `public/`: the optimized hero artwork.
- `.openai/hosting.json`: private preview hosting configuration.

Page content stays in `app/page.tsx`. Only navigation and motion are client components. Manrope and Instrument Serif are self-hosted; the browser downloads only the font subsets used by the page. All content is readable without animations; motion honors the operating system’s reduced-motion preference. FAQ disclosures use native HTML.

Use `pnpm --filter @veyra/web format` to format source. Next.js generates route declarations and agent guidance; generated build output, caches, environment files, and `next-env.d.ts` stay out of Git.

Product claims follow `docs/CONTRACTS.md` in the repository root. Veyra is in development and unaudited. Reserved liquidity does not guarantee debt recovery.

## Artwork provenance

`public/capital-reserve.webp` is an original asset generated with the built-in image-generation tool, then encoded as WebP. It depicts a metaphor for capital reservation, not live protocol data.

Generation brief: a premium studio photograph of a dense, upright, staggered stack of thin graphite metal plates held by a single matte vermilion industrial U-clamp; three-quarter view, warm ivory seamless floor, soft directional daylight, tactile surfaces, portrait 4:5 composition with space for labels. No text, logos, currency symbols, padlocks, glowing elements, charts, or interface. The plates represent capital allocations held in reserve.
