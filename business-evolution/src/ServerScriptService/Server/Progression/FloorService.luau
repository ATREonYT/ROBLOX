--!strict
-- FloorService — the elevator's server half. Owns which floor every player is
-- standing on, validates RequestTeleport against the floor gates (with the two
-- paid skip passes as targeted bypasses), and keeps characters physically ON
-- their floor: respawns get moved off the Mailroom SpawnLocation, and anyone
-- who falls through the world is caught and put back on their spawn pad.
--
-- Everyone starts on the Mailroom because that is where the game's single
-- SpawnLocation lives (MapService); this service only ever moves them after.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ServerScriptService.Server.Net.Net)
local DataService = require(ServerScriptService.Server.Data.DataService)
local MapService = require(ServerScriptService.Server.World.MapService)

local Shared = ReplicatedStorage.Shared
local Floors = require(Shared.Config.Floors)
local Monetization = require(Shared.Config.Monetization)

local Trove = require(ReplicatedStorage.Packages.Trove)
local t = require(ReplicatedStorage.Packages.t)

local HOME_FLOOR_ID = "Mailroom"

-- Manifest Spawn CFrames sit at pad level, but PivotTo places the character's
-- pivot (roughly hip height). Lifting a few studs means a tiny harmless drop
-- instead of legs embedded in the spawn pad.
local SPAWN_LIFT = 4

-- A character this far below its floor's origin has slipped through geometry;
-- floors are stacked 512+ studs apart, so 120 can never reach the floor below.
local FALL_LIMIT = 120
local FALL_CHECK_INTERVAL = 1

-- The two "skip" passes bypass exactly one floor's gate each (§10). They are
-- not part of Stack.Passes (income math never sees them), so per CONTRACTS
-- ("compute it yourself from Config") ownership is checked here from
-- Config/Monetization instead of inventing a new MonetizationService API.
local SKIP_PASS_BY_FLOOR: { [string]: string } = {
	Executive = "ExecutiveSkip",
	Penthouse = "PenthouseSkip",
}

local FloorService = {}

local trove = Trove.new()
-- Per-player troves hold each player's CharacterAdded connection, so one
-- leaver's cleanup never touches anyone else's.
local playerTroves: { [Player]: Trove.Trove } = {}
local currentFloor: { [Player]: string } = {}
-- player -> pass Key -> true. Absent reads as "not owned", which is the safe
-- default while the async ownership fetch is still in flight.
local skipOwned: { [Player]: { [string]: boolean } } = {}

function FloorService.floorOf(player: Player): string
	return currentFloor[player] or HOME_FLOOR_ID
end

local function spawnCfFor(floorId: string): CFrame?
	local manifest = MapService.manifestFor(floorId)
	if manifest then
		-- `+ Vector3` translates in world space, keeping the spawn's facing
		-- direction (spawn pads face the room on purpose, DESIGN-MAP).
		return manifest.Spawn + Vector3.new(0, SPAWN_LIFT, 0)
	end
	return nil
end

local function moveCharacterTo(player: Player, cf: CFrame)
	local character = player.Character
	if not character then
		return
	end
	character:PivotTo(cf)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		-- PivotTo keeps momentum; a fall-caught character would otherwise
		-- arrive at terminal velocity and clip straight through the floor again.
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

local function ownsSkipFor(player: Player, floorId: string): boolean
	local passKey = SKIP_PASS_BY_FLOOR[floorId]
	if not passKey then
		return false
	end
	local owned = skipOwned[player]
	return owned ~= nil and owned[passKey] == true
end

-- Ownership is fetched once per join and cached: UserOwnsGamePassAsync is a
-- yielding web call, far too slow to sit inside a teleport request.
local function fetchSkipPasses(player: Player)
	for _, passKey in SKIP_PASS_BY_FLOOR do
		local pass = Monetization.passByKey(passKey)
		if pass and pass.Id ~= 0 then
			task.spawn(function()
				local ok, owns = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
				end)
				local cache = skipOwned[player]
				if ok and owns == true and cache then
					cache[passKey] = true
				end
			end)
		end
	end
end

local function onRequestTeleport(player: Player, floorId: string)
	local data = DataService.get(player)
	if not data then
		return -- profile still loading; nothing to validate against yet
	end
	if not Floors.get(floorId) then
		return -- validator only proves "string"; the id itself is still client input
	end

	local allowed = Floors.canEnter(floorId, data.Rank, data.Restructures, data.BossesDefeated)
	-- A skip pass bypasses only ITS floor's gate — canEnter already checks
	-- nothing but the target floor, so this substitution is exactly that scope.
	if not allowed and not ownsSkipFor(player, floorId) then
		return -- the client greys locked floors; a denied request is stale or forged
	end

	local cf = spawnCfFor(floorId)
	if not cf then
		return -- floor module missing mid-development; MapService already warned
	end
	moveCharacterTo(player, cf)
	currentFloor[player] = floorId
end

local function onCharacterAdded(player: Player, character: Model)
	-- Roblox has just placed (or is about to place) this character on the
	-- Mailroom SpawnLocation. Deferring one resumption cycle lets that engine
	-- placement finish first, so our pivot to the player's real floor wins.
	task.defer(function()
		if player.Parent ~= Players or player.Character ~= character then
			return
		end
		local cf = spawnCfFor(FloorService.floorOf(player))
		if cf then
			moveCharacterTo(player, cf)
		end
	end)
end

local function watchPlayer(player: Player)
	skipOwned[player] = {}
	-- Extend (not new): the child dies with the service trove even if this
	-- player somehow never fires PlayerRemoving. Cast mirrors the codebase's
	-- workaround for luau-lsp's cross-module Trove identity quirk.
	local playerTrove = trove:Extend()
	playerTroves[player] = playerTrove :: any
	playerTrove:Connect(player.CharacterAdded, function(character: Model)
		onCharacterAdded(player, character)
	end)
	fetchSkipPasses(player)
end

local function forgetPlayer(player: Player)
	local playerTrove = playerTroves[player]
	if playerTrove then
		playerTrove:Clean()
	end
	playerTroves[player] = nil
	currentFloor[player] = nil
	skipOwned[player] = nil
end

local function runFallCheck()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if not (root and root:IsA("BasePart")) then
			continue
		end
		local floorId = FloorService.floorOf(player)
		local floor = Floors.get(floorId)
		if not floor then
			continue
		end
		if root.Position.Y < floor.Origin[2] - FALL_LIMIT then
			local cf = spawnCfFor(floorId)
			if cf then
				moveCharacterTo(player, cf)
			end
		end
	end
end

function FloorService:Init()
	-- All wiring happens in Start; Init may not touch other services.
end

function FloorService:Start()
	Net.bind("RequestTeleport", 1, 2, t.tuple(t.string), onRequestTeleport)

	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	trove:Connect(Players.PlayerAdded, watchPlayer)
	trove:Connect(Players.PlayerRemoving, forgetPlayer)

	-- A skip pass bought mid-session should open its floor immediately, not
	-- after a rejoin. Guarded by Id ~= 0 so unconfigured passes never match.
	trove:Connect(MarketplaceService.PromptGamePassPurchaseFinished, function(player: Player, passId: number, purchased: boolean)
		if not purchased then
			return
		end
		for _, passKey in SKIP_PASS_BY_FLOOR do
			local pass = Monetization.passByKey(passKey)
			if pass and pass.Id ~= 0 and pass.Id == passId then
				local cache = skipOwned[player]
				if cache then
					cache[passKey] = true
				end
			end
		end
	end)

	trove:Add(task.spawn(function()
		while true do
			task.wait(FALL_CHECK_INTERVAL)
			runFallCheck()
		end
	end))
end

return FloorService
