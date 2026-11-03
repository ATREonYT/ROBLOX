--!strict
-- Act 2.2 "Kev Knows" (Story Bible §4): 1 a.m. behind the Food Mart, by the dumpster. Kev is on his break, holding
-- the keys to a car he doesn't have any more. He knows it was you. ~44 s, skippable, with a choice card (Choice.Kev1).
-- Shot plan:
--   A  0.0  wide from down the alley: Kev under the door light, you walk up                       (where, who)
--   B  5.0  over your shoulder on Kev: the joke                                                  (Kev's voice)
--   C  8.4  medium on Kev: "I know it was you"                                                    (the turn)
--   D 10.8  INSERT, low on your shoes                                                            (the evidence)
--   E 14.0  close on you                                                                          (YOU)
--   F 16.6  side two-shot, the dumpster between you and the street, slow drift                    (what he did)
--   G 23.8  over your shoulder on Kev, then tight on him: the suit, the car, the debt            (Royce, unnamed)
--   CHOICE 31.6: "I'll help you with Royce." / "You didn't see nothing. Keep it that way."
--   H 31.6  close on Kev for his answer                                                           (the cost)
--   I 38.0  wide: he goes back in to work; your thought; fade                                     (the button)
-- Anchor = CFrame.new(-1478, 2.3, -286) like BackOfHouse: the back doorway, +Z = out into the alley, +X = east.
local V = Vector3.new

local KEV = V(-4.4, 0, 1.6) -- against the back wall, beside the doorway, the dumpster to his left
local YOU = V(-1.2, 0, 4.2)

return {
	id = "KevKnows",
	length = 43.6,
	skippable = true,
	fadeIn = 1.0,
	dof = true,
	ambience = "City",
	stream = { V(0, 0, 8) },
	placePlayer = { at = V(3.5, 0, 5), face = V(20, 0, 5) },
	actors = {
		Kev = { rig = "Kev", at = KEV, face = V(6, 0, 7), pose = "Lean", hold = "Keys" },
		Player = { rig = "@player", at = V(16, 0, 4.6), face = V(0, 0, 4) },
	},
	choice = {
		t = 31.6,
		prompt = "Kev's waiting.",
		options = {
			{ id = "help", text = "I'll help you with Royce." },
			{ id = "quiet", text = "You didn't see nothing. Keep it that way." },
		},
		default = "help",
	},
	shots = {
		-- A: down the alley at Kev, a slow push as you walk into frame
		{ t = 0, from = { pos = V(24, 7.5, 8.5), look = V(-3, 3.2, 2.5) }, to = { pos = V(20, 6.8, 8), look = V(-3, 3.2, 2.5) }, dur = 5.0, fov = 50, blur = 0.15 },
		-- B: over your shoulder on Kev
		{ t = 5.0, from = { ots = { "Player", "Kev" }, dist = 4.0, side = -2.7 }, to = { ots = { "Player", "Kev" }, dist = 3.6, side = -2.7 }, dur = 3.4, fov = 46, blur = 0.4 },
		-- C: medium on Kev, a push on "I know it was you"
		{ t = 8.4, from = { close = "Kev", dist = 11.2, side = 1 }, to = { close = "Kev", dist = 8.6, side = 1 }, dur = 2.4, fov = 40, ease = "Quad", blur = 0.5 },
		-- D: insert, low on your shoes
		{ t = 10.8, from = { pos = YOU + V(2.2, 0.7, 2.4), look = YOU + V(0, 0.5, 0) }, to = { pos = YOU + V(1.9, 0.6, 2.0), look = YOU + V(0, 0.45, 0) }, dur = 3.2, fov = 40, focus = YOU + V(0, 0.5, 0), blur = 0.6, safe = false },
		-- E: close on you
		{ t = 14.0, from = { close = "Player", dist = 9.4, side = -1 }, to = { close = "Player", dist = 8.3, side = -1 }, dur = 2.6, fov = 38, ease = "Quad", blur = 0.55 },
		-- F: side two-shot from across the alley, drifting
		{ t = 16.6, from = { pos = V(-1.4, 4.6, 14), look = V(-2.8, 3.4, 2.6) }, to = { pos = V(-3.4, 4.4, 13.4), look = V(-2.8, 3.4, 2.6) }, dur = 7.2, fov = 44, blur = 0.3 },
		-- G: over your shoulder, then tight on Kev
		{ t = 23.8, from = { ots = { "Player", "Kev" }, dist = 3.8, side = -2.5 }, to = { ots = { "Player", "Kev" }, dist = 3.4, side = -2.5 }, dur = 3.8, fov = 44, blur = 0.45 },
		{ t = 27.6, from = { close = "Kev", dist = 7.9, side = 0.6 }, to = { close = "Kev", dist = 6.8, side = 0.6 }, dur = 4.0, fov = 34, ease = "Sine", blur = 0.6 },
		-- H: his answer (the clock holds at 31.6 while the card is up, so this shot starts as the card closes)
		{ t = 31.6, from = { close = "Kev", dist = 9.7, side = 1 }, to = { close = "Kev", dist = 8.3, side = 1 }, dur = 6.4, fov = 38, ease = "Quad", blur = 0.5 },
		-- I: wide, he goes back to work
		{ t = 38.0, from = { pos = V(10, 5.2, 9.5), look = V(-2, 3.4, 1.5) }, to = { pos = V(11, 5.4, 10.5), look = V(-1, 3.4, 1) }, dur = 5.6, fov = 46, blur = 0.25 },
	},
	lines = {
		{ t = 5.2, who = "Kev", text = "Break room's out here. Best view in Liberty.", dur = 3.0 },
		{ t = 8.6, who = "Kev", text = "I know it was you, man.", dur = 2.1 },
		{ t = 11.0, who = "Kev", text = "The shoes. You wore your work shoes.", dur = 2.8 },
		{ t = 14.2, who = "You", text = "Of course it was the shoes.", dur = 2.3 },
		{ t = 16.8, who = "Kev", text = "I didn't tell Patel. Didn't tell the cops.", dur = 3.1 },
		{ t = 20.2, who = "Kev", text = "Guy in a nice suit said insurance would cover it.", dur = 3.4 },
		{ t = 24.0, who = "Kev", text = "Said keep my mouth shut. Then he brought up my car.", dur = 3.4 },
		{ t = 27.8, who = "Kev", text = "Car's gone. Debt ain't. Nine hundred by Friday.", dur = 3.5 },
		-- help
		{ t = 32.0, who = "Kev", text = "For real? Okay. Okay.", dur = 2.2, when = "help" },
		{ t = 34.6, who = "Kev", text = "I didn't say nothing. You're welcome. Also, you owe me.", dur = 3.6, when = "help" },
		{ t = 38.6, who = "You", text = "Now there's two of us in that man's book.", dur = 3.2, when = "help" },
		-- quiet
		{ t = 32.0, who = "Kev", text = "...Yeah. Sure.", dur = 2.0, when = "quiet" },
		{ t = 34.4, who = "Kev", text = "I didn't see nothing. I never see nothing.", dur = 3.2, when = "quiet" },
		{ t = 38.4, who = "You", text = "He'll remember this. Everybody around here does.", dur = 3.4, when = "quiet" },
	},
	actions = {
		{ t = 0.6, actor = "Player", walk = YOU, dur = 4.4, ease = "QuadOut" },
		{ t = 4.0, actor = "Kev", pose = "None" }, -- off the wall as you get close
		{ t = 5.1, actor = "Player", turn = KEV, dur = 0.4 },
		{ t = 5.4, actor = "Kev", gesture = "Open", dur = 1.6 },
		{ t = 11.2, actor = "Kev", gesture = "Point", dur = 1.4 }, -- at your feet
		{ t = 14.4, actor = "Player", gesture = "Shrug", dur = 1.2 },
		{ t = 20.6, actor = "Kev", gesture = "Shrug", dur = 1.4 },
		{ t = 28.2, actor = "Kev", gesture = "Open", dur = 1.8 },
		{ t = 32.2, actor = "Kev", gesture = "Laugh", dur = 1.8, when = "help" },
		{ t = 32.2, actor = "Kev", gesture = "Nod", dur = 1.4, when = "quiet" },
		{ t = 34.6, actor = "Kev", pose = "Lean", when = "quiet" }, -- back against the wall, done talking
		{ t = 35.0, actor = "Kev", gesture = "Point", dur = 1.2, when = "help" },
		{ t = 38.8, actor = "Kev", pose = "None" },
		{ t = 39.0, actor = "Kev", walk = V(-1, 0, 0.6), dur = 1.4 },
		{ t = 39.4, actor = "Player", turn = V(-1, 0, -2), dur = 0.8 },
		{ t = 40.4, actor = "Kev", walk = V(0, 0, -4), dur = 1.6 },
		{ t = 40.6, actor = "Kev", hold = false },
		{ t = 42.2, fade = "out", dur = 1.2 },
	},
}
