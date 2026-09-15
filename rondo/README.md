# RONDO-1 launch page

A single-file cinematic launch site for a cork coaster. Open `index.html`
from disk; there is no build step.

## Assets

The page references thirteen images under `assets/` (exact filenames in the
comment block at the top of `index.html`, with an image-generation prompt for
each). Until a file exists, the page draws a procedural stand-in of the
coaster in its place and prints the filename in the corner. Drop the real
files into `assets/` and they take over automatically.

## Dependencies

Loaded from CDNs, pinned: GSAP 3.12.5 with ScrollTrigger, Lenis 1.3.26, and
one Google Fonts stylesheet (Inter Tight, JetBrains Mono).

## Notes

- `prefers-reduced-motion: reduce` unpins every scene and shows the page static.
- Works at 390 px and 1440 px; verified in headless Chromium.
