---
tags: [build-playbooks, vfx, animation, timing, flipbooks, cannon, camera, kid-safe]
updated: 2026-10-31
---

# 16 Pro Animation and VFX Playbook

Back to [[00 Build Router]] · Anime auras and hits: [[15 Anime VFX and Animation Playbook]] · Moments: [[11 VFX Moments Playbook]] · Taste: [[09 Owner Taste Rules]]

Use this when an animation or effect "isn't good". It tells you what to fix first and gives the numbers.
Full research with sources: `reports/Pro Roblox animation and VFX.md` (Oct 31, 2026). Notes behind it are in
`research_notes/Pro Roblox animation and VFX/`. Anime auras, hit sizes and the `AnimeFX` module are in note 15.

**Honest limit:** no hit game publishes its settings. Every number marked (s) is a suggested starting value.
To match a game one-to-one, record it at 30 fps and step through it frame by frame (CLAUDE.md rule 2).

## 1. Fix in this order: timing, then shape, then colour
1. **Timing.** The main hit lands in the **first 25% of the effect's life**, then fades slowly. Never use a linear fade.
   Hits use `Emit()`, not Rate. Burst lifetime is 0.15–0.4 s (s). A whole hit lasts 1 s or less.
2. **Shape.** Make it big and simple, with thick and thin lines. Use our own painted flipbooks and meshes, not the default sparkle.
3. **Colour.** Use one accent (the skin's colour) and its neighbours. Make the core small and bright, the middle saturated and the rim darker. Check it in greyscale.

## 2. Cheap tells and their fixes
| Looks cheap because | Fix |
|---|---|
| One long, even fade | Burst early, then ease out (Quad/Expo Out). Use a Size curve that pops, then shrinks |
| Every particle the same | Rotation (−180, 180), a RotSpeed range, a Lifetime range, a Size envelope, `FlipbookStartRandom` |
| White fog in daylight | Make only the small hot core additive (LightEmission 1). Body and smoke get 0–0.3 |
| Dark smoke vanishes | Dark layers always get LightEmission 0 |
| No weight | Fast debris flying out, plus a ground dust ring that lingers 0.5–1.5 s |
| Effect drifts off the move | Fire it from an animation marker on the contact frame, never from a timer after `Play()` |
| Loop pops | Use a seamless sheet on Loop. The first key is copied as the last key |
| Robot animation | No Linear keys. Use CubicV2, never the old Cubic (it ran backwards in game) |
| "Twinning" | Offset head, arms and torso by 1–3 frames. Holds drift a little over 2–6 frames instead of freezing |
| Attack looks limp | Set the priority to Action. For moves made while walking, ship an upper-body-only copy |

## 3. Pipeline (how the pros build it)
- **Flipbooks:** square sheets of at most 1024 px. Use Grid4x4 (16 frames of 256 px) with a 4–8 px margin in each cell. The cap is 30 fps.
  - Bursts use OneShot with a 0.3–0.6 s lifetime.
  - Claude draws the frames by script and packs them. The owner uploads the PNG and sends back the ID (never invent one).
- **Meshes (Blender):** crescent, flat ring, open dome, helix ribbon, spike cone and sphere, each UV'd as one straight strip.
  - Put the picture on `Texture` objects so it can scroll (`OffsetStudsU/V`) and fade.
  - Shells use the ForceField material.
  - Timing (s): grow over 0.1–0.2 s with Expo Out, fade over 0.3–0.6 s with Quad In.
- **Beams:** stack 2–3 beams (dark edge, coloured body, white core) and scroll them with TextureSpeed.
- **Trails:** lifetime 0.15–0.3 s, width tapering to 0.
- **Layers as data:** copy the VFX Forge idea of `EmitDelay`, `EmitCount` and `EmitDuration` attributes on each emitter. One call then fires the whole timeline, and the owner can tune it in Properties.
- **Networking:** the server checks the move. Every client plays the animation and fires effects from its markers. Replicate effects, never hitboxes. Rate-limit the effect remote.
- **Limits:** a Lifetime cap of 20 s; Rate up to 400/s (100 on mobile). Keep to **about 100 live particles per shot** on phones, one PointLight and at most two Trails.

## 4. Cannon shot recipe (s)

> **Update Oct 31 (note 17 §1):** the measured reference has no shake, zoom, squash or hit-stop on a normal throw. Use this recipe's loud parts for rare tiers only, and keep the charge at 0.25–0.3 s. The kit's `LaunchFX` does this by tier.
| Phase | Time | Motion | Easing |
|---|---|---|---|
| Charge | 0.25–0.45 s | Barrel tips up 4–8°, body squashes (1.1 wide, 0.9 tall), creeps back 0.1–0.2 studs, trembles ±0.5° at the end | Sine InOut |
| Release | 1–2 frames | Barrel stretches to 1.2 long, 0.9 wide | Set instantly |
| Recoil | 0.05–0.08 s | Slides back 0.15–0.25 of the barrel length and pitches up 6–12° | Expo Out |
| Return | 0.25–0.45 s | Overshoots forward 5–10%, then settles | `spr` (0.5, 5) or Back Out |
| Wobble | 0.4–0.6 s | Rocks 2–4° on the rear axle | `spr` (0.4, 4) |
| Idle | 1.5–2 s loop | 1% breathing | Sine InOut |

A Model can't be tweened: tween a `CFrameValue` and call `PivotTo` on each change.

**Muzzle, fastest first:**
1. Flash: 1–2 star particles for 0.05–0.08 s, plus a PointLight (4–8 brightness, 12–20 range) fading over 0.1 s.
2. 12–25 sparks: Speed 20–40, Drag 3–5, 0.2–0.4 s.
3. A ring growing from 0.5× to 3× the bore with Expo Out over 0.35 s.
4. 6–10 soft puffs growing from 2 to 5 over about 1 s.
5. The barrel tip glows and cools over about 0.8 s.

**Flight:**
- Stretch the look mesh (never the physics part) to Z = 1 + clamp(speed/120, 0, 0.6), with X and Y set to 1/√Z.
- Spin it 1–3 turns per second.
- Add an accent-coloured trail tapering over 0.3–0.6 s, plus a thinner, brighter inner trail.
- Add speed lines above a set speed, a drop shadow and the distance number.

**Camera:**
- FOV goes from 70 to 80–85 in 0.08 s, eases to 75 in flight and returns to 70 at landing.
- Hold on the cannon for 2–5 frames, then chase from 12–18 studs behind and 4–6 up, smoothed by `1 − exp(−8·dt)`.
- Shake = trauma² (+0.4 at the shot, decaying 0.5/s), pushed opposite to the shot. It is never stronger than EZ Camera Shake's Bump (2.5, 4, 0.1, 0.75) and always follows `Setting_ScreenShake`.

**Landing mirrors launch:**
- The ball squashes to 0.6 tall and 1.3 wide, then springs back with `spr` (0.4, 6).
- A ground ring grows from 0.5× to 4×, and 8–14 dust puffs rise.
- Hit-stop by tier: none for small shots, 0.04 s for medium, 0.08–0.12 s for records. It is client-only: freeze the ball and slow nearby emitters' TimeScale to 0.05, but never to 0.
- The number pops 0 → 1.2 → 1.0 (Back Out, 0.35 s) and counts up with Quad Out. Each skip gets a smaller squash and a higher "+1" pitch.

## 5. Character animation workflow (Oct 2026)
- Studio has **no text-to-animation**.
  - Animation Capture turns a video under 15 s into R15 keys, on R15 only.
  - Mocap is floaty: always re-time it.
- Steps:
  1. Record a 5–15 s reference video.
  2. Capture it, or animate it in Moon Animator 2.
  3. Cut it down to 4–8 key poses and push each one past real life.
  4. Re-time it to the frame chart in note 15 §6.
  5. Add `Hit`, `TrailOn` and `TrailOff` markers.
  6. Publish. The owner uploads it, and we never invent the ID.
- Hit-stop lives in code, never in the clip: 30–60 ms for light hits, 80–150 ms for heavy ones, on confirmed hits only.
- A blade swing is too fast to see, so show it with a trail or smear mesh between the markers.
- Use R15 for kid games on standard avatars. Get R6's boldness with big torso leans and twists.
- Blender FBX export settings: Add Leaf Bones off, FBX Unit Scale, Simplify 0.

## 6. Kid-safe caps
- At most one screen flash per second, behind `Setting_Flashes`. Prefer a local flash at the hit point.
- Any screen tint lasts 0.1 s or less at 30% opacity or less.
- Shake has an on/off toggle and stays at Bump or below.
- Calm loops (auras, pets, rewards) pulse slower than once per second.

## 7. Checklist before showing the owner
- [ ] Peak inside the first 25% of each effect's life; no linear fades.
- [ ] Every particle randomised; smoke and dark layers at LightEmission 0.
- [ ] Effects fire on markers.
- [ ] Charge is slow, release takes 1–2 frames, and the return springs.
- [ ] Under 100 particles per shot.
- [ ] A 30 fps side-by-side with the reference, judged by a fresh critic.
