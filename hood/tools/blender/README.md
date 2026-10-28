# BoxKit: blocky stud-style models, Blender renders, Roblox exports

One model description in Python drives everything:

```
models/guns.py, models/icons.py   (BoxKit primitives in design units, Roblox axes)
        |                 |                   |                     |
  render.py (Cycles)  export_luau.py    verify_models.luau     export_fbx.py
  hero PNGs, sheets   GunModels.lua     contract checks +      FBX + palette atlas
                      IconModels.lua    .rbxmx per model       (MeshParts)
```

What you render is what the game builds: `export_luau.py` writes the same primitives as plain Parts
(bevels are the only render-only extra). `compare.sh` proves it by rendering the Luau-built parts with
the three.js previewer next to the Blender shot.

## Run it

Blender 5 as a Python module (`pip install bpy`) is all that is needed; no GPU.

```sh
PY=path/to/python-with-bpy
python3 hood/tools/blender/export_luau.py                 # Models/GunModels.lua + IconModels.lua (lint first)
lune run hood/tools/blender/verify_models.luau hood hood/art/models/roblox   # checks + .rbxmx
$PY hood/tools/blender/render.py guns                     # hood/art/renders/guns/<Id>.png, 1024 px
$PY hood/tools/blender/render.py icons                    # hood/art/icons3d/<Id>.png, 512 px
$PY hood/tools/blender/render.py turntable                # hood/art/renders/guns_turntable.png
$PY hood/tools/blender/render.py sheets                   # guns_ladder.png, icons_sheet.png
$PY hood/tools/blender/export_fbx.py                      # hood/art/models/fbx/<Id>.fbx + palette.png
BLENDER_PY=$PY hood/tools/blender/compare.sh             # Blender vs Roblox parts (uses hood/tools/preview)
```

Add `--res 384 --samples 24 --out /tmp/x` to `render.py` for quick previews while modelling.
Set `BK_TMP` to choose where intermediate render passes go.

## HUD icons in the reference style (brief 19): icons_hd.py + hdkit.py

The HUD/window PNGs in `hood/art/icons3d/` are no longer BoxKit renders: `icons_hd.py` models each icon directly in
Blender as smooth cartoon shapes (bevelled boxes, swept bands, lathes, metaballs, text) to match the reference game's
icons, and `hdkit.py` holds the shared kit:

- material: glossy plastic whose base colour runs through a hue-shifted 3-stop ramp driven by the key-light angle
  (dark -> base -> light), plus an optional world-space grid of soft raised squares (the reference's surface tiles);
- camera fitted to the evaluated geometry, a camera-relative light rig, Cycles at 2x the output size;
- post: a navy (#0C0A34) outline ~3.4% of the canvas around the silhouette (exact distance transform) and thinner
  lines (45%) wherever two "line groups" meet, from the object-index pass; optional glow + sparkles; 2x downsample.

```sh
$PY hood/tools/blender/icons_hd.py --list                   # the ids
$PY hood/tools/blender/icons_hd.py                          # all -> hood/art/icons3d/<Id>.png (512 px), ~30 s each
$PY hood/tools/blender/icons_hd.py Muscle Rebirth --out /tmp/x --res 256 --samples 10   # quick previews
python3 hood/tools/make_ui_textures.py                      # hood/art/ui/ stud + gloss tiles (plain python3)
python3 hood/tools/upload_assets.py --dry-run               # see hood/art/README_upload.md
```

Shoe and box icons (`Shoe_<id>`, `Box_<id>`, brief 22) are rendered from the game's own part models: export them with
`export_luau_parts.luau` through the preview harness, then point icons_hd at the JSON:
```sh
cd hood/tools/preview && lune run harness.luau ../../src - "OUT='/tmp/parts.json' ALL=true $(cat ../blender/export_luau_parts.luau)"
BK_PARTS_JSON=/tmp/parts.json BK_MORE_SHOES=<comma list of non-World-1 ids> $PY hood/tools/blender/icons_hd.py Shoe_RedRocket Box_Grail
```
(`hdkit.import_parts` rebuilds the Parts, WedgeParts, cylinders, balls and sphere meshes, and the name plate text, in the
icon look; `PART_LOOK` in icons_hd.py lifts a too-dark model.) Their live fallback needs no BoxKit model:
`IconModels.build('Shoe_<id>')` / `('Box_<id>')` delegate to ShoeModels / BoxModels (`EXTERNAL` in models/icons.py).

The BoxKit models in `models/icons.py` stay as the live in-game fallback (`IconModels.build`). Ids that only have a
PNG reuse another model through `ALIASES` (written as `M.Alias` in IconModels.lua). `export_luau.py` keeps every
id already in `M.Images`, including keys the upload tool added.

Soft edges for the shoes (Oct 28): `export_round_meshes.py` makes the two rounding meshes (RoundBox, RoundWedge, size 1)
into `Shared/Models/RoundMeshData.lua` (for the game, Shared/RoundMesh) and `hood/art/models/round/*.obj` (render14 draws
them through its `round` link). Uploading them is optional: `hood/tools/studio/upload_round_meshes.lua` in Studio's
command bar prints the ids for `Config/RoundMeshIds.lua`; until then each client builds them in game (Game Settings >
Security > "Allow Mesh / Image APIs"), and without either the shoes keep their sharp Part blocks.
```sh
$PY hood/tools/blender/export_round_meshes.py
```

## Getting the models into Roblox Studio

1. **Parts (the main path).** Rojo syncs `src/ReplicatedStorage/Shared/Models/*.lua`. In game code:
   `local GunModels = require(ReplicatedStorage.Shared.Models.GunModels)`, then
   `GunModels.build('AK', 2)` returns an anchored Model with `PrimaryPart` (`Handle` for guns, `Root`
   for icons) at the origin. `GunModels.weld(model)` unanchors and welds for a held Tool.
   `IconModels.viewport('Shop')` gives a live 3D ViewportFrame until the PNGs are uploaded.
2. **.rbxmx.** Drag `hood/art/models/roblox/<Id>.rbxmx` into Studio: the same Parts as a saved Model.
3. **FBX as MeshParts.** File > Import 3D, pick `hood/art/models/fbx/<Id>.fbx`, then:
   - File General: *Import Only As Model* on, *Upload to Roblox* on (gives mesh + texture asset ids),
     *Set Pivot to Scene Origin* on (the grip / icon centre), *Anchored* on.
   - File Transform: *World Forward* = Front, *World Up* = Top (defaults).
   - File Geometry: *Scale Unit* = Stud. Leave *Merge Meshes* off (one MeshPart per material).
   - After import, select the model and run `studio_apply_materials.lua` in the command bar: it sets
     each MeshPart's Material from its name (`Pistol_Metal`, `Blaster_Neon_c46eff`), and gives Neon and
     Glass parts a plain Color, because those materials cannot glow or tint through a texture.
   The exporter already uses the Roblox-documented Blender settings (Apply Scalings = FBX Unit Scale,
   Forward = Z, Up = Y, Path Mode = Copy + Embed Textures, no leaf bones, no animation), triangulates,
   and stays far under the 20,000-triangle mesh limit (largest is about 9,000).

4. **The user's blocky designs as meshes (brief 32; replaces brief 31's FBX).** `build_item_package.py` (plain python3)
   merges the designer's per-object .glb files into four import files, `hood/art/models/items/Items_{Pads,Lobby,Scenery,Guns}.glb`
   (57 ids: pad prizes + Pad_Base, the lobby hero pieces, Target_Dummy, the plaza scenery Scn_*, the 10 shop guns + the 5
   Robux guns), writes `manifest.json`, regenerates `studio_item_meshes.lua` (edit `studio_item_meshes.template.lua`) and the
   `ItemMeshes.Design` table. The user imports the four files once and runs the script (`hood/art/MESH_IMPORT.md`); the game
   reads `ReplicatedStorage.HoodItemMeshes` through `Shared/ItemMeshes` (`GunModels.build` uses the gun meshes on its own)
   and falls back to the Parts. `icons_glb.py` renders the Gun_* and pass icons from the same GLBs.
   `export_item_meshes.py` (brief 31's BoxKit FBX) only runs with `--legacy`.

## Uploading the renders

`hood/art/icons3d/*.png` and `hood/art/ui/*.png`: `python3 hood/tools/upload_assets.py` (Open Cloud, writes the ids
into IconModels.Images and UIKit), or by hand: `hood/art/README_upload.md`. `hood/art/renders/guns/*.png` (1024 px):
Asset Manager > Bulk Import, then paste the ids into `GunModels.Images`. Re-running `export_luau.py` keeps ids that
are already filled in.
