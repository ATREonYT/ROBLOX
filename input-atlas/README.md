# INPUT ATLAS

A single-file prototype store for premium AI prompts and website-building
prompt systems, built as a journey: one input at the origin, then four
chapters that each show what that input becomes. Open `index.html` from disk;
there is no build step.

## Structure

| Chapter | Accent | What happens |
| --- | --- | --- |
| 00 Origin | ivory | A short input is typed, output fragments drift in and organise themselves into four destinations joined by a drawn route. The chapter index appears. Skippable. |
| 01 Build | electric blue | A website panel enters at an angle, flips flat, descends, lands with a small overshoot, is outlined, gains handles, and a decorative pointer drags its corner into a larger frame while the live site inside reflows. Expand / Reset, real corner drag and arrow keys take over afterwards. |
| 02 Imagine | warm amber | A spatial composition of prepared images. Scrolling moves the nearest one out, brings the next to the focal position, draws a framing rectangle and reveals the example input. Three styles swap prepared outputs through a masked transition. |
| 03 Express | soft coral | A rough brief reorganises itself into a headline, copy and a small composition: surviving words fly to their new place and change typeface on the way. Annotation lines draw to Tone, Audience and Structure. |
| 04 Create | pale violet | Three product panels rotate into alignment, connect through drawn lines, and the bundle presentation slides in. The closing headline follows. |

Each chapter has a featured product beside its demonstration with example
results, included prompts, customisation variables and a link to the product
page.

## Store

Hash routes on the same page: `#/browse` (search and category filters, empty
state), `#/product/<slug>` (outcome, audience, example input and output,
contents, editable variables, tool compatibility, usage steps, licence, price
and purchase control) and `#/cart` (quantities, removal, summary, a checkout
that is clearly a demonstration and takes no payment). The cart is kept in
localStorage. All twelve products are demo data. There are no reviews,
earnings claims or customer counts anywhere.

## Motion system

- Time-driven entrances start 40 px before a chapter pins; scroll-driven
  travel and construction run inside the pinned chapter; every pinned stage
  dissolves over its last 40 px into the next chapter's entrance.
- Every chapter keeps three coherent states (zero, playing, done), so reverse
  scrolling, fast scrolling, chapter jumps from the index or the menu, and a
  reload mid-page all settle on a complete composition.
- After every ScrollTrigger refresh (load, fonts, resize) each chapter
  re-measures with the final layout, resets what it animates and re-renders
  both of its timelines at the current position.
- The entrance timelines and the scrubbed timelines never write the same
  property of the same element.
- Below 768 px the chapters flow instead of pinning and the sequences play
  time-driven; the drag demonstration keeps its touch handle.
- With reduced motion, or without the animation library, the page renders
  every chapter at rest with the controls still working.

Sound is optional, off by default, and synthesised in the page.

## Dependencies

GSAP 3.12.5 with ScrollTrigger, Lenis 1.3.26 and one Google Fonts stylesheet
(Instrument Serif, IBM Plex Sans, IBM Plex Mono), all pinned, all from CDNs.
Every image is drawn procedurally in the page; the website previews are real
HTML that reflows with container queries.
