# Roblox aura VFX: sourced notes and lessons from building HoodVFX (Oct 2026)

These notes back the `roblox-vfx` skill (`.claude/skills/roblox-vfx/SKILL.md`). They add to
`research_notes/Tiered props VFX and vibrant maps/vfx_handbook.md`, which already covers every ParticleEmitter /
Beam property, built-in textures, the punch-impact recipe and performance budgets. Read that first; this file
covers what the handbook did not: aura clouds, curly wisps, flipbook authoring, layering for a daylight map, and
what the offline renders taught while tuning the training stations.

**Sources and how far to trust them**
- **[Docs]** A local clone of the Roblox creator-docs repo (same text as create.roblox.com). The
  live site, the DevForum, realtimevfx.com, 80.lv, iquilezles.org and most VFX blogs were blocked by the egress
  proxy this session.
- **[Search]** Search-result summaries only (the page itself could not be opened). Treat as hints.
- **[Measured]** Seen in this repo's offline renderer (three.js, no bloom, approximate blending). Good for
  composition, colour and density; not for exact brightness.
- **[Inference]** My own recommendation.

---

## 1. Flipbooks: what the engine actually does

- Layouts: None, Grid2x2 (4 frames), Grid4x4 (16), Grid8x8 (64), and **Custom** with `FlipbookSizeX` (columns) and
  `FlipbookSizeY` (rows). **[Docs]** `reference/engine/classes/ParticleEmitter.yaml`
- The texture size "must be an exact multiple of the flipbook layout size" (error text in
  `FlipbookIncompatible`). **[Docs]** Older guidance said 1024x1024 only; a power-of-two square up to 1024 is the
  safe choice. **[Inference]**
- `FlipbookMode`: **[Docs]**
  - Loop: plays all frames, repeating, at `FlipbookFramerate` (a NumberRange, max 30 fps).
  - **OneShot**: ignores the framerate; the animation spans the particle's Lifetime ("an explosion that creates
    a puff of smoke and then fades out"). This is the mode for a wisp that grows, curls and breaks up once.
  - PingPong: forward then back.
  - Random: random frames with crossfades ("stars slowly twinkling").
- `FlipbookStartRandom` + `FlipbookFramerate = 0` gives every particle one random static frame: one sheet, four
  cloud shapes. **[Docs]**
- `FlipbookBlendFrames` (default true) crossfades between frames. **[Docs]**
- Memory: "clients automatically deactivate flipbooks when they are low on memory, which is likely for older
  mobile phones ... use fewer unique animated particle effects or choose a texture of smaller resolution."
  **[Docs]** `tutorials/use-case-tutorials/vfx/create-volcanoes.md`
- Roblox's own lava splashes use **two emitters with the same 8x8 flipbook and slightly different settings** so
  the loop is hard to spot, plus a third "aerated" emitter to fill gaps. **[Docs]** create-volcanoes.md

**Consequence for code** **[Inference, applied in HoodVFX]**: a flipbook layout must only be set when the real
sheet is the Texture. If the texture falls back to a built-in single image, a Grid4x4 layout shows a quarter of
it. HoodVFX keeps a `FLIPBOOK` table and applies it only when `Textures[name]` holds an uploaded id.

## 2. Official reference values for clouds, smoke, mist and embers

All **[Docs]** from the creator-docs tutorials (values as written there):

| Effect | Key settings |
|---|---|
| Volcano smoke plume (`create-volcanoes.md`) | thick-smoke texture, Color black -> light peach -> grey, Transparency in then out, **ZOffset -10**, Lifetime 50-60, Rate 0.3, Rotation -360..360, RotSpeed -5..5, SpreadAngle 5, Acceleration (0, 7, 0), Drag 1, LightEmission 0.1, **LightInfluence 0.06** |
| Waterfall mist (`create-waterfalls.md`) | thick-mist texture, Color blue -> white, Size grows steadily, Transparency in, slightly opaque, out, ZOffset 2, Lifetime 0.5-1, Rate 20, RotSpeed -50..50, Speed 35-50, Spread 25, Acceleration (-10, -25, -10), Drag 1.5 |
| Lava ripples / foam (`create-volcanoes.md`, `create-waterfalls.md`) | **Orientation VelocityPerpendicular** with Speed 0.01: flat decals on the surface. Rate 5-12, Rotation 0..360, RotSpeed -15..15, LightEmission 0.25-1 |
| Embers (`create-volcanoes.md`) | elongated oval texture, **VelocityParallel**, Squash rises mid-life, Transparency flickers randomly, ZOffset 1, Lifetime 1-5, Speed 5-8, Spread 180, Acceleration (0, 10, 0), Drag 0.8, LightEmission 1, Brightness 20 |
| Lava splashes | **FacingCameraWorldUp**, 8x8 OneShot flipbook, Rate 0.29-0.37, RotSpeed -20..20, Spread 5, Drag 0.5, LightEmission 0.1, LightInfluence 0.25 |

Patterns worth copying:
- **Smoke and mist are nearly normal-blended** (LightEmission 0.1, low LightInfluence). Only embers, sparks and
  glows are fully additive.
- **ZOffset is used for layering**: negative for big background smoke, positive for small bright bits.
- **VelocityPerpendicular + Speed 0.01** is the official way to lay a particle flat (ripples, foam, ground rings).
- **FacingCameraWorldUp** for things that must stay upright (splashes, flames, light shafts).

## 3. How pros make stylized smoke and wisp textures

- A Substance Designer breakdown of stylized smoke: start from low-scale Cells noise, inverted; warp it with
  blurred Gaussian noise ("warp intensity defines how soft or sharp the whisps will be"); build the puff
  silhouettes as a tiny 2x2 flipbook of four soft paraboloid shapes, then warp those with low-scale Perlin noise.
  **[Search]** realtimevfx.com "Stylized Smoke Texture (Substance Designer Breakdown)"
- Ways to make smoke sheets: fluid sims rendered to an atlas (Houdini/Blender), photo/cloud-noise manipulation,
  or hand painting, which "is the best option" for a stylized look. **[Search]** realtimevfx.com "Smoke sprite
  sheet" thread
- Domain warping (noise sampled at coordinates offset by other noise) is the standard cheap way to make smoke,
  energy and nebula shapes look directed instead of random. **[Search]** gamedev.net shaderlab "domain warped noise"
- Roblox's own lightning texture was "a squiggly line, then an Outer Glow layer effect". **[Docs]** (via the
  handbook, Duvall Drive)
- Roblox texture rules: grayscale, transparent background, blurred edges; up to 1024x1024. **[Docs]**

What `hood/art/vfx/make_aura_textures.js` does with that (pure Node, no image library) **[Measured]**:
- **Clouds**: a cumulus cluster of 9 paraboloid lobes (a wide base row, smaller lobes billowing up), lookups
  domain-warped by fbm so edges curl, alpha = smoothstep of the summed density, and **shading from a per-lobe
  sphere normal lit from the upper left** (grey 0.58-1). The grey is what gives the tinted cloud volume.
- **Curly wisps**: a clothoid path (curvature grows along the length: k = k0 + k1 * s^2.2) gives the classic
  "curly-Q" that starts straight and ends in a tight spiral. Two bright edge lines either side of a faint body
  give the inked-smoke look of the reference. A branch peels off a third of the way up and curls the other way.
  Over 16 frames: the tendril draws in (frames 0-6), keeps curling, then the base detaches and fbm erosion breaks
  it up (frames 8-15).
- **Flames**: a teardrop half-width profile (round belly, long taper), sideways sway that grows with height,
  sampled from noise along a circle in time so the 16 frames loop seamlessly; a white inner core over a grey
  outer flame so a colour ramp reads as hot centre and coloured edge.
- **Arcs**: recursive midpoint displacement with two branches; a thin core plus two blurred glow passes.
- **Every texture fades to zero alpha in its outer 4%**. Without that, a large soft quad with a tiny non-zero
  alpha at its border shows a straight edge when several overlap (seen on the first mist render).
- **Flipbook frames are padded** (16 px in 512 cells, 8 px in 256 cells) and faded inside the cell, so mip
  filtering never bleeds one frame into the next.

## 4. Layering an aura that reads in daylight

The reference (an aura simulator; screenshots the user shared on 2026-10-06) shows each training pad with big soft
coloured clouds billowing off it, curly white wisp lines, sparkles, neon trim on the pad, and stronger effects
on higher tiers. Lessons from rebuilding it **[Measured]**:

1. **Additive washes out on a bright map.** With LightEmission 0.2 the red mist rendered pink-white over the pale
   paving; at 0.05 it read red. Clouds and spill are near-normal blended; only glows, sparks, arcs and wisp
   lines are additive. (Same conclusion as the Roblox volcano smoke at LightEmission 0.1.)
2. **Pale additive colours stack to a white blob.** White and gold auras need their additive layers dimmed. HoodVFX
   scales additive opacity by `hot = 1 - max(0, luminance - 0.55)`.
3. **Brightness > 1 desaturates.** Fire at Brightness 1.4 turned pink-white; at 1 it stayed orange-red.
4. **Fire needs a warm birth colour.** Tinting the flame texture with the tier colour alone looks like coloured
   smoke. Starting at `color:Lerp(yellow, 0.55)` and ending at the tier colour then a dark shade reads as fire for
   any hue.
5. **ZOffset is a depth push, not a draw-order flag.** Mist at ZOffset -3 vanished behind the platform deck when
   seen from above. -1.5 keeps the clouds behind the hanging bag without losing the low puffs.
6. **Light shafts in front of the subject wash it out.** God-ray beams at the deck centre turned the gold bag into
   a white smear; at the sides and back of the deck, leaning outward, they frame it.
7. **The focal object must stay readable**: bag visible at every tier; effects concentrate low and around it.
8. **Escalate by adding a channel per tier and growing size/brightness, not by multiplying counts.** The final
   ladder: T1 floor glow + dust, T2 mist + spill + core glow + light, T3 wisps, T4 glints + sparks + ground ring,
   T5 floor vortex + arcs, T6 edge flames + wisps through the column, T7 god rays, T8 gold glitter, T9 rainbow.
9. **Fallbacks need their own tuning.** Built-in smoke puffs standing in for wisps smothered the station; HoodVFX
   fades fallback wisps/arcs (x0.45 / x0.6 opacity) and skips the high wisp layer until the real sheet is uploaded.

## 5. Performance

- Per-emitter rate cap 400/s (100/s on mobile); Lifetime capped at 20 s. **[Docs]** (handbook §1)
- Particle cost is mostly fill rate and overdraw: "The more pixels particles occupy ... the more costly"; "The
  more layers of transparent effects on screen, the more costly". **[Docs]** (handbook §7)
- A single emitter: "up to 400 particles per second (100 per second on mobile)" and large sizes cost GPU fill
  rate; set fill-rate budgets instead of setting Rate and Size blindly. **[Search]** (summaries of the particle
  emitter docs and a third-party "roblox-vfx" skill page)
- Community budgets: ~150-300 live particles on screen on mobile, 500-800 on desktop. **[Search]** (handbook §7)
- Measured HoodVFX budgets (Rate x mean Lifetime on the 10.4 x 8.8 deck): T1 12, T2 26, T3 35, T4 47, T5 55,
  T6 77, T7 89, T8 106. Spawn (T1-T3) totals ~75. **[Measured]** The expensive part is ~25 big quads (mist,
  spill, glows, rays) at the top tiers; they grow in size, not count. **[Inference]** Cull auras beyond ~120
  studs and halve rates on low graphics with `HoodVFX.setEnabled` / `setDensity`.

## 6. Engine details confirmed while building

- `ParticleEmitter`, `Beam`, flipbook, `Orientation`, `ZOffset`, `Squash`, `WindAffectsDrag`, `ShapePartial`
  and `FlipbookLayout.Custom` all exist in Lune 0.10.5's reflection database (the harness), so code using them
  loads offline. **[Measured]**
- Offline tools (Lune's DOM) store an Attachment's `CFrame` but do not derive it from `Position`: set
  `att.CFrame = CFrame.new(pos)` so previews place it right. In the engine both work. **[Measured]**
- Lights only preview when parented straight to a part (the harness exports part children). **[Measured]**

## Gaps

- No source for the exact `Squash` formula; the renderer assumes height x 2^(s/2), width x 2^(-s/2).
- No measurement on a real phone; the budgets above are counts, not GPU timings.
- I could not see the built-in `.dds` textures; the renderer's stand-ins (`render/vfx/smoke.png`, `flame1.png`)
  are approximations, so the `builtinOnly` previews are only a rough guide to the pre-upload look.
