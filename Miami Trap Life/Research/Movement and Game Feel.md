---
tags: [miami-trap-life, research, game-feel, movement]
updated: 2026-11-02
---
# Movement and game feel

Back to [[00 Master Plan]] · Related: [[Jobs, Leveling and RP Game Feel]] · [[Gun Mechanics]] · [[Cinematic Cutscenes]] · `new-game-kit/GAME-FEEL.md`

The numbers we settled on for how moving around feels, and why. Code: `Config/Movement.lua` (numbers) and `Controllers/MovementController.lua` (behaviour). Reuse both in the next game: they only need `UIState`, `ClientData` (for Settings.ReducedMotion) and `GunRules.springStep`.

## Rules that make it work with everything else
- **One writer of WalkSpeed on the client.** Before this, the gun saved and restored WalkSpeed itself and the server's job carry did the same, so the two could undo each other. Now everything that wants a slower walk calls `MovementController.setModifier(name, mult)` (the gun's aim is `"Aim", 0.6`). A server write (carry = 12) is detected (`WalkSpeed ~= last value we wrote`) and becomes the base; when the carry ends we go back to the walk speed, not to whatever the server restored (which may have had a sprint in it).
- **FOV kick is additive.** Other systems tween FieldOfView to absolute values (gun aim 70 → AimFov, mission zoom 55, cutscenes, the phone camera). If FieldOfView isn't what we wrote last frame, someone else set it: that is the new base and the kick sits on top. Systems that save the FOV and restore it later (cutscenes, phone camera) may save it mid-sprint; we remember the values we wrote with a kick in them, so a restore of one isn't taken as a wider base.
- **Camera effects are transient.** Last frame's offset comes off at `RenderPriority.Camera - 1`, before the camera module reads the camera; the new one goes on at `Camera + 2`, after the gun's recoil step at `Camera + 1`. Nothing accumulates and the recoil (which is meant to stay) isn't touched.
- **Off whenever it would get in the way:** cutscenes (player attribute `MTL_Cutscene` or a non-Custom camera: offset removed and lean snapped back at once), `UIState` lockControls/lockCamera, first person, and `Settings.ReducedMotion` (no bob, roll, dip or FOV kick).

## The numbers
| What | Value | Why |
|---|---|---|
| Walk | 16 studs/s | Roblox default. Every door, prompt range and job station in the map was built around it; changing it would make every distance feel off. |
| Sprint | 24 studs/s (x1.5) | Clearly faster without overshooting prompts. GTA-likes on Roblox sit at 20-28; above ~26 the Vice Bay blocks start to feel small. |
| Ease up / down | 0.25 s / 0.15 s to ~95% | No instant snap (reads as cheap), but stopping must be quicker than starting or turning corners feels floaty. Exponential approach, not a tween, so it can retarget every frame. |
| Sprint input | hold LeftShift · L3 toggle · touch RUN toggle | Hold is what PC players expect. On pad and touch a toggle is kinder to thumbs; it switches itself off after 0.35 s standing still so you never "walk" at sprint speed into a shop. Shift lock is off in this place so Shift is free. |
| Stamina | none | Less friction. Nothing in the loop needs it yet (no chases). Add it only with a reason. |
| Sprint FOV kick | +7°, 0.3 s ease | Gives speed without changing the speed. +6 to +8 is the sweet spot; above 10 it reads as a fisheye. |
| Sprint bob | 0.35° pitch, 0.25° sway, 0.18 steps per stud (~4.3 steps/s at 24) | Barely there on purpose: you should feel it, not see it. Locked to ground speed so it never drifts out of step with the feet. |
| Strafe roll | 1.25° at full speed sideways | A hint of weight on strafes; more than ~2° makes people feel sick. |
| Landing dip | up to 2.5° + 0.35 studs, spring k 140 z 0.7 | Scaled by fall speed: under 18 studs/s nothing, a normal jump ≈ 1°, a roof drop (90+) the full dip. One small bounce sells weight. |
| Lean | 5° forward at full sprint, up to 6° into turns (full at 7 rad/s), spring k 90 z 0.85 | Pivoted at the feet so the body tips rather than the hips sliding. Off while aiming (the gun turns the body to the camera every frame and would make it wobble) and in cutscenes. Local only: C0 isn't replicated, other players don't see it. |
| Carry speed | 14 (was 12) | Carrying a box/bag should feel heavy, but at 12 the bag -> dumpster trip was 4-5 s of dead walking in the first shift. 14 still reads slower than the 16 walk, and sprint stays off while carrying. |
| Jump cooldown | 0.3 s after landing | Stops bunny-hop spam (faster than sprinting, looks bad in RP) without making a single jump feel blocked. |
| Footsteps | Roblox default character sounds | They already play in this place; don't invent ids. |

## First-session pacing
- The gang call moved from Level 5 (~10-11 min of Food Mart chores) to **Level 4 (~6 min)**. Ten minutes of shelf stacking before the first story beat is where new players quit; six is about two shifts' worth of tasks, enough to learn the loop and earn ~$160.
- **Level 3 (~3 min) tease:** one text from "Unknown" ("saw you working at Patel's. you move quick." / "keep your phone on."). The call no longer comes out of nowhere, and the player has a reason to keep working.
- "Tips" (PERFECT +25%) moved from Level 4 to Level 5 so every level in the first 10 still unlocks one thing.
- Checked by `tools/tests/test_job_rules.py` (Level 3 in 2-4 min, Level 4 in 4.5-7.5, Level 5 in 8.5-11.5).

## Big-moment juice (numbers in `Config/Movement.Juice` / `.Dropped`)
| What | Value | Why |
|---|---|---|
| Hit-stop | 40 ms on PERFECT, 50 ms on a kill | Roblox can't pause physics for one player, so we freeze your own character's animation tracks for 2-3 frames while the camera punches. Longer than ~60 ms reads as lag. |
| Camera punch | PERFECT 0.6° + FOV -1.5 · kill 1.2° + FOV -2.5 · any prompt 0.25° | A tiny "snap in" says *that counted*. Springs back in ~0.2 s through the same transient offset as the sprint bob, so it never drifts. ReducedMotion: pitch x0.4, no FOV. |
| Prompt feedback | pop sound (PSE suction pop 9119668788, vol 0.3) + ground ring + nod | Every completed prompt answers back. Our own MTL_* prompts already have job/mission sounds, so they only get the nod (no doubled sounds). Tap actions should be HoldDuration 0 where the prompt is made (a 0.3 s hold on a door feels sticky); don't shorten it on the client, the server checks its own value. |
| Dropped | colour drains (sat -0.85) + blur 6 over 0.8 s, 9° push-in over 2.2 s, card after 0.6 s, countdown = Players.RespawnTime (3 s here) | Dying was a hard cut to respawn. Now it's a beat: you see what happened, the world goes grey, the card says when you're back. Kid-safe words ("YOU GOT DROPPED"), no blood, no killer name. |
| Story shift card | auto "Next shift" after 4 s | The first session's SHIFT COMPLETE card waited for a mouse click (no Clock out option on the story job): keyboard players just stood there. |

## Play-test notes (2026-11-02, ~25 min, Studio solo)
**Passed:** sprint 16 → 24 in ~0.3 s, back in ~0.15 s; FOV 70 → 77 → 70 with the cutscene FOV untouched; carry = 12 and no sprint while carrying; Food Mart trash (bag → dumpster) and restock (stockroom → shelf hold minigame) on the rebuilt store, prompts fire, PERFECT pays; Level 3 tease text arrives; Level 4 call rings; the gun equips and fires outside safe zones; no script errors from any of this.
**Not covered:** the robbery, Burger Shack, Westside Auto, a confirmed hit on the dummy (scripted aim missed), the touch RUN button and gamepad L3 (no device), the new juice/death code (written after the run, installed in Edit mode).

The 5 weakest gameplay-feel moments we actually saw:
1. **The lean never showed.** Loading the avatar's look rebuilds the R15 joints, so the Motor6D found at spawn was gone. *Fixed:* the joint is looked up again whenever it's missing.
2. **"Follow the glow" with nothing to follow.** The task was behind the player inside the store and nothing pointed at it: the edge arrow only followed waypoints with breadcrumbs, and the glow is invisible in the over-bright interior. *Fixed (arrow):* the edge arrow falls back to the newest waypoint (job tasks). The interior brightness went to the lighting/interiors threads.
3. **Pressing a gun key on shift did nothing.** No sound, no text. *Fixed:* a toast says you're on shift and how to end it (only if you own a gun).
4. **A hollow "PERFECT!" stuck on screen for 40+ s.** The text faded but its UIStroke didn't. *Fixed:* the outline fades with it.
5. **Overlapping HUD bits at the first minute:** the objective pill on top of the waypoint label, toasts stacked over the menu button, the tutorial card over the waypoint label. *Handed to the HUD/tutorial threads.*
Also seen, handed over: call-screen Answer/Decline icons draw as empty boxes (phone), FirstDay's "FIRST SHIFT" title frames a parked car outside (cutscenes), the dumpster is a black block (map), and the camera jams into car roofs / the player's head in the small stockroom (worth a camera-collision pass later).

## Idle-time audit: the first 10 minutes (from the code, 2026-11-02)
Waits of 3 s or more with nothing to do, and what fills them now:
| Minute | Moment | Before | Now |
|---|---|---|---|
| 0:00 | Welcome cutscene (26.6 s) | content, skippable | unchanged |
| 0:30 | walk to the door | waypoint + 2 Patel texts | unchanged (short) |
| 1-6 | carry trips (bag -> dumpster, box -> shelf) | 4-5 s of slow walking | carry 14 (from 12), the edge arrow points at targets behind you |
| ~2.5 | first SHIFT COMPLETE card (8 tasks) | waits for a mouse click, no Clock out on the story job | auto "Next shift (4..1)" |
| ~3 | Level 3 | nothing new | "Unknown" tease text (2 lines) |
| ~6 | Level 4 call | rings 3 s after the level-up | unchanged |
| after a declined / missed call | the story goes quiet | objective line only | one text 90 s later: "offer's still open. call me back when you're ready." (once) |
| GangMeet | walk to a random meet spot | breadcrumbs, can be a long walk | sprint (24) makes it ~1.5x faster. Next: a ride / closer spot if it's still long (story thread) |

## Play-test 2 (2026-11-02, ~27 min): every job + the robbery
- **All 9 jobs work end to end** (forced clock-in, 2 tasks each through the real JobAction remote, the prompt checked at every station): Food Mart, Westside Auto (sequence, pickup + timing), Burger Shack (hold + timing), Cashier, Car Wash, Valet, Security (post pays on the 30 s tick), Freight, Port. Pay and XP land; PERFECT shows on minigames.
- **Task repeats:** the same task came back-to-back at most jobs. Fixed for tier 1 (`Jobs.RepeatWeight = 0.3`: ~9% back-to-back, never 3 in a row; tested). Tier 2/3 jobs have **one task each**, so they always repeat: they need a second task (jobs content).
- **Freight drop-offs are 1,500-2,000 studs away:** ~70 s on foot even sprinting. Needs a work vehicle or closer drops.
- **Dropped state works** (grey + blur + ragdoll + card + countdown, all reset on respawn). **Declined-call nudge** arrives at 90 s. **Edge arrow** shows for the robbery waypoint.
- **The lean still didn't show, and the real cause was the rig type:** this place's characters use Roblox's **AnimationConstraint** joints (15 of them, zero Motor6Ds). There's no C0; the root part's `Attachment0` plays that role. The lean now tilts whichever one the rig has. Anything that poses characters in code (GunPose, Actors) must handle both rig types.

## Job content pass (2026-11-02, after play-test 2)
Every tier-2/3 task job now has 3-5 tasks built from the existing step kinds, so shifts stop repeating one action:
- **Cashier:** ring up (hold), bag the groceries (ordered sequence: cans → milk → cereal → bread → eggs), count the till (timing), restock the gum rack (carry a box from the stockroom, hold at the register).
- **Car Wash:** wash (hold), rinse (hold), dry and buff (timing), vacuum the interior (hold), tire shine (ordered sequence).
- **Valet:** park a car (keys → spot), bring a guest's car round (spot → stand), sort the key board (sequence).
- **Trucker:** deliver a load (load hold at the dock → walk to a drop), pre-trip inspection (ordered sequence at the truck spot), strap the load (timing). Drops are now 4 sidewalk spots 190-375 studs from the dock (Port Blvd shops, Liberty Blvd, Railroad Ave warehouse, NW 11 St), checked in Studio for open ground. The far drops (Food Mart, Burger Shack, Westside Auto, motel: 1.5-2k studs) stay defined but unused until there's a **depot truck spawner** (no vehicle system yet).
- **Balance rule used:** each new task pays about the same $ per second (pay ÷ (est + the job's average gap)) as the job's first task, so $/min doesn't move (Cashier 46, Car Wash 53, Valet 49, Trucker 101). Trucker XP was cut to ~35/min so the route job never out-levels the hands-on jobs. Tests: 3+ tasks per tier-2/3 job, ordered sequences use their whole pool, drops 150-400 studs from the dock, Trucker XP/min < the starter jobs.

## Play check 3 (2026-11-02)
Lean verified on the AnimationConstraint rig (Attachment0 tilts ~5° at full sprint, springs back); GunPose's shoulder Transform is applied on AnimationConstraint shoulders; a server-confirmed dummy kill reaches the client (the kill juice runs on that event). Still untested: the new tier-2/3 tasks in Play, touch RUN button, gamepad L3.

## Stride sync: feet that don't slide (Controllers/StrideController.lua, Rules/StrideRules.lua)
**What plays the animations:** Roblox's default `Animate` script (there's no custom one) with each player's **own avatar animation pack** (`LoadCharacterAppearance` is on). So the walk/run clips differ per player: no fixed stride number can be right. We keep Animate (idle, jump, fall, climb, swim, emotes all stay Roblox's) and only take over its `WalkAnim`/`RunAnim` tracks while you're moving on the ground.

**How it works:**
- While a foot is planted it must not move in the world. The body moves forward at the ground speed *v*; the clip carries the planted foot backward relative to the body at *a × rate*, where *a* is the clip's authored speed (studs/s at playback rate 1). The foot sticks when **rate = v / a**.
- *a* is unknown (any pack, any body scale), so it's **measured**: after physics, follow the lower foot (the planted one) and keep **one sample per foot contact, taken when that foot is lowest** (the true plant): its world speed along the walking direction *w* gives *a = (v − w) / rate*. A running mean of those samples (3 s of memory) gives a steady value; early samples move it a lot, so a new clip settles in a few steps. Learned values are kept **per AnimationId**, so a clip swapped in at spawn is learned fresh and an old one is remembered.
- **Why only the lowest moment (play-test 2026-11-02):** in Roblox walk clips the foot is only truly still for a few frames mid-contact; while it lands and lifts it moves 5-10 studs/s even when the timing is right. Averaging the whole contact read that as sliding and pushed the rate to its cap.
- **Cadence trade-off:** the default walk clip measured in Play needs ~2.4x playback to stick at 16 studs/s (~4 steps a second, which looks hurried). Stride sync can only fix sliding by changing cadence; a clip with a longer stride is what makes 16 studs/s look natural. Choose walk clips whose authored speed is near the walk speed (rate ~1 at 16), and run clips near the sprint speed.
- Walk and run are **blended by weight**, not switched: run weight is 0 at walking speed (16, and carry 14), smoothstep up to 1 at 23 (sprint is 24). Each clip learns its own *a*: a blended sample has the other clip's share taken back out first.
- Before each animation step the rate (rounded to 0.02 and only sent when it changes, because AdjustSpeed replicates) and the weights are written to the tracks.
- Hands back to Animate when stopped (< 2.5 studs/s, so Animate's own idle ↔ walk fades still play), seated, swimming, climbing, airborne, in cutscenes and minigames, and while strafing/backpedalling (the clip only walks forward).
- **Proof:** `tools/tests/test_stride_rules.py` simulates walkers with hidden clip speeds (8-25 studs/s), wrong starting guesses and noisy foot readings through carry → walk → sprint → walk: worst remaining slip 0.12-0.19 studs/s, learned speeds within 5%.
- **In Play:** the character shows `MTL_StrideRate`, `MTL_StrideSlip` (planted-foot world speed, studs/s) and `MTL_StrideWalkA`/`RunA`: slip should sit near 0 at 14, 16 and 24.
- **Footsteps:** the default character sounds stay; no licensed (ProSoundEffects) shoe footsteps exist on the Creator Store (only sounds ripped from other games), so none are wired. The plant moment is known (`stanceWasLeft` flips) if real ones are uploaded.

## Lessons for the next game
- Write movement as one owner per property (WalkSpeed, FOV, camera offset). Everything else asks through a modifier/delta API. That's what makes sprint + carry + aim + cutscenes all coexist.
- Never cache R15 joints at spawn: re-find them when they're gone. And never assume Motor6D: newer avatars use AnimationConstraint joints (pose them through Attachment0.CFrame or .Transform).
- Any text with a UIStroke must fade the stroke too.
- Every input the player can press needs an answer, even "not now" (gun on shift).
- Test the first 10 minutes for "dead stops" where the game waits for one specific click.
