---
tags: [sector-brief, world-building, level-design, materials, lighting, performance, streaming, mobile]
updated: 2026-10-30
---
# Brief - Worlds, Lighting and Performance
Back to [[00 Build Router]] · All briefs: [[Sector Briefs Index]]

> TL;DR
> - **Lighting is `LightingStyle` + `PrioritizeLightingQuality` now.** `Lighting.Technology` is deprecated and scripts can't set it. For our cartoony games use `Soft` + `true`. That is the old "ShadowMap" look. Ignore any video that says "set Technology to Future".
> - **Pick one lighting preset and tune it on a phone.** Use one `Atmosphere` (Density 0.3 to 0.4), no fog on top, and only Sky, ColorCorrection, Atmosphere and Bloom as post effects. Phones turn shadows off below quality level 4, so the map must read without them.
> - **Build from parts that repeat.** Identical meshes with identical appearance share one draw call, so import a prop once and clone it in Studio. Use SmoothPlastic and a small palette.
> - **Decoration gets no physics.** Anchor everything static. Turn off `CanCollide`, `CanTouch` and `CanQuery` on decoration. Use `CollisionFidelity = Box` on small meshes and `CastShadow = false` on small or far details.
> - **Leave StreamingEnabled on with the docs' baseline settings:** MinRadius 64, TargetRadius 1024, `Improved`, `Opportunistic`, `PauseOutsideLoadedArea`. Call `RequestStreamAroundAsync` before every server teleport. Client code uses `WaitForChild` and nil checks.
> - **Don't rely on `RenderFidelity`.** Mesh streaming and cloud LoDs replace it, and the engine ignores it when mesh streaming is on. Keep triangles low in Blender instead. Use `Model.LevelOfDetail = SLIM` on large static buildings.
> - **Coming late 2026, not live yet:** rounded parts and cone, capsule and disc primitives, a 500-stud minimum draw distance on low-end Android (200 today) and better automatic collision. Don't build on them until they ship. Check `Enum.PartType` first.
> - **Hub layout:** spawn at the edge, money stations near spawn, paths at least 10 studs wide, and no empty patch bigger than about 30x30 studs.

## Current state (Oct 2026): what's new, renamed or deprecated

| Change | Status | What it means for us | Source |
|---|---|---|---|
| `Lighting.Technology` deprecated. Replaced by `LightingStyle` (`Soft`, `Realistic`) + `PrioritizeLightingQuality` (bool) | Live | Set the two new properties. Old mapping: Voxel = Soft + false, ShadowMap = Soft + true, Future = Realistic + true. `Compatibility`, `Legacy` and `Unified` can no longer be picked. | Roblox docs (Lighting API, LightingStyle enum); rbx-dom issue #637 (mapping) |
| `Lighting.Outlines` and `Lighting.ShadowColor` deprecated | Live | Remove them from any old template. | Roblox docs (Lighting API) |
| `ColorGradingEffect` with `TonemapperPreset` `Default` / `Retro` | Live | `Retro` imitates the pre-2019 Roblox look with muted colours and softer contrast. Only the most recently parented one under Lighting applies. Most of our games leave it out or use `Default`. | Roblox docs |
| Local light `Range` limit raised from 60 to 120 studs (PointLight, SpotLight, SurfaceLight) | Live since Sep 23, 2025 | One 120-range light can replace several small ones, but each one costs more. Scripts that set a range above 120 are clamped to 120. | DevForum (Sep 23, 2025) |
| Mesh streaming and cloud LoDs (`Workspace.MeshStreamingAndImprovedLods`). `RenderFidelity` is ignored when it is on and is planned for removal | Opt-in Apr 2026. The default-on phase was planned for about July 2026 and is **unverified** | Delete code that sets `RenderFidelity`. Keep triangles low at the source. | Vault note [[Engine and API Changes 2025-2026]] (DevForum Apr 27, 2026). Property spelling from the docs' Workspace API page |
| 4096 x 4096 textures render in live games (MeshPart, SurfaceAppearance, Texture, Decal, MaterialVariant) | Live since Jan 30, 2026 | Allowed, but a phone pays for every pixel. Keep cartoony textures at 512 or below. | Vault note [[Engine and API Changes 2025-2026]] |
| SLIM (`Model.LevelOfDetail = SLIM`, `Workspace.EnableSLIMAvatars`) | Live; falls back to `Disabled` where it isn't supported | Cloud-merged LoDs for static buildings. `StreamingMesh` is the old setting, so convert it to SLIM. | Roblox docs (SLIM) |
| `MeshPart.MeshContent` / `TextureContent` (Content type) next to `MeshId` / `TextureID` | Live | Instancing docs now talk in terms of MeshContent and TextureContent. The old IDs still work. | Roblox docs (MeshPart API, Improve performance) |
| Frustum streaming (`Player.FrustumStreaming`) prioritises what the camera sees | Announced Sep 2026; status **not re-checked** | Optional. Test teleports and fast camera turns before you turn it on. | Vault note [[Engine and API Changes 2025-2026]] |
| Custom terrain materials out of Early Access, up to 62 per game | Oct 2026 | Possible, but our cartoony maps mostly use parts and meshes, not terrain. | Vault note [[Engine and API Changes 2025-2026]] |
| **RDC 2026, late 2026:** new BasePart primitives and "rounding support for all applicable base part shapes" | Announced, **not live**. `Enum.PartType` today is still Ball, Block, Cylinder, Wedge, CornerWedge | Rounded parts will suit the soft cartoony style without meshes. Until they ship, use meshes from Blender. | DevForum RDC26 post; Roblox docs (PartType) |
| **RDC 2026, late 2026:** minimum draw distance of 500 studs on low-end Android at quality level 1 (today 200) | Announced, **not live** | Today a low-end phone sees about 200 studs. Gates and landmarks must work inside that range. | DevForum RDC26 post |
| **RDC 2026, late 2026:** a new algorithm that auto-generates better collision geometry, with a debug overlay | Announced | Keep using Box/Hull plus invisible blocker parts for now. | DevForum RDC26 post |
| **RDC 2026, mid 2027:** PBR material layering with masks, better specular controls, and terrain scattering, splines and projected decals | Roadmap | Nothing to do yet. | DevForum RDC26 post |
| Studio: Device Simulator out of beta, a network simulator, and SLIM debug tints (Studio beta) | Live / beta | Check phone framing and slow-network joins before showing the owner. | Vault note [[03 What's New on Roblox - RDC 2026 and October]] |

## The recipes

### 1. Hub map for a simulator / +1 / steal game (golden slice first)
1. **Set the lighting first** (recipe 3). Default lighting makes every colour decision wrong.
2. Make the ground: one grass base of about 250 x 250 studs for a hub (Vault note [[How to Build PRO Roblox Maps!]]).
3. Put the spawn at an edge or corner, never at the centre. Add one wide main path plus a loop path. Paths are at least 10 studs wide and curve at one fixed angle.
4. Build a raised platform for each station: eggs, shop, rebirth, leaderboard, VIP. The shop and eggs go **on the way out of spawn** (Vault note [[Lobby and Hub Design]]). The first station should take under 15 s to reach.
5. Build a border wall from about 5 parts, duplicated around the edge. Then add big filler, then small filler, then colour accents.
6. Gate the zones in a line (zone 1, 2, 3 reuse the same code). Show the next zone's price across a gap.
7. Run the screenshot test from spawn: the main action, shop, leaderboard and first gate must be visible within about 200 studs (the low-end draw distance today).

### 2. Parts vs meshes vs unions
- **Parts** for blockout and for large flat shapes (ground, platforms, walls). Identical sizes and colours batch well.
- **MeshParts from Blender** for repeated props (trees, rocks, eggs, pets). Import each prop **once** and duplicate it in Studio. The importer does not de-duplicate meshes. Two uploads of the same tree are two assets, two draw-call groups and twice the memory (Roblox docs).
- **Unions** only for one-off shapes. Never use them for repeated props. Duplicate a finished union instead of rebuilding it (Vault note [[Parts Unions and MeshParts]]).
- Instancing rule (Roblox docs): meshes with the same MeshContent share a draw call only if their look matches. That means the same SurfaceAppearance, or the same TextureContent when there's no SurfaceAppearance.
- Overlapping coplanar faces flicker (z-fighting). Offset or trim them.

### 3. Cartoony lighting (Studio command bar, or a one-time edit-time script)
`LightingStyle` and `PrioritizeLightingQuality` can be set from scripts according to the API reference. One docs page says LightingStyle is Properties-window only, so **check in a published game that it stuck**. With Rojo, list all lighting properties explicitly in the project file, because rbx-dom can mis-serialize Technology (rbx-dom issue #637).

```lua
--!strict
-- Run once in Studio's Command Bar, then save. Values: preset A from the
-- roblox-cartoony-building skill (Gamer M8 video). Tune by eye on a phone.
local Lighting = game:GetService("Lighting")
Lighting.LightingStyle = Enum.LightingStyle.Soft
Lighting.PrioritizeLightingQuality = true      -- shadow-mapped sun (old "ShadowMap")
Lighting.GlobalShadows = true
Lighting.Brightness = 2
Lighting.Ambient = Color3.fromRGB(200, 160, 225)
Lighting.OutdoorAmbient = Color3.fromRGB(125, 100, 150)
Lighting.ColorShift_Top = Color3.fromRGB(215, 190, 135)
Lighting.EnvironmentDiffuseScale = 0.3
Lighting.EnvironmentSpecularScale = 0.25
Lighting.ShadowSoftness = 0.2
Lighting.ClockTime = 14
Lighting.GeographicLatitude = 40
Lighting.ExposureCompensation = 0

local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atmo.Density = 0.35      -- default is far too foggy for a kid hub
atmo.Offset = 0
atmo.Parent = Lighting

local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
cc.Brightness = 0.05
cc.Contrast = 0.1
cc.Saturation = 0.15
cc.Parent = Lighting
```
- Set Bloom last, with a threshold of about 0.9 to 1.0 so only neon glows.
- Give each zone one ambient hue (orange for an earthy zone, blue for an ice zone). Change zone moods on the **client**, because the server's `Lighting` replicates to everyone.
- Pulsing neon or flashing light: at most 1 flash per second (repo kid-safe rule).
- Use `Realistic` only when indoor local-light shadows matter and the phone test passes.

### 4. Materials (cartoony first)
- Default is SmoothPlastic with flat bright colours. Saturate what players touch (75 to 100 %) and soften what they stand on (20 to 55 %) (Vault note [[13 Cartoony & Low-Poly Building]]).
- **MaterialVariant**: a tiling custom material in `MaterialService`. Parts pick it by name (`BasePart.MaterialVariant`). The texture maps cannot be set by game scripts. Make variants in Material Manager and switch them by name at runtime. A base-material override (`MaterialService:SetBaseMaterialOverride`) changes **every** part and terrain of that material in the place (Roblox docs, via Vault note [[Materials MaterialVariants and SurfaceAppearance]]).
- **SurfaceAppearance**: UV-mapped PBR on a MeshPart. Scripts can change `Color` (a multiplying tint that costs nothing), `EmissiveStrength`, `EmissiveTint` and `AlphaMode` at runtime, but not the maps. Use one greyscale map tinted many ways rather than many textures. For leaf cards, use `AlphaMode = Transparency` and `DoubleSided` on (Vault note).
- A `TextureID` on a MeshPart overrides `Material` changes (measured, Vault note). Very dark colours hide material textures, so keep albedo above about 0.085 luminance.

### 5. Collision and physics pass for decoration (Studio command bar)
```lua
--!strict
-- Select a "Decor" folder, then run. Static decoration: no physics, no shadows on small bits.
local root = workspace:FindFirstChild("Decor")
assert(root, "Make a Workspace.Decor folder first")
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		d.Anchored = true
		d.CanCollide = false
		d.CanTouch = false
		d.CanQuery = false
		if d.Size.Magnitude < 4 then d.CastShadow = false end -- rule of thumb size
		if d:IsA("MeshPart") then d.CollisionFidelity = Enum.CollisionFidelity.Box end
	end
end
```
- `CollisionFidelity` is plugin-level, so set it in Studio, not at runtime.
- Walkable meshes use `Hull`, or `Box` plus invisible blocker parts. Never use `PreciseConvexDecomposition` on props, because Precise is the most expensive (Roblox docs).

### 6. Streaming settings (Studio Properties only)
Set these on `Workspace`. Streaming properties cannot be set from a script (Roblox docs). The Studio MCP's "AI streaming skill", or `ApplyRecommendedStreamingSettings` (plugin), applies the same baseline.

| Property | Value |
|---|---|
| `StreamingEnabled` | true (default for new places) |
| `StreamingMinRadius` | 64 (default; keep it) |
| `StreamingTargetRadius` | 1024 (default; keep it) |
| `ModelStreamingBehavior` | `Improved` |
| `StreamOutBehavior` | `Opportunistic` |
| `StreamingIntegrityMode` | `PauseOutsideLoadedArea` |
| `Model.ModelStreamingMode` | `Atomic` for each building/station. `Persistent` only for a tiny set of essentials |

```lua
--!strict
-- Server: stream the destination before every teleport (zones, rebirth, respawn).
local function moveTo(player: Player, target: CFrame)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end
	local ok = pcall(function()
		player:RequestStreamAroundAsync(target.Position, 10) -- timeout seconds
	end)
	if not ok then warn("stream ahead failed; teleporting anyway") end
	char:PivotTo(target)
end
```
```lua
--!strict
-- Client: never assume a far part exists. Wait, and handle it leaving.
local zone = workspace:WaitForChild("Zones"):WaitForChild("Zone2", 10)
if zone then
	-- connect visuals here; also listen for zone.AncestryChanged / Destroying
end
```
- Keep each model under about 64 studs across, and break up huge container models (Roblox docs, Streaming techniques).
- Client-made instances don't stream out unless they are parented under a server-made instance.

### 7. LOD for big static things
- Set `Model.LevelOfDetail = SLIM` in Studio on static buildings and prop clusters. It needs streaming on, the place saved to Roblox (not a local .rbxl) and Team Create on. After the first publish, wait 1 to 2 minutes, then rejoin. It does not work on models changed at runtime, animated models, or models with a Humanoid (Roblox docs, SLIM).
- Our `places/<Game>.rbxl` local test file will **not** show SLIM results. Judge SLIM only in a published test place.

## Numbers and limits

| Item | Value | Source |
|---|---|---|
| Local light range max | 120 studs (was 60) | DevForum (Sep 23, 2025) |
| Shadows on phones | Engine disables shadows entirely below quality level 4 | Roblox docs (Improve performance) |
| Low-end Android draw distance | 200 studs today; 500 announced for late 2026 | DevForum RDC26 post (Sep 2026) |
| Texture memory | 1024x1024 = 4x the memory of 512x512. Compression and removing alpha don't help | Roblox docs (Improve performance) |
| Texture size target | Usually at most 512; minor images under 256 | Roblox docs (Improve performance) |
| Max rendered texture | 4096 x 4096 (live games) | Vault note [[Engine and API Changes 2025-2026]] (DevForum Jan 30, 2026) |
| StreamingMinRadius / TargetRadius | 64 / 1024 (defaults and recommended) | Roblox docs (Instance streaming) |
| StreamOutBehavior default | `LowMemory`; recommended `Opportunistic` | Roblox docs |
| ModelStreamingBehavior default | `Legacy`; recommended `Improved` | Roblox docs |
| Model size for clean streaming | Keep a model's extent under about 64 studs | Roblox docs (Streaming techniques), via vault research note |
| Physics stepping | Adaptive 60/120/240 Hz; Fixed forces 240 Hz on everything | Roblox docs |
| SLIM avatars example | about 170k vs 2.6M triangles; about 4k vs 60k client instances | Roblox docs (SLIM) |
| Custom terrain materials | Up to 62 per game | Vault note [[Engine and API Changes 2025-2026]] (DevForum Oct 2026) |
| Mesh triangles | No single mesh over 20,000 triangles; pets about 3k, characters about 6k | Vault notes [[Parts Unions and MeshParts]], [[13 Cartoony & Low-Poly Building]] |
| Scene budget example | Under about 1,000 draw calls and 1,000,000 triangles on the target device | Vault research note `research_notes/Cartoony Roblox building UI and animation/lighting_and_build_tech.md` (quoting Roblox docs); measure your own |
| Hub ground | About 250 x 250 studs; paths 10+ studs; no empty patch over about 30 x 30 | Vault note [[How to Build PRO Roblox Maps!]] / skill (rule of thumb) |
| Atmosphere Density | 0.3 to 0.4 for a cartoony hub | Rule of thumb (skill `roblox-cartoony-building`) |
| Hub time budget | First station under 15 s; exit under 20 s | Vault note [[Lobby and Hub Design]] (rule of thumb) |

## Pitfalls
- **"Set Technology to Future/ShadowMap."** Old videos and most AI answers say this. `Technology` is deprecated and not scriptable. Use `LightingStyle` + `PrioritizeLightingQuality`.
- **Judging the look in Studio on a Mac.** A phone at low quality has no shadows (below level 4) and a short view. Check every look on a phone or the Device Simulator at low quality.
- **Atmosphere plus Fog.** When an `Atmosphere` exists, the fog properties do nothing. Use one or the other.
- **Setting zone lighting on the server.** The change replicates to every player. Change zone moods on the client.
- **Using `RenderFidelity = Performance` as "LOD".** It is ignored under mesh streaming and on the way out.
- **Importing a whole map from Blender in one go.** It creates duplicate assets and breaks instancing. Import props one by one and clone them.
- **Unions for repeated props, and Precise collision on decoration.** Both waste memory and physics time.
- **Assuming a far part exists on the client.** With streaming, `workspace.Zone5.Door` errors. Use `WaitForChild` with a timeout and handle stream-out.
- **Teleporting without streaming ahead.** The player falls through an unloaded floor. Call `RequestStreamAroundAsync` first.
- **Making everything `Persistent`.** It never streams out and fills phone memory.
- **Testing SLIM in a local .rbxl.** It only works in a published place with Team Create on.
- **Using announced features as if live.** Rounded parts, the new primitives, the 500-stud draw distance and the new collision algorithm are "late 2026". Check the API before you use them.
- **Too many transparent layers and particles.** Overlapping partial transparency is drawn several times (overdraw). Decals, textures and particles don't batch.
- **Inventing asset IDs** for skies, textures or meshes. Leave them at 0 with a note for the owner (repo rule).

## Checklist before shipping
- [ ] `LightingStyle` and `PrioritizeLightingQuality` set on purpose and confirmed in the **published** game. No script touches `Technology`.
- [ ] One Atmosphere and no fog. Post effects limited to Sky, ColorCorrection, Atmosphere and Bloom. No light flashes faster than 1 per second.
- [ ] The map reads with shadows off (phone at low quality). Key landmarks are visible within 200 studs of where players stand.
- [ ] All static parts anchored. Decoration has CanCollide, CanTouch and CanQuery off, Box fidelity, and no shadows on small bits.
- [ ] Repeated props are clones of one asset. No unions on repeated props. No meshes set to Precise collision.
- [ ] Textures at 512 or below unless it's a hero asset. Tints used instead of extra textures.
- [ ] Streaming on with the baseline settings. Buildings set to Atomic. Every server teleport streams ahead. Client code survives stream-out.
- [ ] SLIM set on large static buildings and checked in a published test place.
- [ ] No overlapping parts flicker. No props float or fall.
- [ ] A 15-minute soak test on a real low-end phone, with FPS and memory written down (Developer Console, F9).
- [ ] Ran `AI Video Library/16 Cartoony Kid-Appeal Checklist.md` (Building, Color, Lighting, Performance).

## Go deeper
- Hub and level layout: [[Lobby and Hub Design]], [[Level Design Principles - Flow Sightlines and Landmarks]], [[Spawn Points Safe Zones and Respawn Flow]], [[Kill Planes, Map Boundaries and Out-of-Bounds Recovery]], [[Zone and Biome Art Direction]], [[World Composition and Set Dressing - Designed, Not Scattered]]
- Our cartoony videos: [[13 Cartoony & Low-Poly Building]], [[How to Build PRO Roblox Maps!]], [[How to make CARTOON LIGHTING in Roblox Studio]], [[How to Light a Low Poly Map (Roblox Studio)]], [[Cartoony Roblox building UI and animation]], [[16 Cartoony Kid-Appeal Checklist]]; skill `.claude/skills/roblox-cartoony-building/SKILL.md`
- Parts, meshes and collision: [[Parts Unions and MeshParts]], [[Collision and Physics Geometry]], [[Mesh Optimization for Mobile]], [[Foliage Props and Scatter]], [[BasePart - Engine Reference Card]], [[Model - Engine Reference Card]]
- Materials: [[Materials MaterialVariants and SurfaceAppearance]], [[MaterialService and Custom Materials]], [[SurfaceAppearance PBR Workflow]], [[Tiling Trim Sheets and Decal Tricks]], [[Textures Decals and Texture Memory]]
- Terrain: [[Terrain Deep Dive - Materials Water and Performance]], [[Terrain Tools and Terrain API]], [[Terrain - Engine Reference Card]]
- Lighting: [[Lighting Technologies and Settings]], [[Stylized Lighting Recipes]], [[Atmosphere Sky Clouds and Post-Processing]], [[Light Sources and Shadows]]
- Performance and streaming: [[Level of Detail and Model Streaming]], [[Instance Streaming]], [[StreamingEnabled QA - Forcing Stream-Out to Catch Nil Bugs]], [[Rendering Performance]], [[Mobile and Low-End Optimization]], [[Art Budgets - Triangles Draw Calls Memory]], [[Physics Performance]], [[Client Zone Culling for Interiors and Cities]], [[Developer Console and Stats]], [[MicroProfiler Guide]], [[Workspace - Engine Reference Card]]
- What changed: [[Engine and API Changes 2025-2026]], [[API Renames and Deprecations 2025-2026]], [[03 What's New on Roblox - RDC 2026 and October]]

## Sources
All read 2026-10-30.
- RDC26 What We Announced (DevForum): https://devforum.roblox.com/t/rdc26-what-we-announced/4865880
- Lighting API reference: https://create.roblox.com/docs/reference/engine/classes/Lighting
- Extended Light Ranges: Doubling the Limit to 120 (DevForum, Sep 23, 2025): https://devforum.roblox.com/t/extended-light-ranges-doubling-the-limit-to-120/3954367
- Instance streaming: https://create.roblox.com/docs/workspace/streaming
- SLIM: https://create.roblox.com/docs/workspace/streaming/slim
- PartType enum: https://create.roblox.com/docs/reference/engine/enums/PartType
- Workspace API reference: https://create.roblox.com/docs/reference/engine/classes/Workspace
- MeshPart API reference: https://create.roblox.com/docs/reference/engine/classes/MeshPart
- ColorGradingEffect: https://create.roblox.com/docs/reference/engine/classes/ColorGradingEffect.md
- TonemapperPreset enum: https://create.roblox.com/docs/reference/engine/enums/TonemapperPreset.md
- Improve performance: https://create.roblox.com/docs/performance-optimization/improve
- Not re-read this session (the web-fetch budget ran out); taken from vault notes that cite them: the mesh streaming DevForum post (Apr 27, 2026), 4K textures (Jan 30, 2026), frustum streaming (Sep 2026), custom terrain materials full launch (Oct 2026), the MaterialService and SurfaceAppearance API pages.

## Vault corrections
| Note | Claim | Correction | Source |
|---|---|---|---|
| Lightning Strikes and Thunder - Procedural Bolts and Sound Delay (line ~100) | PointLight `Range` "max 60 studs per Roblox docs" | The max has been 120 studs since Sep 23, 2025 | DevForum Extended Light Ranges post |
| How to make CARTOON LIGHTING in Roblox Studio (video note) | "Keep Technology as ShadowMap" | Technology is deprecated. The equivalent is `LightingStyle = Soft` + `PrioritizeLightingQuality = true` | Roblox docs (Lighting API) |
| Make Your Roblox Game Look 10x Better With Lighting (video note) | "Switch Technology to realistic/best shadows" | Use `LightingStyle = Realistic` + `PrioritizeLightingQuality = true`; for our cartoony games prefer Soft | Roblox docs (Lighting API) |
| Engine and API Changes 2025-2026; Rendering Performance; Level of Detail and Model Streaming; API Renames and Deprecations 2025-2026; AI Pitfalls - Assets and Import; SYMPTOMS | Property spelled `MeshStreamingAndImprovedLoDs` | The docs' Workspace API page lists `MeshStreamingAndImprovedLods` (lower-case "ods"). Copy the name from the Properties window before scripting against it | Roblox docs (Workspace API) |
| Mobile and Low-End Optimization | "draw distance and detail shrink" (no number) | Add: about 200 studs on low-end Android at quality 1 today; 500-stud minimum announced for late 2026 | DevForum RDC26 post |
