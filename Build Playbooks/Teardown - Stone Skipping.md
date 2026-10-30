---
tags: [build-playbooks, teardown, stone-skipping, plus-one, reference]
updated: 2026-10-30
---

# Teardown - +1 Stone Skipping

Back to [[00 Build Router]] · What to take from it: [[07 Borrow List - Game by Game]] · How to beat it: [[06 Beat the Hits - Polish Playbook]]

**The reference for [[Blueprint - Plus One Evolution]] and +1 Cannon Evolution.** Meow Labs, place 111543903102439, created Sep 2026. About 70.9M visits, 2.2M favourites and 14.4K playing at the end of October (bloxodes wiki listing).

**Where the facts come from:**
- **[M]** I measured it from the owner's recordings, sampled at 2 frames a second:
  - `cannon-evolution/references/recording-2.mp4`: a new player's first 93 s, landscape phone;
  - `recording-1.mp4`: a phone in portrait;
  - two PC recordings from Oct 30 (lobby, shop, playtime gifts, inventory, titles). These live in the project's files, not in the repo.
- **[W]** fan wikis: allthings.how, 1-stone-skipping.wiki, stoneskipping.wiki, bloxodes, nerdschalk. They can be out of date.
- **[I]** my own reading.

## 1. The loop in one line
Each bounce gives **+1 Skill**. Skill raises your Level, and the Level raises a global **Multiplier**. A longer throw reaches farther zones and pays more **Wins**. Wins buy stones, eggs and relics. **Rebirth** resets Level and Skill but raises the cap and unlocks stronger training pads. [W]

## 2. The first 90 seconds (measured from recording-2) [M]
| Time | What happens |
|---|---|
| 0–15 s | Intro cutscene with a **Skip** button. The guide waves in the lobby. The camera flies low along the river, through each zone (beach, then snow), so you see the whole track before you play. |
| ~15–25 s | Guide dialogue in plain subtitles: "My first throw? It barely reached the water." Then "Your turn. Start here." The camera pans over the training pads. |
| ~25–40 s | Quest bar, top centre, yellow: train Skill, then **GET 2 WINS (0/2)**. |
| ~40–48 s | First throw (section 3). "+1 🏆" over your head, and the bar ticks to 1/2. |
| ~50–60 s | **EQUIP A NEW STONE.** Stones sit on pedestals, each with a billboard: UNLOCKED +1 Skill 0 Wins, +3 Skill 2 Wins, LOCKED +5 Skill 10 Wins. A chain of **white chevron arrows** floats straight to the target. A "NEW STONE! Scallop Shell" toast pops up. |
| ~60–75 s | **REACH LEVEL 20.** Stand on a training pad ("UNLOCKED 1x SKILL" over it). The level bar fills fast. |
| ~78–84 s | **REBIRTH NOW.** The screen dims, and the Rebirth button glows at 100%. A Before → After panel opens with a big green Rebirth button and a small "Skip Rebirth". |
| ~85 s | **TUTORIAL COMPLETE!** on a sunburst: "Rebirth #1, ×2 SKILL, Tap to continue". Then confetti and a new feature unlocks with a NEW! tag (**SKIP RUSH**). |
| ~88 s | **Daily Rewards** opens: 7 days, with day 7 a "Limited Shooting Star Relic". "CLAIM YOUR REWARD". |

**Benchmark:** the tutorial ends with a first rebirth about **70 s after the cutscene**. An earlier Cannon Evolution build took about 7 minutes (build notes); `GameConfig.lua` now sets `REBIRTH_POWER_BASE = 100`, aimed at about 1.5 min of training. Time it from join on a fresh save.

## 3. One throw, frame by frame [M]
- **Trigger:** stand in the **THROW ZONE**, a yellow studded dock with giant painted letters. A green **THROW** button pops up just above your character. Auto Throw is a pass.
- **Camera:** within about 0.5 s it cuts to a **chase camera low behind the stone**:
  - the horizon sits about one third from the top;
  - water fills the bottom two thirds;
  - no shake, no zoom pulse, no slow motion.
- **Counter:** big yellow outlined **"0 m"** at the top centre. The zone name sits small in cyan under it and grows big beside the counter when you enter the zone ("Palm Beach").
- **Pace** (a level 4 player): 25 → 60 → 93 → 126 → 156 → 186 → 211 → 220 m in 0.5 s steps:
  - about 60–65 m/s, nearly constant;
  - it only slows in the last second;
  - the whole throw is about **4.5 s**.
- **Each bounce:** a small white splash. The Skill in the HUD ticks +1, the level bar fills, and "Level Up!" flashes small beside it.
- **End:** a hard cut straight back to you in the Throw Zone. "+1 🏆" floats over your head, trophies fly to the Wins counter, and the quest bar ticks. The next THROW button shows about 1 s later.
- **Rare throws** [W]:
  - a **Secret Throw** (~1 in 100: extreme speed, big Wins boost);
  - a **Colossus Throw** (~1 in 1,000).
  
  They can't be forced, and multipliers stack on them.

## 4. HUD layout (PC, late game) [M]
| Where | What |
|---|---|
| Top centre | **AUTO THROW, only R$25** (red), then the event currency pill (Halloween 812). Under it, **one message line**: a trophy icon and "Claimed +13.4K SKILL!", replaced by each new event. |
| Top centre (tutorial) | Quest bar: "REACH LEVEL 20 (6/20)" |
| Left | A wide **Shop** button, then a 2×3 grid: Auras, Rebirth (shows **94%** progress), Pets, Trails, Inventory, Gifts. Red "!" badges mark anything to claim. |
| Left, low | Pet/egg count, then **Wins** (big gold trophy, 4.76K), then "Friend Boost +0%" with a green + (invite) |
| Bottom centre | "⚡3.52M SKILL" on the left and "×15.5 Multiplier" on the right, over a blue **Level 94 bar (343.1K / 383.68K)**. Under it, three Skill packs: **+1M R$25 (yellow), +10M R$95 (red), +100M R$185 (rainbow)**. |
| Right | "+2x SKILL" and "2x WINS" pass offers (green and gold), the Starter Pack icon, and the event quest with a timer ("King break his lanterns 1m47s") |
| World | A rainbow **CLAIM** chest (join the group / like the game), rebirth signs, a waterfall portal, and egg stands with prices |
| Phone | The same layout, smaller, plus the jump button bottom right. Portrait works too (recording-1). |

## 5. Shop: one scrolling page, sections in this order [M]
1. **~ Pack ~:** Starter Pack R$39 (shown against a crossed-out 199), with the pet, x30 and x10K boosts and +1 slot. Demon Pack R$299 (against 799).
2. **~ Limited Offer ~:** Admin Egg with its odds on the card (40/34/20/5/1%). Buy 1 for 175, 3 for 459, 8 for 1,149.
3. **~ Auras ~:** paid rolls, "Up to ×2.5 Wins and ×2 Skill". Odds per aura on the card (Haunted 1 in 112, Jackpot 1 in 673, Cosmos 1 in 224). Get Rolls button.
4. **~ Gamepasses ~:**

   | Pass | Price |
   |---|---|
   | +1 Pet Slot | R$69 |
   | +3 Pet Slots | R$195 |
   | +6 Pet Slots | R$499 |
   | Auto Win | R$25 |
   | Auto Rebirth | R$149 |
   | Admin Zone (50x Skill pad) | R$599 |
   | Koi Zone (3x) | R$99 |
   | Golden Zone (15x) | R$249 |

5. **~ Boosts ~:** Boost Bundle R$95 (2 Win and 2 Skill boosts), Skill Boost 2x for 10 min R$29, Win Boost R$29.
6. **~ Wins Pack ~:**

   | Pack | Wins | Price |
   |---|---|---|
   | Tiny | 10K | R$25 |
   | Small | 50K | R$59 |
   | Medium | 200K | R$115 |
   | Large | 500K | R$229 |
   | Mega (first-time discount) | 1M | R$459 |

7. **~ Codes ~:** a redeem box at the bottom.

Card style: each card is a coloured panel with a big icon on the left, the title, a short benefit line, and a green price pill. Headers are plain "~ Section ~" text on a dark see-through panel. The world behind is blurred.

> [!warning] Don't copy these two
> - **Crossed-out "was" prices** and **"Limited Offer"** break our kid-safe rule (no fake scarcity, see `CLAUDE.md`).
> - A **real** first-purchase discount that really happens once is fine.
>
> Copy the layout, not the pressure tricks.

## 6. Retention systems seen [M]
- **Playtime Rewards:** a 4×3 grid, with rows tinted blue, then purple, then gold by value.
  - Rewards: Skill, Wins, Common Egg, Skill Boost, Uncommon Egg, Win Boost, Luck Boost, Rare Egg.
  - Claimed tiles turn into a big green tick. When all 12 are claimed, every tile shows a **04:00:00** timer.
  - Each claim shows "Claimed +625 WINS!" in the top message line.
- **Daily Rewards:** 7 days, with day 7 the special one.
- **Inventory:** one panel with left tabs: **Stones · Pets · Eggs · Items · Titles**.
  - **Eggs:** unopened eggs from rewards wait here.
  - **Items:** boosts as tiles, "click a boost to use".
  - **Pets:**
    - shows 2/200 owned and Equipped 2/3 (with a + for more slots);
    - a detail card with Lock Pet and Unequip;
    - **Index**, **Equip Best** and a delete button.
- **Titles = achievements:** 1/32 owned. Each one is a goal with a perk ("Skipper: Land 1K ricochets, +5% Skill"; others include Pebble Tosser, Lucky Shot, Hatchling, Familiar Face, Pet Spotter, Stone Slinger, Secret Seeker, Colossus, Master of Time). The equipped title floats over your head in the lobby.
- **Friend Boost:** a % bonus for friends in the server.
- **Group/like chest:** the rainbow CLAIM in the lobby.
- **Events:** a Halloween currency and quests on timers, plus weekly world updates (World 3 to 8 so far) [W].
- **Skip Rush** (Oct 24 update) [W]: a mini-game opened from a training pad. Throw with a **power meter**, collect coins while skipping, then see a results screen (skips, distance, pickups, best). Coins buy upgrades, distance unlocks new skippers, and it has missions and a **weekly leaderboard**.

## 7. Numbers [W]
- **Training pads:** World 1 gives 1x, 4x, 10x and 20x at 0, 2, 4 and 6 rebirths. Later worlds start at 50x and go up to 1,000,000x (Dragon Volcano, 375 rebirths).
- **Worlds:** 5 worlds of 9 territories each, with portals at 100M, 400B, 15Qa and 500Qi Skill.
- **Level multiplier:** ×1.1 at level 6, up to ×111 at level 115.
- **Eggs and pets:** eggs cost 70, 185 and 459 Wins. Golden Fuse turns 3 of the same pet into a golden one.
- **Gamepasses on the wiki:** Hatch +3 (R$25), Auto Wins (25), +1 Pet (69), Koi Zone (99), Extra Aura Slot (99), Hatch +8 (145).

## 8. What makes it feel good (my read) [I]
1. **One verb, instant answer.** Tap THROW and the camera is on the stone in half a second, with no wind-up you have to wait through.
2. **The counter is the star.** One huge number climbing at a steady pace, plus a zone name you are "arriving at".
3. **Short and repeatable.** 4–5 s per throw, a hard cut home, and the next throw a second later. It never makes you wait.
4. **Every second pays something:** +1 Skill per bounce, the level bar, Level Up!, +1 Win, a toast, a red badge.
5. **Calm camera.** No shake. The motion comes from the water rushing past.
6. **The tutorial ends on a rebirth**, so the biggest number jump (×2) lands in the first 90 s, and a new feature unlocks right after.
7. **The HUD is busy, but always in the same place.** The money buttons sit right next to the numbers they raise (+1M Skill under the Level bar).
