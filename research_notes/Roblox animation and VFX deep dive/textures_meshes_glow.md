# Making our own VFX art: textures, mesh effects and glow (Roblox, Oct 2026)

Scope: how Roblox VFX artists make textures, mesh effects and glow looks, and how a code-only team (an AI with Python and, when installed, Blender headless) can make the same art. Tags: **[C]** = cited from the linked source; **[S]** = suggested by me (a starting number to test, not a published rule). Flipbook basics (2x2/4x4/8x8 grids, 30 fps cap, OneShot/Loop/PingPong/Random, square power-of-two up to 1024) are already in `research_notes/Pro Roblox animation and VFX/vfx_pipeline.md` §1 and are not repeated here. Bloom and lighting presets are in `research_notes/Front page feel and gamey stages/lighting_and_gates.md`.

Environment check (this cloud session, Oct 31 2026): Python 3 with Pillow 12.3 and NumPy 2.5 is installed; **Blender is not installed** (`which blender` is empty). Mesh files can still be written as plain-text OBJ from Python, or Blender added later (for example `pip install bpy`, untested here).

## 1. How VFX textures are made, and which sizes, alpha and tint conventions work on Roblox

### Takeaway
The safe default is: a **white or greyscale shape on a transparent PNG**, coloured in Roblox with `ParticleEmitter.Color` / `Beam.Color`. For additive glows, a greyscale image on black works too, because LightEmission 1 adds the colours, so black disappears. Pros paint in GIMP/Krita/Photoshop (with a Polar Coordinates filter for rings and slashes), simulate in EmberGen, or render in Blender. Every one of these steps can be done in Python with Pillow and NumPy.

### Cited Findings
- Roblox's particle docs say "it's best to use .png format with a transparent background". — [Creator Docs: Particle emitters](https://create.roblox.com/docs/effects/particle-emitters)
- The default particle texture is a white sparkle, and `Color` "tints each particle's texture", which is the white-then-tint convention. — [Creator Docs: Particle emitters](https://create.roblox.com/docs/effects/particle-emitters)
- For greyscale textures without alpha, the docs say to "try setting the particle emitter's LightEmission property to 1 to hide the darker regions". LightEmission runs from 0 (normal blending) to 1 (additive). — [Creator Docs: Particle emitters](https://create.roblox.com/docs/effects/particle-emitters)
- At LightEmission 1, particles tinted black turn invisible, because adding black adds nothing. The thread's fix is to drop LightEmission to 0 when a dark colour must show. The same happens on Beams. — [DevForum: LightEmission 1 black becomes transparent](https://devforum.roblox.com/t/when-coloring-particles-with-lightemission-1-to-black-they-become-transparent/2614320); [DevForum: Beam goes transparent when black](https://devforum.roblox.com/t/beam-goes-transparent-when-adjusting-color-to-black/2935018)
- Other look properties: `LightInfluence` (how much scene light tints particles), `Brightness` (scales emitted light when LightInfluence is 0), `Squash` (stretches particles over their life), `Orientation` (FacingCamera, FacingCameraWorldUp, VelocityParallel, VelocityPerpendicular) and `ZOffset` (layers emitters without changing their size). — [Creator Docs: Particle emitters](https://create.roblox.com/docs/effects/particle-emitters)
- Memory: "choose a texture of smaller resolution when possible", and "reusing textures costs less memory than using unique textures". Flipbooks need "spacing between each of the particle frames". — [Creator Docs: Particle emitters](https://create.roblox.com/docs/effects/particle-emitters)
- Uploaded images can be up to 4096×4096. Mesh UV texture maps are limited to 1024×1024. Roblox suggests 256 px for 5-stud objects, 512 for 10-stud and 1024 for 20-stud. Formats: .png, .jpg, .tga, .bmp. The engine streams low-quality versions first. — [Creator Docs: Texture specifications](https://create.roblox.com/docs/art/modeling/texture-specifications)
- Open Cloud accepts Decal/Image uploads "smaller than 8000x8000" pixels, up to 20 MB, as png/jpeg/bmp/tga. — [Creator Docs: Assets usage guide](https://create.roblox.com/docs/en-us/cloud/guides/usage-assets)
- The crescent-slash method from a DevForum tutorial: in GIMP, draw a few lines of different thickness, opacity and colour on their own layer, fade the edges with the eraser, then run **Filters > Distorts > Polar Coordinates** to bend them into a ring or arc. — [DevForum: Crescent Sword Slash Effect](https://devforum.roblox.com/t/crecent-sword-slash-effect/1113871)
- Asphalt, an asset uploader, alpha-bleeds images by default "for crisp edges" (borrowed from Tarmac). This shows alpha bleeding (copying edge colours into the fully clear pixels) is a known fix for dark fringes on Roblox. It also turns SVGs that use `currentColor` white, so they can be tinted in Roblox. — [GitHub: jackTabsCode/asphalt](https://github.com/jackTabsCode/asphalt)
- EmberGen (JangaFX) simulates fire, smoke and explosions in real time and exports flipbooks. — [EmberGen](https://jangafx.com/software/embergen)

### Inferences
- **[S] Default texture contract for our games:** a 256 or 512 px square PNG with a white or greyscale shape and real alpha. Run an alpha bleed (fill the RGB of clear pixels with the nearest edge colour) to avoid grey or black fringes. Tint everything in Roblox (Color sequence), so one texture serves every rarity and accent colour. This matches CLAUDE.md's rule to tie effects to the skin's accent colour.
- **[S] When to use black backgrounds:** only for additive layers (LightEmission 1: glows, sparks, energy). Smoke, dust and dark "void" effects need real alpha with LightEmission 0, or they vanish.
- **[S] Python recipes (Pillow + NumPy), all deterministic, so they can be committed as tools:**
  1. *Soft glow dot*: alpha = (1 − r)^p with r the distance from centre / radius, p ≈ 2–3. RGB is white.
  2. *Ring / shockwave*: alpha = exp(−((r − r0)/w)²) with r0 ≈ 0.7 and w ≈ 0.06–0.12. Multiply by a 1-D noise around the angle for a broken ring.
  3. *Polar Coordinates in code* (the same as GIMP's filter): draw streaks on a rectangular canvas (x = angle, y = radius), then sample with θ = atan2(y, x) and r = hypot(x, y) to bend them into a ring or crescent. Mask the angle to 90–160° for a slash arc.
  4. *Noise textures*: fractal value or Perlin noise (4–5 octaves) remapped with a contrast curve. Tile it by building the noise on a torus, or by wrapping coordinates, so it scrolls with no seam on Beams and Textures.
  5. *Gradient strips for Beams*: a 1-D alpha ramp (for example 0 → 1 → 0) stretched to 256×32. Hot-core strips put a white centre line on a soft falloff.
  6. *Flipbooks*: render N frames procedurally (an expanding ring, noise dissolve with a rising threshold, sparks), tile them into a 4x4 grid on 1024 (256 px cells) or an 8x8 grid (128 px cells). Leave a clear gutter of at least 4–8 px inside each cell, since the docs ask for spacing.
  7. *Anime cel look*: posterize alpha or brightness to 2–3 steps (for example 0, 0.55, 1) and add a hard outer edge. This gives the flat "toon" read rather than soft photo smoke.
- **[S] Blender route (when installed):** render emission-only planes or Eevee smoke on a transparent film (Film > Transparent), using an orthographic camera at 1:1 aspect, then pack the frames with Pillow. Use this only when procedural 2-D falls short (for example rolling 3-D smoke). EmberGen is paid and has a GUI, so it doesn't suit a headless AI.

### Gaps
- I found no Roblox source that says whether uploaded images are stored premultiplied or straight alpha, or what compression and mip filtering they get. The fringe advice comes from Asphalt's default alpha bleeding, not from a Roblox statement.
- No first-party source names a "best" particle texture size. The 256/512 sizes are suggestions scaled from the texture-spec guidance for objects.

## 2. Mesh VFX in Blender for Roblox: UVs, export, MeshPart vs SpecialMesh, scrolling, transparency, glow materials

### Takeaway
Mesh VFX (slashes, rings, domes, spirals) are low-poly shells with UVs laid out in a strip, so a gradient or noise texture can run along them. They are imported as MeshParts and faded by tweening Transparency and Size. The texture is usually put on **Texture or Decal instances** rather than `TextureID`, so the mesh can fade. Roblox has no built-in UV scroll property. Scrolling uses `Texture.OffsetStudsU/V` (projected by surface normal) or EditableMesh UV writes (now usable in published games once the toggle is on). Glow comes from Neon (plain colour only), ForceField (an animated fresnel shimmer), Beams with LightEmission, Highlights and Bloom.

### Cited Findings
**Making and exporting the mesh**
- Studio's 3D Importer reads **.obj** (single basic meshes), plus **.fbx** and **.gltf** (multiple meshes, hierarchies, PBR textures, rigs, animation, **vertex colours**). Settings: Scale Unit (default Studs), World Forward (Front), World Up (Top), Merge Meshes (off by default) and a per-object **Make Double Sided** (off by default, and "more performance-intensive"). — [Creator Docs: 3D Importer](https://create.roblox.com/docs/art/modeling/3d-importer.md)
- Blender FBX export for Roblox: Path Mode Copy with Embed Textures on, Apply Scalings = "FBX Unit Scale", Add Leaf Bones off, Bake Animation off unless the model is animated. — [Creator Docs: Export requirements](https://create.roblox.com/docs/art/modeling/export-requirements)
- Single meshes can't go over 20,000 triangles. Roblox asks for watertight meshes with some thickness. Flat VFX shells break that guideline, so they rely on double-sided rendering. — [Creator Docs: Modeling specifications](https://create.roblox.com/docs/art/modeling/specifications)
- This repo has already checked the axes: 1 Blender unit = 1 stud, FBX Forward = Z with Up = Y undoes the Roblox axis swap, and Neon or Glass need a plain Colour because textures don't glow. — `/home/user/roblox/.claude/skills/blender-roblox-models/SKILL.md` §3–4 (repo-verified)

**Crescent slash recipe (DevForum)**
- Mesh: a squashed sphere. Paint the texture with the polar-coordinates step above. UV-map each side of the shell to the texture in Blender (the author calls this "the most important step"). Upload the texture as a Decal, then put **two Texture objects** inside the MeshPart rather than using its own TextureId, "to make the mesh transparent". Replies animate it by shifting a spritesheet's offset, or by cloning it along the swing and cleaning up with Debris. — [DevForum: Crescent Sword Slash Effect](https://devforum.roblox.com/t/crecent-sword-slash-effect/1113871)

**Scrolling textures on meshes**
- A DevForum survey of the options:
  - `Texture` with OffsetStudsU/V gives a basic scroll on curved meshes, but the projection follows surface normals, so you can't control it.
  - A Beam laid on the surface scrolls, but must be offset to avoid Z-fighting, and loses segments on low-end devices.
  - SurfaceGui doesn't curve with the surface.
  - Swapping `TextureID` per frame works, but blows the memory budget.
  - Shifting UVs every Heartbeat with EditableMesh (`GetUV`/`SetUV`) is "the main workable method". It also works with SurfaceAppearance, but only shows in Play mode.
  - The author asks Roblox for a built-in UV-offset property, which didn't exist at the time.
  - — [DevForum: Scrollable textures for MeshParts](https://devforum.roblox.com/t/scrollable-textures-for-meshparts/2820890)
- A `Texture` repeats across a face while a `Decal` stretches. `StudsPerTileU/V` set the tile size, and `OffsetStudsU/V` move the tile. — summarised (with source) in `research_notes/Cartoony Roblox building UI and animation/building_stylized_techniques.md` line 123

**SpecialMesh vertex colour**
- `FileMesh/SpecialMesh.VertexColor` "changes the hue of a mesh's texture" (a Vector3 multiplier used with TextureId). Its Scale and Offset can be tweened, for example Scale (4,4,4) → (1,1,1). — [Creator Docs: FileMesh](https://create.roblox.com/docs/en-us/reference/engine/classes/FileMesh.md)
- On a SpecialMesh, the part's Material doesn't show, so there's no Neon or ForceField on SpecialMesh shells. — summarised in `research_notes/Tiered props VFX and vibrant maps/prop_modeling_and_tiers.md` §SpecialMesh (cites creator-docs SpecialMesh.yaml)

**Glow materials and instances**
- ForceField material has a **fresnel** effect (glow at edges facing away from the viewer) and an **intersection** glow where it meets other geometry. Reflectance controls the fresnel (post title, Mar 26 2019). It "seems to only really work on spheres or meshes". — [DevForum: ForceField fresnel via Reflectance](https://devforum.roblox.com/t/control-the-fresnel-effect-of-forcefield-material-using-the-reflection-property/258289)
- A common custom-pattern trick: put a texture on a ForceField part or mesh. The material then animates the texture's pattern. No reply gives exact numbers. — [DevForum: Force field custom texture](https://devforum.roblox.com/t/force-field-custom-texture/471091)
- **Highlight**:
  - Up to **255** client-side Highlights render at once, and the rest are silently ignored. Disabled ones still use a slot.
  - The first Highlight costs up to 1 ms of GPU on mobile; more cost little. Mobile cost grows with screen coverage.
  - Creating or destroying a Highlight forces a geometry rebuild (a spike), so toggle its properties instead.
  - DepthMode is AlwaysOnTop or Occluded.
  - — [Creator Docs: Highlighting](https://create.roblox.com/docs/effects/highlighting)
- **Beam**:
  - TextureMode Wrap/Static repeat every TextureLength studs, and Stretch repeats the texture TextureLength times across the whole beam.
  - FaceCamera keeps it facing the camera. Width0/1 and CurveSize0/1 shape a Bézier.
  - Check beams at the lowest and highest Editor Quality Level.
  - — [Creator Docs: Beams](https://create.roblox.com/docs/effects/beams)
- Post-processing now also lists **ColorGradingEffect** (TonemapperPreset Default or Retro) beside Bloom, Blur, ColorCorrection, DepthOfField and SunRays. Bloom makes light-coloured parts glow at high values. — [Creator Docs: Post-processing effects](https://create.roblox.com/docs/environment/post-processing-effects)

### Inferences
- **[S] Code-only mesh pipeline (no Blender needed):**
  1. Generate the shell in Python as an **OBJ** with explicit `vt` UVs. U runs along the sweep (0→1 around the arc or ring) and V runs across it (0 inner edge → 1 outer edge), so a 1-D gradient or a scrolling noise reads correctly.
  2. Shapes:
     - *ring/shockwave*: an annulus of 64 segments × 2 rows;
     - *crescent*: an arc of 120–200° with width tapering to 0 at both ends (width ∝ sin(πu));
     - *dome/shield*: a UV sphere's top half, 32×12;
     - *spiral/tornado*: a helix ribbon, 3–4 turns, radius growing with height;
     - *beam cylinder*: an open tube, 24 segments.
     - All stay far under the 20k-triangle cap [C].
  3. The owner imports with File > Import 3D, Make Double Sided **on** for open shells [C]. If Blender is available, export FBX with the repo's verified settings instead.
- **[S] Settings for a mesh effect part:**
  - Anchored, CanCollide/CanTouch/CanQuery off, CastShadow off.
  - Material SmoothPlastic with the texture on a `Texture` or `Decal` child (so `Transparency` fades it), or Neon with a plain Colour for a solid glowing core.
  - Animate with TweenService: Size ×1.0→×1.6 and Transparency 0.2→1 over 0.25–0.4 s with Quad/Expo Out. Spin rings with CFrame.
  - Use two stacked copies (a slightly bigger, more transparent outer shell) for a fake glow halo.
- **[S] Scrolling choice:**
  - Flat or near-flat strips: use a `Beam` with TextureSpeed (cheapest, no code).
  - Curved shells where a normal-projected scroll looks fine: tween `Texture.OffsetStudsV`.
  - When UV-exact flow matters: use EditableMesh UV writes (needs the published-game toggle, Play mode only, client memory budget; see §3).
- **[S] Fake glow stack (cheap to pro):**
  - Neon core + Bloom (Threshold ~1.0, already tuned in the lighting notes).
  - An additive (LightEmission 1) soft-dot particle or BillboardGui behind the object.
  - A ForceField shell 5–10% larger for the fresnel rim.
  - A Highlight with FillTransparency ~0.7–0.85 on the hero item only (one slot is cheap, but each create/destroy spikes, so keep one and toggle it).
- **[S]** SpecialMesh.VertexColor is the old cheap tint for mesh VFX. Since Material doesn't show on a SpecialMesh, prefer MeshPart for anything that needs Neon or ForceField.

### Gaps
- No source fetched gives numeric ForceField behaviour (how Transparency and Reflectance map to rim strength) or a scroll speed. Test in Studio.
- I didn't confirm whether `SurfaceAppearance` supports alpha-blended transparency for VFX (its AlphaMode setting) from a 2026 source. Treat as unverified.
- Glass-material VFX tricks (refraction look on high graphics only) weren't covered by any source I fetched.
- No source confirms that vertex colours from FBX/glTF can drive per-vertex transparency on MeshParts. The importer only says vertex colours import [C].

## 3. EditableImage and EditableMesh status in Oct 2026, and new Roblox VFX features from 2025–2026

### Takeaway
Both APIs work in published games, but only when the creator turns on **"Enable Mesh / Image APIs"**. They only load assets the owner, Studio user or player owns or has been shared. Clients have strict memory budgets. EditableImage is capped at 1024×1024. EditableMesh is capped at 60k vertices / 20k triangles and gained batching APIs (Aug 2026, live in published games from Sep 15 2026). There is still no shader or material-graph feature. The 2026 VFX-adjacent news is batching APIs, ColorGradingEffect, upgraded UI gradients/UIShadow, and community tools like Effect Designer Suite.

### Cited Findings
- **EditableMesh**:
  - Limits: 60,000 vertices and 20,000 triangles (a quad counts as 2). Clients have "strict client-side memory budgets"; the server, Studio and plugins are unlimited.
  - Permissions: `CreateEditableMeshAsync` only opens assets owned by, or shared with, the game owner, the Studio user or (on the client) the player, or group assets they can edit.
  - It "fails by default in published games". Enable it in Creator Dashboard > Configure > Settings > **Enable Mesh / Image APIs**, or Studio Experience Settings > Security > **Allow Mesh / Image APIs**.
  - Display it with `AssetService:CreateMeshPartAsync(Content.fromObject(em))` or `MeshPart:ApplyMesh`. Meshes made from assets are FixedSize by default.
  - — [Creator Docs: EditableMesh](https://create.roblox.com/docs/reference/engine/classes/EditableMesh.md)
- **EditableMesh batching APIs and parallel queries:** posted Aug 6 2026 as a Studio Beta: nine bulk create/read/update/remove methods plus `Enum.MeshAttribute`, with query methods callable from Parallel Luau. The Sep 15 2026 update: "the EditableMesh batching APIs are now available in published experiences". There's no skinning or parallel writes. Replication, "the extra ID verification requirement" and permission limits are listed as ongoing work. — [DevForum: Full Release EditableMesh Batching APIs](https://devforum.roblox.com/t/full-release-editablemesh-batching-apis-parallel-queries/4779401)
- **EditableImage**:
  - Maximum 1024×1024. Size is read-only (to resize, make a new one with `DrawImageTransformed`).
  - Strict client memory budgets. Same ownership rules and the same published-game toggle.
  - Shown via `Content.fromObject(img)` on `ImageLabel.ImageContent` or `MeshPart.TextureContent`.
  - **Only one EditableImage updates per frame** on the display side.
  - `WritePixelsBuffer` takes RGBA bytes (Size.X·Size.Y·4) and uses alpha, not transparency.
  - — [Creator Docs: EditableImage](https://create.roblox.com/docs/reference/engine/classes/EditableImage.md)
- Developers hit "failed to create empty EditableImage… memory budget limits" errors in practice. — [DevForum thread](https://devforum.roblox.com/t/failed-to-create-empty-editableimage-that-was-requested-due-to-reaching-memory-budget-limits-error/3490799)
- 2026 items found in search: **Effect Designer Suite** (Jul 24 2026), described as a "brand new, open-sourced plugin for creating visual effects" with emit count, delay and duration on any emittable, repeat-emit actions, and property copy/scale tools (including past Roblox's usual limits). Its asset licence isn't stated. Roblox posts: "[Full Release] Upgraded UI Gradients" and "[Studio Beta] Upgraded UIShadow Capabilities". — [DevForum: Effect Designer Suite](https://devforum.roblox.com/t/effect-designer-suite-%E2%80%94-vfx-tooling-assets-and-more/4754553); [DevForum: Upgraded UI Gradients](https://devforum.roblox.com/t/full-release-upgraded-ui-gradients/4846594?page=7); [DevForum: Upgraded UIShadow](https://devforum.roblox.com/t/studio-beta-upgraded-uishadow-capabilities/4934553)
- ParticleEmitter's documented look properties are still the set listed in §1. The docs page shows no new particle properties with dates. — [Creator Docs: Particle emitters](https://create.roblox.com/docs/effects/particle-emitters)

### Inferences
- **[S] For our games, EditableImage/Mesh is a "later" tool, not a base.** It needs a dashboard toggle and Terms review the owner must do, it only shows in Play (CLAUDE.md already says so), it has client memory caps, and older phones run out of budget. Use it for one hero effect at most, such as UV-scrolling a single aura shell, and always have a static texture fallback when creation fails (wrap it in pcall).
- **[S]** The one-update-per-frame rule means runtime-drawn flipbooks via EditableImage are a bad idea. Use real flipbook particles.
- **[S]** "AuroraScript" or a real shader language: I found nothing. Treat any claim of Roblox custom shaders in 2026 as false until a Roblox announcement shows it.

### Gaps
- I couldn't get the exact client memory budget numbers for EditableImage or EditableMesh (the docs only say "strict").
- I didn't confirm whether the ID-verification requirement for enabling Mesh/Image APIs still applies in Oct 2026. The Aug 2026 post lists removing it as ongoing work.
- I found no Roblox announcement of new ParticleEmitter properties in 2025–2026. The search surfaced none, but I didn't read the full DevForum announcement archive.

## 4. Free texture packs with safe licences, compared with marketplace risks

### Takeaway
Only CC0 packs are truly no-strings: no credit needed and commercial use allowed. **Kenney's Particle Pack (80 sprites, CC0)** is the standard example. Toolbox and DevForum "free VFX" assets usually carry no clear licence and can come bundled with scripts. Since we make our own art, packs are best used as reference, or as a stand-in only when the owner approves.

### Cited Findings
- Kenney Particle Pack: **Creative Commons CC0**, 80 files, 512×512 tiles, tagged particle/shader/vfx. Kenney also has a separate "Smoke Particles" pack. — [Kenney: Particle Pack](https://kenney.nl/assets/particle-pack); [Kenney: Smoke particles](https://kenney.nl/assets/smoke-particles)
- Other packs that turned up in search (licences not checked here): the Brackeys VFX Bundle on itch.io and OpenGameArt "smoke particle assets". OpenGameArt blocked the fetch. — [itch.io: Brackeys VFX Bundle](https://brackeysgames.itch.io/brackeys-vfx-bundle); [OpenGameArt: smoke particle assets](https://opengameart.org/content/smoke-particle-assets)
- DevForum flipbook giveaways and plugins with large libraries exist ("2 Free Realistic Flipbook Particle Explosions"; an "Advanced VFX Plugin" claiming 10,000+ assets). These are noted in the earlier pipeline notes. — [DevForum: 2 Free Flipbook Explosions](https://devforum.roblox.com/t/2-free-realistic-flipbook-particle-explosions/3035597)
- Effect Designer Suite calls the plugin open source, but says nothing about the licence of its included assets. — [DevForum: Effect Designer Suite](https://devforum.roblox.com/t/effect-designer-suite-%E2%80%94-vfx-tooling-assets-and-more/4754553)

### Inferences
- **[S] Rule for this repo:** generate our own art with Python (§1). If a pack is ever used, keep only CC0 (Kenney), store the zip and its licence file in `design/`, and record the source in the game's notes. Never take textures from Toolbox models or other games: the licence is unclear and it breaks CLAUDE.md's "we make our own art".
- **[S] Marketplace risks to tell the owner about:** unclear rights, assets that get moderated or deleted later (breaking the effect), hidden scripts in Toolbox models, and the look matching other games, which is the opposite of "our own".

### Gaps
- I couldn't fetch the Brackeys or OpenGameArt licence pages, so their licences aren't confirmed.
- I found no Roblox statement on what licence Creator Store "free" assets carry for reuse outside the original model.

## 5. Uploading and organising many textures (asset IDs, Open Cloud), and a batch path for a non-coder owner

### Takeaway
There are two paths. (a) The owner uploads by hand in Studio, through Asset Manager's bulk import or the Creator Dashboard, and pastes back the IDs. (b) A script path uses the **Open Cloud Assets API**, best through **Asphalt** (an MIT CLI): it uploads a folder, writes a lock file and generates a Luau module of IDs. Path (b) needs an API key made by the owner and must run on the owner's Mac, because this cloud session can't reach apis.roblox.com.

### Cited Findings
- Open Cloud: `POST https://apis.roblox.com/assets/v1/assets` (multipart: a JSON `request` with assetType Decal or Image, displayName, description and creationContext.creator.userId or groupId, plus `fileContent`).
  - It returns an operation. Poll `GET /assets/v1/operations/{id}` until `done`, then read `assetId` and `moderationResult.moderationState` (for example MODERATION_STATE_APPROVED).
  - The API key needs Assets access with Read and Write; OAuth uses `asset:read` and `asset:write`.
  - One asset per call, up to 20 MB. Updating an existing Decal or Image is not supported.
  - — [Creator Docs: Assets usage guide](https://create.roblox.com/docs/en-us/cloud/guides/usage-assets)
- **Asphalt** (MIT):
  - `asphalt.toml` sets the creator (user or group plus id), inputs (a path glob plus output_path for generated code) and codegen options (Luau or TypeScript, flat or nested, Content output).
  - `asphalt sync` uploads to the cloud and writes `asphalt.lock.toml` to commit to git.
  - Images are alpha-bled by default. Auth is `--api-key` or `ASPHALT_API_KEY`.
  - It also has `studio` and `debug` targets that sync locally for testing.
  - — [GitHub: jackTabsCode/asphalt](https://github.com/jackTabsCode/asphalt)
- A Python wrapper, `rblx-open-cloud`, includes an assets upload example. — [GitHub: rblx-open-cloud assets example](https://github.com/TreeBen77/rblx-open-cloud/blob/main/examples/assets.py); [PyPI: rblx-open-cloud](https://pypi.org/project/rblx-open-cloud)
- Studio's Asset Manager has a Bulk Import button (a 2025 bug thread exists). A 2020 thread asks how to bring in 1000+ images without naming each one by hand, and its fetched copy showed no answer. — [DevForum: Bulk Import button doesn't work](https://devforum.roblox.com/t/bulk-import-button-doesnt-work-on-asset-manager/3517906); [DevForum: Bulk importing images](https://devforum.roblox.com/t/bulk-importing-images/566651)
- This repo's rule: cloud sessions can't reach apis.roblox.com, so they can't upload. The owner uploads sounds and images and sends back the IDs. — `/home/user/roblox/CLAUDE.md` (Repo mechanics)

### Inferences
- **[S] The easiest batch path for the owner (no code):**
  1. We commit the PNGs to `<game>/art/vfx/` with names that say what they are (for example `vfx_ring_soft_512.png`).
  2. The owner opens Studio > Asset Manager > Bulk Import and selects them all.
  3. The owner runs a Command Bar helper we ship. It lists the new Images and their IDs and prints `[VFXIDS] name=id` lines to Output.
  4. The owner pastes those lines back, and we write them into an `Ids.luau` module.
- **[S] Power path, if the owner is willing:**
  1. The owner makes one Open Cloud API key (Assets read and write, their user or group) on the Creator Dashboard.
  2. On the Mac, they run one copy-paste line: `asphalt sync` with the key in an environment variable.
  3. Asphalt uploads everything, writes the lock file and generates the ID module. GitHub Desktop commits the lock file.
  4. Never commit the API key.
- **[S] Organising:**
  - One texture per job, reused across emitters (the docs say reuse is cheaper).
  - Names follow the CLAUDE.md kit-naming rule.
  - Keep a manifest (`vfx_textures.json`: name, size, grid, intended LightEmission, ID or 0).
  - Unknown IDs stay 0 with a note, as CLAUDE.md requires.

### Gaps
- I couldn't confirm the current Asset Manager Bulk Import steps, file-count limits, or how to copy many IDs at once from a 2026 Roblox source.
- The Open Cloud page doesn't state rate limits or daily upload caps for images.
- I didn't check whether a group-owned upload needs extra group permissions on the key beyond the creator field.
