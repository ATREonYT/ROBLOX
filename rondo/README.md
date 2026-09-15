# RONDO-1 launch page

A single-file cinematic launch site for a cork coaster. Open `index.html`
from disk; there is no build step.

## Motion map

Time-driven sequences (GSAP timelines that start when a scene enters, 40 px
before it pins): the coaster's flip and landing, the hand rising to take it,
the click-drag-expand demonstration, the card stack unfolding, the tools and
the landing on the workbench, and the finale beside the price.

Scroll-driven sequences (one scrubbed ScrollTrigger per pinned scene): the
coaster's travel from the hero to the hand, the label morph into the gallery,
the active-card step, the desk pan, the engineering drawing constructing
itself, and the bench pan. Each pinned stage dissolves over its last 40 px.

Nested wrappers keep writers apart: `.coin-travel` and `.coin-tilt` (scroll)
wrap `.coin-3d` (entrance), which wraps the faces. The hand's press feedback
lives on `.hand-in`, under the GSAP-driven `.hand`.

Every scene has three coherent states (zero, playing, done), so reverse
scrolling, fast scrolling, anchor jumps and a mid-page reload land on a
complete state.

## Assets

Thirteen optional images under `assets/`, listed with generation prompts in
the comment block at the top of `index.html`. Every missing file is replaced
by a procedural stand-in drawn in the page: the coaster's faces, a backlit
hand in five- and six-finger versions, the jacket, the editorial cards, the
desk, and a bench composed from a bare mat and four separate tools so they
can slide into place. Real files take over automatically. `hand.png` accepts
`data-disc="cx cy r"` so the 3D coaster can land exactly on the photographed
one.

## Dependencies

GSAP 3.12.5 with ScrollTrigger, Lenis 1.3.26 and one Google Fonts stylesheet,
all pinned, all loaded from CDNs. Without them the page renders static and
complete. `prefers-reduced-motion: reduce` does the same.
