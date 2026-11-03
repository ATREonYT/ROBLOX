---
tags: [miami-trap-life, plan, gaps, benchmarks]
updated: 2026-11-02
---
# Benchmark gap list: what it takes to reach Urban Reload, OPPS and BlockSpin

2026-11-02 · Alex: "we want to be on the same level as Urban Reload, Opps, BlockSpin… implement everything they do into the game."

Evidence: `quality/benchmarks/Benchmark Analysis - Urban Reload, OPPS, BlockSpin.md` (frames on the Mac in `~/ROBLOX/benchmarks/`), `quality/What Makes Hood RP Games Fun.md` (Tha Bronx 3, South Bronx, Da Hood, Vice City Miami), `quality/Model Sourcing Guide.md`, and the live vault code (`~/ROBLOX/Miami Trap Life/src`).

**Rule for every task: build our own version of the mechanic.** Don't copy their assets, names, UI art or text. Kid-safe rules stay: no drugs, no paid chance, no fake timers or scarcity, and nobody loses something they paid Robux for.

## Where we stand in one paragraph
We beat all three on story, tutorial, wayfinding and job feel. BlockSpin, which has 1.33B visits, wins because it has a *deep economy*: many jobs with XP skills, farming that grows while you're away, ATM hacking, a house safe, and cars you never lose. Urban Reload, a month old with 11.7k playing, wins on *combat feel*: split-body aiming animation, crouch-run, roll, tracers, kill feed and finish-to-get-paid. OPPS shows that *looks alone* (Future lighting, haze) get a launch spike but not retention when the animations are stock and the economy is thin. We have the opposite problem: rich onboarding, then an empty free roam with stock-feeling combat.

## How to read the table
**Wave** sets the order: wave 1 is what most changes how the game feels in a 10-minute session. **Owner** is the area, which the coordinator maps to a thread. Size: S ≤ 1 day, M = 2-4 days, L = a week or more. "Ref" points to the benchmark that shows it best.

---

## Wave 1: combat and movement feel (Urban Reload's bar)

| # | Task | Owner | Size | Ref | Done when |
|---|---|---|---|---|---|
| 1.1 | **Split-body aim.** While a gun is out, the legs play the run/strafe in the move direction and the waist + neck Motor6Ds rotate toward the camera look direction every frame (clamped ±70° yaw, ±45° pitch, spring-smoothed), so you can strafe or backpedal while staying on target. Replicate the aim angle at 10-15 Hz so others see it | animation | M | UR `anim/KnBi15zsgz4_pose_closeup.jpg` | Running sideways or backwards keeps the gun on the crosshair in both first- and third-person views |
| 1.2 | **Real gun animation set** (replaces `GunPose` code poses): idle hold, aim (shoulder), **high-ready on sprint** (muzzle up), low-ready pistol run, reload per gun class, equip/holster. Made in Studio's Animation Editor or Blender and uploaded to Alex's account | animation + guns | L | UR frames 03, pose close-up | Every gun has 6 clips. No code-posed arms remain |
| 1.3 | **Tactical locomotion set:** custom walk, jog, sprint (forward lean), **crouch walk** (C), crouch-run. Picked by speed and stance through an AnimationController blend | animation | M | UR crouch-run, BlockSpin crouch | Default Roblox run never plays on players |
| 1.4 | **Stamina:** sprint drains a blue bar, regen after 1 s; empty = heavy-breath SFX and walk. A drink item refills it | movement | S | BlockSpin, OPPS | Bar on HUD, breath sound on empty |
| 1.5 | **Dodge roll** (double-tap direction / gamepad B in combat): 0.45 s, i-frames 0.15 s, 1.5 s cooldown, stamina cost | movement + animation | M | UR | Rolls look grounded, and the server checks the cooldown |
| 1.6 | **Shoulder swap (Q)** and a tighter combat camera (closer in over the right shoulder while aiming) | guns | S | BlockSpin Alt Aim, UR | Q flips side with a 0.15 s ease |
| 1.7 | **Gunfire juice pass:** visible tracers on every shot (thin, bright, short-lived), bigger muzzle flash + light, shell casings, per-gun fire/tail/reload sounds (Creator Store licensed), red damage numbers (toggle), hurt vignette, hitmarker + kill confirm sound | guns | M | UR, BlockSpin | Side-by-side clip vs UR frame looks as punchy |
| 1.8 | **Kill feed** (top left) + streak popups (DOUBLE KILL, etc.) + "In combat" flag icon | HUD + guns | S | UR, BlockSpin | Kill feed shows the weapon icon; combat flag shows for 15 s after damage |
| 1.9 | **Downed → finish.** At 0 HP you go down (crawl, 12 s bleed-out); a finisher (hold E 1.5 s, neutral animation, never a stomp) or a teammate revive. Kill rewards pay **only on the finish**. Ties into the knocked state the movement thread built | guns + animation | M | UR, BlockSpin finishers | Downed players crawl; a finish pays; a revive restores 30 HP |
| 1.10 | **Healing items:** medkit (heal over 4 s, can walk slowly), armor vest (+50 armor bar), energy drink (stamina), all on the hotbar | guns + economy | S | UR, BlockSpin | Bought at a pharmacy/gas station, shown on the hotbar with counts |

## Wave 2: the economy and the reason to fight (BlockSpin's bar)

| # | Task | Owner | Size | Ref | Done when |
|---|---|---|---|---|---|
| 2.1 | **Inventory + drop on death.** A real item inventory (guns, ammo, consumables, loot, dirty cash), 15 slots. On death **while combat-flagged** you drop carried items as world pickups with stack counts. Leaving or resetting while flagged counts as death (combat log). Owned guns are a *licence* you rebuy cheaply at the Plug; Robux purchases are never lost | economy + guns | L | BlockSpin, UR, OPPS | Drops show as floating icons; log-out during combat drops too |
| 2.2 | **House safe** in the flat: 10 slots, upgradable with cash (15 / 20 / 25), plus a **repair bench** if we add durability. Store guns, loot, dirty cash | property | M | BlockSpin, OPPS, UR safe | Items in the safe survive death and rejoin |
| 2.3 | **Crime loop v1** (from the fun doc P0-1): stickups, Dre tip jobs, house licks, car boosting, ATM drill, with tiers and cooldowns. Pays dirty cash | crime loop (new thread) | L | OPPS store robbery, BlockSpin vault | At least 4 methods live, shown in the money map |
| 2.4 | **ATM hacking** with tool tiers: Basic → Pro → Elite hacking device bought from a dealer NPC, timing-bar minigame (reuse JobMinigames timing), level-gated tiers, ATM goes dark for 10 min | crime loop | M | BlockSpin | Three tools; pay scales 1× / 5× / 12× |
| 2.5 | **Skills per activity** (BlockSpin's best system): each job and crime has its own XP track (Stocker, Mechanic, Cook, Hacker, Driver, Grower) with perks every 5 levels (faster tasks, better tools, more pay, extra slots). Builds on our job ranks | economy + jobs | M | BlockSpin skills | Skills menu with a level per activity and the next perk |
| 2.6 | **Production that grows while you're away:** our version is **Reps**, bootleg tees and sneakers made on printers in the flat (needs the power on), 5-30 min timers, better machines add +40% / +70%. Plus a legal option: a **rooftop garden** (tomatoes, peppers, sunflowers) selling to Mama Dee's. Timers keep running offline | property + economy | L | BlockSpin farming ($800/plant), Vice City Reps | Two production types; collect after rejoin |
| 2.7 | **Airdrops / loot crates:** a server-wide "Supply drop by the canal in 60 s" with a map marker. The first to open it (hold 5 s) gets cash and an item. Every 12 min | crime loop + live | S | BlockSpin, OPPS | Announcement toast + marker + flare smoke |
| 2.8 | **Pawn shop** that buys any loot (TVs from licks, dropped items, fished items) for cash, with a price list in the phone | economy | S | all three | Sell UI with a stack slider |
| 2.9 | **Fishing** at the canal/docks: cast, wait, timing reel, rare fish sell high. A calm money method many players love | jobs | M | BlockSpin, OPPS | Rod tiers + 10 fish |
| 2.10 | **Multiplier box / daily cache:** one daily hidden cache in the hood (clue in the phone) that gives a 2-3× job boost for 15 min | live | S | BlockSpin boxes | Resets daily, no Robux |

## Wave 3: cars (all three)

| # | Task | Owner | Size | Ref | Done when |
|---|---|---|---|---|---|
| 3.1 | **Car ladder + dealership** (fun doc P0-4): start on a **scooter**, free work truck at jobs, dealership of 6-8 made-up cars bought directly (no crates), the Oros at the top. **Cars are never lost** | cars | M | BlockSpin scooter start, OPPS dealership | Dealership UI with a 3D turntable, test drive |
| 3.2 | **Driving feel:** handbrake (Space) **drift with tyre smoke and skid marks**, a body-roll spring, an engine sound that follows RPM, a speed readout (MPH) | cars | M | BlockSpin drift, OPPS speedo | Drift clip looks like the BlockSpin frames |
| 3.3 | **Garage customization:** paint (bought directly, no odds), rims, tint, neon underglow, headlights colour, horn, spoiler, suspension height. Saved per car | cars | L | UR garage frame | 7 categories, preview before buy |
| 3.4 | **Car lock / steal / spawn from hotbar:** your car is a hotbar slot (spawn near you), lock with L, unlocked cars can be stolen (and returned to the owner's garage on despawn) | cars | S | UR slot 5, BlockSpin | Lock icon on the HUD |
| 3.5 | **Car damage + run-over:** cars take bullet damage to a health bar (no one-shots), smoke at 25%, disabled at 0; ramming players does damage | cars + guns | M | UR, OPPS complaint | Balanced so a pistol needs ~40 hits |
| 3.6 | **Original car bodies** per the sourcing guide: replace the Urus-based Oros shape with our own, add 6+ bodies (Halcyon, Kestrel and new ones) | cars + art | L | sourcing guide | No car is a recognisable real model |

## Wave 4: guns as a collection

| # | Task | Owner | Size | Ref | Done when |
|---|---|---|---|---|---|
| 4.1 | **More guns:** add SMG (MP5-type), mini-AK, M4-type, LMG, double-barrel, sniper, and melee (bat, knuckles, knife, bottle throwable), up to 12 + 4 melee, generic names | guns | L | all three | Each with model, sounds, 6 animations |
| 4.2 | **Attachments:** sight, laser (visible beam), grip, drum mag, extended mag, suppressor, kid-safe-named auto kit on 2 guns. Bought at the Plug | guns | M | UR, BlockSpin underbarrels | Attachment screen with a 3D gun preview |
| 4.3 | **Camos and skins** bought **directly** (cash or Robux) and earned from challenges and events. No paid random cases: our version of "rare camo" is *earned* (e.g. 250 kills with the AK gives the Gold finish) | guns + monetization | M | UR camos, BlockSpin wraps | Challenge counters ("AK kills 19/250") in the Guns app |
| 4.4 | **Plug restock + stock counts:** the dealer's stock resets every 15 min server-wide, which adds a reason to go *now* (real restock, not a fake timer) | guns | S | OPPS | Shows "Restock in 11:23" and "×9 left" |
| 4.5 | **Ammo types:** standard and hollow-point (more damage, pricier) per ammo class | guns | S | OPPS | |
| 4.6 | Optional **durability** + repair at the house bench (BlockSpin/OPPS both do it). Decide with Alex; it's a money sink but adds chores | guns | S | | |

## Wave 5: HUD and menus (the "looks like a top game" layer)

| # | Task | Owner | Size | Ref | Done when |
|---|---|---|---|---|---|
| 5.1 | **HUD layout to the genre standard:** money top right (big, bold, dark box with green rim, dirty cash in red under it), health, armor and stamina bars under it; **5-slot hotbar bottom centre** (rarity colour, ammo under the gun slot, counts on consumables); ammo by the crosshair while aiming; kill feed top left | HUD | M | all three | Matches the frame layout, mobile safe areas checked |
| 5.2 | **Contextual keybind panel** bottom left that changes with state (on foot / aiming / in car / in a job), per input device | HUD | S | BlockSpin | Shows the right keys for KB, gamepad and touch |
| 5.3 | **Menu grid:** a labelled 2×4 grid (Items, Skills, Goals, Garage, Shop, Crew, Emotes, Settings) with 3D-style icons and red badges. The phone keeps story, messages, map and jobs | HUD + phone | M | OPPS/BlockSpin grids, UR column | One toggle, one tap to each screen |
| 5.4 | **Compass strip** top centre with markers (objective, crew, events) as an option next to our waypoints | HUD | S | UR | Toggle in Settings |
| 5.5 | **Death screen v2:** "Dropped by <name>" (opt-in setting; default stays kid-safe "You got dropped"), what you lost, respawn timer, a "Back to your safe" tip. **No paid revenge button** | HUD | S | OPPS (minus the paid part) | |
| 5.6 | **Floating 3D place icons** over key buildings (gun store, dealership, pawn, hospital, ATM) visible across the skyline, fading near | map + HUD | S | OPPS | Toggle in Settings |
| 5.7 | **Font and colour system:** one display face for titles and money, one clean sans for body, rarity colours (grey, green, blue, purple, gold) used everywhere | HUD | S | | Theme tokens updated |
| 5.8 | **Settings:** FPS cap unlock note, camera sensitivity, aim sensitivity, low graphics, radio volume, waypoints, damage numbers, reduced motion | HUD | S | UR, OPPS | |

## Wave 6: look (lighting, avatars, world)

| # | Task | Owner | Size | Ref | Done when |
|---|---|---|---|---|---|
| 6.1 | **Future lighting with hard sun shadows, haze, a real day-night cycle** (already gap #1 in the Quality Gap Report). Target OPPS frame `xY6uTxMZChI_frame04.jpg` by day and UR neon by night | lighting owner | M | OPPS, UR | Side-by-side with the frames |
| 6.2 | **Realistic avatar option:** offer realistic body packages and layered clothing in a character creator (height, build, face, hair) the way UR's players look; keep player avatars allowed | avatar (new) | M | UR | Creator on first join, editable at the barber/clothes store |
| 6.3 | **Free clothing store + barber** with catalog items (BlockSpin has both free; we sell some for in-game cash as a sink) | avatar | M | BlockSpin | |
| 6.4 | **Neon night dressing:** diner/motel/liquor signs, lit billboards, wet-look road at night | map | M | UR night | |
| 6.5 | **Map density pass** per the map threads (already moving) | map | — | | |

## Wave 7: social, events and monetization

| # | Task | Owner | Size | Ref | Done when |
|---|---|---|---|---|---|
| 7.1 | **Crews:** create (cash, or a small Robux pass like UR's R$299), tag in name, colour, shared waypoints, payout split, crew leaderboard | social (new) | L | UR crews/clans, OPPS | |
| 7.2 | **Leaderboards:** richest, most kills this week, best crew, top skill levels | social | S | UR | |
| 7.3 | **Trading** (player-to-player item and cash swap with a two-step confirm screen, account-age gate) | social | M | BlockSpin | Anti-scam: both sides see both offers before confirm |
| 7.4 | **Seasonal event system:** tiered quests (find 10 hidden items, do 150 of X, 250 kills) → exclusive cosmetic tiers, world decorations, a limited mode. First one: a Miami-themed holiday event | live (new) | L | UR Halloween, BlockSpin pumpkins | Event app with tiers and a countdown that's real |
| 7.5 | **Codes** box in Settings (free cash for followers/likes milestones) + **referral** reward | live | S | all three | |
| 7.6 | **Monetization that fits our rules:** Starter Pack (R$99), 2x Money/XP (have), extra safe slots, Mansion-style house upgrade (cameras, lockdown), car paint/wraps and gun camos sold **directly**, private servers, a "Plus" subscription (1.5× earnings, like BlockSpin+) if Roblox subscriptions are available to us. **Not doing:** paid random cases, paid revenge kits, guns sold for Robux that out-stat free ones | monetization | M | all three | All IDs in Config/Monetization, no "SOON" |
| 7.7 | **Anti-exploit for money:** server-authoritative drops, rate limits on every payout, AFK-farm detection (UR's zombie glitch and BlockSpin's ATM wall exploits were their biggest complaints) | quality | M | | Payouts per minute logged; outliers flagged |

---

## Suggested order across threads
1. **Now (in flight anyway):** 6.1 lighting, 1.7 gunfire juice, 5.1 HUD layout.
2. **Next:** 1.1-1.3 animation set (the biggest single "top game" signal), 1.4 stamina, 1.8 kill feed, 1.9 downed/finish.
3. **Then:** 2.1 inventory + drop, 2.2 safe, 2.3-2.4 crime loop, 3.1-3.2 car ladder and drift.
4. **Then:** 2.5 skills, 2.6 production, 4.1-4.3 guns as a collection, 3.3 garage.
5. **Then:** 7.1 crews, 7.4 events, 7.6 monetization, the rest.

## Areas nobody owns yet (for the coordinator)
- **Animation** (a dedicated thread for 1.1-1.3, 1.5, 1.9 and the gun clips), plus Alex for uploading animations to his account.
- **Crime loop** (2.3, 2.4, 2.7).
- **Economy and inventory** (2.1, 2.5, 2.8).
- **Avatar** (6.2, 6.3).
- **Social and live ops** (7.1-7.5).
