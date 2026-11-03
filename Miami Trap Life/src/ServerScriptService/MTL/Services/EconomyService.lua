--!strict
-- THE only place cash and XP change. Applies 2x passes and boosts, levels players up, keeps leaderstats in sync,
-- logs analytics, and tells the client (Reward / LevelUp remotes). Every other system calls this.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.MTL.Config.Economy)
local LevelRules = require(ReplicatedStorage.MTL.Rules.LevelRules)
local Net = require(ReplicatedStorage.MTL.Net)
local Signal = require(ReplicatedStorage.MTL.Signal)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local Analytics = require(script.Parent.Analytics)

local EconomyService = {}
EconomyService.LevelUp = Signal.new() -- (player, newLevel)
EconomyService.CashChanged = Signal.new() -- (player, newCash, delta, reason)
-- set by DailyCacheService: extra multiplier on shift pay (reason "Job:*"), e.g. 2 while Ms. Bea's luck is on
EconomyService.jobBoost = nil :: ((Player) -> number)?

local function log(...)
	print("[MTL Economy]", ...)
end

local function syncLeaderstats(player: Player, data: any)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		return
	end
	local cash = ls:FindFirstChild("Cash") :: IntValue?
	local level = ls:FindFirstChild("Level") :: IntValue?
	if cash then
		cash.Value = data.Cash
	end
	if level then
		level.Value = data.Level
	end
end

function EconomyService.cashMultiplier(player: Player): number
	local data = DataService.get(player)
	local m = 1
	if MonetizationService.owns(player, "Cash2x") then
		m *= Economy.CashMultiplier.Pass
	end
	if data and data.Boosts.Cash2xSeconds > 0 then
		m *= Economy.CashMultiplier.Boost
	end
	return math.min(m, Economy.CashMultiplier.Max)
end

function EconomyService.xpMultiplier(player: Player): number
	local data = DataService.get(player)
	local m = 1
	if MonetizationService.owns(player, "XP2x") then
		m *= Economy.XPMultiplier.Pass
	end
	if data and data.Boosts.XP2xSeconds > 0 then
		m *= Economy.XPMultiplier.Boost
	end
	return math.min(m, Economy.XPMultiplier.Max)
end

function EconomyService.cash(player: Player): number
	local data = DataService.get(player)
	return if data then data.Cash else 0
end

-- Pays the player. `boosted` = apply 2x (true for earnings; false for refunds, purchases, story grants).
-- Returns the amount actually paid. `at` (optional) = world position for the "+$8" pop.
function EconomyService.addCash(player: Player, amount: number, reason: string, boosted: boolean?, at: Vector3?): number
	local data = DataService.get(player)
	if not data or type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return 0
	end
	local mult = if boosted == false then 1 else EconomyService.cashMultiplier(player)
	if boosted ~= false and EconomyService.jobBoost and string.sub(reason, 1, 4) == "Job:" then
		mult *= EconomyService.jobBoost(player)
	end
	local paid = math.floor(amount * mult + 0.5)
	data.Cash = math.min(data.Cash + paid, Economy.MaxCash)
	data.Stats.Earned += paid
	syncLeaderstats(player, data)
	Analytics.cash(player, true, paid, data.Cash, reason)
	EconomyService.CashChanged:Fire(player, data.Cash, paid, reason)
	Net.get("Reward"):FireClient(player, { cash = paid, at = at, reason = reason })
	DataService.push(player)
	return paid
end

-- Takes money if the player has enough. Returns true on success.
function EconomyService.spend(player: Player, amount: number, reason: string): boolean
	local data = DataService.get(player)
	if not data or type(amount) ~= "number" or amount ~= amount or amount < 0 then
		return false
	end
	amount = math.floor(amount)
	if data.Cash < amount then
		return false
	end
	data.Cash -= amount
	data.Stats.Spent += amount
	syncLeaderstats(player, data)
	Analytics.cash(player, false, amount, data.Cash, reason)
	EconomyService.CashChanged:Fire(player, data.Cash, -amount, reason)
	DataService.push(player)
	return true
end

-- Gives XP (2x applied). Returns the XP given and whether the player levelled up.
function EconomyService.addXP(player: Player, amount: number, reason: string, at: Vector3?): (number, boolean)
	local data = DataService.get(player)
	if not data or type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return 0, false
	end
	local given = math.floor(amount * EconomyService.xpMultiplier(player) + 0.5)
	local level, xp, gained = LevelRules.add(data.Level, data.XP, given)
	data.Level, data.XP = level, xp
	syncLeaderstats(player, data)
	Net.get("Reward"):FireClient(player, { xp = given, at = at, reason = reason })
	for _, l in gained do
		log(player.Name, "reached level", l)
		player:SetAttribute("MTL_Level", l)
		Net.get("LevelUp"):FireClient(player, { level = l, unlocks = LevelRules.unlocks(l) })
		EconomyService.LevelUp:Fire(player, l)
	end
	DataService.push(player)
	return given, #gained > 0
end

local function onReady(player: Player, data: any)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Parent = ls
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Parent = ls
	ls.Parent = player
	player:SetAttribute("MTL_Level", data.Level)
	syncLeaderstats(player, data)

	-- Bridge for older scripts that change leaderstats.Cash directly (the existing StockMarket): any change we
	-- didn't make becomes a real cash change here, so the save stays the truth. (Server-only value: clients can't
	-- write it.) Our own writes always set Value == data.Cash, so they're ignored.
	-- Reads cash.Value NOW rather than the event's argument: with deferred events, two of our own writes in one
	-- frame would otherwise look like an outside change.
	cash.Changed:Connect(function()
		local value = cash.Value
		local d = DataService.get(player)
		if not d or value == d.Cash then
			return
		end
		local delta = value - d.Cash
		if delta > 0 then
			EconomyService.addCash(player, delta, "Stocks:Sell", false)
		elseif not EconomyService.spend(player, -delta, "Stocks:Buy") then
			syncLeaderstats(player, d) -- tried to spend more than they have: put the real number back
		end
	end)
end

function EconomyService.init()
	DataService.Ready:Connect(onReady)

	-- Boosts count down in PLAY time only (no real-time timers), and play time is tracked.
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in Players:GetPlayers() do
				local data = DataService.get(player)
				if data then
					data.Stats.PlayTime += 5
					local b = data.Boosts
					local before = b.XP2xSeconds > 0 or b.Cash2xSeconds > 0
					b.XP2xSeconds = math.max(0, b.XP2xSeconds - 5)
					b.Cash2xSeconds = math.max(0, b.Cash2xSeconds - 5)
					if before then
						DataService.push(player)
					end
				end
			end
		end
	end)
end

-- The existing StockMarket script reads/writes leaderstats.Cash. That works as-is through the bridge in onReady
-- (Jobs piece). Cleaner, when someone has Studio open: point its getCash/setCash here instead:
--   getCash = function(p) return EconomyService.cash(p) end
--   setCash = function(p, v) local d = v - EconomyService.cash(p)
--     if d > 0 then EconomyService.addCash(p, d, "Stocks:Sell", false) elseif d < 0 then EconomyService.spend(p, -d, "Stocks:Buy") end end

return EconomyService
