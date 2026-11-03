--!strict
-- Act 2.3 "Cash 4 Gold" (Story Bible §4): upstairs in Royce's office to get paid for the goods. Dre makes you come
-- up "so he knows your face". Royce pays Dre, then pays you a bonus "for the Food Mart". Royce knew. ~39 s, skippable.
-- Shot plan:
--   A  0.0  wide from the office corner: you and Dre walk up to the desk, Royce behind it            (where, who)
--   B  5.4  over your shoulder on Royce                                                          (the man)
--   C  8.8  medium on Royce                                                                       (the inspection)
--   D 11.8  two-shot Royce and Dre: Dre's envelope                                                 (the deal)
--   E 14.4  over Royce's shoulder on you: your envelope, "for the Food Mart"                       (the reveal)
--   F 20.2  close on Dre: his jaw tightens. No line.                                              (Dre knew he knew)
--   G 23.0  INSERT: the wall map, Patel's corner circled in red with a question mark              (the stakes)
--   H 27.6  close on Royce, slow push                                                              (the threat, politely)
--   I 34.6  wide: you leave; fade                                                                  (out)
-- Set: Workspace.ViceBay.Buildings.Hood.RoyceCash4Gold (building thread). The anchor is the world (CFrame.new()),
-- every position is a mark; StoryMissions passes the set's live Anchors (C4G_* parts, prefix dropped), so moving
-- the set moves the scene. The defaults below are the anchors as built on 2026-11-03 (parts sit ~2 above the floor).
local V = Vector3.new

local function m(name: string, off: Vector3?): any
	return { mark = name, off = off }
end

return {
	id = "Cash4Gold",
	length = 39.0,
	skippable = true,
	fadeIn = 1.0,
	dof = true,
	music = "CrewMusic",
	musicVolume = 0.22,
	marks = {
		AlleyDoor = V(-1134.2, 5.0, -337.5),
		Royce_Chair = V(-1114.2, 18.8, -337.3),
		Player_AtDesk = V(-1114.2, 18.8, -345.0),
		Dre_AtDesk = V(-1118.7, 18.8, -346.5),
		WallMap_Look = V(-1124.2, 20.6, -349.5),
		RedBook = V(-1112.4, 19.2, -340.9),
		Cam_OfficeWide = V(-1096.2, 22.8, -363.5),
		Cam_OverShoulder = V(-1112.7, 21.0, -348.0),
	},
	stream = { "#Royce_Chair", "#AlleyDoor" },
	placePlayer = { at = m("AlleyDoor", V(-5, 0, 0)), face = m("AlleyDoor", V(-14, 0, 0)) },
	actors = {
		Royce = { rig = "Royce", at = "#Royce_Chair", face = "#Player_AtDesk", pose = "Sit" },
		Dre = { rig = "Dre", at = m("Dre_AtDesk", V(0.6, 0, -4.4)), face = "#Royce_Chair" },
		Player = { rig = "@player", at = m("Player_AtDesk", V(0, 0, -4.6)), face = "#Royce_Chair" },
	},
	shots = {
		-- A: wide from the office corner, settling as you reach the desk
		{ t = 0, from = { pos = "#Cam_OfficeWide", look = m("Royce_Chair", V(0, 0.6, -2)) }, to = { pos = m("Cam_OfficeWide", V(-1.4, -0.4, 1.6)), look = m("Royce_Chair", V(0, 0.4, -3)) }, dur = 5.4, fov = 52, blur = 0.15, safe = false },
		-- B: over your shoulder on Royce
		{ t = 5.4, from = { ots = { "Player", "Royce" }, dist = 3.8, side = 2.6 }, to = { ots = { "Player", "Royce" }, dist = 3.4, side = 2.6 }, dur = 3.4, fov = 44, blur = 0.45 },
		-- C: medium on Royce
		{ t = 8.8, from = { close = "Royce", dist = 10.8, side = -1 }, to = { close = "Royce", dist = 9.7, side = -1 }, dur = 3.0, fov = 40, ease = "Quad", blur = 0.5 },
		-- D: Royce and Dre, the first envelope
		{ t = 11.8, from = { two = { "Royce", "Dre" }, dist = 9, side = -1, height = 1.0 }, to = { two = { "Royce", "Dre" }, dist = 8.4, side = -1, height = 1.0 }, dur = 2.6, fov = 46, blur = 0.3 },
		-- E: over Royce's shoulder on you, the bonus
		{ t = 14.4, from = { ots = { "Royce", "Player" }, dist = 3.8, side = -2.5 }, to = { ots = { "Royce", "Player" }, dist = 3.4, side = -2.5 }, dur = 5.8, fov = 44, blur = 0.45 },
		-- F: close on Dre, a slow push, no line
		{ t = 20.2, from = { close = "Dre", dist = 9.0, side = 1 }, to = { close = "Dre", dist = 7.0, side = 1 }, dur = 2.8, fov = 36, ease = "Sine", blur = 0.6 },
		-- G: insert on the wall map (the set's camera spot, looking along its look vector at the map)
		{ t = 23.0, from = { pos = m("WallMap_Look", V(2.2, -0.1, 0.4)), look = m("WallMap_Look", V(-6, 1.2, 0)) }, to = { pos = m("WallMap_Look", V(0.6, 0, 0)), look = m("WallMap_Look", V(-6, 1.1, 0)) }, dur = 4.6, fov = 40, ease = "Sine", blur = 0.4, safe = false },
		-- H: close on Royce
		{ t = 27.6, from = { close = "Royce", dist = 8.6, side = -0.6 }, to = { close = "Royce", dist = 7.0, side = -0.6 }, dur = 7.0, fov = 36, ease = "Sine", blur = 0.6 },
		-- I: wide, you and Dre leave
		{ t = 34.6, from = { pos = m("Cam_OfficeWide", V(-1.4, -0.4, 1.6)), look = m("Royce_Chair", V(0, 0.4, -4)) }, to = { pos = m("Cam_OfficeWide", V(-1.8, -0.5, 2.2)), look = m("Royce_Chair", V(0, 0.4, -5)) }, dur = 4.4, fov = 50, blur = 0.2, safe = false },
	},
	lines = {
		{ t = 1.0, who = "Dre", text = "He wants to see your face. That's how it works.", dur = 3.4 },
		{ t = 5.6, who = "Royce", text = "Andre. And the young man from the Food Mart.", dur = 3.1 },
		{ t = 9.0, who = "Royce", text = "Every box, no scratches. Good.", dur = 2.6 },
		{ t = 12.0, who = "Royce", text = "For the goods.", dur = 2.0 },
		{ t = 14.6, who = "Royce", text = "And this one's yours. A bonus.", dur = 2.4 },
		{ t = 17.3, who = "Royce", text = "For the Food Mart. Clean work.", dur = 2.8 },
		{ t = 23.6, who = "You", text = "That's Patel's corner.", dur = 2.6 },
		{ t = 27.9, who = "Royce", text = "Nobody in Liberty ever got rich working for Hemant.", dur = 3.6 },
		{ t = 31.8, who = "Royce", text = "Andre knows. Don't you, Andre?", dur = 2.6 },
		{ t = 34.8, who = "Dre", text = "Let's go, Food Mart.", dur = 2.2 },
	},
	actions = {
		{ t = 0.4, actor = "Player", walk = "#Player_AtDesk", dur = 3.8, ease = "QuadOut" },
		{ t = 0.6, actor = "Dre", walk = "#Dre_AtDesk", dur = 3.6, ease = "QuadOut" },
		{ t = 4.4, actor = "Dre", turn = "#Royce_Chair", dur = 0.5 },
		{ t = 4.4, actor = "Player", turn = "#Royce_Chair", dur = 0.5 },
		{ t = 5.8, actor = "Royce", gesture = "Open", dur = 1.6 },
		{ t = 11.8, actor = "Royce", hold = "Envelope" },
		{ t = 12.1, actor = "Royce", gesture = "Give", dur = 1.1 },
		{ t = 13.2, actor = "Royce", hold = false },
		{ t = 13.2, actor = "Dre", hold = "Envelope" },
		{ t = 14.4, actor = "Royce", hold = "Envelope" },
		{ t = 14.8, actor = "Royce", gesture = "Give", dur = 1.4 },
		{ t = 16.2, actor = "Royce", hold = false },
		{ t = 16.2, actor = "Player", hold = "Envelope" },
		{ t = 18.0, actor = "Player", gesture = "Nod", dur = 1.0 },
		{ t = 22.2, actor = "Player", turn = "#WallMap_Look", dur = 0.8 }, -- the map catches your eye
		{ t = 28.2, actor = "Royce", gesture = "Open", dur = 1.8 },
		{ t = 32.0, actor = "Royce", gesture = "Point", dur = 1.2 }, -- at Dre
		{ t = 34.6, actor = "Dre", walk = m("Dre_AtDesk", V(0.6, 0, -5)), dur = 2.6 },
		{ t = 35.2, actor = "Player", walk = m("Player_AtDesk", V(0, 0, -5.2)), dur = 2.6 },
		{ t = 37.6, fade = "out", dur = 1.2 },
	},
}
