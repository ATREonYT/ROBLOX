# B31 LOOK RECIPE: build like the soldier game

Rules a builder follows without thinking. Each rule cites a frame (F = `brief/B30/frames/`, R30 = `brief/ref30/`) or a
source. Measured numbers come from `work31_LOOK/tools/pal.py` (median RGB/HSV of a patch, luminance spread) on the
reference frames. "Ours" = B30 LOBBY (`work30_LOBBY/shots/f2/still`, `p3/p3_four.jpg`) and Studio
(`brief/ref23/ours_studio_spawn.png`, the real client).

## 0. The diagnosis, verified

| What | Reference | Ours (B30) | Source |
|---|---|---|---|
| Median saturation of the world (HUD cropped) | 0.48-0.74 | 0.31 (spawn), 0.52 (lanes) | F/ref_W01.0, W00.0, STILL_training_lanes; R30/ref_product_pads |
| Pixels with S > 0.6 | 32-69 % | 28-41 % | same |
| Median value (brightness) | 0.78-0.90 | 0.71 | same |
| Stud contrast on the ground (luminance std inside a lit patch) | 5-8 (grass), path ~25-30 incl. tile seams | 35-47 | ref_product_pads grass, W01 path; ours p3 floor |
| Studded share of all lobby surface | ground + cliffs only | 57 % (walls, pillars, props, boards) | export of the B30 lobby |
| Shadow vs lit ground (luminance) | 117 / 155 = 0.75, hue keeps, S stays 0.73 | no cast shadows (voxel, 70 % ambient) | ref_product_pads drone/gun shadow; HoodLighting.lua HoodSun notes |

All six of the lead's points hold. One correction: the reference is NOT stud-free off the ground. Its clay cliffs
are studded (ref_product_pads top-left), but **tone-on-tone**: the stud is a faint bevel in the face's own colour.
Ours are Roblox's `SurfaceType.Studs`, which the real client draws as a high-contrast white/black stroke texture
(ours_studio_spawn.png floor). That stroke is the "AI slop" noise, not studs as such.

## 1. Studs (the biggest single gain)

1. **Never use `SurfaceType.Studs`** on anything. In the real client it is a hard white-and-black stroke per stud
   (ours_studio_spawn.png); at 57 % coverage it is the noise people call "AI slop".
2. **Ground gets faint studs**: one `Texture` on the Top face, `Texture = UIKit.StudBevel` (already uploaded: one
   stud per tile, white highlight + black shade in its alpha), `Color3 = white`, `StudsPerTileU/V = 1`,
   `Transparency = 0.45`. Target: stud luminance spread 5-10 on a lit patch (ref grass 7.6, ref_product_pads).
3. **Walls, pillars, props, boards, items: flat clean colour**, no studs, no texture.
4. **Cliffs / big outdoor blocks**: the same faint texture on every side (ref_product_pads clay cliffs).
5. Material: `SmoothPlastic` for everything built from Parts (flat, no 2022 Plastic grain); Neon only for glow
   strips/pad tops; Glass only for windows.

## 2. Palette (3-4 big warm saturated fields, then loud items)

Sampled lit faces (median of patch, sRGB):

| Field | Reference | Hex | H / S / V |
|---|---|---|---|
| Grass (the big field) | ref_W01 lit grass | #5ACB2E | 103 / 77 / 80 |
| Grass in shadow | ref_product_pads | #3AA52C | 113 / 73 / 65 |
| Grass caps on cliffs | ref_W01 | #7BD420 | 90 / 85 / 83 |
| Clay cliff faces | ref_W01 / ref_product_pads | #CC6A20 / #B67F1A | 26-39 / 84-86 / 71-80 |
| Walk / path (lavender grey) | ref_W01 centre, cross | #A29DC0 / #B0AED0 | 244-249 / 16-18 / 75-82 |
| Training floor (light) | ref_STILL_training_lanes | #CFD9EA | 218 / 12 / 92 |
| Sky | ref_W01 | #62BCCB-ish | 189 / 52 / 80 |
| Items/pads | yellow pad #FFFE02, red pad #FE2C45, pink-red #FF8D9A, purple egg #A552DF | | S 45-99, V 87-100 |

Rules:
6. The **big field is saturated** (S 75-85, V 75-83). In the warehouse (variant A) the field is light warm concrete
   (#D4CAB A-ish, S ~12) so the saturated big fields must come from the **walls (clay brick, H 20-26, S 70-80)** and the
   **sky through an open roof**; outdoors (variant B) the field is grass #60C834.
7. Walks stay the reference's lavender-grey (#BABCE0 Color3 renders ~#ADABCB, = ref #A29DC0-#B0AED0).
8. Shade colours **keep their saturation** and go ~25 % darker and slightly cooler (ref grass 155 -> 117 luminance,
   S 76 -> 73). Never grey shade.
9. Interactables are the loudest thing on screen: S 80-100, V 85-100 (pads, lane mats, prices). No neon anywhere
   else (rule 11 of B30 still holds).
10. Max ~5 hue families per view; walls/floor/sky are 3 of them.

## 3. Light (HoodLighting `HoodToy`, applied by the map)

11. **ShadowMap sun with real cast shadows.** HoodSun (Voxel, Ambient 172 carrying ~70 % of the light) is why the
    hall looks flat. HoodToy: `technology = ShadowMap` (LightingStyle Soft + PrioritizeLightingQuality true),
    ClockTime 10.5, GeographicLatitude 44 (sun ~60 deg up from the south-east: behind-right of a player walking north,
    shadows fall away to the left like ref_product_pads), Brightness 0.9, Ambient = OutdoorAmbient (140, 136, 142),
    ColorShift_Top (255, 232, 200), EnvironmentDiffuseScale 0.3 (blue sky fill in the shade),
    EnvironmentSpecularScale 0.2, ShadowSoftness 0.3. Grade: Saturation 0.6 (Studio shows ~0.4 of it), Contrast 0.12.
    Bloom 0.5 / 24 / threshold 1.1 (Neon only). Atmosphere Density 0.2, Haze 0.15, pale blue.
12. **Scripts cannot set `Lighting.Technology`** (HoodLighting.lua notes); LightingStyle/PrioritizeLightingQuality
    are set by Apply, and the place file written by `hood/tools/place/build_place.sh` carries Technology. In the
    user's own place: Lighting > Technology = ShadowMap (or Future) once in Properties.
13. **Let the sun in.** A 52-stud wall shadows ~30 studs of floor at this sun: in a warehouse open the roof
    (girders stay, they throw stripes) and keep interactables out of the wall-shadow band on the sun side.
14. Lit top faces vs darker sides is automatic with a real sun; do not fake it with two colours per block.

## 4. Models

15. **Map = Parts.** The reference's map is plain blocky Parts (paths, stairs, cliffs, pads): ref_W20.0, W01. We
    do not need Blender for the map. What makes them read well is rules 1-14, not the geometry.
16. **Items = rounded, bevelled, glossy toy meshes** (guns, eggs, pets, crowns): ref_product_pads RPG/hyperlaser,
    ref_W01 red phoenix. A Part stack shows seams and flat facets (work31_LOOK/shots/hero/hero_pair.jpg: same crown,
    Parts left, bevelled mesh right). Hero items should be MeshParts from Blender (pipeline in the LOOK report).
17. "Low poly" in these games = few, chunky, bevelled shapes with smooth-shaded edges and 1-3 colours per object, not
    many small Parts. Silhouette first; no outlines on 3D items.

## 5. Item effects (Studio's own: ParticleEmitter, Beam, PointLight; built-in textures, no upload)

Built-in textures (confirmed in the client tree, github.com/MaximumADHD/Roblox-Client-Tracker/tree/roblox/textures/particles):
`rbxasset://textures/particles/sparkles_main.dds` (white star, the default), `smoke_main.dds`, `fire_main.dds`,
`fire_sparks_main.dds`, `explosion01_shockwave_main.dds`, `explosion01_core_main.dds`, `explosion01_smoke_main.dds`,
`explosion01_implosion_main.dds`, `forcefield_glow_main.dds`, `forcefield_vortex_main.dds`, `SquareParticle.png`;
plus `rbxasset://textures/glow.png` (soft glow) and `rbxasset://textures/sparkle.png`.

18. **Every showcased item** (product pad, box pad, pedestal): spin 40 deg/s + bob 0.3 studs at ~0.4 Hz
    (Lobby.motion), a glowing pad top (Neon, colour lerped 30 % to white), a rising coloured haze
    (Lobby.padHaze: smoke_main, LightEmission 0.35, Rate 2.5, Transparency 0.62-0.78), an edge curtain
    (Lobby.padAura), small sparkles (Rate 3), and from B31: a **ground halo** (glow.png, VelocityPerpendicular,
    Size 1.2-1.5x pad, Transparency 0.55, Rate 0.8, Life 2.5, LightEmission 1) and **big star glints**
    (sparkles_main, Rate 1.4, Life 0.45-0.7, Size 0 -> 1.5 -> 0, Brightness 2, RotSpeed +-60, ZOffset 1).
    ref_product_pads (yellow/red pads with haze), ref_W01 (red item with white star glints).
19. One PointLight per pad (Range 11, Brightness 1.2, Shadows off); no Highlight outlines on items (ref: none).
20. Escalate by channel (skill roblox-vfx sec. 4), never by Rate. Daylight kills additive clouds: haze
    LightEmission <= 0.35.
21. Creator Store packs: the popular "aura" packs are the same primitives (ParticleEmitter/Beam/Attachment .rbxm,
    e.g. BuiltByBit "45+ RNG Aura VFX Pack"); none is a breakthrough over HoodVFX + built-ins. Not needed.

## 6. Composition and labels

22. Open space: keep >= 60 % of the floor in view free of props (ref_W01: path + grass, 3 interactables).
23. One label stack per thing, max 3 lines (price, name, benefit); stacks of neighbours at different heights
    (LabelStep) and never closer than ~6 studs on screen-overlapping axes (our "VIAuto Fight" overlap:
    p3_four.jpg top-left).
24. Eye level: interactables 0.5-4 studs tall (pads, lanes, items at 3-5 studs), titles high (14+), nothing
    clutters the 5-12 stud band between them.

## 7. The renderer (render13, work31_LOOK/r13)

25. render13 is calibrated on the user's Studio frames (ACES tone curve, Studs surface as the real client draws it,
    ambient/sun constants, bloom on Neon): trust its colours. It had one bias: every sun shadow was blurred as for
    voxel lighting (ShadowSoftness floor 0.35). B31 lets a ShadowMap/Future preset use its own ShadowSoftness
    (uncalibrated against Studio; check there). Particles are approximated (no lighting on particles).

## 8. Hero-item mesh pipeline (described, not built)

Verdict from `work31_LOOK/shots/hero/hero_pair.jpg` (same crown, same camera and light; left our Part kit with the
recipe, right a bevelled low-poly Blender mesh): the mesh reads as a toy (one continuous band, rounded rim, edge
highlights, faceted gems); the Parts read as a kit of panels with seams. Use meshes for showcased items only.
1. Model in Blender (bpy script per item, like `work31_LOOK/tools/hero.py`): <= 2k triangles, 2-3 segment bevels
   (0.1-0.2 studs), Weighted Normal modifier, 1-3 materials per item (body / accent / gem), item centred on the origin.
2. Export FBX: Forward Z, Up Y, Apply Scalings = FBX Unit Scale, Path Mode Copy + Embed Textures, no leaf bones
   (`hood/tools/blender/export_fbx.py` already does this for BoxKit models; one MeshPart per material).
   Files: `hood/art/models/fbx/<ItemId>.fbx` (+ `palette.png` when textured).
3. The user imports once: Studio > File > Import 3D, Scale Unit Stud, Set Pivot to Scene Origin, Anchored, then
   runs `hood/tools/blender/studio_apply_materials.lua`, names the model `<ItemId>` and drops it into a
   `ServerStorage.HoodItemMeshes` folder (like the user's own `HoodEnemies`).
4. Our code (Lobby.standItem and its twins): `ServerStorage.HoodItemMeshes:FindFirstChild(id)` -> clone, scale to the
   3.6-stud contract, `decor()` every part; else the Part build from LobbyModels (today's path). No asset ids in code.

## 9. What the golden slice measured (work31_LOOK/shots, HUD-free crop, median S / share S>0.6 / median V)

| View | B30 now | A warehouse | B open plaza | Reference |
|---|---|---|---|---|
| spawn | 0.41 / 39 % / 0.73 | 0.40 / 41 % / 0.75 | 0.62 / 53 % / 0.77 | 0.65 / 52 % / 0.80 (W01) |
| lanes | 0.56 / 44 % / 0.72 | 0.81 / 70 % / 0.77 | 0.71 / 69 % / 0.78 | 0.48 / 32 % / 0.90 (superhero) |
| product pads | 0.49 / 43 % / 0.76 | 0.48 / 45 % / 0.74 | 0.69 / 59 % / 0.75 | 0.74 / 69 % / 0.78 |
| box dais | 0.47 / 28 % / 0.76 | 0.33 / 39 % / 0.67 | 0.45 / 43 % / 0.67 | 0.56 / 48 % / 0.79 (W00) |

Reading: the stud/palette/light rules clean the picture in both variants, but the median saturation of the spawn and
pad views only reaches the reference when the big ground field is saturated (B's grass). Inside a warehouse the
lavender walks + light concrete keep A pale; the walls and lanes carry its colour. The south dais sits in the south
wall's shadow in A (V 0.67).
