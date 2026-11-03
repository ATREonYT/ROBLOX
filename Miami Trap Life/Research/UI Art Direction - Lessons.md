---
tags: [miami-trap-life, ui, art-direction, research]
updated: 2026-11-02
---
# UI Art Direction: why ours looked "AI" and what real games do

> **Update (Nov 2, 19:20): what Alex actually wanted.** The stark "street" restyle below (text-list menu, Oswald, a pink accent, no icons) went too far, and Alex said "it was better before". What he wants is **his reference layout** (an emoji icon grid menu, a cash bar with a money icon, status rings and round hotbar slots) in **plain, normal colours**: dark grey panels (24,25,29), white text, green only on money (92,196,104), gold for level (240,192,72) and a soft blue (96,170,255) for "selected". Flow comes from eased motion (0.14-0.3 s Quad/Quint, small scale and fade, staggered tiles), not from decoration. The "AI" feel came from the **colours** (multi-colour faceted bands and neon), not from the layout. Lesson: when Alex says "too AI", change the palette first and keep the structure he picked.

Back to [[00 Master Plan]]. Written after Alex said the HUD "feels a bit too AI" (Nov 2). The rules below apply to every screen in the game (HUD, menus, phone, prompts and cutscene text).

## What made the old HUD read as AI-made
- **Emoji as icons everywhere.** Emoji look like a placeholder, not art, and every AI mock-up uses them. Real games either draw their own icon set or use no icons at all.
- **Every surface decorated.** Gradients, facets, glows, ribbons, rounded cards and thick outlines all at once. Generic generators produce this "everything is a card" look.
- **Too many colours.** Green, blue, gold, red, purple and pink tiles all shouting at the same level, so nothing is more important than anything else.
- **Thick black text outlines.** These are a Roblox-default habit. Studio games use a soft drop shadow or put text on a solid plate.
- **Rounded pills and big corner radii.** A friendly SaaS look that doesn't fit a street crime game.
- **Even sizes.** Everything was about the same size and weight, so there was no hierarchy.

## What studio games do instead
- **One accent colour.** GTA V/VI uses a white HUD, money green only on money and a single highlight colour for selection. Valorant uses off-white plus one red. We use **Vice pink (255,72,104)** as the only accent, with **money green only on cash** and **gold only for warnings and level-ups**.
- **A neutral base.** Warm off-white text (240,236,228), not pure white. Off-black panels (12,12,14) at roughly 15-25% transparency. No blue-grey slate.
- **Type does the work.** A condensed bold display face for numbers and headings (Oswald, the closest built-in to GTA's Pricedown or Valorant's DIN) and a clean sans for body text (Gotham). Uppercase only on short labels. One step of size between levels: 40 / 22 / 16 / 13.
- **Sharp geometry.** Corners of 0-2 px and 1 px hairline borders at about 85% transparency. Bars are thin (3-4 px). Shapes are rectangles and lines, not blobs.
- **Show only what matters.** The cash readout is just the number, top right, with no box (GTA). XP and health are thin bars. The menu is a **text list** (like GTA's interaction menu) and needs no icons.
- **Motion over decoration.** Panels slide 20-40 px with a quick ease-out (0.18-0.25 s). The selected row gets an accent bar on its left edge. Numbers count up. Nothing bounces more than once.
- **Big moments are full-width bands.** "MISSION PASSED" in GTA is one black band across the screen with big type, not a floating card.
- **Grit belongs in the world, not the UI.** The street feel comes from typography and colour, plus at most one texture accent such as a spray-paint underline. Never put grunge on every panel.

## Where emoji stay
- The **map markers** stay emoji, because Alex asked for that style. They sit on flat dark discs with a hairline ring and no glow, so they read as markers rather than stickers.

## Checklist for any new screen
1. Can you name the single most important thing on it? Make that the biggest and brightest element.
2. Count the colours. More than off-white + off-black + one accent (+ green for money) means cut some.
3. Delete every gradient, glow and outline that has no job to do.
4. Use corners of 2 px or less, borders of 1 px, and Oswald for headings and numbers, Gotham for sentences.
5. Look at it next to a GTA, Valorant or Jailbreak screenshot. If it looks like a template, it is one.

## Tokens of the street restyle (superseded, see the update at the top)
Ink (12,12,14) · Ink2 (24,24,27) · Line white at 0.85 · Paper (240,236,228) · Muted (150,148,142) · Accent (255,72,104) · Money (114,214,112) · Gold (255,196,64) · Head font Oswald Bold · Body font GothamSSm Medium.
