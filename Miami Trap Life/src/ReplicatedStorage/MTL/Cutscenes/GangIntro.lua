--!strict
-- Stage 5: the crew introduces itself at the meet spot (~39 s, skippable). Data only: CutsceneController plays it.
-- Coordinates are LOCAL to the meet spot CFrame (Missions.Meet.Layout): crew around z 0..8, the player stands at
-- z = -10 facing them. Beats (Research: Cutscenes): wide establishing -> Dre steps up -> player reaction ->
-- Dre / Smoke / Nina one line each -> the pitch -> push-in on the player -> black -> "FIRST JOB".
local Missions = require(script.Parent.Parent.Config.Missions)

local V = Vector3.new
local L = Missions.Meet.Layout

return {
	id = "GangIntro",
	length = 38.8,
	skippable = true,
	holdBlack = true, -- ends on black: the server moves the player to the job, the mission screen fades in
	fadeIn = 0.8,
	-- no hour / grade: scenes keep the world's own lighting (Alex: "the lighting changes during the cutscenes")
	dof = true,
	ambience = "Ambience", -- a Theme.Mission.Sounds key ("" there = silent)
	music = "CrewMusic", -- Theme.Cutscene.Sounds: low drums under the pitch
	musicVolume = 0.28,
	actors = {
		Dre = { rig = "Dre", at = L.Dre.at, face = L.Dre.face },
		Smoke = { rig = "Smoke", at = L.Smoke.at, face = L.Smoke.face },
		Nina = { rig = "Nina", at = L.Nina.at, face = L.Nina.face },
		Player = { rig = "@player", at = V(0, 0, -21), face = V(0, 0, 0) },
	},
	props = {
		Car = { prop = "CrewCar", at = L.Car, hazards = true },
	},
	-- camera: pos/look are local points (look may be an actor name = their head), or helpers:
	--   two = {A, B} (both in frame, side-on), close = A (face shot), ots = {listener, speaker} (over the shoulder)
	shots = {
		-- establishing: a crane down along a curve onto the crew by the car (Research: Cinematic Cutscenes §3)
		{ t = 0, from = { path = { V(-34, 22, -40), V(-27, 14, -31), V(-19, 8.5, -23) }, lookPath = { V(0, 1, 6), V(0, 2, 3), V(0, 3, 0) } }, dur = 5, fov = 58, fovTo = 54, blur = 0.12 },
		{ t = 5, from = { ots = { "Player", "Dre" }, dist = 6.5, side = 2.4 }, to = { ots = { "Player", "Dre" }, dist = 5.2, side = 2.4 }, dur = 3.8, fov = 46, focus = "Dre", blur = 0.35 }, -- over your shoulder as Dre walks up
		{ t = 8.8, from = { close = "Player", dist = 5.5, side = -1 }, to = { close = "Player", dist = 5.1, side = -1 }, dur = 1.6, fov = 38, blur = 0.5 },
		{ t = 10.4, from = { ots = { "Player", "Dre" }, dist = 5, side = 2.2 }, to = { ots = { "Player", "Dre" }, dist = 4.2, side = 2.2 }, dur = 4, fov = 48, blur = 0.45 },
		{ t = 14.6, from = { close = "Smoke", dist = 7, side = 1 }, to = { close = "Smoke", dist = 6, side = 1 }, dur = 3.8, fov = 45, blur = 0.5 },
		{ t = 18.4, from = { close = "Nina", dist = 7, side = -1 }, to = { close = "Nina", dist = 6, side = -1 }, dur = 3.8, fov = 45, blur = 0.5 },
		{ t = 22.2, from = { ots = { "Player", "Dre" }, dist = 4.6, side = 2.2 }, fov = 46, handheld = 0.04, blur = 0.45 },
		-- push-in on the player while Dre names the target ("this is serious")
		{ t = 26.6, from = { close = "Player", dist = 7.5, side = 1 }, to = { close = "Player", dist = 6.0, side = 1 }, dur = 1.8, fov = 50, fovTo = 45, ease = "Quad", blur = 0.55 },
		-- Act 1 plant (Story Bible): on "Same store. Tonight." Nina glances at Dre for a beat. She doesn't like it. No line.
		{ t = 28.4, from = { close = "Nina", dist = 5.5, side = -1 }, fov = 38, blur = 0.6 },
		{ t = 29.4, from = { close = "Player", dist = 5.4, side = 1 }, to = { close = "Player", dist = 4.5, side = 1 }, dur = 1.2, fov = 42, fovTo = 40, ease = "Quad", blur = 0.55 },
		-- low and wide: the whole crew in one frame, slow pull back (they're a team now)
		{ t = 30.6, from = { pos = V(0, 3.2, -18), look = V(0, 4, 2) }, to = { pos = V(0, 3.8, -22), look = V(0, 4, 2) }, dur = 5, fov = 52, blur = 0.15 },
	},
	lines = {
		{ t = 5.4, who = "Dre", text = "So you're the kid from the Food Mart.", dur = 3.2 },
		{ t = 10.6, who = "Dre", text = "Relax. I'm Dre. I run the young ones for the Liberty Lows.", dur = 3.9 },
		{ t = 14.8, who = "Smoke", text = "Smoke. I drive. Fast, and never the same way twice.", dur = 3.6 },
		{ t = 18.6, who = "Nina", text = "Nina. I watch the block so nobody sneaks up on us.", dur = 3.5 },
		{ t = 22.4, who = "Dre", text = "Patel pays you eight a box. His register makes that in a minute.", dur = 4.2 },
		{ t = 26.7, who = "Dre", text = "Same store. Tonight. You know the layout, we do the rest.", dur = 3.9 },
		{ t = 30.8, who = "Smoke", text = "In and out. Two minutes.", dur = 2.0 },
		{ t = 32.9, who = "Nina", text = "Nobody gets hurt. Masks are in the car.", dur = 2.6 },
	},
	-- actions (sorted by t). walk/turn/move are smooth over dur; gesture plays once; pose = held base pose
	-- ("None" clears it); hide; sound (a Theme.Mission.Sounds key or an id); shake; fade "in"/"out"; title.
	actions = {
		{ t = 0, actor = "Dre", pose = "Cross" },
		{ t = 0, actor = "Smoke", pose = "Lean" },
		{ t = 0, actor = "Nina", pose = "Phone" },
		{ t = 0, actor = "Player", walk = L.Player.at, dur = 4.4 },
		{ t = 5, actor = "Dre", pose = "None" },
		{ t = 5.1, actor = "Dre", walk = V(0, 0, -5), dur = 1.8 },
		{ t = 7, actor = "Dre", gesture = "Point", dur = 1.4 },
		{ t = 9, actor = "Player", gesture = "Shrug", dur = 2.0 },
		{ t = 10.8, actor = "Dre", gesture = "Open", dur = 1.8 },
		{ t = 15.2, actor = "Smoke", gesture = "Nod", dur = 2.0 },
		{ t = 18.4, actor = "Nina", pose = "None" },
		{ t = 18.8, actor = "Nina", gesture = "Wave", dur = 1.8 },
		{ t = 22.6, actor = "Dre", gesture = "Point", dur = 1.6 },
		{ t = 27, actor = "Dre", gesture = "Nod", dur = 1 },
		{ t = 28.3, actor = "Nina", turn = "@Dre", dur = 0.3 },
		{ t = 29.5, actor = "Nina", turn = L.Player.at, dur = 0.5 },
		{ t = 30.8, actor = "Smoke", pose = "None" },
		{ t = 30.9, actor = "Smoke", gesture = "Laugh", dur = 2.0 },
		{ t = 33.6, actor = "Nina", gesture = "Point", dur = 1.2 },
		{ t = 35.6, fade = "out", dur = 0.6 },
		{ t = 36.3, title = "FIRST JOB", sub = "Liberty Food Mart", dur = 2.5 },
	},
}
