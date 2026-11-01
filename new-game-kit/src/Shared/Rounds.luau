--!strict
-- New Game Kit: Rounds (vault note 32 Round-Based Games). A pure state machine for any game that
-- plays in rounds: party minigames, tag and hide-and-seek, murder-mystery style, horror-lite runs,
-- obby races, arena fights. The server ticks it; it never touches Instances, so it runs offline.
--
--   local r = Rounds.new({ minPlayers = 2, intermission = 15, countdown = 5, roundLength = 120 })
--   r:Join(userId) / r:Leave(userId)          -- queue changes (also use Leave on PlayerRemoving)
--   r:Eliminate(userId, round?)                -- out of this round (caught, fell, tagged)
--   r:Revive(userId, round?)                   -- back in (unfrozen by a friend); only someone who started
--   r:End(now, round?)                         -- the game logic ends the round (all frozen, the goal reached)
--   local events = r:Tick(now)                 -- advance; returns a list of what happened
--   r.state, r.round, r.alive, r:TimeLeft(now)
-- States: "Waiting" (not enough players) -> "Intermission" -> "Countdown" -> "Playing" -> "Results"
-- -> "Intermission"... Every round has an id (`r.round`). Capture it when you start a timer or a
-- delayed elimination, and pass it to Eliminate / Revive / End: a stale id is ignored, so a timer from an
-- old round can't end or change a new one. Players eliminated this round can't re-Join it.
-- Rewards: Results lists who survived; rounds shorter than `minPaidSeconds` or with fewer than
-- `minPlayers` at the start pay nothing (stops alt-account farming).
-- Status: covered by tests/Rounds.spec.luau (offline).

local Rounds = {}
Rounds.__index = Rounds

export type Config = {
	minPlayers: number?, -- default 2
	intermission: number?, -- seconds in the lobby between rounds (default 15)
	countdown: number?, -- "3, 2, 1" before play (default 5)
	roundLength: number?, -- default 120
	results: number?, -- seconds to show the winners (default 6)
	joinInProgress: number?, -- late joiners may enter during the first N s of a round (default 0)
	minPaidSeconds: number?, -- default 20
	endWhenAlive: number?, -- end early when this many or fewer are left (default 1; 0 = never)
}

export type Event = { kind: string, round: number, players: { number }? }

export type RoundState = typeof(setmetatable(
	{} :: {
		cfg: Config,
		state: string,
		round: number,
		since: number,
		queue: { [number]: boolean },
		alive: { [number]: boolean },
		starters: { [number]: boolean },
		startedWith: number,
	},
	Rounds
))

local function count(t: { [number]: boolean }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function list(t: { [number]: boolean }): { number }
	local out = {}
	for id in t do
		table.insert(out, id)
	end
	table.sort(out)
	return out
end

function Rounds.new(cfg: Config): RoundState
	return setmetatable({
		cfg = cfg,
		state = "Waiting",
		round = 0,
		since = 0,
		queue = {},
		alive = {},
		starters = {},
		startedWith = 0,
	}, Rounds)
end

function Rounds.Join(self: RoundState, userId: number, now: number?): boolean
	self.queue[userId] = true
	-- Late join into a running round, only in its first seconds.
	local grace = self.cfg.joinInProgress or 0
	-- Nobody who was already in this round (and got caught) can come back by pressing Play again.
	if self.state == "Playing" and now and now - self.since <= grace and not self.starters[userId] then
		self.starters[userId] = true
		self.alive[userId] = true
		return true
	end
	return false
end

function Rounds.Leave(self: RoundState, userId: number)
	self.queue[userId] = nil
	self.alive[userId] = nil
end

local function current(self: RoundState, round: number?): boolean
	return self.state == "Playing" and (round == nil or round == self.round)
end

function Rounds.Eliminate(self: RoundState, userId: number, round: number?): boolean
	if not current(self, round) or not self.alive[userId] then
		return false
	end
	self.alive[userId] = nil
	return true
end

-- Back into the round (freeze tag's unfreeze). Only players who were in this round, and still queued.
function Rounds.Revive(self: RoundState, userId: number, round: number?): boolean
	if not current(self, round) or self.alive[userId] or not self.starters[userId] or not self.queue[userId] then
		return false
	end
	self.alive[userId] = true
	return true
end

-- The game logic ends the round (everyone frozen, the goal reached, "it" left). Same pay rule as Tick.
function Rounds.End(self: RoundState, now: number, round: number?): { Event }
	if not current(self, round) then
		return {}
	end
	local c = self.cfg
	local paid = now - self.since >= (c.minPaidSeconds or 20) and self.startedWith >= (c.minPlayers or 2)
	self.state, self.since = "Results", now
	return { { kind = if paid then "Ended" else "EndedUnpaid", round = self.round, players = list(self.alive) } }
end

function Rounds.TimeLeft(self: RoundState, now: number): number
	local c = self.cfg
	local length = if self.state == "Intermission"
		then c.intermission or 15
		elseif self.state == "Countdown" then c.countdown or 5
		elseif self.state == "Playing" then c.roundLength or 120
		elseif self.state == "Results" then c.results or 6
		else 0
	return math.max(0, length - (now - self.since))
end

function Rounds.Tick(self: RoundState, now: number): { Event }
	local c = self.cfg
	local events: { Event } = {}
	local minPlayers = c.minPlayers or 2
	local function go(state: string, kind: string, players: { number }?)
		self.state, self.since = state, now
		table.insert(events, { kind = kind, round = self.round, players = players })
	end

	local queued = count(self.queue)
	if self.state == "Waiting" then
		if queued >= minPlayers then
			go("Intermission", "Intermission")
		end
	elseif self.state == "Intermission" or self.state == "Countdown" then
		if queued < minPlayers then
			go("Waiting", "Cancelled") -- someone left during the lobby: never start a one-player round
		elseif self:TimeLeft(now) <= 0 then
			if self.state == "Intermission" then
				go("Countdown", "Countdown")
			else
				self.round += 1
				self.alive = table.clone(self.queue)
				self.starters = table.clone(self.queue)
				self.startedWith = queued
				go("Playing", "Started", list(self.alive))
			end
		end
	elseif self.state == "Playing" then
		local left = count(self.alive)
		local stopAt = c.endWhenAlive or 1
		if self:TimeLeft(now) <= 0 or (stopAt > 0 and left <= stopAt) then
			local played = now - self.since
			local paid = played >= (c.minPaidSeconds or 20) and self.startedWith >= minPlayers
			go("Results", if paid then "Ended" else "EndedUnpaid", list(self.alive))
		end
	elseif self.state == "Results" then
		if self:TimeLeft(now) <= 0 then
			self.alive = {}
			self.starters = {}
			if queued >= minPlayers then
				go("Intermission", "Intermission")
			else
				go("Waiting", "Waiting")
			end
		end
	end
	return events
end

return Rounds
