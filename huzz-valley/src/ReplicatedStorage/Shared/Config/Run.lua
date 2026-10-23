-- The Huss Valley run and huss dash (Shared/RunMotion), matched to the owner's reference video, built in
-- until the owner's own animations are uploaded (Config/Animations.Run). Degrees, studs, seconds.
return {
	-- Walk first, then run (owner, Oct 23 03:37: "add the walking animation first, then after holding w or going
	-- forward, the character starts running, like in huss valley, add the walking from the pack"): you set off at a
	-- walk (StartSpeed, a little under Huss Valley's set-off 9: docs/feel-study.md gap 8), his pack's R6 walk playing, and
	-- keep walking for WalkHold seconds; hold on and you build up into the run (his pack's run) over Ramp. Until Oct 23
	-- you set off at 16, already a run, so his walk never showed.
	StartSpeed = 8, -- you set off at this speed (a walk; Oct 23 13:52 "a bit quicker": was 7)... (Gameplay/Sprint)
	WalkHold = 0.4, -- ...and walk this long while you hold a direction...
	Ramp = 1.0, -- ...then build up to full speed in exactly this many seconds (owner, Oct 20 07:55: "Make
	-- acceleration 1 second long"; was 0.5 s to ~95%). Shared/RunMotion.rampSpeed: eases out with RampEase (2: the
	-- quickest gain at the start, none at the top, so no jolt at either end): 44% of the build at 0.25 s, 75% at 0.5 s.
	RampEase = 2,
	-- The halt (owner, Oct 20 07:55: "after they randomly stop after fully running they move a little forward as a sort
	-- of "hault" like in the game Huss valley"). Let go of every key while running at From of your top speed or more
	-- and you carry on along the ground, slowing from your speed to 0 over Time seconds (Ease 2: quickest at first,
	-- RunMotion.pushSpeed): ~2.3 studs at a runner's 28 (speed x Time / (Ease + 1)). Huss Valley's one full-speed stop
	-- (f1c7bb86, 41.19 to 41.47 s, docs/notes/movement-and-camera.md): ~2.5 studs over its last ~0.28 s (Ease 3 put
	-- 65% of it in the first 30 fps frame: a jolt, not a slide). Pressing any
	-- direction, a huss, a dive, being downed or frozen, or leaving the floor ends it. Shared/Halt (the push),
	-- Gameplay/Sprint (you; never the Practice Bot); the legs brace at once (LocomotionMix input.halt).
	Halt = { From = 0.9, Time = 0.25, Ease = 2 },
	From = 14, -- below this speed: Roblox's own walk
	Full = 20, -- from this speed on: the full run (runners go 24)
	Stride = 12, -- studs per full stride (two steps): 28 studs/s / 12 = 4.7 steps a second, Huss Valley's ~4.6 (feel
	-- study); the footsteps (Gameplay/Feel) use it too, so they land with the pack Sprint (0.483 s a stride at 25 studs/s)
	Lean = 30, -- hunched forward into the run
	WaistLean = 8,
	Crouch = 0.45, -- how much lower the body runs
	Bounce = 0.3, -- up and down each step
	Roll = 7, -- body rolling side to side
	HipTwist = 14, -- hips turn with the legs...
	Twist = 16, -- ...and the shoulders turn the other way
	KneeUp = 72, -- high knees: how far the thigh comes up in front
	KickBack = 32, -- and how far it goes behind
	KneeFold = 105, -- the heel folding up behind
	Splay = 5, -- legs a little apart
	ArmSwing = 70, -- arms swinging forward and back...
	ArmLift = 45, -- ...the forward fist coming up to the head
	ArmOut = 10, -- arms a little out: Huss Valley's swing front to back, not out to the sides (was 22)
	Elbow = 95,

	-- The owner's walk and run on every R15 character (Shared/LocomotionMix): your own through Gameplay/Locomotion
	-- when the Animator can play the pack, everyone else (and you, in the live game) through Gameplay/PlayerMoves.
	-- Idle, Walk and Run play together and cross-fade by the (smoothed) speed, their feet kept in step.
	-- Owner, Oct 18: "make the walking animations way way better". Measured on the pack
	-- (tools/preview/motion3d/pack_measure.luau, standard R15): the Walk's planted foot keeps still at 4.35 studs/s
	-- (1 s loop, 2 steps a second), the Run's at 14 studs/s (0.483 s loop, 4.1 steps a second). The old numbers
	-- played the walk at 1x at 8 studs/s and asked it to cover the 16 studs/s you set off at (the planted foot slid
	-- along at half the ground speed: the "skating" walk), and blended walk into run between 13 and 21, so the slow walk
	-- still showed while you ran.
	-- R6 bodies (owner, Oct 22 13:24: "make the game r6, and use these animations that i sent from the movement"): his
	-- BZ1 pack's loops over Loco below (Gameplay/Locomotion). Measured by tools/preview/motion3d/r6_stride.luau: his
	-- Stylized Walk keeps its feet planted at ~3.3 studs/s, his Stylized Run 2 at ~5; R6 legs are short, so at a
	-- runner's 16-28 the run is capped at 1.5x = 4.5 steps a second (Huss Valley's ~4.6) and the feet slide, as in
	-- Huss Valley's R6 recording. Right leg forward at 0.0 (walk) and 0.95 (run) of each loop. His loops already
	-- swing far: no extra Swing.
	LocoR6 = {
		-- the walk hands over to the run between RunFrom and RunFull studs/s: above the set-off's 8, so setting off is
		-- all walk (Oct 23)
		RunFrom = 9, RunFull = 15,
		-- Oct 23 13:52 (owner: "a bit quicker and look more natural, with every step is a walk, not many steps per one
		-- step"): his pack's walk is a short shuffle (feet planted at only 3.3 studs/s, so it played at 2.1x: ~4.9
		-- steps a second). Its legs now swing 1.8x as far and its arms 1.4x (LocomotionMix.pose, the hips dropping to
		-- keep the lower foot down), so its feet stay planted at 6 studs/s at 1x: at the set-off's 8, 1.35x (~3.1
		-- calm steps a second, each one covering the ground)
		WalkStride = { Legs = 1.8, Arms = 1.4, LegLength = 2 },
		WalkAt = 5.95, WalkRate = { 0.5, 1.6 },
		RunAt = 10, RunRate = { 0.6, 1.5 },
		RootHeight = 3,
		WalkPhase = 0, RunPhase = 0.95,
		Swing = { Arms = 1, Legs = 1 },
	},
	Loco = {
		SpeedResponse = 13, -- how fast the blend follows the speed (higher = snappier; 13 settles in ~0.35 s)
		MoveFrom = 0.4, MoveFull = 3, -- studs/s: idle fades into the walk between these
		RunFrom = 6, RunFull = 11, -- studs/s: the walk hands over to the run between these (was 13 to 21), where both
		-- loops step at nearly the same rate (2.3 to 3.3 steps/s), so the swap never pops (R15 bodies; the game's R6
		-- bodies hand over above their walk: LocoR6)
		WalkAt = 4.3, WalkRate = { 0.5, 1.7 }, -- the walk plays at 1x at 4.3 studs/s (the pack's own: was 8), within
		-- these rates: its feet stay planted from 2.2 to 7.3 studs/s (a slow thumbstick, slowing down)
		RunAt = 14, RunRate = { 0.55, 1.12 }, -- the run too (was 25): planted feet up to ~16 studs/s, then held at
		-- 1.12x = 4.6 steps a second (HV's ~4.6, never frantic), so at a runner's 28 the feet slide (~44%), like HV's quick steps
		RootHeight = 3, -- studs from the ground to the root's middle on a standard R15 avatar (HipHeight 2 + half the
		-- root): a taller avatar's speeds above scale up with it (longer legs, longer steps), a small one's down
		WalkPhase = 0.8, RunPhase = 0.245, -- where each loop has the right leg forward (keeps the feet in step)
		AirIn = 0.08, AirOut = 0.18, -- seconds: jump/fall/climb fade in and out
		JumpHold = 0.32, -- seconds the jump pose plays before the fall takes over
		ClimbAt = 5, -- climbing speed (studs/s) the climb plays at 1x
		-- The procedural touch on top (critically damped): leaning into turns and into speeding up.
		-- Owner, Oct 21 (his Huss Valley recording 1200-huss-valley.mov: "make the body move when you go right or left
		-- and keep the head in the middle"): HV's runner banks hard into a turn, about 15 degrees, so 7 per radian a
		-- second up to 16 (was 3.2 up to 7); the neck takes most of it back (HeadLevel), so the head stays level.
		TurnLean = 7, -- degrees of roll per radian a second of turning (at a run)...
		MaxRoll = 16, -- ...up to this
		-- The owner's run and walk swing their arms and legs further (his HV recording, Oct 21: the R6 runner's arms
		-- reach far out front and back): each shoulder's turn x Arms, each hip's x Legs at a run (half at a walk).
		Swing = { Arms = 1.35, Legs = 1.15 },
		HeadLevel = 0.8, -- of that roll the neck undoes (1 = the head stays perfectly level)
		AccelLean = 0.2, -- degrees of forward pitch per stud/s² of speeding up (0.12 before the 1 s build: its gentler
		-- push, 24 studs/s² at the start, would only lean ~3 degrees; now ~5 at the start, upright as the build tops out)...
		MaxPitch = 5, MaxPitchBack = 3, -- ...up to these (leaning back a little when you stop)
		LeanResponse = 9,
		-- Setting off and stopping, measured on Huss Valley's recording (Oct 19, owner: "add animations for when you
		-- stop running, its a quick but nice looking stopping animation ... and then the slow walking into the running
		-- animation"; tools/preview/motion3d/ground_flow.py and the 30 fps sheets in docs/previews/stop-start-vs-hv.jpg):
		--   HV sets off with short quick steps for ~0.15 s and has the full stride by ~0.35 s: the legs walk for
		--   SetOff.Walk seconds after a standstill, then hand over to the run over Blend (whatever the speed);
		--   HV's ground stops within a frame and its legs are at the idle ~0.15 s later, arms swinging out as the feet
		--   plant (40.7 s): slowing follows the speed at StopResponse (30: ~0.12 s to a stand, was the 13 of speeding
		--   up: ~0.3 s of legs running on in place); a stop from a run goes straight from the run to the idle (no walk
		--   in between: Stop.Blend, ~0.15 s like HV) with the plant on top (the body tips back Lean degrees, the arms
		--   swing ArmsOut out and ArmsForward forward, up in In seconds, gone Out later).
		StopResponse = 30,
		WeightTime = 0.035, -- seconds: the idle / walk / run shares ease this much on top (a stop at 30 crosses the walk
		-- in ~2 frames: without it the legs popped to the idle, 0.64 of the blend in one 60 fps frame)
		SetOff = { Walk = 0.12, Blend = 0.2 },
		Stop = { In = 0.05, Out = 0.25, Blend = 0.05, Lean = 4, ArmsOut = 13, ArmsForward = 12, -- (first film: 7 and 22 flapped the arms and tipped the head back)
			-- the halt (Config/Run.Halt, owner Oct 20): the same plant, but the steps slow to a stop over Settle seconds
			-- and the legs come together over Blend while the ground slides (Blend 0.05 with the steps frozen at once
			-- reversed a swinging arm in one 30 fps frame: move_smooth_measure pop 93 degrees)
			-- Brace: the halt's held pose (critic, Oct 20: ours stood up by +0.73 s and read as a plain stop). HV's
			-- f1c7bb86 frame by frame (41.0 to 41.6 s): from ~41.23 s the runner skids in a wide braced stance, one leg
			-- forward, knees bent, the body a little low and leaning back, held to ~41.45 s, upright and feet together
			-- by ~41.5 s. Up over In seconds while the body slides, held, then eased back to the idle over Out once it
			-- stops (half that when you run on). Seen from HV's camera (in front, above) the hips also turn a little
			-- side-on, the leading leg's hip forward, which is what shows the wide stance from the front. Drop in studs;
			-- Lean, Turn (+ to the left), the hips and knees in degrees (+ thigh forward, - knee folding); the left leg leads.
			Halt = { Settle = 0.12, Blend = 0.08,
				Brace = { In = 0.08, Out = 0.16, Drop = 0.45, Lean = 9, Turn = -30, FrontHip = 40, FrontKnee = -45, BackHip = -25, BackKnee = -30 } } },
		-- The head without shift lock (owner, Oct 19: "make the head not move for the user when he runs, for example
		-- when he presses D, the body turns right, but the head and camera stays the same"): Roblox turns the body to
		-- the move; the head turns back toward where the camera looks, up to Max degrees (a neck's reach; HV's runner at
		-- 52.1 s runs side-on with the head still to the front). Past BackFrom degrees (the camera looking at your face)
		-- it comes round to the front over Fade degrees. Response: the spring (10 settles in ~0.35 s).
		-- Oct 19, 19:48 (owner: "make the users head move but make it follow mouse movements so the head doesnt just
		-- stay in one place, make it like the references of huss valley"): the head looks at the point under the mouse
		-- (Gameplay/HeadAim; the camera's middle on touch screens and gamepads), Up / Down degrees at most up and down
		-- (a neck's reach). Everyone sees it: your screen sends your head's turn SendRate times a second when it moved
		-- SendStep degrees or more (HuzzServer/HeadLookService checks and puts it on your character), and other screens
		-- spring to it with RemoteResponse (softer: the values come 5 times a second).
		-- (Max 90, was 70, Oct 21: running side-on, the head can stay on the middle of the screen, as in HV's recording)
		Look = { Max = 90, BackFrom = 110, Fade = 30, Response = 10, Up = 30, Down = 35, SendRate = 5, SendStep = 2,
			RemoteResponse = 8,
			-- Oct 21 (owner: "make it perfect so it doesnt seem weird in little angles"): the head aims no nearer than
			-- Near studs past itself (Gameplay/HeadAim), and holds still in the world while the body turns under it
			-- (a turn of up to HoldMax degrees in one frame; LocomotionMix.look's yaw)
			Near = 40, HoldMax = 60 },
		-- Shift lock (owner, Oct 19: "when you shift lock the only thing that moves when you press w a s d (etc) is
		-- their body not their head"; 18:16 "when he presses D, the body turns right": MaxTurn 90, was 70, so D is a
		-- full side-on run like HV's): the hips and legs turn toward the way you move, up to MaxTurn degrees; the
		-- chest ends Chest of that turn round, the head turns back so it keeps looking where you aim. Moving more than
		-- BackFrom degrees off straight ahead is a back-pedal (hips toward the mirrored side, the loop backwards).
		-- Response: the spring's speed (12 settles in ~0.3 s). Below MinSpeed studs/s the body faces ahead.
		Strafe = { MaxTurn = 90, BackFrom = 110, Response = 12, Chest = 0.4, MinSpeed = 2 },
	},
	-- Other players (owner, Oct 18: "player to player less choppy"): their speed comes from where their body is over
	-- time (Shared/LocomotionMix.track), not from their replicated velocity, which jumps between network updates and
	-- made their legs stutter. Gameplay/PlayerMoves.
	Track = {
		Window = 0.25, -- seconds: speed = distance covered over this long (evens out network bursts)
		MinSpan = 0.05, -- seconds of samples needed before a speed is read
		Hold = 0.15, -- seconds a body that hasn't moved at all keeps its last speed (a network stall, not a stop)
		Teleport = 160, TeleportMin = 6, -- a jump faster than this (studs/s) and longer than this (studs) is a teleport
		-- (over the huss's 120 burst)
		MaxSpeed = 80, -- studs/s: never reads faster (the huss bursts at 120 but averages ~45 over the window)
		Fade = 0.2, -- seconds the pack fades in or out (a dance or an Action animation starting, a downed body)
		Near = 70, Mid = 160, -- studs: sampled every frame this close, 30 times a second to Mid, 15 beyond or off screen
	},

	-- The huss pose (Shared/RunMotion, on every character including your own; Config/Round.Dash sets its push).
	-- Huss Valley frame by frame (docs/previews/feel-huss.jpg): crouched and leaning ~25-30 degrees into the move
	-- from the first frame, held to 0.30 s, upright by ~0.40 s, running again by 0.5 s.
	-- Oct 19 (owner: "make it more smooth"; tools/preview/motion3d/move_smooth_measure.luau): the pose came in over
	-- 0.05 s, so at 30 fps 74% of it landed in one frame (a leg turned 83 degrees in that frame), then froze like a
	-- statue for 0.25 s. Now it comes in over 3 frames (0.09 s, at most ~50% a frame), settles a little deeper
	-- through the push (Settle) and eases out over 0.16 s.
	Dash = {
		Length = 0.40, In = 0.09, Out = 0.16, -- seconds: total, blend in, blend out (full pose 0.09 to 0.24 s)
		Settle = 0.08, -- the pose starts this much shallower and settles to its full depth by the end of the push
		-- (critic, Oct 17: 0.5 / 20 / 6 / 34 read as a stiff tilt; HV's huss is a wide low crouch, torso fairly upright)
		Crouch = 0.75, -- studs lower: a real crouch (was 0.5; 0.85 dropped the head 21%, past HV's measured ~13-20%)
		SideShift = 0.3, -- hips shift this far the way you go
		SideRoll = 12, -- hips tip into the move only a little (was 20)...
		SideWaist = 14, -- ...the chest bends into it more (was 6): ~26 degrees in all, bent at the waist, not a tilt
		SideHead = 20, -- the head stays nearly upright, looking ahead
		SideSplay = 55, -- the outside leg kicks out wide (was 34)
		LeadHip = 45, -- the inside leg's thigh comes up (was 30)...
		LeadSplay = 42, -- ...and out to the side too (was 30), so both legs spread wide like HV's
		LeadKnee = -80, -- ...and its knee folds deep under you (was -52)
		LungeLean = 38, -- (forward dash: unused since the huss went sideways only)
		-- The white speed lines behind anyone who husses (Gameplay/Feel, seen by everyone near): HV shows 5-6 thin
		-- horizontal lines trailing behind along the move, ~20-25% of the screen wide, for ~0.3 s. They ride with
		-- the body (not left on the ground), draw out in 0.06 s and hold their length.
		-- A more premium huss (owner, Oct 22 16:00: "can you please make the huss look better and more premium"):
		-- see-through glowing copies of the body left along the move (Gameplay/Feel, Gameplay/Ghosts), a cool
		-- white-blue, each fading out; and the speed lines brighter, wider, white at the body fading to that blue.
		Ghosts = {
			Count = 4, -- copies, one every Every seconds from the start of the push
			Every = 0.055,
			Life = 0.26, -- seconds each takes to fade out completely
			From = 0.55, -- how see-through each starts (0 solid, 1 gone)
			Color = Color3.fromRGB(150, 215, 255),
		},
		Lines = {
			Time = 0.28, -- seconds they show (fading out over the last 40%): as long as the push (Config/Round.Dash)
			Width = 0.13, -- studs (was 0.09 before the premium pass)
			Glow = 0.65, -- LightEmission (was 0.3)
			Length = 6.5, -- studs (x each line's own scale: 22-28% of the screen at the round camera's 12 studs)
			Gap = 0.7, -- studs from the body's middle to where a line starts
			-- height over the root, how far in front (+) or behind, and each line's length scale
			{ 1.4, 0.15, 0.8 }, { 0.8, -0.25, 1 }, { 0.2, 0.1, 0.7 }, { -0.4, -0.15, 0.95 }, { -1.0, 0.25, 0.75 }, { -1.7, -0.05, 0.6 },
		},
	},
	-- Running at speed (owner, Oct 22 13:24: "add some effects when you are running and make it feel more intense",
	-- with his clip: design/owner-oct22/video-1616). Measured from the clip at full sprint: thin white wind streaks
	-- curling off the arms and legs (they follow the limbs' swing), and a blue glow round the screen's edge, about
	-- (45, 105, 175) at the very edge fading out over ~6% of the screen; none while walking (f7.6). Gameplay/SpeedFX.
	SpeedFX = {
		-- Only while really running (owner, Oct 23 03:37: "make the lines behind the user when running appear only when
		-- he is running"; they came on at 18 studs/s, in the first steps of a lobby walk): 0 at RunFrom studs/s (where
		-- the legs are fully in the run, LocoR6.RunFull), 1 at your top speed; and yours only while you hold a direction
		-- (never on a halt's slide)
		RunFrom = 15,
		From = 0.45, -- how fast (0 = RunFrom, 1 = flat out) before any of it shows; full at 1
		Trails = {
			Near = 110, -- studs: streaks on runners this close to the camera (yours always)
			Life = 0.28, -- seconds a streak lasts: curls about as long as the clip's (0.2 read short next to it)
			Width = 0.13, -- studs at the limb, thinning to nothing
			See = 0.35, -- how see-through at their thickest
		},
		Glow = {
			Color = Color3.fromRGB(45, 110, 190),
			Edge = 0.07, -- of the screen, each side
			-- Off (owner, Oct 23 15:22, his phone picture: "fix the blue thing on my screen popping up when I run"); was 0.55
			Strength = 0, -- at flat out (0 = none, 1 = solid at the very edge)
		},
		Fov = 4, -- extra degrees of view at flat out (on top of Feel's 2): the clip's wide, rushing camera
	},
	-- The cast pose (owner: "make the usage of items smoother"; critic: powers had no body move at all): while a
	-- power winds up (Config/Powers.Fx WindUp, 0.15 to 0.25 s) the body reaches both arms forward and up and leans
	-- into it, then lets go as the effect bursts. Drawn by Shared/RunMotion on everyone (Gameplay/RunAnimator).
	Cast = {
		In = 0.06, Out = 0.14, -- seconds: blend in, blend out after the wind-up
		ArmsUp = 60, -- degrees above straight ahead (forward and up: reads from the camera behind you)
		ArmsOut = 12, -- degrees the arms open into a V
		Lean = 10, -- degrees the body leans forward into the cast
		-- The Bear Trap's throw (owner, Oct 19: "you throw the beartrap infront of you with a small animation"): the
		-- free left arm (the right holds the knife) winds back over the first Back of the wind-up, then throws forward
		-- and up; { wound back, thrown } in degrees: Arm = shoulder (+ forward), Out = arm out to the side, Elbow,
		-- Turn = chest turn (+ left, away from the throw), Lean = body lean forward.
		Throw = { Back = 0.45, Arm = { -55, 115 }, Out = { 18, 6 }, Elbow = { 40, 8 }, Turn = { 24, -18 }, Lean = { -2, 12 } },
	},
}
