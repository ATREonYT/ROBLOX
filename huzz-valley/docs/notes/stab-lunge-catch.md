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
- Owner Oct 19: "add a dive feature for the tagger and after they use it they are stunned for 2 seconds". It was a
  leap that landed in a low lunge; now the catcher dives flat out, catches whoever it reaches, and lies stunned.
- **Your own dive plays the moment you press Space** (`Gameplay/Dash` calls `Actions.lungeLocal` before its hit
  check; the server's "Stab" echo within 0.8 s is ignored). Everyone else plays it from the server's "Stab" `{ lunge = true }`.
- **The whole body dives** (it owns the root joint and the legs as well as the head and arms; the waist stays straight
  so the chest never dips under the floor): no crouch first (the push is already moving at 72), the take-off blends in
  over `In` 0.15 s (no pop at 60 fps); the body tips about the hips 22° → 46° → 72° → 84° → 88° (flat), the legs push
  off and stretch out behind, toes pointed; both arms reach ahead (`REACH`, superman), the knife leading, evenly
  over `ArmIn` 0.16 s.
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
- **The stun**: from `Lunge.StunAfter` 0.38 s for `Lunge.Stun` 2 s (`PowerService.stun`): speed 0, no stab, no
  abilities, the body doesn't turn to the camera (`Gameplay/ShiftLock`, `Dash` holds AutoRotate off). It lies dazed
  (`Out` = StunAfter + Stun = 2.38 s), the head rolling slowly side to side (`Daze` 16° at 0.5 Hz), three cartoon stars
  circling over the head (`Gameplay/PowerEffects`) and the server's 💫 STUNNED badge; the bar's STUNNED 💫 drains
  ([ui.md](ui.md)). Then a push-up and stand, back to the run by `Up` = Out + `Rise` 0.45 s.
- **A sideways dive** (A / D) does the same into its side.
- **Height** (`Config/Round.Lunge` Up 24): 0.245 s in the air, 1.5 studs. The push (72 to 40 over 0.38 s, 19 studs)
  and the hit box are the round's ([round.md](round.md)).
- **The leap's ribbon** (`KnifeLook.CATCH.Streak`, HV's lunge ribbon): a Trail between two points on the UpperTorso,
  white into the knife's colour (its `SlashColor`, else steel white), 0.14 s long (~8 studs at the leap's speed), on
  for the push only (`Gameplay/Actions`).
- Spec `tests/StabMotion.spec` (the dive: lying flat at 0.39 s, 1.2 s and just before Out, the lowest point within 0.15
  of the floor; the free arm reaching ahead; a sideways dive tips into its side; slash within 0.08 s of reaching
  someone, at SlashBy otherwise; body parts turn at most 16°/frame at 60 fps (14.6 today) and 30° at 30 fps; the
  arms over a ±60° run swing at 30 fps, 8 phases, with and without a hit, at most 68° a frame (61.2 today); every
  joint handed back after Up). Films `docs/previews/dive-stun.mp4` (`motion3d/catch_scene.luau`, side view: the dive,
  the 2 s stun with the stars, getting up, then the catch at 1/4 speed); the older leap: `docs/previews/knife-leap.mp4`.

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
  done: moving the caught body to where the knife touched (the runner would see a snap back) and drawing others
  ahead of where they were (wrong places on every turn).
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
