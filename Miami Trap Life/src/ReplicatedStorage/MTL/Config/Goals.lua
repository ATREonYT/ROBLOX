--!strict
-- FreePlay goals (Master Plan §1 stage 13): the "what do I do now?" list in the phone's Goals app. The top goal
-- that isn't done also sits on the HUD objective line, so a free-play player always sees one next step.
-- Rules/GoalRules evaluates them from the save snapshot (same answer on the server and in the app).
--
-- kind (what "done" means; GoalRules.check):
--   power   the home's power is on (Home.PowerOn)
--   shifts  `count` finished shifts at your current job (Job.Shifts[Job.Current])
--   level   reach Level `level`
--   cash    have `amount` cash at once
--   guns    own `count` guns (Inventory.Guns)
--   soon    not in the game yet: shown greyed with "Coming soon", never the top goal (kid-safe: no fake content)
-- path = "Criminal" / "Civilian": only shown on that path. action = the button on the card:
--   { kind = "payPower" } | { kind = "route", place = <Config/Phone.Places id> | "@job" } | { kind = "app", app }
-- reward = XP given once when the goal is first done (EconomyService.addXP, so 2x XP applies). Order = priority:
-- FreePlay starts the moment you clock in at your new job, so "finish this shift" comes first, then the power bill.
local Economy = require(script.Parent.Economy)

local Goals = {}

Goals.List = {
	{
		id = "FirstShift",
		kind = "shifts",
		count = 1,
		title = "Finish a full shift",
		sub = "Work all the tasks of one shift at your job.",
		action = { kind = "route", place = "@job", label = "Route to work" },
		reward = 80,
	},
	{
		id = "Power",
		kind = "power",
		title = "Turn the power on",
		sub = "Pay the power bill. Your PC might finally work.",
		amount = Economy.PowerBill,
		action = { kind = "payPower", label = "Pay $" .. tostring(Economy.PowerBill) },
		reward = 60,
	},
	{
		id = "Level8",
		kind = "level",
		level = 8,
		title = "Reach Level 8",
		sub = "Laid-back jobs open up: Cashier, Car Wash, Valet.",
		action = { kind = "app", app = "Jobs", label = "Open Jobs" },
		reward = 100,
	},
	{
		id = "Save5k",
		kind = "cash",
		amount = 5000,
		title = "Save up $5,000",
		sub = "Enough for a car, once the dealer opens.",
		reward = 120,
	},
	{
		id = "SecondGun",
		kind = "guns",
		count = 2,
		path = "Criminal",
		title = "Get a second piece",
		sub = "The Plug sells guns and ammo. Criminal life only.",
		action = { kind = "app", app = "Plug", label = "Open Plug" },
		reward = 100,
	},
	{
		id = "Level15",
		kind = "level",
		level = 15,
		title = "Reach Level 15",
		sub = "AFK-friendly jobs open up: Security, Trucker, Dockworker.",
		action = { kind = "app", app = "Jobs", label = "Open Jobs" },
		reward = 150,
	},
	{
		id = "FirstCar",
		kind = "car",
		amount = 2500, -- the cheapest dealer car (Config/Vehicles: Cruiser '99)
		title = "Buy your first car",
		sub = "The dealer is in the Garage app. Cheapest ride: $2,500.",
		action = { kind = "app", app = "Garage", args = { tab = "Dealer" }, label = "Open dealer" },
		reward = 250,
	},
	{ id = "NextJob", kind = "soon", path = "Criminal", title = "Dre's next job", sub = "The Liberty Lows will call when they have work." },
	{ id = "MoveOut", kind = "soon", title = "Get out of the Ends", sub = "Better places to live come in a later update." },
}

Goals.ObjectivePrefix = "Goal: " -- HUD objective line in FreePlay: "Goal: Turn the power on ($120 / $300)"

return Goals
