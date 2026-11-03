--!strict
-- Live, server-wide reasons to move around the hood (Quality pass, Benchmark Gap List 2.7, 2.8, 2.10).
-- No Robux anywhere in here and nothing you can pay for a chance at: everything is found, raced for or sold.
--
--   Cache    Ms. Bea hides her lucky cookie tin somewhere in the hood every day (same spot for everyone, new spot
--            at midnight UTC). Her morning text says where, in her own words. Opening it gives 2x JOB pay for
--            15 minutes (shifts only; crime, sales and story rewards are untouched). Once per player per day.
--   Airdrop  Every 12 minutes a Liberty Relief crate drops on a parachute at one of the open lots. Everyone gets
--            a 60 s heads-up and a marker; the crate pops red flare smoke when it lands. First player to hold
--            E for 5 s gets the cash (and sometimes a cheap crime tool). Gone after 4 minutes if nobody opens it.
--   Pawn     Liberty Pawn & Thrift buys the goods you carry home from house licks for clean cash at 60% of what
--            Marcus pays dirty (CrimeService.fenceValue / takeFence), and buys crime tools back at 35%.
local Live = {}

Live.Cache = {
	contact = "Bea", -- Story.Contacts.Bea
	boostMultiplier = 2, -- job pay
	boostSeconds = 15 * 60,
	xp = 25,
	holdSeconds = 1.2,
	-- the spot is picked per UTC day with Random.new(day) so every server agrees
	spots = {
		{ id = "CarOnBlocks", at = Vector3.new(-1276.7, 2.13, -268.8), clue = "Baby, I left my lucky tin by that poor car somebody put up on blocks off 58th. Whoever finds it gets my luck today 🍀" },
		{ id = "CrateHoop", at = Vector3.new(-1526.9, 2.25, -263.8), clue = "Morning sugar. My tin is in the alley where the kids shoot at that milk-crate hoop. Go on and find it 🍀" },
		{ id = "BBQ", at = Vector3.new(-1598.8, 2.17, -544.7), clue = "I hid my lucky tin by the grill out back on the 66th alley. Don't let Junior eat it 😂🍀" },
		{ id = "Domino", at = Vector3.new(-1454.8, 2.00, -537.8), clue = "The tin's under the tree by the domino table today. The old men won't notice, they never do 🍀" },
		{ id = "YardSale", at = Vector3.new(-1324.1, 2.91, -161.4), clue = "Look by the yard sale table up on Liberty Ave. My tin ain't for sale though 😉🍀" },
		{ id = "Park", at = Vector3.new(-1557.2, 6.00, -179.7), clue = "My lucky tin is in the flower bed by the basketball court in Liberty Park. Mind that dog sign 🐕🍀" },
	},
	texts = {
		found = "You found it! Spend that luck wisely, baby. Double pay on your shift for 15 minutes 💙",
		already = "You already got my luck today. Come back tomorrow, I'll hide it somewhere new.",
	},
}

Live.Airdrop = {
	firstAfter = 4 * 60, -- seconds after the server starts
	every = 12 * 60,
	warnSeconds = 60, -- heads-up before it lands
	fallSeconds = 14, -- parachute time (it starts falling at warn - fall)
	dropHeight = 140,
	holdSeconds = 5,
	stayMinutes = 4,
	minPlayers = 1,
	cash = { 180, 320 },
	xp = 40,
	toolChance = 0.25, -- one cheap crime tool (crime thread: never the Drill); paid as cash if you have it
	tools = { "SlimJim", "Crowbar" },
	toolCashValue = 120,
	-- open, flat, off-road lots (checked by raycast in Studio 2026-11-03)
	spots = {
		{ id = "Court", label = "Liberty Park court", at = Vector3.new(-1595, 6.0, -214) },
		{ id = "CarLot", label = "the used car lot on Liberty Blvd", at = Vector3.new(-1290, 6.0, -621) },
		{ id = "MartLot", label = "the Food Mart lot", at = Vector3.new(-1445, 2.0, -345) },
		{ id = "Abandoned", label = "the yard of the boarded-up house", at = Vector3.new(-1515, 6.0, -572) },
		{ id = "CanalYard", label = "the yard by the canal", at = Vector3.new(-1141, 6.0, -598) },
	},
}

Live.Pawn = {
	title = "Liberty Pawn & Thrift",
	at = Vector3.new(-1084.5, 2.0, -867.5), -- on the pavement in front of the door (store sign renamed in MTL_HoodLife)
	goodsRate = 0.60, -- of Marcus's (dirty) price, paid clean
	toolRate = 0.35, -- of the tool's shop price
	sellCooldown = 0.6,
}

return Live
