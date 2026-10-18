-- How the girls move: while carried, while waiting as the prize, and the
-- carrier's strain. Angles are degrees, times seconds. Works on any R15 or
-- R6 rig; models without Motor6Ds just ride along without limb motion.
return {
	Carried = {
		-- Owner Oct 18: "make the girls have some motion, not just be held straight up like that, and make it for
		-- all of the girls" (before: "no wiggle", and she lay flat and stiff like a plank). Now she sits up in his
		-- hands with calm life on top (GirlMotion.carried). Calm, not crazy: every move here is small and slow.
		Pose = {
			TorsoUp = 24, -- her upper body raised from lying flat (sitting up in his hands)
			LegsUp = 62, -- legs bent up at the hips (R6 legs can't bend at the knee; R15 knees bend too)
			Knees = 45, -- R15 only: shins hang from bent knees
			LegsApart = 6,
			ArmsOut = 8,
			StepGive = 3, -- her body dips this much at each of his footsteps
			LegSway = 7, -- her legs dangle this much with his steps
			ArmSway = 6,
			HeadNod = 4,
			Swing = 6, -- her feet swing slowly on their own (more while he stands)
		},
		Moods = true, -- excited / struggle / cheer / calm kicks, waves and glances (all small)
		Inertia = 0.25, -- how much the carrier's starts, stops and turns swing her limbs
		Gravity = 120,
		Arms = 0.35, -- 0 = keep the model's pose (along her sides), 1 = hang straight down (more dangled in front of his face)
		Elbows = 0.4,
		LookAhead = 0.5, -- how much she turns her head to look where you're going
		LookAround = true, -- slow glances side to side
		Spring = { Arms = 2.6, Legs = 2.4, Damping = 0.75 }, -- Hz; a little loose, so limbs dangle and settle

		Excited = { Time = 2.4 }, -- after a pickup: happy kicks, arms up a little
		Cheer = {}, -- she's been won: waves both arms the whole time
		Struggle = { Time = 2, Every = { 6, 10 }, Burst = 1 }, -- stolen: a short wriggle, then now and then
		Calm = {
			Kick = { Every = { 5, 9 }, Time = 1.6, Size = 14 }, -- a small happy foot kick (degrees)
			Wave = { Every = { 9, 14 }, Time = 2.2 }, -- one arm waves at the sky
			Glance = { Every = { 4, 8 }, Time = 2.2, Angle = 35 }, -- she looks round to one side
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

	-- The girls' walk, run and idle from the owner's movement pack (Shared/GirlMoves; owner: "get all the
	-- animations right in the game"). Speeds are for a standard-size girl (5.25 studs tall) and scale with her size.
	-- The speed each loop plays at 1x (feet planted) is measured from the animation itself (GirlMoves prints nothing;
	-- tests/GirlMoves.spec shows it: about 3.6 studs/s for the Walk, 9 for the Run). The rate limits keep the legs
	-- from blurring when she has to keep up with a fast catcher (30 studs/s): past them her feet slide a little.
	Pack = {
		SpeedResponse = 10, -- how fast the blend follows her speed (10 settles in ~0.45 s)
		MoveFrom = 0.4, MoveFull = 2.5, -- studs/s: idle fades into the walk between these
		RunFrom = 6, RunFull = 10, -- studs/s: the walk fades into the run between these
		WalkRate = { 0.5, 1.6 }, -- the walk plays between half and 1.6x its own speed...
		RunRate = { 0.6, 1.6 }, -- ...and the run too (a smaller girl may go a little quicker)
		MaxSteps = 4.8, -- steps a second at most, any size (HV's run is ~4.6): past it her feet slide instead
		-- (Oct 18 "so choppy": the small companion ran at 9 steps a second; the pack's Sprint already swings a
		-- leg ~2000°/s at 1x, so faster than this the legs jump between frames)
		WalkPhase = 0.8, RunPhase = 0.245, -- where each loop has the right leg forward (as Config/Run.Loco)
		Surge = { Walk = 1, Run = 0.7 }, -- how much of the step's forward/back surge she makes (1 = the planted foot
		-- never slides, but the Run's surge lurches the body; faded out further as her feet slide: GirlMoves.step)
		Clip = 0.12, -- studs (standard size): how far the straight R6 leg swinging through may dip into the ground
	},

	-- Added on top of the carrier's walk animation (R15 Waist joint).
	Carrier = {
		Lean = 5, -- leaning back under her weight
		StepRoll = 1, -- side-to-side with each step
		StepDip = 1,
	},
}
