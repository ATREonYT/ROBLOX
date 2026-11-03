--!strict
-- Stage 9 MoveIn: the first time you walk into your flat (~16 s, skippable). The comedy beat from the brief:
-- walk in (handheld, flickering bulb) -> sit at the PC -> press power: nothing -> close-up on the dead screen, hold
-- (the pause is the joke) -> press again: nothing -> keyboard smash (3 hits + shake) -> silence -> stand, flop
-- onto the bed -> phone out -> the Jobs app opens straight after (the ChooseJob funnel).
-- Positions are LOCAL to the room's origin and use MARKS (named points of this player's room, sent by
-- PropertyService), so the scene still lines up when Alex's real room replaces the placeholder.
-- Defaults = Config/Property.Interior.Points.
local Property = require(script.Parent.Parent.Config.Property)

local V = Vector3.new
local function M(name: string, off: Vector3?): any
	return { mark = name, off = off }
end

return {
	id = "PowerOut",
	length = 16.2,
	skippable = true,
	holdBlack = false, -- ends on gameplay: the real you is already sitting on the bed, phone coming up
	fadeIn = 0.5,
	-- no hour / grade: scenes keep the world's own lighting (Alex: "the lighting changes during the cutscenes")
	dof = true,
	ambience = "RoomTone",
	marks = Property.Interior.Points,
	actors = {
		Player = { rig = "@player", at = "#Entry", face = M("Entry", V(0, 0, -6)) },
	},
	shots = {
		-- 1. walk in: handheld from the corner by the door
		{ t = 0, from = { pos = M("Entry", V(4.5, 5.5, 2.4)), look = M("ChairSpot", V(0, 2.5, 0)) }, to = { pos = M("Entry", V(3.6, 5, 1.8)), look = M("ChairSpot", V(0, 2.5, 0)) }, dur = 3.3, fov = 62, handheld = 0.05 },
		-- 2. over the shoulder at the PC: press power
		{ t = 3.3, from = { pos = M("ChairSpot", V(2.4, 5.2, 4.4)), look = "#Screen" }, to = { pos = M("ChairSpot", V(2.0, 5.0, 3.8)), look = "#Screen" }, dur = 2.3, fov = 52, blur = 0.3 }, -- high over the shoulder: you + the dead screen in one frame
		-- 3. the dead screen. Hold. Push in. (the joke is the wait)
		{ t = 5.6, from = { pos = M("Screen", V(0.4, 0.15, 2.6)), look = "#Screen" }, dur = 1.8, fov = 40, fovTo = 33, ease = "Quad", blur = 0.6 },
		-- 4. keyboard smash, from the side, handheld
		{ t = 7.4, from = { pos = M("ChairSpot", V(4.2, 2.9, -0.6)), look = M("ChairSpot", V(0, 2.4, -1.2)) }, dur = 1.8, fov = 46, handheld = 0.07 },
		-- 5. wide and quiet: get up, flop on the bed
		{ t = 9.2, from = { pos = M("Entry", V(3.5, 5.8, 1.5)), look = M("BedSpot", V(-4, 2.4, 0)) }, to = { pos = M("Entry", V(3, 5.4, 0.6)), look = M("BedSpot", V(-2.5, 2.4, 0)) }, dur = 3.3, fov = 58 },
		-- 6. close on you with the phone
		{ t = 12.5, from = { pos = M("BedSpot", V(-3.8, 2.6, 1.6)), look = M("BedSpot", V(0, 2.2, 0)) }, to = { pos = M("BedSpot", V(-3, 2.5, 1.2)), look = M("BedSpot", V(0, 2.2, 0)) }, dur = 3.7, fov = 44, blur = 0.5 },
	},
	lines = {
		{ t = 0.7, who = "You", text = "Home sweet home.", dur = 2.2 },
		{ t = 6.5, who = "You", text = "Come on. Come ON.", dur = 1.8 },
		{ t = 10.0, who = "You", text = "No power. Of course there's no power.", dur = 2.8 },
		{ t = 13.3, who = "You", text = "Fine. Guess I'm getting a job.", dur = 2.6 },
	},
	actions = {
		{ t = 0.1, actor = "Player", walk = M("ChairSpot", V(1.4, 0, 1)), dur = 2.7 },
		{ t = 0.3, call = "BulbFlicker", dur = 2.6 },
		{ t = 2.9, actor = "Player", walk = "#ChairSpot", dur = 0.45 },
		{ t = 3.2, actor = "Player", turn = "#Screen", dur = 0.35 },
		{ t = 3.4, actor = "Player", pose = "SitType" },
		{ t = 4.1, actor = "Player", gesture = "Press", dur = 0.8 },
		{ t = 4.35, sound = "Click" },
		{ t = 4.36, call = "PcPower" },
		{ t = 6.0, actor = "Player", gesture = "Press", dur = 0.7 },
		{ t = 6.2, sound = "Click" },
		{ t = 6.21, call = "PcPower" },
		{ t = 7.5, actor = "Player", gesture = "Smash", dur = 1.5 },
		{ t = 7.55, sound = "Keys" },
		{ t = 7.56, call = "KeyboardBounce" },
		{ t = 7.57, shake = 0.3, dur = 0.25 },
		{ t = 7.95, sound = "Keys" },
		{ t = 7.96, call = "KeyboardBounce" },
		{ t = 7.97, shake = 0.35, dur = 0.25 },
		{ t = 8.35, sound = "Keys", volume = 0.8 },
		{ t = 8.36, call = "KeyboardBounce" },
		{ t = 8.37, shake = 0.45, dur = 0.3 },
		{ t = 9.7, actor = "Player", pose = "None" },
		{ t = 9.8, actor = "Player", walk = M("BedSpot", V(-1.6, 0, 1.2)), dur = 1.8 },
		{ t = 11.65, actor = "Player", walk = "#BedSpot", dur = 0.35 },
		{ t = 11.9, actor = "Player", turn = M("BedSpot", V(-5, 0, 0)), dur = 0.3 },
		{ t = 12.1, actor = "Player", pose = "SitSlump" },
		{ t = 12.1, actor = "Player", gesture = "Flop", dur = 0.8 },
		{ t = 12.15, sound = "BedCreak" },
		{ t = 12.9, actor = "Player", pose = "SitPhone" },
		{ t = 12.95, call = "PhoneOut" },
	},
}
