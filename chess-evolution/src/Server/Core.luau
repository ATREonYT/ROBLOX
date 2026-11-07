--!strict
-- +1 Chess Evolution: the server rules, pure (no Roblox services), so tools/test.luau proves them.
-- Game.luau wires these to remotes, characters and saves. The server owns every number here.

local Core = {}

local function requireShared(name: string): any
	-- Studio/Rojo: ReplicatedStorage.Kit.<name>; Lune tests: inject via Core.Inject.
	return require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Kit"):WaitForChild(name))
end

local Battle: any, Badges: any
function Core.Inject(battle: any, badges: any)
	Battle, Badges = battle, badges
end

export type Session = {
	station: string?, -- training on this station (ends when the player leaves the deck)
	battle: any?,
	tokens: number,
	tokensAt: number,
	lastStage: string?,
	lastStation: string?,
}

function Core.new(config: any, clock: () -> number)
	if not Battle then
		local ok = pcall(function()
			Battle, Badges = requireShared("Battle"), requireShared("Badges")
		end)
		assert(ok, "Core: Battle/Badges modules not found (call Core.Inject in tests)")
	end
	return { cfg = config, clock = clock, nextId = 0 }
end

function Core.NewData(config: any): { [string]: any }
	return {
		Wins = 0,
		Power = 0,
		Sets = { [config.DefaultSet] = true },
		Equipped = config.DefaultSet,
		Cleared = {},
		BookShown = false,
		Guide = 1,
		Stats = { Taps = 0, Battles = 0, Victories = 0 },
	}
end

function Core.NewSession(): Session
	return { station = nil, battle = nil, tokens = -1, tokensAt = 0, lastStage = nil, lastStation = nil }
end

-- Unlock rules ---------------------------------------------------------------
function Core.StationOpen(cfg: any, data: any, id: string): (boolean, string?)
	local station = cfg.Stations[id]
	if not station then
		return false, "Unknown"
	end
	if not station.built then
		return false, "ComingSoon"
	end
	if station.unlock and station.unlock.stage and not data.Cleared[station.unlock.stage] then
		return false, "Locked"
	end
	return true, nil
end

function Core.StageOpen(cfg: any, data: any, id: string): (boolean, string?)
	if not cfg.Stages[id] then
		return false, "Unknown"
	end
	local prev = cfg.PreviousStage(id)
	if prev and not data.Cleared[prev] then
		return false, "Locked"
	end
	return true, nil
end

-- Token bucket: ~tapsPerSecond accepted, small burst for jitter.
local function takeToken(core: any, s: Session): boolean
	local input = core.cfg.Input
	local now = core.clock()
	if s.tokens < 0 then
		s.tokens, s.tokensAt = input.tapBurst, now
	end
	s.tokens = math.min(input.tapBurst, s.tokens + (now - s.tokensAt) * input.tapsPerSecond)
	s.tokensAt = now
	if s.tokens < 1 then
		return false
	end
	s.tokens -= 1
	return true
end

-- One tap of the main button. ctx = { kind = "train", station } | { kind = "battle", battle }.
-- isNear(kind, id) checks the character against the zone (server side).
-- Returns ok, amount (power gained / meter pushed) or a reason code.
function Core.Tap(core: any, data: any, s: Session, ctx: any, isNear: (string, string) -> boolean): (boolean, any)
	local cfg = core.cfg
	if ctx.kind == "battle" then
		local battle = s.battle
		if not battle or battle.id ~= ctx.battle or battle.state.done then
			return false, "Stale"
		end
		if not takeToken(core, s) then
			return false, "TooFast"
		end
		Battle.Tap(battle.state)
		battle.taps += 1
		return true, battle.state.fight.perTap
	elseif ctx.kind == "train" then
		local id = ctx.station
		if s.battle then
			return false, "Busy"
		end
		local open, why = Core.StationOpen(cfg, data, id)
		if not open then
			return false, why
		end
		if not isNear("station", id) then
			return false, "TooFar"
		end
		if not takeToken(core, s) then
			return false, "TooFast"
		end
		local gain = cfg.Gain(id, data.Equipped)
		data.Power += gain
		data.Stats.Taps += 1
		s.station, s.lastStation = id, id
		return true, gain
	end
	return false, "Invalid"
end

function Core.Challenge(core: any, data: any, s: Session, stageId: string, isNear: (string, string) -> boolean): (boolean, any)
	local cfg = core.cfg
	local stage = cfg.Stages[stageId]
	if not stage then
		return false, "Unknown"
	end
	if s.battle then
		return false, "Busy"
	end
	local open, why = Core.StageOpen(cfg, data, stageId)
	if not open then
		return false, why
	end
	if not isNear("stage", stageId) then
		return false, "TooFar"
	end
	if data.Power < stage.power then
		return false, "NeedPower"
	end
	core.nextId += 1
	local battle = {
		id = `{stageId}-{core.nextId}`,
		stage = stageId,
		state = Battle.new(stage.fight),
		ev = Badges.new(cfg.Badges, stage.fight.grace),
		taps = 0,
		book = not data.BookShown,
		firstClear = not data.Cleared[stageId],
	}
	data.BookShown = true
	data.Stats.Battles += 1
	s.battle = battle
	s.station = nil
	s.lastStage = stageId
	return true, battle
end

-- Advances the active battle. Returns (result?, newBadges).
function Core.StepBattle(core: any, data: any, s: Session, dt: number): (any?, { string })
	local battle = s.battle
	if not battle then
		return nil, {}
	end
	local state = battle.state
	Battle.Step(state, dt)
	local badges = Badges.Update(battle.ev, state.t, state.meter)
	if not state.done then
		return nil, badges
	end
	for _, key in Badges.Finish(battle.ev, state.t, state.outcome) do
		table.insert(badges, key)
	end
	local cfg = core.cfg
	local stage = cfg.Stages[battle.stage]
	local result = { id = battle.id, stage = battle.stage, outcome = state.outcome, reward = 0, unlocked = nil, t = state.t }
	if state.outcome == "win" then
		data.Stats.Victories += 1
		if not data.Cleared[battle.stage] then
			-- First clear: granted exactly once (the flag is written in the same step).
			data.Cleared[battle.stage] = true
			data.Wins += stage.reward
			result.reward = stage.reward
			result.unlocked = stage.unlocks
		end
	end
	s.battle = nil
	return result, badges
end

function Core.Buy(core: any, data: any, setId: string): (boolean, string?)
	local set = core.cfg.Sets[setId]
	if not set then
		return false, "Unknown"
	end
	if not set.available then
		return false, "ComingSoon"
	end
	if data.Sets[setId] then
		return false, "Owned"
	end
	if data.Wins < set.price then
		return false, "NeedWins"
	end
	data.Wins -= set.price
	data.Sets[setId] = true
	return true, nil
end

function Core.Equip(core: any, data: any, setId: string): (boolean, string?)
	if not core.cfg.Sets[setId] then
		return false, "Unknown"
	end
	if not data.Sets[setId] then
		return false, "NotOwned"
	end
	data.Equipped = setId
	return true, nil
end

-- Ends training and any battle (left the deck, died, reset, left the game).
function Core.Leave(_core: any, s: Session, _reason: string): { station: string?, battle: string? }
	local cleared = { station = s.station, battle = if s.battle then s.battle.id else nil }
	s.station = nil
	s.battle = nil
	return cleared
end

return Core
