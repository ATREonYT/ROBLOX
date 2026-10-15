-- How the girls move: while carried, while waiting as the prize, and the
-- carrier's strain. Angles are degrees, times seconds. Works on any R15 or
-- R6 rig; models without Motor6Ds just ride along without limb motion.
return {
	Carried = {
		-- The owner asked for no wiggle: she lies still, limbs relaxed. Turn these up for a
		-- livelier carry (Inertia 1 + Damping 0.3 swings her limbs; Moods adds kicks and waves).
		Moods = false, -- excited / struggle / cheer / calm kicks and waves
		Inertia = 0, -- how much the carrier's starts, stops and bounces swing her limbs
		Gravity = 120,
		Arms = 0.75, -- 0 = keep the model's pose, 1 = hang straight down
		Legs = 0.2,
		Knees = 0.7,
		Elbows = 0.4,
		LookAhead = 0.5, -- how much she turns her head to look where you're going
		LookAround = false, -- slow glances side to side
		Spring = { Arms = 3, Legs = 3, Damping = 1 }, -- Hz; damping 1 = settles without bouncing

		Excited = { Time = 2.4 }, -- after a pickup: kicks and waves both arms
		Cheer = {}, -- she's been won: waves both arms the whole time
		Struggle = { Time = 3, Every = { 4, 7 }, Burst = 1.4 }, -- stolen: kicks and flails, then in bursts
		Calm = {
			Kick = { Every = { 5, 9 }, Time = 1.8 }, -- happy foot kicks
			Wave = { Every = { 8, 13 }, Time = 2.2 }, -- one arm waves at the sky
		},
	},

	Idle = {
		-- The owner asked for her to just stand normally: breathing, a slight weight shift,
		-- and turning her head toward whoever comes near. Wave/Bounce add a livelier idle.
		Wave = false,
		Bounce = false,
		WaveDistance = 35, -- a runner this close gets a wave
		WaveEvery = { 9, 15 }, -- otherwise she waves now and then
		BounceDistance = 14, -- a runner this close makes her bounce
		LookDistance = 80,
		Sway = 1.5, -- weight shift, degrees
		SwaySeconds = 4.5,
	},

	-- Added on top of the carrier's walk animation (R15 Waist joint).
	Carrier = {
		Lean = 5, -- leaning back under her weight
		StepRoll = 1, -- side-to-side with each step
		StepDip = 1,
	},
}
