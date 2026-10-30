---
tags: [build-playbooks, router, start-here]
updated: 2026-10-30
---

# 00 Build Router

**Start here for any build.** Find the job, then open only what that row lists. Claude: grep the linked notes, don't read whole folders.

**Then read the sector brief for your job** in [[Sector Briefs Index]] (8 briefs, verified against Roblox docs on 2026-10-30). Where an older note disagrees with a brief, the brief wins ([[Vault Corrections October 2026]]).

Playbooks in this folder:
- [[01 Current Hits October 2026]]: what's on the charts now, grouped into game families
- [[Blueprint - Egg Run]]: treadmill speed, biomes, grab eggs, base income, steal (Steal An Egg, Climb/Bike For Eggs)
- [[Blueprint - Plus One Evolution]]: train one stat, launch or throw for distance, cash, worlds (our Cannon Evolution)
- [[Blueprint - Plus One Speed Escape]]: +1 speed per step, obstacle course, wins, worlds
- [[Blueprint - Roll and Place RNG]]: roll units, place on plot, income, luck upgrades (Anime Dice, Sol's RNG)
- [[Blueprint - Anomaly Shift]]: short horror-lite job shifts, spot what's wrong (Animal Hospital Anomaly)
- [[02 Launch and Discovery Cheat Sheet]]: the 2026 algorithm, rules and launch checklist on one page
- [[03 What's New on Roblox - RDC 2026 and October]]: every new Roblox feature, sorted into use now / coming soon
- [[04 AI Tools Landscape October 2026]]: our AI stack, the official Studio MCP tool list, and 20+ third-party tools compared

## Pick a game

| Want | Open |
|---|---|
| What to build next | [[01 Current Hits October 2026]], [[Viral Game Anatomy - Hooks, Loops and Timing]], `LihFolk/skills/roblox-trend-game/SKILL.md` |
| A game in a known family | The matching Blueprint above |
| A genre not listed | `LihFolk/LihFolk Vault V2/10 Game Design and Genres/` (Genre Playbook notes) |
| The 7-day plan | `LihFolk/skills/roblox-trend-game/references/trend-games-research.md` section 9 |

## Build a system

| System | Design note | Code to copy |
|---|---|---|
| Saving | [[Session Locking and Profile Libraries]] | `LihFolk/skills/lihfolk-systems/` (PlayerData), `cannon-evolution/src/server/GameServer.server.lua` |
| Currency, upgrades | [[Pricing Curves and Upgrade Costs]], [[Economy Inflation Sinks and Faucets Math]] | lihfolk-systems Currency; Cannon Evolution `GameConfig.lua` |
| Big numbers (1.2M, 3.4B) | [[Big Numbers Precision and Formatting]] | |
| Eggs, pets, rarity | [[Pet Hatching and Following End to End]], [[Drop Tables Rarity and Pity Systems]], [[Rarity Ladders and Drop Pacing Math]] | lihfolk-systems EggHatch; Cannon Evolution `Pets.lua` |
| Rebirth | [[Rebirth and Prestige System End to End]] | lihfolk-systems Rebirth; Cannon Evolution `Rebirth.lua` |
| Base / plot income | [[Tycoon Plots and Droppers End to End]], [[Offline Earnings]] | |
| Steal from players | [[Case Study - Steal a Brainrot]], [[Blueprint - Egg Run]] section 4 | |
| Shop, passes, products | [[Shop with Game Passes and Developer Products End to End]], [[Paid Random Items and Odds Disclosure in Practice]] | lihfolk-systems Shop + Receipts |
| Daily rewards, codes, quests | [[Daily Rewards System End to End]], [[Codes Redemption System End to End]], [[Quest Chain System End to End]] | lihfolk-systems; Cannon Evolution `Rewards.lua`, `Missions.lua` |
| Leaderboards | [[Global Leaderboards End to End]] | lihfolk-systems Leaderboard |
| Obby checkpoints | [[Obby Checkpoints and Stage Saves End to End]] | |
| Trading | [[Trading Systems Without Duplication]] | |
| Anti-cheat for speed games | [[Detecting Movement Exploits - Speed Fly Noclip Teleport]], [[Server Authority and Validation]] | `LihFolk/skills/roblox-secure-remotes/` |
| Tutorial / first 60 s | [[First-Time User Experience and Onboarding]] | Cannon Evolution `Tutorial.lua` |

## Make it look and feel good

| Job | Skill (`.claude/skills/`) | Notes |
|---|---|---|
| Map, props, lighting | `roblox-cartoony-building` | [[13 Cartoony & Low-Poly Building]], `reports/Cartoony Roblox building UI and animation.md` |
| UI | `roblox-cartoony-ui` | [[14 Cartoony UI & Juice]] |
| Effects | `roblox-vfx` | `VFX-ITEMS.md`, [[05 VFX]] |
| Animations | `roblox-ai-animation` | [[06 Animation]] |
| Blender models | `blender-roblox-models` | [[04 Building, Maps & 3D Models]] |
| Game feel | | `GAME-FEEL.md`, `LihFolk/LihFolk Vault V2/47 Game Feel and Juice/` |
| Final check | | [[16 Cartoony Kid-Appeal Checklist]] |

## Ship it

| Job | Open |
|---|---|
| Algorithm, rules, launch steps | [[02 Launch and Discovery Cheat Sheet]] |
| Thumbnails and icon | [[Thumbnails and CTR Start Here]], [[08 Thumbnails, Icons & Marketing]] |
| Retention and come-back hooks | [[Retention and Return Hooks]], [[Live Ops Deep Dive Start Here]] |
| Money | [[10 Business, Monetization & Case Studies]], `LihFolk/skills/roblox-monetization-compliance/` |
| AI workflow (MCP, Rojo, skills) | [[04 AI Tools Landscape October 2026]], [[01 Setup & Workflow]], [[00 Video Notes Index]] |
| New Roblox features to use | [[03 What's New on Roblox - RDC 2026 and October]] |
