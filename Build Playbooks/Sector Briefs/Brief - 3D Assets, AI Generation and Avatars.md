---
tags: [sector-brief, 3d-assets, blender, import, meshpart, ai-generation, cube, pets, rigging, creator-store, licensing, avatars, ugc, emissive]
updated: 2026-10-30
---
# Brief - 3D Assets, AI Generation and Avatars
Back to [[00 Build Router]] · All briefs: [[Sector Briefs Index]]

> TL;DR
> - Fix size, facing and pivot in Blender, not Studio. Use 1 Blender unit = 1 stud, apply transforms, and set the importer's Scale Unit to Studs. Import with File > Import, then check the warnings panel every time.
> - Hard cap: **20,000 triangles per mesh** (Roblox docs). Our own budget for cartoony props is far lower, 300 to 3,000 (rule of thumb). AI meshes arrive with 100k+ triangles and must be reduced.
> - Studio's AI tools work: `generate_mesh` (default cap 10,000 tris), `generate_procedural_model`, `generate_material` and Texture Generator (Fast 1K or Quality 4K PBR). Always re-measure the size and proportions of a generated mesh before placing it.
> - Runtime generation is `GenerationService:GenerateModelAsync` (4D beta, Feb 2026). `GenerateMeshAsync` is deprecated. Generated objects are lost when the server closes. Leave this out of our kid games unless it is the core idea.
> - Pets: pets that only follow are cosmetic. Each client renders them anchored and moves them with `PivotTo`. The server owns only which pets you have. Rig an animated pet in Blender, import it with Rig Type Custom, and play it through `AnimationController` + `Animator`.
> - Glow: since Feb 2026, emissive masks on `SurfaceAppearance` work in every published experience. Use them instead of duplicate Neon shells, and keep pulses to 1 flash per second or fewer.
> - Avatars: use only the `*Async` HumanoidDescription APIs (`ApplyDescriptionAsync`, `GetHumanoidDescriptionFromUserIdAsync`, `CreateHumanoidModelFromDescriptionAsync`). The old names are deprecated.
> - Licences: upload every asset to the group that owns the game. Free AI plans can require attribution or forbid commercial use: check before you ship. Never invent asset IDs.

## Current state (Oct 2026): what's new, renamed or deprecated

| Change | Status / date | What it means for us | Source |
|---|---|---|---|
| Mesh generation in Assistant (`/generate ...`) | Live, DevForum 19 Mar 2026 | Text to a textured mesh. Optional Max Triangle Count (default 10000). If you select a Part first, its size becomes the bounding box | DevForum (19 Mar 2026) |
| Built-in Studio MCP server | Live; docs list 33 tools | `generate_mesh`, `generate_material`, `generate_procedural_model` + `wait_job_finished`, `search_asset`, `insert_asset`, `upload_image`, `store_image`, `screen_capture`, `execute_luau` | Roblox docs (Studio MCP) |
| `insert_from_creator_store` MCP tool | Named in the Mar 2026 post, **absent from current docs** | Use `search_asset` + `insert_asset` | Roblox docs vs DevForum (19 Mar 2026) |
| Texture Generator Quality mode | Live | Fast = 1K diffuse via the texture id, under 30 s. Quality = 4K PBR via a new `SurfaceAppearance`, a couple of minutes. Also reachable via `/generate_texture` and MCP | Roblox docs (Texture Generator) |
| 4D generation (`GenerateModelAsync`, schemas `Car5`, `Body1`) | Beta, 4 Feb 2026 | Players generate working objects in game. Starts at 10 requests per minute per experience. Not persisted between sessions | DevForum (4 Feb 2026), Roblox newsroom (4 Feb 2026) |
| `GenerationService:GenerateMeshAsync` | **Deprecated** (DevForum said it would be deprecated on 18 March) | Do not build on it | Roblox docs (GenerationService), DevForum (4 Feb 2026) |
| Emissive masks in experiences | Live, 12 Feb 2026 | `EmissiveMaskContent`, `EmissiveStrength`, `EmissiveTint` on `SurfaceAppearance`, `MaterialVariant` and `TerrainDetail`. They bloom like Neon but cast no light. Decals are not supported | DevForum (12 Feb 2026) |
| Emissive UGC avatar items | Pilot from 31 Aug 2026 (application, NDA, Roblox Plus). RDC26 lists it as "Late 2026" | Upload fee 500 Robux, and non-limited advances are 5x | DevForum (31 Aug 2026, 11 Sep 2026), Roblox docs (Marketplace fees) |
| HumanoidDescription and character APIs | Non-Async names deprecated | `ApplyDescriptionAsync`, `ApplyDescriptionResetAsync`, `Players:GetHumanoidDescriptionFromUserIdAsync`, `...FromOutfitIdAsync`, `CreateHumanoidModelFromDescriptionAsync`, `CreateHumanoidModelFromUserIdAsync`, `GetCharacterAppearanceInfoAsync` | Roblox docs (Humanoid, Players) |
| RDC26 roadmap, coming | Late 2026 | Instant asset moderation feedback during development; Cone, Capsule, Disc and rounded primitives; improved auto collision geometry with a debug overlay; Scene Generation | DevForum (11 Sep 2026) |
| RDC26 roadmap, later | Early to mid 2027 | Silhouette-preserving layered clothing; new default movement; material layering | DevForum (11 Sep 2026) |
| Publishing | No date given | Roblox expects about 40% fewer bans for well-meaning creators after changes to content violations. One question can replace the full questionnaire for 16+ in most regions | DevForum (11 Sep 2026) |

## The recipes (how we build X)

### 1. Blender prop to MeshPart (static)
1. Model at game size: 1 Blender unit = 1 stud. A default R15 avatar is about 5 studs tall (rule of thumb), so a pet is usually 1.5 to 3 studs (rule of thumb). See [[Modelling to the Roblox Camera and Player Scale]].
2. Apply rotation and scale (`Ctrl+A`). Put the origin at the bottom centre for anything that sits on the ground. Check that normals face outward (Face Orientation overlay).
3. Use one material and one UV set per mesh. For cartoony, untextured looks, use one gradient palette texture shared by the whole kit: [[The Gradient Palette Texture Workflow]], [[Trim Sheets Atlases and Vertex Colors]].
4. Export GLB for static props (rule of thumb). For FBX, use our skill's axes: Forward = Z, Up = Y (`.claude/skills/blender-roblox-models`). The LihFolk convention is Apply Scalings = FBX Unit Scale. Pick one and keep it for the whole kit.
5. In Studio, go to File > Import (Roblox docs) and set these:
   - Name: set it, or GLBs arrive as `Scene` (Vault note).
   - Scale Unit: Studs (the default).
   - Use Imported Pivot: on (the default).
   - Merge Meshes: off for kits.
   - Upload to Roblox: on by default. Turn it off while you iterate (rule of thumb).
   - Creator: the group that owns the game.
   - **Anchored: off by default.** Turn it on for props.
6. Read the warnings panel. Then run the audit below.
7. Set collision on purpose:
   - Decor: `CanCollide`, `CanTouch` and `CanQuery` all false.
   - Things players stand on: an invisible box Part.
   - `CollisionFidelity` cannot be changed by a script on a loaded part, so set it in Studio (Vault note: [[Exporting and Validating Models for Roblox]]).

```lua
--!strict
-- Studio Command Bar: select the imported Model, then run. Prints problems; changes nothing.
local Selection = game:GetService("Selection")
local root = Selection:Get()[1]
assert(root, "Select the imported model first")
for _, d in root:GetDescendants() do
	if d:IsA("MeshPart") then
		local p = d :: MeshPart
		local s = p.Size
		if p.TextureID == "" and not p:FindFirstChildOfClass("SurfaceAppearance") then
			warn(p:GetFullName(), "no texture (fine only if it uses vertex colours)")
		end
		if p.PivotOffset ~= CFrame.new() then
			warn(p:GetFullName(), "PivotOffset not identity (upload add-ons can rotate it)")
		end
		if not p.Anchored then warn(p:GetFullName(), "not Anchored") end
		if math.max(s.X, s.Y, s.Z) > 100 or math.min(s.X, s.Y, s.Z) < 0.05 then
			warn(p:GetFullName(), "odd size", s, "- check units at export")
		end
		if p.CanCollide and p.Transparency >= 1 then warn(p:GetFullName(), "invisible wall") end
	end
end
print("audit done")
```

### 2. AI-generated mesh (in Studio)
1. Prompt with `/generate` in Assistant, or call MCP `generate_mesh` from Claude Code. Set Max Triangle Count to a few hundred to 1K for low-poly props, as the DevForum post suggests (19 Mar 2026).
2. Select a Part first to give it a bounding box (DevForum, 19 Mar 2026). Even so, **measure the result**. Vault notes report that requested size and proportions are ignored.
3. Keep jobs few at a time. Many jobs at once return "Too Many Requests" (Vault note). Body-part words such as "skeleton" or "teeth" have failed moderation (Vault note).
4. Retexture with Texture Generator: select the mesh, then Model tab > Texture. Use Quality for hero items only, because it adds a 4K `SurfaceAppearance` and costs more memory (rule of thumb). Don't edit the mesh while generation runs (Roblox docs).
5. If you need editable pieces instead of one mesh, use `generate_procedural_model` (primitives in a `GeneratedFolder`, then `wait_job_finished`). Watch the part count, which adds draw calls ([[Art Budgets - Triangles Draw Calls Memory]]).

```lua
--!strict
-- Fit a generated mesh to a target height without distorting it.
local function fitToHeight(part: MeshPart, targetHeight: number)
	local size = part.Size
	if size.Y <= 0 then return end
	part.Size = size * (targetHeight / size.Y)
end
```

### 3. AI mesh from outside Roblox (Meshy, Tripo, Hunyuan3D, Rodin)
1. Make the reference image first: front view, a simple pose and limbs apart (legs standing, wings away from the body), so rigging works. From [[I Built a Roblox Pet RPG with Claude Opus 4 MCP + Roblox Studio MCP (Full Tutorial)]].
2. Generate, then reduce the mesh. In the video, Meshy Remesh with Adaptive and Quads took a dog from about 250,000 to about 3,000 triangles. Remesh with a fixed polygon count damaged the texture.
3. In Blender, apply transforms, set the origin and scale to studs. Rebuild hard-surface shapes instead of decimating them. Remove lighting baked into the colour map. Full pipeline: [[AI 3D Model Generation Outside Roblox]], [[Retopology and Decimation]].
4. **Write down the licence for the plan you used** before shipping. See the licence table under Numbers.

### 4. Pets (follow, rig, glow)
- **Ownership and odds live on the server.** The server rolls the pet with `Random.new()` and saves pets with unique ids. It publishes the equipped pets as one Player attribute. Paid eggs show their odds and a pity counter. Full wiring: [[Pet Hatching and Following End to End]].
- **Following is cosmetic and runs on the client.** Each client clones the pet models, anchors the root and moves it every frame. There is no physics, no network ownership and no `AlignPosition` on the server (Vault note).

```lua
--!strict
-- Client: one step of pet follow. Call from RunService.RenderStepped for each rendered pet.
local SHARPNESS = 10 -- higher = snappier
local function followStep(pet: Model, root: BasePart, slot: number, dt: number, t: number)
	local offset = CFrame.new((slot - 2) * 3, 0, 4) -- side by side, 4 studs behind
	local bob = math.sin(t * 4 + slot) * 0.25
	local target = root.CFrame * offset * CFrame.new(0, bob - 1.5, 0)
	local alpha = 1 - math.exp(-SHARPNESS * dt) -- frame-rate independent
	pet:PivotTo(pet:GetPivot():Lerp(target, alpha))
end
```

- **Rigged pet (bones):**
  1. In Blender, add an armature and use automatic weights. Use at most 4 bone influences per vertex. Bones must be frozen at scale 1 and rotation 0, with the root at 0,0,0 (Roblox docs).
  2. Export FBX with Add Leaf Bones off (Vault note). Import with Rig Type: Custom.
  3. Upload the animations to the **group that owns the game**, or they won't play ([[Animation Asset Permissions and Groups]]).
- **Rigid-part pet (Motor6D):**
  1. Import the parts separately, with Merge Meshes off.
  2. Put each limb's Blender origin on its hinge.
  3. Join each limb to the root with a Motor6D at that pivot. Don't also weld a part that a Motor6D drives (Vault note).

```lua
--!strict
-- Joint a limb to the pet root so it rotates around its imported pivot (the Blender origin).
local function motorAtPivot(root: BasePart, limb: BasePart, name: string): Motor6D
	local hinge = limb:GetPivot()
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = root
	m.Part1 = limb
	m.C0 = root.CFrame:ToObjectSpace(hinge)
	m.C1 = limb.CFrame:ToObjectSpace(hinge)
	limb.Anchored = false -- only the root stays anchored
	m.Parent = root
	return m
end

-- Play a looping clip. animId comes from the owner's checklist; never invent one.
local function playLoop(pet: Model, animId: string): AnimationTrack?
	if animId == "" then return nil end
	local ctrl = pet:FindFirstChildOfClass("AnimationController") or Instance.new("AnimationController")
	ctrl.Parent = pet
	local animator = ctrl:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = ctrl
	local anim = Instance.new("Animation")
	anim.AnimationId = animId
	local track = animator:LoadAnimation(anim)
	track.Looped = true
	track:Play()
	return track
end
```

- **Tier glow:** paint an emissive mask, which is a grayscale map; only the red channel is read. Set it on the pet's `SurfaceAppearance` in Studio, because the map properties are not writable by game scripts (Vault note: [[SurfaceAppearance PBR Workflow]]). Scripts may change `EmissiveStrength` and `EmissiveTint`. A pure black colour area won't glow unless you tint it (DevForum, 12 Feb 2026).

```lua
--!strict
-- Slow breathing glow: one cycle every 3 s, well under 1 flash per second.
local TweenService = game:GetService("TweenService")
local function glowPulse(sa: SurfaceAppearance, peak: number)
	local info = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	TweenService:Create(sa, info, { EmissiveStrength = peak }):Play()
end
```

### 5. Avatars in our games (statues, NPCs, uniforms)
Run this on the server. Wrap every call in `pcall`, because these are web calls that can fail.

```lua
--!strict
local Players = game:GetService("Players")
-- Leaderboard statue of a player's real avatar.
local function makeStatue(userId: number, where: CFrame): Model?
	local ok, desc = pcall(Players.GetHumanoidDescriptionFromUserIdAsync, Players, userId)
	if not ok or not desc then return nil end
	local ok2, model = pcall(Players.CreateHumanoidModelFromDescriptionAsync, Players, desc, Enum.HumanoidRigType.R15)
	if not ok2 or not model then return nil end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then d.Anchored = true end
	end
	model:PivotTo(where)
	model.Parent = workspace
	return model
end
```
- To change a live character, start from `humanoid:GetAppliedDescription()`, edit it, then call `ApplyDescriptionAsync`. Use `ApplyDescriptionResetAsync` if other code has added parts by hand ([[HumanoidDescription and Outfit Systems]]).
- When a game sells a catalog item, the creator gets 30% and the game owner gets 40% (Roblox docs, Marketplace fees).

### 6. Creator Store and Toolbox assets
1. Prefer our own Blender kits. If you take a store model, insert it (MCP `search_asset` then `insert_asset`, or the Toolbox). Then **delete every Script in it and read any you keep** ([[Creator Store and Toolbox Safety]]).
2. Open Use assets can be used by anyone who has the id. Restricted assets load only where the owner allows (Vault note citing Roblox docs).
3. Re-upload the art we own to the game's group, so it loads in group games.

## Numbers and limits

| Item | Value | Source |
|---|---|---|
| Triangles per mesh | 20,000 max | Roblox docs (mesh specifications) |
| Bone influences per vertex | 4 max | Roblox docs (mesh specifications) |
| Rig transforms | Bones scale 1,1,1, rotation 0,0,0, root at 0,0,0 | Roblox docs (mesh specifications) |
| Animation tracks per FBX | One | Roblox docs (mesh specifications) |
| Texture upload resolution | Up to 4096 x 4096. The same page also says "up to 1024 x 1024" for UV texture maps (the page conflicts with itself) | Roblox docs (texture specifications) |
| Normal maps | OpenGL tangent space only | Roblox docs (texture specifications) |
| Roughness, metalness, emissive maps | Single-channel 8-bit grayscale | Roblox docs (texture specifications) |
| Importer formats | .fbx, .obj, .gltf/.glb | Roblox docs (3D Importer) |
| `generate_mesh` triangle cap | Default 10,000, adjustable down | DevForum (19 Mar 2026) |
| Texture Generator | 3 previews in about 10 s; Fast 1K in under 30 s; Quality 4K PBR in about 2 min | Roblox docs (Texture Generator) |
| Procedural models | 50 per rolling 24 hours | Vault note ([[Roblox Generative AI - Cube Mesh and Texture Generation]]) |
| Mesh segmentation | Up to 5 names per run, 8 parts per model, "early preview" | Vault note (same) |
| 4D runtime API rate | Starts at 10 requests per minute per experience, scales with users | DevForum (4 Feb 2026) |
| UGC accessory budget | 4,000 triangles, one mesh | Vault note ([[UGC Avatar Items and Accessories]]) |
| UGC upload fee | 80 Robux; 500 with an emissive mask | Roblox docs (Marketplace fees) |
| Emissive non-limited advance | 5x standard (hat 7,500; shirt 3,000; body bundle 12,500) | Roblox docs (Marketplace fees) |
| Creator Store paid assets | Models 2.99 to 49.99 USD, plugins 4.99 to 249.99 USD, ID-verified, no group-owned sales | Vault note ([[Legal Basics - IP Licenses and Assets]], citing Roblox docs Oct 2026) |
| Cartoony prop budget | Small prop 100 to 800 tris; medium 800 to 3,000; hero 5,000 to 10,000; textures 1024 at most | Rule of thumb (`LihFolk/skills/roblox-asset-import`) |
| Pet budget | About 3,000 tris worked in the pet RPG video; 30 players x 3 pets = 90 models moved per frame on every client | Video note; Vault note |
| Meshy Free plan | CC BY 4.0, commercial use with attribution; paid plans need no attribution | Vault note ([[AI 3D Model Generation Outside Roblox]]), not re-checked today |
| Tripo free plan | Reported as no commercial licence | Vault note (third-party source), check vendor terms |
| Hunyuan3D (Tencent community licence) | The licence's "Territory" excludes the EU, UK and South Korea, with extra terms for very large products | Hunyuan3D-2 LICENSE on Hugging Face (seen in search results, full text not re-read today): **check before use** |
| Roblox Cube 3D open weights | OpenRAIL-family licence on the Hugging Face model card | Search result for the Roblox/cube3d model card, not re-read today |

## Pitfalls
- **Fixing size in Studio.** Scaling a MeshPart in Studio leaves texture density, pivots and kit offsets wrong. Fix it at export (Vault note).
- **Assuming the importer anchors.** Anchored is off by default (Roblox docs). Unanchored props fall or get pushed.
- **"Roblox mesh limit is 10,000."** That is only `generate_mesh`'s default cap. The engine limit is 20,000 per mesh.
- **Trusting generated proportions.** Generated meshes come out at whatever size and aspect ratio the model chose. Uniform rescaling can't fix a wrong aspect ratio, and stretching distorts the baked texture.
- **Light baked into AI textures.** The model looks lit twice. Clean the colour map or regenerate it with Texture Generator.
- **Server-side pets with `AlignPosition`.** They jitter and churn network ownership. Render cosmetic pets on the client.
- **Welding parts that a Motor6D also drives.** The joints fight, and the limb freezes or flips.
- **Animations uploaded to a personal account** in a group game don't play.
- **Neon duplicate shells for glow.** They double the triangles. Use an emissive mask (live since Feb 2026). Emissive glow does not light nearby parts, so add a PointLight if you need light.
- **Deprecated avatar APIs.** AI models still write `ApplyDescription`, `GetHumanoidDescriptionFromUserId` and `CreateHumanoidModelFromDescription`. Use the `*Async` names.
- **Runtime `GenerateMeshAsync`.** It is deprecated. Even the 4D replacement loses objects between sessions, and player prompts are a moderation risk in a kid game (rule of thumb).
- **Free models with scripts.** Hidden backdoors and `require` calls by asset id. Strip the scripts.
- **Invented asset or animation IDs.** Leave them `""` or 0 and add them to the owner's checklist (repo rule).
- **Paid AI plan assumed.** Free plans of some tools need attribution or forbid commercial use. Record the plan with each asset.

## Checklist before shipping
- [ ] Every mesh is under 20,000 triangles, and props are within our budget.
- [ ] Transforms were applied in Blender. Scale is in studs, and the pivot sits at the bottom centre or on the hinge.
- [ ] Import warnings were read, the audit script ran clean, and Anchored and collision were set on purpose.
- [ ] Generated meshes were measured and fitted. No hard-surface piece still has wobbly AI edges.
- [ ] Every asset is uploaded to the game's group. Animations are owned by that group too.
- [ ] The licence and plan for each AI or store asset is written down (in `design/` or the game's notes).
- [ ] Store models have their scripts removed or reviewed.
- [ ] Pets: the server owns the rolls and inventory. Odds and pity are shown for paid eggs. Following runs on the client. Glow pulses at 1 flash per second or fewer.
- [ ] Avatar code uses only `*Async` APIs, wrapped in `pcall`.
- [ ] No invented IDs: every missing ID is on the owner's checklist.

## Go deeper
- Import and export: [[Exporting and Validating Models for Roblox]], [[3D Importer Settings Reference]], [[Exporting FBX vs GLB]], [[Blender Workflow for Roblox Creators]], [[Enemy Import Axis Fix]], [[Asset Upload Automation with Open Cloud]]
- Budgets and look: [[Art Budgets - Triangles Draw Calls Memory]], [[Mesh Optimization for Mobile]], [[Low-Poly and Stylized Modeling]], [[Spending Triangles Where the Camera Looks]], [[UV Unwrapping]], [[The Gradient Palette Texture Workflow]], [[SurfaceAppearance PBR Workflow]]
- AI generation: [[Roblox Generative AI - Cube Mesh and Texture Generation]], [[AI 3D Model Generation Outside Roblox]], [[AI Material and Texture Generation]], [[Roblox Studio MCP Server]], [[Roblox Built-In AI Tools Timeline 2023-2026]], [[AI Pitfalls - Assets and Import]]
- Pets and rigs: [[Pet Hatching and Following End to End]], [[Importing Models and Rigs]], [[Custom Rigs - Weapons and Props]], [[Creature Rig Conventions]], [[Bones and Skinned Meshes]], [[Character and Creature Pipeline]], [[Low-Poly Creature From a Flat Reference Sheet]], [[Chibi Character Rules in Practice]], [[Teardown - Ride A Pet]]
- Videos: [[I Built a Roblox Pet RPG with Claude Opus 4 MCP + Roblox Studio MCP (Full Tutorial)]], [[How To Connect Claude To Blender (Blender MCP Setup)]], [[04 Building, Maps & 3D Models]]
- Licensing and store: [[Legal Basics - IP Licenses and Assets]], [[Creator Store and Toolbox Safety]], [[Roblox Policies on AI-Generated Content]], [[Who Owns AI-Generated Code and Assets]], [[Animation Asset Permissions and Groups]], [[Packages and Asset Reuse]]
- Avatars: [[HumanoidDescription and Outfit Systems]], [[Avatar Body Types and Scale in Gameplay]], [[UGC Avatar Items and Accessories]]
- Skills: `.claude/skills/blender-roblox-models`, `LihFolk/skills/roblox-blender-modeling`, `LihFolk/skills/roblox-asset-import`

## Sources
All read 2026-10-30.
- https://create.roblox.com/docs/art/modeling/specifications
- https://create.roblox.com/docs/art/modeling/texture-specifications
- https://create.roblox.com/docs/art/modeling/3d-importer
- https://create.roblox.com/docs/studio/texture-generator
- https://create.roblox.com/docs/studio/mcp.md
- https://create.roblox.com/docs/reference/engine/classes/GenerationService
- https://create.roblox.com/docs/reference/engine/classes/Humanoid
- https://create.roblox.com/docs/reference/engine/classes/Players
- https://create.roblox.com/docs/en-us/marketplace/marketplace-fees-and-commissions
- https://devforum.roblox.com/t/rdc26-what-we-announced/4865880 (11 Sep 2026)
- https://devforum.roblox.com/t/assistant-updates-mesh-generation-new-mcp-server-tools-screenshot-tool-and-more/4527258 (19 Mar 2026)
- https://devforum.roblox.com/t/beta-4d-generation-unlock-new-types-of-gameplay/4331818 (4 Feb 2026)
- https://devforum.roblox.com/t/emissive-masks-are-now-live-for-published-experiences/4357705 (12 Feb 2026)
- https://devforum.roblox.com/t/pilot-create-and-sell-emissive-items-on-marketplace/4842465 (31 Aug 2026)
- https://about.roblox.com/tr/newsroom/2026/02/accelerating-creation-powered-roblox-cube-foundation-model (4 Feb 2026)
- Not fetched (budget ran out), search results only: the Hunyuan3D-2 LICENSE on Hugging Face, the Roblox cube3d model card, the Creator Store docs. The licence rows above are marked as such.

## Vault corrections
- **[[I Built a Roblox Pet RPG with Claude Opus 4 MCP + Roblox Studio MCP (Full Tutorial)]]** (table row "Roblox mesh limit: about 10,000 triangles"). The engine limit is 20,000 per mesh. 10,000 is only the default cap of `generate_mesh`. Source: Roblox docs (mesh specifications); DevForum (19 Mar 2026).
- **[[Cookbook - Players and Characters]]** (about line 403) uses `GetHumanoidDescriptionFromUserId` and `ApplyDescription`. Both are deprecated: use `GetHumanoidDescriptionFromUserIdAsync` and `ApplyDescriptionAsync`. Source: Roblox docs (Players, Humanoid).
- **[[Character Select and Class Systems with Different Rigs]]** and the atlas note **[[ApplyDescription]]** recommend `ApplyDescription`. It is deprecated: use `ApplyDescriptionAsync` (or `ApplyDescriptionResetAsync`). Source: Roblox docs (Humanoid).
- **[[UGC Avatar Items and Accessories]]** gives emissive fees and advances, which are correct per the docs, but reads as if anyone can sell emissive items. Selling them was an application-only pilot from 31 Aug 2026, with a wider rollout "in the coming months" (RDC26: "Late 2026"). The "EmissiveStrength 0 to 40" limit was not confirmed in any source read today. Source: DevForum (31 Aug 2026, 11 Sep 2026).
- **[[Roblox Generative AI - Cube Mesh and Texture Generation]]** is accurate. Add: `GenerateModelAsync` starts at 10 requests per minute per experience; generated objects are not saved between sessions; weapons generate only at mild violence or higher. Source: DevForum (4 Feb 2026).
- **Code, not a vault note:** `cannon-evolution/src/server/GameServer.server.lua` line 1306 calls the deprecated `Players:CreateHumanoidModelFromDescription`. Swap it for `CreateHumanoidModelFromDescriptionAsync` inside a `pcall`. Source: Roblox docs (Players).
