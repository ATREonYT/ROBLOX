--[[
	The game's rules as a pure state machine (no Roblox calls), so every case is unit tested in
	tests/RoundRules.spec.luau. RoundService feeds it what happens in the world and acts on the events
	it returns. Players are ids (UserIds).

	Huss Valley's loop, one to one (owner's call), with the anime girl built in:
	  - One random player starts as the (lead) catcher; everyone else runs.
	  - Each round the runners line up on their safe line. One runner is picked at random and chooses
	    HERO or CHICKEN (no answer in time = a random pick). A Hero crosses ALONE first while everyone
	    else waits; Chicken skips that. Then everyone runs for the other side.
	  - A stabbed runner is DOWNED where they fall. Another runner still out on the field can rescue them
	    (stand next to them). Anyone still down when the round ends joins the catchers.
	  - One second chance per game (owner): a runner can be rescued once; caught again after that, nobody can
	    help them up ("Caught" carries final = true) and they join the catchers when the round ends.
	  - Runners win by getting EVERYONE across `crossings` (3) rounds in a row; a round where anyone
	    ends up caught resets the streak. Catchers win when no runners are left (or after maxRounds).
	The girl (floats over the map until someone wins her over):
	  - A Hero who survives the solo crossing gets her: she comes down onto their shoulders (from the sky,
	    or from the catcher who stole her).
	  - A catcher who stabs her carrier steals her: she follows that catcher around.
	  - When the game ends she goes home with the winning side: whoever on that side holds her; if
	    nobody does, the runners' last successful Hero (else a random runner who made it), or the lead
	    catcher (else the catcher with the most catches).
	  - Chicken gets nothing (owner, Oct 18: "you dont recieve the girl if you run chicken"): a runner who
	    chose Chicken this game can't be handed her at the end (s.chickens). If every runner left chose
	    Chicken, nobody wins her.

	Runner status during a round: "Active" (still to cross) | "Safe" (across) | "Downed" (stabbed).
	Every function returns a list of events:
	  {type="RoundStarted", round}            {type="NewCatcher", id}       {type="JoinCatchers", ids}
	  {type="Picked", id}                     {type="Choice", id, hero}     {type="HeroResult", id, survived}
	  {type="Safe", id}                       {type="Caught", id, by}       {type="Rescued", id, by}
	  {type="Streak", count, goal}            {type="StreakLost", count}
	  {type="GirlMoved", from, to, reason}    (reason: "Hero" | "Stolen" | "Dropped" | "Reassigned")
	  {type="Win", team, winner, reason}      (team "Runners" | "Catchers"; winner = who gets her, may be nil)
]]

local RoundRules = {}

local function idsWithRole(s, role)
	local list = {}
	for id, r in s.roles do
		if r == role then
			table.insert(list, id)
		end
	end
	table.sort(list) -- deterministic for tests
	return list
end

local function pick(s, list)
	if #list == 0 then
		return nil
	end
	return list[s.random(#list)]
end

local function moveGirl(s, to, reason, events)
	local from = s.holder
	if from == to then
		return
	end
	s.holder = to
	table.insert(events, { type = "GirlMoved", from = from, to = to, reason = reason })
end

-- Who takes her home when `team` wins.
local function girlWinner(s, team)
	local role = if team == "Runners" then "Runner" else "Catcher"
	if s.holder and s.roles[s.holder] == role then
		return s.holder
	end
	if team == "Runners" then
		if s.lastHero and s.roles[s.lastHero] == "Runner" then
			return s.lastHero
		end
		local made, brave = {}, {}
		for _, id in idsWithRole(s, "Runner") do
			if not s.chickens[id] then
				table.insert(brave, id)
				if s.status[id] == "Safe" then
					table.insert(made, id)
				end
			end
		end
		return pick(s, if #made > 0 then made else brave)
	end
	if s.lead and s.roles[s.lead] == "Catcher" then
		return s.lead
	end
	local best, most = nil, -1
	for _, id in idsWithRole(s, "Catcher") do
		local n = s.catches[id] or 0
		if n > most then
			best, most = id, n
		end
	end
	return best
end

local function finish(s, team, reason, events)
	if s.over then
		return
	end
	s.over = true
	s.team = team
	s.reason = reason
	s.winner = girlWinner(s, team)
	table.insert(events, { type = "Win", team = team, winner = s.winner, reason = reason })
end

-- opts: { random = function(n) -> 1..n, crossings = 3, maxRounds = number }
function RoundRules.newGame(ids, catcherId, opts)
	opts = opts or {}
	local s = {
		round = 0,
		roles = {},
		status = {},
		catches = {}, -- catcher id -> runners downed this game
		rescued = {}, -- runner id -> true once they've had their second chance this game
		holder = nil, -- who has the girl (a runner on their shoulders, or a catcher she follows)
		lead = catcherId, -- the first catcher
		picked = nil, -- this round's runner who chooses Hero or Chicken
		choice = nil, -- nil (not chosen yet) | "Hero" | "Chicken"
		hero = nil, -- this round's Hero (while their solo crossing counts)
		lastHero = nil, -- the latest Hero who made it across
		chickens = {}, -- runners who chose Chicken this game (they can't be handed the girl at the end)
		streak = 0, -- full crossings in a row
		goal = opts.crossings or 3,
		over = false,
		team = nil,
		winner = nil,
		reason = nil,
		maxRounds = opts.maxRounds or math.huge,
		random = opts.random or math.random,
	}
	for _, id in ids do
		s.roles[id] = if id == catcherId then "Catcher" else "Runner"
	end
	return s
end

function RoundRules.startRound(s)
	local events = {}
	if s.over then
		return events
	end
	-- Runners still down at the end of the last round catch from now on.
	if s.round > 0 then
		for id, role in s.roles do
			if role == "Runner" and s.status[id] ~= "Safe" then
				s.roles[id] = "Catcher"
			end
		end
	end
	s.round += 1
	s.status = {}
	s.picked, s.choice, s.hero = nil, nil, nil

	local runners = idsWithRole(s, "Runner")
	if #runners == 0 then
		finish(s, "Catchers", "AllCaught", events)
		return events
	end
	-- Every catcher left the server: a runner (not her carrier) takes over.
	if #runners >= 2 and #idsWithRole(s, "Catcher") == 0 then
		local pool = {}
		for _, id in runners do
			if id ~= s.holder then
				table.insert(pool, id)
			end
		end
		local id = pick(s, pool)
		s.roles[id] = "Catcher"
		s.lead = s.lead or id
		table.insert(events, { type = "NewCatcher", id = id })
		runners = idsWithRole(s, "Runner")
	end
	for _, id in runners do
		s.status[id] = "Active"
	end
	table.insert(events, { type = "RoundStarted", round = s.round })
	return events
end

-- The runner who chooses Hero or Chicken this round (any runner, her carrier too).
function RoundRules.pickRunner(s)
	local events = {}
	if s.over or s.picked then
		return events
	end
	local pool = {}
	for _, id in idsWithRole(s, "Runner") do
		if s.status[id] == "Active" then
			table.insert(pool, id)
		end
	end
	local id = pick(s, pool)
	if id then
		s.picked = id
		table.insert(events, { type = "Picked", id = id })
	end
	return events
end

-- The picked runner's answer (isHero nil = they ran out of time: a random pick).
function RoundRules.choose(s, id, isHero)
	local events = {}
	if s.over or s.picked ~= id or s.choice ~= nil or s.status[id] ~= "Active" then
		return events
	end
	local answered = isHero ~= nil
	if isHero == nil then
		isHero = s.random(2) == 1
	end
	s.choice = if isHero then "Hero" else "Chicken"
	s.hero = if isHero then id else nil
	if not isHero and answered then -- (a random pick for a runner who didn't answer isn't their choice)
		s.chickens[id] = true
	end
	table.insert(events, { type = "Choice", id = id, hero = isHero == true })
	return events
end

-- The Hero's solo crossing ran out of time without a result: they just run with everyone.
function RoundRules.heroTimeout(s)
	s.hero = nil
	return {}
end

function RoundRules.reachSafe(s, id)
	local events = {}
	if s.over or s.roles[id] ~= "Runner" or s.status[id] ~= "Active" then
		return events
	end
	s.status[id] = "Safe"
	table.insert(events, { type = "Safe", id = id })
	if s.hero == id then
		s.hero = nil
		s.lastHero = id
		table.insert(events, { type = "HeroResult", id = id, survived = true })
		moveGirl(s, id, "Hero", events) -- the reward: she comes down to the Hero
	end
	return events
end

-- catcherId nil = caught by the clock or by dying.
function RoundRules.tag(s, catcherId, runnerId)
	local events = {}
	if s.over or s.roles[runnerId] ~= "Runner" or s.status[runnerId] ~= "Active" then
		return events
	end
	if catcherId ~= nil and s.roles[catcherId] ~= "Catcher" then
		return events
	end
	s.status[runnerId] = "Downed"
	if catcherId then
		s.catches[catcherId] = (s.catches[catcherId] or 0) + 1
	end
	table.insert(events, { type = "Caught", id = runnerId, by = catcherId, final = s.rescued[runnerId] == true })
	if s.hero == runnerId then
		s.hero = nil
		table.insert(events, { type = "HeroResult", id = runnerId, survived = false })
	end
	if runnerId == s.holder then
		if catcherId then
			moveGirl(s, catcherId, "Stolen", events)
		else
			moveGirl(s, nil, "Dropped", events)
		end
	end
	return events
end

-- A runner still out on the field helps a downed runner up.
function RoundRules.rescue(s, rescuerId, downedId)
	local events = {}
	if s.over or rescuerId == downedId then
		return events
	end
	if s.roles[rescuerId] ~= "Runner" or s.status[rescuerId] ~= "Active" then
		return events
	end
	if s.roles[downedId] ~= "Runner" or s.status[downedId] ~= "Downed" then
		return events
	end
	if s.rescued[downedId] then
		return events -- (their second chance is used up)
	end
	s.rescued[downedId] = true
	s.status[downedId] = "Active"
	table.insert(events, { type = "Rescued", id = downedId, by = rescuerId })
	return events
end

-- Over when nobody is still out there running (the downed can't move; nobody's left to rescue them).
function RoundRules.isRoundOver(s)
	if s.over then
		return true
	end
	for _, status in s.status do
		if status == "Active" then
			return false
		end
	end
	return true
end

-- A stalled round: every runner still to cross (or only `only`, the Hero on their solo run) stands in the start
-- zone, where nobody can stab them (someone AFK, or too scared to go). RoundService then shortens the clock.
-- inStart: id -> true for the runners standing in their start zone.
function RoundRules.stalling(s, inStart, only)
	if s.over then
		return false
	end
	local any = false
	for id, status in s.status do
		if status == "Active" and (only == nil or id == only) then
			if not inStart[id] then
				return false
			end
			any = true
		end
	end
	return any
end

-- The only runner still out on the field (nil when none or several): they get a catch-up (Config Speeds.LastRunner).
function RoundRules.lastRunner(s)
	if s.over then
		return nil
	end
	local last = nil
	for id, status in s.status do
		if status == "Active" then
			if last then
				return nil
			end
			last = id
		end
	end
	return last
end

function RoundRules.endRound(s, timedOut)
	local events = {}
	if s.over then
		return events
	end
	if timedOut then
		for _, id in idsWithRole(s, "Runner") do
			if s.status[id] == "Active" then
				for _, e in RoundRules.tag(s, nil, id) do
					table.insert(events, e)
				end
			end
		end
	end
	local downed, safe = {}, 0
	for _, id in idsWithRole(s, "Runner") do
		if s.status[id] == "Safe" then
			safe += 1
		elseif s.status[id] == "Downed" then
			table.insert(downed, id)
		end
	end
	if #downed == 0 then
		s.streak += 1
		table.insert(events, { type = "Streak", count = s.streak, goal = s.goal })
	else
		local lost = s.streak
		s.streak = 0
		table.insert(events, { type = "StreakLost", count = lost })
		table.insert(events, { type = "JoinCatchers", ids = downed })
	end
	if s.streak >= s.goal then
		finish(s, "Runners", "Crossed", events)
	elseif safe == 0 then
		finish(s, "Catchers", "AllCaught", events)
	elseif s.round >= s.maxRounds then
		finish(s, "Catchers", "MaxRounds", events)
	end
	return events
end

function RoundRules.removePlayer(s, id)
	local events = {}
	if s.roles[id] == nil then
		return events
	end
	local wasCatcher = s.roles[id] == "Catcher"
	s.roles[id] = nil
	s.status[id] = nil
	s.catches[id] = nil
	if s.picked == id then
		s.picked = nil
	end
	if s.hero == id then
		s.hero = nil
	end
	if s.lastHero == id then
		s.lastHero = nil
	end
	if s.lead == id then
		s.lead = nil
	end
	if s.over or s.holder ~= id then
		return events
	end
	if wasCatcher then
		local heir = pick(s, idsWithRole(s, "Catcher"))
		moveGirl(s, heir, if heir then "Reassigned" else "Dropped", events)
	else
		moveGirl(s, nil, "Dropped", events)
	end
	return events
end

return RoundRules
