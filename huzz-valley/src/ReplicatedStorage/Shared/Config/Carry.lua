-- How the girl is held overhead. Angles are degrees, distances studs.
-- The pose sits on top of whatever walk/run/huss animation is playing: the
-- girl is attached to the torso, so she follows its bob and sway for free.
return {
	GirlLength = 5.4, -- her height before she's laid down (models are scaled to it; a default avatar is about 5.2-5.9)
	HeadToLeft = true, -- which shoulder her head points over
	Rotation = Vector3.new(20, 0, 0), -- extra tilt; +X turns her face toward the camera
	Forward = 0, -- move her forward (-) or back (+)
	Sink = 0.2, -- how far she sinks into the hands
	HairRoom = 0.3, -- she never sits lower than the head top plus this

	PickupTime = 0, -- 0 = she appears overhead at once (owner's call); e.g. 0.55 = she flies in from where she was
	ArcHeight = 3.5,

	Arms = {
		Raise = 170, -- 180 = straight up
		Spread = 14, -- elbows out
		ElbowBend = 28, -- forearms in toward her
		AnimBlend = 0.2, -- how much of the playing animation's arm swing shows through
	},

	Bob = {
		StepsPerStud = 0.15, -- footsteps per stud walked (match the walk animation)
		Height = 0.06, -- kept small: the owner asked for no wiggle
		Roll = 0, -- side-to-side rock per step
		ElbowFlex = 3,
	},

	-- Hussing (H / the HUSS button while carrying her): he throws her up, she twirls, he does
	-- his huss move under her, and catches her. Time in seconds, Height in studs above the hold.
	Huss = { Time = 1.6, Height = 7, Spins = 1 },

	-- Inertia: she lags behind speed changes and turns, then wobbles back.
	Spring = {
		Frequency = 5,
		Damping = 0.9, -- 1 = no wobble back and forth
		Lag = 0.005, -- studs of lag per stud/s^2 of acceleration
		MaxLag = 0.2,
		Tilt = 15, -- degrees of tilt per stud of lag
		TurnLag = 0.02, -- radians of yaw lag per radian/s of turning
		MaxTurnLag = 0.12,
	},

	-- A catcher who steals her doesn't carry her: she walks along behind him.
	Follow = {
		Offset = Vector3.new(3.5, 0, 1.5), -- where she aims to be, from the catcher (right, up, behind): beside him, so she never blocks his camera
		Catchup = 6, -- how hard she closes the gap (higher = keeps closer when he runs)
		MaxSpeed = 30, -- studs per second
		StopDistance = 1, -- within this of her spot she stands still
		TeleportDistance = 60, -- further than this (he teleported) and she pops to her spot
		Stride = 4.2, -- studs per full walk cycle (two steps)
	},
}
