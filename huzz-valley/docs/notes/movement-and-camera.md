# Movement and camera vs Huss Valley

Read before changing the sprint, the huss (Space dash), FOV, speed lines, footsteps, the round camera or shot
changes. Study: `docs/feel-study.md` gaps 4-9 and 14; spec `tests/Movement.spec`. Speeds per role: [round.md](round.md).
The huss pose and walk animations: [animations.md](animations.md).

## Moving
- **The build-up** (`Gameplay/Sprint`, `RunMotion.rampSpeed`): you set off at `Run.StartSpeed` 16 and reach the cap
  in exactly 1 s (`Ramp` 1, `RampEase` 2: eases out, 44% of the build at 0.25 s, 75% at 0.5 s, 90% at 0.69 s, no
  jolt at either end). Once built, a new cap (a boost, carrying, slowed) is followed over ~0.15 s. The legs follow
  the speed (the run's step rate is already at its 1.12x cap from ~16 studs/s, so the slower build adds no foot
  slide); the forward lean is `Loco.AccelLean` 0.2 (~5° at the start, upright as the build tops out).
- **Walk first** (Oct 23: "add the walking animation first, then after holding w ... starts running"): you set off at
  `Run.StartSpeed` 7 (his R6 walk, up to 2.1x so its feet stay planted), keep walking `Run.WalkHold` 0.4 s, then build up to the cap in `Ramp` 1 s. R6 hands
  the walk to the run between `LocoR6.RunFrom` 9 and `RunFull` 15 (R15's `Loco` keeps 6 to 11). Speed lines only above
  `SpeedFX.RunFrom` 15 and only while you hold a direction.
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
  the ground stops at once (as Roblox's; HV's at 52.13 s within ~2 frames, but that was from a walk); the legs
  go straight from the run to the idle (never through the walk), idle at 0.15 s (HV ~0.15 s: the run pose holds
  ~0.15 s, idle at 52.30); a small plant: the body tips back 4°, the arms go 13° out and 12° forward, full at 0.07 s,
  gone by 0.32 s. Only from a full run; pressing again cancels it. Before: the legs ran on in place ~0.3 s.
  Everyone else's stop: [animations.md](animations.md) (the velocity hint). From 90% of your top speed or more a
  stop is a halt instead (below).
- **The halt** (`Shared/Halt`, `Gameplay/Sprint`, `Run.Halt`, `RunMotion.haltFrom` / `haltPush`): let go of every key
  at 90% of your top speed or more (`From`) and the body carries on, slowing from your speed (never more than your
  top speed, so letting go just after a huss, a dive or a shove slides no further: ~2.6 studs) to 0 over 0.25 s
  (`Time`, `Ease` 2): ~2.3 studs at a runner's 28 (2.6 as the game samples it at 60 fps), 1.8 in the lobby, at most
  3 at the fastest catcher. A LinearVelocity in the ground plane moves the real body (as the huss does), so walls stop
  it, the server's `HitHistory` sees it and every screen sees the slide. The plant plays at once and the legs come
  together over 0.08 s while the steps slow to a stop over 0.12 s (`Loco.Stop.Halt`; LocomotionMix `input.halt`): a
  skid, not a run. The legs also brace at once (`Loco.Stop.Halt.Brace`, LocomotionMix `brace` / `braceJoint`): up in
  0.08 s, held while the body slides, eased back to the idle over 0.16 s once it stops: the hips drop 0.45 studs,
  turn 30° side-on and lean back 9°, the left thigh forward 40° with the knee bent 45°, the right back 25° (HV's
  f1c7bb86: a wide braced stance from 41.23 to 41.45 s, upright by ~41.5). It ends at once on any key (turning round is never a halt: the new key takes over the next
  frame), a huss or dive, being downed or frozen (`HuzzSpeed` at or under 16), sitting or leaving the floor.
  A lobby tap or a short dash never reaches 90%. Your screen marks it with the local attribute `HuzzHalt`; everyone
  else's halt shows from their Humanoid's `MoveDirection` going to zero while their body still slides at a run
  (`Gameplay/PlayerMoves`, only once their MoveDirection has been seen moving; never mid huss or dive, which on a
  phone moves fast with no key held, nor in the air, from their tracked climb or their replicated vertical speed).
  The Practice Bot never halts: it stops after a stab to give the kid a breather, and a halt slid it ~2.3 studs
  toward them (critic, Oct 20).
- **The head follows the mouse** (`Gameplay/HeadAim`, `LocomotionMix.look`, `Run.Loco.Look`, `Gameplay/Locomotion`
  and `PlayerMoves`): the head looks at the point under the cursor (a ray from the camera through the mouse, your
  own body skipped; 300 studs along it at the sky), up to 70° each way (`Look.Max`) and 30° up / 35° down (`Up`,
  `Down`). A point behind you is mirrored to the front (`LocomotionMix.aimFrom`, Oct 20): standing facing the camera,
  the cursor always lands on the field past you, and the old fade kept the head still ("it doesnt seem fixed",
  14:07); now the head turns toward the cursor's side of the screen (20-26° with the cursor out to the side of the screen,
  in `motion3d/moves_check_scene.luau`) and looks at the camera when it is in the middle. Touch screens and gamepads have no cursor:
  the camera's middle. Without shift lock D turns the body right (Roblox's AutoRotate) while the head stays on the
  mouse; in shift lock the strafe keeps the turn and the head still tilts up and down. Same exact neck solve as the
  strafe (tilt about the body's level, then the turn: no tip), the chest takes 40% of the turn. Spring 10 (~0.35 s
  to settle, at most 12° a frame at 30 fps). The camera doesn't move with the body (Roblox's Classic camera).
- **On Roblox's newer joints too** (owner, Oct 21: "the body and the head move seperatley, the head from the mouse,
  and the body from the controls ... ive asked you before but i dont think you understood"): his avatar has
  AnimationConstraints, no Motor6D. `Gameplay/Locomotion` and `Gameplay/PlayerMoves` only took Motor6Ds, so on his
  body the head look, the lean, the strafe and the pack's walk never ran (Roblox's plain walk instead), on his screen
  and everyone else's. Now every joint is found with `CarryMath.holding` (either kind, doubled ones written together);
  CrownPose too. Specs: `tests/AvatarAnims.spec` "newer joints", `tests/PlayerMoves.spec` (head turns on that body).
- **Small angles (Oct 21, owner: "make it perfect so it doesnt seem weird in little angles"):** the head aims no
  nearer than `Look.Near` 40 studs past itself along the cursor's ray (`HeadAim`: a cursor on the floor or a wall
  just past you swung it a long way and jumped at edges), and holds still in the world while the body turns under it
  (`LocomotionMix.look`'s yaw, up to `HoldMax` 60° a frame, never past the neck's reach or when aiming behind you):
  a 30° tap of D used to drag the head 20° off the aim before it sprang back, now 0 (`tests/Locomotion.spec`).
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
- `Gameplay/Feel`: +6° FOV at full sprint (2 + `Config/Run.SpeedFX.Fov`, Oct 22: the owner asked for a more intense
  run with his clip), held through a huss; no huss FOV kick.
- `Gameplay/SpeedFX` (Oct 22, owner: "add some effects when you are running and make it feel more intense"; his clip
  in `design/owner-oct22/video-1616`): from sprint 0.45 up, 8 thin white Trails (feet, knees, hands, elbows; R6 and
  R15 points) on every runner near the camera, off when hidden, down, dancing or dead; a blue glow on the left, right
  and top screen edges (none at the bottom, as in the clip), eased, never flashing, off with Reduced Motion and the
  intro camera. Tuned in `Config/Run.SpeedFX`. Film: `motion3d/r6_speed_scene.luau`, side by side with his clip in
  `docs/previews/oct22-r6-run-side.mp4`. Smoke: `tools/preview/smoke_speed_fx.luau`.
  A huss draws 6 thin Beams riding with whoever husses (`RunMotion.hussLines`, `Run.Dash.Lines`), seen by
  everyone near (HV's thin speed lines; no white trail). Oct 22 ("make the huss look better and more premium"): the
  lines glow white to a cool blue and are a little wider, and 4 see-through glowing copies of the body are left
  along the move, fading out (`Run.Dash.Ghosts`, `Gameplay/Ghosts`; never on hidden bodies). Before / after:
  `motion3d/huss_fx_scene.luau` (OLD=1), `docs/previews/oct22-huss-premium.mp4` (project files). Dust, steps, a `speed_wind` loop. Reduced Motion turns off
  the FOV.
- **Footsteps are ours** (`Feel`, Sfx "step", lobby too; Roblox's "Running" muted; stand-in thud until the owner
  uploads `step`). They step by distance (`Run.Stride` 12), so below ~28 they're slower than the feet.

## Same place on every screen (Oct 20)
- Owner, Oct 20 15:13: "please make the DSYNC way, way better. right now on peoples screens it sometimes doesnt match
  up and the peoples locations are off on eachothers screens".
- **Cause found:** your client simulates your body and sends where it is; the server and every other screen
  follow. The server set CFrames on those bodies itself (7 `PivotTo`s in RoundService: lobby, middle, line-up,
  keep a catcher out of the safe zones, keep a safe runner in, keep a runner on the line; plus MapService's fall
  net). The owner kept sending positions from before the move until the change reached it, so the others saw the
  body jump there, back, and there again. The safe-zone and line checks ran every frame from the server's older
  copy, so they kept fighting the player's own running.
- **Fix:** the body's owner moves it. `HuzzServer/PlaceService` (`place`) asks that screen (Net `Place`;
  `Gameplay/PlaceSelf` stops the body and moves it). The server watches for `Config/Round.Place` Grace 0.4 s plus the
  round trip, and moves the body itself only if its copy never came within Near (4 studs). That happens once, with a
  `[Huzz] Place:` line in Output. `pending()` stops the every-frame checks from sending again while a move is on its
  way. The spot is streamed in first (`RequestStreamAroundAsync`): his place pauses bodies outside loaded areas.
  An anchored body (lying caught, KnockdownService) is the server's, so the server still moves it at once.
- **What doesn't move bodies:** the huss, halt, Glitchy and the dive push only your own root (LinearVelocity, `mine`).
  The run, the leap and the dances move joints only, so they are drawn on each screen and never move the body. Hits
  are judged with lag rewind (`HitHistory`, `TouchHit.verify`).
- **Checked offline:**
  - `tests/PlaceService.spec.luau`: the screen is asked and the server writes nothing; a screen that never answers
    gets one fallback; someone who arrived and ran on is not pulled back; a respawned body is left alone; PlaceSelf
    moves only your own unanchored body; no character `PivotTo` is left in RoundService but the reset while down.
  - The sim: bots answer 0.12 s late and the server never had to move one itself (0 in all 10 setups).
- **Only a live test shows it (Studio Test > Clients and Servers, 2 players):** watch the line-up, the GO, a
  catcher pushed out of a safe zone, a runner across, a catch and a fall off the map on both windows side by side.
  Bodies should land once, with no jump back. Send any `[Huzz] Place:` line.
- **Gaps:**
  - The catch used to lie the runner down where the server last saw them, so on their own screen they snapped back
    about half a ping of running. Oct 21: the server adds that run (speed along their facing x half their ping, at
    most `Knockdown.Lead` 0.15 s) to the slide, and every screen eases its own view of the body into the fall over
    `Knockdown.Blend` 0.3 s (`DownMotion.leadSlide` / `blendAt`, `Gameplay/Knockdown`; tests/DownMotion.spec).
  - Every screen is behind by the network delay; nothing removes that.
  - WalkSpeed is set by the server (the round speeds) and every frame by `Gameplay/Sprint`. This changes speed, not
    where you are, and it was left as it is.

## Server Authority test place (Oct 21)
- Owner, Oct 21: "check the desync again ... run it on a server client so it works best"; picked "Tune now, Server
  Authority test". Roblox's Server Authority (Workspace.AuthorityMode = Server) makes the server the only truth and
  runs the same code one step ahead on your screen, rewinding it when the server disagrees. It needs every move
  rewritten as a shared simulation (`BindToSimulation`, InputActions, attributes), so it is tried in its own place
  first: `sa-test/` (README there), `places/ServerAuthorityTest.rbxl`, checks `lune run huzz-valley/sa-test/check.luau`.
- Golden slice: the 1 s build-up, the huss, the dive and the catch, with the game's own numbers (Config/Round, Run).
- Not checked anywhere but Studio: whether Roblox lets the simulation set Humanoid.WalkSpeed (a `[SATest]` line says
  if not), how the corrections look at real ping. No animations, girls, rounds or UI there.
- Own notes from Roblox's docs and the Cakeman example (github.com/MrChickenRocket/Server-Authority-Tutorial-Cakeman):
  60 Hz not the default 30; buttons only through InputActions under the Player; state only in attributes on the
  root; no clocks but dt; no effects in the step; other players are drawn slightly in the past (not guessed).

## Map size: nothing scales the map (Oct 20)
- Measured: the maps in the place file are his size (Base 752x329, BasketBall 317x167, Halloween 319x164), and no
  script resizes a map. What can make a map *feel* smaller:
  - **Speed:** Lobby 22, Runner 28, Catcher 30, Holder 27, LastRunner 30, Thief 30 studs/s (`Config/Round.Speeds`),
    against Roblox's 16 (the place's `CharacterWalkSpeed`). They were 20/24/26/23/26 before his "run quicker" asks.
    Plus 2% a round after the first, up to +20% (`Round.SpeedUp`): a runner can reach 33.6, a catcher 36.
  - **Setting off:** 16 to top speed in 1 s (`Run.StartSpeed`, `Ramp`; 0.5 s until Oct 20).
  - **Huss:** 12 studs in 0.28 s (Dash Speed 120 easing to 16).
  - **Camera:** in rounds the zoom starts at 12 and is capped at 22 (`Shot.RoundZoom` / `RoundMaxZoom`); the lobby
    keeps the place's limits (max 128). FOV only +2 degrees at full sprint (was 11).
- To make a map feel bigger without touching it: lower the speeds or the speed-up in `Config/Round`.

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
- **The HERO / CHICKEN shot holds still** (owner, Oct 21: "make the camera not be locked onto you moving with your
  characters movements, just keep it focused in one place, then zoom in and out"): the face shot is set up once from
  the picked runner's head and body facing when it lands (their pose and head look used to drag it up to 9 studs and
  52°), then Chosen eases in over `Shot.PushTime` 0.6 s and the hand-back pulls out. Check:
  `tools/preview/check_hero_camera.luau` (harness, with setup_ui.luau).
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
- The build-up and the halt: `sh motion3d/halt_side.sh <hv f1c7bb86.mp4> out.mp4 out.jpg` (repo root) films
  `halt_scene.luau` and puts it next to HV's one full-speed stop, same framing (HV's camera at 40.3 to 41.6 s: turned
  round in front of the runner, ~20° down, the runner coming toward it, facing the way it runs), 30 fps →
  `docs/previews/halt-vs-hv.mp4` / `.jpg`. Specs: `tests/Halt.spec` (the real Sprint and Halt on a fake body: 1 s
  build, ~2.6 studs, every way it ends, no halt from a tap, ≤ 2.8 studs after a 60 studs/s shove),
  `tests/Movement.spec` (the numbers), `tests/Locomotion.spec` (the skid; the brace up by 0.08 s, held, gone 0.15 s
  after the stop, at most 0.31 of it a frame), `tests/PlayerMoves.spec` (another player's halt: the thigh moves 6°
  through the skid against 78° running on; none mid huss with no key, none falling). Smoothness:
  `move_smooth_measure.luau` "let go: halt" (worst part turn in a frame at 30 fps 57°, pop 76° on the legs as the
  brace comes in at the worst phase; a running stride's own turns are 66-68° and pops 60-68°).
- Not seen in Studio yet: the 1 s build-up and the halt (whether Roblox's Humanoid lets the LinearVelocity carry the
  body as cleanly as offline, the halt against walls and other players, and whether other players' MoveDirection
  reaches every screen: if it doesn't, their halt slides with the legs stopping by speed instead), the sprint and lunge feel, the Oct 19 huss, the feet-first gate on the owner's floors, the
  shift-lock back-pedal (negative AdjustSpeed), the AFK rejoin (live game only), the set-off, stop plant and head
  look on a real camera, others' stops over a real network, the head on a real mouse (and whether 5 sends a
  second look smooth enough on others in a full server).
- Still different from HV's halt: their legs keep running ~0.2 s while the ground slows (41.19 to 41.38 s); ours
  plant and brace at once (the brief: a skid). Their braced stance is wider and lower than ours and their arms stay
  forward (they hold a knife); our brace is a made-up pose on the pack's legs, not their animation. In the side by
  side their runner fills more of the frame than ours (the crop of their 3020 px video against our 720 px camera).
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
- Oct 20, 07:55 (owner: "Make acceleration 1 second long and after they randomly stop after fully running they move
  a little forward as a sort of "hault" like in the game Huss valley"): the build was 0.5 s to ~95%. Measured again:
  only one HV recording is here (f1c7bb86; 32fe8d21 and 87565d66 aren't in the uploads), and it holds one stop from a
  full run, at 41 s (52.13 s, the "stops within a frame" above, was from a walk: ~6 studs/s; 59.66 s is a cut to the
  line-up). At 41 s, calibrated by the floor's 1-stud squares (~120 px each at the measured patches), their run is
  ~26 studs/s; the ground slows from 41.05 s and stops at 41.47 s: ~5.7 studs in all, ~2.5 studs over the last
  0.28 s from 60% speed, ~0.8 studs after the legs stop running (41.38 s), idle at ~41.5 s. Ours: 2.3 studs over
  0.25 s, the legs planting at once. Ease 3 was tried first (65% of the slide in the first 30 fps frame: a jolt).
- Oct 17 round 2 (owner: "more cinematic", "less ui", "cutscenes dont cut out"): the huss's white trail went (`Feel`
  draws HV's thin speed lines), no letterbox bars, our own footsteps.

## Oct 22 evening: dive snap-back, lobby fall, R6 stop
- MoveGuard sent a catcher who ran and then dived back up to 2 s (often to the middle spawn): the dive's stun is
  WalkSpeed 0, and that 0 counted for the whole run before it. `MoveGuard.look` now allows the highest top speed seen
  since the accepted spot (`rec.top`). Test: MoveGuard.spec "a catcher's run and then a dive".
- `Gameplay/PlaceSelf.holdUntilFloor`: after a move to the lobby, if no floor is found under you yet (it is still
  streaming in), the root is held (anchored, attribute HuzzFloorWait) until it is, at most 4 s.
- `Gameplay/PlayerMoves.r6Stop`: the stop's plant (arms out) and the halt's brace (side-on, lean back, front leg
  forward, back leg braced, arms out) on R6 bodies; the R15 ones were never applied to R6.
- Not done: a full server-authority movement rewrite (the owner's "make the game server sided"); `sa-test/` (Oct 21)
  is the experiment. MoveGuard still checks speed on the server.
