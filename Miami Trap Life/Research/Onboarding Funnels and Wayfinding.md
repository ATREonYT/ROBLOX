---
tags: [miami-trap-life, research, onboarding, funnel, ftue]
updated: 2026-11-01
---
# Onboarding funnels and wayfinding

Back to [[00 Master Plan]]

## The principles (Roblox docs + what top RP games do)
- **Get to the fun fast.** New players decide within minutes, most of the drop-off happens in the first ~90 seconds. Our first action (walk into the Food Mart and do a task) must happen within **20 seconds** of spawning. ([Roblox onboarding docs](https://create.roblox.com/docs/production/game-design/onboarding), [rowatcher](https://rowatcher.com/news/your-first-90-seconds-are-destroying-roblox-retention))
- **Teach by doing, not by reading.** In-world cues beat text: a lit path, an arrow, an NPC walking where you should go. Show what a mechanic does first, explain later.
- **Early levels come fast.** Low XP thresholds at the start (our Level 2 in ~1 minute, Level 5 in ~10).
- **Always show the next goal** (short, mid and long term) and end the first session on a high point (the robbery payout + moving into your own place).
- **Never block the player behind text.** No lore walls, no unskippable dialogue (players learn to click through it anyway).
- **Measure it.** Log every story stage as an onboarding funnel step on the server and fix the step where people drop.

## Our funnel tools (one consistent language, so players learn it once)
1. **Objective line** (top centre, one line, always present): "Restock the cereal shelf", "Go to the meet: Liberty Motel · 220 m". Same spot and style every time.
2. **Waypoint marker**: a floating 3D marker over the target with the distance, clamped to the screen edge with an arrow when off-screen.
3. **Ground breadcrumbs**: a line of glowing chevrons on the ground from the player to the target, built from `PathfindingService` waypoints (recomputed every ~1.5 s or when the player strays > 12 studs). This is the "you cannot get lost" layer. Fades out within 10 studs of the target.
4. **Target highlight**: `Highlight` instance (outline only) on the door/shelf/car/bed you need, pulsing gently (no flashing; max 1 pulse/s).
5. **Phone ping**: when the next step comes from the story (a text, a call), the phone peeks up a little higher with a badge, then lowers. Players learn "phone moved = something for me".
6. **Arrival**: a soft chime + the objective line ticks off with a check, the next one slides in.

Rules: only **one** active story waypoint at a time (job tasks can add small local markers). Never stack three arrows on screen. Every waypoint is set by the server (`Waypoint` remote) from `Config/Locations.lua` positions, because StreamingEnabled may not have streamed the target part in yet.

## Funnel per story step (what the player sees)
| Step | Cue |
|---|---|
| Spawn → Food Mart | Phone text from Mr. Patel + breadcrumbs to the door (12 studs away) + door highlight |
| Each job task | Objective line names the task + a marker on the shelf/spill/bin + a hold/minigame prompt at it |
| Level 5 → the call | Phone rises by itself into the incoming-call screen. If declined: Recents shows "Unknown (missed)" with a red dot, and the objective line says "Call back the unknown number" |
| The meet | Waypoint + breadcrumbs + distance. Meet spot gets a car with hazard lights and the crew standing around (visible from far away) |
| Robbery | Each step: objective line + one marker. "Put on the mask" (prompt on the car), "Go in", "Get the register open", "Grab the cash", "Get out", "Drive to the drop-off" |
| Buy the flat | Crew text with a picture-link → tapping it sets the waypoint. Buy prompt at the door shows the price you can now afford |
| Choose job | The cutscene ends with the phone already open on the Jobs app. Three big cards: picture, pay, distance from home, "CHOOSE". Nothing else on screen |
| Sleep | Bed highlight + "Get some sleep. Work starts tomorrow." |
| Commute | Wake up → phone alarm text "Shift starts at Westside Auto. 340 m" + waypoint + breadcrumbs. On arrival: "Clock in" prompt, glowing |

## Analytics (server only, only works in the published game)
```lua
-- step numbers = the story stage index in Master Plan §1
AnalyticsService:LogOnboardingFunnelStepEvent(player, 1, "Arrive")
AnalyticsService:LogOnboardingFunnelStepEvent(player, 2, "FirstShift")
...
-- recurring flows (shop, job app) use LogFunnelStepEvent(player, "JobApp", sessionGuid, step, name)
-- money: AnalyticsService:LogEconomyEvent(...) inside EconomyService, for every source and sink
```
Notes: steps are logged once per player (repeats are ignored for the funnel but count against the rate limit); skipped earlier steps count as done; up to 10 funnels on the dashboard. ([Funnel events docs](https://create.roblox.com/docs/production/analytics/funnel-events))

## Things to A/B test later (Roblox Experiments)
- Start cash ($50 vs $100).
- Breadcrumbs always on vs only after 20 s without progress.
- Level 5 vs Level 4 for the call.

Sources: [Roblox onboarding](https://create.roblox.com/docs/production/game-design/onboarding), [Funnel events](https://create.roblox.com/docs/production/analytics/funnel-events), [Improving onboarding through funnel events](https://devforum.roblox.com/t/3064458), [Onboarding without tutorials](https://rowatcher.com/news/onboarding-without-tutorials-teaching-through-play-in-roblox).

## What we built (Piece 4: flat → job → commute)
The rule we followed: **at every moment there is exactly one thing to do, and three ways to see it** (objective line, a world cue, the phone).
| Step | Objective line | World cue | Phone / screen |
|---|---|---|---|
| Buy the flat | "Buy the flat in the Ends: $1,200" | breadcrumbs + pulsing outline + a "FOR SALE · $1,200" sign over the door (visible from 600 studs) | Dre's 2 texts; the FOR SALE card pops up by itself at the door (BUY, or "You need $X more") |
| Move in | (cutscene) | — | the phone rises by itself on Jobs when the scene ends |
| Pick a job | "Pick a job on your phone" | — | "STEP 1 OF 2", 3 cards, one CHOOSE each, a confirm, then "YOU'RE HIRED · STEP 2 OF 2"; a gentle banner every 25 s if the phone is put away |
| Sleep | "Get some sleep. Work starts tomorrow." | the bed outlined + a "Sleep" marker + prompt | the hired screen says "Your bed is glowing. Walk over and press E" (tap / X on other devices) |
| Leave for work | "Head out to work: use the front door" | the front door outlined + a marker | the boss's good-morning text |
| Commute | "Get to work: Westside Auto Repair" | Story waypoint + breadcrumbs (distance on the marker) | GPS app still works |
| Clock in | "Clock in at the time clock" | the job's clock-in marker (Jobs piece) | Jobs app "Clock in" button |
| Free play | "Goal: Finish a full shift (0 / 1)" | — | the Goals app (unlocks with a ping) |
Distances in the Jobs app are measured from your front door while you're inside (rooms are instanced far away). Returning players wake up inside their own room.
