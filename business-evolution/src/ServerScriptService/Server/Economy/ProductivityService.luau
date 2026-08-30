--!strict
-- Every Productivity faucet lives here: manual clicks (crits rolled on the
-- server so a hacked client can never force one), plus the once-a-second idle
-- tick that pays chairs + interns, training-zone squatters, and Delegate-pass
-- auto-clicks. All grants flow through DataService.update and echo back as a
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

-- The manifest slice this service consumes. Typed locally because MapService
-- belongs to another agent and is resolved as `any` in Start.
type TrainingZone = { Rate: number, MinRank: number, Zone: BasePart }

local ProductivityService = {}

local trove = Trove.new()

-- Other agents' services. Resolved in Start (the cross-service phase) instead
-- of at the top of the file so Main stays free to load services in any order.
local MapService: any = nil
local FloorService: any = nil

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

-- Object-space box test so the check stays honest even if a floor builder
-- rotates the zone part. Y gets slack because the root part floats a few
-- studs above the carpet while zone parts may be thin floor pads.
local function isInsideZone(zone: BasePart, position: Vector3): boolean
	local localPosition = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(localPosition.X) <= half.X
		and math.abs(localPosition.Y) <= half.Y + 4
		and math.abs(localPosition.Z) <= half.Z
end

-- The best training rate the player is currently earning: highest eligible
-- zone they stand in — highest rather than first, so overlapping zone parts
-- can never pay twice or pay the wrong tier.
local function trainingRateFor(player: Player, rank: number): number
	if MapService == nil or FloorService == nil then
		return 0
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (root and root:IsA("BasePart")) then
		return 0
	end
	local floorId = FloorService.floorOf(player)
	if type(floorId) ~= "string" then
		return 0
	end
	local manifests = MapService.allManifests()
	local manifest = if type(manifests) == "table" then manifests[floorId] else nil
	if manifest == nil or manifest.TrainingZones == nil then
		return 0
	end
	local best = 0
	for _, entry in manifest.TrainingZones :: { TrainingZone } do
		if rank >= entry.MinRank and entry.Rate > best and isInsideZone(entry.Zone, root.Position) then
			best = entry.Rate
		end
	end
	return best
end

local function runIdleTick()
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data then
			local passes = DataService.passesFor(player)
			local clickIncome = Stack.clickIncome(data, passes)

			-- Chair + equipped interns.
			local earned = Stack.idlePerSecond(data, passes) * Balance.IdleTickSeconds

			-- Training zones pay in click-equivalents (DESIGN-MAP: tier rate ×
			-- what one click is worth right now).
			local trainingRate = trainingRateFor(player, data.Rank)
			earned += trainingRate * clickIncome * Balance.IdleTickSeconds

			-- Delegate pass: a phantom employee clicking for you.
			if passes.Delegate then
				earned += Monetization.DelegateClicksPerSecond * clickIncome * Balance.IdleTickSeconds
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
	-- These modules belong to other agents; requiring them here (not at the
	-- top of the file) keeps the module graph free of load-order traps. By the
	-- time any Start runs, Main has required everything, so these never yield.
	local serverFolder = ServerScriptService:WaitForChild("Server")
	local worldFolder = serverFolder:WaitForChild("World")
	local progressionFolder = serverFolder:WaitForChild("Progression")
	MapService = require(worldFolder:WaitForChild("MapService") :: ModuleScript) :: any
	FloorService = require(progressionFolder:WaitForChild("FloorService") :: ModuleScript) :: any

	-- 22/s sits just above Balance.MaxClicksPerSecond on purpose: a legit
	-- player clicking at the cap through jitter never gets silently dropped.
	Net.bind("RequestClick", 22, 25, t.tuple(), onRequestClick)

	trove:Add(task.spawn(function()
		while true do
			task.wait(Balance.IdleTickSeconds)
			runIdleTick()
		end
	end))
end

return ProductivityService
