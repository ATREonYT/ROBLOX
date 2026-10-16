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

	-- Your equipped girl as a small companion walking behind you on the ground (owner: "make the anime girls
	-- walk behind you, not fly"). HuzzClient/Gameplay/Auras moves her with Shared/FollowMotion and these.
	Companion = {
		Height = 2.8, -- studs tall, about half your height (owner: "a smaller character")
		Offset = Vector3.new(1.5, 0, 3.5), -- her spot from you (right, up, behind)
		CheerOffset = Vector3.new(2.2, 0, 1), -- once you're safe in a round: beside you
		MatchSpeed = true, -- walks at your speed (then closes the gap), so she never trails far behind
		Catchup = 3, -- how hard she closes the gap to her spot
		MaxSpeed = 36, -- studs per second (players run at 20-26)
		StopDistance = 0.6,
		MaxLag = 10, -- never further than this from her spot
		TeleportDistance = 40, -- further (you teleported or respawned) and she pops to her spot
		StartOnGround = true, -- she appears standing on the ground there (never dropping in)
		Stride = 2.2, -- studs per full walk cycle at her size
		MaxCadence = 2.8, -- walk cycles a second at most: faster than this her stride grows instead
		RunFrom = 9, -- studs/s: from walking...
		RunTo = 17, -- ...to a full run (leaning, knees up, arms pumping)
		HopHeight = 0.55, -- her cheer hops, studs
	},

	-- Added on top of the carrier's walk animation (R15 Waist joint).
	Carrier = {
		Lean = 5, -- leaning back under her weight
		StepRoll = 1, -- side-to-side with each step
		StepDip = 1,
	},
}
