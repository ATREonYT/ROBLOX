---
tags: [build-playbooks, realistic, terrain, water, foliage, trees, palms, wind, scatter]
updated: 2026-11-01
---

# 37 Terrain, Water and Foliage

Back to [[33 Realistic World Building Playbook]] · [[00 Build Router]] · Deep reference: `LihFolk/LihFolk Vault V2/06 World Building and Art/` (Terrain Deep Dive - Materials Water and Performance, Terrain Tools and Terrain API, Foliage Props and Scatter, Water Sky and Atmosphere Art), `44 Materials and Surfaces/Terrain Materials and Painting.md`

> **TL;DR**
> - **Terrain for land and water; parts and meshes for anything built.** Terrain hills, beaches, sea, lawns; meshes for roads, kerbs, buildings.
> - **Foliage at three heights everywhere:** ground cover (grass, tufts), shrubs (waist to head high), canopy (trees and palms). No bare ground in the coastal look.
> - **Leaves are crossed alpha cards** with `AlphaMode = Transparency`, `MeshPart.Transparency = 0`, and a few shared meshes tinted for variety.
> - **Wind makes it alive:** `Workspace.GlobalWind` moves terrain grass, clouds and opted-in particles; a WindShake-style client module sways leaf meshes.
> - **Shallow turquoise water** = higher transparency, lower reflectance, a teal-cyan colour, a light sand/rock bed, and props in the water.

---

## 1. Terrain in a realistic map

- **Use terrain for:** the land shape (hills behind the town in hood-02), beaches, riverbanks, the sea floor, big lawns, cliffs. It's cheap per area and blends materials smoothly.
- **Don't use terrain for:** roads, kerbs, sidewalks, building floors (straight edges look lumpy on 4-stud voxels). Brick and WoodPlanks terrain on slopes render as blocky cubes.
- **Paint by reason:** grass where it gets sun and water, dirt where people walk, rock on steep slopes, sand by water, mud where it's wet (see `Terrain Materials and Painting.md` for a slope/height paint script).
- **Override terrain materials with variants** (`MaterialService` overrides, or `TerrainDetail` for top/side/bottom), so terrain grass matches our lawn texture. Custom terrain materials are out of Early Access (Oct 2026, up to 62 per game).
- **3–5 terrain materials per view.** More looks noisy.
- **Hide straight paint edges:** no clean line longer than ~20 studs; break with scatter and decals.
- **Terrain grass decoration** (`Terrain.Decoration = true`, `GrassLength` 0.1–1): animated short grass on the Grass material that sways with `GlobalWind`. Great for lawns and verges. It's short; add tall grass meshes for wild areas.
- **Material colours** (`Terrain:SetMaterialColor`) are global per material. Grass green is one colour for the whole map, so use variants or a second material (`LeafyGrass`) for a different green.

---

## 2. Coast and land shape recipes

**Coastal town (coast-04, coast-05):**
1. Sea level at Y = 0 (terrain water fills below). Town ground at +4 to +8 studs.
2. Beach: sand slope of 1:6 to 1:10 from the water; wet sand band (darker) 4–8 studs wide at the waterline.
3. Breakwaters: rows of boulder meshes (one mesh, rotated and scaled 0.7–1.4×, half sunk), along the channel (coast-05).
4. Mangrove-ish edge: dense bushes right down to the rocks.
5. Islands and far shore: low terrain strips in the haze; the atmosphere blends them to grey-green.

**Hood edge (hood-02):** a concrete flood channel with sloped walls, chain-link fence and graffiti, a rail line or freeway berm behind, dry hills in the distance with power towers.

---

## 3. Water

Terrain water properties (Roblox Terrain API): `WaterColor` (default dark teal), `WaterTransparency` (0–1, default 0.3), `WaterReflectance` (0–1, default 1), `WaterWaveSize` (0–1 studs), `WaterWaveSpeed` (0–100 per minute).

| Look | WaterColor | Transparency | Reflectance | WaveSize | WaveSpeed |
|---|---|---|---|---|---|
| Shallow tropical lagoon (coast-05) | (40, 150, 150) to (60, 170, 160) | 0.75–0.85 | 0.3–0.5 | 0.05–0.1 | 8–12 |
| Harbour / marina | (35, 95, 95) | 0.5–0.6 | 0.6 | 0.1 | 10 |
| Open sea | (20, 70, 90) | 0.3–0.4 | 0.8–1 | 0.15–0.3 | 12–20 |
| Canal / river in a city | (45, 60, 50) | 0.3 | 0.7 | 0.03 | 6 |

(Starting points, tune under the chosen lighting preset; not yet checked in Studio.)

What sells water more than any setting:
- **A visible bed:** light sand under shallow water, darker rock and weed deeper. The colour gradient from turquoise to deep blue comes from the bed depth.
- **Props in and on it:** channel markers (red and green posts), buoys, a pier on piles, moored boats, a half-sunk wreck (coast-05), rocks breaking the surface, a jetty.
- **Shoreline foam:** a thin white beam or animated decal strip at the waterline, or particles where waves meet rocks (keep counts tiny).
- **Reflections of the sky:** reflectance pulls in the skybox, so a good sky matters.
- **Sound:** soft lapping near shore, gulls, a far boat engine (see [[39 Living World - Traffic, NPCs and Ambience]]).
- Water reflections and depth work better when see-through foliage uses `MeshPart.Transparency = 0` with alpha cutouts (Roblox docs on AlphaMode).

---

## 4. Trees, palms and bushes

### 4.1 How realistic Roblox foliage is built
- **Trunk and branches:** a low-poly mesh (6–8 sided trunk) with a bark SurfaceAppearance (512).
- **Leaves:** clusters of **alpha cards** (planes with a leaf-cluster texture), crossed at 2–3 angles so they look full from every side. SurfaceAppearance with `AlphaMode = Transparency`, `MeshPart.Transparency = 0` (hard cutout, sorts correctly). Turn on double-sided on the mesh where it's offered at import.
- **Palms:** a curved trunk (bent along a curve in Blender, ring texture), 8–14 fronds (each a bent card with a frond texture), a few coconuts. Lean 3–15° away from the wind and give each a slight S-curve. Palms in Alex's references are **tall and thin** (30–50 studs) and lean in different directions.
- **Bushes:** 3–6 crossed leaf-card clusters in a dome, sunk 10–20% into the ground. Dark green, slightly blue in the shade. These carry the coastal look.
- **Ground cover:** grass tufts, ferns, weeds in cracks (hood), small flowers. Tiny cards; never cast shadows.

### 4.2 Variety without cost
- Make **3–4 tree meshes, 2–3 palm meshes, 3 bush meshes**. Clone them; never re-import a copy (each import is a new asset and a new draw batch).
- Vary by **rotation (random 0–360°), scale (0.8–1.25×), lean (0–8°) and tint** (`SurfaceAppearance.Color` ± a little green/yellow). One mesh looks like a forest.
- Mix species in loose groups of 3–7, not rows (except deliberate palm rows on medians and seafronts).

### 4.3 Density by layer (coastal look)

| Layer | Height | Density | Shadows |
|---|---|---|---|
| Ground cover | 0.5–2 | Continuous carpet on every unpaved area near the player | Off |
| Shrubs | 3–8 | 1 per 25–60 sq studs on unpaved areas | Off on small, on for big |
| Mid trees | 15–25 | Clusters every 30–60 studs | On |
| Palms | 30–50 | Loose rows and clusters; skyline every 20–40 studs | On (cheap thin trunk shadows look great on roads, coast-03) |

Hood look: a third of that; weeds in cracks, a few street trees in tree pits, palms over rooftops, dry grass in lots.

### 4.4 Placing foliage (a scatter brush)

Use a scatter plugin (Brushtool-style or ScatterForge from Godberry; check licence) or this Command Bar scatter that raycasts down onto terrain and grass only:

```lua
--!strict
-- Command Bar: scatter clones of a template model in a circle, only on Grass/LeafyGrass terrain.
-- Put templates in ServerStorage.Foliage (e.g. "BushA", "BushB", "Palm1"). Sketch, not yet run in Studio.
local TEMPLATES = { "BushA", "BushB", "BushC" }
local CENTER = workspace.CurrentCamera.Focus.Position
local RADIUS, COUNT, SEED = 60, 80, 7
local OK = { [Enum.Material.Grass] = true, [Enum.Material.LeafyGrass] = true, [Enum.Material.Ground] = true }

local rng = Random.new(SEED) -- seeded so re-runs are repeatable
local src = game:GetService("ServerStorage"):WaitForChild("Foliage")
local out = workspace:FindFirstChild("Decor") or Instance.new("Folder")
out.Name = "Decor"; out.Parent = workspace
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { workspace.Terrain }
local placed = 0
for _ = 1, COUNT * 3 do
	if placed >= COUNT then break end
	local a, r = rng:NextNumber(0, math.pi * 2), RADIUS * math.sqrt(rng:NextNumber())
	local origin = CENTER + Vector3.new(math.cos(a) * r, 200, math.sin(a) * r)
	local hit = workspace:Raycast(origin, Vector3.new(0, -400, 0), params)
	if hit and OK[hit.Material] and hit.Normal.Y > 0.8 then
		local t = src:FindFirstChild(TEMPLATES[rng:NextInteger(1, #TEMPLATES)]) :: Model
		local m = t:Clone()
		local s = rng:NextNumber(0.8, 1.25)
		m:ScaleTo(s)
		local sink = m:GetExtentsSize().Y * 0.12
		m:PivotTo(CFrame.new(hit.Position - Vector3.new(0, sink, 0))
			* CFrame.Angles(math.rad(rng:NextNumber(-4, 4)), rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-4, 4))))
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
				if p.Size.Magnitude < 6 then p.CastShadow = false end
			end
		end
		m.Parent = out
		placed += 1
	end
end
print("Placed", placed, "foliage models")
```

Keep a **46-stud clear zone** around job stations and doors, and never put a bush on a road or path (raycast filter to terrain only does this).

### 4.5 Wind (plants must move)
- **`Workspace.GlobalWind`** (Vector3) moves terrain grass, dynamic clouds, and particles with `WindAffectsDrag = true` and `Drag > 0`. Fire and Smoke follow it by default. Roblox's sample gusts between (5, 0, 2) and (25, 0, 10) on a sine ramp; a gentle coastal breeze is about (8, 0, 4).
- **Leaf meshes don't follow GlobalWind on their own.** Use a client sway module like the open-source **WindShake** (boatbomber): tag leaf parts `WindShake`, call `Init({ MatchWorkspaceWind = true })`. It moves parts with `BulkMoveTo` and culls by distance (default render distance 150 studs). Tag only the leaf cards and fronds, never trunks or collidable parts.
- On the Low graphics setting, drop the sway render distance to ~50 studs (see [[34 Realistic Lighting and Atmosphere]] §6). Players with Reduce Motion on get slower grass by default.

---

## 5. Foliage performance rules
- Anchored, no collision, no touch, no query on all foliage (players walk through bushes; trees get one invisible trunk collider).
- `CastShadow = false` on ground cover and small shrubs.
- Overlapping transparent cards are the main GPU cost on phones (overdraw). Fewer, larger, more opaque cards beat many sparse ones.
- Group foliage per block into Models with `ModelStreamingMode = Atomic` so whole clumps stream in together.
- Far hills use **cheap tree impostors**: a single crossed-card tree or terrain colour, hidden by haze.

## Sources
Roblox docs [Terrain API](https://create.roblox.com/docs/reference/engine/classes/Terrain) (water properties and ranges, Decoration, GrassLength), [Global wind](https://create.roblox.com/docs/environment/global-wind), [SurfaceAppearance](https://create.roblox.com/docs/art/modeling/surface-appearance) (Transparency mode and MeshPart.Transparency 0 vs ≥ 0.02), [Materials](https://create.roblox.com/docs/parts/materials) (terrain overrides and details). DevForum [Wind Shake](https://devforum.roblox.com/t/wind-shake-high-performance-wind-effect-for-leaves-and-foliage/1039806), [Realistic alpha leaves](https://devforum.roblox.com/t/how-to-make-realistic-looking-alpha-leaves-for-realistic-building/684354). Vault budgets: `LihFolk/skills/lihfolk-worldbuilding/references/budgets.md`.
