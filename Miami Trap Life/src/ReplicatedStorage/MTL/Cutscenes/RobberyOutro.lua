--!strict
-- End of stage 6: you reach the getaway car, jump in, the car tears off, and the crew talks over black (~11 s).
-- Coordinates are LOCAL to the getaway car spot (Missions.FirstMission.Points.Car): car at the origin, front = -Z.
-- "@here" = where the real player is standing when the scene starts.
local V = Vector3.new

return {
	id = "RobberyOutro",
	length = 11.4,
	skippable = true,
	holdBlack = true, -- ends on black: the server moves the player to the drop-off, the payout screen fades in
	fadeIn = 0.25,
	-- no hour / grade: scenes keep the world's own lighting (Alex: "the lighting changes during the cutscenes")
	dof = true,
	actors = {
		Player = { rig = "@player", at = "@here", face = V(-3, 0, 0) },
		Dre = { rig = "Dre", at = V(-4.2, 0, 3), face = "@Player" },
	},
	props = {
		Car = { prop = "CrewCar", at = CFrame.new(), hazards = false },
	},
	shots = {
		{ t = 0, from = { pos = V(-16, 5, -12), look = "Car" }, to = { pos = V(-14, 4.5, -10), look = "Car" }, dur = 2.2, fov = 55, handheld = 0.08, focus = "Car", blur = 0.3 },
		-- low by the kerb: the car tears past the lens (cut on the engine)
		{ t = 2.2, from = { pos = V(-9, 1.6, -24), look = "Car" }, to = { pos = V(-9.5, 1.8, -27), look = "Car" }, dur = 3.4, fov = 52, handheld = 0.06, focus = "Car", blur = 0.4 },
	},
	lines = {
		{ t = 6.0, who = "Smoke", text = "Two minutes. Told you.", dur = 2.2 },
		{ t = 8.4, who = "Dre", text = "Not bad, Food Mart. Not bad at all.", dur = 2.8 },
	},
	actions = {
		{ t = 0, actor = "Dre", gesture = "Point", dur = 1.2 },
		{ t = 0.1, actor = "Player", walk = V(-3.2, 0, 0.6), dur = 1.1 },
		{ t = 1.2, actor = "Player", hide = true },
		{ t = 1.2, sound = "Door" },
		{ t = 1.3, actor = "Dre", walk = V(-3.2, 0, 2), dur = 0.5 },
		{ t = 1.8, actor = "Dre", hide = true },
		{ t = 2.0, sound = "Engine" },
		{ t = 2.2, prop = "Car", move = CFrame.new(0, 0, -70), dur = 3.6, ease = "QuadIn" },
		{ t = 2.3, shake = 0.25, dur = 0.6 },
		{ t = 5.2, fade = "out", dur = 0.6 },
	},
}
