--!strict
-- Stage 1 (Arrive), first join only: the welcome (~26.6 s, skippable). Data only: CutsceneController plays it.
-- Built against Research: Cinematic Cutscenes. Shot plan (wide -> medium -> close -> hand-off):
--   A  0.0  aerial crane over the Ends down to Liberty Food Mart, game title       (establishing, high = "small, new")
--   B  6.4  street level by the curb, slow dolly, store sign in the distance          (where we are)
--   C 10.8  low tracking shot: the player walks in from the boulevard                  (who)
--   D 15.4  CUT ON THE BUZZ: close-up, phone out, Mr. Patel's text                     (the hook: you have a job)
--   E 19.6  over the shoulder toward the store door, dolly in                          (the goal)
--   F 23.4  the camera glides into the gameplay camera behind the real player, "CHAPTER 1" (hand-off, no snap)
-- Coordinates are LOCAL to the anchor: StoryWelcome sends CFrame.new(Locations.Spawn) (no rotation), so local =
-- world minus the spawn (-1432, 3, -368). The Food Mart door is at local (-10, 0, 38); north = -Z.
local V = Vector3.new
local GameInfo = require(script.Parent.Parent.Config.Game)

local DOOR = V(-10, 0, 38)
local STAND = V(-3, 0, 12) -- where the player ends up (and the real character waits, hidden)
local FROM = V(24, 0, -4) -- walks in from the boulevard side

return {
	id = "Welcome",
	length = 26.6,
	skippable = true,
	fadeIn = 1.2,
	-- no hour / grade: scenes keep the world's own lighting (Alex: "the lighting changes during the cutscenes")
	dof = true,
	music = "WelcomeMusic", -- Theme.Cutscene.Sounds ("" = silent until Alex sends a track)
	musicVolume = 0.4,
	ambience = "City",
	stream = { DOOR, V(60, 0, -120), V(-40, 0, 80) },
	placePlayer = { at = STAND, face = DOOR },
	actors = {
		Player = { rig = "@player", at = FROM, face = STAND },
	},
	shots = {
		-- A: aerial crane down along a spline (no corners), looking at the store front
		{
			t = 0,
			from = { path = { V(170, 165, -250), V(110, 110, -170), V(55, 62, -100), V(22, 30, -52) }, lookPath = { V(-14, 0, 26), V(-13, 2, 29), V(-12, 4, 31), V(-11, 6, 33) } }, -- the lot in front of the door (never inside a building)
			dur = 6.4,
			fov = 55,
			fovTo = 50,
			blur = 0.08,
			safe = false, -- high above the roofs: no wall check (it would pull the camera into the store)
		},
		-- B: street level, low by the curb, slow sideways dolly; the store sign far away
		{ t = 6.4, from = { pos = V(15, 2.2, -11), look = V(-12, 7, 30) }, to = { pos = V(8, 2.6, -7), look = V(-12, 7, 30) }, dur = 4.4, fov = 54, blur = 0.15 }, -- low 3/4 view of the store, slow dolly (not straight-on)
		-- C: low tracking shot while the player walks in (camera leads the walk)
		{ t = 10.8, from = { pos = V(12, 2.2, 14), look = "Player" }, to = { pos = V(3, 2.6, 22), look = "Player" }, dur = 4.6, fov = 46, blur = 0.3 },
		-- D: close-up on the buzz (cut on action), slow push
		{ t = 15.4, from = { close = "Player", dist = 8, side = 1 }, to = { close = "Player", dist = 7, side = 1 }, dur = 4.2, fov = 34, ease = "Quad", blur = 0.5 }, -- medium close: face AND the phone in hand
		-- E: over the shoulder toward the store door, dolly in
		{ t = 19.6, from = { pos = V(-4.0, 5.7, 7.0), look = V(-12, 7, 34) }, to = { pos = V(-3.9, 5.5, 8.4), look = V(-12, 7, 34) }, dur = 3.8, fov = 50, focus = V(-11, 6, 38), blur = 0.25 },
		-- F: glide into the gameplay camera behind the real player (Research §5: hand-off)
		{ t = 23.4, from = { pos = V(-3.9, 5.5, 8.4), look = V(-12, 7, 34) }, to = { gameplay = true }, dur = 3.2, fov = 50, fovTo = 70, ease = "Cubic", blur = 0.1 },
	},
	lines = {
		{ t = 7.0, who = "You", text = "Fifty bucks and a phone. That's the whole plan.", dur = 3.4 },
		{ t = 11.6, who = "You", text = "No job. No crib. Nobody knows my name.", dur = 3.2 },
		{ t = 16.2, who = "Patel", text = "Hey, it's Mr. Patel from Liberty Food Mart. You start today!", dur = 4.0 }, -- the SAME words as his real text (PhoneStory), so nothing reads twice in different words
		{ t = 20.3, who = "You", text = "Stocking shelves. Everybody starts somewhere.", dur = 3.2 },
	},
	actions = {
		{ t = 1.2, title = string.upper(GameInfo.Title), sub = "Vice Bay, Florida", dur = 4.2 },
		{ t = 10.8, actor = "Player", walk = STAND, dur = 4.8 },
		{ t = 15.4, sound = "PhoneVibrate" },
		{ t = 15.6, actor = "Player", turn = DOOR, dur = 0.5 },
		{ t = 15.7, actor = "Player", pose = "Phone" },
		{ t = 16.0, sound = "PhoneMessage", volume = 0.4 },
		{ t = 19.4, actor = "Player", pose = "None" },
		{ t = 20.4, actor = "Player", gesture = "Nod", dur = 1.0 },
		{ t = 23.6, title = "CHAPTER 1", sub = "New in Town", dur = 2.8 },
	},
}
