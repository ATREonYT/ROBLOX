-- The Huss Valley run and huss dash (Shared/RunMotion), matched to the owner's reference video, built in
-- until the owner's own animations are uploaded (Config/Animations.Run). Degrees, studs, seconds.
return {
	-- Owner: "walk builds into a run"; Huss Valley's run looks instant (docs/feel-study.md gap 8: 9 -> 16, 1.2 -> 0.5 s),
	-- so the walk is a short quick build now, not a slow one.
	StartSpeed = 16, -- you set off at this speed (a fast walk) and build up to full speed... (Gameplay/Sprint)
	Ramp = 0.5, -- ...reaching ~95% of it after this many seconds of holding a direction (eases out: quick at first,
	-- then settling gently into the top speed, so there is no jolt at either end)
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
	Loco = {
		SpeedResponse = 13, -- how fast the blend follows the speed (higher = snappier; 13 settles in ~0.35 s)
		MoveFrom = 0.4, MoveFull = 3, -- studs/s: idle fades into the walk between these
		RunFrom = 6, RunFull = 11, -- studs/s: the walk hands over to the run between these (was 13 to 21), where both
		-- loops step at nearly the same rate (2.3 to 3.3 steps/s), so the swap never pops. You set off at 16:
		-- a run at once, like HV
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
		TurnLean = 3.2, -- degrees of roll per radian a second of turning (at a run)...
		MaxRoll = 7, -- ...up to this
		AccelLean = 0.12, -- degrees of forward pitch per stud/s² of speeding up...
		MaxPitch = 5, MaxPitchBack = 3, -- ...up to these (leaning back a little when you stop)
		LeanResponse = 9,
		-- Shift lock (owner, Oct 19: "when you shift lock the only thing that moves when you press w a s d (etc) is
		-- their body not their head"): the hips and legs turn toward the way you move, up to MaxTurn degrees; the
		-- chest ends Chest of that turn round, the head turns back so it keeps looking where you aim. Moving more than
		-- BackFrom degrees off straight ahead is a back-pedal (hips toward the mirrored side, the loop backwards).
		-- Response: the spring's speed (12 settles in ~0.3 s). Below MinSpeed studs/s the body faces ahead.
		Strafe = { MaxTurn = 70, BackFrom = 110, Response = 12, Chest = 0.4, MinSpeed = 2 },
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
		Lines = {
			Time = 0.28, -- seconds they show (fading out over the last 40%): as long as the push (Config/Round.Dash)
			Width = 0.09, -- studs
			Length = 6.5, -- studs (x each line's own scale: 22-28% of the screen at the round camera's 12 studs)
			Gap = 0.7, -- studs from the body's middle to where a line starts
			-- height over the root, how far in front (+) or behind, and each line's length scale
			{ 1.4, 0.15, 0.8 }, { 0.8, -0.25, 1 }, { 0.2, 0.1, 0.7 }, { -0.4, -0.15, 0.95 }, { -1.0, 0.25, 0.75 }, { -1.7, -0.05, 0.6 },
		},
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
