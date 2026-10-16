-- Starts every server service in order.
local SoundService = game:GetService("SoundService")
local HuzzServer = script.Parent

-- Sound groups the Audio settings control (each player's client sets its own volumes).
local master = SoundService:FindFirstChild("Master") or Instance.new("SoundGroup")
master.Name = "Master"
master.Parent = SoundService
for _, name in { "Music", "Effects" } do
	local g = master:FindFirstChild(name) or Instance.new("SoundGroup")
	g.Name = name
	g.Parent = master
end

-- Studio only: the owner's raw animations go where clients can play them (Shared/AnimationLibrary). In the live
-- game they stay in ServerStorage (published IDs are used there), so nobody downloads 2.7 MB for nothing.
if game:GetService("RunService"):IsStudio() then
	local raw = game:GetService("ServerStorage"):FindFirstChild("HuzzAnimations")
	local RS = game:GetService("ReplicatedStorage")
	if raw and not RS:FindFirstChild("HuzzAnimations") then
		raw:Clone().Parent = RS
	end
end

local DataService = require(HuzzServer.DataService)
local ShopService = require(HuzzServer.ShopService)
local SettingsService = require(HuzzServer.SettingsService)
local CosmeticsService = require(HuzzServer.CosmeticsService)
local ActionService = require(HuzzServer.ActionService)
local CompanionService = require(HuzzServer.CompanionService)

DataService.start()
SettingsService.start()
ShopService.start()
CosmeticsService.start()
ActionService.start()
CompanionService.start()
DataService.onChanged = function(player)
	CosmeticsService.refresh(player)
	CompanionService.refresh(player) -- (the equipped anime girl follows you: Gameplay/Auras)
end
