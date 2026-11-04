---
tags: [build-playbooks, realistic, materials, pbr, materialvariant, surfaceappearance, decals, wear, graffiti]
updated: 2026-11-01
---

# 35 Realistic Materials, Decals and Wear

Back to [[33 Realistic World Building Playbook]] · [[00 Build Router]] · Deep reference: `LihFolk/LihFolk Vault V2/44 Materials and Surfaces/` (MaterialService and Custom Materials, SurfaceAppearance PBR Workflow, Tiling Trim Sheets and Decal Tricks, Stylised vs Realistic Material Pipelines, Baking Lighting and Detail into Textures)

> **TL;DR**
> - **Two tools, two jobs.** `MaterialVariant` = a tiling material for parts and terrain (roads, walls, sidewalks), picked by name. `SurfaceAppearance` = a UV-mapped PBR skin for one MeshPart (hydrant, car, AC unit, hero building).
> - **Real scale first:** set `StudsPerTile` from the texture's real size (1 stud = 0.28 m). Wrong tiling ruins realism more than low resolution.
> - **1024 maps for big tiling surfaces, 512 for props, 256 for small stuff.** 1024 costs 4× the memory of 512 (Roblox docs).
> - **The wear layer is what makes it real:** asphalt patches, cracks, oil stains, tyre marks, kerb paint, grime skirts, water streaks, graffiti. Each with a reason.
> - **Decals batch poorly.** Bake most wear into a few tile variants; use loose decals only for hero spots.
> - **OpenGL normal maps only.** DirectX normals make bumps look like dents.

---

## 1. Which tool for which surface

| Surface | Tool | Why |
|---|---|---|
| Road, sidewalk, plaza, parking lot | `MaterialVariant` on Parts | Tiles forever; one name, many parts; swap the look of the whole city by editing one variant |
| Building walls (plaster, brick, siding) | `MaterialVariant` on Parts or simple meshes | Same; facade detail from geometry and decals |
| Terrain ground (grass, dirt, sand, rock) | `MaterialVariant` with **Set as Override**, or `TerrainDetail` for top/side/bottom | Terrain uses base-material overrides |
| Hero props (hydrant, AC unit, phone booth, dumpster, car) | `SurfaceAppearance` on a MeshPart | UV-mapped, baked edge wear, unique look |
| Modular facade pieces from Blender | `SurfaceAppearance` with a **trim sheet** | One texture covers cornices, frames, ledges for a whole kit |
| Signs, graffiti, posters, markings | `Decal` on a host part, or baked into a trim/atlas | Pictures on surfaces |
| Glass | Built-in `Glass` material, or a SurfaceAppearance with `AlphaMode = Transparency` and `MeshPart.Transparency ≥ 0.02` for dirty glass | Glass refraction doesn't work on mobile (Roblox docs) |

**Facts that shape the choice (Roblox docs):**
- Only `MaterialVariant` carries physical properties (friction, footstep sound comes from the base material). Variants inherit physics from their base material, so pick the right base: asphalt on `Asphalt`, sidewalk on `Concrete`, siding on `WoodPlanks`.
- A part stores the variant's **name**. Renaming a variant breaks the parts that used the old name. Name once, carefully.
- SurfaceAppearance maps can't be changed by scripts at runtime; `Color` (a free multiply tint), `EmissiveStrength` and `EmissiveTint` can be.
- Identical meshes with the same SurfaceAppearance draw in one batch. Two copies of the same hydrant with different SurfaceAppearance assets cost two batches. Use **one texture + `SurfaceAppearance.Color` tint** for variety (free).

---

## 2. The city MaterialVariant library (build once, reuse in every realistic game)

Naming rule: PascalCase, base material first-ish, condition last (Roblox docs advise a consistent scheme). Keep them all in `MaterialService`, and export the set as one model `RealisticMaterials.rbxm` in `new-game-kit/assets/materials/` once made.

| Variant | Base material | StudsPerTile (start) | Pattern | Notes |
|---|---|---|---|---|
| `AsphaltClean` | Asphalt | 14–18 | Organic | Coastal roads; fine grain, light grey |
| `AsphaltWorn` | Asphalt | 14–18 | Organic | Hood roads; darker, faded, small cracks |
| `AsphaltPatchedA/B/C` | Asphalt | 28–40 | Regular | Tile variants with **baked** patches (§4.2) |
| `ConcreteSidewalkTile` | Concrete | 8–12 (one slab ~ 5 ft) | Regular | Joint lines every slab; slab size must match the curb module |
| `ConcreteStained` | Concrete | 20–30 | Organic | Big soft blotches for lots, walls, flood channels |
| `ConcreteBarrier` | Concrete | 10 | Regular | Jersey barriers and bridge decks |
| `CurbConcrete` | Concrete | 6 | Regular | Slight edge wear |
| `StuccoPaintedFaded` | Slate or Concrete | 12–16 | Organic | Hood walls; tint with part Color for pink/blue/mint |
| `BrickRed` | Brick | 6–8 | Regular | Fire station; ~1 brick ≈ 0.8 × 0.25 studs |
| `BrickPainted` | Brick | 6–8 | Regular | Painted-over brick with chips |
| `SidingPainted` | WoodPlanks | 6–8 | Regular | Coastal houses; tint per house |
| `RoofShingleGrey` | Slate | 8–10 | Regular | Pitched roofs |
| `RoofFlatGravel` | Pebble or Concrete | 12 | Organic | Flat roofs with AC units |
| `MetalShutterCorrugated` | CorrodedMetal or Metal | 4–6 | Regular | Roll-up doors |
| `MetalRusty` | CorrodedMetal | 8 | Organic | Hydrants, poles, fences |
| `ChainLink` | DiamondPlate or Metal (alpha) | 4 | Regular | Needs a part with alpha; or a mesh with SurfaceAppearance Transparency |
| `GrassLawn` / `GrassDry` | Grass | 12–16 | Organic | Verges and lots |
| `SandWet` / `SandDry` | Sand | 16 | Organic | Coast |
| `RockCoastal` | Rock | 12 | Organic | Breakwaters |
| `DirtPacked` | Ground | 14 | Organic | Alleys, empty lots |

**How to set `StudsPerTile` from a real texture:** most free PBR sets state their real-world size (for example "2 m × 2 m"). Studs = metres ÷ 0.28. A 2 m asphalt sample → ~7 studs; but road grain looks better a bit larger in-game, so we start at 14 (the "readable from a car" rule). Check by placing a 5-stud avatar next to it: bricks should be about knee-to-ankle height in rows of 3–4 per stud of height.

**Pattern:** `Organic` hides repetition on natural, noisy surfaces (asphalt, plaster, dirt). `Regular` keeps grids straight (tiles, bricks, siding, shingles).

**Where textures come from (licence-safe, write each source in `<game>/art/LICENSES.md`):**
- **Poly Haven** and **ambientCG**: free CC0 PBR sets (colour, normal GL, roughness, sometimes AO). Download 1K or 2K and export at 1024.
- **Roblox Material Generator** (in Studio's Material Manager): makes a variant from a text prompt. Fast for first passes; check tiling.
- **Our own photos** of real walls and roads (phone, overcast day, straight on), made tileable in an image editor.
- **Roblox Creator Store** materials only when the licence allows; never ripped textures from other games.

**Map recipe for a variant (from a CC0 set):**
1. ColorMap = diffuse multiplied by AO (layer blend Multiply, AO at 30–60%). Take out any baked strong shadows.
2. NormalMap = the **GL** normal (not DX). If only DX exists, invert the green channel.
3. RoughnessMap = roughness as is. Real asphalt and concrete are 0.8–0.95 rough; wet or polished areas lower.
4. MetalnessMap only for real bare metal (shutters, poles); skip for stone and paint.
5. Export PNG, square, 1024. Upload with Asset Manager bulk import; wait for moderation.

---

## 3. Hiding the tile (three scales)

A single tiled material repeats every few studs and players notice the grid from a car. Fix it at three scales:
1. **Small scale (inside the tile):** `Pattern = Organic` on noisy materials.
2. **Medium scale (5–30 studs):** a second, very large, low-contrast stain layer. Put a `Texture` (not Decal) on the same face with a soft blotch map, `StudsPerTileU/V` 40–80, Transparency 0.6–0.85. This is the "mottled concrete" look in hood-01 and hood-02.
3. **Large scale (whole street):** variation in **part Color** (± 5–10% brightness between road segments), and real-world events: patches, a resurfaced lane, a different sidewalk slab colour in front of a newer building.

Also: rotate repeated road tile parts by 180° at random, and never end a texture seam exactly on a lane line.

---

## 4. The wear layer (the most important pass)

### 4.1 Wear catalogue: what, where, why

| Wear | Where it goes (the reason) | How |
|---|---|---|
| **Utility patch** (rectangle, lighter ragged border) | Across lanes and at kerbs, over pipes and cables; in front of driveways | Baked in `AsphaltPatched*` tiles, or decal on host |
| **Pothole / crack network** | Lane edges, gutters, where water sits | Decal (alpha), plus a shallow mesh dip for hero potholes |
| **Crack seal lines** (dark tar squiggles) | Long cracks along lanes | Decal strips |
| **Oil stains** | Middle of parking bays, at stop lines, under parked cars | Decal, dark, soft, Transparency 0.3–0.5 |
| **Tyre marks** | Turns at intersections, driveways, skid near stop lines | Decal strips, low opacity |
| **Faded markings** | Lane lines and crosswalks on older streets | Marking texture with grunge alpha; new crisp ones on fresh roads |
| **Kerb paint** | Red no-parking near hydrants and corners; yellow at loading | Part colour or decal on the kerb top and face |
| **Grime skirt** | Bottom 1–3 studs of every wall (rain splash, dirt) | A gradient decal strip, dark at the bottom fading up |
| **Water streaks** | Under windowsills, AC drips, under roof edges and barrier tops | Vertical decal streaks |
| **Sun bleach** | Sunny side of signs and awnings | Lower saturation on that side |
| **Moss and damp** | Shaded north sides, bottoms of barriers, bridge piers near water | Green-dark decal, low on the wall |
| **Rust** | Bolts, hydrants, gutters, shutter bottoms, poles | In the SurfaceAppearance of the prop |
| **Chipped paint** | Door frames, window frames, kerb corners | Trim sheet edge wear |
| **Gum and litter spots** | Sidewalks near shops, bus stops | Tiny decals, very sparse |
| **Graffiti** | Reachable walls, shutters, canal walls, under bridges, train bridges | §5 |
| **Posters and stickers** | Poles, boarded windows, bus stops | Small decals, our own art |
| **Sand drifts** (coast) | Kerb gutters near the beach, car park corners | Thin decal or terrain sand bleeding onto asphalt |

**Density guide for the hood look:** at least one wear element per 10×10 studs of street, one big patch every 15–30 studs of lane, grime skirt on every wall, graffiti on about 1 in 3 ground-floor walls. Coastal look: about a third of that.

### 4.2 Bake most wear, decal the rest
Decals, Textures and particles batch poorly (Roblox docs). A city block with 400 loose decals costs real frame time on phones. So:
1. Make **3–5 road tile variants** (for example 40×20 studs) with patches, cracks and stains **baked into one texture** (a SurfaceAppearance on a flat MeshPart, or a big-tile MaterialVariant). Mix them along the street so no two neighbours match.
2. Same for sidewalk slabs: clean, cracked, stained, gum-spotted.
3. Use **loose decals only for unique story spots**: the tyre skid at one corner, the oil stain under the parked car, a graffiti piece.
4. Put loose decals on an **invisible host part** (Transparency 1, Anchored, CanCollide/CanTouch/CanQuery off, CastShadow off) lifted 0.02 studs above the surface to avoid z-fighting.

```lua
--!strict
-- Command Bar: drop a wear decal where you're looking. Select the target part first.
-- Usage: set IMAGE to an uploaded image asset id ("rbxassetid://...") and SIZE in studs.
local IMAGE = "rbxassetid://0" -- fill in; never invent IDs
local SIZE = Vector2.new(8, 6)
local Selection = game:GetService("Selection")
local target = Selection:Get()[1] :: BasePart
assert(target and target:IsA("BasePart"), "Select a road or wall part")
local cam = workspace.CurrentCamera
local hit = workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 500)
assert(hit, "Look at the surface")
local host = Instance.new("Part")
host.Name = "WearDecal"
host.Size = Vector3.new(SIZE.X, 0.05, SIZE.Y)
host.Transparency = 1
host.Anchored, host.CanCollide, host.CanTouch, host.CanQuery, host.CastShadow = true, false, false, false, false
local up = hit.Normal
local spin = math.rad(math.random(0, 359))
local right = up:Cross(Vector3.zAxis)
if right.Magnitude < 0.1 then right = up:Cross(Vector3.xAxis) end
-- fromMatrix(pos, X, Y): the part's Top face (its +Y) points along the surface normal
host.CFrame = CFrame.fromMatrix(hit.Position + up * 0.02, right.Unit, up) * CFrame.Angles(0, spin, 0)
local d = Instance.new("Decal")
d.Texture = IMAGE
d.Face = Enum.NormalId.Top
d.Parent = host
host.Parent = workspace:FindFirstChild("Decor") or workspace
Selection:Set({ host })
```
(Sketch, not yet run in Studio. If the orientation is off, rotate the host by hand; the important bits are the invisible host, the 0.02 lift and the physics flags.)

### 4.3 Making wear textures (our own, licence-clean)
- Start from CC0 grunge/crack/stain alphas (ambientCG has "decals" and "imperfections" sets) or paint our own.
- **Patch:** a dark asphalt rectangle with a lighter, rough sealant border (the hood-02 look). Keep corners slightly irregular, never perfect rectangles.
- **Stain:** soft radial blotch, darker centre, 256–512 px, no hard edges.
- **Grime skirt:** a 1×4 gradient (dark bottom, transparent top) with noise; stretch along walls.
- Keep alpha edges soft and noisy. Clean geometric edges look pasted on.

---

## 5. Graffiti that looks real (and stays kid-safe)

1. **Placement follows access:** ground-floor walls, shutters, canal and flood-channel walls, under bridges, backs of signs, rooftops reachable by ladder. Never three storeys up on a blank wall (a common DevForum critique: graffiti nobody could reach).
2. **Layering:** old faded tags under newer, brighter pieces; some buffed-out (grey paint rectangles painted over tags). This history is what reads as real.
3. **Scale:** tags 2–4 studs wide; throw-ups 6–10; big murals only on large blank walls and only a few per map.
4. **Texture interaction:** bake a grunge mask into the graffiti PNG so wall texture shows through the paint (a uniform Decal.Transparency looks like a sticker). Use `Decal.Color3` for colour variants of the same tag.
5. **Our own designs only.** Write our own made-up words and shapes. No real crews, no gang signs, no real brands, no rude words in any language. Kid-safe test: would a parent mind it on a school wall? If yes, cut it.
6. **Sources:** draw them, or generate with an image AI and then clean up by hand; keep the prompt and file in `<game>/art/graffiti/`.

---

## 6. SurfaceAppearance for hero props and modular kits

- **Texel density:** aim for a consistent ~64–128 px per stud on props players see close (hydrant, door, AC unit), 32–64 on building facades, less on far stuff. Same density everywhere = nothing looks blurrier than its neighbour.
- **Maps:** ColorMap (with little baked lighting, light AO allowed), NormalMap (OpenGL), RoughnessMap, MetalnessMap (0 or 1, rarely in between), optional EmissiveMask for lit signs.
- **AlphaMode:** `Overlay` (default; part Color shows through transparent areas), `Transparency` for leaves, fences, nets (set `MeshPart.Transparency = 0` for hard cutouts; ≥ 0.02 for soft see-through like dirty glass), `TintMask` to tint only masked areas (paint on a car body, not the rubber).
- **Colour variety for free:** grey-ish ColorMap + `SurfaceAppearance.Color` tint = 10 colours of the same car or awning at zero extra cost.
- **Trim sheets for facades:** one 1024 texture with horizontal strips (cornice, sill, frame, brick band, metal edge). Every facade module in the kit maps its UVs onto the strips, so a whole street uses one texture. See `LihFolk/.../Tiling Trim Sheets and Decal Tricks.md`.
- **Roughness is realism:** most "plastic" looks come from flat roughness. Vary it: dirt raises roughness, wear on metal edges lowers it, puddles make it near 0.

---

## 7. Material audit script (run before every showing)

```lua
--!strict
-- Command Bar: list street-level parts still on a plain built-in material (no variant, no SurfaceAppearance).
local found = 0
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") and d.Transparency < 1 and d.Material ~= Enum.Material.Neon and d.Material ~= Enum.Material.Glass then
		local hasSA = d:FindFirstChildOfClass("SurfaceAppearance") ~= nil
		if d.MaterialVariant == "" and not hasSA and d.Position.Y < 60 and d.Size.Magnitude > 6 then
			found += 1
			if found <= 50 then print("Plain material:", d:GetFullName(), d.Material.Name) end
		end
	end
end
print("Plain big parts at street level:", found)
```

## Sources
Roblox docs [SurfaceAppearance](https://create.roblox.com/docs/art/modeling/surface-appearance) (alpha modes, tinting is free, OpenGL normals, roughness/metalness guidance), [Materials](https://create.roblox.com/docs/parts/materials) (variants, overrides, naming, adaptive materials, terrain details, glass on mobile), [Improve performance](https://create.roblox.com/docs/performance-optimization/improve) (texture memory, decals batch poorly, trim sheets). DevForum [PBR materials tutorial](https://devforum.roblox.com/t/full-in-depth-tutorial-on-how-to-use-pbr-materials-to-create-realistic-objects-in-roblox/1574778) (AO into colour, 1K maps), [Hood style game map](https://devforum.roblox.com/t/hood-style-game-map/2938255) (critique: roads too clean, buildings too washed, graffiti placement). [CraftPBR Roblox guide](https://craftpbr.com/guides/roblox-texture) (1024 target, Overlay vs Transparency, DX normals invert relief).
