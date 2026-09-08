# Veyra landing page

A static Next.js App Router site in TypeScript. This application covers the landing page only; wallet connection and live contract interaction are outside its scope.

## Development

From the repository root:

```sh
pnpm install --frozen-lockfile
pnpm dev
pnpm check:web
```

`check:web` generates route types, checks TypeScript and formatting, and creates the production export in `apps/web/out/`. Host that directory on a static web server. There is no `next start` server for this static export.

## Structure

- `app/page.tsx`: server-rendered product story, protocol steps, participant benefits, FAQs, and footer.
- `app/layout.tsx`: metadata and self-hosted Manrope.
- `app/globals.css`: shared design tokens, self-hosted Fredoka, responsive layout, and reduced-motion styles.
- `components/brand.tsx`: shared interface icons.
- `components/navigation.tsx`: responsive navigation with keyboard handling.
- `public/veyra-gecko-navbar.webp`: dark gecko mascot, used only beside the navbar’s live Fredoka wordmark. Its white background blends into the lime surface with `mix-blend-mode: darken`. Its dimensions reserve space before loading, and it scales down on mobile. Below 400px the documentation link remains available in the mobile menu.
- `public/veyra-footer-signature*.webp`: responsive footer artwork combining the wordmark without a dot and a front-facing 3D gecko with crossed legs and its hands resting on the final “a”.
- `components/motion.tsx`: scoped GSAP entrances and ScrollTrigger motion.
- `components/faq.tsx`: hover, click, and keyboard FAQ controls with sequenced GSAP slide and height animations; native disclosure fallback without JavaScript.
- `public/fonts/`: Fredoka SemiBold (600) and its SIL Open Font License.

The selected hero direction is lime editorial: a vivid lime header and hero, oversized “Reserve first. Lend next.” typography, three linked bands, and a dark rounded call to action. The conventional product sections carry the same green palette, rounded typography, fine borders, and smooth native scrolling.

The same editorial system continues through the page: open protocol and participant columns, larger two-tone headings, sentence-case labels, round controls, and shared spacing and color tokens. The closing call to action uses dark green with a clean two-column layout: heading on the left, copy and actions on the right, stacking below 900px. Its lime primary button uses the same rounded shape as the hero action. The footer uses the shared paper canvas and wordmark treatment.

Fredoka SemiBold carries the hero, display headings, and live navbar wordmark. Manrope remains the font for paragraphs, navigation, buttons, and FAQ content. Display tracking is tuned for Fredoka’s rounded shapes.

Page content remains readable without animations. Motion honors the operating system’s reduced-motion preference. FAQ disclosures use native HTML. The hero bands use CSS geometry with a sequenced GSAP entrance and a subtle desktop scroll displacement. Fonts are served locally; the hero needs no image download.

The main product sections, FAQ, closing panel, and footer use scroll-linked vertical motion inspired by [Kimia](https://kimia.live/). The reference’s section wrappers translate vertically and ease toward the scroll position. Veyra reproduces that motion with GSAP ScrollTrigger’s numeric `scrub` (0.85 seconds), with a different travel distance per section. Stationary wrappers provide stable measurements while their children move; existing entrance and FAQ animations remain on separate elements. Phones use 35% of the travel distance. The footer finishes at its natural position, endpoints stay within the page bounds, and reduced-motion preferences disable the effect. Native scrolling remains in control.

Use `pnpm --filter @veyra/web format` to format source. Next.js generates route declarations and agent guidance; generated build output, caches, environment files, and `next-env.d.ts` stay out of Git.

## Product scope

Claims follow `docs/CONTRACTS.md` in the repository root. Buyers reserve collateral-purchasing capacity; lenders separately supply original principal. Reserved liquidity does not guarantee debt recovery. Veyra is in development, unaudited, and not deployed for production.

## Navbar mascot

The approved dark gecko was isolated using built-in imagegen and exported as a small lossless WebP for the navbar. The white image background and eye shapes take on the existing lime surface through CSS blending. The favicon is a separate asset.

Final image-edit prompt:

> Edit this image by replacing ONLY the entire gray-and-white patterned background with a completely uniform pure white #FFFFFF background. Also replace the patterned areas inside the curled tail and between the feet with pure white. Preserve the exact approved dark gecko, face, tilted head, body, paws, curled tail, colors, scale, full square canvas and margins. The background must be plain solid RGB white with no pattern, no gradient, no noise, no shadows and no texture. This is an opaque white-background logo export, not a transparency request. Keep the whole animal fully visible. No text, no extra elements, no redesign.

## Footer mascot

Built-in imagegen created a 3D-rendered version of the approved gecko facing the viewer, standing with crossed legs, and resting both hands on the wordmark’s final “a”. The footer signature contains no trailing dot. Keeping the character and lettering in one composition preserves the contact between hands and letter at every viewport width.

The artwork is served through a responsive picture with 640px, 1280px, and 1920px WebP sources (approximately 12 KB, 27 KB, and 49 KB). It loads lazily with intrinsic dimensions to reserve layout space. The opaque white export blends into the existing paper surface, and the whole composition uses the existing reduced-motion-aware section reveal. The artwork is decorative and hidden from assistive technology.

<details>
<summary>Final imagegen prompt</summary>

> Use case: stylized-concept / logo-brand.
> Create the final production footer signature artwork for Veyra, using the attached image as the approved mascot identity and rounded lowercase wordmark reference. This is one composed website asset, not a concept board.
>
> A wide landscape composition about 2.6:1, high resolution, with the lowercase word "veyra" in large, dark forest ink #1a251f, thick soft rounded Fredoka-style lettering across the left three quarters. Exactly v-e-y-r-a. REMOVE the period completely. The letters are clean flat graphic lettering with optically balanced spacing, a single-storey rounded "a", no bevels and no thick 3D extrusion.
>
> Immediately to the RIGHT of the final "a", place the approved gecko translated into a beautifully crafted 3D collectible mascot: soft satin vinyl, dark forest-green body, brighter natural forest-green belly, broad rounded pebble head, large friendly off-white eyes with dark pupils, tiny lime smile and nostrils, and its distinctive open curled tail. Preserve the recognizable approved character. Soft studio lighting reveals real rounded volume, subtle highlights, restrained ambient occlusion, and a small soft contact shadow underneath. Professional premium character rendering, charming but calm, without photographic reptile texture.
>
> POSE IS THE MOST IMPORTANT PART:
> The mascot is STANDING UPRIGHT, FACING DIRECTLY TOWARD THE VIEWER. Face, chest and both eyes are frontal and looking at us. It is casually leaning slightly toward the letter on its LEFT (viewer’s left). BOTH HANDS AND FOREARMS rest together naturally on the TOP of the final letter "a", palms down, fingers gently draped over the top edge. Clear physical contact and subtle contact shadow, like someone casually leaning on a counter beside them. The gecko’s body is beside the letter, not behind the entire word. Its legs are visibly CROSSED AT THE ANKLES, one foot in front of the other, relaxed weight on the rear leg. Keep the lower legs long enough to make the crossed stance unmistakable. Both feet are on the same baseline as the word, completely visible. The head is above the letter and the tail curls gently out behind the body on the right. No sitting, no side-facing pose, no hovering hands, no arms crossed over the chest, no floating feet.
>
> Composition: wordmark begins close to the left margin and remains fully readable; mascot occupies the right quarter, about 1.7 times the lowercase letter height, with the top of the "a" reaching its relaxed forearms. Connect mascot and letter into one seamless professionally balanced footer signature. Fill the width of the canvas, preserving narrow comfortable outer margins and enough room above the head. Keep the whole tail and feet in frame.
> Background: uniform pure white #FFFFFF, all the way to every edge. An opaque white studio export, no transparency or checker pattern. Only a restrained short ground contact shadow beneath the gecko; no horizon line, room, set, scenery, large gradients, frame, cards or board labels. Do not include navigation, buttons, extra logo instances, captions, slogans, other creatures or props. No period after "veyra".
> Deliver a beautiful polished 3D mascot leaning with BOTH hands on the letter "a", crossed ankles, directly facing the audience, suitable as the signature at the very bottom of a contemporary green DeFi website.

</details>
