---
tags: [miami-trap-life, research, benchmarks]
updated: 2026-11-02
---
# Benchmark analysis: Urban Reload, OPPS, BlockSpin

The reference images live on Alex's Mac in `~/ROBLOX/benchmarks/` (27 MB). There are 17 gameplay videos with 10 frames each at 1280 px, 8 fps animation bursts in each `anim/` folder, store data in `store.md`/`store.json`, and `index.md`. Eight of the 17 transcripts were saved. YouTube rate-limited the rest. The store screenshots couldn't be downloaded because the sandbox blocks `thumbnails.roblox.com`.
**Seen** means visible in a frame, **said** means from a transcript, and anything unmarked is inference.

## The 10 frames to look at first
| File | What it shows |
|---|---|
| `urban-reload/anim/KnBi15zsgz4_pose_closeup.jpg` | **The animation reference.** Four rifle poses: the upper body aims while the legs run sideways or backwards, a deep crouch-run, and a high-ready sprint |
| `urban-reload/KnBi15zsgz4_frame03.jpg` | The full combat HUD: money, health and stamina top right, compass top centre, kill feed top left, a 5-slot hotbar with ammo, a menu column on the right, a laser tracer |
| `urban-reload/-7znNlx-GQQ_frame02.jpg` | Garage: neons $150k, headlights $100k, wheels, spoilers, suspension, paint with posted odds |
| `urban-reload/fl-Q6vVplXg_frame06.jpg` | Weapon-case kiosk ($5k–30k, three tiers, odds, "drop it on death unless protected slot") |
| `urban-reload/EVh64L6Xxi4_frame01.jpg` | Instant-cash store: R$1,499 = $1M up to R$29,999 = $100M |
| `opps/0W6SYkfwqKE_frame01.jpg` | Gun shop with dual prices (Glock R$59 or $900), restock timer, stock counts |
| `opps/0W6SYkfwqKE_frame10.jpg` | Death screen: "Killed by", a paid "Get Revenge?" (Glock + 20 ammo), Respawn |
| `opps/xY6uTxMZChI_frame04.jpg` | Future lighting with hard shadows, gun hold, left 2×4 menu grid, round hotbar |
| `blockspin/IcXpnBlWjkU_frame02.jpg` | Legendary case odds (AWP 0.051% … M24 6.076%) |
| `blockspin/OlhizsSLv1g_frame04.jpg` | Night firefight, contextual keybind panel, ammo by the crosshair, "In Combat" skull |
Runners-up: `urban-reload/-7znNlx-GQQ_frame09.jpg` (safe inventory), `blockspin/3AGJU4b5g9o_frame10.jpg` (farming skill tree), `urban-reload/ueoyuJdCGGk_frame01.jpg` (Halloween event tiers).

---

## 1. Urban Reload (Squad Labs): tactical PvP in grey New York
- **Store:** 11,710 playing, 8.3M visits in 4 weeks (created 2026-10-05), 85.4% likes, 20-player servers, avg session 9.9 min. Pitch: "Tactical PvP in a city where every street is a fight… You lose your weapons, so play smart… Realistic guns, attachments and rare camos." Universe 10769552054, place 84448037861644.
- **Loop:** spawn → fight players or farm NPC zombies in a walled Farm Zone (no vehicles allowed) → buy weapon cases → fight with better guns. No jobs, no robberies. Starting cash $15,000.
- **Kills pay, but only on the finish.** Said: "Knocking an enemy down isn't enough. You need to finish them to receive money." Seen: +$2,500 per player kill, +$3,250 for a loot kill, +$960 to +$5,680 per zombie.
- **Death:** knock-down, then finish, then ragdoll. You drop your weapons and others loot them. A **Safe** window has "YOUR ITEMS 13/50" plus protected safe slots, and "+10 Safe" is a pass.
- **Cars:** the car sits in hotbar slot 5 and spawns from there. Starter hatchback, then up to a Cayenne-style SUV and a Lambo. The **garage** sells paint, wheels, neons ($150k), headlights ($100k), spoilers, horns and suspension, and paint colours come from odds (Pink 2.65%). Running players over works, and cars take damage.
- **Guns:** AK/AR, M4, M60, SPAS-12, an SMG with an underbarrel, pistol, and melee (bat, baton, knuckles). **Cases $5k–30k** (Basic, Normal, Legendary) with posted odds. Camos (gold, leopard, flame, galaxy), optics, grips, lasers. Coloured tracers, a big muzzle flash, kill feed top left, DOUBLE KILL popups, and "PLAYER KILLS 19/1,000" challenge counters. Medkit (heals over time, you can move), Kevlar, and an "E-Drink".
- **Movement:** sprint with stamina, crouch, **roll**, climbing buildings. There's a "movement player" skill meta, and players unlock 240 FPS and tune sensitivity.
- **Animation (best of the three):** the lower body plays the run/strafe in the movement direction, and the upper body twists toward the camera (procedural Waist/Neck rotation layered on the locomotion clip). Custom deep crouch-run, high-ready rifle pose while sprinting, two-handed shoulder hold while firing, pistol held low and forward. Tight over-right-shoulder camera. Realistic R15 bodies with layered clothing.
- **HUD:** money top right in a dark box with a green border and a serif font; red health bar (150 HP), blue stamina bar and a skull streak count under it. Compass strip top centre. Kill feed top left. Five square hotbar slots at the bottom centre with rarity colours and ammo under the gun slot, plus a big "30 / ∞" at the bottom right. A right-edge column of icon buttons (Inventory, Shop, Effects, Crew, Clan, Emotes, Event) with key hints and red badges. "Hold ALT to free your cursor." A green SAFE ZONE pill.
- **Look:** grey overcast NYC by day; by night, blue ambient light with neon (diner, motel, billboard). Halloween pink sky. Dense and grungy with real textures: elevated subway, brownstones, chain-link, graffiti.
- **Social:** Crews (R$299 pass), Clans (R$499), both for R$799, clan leaderboards, crew tags in names.
- **Event:** Halloween tiers (find 10 ghosts, 150 pumpkin zombies, 250 player kills) → Grim Reaper skin → Shadow → Inverted.
- **Money:** passes Starter Pack R$99, Skip case animation R$499, Crew R$299, Clan R$499, Crew+Clan R$799. Instant-cash dev products R$1,499 / R$6,999 / R$29,999. A creator-code field.
- **Loved:** the movement and PvP skill ceiling, and controller support. **Hated:** an AFK zombie money glitch.

## 2. OPPS ("#1 Hood" group): LA hood sandbox with a YouTuber cast
- **Store:** 279 playing now (it peaked on YouTuber launch videos), 3.7M visits since 2026-08-14, 79.4% likes, 50-player servers.
- **Loop:** tutorial janitor job (said: "Did we just get paid $7, bro?") → buy a gun → rob stores ("The convenience store is being robbed") and the jeweller, kill and loot players ("they got 500,000 off of me") → store loot in a rented house's safe → craft and upgrade. Also a pawn shop, fishing, a crafting bench (Silver Fishing Rod), shootable loot crates in the street, and a cop role.
- **Death:** you drop your loot. The death screen shows "Killed by <name>", a paid **Get Revenge?** pack (Glock + 20 ammo, ~R$27), and Respawn.
- **House:** rented for $100. It has a safe and a **gun repair bench**, because guns have **durability**, shown as a ring around each hotbar icon.
- **Cars:** **car crates** at the dealership (Basic → Trackhawk, Rare → Hellcat, Elite → Lambo/McLaren); "It took all my money… the Low Rider is the worst one." MPH speedometer bottom left with lock, horn and headlight icons. Drive-bys are core. Car damage is inconsistent ("this car is literally one shot").
- **Guns:** a shop with a **restock timer** and stock counts, and **dual price** (Glock R$59 or $900, P226 R$69 or $900). Glock, revolver, Draco, MP5, AK, shotgun, sniper, crossbow, RPG; a flamethrower is coming. Ammo by rarity (Shotgun Ammo Epic $350, Explosive Ammo Legendary $1,500), vests, skin crates. Red damage numbers.
- **Movement:** sprint with stamina, hiding in bushes. **Animations are stock R15** with a basic tool hold.
- **HUD:** very minimal. A small green money pill top right with two tiny status icons. **Round** hotbar slots with durability rings. A **left 2×4 labelled grid** (Items, Quests, Skills, Crews, Store, Emotes, Settings, Codes) with glossy 3D icons. Floating 3D waypoint icons over the skyline. Nametags read "@handle / Name / Lv. 0". Gotham-like sans font. Settings include radio, low graphics, waypoints and reduced motion.
- **Look:** **Future lighting with hard shadows, haze, a full day-night cycle**, PBR asphalt with real road markings, palms, strip malls, a gas station, a jeweller, an ammo store, a dealership, motels, overpasses, a beach. Classic blocky avatars.
- **Money:** guns for Robux, the revenge pack, car crates, skin crates, paid emotes, paid crew creation, private-server upsell.
- **Loved:** "one of the best hood games out on Roblox right now". **Hated:** snipers, one-shot cars, being backdoored. Lesson: stock animations and a thin economy made it lose players right after launch.

## 3. BlockSpin (Cinnamon Go!): the market leader, GTA-lite in Florida
- **Store:** 24,772 playing, **1.33 billion visits**, 1.0M favorites, 78.8% likes, 28-player servers, live since 2024-11. "Grind your way through jobs to unbox random reward cases… You drop everything in your inventory on death, place items into the safe in your house."
- **Loop:** job → cash → cases (guns and cars) → house + safe → PvP and robbery, with **skills** (XP per activity) gating better tools. Said: "it's literally GTA but on Roblox."
- **Money:**
  - **Jobs:** Janitor ($9–18 a puddle) and Shelf Stocker (seen "+$770 · +774 Shelf Stocker XP · complete in 5.24 s"), Burger Spot.
  - **ATM hacking:** a dealer in the alley sells a Basic Hack Tool for $10, then Pro for $150, then Ultimate. Better tools are level-gated, and each hack is a timing bar.
  - **Farming (the meta):** rent a house, buy soil and seeds, plant in pots. Sunflower: water once, 15 min, $800 a plant. Corn takes 1 h and tomato 24 h. Golden pots add +40% and diamond +70%, and premium soil stacks to +90%. Farming skill unlocks fertiliser (level 40) and an extra pot slot (level 45).
  - **Multiplier boxes:** 25× with a 6-hour cooldown.
  - **Card swiping**, which is fraud plus chance.
  - **Bank vault robbery:** a live money ticker shows $167,955.
  - **Airdrops** ("Large Crate will drop by the Graveyard in 60 s"), fishing and a pawn shop.
- **Death:** you drop all items if you're combat-flagged. **Vehicles are never lost.** Loot spills out as floating icons with stack counts.
- **House:** rented (later free) from the mailbox. It has a **safe** (11 slots, upgradable to 23) that can store vehicles, and a **workbench** for durability. The **Mansion** pass adds lockdown and security cameras.
- **Cars:** crates from $540. You start on a **mobility scooter** or ATV, then Mustangs, an Urus, a Humvee, a Cullinan. Handbrake **drift with heavy tyre smoke**. Speed number at the top centre. Lock and horn. Cars can be stolen if you leave them unlocked. Halloween **wrap** cases ($25k with posted odds), Robux wraps and underglow.
- **Guns:** 5 weapon crates with posted odds (legendary: AWP 0.051% … M24 6.076%), Uzi, M249, M60, Glock, Draco, RPG, plus melee (knife, axe, shovel, wrench, bottle). Ammo crates, durability, throwable bottles. Red hitmarkers, damage numbers, a hurt vignette, ammo next to the crosshair. **Alt Aim (Q)** swaps the camera shoulder. **Finishers** on downed players.
- **Movement:** sprint with stamina (Bull Energy drink $40 gives +40 stamina and speed), heavy breathing SFX, crouch, ladders and rooftops.
- **Animation:** blocky R15 with a simple two-handed hold, the camera pulls in over the shoulder on aim, a forward lean on sprint, a low crouch-walk, finishers.
- **HUD:** a big cash-stack icon with a bold white $ figure in a dark rounded box with a green rim, top right, with green health and blue stamina bars under it. A right 2×4 grid of 3D icons (Items, Skills, Quests, Store, Crews, Emotes, Codes). Small square hotbar at the bottom centre. **A contextual keybind list at the bottom left** that changes with what you're doing (on foot: Sprint, Aim, Alt Aim, Reload, Crouch; in a car: Handbrake, Exit). An "In Combat" skull, toasts at the bottom. Blackletter/serif panel titles.
- **Shops:** free clothing store and free barber (named cuts), hospital blood bags ($100, +50 HP), a gas-station counter, a case "Buy Case?" popup with odds, item reveal on a pedestal.
- **Look:** bright Florida daylight, soft shadows, haze, orange sunsets, dark nights with headlight cones. Clean modern stucco, glossy floors, PBR asphalt with skid marks. Blocky player avatars.
- **Social:** crews, land fights, trading, level badges.
- **Event:** Halloween wraps, pumpkin bombs, and a "smash 25 pumpkins" quest for $10k.
- **Money:** BlockSpin+ subscription (1.5× earnings), Mansion pass, Robux wraps, explosives bundles, dev products. No game passes listed.
- **Loved:** "GTA on Roblox", the farming grind, high-stakes loot. **Hated:** exploiters, getting killed while AFK, lag, wall exploits at ATMs.

---

## Comparison
| | Urban Reload | OPPS | BlockSpin | **Hood Life today** |
|---|---|---|---|---|
| Players / visits | 11.7k / 8.3M | 279 / 3.7M | 24.8k / 1.33B | not live |
| Server size | 20 | 50 | 28 | 60 (plan: 30–40) |
| Avatars | realistic R15 + layered clothes | blocky | blocky | player avatars; NPCs from catalog outfits |
| Money | PvP kills + zombie farm | janitor, robbing, looting | jobs + skills, farming, ATM hacking | 9 jobs with ranks; one story robbery |
| Death | drop guns, finish to get paid | drop loot, revenge pack | drop items if in combat; cars kept | nothing lost; "dropped" screen |
| Storage | safe slots | house safe + repair | house safe (11→23) + bench + cameras | flat with no storage |
| Guns | cases, camos, attachments | shop with restock, durability | cases, durability, throwables | 5 guns bought at the Plug, no attachments |
| Cars | hotbar spawn, deep garage | car crates | crates, scooter start, drift, wraps | one SUV for everyone, no garage upgrades |
| Movement | sprint, crouch, roll, climb | sprint | sprint, stamina drink, crouch | sprint (no stamina, crouch or roll) |
| Animation | split-body aim, custom stances | stock | simple + finishers | arms posed in code (GunPose), no clips |
| Camera | tight right shoulder | default | shoulder on aim, Q swaps side | third-person over-shoulder on aim |
| HUD | right icon column, compass, kill feed | minimal, left grid, 3D waypoints | right grid, keybind panel | cash and level top, phone bottom right, objective line |
| Lighting | overcast / neon night | Future, hard shadows, haze | bright, soft, sunsets | being reworked (gap report: too saturated) |
| Social | crews, clans, leaderboards | crews, voice | crews, trading, levels | none |
| Live event | Halloween tiers | — | Halloween wraps + quests | none |
