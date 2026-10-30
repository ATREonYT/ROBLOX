--[[
	GameConfig  (ModuleScript)  ->  ReplicatedStorage > GameConfig

	Every balance number, item, price and reward in the game.
	Server and client both read this, so the UI always matches the rules.

	Robux ids: create the gamepasses / developer products on the Creator Hub
	and paste the ids below. While an id is 0 the item shows "Soon" in game,
	except in Studio where TEST_PURCHASES_IN_STUDIO lets you test it for free.
]]

local Config = {}

Config.DATASTORE_NAME = "CannonEvo_v2"
Config.AUTOSAVE_INTERVAL = 90
Config.TEST_PURCHASES_IN_STUDIO = true

---------------------------------------------------------------------------
-- Training stations (World 1). Gain = base Power per shot.
---------------------------------------------------------------------------
Config.SHOT_INTERVAL = 0.8
Config.MIN_SHOT_INTERVAL = 0.35
Config.STATION_LEAVE_COOLDOWN = 1.5

Config.Stations = {
	{ Id = 1, Name = "Starter Cannon",    Model = "Cannon01_Starter",    Gain = 1,   Rebirths = 0 },
	{ Id = 2, Name = "Iron Cannon",       Model = "Cannon02_Iron",       Gain = 3,   Rebirths = 2 },
	{ Id = 3, Name = "Steel Cannon",      Model = "Cannon03_Steel",      Gain = 8,   Rebirths = 4 },
	{ Id = 4, Name = "Heavy Cannon",      Model = "Cannon04_Heavy",      Gain = 20,  Rebirths = 6 },
	{ Id = 5, Name = "Industrial Cannon", Model = "Cannon06_Industrial", Gain = 50,  Rebirths = 8 },
	{ Id = 6, Name = "Golden Cannon",     Model = "Cannon05_Golden",     Gain = 125, Rebirths = 10 },
	{ Id = 7, Name = "Dragon Cannon",     Model = "Cannon19_Dragon",     Gain = 40,  Rebirths = 0, Pass = "VIP" },
	-- 8th station (Alex, Oct 30). Ids are list positions, so it goes after the VIP one;
	-- BuildWorld1 still places the VIP booth last in the row.
	{ Id = 8, Name = "Plasma Cannon",     Model = "Cannon09_Plasma",     Gain = 300, Rebirths = 12 },
}

---------------------------------------------------------------------------
-- Grand Cannon launch
---------------------------------------------------------------------------
Config.LAUNCH_BASE_SPEED = 180
Config.LAUNCH_SPEED_PER_SQRT = 1.6
Config.LAUNCH_MAX_SPEED = 1900
Config.LAUNCH_ANGLE = 30
Config.LAUNCH_DIRECTION = Vector3.new(1, 0, 0) -- the river runs along +X from the dock (CannonMap)

-- Alex's map (mapeg.glb, packed by tools/map/pack_map.py and imported as Workspace.CannonMap). Map units are
-- studs and the tools keep its own coordinates, so these points are read straight off the model.
Config.Map = {
	Root = "CannonMap",
	River = "03_River", -- the water meshes; flights skim their surface
	Stages = "02_Stages", -- slices named <stage>_<nn>, e.g. 05_Shipwreck_Bay_03
	Sky = "04_Sky_Kingdom",
	WaterY = -0.5, -- the river's surface
	LobbyCenter = Vector3.new(-56, 2, 0), -- the sand island inside the palisade
	LobbySize = Vector3.new(100, 36, 80), -- lobby orbs fall somewhere in 80% of this, on open ground
	Spawn = Vector3.new(-60, 2.5, 0), -- the compass plaza
	DockEnd = Vector3.new(14, 2.5, 0), -- your cannon stands here, nose over the water
	-- stage name and where it starts along the river (X), from the map; the area walls go here
	StageStarts = {
		{ "Meadow Pond", 0 }, { "Mushroom Grove", 100 }, { "Sandy Shore", 233 }, { "Lighthouse Point", 400 },
		{ "Shipwreck Bay", 620 }, { "Skull Rock", 905 }, { "Red Mesa", 1276 }, { "Ancient Ruins", 1760 },
		{ "Maple Woods", 2388 }, { "Fortress Walls", 3204 }, { "Igloo Camp", 4264 }, { "Aurora Peaks", 5644 },
		{ "Crystal Caverns", 7436 }, { "Volcano Core", 9763 }, { "Sky Kingdom", 12780 },
	},
}
-- the map's walkable floor pieces (sand, plaza, paths, dock), by their names from the map file
function Config.Map.IsGround(name)
	return string.find(name, "^Island_") ~= nil or string.find(name, "^Plaza_") ~= nil
		or string.find(name, "^Path_") ~= nil or string.find(name, "^Dock_") ~= nil
end
Config.LAUNCH_COOLDOWN = 2
Config.FLIGHT_TIMEOUT = 25
Config.SKIP_FIRST_HOP = 0.2 -- first arc out of the cannon, as a share of the whole distance
Config.SKIP_DECAY = 0.86 -- each skip is this much shorter than the last
Config.RETURN_DELAY = 1 -- seconds on the landing before you're home; Stone Skipping's next throw is ~1 s after
Config.MIN_LAUNCH_DISTANCE = 160 -- the first arc clears the lobby into the water
-- Rare shots (vault "Beat the Hits", our take on Stone Skipping's Secret/Colossus throws): the server
-- rolls them on every launch, free and never for sale. They multiply that launch's cash, and the
-- ball flies with its own trail; a Mega Shot is announced to the whole server.
Config.RareShots = {
	{ Id = "Mega", Name = "MEGA SHOT", Chance = 1 / 1000, Mult = 25, Color = Color3.fromRGB(255, 120, 240) },
	{ Id = "Golden", Name = "GOLDEN SHOT", Chance = 1 / 100, Mult = 5, Color = Color3.fromRGB(255, 205, 50) },
}
function Config.GetRareShot(id)
	for _, r in ipairs(Config.RareShots) do
		if r.Id == id then
			return r
		end
	end
	return nil
end
Config.CASH_PER_STUD = 0.25
Config.GEM_CHANCE_PER_LAUNCH = 0.15 -- chance of a few bonus gems on landing
Config.AUTO_LAUNCH_INTERVAL = 4 -- seconds between launches with Auto Launch on

---------------------------------------------------------------------------
-- Rebirth: needs Power AND Cash, resets both (and upgrades stay).
---------------------------------------------------------------------------
Config.REBIRTH_POWER_BASE = 100 -- rebirth 2 onwards: this times REBIRTH_GROWTH ^ rebirths
-- The first rebirth ends the tutorial at about 90 s, like Stone Skipping's 85 s (vault teardown, Oct 30):
-- the tutorial's 30 training shots are the Power, and the cash left after the Starter Egg (3 launches,
-- at least 120, minus 100) is the Cash, so you rebirth right after your first hatch
Config.REBIRTH_FIRST_POWER = 30
Config.REBIRTH_FIRST_CASH = 20
Config.REBIRTH_CASH_BASE = 50
Config.REBIRTH_GROWTH = 3.2 -- R1 ~1 min, R5 ~10 min, R10 ~1.5 h, R12 ~3.5 h of training
Config.REBIRTH_POWER_BONUS = 0.5 -- +50% Power per shot per rebirth
Config.REBIRTH_CASH_BONUS = 0.25 -- +25% Cash per rebirth

function Config.RebirthCost(rebirths)
	local g = Config.REBIRTH_GROWTH ^ rebirths
	if rebirths == 0 then
		return Config.REBIRTH_FIRST_POWER, Config.REBIRTH_FIRST_CASH
	end
	return math.floor(Config.REBIRTH_POWER_BASE * g), math.floor(Config.REBIRTH_CASH_BASE * g)
end

Config.RebirthRewards = {
	{ Icon = "World", Text = "New Worlds" },
	{ Icon = "Evolve", Text = "Stronger Cannons" },
	{ Icon = "Power", Text = "+50% Power" },
	{ Icon = "Cash", Text = "+25% Cash" },
	{ Icon = "RebirthSign", Text = "New Training" },
}

---------------------------------------------------------------------------
-- Upgrades (paid with Cash, kept through rebirths)
---------------------------------------------------------------------------
Config.Upgrades = {
	Player = {
		{ Id = "Power",  Name = "Power",      Icon = "Power",        Desc = "+10% Power",     Base = 50,  Growth = 1.45, Max = 50 },
		{ Id = "Range",  Name = "Range",      Icon = "Arrow",        Desc = "+4% Range",      Base = 75,  Growth = 1.5,  Max = 40 },
		{ Id = "Cash",   Name = "Cash Boost", Icon = "CashMedium",   Desc = "+10% Cash",      Base = 60,  Growth = 1.45, Max = 50 },
		{ Id = "Reload", Name = "Reload",     Icon = "Rebirth",      Desc = "-0.03s Reload",  Base = 120, Growth = 1.7,  Max = 15 },
		{ Id = "Luck",   Name = "Luck",       Icon = "Lucky",        Desc = "+5% Luck",       Base = 200, Growth = 1.6,  Max = 25 },
		{ Id = "Speed",  Name = "Walk Speed", Icon = "Sneaker",      Desc = "+1 Walk Speed",  Base = 40,  Growth = 1.5,  Max = 20 },
	},
	Cannon = {
		{ Id = "Barrel",    Name = "Big Barrel",  Icon = "Evolve",     Desc = "+6% Range",       Base = 150, Growth = 1.6, Max = 30 },
		{ Id = "Gunpowder", Name = "Gunpowder",   Icon = "PowerLarge", Desc = "+8% Power",       Base = 150, Growth = 1.6, Max = 30 },
		{ Id = "Crit",      Name = "Lucky Shot",  Icon = "Favorite",   Desc = "+1% 5x Shot",     Base = 250, Growth = 1.7, Max = 20 },
	},
}

function Config.FindUpgrade(id)
	for _, list in pairs(Config.Upgrades) do
		for _, u in ipairs(list) do
			if u.Id == id then
				return u
			end
		end
	end
end

function Config.UpgradeCost(upgrade, level)
	return math.floor(upgrade.Base * upgrade.Growth ^ level)
end

---------------------------------------------------------------------------
-- Worlds (teleports along the map). Zone = a stage name in Config.Map.StageStarts.
---------------------------------------------------------------------------
Config.Worlds = {
	{ Id = 1, Name = "Spawn",        Zone = "Lobby",           Rebirths = 0,  Color = Color3.fromRGB(110, 200, 90) },
	{ Id = 2, Name = "Pirate Cove",  Zone = "Shipwreck Bay",   Rebirths = 1,  Color = Color3.fromRGB(70, 140, 210) },
	{ Id = 3, Name = "Desert",       Zone = "Red Mesa",        Rebirths = 3,  Color = Color3.fromRGB(220, 150, 70) },
	{ Id = 4, Name = "Autumn",       Zone = "Maple Woods",     Rebirths = 5,  Color = Color3.fromRGB(220, 110, 50) },
	{ Id = 5, Name = "Snow",         Zone = "Igloo Camp",      Rebirths = 8,  Color = Color3.fromRGB(150, 210, 255) },
	{ Id = 6, Name = "Lava",         Zone = "Volcano Core",    Rebirths = 10, Color = Color3.fromRGB(230, 70, 40) },
	{ Id = 7, Name = "Sky Kingdom",  Zone = "Sky Kingdom",     Rebirths = 15, Color = Color3.fromRGB(255, 220, 120) },
}

-- where a stage starts along the river, or nil
function Config.StageStart(name)
	for _, st in ipairs(Config.Map.StageStarts) do
		if st[1] == name then
			return st[2]
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- Pets. Boost = multiplier added to Power (0.1 = +10%).
-- Model = name of the model in ReplicatedStorage > Pets.
---------------------------------------------------------------------------
Config.Rarities = {
	Common    = { Order = 1, Color = Color3.fromRGB(190, 190, 200) },
	Uncommon  = { Order = 2, Color = Color3.fromRGB(90, 220, 90) },
	Rare      = { Order = 3, Color = Color3.fromRGB(70, 160, 255) },
	Epic      = { Order = 4, Color = Color3.fromRGB(180, 80, 255) },
	Legendary = { Order = 5, Color = Color3.fromRGB(255, 190, 40) },
	Mythic    = { Order = 6, Color = Color3.fromRGB(255, 70, 110) },
	Secret    = { Order = 7, Color = Color3.fromRGB(20, 20, 20) },
}

Config.Pets = {
	-- Starter
	dog        = { Name = "Dog",        Rarity = "Common",    Boost = 0.10 },
	cat        = { Name = "Cat",        Rarity = "Common",    Boost = 0.12 },
	bunny      = { Name = "Bunny",      Rarity = "Uncommon",  Boost = 0.18 },
	chick      = { Name = "Chick",      Rarity = "Rare",      Boost = 0.30 },
	corgi      = { Name = "Corgi",      Rarity = "Epic",      Boost = 0.55 },
	-- Woodland
	deer       = { Name = "Deer",       Rarity = "Common",    Boost = 0.35 },
	fox        = { Name = "Fox",        Rarity = "Uncommon",  Boost = 0.50 },
	bear       = { Name = "Bear",       Rarity = "Rare",      Boost = 0.80 },
	wolf       = { Name = "Wolf",       Rarity = "Epic",      Boost = 1.30 },
	mint_deer  = { Name = "Mint Deer",  Rarity = "Legendary", Boost = 2.20 },
	-- Nature
	ladybug    = { Name = "Ladybug",    Rarity = "Common",    Boost = 1.00 },
	frog       = { Name = "Frog",       Rarity = "Uncommon",  Boost = 1.40 },
	bee        = { Name = "Bee",        Rarity = "Rare",      Boost = 2.00 },
	sheep      = { Name = "Sheep",      Rarity = "Epic",      Boost = 3.20 },
	penguin    = { Name = "Penguin",    Rarity = "Legendary", Boost = 5.00 },
	-- Ocean
	crab       = { Name = "Crab",       Rarity = "Common",    Boost = 3.00 },
	clownfish  = { Name = "Clownfish",  Rarity = "Uncommon",  Boost = 4.20 },
	turtle     = { Name = "Turtle",     Rarity = "Rare",      Boost = 6.00 },
	seahorse   = { Name = "Seahorse",   Rarity = "Epic",      Boost = 9.00 },
	shark      = { Name = "Shark",      Rarity = "Legendary", Boost = 14.0 },
	narwhal    = { Name = "Narwhal",    Rarity = "Mythic",    Boost = 22.0 },
	-- Magic
	bat        = { Name = "Bat",        Rarity = "Uncommon",  Boost = 10.0 },
	parrot     = { Name = "Parrot",     Rarity = "Rare",      Boost = 15.0 },
	unicorn    = { Name = "Unicorn",    Rarity = "Epic",      Boost = 24.0 },
	dragon     = { Name = "Dragon",     Rarity = "Legendary", Boost = 38.0 },
	phoenix    = { Name = "Phoenix",    Rarity = "Mythic",    Boost = 60.0 },
	-- Hacker (Robux)
	ice_cube     = { Name = "Ice Cube",     Rarity = "Rare",      Boost = 8.0 },
	crystal_cube = { Name = "Crystal Cube", Rarity = "Epic",      Boost = 14.0 },
	void_cube    = { Name = "Void Cube",    Rarity = "Legendary", Boost = 25.0 },
	shadow_cube  = { Name = "Shadow Cube",  Rarity = "Mythic",    Boost = 45.0 },
	galaxy_cube  = { Name = "Galaxy Cube",  Rarity = "Secret",    Boost = 90.0 },
	-- Secret (Gems)
	robot      = { Name = "Robot",      Rarity = "Epic",      Boost = 12.0 },
	alien      = { Name = "Alien",      Rarity = "Legendary", Boost = 20.0 },
	angel_cube = { Name = "Angel Cube", Rarity = "Mythic",    Boost = 35.0 },
	cosmo_cube = { Name = "Cosmo Cube", Rarity = "Secret",    Boost = 70.0 },
	-- Rewards / exclusives
	golden_wing  = { Name = "Golden Wing",  Rarity = "Legendary", Boost = 3.0 },
	royal_cube   = { Name = "Royal Cube",   Rarity = "Mythic",    Boost = 6.0 },
	rainbow_cube = { Name = "Rainbow Cube", Rarity = "Legendary", Boost = 2.0 },
	dino         = { Name = "Dino",         Rarity = "Epic",      Boost = 1.5 },
}

Config.MAX_EQUIPPED = 3
Config.EXTRA_EQUIP = 2 -- from the Extra Equip gamepass
Config.MAX_PETS = 150

---------------------------------------------------------------------------
-- Eggs. Currency = "Cash" | "Gems" | "Robux". Robux eggs use Products.
-- Model = egg model name in ReplicatedStorage > Eggs (for the viewport).
---------------------------------------------------------------------------
Config.Eggs = {
	{ Id = "Starter",  Name = "Starter Egg",  Model = "starter_egg",   Currency = "Cash", Price = 100,
		Pets = { { "dog", 45 }, { "cat", 30 }, { "bunny", 17 }, { "chick", 7 }, { "corgi", 1 } } },
	{ Id = "Woodland", Name = "Woodland Egg", Model = "woodland_egg",  Currency = "Cash", Price = 2500,
		Pets = { { "deer", 45 }, { "fox", 30 }, { "bear", 17 }, { "wolf", 7 }, { "mint_deer", 1 } } },
	{ Id = "Nature",   Name = "Nature Egg",   Model = "nature_egg",    Currency = "Cash", Price = 30000,
		Pets = { { "ladybug", 45 }, { "frog", 30 }, { "bee", 17 }, { "sheep", 7 }, { "penguin", 1 } } },
	{ Id = "Ocean",    Name = "Ocean Egg",    Model = "ocean_egg",     Currency = "Cash", Price = 400000,
		Pets = { { "crab", 40 }, { "clownfish", 30 }, { "turtle", 18 }, { "seahorse", 9 }, { "shark", 2.7 }, { "narwhal", 0.3 } } },
	{ Id = "Magic",    Name = "Magic Egg",    Model = "magic_egg",     Currency = "Cash", Price = 6000000,
		Pets = { { "bat", 45 }, { "parrot", 30 }, { "unicorn", 18 }, { "dragon", 6.5 }, { "phoenix", 0.5 } } },
	{ Id = "Hacker",   Name = "Hacker Egg",   Model = "elemental_egg", Currency = "Robux",
		Products = { [1] = "HackerEgg1", [3] = "HackerEgg3", [10] = "HackerEgg10" },
		Pets = { { "ice_cube", 40 }, { "crystal_cube", 30 }, { "void_cube", 20 }, { "shadow_cube", 8 }, { "galaxy_cube", 2 } } },
	{ Id = "Secret",   Name = "Secret Egg",   Model = "celestial_egg", Currency = "Gems", Price = 500,
		Pets = { { "robot", 83 }, { "alien", 12 }, { "angel_cube", 4.9 }, { "cosmo_cube", 0.1 } } },
}

function Config.GetEgg(id)
	for _, egg in ipairs(Config.Eggs) do
		if egg.Id == id then
			return egg
		end
	end
end

---------------------------------------------------------------------------
-- Cannon collection. Equipped cannon multiplies Power per shot.
-- Model = model name in ReplicatedStorage > Cannons.
-- Currency "Free" | "Cash" | "Gems" | "Robux" (Robux uses Product) | "Rebirth" (Rebirths = how many).
---------------------------------------------------------------------------
Config.CannonTabs = { "All", "Basic", "Rare", "Epic", "Legendary", "Secret" }

Config.Cannons = {
	{ Id = "Starter",    Model = "Cannon01_Starter",    Tier = "Basic",     Mult = 1,    Currency = "Free" },
	{ Id = "Iron",       Model = "Cannon02_Iron",       Tier = "Basic",     Mult = 1.25, Currency = "Rebirth", Rebirths = 2 },
	{ Id = "Steel",      Model = "Cannon03_Steel",      Tier = "Basic",     Mult = 1.5,  Currency = "Rebirth", Rebirths = 4 },
	{ Id = "Heavy",      Model = "Cannon04_Heavy",      Tier = "Basic",     Mult = 1.8,  Currency = "Rebirth", Rebirths = 6 },
	{ Id = "Industrial", Model = "Cannon06_Industrial", Tier = "Basic",     Mult = 2.2,  Currency = "Rebirth", Rebirths = 8 },
	{ Id = "Twin",       Model = "Cannon07_Twin",       Tier = "Rare",      Mult = 2.7,  Currency = "Cash", Price = 250000 },
	{ Id = "Golden",     Model = "Cannon05_Golden",     Tier = "Rare",      Mult = 3.3,  Currency = "Rebirth", Rebirths = 10 },
	{ Id = "Rotary",     Model = "Cannon08_Rotary",     Tier = "Rare",      Mult = 4,    Currency = "Cash", Price = 3000000 },
	{ Id = "Toy",        Model = "Cannon21_Toy",        Tier = "Rare",      Mult = 3,    Currency = "Gems", Price = 250 },
	{ Id = "Candy",      Model = "Cannon22_Candy",      Tier = "Rare",      Mult = 3.6,  Currency = "Gems", Price = 450 },
	{ Id = "Frost",      Model = "Cannon11_Frost",      Tier = "Epic",      Mult = 5,    Currency = "Cash", Price = 10000000 },
	{ Id = "Inferno",    Model = "Cannon12_Inferno",    Tier = "Epic",      Mult = 6,    Currency = "Cash", Price = 35000000 },
	{ Id = "Toxic",      Model = "Cannon13_Toxic",      Tier = "Epic",      Mult = 7.5,  Currency = "Cash", Price = 120000000 },
	{ Id = "Pumpkin",    Model = "Cannon23_Pumpkin",    Tier = "Epic",      Mult = 6.5,  Currency = "Gems", Price = 900 },
	{ Id = "Pirate",     Model = "Cannon24_Pirate",     Tier = "Epic",      Mult = 8,    Currency = "Gems", Price = 1500 },
	{ Id = "Plasma",     Model = "Cannon09_Plasma",     Tier = "Legendary", Mult = 9.5,  Currency = "Cash", Price = 400000000 },
	{ Id = "Thunder",    Model = "Cannon14_Thunder",    Tier = "Legendary", Mult = 12,   Currency = "Cash", Price = 1500000000 },
	{ Id = "Reactor",    Model = "Cannon10_Reactor",    Tier = "Legendary", Mult = 15,   Currency = "Cash", Price = 5000000000 },
	{ Id = "Shark",      Model = "Cannon25_Shark",      Tier = "Legendary", Mult = 11,   Currency = "Gems", Price = 2500 },
	{ Id = "Robot",      Model = "Cannon26_Robot",      Tier = "Legendary", Mult = 14,   Currency = "Gems", Price = 4000 },
	{ Id = "Quantum",    Model = "Cannon15_Quantum",    Tier = "Secret",    Mult = 20,   Currency = "Cash", Price = 20000000000 },
	{ Id = "Rainbow",    Model = "Cannon27_Rainbow",    Tier = "Secret",    Mult = 18,   Currency = "Gems", Price = 8000 },
	{ Id = "Galaxy",     Model = "Cannon30_Galaxy",     Tier = "Secret",    Mult = 25,   Currency = "Robux", Product = "GalaxyCannon" },
	{ Id = "Hacker",     Model = "Cannon31_Hacker",     Tier = "Secret",    Mult = 3.5,  Currency = "Robux", Product = "HackerCannon", Featured = true },
}

-- The training-station cannons ("Rebirth" above) unlock by rebirthing, one per
-- station, and the best one you own is equipped for you. It's the cannon that
-- stands at the Launch Zone and fires you down the track.
function Config.BestCannon(data)
	local best = Config.Cannons[1]
	for _, c in ipairs(Config.Cannons) do
		if data.Cannons[c.Id] and c.Mult > best.Mult then
			best = c
		end
	end
	return best
end

function Config.GetCannon(id)
	for _, c in ipairs(Config.Cannons) do
		if c.Id == id then
			return c
		end
	end
end

---------------------------------------------------------------------------
-- Cannonballs: shown on the stand in the lobby, one per pad (lower row first,
-- left to right). Bought once with Cash, then picked; the picked one
-- is the ball your cannon fires and adds its Cash bonus to every launch (Alex, Oct 30).
-- Model = true: Alex's imported ball (ReplicatedStorage.CannonBalls, named by Id) is used; the
-- others are drawn from Color and Band, which also tint the trail and the shop card.
---------------------------------------------------------------------------
Config.Balls = {
	{ Id = "Wood",    Name = "Wood",    Price = 0,         CashBonus = 0,    Model = true, Color = Color3.fromRGB(225, 110, 40),  Band = Color3.fromRGB(150, 65, 25) },
	{ Id = "Stone",   Name = "Stone",   Price = 500,       CashBonus = 0.05, Model = true, Color = Color3.fromRGB(175, 170, 165), Band = Color3.fromRGB(115, 110, 105) },
	{ Id = "Steel",   Name = "Steel",   Price = 2500,      CashBonus = 0.1,  Model = true, Color = Color3.fromRGB(230, 232, 240), Band = Color3.fromRGB(150, 160, 185) },
	{ Id = "Gold",    Name = "Gold",    Price = 10000,     CashBonus = 0.15, Color = Color3.fromRGB(255, 200, 40),  Band = Color3.fromRGB(255, 255, 255) },
	{ Id = "Ruby",    Name = "Ruby",    Price = 50000,     CashBonus = 0.2,  Color = Color3.fromRGB(225, 40, 70),   Band = Color3.fromRGB(255, 170, 190) },
	{ Id = "Neon",    Name = "Neon",    Price = 250000,    CashBonus = 0.3,  Model = true, Color = Color3.fromRGB(45, 20, 70),    Band = Color3.fromRGB(210, 70, 255) },
	{ Id = "Frost",   Name = "Frost",   Price = 1000000,   CashBonus = 0.4,  Color = Color3.fromRGB(190, 235, 255), Band = Color3.fromRGB(70, 180, 255) },
	{ Id = "Rainbow", Name = "Rainbow", Price = 5000000,   CashBonus = 0.5,  Model = true, CardZoom = 1.5, Color = Color3.fromRGB(255, 190, 40),  Band = Color3.fromRGB(255, 80, 60) },
	{ Id = "Hacker",  Name = "Hacker",  Price = 25000000,  CashBonus = 0.75, Model = true, CardZoom = 1.5, Color = Color3.fromRGB(15, 30, 20),    Band = Color3.fromRGB(60, 255, 100) },
	{ Id = "Galaxy",  Name = "Galaxy",  Price = 100000000, CashBonus = 1,    Model = true, CardZoom = 1.5, Color = Color3.fromRGB(50, 25, 95),    Band = Color3.fromRGB(200, 110, 255) },
}

function Config.GetBall(id)
	for _, b in ipairs(Config.Balls) do
		if b.Id == id then
			return b
		end
	end
end

---------------------------------------------------------------------------
-- Robux: gamepasses and developer products (paste ids from Creator Hub)
---------------------------------------------------------------------------
Config.Passes = {
	DoublePower = { Id = 0, Name = "2x Power",    Icon = "DoublePower", Price = 399, Desc = "Double Power from every shot" },
	DoubleCash  = { Id = 0, Name = "2x Cash",     Icon = "DoubleCash",  Price = 399, Desc = "Double Cash from every launch" },
	Lucky       = { Id = 0, Name = "Lucky",       Icon = "Lucky",       Price = 249, Desc = "2x Luck when hatching eggs" },
	TripleOpen  = { Id = 0, Name = "Triple Open", Icon = "TripleOpen",  Price = 349, Desc = "Hatch 3 eggs at once" },
	OctoOpen    = { Id = 0, Name = "8x Open",     Icon = "TripleOpen",  Price = 799, Desc = "Hatch 8 eggs at once" },
	AutoCollect = { Id = 0, Name = "Auto Collect", Icon = "AutoCollect", Price = 349, Desc = "Collect orbs from far away", ComingSoon = true }, -- orbs are off, so it gives nothing yet
	ExtraEquip  = { Id = 0, Name = "+2 Pets",     Icon = "ExtraEquip",  Price = 199, Desc = "Equip 2 more pets" },
	VIP         = { Id = 0, Name = "VIP",         Icon = "VIP",         Price = 299, Desc = "Dragon Cannon station + 1.5x Gems" },
	AutoLaunch  = { Id = 0, Name = "Auto Launch", Icon = "Trophy",      Price = 25,  Desc = "Launch automatically" },
}
Config.PassOrder = { "DoublePower", "DoubleCash", "Lucky", "TripleOpen", "OctoOpen", "AutoCollect", "ExtraEquip", "VIP", "AutoLaunch" }

-- Grant: what the server gives when the product is bought.
Config.Products = {
	CashSmall    = { Id = 0, Name = "Pile of Cash",   Icon = "CashSmall",    Price = 49,  Grant = { CashMinutes = 10 } },
	CashMedium   = { Id = 0, Name = "Stack of Cash",  Icon = "CashMedium",   Price = 149, Grant = { CashMinutes = 45 } },
	CashLarge    = { Id = 0, Name = "Vault of Cash",  Icon = "CashLarge",    Price = 399, Grant = { CashMinutes = 180 } },
	GemsSmall    = { Id = 0, Name = "250 Gems",       Icon = "Gem",   Price = 49,  Grant = { Gems = 250 } },
	GemsMedium   = { Id = 0, Name = "1,000 Gems",     Icon = "Gem",   Price = 149, Grant = { Gems = 1000 } },
	GemsLarge    = { Id = 0, Name = "4,000 Gems",     Icon = "Gem",   Price = 449, Grant = { Gems = 4000 } },
	PowerPack1   = { Id = 0, Name = "Power Pack",     Icon = "PowerPack1",   Price = 25,  Grant = { PowerMinutes = 10 } },
	PowerPack2   = { Id = 0, Name = "Mega Power",     Icon = "PowerPack2",   Price = 95,  Grant = { PowerMinutes = 45 } },
	PowerPack3   = { Id = 0, Name = "Giga Power",     Icon = "PowerPack3",   Price = 185, Grant = { PowerMinutes = 120 } },
	SkipRebirth  = { Id = 0, Name = "Skip Rebirth",   Icon = "RebirthSkip",  Price = 99,  Grant = { Rebirth = true } },
	StarterPack  = { Id = 0, Name = "Starter Pack",   Icon = "StarterCrate", Price = 99,  Grant = { Gems = 500, CashMinutes = 30, Pet = "royal_cube" } },
	HackerEgg1   = { Id = 0, Name = "1 Hacker Egg",   Icon = "StarterCrate", Price = 249, Grant = { Egg = "Hacker", Count = 1 } },
	HackerEgg3   = { Id = 0, Name = "3 Hacker Eggs",  Icon = "StarterCrate", Price = 699, Grant = { Egg = "Hacker", Count = 3 } },
	HackerEgg10  = { Id = 0, Name = "10 Hacker Eggs", Icon = "StarterCrate", Price = 1999, Grant = { Egg = "Hacker", Count = 10 } },
	HackerCannon = { Id = 0, Name = "Hacker Cannon",  Icon = "Evolve",       Price = 349, Grant = { Cannon = "Hacker" } },
	GalaxyCannon = { Id = 0, Name = "Galaxy Cannon",  Icon = "Evolve",       Price = 799, Grant = { Cannon = "Galaxy" } },
}

-- Gem-priced timed boosts (Shop > Boosts)
Config.Boosts = {
	{ Id = "Power", Name = "2x Power", Icon = "PotionRed",   Minutes = 15, Gems = 100 },
	{ Id = "Cash",  Name = "2x Cash",  Icon = "PotionGold",  Minutes = 15, Gems = 100 },
	{ Id = "Luck",  Name = "2x Luck",  Icon = "Lucky",       Minutes = 15, Gems = 75 },
	{ Id = "All",   Name = "Boost Bundle", Icon = "BoostBundle", Minutes = 15, Gems = 225 },
}

-- Featured carousel (Shop > Featured)
Config.Featured = {
	{ Title = "HACKER CANNON", Lines = { "+250% Power", "Unique Effects", "Exclusive Cannon" }, Product = "HackerCannon", Color = Color3.fromRGB(40, 200, 60), Model = "Cannon31_Hacker" },
	{ Title = "HACKER EGG", Lines = { "2% Galaxy Cube!", "Up to x90 Power", "Limited Pets" }, Product = "HackerEgg1", Color = Color3.fromRGB(120, 60, 230), Egg = "Hacker" },
	{ Title = "STARTER PACK", Lines = { "500 Gems", "Royal Cube pet", "30 min of Cash" }, Product = "StarterPack", Color = Color3.fromRGB(240, 150, 30), Icon = "StarterCrate" },
}

---------------------------------------------------------------------------
-- Cash orbs around the lobby (Auto Collect gamepass pulls them in)
---------------------------------------------------------------------------
Config.ORB_COUNT = 0 -- Alex asked to remove the orbs (Oct 29); set above 0 to bring them back
Config.ORB_RESPAWN = 8
Config.ORB_AUTO_RANGE = 60
Config.ORB_GEM_CHANCE = 0.08

---------------------------------------------------------------------------
-- Missions. Stat = what counts: Shots, Launches, Hatches, CashEarned,
-- Rebirths, Distance (best single launch).
---------------------------------------------------------------------------
Config.Missions = {
	Daily = {
		{ Id = "d_shots",    Text = "Fire 300 Shots",    Stat = "Shots",      Goal = 300, Reward = { Cash = 2500 } },
		{ Id = "d_hatch",    Text = "Hatch 10 Eggs",     Stat = "Hatches",    Goal = 10,  Reward = { Gems = 25 } },
		{ Id = "d_launch",   Text = "Launch 20 Times",   Stat = "Launches",   Goal = 20,  Reward = { Cash = 5000 } },
	},
	Weekly = {
		{ Id = "w_shots",    Text = "Fire 5,000 Shots",  Stat = "Shots",      Goal = 5000, Reward = { Gems = 150 } },
		{ Id = "w_hatch",    Text = "Hatch 100 Eggs",    Stat = "Hatches",    Goal = 100,  Reward = { Gems = 200 } },
		{ Id = "w_rebirth",  Text = "Rebirth 3 Times",   Stat = "Rebirths",   Goal = 3,    Reward = { Gems = 250 } },
	},
	-- Infinite missions level up forever: goal and reward grow each tier.
	Infinite = {
		{ Id = "i_shots",    Text = "Fire %s Shots",     Stat = "Shots",      Goal = 100, GoalGrowth = 2,   Reward = { Gems = 10 } },
		{ Id = "i_launch",   Text = "Launch %s Times",   Stat = "Launches",   Goal = 10,  GoalGrowth = 2,   Reward = { Gems = 10 } },
		{ Id = "i_cash",     Text = "Earn %s Cash",      Stat = "CashEarned", Goal = 1000, GoalGrowth = 3,  Reward = { Gems = 15 } },
	},
}

---------------------------------------------------------------------------
-- Rewards
---------------------------------------------------------------------------
Config.DailyRewards = {
	{ Icon = "DoublePower", Text = "2x Power",  Reward = { Boost = "Power", Minutes = 15 } },
	{ Icon = "CashMedium",  Text = "Cash",      Reward = { CashMinutes = 15 } },
	{ Icon = "Gem",  Text = "50 Gems",   Reward = { Gems = 50 } },
	{ Icon = "Rewards",     Text = "2x Luck",   Reward = { Boost = "Luck", Minutes = 30 } },
	{ Icon = "StarterCrate", Text = "Exclusive", Reward = { Pet = "golden_wing" } },
	{ Icon = "DoubleCash",  Text = "2x Cash",   Reward = { Boost = "Cash", Minutes = 30 } },
	{ Icon = "Quest",       Text = "Secret",    Reward = { Gems = 300, Pet = "rainbow_cube" } },
}
Config.DAILY_COOLDOWN = 20 * 3600 -- can claim again after 20h
Config.DAILY_STREAK_RESET = 48 * 3600 -- streak resets after 48h

Config.PlaytimeRewards = {
	{ Minutes = 3,  Icon = "CashTiny",    Text = "Cash",     Reward = { CashMinutes = 3 } },
	{ Minutes = 8,  Icon = "Gem",  Text = "15 Gems",  Reward = { Gems = 15 } },
	{ Minutes = 15, Icon = "Lucky",       Text = "2x Luck",  Reward = { Boost = "Luck", Minutes = 10 } },
	{ Minutes = 25, Icon = "CashMedium",  Text = "Cash",     Reward = { CashMinutes = 15 } },
	{ Minutes = 40, Icon = "Gem",  Text = "60 Gems",  Reward = { Gems = 60 } },
	{ Minutes = 60, Icon = "DoublePower", Text = "2x Power", Reward = { Boost = "Power", Minutes = 20 } },
	{ Minutes = 90, Icon = "StarterCrate", Text = "Dino Pet", Reward = { Pet = "dino" } },
}

Config.Codes = {
	RELEASE = { Gems = 100 },
	CANNON = { CashMinutes = 20 },
	BOOM = { Boost = "Power", Minutes = 15 },
}

-- Offline earnings: % of your normal Power rate, capped.
Config.OFFLINE_RATE = 0.1
Config.OFFLINE_MAX_HOURS = 8

Config.LEADERBOARDS = {
	{ Id = "Power",    Name = "Power",    Stat = "Power" },
	{ Id = "Distance", Name = "Distance", Stat = "BestDistance" },
	{ Id = "Rebirths", Name = "Rebirths", Stat = "Rebirths" },
	{ Id = "Launches", Name = "Launches", Stat = "TotalLaunches" },
}
Config.LEADERBOARD_REFRESH = 60

-- Sound ids ("rbxassetid://123"). Empty = silent. Music loops in the lobby.
-- Sound ids by name (GameClient/Sfx plays them). "" = Roblox's built-in stand-in plays (or nothing).
-- Never invent an id: each one is either Alex's own upload or a page we read.
-- Button sounds: upload cannon-evolution/assets/sfx/UI_*.ogg (Kenney Interface Sounds, CC0) with
-- Asset Manager > Bulk Import, then paste each rbxassetid here.
Config.Sounds = {
	-- Button sounds: Roblox's own "Roblox_UI_" set (by Roblox, public, no upload), found and load-checked in
	-- Studio's Toolbox on Oct 30 after Alex found the built-in clicks harsh. The Kenney files in assets/sfx
	-- (UI_*.ogg, CC0) are the alternative if uploaded.
	-- Alex, Oct 30: "find out what sounds other popular games use". Big simulators use this same licensed library
	-- (Pro Sound Effects / APM): a bubble "pop" click, a coin bounce, a dry boom. Found with AssetService:SearchAudio.
	Click = "rbxassetid://9112872239", -- "Small Bubbles Water Surface Float Up Pop 5 (SFX)", ProSoundEffects (Sfx plays 0.25 s)
	Hover = "", -- silent: a tick on every hover was too much
	Open = "rbxassetid://15675012262", -- "Roblox_UI_Whoosh_04", 0.35 s
	Close = "rbxassetid://15675028888", -- "Roblox_UI_Whoosh_02", 0.49 s
	Confirm = "rbxassetid://9038924756", -- "Happy Forever - Hit3", APMOfficial, ~2 s (Sfx plays its first 0.6 s)
	Error = "rbxassetid://15675075163", -- "Roblox_UI_Delete", 0.61 s
	Tab = "rbxassetid://15675032796", -- "Roblox_UI_Small_Click", 0.13 s
	-- "Magic Burst 2 (SFX)" by @ProSoundEffects, Roblox's free licensed library (public, no upload):
	-- https://create.roblox.com/store/asset/9116384799/Magic-Burst-2-SFX
	Hatch = "rbxassetid://9116384799",
	-- Roblox's free licensed library too (found with Studio's Toolbox search on Oct 30, each loaded in Studio;
	-- picked by title and length, not yet heard by Alex: swap any one by changing its id):
	Reward = "rbxassetid://1840076509", -- "Through the Roof (sting)", APMOfficial, 2.25 s: a playful organ sting
	-- "Through the Looking Glass (sting)", APMOfficial, 8 s: a magical glockenspiel "ta-da" (Huzz Valley's Secret sting)
	Rebirth = "rbxassetid://1840018171",
	Unlock = "rbxassetid://9116405618", -- "Magic Poofs Short Breathy Bursts Punchy 2 (SFX)", ProSoundEffects
	Coin = "rbxassetid://9113848469", -- "Coin Bounce 3 (SFX)", ProSoundEffects: Sfx plays only its first 0.35 s
	Shot = "rbxassetid://9043341682", -- "DRY BOOM 01", APMOfficial, ~1 s (Sfx plays 0.8 s); assets/sfx/Shot.ogg (crack + boom) if uploaded
	Launch = "rbxassetid://9125805579", -- "Rising Whoosh Hissing Build Up Ascending Swo (SFX)", ProSoundEffects, 1.14 s
	Skip = "rbxassetid://9120589933", -- "Water Splash Splashes Splats Light 5 (SFX)", ProSoundEffects, 0.41 s
	-- the ball's final landing (Alex, Oct 30: "a big splash sound"); found with Studio's Creator Store search, public and free
	Splash = "rbxassetid://9120585530", -- "Water Splash Big Water Splash Dive In 3 (SFX)", ProSoundEffects, 2.7 s, Sfx cuts it at 1 s
	Music = "",
}

---------------------------------------------------------------------------
-- Saved data template
---------------------------------------------------------------------------
Config.DefaultData = {
	Power = 0,
	Cash = 0,
	Gems = 0,
	Rebirths = 0,
	BestDistance = 0,
	TotalLaunches = 0,
	Upgrades = {},
	Pets = {}, -- array of { Id = uid, Name = petKey, Equipped = bool }
	NextPetUid = 1,
	Cannons = { Starter = true },
	EquippedCannon = "Starter",
	Balls = { Wood = true },
	EquippedBall = "Wood",
	Boosts = {}, -- [boostId] = seconds remaining
	Products = {}, -- owned product grants that are permanent (cannons), plus receipt ids
	Stats = { Shots = 0, Launches = 0, Hatches = 0, CashEarned = 0, Rebirths = 0 },
	Missions = { DailyKey = "", WeeklyKey = "", Daily = {}, Weekly = {}, Infinite = {} },
	Daily = { Streak = 0, LastClaim = 0 },
	Codes = {},
	Settings = { Music = true, Sfx = true, ShowPlayers = true, ShowPets = true, LowGraphics = false },
	LastOnline = 0,
	Receipts = {},
	Tutorial = 0, -- last tutorial step finished
}

---------------------------------------------------------------------------
-- Formulas shared by server and client
---------------------------------------------------------------------------
function Config.Level(data, id)
	return data.Upgrades[id] or 0
end

function Config.PetBoost(data)
	local total = 0
	for _, pet in ipairs(data.Pets) do
		if pet.Equipped then
			local info = Config.Pets[pet.Name]
			total += info and info.Boost or 0
		end
	end
	return total
end

-- Everything that multiplies Power per shot (except gamepasses / boosts,
-- which the server adds since it knows ownership and timers).
function Config.PowerMultiplier(data)
	local cannon = Config.GetCannon(data.EquippedCannon)
	return (1 + data.Rebirths * Config.REBIRTH_POWER_BONUS)
		* (1 + Config.Level(data, "Power") * 0.10)
		* (1 + Config.Level(data, "Gunpowder") * 0.08)
		* (cannon and cannon.Mult or 1)
		* (1 + Config.PetBoost(data))
end

function Config.CashMultiplier(data)
	local ball = Config.GetBall(data.EquippedBall)
	return (1 + data.Rebirths * Config.REBIRTH_CASH_BONUS) * (1 + Config.Level(data, "Cash") * 0.10) * (1 + (ball and ball.CashBonus or 0))
end

function Config.ShotInterval(data)
	return math.max(Config.MIN_SHOT_INTERVAL, Config.SHOT_INTERVAL - Config.Level(data, "Reload") * 0.03)
end

function Config.LuckMultiplier(data)
	return 1 + Config.Level(data, "Luck") * 0.05
end

function Config.CritChance(data)
	return Config.Level(data, "Crit") * 0.01
end

function Config.RangeMultiplier(data)
	return (1 + Config.Level(data, "Range") * 0.04) * (1 + Config.Level(data, "Barrel") * 0.06)
end

function Config.LaunchSpeed(power, rangeMult)
	local speed = Config.LAUNCH_BASE_SPEED + math.sqrt(math.max(power, 0)) * Config.LAUNCH_SPEED_PER_SQRT
	speed *= math.sqrt(rangeMult or 1) -- range scales with speed^2
	return math.min(speed, Config.LAUNCH_MAX_SPEED)
end

function Config.LaunchVelocity(power, rangeMult)
	local angle = math.rad(Config.LAUNCH_ANGLE)
	local dir = (Config.LAUNCH_DIRECTION.Unit * math.cos(angle) + Vector3.yAxis * math.sin(angle)).Unit
	return dir * Config.LaunchSpeed(power, rangeMult)
end

-- Seconds a launch takes to skip its whole distance
function Config.FlightTime(distance)
	return math.clamp(2.5 + math.sqrt(distance) * 0.09, 3, 14)
end

function Config.MaxRange(power, rangeMult)
	local v = Config.LaunchSpeed(power, rangeMult)
	return v * v * math.sin(2 * math.rad(Config.LAUNCH_ANGLE)) / workspace.Gravity
end

-- "Cash per minute" used for cash packs and rewards, so they stay useful
-- at every stage of the game.
function Config.CashPerMinute(data)
	local distance = math.max(data.BestDistance, 100)
	return math.floor(distance * Config.CASH_PER_STUD * Config.CashMultiplier(data) * 10)
end

-- Same idea for Power packs: minutes of training at the best station you can use.
function Config.PowerPerMinute(data, hasVip)
	local best = Config.Stations[1]
	for _, s in ipairs(Config.Stations) do
		if (s.Pass == nil and data.Rebirths >= s.Rebirths) or (s.Pass and hasVip) then
			if s.Gain > best.Gain then
				best = s
			end
		end
	end
	return math.floor(best.Gain * Config.PowerMultiplier(data) * 60 / Config.ShotInterval(data))
end

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
function Config.Format(n)
	n = math.floor(n or 0)
	if math.abs(n) < 1000 then
		return tostring(n)
	end
	local i = 1
	while math.abs(n) >= 1000 and i < #SUFFIXES do
		n /= 1000
		i += 1
	end
	local fmt = n >= 100 and "%.0f%s" or (n >= 10 and "%.1f%s" or "%.2f%s")
	return string.format(fmt, n, SUFFIXES[i])
end

function Config.FormatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

return Config
