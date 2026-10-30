---
tags: [build-playbooks, starter-kit, code, start-here]
updated: 2026-10-30
---

# 05 New Game Kit

Back to [[00 Build Router]] · Rules it follows: [[02 Launch and Discovery Cheat Sheet]], [[Paid Random Items and Odds Disclosure in Practice]]

**Every new game starts from `new-game-kit/`.** It has every system a kid simulator needs, already wired, tested offline and built into a place file. Full guide: `new-game-kit/README.md`.

![[hud-sheet.jpg]]

## Start
1. `sh new-game-kit/tools/new_game.sh my-game MyGame` (copies the kit, renames the save store, builds `my-game/places/MyGame.rbxl`).
2. Pick the blueprint: [[Blueprint - Egg Run]], [[Blueprint - Plus One Evolution]], [[Blueprint - Plus One Speed Escape]], [[Blueprint - Roll and Place RNG]], [[Blueprint - Anomaly Shift]].
3. Edit one file: `src/Config/GameConfig.luau`.
4. Build only the game's own loop as a new service; everything else is there.
5. `sh tools/check.sh` before every commit (119 checks + a 60-check play-through + place rebuild).

## What's inside
| System | Kit file | Design note |
|---|---|---|
| Session-locked saving | `src/Server/PlayerData.luau` | [[Session Locking and Profile Libraries]] |
| Cash per second, tap, offline earnings | `src/Server/Income.luau` | [[Offline Earnings]] |
| Upgrades | `src/Server/Upgrades.luau` | [[Pricing Curves and Upgrade Costs]] |
| Rebirth | `src/Server/Rebirth.luau` | [[Rebirth and Prestige System End to End]] |
| Eggs with odds and pity | `src/Server/EggHatch.luau` | [[Drop Tables Rarity and Pity Systems]] |
| Pets: boost and index | `src/Server/Pets.luau` | [[Pet Hatching and Following End to End]] |
| Shop, passes, products, receipts | `src/Server/Shop.luau`, `Receipts.luau` | [[Shop with Game Passes and Developer Products End to End]] |
| Daily, playtime gifts, codes, quests | `DailyRewards`, `PlaytimeGifts`, `Codes`, `Quests` | [[Daily Rewards System End to End]], [[Codes Redemption System End to End]], [[Quest Chain System End to End]] |
| Leaderboards | `src/Server/Leaderboard.luau` | [[Global Leaderboards End to End]] |
| Settings (flashes, shake, low graphics) | `src/Server/Settings.luau` | [[Comfort Toggles - Flashes Damage Numbers and Hit-Stop]] |
| Big numbers | `src/Shared/Format.luau` | [[Big Numbers Precision and Formatting]] |
| Cartoony HUD (saved in StarterGui) | `src/Shared/HudBuilder.luau`, `src/Client/KitClient.client.luau` | [[14 Cartoony UI & Juice]] |

Restyle the HUD to the game's reference: [[Reference Gallery]].

## Status
Runs offline in a stand-in Roblox; **not yet run in Studio**. Do the Studio smoke test in the README (step 4) on the first game made from it. Product, pass and icon ids are 0 until the owner creates them.
