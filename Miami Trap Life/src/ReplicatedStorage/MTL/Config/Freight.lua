--!strict
-- Freight: grey-market imports (sneakers, phones, designer bags) run from a warehouse (vault §7.3, GTA Special
-- Cargo shape: buy small, sell big). Works on either path. Warehouses are Realty props of kind "freight".
local Freight = {}

-- Sourcing: crates per run and the price per crate (GTA's 1-3 crate runs; bigger runs cost a bit more each).
Freight.Source = {
	[1] = 300,
	[2] = 350,
	[3] = 400,
}
Freight.SourceMax = 3

-- Pickup: the Plug's container yard at the Port of Vice Bay (HUD marker at -700, 4, 1110). Several spots so
-- players in the same server don't stack. TODO(map check): put them on the container yard's ground.
Freight.Pickups = {
	Vector3.new(-712, 4, 1096),
	Vector3.new(-688, 4, 1124),
	Vector3.new(-726, 4, 1132),
	Vector3.new(-672, 4, 1090),
}
Freight.LoadSeconds = 1.6 -- per crate, holding the prompt at the container ("Load crate")
Freight.UnloadSeconds = 1.0 -- per crate at the warehouse door

-- Selling: price per crate grows with the size of the sale (the whole point of filling the warehouse).
Freight.SellCurve = { -- { crates, $ each } interpolated linearly between points
	{ 1, 650 },
	{ 12, 800 },
	{ 40, 1000 },
	{ 100, 1250 },
}
-- How many drops a sale needs: 1-11 crates one drop, 12-39 two, 40+ three.
Freight.Drops = { { 1, 1 }, { 12, 2 }, { 40, 3 } }
-- Buyer drop spots (TODO(map check): the curb by each place).
Freight.Buyers = {
	{ name = "Brickell valet", at = Vector3.new(820, 8, -300) },
	{ name = "Airport cargo gate", at = Vector3.new(-1400, 4, 900) },
	{ name = "SoHo boutique", at = Vector3.new(300, 6, 120) },
	{ name = "Star Island dock", at = Vector3.new(1100, 4, 600) },
	{ name = "Suncoast Freight", at = Vector3.new(-1150, 4, 1110) },
}
Freight.HandSeconds = 2.0 -- "Hand over" prompt at each drop

Freight.JobMinutes = 12 -- a run or a sale left this long is cancelled (sourced crates are lost, unsold stay)
Freight.XP = { Sourced = 40, Sold = 25 } -- per crate (2x pass applies)

-- Upgrades bought in the Freight app (per warehouse).
Freight.Upgrades = {
	Sourcer = { title = "Hire a sourcer", price = 20000, level = 16, blurb = "Brings in 1 crate every 6 min while you're online.", every = 360 },
	Security = { title = "Security", price = 30000, level = 14, blurb = "Halves the chance of a raid on your stock." },
}

-- Raids: when you come back after being away, each full day a warehouse sat at 80%+ has a 10% chance to have
-- lost 10% of its stock (halved by Security). Shown as an email.
Freight.Raid = { Full = 0.8, Chance = 0.10, Lose = 0.10 }

return Freight
