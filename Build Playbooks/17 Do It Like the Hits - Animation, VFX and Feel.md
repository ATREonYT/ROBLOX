---
tags: [build-playbooks, vfx, animation, rare-reveal, cutscene, anime, sound, performance, discovery, kid-safe]
updated: 2026-10-31
---

# 17 Do It Like the Hits: Animation, VFX and Feel

Back to [[00 Build Router]] · Anime auras and hits: [[15 Anime VFX and Animation Playbook]] · Looks cheap: [[16 Pro Animation and VFX Playbook]] · Stone Skipping pacing: [[13 Beat Stone Skipping - Tutorial, Pacing and Feel]] · Taste: [[09 Owner Taste Rules]]

**Why this note exists.** On Oct 31 Alex asked us to "research everything possible about animations and VFX", "find out how to do everything like popular games", "study anime games especially", "study all of the videos" and "put it into the vault and remember it". This is the result. Read it before any animation, effect, reveal or cutscene job.

**Sources:**
- Full report: `reports/Roblox animation and VFX deep dive.md`.
- Notes behind it: `research_notes/Roblox animation and VFX deep dive/`:
  - the frame study of Alex's 5 videos, with timestamped sheets in `frames/`;
  - rare reveals;
  - textures;
  - code animation;
  - performance;
  - game teardowns;
  - anime games, parts 1 and 2;
  - everything else.

**How sure we are.** Only the frame study is measured. Hit games publish no settings, and their wikis would not load from the cloud. Numbers marked (s) are our suggestion, to be checked on a 30 fps capture.

## 1. The big lesson: quiet normal shots, loud rare shots
In Alex's +1 Stone Skipping videos, a normal throw has **no shake, no zoom punch, no squash, no hit-stop, no glow and no bloom**. It feels great through **timing, camera and the counter**. So:
- the normal shot copies the reference's timing exactly and stays clean;
- all the loud stuff (shake, freeze, cinematic, colour wash) is saved for rare shots, and each tier adds one new kind of layer.

**Measured timings to copy** (frame study §8; mechanics and timing only, never their art or names):

| Beat | Reference |
|---|---|
| Tap to ball out | **0.33 s** (charge 0.25–0.3 s, no hold-to-charge) |
| Launch button | Rises in 0.17 s (ease-out, no overshoot); drops in 0.1 s on tap; back 0.9 s after landing |
| Side menus | Slide off in 0.13 s at the shot, back in 0.2 s after the cut home |
| Sound at the shot | 0.1 s near-silence (music ducked), then the boom |
| Camera | Short hold on the shooter, then a 0.4–0.45 s swing into the side-on chase, no cut; locked to the ball's forward position |
| Skips | About every **0.55 s**. White splash crown of 3–5 blobs at 1.5–2× the ball's width, peaking on frame 3, gone by 0.2–0.3 s, plus one ripple ring 1× → 3× over 0.35 s |
| "+1" | Appears on the splash frame, lives 0.5 s; the counter ticks on the same frame with a rising pitch |
| Counter | Ticks every frame with no pop; eases over the last 0.8 s on short throws |
| End | Hold 0.5–0.6 s, hard cut home with counters already updated, second cut 0.5 s later |
| Reward | "+N" above the head instantly, held 0.8 s, faded in 0.1 s; 5–8 small icons float up |
| Whole loop | About **6 s** |
| Level-up | Bar jumps (no slow fill); about 30 confetti rectangles 0.1 s later, living 0.6–0.8 s |
| Rebirth | White fade 0.2 in, 0.4 hold, 0.1 out; title 0.5 → 1.05 → 1.0 in 0.33 s with slow rays |
| Panels | Blur in 1 frame; scale 0.1 → 1.0 in 0.13 s, overshoot to 1.1, settled by 0.35–0.4 s |

## 2. Rare shots: the reveal ladder (s)
Each tier keeps everything below it and adds one new kind of layer. The colour of the real tier shows from the **first frame**, so there is never an "almost got it" tease. Kit module: `RareReveal`.

| Tier | Length | Adds |
|---|---|---|
| Common | 0 s | Normal shot only |
| Rare | 0.6 s | Chime, an outline in the tier colour, and a small card with the real odds ("1 in N") |
| Epic | 1.2 s | First zoom pulse, plus a small shake at the shot only |
| Legendary | 2 s | Personal colour wash (on the camera, not Lighting), 0.1 s freeze, camera push-in, one burst, server chat line |
| Mythic | 3 s | Black bars, camera orbit, sky tint, an aura that stays 60 s |
| Secret | 4.5 s | Its own music sting, sky swap, Skip button after 1 s, a server banner other players can mute |

- **Only Legendary and up take the camera.** Auto-fire should shorten or queue reveals.
- **Always hand the camera back**, including on skip, death or a second reveal, and do it **before** signalling "done". A popular cutscene module got this order wrong.
- **Hit-game patterns behind this:**
  - Sol's RNG changes the star colour and sound by rarity bracket; only the top tier gets its own cutscene and music; there is a setting to mute other players' rare-roll sounds.
  - Pet Simulator 99 posts rare hatches to the whole server and shows your rarest pet as an aura.
- **Cutscene camera recipe:** set the camera to Scriptable, tween a CFrame or follow a curve for 3+ points, keep FOV between 70 and 85, and add letterbox bars as GUI. Moon Animator 2 camera tracks can be played back with a Moon2Cutscene-style player.

## 3. Making our own art (no downloads, no copying)
- **Textures:** draw a white or grey shape on a transparent PNG and tint it in Roblox with `Color`. One texture then serves every rarity and accent.
  - Additive layers (LightEmission 1) can be grey on black.
  - Smoke and dark layers need real alpha and LightEmission 0.
  - Sizes: 256 or 512 px; flipbooks 1024 px Grid4x4 with 8 px gutters.
- **Kit tool:** `new-game-kit/tools/vfx/make_textures.py` writes 13 textures to `assets/vfx/` (picture: `assets/vfx/_sheet.png`):
  - soft glow, ring, broken ring, 4- and 6-point stars, spark streak, cel puff, slash arc, tiling noise, beam core;
  - flipbooks: shockwave, cel smoke puff, looping flame.
  - Alex uploads them with Asset Manager > Bulk Import and sends back the IDs. We never invent IDs.
- **Meshes:** Python can write OBJ rings, crescents, domes and helix ribbons, with U along the sweep so textures scroll. Import with "Make Double Sided" on; stay under 20k triangles. Put the picture on two `Texture` children so the mesh can fade.
- **Glow, three cheap tricks:**
  - Neon with a plain colour, plus Bloom;
  - a ForceField shell 5–10% bigger, for a moving rim;
  - one Highlight that you toggle rather than create and destroy. The limit is now 255, not 31; the first one costs up to 1 ms on phones.
- **EditableImage and EditableMesh:** only work in published games after Alex turns on "Enable Mesh / Image APIs" in the Creator Dashboard. Max 1024×1024 and 20k triangles.
- **Techniques from the tutorial videos to keep:**
  - an outline-only Highlight (FillTransparency 1);
  - Neon copies of a part toggled per charge stage;
  - a 16-frame texture cycled on a ribbon mesh;
  - one hidden joint driving a multi-mesh model;
  - trail settings: Lifetime 0.5, MinLength 0.1, MaxLength 0;
  - blur and SunRays behind charge cutscenes, and testing glow at night.

## 4. Motion from code
- **Pick the tool:**
  - tweens for fixed one-shot moves;
  - **springs** for anything that can be interrupted or should overshoot (recoil, UI pops, aim);
  - smoothed follow for cameras.
  - Run cosmetic motion on the **client**: server tweens stutter at 20–30 updates per second.
- **Kit module `Spring`:** an exact damped spring (same model as `spr`) on numbers and Vector3. Presets: Bouncy (0.5, 5), Clean (1, 4), Wobble (0.4, 4), Squash (0.4, 6), Pop (0.45, 7).
- **Cannon rig (s):** anchor the base; join the moving parts with Motor6Ds at the real hinges (yaw, pitch at the trunnion, a recoil slide, wheels), and write `Motor6D.Transform` in PreSimulation from springs. A wrong pivot is the top reason a code rig looks cheap.
- **2026 change:** since Jan 26, 2026 new R15 player characters use **AnimationConstraint** joints, not Motor6D. `IsA("Motor6D")` misses them, and setting C0/C1 errors. Layer lean, recoil and landing dips by multiplying onto `Transform` in PreSimulation. Props and NPCs we build keep Motor6D.
- **Animation clips:**
  - Studio has no text-to-animation.
  - Use five poses per strike: idle, anticipation, contact, follow-through, recovery.
  - Use FK, not IK, when AI writes angles (IK can flip an arm).
  - When an animation is shortened, move its markers with the keys.
  - A fighting-stance idle animates only the arms and torso, so the walk still moves the legs.
  - Clips made by code are tested in Studio with temporary IDs; Alex publishes them for the live game.
- **Animation Graphs:** documented, with transitions in Linear or CubicV2 only. Treat state machines as possibly still beta.

## 5. Budgets and the effect system
- **Phone budget** (from a staff-section article): about 500 draw calls and 500k triangles per scene, under 150 draw calls for UI, and under 1.3 GB of memory.
  - Each ParticleEmitter or Beam is **one draw call however many particles it emits**, so use few emitters that emit a lot.
  - BillboardGuis are costly: pool the "+1" popups.
  - Cap a big moment at 8–12 emitters or beams (s) and about 100 particles.
- **Kit module `Emit`:** effects are templates whose pieces carry the VFX Forge attribute names: `EmitCount`, `EmitDelay`, `EmitDuration`.
  - `Emit.Play(clone, where)` plays the whole timeline and cleans up afterwards.
  - The same module holds the gates:
    - `TryFlash()`: at most once per second, and off when the Flashes setting is off;
    - `MotionScale()`: 0 with Reduced Motion (`GuiService.ReducedMotionEnabled`) or ScreenShake off;
    - `InRange()`: skip effects more than 300 studs away.
- **Networking:** the server decides the result and fires one remote with the effect name, position and `GetServerTimeNow()`. Every client plays the effect and fires it from markers. Rate-limit the remote.
- **Projectiles:** visual-only on the client; the server owns distance. The arc maths is in `LaunchFX.Arc` and `LandingTime` (gravity 196.2).
- **Low quality settings** cut particle rates automatically. Use `Emit()` bursts for small effects that must still show.

## 6. Anime games: what to borrow
- **Structure:** 4 base moves plus a meter that fills in combat and unlocks an "Awakening" that swaps in 4 ultimates. A big move has a built-in cost: afterwards every skill is on cooldown and the meter is at zero.
- **Character types:** a dash fighter, a heavy with a long wind-up that punishes misses, a zoner, a grappler, and a transformation form.
- **Visual vocabulary:** see note 15 and the `AnimeFX` module.
  - The impact frame is a ColorCorrection (Saturation −1, very high Contrast, 0.1 s) with parts switched to Neon. Ours is gated to one per second and darker.
  - Rocks are placed from a raycast of the surface and pooled.
  - Each move family gets **one motion plus one ground reaction**.
- **Summons:**
  - Hits show odds and pity, e.g. Legendary guaranteed by 50, Mythic by 400.
  - Shinies are recolours: a higher tier is a new colour layer on the same item. Murder Mystery 2's chroma knives and Pet Simulator 99's Huge trails work the same way.
- **Server-wide moments:** Blox Fruits' full moon, and Grow a Garden's weather skies and weekly scheduled events. Give the whole server a world cue before a big moment.
- **Commissioned VFX** costs about 2,000–4,000 Robux per slash or hit effect, and 5,000–10,000 per advanced move, if Alex ever wants hand-made art.

## 7. Sound
- A hit has **four layers**:
  - a crack above 1 kHz;
  - a body near 200 Hz;
  - a sub sine falling through 30–60 Hz over 200–400 ms;
  - a reverb tail on the body only.
  - Saturate the layers so the hit cuts through phone speakers. Make them with `tools/sfx/make_sfx.py`.
- A normal shot uses only the crack and the body. Rare tiers add the sub, the tail, a riser during the tease, and their own sting.
- **Duck the music:** the simplest reliable way is to tween the Music SoundGroup down 3–6 dB for the sting and back. A CompressorSoundEffect side-chained to the stinger group is the docs' way; test that it works in Studio before relying on it (note 19, Part 4).
- **Pitch:**
  - ±3–6% random pitch on repeated clicks and coins, never on stings or other signature sounds (note 19, R24);
  - one semitone up per skip, capped at +12, so a long flight plays a rising scale.
- Other players' rare shots play in 3D, with a mute toggle.

## 8. Everything else the hits do well
- **Discovery changed on June 15, 2026.** Roblox now ranks games on 28 days of return (day 1, days 2–7, days 8–28). The top signals are:
  - how often an impression turns into a play;
  - **quits within 60 s and within 1–3 minutes** (these count against you);
  - days played per player;
  - minutes played, **capped at 60 per player per day**.
  - Friends playing together and spending come next.
  - A custom, honest thumbnail is required for home-page impressions.
  - What helps: a fast first reward and a 6-second loop.
- **Required:** a maturity questionnaire (games without a label can't be played publicly since Sep 30, 2025).
  - Paid random items show percentages that add up to 100%, behind an "Info" or "Details" button.
  - Luck boosts show their numbers and update the shown odds while active.
  - `PolicyService` decides who may buy random items or trade.
- **Return:** weekly updates, a world that keeps growing while you're away (Grow a Garden), and scheduled events at published times. No fake countdowns.
- **Social:** an invite prompt can carry data, so an invited friend spawns next to the person who invited them. Live global leaderboards use MemoryStore (entries expire after 45 days at most).
- **Analytics:** set up funnels in AnalyticsService (logged from the server, in published games, up to 10) to see where kids quit.
- **Rewarded video ads** need about 100K daily players and only show to players 13 and older, so skip them at launch.

## 9. Kid-safe: what the hits do that we don't

| Seen in hits | Our version |
|---|---|
| Impact frames chained black-white-black several times a second | Dark or desaturated, finishers only, one per second, behind the Flashes toggle |
| A cracked white screen on rare rolls; disco and lightning spam | Slow fades of 0.15 s or more, one flash per reveal |
| Colour that changes partway through a reveal | The real tier colour from frame one |
| Luck potions that don't say how much they help | The boost shown in numbers, with odds updating live |
| VIP-discounted pity; event units with no pity | The same pity for everyone, always shown |
| Hourly banner countdowns; progress wiped on death | Real fixed times only; checkpoints |
| Burn, poison, stab themes | Sparkle, bubble, zap, cartoony poof |

## 10. Kit modules (in `new-game-kit/src/Shared`, tests in `tests/`)
- `Spring`: springs and presets.
- `Emit`: attribute timelines, plus the flash, motion and range gates.
- `LaunchFX`: the cannon or throw shot.
  - `Charge(model)` then `:Fire({tier, color, direction})`.
  - `Flight(ball)` then `:Land(pos)`.
  - `MuzzleTemplate`, `KickCamera`, `Arc`, `LandingTime`, `StretchFor`, and a `Trauma` shake.
  - Common and Rare tiers have **no shake or zoom**, following the reference.
- `RareReveal`: `Play(tier, {target, title, odds, color, onAnnounce, music, sky})` and `Plan(tier)`.
- `AnimeFX` (note 15): auras, hits, shockwaves, craters, impact frames, speed lines, hit-stop.

**Status:**
- Pure maths and plans pass offline (156 kit tests).
- The visuals have **not yet run in Studio**. Do one Play test of each before wiring them into a game.
- The textures are ours, but not uploaded yet.

## 11. Next steps to replace guesses with measurements
1. Frame-step at 30 fps one Sol's RNG cutscene, one Pet Simulator 99 Huge hatch and one anime summon reveal. Record them, or ask Alex for recordings.
2. Build the Rare tier first as the small test piece (golden slice), then roll up the ladder.
3. Upload `assets/vfx`, swap the IDs into `LaunchFX.Textures` and `AnimeFX.Textures`, and compare side by side with the reference.
