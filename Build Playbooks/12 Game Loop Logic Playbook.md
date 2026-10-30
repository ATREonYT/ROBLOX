---
tags: [build-playbooks, game-design, core-loop, economy, pacing, systems]
updated: 2026-10-30
---

# 12 Game Loop Logic Playbook

Back to [[00 Build Router]] · Family blueprints: [[Blueprint - Plus One Evolution]], [[Blueprint - Egg Run]], [[Blueprint - Plus One Speed Escape]], [[Blueprint - Roll and Place RNG]] · Numbers from the hits: [[Teardown - Stone Skipping]], [[07 Borrow List - Game by Game]] · Economy and saving APIs: [[Brief - Saving, Economy and Monetization]] · Retention and growth: [[Brief - Game Design, Retention and Growth]]

**Goal (owner, Oct 30):** very good game loops from few prompts. The steps:
1. pick the loop family (§2);
2. set the pacing targets (§3);
3. derive the numbers with the formulas (§4);
4. build on the system template (§5);
5. prove the pacing with a simulation before anyone plays (§6).

## 1. Anatomy of a loop that holds kids
Every hit stacks **three loops**, and each must pay off on its own clock:

| Loop | Clock | Stone Skipping [M] | +1 Cannon Evolution [R] |
|---|---|---|---|
| **Second loop** (the verb) | 1–5 s | Throw, then +1 Skill per bounce | Shoot at a station (+Power per shot), launch |
| **Minute loop** (the goal) | 30 s – 3 min | Reach the next zone; buy the next stone; level up | Next zone on the track; next upgrade; next cannon |
| **Session loop** (the reset) | 2 – 30 min | Rebirth (×2 Skill), new pads, a new world portal | Rebirth (+50% Power, +25% Cash), a new station |
| **Return loop** | Hours / days | Playtime gifts (4 h), 7-day daily, events, weekly worlds | Daily, playtime, missions, codes |

**Rules:**
- **Something goes up every few seconds.** If a player can't see a number move for 5 s, the loop is broken.
- **Always show the next goal** and how far you are from it (a bar, "94%", "needs 10K").
- **Every reset makes the next run visibly faster.** Rebirth must feel like a power-up, not a punishment: show Before → After.
- **Two currencies:** the stat opens gates, the payout buys things. Never let one buy the other directly. (Stat packs for Robux are the exception that monetises the gap.)
- **Never punish a bad attempt.** A short throw still pays a little (the "brain off" feel, Grow a Garden). [W]

## 2. Loop families (state machines to copy)
**A. +1 Launch/Throw** (Stone Skipping, Cannon Evolution)
```text
Lobby ─walk─► Station (Training) ─leave─► Lobby ─walk in─► LaunchZone
  ▲                                                        │ server: distance = f(stat), payout = g(distance)
  └─ hard cut home ◄── Result (0.6 s) ◄── Flight (3–14 s) ◄┘
Spend: upgrades / cannons / balls / eggs.  Reset: Rebirth (stat→0, payout→0, ×mult up, new station).
```
**B. Egg Run** (Steal an Egg): `Base ─► Treadmill (+speed) ─► Biome (grab egg) ─► run home (risk) ─► Pen (hatch) ─► income/s ─► upgrades`

**C. Stage lane** (+1 Superhero/Muscle/Speed): `Train (+stat) ─► Stage n gate (stat ≥ need) ─► fight/run ─► end pad (+Wins, teleport home) ─► buy evolution ─► Rebirth`

**D. Roll & place** (Anime Dice, Sol's RNG): `Roll (luck) ─► unit ─► place on plot ─► income/s ─► luck upgrades ─► better rolls`

**Server-side, each state is one value per player** (`State = "Lobby" | "Training" | "Flight" | …`). Every action checks the state first, so a client can't skip one. Cannon does this with `TrainingState` and the launch lock (`LAUNCH_COOLDOWN`, `FLIGHT_TIMEOUT`).

## 3. Pacing targets (time from join, a fresh save, playing well)
| Beat | Target | Reference |
|---|---|---|
| First number goes up | ≤ 5 s | Stone Skipping: training at spawn [M] |
| First payoff (launch/throw) | ≤ 30 s | ~40 s after the cutscene [M] |
| First purchase affordable | after the 2nd payoff (~60 s) | New stone at ~55 s [M] |
| First rebirth | ≤ 90 s (tutorial ends on it) | ~85 s [M] |
| Rebirth 2 | 2–3 min | |
| Rebirth n | T(n) ≈ T(1) × 1.5–1.8ⁿ⁻¹ | Cannon Config: R1 ~1 min, R5 ~10 min, R10 ~1.5 h [R] |
| New zone or world | about every 1–2 rebirths | Cannon: zones ×1.3–1.4 apart [R] |
| First egg hatch | ≤ 3 min (a free egg from a playtime gift) | Playtime gift eggs [M] |
| Session | 15–25 min with 3–5 milestones | Steal an Egg averages ~15 min [W player.one] |
| World 1 complete | 25–30 min (owner's call for Hood) to 2+ h (Stone Skipping) | [R][W] |

## 4. Economy formulas (put every number in Config; see Cannon `GameConfig.lua`)
```lua
-- Geometric cost: each step costs g times the last.
Cost(n) = base * g^n                          -- upgrades g 1.15–1.5; rebirth g 2.5–3.5
-- Time to a goal at the current rate:
TimeTo(goal) = (goal - have) / ratePerSecond
-- Rebirth pacing: time grows by (cost growth) / (rate growth) per rebirth.
TimeGrowth = REBIRTH_GROWTH / RateGrowthPerRebirth   -- target 1.5–1.8
-- Multipliers: ADD within one source, MULTIPLY across sources.
PowerMult = (1 + rebirths*0.5) * (1 + sum(petBoosts)) * passMult * boostMult * levelMult
```
- **Rate growth per rebirth** comes from the rebirth bonus, the newly unlocked station, and pets.
  - Cannon: stations gain ×2.5 every 2 rebirths (1, 3, 8, 20, 50, 125, 300), about ×1.6 per rebirth, plus +50% per rebirth on top.
  - Rebirth cost ×3.2 per rebirth, so time grows about ×1.6–1.9 per rebirth. On target.
- **Payout from distance:** linear in distance (Cannon: Cash = 0.25 per stud). Distance grows like √stat (Cannon: speed = 180 + 1.6·√Power, capped at 1900), so stat gains feel big early and taper. The cap stops the lane running out; add worlds before players hit it.
- **Zone borders** sit where each rebirth's typical distance lands, so every rebirth reveals about one new zone. Rule: `border(k) = border(1) × 1.35^(k-1)`.
- **Egg ladder:** price ×40–×250 per tier, with the top pet's odds at 0.1–3% ([R] +1 Muscle). Pet boosts ≈ the egg price ratio^0.5, so a new egg is worth it but doesn't skip a whole world.
- **Level multiplier** (Stone Skipping): Level from the total stat; Multiplier ×1.1 at Lv 6 up to ×111 at Lv 115 [W]. It's a second number that always climbs. Borrow it.
- **Rare outcomes:** 1/100 (×5) and 1/1000 (×25) rolls on the verb. Expected value +9%: small enough not to break pacing, big enough to scream about.
- **Offline earnings:** cap at 8–12 h and pay 25–50% of the online rate, or it replaces playing.
- **Big numbers:** format as 1.2K, 3.4M, 5.6B, 7.8T, Qa, Qi (`Config.Format`). Above ~1e15, store them as {mantissa, exponent} ([[Big Numbers Precision and Formatting]]).

## 5. System template (server decides, client draws)
Copy Cannon Evolution's shape for any loop game:

| Piece | File in Cannon | Rule |
|---|---|---|
| Config (every number, item, price, odds, text) | `src/shared/GameConfig.lua` | Server and client read the same table, so the UI always matches the rules |
| Server: data, saving, all rules | `src/server/GameServer.server.lua` | ProfileStore/DataStore with reconcile against `DefaultData`; autosave 90 s; save on leave |
| One action entry point | `Request` RemoteFunction: `(action, ...) -> ok, message` | An action table: `Actions.BuyUpgrade = function(player, data, id) … end`. Validate types, state, cost and cooldown in every handler |
| State push | `Sync` RemoteEvent with the data snapshot after each change | The client never computes rewards; it shows the snapshot |
| Moment events | `LaunchPlayer`, `LaunchResult`, `Hatched`, `Rewarded`, `Unlocked` | One event per moment, so the client can play the juice |
| Client state mirror | `GameClient/State.lua` | Read-only copy plus derived values |
| One module per screen | `GameClient/Shop.lua`, `Pets.lua`, `Rebirth.lua`… | Each reads State and calls Request |
| Purchases | one ProcessReceipt, grant once per PurchaseId, "granted" only after the save | Repo `CLAUDE.md` Never list |

Action handler pattern (Luau):
```lua
Actions.Rebirth = function(player, data)
	if profiles[player].State ~= "Lobby" then return false, "Finish your launch first" end
	local needPower, needCash = Config.RebirthCost(data.Rebirths)
	if data.Power < needPower or data.Cash < needCash then return false, "Not enough yet" end
	data.Rebirths += 1
	data.Power, data.Cash = 0, 0
	Unlocked:FireClient(player, "REBIRTH #" .. data.Rebirths, "Rebirth", "x" .. Config.PowerMultiplier(data) .. " Power")
	return true
end
```
Reusable kit versions of each system (Currency, Rebirth, EggHatch, Shop, Receipts, DailyRewards, Codes, Quests, Leaderboard, Inventory) are in `new-game-kit/examples/`.

## 6. Prove the loop before a human plays it
- **Pacing sim** (Lune, offline): a bot that plays optimally from a fresh save. Every simulated second it trains, launches when ready, buys the best upgrade or egg, and rebirths when it can. Log the time of each beat in §3 and **fail the check if any beat misses its target by more than 30%**. Put it in `tools/check.sh` (new-game-kit has the harness; Hood and Huzz Valley run full-loop sims).
- **Rule specs:** cost formulas, odds that sum to 100%, rebirth resets the right fields, pity counter, offline cap.
- **A Studio playtest** with the MCP playtest subagent: "fresh save, follow the tutorial, report the time to first rebirth".
- **After launch:** Roblox's funnel events and retention (D1/D7) in Creator Analytics; A/B test the first rebirth price with Experiments ([[Brief - Game Design, Retention and Growth]]).

## 7. Loop checklist
- [ ] Three loops (second / minute / session) plus a return loop, each with a visible payoff
- [ ] A number moves at least every 5 s; the next goal is always shown with progress
- [ ] Pacing sim passes every §3 beat within 30%
- [ ] Rebirth time grows ×1.5–1.8 per rebirth; a new zone about every 1–2 rebirths
- [ ] Multipliers add within a source and multiply across sources; no single pass skips a world
- [ ] All rules live on the server, with state checks; the client only asks and shows
- [ ] Every number is in Config; the UI reads the same Config
- [ ] Kid-safe: odds shown, pity counter, no fake timers, nothing sold that does nothing yet
