# Cannon Shot / Projectile Launch Animation: Frame-by-Frame Recipe for Roblox

Scope: how to make a cannon firing a ball (or a player) feel great. It covers anticipation, fire, recoil, follow-through, flight, camera and landing, with numbers.

How to read this note:
- **Sourced numbers** carry a link.
- **Numbers in "Inferences"** are this researcher's suggested starting values, built from the sourced principles. They are not quoted from a source; tune them by eye on a 30 fps capture.
- **Research budget was small** (about 20 tool calls). Several famous talks (Nijman's "Art of Screenshake", "Juice it or Lose it") have no accessible transcript with numbers, so their numbers are listed as gaps rather than invented.

---

## 1. Object animation principles applied to a cannon (anticipation, squash/stretch, recoil, overshoot, wobble)

### Takeaway
A juicy cannon shot is the classic animation chain: anticipation (squash and lift), then a very fast release (stretch plus recoil), then follow-through that overshoots and settles. Squash and stretch should keep volume roughly constant. No source gives cannon-specific frame counts, so the timings below are inferences. They are built on spring and easing tools that Roblox supports.

### Cited Findings
- **Squash and stretch** gives weight and flexibility. The key rule is that "an object's volume does not change when squashed or stretched": if it gets taller, its width and depth shrink to match. — [Twelve basic principles of animation (wiki mirror)](https://cavac.at/cavacopedia/Twelve%20basic%20principles%20of%20animation)
- **Anticipation** prepares the audience for an action and makes it believable (a dancer bends the knees before a jump). — [same](https://cavac.at/cavacopedia/Twelve%20basic%20principles%20of%20animation)
- **Follow-through and overlapping action:** loose parts keep moving after the main body stops, then get pulled back or oscillate. Different parts move at different rates. — [same](https://cavac.at/cavacopedia/Twelve%20basic%20principles%20of%20animation)
- **Slow in, slow out:** more frames near the start and end of an action and fewer in the middle. **Arcs:** thrown objects follow a parabola. **Exaggeration:** motion that only imitates reality looks dull, but it needs restraint. — [same](https://cavac.at/cavacopedia/Twelve%20basic%20principles%20of%20animation)
- **"Juice It or Lose It"** (Martin Jonasson and Petri Purho, GDC Europe 2012, Independent Games Summit) took a dull Breakout clone and made it more satisfying live on stage with tweening, particles and similar effects. The source code was included. — [GDC Vault](https://gdcvault.com/play/1016487/Juice-It-or-Lose)
- **Roblox easing styles** available to TweenInfo: Linear, Sine, Back, Quad, Quart, Quint, Bounce, Elastic, Exponential, Circular, Cubic. — [Creator Docs: EasingStyle](https://create.roblox.com/docs/reference/engine/enums/EasingStyle)
- **spr (Fraktality, MIT)** animates Instance properties with a physical spring: `spr.target(obj, dampingRatio, frequency, {props})`. A damping ratio below 1 overshoots and wobbles, exactly 1 settles with no overshoot (the "most visually neutral"), and above 1 settles slowly. Higher frequency is faster. It supports CFrame, Vector3, number, Color3, UDim2 and more. Examples from the docs: `(1, 1)` for a slow, clean move and `(0.6, 4)` for a quick, bouncy move. — [spr GitHub](https://github.com/Fraktality/spr); [DevForum thread](https://devforum.roblox.com/t/spring-driven-motion-spr/714728)

### Inferences
Suggested cannon timeline at 60 fps (1 frame ≈ 16.7 ms). Barrel length is L.

| Phase | Time | Motion | Easing / tool |
|---|---|---|---|
| A. Charge / anticipation | 0.25–0.45 s (15–27 f); scale with charge if there is a power meter | Barrel tips UP 4–8° (or toward the aim), body squashes to X/Z 1.08–1.12, Y 0.88–0.92 (volume kept) and creeps back 0.1–0.2 studs. A small tremble in the last 0.1 s (±0.5°, 20–30 Hz) reads as "about to blow". | Tween, Quad or Sine InOut |
| B. Fire (release) | 1–2 frames (≈0.03 s) | Snap to stretch along the barrel: length 1.15–1.25, cross-section 0.9. | Instant set or Exponential Out; no slow-in at release |
| C. Recoil kick | 0.05–0.08 s | Whole barrel slides BACK 0.3–0.6 × barrel radius (≈0.15–0.25 L) and pitches up an extra 6–12°. | Exponential or Quint Out (fast) |
| D. Recovery | 0.25–0.45 s | Barrel returns to rest and overshoots forward slightly (5–10 % of the kick), then settles. | Back Out, or spr damping 0.4–0.55, frequency 4–6 |
| E. Base / wheel wobble (overlap) | starts 1–2 frames after C, lasts 0.4–0.6 s | Carriage rocks back 2–4° about the rear wheel axle, then rocks forward. Wheels roll back a few degrees. Scale returns from stretch to 1.0 with a single overshoot (0.97). | spr damping 0.3–0.5, frequency 3–5, or Elastic Out at a small amplitude |
| F. Idle settle | after about 0.6 s | Optional 1 % breathing scale loop so the cannon never looks frozen. | Sine InOut, 1.5–2 s period |

- **Contrast is what sells it.** A slow charge (A) against an almost instant fire (B and C) is what creates "punch". A cheap launch usually tweens everything at one even speed (for example 0.3 s Linear for everything).
- **Ease choices.** Use Exponential or Quint Out for the kick: most of the movement in the first frame. Use Back Out or an underdamped spring for the return (overshoot). Never use Linear for recoil.

### Gaps
- No source found that gives measured cannon recoil distances or frame counts from a shipped Roblox launch game. The table values are inferences.
- Steve Swink's *Game Feel* book was not consulted directly (no accessible text in this session).

---

## 2. Muzzle effects (flash, smoke puff and ring, sparks, light): layering and timing

### Takeaway
Layer from fastest to slowest: flash and light (1–3 frames), then sparks (0.15–0.4 s), then a smoke ring or puff (0.5–1.2 s). Keep the full-screen flash out entirely, or at most one per second (kid-safe rule). The main flash should be a local billboard or particle at the muzzle, not a screen-wide white.

### Cited Findings
- A Vlambeer talk ("The Art of Screenshake", Jan Willem Nijman) showed about 30 small tweaks that make shooting feel better. The write-up names only "shake the screen slightly in the opposite direction of the gunfire" and a 33 % chance of harmless enemy death explosions; the full list is in the roughly 45-minute talk. — [Game Developer](https://gamedeveloper.com/design/vlambeer-co-founder-shares-advice-on-building-better-action-games)
- The project's own sector brief and playbooks already define the VFX moments and flash limits for this repo. See `Build Playbooks/11 VFX Moments Playbook.md` and `Build Playbooks/Sector Briefs/Brief - VFX, Animation, Audio and Game Feel.md` (local repo, not web).

### Inferences
Muzzle layering at fire time t = 0:
1. **Flash** (t = 0 to 0.05 s): a ParticleEmitter Burst of 1–2 big, bright, star-shaped particles at the muzzle. Size 3–5 × bore, Lifetime 0.05–0.08, LightEmission 1, Size curve shrinking to 0. Also a PointLight at the muzzle: Brightness 4–8, Range 12–20, tweened to 0 over 0.08–0.12 s (Quad Out).
2. **Sparks** (t = 0 to 0.4 s): Burst of 12–25 small particles. Speed 20–40, Spread 25–35°, Lifetime 0.2–0.4, Drag 3–5 so they stop quickly, Acceleration downward.
3. **Smoke ring / shockwave** (t = 0.02 to 0.5 s): a flat ring mesh or a ring texture facing the barrel axis. Scale from 0.5× to 3× bore with Exponential Out over 0.3–0.4 s, while transparency goes 0 → 1.
4. **Smoke puff** (t = 0.03 to 1.2 s): Burst of 6–10 soft cartoon puffs. Speed 4–10 along the barrel, Drag 2–4, Size 2 → 5 grow curve, Lifetime 0.8–1.2, RotSpeed ±60.
5. **Barrel tip glow:** a Neon tip whose colour tweens from hot orange back to normal over 0.6–1.0 s.
- **Flash rule:** the screen flash, if any, should be a ≤ 0.1 s, ≤ 30 % opacity tint at most once per second, behind a setting toggle. This follows the repo's ≤ 1 flash per second rule.
- **Built-in pictures only:** use Roblox's built-in particle and texture assets, per the repo's VFX rules (`VFX-ITEMS.md`). Do not invent asset IDs.

### Gaps
- No primary source found with muzzle-flash frame counts for Roblox launch games. Values are inferences.

---

## 3. Projectile flight: stretch, trail, spin, speed lines, readability

### Takeaway
Keep the projectile readable: a bright, high-contrast core; a Trail tied to two attachments that fades over about 0.3–0.6 s; stretch along velocity scaled by speed; a visible spin; and a camera that keeps it in frame. Follow an arc (parabola). Launch and throw sims, such as +1 Stone Skipping, are built around watching the object travel while a distance counter climbs.

### Cited Findings
- **Thrown objects follow arcs** (a parabola). Faster motion flattens arcs. — [Twelve principles](https://cavac.at/cavacopedia/Twelve%20basic%20principles%20of%20animation)
- **Roblox Trail** properties include Lifetime, MinLength, MaxLength, WidthScale (NumberSequence), FaceCamera, LightEmission, Transparency (NumberSequence), Color (ColorSequence), Texture, TextureMode and TextureLength. A Trail draws between two attachments; the docs' sample places them 4 studs apart on opposite sides of a part. — [Creator Docs: Trail](https://create.roblox.com/docs/reference/engine/classes/Trail)
- **+1 Stone Skipping** (place 10765298801) is a popular "+1" throw sim with many code and guide pages. No source was found that breaks down its launch animation or camera. — [RoWatcher listing](https://rowatcher.com/games/10765298801/1-stone-skipping); [Dexerto codes page](https://www.dexerto.com/roblox/1-stone-skipping-codes-3416218/)

### Inferences
- **Stretch.** Each frame, set the visual mesh (not the physics part) to scale Z = 1 + clamp(speed/120, 0, 0.6) along the velocity direction and X/Y = 1/√Z (volume kept). Ease back to round at landing.
- **Spin.** 1–3 turns per second on the ball's visual. Players read the spin as speed.
- **Trail.**
  - Settings: Lifetime 0.3–0.6 s, FaceCamera = true, LightEmission 0.5–1, MinLength 0.1.
  - Width: attachments one ball-diameter apart, WidthScale 1 → 0.
  - Colour: Transparency 0.2 → 1, and the ColorSequence is the skin's accent colour (repo rule: tie the effect to the skin).
  - Add a second, thinner and brighter inner trail for a "comet" look.
- **Speed lines.**
  - Above a speed threshold, a ParticleEmitter attached to the camera (or the projectile) emits thin streaks in Velocity-Parallel orientation.
  - Settings: Lifetime 0.15–0.25 and Rate 30–60, fading out as the projectile slows.
  - Mobile: cap Rate and particle count (see Q7).
- **Readability.**
  - Bright outline: a Highlight with OutlineTransparency 0 and FillTransparency 1, used sparingly, as one Highlight per projectile at most.
  - A drop shadow or ground marker under the ball.
  - A distance number floating above it.
  - Keep the FOV wide during flight.
- **Player as the projectile.** A curled "cannonball" pose, a spin, and the same trail on both hands or the torso.

### Gaps
- No frame-by-frame breakdown of +1 Stone Skipping, or of any Roblox cannon or launch sim, was retrievable (the guide site failed to load). A video capture of the real game is needed to match it one-to-one, per the repo rule "the reference is the authority".
- Trail default values were not shown on the docs page fetched.

---

## 4. Camera: shake, FOV kick, chase cam, cut timing (Roblox implementation)

### Takeaway
- **Shake** with trauma: add trauma on fire and on impact, use shake = trauma², decay linearly at about 0.5–1.5 per second, and drive it with smooth noise rather than pure random.
- **FOV** jumps 8–15° wider on fire and eases back over the flight.
- **Chase cam:** a Scriptable camera updated in BindToRenderStep, lagging behind the projectile.
- **Settings:** shake must be toggleable (kid-safe; also accessibility).

### Cited Findings
- **Trauma-based shake** (from Squirrel Eiserloh's GDC 2016 talk "Math for Game Programmers: Juicing Your Cameras With Math"): shake intensity = trauma^2. The Bevy engine reference implementation uses max angle 10°, max offset 20 px, trauma decay 0.5/s (full trauma fades in 2 s), noise speed 20, exponent 2, and +0.4 trauma per event. — [Bevy example](https://bevy.org/examples/camera/2d-screen-shake/); [GDC Vault session](https://gdcvault.com/play/1023146/Math-for-Game-Programmers-Juicing)
- **Shake direction:** shake the screen slightly opposite the direction of fire (Vlambeer). — [Game Developer](https://gamedeveloper.com/design/vlambeer-co-founder-shares-advice-on-building-better-action-games)
- **EZ Camera Shake for Roblox (RbxCameraShaker, Sleitnick).**
  - Usage: `CameraShaker.new(Enum.RenderPriority.Camera.Value + 1, callback)`, then `:Shake(preset)` or `:ShakeOnce(magnitude, roughness, fadeIn, fadeOut, posInfluence, rotInfluence)`.
  - Preset values from the source code:
    - **Bump** = (2.5, 4, 0.1, 0.75), PositionInfluence 0.15, RotationInfluence (1, 1, 1).
    - **Explosion** = (5, 10, 0, 1.5), PositionInfluence 0.25, RotationInfluence (4, 1, 1).
    - **Vibration** = (0.4, 20, 2, 2).
    - **Earthquake** = (0.6, 3.5, 2, 10).
  - Links: [GitHub README](https://github.com/Sleitnick/RbxCameraShaker); [Presets source](https://raw.githubusercontent.com/Sleitnick/RbxCameraShaker/master/src/CameraShaker/CameraShakePresets.lua); [DevForum thread](https://devforum.roblox.com/t/ez-camera-shake-ported-to-roblox/98482/145)
- **Visual kick on Roblox:** forum advice is to tween the camera CFrame rotation slightly up, then back down, or to use EZ Camera Shake. — [DevForum: visual kick/recoil](https://devforum.roblox.com/t/how-would-i-add-visual-kickrecoil/3015445)
- **Chase cam:** set CameraType to Scriptable and update the camera CFrame each frame from the projectile (BindToRenderStep or RunService), then disconnect on hit. — [DevForum: bind camera to projectile](https://devforum.roblox.com/t/bind-camera-to-projectile/1861469)
- **Shake as a setting:** cozy or puzzle games should use minimal shake, heavy moments get more, and you should offer a slider plus an on/off toggle. — [DEV: The Art of Screen-shake](https://dev.to/dat_one_dev/the-art-of-screen-shake-33bi)
- **Hand-made shake:** a simple shake moves the camera through a few offsets over about 8 frames and back. Enforcing a minimum jump distance and shrinking the maximum distance over time makes it decay cleanly. — [Oregon State dev blog](https://blogs.oregonstate.edu/petekevi/?p=22)

### Inferences
Camera script at fire (t = 0), as a client LocalScript:
- **t = 0, shake.**
  - Add trauma 0.35–0.5 (or `ShakeOnce(2.5–3.5, 8–10, 0, 0.4–0.6)`), with rotation biased to pitch, kicking back opposite the shot.
  - For kids, keep it at or below Bump strength and decay within 0.5 s.
  - Multiply by a `ShakeEnabled` setting (0 when off).
- **t = 0, FOV kick.**
  - Camera.FieldOfView goes from 70 to 80–85 (+10 to +15) in 0.06–0.1 s, Quad or Exponential Out.
  - It then eases back to about 75 (+5) during flight over 0.6–1.0 s (Sine Out), and returns to 70 on landing over 0.4 s.
  - Roblox's default FOV is 70. That figure comes from general Roblox knowledge, not from a source fetched here.
- **t = 0.08–0.15 s, chase handoff.**
  - Switch to a Scriptable chase cam, bound with `RunService:BindToRenderStep("LaunchCam", Enum.RenderPriority.Camera.Value + 1, fn)`.
  - Target position = projectile position − velocity.Unit × 12–18 studs + up × 4–6 studs. Look at the projectile plus velocity × 0.2.
  - Smooth with alpha = 1 − exp(−k·dt), k = 6–10 (frame-rate independent), or with spr at damping 1, frequency 3–5.
  - Do not hard-lock the camera to the projectile: a little lag is what shows speed.
- **Cut timing.** Hold the cannon framing for 2–5 frames after fire, so the player sees the recoil and smoke, then follow. If there is a cinematic cut, cut on the fire frame, never in the middle of the anticipation.
- **Landing.** Shake again with trauma 0.3–0.6 by impact speed, FOV +4–6 pop back, then ease the camera back to the player (or hold on the landing spot for about 1 s while the distance number counts up).

### Gaps
- Nijman's talk is reported to include camera lerp toward the aim and "kick" values, but no accessible transcript with numbers was found.
- No measured FOV-kick values were found from shipped Roblox launch games.

---

## 5. Hit-stop / time freeze at fire or impact

### Takeaway
A hit-stop of about 0.05–0.1 s at a big moment adds weight. Roblox has no global time scale, so you fake it: pause the projectile's visual and particle timescale and hold the camera for those frames. Use it on the impact, and only on the fire frame for the biggest shots.

### Cited Findings
- **Example hit-stop:** 0.08 s at time scale 0.05 ("looks almost stopped"). The guidance:
  - don't use exactly 0, because code dividing by delta can break;
  - time the restore in real time;
  - give one owner control of the time scale;
  - handle back-to-back hits with a counter so an earlier timer doesn't end a later stop.
  - Source: [Uhiyama Lab: Godot hitstop](https://uhiyama-lab.com/en/notes/godot/hit-feedback-hitstop/)

### Inferences
- **Roblox version.**
  - Anchor or freeze the client-side visual ball for 3–6 frames (0.05–0.1 s) on impact.
  - Set `ParticleEmitter.TimeScale` to about 0.05 for nearby emitters, then restore.
  - Freeze the camera follow and play the impact sound at full speed.
  - Keep server physics untouched. Hit-stop is visual and client-only.
- **At fire.** A 2–3 frame (≈0.04 s) hold on the most stretched pose before the recoil feels like "the cannon strained", but make it optional and not every shot. Overuse feels laggy.
- **Scale by tier:** small shots 0, medium 0.04 s, big or record shots 0.08–0.12 s.

### Gaps
- No Roblox-specific source on hit-stop numbers was found. These values are inferences from the general source.

---

## 6. Landing / impact recipe

### Takeaway
Landing mirrors firing. Squash on contact, then a ground ring, dust puffs, a camera bump and a short hit-stop. Then a reward beat: distance number pop, then currency.

### Cited Findings
- **Squash on contact** with volume conserved, then recovery with overshoot (follow-through). — [Twelve principles](https://cavac.at/cavacopedia/Twelve%20basic%20principles%20of%20animation)
- **Trauma shake on impact,** scaled by event size. — [Bevy trauma example](https://bevy.org/examples/camera/2d-screen-shake/)
- **Spring settle:** underdamped springs give the "pop" settle. — [spr](https://github.com/Fraktality/spr)

### Inferences
Landing timeline at contact time t = 0:
- **t = 0:** hit-stop 0.05–0.1 s. The ball squashes to Y 0.6, X/Z 1.3.
- **t = 0.0–0.3 s:**
  - A ground shock ring scales from 0.5 to 4 × ball size (Exponential Out) and fades.
  - Dust puffs: 8–14 particles, low speed, Drag 3, Lifetime 0.6–1.0.
  - Optional debris chips.
- **t = 0.05–0.4 s:** the ball unsquashes with spr damping 0.35–0.5, frequency 5–7 (it bounces to Y 1.1 and settles). If it skips (stone-skip style), each skip gets a smaller squash and a smaller ring, plus a rising pitch "+1" sound.
- **t = 0.1–0.6 s:**
  - The distance number pops: scale 0 → 1.2 → 1.0 with Back Out over 0.35 s.
  - The number counts up with Quad Out over 0.5–1.0 s.
- **Camera:** trauma 0.3–0.5 and an FOV pop of +5, back over 0.3 s.

### Gaps
- No Roblox launch sim landing breakdown was found. Capture the reference game on video to calibrate.

---

## 7. Roblox implementation specifics and "cheap vs juicy"

### Takeaway
- **Model motion:** animate the cannon with TweenService or springs on a CFrameValue, then apply it with `Model:PivotTo()` each frame. A Model has no tweenable CFrame property.
- **Rigged cannon:** use Motor6D joints or Bones played by an AnimationController and Animator.
- **Where to run it:** do all juice on the client.
- **What makes it juicy:** contrast in timing, overshoot, layered effects, and camera response. Cheap launches lack these.

### Cited Findings
- **AnimationController** loads and plays animations on a model in place of a Humanoid. Its own `LoadAnimation` is marked deprecated on the reference page, which points to using an Animator child (`Animator:LoadAnimation`). — [Creator Docs: AnimationController](https://create.roblox.com/docs/reference/engine/classes/AnimationController)
- **spr** supports CFrame and Vector3 springs on Instances with a single call, which makes it suited to recoil and settle. It is MIT licensed. — [spr](https://github.com/Fraktality/spr)
- **Camera shaker render priority:** `Enum.RenderPriority.Camera.Value + 1`, so the shake applies after the default camera. — [RbxCameraShaker](https://github.com/Sleitnick/RbxCameraShaker)
- **Juice can be overdone.** GDC later hosted a counter-talk titled "Don't Juice It or Lose It". — [GDC Vault](https://gdcvault.com/play/1020861/Don-t-Juice-It-or)

### Inferences
- **Tween a Model.** Create a `CFrameValue`, tween its Value, and on `.Changed` call `model:PivotTo(base * value)`. The other option is to weld everything to the barrel's PrimaryPart and tween only that anchored part's CFrame. For a recoil that must overshoot, spr on a CFrameValue or a hand-rolled spring is cleaner than chaining tweens.
- **Rigged cannon.**
  - Build: Barrel, Carriage and Wheels joined by Motor6D, with AnimationController plus Animator.
  - Author a 0.8–1.0 s "Fire" animation in the Animation Editor using the phase table in Q1. Set the release key to Constant easing so it snaps.
  - IDs: do not invent animation IDs. Per repo rules, leave them at 0 and put them on the owner's checklist, or play the extracted KeyframeSequence with KeyframeSequenceProvider in Studio.
- **Client vs server.** The server decides the shot (power, landing distance). Every client plays the visuals locally from one RemoteEvent, so there is no stutter from replicated tweens.
- **Mobile performance.**
  - Keep total live particles per shot under about 100.
  - Use one PointLight per shot.
  - Use at most two Trails per projectile.
  - Pool and reuse the projectile and effect parts instead of creating them each shot.
  - Avoid a Highlight per particle. Roblox caps Highlights; the cap number was not verified here.
- **Cheap vs juicy checklist.**

| Cheap | Juicy |
|---|---|
| No anticipation | Squash and lift before the shot |
| Linear tweens | Out and Back eases or springs |
| Recoil the same speed both ways | Fast kick, slow springy return |
| Single particle effect | Flash, sparks, ring and puff layered over time |
| Fixed camera | Shake opposite the shot, FOV kick, lagging chase cam |
| Ball pops in at full speed with no trail | Stretch, spin and trail |
| Landing just stops | Squash, ring, dust, number pop |
| Silent or one sound | Boom, whoosh loop scaled by speed, and a landing thud |

- **Kid-safe guardrails.**
  - Shake has a toggle and is capped at about Bump strength by default.
  - No more than 1 full-screen flash per second, and better none, since the flash stays at the muzzle.
  - Hit-stop of 0.1 s or less.

### Gaps
- The Roblox Animator, Motor6D and PivotTo reference pages were not fetched in this session. The PivotTo and CFrameValue pattern is standard Roblox practice from the researcher's knowledge, not cited here.
- No source with concrete numbers was found from the "Juice it or Lose it" or "Art of Screenshake" talks; only their existence and headline ideas are confirmed. Steve Swink's *Game Feel* was not accessed.
