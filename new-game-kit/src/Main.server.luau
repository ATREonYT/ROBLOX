--!strict
-- New Game Kit: bootstrap (the ONLY server Script) (adapted from LihFolk Systems, CC BY 4.0)
-- Install: ServerScriptService/Main (Script)
--
-- Order matters:
--   1. PlayerData.Configure            (store name, schema, migrations)
--   2. Policy.Init, then every service .Init(config)  (slices + remotes)
--   3. Cross-module hooks              (luck sources, custom grants, quest feeds)
--   4. Receipts.Start                  (asserts every product has a grant; sets ProcessReceipt)
--   5. PlayerData.Start                (loads players; nothing loads before slices exist)
-- Remove the services you do not use (and their config sections).
-- Status: reviewed, not run in Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Server = ServerScriptService:WaitForChild("Kit")
local Config = require(ReplicatedStorage:WaitForChild("GameConfig")) :: any
local Secrets = require(ServerStorage:WaitForChild("GameSecrets")) :: any

local PlayerData = require(Server.PlayerData)
local Policy = require(Server.Policy)
local Currency = require(Server.Currency)
local Inventory = require(Server.Inventory)
local Receipts = require(Server.Receipts)
local Shop = require(Server.Shop)
local EggHatch = require(Server.EggHatch)
local Codes = require(Server.Codes)
local DailyRewards = require(Server.DailyRewards)
local Rebirth = require(Server.Rebirth)
local Quests = require(Server.Quests)
local Leaderboard = require(Server.Leaderboard)
local Upgrades = require(Server.Upgrades)
local Income = require(Server.Income)
local Pets = require(Server.Pets)
local PlaytimeGifts = require(Server.PlaytimeGifts)
local Settings = require(Server.Settings)
local ErrorLog = require(Server.ErrorLog)

-- 0. Error groups and save health first, so start-up errors are counted (note 18 §7.4)
ErrorLog.Start(PlayerData)

-- 1. Data layer
PlayerData.Configure(Config.PlayerData)

-- 2. Services (each registers its profile slice and remotes)
Policy.Init()
Currency.Init(Config.Currency)
Inventory.Init(Config.Inventory)
Receipts.Init(Config.Receipts)
Shop.Init(Config.Shop)
EggHatch.Init(Config.Eggs)
Codes.Init(Secrets.Codes)
DailyRewards.Init(Config.Daily)
Rebirth.Init(Config.Rebirth)
Quests.Init(Config.Quests)
Upgrades.Init(Config.Upgrades)
Pets.Init(Config.Pets)
PlaytimeGifts.Init(Config.PlaytimeGifts)
Settings.Init(Config.Settings)
local incomeConfig = table.clone(Config.Income)
incomeConfig.perSecondStat = function(player: Player): number
	return Upgrades.Value(player, "Income")
end
Income.Init(incomeConfig)

local boards = table.clone(Config.Leaderboard.boards)
boards.CoinsEarned = table.clone(boards.CoinsEarned)
-- Sources read the profile they are given: on leave the profile is already
-- detached, so PlayerData.Get(player) would return nil for the final write.
boards.CoinsEarned.source = function(_player: Player, profile: PlayerData.Profile): number
	return profile.Data.Currency.Earned.Coins or 0
end
Leaderboard.Init({
	boards = boards,
	writeSeconds = Config.Leaderboard.writeSeconds,
	refreshSeconds = Config.Leaderboard.refreshSeconds,
})

-- 3. Cross-module hooks
-- Game pass benefits are derived from the server ownership cache, never saved.
Currency.AddMultiplier("Coins", function(player: Player): number
	return if Shop.OwnsPass(player, "DoubleCoins") then 2 else 1
end)
-- A paid luck pass is a probability modifier: marked paid, so restricted
-- players do not get it and their displayed odds stay at base luck.
EggHatch.AddLuckSource("LuckyPass", true, function(player: Player): number
	return if Shop.OwnsPass(player, "LuckyPass") then 1.5 else 1
end)

Receipts.SetCustomGrant("LuckBoost2x", function(player: Player): boolean
	return EggHatch.GrantTimedBoost(player, 2, 15 * 60, true)
end)
Receipts.SetPromptCheck("LuckBoost2x", function(player: Player): (boolean, string?)
	if EggHatch.IsAtMaxLuck(player) then
		return false, "AtMaxLuck" -- never sell a boost that does nothing
	end
	if not EggHatch.CanAddTimedBoost(player) then
		return false, "BoostLimit" -- room check first, so the paid grant never has to merge
	end
	return true, nil
end)
Receipts.SetCustomGrant("RoyalHatch", function(player: Player): boolean
	return EggHatch.GrantPaidHatch(player, "Royal", 1)
end)

-- Rebirth resets the upgrades marked keepOnRebirth = false.
Rebirth.Rebirthed:Connect(function(player: Player)
	Upgrades.ResetForRebirth(player)
end)

-- Walk speed upgrade: applied by the server on every spawn and every level up.
local function applyWalkSpeed(player: Player)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		humanoid.WalkSpeed = Upgrades.Value(player, "WalkSpeed")
	end
end
PlayerData.Loaded:Connect(function(player: Player)
	player.CharacterAdded:Connect(function()
		applyWalkSpeed(player)
	end)
	applyWalkSpeed(player)
end)
Upgrades.Changed:Connect(function(player: Player, key: string)
	if key == "WalkSpeed" then
		applyWalkSpeed(player)
	end
end)

-- Quest progress comes only from server systems.
Currency.Changed:Connect(function(player: Player, name: string, _balance: number, delta: number, reason: string)
	if name == "Coins" and delta > 0 and reason == "pickup" then
		Quests.Report(player, "Collect", "Coin", delta)
	end
end)

EggHatch.Hatched:Connect(function(player: Player, eggId: string, results: { any })
	Quests.Report(player, "Hatch", eggId, #results)
	for _, result in results do
		Pets.Discover(player, result.item)
	end
	Leaderboard.Add(player, "WeeklyHatches", #results)
end)

-- 4. Purchases
Receipts.Start()

-- 5. Load players last
PlayerData.Start()
