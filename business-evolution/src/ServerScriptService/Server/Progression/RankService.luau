--!strict
-- The promotion watchdog (§2). Productivity only ever climbs between
-- Restructures, so promotion detection can be a cheap poll: twice a second,
-- compare each loaded player's stored Rank against what the ladder says their
-- Productivity deserves. Half a second keeps the worst case well inside the
-- contract's one-second detection budget, and a handful of players makes the
-- loop essentially free.
--
-- Demotions never happen here — RestructureService owns rank resets (and it
-- calls AppearanceService itself), so this file only ever moves rank UP.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ServerScriptService.Server.Net.Net)
local DataService = require(ServerScriptService.Server.Data.DataService)

local Ranks = require(ReplicatedStorage.Shared.Config.Ranks)
local Trove = require(ReplicatedStorage.Packages.Trove)

local CHECK_INTERVAL = 0.5

local RankService = {}

local trove = Trove.new()
local sinceCheck = 0

local function promote(player: Player, newRank: number)
	DataService.update(player, function(data)
		data.Rank = newRank
		-- BestRank survives Restructure resets, so it only ever moves up.
		data.BestRank = math.max(data.BestRank, newRank)
	end)
	-- Broadcast, not sendTo: promotions are a world-visible moment — RankUpFx
	-- confettis the promoted player and toasts everyone else.
	Net.sendAll("Fx", { Kind = "RankUp", UserId = player.UserId, Rank = newRank })
end

local function checkAllPlayers()
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data then
			-- If several thresholds were crossed in one burst, jump straight
			-- to the final rank: one Fx with the rank that actually sticks.
			local deserved = Ranks.rankForProductivity(data.Productivity)
			if deserved > data.Rank then
				promote(player, deserved)
			end
		end
	end
end

function RankService:Init()
	-- All wiring happens in Start; nothing here may touch other services.
end

function RankService:Start()
	trove:Connect(RunService.Heartbeat, function(dt: number)
		sinceCheck += dt
		if sinceCheck < CHECK_INTERVAL then
			return
		end
		sinceCheck = 0
		checkAllPlayers()
	end)
end

return RankService
