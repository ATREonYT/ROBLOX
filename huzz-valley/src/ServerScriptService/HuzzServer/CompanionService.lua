--[[
	Your equipped anime girl (owner's call): when the character you've equipped in the Index is one of the
	girls, the player carries two attributes every client reads (HuzzClient/Gameplay/Auras):
	  HuzzCompanion        her key in ReplicatedStorage.HuzzGirls ("G7"), or "" for none
	  HuzzCompanionRarity  her rarity (her effects grow with it; Rare and up also light up YOU)
	  HuzzCompanionPrestige  her prestige level 0..3 (Shared/PrestigeRules: her effects use a rarer tier's look)
	Refreshed whenever the save changes (DataService.onChanged) and once the girls are published.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)

local CompanionService = {}

local function girlFor(id)
	local folder = ReplicatedStorage:FindFirstChild("HuzzGirls")
	if not (folder and type(id) == "string" and id ~= "") then
		return nil
	end
	for _, model in folder:GetChildren() do
		if model:GetAttribute("Id") == id then
			return model
		end
	end
	return nil
end

function CompanionService.refresh(player)
	local profile = DataService.get(player)
	local girl = profile and girlFor(profile.Data.Equipped)
	player:SetAttribute("HuzzCompanion", if girl then girl.Name else "")
	player:SetAttribute("HuzzCompanionRarity", if girl then girl:GetAttribute("Rarity") else "")
	player:SetAttribute("HuzzCompanionPrestige", if girl then ((profile.Data.Prestige or {})[profile.Data.Equipped] or 0) else 0)
end

function CompanionService.start()
	local function joined(player)
		task.spawn(function()
			DataService.waitFor(player, 60)
			CompanionService.refresh(player)
		end)
	end
	Players.PlayerAdded:Connect(joined)
	for _, p in Players:GetPlayers() do
		joined(p)
	end
	-- the girls are published by GirlService a moment after start: refresh everyone then
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild("HuzzGirls", 60)
		if folder then
			task.wait(0.5)
			for _, p in Players:GetPlayers() do
				CompanionService.refresh(p)
			end
		end
	end)
end

return CompanionService
