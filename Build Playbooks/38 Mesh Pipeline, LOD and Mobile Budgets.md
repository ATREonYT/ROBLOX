---
tags: [build-playbooks, realistic, blender, meshes, lod, streaming, performance, mobile, budgets]
updated: 2026-11-01
---

# 38 Mesh Pipeline, LOD and Mobile Budgets

Back to [[33 Realistic World Building Playbook]] · [[00 Build Router]] · Skill: `blender-roblox-models` · Deep reference: `LihFolk/LihFolk Vault V2/06 World Building and Art/` (Art Budgets - Triangles Draw Calls Memory, Level of Detail and Model Streaming, Modeling in Blender for Roblox, Collision and Physics Geometry), `12 Performance Testing and Debugging/` (Mobile and Low-End Optimization, MicroProfiler Guide, Client Zone Culling for Interiors and Cities) · Current engine facts: [[Brief - Worlds, Lighting and Performance]]

> **TL;DR**
> - **Draw calls and instance count kill realistic maps before triangles do.** Reuse a few meshes many times; never re-import a copy.
> - **Blender settings:** Unit System None, export FBX with "Apply Scalings: FBX Unit Scale", Z forward / Y up; or export glTF (no scale fix needed). Import with Scale Unit = Stud.
> - **20,000 triangles per mesh is the hard limit.** Props 200–2k, hero props 5–10k, buildings in pieces.
> - **LOD today:** `Model.LevelOfDetail = SLIM` on big static buildings, `StreamingEnabled` with the docs' baseline, `ModelStreamingMode = Atomic` per building. Don't rely on `RenderFidelity`.
> - **Budgets for a 30–50 player realistic RP map on mid phones (rules of thumb):** 300–600k visible triangles, 8–12 local lights on screen with 2–3 shadowed, textures mostly ≤ 512, client memory well under 1 GB on low phones.

---

## 1. Blender → Roblox (settings that work)

From the Roblox docs page on Blender:

**In Blender**
- Scene properties: **Unit System = None**, Rotation = Degrees. Then 1 Blender unit = 1 stud. Model at real scale in studs (a door 7.5 tall).
- Blender's up is Z, Studio's is Y. Exporter fixes it with **Forward = Z Forward, Up = Y Up**.
- **FBX:** tick "Limit to Selected Objects", set **Apply Scalings = FBX Unit Scale** (recommended; otherwise FBX imports huge). Leave other scale values at 1.0.
- **glTF/GLB:** no scale workaround needed. Good default for our pipeline.

**In Studio's 3D Importer**
- **Import Only as a Model** (groups pieces), **Upload to Roblox** on, Creator = Alex (or the group), **Insert Using Scene Position** on (keeps modular pieces aligned), **World Forward = Front, World Up = Top**, **Scale Unit = Stud**.

**Model-side rules (our pipeline):**
1. **Pivot at the snap point:** road pieces at road centre on the ground; facade modules at bottom-left-back; props at the base centre. Snapping on a 4-stud grid then just works.
2. **Apply transforms** (Ctrl+A → All Transforms) before export.
3. **One material slot per mesh** where possible; multi-material meshes split into several MeshParts on import.
4. **UVs:** tiling surfaces use UVs in real-world scale (so a MaterialVariant or trim lines up); unique props use a 0–1 atlas.
5. **Bevels:** a small bevel on every hard edge (0.05–0.15 studs) catches light and looks real. Cheap: 1–2 segments.
6. **Name meshes** like `Kit_Road_Straight40_Worn`, `Prop_Hydrant_A`. Names survive into Studio.
7. **Import each unique asset once**, then clone in Studio. Importing a whole map at once creates duplicate mesh IDs that don't batch (Roblox docs).
8. **AI meshes** (Studio's mesh generation, third-party AI) are fine for props if retopologised and re-textured to our density; see `.claude/skills/blender-roblox-models/` and [[04 AI Tools Landscape October 2026]].

### Modular kit workflow (the fastest way to a big believable city)
1. Block the street in Studio with grey parts (scale and play first).
2. Model a **kit**: 10–30 pieces per style (road pieces, kerbs, facade modules, roofs, props), all on the 4-stud grid.
3. **One trim sheet + 2–4 tiling materials per kit.** The whole hood block then uses maybe 6 textures.
4. Assemble buildings from modules in Studio. Vary with colour tints, signs, awnings, decals.
5. Turn the best assembled buildings into **Packages** so a fix updates every copy.

---

## 2. Triangle and texture budgets per asset

| Asset | Triangles | Texture | Notes |
|---|---|---|---|
| Small prop (cone, can, sign) | 50–500 | shared atlas, 256 | No shadow |
| Street prop (hydrant, bin, meter) | 300–1,500 | 512 or atlas | |
| Hero prop (car, ATM, vending machine) | 3k–10k | 512–1024 | Split into body + wheels + glass |
| Tree / palm | 1k–5k | 512 leaves + 512 bark, shared by species | Crossed cards, not modelled leaves |
| Bush | 300–1,200 | shared leaf atlas | |
| Facade module | 200–2k | trim sheet + tiling variants | |
| Whole building | 5k–20k in pieces | kit textures | SLIM on the model |
| Landmark (bridge, tower) | 6k–12k + LOD | 1024 | Persistent only if seen from everywhere |
| Road piece | 20–300 | tiling variant | |

Hard limit: **20,000 triangles per mesh** (Roblox modelling specs). Split anything bigger.

Textures: **512 for most, 256 for minor, 1024 only for big tiling surfaces and hero props.** A 1024 texture costs 4× the memory of 512 (Roblox docs). 4K textures render since Jan 2026, but phones pay for every pixel; don't.

---

## 3. LOD and streaming for a big city

**Workspace (Studio Properties only; scripts can't set these):**

| Property | Value | Why |
|---|---|---|
| `StreamingEnabled` | true | Big maps must stream |
| `StreamingMinRadius` | 64 (default) | Raise to 128 only if driving outruns streaming |
| `StreamingTargetRadius` | 1024 (default) | Lower to 512–768 if memory is tight |
| `ModelStreamingBehavior` | `Improved` | Models stream by their parts |
| `StreamOutBehavior` | `Opportunistic` | Frees memory as you move |
| `StreamingIntegrityMode` | `PauseOutsideLoadedArea` | No falling through unloaded roads |
| `PredictiveStreamingMode` | Enabled (opt-in) | Pre-streams likely areas such as respawn points |
| `EnableSLIMAvatars` | true | 50 avatars cost far less at distance |

**Per model:**
- Each building = one Model, `ModelStreamingMode = Atomic` (arrives whole, no half-houses).
- Big static buildings: `Model.LevelOfDetail = SLIM` (cloud-generated low-detail version for distance; the old `StreamingMesh` setting should be converted).
- Landmarks seen from everywhere: `Persistent`, but only 2–5 of them.
- Player houses with interiors: Atomic exterior; interior streamed or culled by the client when outside (`Client Zone Culling for Interiors and Cities.md`).

**Driving and streaming:** cars cover 60–100 studs per second, so they can outrun streaming. Fixes:
- `Player:RequestStreamAroundAsync(position)` ahead of fast travel and teleports.
- Keep road surfaces in a Persistent or near-persistent low-detail layer (one long simple part per road) so the ground is always there, and stream the detail.
- See `LihFolk/.../25 Physics and Vehicles/Vehicles and StreamingEnabled - Atomic Models and Streaming Ahead of the Driver.md`.

**Don't rely on `RenderFidelity`:** mesh streaming and cloud LoDs replace it and the engine ignores it when mesh streaming is on (vault brief). Keep triangles low at the source instead.

---

## 4. Collision, physics and shadows (the "decor pass")

- Anchor everything static.
- Decoration (foliage, small props, wear hosts, wires): `CanCollide`, `CanTouch`, `CanQuery` all false.
- Props that block: `CollisionFidelity = Box` (small) or `Hull` (medium); never `PreciseConvexDecomposition` on props.
- Buildings: one or a few invisible Box collider parts per building instead of collision on every facade mesh.
- `CastShadow = false` on small props, decals hosts, wires, ground cover, far buildings' details.
- The Command Bar decor pass in [[Brief - Worlds, Lighting and Performance]] recipe 5 does this in one click.

---

## 5. Phone budget for a realistic RP map (per view, rules of thumb)

| Budget | Low-end phone (target) | Mid phone | PC |
|---|---|---|---|
| Frame rate | 30+ fps at graphics quality 1 | 45–60 | 60 |
| Visible triangles | ≤ 300k | 300–600k | 1M+ |
| Draw calls | keep unique mesh+material combos in view low; reuse | | |
| Local lights on screen | 6–8, 1–2 shadowed | 8–12, 2–3 shadowed | more |
| Loose decals in view | ≤ 60 | ≤ 120 | |
| Particles alive | ≤ 300 | ≤ 1,000 | 2,500 |
| Client memory | well under 1 GB | 1–1.5 GB | |
| Instances per dressed block | 3k–10k | | |
| Ambient NPCs active near player | 6–10 | 12–20 | 30 |
| Moving AI cars near player | 4–8 | 8–15 | 20+ |

(From the vault's art budgets plus our NPC/traffic numbers. Roblox publishes no scene budget; measure on a real phone with a 15-minute soak.)

**How to measure:** Studio Device Emulator for framing, but numbers only from a real phone: Developer Console (F9) Memory tab, MicroProfiler (Ctrl+F6 on desktop, settings on mobile) for frame time, Stats (Shift+F5) for draw calls and triangles. Measure from the busiest views: downtown intersection at night, the strip mall lot, the bridge.

**First fixes when over budget (in order):**
1. Reduce unique meshes and materials in view (reuse, tint).
2. Cut loose decals; bake wear into tile variants.
3. Turn off shadows on small parts and most local lights.
4. Lower texture sizes (1024 → 512).
5. Lower foliage density in far layers; impostors in haze.
6. Lower NPC and traffic counts on Low graphics.
7. Lower `StreamingTargetRadius`.

---

## 6. Audit script (run before every showing)

```lua
--!strict
-- Command Bar: quick realistic-map audit. Counts that usually explain phone lag.
local meshIds: { [string]: number } = {}
local uniqueMeshes, parts, decals, lights, shadowLights, bigTex = 0, 0, 0, 0, 0, 0
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
		if d:IsA("MeshPart") then
			local id = d.MeshId
			if not meshIds[id] then meshIds[id] = 0; uniqueMeshes += 1 end
			meshIds[id] += 1
		end
	elseif d:IsA("Decal") or d:IsA("Texture") then
		decals += 1
	elseif d:IsA("Light") then
		lights += 1
		if d.Shadows then shadowLights += 1 end
	end
end
print(("Parts %d · unique meshes %d · decals/textures %d · lights %d (%d with shadows)"):format(parts, uniqueMeshes, decals, lights, shadowLights))
-- Same-named meshes with different MeshIds usually mean a prop was imported twice (Roblox docs tip).
local byName: { [string]: { [string]: boolean } } = {}
for _, d in workspace:GetDescendants() do
	if d:IsA("MeshPart") then
		byName[d.Name] = byName[d.Name] or {}
		byName[d.Name][d.MeshId] = true
	end
end
for name, ids in byName do
	local n = 0
	for _ in ids do n += 1 end
	if n > 1 then print("Imported more than once?", name, n, "mesh ids") end
end
```

## Sources
Roblox docs [Blender](https://create.roblox.com/docs/art/blender) (units, axes, FBX unit scale, glTF, importer settings), [Improve performance](https://create.roblox.com/docs/performance-optimization/improve) (instancing, import once, texture memory, collision fidelity, shadows below quality 4, SLIM), [Streaming](https://create.roblox.com/docs/workspace/streaming) (model streaming modes, recommended settings, predictive streaming, SLIM). Vault: `LihFolk/skills/lihfolk-worldbuilding/references/budgets.md`, `LihFolk/.../Art Budgets - Triangles Draw Calls Memory.md`, [[Brief - Worlds, Lighting and Performance]].
