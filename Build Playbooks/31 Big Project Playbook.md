---
tags: [build-playbooks, production, planning, milestones, scope, live-ops, threads, big-projects]
updated: 2026-11-01
---

# 31 Big Project Playbook

Back to [[00 Build Router]] · Rules: repo `CLAUDE.md` "How we build" · Numbers: [[27 Studio Standard - One Sheet per Craft]] · Code and release: [[18 Studio-Level Development Playbook]] · Studio: [[24 Working Live in Studio - Saves, Turns and Hand Edits]] · Money and live ops: [[21 Money and Retention at Studio Level]]

**Why this note.** Alex said on Nov 1: "There are big projects to come", and roleplay and more fun games are next. A small +1 game can be built in a few days. A roleplay town or a round-based party game has many more systems, more art, more players at once and more ways to break. This note is the plan for running a big build: the phases, what "done" means for each, how the threads share the work, and what to cut when it runs long.

## 1. Phases and their exit tests
| Phase | Goal | Exit test (all must be true) | Typical length |
|---|---|---|---|
| **0. Pitch** | One page: the fantasy, the 30-second hook, the loop, the reference game, what we do better | Alex says yes to one of 2–3 pitches ([[Game Concepts - RP and Fun]] has examples) | 1 session |
| **1. Golden slice** | The smallest piece that proves the look and feel: one place, one action, one reward, one cinematic moment | A side-by-side with the reference; a fresh critic's worst-gaps list is short; Alex says "yes, more of this" | 1–3 days |
| **2. Core loop** | Everything a player does in the first 10 minutes works and saves | The first-session timeline matches the targets (27 §10); `check.sh` green; saves migrate | 3–7 days |
| **3. Systems** | Shop, passes, daily gifts, quests, settings, codes, leaderboards (mostly from the kit) | Kit specs green; kid-safe check green; every unbuilt item says "Coming soon" | 3–7 days |
| **4. Content** | Zones, maps, items, modes, the reward ladder | Each piece passes the ten-line review (27 §12); phone budget holds with a full server | 1–3 weeks |
| **5. Soft launch** | Real players on a small scale (unlisted, or a small ad test) | D1 and first-play bounce measured; top errors in `ErrorLog` fixed; no purchase bugs | 3–7 days |
| **6. Launch** | Public, with a thumbnail set and an update plan | The launch checklist in [[02 Launch and Discovery Cheat Sheet]] | 1 day |
| **7. Live** | Weekly updates on a fixed weekday | A 4-week update calendar (§6) is written before launch | ongoing |

**Never skip phase 1.** A full build that misses the look wastes days (repo rule 1).

## 2. Plan the save file on day one
Big games die from save problems. Before phase 2:
- Write the **save schema** (what is saved, its type, its default) in the game's `CLAUDE.md`.
- Start at `version = 1` and add a migration for every change (note 18 §11 A). Keep a fixture of an old save and test that it still loads (the kit's "old saves still load" check).
- Decide what is **per server** (a claimed house in a roleplay town, a round's score) and what is **saved** (owned furniture, outfits, coins, level).
- Purchases: one ProcessReceipt, granted once per PurchaseId, "granted" only after the save.

## 3. Build systems in this order
1. Data and saving (`PlayerData`), then currency (`Currency`).
2. The core action and its reward (the game's own code).
3. The HUD with stages (`HudStages`), and the message line.
4. Server checks for every interaction (`Interact`), and rate limits on every remote (`Net`, `RateLimit`).
5. The shop and receipts (`Shop`, `Receipts`), with "Coming soon" for anything not built.
6. Return hooks (`DailyRewards`, `PlaytimeGifts`, `Quests`, `Codes`).
7. Genre systems: rounds (`Rounds`), roleplay rules (`Roleplay`), eggs and pets (`EggHatch`, `Pets`), rebirth (`Rebirth`).
8. Live tools: `Flags` (kill switches), `ErrorLog`, leaderboards.
9. Polish passes by craft (27 §1–§10), one craft at a time.

## 4. Sharing the work between threads
- **One thread per system or craft**, with a clear owner. Name them by the goal ("Make training lanes like Stone Skipping").
- **Shared files have one owner.** The Router, `CLAUDE.md`, the game's `CLAUDE.md` and the save schema each have one thread that edits them; others ask.
- **One thread in Studio at a time** (note 24 §3), installing narrow pieces, and saying "Studio is free" when done.
- **Merge rule** (repo rule 6): copy only the files a thread changed onto the current HEAD; never an older copy of a file that changed since.
- **One PR per piece of work**, small enough for Alex to try in one sitting. Stack PRs on one base branch when they depend on each other.

## 5. What to ask Alex for, and when
Ask early so the art and IDs never block the build:
| When | Ask for |
|---|---|
| Pitch | The reference game and 1–3 clips or pictures they love |
| Golden slice | UI kit or mockup pictures (`design/`), icon PNGs ≥ 256 px |
| Systems | Gamepass and product IDs after they create them (never invent them); the uploaded sound and image IDs |
| Content | Any models or packs they want used, as files |
| Soft launch | Publish, a private test server with friends, and a phone test |

Keep a running **"Alex-only steps" checklist** in the game's README, with exact clicks.

## 6. Live ops calendar (write it before launch)
| Week | Update | Why it brings players back |
|---|---|---|
| 1 | Fixes from launch, one new code, a thank-you gift | Shows the game is alive |
| 2 | A small content drop (a zone, a mode, 5 items) | Something new to see |
| 3 | A weekend event that reuses the map (a collectible hunt with milestone rewards) | Cheap to build, rewards exploring |
| 4 | A bigger drop (a new world or a new system) | The headline for thumbnails |

Ship on the **same weekday** every week, and switch events on and off with `Flags`, not a new publish.

## 7. When it runs long: what to cut
Cut in this order, and say plainly what was cut:
1. Extra content (fewer zones, fewer items). Players forgive less content more than broken content.
2. Secondary systems (trading, a second currency, a battle pass).
3. Extra modes or maps (ship 3 good ones, not 8 thin ones).
4. **Never cut:** save safety, the purchase rules, kid-safe rules, phone performance or the first 60 seconds.

## 8. Risk list (check every week)
| Risk | Sign | Action |
|---|---|---|
| Saves break | Any "load failed" in `ErrorLog` | Stop content work; fix and add a test |
| The phone is slow | Client scripts over 2 ms, particles over 300, crashes over 2–3% | A performance pass before more content |
| The look drifts from the reference | Alex asks for changes twice on the same thing | A fresh side-by-side and a critic pass |
| Studio work isn't in git | A Studio-only diff exists | Pull it back the same day (note 24 §5) |
| Scope grows | The phase's exit test keeps moving | Write the cut list (§7) and ask Alex once |

## 9. Checklist for starting a big project
- [ ] A one-page pitch Alex picked.
- [ ] The golden slice planned with its side-by-side and critic.
- [ ] The save schema written, version 1, with a fixture.
- [ ] The system order (§3) and one owner per thread and shared file.
- [ ] The Alex-only checklist started.
- [ ] A 4-week live ops calendar drafted before launch.
