# Roblox anime games, part 3: numbers, artist workflow, architecture, staging (Oct 31 2026)

Third pass. Builds on `research_notes/Roblox animation and VFX deep dive/anime_games_study.md` (part 1) and `anime_games_part2.md` (part 2). Only adds what those two lacked: **real numbers**. Part 1's big gap was "no frame data, no cooldown seconds". This pass found cooldowns, M1 damage splits, dash cooldowns, awakening length and domain stun length from wikis, plus a large set of measured numbers already sitting in the LihFolk vault.

Source tags:
- [cited URL]: read on that page this session.
- [LihFolk path]: from `LihFolk/LihFolk Vault V2/` (a third-party knowledge base; its "reference project" numbers are measured in one live game, not in TSB/JJS).
- [estimated]: my judgement, not verified.

Patterns only. The game, character and move names below identify where a number came from. Never reuse them, their assets or their move names in our games.

---

## 1. Numbers table

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

## 2. VFX artist workflow notes

- **Flipbooks got bigger (Oct 13 2025, client beta):** `ParticleFlipbookLayout.Custom` with `FlipbookSizeX` / `FlipbookSizeY` from 1 to 64. Before, only square Grid2x2/4x4/8x8 on square textures (256/512/1024). Now non-square sheets work, e.g. 4x8 = 32 frames, or a 4096x4096 sheet holding 32x8 = 256 frames of 128x512. Old non-power-of-two emitters may change look, so check them. [cited [DevForum beta](https://devforum.roblox.com/t/client-beta-optimize-your-particle-animations-with-custom-flipbook-layouts/4005128)] For us: a tall slash or a flame column can now be a 4x8 strip instead of a wasted square sheet.
- **Mesh flipbooks are not a feature.** Artists swap MeshIds or textures from a script, frame by frame. Particles are the only built-in flipbook. [cited [DevForum](https://devforum.roblox.com/t/what-are-mesh-flipbooks/2656999)]
- **Impact frame recipes artists use** (no timings were given; ours come from LihFolk) [cited [DevForum advanced impact frames](https://devforum.roblox.com/t/advanced-impact-frames/2468478)]:
  1. Sequence: speedline particles -> black ColorCorrection -> white Highlight on the hero -> more particles.
  2. Saturation -1 via ColorCorrection, plus Highlight recolours of objects.
  3. Hand-drawn 2D frames, or a screenshot desaturated, edge-filtered ("torn edges") and inverted, shown as a full-screen image.
  4. Two ColorCorrections: one darkens the scene without wiping out the background.
  - Pitfall: with ColorCorrection on, some effects vanish. Highlights don't draw particles in front, and ViewportFrames lag.
  - LihFolk timing: 1–2 frames at 1/30 s, inside the hit-stop, never more than 2 frames (strobe) [LihFolk `Camera Shake and Camera FX.md`].
- **Trails vs crescents:** trails only for arcs under about 120°. Wide sweeps get a drawn crescent mesh (radius about 15 studs at 1.6x scale, fades in 0.1–0.3 s, tinted with the weapon colour). Trail on at `hit - 0.12`, call `Trail:Clear()` first, off 0.24 s later. [LihFolk `VFX Timing with Animation.md`]
- **Afterimages:** only when moving faster than 26 studs/s (a run is about 22). One every 0.05 s, max 10 per move. [LihFolk same]
- **Sound sync:** measure each sound's peak (a swish peaks at about 0.13 s) and start it at `beat - peak`, so the crack lands on the hit frame. [LihFolk same]
- **Moon Animator to game:** VFX tutorials are video-only (e.g. "(Moon Animator) Impact Frames: Basic / Advanced" on YouTube, the DevForum "How to use Moon Animator for Roblox VFX", Sep 2025). No written steps or numbers could be read. Transcripts were blocked this session (YouTube proxy 403; the transcript connector needs a paid plan).
- **Marker sync rule** [LihFolk `Combat Combo Systems.md`]:
  - The client plays the clip, then sends the cast 0.06 s later.
  - The server times each hit at `marker - 0.06`, so server damage lands one network trip after the visual hit.
  - A baker that drops markers silently breaks damage timing.
- **Layer counts per move:** no artist breakdown with counts was reachable. Working default [estimated]:
  - M1: 2 layers (spark plus small ring).
  - Skill: 4–6 layers (wind-up glow, trail or crescent, impact burst, shockwave ring, debris, lingering smoke).
  - Ultimate: 8–12 layers, plus a camera package.
  - Matches LihFolk's particle budgets above.

---

## 3. Combat architecture notes

- **Market-standard feature list** (paid battlegrounds kits, 2026): M1 strings, blocking, 4 skills, a skill framework, directional dashing, uppercut and downslam, ragdoll with part-destruction physics, character switch, mobile support. [cited [BuiltByBit kit](https://builtbybit.com/resources/battlegrounds-combat-system.100256/)] This is the minimum feature set players expect.
- **State machine:** priorities Idle 1, Attack 2, Block 2, Stunned 3. Explicit allowed transitions; Attack <-> Block is forbidden. Timed states carry a per-character token so an old timer can't reset a newer state. [cited [DevForum state machine](https://devforum.roblox.com/t/combat-state-machine-for-block-attack-stun-system/4660683)] Store state as a character attribute.
- **Who moves whom:**
  - Your own dash runs on your client (a commenter says TSB uses acceleration, not constant velocity) [cited [DevForum dash](https://devforum.roblox.com/t/very-smooth-dash-system-like-strongest-battlegrounds/2590353)].
  - Knockback is applied on the victim's client with LinearVelocity, sent by the server [cited [DevForum knockback](https://devforum.roblox.com/t/how-can-i-achieve-knockback-like-in-battleground-games/2545817)].
  - Some devs move ragdolled bodies to server ownership [cited [DevForum](https://devforum.roblox.com/t/how-to-reduce-delay-in-knockback-like-tsb/3226267)].
  - Roblox has built-in delay; the only real fix is rollback, or custom replication over UnreliableRemoteEvents (same thread).
- **Typical ability flow:** input -> server checks the cooldown -> FireAllClients to play VFX -> the attacker applies its own physics. [cited [DevForum](https://devforum.roblox.com/t/ability-framework-replication-help-similar-to-the-strongest-battlegrounds/3034728)]
- **Frameworks:** WCS (roblox-ts, usable from Luau) packages replication, skills, status effects and server requests [cited [DevForum WCS](https://devforum.roblox.com/t/20-wcs-a-combat-system-framework/2843521)].
- **Hit registration** [LihFolk `Client Prediction and Reconciliation for Combat.md`, `Genre Playbook - Battlegrounds...`]:
  - The attacker sees the animation and VFX in under 100 ms; the server decides damage.
  - The server keeps 1 s of root positions at 20–30 Hz and caps rewind at 250 ms.
  - Client-reported hits pass a reach check: hitbox reach + half the box + target speed x ping.
  - Cooldowns are enforced at 0.95x on the server.
  - Remotes run about 40–50 ms out of step with physics.
  - Max 8 playing tracks per Animator.
  - Test at 100/150/250/300 ms simulated lag.
- **Hitbox size:** slightly bigger than the weapon (6x5x6 studs for a 4-stud blade) [LihFolk Melee build].
- **Rate rule:** if a finisher's hit lands later than the next swing's hit, delay the next press by the difference, or the server drops the second hit as too fast [LihFolk `Combat Combo Systems.md`].

---

## 4. Ultimate and cutscene staging

All numbers are from [LihFolk `08 Animation/05 Systems/Cinematic Ultimates.md`] unless marked.

- **Anchor contract:**
  - Damage, the explosion and the camera all centre on one server-set anchor point. Before this, enemies stood up to 19 studs from the visual centre; after it the error was 0.00.
  - Targets are pulled into a tight stack (≤1.5 stud spacing) over 0.7 s, starting at t = 0.15 s.
  - Damage lands at or after the climax. Bosses are never pulled.
- **Camera beats:**
  - **Open:** FOV punch over 0.12 s, held to the Open marker (about 0.21 s, clamped 0.15–0.6), then a 0.55 s widen, dolly and lift. Grade in 0.25 s, letterbox in 0.35 s, title card held 1.35 s.
  - **Climax:** on the Impact marker (fallback: 66% of the clip). Impact frames inside the hit-stop, FOV kick, shake after the freeze, blur, colour punch (0.35 s decay).
  - **Recover:** smootherstep back; 0.55 s blend into the player's own camera.
- **Per-tier escalation** (Epic -> top tier): FOV punch -3 -> -8, dolly 1.6 -> 4.4 studs, letterbox none -> 7.5% (cinema mode 9.5–12%), impact frames 0 -> 4 kinds, blur 4 -> 14, trauma 0.40 -> 0.95.
- **Slow motion** slows only the caster's **camera time**:
  - 0.16 s at 0.32x (lowest tier) up to 0.34 s at 0.16x (top tier), ramping back over 0.15 s.
  - Gameplay, server hits and other players are untouched.
  - The enemy impact hold (0.08–0.12 s) adds to the slow-motion feel.
- **Shake:** noise at 16 Hz, trauma decays 1.45/s, base 2.6° x tier factor 1.0–1.6. Onlookers get 0.3x, full at 30 studs, zero at 150 studs.
- **Cutscene lock:** hide all GUIs, nameplates and prompts and lock input. Restore at once on death, respawn, a camera steal, an error, or a watchdog (no frame for 0.6 s, or ult length + 2 s). Keep a kill switch to fall back to the light camera package.
- **Domain-style "time stop" in the hits:** the ultimate freezes targets for 7–14 s and leaves the caster drained (part 1, plus [rblxguide](https://rblxguide.com/games/jujutsu-shenanigans/characters/honored-one): 14 s stun, 120 s cooldown, 0.2 s expansion). Kid version: see recipe R4. 14 s of helplessness is too long for kids.

---

## 5. Anime TD summon escalation (still a gap)

- Still no readable source gives per-rarity summon timing for Anime Vanguards, Anime Defenders or ALS. Search results were YouTube titles only (e.g. "new summon animation in universal tower defense").
- **One confirmed technique** [cited [DevForum](https://devforum.roblox.com/t/how-do-the-devs-of-anime-vanguards-get-this-effect-in-a-gui/3178407)]: the glowing effect behind a unit "in the GUI" is real VFX placed in Workspace in front of the camera, computed on the client, because particles don't render in ViewportFrames.
- Our ladder already exists: `Build Playbooks/17 Do It Like the Hits` §2 (Legendary 2 s, Mythic 3 s, only Legendary+ takes the camera). Map LihFolk's per-tier camera table (§4) onto it for the Legendary+ beats.

---

## 6. Kid-safety flags found this pass
- **Gambling theme:** one JJS character's domain is a slot-machine "jackpot" reel. Don't copy a slot or jackpot motif, even as a joke move.
- **Long helplessness:** 14 s domain stuns, insta-kill finishers. Bad for kids: cap any stun at about 2 s and give a visible escape.
- **Strobe:** impact frames are black/white or negative flashes. Max 2 frames each and at most 1 flash per second (project rule). No negative-image frames for the lowest tiers.
- **Ragdoll/finisher kills** count double for kill credit (TSB). Fine mechanically; keep it cartoony, with no gore or blood decals.
- **Paid kill sounds and finishing emotes** (TSB game passes): fine as cosmetics, but no taunting text aimed at the loser.

---

## 7. Recipes to add (kid-friendly, IP-free)

**R1. 4-tap combo ("Bop chain")** [numbers from LihFolk/TSB pattern; tuning estimated]
- Hits land at 0.20 / 0.20 / 0.23 / 0.32 s; clips 0.42 / 0.42 / 0.47 / 0.62 s. Min gap 0.45 s, 0.15 s input buffer, combo window 1.0 s.
- Damage weights 3/3/4/5 (the last hit is biggest).
- Hits 1–3: a small spark, a squeaky "bop", 0.4 s stun.
- Hit 4: knockback (LinearVelocity on the victim's client, up = 0.3 x speed), 70 ms hit-stop, 0.2 trauma, 3 colourful afterimages, a star burst.
- Total combo cap 3 s. After a knockdown, 0.75 s get-up shield.

**R2. Dash ("Zoom")**
- About 70–80 studs/s for 0.3 s (about 22–24 studs), eased out, not a hard stop.
- Side dash 2 s cooldown; front dash 4–6 s with a tiny bump.
- 0.3–0.4 s dodge window counted on the server.
- Camera: +9 FOV pulse, Blur 5 for 0.1 s. A cartoon dust puff at the start point.

**R3. Guard and perfect guard**
- Hold block: x0.3 damage, front only.
- Tap within 0.2–0.26 s before the hit = perfect guard. It gives a sparkle shield pop and a 1 s daze on the attacker (kids: not 2.2 s).
- 0.55 s re-arm. Stuck escape: one "wiggle free" per 20–30 s.

**R4. Power-up meter ("Super mode")**
- The meter fills from landing hits and partly from blocking or getting hit (comeback).
- Activation: 0.6 s untouchable power-up pose, one ring and one flash.
- 45–60 s of super mode, heals a little, swaps the 4 moves for bigger ones (cooldowns 10–40 s); the aura stays on.
- Super finale: camera package per §4 at Epic or Legendary values. The freeze bubble holds targets for at most 2 s, then a big bounce, never a long stun. The meter empties and all moves go on a short cooldown afterwards (the "cost").

**R5. Skill cooldown ladder**
- 4 skills at 8 / 12 / 15 / 20 s (kids: slightly shorter than JJS's 13–20).
- The super finale gets a 60–90 s cooldown, or one use per super mode.

**R6. Impact frame (safe)**
- At the climax only: 1 frame (1/30 s) of a white silhouette plus a black ColorCorrection (Saturation -1, Contrast +1), then a colour punch back.
- Never a negative image, max 1 per second, and only on Legendary+ moves.

**R7. Tall flipbook VFX**
- Author slashes and flame columns as 4x8 Custom flipbook sheets (non-square, e.g. 512x1024).
- Fall back to Grid4x4 if Custom isn't live for all clients yet (it was a client beta in Oct 2025; check before relying on it).

**R8. Summon reveal behind UI cards**
- Put real particles and beams in Workspace in front of the camera behind the card (not in a ViewportFrame).
- Rarity ladder from Playbook 17. Odds and pity always visible.
