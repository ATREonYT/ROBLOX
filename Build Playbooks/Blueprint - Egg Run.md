---
tags: [build-playbooks, blueprint, egg-run, steal-a-x, simulator, pets]
updated: 2026-10-30
---

# Blueprint - Egg Run

Back to [[00 Build Router]] · Family overview: [[01 Current Hits October 2026]]

**One line:** train Speed on a treadmill, run into a biome you can now reach, grab an egg, get it home, hatch an animal that earns cash every second on your base, and spend the cash on a better treadmill and base. Optional: other players can steal from your base and you from theirs.

Reference games: Steal An Egg (#1 on Roblox in Oct 2026), Climb For Animals Eggs, Bike For Egg!, Break and Steal an Egg, Steal A Pet And Ride It!, Ride A Pet. Deep teardowns: [[Teardown - Steal An Egg]], [[Teardown - Ride A Pet]], [[Case Study - Steal a Brainrot]].

> [!info] Labels
> Numbers marked **start** are our starting values to tune in playtests, not measured from the hits. Hit-game facts come from the linked teardowns.

## 1. Pick the twist (day 1, one sentence)
Change about 20% of the formula (see [[15 Kid Appeal & Game Design]]). Pick one from each row:
- **Verb:** steal, climb, bike, ride, swim, fly, dig, skate, jump, launch.
- **World shape:** flat biomes in a line, a vertical tower/mountain, a long track, islands with a boat.
- **Collectible:** animals, brainrots, dinos, bugs, food, robots (original designs only, never copied characters).
- Test: can a 7-year-old explain the game from the title and the thumbnail alone?

## 2. Core loop and first 60 seconds
```text
treadmill (+Speed) ─► Speed gate opens next biome ─► grab egg ─► carry home (guardian / thief chase)
     ▲                                                                  │
     └── buy better treadmill / base slots ◄── cash per second ◄── hatch ─► animal on base
                                                          rebirth ─► x multiplier, keep Speed tier
```
First minute, no reading needed:
1. Spawn beside your empty base and the starter treadmill, with an arrow on the floor.
2. Treadmill: Speed climbs fast at first (**start:** +1 per 0.25 s, so about 100 in 25 s).
3. Biome 1 needs **0 Speed** and sits **30-60 studs** from spawn. First egg in under 60 seconds.
4. Grab → a guardian wakes → a short chase over a clear "safe line" back home.
5. The egg hatches in **3-5 s** (**start**), the animal appears on a base pad and cash ticks up with a +$ popup.
6. A sign shows the next goal: "Biome 2: 250 Speed".

## 3. Systems list (build in this order)
| # | System | Vault note | Code to start from |
|---|---|---|---|
| 1 | Player data + saving (Speed, Cash, Rebirths, Animals, Index) | [[Session Locking and Profile Libraries]] | `LihFolk/skills/lihfolk-systems` PlayerData |
| 2 | Speed stat + treadmill tiers (server owns Speed) | [[Detecting Movement Exploits - Speed Fly Noclip Teleport]] | Cannon Evolution training stations |
| 3 | Biome gates checked on the server at grab time | [[Server Authority and Validation]] | snippet in [[Teardown - Steal An Egg]] |
| 4 | Egg grab → carry → deliver state machine + guardian | [[Case Study - Steal a Brainrot]] | |
| 5 | Hatch table (rarity × size × mutation) that also feeds the odds panel | [[Pet Hatching and Following End to End]], [[Drop Tables Rarity and Pity Systems]] | lihfolk-systems EggHatch |
| 6 | Base pads + cash per second + offline earnings | [[Tycoon Plots and Droppers End to End]], [[Offline Earnings]] | |
| 7 | Upgrades: treadmill tier, base slots, income | [[Pricing Curves and Upgrade Costs]] | Cannon Evolution `Upgrades.lua` |
| 8 | Rebirth | [[Rebirth and Prestige System End to End]] | lihfolk-systems Rebirth |
| 9 | Animal Index with rewards | [[Saved Inventory End to End]] | |
| 10 | Stealing between players (optional) | section 4 below | |
| 11 | Shop: passes + products, odds panel | [[Shop with Game Passes and Developer Products End to End]], [[Paid Random Items and Odds Disclosure in Practice]] | lihfolk-systems Shop + Receipts |
| 12 | Daily reward, codes, group gift, leaderboard | [[Daily Rewards System End to End]], [[Codes Redemption System End to End]], [[Global Leaderboards End to End]] | lihfolk-systems |

## 4. Stealing that kids don't rage-quit
- Only animals **on the base** can be taken, never the Speed stat ("safe stat, risky money").
- Thief carries slowly (**start:** WalkSpeed × 0.6) and drops it if hit once.
- **Newcomer shield:** no theft from players in their first **10 minutes** or under a cash floor (**start**).
- Base lock button: **60 s** lock, **3 min** cooldown (**start**). A paid "lock longer" is self-protection and fine; never sell a tool whose only use is taking from others.
- Steal-back: the owner can tag the thief before the thief crosses the gate to get it back.

## 5. Starting numbers (tune in playtests)
| Thing | Start value | Why |
|---|---|---|
| Biomes at launch | 5 | room for weekly updates |
| Speed gates | 0 / 250 / 1.5K / 8K / 40K | about ×5 per biome |
| Treadmill tiers | 6, each ×2-3 Speed per second over the last | the first buy within 2 minutes |
| Egg rarities | Common 60 / Uncommon 25 / Rare 10 / Epic 4 / Legendary 0.9 / Mythic 0.1 (%) | the ladder from [[Rarity Ladders and Drop Pacing Math]] |
| Sizes | Normal 85 / Big 12 / Huge 3 (%), cash ×1 / ×2 / ×5 | |
| Mutations | Gold 5% ×2, Rainbow 1% ×5, event mutation 0.5% ×10 | duplicates stay worth keeping |
| Base slots | 6 at start, +2 per upgrade, 30 max | |
| Upgrade cost | `a × 1.15^L` | see [[Pricing Curves and Upgrade Costs]] |
| Rebirth | needs Cash ≥ 1M × 3^rebirths; gives ×1.5 cash each | |
| Offline earnings | 50% rate, capped at 8 h | come-back reason without "free money forever" |

## 6. Map layout
- Spawn → own base row (bases in a line or a ring, each with a clear name sign and colour).
- Treadmills in front of the base, then biome gates in a straight line outward (the linear layout from [[00 Video Notes Index]]: SyphoDev's creature game).
- Each biome has its own colour accent and **one new movement idea** (ice, jump pads, wind), not only bigger numbers.
- Speed gate = a glowing wall with the number on it. Locked biomes are visible through it.
- Build it with the `roblox-cartoony-building` skill. Lighting preset A (purple and yellow) suits the hub.

## 7. UI list
HUD: Speed (big, top centre) · Cash with **+** button · Rebirths · left column (Shop, Index, Rebirth, Settings) · next-goal bar ("Biome 3: 1.2K / 1.5K Speed").
Popups: hatch reveal (spin → reveal → rarity colour burst), "Your animal was stolen!" with a steal-back arrow, new-biome banner.
Build it with the `roblox-cartoony-ui` skill.

## 8. Money (kid-safe, 2026 rules)
- Passes: 2x Cash, 2x Speed, +5 base slots, auto-collect, VIP biome. Self-only multipliers need no odds.
- Products: Speed boost 15 min, Cash pack, Luck boost (paid random → odds shown and updated live).
- Paid eggs or luck: odds that sum to 100% shown before buying, `PolicyService` check that fails closed, and a pity counter. See [[Paid Random Items and Odds Disclosure in Practice]].
- No fake timers or fake stock (repo rule in `CLAUDE.md`).

## 9. Weekly updates (plan 4 before launch)
1. A new biome + egg + 6 animals. 2. An event mutation (🎃 Pumpkin). 3. A new treadmill tier + Index rewards. 4. An admin-abuse style live event weekend (2x luck, a meteor drop).

## 10. Done when
- [ ] First egg in under 60 s on a phone, without reading.
- [ ] Speed, gates and steals are checked on the server.
- [ ] The odds panel uses the same table as the roll.
- [ ] [[16 Cartoony Kid-Appeal Checklist]] passes.
