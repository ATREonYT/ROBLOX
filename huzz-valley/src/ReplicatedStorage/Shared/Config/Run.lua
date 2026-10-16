-- The Huss Valley sprint (Shared/RunMotion), built in until the owner's own run animation is uploaded
-- (Config/Animations.Run). Angles in degrees, distances in studs, speeds in studs per second.
return {
	From = 14, -- below this speed: Roblox's own walk
	Full = 20, -- from this speed on: the full sprint (runners go 24)
	Stride = 11, -- studs per full stride (two steps): bigger = slower, longer steps
	Lean = 22, -- leaning into the run
	WaistLean = 6, -- a little more from the chest
	Bounce = 0.25, -- up and down each step
	Roll = 3, -- side to side each step
	HipTwist = 8, -- hips turn with the legs...
	Twist = 10, -- ...and the shoulders turn the other way
	Swing = 48, -- how far the legs swing forward and back
	KneeFold = 95, -- how high the heel comes up as the leg swings through
	ArmSwing = 55, -- arm pump
	Elbow = 85, -- elbow bend
}
