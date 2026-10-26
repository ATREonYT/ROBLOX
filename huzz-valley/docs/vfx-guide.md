# Anime VFX and cutscenes, built by code only

How top Roblox VFX artists get the cel-shaded anime look (energy slashes, crescent swooshes, shockwave rings,
swirling orbs, light pillars, lightning, screen tint, silhouettes, impact frames), rewritten for this repo's rules:
- effects are built by client scripts at runtime;
- textures are our own PNGs drawn in Python/PIL (`tools/fx/make_fx.py`, output in `assets/fx/`), which the owner
  uploads once (ids go in `Shared/Config/ImageIds` as `Fx/<name>`, as `Gameplay/AuraFX` already reads them);
- no other people's assets, meshes or ids; no Studio hand-editing;
- kid-safe: at most 1 flash per second, Reduced Motion turns off shake, FOV punches and loops.

Research notes (Oct 2026): "VysVEX"/vysdev has no public write-ups that search engines index, so this guide
takes the same style from the official Roblox docs, DevForum threads and stylised-VFX breakdowns (sources
at the end). Numbers marked *start* are starting values to tune by eye; numbers marked *doc* come from the
official docs.

---

## 1. What makes anime VFX read as "anime" (and not "rushed particles")

1. **Shape over noise.** Hard-edged, vector-like shapes (crescents, rings, spiky stars, tongues) on flat
   planes, not soft smoke. Few big shapes beat many small dots.
2. **Value hierarchy.** A white-hot core, a saturated colour band and a darker edge or outline. If every layer
   has the same brightness, size and lifetime, the effect turns to mush.
3. **Timing.** Fast in (1-3 frames to full size), hold, then snap out with a short fade. Anticipation, then
   impact, then aftermath. The impact itself lasts under 0.2 s.
4. **Restraint.** 3-5 layers per effect (core, main shape, sparks, a secondary shape, maybe dust), each
   doing one job. One motion direction per effect (everything rises, or everything bursts out).
5. **Spend tuning time on the curves.** The Size and Transparency NumberSequences decide most of the look.
   Never let a particle appear or vanish at full opacity unless that pop is the point.

---

## 2. Building blocks (no custom meshes)

### 2.1 ParticleEmitter: the properties that matter
| Property | What it does | Anime use (*start*) |
|---|---|---|
| `LightEmission` | 0 = normal blend, 1 = additive (*doc*) | 1 for the white core and glow; 0.3-0.6 for coloured bands in daylight (additive washes out on bright ground); 0 for dark outline layers |
| `LightInfluence` | 0 = ignores scene light. Defaults to 0 from `Instance.new`, 1 from Studio (*doc*) | Always set 0 explicitly |
| `Brightness` | Scales emitted light when LightInfluence is 0 (*doc*) | 1-3 for cores; keep 1 for coloured layers so the hue doesn't blow out to white |
| `ZOffset` | Moves the render toward the camera in studs, fractional OK (*doc*) | Core +0.3, main 0, outline -0.2, so layers sort the same from every angle |
| `Orientation` | FacingCamera, FacingCameraWorldUp, VelocityParallel, VelocityPerpendicular (*doc*) | VelocityParallel + Squash = streak sparks; VelocityPerpendicular + Speed 0.01 = a flat decal-like particle (ground rings, sigils) |
| `Squash` | NumberSequence; >0 makes particles thin and tall, <0 wide and short (*doc*) | Sparks: 0 -> 1.5 -> 2.5 stretch as they fly |
| `Shape` / `ShapeStyle` / `ShapeInOut` / `ShapePartial` | Box/Sphere/Cylinder/Disc; Volume or Surface; Outward/Inward/both; Disc ShapePartial = inner radius (1 = rim only), Sphere = hemisphere angle (*doc*) | Disc + Surface + ShapePartial 1 + Outward = a ring of dust bursting out; Sphere + Inward = energy sucked into an orb. Sphere/Cylinder only work on a BasePart, not an Attachment (*doc*) |
| `FlipbookLayout` | None, Grid2x2, Grid4x4, Grid8x8, Custom (`FlipbookSizeX/Y`) (*doc*) | 4x4 at 1024 px (256 px frames) is the sweet spot |
| `FlipbookMode` | Loop, OneShot (plays once over Lifetime, ignores framerate), PingPong, Random (crossfades random frames) (*doc*) | OneShot for slashes and bursts; Random for twinkles |
| `FlipbookFramerate` | NumberRange, max 30 fps (*doc*) | 12-24 for flames |
| `FlipbookStartRandom` | Random start frame; with framerate 0 each particle shows one random frame (*doc*) | One sheet of 4 spark variants = variety from a single texture |
| `TimeScale` | 0-1: 1 normal, 0.5 half speed, 0 frozen (*doc*) | Hit-stop and slow motion (section 4.4) |
| `LockedToPart` / `VelocityInheritance` | Particles move with the parent (*doc*) | Aura on a moving girl: LockedToPart for the sigil; VelocityInheritance 0.3-0.6 for flames so they lag a little |
| `Rotation` / `RotSpeed` | NumberRange of start angle and spin | Rotation (0,360) always, so repeats don't line up; RotSpeed (-40,40) for slow spin |
| `:Emit(n)` | Emits n particles at once (*doc*) | All one-shot bursts: `Rate = 0`, `Enabled = false`, then `:Emit(n)` |

**Flat-particle trick:** `Orientation = VelocityPerpendicular`, `EmissionDirection = Top`, `Speed = 0.01`
(exactly 0 renders nothing), `SpreadAngle = (0,0)`, parented to an Attachment pointing up. The particle lies
flat, so a ring or sigil texture becomes a ground decal that keeps LightEmission, Size curves and RotSpeed.
DevForum threads report jitter when it is LockedToPart inside a moving character; if it shakes, emit from an
anchored part at the feet instead.

### 2.2 NumberSequences that read as anime (copy these)
- **Pop-in, drift, snap-out (size):** `{0, 0}, {0.06, 1.0*S}, {0.4, 1.1*S}, {1, 1.15*S}`
- **Shockwave (size, ease-out):** `{0, 0.2*S}, {0.12, 0.65*S}, {0.4, 0.9*S}, {1, 1.0*S}`
- **Hold then cut (transparency):** `{0, 0}, {0.75, 0}, {1, 1}`. For a harder cel feel use `{0.85, 0.05}, {1, 1}`.
- **Fade in and out (looping aura bits):** `{0, 1}, {0.15, 0.2}, {0.7, 0.3}, {1, 1}`
- **Shrink-out sparks (size):** `{0, S}, {0.7, 0.6*S}, {1, 0}`
- **Colour ramp, white-hot to colour:** `{0, white}, {0.12, white}, {0.3, main}, {1, deep}`. Keep `Color` keypoints
  at 3-4, because particles interpolate between them.
- **Envelope:** use NumberSequenceKeypoint's third argument (envelope) at 10-20% on size so copies differ a little.
- Lifetimes are always ranges: `NumberRange.new(0.35, 0.5)`, never a single number.

### 2.3 Beams: arcs, crescents, swirls, pillars
- A Beam is a cubic Bezier from `Attachment0` to `Attachment1`. P1 sits `CurveSize0` studs along Attachment0's
  **+X**, and P2 sits `CurveSize1` studs along Attachment1's **-X** (*doc*). Rotate the attachments to bend it.
- `Segments` defaults to 10; you need at least (keypoints - 1) for colour and transparency curves (*doc*). Use 16-24 for arcs.
- `TextureMode`: Wrap/Static repeat every `TextureLength` studs; Stretch repeats `TextureLength` times along
  the whole beam (*doc*). `TextureSpeed` is cycles per second; negative reverses (*doc*).
- `Width0/Width1` taper it: a crescent slash = Width0 0.1, Width1 2.5, Transparency `{0,1},{0.2,0},{1,0}`.
- `FaceCamera = true` for pillars and lightning (readable from any angle); false for a flat slash or ring.
- `LightEmission` 0-1 and `Brightness` 0-10000 as for particles (*doc*); `ZOffset` avoids z-fighting between two
  stacked beams (*doc*).
- **Semicircle from one beam:** attachments at (-r,0,0) and (+r,0,0), both pointing their X axes so the curve
  bulges the same way, `CurveSize0 = CurveSize1 = 4/3 * r`. That gives an exact apex at height r (the sides are a
  few % off). Two of them make a ring. Check once in Studio which way the ribbon's flat side faces.
- **Crescent slash (what `AuraFX` already does):** two beams on the same attachments: a dark, wide edge beam
  (LightEmission 0, ZOffset -0.1) and a bright, narrower core beam (LightEmission 1). Sweep the attachments round
  a pivot in `RenderStepped` over 0.12-0.18 s and fade them out over 0.15 s.
- **Swirl:** a beam with a diagonal-stripe texture, `TextureSpeed` 1.5-3 and a strong `CurveSize` (2-4), between an
  attachment at the feet and one above the head with opposite X directions. Two or three such beams rotated 120
  degrees apart read as a vortex.
- **Pillar of light:** three FaceCamera beams from ground to +60 studs (core white Width 1.5, LightEmission 1;
  rim colour Width 4, LightEmission 0.6; vertical-streak texture with TextureSpeed -2 so streaks rise).

### 2.4 Trails
- Two attachments; the trail's width is their spacing times `WidthScale` (0-1) (*doc*). `Lifetime` 0.01-20 s
  (*doc*), `MinLength`, `MaxLength`, `FaceCamera`, `TextureMode`.
- Anime swoosh: Lifetime 0.18-0.3, WidthScale `{0,1},{1,0}`, Transparency `{0,0},{0.6,0.2},{1,1}`, Color
  `{0,white},{0.25,main},{1,deep}`, LightEmission 0.8.

### 2.5 Parts and post-processing (built-in, no meshes)
- **Built-in shapes only:** Ball, Block, Cylinder, Wedge, CornerWedge parts (a Cylinder's axis is its X; rotate
  90 degrees on Z to stand it up). Don't use SpecialMesh `FileMesh` with anyone else's ids.
- **Neon material** for solid glowing cores (an orb, a pillar core). It glows through the Lighting `BloomEffect`.
- **ForceField material** on a Ball part = an animated energy shell; tween Size up and Transparency to 1 for a
  dome shockwave. Test it in Studio, because its transparency doesn't behave like other materials.
- **SurfaceGui on a thin part** = a textured quad that you can tween: part `Size = (8, 0.05, 8)`, Transparency 1,
  CanCollide/CanQuery/CanTouch false, CastShadow false; `SurfaceGui.Face = Top`, `LightInfluence = 0`,
  `Brightness` 1-3 (range 0-1000, *doc*); a full-size ImageLabel. Tween the part's Size and the ImageTransparency.
  This is the safest way to keep a ground ring perfectly flat.
- **Highlight:** white silhouette = `FillColor` white, `FillTransparency` 0, `OutlineTransparency` 0, `DepthMode`
  AlwaysOnTop. Cel outline = `FillTransparency` 1, `OutlineColor` rarity colour. Studio shows at most 255 at once,
  and disabled ones still take a slot (*doc*), so use them only on the girls in focus.
- **Lighting effects:** one `ColorCorrectionEffect` (Brightness, Contrast, Saturation, TintColor), one `BloomEffect`
  (Intensity, Size, Threshold) and a `BlurEffect`, all made once and tweened, never re-created per hit.
- **PointLight** (Range 8-12, Brightness 1-2) under an aura: particles do not light the world (*doc*).
- **Optional upgrade:** a torus or crescent mesh generated by our own Python `.obj` script counts as *our* asset.
  The owner would import it once in Studio. Not needed for anything below.

---

## 3. Drawing our own anime textures (PIL)

General rules
- **Draw white or greyscale masks and tint them with `Color`.** One texture then serves every rarity. For a white
  core with a coloured rim, stack two emitters with the same texture or two textures (core white, ZOffset +0.2;
  rim tinted), because `Color` multiplies the whole texture. Bake colour into a texture only for one-off hero effects.
- **Hard edges:** draw at 4x size, then downsample with `Image.LANCZOS`. Edges come out crisp but not jagged.
  Use 2-3 flat value steps (255 / 200 / 140 alpha or grey), not smooth gradients. The single exception is a
  separate soft `glow` texture used at low opacity behind things.
- **Edge bleed:** fill the RGB of fully transparent pixels with the nearest opaque colour (or plain white for
  masks). Black RGB under alpha 0 causes dark fringes when the image is filtered.
- **Sizes:** square and power-of-two. 256 px for small sparks and stars, 512 px for single shapes, 1024 px for
  flipbook sheets (8x8 at 1024 = 128 px frames; 4x4 = 256 px frames) (*doc*). The flipbook texture size must be
  an exact multiple of the layout (*doc*). Leave a 6-12 px transparent gutter inside every frame, because mip
  filtering bleeds neighbours (*doc*).
- The owner's Mac is Retina; anything that fills a lot of the screen (shockwave, slash) should be 512 or more.
- Reuse textures: every unique flipbook costs memory, and low-memory phones switch flipbooks off (*doc*).

Shapes to draw (each one a function in `tools/fx/make_fx.py`)
| Texture | How to draw it |
|---|---|
| `crescent` | Big circle minus a same-size circle shifted 18-25% sideways; taper both tips; add 2 thin parallel sub-arcs inside at 60% and 40% alpha (speed lines). |
| `ring_hard` | Annulus, outer radius 0.95, thickness 0.10, hard edges; a thin second ring at radius 0.78, thickness 0.02. |
| `ring_soft` | Same, but with a 3-step falloff on the outside only (sharp inner edge, soft outer edge = wave front). |
| `burst_star` | 10-14 spikes with random tip radii 0.55-1.0 and random angular jitter of 5 degrees; inner disc of radius 0.25 at full alpha. Make 4 variants in a 2x2 sheet. |
| `twinkle` | 4-point star (two thin diamonds crossed) plus a tiny centre dot; 2x2 sheet of slightly different arm lengths for `FlipbookMode = Random`. |
| `spark` | A thin diamond needle (length 1.0, width 0.12). Use it with VelocityParallel and Squash. |
| `swirl` | 3 logarithmic-spiral strokes tapering toward the centre; also a tileable diagonal stripe strip (256x64) for beams. |
| `flame_sheet` | 4x4 OneShot flipbook of a cel flame tongue: teardrop with 2-3 wavy lobes, rising, splitting at frame 10, shrinking to a wisp by frame 16. A 2-tone mask (core 255, body 170). |
| `shock_sheet` | 4x4 OneShot flipbook: ring expanding from radius 0.2 to 0.95 while thinning from 0.18 to 0.02, breaking into 3 arcs in the last 4 frames. |
| `slash_sheet` | 4x4 OneShot flipbook: crescent sweeping 0 to 200 degrees, then thinning and breaking into speed lines. |
| `bolt` | Midpoint displacement from top to bottom (5-6 subdivisions, offset halves each step, 1-2 forks); 3 px white core + 9 px 50% alpha body. Make 4 variants in a 2x2 sheet with FlipbookStartRandom. |
| `streak` | Tapered horizontal line with two soft stripes, 256x64, for trails and speed lines. |
| `sigil` | Two concentric rings, 8 tick marks, a 6-point star polygon; a hard 2-tone mask. |
| `glow` | Radial gradient, alpha `(1-r)^2`. Used only as a background layer at Transparency 0.6-0.8. |

---

## 4. Cutscene craft

### 4.1 Camera
- `camera.CameraType = Enum.CameraType.Scriptable`; always restore `Custom` (and `CameraSubject`) in a cleanup
  that also runs if the cutscene errors (`task.spawn` plus `pcall`, or a `finally`-style cleanup function).
- Drive the camera from one `RenderStepped` timeline, not chained waits: `t = os.clock() - t0`, then look up
  the shot at time t. Each shot = a `from` CFrame, a `to` CFrame, an ease, and an FOV pair.
  `cf = from:Lerp(to, TweenService:GetValue(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))`.
  This avoids overlapping tweens fighting each other (a common DevForum bug).
- Aim with `CFrame.lookAt(camPos, target)`; orbit shots = `target * CFrame.Angles(0, angle, 0) * CFrame.new(0, h, d)`.
- **FOV punch** (*start*): build-up 70 -> 58 over 1.5 s (Sine In); at the impact 58 -> 82 in 0.06 s, then back to
  70 over 0.6 s (Quint Out). Reduced Motion: skip the punch and hold 70.
- **Shake:** Perlin-noise rotation, not random jumps, applied on top of the shot CFrame each frame (never
  accumulate). Values from Sleitnick's open-source RbxCameraShaker presets, as (magnitude, roughness,
  fadeIn, fadeOut): Bump (2.5, 4, 0.1, 0.75), PositionInfluence 0.15, RotationInfluence (1,1,1); Explosion (5, 10,
  0, 1.5), position 0.25, rotation (4,1,1); Earthquake (0.6, 3.5, 2, 10). For kids, use about half the Explosion
  magnitude. Reduced Motion: no shake.

### 4.2 Impact frames, done kid-safe
Pro Roblox anime games use black/white inverted frames: ColorCorrection pushed to extreme contrast with Saturation 0,
a Highlight on characters, and colours flipped after a short delay, often 2-4 times in a row. **We must not do the
rapid flipping:** WCAG 2.3.1 treats more than 3 flashes a second as a seizure risk, saturated red flashes count
extra, and our own rule is at most 1 per second. Safe alternatives that keep the punch:
1. **One silhouette beat:** white Highlight (FillTransparency 0, AlwaysOnTop) on the hero for 0.1 s, then tween
   FillTransparency to 1 over 0.35 s. At the same time, ColorCorrection Saturation -0.8 -> 0 over 0.4 s, so the
   world is grey for an instant and the white figure pops. That is one luminance change and no reversal burst.
2. **One bloom/brightness pulse:** ColorCorrection Brightness 0 -> +0.25 in 0.05 s, back to 0 over 0.4 s; Bloom
   Intensity 0.4 -> 1.2 -> 0.4. At most one per second, never red-dominant, never full black.
3. **Hit-stop instead of flicker** (section 4.4): a frozen 0.1 s reads as "impact frame" with no flash at all.
4. **Radial speed lines** (ScreenGui ImageLabel of a `burst_star`/lines texture, ImageTransparency 0.3 -> 1 over
   0.3 s, scale 1.0 -> 1.3): the manga "impact" look without changing screen brightness.

### 4.3 Grading and beats
- **Beats:** anticipation is about 55-65% of the time (slow, building, darker), impact under 0.2 s (biggest,
  brightest, fastest) and aftermath the rest (settling, slower, readable). Silence 0.1 s right before the impact
  makes the hit louder.
- **Grade:** during build-up, Brightness -0.1, Saturation -0.3, TintColor slightly toward the rarity colour (e.g.
  `Color3.fromRGB(235,225,255)`); after the impact, return to defaults over 0.8 s.
- **Blur:** BlurEffect Size 0 -> 10 -> 0 within 0.25 s on a whoosh cut only; skip it on phones.
- **Letterbox:** the owner rejected black bars. Frame with the camera and the one message line instead.
- **Sound sync:** preload with `ContentProvider:PreloadAsync`; start the riser 1.5-2 s before the impact; play the
  impact sound on the exact impact cue in the same timeline function; start whooshes about 0.05 s *before* the
  motion. Our own SFX come from `tools/sfx/make_sfx.py`.

### 4.4 Slow motion and hit-stop
- Set every effect emitter's `TimeScale` to 0.05-0.15 (*doc*), `AnimationTrack:AdjustSpeed(0.1)` on the hero's
  tracks, and slow the camera's shot alpha by the same factor; restore all three together.
- Hit-stop = 0.08-0.12 s at TimeScale 0.05 right *on* the impact, then snap back to 1. Slow motion = 0.3-0.5 for
  0.5-1 s right *after* it, easing back over 0.3 s.

---

## 5. Performance rules
- One emitter makes at most 400 particles per second, 100 on mobile (*doc*). Fill rate is the real cost: big
  overlapping transparent particles hurt more than many small ones (*doc*).
- Roblox scales `Rate`-based emission down with the graphics level, but `:Emit()` skips that scaling (DevForum
  performance guide). Scale our Emit counts ourselves, e.g. `n * (0.5 + 0.5 * qualityLevel / 10)`, and halve
  them on touch devices.
- Budgets (*start*): an idle aura has 40-70 live particles per girl; a burst peaks at 150 live particles; a cutscene
  peaks at 300. Only the 3 nearest or featured girls get the full aura; beyond 60 studs show only the glow and
  PointLight; beyond 120 studs, nothing.
- Build every effect on the client (the server sends one remote saying what happened); pool parts and emitters;
  `Debris:AddItem` or `task.delay` + `Destroy()` after the longest Lifetime.
- Flipbooks cost memory and are switched off on low-memory phones (*doc*), so every flipbook needs a texture that
  still reads as frame 1 alone. Share a few sheets across all effects.
- Highlights: few, and only on the girls in focus (cap 255, *doc*). Beams: 16-24 segments, not 100.
- Test at Studio's lowest and highest Editor Quality Level and on the phone emulator before showing the owner.

---

## 6. Recipes

Palettes: every effect uses three tones (white / main / deep). `AuraLook` already gives each girl her element
colour, so take main and deep from there. The rarity changes the *layers*, not the hue. Avoid gold: the owner
rejected gold tones ("looks so AI"). Example sets: Mythic white, `(215,110,255)`, `(110,40,200)`. Secret white,
`(110,235,255)` + `(255,120,210)` two-tone, with a slow hue drift on the main colour (set a new `Color` every 0.15 s;
only new particles change, so it flows).

### 6.1 Rarity aura (Legendary / Mythic / Secret)
Mount it on an invisible welded box around the girl (`Size (3,5,3)`, Transparency 1, Massless, CanCollide/CanQuery
false), because shaped emission needs a BasePart (*doc*), plus attachments at the feet and chest.
| Layer | Setup (*start*) | L / M / S |
|---|---|---|
| 1. Ground sigil | Flat particle (2.1 trick) at the feet, `sigil`, Size 6, RotSpeed 25, Lifetime 1.6, Rate 1.25 (two overlap and crossfade), Transparency `{0,1},{0.2,0.35},{0.8,0.35},{1,1}`, LightEmission 1, colour = main | yes / yes / yes |
| 2. Flame tongues, colour | Box surface emission, `flame_sheet` OneShot, Lifetime (0.6,0.9), Speed (1.5,3) up, Acceleration (0,4,0), Size `{0,0},{0.15,1.6},{1,0.5}`, Transparency `{0,0.15},{0.7,0.3},{1,1}`, VelocityInheritance 0.4, LightEmission 0.5, colour main -> deep | Rate 10 / 14 / 18 |
| 3. Flame tongues, core | Same emitter cloned: Size x0.55, colour white, LightEmission 1, ZOffset +0.3 | Rate 6 / 8 / 10 |
| 4. Orbit orbs | Attachments moved in `step(dt)`: radius 2.2, 2.5 rad/s, bob +-0.4 at 1.3 Hz; each has a Trail (Lifetime 0.35, attachments 0.35 apart, WidthScale `{0,1},{1,0}`, LightEmission 1, FaceCamera) and a 0.6-stud `glow` particle | 2 / 3 / 4 orbs |
| 5. Twinkles | `twinkle` 2x2 Random, Lifetime (1,1.6), Rate 5, Size `{0,0},{0.3,0.4},{1,0}`, Speed (0.3,1), SpreadAngle (180,180) | yes / yes / yes |
| 6. Pulse ring | Flat `ring_soft`, Emit(1) every 2.5 s, Lifetime 0.9, Size 3 -> 8 (shockwave curve), Transparency `{0,0.2},{1,1}` | - / yes / yes |
| 7. Crackle | 2-3 times a second, a 3-segment jagged FaceCamera beam (Width 0.15, white core + colour twin) between two random points on the box, alive for 0.1 s. It changes shape and doesn't blink the whole screen. | - / - / yes |
| 8. Outline + light | Highlight: FillTransparency 1, OutlineColor main, OutlineTransparency 0.25 (focused girl only); PointLight Range 10, Brightness 1.5, colour main | yes / yes / yes |
"Premium" checklist: three tones only, everything moves up or around (never random), every curve fades in and
out, ranges on every Lifetime/Size/Rotation, no default Roblox sparkle texture, the rarer tier adds a *new* layer
(not just a higher Rate), and the aura still reads as a silhouette shape from 40 studs.

### 6.2 Companion / pet trail
- Two attachments on the pet's root, 0.5 studs apart vertically. Trail: `streak` texture, TextureMode Stretch,
  Lifetime 0.4, MinLength 0.1, WidthScale `{0,1},{1,0}`, Transparency `{0,0.15},{1,1}`, Color `{0,white},{0.3,main},{1,deep}`,
  LightEmission 0.7, FaceCamera true.
- Sparkle crumbs: `twinkle` emitter with Rate 0; in `Heartbeat`, `:Emit(1)` every 0.6 studs travelled (the docs'
  "emit particles over distance" sample). Lifetime (0.5,0.8), Size `{0,0.35},{1,0}`, Acceleration (0,-2,0).
- Idle: `Trail.Enabled = false` under 1 stud/s, and a slow 1-orb orbit (6.1 layer 4 with 1 orb, radius 1).
- Hop landings: 6 dust puffs from a Disc emitter (Surface, ShapePartial 1, Outward), Speed 3, Lifetime 0.3.
- Reduced Motion: keep the trail, drop the orbit and the crumbs.

### 6.3 "Secret character chosen" cutscene (7.5 s)
All cues live in one timeline table `{t, fn}` driven by `RenderStepped`. Reduced Motion: same shots, no shake,
no FOV punch, and Highlight + saturation instead of the brightness pulse.
| t (s) | Beat | What happens (*start*) |
|---|---|---|
| 0.0-0.4 | Set-up | Cut to a wide shot of the drop point (FOV 70). Grade: Brightness -0.12, Saturation -0.35, Tint toward cyan. Message line: "Something rare is coming..." Riser sound starts. |
| 0.4-2.6 | Build-up | Orb at drop point +8 studs: Neon Ball 0.5 -> 3.5 studs (Sine In) inside a ForceField shell 1.2x larger. Inward Sphere emitter on it (ShapeInOut Inward, `spark` VelocityParallel, Rate 40 -> 90, Lifetime 0.4). 2 -> 4 orbit trails speeding up from 2 to 9 rad/s. Pillar beams fade in from Width 0 (TextureSpeed -2). Earthquake-style shake (0.6, 3.5). Camera pushes in, FOV 70 -> 58. |
| 2.6-2.72 | Hold | Hit-stop: emitter TimeScale 0.05, orb stops growing, sound dips to silence. |
| 2.72 | **Impact** | Orb hidden. Emit: 1 `burst_star` (Size 0 -> 14 in 0.08 s, Lifetime 0.35, hold-then-cut), 24 `spark` (VelocityParallel, Speed (25,45), Squash 0 -> 2, Drag 6), 1 vertical camera-facing `shock_sheet` (Size 18, Lifetime 0.4), 1 flat ground `ring_hard` (Size 2 -> 26, Lifetime 0.5). The girl appears with a white Highlight (4.2 #1). One Bloom pulse. FOV 58 -> 82 -> 70. Explosion shake at half magnitude. Impact sound. |
| 2.72-3.1 | Drop | Girl falls 8 studs to the ground (Quad In 0.35 s); a short Trail on her root (Lifetime 0.2) gives a speed streak. |
| 3.1 | Landing | Ground `ring_soft` flat (Size 3 -> 18, 0.5 s) + a ForceField dome (Size 2 -> 14, Transparency 0.2 -> 1, 0.45 s), 12 dust puffs from a Disc rim, Bump shake. Camera cuts to a low hero angle. |
| 3.1-5.0 | Aftermath | Slow orbit 25 degrees around her (Sine InOut). Grade returns to default over 0.8 s. Her Secret aura (6.1) fades in. Message line: "SECRET: <Name>!" Pillar thins out. |
| 5.0-7.0 | Float up | She rises to her showcase height above the map (Sine InOut 2 s) while scaling to showcase size (`Model:ScaleTo`); 1 pulse ring when she starts; the camera tilts up and pulls back to keep her framed. |
| 7.0-7.5 | Return | Camera tweens back to the player's view (0.5 s, Sine Out); restore `Custom`. No hard cut, because the owner asked that cutscenes not cut out. |
Flash count: exactly one brightness pulse (2.72 s); the landing uses shake and rings, not light, so the
1-per-second rule holds.

---

## 7. How to judge it (repo rules)
- Render one side-by-side against the reference frame, and a 30 fps video for motion (`tools/preview`).
- Be honest about what the offline renderer cannot show: additive blending, Bloom, ForceField and Highlight look
  are Studio-only. Say so when reporting.
- Every new texture: name it `Fx/<name>`, add a 0/empty id with a note on the owner's upload checklist, and fall back
  to `AuraLook.TEXTURES` until the id arrives (as `AuraFX.texture()` does).

---

## Sources
- ParticleEmitter API (Flipbook*, LightEmission, LightInfluence, Orientation, Shape*, Squash, TimeScale, ZOffset, Emit): https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter (raw: https://github.com/Roblox/creator-docs/blob/main/content/en-us/reference/engine/classes/ParticleEmitter.yaml)
- Particle emitters guide (400/s, 100/s on mobile, fill rate, flipbook spacing and memory, Sphere/Cylinder only on parts): https://create.roblox.com/docs/effects/particle-emitters
- Beam API and guide (Bezier CurveSize, Segments, TextureMode/Length/Speed, FaceCamera, ZOffset): https://create.roblox.com/docs/reference/engine/classes/Beam , https://create.roblox.com/docs/effects/beams
- Trail API and guide (Lifetime 0.01-20, WidthScale, MinLength/MaxLength): https://create.roblox.com/docs/reference/engine/classes/Trail , https://create.roblox.com/docs/effects/trails
- Highlight (255 limit): https://create.roblox.com/docs/reference/engine/classes/Highlight
- SurfaceGui (Brightness 0-1000, LightInfluence, AlwaysOnTop): https://create.roblox.com/docs/reference/engine/classes/SurfaceGui
- Post-processing (Bloom, ColorCorrection, Blur): https://create.roblox.com/docs/environment/post-processing-effects
- Texture specifications (resolution guidance): https://create.roblox.com/docs/art/modeling/texture-specifications
- Roblox VFX curriculum (beginner explosions, laser): https://create.roblox.com/docs/tutorials/curriculums/artist
- Flipbook enum naming pitfall (Enum.ParticleFlipbookLayout): https://devforum.roblox.com/t/having-some-problems-creating-particles-and-using-flipbook-stuff/2979491
- VelocityPerpendicular needs Speed > 0 (0.01 trick): https://devforum.roblox.com/t/velocityperpendicular-particle-orientation-doesnt-work-with-0-speed/2575975 ; jitter when locked in a character: https://devforum.roblox.com/t/particle-rotation-glitches-with-velocityperpendicular-and-lockedtopart-inside-the-character/1994232 ; flat shockwave with particles: https://devforum.roblox.com/t/how-can-i-create-a-shockwave-effect-with-particleemitters/2789227
- Emit() skips the graphics-level auto-scaling: https://devforum.roblox.com/t/performance-considerations-improvements-and-optimizations-when-making-a-game/817499
- ZOffset layering and particle basics: https://devforum.roblox.com/t/introduction-to-vfx-particles/2068650
- Anime/fighting VFX scripting structure (client-side spawning): https://devforum.roblox.com/t/full-beginners-guide-on-scripting-animefighting-vfxvisual-effects-part-1/1610853
- Making effects look better (variety, beams + trails for shapes particles can't make): https://devforum.roblox.com/t/how-can-i-make-my-visual-effects-look-better/2963977 , https://devforum.roblox.com/t/how-to-make-emitter-effects-look-good/4138403
- Crescent slash discussion (beams vs spritesheets): https://devforum.roblox.com/t/crecent-sword-slash-effect/1113871
- Punch VFX feedback (scale from 0, random ring rotation): https://devforum.roblox.com/t/help-with-punch-vfx/3598230 ; ring from beams: https://devforum.roblox.com/t/how-can-i-make-a-ring-that-can-be-rendered-real-time/2021996
- Impact frames in Roblox (ColorCorrection + Highlight flips; ViewportFrame method): https://devforum.roblox.com/t/advanced-impact-frames/2468478 , https://devforum.roblox.com/t/a-simple-impact-frame-showcase/4355157 , https://devforum.roblox.com/t/creating-a-white-silhouette-for-the-players-character/3914089
- Camera: FOV tweens and shake threads: https://devforum.roblox.com/t/how-to-make-smooth-fov-tween-script/1785607 , https://devforum.roblox.com/t/how-do-i-make-the-camera-shake-like-this/2271362
- CameraShaker presets (open source, Sleitnick): https://github.com/Sleitnick/RbxCameraShaker/blob/master/src/CameraShaker/CameraShakePresets.lua
- Stylised VFX principles (hard-edged shapes, impact stars, timing/contrast/restraint): https://www.vfxapprentice.com/blog/genshin-impact-stylized-vfx-breakdown
- Smear frames and fast-motion readability: https://blog.cg-wire.com/smear-frames/
- Flash safety (WCAG 2.3.1, three flashes, red flash): https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html
