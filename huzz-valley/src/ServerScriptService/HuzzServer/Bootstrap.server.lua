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
