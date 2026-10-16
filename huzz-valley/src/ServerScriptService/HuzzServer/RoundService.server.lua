--[[
	The core loop: intermission -> rounds -> a winner takes the girl home.
	RoundRules decides everything; this script moves players, watches the
	zones and tags, and turns rule events into carries, messages and saves.
]]
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Round)
local Carry = require(Shared.Config.Carry)
local Rules = require(Shared.RoundRules)
local Net = require(Shared.Net)
local MapService = require(script.Parent.MapService)
local GirlService = require(script.Parent.GirlService)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local KnockdownService = require(script.Parent.KnockdownService)
local MapVoteService = require(script.Parent.MapVoteService)
local KnifeService = require(script.Parent.KnifeService)
local PowerService = require(script.Parent.PowerService)

require(script.Parent.SafetyService).clean()
MapService.init()
GirlService.init()

-- Round state lives in the Round remote's attributes; moments go through it as (kind, data).
local RoundNet = Net.get("Round") :: RemoteEvent
local State = RoundNet
local zones = MapService.zones
local GOLD = Color3.fromRGB(255, 205, 80)
local RED = Color3.fromRGB(255, 90, 90)

local byId = {} -- UserId -> Player
local match = nil -- RoundRules state while a game runs
local girl = nil -- this game's girl {name, rarity, template}
local prize = nil -- her display model while nobody holds her (GirlSpot "Middle"/"SafeZone")
local showcase = nil -- the big her floating over the map for the whole game (GirlSpot "Sky")
local goalName = "ZoneB"

-- Quest counters (Config/Progression) and the Index, saved through DataService.
local function addStat(id, stat, amount)
	local p = byId[id]
	if p then
		DataService.update(p, function(d)
			d.Stats[stat] = (d.Stats[stat] or 0) + amount
		end)
	end
end

local holdSeconds = 0 -- time the current holder has carried her, saved at round end
local function saveHold()
	if match and match.holder and holdSeconds >= 1 then
		addStat(match.holder, "HoldSeconds", math.floor(holdSeconds))
	end
	holdSeconds = 0
end

local function setStage(stage, seconds)
	State:SetAttribute("Stage", stage)
	State:SetAttribute("EndsAt", if seconds then Workspace:GetServerTimeNow() + seconds else 0)
	-- The Lobby HUD's "next round" banner counts down to this.
	Workspace:SetAttribute("NextRoundAt", if stage == "Intermission" or stage == "Voting" then State:GetAttribute("EndsAt") else nil)
end

local function humanoidOf(id)
	local p = byId[id]
	local c = p and p.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function rootOf(id)
	local h = humanoidOf(id)
	return h and h.Health > 0 and h.RootPart or nil
end

local function nameOf(id)
	local p = id and byId[id]
	return if p then p.DisplayName else "Someone"
end

local function announce(text, color, big)
	RoundNet:FireAllClients("Announce", { text = text, color = color, big = big })
end

local function speedFor(id)
	local role = match and match.roles[id]
	if not role then
		return Config.Speeds.Lobby or StarterPlayer.CharacterWalkSpeed
	elseif match.holder == id then
		return if role == "Catcher" then Config.Speeds.Thief else Config.Speeds.Holder
	end
	return Config.Speeds[role]
end

local function syncPlayer(id)
	local p = byId[id]
	if not p then
		return
	end
	p:SetAttribute("HuzzRole", match and match.roles[id] or "Lobby")
	p:SetAttribute("HuzzStatus", match and match.status[id] or "")
	local h = humanoidOf(id)
	if h then
		local still = KnockdownService.isDown(p) or PowerService.stuck(id)
		h.WalkSpeed = if still then 0 else PowerService.speedOf(id, speedFor(id))
		h.JumpHeight = if still then 0 else StarterPlayer.CharacterJumpHeight
		h.JumpPower = if still then 0 else StarterPlayer.CharacterJumpPower
	end
	-- Catchers hold a knife (Config.TagMode "Stab"); everyone else's hands are empty.
	local c = p.Character
	if c then
		if match and not match.over and match.roles[id] == "Catcher" and Config.TagMode == "Stab" then
			KnifeService.give(c)
		else
			KnifeService.take(c)
		end
	end
end

local function syncAll()
	for id in byId do
		syncPlayer(id)
	end
end

-- Puts a player where their role belongs this round.
local function place(id)
	local p = byId[id]
	local c = p and p.Character
	if not (c and c.PrimaryPart) then
		return
	end
	local role = match and match.roles[id]
	local status = match and match.status[id]
	local middle = if zones.Middle then zones.Middle.Position elseif zones.Lobby then zones.Lobby.Position else Vector3.zero
	local zone, lookAt
	if not role then
		-- Waiting for the next game: the Lobby part if there is one, else where they are.
		zone, lookAt = (match and zones.Bench) or zones.Lobby, middle
	else
		local start, goal = zones[MapService.startFor(match.round)], zones[goalName]
		if role == "Catcher" then
			zone, lookAt = zones.Middle, start.Position
			c:PivotTo(MapService.spot(zone, lookAt, Config.Map.MiddleSpawn))
			return
		elseif status == "Caught" then
			zone, lookAt = zones.Bench, middle
		elseif status == "Safe" then
			zone, lookAt = goal, middle
		else
			zone, lookAt = start, goal.Position
		end
	end
	if zone then
		c:PivotTo(MapService.spot(zone, lookAt))
	end
end

local function clearPrize()
	if prize then
		prize:Destroy()
		prize = nil
	end
end

local function showPrize()
	clearPrize()
	if girl and Config.GirlSpot ~= "Sky" then
		-- In the middle (Config.GirlSpot "Middle"), facing the runners' side; or on the far side.
		local inMiddle = Config.GirlSpot == "Middle"
		local spot = if inMiddle then zones.Middle else zones[goalName]
		local face = if inMiddle then zones[MapService.startFor(match and match.round or 1)].Position else zones.Middle.Position
		local floor = MapService.ground(spot.Position, spot.Position.Y + spot.Size.Y / 2) or (spot.Position.Y - spot.Size.Y / 2)
		prize = GirlService.display(girl, Vector3.new(spot.Position.X, floor, spot.Position.Z), face, Workspace)
	end
end

local function girlPosition(id)
	return (id and CarryService.position(byId[id])) or (prize and prize:GetBoundingBox().Position) or nil
end

-- How she reacts to her new carrier.
local MOODS = { FirstAcross = "Excited", Grabbed = "Excited", Rescued = "Excited", Stolen = "Struggle", Reassigned = "Struggle" }

local function moveGirlTo(fromId, toId, reason)
	local from = girlPosition(fromId)
	if fromId and byId[fromId] then
		CarryService.remove(byId[fromId])
	end
	clearPrize()
	local to = toId and byId[toId]
	if to and match and match.roles[toId] == "Catcher" then
		CarryService.follow(to, girl, from) -- a catcher who caught her carrier: she falls down and follows him
	elseif to then
		CarryService.give(to, girl, from, MOODS[reason] or "Excited")
	end
	State:SetAttribute("HolderId", toId or 0)
end

-- Rule events -> the world
local handlers = {}

function handlers.GirlMoved(e)
	saveHold()
	if e.from and e.to then
		addStat(e.to, "Steals", 1) -- took her from someone
	end
	moveGirlTo(e.from, e.to, e.reason)
	if not e.to then
		showPrize()
	end
	for _, id in { e.from, e.to } do
		syncPlayer(id)
	end
	State:SetAttribute("Phase", match.phase)
	local to, g = nameOf(e.to), girl.name
	local messages = {
		FirstAcross = { `{to} got {g}!`, GOLD },
		Grabbed = { `{to} grabbed {g}! Carry her across!`, GOLD },
		Stolen = { `{to} caught her carrier! {g} follows {to} now. Cross first to take her back!`, RED },
		Rescued = { `{to} rescued {g}! Next round is the FINAL round!`, GOLD },
		Reassigned = { `{to} now holds {g}`, RED },
		Dropped = { if Config.Pickup == "Grab" then `{g} was dropped! She's back in the middle` else `{g} was dropped! First across gets her`, GOLD },
	}
	local m = messages[e.reason]
	if m then
		announce(m[1], m[2], true)
	end
end

function handlers.Caught(e)
	-- Falls flat where they were caught and lies there until the next round
	-- (or, with Knockdown off, goes to the bench).
	if Config.Knockdown.Enabled and byId[e.id] then
		KnockdownService.down(byId[e.id])
	end
	syncPlayer(e.id)
	RoundNet:FireAllClients("Caught", { catcher = e.by, runner = e.id })
	if not Config.Knockdown.Enabled then
		task.delay(0.6, function()
			if match and match.status[e.id] == "Caught" then
				place(e.id)
			end
		end)
	end
end

function handlers.Safe(e)
	syncPlayer(e.id)
	if byId[e.id] then
		RoundNet:FireClient(byId[e.id], "Announce", { text = "SAFE!", color = Color3.fromRGB(110, 230, 150) })
	end
end

function handlers.FinalRound(e)
	State:SetAttribute("Phase", "Final")
	announce(`FINAL ROUND! {nameOf(e.runner)} must cross with {girl.name}!`, GOLD, true)
end

function handlers.NewCatcher(e)
	syncPlayer(e.id)
	announce(`{nameOf(e.id)} is a catcher now!`, RED)
end

local function apply(events)
	for _, e in events do
		local handler = handlers[e.type]
		if handler then
			handler(e)
		end
	end
end

-- One frame of a running round: who's across, who got tagged.
local function step()
	local goal = zones[goalName]
	local start = zones[MapService.startFor(match.round)]
	-- A runner who walks up to her (waiting in the middle) picks her up.
	if Config.Pickup == "Grab" and prize and match.holder == nil then
		local at = prize:GetBoundingBox().Position
		for id, status in match.status do
			local root = status == "Active" and rootOf(id)
			if root and (root.Position - at).Magnitude <= Config.GrabRange then
				apply(Rules.grab(match, id))
				break
			end
		end
	end
	for id, status in match.status do
		if status == "Active" then
			local root = rootOf(id)
			if root and MapService.inZone(goal, root.Position) then
				apply(Rules.reachSafe(match, id))
				if match.over then
					return
				end
			end
		end
	end
	if Config.TagMode == "Stab" then
		return -- catchers tag by stabbing (the Stab remote below)
	end
	for catcherId, role in match.roles do
		local catcher = role == "Catcher" and PowerService.canStab(catcherId) and rootOf(catcherId)
		if catcher then
			for runnerId, status in match.status do
				local runner = status == "Active" and rootOf(runnerId)
				if
					runner
					and (runner.Position - catcher.Position).Magnitude <= Config.TagRange
					and not (Config.StartZoneSafe and MapService.inZone(start, runner.Position))
				then
					if not PowerService.blocks(catcherId, runnerId) then
						apply(Rules.tag(match, catcherId, runnerId))
					end
					if match.over then
						return
					end
				end
			end
		end
	end
end

-- Anyone who got round the start wall goes back behind the line.
local function keepRunnersIn(zone)
	if not zone then
		return
	end
	for id, status in match.status do
		local root = status == "Active" and rootOf(id)
		local back = root and MapService.keepIn(zone, root.Position)
		if back then
			root.Parent:PivotTo(CFrame.new(back) * root.CFrame.Rotation)
		end
	end
end

local function runRound()
	local events = Rules.startRound(match)
	if match.over then
		apply(events)
		return
	end
	goalName = MapService.goalFor(match.round)
	State:SetAttribute("Round", match.round)
	State:SetAttribute("Goal", goalName)
	State:SetAttribute("Phase", match.phase)

	-- Before GO: runners stand behind their start line (a see-through wall holds it; they can
	-- walk around in their zone), catchers in the middle. SAFE ZONE marks the line to reach.
	local startName = MapService.startFor(match.round)
	KnockdownService.upAll()
	MapService.showGoal(goalName)
	MapService.holdStart(startName, true)
	for id in match.roles do
		place(id)
	end
	PowerService.newRound()
	syncAll()
	if match.holder == nil then
		showPrize() -- she waits in the middle (or on the far side)
	end
	announce(`ROUND {match.round}`, Color3.new(1, 1, 1), true)
	apply(events)
	setStage("Countdown", Config.CountdownTime)
	local go = os.clock() + Config.CountdownTime
	while os.clock() < go do
		RunService.Heartbeat:Wait()
		keepRunnersIn(zones[startName])
	end
	MapService.holdStart(startName, false)
	syncAll()
	setStage("Running", Config.RoundTime)
	local deadline = os.clock() + Config.RoundTime
	while not Rules.isRoundOver(match) and os.clock() < deadline do
		local dt = RunService.Heartbeat:Wait()
		if match.holder then
			holdSeconds += dt
		end
		PowerService.step()
		step()
	end
	saveHold()
	PowerService.clear() -- traps and effects end with the round
	apply(Rules.endRound(match, not Rules.isRoundOver(match)))
	syncAll()
	if not match.over then
		setStage("RoundOver", Config.RoundEndPause)
		task.wait(Config.RoundEndPause)
	end
end

local function finishGame()
	local winnerId = match.winner
	local winner = winnerId and byId[winnerId]
	for id in match.roles do
		addStat(id, "Rounds", 1) -- "Complete 3 matches"
	end
	if winner then
		-- Into the winner's collection: the Index shows every id in Characters.
		DataService.update(winner, function(d)
			d.Characters[girl.id] = d.Characters[girl.id] or os.time()
		end)
		if match.holder ~= winnerId then
			moveGirlTo(match.holder, winnerId, "Won")
		end
		CarryService.setMood(winner, "Cheer")
		RoundNet:FireAllClients("Win", { winner = winnerId, name = winner.DisplayName, girl = girl.name, rarity = girl.rarity })
	else
		RoundNet:FireAllClients("Win", { girl = girl.name, rarity = girl.rarity })
	end
	State:SetAttribute("HolderId", winnerId or 0)
	syncAll() -- knives away
	setStage("GameOver", Config.GameOverTime)
	task.wait(Config.GameOverTime)
end

-- The big showpiece of this game's girl over the middle of the map.
local function showShowcase()
	local m = zones.Middle
	if not (girl and m) then
		return
	end
	local floor = MapService.ground(m.Position, m.Position.Y + m.Size.Y / 2) or (m.Position.Y - m.Size.Y / 2)
	local ok, result = pcall(GirlService.showcase, girl, Vector3.new(m.Position.X, floor + Config.Showcase.Height, m.Position.Z), Workspace)
	if ok then
		showcase = result
	else
		warn("[Huzz] Couldn't show the girl over the map: " .. tostring(result))
	end
end

local function runGame()
	showShowcase()
	local ids = {}
	for id in byId do
		table.insert(ids, id)
	end
	local catcher = if #ids >= 2 then ids[math.random(#ids)] else nil
	match = Rules.newGame(ids, catcher, { maxRounds = Config.MaxRounds, pickup = Config.Pickup })
	State:SetAttribute("GirlName", girl.name)
	State:SetAttribute("GirlRarity", girl.rarity)
	State:SetAttribute("HolderId", 0)
	announce(`Today's girl: {girl.name}  ({girl.rarity})`, GirlService.rarity(girl.rarity).Color, true)
	if catcher then
		task.delay(1.5, announce, `{nameOf(catcher)} is the CATCHER!`, RED, true)
	end
	while not match.over do
		runRound()
	end
	finishGame()
end

local function cleanUp()
	KnockdownService.upAll()
	CarryService.removeAll()
	clearPrize()
	if showcase then
		showcase:Destroy()
		showcase = nil
	end
	MapService.holdStart(nil, false)
	PowerService.clear()
	MapService.showGoal(nil) -- the lines stay on the map, the SAFE ZONE sign goes out
	match, girl = nil, nil
	State:SetAttribute("GirlName", "")
	State:SetAttribute("HolderId", 0)
	State:SetAttribute("Round", 0)
	for id in byId do
		place(id) -- everyone back to the lobby
	end
	syncAll()
	-- The map stays in front of the lobby until the next vote picks its replacement.
end

-- Catchers stab (click / tap STAB). The client plays the move at once and tells us; we check the
-- catcher may stab now and tag the nearest runner in reach in front of them.
local lastStab = {}
Net.get("Stab").OnServerEvent:Connect(function(player)
	local id = player.UserId
	if not (match and not match.over and match.roles[id] == "Catcher" and State:GetAttribute("Stage") == "Running") then
		return
	end
	if Config.TagMode ~= "Stab" or KnockdownService.isDown(player) or not PowerService.canStab(id) then
		return -- (dizzy from a Heart Shield: no stabbing for a moment)
	end
	local now = os.clock()
	if lastStab[id] and now - lastStab[id] < Config.Stab.Cooldown * 0.8 then
		return -- faster than the button allows
	end
	lastStab[id] = now
	local me = rootOf(id)
	if not me then
		return
	end
	RoundNet:FireAllClients("Stab", { id = id }) -- everyone else sees the stab
	local start = zones[MapService.startFor(match.round)]
	local look = me.CFrame.LookVector
	local best, bestDistance = nil, Config.Stab.Range
	for runnerId, status in match.status do
		local root = status == "Active" and rootOf(runnerId)
		if root then
			local offset = root.Position - me.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local inFront = flat.Magnitude < 3.5 or look:Dot(flat.Unit) > -0.2 -- generous: runners lag on screen
			local safe = Config.StartZoneSafe and start and MapService.inZone(start, root.Position)
			if offset.Magnitude <= bestDistance and math.abs(offset.Y) < 8 and inFront and not safe then
				best, bestDistance = runnerId, offset.Magnitude
			end
		end
	end
	if best and not PowerService.blocks(id, best) then
		apply(Rules.tag(match, id, best))
	end
end)

-- Round powers (Config/Powers, HuzzServer/PowerService).
PowerService.start({
	match = function()
		return match
	end,
	running = function()
		return State:GetAttribute("Stage") == "Running"
	end,
	rootOf = rootOf,
	playerOf = function(id)
		return byId[id]
	end,
	isDown = KnockdownService.isDown,
	sync = function(id)
		syncPlayer(id)
	end,
	startZone = function()
		return match and zones[MapService.startFor(match.round)]
	end,
	inZone = MapService.inZone,
	ground = function(position)
		return MapService.ground(position, position.Y + 2)
	end,
})

-- Hussing: her carrier throws her up and catches her (every client plays it from HussAt, server
-- time). The client sends the time it started on its screen so its own view never jumps.
Net.get("Huss").OnServerEvent:Connect(function(player, at)
	local model = CarryService.get(player)
	if not (model and model:GetAttribute("Carrier") == player.UserId) or KnockdownService.isDown(player) then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local start = if type(at) == "number" and at == at then math.clamp(at, now - 0.4, now) else now
	local previous = model:GetAttribute("HussAt")
	if previous and start < previous + Carry.Huss.Time + Config.HussCooldown - 0.15 then
		return
	end
	model:SetAttribute("HussAt", start)
end)

-- Players
local function onCharacter(player, character)
	local id = player.UserId
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	humanoid.Died:Connect(function()
		if match and match.status[id] == "Active" then
			apply(Rules.tag(match, nil, id))
		end
	end)
	task.defer(function()
		if not (match and match.roles[id]) then
			place(id) -- waiting for the next game: to the lobby
		end
		if match and match.roles[id] then
			place(id)
			if match.holder == id and not CarryService.get(player) then
				if match.roles[id] == "Catcher" then
					CarryService.follow(player, girl, nil)
				else
					CarryService.give(player, girl, nil, "Calm")
				end
			end
		end
		syncPlayer(id)
	end)
end

local function onPlayer(player)
	byId[player.UserId] = player
	player:SetAttribute("HuzzRole", "Lobby")
	player.CharacterAdded:Connect(function(c)
		onCharacter(player, c)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do
	onPlayer(p)
end
Players.PlayerRemoving:Connect(function(player)
	lastStab[player.UserId] = nil
	if match then
		apply(Rules.removePlayer(match, player.UserId))
	end
	byId[player.UserId] = nil
end)

-- Main loop
local function playerCount()
	local n = 0
	for _ in byId do
		n += 1
	end
	return n
end
local minPlayers = if RunService:IsStudio() then Config.StudioMinPlayers else Config.MinPlayers

local function enough()
	return playerCount() >= minPlayers
end

-- Between games: everyone votes on two maps (one map: a short wait instead), the winner
-- appears in front of the lobby and everyone in the server is moved onto it.
local function chooseMap()
	if #MapService.maps >= 2 then
		local a, b = MapService.candidates()
		setStage("Voting", Config.VoteTime)
		local winner = MapVoteService.run(a.name, b.name, Config.VoteTime, enough)
		return winner and MapService.byName(winner)
	end
	setStage("Intermission", Config.IntermissionTime)
	local deadline = os.clock() + Config.IntermissionTime
	while os.clock() < deadline and enough() do
		task.wait(0.25)
	end
	return enough() and MapService.maps[1] or nil
end

-- The girl roller: everyone watches a strip of girl names spin at the top of the screen and stop
-- on this game's girl. She's picked first (fairly: Shared/GirlRoll), and every other name on the
-- strip is an honest pick too. Meanwhile she's rebuilt as R15 (Config/Round.GirlRig).
local function rollGirl()
	girl = GirlService.roll()
	local R = Config.Roll
	local cells, odds = GirlService.strip(girl, R.Cells, R.Stop)
	local list = {}
	for i, g in cells do
		list[i] = { name = g.name, rarity = g.rarity, key = g.key }
	end
	-- In an attribute (not a message), so players who join mid-roll see it too.
	local roll = { cells = list, stop = R.Stop, start = Workspace:GetServerTimeNow(), spin = R.SpinTime, odds = odds }
	State:SetAttribute("RollData", HttpService:JSONEncode(roll))
	setStage("Rolling", R.Time)
	local ready = false
	task.spawn(function()
		local ok, err = pcall(GirlService.prepare, girl)
		if not ok then
			warn("[Huzz] Couldn't rebuild " .. girl.name .. ": " .. tostring(err))
		end
		ready = true
	end)
	task.wait(R.Time)
	local waitUntil = os.clock() + 10
	while not ready and os.clock() < waitUntil do
		task.wait(0.1)
	end
	State:SetAttribute("RollData", "")
end

while true do
	setStage("Waiting")
	while not enough() do
		task.wait(1)
	end
	local map = chooseMap()
	if map and enough() then
		-- The winning map replaces the one in front of the lobby, then the girl roller spins.
		MapService.load(map)
		State:SetAttribute("Map", map.display)
		announce(`Map: {map.display}`, Color3.new(1, 1, 1), true)
		rollGirl()
		local ok, err = xpcall(runGame, debug.traceback)
		if not ok then
			warn("[Huzz] Game stopped by an error: " .. tostring(err))
		end
		cleanUp()
	end
end
