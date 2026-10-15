--[[
	The game's rules as a pure state machine (no Roblox calls), so every case
	is unit tested in tests/RoundRules.spec.luau. RoundService feeds it what
	happens in the world and acts on the events it returns.

	Players are ids (UserIds). Roles: "Runner" | "Catcher".
	Runner status during a round: "Active" | "Safe" | "Caught".

	Phases of the girl:
	  Open      - nobody or a runner holds her. With pickup "Middle" (default) she
	              waits in the middle and the first runner to reach her grabs her;
	              with pickup "SafeZone" the first runner across each round takes
	              her. A catcher who tags her holder steals her.
	  Stolen    - a catcher (the thief) holds her. The first runner across
	              rescues her, and the next round is the final round.
	  FinalNext - rescued this round; turns into Final when the next round starts.
	  Final     - her holder must cross once more: across = he wins her,
	              caught = the catcher who tagged him wins her.
	A round where her holder is the only runner left is also Final.
	When no runners are left, whoever holds her wins her.

	Every function returns a list of events:
	  {type="RoundStarted", round}       {type="FinalRound", runner}
	  {type="NewCatcher", id}            {type="Safe", id}
	  {type="Caught", id, by}            {type="GirlMoved", from, to, reason}
	  {type="Win", winner, reason}       (winner may be nil: nobody gets her)
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

local function finish(s, winner, reason, events)
	if s.over then
		return
	end
	s.over = true
	s.winner = winner
	s.reason = reason
	table.insert(events, { type = "Win", winner = winner, reason = reason })
end

local function moveGirl(s, to, reason, events)
	local from = s.holder
	s.holder = to
	table.insert(events, { type = "GirlMoved", from = from, to = to, reason = reason })
end

-- opts: { random = function(n) -> 1..n, maxRounds = number, pickup = "Middle" | "SafeZone" }
function RoundRules.newGame(ids, catcherId, opts)
	opts = opts or {}
	local s = {
		round = 0,
		phase = "Open",
		holder = nil,
		thief = nil,
		roles = {},
		status = {},
		firstSafe = nil,
		over = false,
		winner = nil,
		reason = nil,
		maxRounds = opts.maxRounds or math.huge,
		pickup = opts.pickup or "Middle",
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
	-- Runners who didn't make it across last round catch from now on.
	if s.round > 0 then
		for id, role in s.roles do
			if role == "Runner" and s.status[id] ~= "Safe" then
				s.roles[id] = "Catcher"
			end
		end
	end
	s.round += 1
	s.firstSafe = nil
	s.status = {}

	local runners = idsWithRole(s, "Runner")
	if #runners == 0 then
		finish(s, s.holder, "AllCaught", events)
		return events
	end
	-- Every catcher left: a runner (not her holder) takes over.
	if #runners >= 2 and #idsWithRole(s, "Catcher") == 0 then
		local pool = {}
		for _, id in runners do
			if id ~= s.holder then
				table.insert(pool, id)
			end
		end
		local id = pick(s, pool)
		s.roles[id] = "Catcher"
		table.insert(events, { type = "NewCatcher", id = id })
		runners = idsWithRole(s, "Runner")
	end
	for _, id in runners do
		s.status[id] = "Active"
	end

	if s.phase == "FinalNext" then
		s.phase = "Final"
	elseif s.phase == "Open" and s.holder ~= nil and #runners == 1 and runners[1] == s.holder then
		s.phase = "Final"
	end
	table.insert(events, { type = "RoundStarted", round = s.round })
	if s.phase == "Final" then
		table.insert(events, { type = "FinalRound", runner = s.holder })
	end
	return events
end

function RoundRules.reachSafe(s, id)
	local events = {}
	if s.over or s.roles[id] ~= "Runner" or s.status[id] ~= "Active" then
		return events
	end
	s.status[id] = "Safe"
	table.insert(events, { type = "Safe", id = id })

	if s.phase == "Final" then
		if id == s.holder then
			finish(s, id, "Crossed", events)
		end
	elseif s.firstSafe == nil then
		s.firstSafe = id
		if s.phase == "Open" then
			if s.pickup == "SafeZone" and s.holder ~= id then
				moveGirl(s, id, "FirstAcross", events)
			end
		elseif s.phase == "Stolen" then
			moveGirl(s, id, "Rescued", events)
			s.phase = "FinalNext"
		end
	end
	return events
end

-- A runner reached her where she waits (pickup "Middle").
function RoundRules.grab(s, id)
	local events = {}
	if s.over or s.pickup ~= "Middle" or s.phase ~= "Open" or s.holder ~= nil then
		return events
	end
	if s.roles[id] ~= "Runner" or s.status[id] ~= "Active" then
		return events
	end
	moveGirl(s, id, "Grabbed", events)
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
	s.status[runnerId] = "Caught"
	table.insert(events, { type = "Caught", id = runnerId, by = catcherId })

	if runnerId == s.holder then
		if s.phase == "Final" then
			finish(s, catcherId or s.thief or pick(s, idsWithRole(s, "Catcher")), "Caught", events)
		elseif catcherId ~= nil then
			moveGirl(s, catcherId, "Stolen", events)
			s.phase = "Stolen"
			s.thief = catcherId
		else
			moveGirl(s, nil, "Dropped", events)
		end
	end
	return events
end

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
		if s.over then
			return events
		end
	end
	local safe = 0
	for _, status in s.status do
		if status == "Safe" then
			safe += 1
		end
	end
	if safe == 0 then
		finish(s, s.holder, "AllCaught", events)
	elseif s.round >= s.maxRounds then
		finish(s, s.holder, "MaxRounds", events)
	end
	return events
end

function RoundRules.removePlayer(s, id)
	local events = {}
	if s.roles[id] == nil then
		return events
	end
	s.roles[id] = nil
	s.status[id] = nil
	if s.thief == id then
		s.thief = nil
	end
	if s.over or s.holder ~= id then
		return events
	end
	if s.phase == "Final" or s.phase == "FinalNext" then
		s.holder = nil
		finish(s, s.thief or pick(s, idsWithRole(s, "Catcher")), "HolderLeft", events)
	elseif s.phase == "Stolen" then
		local heir = pick(s, idsWithRole(s, "Catcher"))
		moveGirl(s, heir, "Reassigned", events)
		s.thief = heir
		if heir == nil then
			s.phase = "Open"
		end
	else
		moveGirl(s, nil, "Dropped", events)
	end
	return events
end

return RoundRules
