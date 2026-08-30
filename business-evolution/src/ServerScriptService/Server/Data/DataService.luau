--!strict
-- The single source of truth for player state (§13.2). Wraps ProfileStore:
-- session locking, Reconcile, migrations, NaN/inf guards, leaderstats mirror,
-- and the throttled state push to the owning client.
--
-- Everything else mutates data ONLY through DataService.update(), which
-- sanitizes the core stats and schedules a client sync. leaderstats is a
-- WRITE-ONLY display mirror; no code may ever read it back.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local ProfileStore = require(ServerScriptService.Packages.ProfileStore)
local Migrations = require(script.Parent.Migrations)
local Net = require(ServerScriptService.Server.Net.Net)
local Stack = require(ServerScriptService.Server.Economy.Stack)

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Ranks = require(Shared.Config.Ranks)
local Sanitize = require(Shared.Util.Sanitize)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Signal = require(ReplicatedStorage.Packages.Signal)


export type ProfileData = {
	DataVersion: number,
	Productivity: number,
	Wins: number,
	Rank: number,
	Restructures: number,
	BestRank: number,
	TotalClicks: number,
	Gear: { Keyboard: number, Chair: number, Coffee: number },
	Severance: { string },
	PendingSeverance: { string },
	Interns: { { Uid: string, Id: string } },
	EquippedInterns: { string },
	BossesDefeated: { string },
	PurchaseLog: { string },
	FirstJoinTime: number,
}

local TEMPLATE: ProfileData = {
	DataVersion = Migrations.CURRENT_VERSION,
	Productivity = 0,
	Wins = 0,
	Rank = 1,
	Restructures = 0,
	BestRank = 1,
	TotalClicks = 0,
	Gear = { Keyboard = 0, Chair = 0, Coffee = 0 },
	Severance = {},
	PendingSeverance = {},
	Interns = {},
	EquippedInterns = {},
	BossesDefeated = {},
	PurchaseLog = {},
	FirstJoinTime = 0,
}

local DataService = {}

-- Fires (player, data) once a profile is loaded and safe to touch.
DataService.PlayerLoaded = Signal.new()
-- Fires (player) just before the profile is released on leave.
DataService.PlayerUnloading = Signal.new()

DataService.Template = TEMPLATE

local store = nil :: any
local profiles: { [Player]: any } = {}
local leaderstatValues: { [Player]: { Productivity: NumberValue, Wins: NumberValue } } = {}
local syncDue: { [Player]: boolean } = {}
local lastSync: { [Player]: number } = {}
local trove = Trove.new()

-- Set by MonetizationService in its Start (avoids a hard dependency cycle);
-- until then nobody owns any passes.
local passProvider: (player: Player) -> Stack.Passes = function()
	return {}
end

function DataService.setPassProvider(provider: (player: Player) -> Stack.Passes)
	passProvider = provider
end

function DataService.passesFor(player: Player): Stack.Passes
	return passProvider(player)
end

function DataService.get(player: Player): ProfileData?
	local profile = profiles[player]
	if profile and profile:IsActive() then
		return profile.Data
	end
	return nil
end

-- The one mutation doorway. Runs `mutate` on live data, then sanitizes the
-- numeric stats, refreshes leaderstats, and queues a state push.
function DataService.update(player: Player, mutate: (data: ProfileData) -> ())
	local data = DataService.get(player)
	if not data then
		return
	end
	mutate(data)
	data.Productivity = Sanitize.stat(data.Productivity)
	data.Wins = Sanitize.stat(data.Wins)
	data.Rank = math.clamp(Sanitize.stat(data.Rank, 1), 1, #Ranks.List)
	data.Restructures = Sanitize.stat(data.Restructures)
	data.TotalClicks = Sanitize.stat(data.TotalClicks)
	local stats = leaderstatValues[player]
	if stats then
		stats.Productivity.Value = data.Productivity
		stats.Wins.Value = data.Wins
	end
	syncDue[player] = true
end

-- Snapshot + derived numbers the client renders. Server computes everything;
-- the client owns zero balance math.
local function buildClientState(player: Player, data: ProfileData)
	local passes = passProvider(player)
	return {
		Productivity = data.Productivity,
		Wins = data.Wins,
		Rank = data.Rank,
		Restructures = data.Restructures,
		Gear = data.Gear,
		Severance = data.Severance,
		PendingSeverance = data.PendingSeverance,
		Interns = data.Interns,
		EquippedInterns = data.EquippedInterns,
		BossesDefeated = data.BossesDefeated,
		ClickIncome = Stack.clickIncome(data, passes),
		IdlePerSecond = Stack.idlePerSecond(data, passes),
		RestructureCost = Stack.restructureCost(data.Restructures),
		NextRankAt = Ranks.nextRequirement(data.Rank),
		InternSlots = Stack.internSlots(data, passes),
		ClickCooldown = Stack.clickCooldown(data),
	}
end

function DataService.pushState(player: Player)
	local data = DataService.get(player)
	if data then
		Net.sendTo(player, "StateChanged", buildClientState(player, data))
		lastSync[player] = os.clock()
		syncDue[player] = nil
	end
end

local function makeLeaderstats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local productivity = Instance.new("NumberValue") -- NumberValue, never IntValue (§13.9)
	productivity.Name = "Productivity"
	local wins = Instance.new("NumberValue")
	wins.Name = "Wins"
	productivity.Parent = folder
	wins.Parent = folder
	folder.Parent = player
	leaderstatValues[player] = { Productivity = productivity, Wins = wins }
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync("Player_" .. player.UserId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if not profile then
		-- Another server holds the lock (or DataStores are down). Playing
		-- without saves risks wiping progress, so decline politely.
		player:Kick("Your save is still closing on another server — rejoin in a moment!")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	Migrations.run(profile.Data)

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player.Parent == Players then
			player:Kick("Your session was opened somewhere else.")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	if profile.Data.FirstJoinTime == 0 then
		profile.Data.FirstJoinTime = os.time()
	end

	profiles[player] = profile
	makeLeaderstats(player)
	DataService.update(player, function() end) -- sanitize + mirror once on load
	DataService.PlayerLoaded:Fire(player, profile.Data)
	DataService.pushState(player)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		DataService.PlayerUnloading:Fire(player)
		-- Last line of defence: a corrupt table would make ProfileStore's
		-- save silently fail, which is worse than losing one field now.
		local ok, why = Sanitize.validateSavable(profile.Data)
		if not ok then
			warn("[DataService] unsavable data for", player.Name, "-", why)
		end
		profile:EndSession()
	end
	profiles[player] = nil
	leaderstatValues[player] = nil
	syncDue[player] = nil
	lastSync[player] = nil
end

function DataService:Init()
	-- ProfileStore detects missing DataStore access (e.g. Studio without API
	-- access enabled) and quietly runs on an in-memory mock, so one code path
	-- covers Studio playtests and live servers alike.
	store = ProfileStore.New("PlayerData_v1", TEMPLATE)
end

function DataService:Start()
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	trove:Connect(Players.PlayerAdded, function(player)
		onPlayerAdded(player)
	end)
	trove:Connect(Players.PlayerRemoving, onPlayerRemoving)

	-- Throttled sync pump: pushes at most StateSyncHz per player, only when dirty.
	local interval = 1 / Balance.StateSyncHz
	trove:Connect(RunService.Heartbeat, function()
		local now = os.clock()
		for player in syncDue do
			if now - (lastSync[player] or 0) >= interval then
				DataService.pushState(player)
			end
		end
	end)
end

return DataService
