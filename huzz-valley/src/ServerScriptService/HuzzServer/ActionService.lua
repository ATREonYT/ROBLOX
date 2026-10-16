-- Handles the player's actions from the UI (the "Action" remote): equip / favourite companions, favourite dances,
-- claim rewards and quests. Every action is checked here against the player's saved data.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Characters = require(ReplicatedStorage.Shared.Config.Characters)
local Dances = require(ReplicatedStorage.Shared.Config.Dances)
local CoinShop = require(ReplicatedStorage.Shared.Config.CoinShop)
local Crates = require(ReplicatedStorage.Shared.Config.Crates)
local CrateRoll = require(ReplicatedStorage.Shared.CrateRoll)
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

-- The coin shop (Config/CoinShop): looks only. Buying checks the price here, takes the coins and wears it.
function VERBS.BuyWithCoins(player, key)
	local item = type(key) == "string" and CoinShop.get(key)
	if not item then return false, "Unknown item." end
	local ok, why = false, nil
	DataService.update(player, function(data)
		if data.Cosmetics[key] then why = "You own this already."; return end
		if (data.Coins or 0) < item.Price then why = `You need {item.Price - (data.Coins or 0)} more coins.`; return end
		data.Coins -= item.Price
		data.Cosmetics[key] = true
		data.Wear[item.Slot] = key
		ok = true
	end)
	return ok, why
end

-- Wear an owned item in its slot, or take the slot off (key = nil with a slot name).
function VERBS.Wear(player, slot, key)
	if type(slot) ~= "string" or not table.find(CoinShop.Slots, slot) then return false, "Unknown slot." end
	if key ~= nil then
		local item = type(key) == "string" and CoinShop.get(key)
		local robuxTrail = key == "SunsetTrail" and slot == "Trail"
		if not robuxTrail and not (item and item.Slot == slot) then return false, "That doesn't go there." end
	end
	local ok, why = false, nil
	DataService.update(player, function(data)
		if key ~= nil and not data.Cosmetics[key] then why = "You don't own this yet."; return end
		data.Wear[slot] = key
		ok = true
	end)
	return ok, why
end

-- Crates (Config/Crates, Shared/CrateRoll): costs Aura, rolled here with the shown odds and the pity counter.
-- Returns true and what came out (its name), or false and why.
local crateRandom = Random.new()
function VERBS.OpenCrate(player, crateId)
	local crate = type(crateId) == "string" and Crates.get(crateId)
	if not crate then return false, "Unknown crate." end
	local ok, result = false, nil
	DataService.update(player, function(data)
		if (data.Aura or 0) < crate.Price then result = `You need {crate.Price - (data.Aura or 0)} more Aura.`; return end
		data.Aura -= crate.Price
		local item, pity = CrateRoll.roll(crate, data.Pity[crate.Id] or 0, function() return crateRandom:NextNumber() end)
		data.Pity[crate.Id] = pity
		if item.Kind == "Coins" then
			data.Coins += item.Amount or 0
		elseif item.Kind == "Cosmetic" or item.Kind == "Dance" then
			local owned = if item.Kind == "Cosmetic" then data.Cosmetics else data.Dances
			if owned[item.Id] then
				data.Coins += crate.Duplicate or 0 -- (a duplicate turns into coins)
			else
				owned[item.Id] = true
			end
		end
		ok, result = true, item.Name
	end)
	return ok, result
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
