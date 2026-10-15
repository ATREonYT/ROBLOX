--[[
	The core loop: intermission -> rounds -> a winner takes the girl home.
	RoundRules decides everything; this script moves players, watches the
	zones and tags, and turns rule events into carries, messages and saves.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Round)
local Rules = require(Shared.RoundRules)
local Net = require(Shared.Net)
local MapService = require(script.Parent.MapService)
local GirlService = require(script.Parent.GirlService)
local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)

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
local prize = nil -- her display model while nobody holds her
local goalName = "ZoneB"
local frozen = false

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
	Workspace:SetAttribute("NextRoundAt", if stage == "Intermission" then State:GetAttribute("EndsAt") else nil)
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
		return StarterPlayer.CharacterWalkSpeed
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
		local still = frozen and match and match.roles[id] ~= nil
		h.WalkSpeed = if still then 0 else speedFor(id)
		h.JumpHeight = if still then 0 else StarterPlayer.CharacterJumpHeight
		h.JumpPower = if still then 0 else StarterPlayer.CharacterJumpPower
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
	local middle = zones.Middle.Position
	local zone, lookAt
	if not role then
		zone, lookAt = (match and zones.Bench) or zones.Lobby, middle
	else
		local start, goal = zones[MapService.startFor(match.round)], zones[goalName]
		if role == "Catcher" then
			zone, lookAt = zones.Middle, start.Position
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
	if girl then
		prize = GirlService.display(girl, zones[goalName], zones.Middle.Position, Workspace)
	end
end

local function girlPosition(id)
	return (id and CarryService.position(byId[id])) or (prize and prize:GetBoundingBox().Position) or nil
end

local function moveGirlTo(fromId, toId)
	local from = girlPosition(fromId)
	if fromId and byId[fromId] then
		CarryService.remove(byId[fromId])
	end
	clearPrize()
	if toId and byId[toId] then
		CarryService.give(byId[toId], girl, from)
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
	moveGirlTo(e.from, e.to)
	if not e.to then
		showPrize()
	end
	for _, id in { e.from, e.to } do
		syncPlayer(id)
	end
	State:SetAttribute("Phase", match.phase)
	local to, g = nameOf(e.to), girl.name
	local messages = {
		FirstAcross = { `{to} grabbed {g}!`, GOLD },
		Stolen = { `{to} STOLE {g}! Cross to take her back!`, RED },
		Rescued = { `{to} rescued {g}! Next round is the FINAL round!`, GOLD },
		Reassigned = { `{to} now holds {g}`, RED },
		Dropped = { `{g} was dropped! First across takes her`, GOLD },
	}
	local m = messages[e.reason]
	if m then
		announce(m[1], m[2], true)
	end
end

function handlers.Caught(e)
	syncPlayer(e.id)
	RoundNet:FireAllClients("Caught", { catcher = e.by, runner = e.id })
	task.delay(0.6, function()
		if match and match.status[e.id] == "Caught" then
			place(e.id)
		end
	end)
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
	for catcherId, role in match.roles do
		local catcher = role == "Catcher" and rootOf(catcherId)
		if catcher then
			for runnerId, status in match.status do
				local runner = status == "Active" and rootOf(runnerId)
				if
					runner
					and (runner.Position - catcher.Position).Magnitude <= Config.TagRange
					and not (Config.StartZoneSafe and MapService.inZone(start, runner.Position))
				then
					apply(Rules.tag(match, catcherId, runnerId))
					if match.over then
						return
					end
				end
			end
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

	frozen = true
	for id in match.roles do
		place(id)
	end
	syncAll()
	if match.holder == nil then
		showPrize() -- she waits on the far side
	end
	apply(events)
	setStage("Countdown", Config.CountdownTime)
	task.wait(Config.CountdownTime)

	frozen = false
	syncAll()
	setStage("Running", Config.RoundTime)
	local deadline = os.clock() + Config.RoundTime
	while not Rules.isRoundOver(match) and os.clock() < deadline do
		local dt = RunService.Heartbeat:Wait()
		if match.holder then
			holdSeconds += dt
		end
		step()
	end
	saveHold()
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
			moveGirlTo(match.holder, winnerId)
		end
		RoundNet:FireAllClients("Win", { winner = winnerId, name = winner.DisplayName, girl = girl.name, rarity = girl.rarity })
	else
		RoundNet:FireAllClients("Win", { girl = girl.name, rarity = girl.rarity })
	end
	State:SetAttribute("HolderId", winnerId or 0)
	frozen = false
	setStage("GameOver", Config.GameOverTime)
	task.wait(Config.GameOverTime)
end

local function runGame()
	girl = GirlService.roll()
	local ids = {}
	for id in byId do
		table.insert(ids, id)
	end
	local catcher = if #ids >= 2 then ids[math.random(#ids)] else nil
	match = Rules.newGame(ids, catcher, { maxRounds = Config.MaxRounds })
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
	CarryService.removeAll()
	clearPrize()
	match, girl, frozen = nil, nil, false
	State:SetAttribute("GirlName", "")
	State:SetAttribute("HolderId", 0)
	State:SetAttribute("Round", 0)
	for id in byId do
		place(id)
	end
	syncAll()
end

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
		if match and match.roles[id] then
			place(id)
			if match.holder == id and not CarryService.get(player) then
				CarryService.give(player, girl, nil)
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

while true do
	setStage("Waiting")
	while playerCount() < minPlayers do
		task.wait(1)
	end
	setStage("Intermission", Config.IntermissionTime)
	local deadline = os.clock() + Config.IntermissionTime
	while os.clock() < deadline and playerCount() >= minPlayers do
		task.wait(0.25)
	end
	if playerCount() >= minPlayers then
		local ok, err = xpcall(runGame, debug.traceback)
		if not ok then
			warn("[Huzz] Game stopped by an error: " .. tostring(err))
		end
		cleanUp()
	end
end
