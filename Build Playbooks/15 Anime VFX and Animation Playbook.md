---
tags: [build-playbooks, vfx, animation, anime, aura, combat, impact-frames, hit-stop, kid-safe]
updated: 2026-10-31
---

# 15 Anime VFX and Animation Playbook

Back to [[00 Build Router]] · General layering, tiers, budgets: skill `roblox-vfx` · Game moments (launch, hatch, rebirth): [[11 VFX Moments Playbook]] · Animations: skill `roblox-ai-animation` · Premium layer: [[14 Premium Feel Playbook]] · Taste: [[09 Owner Taste Rules]] · Still looks cheap: [[16 Pro Animation and VFX Playbook]]

> **Oct 31 update:** step-by-step recipes for every moment in this note (catch-up hit-stop, impact order, cheap auras, slashes, dashes, ultimates) are in [[19 Animation and VFX Recipe Book]]. Where they differ, note 19 is newer.

**Goal (owner, Oct 31):** "anime style animations and VFX, like the anime games on Roblox do", "sort of Dragon Ball Z aura style". This note covers:
- how the popular Roblox anime games get that look (§1);
- where each piece already lives in the vault (§2);
- the recipes: the power-up aura (§3), hits (§4), beams and slashes (§5), attack timing (§6), ultimates (§7);
- the kid-safe rules (§8), the kit module and a minimal prompt (§9), and a checklist (§10).

**Our own look, never theirs.** Use the style and timing, never their textures, meshes, move names or character designs (a takedown risk, LihFolk case study of The Strongest Battlegrounds).

**Tags:** [W] from DevForum posts, open modules and fan sources; [V] from the vault's existing notes; [R] built and previewed here; [I] my read.

## 1. What makes Roblox anime games look "anime"
Battlegrounds games (The Strongest Battlegrounds, Jujutsu Shenanigans), anime fighting and RPG games (Blox Fruits, Type Soul) and anime tower-defence and RNG games all share these:

1. **Hard contrast, short holds.** Every big hit has a beat where the world goes black-and-white or inverted for 1–3 frames (the "impact frame"), then snaps back. [W]
2. **White-hot core, coloured body, dark accent.** Every effect frame has three tones: white (rims, cores), the element colour, and a dark ink or smear. [V LihFolk Slash Recipes]
3. **Snappy timing.** A long wind-up, then a 2–4 frame strike, a freeze on contact (hit-stop), and a held end pose. Motion is fast, then stops dead. [V]
4. **Shapes over particles.** Top games build most effects from **meshes** (rings, crescents, spikes, spheres) that tween size, transparency and colour, with particles on top. Particles alone look soft. [W DevForum "How do y'all make auras"]
5. **The ground reacts.** Rocks burst up in a ring (The Strongest Battlegrounds uses a rock module), dust rolls out, and a shockwave ring skims the floor. [W]
6. **The camera sells it.** Short shake on heavy hits, speed lines on dashes and charges, and a quick cut to a close angle for ultimates. Plain hits use no camera effects. [V]
7. **Auras are shapes that flicker,** not smoke: tall flame tongues inside a glowing egg-shaped envelope, sparks shooting up, electric crackle at high tiers. Many games swap between several aura meshes quickly; we use layered particles plus a soft envelope (§3). [W][R]

## 2. What the vault already has (use it, don't rebuild it)
| Need | Where |
|---|---|
| Layering, property cheat sheet, tier ladder, budgets, offline preview | skill `roblox-vfx` |
| **Slashes, thrusts, overhead cleaves, dash afterimages, hit sparks, charge-ups, explosions:** a working module with review scores | `LihFolk/skills/lihfolk-vfx` (`LihFolkVFX.luau`, `SlashSweep`, `CrescentDouble`, `DashTrail`, `HitSpark`, `ChargeUp`…); notes in `LihFolk/LihFolk Vault V2/07 Lighting VFX and Audio/` |
| Hit-stop and shake numbers by attack weight | `LihFolk Vault V2/47 Game Feel and Juice/Hit-Stop and Screen Shake Tuning by Numbers.md`; [[Brief - VFX, Animation, Audio and Game Feel]] |
| Beams, trails, elemental kits (fire, ice, earth, water, wind, lightning), projectiles | `07 Lighting VFX and Audio/Beams and Trails.md`, `Elemental VFX Kits…`, `Projectile VFX…` |
| Kid-friendly hit feedback (no gore) | `07 …/Gore Policy and Kid-Friendly Hit Feedback.md` |
| Animation craft (rigs, Moon Animator, procedural, markers) | `LihFolk Vault V2/08 Animation/`; skill `roblox-ai-animation` |
| Battlegrounds and anime game design | `32 Case Studies…/Case Study - The Strongest Battlegrounds.md`, `Case Study - Blox Fruits.md`, `10 Game Design and Genres/Genre Playbook - Combat and RPG.md` |
| **New here:** the power-up aura, impact frames, speed lines, craters, shockwaves, hit sizes | `new-game-kit/src/Shared/AnimeFX.luau` (§9) |

## 3. The power-up aura (Dragon Ball-style energy, our recipe) [R]
Preview: `new-game-kit/previews/anime-aura.png` (tiers 1.0, 0.6, 0.3, left to right; offline renderer, no bloom, so Studio looks brighter).

**Layers** (all on an invisible body-sized box welded to the HumanoidRootPart; `LockedToPart` so the aura stays on the body while you run):

| Layer | Job | Recipe (built-in textures) | From tier |
|---|---|---|---|
| Shell | The egg-shaped outline | glow.png, FacingCameraWorldUp, Squash 0.7 (taller), Size 6→7.5 (+2.5 by tier), Rate 8–16, Life 0.35–0.5, Transparency 0.6, ZOffset −1.2, additive | 0 |
| Flames | The flaring tongues | fire_main, FacingCameraWorldUp, up at 4–7 studs/s, Accel +18 up, Squash 0.5→1.1, Size 1.8→3→0.8 (+1.2 by tier), Rate 45–120, Life 0.45–0.7, colour white-hot → tier → 25% darker, ZOffset −0.6 | 0 |
| Core | White-hot tongues close to the body: reads as energy, not fire | fire_main, smaller and more see-through (0.45), white → pale tier colour, ZOffset +0.4 | 0.2 |
| Streaks | Speed and power: thin sparks shooting straight up | sparkles, VelocityParallel, Squash 2.5, 10–16 studs/s, Life 0.2–0.4, Brightness 2 | 0.4 |
| Ground | Weight: dust pushed out along the floor and a glow disc under the feet | smoke at the feet, Spread 85°, Drag 3; glow.png flat (VelocityPerpendicular), Size 5–6.5 | 0.5 |
| Crackle | Electric arcs round the body, ~4 a second | 2–3 scripted Beams, 6 segments, random curve, width 0.18→0.08, live 0.08 s | 0.75 |
| Outline | The body glows in the aura colour | one Highlight (fill 0.85, outline 0.35), **local player only** (Roblox now allows 255, but the first costs up to 1 ms on phones; keep one and toggle it) | 0.9 |
| Light | Colour spill on the floor | one PointLight, Brightness 0.8–2.2, Range 12, Shadows off | 0 |

**Tier ladder:** each step adds one channel (core, streaks, ground, crackle, outline) and grows the flames about 10–20%. That's the `roblox-vfx` rule: escalate by channel, not by count. Colour by tier or rarity, e.g. yellow, then blue, then violet. Avoid copying one show's exact colour sequence and names.

**Charge-up sequence (one press):**

| Time | Beat |
|---|---|
| 0–0.3 s | Anticipation: crouch pose, the flames pull in (Rate ×0.5), and motes converge (LihFolk `ChargeUp`) |
| 0.3 s | Burst: two ground rings 0.12 s apart (shockwave texture, Size 2→18, Life 0.45), dust `Emit(24)`, streaks `Emit(20)`, flames ×2.2 for 0.9 s, shake 0.35–0.7 |
| 0.3–0.7 s | Speed lines on screen, and rocks rise round the feet (`AnimeFX.Crater`) |
| 0.7 s on | The new tier settles. Optionally one impact frame (§4), only for a transformation |

**Budget:** about 60 live particles at tier 0.5 and about 110 at tier 1, so show only one tier-1 aura on screen at a time. Other players' auras run at half rate beyond 40 studs (skill §7).

## 4. Hits that feel anime [V][R]
| Size | Flash | Ring | Sparks | Hit-stop | Shake | Extra |
|---|---|---|---|---|---|---|
| Light (jabs, M1 1–3) | glow 2.5 studs, 0.1 s | 0.5→5 | 10 | 0.04 s | none | a star or cartoon spark, never blood |
| Heavy (M1 4, kicks) | 4 | 9 | 18 | 0.07 s | 0.5 for 0.25 s | knockback + dust |
| Finisher / ultimate | 6 | 14 | 28 | 0.1 s | 1 for 0.25 s | **impact frame** + crater + shockwave |

- **Impact frame** (kit: `AnimeFX.ImpactFrame`):
  - A `ColorCorrectionEffect` with Saturation −1, Contrast +2.5 and Brightness −0.05 for 0.07 s.
  - Open modules use Contrast ±25000 for pure black or white and recolour every part to Neon. That's a full-screen flash, too harsh for our players.
  - Ours is a hard grey beat, **at most one a second**, skipped when the player's Flashes setting is off.
- **Hit-stop** (kit: `AnimeFX.HitStop`): `track:AdjustSpeed(0)` on the attacker's track for 0.04–0.1 s, then restore. Cap it at about 140 ms of hit-stop per 0.6 s, or combat feels sticky (LihFolk numbers).
- **Shake** (kit: `AnimeFX.Shake`): random offsets that fade out, bound after the camera's render step. Skipped when ScreenShake is off. Visible shake under 10% of combat time.
- **Craters** (kit: `AnimeFX.Crater`):
  - 6–14 rocks in a ring, coloured from the floor under the hit (a raycast), tilted outward.
  - They pop up in 0.12 s with Back easing and sink away after 2.5 s.
  - Use plain parts, so there are no assets to upload.
- **Shockwave** (kit: `AnimeFX.Shockwave`): a flat ring (VelocityPerpendicular) at about 2× the radius over 0.5 s, plus a dust ring.

## 5. Beams, slashes and dashes
- **Slashes, dashes, thrusts:** start from the `LihFolkVFX` presets, but they are **not plug-and-play**: they need textures and meshes from a LihFolk asset pack that isn't in this repo, and most are unreviewed drafts (note 19, Part 4). Rebuild them with our own textures (`new-game-kit/tools/vfx/make_textures.py`) and the slash recipe (note 19, R8). They follow the frontal rule (arcs only in front of the character) and the three-tone rule, and the vault holds their review scores.
- **Energy beam (charged blast):**
  1. **Charge orb:** a glow core at the hands growing over 0.6 s, with motes pulled in (LihFolk `ChargeUp`).
  2. **Fire:** a Beam from the hands to the hit point, FaceCamera, Width 1→4 over 0.15 s, LightEmission 1, TextureSpeed 2–4 with a scrolling streak texture.
  3. **Pulse:** a second, wider and fainter Beam whose width pulses ±10% every 0.1 s.
  4. **Muzzle:** a ring plus sparks at the hands.
  5. **End:** the §4 Finisher at the far end.
  6. **Fade:** Width → 0 over 0.25 s. Total length 1–2 s.
- **Dash:** use LihFolk `DashTrail` (afterimages, streaks, launch ring) plus `AnimeFX.SpeedLines(0.3)` for the local player only.

## 6. Snappy anime attack timing (30 fps frames) [V][I]
| Move | Wind-up | Strike | Hold on contact | Recovery | Notes |
|---|---|---|---|---|---|
| M1 jab (1–3) | 2–3 f | 2 f | 1–2 f (hit-stop) | 4–6 f | about 0.35 s per hit; chain within 0.5 s |
| M1 finisher (4th) | 5–6 f | 3 f | 3 f | 8–10 f | knockback; then a 1 s combo cooldown |
| Heavy / special | 8–12 f | 3–4 f | 3 f | 10–14 f | anticipation pose readable from 30 studs |
| Dash | 1 f | 4–6 f | none | 3 f | invulnerable frames only if the game is PvP |
| Ultimate | 15–30 f (charge, can't be cancelled) | 6–10 f | 4–6 f | 15 f | camera cut (§7) |

Rules:
- **Pose to pose with holds.** Ease out fast (Quint or Exponential), hold the extreme for 2–4 frames, and never ease in to a hit.
- **Smear on the strike frame:** a stretched limb, or a slash ribbon from LihFolk, so a 2-frame move still reads.
- **Fire effects on animation event markers** at the contact frame (`GetMarkerReachedSignal("Hit")`), never on a timer. Skill `roblox-ai-animation` §4.
- **The server decides hits** with reach and rate checks; the client plays effects at once, for feel, then trusts the server's answer ([[Brief - VFX, Animation, Audio and Game Feel]]).
- **Make animations** with the AI animation workflow (skill `roblox-ai-animation`, a reference video in, keyframes out) or Moon Animator. The owner's files are raw KeyframeSequences (repo `CLAUDE.md`).

## 7. Ultimates and transformations (the clip moment)
Every anime game's best moment is the ultimate: it makes the clip kids post. Keep it **under 3 s**, skippable after the first time, and seen only by the player using it and anyone close by.

1. **Camera cut** to a low three-quarter angle on the user: 0.4 s, FOV 70 → 55.
2. **Letterbox bars** slide in (black frames, 8% of the screen height, 0.15 s).
3. **Name card:** the move's name slams in (scale 1.6 → 1, 0.2 s), with a coloured slash behind it.
4. **Charge** (§3 sequence), then **release:** the effect, one impact frame and the Finisher hit.
5. **Cut back** to the normal camera. Bars out in 0.15 s.

The ultimate meter fills from fighting, never on a plain timer (LihFolk case study: "ultimates earned in fight").

## 8. Kid-safe rules for anime effects (repo `CLAUDE.md` wins over any reference)
- **At most 1 flash per second.** Impact frames only on finishers and ultimates, skipped when Flashes is off, never full white.
- **Shake off switch** (ScreenShake), and no shake on light hits.
- **No blood, wounds or gore.** Hits are sparks, stars, rings and dust; knockouts are a cartoon spin and "K.O." (LihFolk Gore Policy note).
- **No copied anime IP:** our own move names, colours and silhouettes.
- **Phones:** stay within the particle budget; one big aura on screen; craters at most 14 rocks, cleaned up in 3.6 s.

## 9. Kit module and minimal prompt
`new-game-kit/src/Shared/AnimeFX.luau` (ReplicatedStorage/Kit/AnimeFX), client-side:
```lua
local AnimeFX = require(ReplicatedStorage.Kit.AnimeFX)
local aura = AnimeFX.Aura(player.Character, { color = Color3.fromRGB(255, 210, 60), tier = 0.6 })
aura:Charge()                                  -- §3 burst
AnimeFX.Hit(targetRoot.Position, nil, "Heavy") -- §4
AnimeFX.Crater(hitPos, 6); AnimeFX.ImpactFrame(); AnimeFX.SpeedLines(0.3)
AnimeFX.HitStop(attackTrack, 0.07)
```
**Status:**
- The aura is previewed offline. The arcs, shake, speed lines, hit-stop and impact frame are scripted and haven't run in Studio yet.
- At tier 1 the flames wash the head out a little in the preview. Check it in Studio first and lower the Core layer if it looks the same.

**Minimal prompt:**
> Add anime-style effects to **<game>** with `15 Anime VFX and Animation Playbook`: a power-up aura (§3) on **<when: rebirth / a pass / an equipped item>** in colours **<list>**, hits (§4) on **<attacks>**, and **<an ultimate (§7) / none>**. Use `AnimeFX` and `LihFolkVFX`, built-in textures only, and the kid-safe rules in §8. Show me one 30 fps clip next to the reference: **<video>**.

## 10. Checklist
- [ ] Three tones in every effect frame (white core, colour body, dark accent)
- [ ] Wind-up → 2–4 frame strike → hit-stop → held pose; effects fire on animation markers
- [ ] Hit sizes from the §4 table; impact frames only on finishers, ≤ 1 a second, Flashes setting honoured
- [ ] Aura: shell, flames and light at the base tier, plus one new channel per tier; only the local player gets the Highlight
- [ ] Ultimate ≤ 3 s, skippable, earned in play
- [ ] No gore, no copied IP; shake has an off switch
- [ ] Particle budget checked; a 30 fps clip next to the reference, judged by a fresh critic

## Sources
- [Open-source impact frame module](https://devforum.roblox.com/t/open-source-impactframe-module/2963136): ColorCorrection Saturation −1, Contrast ±25000, Neon recolour, 0.1 s.
- [Advanced impact frames](https://devforum.roblox.com/t/advanced-impact-frames/2468478), [negative colour effect](https://devforum.roblox.com/t/how-to-create-this-negative-color-effect/3963695).
- [How do y'all make auras](https://devforum.roblox.com/t/how-do-yall-make-auras/1383893): mesh swapping and animated mesh properties.
- [Crater and rock effect](https://devforum.roblox.com/t/how-do-i-create-this-craterrock-effect/2796810): a rock module in The Strongest Battlegrounds style.
- Vault: LihFolk Slash VFX Recipes, Hit-Stop and Screen Shake Tuning by Numbers, Gore Policy, Case Study - The Strongest Battlegrounds; `research_notes/Cartoony Roblox building UI and animation/animation_and_vfx.md` §3.
