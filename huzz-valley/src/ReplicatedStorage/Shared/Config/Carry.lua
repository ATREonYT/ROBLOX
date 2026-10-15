-- How the girl is held overhead. Angles are degrees, distances studs.
-- The pose sits on top of whatever walk/run/huss animation is playing: the
-- girl is attached to the torso, so she follows its bob and sway for free.
return {
	GirlLength = 4.8, -- her height before she's laid down (models are scaled to it)
	HeadToLeft = true, -- which shoulder her head points over
	Rotation = Vector3.new(20, 0, 0), -- extra tilt; +X turns her face toward the camera
	Forward = 0, -- move her forward (-) or back (+)
	Sink = 0.2, -- how far she sinks into the hands
	HairRoom = 0.3, -- she never sits lower than the head top plus this

	PickupTime = 0.55, -- flight from the ground/previous holder up overhead
	ArcHeight = 3.5,

	Arms = {
		Raise = 170, -- 180 = straight up
		Spread = 14, -- elbows out
		ElbowBend = 28, -- forearms in toward her
		AnimBlend = 0.2, -- how much of the playing animation's arm swing shows through
	},

	Bob = {
		StepsPerStud = 0.15, -- footsteps per stud walked (match the walk animation)
		Height = 0.16,
		Roll = 3.5, -- side-to-side rock per step
		ElbowFlex = 7,
	},

	-- Inertia: she lags behind speed changes and turns, then wobbles back.
	Spring = {
		Frequency = 6.5,
		Damping = 0.42,
		Lag = 0.012, -- studs of lag per stud/s^2 of acceleration
		MaxLag = 0.45,
		Tilt = 28, -- degrees of tilt per stud of lag
		TurnLag = 0.06, -- radians of yaw lag per radian/s of turning
		MaxTurnLag = 0.35,
	},

	-- Limbs of rigged girls hang toward the ground and swing a little.
	Dangle = {
		Arms = 0.45, -- 0 = keep the model's pose, 1 = hang straight down
		Legs = 0.2,
		Head = 0.15,
		Knees = 16,
		Elbows = 10,
		Swing = 9,
	},
}
