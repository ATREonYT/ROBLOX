--!strict
-- The stage loop: enemies stand in each stage, you attack them by clicking,
-- and clearing a stage's quota permanently unlocks the barrier at its far end.
--
--   attack  -> damage = Stack.outworkDamage(productivity, ...)
--   kill    -> Productivity reward + one tick toward this stage's quota
--   quota   -> stage marked cleared (saved) + barrier opens for that player
--   pads    -> yellow banks WinsReward, magenta banks 10x, both send you home
--
-- Enemies are server state only: no Humanoids, no server-side models. Clients
-- render them from the StageState replication (§13.7/13.8).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(ServerScriptService.Server.Data.DataService)
local Net = require(ServerScriptService.Server.Net.Net)
local Stack = require(ServerScriptService.Server.Economy.Stack)

local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Trove = require(ReplicatedStorage.Packages.Trove)
local t = require(ReplicatedStorage.Packages.t)

local StageService = {}

local trove = Trove.new()
local WorldService: any = nil

type Enemy = {
	Id: string,
	StageNumber: number,
	Index: number,
	MaxHealth: number,
	Health: number,
	RespawnAt: number, -- 0 = alive
	Cf: CFrame,
}

local enemies: { [string]: Enemy } = {}
local dirty: { [string]: boolean } = {}
-- Kills this visit, per player per stage. Not saved: the quota resets if you
-- leave, but a CLEARED stage stays cleared forever.
local progress: { [Player]: { [number]: number } } = {}
local padDebounce: { [Player]: number } = {}

local RESPAWN_SECONDS = 6
local ATTACK_RANGE = 34
local REPLICATE_HZ = 5

local function enemyId(stageNumber: number, index: number): string
	return ("S%d_%d"):format(stageNumber, index)
end

-- Compact wire form: the client needs position once and health per tick.
local function fullPayload(): { any }
	local list = {}
	for _, enemy in enemies do
		local x, y, z = enemy.Cf.X, enemy.Cf.Y, enemy.Cf.Z
		table.insert(list, {
			Id = enemy.Id,
			Stage = enemy.StageNumber,
			Max = enemy.MaxHealth,
			Health = enemy.Health,
			RespawnAt = enemy.RespawnAt,
			Pos = { x, y, z },
		})
	end
	return list
end

local function clearedList(player: Player): { number }
	local data = DataService.get(player)
	if data then
		return data.ClearedStages
	end
	local empty: { number } = {}
	return empty
end

-- Tell one player where they stand in every stage they are working on.
local function pushProgress(player: Player)
	local perStage: { [number]: number } = progress[player] or {}
	local rows = {}
	for stageNumber, kills in perStage do
		local stage = Stages.byNumber(stageNumber)
		if stage then
			table.insert(rows, { Stage = stageNumber, Kills = kills, Needed = stage.EnemyCount })
		end
	end
	Net.sendTo(player, "StageState", { Progress = rows, Cleared = clearedList(player) })
end

local function markCleared(player: Player, stageNumber: number)
	local data = DataService.get(player)
	if not data or table.find(data.ClearedStages, stageNumber) then
		return
	end
	DataService.update(player, function(live)
		table.insert(live.ClearedStages, stageNumber)
	end)
	local stage = Stages.byNumber(stageNumber)
	Net.sendAll("Fx", {
		Kind = "StageCleared",
		UserId = player.UserId,
		Stage = stageNumber,
		Name = if stage then stage.DisplayName else "",
	})
	DataService.pushState(player)
end

local function onAttack(player: Player, id: string)
	local enemy = enemies[id]
	if not enemy or enemy.RespawnAt > 0 then
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (root and root:IsA("BasePart")) then
		return
	end
	if (root.Position - enemy.Cf.Position).Magnitude > ATTACK_RANGE then
		return -- too far away to be swinging at this one
	end

	local passes = DataService.passesFor(player)
	local damage = Stack.outworkDamage(math.max(data.Productivity, 1), data, passes)
	enemy.Health = math.max(0, enemy.Health - damage)
	dirty[enemy.Id] = true

	Net.sendTo(player, "ClickResult", { Amount = damage, Crit = "none", Kind = "attack", EnemyId = enemy.Id })

	if enemy.Health > 0 then
		return
	end

	-- Defeated.
	local stage = Stages.byNumber(enemy.StageNumber)
	if not stage then
		return
	end
	enemy.RespawnAt = os.clock() + RESPAWN_SECONDS
	DataService.update(player, function(live)
		live.Productivity += stage.EnemyPowerReward
	end)
	Net.sendAll("Fx", {
		Kind = "EnemyDefeated",
		UserId = player.UserId,
		EnemyId = enemy.Id,
		Position = { enemy.Cf.X, enemy.Cf.Y, enemy.Cf.Z },
	})

	local perStage = progress[player]
	if not perStage then
		perStage = {}
		progress[player] = perStage
	end
	perStage[enemy.StageNumber] = (perStage[enemy.StageNumber] or 0) + 1
	if perStage[enemy.StageNumber] >= stage.EnemyCount then
		markCleared(player, enemy.StageNumber)
	end
	pushProgress(player)
end

-- Cash-out pads. Both require the stage to be cleared, both send you home:
-- the choice is whether you take the safe payout or the 10x one.
local function onPadTouched(player: Player, stageNumber: number, multiplier: number)
	local now = os.clock()
	if (padDebounce[player] or 0) > now then
		return
	end
	padDebounce[player] = now + 1.5

	local data = DataService.get(player)
	local stage = Stages.byNumber(stageNumber)
	if not (data and stage) then
		return
	end
	if not table.find(data.ClearedStages, stageNumber) then
		Net.sendTo(player, "ClickResult", {
			Amount = 0,
			Crit = "none",
			Kind = "locked",
			Label = ("Defeat %d %ss first"):format(stage.EnemyCount, stage.EnemyName),
		})
		return
	end

	local award = Stack.winsAward(stage.WinsReward * multiplier, data, DataService.passesFor(player))
	DataService.update(player, function(live)
		live.Wins += award
	end)
	Net.sendAll("Fx", { Kind = "CashOut", UserId = player.UserId, Wins = award })

	local character = player.Character
	if character then
		character:PivotTo(WorldService.spawnCf() + Vector3.new(0, 3, 0))
	end
	DataService.pushState(player)
end

local function buildEnemies()
	for stageNumber, manifest in WorldService.allStages() do
		local stage = Stages.byNumber(stageNumber)
		if not stage then
			continue
		end
		for index, cf in manifest.EnemySpots do
			local id = enemyId(stageNumber, index)
			enemies[id] = {
				Id = id,
				StageNumber = stageNumber,
				Index = index,
				MaxHealth = stage.EnemyHealth,
				Health = stage.EnemyHealth,
				RespawnAt = 0,
				Cf = cf,
			}
		end
	end
end

local function connectPads()
	for stageNumber, manifest in WorldService.allStages() do
		local function bindPad(pad: BasePart, multiplier: number)
			trove:Connect(pad.Touched, function(hit: BasePart)
				local character = hit.Parent
				local player = if character then Players:GetPlayerFromCharacter(character) else nil
				if player then
					onPadTouched(player, stageNumber, multiplier)
				end
			end)
		end
		bindPad(manifest.ReturnPad, 1)
		bindPad(manifest.BigPad, Stages.BigPadMultiplier)
		-- The barrier never collides server-side: the client decides whether it
		-- is solid for THIS player based on their cleared list. Wins are gated
		-- on the server regardless, so walking past early earns nothing.
		manifest.Barrier.CanCollide = false
	end
end

function StageService:Init() end

function StageService:Start()
	local worldFolder = ServerScriptService:WaitForChild("Server"):WaitForChild("World")
	WorldService = require(worldFolder:WaitForChild("WorldService") :: ModuleScript) :: any

	buildEnemies()
	connectPads()

	Net.bind("RequestAttack", 22, 25, t.tuple(t.string), onAttack)

	local function sendFull(player: Player)
		Net.sendTo(player, "StageState", { Full = fullPayload(), Cleared = clearedList(player) })
	end
	for _, player in Players:GetPlayers() do
		sendFull(player)
	end
	trove:Connect(Players.PlayerAdded, sendFull)
	trove:Connect(DataService.PlayerLoaded :: any, function(player: Player)
		sendFull(player)
	end)
	trove:Connect(Players.PlayerRemoving, function(player)
		progress[player] = nil
		padDebounce[player] = nil
	end)

	-- Respawn ticker + delta replication.
	trove:Add(task.spawn(function()
		while true do
			task.wait(1 / REPLICATE_HZ)
			local now = os.clock()
			for _, enemy in enemies do
				if enemy.RespawnAt > 0 and now >= enemy.RespawnAt then
					enemy.RespawnAt = 0
					enemy.Health = enemy.MaxHealth
					dirty[enemy.Id] = true
				end
			end
			local delta = {}
			for id in dirty do
				local enemy = enemies[id]
				if enemy then
					table.insert(delta, { Id = id, Health = enemy.Health, RespawnAt = enemy.RespawnAt })
				end
			end
			if #delta > 0 then
				table.clear(dirty)
				Net.sendAll("StageState", { Delta = delta })
			end
		end
	end))
end

return StageService
