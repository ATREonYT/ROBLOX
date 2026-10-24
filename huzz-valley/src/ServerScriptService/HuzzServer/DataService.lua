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
local CombineRules = require(game:GetService("ReplicatedStorage").Shared.CombineRules)

local DataService = {}

DataService.onChanged = nil :: ((Player) -> ())? -- set by Bootstrap (cosmetics follow ownership)

DataService.Template = {
	Coins = 0,
	Aura = 0, -- the premium currency (Huss Valley's gems; owner's call). Crates cost Aura (Config/Crates)
	Cosmetics = {}, -- [key] = true for bought cosmetics (Robux ones and Config/CoinShop items)
	Wear = {}, -- [slot] = the worn coin-shop item (Trail, Tag, Knife); nil = none
	Pity = {}, -- [crateId] = opens since that crate's top prize (Config/Crates; shown to the player)
	CrateKeys = {}, -- [crateId] = crate keys bought with Robux (the Halloween shop); an open uses one before Aura
	PassKnives = {}, -- [pass key] = true: a Halloween knife pass gave its knife (ShopService)
	PassRefunds = {}, -- [pass key] = true: its knife was yours already, so its crate keys were given instead (once)
	Settings = table.clone(Settings.Defaults),
	Receipts = {}, -- recent developer-product PurchaseIds, so a receipt is never granted twice
	AdminPasses = {}, -- [pass key] = true: a game pass's perks given by an admin (HuzzServer/AdminService GivePass)
	Characters = {}, -- [id] = os.time() when acquired
	Equipped = "", -- equipped companion id ("" = none)
	Copies = {}, -- [id] = { Normal = n, Silver = n, Gold = n, Diamond = n }: her copies by grade (Shared/CombineRules;
	-- the Combine machine merges two of a grade into one a grade up, PRESTIGE spends a spare Normal one). Old saves'
	-- Dupes (spare copies) are moved in here on load (CombineRules.migrate).
	Combines = 0, -- merges made (the Combine machine waits for the save holding this before showing the result)
	Prestige = {}, -- [id] = her prestige level 0..3 (cooler effects)
	FriendReward = false, -- the friend knife (or its coins) was given (Shared/FriendRules)
	GroupReward = false, -- the "join our group" spins were given (Config/Group, ProgressService.claimGroup)
	Login = {}, -- daily login rewards: { Count = claimed so far, Last = day number of the last } (Shared/LoginRules)
	FavChars = {}, -- [id] = true
	Dances = {}, -- [id] = true (owned outright; the Dance Pack pass adds its dances on top)
	FavDances = {}, -- [id] = true (saved favourites; ActionService FavoriteDance checks the id and caps the count)
	XP = 0,
	Claimed = {}, -- [tostring(level)] = true for claimed track rewards
	Stats = {}, -- quest counters (Config/Progression.Stats): Rounds, Crossings, AuraStars, Heroes, Rescues, ...
	QuestsClaimed = {}, -- [questId] = true
	Daily = {}, -- today's daily quests and the 2-hour spin quest with their progress (Shared/DailyRules)
	-- Spin the Wheel (SpinService, Shared/SpinRules)
	Spins = 0, -- owned (bought) spins
	FreeSpinAt = 0, -- os.time() when the next free spin is ready (0 = ready)
	SpinPity = 0, -- spins since the last Legendary (shown: "Guaranteed Legendary in N spins")
	Boosts = { Coins = 0, Aura = 0 }, -- [kind] = os.time() its x2 lasts until
	Abilities = {}, -- [name] = true for round abilities bought with coins (Shared/AbilityRules; starters are always owned)
	Loadout = {}, -- { Runner, CatcherQ, CatcherE }: the abilities you bring (Config/Powers.Loadout; AbilityRules.loadout)
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
		CrateKeys = table.clone(d.CrateKeys or {}),
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
		Daily = { Day = d.Daily and d.Daily.Day, Slot = d.Daily and d.Daily.Slot, Q = (function()
			local q = {}
			for k, e in (d.Daily and d.Daily.Q or {}) do q[k] = table.clone(e) end
			return q
		end)() },
		Spins = d.Spins or 0,
		GroupReward = d.GroupReward == true,
		Login = table.clone(d.Login or {}),
		FreeSpinAt = d.FreeSpinAt or 0,
		SpinPity = d.SpinPity or 0,
		Boosts = table.clone(d.Boosts or {}),
		Copies = (function()
			local c = {}
			for id, byGrade in (d.Copies or {}) do c[id] = table.clone(byGrade) end
			return c
		end)(),
		Prestige = table.clone(d.Prestige or {}),
		Abilities = table.clone(d.Abilities or {}),
		Loadout = table.clone(d.Loadout or {}),
	}
end

local function push(player: Player)
	local snap = DataService.snapshot(player)
	if snap then stateRemote:FireClient(player, snap) end
end

-- The old dances (gone Oct 22: the owner's own R6 dances replaced them, Config/Dances) and what each cost in coins.
-- A save that still has one: its coins come back (kid-safe: never pay for something that vanished), and the old
-- Robot from the Level 3 reward becomes that reward's new dance (Untouchable) instead. Old favourites go. Safe on
-- every load (an id handled here is gone after).
local OLD_DANCES = {
	Floss = 0, CitrusGroove = 0, HypeUp = 0, ShockShuffle = 0, ClassicGroove = 0, SmoothMoves = 0, SoFresh = 0,
	PopLock = 0, Robot = 600, PhoneCall = 0, RunningMan = 0, CrazyFeet = 0, Breakdown = 0, SwingTime = 0, FreeFlow = 0,
	Freestyle = 0, CleanGroove = 0, BounceBounce = 0, Flapper = 0, SquatKick = 0, Sprinkler = 0, CrabDance = 0,
	Toprock = 0, Aerobics = 0, BoogieBlast = 400, HeadBanger = 400, TheTwist = 600, ZanyZig = 600, PowerMoves = 800,
	Showstopper = 1200, ZombieGroove = 2000,
}
function DataService.migrateDances(data)
	data.Dances = data.Dances or {}
	for id in table.clone(data.Dances) do
		local paid = OLD_DANCES[id]
		if paid ~= nil and not Dances.get(id) then
			data.Dances[id] = nil
			if id == "Robot" and data.Claimed and data.Claimed["3"] then
				data.Dances.Untouchable = true -- (earned at Level 3: the reward's new dance)
			elseif paid > 0 then
				data.Coins = (data.Coins or 0) + paid
			end
		end
	end
	for id in table.clone(data.FavDances or {}) do
		if not Dances.get(id) then data.FavDances[id] = nil end
	end
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

-- Saves now and waits (up to `timeout` seconds) until the stored save passes check(savedData): for answers that must
-- only show once they're safe (the Combine machine's result). True when it did.
function DataService.saveAndWait(player: Player, check: (any) -> boolean, timeout: number?): boolean
	local profile = profiles[player]
	if not profile then return false end
	local function done()
		local d = profile.LastSavedData
		return type(d) == "table" and check(d) == true
	end
	if done() then return true end
	pcall(function() profile:Save() end)
	local deadline = os.clock() + (timeout or 10)
	while not done() and profile:IsActive() and os.clock() < deadline do
		task.wait(0.25) -- (polled, so the deadline holds even when no further save happens)
	end
	return done()
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
	-- (a save made before abilities were bought has no Abilities table until Reconcile adds one: it keeps every
	-- ability it could already roll, Shared/AbilityRules.migrate)
	local hadAbilities = type(profile.Data.Abilities) == "table"
	profile:Reconcile()
	require(game:GetService("ReplicatedStorage").Shared.AbilityRules).migrate(profile.Data, hadAbilities)
	-- Gems became Aura (owner's call): anything saved as gems carries over.
	if type(profile.Data.Gems) == "number" then
		profile.Data.Aura = (profile.Data.Aura or 0) + profile.Data.Gems
		profile.Data.Gems = nil
	end
	-- The Oct 19 Knife Crate became his three knife crates: its pity counter (and any keys) carry over (Shared/CrateSaves).
	require(game:GetService("ReplicatedStorage").Shared.CrateSaves).migrate(profile.Data)
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
	-- Girls are copies by grade since the Combine machine (Oct 20): old saves' girls and spare copies carry over as
	-- Normal copies (Shared/CombineRules.migrate; safe on every load).
	CombineRules.migrate(profile.Data)
	DataService.migrateDances(profile.Data)
	for _, d in Dances.List do
		if d.Starter then profile.Data.Dances[d.Id] = true end
	end
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		-- (not when this server is shutting down: ProfileStore ends every session then, and kids would read the wrong
		-- reason; release check, Oct 22)
		local closing = false
		pcall(function() closing = ProfileStore.IsClosing == true end)
		if player.Parent == Players and not closing then player:Kick("Your save was opened somewhere else. Please rejoin.") end
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
	-- The client asks once at start (UI/State); later changes arrive by themselves (the State remote). Only one ask
	-- waits for the save at a time, and asks closer than a second apart get nothing, so a client can't pile up
	-- waiting threads or whole-save copies (bug hunt, Oct 20).
	local asking: { [Player]: boolean } = {}
	local askedAt: { [Player]: number } = {}
	(Net.get("GetState") :: RemoteFunction).OnServerInvoke = function(player)
		local now = os.clock()
		if asking[player] or (askedAt[player] and now - askedAt[player] < 1) then return nil end
		askedAt[player] = now
		asking[player] = true
		DataService.waitFor(player, 60)
		asking[player] = nil
		return DataService.snapshot(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		asking[player], askedAt[player] = nil, nil
	end)
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
