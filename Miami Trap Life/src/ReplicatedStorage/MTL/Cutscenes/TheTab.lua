--!strict
-- Act 2.7 "The Tab", part 2 (Story Bible §4): the Food Mart counter, late, the tab book open. Patel is $3,000 behind
-- and meets Royce on Monday. The act's big choice (Choice.Tab). ~38 s plus the card, skippable up to the card.
-- Shot plan:
--   A  0.0  wide from the aisle: the store empty at night, Patel alone at the book; you come in       (where)
--   B  6.2  over your shoulder on Patel                                                              (he's fine)
--   C  9.6  close on Patel                                                                            (he's not fine)
--   D 13.4  INSERT: the tab book                                                                      (the question)
--   CHOICE 16.8: "Tell him the truth." / "Pay it, say nothing. ($3,000)" / "It's not my problem."
--   E 16.8  close on Patel for the answer          F 21.4  side two-shot across the counter
--   G 25.4  the book again                         H 29.2  close on Patel
--   I 33.2  from outside the glass: the lit store at night, "END OF CHAPTER 2"
-- "pay" costs $3,000: StoryMissions takes it after the scene (Config/Chapters.ChoiceEffects); short of cash, the
-- pick isn't saved and you come back later. Anchor = StoryWelcome.storeAnchor() (same layout as FirstDay).
local V = Vector3.new

local TILL = V(-21, 0, -13.5) -- Patel
local COUNTER = V(-14.4, 0, -11.6) -- you
local DOOR_OUT = V(0, 0, -2.2)
local DOOR_IN = V(0, 0, -9.5)

local function doors(list: { any }, t: number, open: boolean, dur: number)
	table.insert(list, { t = t, prop = "DoorA", move = CFrame.new(if open then -4.15 else -1.42, 0, -6.3), dur = dur, ease = "Quad" })
	table.insert(list, { t = t, prop = "DoorB", move = CFrame.new(if open then 4.15 else 1.42, 0, -6.3) * CFrame.Angles(0, math.pi, 0), dur = dur, ease = "Quad" })
end

local actions = {
	{ t = 0.2, actor = "Player", walk = DOOR_OUT, dur = 1.8, ease = "QuadOut" },
	{ t = 0.65, sound = "StoreBell", volume = 0.4 },
	{ t = 2.1, actor = "Player", walk = DOOR_IN, dur = 1.5 },
	{ t = 3.7, actor = "Player", walk = COUNTER, dur = 2.5, ease = "QuadOut" },
	{ t = 0.4, actor = "Patel", gesture = "Count", dur = 3.0 }, -- going over the book, again
	{ t = 4.2, actor = "Patel", turn = V(-8, 0, -9), dur = 0.8 },
	{ t = 6.3, actor = "Patel", turn = COUNTER, dur = 0.4 },
	{ t = 6.6, actor = "Patel", gesture = "Open", dur = 1.6 },
	{ t = 13.0, actor = "Patel", gesture = "Laugh", dur = 1.4 }, -- too cheerful
	-- truth
	{ t = 17.2, actor = "Patel", gesture = "Nod", dur = 1.6, when = "truth" }, -- a long silence, then he nods
	{ t = 22.0, actor = "Patel", gesture = "Point", dur = 1.2, when = "truth" }, -- at your shoes
	{ t = 26.0, actor = "Patel", gesture = "Point", dur = 1.6, when = "truth" }, -- at the book
	{ t = 29.6, actor = "Patel", gesture = "Open", dur = 1.6, when = "truth" },
	{ t = 30.0, actor = "Player", gesture = "Nod", dur = 1.2, when = "truth" },
	-- pay
	{ t = 19.6, actor = "Patel", gesture = "Open", dur = 1.4, when = "pay" },
	{ t = 20.2, actor = "Player", gesture = "Nod", dur = 1.0, when = "pay" },
	{ t = 22.0, actor = "Player", hold = "Envelope", when = "pay" },
	-- walk
	{ t = 19.6, actor = "Patel", gesture = "Shrug", dur = 1.4, when = "walk" },
	{ t = 21.6, actor = "Patel", gesture = "Count", dur = 4.0, when = "walk" }, -- back to the book
	{ t = 33.4, title = "END OF CHAPTER 2", sub = "The Tab", dur = 3.6 },
	{ t = 36.6, fade = "out", dur = 1.0 },
}
doors(actions, 0.6, true, 0.6)
doors(actions, 4.0, false, 0.9)
table.sort(actions, function(a, b)
	return a.t < b.t
end)

return {
	id = "TheTab",
	length = 37.6,
	skippable = true,
	fadeIn = 1.0,
	dof = true,
	stream = { V(0, 0, -20) },
	placePlayer = { at = V(-11, 0, -14.5), face = V(0, 0, -6) },
	actors = {
		Patel = { rig = "Patel", at = TILL, face = V(-17, 0, -12.4) }, -- looking down at the book
		Player = { rig = "@player", at = V(0, 0, 7), face = DOOR_OUT },
	},
	hideWorld = { { name = "AutoDoors", at = V(0, 4, -6.3), radius = 7 } },
	props = {
		DoorA = { prop = "GlassDoor", at = CFrame.new(-1.42, 0, -6.3) },
		DoorB = { prop = "GlassDoor", at = CFrame.new(1.42, 0, -6.3) * CFrame.Angles(0, math.pi, 0) },
		TabBook = { prop = "TabBook", at = CFrame.new(-17, 0, -12.4) * CFrame.Angles(0, math.rad(90), 0) },
		Photo = { prop = "DrePhoto", at = CFrame.new(-17.4, 0, -14.4) * CFrame.Angles(0, -math.pi / 2, 0) },
		Card = { prop = "BusinessCard", at = CFrame.new(-17.6, 0, -11.0) * CFrame.Angles(0, math.rad(20), 0) }, -- Royce's card, still there
	},
	choice = {
		t = 16.8,
		prompt = "What do you tell him?",
		options = {
			{ id = "truth", text = "Tell him the truth." },
			{ id = "pay", text = "Pay it, say nothing. ($3,000)" },
			{ id = "walk", text = "It's not my problem." },
		},
		default = "truth",
	},
	shots = {
		-- A: wide from down the aisle: the empty store, Patel at the book, the doors
		{ t = 0, from = { pos = V(-9, 6.8, -24), look = V(-12, 3.6, -8) }, to = { pos = V(-9.6, 6.5, -22.6), look = V(-13, 3.6, -9) }, dur = 6.2, fov = 52, blur = 0.15, safe = false },
		-- B: over your shoulder on Patel
		{ t = 6.2, from = { ots = { "Player", "Patel" }, dist = 4.0, side = 2.7 }, to = { ots = { "Player", "Patel" }, dist = 3.6, side = 2.7 }, dur = 3.4, fov = 46, blur = 0.4, safe = false },
		-- C: close on Patel
		{ t = 9.6, from = { close = "Patel", dist = 10.1, side = -1 }, to = { close = "Patel", dist = 8.3, side = -1 }, dur = 3.8, fov = 38, ease = "Quad", blur = 0.5, safe = false },
		-- D: insert, the tab book (Royce's card beside it)
		{ t = 13.4, from = { pos = V(-13.6, 6.2, -10.6), look = V(-17, 2.7, -12.2) }, to = { pos = V(-13.9, 5.9, -11.2), look = V(-17, 2.7, -12.4) }, dur = 3.4, fov = 34, ease = "Sine", focus = V(-17, 2.7, -12.4), blur = 0.55, safe = false },
		-- E: after the card, close on Patel
		{ t = 16.8, from = { close = "Patel", dist = 9.0, side = -0.8 }, to = { close = "Patel", dist = 7.6, side = -0.8 }, dur = 4.6, fov = 36, ease = "Sine", blur = 0.55, safe = false },
		-- F: side two-shot across the counter
		{ t = 21.4, from = { two = { "Patel", "Player" }, dist = 10, side = 1, height = 1.0 }, to = { two = { "Patel", "Player" }, dist = 9.4, side = 1, height = 1.0 }, dur = 4.0, fov = 44, blur = 0.3, safe = false },
		-- G: the book again
		{ t = 25.4, from = { pos = V(-14.2, 5.6, -11.6), look = V(-17, 2.7, -12.4) }, to = { pos = V(-14.6, 5.4, -12.0), look = V(-17, 2.7, -12.4) }, dur = 3.8, fov = 32, ease = "Sine", focus = V(-17, 2.7, -12.4), blur = 0.6, safe = false },
		-- H: close on Patel
		{ t = 29.2, from = { close = "Patel", dist = 8.3, side = -0.6 }, to = { close = "Patel", dist = 7.0, side = -0.6 }, dur = 4.0, fov = 34, ease = "Sine", blur = 0.6, safe = false },
		-- I: from outside the glass, the lit store at night
		{ t = 33.2, from = { pos = V(3, 5.2, 6), look = V(-15, 4, -12) }, to = { pos = V(4.5, 5.6, 9), look = V(-15, 4, -12) }, dur = 4.4, fov = 46, blur = 0.15, safe = false },
	},
	lines = {
		{ t = 6.4, who = "Patel", text = "You came. At this hour. Good kid.", dur = 2.6 },
		{ t = 9.4, who = "Patel", text = "Supplier's done with me. Royce on Monday.", dur = 3.0 },
		{ t = 12.8, who = "Patel", text = "It's fine. Everybody is short some week.", dur = 3.0 },
		-- truth
		{ t = 19.6, who = "Patel", text = "I know.", dur = 1.8, when = "truth" },
		{ t = 21.8, who = "Patel", text = "I watched the tape the next morning. Your work shoes.", dur = 3.6, when = "truth" },
		{ t = 25.8, who = "Patel", text = "Fifteen hundred. Your name. Not marked paid.", dur = 3.2, when = "truth" },
		{ t = 29.4, who = "Patel", text = "You'll work it off. Mop's in the back.", dur = 3.2, when = "truth" },
		-- pay
		{ t = 19.4, who = "Patel", text = "Go home, kid. It's late.", dur = 2.3, when = "pay" },
		{ t = 22.2, who = "You", text = "Three grand in an envelope. Under his shutter tonight.", dur = 3.6, when = "pay" },
		{ t = 26.2, who = "You", text = "He'll never ask. I'll never say.", dur = 2.6, when = "pay" },
		{ t = 29.4, who = "Patel", text = "Goodnight. Thank you for coming by.", dur = 2.8, when = "pay" },
		-- walk
		{ t = 19.4, who = "Patel", text = "Okay. Okay.", dur = 1.8, when = "walk" },
		{ t = 21.6, who = "Patel", text = "Goodnight, then. Mind the step.", dur = 2.4, when = "walk" },
		{ t = 24.6, who = "You", text = "Not my problem. That's what I tell myself.", dur = 3.0, when = "walk" },
		{ t = 28.4, who = "You", text = "Monday he'll sign something. I won't be there.", dur = 3.2, when = "walk" },
	},
	actions = actions,
}
