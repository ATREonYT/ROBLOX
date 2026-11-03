--!strict
-- Stage 11 FirstNight -> 12 CommuteToWork: you go to sleep, "NEXT DAY", the phone alarm wakes you (~10 s, skippable).
-- Sit on the bed -> the bulb dies -> the window at night -> black + "NEXT DAY · 6:58 AM" -> morning light through the
-- boards -> alarm -> stretch -> stand up. Then the boss's text arrives and the commute funnel starts.
-- LOCAL to the room's origin, using the room's marks (see PowerOut.lua). Defaults = Config/Property.Interior.Points.
local Property = require(script.Parent.Parent.Config.Property)

local V = Vector3.new
local function M(name: string, off: Vector3?): any
	return { mark = name, off = off }
end

return {
	id = "NextDay",
	length = 10.4,
	skippable = true,
	holdBlack = false,
	fadeIn = 0.6,
	-- no hour / grade: scenes keep the world's own lighting (Alex: "the lighting changes during the cutscenes")
	dof = true,
	marks = Property.Interior.Points,
	actors = {
		Player = { rig = "@player", at = "#BedSpot", face = M("BedSpot", V(-5, 0, 0)), pose = "SitSlump" },
	},
	shots = {
		{ t = 0, from = { pos = M("BedSpot", V(-5, 3.4, 3)), look = M("BedSpot", V(0, 2.2, 0)) }, to = { pos = M("BedSpot", V(-4.4, 3.2, 2.6)), look = M("BedSpot", V(0, 2.2, 0)) }, dur = 2.8, fov = 50 },
		{ t = 2.8, from = { pos = M("Window", V(-1.5, -1.5, 6)), look = "#Window" }, to = { pos = M("Window", V(-1.2, -1.4, 5.2)), look = "#Window" }, dur = 2.6, fov = 45, blur = 0.5 },
		{ t = 5.4, from = { pos = M("BedSpot", V(-4.2, 3.1, 2.4)), look = M("BedSpot", V(0, 2.3, 0)) }, to = { pos = M("BedSpot", V(-3.6, 3, 2)), look = M("BedSpot", V(0, 2.4, 0)) }, dur = 5, fov = 48 },
	},
	lines = {
		{ t = 0.5, who = "You", text = "Long day.", dur = 1.8 },
		{ t = 7.4, who = "You", text = "Day one. Let's go.", dur = 2.2 },
	},
	actions = {
		{ t = 0.9, actor = "Player", gesture = "Flop", dur = 0.8 },
		{ t = 1.9, call = "BulbOff" },
		{ t = 2.6, fade = "out", dur = 1.0 },
		{ t = 3.8, title = "NEXT DAY", sub = "6:58 AM", dur = 2.2 },
		{ t = 5.25, call = "WorldMorning" }, -- LightingController: this player's sky jumps to 7 AM behind the black
		{ t = 5.3, call = "MorningLight" },
		{ t = 5.6, fade = "in", dur = 1.0 },
		{ t = 5.9, sound = "Alarm" },
		{ t = 6.5, actor = "Player", gesture = "Stretch", dur = 1.6 },
		{ t = 8.5, actor = "Player", pose = "None" },
		{ t = 8.6, actor = "Player", walk = "#BedStand", dur = 1.2 },
	},
}
