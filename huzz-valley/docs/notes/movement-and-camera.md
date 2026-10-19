# Movement and camera vs Huss Valley

Read before changing the sprint, the huss (Space dash), FOV, speed lines, footsteps, the round camera or shot
changes. Study: `docs/feel-study.md` gaps 4-9 and 14; spec `tests/Movement.spec`. Speeds per role: [round.md](round.md).
The huss pose and walk animations: [animations.md](animations.md).

## Moving
- `Gameplay/Sprint`: you set off at `Run.StartSpeed` 16 and reach the cap in ~0.5 s (`Ramp`).
- **The huss** (`Gameplay/Dash`): left/right along the **camera's** right; the body eases (0.08 s) to the nearer way
  along the camera's line (never a snap, at most a quarter turn; none in shift lock). The push eases every frame from
  `Round.Dash` Speed 64 to EndSpeed 28 over 0.30 s (`RunMotion.pushSpeed`: 12 studs). The server takes the sent facing
  within 150°. A catcher's lunge eases the same way (72 to 40 over 0.38 s, 19 studs, the old reach):
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
- Film: `HUSS_ONLY=1 sh video.sh ramp_scene.luau out.mp4`, sheet `motion3d/huss_sheet.py` →
  `docs/previews/feel-huss-after.jpg`. Not seen in Studio yet (sprint feel, the lunge feel).

## Why it is this way / history
- All from the Oct 17 movement and camera study against Huss Valley. The sprint used to start at 9 and take 1.2 s;
  FOV at full sprint was 11°; the server took facings within 110°.
- The huss push is 12 studs since owner Oct 18 "a bit further" (was 9).
- Oct 17 round 2 (owner: "more cinematic", "less ui", "cutscenes dont cut out"): the huss's white trail went (`Feel`
  draws HV's thin speed lines), no letterbox bars, our own footsteps.
