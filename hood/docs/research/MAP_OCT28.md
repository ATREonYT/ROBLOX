# Map vs the references, Oct 28

The owner, after playing in Studio (Oct 28 00:42): "the map isn't good, there are too many shades ... remove the shades,
we need to make this cartoony ... check previous references of maps and how they look ... some of the crate models are
too small". "Shades" means cast shadows and dark shading on the parts.

Compared: the World 1 lobby and Stage 1 (preview r14, `hood/tools/preview/render14`, before = the Oct 27 lobby round 2
build, after = this round) against `docs/refs/ref_W01.0_spawn_view_north.jpg`, `ref_W00.0_lobby_eggs_foreground.jpg`,
`ref_STILL_lobby_topdown_superhero.png`, `ref_STILL_training_lanes_superhero.png` and `docs/INSPIRATION.md`.
The picture: `hood/art/renders/map-oct28/map_oct28_sheet.jpg`.

## Measurements

| What | Before (Oct 27) | After (Oct 28) | Reference |
|---|---|---|---|
| Spawn view mean brightness | 130 | 147 | W01 139 (rule: ~145) |
| Spawn view near-white | 0.0 % | 0.1 % | W01 0.4 % (rule: under 1 %) |
| Dark part surface in the hall (luminance under 95) | 15.6 % | 2.5 % (all saturated reds and purples) | |
| Cast shadows | sun shadows under the roof girders, the gates, every prop | none (GlobalShadows off) | W01 soft shadows; the owner wants none |
| Range bays view | | mean 141, median S 0.71 | training lanes ref |
| Stage 1 start | median S 0.27, grey-blue road | mean 157, lavender road | W01 path #A29DC0-#B0AED0 |
| World 2 stage 5 / 8 | 160 / 158 | 161 / 154 | |
| Sale chests by the spawn (body) | ~2.9 wide, 1.7 tall | ~4 wide (6.6 with wings) | W01 "MOST OP!" item ~ a player tall |
| Group and codes chests | 3.2 tall | 5.2 tall, 6.2 wide | top-down ref chests ~ 1.5 players wide |
| Shoe boxes on the dais | 4.9 tall (Robux box 3.5) | 6.6 tall, 8.2 wide (Robux box 5.3 on its plinth, same top) | W00 eggs ~ a player tall |

## The worst gaps, worst first

1. **Shadows and dark shading everywhere (fixed).** PlusOne drew real sun shadows: the roof girders striped the
   floor, the closed roof darkened the hall, and every surface was built in 2-3 darker cuts of its colour (navy steel,
   brown skirting, 45 %-black bay rims, dark kerbs). Fix: `HoodLighting` PlusOne now has GlobalShadows off, a high warm
   Ambient (168, 164, 160) everywhere, a gentler sun (1.15), saturation 0.5. `x_look` `Look.cartoon` lifts every
   remaining dark cut of a colour to the same hue at value 0.6 in both worlds (ink under 0.2 stays: hazard stripes,
   tyres, outlines; the owner's meshes, Neon, glass and word boards are untouched). The palettes went flat at the
   source too: one brick tone, a toy-blue steel, bay rims 20 % darker instead of 45 %, the armory's light stone bands,
   the street's single tones.
2. **The crates read too small (fixed).** The two sale chests by the spawn were scaled to 0.75 in lobby round 1 and fitted by
   their wing span, so their bodies were ~3 studs: now full size, fitted at 6.6. The group and codes chests were at
   0.62: now full size. The dais boxes were width-limited at 6.6: now 8.4 wide, 6.6 tall, over a player's head
   like the reference's eggs; the Robux box keeps the middle on its plinth with the same top.
3. **Stage 1 read grey (fixed in colour, not in shape).** The street was a mid blue-grey road between grey sidewalks.
   The ref's path is a light lavender stone between bright grass. The road is now the ref's lavender, the sidewalks
   a paler cut, and the second and third tones of brick, trim, roof, lamps, fence and grass are one flat tone each.
   Still worse than the ref: the buildings' cream and grey fronts fill the frame where the ref has clay cliffs and
   grass, and the row of gates shows straight down the street (World 1's haze stays 0.5; the preview can't draw it).
4. **Saturation is still below the reference** (median 0.35 at the spawn vs 0.68). The cause is the owner's
   warehouse: a warm concrete floor and lavender walks fill half the frame where the ref has saturated grass. The
   grade is at 0.5 and the preview draws it at 0.4x strength, so Studio will look more saturated than these numbers.
   Raising the floor's saturation further would turn it orange; the honest fix is bigger saturated floor fields
   (zone platforms in their colours), a design decision for the owner.
5. **The owner's meshes keep their own darks.** The Pad_Base under the sale chests has a dark navy rim, and the base of
   the Stage 1 gate (Gate_Stage1) is near black. They're the owner's designs, so this pass doesn't touch them. If they read too dark in
   Studio, they need a lighter version from Claude Design.
6. **The dais close-up is bright** (mean 163). That's the light deck and steps filling a close view; the spawn view
   is at 147.

## Kept as the owner asked

The warehouse (orange brick, cream pilasters, blue steel, painted fields, warm concrete floor, closed roof), the
Stage 1 gate straight ahead, the 2 Robux pads by the spawn, no grass inside, the themed bays without side walls, no
props on the open floor.

## What the preview can't show (check in Studio)

- **Shadows:** the preview never drew the hall's shadows the way Studio does. "No shadows" is the GlobalShadows switch,
  so it holds in Studio by construction. How even the light looks in Studio is still to check.
- Exposure (emulated here with `kec=1`), the grade's full saturation, and the gate haze.
