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
- **Shift lock strafe** (`Shared/LocomotionMix.strafe` / `strafePose`, in `Gameplay/Locomotion` for you and
  `Gameplay/PlayerMoves` for everyone else): the hips and legs turn toward the way you move (up to 70°, `Run.Loco.Strafe`),
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
- Not seen in Studio yet: the sprint and lunge feel, the Oct 19 huss, the feet-first gate on the owner's floors, the
  shift-lock back-pedal (negative AdjustSpeed), the AFK rejoin (live game only).

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
- Oct 17 round 2 (owner: "more cinematic", "less ui", "cutscenes dont cut out"): the huss's white trail went (`Feel`
  draws HV's thin speed lines), no letterbox bars, our own footsteps.
