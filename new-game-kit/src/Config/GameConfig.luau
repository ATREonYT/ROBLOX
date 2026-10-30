--!strict
-- New Game Kit: shared game config (EXAMPLE VALUES - replace with yours) (adapted from LihFolk Systems, CC BY 4.0)
-- Install: ReplicatedStorage/GameConfig (ModuleScript)
--
-- Everything here is display-safe: names, prices, odds, quests. The client
-- reads it to draw UI; the server reads its OWN copy to decide outcomes, so
-- editing the client copy changes nothing. Secrets (codes) live in
-- ServerStorage/GameSecrets instead.
-- Every module asserts its part of this config at startup.

local Config = {}

Config.PlayerData = {
	storeName = "PlayerData_v1", -- never rename after launch
	schemaVersion = 1,
	-- Studio: saves stay in memory and reset on Stop. Set false to test real
	-- saving in Studio (needs Game Settings > Security > Studio Access to API Services).
	studioResetsProgress = true,
	migrations = {
		-- [2] = function(data) data.Currency.Balances.Gems = data.Currency.Balances.Diamonds or 0 end,
	},
}

Config.Currency = {
	currencies = {
		Coins = { start = 0, paid = false, leaderstat = true },
		-- Gems can be bought with Robux (see products), so anything random
		-- priced in Gems is a PAID random item.
		Gems = { start = 0, paid = true },
	},
	maxMultiplier = 1000,
}

Config.Inventory = {
	uniqueCapacity = 200,
	maxEquipped = 3,
	items = {
		SpeedPotion = { name = "Speed Potion", stackable = true, maxStack = 99 },
		Dog = { name = "Dog", stackable = false, equippable = true, tradable = true },
		Cat = { name = "Cat", stackable = false, equippable = true, tradable = true },
		Bunny = { name = "Bunny", stackable = false, equippable = true, tradable = true },
		Fox = { name = "Fox", stackable = false, equippable = true, tradable = true },
		Dragon = { name = "Dragon", stackable = false, equippable = true, tradable = true },
		GoldenDragon = { name = "Golden Dragon", stackable = false, equippable = true, tradable = false },
	},
}

Config.Eggs = {
	maxLuck = 8,
	eggs = {
		Basic = {
			name = "Basic Egg",
			price = { currency = "Coins", amount = 100 },
			hatchCounts = { 1, 3 },
			tiers = {
				{ name = "Common", weight = 75, items = { { id = "Dog", weight = 1 }, { id = "Cat", weight = 1 } } },
				{ name = "Rare", weight = 22, lucky = true, items = { { id = "Bunny", weight = 1 } } },
				{ name = "Legendary", weight = 3, lucky = true, items = { { id = "Fox", weight = 1 } } },
			},
			pity = { tier = "Legendary", rolls = 60 },
		},
		Royal = {
			name = "Royal Egg",
			price = { currency = "Gems", amount = 50 }, -- Gems are paid: PolicyService gated
			hatchCounts = { 1 },
			restrictedNote = "Royal Egg pets can be earned from quests instead.",
			tiers = {
				{ name = "Rare", weight = 80, items = { { id = "Bunny", weight = 1 } } },
				{ name = "Legendary", weight = 19.5, lucky = true, items = { { id = "Fox", weight = 2 }, { id = "Dragon", weight = 1 } } },
				{ name = "Mythic", weight = 0.5, lucky = true, items = { { id = "GoldenDragon", weight = 1, once = true } } },
			},
			pity = { tier = "Legendary", rolls = 20 },
		},
	},
}

Config.Shop = {
	items = {
		SpeedPotion = {
			price = { currency = "Coins", amount = 250 },
			reward = { kind = "item", item = "SpeedPotion", count = 1 },
			maxQuantity = 10,
		},
	},
	passes = {
		-- Replace 0 with real Game Pass ids from the Creator Dashboard.
		DoubleCoins = { id = 0, name = "2x Coins" },
		LuckyPass = { id = 0, name = "Lucky", paidModifier = true }, -- paid luck: a probability modifier
	},
}

Config.Receipts = {
	products = {
		-- Replace 0 with real Developer Product ids. Prices are NOT stored here:
		-- the client shows GetProductInfoAsync's PriceInRobux (regional pricing).
		Gems100 = { id = 0, name = "100 Gems", reward = { kind = "currency", currency = "Gems", amount = 100 } },
		StarterPack = {
			id = 0,
			name = "Starter Pack",
			limit = 1,
			reward = { kind = "bundle", rewards = {
				{ kind = "currency", currency = "Coins", amount = 5000 },
				{ kind = "item", item = "SpeedPotion", count = 3 },
			} },
		},
		LuckBoost2x = { id = 0, name = "2x Luck (15 min)", paidRandom = true, custom = "LuckBoost2x" },
		RoyalHatch = { id = 0, name = "Royal Egg Hatch", paidRandom = true, custom = "RoyalHatch" },
	},
}

Config.Daily = {
	resetOffsetHours = 0,
	graceDays = 0,
	track = {
		{ kind = "currency", currency = "Coins", amount = 100 },
		{ kind = "currency", currency = "Coins", amount = 200 },
		{ kind = "currency", currency = "Coins", amount = 300 },
		{ kind = "item", item = "SpeedPotion", count = 1 },
		{ kind = "currency", currency = "Coins", amount = 500 },
		{ kind = "currency", currency = "Coins", amount = 750 },
		{ kind = "bundle", rewards = {
			{ kind = "currency", currency = "Coins", amount = 1500 },
			{ kind = "item", item = "SpeedPotion", count = 2 },
		} },
	},
}

Config.Rebirth = {
	currency = "Coins",
	baseCost = 250, -- first rebirth ~1.5 min, each run ~1.5x longer (tools/pace.luau)
	growth = 3.5,
	bonusPerRebirth = 0.25,
	maxBulk = 1000,
}

-- Levels bought with Coins. "stat" upgrades are read with Upgrades.Value.
Config.Upgrades = {
	upgrades = {
		Income = { name = "More Coins/s", currency = "Coins", baseCost = 100, growth = 1.35, maxLevel = 100, effect = { kind = "stat", perLevel = 1, base = 0 } },
		CoinBoost = { name = "Coin Boost", currency = "Coins", baseCost = 200, growth = 1.6, maxLevel = 50, effect = { kind = "multiplier", currency = "Coins", perLevel = 0.1 } },
		WalkSpeed = { name = "Walk Speed", currency = "Coins", baseCost = 100, growth = 1.5, maxLevel = 20, keepOnRebirth = false, effect = { kind = "stat", perLevel = 1, base = 16 } },
	},
}

-- Cash every second (base + the Income upgrade), tap to earn, and a capped
-- offline payout so there is a reason to come back tomorrow.
Config.Income = {
	currency = "Coins",
	perSecond = 1,
	tap = 1,
	tapsPerSecond = 8,
	offline = { rate = 0.5, maxHours = 2 },
}

-- Equipped pets boost Coins; first-time pets fill the Index and give Gems.
Config.Pets = {
	currency = "Coins",
	boosts = { Dog = 0.1, Cat = 0.1, Bunny = 0.25, Fox = 0.5, Dragon = 1, GoldenDragon = 2 },
	discoverReward = { kind = "currency", currency = "Gems", amount = 5 },
}

-- Free gifts for staying (real timers, reset each session).
Config.PlaytimeGifts = {
	gifts = {
		{ minutes = 1, reward = { kind = "currency", currency = "Coins", amount = 100 } },
		{ minutes = 5, reward = { kind = "currency", currency = "Coins", amount = 500 } },
		{ minutes = 10, reward = { kind = "item", item = "SpeedPotion", count = 1 } },
		{ minutes = 20, reward = { kind = "currency", currency = "Gems", amount = 10 } },
		{ minutes = 30, reward = { kind = "currency", currency = "Coins", amount = 5000 } },
	},
}

-- Comfort and performance toggles (kid-safe: flashes and shake can be turned off).
Config.Settings = {
	defaults = {
		Music = true,
		Sounds = true,
		Flashes = true,
		ScreenShake = true,
		HideOtherPets = false,
		LowGraphics = false,
	},
}

-- Pacing targets (seconds from join, a fresh save, a kid tapping 4 times a second), checked by
-- tools/pace.luau within `tolerance` (vault note 12 §3, note 14 §7; Stone Skipping's first
-- rebirth is at ~85 s). Tune the prices above until it passes.
Config.Pacing = {
	botTapsPerSecond = 4,
	egg = "Basic",
	firstPayoff = 1,
	firstPurchase = 30,
	firstHatch = 60,
	rebirths = { 90, 240, 480, 840 }, -- each run about 1.5-1.8x longer than the last
	tolerance = 0.3,
	saveAt = 0.6,
}

-- The HUD arrives a piece at a time (vault note 14 §2, like Stone Skipping's tutorial):
-- a new player sees the verb and one number; each step brings in the one button it needs,
-- glowing; everything else pops in after the first rebirth. A step is done when the player
-- attribute reaches the number (done steps stay done, so a returning player picks up where
-- they left off). Anyone with a rebirth gets the full HUD. Names: "Tap", "TopBar.<pill>",
-- "Menu.<button>". Set Config.HudStages = nil to show everything from the start.
Config.HudStages = {
	{ Step = "Tap", Show = { "Tap", "TopBar.Coins" }, Spotlight = "Tap", DoneWhen = { attr = "Coins", atLeast = 50 } },
	{ Step = "Upgrade", Show = { "Menu.Upgrades" }, Spotlight = "Menu.Upgrades", DoneWhen = { attr = "Upgrade_Income", atLeast = 1 } },
	{ Step = "Hatch", Show = { "Menu.Eggs" }, Spotlight = "Menu.Eggs", DoneWhen = { attr = "Discovered", atLeast = 1 } },
	{ Step = "Rebirth", Show = { "Menu.Rebirth", "TopBar.Rebirths" }, Spotlight = "Menu.Rebirth", DoneWhen = { attr = "Rebirths", atLeast = 1 } },
	{ Step = "Done", Show = "*" },
}

Config.Quests = {
	quests = {
		{
			id = "FirstCoins",
			title = "Pocket Money",
			objectives = { { kind = "Collect", target = "Coin", amount = 50, text = "Collect 50 coins" } },
			reward = { kind = "currency", currency = "Coins", amount = 250 },
		},
		{
			id = "FirstHatch",
			title = "Egg Curious",
			requires = { "FirstCoins" },
			objectives = { { kind = "Hatch", target = "*", amount = 3, text = "Hatch 3 eggs" } },
			reward = { kind = "item", item = "SpeedPotion", count = 2 },
		},
		{
			id = "RoyalFriend",
			title = "Royal Friend",
			requires = { "FirstHatch" },
			objectives = { { kind = "Hatch", target = "Basic", amount = 100, text = "Hatch 100 Basic Eggs" } },
			-- Free earnable path to a Royal Egg pet for players who cannot buy paid random items.
			reward = { kind = "item", item = "Dragon", count = 1 },
		},
	},
}

Config.Leaderboard = {
	writeSeconds = 120,
	refreshSeconds = 120,
	boards = {
		-- Source boards read the profile; counter boards are fed with Leaderboard.Add.
		CoinsEarned = { storeName = "LB_CoinsEarned_v1", period = "all" }, -- source set in Main
		WeeklyHatches = { storeName = "LB_WeeklyHatches_v1", period = "weekly" },
	},
}

return Config
