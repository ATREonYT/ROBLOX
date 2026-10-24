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
	  - Last runner standing (owner, Oct 19: "make the round not be capped at 3, but go on until there is one
	    person left in the runners and he wins the game and wins the girl"): rounds go on, anyone caught joins
	    the catchers, and when a round ends with exactly one runner left (of a game that started with 2+),
	    that runner wins the game and the girl ("LastStanding"), wherever she was. Catchers win when no
	    runners are left. A game that started with ONE runner (practice with the bot) still ends after
	    `crossings` (3) clean rounds in a row. maxRounds is only a safety net: the runners left win then.
	The girl (floats over the map until someone wins her over):
	  - A Hero who survives the solo crossing gets her: she comes down onto their shoulders (from the sky,
	    or from the catcher who stole her).
	  - No Hero won her this round (Chicken, or the Hero failed) and she's still floating: the first runner
	    across takes her ("First"), whoever chose Chicken included.
	  - A catcher who catches her carrier while runners are left keeps her (she follows him) only until the next
	    runner makes it across: that runner takes her back ("Reclaimed"; owner, Oct 19: "if the catcher gets the
	    girl and there are still runners left the catcher keeps the girl until the next runner makes it to the
	    safe zone").
	  - A catcher wins her only by catching the LAST runner (owner, Oct 19: "the girl will be recieved by the
	    catcher only if at the end he catches the last runner"): when the catchers win (everyone caught), she goes
	    to the catcher who made the final catch. If the clock caught the last runner, the catcher holding her keeps
	    her, else the catcher with the most catches (the lead catcher wins a tie).
	  - When the runners win she goes to the runner holding her; if nobody does, the runners' last successful
	    Hero (else a random runner who made it). The last runner standing always wins her.
	  - Everyone caught turns into a catcher (owner, Oct 19: "every person who got caught turns into a catcher"):
	    from the next round, so a round stays readable; a rescue in the same round still saves them.
	  - Chicken still wins her (owner, Oct 19: "fix the users not getting the girl if they win on the chicken
	    round ... make them get her"; this replaces Oct 18's "you dont recieve the girl if you run chicken"):
	    choosing Chicken never takes away the claim. The Hero's edge is getting her first, alone, plus the
	    Hero bonus. s.chickens still records who chose Chicken (Results text), it no longer blocks her.

	Runner status during a round: "Active" (still to cross) | "Safe" (across) | "Downed" (stabbed).
	Every function returns a list of events:
	  {type="RoundStarted", round}            {type="NewCatcher", id}       {type="JoinCatchers", ids}
	  {type="Picked", id}                     {type="Choice", id, hero}     {type="HeroResult", id, survived}
	  {type="Safe", id}                       {type="Caught", id, by}       {type="Rescued", id, by}
	  {type="Streak", count, goal}            {type="StreakLost", count}
	  {type="GirlMoved", from, to, reason}    (reason: "Hero" | "First" | "Stolen" | "Reclaimed" | "Last" | "Dropped" | "Reassigned")
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
RoundRules.idsWithRole = idsWithRole

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
	if team == "Catchers" and s.lastCatchBy and s.roles[s.lastCatchBy] == "Catcher" then
		return s.lastCatchBy -- (he caught the last runner)
	end
	if s.holder and s.roles[s.holder] == role then
		return s.holder
	end
	if team == "Runners" then
		if s.lastHero and s.roles[s.lastHero] == "Runner" then
			return s.lastHero
		end
		local made, all = {}, {}
		for _, id in idsWithRole(s, "Runner") do
			table.insert(all, id)
			if s.status[id] == "Safe" then
				table.insert(made, id)
			end
		end
		return pick(s, if #made > 0 then made else all)
	end
	-- the catcher with the most catches; the lead catcher only breaks a tie (loop audit: the lead took her with 0)
	local best, most = nil, -1
	for _, id in idsWithRole(s, "Catcher") do
		local n = s.catches[id] or 0
		if n > most or (n == most and id == s.lead) then
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
	s.winner = if reason == "Forfeit" then nil else girlWinner(s, team) -- (Forfeit: nobody wins her)
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
		lastCatchBy = nil, -- who made the latest catch (nil: the clock): the catchers' winner gets her
		chickens = {}, -- runners who chose Chicken this game and never went Hero (they can't be handed the girl)
		brave = {}, -- runners who went Hero this game
		streak = 0, -- full crossings in a row (the win only for a game that started with one runner)
		startRunners = nil, -- runners when round 1 started
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
	if s.round == 1 then
		s.startRunners = #runners -- (2+ = last runner standing wins; 1 = practice, 3 clean rounds)
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
	if isHero then
		s.brave[id] = true
		s.chickens[id] = nil -- (going Hero once wins back the right to her)
	elseif answered and not s.brave[id] then -- (a random pick for a runner who didn't answer isn't their choice)
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
	elseif s.holder ~= nil and s.roles[s.holder] == "Catcher" then
		moveGirl(s, id, "Reclaimed", events) -- the next runner across takes her back from the catcher
	elseif s.holder == nil and s.hero == nil and (s.choice ~= nil or s.picked == nil) then -- (picked == nil: the picked runner left before choosing, release check Oct 22)
		-- No Hero run won her (Chicken, or the Hero was caught or ran out of time): the first runner across takes
		-- her (owner, Oct 18: "if you go chicken, still the first person to reach the safe zone gets the girl"),
		-- the one who chose Chicken too (owner, Oct 19: "make them get her").
		moveGirl(s, id, "First", events)
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
	s.lastCatchBy = catcherId
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

-- How much faster everyone in the game runs in round `round` (owner, Oct 19: "speed goes up every round a very tiny
-- bit"): 1 in round 1, then +perRound a round, never more than 1 + max. cfg = Config/Round.SpeedUp.
function RoundRules.speedScale(round: number?, cfg): number
	if not cfg or type(round) ~= "number" or round <= 1 then
		return 1
	end
	return 1 + math.min((round - 1) * (cfg.PerRound or 0), cfg.Max or 0)
end

-- Does an Active runner's death (a reset, a fall off the map) count as being caught? Only while they could be
-- caught: in Running, or in the Hero's solo run for whoever isn't held on the line (the Hero, never the runners
-- waiting). Before that (Lineup, Picking, Countdown) the new body just goes back to its line spot (bug hunt, Oct 20).
function RoundRules.deathCounts(stage: string?, frozen: boolean): boolean
	return stage == "Running" or (stage == "HeroRun" and not frozen)
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
	local caughtAny = false
	for _, n in s.catches do
		if n > 0 then caughtAny = true end
	end
	if safe == 0 and #downed == 0 and not caughtAny then
		-- every runner left and nobody was ever caught (release check, Oct 22: the catcher took the girl and a full
		-- win for nothing; a second account could farm it): the game ends, nobody wins her or the pay
		finish(s, "Catchers", "Forfeit", events)
	elseif safe == 0 then
		finish(s, "Catchers", "AllCaught", events)
	elseif (s.startRunners or 0) >= 2 and safe == 1 then
		local last = nil
		for _, id in idsWithRole(s, "Runner") do
			if s.status[id] == "Safe" then
				last = id
			end
		end
		moveGirl(s, last, "Last", events) -- the last runner standing wins her, wherever she was
		finish(s, "Runners", "LastStanding", events)
	elseif (s.startRunners or 0) < 2 and s.streak >= s.goal then
		finish(s, "Runners", "Crossed", events)
	elseif s.round >= s.maxRounds then
		finish(s, "Runners", "MaxRounds", events)
	end
	return events
end

function RoundRules.removePlayer(s, id)
	local events = {}
	if s.roles[id] == nil then
		return events
	end
	local wasCatcher = s.roles[id] == "Catcher"
	if s.roles[id] == "Runner" and s.status[id] == "Active" then
		s.lastCatchBy = nil -- (a runner still out there left: nobody caught the last one)
	end
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
	if s.lastCatchBy == id then
		s.lastCatchBy = nil
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

-- The huss cut-off (owner, Oct 24: "if you huss infront of someone they go from 1x-0.75x speed"): whether a huss
-- from `from` along the flat unit `dir` for `dist` studs crosses in front of someone standing at `at` facing the flat
-- unit `look`: some point of the path is between 0 and cut.Ahead studs ahead of them and at most cut.Side studs to
-- their side. Anything with .X and .Z works (Vector3s in the game).
function RoundRules.cutsOff(from: any, dir: any, dist: number, at: any, look: any, cut: { Ahead: number, Side: number }): boolean
	local steps = math.max(1, math.ceil(dist / 1.5))
	for i = 0, steps do
		local k = dist * i / steps
		local rx, rz = from.X + dir.X * k - at.X, from.Z + dir.Z * k - at.Z
		local ahead = rx * look.X + rz * look.Z
		local side = math.abs(rx * look.Z - rz * look.X)
		if ahead > 0 and ahead <= cut.Ahead and side <= cut.Side then
			return true
		end
	end
	return false
end

return RoundRules
