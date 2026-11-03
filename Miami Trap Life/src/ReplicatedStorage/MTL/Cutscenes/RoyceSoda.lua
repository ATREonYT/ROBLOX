--!strict
-- Act 2.1 "Back of the House", part 2 (Story Bible §3, §4): you're on the till; Lionel Royce buys a mango soda with a
-- $100 bill and leaves his card for Patel. ~31 s, skippable. The man is polite, generous, and that's the threat.
-- Shot plan:
--   A  0.0  from behind the counter: the doors slide open, a cream suit walks in and heads for the coolers  (who)
--   B  5.0  CUT ON THE ELLIPSIS: he's at the counter with the soda; over your shoulder on him              (the ask)
--   C  8.6  reverse, over his shoulder on you                                                             (you, small)
--   D 12.0  medium on Royce, the $100 bill                                                                (the gift)
--   E 16.4  close, slow push: "I'll remember."                                                            (the hook)
--   F 19.2  side two-shot across the counter: the card                                                     (the message)
--   G 22.6  insert on the card; he leaves out of focus behind it, the bell                                 (read it)
--   H 26.0  close on you: the YOU thought; fade                                                            (the button)
-- Anchor = StoryWelcome.storeAnchor() (same layout as FirstDay): the counter at local x -17, the till side at
-- local x -21, the customer side at local x -14, the glass doors at local z -6.3.
local V = Vector3.new

local TILL = V(-21, 0, -13.2) -- you, behind the counter (where Patel stood on your first day)
local COUNTER = V(-14.4, 0, -11.6) -- Royce, across from you
local AISLE = V(-8, 0, -18) -- where he heads first (the coolers), off camera at the cut
local DOOR_OUT = V(0, 0, -2.2)
local DOOR_IN = V(0, 0, -9.5)
local CARD = CFrame.new(-16.5, 0, -10.9) * CFrame.Angles(0, math.rad(-12), 0)
local CARD_HIDDEN = CARD * CFrame.new(0, -1.6, 0) -- inside the counter until he puts it down

local function doors(t: number, open: boolean, dur: number): { any }
	return {
		{ t = t, prop = "DoorA", move = CFrame.new(if open then -4.15 else -1.42, 0, -6.3), dur = dur, ease = "Quad" },
		{ t = t, prop = "DoorB", move = CFrame.new(if open then 4.15 else 1.42, 0, -6.3) * CFrame.Angles(0, math.pi, 0), dur = dur, ease = "Quad" },
	}
end

local actions = {
	-- he walks up, the doors part, the bell; in, a glance down the aisles, off toward the coolers
	{ t = 0.2, actor = "Royce", walk = DOOR_OUT, dur = 1.8, ease = "QuadOut" },
	{ t = 0.65, sound = "StoreBell", volume = 0.45 },
	{ t = 2.1, actor = "Royce", walk = DOOR_IN, dur = 1.5 },
	{ t = 3.7, actor = "Royce", walk = AISLE, dur = 1.25 },
	{ t = 1.0, actor = "Player", turn = DOOR_IN, dur = 0.6 },
	-- the cut: he's back at the counter, soda in hand
	{ t = 5.0, actor = "Royce", walk = COUNTER, dur = 0.02 },
	{ t = 5.0, actor = "Royce", hold = "Soda" },
	{ t = 5.03, actor = "Royce", turn = TILL, dur = 0.02 },
	{ t = 5.0, actor = "Player", turn = COUNTER, dur = 0.02 },
	{ t = 9.2, actor = "Player", gesture = "Nod", dur = 1.0 },
	{ t = 10.2, actor = "Royce", gesture = "Open", dur = 1.4 },
	-- the bill
	{ t = 12.1, actor = "Royce", hold = "Bill" },
	{ t = 12.3, actor = "Royce", gesture = "Give", dur = 1.2 },
	{ t = 13.5, actor = "Royce", hold = "Soda" },
	{ t = 13.5, actor = "Player", hold = "Bill" },
	{ t = 14.4, actor = "Player", gesture = "Shrug", dur = 1.2 }, -- "I can't take this"
	{ t = 15.6, actor = "Player", hold = false },
	-- the card goes down on the counter
	{ t = 19.6, actor = "Royce", hold = "Card" },
	{ t = 20.2, actor = "Royce", gesture = "Give", dur = 1.0 },
	{ t = 21.1, actor = "Royce", hold = "Soda" },
	{ t = 21.1, prop = "Card", move = CARD, dur = 0.01 },
	-- and he leaves the way he came
	{ t = 22.9, actor = "Royce", walk = DOOR_IN, dur = 2.4 },
	{ t = 25.4, actor = "Royce", walk = V(0, 0, 4), dur = 1.9 },
	{ t = 25.7, sound = "StoreBell", volume = 0.35 },
	{ t = 26.2, actor = "Player", turn = DOOR_IN, dur = 0.8 },
	{ t = 29.8, fade = "out", dur = 1.2 },
}
for _, a in doors(0.6, true, 0.6) do
	table.insert(actions, a)
end
for _, a in doors(4.0, false, 0.9) do
	table.insert(actions, a)
end
for _, a in doors(24.6, true, 0.6) do
	table.insert(actions, a)
end
for _, a in doors(27.6, false, 0.9) do
	table.insert(actions, a)
end
table.insert(actions, 1, { t = 0, prop = "Card", move = CARD_HIDDEN, dur = 0.01 })
table.sort(actions, function(a, b)
	return a.t < b.t
end)

return {
	id = "RoyceSoda",
	length = 31.2,
	skippable = true,
	fadeIn = 0.8,
	dof = true,
	stream = { V(0, 0, -20) },
	placePlayer = { at = V(-11, 0, -14.5), face = V(0, 0, -6) }, -- in front of the counter, facing the door
	actors = {
		Royce = { rig = "Royce", at = V(0, 0, 7), face = DOOR_OUT },
		Player = { rig = "@player", at = TILL, face = V(-8, 0, -9) },
	},
	hideWorld = { { name = "AutoDoors", at = V(0, 4, -6.3), radius = 7 } },
	props = {
		DoorA = { prop = "GlassDoor", at = CFrame.new(-1.42, 0, -6.3) },
		DoorB = { prop = "GlassDoor", at = CFrame.new(1.42, 0, -6.3) * CFrame.Angles(0, math.pi, 0) },
		TabBook = { prop = "TabBook", at = CFrame.new(-17, 0, -12.4) * CFrame.Angles(0, math.rad(90), 0) },
		Photo = { prop = "DrePhoto", at = CFrame.new(-17.4, 0, -14.4) * CFrame.Angles(0, -math.pi / 2, 0) },
		Card = { prop = "BusinessCard", at = CARD },
	},
	shots = {
		-- A: from behind the counter, over the till, on the doors
		{ t = 0, from = { pos = V(-23.6, 6.3, -15.4), look = V(-1, 4, -6) }, to = { pos = V(-23.2, 6.2, -15.0), look = V(-4, 4, -10) }, dur = 5.0, fov = 50, blur = 0.2, safe = false },
		-- B: over your shoulder on Royce
		{ t = 5.0, from = { ots = { "Player", "Royce" }, dist = 4.0, side = 2.7 }, to = { ots = { "Player", "Royce" }, dist = 3.6, side = 2.7 }, dur = 3.6, fov = 46, blur = 0.4, safe = false },
		-- C: reverse, over his shoulder on you
		{ t = 8.6, from = { ots = { "Royce", "Player" }, dist = 4.0, side = -2.7 }, to = { ots = { "Royce", "Player" }, dist = 3.6, side = -2.7 }, dur = 3.4, fov = 46, blur = 0.4, safe = false },
		-- D: medium on Royce, the bill
		{ t = 12.0, from = { close = "Royce", dist = 11.5, side = -1 }, to = { close = "Royce", dist = 10.1, side = -1 }, dur = 4.4, fov = 40, ease = "Quad", blur = 0.45, safe = false },
		-- E: close, slow push
		{ t = 16.4, from = { close = "Royce", dist = 7.9, side = -0.6 }, to = { close = "Royce", dist = 6.7, side = -0.6 }, dur = 2.8, fov = 34, ease = "Sine", blur = 0.6, safe = false },
		-- F: side two-shot across the counter (the card goes down between you)
		{ t = 19.2, from = { two = { "Royce", "Player" }, dist = 10, side = 1, height = 1.0 }, to = { two = { "Royce", "Player" }, dist = 9.4, side = 1, height = 1.0 }, dur = 3.4, fov = 44, blur = 0.3, safe = false },
		-- G: insert on the card, the doors behind it out of focus
		{ t = 22.6, from = { pos = V(-15.6, 5.2, -9.6), look = V(-16.5, 2.75, -11.0) }, to = { pos = V(-15.8, 5.0, -9.9), look = V(-16.5, 2.75, -11.0) }, dur = 3.4, fov = 30, ease = "Sine", focus = V(-16.5, 2.75, -10.9), blur = 0.6, safe = false },
		-- H: close on you, looking after him
		{ t = 26.0, from = { close = "Player", dist = 10.1, side = 1 }, to = { close = "Player", dist = 8.6, side = 1 }, dur = 5.2, fov = 38, ease = "Quad", blur = 0.55, safe = false },
	},
	lines = {
		{ t = 5.4, who = "Royce", text = "Evening, young man. Just the soda.", dur = 2.9 },
		{ t = 8.8, who = "Royce", text = "Hemant has you on nights now? Good for him.", dur = 3.2 },
		{ t = 12.4, who = "Royce", text = "Keep the change.", dur = 1.8 },
		{ t = 14.4, who = "Royce", text = "No, really. Keep it.", dur = 1.9 },
		{ t = 16.6, who = "Royce", text = "I'll remember.", dur = 2.4 },
		{ t = 19.5, who = "Royce", text = "Give this to Hemant. He'll know what it means.", dur = 3.4 },
		{ t = 26.6, who = "You", text = "Richest man on the block. Tipped me a hundred on a soda.", dur = 3.9 },
	},
	actions = actions,
}
