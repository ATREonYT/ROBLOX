---
tags: [build-playbooks, game-design, genres, first-minute, retention, economy, live-ops, discovery, kid-safe]
updated: 2026-10-31
---

# 20 Whole-Game Field Guide

Back to [[00 Build Router]] · Studio practice: [[18 Studio-Level Development Playbook]] · Animation and VFX recipes: [[19 Animation and VFX Recipe Book]] · Taste: [[09 Owner Taste Rules]]

**Why this note exists.** On Oct 31 Alex asked us to "learn everything, absorb". This note is the whole-game craft, distilled from the LihFolk vault (1,400 notes) plus our research, and checked against our house rules. Where LihFolk is looser (flashes, VIP, limited stock, optional pity, near-miss), **our rules win** (§5).

**How to use it:**
- Before designing a game, read §1 and the matching genre blueprint in §2.
- When numbers look bad, use the symptoms table in §3.
- To see which rules are already proved by the kit's checks, see §0.
- Each line names the LihFolk note to open for depth.

## 0. Scorecard: what our checks already prove, and what needs eyes
Added Oct 31 (second pass). Run `sh tools/check.sh` in the game folder; it is also run on every GitHub push. A rule in the left table can't silently break. A rule in the right table needs a person or a playtest.

| Proved by a check on every push | Check | Kit result today |
|---|---|---|
| Rule 3: a small reward fast, a big one soon | `tools/pace.luau` (a bot plays the real config) | first payoff 1 s, first buy 20 s, first hatch 37 s |
| §2.1: first rebirth by about 90 s, then a steady ladder | `tools/pace.luau` | rebirths at 106 / 262 / 485 / 953 s against 90 / 240 / 480 / 840 s; each inside the 30% band. **Rebirth 1 is 16 s slower than the blueprint; trim its price if a game needs the 90 s beat.** |
| Rule 13: rebirth keeps what it should | `tools/sim.luau` | keeps the Income upgrade, resets coins and walk speed, raises the multiplier (pets kept is not yet checked) |
| Paid random items show odds that add up | `tools/sim.luau` | odds add up to 100%; paid eggs refused where Roblox's policy restricts them |
| Purchases granted once, only after the save | `tools/sim.luau` | redelivered receipts and failed saves are handled |
| Progress survives leaving, two servers and old saves | `tools/sim.luau` | session lock, save on leave, offline earnings, `save_v1.json` |
| Cheating by bad input gets nothing | `tools/sim.luau` "Bad input" | 17 kinds of bad input at every remote |
| No fake pressure, no made-up ids, flashes at most once a second | `tools/kidsafe_check.py` and `tests/VaultNumbers.spec.luau` | pass |

| Needs eyes or a playtest | How to judge it |
|---|---|
| Rules 1, 2, 4, 5: control in 10 s, the verb is obvious, failure teaches, one short objective | Watch a new player's first minute on a 30 fps capture. Time join → first control. |
| Rules 7–10: the verb feels good alone, the session arc, the exit hook | The feel test in note 06 §9 |
| Discovery (thumbnail, icon, title) | Creator Hub numbers after launch: quit within 60 s, and 1–3 min sessions, count against you since June 15, 2026 |
| Look and motion match the reference | One side-by-side per change (repo CLAUDE.md rule 2) |
| Real purchase prompts and the odds on screen | Alex in Studio, on the owner checklist |

## 1. What every great Roblox game does (44 rules)

### First minute
1. Control within about 10 s of joining; no unskippable intro, name prompt or group prompt before play. `LF/10 Game Design and Genres/First-Time User Experience and Onboarding.md`
2. The first action **is** the core verb, and a seven-year-old can name it after a 15-second clip. `LF/59 Viral and Trend Game Teardowns/Viral Game Anatomy - Hooks, Loops and Timing.md` §2
3. First small reward by 30 s, first big reward by 60 s, and the core loop closed 3+ times in 5 minutes. `LF/10 Game Design and Genres/Onboarding by Genre - The First Five Minutes.md` §3
4. Failure teaches the rule (falling, the first wave, the first theft); no tutorial screen to skip. `LF/59 .../Viral Game Anatomy - Hooks, Loops and Timing.md` §2
5. One objective of 8 words or fewer, one pointer, and one step at a time. The step completes from a server signal, not a "Next" button. `LF/05 UI and UX/Tutorial Step Design Patterns - Teach by Doing.md`
6. A tutorial step can never be failed by the economy: top the player up to exactly the price. `LF/05 UI and UX/Onboarding and FTUE - Tutorials That Keep Players.md`

### Core loop
7. The loop fits in one sentence with real verbs. Prototype the verb alone until it feels good before adding systems. `LF/10 .../Core Loops and Session Design.md` §1, §4
8. Every output has a sink that **changes the verb** (a faster tool, a new zone), not just a bigger number. `LF/10 .../Core Loops and Session Design.md`
9. Design the session arc: arrival, re-orientation ("here's where you were"), an easy warm-up win, the main push, one peak moment, then an exit hook. `LF/10 .../Core Loops and Session Design.md` §5
10. End each session with something unfinished and time-bound (a gift in 4 minutes, a quest at 2/3), never with a punishment for being away. `LF/10 .../Core Loops and Session Design.md` §5 "The exit hook"
11. AFK earns less than active play, and only after onboarding. Put AFK spots in the hub so idle players make it look alive. `LF/10 .../Core Loops and Session Design.md` §6

### Progression
12. Plot time-per-step for the **whole** ladder: a sawtooth (rises, then drops at milestones), anchored to targets, not guessed. `LF/10 .../Progression and Pacing Design.md`
13. Rebirth multiplier grows geometrically, slightly slower than rebirth cost. Show a "now vs after" panel with what is kept and what resets. Keep pets, index and cosmetics. `LF/10 .../Genre Playbook - Simulators.md` §7
14. Rebirths should **unlock features** (teleport, auto-hatch, trading), not only reset numbers. `LF/32 Case Studies of Top Roblox Games/Case Study - Pet Simulator 99.md`
15. Pace rarity on the median and p90 wait, never the mean. The next unreached tier is 1 to 2 sessions away. `LF/10 .../Rarity Ladders and Drop Pacing Math.md`

### Economy
16. Players feel **time to afford**, not prices. Write a band per purchase type: small upgrade 1–3 min, real upgrade 5–15 min, zone gate 15–45 min, rebirth 1–3 sessions. `LF/11 Monetization Publishing and Live Ops/Economy Inflation Sinks and Faucets Math.md` §1
17. Decide the maximum payer gap in writing (for example, "all passes together are at most 3× a free player"). Stack additively inside a category and multiplicatively across categories. `LF/11 .../Economy Inflation Sinks and Faucets Math.md` §2
18. Each currency has one job, one source and one sink. Fixed-price cosmetics never live in an exponential currency. `LF/48 Economy Design Deep Dive/Currency Architecture - Soft Hard and Event Currencies.md`
19. Duplicates always have a use (fuse, salvage, auto-delete by rarity), or phone inventories fill with junk. `LF/10 .../Genre Playbook - Simulators.md` §6
20. Simulate the economy with player archetypes before launch, and log every currency change from one wallet function after launch. `LF/48 .../Simulating an Economy Before Launch.md`, `LF/48 .../Economy Telemetry and Balancing Live.md`

### Social
21. Climb at least three rungs of the social ladder: being seen, showing off, playing side by side, co-op, trading, competing, expressing. `LF/10 .../Social Design and Multiplayer Play.md` §2
22. Rare moments are visible to the whole server (an announcement plus a world effect). Luck becomes social. `LF/59 .../Teardown - Sol's RNG.md`
23. Design for a server of 3 before a server of 20; at low player counts, shrink the server size so players land together. `LF/27 Marketing and Growth/Rescuing a Weak Launch - Empty Servers, Low CCU and Relaunch Tactics.md` Step 3
24. Give a small "playing with friends" bonus and an invite button. Reward only a friend who actually arrives, never just opening the prompt. `LF/49 Roblox Platform Features/Friend Invites Referrals and Experience Invites.md`
25. Protect new players from much richer ones (grace window, theft limits, spawn protection). `LF/32 .../Case Study - Steal a Brainrot.md`, `LF/58 Player QoL and Game Tweaks/Quick Respawn and Spawn Protection.md`

### UI and UX
26. Pop-up gate: no automatic pop-up during onboarding (the first 180 s), over another panel or reveal, in combat, or within 8 s of another. At most one modal in the first minute. `LF/10 .../Core Loops and Session Design.md` §5 "Pop-up discipline"
27. One rewards hub with tabs, not five claim pop-ups on join. `LF/10 .../Retention and Return Hooks.md` §9
28. Every rejected action says why ("Need 120 more coins"), at the button that failed, not in a corner toast. `LF/05 UI and UX/Notification and Toast Systems.md`, `LF/58 .../Feedback - Autosave Indicator Ping Display and Error Toasts.md`
29. Phone first: text at least 12 px drawn, tap areas at least 44 px, gaps at least 8 px, and zero overlaps at five screen sizes plus a notched phone. `LF/05 UI and UX/Responsive UI for Phone Tablet Console and PC.md`

### World and level design
30. Spawn faces the centrepiece. One hero landmark per zone, the brightest and tallest thing in view. Light, motion, skyline and openings all point the same way. `LF/33 Level Design/Level Design Principles - Flow Sightlines and Landmarks.md`, `LF/06 World Building and Art/World Composition and Set Dressing - Designed, Not Scattered.md`
31. Hub: build the spawn and the exits first. First station under 15 s away, the exit under 20 s for veterans, and the main shop on the way out. `LF/33 Level Design/Lobby and Hub Design.md`
32. Teach each new mechanic in four spaces: show, try (a soft floor and instant retry), test, combine. One visual cue per meaning. `LF/33 Level Design/Teaching Through Level Design.md`
33. Each zone gets one accent colour, a one-line identity and a name with a number if the path is linear. Neighbouring zones alternate warm and cool. `LF/06 .../Zone and Biome Art Direction.md`, `LF/36 Narrative and Worldbuilding/Naming Items Zones and Abilities.md`

### Live ops and updates
34. A written cadence: a weekly update on a fixed published day, content every 2–4 weeks, and one buffer week a month. Plan from what the team really shipped in the last six weeks. `LF/38 Live Ops Deep Dive/Event Calendars and Content Planning.md`, `LF/27 .../Update Cadence and Hype Cycles.md`
35. Publish before go-live and gate the content by server UTC time. Feature freeze 10 days out; event public 7 days out. `LF/27 .../Update Cadence and Hype Cycles.md`, `LF/11 .../Live Ops Events and Updates.md`
36. An in-game "What's new" panel is the main changelog: shown once per version, skipped for brand-new players, with specific numbered changes. `LF/38 .../Patch Notes and Player Communication.md`

### Discovery, thumbnails and CTR
37. Title = a fixed brand plus one accurate descriptor with the verb. Rotate only one bracketed tag per update. `LF/32 .../Cross-Game Patterns - Thumbnails Icons and Titles That Get Clicks.md`, `LF/27 .../Experience Description and Search Keywords.md`
38. Thumbnail: one subject at 30–45% of the frame with a readable emotion. It passes the greyscale test, shows real gameplay, keeps nothing in the bottom strip and comes in 2–5 versions at 1920×1080. `LF/61 Thumbnails and CTR/Thumbnail Composition for High CTR - Focal Point, Contrast and Readability.md`, `LF/61 .../Thumbnail Specs, Rules and Upload - Sizes, Count and Policy.md`
39. Icon: one face or object, readable at 50–150 px, with a hue distinct from the genre crowd. `LF/27 .../Game Icon Design - Readable at Small Sizes.md`
40. Diagnose by funnel, not by player count: impressions → click → first session → return → spend. Fix the first broken stage, one change at a time. `LF/27 .../Rescuing a Weak Launch...md` Step 1, `LF/61 .../From CTR to CCU - Impressions, Play-Through and the Discovery Loop.md`

### Accessibility and QoL
41. Ship the cheap QoL wins first: a music slider and mute (every sound in a SoundGroup), clear error messages, a loading screen that closes on ready (with a timeout and skip), a rejoin button, and a camera-shake slider. `LF/58 .../Top 25 QoL Wins by Effort.md`
42. Information never relies on colour alone: rarity has a name and an icon, not just a hue. `LF/42 Accessibility and Inclusive Design/Colour-Blind Safe Design.md`

### Community and moderation
43. The platform report button is reachable in game. Every custom interaction (trade, gift, invite) honours blocks both ways on the server. No Discord links or handles in game, and codes are never Discord-only. `LF/26 Community and Moderation/Player Reports and In-Game Moderation.md`, `LF/58 .../Block and Mute Respecting Platform Rules.md`, `LF/26 .../Discord Servers for Roblox Games.md`

### Money, the kid-safe way
44. Sell scale, speed, convenience and looks, never wins.
    - Use a ladder of 3–5 price steps per category, each step better value per Robux, plus one impulse step under 100.
    - Show prices live with `GetProductInfoAsync`.
    - Every random paid thing shows numeric odds summing to 100%, live odds while boosted, and a pity counter.
    - Check `PolicyService` on the server and fail closed.

    Sources: `LF/11 .../Robux Price Points and Offer Design.md`, `LF/11 .../Paid Random Items and Odds Disclosure in Practice.md`, `LF/32 .../Case Study - Brookhaven RP.md`, `CLAUDE.md` Never list.

---

## 2. Genre quick blueprints

Each blueprint has the loop, the systems, a five-minute script, return hooks and kid-safe money. **Our start:** always `new-game-kit/` plus the matching `BP/Blueprint - *.md` if one exists.

### 2.1 +1 / launch simulators (train a stat, launch or throw for distance)
- **Our start:** `BP/Blueprint - Plus One Evolution.md`, `BP/Blueprint - Plus One Speed Escape.md`, `BP/Teardown - Stone Skipping.md`, `BP/12` pacing table. This genre is our strongest; LihFolk adds the checks below.
- **Loop:** train (the number ticks up every second) → launch/run → distance pays cash → buy upgrades → zone walls → rebirth.
- **Key systems:** a stat owned by the server and earned from real movement (never one the client reports), a level multiplier, zones every 1–2 rebirths, rebirth, eggs/pets, offline earnings, a cosmetic trail ladder.
- **First 5 minutes:** the counter grows inside 5 s → first launch ≤ 30 s → first buy ~60 s → first rebirth ≤ 90 s (ends the tutorial) → free egg from a playtime gift ≤ 3 min. (`BP/12` §3.)
- **LihFolk checks:** does the counter visibly grow in the first 5 s? Does more stat change how the course plays (the +1 Speed twist: more speed makes the obby harder)? Use thicker, simpler collision at high speed. `LF/59 .../Teardown - +1 Speed Keyboard Escape.md`
- **Retention hooks:** worlds, rebirth unlocks, offline earnings, weekly world or cosmetic drops, a leaderboard for distance.
- **Kid-safe money:** a cosmetic trail/aura ladder from tiny to premium (Keyboard Escape spans 19–2,999 R$), 2× cash, auto-train, extra pet slots, and a plain top-tier gamepass with the loudest look (never "VIP"). Eggs follow the odds and pity rules.

### 2.2 Tycoon / business evolution
- **Our start:** `business-evolution/`, `new-game-kit/src/Server/Income.luau`. **No tycoon blueprint in BP yet** (see §4).
- **Loop:** claim a plot → buy a button → income ticks → buy the next button → stage reveal → rebirth/new stage.
- **Key systems:**
  - The button chain is data (cost, income, requires, model).
  - 1–3 buttons visible at once, placed next to the last build.
  - Alternate income and spectacle buttons.
  - End each stage on a big reveal.
  - Server income tick; drops are client-only visuals; a fast rebuild on rejoin.
  - Sources: `LF/10 .../Genre Playbook - Tycoons.md` §2–5; `LF/43 Genre Systems End to End/Tycoon Plots and Droppers End to End.md`.
- **Payback:** early buttons pay back in 10–60 s. Plot the wait per button, and hide price spikes behind spectacle buttons. `LF/10 .../Genre Playbook - Tycoons.md` §3
- **First 5 minutes:**

  | When | What happens |
  |---|---|
  | 0–10 s | The plot is auto-assigned and you face it |
  | 10–20 s | The first button is free and builds a dropper |
  | 20–60 s | Income visible as a rate, with the next button's price shown |
  | 1–3 min | First wall or floor reveal |
  | 3–5 min | A branch choice (garden or garage) |

- **Retention hooks:**
  - offline earnings shown on return;
  - visits: plots are visible to each other, so the neighbour's build acts as an advert;
  - co-op plots and gifting an upgrade to a friend;
  - rebirth that keeps cosmetics;
  - decoration mode;
  - leaderboards for things players control.

  Source: `LF/10 .../Genre Playbook - Tycoons.md` §6–7.
- **Kid-safe money:** an income-multiplier pass priced in minutes saved, auto-collect, cosmetic droppers and themes, and extra plot themes.
  - Never make the free pace painful so that "skip" sells: that is the genre's main ethical risk.
  - Raids, if any, are opt-in, followed by a shield, and only cost temporary resources.

### 2.3 Pet / egg collection simulators
- **Our start:** `BP/Blueprint - Egg Run.md`, kit `EggHatch.luau` + `Pets.luau`.
- **Loop:** break/collect → coins → hatch → equip the best → next area → rebirth (unlocks features) → trade later.
- **Key systems:**
  - Eggs per zone, 5–9 rarity tiers, 3–6 equip slots.
  - Fuse duplicates, an index with completion rewards, and an auto-delete-by-rarity option.
  - Pet multipliers count inside the multiplier caps.
  - Sources: `LF/10 .../Genre Playbook - Simulators.md` §6; `LF/24 Worked Builds/Pet Hatching and Following End to End.md`.
- **First 5 minutes** (Pet Simulator 99 shape, `LF/32 .../Case Study - Pet Simulator 99.md`):
  1. Starter pets swarm the breakables and coins fly within 10 s.
  2. First egg bought and auto-equipped within 1–2 min.
  3. First area gate.
  4. Quest arrows with 2 goals at a time.
  5. Cheap premium-currency upgrades.
- **Bee Swarm check:** the first gather-convert-spend loop finishes inside a minute, and depth is staged with quest arrows. `LF/59 .../Teardown - Bee Swarm Simulator.md`
- **Retention hooks:**
  - one long-term currency, plus a coin per world (a soft reset without loss);
  - rank goals that fill a reward track;
  - huge or rare pet chases from events;
  - trading opens only after a progress milestone (first rebirth or about 30 min of play);
  - a weekly update on a fixed day;
  - a "Potato Mode" setting for cheap phones.
- **Kid-safe money:** extra equip/storage slots, 2× coins, auto-hatch, a faster hatch animation, and a plain top-tier pass.
  - Paid eggs, and eggs bought with a currency Robux can buy, are paid random items: odds summing to 100%, live odds under boosts, pity shown, `PolicyService` fail-closed.
  - Trades are blocked for players whose policy disallows paid-item trading.

### 2.4 Anime fighting / battlegrounds
- **Our start:** none in BP (only VFX in `BP/15`, `BP/16`). Main sources:
  - `LF/10 .../Genre Playbook - Battlegrounds and Arena Fighters.md`
  - `LF/32 .../Case Study - The Strongest Battlegrounds.md`
  - `LF/60 High-Craft Game Teardowns/Teardown - Jujutsu Shenanigans.md`
  - `LF/24 Worked Builds/Melee Combat System End to End.md`
- **Loop:** exchange (1–5 s: approach, M1 chain or ability, block or dodge, punish) → fight (10–60 s) → session of many fights, swaps and streaks → meta (unlock characters, emotes, mastery).
- **The combat grammar players already know:**
  - 4-hit M1 chain, the last hit knocks back;
  - hold block with guard break;
  - dash on a 1.5–3 s cooldown;
  - 4 moves per kit on 5–25 s cooldowns (starter, mobility, counter, finisher);
  - an ultimate **earned in combat**, lasting 30–60 s;
  - a counter;
  - ragdoll.
- **Fairness rules:**
  - same base stats for everyone; kits differ;
  - hitstun decays, with a 3–4 s cap on any combo;
  - 0.5–1 s invulnerability on getting up;
  - a combo breaker on a long cooldown;
  - one wall bounce and one ground bounce per combo;
  - 100–200 ms input buffer.
- **Server shape:** 10–20 players (TSB uses 15), respawn in 2–5 s with a 2 s shield, multiple spawns.
- **First 5 minutes:**
  1. Pick a character in seconds.
  2. A training dummy with an input display sits by spawn.
  3. Land a combo in minute one.
  4. Walk into the arena.
  5. The first ultimate charges within the first few fights.
  6. Bounties on top-streak players draw fire away from newcomers.
- **Mobile is half the game:**
  - big buttons, with the basic attack under the right thumb;
  - soft auto-target in front of the player;
  - shift-lock on by default for touch;
  - no combo that needs two presses at once.
- **Retention hooks:**
  - a new character every 2–4 weeks with a free unlock path;
  - mastery per character;
  - kill streaks and a daily challenge per character;
  - private servers.
- **Kid-safe money:** emotes, kill effects, skins for moves, extra emote slots, and private servers.
  - **Never stat boosts or damage passes.**
  - Characters sold for Robux also unlock by playtime.
  - Random emote spins state their odds plainly (TSB writes "equal chance, no duplicates" in its description).
  - Let players mute other players' emotes and effects.
- **Never copy an anime's names, likenesses or move names.**

### 2.5 Tower defense
- **Our start:** none in BP. Main sources:
  - `LF/10 .../Genre Playbook - Tower Defense.md`
  - `LF/43 .../Tower Defense Waves and Placement End to End.md`
  - `LF/32 .../Case Study - Tower Defense Simulator.md`
  - `LF/60 .../Teardown - Anime Vanguards.md`
- **Two loops:**
  - The match (15–40 min): place, upgrade, sell, use abilities; kills pay match cash.
  - The meta (days): summon, upgrade, evolve, trait-roll, loadout.
- **The core sum:** required path DPS = the wave's total health ÷ the time the wave spends inside your coverage. Keep one sheet of this per wave.
- **Key systems:**
  - enemies run as data on paths, drawn by the client (no Humanoids);
  - batched spawn and death events;
  - more players raise enemy **health**, not enemy count;
  - placement snaps, previews and confirms, and the server validates cash, caps, bounds, footprint, surface and NaN;
  - 2× speed built in on the server (simulation time scale);
  - partial rewards per wave cleared, so leaving early is safe on phones;
  - a lobby place plus match places with group teleports.
- **Mode lengths:** story 10–20 min, challenge 8–15, raid 15–25, endless 30–90.
- **First 5 minutes:**

  | When | What happens |
  |---|---|
  | 0–60 s | A guided first summon gives a team you love |
  | 1 min | A pointer shows a strong first placement |
  | Wave 1 | Cannot be lost |
  | Before wave 3 | One upgrade |
  | After the win | Rewards, then back to the lobby |

  Stats and synergies come later, as tips.
- **Retention hooks:** a weekly new map or mode, a banner rotation, unit evolution, a daily challenge mode, an endless leaderboard showing the loadout, and rare units shown off in the lobby.
- **Kid-safe money:**
  - Every story map is beatable with free units (test it).
  - Paid units are side-grades or niche.
  - Sell extra loadout or storage slots and cosmetic unit skins.
  - Give 2× speed free; 3× may be a pass.
  - Summons follow the paid-random rules with a **visible pity counter**.

### 2.6 Obby
- **Our start:** `BP/Blueprint - Plus One Speed Escape.md` (the +1 obby). Main sources:
  - `LF/10 .../Genre Playbook - Obbies and Platformers.md`
  - `LF/33 Level Design/Obby and Platforming Level Design.md`
  - `LF/43 .../Obby Checkpoints and Stage Saves End to End.md`
  - `LF/59 .../Teardown - Tower of Hell.md`
- **Loop:** jump → checkpoint → next stage → difficulty band badge → (tower variant: a timed random tower that resets).
- **Key systems:**
  - Write the jump mode (height or power) down and compute a reach table.
  - Each stage raises one dial.
  - Sawtooth difficulty with breather stages.
  - Stage lengths: early 5–15 s, mid 15–40 s, late 30–90 s.
  - A checkpoint wherever failing would replay more than ~1 min, or more than 5–6 jumps.
  - One consistent look for kill bricks.
  - Save stages by stable id, not by number.
  - Finishes are checked on the server.
- **First 5 minutes:**
  1. No text about jumping.
  2. The first jumps fail cheaply, and the first checkpoint comes within ~20 s.
  3. The first section clears on the first try.
  4. Each new obstacle gets show, try, test.
  5. A visible band name ("Easy → Medium") lands by minute 3–5.
- **Retention hooks:** badges per band, hidden collectibles off the main path, a daily challenge stage, co-op stages, and movement abilities unlocked by progress.
- **Kid-safe money:** cosmetics (trails, hats), a fair skip-stage product, and coils kept off the leaderboards.
  - **Never tune a stage to be unfair so that skips sell.**
  - Lock the shop in private servers for pure runs.

### 2.7 RNG / aura games
- **Our start:** `BP/Blueprint - Roll and Place RNG.md`. Main sources:
  - `LF/10 .../Genre Playbook - RNG and Collection Games.md`
  - `LF/59 .../Teardown - Sol's RNG.md`
  - `LF/48 .../Drop Tables Rarity and Pity Systems.md`
- **Loop:** roll → aura ("1 in N") → keep or equip → craft gear from auras → gear raises luck or speed → biomes rotate on server time and change the odds.
- **Key systems:**
  - Roll on the server only.
  - **One table feeds both the roll and the odds UI** (flattened to final outcomes).
  - Define luck in writing: which tiers it affects, how it stacks and its cap.
  - Rollable tiers are capped by progress.
  - Pity, or tokens/sparks.
  - One colour per tier, used everywhere.
  - Rarer must look better: every Legendary and above is animated.
  - The next tier's odds are shown before the player reaches it.
- **First 5 minutes:**
  1. The Roll button is the first thing on screen; the first roll comes within 5 s.
  2. Even a common result gets a big "1 in N" moment.
  3. Auto/quick roll appears soon.
  4. A biome change sweeps the server within minutes and teaches that the world affects luck.
- **Retention hooks:**
  - biome rotation works as a built-in calendar;
  - a months-long top-tier chase;
  - crafting gives duplicates a use;
  - seasons;
  - free private servers (they count as co-play);
  - server-wide announcements of rare rolls.
- **Kid-safe money:**
  - Direct-buy cosmetics are the cleanest product; speed passes come second.
  - Luck products need a numeric effect, live odds and modest size.
  - A server luck boost that helps everyone is fine with a real countdown from server time.
  - Treat quick-roll as in scope for odds disclosure.
  - **No near-miss reels** (see §5).

---

## 3. Symptoms → fixes

| What you see | Likely cause | Fix | Source |
|---|---|---|---|
| Few impressions on Home | Default thumbnail (not eligible since 2026-10-19), no maturity label, or not yet tested by recommendations | Upload 2–5 honest custom thumbnails, finish the questionnaire, and run a small ads test to get a sample | `LF/27 .../Rescuing a Weak Launch...md` Step 1; `LF/49 .../Discovery and Monetization Changes 2025-2026.md` |
| Impressions but few clicks (low CTR) | Icon or thumbnail unreadable at phone size; title doesn't say the verb; looks like a copy | One subject at 30–45% of the frame, greyscale test, title = brand + verb, one visible twist. A/B test for 7–14 days | `LF/61 .../Thumbnail Composition...md`; `LF/61 .../Thumbnail and Icon A-B Testing...md` |
| Players quit in the first minute | Slow join, a text wall, pop-ups, no reward before 60 s, broken on phones | Measure join time on a mid phone, cap loading at ~12 s with a skip, first verb ≤ 10 s, first reward ≤ 60 s, no modal in minute one | `LF/27 .../Rescuing a Weak Launch...md` Step 4; `LF/58 .../Loading Screen Skip and First-Session Goals.md` |
| Big drop at one tutorial step | A step that can fail (combat, or can't afford it) | Top up to the price; a weak enemy owned by the player; log each step on the server | `LF/11 .../Measuring Onboarding - Funnels, Drop-off and A-B Tests.md`; `LF/10 .../First-Time User Experience and Onboarding.md` |
| Short sessions | The loop is invisible ("what do I do?") or the first wall comes too early | One next-goal tracker always on screen; reprice the wall in minutes of income; add a second way past it | `LF/10 .../Core Loops and Session Design.md` §7 |
| Good first session, low D1 | No exit hook or reason to return | Offline earnings shown on return, a daily calendar (missing a day pauses the streak), a gift ready in a few minutes, a quest at 2/3 | `LF/10 .../Retention and Return Hooks.md` |
| Good D1, collapsing D7 / D8–28 | Only a short loop; content runs out | A long loop: rebirth with unlocks, collections or an index, a weekly update, events | `LF/10 .../Core Loops and Session Design.md` §7; `LF/10 .../Genre Playbook - Simulators.md` §10 |
| Players stop at zone 3–5 | Zone price outruns income; nothing new to push for | Reprice in minutes of income; a visible reward per zone | `LF/10 .../Genre Playbook - Simulators.md` §10 |
| Economy inflation (balances pile up, nothing to buy) | Unmodelled faucet; uncapped multiplicative stacking | Add a top-end repeatable sink, raise prices of **new** content only, put multipliers in category caps; never touch paid value | `LF/11 .../Economy Inflation Sinks and Faucets Math.md` §8 |
| Late-game numbers mean nothing | Multipliers multiply without caps | Additive buckets per category, a written payer gap, one breakdown tooltip | `LF/11 .../Economy Inflation Sinks and Faucets Math.md` §2 |
| Low CCU, servers feel empty | Server size too big for the traffic; too many places or zones | Max server 8–12 while small, fill servers fully, collapse to one place, add an activity feed and shared events | `LF/27 .../Rescuing a Weak Launch...md` Step 3 |
| Servers full of idle avatars | AFK pays too much | AFK pays less than active play, capped, and only after onboarding; AFK spots go in the hub | `LF/58 .../AFK Detection Idle Kicks and AFK Reward Rules.md` |
| "Grind", "homework", "lost my streak" in comments | Hooks became chores | Merge claim screens, verb quests instead of presence quests, a grace day for streaks | `LF/10 .../Retention and Return Hooks.md` §9 |
| Complaints about eggs or rolls | Odds unclear, base odds shown while boosted, long dry streaks | Odds from the roll table, live odds under boosts, a visible pity counter, honest animation | `LF/11 .../Paid Random Items and Odds Disclosure in Practice.md` |
| "I paid and got nothing" | No processing state; granted before save; client-side grant | Processing → granted → receipt UI; grant in ProcessReceipt only, save first | `LF/58 .../Purchase Receipts and Purchase History in UI.md` |
| New players quit after being robbed or comboed | No newcomer protection | Grace window, theft limits, spawn shield, combo breaker, bounties on top players | `LF/32 .../Case Study - Steal a Brainrot.md`; `LF/10 .../Genre Playbook - Battlegrounds and Arena Fighters.md` §2 |
| Lag in big waves or fights on phones | Humanoid enemies, VFX counts that don't scale | Enemies as data, one VFX density scale, Low/Med/High presets (gameplay VFX exempt) | `LF/10 .../Genre Playbook - Tower Defense.md` §5; `LF/58 .../Graphics and Performance Toggles for Low-End Devices.md` |
| Update day breaks the game | Publish and go-live at the same moment | Publish first, gate content by server time, feature freeze 10 days out | `LF/27 .../Update Cadence and Hype Cycles.md`; `LF/38 .../Feature Flags and Staged Rollouts.md` |
| Ad players have bad D1 | The ad over-promises | Show the real loop in the creative; check onboarding for ad cohorts | `LF/27 .../Sponsored Ads and Campaign Math.md` |
| Everything mediocre after 2–3 fix rounds | Weak concept | Archive it; reuse the systems in a new concept | `LF/27 .../Rescuing a Weak Launch...md` Step 5 |

---

## 4. Gaps: what our Build Playbooks lack (ranked)

Ranked by how often we'd hit them in the games we make. "Promote" means: write a short BP playbook or blueprint from these notes, checked against §5.

1. **Tower defense blueprint.** BP has nothing on it (0 mentions). Promote:
   - `LF/10 .../Genre Playbook - Tower Defense.md`
   - `LF/43 .../Tower Defense Waves and Placement End to End.md`
   - `LF/32 .../Case Study - Tower Defense Simulator.md`
   - `LF/60 .../Teardown - Anime Vanguards.md`
2. **Anime battlegrounds game design** (BP has the VFX only). Promote:
   - `LF/10 .../Genre Playbook - Battlegrounds and Arena Fighters.md`
   - `LF/32 .../Case Study - The Strongest Battlegrounds.md`
   - `LF/60 .../Teardown - Jujutsu Shenanigans.md`
   - `LF/24 .../Melee Combat System End to End.md`
   - `LF/09 Gameplay Systems/Combat Systems Architecture.md`
3. **Economy guard-rails.** There is no time-to-afford band table, no written payer-gap cap, no currency-job rule and no inflation fix-ladder (`BP/12` has formulas only). Promote:
   - `LF/11 .../Economy Inflation Sinks and Faucets Math.md`
   - `LF/48 .../Currency Architecture - Soft Hard and Event Currencies.md`
   - `LF/48 .../Simulating an Economy Before Launch.md`
   - `LF/48 .../Pricing Curves and Upgrade Costs.md`
4. **Tycoon blueprint**, for `business-evolution/`. Promote:
   - `LF/10 .../Genre Playbook - Tycoons.md` (button chain, payback, social)
   - `LF/43 .../Tycoon Plots and Droppers End to End.md`
5. **Session arc and pop-up gate.** The timing rules for return visits are missing. Promote:
   - `LF/10 .../Core Loops and Session Design.md` §5–6
   - `LF/10 .../Retention and Return Hooks.md` §9
   - `LF/58 .../Notification Queues and Limits.md`
6. **Launch diagnosis and rescue.** BP has a checklist but no "what to do when numbers are bad". Promote:
   - `LF/27 .../Rescuing a Weak Launch...md`
   - `LF/61 .../From CTR to CCU...md`
   - `LF/11 .../Analytics and Funnels.md`
   - `LF/11 .../Measuring Onboarding - Funnels, Drop-off and A-B Tests.md`
7. **Settings, QoL and accessibility pack for kids.** This means music and SFX sliders, shake slider, flash toggle, text size, colour-blind second channel, graphics presets and rejoin. BP mentions it in 2 files. Promote:
   - `LF/58 .../Top 25 QoL Wins by Effort.md`
   - `LF/58 .../Settings Menu Essentials and Persistence.md`
   - `LF/42 .../Colour-Blind Safe Design.md`
   - `LF/42 .../Readable Text and UI Scale.md`
   - `LF/58 .../Graphics and Performance Toggles for Low-End Devices.md`
8. **Live ops calendar and patch notes.** BP says "weekly update" but has no calendar method, no What's New panel and no rollout flags. Promote:
   - `LF/38 .../Event Calendars and Content Planning.md`
   - `LF/38 .../Patch Notes and Player Communication.md`
   - `LF/38 .../Feature Flags and Staged Rollouts.md`
   - `LF/27 .../Update Cadence and Hype Cycles.md`
9. **Thumbnail craft and A/B method.** BP points to the hub only. Promote:
   - `LF/61 .../Thumbnail Composition...md`
   - `LF/61 .../Making Thumbnails in Studio and Blender...md`
   - `LF/61 .../Thumbnail Review Checklist and Scoring Rubric.md`
   - `LF/61 .../Thumbnail and Icon A-B Testing...md`
   - `LF/27 .../Game Icon Design - Readable at Small Sizes.md`
10. **Social ladder and low-density design.** Promote:
    - `LF/10 .../Social Design and Multiplayer Play.md`
    - `LF/49 .../Friend Invites Referrals and Experience Invites.md`
    - `LF/48 .../Player-Driven Trading Economies.md`
    - `LF/58 .../Block and Mute Respecting Platform Rules.md`
11. **Level design teaching and hub flow.** `BP/10` covers layout and theme; this adds teaching spaces and hub timing. Promote:
    - `LF/33 Level Design/Teaching Through Level Design.md`
    - `LF/33 .../Lobby and Hub Design.md`
    - `LF/33 .../Level Design Principles - Flow Sightlines and Landmarks.md`
    - `LF/06 .../Zone and Biome Art Direction.md`
12. **Community, creators and moderation.** Promote:
    - `LF/26 .../Player Reports and In-Game Moderation.md`
    - `LF/26 .../Working with Content Creators.md`
    - `LF/27 .../Marketing to Kids and Teens - Age Rules and Paid-Promo Disclosure.md`
    - `LF/26 .../Discord Servers for Roblox Games.md`
13. **Naming and writing.** Promote:
    - `LF/36 .../Naming Items Zones and Abilities.md` (name shape per tier, edit-distance check)
    - `LF/36 .../Quest Writing and Hooks.md` (objective = verb, count, target, place, under 40 characters)
    - `LF/36 .../Writing Dialogue for Roblox Players.md` (18 words per screen)
14. **Obby stage-design numbers** (lower priority; we have the +1 obby blueprint). Promote:
    - `LF/33 .../Obby and Platforming Level Design.md` (reach table, one dial per stage)
    - `LF/43 .../Obby Checkpoints and Stage Saves End to End.md`

---

## 5. Conflicts with house rules (ours win)

| LihFolk says | Where | Our rule | What we do |
|---|---|---|---|
| Flash limiter of **3 per second** | `LF/58 .../Comfort Toggles - Flashes Damage Numbers and Hit-Stop.md`; `LF/58 .../Top 25 QoL Wins by Effort.md` #5 | **At most 1 flash per second** (`CLAUDE.md`) | Cap at 1/s; keep their flash toggle and the replacement feedback idea |
| Passes named **"VIP"** (VIP 399 R$ bundles; "12 h with VIP" offline cap; VIP in the TD, sim and RNG tables) | `LF/10 .../Genre Playbook - Simulators.md` §8; `LF/10 .../Genre Playbook - RNG and Collection Games.md` §10; `LF/10 .../Genre Playbook - Tower Defense.md` §6; `LF/10 .../Core Loops and Session Design.md` §6 | **No VIP branding anywhere** (`BP/09`, Oct 31) | A plain top-tier gamepass with the best look and a real benefit |
| Real limited offers are fine: "only 500 ever" stock counters, starter packs that vanish 3 days after first view, "never returns" exclusives, weekly rotating direct-buy exclusives, shared timed stock with a countdown (Blox Fruits), "retired items" (Adopt Me) | `LF/38 .../Limited-Time Offers - Design and Ethics.md`; `LF/10 .../Genre Playbook - RNG and Collection Games.md` §10; `LF/32 .../Case Study - Blox Fruits.md`; `LF/32 .../Case Study - Adopt Me.md` | **No fake timers, scarcity or stock**; kid-focused | Stricter: **no stock counts, no personal offer timers, no "never returns" claims** for Robux items. Event items may have the event's real end date and are labelled "seasonal, may return". Rotating shops only for earned-currency items, with a calm display of the real rotation time |
| Pity is one option among several; "recommended" | `LF/10 .../Genre Playbook - RNG and Collection Games.md` §5 | **Paid random items always show odds and a pity counter** | Pity is mandatory on every paid random item, shown as a counter ("Legendary guaranteed in 37") |
| Near-miss reels allowed on free rolls (capped by progress) | `LF/10 .../Genre Playbook - RNG and Collection Games.md` §6 | Kid-safe spirit (no manipulation) | Our call: **no near-miss presentation at all** in kid games; reels only replay the real server result |
| Offline vault pays 15%/min, capped at 8 h | `LF/10 .../Core Loops and Session Design.md` §6 | `BP/12`: 25–50% of the online rate, cap 8–12 h | Use `BP/12` numbers (owner-tuned); LihFolk's lower rate is a fallback if offline earnings start replacing play |
| Group perk example uses `player:IsInGroup` (our own research note) | `research_notes/Roblox animation and VFX deep dive/everything_else_hits_do.md` §3 | LihFolk is right here | Use `IsInGroupAsync` in `pcall`, on the server, cached. `GROUP_ID` stays 0 until the owner gives it |
| "Qualified play-through rate (qPTR)" used as the CTR metric | `LF/27 .../Rescuing a Weak Launch...md`; `LF/61 .../From CTR to CCU...md` | `BP/02` (verified 2026-10-30): "play-through rate"; LihFolk's own `Discovery and Monetization Changes 2025-2026.md` says qPTR no longer exists | Read it as play-through rate from Recommended For You |
| Tap targets at least 44 px drawn | `LF/05 .../Responsive UI...md`; `LF/21 LihFolk UI Design System/LihFolk UI Spec.md` | Owner wants **small, premium buttons** (`BP/09`) | Not a true conflict: keep the art small but the **hit area** at 44 px or more on phones (phones keep near full size per `BP/09`) |
| Early Access pass (play new characters first) in PvP | `LF/32 .../Case Study - The Strongest Battlegrounds.md` | "Never sell something that gives nothing yet" is fine; fairness in a kid PvP game is our call | Only if the early character is not stronger than free ones, and the window is short and stated |
| Rewarded video ads as income | `LF/11 .../Ads and Rewarded Video.md` | Kid audience | Plan without them: they reach only 13+ players and need eligibility. Never put an ad on a reward a younger kid needs |

**Agreed with house rules, no change needed:**
- grant purchases only in ProcessReceipt, save first;
- prices from `GetProductInfoAsync`;
- odds from the roll table and summing to 100%;
- `PolicyService` fail-closed;
- no rewards for likes or favourites, and no group-join prompts on join or during the tutorial;
- no Discord links in game;
- never invent IDs (LihFolk: "no id 0 left visible as purchasable", which matches our "coming soon" rule).
