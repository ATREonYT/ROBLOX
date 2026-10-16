-- The Huss Valley run and huss dash (Shared/RunMotion), matched to the owner's reference video, built in
-- until the owner's own animations are uploaded (Config/Animations.Run). Degrees, studs, seconds.
return {
	StartSpeed = 9, -- you set off at this speed (a walk) and build up to full speed... (Gameplay/Sprint)
	Ramp = 1.1, -- ...over this many seconds of holding a direction
	From = 14, -- below this speed: Roblox's own walk
	Full = 20, -- from this speed on: the full run (runners go 24)
	Stride = 9.5, -- studs per full stride (two steps): smaller = quicker steps
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
	ArmOut = 22, -- arms wide
	Elbow = 95,

	-- Your own walk and run when the owner's animations can play (Shared/LocomotionMix, Gameplay/Locomotion):
	-- Idle, Walk and Run play together and cross-fade by your (smoothed) speed, their feet kept in step.
	Loco = {
		SpeedResponse = 13, -- how fast the blend follows your speed (higher = snappier; 13 settles in ~0.35 s)
		MoveFrom = 0.4, MoveFull = 3, -- studs/s: idle fades into the walk between these
		RunFrom = 11, RunFull = 18, -- studs/s: the walk fades into the run between these
		WalkAt = 8, WalkRate = { 0.75, 1.3 }, -- the walk plays at 1x at WalkAt studs/s, kept within these rates
		RunAt = 22, RunRate = { 0.85, 1.1 }, -- the run too: calm, never frantic (a little foot slide, as HV)
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

	-- The huss dash pose (Config/Round.Dash sets its speed and timing).
	Dash = {
		Length = 0.45, In = 0.06, Out = 0.18, -- seconds: total, blend in, blend out
		Crouch = 0.9,
		LungeLean = 38, -- (forward dash: unused since the huss went sideways only)
		SideRoll = 24, -- sideways dash
		SideSplay = 38,
	},
}
