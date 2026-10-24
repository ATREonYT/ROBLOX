--[[
	The core loop, Huss Valley one to one (owner's call) with the anime girl built in:
	  vote -> girl roller -> rounds -> one side wins and the girl goes home with them.
	Each round: Lineup (runners in a row on their line) -> Picking (a random runner chooses HERO or
	CHICKEN; clients play the camera sweep, Gameplay/Cinematic) -> Chosen -> HeroRun (a Hero crosses
	alone) -> Countdown -> Running (everyone; stabbed runners go down, others can rescue them) ->
	RoundOver. RoundRules decides everything; this script moves players, watches the zones, stabs and
	rescues, and turns rule events into carries, messages, name tags and saves.
]]
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Round)
local CoinShop = require(ReplicatedStorage.Shared.Config.CoinShop)
local KnifeLook = require(Shared.KnifeLook)
local Carry = require(Shared.Config.Carry)
local Rules = require(Shared.RoundRules)
local CombineRules = require(Shared.CombineRules)
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
local SecretReveal = require(ReplicatedStorage.Shared.SecretReveal)
local PracticeBot = require(script.Parent.PracticeBot)
local HitHistory = require(script.Parent.HitHistory)
local PlaceService = require(script.Parent.PlaceService) -- (a player's own screen moves their body: the owner moves it)
local Skip = require(script.Parent.SkipService) -- (SKIP (skip game): who sits the next game out)
local MoveGuard = require(script.Parent.MoveGuard) -- (release check, Oct 22: no safe by a jump, no hits after one)
local TouchHit = require(Shared.TouchHit)
local MotionStamps = require(Shared.MotionStamps)
local MotionRelay = require(script.Parent.MotionRelay) -- (the runner's own stamps: screenHit's path reaches the claim)
local ProgressService = require(script.Parent.ProgressService)

require(script.Parent.SafetyService).clean()
MapService.init()
GirlService.init()
task.spawn(function() -- the AFK zone in the lobby (Config/Afk): never holds up the round loop
	local ok, err = pcall(function() require(script.Parent.AfkService).start() end)
	if not ok then warn("[HuzzAfk] " .. tostring(err)) end
end)

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
local botPlayed = false -- the Practice Bot catches this round (then it, not a player, wins if every runner is down)
local botPlayers = nil -- who played its last game ("1,5,9"): someone new = it starts again at Config.Bot.Speed
local botNews = nil -- "slower" / "faster": said when its next game starts
local botChecked = nil -- the match whose players it last checked
local botTagging = false -- true while the Practice Bot's stab is being applied (so the message names it)
local botStabShownAt = -math.huge -- (os.clock) when clients were last told to play the bot's stab
local botStep -- (set once stabNear exists, further down)
local tally = {} -- id -> { Crossings = n, Catches = n, ... } this game only (the results screen at the end)
local lastRunner = nil -- the only runner still out on the field while running (Speeds.LastRunner: a catch-up)

-- Quest counters (Config/Progression) and the Index, saved through DataService.
local function addStat(id, stat, amount)
	if id then
		tally[id] = tally[id] or {}
		tally[id][stat] = (tally[id][stat] or 0) + amount
	end
	local p = byId[id]
	if p then
		ProgressService.addStat(p, stat, amount) -- (saved quest counters, and the daily quests count them too)
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

-- The message line at the top of everyone's screen (as in Huss Valley), in the news colour: green good news, red
-- caught / out, white news (RoundHud colours the words while Theme.MessageColour is on). News never takes the
-- middle of the screen: centre words are only the big moments RoundHud draws itself (3-2-1, SAFE!, YOU'RE OUT, wins).
local function announce(text, color)
	RoundNet:FireAllClients("Announce", { text = text, color = color })
end

-- Everyone in the game runs a tiny bit faster each round (Config.SpeedUp, Rules.speedScale; the lobby never changes).
local function roundScale(): number
	return Rules.speedScale(match and match.round, Config.SpeedUp)
end

-- The fastest catcher this round: the Practice Bot's own speed when it's the catcher.
local function catcherTop()
	return (if botPlayed and PracticeBot.active() then PracticeBot.speed() else Config.Speeds.Catcher) * roundScale()
end

local function speedFor(id)
	local role = match and match.roles[id]
	if not role then
		return Config.Speeds.Lobby or StarterPlayer.CharacterWalkSpeed
	end
	local scale = roundScale() -- (a tiny bit faster every round, runners and catchers alike)
	if lastRunner == id and Config.Speeds.LastRunner then
		-- the catch-up: up to the real catcher's speed, never past it (and never slower than a runner)
		return math.max(Config.Speeds.Runner * scale, math.min(Config.Speeds.LastRunner * scale, catcherTop()))
	elseif match.holder == id then
		return (if role == "Catcher" then Config.Speeds.Thief else Config.Speeds.Holder) * scale
	end
	return Config.Speeds[role] * scale
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
			-- second chance used: OUT, so nobody runs over to help (loop audit: HELP! sent them to a lost cause)
			return if match.rescued[id] then "Out" else "Downed"
		elseif status == "Safe" then
			return "Safe"
		elseif match.hero == id then
			return "Hero"
		end
		return "Runner"
	end
	return nil
end

-- Only the name tag (role title, HERO/CHICKEN badge, rescue bar). The rescue loop calls this every frame instead of
-- the whole syncPlayer, which walks every body part and refits the worn knife (bug hunt, Oct 20).
-- onlyIfMoved (the rescue loop, every frame): skips it unless the look, the badge or the bar moved a step (1/40), so
-- the tag isn't rewritten and sent to everyone 60 times a second (owner, Oct 23: "its very laggy").
local tagSent = {} -- id -> what the tag last showed
local function syncTag(id, onlyIfMoved: boolean?)
	local p = byId[id]
	if not p then
		return
	end
	local badge = nil
	if match and match.picked == id and match.choice then
		badge = string.upper(match.choice)
	end
	local rescue = rescueTime[id] and rescueTime[id] / Config.Rescue.Time
	local look = tagLook(id)
	local key = string.format("%s|%s|%d", tostring(look), tostring(badge), math.floor((rescue or 0) * 40))
	if onlyIfMoved and tagSent[id] == key then return end
	tagSent[id] = key
	NameTags.set(p, look, badge, rescue)
end

local function syncPlayer(id)
	local p = byId[id]
	if not p then
		return
	end
	p:SetAttribute("HuzzRole", match and match.roles[id] or "Lobby")
	p:SetAttribute("HuzzStatus", match and match.status[id] or "")
	p:SetAttribute("HuzzHero", match ~= nil and match.hero == id) -- this round's Hero (yellow outline)
	-- down with the second chance used: nobody can help them up (RoundHud says OUT)
	p:SetAttribute("HuzzOut", match ~= nil and match.status[id] == "Downed" and match.rescued[id] == true)
	p:SetAttribute("HuzzFrozen", frozen[id] == true) -- on the line, waiting (no dash, no powers)
	-- Safe runners stay across (owner's call): their parts bump into the goal's gate (MapService.holdGoal).
	MapService.setSafe(p.Character, match ~= nil and not match.over and match.status[id] == "Safe")
	-- catchers bump into both safe zones' walls (owner: "make catcher not be able to go into the safe zone")
	MapService.setCatcher(p.Character, match ~= nil and not match.over and match.roles[id] == "Catcher")
	local h = humanoidOf(id)
	if h then
		local still = KnockdownService.isDown(p) or PowerService.stuck(id) or frozen[id] == true
		h.WalkSpeed = if still then 0 else PowerService.speedOf(id, speedFor(id))
		if lastRunner == id and not still then
			h.WalkSpeed = math.min(h.WalkSpeed, catcherTop() + 4) -- (a Speed Boost on top of the catch-up: capped)
		end
		h:SetAttribute("HuzzSpeed", h.WalkSpeed) -- the top speed: Gameplay/Sprint builds up to it from a walk
		-- No jumping anywhere (owner: "remove the jumping from the lobby"): Space is the huss instead.
		h.JumpHeight = 0
		h.JumpPower = 0
	end
	-- Catchers hold a knife (Config.TagMode "Stab"); everyone else wears theirs (on the back or the hip, per knife: Config/CoinShop Wear).
	-- One knife per body: give/giveBack each remove the other (KnifeService).
	local c = p.Character
	local profile = DataService.get(p)
	local knifeSkin = KnifeLook.pick(profile and profile.Data, CoinShop)
	if c then
		if match and not match.over and match.roles[id] == "Catcher" and Config.TagMode == "Stab" then
			KnifeService.takeBack(c)
			KnifeService.give(c, knifeSkin) -- (in hand, with their knife skin)
		else
			KnifeService.take(c)
			KnifeService.giveBack(c, knifeSkin) -- everyone else wears theirs on their back
		end
	end
	syncTag(id)
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

-- Puts a player where their role belongs (lobby, middle, or their spot in the line-up). Their own screen moves them
-- (HuzzServer/PlaceService; the server only if it doesn't): a server PivotTo on a body the player's client simulates
-- made it jump there, back and there again on the other screens (owner, Oct 20 15:13: "the peoples locations are off").
local lineSpots = {}
local function place(id)
	local p = byId[id]
	local c = p and p.Character
	if not (c and c.PrimaryPart) then
		return
	end
	local role = match and match.roles[id]
	local middle = if zones.Middle then zones.Middle.Position elseif zones.Lobby then zones.Lobby.Position else Vector3.zero
	-- (every spot is open ground: MapService + Shared/SpawnSpots; the lobby's is its spawn pad)
	if not role then
		local zone = (match and not Skip.sitting(id) and zones.Bench) or zones.Lobby
		local at = if zone == zones.Bench then MapService.benchSpot(middle) else MapService.lobbySpot()
		if at or zone then
			PlaceService.place(p, at or MapService.spot(zone, middle), "lobby")
		end
	elseif role == "Catcher" then
		local catchers = Rules.idsWithRole(match, "Catcher")
		table.sort(catchers)
		local startName = MapService.startFor(match.round)
		PlaceService.place(p, MapService.middleSpot(table.find(catchers, id) or 1, startName)
			or MapService.spot(zones.Middle, zones[startName].Position, Config.Map.MiddleSpawn), "middle")
	elseif lineSpots[id] and match.status[id] == "Active" then
		PlaceService.place(p, lineSpots[id], "line")
	end
end

-- Her big showpiece over the map is there while nobody has her.
local function showcaseVisible(on)
	if showcase then
		showcase.Parent = if on then Workspace else nil
	end
end

-- How she reacts to her new carrier.
local MOODS = { Hero = "Excited", First = "Excited", Stolen = "Struggle", Reclaimed = "Excited", Reassigned = "Struggle" }

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
	if e.reason == "Stolen" and e.from and e.to then
		addStat(e.to, "Steals", 1) -- a catcher took her off her carrier (not a hand-back, a last runner or a reassign)
	end
	moveGirlTo(e.from, e.to, e.reason)
	for _, id in { e.from, e.to } do
		syncPlayer(id)
	end
	local to, g = nameOf(e.to), girl.name
	-- Caught carrying her: only promise "next runner across" when someone can still get across (critic, Oct 19:
	-- on the last catch the game ends that frame). Counted when the line goes out, not when she moves: two
	-- catchers can catch the last two runners in the same frame, and the second catch comes after this event
	-- (the sim caught it: "next runner across" on a game the catchers had just won).
	local thisGame = match
	local function stolen()
		if thisGame then
			local active, safe = 0, 0
			for id, role in thisGame.roles do
				if role == "Runner" and thisGame.status[id] == "Active" then active += 1 end
				if role == "Runner" and thisGame.status[id] == "Safe" then safe += 1 end
			end
			if active == 0 and safe == 0 then
				return `{to} caught the last runner!` -- (the catchers win; the Win line names who gets her)
			elseif active == 0 and safe == 1 and (thisGame.startRunners or 0) >= 2 then
				return `{to} caught her carrier!` -- (the last runner standing wins her as the round ends)
			end
		end
		return `{to} caught her carrier! Next runner across takes {g} back!`
	end
	local messages = {
		Hero = { `{to} won {g} over! Keep her safe!`, GOLD },
		First = { `{to} got there first and won {g} over! Keep her safe!`, GOLD },
		Last = { `{to} is the last runner standing and wins {g}!`, GOLD },
		Stolen = { stolen, RED },
		Reclaimed = { `{to} made it across and took {g} back!`, GOLD },
		Reassigned = { `{to} has {g} now`, RED },
		Dropped = { `{g} floats back up!`, GOLD },
	}
	local m = messages[e.reason]
	if m then
		task.delay(if e.reason == "Hero" then 1.4 else 0, function()
			announce(if type(m[1]) == "function" then m[1]() else m[1], m[2], e.reason == "Hero")
		end)
	end
end

function handlers.Picked(e)
	State:SetAttribute("PickId", e.id)
end

function handlers.Choice(e)
	State:SetAttribute("PickChoice", if e.hero then "Hero" else "Chicken")
	syncAll()
	if e.hero then
		announce(`{nameOf(e.id)} goes HERO!`, GOLD)
	else
		announce(`{nameOf(e.id)} chose CHICKEN. Everyone runs!`, WHITE)
	end
end

function handlers.HeroResult(e)
	State:SetAttribute("HeroResult", if e.survived then "Survived" else "Fell")
	if e.survived then
		announce(`{nameOf(e.id)} made the Hero run!`, GREEN)
		addStat(e.id, "Heroes", 1) -- (lore quest: Brave Heart)
		local p = byId[e.id]
		-- (the bonus is for crossing alone while others watch: a solo player is picked every round, so alone
		-- against the Practice Bot it paid ~10x a real game per minute; loop audit, Oct 18)
		local others = 0 -- (anyone else in the game: a catcher or another runner; alone, only the bot is there)
		for id in match.roles do
			if id ~= e.id then others += 1 end
		end
		if p and Config.HeroBonus > 0 and others > 0 then
			DataService.update(p, function(d)
				d.Coins = (d.Coins or 0) + Config.HeroBonus
			end)
			RoundNet:FireClient(p, "Bonus", { coins = Config.HeroBonus })
			tally[e.id] = tally[e.id] or {}
			tally[e.id].BonusCoins = (tally[e.id].BonusCoins or 0) + Config.HeroBonus -- (shown on the results screen)
			tally[e.id].HeroPaid = (tally[e.id].HeroPaid or 0) + 1 -- (the XP for a Hero run counts only these)
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
	fellAt[e.id] = nil -- (up again: a reset later must not send them back to this spot)
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
	if (match.startRunners or 0) < 2 and e.count < e.goal then -- (only a practice game counts clean rounds)
		announce(`Clean round! {e.count} of {e.goal} in a row`, GOLD)
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
	announce(`{who} {if #names == 1 then "joins" else "join"} the catchers`, RED)
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
			-- (a body that jumped into the goal is sent back, not made safe: MoveGuard looks right now)
			if root and MapService.inZone(goal, root.Position) and MoveGuard.fine(byId[id]) then
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
			local slide = c and c:GetAttribute("DownedSlide") -- (the body slid on as it fell: KnockdownService)
			local at = if typeof(feet) == "CFrame" then (feet * CFrame.new(0, 0, -(tonumber(slide) or 0))).Position
				elseif body then body.Position else nil
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
					apply(Rules.rescue(match, helper, downedId)) -- (a full sync: handlers.Rescued)
				else
					syncTag(downedId, true) -- (only the bar moves: nothing else about them changed)
				end
			elseif before then
				rescueTime[downedId] = if before > dt * 2 then before - dt * 2 else nil
				syncTag(downedId, rescueTime[downedId] ~= nil) -- (the bar emptied: always shown)
			end
		end
	end
end

-- Safe runners stay across (owner's call): the goal's gate stops them, and anyone who got round it (a dash, a
-- push) goes back in. Every frame of the round, not only while running (a Hero safe after the solo run waits
-- through the countdown too). Their own screen moves them (PlaceService), once: no new move while one is on its way
-- (the server's copy of a moving body is a moment old, so a move every frame fought the player's own movement).
local function keepSafe()
	-- catchers who got past a zone's wall (a lunge into a corner, lag) go back out onto the field
	for id, role in match.roles do
		local root = role == "Catcher" and rootOf(id)
		if root then
			for _, zone in { zones.ZoneA, zones.ZoneB } do
				local out = MapService.pushOut(zone, root.Position)
				if out and (out - root.Position).Magnitude > 2 and not PlaceService.pending(byId[id]) then
					PlaceService.place(byId[id], CFrame.new(out) * root.CFrame.Rotation, "out of a safe zone")
				end
			end
		end
	end
	local bot = botPlayed and PracticeBot.position()
	if bot then
		for _, zone in { zones.ZoneA, zones.ZoneB } do
			local out = MapService.pushOut(zone, bot)
			if out and (out - bot).Magnitude > 2 then
				PracticeBot.nudge(CFrame.new(out))
			end
		end
	end
	local goal = goalName and zones[goalName]
	if not goal then
		return
	end
	for id, status in match.status do
		local root = status == "Safe" and rootOf(id)
		if root then
			local back = MapService.keepIn(goal, root.Position)
			if back and (back - root.Position).Magnitude > 2 and not PlaceService.pending(byId[id]) then
				PlaceService.place(byId[id], CFrame.new(back) * root.CFrame.Rotation, "back in the safe zone")
			end
		end
	end
end

-- Runners waiting on the line stay on their spot (anyone pushed or sneaking off goes back).
local function keepOnLine()
	for id in frozen do
		local root = match.status[id] == "Active" and lineSpots[id] and rootOf(id)
		if root and (root.Position - lineSpots[id].Position).Magnitude > 3 and not PlaceService.pending(byId[id]) then
			PlaceService.place(byId[id], lineSpots[id], "back on the line")
		end
	end
end

-- Waits `seconds` (or until done() says so). live = play is on: powers, crossings, rescues. onFrame(dt) runs every
-- frame. Returns true when the time ran out. hurry() can bring the end closer (the clock on screen follows).
local playUntil = 0
local function hurry(seconds)
	local at = os.clock() + seconds
	if at < playUntil then
		playUntil = at
		State:SetAttribute("EndsAt", Workspace:GetServerTimeNow() + seconds)
		return true
	end
	return false
end

-- Calls w.onStall once when the runners still to cross (or only w.only) have all stood in the start zone, where
-- nobody can stab them, for w.wait seconds in a row (Config.Hurry; Shared/RoundRules.stalling). It starts counting
-- w.delay seconds in, and calls w.onWarn once at w.warnAt seconds of waiting. It doesn't count while one of them is
-- stuck in a trap or held on the line, and starts again while a catcher (or the bot) is within 10 studs of the
-- zone: waiting for a camper to move is sensible, not a stall. After 10 s of camping in a row it counts anyway (both
-- sides are just waiting; and catchers hover next to an AFK runner, which would stall the round for good).
local function nearZone(zone, position)
	local back = MapService.keepIn(zone, position)
	return back == nil or (Vector3.new(back.X, 0, back.Z) - Vector3.new(position.X, 0, position.Z)).Magnitude <= 10
end
local function stallWatch(w)
	local still, age, campFor, fired, warned = 0, 0, 0, false, false
	return function(dt)
		local start = zones[MapService.startFor(match.round)]
		age += dt
		if fired or not start or age < (w.delay or 0) then
			return
		end
		local inStart = {}
		for id, status in match.status do
			if status == "Active" and (w.only == nil or id == w.only) and (PowerService.stuck(id) or frozen[id]) then
				return -- (a trap or the line holds them: not their choice)
			end
			local root = status == "Active" and rootOf(id)
			if root and MapService.inZone(start, root.Position) then
				inStart[id] = true
			end
		end
		local camped = false
		for id, role in match.roles do
			local root = role == "Catcher" and rootOf(id)
			if root and nearZone(start, root.Position) then
				camped = true
			end
		end
		local bot = botPlayed and PracticeBot.position()
		if bot and nearZone(start, bot) then
			camped = true
		end
		campFor = if camped then campFor + dt else 0
		local excused = camped and campFor < 10
		still = if not excused and Rules.stalling(match, inStart, w.only) then still + dt else 0
		if w.onWarn and not warned and still >= w.warnAt then
			warned = true
			w.onWarn()
		end
		if still >= w.wait then
			fired = true
			w.onStall()
		end
	end
end

-- The last runner out on the field (Shared/RoundRules.lastRunner): faster, and everyone hears about it once a round.
local calledMatch, calledRound = nil, nil -- the game and round the "last runner" line was said in
local function watchLastRunner(roundRunners)
	local id = Rules.lastRunner(match)
	if id == lastRunner then
		return
	end
	if roundRunners < 2 then
		return -- (alone from the start: no "last runner" moment)
	end
	local before = lastRunner
	lastRunner = id
	if before then
		syncPlayer(before)
	end
	if id then
		syncPlayer(id)
		if not (calledMatch == match and calledRound == match.round) then
			calledMatch, calledRound = match, match.round
			-- (a moment after the catch or crossing that made them last, so that line gets read first)
			task.delay(0.8, function()
				if lastRunner == id then
					announce(`{nameOf(id)} is the last runner!`, WHITE)
				end
			end)
		end
	end
end

local function play(seconds, done, live, onFrame)
	playUntil = os.clock() + seconds
	while os.clock() < playUntil and not (done and done()) and not match.over do
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
		if onFrame and not match.over then
			onFrame(dt)
		end
	end
	return os.clock() >= playUntil
end

local function runRound()
	table.clear(fellAt) -- (a new round: last round's fall spots don't count)
	local events = Rules.startRound(match)
	if match.over then
		apply(events)
		return
	end
	goalName = MapService.goalFor(match.round)
	local startName = MapService.startFor(match.round)
	State:SetAttribute("Round", match.round)
	State:SetAttribute("SpeedUp", roundScale()) -- (1.06 = 6% faster than round 1: for the HUD's round line)
	PracticeBot.setScale(roundScale())
	State:SetAttribute("Goal", goalName)
	State:SetAttribute("Streak", match.streak)
	State:SetAttribute("RunnersLeft", #Rules.idsWithRole(match, "Runner"))
	State:SetAttribute("LastStanding", (match.startRunners or 0) >= 2)
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
		botPlayed = PracticeBot.spawn(MapService.middleSpot(1, startName) or MapService.spot(zones.Middle, zones[startName].Position, Config.Map.MiddleSpawn))
		if botPlayed then -- (the bot is a catcher too: the safe zones' walls stop it)
			local ok, bots = pcall(CollectionService.GetTagged, CollectionService, "HuzzBot")
			for _, m in if ok then bots else {} do
				MapService.setCatcher(m, true)
			end
		end
		if botPlayed and botChecked ~= match then -- (its first round this game)
			botChecked = match
			-- it adapts to the kids playing it: someone new in the game = it starts again at Config.Bot.Speed
			local ids = {}
			for id in match.roles do
				table.insert(ids, id)
			end
			table.sort(ids)
			local key = table.concat(ids, ",")
			if key ~= botPlayers then
				botPlayers, botNews = key, nil
				PracticeBot.reset()
			elseif botNews then
				announce(`{Config.Bot.Name} is {botNews} this game`, WHITE)
			end
			botNews = nil
		end
	else
		botPlayed = false
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
		-- one runner on the line: no roulette to watch (loop audit: dead time), their choice opens straight away
		local roulette = if #runnersWith("Active") > 1 then P.Roulette else 0
		State:SetAttribute("PickAt", Workspace:GetServerTimeNow() - (P.Roulette - roulette))
		setStage("Picking", roulette + P.ChooseTime)
		if roulette > 0 then
			announce("Picking a runner...", WHITE)
		end
		task.delay(roulette, function()
			if match and match.picked and not match.choice then
				announce(`{nameOf(match.picked)}: HERO or CHICKEN?`, WHITE)
			end
		end)
		play(roulette + P.ChooseTime, function()
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
		announce(`{nameOf(hero)}'s solo run!`, WHITE)
		local H = Config.Hurry
		local timedOut = play(Config.HeroTime, function()
			return match.status[hero] ~= "Active" or match.hero ~= hero
		end, true, H and stallWatch({
			only = hero,
			wait = H.HeroWait,
			delay = 1, -- (the camera comes back to them first)
			warnAt = 3,
			onWarn = function()
				local p = byId[hero]
				if p then
					RoundNet:FireClient(p, "Announce", { text = "Go now!", color = GOLD })
				end
			end,
			onStall = function()
				-- the Hero never left the start (AFK, or scared): no solo run, everyone runs
				Rules.heroTimeout(match)
				announce(`{nameOf(hero)} didn't go. Everyone runs!`, WHITE)
			end,
		}))
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
			PracticeBot.place(MapService.middleSpot(1, startName) or MapService.spot(zones.Middle, zones[startName].Position, Config.Map.MiddleSpawn))
		end
		if match.status[hero] == "Active" then
			frozen[hero] = true
			place(hero) -- (timed out: back to the line)
		end
		MapService.holdStart(startName, true)
		PowerService.clear(true) -- (traps laid during the Hero run don't stay for everyone's run; the power cards do)
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

	-- 3, 2, 1, GO! Everyone runs. Straight after a camera shot (CHICKEN, no answer, or no pick) every camera first
	-- swings back behind its player (Gameplay/Cinematic: Shot.HandBackTime 0.3 s + the hand-over), so the count gets
	-- a lead of CAMERA_BACK seconds in which the HUD draws nothing (owner: "fix the countdown when someone chooses
	-- chicken, the numbers just dont appear well": 3 popped while the camera was still flying back). After a Hero
	-- run the camera is already back: no lead.
	local CAMERA_BACK = 0.6
	local fromShot = State:GetAttribute("Stage") == "Chosen" or State:GetAttribute("Stage") == "Picking" or State:GetAttribute("Stage") == "Lineup"
	local countTime = Config.CountdownTime + (if fromShot then CAMERA_BACK else 0)
	setStage("Countdown", countTime)
	play(countTime)
	MapService.holdStart(startName, false)
	table.clear(frozen)
	PracticeBot.setFrozen(false)
	syncAll()
	setStage("Running", Config.RoundTime)
	announce("GO! Get across!", WHITE)
	local H = Config.Hurry
	local stalled = H and stallWatch({
		wait = H.Wait,
		onStall = function()
			if hurry(H.Time) then
				announce("Hurry! Run or you're out", RED)
			end
		end,
	})
	local roundRunners = #runnersWith("Active")
	play(Config.RoundTime, function()
		return Rules.isRoundOver(match)
	end, true, function(dt)
		if stalled then stalled(dt) end
		watchLastRunner(roundRunners)
	end)
	if lastRunner then
		local id = lastRunner
		lastRunner = nil
		syncPlayer(id)
	end
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
	-- It adapts to whoever plays it (Config.Bot.Step): slower after a win, faster after a loss (said when its next
	-- game starts). Only when it was the catcher in the last round.
	if botPlayed then
		botNews = PracticeBot.result(botWon)
	end
	local winnerId = if botWon then nil else match.winner
	local winner = winnerId and byId[winnerId]
	-- A girl you already own pays coins by her rarity instead (Config/Round.DupeCoins; loop audit: a repeat win
	-- gave nothing at all)
	local dupeCoins = nil
	if winner then
		local profile = DataService.get(winner)
		local d = profile and profile.Data
		if d and d.Characters and d.Characters[girl.id] then
			dupeCoins = (Config.DupeCoins or {})[girl.rarity or ""] or 25
		end
	end
	-- A catchers' win goes to the catchers who did the catching (the lead, or anyone with a catch). Runners caught
	-- in earlier rounds are catchers too, and those caught in the last round survived longer than them, so
	-- "every catcher wins" paid the wrong players (loop audit, Oct 18).
	local function wonGame(id, role)
		local caught = id == match.lead or id == winnerId or (match.catches[id] or 0) > 0
		-- (a runner caught in the last round lost, release check Oct 22: they were paid as winners; a Forfeit, every
		-- runner gone before a single catch, pays nobody)
		return not botWon and match.reason ~= "Forfeit" and ((match.team == "Runners" and role == "Runner" and match.status[id] ~= "Downed")
			or (match.team == "Catchers" and role == "Catcher" and caught))
	end
	-- the winner page (Screens/Results, Shared/Standings): everyone's numbers for its MVP / Survival / Catches tabs
	local board = {}
	for id, role in match.roles do
		local p, t = byId[id], tally[id] or {}
		if p then
			table.insert(board, { user = p.UserId, name = p.DisplayName, crossed = t.Crossings or 0, catches = t.Catches or 0,
				rescues = t.Rescues or 0, heroes = t.Heroes or 0, won = wonGame(id, role) })
		end
	end
	for id, role in match.roles do
		addStat(id, "Rounds", 1) -- "Play 3 games"
		local won = wonGame(id, role)
		if won then
			addStat(id, "Wins", 1)
			-- Crown Pose (a Robux cosmetic): winners who wear it strike it (HuzzClient/Gameplay/CrownPose)
			local c = byId[id] and byId[id].Character
			local now = workspace:GetServerTimeNow()
			if c and c:GetAttribute("HuzzPose") == "CrownPose" and now - (c:GetAttribute("HuzzPoseAt") or 0) > 4 then
				c:SetAttribute("HuzzPoseAt", now)
			end
		end
		-- pay for the game: coins for playing, more and a little Aura for winning
		local p = byId[id]
		local pay = Config.Pay
		if p and pay then
			local coins, aura = pay.Played + (if won then pay.Won else 0), if won then pay.WonAura else 0
			coins *= require(script.Parent.SpinService).boost(p, "Coins") -- Spin the Wheel's "x2 Coins" while it lasts
			coins = require(script.Parent.FriendService).coins(p, coins) -- +10% while a friend plays here (Config/Friends)
			coins = require(script.Parent.PlaytimeService).coins(p, coins) -- +10% a step for time played here (Config/Playtime)
			DataService.update(p, function(d)
				d.Coins = (d.Coins or 0) + coins
				d.Aura = (d.Aura or 0) + aura
			end)
			RoundNet:FireClient(p, "Bonus", { coins = coins, aura = aura, late = true })
			-- the results screen (Screens/Results): how your game went
			local t = tally[id] or {}
			-- XP for every game (it only came from quests, so everyone stopped at level 5): playing, winning, and each
			-- thing you did (Config/Progression.GameXP); past the reward track each new level pays a little
			local xp, levelUp = ProgressService.gameXP(p, won, t)
			RoundNet:FireClient(p, "Results", {
				outcome = if botWon then "Bot" elseif won then "Win" else "Lose",
				girl = girl.name, rarity = girl.rarity, gotGirl = winnerId == id, girlTaken = winnerId ~= nil,
				winnerName = if winner then winner.DisplayName else nil, xp = xp, level = levelUp,
				dupeCoins = if winnerId == id then dupeCoins else nil,
				team = match.team, bot = botWon or nil, board = board, heroPaid = t.HeroPaid or 0,
				crossed = t.Crossings or 0, catches = t.Catches or 0, rescues = t.Rescues or 0, heroes = t.Heroes or 0,
				-- everything this game paid: the game's pay, a Hero bonus, and Aura from stars on the field
				coins = coins + (t.BonusCoins or 0), aura = aura + (p:GetAttribute("HuzzGameAura") or 0),
			})
		end
	end
	if winner then
		-- Into the winner's collection: the Index shows every id in Characters.
		DataService.update(winner, function(d)
			-- a copy of her (Shared/CombineRules: a Normal copy; two of the same grade combine at the machine, and
			-- PRESTIGE can spend a spare one)
			CombineRules.add(d, girl.id, "Normal")
			-- your first girl walks with you at once, so everyone sees her (owner, Oct 19: "make the girls be seen on
			-- everyones screen"; before, a won girl waited in the Index until you equipped her)
			if (d.Equipped or "") == "" then d.Equipped = girl.id end
			if dupeCoins then
				d.Coins = (d.Coins or 0) + dupeCoins
			end
		end)
		-- after the win she stands on the floor beside her winner, every girl, whoever wins (owner, Oct 20 15:13: "make
		-- the girls always be on the floor after the game is won. make it for all of them"): a runner's girl stops
		-- being carried and walks with him like a catcher's (CarryService.follow: each screen drops her to
		-- the floor under her and keeps her feet on it, HuzzClient/Gameplay/CarryAnimator)
		local held = CarryService.get(winner)
		if match.holder ~= winnerId or not (held and held:GetAttribute("Follow")) then
			local from = (match.holder and byId[match.holder] and CarryService.position(byId[match.holder]))
				or (showcase and showcase:GetPivot().Position) or nil
			if match.holder and byId[match.holder] then
				CarryService.remove(byId[match.holder])
			end
			CarryService.follow(winner, girl, from)
			showcaseVisible(false)
		end
		CarryService.setMood(winner, "Cheer")
	elseif match.holder then
		-- nobody wins her (every runner went Chicken, or the bot won): she leaves whoever still has her, so she
		-- doesn't follow a losing catcher through the game-over screen (critic)
		moveGirlTo(match.holder, nil, "Dropped")
	end
	RoundNet:FireAllClients("Win", {
		team = match.team, winner = winnerId, name = if botWon then nil else winner and winner.DisplayName, -- ("Nobody wins her")
		girl = girl.name, rarity = girl.rarity, bot = botWon or nil,
		-- a catcher wins her only by catching the last runner (owner, Oct 19): the HUD says so
		lastCatch = (not botWon and match.team == "Catchers" and winnerId ~= nil and winnerId == match.lastCatchBy) or nil,
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
	-- (read from 6 studs over the Middle box: Halloween's grass top is above the box, and a ray started inside the
	-- grass misses it, so she stood 8 studs low and the Secret cutscene showed her sunk in the floor)
	local floor = MapService.ground(m.Position, m.Position.Y + m.Size.Y / 2 + 6) or (m.Position.Y - m.Size.Y / 2)
	local ok, result = pcall(GirlService.showcase, girl, Vector3.new(m.Position.X, floor + Config.Showcase.Height, m.Position.Z), Workspace)
	if ok then
		showcase = result
	else
		warn("[Huzz] Couldn't show the girl over the map: " .. tostring(result))
	end
end

local function runGame()
	MapService.setBounds(true) -- (the field's invisible walls: only during a game)
	MapService.holdCatchers(true) -- (and the safe zones' walls for catchers)
	table.clear(tally)
	for _, p in Players:GetPlayers() do
		p:SetAttribute("HuzzGameAura", 0) -- (AuraPickupService adds the stars collected this game)
	end
	showShowcase()
	-- A Secret girl arrives with a cutscene on every screen (HuzzClient/Gameplay/SecretReveal): she bursts out of an
	-- orb of light, lands in the middle of the map and floats up to her place, then the game goes on.
	if girl.rarity == "Secret" and showcase then
		-- (the owner's place streams the world in around each player: the cutscene's spot over the map can be too
		-- far from the lobby, so its floor and props were missing in Studio. Load them around everyone first, for
		-- at most 3 s, and keep them loaded until the cutscene ends)
		local spot = (showcase:GetAttribute("Base") :: CFrame?) or showcase:GetPivot()
		local focus = showcase:FindFirstChild("Aura")
		local waiting = 0
		for _, p in Players:GetPlayers() do
			pcall(function() p.ReplicationFocus = focus end)
			waiting += 1
			task.spawn(function()
				pcall(function() p:RequestStreamAroundAsync(spot.Position - Vector3.new(0, Config.Showcase.Height, 0), 3) end)
				waiting -= 1
			end)
		end
		local deadline = os.clock() + 3
		while waiting > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
		task.delay(SecretReveal.LENGTH, function()
			for _, p in Players:GetPlayers() do
				pcall(function() if p.ReplicationFocus == focus then p.ReplicationFocus = nil end end)
			end
		end)
		showcase:SetAttribute("RevealAt", Workspace:GetServerTimeNow())
		setStage("Reveal", SecretReveal.LENGTH)
		announce("Something rare is coming...", Color3.fromRGB(190, 170, 255))
		task.delay(SecretReveal.NAME, announce, `SECRET: {girl.name}!`, Color3.fromRGB(150, 110, 255)) -- (with her name card)
		task.wait(SecretReveal.LENGTH)
	end
	local ids, all = {}, {}
	for id, p in byId do
		if Skip.sitting(id) then continue end -- (SKIP (skip game): they stay in the lobby this game)
		table.insert(all, id)
		-- (only players whose save has loaded: pay, XP and a won girl go into the save; release check, Oct 22. A
		-- slow load, e.g. a save handed over from another server, joins the next game)
		if DataService.get(p) then table.insert(ids, id) end
	end
	if #ids == 0 then ids = all end -- (never a game with nobody: then everyone plays)
	local catcher = if #ids >= 2 then ids[math.random(#ids)] else nil
	match = Rules.newGame(ids, catcher, { maxRounds = Config.MaxRounds, crossings = Config.Crossings })
	State:SetAttribute("GirlName", girl.name)
	State:SetAttribute("GirlRarity", girl.rarity)
	State:SetAttribute("HolderId", 0)
	State:SetAttribute("Crossings", Config.Crossings)
	State:SetAttribute("Winners", "")
	announce(`{girl.name} is up for grabs!`, GirlService.rarity(girl.rarity).Color)
	if catcher then
		task.delay(1.5, announce, `{nameOf(catcher)} is the CATCHER!`, RED)
	elseif Config.Bot.Enabled then
		task.delay(1.5, announce, `{Config.Bot.Name} is the CATCHER!`, RED)
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
	MapService.holdCatchers(false)
	PowerService.clear()
	MapService.showGoal(nil) -- the lines stay on the map, the SAFE ZONE sign goes out
	match, girl = nil, nil
	lastRunner = nil
	Skip.clear()
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

-- How far back the catcher's screen shows the runners (owner, Oct 19: "make the player to player touch WAY MORE
-- accurate"): their one-way network trip plus Roblox's smoothing of other bodies, capped (Config.Touch).
local function viewDelay(id): number
	local T = Config.Touch
	local p = id and byId[id]
	local ping = 0
	if p then
		local ok, value = pcall(function() return p:GetNetworkPing() end)
		ping = if ok and type(value) == "number" then value else 0
	end
	return math.clamp(ping / 2 + T.Smoothing, 0, T.MaxRewind)
end

-- Does the knife's box touch this runner's body, anywhere it was over the last `back` seconds (where the catcher's
-- screen showed it)? Their limbs, torso and head only (Shared/TouchHit), placed where their root was then
-- (HuzzServer/HitHistory); a body whose parts can't be read is a standard body's box.
local function touchesRunner(boxCF: CFrame, boxSize: Vector3, root: BasePart, back: number): boolean
	local character = root.Parent
	local shape = character and TouchHit.shape(root.CFrame, character:GetChildren())
		or TouchHit.standIn(CFrame.identity)
	for _, at in HitHistory.between(root, os.clock() - back) do
		if TouchHit.touches(boxCF, boxSize, at, shape, Config.Touch.Tolerance) then
			return true
		end
	end
	return false
end

-- Stab the nearest runner the knife's box touches (Shared/TouchHit: the box in front of the catcher, or along their
-- leap, `knife` = Config Stab or Lunge Reach x Width, against the runner's own body where the catcher's screen showed
-- it). Shields, the safe start zone and a fresh rescue protect. True when someone was hit.
-- only: the runner the catcher's screen hit (pinpoint, Gameplay/HitCheck): just that one is checked.
-- id nil = the Practice Bot: its knife is where the runner's screen showed the bot (Touch.Smoothing ago).
local chaseClaim
local function stabNear(id, me: BasePart, knife, only: number?, along: Vector3?): boolean
	local now = os.clock()
	local start = zones[MapService.startFor(match.round)]
	local from = me.CFrame
	local back = viewDelay(id)
	if id == nil then
		HitHistory.track(me)
		from = HitHistory.at(me, now - Config.Touch.Smoothing)
		back = 0
	end
	local boxCF, boxSize = TouchHit.reachBox(from, along, knife.Reach, knife.Width)
	local best, bestDistance = nil, math.huge
	for runnerId, status in match.status do
		local root = (only == nil or runnerId == only) and status == "Active" and not frozen[runnerId]
			and (protectedUntil[runnerId] or 0) <= now and rootOf(runnerId)
		if root then
			local offset = root.Position - me.Position
			local safe = Config.StartZoneSafe and start and MapService.inZone(start, root.Position)
			if offset.Magnitude < bestDistance and not safe and touchesRunner(boxCF, boxSize, root, back) then
				best, bestDistance = runnerId, offset.Magnitude
			end
		end
	end
	if best then
		if PowerService.blocks(id, best) then
			return true -- (a Shield took it: that ends the stab or the dive)
		end
		apply(Rules.tag(match, id, best))
		return true
	end
	return false
end

-- A hit the catcher's screen saw, judged on what that screen showed (owner, Oct 19: "make the player to player
-- interactions pinpoint precise"): shown = { seen = the runner's root as drawn there, mine = the catcher's root },
-- from Gameplay/HitCheck. Shared/TouchHit.verify ties it to one moment of our own history (HitHistory), points the
-- knife the way we have the catcher facing (or along their dive), and caps the reach at an honest one plus
-- Touch.CapSlack. Shields, the safe start zone and a fresh rescue protect as in stabNear. True when it holds (a hit,
-- or a Shield took it); false sends the caller to the server's own test (chaseClaim).
-- A body's speed as its own screen reports it, flat and capped at the dive's speed (Config.Lunge.Speed).
local function cappedSpeed(v: Vector3?): Vector3
	if typeof(v) ~= "Vector3" then return Vector3.zero end -- (a body with no speed, e.g. in the sim)
	local flat = Vector3.new(v.X, 0, v.Z)
	local cap = Config.Lunge.Speed
	if flat.Magnitude ~= flat.Magnitude then return Vector3.zero end -- (NaN)
	return if flat.Magnitude > cap then flat.Unit * cap else flat
end

local function screenHit(id, me: BasePart, runnerId: number, shown, knife, along: Vector3?): boolean
	local now = os.clock()
	local root = match.status[runnerId] == "Active" and not frozen[runnerId]
		and (protectedUntil[runnerId] or 0) <= now and rootOf(runnerId)
	if not root then
		return false
	end
	local start = zones[MapService.startFor(match.round)]
	if Config.StartZoneSafe and start and MapService.inZone(start, root.Position) then
		return false
	end
	local T = Config.Touch
	local character = root.Parent
	local shape = character and TouchHit.shape(root.CFrame, character:GetChildren()) or TouchHit.standIn(CFrame.identity)
	local p = byId[id]
	local okPing, ping = pcall(function() return p and p:GetNetworkPing() end)
	ping = if okPing and type(ping) == "number" then ping else 0
	local runnerPath = HitHistory.samples(root, now - T.MaxRewind)
	-- The catcher's screen drew the runner where the runner's own newest stamp said they were at its frame (Oct 23,
	-- Gameplay/OthersAhead), which our copy may not have reached yet (it left the runner half their ping ago). So the
	-- path gets that one point too: the newest stamp we checked (MotionRelay), moved on to the catcher's frame (half
	-- the catcher's ping ago), and never further from our own copy than our copy's own speed could cover in the time
	-- it is behind (half the runner's ping and Roblox's 0.1 s, plus a stud): a stamp can't stretch the reach.
	local runner = byId[runnerId]
	local st = MotionRelay.latest(runner) or MotionRelay.latest(character)
	if st and #runnerPath > 0 then
		local at = Workspace:GetServerTimeNow() - ping / 2
		if at - st.t <= 0.35 and at - st.t > -0.25 then
			local okR, rPing = pcall(function() return runner and runner:GetNetworkPing() end)
			rPing = if okR and type(rPing) == "number" then math.clamp(rPing, 0, 0.5) else 0.1
			local v = root.AssemblyLinearVelocity
			local most = Vector3.new(v.X, 0, v.Z).Magnitude * (rPing / 2 + 0.1) + 1
			local off = MotionStamps.limit(MotionStamps.predict(st, math.max(0, at - st.t)) - root.Position)
			if off.Magnitude > most then off = off.Unit * most end
			table.insert(runnerPath, { t = now, cf = root.CFrame + off })
		end
	end
	if not TouchHit.verify(shown, {
		runner = runnerPath,
		catcher = HitHistory.samples(me, now - T.MineBack),
		now = now,
		back = TouchHit.lookBack(ping, T),
		shape = shape, knife = knife, along = along,
		-- (the speed comes from the catcher's own screen: flat, and never faster than a dive, so a faked speed can't
		-- stretch the reach; critic, Oct 19)
		face = me.CFrame.LookVector, vel = cappedSpeed(me.AssemblyLinearVelocity),
	}, T) then
		return false
	end
	if PowerService.blocks(id, runnerId) then
		return true -- (a Shield took it: that ends the stab or the dive)
	end
	apply(Rules.tag(match, id, runnerId))
	return true
end

-- A hit claimed without what the screen showed (an old client): that one runner is checked from here every frame
-- until `untilClock`, the way the old lunge loop kept checking (a single check failed under normal lag).
function chaseClaim(id, player, claim, knife, untilClock, onHit, along)
	task.spawn(function()
		while true do
			local me = rootOf(id)
			local st = State:GetAttribute("Stage")
			if not (me and match and not match.over and match.roles[id] == "Catcher" and (st == "Running" or st == "HeroRun"))
				or frozen[id] or KnockdownService.isDown(player) or not PowerService.canStab(id) or PowerService.stunned(id) then
				return -- (a dive's hit can't land once the diver lies stunned)
			end
			if stabNear(id, me, knife, claim, along) then
				if onHit then onHit() end
				return
			end
			if os.clock() >= untilClock or match.status[claim] ~= "Active" then
				return
			end
			task.wait(0.03)
		end
	end)
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
	PracticeBot.step(targets, function(me, target)
		botTagging = true
		local along = if target then Vector3.new(target.Position.X - me.Position.X, 0, target.Position.Z - me.Position.Z) else nil
		local ok, hit = pcall(stabNear, nil, me, Config.Stab, nil, if along and along.Magnitude > 0.1 then along.Unit else nil)
		botTagging = false
		-- everyone sees the bot's stab too (Gameplay/Actions plays it on the HuzzBot model): on a hit, and at
		-- most once a stab cooldown while it keeps trying (a shield or the safe zone stopping it)
		local now = os.clock()
		if Config.TagMode == "Stab" and ((ok and hit) or now - botStabShownAt >= Config.Stab.Cooldown) then
			botStabShownAt = now
			RoundNet:FireAllClients("Stab", { bot = true, hit = ok and hit or nil })
		end
		return ok and hit
	end, fallY)
end

Net.get("Stab").OnServerEvent:Connect(function(player, claim, shown)
	local id = player.UserId
	if claim ~= nil and claim ~= false and type(claim) ~= "number" then
		return
	end
	local stage = State:GetAttribute("Stage")
	if not (match and not match.over and match.roles[id] == "Catcher" and (stage == "Running" or stage == "HeroRun") and not frozen[id]) then
		return
	end
	if MoveGuard.flagged(player) then
		return -- (just sent back for moving too far: no hit from a jump)
	end
	if Config.TagMode ~= "Stab" or KnockdownService.isDown(player) or not PowerService.canStab(id) or PowerService.stunned(id) then
		return -- (dizzy from a Shield, or stunned after a dive: no stabbing for a moment)
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
	if type(claim) == "number" then
		-- pinpoint: the runner the catcher's screen saw inside the knife's reach, if that's possible from here.
		-- Checked again for a moment (critic: a catcher a little behind on our side at full speed failed a single
		-- check and the kid saw a clean hit do nothing); still in front only, so a cheat can't hit all round.
		-- (pinpoint: what the screen showed, Oct 19; if that fails, or an old client sent none, our own test)
		if not (type(shown) == "table" and screenHit(id, me, claim, shown, Config.Stab)) then
			chaseClaim(id, player, claim, Config.Stab, os.clock() + 0.25)
		end
	elseif claim == nil then
		stabNear(id, me, Config.Stab) -- (a client that can't check)
	end -- (false: a clean miss on the catcher's screen)
end)

-- The catcher's lunge (Config.Lunge): the client leaps at once (Gameplay/Dash) and tells us; we check it's allowed,
-- set the Space cooldown, show the stab to everyone, and for HitWindow seconds stab the first runner within
-- the leap's knife box (Config.Lunge Reach x Width, along the leap; Shared/TouchHit on the runner's body) (shields and
-- the safe start zone still count).
local lastLunge = {}
local lungeHit = {} -- id -> true once this lunge has caught someone (one runner per lunge)
local lungeClaims = {} -- id -> true while this lunge lets the catcher's screen report the hit (it sent true)
local lungeDirs = {} -- id -> the way this lunge goes (flat unit Vector3; sideways leaps hit only to that side)
Net.get("Lunge").OnServerEvent:Connect(function(player, arg, dir)
	local id = player.UserId
	local c = player.Character
	-- a pinpoint hit from the catcher's screen during their leap (Gameplay/Dash + HitCheck)
	if type(arg) == "number" then
		local me = rootOf(id)
		local st = State:GetAttribute("Stage")
		if me and match and not match.over and match.roles[id] == "Catcher" and (st == "Running" or st == "HeroRun")
			-- (the claim's moment, from the press: arrival - lastLunge, the catcher's ping cancels out; after the
			-- landing they lie stunned, so a hit then isn't fair: StunAfter + 0.1 s for the network's jitter)
			and lungeClaims[id] and lastLunge[id] and os.clock() - lastLunge[id] <= math.min(Config.Lunge.HitWindow,
				Config.Lunge.StunAfter or Config.Lunge.Time) + 0.1 and not lungeHit[id]
			and not frozen[id] and not KnockdownService.isDown(player) and PowerService.canStab(id) and Config.TagMode == "Stab"
			and not MoveGuard.flagged(player) then
			lungeClaims[id] = nil -- (one claim per lunge)
			-- (pinpoint, Oct 19: the second value is what the screen showed, not a direction; if it fails, or an old
			-- client sent none, our own test for a moment, never past the stun)
			if type(dir) == "table" and screenHit(id, me, arg, dir, Config.Lunge, lungeDirs[id]) then
				lungeHit[id] = true
			else
				chaseClaim(id, player, arg, Config.Lunge, os.clock() + 0.25, function()
					lungeHit[id] = true
				end, lungeDirs[id])
			end
		end
		return
	end
	if arg ~= nil and arg ~= true then
		return
	end
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
	lungeHit[id] = nil
	lungeClaims[id] = arg == true or nil -- (a lunge the server checks itself takes no claim: no second hit)
	-- the leap's way (Gameplay/Dash + Shared/KnifeLeap: forward or sideways, never back); a bad value = facing
	lungeDirs[id] = nil
	local me0 = rootOf(id)
	if typeof(dir) == "Vector3" and dir == dir and me0 then
		local flat = Vector3.new(dir.X, 0, dir.Z)
		if flat.Magnitude > 0.5 and flat.Unit:Dot(me0.CFrame.LookVector) > -0.3 then
			lungeDirs[id] = flat.Unit
		end
	end
	player:SetAttribute("DashReady", now + Config.Lunge.Cooldown)
	player:SetAttribute("DashCooldown", Config.Lunge.Cooldown) -- (how long this wait is: the HUD's dash bar)
	c:SetAttribute("LungeAt", now) -- (every screen plays the leap)
	PowerService.stun(id, Config.Lunge.StunAfter or Config.Lunge.Time, Config.Lunge.Stun or 0) -- (the dive's 0.4 s slide and pop up: Config/Round.Lunge)
	RoundNet:FireAllClients("Stab", { id = id, lunge = true }) -- (the stab move, on the catcher's own screen too)
	if Config.TagMode ~= "Stab" or arg == true then
		return -- (touch mode: the leap is just a leap; true: the catcher's screen reports the hit itself)
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
			if lungeHit[id] then
				return
			end
			if stabNear(id, me, Config.Lunge, nil, lungeDirs[id]) then
				lungeHit[id] = true
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
	-- the Practice Bot while it catches this round (a runner's Banana Peel trips it too), else nil
	bot = function()
		return if botPlayed and PracticeBot.active() then PracticeBot else nil
	end,
})

-- Hero or Chicken: only the picked runner, while the pick is open (Shared/RoundRules.choose).
Net.get("Hero").OnServerEvent:Connect(function(player, isHero)
	local id = player.UserId
	if match and not match.over and match.picked == id and State:GetAttribute("Stage") == "Picking" and type(isHero) == "boolean" then
		apply(Rules.choose(match, id, isHero))
	end
end)

-- The huss cut-off (Config.Cut): everyone on the other side whose way ahead this huss crosses runs slower for a moment
-- (the Practice Bot too, when it's the catcher).
local function cutOff(id, from: Vector3, dir: Vector3)
	local cut = Config.Cut
	local mine = match.roles[id]
	local function flatLook(cf: CFrame)
		local l = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
		return if l.Magnitude > 0.1 then l.Unit else nil
	end
	for other, role in match.roles do
		if other ~= id and role ~= mine and (role ~= "Runner" or match.status[other] == "Active") then
			local r = rootOf(other)
			local look = r and flatLook(r.CFrame)
			if look and Rules.cutsOff(from, dir, cut.Path, r.Position, look, cut) then
				PowerService.slowFor(other, cut.Slow, cut.Time)
			end
		end
	end
	local bot = mine == "Runner" and botPlayed and PracticeBot.body()
	local botRoot = bot and bot:FindFirstChild("HumanoidRootPart")
	local look = botRoot and flatLook(botRoot.CFrame)
	if look and Rules.cutsOff(from, dir, cut.Path, botRoot.Position, look, cut) then
		PracticeBot.slow(cut.Slow, cut.Time)
	end
end

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
	-- client turns toward its camera's line as it husses and sends that facing, which we haven't seen yet: we take it
	-- when it's within 150 degrees of the facing we have (the client turns at most 90 degrees, plus lag; past 150 our own
	-- facing is nearly the same line, so the sideways check below still passes: no angle is refused by mistake).
	local facing = root.CFrame.LookVector
	if typeof(look) == "Vector3" and look == look then
		local flatLook, flatFacing = Vector3.new(look.X, 0, look.Z), Vector3.new(facing.X, 0, facing.Z)
		if flatLook.Magnitude > 0.1 and flatFacing.Magnitude > 0.1 and flatLook.Unit:Dot(flatFacing.Unit) > math.cos(math.rad(150)) then
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
	player:SetAttribute("DashReady", start + Config.Dash.Cooldown) -- (when the huss is ready again, server time)
	player:SetAttribute("DashCooldown", Config.Dash.Cooldown) -- (how long this wait is: the HUD's dash bar fills over it)
	c:SetAttribute("DashDir", flat.Unit)
	c:SetAttribute("DashAt", start)
	if playing and stage == "Running" then
		cutOff(id, root.Position, flat.Unit)
	end
end)

-- Players
local function onCharacter(player, character)
	local id = player.UserId
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	humanoid.Died:Connect(function()
		-- Only a death while you can run counts as a catch (Running, or the Hero's own solo run). A reset or a fall
		-- while waiting on the line (Lineup, Picking, Countdown, the others' Hero run) isn't one: the new body goes
		-- back to its line spot (place, below) and still runs (bug hunt, Oct 20: it used to make them a catcher).
		if match and match.status[id] == "Active" and Rules.deathCounts(State:GetAttribute("Stage"), frozen[id] == true) then
			-- (health is already 0 here, so rootOf says nil: keep where they fell before tagging, so the new body
			-- lies down there and nobody can rescue it from wherever it respawns)
			local root = character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then fellAt[id] = root.CFrame end
			apply(Rules.tag(match, nil, id))
		end
	end)
	task.defer(function()
		place(id) -- the lobby, the middle or their spot on the line
		if match and match.status[id] == "Downed" and fellAt[id] then
			character:PivotTo(fellAt[id]) -- reset while down: lie down again where they fell (the server, at once: down() anchors it next)
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
		DataService.waitFor(player, 60)
		syncPlayer(player.UserId) -- the name tag's level and wins once the save has loaded
	end)
	player.CharacterAdded:Connect(function(c)
		MapService.playerParts(c) -- (players pass through each other: MapService PLAYER)
		onCharacter(player, c)
	end)
	-- the avatar's look can swap body parts after spawning: put the worn knife back on the new ones
	pcall(function() -- (guarded: the offline harness's copy of the Roblox API has no CharacterAppearanceLoaded)
		player.CharacterAppearanceLoaded:Connect(function()
			if byId[player.UserId] then syncPlayer(player.UserId) end
		end)
	end)
	if player.Character then
		MapService.playerParts(player.Character)
		task.spawn(onCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do
	onPlayer(p)
end
Players.PlayerRemoving:Connect(function(player)
	lastStab[player.UserId] = nil
	if #Players:GetPlayers() <= 1 then
		botPlayers, botNews = nil, nil -- (the server empties: the Practice Bot starts again for the next kid)
		PracticeBot.reset()
	end
	if match then
		apply(Rules.removePlayer(match, player.UserId))
		-- The only catcher left mid-run (release check, Oct 22: the rest of the round was a free walk across): the
		-- Practice Bot steps in from the middle, as it does when a round starts with nobody catching.
		local stage = State:GetAttribute("Stage")
		if Config.Bot.Enabled and not match.over and not botPlayed and (stage == "Running" or stage == "HeroRun") and zones.Middle then
			local anyCatcher, anyRunner = false, false
			for id, role in match.roles do
				if id ~= player.UserId and role == "Catcher" then anyCatcher = true end
				if id ~= player.UserId and role == "Runner" and match.status[id] == "Active" then anyRunner = true end
			end
			if not anyCatcher and anyRunner then
				local startName = MapService.startFor(match.round)
				botPlayed = PracticeBot.spawn(MapService.middleSpot(1, startName) or MapService.spot(zones.Middle, zones[startName].Position, Config.Map.MiddleSpawn))
				if botPlayed then
					local ok, bots = pcall(CollectionService.GetTagged, CollectionService, "HuzzBot")
					for _, m in if ok then bots else {} do
						MapService.setCatcher(m, true)
					end
					PracticeBot.setScale(roundScale())
					PracticeBot.setFrozen(false)
					announce(`{Config.Bot.Name} is catching now`, RED)
				end
			end
		end
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
	-- (SKIP (skip game): players can choose to sit the next game out while they wait, HuzzServer/SkipService)
	if #MapService.maps >= 2 then
		local a, b = MapService.candidates()
		setStage("Voting", Config.VoteTime)
		Skip.open()
		local winner = MapVoteService.run(a.name, b.name, Config.VoteTime, enough)
		Skip.close()
		return winner and MapService.byName(winner)
	end
	setStage("Intermission", Config.IntermissionTime)
	Skip.open()
	local deadline = os.clock() + Config.IntermissionTime
	while os.clock() < deadline and enough() do
		task.wait(0.25)
	end
	Skip.close()
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
	-- the server's luck on this roll (HuzzServer/LuckService): shown on the roller, and one Output line with the odds
	local okLuck, luck = pcall(function() return require(script.Parent.LuckService).server() end)
	luck = if okLuck then luck else 1
	local line = {}
	for _, o in odds do table.insert(line, `{o.name} {string.format("%.1f", o.chance)}%`) end
	print(`[HuzzLuck] server luck x{luck}: {table.concat(line, ", ")}. Rolled {girl.name} ({girl.rarity})`)
	local roll = { cells = list, stop = R.Stop, start = Workspace:GetServerTimeNow(), spin = R.SpinTime, odds = odds, luck = luck }
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

-- One pass of the server's loop: wait for players, vote, play a game, clean up. Each pass runs protected, so an error
-- anywhere in it (a map that fails to load, the girl roll) skips to the next pass instead of stopping the game
-- for the rest of the server's life.
local function onePass()
	setStage("Waiting")
	while not enough() do
		task.wait(1)
	end
	local map = chooseMap()
	if map and Skip.everyone() then
		-- (everyone chose SKIP: no game this time, the vote starts again)
		announce("Everyone skipped this game", Color3.new(1, 1, 1))
		Skip.clear()
		task.wait(2)
		return
	end
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
		announce(`Map: {map.display}`, Color3.new(1, 1, 1))
		rollGirl()
		local ok, err = xpcall(runGame, debug.traceback)
		if not ok then
			warn("[Huzz] Game stopped by an error: " .. tostring(err))
		end
		cleanUp()
	end
end

while true do
	local ok, err = xpcall(onePass, debug.traceback)
	if not ok then
		warn("[Huzz] The game loop hit an error: " .. tostring(err))
		pcall(cleanUp)
		task.wait(1)
	end
end
