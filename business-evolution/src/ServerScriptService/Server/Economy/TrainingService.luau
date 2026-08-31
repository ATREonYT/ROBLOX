--!strict
-- Training bags. Stand on a bag's pad and it pays out every HitInterval:
--
--   payout = clickIncome x bagMultiplier(bag, yourRestructures)
--
-- The rebirth term is the whole point — the same bag keeps getting better, so
-- a Restructure visibly pays off the moment you walk back to the yard.
-- Locked bags pay nothing and say so.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(ServerScriptService.Server.Data.DataService)
local Stack = require(ServerScriptService.Server.Economy.Stack)
local Net = require(ServerScriptService.Server.Net.Net)

local TrainingBags = require(ReplicatedStorage.Shared.Config.TrainingBags)
local Trove = require(ReplicatedStorage.Packages.Trove)

local TrainingService = {}

local trove = Trove.new()
local WorldService: any = nil

-- How close to a bag's pad counts as "on it".
local PAD_RADIUS = 9

function TrainingService:Init() end

function TrainingService:Start()
	local worldFolder = ServerScriptService:WaitForChild("Server"):WaitForChild("World")
	WorldService = require(worldFolder:WaitForChild("WorldService") :: ModuleScript) :: any

	trove:Add(task.spawn(function()
		while true do
			task.wait(TrainingBags.HitInterval)
			local hub = WorldService.hub()
			if not hub then
				continue
			end
			for _, player in Players:GetPlayers() do
				local data = DataService.get(player)
				local character = player.Character
				local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
				if not (data and root and root:IsA("BasePart")) then
					continue
				end

				-- Highest-paying bag the player is standing on. Highest, not
				-- first, so overlapping pads can never pay the wrong tier.
				local bestPayout = 0
				local bestName: string? = nil
				local lockedName: string? = nil
				for _, entry in hub.TrainingBags do
					local pad = entry.Pad
					if (pad.Position - root.Position).Magnitude > PAD_RADIUS then
						continue
					end
					local bag = TrainingBags.get(entry.BagId)
					if not bag then
						continue
					end
					if not TrainingBags.isUnlocked(bag, data.Restructures) then
						lockedName = bag.Name
						continue
					end
					local payout = Stack.clickIncome(data, DataService.passesFor(player))
						* TrainingBags.multiplierFor(bag, data.Restructures)
					if payout > bestPayout then
						bestPayout = payout
						bestName = bag.Name
					end
				end

				if bestPayout > 0 then
					DataService.update(player, function(live)
						live.Productivity += bestPayout
					end)
					Net.sendTo(player, "ClickResult", {
						Amount = bestPayout,
						Crit = "none",
						Kind = "train",
						Label = bestName,
					})
				elseif lockedName then
					-- Silent on the economy, loud in the UI: the player needs to
					-- know the bag is real and what unlocks it.
					Net.sendTo(player, "ClickResult", {
						Amount = 0,
						Crit = "none",
						Kind = "locked",
						Label = lockedName,
					})
				end
			end
		end
	end))
end

return TrainingService
