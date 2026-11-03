--!strict
-- Loads/saves each player's profile with ProfileStore (Vendor/ProfileStore.lua, the same vetted copy as hood/).
-- In Studio it runs in Mock mode: progress resets on Stop, on purpose.
-- Other services read/write `DataService.get(player)` (the live Data table) and call `DataService.push(player)`
-- after changing it. Pushes are batched to one per frame.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.MTL.Net)
local Signal = require(ReplicatedStorage.MTL.Signal)
local Schema = require(script.Parent.ProfileSchema)
local ProfileStore = require(script.Parent.Parent.Vendor.ProfileStore)

local DataService = {}
DataService.Ready = Signal.new() -- (player, data) after load
DataService.Releasing = Signal.new() -- (player, data) just before the session ends
DataService.Mode = if RunService:IsStudio() then "Mock" else "Live"

local profiles: { [Player]: any } = {}
local pushQueued: { [Player]: boolean } = {}
local store

local function log(...)
	print("[MTL Data]", ...)
end

function DataService.get(player: Player): any?
	local p = profiles[player]
	return if p and p:IsActive() then p.Data else nil
end

function DataService.profile(player: Player): any?
	local p = profiles[player]
	return if p and p:IsActive() then p else nil
end

function DataService.snapshot(player: Player): any?
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local snap = Schema.public(data)
	snap.DataMode = DataService.Mode
	return snap
end

function DataService.push(player: Player)
	if pushQueued[player] then
		return
	end
	pushQueued[player] = true
	task.defer(function()
		pushQueued[player] = nil
		local snap = DataService.snapshot(player)
		if snap and player.Parent then
			Net.get("ProfileUpdated"):FireClient(player, snap)
		end
	end)
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync("Player_" .. player.UserId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if not profile then
		player:Kick("Couldn't load your save. Please rejoin.")
		return
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	Schema.sanitize(profile.Data)
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player.Parent == Players then
			player:Kick("Your save was opened somewhere else. Please rejoin.")
		end
	end)
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end
	profiles[player] = profile
	profile.Data.Stats.Joins += 1
	log(player.Name, "loaded", DataService.Mode, "stage", profile.Data.Story.Stage, "level", profile.Data.Level)
	DataService.Ready:Fire(player, profile.Data)
	player:SetAttribute("MTL_Ready", true)
	DataService.push(player)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		DataService.Releasing:Fire(player, profile.Data)
		profiles[player] = nil
		profile:EndSession()
	end
end

function DataService.init()
	local s = ProfileStore.New(Schema.StoreName, Schema.Template)
	store = if DataService.Mode == "Mock" then s.Mock else s

	Net.get("RequestSnapshot").OnServerInvoke = function(player)
		return DataService.snapshot(player)
	end

	log("store ready (" .. DataService.Mode .. ")")
end

-- Called by Main AFTER every service's init, so all Ready listeners are connected before anyone loads.
function DataService.start()
	Players.PlayerAdded:Connect(function(p)
		task.spawn(onPlayerAdded, p)
	end)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerAdded, p)
	end
end

return DataService
