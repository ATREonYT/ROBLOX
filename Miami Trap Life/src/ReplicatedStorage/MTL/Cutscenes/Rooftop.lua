--!strict
-- Act 2.7 "The Tab", part 1 (Story Bible §4): the Ends rooftop at night, the skyline behind Nina (the act's money
-- shot). She shows you what she photographed at Royce's: the Food Mart job was his. ~41 s, skippable.
-- Shot plan:
--   A  0.0  the skyline alone, a slow drift                                                       (the city that's coming)
--   B  4.2  the set's two-shot spot: you come up off the fire escape to Nina at the ledge          (who)
--   C  9.0  over your shoulder on Nina, her phone up                                               (the evidence)
--   D 16.0  close on Nina (the set's close-up spot)                                                (the truth)
--   E 21.8  close on you                                                                            (YOU)
--   F 24.6  close on Nina, tighter                                                                  (Dre, the 52s)
--   G 32.4  wide two-shot against the skyline: your phone buzzes                                   (Patel)
-- Set: MTL_EndsRooftop on the Apartments roof (building thread). Anchor = the world; positions are marks from the
-- set's Anchors (Roof_* parts, prefix dropped) passed by StoryMissions. Defaults = the anchors as built 2026-11-03.
local V = Vector3.new

local function m(name: string, off: Vector3?): any
	return { mark = name, off = off }
end

return {
	id = "Rooftop",
	length = 41.0,
	skippable = true,
	fadeIn = 1.2,
	dof = true,
	ambience = "City",
	music = "WelcomeMusic",
	musicVolume = 0.2,
	marks = {
		Nina_AtLedge = V(-1413.0, 37.6, -64.2),
		Player_FacingNina = V(-1418.6, 37.6, -64.2),
		Cam_SkylineTwoShot = V(-1426.6, 40.1, -58.7),
		Cam_NinaCloseUp = V(-1416.8, 39.2, -63.5),
		Cam_Skyline = V(-1412.1, 40.6, -64.2),
		FireEscape_Bottom = V(-1463.1, 5.0, -70.7),
	},
	stream = { "#Nina_AtLedge", m("Cam_Skyline", V(120, 0, -20)) },
	placePlayer = { at = m("FireEscape_Bottom", V(0, 0, 5)), face = m("FireEscape_Bottom", V(0, 0, 20)) },
	actors = {
		Nina = { rig = "Nina", at = "#Nina_AtLedge", face = m("Nina_AtLedge", V(10, 0, -1)) }, -- looking out at the city
		Player = { rig = "@player", at = m("Player_FacingNina", V(-13, 0, 1.5)), face = "#Player_FacingNina" },
	},
	shots = {
		-- A: the skyline alone (from just past Nina, looking out), a slow lateral drift
		{ t = 0, from = { pos = m("Cam_Skyline", V(1, 0.4, 2)), look = m("Cam_Skyline", V(80, 10, -15)) }, to = { pos = m("Cam_Skyline", V(1, 0.6, -1)), look = m("Cam_Skyline", V(80, 10, -17)) }, dur = 4.2, fov = 50, blur = 0.05, safe = false },
		-- B: the two-shot spot: you walk up, the skyline behind her
		{ t = 4.2, from = { pos = "#Cam_SkylineTwoShot", look = m("Nina_AtLedge", V(-2.5, 1.2, 0)) }, to = { pos = m("Cam_SkylineTwoShot", V(1.2, -0.2, -0.4)), look = m("Nina_AtLedge", V(-2.6, 1.2, 0)) }, dur = 4.8, fov = 46, blur = 0.2, safe = false },
		-- C: over your shoulder on Nina and her phone
		{ t = 9.0, from = { ots = { "Player", "Nina" }, dist = 3.8, side = 2.6 }, to = { ots = { "Player", "Nina" }, dist = 3.3, side = 2.6 }, dur = 7.0, fov = 42, blur = 0.45, safe = false },
		-- D: the close-up spot on Nina
		{ t = 16.0, from = { pos = "#Cam_NinaCloseUp", look = m("Nina_AtLedge", V(0, 1.5, 0)) }, to = { pos = m("Cam_NinaCloseUp", V(0.6, 0, 0)), look = m("Nina_AtLedge", V(0, 1.5, 0)) }, dur = 5.8, fov = 36, ease = "Sine", focus = "Nina", blur = 0.55, safe = false },
		-- E: close on you
		{ t = 21.8, from = { close = "Player", dist = 9.4, side = 1 }, to = { close = "Player", dist = 8.3, side = 1 }, dur = 2.8, fov = 38, ease = "Quad", blur = 0.55, safe = false },
		-- F: Nina, tighter
		{ t = 24.6, from = { close = "Nina", dist = 7.9, side = -0.6 }, to = { close = "Nina", dist = 6.7, side = -0.6 }, dur = 7.8, fov = 34, ease = "Sine", blur = 0.6, safe = false },
		-- G: the wide two-shot against the skyline; your phone
		{ t = 32.4, from = { pos = m("Cam_SkylineTwoShot", V(-1.2, 0.4, 1.4)), look = m("Nina_AtLedge", V(-2.8, 1.4, 0)) }, to = { pos = m("Cam_SkylineTwoShot", V(-2.4, 0.8, 2.6)), look = m("Nina_AtLedge", V(-2.8, 1.6, 0)) }, dur = 8.6, fov = 48, blur = 0.2, safe = false },
	},
	lines = {
		{ t = 5.0, who = "Nina", text = "Took you long enough.", dur = 2.2 },
		{ t = 7.6, who = "Nina", text = "I took a picture at Royce's. Look.", dur = 2.8 },
		{ t = 10.6, who = "Nina", text = "His map. Patel's corner. And a date.", dur = 2.8 },
		{ t = 13.6, who = "Nina", text = "The day before we hit the store.", dur = 2.6 },
		{ t = 16.4, who = "Nina", text = "Royce doesn't rob stores.", dur = 2.2 },
		{ t = 18.8, who = "Nina", text = "He buys them after somebody else does.", dur = 2.8 },
		{ t = 22.0, who = "You", text = "So the job was never Dre's.", dur = 2.4 },
		{ t = 24.8, who = "Nina", text = "Dre owes him. For his little brother's funeral.", dur = 3.4 },
		{ t = 28.6, who = "Nina", text = "And the 52s keep finding us. Guess who tells them.", dur = 3.6 },
		{ t = 34.2, who = "You", text = "Patel. Texting at this hour.", dur = 2.4 },
		{ t = 37.0, who = "Nina", text = "Go. He's gonna need somebody.", dur = 2.6 },
	},
	actions = {
		{ t = 4.4, actor = "Player", walk = "#Player_FacingNina", dur = 4.4, ease = "QuadOut" },
		{ t = 6.4, actor = "Nina", turn = "#Player_FacingNina", dur = 0.8 },
		{ t = 7.8, actor = "Nina", pose = "Phone" },
		{ t = 9.0, actor = "Player", turn = "#Nina_AtLedge", dur = 0.3 },
		{ t = 15.6, actor = "Nina", pose = "None" },
		{ t = 16.6, actor = "Nina", gesture = "Open", dur = 1.6 },
		{ t = 22.2, actor = "Player", gesture = "Shrug", dur = 1.2 },
		{ t = 25.0, actor = "Nina", turn = m("Nina_AtLedge", V(10, 0, -1)), dur = 1.2 }, -- back to the city
		{ t = 32.6, sound = "PhoneVibrate" },
		{ t = 33.0, actor = "Player", pose = "Phone" },
		{ t = 33.3, sound = "PhoneMessage", volume = 0.4 },
		{ t = 36.6, actor = "Player", pose = "None" },
		{ t = 37.2, actor = "Nina", turn = "#Player_FacingNina", dur = 0.6 },
		{ t = 37.4, actor = "Nina", gesture = "Nod", dur = 1.2 },
		{ t = 39.6, fade = "out", dur = 1.2 },
	},
}
