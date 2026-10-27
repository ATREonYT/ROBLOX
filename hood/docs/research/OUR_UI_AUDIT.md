# Our UI audit: why it looks blurry, badly cut out and cheaply animated (Oct 27)

This audit answers the owner's message: "Please make the ui not be blurry and badly cut out, the animations are bad"
and "center the ui icons well ... make the gamepass menu look better ... make luck separate".
It was made on HEAD 0bf71fdb and changes no code; worst items come first.
Each item gives its evidence, a fix, and the size of the fix (S = under an hour, M = a few hours, L = a day or more).
One proof picture sits next to this file: `OUR_UI_AUDIT_proof.jpg`. It shows a shoe the way the game draws it next
to its source, a mockup button at its 1080p size, and the cut-out pieces on a checker.

## How big things are on screen (the numbers used below)
- **The HUD and the Shop** are laid out on a 1280x720 canvas and scaled to the screen (`UIKit Kit.scaleFor`):
  - 1080p: x1.5;
  - a phone (844x390 points): x0.70 in points. That is about x2.1 in real pixels on a 3x-density screen, since Roblox
    draws the UI at the phone's full resolution.
- **The art windows** (Shoe Boxes, Inventory, pair detail, reveal, Daily...) are drawn at artboard size and scaled by
  `ArtKit.fit`:
  - 1080p: up to x1.25;
  - phones: about x0.55-0.6 in points, which is about x1.7 in real pixels.
- **A picture goes soft** when it's shown bigger than its own pixels ("upscaled"). It goes grainy or jaggy when it's
  shown many times smaller, because pictures our game draws itself have no smaller pre-shrunk copies to fall back on
  (likely; Studio will tell).

---

## Part A: blur and bad cut-outs, worst first

### A1. 56 of the 96 uploaded icons show OLD pictures, and they are placed by the new pictures' measurements (L impact, S fix)
- **The setup:**
  - `Models/IconModels.lua` `M.Images` holds the uploaded image ids.
  - The last upload commits are 50e045cf (Oct 10) and 5f876dfa (Oct 12).
  - Since then, the PNGs in `hood/art/icons3d` were redrawn: Oct 13 (guns) and Oct 27 (776b0019, "Icons from the
    owner's sheet", 53 icons).
  - An uploaded id always wins over the packed picture (`Kit.icon3d`), so the real game shows the Oct 10 drawings.
  - Meanwhile `M.Bounds`, which centres and sizes each icon (`Kit.place`), was measured on the new PNGs.
  - The offline preview draws the new PNGs, so none of our pictures ever showed this.
- **Affected (PNG changed after its upload):**
  - Arrow, AutoFight, Backpack, Basket, BlockParty, BoostBundle;
  - Cash, CashLarge, CashMedium, CashSmall, CashTiny;
  - Delete, DoubleCash, DoublePower, Evolve, ExtraEquip, Favorite;
  - Gun, Gun_AK, Gun_Blaster, Gun_Deagle, Gun_Diamond, Gun_Minigun, Gun_Pistol, Gun_Revolver, Gun_Shotgun,
    Gun_Tommy, Gun_Uzi;
  - Lucky, Muscle, PotionGold, PotionRed;
  - Power, PowerLarge, PowerMedium, PowerPack1, PowerPack2, PowerPack3;
  - Quest, Rebirth, RebirthSkip, Rewards, Robux, Search, Shield, ShoeBox, ShoePile, Shop, Skull, Sneaker;
  - TenXCash, TripleOpen, Trophy, VIP, World, XP.
- **What the owner sees:**
  - old-style drawings mixed with the new owner-sheet icons;
  - icons sitting off-centre or the wrong size in their slots, because the old art has other margins than the bounds
    expect.
  - This is very likely a big part of "center the ui icons well".
- **Fix:**
  - Re-upload the changed PNGs with `hood/tools/upload_assets.py` (it rewrites the ids; the owner's Open Cloud key is
    needed, see `hood/art/README_upload.md`).
  - Until then, prefer the packed picture whenever the PNG is newer than its id. A small table, or simply clear the
    56 stale ids so the game draws the current PNGs; but then A2 applies to them.
  - Add a check that fails when a PNG changed after its id was written.

### A2. Every shoe, box and new gun picture is drawn from a 192 px, 256-colour, dithered copy, and shown up to 3x bigger (L impact, S-M fix)
- **The setup:**
  - 48 `Shoe_*`, 9 `Box_*`, the 5 exclusive guns and about 20 newer icons have no uploaded id. They are drawn by
    `Shared/ImageLoader` from `Shared/Images/Icons`.
  - `tools/ui/pack_images.py` shrinks them to 192 px (items) or 160 px (icons). It then reduces them to a 256-colour
    palette with Floyd-Steinberg dithering (`encode`).
- **Measured on Shoe_Ember, Box_Exclusive, Cash and Gun_AK:**
  - **Colour:** the packed copy is 34-38 dB from the source (visible grain on gradients).
  - **Soft edges:** the levels of see-through drop from about 230 to 14-103. Gun_AK keeps 14, so its edges stair-step.
  - **Halo:** the half-see-through edge pixels of Shoe_Ember change from a mean brightness of 98 to 195, a light rim
    around a dark outline.
- **Largest on-screen sizes:**

| Where | Code | Box (design px) | 1080p | phone (real px) | from 192 px |
|---|---|---|---|---|---|
| Pair detail, the big shoe | `ShoeScreens.lua:537` | 520x345 | ~431 px | ~620 px | x2.2 / x3.2 |
| Reveal card shoe | `ShoeScreens.lua:337` | (W-140)x352 | ~440 px | ~630 px | x2.3 / x3.3 |
| Store bundle hero shoes | `Store.client.lua` BundleHero | ~229x182 content | ~343 px | ~480 px | x1.8 / x2.5 |
| Shoe Boxes browser box | `ShoeScreens.lua:91` | 252x206 | ~258 px | ~370 px | x1.3 / x1.9 |
| Pass card icon (5 exclusive guns, AutoOpen, Speed2x, ServerBoost...) | `Store.client.lua:654` | 178 | 267 px | ~375 px | x1.4 / x2 |
| Shoe grid card | `ShoeScreens.lua:382` | ~160x127 | ~160 px | ~230 px | ~x1 (grain only) |

- The proof picture shows the pair-detail case side by side.
- **Fix (best):** upload the item pictures, so Roblox serves them full size and smooth. Use 512 px for cards and
  1024 px for the pair detail and reveal, with an alpha bleed first (A6).
- **Fix (no upload):**
  - Pack the items at 512 px with no palette and no dithering. Store the RGBA runs, or 4096 colours, or let the
    EditableImage take the PNG bytes.
  - The cost is a bigger place file and more of the per-screen picture memory, so keep the number of big pictures
    on screen small.
  - Size M, because the EditableImage memory budget on phones needs a test in Studio.

### A3. Buttons, tabs, cards, the header bar, the window body and the X are crops of a tiny AI mockup, enlarged 2.5x to 8x (L impact, M fix)
- **The setup:**
  - `tools/ui/cut_mockup.py` cuts the pieces from `docs/refs/ui/owner_ui_windows_oct27.png`. That image is
    1536x1024, AI-made, with its own softness.
  - A green button in it is 46 px tall, a tab 25-31 px, an item tile 58 px, the header bar 38 px, and the body
    pattern 37 px.
  - Each piece is enlarged 3x with Lanczos. That adds no detail and adds faint ringing beside the black outline.
  - `UIKit Kit.skin`/`Kit.reskin` then 9-slice them over about 170 `Kit.block` and `ArtKit.block` calls: every
    block whose tone is in `Kit.SkinPieces` (green, cardGold, blue, grey, cardPurple, red, cardBlue, lime, dark ...).
- **Enlargement of the mockup's real detail:**

| Piece | Mockup px | Typical on-screen size, 1080p | x | Phone (real px) | x |
|---|---|---|---|---|---|
| btn_green / price buttons (42-76 design px tall) | 46 tall | 63-114 px | x1.4-2.5 | 88-160 px | x1.9-3.5 |
| tile_* on cards (pass cards 156, Featured 175-220) | 58 tall | 234-330 px | x4-5.7 | 330-460 px | x5.7-8 |
| header (window header ~92 px inside the outline) | 38 tall | ~138 px | x3.6 | ~195 px | x5 |
| body_tile (TileSize 100 design px) | 37 square | 150 px | x4 | 210 px | x5.7 |
| close X (~60-84 design px) | 42 square | 90-126 px | x2.1-3 | 126-176 px | x3-4 |
| tab_* (~34-40 design px) | 25-31 tall | 51-60 px | x1.9-2 | 71-84 px | x2.7 |

- **The wrong piece shapes:**
  - The tall `tile_*` pieces are also put on small things. The Store's "Info" tab (`Store.client.lua:630`, purple,
    56x22) gets `tile_purple` at SliceScale 0.15. A 174 px piece squeezed about 7x looks jaggy and grainy, and its
    bands squash.
  - `blue` buttons wear a *tab* piece (`tab_on_blue`).
- **Fix (recommended): stop wearing mockup crops; draw the chrome natively.**
  - Use Frame + UICorner + UIStroke + UIGradient + a darker lip Frame. UIKit already has this as "the drawn look"
    under every skin (the fallback).
  - Set `Kit.UseOwnerSkins = false` (one line). Then tune the drawn look's colours, rim and lip to the mockup
    (`Kit.Tone`, `Kit.Skin`).
  - Native shapes stay sharp at every size and on every phone. This is also research item "Fix A" in
    `UI_CRISP_AND_JUICE.md`.
  - Size: S to switch, M to match the mockup's look closely.
- **Fix (if the owner wants the exact mockup texture):**
  - Have Claude Design make each piece as a clean transparent PNG at 4x: a button 184 px tall, a tile 232 px.
  - Upload them and 9-slice them with `SliceScale` 0.25-0.5.
  - Size M, plus the owner's design round.

### A4. The cut-out pieces have missing outlines and leftover backdrop (L impact on "badly cut out", fixed by A3)
- **Measured on the PNG edges in `hood/art/ui_owner`** (on the checker in the proof picture):

| Piece | What's wrong at its edges |
|---|---|
| `close` | Its bottom row is the header's yellow (255,224,0). Its top row is pink, with no dark outline. |
| `btn_red` | No outline on the top and left (bright red to the edge). Outline only on the right and bottom. |
| `btn_grey` | No outline on the top and left. |
| `tab_on_blue` | No outline on the left (cyan to the edge). |
| `tile_blue` / `tile_red` / `tile_green` / `tile_grey` / `tile_purple` / `tile_yellow` / `tile_secret` | No outline on the left and bottom (`tile_blue` is blue to the edge). |
| `price_pill` | Its bottom row is the mockup's yellow-olive backdrop (163,169,2). |

- **The rounded corners are a guess:**
  - `alpha_corners` masks each piece with a guessed radius (3-10 px). Along the corner diagonal, the first solid
    pixel is the bright fill, not the outline: `btn_green` (200,218,123), `tab_on_blue` (11,221,252),
    `tile_blue` (2,117,240).
  - So at every rounded corner the dark outline is cut away, and the bright fill meets the background in a jaggy
    edge.
- **Why it shows:** `skinLook` turns off our own UIStroke while a piece shows (`UIKit.lua` ~2337), so nothing hides
  these edges.
- **The seams:**
  - The left and right caps of 'join' pieces come from different spots in the mockup. Two columns at the seam differ
    by 1-5 levels on average (`tile_secret` 5.3, `bar_fill` 3.5, `tab_on_blue` 2.5).
  - The stretched middle is a 2 px column at that seam, so any difference repeats across the whole button.
- **Fix:** A3 (native drawing) removes all of this. A recut would need new, clean source art, not this mockup.

### A5. Two looks side by side: crisp drawn blocks next to blurry picture blocks (M impact, fixed by A3)
- Tones that are not in `Kit.SkinPieces` stay crisp and drawn: rose, orange, cardTeal, cardPink, the headerCyan,
  headerMagenta, headerBrown and headerYellow headers, tabOn, world, level, rainbow.
- Their neighbours wear soft mockup pieces, so one window mixes two styles.
- **Picture memory:**
  - A piece also only shows once ImageLoader has drawn it; until then the drawn look shows (B1).
  - When the picture memory is full, the picture unseen longest is freed. It is redrawn when it shows again, so on a
    phone (smaller budget) blocks can switch look while scrolling.
- **Fix:** A3.

### A6. Dark or light fringes on cut-out art (M impact, S fix)
- The see-through pixels of the icon PNGs are black (0,0,0), or near-black for the drawn ones.
- The packed copies are the same: their palette's see-through entry is black.
- When Roblox smooths an enlarged picture, it mixes that hidden colour into the edge. The research doc explains the
  mechanism (`UI_CRISP_AND_JUICE.md`, "halo").
- The dark baked outline hides most of it on our icons. The pieces (A4) and the palette rim (A2) do show it.
- **Fix:** a PixelFix-style alpha bleed in `pack_images.py` and before every upload: fill see-through pixels from
  their neighbours, about 4 px. Size S.

### A7. Text that is scaled to fit, or is too heavy for its size (M impact, S-M fix)
- **`TextScaled = true` in the UI** (the research doc cites a known blur bug, and neighbouring labels pick uneven
  sizes):
  - **HUD:**
    - `HUD.client.lua:592`: the rebirth moment's "Power forever!";
    - `HUD.client.lua:833` and `:836`: the goal panel's text and where-line, on screen all the time.
  - **Shoes and boxes:**
    - `Shoes.client.lua:484, 486, 489, 512, 519, 525, 545` (the box browser cards' chance, name, title, price, tag);
    - `PityUI.lua:85` (every pity line).
  - **Toasts and the rest:**
    - `HudToasts.lua:91, 96` (every toast);
    - `World.client.lua:74`;
    - `Onboarding.client.lua:235`;
    - `UnboxCinematic.lua:1997, 2002, 4657`;
    - `UnboxWorld.lua`, `UnboxKit.lua`, `FightUI.lua`, `Wheel.client.lua`, `Stages.client.lua`.
- **Heavy small text:**
  - Pass card descriptions are 16 px with a 3 px stroke (`Store.client.lua:661`). At 16 px, a 3 px dark stroke
    closes the letters up ("Better odds for Epic and up in Cash boxes" reads as a dark smudge on a phone).
- **Fix:**
  - Fixed TextSize from one size table; `UITextSizeConstraint` where it must shrink.
  - Body text at Bold, not Black, and stroke at about 12% of the size (2 px at 16).
  - Shorter descriptions (Part D).
  - Size S for the HUD goal panel, toasts and pity line; M for all of it.

### A8. Odd sizes, half pixels and things rotated at rest (S-M impact, S fix)
- **Fractional pixels:**
  - The 1.5x and 0.70x screen scales put many offsets on half pixels. The 1 px rims and outlines of pictures go soft.
  - Phones (0.70) are worst: almost every size is fractional.
  - The header's tile size is `floor(111 * (hh - 2O) / 114 + 0.5)` (`UIKit.lua:2758`). Its scaled width is
    fractional, so the repeating pattern shows a moving 1 px seam line.
- **Rotated at rest** (resampled, so soft or jaggy edges; Roblox doesn't smooth rotated frame edges):
  - the Store's ribbon (`Store.client.lua:710`, Rotation -7, with 45° tails);
  - the struck-through price line (`Store.client.lua:412` and `:729`, -6°);
  - all the endless wobbles in B5.
- **Rounded corners don't clip:**
  - `ClipsDescendants` clips to the rectangle, not the UICorner.
  - So the shine band inside a price button (`Store.client.lua:217-219`, `ShineClip`) crosses the button's
    transparent rounded corners: a light square corner appears as each sweep passes.
- **Fix:**
  - Round the screen scale to steps that give whole pixels (1.5 is fine; for phones prefer 0.75 or 0.5) and keep
    offsets even.
  - Bake tilts into art, or keep them at 0 at rest.
  - Make the shine a UIGradient on the button itself (`UIMotion.shine` already does it that way) instead of a band
    in a clipping frame.

### A9. 3D views inside the UI (S impact)
- The Shop's Featured Chrome Box card draws the box in a ViewportFrame (the empty left half in the offline still),
  and other box and gun previews do the same (`UIKit.lua:1550`, `1709`, `Models/*Models.lua`).
- ViewportFrames render with flat light and lower quality, and grow jaggy when small.
- **Fix:** use the uploaded PNG for any small box or gun. Keep at most one 3D view, for one big spinning preview.

---

## Part B: animations that look cheap, worst first

### B1. Pictures pop in after the window has opened, and blocks change look as they do (L impact, M fix)
- **The setup:**
  - `ImageLoader` draws one picture per frame (`drawNext`, `ImageLoader.lua:312`). It looks for new labels only every
    0.2 s when idle (`loop`, `:325-346`), and decodes big pictures in slices across frames (`decode`).
  - So when the Shop opens, its ~35 different pictures (pieces and icons) arrive one by one over about 0.6-0.8 s,
    after the open animation has finished.
- **What the player sees:**
  - Each block first shows its drawn look, then switches to the piece (`skinLook`, `UIKit.lua` ~2337).
  - Each icon first shows a flat stand-in, then the picture.
- **More:**
  - Pictures nobody saw for 120 s are freed (`IDLE_FREE`), so a second visit can repeat it.
  - This is the single biggest "the animations are bad" cause: the window looks unfinished for most of a second.
- **Fix:**
  - Uploading the pictures (A1/A2) and drawing the chrome natively (A3) removes almost all of it.
  - Whatever stays packed: draw a window's pictures before it opens (warm them at join, or wait up to 0.3 s before
    the pop), and never show the stand-in once a picture has been drawn this session.

### B2. Too many things moving at once in the Shop (L impact, S fix)
- **What moves on every Gamepass, Boost and Cash card:**
  - the icon's idle (rock, bob or breathe; `Store.client.lua:228-231`, `UIIdle.icon`);
  - a shine band every 3.5 s (`addShine`, `:206-212`);
  - a sparkle (`:666`);
  - its price button's own sweep every 4.2 s (`buyFX`, `:216-225`);
  - green Robux buttons breathe a lime glow every 1.6 s (`:224`);
  - big buttons breathe (`:399-400`).
- **The count:**
  - The Gamepasses section alone has 18 cards, so about 50-70 moving things, each on its own phase.
  - The research doc's +1 and Bee Swarm notes say the opposite: calm menus, juice only on the one item that matters.
- **Fix:**
  - Idle motion only on the Featured hero card, a "BEST VALUE" card and an unowned Luck card. At most 3-4 moving
    things on screen.
  - Everything else is still until hovered. Size S (delete calls).

### B3. Cards zoom in from nothing inside a window that is also popping (M impact, S fix)
- The window pops 0.8 > 1 in 0.26 s Back (`UIMotion.lua:79-91`).
- At the same time, every card starts at scale 0.01 and 28 px low, and pops to 1 in 0.34 s Back, staggered 0.07 s
  up to 0.6 s (`Store.client.lua:254-266`).
- The last card lands about 0.95 s after the tap. The research table says to start a pop at 0.85-0.9, never at 0
  ("looks like a cheap zoom"), and to stagger 0.03-0.05 s.
- **Fix:** cards from 0.92 with a fade, a 0.04 s stagger and a 0.25 s cap; or no card stagger at all, since the
  window already pops.

### B4. The Rebirth pill twitches every second (M impact, S fix)
- While a rebirth is ready, `Motion.pop(rebirthPill, 0.12)` runs every second inside the boost-chip loop
  (`HUD.client.lua:1048`): a 0.075 s jump up and a 0.24 s Back down, once a second, forever.
- It reads as a nervous tick, not a breath.
- **Fix:** `UIIdle 'breathe'` (1 > 1.06 > 1 over 1.8 s, Sine) or a soft glow, started and stopped with readiness.

### B5. Endless wobbles and rotations (M impact, S fix)
- **Endless wobbles and bobs:**
  - `HUD.client.lua:256`: the Shop's rainbow "!" badge wobbles ±7° every 1.4 s, forever. A rotated frame with a
    3 px stroke has jaggy edges, and it never rests.
  - `Extras.client.lua:118` (gift ±6°/1.6 s), `:242` (scroll ±6°/1.4 s), `:349` (hero bob 6 px), `:330` (crate bob);
    `Retention.client.lua:122` (icon bob).
  - `UIIdle 'rock'` rotates item pictures ±5° (the clover), resampling them every frame.
- **Fix:** a short wiggle (0.4 s) every 4-6 s that settles at 0°, or a scale breathe instead of rotation; nothing
  rotated at rest.

### B6. Small bobs step pixel by pixel (S-M impact, S fix)
- `UIIdle 'bob'` moves `Position` in 0.1 px steps (`UIIdle.lua:56-62`). `Motion.bob` moves the Rebirth window's
  ">>>" text 5 px every 1.1 s (`HUD.client.lua:673`).
- Text and pictures land on whole pixels, so a 4-6 px bob over 1-2 s moves in visible 1 px jumps (a crawl, not a
  float). Likely; check in Studio at 1080p.
- **Fix:**
  - Bob with a UIScale (1 > 1.04), or bob at least 8 px over 1.2 s+, where the steps blur together.
  - Never bob text; move its parent frame or scale it.

### B7. The rebirth moment is long and can't be tapped away (S impact, S fix)
- From punch to hold to fade it runs about 3.6 s (`HUD.client.lua:545-626`, this round's work), with a 2.1 s hold.
- The research says to hold about 1.5 s, with tap to skip.
- **Fix:** a 1.5 s hold, and a tap anywhere ends it early.

### What is fine and should stay
- Button hover, press and release: 1.05 at 0.13 s; 0.94 at 0.07 s; Back at 0.2 s (`UIMotion.Time`).
- Window open 0.26 s Back, close 0.15 s Quad In.
- `ArtKit.popIn` 0.86 > 1.03 > 1; toasts 0.22 s Back in, 0.18 s out.
- Count-ups: 0.6 s Quart.
- The rebirth rays' slow Linear turn.
- All of these sit inside the research doc's table.

---

## Part C: icons that aren't centred in their slots

**The PNGs themselves are well centred.** I measured all 183 `hood/art/icons3d` PNGs (visible box, alpha over 24,
against the canvas centre):
- 173 are within 3% of centre.
- The exceptions are by design:
  - `BoxLid_*` (-13 to -15% vertically) and `BoxBase_*` (+6%) are framed to stack into one box;
  - `PowerBig` is +3.2%.
- `M.Bounds` matches every current PNG within 2%.

**So the off-centre look in the game comes from these:**
1. **A1, the stale uploads (the main cause):** the game draws old Oct 10 pictures, but places them by the new
   pictures' bounds.
2. **Icons bigger than their card, so they spill over its edges.** I laid out the Shop and the HUD in the preview
   page and measured each icon's visible box against its slot (negative = sticks out):
   - **Pass cards:**
     - The icon is 178 px in a 156 px card (`Store.client.lua:654`), so every pass icon spills: left by 2-16 px,
       top or bottom by up to 14 px.
     - Worst cases: Gun_RoyalCrown L-16, Gun_NeonViper L-13, Gun_GalaxyRay and Gun_Frostbite L-10, Arrow L-9,
       AutoFight B-14.
     - Their visible sizes vary from 95x144 (GoldBay) to 171x73 (Gun_RoyalCrown). A tall potion and a flat gun get
       the same square, so the row looks uneven.
   - **Cash cards:** the cash art spills left by 4 px (Tiny, Small, Medium, Big).
   - **HUD:**
     - The Power-pack muscle icons spill 22 px out of their 120x34 pill (PowerPack1-3).
     - The HUD offers' pictures stick out of the top of their buttons by 18-24 px (Speed2x -24, DoubleCash -19,
       DoublePower -18). Their visible sizes also differ (84x66, 78x60, 69x70).
   - **World window:** the World icon spills 7 px left (`Here` card).
3. **Small horizontal drift:** the Featured strip's four tiles (DoublePower, DoubleCash, TripleOpen, Lucky) sit
   2-3 px right of centre (pads L45 / R40).

**Fix (S-M):**
- One rule per slot kind: the icon's *visible* box fits inside the slot with an 8-10% margin. Place every Store and
  HUD icon with `Kit.place` and a rule, which already uses `M.Bounds`. At the moment only some HUD buttons do.
- Give items an optical size: scale by the visible box's larger side, so a flat gun and a tall potion read the same
  size.
- Re-upload (A1).

---

## Part D: the Gamepass section and Luck, against the references

**What the references show:**
- **`docs/refs/ui/ref_ui_shop_passes.png`** (Gamepasses page):
  - Two columns of big cards, about 4-6 on screen.
  - Each card is **one saturated colour** (red, yellow, blue, green, purple) with a faint stud texture.
  - Its parts:
    - a **huge icon on the left** (about 45% of the card, inside it);
    - the **title** big at the top right;
    - a **short description in 2 lines** of plain white text;
    - a yellow **OWNED** or price button at the bottom right.
  - **Luck leads the page, in tiers:**
    - "2x Luck: Permanent 2X Luck on rolls" (green clover on red);
    - a bigger tier, "Permanent 4X Luck on rolls" (rainbow clover on yellow);
    - then Faster Roll, 2x Cash, Premium Paint.
- **`ref_ui_shop_featured.png`** (Featured page):
  - The week's pack card. It has a "Limited Time!" pill and a countdown, which we only show because ours really
    rotates weekly.
  - Then a **full-width "Server Luck 1x > 2x, +15 minutes" card**: big blocky clover, the multiplier change in huge
    text, the price on the right.
  - So Luck has its own big card on the first page: a timed luck boost for the whole server.
- **`ref_V3-00.5_store_exclusive.jpg`:**
  - The egg card with odds and x10/x3/x1, which we now have (round 6).
  - An exclusive gun card with "2900/3000 LEFT". That is fake stock; never copy it.
- **`owner_ui_windows_oct27.png`** (the owner's mockup): under the egg card, a row of 4 small pass tiles: 2x Power,
  2x Cash, **Lucky**, Triple Open. Each is a coloured tile with the name on top, a big centred icon and a price pill.

**What we have** (preview of the Gamepasses section, Oct 27 build):
- **18 pass cards in one long list.** Lucky is the 5th, and it is the *only* luck item in the game (`Products`
  `Lucky`, 129, "Better odds for Epic and up in Cash boxes").
- **Cramped cards:**
  - Each card is 156 px tall with a 178 px icon, so icons spill out (Part C).
  - Its descriptions run 2-3 lines of 16 px heavy-stroked text that crowds the price button.
- **Busy colours and badges:**
  - Diagonal two-colour gradients (red > yellow, green > yellow) instead of one colour.
  - An "Info" tag over every icon (`Store.client.lua:630`, a squeezed purple piece, A3).
  - Every card shines and sparkles (B2).
- **No grouping:** Power/Cash, Speed, Auto, the three paid lanes and the 5 exclusive guns are all in one run.

**What "make luck separate" should mean (my reading, the same as yours):**
- **Luck gets its own tab** (Featured | **Luck** | Gamepasses | Cash | Power | Boosts | Boxes | Codes), with its own
  big cards, like the references.
  - **The hero card:** the Lucky pass with the honest odds change for each Cash box (Epic+ chance without > with
    Lucky), from `ShoeRules.weights(boxId, true)`, and the owned state.
  - **The other box-luck items we already have:** Triple Open, Auto Open, and the Chrome Box card with its odds and
    pity counter (the shoe boxes are what luck is for).
- **What the references also have that we don't sell:**
  - Tiered permanent luck (2x, 4x);
  - a timed **Server Luck** boost for everyone in the server.
  - These would be NEW Robux products. The owner must approve them and create them on the website, and
    `Config/Products` and `ShoeRules` must change.
  - Kid-safe: the odds shown everywhere must change while luck is on, and server luck must be the same for everyone,
    with a real timer.
  - **This needs one question to the owner before building.**
- **The Featured page keeps one Luck card** (the mockup's Lucky tile, or a full-width luck card like the reference
  once a timed boost exists), linking to the tab.

**Making the passes "more likely to buy" without tricks** (style of the refs):
- **Fewer, bigger cards:** 2 columns with about 4-6 visible.
- **One flat saturated colour per card**, by group: Luck green, Cash yellow, Power red, Speed and Auto blue, Lanes
  purple, Guns dark.
- **The art inside the card:** the icon's visible box at about 40-45% of the card's width.
- **Short words:**
  - a title of at most 2 words;
  - one benefit line of at most 5 words ("2x Cash forever", "Open 3 boxes at once");
  - the detail stays in Info.
- **Clear states:** an obvious OWNED state.
- **Grouped sub-headers:** Luck, Boosts, Auto, Lanes, Exclusive Guns.
- **Motion only on the top card of the page** (B2).

---

## Part E: what only Studio can show
- Whether EditableImages are drawn unsmoothed and without pre-shrunk copies (the jaggies on downscaled pieces, A3).
- The real per-screen picture-memory limit on a phone (A2, A5, B1).
- Whether whole-pixel snapping makes the bobs step (B6).
- Whether the "Allow Mesh / Image APIs" setting is on in the owner's place. If it is off, every packed picture shows
  its drawn stand-in instead.
- Judge at 100% in Studio's Device Emulator (iPhone, 1080p, 1440p).

## Suggested order (smallest work, biggest win first)
1. **A1:** re-upload the 56 stale icons, plus all shoes, boxes and new guns at 512 (1024 for the big views), after an
   alpha bleed (A6). This needs the owner's upload key. It fixes most of the icon blur, the centring and B1.
2. **A3, A4, A5:** switch the chrome to native drawing, tuned to the mockup's colours. Sharp at every size; no cut-out
   edges.
3. **B2, B3, B4, B5:** calm the Shop and fix the twitchy HUD motions (deletions and timing numbers).
4. **Part C:** the icon placement rule. **Part D:** the Luck tab and the pass-card redesign, after the owner's answer
   on new luck products.
5. **A7, A8:** text sizes and the half-pixel and corner details.
