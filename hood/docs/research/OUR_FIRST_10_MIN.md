# Our first 10 minutes, as a brand-new kid (audit, Oct 27)

This audit follows the owner's feedback on HEAD 0bf71fdb: "the tutorial isn't good, the feel of the game feels rushed, there is no flow, there aren't any welcoming traits". It is an audit only; nothing in the game was changed.

## How this was measured

- **The first 30 s:** the real server and client scripts in the offline harness, using `first30` (feel_base's setup plus `route.luau`). It is a fresh save, and the kid follows every hint. Times are "kid seconds" from the spawn.
- **Minutes 1 to 10:** the pacing sim (`tools/pacing/pacing.luau`, the "focused" player), plus the rules in the code: `GoalRules`, `LevelRules`, `HudExtrasRules`, `RetentionRules` and `TutorialRules`. The harness walk only covers about 2 minutes. `feel_base`'s own fight step is out of date: it saw no knock-out for 12 s and never cleared Stage 1. So its later steps (the pads, the box and the rebirth) ran on fast-forwarded numbers, and I used them only for what the screen shows.
- **Not measured:** how anything sounds (the game is silent, see problem 1), and real Studio timing (the harness runs slower than real time).

## Timeline

| When | What the kid sees | Hears | Is told |
|---|---|---|---|
| 0 s | The loading cover: dark navy, "+1 HOOD EVOLUTION" in yellow, "Getting your look ready...", a bar, then "Ready!". It shows for at least 0.6 s and at most 12 s, then fades in 0.4 s. Then the lobby, facing the Stage 1 gate, with the full HUD at once: about 25 labels, including x2 Cash, x2 Speed, x2 Power, Auto Fight, Shop, Starter Pack, Friend Boost +0%, Playtime and Missions 0/3. | Nothing. `Sound.Enabled = false`; only Roblox's own footsteps play. | Nothing yet. |
| 1-3 s | White arrows on the floor to BAY 1, "TRAIN x1 HERE ↓" over the lane, and the goal tracker. The first click fires: "+1 POWER", then a "Level 1 > Level 2" toast with a yellow bloom. | Silence. | Hint: "Walk into **BAY 1**!" (typed by 2.5 s). Goal: "NEXT GOAL +2 / Reach Level 6 in BAY 1 / on the left, it shoots for you". That is four guides saying the same thing. |
| 4-6 s | In BAY 1 at 4.2 s; the lane fires for the kid and Power goes 3 → 6. At 5.7 s the goal is met: **GOAL DONE! +2 Cash**. | Silence. | "BAY 1 shoots for you!" is still typing when GOAL DONE already says "NEXT GOAL: Walk to Stage 1". |
| 10 s | Walking up the middle to the gate (the white arrows swing to it). The GOAL DONE band is just fading. | Silence. | "Go to **STAGE 1**!" (typed at 7.9-8.4 s). |
| 11-14 s | Through the gate at 11.1 s. Another GOAL DONE (+3) and "3 LEFT" both appear. The first hit lands at 12.4 s, and all 3 goons are down at 13.7 s, then "CLEAR!" and "STAGE 2 OPEN!". | Silence. | "**Hold click** to shoot the crew!" is fully typed at 12.1 s, so the fight lasts 1.3 s after the instruction. |
| 14-20 s | "Step on the **yellow pad**!" at 14.3 s, then GOAL DONE (+5) at 14.8 s. On the pad at 18.6 s: a +20 Cash cash-out cinematic and a teleport of 94 studs back to the lobby. At 20.1 s, GOAL DONE (+5) and "Buy a gun". | Silence. | Three instructions in six seconds. |
| 22-24 s | The kid steps on the Snub Revolver pad and it is bought instantly. "NEW GUN!" pops, with the notice "Bought Snub Revolver! / x2 Power per shot". At 24.3 s another GOAL DONE (+5): "Beat Stage 2 and cash out". | Silence. | |
| 27.5 s | **The tutorial is over** (`OnboardingStep = Done`). Stage 2's crew walks in ("Hold click to shoot!") and is down by 29.6 s. | Silence. | No "you did it" or "tutorial complete" moment. |
| 30 s | The gold GoalGuide arrow and floor chevrons take over. The tracker says "Beat Stage 2 and cash out". | Silence. | |
| ~35 s | (computed) Level 10 at Power 37 brings the **RANK UP!** screen: Rookie → Street Kid, +40 Cash, about 2 s. | Silence. | |
| 1 min | Stage 2 cleared (sim: 1.0 min). Back to training for Stage 3, which needs 150 Power. Level toasts keep coming. | Silence. | |
| 2 min | Street Uzi bought (1.2 min), Stage 3 at 1.7 min with GOAL DONE +25, next goal "Rebirth!". The side goal "Open a shoe box" also appears. | Silence. | |
| 3 min | Stage 4 at 2.9 min, the Pump Shotgun at 3.0 min, and RANK UP to Hustler (Level 16, Power 437). | Silence. | |
| 3-4.3 min | **The first long wait:** about 80 s standing in a lane until the rebirth bar fills (Stage 5 needs 2,400, the rebirth 1,000). It is silent and no one says why. | Silence. | |
| 4.3 min | **First rebirth.** The one boxed lesson: the world dims, then "Open **REBIRTH**!", "Click **REBIRTH**!", "Now go **train** again!" (3.2 s). Then the rebirth moment: "Rebirth 1!", x1 > x2. Power drops to 0, and the level toasts start again from Level 1. | Silence. | The first explanation of anything (in the Rebirth window: "Rebirth resets your power"). |
| 5 min | Playtime gift 1 is ready (+300 Cash): a red "!" on the Playtime button, to be claimed in a window. The 5-minute quiet window ends, so a "2x Power 15 min" offer card can now show after 30 s at a lane, and after a knock-out. | Silence. | |
| 5-10 min | Stage 5 at 6.0 min, the Tommy Gun at 6.1, Stage 6 at 7.3, rebirth 2 at 7.4 (BAY 2 opens), Stage 7 at 8.7, RANK UP Enforcer at about 8 min, playtime gift 2 at 10:00, rebirth 3 at 10.4. | Silence. | |

In 10 minutes the kid gets **about 17 big moments**: 7 stages, 3 rebirths, 4 guns, 3 rank-ups and 2 playtime gifts. That is one every 35 s, on top of a level toast every few seconds.

## Every popup in the first 10 minutes

| Popup | Text | How long |
|---|---|---|
| Loading cover | "+1 HOOD EVOLUTION" / "Getting your look ready..." / "Ready!" | 0.6-12 s, then a 0.4 s fade |
| Tutorial hint (bottom centre, dark box) | "Walk into BAY 1!", "BAY 1 shoots for you!", "Go to STAGE 1!", "Hold click to shoot the crew!", "Step on the yellow pad!" (the gift step "Grab your free gift!" is off) | Typed at 32 characters/s; stays while its step lasts (3 s at most for the fight hint) |
| Goal tracker (top centre) | "NEXT GOAL +N" / the goal / where | Always on |
| GOAL DONE moment | "GOAL DONE! +N Cash" / "NEXT GOAL: ..." | About 4.5 s (pop in, 0.9 s, 2.9 s, 0.45 s out); 5 of them between 5.7 s and 24.3 s |
| Level-up toast | "Level a > Level b" (merges while levels keep coming), a 0.25 s yellow bloom, and a gold burst at most every 3 s | About 1-2 s; levels come every 1.5x Power, so 7 in the first 30 s |
| Rank up | "RANK UP!" / "Rookie > Street Kid" plus 2 reward cards and "Press to Close" | 2.0 s |
| HUD notices | "Bought Snub Revolver! / x2 Power per shot", "Need N more Power!", "This lane opens with the Pro Bay pass (Store)" | 3.5 s; 3 at most stacked |
| Fight HUD | "3 LEFT" with a skull, "CLEAR!", "STAGE 2 OPEN!", "Hold click to shoot!" | During the fight; CLEAR! is held a moment |
| Stage banner | "+N Cash / Run banked!" | 1.8 s + 0.45 s |
| Cash-out cinematic | "+20" and a teleport to the lobby | About 1-2 s |
| "NEW GUN!" pop | "NEW GUN!" | Under 1 s |
| Unboxing | The box drops on a rooftop, wobbles and pops; the shoe rises; "tap to continue" | 4.75 s (a Cash box), 8.5-10 s (a Robux box) |
| Rebirth lesson | "Open REBIRTH!" → "Click REBIRTH!" → "Now go train again!" | Until done; the last line 3.2 s; gives up after 15 s |
| Rebirth moment | "Rebirth 1!" / x1 > x2 / a line about it being forever | A few seconds |
| Playtime badge | A red "!" | Until claimed |
| Offer card (from 5 min) | "2x Power 15 min" with its real price and an X | Until closed; once per 15 min (lane) / 5 min (knock-out) |

## Waiting with nothing happening

- **First 30 s: none.** The harness found no gap over 5 s. That is part of the problem: there is no rest at all.
- **About 3:00 to 4:20:** around 80 s in a lane before the first rebirth, in silence, with no reason given.
- **After each rebirth:** Power is back to 0 and the kid trains again; another 1-2 minutes in the lane between rebirth 1 and 2.

## Things fighting for attention

| When | What overlaps |
|---|---|
| 1-2 s | Four guides for one action (hint, floor arrows, "TRAIN x1 HERE ↓", the goal tracker), plus a "Level 1 > Level 2" toast and a bloom from the first click |
| 5.7 s | GOAL DONE pops while the hint is still typing a lesson that no longer applies, plus level toasts and a burst |
| 11.2 s | GOAL DONE (+3), "3 LEFT" and the fight hint typing, all at the gate |
| 13.7-15 s | "CLEAR!", "STAGE 2 OPEN!", the yellow-pad hint and GOAL DONE (+5) within 1.1 s |
| 18.6-20.6 s | The cash-out cinematic, the teleport, GOAL DONE (+5) and the new goal "Buy a gun" |
| 22-24.3 s | "NEW GUN!", the "Bought Snub Revolver!" notice, GOAL DONE (+5) and the new goal |
| From 5 min | The playtime "!" and the offer card on top of the rank-ups and level toasts |

## Words of text

- **The tutorial itself:** 36 words in total (6 hints, 28 words; the rebirth lesson, 8 words). The word count is not the problem.
- **Everything on screen in the first 30 s:** about 130 words, counting the goal lines, the GOAL DONE repeats, the notices and the level toasts. That is over 4 words a second for a kid who is also walking and shooting.
- **What the words never say:** what Power is, what Cash is for, why gates need Power, or that the lane keeps working while you stand there. The first explanation of anything is the rebirth window at 4.3 min.

## Welcome moment

There is none:

- no greeting, no title card, no player name;
- no camera intro (Tutorial.client: "No cutscene, no intro");
- no music and no sound (everything is off; only Roblox's footsteps play);
- no free gift (`Features.WelcomeGift = false`; the gift step and its unboxing are skipped).

**How the first reward lands:** "+1 POWER" from a stray click at the spawn (1.8 s). Then **+2 Cash in a GOAL DONE band at 5.7 s**, for a goal ("Reach Level 6") the kid did not knowingly try for. It is silent, and it lands on top of the hint.

## The four firsts

- **First gate (11 s):** walking through the gate counts as a goal (+3), and the crew of 3 starts at once, with no "incoming" beat. The whole fight takes 1.3 s from the first hit. The gate sign reads "STAGE 1 / Recommended / Power: 10".
- **First gun (22 s):** the kid steps on the pad and the gun is bought instantly, with no confirm and no moment to look at it. "NEW GUN!", the notice and GOAL DONE all land within 2 s, and the tutorial ends 5 s later.
- **First box (from about 25 s; never prompted in the tutorial):** the kid has 30 Cash after the gun, and the Street box costs 25. The goal "Open a shoe box" is a side goal that comes after "Beat Stage 2 and cash out". The unboxing itself (4.75 s, rooftop cinematic, honest odds board and pity counter) is good, but nobody introduces it.
- **First rebirth (4.3 min):** the best-made part, a calm boxed lesson with one thing to click. But it comes after 80 silent seconds of waiting. Power drops to 0 right after the game has spent 4 minutes rewarding Power, and the level toasts restart from Level 1.

## Problems, worst first, each with a fix and its size

Sizes: S = under a day, M = 1-2 days, L = more.

1. **No welcome, and a silent game.**
   - The problem: the kid goes from a navy loading card straight into a full HUD and an instruction, with no greeting, music, gift or sound. This is the "no welcoming traits" the owner felt, and silence also kills flow: there is no rhythm to the loop.
   - The fix: a 3-4 s welcome beat, run once on the first join:
     - a slow camera pull from the Stage 1 gate down to the kid;
     - "WELCOME TO THE BLOCK, <name>!" in the title style;
     - the gift switched back on, as a present in front of the kid before the first lesson (its unboxing then also teaches boxes);
     - a soft music bed and the core sounds back on (shot, Cash, GOAL DONE chime, gate), after an owner sound pass.
   - Size: **M** (the camera, title and gift switch are S; the sounds need the owner's approval, M).
2. **The whole tutorial and 5 GOAL DONE moments are crammed into 28 s.**
   - The problem: each GOAL DONE lasts about 4.5 s, and they start at 5.7, 11.2, 14.8, 20.1 and 24.3 s, so the band is on screen almost non-stop from 5.7 s to 29 s. Every 5-second window holds 2-7 rewards. This is the "rushed" feeling.
   - The fix:
     - the tutorial's own steps complete quietly (a tick and a small "+N" by the tracker);
     - one big "YOU'RE READY!" moment at the end, with its Cash;
     - at least 2-3 s of calm between two moments.
   - Size: **S-M**.
3. **The training lane, the heart of the loop, is shown for 1.5 s.**
   - The problem: the kid enters BAY 1 at 4.2 s and is sent away at 5.7 s, because the first goal is Level 6, which is only Power 8. "BAY 1 shoots for you!" is still typing when the next goal arrives, so the kid never learns "stand here and watch Power climb".
   - The fix:
     - stay in the lane until Stage 1's Power (10), with a short beat that points at the Power counter ("Your POWER grows here!");
     - let a hint finish before the step moves on;
     - word the goal as "Train to 10 Power in BAY 1" instead of a level.
   - Size: **S**.
4. **The first fight ends before it starts.**
   - The problem: 3 goons, 1.3 s, no build-up and no danger, so the first fight feels like a formality.
   - The fix:
     - a 1 s "CREW INCOMING!" beat as they walk out;
     - Stage 1's crew a bit tougher, so the fight lasts about 5-8 s (only Stage 1's goon health; rerun the pacing sim, since the Balance numbers are the owner's).
   - Size: **S**.
5. **Several things talk at once.** The overlaps are listed above.
   - The fix: one voice at a time.
     - During the tutorial, hide the goal tracker and the lane's "TRAIN x1 HERE" (the hint and the arrows are enough).
     - No level toasts in the first minute (the counter still ticks).
     - A shared queue with a 1.5 s gap between the GOAL DONE band, the banners, the notices and the rank-up.
   - Size: **M**.
6. **No "why".**
   - The problem: the hints teach where to walk, never what things are for. It is a chain of errands, which is the "no flow".
   - The fix: three short "why" lines, each at a calm moment:
     - "More POWER = stronger shots" (in the lane);
     - "Gates need POWER" (at the gate);
     - "CASH buys guns" (on the pad).
   - Size: **S**.
7. **The tutorial stops without an ending, and nothing follows until 4.3 min.**
   - The fix:
     - a short graduation moment;
     - then two light lessons later on: the shoe box at about 1 min (after Stage 2), and the rebirth as now.
   - Size: **S**.
8. **The gun purchase is not a moment.**
   - The problem: it is bought instantly and hidden under GOAL DONE.
   - The fix: a 2 s reveal (the gun spins up into the kid's hand, a name card, "x2 POWER"), with nothing else allowed on screen.
   - Size: **S-M**.
9. **Minutes 1-10 have no rhythm.**
   - The problem: there is a big moment every 35 s for 3 minutes, then 80 s of silent waiting before the first rebirth.
   - The fix: don't change the numbers (the owner set World 1 at about 30 min); change the feel.
     - Fill the wait: music, lane sounds, and the next lane or stage visible with "x2 POWER at Rebirth 1".
     - Hold back the small moments (level toasts), so the big ones stand out.
   - Size: **M**.
10. **The first screen is crowded.**
    - The problem: about 25 HUD labels at 1.2 s, including 4 Robux buttons and the Starter Pack, before the kid has done anything.
    - The fix: show only Power, Cash and the goal at first. The other buttons slide in after the tutorial, one row at a time.
    - Size: **M** (it touches HUD layout, which the UI agent owns).
11. **The first rebirth feels like a loss.**
    - The problem: Power goes back to 0 and the levels start again from Level 1.
    - The fix: the rebirth moment shows what you keep (Cash, guns, shoes) and the new x2 in large type, with the first new lane highlighted after it. Keep Best Level visible, so "Level 1" doesn't read as starting over.
    - Size: **S**.

## Tool notes (for whoever fixes this)

- `feel_base.luau`'s fight step is out of date: no knock-out for 12 s, and the stage was never cleared. Its pad, box and rebirth "!!" lines in this run come from that, not from the game. `route.luau` (first30) is the trustworthy walk.
- The harness can't lay out the level toast (`AbsoluteSize` missing in Lune), so level toasts don't show in its event list. They do show in Studio.
