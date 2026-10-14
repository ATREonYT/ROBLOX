-- Handles the player's actions from the UI (the "Action" remote): equip / favourite companions, favourite dances,
-- claim rewards and quests. Every action is checked here against the player's saved data.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Characters = require(ReplicatedStorage.Shared.Config.Characters)
local Dances = require(ReplicatedStorage.Shared.Config.Dances)
local Net = require(ReplicatedStorage.Shared.Net)
local DataService = require(script.Parent.DataService)
local ProgressService = require(script.Parent.ProgressService)

local ActionService = {}

local MIN_INTERVAL = 0.15
local last: { [Player]: number } = {}

local VERBS: { [string]: (Player, ...any) -> (boolean, string?) } = {}

function VERBS.Equip(player, id)
	if type(id) ~= "string" or not Characters.get(id) then return false, "Unknown companion." end
	local ok, why = false, nil
	DataService.update(player, function(data)
		if not data.Characters[id] then why = "You don't own this companion yet."; return end
		data.Equipped = id
		ok = true
	end)
	return ok, why
end

function VERBS.Unequip(player)
	DataService.update(player, function(data) data.Equipped = "" end)
	return true
end

function VERBS.FavoriteCharacter(player, id, on)
	if type(id) ~= "string" or not Characters.get(id) or type(on) ~= "boolean" then return false, "Unknown companion." end
	DataService.update(player, function(data) data.FavChars[id] = on or nil end)
	return true
end

function VERBS.FavoriteDance(player, id, on)
	if type(id) ~= "string" or not Dances.get(id) or type(on) ~= "boolean" then return false, "Unknown dance." end
	DataService.update(player, function(data) data.FavDances[id] = on or nil end)
	return true
end

function VERBS.ClaimReward(player, level) return ProgressService.claimReward(player, level) end
function VERBS.ClaimQuest(player, id) return ProgressService.claimQuest(player, id) end

function ActionService.start()
	(Net.get("Action") :: RemoteFunction).OnServerInvoke = function(player, verb, ...)
		local now = os.clock()
		if last[player] and now - last[player] < MIN_INTERVAL then return false, "Too fast." end
		last[player] = now
		local fn = type(verb) == "string" and VERBS[verb]
		if not fn then return false, "Unknown action." end
		if not DataService.get(player) then return false, "Your save is still loading." end
		return fn(player, ...)
	end
	Players.PlayerRemoving:Connect(function(p) last[p] = nil end)
end

return ActionService
