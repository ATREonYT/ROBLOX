---
tags: [build-playbooks, camera, cutscene, follow-camera, side-on, shake, fov, comfort, kit/CameraMath]
updated: 2026-11-01
---

# 28 Camera Playbook

Back to [[00 Build Router]] · Numbers: [[27 Studio Standard - One Sheet per Craft]] §3 · Rare-shot plans: [[25 Rare Shot Cameras and Using a VFX Pack]] §2 · Recipes: [[19 Animation and VFX Recipe Book]] R3, R13, R22 · Kit: `Shared/CameraMath.luau`

**Why a whole note.** The camera is the one effect that's on screen 100% of the time. A good effect with a bad camera looks cheap; a plain effect with a great camera looks expensive. The camera was also behind most of Alex's feedback on the rare shots (stuck behind crates, wrong angle, too short). This note covers every camera a kids' game needs and the rules that keep each one comfortable.

## 1. The five rules
1. **One owner.** One client script owns `Camera.CFrame` and `FieldOfView`. Every other system *asks* by adding a named kick or offset; nothing tweens the camera directly. Two scripts tweening FOV is the top cause of "the zoom gets stuck".
2. **Effects are added, then removed.** Shake and offsets are added after Roblox's camera runs (`RenderPriority.Camera + 1`) and removed before it runs next frame (`Camera − 1`). Then the camera can never drift.
3. **Smooth by half-life, not by `Lerp(x, 0.1)`.** A fixed lerp is twice as stiff at 120 fps as at 60. Use `CameraMath.Damp(halfLife, dt)`.
4. **Always give it back.** Every scripted camera saves CameraType, CameraSubject, FOV and the visible UI, and restores them on finish, on death, on leave and on error (a watchdog).
5. **Comfort first.** No fast spins, no roll on hits, shake scalable to zero, and Reduced Motion respected (`CameraMath.ShakeScale`).

## 2. Pick the camera for the game
| Camera | Use it for | Key numbers | Notes |
|---|---|---|---|
| **Default third person** | Walking, lobbies, RP towns, obbies | FOV 70; zoom 10–25 studs | Pick an occlusion mode per area: Zoom outdoors, Invisicam indoors (split huge walls into pieces first) |
| **Side-on flight** | +1 launch games (Alex's call for Cannon, note 09) | Distance = `CameraMath.SideOnDistance(height, fov)` for the height you want on screen; ball about ⅓ from the left, moving right and up | Lock the camera to one plane; follow X with a 0.1–0.15 s half-life, Y with 0.25 s, so the arc reads as an arc |
| **Chase (behind)** | Cars, boats, sliding, racing | Position half-life 0.08–0.15 s; yaw 0.15–0.3 s; pull back 1–3 studs and FOV 70 → 82 with speed (the +12° cap) | Follow **yaw only**, never the full roll and pitch of the vehicle |
| **Top-down / fixed** | Tycoon plots, tower defence, board-style minigames | Pitch 55–70°; FOV 40–55 for less distortion | Pan with a drag, zoom with a pinch, clamp both to the plot |
| **Scripted shot** | Reveals, rare shots, boss intros, a new zone | 1–4 shots per moment (§4) | Always through the cutscene recipe (R13) with Skip after 1 s if it's longer than 3 s |
| **First person** | Rare: horror-lite, cockpit views | FOV 70–80 | Kids get dizzy faster in first person; keep it optional |

## 3. Selling speed without shaking
Speed is felt through things rushing past (optic flow), not through the number on the HUD. Drive every cue from **one normalised speed `s` (0..1)**:
- **FOV:** base + up to +12° (`CameraMath.FovStack`), eased with `s²`.
- **Distance:** pull back 1–3 studs as `s` rises.
- **Speed lines:** only above `s = 0.6`, so they mean something. A ScreenGui with 10–20 thin frames radiating from the centre is cheaper than particles.
- **World cues:** ripples, posts and walls passing, wind sound. On the +1 lanes, the zone walls show only while you fly (note 09).
- **Shake: none during normal travel.** Only a short impulse on a crash or a rare landing.

## 4. Cutscene grammar (how to plan a scripted moment)
A big moment is a **sequence of shots**, like a film. Plan it as a table before writing code:

| Beat | Shot | Length | Why |
|---|---|---|---|
| 1. Tease | **Close-up** on the thing that's about to happen (the cannon's mouth, the egg) | 0.4–0.8 s | Tells the eye where to look |
| 2. Build | **Low hero angle** or a **slow orbit** | 0.6–2 s | Makes the subject feel big; the orbit shows its shape |
| 3. Hit | **Wide** at the moment of the hit, so the effect has room | 0.3–1 s | The biggest moment gets its own angle |
| 4. Follow | Back to the gameplay camera, or a push-in on the result | 0.5–2 s | Connects the moment to the reward |
| 5. Calm | Hold still for at least 0.4 s, then hand back | ≥ 0.4 s | The quiet ending sells the size (note 22) |

**Rules for the shots:**
- **Cut on the action** (the instant of the fire or the hit), not before it. A cut in the middle of nothing looks like a glitch.
- **Keep the subject on the same side of the screen across a cut** (if the cannon faces right in shot 1, it faces right in shot 2). Crossing sides confuses kids.
- **Orbits are slow:** at most a half circle over 2 s or more. Never spin.
- **Avoid walls on every shot:** spherecast (radius 0.5–1) from the subject to the planned camera spot; if it hits, move the camera in front of the hit. Move *in* instantly and *out* slowly (half-life 0.2–0.4 s).
- **Letterbox bars** at 8% height, sliding in over 0.25–0.35 s, in whole pixels (`CameraMath.Letterbox`).
- **Ladder by rarity:** Common 0 shots, Rare 0, Epic 1 (a zoom pulse only), Legendary 2, Mythic 3, Secret 2 long ones, Divine 3 with an orbit (note 25 §2).

## 5. Shake done right
- **Trauma model:** add trauma (0–1) on an event, shake by `trauma²`, decay 1.0–1.5 per second (`CameraMath.Trauma`). Stack small events, cap at 1.
- **Order:** kick on the hit frame; noise only after any hit-stop freeze ends (C5).
- **Size:** never above EZ Camera Shake's "Bump" (magnitude 2.5, roughness 4); translation and small pitch only, **no roll**.
- **Scale:** by the player's setting and by zoom, 0 with Reduced Motion (`CameraMath.ShakeScale`).
- **Where:** never on repeated actions (each normal shot, each coin). Only rare shots, landings of big tiers, explosions and boss slams.

## 6. Comfort and settings (kids' game minimum)
- **A Screen Shake toggle** (0 or 100% is enough; a slider is better) and **Reduced Motion** both halve FOV moves (`FovStack` with `reduced = true`) and remove shake (`ShakeScale`).
- **No head bob by default.** No camera roll during gameplay.
- **Skip** on every reveal longer than 3 s, after 1 s.
- Custom cameras read the player's Roblox mouse sensitivity and invert setting.
- Test at 30 fps and 120 fps, and on a low-end phone (smoothing must feel the same).

## 7. Worked example: the Mythic shot camera (3 shots, about 3 s)
1. **0.0–0.6 s, low hero shot.** Camera 3 studs above the ground, 10 studs in front-left of the player, looking up at the player and the cannon. Spherecast from the player to that spot; if a crate is in the way, slide the camera toward the player until it's clear.
2. **0.6–1.4 s, raised shot.** Cut on the charge peak to a spot 12 studs up and 18 studs back, with the player and cannon both in frame. The colour grading tweens to magenta over 0.3 s.
3. **1.4 s, over the cannon.** Cut on the fire to a spot just behind and above the barrel, looking down the river. FOV punch +8° over 0.12 s, then back over 0.55 s.
4. **1.6–2.6 s, follow.** Blend into the normal flight camera (side-on) over 0.4 s.
5. **Landing, then calm** for 0.4 s; restore the FOV, grading and UI; `RareReveal` gives the camera back.
**Test:** after 20 Mythic shots in a row, FOV is exactly 70, CameraType is Custom, and every UI that was on is on again.

## 8. Common mistakes
| Mistake | What you see | Fix |
|---|---|---|
| Two scripts set FOV | Zoom stuck after sprinting or a reveal | One owner, named kicks (`FovStack`) |
| Shake written into CFrame and never removed | The camera slowly turns | Add at Camera+1, remove at Camera−1 |
| `Lerp(x, 0.1)` every frame | Feels different on every device | `Damp(halfLife, dt)` |
| No restore on death | Camera stuck Scriptable after dying mid-cutscene | Hook Died and CharacterRemoving into the restore |
| Raycast instead of spherecast | The near plane slices through walls | Spherecast, radius 0.5–1 |
| Following the vehicle's roll | Car-sick camera | Yaw only |
| Shake on every coin | Tired eyes, kids leave | Shake only on rare moments |

## 9. Checklist
- [ ] One camera owner; every effect is a named kick or offset that ends at zero.
- [ ] The camera type fits the game (§2).
- [ ] Cutscenes planned as a shot table (§4); cuts on the action; no spins.
- [ ] Walls avoided on every shot (spherecast).
- [ ] Shake only on rare moments; settings and Reduced Motion respected.
- [ ] Every scripted camera restores on finish, death, leave and error.
- [ ] Tested at 30 and 120 fps and on a phone.
