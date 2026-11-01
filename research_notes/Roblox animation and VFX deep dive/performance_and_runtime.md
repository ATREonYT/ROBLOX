# Roblox VFX performance budgets and runtime VFX systems

Researched 2026-10-31. "Cited" means it came from a page fetched in this session. "Suggested" means it is our own recommendation or a known formula that was not re-checked against a source this session. Several Creator Docs reference pages (ParticleEmitter, Workspace, Highlight class) loaded with very little descriptive text, so some of the official wording could not be checked.

## 1. Measured costs and device budgets (particles, beams, trails, lights, Highlights, transparency, shadows, quality scaling)

### Takeaway
The most useful hard budget comes from a guest article in the Roblox Staff section: keep the scene at about 500 draw calls and 500k triangles, UI under about 150 draw calls, and client memory under 1.3 GB for 2 GB phones. Each ParticleEmitter or Beam costs one draw call however many particles it emits. Use a few emitters that each emit many particles, not many emitters. The often-quoted "31 Highlights" limit is out of date: the current Creator Docs say 255.

### Cited Findings
**Draw-call and scene budgets** (from an article by Peter "MrChickenRocket" McNeill, published in the Roblox Staff section with help from Roblox staff, mid-2024)
- Scene budgets: "500,000 triangle budget" and "500 drawcall budget" in scene. Worry about UI if it goes "over about 150 drawcalls." — [Real world building and scripting optimization](https://devforum.roblox.com/t/real-world-building-and-scripting-optimization-for-roblox/3127146)
- Example split: 300 draw calls fixed for the map and 200 flexible for players, pets, coins and effects. Each zone budget was 40k triangles and 40 draw calls. — same source
- Target devices: the demo "runs on most phones at graphics quality 10 at 60 FPS". The numbers aim at "most (90%+)" of phones. — same source
- Emitter cost: "all particle emitters take one drawcall each … If you have 40 particle emitters on screen, that's 40 drawcalls, regardless of if they emit a lot of particles or not." Also: "Beams and particle effects all cost 1 drawcall each." — same source
- "Transparent objects via Part.Transparency can cause unexpected extra drawcalls". "SurfaceGuis and BillboardGuis can chew up drawcalls very quickly". Each unique Texture or Decal ID counts as its own material. — same source
- Memory and network: aim for "< 1.3GB client memory usage in order to support 2 GB phones" and "under 50KB/s network receive." Each moving physics object costs about 0.4–0.9 KB/s, so keep to roughly 40–60 moving assemblies. — same source
- Lights: "Be conservative of your use of extra shadow casting lights in Future". Keep each light's area small, and "Small lights tends to be fine." ShadowMap is "a touch more performant, especially on phones." — same source
- Culling: detail objects are removed beyond 300 studs from the camera. The culling manager makes at most 50 checks per frame. — same source
- A community tutorial repeats the target: keep "Scene Draw Count" (Ctrl+Shift+F2) "under 500." Each emitter is one draw call even when emitters share a texture, and far-away particles should be turned off with a distance check. — [Optimization Guide (Curs1der)](https://devforum.roblox.com/t/tutorial-roblox-optimization-guide-memory-draw-calls-and-network-tips/3881861)

**Official Creator Docs (Improve performance page)**
- "Objects like decals, textures, and particles don't batch well and introduce additional draw calls." Also: "property changes to ParticleEmitters can have a dramatic impact on performance." — [Creator Docs: Improve performance](https://create.roblox.com/docs/performance-optimization/improve)
- Lights: turn off `Light.Shadows` where they are not needed, "Limit the range and angle of light instances," "Use fewer light instances," and switch off lights outside a set range. — same source
- Shadows: "Handling shadows is an expensive process". The engine scales shadows down, "eventually disabling shadows altogether at quality levels below 4." Turn off shadows on moving objects when possible. — same source
- Transparency: layered transparency "forces the engine to render the overlapping pixels multiple times" (overdraw). — same source
- Profiling: use Render Stats > Timing (Shift+F2 in the client). The MicroProfiler scope `Perform/Scene/computeLightingPerform` covers "Light grid and shadow updates." — same source
- Textures: "a 1024x1024 pixel texture consumes four times the graphics memory of a 512x512". Most images need at most 512², and minor images should be under 256². — same source
- Effects pattern: "The server only needs to know the location … while the clients can create visuals locally." — same source

**Highlights**
- Current limit: "Studio only displays 255 simultaneous Highlight instances on the client-side at a time". Highlights past the limit are ignored silently, and disabled highlights still take a slot. — [Creator Docs: Highlighting](https://create.roblox.com/docs/effects/highlighting)
- Cost: the first highlight carries most of the cost, and later ones have no "significant performance impact on any platform." Adding or removing a highlight can trigger a geometry rebuild (a spike), while changing its properties is cheap. On mobile the cost grows with how much of the screen it covers. Disabled or fully transparent highlights cost nothing when off screen. Delete a highlight rather than disabling it, and avoid nesting highlighted objects. — same source
- History: in Oct 2022 the cap was "31 Highlight adorns active at a time". Users linked it to older mobile rendering. That thread has no staff reply or date for the raise. — [Raise limit on Highlights](https://devforum.roblox.com/t/raise-limit-on-the-number-of-active-highlights/2005711). The docs number (255) is newer and is the one to trust. It is unclear whether old low-end mobile paths still cap at 31.

**Automatic quality scaling**
- The graphics level "automatically reduces particle rates and beam segments." One example: a splash emitter at Rate 30 shows about 15 particles at maximum graphics but about 1 at minimum. There was no staff reply. — [Allow us to disable VFX scaling](https://devforum.roblox.com/t/allow-us-to-disable-vfx-scaling-with-graphics-level/2301568)
- The engine also throttles Rate by distance and has a hard cut-off distance. `UserSettings().GameSettings.SavedQualityLevel` reads 0 when the player uses Automatic (1–10 are manual), and a client cannot read the level Automatic actually picked. — [Bypassing Particle LOD Rate Throttle](https://devforum.roblox.com/t/bypassing-particle-lod-rate-throttle/2446042)
- `ParticleEmitter:Emit(particleCount)` defaults to 16. — [ParticleEmitter API](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter)

### Inferences
- Suggested phone budget for effects: about 200 of the 500 scene draw calls for everything dynamic. A single big moment (a cannon shot, a level-up) should use no more than about 8–12 emitters and beams, and the whole screen should rarely go past about 30 active emitters.
- Suggested: burst moments should use `Emit(n)` (one-shot) on 1–3 emitters with high counts rather than many emitters with Rate > 0. Short Lifetime keeps overdraw down.
- Suggested: use PointLights in effects without shadows (`Shadows = false`) and with a small Range, and delete them when the effect ends. Neon plus Bloom is cheaper than real lights for "glow".
- Suggested: one Highlight per rarity pickup is fine. Create it once and toggle Transparency, because adding and removing it causes rebuild spikes.
- Suggested: do not fully bypass the engine's particle throttling. Small essential feedback (a hit spark) can be emitted with `Emit()` so it survives low quality, while ambient rate emitters should be left to scale.

### Gaps
- No official per-device ms numbers for particles, beams or trails. No trail cost found (the guest article does not mention Trails).
- The size of the cost of Neon or Bloom on mobile was not found.
- No official percentage for how much particles drop at each quality level.
- The MicroProfiler label names for particles were not checked this session.

## 2. Pooling and cleanup (pools, cloning cost, Debris vs task.delay, PartCache)

### Takeaway
Pool anything that spawns often (projectiles, impact parts). Move pooled parts with CFrame instead of reparenting or recreating them. For one-off cleanup, `task.delay(t, inst.Destroy, inst)` is the community-preferred choice over `Debris:AddItem`.

### Cited Findings
- How PartCache works: it keeps parts in the workspace and moves them by CFrame, because "CFrame is the only property you can update every frame without heavy code kicking in". Reparenting is slower. — [PartCache thread](https://devforum.roblox.com/t/partcache-for-all-your-quick-part-creation-needs/246641)
- PartCache API: `.new(template, precreatedParts=5)`, `:GetPart()` (warns and grows when empty), `:ReturnPart(part)`, `:SetCacheParent(parent)` (must be under Workspace) and `:Dispose()`. `DestroyPart` is deprecated. The thread does not state a licence. — same source
- PartCache measured numbers (pobammer, MicroProfiler, 2019): FIRE 0.114 ms with the cache vs 0.139 ms without, and ON_RAY_HIT 0.007 vs 0.014 ms. — same source
- Alternatives named in the thread: ObjectCache, Cacher, Recycler, SimpleCast. — same source; also [Cacher](https://devforum.roblox.com/t/cacher-a-cache-module-for-instances/3626420)
- Official advice: "Instead of destroying an NPC completely, send the NPC to a pool of inactive NPCs". Creating instances "can be intensive for the engine to process". Creating and destroying large hierarchies at runtime "can be very network intensive." — [Creator Docs: Improve performance](https://create.roblox.com/docs/performance-optimization/improve)
- Debris vs task.delay: community answers recommend `task.delay`. A user benchmark with 1,000 parts found "task.delay is significantly faster!", but its figures are only in an image. Claims that Debris leaks memory come without evidence. There is no staff answer. — [Debris or task.delay thread](https://devforum.roblox.com/t/hello-ive-been-wondering-if-its-better-to-use-debrisadditem-or-taskdelay/2997135)

### Inferences
- Suggested: a pool per effect template. Clone N copies at start, and on use set the CFrame, enable or emit, then return the copy after its longest Lifetime. Return parts to a far CFrame (or `Parent = nil` for non-parts). Batch moves with `workspace:BulkMoveTo`.
- Suggested: for pooled emitters call `:Clear()` before reuse, and avoid changing many emitter properties every frame (see the docs' warning about property changes).

### Gaps
- No official clone cost in microseconds. PartCache's licence is not stated.

## 3. Runtime VFX modules (templates, Emit helper and attributes, open source, replication)

### Takeaway
The common pattern: build effects in Studio as Attachment and Emitter templates in ReplicatedStorage, tag each emitter with `EmitCount`, `EmitDelay` and `EmitDuration` attributes, and have one client-side `Emit(effect)` helper read them. The server fires one remote with the effect name, the position and `GetServerTimeNow()`, and each client clones, plays and culls the effect locally.

### Cited Findings
- VFX Forge's attribute convention: **EmitCount** is "The amount of times a particle or an effect is emitted"; **EmitDelay** is "The amount of seconds waited before the effect is emitted"; **EmitDuration** is documented ambiguously ("seconds the effect is delayed by"). Curves exist for Transparency, Size, Squash and TimeScale. — [Forge docs: particle](https://zilibobi.github.io/forge-docs/effects/particle)
- VFX Forge at runtime: an "Emit Module for games" with `.init()` then `.emit(model)`. A reviewer's example clones the model, calls `PivotTo`, parents it to workspace, calls `shared.vfx.emit(...)`, and destroys it after 2 s. v2 is whitelisted and obfuscated. A reviewer mentions paying about $15. No licence is stated. — [VFX Forge thread](https://devforum.roblox.com/t/plugin-vfx-forge-an-advanced-custom-vfx-system/3867553)
- Other tools with attribute or emit conventions: [VFXer plugin attributes](https://vfxer.gitbook.io/plugin/attributes.md), [VFXer GameModule](https://vfxer.gitbook.io/plugin/module), [rParticle (GitHub, AlexR32)](https://github.com/AlexR32/rParticle) (a UI particle emitter), [Effect Designer Suite](https://devforum.roblox.com/t/effect-designer-suite-%E2%80%94-vfx-tooling-assets-and-more/4754553). The attribute pages were not opened this session.
- Server and client split: let the server decide the outcome and the clients make the visuals. — [Creator Docs: Improve performance](https://create.roblox.com/docs/performance-optimization/improve). The guest article clones coins and pets locally when an event arrives. — [MrChickenRocket](https://devforum.roblox.com/t/real-world-building-and-scripting-optimization-for-roblox/3127146)
- `GetServerTimeNow` accuracy (community only, no staff): "accurate down to a few milliseconds" with "a few milliseconds of variation across clients". One user warns that differences of about 50 ms can matter for projectiles. It is not a live request on each call. — [How accurate is GetServerTimeNow](https://devforum.roblox.com/t/about-how-accurate-is-getservertimenow/3926695)

### Inferences (suggested design for our games)
- Folder: `ReplicatedStorage.VFX.<EffectName>`, a Model or Attachment holding emitters, beams and lights, with attributes per emitter: `EmitCount` (number, default 1 burst of Emit), `EmitDelay` (seconds), `EmitDuration` (seconds of enabling Rate > 0, 0 = burst only). This copies the VFX Forge names, so effects made in that plugin play the same way.
- Helper sketch: for each descendant ParticleEmitter, `task.delay(EmitDelay, function() if EmitDuration > 0 then e.Enabled = true; task.delay(EmitDuration, function() e.Enabled = false end) else e:Emit(EmitCount) end end)`. Clean up after `maxDelay + maxDuration + maxLifetime`.
- Replication: the server sends `FireAllClients("CannonShot", pos, dir, serverTime)`. The client skips the effect if the camera is more than about 300 studs away (the guest article's culling distance) and fast-forwards the start by `GetServerTimeNow() - serverTime`.
- Respect reduced motion or flash settings inside the helper (see section 5).

### Gaps
- No well-known MIT-licensed GitHub "Emit module" was confirmed this session. VFX Forge is closed-source. Licences for VFXer and others were not checked.

## 4. Projectile systems (FastCast, client prediction, arcs and landing prediction for a cannon)

### Takeaway
Visual projectiles should be simulated on the client, not with server physics. FastCast (no longer maintained) and its continuation FastCast2 are the standard. For a kid cannon, a closed-form ballistic arc computed on each client from (origin, velocity, serverTime) is simpler and enough.

### Cited Findings
- FastCast2 is "designed to simulate thousands of projectiles without relying on physics replication". FastCast is "no longer actively maintained by EtiTheSpirit". FastCast2 has parallel Luau (`FastCast2.newParallel()`) and a built-in ObjectCache (500 parts pre-allocated by default). The API is `FastCast2.new()`, `Caster:Init("BulkMoveTo", false)`, `behavior.CosmeticBulletTemplate` / `CosmeticBulletContainer`, and `Caster:RaycastFire(origin, dir, speed, behavior)` (also Blockcast and Spherecast). It is described as open source, but no licence is named. — [FastCast2 docs](https://weenachuangkud.github.io/FastCast2)
- Original FastCast docs and thread (a "Cosmetic Bullet system"): [FastCast API docs](https://etithespir.it/FastCastAPIDocs), [FastCast DevForum thread](https://devforum.roblox.com/t/133474). Xan said the PartCache idea was later added into FastCast. — [PartCache thread](https://devforum.roblox.com/t/partcache-for-all-your-quick-part-creation-needs/246641)
- Community advice: the server owns the outcome and clients only play the A-to-B animation. — [GetServerTimeNow thread](https://devforum.roblox.com/t/about-how-accurate-is-getservertimenow/3926695)

### Inferences (suggested; standard physics, not re-cited)
- Arc: `p(t) = p0 + v0*t + 0.5*g*t^2`, with `g = Vector3.new(0, -workspace.Gravity, 0)` (the default Gravity is 196.2 studs/s², from memory and not re-checked).
- Landing prediction on flat ground at height y: solve `0.5*g*t^2 + v0.y*t + (p0.y - y) = 0` and take the larger root. Show a landing marker (a decal ring) at `p(t_land)`.
- Preview arc line: sample 20–30 points and draw them with one Beam chain or a few Attachments. Use one Beam rather than many parts (each Beam is one draw call).
- Client prediction for the local player: start the shot animation immediately on input, send it to the server, and let the server confirm the result. Other players see it through the remote with a serverTime offset.

### Gaps
- No licence confirmed for FastCast or FastCast2. No RDC talk on projectiles was found this session.

## 5. Accessibility (reduce motion, flashes, shake)

### Takeaway
Roblox exposes `GuiService.ReducedMotionEnabled` and `GuiService.PreferredTransparency` (announced Nov 29, 2023). There is no built-in "reduce flashes" or "camera shake" setting, so games add their own toggle and combine it with ReducedMotion.

### Cited Findings
- Settings: Reduce Motion is `GuiService.ReducedMotionEnabled`, and Background Transparency is `GuiService.PreferredTransparency` (the inverse of the app value: near 0 means more opaque). Listen with `GetPropertyChangedSignal`. — [Introducing Accessibility Settings](https://devforum.roblox.com/t/introducing-accessibility-settings/2723187)
- Official guidance: with reduced motion, replace fly-in animations with a fade or an instant transition, and stop looping motion or replace it with in-place effects. Multiply the default background transparency by PreferredTransparency. — same source
- API reference: [GuiService](https://create.roblox.com/docs/reference/engine/classes/GuiService)

### Inferences (suggested wiring)
- One `Settings` module on the client: `reduceMotion = GuiService.ReducedMotionEnabled or playerToggle`. When it is on, camera shake goes to 0, screen punch and zoom go to 0, UI pops become fades, and particle counts go to about 50%.
- Flash limit: the project rule allows at most 1 flash per second. Enforce it centrally in the Emit helper (a timestamp gate on any full-screen flash or white frame), and also skip flashes when reduceMotion is on.
- Combine with quality scaling: when `SavedQualityLevel` is between 1 and 3, scale `EmitCount` down. Treat 0 (Automatic) as "trust the engine".

### Gaps
- No official Roblox photosensitivity setting found. No API exposes the level Automatic graphics quality chose (per a community thread).
