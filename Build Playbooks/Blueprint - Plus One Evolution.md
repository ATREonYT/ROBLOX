---
tags: [build-playbooks, blueprint, plus-one, evolution, simulator]
updated: 2026-10-30
---

# Blueprint - Plus One Evolution

Back to [[00 Build Router]] · Family overview: [[01 Current Hits October 2026]]

**Code:** start from [[05 New Game Kit]] (`sh new-game-kit/tools/new_game.sh`); build only this blueprint's own loop.

**One line:** do one simple action that gives +1 to a stat, then spend that stat on a big, visible payoff (a launch, a throw, a punch, a body that grows) that pays cash. Cash buys multipliers, and rebirths reset for a bigger multiplier.

Reference games: +1 Venom Evolution, +1 Anime Eyes, Bug Evolution, Throw Food For Animals, Feed A Mosquito, Tap Simulator REBORN. **Our working reference implementation is `cannon-evolution/`** (+1 Cannon Evolution). Read its `README.md` and `GameConfig.lua` before building another one, and reuse its structure. Build history: `reports/+1 Cannon Evolution build notes.md`.

## 1. Pick the twist
- **Stat:** Power, Size, Strength, Speed, Eyes, Venom, Weight.
- **Payoff verb (the thing kids film):** launch, throw, skip, punch, smash, feed, grow, fly.
- **Collectible that multiplies the stat:** pets, cannons, weapons, forms (evolutions with a new model each tier).
- The payoff must be **visible from far away** (a ball flying 5,000 metres, a body 10× bigger), because that's the clip and the thumbnail.

## 2. Core loop and first 60 seconds
```text
training station (+Power per hit) ─► payoff zone (launch/throw) ─► distance ─► Cash
        ▲                                                                  │
        └── better station / pets / cannons ◄── Cash, Gems ◄───────────────┘
                     rebirth: reset Power + Cash ─► +50% Power, +25% Cash, unlock next station
```
First minute (Cannon Evolution does this; copy it):
1. Spawn facing the first training station with an arrow. Click: +Power, a pop and a number popup.
2. The tutorial quest bar says the next step: Train → Launch → Earn Cash → Hatch → Rebirth (`cannon-evolution/src/client/GameClient/Tutorial.lua`).
3. First launch within 30 s. The camera follows the payoff, with a big distance counter and cash popping.
4. First upgrade affordable after the second launch.

## 3. Systems list
| # | System | Copy from |
|---|---|---|
| 1 | Config-driven everything (stations, worlds, pets, eggs, cannons, passes, codes in one file) | `cannon-evolution/src/shared/GameConfig.lua` |
| 2 | Server: saving, training, launch maths, purchases | `cannon-evolution/src/server/GameServer.server.lua` |
| 3 | Training stations, unlocked by rebirth | `GameConfig` Stations + `src/tools/BuildWorld1.lua` |
| 4 | Payoff (launch with camera follow) | `GameClient/Effects.lua`, `Worlds.lua` |
| 5 | Pets with Power boost + eggs | `GameClient/Pets.lua`, [[Pet Hatching and Following End to End]] |
| 6 | Collection (cannons / forms) | `GameClient/Cannons.lua` |
| 7 | Upgrades kept through rebirth | `GameClient/Upgrades.lua`, [[Pricing Curves and Upgrade Costs]] |
| 8 | Rebirth (Power AND Cash, signs over each station) | `GameClient/Rebirth.lua`, `src/tools/BuildRebirthSigns.lua` |
| 9 | Missions, daily rewards, codes | `Missions.lua`, `Rewards.lua`, [[Daily Rewards System End to End]] |
| 10 | Leaderboard (top distance) | `Leaderboard.lua`, [[Global Leaderboards End to End]] |
| 11 | Shop: passes + products | `Shop.lua`, [[Shop with Game Passes and Developer Products End to End]] |

## 4. Numbers that worked in Cannon Evolution (starting point)
| Setting | Value |
|---|---|
| First rebirth | Power 100, about 1.5 min of training |
| Rebirth growth | ×3.2 per rebirth (R1 about 1 min, R5 about 10 min, R10 about 1.5 h) |
| Rebirth bonus | +50% Power per shot, +25% Cash |
| Skip decay | each skip 0.86 of the last; first arc 20% of the distance |
| Return delay | 1.5 s between launches; Auto Launch every 4 s |
| Gem chance | 15% per launch |
| Egg ladder | 45 / 30 / 17 / 7 / 1 (%), with the top egg 40 / 30 / 18 / 9 / 2.7 / 0.3 |
| Equip slots | +2 from a pass |
These are in `GameConfig.lua`. Change them there, never in scripts.

## 5. Map layout
- Lobby: training stations in a row (each a bigger, cooler machine with the rebirth needed written above it), the payoff zone at the end, and the egg stands beside it.
- Payoff track: long, straight, with see-through world borders and a name per area, so distance reads as travel.
- Cartoony look: the `roblox-cartoony-building` skill; Cannon Evolution's `src/tools/BuildCartoonyMap.lua` and `BuildLighting.lua`.

## 6. UI list
HUD: the stat (huge) · Cash · Gems · Rebirths · left column (Shop, Pets, Cannons, Rebirth, Upgrades, Missions) · quest bar · distance counter during the payoff.
The owner's UI is reference-matched: follow `CLAUDE.md` rules 2 and 11 and the `roblox-cartoony-ui` skill.

## 7. Money
Passes: 2x Power, 2x Cash, Auto Launch/Auto Train, Extra Equip, VIP station. Products: Power boost, Cash packs, paid eggs (odds shown, pity). An item that gives nothing yet shows "Coming soon" and never opens a purchase (repo rule).

## 8. Weekly updates
New world on the track + a new egg; a new collection tier; an event form/skin (seasonal); a 2x weekend.

## 9. Done when
- [ ] First payoff within 30 s, first rebirth within 2 min.
- [ ] The payoff looks great in a 15-second phone clip.
- [ ] All tunables live in GameConfig.
- [ ] [[16 Cartoony Kid-Appeal Checklist]] passes.
