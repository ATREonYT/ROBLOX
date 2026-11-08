---
tags: [chess-evolution, references, popups, juice]
updated: 2026-11-08
source: "Screen Recording 2026-11-08 at 3.26.34 PM.mov (9 s, 3024x1722)"
---

# Ref: Subscribers pop-up on tap

![[frames/subscribers-popup-on-tap.jpg]]
![[frames/subscribers-popup-closeup.jpg]]

**What it shows.** The player walks around the hub with the FREE Auto Clicker ON. Every click spawns its own "+182" pop-up around the avatar, and the Level bar fills steadily (125.5K → 143.2K in about 9 s).

**How the pop-up looks and moves**
- A gold rounded-square icon (white play triangle) on the left, then "+182" in heavy white text with a thick black outline. The icon is about as tall as the text.
- **One pop-up per click. They are not merged.** About 10 clicks a second, so 6–8 are on screen at once.
- Each spawns at a **random spot around the avatar**, inside roughly one avatar-height in every direction (above the name, beside the body, at the feet). Spots never repeat in a pattern.
- It appears at full size instantly, drifts up a little, then **shrinks and fades** together. Lifetime is about 0.6–0.8 s. The older ones are visibly smaller and paler than new ones.
- They follow the avatar (they are world-anchored around it), and they draw over everything.
- The bottom "2.7M Subscribers" counter and Level bar update continuously; the bar fill eases rather than jumps.

**Around the avatar while clicking:** a thin rainbow/cyan ring aura spins around the body, with a few small yellow sparkles at the feet. Nothing on the camera: no shake, no zoom.

**For Chess Evolution:** the same pop-up with our Power icon and "+N", one per accepted tap, random offset around the character. The Nov 7 build merges gains every 150–250 ms (master prompt §4). The reference does not merge at 10 taps a second, so keep one per tap and pool them.
