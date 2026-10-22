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
- `Shared/AnimationLibrary.id`: published ID (`Config/AnimationIds`, written by the owner's helper, else
  `Config/Animations` / `Config/Dances`), else in Studio a temporary ID (KeyframeSequenceProvider), else "".
  Temporary IDs play only on the client that made them. `AnimationLibrary.published` = the published one only.
- **Publishing** (optional since Oct 20 15:13, the live game works without it): the owner runs
  `require(game.ServerStorage.HuzzStudioTools.PublishAnimations)()` once (`docs/STUDIO-STEPS.md` Part 5;
  `tools/studio/publish-animations.lua` is that line). It tries `AssetService:CreateAssetAsync` on each
  KeyframeSequence in `ServerStorage > HuzzAnimations` (untested: Roblox may refuse animations from a script), takes
  any ID he set himself as an `AnimationId` attribute (Save to Roblox by hand), writes them all into
  `Config/AnimationIds` and reports on `[HuzzAnim]` lines. No ID is ever typed in by us.

## Everyone walks with the pack, Studio and live, nothing uploaded
- `Gameplay/Locomotion` plays Idle/Walk/Run on your own Animator when it can (Studio); `Gameplay/PlayerMoves` (Frame
  order 8) samples the same three from `HuzzGirlMoves` by hand onto every other R15 body's Motor6D.Transform (and
  yours in live), blended by `LocomotionMix`.
- Others' speed comes from their body's position over a 0.25 s window (`LocomotionMix.track`, `Run.Track`: holds
  through 0.15 s network stalls, ignores teleports), never their replicated velocity (that jumpy number made the old
  scripted legs stutter). The velocity is only a yes/no hint (Oct 19): when it says stopped and the body hasn't
  moved, the legs stop at once (their stop shows 0.17-0.30 s after it happens, was ~0.4 s), and a stall while it
  still says running keeps the run. Their halt (Oct 20): their `MoveDirection` at zero while the body still slides at
  a run plants, skids and braces their legs (`input.halt`, `Mix.braceJoint`; never mid huss or dive or in the air,
  [movement-and-camera.md](movement-and-camera.md)). Fades out for a dance/Action track; downed = speed 0 under the knockdown; carriers' arms go
  to CarryAnimator. LOD: re-sampled every frame within 70 studs, 30/s to 160, 15/s beyond or behind the camera.
  `RunAnimator` now draws only the huss and cast on top (`dashOnly`); its scripted run shows only before the pack's
  folder arrives.
- **Planted feet** (`Config/Run.Loco`, measured by `motion3d/pack_measure.luau`): the pack Walk keeps its foot still at
  4.35 studs/s (`WalkAt` 4.3), the Run at 14 (`RunAt` 14); walk hands over to run at 6-11 studs/s. Foot slide is under
  5% up to 16 studs/s; the run is capped at 1.12x = 4.6 steps/s (HV's), so at 28 the feet slide ~44% like HV's quick
  steps. Speeds scale with avatar size (`RootHeight` 3).
- Specs `tests/Locomotion.spec` (pure maths) and `tests/PlayerMoves.spec` (the real Gameplay files on fake bodies).
  Film `docs/previews/remote-walk.mp4` (`motion3d/remote_walk_scene.luau`: before/after over a jumpy network, then the
  set-off from behind); sheet `docs/previews/walk-vs-hv.jpg` (`motion3d/walk_sheet.py`). Setting off and stopping (a short walk
  into the run, the stop plant) and the head look: [movement-and-camera.md](movement-and-camera.md). Footstep sounds: [movement-and-camera.md](movement-and-camera.md). Not seen in Studio yet.
- **Shift lock strafe** (`LocomotionMix.strafe` + `strafePose`): hips and legs turn to the move, the head stays on the
  aim, S back-pedals; `LocomotionMix.look` turns and tilts the head toward the mouse (`Gameplay/HeadAim`; the body
  turned, the head stays on the mouse), on everyone's screen through `HuzzLook`; [movement-and-camera.md](movement-and-camera.md). `strafePose` solves the neck exactly (the
  head's turn is undone through the hunched run pose); a plain counter-turn on the neck tipped the head sideways.

## The owner's Oct 20 14:07 check ("it doesnt seem fixed")
- His recording (`design/owner-oct20/1407-animations.mov`): standing facing the camera, a dark shape across his
  chest looks like arms carrying something. It is his avatar's own item: Huss Valley's f1c7bb86 shows the same
  shape on the same avatar ("alex", 41.5 s) with his arms hanging at his sides. Not a stuck pose: no carry, brace,
  huss or dance layer holds the arms (our idle is the pack's, arms at the sides, slightly out).
- What was really wrong: the head didn't follow the mouse while he faced the camera (the cursor points past him, and
  a point behind faded the look to straight). Fixed with `LocomotionMix.aimFrom` ([movement-and-camera.md](movement-and-camera.md)).
- Film: `docs/previews/moves-check-oct20.mp4` / `.jpg` (`motion3d/moves_check_scene.luau`, the real layers: standing
  with the cursor swept past him, A and D with the head on the far field, W's 1 s build-up and the halt; next to his
  recording and HV's stop). It prints the head's turn and the speed every 0.2 s.

## R6 and his BZ1 movement pack (Oct 22)
- The game is R6 (owner, Oct 22 13:24): `StarterPlayer.GameSettingsAvatar = R6` in `tools/place/world.luau`,
  `build_yours.luau` and `default.project.json`. He must also set Game Settings > Avatar > R6 in Studio before
  publishing.
- An R6 body plays his BZ1 "Movement Animation Pack V1.2" through `Gameplay/Locomotion` (R6Idle / R6Walk / R6Run,
  tuned by `Config/Run.LocoR6`), and `AvatarAnimations` fills Roblox's Animate slots from R6<slot>. Mapping in
  `tools/anim/extract_anims.luau` (R6_MOVES). On R6 only the lean goes on top (RootJoint); no waist, head look,
  brace or arm plant (shaped for R15 joints).
- **Licence:** BZ1 forbids sharing the raw files or place files with them in. The repo is public, so the pack lives
  only in `design/owner-oct22/anims/` (gitignored) and `/mnt/project-files/huzz-valley/owner-anims-oct22/`. The git
  HuzzAnimations.rbxm and place files are built WITHOUT it (R6 bodies then use Roblox's own R6 walk); the place with
  it goes to him through the project files only. If the repo goes private, extract and commit normally.
- Everyone's walk and run on R6 (yours too in the live game, where nothing is published): `Gameplay/PlayerMoves`
  draws R6Idle / R6Walk / R6Run by hand from `ReplicatedStorage.HuzzR6Moves` (Bootstrap fills it, Studio and live),
  tuned by `Config/Run.LocoR6`; only the lean on top. The huss on R6: `Gameplay/R6Huss` (Frame 13) draws the
  game's own huss pose rebuilt for six blocks (`Shared/R6HussPose`; owner Oct 22 17:21: "make the huss animation not
  like that, but actually like the huss movement, just adjusted to the new animations"; his Dash Left / Right from
  14:37 is no longer used): RunMotion's timing (In, Settle, Out), leaning forward 12 and tipped 18 into the move,
  the outside leg planted 48 out (that sets the crouch: R6 legs can't bend), the inside leg lifted forward and out
  with its foot just off the floor, fists in front, the head nearly upright. Works without his pack.
  Specs: tests/R6Huss.spec (feet, crouch, lean, mirror), tests/PlayerMoves.spec (R6 case). Film:
  `motion3d/huss_fx_scene.luau` (PACK=1 his dash, as before).
- Dances (Oct 22, "input these dances i found and remove the old ones"): his 33 R6 dances (extract_anims R6_DANCES,
  our own names in `Config/Dances`), 21 for everyone, 4 Dance Pack, 8 coins; Untouchable is the Level 3 reward
  (was Robot). Old dances in saves: `DataService.migrateDances` gives their coins back (Robot from the reward becomes
  Untouchable). DanceSync and DancePlayer draw R6 joints; cards: `dance_poses.luau` (R6) + `dance_stills.luau` (R6).
  Song picks: docs/dance-music.md (by feel; tempos not measured).
- Still R15-shaped (step 2 of `docs/plan-oct22-r6.md`): the stab, carry, down, crown, stands, knife hand, auras.
- **Local file:** `src/ServerStorage/HuzzAnimations.rbxm` on disk holds his packs (git is told to ignore changes:
  `git update-index --assume-unchanged`); the committed copy has none. Checks run against the disk copy.

## Your own moves: never a stiff body (Oct 20)
- `Gameplay/Locomotion` checks itself: within 3 s (`LOAD_WAIT`) Idle, Walk and Run must have a length and a knee,
  hip or elbow must really move (joints only the Animator writes, looked up again on every check: Roblox swaps the
  avatar's own limbs in, with new Motor6Ds, after the body appears, and the old joints never move; critic Oct 20,
  the "limbs swapped" case in `tests/AvatarAnims.spec`). If not, if attaching throws, or if the frame step
  fails 30 times in a row, it lets go (`ctl.fail`): our tracks stop, Roblox's `Animate` comes back on, and
  `Gameplay/PlayerMoves` draws the pack by hand over it (`Locomotion.drives` turns false). If AvatarAnimations can't
  load Locomotion at all, Roblox's own walk stays.
- One `[HuzzAnim]` line in Output says which way it went (a print when fine, a warning when not):
  - fine: `your moves: the pack's Idle, Walk and Run on your Animator, blended by your speed`
  - `the pack's moves didn't play on your avatar in 3 s (Idle, Walk or Run never loaded)` or `(loaded, but the body
    never moved)`, then `: Roblox's own walk is back on, the pack drawn on top by hand`
  - `the pack's Studio copies didn't become animations (...)` / `the pack isn't published yet (Config/Animations)`
  - `the pack's Idle, Walk or Run didn't load on your Animator`, `the walk controller failed (...)`,
    `the walk blend failed 30 frames in a row (...)`, `... no Animate script to fall back on, the pack drawn by hand`
  - `R6 avatar: Roblox's own walk (the pack is made for R15 bodies)`; `no Humanoid ...`; `no Animator or root part ...`
- Spec `tests/AvatarAnims.spec` runs the real AvatarAnimations, Locomotion, PlayerMoves and Frame on a fake Studio
  for 9 cases (works, never loads, never moves, no register, load throws, step fails, attach throws, no Animate, R6)
  and checks the body moves in each and says one line (two for "step fails"). The old code ended stiff in "never
  loads", "never moves" and "no Animate".

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

## The girls' rigs (`Shared/GirlRig`: every copy that moves)
- Every girl copy that moves (carried, follower, prize, big showcase: `GirlService.makeCopy`; your companion:
  `Gameplay/Auras`) goes through `GirlRig.toMotors` (AnimationConstraints to one Motor6D per joint) and
  `GirlRig.joinAccessories` (each hat, hair and face piece welded to the body part it sits on). His models are never
  changed. Spec `tests/GirlRig.spec.luau` (all 35 of his girls: every accessory on a body part where it sat, a head
  Motor6D, C.C.'s hair on her Head); film `docs/previews/cc-head-turn.mp4` (`motion3d/girl_rig_scene.luau`).
- Lesson: **join accessories by what holds them, not by Welds alone.** C.C. (his only R15, the Secret) holds her hair,
  face and hat with AccessoryRigidConstraints; the copies only followed Welds and Motor6Ds, saw her hair as loose and
  welded it to her ROOT, so her head turned under hair that stayed still ("cc's head doesnt move"). The 34 R6 girls
  use Welds to the Head; one loose piece on Rize (no attachment) now goes on the body part nearest to it.
- **Everyone's girl on your screen** (`Gameplay/Auras`): each player is updated on their own (pcall); one player's girl
  failing used to end the frame's loop, so every player after them had no girl on your screen. A girl that can't be
  built is tried again every 5 s (not every frame) and the first error per player goes to Output tagged `[Huzz]`.
  On the server each step after a save change (looks, title, companion) runs on its own too. Check
  `tools/preview/check_companions.luau` (three players with his real girls; one broken girl doesn't hide the others).

## Carried girls (`GirlMotion.carried`, `Config/GirlMotion.Carried.Pose`)
- She sits up in his raised hands (upper body up 24°, legs bent up 62° at the hips, R15 knees bent, arms half hanging),
  dips and dangles on his real footfalls (`CarryMotion` reads his right hip), swings her feet, a small kick, wave or
  look round every few seconds (owner Oct 20 "Please do so": every girl livelier, a kick and a glance every
  2.5-4.5 s, a wave every 5-8 s, 3.5 s of happy kicks after a pickup); calm (under 6° a frame). Spec `tests/GirlMotion.spec`. Before/after film
  `docs/previews/girls-walk-carry.mp4` (`motion3d/girls_walk_carry_scene.luau`). Not seen in Studio yet.
- **Every girl, checked (Oct 20 recheck, owner: "check the animations for the girls ... it doesnt seem fixed"):** his
  35 girls (`tools/girl_survey.luau`: 34 R6 with 6 Motor6Ds each, C.C. R15 with 30 AnimationConstraints; each a
  Humanoid + Animator; no scripts, Animation objects or AnimationControllers of their own) all get every joint the
  motion needs after `GirlRig`, and all move held (quietest 2 s: 22°), as the big girl (24°+) and with the scripted
  idle (21°): spec `tests/GirlsAlive.spec.luau` runs the game's motion on each one's real joints. Nobody stays stiff
  for a rig reason. Film `docs/previews/girls-alive.mp4` (`motion3d/girls_alive_scene.luau`: all 35 held in a grid,
  then the round 1 prize Yui before/now from the field). Numbers: `motion3d/girl_alive_measure.luau`.

## The big girl over the map (`CarryAnimator`, tag HuzzShowcase; `GirlMotion.showcase`, `Config/GirlMotion.Showcase`)
- Floating over the field is our design (owner: "higher", `Config/Round.Showcase` Height 34, 3x, slow turn and bob).
  Huss Valley has no girl prize, so nothing to match there.
- His Oct 20 clip (round 1, Yui): she turned and bobbed as designed, her arm held in the Idle's pose (not a bind
  pose), but read as a statue: the pack's Idle plus a slow 12° head drift moved her at most 15° in any 2 s, mostly her
  head, small from the field; and if the pack hadn't reached the screen she had no fallback at all (a true statue).
- Now: she watches the nearest player below her (any distance), her feet swing slowly the whole time (12°, 0.45 Hz),
  she waves at the field every 3.5-6 s and gives a happy kick every 2.5-4.5 s (eased, under 5° a frame); without
  the pack she plays the scripted idle under the same overlay. Each screen prints one Output line, `[Huzz] girls:
  movement pack found` or `... not here yet, scripted idle`, so his Output shows which one ran. Not seen in Studio yet.
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
- **In the live game with nothing published** (owner, Oct 20 15:13: "inside the actual roblox game, not studio,
  make it so that dances are available, right now they arent"). Cause: all 32 `Config/Dances` AnimationIds are "",
  Studio's temporary IDs don't exist live and `HuzzAnimations` reaches clients only in Studio, so
  `DancePlayer.ready` said "isn't published yet" and the wheel said "Coming soon" for every dance. Now an
  unpublished dance live is drawn by hand: `DancePlayer` starts it with no track (`handBeat`), the `Dance` remote's
  handler (`ActionService.shareDance`) copies that one dance's KeyframeSequence (~70 KB) from
  `ServerStorage > HuzzAnimations` into `ReplicatedStorage > HuzzDanceMoves` the first time anyone starts it (never all
  32 at join), and `Gameplay/DanceSync` poses your own R15 joints from it on its beat, as it already did for other
  players; their screens draw you the same way, your girl follows (`CompanionDance`, `DancePose` read
  `HuzzDanceMoves` too). R6 avatars get "Dances need an R15 avatar". Oct 21 15:24 (owner: "make the dances work on the actual user, not only on the girl"): his avatar is on Roblox's newer joints (AnimationConstraints, no Motor6D), which DanceSync skipped, so only the girl danced; now it poses every joint that holds each part (Motor6D or AnimationConstraint, doubled ones too) and finds them again when Roblox swaps the limbs in. Studio still plays the raw ones as tracks;
  published ones play as tracks everywhere. Test: `tools/preview/smoke_live_dance.luau` (the harness as the live
  game: ready, starts, moves shared, joints posed, let go on stop, a locked dance refused).
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

- **Dances made by us (Oct 22), `tools/anim/fit/`** (numpy only; the results are our own data, so they ship in the
  public build too; `extract_anims.luau` VIDEO_DANCES turns each `fit/dances/<name>.json` into a looping
  `Dance_<Id>` at 30 keyframes a second):
  - **From his videos** (Balenci, Sweet Dancin; owner 15:30: "make it one to one, use the references"): `fit_video.py`
    fits an R6 body to every frame of a clip (analysis by synthesis: `r6fit.py` draws the six blocks plus what tells
    front from back, a shirt, backpack, shoes, hat, from a fitted camera into a label picture; `seg.py` labels the
    clip's colours; each frame's 21 numbers searched from the frame before, with stock limb poses offered, forwards
    and backwards, the better kept). `make_dance.py` folds every repeat of the loop onto one (Balenci 3.2 s with a
    full turn; Sweet Dancin 0.73 s), unwraps the turn, smooths over a frame. `overlay.py` draws a fit over its clip.
    Clips: his uploads (not in the repo); crops in the project files. Measured fit, not motion capture: limbs
    turning about their own length don't show on square blocks.
  - **Hardtekk three** (TekkPump 150 BPM, HakkenStomp 200, JumpstyleRave 180; owner 16:00: "dances that fit the
    beats, more hardtekk dances"): `author_dances.py`, 16 beats each at the tempo measured off his songs, so every
    punch, stomp and jump lands on a kick; a limb is set by where it points (forward, out), turned into its joint's
    Transform. Their songs are `Config/Dances.Tracks` Hardtekk1-3 (Id "" until he uploads; `Start` = first kick).
    Film with the songs: `docs/previews/oct22-hardtekk-dances.mp4` (project files).
  - **Fixes after the first look (16:17-16:40):** `make_dance.py front` turns round the frames the fit stood back to
    front (a dark body's outline is the same both ways; 154 of Sweet Dancin's 204 were), averages joint angles round
    the circle (a raised arm sits near +-180 degrees: a plain average dropped it), and keeps the cube head facing the
    body's way. `[seconds]` stretches a loop to whole beats of its song (Balenci 6 beats at 119 = 3.025 s; Sweet
    Dancin 2 at 159.9 = 0.750 s; the hardtekk three at their re-measured 150.9 / 199.75 / 179.75).
    Side-by-side with his clips, filmed by each fit's own camera (`anim_scene ANIM_VIEW=front ANIM_FOV ANIM_DOWN`):
    project files `previews/oct22-video-dances-side.mp4`. Sweet Dancin is close; Balenci has the hops and the full turn
    but its legs kick higher and it leans more than his clip (the fit's cost stayed high on that clip).
  - **Balenci by hand (17:19, "make it be exactly replicated so it looks one to one"):** the fit kept sinking into
    crouches the clip never makes, so Balenci is now set by hand in `author_dances.py balenci` from numbers measured
    off his clip (the head's top and the shoes, frame by frame): a bow every 12 frames, 8 bows to one whole turn to
    his own left; each bow folds about 55 degrees forward with the right leg kicking forward and out, then a hop of
    about 0.3 studs with that leg swung back; right fist up at the chin, left arm hanging out. `planted()` keeps the
    standing foot on its spot and the lowest foot on the floor. Looped over 6 beats of his song (3.03 s, the clip's
    3.2 s within 6%). Still short of his clip: R6 has no knees or elbows, so his bent-leg crunch and the fist tucked
    under the chin are straight blocks here. Side-by-side: project files `previews/oct22-balenci-by-hand.mp4`.
- **His songs on the dances (16:17):** each of his dances is paired with the song whose beat fits its loop and
  stretched (at most 4.5%) to whole beats of it: `extract_anims.luau` ON_BEAT, songs measured and cut to clean
  loops by `tools/sfx/song_loops.py`; pairs and reasons in `docs/dance-music.md` "His own songs".
- **Girls dance your R6 dances (16:22: "make the girls dance with you"):** `Shared/DanceRetarget` only read R15 poses,
  so since the dances went R6 the girls stood still. An R6 pose is now read through the R6 joints' own C0 turns into
  each parent's space and put on her joints the same way (R6 girl: exactly the dance; R15 girl: waist, elbows, knees
  straight). `tests/DanceRetarget.spec.luau`; film `tools/preview/motion3d/dance_scene.luau`.

## Honest gaps
- Live dances drawn by hand are checked offline only: whether Roblox's own Animate (or a published walk) fights the
  hand pose on your own body in the real game, and how the first second looks while the moves download, only the
  live game shows. The publish helper is untested (Roblox may refuse animations from a script: then the manual
  Save to Roblox path in STUDIO-STEPS Part 5).
- Which way his Studio goes (the Oct 20 stiff body) only his `[HuzzAnim]` line shows. The likely cause: Studio's
  KeyframeSequenceProvider copies load as tracks but never play, while Animate was off and PlayerMoves skipped your
  own body; now that ends in Roblox's walk with the pack drawn on top within 3 s. Not seen in Studio yet.
- The girls' rigs and everyone's girls (Oct 19 fixes) are checked offline only. Why other players' girls were missing
  on HIS screen is not proven: the loop that one error stopped is a real way for it to happen, but Studio's Output
  (`[Huzz] <name>'s girl on this screen: ...`) will say if a girl actually fails there. The R6 girls' moves are the
  same as before (retargeted from the R15 pack); only the accessories changed. Since Oct 22 the dances are R6 and
  reach the girls joint for joint (offline checked only).
- Not seen in Studio yet: the pack walk for everyone, carried girls, the pickup and its effects, dance pictures on
  real avatars, synced dancing across two clients (the hand-drawn dances for others in Studio, the nudges on
  published tracks, the DANCE TOGETHER prompt; whether a replicated track takes the nudge smoothly is Studio-only).

## Why it is this way / history
- **Never a stiff body** (owner Oct 20: "also the user animations isnt there", screenshot
  `design/owner-oct19/2010-floating-block.png`, his avatar standing in the rest pose in the lobby): Locomotion turned
  Animate off and trusted tracks that loaded without an error; nothing noticed when they never played.
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
- **Girls' rigs and everyone's girls** (owner, Oct 19: "please fix all of the girl characters when you equip them, for
  example cc's head doesnt move, or in general it looks weird even in the animations, so please fix the girls";
  "Also make the girls appear for everyone on everyones screen"): C.C.'s accessories on her root; the one-error loop.
- **Girls on every screen / synced dancing** (Oct 19): the streaming lesson again (core pitfall: never look a part up
  once); and dances with Studio's stand-in IDs never showed on other screens, so the girls' and dancers' moves are now
  driven from the two attributes every screen has.
