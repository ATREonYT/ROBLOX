--!strict
-- +1 Chess Evolution: server wiring. Core.luau holds the rules; this file connects them to
-- remotes, characters, the map's zones and saves. The server owns progress, outcomes,
-- purchases and rewards; the client only sends "tap", "challenge", "buy", "equip".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Kit = ReplicatedStorage:WaitForChild("Kit")
local Net = require(Kit:WaitForChild("Net"))
local ChessItems = require(Kit:WaitForChild("ChessItems"))
local Core = require(script.Parent:WaitForChild("Core"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local MarketplaceService = game:GetService("MarketplaceService")

local T = Net.T
local Game = {}

local config: any
local core: any
local sessions: { [Player]: Core.Session } = {}
local dirty: { [Player]: boolean } = {}
local battleSent: { [Player]: number } = {}
local trophyAt: { [Player]: number } = {} -- last trophy (Return pad Wins) paid
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
		Promotions = d.Promotions or 0,
		PromoPower = (config.PromotionCost(d.Promotions or 0)),
		PromoWins = select(2, config.PromotionCost(d.Promotions or 0)),
		TutorialDone = (d.Promotions or 0) >= 1,
		Passes = s and s.passes or {},
		Auto = s and s.auto or false,
		DailyReady = (d.DailyDay or -1) < Core.Day(os.time()),
		DailyTile = ((d.DailyStreak or 0) % #config.Daily) + 1,
		GiftsClaimed = s and s.gifts or {},
		SessionAge = s and math.floor(os.clock() - s.joinedAt) or 0,
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
	return Net.ok({ id = battle.id, stage = stageId, fight = battle.state.fight, intro = config.DuelIntro or 0, book = battle.book, firstClear = battle.firstClear })
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
					if result.firstClear then
						task.spawn(PlayerData.SaveNowAsync, player) -- a first clear is saved right away
					end
				end
				dirty[player] = true
				BattleEndPush:Fire(player, {
					id = result.id,
					stage = result.stage,
					outcome = result.outcome,
					reward = result.reward,
					unlocked = result.unlocked,
					firstClear = result.firstClear,
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

-- Auto Train (pass): taps for you anywhere, below the hand cap. Same Elo as a hand tap.
local autoAcc: { [Player]: number } = {}
local function stepAuto(dt: number)
	for player, s in sessions do
		if s.auto and s.passes.AutoTrain and not s.battle then
			autoAcc[player] = (autoAcc[player] or 0) + dt * config.AutoTrainRate
			while autoAcc[player] >= 1 do
				autoAcc[player] -= 1
				local d = data(player)
				if d then
					d.Power += config.TapGain(d.Equipped) * config.PowerMult(d.Promotions or 0, s.passes)
					d.Stats.Taps += 1
					markDirty(player)
				end
			end
		else
			autoAcc[player] = 0
		end
	end
end

-- Treadmills pay by themselves (Alex, Nov 8): standing on an open treadmill's deck gives its Elo
-- every TreadmillTick seconds. The client shows the pop when the "Fx" push arrives.
local treadAcc: { [Player]: number } = {}
local function stepTreadmills(dt: number)
	local map = mapFolder()
	local stations = map and map:FindFirstChild("Stations")
	if not stations then
		return
	end
	for player, s in sessions do
		local root = rootOf(player)
		local d = data(player)
		local on: string? = nil
		if root and d and not s.battle then
			for _, m in stations:GetChildren() do
				local deck = m:FindFirstChild("Deck")
				if deck and deck:IsA("BasePart") and config.Stations[m.Name] and insideZone(root, deck, 1, 8) then
					on = m.Name
					break
				end
			end
		end
		if not on or not Core.StationOpen(config, d, on) then
			treadAcc[player] = 0
			continue
		end
		treadAcc[player] = (treadAcc[player] or 0) + dt
		if treadAcc[player] >= config.TreadmillTick then
			treadAcc[player] -= config.TreadmillTick
			local ok, gain = Core.TreadmillGain(core, d, s, on :: string)
			if ok then
				player:SetAttribute("Training", on)
				markDirty(player)
				updateLeaderstats(player)
				FxPush:Fire(player, { kind = "tread", station = on, gain = gain })
			end
		end
	end
end

-- Game passes: always asked from Roblox on the server, never trusted from the client.
local function checkPasses(player: Player)
	local s = sessions[player]
	if not s then
		return
	end
	for key, pass in config.Passes do
		if pass.id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
			if ok and owns then
				s.passes[key] = true
			end
		end
	end
	dirty[player] = true
end

local function flush()
	for player in dirty do
		dirty[player] = nil
		if player.Parent == Players then
			StatePush:Fire(player, snapshot(player))
		end
	end
end

-- The equipped set's chess item in the hand, and its aura (ChessItems). Seen by everyone.
local function wearItem(player: Player)
	local d = data(player)
	local character = player.Character
	if not d or not character then
		return
	end
	local ok, err = pcall(ChessItems.Wear, character, d.Equipped or config.DefaultSet)
	if not ok then
		warn("[ChessItems] wear failed: " .. tostring(err))
	end
end

local function onCharacter(player: Player, character: Model)
	task.delay(1, wearItem, player) -- after the rig's hands exist
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
			wearItem(player)
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
			local root = rootOf(player)
			local paid = 0
			if spawn and character and root then
				-- Trophy: standing on a beaten stage's Return pad pays that stage's Wins, at most once
				-- per walk from the hub (Auto Wins farms this; clip 2 of Nov 8).
				local d = data(player)
				local stagesFolder = map and map:FindFirstChild("Stages")
				if d and s and stagesFolder then
					for id, st in config.Stages do
						local m = stagesFolder:FindFirstChild(id)
						local pad = m and m:FindFirstChild("Return")
						if pad and pad:IsA("BasePart") and d.Cleared[id] and insideZone(root, pad, config.Input.distanceSlack, 8) then
							local walk = math.max(2, (pad.Position - spawn.Position).Magnitude / 22)
							if os.clock() - (trophyAt[player] or -math.huge) >= walk then
								trophyAt[player] = os.clock()
								paid = math.floor(st.reward * config.WinsMult(d.Promotions or 0, s.passes))
								d.Wins += paid
								markDirty(player)
								updateLeaderstats(player)
								log(`{player.Name}: trophy {id} +{paid} wins`)
							end
							break
						end
					end
				end
				endSession(player, "return")
				character:PivotTo(CFrame.lookAt(spawn.Position + Vector3.new(0, 4, 0), spawn.Position + Vector3.new(0, 4, -10)))
			end
			return Net.ok({ trophy = paid })
		end,
	})
	-- Promotion, daily, playtime gifts, codes, shop ------------------------------
	local function simple(name: string, args: { any }, fn: (Player, any, Core.Session, ...any) -> (boolean, any), save: boolean)
		Net.Handle(name, {
			rate = { burst = 3, perSecond = 1 },
			args = args,
			handler = function(player: Player, ...)
				local d = data(player)
				local s = sessions[player]
				if not d or not s then
					return Net.fail("NotLoaded")
				end
				local ok, res = fn(player, d, s, ...)
				if not ok then
					return Net.fail(res or "Error")
				end
				markDirty(player)
				updateLeaderstats(player)
				if save then
					task.spawn(PlayerData.SaveNowAsync, player)
				end
				log(`{player.Name}: {name} ok`)
				return Net.ok(res)
			end,
		})
	end
	simple("Promote", {}, function(player, d, s)
		local ok, why = Core.Promote(core, d, s)
		if ok then
			player:SetAttribute("Training", nil)
			return true, { promotions = d.Promotions }
		end
		return false, why
	end, true)
	simple("ClaimDaily", {}, function(_player, d)
		return Core.ClaimDaily(core, d, os.time())
	end, true)
	simple("ClaimGift", { T.integer(1, #cfg.Playtime) }, function(_player, d, s, i)
		return Core.ClaimGift(core, d, s, i, os.clock())
	end, false)
	simple("Redeem", { T.string(24) }, function(_player, d, _s, code)
		return Core.Redeem(core, d, code)
	end, true)
	local passKeys = {}
	for k in cfg.Passes do
		table.insert(passKeys, k)
	end
	simple("SetAuto", { T.boolean }, function(_player, _d, s, on)
		if on and not s.passes.AutoTrain then
			return false, "NeedPass"
		end
		s.auto = on
		return true, { auto = on }
	end, false)
	-- Buying a pass: the prompt only opens for a real id; id 0 says "Coming soon" (repo rule).
	simple("BuyPass", { T.oneOf(passKeys) }, function(player, _d, s, key)
		local pass = cfg.Passes[key]
		if s.passes[key] then
			return false, "Owned"
		end
		if pass.id == 0 then
			return false, "ComingSoon"
		end
		MarketplaceService:PromptGamePassPurchase(player, pass.id)
		return true, { prompted = key }
	end, false)
	-- Power packs (developer products). id 0 = not made yet: "ComingSoon", never prompts.
	local packKeys, packById = {}, {}
	for _, pack in cfg.PowerPacks or {} do
		table.insert(packKeys, pack.key)
		if pack.id ~= 0 then
			packById[pack.id] = pack
		end
	end
	simple("BuyPack", { T.oneOf(packKeys) }, function(player, _d, _s, key)
		for _, pack in cfg.PowerPacks do
			if pack.key == key then
				if pack.id == 0 then
					return false, "ComingSoon"
				end
				MarketplaceService:PromptProductPurchase(player, pack.id)
				return true, { prompted = key }
			end
		end
		return false, "Unknown"
	end, false)
	-- Receipts: PlayerData grants each PurchaseId exactly once and saves before we confirm.
	MarketplaceService.ProcessReceipt = function(info: any)
		local player = Players:GetPlayerByUserId(info.PlayerId)
		local pack = packById[info.ProductId]
		if not player or not pack then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local result = PlayerData.ProcessPurchaseAsync(player, {
			Id = info.PurchaseId,
			Product = pack.key,
			Robux = info.CurrencySpent or pack.price,
			Time = os.time(),
		}, function(profile: any): boolean
			local d = profile.Data and profile.Data.Chess
			if not d then
				return false
			end
			d.Power += pack.amount
			return true
		end)
		if result == "granted" then
			dirty[player] = true
			updateLeaderstats(player)
			log(`{player.Name}: bought {pack.key} (+{pack.amount} Power)`)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		elseif result == "duplicate" then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, bought: boolean)
		if bought then
			task.spawn(checkPasses, player) -- re-ask Roblox; never trust this event alone
			log(`{player.Name}: pass {passId} bought, re-checking`)
		end
	end)

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
		wearItem(player)
	end)

	local function onPlayer(player: Player)
		sessions[player] = Core.NewSession()
		sessions[player].joinedAt = os.clock()
		task.spawn(checkPasses, player)
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
		autoAcc[player] = nil
		treadAcc[player] = nil
		trophyAt[player] = nil
	end)

	RunService.Heartbeat:Connect(function(dt)
		stepBattles(dt)
		stepAuto(dt)
		stepTreadmills(dt)
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
