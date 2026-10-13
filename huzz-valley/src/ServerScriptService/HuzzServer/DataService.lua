-- Saving. One ProfileStore session per player; everything a player owns lives in profile.Data.
-- In Studio the store is a Mock (progress resets when you press Stop) so testing never touches real saves.
-- Other services change data only through DataService.update(), which re-sends the player's state to their client.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ProfileStore = require(script.Parent.Vendor.ProfileStore)
local Settings = require(game:GetService("ReplicatedStorage").Shared.Config.Settings)
local Net = require(game:GetService("ReplicatedStorage").Shared.Net)

local DataService = {}

DataService.onChanged = nil :: ((Player) -> ())? -- set by Bootstrap (cosmetics follow ownership)

DataService.Template = {
	Coins = 0,
	Gems = 0,
	Cosmetics = {}, -- [key] = true for bought cosmetics
	Settings = table.clone(Settings.Defaults),
	Receipts = {}, -- recent developer-product PurchaseIds, so a receipt is never granted twice
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
		Gems = d.Gems,
		Cosmetics = table.clone(d.Cosmetics),
		Passes = table.clone(ex.Passes or {}),
		Settings = table.clone(d.Settings),
	}
end

local function push(player: Player)
	local snap = DataService.snapshot(player)
	if snap then stateRemote:FireClient(player, snap) end
end

function DataService.get(player: Player)
	return profiles[player]
end

-- Waits (up to `timeout` seconds) for the player's save to finish loading.
function DataService.waitFor(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 10)
	while not profiles[player] and player.Parent and os.clock() < deadline do
		loaded.Event:Wait()
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
	-- Drop settings that no longer exist and fix any saved value that is no longer allowed.
	local clean = table.clone(Settings.Defaults)
	for k, v in profile.Data.Settings do
		if clean[k] ~= nil and Settings.validate(k, v) ~= nil then clean[k] = v end
	end
	profile.Data.Settings = clean
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
		DataService.waitFor(player, 15)
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
