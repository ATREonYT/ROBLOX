---
tags: [build-playbooks, borrow-list, competitors, teardown]
updated: 2026-10-30
---

# 07 Borrow List - Game by Game

Back to [[00 Build Router]] · Feel and polish: [[06 Beat the Hits - Polish Playbook]] · Deep teardown: [[Teardown - Stone Skipping]]

**The owner's direction (Oct 30):** borrow every well-made idea from the hits and do it well. Rebuild each one with our own art, names and numbers. Never copy their assets, names or text.

**How to use this list:**
- Each row is one idea: what it is, why it works, and the cheapest Roblox way to build it.
- Tick it off per game.
- **Cannon** says where +1 Cannon Evolution stands on Oct 30, 2026 (✓ has it, ½ partly, ✗ missing).

**Sources:**
- [[Teardown - Stone Skipping]]: measured from the owner's recordings.
- `research_notes/Front page feel and gamey stages/plus_one_and_steal_games.md`: the +1 genre, Steal an Egg and Steal a Brainrot, with the numbers.
- allthings.how, player.one and PC Gamer pages: their URLs are in the section headings below.

## 1. +1 Stone Skipping (the direct reference)
| # | Borrow | Why it works | How in Roblox | Cannon |
|---|---|---|---|---|
| 1 | **Intro flyover of the whole track** with a Skip button, ending behind the player | You see every zone you'll reach before you play: the promise | Camera on `Scriptable`, a CFrame spline with tweened waypoints, a Skip button, and the camera back to `Custom` | ✓ (Tutorial.lua) |
| 2 | **Tutorial that ends on the first rebirth by ~70–90 s**, then TUTORIAL COMPLETE on a sunburst with "Rebirth #1 ×2" | The biggest number jump lands in the first session | Price rebirth 1 so the quest steps reach it in ~60 s; a full-screen moment card | ½ (Config aims at ~1.5 min of training; time it from join) |
| 3 | **A new feature unlocks right after the tutorial** (NEW! tag), then Daily Rewards opens | It answers "what next?" before boredom | A "feature unlocked" moment queue: tutorial complete, then unlock, then daily | ½ |
| 4 | **A tap-to-launch button pops up over your character** inside the zone | One clear verb, thumb-sized | A BillboardGui or ScreenGui button shown on zone enter (walk-in also works) | ✓ (walk-in zone) |
| 5 | **Chase cam low behind the projectile** with the horizon about ⅓ from the top, no shake | Speed comes from the world rushing past, not from wobble | Camera `Scriptable`; each RenderStepped, lerp to `ball.Position - dir*14 + up*4`, looking ahead | ✓, check the numbers in [[06 Beat the Hits - Polish Playbook]] |
| 6 | **One huge distance counter**, with the zone name under it that grows when you enter the zone | The number is the show | TextLabel + UIStroke; the zone label tweens size on border cross | ✓ |
| 7 | **+1 stat per bounce** shown live in the HUD, plus a Level Up! flash | The flight itself pays out | Server sends bounce count; the client ticks the HUD at each splash | ½ (cash pops per skip) |
| 8 | **Hard cut home + "+1 🏆" over your head + trophies fly to the counter** | Instant, readable payout; next throw in ~1 s | A pooled BillboardGui rise, then UI icons tween to the HUD counter | ½ |
| 9 | **Rare shots: Secret (~1/100) and Colossus (~1/1000)** | Every throw is a lottery ticket: clips and screams | The server rolls before launch; a different trail, sound, colour, server-wide announcement, extra payout | ✗ |
| 10 | **Global Multiplier from Level** (×1.1 → ×111) beside the stat | A second number that always climbs | Level from total stat; multiplier table in Config | ✗ (Power only) |
| 11 | **Skill packs right under the Level bar** (+1M / +10M / +100M at R$25 / 95 / 185) | The purchase sits next to the number it raises | 3 developer products scaled to the current stat | ✗ |
| 12 | **Training pads that unlock by rebirth** (1x / 4x / 10x / 20x) with "UNLOCKED 1x SKILL" over each | A visible ladder in the lobby | Station table in Config with `Rebirths` needed; billboard per pad | ✓ (booths + rebirth signs) |
| 13 | **Paid "zone" pads** (Koi 3x R$99, Golden 15x R$249, Admin 50x R$599) | A pass you can see other players standing on | A pad gated by `UserOwnsGamePassAsync`, glowing, with a sign | ✗ (VIP station idea in blueprint) |
| 14 | **One scrolling shop page with "~ Section ~" headers**, in this order: packs, featured egg, rolls, passes, boosts, currency packs, codes | Kids scroll, they don't tab | ScrollingFrame with UIListLayout; one card template per kind | ✓ (one-page shop) |
| 15 | **Odds printed on every paid random card** (40/34/20/5/1%, "1 in 673") | Trust, and our kid-safe rule | Card reads odds from Config | ✓ check every card |
| 16 | **Playtime Rewards 4×3 grid**, rows tinted by value, green ticks, then 4 h timers | Stays open for 20+ minutes | Server-timed claims; a tile template with 3 tints | ✓ (Playtime tab), restyle |
| 17 | **Inventory with left tabs: Balls · Pets · Eggs · Items · Titles** | One place for everything you own | Tabs on one panel; boosts as click-to-use tiles; unopened eggs saved | ½ |
| 18 | **Titles = achievements with a perk**, worn over your head ("Skipper: 1K ricochets, +5%") | Long goals plus show-off | Config list of {stat, target, perk}; a BillboardGui title | ✗ |
| 19 | **Friend Boost %** with an invite + button | Free growth, and players bring friends | `Players:GetFriendsOnline` / `IsFriendsWith` on join, +10% each; invite prompt with `SocialService:PromptGameInvite` | ✗ |
| 20 | **Group/like chest** (rainbow CLAIM in the lobby) | Group members get notified of updates | `IsInGroupAsync` on the server, a one-time reward | ✗ |
| 21 | **Pet panel:** Equip Best, Lock, Index, slots +, mass delete; **Golden Fuse** (3 → 1 golden) | Collection depth for almost no art | UI over the existing pet save; golden = recolour + ×multiplier | ½ |
| 22 | **Auras by paid/earned rolls** (up to ×2.5) | A cosmetic plus a boost, shown off on your body | Attachment + particles per aura, odds shown | ✗ |
| 23 | **Event currency + timed event quests** (Halloween pill top centre) | A reason to come back this week | A seasonal Config block; quest with end time | ✗ |
| 24 | **A mini-game unlocked later (Skip Rush):** a power meter, coins on the water, results screen, weekly leaderboard | Skill and competition for older kids | A separate track with its own currency; OrderedDataStore weekly key | ✗ (later update) |
| 25 | **One message line top centre** ("Claimed +13.4K SKILL!"), replaced by each new event | Feedback without clutter | One TextLabel; queue with a 1.5 s minimum | ½ (popups take turns) |

## 2. Steal an Egg (#1 on Roblox in Sep 2026; ~1.3M CCU peak days)
Sources: [player.one](https://www.player.one/robloxs-steal-egg-beating-some-platforms-biggest-games-164086), [allthings.how guide](https://allthings.how/steal-an-egg-beginner-guide-biomes-speed-and-pets-explained/), and the repo research note §3.

| # | Borrow | Why it works | For a +1 game |
|---|---|---|---|
| 1 | **A name that explains the game** | The algorithm and kids both "get it" from the tile | "+1 Cannon Evolution" already does this |
| 2 | **Biomes gated by a recommended stat** (Forest 0, Lake 900, Desert 10K … Cosmic 700M) | Every gate is a goal you can read | Our track zones: print the Power needed on each border wall |
| 3 | **Risk on the way home:** a guardian chases you if your speed is too low, and you drop the egg | Tension, not just numbers | Optional: a "sea monster" that can splash a weak ball short. Keep it gentle |
| 4 | **Placed pets earn money over time; size and mutations change the value** | Two of the same pet aren't equal, so you keep hatching | Pet size/mutation roll at hatch (Big, Golden, Rainbow) = a × boost |
| 5 | **Shared rare spawns that everyone races for** (eggs reset every 5 min) | A server-wide moment every few minutes | A "Golden Ball" drop on the dock every 5 min: first to grab it gets a rare shot |
| 6 | **Stealing / social conflict** | Unpredictable stories between players | Not for this game. Keep it to friendly leaderboards and racing for drops |
| 7 | **Treadmill "Reels" while you train** | A joke that went viral (Dexerto) | A funny thing to look at while training (pet antics, a TV) |
| 8 | **Short sessions (~15 min average)** with progress in each | Fits phones and school breaks | Every session should reach one new zone or one rebirth |

## 3. +1 Superhero / Muscle / Mog / Speed Evolution family
Sources: the repo research note §1.3 (wikis via search summaries).

| # | Borrow | How |
|---|---|---|
| 1 | **The evolution ladder on a big pedestal in the lobby**: every form visible, locked ones dark | Our cannons: a lineup on a stage, with prices and rebirths on plates |
| 2 | **Two currencies:** the stat opens gates, the payout buys things | Power + Cash, already done |
| 3 | **Stage-end pad that pays and teleports you home** (yellow/purple) | Our hard cut home after landing |
| 4 | **Countdown boss / event every hour** (Dungeon Raid at XX:30) | A scheduled "Mega Launch" event: everyone launches at once, bonus for the farthest |
| 5 | **Rebirth keeps 25% and gives ×2** (Superhero); the rebirth table shows "needs Lv 26, ×3" | Show Before → After on the rebirth panel, like the reference |
| 6 | **Eggs ×40–×250 apart in price; a top pet at 0.1–3%** | Our egg ladder already follows this; check the gaps |
| 7 | **Admin Abuse events** (the owner on the server giving boosts) | A live event the owner can run from a chat command |

## 4. Grow a Garden (the most visited "simple" hit; PC Gamer)
- **"Brain off" play:** progress rarely stalls or goes backwards, so it's chill. Never punish a bad launch, just pay less.
- **Random mutations turn a normal item rare.** Borrow for balls: 1 in 50 launches is a "Shiny" shot with ×5 cash.
- **Rotating shop stock** (only 1–2 rare items per rotation). Only use it where the rotation is real and shows a timer. No fake stock (kid-safe rule).

## 5. Steal a Brainrot (still top 10)
Notes: [[Case Study - Steal a Brainrot]].
- A **conveyor of things to buy passing in front of you**: always something new to look at.
- Your **own base with your stuff on display**: show-off.
- For a +1 game, borrow the display: put your best 3 cannons on your own pedestal on the dock, with your name on it.

## 6. Don't borrow
- Fake "was" prices, "Limited Offer" without a real end, fake stock, and timers that reset. These break the repo `CLAUDE.md` kid-safe rules.
- Their art, names, icons, music or text. Make our own (the owner's art kit, CC0 sounds).
- Mechanics that punish kids hard (losing pets to other players) in a game that isn't about stealing.
