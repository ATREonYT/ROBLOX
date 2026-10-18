-- Saving. One ProfileStore session per player; everything a player owns lives in profile.Data.
-- In Studio the store is a Mock (progress resets when you press Stop) so testing never touches real saves.
-- Other services change data only through DataService.update(), which re-sends the player's state to their client.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ProfileStore = require(script.Parent.Vendor.ProfileStore)
local Settings = require(game:GetService("ReplicatedStorage").Shared.Config.Settings)
local Net = require(game:GetService("ReplicatedStorage").Shared.Net)
local Characters = require(game:GetService("ReplicatedStorage").Shared.Config.Characters)
local Dances = require(game:GetService("ReplicatedStorage").Shared.Config.Dances)

local DataService = {}

DataService.onChanged = nil :: ((Player) -> ())? -- set by Bootstrap (cosmetics follow ownership)

DataService.Template = {
	Coins = 0,
	Aura = 0, -- the premium currency (Huss Valley's gems; owner's call). Crates cost Aura (Config/Crates)
	Cosmetics = {}, -- [key] = true for bought cosmetics (Robux ones and Config/CoinShop items)
	Wear = {}, -- [slot] = the worn coin-shop item (Trail, Tag, Knife); nil = none
	Pity = {}, -- [crateId] = opens since that crate's top prize (Config/Crates; shown to the player)
	Settings = table.clone(Settings.Defaults),
	Receipts = {}, -- recent developer-product PurchaseIds, so a receipt is never granted twice
	Characters = {}, -- [id] = os.time() when acquired
	Equipped = "", -- equipped companion id ("" = none)
	FavChars = {}, -- [id] = true
	Dances = {}, -- [id] = true (owned outright; the Dance Pack pass adds its dances on top)
	FavDances = {}, -- [id] = true (saved favourites; ActionService FavoriteDance checks the id and caps the count)
	XP = 0,
	Claimed = {}, -- [tostring(level)] = true for claimed track rewards
	Stats = {}, -- quest counters (Config/Progression.Stats): Rounds, Crossings, AuraStars, Heroes, Rescues, ...
	QuestsClaimed = {}, -- [questId] = true
	-- Spin the Wheel (SpinService, Shared/SpinRules)
	Spins = 0, -- owned (bought) spins
	FreeSpinAt = 0, -- os.time() when the next free spin is ready (0 = ready)
	SpinPity = 0, -- spins since the last Legendary (shown: "Guaranteed Legendary in N spins")
	Boosts = { Coins = 0, Aura = 0 }, -- [kind] = os.time() its x2 lasts until
}

local STORE_NAME = "HuzzValley_Player_v1"
local store = ProfileStore.New(STORE_NAME, DataService.Template)
if RunService:IsStudio() then store = store.Mock end

local profiles: { [Player]: any } = {}
local extras: { [Player]: { [string]: any } } = {} -- live-only state (e.g. game pass ownership), sent with the save
local loaded = Instance.new("BindableEvent")
local stateRemote = Net.get("State") :: RemoteEvent

function DataService.snapshot(player: Player)
	local profile = profiles[player]
	if not profile then return nil end
	local d = profile.Data
	local ex = extras[player] or {}
	return {
		Coins = d.Coins,
		Aura = d.Aura,
		Wear = table.clone(d.Wear),
		Pity = table.clone(d.Pity),
		Cosmetics = table.clone(d.Cosmetics),
		Passes = table.clone(ex.Passes or {}),
		Settings = table.clone(d.Settings),
		Characters = table.clone(d.Characters),
		Equipped = d.Equipped,
		FavChars = table.clone(d.FavChars),
		Dances = DataService.ownedDances(player),
		FavDances = table.clone(d.FavDances),
		XP = d.XP,
		Claimed = table.clone(d.Claimed),
		Stats = table.clone(d.Stats),
		QuestsClaimed = table.clone(d.QuestsClaimed),
		Spins = d.Spins or 0,
		FreeSpinAt = d.FreeSpinAt or 0,
		SpinPity = d.SpinPity or 0,
		Boosts = table.clone(d.Boosts or {}),
	}
end

local function push(player: Player)
	local snap = DataService.snapshot(player)
	if snap then stateRemote:FireClient(player, snap) end
end

-- Dances the player can use: owned outright, plus the Dance Pack's dances while they own the pass.
function DataService.ownedDances(player: Player)
	local profile = profiles[player]
	local owned = profile and table.clone(profile.Data.Dances) or {}
	local passes = extras[player] and extras[player].Passes
	if passes and passes.DancePack then
		for _, d in Dances.List do if d.Pack then owned[d.Id] = true end end
	end
	return owned
end

function DataService.get(player: Player)
	return profiles[player]
end

-- Waits (up to `timeout` seconds) for the player's save to finish loading.
function DataService.waitFor(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 10)
	-- (polls: a save that never loads, say they left or were kicked, would otherwise wait on someone else's load)
	while not profiles[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return profiles[player]
end

-- Changes saved data. fn(data) edits it in place; the client gets the new state afterwards.
function DataService.update(player: Player, fn: (any) -> ())
	local profile = profiles[player]
	if not profile or not profile:IsActive() then return false end
	fn(profile.Data)
	push(player)
	if DataService.onChanged then task.spawn(DataService.onChanged, player) end
	return true
end

function DataService.setExtra(player: Player, key: string, value: any)
	extras[player] = extras[player] or {}
	extras[player][key] = value
	push(player)
end

function DataService.getExtra(player: Player, key: string)
	return extras[player] and extras[player][key]
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync("Player_" .. player.UserId, {
		Cancel = function() return player.Parent ~= Players end,
	})
	if not profile then
		player:Kick("Your save couldn't load. Please rejoin.")
		return
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	-- Gems became Aura (owner's call): anything saved as gems carries over.
	if type(profile.Data.Gems) == "number" then
		profile.Data.Aura = (profile.Data.Aura or 0) + profile.Data.Gems
		profile.Data.Gems = nil
	end
	-- Drop settings that no longer exist and fix any saved value that is no longer allowed.
	local clean = table.clone(Settings.Defaults)
	for k, v in profile.Data.Settings do
		if clean[k] ~= nil and Settings.validate(k, v) ~= nil then clean[k] = v end
	end
	profile.Data.Settings = clean
	-- The kit's placeholder companions are gone: drop them from old saves (unless a real girl has that id).
	local girls = game:GetService("ReplicatedStorage"):FindFirstChild("HuzzGirls")
	local GirlIds = {}
	if girls then
		for _, m in girls:GetChildren() do
			local gid = m:GetAttribute("Id")
			if type(gid) == "string" then GirlIds[gid] = true end
		end
	end
	for id in Characters.Retired do
		if profile.Data.Characters[id] and not GirlIds[id] then profile.Data.Characters[id] = nil end
		if profile.Data.FavChars and profile.Data.FavChars[id] and not GirlIds[id] then profile.Data.FavChars[id] = nil end
	end
	if Characters.Retired[profile.Data.Equipped] and not GirlIds[profile.Data.Equipped] then profile.Data.Equipped = "" end
	-- Starter companion and dance for every player (also fills them in for older saves).
	for _, c in Characters.List do
		if c.Starter and not profile.Data.Characters[c.Id] then profile.Data.Characters[c.Id] = os.time() end
		if c.Starter and profile.Data.Equipped == "" then profile.Data.Equipped = c.Id end
	end
	for _, d in Dances.List do
		if d.Starter then profile.Data.Dances[d.Id] = true end
	end
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player.Parent == Players then player:Kick("Your save was opened somewhere else. Please rejoin.") end
	end)
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end
	profiles[player] = profile
	loaded:Fire(player)
	push(player)
end

function DataService.start()
	(Net.get("GetState") :: RemoteFunction).OnServerInvoke = function(player)
		DataService.waitFor(player, 60)
		return DataService.snapshot(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, p in Players:GetPlayers() do task.spawn(onPlayerAdded, p) end
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		profiles[player] = nil
		extras[player] = nil
		if profile then profile:EndSession() end
	end)
end

return DataService
