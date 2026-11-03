--!strict
-- The Re-Up: packs logistics, Criminal path only (vault §7.4). Plain brown packs and duffels in the world; never
-- named as a substance anywhere (Roblox rules). Every dollar it makes is dirty cash (CrimeService.addDirty), so
-- players still have to wash it at Liberty Laundromat.
local V = Vector3.new

local ReUp = {}

-- Re-up orders from the PC: packs of raw stock, cheaper per pack in bulk (clean cash).
ReUp.Orders = {
	{ n = 10, each = 70 },
	{ n = 25, each = 60 },
	{ n = 50, each = 50 },
}
-- The Plug's container at the docks (TODO(map check): the container yard's far end, out of the Freight spots).
ReUp.Plug = V(-760, 4, 1150)
ReUp.GrabSeconds = 2.0
ReUp.GrabHeat = { chance = 0.25, stars = 1 } -- the pickup can draw a star

-- Packing up at the stash: one round of the "release" minigame seals a batch.
ReUp.Batch = 5 -- raw -> packs per round
ReUp.Mini = { kind = "release", verb = "Seal", seconds = 2.2, band = { 0.72, 0.84 }, low = "Light", high = "Torn" }
ReUp.MiniMin = 1.2 -- server minimum seconds per round
ReUp.Waste = 0.3 -- below this score one raw pack is wasted
ReUp.Perfect = 0.9 -- at or above: +XP bonus
ReUp.XP = { Pack = 6, Perfect = 10, Order = 30, Sold = 3, Bulk = 120 } -- 2x pass applies

-- Upgrades per stash (bought in the app).
ReUp.Upgrades = {
	Crew = { title = "Pack-up crew", price = 8000, level = 14, blurb = "Seals 1 pack every 20 s while you're online.", every = 20 },
	Lookout = { title = "Lookout", price = 6000, level = 13, blurb = "Earlier raid warnings and half the raid chance." },
}

-- Corners: real street corners in the Ends and on NW 52nd. TODO(map check): stand points on each curb.
ReUp.Corners = {
	{ id = "FifthAndMain", title = "5th & Main", at = V(-1240, 4, -260), pay = 120, turf = "Ends" },
	{ id = "Laundromat", title = "Behind the laundromat", at = V(-1180, 4, -330), pay = 115, turf = "Ends" },
	{ id = "CanalBridge", title = "Canal bridge", at = V(-1060, 4, -520), pay = 125, turf = "Ends" },
	{ id = "FiftySecond", title = "NW 52nd St", at = V(-900, 4, -720), pay = 150, turf = "52s" },
}
-- How many corners you can run: { level, corners }.
ReUp.CornerSlots = { { 15, 1 }, { 18, 2 }, { 22, 3 }, { 28, 4 } }
ReUp.Runner = { min = 45, max = 75, cut = 0.15, heatPerSale = 0.04 } -- sells 1 pack every 45-75 s; 15% to the runner
ReUp.HeatDecay = 0.01 -- per 10 s tick, each corner cools off

-- Bulk buyer (Level 18): wants 25+ packs at $135 each, at a meet on the map.
ReUp.Bulk = { level = 18, min = 25, each = 135, meets = { { name = "Sunset Motel lot", at = V(-980, 4, 260) }, { name = "Under the canal bridge", at = V(-1070, 2, -540) } } }

-- Raids: a stash holding 30+ packs gets a roll every 10 min; chance grows with the heat on its corners.
ReUp.Raid = { min = 30, every = 600, base = 0.08, heat = 0.25, warn = 60, warnLookout = 120, lose = 0.5 }

ReUp.JobMinutes = 12

return ReUp
