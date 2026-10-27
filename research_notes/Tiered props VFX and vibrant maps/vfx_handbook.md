# Roblox VFX Handbook for "Hood" (2025–2026): ParticleEmitters, Beams/Trails, glow tools, art principles, textures, tiered recipes, performance

**How to read these notes**
- **Primary sources:**
  - The Roblox Creator Docs GitHub mirror, `Roblox/creator-docs`, cloned at commit `9f840b1` (2026-10-02). Docs URLs below are the live create.roblox.com equivalents.
  - The live engine API dump: `Full-API-Dump.json` in `MaximumADHD/Roblox-Client-Tracker`, commit dated 2026-09-29. It gives exact defaults, deprecation tags and security levels.
- **Blocked sites:** devforum.roblox.com, 80.lv, vfxapprentice.com and nexus.leagueoflegends.com were blocked by the egress proxy. Claims from them come from **search-result summaries only** and are marked **(search summary)**.
- **Inferences:** everything in an "Inferences" block is my own recommendation or untested starting values for Hood, not sourced fact.
- **Overlap:** the earlier note `research_notes/Cartoony Roblox building UI and animation/animation_and_vfx.md` §7 already covers the basics. This handbook goes deeper and fills that note's gaps:
  - `Explosion` status;
  - built-in textures;
  - quality scaling;
  - GUI and mesh glows;
  - the 8-tier ladder.

---

## 1. ParticleEmitter in depth: every important property, the Emit() burst pattern, attachments as emitters, limits

### Takeaway
A `ParticleEmitter` draws 2D textured quads. Almost every good effect comes from shaping four `NumberSequence`/`ColorSequence` curves over lifetime:
- **Size**
- **Transparency**
- **Color**
- **Squash**

Three more property groups do the rest of the work:
- **Motion:** `Speed`, `Drag`, `Acceleration`.
- **Blend:** `LightEmission` (additive) versus `LightInfluence` (scene lighting).
- **Spawn:** Attachment versus part, `Shape*` and `SpreadAngle`.

Use `Enabled`/`Rate` for continuous ambience and `:Emit(n)` on disabled emitters for bursts.

Gotchas that matter for Hood, which builds VFX in code:
- `Instance.new` gives `LightInfluence = 0`, but Studio insertion gives 1.
- `VelocitySpread` is deprecated.
- `FastForward()` is not callable by game scripts.
- Lifetime is capped at 20 s.
- Rate is capped at 400/s per emitter (100/s on mobile).

### Cited Findings

**What the emitter does and where particles spawn**
- A ParticleEmitter must be parented to a `BasePart` or to an `Attachment` inside one.
  - Parented to a BasePart, particles spawn randomly within the part's bounding box or shape.
  - Parented to an Attachment, they spawn from the attachment's position.
  - Particles emit automatically when `Enabled` with a non-zero `Rate`, or manually through `Emit()`.
  - Source: [Roblox API: ParticleEmitter](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter)
- On an Attachment you can rotate the attachment instead of using `EmissionDirection`. The **Sphere and Cylinder shapes "will not display correctly"** when the emitter is parented to an Attachment; use them only on BaseParts. — [Roblox Docs: Particle emitters](https://create.roblox.com/docs/effects/particle-emitters)

**Engine defaults** (what `Instance.new("ParticleEmitter")` gives you), from the API dump — [Roblox-Client-Tracker Full-API-Dump.json](https://github.com/MaximumADHD/Roblox-Client-Tracker)

| Property | Default |
|---|---|
| Texture | `rbxasset://textures/particles/sparkles_main.dds` |
| Rate | 20 |
| Lifetime | 5–10 |
| Speed | 5 |
| SpreadAngle | (0, 0) |
| Size | 1 |
| Transparency | 0 |
| Squash | 0 |
| LightEmission | 0 |
| LightInfluence | 0 |
| Brightness | 1 |
| Drag | 0 |
| Acceleration | (0, 0, 0) |
| Orientation | FacingCamera |
| Shape / ShapeStyle / ShapeInOut / ShapePartial | Box / Volume / Outward / 1 |
| EmissionDirection | Top |
| FlipbookLayout / FlipbookMode | None / Loop |
| FlipbookFramerate | 1 |
| FlipbookBlendFrames | true |
| TimeScale | 1 |
| VelocityInheritance | 0 |
| WindAffectsDrag | false |
| ZOffset | 0 |
| `Emit(particleCount)` | default count 16 |

- **LightInfluence depends on how the emitter was inserted:** "By default, this value is 1 if inserted with Studio tools. If inserted using `Instance.new()`, it is 0." — [Roblox API: ParticleEmitter](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter)

**Deprecated or restricted members**

| Member | Status | Source |
|---|---|---|
| `VelocitySpread` | Tagged `Deprecated` and `NotReplicated`: "superseded by `SpreadAngle` which should be used in all new work" | [Roblox API: ParticleEmitter](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter); API dump |
| `FastForward(numFrames)` | Exists, but its security is `RobloxScriptSecurity`, so game scripts cannot call it | API dump, [Client Tracker](https://github.com/MaximumADHD/Roblox-Client-Tracker) |
| `TextureContent` (type `Content`) | New equivalent of `Texture` that supports asset URIs; assigning it updates `Texture`. Beam and Trail have the same pair. | [Roblox API: ParticleEmitter](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter) |
| `LocalTransparencyModifier` | Hidden, client-only multiplier. A value of 1 hides the particles for that client only. | [Roblox API: ParticleEmitter](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter) |

**Property reference (what each property is for)**

Sources: [API](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter) and [guide](https://create.roblox.com/docs/effects/particle-emitters).

| Property | Behaviour per docs |
|---|---|
| **Texture** | Image on each particle. Use PNG with a transparent background. "If your texture is grayscale with no alpha channel, try setting … LightEmission to 1 to hide the darker regions." |
| **Color** (ColorSequence) | Tints the texture; interpolated by age ÷ lifetime. "If an emitter has a LightEmission value that's greater than 0, darker colors make particles appear more transparent." Changes affect current and future particles. |
| **Size** (NumberSequence) | World size of the square quad over lifetime. Non-zero **envelopes** pick a random value per keypoint per particle. Warning: large particles cost **fill-rate**. |
| **Transparency** (NumberSequence) | 0 is opaque, 1 is invisible. "One of the most vital properties": fading near the start and/or end "avoids a popping in/out effect". |
| **Squash** (NumberSequence) | Non-uniform scale over lifetime. Above 0, particles get thinner and taller; below 0, wider and shorter. |
| **LightEmission** | 0 is normal blending, 1 is **additive**. It does *not* light the world (use a PointLight for that). |
| **LightInfluence** | 0–1: how much scene lighting tints particles. At 1, particles in darkness turn black. |
| **Brightness** | "Scales the light emitted from the emitter when LightInfluence is 0." |
| **ZOffset** | Shifts render depth in studs (fractional allowed) without changing on-screen size. Positive is toward the camera. Use it to layer emitters or to push particles in front of or behind the parent. |
| **Lifetime** (NumberRange) | Per-particle random age. **Capped at 20 s.** A value of 0 prevents emission. |
| **Rate** | Particles per second while Enabled. "Up to **400 particles per second (100 per second on mobile)**" per emitter. |
| **Speed** (NumberRange) | Initial studs/s along EmissionDirection. Negative values reverse it. Changing it doesn't affect live particles. |
| **SpreadAngle** (Vector2) | Random cone around EmissionDirection on the X/Z axes. 360 on one axis gives a circle; 360 on both gives a sphere. (180, 180) emits "in every direction" ([basic tutorial](https://create.roblox.com/docs/tutorials/use-case-tutorials/vfx/basic-particle-effects)). |
| **EmissionDirection** | Face (NormalId) of the parent to emit from. On attachments, rotate the attachment instead. |
| **Shape** | Box / Sphere / Cylinder / Disc. **ShapeStyle**: Volume or Surface. **ShapeInOut**: Outward, Inward, or InAndOut. |
| **ShapePartial** | Cylinder: top-radius proportion (0 makes a cone). Disc: inner-radius proportion (1 emits only from the outer rim). Sphere: hemispherical angle (0.5 is a half-dome). |
| **Acceleration** (Vector3) | World-space studs/s². Affects current and future particles; use it for gravity and drift. |
| **Drag** | "Rate in seconds at which individual particles will lose half their speed via exponential decay". Negative values accelerate. |
| **VelocityInheritance** | 0–1 fraction of the parent part's velocity. Combine with Drag to make a moving part "shed" particles. |
| **LockedToPart** | Live particles move rigidly with the parent. |
| **Orientation** | FacingCamera (default billboard), FacingCameraWorldUp (yaws only around world Y), VelocityParallel (aligned to motion), VelocityPerpendicular (perpendicular to motion). Enum confirmed in the API dump. |
| **Rotation / RotSpeed** (NumberRange) | Initial angle and deg/s; commonly `[0, 360]` for random rotation. Very high RotSpeed can alias to no visible rotation. |
| **TimeScale** | 0–1 simulation speed. 0 freezes particles, which is handy for hit-stop. |
| **WindAffectsDrag** | Particles follow `Workspace.GlobalWind` only if `Drag > 0`. |
| **Enabled** | `false` stops new spawns; existing particles live out their lifetime. `Clear()` removes them instantly. |

**Flipbooks** — [Roblox Docs: Particle emitters](https://create.roblox.com/docs/effects/particle-emitters); [Roblox API: ParticleEmitter](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter)
- `FlipbookLayout` is one of:
  - None;
  - Grid2x2 (4 frames);
  - Grid4x4 (16 frames);
  - Grid8x8 (64 frames);
  - Custom, using `FlipbookSizeX` (columns) and `FlipbookSizeY` (rows).
- `FlipbookFramerate` is a min/max range, **max 30 fps**.
- `FlipbookMode` options:
  - Loop.
  - OneShot: the framerate is ignored and the animation spans the particle's lifetime ("useful for … an explosion that creates a puff of smoke and then fades out").
  - PingPong.
  - Random: crossfades between random frames ("stars slowly twinkling").
- `FlipbookStartRandom`: with Framerate 0, each particle shows "a static frame chosen randomly from the flipbook texture". This is a way to get variety from one emitter.
- `FlipbookBlendFrames` (default true) chooses between a linear crossfade and an instant swap.
- **Spacing:** "include spacing between each of the particle frames. In some cases, mip filtering might require even more spacing."
- **Memory:** "clients automatically deactivate flipbooks when they are low on memory, which is likely for older mobile phones… Reusing textures costs less memory than using unique textures."

**Flipbook texture-size rules conflict across sources**
- The API says the flipbook texture size "must be an exact multiple of the flipbook layout size" — [API](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter).
- The engine's built-in default error string still reads "Particle texture must be 1024 by 1024 to use flipbooks." — API dump, `FlipbookIncompatible` default.
- Search summaries say Roblox later loosened the original 1024² requirement to "any resolution that is squared and a power of two (minimum 8x8 and maximum 1024x1024)". They also say a Custom-layout client beta followed. — [DevForum: Particles' Flipbook Release](https://devforum.roblox.com/t/particles%E2%80%99-flipbook-release/2029388); [DevForum: Custom flipbook layouts beta](https://devforum.roblox.com/t/client-beta-optimize-your-particle-animations-with-custom-flipbook-layouts/4005128) **(search summary)**

**Emit and cleanup patterns**
- In the official burst recipe, the emitter has **Enabled off** and the script calls `particleEmitter:Emit(EMIT_AMOUNT)` with `EMIT_AMOUNT = 100`. Roblox also publishes an "Emit() plugin" for testing bursts in Studio. — [Roblox Docs: Create explosions with VFX](https://create.roblox.com/docs/tutorials/use-case-tutorials/vfx/use-particles-for-explosions)
- `Emit()` doesn't yield. Destroying the emitter's parent right after `Emit()` removes the particles before they render. — [DevForum: Issues with ParticleEmitter:Emit()](https://devforum.roblox.com/t/issues-with-particleemitteremit/3325717) **(search summary)**
- `Debris:AddItem(obj, t)` destroys without yielding and runs even if the calling script is destroyed. It has a **hardcoded 1,000-item cap**: past that, the oldest items are destroyed early. `Debris.MaxItems` is deprecated. — [Roblox API: Debris](https://create.roblox.com/docs/reference/engine/classes/Debris)

**Official reference recipes with exact values**

| Recipe | Values | Source |
|---|---|---|
| Gold sparkle | MeshPart Neon `255,180,0`. Emitter: Color `255,200,50`, Lifetime 0.5–1, Rate 7, Speed 2–3, SpreadAngle 180,180, Size 0.3, LightEmission 1, Transparency 0.5, Drag 1.5. Optional PointLight. | [Basic particle effects](https://create.roblox.com/docs/tutorials/use-case-tutorials/vfx/basic-particle-effects) |
| Smoke plume | Texture `rbxassetid://3845808160` (soft-edged circle), Transparency 0→1, Size 3→10, Color orange → dark grey → white, Acceleration (2, 2, 0), Rate 40 | [Custom particle effects](https://create.roblox.com/docs/tutorials/use-case-tutorials/vfx/custom-particle-effects) |
| Electric burst | Texture `rbxassetid://6101261905` (spark), Drag 10, Lifetime 0.2–0.6, Speed 20–40, SpreadAngle 180,180, Emit 100 | [Create explosions with VFX](https://create.roblox.com/docs/tutorials/use-case-tutorials/vfx/use-particles-for-explosions) |
| Flare | Texture `rbxassetid://8983307836`, Color `127,84,59`, LightEmission 1, ZOffset 1, Lifetime 10, Rate 0.45, RotSpeed 20, Speed 0, Size 0 → slow grow → 10 (held), Transparency near 0 then "bounces" to 1. Sibling PointLight Brightness 2, Range 36. | [Core curriculum: Create basic visual effects](https://create.roblox.com/docs/tutorials/curriculums/core/building/create-basic-visual-effects) |
| Dust motes | Huge invisible volume part `645×355×275`. Texture `rbxassetid://14302399641`, Color `192,241,255`, ZOffset −5 (renders behind players), Lifetime 1–10, **Rate 50000**, Rotation −45..45, RotSpeed −60, Speed 1–5, Acceleration (1, −1, 1), Size up to ~0.25 then down to 0, Transparency fading in and out with envelope ~0.1 | same |

- **Conflict:** the dust-motes Rate of 50000 contradicts the guide's stated 400/s per-emitter cap. Either the cap isn't applied as written, or the tutorial relies on clamping. Treat both numbers cautiously. — [Particle emitters guide](https://create.roblox.com/docs/effects/particle-emitters) vs [Core curriculum](https://create.roblox.com/docs/tutorials/curriculums/core/building/create-basic-visual-effects)
- **Squash for rain** (Roblox's own showcase): "A Squash value of 3 starts to stretch the texture longer… 20 stretches the particles much longer, but we also needed to increase the Size value too." Because of the particle count limit they used several same-size emitter volumes in a grid instead of one huge one. — [The Mystery of Duvall Drive: Develop a moving world](https://create.roblox.com/docs/resources/the-mystery-of-duvall-drive/develop-a-moving-world)
- **Ground orientation:** for particle effects on the ground, set Orientation to VelocityPerpendicular. A ring-shaped burst can come from `:Emit()` with SpreadAngle X = 360. — [DevForum: confetti/Orientation threads](https://devforum.roblox.com/t/what-does-particleemitterorientation-do/1478211); [DevForum: shockwave with ParticleEmitters](https://devforum.roblox.com/t/how-can-i-create-a-shockwave-effect-with-particleemitters/2789227) **(search summary)**
- **Quality-level testing:** the guide says to check particles at the lowest and highest **Editor Quality Level** in Studio Settings before shipping. — [Particle emitters guide](https://create.roblox.com/docs/effects/particle-emitters)

### Inferences

**Practical meaning of each property for Hood**
- **Lifetime and timing:**
  - Impacts should live **0.1–0.4 s**.
  - Dust and smoke: 0.5–2 s.
  - Ambient motes: 1–4 s.
- **Speed, Drag and Acceleration:** high `Speed` with high `Drag` (8–12) gives the snappy "explode then hang" feel. `Acceleration` Y between −20 and −60 gives cartoony gravity arcs for coins, confetti and debris.
- **Count:** `Rate × average Lifetime` ≈ live particles per emitter. Budget with this number (see §7).
- **LightEmission choice:**
  - Use `LightEmission = 1` for glows, sparks and energy.
  - Use `0` for dust, smoke, confetti and debris.
  - Additive particles wash out against bright daytime skies and pale walls (darker colours become more transparent). Cartoony daylight readability therefore needs some **non-additive solid shapes**: a coloured ring, solid stars or dark-outlined confetti.
- **LightInfluence and Brightness:** set `LightInfluence = 0` (already the default from `Instance.new`) so tier glows stay vivid at night. Raise `Brightness` to 1.5–3 on top tiers to push particles over the Bloom threshold.
- **ZOffset:** use +0.5 to +2 for glints and flashes, so they sit in front of the bag mesh. Use negative values for ground dust and halos.
- **VelocityPerpendicular:** gives flat ground rings and decals when given a tiny upward Speed (0.01).
- **VelocityParallel:** with Squash ≥ 1 it gives spark streaks that point where they fly.
- **FacingCameraWorldUp:** suits flames, steam and light shafts that shouldn't roll with the camera.

**Reusable Luau helpers.** These are untested starting code. They match the house style in `hood/src/ReplicatedStorage/Shared/Juice.lua`.

```lua
-- ReplicatedStorage/Shared/VFX/Seq.lua
local Seq = {}
-- Seq.N({ {0, 0}, {0.15, 1}, {1, 0} })  -- {time, value, envelope?}; times must start at 0 and end at 1
function Seq.N(points)
	local kps = table.create(#points)
	for i, p in points do kps[i] = NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0) end
	return NumberSequence.new(kps)
end
-- Seq.C({ {0, Color3.new(1,1,1)}, {0.3, gold}, {1, amber} })
function Seq.C(points)
	local kps = table.create(#points)
	for i, p in points do kps[i] = ColorSequenceKeypoint.new(p[1], p[2]) end
	return ColorSequence.new(kps)
end
-- Disabled, full-bright emitter built from a property table (code-built emitters default LightInfluence = 0).
function Seq.emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local pe = Instance.new("ParticleEmitter")
	pe.Enabled = false
	pe.LightInfluence = 0
	pe.Rate = 0
	for k, v in props do (pe :: any)[k] = v end
	pe.Parent = parent
	return pe
end
return Seq
```

**Burst pattern: reuse one emitter rig per client and move its Attachment.** Don't clone emitters per hit.

```lua
-- Point the attachment's +Y (EmissionDirection = Top) along the punch direction.
local function aim(att: Attachment, pos: Vector3, dir: Vector3)
	att.WorldCFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(-math.pi / 2, 0, 0)
end
-- Particles already emitted stay in world space (LockedToPart = false), so the rig can move right away.
```

### Gaps
- I could not confirm the exact current per-emitter rate cap, given the 50000-rate tutorial conflict.
- I could not confirm the current flipbook size rule (the 1024² default string versus "any power-of-two square") from a readable primary source.
- I could not confirm the maximum keypoints per NumberSequence or the exact envelope constraints this session.
- I could not verify the exact geometry of `SpreadAngle` X versus Y on a rotated attachment. Test ring-burst orientation in Studio.

---

## 2. Beams and Trails: textures, TextureMode/Length/Speed, curves, widths, FaceCamera, animated energy, lightning, fist trails

### Takeaway
**Beams** are textured, Bezier-curved ribbons between two Attachments. A scrolling texture (`TextureSpeed`) plus `LightEmission` turns them into energy streams, aura rings, rope glows, light shafts and lightning. They're cheap and resolution-independent, which makes them good for phones.

**Trails** record two attachments' positions each frame. Short `Lifetime` (0.1–0.25 s) with a `WidthScale` taper is the standard fist and swing streak.

Leave both disabled until needed, and keep `Segments` low.

### Cited Findings

**Beam basics** — [Roblox Docs: Beams](https://create.roblox.com/docs/effects/beams)
- A beam renders a texture between `Attachment0` and `Attachment1`. If either attachment is removed, it stops rendering.
- It draws two triangles per segment, laid out using the attachments' orientation; rotating the attachments rotates the segments.
- If `Texture` is unset or invalid, the beam renders as a **solid line** coloured by `Color` — [Roblox API: Beam](https://create.roblox.com/docs/reference/engine/classes/Beam).

**Beam curve**
- A cubic Bézier:
  - **P0** is Attachment0.
  - **P1** is `CurveSize0` studs along Attachment0's **+X**.
  - **P2** is `CurveSize1` studs along Attachment1's **−X**.
  - **P3** is Attachment1.
- Source: [Roblox Docs: Beams](https://create.roblox.com/docs/effects/beams)

**Beam texture tiling**
- With `TextureMode` set to Wrap or Static, repetitions equal the beam length (studs) ÷ `TextureLength`.
- With Stretch, the texture repeats `TextureLength` times across the beam.
- Source: [Roblox Docs: Beams](https://create.roblox.com/docs/effects/beams)

**Beam properties** — [Roblox API: Beam](https://create.roblox.com/docs/reference/engine/classes/Beam)

| Property | Behaviour |
|---|---|
| `TextureSpeed` | Texture cycles per second. Positive moves from A0 to A1; negative reverses. Default 1. |
| `Segments` | Default 10. A Color or Transparency sequence with *n* keypoints needs at least *n − 1* segments to display correctly. |
| `Width0` / `Width1` | Studs, interpolated linearly. Values below 0 are clamped to 0. |
| `FaceCamera` | Always faces the current camera. |
| `LightEmission` | 0–1; 1 is additive. Does not light the world. |
| `LightInfluence` | 0–1 scene-lighting influence. |
| `Brightness` | 0–10000. Scales emitted light when `LightInfluence < 1`. |
| `ZOffset` | Studs toward the camera; avoids z-fighting between several beams on the same attachments. |

**Beam defaults** — [API dump](https://github.com/MaximumADHD/Roblox-Client-Tracker)
- `Width0` and `Width1`: 1.
- `Segments`: 10.
- `TextureMode`: Stretch.
- `TextureLength`: 1.
- `TextureSpeed`: 1.
- `Transparency`: 0.5.
- `LightEmission` and `LightInfluence`: 0.
- `Brightness`: 1.
- `FaceCamera`: false.
- Method: `Beam:SetTextureOffset(offset = 0)`.

**Official laser recipe** — [Roblox Docs: Create laser beams with VFX](https://create.roblox.com/docs/tutorials/use-case-tutorials/vfx/laser-traps-with-beams)
- Texture `rbxassetid://6060542021`.
- Color `255, 47, 137`.
- LightEmission 0.5.
- Width0 and Width1: 4.
- TextureSpeed 2.
- FaceCamera on.
- Beams have no collision, so the tutorial adds an invisible part for hit detection.

**Roblox's own lightning (Duvall Drive)** — [The Mystery of Duvall Drive](https://create.roblox.com/docs/resources/the-mystery-of-duvall-drive/develop-a-moving-world)
- Hero bolts were **scripted textured beams** whose texture, brightness and delays were randomized on every strike.
- A server script picks parameters, waits `rand:NextNumber(3.0, 10.0)` s, and calls `lightningEvent:FireAllClients(info)`. Clients set `beam.Texture = textures[info.textIdx]` and `beam.Brightness = 10`, then tween brightness, Bloom and colour correction down, synced with audio.
- Clients skip the effect when the player is indoors.
- Bolt textures were "super easy to create in Photoshop; we drew a squiggly line, then added an 'Outer Glow' layer effect."
- Distant lightning was a particle emitter flashing a cloud billboard with a randomized transparency curve.

**Community procedural lightning**
- `SamyBlue/Lightning-Beams`: an open-source module using layered moving Perlin noise, disk-point picking and Bézier curves.
- API: `LightningBolt.new(att0, att1, partCount)`, properties `CurveSize0/1`, `PulseSpeed`, `Thickness`, `Frequency`, `AnimationSpeed`, `Color` (Color3 or ColorSequence), `FadeLength`/`PulseLength` and `MinRadius`/`MaxRadius`. No benchmarks are given.
- Source: [GitHub: SamyBlue/Lightning-Beams](https://github.com/SamyBlue/Lightning-Beams)

**Trails** — [Roblox Docs: Trails](https://create.roblox.com/docs/effects/trails); [Roblox API: Trail](https://create.roblox.com/docs/reference/engine/classes/Trail)
- A Trail draws between and behind two attachments as they move. Attachment spacing sets the width.
- Defaults (API dump): `Lifetime` 2 (range 0.01–20), `MinLength` 0.1, `MaxLength` 0 (unlimited), `WidthScale` 1, `Transparency` 0.5, `TextureMode` Stretch, `FaceCamera` false, `LightEmission` 0.
- `WidthScale` (0–1 NumberSequence) multiplies attachment distance over lifetime, centred between the attachments.
- `Enabled = false` stops new segments but old ones expire naturally. Call `Trail:Clear()` to wipe them.
- Changing attachments mid-draw erases drawn segments.
- **TextureMode** behaviour:

  | Mode | Behaviour |
  |---|---|
  | Stretch | Stretches with lifetime and shrinks when the attachments stop |
  | Wrap | Tiles, stationary relative to the attachments |
  | Static | "Stamped" in place, e.g. tire tracks |

- Shortening `Lifetime` "moves through the space more quickly and consequently cuts down the length of the trail… a faster, more animated visual appearance."

### Inferences

**Fist trail per tier**
- Put two Attachments on each glove, about 0.35 studs apart vertically.
- Trail settings:
  - `Lifetime` 0.12 (T1) to 0.2 (T8).
  - `WidthScale` `{0,1}→{1,0}`.
  - `Transparency` `{0,0.15}→{1,1}`.
  - `FaceCamera = true`.
  - `MinLength = 0.05`.
  - `LightEmission`: 0 at T1–3 (solid white or grey streak, readable in daylight), 0.6–1 at T5+ (tier-colour glow).
- Enable it at the end of the wind-up, disable it Lifetime + 0.05 s after impact, and call `:Clear()` on respawn.

**Energy and aura beams**
- For a circle around a bag base, use 4 attachments at 90° around a ring and 4 beams with `CurveSize0/1 ≈ radius × 0.55`. Rotate the attachments so their ±X axes are tangent to the circle; this approximates a circle with Béziers.
- Settings: `TextureMode = Wrap`, `TextureLength ≈ 2`, `TextureSpeed = 0.5–1.5` (higher tiers spin faster), `FaceCamera = false` so the ring lies flat, `LightEmission = 1`, `Segments` 8–12.

**Lightning without uploads**
- A Beam with no texture is a solid line. Chain 4–6 untextured beams (`Segments = 1`) through jittered attachments and re-randomize them for 0.1–0.2 s.
- Upgrade later to uploaded squiggle textures, as Roblox did for Duvall Drive.

```lua
-- Electric arc that strikes between two local points on `host` (T5+ bags, punch crits). Untested.
local RNG = Random.new()
local function makeArc(host: BasePart, points: number, color: Color3)
	local atts, beams = {}, {}
	for i = 1, points do
		local a = Instance.new("Attachment")
		a.Parent = host
		atts[i] = a
	end
	for i = 1, points - 1 do
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = atts[i], atts[i + 1]
		b.Width0, b.Width1 = 0.16, 0.16
		b.FaceCamera = true
		b.Segments = 1                      -- straight pieces; jaggedness comes from the joints
		b.LightEmission, b.LightInfluence = 1, 0
		b.Brightness = 2
		b.Color = ColorSequence.new(color)
		b.Transparency = NumberSequence.new(0)
		b.Enabled = false
		b.Parent = host
		beams[i] = b
	end
	return function(fromLocal: Vector3, toLocal: Vector3, jitter: number)
		for flick = 1, 3 do                  -- 3 re-jitters over ~0.15 s reads as crackling
			for i, a in atts do
				local t = (i - 1) / (points - 1)
				local off = if i == 1 or i == points then Vector3.zero
					else Vector3.new(RNG:NextNumber(-1, 1), RNG:NextNumber(-1, 1), RNG:NextNumber(-1, 1)) * jitter
				a.Position = fromLocal:Lerp(toLocal, t) + off
			end
			for _, b in beams do b.Enabled = true end
			task.wait(0.05)
		end
		for _, b in beams do b.Enabled = false end
	end
end
```

**Champion ring ropes:** a Beam along each rope with a soft gradient texture, `TextureSpeed` 0.3, a gold→white `Color`, and a `Brightness` pulse tween (1 ⇄ 2.5, 1.2 s, Sine, reversing).

### Gaps
- I could not confirm current per-beam or per-trail rendering costs or segment limits from an official source.
- The DevForum beam-texture tutorials (e.g. tileable lightning sheets) were blocked.

---

## 3. Other tools: Highlight, Neon + lights, GUI glows, UIGradient, mesh VFX, ForceField material, legacy Explosion/Fire/Smoke/Sparkles

### Takeaway
To glow without particles:
- **Highlight** gives outlines and flashes, but has a 255 limit and a first-use GPU cost.
- **Neon parts** glow through Bloom, which needs higher graphics quality.
- **PointLight / SpotLight / SurfaceLight** cast real light.
- **BillboardGui/SurfaceGui** with `Brightness > 1` and `LightInfluence 0` give glow sprites.
- **UIGradient** now offers Radial and Conical types and Repeat/Mirror tiling, so soft halos and sun-rays need no textures.
- **MeshParts / basic parts tweened** in size and transparency give shockwave spheres, discs and spinning rings.
- **ForceField material** gives animated shimmer shells.

`Explosion` is **not deprecated**, but it is a physics object with dated visuals. Use particle and mesh bursts instead.

### Cited Findings

**Highlight** — [Roblox Docs: Highlighting objects](https://create.roblox.com/docs/effects/highlighting); [Roblox API: Highlight](https://create.roblox.com/docs/reference/engine/classes/Highlight)
- An outline plus an interior fill.
- Defaults (API dump): FillColor red (1, 0, 0), FillTransparency 0.5, OutlineColor white, OutlineTransparency 0, DepthMode AlwaysOnTop.
- Parent it to a Model or BasePart, or set `Adornee`.
- **Limits:**
  - Only **255** Highlights display client-side at once; extras are silently ignored.
  - A disabled Highlight still takes a slot, so delete permanently unused ones.
- **Changes are cheap, creation is not:**
  - Toggling `Enabled` has no performance impact.
  - Changing properties is lightweight.
  - **Adding or removing a Highlight can trigger a geometry rebuild, causing spikes and extra draw calls.**
- **Cost:**
  - The **first** visible Highlight costs "up to 1 millisecond of GPU time on mobile"; more Highlights add little.
  - On mobile, cost grows with screen coverage.
  - Invisible Highlights (disabled or fully transparent) cost nothing.
  - Low-end devices render Highlights more pixelated.
- Don't nest highlighted objects inside other highlighted objects; back-to-front draw order causes problems.
- `DepthMode` is AlwaysOnTop (shows through walls) or Occluded.

**Light sources** — [Roblox Docs: Light sources](https://create.roblox.com/docs/effects/light-sources)
- **PointLight:** spherical, for bulbs, torches and fireballs. Attachments are recommended as the parent.
- **SpotLight:** a cone; `Face` and `Angle` (up to 180).
- **SurfaceLight:** emits from a whole part face; for signs, screens and billboards.
- Shared properties are `Color`, `Brightness` and `Shadows`. Brightness doesn't extend beyond `Range`.
- The flare tutorial pairs particles with a PointLight at Brightness 2, Range 36 — [Core curriculum](https://create.roblox.com/docs/tutorials/curriculums/core/building/create-basic-visual-effects).
- Particles, beams and trails do **not** light the world, so add a PointLight for real light — [Roblox API: ParticleEmitter](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter).

**Bloom and Neon**
- `BloomEffect` defaults: Intensity 0.4, Size 24, Threshold 0.95 (API dump). "When this effect has a high value, parts with light colors glow." — [Roblox Docs: Post-processing effects](https://create.roblox.com/docs/environment/post-processing-effects)
- Neon and ForceField materials are "unique and/or [their] texture assets are bundled with Studio". They are not editable material variants. — [Roblox Docs: Materials](https://create.roblox.com/docs/parts/materials)
- Neon's glow comes from Bloom. Search summaries report:
  - It needs graphics quality around level 8 or higher.
  - "Automatic" quality may not show bloom.
  - The glow varies with part colour.
  - Sources: [DevForum: Neon part not glowing](https://devforum.roblox.com/t/neon-part-not-glowing/3150111); [DevForum: Neon parts don't glow](https://devforum.roblox.com/t/neon-parts-dont-glow-is-not-the-rendering/3276740) **(search summary)**

**GUI glows**
- `BillboardGui` and `SurfaceGui` both have `Brightness` (default 1) and `LightInfluence` (default 0 via the API), plus `AlwaysOnTop`. BillboardGui also has `MaxDistance` (default INF). — API dump, [Client Tracker](https://github.com/MaximumADHD/Roblox-Client-Tracker)
- **No GUI object has a blend-mode property.** The only "blend" member in the whole API dump is `ParticleEmitter.FlipbookBlendFrames`. So ImageLabel "additive glow" is not possible natively; a glow must come from bright colours, transparency and Bloom.

**UIGradient (2025–26 features)** — [Roblox Docs: Appearance modifiers](https://create.roblox.com/docs/ui/appearance-modifiers)
- `Type`:
  - Linear.
  - **Radial**: radiates from the centre, radius (width + height) ÷ 4.
  - **Conical**: sweeps clockwise around the centre; `Rotation` sets the start angle.
- `Offset` is a percentage of parent size; `Rotation` sets the angle.
- `Scale`: below 1 the gradient covers less of the element, and the rest fills per `TileMode`.
- `TileMode`: Clamp, **Repeat** or **Mirror** (enum `GradientTileMode` in the API dump).
- Defaults: Type Linear, Scale 1, TileMode Clamp.

**ForceField material and mesh VFX** (search summaries)
- ForceField material works on parts, CSG and MeshParts.
- On MeshParts, a custom `TextureID` animates. The texture's **red channel** controls which pixels become visible as an internal 0–1 "slider" sweeps up and down.
- Animation speed and slider thickness can't be controlled; about 10% of the surface is opaque at any moment.
- `Texture` instances don't work with ForceField.
- Sources: [DevForum: How ForceField texture animation works](https://devforum.roblox.com/t/how-forcefield-texture-animation-works/3041374); [DevForum: New material ForceField v2.0](https://devforum.roblox.com/t/new-material-forcefield-v20/297785) **(search summary)**
- The community "Hit Effect Handler" builds hit effects from a special mesh part plus a ParticleEmitter in a ModuleScript — [DevForum: Hit Effect Handler](https://devforum.roblox.com/t/hit-effect-handler-how-to-make-a-good-hit-effect-in-5-minutes-mesh-particles/1511337) **(search summary)**

**Explosion**
- Not deprecated: no deprecation tag in the API dump.
- It applies force, **breaks joints and welds, and kills Humanoids** not protected by a ForceField. Parenting an Explosion fires it immediately and auto-unparents it after a few seconds.
- Defaults: `BlastPressure` 500000, `BlastRadius` 4 (0–100), `DestroyJointRadiusPercent` 1, `ExplosionType` **Craters** (damages terrain).
- Other properties: `Visible` and `TimeScale`.
- Docs advice: set `DestroyJointRadiusPercent = 0` and use the `Hit` event for custom damage.
- Source: [Roblox API: Explosion](https://create.roblox.com/docs/reference/engine/classes/Explosion)
- The official explosion tutorial builds the effect entirely from a ParticleEmitter burst — [Create explosions with VFX](https://create.roblox.com/docs/tutorials/use-case-tutorials/vfx/use-particles-for-explosions).

**Fire, Smoke and Sparkles**
- Still present and not deprecated (API dump). Defaults: Fire Size 5, Heat 9; Smoke Opacity 0.5, RiseVelocity 1; Sparkles SparkleColor purple.
- Docs: they "can be a convenient way to save time… but they are far less customizable than ParticleEmitters." — [Basic particle effects](https://create.roblox.com/docs/tutorials/use-case-tutorials/vfx/basic-particle-effects)

### Inferences

**Highlights in Hood**
- Use **one persistent Highlight per T6–T8 bag**. Set a coloured outline at OutlineTransparency 0.35–0.6, `DepthMode = Occluded`, and keep the fill invisible (FillTransparency 1).
- On a punch, set FillTransparency to 0.25 and tween it back to 1 over 0.12 s.
- **This means changing `Juice.flash`.** It currently creates and destroys a Highlight on every punch, which is exactly the add/remove churn the docs warn causes rebuild spikes. Fully transparent Highlights cost nothing on GPU, though they still use a slot.

```lua
local TweenService = game:GetService("TweenService")
local FLASH_IN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local function bagHighlight(model: Model, outline: Color3?, outlineT: number?): Highlight
	local h = model:FindFirstChild("TierHighlight") :: Highlight?
	if not h then
		h = Instance.new("Highlight")
		h.Name = "TierHighlight"
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.FillColor = Color3.new(1, 1, 1)
		h.FillTransparency = 1
		h.Parent = model
	end
	h.OutlineColor = outline or Color3.new(1, 1, 1)
	h.OutlineTransparency = outlineT or 1
	return h
end
local function hitFlash(h: Highlight)
	h.FillTransparency = 0.25
	TweenService:Create(h, FLASH_IN, { FillTransparency = 1 }):Play()
end
```

**Neon and lights**
- Always pair a Neon part with a **solid bright colour and a light** (PointLight or SurfaceLight). On phones where Bloom is off, Neon then still reads as a bright flat colour plus coloured light spill.
- Set `Shadows = false` on all VFX lights.
- Use SurfaceLight for neon signs and shop fronts, SpotLight cones for the Champion ring, and PointLight on Attachments for bag tiers T4+.

**Glow sprites without textures**
- Use a `BillboardGui` with LightInfluence 0, Brightness 2–3 and `AlwaysOnTop = false`. Inside it, place a `Frame` with:
  - `UICorner` (0.5, 0);
  - `UIGradient` Type **Radial**, Transparency `{0,0.1}→{0.5,0.6}→{1,1}`, and a white→tier colour Color.
- This gives a soft halo behind coins, gems and rare items.
- **Sun-rays:** a second Frame with UIGradient Type **Conical**, `TileMode = Repeat`, `Scale ≈ 0.125` (about 8 rays) and an alternating transparency sequence, with `Rotation` animated slowly. This is an unverified combination; check it in Studio.

**Mesh VFX**
- Use an anchored, non-colliding Part, then tween `Size` and `Transparency` with Quart/Out and destroy it afterwards. Options:
  - **Shockwave sphere:** `Shape = Ball`, Material ForceField or Neon.
  - **Ground disc:** `Shape = Cylinder` rotated 90° on Z, Neon.
  - **Ring:** needs an uploaded torus MeshPart or a ring texture.
- `ForceField` spheres with an uploaded noise texture make good "shield" or rebirth shells, because the material animates itself at no scripting cost.

```lua
local Debris = game:GetService("Debris")
local function shockSphere(pos: Vector3, color: Color3, maxSize: number, dur: number, material: Enum.Material?)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Material = material or Enum.Material.ForceField
	p.Color = color
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size = Vector3.one * 0.5
	p.CFrame = CFrame.new(pos)
	p.Transparency = 0
	p.Parent = workspace
	TweenService:Create(p, TweenInfo.new(dur, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Size = Vector3.one * maxSize, Transparency = 1 }):Play()
	Debris:AddItem(p, dur + 0.05)
end
local function groundDisc(pos: Vector3, color: Color3, maxDiameter: number, dur: number)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder                 -- cylinder axis is X, so roll 90° to lie flat
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size = Vector3.new(0.1, 1, 1)
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	p.Transparency = 0.15
	p.Parent = workspace
	TweenService:Create(p, TweenInfo.new(dur, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.05, maxDiameter, maxDiameter), Transparency = 1 }):Play()
	Debris:AddItem(p, dur + 0.05)
end
```

**Don't use `Explosion` for wall breaks or rebirths.** If you must use it, set `BlastPressure = 0`, `DestroyJointRadiusPercent = 0` and `ExplosionType = Enum.ExplosionType.NoCraters`. Otherwise it can kill players and break the wall's own welds unpredictably.

### Gaps
- I found no official number for how many dynamic lights a mobile device renders before culling, nor their per-light cost.
- I couldn't verify the Neon "quality ≥ 8" bloom threshold from a primary source.
- I couldn't verify the UIGradient Conical + Repeat sun-ray behaviour.

---

## 4. VFX art principles from pro VFX artists: timing, shape, layering, colour ramps, value, readability, randomness, mobile restraint

### Takeaway
Pro real-time VFX art rests on four ideas:
- **Gameplay-first clarity.**
- **Value contrast** draws the eye more than hue.
- **Strict timing:** anticipation, then a sharp impact peak, then a quick dissipation.
- **Layered elements:** a primary shape plus secondaries.

Visual loudness should scale with gameplay importance. For Hood's tiers, escalation comes from these levers (see §6 for values):
- value and brightness;
- element count;
- motion speed;
- secondary motion;
- saturation range.

The levers do **not** include filling the screen. That is exactly the "less is more" rule for phones.

### Cited Findings

**League of Legends VFX style guide** (Riot) — [/dev: League's VFX Style Guide](https://nexus.leagueoflegends.com/en-us/2017/10/dev-leagues-vfx-style-guide/); [Style guide PDF](https://nexus.leagueoflegends.com/wp-content/uploads/2017/10/VFX_Styleguide_final_public_hidpjqwx7lqyx0pjj3ss.pdf) **(search summary)**
- The guide is built on five pillars: **gameplay, value, color, shape, timing**.
- Its goals: visual clarity for gameplay, minimal clutter, promoting theme, and "surprise and delight".
- "Visual impact should represent gameplay impact." Small, frequent effects stay visually small; big ultimates are visually loud.
- Primary elements have a high value range and strong value or saturation contrast. Secondary elements have a lower value range and smaller size, and support the primary.

**Value and readability** — [VFX Apprentice: 10 Design Tips from the LoL VFX Style Guide](https://www.vfxapprentice.com/blog/10-league-of-legends-vfx-design-tips); [VFX Apprentice: Artistic principles of game VFX](https://www.vfxapprentice.com/blog/five-artistic-principles-gaming-vfx) **(search summary)**
- Value ranges are "the most powerful tools … to dictate where a player's eyes focus".
- Saturation, value contrast and size "must align directly with a spell's mechanical tier".
- Crunching value gradients in highlight zones avoids muddy blends.

**Timing** — [80.lv: VFX Staples: Shape, Color, and Motion](https://80.lv/articles/vfx-staples-shape-color-and-motion); [VFX Apprentice: FX timing principles](https://www.vfxapprentice.com/courses/fx-timing-principles) **(search summary)**
- Anticipation amplifies energy; "80% of impact is before contact".
- The climax or impact shows "the maximum number of elements with biggest contrast and high saturation".
- Dissipation "shouldn't stay visible for long … low contrast and low opacity".
- "The flash has to land on the exact frame of impact … the fade has to clear before the next action."
- Shape means silhouette, mass and directionality: "can you read it at a glance?"

**Contrast at the start of an effect** — [RealtimeVFX: Simon Trümpler VFX Sketchbook](https://realtimevfx.com/t/simon-trumpler-vfx-sketchbook/4177) **(search summary)**
- Simon Trümpler, a well-known real-time VFX artist and the author of *Game Art Tricks*, shows how adding contrast in the first few frames of fire makes it feel like it is "popping out".

**Roblox-specific principles in the official docs**
- Fade particles in and out to avoid popping — [Particle emitters guide](https://create.roblox.com/docs/effects/particle-emitters).
- Moving effects in an otherwise still world become a focal point and "draw players' eyes", like the flare used to guide players upward — [Core curriculum](https://create.roblox.com/docs/tutorials/curriculums/core/building/create-basic-visual-effects).
- Randomize texture, brightness and delay on every strike — [Duvall Drive](https://create.roblox.com/docs/resources/the-mystery-of-duvall-drive/develop-a-moving-world).
- "Randomizing properties can make particles feel less repetitive." — [Artist curriculum](https://create.roblox.com/docs/tutorials/curriculums/artist/work-with-particle-emitters)
- Rain had to be "heavy enough, but not so much that it blocked the visibility of the game" — [Duvall Drive](https://create.roblox.com/docs/resources/the-mystery-of-duvall-drive/develop-a-moving-world).

### Inferences

**Hood's VFX style rules**

1. **Timing template for every punch.** This matches the existing Juice hit-stop and camera kick.

   | Phase | Duration | What happens |
   |---|---|---|
   | Wind-up glow | 80–150 ms | Glove trail on, faint charge particles for T5+ |
   | **Impact frame** | 0–60 ms | White-hot core flash, ring and sparks at full contrast. Highlight fill flash. Hit-stop 40–80 ms. |
   | Dissipation | 150–450 ms | Sparks decelerate (Drag), the ring fades, a dust puff drifts |
   | Clean slate | ≤ 0.6 s after impact | Nothing left from this punch, so rapid punching doesn't stack clutter |

2. **Colour ramp, "white-hot to tier colour":** every glow uses `Color = white → tier colour → darker tier colour` over its lifetime, and transparency rises at the end. Cores stay white or near-white; the tier hue lives on edges and secondary elements. This also keeps tiers distinguishable on small screens.
3. **Value hierarchy:** primary layer (core flash and ring) has the highest value and largest size. Secondary layers (sparks, motes) are smaller and more saturated. Tertiary layers (dust, smoke) are low contrast with `LightEmission` 0.
4. **Shape language per theme:**
   - Round puffs and stars for cartoony and friendly effects.
   - Sharp shards and streaks for power and electric effects.
   - Rays and glints for gold and champion.
   - Keep every shape chunky: ≥ 0.3 studs at bag distance. Thin 1-pixel sparks vanish on phones.
5. **Randomness:** always give Lifetime, Speed, Rotation and RotSpeed a min/max range. Add Size envelopes of ~10–20%. Pick from 2–3 texture variants (or a flipbook with `FlipbookStartRandom`).
6. **Secondary motion:** use a slow RotSpeed on glints, orbiting beams on T7+, and bobbing for floating pickups. Add a light pulse (PointLight Brightness tween) synced to the impact.
7. **Mobile "less is more":**
   - Escalate with brightness, colour and one extra layer per tier, not with particle counts.
   - Cap the per-punch burst at about 30–40 particles total.
   - Limit full-screen effects (huge flashes, big smoke) to rare events: rebirth and ring wins.

### Gaps
- I couldn't read the full LoL guide, the VFX Apprentice articles or RealtimeVFX threads (blocked). Quotes are from search summaries only.
- I found no Roblox-specific published "pro VFX artist" style guide this session; DevForum portfolio advice was blocked.

---

## 5. Texture creation: what pros use, resolutions, alpha, flipbook sheets, how to make them, built-in textures usable without uploads

### Takeaway
A small set of grayscale-on-transparent textures, tinted by `Color`, covers about 90% of stylized VFX:
- soft glow;
- four-point star or sparkle;
- ring;
- smoke puff;
- spark streak;
- slash arc;
- shard;
- lightning squiggle;
- dust mote.

Size guidance:
- Keep singles at **128–256 px**.
- Keep flipbooks at **512²** (4×4 of 128 px frames) for mobile, and use **1024²** (the maximum) only for hero effects.
- Pad flipbook frames by about 8 px.

Roblox ships usable built-in textures at `rbxasset://textures/particles/…` and `rbxasset://textures/glow.png`. Roblox's tutorials also expose several free official uploaded texture IDs.

### Cited Findings

**Authoring rules**
- "Make your image **grayscale**… complete control over the final color with the Color property. Ensure the background is **transparent**. **Blur** the edges." — [Custom particle effects](https://create.roblox.com/docs/tutorials/use-case-tutorials/vfx/custom-particle-effects)
- Use PNG with a transparent background. For grayscale textures with no alpha, set `LightEmission = 1` — [Particle emitters guide](https://create.roblox.com/docs/effects/particle-emitters).
- Roblox supports up to **1024×1024** texture maps — [Roblox Docs: Texture specifications](https://create.roblox.com/docs/art/modeling/texture-specifications).

**Flipbooks**
- Layouts are 2×2, 4×4, 8×8 or custom. For example, a 1024×1024 sheet at 8×8 holds 64 frames.
- Include transparent spacing between frames; mip filtering may require more.
- Flipbooks are dropped on low-memory phones, and reused textures cost less.
- Source: [Particle emitters guide](https://create.roblox.com/docs/effects/particle-emitters)
- For an 8×8 sheet (128 px frames), stay about 8 px from cell edges, drawing in the middle 120×120 — [DevForum: Animated Particles with the Particle Flipbooks Beta](https://devforum.roblox.com/t/animated-particles-with-the-particle-flipbooks-beta/1718023) **(search summary)**

**How pros made textures**
- Lightning was a squiggly line with a Photoshop "Outer Glow" layer effect — [Duvall Drive](https://create.roblox.com/docs/resources/the-mystery-of-duvall-drive/develop-a-moving-world).
- A DevForum tutorial covers making VFX textures in Photopea, a free browser editor — [DevForum: How to make textures for VFX and particles](https://devforum.roblox.com/t/how-to-make-textures-for-vfx-and-particles/3546172) **(search summary, via the earlier note)**

**Built-in engine textures** (no upload, `rbxasset://` content bundled with the client). Listed from the client content tree, with dimensions and format read from the files — [Roblox-Client-Tracker `textures/particles/`](https://github.com/MaximumADHD/Roblox-Client-Tracker/tree/roblox/textures/particles).

| Path | Notes |
|---|---|
| `rbxasset://textures/particles/sparkles_main.dds` | 128², DXT5. **The default ParticleEmitter texture** (white star sparkle). |
| `rbxasset://textures/particles/smoke_main.dds` | 128², DXT5 |
| `rbxasset://textures/particles/explosion01_shockwave_main.dds` | 256², DXT5. Shockwave, judging by the name. |
| `…/explosion01_core_main.dds`, `…/explosion01_smoke_main.dds`, `…/explosion01_implosion_main.dds` | Legacy Explosion layers |
| `…/fire_main.dds`, `…/fire_sparks_main.dds` | Legacy Fire layers |
| `…/forcefield_glow_main.dds`, `…/forcefield_vortex_main.dds` | Legacy ForceField layers |
| `rbxasset://textures/particles/SquareParticle.png` | 256², palette PNG; a plain square |
| `rbxasset://textures/glow.png` | 256², grayscale + alpha. Soft glow. |
| `rbxasset://textures/sparkle.png` | 32², grayscale + alpha |

**Official uploaded texture IDs from Roblox tutorials**

| Asset ID | What it is | Source |
|---|---|---|
| `rbxassetid://3845808160` | Soft circle (smoke) | [Custom particle effects](https://create.roblox.com/docs/tutorials/use-case-tutorials/vfx/custom-particle-effects) |
| `rbxassetid://6101261905` | Electric spark | [Explosions tutorial](https://create.roblox.com/docs/tutorials/use-case-tutorials/vfx/use-particles-for-explosions) |
| `rbxassetid://8983307836` | Flare | [Core curriculum](https://create.roblox.com/docs/tutorials/curriculums/core/building/create-basic-visual-effects) |
| `rbxassetid://14302399641` | Dust mote | same |
| `rbxassetid://6060542021` | Laser beam texture | [Laser tutorial](https://create.roblox.com/docs/tutorials/use-case-tutorials/vfx/laser-traps-with-beams) |
| `5860841663`, `5857851812`, `5857851618`, `6711256324`, `5833235272`, `6772783963`, `5833323391`, `5857892330`, `5857892405`, `5857931724`, `5860841737` | "Starter pack" particle textures from the Mansion of Wonder lesson. The captions give only the IDs, not what each depicts. | [Artist curriculum](https://create.roblox.com/docs/tutorials/curriculums/artist/work-with-particle-emitters) |

### Inferences

**Texture shopping list for Hood** (author once, reuse everywhere; all white or grayscale on transparent)

| Texture | Size | Used by |
|---|---|---|
| `glow_soft` | 256² | Core flash, halos, pickup glow. Start with built-in `glow.png`. |
| `star4` | 256² | Four-point glint for gold, diamond and level-up |
| `ring` (thin, soft edge) | 256² | Shockwaves, ground halos. Try built-in `explosion01_shockwave_main.dds` first. |
| `smoke_puff` | 2×2 flipbook at 512² | Dust, wall-break smoke, steam |
| `spark_streak` | 128² | Punch sparks (with VelocityParallel + Squash) |
| `slash_arc` | 512² | Hook/uppercut swoosh, champion swings |
| `shard` | 2×2 at 256² | Wall debris chips, diamond shards (FlipbookStartRandom, Framerate 0) |
| `lightning` | 512×128 tiling strip | Electric-tier beams |
| `confetti` | 2×2 at 128² with 4 differently coloured pieces | Multi-colour confetti from one emitter. **Keep `Color` white.** |
| `coin` | 2×2 at 256² (spin frames) | Gold-tier hit shower, cash pickups |

**Making them**
- Krita, GIMP or Photopea work: draw a white shape and use Gaussian blur for soft edges, or an outer glow.
- Alternatively, generate them procedurally in Python (the repo already uses Python in `hood/art/icons/make_icons.py`):

```python
# hood/art/vfx/make_vfx_textures.py  (untested sketch; Pillow)
from PIL import Image, ImageDraw, ImageFilter, ImageChops
import math

def blank(n): return Image.new("L", (n, n), 0)            # alpha mask
def save(mask, path):                                       # white RGB + alpha = tintable by Color
    img = Image.new("RGBA", mask.size, (255, 255, 255, 0)); img.putalpha(mask); img.save(path)

def soft_glow(n=256, falloff=2.2):
    m = blank(n); px = m.load(); c = (n - 1) / 2
    for y in range(n):
        for x in range(n):
            d = min(1.0, math.hypot(x - c, y - c) / c)
            px[x, y] = int(255 * (1 - d) ** falloff)
    return m

def ring(n=256, radius=0.75, width=0.07, blur=2):
    m = blank(n); d = ImageDraw.Draw(m); c = n / 2
    ro, ri = c * (radius + width), c * (radius - width)
    d.ellipse([c - ro, c - ro, c + ro, c + ro], fill=255)
    d.ellipse([c - ri, c - ri, c + ri, c + ri], fill=0)
    return m.filter(ImageFilter.GaussianBlur(blur))

def star4(n=256, thin=0.06, pad=8):
    m = blank(n); d = ImageDraw.Draw(m); c = n / 2; t = thin * c
    d.polygon([(c, pad), (c + t, c), (c, n - pad), (c - t, c)], fill=255)
    d.polygon([(pad, c), (c, c - t), (n - pad, c), (c, c + t)], fill=255)
    return ImageChops.lighter(m.filter(ImageFilter.GaussianBlur(1.5)), soft_glow(n, 4.0))

def pack(frames, grid, n=512, pad=8):                       # flipbook sheet, row-major
    sheet = blank(n); cell = n // grid
    for i, f in enumerate(frames[: grid * grid]):
        f = f.resize((cell - 2 * pad, cell - 2 * pad))
        sheet.paste(f, ((i % grid) * cell + pad, (i // grid) * cell + pad))
    return sheet

save(soft_glow(), "glow_soft_256.png"); save(ring(), "ring_256.png"); save(star4(), "star4_256.png")
```

- Prefer reusing built-ins (`glow.png`, `sparkles_main.dds`, `SquareParticle.png`) during prototyping. Built-in content can change with client updates, so ship uploaded copies of anything critical.

### Gaps
- I couldn't visually inspect the built-in `.dds` textures, so descriptions beyond the default sparkle are inferred from file names.
- I couldn't confirm frame order in flipbook sheets from the docs. Row-major, left-to-right and top-to-bottom, is assumed.
- The 11 artist-curriculum texture IDs have no descriptions in the source.

---

## 6. Concrete recipes for Hood: tiered aura ladder (8 bags + champion ring), tiered punch impact, wall break, level-up/rebirth, rare glow, gold shine, confetti, steam, neon flicker, lightning, pickups

### Takeaway
Build every effect as **data-driven layers on a shared client FX module**. The server only fires events, as in Roblox's own Duvall Drive pattern of "server picks parameters → `FireAllClients` → clients render".

Tiers escalate one or two layers at a time, so each step is noticeable but phones stay within budget:

| Tier | Adds |
|---|---|
| T1 | Nothing ambient |
| T3 | Motes |
| T4 | Light |
| T5 | Electric arcs |
| T6 | Highlight outline |
| T7 | Shell / orbit |
| T8 | Gold glints + rays + coins |

Only the official sparkle, smoke, burst, flare and dust values below are sourced. **All other numbers are untested starting values to tune in Studio.**

### Cited Findings
- **Server parameters, client rendering:** the server computes randomized FX parameters and calls `FireAllClients(info)`. Each client decides whether to render (e.g., indoors check) and runs tweens locally. — [Duvall Drive](https://create.roblox.com/docs/resources/the-mystery-of-duvall-drive/develop-a-moving-world)
- **Gold sparkle base recipe:** Color `255,200,50`, Lifetime 0.5–1, Rate 7, Speed 2–3, SpreadAngle 180/180, Size 0.3, LightEmission 1, Transparency 0.5, Drag 1.5, with a PointLight for a gentle glow — [Basic particle effects](https://create.roblox.com/docs/tutorials/use-case-tutorials/vfx/basic-particle-effects).
- **Burst base recipe:** Drag 10, Lifetime 0.2–0.6, Speed 20–40, SpreadAngle 180/180, Enabled off, Emit 100. The docs suggest "sparkles for gathering collectable objects" as a variant. — [Create explosions with VFX](https://create.roblox.com/docs/tutorials/use-case-tutorials/vfx/use-particles-for-explosions)
- **Smoke base recipe:** soft circle `3845808160`, Transparency 0→1, Size 3→10, Color orange → grey → white, Acceleration (2, 2, 0), Rate 40 — [Custom particle effects](https://create.roblox.com/docs/tutorials/use-case-tutorials/vfx/custom-particle-effects).
- **Water drops:** "Speed to 0 and Y acceleration to a negative value" — same source.
- **Varied static frames:** `FlipbookStartRandom` with Framerate 0 gives random static frames per particle (multi-colour confetti or shards from one emitter) — [Particle emitters guide](https://create.roblox.com/docs/effects/particle-emitters).
- **Wind drift:** `WindAffectsDrag` with `Drag > 0` makes ambient particles follow `Workspace.GlobalWind` — [Particle emitters guide](https://create.roblox.com/docs/effects/particle-emitters).

### Inferences

#### 6.1 Tier ladder

Tier names are placeholders (only T1 Tire, T8 Gold and the Champion ring are given); rename them to match the bag designs. The "Live" column is approximate on-screen particles from ambient emitters (Rate × Lifetime).

| Tier | Theme / palette (core → edge) | Ambient layers (each adds to the previous tier) | Live | Light | Highlight | Per-punch impact |
|---|---|---|---|---|---|---|
| **T1 Tire** | Rubber. White → grey. | None: matte, maybe a slow idle sway only | 0 | none | none | 6 grey-white sparks, 3 dust puffs, **no ring** |
| **T2** | Canvas/tape. White → pale yellow. | 1 slow dust mote (Rate 0.5, Life 3) | ~2 | none | none | 8 sparks, small ring (size → 4), 3 dust |
| **T3** | Red leather. White → red. | Tier motes: Rate 1.5, Life 2, Speed 0.5–1, Size 0.25, LightEmission 1 | ~4 | none | none | 10 sparks, ring → 5 |
| **T4** | Chrome blue. White → sky blue. | + glints on the bag surface (see 6.4, Rate 1.5) | ~5 | PointLight Brightness 1, Range 8 | none | 12 sparks, ring → 6, light pulse |
| **T5** | Electric lime. White → lime → teal. | + rising wisps (Rate 3, Life 1.2) + arc strike every 1.5–3 s (§2) | ~8 | Brightness 1.5, Range 10 | none | 14 sparks, ring → 7, mini arc on crit |
| **T6** | Inferno. White → yellow → orange → red. | + embers rising (Rate 5, Life 1.2, Accel +Y 4, RotSpeed) + ground halo ring (Rate 0.7, Life 1.5) | ~12 | Brightness 2, Range 12, flicker | outline orange, 0.6 | 16 sparks, ring → 8, 6-ember fountain |
| **T7** | Diamond. White → cyan → violet. | + ForceField shell sphere (scale 1.15× bag, cyan) + 2 orbiting glints (rotating attachment) | ~14 | Brightness 2, Range 12, cool white | outline cyan, 0.5 | 18 sparks, **double ring**, 6 shard chips |
| **T8 Gold** | White → gold `255,200,50` → amber `230,140,20` | + gold sparkle (official recipe) + big star glints + sun-ray billboard behind the bag + coins drifting up (Rate 0.5) | ~18 | warm, Brightness 2.5, Range 14 | outline gold, 0.35 | 20 sparks, double ring, **8-coin shower**, light pulse to 6 |
| **Champion ring** | Gold + white + team red/blue | Rope beams scrolling, neon corner posts, 4 SpotLight cones (Shadows off), sparkle volume over the canvas (Rate 6, Life 2) | ~25 total | 4 SpotLights | none | Win: confetti 40 + rays + flash |

Escalation levers, in order:
- brighter core and higher `Brightness`;
- one new layer;
- faster `TextureSpeed`/`RotSpeed`;
- wider saturation range.

Particle counts grow only modestly.

#### 6.2 Data + builder sketch

```lua
-- ReplicatedStorage/Shared/Config/BagFX.lua  (data only; names/colors are placeholders)
local C = Color3.fromRGB
return {
	[1] = { core = C(255,255,255), edge = C(170,170,175), sparks = 6,  ring = 0, dust = 3 },
	[2] = { core = C(255,255,240), edge = C(250,225,140), sparks = 8,  ring = 4, dust = 3, motes = 0.5 },
	[3] = { core = C(255,240,235), edge = C(235, 60, 60), sparks = 10, ring = 5, motes = 1.5 },
	[4] = { core = C(240,250,255), edge = C( 90,190,255), sparks = 12, ring = 6, motes = 1.5, glints = 1.5, light = { 1, 8 } },
	[5] = { core = C(245,255,235), edge = C(120,255, 90), sparks = 14, ring = 7, motes = 2, glints = 1.5, wisps = 3, arcs = true, light = { 1.5, 10 } },
	[6] = { core = C(255,250,220), edge = C(255,120, 30), sparks = 16, ring = 8, motes = 2, glints = 1.5, embers = 5, halo = 0.7, light = { 2, 12 }, outline = 0.6 },
	[7] = { core = C(240,255,255), edge = C(120,220,255), sparks = 18, ring = 8, ring2 = true, glints = 2, shell = true, orbit = 2, light = { 2, 12 }, outline = 0.5 },
	[8] = { core = C(255,250,225), edge = C(255,200, 50), sparks = 20, ring = 9, ring2 = true, glints = 2.5, goldSparkle = true, rays = true, coins = 8, light = { 2.5, 14 }, outline = 0.35 },
}
```

```lua
-- Ambient builder (client). `bag` = the bag's main BasePart (cylinder-ish). Untested sketch.
local Seq = require(script.Parent.Seq)
local GLOW = "rbxasset://textures/glow.png"
local STAR = "rbxasset://textures/particles/sparkles_main.dds"

local function ramp(cfg) -- white-hot core -> tier color -> darker edge
	return Seq.C({ { 0, cfg.core }, { 0.35, cfg.edge }, { 1, cfg.edge:Lerp(Color3.new(0, 0, 0), 0.35) } })
end

local function buildAmbient(bag: BasePart, cfg)
	local list = {}
	if cfg.motes then -- soft tier-colored motes drifting up around the bag
		table.insert(list, Seq.emitter(bag, {
			Texture = GLOW, Color = ramp(cfg), LightEmission = 1, Rate = cfg.motes, Enabled = true,
			Lifetime = NumberRange.new(1.6, 2.4), Speed = NumberRange.new(0.5, 1.2),
			SpreadAngle = Vector2.new(25, 25), Acceleration = Vector3.new(0, 0.6, 0),
			Size = Seq.N({ { 0, 0 }, { 0.2, 0.35, 0.08 }, { 1, 0 } }),
			Transparency = Seq.N({ { 0, 1 }, { 0.2, 0.2 }, { 1, 1 } }),
			Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		}))
	end
	if cfg.glints then -- star "shine" pops on the bag surface: grow fast, shrink, slight spin
		table.insert(list, Seq.emitter(bag, {
			Texture = STAR, Color = ColorSequence.new(cfg.core, cfg.edge), LightEmission = 1, Brightness = 2,
			Rate = cfg.glints, Enabled = true, ZOffset = 1,
			Lifetime = NumberRange.new(0.35, 0.55), Speed = NumberRange.new(0),
			Rotation = NumberRange.new(0, 90), RotSpeed = NumberRange.new(-40, 40),
			Size = Seq.N({ { 0, 0 }, { 0.35, 1.4, 0.3 }, { 1, 0 } }),
			Shape = Enum.ParticleEmitterShape.Cylinder, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		}))
	end
	if cfg.goldSparkle then -- the official sparkle recipe, verbatim values
		table.insert(list, Seq.emitter(bag, {
			Color = ColorSequence.new(Color3.fromRGB(255, 200, 50)), LightEmission = 1, Enabled = true,
			Lifetime = NumberRange.new(0.5, 1), Rate = 7, Speed = NumberRange.new(2, 3),
			SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.3),
			Transparency = NumberSequence.new(0.5), Drag = 1.5,
		}))
	end
	if cfg.light then
		local a = Instance.new("Attachment"); a.Parent = bag
		local l = Instance.new("PointLight")
		l.Brightness, l.Range, l.Color, l.Shadows = cfg.light[1], cfg.light[2], cfg.edge, false
		l.Parent = a
	end
	return list -- keep for distance-LOD toggling (see §7)
end
```

- **Sun-rays (T8) and pickup glow:** a BillboardGui with a Radial or Conical UIGradient Frame, as in §3. Set `Size = UDim2.fromScale(6, 6)` (studs), `LightInfluence = 0`, `Brightness = 2` and `MaxDistance = 80`. Rotate it slowly with a RenderStepped accumulator or a looped Rotation tween on the UIGradient.
- **T7 orbit glints:** parent 2 Attachments to a client-side invisible anchored "pivot" part at the bag centre. Rotate the pivot's CFrame by `dt × 90°` each frame. Each attachment carries a small star emitter (Rate 6, Life 0.4, `LockedToPart = false`), so the trail of glints draws circles. Alternatively, put a Trail between two attachments on the pivot (Lifetime 0.4, LightEmission 1).

#### 6.3 Tiered punch impact (one pooled rig, `Emit` only)

Layers, all on one Attachment aimed along the punch direction (see `aim()` in §1):

| Layer | Settings | Emit |
|---|---|---|
| **Core flash** | Texture `glow.png`, Size `{0,0}→{0.25, 2.5+0.3·tier}→{1,0}`, Lifetime 0.12, Speed 0, LightEmission 1, Brightness 1+0.25·tier, ZOffset 1.5 | 1 |
| **Ring** (FacingCamera; skip on T1) | Ring texture, Size `{0,0.5}→{1, cfg.ring}` with an ease-out curve via a mid keypoint `{0.3, 0.75·ring}`, Transparency `{0,0.1}→{1,1}`, Lifetime 0.22, LightEmission 0.6 (a bit of solid colour helps daylight), Color = cfg.edge. `ring2` adds a second, slower, larger ring (Lifetime 0.35, size × 1.4). | 1 |
| **Sparks** | Texture `spark_streak` (fallback: default sparkle), Orientation **VelocityParallel**, Squash `{0,1.5}→{1,0}`, Speed 28–45, Drag 9, SpreadAngle (55, 55) around the punch direction, Lifetime 0.15–0.35, Size `{0,0.45}→{1,0}`, Color = `ramp(cfg)`, LightEmission 1 | `cfg.sparks × vfxScale()` |
| **Dust** (T1–T3; adds weight) | Soft circle `3845808160`, LightEmission 0, LightInfluence 0.6, Color sand `210,190,160`, Size `{0,0.6}→{1,2.4}`, Transparency `{0,0.35}→{1,1}`, Speed 4–8, Drag 6, Acceleration (0, 1.5, 0), Lifetime 0.5–0.8 | `cfg.dust` |
| **Extras** | T6 embers fountain: Accel (0, −30, 0), Speed 14–22, Spread 30. T7 shards: `shard` flipbook, FlipbookStartRandom, Framerate 0, RotSpeed ±360, Accel (0, −50, 0). T8 coins: `coin` flipbook Loop 12 fps, Speed 15–25 upward, Spread 35, Accel (0, −45, 0), Lifetime 0.9–1.2, LightEmission 0. | 6 / 6 / 8 |
| **Non-particle** | Highlight fill flash (§3). PointLight on the rig: Brightness 0 → 2+0.5·tier → 0 over 0.15 s (T4+). Juice hit-stop and camera kick scaled by tier. | — |

- Budget check: a T8 punch is 1 + 2 + 20 + 8 ≈ **31 particles**, each living ≤ 1.2 s. That fits the ~30–40-per-punch mobile ceiling in §4.
- Keep the existing `Juice.burst` call signature, but swap its ring layer to a real ring texture. It currently uses the default sparkle star.

#### 6.4 Gold "shine" sweep (T8 bag, gold trophies, rare items)
- Glints, as in the builder above.
- A periodic **specular sweep**: a thin Neon white Part (0.15 studs wide), welded diagonally, tweened across the bag's front with Transparency 0.2 → 1 every 2.5–4 s.
- For UI icons of rare items, tween `UIGradient.Offset` from (−1, 0) to (1, 0) on a white→transparent→white Linear gradient at `Rotation = 25`.

#### 6.5 Wall-breaking effect
Run it client-side and spawn everything locally.

**Debris chunks**
- 8–12 small unanchored Parts (0.4–1.2 studs) in the wall's colours, positioned on the wall face.
- Settings: `AssemblyLinearVelocity = (punchDir × 25 + up × 15 + random × 8)`, `AssemblyAngularVelocity` random ±10.
- Give them a CollisionGroup that ignores players.
- Fade the last 0.4 s, then call `Debris:AddItem(chunk, 2.5)`. Cap chunks at 6 on touch devices.

**Particle layers**
- **Dust cloud:** smoke puff, Emit 8, Size `{0,2}→{1,6}`, Speed 6–12, Drag 4, LightEmission 0, LightInfluence 0.8, Color = wall colour lerped 50% to light grey, Lifetime 0.8–1.4.
- **Chips:** `SquareParticle.png` or the shard flipbook, Emit 14, Speed 20–35, Accel (0, −60, 0), RotSpeed ±400, Size 0.25–0.4, Lifetime 0.6–1.
- **Ground ring:** `groundDisc()` from §3, diameter 10, 0.3 s, in tier colour.

**Feedback and aftermath**
- Big camera kick plus a 60–80 ms hit-stop.
- Optional crack decal on the remaining wall that fades over 2 s.

#### 6.6 Level-up burst (≈ 0.8 s)
1. **0 s:**
   - Ground ring (`groundDisc`, 8 studs, 0.3 s).
   - Upward column: a Beam from the feet to +12 studs with Width0 3 and Width1 0, a glow texture, LightEmission 1, and a 0.4 s Transparency tween to 1.
   - 24 star particles: Speed 12–20 up, Spread 35, Accel (0, −25, 0), RotSpeed ±180, Size `{0,0.6}→{1,0}`, Lifetime 0.6–0.9.
2. **0.05 s:** a white Highlight flash on the character and the UI pop.

#### 6.7 Rebirth explosion (≈ 1.6 s, the loudest effect in the game)
1. **Anticipation (0–0.35 s):**
   - An implosion emitter on a 10-stud invisible Ball part around the player: `Shape = Sphere`, `ShapeStyle = Surface`, `ShapeInOut = Inward`, Speed 25, Lifetime 0.35, Rate 60 for 0.3 s, white → rebirth colour, LightEmission 1.
   - Brightness ramp on a PointLight (0 → 4).
2. **Impact (0.35 s):**
   - Core flash (`glow.png`, size → 14, 0.2 s).
   - Two `groundDisc`s (12 and 18 studs, staggered by 0.08 s).
   - A `shockSphere` (ForceField, 16 studs, 0.5 s).
   - Star burst of 30: Speed 25–45, Drag 4, Accel (0, −30, 0).
   - Confetti of 40 (6.8).
   - Camera kick, and a full-screen white ImageLabel flash 0.6 → 1 over 0.25 s.
3. **Dissipation (0.4–1.6 s):** lingering motes Rate 15 for 1 s, LockedToPart on the character's HumanoidRootPart attachment.
4. **Sustained "reborn" aura (optional, a few seconds):** the T6-style halo ring under the feet, with the motes recipe at Rate 4.

#### 6.8 Confetti
Two ways to get multiple colours:
- **(a)** 4 emitters, one per colour, each using `SquareParticle.png`.
- **(b)** One emitter with a 2×2 coloured `confetti` flipbook, `FlipbookStartRandom = true`, `FlipbookFramerate = NumberRange.new(0)` and **Color white**.

Emitter settings:
- `Speed` 25–40 along +Y.
- `SpreadAngle` (35, 35).
- `Acceleration` (0, −22, 0).
- `Drag` 1.5.
- `Lifetime` 2.2–3.
- `Size` 0.3–0.4 (use an envelope).
- `Rotation` 0–360, `RotSpeed` −360..360.
- `LightEmission` 0, `LightInfluence` 0.3.
- **Flutter:** an oscillating `Squash` sequence `{0,0}→{0.2,0.8}→{0.4,-0.6}→{0.6,0.8}→{0.8,-0.6}→{1,0}` fakes paper flipping.
- `Transparency` 0, fading `{0.85,0}→{1,1}`.
- Emit 40 for a ring win or rebirth; 15 for small rewards.

#### 6.9 Steam vent (manholes, food stands, laundromat)
- Soft circle or `smoke_main.dds`, `Orientation = FacingCameraWorldUp`.
- `Rate` 6–8, `Lifetime` 1.4–2, `Speed` 4–6 up, `SpreadAngle` (10, 10), `Drag` 1, `Acceleration` (0.6, 0.8, 0) drift (or `WindAffectsDrag = true` with GlobalWind).
- `Size` `{0,0.6}→{1,3.5}`.
- `Transparency` `{0,1}→{0.1,0.45}→{1,1}`.
- `Rotation` 0–360, `RotSpeed` −25..25.
- `Color` white → `220,225,230`, `LightEmission` 0, `LightInfluence` 0.4.
- For puffs, toggle `Enabled` on for 1.5 s every 4–6 s (random). Only ~10 particles are live.

#### 6.10 Neon flicker (signs, broken street light)
One client loop over a CollectionService tag. Use long stable periods and short stutter bursts, and keep it to a handful of signs.

```lua
local CollectionService = game:GetService("CollectionService")
local RNG = Random.new()
local function flicker(part: BasePart)
	local light = part:FindFirstChildWhichIsA("Light", true)
	local on = part.Color
	local off = on:Lerp(Color3.new(0, 0, 0), 0.6)
	task.spawn(function()
		while part.Parent do
			task.wait(RNG:NextNumber(2.5, 8))                 -- stable "on" period
			for _ = 1, RNG:NextInteger(2, 5) do               -- stutter burst
				part.Material, part.Color = Enum.Material.SmoothPlastic, off
				if light then light.Enabled = false end
				task.wait(RNG:NextNumber(0.03, 0.09))
				part.Material, part.Color = Enum.Material.Neon, on
				if light then light.Enabled = true end
				task.wait(RNG:NextNumber(0.04, 0.16))
			end
		end
	end)
end
for _, p in CollectionService:GetTagged("NeonFlicker") do flicker(p) end
CollectionService:GetInstanceAddedSignal("NeonFlicker"):Connect(flicker)
```

#### 6.11 Ambient map effects (The Block)
- **Street dust:** the official dust-motes approach, scaled down. Use several medium invisible volume parts over walkable streets (as in Duvall's grid), not one giant one. Each gets Rate 8–15, Life 4–8, Size ≈ 0.2, warm tint, `ZOffset` −5, `WindAffectsDrag`.
- **Sparkles on collectibles:** the official sparkle recipe at Rate 2–3.
- **Rooftop/neon bloom:** Neon trim plus SurfaceLights; see §3.
- **Leaves or paper scraps:** `FacingCameraWorldUp`, the Squash flutter, GlobalWind.
- **Fire-barrel embers:** Rate 4, Accel +Y 3, Life 1–1.5, LightEmission 1, plus a flickering PointLight.

#### 6.12 Floating gem/coin pickup glow
- Model or mesh: bob ±0.4 studs over a 1.6 s Sine looped tween, and spin about Y at 90°/s on the client.
- Effects:
  - BillboardGui Radial-gradient halo (§3), 3 × 3 studs.
  - Star glints at Rate 1.5.
  - PointLight Brightness 1, Range 6 for rare items only.
- On pickup:
  - Emit 8 stars (Speed 6–10, Life 0.35).
  - Shrink the item with Back/In over 0.15 s.
  - Then fly the UI icon to the HUD (see the existing Juice/UIMotion code).
- Rarity → glow colour + glint rate + Highlight outline (legendary only).

### Gaps
- None of the values in 6.1–6.12 except the cited official recipes have been tested in Studio. They need a tuning pass on a real phone at low quality.
- I didn't verify Disc rim emission (`ShapePartial = 1`) as a ground-ring technique, nor `SpreadAngle` orientation for horizontal ring bursts.

---

## 7. Performance budgets and cleanup: particle counts, mobile, beams/trails, Highlights, lights, quality levels, Debris vs Enabled vs Emit

### Takeaway
The GPU cost of VFX is mostly **fill-rate and overdraw**: big, overlapping, transparent quads. It is not raw particle count.

Practical rules for Hood:
- Keep live ambient particles per screen at roughly **150–300 on mobile** (community guidance, search summary).
- Hard caps per emitter are **400/s (100/s mobile)**.
- Graphics quality scales `Rate` but reportedly **not `Emit()`**, so you must scale bursts yourself.
- Keep **one persistent Highlight per highlighted bag**, never create/destroy.
- Use few lights with Shadows off.
- Spawn all VFX on the client and distance-cull ambient emitters.

### Cited Findings

**Official limits and warnings**
- Per-emitter rate is **400/s, or 100/s on mobile** — [Particle emitters guide](https://create.roblox.com/docs/effects/particle-emitters).
- Particle size costs fill-rate: "The more pixels particles occupy on a player's screen, the more costly it is on the GPU." — same source.
- Overlapping particles cost overdraw: "The more layers of transparent effects on screen, the more costly it is on the GPU." — same source.
- "Decals, textures, and particles don't batch well and introduce additional draw calls… **property changes to ParticleEmitters can have a dramatic impact on performance**." — [Roblox Docs: Improve performance](https://create.roblox.com/docs/performance-optimization/improve)
- Flipbooks are auto-disabled on low-memory devices — [Particle emitters guide](https://create.roblox.com/docs/effects/particle-emitters).
- Lifetime is capped at 20 s — [Particle emitters guide](https://create.roblox.com/docs/effects/particle-emitters).
- Duvall Drive split rain across several emitter volumes "because of the particle count limit" — [Duvall Drive](https://create.roblox.com/docs/resources/the-mystery-of-duvall-drive/develop-a-moving-world).
- Beams, trails and particles can change appearance with device graphics settings; test at the lowest and highest Editor Quality Level — [Beams](https://create.roblox.com/docs/effects/beams); [Trails](https://create.roblox.com/docs/effects/trails).

**Particle caps and budgets** (search summary)
- Reported caps: about **16,000 total particles on PC/Xbox and 3,500 on mobile**.
- Practical budgets: **500–800 active particles on desktop, 150–300 on mobile**.
- Sources: [DevForum: performance threads](https://devforum.roblox.com/t/improve-the-performance-of-particleemitters/3547121); [kitsblox: Roblox Particle System Deep Dive](https://kitsblox.com/blog/roblox-particle-system-deep-dive). The budget figures come from a third-party blog, so treat them as heuristics.

**Graphics-quality scaling** (search summary)
- Quality scales emitter rate roughly as `Rate × QualityLevel / 10`.
- `:Emit()` reportedly **ignores** graphics quality, so bursts are full strength even at level 1.
- Sources: [DevForum: Graphics quality lowering particle emission rates?](https://devforum.roblox.com/t/graphics-quality-lowering-particle-emission-rates/1241979); [DevForum: A way to make ParticleEmitter rate ignore graphics quality](https://devforum.roblox.com/t/a-way-to-make-particleemitter-rate-ignore-graphics-quality/474762)
- A more recent Engine Bugs thread titled **"Particle Emitters no longer change Rate with graphics quality"** exists, which suggests this behaviour may have changed or regressed recently. I couldn't read its content. — [DevForum thread 4834736](https://devforum.roblox.com/t/particle-emitters-no-longer-change-rate-with-graphics-quality/4834736)
- A feature request for particle throttling and a player-controlled particle count also exists — [DevForum 4726039](https://devforum.roblox.com/t/add-particle-throttling-and-a-player-controlled-particle-count-setting/4726039). **(search summary)**

**Reading quality from scripts** — API dump, [Client Tracker](https://github.com/MaximumADHD/Roblox-Client-Tracker)
- `UserGameSettings.SavedQualityLevel` (enum `SavedQualitySetting`: Automatic, QualityLevel1–10) is **readable by game scripts**.
- `GraphicsQualityLevel` (the actual automatic level) is `RobloxScriptSecurity`, so it is **not readable**.
- `RenderSettings.QualityLevel` is plugin-only.

**Highlights**
- 255 slots.
- The first visible Highlight costs up to about 1 ms GPU on mobile.
- On mobile, cost scales with screen coverage.
- Invisible Highlights cost nothing.
- Add/remove triggers a rebuild, while property changes are lightweight.
- Source: [Highlighting objects](https://create.roblox.com/docs/effects/highlighting)

**Cleanup**
- `Debris:AddItem` is non-yielding, guaranteed, and capped at 1,000 items.
- Alternatives are `task.delay(t, inst.Destroy, inst)`, which won't run if the script is destroyed.
- Source: [Roblox API: Debris](https://create.roblox.com/docs/reference/engine/classes/Debris)
- `Enabled = false` lets particles finish; `Clear()` removes them now — [Roblox API: ParticleEmitter](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter).
- Destroying an emitter right after `Emit()` kills the burst — [DevForum](https://devforum.roblox.com/t/issues-with-particleemitteremit/3325717) **(search summary)**.

### Inferences

**Hood budget sheet** (mobile-first; desktop can be about 2× via `vfxScale()`)

| Item | Budget |
|---|---|
| Ambient live particles per visible bag | T1–T3 ≤ 4, T4–T6 ≤ 12, T7–T8 ≤ 18. With about 8 bags on screen, that's ~80. |
| Map ambience (dust, steam, sparkles) in view | ≤ ~100 live |
| Per-punch burst | ≤ ~31 at T8 (see 6.3). Rapid punching at 4–5 hits/s therefore keeps at most ~60–80 burst particles alive. |
| Rebirth or win | ≤ ~150 for 1–2 s (rare and acceptable) |
| Particle size | Keep big soft layers (flash, smoke, halo) short-lived: under 0.3 s for flashes. Fill-rate matters more than count. |
| Highlights | ≤ 1 per T6–T8 bag plus the local character. Never per-hit. |
| Dynamic lights | About 1 per T4+ bag, 4 SpotLights at the ring, plus signs. `Shadows = false` on all. Distance-cull bag lights with their emitters. |
| Beams and trails | Low `Segments` (1 for straight beams; 8–12 for curves). Trails `Enabled` only during swings. |
| Flipbooks | ≤ 4 unique sheets, 512² preferred. Share them across tiers via `Color` tinting. |
| Debris parts | ≤ 12 per wall break (6 on touch devices), destroyed within 2.5 s |

**Scale bursts yourself, and cull ambient by distance on a slow timer**

```lua
local UIS = game:GetService("UserInputService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local function vfxScale(): number
	local q = UserGameSettings.SavedQualityLevel
	local s = if q == Enum.SavedQualitySetting.Automatic then 1 else math.clamp(q.Value / 10, 0.35, 1)
	if UIS.TouchEnabled and not UIS.KeyboardEnabled then s *= 0.65 end -- phones/tablets
	return s
end
local function emitScaled(pe: ParticleEmitter, n: number)
	pe:Emit(math.max(1, math.round(n * vfxScale())))
end

-- Distance LOD: every 0.5 s, enable a bag's ambient emitters/lights only within 70 studs of the camera.
-- `registry` = { { pos = Vector3, emitters = {ParticleEmitter}, lights = {Light} } } built by buildAmbient.
local function lodLoop(registry)
	task.spawn(function()
		while true do
			local cam = workspace.CurrentCamera.CFrame.Position
			for _, e in registry do
				local near = (e.pos - cam).Magnitude < 70
				for _, pe in e.emitters do if pe.Enabled ~= near then pe.Enabled = near end end
				for _, l in e.lights do if l.Enabled ~= near then l.Enabled = near end end
			end
			task.wait(0.5)
		end
	end)
end
```

**General rules**
- **Toggle, don't animate:** only write emitter properties when the value actually changes. The docs warn that ParticleEmitter property changes are expensive, so never tween emitter properties every frame. Animate parts, lights, beams and GUIs instead.
- **Pooling:** use one impact rig per client, re-aimed per hit. Use `Debris:AddItem(part, maxLifetime + 0.1)` only for one-off spawned parts such as shockwave meshes and chunks. Never destroy an emitter in the same frame as `Emit`.
- **Client-only VFX:** server scripts in `hood/src/ServerScriptService` should send `{kind, tier, pos, dir}` over the existing `Net` remotes, and clients build and render. Ambient bag VFX should also be built client-side, keyed on a bag `Tier` attribute, so the server replicates no emitter instances.
- **Quality-test matrix:** Studio Editor Quality Level 1 and 21, plus a real low-end Android phone on Automatic. Check:
  - that every tier is still distinguishable without Bloom (colour + outline + light, not Neon glow alone);
  - that bursts don't hitch;
  - that additive effects remain readable against the daytime sky.

### Gaps
- I found no official, current per-device total-particle cap. The 16,000/3,500 and 150–300 figures are unverified community numbers.
- I couldn't read the recent "no longer change Rate with graphics quality" thread, so whether quality still scales `Rate` in late 2026 is unconfirmed. Design so effects look acceptable both ways.
- I found no official dynamic-light count or cost guidance for mobile.
- I found no measured per-Beam or per-Trail cost.
