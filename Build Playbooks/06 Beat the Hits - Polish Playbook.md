---
tags: [build-playbooks, polish, game-feel, juice, checklist]
updated: 2026-10-30
---

# 06 Beat the Hits - Polish Playbook

Back to [[00 Build Router]] · What to borrow: [[07 Borrow List - Game by Game]] · Reference measured: [[Teardown - Stone Skipping]] · Rules: `GAME-FEEL.md` · Recipes and APIs: [[Brief - VFX, Animation, Audio and Game Feel]], [[Brief - UI, Input and Mobile]]

**Goal (owner, Oct 30):** "feel and operate like Stone Skipping", then beat it, with our own look.

This page is the **spec**: the numbers and moments a front-page game hits, and the extra step that beats it. For *how* to code each piece, follow the links; don't re-derive.

**Tags:**
- **[M]** measured from the owner's recordings;
- **[R]** read in this repo;
- **[D]** Roblox docs;
- **[I]** design judgement, to tune by eye.

## 0. The five rules behind "polished"
1. **Answer every input within 0.1 s.** Show a sound, a squash or a number before the server has even replied. The *reward* waits for the server; the *click* never waits. [I][R brief]
2. **One star per moment.** During a launch the counter is the star, during a hatch the egg, during a rebirth the before → after number. Hide or dim everything else. [M]
3. **Short loops, no waiting.** Stone Skipping:
   - the throw lasts about 4.5 s;
   - a hard cut home;
   - the next throw is ready about 1 s later. [M]
   
   Anything that makes a kid wait more than 2 s without something to watch feels broken.
4. **Calm camera, busy world.** No shake on normal actions. Speed comes from things rushing past: water ripples, border walls, the zone name. [M]; `GAME-FEEL.md` §9.
5. **Every few seconds, a number goes up somewhere:** the stat, the level bar, a toast, a badge. [M]

## 1. The launch: spec by phase (+1 Cannon Evolution, and any throw/launch game)
| Phase | Reference [M] | Our spec to beat it [I] | Status in Cannon [R] |
|---|---|---|---|
| **Ready** | A green THROW button pops above the player in the zone | Walk-in zone **plus** a big pulsing LAUNCH button (phones). The cannon's fuse glows while you're in the zone | Walk-in zone ✓ |
| **Anticipation** | None (instant throw) | **0.35 s:** the cannon recoils back 0.6 studs, the fuse sparks, a low rising tick. Short enough not to feel like waiting; it sells the *cannon* | Cannon tween exists (Effects.lua:53) |
| **Fire** | Throw animation | Muzzle flash (one bright frame), a smoke ring (`Emit(12)`), the layered crack + boom (0.8 s, done Oct 30), and a tiny FOV punch 70→74→70 over 0.25 s. **The only "kick" in the launch.** | Shot sound ✓; FOV punch ✗ |
| **Camera in** | Cut to a chase cam in ≤0.5 s | Ease in over 0.3 s (no jump cut), then lock | ✓ lerp dt×12 |
| **Chase cam** | Low behind the stone; horizon ~⅓ from the top; water fills the lower ⅔; no shake | Keep: `ball - dir*16 + up*4.5`, look 40 ahead (current values match). Add a 2–3° roll on curves only, never on hops | ✓ |
| **Speed curve** | Near-**constant** ~60 m/s for 80% of the flight, slowing only in the last second | Current: `1-(1-u)^2` starts at 2× the average and slows the whole way, so mid-flight feels sluggish. **Change to:** constant speed until u = 0.8, then ease out | ✗ worth fixing |
| **Duration** | ~4.5 s for 220 m | `FlightTime = 2.5 + sqrt(d)*0.09`, clamped 3–14 s, is fine. Above about 8 s, add something new to see every 2 s (zone, best-flag, landmark) | ✓ |
| **Counter** | Huge yellow "220 m" top centre; zone name small under it, big on entry | Same. Plus a **colour step** each 1,000 m and a scale bump of 1.0→1.12→1.0 over 0.15 s on each zone entry | ✓ counter, bump ✗ |
| **Bounces** | A small splash; +1 Skill ticks in the HUD per bounce; "Level Up!" small | Ripple rings ✓ (Oct 30), cash pop per skip ✓. Add: **pitch rises a semitone per skip** (0, +1, +2… capped at +7). Kids hear the streak | Pitch ladder ✗ |
| **Zone cross** | The zone name grows | Wall flash, a short sting, sky tint lerps 1 s to the zone's colour | Banner ✓, sky ✗ |
| **Landing** | Hard cut home | **Beat it:** 3 big ripples ✓, then a **0.6 s result card**: "2,340 m · +12.5K 💵 · NEW BEST!", then cut home | ½ |
| **Payout** | "+1 🏆" over your head; trophies fly to the counter | Coins fly from the screen centre to the Cash counter in a 0.4 s arc, 8 icons max; the counter **rolls up** with ticks and flashes green (the motion pass did this) | ½ |
| **Reset** | Next THROW ~1 s later | `RETURN_DELAY = 1.5`. Try **1.0** | Tune |

### Beat-them extras for the launch (none of these are in the reference)
- **Personal-best flag** standing on the water at your best distance, with your name. Passing it gives "NEW BEST!", a gold burst and a cheer. Friends' flags show too, which makes it social.
- **Rare shots:**
  - a ~1/100 **Golden Shot**: gold trail, ×5 payout, chime;
  - a ~1/1,000 **Mega Shot**: rainbow trail, ×25, server-wide message "Alex fired a MEGA SHOT! 🎉".
  
  The server rolls before the launch. This is Stone Skipping's Secret/Colossus idea in our own colours.
- **Distance milestones** every 1,000 m: a floating number gate the ball flies through.
- **A slow-motion finish only on a new best:** the last 0.4 s at 0.4× speed, then normal. Only on a new best, so it stays special.

## 2. Juice menu (pick per event; the event decides how big)
| Size | When | What fires together, on the same frame |
|---|---|---|
| **XS** | Button press, +1 tick | Squash 0.9 then a Back spring (0.12 s), a soft click, no particles |
| **S** | Skip, coin, small buy | +number popup rising 2 studs, Back ease 0.5 s, then fade; a chip sound; 4–8 particles |
| **M** | New zone, new cannon, egg common/rare | Banner pop, sting (≤0.6 s), 16-particle burst, UI counter bump |
| **L** | Rebirth, legendary hatch, new best | Dim the screen 40%, sunburst rays rotating, big text with Back ease in, confetti, one white flash (≤1 per second), sting ≤0.8 s, "Tap to continue" |
| **XL** | Mega Shot, secret pet | L + server-wide message + a slow-motion beat (0.4 s) |

Rules [R `CLAUDE.md`, brief]:
- ≤1 flash per second.
- Shake only on L/XL, with a settings toggle.
- Particles under 100/s per emitter on mobile.
- The reward's juice fires only after the server confirms.

## 3. Sound (the owner's taste is set: smooth, "satisfying", short)
- **Everything short:** UI 0.1–0.3 s; rewards, rebirth, hatch and unlock stop by **0.6–0.8 s**; splashes play only their first second [R commits Oct 30].
- Pool and preload. Two SoundGroups (Interface, Effects) with a mute setting [R Sfx.lua].
- **Pitch variation ±5%** on repeated sounds (skips, coins), so 20 in a row don't sound robotic [I].
- **Streak pitch ladder** on skips and coin runs (see §1).
- **Duck the music ~30%** for 1 s under big stings [I].
- **Sources:** Kenney CC0, the UI SFX "rubber" pack (CC0), and Roblox's licensed library (search the Toolbox; creators ProSoundEffects or APMOfficial). Never invent IDs [R].

## 4. HUD and UI: the reference layout, our skin
**Layout to copy** (positions, not art) [M]:
- top centre: the main pass offer, the event pill, then **one message line**;
- left: a wide Shop, then a 2×3 menu grid with red "!" badges and **progress % on Rebirth**;
- left bottom: currencies (the payout currency biggest), then Friend Boost;
- bottom centre: the stat + multiplier, then the Level bar, then **3 stat packs**;
- right: 2x passes, the starter pack, the event quest timer.

**Beat it on:**
- **Clarity.** The reference crams 20+ buttons on screen. Ours shows the **3 that matter now** at full size and the rest smaller. The UI is already 18% smaller (owner, Oct 30).
- **Motion.** Panels enter in 0.26 s with Back from 0.75 and exit in 0.14 s with Quad In; cards cascade in; numbers roll [R build notes, Oct 30 motion pass]. The reference just appears.
- **Readability on a phone:**
  - test in Studio's Device Simulator (iPhone SE and a small Android);
  - nothing important in the top 60 px (Roblox top bar);
  - thumb-sized buttons, at least 44 px [D Brief - UI, Input and Mobile].
- **Look:** toy-style panels, thick outline, lit top and lip (`roblox-cartoony-ui` skill, [[14 Cartoony UI & Juice]]).

## 5. Onboarding: the numbers to hit
| Milestone | Reference [M] | Target |
|---|---|---|
| Intro cutscene | ~15 s, skippable | ≤15 s, skippable, ends behind the player |
| First payoff (throw/launch) | ~40 s after join | **≤30 s** |
| First new item (stone/cannon) | ~55 s | ≤60 s |
| First rebirth (tutorial end) | **~85 s** | **≤90 s** (Cannon: GameConfig now aims at ~1.5 min of training with `REBIRTH_POWER_BASE = 100`; an earlier build took ~7 min. Time it from join in a fresh save) |
| Feature unlock + Daily Rewards | ~88 s | Right after the first rebirth |
| First egg hatch | Not in the first 90 s | In the first 3 min (from a playtime gift: a free egg) |

Roblox's own onboarding guide [D create.roblox.com/docs/production/game-design/onboarding]:
- teach the controls on screen;
- reach the fun fast (low early level thresholds, starter items);
- show short, mid and long goals before onboarding ends;
- **end with a moment of joy**;
- A/B test the steps with Experiments and the Player Funnel.

## 6. Progression and retention checklist (each is a system the hits all have)
- [ ] Two currencies: the stat opens gates, the payout buys things
- [ ] Level from the stat → a global multiplier shown next to the stat
- [ ] Rebirth with a Before → After panel; first rebirth in the tutorial
- [ ] Training stations unlocked by rebirth, visible as a ladder in the lobby
- [ ] Eggs with odds on the card, Equip Best, Lock, Index, slots, Golden Fuse (3 → 1)
- [ ] Playtime gifts (12 tiles, about 2 h total) + 7-day daily streak
- [ ] Titles as achievements with a small perk, worn over your head
- [ ] Friend Boost + invite button; group/like chest
- [ ] Codes box at the bottom of the shop
- [ ] Weekly update: a new world or zone + an egg; a seasonal event currency
- [ ] Global leaderboards (best distance, total, rebirths)

## 7. Monetization layout (kid-safe version of what the hits do)
One scrolling shop, in this order:
1. starter pack (a real one-time discount is OK);
2. featured egg with odds;
3. aura/roll offers with odds;
4. passes (2x stat, 2x payout, Auto launch, Auto rebirth, pet slots, VIP training pads);
5. 10-minute boosts + a bundle;
6. currency packs (5 sizes);
7. codes.

Also put **stat packs next to the Level bar** and **2x offers on the HUD**.

**No crossed-out fake prices, no fake "limited", no fake stock.** Items that do nothing yet show "Coming soon" [R `CLAUDE.md`].

## 8. Phones and performance (most kids play on phones)
- Baseline: under **1,000 draw calls and 1M triangles**; 16.67 ms per frame at 60 FPS; chunk script work to ~5 ms per frame [D performance-optimization/design].
- Transparency only 0 or 1 where possible (overdraw) [D].
- Instance streaming for big maps [D]. Cannon Evolution packed its map from 9,162 to 187 pieces (Oct 30).
- Cosmetic motion on the client; effects pooled; emitters use `Emit` bursts [R brief].

## 9. The feel test (run before the owner sees a build)
1. Record ours and the reference at **30 fps**, the same moment, the same framing (`GAME-FEEL.md` §9).
2. Measure:
   - time to first payoff;
   - throw length (s);
   - counter speed (m per 0.5 s);
   - camera height and horizon line;
   - counter text height (% of screen);
   - next-throw delay;
   - first rebirth time.
3. Put both side by side, one picture (repo rule 2).
4. A fresh critic agent lists the **worst 5 gaps first** (repo rule 3).
5. Fix the top 3, then show the owner.

## Sources
- The owner's recordings: `cannon-evolution/references/recording-1.mp4` and `recording-2.mp4`, plus two PC screen recordings (Oct 30, project files).
- Roblox: [onboarding](https://create.roblox.com/docs/production/game-design/onboarding), [design for performance](https://create.roblox.com/docs/performance-optimization/design).
- Stone Skipping wikis: [allthings.how](https://allthings.how/1-stone-skipping-beginner-s-guide-every-world-s-skill-requirement/), [1-stone-skipping.wiki](https://1-stone-skipping.wiki/guides/beginner-guide), [stoneskipping.wiki](https://stoneskipping.wiki/), [bloxodes](https://bloxodes.com/wiki/1-stone-skipping), [nerdschalk Skip Rush](https://nerdschalk.com/skip-rush-stone-skipping/).
- Repo: `cannon-evolution/src/client/GameClient/Effects.lua` (flight), `shared/GameConfig.lua` (FlightTime, RETURN_DELAY), `reports/+1 Cannon Evolution build notes.md`, git log of `claude/vault-everything` (Oct 30 sound and arrow rounds).
