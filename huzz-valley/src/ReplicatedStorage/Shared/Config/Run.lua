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

	-- Your own walk and run when the owner's animations can play (Shared/LocomotionMix, Gameplay/Locomotion):
	-- Idle, Walk and Run play together and cross-fade by your (smoothed) speed, their feet kept in step.
	Loco = {
		SpeedResponse = 13, -- how fast the blend follows your speed (higher = snappier; 13 settles in ~0.35 s)
		MoveFrom = 0.4, MoveFull = 3, -- studs/s: idle fades into the walk between these
		RunFrom = 13, RunFull = 21, -- studs/s: the walk fades into the run between these (you set off at 16, so the
		-- walk still shows for the first moment and is a full run by the lobby's 22)
		WalkAt = 8, WalkRate = { 0.75, 1.3 }, -- the walk plays at 1x at WalkAt studs/s, kept within these rates
		RunAt = 25, RunRate = { 0.85, 1.15 }, -- the run too: calm, never frantic (a little foot slide, as HV)
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
	},

	-- The huss pose (Shared/RunMotion, on every character including your own; Config/Round.Dash sets its push).
	-- Huss Valley frame by frame (docs/previews/feel-huss.jpg): crouched and leaning ~25-30 degrees into the move
	-- from the first frame, held to 0.30 s, upright by ~0.40 s, running again by 0.5 s.
	Dash = {
		Length = 0.42, In = 0.05, Out = 0.12, -- seconds: total, blend in, blend out (full pose 0.05 to 0.30 s)
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
			Time = 0.3, -- seconds they show (fading out over the last 40%)
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
	},
}
