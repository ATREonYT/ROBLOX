---
tags: [build-playbooks, recipes, vfx, animation, game-feel, anime, combat, camera, sound, kid-safe]
updated: 2026-10-31
---

# 19 Animation and VFX Recipe Book

Back to [[00 Build Router]] · Why and what to copy: [[17 Do It Like the Hits - Animation, VFX and Feel]] · Looks cheap: [[16 Pro Animation and VFX Playbook]] · Anime style: [[15 Anime VFX and Animation Playbook]] · Studio practice: [[18 Studio-Level Development Playbook]]

**How to use this book.** Each recipe has the same parts: what it is for, what you need, numbered steps with exact values, how to check it worked, and kid-safe notes. To build a moment:
1. Find the recipe.
2. Follow the steps.
3. Use the kit modules where a recipe names them (`AnimeFX`, `LaunchFX`, `RareReveal`, `Spring`, `Emit`, `Flags`).
4. Check the result on a 30 fps capture next to the reference.

**Recipes the kit already does** (call the function instead of rebuilding it). The numbers are locked by `tests/VaultNumbers.spec.luau`, so the code and this book can't drift apart without a red check:

| Recipe | Kit call | Test |
|---|---|---|
| R1 catch-up hit-stop | `AnimeFX.StopFor(strength)`, `AnimeFX.HitStop(track, d)` | VaultNumbers |
| R3 trauma shake | `LaunchFX.Trauma.new(decay, maxDeg)`, `AnimeFX.Shake` | LaunchFX |
| R4–R5 charge and cannon shot | `LaunchFX.Charge(model)` → `:Fire({ tier, color, direction })`, `LaunchFX.Flight(ball)` | LaunchFX, VaultNumbers |
| R6 landing with rings | `LaunchFX.Land(pos, color, tier)` | LaunchFX |
| R7 shockwave and crater | `AnimeFX.Shockwave`, `AnimeFX.Crater` | not yet (needs Studio) |
| R9–R10 aura and power-up | `AnimeFX.Aura(character, { color, tier })` | not yet (needs Studio) |
| R13, R19 rare reveal and its time budget | `RareReveal.Play(tier, opts, onDone)` | RareReveal, VaultNumbers |
| R23 UI pop | `Spring.Run(Spring.fromPreset(0, "Pop"), apply)` | Spring, VaultNumbers |
| R25 juice governor | `Emit.Scale`, `Emit.InRange`, `Emit.TryFlash`, `Emit.MotionScale` | Emit |

Every other recipe is built by hand from its steps. When one is built twice, move it into the kit with a test.

**How sure we are:**
- `[source]` / `[cited]` numbers come from LihFolk notes, the tutorial videos or the web. Most LihFolk combat numbers were measured in one live action game, not a kids' game.
- `[suggested]` / `[estimated]` numbers are ours.
- Nothing here has run in Studio yet.

**Where it comes from:**
- `research_notes/Roblox studio craft and recipes/vault_gap_recipes.md`: the full gap list, mined from LihFolk's 1,400 notes, the 38 video notes and our research.
- `research_notes/Roblox studio craft and recipes/anime_games_part3.md`.

**Golden rules:**
- A normal action stays quiet (note 17 §1). Loud layers belong to rare or big moments.
- At most one flash per second.
- Keep stuns at about 2 s or less for kids.
- No gore.
- Never copy a game's names, moves or assets.

## Part 1. Animation, VFX and feel recipes (R1–R25)

Format: **Name · When to use · Ingredients · Steps · Check · Kid-safe.** The house rules in the repo `CLAUDE.md` apply to all of them:
- at most 1 flash a second;
- shake and flashes honour `Setting_ScreenShake` / `Setting_Flashes` through `Emit.MotionScale()` and `Emit.TryFlash()`;
- no invented asset IDs;
- built-in textures or the owner's uploads only.

---

### R1. Hit-stop that never drifts (catch-up stop)
- **When to use:** any attack, cannon landing or punch whose effects are scheduled by markers or the clock; any multi-hit combo.
- **Ingredients:** the attacker's AnimationTrack (Action4 or Action), a strength value per hit (0.3–1.3), a small `HitFeel` budget table, `RunService.Heartbeat`.
- **Steps:**
  1. Give every hit one **strength**: Light 0.30, Medium 0.45, Heavy 0.80, Finisher 1.0, Ultimate 1.3. [source: `V47/Hit-Stop…`]
  2. If strength < 0.45, **no stop** (play a glint and a sound only). [source]
  3. Stop length `d = 0.03 + 0.045 × strength`, giving 50, 66, 75 and 89 ms. [source]
  4. Budget:
     - keep a rolling 0.6 s window; skip stops once 140 ms is spent;
     - finishers are `reserve = true` and keep 60 ms free;
     - one stop per swing id, the first target only. [source]
  5. `track:AdjustSpeed(0.12)` for `d`, then `AdjustSpeed(1.88)` for `d`, then restore the original speed. Slow only the ability or attack track, never locomotion. [source: `V08/05/Hit Reactions…`]
  6. Play the impact sound **at the start** of the stop; never pause it. [source: `LF-sfx`]
  7. Cap any single stop at 0.12 s. [suggested; LF module caps at 0.2 s]
- **Check:**
  - On a 30 fps capture, Heavy shows **2 frames** of near-still pose, then the swing visibly "catches up".
  - After a 4-hit flurry, the slash VFX still sits on the blade (no sparks before the sword).
  - Light jabs show no pause.
- **Kid-safe:** no screen effect involved. Skip the stop entirely when reduced motion is on, if a player finds it "sticky". [suggested]

---

### R2. The impact stack (order of hit-stop, flash, kick and shake)
- **When to use:** heavy hits, finishers, record-breaking cannon landings, an ultimate's climax.
- **Ingredients:** R1, `AnimeFX.ImpactFrame` (changed to count frames), a camera FX module bound at `RenderPriority.Camera + 1`, `Emit.TryFlash()`, a BlurEffect and a ColorCorrectionEffect under `workspace.CurrentCamera`.
- **Steps (t = 0 is the contact marker):**
  1. **t = 0:** the hit-stop starts (R1), plus a **directional kick**:
     - set the camera rotation in 1 frame, away from the hit (or along your own attack);
     - size by tier from 0.25% to 1.2% of screen height, converted with `deg = atan(frac × 2 × tan(FOV/2))`;
     - return over 0.10–0.18 s with ease-out. [source: `V47` §6]
  2. **Contact + 1 frame:** the local flash at the hit point, about 0.6× the body size, living 1–2 frames. [source: `LF-vfx`]
  3. **Inside the stop:** the impact frame (Finisher and Ultimate only, and only if `Emit.TryFlash()` passes):
     - ColorCorrection Saturation −1, Contrast +2.5, Brightness −0.05 (note 15's grey beat);
     - show it for exactly **1 rendered frame** (count `PreRender` callbacks, remove on the 2nd), at most 2. [source: frame counting `V47` §1; values: note 15]
  4. **t = d/2:** FOV kick of +2 to +4° that springs back over 0.5 s with a small overshoot (kit `Spring` Pop 0.45, 7). [source: order `V08/05/Camera Shake…`; size suggested]
  5. **t = d (the freeze ends):** add trauma (0.25 Heavy, 0.35 Finisher, 0.6 Ultimate). The shake starts now, never during the freeze. [source]
  6. Blur pulse Size 4 → 0 with a 0.09 s e-folding time; colour punch (Saturation +0.2, tint toward the accent) decaying over 0.35 s. [source: timings; sizes suggested]
- **Check:**
  - Frame-step a 30 fps capture: contact frame (clean) → flash frame → still frames (one grey) → shake begins on the first moving frame.
  - FOV is exactly back on base afterwards (print it).
- **Kid-safe:** impact frame on finishers only, grey not negative, at most 1/s, skipped with Flashes off. Shake through `MotionScale()`; the kick at 0.25× is the reduced-motion fallback. [source: `V47` §6]

---

### R3. Trauma shake done right
- **When to use:** every screen shake (cannon record, landing, ultimate). Replaces ad-hoc `math.random` shakes.
- **Ingredients:** a client module with `addTrauma(x, sourcePos?)`, a per-frame noise sampler, a render step bound at `Camera + 1` with an undo at `Camera − 1`.
- **Steps:**
  1. Trauma 0–1, clamped. Visible shake = trauma². [source: `V08/05/Camera Shake…`]
  2. Decay linearly, 1.0–1.5 per second (1.45 measured for ultimates). [source/suggested]
  3. Rotation amplitude = 2.6° × trauma² × tier factor (1.0–1.6). Rotation only; translation only for "the ground moved" (a landing right under the player). [source]
  4. Noise frequency 16 Hz, capped at `0.4 × smoothedFps` (12 Hz at 30 fps), using the fps averaged over 0.5 s. [source: `V47` §4]
  5. Multiply by `tan(FOV/2) / tan(35°)` so zoomed views don't shake harder. [source]
  6. Others' events: × 0.3 with smoothstep falloff `1 − u²(3 − 2u)`, full at 30 studs and zero at 150. [source]
  7. Many targets at once: `trauma × (1 + 0.35·log2(count))`; one source adds at most 0.6 a second. [source]
  8. Undo last frame's offset at `Camera − 1` and apply at `Camera + 1`; roll and pitch only, no yaw. [source: `V08/05/Cameras…`]
- **Check:**
  - Log FOV and look direction before and after 50 shakes: identical.
  - On a 30 fps phone capture the shake judders smoothly rather than jumping.
  - Visible shake (trauma² > 0.05) is under 10% of play seconds.
- **Kid-safe:** `MotionScale()` multiplies everything (0 means off); never shake on Common or Rare cannon shots (note 17); shake is never the only cue.

---

### R4. Charge-up with a readable "full" cue (cannon or anime)
- **When to use:** cannon charge (0.25–0.3 s normal), hold-to-charge moves, anime power-ups.
- **Ingredients:**
  - a charge clip with `Charge` and `Full` markers;
  - `LaunchFX.Charge` or `aura:Charge()`;
  - an implosion ParticleEmitter on an invisible Ball part;
  - a PointLight;
  - a riser sound with a "ready" ping.
- **Steps:**
  1. Charge time 0.15–0.7 s for held moves; the cannon's normal shot stays at 0.25–0.3 s. [source: `V08/05/Stance and Charge Moves.md`; cannon: note 17]
  2. If the clip is longer than the gameplay charge, play it faster so `Full` lands on time: `speed = clipLength / chargeTime` (1.2/0.7 = 1.71). Never play a release clip below 0.6×. [source]
  3. Implosion emitter (rare tiers and anime only) [source: `HB` §6.7]:
     - an invisible Ball 10 studs across;
     - `Shape = Sphere`, `ShapeStyle = Surface`, `ShapeInOut = Inward`, Speed 25, Lifetime 0.35;
     - Rate 60 for the charge;
     - colour white → accent, LightEmission 1, LightInfluence 0.
  4. Stepped glow, not a smooth ramp: PointLight Brightness 0 → 1.5 at `Charge`, then 3 at `Full`, Range 12, Shadows off. [suggested from the source's "stepped" rule]
  5. At `Full`: one glint (`Emit(1)` star, Size 0→1.5→0 over 0.15 s) plus the "ready" ping (fixed pitch, never randomised). Players release on this cue. [source: Stance note; sound rule `LF-sfx`]
  6. Hold pose: still. If held past full, loop a short hold clip or auto-release. Don't rely on the clip's end hold, which fades out in 0.3 s. [source]
  7. The server measures charge from its own press and release receipt times, clamped to the legal range. [source]
- **Check:**
  - 30 fps capture: motes converge, the light steps up twice, one glint on the `Full` frame.
  - Holding past full doesn't pop the pose.
  - The first use in a live server isn't late (preload the clip on equip).
- **Kid-safe:** the glint is local (not full-screen); touch: if the thumb slides off the button, **release** rather than cancel. [source]

---

### R5. Cannon shot, muzzle → flight (quiet normal, loud rare)
- **When to use:** every cannon or throw shot. Pairs with `LaunchFX` and note 17's measured timings.
- **Ingredients:** `LaunchFX.Fire`/`Flight`, a "Muzzle" Attachment 1–2 studs ahead of the barrel, a Neon core ball, a Trail, two wake emitters, one PointLight.
- **Steps:**
  1. **Muzzle**, placed 1–2 studs ahead of the barrel tip [source: `V07/Projectile VFX…`]:
     - flash sprite life 0.05–0.07 s, growing to 1.25× its start, about 0.6× the size of the landing flash;
     - 6–10 spark streaks in a 20–25° cone, Speed 18–34, Drag 6, life 0.16–0.3 s, VelocityParallel.
  2. Smoke puff only on Epic and up (a cannon may keep one small puff, but the reference's normal throw is clean). [suggested, note 17]
  3. **Core:**
     - body Neon Ball 0.9 studs in the accent colour, with a hot-centre Ball 0.5 studs near-white;
     - for a dark accent, a ForceField ball 1.15 gives the rim. [source]
  4. **Trail:**
     - pick Lifetime so speed × lifetime = 12–30 studs (at 100 studs/s, Lifetime 0.2);
     - WidthScale 1→0; colour hot → body → deep; transparency 0.05→0.45→1; FaceCamera on. [source]
  5. **Wake:** Rate 36, life 0.22–0.36, Drag 5, Size 0.55→0. Dark wake Rate 12, LightEmission 0, dropped on low quality. [source]
  6. **Light:** PointLight Brightness 1.4, Range 9, Shadows off, travelling with the ball. [source]
  7. Stretch the look mesh by speed (note 16) and spin it 1–3 turns a second.
- **Check:**
  - On a 30 fps capture the ball reads as a streak (not a dot, not a laser) at the chase-camera distance.
  - The muzzle flash is visibly smaller than the landing flash.
  - A Common shot has no smoke, shake or zoom.
- **Kid-safe:** no screen flash; one light per shot; about 50 particles per shot.

---

### R6. Landing impact with two rings (cannonball, slam, projectile)
- **When to use:** the ball lands, a ground slam, a projectile hits a wall.
- **Ingredients:** a raycast for position and normal, a pooled impact Attachment with flash, spark, chip and ring emitters (or 2 CylinderHandleAdornment rings), the travelling PointLight.
- **Steps:**
  1. On contact, keep the ball visible on the contact frame. Everything below starts **1 frame later**. [source: Ice Ball recipe]
  2. Flash about 2.6 studs, life 0.05 s, LightEmission 1. [source: `V07/Projectile VFX…`]
  3. Sparks: 12–18 in a 60–70° cone around the **surface normal**, Speed 22–40, Drag 6, VelocityParallel. [source]
  4. Chips: 6–8 dark flecks, Acceleration (0, −40, 0), life 0.35–0.55 s. [source]
  5. **Two rings in the surface plane** [source]:
     - bright ring 0.4 → 3.6 studs in 0.3 s;
     - dark ring 0.6 → 4.4 studs in 0.42 s, starting 0.03 s later;
     - both fade while they grow.
  6. Light pulse: move the travelling light to the hit; Brightness 3 → 0 over 0.2 s. [source]
  7. Set the wake emitters' Rate to 0 (don't destroy them); destroy after the longest lifetime. Whole impact under 1 s. [source]
  8. Scale by tier: Rare +1 ring in the accent colour; Legendary adds R7 (crater) and R2. [suggested]
  9. Water skips: keep note 17's measured splash crown and ripple instead of rings.
- **Check:** 30 fps: frame 0 shows the ball touching, frame 1 the flash, frames 2–10 the rings at different speeds (two distinct rings, not a stamp). Gone by frame 27.
- **Kid-safe:** local flash only; ≤ 25 particles at the impact.

---

### R7. Shockwave and crater (anime ground reaction)
- **When to use:** finisher, ultimate climax, Legendary cannon landing, aura burst.
- **Ingredients:** `AnimeFX.Crater`, `AnimeFX.Shockwave`, a pooled rock-part set, a smoke emitter, a crack decal (optional, uploaded).
- **Steps:**
  1. Rocks: 6–14 plain parts in a ring, coloured from the raycast floor material, tilted outward. They pop up in 0.12 s with Back Out, hold, and sink after 2.5 s. **Pool them.** [note 15 + source: pooled rocks `V08/05/Cinematic Ultimates.md`, note 17]
  2. Shockwave ring: flat (VelocityPerpendicular, Speed 0.01), 2× the radius over 0.5 s, **expanding while fading**. Never a static stamp, and no extra concentric copies. [source: `V07/Escalation…`, `V07/Slash VFX…`]
  3. Dust blast: 8–12 low puffs rolling outward, each with a different size and drift, fading in 0.5–0.8 s. Identical puffs that linger about 1 s read as flat discs. [source]
  4. One travelling shock crescent forward out of the move, for directional moves. [source: `V07/Escalation…`]
  5. At most **one** growing environmental element per move (cracks *or* a vortex *or* a sigil). [source]
  6. 2–3 embers drifting up for the tail, life under 1 s. [source]
- **Check:**
  - The character's silhouette is still clear at game distance at the busiest frame.
  - The peak particle count is at the finisher frame, and earlier beats sit well under it.
  - The rocks are gone by 3.6 s.
- **Kid-safe:** no gore, no blood-red as the default hit colour [source: `V07/Gore Policy…`]; at most 14 rocks on phones.

---

### R8. Slash crescent (frontal sword or energy cut)
- **When to use:** M1 swings, anime cuts, a "slice" cannon skin's motif.
- **Ingredients:** a crescent mesh (OBJ from our Python tool, uploaded) or a flat flipbook card, an edge Beam on two attachments, spark and glint emitters, the Hit marker.
- **Steps:**
  1. Fire on the `Hit` marker; its value picks the direction preset (forehand, backhand, overhead tilt about 70°). [source: `V07/Slash VFX…`]
  2. Arc only within ±100° of the LookVector, 120–200° long; outer radius 6.5–8 studs at character scale 1. [source]
  3. Timing at 30 fps after the marker [source]:
     - flash f0–2 (star, size 0 → 6–7 → 40%);
     - sweep-in f3–4 (ease-out with exponent 2.2);
     - hold f1–2 while still drifting (30° for a crescent);
     - erode over 10–12 f, fading in the last 60%;
     - debris to f33–39.
  4. Hot edge: Beam with FaceCamera, 24 segments, LightEmission 1, `CurveSize = 4/3·tan(band/4)·r`, width 1.1–2 → 0 over 0.34–0.45 s, riding the arc's head. [source]
  5. Dark smear: an ink copy about 10% of the element's value, transparency 0.12, lagging 18–20° behind. [source]
  6. Sparks: 16 along the swing tangent + 35–55% outward, Speed 34–58, Drag 6, life 0.2–0.38 s. [source]
  7. No weapon Trail on arcs over 120°. For smaller arcs: `Trail:Clear()`, on at hit − 0.12 s, off 0.24 s later, Lifetime 0.15–0.3. [source]
- **Check:**
  - 30 fps capture: the arc never appears behind the body.
  - Every frame has white, colour and dark.
  - The shape keeps moving during the hold (never a frozen plate).
- **Kid-safe:** sparks, not blood; a non-red default colour.

---

### R9. Persistent aura that stays cheap (worn, or other players)
- **When to use:** rebirth auras, a pass aura, Legendary "glow" that lasts minutes, any aura on other players.
- **Ingredients:**
  - Attachments at the feet (`−(root.Size.Y/2 + HipHeight)` on R15, −3 on R6);
  - 2 emitters (motes, dark specks);
  - 2 CylinderHandleAdornment rings;
  - 2 Trails between orbiting attachment pairs;
  - one Highlight.
- **Steps:**
  1. Rim: Highlight `FillTransparency 1`, `OutlineTransparency 0.3`, `DepthMode Occluded`, in the glow colour. **No fill.** [source: `V07/Auras, Shields…`]
  2. Motes: Rate 7, life 1.1–1.6 s, Speed 1.2–2.6 up in a 70° spread, Acceleration (0, 2.5, 0), Size 0 → 0.22 → 0. [source]
  3. Dark specks: Rate 3, life 0.9–1.3 s, LightEmission 0 (decoration, dropped on low quality). [source]
  4. Foot ring 2.55–2.8 studs, breathing at 2.4 rad/s, over a darker, wider ring. [source]
  5. Orbit wisps: 2 Trails (Lifetime 0.35) on attachment pairs orbiting at radius 2.1, in opposite directions, at 2.4–3.2 rad/s. [source]
  6. Light **off** (optional: 0.6 brightness, Range 8, 3.5 studs up and 1.5 behind). [source]
  7. One `intensity` 0–1 drives the motes' Rate, the rim's OutlineTransparency (1 → 0.3) and the ring. Map tiers to 0.4 / 0.75 / 1. [source]
  8. Sleep beyond 160 studs, wake inside 136; replicate "aura on" as a character attribute. [source]
  9. Our own player's short charge burst may switch to note 15's full aura for its seconds-long moment. [suggested, §2 C6]
  10. Add a "Hide others' auras" setting (Sol's RNG). [source: `V59/Teardown - Sol's RNG.md`]
- **Check:**
  - About 15 particles alive per aura (count in the MicroProfiler or by script).
  - The body's colour is unchanged (rim only).
  - With 12 auras on screen, a phone stays at its frame rate.
- **Kid-safe:** calm loops pulse slower than once a second (2.4 rad/s is about 0.38 Hz ✓); no flashing.

---

### R10. Anime power-up and transformation burst
- **When to use:** rebirth on an anime game, "Awakening", a Mythic shot's aura start.
- **Ingredients:** `AnimeFX.Aura` (`:Charge()`), R4's implosion, R7 shockwave, `AnimeFX.SpeedLines`, Neon colour-stage copies (optional), sound riser + sting.
- **Steps:**
  1. 0–0.3 s anticipation: crouch pose; flames pulled in (Rate × 0.5); implosion motes (R4). [note 15 + source `HB`]
  2. Colour stages: toggle prepared Neon copies of a hair or accessory part at markers (stage 1 colour at `Charge`, stage 2 at `Pulse`), on the client only. [source: `VN/VFX/Claude MCP + Codex…Cutscene…`]
  3. 0.3 s burst: two ground rings 0.12 s apart (Size 2 → 18, life 0.45 s), dust `Emit(24)`, streaks `Emit(20)`. [note 15]
  4. Grandeur rule: this burst is the peak. Each later pulse must be **bigger, brighter and shorter** (+15–30% radius). Add one new layer per pulse and remove or shrink one. [source: `V07/Escalation…`]
  5. Impact stack (R2) only for the full transformation, once.
  6. Settle into R9 at intensity 1 for the lasting state.
- **Check:** 30 fps: one clear peak frame; the silhouette never fully covered (≤ 35% of the screen covered); each repeat looks different.
- **Kid-safe:** the impact frame at most once; our own colours, never a show's exact sequence.

---

### R11. Dash with afterimages and a camera pulse
- **When to use:** dash moves, a "boost" pad, a fast character entering a zone.
- **Ingredients:** a ghost pool (Neon copies of the character's visible parts), `AnimeFX.SpeedLines`, the camera FX envelope module, a BlurEffect under the camera.
- **Steps:**
  1. Ghosts only while the body moves faster than 26 studs/s (a run is about 22). [source: `V08/05/VFX Timing…`]
  2. One ghost every 0.05 s, at most 10 per move; each fades from about 0.5 to 1 transparency over 0.2–0.25 s. [source; fade suggested]
  3. Camera pulse [source: `V08/05/Camera Shake…`]:
     - FOV +9 in 0.06 s, back over 0.25 s;
     - kick 0.7 studs along the dash;
     - roll 2.5°;
     - Blur 5 for 0.1 s.
  4. Speed lines 0.3 s, local player only (note 15).
  5. Release clips don't move the root; code moves the HumanoidRootPart. [source: `V08/05/Stance…`]
  6. Dash-strike finisher: 3 dark ghosts 0.035 s apart, starting 0.06 s before the hit, alpha 0.45, life 0.22 s. [source]
- **Check:**
  - 30 fps capture: ghosts every 1–2 frames along the path.
  - Normal running never ghosts.
  - FOV returns exactly to base.
- **Kid-safe:** blur and roll go through `MotionScale()`; others only see the ghosts.

---

### R12. Energy beam (charged blast)
- **When to use:** anime beam ultimates, a "laser" cannon skin, boss attacks.
- **Ingredients:** LihFolk `BeamLaser` (built-in looks work without uploads) or 3 Beams between attachments; charge orb Neon ball; endpoint glow, sparks and light.
- **Steps:**
  1. Charge: converging motes plus a Neon orb at the hands growing over 0.6 s (note 15 / `ChargeUp`).
  2. Three stacked Beams: dark edge (widest, LightEmission 0), body (accent), white core (thinnest, LightEmission 1). Each FaceCamera. [source: `LF-vfx`, note 16]
  3. Width 1 → 4 over 0.15 s; width wobble ±10% every 0.1 s; TextureSpeed 2–4. [note 15]
  4. Hairline streaks: keep Brightness low (bloom fattens them). Ribbons read thicker with lower body brightness and a thin white core. [source: `LF-vfx`]
  5. Endpoint every frame: raycast clip to walls; glow sprite, a spark stream, one PointLight. [source: `LF-vfx` BeamLaser]
  6. End: width → 0 over 0.25 s, plus an end burst (R6). Budget about 40 particles and 3 beams (2 below quality 0.55). [source]
- **Check:** the beam never passes through walls; the three layers are visible in a still; the light sits at the endpoint, not on the caster.
- **Kid-safe:** no full-screen white; the beam's end flash is local.

---

### R13. Ultimate / Mythic cutscene that always gives the camera back
- **When to use:** an anime ultimate, a Mythic or Secret cannon shot (`RareReveal`), a boss intro.
- **Ingredients:** a cutscene module with Lock/Hide/Shoot/Restore/Watchdog, letterbox Frames, a title card, a `CutsceneLock` attribute, `workspace.CurrentCamera`.
- **Steps:**
  1. **Lock:** set `CutsceneLock` on the player; disable controls; every other camera, effect and kit steps aside. [source: `V08/05/Cameras…`]
  2. **Hide:** remember which ScreenGuis were enabled and hide them; hide CoreGui and prompts. Bars slide in over 0.25–0.35 s at 8% height, with FOV compensated so the subject keeps its size. [source; 8% from note 15]
  3. **OPEN:** CameraType Scriptable. FOV punch in over 0.12 s (ease out), hold to the `Open` marker (0.15–0.6 s, about 0.21 s), then widen, dolly back and lift over 0.55 s. FOV clamped 35–105. [source: `V08/05/Cinematic Ultimates.md`]
  4. Title card (our move name plus the real odds for rare shots) held 1.35 s; scale 1.6 → 1 in 0.2 s. [source: hold; slam from note 15]
  5. **CLIMAX** on the strongest `Impact` marker: R2 stack.
     - Optional "slow motion" slows **camera time only** (0.3–0.5× for 0.3 s), then ramps back over 0.15 s with a quadratic blend. [source; factor suggested]
  6. **RETURN:** blend 0.55 s back to the player's own zoom and look direction; restore exactly the guis that were on. [source]
  7. **Survive failure:**
     - restore at once on death, respawn, character removal, a script error, or another script taking the camera;
     - watchdog: no frame for 0.6 s, or past the length + 2 s. [source]
  8. Skippable after 2–3 s (touch and gamepad button); a "seen" profile flag. [source]
  9. Frame subjects in the centre 60% (phones and tablets); `RequestStreamAroundAsync` if the shot shows distant things. [source]
- **Check:**
  - Kill the player mid-cutscene: the camera, HUD and controls come back within 0.6 s.
  - A second ultimate continues the cutscene rather than restarting it.
  - FOV and look direction end identical to before.
- **Kid-safe:**
  - in a PvP area, server-enforced invulnerability while locked, or no cutscene [source];
  - reduced motion: cuts instead of swoops;
  - Secret-tier server banners can be muted.

---

### R14. Combo attack clip (M1 1–4) that feels snappy
- **When to use:** making or re-timing any character attack with the AI animation workflow.
- **Ingredients:** R15 rig, Animation Editor or Moon Animator, markers `TrailOn`, `Hit` (value "1"–"4"), `TrailOff`; a combo controller.
- **Steps:**
  1. Light hit lands about 0.2 s after the click (6 f at 30 fps); the finisher at 0.30–0.38 s. [source: `V08/05/Combat Combo…`]
  2. Frame 0–1: something visibly moves (the shoulder drops). Wind-up 2–6 f (light) or 6–15 f (heavy), with the direction obvious: blade cocked on its side, torso turned about 24°, weight back. [source: `V08/03/Combat Animation Craft.md`]
  3. Strike 1–3 f, **arriving at speed** (never ease in to contact). Key strike segments every 0.035–0.045 s so wide arcs don't cut corners. [source]
  4. Contact hold 2–4 f near-still, then 4–8 f settle. [source]
  5. End within 75° per arm joint of the idle; start within 90°. The follow-through of swing N is the wind-up of swing N+1 ("link pose"). [source]
  6. Controller [source]:
     - min gap 0.42 s;
     - combo window 0.9–1.1 s;
     - input buffer 0.15 s;
     - chained press: stop the old track with fade 0.06, play the new with fade 0.04; a fresh press fades in 0.1 s.
  7. Shortened clip? Move the markers with the keys. Data tables divide hit times by playback speed. [source]
  8. Hit-stop in code only (R1); never baked into the clip. [source]
- **Check:**
  - 30 fps: the swing reaches contact on f6.
  - No snap when clicking stops.
  - Fast clicking never "eats" a press (log the buffered presses).
  - No forearm spin across the 180° wrap (blend as CFrames).
- **Kid-safe:** for PvP, raise startup to 6–8 f [suggested, §2 C17]; knockouts are cartoon spins, never gore.

---

### R15. Idle that breathes (player, NPC, shopkeeper)
- **When to use:** every idle; the owner's raw KeyframeSequences that look like statues.
- **Ingredients:** an idle clip (arms and torso only), 2–3 fidget clips, a fidget timer.
- **Steps:**
  1. A 4 s loop (breath cycle 3–5 s). [source: `V08/03/Idle Breathing…`]
  2. Waist pitch 1–3°, both shoulders lifting 1–2°, neck counter under 1° delayed by 1 frame. Inhale 40%, exhale 60%, a tiny pause at the bottom. [source]
  3. Weight shift: hips drift 0.05–0.15 studs over several seconds, the loaded hip up, shoulders counter-tilted, feet planted. [source]
  4. No dead holds: no joint under 4°/s for more than 0.3 s. [source]
  5. Animate arms and torso only, so the default walk moves the legs (skill `roblox-ai-animation`). Last key = first key.
  6. Fidget after 10 s still, then every 16–26 s, never the same one twice running. [source]
  7. NPCs [source]:
     - turn the head toward players within 26 studs (through `C0`, or a PreSimulation overlay);
     - wave within 15 studs;
     - sleep beyond 280 studs;
     - update every frame within 60 studs, every 2nd within 150, every 4th within 300.
- **Check:**
  - Played for 20 s, the character never looks frozen and never pants.
  - Attacks start without a snap (90° rule).
  - Walking while idling doesn't slide.
- **Kid-safe:** n/a.

---

### R16. Hit reaction on the target (dummy, NPC, enemy)
- **When to use:** punching NPCs, training dummies, bosses, other players in fighting modes.
- **Ingredients:** 4 directional flinch clips (front, back, left, right) at Action2; a pooled white Highlight; optional procedural spring flinch.
- **Steps:**
  1. Flinch clip 0.2–0.4 s at **Action2 with a 0.05 s fade**, over whatever is playing, so the enemy's own attack keeps its timing. [source: `V08/05/Hit Reactions…`]
  2. Skip the flinch while a stronger state owns the body (stunned, knocked up, caught, dead). [source]
  3. Flash: a white Highlight from a pool of at most 8, FillTransparency 0 → 1 over 0.1 s; animate a persistent one, never create one per hit. [source]
  4. Procedural option (no clips): joint kick rad/s × k (`k = clamp(mult/2, 0.5, 2)`): head 5.5, arms 4, spine 3.2, legs 0.8, ±25% noise; root spring 6 Hz, damping 0.5, 55°/s about the feet. [source: `V08/04/Procedural Death Knockdown…`]
  5. Stagger at 75/50/25% health: the stagger clip at 0.5× speed, AI paused 1.6 s (bosses 0.9 s). No other enemy clip runs below 1×. [source]
  6. Damage numbers and status come from the server; the attacker's flash, stop and sound are predicted locally at the contact frame, with the echo suppressed per target. [source: `V56/Client Hit Prediction…`]
- **Check:**
  - 30 fps: the flash and flinch start on the frame after contact.
  - Rapid hits don't stack into jitter.
  - The enemy's swing still lands on schedule while it flinches.
- **Kid-safe:** white flash, stars and sparks (no red wounds); "K.O." cartoon spin; flash rate ≤ 1 per 0.12 s per target. [source; Gore Policy]

---

### R17. Reward fly-to-counter (coins, gems, "+N")
- **When to use:** every payoff: the cannon landing reward, pickups, quest rewards.
- **Ingredients:** a pool of icon ImageLabels, the counter TextLabel with a `UIScale`, a pickup sound with a pitch ladder.
- **Steps:**
  1. Spawn 4–8 icons at the event's screen point (note 11), staggered 0.04 s.
  2. Each flies on a curve over 0.35–0.5 s (note 11). Stretch along velocity [source: `V47/Squash Stretch…` §4]:
     - rotate the icon to face its velocity;
     - X scale `1 + k·speed` (k 0.08–0.15, speed in screen heights per second, cap 1.4);
     - Y scale = 1/X.
  3. On arrival: the counter's **art** squashes with its pivot facing the impact (kick −0.12), springing back with damping 0.5 (kit `Spring` Bouncy). The number text is never squashed. [source]
  4. Pickup pitch climbs one semitone per item within 0.5 s and resets after a pause. Many items at once: one "+1,240" per 0.2 s window, not one per coin. [source: `V07/Collectible Pickup FX…`]
  5. The counter rolls (note 14: NumberValue tween 0.35–0.6 s).
  6. Pool the icons; the whole chain runs in one loop for the screen. [source: `V08/05/UI and GUI Animation.md`]
- **Check:** 30 fps: icons visibly stretch mid-flight and relax as they arrive; the counter bumps on the frame the first icon lands; the pitch rises with each icon.
- **Kid-safe:** real amounts only; no flashing counter faster than once a second.

---

### R18. Collectible glint, magnet and pop
- **When to use:** coins on the map, gems, orbs, drops after a landing.
- **Ingredients:** client-side pickup parts (never server Touched), one shared animation loop, a star emitter per pickup type.
- **Steps:**
  1. Idle: one shared loop bobs and spins every pickup with a phase offset. Glint = `Emit(1)` on a **fixed** timer of 1.5–3 s per item, never a random Rate (random gaps under 1 s strobe). [source: `V07/Collectible…`, `VFX-ITEMS.md` §5]
  2. Magnet: speed accelerates by 120 studs/s per second, capped at 90 studs/s, toward the player's root. [source]
  3. Collect pop: scale to 1.3× over 0.05 s, vanish, back to the pool. Burst 6–12 sparkles in the item colour (radial is fine here). [source]
  4. Sound: short and bright, one semitone up per pickup within 0.5 s. [source]
  5. The client batches collect requests every 0.1–0.25 s; the server checks distance and rate. [source]
- **Check:**
  - With 50 coins on screen, no glints fire in the same frame.
  - The magnet arrives with speed (not slowing at the end).
  - The server rejects a teleport-grab.
- **Kid-safe:** ≤ 1 glint per item per 1.5 s.

---

### R19. Hatch / reveal in four beats, with a time budget
- **When to use:** egg hatches, cannon unlocks, rare shot cards, summon banners.
- **Ingredients:** `RareReveal`, a reveal card (CanvasGroup), the item model in a ViewportFrame, a rays sunburst ImageLabel, sounds (riser, reveal, sting).
- **Steps:**
  1. Lengths: keep note 17's ladder (Rare 0.6 s … Secret 4.5 s). Track total reveal time; keep it under 10% of play time, and let players cut it further ("Skip below tier" setting, like Sol's RNG). [source: `V47/Reward Moments…`, `signature_moments_teardown.md`]
  2. Beats for a long reveal (3.5 s version; scale the others down) [source]:
     - anticipation 0–1.2 s: the container shakes with growing amplitude while a riser climbs, light leaking from the seams;
     - reveal 1.2–1.5 s: the item appears at 1.15× with an **instant** squash and springs back (R17 squash);
     - payoff 1.5–3.0 s: the name and rarity banner slide in, stats count up, the sting peaks;
     - settle 3.0–3.5 s: background effects fade.
  3. Buttons appear **last**; the primary one becomes clickable 0.3 s after appearing. [source]
  4. The tier colour shows from the first frame (note 17; honest suspense). The odds card ("1 in N") is shown.
  5. Queue: priority by tier; merge same-kind rewards ("+3 items", best shown); wait for safe moments (not mid-cutscene or in a menu, up to 20 s, then downgrade to a toast). With more than 3 queued, play each at 0.5× length. [source]
  6. Multi-open: cascade with a 0.08 s stagger; the rarest gets the solo reveal (note 11).
- **Check:**
  - Log the reveal seconds per 10 minutes of play: under 60 s.
  - Mashing "open" never confirms a purchase.
  - A 30 fps capture shows the squash frame exactly on the reveal beat.
- **Kid-safe:** no full-screen colour flash at any tier (the library's Legendary flash is out); odds and pity always shown; no "almost got it" tease.

---

### R20. Level-up burst (0.8 s, small and frequent)
- **When to use:** grind level-ups (about once a second while grinding, note 14), cannon upgrades.
- **Ingredients:** a ground ring (CylinderHandleAdornment or a flat emitter), a Beam column, a star emitter, the reused Highlight.
- **Steps:**
  1. **0 s** [source: `HB` §6.6]:
     - ground ring 8 studs over 0.3 s;
     - a column Beam from the feet to +12 studs, Width0 3 → Width1 0, LightEmission 1, Transparency to 1 over 0.4 s;
     - 24 stars: Speed 12–20 up, Spread 35, Acceleration (0, −25, 0), RotSpeed ±180, Size 0.6 → 0, life 0.6–0.9 s.
  2. **0.05 s:** Highlight flash (FillTransparency 0.6 → 1 over 0.3 s) and the UI "Level Up! [xN]" pop. [source; Highlight fade suggested]
  3. Frequent version: when level-ups come under 1.5 s apart, drop the column and stars and keep only the ring and the text counter (note 14 streak). [suggested]
  4. Big version (LihFolk `LevelUp`, 76 particles): two escalating foot rings, a scan ring rising round the body, a light pillar, a sparkle fountain, confetti. Only for milestone levels. [source: `LF-vfx`]
- **Check:**
  - 10 level-ups in 10 s stay calm (no flash pile-up).
  - The milestone version is clearly bigger in a side-by-side.
- **Kid-safe:** the Highlight "flash" is a soft fade, not a white screen; ≤ 1 per second.

---

### R21. Rebirth explosion (the loudest effect, about 1.6 s) with fluttering confetti
- **When to use:** rebirth/evolution, first Legendary, a new cannon tier.
- **Ingredients:** R4's implosion emitter, a PointLight, ground discs, a ForceField shock sphere, star and confetti emitters, note 14's white fade.
- **Steps:**
  1. **0–0.35 s anticipation** [source: `HB` §6.7]:
     - implosion (Sphere, Surface, Inward), Speed 25, life 0.35 s, Rate 60 for 0.3 s, white → rebirth colour;
     - PointLight 0 → 4.
  2. **0.35 s impact** [source]:
     - core flash (glow, size → 14, 0.2 s);
     - two ground discs (12 and 18 studs, 0.08 s apart);
     - a ForceField shock sphere to 16 studs over 0.5 s, fading;
     - 30 stars (Speed 25–45, Drag 4, Acceleration (0, −30, 0)).
  3. **Confetti** [source: `HB` §6.8]:
     - `Emit(40)` (15 for small rewards), Speed 25–40 up, Spread (35, 35), Acceleration (0, −22, 0), Drag 1.5;
     - life 2.2–3 s, Size 0.3–0.4, Rotation 0–360, RotSpeed ±360;
     - LightEmission 0, LightInfluence 0.3;
     - **flutter** with Squash `{0,0},{0.2,0.8},{0.4,−0.6},{0.6,0.8},{0.8,−0.6},{1,0}`;
     - multicolour from one 2×2 flipbook (framerate 0, random start, Color white), or 4 emitters with `SquareParticle`;
     - transparency held to 0.85 of life, then fading.
  4. The screen moment uses note 14's white fade (0.22–0.25 s in, 0.45–0.5 s hold, 0.3–0.35 s out), **instead of** the handbook's 0.6 → 1 white ImageLabel flash. [§2; owner-approved timing]
  5. **0.4–1.6 s:** lingering motes Rate 15 for 1 s, LockedToPart; then R9 at intensity 0.4 for a few seconds.
- **Check:**
  - The 30 fps capture shows inward motes, then one burst frame; confetti tumbles (flips) rather than sliding.
  - Particles peak under about 120 for a local-only effect.
- **Kid-safe:** exactly one white fade per moment; confetti LightEmission 0 (no glare).

---

### R22. Chase camera and launch cut without drift
- **When to use:** cannon shot flight, a dash camera, any camera follow or FOV effect layered on the default camera.
- **Ingredients:** a render step at `Camera + 1` (plus an undo at `Camera − 1`), `TweenService:SmoothDamp`, an FOV contribution tracker.
- **Steps:**
  1. Keep the reference's normal-shot camera from note 17 (a short hold on the shooter, a 0.4–0.45 s swing into side-on chase, no cut). This recipe is about the *mechanics*.
  2. Follow with `TweenService:SmoothDamp(current, target, velocity, smoothTime ≈ 0.12–0.2)`, keeping the velocity between frames (or note 16's `1 − exp(−8·dt)` lerp). Never a constant per-frame lerp. [source: `V62/TweenService…`, `V08/04/Springs…`]
  3. FOV: remember the player's base FOV at start. Each effect owns an envelope (attack, hold, release) that ends at exactly 0. Sum them with caps (+12° FOV, 1.6 studs offset, 4° roll) and **replace** your previous contribution; never `+=`. [source: `V08/05/Camera Shake…`, `V56/Layering Camera Feedback…`]
  4. Landing dip: 0.12–1.1 studs scaled by k² (k = normalised fall speed 45–140 studs/s), FOV −2k. A mini shake only past k = 0.5. [source]
  5. If another script wrote FOV (sprint, zoom), detect it by comparing with the value you last wrote and rebase. [source]
  6. Hand the camera back **before** signalling "done" (note 17), and also on death or respawn.
- **Check:**
  - After 100 launches, FOV and camera yaw are exactly back on base.
  - At 30 fps the follow doesn't stutter.
  - A hitch (alt-tab) doesn't pop the camera (dt clamp 0.1 s).
- **Kid-safe:** FOV changes ≤ 15° [suggested]; reduced motion halves FOV moves and removes roll. [source: comfort table]

---

### R23. UI pop, shine and stagger (premium menus)
- **When to use:** any panel opening, a NEW! badge, a reward card, an idle "next goal" card.
- **Ingredients:** a centred inner "content" frame with a `UIScale`, a `UIGradient` shine band, a `CanvasGroup` for fades, one loop per screen.
- **Steps:**
  1. Pop: UIScale 0.6 → 1.05 → 1 with Back, 0.25 s, about the centre (AnchorPoint 0.5, 0.5, or a centred inner frame inside layouts). Tween `UIScale`, never `Size`, inside a layout. [source: `V08/05/UI and GUI Animation.md`]
  2. Multiply by the stored phone `BaseScale` attribute. [source]
  3. Children: one hero motion per screen; the rest fade or pop with a 20–40 ms stagger, capped so the last lands within 0.3 s. [source]
  4. Shine: UIGradient Transparency band, Rotation 25°, Offset (−1, 0) → (1, 0) over 0.5 s [suggested]. Cadence 1.6 s for toasts, 3.4 s for item cards, 7 s for an idle goal card; never on permanent HUD. [source]
  5. Fades of a whole card: `CanvasGroup.GroupTransparency` (no stacked-transparency artefacts). [source]
  6. Buttons work on frame one; closing stops input at once. [source]
  7. Press squash −0.12 on the art layer only (text separate), with a spring of damping 0.5 at about 4 Hz. [source: `V47/Squash Stretch…`]
  8. Keep note 14's motion table for hover, press and close times; this recipe adds what that table lacks.
- **Check:**
  - On a phone (UI scale 0.8) the pop ends at 0.8, not 1.
  - Pops grow from the centre.
  - No loops run while the menu is closed (count connections).
- **Kid-safe:** shine at most every 1.6 s; nothing blinks.

---

### R24. Sound on the beat (our own sounds)
- **When to use:** every hit, launch, pickup and UI sound made with `tools/sfx/make_sfx.py`.
- **Ingredients:** `make_sfx.py`, SoundGroups (Master > SFX / Music / UI / Ambience), a small SFX module with bags, cooldowns and a voice cap.
- **Steps:**
  1. Make files with the transient within 5–10 ms of the start; keep a 30–60 ms swell on whooshes. Write each file's **peak time** into its definition. [source: `LF-sfx`, `V56/Sound Design Pitfalls…`]
  2. Level every one-shot to −18 LUFS momentary max, true peak −1 dBTP. Set the mix with `Volume` only (UI 0.15–0.35). [source: `LF-sfx`]
  3. On a marker, start the sound with `TimePosition = peak`, so the crack lands on the frame. Target 0–30 ms late and **never early**. [source: `V47/Feedback Timing…`]
  4. Layers for a hit: transient (5–60 ms), body, tail (0.1 s later, lower), and an optional sweetener; plus note 17's sub layer for rare tiers. Melee tails ≤ 0.6 s. [source]
  5. Variation: round-robin bags of at least 3 takes (no repeat twice running), pitch ±3–6%, volume ±1–2 dB. **No random pitch on stings, the charge "ready" ping or the rare chime.** [source]
  6. Voices: cap 24 PC / 16 touch; 30 ms per-name cooldown; a new swing chokes the last. [source]
  7. 3D: InverseTapered rolloff (melee 8/100, ability 12/200, explosion 30/450); our own player's sounds in 2D; others' at 0.7× volume. [source]
  8. Ducking: tween the Music group down 3–6 dB on heavy hits, releasing over 250–500 ms. [source]
  9. Preload sounds on spawn; new uploads can fail preload for 20–60 s. [source]
- **Check:**
  - At 0.25× speed in Studio the crack lands on the contact frame.
  - 50 repeats don't grate.
  - The phone speaker still carries 1–4 kHz content on key cues.
- **Kid-safe:** no harsh stand-ins (note 14: silence beats a bad sound); sliders per bus with a squared curve (`base × v²`).

---

### R25. Juice governor (performance safety net for every recipe)
- **When to use:** any game that ships R1–R24, before showing it on a phone.
- **Ingredients:** a client module reading the smoothed frame time and `UserGameSettings.SavedQualityLevel`, used by `Emit.Scale`.
- **Steps:**
  1. Three tiers [source: `V47/Juice on a Budget…`]:

     | Tier | Spawns per frame | Particles per second | Live Highlights | Post-processing | Particle scale |
     |---|---|---|---|---|---|
     | Low | 3 | 120 | 2 | Off | 0.4 |
     | Mid | 8 | 400 | 5 | Off | 0.7 |
     | High | 20 | 1200 | 8 | On | 1 |

  2. Drop a tier when the average frame time stays above 1.15× target for 2 s; raise one after 10 s below 0.8×, never above the player's setting. Ignore single spikes over 0.25 s. [source]
  3. Feed the tier's scale into `Emit.Scale`. `Emit()` ignores Roblox's own quality thinning; touch devices start at 0.6. [source: `V07/Slash VFX…` §3]
  4. Global live-particle cap 360 mobile / 900 PC; above 75%, drop decoration (dark wakes, ink, glints) and halve counts. Others' effects at half detail beyond 160 studs, none beyond 220; at most 8 effects at once. [source: `LF-vfx`]
  5. Pools for everything that spawns per hit (ghosts, rocks, popups, Highlights); one Heartbeat stepper for all live effects, disconnected when idle. [source]
  6. Substitute, don't delete, on low tiers: smaller, more opaque pieces instead of full-screen glows; no post-processing. [source]
  7. Gameplay-critical effects (telegraphs, landing markers) are flagged "important": simplified, never skipped. [source]
- **Check:**
  - A 15–20 minute session on a warm mid phone holds its frame rate during big moments.
  - The live-particle counter never passes 360 on touch.
  - Low tier still shows every gameplay cue.
- **Kid-safe:** lower tiers never remove the honest parts (odds cards, reward numbers).

---

## Part 2. Anime combat recipes (A1–A8) (kid-friendly, IP-free)

**A1. 4-tap combo ("Bop chain")** [numbers from LihFolk/TSB pattern; tuning estimated]
- Hits land at 0.20 / 0.20 / 0.23 / 0.32 s; clips 0.42 / 0.42 / 0.47 / 0.62 s. Min gap 0.45 s, 0.15 s input buffer, combo window 1.0 s.
- Damage weights 3/3/4/5 (the last hit is biggest).
- Hits 1–3: a small spark, a squeaky "bop", 0.4 s stun.
- Hit 4: knockback (LinearVelocity on the victim's client, up = 0.3 x speed), 70 ms hit-stop, 0.2 trauma, 3 colourful afterimages, a star burst.
- Total combo cap 3 s. After a knockdown, 0.75 s get-up shield.

**A2. Dash ("Zoom")**
- About 70–80 studs/s for 0.3 s (about 22–24 studs), eased out, not a hard stop.
- Side dash 2 s cooldown; front dash 4–6 s with a tiny bump.
- 0.3–0.4 s dodge window counted on the server.
- Camera: +9 FOV pulse, Blur 5 for 0.1 s. A cartoon dust puff at the start point.

**A3. Guard and perfect guard**
- Hold block: x0.3 damage, front only.
- Tap within 0.2–0.26 s before the hit = perfect guard. It gives a sparkle shield pop and a 1 s daze on the attacker (kids: not 2.2 s).
- 0.55 s re-arm. Stuck escape: one "wiggle free" per 20–30 s.

**A4. Power-up meter ("Super mode")**
- The meter fills from landing hits and partly from blocking or getting hit (comeback).
- Activation: 0.6 s untouchable power-up pose, one ring and one flash.
- 45–60 s of super mode, heals a little, swaps the 4 moves for bigger ones (cooldowns 10–40 s); the aura stays on.
- Super finale: camera package per §4 at Epic or Legendary values. The freeze bubble holds targets for at most 2 s, then a big bounce, never a long stun. The meter empties and all moves go on a short cooldown afterwards (the "cost").

**A5. Skill cooldown ladder**
- 4 skills at 8 / 12 / 15 / 20 s (kids: slightly shorter than JJS's 13–20).
- The super finale gets a 60–90 s cooldown, or one use per super mode.

**A6. Impact frame (safe)**
- At the climax only: 1 frame (1/30 s) of a white silhouette plus a black ColorCorrection (Saturation -1, Contrast +1), then a colour punch back.
- Never a negative image, max 1 per second, and only on Legendary+ moves.

**A7. Tall flipbook VFX**
- Author slashes and flame columns as 4x8 Custom flipbook sheets (non-square, e.g. 512x1024).
- Fall back to Grid4x4 if Custom isn't live for all clients yet (it was a client beta in Oct 2025; check before relying on it).

**A8. Summon reveal behind UI cards**
- Put real particles and beams in Workspace in front of the camera behind the card (not in a ViewportFrame).
- Rarity ladder from Playbook 17. Odds and pity always visible.

## Part 3. Anime combat numbers (reference table)

### M1 combo

| Mechanic | Value | Source |
|---|---|---|
| M1 hits per chain (TSB) | 4; the 4th knocks back (or slams) | [namu TSB](https://www.namu.moe/w/Strongest%20Battlegrounds) |
| M1 hits per chain (JJS) | 4 for most characters, some differ | [namu JJS](https://www.namu.moe/w/Jujutsu%20Shenanigans) |
| M1 damage split (TSB, % of HP) | 3 / 3 / 4 / 5 (finisher biggest) | [namu TSB](https://www.namu.moe/w/Strongest%20Battlegrounds) |
| Holding click | auto-repeats the chain | [namu TSB](https://www.namu.moe/w/Strongest%20Battlegrounds) |
| M1 variants | uppercut and downslam are a modified last hit (e.g. "2 M1s then downslam", "3 M1s then uppercut") | [bloxodes TSB techniques](https://bloxodes.com/wiki/the-strongest-battlegrounds/techniques) |
| Combo techniques count (TSB) | 176 community-named techs, 17 universal | [bloxodes](https://bloxodes.com/wiki/the-strongest-battlegrounds/techniques) |
| Light hit contact time | about 0.20 s (6 frames at 30 fps) from click | [LihFolk `08 Animation/05 Systems/Combat Combo Systems.md`] |
| Swing durations (4-hit sword chain) | 0.42 / 0.42 / 0.47 / 0.62 s, hits at 0.20 / 0.20 / 0.23 / 0.30 s | [LihFolk same] |
| Finisher hit time | 0.30–0.38 s light, 0.54–0.74 s heavy | [LihFolk same] |
| Min gap between presses | 0.42–0.7 s by class (default 0.55 s) | [LihFolk same] |
| Combo window (time to continue) | 0.9–1.1 s | [LihFolk same] |
| Input buffer | 0.1–0.2 s; over 0.3 s "plays itself" | [LihFolk same] |
| Chain fades | new swing 0.04 s, old swing out 0.06 s, fresh press 0.1 s | [LihFolk same] |
| Finisher-only extras | 0.2 trauma shake, 3 afterimages from 0.06 s before hit, 0.035 s apart, alpha 0.45, life 0.22 s | [LihFolk same] |
| Worked-build defaults | cooldown 0.35, combo window 0.9, finisher recovery 0.6, windup 0.15, stun 0.4 s, hitbox forward 3.5 studs, last hit knockback x1.6 | [LihFolk `24 Worked Builds/Melee Combat System End to End.md`] |
| Server cooldown tolerance | 0.06 s (50–80 ms band) | [LihFolk same] |
| Hit-stop | 50–100 ms; formula `0.03 + 0.045 * strength` (50–89 ms); slow tracks to 0.12x, not 0 | [LihFolk `Hit Reactions Stagger and Hit-Stop.md`] |
| Total combo cap | 3–4 s, or decaying hitstun per hit | [LihFolk `Genre Playbook - Battlegrounds and Arena Fighters.md`] |

### Dash, block, parry, escapes

| Mechanic | Value | Source |
|---|---|---|
| Front dash (JJS) | 6 s cooldown, deals small damage, blockable from the front | [namu JJS](https://www.namu.moe/w/Jujutsu%20Shenanigans) |
| Side dash (JJS) | 2 s cooldown, no damage | [namu JJS](https://www.namu.moe/w/Jujutsu%20Shenanigans) |
| Front/back vs side dash | front/back cooldowns are longer than side (Sorcerer BG) | [itemlevel](https://itemlevel.net/?p=170418) |
| Front dash (TSB) | 4% damage plus a brief stun on contact | [namu TSB](https://www.namu.moe/w/Strongest%20Battlegrounds) |
| Back tumble (TSB) | invulnerable to M1s | [namu TSB](https://www.namu.moe/w/Strongest%20Battlegrounds) |
| Community "TSB-like" dash | LinearVelocity 80 studs/s for 0.3 s (about 24 studs), 2 s cooldown | [DevForum dash](https://devforum.roblox.com/t/very-smooth-dash-system-like-strongest-battlegrounds/2590353) |
| Dash cooldown, genre band | 1.5–3 s | [LihFolk Battlegrounds playbook] |
| Dash i-frames vs big attacks | 0.40 s, counted from the server's receipt; telegraphs at least 0.45–0.5 s | [LihFolk `Client Prediction and Reconciliation for Combat.md`] |
| Dash camera | +9 FOV (0.06 s in, 0.25 s out), 0.7 stud kick, 2.5° roll, Blur 5 for 0.1 s | [LihFolk `Camera Shake and Camera FX.md`] |
| Ragdoll escape (TSB) | dash while ragdolled; once per 30 s | [namu TSB](https://www.namu.moe/w/Strongest%20Battlegrounds) |
| Ragdoll escape (JJS) | needs a 100% gauge and empties it | [namu JJS](https://www.namu.moe/w/Jujutsu%20Shenanigans) |
| Burst (old JJS) | shockwave stuns nearby for about 2 s | [namu JJS](https://www.namu.moe/w/Jujutsu%20Shenanigans) |
| Wall run uses (JJS) | 3 / 2 / 1 by HP band (66–100 / 33–66 / 1–33%) | [namu JJS](https://www.namu.moe/w/Jujutsu%20Shenanigans) |
| Parry window | 0.26 s from raising guard; 0.15 s variant | [LihFolk `Hit Reactions...`], [LihFolk Melee Combat build] |
| Parry reward | attacker stunned 2.2 s | [LihFolk `Hit Reactions...`] |
| Parry re-arm | 0.55 s (stops guard-tap spam) | [LihFolk same] |
| Held block | damage x0.25–x0.3, front only (dot > 0.2), min hold 0.3 s | [LihFolk same], [LihFolk Melee build] |
| Blocked special | half damage (12.5 -> 6.25 on one JJS move) | [rblxguide JJS](https://rblxguide.com/games/jujutsu-shenanigans/characters/honored-one) |

### Stun, knockback, ragdoll

| Mechanic | Value | Source |
|---|---|---|
| M1 stun per hit | 0.4 s (starting value) | [LihFolk Melee build] |
| Get-up invulnerability | 0.5–1 s | [LihFolk Battlegrounds playbook] |
| Ragdoll length | 1–2 s, shortened on low-end devices | [LihFolk same] |
| Wall combo (TSB) | 12% damage plus ragdoll | [namu TSB](https://www.namu.moe/w/Strongest%20Battlegrounds) |
| Knockback method (community answer) | LinearVelocity on the **victim's client**; server-side impulses show lag or "teleport" on other screens | [DevForum knockback](https://devforum.roblox.com/t/how-can-i-achieve-knockback-like-in-battleground-games/2545817) |
| Knockback example impulse | (0, 65, 35): up-heavy pop | [same] |
| Knockback with ragdoll | some devs set network owner to nil (server) during ragdoll, restore after | [DevForum TSB knockback](https://devforum.roblox.com/t/how-to-reduce-delay-in-knockback-like-tsb/3226267) |
| Knockback velocity shape | flat direction x speed + up = speed x 0.3 | [LihFolk Melee build] |
| Light swing lunge | 24 studs/s for 0.07 s; lunges only on finishers | [LihFolk `Combat Combo Systems.md`] |

### Skills, ultimates, awakening

| Mechanic | Value | Source |
|---|---|---|
| Base skill cooldowns (one JJS kit) | 13 / 15 / 18 / 20 s | [rblxguide JJS](https://rblxguide.com/games/jujutsu-shenanigans/characters/honored-one) |
| Barrage move | 15 light hits at 0.5 dmg + 3 heavy at 1.5 + final 4 | [same] |
| Pull move | pulls targets within 35 studs | [same] |
| Projectile | travels 40 studs, 15-stud blast radius | [same] |
| Awakening length (one JJS kit) | 60 s, heals 25 HP on activation | [same] |
| Awakened skill cooldowns | 10 / 15 / 17 / 40 s | [same] |
| Big awakened beam | about 3 s charge before it fires | [same] |
| Domain-style ultimate | 120 s cooldown, 14 s stun on targets | [same] |
| Domain (other guide) | 7 s on one target, 14 s area version; afterwards all skills on cooldown, meter 0 | part 1 ([Sportskeeda](https://www.sportskeeda.com/roblox-news/jujutsu-shenanigans-0-2-domain-guide)) |
| Domain clash | 15 s | [namu JJS](https://www.namu.moe/w/Jujutsu%20Shenanigans) |
| Awakening meter fill (TSB) | each landed hit; Burst gauge from hits taken in a short window | [namu TSB](https://www.namu.moe/w/Strongest%20Battlegrounds) |
| Awakening cost of a skill | some moves cost 6% of the meter | [rblxguide JJS](https://rblxguide.com/games/jujutsu-shenanigans/characters/honored-one) |
| Awakening (TSB, one kit) | lasts "until you spend a move or die" | [bloxodes TSB characters](https://bloxodes.com/wiki/the-strongest-battlegrounds/characters) |
| Awakening, genre band | 30–60 s; 4 abilities at 5–25 s cooldowns | [LihFolk Battlegrounds playbook] |
| Crit chain (TSB) | 2+ crits within about 5 s -> special hit at 25%, chains up to 3 | [namu TSB](https://www.namu.moe/w/Strongest%20Battlegrounds) |
| Server size | TSB 15, JJS 20 | [namu TSB](https://www.namu.moe/w/Strongest%20Battlegrounds), [namu JJS](https://www.namu.moe/w/Jujutsu%20Shenanigans) |
| Respawn | 2–5 s, 2 s spawn shield | [LihFolk Battlegrounds playbook] |
| Ultimate VFX budget | 5,600 particles per 2 s for the caster; 3,200 per 2 s normal (onlookers half) | [LihFolk `VFX Timing with Animation.md`] |
| Extras drawn only within | 220 studs of the camera | [LihFolk same] |

### Reading the numbers [estimated]
- **Cooldown ladder:** dash 2–6 s < skills 13–20 s < awakened skills 10–40 s < domain-style ultimate 120 s. Each tier is roughly 3–6x the one below.
- **Awakening = 60 s with a heal.** It is the comeback mechanic: the meter fills from landing hits, so the losing player also gets it from blocking or landing a few hits.
- **The finisher gets the most damage, the latest hit time, the knockback and all the extras.** The first three hits are quick and quiet.

---

## Part 4. Corrections to older notes (library vs notes 15–17; fixes applied Oct 31 where marked in those notes)

| # | Topic | Notes 15–17 say | Library says | Follow | Why |
|---|---|---|---|---|---|
| C1 | **How to hit-stop** | 15 §4: `track:AdjustSpeed(0)` for 0.04–0.1 s, then restore | Catch-up: 0.12× for d, then 1.88× for d. Plain freeze drifts behind clock-timed VFX and server hits, and 0 speed reads as a hitch (`V08/05/Hit Reactions…`) | **Library** for character attacks with scheduled effects. For our client-only ball, freezing the ball is fine; keep 16's "TimeScale 0.05, never 0" for emitters | Measured desync in a live game; the fix is small |
| C2 | **Light hit-stop** | 15: Light 0.04 s. 16: 30–60 ms light, 80–150 ms heavy | Light gets **no** stop (a glint and a sound). Stop = 0.03 + 0.045·strength (50–89 ms). Under 66 ms is unreliable at 30 fps. Budget 140 ms per 0.6 s (`V47/Hit-Stop…`). `V08/03/Combat Animation Craft.md` repeats the 30–60/80–150 rule of thumb | **The measured formula.** Light 0, Medium 50 ms, Heavy 66, Finisher 75, Ultimate 89; ceiling 100–120 ms | Measured beats rule of thumb; 150 ms reads as lag; phones drop sub-2-frame stops |
| C3 | **Impact frame timing** | 15: ColorCorrection for **0.07 s** on a timer | Count **rendered frames** (1–2) with PreRender; play inside the hit-stop; at most 2 frames (`V47`, `V08/05/Camera Shake…`) | **Library** | A seconds-based flash is 2 frames at 30 fps but 17 at 240 fps (a strobe). Frame counting also suits our 1-flash-per-second rule |
| C4 | **When the flash fires** | 16 §1: "peak inside the first 25%"; kit `Hit` flashes on the contact frame | Flash **1 frame after** contact, about 0.6× body size; muzzle flash about 0.6× impact (`V07/Projectile VFX…`, `LF-vfx`, Ice Ball recipe) | **Library**, and it fits 16 (one frame is still the first 25%) | The blind reviews found a contact-frame flash hides the landing |
| C5 | **Shake order and decay** | 15 §4: shake on heavy hits, timing unspecified. 16 §4: trauma +0.4 decaying 0.5/s | Kick on the hit frame; **noise starts when the freeze ends**; ultimate decay 1.45/s; noise ≤ 0.4×fps; scale by FOV (`V08/05/Camera Shake…`, `V47`) | **Library** for order. Decay: about 1.0–1.5/s [suggested], since 0.5/s keeps a 0.4 shot shaking 0.8 s | Shaking during a freeze hides the freeze; slow decay tires kids over long sessions |
| C6 | **Aura particle budget and build** | 15 §3: about 60 live at tier 0.5, about 110 at tier 1; welded invisible box; Highlight fill 0.85; PointLight on | Persistent auras: about 15 alive, 3–8/s per layer, on Attachments, Highlight **FillTransparency 1** (fill tints the body), light **off** (shins glow), sleep beyond 160 studs (`V07/Auras, Shields…`) | **Both, by role.** Note 15's full aura only for the local player's charge or transformation burst (a few seconds). Anything worn all the time, or on other players, uses the library recipe (R9) | 12 players × 110 particles breaks the 360 mobile cap before anyone acts |
| C7 | **Mobile particle cap** | skill §7: 150–300 on screen on mobile; 16/17: about 100 per shot | LihFolk module: 360 mobile / 900 PC live cap, decoration dropped above 75% | **Use 360 as the hard cap and 150–300 as the normal target** | They agree once one is called a cap and the other a target |
| C8 | **"Use LihFolkVFX presets as they are"** | 15 §2, §5 | The slash presets need textures and meshes from a **separate LihFolk Asset Pack not in this repo**. Empty ids skip layers with a warning. Most presets are "draft, not reviewed". Everything is "untested in Studio" (`LF-vfx`) | **Library caveat wins.** Plug-and-play only for the ability module's built-in looks (HandleAdornments, Neon, ForceField, Highlights) | Note 15 overstates readiness. The owner would see blank slashes |
| C9 | **Highlight limit** | 15 §3: "Roblox caps Highlights at 31" (17 corrects to 255) | 255 engine limit, but budget 3 decorative + a flash pool of 8; animate one persistent Highlight (`V07/Highlights…`, `V08/05/Hit Reactions…`) | **17 + library**; delete the 31 line in 15 | Outdated number |
| C10 | **Sound sourcing** | Repo CLAUDE.md and 17 §7: make our own with `make_sfx.py` | `LF-sfx`: licensed libraries only, "no procedurally generated placeholders" | **Repo CLAUDE.md** (the owner's rule). Borrow LF-sfx's loudness, onset, bag and voice rules | Owner rules override third-party guides |
| C11 | **Random pitch** | 17 §7: ±8% on repeated clicks and coins | ±3–6% on transients and bodies; **never randomise tonal stings or signature cues** (`LF-sfx`) | **±3–6%** for noisy layers; deterministic semitone ladders (coins, skips) stay as 17 says | ±8% makes tonal UI sounds go off-key |
| C12 | **Toolbox kits and copied looks in tutorial videos** | 15/17: our own look, never theirs | Videos use a Toolbox "Demon Slayer Kit", a Goku hero and AI images of a Studio scene (`VN/VFX/…`) | **Notes 15/17** | IP takedown risk (LihFolk TSB case study). Use the videos' *mechanics* only |
| C13 | **Reveal lengths by tier** | 17 §2: Rare 0.6, Epic 1.2, Legendary 2, Mythic 3, Secret 4.5 s | `V47/Reward Moments…`: Rare 1–1.5, Epic 2, Legendary 3–4, top 5–6 s; Legendary gets a full-screen colour flash | **17's lengths** for a 6-second launch loop, plus the library's **<10% of play time** rule and queue compression. **Never** the full-screen flash | The cannon loop repeats every 6 s; long reveals blow the budget; flashes break the kid-safe rule |
| C14 | **Letterbox size** | 15 §7: 8% of screen height, 0.15 s | 3.5–7.5% (light package) or 9.5–12% (full cutscene), in over 0.35 s, with FOV compensation so the subject doesn't shrink (`V08/05/Cameras…`) | **8% is fine**; add FOV compensation and a 0.25–0.35 s slide [suggested] | 0.15 s bars on top of a cut feel abrupt |
| C15 | **Ultimate camera move** | 15 §7: cut to low ¾, FOV 70→55 over 0.4 s | OPEN: FOV punch in 0.12 s, hold to the `Open` marker (0.15–0.6), then widen and dolly over 0.55 s; FOV clamp 35–105; return blend 0.55 s (`V08/05/Cinematic Ultimates.md`) | **Library timing**, with our narrower FOV range | Measured on 88 ultimates; ours is a guess |
| C16 | **Weapon trail lifetime** | 17 §3 (from a video): Trail Lifetime 0.5, MinLength 0.1, MaxLength 0. 16 §3: 0.15–0.3 s | Trails only for arcs under 120°; otherwise crescents; `Trail:Clear()` first; projectiles: lifetime from speed (12–30-stud streak) | **0.15–0.3 s for swings** (library and 16). 0.5 s only for slow, big movers (the dragon in the video) | A 0.5 s trail on a fast swing wraps the body |
| C17 | **Attack startup** | 15 §6: M1 wind-up 2–3 f | Light PvP attacks under 8 f startup can't be reacted to; light hit at about 6 f from click (`V08/03/Locomotion and Melee…`, `V08/05/Combat Combo…`) | **15 for PvE** (kids hitting dummies or NPCs). In PvP, 6–8 f [suggested] | Both are right for their mode |
| C18 | **Music ducking method** | 17 §7: CompressorSoundEffect side-chained on the Music group | Classic Sounds can't sidechain; tween the Music group 3–6 dB down (release 250–500 ms), or use the Audio API's `AudioCompressor` (`LF-sfx`) | **Library** | The classic `CompressorSoundEffect` has no sidechain input; 17's recipe won't work as written |
| C19 | **Flipbook gutters** | 16/17: 4–8 px, "8 px gutters" | Margins 16/12/8 px for 512/256/128-px cells; exactly 1024×1024 or the flipbook won't animate (`V07/Designing VFX Textures…`, `V62/ParticleEmitter…`) | **Library** (scale the margin with the cell) | Bigger cells bleed more when mipmapped |

---
