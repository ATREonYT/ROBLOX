--!strict
-- RivalService — the authoritative brain for every desk rival and floor boss.
-- Pure state, no models: the server only knows "rival X has Y workload left",
-- and RivalRenderer on each client builds the visible suit-guy from that. This
-- keeps the server's per-frame cost near zero and makes cheating pointless —
-- there is nothing physical to exploit (§13.8).
--
-- Replication contract (CONTRACTS.md): a Full list to each joining player
-- (spot CFrames travel once, as 12 raw components), then compact Deltas at
-- RivalTickHz for whichever entries changed since the last tick.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Net = require(ServerScriptService.Server.Net.Net)
local DataService = require(ServerScriptService.Server.Data.DataService)
local Stack = require(ServerScriptService.Server.Economy.Stack)
local MapService = require(ServerScriptService.Server.World.MapService)
local FloorService = require(ServerScriptService.Server.Progression.FloorService)

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Config.Balance)
local Rivals = require(Shared.Config.Rivals)
local Severance = require(Shared.Config.Severance)

local Trove = require(ReplicatedStorage.Packages.Trove)
local t = require(ReplicatedStorage.Packages.t)

-- Payday pads fire Touched for every limb of a walking character; without a
-- debounce one step would pay (and teleport) several times.
local PAYDAY_DEBOUNCE_SECONDS = 2

-- Same lift FloorService uses: pivot to pad level would bury the character's legs.
local SPAWN_LIFT = 4

type RivalRuntime = {
	Id: string,
	FloorId: string,
	DefIndex: number,
	Cf: CFrame,
	MaxWorkload: number,
	BaseWins: number,
	IsBoss: boolean,
	Remaining: number, -- workload left; 0 while waiting to respawn
	RespawnAt: number, -- workspace server time it comes back; 0 = alive
	-- What Remaining resets to on respawn. Rivals are shared server-wide but
	-- InsiderKnowledge is personal, so the head start applied is the one owned
	-- by the player whose defeat scheduled this respawn — they are the one
	-- farming this desk right now.
	SpawnRemaining: number,
	Dirty: boolean,
}

local RivalService = {}

local trove = Trove.new()
local rivals: { [string]: RivalRuntime } = {}
-- Array twin of `rivals` so the Full payload has a stable order.
local rivalList: { RivalRuntime } = {}

-- Wins earned in the current wing run, per player. Banked (as a bonus) by
-- Payday pads and zeroed on any floor change — a run ends when you leave.
local runWins: { [Player]: number } = {}
local lastKnownFloor: { [Player]: string } = {}
local lastPaydayAt: { [Player]: number } = {}

-- ── State construction ──────────────────────────────────────────────────────

local function buildRivalsFromManifests()
	for floorId, manifest in MapService.allManifests() do
		-- Copy counters make ids stable per floor: the second Colleague placed
		-- becomes "<floor>_3_2" no matter what the other floors contain.
		local copyCounters: { [number]: number } = {}
		for _, spot in manifest.RivalSpots do
			local def = Rivals.get(floorId, spot.DefIndex)
			if not def then
				warn(("[RivalService] %s has a RivalSpot with unknown DefIndex %d — skipping it"):format(floorId, spot.DefIndex))
				continue
			end
			local copy = (copyCounters[spot.DefIndex] or 0) + 1
			copyCounters[spot.DefIndex] = copy

			local rival: RivalRuntime = {
				Id = Rivals.rivalId(floorId, spot.DefIndex, copy),
				FloorId = floorId,
				DefIndex = spot.DefIndex,
				Cf = spot.Cf,
				MaxWorkload = def.Workload,
				BaseWins = def.Wins,
				IsBoss = def.IsBoss == true,
				Remaining = def.Workload,
				RespawnAt = 0,
				SpawnRemaining = def.Workload,
				Dirty = false,
			}
			rivals[rival.Id] = rival
			table.insert(rivalList, rival)
		end
	end
end

-- ── Replication ─────────────────────────────────────────────────────────────

local function buildFullPayload(): { { [string]: any } }
	local payload = {}
	for _, rival in rivalList do
		table.insert(payload, {
			Id = rival.Id,
			DefIndex = rival.DefIndex,
			-- 12 raw components instead of a CFrame: remotes serialize plain
			-- number arrays cheaply and the client rebuilds with CFrame.new(...).
			Cf = { rival.Cf:GetComponents() },
			Remaining = rival.Remaining,
			RespawnAt = rival.RespawnAt,
		})
	end
	return payload
end

local function sendFullTo(player: Player)
	Net.sendTo(player, "RivalState", { Full = buildFullPayload() })
end

local function sendDeltas()
	local deltas = {}
	for _, rival in rivalList do
		if rival.Dirty then
			rival.Dirty = false
			table.insert(deltas, {
				Id = rival.Id,
				Remaining = rival.Remaining,
				RespawnAt = rival.RespawnAt,
			})
		end
	end
	if #deltas > 0 then
		Net.sendAll("RivalState", { Delta = deltas })
	end
end

-- ── Out-working ─────────────────────────────────────────────────────────────

local function onDefeat(rival: RivalRuntime, player: Player, data: DataService.ProfileData, passes: Stack.Passes)
	rival.Remaining = 0
	local respawnSeconds = if rival.IsBoss then Balance.BossRespawnSeconds else Balance.RivalRespawnSeconds
	rival.RespawnAt = Workspace:GetServerTimeNow() + respawnSeconds
	local headStart = Severance.effects(data.Severance).RivalHeadStart
	rival.SpawnRemaining = rival.MaxWorkload * (1 - headStart)

	local award = Stack.winsAward(rival.BaseWins, data, passes)
	DataService.update(player, function(live)
		live.Wins += award
		-- BossesDefeated gates the next floor's elevator; append-once keeps
		-- repeat boss farms from growing the array forever.
		if rival.IsBoss and not table.find(live.BossesDefeated, rival.FloorId) then
			table.insert(live.BossesDefeated, rival.FloorId)
		end
	end)
	runWins[player] = (runWins[player] or 0) + award

	local kind = if rival.IsBoss then "BossDefeated" else "RivalDefeated"
	-- Broadcast: a defeat is a world-visible moment every client animates.
	Net.sendAll("Fx", { Kind = kind, RivalId = rival.Id, UserId = player.UserId, Wins = award })
end

local function onRequestOutwork(player: Player, rivalId: string)
	local data = DataService.get(player)
	if not data then
		return
	end
	-- Membership in `rivals` proves the id both parses and names a real spot —
	-- every key in the table was minted by Rivals.rivalId at build time.
	local rival = rivals[rivalId]
	if not rival then
		return
	end
	if rival.RespawnAt ~= 0 or rival.Remaining <= 0 then
		return -- defeated and waiting to respawn; late clicks are harmless
	end

	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (root and root:IsA("BasePart")) then
		return
	end
	if (root.Position - rival.Cf.Position).Magnitude > Balance.RivalReachStuds then
		return -- an exploited client can name any rival; distance is the real gate
	end

	local passes = DataService.passesFor(player)
	local damage = Stack.outworkDamage(data.Productivity, data, passes)
	rival.Remaining -= damage
	rival.Dirty = true

	if rival.Remaining <= 0 then
		onDefeat(rival, player, data, passes)
	end
	-- ClickResult always carries the DAMAGE dealt (the popup number); Wins on a
	-- defeat travel separately in the Fx broadcast above.
	Net.sendTo(player, "ClickResult", { Amount = damage, Crit = "none", Kind = "outwork", RivalId = rivalId })
end

-- ── Payday pads ─────────────────────────────────────────────────────────────

local function onPaydayTouched(floorId: string, segment: number, otherPart: BasePart)
	local characterCandidate = otherPart.Parent
	if not (characterCandidate and characterCandidate:IsA("Model")) then
		return
	end
	local player = Players:GetPlayerFromCharacter(characterCandidate)
	if not player then
		return
	end
	local now = os.clock()
	if now - (lastPaydayAt[player] or -math.huge) < PAYDAY_DEBOUNCE_SECONDS then
		return
	end
	lastPaydayAt[player] = now

	local data = DataService.get(player)
	if not data then
		return
	end

	-- Deeper pads multiply harder (Segment), so pushing further before cashing
	-- out is always tempting — but the pad is pure upside, never a toll (§5).
	local bonus = math.floor(Balance.PaydayBonusFraction * (runWins[player] or 0) * segment)
	if bonus > 0 then
		DataService.update(player, function(live)
			live.Wins += bonus
		end)
		Net.sendAll("Fx", { Kind = "Payday", UserId = player.UserId, Wins = bonus })
	end
	runWins[player] = 0

	-- Back to this floor's hub spawn. Same floor, so FloorService's tracked
	-- floor stays correct without any cross-service notification.
	local manifest = MapService.manifestFor(floorId)
	local character = player.Character
	if manifest and character then
		character:PivotTo(manifest.Spawn + Vector3.new(0, SPAWN_LIFT, 0))
	end
end

local function connectPaydayPads()
	for floorId, manifest in MapService.allManifests() do
		for _, entry in manifest.PaydayPads do
			local segment = entry.Segment
			trove:Connect(entry.Pad.Touched, function(otherPart: BasePart)
				onPaydayTouched(floorId, segment, otherPart)
			end)
		end
	end
end

-- ── The tick ────────────────────────────────────────────────────────────────

local function runTick()
	local now = Workspace:GetServerTimeNow()
	for _, rival in rivalList do
		if rival.RespawnAt ~= 0 and now >= rival.RespawnAt then
			rival.Remaining = rival.SpawnRemaining
			rival.RespawnAt = 0
			rival.Dirty = true
		end
	end

	-- Wing runs end the moment the player leaves the floor by ANY route
	-- (elevator, fall-catch, respawn) — watching floorOf catches all of them
	-- without FloorService having to tell us anything.
	for _, player in Players:GetPlayers() do
		local floorId = FloorService.floorOf(player)
		if lastKnownFloor[player] ~= floorId then
			lastKnownFloor[player] = floorId
			runWins[player] = 0
		end
	end

	sendDeltas()
end

-- ── Service lifecycle ───────────────────────────────────────────────────────

function RivalService:Init()
	-- All wiring happens in Start; Init may not touch other services.
end

function RivalService:Start()
	-- MapService built the whole tower in its Init, so every manifest exists
	-- by the time any Start runs.
	buildRivalsFromManifests()
	connectPaydayPads()

	Net.bind("RequestOutwork", 22, 25, t.tuple(t.string), onRequestOutwork)

	for _, player in Players:GetPlayers() do
		sendFullTo(player)
	end
	trove:Connect(Players.PlayerAdded, sendFullTo)
	-- Belt and braces: the join-time Full can race a slow client boot, and the
	-- profile-load push lands seconds later when the client is surely listening.
	trove:Connect(DataService.PlayerLoaded :: any, function(player: Player)
		sendFullTo(player)
	end)
	trove:Connect(Players.PlayerRemoving, function(player: Player)
		runWins[player] = nil
		lastKnownFloor[player] = nil
		lastPaydayAt[player] = nil
	end)

	trove:Add(task.spawn(function()
		while true do
			task.wait(1 / Balance.RivalTickHz)
			runTick()
		end
	end))
end

return RivalService
