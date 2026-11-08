# +1 Chess Evolution hub map (v2) — brief

Built with the blender-image-to-3d workflow, from Alex's references (Nov 8). Map only.

```text
ASSET       EN_ChessHubMap (environment, modular kit)
CATEGORY    environment / modular kit (hub, two terraces, water recess, portal shell, 14-bay stage lane)
VIEWS       ref/hub_overview.png    perspective, high three-quarter from rear-right, ~50 deg down, Roblox 70 deg vFOV. Hub layout authority.
            ref/terraceA_closeup.png perspective, frontal, ~25 deg down, player behind on path. Terrace A forms.
            ref/terraceB_closeup.png perspective, frontal, ~30 deg down. Terrace B forms.
            ref/lane_view.png       perspective, high lane camera, ~30 deg down along the lane. Lane module.
            ref/layout_sheet.png    generated sheet: orientation and naming only. The screenshots win where they disagree.
SCALE       1 Blender unit = 1 Roblox stud. Avatar ~5 studs tall (from the screenshots) sets everything else.
ORIENTATION Spawn crossing at origin, stage lane along +Y. Facing +Y: Terrace A and the portal on the left (-X),
            Terrace B on the right (+X), water recess behind spawn (-Y, left of the main path).
PROPORTIONS path width 12 (~2.4 avatar heights); hub 128 x 120; wall 14 tall (~2.8 avatars) + 10-stud grass shelf
            + second step to 24; lane 32 wide; bay pitch 40; red mat 13 x 16, right of centre; pads 5 x 4 on the left;
            terrace shelves 5 high, apron 1.2, Terrace B central floor 0.7 with rim at 2.
PARTS       Hub (grass, cross path, spawn square), Terrace_A (lower apron, raised rear shelf, two broad inset ramps),
            Terrace_B (lower central floor, two end ramps, long rear shelf, rim), Water (recess, stepped rocks, rails),
            Portal (shell only), Lane (floor, kerbs, 14 bay instances), Stage_Frames (14 separate square frames),
            Walls (one reusable section instanced around hub and lane), Foliage (3 reusable trees, bushes, sprigs, rocks).
MATERIALS   saturated studded plastic: grass lime, path orange, wall face orange with dark-rust band and grey skirt,
            green cap, stone light grey, lane grey, lime divider, red mat, charcoal plates, yellow and magenta pads,
            water cyan, portal blue-violet shell with pink inner. One shared stud grid (1 per stud) on every face.
ARTICULATION none (static kit).
INFERRED    everything outside the screenshots: absolute sizes (from avatar height), the far lane (repeated module),
            wall backs and shelf depths, tree count and placement, the recess depth, portal back side.
TARGET      Roblox Studio. Export groups as FBX per collection plus simple collision boxes; Studio install only after Alex approves.
```

## Result (Nov 8, render round 3)
- `ChessMap_v2.blend` is the editable scene; `build_map_v2.py` rebuilds it from scratch (run inside Blender).
- Final sizes changed from the first estimate after comparing with the screenshots: lane 28 wide, walls 18 tall
  with a second step at 30, Terrace B floor sunk to 0.5 inside a rim at 3 with a shelf at 4.2, frames 15 tall.
- `review/v3_four_panel_sheet.jpg` (overhead, three-quarter, lane cut, player eye) and `review/v3_compare.jpg` (screenshots vs Blender).
- `export/<Group>.fbx`: one FBX per collection (Hub, Terrace_A, Terrace_B, Water, Portal, Lane, Stage_Frames, Walls,
  Foliage) plus `COLLISION.fbx` (simple boxes). Reusable modules: Module_StageBay, Module_Wall, three trees, each at its own origin.
- Checks (raycasts): lane centre is clear from y 62 to 620 (only the stage frame crossbars, 15 up); paths sit 0.15 on grass;
  Terrace A ramps run 1.2 to 5 and Terrace B end ramps 0.5 to 3, both flush with the level they meet.
- Still worse than the screenshots: blocky trees are simpler, grass has no darker checker squares, the stud texture is
  a Blender stand-in (Studio uses its own studs), the far lane and wall backs are guesses.

## Texture pass (Nov 8, v3)
- Square Roblox-style studs on every surface (dark top/left edge, light bottom/right), with stronger bump.
- Tile variation read from the screenshots: 4-stud grass checker, 2-stud stone tiles, soft lane and wall tiles.
- Stage barriers: grey curbs either side of a lime strip at every stage boundary; side kerbs on the lane.
- Fuller trees (six-tier pine, big offset-cube tree, pale trunk), chunky studded bushes, neutral greys, red-orange walls.
- Still worse than the screenshots: the lime strip between stages reads thinner than the reference, trees are bigger
  blocks without the small stud overhangs, no small grass tufts on top of walls.

## Colour, shading and tree pass (Nov 8, v4)
- Colours measured from lit faces in the screenshots (24 px medians), lighting lowered so lit faces land on them.
- Soft rounded block edges (bevel, hardened normals) plus contact shading in corners on every visual mesh.
- Trees, bushes and trunks use a mixed sheet of raised and sunken square studs; one tree has a leaning trunk
  and both trees have flat splayed root planks, as in Alex's tree close-up. Normal square studs everywhere else.
- No gate at the lane entrance (Alex): frames start at stage 2.
- Sheet and compare: `review/v4_four_panel_sheet.jpg`, `review/v4_compare.jpg`.
- Portal turned 45 degrees to face the spawn corner; no trees inside the hub, so the stands are clear (Alex).
- Four trees at the rear corners of both stands, on the raised back shelf (Alex: trees behind the stands).
