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

## Uploading the renders

`hood/art/renders/guns/*.png` (1024 px) and `hood/art/icons3d/*.png` (512 px) have transparent
backgrounds, a dark outline and soft shadow, so they read on any button. Upload them (Asset Manager >
Bulk Import), then paste the ids into `M.Images` in the two modules. Re-running `export_luau.py` keeps
ids that are already filled in.
