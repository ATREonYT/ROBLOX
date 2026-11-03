--!strict
-- Every job, task, station and job number in the game (Master Plan §4 "Jobs"). Tune here only.
-- Research: "Jobs, Leveling and RP Game Feel". Pure data: shared by JobService (server), JobController (client),
-- the Jobs phone app and the unit tests (tools/tests/test_job_rules.py checks the balance targets).
--
-- HOW A JOB WORKS
--   kind = "tasks": the server hands out one task at a time. A task is 1-3 steps; each step happens at a STATION
--                   (a spot in the world). Step kinds:
--                     pickup  : press the prompt, you now carry `carry` (a prop in your hands, slower walk)
--                     drop    : press the prompt where it goes (ends the carry)
--                     press   : press the prompt (no carry)
--                     hold    : minigame, hold the button while the bar fills (`seconds`). Let go early = it drains
--                     timing  : minigame, press when the needle is in the green (`hits` times)
--                     sequence: minigame, tap `count` items in the order shown (picked from `pool`)
--                   `gap = {min, max}` (optional) = seconds of waiting between tasks: the semi-AFK jobs.
--                   Minigame steps can name `action` (a looping body pose in the client's ActionPose, e.g. "Mop")
--                   and `tool` (a model in ReplicatedStorage.MTL_JobProps.Tools put in the right hand while it runs).
--   kind = "post":  stand inside the post zone and get paid per minute. Every `checkInEvery` seconds a
--                   "Still on post?" card appears; pay pauses (never a kick) until it's answered.
--
-- STATIONS (where steps happen). Resolved by the server in this order:
--   1. a part in Workspace.MTL_Stations.<JobId>.<StationId> (Map thread / Alex drag these into place;
--      run tools/PlaceJobStations.lua once in the Command Bar to create them at the defaults below)
--   2. `pos` (absolute) or `offset` from the job site's centre (Config/Locations[site].Inside, or the map's
--      JobSpot part for this job, see `mapJob`). PLACEHOLDER positions until the map has real ones.
--   `prop` = which placeholder prop the client draws there while the station has no real map part.
local Locations = require(script.Parent.Locations)

local Jobs = {}

---------------------------------------------------------------- global tuning

Jobs.StoryJob = "Supermarket" -- the FirstShift job (Master Plan §1 stage 2)
Jobs.StarterJobs = { "Supermarket", "Mechanic", "Restaurant" } -- the 3 cards on the ChooseJob stage
Jobs.ChooseFromStage = "ChooseJob" -- players pick their own job from this stage on (before: the story job)
-- No clocking in during these stages (the robbery, cutscenes, moving in). Entering one ends the shift.
Jobs.BlockedStages = { GangIntro = true, FirstMission = true, MoveIn = true, FirstNight = true }

Jobs.Shift = {
	Tasks = 8, -- tasks per shift (task jobs)
	PostTicks = 16, -- pay ticks per shift (post jobs): 16 x 30 s = 8 minutes
	BonusLevel = 3, -- shift bonus unlocks at this level (Config/Levels.Unlocks[3])
	BonusShare = 0.25, -- +25% of what the shift earned
	BigBonusLevel = 10,
	BigBonusShare = 0.5, -- +50% from Level 10
}

Jobs.Quality = {
	Perfect = 0.95, -- score >= this: "PERFECT" (+25% pay and XP from PerfectBonusLevel: "tips")
	PerfectBonus = 0.25,
	PerfectBonusLevel = 5, -- Config/Levels.Unlocks[5]
	Good = 0.6, -- score below this: "Sloppy" -20%
	SloppyPenalty = 0.2,
}

-- Level perks (each one is a Config/Levels.Unlocks line, so every early level-up means something)
Jobs.PayRaises = { { level = 6, share = 0.10 }, { level = 9, share = 0.10 } } -- cumulative: +20% at Level 9
Jobs.RepeatWeight = 0.3 -- the task you just did comes back at 30% of its weight (never 3 in a row: JobRules.pickTask)
Jobs.QuickHandsLevel = 7 -- from this level, hold minigames take 15% less time
Jobs.QuickHandsScale = 0.85

-- What you carry between a pickup and a drop: a mesh prop held in your hands (everyone sees it), posed by the
-- client's ActionPose controller. The look comes from ReplicatedStorage.MTL_JobProps.Carry.<kind> (a Model whose
-- pivot is its centre); size/colour/material below only shape the invisible anchor part (and the fallback look
-- if the model is missing).
--   attach  "Torso" (UpperTorso) or "RightHand": the part the prop is welded to
--   at      the prop centre relative to that part
--   pose    ActionPose static pose: Hug (both hands, in front), Tray, Side (hanging from the hand), Hand
Jobs.Carry = {
	WalkSpeed = 14, -- walk speed while carrying (walk 16, sprint 24 is off while carrying). Was 12: the bag -> dumpster
	-- trip was 4-5 s of dead walking in the first shift (play-test 2026-11-02); 14 still reads as "this is heavy"
	Props = {
		Box = { size = Vector3.new(1.55, 1.55, 1.55), color = Color3.fromRGB(176, 132, 84), material = Enum.Material.Cardboard, attach = "Torso", at = CFrame.new(0, -0.55, -1.25), pose = "Hug" },
		Bag = { size = Vector3.new(1.5, 1.7, 1.5), color = Color3.fromRGB(30, 30, 34), attach = "RightHand", at = CFrame.new(0, -0.95, 0), pose = "Side" },
		Tire = { size = Vector3.new(2.2, 2.2, 0.65), color = Color3.fromRGB(28, 28, 30), attach = "Torso", at = CFrame.new(0, -0.45, -1.45), pose = "Hug" },
		Tray = { size = Vector3.new(2, 0.2, 1.33), color = Color3.fromRGB(200, 60, 50), attach = "Torso", at = CFrame.new(0, -0.45, -1.5), pose = "Tray" },
		Keys = { size = Vector3.new(0.25, 0.16, 0.55), color = Color3.fromRGB(255, 205, 80), material = Enum.Material.Metal, attach = "RightHand", at = CFrame.new(0, -0.3, -0.05) * CFrame.Angles(math.rad(90), 0, 0), pose = "Hand" },
		Crate = { size = Vector3.new(1.9, 1.85, 1.9), color = Color3.fromRGB(150, 110, 70), material = Enum.Material.WoodPlanks, attach = "Torso", at = CFrame.new(0, -0.6, -1.45), pose = "Hug" },
	},
}

-- Server-side checks (anti-exploit). Generous enough that lag never fails an honest player.
Jobs.Validation = {
	StationSlack = 6, -- studs beyond a station's radius still accepted
	MinPromptSeconds = 0.2, -- a step can't finish faster than this after the previous one
	HoldTolerance = 0.75, -- a hold must last at least this share of its seconds (server clock)
	TimingMinPerHit = 0.3, -- seconds per needed hit, minimum
	SequenceMinPerItem = 0.25, -- seconds per item, minimum
	ClockInRadius = 45, -- studs from the site centre or the time clock where clocking in works
	LeaveRadius = 90, -- studs from the job site: further than this starts the "you left work" countdown
	LeaveGrace = 15, -- seconds to get back before the shift ends
	RatePerSecond = 6, -- JobAction rate limit
}

Jobs.Post = {
	PayEvery = 30, -- seconds between pay ticks on post jobs
	CheckInEvery = 120, -- "Still on post?" every 2 minutes (pay pauses until answered, no kick)
}

---------------------------------------------------------------- jobs
-- tier 1 = interactive (Level 1), tier 2 = semi-AFK (Level 8), tier 3 = AFK-able (Level 15)
-- `site` = key in Config/Locations (centre = .Inside or .Door). `place` = Config/Phone.Places id for the GPS.
-- `boss` = who texts you about this job (Config/Story.Contacts). `mapJob` = names of the map's JobSpot `Job`
-- attribute that mean this job (the server then uses that part as the site centre).

Jobs.Order = { "Supermarket", "Mechanic", "Restaurant", "Cashier", "CarWash", "Valet", "Security", "Trucker", "Dockworker" }

Jobs.Defs = {
	Supermarket = {
		title = "Liberty Food Mart",
		role = "Stocker",
		blurb = "Restock shelves, mop spills, take the trash out.",
		tier = 1,
		level = 1,
		kind = "tasks",
		site = "FoodMart",
		place = "FoodMart",
		boss = "Patel",
		tasks = { "Restock", "Mop", "Trash", "PriceGun" },
		stations = {
			TimeClock = { offset = Vector3.new(-6, 0, -12), radius = 8, prop = "TimeClock" },
			Stockroom = { offset = Vector3.new(0, 0, 16), radius = 7, prop = "Boxes" },
			Shelf1 = { offset = Vector3.new(-10, 0, -4), radius = 6, prop = "Shelf" },
			Shelf2 = { offset = Vector3.new(-10, 0, 6), radius = 6, prop = "Shelf" },
			Shelf3 = { offset = Vector3.new(10, 0, -4), radius = 6, prop = "Shelf" },
			Shelf4 = { offset = Vector3.new(10, 0, 6), radius = 6, prop = "Shelf" },
			Floor1 = { offset = Vector3.new(0, 0, -6), radius = 6 },
			Floor2 = { offset = Vector3.new(-4, 0, 4), radius = 6 },
			Floor3 = { offset = Vector3.new(5, 0, 10), radius = 6 },
			Bin1 = { offset = Vector3.new(8, 0, -12), radius = 6, prop = "Bin" },
			Bin2 = { offset = Vector3.new(-12, 0, 12), radius = 6, prop = "Bin" },
			Dumpster = { offset = Vector3.new(20, 0, 24), radius = 8, prop = "Dumpster" },
		},
	},
	Mechanic = {
		title = "Westside Auto Repair",
		role = "Mechanic",
		blurb = "Swap tires, change oil, wash cars.",
		tier = 1,
		level = 1,
		kind = "tasks",
		site = "WestsideAuto",
		place = "WestsideAuto",
		boss = "Rico",
		tasks = { "TireSwap", "OilChange", "Detail" },
		stations = {
			TimeClock = { offset = Vector3.new(-10, 0, 8), radius = 8, prop = "TimeClock" },
			TireRack = { offset = Vector3.new(-14, 0, -4), radius = 7, prop = "TireRack" },
			Bay1 = { offset = Vector3.new(0, 0, -6), radius = 8, prop = "Car" },
			Bay2 = { offset = Vector3.new(12, 0, -6), radius = 8, prop = "Car" },
			WashBay = { offset = Vector3.new(6, 0, 12), radius = 8, prop = "Car" },
		},
	},
	Restaurant = {
		title = "Burger Shack",
		role = "Cook",
		blurb = "Grill patties, build orders, serve tables.",
		tier = 1,
		level = 1,
		kind = "tasks",
		site = "BurgerShack",
		place = "BurgerShack",
		boss = "Tasha",
		tasks = { "Grill", "BuildOrder", "Serve", "MopShack" },
		stations = {
			TimeClock = { offset = Vector3.new(8, 0, 10), radius = 8, prop = "TimeClock" },
			Grill = { offset = Vector3.new(-8, 0, -8), radius = 6, prop = "Grill" },
			Prep = { offset = Vector3.new(0, 0, -8), radius = 6, prop = "Counter" },
			Pass = { offset = Vector3.new(6, 0, -4), radius = 6, prop = "Counter" },
			Table1 = { offset = Vector3.new(-8, 0, 6), radius = 6, prop = "Table" },
			Table2 = { offset = Vector3.new(0, 0, 8), radius = 6, prop = "Table" },
			Table3 = { offset = Vector3.new(8, 0, 4), radius = 6, prop = "Table" },
			Floor1 = { offset = Vector3.new(-3, 0, 0), radius = 6 },
			Floor2 = { offset = Vector3.new(4, 0, 2), radius = 6 },
		},
	},

	-- tier 2: semi-AFK (one light task, then you wait for the next customer)
	Cashier = {
		title = "Liberty Food Mart",
		role = "Cashier",
		blurb = "Ring up customers at the register. Chill between them.",
		tier = 2,
		level = 8,
		kind = "tasks",
		gap = { 6, 12 },
		site = "FoodMart",
		place = "FoodMart",
		boss = "Patel",
		tasks = { "Checkout", "BagGroceries", "CountTill", "GumRack" },
		stations = {
			TimeClock = { offset = Vector3.new(-6, 0, -12), radius = 8, prop = "TimeClock" },
			Register = { offset = Vector3.new(6, 0, -12), radius = 7, prop = "Register" },
			Stockroom = { pos = Vector3.new(-1474, 4.65, -297), radius = 7 }, -- the Food Mart stockroom (Supermarket's station)
		},
	},
	CarWash = {
		title = "Bay Suds Car Wash",
		role = "Washer",
		blurb = "Cars roll in, you scrub them. Easy money.",
		tier = 2,
		level = 8,
		kind = "tasks",
		gap = { 7, 13 },
		site = "CarWash",
		place = "CarWash",
		mapJob = { "Car Wash", "CarWash", "Car Wash Attendant" }, -- the Sudz Car Wash tunnel in HoodWest
		tasks = { "WashCar", "Rinse", "DryBuff", "Vacuum", "TireShine" },
		stations = {
			TimeClock = { offset = Vector3.new(-8, 0, 0), radius = 8, prop = "TimeClock" },
			Lane = { offset = Vector3.new(4, 0, 0), radius = 9, prop = "Car" },
		},
	},
	Valet = {
		title = "Coral Hotel",
		role = "Valet",
		blurb = "Take the keys, park the car, keep the tip.",
		tier = 2,
		level = 8,
		kind = "tasks",
		gap = { 5, 10 },
		site = "Valet",
		place = "Valet",
		mapJob = { "Valet" },
		tasks = { "ParkCar", "FetchCar", "KeyBoard" },
		stations = {
			TimeClock = { offset = Vector3.new(0, 0, -4), radius = 8, prop = "TimeClock" },
			Stand = { offset = Vector3.new(0, 0, 0), radius = 7, prop = "Podium" },
			Spot1 = { offset = Vector3.new(-20, 0, 14), radius = 7 },
			Spot2 = { offset = Vector3.new(-10, 0, 18), radius = 7 },
			Spot3 = { offset = Vector3.new(10, 0, 18), radius = 7 },
			Spot4 = { offset = Vector3.new(20, 0, 14), radius = 7 },
		},
	},

	-- tier 3: AFK-able (stand on post, or long drives)
	Security = {
		title = "Bayside Mall",
		role = "Security Guard",
		blurb = "Stand your post. Check in when the radio buzzes.",
		tier = 3,
		level = 15,
		kind = "post",
		perMinute = 70,
		xpPerMinute = 30,
		site = "Security",
		place = "Security",
		mapJob = { "Security Guard", "Security" },
		stations = {
			TimeClock = { offset = Vector3.new(-6, 0, 0), radius = 8, prop = "TimeClock" },
			Post = { offset = Vector3.new(0, 0, 0), radius = 14, prop = "Post" },
		},
	},
	Trucker = {
		title = "Vice Bay Freight",
		role = "Trucker",
		blurb = "Load up at the depot, drop it across town. Longer runs pay more.",
		tier = 3,
		level = 15,
		kind = "tasks",
		site = "TruckDepot",
		place = "TruckDepot",
		mapJob = { "Trucker", "Truck Driver", "Delivery" },
		leaveRadius = math.huge, -- route job: driving away is the job
		tasks = { "Delivery", "PreTrip", "StrapLoad" },
		stations = {
			TimeClock = { offset = Vector3.new(-8, 0, 0), radius = 8, prop = "TimeClock" },
			Dock = { offset = Vector3.new(6, 0, 0), radius = 10, prop = "Crates" },
			Truck = { pos = Vector3.new(-1189, 2.3, 1105), radius = 9, prop = "Car" }, -- open asphalt on Port Rd by the dock
			-- Local drops, all on sidewalks 190-375 studs from the dock (checked in Studio 2026-11-02): there is no
			-- vehicle system yet, so runs are on foot. TODO(vehicles): a depot truck spawner, then the far drops below.
			DropPortShops = { pos = Vector3.new(-1189, 2.9, 929), radius = 12 }, -- Port Blvd shops
			DropLiberty = { pos = Vector3.new(-1401, 3, 909), radius = 12 }, -- Liberty Blvd shops
			DropWarehouse = { pos = Vector3.new(-904, 2.9, 1006), radius = 12 }, -- Railroad Ave warehouse
			DropCourt = { pos = Vector3.new(-1450, 2.9, 852), radius = 12 }, -- NW 11 St
			-- far drops (1.5-2k studs, only with a truck): not in the Delivery list for now
			DropFoodMart = { pos = Locations.FoodMart.Door, radius = 12 },
			DropShack = { pos = Locations.BurgerShack.Door, radius = 12 },
			DropAuto = { pos = Locations.WestsideAuto.Door, radius = 12 },
			DropMotel = { pos = Vector3.new(-1300, 3, -880), radius = 12 },
		},
	},
	Dockworker = {
		title = "Port of Vice Bay",
		role = "Dockworker",
		blurb = "Watch the crane, sign the manifests. The port pays well.",
		tier = 3,
		level = 15,
		kind = "post",
		perMinute = 80,
		xpPerMinute = 30,
		site = "Docks",
		place = "Docks",
		mapJob = { "Dockworker", "Docks", "Dock Worker" },
		stations = {
			TimeClock = { offset = Vector3.new(-6, 0, 0), radius = 8, prop = "TimeClock" },
			Post = { offset = Vector3.new(0, 0, 0), radius = 16, prop = "Post" },
		},
	},
}

---------------------------------------------------------------- tasks
-- pay/xp = per task, before multipliers. `weight` = how often it comes up. `level` = unlocks at.
-- `est` = rough seconds per task INCLUDING walking (only used by the balance test and the app's "/min" text).
-- `hint` = one coach line shown the first 2 times a player does this task.

Jobs.Tasks = {
	-- Liberty Food Mart (Stocker)
	Restock = {
		title = "Restock the shelves",
		pay = 8,
		xp = 22,
		weight = 3,
		est = 21,
		hint = "Grab a box in the stockroom, carry it to the glowing shelf, then hold to stack it.",
		steps = {
			{ kind = "pickup", at = { "Stockroom" }, prompt = "Grab box", text = "Grab a box from the stockroom", carry = "Box" },
			{ kind = "hold", at = { "Shelf1", "Shelf2", "Shelf3", "Shelf4" }, prompt = "Stock shelf", action = "Scan", text = "Stock the empty shelf", verb = "STOCKING", seconds = 3.5, fx = "ShelfFill" },
		},
	},
	Mop = {
		title = "Mop up a spill",
		pay = 8,
		xp = 20,
		weight = 2,
		est = 16,
		hint = "Hold to mop. Let go and the spill creeps back.",
		steps = {
			{ kind = "hold", at = { "Floor1", "Floor2", "Floor3" }, prompt = "Mop", action = "Mop", tool = "Mop", text = "Somebody dropped a soda. Mop it up", verb = "MOPPING", seconds = 4, fx = "Spill" },
		},
	},
	Trash = {
		title = "Take the trash out",
		pay = 9,
		xp = 24,
		weight = 2,
		est = 24,
		hint = "Pick up the full bag, walk it out back to the dumpster.",
		steps = {
			{ kind = "pickup", at = { "Bin1", "Bin2" }, prompt = "Grab bag", text = "Grab the full trash bag", carry = "Bag", fx = "Bag" },
			{ kind = "drop", at = { "Dumpster" }, prompt = "Toss bag", text = "Toss it in the dumpster out back", fx = "Slam" },
		},
	},
	PriceGun = {
		title = "Price-gun the new stock",
		level = 2,
		pay = 8,
		xp = 22,
		weight = 2,
		est = 15,
		hint = "Press when the needle is in the green. Three tags.",
		steps = {
			{ kind = "timing", at = { "Shelf1", "Shelf2", "Shelf3", "Shelf4" }, prompt = "Price items", action = "Spray", tool = "Scanner", text = "Tag the new stock with prices", verb = "TAG IT", hits = 3, zone = 0.24, speed = 0.9, fx = "PriceTag" },
		},
	},

	-- Westside Auto Repair (Mechanic)
	TireSwap = {
		title = "Swap a flat tire",
		pay = 11,
		xp = 26,
		weight = 3,
		est = 26,
		hint = "Grab a tire from the rack, then tighten the lug nuts when the needle hits green.",
		steps = {
			{ kind = "pickup", at = { "TireRack" }, prompt = "Grab tire", text = "Grab a fresh tire off the rack", carry = "Tire" },
			{ kind = "timing", at = { "Bay1", "Bay2" }, prompt = "Fit tire", action = "Crank", tool = "Wrench", text = "Fit it and tighten the lug nuts", verb = "TIGHTEN", hits = 4, zone = 0.22, speed = 1.0 },
		},
	},
	OilChange = {
		title = "Change the oil",
		pay = 10,
		xp = 24,
		weight = 2,
		est = 20,
		hint = "Do the steps in the order on the card.",
		steps = {
			{ kind = "sequence", at = { "Bay1", "Bay2" }, prompt = "Change oil", action = "Crank", tool = "Wrench", text = "Change the oil, steps in order", verb = "ORDER", count = 4, pool = { "Drain old oil", "Swap filter", "Pour new oil", "Check dipstick" }, keepOrder = true },
		},
	},
	Detail = {
		title = "Detail a car",
		pay = 10,
		xp = 22,
		weight = 2,
		est = 19,
		hint = "Hold to scrub. Let go and you lose some shine.",
		steps = {
			{ kind = "hold", at = { "WashBay" }, prompt = "Scrub", action = "Wipe", tool = "Sponge", text = "Scrub the car in the wash bay", verb = "SCRUBBING", seconds = 4.5, fx = "Suds" },
		},
	},

	-- Burger Shack (Cook)
	Grill = {
		title = "Grill a patty",
		pay = 9,
		xp = 22,
		weight = 3,
		est = 17,
		hint = "Hold to grill, then flip it when the needle's in the green.",
		steps = {
			{ kind = "hold", at = { "Grill" }, prompt = "Grill", action = "Flip", tool = "Spatula", text = "Get a patty on the grill", verb = "GRILLING", seconds = 3, fx = "Sizzle" },
			{ kind = "timing", at = { "Grill" }, prompt = "Flip", action = "Flip", tool = "Spatula", text = "Flip it", verb = "FLIP", hits = 2, zone = 0.26, speed = 1.0 },
		},
	},
	BuildOrder = {
		title = "Build an order",
		pay = 9,
		xp = 22,
		weight = 2,
		est = 18,
		hint = "Tap the ingredients in the order on the ticket.",
		steps = {
			{ kind = "sequence", at = { "Prep" }, prompt = "Build order", action = "Count", text = "Build the burger on the ticket", verb = "BUILD", count = 4, pool = { "Bun", "Patty", "Cheese", "Lettuce", "Tomato", "Pickles", "Sauce" } },
		},
	},
	Serve = {
		title = "Serve a table",
		pay = 9,
		xp = 22,
		weight = 2,
		est = 21,
		hint = "Grab the tray at the pass and take it to the glowing table.",
		steps = {
			{ kind = "pickup", at = { "Pass" }, prompt = "Grab tray", text = "Order's up. Grab the tray", carry = "Tray" },
			{ kind = "drop", at = { "Table1", "Table2", "Table3" }, prompt = "Serve", text = "Take it to the table" },
		},
	},
	MopShack = {
		title = "Mop the floor",
		pay = 8,
		xp = 20,
		weight = 1,
		est = 17,
		hint = "Hold to mop. Let go and the spill creeps back.",
		steps = {
			{ kind = "hold", at = { "Floor1", "Floor2" }, prompt = "Mop", action = "Mop", tool = "Mop", text = "Grease on the floor. Mop it", verb = "MOPPING", seconds = 4, fx = "Spill" },
		},
	},

	-- tier 2 (pay ~ the same $ per second as the job's first task, so $/min holds: tools/tests/test_job_rules.py)
	Checkout = {
		title = "Ring up a customer",
		pay = 16,
		xp = 22,
		weight = 3,
		est = 14, -- plus the wait (gap)
		steps = {
			{ kind = "hold", at = { "Register" }, prompt = "Scan items", action = "Scan", tool = "Scanner", text = "Customer at the register", verb = "SCANNING", seconds = 2.5 },
		},
	},
	BagGroceries = {
		title = "Bag the groceries",
		pay = 17,
		xp = 22,
		weight = 2,
		est = 15,
		hint = "Heavy stuff first, eggs on top: tap them in the order on the card.",
		steps = {
			{ kind = "sequence", at = { "Register" }, prompt = "Bag items", action = "Scan", text = "Bag the customer's groceries", verb = "BAG IT", count = 5, pool = { "Cans", "Milk", "Cereal", "Bread", "Eggs" }, keepOrder = true },
		},
	},
	CountTill = {
		title = "Count the till",
		pay = 15,
		xp = 20,
		weight = 1,
		est = 12,
		hint = "Press when the needle's in the green to count each stack.",
		steps = {
			{ kind = "timing", at = { "Register" }, prompt = "Count till", action = "Count", text = "Shift change. Count the till", verb = "COUNT", hits = 3, zone = 0.24, speed = 0.9 },
		},
	},
	GumRack = {
		title = "Restock the gum rack",
		pay = 24,
		xp = 26,
		weight = 1,
		est = 26,
		hint = "Grab a box from the stockroom, then hold to fill the rack by the register.",
		steps = {
			{ kind = "pickup", at = { "Stockroom" }, prompt = "Grab box", text = "Grab a box of gum from the stockroom", carry = "Box" },
			{ kind = "hold", at = { "Register" }, prompt = "Fill rack", action = "Scan", text = "Fill the rack by the register", verb = "STOCKING", seconds = 2.5 },
		},
	},
	WashCar = {
		title = "Wash a car",
		pay = 20,
		xp = 24,
		weight = 3,
		est = 15,
		steps = {
			{ kind = "hold", at = { "Lane" }, prompt = "Wash", action = "Wipe", tool = "Sponge", text = "A car rolled in. Wash it", verb = "WASHING", seconds = 4, fx = "Suds" },
		},
	},
	Rinse = {
		title = "Rinse a car",
		pay = 18,
		xp = 22,
		weight = 1,
		est = 12,
		hint = "Hold to rinse. Let go and the foam dries on.",
		steps = {
			{ kind = "hold", at = { "Lane" }, prompt = "Rinse", action = "Spray", tool = "SprayBottle", text = "Rinse the foam off", verb = "RINSING", seconds = 3, fx = "Suds" },
		},
	},
	DryBuff = {
		title = "Dry and buff",
		pay = 18,
		xp = 22,
		weight = 1,
		est = 13,
		hint = "Press when the needle's in the green: three panels.",
		steps = {
			{ kind = "timing", at = { "Lane" }, prompt = "Buff", action = "Wipe", tool = "Sponge", text = "Dry it off and buff the paint", verb = "BUFF", hits = 3, zone = 0.24, speed = 1.0 },
		},
	},
	Vacuum = {
		title = "Vacuum the interior",
		pay = 20,
		xp = 24,
		weight = 1,
		est = 15,
		hint = "Hold to vacuum the seats and the mats.",
		steps = {
			{ kind = "hold", at = { "Lane" }, prompt = "Vacuum", action = "Sweep", text = "Vacuum the inside", verb = "VACUUMING", seconds = 4 },
		},
	},
	TireShine = {
		title = "Tire shine",
		pay = 19,
		xp = 22,
		weight = 1,
		est = 14,
		hint = "Do the tires in the order on the card.",
		steps = {
			{ kind = "sequence", at = { "Lane" }, prompt = "Shine tires", action = "Wipe", tool = "Sponge", text = "Shine all four tires", verb = "ORDER", count = 4, pool = { "Front left", "Front right", "Back right", "Back left" }, keepOrder = true },
		},
	},
	ParkCar = {
		title = "Park a guest's car",
		pay = 22,
		xp = 26,
		weight = 3,
		est = 22,
		steps = {
			{ kind = "pickup", at = { "Stand" }, prompt = "Take keys", text = "Guest pulled up. Take the keys", carry = "Keys" },
			{ kind = "drop", at = { "Spot1", "Spot2", "Spot3", "Spot4" }, prompt = "Park", text = "Park it in the open spot" },
		},
	},

	FetchCar = {
		title = "Bring a guest's car round",
		pay = 22,
		xp = 26,
		weight = 2,
		est = 22,
		hint = "A guest is leaving: grab their keys from the car, then bring it to the stand.",
		steps = {
			{ kind = "pickup", at = { "Spot1", "Spot2", "Spot3", "Spot4" }, prompt = "Get car", text = "Guest's leaving. Get their car", carry = "Keys" },
			{ kind = "drop", at = { "Stand" }, prompt = "Hand over", text = "Bring it round to the stand" },
		},
	},
	KeyBoard = {
		title = "Sort the key board",
		pay = 15,
		xp = 20,
		weight = 1,
		est = 12,
		hint = "Hang the keys by colour, in the order on the card.",
		steps = {
			{ kind = "sequence", at = { "Stand" }, prompt = "Sort keys", action = "Count", text = "The key board's a mess. Sort it", verb = "SORT", count = 3, pool = { "Gold tag", "Blue tag", "Red tag", "Green tag" } },
		},
	},

	-- tier 3 (route job). On foot for now (no vehicles yet): local drops only, so a run is ~40 s, not ~75.
	Delivery = {
		title = "Deliver a load",
		pay = 20,
		xp = 22, -- tier 3 keeps XP/min below the hands-on jobs (~35/min)
		weight = 2,
		est = 40,
		distancePay = 0.12, -- + $ per stud between the dock and the drop
		estDistance = 300, -- typical run length (balance test + the app's $/min only)
		steps = {
			{ kind = "hold", at = { "Dock" }, prompt = "Load up", text = "Load the cargo at the dock", verb = "LOADING", seconds = 3, carry = "Crate" },
			{ kind = "drop", at = { "DropPortShops", "DropLiberty", "DropWarehouse", "DropCourt" }, prompt = "Drop off", text = "Deliver the load", far = true },
		},
	},
	PreTrip = {
		title = "Pre-trip inspection",
		pay = 21,
		xp = 10,
		weight = 1,
		est = 15,
		hint = "Check the truck in the order on the card.",
		steps = {
			{ kind = "sequence", at = { "Truck" }, prompt = "Inspect", text = "Walk around the truck before the run", verb = "CHECK", count = 5, pool = { "Tires", "Lights", "Brakes", "Mirrors", "Horn" }, keepOrder = true },
		},
	},
	StrapLoad = {
		title = "Strap the load",
		pay = 17,
		xp = 8,
		weight = 1,
		est = 12,
		hint = "Ratchet each strap when the needle's in the green.",
		steps = {
			{ kind = "timing", at = { "Dock" }, prompt = "Strap", action = "Crank", text = "Strap the pallets down", verb = "RATCHET", hits = 3, zone = 0.22, speed = 1.0 },
		},
	},
}

-- Which job each task belongs to (filled below from Defs[...].tasks)
Jobs.TaskJob = {}
for jobId, def in Jobs.Defs do
	for _, t in def.tasks or {} do
		Jobs.TaskJob[t] = jobId
	end
end

-- Shift-done / first-task texts from the boss (light flavour, makes the job feel like a place).
Jobs.BossLines = {
	Patel = {
		FirstTask = "Good, good. Boxes go on the shelves, not in your pocket.",
		ShiftDone = { "Nice shift. Same again?", "You're quicker than the last kid. Keep it up.", "Shelves look great. Take a breather if you need it." },
	},
	Rico = {
		FirstTask = "Tires on the rack, cars in the bays. Don't scratch nothing.",
		ShiftDone = { "Clean work. Customers noticed.", "Not bad, rookie." },
	},
	Tasha = {
		FirstTask = "Grill's hot. Don't burn the patties, don't burn yourself.",
		ShiftDone = { "Kitchen ran smooth today. Thank you!", "You're a natural behind that grill." },
	},
}

-- Back-compat for the Piece 1 Jobs app shell: { id, title, role, pay (text), level, place }
Jobs.List = {}
for _, id in Jobs.Order do
	local d = Jobs.Defs[id]
	local payText = if d.kind == "post" then ("$" .. tostring(d.perMinute) .. " / min") else "per task"
	table.insert(Jobs.List, { id = id, title = d.title, role = d.role, pay = payText, level = d.level, place = d.place })
end

return Jobs
