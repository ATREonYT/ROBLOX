-- Handles the player's actions from the UI (the "Action" remote): equip / favourite companions, favourite dances,
-- claim rewards and quests. Every action is checked here against the player's saved data.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Characters = require(ReplicatedStorage.Shared.Config.Characters)
local Dances = require(ReplicatedStorage.Shared.Config.Dances)
local CoinShop = require(ReplicatedStorage.Shared.Config.CoinShop)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local CrownPose = require(ReplicatedStorage.Shared.CrownPose)
local Crates = require(ReplicatedStorage.Shared.Config.Crates)
local CrateRoll = require(ReplicatedStorage.Shared.CrateRoll)
local HalloweenShop = require(ReplicatedStorage.Shared.Config.HalloweenShop)
local PrestigeRules = require(ReplicatedStorage.Shared.PrestigeRules)
local Net = require(ReplicatedStorage.Shared.Net)
local DataService = require(script.Parent.DataService)
local ProgressService = require(script.Parent.ProgressService)

local ActionService = {}

local MIN_INTERVAL = 0.15
ActionService.MIN_INTERVAL = MIN_INTERVAL -- (the admin panel uses the same limit: AdminService)
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

-- PRESTIGE in the Index (Shared/PrestigeRules): spends a spare copy of her, up to level 3
function VERBS.Prestige(player, id)
	local level, why = nil, nil
	DataService.update(player, function(data)
		level, why = PrestigeRules.apply(data, id)
	end)
	return level ~= nil, if level then level else why
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

-- Favourite dances (saved; the Dances window's FAVOURITES tab and the G wheel). Only real dance ids, at most
-- Dances.MaxFavourites of them (old ids that no longer exist are dropped and don't count).
function VERBS.FavoriteDance(player, id, on)
	if type(id) ~= "string" or not Dances.get(id) or type(on) ~= "boolean" then return false, "Unknown dance." end
	local ok, why = false, "Your save isn't ready yet."
	DataService.update(player, function(data)
		ok, why = true, nil
		local count = 0
		for fav in data.FavDances do
			if Dances.get(fav) then count += 1 else data.FavDances[fav] = nil end
		end
		if on and not data.FavDances[id] and count >= Dances.MaxFavourites then
			ok, why = false, `You can have up to {Dances.MaxFavourites} favourites. Unstar one first.`
			return
		end
		data.FavDances[id] = on or nil
	end)
	return ok, why
end

-- The coin shop (Config/CoinShop): looks only. Buying checks the price here, takes the coins and wears it.
function VERBS.BuyWithCoins(player, key)
	local item = type(key) == "string" and CoinShop.get(key)
	if not item then return false, "Unknown item." end
	if item.Pass then -- (the Game Pass knives: only the pass gives them, ShopService)
		local pass = Products.get(item.Pass)
		return false, `That one comes with the {if pass then pass.Name else item.Pass} Game Pass.`
	end
	if item.Unlock then return false, `Earn it: {item.Unlock}.` end -- (quest / wheel items aren't sold)
	if item.NotForSale then return false, "That one comes from the Spin the Wheel." end
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

-- Wear an owned item in its slot, or take the slot off (key = nil with a slot name). Robux cosmetics (Config/Products)
-- go in their own slot (Sunset Trail: Trail, Blossom Aura: Aura, Crown Pose: Pose, Midnight Outfit: Outfit).
function VERBS.Wear(player, slot, key)
	if type(slot) ~= "string" or not table.find(CoinShop.Slots, slot) then return false, "Unknown slot." end
	if key ~= nil then
		local item = type(key) == "string" and CoinShop.get(key)
		local product = type(key) == "string" and Products.get(key)
		local fits = (item and item.Slot == slot) or (product and product.Kind == "Cosmetic" and product.Slot == slot)
		if not fits then return false, "That doesn't go there." end
	end
	local ok, why = false, nil
	DataService.update(player, function(data)
		if key ~= nil and not data.Cosmetics[key] then why = "You don't own this yet."; return end
		data.Wear[slot] = if key == nil then "" else key -- ("" = taken off on purpose: Config/CoinShop.worn)
		ok = true
	end)
	if ok and slot == "Pose" and key ~= nil then -- (put it on and you strike it once, so you see what you got)
		task.delay(0.3, function()
			local c = player.Character
			local now = workspace:GetServerTimeNow()
			-- (once per pose length at most: tapping WEAR fast never restarts it for the whole server)
			if c and c:GetAttribute("HuzzPose") == key and now - (c:GetAttribute("HuzzPoseAt") or 0) > CrownPose.LENGTH + 0.5 then
				c:SetAttribute("HuzzPoseAt", now)
			end
		end)
	end
	return ok, why
end

-- Crates (Config/Crates, Shared/CrateRoll): costs Aura, rolled here with the shown odds and the pity counter, all in
-- one save write (the Aura is taken once, whatever the client does). The client only animates to the answer:
-- true and { crate, index (in crate.Items), name, rarity, new (first time you own it), coins (what was added: a coin
-- prize or a duplicate's coins back), pity (opens since the top prize), left (opens until it's certain), strip (the
-- reel: item numbers, honest draws), at (the prize's card on it) }, or false and why.
local crateRandom = Random.new()
function VERBS.OpenCrate(player, crateId)
	local crate = type(crateId) == "string" and Crates.get(crateId)
	if not crate then return false, "Unknown crate." end
	local ok, result = false, nil
	DataService.update(player, function(data)
		data.CrateKeys = data.CrateKeys or {}
		local keys = data.CrateKeys[crate.Id] or 0
		if keys > 0 then -- a crate key bought with Robux (the Halloween shop) opens it before any Aura is spent
			data.CrateKeys[crate.Id] = if keys > 1 then keys - 1 else nil
		elseif (data.Aura or 0) < crate.Price then
			result = `You need {crate.Price - (data.Aura or 0)} more Aura.`
			return
		else
			data.Aura -= crate.Price
		end
		local item, pity = CrateRoll.roll(crate, data.Pity[crate.Id] or 0, function() return crateRandom:NextNumber() end)
		data.Pity[crate.Id] = pity
		local isNew, coins = false, 0
		if item.Kind == "Coins" then
			coins = item.Amount or 0
		elseif item.Kind == "Cosmetic" or item.Kind == "Dance" then
			local owned = if item.Kind == "Cosmetic" then data.Cosmetics else data.Dances
			if owned[item.Id] or (item.Kind == "Dance" and DataService.ownedDances(player)[item.Id]) then
				coins = CrateRoll.dupeCoins(crate, item) -- (a duplicate turns into coins)
			else
				owned[item.Id] = true
				isNew = true
			end
		end
		data.Coins += coins
		local index = CrateRoll.indexOf(crate, item) or 1
		local R = Crates.Reel
		ok, result = true, {
			crate = crate.Id, index = index, name = item.Name, rarity = item.Rarity, new = isNew, coins = coins,
			pity = pity, left = CrateRoll.left(crate, pity),
			strip = CrateRoll.strip(crate, index, R.Length, R.At, function() return crateRandom:NextNumber() end), at = R.At,
		}
	end)
	return ok, result
end

-- The Halloween shop (Config/HalloweenShop): one of its knives straight away for its Aura price. Only the knives on
-- that page; the price, "already yours" and "not enough Aura" are all checked here, in the same save write that
-- takes the Aura and gives the knife (so a double tap can only buy it once).
function VERBS.BuyHalloweenKnife(player, key)
	local entry = type(key) == "string" and HalloweenShop.knife(key)
	local item = entry and CoinShop.get(entry.Key)
	if not entry or not item or not entry.Aura then return false, "That knife isn't sold here." end
	local ok, why = false, nil
	DataService.update(player, function(data)
		if data.Cosmetics[item.Key] then why = "You own this already."; return end
		if (data.Aura or 0) < entry.Aura then why = `You need {entry.Aura - (data.Aura or 0)} more Aura.`; return end
		data.Aura -= entry.Aura
		data.Cosmetics[item.Key] = true
		data.Wear[item.Slot] = item.Key
		ok = true
	end)
	return ok, why
end

-- The Halloween shop's Robux buttons: the server decides whether Roblox's prompt opens (never for a knife you own).
function VERBS.PromptHalloween(player, key) return require(script.Parent.ShopService).promptHalloween(player, key) end
-- Shop > CRATES' BUY under his knife crates (ShopService.promptCrateKey: Id 0 = "coming soon", never a prompt)
function VERBS.PromptCrateKey(player, key) return require(script.Parent.ShopService).promptCrateKey(player, key) end

function VERBS.ClaimReward(player, level) return ProgressService.claimReward(player, level) end
function VERBS.ClaimQuest(player, id) return ProgressService.claimQuest(player, id) end
function VERBS.ClaimDaily(player, key) return ProgressService.claimDaily(player, key) end

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

	-- Dancing in step (owner: "make dances sync when someone is dancing and someone comes close and starts the same
	-- dance"): the character carries the dance it's doing and when it started (server time). UI/DancePlayer starts
	-- the same dance on the same beat as anyone near you already doing it. Only dances you own.
	local danceRemote = Net.get("Dance") :: RemoteEvent
	local lastDance: { [Player]: number } = {}
	Players.PlayerRemoving:Connect(function(p) lastDance[p] = nil end)
	danceRemote.OnServerEvent:Connect(function(player, id, startAt)
		local character = player.Character
		if not character then return end
		local now0 = os.clock()
		if lastDance[player] and now0 - lastDance[player] < 0.1 then return end
		lastDance[player] = now0
		-- (stopped, or a dance that can't be yours: clear it, so nobody syncs to an old dance)
		if id == nil or type(id) ~= "string" or not Dances.get(id) or not DataService.ownedDances(player)[id] then
			character:SetAttribute("HuzzDance", nil)
			character:SetAttribute("HuzzDanceAt", nil)
			return
		end
		local now = workspace:GetServerTimeNow()
		if type(startAt) ~= "number" or startAt ~= startAt or startAt > now + 1 or startAt < now - 3600 then
			startAt = now
		end
		character:SetAttribute("HuzzDance", id)
		character:SetAttribute("HuzzDanceAt", startAt)
	end)
end

return ActionService
