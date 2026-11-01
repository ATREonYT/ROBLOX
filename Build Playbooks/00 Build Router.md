---
tags: [build-playbooks, router, start-here]
updated: 2026-11-01
---

# 00 Build Router

**Start here for any build.** Find the job, then open only what that row lists. Claude: grep the linked notes, don't read whole folders.

**Then read the sector brief for your job** in [[Sector Briefs Index]] (8 briefs, verified against Roblox docs on 2026-10-30). Where an older note disagrees with a brief, the brief wins ([[Vault Corrections October 2026]]).

**Starting code: [[05 New Game Kit]].** Every new game starts from `new-game-kit/` (saving, cash, upgrades, rebirth, eggs, pets, shop, gifts, codes, HUD, all tested offline). Build only the game's own loop.

**The numbers: [[27 Studio Standard - One Sheet per Craft]].** One sheet per craft (rule, numbers, recipe, test). Where an older note's number disagrees, the sheet wins (clashes C1–C31 settled).

## By craft (start here for a look, feel or code job)

| Craft | Numbers | Deep note | Skill | Kit code |
|---|---|---|---|---|
| Animation | 27 §1 | [[16 Pro Animation and VFX Playbook]], [[19 Animation and VFX Recipe Book]], anime: [[15 Anime VFX and Animation Playbook]] | `roblox-ai-animation` | `Spring`, `AnimeFX` |
| VFX | 27 §2 | [[11 VFX Moments Playbook]], [[17 Do It Like the Hits - Animation, VFX and Feel]], [[22 Rare Shot VFX Spec from Alex's References]] | `roblox-vfx` | `Emit`, `LaunchFX`, `RareReveal` |
| Camera | 27 §3 | [[28 Camera Playbook]], [[25 Rare Shot Cameras and Using a VFX Pack]] | `roblox-vfx` | `CameraMath` |
| Code architecture | 27 §4 | [[18 Studio-Level Development Playbook]], [[12 Game Loop Logic Playbook]] | | `Net`, `Flags`, `ErrorLog`, `PlayerData`, `Interact` |
| Building and maps | 27 §5 | [[10 Map Design Playbook]], [[23 Training Lane Style Guide (Alex's Treadmill References)]] | `roblox-cartoony-building`, `blender-roblox-models` | |
| UI and UX | 27 §6 | [[30 UI and UX Playbook]], [[14 Premium Feel Playbook]], [[13 Beat Stone Skipping - Tutorial, Pacing and Feel]] | `roblox-cartoony-ui` | `HudStages`, `HudBuilder`, `Feedback` |
| Sound | 27 §7 | [[29 Sound Playbook]] | | `make_sfx.py` |
| Money and gamepasses | 27 §8 | [[21 Money and Retention at Studio Level]] | | `Shop`, `Receipts`, `Offers`, `Odds` |
| Retention | 27 §9 | [[21 Money and Retention at Studio Level]], [[20 Whole-Game Field Guide]] | | `DailyRewards`, `PlaytimeGifts`, `Quests`, `Codes`, `Income` |
| Pacing | 27 §10 | [[12 Game Loop Logic Playbook]], [[Teardown - Stone Skipping]] | | `Progression`, `tools/pace.luau` |
| Working in Alex's Studio | | [[24 Working Live in Studio - Saves, Turns and Hand Edits]] | | |

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
- [[15 Anime VFX and Animation Playbook]]: ⭐ anime-style effects: Dragon Ball-style power-up aura, impact frames, hit sizes, craters, speed lines, snappy attack timing, ultimates, kid-safe rules; kit module `AnimeFX`
- [[16 Pro Animation and VFX Playbook]]: ⭐ when animations or effects look cheap: fix order (timing, shape, colour), cheap-vs-pro table, flipbook and mesh pipeline, cannon shot timeline, camera, character animation workflow
- [[17 Do It Like the Hits - Animation, VFX and Feel]]: ⭐ Oct 31 deep dive: measured Stone Skipping timings (quiet normal shots), rare-shot reveal ladder, cutscene camera, own textures by code, springs and rigs, phone budgets, anime-game patterns, sound layers, 2026 discovery signals; kit modules `Spring`, `Emit`, `LaunchFX`, `RareReveal`
- [[18 Studio-Level Development Playbook]]: ⭐ how pro studios build: architecture, networking checks, data safety, CI on every push, phone performance budgets, building hygiene, release checklist, kill switches (`Flags`), simulator security, ranked to-do for the kit
- [[19 Animation and VFX Recipe Book]]: ⭐ 25 step-by-step recipes (catch-up hit-stop, impact order, charge-up, cannon shot, landing rings, slash, aura, dash, beam, ultimate cutscene, combo clip, idle, hit react, reward fly, hatch, level-up, rebirth, chase cam, UI pop, sound, juice governor) + 8 kid-friendly anime combat recipes + anime numbers + corrections
- [[20 Whole-Game Field Guide]]: ⭐ 44 rules every great Roblox game follows, blueprints for 7 genres (+1/launch, tycoon, pets, battlegrounds, tower defense, obby, RNG), symptoms → fixes, gaps, conflicts with our rules
- [[21 Money and Retention at Studio Level]]: ⭐ what to sell in a kids' simulator, the price ladder rules, when an unasked offer may pop up, the six numbers to read weekly, and return hooks for D1, D2–7 and D8–28. Kit: `Shared/Offers.luau`.
- [[22 Rare Shot VFX Spec from Alex's References]]: frame-by-frame study of Alex's 4 favourite VFX clips (impact frames, dark inhale, fast-in slow-out) and a frame-timed build spec for the Mythic, Secret and Divine cannon shots, kid-safe.
- [[23 Training Lane Style Guide (Alex's Treadmill References)]]: Alex's favourite treadmill look (dark voxel body, neon edges, one colour plus white), the "alive but not too crazy" motion budget, why gamepass lanes beat free ones by shape and life, and 8 kid-safe themes. Sheets in `references/treadmill-lanes/`.
- [[24 Working Live in Studio - Saves, Turns and Hand Edits]]: ⭐ how to work inside Alex's open Studio without losing anything: which save button really saves, one thread at a time, merge into live scripts and keep hand edits, bring Studio-only changes back to git, bringing in a pack.
- [[25 Rare Shot Cameras and Using a VFX Pack]]: what Alex pushed back on in the rare shots and the fixes, a camera plan per tier, and how to use an effects or sound pack (pick by job, recolour, cap brightness, skip ripped textures).
- [[26 Fun and Roleplay Playbook]]: roleplay towns and fun party or action games: social loops, jobs and roles, houses, vehicles, outfits, safety (written by the RP research thread). Blueprint: [[Blueprint - Roleplay Town]]; ideas: [[Game Concepts - RP and Fun]]. Kit: `Server/Roleplay.luau`, `Shared/Interact.luau`.
- [[27 Studio Standard - One Sheet per Craft]]: ⭐ the one number sheet: rule, numbers, recipe and test for animation, VFX, camera, code, building, UI, sound, money, retention and pacing, plus the settled clashes and a ten-line review.
- [[28 Camera Playbook]]: ⭐ every camera a kids' game needs (default, side-on flight, chase, top-down, scripted), cutscene grammar, shake, comfort, a worked Mythic shot. Kit: `CameraMath`.
- [[29 Sound Playbook]]: ⭐ Alex's smooth-and-short sound rules, file prep (−18 LUFS), the sound ladder by moment, variety without going off-key, mixing, music, a worked coin pickup.
- [[30 UI and UX Playbook]]: ⭐ UI rules in build order, the HUD by tutorial stage, phone layout, the button recipe in Roblox parts, kid-friendly menus, feedback, accessibility, a worked Shop button.
- [[31 Big Project Playbook]]: ⭐ how to run a big build (roleplay, party games): phases with exit tests, the save file on day one, system order, threads and shared files, what to ask Alex for, a live ops calendar, what to cut.
- [[32 Round-Based Games Playbook]]: ⭐ lobby → countdown → round → results for party minigames, tag, hide-and-seek, mystery roles, horror-lite, obby races and friendly arenas; rules, per-genre table, server must-haves, a worked freeze-tag round. Kit: `Rounds`.
- [[14 Premium Feel Playbook]]: ⭐ the premium layer every game gets: staged HUD, level-up streaks, one motion table, reward beat chains, feel numbers per family, the kid-safe check, five prompts per game
- [[13 Beat Stone Skipping - Tutorial, Pacing and Feel]]: ⭐ hide the UI until the tutorial needs it, a level-up every second, spotlight the one button, chained reward beats (Oct 31 recording)
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
| A big project (plan, phases, threads, live ops) | [[31 Big Project Playbook]] |
| What to build next | [[01 Current Hits October 2026]], [[Viral Game Anatomy - Hooks, Loops and Timing]], `LihFolk/skills/roblox-trend-game/SKILL.md` |
| A game in a known family | The matching Blueprint above, then [[12 Game Loop Logic Playbook]] for pacing and numbers |
| Roleplay town (jobs, houses, cars, outfits) | [[26 Fun and Roleplay Playbook]], [[Blueprint - Roleplay Town]], `LihFolk/LihFolk Vault V2/32 Case Studies of Top Roblox Games/Case Study - Brookhaven RP.md`, `LihFolk/LihFolk Vault V2/24 Worked Builds/Weekend Build - Roleplay Town with Jobs and Paychecks.md` |
| A fun party, minigame, obby or action game | [[32 Round-Based Games Playbook]], [[26 Fun and Roleplay Playbook]], [[Game Concepts - RP and Fun]], `LihFolk/LihFolk Vault V2/43 Genre Systems End to End/` |
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
| "Press E" interactions (doors, seats, counters, job boards) | [[26 Fun and Roleplay Playbook]] | `new-game-kit/src/Shared/Interact.luau` (server check: distance, cooldown, permission, one user at a time) |
| Jobs, paychecks, houses, props (roleplay) | [[Blueprint - Roleplay Town]], LihFolk `Weekend Build - Roleplay Town with Jobs and Paychecks`, `Instanced Interiors - Pooled House and Room Copies for Many Players` | `new-game-kit/src/Server/Roleplay.luau` |
| Vehicles (spawn, drive, ownership, phone controls) | `LihFolk/LihFolk Vault V2/25 Physics and Vehicles/` (start with `Vehicle Spawner and Garage`, `Vehicle Ownership and Anti-Exploit`, `Vehicle Controls on Phone and Gamepad`) | `Roleplay.CanSpawnVehicle` |
| Avatar, outfits, uniforms | `LihFolk/LihFolk Vault V2/37 Avatars and UGC/HumanoidDescription and Outfit Systems.md`, `AvatarEditorService and In-Game Avatar Editors.md` | |
| Rounds (lobby, countdown, round, results) | [[32 Round-Based Games Playbook]] | `new-game-kit/src/Shared/Rounds.luau` |
| Camera systems | [[28 Camera Playbook]] | `new-game-kit/src/Shared/CameraMath.luau` |
| Tutorial / first 60 s | [[First-Time User Experience and Onboarding]] | Cannon Evolution `Tutorial.lua` |

## Make it look and feel good

| Job | Skill (`.claude/skills/`) | Notes |
|---|---|---|
| Map, props, lighting | `roblox-cartoony-building` | [[10 Map Design Playbook]], [[13 Cartoony & Low-Poly Building]], `reports/Cartoony Roblox building UI and animation.md` |
| UI | `roblox-cartoony-ui` | [[30 UI and UX Playbook]], [[14 Cartoony UI & Juice]] |
| Effects | `roblox-vfx` | [[11 VFX Moments Playbook]], anime style: [[15 Anime VFX and Animation Playbook]], looks cheap: [[16 Pro Animation and VFX Playbook]], like the hits: [[17 Do It Like the Hits - Animation, VFX and Feel]] + `LihFolk/skills/lihfolk-vfx`, `VFX-ITEMS.md`, [[05 VFX]] |
| Animations | `roblox-ai-animation` | [[06 Animation]] |
| Blender models | `blender-roblox-models` | [[04 Building, Maps & 3D Models]] |
| Game feel | | [[14 Premium Feel Playbook]], [[06 Beat the Hits - Polish Playbook]], `GAME-FEEL.md`, `LihFolk/LihFolk Vault V2/47 Game Feel and Juice/` |
| Match or beat a hit | | [[07 Borrow List - Game by Game]], the game's Teardown note, [[09 Owner Taste Rules]] |
| A row of tiered stations (training lanes, upgrade pads) | `roblox-cartoony-building` | [[Lesson - Tiered Training Lanes]] |
| Sound | | [[29 Sound Playbook]], [[17 Do It Like the Hits - Animation, VFX and Feel]] (sound layers), [[19 Animation and VFX Recipe Book]] (sound recipe), [[25 Rare Shot Cameras and Using a VFX Pack]] §4, `<game>/tools/sfx/make_sfx.py`, [[09 Owner Taste Rules]] |
| Camera for shots and cutscenes | `roblox-vfx` | [[28 Camera Playbook]], [[25 Rare Shot Cameras and Using a VFX Pack]] §2, [[19 Animation and VFX Recipe Book]] (chase cam, ultimate cutscene), [[22 Rare Shot VFX Spec from Alex's References]] |
| Use an effects or sound pack the owner sent | `roblox-vfx` | [[25 Rare Shot Cameras and Using a VFX Pack]] §3, [[24 Working Live in Studio - Saves, Turns and Hand Edits]] §7 |
| Lane or station looks (neon, themes, free vs gamepass) | `roblox-cartoony-building` | [[23 Training Lane Style Guide (Alex's Treadmill References)]] |
| Final check | | [[16 Cartoony Kid-Appeal Checklist]] |

## Ship it

| Job | Open |
|---|---|
| Algorithm, rules, launch steps | [[02 Launch and Discovery Cheat Sheet]] |
| Thumbnails and icon | [[Thumbnails and CTR Start Here]], [[08 Thumbnails, Icons & Marketing]] |
| Retention and come-back hooks | [[Retention and Return Hooks]], [[Live Ops Deep Dive Start Here]] |
| Money | [[21 Money and Retention at Studio Level]], [[10 Business, Monetization & Case Studies]], `LihFolk/skills/roblox-monetization-compliance/` |
| Code quality, tests, release checklist | [[18 Studio-Level Development Playbook]] |
| Installing into the owner's open Studio | [[24 Working Live in Studio - Saves, Turns and Hand Edits]] |
| AI workflow (MCP, Rojo, skills) | [[08 Few-Prompt Game Building with AI]], [[04 AI Tools Landscape October 2026]], [[01 Setup & Workflow]], [[00 Video Notes Index]] |
| New Roblox features to use | [[03 What's New on Roblox - RDC 2026 and October]] |

## Build a realistic world (RP city, hood, coastal town)

Skill: `roblox-realistic-building`. Alex's references: [[References - Realistic Worlds]]. Game design for RP: [[26 Fun and Roleplay Playbook]], [[Blueprint - Roleplay Town]].

| Job | Open |
|---|---|
| Start here: process, reading a reference, critic sheet | [[33 Realistic World Building Playbook]] |
| Lighting presets, atmosphere, day/night, graphics menu | [[34 Realistic Lighting and Atmosphere]] |
| PBR materials, MaterialVariants, wear, graffiti | [[35 Realistic Materials, Decals and Wear]] |
| The 179 picked CC0 textures (hood, downtown) and how to install them | [[40 Realistic Texture Library - Hood and Downtown]] |
| Alex's Larp photos decoded: day, pink and foggy-night presets, surface map, props, road paint, sound, game feel | [[41 Larp Reference Study - Atmosphere, Surfaces and Feel]] |
| Vice Bay references: sunset downtown, glass tower, luxury villa and realistic interiors (presets, interior lighting, luxury materials) | [[42 Vice Bay Reference Study - Downtown, Towers, Villas and Interiors]] |
| Roads, city plan, building and street kits, power lines | [[36 Roads, Blocks and City Layout Kit]] |
| Terrain, water, trees, palms, bushes, wind | [[37 Terrain, Water and Foliage]] |
| Blender export, LOD, streaming, phone budgets | [[38 Mesh Pipeline, LOD and Mobile Budgets]] |
| Ambient traffic, pedestrians, ambience sound | [[39 Living World - Traffic, NPCs and Ambience]] |
