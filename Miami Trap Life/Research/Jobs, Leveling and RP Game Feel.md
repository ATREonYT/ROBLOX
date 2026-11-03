---
tags: [miami-trap-life, research, jobs, progression, game-feel]
updated: 2026-11-01
---
# Jobs, leveling and RP game feel

Back to [[00 Master Plan]] · Also read `new-game-kit/GAME-FEEL.md` (measured lessons from Huzz Valley).

## Why jobs in RP games feel like chores, and how to avoid it
- A job is fun when each task is **short (8–20 s), readable at a glance, and ends with a reward pop** (cash + XP numbers flying to the HUD). A job is a chore when you wait with nothing to do.
- **Variety inside a shift:** rotate 3–4 task types so no task repeats more than twice in a row.
- **Physical feedback:** the shelf actually fills, the spill actually shrinks as you mop, the bin lid slams. The world changing is the reward.
- **Visible progress:** a shift bar ("Shift 6/10 tasks") and the level bar both move after every task. A bonus at the end of the shift (+25%) gives a natural stopping point and a reason to do "one more".
- **Social:** other players doing the same job in the same place is good (co-workers). Tasks are per player, so nobody steals your task.

## Task minigame types (reusable for every job)
| Type | How it plays | Supermarket | Mechanic | Restaurant |
|---|---|---|---|---|
| Carry | pick up a box, walk it to a zone (box in hands, slower walk) | restock: box from the back to the shelf | carry a tire to the car | carry a tray to a table |
| Hold | hold the button while a ring fills; release early = small penalty | mop a spill (spill shrinks) | jack up the car | grill a patty |
| Timing bar | press when the needle is in the green zone (3 presses) | price-gun items | tighten lug nuts | flip the patty |
| Sequence | tap 3–4 items in the right order shown on a card | — | oil change steps | assemble the burger order |
Each type is one module the Jobs thread writes once and reuses with different props and text.

## Leveling (feel)
- XP pop at the task ("+20 XP") and the HUD bar fills with a smooth tween; at level-up: banner "LEVEL 3", short sound, a ring of light around the character, and a phone ping listing what unlocked.
- Fast early, slower later: Level 2 in ~1 min, Level 5 in ~10 min, Level 10 in ~1 hour, then long-tail.
- **Unlock something every level** in the first 10 (a job, an app, a phone case, a location on the map, a mission). An empty level-up is a wasted moment.
- AFK-able jobs at higher levels pay more per minute but need a short check-in every ~2 minutes (pay pauses, no kick). This rewards progress without making the game a pure AFK farm.

## RP game feel (the world)
- **The phone is the hub.** Everything social or story-related arrives through it: texts, calls, the job app, the GPS. This keeps the screen clean and feels like real life (and like GTA).
- **The city reacts:** NPC customers walk into the Food Mart during your shift, the clerk you worked with is behind the counter during the robbery ("...wait, I know you"). Recognition moments make the story feel personal.
- **Contrast sells the come-up:** the flat in the Ends is filthy, dark and broken (no power), so every upgrade later feels huge. The first property sets the baseline.
- **Next goal always visible:** after moving in, the Goals app lists "Pay the power bill ($300) → your PC works", "Buy your first car", "Next crew job". The power bill is a perfect first free-play goal: it ties back to the gag.

## Monetization that doesn't feel cheap
- Offer passes **at the moment they make sense** (2x Money right after you see your first big payout), not on join.
- Every offer card is dismissable with one clear "No thanks", has no timers and no fake scarcity (kid-safe rules in [[CLAUDE]]).
- Passes are boosts, not walls: the story is fully playable for free.

## Roblox content rules to respect
- Guns, robbery and gang themes are allowed with the right **content maturity label** (likely "Moderate" for realistic violence) on the experience questionnaire. Fill it in honestly before publishing.
- **Drug content is not allowed.** "Trapping" in game must stay abstract: sell "packs", flip stolen goods, resell sneakers/phones. Never show or name drugs.
- No real gang names or real people.

## What Piece 2 actually built (and why)
- **One thing to do at a time.** The server hands out one task step; the client shows it three ways at once: the panel line ("Grab a box from the stockroom"), a floating marker, and a pulsing gold ring + light column on the floor at the spot. Breadcrumbs only when the spot is more than 60 studs away (inside a store they're noise).
- **Coach line the first two times** a player meets a task ("Hold to mop. Let go and the spill creeps back."), then it disappears. Teaches without a tutorial screen.
- **The world changes because of you:** products pop onto the shelf one by one as the hold fills, the spill shrinks under the mop, the full bag sits by the bin until you lift it, suds/sizzle particles while you scrub/grill, price tags pop on each timing hit. All local, so tasks are per player.
- **You carry what you're moving** (box, bag, tire, tray, keys, crate) as a real welded prop everyone sees, and walk a bit slower. Co-workers see each other working.
- **Juice on every beat:** a little click rhythm while holding (pitch rises with progress), hit pings that climb in pitch, a shake + red flash on a miss, a punch-scale on the panel, a ring burst at the station when done, "+$8" and "+22 XP" flying from the spot into the HUD counters, PERFECT flourish, level-up rings of light.
- **Fair minigames:** letting go of a hold drains it (60% speed) instead of resetting; timing zones move and speed up slightly per hit; sequences use number keys / gamepad selection too. Scores only nudge pay (+25% / -20%), never fail you.
- **Natural stopping points:** shift card every 8 tasks with a bonus from Level 3. The story shift hides "Clock out" so the first 10 minutes can't be abandoned by accident.
- **AFK done honestly:** post jobs pay every 30 s inside a visible ring; a "Still on post?" card every 2 min pauses pay until answered (no kick, no punishment).
