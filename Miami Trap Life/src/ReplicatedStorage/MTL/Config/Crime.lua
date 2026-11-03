--!strict
-- The crime loop (research "What Makes Hood RP Games Fun" §5 P0-1..3). Every number for repeatable crime lives here:
-- the money ladder (stickups, tip jobs, house licks, car boosts, ATM drills, crew heists), heat stars + NPC police,
-- and dirty cash (carried in a bag on your back, washed at Liberty Laundromat, half dropped when you go down).
-- Story rule (01 Story Bible §5): repeatable robberies only hit Royce's places, never Patel or a mom-and-pop shop.
--
-- Places: the builder tool (tools/BuildCrimeSites.lua, Edit mode) makes Workspace.MTL_CrimeSites.<SiteId> with named
-- invisible point parts. CrimeService reads points from there (server side, so StreamingEnabled never hides them);
-- `at` below is only the fallback / the GPS spot for the Money app before the sites exist.
-- North = -Z, east = +X, street y = 2-3, shop floors y = 6.4.
local V = Vector3.new

local Crime = {}

---------------------------------------------------------------- who can do crime

Crime.Requires = {
	Path = "Criminal", -- Settings -> Lifestyle. Civilians see the methods in the Money app with "Criminal life only"
	Stage = "MissionDone", -- after the first robbery (StoryRules order); story missions stay the story's
}

---------------------------------------------------------------- dirty cash

Crime.Dirty = {
	Max = 250000, -- a bag can't hold more (anti-exploit cap)
	DropShare = 0.5, -- going down drops this share of your bag as a pickup anyone can grab
	DropMin = 50, -- smaller bags don't drop anything (newcomers never lose a few dollars)
	PickupLife = 90, -- seconds a dropped bag stays on the ground
	PickupOwnerDelay = 4, -- seconds before the player who dropped it can grab it back (no instant re-pickups)
	PickupRadius = 6, -- studs; walk over it (the server checks distance)
	BustShare = 1, -- getting cuffed takes this share of the bag (all of it). Clean cash, guns, cars: never touched
	BagShowAt = 1, -- the duffel shows on your back from this much dirty cash
	BagBigAt = 5000, -- and gets fatter from here
	LeaveKeeps = true, -- dirty cash is saved when you leave (no penalty for a crash). Heat is not saved.
}

-- Washing at Liberty Laundromat (back room). Takes time, you stand there, and the house keeps a cut.
Crime.Wash = {
	Site = "Laundromat",
	Cut = 0.15, -- 15% (10% from Level 15: WashCutLevel)
	CutLow = 0.10,
	CutLowLevel = 15,
	PerSecond = 400, -- dollars washed per second of standing at the counter (big bags take a while: real risk)
	MinSeconds = 3,
	MaxSeconds = 25,
	MaxHeat = 0, -- can't wash with stars on you ("Not with the cops on you. Come back clean.")
	Radius = 7, -- stand this close to the counter
}

---------------------------------------------------------------- tools (bought at the Cash 4 Gold back door)

-- Kept forever in Inventory.Items[id] = true. Bought from Marcus at the back door of Royce's Cash 4 Gold
-- (a phone-free physical shop: walk up, pick, pay clean cash).
Crime.Tools = {
	Sledgehammer = { title = "Sledgehammer", price = 450, level = 6, blurb = "For walls that hide money. Tip jobs." },
	Crowbar = { title = "Crowbar", price = 200, level = 5, blurb = "Pops a back door. House licks." },
	SlimJim = { title = "Slim jim", price = 250, level = 7, blurb = "Opens a car door without a key. Car boosts." },
	Drill = { title = "Drill rig", price = 800, level = 9, blurb = "Eats an ATM in 45 seconds. Loud." },
}
Crime.ToolOrder = { "Crowbar", "Sledgehammer", "SlimJim", "Drill" }

---------------------------------------------------------------- the money ladder

-- pay = dirty cash. perMinute = rough take per minute INCLUDING travel and heat time (for the Money app sort).
-- A tier-1 job pays ~$27/min; crime should beat it 3-10x once risk is counted (research rule).
Crime.Methods = {
	Stickup = {
		title = "Stickup",
		blurb = "Royce's check-cashing spots and his other Cash 4 Gold. Gun out, clerk's hands up, empty the drawer.",
		level = 5,
		needsGun = true,
		cooldown = 180, -- per store
		heat = 1,
		heatIfShots = 2,
		stacks = { 4, 6 }, -- cash stacks in the drawer
		stackValue = { 90, 140 },
		aimSeconds = 2.0, -- aim at the clerk this long (GunService.Intimidating)
		grabSeconds = 0.7, -- hold per stack
		xp = 60,
		sites = { "CheckCashingN", "CheckCashingS", "CashForGoldS" },
	},
	TipJob = {
		title = "Tip job",
		blurb = "Dre texts you a wall with money behind it. Three hits with a sledgehammer, scoop the stacks, go.",
		level = 6,
		tool = "Sledgehammer",
		cooldown = 480,
		heat = 2,
		hits = 3, -- timing minigame per swing
		stacks = { 12, 15 },
		stackValue = { 110, 170 },
		grabSeconds = 0.35,
		xp = 140,
		spots = { "TipTrap", "TipLaundromat", "TipWings", "TipCourts" },
	},
	HouseLick = {
		title = "House lick",
		blurb = "Royce's empty rentals on 52nd. Pop the back door, carry the goods to the van, fence them at Cash 4 Gold.",
		level = 5,
		tool = "Crowbar",
		cooldown = 600, -- per house
		heat = 1, -- a neighbour calls it in...
		heatDelay = 40, -- ...this many seconds after the door pops
		items = 5, -- loot in the house (each one a carry trip to the van)
		vanCapacity = 5,
		xp = 120,
		sites = { "Lick52A", "Lick52B", "Lick52C", "Lick52D" },
	},
	CarBoost = {
		title = "Car boost",
		blurb = "Royce's rent collector parks his SUV wherever he's collecting. Slim jim the door, drive it to A1 Tires.",
		level = 7,
		tool = "SlimJim",
		cooldown = 360,
		heat = 2, -- the alarm goes when the door opens
		hits = 4, -- lock timing minigame
		pay = 1400, -- minus damage
		damageCost = 70, -- per hard hit (> DamageSpeed change in one frame)
		damageSpeed = 30, -- studs/s lost in one frame = a hard hit
		minPay = 500,
		xp = 160,
		spots = { "BoostCheckN", "BoostGold", "BoostLucky" },
		chopShop = "ChopShop",
		carTemplate = "Oros", -- ServerStorage.MTL_Cars.<template> (any A-Chassis car; swap for a beater SUV later)
	},
	AtmDrill = {
		title = "ATM drill",
		blurb = "Royce runs his own ATM network (ROYCE CASH). Bolt the rig on one and hold the block for 45 seconds. Everybody hears it.",
		level = 9,
		tool = "Drill",
		cooldown = 900, -- per ATM
		heat = 1, -- when the drill starts
		heatDone = 2, -- when the box pops
		attachSeconds = 2.5,
		drillSeconds = 45,
		leaveRadius = 40, -- walk further than this and the drill stalls (it waits for you)
		stacks = { 8, 10 },
		stackValue = { 120, 160 },
		grabSeconds = 0.4,
		xp = 200,
		sites = { "AtmGas", "AtmCarWash", "AtmPark" },
	},
	Heist = {
		title = "Crew heist: Cash 4 Gold",
		blurb = "Royce's own store after closing. Cut the alarm, crack the office safe, carry the bags out. Bring a crew.",
		level = 12,
		tools = { "Crowbar", "Drill" },
		cooldown = 2700, -- 45 min, per player
		crewMax = 4,
		crewRadius = 60, -- crew = Criminal players this close to you when you start
		heat = 3,
		alarmSeconds = 6, -- hold on the alarm box
		safeHits = 6, -- 3 dials x 2
		bags = 4, -- duffels in the safe, carried one at a time
		bagValue = { 1500, 2300 }, -- each, split evenly between the crew
		xp = 450,
		site = "CashForGoldN",
	},
}
Crime.MethodOrder = { "Stickup", "HouseLick", "TipJob", "CarBoost", "AtmDrill", "Heist" }

-- Fencing (house lick goods) at the Cash 4 Gold back door. Prices per item (dirty cash).
Crime.Loot = {
	TV = { title = "Flat TV", value = { 220, 300 }, carry = "Hug", look = "TV" },
	Speaker = { title = "Speaker", value = { 120, 180 }, carry = "Hug", look = "Speaker" },
	Console = { title = "Game console", value = { 160, 240 }, carry = "Hug", look = "Console" },
	Laptop = { title = "Laptop", value = { 140, 200 }, carry = "Hug", look = "Laptop" },
	Microwave = { title = "Microwave", value = { 80, 120 }, carry = "Hug", look = "Microwave" },
	Jewelry = { title = "Jewelry box", value = { 180, 320 }, carry = "Hug", look = "Jewelry" },
}
Crime.FenceSite = "CashForGoldN" -- point "Fence" (Marcus at the back door)
Crime.EconVersion = "econ_v1" -- sent with every Dirty economy event; bump when payouts are retuned

---------------------------------------------------------------- heat + police

Crime.Heat = {
	Max = 5,
	-- not being seen by any police unit for this long drops one star (per current stars)
	LoseSeconds = { 18, 26, 34, 44, 56 },
	SeeRange = 140, -- studs; police see you inside this with line of sight
	SeeRangeCar = 220,
	HideHomeSeconds = 6, -- inside your own flat: stars drop to 0 after this
	-- drive through a car wash tunnel or a paint booth (parts tagged MTL_HeatWash, placed by the builder) while
	-- nobody has eyes on you for this long: the heat is gone (new plate, new colour, nobody's sure it was you)
	WashUnseenSeconds = 1.5,
	AttrName = "MTL_Heat", -- player attribute 0-5 (the HUD and other players' tags read it)
	ClearOnDeath = true,
}

Crime.Police = {
	Enabled = true,
	UnitsPerStar = { 1, 2, 3, 3, 4 }, -- cruisers chasing you at 1-5 stars (plus the helicopter from 4, SWAT at 5)
	MaxUnits = 8, -- whole server
	SpawnMin = 220, -- cruisers appear on a road this far away (out of sight)
	SpawnMax = 420,
	CarSpeed = { 58, 66, 74, 78, 84 }, -- studs/s along the road route, per star
	ReRoute = 2.5, -- seconds between route refreshes while chasing
	StopDistance = 34, -- the car stops this far from you; the officers get out
	OfficersPerCar = 2,
	OfficerSpeed = { 17, 19, 21, 22, 23 }, -- per star; a sprinting player is 24
	OfficerHealth = 120,
	CuffRange = 4.5, -- officer this close...
	CuffSeconds = 1.6, -- ...for this long while you're slow (< CuffMaxSpeed) = busted
	CuffMaxSpeed = 10,
	-- shooting (2+ stars): a shot every ShotEvery seconds per officer, hit chance falls with distance/speed
	ShootFrom = 2,
	ShootRange = 90,
	ShotEvery = { 1.4, 1.15, 1.0, 0.85 }, -- at 2 / 3 / 4 / 5 stars
	ShotDamage = { 7, 10, 11, 13 },
	HitChanceNear = 0.55, -- at 10 studs, standing still
	HitChanceFar = 0.12, -- at ShootRange
	MovingPenalty = 0.5, -- x hit chance when you move faster than 14 studs/s
	GiveUpDistance = 900, -- units further than this from their target despawn
	DespawnAfterCalm = 8, -- seconds after the target has 0 stars
	KillHeat = 3, -- dropping an officer = at least 3 stars...
	KillBump = 1, -- ...and every officer after that is one more star (up to Heat.Max)
	-- 4 stars: a helicopter circles overhead with a spotlight (it sees you from above, so get under a roof)
	Heli = { FromStars = 4, Height = 85, Orbit = 42, OrbitSpeed = 0.35, SeeRange = 320, Responsiveness = 12 },
	-- 5 stars: the officers who get out are SWAT (dark kit, helmet, more health)
	Swat = { FromStars = 5, Health = 220, Kit = Color3.fromRGB(28, 30, 34) },
	BookingSeconds = 10, -- the BOOKED card
	BookedSpawn = V(-1432, 3, -368), -- let go at the spawn lot after booking
	-- looks (R15, HumanoidDescription; Roblox-made items only)
	Uniform = {
		Skin = { Color3.fromRGB(110, 74, 52), Color3.fromRGB(234, 190, 160), Color3.fromRGB(176, 124, 88), Color3.fromRGB(86, 58, 44) },
		Shirt = Color3.fromRGB(28, 36, 64),
		Pants = Color3.fromRGB(24, 28, 44),
		ShirtId = 0, -- 0 = plain navy + the badge/belt parts the service adds
		PantsId = 0,
		HatId = "", -- "" = the built police cap
	},
}

-- Sounds: "(PSE)" = Pro Sound Effects, Roblox-owned and always public; others are community uploads that load today
-- (checked in Studio 2026-11-02). Swap for your own uploads any time. "" = silent.
Crime.Sounds = {
	Siren = "rbxassetid://4832498807", -- "Wail Police Siren" (JuriaanT), a clean loop
	Shot = "rbxassetid://9117399569", -- Pistol Single Shots 1 (PSE), same as the game's pistol (Config/Guns)
	Alarm = "rbxassetid://9113084849", -- Alarm Bell On Carpet Constant Ring 1 (PSE), looped
	Drill = "rbxassetid://9125450626", -- Construction Interior Large Power Tool Drill (PSE), looped
	Smash = "rbxassetid://9120915095", -- Wood Impacts 2 (PSE): sledgehammer hits, the back door
	Break = "rbxassetid://9116329927", -- Low Impacts 2 (PSE): the wall gives
	Cuffs = "rbxassetid://18400149589", -- "Handcuffs" (Lit)
	CashGrab = "rbxassetid://9119668788", -- suction pop (PSE), same as PromptDone
	Wash = "rbxassetid://9117875538", -- Power Drill 1 (PSE) slowed down = a washer spinning up
}

-- Phone texts (Dre / Nina / Smoke) when a method opens up or a tip comes in.
Crime.Texts = {
	TipJob = {
		"Got a tip. Wall behind {spot} got a stash in it. Bring a hammer.",
		"Somebody's been hiding money in a wall at {spot}. Go get it before they move it.",
	},
	Boost = "Royce's collector just parked his ride at {spot}. Go get it. A1 Tires takes it, no questions.",
	Unlock = {
		Stickup = "Royce got check-cashing spots all over. Not Patel. Not nobody on the block. Just Royce.",
		HouseLick = "52nd is all Royce rentals now. Empty, furnished, nobody home. Get a crowbar from Marcus.",
		TipJob = "I hear things. When I hear about money in a wall I'll text you. Get a sledgehammer.",
		CarBoost = "Royce's collector rolls in a nice SUV. Smoke says A1 Tires will take it apart.",
		AtmDrill = "Them blue ROYCE CASH machines at the gas station, Sudz and the park? His. Marcus sells a drill rig. Loud though.",
		Heist = "Royce keeps the real money in the Cash 4 Gold office. Get the crew. We go after close.",
	},
}

---------------------------------------------------------------- people at the sites

-- Built with CreateHumanoidModelFromDescription (Missions.Actors shape). Clothing ids 0 = plain colours; Alex: drop
-- Roblox catalog ids in (or a finished rig in ReplicatedStorage.MTL_Actors.<Name>) any time.
local C = Color3.fromRGB
Crime.Actors = {
	-- Story bible: Marcus works Royce's back door at the Cash 4 Gold on 79th. Sells tools, buys goods, asks nothing.
	Marcus = { Skin = C(86, 58, 44), Shirt = C(30, 30, 34), Pants = C(46, 52, 70), ShirtId = 0, PantsId = 0, Hat = "80275296", Height = 1.06 },
	-- Benny runs the back room at Liberty Laundromat. Takes his cut, never counts out loud.
	Benny = { Skin = C(176, 124, 88), Shirt = C(214, 214, 200), Pants = C(60, 58, 66), ShirtId = 0, PantsId = 0, Height = 0.98 },
	-- Royce's nephew behind the Cash 4 Gold counter, and the tellers at Royce's check-cashing spots.
	Nephew = { Skin = C(110, 74, 52), Shirt = C(150, 30, 40), Pants = C(28, 28, 34), ShirtId = 0, PantsId = 382538503, Height = 1.0 },
	Teller = { Skin = C(234, 190, 160), Shirt = C(70, 110, 160), Pants = C(40, 40, 48), ShirtId = 0, PantsId = 0, Height = 0.97 },
}
-- who stands behind which counter (stickup sites)
Crime.Clerks = { CheckCashingN = "Teller", CheckCashingS = "Teller", CashForGoldS = "Nephew" }

---------------------------------------------------------------- places (fallback positions; the builder makes the real ones)

Crime.Sites = {
	Laundromat = { title = "Liberty Laundromat", at = V(-1416, 6.4, -914), kind = "Laundromat" },
	CheckCashingN = { title = "Check Cashing (Glades Rd)", at = V(-1742, 6.4, -198), kind = "CheckCashing" },
	CheckCashingS = { title = "Check Cashing (south)", at = V(-1502, 6.4, 392), kind = "CheckCashing" },
	CashForGoldS = { title = "Cash 4 Gold (Liberty Blvd)", at = V(-1416, 6.4, 367), kind = "CashForGold" },
	CashForGoldN = { title = "Royce's Cash 4 Gold, back door", at = V(-1135, 2, -336), kind = "CashForGoldN" },
	Lick52A = { title = "Rental on NW 52nd", at = V(-1889, 2, -928), kind = "House" },
	Lick52B = { title = "Rental on NW 52nd", at = V(-1895, 2, -828), kind = "House" },
	Lick52C = { title = "Rental on NW 52nd", at = V(-2031, 2, -608), kind = "House" },
	Lick52D = { title = "Rental on NW 52nd", at = V(-1928, 2, -1078), kind = "House" },
	AtmGas = { title = "the ROYCE CASH ATM at Sunshine Gas", at = V(-1313.8, 3.7, -914), kind = "Atm" },
	AtmCarWash = { title = "the ROYCE CASH ATM at Sudz Car Wash", at = V(-1841, 2, -246), kind = "Atm" },
	AtmPark = { title = "the ROYCE CASH ATM by Liberty Park", at = V(-1560, 2.9, -170), kind = "Atm" },
	ChopShop = { title = "A1 Tires & Rims", at = V(-1834, 2.2, -348), kind = "ChopShop" },
	-- tip walls and boost spots: titles for Dre's texts (the builder places them; `at` is the GPS fallback)
	TipTrap = { title = "the side of the boarded-up house on NW 52nd", at = V(-1882, 2, -827), kind = "TipWall" },
	TipLaundromat = { title = "the alley wall by the laundromat", at = V(-1418.5, 2, -904), kind = "TipWall" },
	TipWings = { title = "the back wall of the wing spot", at = V(-1604.5, 2, 43.5), kind = "TipWall" },
	TipCourts = { title = "the old wall by Westside Courts", at = V(-1928.5, 2, 140), kind = "TipWall" },
	BoostCheckN = { title = "Glades Rd, outside Royce's check cashing", at = V(-1764, 2.2, -206), kind = "BoostSpot" },
	BoostGold = { title = "Liberty Blvd, outside his Cash 4 Gold", at = V(-1391.5, 2.2, 371), kind = "BoostSpot" },
	BoostLucky = { title = "the front row at Lucky's Used Autos", at = V(-1311.5, 2, -596), kind = "BoostSpot" },
}

-- Interiors for house licks are instanced far off the map (one room per house, shared; one crew at a time).
Crime.LickRooms = {
	Origin = V(7400, 400, 6000),
	Spacing = 140,
}

---------------------------------------------------------------- the phone's Money app (Config/Earn contract)

-- Exported for the phone thread's Money app (it merges this list). Shape = Config/Earn.Methods.
Crime.EarnMethods = {}
do
	local pay = {
		Stickup = "$400-800",
		TipJob = "$1,500-2,500",
		HouseLick = "$700-1,300",
		CarBoost = "$800-1,400",
		AtmDrill = "$1,000-1,500",
		Heist = "$6,000-9,000 split",
	}
	local perMinute = { Stickup = 160, TipJob = 260, HouseLick = 150, CarBoost = 220, AtmDrill = 300, Heist = 450 }
	local risk = { Stickup = "1 star", TipJob = "2 stars", HouseLick = "1 star", CarBoost = "2 stars", AtmDrill = "2 stars", Heist = "3 stars" }
	local where = {
		Stickup = "CheckCashingN",
		TipJob = nil,
		HouseLick = "Lick52A",
		CarBoost = nil,
		AtmDrill = "AtmGas",
		Heist = "CashForGoldN",
	}
	for _, id in Crime.MethodOrder do
		local m = (Crime.Methods :: any)[id]
		local tool = m.tool or (m.tools and m.tools[1])
		local site = where[id] and (Crime.Sites :: any)[where[id]]
		table.insert(Crime.EarnMethods, {
			id = id,
			title = m.title,
			kind = "Crime",
			pay = pay[id],
			perMinute = perMinute[id],
			cooldown = m.cooldown,
			risk = risk[id],
			blurb = m.blurb,
			requires = {
				level = m.level,
				path = "Criminal",
				item = tool,
				itemLabel = if tool then "a " .. string.lower((Crime.Tools :: any)[tool].title) else nil,
			},
			position = site and site.at or nil,
			sites = m.sites,
		})
	end
	table.insert(Crime.EarnMethods, {
		id = "Laundromat",
		title = "Wash dirty cash",
		kind = "Hustle",
		pay = "Keeps 85%",
		blurb = "Crime pays dirty cash. Liberty Laundromat's back room washes it clean, minus a cut.",
		requires = { path = "Criminal" },
		position = Crime.Sites.Laundromat.at,
	})
	table.insert(Crime.EarnMethods, {
		id = "Fence",
		title = "Tools and fence",
		kind = "Hustle",
		pay = "Buys your goods",
		blurb = "Marcus at the Cash 4 Gold back door sells tools and buys what you carry out of a house.",
		requires = { path = "Criminal" },
		position = Crime.Sites.CashForGoldN.at,
	})
end

function Crime.method(id: string): any?
	return (Crime.Methods :: any)[id]
end

return Crime
