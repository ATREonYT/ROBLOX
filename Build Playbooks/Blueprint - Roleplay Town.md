---
tags: [build-playbooks, blueprint, roleplay, social, town]
updated: 2026-11-01
---

# Blueprint - Roleplay Town

Back to [[00 Build Router]] · Why it's fun: [[26 Fun and Roleplay Playbook]] · Concepts to pick from: [[Game Concepts - RP and Fun]]

**Code:** start from [[05 New Game Kit]] (`sh new-game-kit/tools/new_game.sh`), then add kit `Server/Roleplay.luau` (jobs, paychecks, house book, car and prop caps, jail) and `Shared/Interact.luau` (the one server check for every "press E"). Build only the town's own toys, jobs and map.

**One line:** spawn in a small, bright town, get a free house, car and job in 30 seconds, and play out stories with other players using toys that work in one press. One twist makes it ours (see the concepts note).

Reference games (learn feel, don't copy): Brookhaven RP (breadth, zero friction), Bloxburg (depth), Berry Avenue and LifeTogether (careers, phone menu), Emergency Hamburg (services). Related older notes: `LihFolk/LihFolk Vault V2/24 Worked Builds/Weekend Build - Roleplay Town with Jobs and Paychecks.md`, `10 Game Design and Genres/Genre Playbook - Roleplay and Social Hangouts.md`.

## 0. Age-rating check (day 1, before anything else)
- A game Roblox classes as a **social hangout is 16+**; a hangout with **private spaces (lockable rooms, bedrooms, bathrooms) is ID-verified 18+**; hangouts are excluded by default from Roblox Kids and Select ([[Policy and Age Rules 2026]]).
- So this town must be **gameplay-first**: jobs with real tasks, town events, a pet or rank to raise. Write down the main goal in one sentence that is not "hang out".
- Fill the Maturity & Compliance questionnaire honestly and aim for **Minimal or Mild**. Every new game starts 16+ only until selection (Sector Brief Game Design).
- Keep kit house locking **off** (`Houses.LockingAllowed = false`). No bedrooms, bathrooms or lockable rooms on the map.

## 1. Pick the twist (day 1, one sentence)
A plain town loses to Brookhaven. Pick one twist that changes *what you do*, not only the theme: "the weather changes the town every 5 minutes", "every job rescues pets", "the whole town is toy-sized in a giant garden". Write it on the thumbnail.

## 2. Core loop and first 30 seconds
```text
spawn on busy plaza ─► job board glows ─► pick job (outfit pops on, tag over head)
      ─► arrow to free house ─► keys + car appear in driveway (sting)
      ─► play: do job tasks for others  |  decorate house  |  drive friends  |  join a town event
      ─► paycheck for work seen (every 3 min) ─► buy furniture, outfits, car colours
      ─► weekly: new toy drop + map event ─► come back
```
- Own **3 things in 30 s** (house, car, job). No tutorial screens; arrows and one glowing button at a time ([[13 Beat Stone Skipping - Tutorial, Pacing and Feel]]).
- A job task takes **20-60 s** and is **3 presses deep** (pick up, do, hand over).
- A **town event every 4-6 minutes** (fire, parade, delivery rush, weather) so 6 players still have something to do together.

## 3. Systems (build in this order)
| # | System | Kit / note |
|---|---|---|
| 1 | Spawn plaza, 8-12 buildings, loop road, ambient life | [[10 Map Design Playbook]] |
| 2 | Interact: doors, seats, switches, mailbox, horn (all one press) | `Shared/Interact.luau` |
| 3 | Job board + caps + job tags + outfits | `Roleplay.CanJoin`, `Roleplay.Paycheck` |
| 4 | House book: claim, guests, kick, release on leave (locking stays off) | `Roleplay` house book; instanced interiors note |
| 5 | Cars: one each, server cap 20, cooldown, Replace (swapping your own car works even on a full server) | `Roleplay.CanSpawnVehicle` |
| 6 | Job tasks (one tool and one customer each) + self-serve events | [[26 Fun and Roleplay Playbook]] §4 |
| 7 | Emote wheel + Quick Words | Creator Hub > Configure > Chat |
| 8 | Phone menu (jobs, house, cars, outfits, map, friends) | [[14 Premium Feel Playbook]] staged HUD |
| 9 | Furniture placing with prop cap 40 | `Roleplay.CanPlaceProp` |
| 10 | Saving (houses, cars, outfits, ranks, layout) | `Server/PlayerData.luau` |
| 11 | Shop: premium houses, vehicle pack, outfit pack, emote pack, private servers | `Server/Shop.luau`, [[21 Money and Retention at Studio Level]] |
| 12 | Flags for every toy, block/report, filter on all text | `Shared/Flags.luau`, [[18 Studio-Level Development Playbook]] |

## 4. Starting numbers (tune in playtests)
| Thing | Start |
|---|---|
| Server size | 30-40 |
| Map | walkable edge to edge in ~90 s; driveable in ~30 s |
| Paycheck | every 180 s, only if a job action happened in that window |
| Job cap | police and crime roles ≤ 25% each of the server |
| Cars | 1 per player, 20 per server, 10 s cooldown, despawn after 2 min unused |
| Props | 40 per player |
| Jail | 10-60 s, only for players who picked a crime role |
| Town event | every 4-6 min, 60-120 s long |
| Day/night | 20 min cycle |
| New toy drop | weekly, 6 planned before launch |

## 5. Safety for a kids' town (must pass before launch)
- Homes are play spaces: kitchen, garage, garden, playroom, pets. No bedrooms, bathrooms or lockable rooms, no romance or carry emotes (private spaces push a hangout to ID-verified 18+).
- All sign and name text through Roblox filtering; no user images or drawings.
- Opt-in roles for any chase, jail or fling. Block and report in the phone menu.
- `python3 tools/kidsafe_check.py <game>` and [[Policy and Age Rules 2026]].

## 6. Weekly updates (plan 6 before launch)
New vehicle · new house style · new job with a new tool · seasonal map event · new pet or emote pack · a town-wide mini-event (parade, race, talent show).

## 7. Done when
- A new player owns house, car and job within 30 s, on a phone.
- 6 players in one server find something to do together within 60 s, with chat off.
- Every door, seat and switch passes the door test ([[26 Fun and Roleplay Playbook]] §12).
- Feel test in [[06 Beat the Hits - Polish Playbook]] §9 and the kid-safe check pass.
