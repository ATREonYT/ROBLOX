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

	-- The huss dash pose (Config/Round.Dash sets its speed and timing).
	Dash = {
		Length = 0.45, In = 0.06, Out = 0.18, -- seconds: total, blend in, blend out
		Crouch = 0.9,
		LungeLean = 38, -- forward dash
		SideRoll = 24, -- sideways dash
		SideSplay = 38,
	},
}
