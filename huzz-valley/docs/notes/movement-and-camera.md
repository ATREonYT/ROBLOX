# Movement and camera vs Huss Valley

Read before changing the sprint, the huss (Space dash), FOV, speed lines, footsteps, the round camera or shot
changes. Study: `docs/feel-study.md` gaps 4-9 and 14; spec `tests/Movement.spec`. Speeds per role: [round.md](round.md).
The huss pose and walk animations: [animations.md](animations.md).

## Moving
- `Gameplay/Sprint`: you set off at `Run.StartSpeed` 16 and reach the cap in ~0.5 s (`Ramp`).
- **Feet first** (`Sprint`): after a spawn or a teleport (more than 12 studs in one frame: the round start, the fall
  net), WalkSpeed is 0 until
  `Humanoid.FloorMaterial` says the feet are on the floor (sets the local attribute `HuzzFeetFirst`; the huss waits
  too). It lets go one frame after landing, at once on normal ground, and always after 3 s (a floor Roblox can't read)
  or when sitting. Why the 3 s: a gate that can hold forever is worse than a bad landing.
- **Speed up each round:** everyone (runners, catchers, the Practice Bot) is 2% faster per round after the first, up
  to +20% (`Round.SpeedUp`, `RoundRules.speedScale`, set on the server; `State` attribute `SpeedUp` for the HUD).
  The lobby never changes. [round.md](round.md).
- **Setting off** (`Run.Loco.SetOff`, `LocomotionMix.step`): the legs move on the first frame; a short walk
  (0.12 s) then blends into the run over 0.2 s: walk at 0.07 s, full run at 0.37 s. Huss Valley (their video
  f1c7bb86, 30.73 s): legs move at once, short steps to ~0.15 s, full stride by ~0.35 s. The ground speed is
  Roblox's (instant), only the legs build, so controls stay sharp.
- **Stopping** (`Run.Loco.Stop`, `StopResponse` 30, `LocomotionMix.stopAmount` / `stopArm`): let go from a run and
  the ground stops at once (as Roblox's and Huss Valley's: measured, within one 60 fps frame at 52.13 s); the legs
  go straight from the run to the idle (never through the walk), idle at 0.15 s (HV ~0.15 s: the run pose holds
  ~0.15 s, idle at 52.30); a small plant: the body tips back 4°, the arms go 13° out and 12° forward, full at 0.07 s,
  gone by 0.32 s. Only from a full run; pressing again cancels it. Before: the legs ran on in place ~0.3 s.
  Everyone else's stop: [animations.md](animations.md) (the velocity hint).
- **The head follows the mouse** (`Gameplay/HeadAim`, `LocomotionMix.look`, `Run.Loco.Look`, `Gameplay/Locomotion`
  and `PlayerMoves`): the head looks at the point under the cursor (a ray from the camera through the mouse, your
  own body skipped; 300 studs along it at the sky), up to 70° each way (`Look.Max`) and 30° up / 35° down (`Up`,
  `Down`), fading to straight when the point is behind you past 110°. Touch screens and gamepads have no cursor:
  the camera's middle. Without shift lock D turns the body right (Roblox's AutoRotate) while the head stays on the
  mouse; in shift lock the strafe keeps the turn and the head still tilts up and down. Same exact neck solve as the
  strafe (tilt about the body's level, then the turn: no tip), the chest takes 40% of the turn. Spring 10 (~0.35 s
  to settle, at most 12° a frame at 30 fps). The camera doesn't move with the body (Roblox's Classic camera).
- **Everyone sees everyone's head** (`HeadAim.start`, remote `HeadLook`, `HuzzServer/HeadLookService`): your screen
  sends the head's turn and tilt as drawn, whole degrees, 5 times a second at most and only when it moved 2°; the
  server drops anything past 8 a second, NaN or text, clamps it to the neck's reach and puts it on your character
  (`HuzzLook`, a Vector2); every other screen springs to it (`RemoteResponse` 8: smooth between the 5-a-second
  values, ~0.2 s behind your own). Your own head never waits for the network. Specs: `tests/Locomotion.spec`
  (tilt, limits, the service's checks), `tests/PlayerMoves.spec` (another player's head from `HuzzLook`).
- **Shift lock strafe** (`Shared/LocomotionMix.strafe` / `strafePose`, in `Gameplay/Locomotion` for you and
  `Gameplay/PlayerMoves` for everyone else): the hips and legs turn toward the way you move (up to 90°: a full
  side-on run on D, as HV's at 52.13 s; `Run.Loco.Strafe`),
  the chest turns 40% of that, and the neck is solved so the **head keeps facing ahead**. S back-pedals (the legs face
  forward and the walk/run plays backward: `AdjustSpeed` with a negative speed). Only in shift lock, only on the
  ground, never in a huss, leap, stab or while down. Before, the body was held to the camera, so A/D slid sideways
  with the run playing straight ahead and S moonwalked. Film: `docs/previews/strafe-before-after.mp4`.
- **AFK rejoin** (`Gameplay/AfkRejoin`): Roblox kicks after 20 minutes without input and warns the game with
  `Players.LocalPlayer.Idled`. At 17 minutes idle we show one line and send the player back into the same server
  (`TeleportToPlaceInstance`), or any server if that one is full (at most 2 tries). Their save is kept as on any
  leave. Studio can't teleport: it only prints `[Huzz] AFK rejoin`. Only the live game can show it working.
- **The huss** (`Gameplay/Dash`): left/right along the **camera's** right; the body eases (0.08 s) to the nearer way
  along the camera's line (never a snap, at most a quarter turn; none in shift lock). The push is front-loaded:
  `Round.Dash` Speed 120 easing to EndSpeed 16 over 0.28 s on a cubed curve (`Ease` 3, `RunMotion.pushSpeed`:
  12 studs, 80% of it in the first 0.18 s). The pose leans in over 0.09 s (half of it on the first frame), holds
  while the push lasts and eases out of the crouch as it dies (`Run.Dash`). Ready again after exactly 2 s
  (`Round.Dash.Cooldown`; the server sets `DashCooldown` on the player for the HUD's bar). The server takes the
  sent facing within 150°. A catcher's lunge eases the same way (72 to 40 over 0.38 s, 19 studs, the old reach):
  [stab-lunge-catch.md](stab-lunge-catch.md).
- `Gameplay/Feel`: +2° FOV at full sprint, held through a huss; no huss FOV kick, no screen-edge streaks or line ring.
  A huss draws 6 thin white Beams riding with whoever husses (`RunMotion.hussLines`, `Run.Dash.Lines`), seen by
  everyone near (HV's thin speed lines; no white trail). Dust, steps, a `speed_wind` loop. Reduced Motion turns off
  the FOV.
- **Footsteps are ours** (`Feel`, Sfx "step", lobby too; Roblox's "Running" muted; stand-in thud until the owner
  uploads `step`). They step by distance (`Run.Stride` 12), so below ~28 they're slower than the feet.

## The round camera (`Gameplay/Cinematic` + `Shared/CinematicShot`)
- The line-up camera. The hand-back lands where Roblox's camera will be (zoom 12, 14° down, the shift-lock offset only
  when `ShiftLock.wouldLock()`: same test as ShiftLock, so not with Alt held, a menu open or the dance wheel up; zoom
  pinned for that moment), then zoom is capped at 22 in rounds; the lobby keeps the place's limits. You are ~31% of
  the screen tall, the horizon ~32% from the top. No letterbox bars.
- **Shot changes:** one 0.25 s quart swing that orbits round and over the runners (`Shot.transition`, at least 4 studs
  over heads), the eye pulled in front of walls and the floor (`clear()`).
- **Secret cutscene hand-back:** a 0.2 s dip to black; once fully black the camera goes back to Roblox (Custom) behind
  where you stand now (your old angle and distance), black holds 2 frames, then lifts (no fly-back, no cut on a clear
  screen).
- The Countdown waits for the camera's swing back: [round.md](round.md).

## Checks and films
- Film: `HUSS_ONLY=1 sh video.sh ramp_scene.luau out.mp4` (run from the repo root with the full paths:
  the scene reads its files from there), sheet `motion3d/huss_sheet.py` → `docs/previews/huss-oct19.jpg` (ours vs Huss
  Valley, same moments; `docs/previews/feel-huss-after.jpg` is the Oct 17 one). Shift lock:
  `motion3d/strafe_scene.luau` → `docs/previews/strafe-before-after.mp4`.
- Setting off, stopping and the head look: `sh video.sh feel_scene.luau out.mp4` (before left, after right; W at
  0.5 s, let go 2.0, D without shift lock 2.8, let go 4.3) → `docs/previews/feel-before-after.mp4`; sheet
  `python3 motion3d/feel_sheet.py <hv.mp4> <ours.mp4> <out.jpg>` → `docs/previews/feel-vs-hv-oct19.jpg` (HV rows
  from their video f1c7bb86). When HV's ground stops: `python3 motion3d/ground_flow.py <video> <start> <end>`
  (how far the ground moves each frame; useless while their camera turns). Numbers: `tests/Locomotion.spec` prints
  them (set-off, stop, plant, biggest weight change in a frame 0.30, others' stop).
- Not seen in Studio yet: the sprint and lunge feel, the Oct 19 huss, the feet-first gate on the owner's floors, the
  shift-lock back-pedal (negative AdjustSpeed), the AFK rejoin (live game only), the set-off, stop plant and head
  look on a real camera, others' stops over a real network, the head on a real mouse (and whether 5 sends a
  second look smooth enough on others in a full server).
- Still worse than HV: our idle holds the arms wider than theirs, so the stop lands in a different pose; the plant
  is our own made-up motion on the pack's poses (HV's arms swing out on a stop, 40.73 s), not their animation.

## Why it is this way / history
- All from the Oct 17 movement and camera study against Huss Valley. The sprint used to start at 9 and take 1.2 s;
  FOV at full sprint was 11°; the server took facings within 110°.
- The huss push is 12 studs since owner Oct 18 "a bit further" (was 9).
- Oct 19 (owner: "their huss is way quciker than ours, make it more smooth and quicker reset Huss (2 seconds)"):
  measured, ours took 0.05 s to lean (74% of it in one frame), froze, and pushed 64 to 28 studs/s, barely faster than
  the run. Now the same 12 studs come mostly in the first 0.18 s, as in Huss Valley's frames (crouch at once, upright
  by ~0.4 s). "speed goes up every round a very tiny bit"; "move when your legs touch the floor"; "make it so when
  you shift lock the only thing that moves when you press w a s d (etc) is their body not their head"; "make the
  players join back automatically after going afk and about to get kicked".
- Oct 19, 19:48 (owner: "Also, please make the users head move but make it follow mouse movements so the head doesnt
  just stay in one place, make it like the references of huss valley"): the head followed the camera's middle, and
  others' heads didn't move at all. Huss Valley's one recording (f1c7bb86) can't time a head swing: its runner wears
  a dark hood seen from behind, and where the cursor shows (48.25 to 50 s) it is ~5° off the middle, a turn too
  small to see; the line-up heads (0 to 30 s) hold still for seconds. So the reach (70° / 30° up / 35° down) and the
  speed (~0.35 s) are ours: a neck's reach, quick but never a snap.
- Oct 19, 18:16 (owner: "make the head not move for the user when he runs, for example when he presses D, the body
  turns right, but the head and camera stays the same, and also add some velocity into the game, and add animations
  for when you stop running, its a quick but nice looking stopping animation ... and then the slow walking into the
  running animation"; "in general can you make the gameplay way way smoother just like huss valley"): the set-off,
  the stop and the head look above. "Velocity" is in the legs, not the ground: a ground that slides on after you let
  go would make the controls slippery (GAME-FEEL.md), and HV's ground stops at once too. The first stop film had a
  bigger plant (7° back, 22° arms): the arms flapped and the head tipped back, so it is 4°/13°/12°. The strafe turn
  went from 70° to 90°, because HV runs fully side-on.
- Oct 17 round 2 (owner: "more cinematic", "less ui", "cutscenes dont cut out"): the huss's white trail went (`Feel`
  draws HV's thin speed lines), no letterbox bars, our own footsteps.
