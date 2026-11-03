--!strict
-- Royce Realty: every property is a real building on the map (vault: Desk Computer Empire §5). Bought from the PC.
--   kind:  "freight" (a warehouse: Freight app, cap = crates) · "stash" (The Re-Up, cap = packs) · "home" (a better
--          home with its own PC; PropertyService adds it as a homeId)
--   at:    the front door on the map (GPS + the property's sign and door prompt). Positions are the building's
--          street side, read from the map (Wynwood.Warehouse, Port.Warehouse, Hood.Apartments, Habana.Apartments).
--   needs: extra gates on top of level: path, own (another property), crates (Freight crates sold, all
--          warehouses), packs (Re-Up packs sold).
local Realty = {}

Realty.Order = { "EndsLockup", "StashHouse", "Habana", "WynwoodWarehouse", "SecondStash", "PortWarehouse", "Brickell", "StarIsland" }

Realty.Props = {
	EndsLockup = {
		title = "Ends Lockup",
		area = "The Ends",
		kind = "freight",
		price = 25000,
		level = 10,
		cap = 12,
		size = "2-bay garage · 600 sq ft",
		blurb = "A roller-door lockup behind the laundromat. Small, quiet, nobody asks what's in the boxes.",
		at = Vector3.new(-1180, 4, -300), -- TODO(map check): garage row in the Ends
	},
	StashHouse = {
		title = "Stash House",
		area = "The Ends",
		kind = "stash",
		price = 18000,
		level = 12,
		cap = 40,
		size = "Ground-floor unit · back door to the alley",
		blurb = "Bars on the windows, a back door to the alley and a landlord who only takes cash.",
		needs = { path = "Criminal" },
		at = Vector3.new(-1300, 25, -224),
	},
	Habana = {
		title = "Habana Apartment",
		area = "Little Habana",
		kind = "home",
		price = 60000,
		level = 15,
		size = "1 bed · balcony · desk nook",
		blurb = "Tiled floors, a balcony over Calle Ocho and a proper desk. Out of the Ends at last.",
		at = Vector3.new(-66, 6, 562),
	},
	WynwoodWarehouse = {
		title = "Wynwood Warehouse",
		area = "Wynwood",
		kind = "freight",
		price = 90000,
		level = 14,
		cap = 40,
		size = "Mural wall · loading dock · 4,000 sq ft",
		blurb = "Painted over twice a year by artists who don't know what's inside. A real loading dock.",
		needs = { crates = 20 },
		at = Vector3.new(-491, 17, -341),
	},
	SecondStash = {
		title = "Second Stash",
		area = "The Ends",
		kind = "stash",
		price = 45000,
		level = 16,
		cap = 60,
		size = "Upstairs unit · two exits",
		blurb = "A second base on the far side of the Ends. More room, more runners, more to lose.",
		needs = { path = "Criminal", own = "StashHouse", packs = 200 },
		at = Vector3.new(-1106, 23, -640),
	},
	PortWarehouse = {
		title = "Port Warehouse",
		area = "Port of Vice Bay",
		kind = "freight",
		price = 240000,
		level = 20,
		cap = 100,
		size = "Dockside · 12,000 sq ft · truck bay",
		blurb = "Right on the water. Containers come off the ship and straight through your doors.",
		needs = { crates = 100 },
		at = Vector3.new(-858, 15, 1024),
	},
	Brickell = {
		title = "Brickell Penthouse",
		area = "Brickell",
		kind = "home",
		price = 400000,
		level = 25,
		size = "Top floor · city view · office",
		blurb = "Floor-to-ceiling glass, a dual-screen office and a view of everything you own.",
		at = Vector3.new(800, 8, -328), -- TODO(map check): downtown tower door
	},
	StarIsland = {
		title = "Star Island Estate",
		area = "Star Island",
		kind = "home",
		price = 2500000,
		level = 40,
		size = "Waterfront mansion · garage · pool",
		blurb = "The one in the music videos. Gates, a garage for the collection and an office with a view.",
		at = Vector3.new(0, 0, 0), -- TODO(map check): pick a VBInteriors mansion and its lot
	},
}

Realty.XP = 150 -- per purchase (2x pass applies)
Realty.SignHeight = 14 -- the "ROYCE REALTY · SOLD" sign over owned doors

return Realty
