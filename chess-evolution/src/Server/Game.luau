--!strict
-- +1 Chess Evolution: server wiring. Core.luau holds the rules; this file connects them to
-- remotes, characters, the map's zones and saves. The server owns progress, outcomes,
-- purchases and rewards; the client only sends "tap", "challenge", "buy", "equip".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Kit = ReplicatedStorage:WaitForChild("Kit")
local Net = require(Kit:WaitForChild("Net"))
local Core = require(script.Parent:WaitForChild("Core"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local T = Net.T
local Game = {}

local config: any
local core: any
local sessions: { [Player]: Core.Session } = {}
local dirty: { [Player]: boolean } = {}
local battleSent: { [Player]: number } = {}
local StatePush, BattlePush, BattleEndPush, FxPush

local function log(msg: string)
	print(`[Chess] {msg}`)
end

local function mapFolder(): Instance?
	return workspace:FindFirstChild("Map")
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Is the character inside a zone part's box (plus slack, plus some height)?
local function insideZone(root: BasePart, zone: BasePart, slack: number, height: number): boolean
	local p = zone.CFrame:PointToObjectSpace(root.Position)
	local half = zone.Size / 2
	return math.abs(p.X) <= half.X + slack and math.abs(p.Z) <= half.Z + slack and p.Y >= -half.Y - 2 and p.Y <= half.Y + height
end

local function zoneFor(kind: string, id: string): BasePart?
	local map = mapFolder()
	if not map then
		return nil
	end
	if kind == "station" then
		local model = map:FindFirstChild("Stations") and map.Stations:FindFirstChild(id)
		return model and model:FindFirstChild("Deck") :: BasePart?
	elseif kind == "stage" then
		local model = map:FindFirstChild("Stages") and map.Stages:FindFirstChild(id)
		return model and model:FindFirstChild("Zone") :: BasePart?
	end
	return nil
end

local function nearFn(player: Player): (string, string) -> boolean
	return function(kind: string, id: string): boolean
		local root = rootOf(player)
		local zone = zoneFor(kind, id)
		if not root or not zone then
			return false
		end
		return insideZone(root, zone, config.Input.distanceSlack, 8)
	end
end

local function data(player: Player): any?
	local profile = PlayerData.Get(player)
	return profile and (profile.Data :: any).Chess
end

local function markDirty(player: Player)
	dirty[player] = true
	local profile = PlayerData.Get(player)
	if profile then
		PlayerData.MarkDirty(profile)
	end
end

local function snapshot(player: Player): any
	local d = data(player)
	local s = sessions[player]
	if not d then
		return { loaded = false }
	end
	return {
		loaded = true,
		Wins = d.Wins,
		Power = d.Power,
		Sets = d.Sets,
		Equipped = d.Equipped,
		Cleared = d.Cleared,
		Settings = d.Settings,
		station = s and s.station,
		lastStation = s and s.lastStation,
		battle = s and s.battle and s.battle.id,
	}
end

local function updateLeaderstats(player: Player)
	local d = data(player)
	local stats = player:FindFirstChild("leaderstats")
	if d and stats then
		(stats:FindFirstChild("Wins") :: IntValue).Value = d.Wins;
		(stats:FindFirstChild("Power") :: IntValue).Value = d.Power
	end
end

-- Character control during a fight: stand on the player spot and hold still.
local function holdCharacter(player: Player, stageId: string?, hold: boolean)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if hold and stageId then
		local map = mapFolder()
		local spot = map and map:FindFirstChild("Stages") and map.Stages:FindFirstChild(stageId) and map.Stages[stageId]:FindFirstChild("PlayerSpot") :: BasePart?
		if spot and character then
			character:PivotTo(spot.CFrame + Vector3.new(0, 3, 0))
		end
		humanoid.WalkSpeed = 0
		humanoid.JumpHeight = 0
		humanoid.UseJumpPower = false
	else
		humanoid.WalkSpeed = 16
		humanoid.JumpHeight = 7.2
	end
end

local function endSession(player: Player, reason: string)
	local s = sessions[player]
	if not s then
		return
	end
	local cleared = Core.Leave(core, s, reason)
	player:SetAttribute("Training", nil)
	if cleared.battle then
		holdCharacter(player, nil, false)
		BattleEndPush:Fire(player, { id = cleared.battle, outcome = "cancelled", reason = reason })
		log(`{player.Name}: battle {cleared.battle} cancelled ({reason})`)
	end
	if cleared.station or cleared.battle then
		dirty[player] = true
	end
end

local function onTap(player: Player, kind: string, id: string)
	local d = data(player)
	local s = sessions[player]
	if not d or not s then
		return
	end
	local ctx = if kind == "battle" then { kind = "battle", battle = id } else { kind = "train", station = id }
	local ok, amount = Core.Tap(core, d, s, ctx, nearFn(player))
	if ok and kind == "train" then
		player:SetAttribute("Training", id)
		markDirty(player)
		updateLeaderstats(player)
	elseif not ok and kind == "train" and amount ~= "TooFast" then
		-- Tell the client why (it shows one short line), at most a few times a second.
		dirty[player] = true
	end
end

local function challenge(player: Player, stageId: string): any
	local d = data(player)
	local s = sessions[player]
	if not d or not s then
		return Net.fail("NotLoaded")
	end
	local ok, result = Core.Challenge(core, d, s, stageId, nearFn(player))
	if not ok then
		return Net.fail(result)
	end
	markDirty(player)
	holdCharacter(player, stageId, true)
	local battle = result
	local stage = config.Stages[stageId]
	battleSent[player] = 0
	log(`{player.Name}: challenge {stageId} ({battle.id})`)
	return Net.ok({ id = battle.id, stage = stageId, fight = stage.fight, book = battle.book, firstClear = battle.firstClear })
end

local function stepBattles(dt: number)
	local now = os.clock()
	for player, s in sessions do
		if s.battle then
			local d = data(player)
			if not d then
				continue
			end
			local battle = s.battle
			local result, badges = Core.StepBattle(core, d, s, dt)
			if result then
				holdCharacter(player, nil, false)
				if result.reward > 0 then
					markDirty(player)
					updateLeaderstats(player)
					task.spawn(PlayerData.SaveNowAsync, player) -- a first clear is saved right away
				end
				dirty[player] = true
				BattleEndPush:Fire(player, {
					id = result.id,
					stage = result.stage,
					outcome = result.outcome,
					reward = result.reward,
					unlocked = result.unlocked,
					badges = badges,
					meter = if result.outcome == "win" then 100 elseif result.outcome == "lose" then 0 else 50,
				})
				log(`{player.Name}: {result.stage} {result.outcome} (+{result.reward} wins) badges [{table.concat(badges, ",")}]`)
			elseif #badges > 0 or now - (battleSent[player] or 0) >= 0.1 then
				battleSent[player] = now
				BattlePush:Fire(player, { id = battle.id, meter = battle.state.meter, t = battle.state.t, taps = battle.taps, badges = badges })
			end
		end
	end
end

local lastZoneCheck = 0
local function checkTraining()
	for player, s in sessions do
		if s.station then
			local near = nearFn(player)
			if not near("station", s.station) then
				Core.Leave(core, s, "walked")
				player:SetAttribute("Training", nil)
				dirty[player] = true
			end
		end
	end
end

local function flush()
	for player in dirty do
		dirty[player] = nil
		if player.Parent == Players then
			StatePush:Fire(player, snapshot(player))
		end
	end
end

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid.Died:Connect(function()
			endSession(player, "died")
		end)
	end
	-- A respawn (reset) also ends whatever was running.
	endSession(player, "respawn")
end

function Game.Init(cfg: any)
	config = cfg
	core = Core.new(cfg, os.clock)
	PlayerData.RegisterSlice("Chess", function()
		local d = Core.NewData(cfg)
		d.Settings = { Music = true, Sound = true, Reduced = false }
		return d
	end)

	StatePush = Net.Push("State")
	BattlePush = Net.Push("Battle")
	BattleEndPush = Net.Push("BattleEnd")
	FxPush = Net.Push("Fx")

	local stationKeys, stageKeys, setKeys = {}, {}, {}
	for k in cfg.Stations do
		table.insert(stationKeys, k)
	end
	for k in cfg.Stages do
		table.insert(stageKeys, k)
	end
	for k in cfg.Sets do
		table.insert(setKeys, k)
	end

	-- Taps: generous transport limit; Core applies the real ~6/s accepted-tap cap.
	Net.Listen("Tap", {
		rate = { burst = 25, perSecond = 20 },
		args = { T.oneOf({ "train", "battle" }), T.string(40) },
		handler = onTap,
	})
	Net.Handle("Challenge", {
		rate = { burst = 3, perSecond = 1 },
		args = { T.oneOf(stageKeys) },
		handler = challenge,
	})
	Net.Handle("Buy", {
		rate = { burst = 3, perSecond = 1 },
		args = { T.oneOf(setKeys) },
		handler = function(player: Player, setId: string)
			local d = data(player)
			if not d then
				return Net.fail("NotLoaded")
			end
			local ok, why = Core.Buy(core, d, setId)
			if not ok then
				return Net.fail(why or "Error")
			end
			markDirty(player)
			updateLeaderstats(player)
			task.spawn(PlayerData.SaveNowAsync, player)
			log(`{player.Name}: bought {setId}`)
			return Net.ok({ set = setId })
		end,
	})
	Net.Handle("Equip", {
		rate = { burst = 4, perSecond = 2 },
		args = { T.oneOf(setKeys) },
		handler = function(player: Player, setId: string)
			local d = data(player)
			if not d then
				return Net.fail("NotLoaded")
			end
			local ok, why = Core.Equip(core, d, setId)
			if not ok then
				return Net.fail(why or "Error")
			end
			markDirty(player)
			return Net.ok({ set = setId })
		end,
	})
	Net.Handle("Forfeit", {
		rate = { burst = 2, perSecond = 1 },
		args = {},
		handler = function(player: Player)
			endSession(player, "exit")
			return Net.ok()
		end,
	})
	Net.Handle("Setting", {
		rate = { burst = 6, perSecond = 3 },
		args = { T.oneOf({ "Music", "Sound", "Reduced" }), T.boolean },
		handler = function(player: Player, key: string, value: boolean)
			local d = data(player)
			if not d then
				return Net.fail("NotLoaded")
			end
			d.Settings[key] = value
			markDirty(player)
			return Net.ok()
		end,
	})
	-- Quick route back to the hub (Return pads and the result panel).
	Net.Handle("Return", {
		rate = { burst = 2, perSecond = 0.5 },
		args = {},
		handler = function(player: Player)
			local s = sessions[player]
			if s and s.battle then
				return Net.fail("Busy")
			end
			local map = mapFolder()
			local spawn = map and map:FindFirstChild("Spawn") :: BasePart?
			local character = player.Character
			if spawn and character and rootOf(player) then
				endSession(player, "return")
				character:PivotTo(CFrame.lookAt(spawn.Position + Vector3.new(0, 4, 0), spawn.Position + Vector3.new(0, 4, -10)))
			end
			return Net.ok()
		end,
	})
	Net.Handle("Hello", {
		rate = { burst = 3, perSecond = 1 },
		args = {},
		handler = function(player: Player)
			return Net.ok(snapshot(player))
		end,
	})
	local _ = stationKeys

	PlayerData.Loaded:Connect(function(player: Player)
		updateLeaderstats(player)
		dirty[player] = true
		local d = data(player)
		log(`{player.Name}: progress loaded (Wins {d and d.Wins}, Power {d and d.Power})`)
	end)

	local function onPlayer(player: Player)
		sessions[player] = Core.NewSession()
		local stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		local wins = Instance.new("IntValue")
		wins.Name = "Wins"
		wins.Parent = stats
		local power = Instance.new("IntValue")
		power.Name = "Power"
		power.Parent = stats
		stats.Parent = player
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		endSession(player, "left")
		sessions[player] = nil
		dirty[player] = nil
		battleSent[player] = nil
	end)

	RunService.Heartbeat:Connect(function(dt)
		stepBattles(dt)
		local now = os.clock()
		if now - lastZoneCheck >= 0.2 then
			lastZoneCheck = now
			checkTraining()
			flush()
		end
	end)
	local _fx = FxPush
end

return Game
