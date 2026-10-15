-- How the girls move: while carried, while waiting as the prize, and the
-- carrier's strain. Angles are degrees, times seconds. Works on any R15 or
-- R6 rig; models without Motor6Ds just ride along without limb motion.
return {
	Carried = {
		Gravity = 120, -- how hard limbs fall (studs/s^2); lower = floatier
		Inertia = 1, -- how much the carrier's starts, stops and bounces swing her limbs
		Arms = 0.9, -- 0 = keep the model's pose, 1 = hang straight down
		Legs = 0.3,
		Knees = 0.85,
		Elbows = 0.45,
		LookAhead = 0.6, -- how much she turns her head to look where you're going
		Spring = { Arms = 2.2, Legs = 3, Damping = 0.28 }, -- Hz; lower damping = more swing

		Excited = { Time = 2.4 }, -- after a pickup: kicks and waves both arms
		Cheer = {}, -- she's been won: waves both arms the whole time
		Struggle = { Time = 3, Every = { 4, 7 }, Burst = 1.4 }, -- stolen: kicks and flails, then in bursts
		Calm = {
			Kick = { Every = { 5, 9 }, Time = 1.8 }, -- happy foot kicks
			Wave = { Every = { 8, 13 }, Time = 2.2 }, -- one arm waves at the sky
		},
	},

	Idle = {
		WaveDistance = 35, -- a runner this close gets a wave
		WaveEvery = { 9, 15 }, -- otherwise she waves now and then
		BounceDistance = 14, -- a runner this close makes her bounce
		LookDistance = 80,
		Sway = 3, -- weight shift, degrees
		SwaySeconds = 4.5,
	},

	-- Added on top of the carrier's walk animation (R15 Waist joint).
	Carrier = {
		Lean = 5, -- leaning back under her weight
		StepRoll = 2.5, -- side-to-side with each step
		StepDip = 1.5,
	},
}
