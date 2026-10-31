---
tags: [build-playbooks, stone-skipping, tutorial, pacing, ui-reveal, game-feel, plus-one, lessons]
updated: 2026-10-31
---

# 13 Beat Stone Skipping: Tutorial, Pacing and Feel

Back to [[00 Build Router]] · Full teardown: [[Teardown - Stone Skipping]] · Rules: [[09 Owner Taste Rules]] · Loop maths: [[12 Game Loop Logic Playbook]]

**What this is.** A frame-by-frame study of Alex's PC recording of Stone Skipping (Oct 28, 8.41 PM, 56 s, 3024×1722 at 120 fps, on Alex's Desktop and in the project files). It starts mid-tutorial ("GET 2 WINS 1/2") and ends after the first throw of the second run. Sampled at 1 fps for the whole clip, 4 fps over the rebirth and reveal, and 6 fps over the walk to the pad. Each point below says what Stone Skipping does, what +1 Cannon Evolution did on Oct 30, and what we changed. **Borrow the mechanics and timing; never their art, names or sounds.**

## 1. Timeline of the clip (seconds into the recording)
| t | What happens |
|---|---|
| 0 | Standing in the THROW ZONE. A green THROW button sits just above the character. Quest bar: GET 2 WINS (1/2). |
| 1–5 | Throw. Chase camera low behind the stone. Counter 35 → 104 → 166 → 216 m, one second apart (about 60 m/s). Each bounce floats a small "⚡+1" over the water; the Skill number and level bar tick. "Palm Beach" grows big beside the counter as the stone enters it. |
| 5 | Hard cut home. "+1 🏆" over the head, confetti, quest bar fills 2/2 and turns into EQUIP A NEW STONE. |
| 6–11 | A chain of white arrows on the ground leads to the stone pedestals. Toast: NEW STONE! Scallop Shell (bottom-left of centre, small, 2 s). |
| 11–14 | Quest becomes REACH LEVEL 20 (6/20). The arrow chain swings round and leads to the 1x training pad (~3 s walk). |
| 14–33 | On the pad. Every tick: "⚡+3" pops off the stone, Skill +9 to +12 a second, and **a level-up about every second** with confetti on the character, "Level Up! [x3] … [x13]" (the bracket counts level-ups in a row) next to the bar, and the quest number ticks with it. Levels 6 → 19 in ~19 s. Level sizes grow slowly: 10, 10, 10, 12, 14, 15, 17, 19, 22. |
| 34 | Level 20 = MAX LEVEL. Quest: REBIRTH NOW. The **whole screen dims**, and only now does the left menu appear, with the Rebirth tile lit, outlined and showing 100%. |
| 36–37 | Rebirth panel: Before → After (x1 → x2 Skill), "Level 20 / Level 20", big green Rebirth and a small Skip. |
| 38 | Tap Rebirth: the screen fades to **white** (~0.25 s in, ~0.5 s held, ~0.3 s out). |
| 39–42 | TUTORIAL COMPLETE! on spinning rays: Rebirth #1, x2 SKILL, Tap to continue. |
| 42 | Tap. **The full HUD is there at once**: Auto Throw and the event pill on top, the 2×3 menu grid with Shop on the left, the pass cards and Starter Pack on the right. Confetti. The multiplier reads x2. |
| 44–48 | Daily Rewards opens by itself. Claim day 1, a big green tick, "Next reward in 24:00:00". |
| 49–56 | Next throw: Level 1 → 4 in one throw (+6 per bounce now), a floating pumpkin pickup in the water pays the event currency. |

## 2. What it does better than us (Oct 30 build), and what we did about it

### A. The UI is hidden until the tutorial needs it
- **Them:** during the tutorial the screen shows only the quest bar, the Skill/Level bar with its three packs, and the wins and eggs counters. **No menu grid, no Shop, no pass cards, no Auto Throw.** The menu appears only at REBIRTH NOW, dimmed except the Rebirth tile; everything else arrives at once after TUTORIAL COMPLETE.
- **Us:** the whole HUD (Shop, six menu tiles, four round buttons, Auto Launch, two pass cards, three currencies, three packs) was there from the first frame, so a new player had 20 buttons and one arrow.
- **Done (Oct 31):** HUD elements now have a tutorial stage. Start: the Power/Level bar only. Cash appears when the EARN CASH step starts, the Eggs tile when HATCH starts, the Rebirth tile and Rebirths count at REBIRTH NOW with the rest of the screen dimmed, and everything else pops in one after another when you tap past TUTORIAL COMPLETE. Returning players (tutorial done, or any rebirth) see the full HUD.

### B. A level-up every second while training
- **Them:** training is "reach level 20", and levels are small, so the bar fills and empties about once a second, each with confetti, a "Level Up! [xN]" streak and a tick on the quest bar. You never wait more than a second for a reward.
- **Us:** the bar crept from 0 to 30 Power with one +1 every 0.8 s and nothing in between.
- **Done:** Power now shows as **Level 1 to 20 within each rebirth** (Level 20 = enough Power to rebirth; the bar says MAX LEVEL). Level sizes grow slowly like theirs (`Config.PowerLevel`). Each level-up: confetti on your character, "Level Up! [xN]" by the bar, a soft rising tick. The first tutorial step became REACH LEVEL 20, which is the same 30 Power, so pacing is unchanged. The level is a progress display only; it doesn't change any number you earn.

### C. Pacing: the first rebirth at about 85 s
- **Them:** first throw about 40 s after the intro, first rebirth about 85 s.
- **Us:** already tuned on Oct 30 (`REBIRTH_FIRST_POWER = 30`, `REBIRTH_FIRST_CASH = 20`, three launches pay for the Starter Egg plus the rebirth). The intro cutscene (about 25 s) is still longer than theirs (about 15 s); it has a Skip button.
- **Done (Oct 31, later):** the intro is now about 13 s of camera plus 1.5 s of loading (measured in Studio), down from about 25 s. Every shot is shorter (`ESTABLISH_TIME` 2, `WINDUP_TIME` 0.6, `AFTER_TIME` 1, `TALK_TIME` 2.2, `PADS_TIME` 3.4) and the chase covers the same map in 5.6 s instead of 8.6 s.

### D. The throw reads at a glance
- **Them:** chase camera behind the stone, the counter is the star, a hard cut home, the next throw a second later.
- **Alex's call for us (Oct 31):** the ball flies **upward and left to right across the screen**, like a side-on shot, so the arc out of the cannon is the show.
- **Done:** the flight camera sits off to the side of the river, a little above the water, with the ball on the left third and the open water ahead of it on the right. It rises with the ball's big first arc and settles back down for the skips. The launch shake, lens punch, counter, area banners and gates are untouched. At launch the camera used to stand inside the lobby's bank, so it now rays out from the ball's line and pulls in, in front of any map piece in the way, then eases back out. Measured in Studio: the ball starts at 31% across the screen, climbs from 40% to 23% from the top, then drifts to 63%, and nothing blocks the view.

### E. Transitions are part of the reward
- **Them:** the white fade on Rebirth, then the TUTORIAL COMPLETE rays, then the HUD arriving, then Daily Rewards: four beats in eight seconds, each one a little gift.
- **Done:** a white fade (one flash, kid-safe) now leads into our TUTORIAL COMPLETE screen; the HUD arrives on tap with a pop per element; Rewards opens after (already there).

### F. Small things worth copying later
- The arrow chain lies **on the ground** from your feet to the target and swings round as you turn. Ours floats; keep it, Alex approved it (Taste Rules).
- "+1 🏆" floats over the head when you land home, and coins fly to the counter.
- Pickups in the water during the throw (their pumpkins). Ours could put gems or cash bags on the river that the ball collects.
- The level resets to 1 on rebirth, but the multiplier jumps (x1 → x2) and the first throw after it gives three levels at once: the rebirth is felt in the first five seconds.

## 3. Rules to reuse in every +1 game
1. **First screen = the verb and one bar.** Every other button arrives on the step that needs it, and the rest after the first rebirth.
2. **Something levels up every second** while you grind. Split the grind into about 20 small levels and celebrate each one.
3. **Spotlight the one button** the step needs: dim everything else.
4. **Chain the reward beats**: fade, celebration screen, HUD reveal, daily reward.
5. **Measure from the recording, not from memory**: the numbers above are from frames.

## 4. Oct 31 follow-ups
- **Cash coins fly into the counter** when you land home (`GameClient/CoinFly.lua`): 6 to 12 coins spray off your character, swoop up into the Cash icon and bump it one by one with a rising coin tick. The money buttons sit next to the number they raise, and now the money visibly lands there too.
- **The tutorial has you buy a cannonball** (Alex: "make them buy a cannon ball"), as step 3, right after the first two launches, like Stone Skipping's EQUIP A NEW STONE. The Stone ball now costs 40 (one early launch's pay, was 500), and buying it also equips it. Steps: Reach Level 20, Launch ×2, Get a New Cannonball, Earn Cash (100), Hatch, Rebirth Power/Cash, Rebirth. The HUD reveal stages moved up by one (`FULL = 7`).
- **Timed in Studio with no walking:** intro done at about 9 s; Level 20 at 35 s; two launches by 59 s; ball bought at 68 s; Starter Egg cash at 92 s (two more launches); rebirth at about 103 s. Four launches in all, so the guaranteed first Mythic (6th launch) lands on the second launch after the tutorial. Walking adds roughly 20 to 30 s on the Oct 31 map; launches take about 11 s each, which is now the biggest cost.
- **Lesson:** a cheap first purchase in the tutorial must cost less than one or two payoffs; a price set for the long game (500) blocks the tutorial for minutes.

## 5. Early progression pass (Oct 31 evening; vault 20's first-five-minutes rules)
- **Before >> After on the Rebirth panel:** a line under Alex's have >> need layout says `Power x1.6 >> x2.2  +25% Cash, new cannons and worlds`. It is Stone Skipping's x1 → x2 Skill box in one line, and it keeps Alex's mockup. Vault 20 rule 13: show now vs after.
- **NEXT GOAL bar after the tutorial:** the quest bar stays for rebirths 2 to 4. It shows `REBIRTH 2: REACH LEVEL 20 (3/20)`, then `GET CASH`, then `REBIRTH NOW`, with the arrows going to your best booth, then the Launch Zone, then the Rebirth button. Stone Skipping always has a quest on screen. Vault 20 rule 10 says one short objective; rule 12 says a sawtooth to each rebirth. The bar steps aside at rebirth 4.
- **Gift countdown** under the gift button (`2:37`, then `READY!`), so there is always something a minute or two away. Vault 20 rule 10 calls this the exit hook.
- **First playtime gift = a free Starter Egg at 3 min** (it was 3 minutes of cash): a free hatch inside 3 minutes, from vault 20's "+1 genre" first five minutes. The server's `claimPlaytime` hatches `Reward.Egg` with the normal odds and reveal.
- **Rebirth 2 is cheaper:** 150 Power / 100 Cash (it was 320 / 160). With only the first booth open it took about 3.5 min; now it's about 1.5 to 2. The ladder aims at rebirths at about 1.5, 4 and 8 min.
- **Timed in Studio (Oct 31, scripted, no walking):** Level 20 at 42 s, two launches by 55 s, ball at 58 s, egg cash at 70 s, REBIRTH NOW at 82 s. Launches now take about 6 s each.

> [!note] Oct 31 evening: Alex tried the side-on camera and asked for the ball seen from behind again. The rare-shot thread's chase camera (`CHASE_*` in Effects) now handles normal launches. Lesson: when the owner asks for a big feel change, ship it, then ask them to try it in a playtest before building on it.

## 6. Tutorial arrows that look professional (Oct 31)
Alex: "they don't correctly point at things, move around a lot". Why they did:
1. **Spacing was measured on screen**, so every camera move re-spaced the whole chain, and the darts slid.
2. **The chain flowed forward all the time**, so nothing was ever still.
3. **It aimed at the target's centre** (inside the pad or crate), not at where you stand.
4. **The marker bobbed 1.2 studs** at 4 rad/s.

Fix (`Tutorial.lua`, `drawArrows`): one straight line from just above your feet (root minus hip height, steady while you walk) to just above the middle of the target's top. Darts sit at fixed 2.4-stud steps counted **back from the target**, so they stay put while you walk; you only pass them. The last dart stops 1.8 studs short. There is no flow. The marker sits 5 studs over the target's top and moves 0.3 studs, slowly. **Rule:** guidance arrows are anchored in the world at the target end, never laid out in screen space.
