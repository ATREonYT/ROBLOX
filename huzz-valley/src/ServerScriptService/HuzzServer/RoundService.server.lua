--[[
	The core loop, Huss Valley one to one (owner's call) with the anime girl built in:
	  vote -> girl roller -> rounds -> one side wins and the girl goes home with them.
	Each round: Lineup (runners in a row on their line) -> Picking (a random runner chooses HERO or
	CHICKEN; clients play the camera sweep, Gameplay/Cinematic) -> Chosen -> HeroRun (a Hero crosses
	alone) -> Countdown -> Running (everyone; stabbed runners go down, others can rescue them) ->
	RoundOver. RoundRules decides everything; this script moves players, watches the zones, stabs and
	rescues, and turns rule events into carries, messages, name tags and saves.
]]
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Round)
local CoinShop = require(ReplicatedStorage.Shared.Config.CoinShop)
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
local NameTags = require(script.Parent.NameTagService)
local PracticeBot = require(script.Parent.PracticeBot)

require(script.Parent.SafetyService).clean()
MapService.init()
GirlService.init()

-- Round state lives in the Round remote's attributes; moments go through it as (kind, data).
local RoundNet = Net.get("Round") :: RemoteEvent
local State = RoundNet
local zones = MapService.zones
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(91, 224, 122) -- (the good-news accent: Huss Valley green; owner: no gold)
local RED = Color3.fromRGB(255, 96, 96)
local GREEN = Color3.fromRGB(110, 236, 140)

local byId = {} -- UserId -> Player
local match = nil -- RoundRules state while a game runs
local girl = nil -- this game's girl {name, rarity, template}
local showcase = nil -- the big her floating over the map while nobody has her
local goalName = "ZoneB"
local frozen = {} -- id -> true: standing still on the line (lineup, pick, the Hero's solo run, countdown)
local rescueTime = {} -- downed id -> seconds someone has been helping them up
local protectedUntil = {} -- id -> os.clock() until which a just-rescued runner can't be stabbed
local botPlayed = false -- the Practice Bot caught for this game (then it, not a player, wins if every runner is down)
local botTagging = false -- true while the Practice Bot's stab is being applied (so the message names it)
local botStep -- (set once stabNear exists, further down)
local tally = {} -- id -> { Crossings = n, Catches = n, ... } this game only (the results screen at the end)

-- Quest counters (Config/Progression) and the Index, saved through DataService.
local function addStat(id, stat, amount)
	if id then
		tally[id] = tally[id] or {}
		tally[id][stat] = (tally[id][stat] or 0) + amount
	end
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

-- The message line at the top of everyone's screen (as in Huss Valley); big = also a centre banner.
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

local function tagLook(id)
	if not match then
		return nil
	end
	local role, status = match.roles[id], match.status[id]
	if role == "Catcher" then
		return "Catcher"
	elseif role == "Runner" then
		if status == "Downed" then
			return "Downed"
		elseif status == "Safe" then
			return "Safe"
		elseif match.hero == id then
			return "Hero"
		end
		return "Runner"
	end
	return nil
end

local function syncPlayer(id)
	local p = byId[id]
	if not p then
		return
	end
	p:SetAttribute("HuzzRole", match and match.roles[id] or "Lobby")
	p:SetAttribute("HuzzStatus", match and match.status[id] or "")
	p:SetAttribute("HuzzHero", match ~= nil and match.hero == id) -- this round's Hero (yellow outline)
	p:SetAttribute("HuzzFrozen", frozen[id] == true) -- on the line, waiting (no dash, no powers)
	-- Safe runners stay across (owner's call): their parts bump into the goal's gate (MapService.holdGoal).
	MapService.setSafe(p.Character, match ~= nil and not match.over and match.status[id] == "Safe")
	local h = humanoidOf(id)
	if h then
		local still = KnockdownService.isDown(p) or PowerService.stuck(id) or frozen[id] == true
		h.WalkSpeed = if still then 0 else PowerService.speedOf(id, speedFor(id))
		h:SetAttribute("HuzzSpeed", h.WalkSpeed) -- the top speed: Gameplay/Sprint builds up to it from a walk
		-- No jumping anywhere (owner: "remove the jumping from the lobby"): Space is the huss instead.
		h.JumpHeight = 0
		h.JumpPower = 0
	end
	-- Catchers hold a knife (Config.TagMode "Stab"); everyone else wears theirs on their back.
	local c = p.Character
	local profile = DataService.get(p)
	local wear = profile and profile.Data.Wear
	local knifeSkin = wear and wear.Knife and CoinShop.get(wear.Knife) or nil
	if c then
		if match and not match.over and match.roles[id] == "Catcher" and Config.TagMode == "Stab" then
			KnifeService.takeBack(c)
			KnifeService.give(c, knifeSkin) -- (in hand, with their knife skin)
		else
			KnifeService.take(c)
			KnifeService.giveBack(c, knifeSkin) -- everyone else wears theirs on their back
		end
	end
	local badge = nil
	if match and match.picked == id and match.choice then
		badge = string.upper(match.choice)
	end
	NameTags.set(p, tagLook(id), badge, rescueTime[id] and rescueTime[id] / Config.Rescue.Time)
end

local function syncAll()
	for id in byId do
		syncPlayer(id)
	end
end

local function runnersWith(status)
	local list = {}
	for id, st in match.status do
		if st == status then
			table.insert(list, id)
		end
	end
	table.sort(list)
	return list
end

-- Puts a player where their role belongs (lobby, middle, or their spot in the line-up).
local lineSpots = {}
local function place(id)
	local p = byId[id]
	local c = p and p.Character
	if not (c and c.PrimaryPart) then
		return
	end
	local role = match and match.roles[id]
	local middle = if zones.Middle then zones.Middle.Position elseif zones.Lobby then zones.Lobby.Position else Vector3.zero
	if not role then
		local zone = (match and zones.Bench) or zones.Lobby
		if zone then
			c:PivotTo(MapService.spot(zone, middle))
		end
	elseif role == "Catcher" then
		c:PivotTo(MapService.spot(zones.Middle, zones[MapService.startFor(match.round)].Position, Config.Map.MiddleSpawn))
	elseif lineSpots[id] and match.status[id] == "Active" then
		c:PivotTo(lineSpots[id])
	end
end

-- Her big showpiece over the map is there while nobody has her.
local function showcaseVisible(on)
	if showcase then
		showcase.Parent = if on then Workspace else nil
	end
end

-- How she reacts to her new carrier.
local MOODS = { Hero = "Excited", Stolen = "Struggle", Reassigned = "Struggle" }

local function moveGirlTo(fromId, toId, reason)
	local from = (fromId and CarryService.position(byId[fromId])) or (showcase and showcase:GetPivot().Position) or nil
	if fromId and byId[fromId] then
		CarryService.remove(byId[fromId])
	end
	local to = toId and byId[toId]
	if to and match and match.roles[toId] == "Catcher" then
		CarryService.follow(to, girl, from) -- a catcher who stabbed her carrier: she follows him on foot
	elseif to then
		CarryService.give(to, girl, from, MOODS[reason] or "Excited")
	end
	showcaseVisible(toId == nil)
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
	for _, id in { e.from, e.to } do
		syncPlayer(id)
	end
	local to, g = nameOf(e.to), girl.name
	local messages = {
		Hero = { `{to} won {g} over! Keep her safe!`, GOLD },
		Stolen = { `{to} stole {g}!`, RED },
		Reassigned = { `{to} has {g} now`, RED },
		Dropped = { `{g} floats back up!`, GOLD },
	}
	local m = messages[e.reason]
	if m then
		task.delay(if e.reason == "Hero" then 1.4 else 0, announce, m[1], m[2], e.reason == "Hero")
	end
end

function handlers.Picked(e)
	State:SetAttribute("PickId", e.id)
end

function handlers.Choice(e)
	State:SetAttribute("PickChoice", if e.hero then "Hero" else "Chicken")
	syncAll()
	if e.hero then
		announce(`{nameOf(e.id)} goes HERO!`, GOLD, true)
	else
		announce(`{nameOf(e.id)} chose CHICKEN. Everyone runs!`, WHITE, true)
	end
end

function handlers.HeroResult(e)
	State:SetAttribute("HeroResult", if e.survived then "Survived" else "Fell")
	if e.survived then
		announce(`{nameOf(e.id)} made the Hero run!`, GREEN, true)
		addStat(e.id, "Heroes", 1) -- (lore quest: Brave Heart)
		local p = byId[e.id]
		if p and Config.HeroBonus > 0 then
			DataService.update(p, function(d)
				d.Coins = (d.Coins or 0) + Config.HeroBonus
			end)
			RoundNet:FireClient(p, "Bonus", { coins = Config.HeroBonus })
			tally[e.id] = tally[e.id] or {}
			tally[e.id].BonusCoins = (tally[e.id].BonusCoins or 0) + Config.HeroBonus -- (shown on the results screen)
		end
	end
end

local fellAt = {} -- downed id -> where their body lies (so a reset lays the new body down there again)
function handlers.Caught(e)
	-- Falls flat where they were caught; another runner can help them up.
	local p = byId[e.id]
	local root = rootOf(e.id)
	if root then
		fellAt[e.id] = root.CFrame
	end
	if p then
		KnockdownService.down(p)
	end
	rescueTime[e.id] = nil
	syncPlayer(e.id)
	RoundNet:FireAllClients("Caught", { catcher = e.by, runner = e.id, final = e.final, bot = botTagging or nil })
	if e.final then
		announce(`{nameOf(e.id)} is out: no second chance`, RED)
	elseif e.by then
		announce(`{nameOf(e.by)} got {nameOf(e.id)}`, RED)
	elseif botTagging then
		announce(`{Config.Bot.Name} got {nameOf(e.id)}`, RED)
	else
		announce(`{nameOf(e.id)} is down`, RED)
	end
	if e.by then addStat(e.by, "Catches", 1) end -- (lore quest: The Hunter)
end

function handlers.Rescued(e)
	rescueTime[e.id] = nil
	protectedUntil[e.id] = os.clock() + Config.Rescue.Shield
	if byId[e.id] then
		byId[e.id]:SetAttribute("ProtectedUntil", Workspace:GetServerTimeNow() + Config.Rescue.Shield)
	end
	if byId[e.id] then
		KnockdownService.up(byId[e.id])
	end
	syncPlayer(e.id)
	RoundNet:FireAllClients("Rescued", { runner = e.id, by = e.by })
	announce(`{nameOf(e.by)} saved {nameOf(e.id)}`, GREEN)
	addStat(e.by, "Rescues", 1)
end

local firstMatch, firstRoundNo -- the match table and round of the last FIRST across, so each round has one
function handlers.Safe(e)
	syncPlayer(e.id)
	addStat(e.id, "Crossings", 1) -- (lore quest: cross safely)
	local first = false
	if State:GetAttribute("Stage") == "Running" then
		announce(`{nameOf(e.id)} is safe`, GREEN)
		if match and not (firstMatch == match and firstRoundNo == match.round) then
			firstMatch, firstRoundNo, first = match, match.round, true
		end
	end
	if byId[e.id] then
		RoundNet:FireClient(byId[e.id], "Safe", {})
	end
	if first then -- first across this round, after SAFE! (Huss Valley flies their name in with FIRST)
		RoundNet:FireAllClients("First", { id = e.id, name = nameOf(e.id) })
	end
end

function handlers.Streak(e)
	State:SetAttribute("Streak", e.count)
	if e.count < e.goal then
		announce(`Clean round! {e.count} of {e.goal} in a row`, GOLD, true)
	end
end

function handlers.StreakLost()
	State:SetAttribute("Streak", 0)
end

function handlers.JoinCatchers(e)
	local names = {}
	for _, id in e.ids do
		table.insert(names, nameOf(id))
	end
	local who = if #names <= 3 then table.concat(names, ", ") else `{#names} runners`
	announce(`{who} {if #names == 1 then "joins" else "join"} the catchers`, RED, true)
end

function handlers.NewCatcher(e)
	syncPlayer(e.id)
	announce(`{nameOf(e.id)} is a catcher now`, RED)
end

local function apply(events)
	for _, e in events do
		local handler = handlers[e.type]
		if handler then
			handler(e)
		end
	end
end

-- One frame of play: who's across, who's being rescued (catchers stab through the Stab remote).
local function step(dt)
	local goal = zones[goalName]
	for id, status in match.status do
		if status == "Active" and not frozen[id] then
			local root = rootOf(id)
			if root and MapService.inZone(goal, root.Position) then
				apply(Rules.reachSafe(match, id))
				if match.over then
					return
				end
			end
		end
	end
	if Config.TagMode ~= "Stab" then
		local start = zones[MapService.startFor(match.round)]
		for catcherId, role in match.roles do
			local catcher = role == "Catcher" and not frozen[catcherId] and PowerService.canStab(catcherId) and rootOf(catcherId)
			if catcher then
				for runnerId, status in match.status do
					local runner = status == "Active" and not frozen[runnerId] and (protectedUntil[runnerId] or 0) <= os.clock() and rootOf(runnerId)
					if runner and (runner.Position - catcher.Position).Magnitude <= Config.TagRange
						and not (Config.StartZoneSafe and MapService.inZone(start, runner.Position)) then
						if not PowerService.blocks(catcherId, runnerId) then
							apply(Rules.tag(match, catcherId, runnerId))
						end
					end
				end
			end
		end
	end
	-- Rescues: an Active runner next to a downed one fills their bar; walking away lets it drain. Someone who has
	-- used their second chance can't be helped up again.
	for downedId, status in match.status do
		if status == "Downed" and not match.rescued[downedId] then
			local p = byId[downedId]
			local c = p and p.Character
			local feet = c and c:GetAttribute("DownedFeet")
			local body = c and c:FindFirstChild("HumanoidRootPart")
			local at = if typeof(feet) == "CFrame" then feet.Position elseif body then body.Position else nil
			local helper = nil
			if at then
				local start = zones[MapService.startFor(match.round)]
				for id, st in match.status do
					local root = st == "Active" and not frozen[id] and rootOf(id)
					-- (from inside the start zone they couldn't be stabbed: no risk-free rescues)
					if root and (root.Position - at).Magnitude <= Config.Rescue.Range and not (start and MapService.inZone(start, root.Position)) then
						helper = id
						break
					end
				end
			end
			local before = rescueTime[downedId]
			if helper then
				rescueTime[downedId] = (before or 0) + dt
				if rescueTime[downedId] >= Config.Rescue.Time then
					apply(Rules.rescue(match, helper, downedId))
				else
					syncPlayer(downedId)
				end
			elseif before then
				rescueTime[downedId] = if before > dt * 2 then before - dt * 2 else nil
				syncPlayer(downedId)
			end
		end
	end
end

-- Safe runners stay across (owner's call): the goal's gate stops them, and anyone who got round it (a dash, a
-- push) goes back in. Every frame of the round, not only while running (a Hero safe after the solo run waits
-- through the countdown too).
local function keepSafe()
	local goal = goalName and zones[goalName]
	if not goal then
		return
	end
	for id, status in match.status do
		local root = status == "Safe" and rootOf(id)
		if root then
			local back = MapService.keepIn(goal, root.Position)
			if back and (back - root.Position).Magnitude > 2 then
				root.Parent:PivotTo(CFrame.new(back) * root.CFrame.Rotation)
			end
		end
	end
end

-- Runners waiting on the line stay on their spot (anyone pushed or sneaking off goes back).
local function keepOnLine()
	for id in frozen do
		local root = match.status[id] == "Active" and lineSpots[id] and rootOf(id)
		if root and (root.Position - lineSpots[id].Position).Magnitude > 3 then
			root.Parent:PivotTo(lineSpots[id])
		end
	end
end

-- Waits `seconds` (or until done() says so). live = play is on: powers, crossings, rescues.
-- Returns true when the time ran out.
local function play(seconds, done, live)
	local deadline = os.clock() + seconds
	while os.clock() < deadline and not (done and done()) and not match.over do
		local dt = RunService.Heartbeat:Wait()
		keepOnLine()
		keepSafe()
		if live then
			if match.holder then
				holdSeconds += dt
			end
			PowerService.step()
			step(dt)
			if not match.over and botStep then botStep() end
		end
	end
	return os.clock() >= deadline
end

local function runRound()
	local events = Rules.startRound(match)
	if match.over then
		apply(events)
		return
	end
	goalName = MapService.goalFor(match.round)
	local startName = MapService.startFor(match.round)
	State:SetAttribute("Round", match.round)
	State:SetAttribute("Goal", goalName)
	State:SetAttribute("Streak", match.streak)
	State:SetAttribute("PickId", 0)
	State:SetAttribute("PickChoice", "")
	State:SetAttribute("HeroResult", "")
	table.clear(rescueTime)

	-- Lineup: runners shoulder to shoulder on their line, facing across; catchers in the middle.
	KnockdownService.upAll()
	MapService.showGoal(goalName)
	MapService.holdGoal(goalName, true)
	MapService.holdStart(startName, true)
	local runners = runnersWith("Active")
	local line, length, spots = MapService.lineup(startName, #runners)
	table.clear(lineSpots)
	for i, id in runners do
		lineSpots[id] = spots[i]
	end
	State:SetAttribute("LineCF", line)
	State:SetAttribute("LineLength", length)
	table.clear(frozen)
	for id in match.roles do
		frozen[id] = true -- catchers wait too, until the Hero runs
		place(id)
	end
	-- Nobody catching (alone, or the only catcher left): the Practice Bot catches this round.
	local anyCatcher = false
	for _, role in match.roles do
		if role == "Catcher" then anyCatcher = true end
	end
	if Config.Bot.Enabled and not anyCatcher and #runners > 0 and zones.Middle then
		if PracticeBot.spawn(MapService.spot(zones.Middle, zones[startName].Position, Config.Map.MiddleSpawn)) then
			botPlayed = true
		end
	else
		PracticeBot.remove()
	end
	PracticeBot.setFrozen(true)
	PowerService.newRound()
	syncAll()
	apply(events)
	setStage("Lineup", Config.LineupTime)
	if match.round == 1 then
		announce(`Get everyone across {match.goal} rounds in a row`, WHITE)
	else
		announce(`Line up. {match.streak} of {match.goal} in a row so far`, WHITE)
	end
	play(Config.LineupTime)

	-- Picking: one random runner chooses HERO or CHICKEN (no answer in time = a random pick).
	if Config.Pick.Enabled then
		apply(Rules.pickRunner(match))
	end
	if match.picked then
		local P = Config.Pick
		State:SetAttribute("PickAt", Workspace:GetServerTimeNow())
		setStage("Picking", P.Roulette + P.ChooseTime)
		announce("Picking a runner...", GOLD)
		task.delay(P.Roulette, function()
			if match and match.picked and not match.choice then
				announce(`{nameOf(match.picked)}: HERO or CHICKEN?`, WHITE)
			end
		end)
		play(P.Roulette + P.ChooseTime, function()
			return match.choice ~= nil or match.picked == nil
		end)
		if match.picked and not match.choice then
			apply(Rules.choose(match, match.picked, nil))
		end
		if match.choice then
			setStage("Chosen", P.ShowTime)
			play(P.ShowTime)
		end
	end

	-- The Hero's solo crossing: everyone else waits on the line and watches.
	if match.hero then
		local hero = match.hero
		frozen[hero] = nil
		for id, role in match.roles do
			if role == "Catcher" then
				frozen[id] = nil
			end
		end
		PracticeBot.setFrozen(false)
		MapService.holdStart(startName, false)
		syncAll()
		setStage("HeroRun", Config.HeroTime)
		announce(`{nameOf(hero)}'s solo run!`, GOLD)
		local timedOut = play(Config.HeroTime, function()
			return match.status[hero] ~= "Active" or match.hero ~= hero
		end, true)
		if timedOut and match.hero == hero then
			Rules.heroTimeout(match)
			announce(`{nameOf(hero)} ran out of time`, WHITE)
		end
		if match.over then
			return
		end
		-- catchers back to the middle for a fair start
		for id, role in match.roles do
			if role == "Catcher" then
				frozen[id] = true
				place(id)
			end
		end
		PracticeBot.setFrozen(true)
		if zones.Middle then
			PracticeBot.place(MapService.spot(zones.Middle, zones[startName].Position, Config.Map.MiddleSpawn))
		end
		if match.status[hero] == "Active" then
			frozen[hero] = true
			place(hero) -- (timed out: back to the line)
		end
		MapService.holdStart(startName, true)
		PowerService.clear() -- (traps laid during the Hero run don't stay for everyone's run)
		syncAll()
		play(0.8)
	end

	-- Nobody left to run (the only runner was the Hero): straight to the round's end.
	if Rules.isRoundOver(match) then
		saveHold()
		PowerService.clear()
		apply(Rules.endRound(match, false))
		syncAll()
		if not match.over then
			setStage("RoundOver", Config.RoundEndPause)
			task.wait(Config.RoundEndPause)
		end
		return
	end

	-- 3, 2, 1, GO! Everyone runs.
	setStage("Countdown", Config.CountdownTime)
	play(Config.CountdownTime)
	MapService.holdStart(startName, false)
	table.clear(frozen)
	PracticeBot.setFrozen(false)
	syncAll()
	setStage("Running", Config.RoundTime)
	announce("GO! Get across!", WHITE)
	play(Config.RoundTime, function()
		return Rules.isRoundOver(match)
	end, true)
	PracticeBot.setFrozen(true)
	saveHold()
	PowerService.clear() -- traps and effects end with the round
	apply(Rules.endRound(match, not Rules.isRoundOver(match)))
	table.clear(rescueTime)
	syncAll()
	if not match.over then
		setStage("RoundOver", Config.RoundEndPause)
		task.wait(Config.RoundEndPause)
	end
end

local function finishGame()
	PracticeBot.remove()
	-- The Practice Bot downed everyone: it wins, so no player does (no girl, no winner's pay).
	local botWon = botPlayed and match.team == "Catchers"
	local winnerId = if botWon then nil else match.winner
	local winner = winnerId and byId[winnerId]
	for id, role in match.roles do
		addStat(id, "Rounds", 1) -- "Complete 3 matches"
		local won = not botWon and ((match.team == "Runners" and role == "Runner") or (match.team == "Catchers" and role == "Catcher"))
		if won then
			addStat(id, "Wins", 1)
		end
		-- pay for the game: coins for playing, more and a little Aura for winning
		local p = byId[id]
		local pay = Config.Pay
		if p and pay then
			local coins, aura = pay.Played + (if won then pay.Won else 0), if won then pay.WonAura else 0
			coins *= require(script.Parent.SpinService).boost(p, "Coins") -- Spin the Wheel's "x2 Coins" while it lasts
			DataService.update(p, function(d)
				d.Coins = (d.Coins or 0) + coins
				d.Aura = (d.Aura or 0) + aura
			end)
			RoundNet:FireClient(p, "Bonus", { coins = coins, aura = aura, late = true })
			-- the results screen (Screens/Results): how your game went
			local t = tally[id] or {}
			RoundNet:FireClient(p, "Results", {
				outcome = if botWon then "Bot" elseif won then "Win" else "Lose",
				girl = girl.name, rarity = girl.rarity, gotGirl = winnerId == id,
				crossed = t.Crossings or 0, catches = t.Catches or 0, rescues = t.Rescues or 0, heroes = t.Heroes or 0,
				-- everything this game paid: the game's pay, a Hero bonus, and Aura from stars on the field
				coins = coins + (t.BonusCoins or 0), aura = aura + (p:GetAttribute("HuzzGameAura") or 0),
			})
		end
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
	end
	RoundNet:FireAllClients("Win", {
		team = match.team, winner = winnerId, name = if botWon then nil else winner and winner.DisplayName, -- ("Nobody wins her")
		girl = girl.name, rarity = girl.rarity, bot = botWon or nil,
	})
	State:SetAttribute("HolderId", winnerId or 0)
	State:SetAttribute("Winners", match.team or "")
	table.clear(frozen)
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
	MapService.setBounds(true) -- (the field's invisible walls: only during a game)
	table.clear(tally)
	for _, p in Players:GetPlayers() do
		p:SetAttribute("HuzzGameAura", 0) -- (AuraPickupService adds the stars collected this game)
	end
	showShowcase()
	local ids = {}
	for id in byId do
		table.insert(ids, id)
	end
	local catcher = if #ids >= 2 then ids[math.random(#ids)] else nil
	match = Rules.newGame(ids, catcher, { maxRounds = Config.MaxRounds, crossings = Config.Crossings })
	State:SetAttribute("GirlName", girl.name)
	State:SetAttribute("GirlRarity", girl.rarity)
	State:SetAttribute("HolderId", 0)
	State:SetAttribute("Crossings", Config.Crossings)
	State:SetAttribute("Winners", "")
	announce(`{girl.name} is up for grabs!`, GirlService.rarity(girl.rarity).Color, true)
	if catcher then
		task.delay(1.5, announce, `{nameOf(catcher)} is the CATCHER!`, RED, true)
	elseif Config.Bot.Enabled then
		task.delay(1.5, announce, `{Config.Bot.Name} is the CATCHER!`, RED, true)
	end
	while not match.over do
		runRound()
	end
	finishGame()
end

local function cleanUp()
	MapService.setBounds(false)
	PracticeBot.remove()
	botPlayed = false
	KnockdownService.upAll()
	CarryService.removeAll()
	if showcase then
		showcase:Destroy()
		showcase = nil
	end
	MapService.holdStart(nil, false)
	MapService.holdGoal(nil, false)
	PowerService.clear()
	MapService.showGoal(nil) -- the lines stay on the map, the SAFE ZONE sign goes out
	match, girl = nil, nil
	table.clear(frozen)
	table.clear(rescueTime)
	table.clear(protectedUntil)
	table.clear(lineSpots)
	table.clear(fellAt)
	State:SetAttribute("GirlName", "")
	State:SetAttribute("HolderId", 0)
	State:SetAttribute("Round", 0)
	State:SetAttribute("PickId", 0)
	State:SetAttribute("Streak", 0)
	for id in byId do
		place(id) -- everyone back to the lobby
	end
	syncAll()
	-- The map stays in front of the lobby until the next vote picks its replacement.
end

-- Catchers stab (click / tap STAB). The client plays the move at once and tells us; we check the
-- catcher may stab now and tag the nearest runner in reach in front of them.
local lastStab = {}
-- Stab the nearest runner within range of the catcher (front only for the knife: runners lag on screen, so a
-- little behind still counts). Shields, the safe start zone and a fresh rescue protect. True when someone was hit.
local function stabNear(id, me: BasePart, range: number, front: boolean): boolean
	local now = os.clock()
	local start = zones[MapService.startFor(match.round)]
	local look = me.CFrame.LookVector
	local best, bestDistance = nil, range
	for runnerId, status in match.status do
		local root = status == "Active" and not frozen[runnerId] and (protectedUntil[runnerId] or 0) <= now and rootOf(runnerId)
		if root then
			local offset = root.Position - me.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local inFront = not front or flat.Magnitude < 3.5 or look:Dot(flat.Unit) > -0.2
			local safe = Config.StartZoneSafe and start and MapService.inZone(start, root.Position)
			if offset.Magnitude <= bestDistance and math.abs(offset.Y) < 8 and inFront and not safe then
				best, bestDistance = runnerId, offset.Magnitude
			end
		end
	end
	if best then
		if PowerService.blocks(id, best) then
			return true -- (a Heart Shield took it: that ends the stab or the lunge)
		end
		apply(Rules.tag(match, id, best))
		return true
	end
	return false
end

-- The Practice Bot's frame: it chases the runners a catcher could stab right now and stabs within its reach.
function botStep()
	if not PracticeBot.active() then
		return
	end
	local start = zones[MapService.startFor(match.round)]
	local now = os.clock()
	local targets = {}
	for id, status in match.status do
		local root = status == "Active" and not frozen[id] and (protectedUntil[id] or 0) <= now and rootOf(id)
		if root and not (Config.StartZoneSafe and start and MapService.inZone(start, root.Position)) then
			table.insert(targets, root)
		end
	end
	local m = zones.Middle
	local fallY = if m then m.Position.Y - m.Size.Y / 2 - 30 else nil
	PracticeBot.step(targets, function(me)
		botTagging = true
		local ok, hit = pcall(stabNear, nil, me, Config.Bot.Reach, false)
		botTagging = false
		return ok and hit
	end, fallY)
end

Net.get("Stab").OnServerEvent:Connect(function(player)
	local id = player.UserId
	local stage = State:GetAttribute("Stage")
	if not (match and not match.over and match.roles[id] == "Catcher" and (stage == "Running" or stage == "HeroRun") and not frozen[id]) then
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
	stabNear(id, me, Config.Stab.Range, true)
end)

-- The catcher's lunge (Config.Lunge): the client leaps at once (Gameplay/Dash) and tells us; we check it's allowed,
-- set the Space cooldown, show the stab to everyone, and for HitWindow seconds stab the first runner within
-- HitRange of the catcher (shields and the safe start zone still count).
local lastLunge = {}
Net.get("Lunge").OnServerEvent:Connect(function(player)
	local id = player.UserId
	local c = player.Character
	local stage = State:GetAttribute("Stage")
	if not (c and match and not match.over and match.roles[id] == "Catcher" and (stage == "Running" or stage == "HeroRun") and not frozen[id]) then
		return
	end
	if KnockdownService.isDown(player) or not PowerService.canStab(id) or PowerService.stuck(id) then
		return
	end
	local now = Workspace:GetServerTimeNow()
	if now < (player:GetAttribute("DashReady") or 0) - 0.05 or (lastLunge[id] and os.clock() - lastLunge[id] < Config.Lunge.Cooldown * 0.8) then
		return -- still cooling down
	end
	lastLunge[id] = os.clock()
	player:SetAttribute("DashReady", now + Config.Lunge.Cooldown)
	c:SetAttribute("LungeAt", now) -- (every screen plays the leap)
	RoundNet:FireAllClients("Stab", { id = id, lunge = true }) -- (the stab move, on the catcher's own screen too)
	if Config.TagMode ~= "Stab" then
		return -- (touch mode: the leap is just a leap; touching tags as always)
	end
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < Config.Lunge.HitWindow do
			local me = rootOf(id)
			local st = State:GetAttribute("Stage")
			if not (me and match and not match.over and match.roles[id] == "Catcher" and (st == "Running" or st == "HeroRun"))
				or frozen[id] or KnockdownService.isDown(player) or not PowerService.canStab(id) then
				return
			end
			if stabNear(id, me, Config.Lunge.HitRange, false) then
				return -- (one runner per lunge)
			end
			task.wait(0.03)
		end
	end)
end)

-- Round powers (Config/Powers, HuzzServer/PowerService).
PowerService.start({
	match = function()
		return match
	end,
	running = function()
		local stage = State:GetAttribute("Stage")
		return stage == "Running" or stage == "HeroRun"
	end,
	rootOf = rootOf,
	playerOf = function(id)
		return byId[id]
	end,
	isDown = KnockdownService.isDown,
	frozen = function(id)
		return frozen[id] == true
	end,
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

-- Hero or Chicken: only the picked runner, while the pick is open (Shared/RoundRules.choose).
Net.get("Hero").OnServerEvent:Connect(function(player, isHero)
	local id = player.UserId
	if match and not match.over and match.picked == id and State:GetAttribute("Stage") == "Picking" and type(isHero) == "boolean" then
		apply(Rules.choose(match, id, isHero))
	end
end)

-- The huss (owner's call, like Huss Valley): a dash to the left or right of the way you face, never forward or
-- back. The client moves its own character at once (Gameplay/Dash) and tells us; we check it's allowed, turn the
-- direction into pure left or right of the character's facing (anything that isn't clearly sideways is refused),
-- and set DashAt/DashDir on the character so every client plays the move, and DashReady (server time) for the
-- cooldown tile.
Net.get("Dash").OnServerEvent:Connect(function(player, dir, at, look)
	local id = player.UserId
	local c = player.Character
	local stage = State:GetAttribute("Stage")
	-- in a game: only while running; in the lobby (not in the game) any time (owner: no jumping in the lobby,
	-- keep the huss)
	local playing = match ~= nil and not match.over and match.roles[id] ~= nil
	if not c or (playing and not (stage == "Running" or stage == "HeroRun")) then
		return
	end
	if KnockdownService.isDown(player) or PowerService.stuck(id) or frozen[id] or (playing and match.status[id] == "Downed") then
		return
	end
	if typeof(dir) ~= "Vector3" or dir ~= dir then
		return
	end
	local flat = Vector3.new(dir.X, 0, dir.Z)
	local root = c:FindFirstChild("HumanoidRootPart")
	if flat.Magnitude < 0.1 or not root then
		return
	end
	-- sideways only: project onto the character's right; mostly forward/back (or a stale facing) is refused. The
	-- client turns to face its camera just before a huss and sends that facing, which we haven't seen yet: we take it
	-- when it's within 110 degrees of the facing we have (a real turn, not a made-up direction).
	local facing = root.CFrame.LookVector
	if typeof(look) == "Vector3" and look == look then
		local flatLook, flatFacing = Vector3.new(look.X, 0, look.Z), Vector3.new(facing.X, 0, facing.Z)
		if flatLook.Magnitude > 0.1 and flatFacing.Magnitude > 0.1 and flatLook.Unit:Dot(flatFacing.Unit) > math.cos(math.rad(110)) then
			facing = flatLook.Unit
		end
	end
	local right = Vector3.new(-facing.Z, 0, facing.X) -- (the right of a flat facing)
	if right.Magnitude < 0.1 then
		return
	end
	right = right.Unit
	local across = flat.Unit:Dot(right)
	if math.abs(across) < 0.5 then
		return
	end
	flat = right * (if across > 0 then 1 else -1)
	local now = Workspace:GetServerTimeNow()
	if now < (player:GetAttribute("DashReady") or 0) - 0.05 then -- (a little slack for clock drift)
		return -- still cooling down
	end
	local start = if type(at) == "number" and at == at then math.clamp(at, now - 0.15, now) else now
	player:SetAttribute("DashReady", start + Config.Dash.Cooldown)
	c:SetAttribute("DashDir", flat.Unit)
	c:SetAttribute("DashAt", start)
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
		place(id) -- the lobby, the middle or their spot on the line
		if match and match.status[id] == "Downed" and fellAt[id] then
			character:PivotTo(fellAt[id]) -- reset while down: lie down again where they fell
			KnockdownService.down(player)
		end
		if match and match.roles[id] then
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
	player.DevEnableMouseLock = false -- our own shift lock (Gameplay/ShiftLock, Alt) replaces Roblox's Shift one
	task.spawn(function()
		DataService.waitFor(player, 20)
		syncPlayer(player.UserId) -- the name tag's level and wins once the save has loaded
	end)
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
	frozen[player.UserId] = nil
	rescueTime[player.UserId] = nil
	protectedUntil[player.UserId] = nil
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
-- (with the Practice Bot one player is enough, live too: the owner picked bots so a round works alone)
local minPlayers = if RunService:IsStudio() then Config.StudioMinPlayers elseif Config.Bot.Enabled then 1 else Config.MinPlayers

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
		-- The winning map replaces the one in front of the lobby and everyone moves to the lobby beside it
		-- (owner: "one per map"; after the load, so they face the new map), then the girl roller spins.
		local moved = MapService.useLobbyFor(map)
		MapService.load(map)
		if moved then
			local target = MapService.lobbySpawn()
			for id, p in byId do
				-- (the far island may not have streamed in on a phone yet: load it around them first)
				task.spawn(function()
					if target then pcall(function() p:RequestStreamAroundAsync(target, 2) end) end
					place(id)
				end)
			end
		end
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
