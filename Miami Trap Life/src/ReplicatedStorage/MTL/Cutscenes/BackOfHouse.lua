--!strict
-- Act 2.1 "Back of the House", part 1 (Story Bible §4): the late delivery behind Liberty Food Mart. ~35 s, skippable.
-- Opens the chapter: "CHAPTER 2 · The Tab" over the establishing shot. Data only: CutsceneController plays it.
-- Shot plan:
--   A  0.0  wide from the far end of the alley: the idling box truck, Patel and the driver; you walk in   (where)
--   B  6.2  over Patel's shoulder on the driver: "except the last pallet"                                  (the problem)
--   C  9.6  reverse, over the driver's shoulder on Patel                                                   (who's short)
--   D 12.4  medium on the driver: eighteen hundred short                                                   (the number)
--   E 15.6  3/4 wide: the three of you and the pallet between Patel and the truck                          (the stakes)
--   F 19.4  close on Patel counting what he has (the pallet loses half, off camera)                       (the cost)
--   G 23.0  two-shot, Patel turns to you with the joke; the half pallet behind you                         (who he is)
--   H 27.0  close on you: the YOU thought                                                                  (subtext)
--   I 30.2  over your shoulder on Patel: watch the till; fade                                               (next step)
-- Anchor = CFrame.new(-1478, 2.3, -286): the back doorway, world-aligned (+Z = out into the alley, +X = east).
-- Measured 2026-11-03: back wall + doorway at local z 0 (x -2..2), dumpster at local (-8, 6.4), the alley is open
-- to the mural board at local z ~23. The truck parks along the alley, nose east, its open back by the doorway.
local V = Vector3.new

local TRUCK = CFrame.new(14, 0, 14.5) * CFrame.Angles(0, -math.pi / 2, 0) -- 21 long: x 3.5 .. 24.5, z 10.7 .. 18.3
local PALLET = CFrame.new(1.2, 0, 14.6) -- the last pallet, on the ground at the truck's open back
local HIDDEN = CFrame.new(1.2, -60, 14.6)

local PATEL = V(-0.8, 0, 6.6)
local DRIVER = V(1.6, 0, 11.4)
local YOU = V(3.4, 0, 6.2)

return {
	id = "BackOfHouse",
	length = 35.0,
	skippable = true,
	fadeIn = 1.0,
	-- no hour / grade: scenes keep the world's own lighting
	dof = true,
	ambience = "City",
	stream = { V(0, 0, 10), V(24, 0, 10) },
	placePlayer = { at = V(4, 0, 4), face = V(4, 0, -10) }, -- by the doorway, facing the store: the next step is inside
	actors = {
		Patel = { rig = "Patel", at = PATEL, face = DRIVER },
		Driver = { rig = "Driver", at = DRIVER, face = PATEL, hold = "Clipboard" },
		Player = { rig = "@player", at = V(15, 0, 4.4), face = V(0, 0, 5) },
	},
	props = {
		Truck = { prop = "DeliveryTruck", at = TRUCK },
		Unloaded = { prop = "Pallet", at = CFrame.new(-4.2, 0, 2.8) * CFrame.Angles(0, math.rad(8), 0), boxes = 12 },
		LastFull = { prop = "Pallet", at = PALLET, boxes = 12 },
		LastHalf = { prop = "Pallet", at = HIDDEN, boxes = 6 },
	},
	shots = {
		-- A: low wide from the east end of the alley, the truck's lit side filling the right of frame
		{ t = 0, from = { pos = V(34, 4.5, 4.2), look = V(2, 4, 9) }, to = { pos = V(30, 4.2, 4.0), look = V(1, 4, 9) }, dur = 6.2, fov = 52, blur = 0.12 },
		-- B: over Patel's shoulder on the driver
		{ t = 6.2, from = { ots = { "Patel", "Driver" }, dist = 4.2, side = 2.8 }, to = { ots = { "Patel", "Driver" }, dist = 3.8, side = 2.8 }, dur = 3.4, fov = 46, blur = 0.4 },
		-- C: reverse, over the driver's shoulder on Patel
		{ t = 9.6, from = { ots = { "Driver", "Patel" }, dist = 4.2, side = -2.8 }, to = { ots = { "Driver", "Patel" }, dist = 3.8, side = -2.8 }, dur = 2.8, fov = 46, blur = 0.4 },
		-- D: medium on the driver, slow push
		{ t = 12.4, from = { close = "Driver", dist = 13.5, side = -1 }, to = { close = "Driver", dist = 11.5, side = -1 }, dur = 3.2, fov = 40, ease = "Quad", blur = 0.45 },
		-- E: 3/4 wide from the dumpster side: Patel, the driver, the full pallet, the truck's open back
		{ t = 15.6, from = { pos = V(-7.5, 5.2, 13.5), look = V(1.5, 3.4, 9.5) }, to = { pos = V(-7, 5, 12.4), look = V(1.5, 3.4, 9.5) }, dur = 3.8, fov = 50, blur = 0.25 },
		-- F: close on Patel counting (the camera is between him and the truck, the pallet is behind it)
		{ t = 19.4, from = { close = "Patel", dist = 9.0, side = 0.8 }, to = { close = "Patel", dist = 7.7, side = 0.8 }, dur = 3.6, fov = 38, ease = "Quad", focus = "Patel", blur = 0.55 },
		-- G: two-shot, Patel and you, the half pallet and the truck behind you
		{ t = 23.0, from = { two = { "Patel", "Player" }, dist = 9, side = -1, height = 1.2 }, to = { two = { "Patel", "Player" }, dist = 8.2, side = -1, height = 1.2 }, dur = 4.0, fov = 46, blur = 0.3 },
		-- H: close on you
		{ t = 27.0, from = { close = "Player", dist = 9.9, side = 1 }, to = { close = "Player", dist = 8.3, side = 1 }, dur = 3.2, fov = 38, ease = "Quad", blur = 0.55 },
		-- I: over your shoulder on Patel, then the fade
		{ t = 30.2, from = { ots = { "Player", "Patel" }, dist = 4.0, side = 2.7 }, to = { ots = { "Player", "Patel" }, dist = 3.5, side = 2.7 }, dur = 4.8, fov = 46, blur = 0.4 },
	},
	lines = {
		{ t = 6.4, who = "Driver", text = "That's everything. Except the last pallet.", dur = 3.0 },
		{ t = 9.8, who = "Patel", text = "What's wrong with the last pallet?", dur = 2.5 },
		{ t = 12.6, who = "Driver", text = "You're eighteen hundred short, Mr. P.", dur = 2.9 },
		{ t = 15.8, who = "Driver", text = "Since the... thing. Company says cash first.", dur = 3.4 },
		{ t = 19.6, who = "Patel", text = "Half. Take half back. Half is fine.", dur = 3.1 },
		{ t = 23.3, who = "Patel", text = "Half a pallet. Very modern. Minimalism.", dur = 3.4 },
		{ t = 27.2, who = "You", text = "He's laughing. His hands are shaking.", dur = 2.9 },
		{ t = 30.5, who = "Patel", text = "Watch the till for me? I need to sit a minute.", dur = 3.6 },
	},
	actions = {
		{ t = 1.0, title = "CHAPTER 2", sub = "The Tab", dur = 4.4 },
		{ t = 1.4, actor = "Player", walk = YOU, dur = 4.6, ease = "QuadOut" },
		{ t = 6.0, actor = "Player", turn = "@Driver", dur = 0.5 },
		{ t = 6.6, actor = "Driver", gesture = "Point", dur = 1.6 }, -- at the pallet
		{ t = 10.0, actor = "Patel", gesture = "Open", dur = 1.6 },
		{ t = 12.8, actor = "Driver", gesture = "Shrug", dur = 1.4 },
		{ t = 16.0, actor = "Player", turn = "@Patel", dur = 0.6 },
		{ t = 19.4, actor = "Patel", hold = "Bill" },
		{ t = 19.5, actor = "Patel", gesture = "Count", dur = 2.2 },
		{ t = 21.0, prop = "LastFull", move = HIDDEN, dur = 0.01 },
		{ t = 21.0, prop = "LastHalf", move = PALLET, dur = 0.01 },
		{ t = 21.7, actor = "Patel", gesture = "Give", dur = 1.0 },
		{ t = 22.2, actor = "Patel", hold = false },
		{ t = 22.2, actor = "Driver", hold = "Bill" },
		{ t = 22.8, actor = "Driver", walk = V(2.6, 0, 12.8), dur = 0.8 },
		{ t = 23.0, actor = "Patel", turn = YOU, dur = 0.6 }, -- (a "@Name" turn aims at where that actor STARTED)
		{ t = 23.6, actor = "Patel", gesture = "Laugh", dur = 2.0 },
		{ t = 26.0, actor = "Player", turn = "@Patel", dur = 0.4 },
		{ t = 30.6, actor = "Patel", gesture = "Point", dur = 1.4 }, -- at the door in
		{ t = 32.0, actor = "Player", gesture = "Nod", dur = 1.2 },
		{ t = 33.6, fade = "out", dur = 1.2 },
	},
}
