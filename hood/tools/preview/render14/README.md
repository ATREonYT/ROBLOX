# render14: the preview renderer that draws the owner's designs

render13 (Roblox-fidelity lighting, HoodToy, Montserrat and the Robux sign, Studs surfaces) plus the owner's GLB
designs from `hood/art/models/items` (`glb` is a link to that folder). Saved from the B31-B33 sessions so it no longer
lives only in a temp folder.

## Setup (once)
- `cd hood/tools/preview/render14 && npm install` (three.js 0.160 and Playwright; `node_modules` is not in git).
  Set `CHROME=/path/to/chrome` if Playwright's own Chromium isn't installed (`npx playwright install chromium`).
- Lune 0.10.5 for the harness (see `../README.md`); pass it as `LUNE=/path/to/lune`.

## Use
```sh
T=hood/tools/preview/render14/tools
LUNE=... sh $T/export.sh out/fake fake "0,38,0"     # build with the designs faked in (+ an avatar at x,z,yaw)
LUNE=... sh $T/export.sh out/nofake nofake          # our Part fallbacks only (Studio before the import)
sh $T/render.sh out/fake/scene.json views.json out/shots 1200 750
python3 $T/sbs.py out/shots/spawn.png hood/docs/refs/ref_W01.0_spawn_view_north.jpg sbs_spawn.jpg
```
- `views.json`: `{"options":{"time":3,"bloom":true,"lighting":"HoodToy","lights":24},"views":[{"name":"spawn","pos":[x,y,z],"look":[x,y,z],"fov":70}]}`.
  The lobby is built at world x + 2400 (map x 0 = world 2400). `plan.json` (from export) drops the roof for top-down views.
- Walk video: `FPS=30 WALK="0,38;0,33;-30,33" node walk.js scene.json frames/ 854 480 <frames>`, then
  `ffmpeg -framerate 30 -i frames/f_%04d.png -pix_fmt yuv420p walk.mp4`. The avatar walks the map-frame route with a
  follow camera 12 back and 9 up. `GUIDE=<guide_frames.dat>` (from `ui/corevideo.luau`) adds the real goal guide's parts
  for each frame, recorded in the game harness on the same route (its route is the default WALK then).
  `CAM='back,up'` sets the follow camera (12,12 with GUIDE: from head height the avatar hides the trail's first 15 studs).
  Each frame takes about 11 s; `START`/`END` render a chunk, so three chunks can run side by side.
- `tools/lobby_metrics.luau`: the lobby's numbers (distances from the spawn, labels readable from it, empty floor share,
  design models tilted). Run it after a build through the harness.
- `round` links `hood/art/models/round` (the shoes' rounding meshes, Shared/RoundMesh): `ui/items_scene.luau` injects
  MeshPart templates whose `PreviewMesh` names these OBJs, so shoe pictures show the soft edges.
- `tools/fake_items.luau`: fakes `ReplicatedStorage.HoodItemMeshes` the way the Studio import leaves it, so builders take
  the design path and the renderer draws the GLB meshes.

## What it gets wrong (check in Studio)
Classic Studs surfaces are drawn bigger and harder than Studio draws them; particles are unlit approximations; shadows
and bloom are close but not Studio's; billboards are all drawn (Studio's LabelFade hides far ones).
