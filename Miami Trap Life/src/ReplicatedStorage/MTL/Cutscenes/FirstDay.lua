--!strict
-- Stage 2 (FirstShift), first time only: Mr. Patel meets you inside Liberty Food Mart (~25 s, skippable).
-- Data only: CutsceneController plays it. Research: Cinematic Cutscenes. Shot plan:
--   A  0.0  from inside: you walk up, slow down, the sliding doors open, the bell, you step in and look around
--           (Alex: "make him open the door, walk it normally, not through walls": the walk follows the doorway)
--   B  5.8  two-shot, you and Patel on the shop floor                              (who)
--   C  9.8  over your shoulder on Patel; he points to the back                   (the job)
--   D1 13.8 insert: the open tab book (and the photo of young Dre beside the till)   (the story's theme)
--   D2 19.7 close-up on Patel, the joke                                           (who he is)
--   E 22.4  you walk into the aisle, the camera glides into a close gameplay camera, "FIRST SHIFT" (hand-off)
-- Anchor = StoryWelcome.storeAnchor(): at Locations.FoodMart.Door, local -Z = into the store, local +X = world -X.
-- Layout (measured in Studio after the job-interiors rebuild, 2026-11-02): front door centred at local x 0 in the
-- glass line (local z -6.3), checkout counter on the east side at local x -17 (world x -1425), Patel's spot behind
-- it at local (-23, -12), shelf rows from local z -18 back, free aisle at local x -10.4, coolers at the back.
-- (Quality pass: 3 gondolas now, the middle one at world x -1439.1 with an endcap, so the walk uses aisle 1.)
local V = Vector3.new

local MEET = V(-12.5, 0, -11) -- you stop at the counter, across from Patel
local AISLE = V(-10.4, 0, -21) -- then walk into the aisle (the real character waits here, hidden); camera stays inside
local BACK = V(-10.4, 0, -40) -- the coolers at the back

local DOOR_OUT = V(0, 0, -2.2) -- just outside the doorway (the glass line is at local z -6.3)
local DOOR_IN = V(0, 0, -9.5) -- one step inside
local TURN = V(-10.4, 0, -14.5) -- the corner of the open floor before the aisle (keeps clear of the shelf ends)

return {
	id = "FirstDay",
	length = 25.0,
	skippable = true,
	fadeIn = 0.7,
	-- no hour / grade: scenes keep the world's own lighting (Alex: "the lighting changes during the cutscenes")
	dof = true,
	stream = { V(0, 0, -20) },
	placePlayer = { at = AISLE, face = BACK },
	actors = {
		Patel = { rig = "Patel", at = V(-21, 0, -13.5), face = MEET }, -- behind the counter, clear of the register and stool
		Player = { rig = "@player", at = V(0, 0, 6), face = DOOR_OUT },
	},
	-- the store's automatic sliding doors (closed at the start, they part as you reach them). The map has real ones
	-- now (InteriorV2.Shell.AutoDoors, server-driven): hidden for the scene so the timing is ours, back afterwards.
	hideWorld = { { name = "AutoDoors", at = V(0, 4, -6.3), radius = 7 } },
	props = {
		DoorA = { prop = "GlassDoor", at = CFrame.new(-1.42, 0, -6.3) },
		DoorB = { prop = "GlassDoor", at = CFrame.new(1.42, 0, -6.3) * CFrame.Angles(0, math.pi, 0) },
		-- Act 1 plants (Story Bible): Patel's tab book open on the counter, and the photo nobody mentions
		TabBook = { prop = "TabBook", at = CFrame.new(-17, 0, -12.4) * CFrame.Angles(0, math.rad(90), 0) },
		Photo = { prop = "DrePhoto", at = CFrame.new(-17.4, 0, -14.4) * CFrame.Angles(0, -math.pi / 2, 0) },
	},
	shots = {
		-- A: from inside the store, high, looking at the door: you walk up, the doors slide open, you step in
		{ t = 0, from = { pos = V(-10.5, 8.5, -19), look = V(0, 4, -4) }, to = { pos = V(-11, 8, -17.5), look = V(-2, 4, -8) }, dur = 5.8, fov = 56, blur = 0.15 },
		-- B: two-shot from the shop floor: you screen-left, Patel behind the counter screen-right
		{ t = 5.8, from = { pos = V(-7, 5.6, -17), look = V(-15, 4.6, -12) }, to = { pos = V(-7.8, 5.5, -16.2), look = V(-15, 4.6, -12) }, dur = 4, fov = 50, blur = 0.3, safe = false }, -- checked clear in Studio; the wall check would snag on the counter's plexi
		-- C: over your shoulder on Patel while he points to the back
		{ t = 9.8, from = { ots = { "Player", "Patel" }, dist = 4.4, side = 2.2 }, to = { ots = { "Player", "Patel" }, dist = 3.8, side = 2.2 }, dur = 3.8, fov = 48, blur = 0.4 },
		-- D1: insert on the open tab book (Act 1 plant: the theme of the whole story), the photo of young Dre in frame
		{ t = 13.8, from = { pos = V(-13.6, 6.2, -10.6), look = V(-17, 2.7, -12.8) }, to = { pos = V(-13.9, 5.9, -11.2), look = V(-17, 2.7, -13.0) }, dur = 5.9, fov = 34, ease = "Sine", focus = V(-17, 2.7, -12.4), blur = 0.55, safe = false },
		-- D2: medium close on Patel, the joke
		{ t = 19.7, from = { pos = V(-11, 5.6, -14.5), look = "Patel" }, to = { pos = V(-12, 5.5, -14), look = "Patel" }, dur = 2.7, fov = 40, ease = "Quad", blur = 0.5, safe = false },
		-- E: you walk into the aisle; the camera follows and settles into a close gameplay camera (we're indoors)
		{ t = 22.4, from = { pos = V(-2, 6.4, -12.5), look = V(-10.4, 4, -34) }, to = { gameplay = true, dist = 7.5, height = 2.4 }, dur = 2.6, fov = 56, fovTo = 70, ease = "Cubic", blur = 0.1 },
	},
	lines = {
		{ t = 6.2, who = "Patel", text = "Ah, the new kid! Right on time. I like that.", dur = 3.0 },
		{ t = 10.0, who = "Patel", text = "Boxes in the back, shelves out front. Eight bucks a box.", dur = 3.8 },
		{ t = 14.1, who = "Patel", text = "That book's for people who are short this week.", dur = 3.2 },
		{ t = 17.4, who = "Patel", text = "Everybody is short some week.", dur = 2.2 },
		{ t = 19.8, who = "Patel", text = "Break nothing. And smile, customers love a smile.", dur = 3.2 },
	},
	actions = {
		-- walk up and slow down at the door (QuadOut = decelerate), the doors sense you and slide apart
		{ t = 0.1, actor = "Player", walk = DOOR_OUT, dur = 1.9, ease = "QuadOut" },
		{ t = 0.6, prop = "DoorA", move = CFrame.new(-4.15, 0, -6.3), dur = 0.6, ease = "Quad" }, -- open well before he arrives
		{ t = 0.6, prop = "DoorB", move = CFrame.new(4.15, 0, -6.3) * CFrame.Angles(0, math.pi, 0), dur = 0.6, ease = "Quad" },
		{ t = 0.65, sound = "StoreBell", volume = 0.45 },
		-- step in straight through the middle of the doorway, then glance around the store
		{ t = 2.1, actor = "Player", walk = DOOR_IN, dur = 1.5 },
		{ t = 3.6, actor = "Player", turn = V(6, 0, -14), dur = 0.5 },
		{ t = 4.1, actor = "Player", turn = MEET, dur = 0.45 },
		{ t = 4.2, prop = "DoorA", move = CFrame.new(-1.42, 0, -6.3), dur = 0.9, ease = "Quad" },
		{ t = 4.2, prop = "DoorB", move = CFrame.new(1.42, 0, -6.3) * CFrame.Angles(0, math.pi, 0), dur = 0.9, ease = "Quad" },
		{ t = 4.5, actor = "Player", walk = MEET, dur = 1.6 },
		{ t = 6.0, actor = "Patel", gesture = "Wave", dur = 1.8 },
		{ t = 10.6, actor = "Patel", gesture = "Point", dur = 2.2 },
		{ t = 11.8, actor = "Player", gesture = "Nod", dur = 1.9 },
		{ t = 14.2, actor = "Patel", gesture = "Open", dur = 1.4 },
		{ t = 20.0, actor = "Patel", gesture = "Laugh", dur = 2.0 },
		{ t = 22.4, actor = "Player", walk = TURN, dur = 1.2 },
		{ t = 22.6, title = "FIRST SHIFT", sub = "Liberty Food Mart", dur = 2.4 },
		{ t = 23.6, actor = "Player", walk = AISLE, dur = 1.4 },
	},
}
