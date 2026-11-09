# v3 recreation: what still differs, per phase

How to read the sheets: each `compare/<view>_vNN.png` is **screenshot | render | 50% overlay**, half size. Full renders are in
`compare/renders/`. `metrics.json` holds the mean colour difference per view (HUD, players and props included, so it
only moves a little). `scripts/colour_stats.py` gives the class agreement (grass / path / wall / stone / sky) and the
mean colour per class where the screenshot and the render agree on the class.

## v00 baseline (ChessMap_Reference_Fix.blend, untouched)

Rendered at each screenshot's exact size. The phone camera now renders the 2024x796 box directly: a 35.638 degree
frame with shift (0.0930, 0.4058). Blender measures shift in frame heights with a vertical sensor fit; checked
against the old crop at 0.59/255 mean difference.

| view | class agreement | biggest differences |
|---|---|---|
| hub | 0.686 | No machines, props or signs. The trees at the bottom right are too big and too close. The screenshot is paler (lower saturation) than every close-up. |
| treadmill | 0.758 | No machines. The back wall's green band reads 22.2 to 24.8 high in the screenshot, but the render has a 0.6 cap, so the upper tier sits about 3 studs low. Two stepped trees stand on the stand where the screenshot has none. |
| phone | 0.844 | No gems, trophies, locks or signs. The trees on both sides are missing. |
| lane | 0.655 | The bank tops have a thick green lip in the screenshot. The trees don't match one for one. |

## v01 (Phase 1: alignment)

- **Hub camera refit** by mask overlap (`scripts/fit_hub_masks.py`). The projected 10-wide orange cross and both stand tops are matched against the screenshot's orange and grey masks, with the HUD masked out.
  - The camera moved 0.4 studs and 0.4 degrees.
  - Path overlap went from 0.782 to 0.790 and stand overlap from 0.511 to 0.527. Stand overlap stays low because machines, trees and the HUD cover the grey.
  - The path cross, both stand fronts and the lane mouth line up within about 3 px at half size.
  - The edges of the stands that the trees hide can't be measured. I back-projected the visible corners of the phone stand's near end and the treadmill stand's water end (`scripts/backproject.py`); both agree with the build to within about 2 studs.
- **Bank lip:** every bank top now has a 2.6-stud green lip.
  - The red faces still end at 22 and 36, as measured in lane_view.
  - The lower bank top is now 24.6 and the upper bank top 38.6.
  - Measured on the treadmill back wall plane (`analysis/closecam.py`, cam_tread):
    - green band 22.2 to 24.8 (render now 22 to 24.6);
    - upper top 38.7 (render 38.6).
- **Collections:** Hub (with Water and Portal), Treadmill, Phone, Lane (with the gate frames), and Shared (walls, foliage, cameras, collision).
- **No bevels:** every edge is hard and flat shaded.
- **Class agreement:** hub 0.695, treadmill 0.771, phone 0.844, lane 0.642.
  - The lane dropped 0.013. The thicker lip shows more green along the bank edges where the screenshot has trees in the way.
- **Still differs:**
  - the lane floor renders about 28/255 darker than the screenshot, because the banks shade it under the low sun (Phase 5);
  - the sky is too pale: the screenshot measures (64,185,254), the render (154,203,251) (Phase 5);
  - the hub screenshot is less saturated than the close-ups. Its grass is (123,230,71), where the close-ups give (41,229,9). The hub's walls and stone match the close-ups, so this looks like the screenshot's own colour grade, not the world.

## v02 (Phase 2: materials)

- **Grass and walls** were trimmed to the close-ups' class means, through texture multipliers in `TINT`.
  - Grass render vs screenshot: treadmill (46,239,18) vs (41,229,9); phone (49,229,24) vs (38,228,20).
  - Walls are now within about 12/255.
- **Stone, paths and pads:** these were already within about 10 to 16/255 in v00, so they are unchanged.
  - Stone and paths come from the texture pack's tiles with block seams.
  - Pads: mint, cyan, red, black, black.
- **Class agreement:** hub 0.695, treadmill 0.772, phone 0.844, lane 0.642.

## v03 (Phase 3: trees and water)

- **One tree, many copies:** each tree type (stepped, pale stepped, cube) is built once in Shared > Library and placed as collection instances. The scene went from 2774 objects to 594.
- **Moved off the stand:** the two stepped trees on the treadmill stand's top are gone; the screenshot has none there.
- **New trees:** two stepped trees now stand at the stand's water end, at (-74,-65) and (-24,-68), back-projected from hub_overview. The first is also the tiered tree at the left edge of terraceA_closeup.
- **Phone stand trees** moved to (57, ±53), back-projected from terraceB_closeup's trunks.
- **Water:** the red channel was raised. Hub water now renders (116,253,253); the screenshot is (110,236,250).
- **Class agreement:** hub 0.696, treadmill 0.795, phone 0.855, lane 0.644.

## v04 (Phase 4: props)

- **Treadmills:** Alex's 8 studded treadmills are appended unchanged and instanced (see `props.md` for which machine went where).
  - Scaled 1.4x to the stations' size in terraceA_closeup and turned to face the path.
  - Positions were checked against terraceA_closeup at about 9 px per stud, and the outer edges line up within about 10 px at half size.
- **Built props:** gems, phone items, padlocks, the Hologram Phone pad, the spawn marker and the "1 Like = 1 Sub" text, all as linked duplicates of one mesh per shape.
- **Chessboards:** skipped, Alex's choice; the file doesn't exist.

## v05 (Phase 5: lighting)

- **Sky:** 3FB6FF on camera rays. Screenshot (46-73,184-198,248-254), render (63-82,183-203,232-254).
- **Sun:** raised from 49 to 63 degrees, so the lane floor is no longer half in shadow. Lane stone went from -28 to -6/-14/-18.
- **Light:** sun edges softened from 3 to 6 degrees, and ambient raised from 0.8 to 1.0.
- **Bloom:** a compositor Glare node (threshold 1.0, strength 0.8) picks up the glowing props.
- **Exposure:** Standard view transform at -0.25. At 0.0 every view read about 15/255 too bright.
- **Class agreement:** hub 0.694, treadmill 0.801, phone 0.858, lane 0.651. At v00 these were 0.686, 0.758, 0.844 and 0.655.
- **Colour per class:** within about 17/255 everywhere except the hub's grass and the cyan class in the phone view. The phone view's cyan class is mostly sky and glow pixels.

## What still differs (final, v05)

1. **The hub screenshot's colour grade.**
   - Its grass is (123,229,71), where the close-ups and the render give about (45,230,15). Its walls and stone match the close-ups.
   - So the hub shot is less saturated than the other three. One world can't match both, so I followed the three close-ups.
2. **The machines are Alex's new studded designs, not the game's current low frames.** They are taller and more decorated than the stations in the screenshots. Their positions and footprints match.
3. **The phone stand's items are blocky stand-ins.** The screenshot's sparkly hologram phones and spinning effects are particle effects in the game.
4. **The gem glow is weaker than in the screenshot,** where it is a bigger soft halo from the game's own effects. The bloom is kept moderate so the stones and grass don't wash out.
5. **Chessboards:** not placed, because no asset exists (Alex chose to skip them).
6. **Trees on the top land and along the lane banks follow a regular pattern, not the screenshot's tree-for-tree layout.** The screenshots only show them partly, behind the HUD.
7. **The "1 Like = 1 Sub" sign** uses Blender's default font instead of the game's rounded one.
8. **Not modelled:** HUD, players, name tags, price and lock labels (BillboardGuis), and the yellow-to-magenta trail by the water.

## v06 (studs and colour match)

- **Stud textures (`textures/`, made by `scripts/make_studs.py`):** one 512 px tile holds 8x8 studs, mapped with world UVs at one stud per stud-unit.
  - `baseplate`: raised studs with a groove, on all grass (ground, caps, bank tops).
  - `inout`: a checker of raised and sunken studs, on tree leaves, shrubs and trunks.
  - `inlet`: sunken studs, on the orange path.
  - Each texture is a shade map (multiplied into the colour) plus a normal map (strength 2.0), so the scene's sun lights the stud edges.
- **Colours, render vs screenshot:** trunk (219,81,29) vs (215,80,30); pine lit side (58,252,16) vs (71,245,0); hub grass in the treadmill view (34,238,21) vs (21,233,1); phone grass (40,231,28) vs (38,227,19); lane wall (214,74,43) vs (210,68,45). Stone is within 6/255.
- **Exposure:** -0.5 (the stud shading brightened the whole scene by about 18/255 at -0.25).
- **Class agreement:** hub 0.689, treadmill 0.798, phone 0.856, lane 0.647 (about the same as v05; the studs add detail, not shape).
- **Checks:** `verify("v06")` passes (53 images packed and readable, 163 materials, routes unchanged). `tools/kidsafe_check.py chess-evolution` passes.
- **Kid-appeal checklist (map lines only):**
  - Hard edges and no chamfers on purpose: the screenshots are a hard-edged stud style, and the reference wins over the checklist's chamfer line.
  - Ground saturation is higher than the checklist's "soften the ground" line, again because the screenshots are that bright.
  - Paths are wider than 10 studs; the hub sees the machines, the phone stand and the lane from spawn.
  - Repeated props and trees are instanced (one mesh per shape).
  - Studio-only lines (LightingStyle, ColorCorrection, Anchored/CanCollide, phone test) can only be set and checked once the map goes into Studio.
- **Fresh critic (v06c), worst first:** (1) lane trees merged into the green banks, (2) every green side face as bright as the tops, (3) the hub's front-right tree is too far left and hides the end of the phone stand, (4) the back row of machines looks smaller than in the screenshot, (5) grass studs too faint.
- **Fixed in v06d (the final v06 file):**
  - Light: fill 1.35 -> 1.0, sun 1.9 -> 3.1. Darkest 10% of greens, render vs screenshot: lane G 188 vs 171, treadmill 188 vs 189, phone 181 vs 180 (was 210/207/... in v06c). Tops are unchanged (mid greens within 3/255).
  - Grass studs: stronger rim (0.40) and lighter raised tops (0.16), plus a lime highlight on raised stud tops (`STUD_HL`). Foreground grass, render vs screenshot: G spread 20.5 vs 19.1, R spread 25.5 vs 26.3 (was 14.0 and 7.1).
  - The lane trees now read as separate crowns against the banks.
- **Left as is:** the hub's front-right tree position (critic 3), and the back-row machines are Alex's new studded designs (critic 4).
- Sheet: `compare/final_sheet_v06.jpg` (tag v06d).
