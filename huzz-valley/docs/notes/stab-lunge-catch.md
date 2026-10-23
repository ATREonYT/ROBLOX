# Stab, dive (lunge) and catch (motion and VFX)

Read before changing how the click stab, a catcher's dive (lunge) and its stun, the catch or getting up look. The rules behind them
(hit boxes, ranges, cooldowns, rescues): [round.md](round.md). Huss Valley's read, frame by frame:
`docs/knife-study.md` (section 4 for the catch). Players read "catch", never "kill".

## The stab (`Shared/StabMotion`, scripted until `Config/Animations.Stab` is uploaded)
- `Config/Round.Stab.Time` 0.40 s, Huss Valley's slash from `docs/knife-study.md`: no wind-up; the arm sweeps out to
  the right side, landing at ~0.07 s, held out (free arm pointing ahead) to 0.24 s, back by 0.40; trail on 0.02 to
  0.45 of it. The wrist snaps the blade flat into the sweep and the body leans in a little. The knife arm is raised
  by the run's hunch so it slashes level while sprinting. Written after the animations (Frame order 30), so it sits
  over the run.
- A long blade (over 2.2 studs from grip to tip) is held more forward in hand so it clears the floor
  ([knives.md](knives.md), "In a catcher's hand"); in the stab and the lunge `Gameplay/Actions` eases it back to the
  usual 150 degrees (`KnifeLook.slashC0`), so the slash and the leap's level blade are the same for every knife.
- A Game Pass knife's trail is in its element's colours, lasts 0.17 s (`KnifeLook.TRAIL.ElementLifetime`) and tapers;
  Epic and up draw a thin crescent round the front and right of the catcher (`KnifeLook.ARC`: a Beam on two root
  attachments, gone in 0.2 s, never solid) and a pass knife throws half its element's burst (`KnifeBurst`).
- The Practice Bot's stab shows too: RoundService sends "Stab" `{ bot = true }` on a hit (and at most once a cooldown
  while it keeps trying); `Gameplay/Actions` plays it on the `HuzzBot` model.
- Spec `tests/StabMotion.spec`, video `docs/previews/stab.mp4` (`motion3d/stab_scene.luau`). Before/after film
  `docs/previews/stab-before-after.mp4` + `.jpg` (`motion3d/stab_fx_scene.luau`, `STAB_OLD` = the old module copied
  next to the new one). Honest: the arm change is small; the arc reads faintly in the render.

## The dive (the code's lunge: `Shared/StabMotion` `LEAP`, `play(rec, now, true)`)
- Owner Oct 19: "add a dive feature for the tagger"; Oct 20 15:13: "right now its like a ragdoll, make it straight
  to the point and without a long unconsiousness, make it concrete". One clean move, 0.80 s from the press to
  running again: a quick crouch, a straight dive along the ground, a belly landing and slide, a pop up to the feet.
- **Your own dive plays the moment you press Space** (`Gameplay/Dash` calls `Actions.lungeLocal` before its hit
  check; the server's "Stab" echo within 0.8 s is ignored). Everyone else plays it from the server's "Stab" `{ lunge = true }`.
- **The whole body dives** (it owns the root joint and the legs as well as the head and arms; the waist stays straight
  so the chest never dips under the floor). `LEAP.KEYS`, seconds from Space: a quick crouch by 0.07 s (`In`; knees
  bent, the hips down to the feet as the hop lifts off), the spring by 0.16 s (tipped 60°, the legs together and
  straight behind, toes pointed), one straight line in the air (76° at 0.18 s), chest and legs touching down as the
  hop ends (0.245 s, 84°), on the belly to `Out` 0.40 s (88°); both arms reach ahead (`REACH`, superman), the knife
  leading, evenly over `ArmIn` 0.16 s.
- **The dive's arms blend angle by angle** (`StabMotion.blendArm`), not with `CFrame:Lerp`: REACH (168°) and LIE (158°)
  are near 180° from the run's arm swing, and a Lerp there takes the shorter way round, which flips sides from one
  frame to the next as the run's arm swings. Oct 19 evening (a fresh critic, `motion3d/move_smooth_measure.luau` at 30
  fps): the right arm turned 100° in one frame at 8.30 s (getting up, leapWeight 0.20, before release at Up; it did
  not turn back), the hand 173° at take-off (ArmIn was 0.06 with an ease) and 113° at the slash. Now the dive's worst
  arm turn is 66° a frame (LeftUpperArm at take-off; the run's legs reach 67°), the get-up 11°. The click stab is
  unchanged (its sweep is 100° in a frame, as Huss Valley's).
- **The slash lands when the knife reaches someone**: `StabMotion.slash` from `Dash` (your screen's hit check) or from
  the server's "Caught" (everyone else's, so it lines up with the runner's fall there); if it reaches no one, at
  `SlashBy` 0.14 s. The sweep goes from the reach out to the right (`DIVE_KEYS`: the click slash's poses on a slower
  clock, the sweep at 0.14 s with a smooth ease; the hand is out to the right within 0.08 s), then the arm settles
  flat on the floor ahead (`LIE`). The slash trail, `KnifeLook.ARC` crescent and the `KnifeBurst` start with the slash, not at take-off.
- **Landing**: at the hop's end (`StabMotion.air()` = 2 x Up / 196.2) the body is down on its belly; the hips come down
  by exactly what keeps the lowest of the feet, legs, hips, chest and head on the floor (`lowestBody`, from the joints'
  C0/C1, not the parts, which lag a frame; `lowestFoot` for the feet alone). It slides with the push.
- **The slide and the pop up** (Oct 20 15:13): after the push the belly slides on from 40 studs/s to a stop over
  `Lunge.Slide` 0.16 s (`RunMotion.lungeSpeed`, ~2.1 studs, fast then settling; it used to stop dead). From `Out`
  0.40 s the hands come under the shoulders (`PUSH`, over 0.12 s) and the knees tuck under (0.54 s, chest 54° off the
  floor), a quick crouch (0.67 s) and up, the run back over the last `Blend` 0.16 s (`Up` 0.80 s). The hips are lowered
  every frame so the lowest part of the body touches the floor (`lowestBody`): crouching, landing, sliding and getting
  up. No dazed head roll, no lying still (the spec checks the chest keeps moving after the slide).
- **The stun**: from `Lunge.StunAfter` 0.38 s for `Lunge.Stun` 0.4 s (`PowerService.stun`): speed 0, no stab, no
  abilities, the body doesn't turn to the camera (`Gameplay/ShiftLock`, `Dash` holds AutoRotate off); it ends at
  0.78 s as the body stands. No stars and no 💫 badge for a stun this short (`PowerEffects` and `PowerService` show
  them only from 1 s); the bar's STUNNED 💫 drains ([ui.md](ui.md)). `Lunge.Cooldown` 3 s from the press still keeps
  it from being spammed. Huss Valley's catcher: leaps at 41.60 s, lands ~42.0, up by ~42.27 (`docs/knife-study.md`).
- **A sideways dive** (A / D) does the same into its side.
- **Height** (`Config/Round.Lunge` Up 24): 0.245 s in the air, 1.5 studs. The push (72 to 40 over 0.38 s, 19 studs)
  and the hit box are the round's ([round.md](round.md)).
- **The leap's ribbon** (`KnifeLook.CATCH.Streak`, HV's lunge ribbon): a Trail between two points on the UpperTorso,
  white into the knife's colour (its `SlashColor`, else steel white), 0.14 s long (~8 studs at the leap's speed), on
  for the push only (`Gameplay/Actions`).
- Spec `tests/StabMotion.spec` (the dive: running again within 0.85 s, 0.4 to 0.7 s on the floor, the stun ending as
  it stands, the cooldown kept; the crouch on the feet at 0.07 s; tipped 60° with the legs together behind at 0.16 s;
  flat on the belly at 0.32 and 0.35 s, the lowest point within 0.15 of the floor; popping up at 0.54 s; never still
  after the slide; the free arm reaching ahead; a sideways dive tips into its side; slash within 0.08 s of reaching
  someone, at SlashBy otherwise; body parts turn at most 24°/frame at 60 fps (22.1 today) and 42° at 30 fps (40.2: the
  crouch, spring and pop up are quick on purpose, under the run's own ~66°); the arms over a ±60° run swing at 30 fps
  at most 68° a frame (65.4 today); every joint handed back after Up). `tests/Movement.spec`: the push, then the
  slide with no jump in speed, 1.5 to 3 studs; the stun at most 0.5 s. `move_smooth_measure.luau` "Space: leap": worst
  turn 75.5° (LeftUpperArm at take-off; was 66), pop 71° at the slash.
- Film `docs/previews/dive-oct20.mp4` + `.jpg` (30 fps; before above, now below; the catcher's camera left, a
  bystander's side view right; full speed then 1/4 speed): `motion3d/catch_scene.luau` with `CATCH_DIVE_OLD=1` for the
  before. Older films: `docs/previews/dive-stun.mp4` (the 2 s stun), `docs/previews/knife-leap.mp4`.

## The catch
- **What counts as a catch** is the knife's box touching the runner's real body, checked the same way on the
  catcher's screen and on the server with a look-back for lag (`Shared/TouchHit`, `HuzzServer/HitHistory`; numbers
  in [round.md](round.md) "Catching"). The motion here doesn't change it: a slash or leap that looks like it reaches
  someone but whose box doesn't touch their body is a miss.
- **Pinpoint: what the catcher saw counts** (Oct 19; rule in [round.md](round.md) "Catching"): the screen sends
  where it drew the runner and itself, the server ties that to one moment of its own history and takes the touch as
  drawn, with at most 1 stud more reach than an honest hit. Network model `lune run
  huzz-valley/tools/sim/touch_lag.luau` (repo root; 30 Hz sends, one-way = ping/2, others drawn 0.05 s late: a
  guess). Fair hits that count, the server's own test vs now (the claim, or that test when it fails): both 50 and
  100 ms 100/100%; both 200 ms 70/100; runner 60 ms, catcher 250 ms 60/100; catcher 400 ms 38/38 (the claim is past
  MaxRewind, the fallback still counts what it did); a catcher chasing at a dive's 72 studs/s, 50/100/200 ms: 100%.
  Its cheat test (a catcher sending any claim he likes): an honest stab reaches 5.35 studs root to root; the first
  pinpoint version let a cheat reach 9.9 and stab behind him; now 6.35, never behind. The sim's bots send claims
  too ("screen claims").
- **The gap nobody can close:** every screen shows the others where they were a moment ago (their send, the trip to
  the server, the trip to you, plus Roblox's smoothing), so the catcher sees the runner 3 studs back at 50 ms ping
  each, ~5 at 100 ms, ~7.5 at 200 ms (p95 up to 10: the runner turning or hussing). On the runner's own screen the knife can
  therefore look short. Roblox gives no way to show every player in the same spot at the same time; the fair choice
  is one screen's view, and we take the catcher's. Not
  done: moving the caught body to where the knife touched (the runner would see a snap back).
- **Others drawn ahead (Oct 22 19:45, `Gameplay/OthersAhead`)**: the owner's two recordings of one round (runner's
  and catcher's screens, both ~55 ms ping) showed the catcher's knife on the runner while the runner's screen had the
  catcher several studs behind. Now every screen draws everyone else ahead along their movement by its half ping +
  `Round.Ahead.Interp` 0.1 s (at most 0.3 s and 8 studs; eased; still, anchored or teleporting bodies not moved),
  by shifting their root joint's C0 on that screen only. HitCheck sends the offset as `ahead` with the unshifted root;
  `TouchHit.verify` follows the runner's real server path that far (never past it, `Touch.AheadMax` 8.5), tests the
  touch where the screen drew them (or where they really were if that guess left their path on a turn), and caps it
  against that moment. Lag model (`AHEAD=1 lune run huzz-valley/tools/sim/touch_lag.luau`), runner's-screen gap
  without -> with: both 50 ms 3.3 -> 1.1 studs, 100 ms 4.8 -> 2.1, 200 ms 7.5 -> 4.4, dives 3.3/4.6/7.5 -> 1.3/1.3/3.5;
  fair hits that count 98-100% (catcher 400 ms: 38 -> 87%). Cheat reach unchanged (+1 stud). Limits: on a sharp turn
  the body shows a little past the corner for a moment; Interp 0.1 is a guess (Roblox doesn't publish its smoothing),
  only real servers can tune it.
- **Motion stamps (Oct 23 08:36, owner: "make the desync the most precise it can be")**: no more guessing Roblox's
  delay. `Gameplay/MotionSend` stamps your own body 20x a second and on every key change (`Shared/MotionStamps`: server
  clock `t`, root `p`, speed `v`, keys' speed `g` = MoveDirection x WalkSpeed, `push` for a huss/dive/halt) on the
  `Motion` UnreliableRemoteEvent; `HuzzServer/MotionRelay` checks it (within 1 s of the server clock, alive, unanchored,
  not downed, within `Near` 6 studs + 0.1 s of speed of the server's copy, keys no faster than WalkSpeed + 2, speed under
  150, 40/s per player) and sends it on with the character; it stamps HuzzBot bodies itself. `OthersAhead` draws a body
  with a fresh stamp (<= `MaxAge` 0.6 s) at `predict(stamp, now - t)` (speed eases to the keys' at `K` 12/s; a push
  kept `PushFor` 0.12 s), capped by `limit` (flat, `MaxStuds` 10, none past `Teleport` 14), eased at
  `Round.Ahead.StampSmooth` 25; else the old guess. `RoundService.screenHit` adds the runner's newest stamp, moved on to
  the catcher's frame (now - catcher ping/2), to the runner's path (`Touch.AheadMax` 10.5). Lag model
  (`STAMP=1 lune run huzz-valley/tools/sim/touch_lag.luau`), runner's-screen gap guess -> stamps: both 50 ms 1.2 -> 0.2
  studs, 100 ms 1.5 -> 0.9, 200 ms 4.1 -> 1.4; one slow side 0.8; dives 0.3/0.5/1.0; fair hits 99-100% (catcher 400 ms
  97%). Cheat reach unchanged. Only real servers show Roblox's own smoothing and real pings; tests
  `MotionStamps.spec`, `OthersAhead.spec`.
- **Releasing a pose** (StabMotion, DownMotion, CarryMotion): put back the pose underneath only on joints nobody else
  wrote since, or the old pose shows for one frame ([animations.md](animations.md) "Layering").
- **Red fill** on the caught runner (`Gameplay/RoundHud`, on their team Highlight, everyone's screen,
  `KnifeLook.CATCH.Fill` / `catchFill`): FillTransparency 0.12 for 0.07 s (HV's 2 solid frames), up to 0.6 by 0.25 s,
  gone by 0.42 s. The solid frames only through `Burst.flashOk` (one flash a second per screen), else the tint only.
  Then a **red outline while they lie down** (refreshHighlight: Runner + Downed = red).
- **Knife-colour touches** (`Gameplay/Juice`, one each per catch, calm): a thin cut line drawn on across the runner's
  back in 0.06 s and gone by 0.26 s (a Beam on their UpperTorso, so it falls with them) and 10 sparks, both in the
  catcher's knife colour. Your own screen keeps the red tint (`HuzzHit`) and the shakes (owner asked for shake).
- **The runner reacts, then falls with momentum** (`Shared/DownMotion`): the hit (`HIT`: in 0.1 s the back arches,
  head back, arms fly up and out, knees buckle; at its fullest before the body has tipped 10°, gone by 0.34 s), and
  the body slides on `Knockdown.Slide` 2.2 studs as it falls (fast, then settling). The server shortens the slide
  before a wall (`KnockdownService`: rays ahead at the waist and near the floor, and the field's invisible walls via
  `DownMotion.fieldSlide`; the character's `DownedSlide`); clients, the server's final placement, standing up and the
  rescue range all use it.
- Spec `tests/DownMotion.spec` (the hit at once, before the tip; slide fast at first and done by the landing; no
  slide = the old fall; no part over 45°/frame at 30 fps).
- Film `docs/previews/catch-before-after.mp4` (30 fps: side view, the catcher's camera, the runner's camera; before
  left, after right; full speed then 1/4 speed) and `catch-before-after.jpg`, from `motion3d/catch_scene.luau`
  (`CATCH_OLD=1` loads `StabMotionOld`/`DownMotionOld`: copy the old modules next to the new ones to re-render the
  before, then delete them; `CATCH_VIEW` = side / catcher / runner).
- Honest: not seen in Studio yet. The preview draws the red fill by recolouring the parts (Studio's Highlight fill is
  an overlay) and draws particles additively, so bursts over the sky look whiter than in Roblox. The run animation
  under the leap is the pack's, so the take-off blend in Studio starts from a mid-stride pose the spec doesn't test.

## Getting up (`DownMotion.rise`, `Gameplay/Knockdown`)
- The server stands a revived player up at once; the client tips the body back down about the feet and eases it up
  over 0.4 s (no pop). Spec `tests/DownMotion.spec`.

## Why it is this way / history
- **Stab, Oct 19** (owner: "better knife animations, not only during gameplay"): same timing and still no wind-up;
  the wrist snap, the lean, element trails, the arc and the burst were added then.
- **Lunge, knife pass 2, Oct 19** (owner: "give them a good vfx, make them have good animations, the leaping, the
  killing ... take your time"). Before, the lunge was the click slash at take-off with the legs still running, a
  0.18 s hop and a 35° waist dive only after landing, so it read as a stumble; and your own lunge waited for the
  server's echo (a round trip late).
- **The dive, Oct 19 batch 2** ("add a dive feature for the tagger and after they use it they are stunned for 2
  seconds"): "The lunge" section became "The dive". The leap used to land in a low lunge, tipped ~34°, held to `Out`
  0.47 s and handed back by `LEAP.Up` 0.72 s; now it lies flat for the stun. The waist stays straight in a dive
  because its pitch put the chest under the floor during the slash; `In` went from 0.1 to 0.15 s (19.6°/frame at
  take-off was over the 16° limit). The knife's 1 s charge ("one second charge time for knife only") is
  `Stab.Cooldown`, was 0.6.
- **The dive, Oct 20 15:13** ("make it so that the leap for the catchers is way better and more smooth, right now its
  like a ragdoll, make it straight to the point and without a long unconsiousness, make it concrete"): it lay flat
  and dazed for 2 s (head rolling, stars, badge) and was up at 2.83 s, with no crouch first and a dead stop at the
  push's end. Now a crouch, a straight dive, a belly slide and a pop up, running again at 0.80 s (stun 0.4 s).
- **Up 24, was 18**: at 18 the body was off the floor 0.18 s (5 frames) and 0.8 studs high, too short to show a
  take-off, a knife leading and a landing; HV's catcher is in the air ~0.4 s.
- **Pinpoint, Oct 19** (owner: "make the player to player interactions pinpoint precise. For example make them
  all be in the same spots on everyones screen because its like that in huss valley, so please make it pin point so
  people dont die and start compalining"): before, the server re-tested the touch against its own history with a
  guessed lag, so a fair hit on a 200 ms screen missed 30% of the time. Same day, a critic's cheat test: the first
  version took the claim's facing, turn and both positions as sent (stab behind you, 9.9 to 11.6 studs of reach),
  had no fallback (a 400 ms catcher went from 38% to 0%) and took dive hits after the landing; and when the end of
  a Hero run took a stun away (`PowerService.clear`), your own screen still held you stunned and unable to turn for up
  to 2.4 s (`Actions.stunned`, `Dash`: both now let go when `StunnedUntil` goes). All fixed. (The
  model's numbers moved a little that day: Lune's `CFrame.lookAt` faces the wrong way along Z, so its catchers had
  faced away; it has its own helper now, like `round_sim.luau`.) Not seen with real ping yet (Studio's
  Clients and Servers has no lag unless Studio's Incoming Replication Lag setting is raised).
- **The get-up arm snap** (fixed Oct 19 evening): ~2.7 s after take-off, while getting up (leapWeight 0.20, before
  the release at `Up`), the right arm turned 100° in one frame and stayed (`motion3d/move_smooth_measure.luau` at
  8.30 s): a CFrame Lerp toward `LIE`, near 180° from the run's swing, flipping the long way round. Fixed by the
  angle-by-angle arm blend (above).
- **Catch**: the knife-colour cut line and 10 sparks replaced 30 red-and-white sparks (generic, and HV has none).
  Downed runners used to lose their outline. The runner used to stop dead from a sprint.

## R6 knife swing and dive (Oct 22, `Shared/StabMotion` R6 part)
- Owner, 18:53: "make the animations for swinging the knives"; "make the jumping animation way better". On R6 the
  swing turns the body into the sweep, knife arm out level, free arm ahead; the dive tips the body flat along the
  dive direction, arms ahead, legs trailing, never under the floor (arms counted), then hands the joints back.
- Every limb is aimed with the shortest turn (`fromTo(DOWN, dir)`), so the twist about the C1 offset stays right.
- Test: `tests/R6Knife.spec.luau`. Video: `tools/preview/motion3d/r6_knife_scene.luau` (needs his R6Run: private).
