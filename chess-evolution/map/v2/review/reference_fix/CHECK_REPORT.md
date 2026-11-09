# Chess hub map: Reference Fix check report (Nov 9)

Build: `build_reference_fix.py` (MARK rf5) → `ChessMap_Reference_Fix.blend` (44 pack images packed; it reopens with all 44 materials and no missing images).
FBX per collection: `export_rf/`. Texture pack: `texture_pack/` (Alex's pack, unchanged). Comparison sheet: `rf_comparison_sheet.jpg`.

## What changed in the measurements

- **The map was about 9% too small.** The path is 12 studs wide: 10 orange stud glyphs plus a 1-stud brown edge on each side, counted in the treadmill close-up. The lane is 48 studs wall to wall, counted from the studs on its floor.
- **The real camera has a 70° view.** With focal length left free, the lane camera solve converges to 70.3°. The v7 hub camera used 81°, which stretched the map along the view. All four cameras are now Roblox 70° cameras with no roll:
  - **Hub:** refit on the crossing and the path edges.
  - **Treadmill:** path edges and the stand's front edge, 3.5 px rms.
  - **Phone:** path edges and the stand's front edge, 1.8 px rms. The phone screenshot is a 2024×796 crop of a 3024×1734 frame at (574, 146); I found its position by matching the on-screen buttons. The camera renders the full frame and the comparison crops it.
  - **Lane:** lane edges and three dividers, 1.3 px rms.
- **The world positions agree across views.** Each value below is the cameras' reading against the build value:
  - treadmill stand front: -33.1 vs -34
  - phone stand front: 28.1 vs 27
  - lane mouth: 73.5 vs 76
  - portal: (-14.9, 30.8) vs (-16, 28.5)
  - phone stand far corner: 42.9 vs the apron edge at 44
- **Lane:**
  - Bays repeat every 48 studs. There are 2 starter bays, then gates into stages 2 to 14 (15 bays in total).
  - The red mat is 26×24 with two 4×5 markers. The yellow and magenta tiles are 8 wide.
  - Each divider is a curb, then 2 studs of lime, then a curb.
  - Gates are 24 tall and span 50 studs across.
  - The lane view was taken after stages 2 and 3 were unlocked, so their gates are hidden in that render only. Its first gate is the magenta stage 4 gate, with three open bays in front of it.
- **Banks:** the lower face is 22 high, the green ledge is 13 deep, and the top land is at 36. All three were sampled along projected world lines in the lane view. The block right of the lane rises straight to the top land.

## Colour patches (render vs your targets, largest channel error)

| patch | target | render | error |
|---|---|---|---|
| tread approach | F1840E | F68319 | 11 |
| tread paving | ACBDBE | B0BEBE | 4 |
| phone apron | B4C3C6 | B4C5C7 | 2 |
| phone rear dirt | AB441C | AF4724 | 8 |
| lane left face | D85529 | D9592E | 5 |
| lane floor | B1C4C2 | ADBBBB | 9 |
| lane red pad | FF1933 | F52030 | 10 |
| lane yellow tile | F4C61C | FFD32B | 15 |
| hub water | 74F5FD | 41F1FF | 51 (too dark in red) |
| lane right grass | 5FFC0E | (lands on a tree trunk in the render) | n/a |

The hub lawn now renders #37ED13. The close-ups sample the screenshot grass at #0EE900 to #61FE0D.

## Largest remaining discrepancy per view

| view | colour-class agreement | largest gap |
|---|---|---|
| Hub | 0.70 | Walls and trees at the frame edges look taller and closer than in the screenshot. The hub screenshot also has a light distance haze that I did not add. The hub view and the close-ups disagree slightly on wall height; I followed the close-ups, which are measured more precisely. |
| Treadmill | 0.79 | The ramps read flatter than in the screenshot. The wall behind shows one level, where the screenshot shows the upper tier above the green band. The far ends of the deck are estimated. |
| Phone | 0.87 | Pad and plinth spacing is within about 1 stud, which is about 10 px at 587 wide. The depth of the pocket and the shelf section is estimated. |
| Lane | 0.68 | The trees along the banks don't match one for one: the screenshot's trees sit closer to the bank edges and the big right tree stands slightly further left. The right foreground block is estimated from two edges. |

Overall alignment: paths, stand outlines, pads, lane bays and gates land within about 5 to 10 px at 587 px wide. Banks and trees are worse.

## Estimated, not measured

- Heights of the stand decks: treadmill deck 1.0 and shelf 2.6; phone apron 1.2, pocket 0.4, shelf 5.
- Off-screen extents: the far bank behind the water, the far ends of the stands, and the lane past stage 7.
- Tree count and placement on the top land.
- Shrub sizes.
- The stone feature's block layout.
- Gate colours past stage 6.

## Not built, as the prompt says

UI, characters, treadmills, phones, effects, purchase markers and YouTube branding.
