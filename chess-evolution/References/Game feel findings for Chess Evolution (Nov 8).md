---
tags: [chess-evolution, game-feel, juice, ui, camera, vfx]
updated: 2026-11-08
---

# Game feel findings for Chess Evolution (Nov 8)

What the vault says that makes the game feel like the reference ([[00 Reference index (Nov 8)]]). Sources: the Build Playbooks (on git branch `origin/claude/vault-all-notes`, not in the working folder: `git show "origin/claude/vault-all-notes:Build Playbooks/<note>.md"`), and the LihFolk Vault V2 notes in `LihFolk Vault V2 (imported)/`. Items already used on Nov 7 are in `chess-evolution/docs/Vault - what we used.md` and are not repeated.

## Tap pop-ups (the biggest gap against the reference)
- Reference: one "+N" per tap, random spot around the avatar, full size at once, drift up, shrink and fade in about 0.6–0.8 s, never merged ([[Ref - Subscribers pop-up on tap]]).
- 11 VFX Moments §4: pooled BillboardGui, AlwaysOnTop, rise 2 studs over 0.5 s with Back, fade 0.3 s, colour by currency, random x offset ±1.5. Widen the offset to the whole body (±2 x, 0–5 y) to match the reference.
- 17 Do It Like the Hits: BillboardGuis are costly, so pool the pop-ups. Damage Numbers note: pooled, capped, client only, with an All / Mine only / Off setting.
- 14 Premium Feel: the counter pill bumps 1.12 → 1 (0.2 s Back) on each gain; the counter rolls a NumberValue over 0.35–0.6 s.
- Cap about 12 live pop-ups for your own character and 3 for other players.

## Auto-run on the treadmill
- Reference: standing on the deck trains by itself about 4 times a second, with a running cycle and pop-ups ([[Ref - Auto-run on treadmills]]).
- Blueprint - Plus One Evolution §4 and 06 Polish: something should go up every 1–2 s while grinding; 14 Premium Feel rule 2 "something every second".
- Master prompt §6: the belt has states (idle, training, streak, cooldown), ramps in over 200–350 ms, stays moving between ticks and eases to a stop when you step off.

## Win reward, Evolve and rebirth moments
- 06 Polish juice sizes: XS tap = squash 0.9 then Back spring (0.12 s), soft click, no particles. S = +number rising, Back 0.5 s, 4–8 particles. L (rebirth/evolve/new best) = dim the screen 40 %, rotating sunburst, big text with Back, confetti, one white flash (at most one a second), sting ≤ 0.8 s.
- 11 VFX §6 level up: a ground ring under the feet (Size 2 → 10, 0.4–0.5 s, white to tier colour), a "Level Up!" text pop and a sparkle column Emit(16). No screen effect. This matches the "Level 10! Ready To Rebirth" burst in the long recording.
- Reference win: a burst of trophy icons flies out around the avatar to the Wins counter. 17 Do It Like the Hits: "+N" above the head at once, held 0.8 s, faded in 0.1 s, with 5–8 small icons floating up.
- Evolve (Promote): a new form pops in 0.2 → 1.1 → 1 (0.35 s Back) with rays behind it, only after the server confirms (11 VFX §5 hatch recipe adapted; master prompt §4).

## Glass smash at the gate
- Destruction and Fracture note: cosmetic breaks are client-only. Swap the pane, spawn about 8 pooled shards, ApplyImpulse, put them in a Debris collision group that ignores characters, fade within 3 s.
- Master prompt §7: wind-up → rival launch along the gate normal → impact → glass break → opening cue. Tie the shards and sound to the impact, not to the result packet. Reuse the local `GlassSmash` script.
- The clip itself is still missing ([[Ref - Clips zip (pending)]]).

## Camera
- 28 Camera Playbook: one script owns Camera.CFrame and FOV; others add named kicks. Always save and restore CameraType, CameraSubject, FOV and the UI, including on death and leave.
- No shake or zoom on repeated taps (06 rule 4, 14 rule 6, 09 Owner Taste). Shake only for L/XL moments, with a Screen Shake toggle; Reduced Motion halves FOV moves and removes shake.
- Duel camera (master prompt §5): blend in 250–420 ms to a low side or three-quarter view, give control back 250–450 ms after the win beat. The long recording's duel camera sits low behind the player with both on their plates.
- Rare/big moment camera: hold still at least 0.4 s before handing back (28 §cutscene "Calm").

## UI motion
- 14 Premium Feel §4: press 0.9 in 0.03–0.08 s, back in 0.28 s Back; hover 1.05–1.07 in 0.3 s; pop-in 0.6 → 1 in 0.25 s Back, staggered 0.06 s; panel open 0.85 → 1 with fade in 0.2–0.25 s Back, close in 0.14 s Quad In.
- 17: springs for anything that can be interrupted (UI pops), tweens for fixed one-shots, all cosmetic motion on the client.
- 09 Owner Taste: small buttons, no emoji, no red error box, see-through panels, smooth ASMR sounds of 0.1–0.3 s, rewards done by 0.6–0.8 s.

## Sound
- 06 and 29: pitch rises one semitone per tap, capped (+7 to +12), at most 8 ticks a second.
- 17: duck the music 3–6 dB for a sting by tweening the Music SoundGroup.
