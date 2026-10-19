# Animations and dances (the owner's files)

Read before touching the movement pack, how everyone walks, the huss pose, the girls' moves, carried girls, dances,
dance pictures or the dance wheel. The stab and lunge: [stab-lunge-catch.md](stab-lunge-catch.md). Root `CLAUDE.md`
has the general KeyframeSequence workflow; 3D video tools are in core `CLAUDE.md` section 4.

## The pack and IDs
- Videos: `tools/preview/motion3d` (`sh video.sh <scene.luau> <out.mp4>`): `anim_scene.luau` plays any
  KeyframeSequence (`ANIM_FILE`, `ANIM_NAMES`, `ANIM_VIEW=back|side`); `dance_poses.luau` picks each dance's pose and
  writes `Config/DancePoses`; `aura_star_scene.luau`. Render.mjs loads `assets/fx` and two
  `assets/icons`.
- `tools/anim/extract_anims.luau` → `ServerStorage/HuzzAnimations.rbxm`: Idle, Walk, **Run = the pack's Sprint as it
  is** (big arm swings; `docs/previews/run-arms-vs-hv.jpg`), Jump, Fall, Climb, **DashLeft/DashRight** (built: a
  compact sideways lean), and 25 `Dance_<Id>` (our own names; the originals are other games' emotes).
- `Shared/AnimationLibrary.id`: published ID, else in Studio a temporary ID (KeyframeSequenceProvider), else "".
  Temporary IDs play only on the client that made them. The live game needs `tools/studio/publish-animations.lua`.

## Everyone walks with the pack, Studio and live, nothing uploaded
- `Gameplay/Locomotion` plays Idle/Walk/Run on your own Animator when it can (Studio); `Gameplay/PlayerMoves` (Frame
  order 8) samples the same three from `HuzzGirlMoves` by hand onto every other R15 body's Motor6D.Transform (and
  yours in live), blended by `LocomotionMix`.
- Others' speed comes from their body's position over a 0.25 s window (`LocomotionMix.track`, `Run.Track`: holds
  through 0.15 s network stalls, ignores teleports), never their replicated velocity (that jumpy number made the old
  scripted legs stutter). Fades out for a dance/Action track; downed = speed 0 under the knockdown; carriers' arms go
  to CarryAnimator. LOD: re-sampled every frame within 70 studs, 30/s to 160, 15/s beyond or behind the camera.
  `RunAnimator` now draws only the huss and cast on top (`dashOnly`); its scripted run shows only before the pack's
  folder arrives.
- **Planted feet** (`Config/Run.Loco`, measured by `motion3d/pack_measure.luau`): the pack Walk keeps its foot still at
  4.35 studs/s (`WalkAt` 4.3), the Run at 14 (`RunAt` 14); walk hands over to run at 6-11 studs/s. Foot slide is under
  5% up to 16 studs/s; the run is capped at 1.12x = 4.6 steps/s (HV's), so at 28 the feet slide ~44% like HV's quick
  steps. Speeds scale with avatar size (`RootHeight` 3).
- Specs `tests/Locomotion.spec` (pure maths) and `tests/PlayerMoves.spec` (the real Gameplay files on fake bodies).
  Film `docs/previews/remote-walk.mp4` (`motion3d/remote_walk_scene.luau`: before/after over a jumpy network, then the
  set-off from behind); sheet `docs/previews/walk-vs-hv.jpg` (`motion3d/walk_sheet.py`): full run ~0.1 s after W in
  both. Footstep sounds: [movement-and-camera.md](movement-and-camera.md). Not seen in Studio yet.
- **Shift lock strafe** (`LocomotionMix.strafe` + `strafePose`): hips and legs turn to the move, the head stays on the
  aim, S back-pedals; [movement-and-camera.md](movement-and-camera.md). `strafePose` solves the neck exactly (the
  head's turn is undone through the hunched run pose); a plain counter-turn on the neck tipped the head sideways.

## Layering poses on Motor6D.Transform (every pose module; lesson of Oct 19)
- Layers run in Frame order: 8 PlayerMoves, 10 RunAnimator (huss), 12 Locomotion (lean and strafe), 20 carry,
  30 stab, 40 knockdown. Each keeps what it wrote (`written`) and the pose under it (`base`), and builds from `base`,
  never from its own last write.
- **Releasing:** put `base` back only on a joint whose Transform is still exactly what you wrote. If anything else
  wrote it since (the pack's next frame), leave it: writing the old base back showed a stale pose for one frame, a
  pop of up to ~178° at the end of every huss and leap (RunMotion, StabMotion, CarryMotion, DownMotion, PlayerMoves).
- Measure smoothness, don't eyeball stills: `lune run huzz-valley/tools/preview/motion3d/move_smooth_measure.luau [fps]`
  (repo root) runs the real layers through idle, W, huss, strafe, stab, leap, S and stop, and prints each moment's
  biggest turn per frame and its "pop" (the change between one frame's motion and the next).
  `MOVE_TRACE="Part,Part:from:to"` prints frames. Oct 19, 30 fps: huss pop 110° → 63° (the run itself is ~66°),
  the end-of-leap flip gone. The click stab is still a fast sweep (~100° in a frame, as Huss Valley's slash).

## The huss pose (`Shared/RunMotion`, for everyone, you too)
- `Gameplay/RunAnimator` draws only the huss on your own character when your run is the pack's: a wide low crouch:
  Crouch 0.75 (head drops 19%), leaning ~28° mostly at the waist (`Run.Dash` SideRoll 12 + SideWaist 14), outside leg
  out 55°, inside thigh up 45° and out 42°, knee -80. In over 0.09 s (half on the first frame), held while the push
  lasts (0.28 s), upright by 0.40 s, the crouch easing out with the push (`Run.Dash` In/Out/Settle; the old 0.05 s
  blend put 74% of it in one frame). Still narrower and higher than HV's flat straddle (`docs/previews/huss-oct19.jpg`).
- Your own huss's server DashAt is ignored within 0.6 s of your local one (`RunMotion.dashAt`, local attribute
  HuzzMyDashAt), so a laggy echo never restarts the lean or lines.
- The built DashLeft/DashRight (38° lean) plays only once the owner publishes a run (`Config/Animations.Run`);
  re-extract with a smaller lean before then.

## The girls on the pack (`Shared/GirlMoves`, no upload needed)
- Bootstrap copies Idle/Walk/Run to `ReplicatedStorage.HuzzGirlMoves` in Studio AND live (~180 KB); the follower girl,
  your companion (both via `FollowMotion` `rec.moves`) and the prize's idle play them by hand, retargeted to R6
  (`DanceRetarget`), blended by `LocomotionMix` with `Config/GirlMotion.Pack`.
- Planted feet: each straight leg aims its foot over the R15 foot, the body surges with the step (a lock measured from
  the loop, which also sets each loop's 1x speed) and is lowered onto the stance foot. At most `Pack.MaxSteps` 4.8
  steps/s, the lock rounded off and faded as her feet slide (`Pack.Surge`): 23°/frame, no jolts
  (`motion3d/girl_smooth_measure.luau`; limits in the spec). Scripted `GirlMotion` walk/idle only until the folder arrives.
- Spec `tests/GirlMoves.spec`, video `docs/previews/girl-pack-walk.mp4` (`motion3d/girl_pack_scene.luau`).

## Carried girls (`GirlMotion.carried`, `Config/GirlMotion.Carried.Pose`)
- She sits up in his raised hands (upper body up 24°, legs bent up 62° at the hips, R15 knees bent, arms half hanging),
  dips and dangles on his real footfalls (`CarryMotion` reads his right hip), swings her feet, a small kick, wave or
  look round now and then; calm (under 6° a frame). Spec `tests/GirlMotion.spec`. Before/after film
  `docs/previews/girls-walk-carry.mp4` (`motion3d/girls_walk_carry_scene.luau`). Not seen in Studio yet.
- **The pickup** (`CarryMotion`, `Config/Carry` PickupTime 0.85, ArcHeight 2.5, PickupSpin 1): won from far away
  (the big girl over the map; anything over `PickupNear` 10 studs) she appears standing on the ground 3.2 studs in
  front of him, rises in a short arc turning once round herself (slowing), and only in the last 60% lies back into his
  arms; taken off a head close by (a steal) she flies over from there, lying as she was. His arms ease up to meet her
  (smoothstep, all the way by 62% of it). No jump at the start or the landing (spec). Effects:
  [effects.md](effects.md). Spec `tests/GirlPickup.spec.luau`; film `docs/previews/girl-pickup.mp4`
  (`motion3d/girl_pickup_scene.luau`, before/after lanes). Not seen in Studio yet.
- **Seen on every screen** (owner, Oct 19: "make the girls be seen on everyones screen"): every girl the server
  makes (carried, following a catcher, the prize) is `ModelStreamingMode` Persistent (his place streams: a plain
  Model reaches other players before its parts), and `CarryAnimator` waits for her parts (`whenWhole`) before moving
  her (the follower used to give up at once when her root hadn't arrived, and stood frozen where she was caught).
  Your first girl is equipped when you win her (if you had none), so she walks behind you for everyone.

## Dances
- `UI/DancePlayer` (one at a time; walking stops it; **in step**: the `Dance` remote puts HuzzDance / HuzzDanceAt
  (server time) on your character, and starting the same dance within 30 studs of a dancer joins their beat).
  `Gameplay/CompanionDance` puts your dance on your R6 girl at your track's time, and other players' girls on their
  HuzzDance / HuzzDanceAt. Dance music: [sounds.md](sounds.md).
- **Synced dancing** (owner, Oct 19: "make synced dancing"; `Gameplay/DanceSync`, Frame order 9). The rule: a dance's
  beat is HuzzDanceAt; on every screen each dancer is shown at `(server now - beat) % length` (`DanceSync.timeAt`),
  so dancers on one beat move as one everywhere. A track on screen (yours, or a replicated one) is nudged back when it
  drifts over 0.12 s; another player's dance with no track on this screen (Studio's stand-in IDs only play for their
  maker; a published one may still be loading) is drawn by hand from its KeyframeSequence on their R15 joints (the
  15 parts PlayerMoves drives; fades 0.25 s; within 120 studs). **Dance together:** a prompt on another dancer (F /
  gamepad Y, 12 studs, "DANCE TOGETHER", their dance's name) while you're free (no round, cutscene or choosing, not
  dancing): starts their dance on their beat if you own it, else a toast says where to get it (never a purchase).
  Spec `tests/GirlPickup.spec.luau` (timeAt / offBy); film `docs/previews/dance-sync.mp4`
  (`motion3d/dance_sync_scene.luau`: three players start Floss at different times, not synced vs synced).
- **Dance pictures** (`UI/DancePose`): your avatar posed by hand from the KeyframeSequence at the dance's best second,
  walking every joint (Motor6D, Weld, WeldConstraint, AnimationConstraint) and anchoring it. **No Animator, so no
  lag** (25 live animated viewports lagged). Used by the Dances cards and the wheel; note icon as fallback on the wheel.
- The **Dances window** follows the Oct 17 mockup (`docs/previews/dances-vs-mockup.jpg`): 3 column cards glowing in
  each dance's `Config/Dances` Color (our `dance-fx-*` notes), a `Blurb` line under the big picture, and a white
  blocky stand-in figure in the same pose (`dance-still-*`: `motion3d/dance_stills.luau` +
  `tools/icons/make_dance_stills.py`, re-run when the dances change) until your avatar's picture is ready.
  Favourites: saved `FavDances`, server-capped at `Dances.MaxFavourites` (12).
- **Dance wheel** (`Screens/DanceWheel`, the owner's taunt-wheel reference): 8 see-through dark circles round a big
  centre circle; pictures built ahead while closed; opens with one smooth grow (no CanvasGroup, no stagger).

## Honest gaps
- Not seen in Studio yet: the pack walk for everyone, carried girls, the pickup and its effects, dance pictures on
  real avatars, synced dancing across two clients (the hand-drawn dances for others in Studio, the nudges on
  published tracks, the DANCE TOGETHER prompt; whether a replicated track takes the nudge smoothly is Studio-only).

## Why it is this way / history
- **Walking** (owner Oct 18: "player to player less choppy", "make the walking animations way way better").
- **Planted feet:** `WalkAt` was 8 and `RunAt` 25, and walk handed over to run at 13-21 studs/s, so the walk skated at
  half the ground speed at the 16 you set off at.
- **Huss pose:** an Oct 17 critic called the first one "a stiff tilt"; the first version of all was a cartwheel.
- **Smoothness** (owner Oct 19: "make animations more smooth"): measured first; the pops were the one-frame huss
  blend and the stale writes on release, not the pack.
- **Girls:** Oct 18 "so choppy": the small companion sprinted at 9 steps/s (legs jumping 44° a frame) and the lock
  jolted her body every step; hence `Pack.MaxSteps` and `Pack.Surge`.
- **Carried girls** (Oct 18 "not just be held straight up like that").
- **The pickup** (Oct 19 "add the nice girl animations when they are picked up"): PickupTime was 0 (she appeared
  overhead at once) because the old flight came all the way from the big girl over the map; now a far pickup starts
  on the ground in front of him, so it reads as him lifting her, not her flying across the field.
- **Girls on every screen / synced dancing** (Oct 19): the streaming lesson again (core pitfall: never look a part up
  once); and dances with Studio's stand-in IDs never showed on other screens, so the girls' and dancers' moves are now
  driven from the two attributes every screen has.
