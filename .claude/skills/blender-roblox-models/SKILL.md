---
name: blender-roblox-models
description: Use when making or changing 3D props, weapons, pickups or HUD icons for the Hood Roblox game in the low-poly, blocky, classic-stud style - modelling them in code with the BoxKit pipeline (hood/tools/blender), rendering polished Cycles PNGs for UI/upload, and exporting the same model to Roblox as Parts (generated Luau module), .rbxmx, or FBX MeshParts. Also use when asked how to import Blender/FBX models into Roblox Studio, or when renders look washed out, black-speckled or do not match what the game builds.
---

# Blocky stud-style models: Blender renders + Roblox exports (BoxKit)

Everything lives in `hood/tools/blender/` (read its README for commands). One Python description of a
model drives the Cycles render, the Roblox Parts module, the .rbxmx and the FBX, so what the user sees in
a render is what the game builds. Never hand-edit `Shared/Models/*.lua`; they are generated.

## 1. Model in code (models/*.py)

- Units: **design units (DU)**, 1 DU = one stud-bump pitch. `Model.unit` converts to studs at scale 1
  (0.2 for guns and icons, so a stud bump is 0.12 wide x 0.05 tall and a pistol is ~1.5 studs).
- Axes are **Roblox axes**: x right, y up, front/muzzle toward **-z**. Seen from the front camera,
  screen-right is world **-x** (easy to get mirrored text such as "$" wrong).
- Primitives (`boxkit.Model`): `box(pos, size, colour, kind, rot=, studs=, skip=, bevel=)`,
  `wedge` (Roblox WedgePart: tall face at local +z, slope down to the -z bottom edge), `cyl` (round,
  axis = local X like Roblox cylinders; `axis='y'|'z'` turns it), `prism(sides=6|8)` (low-poly n-gon;
  Roblox gets sides/2 crossed blocks, so it costs 3-4 parts), `ball`, `stud`, `tri` (arrowhead from two
  wedges). `with m.at(pos, euler(rx, ry, rz)):` builds a tilted sub-assembly (euler = CFrame.Angles).
- `studs=True` puts classic studs on the box's local +y face, one per whole DU; `skip(x, z)` drops some
  (under a handle, a ribbon, a sight). Studs are separate parts: budget them.
- Colours: names from `boxkit.PALETTE` (or an RGB tuple). Kinds: plastic, smooth, metal, gold, neon,
  glass -> Roblox Plastic, SmoothPlastic, Metal, Foil, Neon, Glass (table `M.Materials` in the module).
- Gun contract: origin = grip centre, muzzle -z (`m.meta['muzzle']`), <= 120 parts. Icon contract:
  `recentre()` then fit 10 DU (= 2x2x2 studs); `build_all()` shrinks `unit` if an icon is bigger.

### Style rules that made it look good
- Chunky toy proportions: thick barrels (0.8-1.05 DU), fat grips, big readable silhouettes. Real-gun
  slenderness looks thin and black at icon size.
- One tier colour per model, used on large pieces (frame, mag, receiver), wood/dark steel elsewhere.
- Tier ladder = stack channels: plain plastic -> colour accents + studs -> wood furniture + more parts
  -> gold + gems -> first neon -> neon coils -> diamond glass + gold + glowing core. Renders add a
  tier-coloured halo and sparkles from tier 7 (`render.BLING`).
- Icons: one big shape + one accent colour; check them at 64 px on a coloured button (icons_sheet.png).
  Profiles read better than front views for gloves/guns; a stepped "pixel" arrow reads as a tree.
- **Never let two parts share a face plane where they overlap** (same-size joined boxes, a bar and its
  post, ring segments). Cycles renders black wedges there and Roblox z-fights. `boxkit.lint(model)`
  finds them; fix by offsetting 0.02-0.05 DU or alternating depths. `export_luau.py` prints lint first.

## 2. Render (render.py, bk_blender.py) - settings that look good
- Cycles CPU, 96 samples, adaptive 0.02, OpenImageDenoise; 1024 px guns, 512 px icons. ~1.5 min/gun.
- **View transform Standard, not AgX**: AgX desaturates toy colours to pastel. Light rig is placed
  relative to the camera (key, fill, top, two rims) with energy scaled by distance^2 (`LOOK['light']`
  0.15); world = vertical gradient (warm floor, grey horizon, blue sky) at 0.3 so metal and gold have
  something to reflect. A dark floor colour turns gold sides brown.
- Materials: smooth plastic rough 0.26 + 0.35 clear coat; metal metallic 0.55 (full metal goes black
  in a studio world); gold metallic 0.85 rough 0.22; neon emission 1.25 (above ~1.5 it clips to white,
  the colour comes back through the bloom); glass = stylised gem (alpha 0.72, coat 1, faint emission),
  because physical transmission reads as pale ice.
- Bevels (0.05-0.07 DU, harden normals) are render/FBX-only; they give the toy edge highlights.
- Post (numpy, `bk_blender.finish`): bloom from the Emission pass (saved by a compositor File Output
  node; Blender 5 uses `scene.compositing_node_group`), dark navy outline (~1% of width), soft drop
  shadow, optional back-glow + sparkles. Transparent PNG ready for upload.
- Camera: `camera_fit` frames all vertices with a 70 mm lens; long guns get a diagonal roll.
- Look at every render (Read the PNG). Fast previews: `--res 384 --samples 24 --out <scratch>`.

## 3. Roblox scale, axes, limits
- 1 Blender unit = 1 stud when exporting. Roblox (x, y, z) = Blender (-x, z, y); FBX export with
  Forward = Z, Up = Y undoes this exactly (verified by re-import).
- Part sizes may go down to 0.001 studs; below 0.05 they are only physically treated as 0.05
  (BasePart.Size docs), fine for anchored, non-colliding decor. Balls must be uniform.
- Parts: Anchored, CanCollide/CanTouch/CanQuery false; CastShadow off for studs, neon and glass.
- PrimaryPart is an invisible `Handle` (guns) / `Root` (icons) at the origin, so the pivot is the origin.
- Mesh limits: 20,000 triangles per mesh, watertight, no n-gons (exporter triangulates).

## 4. Export paths
1. **Parts module** - `python3 hood/tools/blender/export_luau.py` writes
   `src/ReplicatedStorage/Shared/Models/GunModels.lua` / `IconModels.lua`: `M.build(id, scale)`,
   `M.weld(model)`, `M.viewport(id)` (ViewportFrame), `M.Ids`, `M.Images` (kept across re-exports),
   `M.Meta` (Size, Center, Muzzle, Tier, Parts). Rojo syncs it: this is the "import into Studio".
2. **.rbxmx** - `verify_models.luau` serialises each built Model with Lune (`roblox.serializeModel`)
   into `hood/art/models/roblox/` (drag into Studio).
3. **FBX + palette atlas** - `export_fbx.py`: one `palette.png` (8 px swatches); every face UV'd to its
   swatch centre (closest filtering, no bleeding); objects split per Roblox material
   (`<Id>_<Material>`, Neon/Glass also per colour `<Id>_Neon_<hex>`). Settings: Apply Scalings = FBX
   Unit Scale, Forward Z, Up Y, Path Mode Copy + Embed Textures, no leaf bones, no bake animation.
   Studio: File > Import 3D, Scale Unit = Stud, World Forward = Front, World Up = Top, Set Pivot to
   Scene Origin on, Anchored on, Merge Meshes off; then run `studio_apply_materials.lua`
   (Neon/Glass need a plain Color: textures do not glow).

## 5. Verify (all four, every change)
- `export_luau.py` -> lint clean, part budgets printed.
- `lune run hood/tools/blender/verify_models.luau hood hood/art/models/roblox` -> builds every model
  at scales 1, 0.5, 3: PrimaryPart at origin, flags, min size, <= 120 parts, exact bounds = Meta,
  icons inside 2x2x2 and centred, muzzle at the -z end, `weld()` works. (2516 checks.)
- `compare.sh` -> `hood/art/renders/compare_blender_vs_roblox.png`: Blender shot next to the
  Luau-built Parts rendered by the three.js previewer with the same camera. Shapes must match 1:1
  (the previewer's lighting is darker; that is fine).
- `export_fbx.py` re-imports each FBX and checks size against the model and triangles < 20k.

## Sources
- Roblox Creator Docs (mirror commit 9f840b1): `studio/importer.md` (formats; FBX/glTF carry vertex
  colours; File General/Transform/Geometry settings incl. Scale Unit, Set Pivot to Scene Origin,
  Anchored, Merge Meshes, Ignore Vertex Colors), `art/modeling/export-requirements.md` (Blender FBX:
  Path Mode Copy + Embed Textures, Apply Scalings = FBX Unit Scale, no leaf bones, no bake animation),
  `art/blender.md` (Unit System None, Forward Z / Up Y, FBX imports too large with default scaling,
  glTF needs no scaling fix, vertex painting), `art/modeling/specifications.md` (20,000 triangles,
  watertight, no n-gons), `reference/engine/classes/BasePart.yaml` (Size 0.001..2048, physics floor 0.05).
  Online: https://create.roblox.com/docs/studio/importer and https://create.roblox.com/docs/art/blender
- Web search summaries (pages not opened, treat as unverified): Roblox reduces meshes over 20k
  triangles rather than rejecting them and treats 1 unit as 1 stud (nilo.io/articles/roblox-studio-3d-import-tips);
  vertex colours multiply with MeshPart.Color, so set Color to white (DevForum "Vertex Colored Meshes
  using Blender and Studio", devforum.roblox.com/t/3050119); Neon on a textured MeshPart does not glow
  from the texture (DevForum "Trouble making mesh neon", devforum.roblox.com/t/trouble-making-mesh-neon/3058484).
