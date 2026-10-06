---
name: roblox-vfx
description: Build, tune and preview Roblox visual effects (ParticleEmitter, Beam, Trail, lights, Neon) that look professional and stay cheap - auras, mist and smoke clouds, curly wisps, sparks, fire, electricity, god rays, ground rings, item glows, punch impacts and tiered "rarity" escalation. Use it whenever you add or change effects in this repo (HoodVFX, station auras, gun pedestals, Juice bursts), make particle/flipbook textures, or need to check an effect in the offline harness + renderer before it ships.
---

# Roblox VFX: layered, tiered, cheap

The house module is `hood/src/ReplicatedStorage/Shared/HoodVFX.lua` (`station`, `item`, `setEnabled`,
`setDensity`, `Textures`, `TierColors`). Reuse it before writing new emitters. Longer sourced notes:
`research_notes/Roblox VFX/aura_vfx_notes.md` and `research_notes/Tiered props VFX and vibrant maps/vfx_handbook.md`
(every property, built-in texture list, punch-impact recipe, budgets).

## 1. Principles

1. **Layer, don't pile.** Every good effect is 4-7 layers with different jobs:
   core glow (additive, big, few) -> volume (mist/smoke clouds, near-normal blend) -> detail (wisps, arcs,
   flames) -> sparkle (glints, sparks, glitter, additive, small) -> ground (flat glow, ring, vortex) -> light
   (one PointLight, Shadows off). Each layer has its own size, speed and lifetime.
2. **The subject stays readable.** The bag/item/player is the focal point; push clouds behind it
   (ZOffset -1..-2), keep sparkles in front (+0.5..+1.5), frame it with beams instead of covering it.
3. **Daylight kills additive.** On a bright map, additive (LightEmission 1) clouds turn into white fog. Clouds,
   smoke and spill: LightEmission 0-0.1 with saturated colour. Additive only for glows, sparks, arcs, wisp lines.
4. **Pale additive colours stack to white.** Dim additive opacity for white/gold/cyan glows
   (`hot = 1 - max(0, luminance - 0.55)`). Keep `Brightness` at 1 for coloured fire; > 1 desaturates.
5. **Value and shape carry the read, hue carries the tier.** White-hot core, tier colour on edges, darker tail.
6. **Always randomise:** ranges on Lifetime, Speed, Rotation, RotSpeed; envelopes on Size; random flipbook start.
7. **Fade in and out** (Transparency 1 at t=0 and t=1) so nothing pops. Textures fade to zero alpha at their border.
8. **Escalate by channel, not count.** Each tier adds one new kind of thing and grows size/brightness ~10-20%.
9. **Effects are client-cheap or they don't ship**: budget live particles and big overlapping quads (sec. 7).

## 2. Property cheat-sheet (starting values)

| Property | Use | Good start |
|---|---|---|
| `LightInfluence` | always set it: Instance.new gives 0, Studio insert gives 1 | 0 for glows/auras, 0.3-1 for confetti/dust that should be lit |
| `LightEmission` | 0 normal blend, 1 additive | clouds 0-0.1, wisps 0.6, flames 0.7, glows/sparks/arcs 1 |
| `Brightness` | HDR push when LightInfluence 0 | 1 (coloured), 1.5-2.5 sparkles, arcs 2-3 |
| `Transparency` | NumberSequence over life | `{0,1},{0.2,0.4},{0.7,0.5},{1,1}` |
| `Size` | NumberSequence, envelope = per-particle random | grow clouds 3 -> 7 studs; pop glints 0 -> 0.7 -> 0 |
| `Squash` | >0 taller/thinner | streak sparks 1-1.5 with VelocityParallel |
| `Rotation` / `RotSpeed` | NumberRange degrees | 0..360 / -20..20 clouds, 100-150 vortex |
| `Speed` / `SpreadAngle` | initial velocity / cone (Vector2) | mist 1-2.5 & (60,60); sparks 6-11 & (18,18) |
| `Drag` | half-life decay; > 0 needed for wind | 0.5 clouds, 1.2 sparks, 8-12 snappy bursts |
| `Acceleration` | world studs/s^2 | clouds (0,0.5,0), embers (0,3,0), debris (0,-40,0) |
| `ZOffset` | depth push toward (+) / away (-) from camera | clouds -1.5 (more and floors hide low puffs), sparkles +1 |
| `Orientation` | FacingCamera (default) | VelocityPerpendicular + Speed 0.01 = flat floor decal; FacingCameraWorldUp = upright flames/rays; VelocityParallel = streaks |
| `Shape` | on a BasePart: Box/Sphere/Cylinder/Disc fill the part | on an Attachment everything is a point (Sphere/Cylinder misbehave) |
| `Flipbook*` | sheet animation | see sec. 6; only when the sheet is the Texture |
| `Rate` | particles/s, cap 400 (100 mobile) | live count = Rate x mean Lifetime |
| Beam | `FaceCamera`, `Segments` 1 (straight) / 8-12 (curved), `TextureMode` Stretch, `TextureSpeed` 0.1-1.5 | god ray: Width0 2, Width1 4, Transparency `{0,0.45},{0.5,0.7},{1,1}`, LightEmission 0.7 |
| PointLight | real light; particles don't light the world | Brightness 0.6-2.2, Range 8-16, `Shadows = false` |

Engine gotchas: `VelocitySpread` is deprecated (use SpreadAngle); `FastForward` is not callable; Lifetime caps at
20 s; `Debris:AddItem` caps at 1000 items; never destroy an emitter in the frame you `:Emit()`; property writes on
emitters are not free (write only on change, never tween emitter props per frame).

## 3. Layer recipes (values from HoodVFX, tier k = 0..1)

**Aura on a platform** (`HoodVFX.station(deckPart, tier, color, Vector3.new(w, h, d), {smoke = c})`):
- Floor glow: softglow, VelocityPerpendicular, Speed 0.01, Rate 0.8, Life 2.5, Size w, Transparency 0.62 -> 0.32.
- Dust: dust, on the deck part, Rate 4-10, Life 2-3.4, Speed 0.6-1.6, Size 0.3, LightEmission 0.8.
- Mist: 2x2 cloud sheet with random static frame, Rate 2-5, Life 3-4, Speed 0.8-2.6, Spread 60-80, Drag 0.5,
  Accel +0.3..0.8, Size 3 -> 7..11, Transparency peak 0.45 -> 0.25, ZOffset -1.5, LightEmission 0.05,
  Color light tint -> tier colour -> 12% darker.
- Spill: soft mist, Speed 2.5-5, Spread 85 (sideways), Accel -0.4 (sinks over edges), LightEmission 0.
- Core glow: softglow on a central attachment, Size 7-11, Transparency 0.86 -> 0.6, ZOffset -2, additive.
- Wisps: 4x4 OneShot curl sheet, Rate 1.6-5.6, Life 1.6-2.4, Speed 2.5-4.5, Rotation -40..40, RotSpeed +-30,
  Size 2.8 -> 4.2..5.4, LightEmission 0.6, Color white -> light tint.
- Glints: glitter in the column part, Life 0.45-0.8, Size 0 -> 0.75 -> 0, ZOffset 1.
- Sparks: dust, VelocityParallel, Squash 1.5, Speed 6-11, Drag 1.2, Accel -2.
- Ground ring: ring, VelocityPerpendicular, Size 2 -> deck width, Life 1.6, Rate 0.45-0.75.
- Vortex: swirl texture, VelocityPerpendicular, RotSpeed 100-150, Size 0.62w -> 0.8w, Rate 0.45, Life 3.2.
- Light: PointLight in the column, Brightness 0.6 -> 2.2, Range 8 -> 16.

**Punch impact** (pooled rig, `:Emit` only, ~30 particles max): core flash (glow, Size 0 -> 2.5+0.3*tier -> 0,
Life 0.12, ZOffset 1.5) + ring (Size 0.5 -> 4-9, Life 0.22) + sparks (VelocityParallel, Speed 28-45, Drag 9,
Spread 55, Life 0.15-0.35) + dust puff on low tiers. Hit-stop 40-80 ms. Details: handbook sec. 6.3.

**Item glow** (`HoodVFX.item(part, tier, color)`, tiers 1-10): soft halo behind (ZOffset -1, Size 1.3r -> 2.5r),
glints on the item's box (T2+), rising motes (T3+), PointLight (T4+), small wisps (T5+), flames in the box with
FacingCameraWorldUp (T6+), arcs (T7+), a ray shaft + gold glitter (T8+), rainbow ramps (T9+).

**Fire**: flame flipbook (Loop 16-22 fps, random start), FacingCameraWorldUp, Life 0.6-1, Speed 2-3.5, Accel
(0,3,0), Size 2 -> 3.6 -> 2.2, Transparency `{0,0.6},{0.15,0.05},{0.7,0.25},{1,1}`, LightEmission 0.7,
Brightness 1, Color `birth = tint:Lerp(yellow,0.55)` -> tint -> 35% darker. White birth for white flames.

**Electric**: arc sheet (2x2 static random frame), Life 0.12-0.22, Speed 0, Size 2.6-3.2 (envelope 0.6),
Rotation 0..360, LightEmission 1, Brightness 2-3, white -> pale tint. For scripted bolts: 4-6 untextured
`Segments = 1` beams through jittered attachments, re-jittered 3 times over 0.15 s (handbook sec. 2).

**God rays**: 3 FaceCamera beams from the sides/back of the area leaning outward (never in front of the subject),
shaft texture, Width 1.6 -> 3.4, Transparency 0.45 base -> 1 top, LightEmission 0.7, TextureSpeed 0.15-0.35;
plus a few ray particles (FacingCameraWorldUp, Size ~0.8 x height, fading in and out over 2-3 s).

**Ground decal** (ripples, rings, vortex, floor glow): Orientation VelocityPerpendicular, Speed 0.01, emitter on
an attachment 0.05 above the floor, ZOffset 0 (negative sinks it under the floor).

## 4. Tier ladder (one new channel per tier)

| Tier | Colour (glow) | Adds | Live particles |
|---|---|---|---|
| 1 | green 90,235,110 | floor glow, faint dust | ~12 |
| 2 | cyan 70,225,255 | billowing mist, spill, core glow, point light | ~26 |
| 3 | blue 80,140,255 | curly wisps | ~35 |
| 4 | purple 180,100,255 | glints, sparks, ground ring | ~47 |
| 5 | pink 255,105,205 | floor vortex, electric arcs | ~55 |
| 6 | red 255,64,64 | flames on the edges, wisps through the column | ~77 |
| 7 | white on black 235,240,255 (grey smoke) | god rays (beams + shafts) | ~89 |
| 8 | gold 255,200,60 | gold glitter | ~106 |
| 9 | rainbow | rainbow ramps on every layer | ~120 |

Pair the VFX ladder with a model ladder (colour, material, trim, size): never change only one channel. Save the
loudest jump for the biggest multiplier.

## 5. Textures

- **White/grey on transparent**, tinted by `Color`. Grey inside the shape = shading (volume); alpha = shape.
  Fade alpha to 0 in the outer ~4% (or quads show straight edges when they overlap). Keep RGB white where alpha
  is 0 so filtering never pulls dark fringes in.
- Sizes: singles 128-512, flipbooks 1024 (2x2 of 512 or 4x4 of 256), padded 8-16 px per frame, power-of-two
  squares. A flipbook layout must match the sheet exactly and must be **off** when falling back to a built-in.
- Generator: `node hood/art/vfx/make_aura_textures.js [outDir]` (pure Node: fbm noise, domain warp, gaussian
  splats, blur, PNG writer). It makes `aura` (2x2 clouds), `wisp` (4x4 OneShot curl), `flame` (4x4 Loop), `arc`
  (2x2), `mist`, `ray`, `shaft`, `glitter`, `swirl`, `dust`, `softglow`. Older set: `make_vfx_textures.js`.
  Techniques: clouds = union of lit paraboloid lobes + warped edges; wisps = clothoid curve (curvature
  k0 + k1*s^2.2) drawn as two bright edge lines and a faint body, then eroded by noise over the frames; flames =
  teardrop profile + sway sampled on a circle in time (seamless loop); arcs = midpoint displacement + 2 glows.
- Shipping: upload each PNG (Asset Manager / Creator Hub), paste `rbxassetid://...` into `HoodVFX.Textures`.
  Until then each name falls back to a built-in: `rbxasset://textures/particles/smoke_main.dds`,
  `sparkles_main.dds`, `fire_main.dds`, `explosion01_shockwave_main.dds`, `rbxasset://textures/glow.png`
  (full list in the handbook sec. 5). Fallbacks get their own fades (no built-in looks like a wisp).

## 6. Flipbook settings

| Sheet | Layout | Mode | Framerate | StartRandom |
|---|---|---|---|---|
| variants (clouds, arcs, shards, confetti) | Grid2x2 | Loop | `NumberRange.new(0)` | true |
| one-shot life (wisp, puff, explosion) | Grid4x4 / 8x8 | OneShot (ignores framerate) | - | false |
| looping (flame, energy) | Grid4x4 | Loop | 16-22 | true |
| twinkle | any | Random | 4-10 | true |

Two emitters with the same sheet and slightly different settings hide the repetition (Roblox's lava does this).
Low-memory phones drop flipbooks: the first frame must still read on its own.

## 7. Performance limits

- Live particles on screen: aim <= 150-300 on mobile, 500-800 desktop. Per aura: T1-3 <= 35, T6-8 <= ~110 and
  only one high-tier aura on screen at a time.
- Fill rate is the real cost: count big quads (> 4 studs) per effect and keep them under ~25; make them grow in
  size per tier rather than in number. Short life for flashes (< 0.3 s).
- Rate cap 400/s (100/s mobile) per emitter; graphics quality may scale Rate but not `:Emit()`, so scale bursts
  yourself (`vfxScale()` in the handbook sec. 7).
- One PointLight per effect, `Shadows = false`. Highlights: persistent only (255 cap, creation causes rebuilds).
- Build ambient effects once; LOD on the client: `HoodVFX.setEnabled(model, dist < 120)` on a 0.5 s timer and
  `HoodVFX.setDensity(model, 0.5)` on low graphics.

## 8. Preview it offline (this repo)

Tools live in `hood/tools/preview/` (setup in its README: Lune 0.10.5, `npm install` in `render/`).
1. Work on a private copy of `hood/src` when experimenting (`cp -r hood/src /tmp/fx/src`), with your changed
   modules copied in.
2. Build a scene and export parts + particles + beams:
   `cd hood/tools/preview && lune run harness.luau <srcDir> out.json "<luau snippet>"`.
   To see the post-upload look, set every `HoodVFX.Textures[k] = 'rbxassetid://0'` in the snippet first.
   To preview one piece, put a small module in `<srcCopy>/ServerStorage/Preview.lua` that builds it into
   Workspace and call it from the snippet: `return require(game.ServerStorage.Preview).Preview()`.
3. Render: `cd hood/tools/preview/render && W=1400 H=800 node shoot.js ../out.json views.json shots/`, views.json:
   `{"options":{"time":3,"noFog":true,"builtinOnly":false},"views":[{"name":"a","pos":[x,y,z],"look":[x,y,z],"fov":55}]}`
   (template: `scripts/views_example.json`).
   `time` = seconds the emitters have run; `builtinOnly: true` ignores PreviewTexture and shows the built-in
   fallbacks (the pre-upload look). Remember +X is screen-left when the camera looks along +Z.
4. Emitters need a `PreviewTexture` attribute naming `hood/art/vfx/<name>.png`; flipbook names are listed in
   `hood/tools/preview/render/index.html` (`FLIP`). The renderer simulates Rate/Lifetime/Speed/Spread/Drag/Acceleration/Size/
   Transparency/Color/Squash/Rotation, LightEmission blending, VelocityParallel/Perpendicular, FacingCameraWorldUp,
   ZOffset and Beams. No bloom and no lighting on particles: judge composition, colour and density, not glow.
5. Test one texture at a time with the FX lab (`scripts/fxlab.luau`: one emitter per texture on a dark wall),
   or disable every emitter but one layer before export to judge it alone:
   `for _, d in workspace:GetDescendants() do if d:IsA('ParticleEmitter') and not d.Name:find('Flames') then d.Enabled = false end end`.
6. Contact sheet: `montage a.png b.png -tile 3x2 -geometry 600x400+2+2 sheet.png`. Look at every render.
7. Check the budget in the harness: paste `scripts/budget.luau` into the snippet and call `budget(model)` (sums
   `Rate * (Lifetime.Min + Lifetime.Max) / 2` per child model).

Offline-tool gotchas: set `Attachment.CFrame` (not `.Position`) so offline exports place it; lights preview only
when parented straight to a part; read `part.CFrame.Position` (Lune doesn't derive `Position`).

## 9. Checklist before shipping an effect

- [ ] Every emitter sets LightInfluence, has fades at both ends, randomised ranges, and a sane Rate x Lifetime.
- [ ] Subject readable at the highest tier; lowest tier not noisy; tiers distinguishable without bloom.
- [ ] Looks right in daylight on a pale floor (and at night: LightInfluence 0 glows stay bright).
- [ ] Flipbook layouts only with uploaded sheets; fallback look checked with `builtinOnly`.
- [ ] Budget written in a comment; LOD hook available; no per-frame emitter property writes.
