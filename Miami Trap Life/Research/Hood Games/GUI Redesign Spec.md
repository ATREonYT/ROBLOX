---
tags: [miami-trap-life, ui, spec, hud, phone]
updated: 2026-11-03
status: ready to build
---
# GUI redesign spec: Miami Trap Life

**Goal:** a GUI that reads as a top hood RP game at a glance, in our own look. It is built from 143 frames of 10 hood games ([[GUI Patterns - Breakdown]]), the earlier benchmark pack, and Alex's standing calls in `Research/UI Art Direction - Lessons.md` (read its update at the top) and `Build Playbooks/09 Owner Taste Rules.md`.

**What stays (Alex picked these):** the icon-grid menu, a cash bar with a money icon, status rings, round hotbar slots, and plain colours (dark grey panels, white text, green only on money, gold for level, one soft blue for "selected"). Eased motion, not decoration.

**What changes:** sizes (we are 1.5–2× bigger than the genre), outlines that sit off their shapes, the faceted store, and missing genre-standard pieces (bank/dirty cash, energy, [E] prompts, status lines, keybind hints, a list-style shop, a death screen).

**Don't touch:** the tutorial card (the story thread is redoing it). Don't copy Vice City 2's chamfered panels, bracket lines, hex badges or red-wave phone wallpaper.

Sizes below are **pixels at 1080p screen height**. One `UIScale` on each ScreenGui sets `Scale = clamp(viewportHeight / 1080, 0.72, 1.15)`, and phones (touch) get × 1.15 so tap targets stay at least 44 px.

---

## 0. Outline fix (do this first, it's what Alex flagged)

> Alex: "make the outlines of the phone and other things actually outline the thing they need to, not like above it."

**What causes it today** (read from the code and the Nov 2-3 screenshots):
1. **`LowPoly.rim()`** (`UI/LowPoly.lua`) adds a separate 2 px light line, 2 px down from the top edge and 10 px narrower than the shape. On the store cards, tabs and "SOON" buttons it shows as a second outline floating just inside the top edge. That is the "above it" look.
2. **Square joins on rounded shapes.** `LowPoly.outline()` sets `LineJoinMode = Miter`, while the same frame has a 6 px `UICorner`. The stroke corners don't follow the rounded corner, so the outline looks like a box sitting around the shape.
3. **Outer strokes get clipped or pushed.** Strokes are drawn outside the edge by default. Inside a ScrollingFrame or a clipping parent the outer half gets cut off (top and left look thinner than bottom and right), and on tightly packed tiles they overlap the neighbour.
4. **Offset shadows read as a second edge.** The phone's `Shadow` frame sits 10 px lower than the body at 55% transparency, so a dark band shows under the phone. On the closed phone that peeks at the bottom right, you see the rim and the shadow, not a clean phone.
5. **Outline on the wrong object.** Wherever a stroke sits on a wrapper (a card, a slot holder) while the visible shape is a child that is inset, scaled by `UIScale` or moved by a press animation, the outline no longer lines up with what you see. Check the cash pill (the icon overhangs the pill), the store `Buy`/`Press` button, and hotbar `Disc` vs slot.

**The rule for every outline in the game:**
- The `UIStroke` goes **on the same object that draws the shape** (the one with the background colour and the `UICorner`). Never on a wrapper, never on a separate frame.
- `ApplyStrokeMode = Border`, **`BorderStrokePosition = Inner`**, so the line sits exactly on the edge, inside the shape, and nothing can clip it.
- `LineJoinMode = Round` on anything with a `UICorner` (`Miter` only on true square corners).
- `Thickness` is a whole number: **1** for hairlines, **2** for the selected state. `StrokeSizingMode = FixedSize`, so a pop or press animation doesn't fatten it.
- **No second outlines:** delete `LowPoly.rim()` and every "Rim", "Bevel" or offset "Shadow" frame. If something needs depth, use one soft `ImageLabel` shadow centred under it (same size + 12 px, no offset, 70% transparent), or nothing.
- Press animations scale the whole shape with a `UIScale`. They never move a child face inside a fixed outline.
- Text outlines: no thick black `UIStroke` on text. Use a 1 px black stroke at 75% transparency only on text that sits straight on the 3D world.

**Elements to fix and check, one by one:** cash bar and its icon · level ring · health ring · objective pill · menu (G) button and every menu tile · hotbar slots (normal and selected) · store panel, tabs, cards, ribbons, buy buttons, close X · emote wheel · minimap ring · phone body, screen and side buttons, open and closed · phone app cards and icons · prompts · toasts. **Done when** each is screenshotted at 2× zoom and the line hugs the shape all the way round, with an even thickness on every side.

---

## 1. Tokens (Theme.HUD)

Keep Alex's palette and add four colours.

| Token | RGB | Use |
|---|---|---|
| Ink | 24,25,29 at 0.12 transparency | every panel |
| Ink2 | 38,40,46 | tiles, slots, rows |
| Line | 255,255,255 at 0.86 transparency | the 1 px hairline |
| Paper | 245,245,245 | main text |
| Muted | 165,168,175 | labels, secondary text |
| Accent | 96,170,255 | selected slot, focus, active tab. **Nothing else** |
| Money | 92,196,104 | cash, buy buttons, "+$" pops |
| Gold | 240,192,72 | level, XP, level-up |
| Danger | 226,72,72 | low health, death, "-$" pops, warnings |
| **Bank** (new) | 205,210,220 | the bank balance under cash |
| **Dirty** (new) | 236,128,96 | dirty cash (only shown when > 0) |
| **Energy** (new) | 80,180,240 | the energy ring/bar |
| **Shade** (new) | 0,0,0 at 0.45 | full-screen dims behind menus |

**Type:** one family, Gotham SSm (as now). Heavy for numbers and short caps labels, Medium for sentences.
Scale: **26** cash · **18** panel titles · **15** prompt actions, button text · **13** body, list rows · **11** caps labels (letter-spaced +1) · **10** slot numbers. Nothing on screen under 10 (12 on touch).

**Shape:** panel corners **8**, tiles and rows **6**, pills fully round, round slots fully round. Hairline 1 px inner. No gradients, no facets, no glows. `LowPoly.style` stays only for 3D-world signs, if anywhere.

**Motion:** open 0.18 s Quint Out (scale 0.96 → 1 + fade), close 0.12 s Quad In, hover 0.08 s, tab slide 0.2 s, list items stagger 0.025 s, money count-up 0.4 s. Nothing bounces more than once.

---

## 2. HUD layout (on foot)

```
┌──────────────────────────────────────────────────────────────────┐
│ [Roblox topbar]          ● Head inside Liberty Food Mart   ┌───────────┐
│                          SAFE ZONE · chips row              │ 💵 $1,250 │ cash bar
│                                                             │ BANK $8,400│
│                                                             │ DIRTY $320 │
│                                                             └───────────┘
│                                                         ◯Lv ◯♥ ◯⚡ rings
│ [G] menu                                                  +$45 Job pay  ← toasts
│                                                                          │
│                                                   Sprint ⇧ · Crouch C    │ keybind hints
│                                                                          │
│   (minimap)                 You are in a safe zone                       │ status line
│   Flagler St                     12 / 48                                 │ ammo
│                           ①  ②  ③  ④  ⑤  ⑥                    [M] Phone │ hotbar
└──────────────────────────────────────────────────────────────────┘
```

| Piece | Where | Size (1080p) | Details |
|---|---|---|---|
| **Cash bar** | top-right, 16 px from the edges | 210 × 44 | Ink plate, hairline, 8 corners. Money icon 28 px **inside** the plate on the left (no overhang). Cash in Money 26 Heavy, right-aligned. Counts up 0.4 s on change, and a "+$45" (Money) or "-$1,030" (Danger) 15 Heavy floats up 24 px and fades by the number |
| **Bank / dirty** | right under the cash bar, no plate | 2 lines of 13 | "BANK $8,400" in Bank colour with a Muted label. "DIRTY $320" in Dirty, only when > 0. Ties into the dirty-money loop in [[Economy, Jobs and Crime]] |
| **Rings** | under, right-aligned, 8 px gap | 36 px each | Level (Gold, number inside, XP as the ring), Health (Money colour, Danger under 30%, heart), **Energy** (new, Energy colour, bolt). Ring stroke 3 px on an Ink disc. A small "LEVEL 3 · 40/120 XP" 11 caps label left of the level ring |
| **Toasts** | right side, under the rings | 240 wide, 36 tall | Max 3 stacked. Ink plate, 3 px colour stripe on the left edge (inside the shape), 13 text, an optional 11 caps category ("JOB PAY", "BANK", "WANTED"). Slide in 24 px from the right, stay 3 s, fade |
| **Objective pill** | top-centre, 56 px down | auto width, 34 tall | As now, but 15 Medium text and a 6 px gold dot. Hide it while a menu is open |
| **Status chips** | right under the objective | 22 tall | Short caps chips: SAFE ZONE (Accent), WANTED ★★ (Danger), IN COMBAT 0:12 (Danger), RENT DUE 2 DAYS (Gold). Ink plate, hairline in the chip colour. Only while true |
| **Status line** | bottom-centre, 120 px above the hotbar | 15 Medium, no plate | Plain white text with a soft shadow: "You are in a safe zone", "Too tired to sprint. Grab a coffee." One line at a time, 4 s |
| **Hotbar** | bottom-centre, 16 px up | **56 px** round slots, 8 px gap, 6 slots (as now, smaller) | Ink2 disc at 0.15 transparency, 1 px hairline. Icon 30 px. Slot number 10 Heavy above-left. **Selected: 2 px Accent stroke (inner) + scale 1.06**, and the item name in 11 caps under that slot only. Empty slots at 0.5 transparency |
| **Ammo** | just above the hotbar, centred | 15 Heavy | "12 / 48" with the gun name in 11 caps Muted. Only with a gun out. Turns Danger when the mag is ≤ 20% |
| **Menu button (G)** | left, vertically centred | 48 px | As now but 48 (was 64). Tiny "G" key-cap under it on keyboard, nothing on touch |
| **Minimap** | bottom-left, 16 px in | **200 px** (was 280) | Keep the round map. Street name under it in 11 caps on a small pill ("FLAGLER ST"). Drop the "310 m" pill: the distance shows on the world marker only |
| **Keybind hints** | right-middle | 12 text, 22 px key-caps | 3–4 rows that change with state: on foot (Sprint ⇧, Crouch C, Phone M), in a car (Exit F, Horn H, Lights L), aiming (Reload R, Swap shoulder Q). Fade out after 8 s without a state change, come back on change. Setting to turn off. Controller and touch show their own glyphs |
| **Phone hint** | bottom-right | chip "[M] Phone" | The closed phone is **hidden completely**. No peeking phone corner. New-message badge on the chip |

**Reveal step by step** (owner rule): on first join only the objective pill and cash bar show. Hotbar after the first item, rings after the first job, the menu after the tutorial asks for it, and the minimap after the first drive.

---

## 3. Prompts (custom ProximityPrompt style)
- Key-cap: 32 px rounded square (6 corners), Ink plate, 1 px hairline, key letter 15 Heavy. On touch the whole prompt is the button (min 56 px tall).
- Right of it, two lines: object name 11 caps Muted ("LIBERTY FOOD MART"), action 15 Heavy Paper ("Open door").
- **Hold:** a 2 px ring around the key-cap fills clockwise in Money colour. When done: a 0.1 s pop to 1.08, then the PromptDone sound.
- Price prompts read "Buy · $45" with the price in Money. Locked ones read "Needs Level 3" in Muted with a lock glyph.
- Spacing: at most 2 prompts at once, stacked 8 px apart.

## 4. Menus
- **Icon-grid menu (G):** keep Alex's 2-column grid and its order. Tiles 92 × 84, Ink2, 6 corners, icon 36 px, 11 caps label. Hover lifts 2 px and swaps the hairline to Accent. Red badge (Danger dot, 16 px, white number) for new stuff. The panel slides 24 px in from the left over a Shade dim.
- **Every panel** shares one frame: Ink panel, 8 corners, 1 px hairline, a title bar 52 px with the 18 Heavy title on the left, the cash readout and a 32 px close X on the right. The close X is in the same place on every panel.

## 5. Shops (two kinds)
**In-world shops (gun store, plug, clothes, corner store, dealership): list + checkout.** This is the genre standard.
- The panel opens over the live shop with the camera kept, 760 × 440, centred-right so the shelf stays visible.
- Left column, **CATALOG**: category tabs as pills on top, then rows 40 tall: name 13 Medium, stock "×4" Muted, price right-aligned in Money. The selected row gets an Ink2 fill and a 2 px Accent strip on its left edge (inside the row).
- Right column, **CHECKOUT**: a 200 px item preview (a ViewportFrame turning slowly), the name 18 Heavy, a one-line blurb, a stats row for guns (damage, fire rate, range as 4 px bars), then **one big buy button**: 48 tall, Money fill, "BUY · $1,250" 15 Heavy. Can't afford it: Ink2 fill with "NEED $410 MORE" in Muted.
- After buying: the button flashes "BOUGHT" for 0.6 s, the cash bar shows "-$1,250", and the item jumps to the hotbar with a pop.
- Dealership: the same frame, and the preview is the real car on the plinth (the camera cuts to it).

**Robux store (the menu's STORE tile): cards, but flat.**
- Keep the card layout, but **drop the facets and the rim**: a flat Ink2 card, an art area with a soft 20% tint of the card colour, a ribbon as a plain Gold pill, and a flat Money buy button with the Robux price.
- "SOON" cards: Ink2 button with Muted text, no tint, and tapping it only shows "Coming soon" (kid-safe rule).

## 6. Phone
- **Size:** 300 × 620 at 1080p (about 28% narrower and 25% shorter than now), 24 px from the right edge, vertically centred. No tilt, no peeking when closed: it slides up from below the screen in 0.22 s.
- **Body:** the body frame is the only thing with the outline: 2 px inner stroke in a slightly lighter grey (62,65,74), corner 38. Side buttons sit **behind** the body (lower ZIndex) and stick out 3 px. No offset shadow.
- **Home screen:** a 4-column grid with no empty half. Apps: Messages, Jobs, Bank (send money to a player, as South Bronx does), Maps, Garage, Plug (criminal path), Goals, Camera, Music, Settings, Contacts, and one social app ("Flex": posts that also show as a toast for everyone, like Streetz War 2's Twitter). Unbuilt apps open a "Coming soon" card.
- **Wallpaper:** our own Miami look, a dusk gradient (deep blue to warm orange) with a palm silhouette. Not red waves.
- **Lock screen:** keep the big clock. Tie it to the game clock so it never disagrees with the sky (Nov 3 screenshot showed 9:00 PM at early dusk).
- **Notifications:** a banner slides down at the top of the screen (not the phone) when the phone is closed, and inside the phone when it's open.

## 7. Death and downed screens (kid-safe wording)
- **Downed:** a soft red vignette at the screen edges, "DOWN" 26 Heavy, "Crew can pick you up · 0:20" 13, and a thin Danger bar draining. Crawl hint as a keybind row.
- **Dropped:** the world fades to 60% dark and desaturates, "YOU GOT DROPPED" 34 Heavy, "by NAME" 15 in Muted (name shown only if the player turned that setting on), what you lost ("Lost $320 dirty cash", "Lost Glock"), a respawn countdown, and the tip "Bank your cash to keep it safe". No paid revenge or keep-inventory button.

## 8. Car HUD
- A round speedo, bottom-right, 120 px: Ink disc, 2 px ring, the speed number 26 Heavy, "MPH" 10 caps. Fuel as a thin vertical bar beside it if we add fuel.
- The hotbar hides in a car. Keybind hints switch to car keys.

---

## 9. Build order (golden slice first)
1. **Outline fix + size pass** on what exists: cash bar, rings, hotbar, objective pill, menu button, minimap, phone (size, hide when closed, no shadow band). **Show Alex one side-by-side**: our HUD next to `philly-streetz/hud-stats-combat_PS4Tm2gEK4g_f06.jpg` and `tha-bronx-3/hud-tired-stats_vPU4Qjc0m0w_f14.jpg`, same framing. Get a yes before going on.
2. Bank/dirty lines, energy ring, toasts, status chips, status line.
3. Prompts.
4. In-world shop list + checkout (gun store first), and flatten the Robux store.
5. Phone home grid, wallpaper, clock sync, notifications.
6. Death and downed screens.
7. Keybind hints, car HUD.

Each step: one screenshot at the same framing as before, the outline check from §0, and a phone-sized check (iPhone 14 viewport) before calling it done.

## 10. Open items for Alex
- **Icons:** emoji are still placeholders (owner rule: no emoji in the final UI). We need a matching icon set: cash, bank, dirty, level, heart, bolt, and one per menu tile and phone app. 256 px transparent PNGs, flat, white glyph on a coloured round tile.
- **Phone wallpaper** art (or we generate a gradient + palm in Studio).
- Whether killer names show on the death screen by default (recommended: off by default, a setting to turn on).
