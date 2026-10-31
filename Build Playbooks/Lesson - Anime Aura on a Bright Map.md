---
tags: [build-playbooks, lesson, vfx, anime, aura, cannon-evolution]
updated: 2026-10-31
---

# Lesson - Anime Aura on a Bright Map

Back to [[00 Build Router]] · Recipes: [[15 Anime VFX and Animation Playbook]] · [[11 VFX Moments Playbook]] · Taste: [[09 Owner Taste Rules]]

From +1 Cannon Evolution (Oct 31): Alex asked for "crazy cannon shots" with a Dragon Ball-style power-up aura. Code: `cannon-evolution/src/client/GameClient/AnimeFX.lua`. Pictures: `cannon-evolution/previews/anime-aura-training.jpg`, `anime-comet-ball.jpg`.

## What went wrong first
- **The built-in `fire_main.dds` is a dim, smoky blot.** As additive flames on the sunny, saturated Cannon map the aura was **invisible** in Studio (60–90 particles a second, and nothing on screen).
- **The built-in `glow.png` is a sparkle star on a black square.** It only works additive (LightEmission 1). With LightEmission 0 it draws a black box.
- Pale, additive colours (white → light blue) wash out over sand and water. Check every effect **on the real map in Studio**, not in the offline renderer, before tuning numbers.

## What works (shapes over particles)
| Layer | Build |
|---|---|
| Flame tongues | Neon parts with a Sphere `SpecialMesh`, spawned round the body (radius 1.4–2), stretched to 3.5–6 studs tall while they rise, fading late (Transparency tween `In`). 16–55 a second by power. Every third one is a white-hot core closer in |
| Shell | One ForceField-material ball, mesh scale (1, 1.45, 1), welded to the root, Transparency breathing 0.3–0.55. It shimmers on its own |
| Ground | A flat Neon disc under the feet (Transparency 0.6) plus smoke dust (LightEmission 0) |
| Streaks / crackle | `sparkles_main` VelocityParallel (additive is fine for sparks), and 4-segment Neon bolts that live 0.07 s |
| Ball in flight | A "comet head": 4–7 Neon spikes that follow the ball every frame, pointing back, flickering in length (sin at 26 rad/s), plus loose tongues peeling off |

**Saturated tier colours read best:** cyan (80, 200, 255), blue (40, 110, 255), violet (175, 80, 255), gold (255, 200, 40), pink (255, 50, 100) with rainbow tongues.

## Hooking in without clashing with other threads
- The effects module only **listens** (`TrainingState`, `TrainingShot`, `LaunchPlayer`) and finds the `Cannonball` on the next frame (`task.defer`). It never touches the launch timing, the camera code or the sounds, so the UI/sound thread's launch animation stays theirs.
- Shake and hit-stop bind at `RenderPriority.Camera + 1` and undo their own offset if nobody moved the camera, so they stack on the flight camera without drifting.
- Emitters live on **Attachments**: Effects' Low Graphics switch flips every emitter whose parent isn't an Attachment.

## Testing tips
- `screen_capture` can't follow a 4 s flight, and running `execute_luau` resets the camera type. To judge the ball: on the client, clone the ball and the live effect parts into an anchored snapshot folder, wait for the flight to end, bind a Scriptable camera at priority 2000 beside the snapshot, then capture.
- Each fresh play re-runs the intro cutscene, which owns the camera. Wait for it to finish before capturing.
