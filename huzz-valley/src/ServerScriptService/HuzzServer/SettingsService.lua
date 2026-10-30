-- Player settings: validated, saved, and the one place that answers social permission questions.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Config.Settings)
local Net = require(ReplicatedStorage.Shared.Net)
local DataService = require(script.Parent.DataService)

local SettingsService = {}

local MIN_INTERVAL = 0.08 -- sliders send many changes; this keeps a client from flooding saves
local lastSet: { [Player]: number } = {}

function SettingsService.get(player: Player, key: string)
	local profile = DataService.get(player)
	return profile and profile.Data.Settings[key]
end

-- May `viewer` use `owner`'s social feature? key = "InventoryVisibility" or "InviteRequests".
-- Every feature that shows someone's inventory or sends an invite must ask this first.
function SettingsService.allows(owner: Player, viewer: Player, key: string): boolean
	if owner == viewer then return true end
	local choice = SettingsService.get(owner, key) or Settings.Defaults[key]
	if choice == "Everyone" then return true end
	if choice == "Friends" then
		local ok, friends = pcall(owner.IsFriendsWith, owner, viewer.UserId)
		return ok and friends == true
	end
	return false
end

function SettingsService.start()
	(Net.get("SetSetting") :: RemoteFunction).OnServerInvoke = function(player, key, value)
		local now = os.clock()
		if lastSet[player] and now - lastSet[player] < MIN_INTERVAL then return false, "Too fast." end
		lastSet[player] = now
		if type(key) ~= "string" then return false, "Unknown setting." end
		local profile = DataService.get(player)
		if not profile then return false, "Your save is still loading." end
		local clean, why = Settings.validate(key, value, profile.Data.Settings)
		if clean == nil then return false, why end
		DataService.update(player, function(data) data.Settings[key] = clean end)
		return true
	end
	Players.PlayerRemoving:Connect(function(p) lastSet[p] = nil end)
end

return SettingsService
