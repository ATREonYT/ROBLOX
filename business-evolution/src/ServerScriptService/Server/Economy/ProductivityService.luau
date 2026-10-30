--!strict
-- Every Productivity faucet lives here: manual clicks (crits rolled on the
-- server so a hacked client can never force one), plus the once-a-second idle
-- tick that pays chairs + interns and Delegate-pass auto-clicks (the training
-- bags in the hub are TrainingService's job). All grants flow through DataService.update and echo back as a
-- ClickResult so the client can pop numbers without owning any math.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ServerScriptService.Server.Net.Net)
local DataService = require(ServerScriptService.Server.Data.DataService)
local Stack = require(ServerScriptService.Server.Economy.Stack)

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Monetization = require(Shared.Config.Monetization)

local Trove = require(ReplicatedStorage.Packages.Trove)
local t = require(ReplicatedStorage.Packages.t)

local ProductivityService = {}

local trove = Trove.new()

-- Overtime: the genre's verified retention hook — after ~15 minutes in one
-- session, a free auto-clicker kicks in (session-only, not saved). Tracked
-- per join, announced exactly once.
local sessionStart: { [Player]: number } = {}
local overtimeAnnounced: { [Player]: boolean } = {}

-- One roll decides both crit tiers. Big is checked first because both ranges
-- start at zero — testing the common crit first would swallow every big crit.
local function rollCrit(): (number, string)
	local roll = math.random()
	if roll < Balance.BigCritChance then
		return Balance.BigCritMultiplier, "big"
	elseif roll < Balance.BigCritChance + Balance.CritChance then
		return Balance.CritMultiplier, "crit"
	end
	return 1, "none"
end

local function onRequestClick(player: Player)
	local data = DataService.get(player)
	if not data then
		return -- profile still loading; the click is quietly lost
	end
	local passes = DataService.passesFor(player)
	local multiplier, crit = rollCrit()
	local amount = Stack.clickIncome(data, passes) * multiplier
	DataService.update(player, function(live)
		live.Productivity += amount
		live.TotalClicks += 1
	end)
	Net.sendTo(player, "ClickResult", { Amount = amount, Crit = crit, Kind = "click" })
end

local function runIdleTick()
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data then
			local passes = DataService.passesFor(player)
			local clickIncome = Stack.clickIncome(data, passes)

			-- Chair + equipped interns.
			local earned = Stack.idlePerSecond(data, passes) * Balance.IdleTickSeconds

			-- Delegate pass: a phantom employee clicking for you.
			if passes.Delegate then
				earned += Monetization.DelegateClicksPerSecond * clickIncome * Balance.IdleTickSeconds
			end

			-- Overtime: free auto-clicks once the session is long enough.
			local started = sessionStart[player]
			if started and os.clock() - started >= Balance.OvertimeAfterMinutes * 60 then
				earned += Balance.OvertimeClicksPerSecond * clickIncome * Balance.IdleTickSeconds
				if not overtimeAnnounced[player] then
					overtimeAnnounced[player] = true
					-- Personal Fx so the HUD can toast it; other clients ignore
					-- kinds they don't handle.
					Net.sendTo(player, "Fx", { Kind = "Overtime", UserId = player.UserId })
				end
			end

			if earned > 0 then
				DataService.update(player, function(live)
					live.Productivity += earned
				end)
				-- One batched ClickResult per tick keeps remote traffic flat no
				-- matter how many passive faucets are running at once.
				Net.sendTo(player, "ClickResult", { Amount = earned, Crit = "none", Kind = "train" })
			end
		end
	end
end

function ProductivityService:Init()
	-- Nothing to wire before other services exist; all hookup happens in Start.
end

function ProductivityService:Start()
	-- 22/s sits just above Balance.MaxClicksPerSecond on purpose: a legit
	-- player clicking at the cap through jitter never gets silently dropped.
	Net.bind("RequestClick", 22, 25, t.tuple(), onRequestClick)

	for _, player in Players:GetPlayers() do
		sessionStart[player] = os.clock()
	end
	trove:Connect(Players.PlayerAdded, function(player)
		sessionStart[player] = os.clock()
	end)
	trove:Connect(Players.PlayerRemoving, function(player)
		sessionStart[player] = nil
		overtimeAnnounced[player] = nil
	end)

	trove:Add(task.spawn(function()
		while true do
			task.wait(Balance.IdleTickSeconds)
			runIdleTick()
		end
	end))
end

return ProductivityService
