---
tags: [build-playbooks, router, start-here]
updated: 2026-10-30
---

# 00 Build Router

**Start here for any build.** Find the job, then open only what that row lists. Claude: grep the linked notes, don't read whole folders.

**Then read the sector brief for your job** in [[Sector Briefs Index]] (8 briefs, verified against Roblox docs on 2026-10-30). Where an older note disagrees with a brief, the brief wins ([[Vault Corrections October 2026]]).

**Starting code: [[05 New Game Kit]].** Every new game starts from `new-game-kit/` (saving, cash, upgrades, rebirth, eggs, pets, shop, gifts, codes, HUD, all tested offline). Build only the game's own loop.

Playbooks in this folder:
- [[05 New Game Kit]]: the starter kit and how to start a game from it in 10 steps
- [[Reference Gallery]]: the owner's reference pictures (HUDs, menus, lobbies, icons); give one with every UI or map prompt
- [[01 Current Hits October 2026]]: what's on the charts now, grouped into game families
- [[Blueprint - Egg Run]]: treadmill speed, biomes, grab eggs, base income, steal (Steal An Egg, Climb/Bike For Eggs)
- [[Blueprint - Plus One Evolution]]: train one stat, launch or throw for distance, cash, worlds (our Cannon Evolution)
- [[Blueprint - Plus One Speed Escape]]: +1 speed per step, obstacle course, wins, worlds
- [[Blueprint - Roll and Place RNG]]: roll units, place on plot, income, luck upgrades (Anime Dice, Sol's RNG)
- [[Blueprint - Anomaly Shift]]: short horror-lite job shifts, spot what's wrong (Animal Hospital Anomaly)
- [[02 Launch and Discovery Cheat Sheet]]: the 2026 algorithm, rules and launch checklist on one page
- [[06 Beat the Hits - Polish Playbook]]: ⭐ the feel and polish spec (launch by phase, juice sizes, sound, HUD, onboarding numbers, feel test)
- [[07 Borrow List - Game by Game]]: every good idea from Stone Skipping, Steal an Egg, the +1 family and Grow a Garden, with how to build it
- [[Teardown - Stone Skipping]]: the +1 reference measured frame by frame (first 90 s, one throw, HUD, shop, retention)
- [[08 Few-Prompt Game Building with AI]]: how to get a good game in a few prompts (what works, templates, self-checks)
- [[09 Owner Taste Rules]]: the owner's calls on UI, sound, look and pace; load for every look/feel job
- [[10 Map Design Playbook]]: ⭐ popular-quality maps from a short prompt (4 layout templates, 12-zone theme kit, scale numbers, build recipe, checklist)
- [[11 VFX Moments Playbook]]: ⭐ launch, trails, splashes, coins, hatch, rebirth, zone and rare-shot effects with values and tier scaling
- [[12 Game Loop Logic Playbook]]: ⭐ loop families, pacing targets, economy formulas, server/client system template, pacing sim
- [[03 What's New on Roblox - RDC 2026 and October]]: every new Roblox feature, sorted into use now / coming soon
- [[04 AI Tools Landscape October 2026]]: our AI stack, the official Studio MCP tool list, and 20+ third-party tools compared

## Pick a game

| Want | Open |
|---|---|
| What to build next | [[01 Current Hits October 2026]], [[Viral Game Anatomy - Hooks, Loops and Timing]], `LihFolk/skills/roblox-trend-game/SKILL.md` |
| A game in a known family | The matching Blueprint above, then [[12 Game Loop Logic Playbook]] for pacing and numbers |
| A genre not listed | `LihFolk/LihFolk Vault V2/10 Game Design and Genres/` (Genre Playbook notes) |
| The 7-day plan | `LihFolk/skills/roblox-trend-game/references/trend-games-research.md` section 9 |

## Build a system

| System | Design note | Code to copy |
|---|---|---|
| Saving | [[Session Locking and Profile Libraries]] | `new-game-kit/src/Server/PlayerData.luau`; `LihFolk/skills/lihfolk-systems/` (PlayerData), `cannon-evolution/src/server/GameServer.server.lua` |
| Currency, upgrades | [[Pricing Curves and Upgrade Costs]], [[Economy Inflation Sinks and Faucets Math]] | `new-game-kit/src/Server/Currency.luau`, `Upgrades.luau`; lihfolk-systems Currency; Cannon Evolution `GameConfig.lua` |
| Big numbers (1.2M, 3.4B) | [[Big Numbers Precision and Formatting]] | `new-game-kit/src/Shared/Format.luau` |
| Eggs, pets, rarity | [[Pet Hatching and Following End to End]], [[Drop Tables Rarity and Pity Systems]], [[Rarity Ladders and Drop Pacing Math]] | `new-game-kit/src/Server/EggHatch.luau`, `Pets.luau`; lihfolk-systems EggHatch; Cannon Evolution `Pets.lua` |
| Rebirth | [[Rebirth and Prestige System End to End]] | `new-game-kit/src/Server/Rebirth.luau`; lihfolk-systems Rebirth; Cannon Evolution `Rebirth.lua` |
| Base / plot income | [[Tycoon Plots and Droppers End to End]], [[Offline Earnings]] | `new-game-kit/src/Server/Income.luau` (per second + offline) |
| Steal from players | [[Case Study - Steal a Brainrot]], [[Blueprint - Egg Run]] section 4 | |
| Shop, passes, products | [[Shop with Game Passes and Developer Products End to End]], [[Paid Random Items and Odds Disclosure in Practice]] | `new-game-kit/src/Server/Shop.luau` + `Receipts.luau`; lihfolk-systems Shop + Receipts |
| Daily rewards, codes, quests | [[Daily Rewards System End to End]], [[Codes Redemption System End to End]], [[Quest Chain System End to End]] | `new-game-kit/src/Server/` DailyRewards, PlaytimeGifts, Codes, Quests; lihfolk-systems; Cannon Evolution `Rewards.lua`, `Missions.lua` |
| Leaderboards | [[Global Leaderboards End to End]] | `new-game-kit/src/Server/Leaderboard.luau`; lihfolk-systems Leaderboard |
| Obby checkpoints | [[Obby Checkpoints and Stage Saves End to End]] | |
| Trading | [[Trading Systems Without Duplication]] | |
| Anti-cheat for speed games | [[Detecting Movement Exploits - Speed Fly Noclip Teleport]], [[Server Authority and Validation]] | `LihFolk/skills/roblox-secure-remotes/` |
| Tutorial / first 60 s | [[First-Time User Experience and Onboarding]] | Cannon Evolution `Tutorial.lua` |

## Make it look and feel good

| Job | Skill (`.claude/skills/`) | Notes |
|---|---|---|
| Map, props, lighting | `roblox-cartoony-building` | [[10 Map Design Playbook]], [[13 Cartoony & Low-Poly Building]], `reports/Cartoony Roblox building UI and animation.md` |
| UI | `roblox-cartoony-ui` | [[14 Cartoony UI & Juice]] |
| Effects | `roblox-vfx` | [[11 VFX Moments Playbook]], `VFX-ITEMS.md`, [[05 VFX]] |
| Animations | `roblox-ai-animation` | [[06 Animation]] |
| Blender models | `blender-roblox-models` | [[04 Building, Maps & 3D Models]] |
| Game feel | | [[06 Beat the Hits - Polish Playbook]], `GAME-FEEL.md`, `LihFolk/LihFolk Vault V2/47 Game Feel and Juice/` |
| Match or beat a hit | | [[07 Borrow List - Game by Game]], the game's Teardown note, [[09 Owner Taste Rules]] |
| Final check | | [[16 Cartoony Kid-Appeal Checklist]] |

## Ship it

| Job | Open |
|---|---|
| Algorithm, rules, launch steps | [[02 Launch and Discovery Cheat Sheet]] |
| Thumbnails and icon | [[Thumbnails and CTR Start Here]], [[08 Thumbnails, Icons & Marketing]] |
| Retention and come-back hooks | [[Retention and Return Hooks]], [[Live Ops Deep Dive Start Here]] |
| Money | [[10 Business, Monetization & Case Studies]], `LihFolk/skills/roblox-monetization-compliance/` |
| AI workflow (MCP, Rojo, skills) | [[08 Few-Prompt Game Building with AI]], [[04 AI Tools Landscape October 2026]], [[01 Setup & Workflow]], [[00 Video Notes Index]] |
| New Roblox features to use | [[03 What's New on Roblox - RDC 2026 and October]] |
