---
tags: [build-playbooks, realistic-rp, city-rp, start-here]
updated: 2026-11-01
---

# 00 Start Here - Realistic City RP

Back to [[00 Build Router]] · Why RP is fun: [[26 Fun and Roleplay Playbook]] · Kid-town version: [[Blueprint - Roleplay Town]] · Map look: the world-building notes from the "Learn realistic Roblox world building" thread

This folder is how realistic city / hood / county roleplay games **work under the hood**: the systems, the numbers, the code shape and the rules that keep them safe and fair. It is written so a fresh session can build each system without re-researching. Everything here is our own wording and our own code; the games named are studied for how they *feel*, never copied (names, maps, logos, item names stay theirs).

## What Alex showed us (screenshot teardown, 2026-11-01)

Alex's screenshots are a realistic West-Coast-style hood RP (sun-bleached asphalt, palms, graffiti, power lines, parked sedans) plus a Florida-county style town (fire station, palms, suburban houses). On screen:

| What you see | What it is | Note |
|---|---|---|
| Big green **$1,105** pill, top right | Pocket **cash** on the HUD (bank lives in the phone) | [[02 Economy, Jobs, Stores and Inventory]] |
| Round dark icons floating over buildings: briefcase, bank, hospital, fuel pump, barber pole, T-shirt, gun, car, wrench, house, "24" store | **World icons**: every service in town marked in 3D, readable from across the street | [[01 HUD, World Icons and Interaction]] |
| Gold ring on the ground near the player | A **job / interaction spot** (stand here and press) | [[01 HUD, World Icons and Interaction]] |
| Running-man button and heart button | **Sprint** toggle (with stamina ring) and **health** | [[05 Health, Stamina, Sprint and Knockouts]] |
| One slot "1" with a fist | A **custom hotbar** (Roblox backpack hidden), fists always in slot 1 | [[04 Combat - Fists, Weapons and Server Hit Validation]] |
| "Starter Pack · 199 R$ · 22:20" | A **first-session offer** with a countdown | [[12 Money - Starter Packs, Passes and Offers]] (we do it without a countdown) |
| Name tag with a level under it ("alex · Lv 0") | Overhead tag with **level / rank** | [[01 HUD, World Icons and Interaction]] |
| Leaf + sun icons, bottom right | **Season and weather** indicators | [[09 Day-Night, Weather and a Living City]] |
| Square "apps" button, left | Opens the **phone / menu** | [[07 Phone, Apps and Banking]] |

## The genre in one paragraph

A realistic RP is a **city that pays you to live in it**. You spawn with a little cash, pick a legal job (or an opt-in crime path), earn, and spend on things other players can *see*: cars, clothes, a house, a better phone, a bigger garage. Police, medics and mechanics exist because the other players need them. The best ones make every system touch another: a robbery creates a 911 call, which spawns a police chase, which wrecks a car, which feeds the mechanic and the tow truck. Most of the fun is **other players**; the systems exist to give them reasons to meet.

## Who is winning (live check, 2026-11-01)

| Game (study only) | What it's best at | What to learn |
|---|---|---|
| Emergency Response: Liberty County | Services RP: police, fire, DOT, K-9, boats; a 2026 map update doubled the map | Jobs that need *each other*; vehicle depth; trunk inventory per team |
| Southwest Florida / West Coast Florida | Driving + jobs + dealership + criminal ranks | Crime ranks unlock bigger targets (diner → supermarket → bank); 80 s robbery timers, 300 s cooldowns |
| Tha Bronx 3, South Bronx, Da Hood-likes | Hood vibe, PvP, buy-a-gun, money grind | Strong HUD identity, fast cash feedback, cheap starter gear. **Also their problems:** constant PvP on public servers, slow "mop" jobs, Discord-application police (all fixed in [[13 Beat the Top RP Games]]) |
| Brookhaven, Berry Avenue | Zero-friction life sim | Own a house/car in seconds; no grind gate on fun |
| Jailbreak | Cops vs robbers loop | Arrest/escape tension, bounties, heists on timers |
| Sochi County, Roanoke VA, Nizhegorodskiy | Ultra-realistic county | Realism in roads, signs, traffic laws, sirens |

Sources: [Top 25 RP games, Oct 2026](https://mygamedesk.com/top-25-roblox-roleplay-rp-games/), [ER:LC Map Update 2026 log](https://devforum.roblox.com/t/emergency-response-liberty-county-map-update-2026-update-log/4897775), [Southwest Florida criminal guide](https://sportskeeda.com/roblox-news/southwest-florida-criminal-guide), [Tha Bronx 3 fan guide](https://tha-bronx-3.pages.dev/guides/how-to-play/). Player numbers move weekly; re-check before using them in a pitch.

## The rules box (read before building anything)

**Age rating.** Roblox's Maturity & Compliance labels ([Creator Docs](https://create.roblox.com/docs/production/promotion/content-maturity), read 2026-11-01):
- Realistic-looking guns that hurt people = **"non-graphic, realistic-looking violence" → Moderate**. Even *one* realistic moment counts. Moderate is a 13+ label. Keep it **non-graphic**: no blood pools, no gore, knockouts instead of corpses where we can.
- **Light realistic blood** is also Moderate; heavy realistic blood is Restricted (18+ ID-verified). We use **no blood** at all.
- **Alcohol** (even a bar sign with bottles), **strong language**, **romance** → Restricted 18+. Keep them out.
- **Drugs** are banned on Roblox at *every* age, including 18+ ([Restricted Content Policy](https://en.help.roblox.com/hc/en-us/articles/15869919570708-Restricted-Content-Policy)): no "trap house", no "plug", no dealing, no smoking. Many hood games hint at this; we don't.
- **Playable gambling** is banned (dice, casinos, card games for money).
- A game whose main activity is chatting is a **social hangout (16+)**, with private spaces (lockable bedrooms, bathrooms) **18+ ID-verified**. Our city must be **gameplay-first**: jobs with real tasks, events, progression.
- Every new game starts 16+ until selection (Sector Brief Game Design). Fill the questionnaire honestly; aim for **Moderate** with no other descriptors.

**Our project rules still apply** (`CLAUDE.md`): never invent asset/product ids (leave 0 with a note); purchases granted only on the server, once, after the save; at most 1 flash per second; no fake timers or scarcity; paid random items show odds. A hood theme is a *look*, not a licence to drop these.

**Originality.** Fictional brands for guns, cars and stores (no "Glock", no real car makers, no real fast-food chains); our own map, our own icons. No real-world gang names, colours-as-gang-signs or real neighbourhood shootings. No illegal gun modifications (auto "switches") as items.

## The systems map (what touches what)

```text
                      ┌───────────── Phone (bank, jobs, GPS, garage, 911, messages) ──────────────┐
                      │                                                                           │
 spawn ─► HUD (cash, sprint, health, hotbar, world icons) ─► walk / drive ─► ProximityPrompt at a place
                                                                                │
        ┌───────────────┬──────────────┬────────────────┬──────────────────────┼───────────────────┐
        ▼               ▼              ▼                ▼                      ▼                   ▼
   Job task         Store /         Dealership /     House / property     Crime (opt-in)       Hospital /
   (server-seen)    counter         garage / pump    (claim, decorate)    → Wanted heat        respawn
        │               │              │                                       │
        ▼               ▼              ▼                                       ▼
   Wallet.Earn      Wallet.Pay      Garage + Wallet                     911 call → Police → chase → arrest → jail (10-60 s)
        │                                                                      │
        └────────────── PlayerData (one save, session-locked) ◄────────────────┘
                     day/night clock · city events · traffic & pedestrians (client-only)
```

## Build order (golden slice first)

1. **Slice (1 week):** one street block, spawn, HUD (cash, sprint, health, hotbar with fists), 6 world icons, one job, one store, one car, phone with Bank + GPS. Prove the *feel* on a phone. Get Alex's yes.
2. **Economy spine:** `Wallet`, PlayerData schema, ATMs, paychecks, 3 jobs, 4 stores, inventory + hotbar.
3. **Vehicles:** dealership, garage spawn from phone, fuel + gas station, mechanic, impound.
4. **Combat + health:** fists, 3 weapons, knockouts and hospital respawn, safe zones, new-player protection.
5. **Crime + police (opt-in):** wanted heat, 911 calls, cuffs, jail, 3 robbery types on cooldowns.
6. **Houses:** claim, furniture placing, garage at home.
7. **Living city:** day/night, traffic and pedestrians, weather, city events.
8. **Money + live ops:** starter pack, passes, private servers, weekly updates.
9. **Hardening:** streaming pass, perf budget, anti-exploit review, save fixtures, kill switches.

## The notes in this folder

| # | Note | Kit code |
|---|---|---|
| 01 | [[01 HUD, World Icons and Interaction]] | `Shared/Markers.luau`, `Shared/Interact.luau` |
| 02 | [[02 Economy, Jobs, Stores and Inventory]] | `Server/Wallet.luau`, `Server/Roleplay.luau`, `Server/Inventory.luau` |
| 03 | [[03 Vehicles - Driving, Dealership, Garage and Fuel]] | `Server/Garage.luau`, `Roleplay.CanSpawnVehicle` |
| 04 | [[04 Combat - Fists, Weapons and Server Hit Validation]] | `Shared/HitCheck.luau` |
| 05 | [[05 Health, Stamina, Sprint and Knockouts]] | `Shared/Stamina.luau` |
| 06 | [[06 Houses and Property]] | `Roleplay.Houses` |
| 07 | [[07 Phone, Apps and Banking]] | `Wallet.Transfer`, `WorldClock.Label` |
| 08 | [[08 Crime, Police and Wanted Levels]] | `Server/Wanted.luau` |
| 09 | [[09 Day-Night, Weather and a Living City]] | `Shared/WorldClock.luau` |
| 10 | [[10 Saving, Anti-Exploit and Admin]] | `Server/PlayerData.luau`, `Shared/Net.luau`, `Shared/RateLimit.luau` |
| 11 | [[11 Streaming and Performance for a City]] | — |
| 12 | [[12 Money - Starter Packs, Passes and Offers]] | `Shared/Offers.luau`, `Server/Receipts.luau` |
| 13 | [[13 Beat the Top RP Games]] | — |

Older notes this builds on (don't repeat them, link them): LihFolk `10 Game Design and Genres/Genre Playbook - Open-World City and Crime Roleplay`, `25 Physics and Vehicles/*` (20 notes on chassis, spawners, streaming cars), `22 Anti-Exploit and Security/*`, `24 Worked Builds/Weekend Build - Roleplay Town with Jobs and Paychecks`.

## Starting numbers (one table to tune)

| Thing | Start | Why |
|---|---|---|
| Server size | 40 (try 50 once perf is proven) | Enough for police + crime + jobs to all have people |
| Starting cash | $1,000 cash, $0 bank | Matches the genre; buys a first item in minute 1 |
| First paycheck | within 90 s of starting a job | The first "cha-ching" must come fast |
| Job pay | $60-$150 per task, tasks 20-60 s | ~$6k-$12k per hour of real work |
| First car | $4,000 (a ~30-40 min goal) or a free starter beater | A car is the first big want |
| Walk / sprint | 16 / 24 studs/s, 8 s of sprint | Cars stay faster; on foot stays tactical |
| Knockout cash drop | 10% of pocket cash, max $5,000 | Bank is safe; pocket cash is the risk |
| Jail | 12 s per star, 10-60 s | Nobody sits out of the game |
| Day / night | 14 min / 6 min | Night is a mood, not half the session |
| Robbery | 60-90 s hold, 5 min cooldown per store | Gives police time to arrive |
| City event | every 6-8 min | Something to do together, always |
