--!strict
-- +1 Chess Evolution: battle badges (chess-review style), a deterministic evaluator.
-- Fed only with the confirmed meter (server) and the fight result. Every threshold
-- is in ChessConfig.Badges. Pure: the same samples always give the same badges.
--   local ev = Badges.new(Config.Badges, fight.grace)
--   Badges.Update(ev, t, meter) -> { "Inaccuracy" }      (each server tick)
--   Badges.Finish(ev, t, "win" | "lose" | "tie") -> { "Brilliant" }

local Badges = {}

export type Evaluator = {
	cfg: any,
	grace: number,
	lastT: number,
	-- danger bands
	below: { number }, -- seconds continuously inside each band (reset above its leave line)
	shown: { boolean }, -- shown in this losing streak
	resetTimer: number,
	-- routine ratings
	windowStart: number,
	windowMeter: number?,
	routine: number,
	-- comebacks
	deficitTimer: number,
	deficitSeen: boolean,
	leadTimer: number,
	greatShown: boolean,
	dipTimer: number,
	dipSeen: boolean,
	-- miss
	behind: boolean,
	low: number,
	peak: number,
	recovering: boolean,
	missShown: boolean,
	log: { { any } },
}

function Badges.new(cfg: any, grace: number): Evaluator
	local below, shown = {}, {}
	for i in cfg.danger do
		below[i] = 0
		shown[i] = false
	end
	return {
		cfg = cfg,
		grace = grace,
		lastT = 0,
		below = below,
		shown = shown,
		resetTimer = 0,
		windowStart = grace,
		windowMeter = nil,
		routine = 0,
		deficitTimer = 0,
		deficitSeen = false,
		leadTimer = 0,
		greatShown = false,
		dipTimer = 0,
		dipSeen = false,
		behind = false,
		low = 50,
		peak = 50,
		recovering = false,
		missShown = false,
		log = {},
	}
end

local function anyShown(ev: Evaluator): boolean
	for _, s in ev.shown do
		if s then
			return true
		end
	end
	return false
end

local function emit(ev: Evaluator, out: { string }, key: string, t: number)
	table.insert(out, key)
	table.insert(ev.log, { t, key })
end

function Badges.Update(ev: Evaluator, t: number, meter: number): { string }
	local cfg = ev.cfg
	local out = {}
	local dt = math.max(0, t - ev.lastT)
	ev.lastT = t

	-- Danger bands: continuous dwell with a separate leave line (no flicker).
	for i, band in cfg.danger do
		if meter <= band.enter then
			ev.below[i] += dt
		elseif meter > band.leave then
			ev.below[i] = 0
		end
	end
	if t >= cfg.openingQuiet then
		-- Deepest qualifying band wins; shallower ones it skipped are discarded.
		for i = #cfg.danger, 1, -1 do
			-- A deeper band already counting down wins: wait for it instead.
			local deeperPending = false
			for k = i + 1, #cfg.danger do
				if ev.below[k] > 0 and not ev.shown[k] then
					deeperPending = true
				end
			end
			if ev.below[i] >= cfg.dwell and not ev.shown[i] and not deeperPending then
				for j = 1, i do
					ev.shown[j] = true
				end
				emit(ev, out, cfg.danger[i].key, t)
				break
			end
		end
	end
	-- A sustained recovery near the midpoint resets the warning sequence.
	if meter >= cfg.resetAt then
		ev.resetTimer += dt
		if ev.resetTimer >= cfg.resetDwell and anyShown(ev) then
			for i in ev.shown do
				ev.shown[i] = false
			end
		end
	else
		ev.resetTimer = 0
	end

	-- Comebacks.
	if meter <= cfg.greatDeficit then
		ev.deficitTimer += dt
		if ev.deficitTimer >= cfg.dwell then
			ev.deficitSeen = true
		end
	else
		ev.deficitTimer = 0
	end
	if meter <= cfg.brilliantDip then
		ev.dipTimer += dt
		if ev.dipTimer >= cfg.dwell then
			ev.dipSeen = true
		end
	else
		ev.dipTimer = 0
	end
	if meter >= cfg.greatLead then
		ev.leadTimer += dt
		if ev.leadTimer >= cfg.dwell and ev.deficitSeen and not ev.greatShown then
			ev.greatShown = true
			emit(ev, out, "Great", t)
		end
	else
		ev.leadTimer = 0
	end

	-- Miss: a real recovery from behind, then losing it before taking the lead.
	if not ev.behind then
		if ev.below[1] >= cfg.dwell then
			ev.behind = true
			ev.low, ev.peak, ev.recovering = meter, meter, false
		end
	else
		if meter > 50 then
			ev.behind, ev.recovering = false, false
			if not anyShown(ev) then
				ev.missShown = false
			end
		elseif not ev.recovering then
			ev.low = math.min(ev.low, meter)
			if meter >= ev.low + cfg.missRecover then
				ev.recovering, ev.peak = true, meter
			end
		else
			ev.peak = math.max(ev.peak, meter)
			if meter <= ev.peak - cfg.missDrop and not ev.missShown then
				ev.missShown = true
				emit(ev, out, "Miss", t)
				ev.recovering, ev.low = false, meter
			end
		end
	end

	-- Routine ratings over coarse windows (only while not in danger).
	if t >= ev.grace then
		if ev.windowMeter == nil then
			ev.windowStart, ev.windowMeter = t, meter
		elseif t - ev.windowStart >= cfg.window then
			local gain = meter - (ev.windowMeter :: number)
			ev.windowStart, ev.windowMeter = t, meter
			if ev.routine < cfg.routineCap and meter > cfg.danger[1].leave and #out == 0 then
				local key = if gain >= cfg.best then "Best" elseif gain >= cfg.excellent then "Excellent" elseif gain >= cfg.good then "Good" else nil
				if key then
					ev.routine += 1
					emit(ev, out, key, t)
				end
			end
		end
	end
	return out
end

function Badges.Finish(ev: Evaluator, t: number, outcome: string): { string }
	local out = {}
	if outcome == "win" then
		if ev.dipSeen then
			emit(ev, out, "Brilliant", t)
		end
	elseif outcome == "lose" then
		local deepest = #ev.cfg.danger
		if not ev.shown[deepest] then
			emit(ev, out, ev.cfg.danger[deepest].key, t)
		end
	end
	return out
end

-- Runs a scripted meter path through the evaluator (tests and the preview).
-- samples = { { t, meter } ... }; returns the badge log { { t, key } ... }.
function Badges.Run(cfg: any, grace: number, samples: { { number } }, outcome: string?): { { any } }
	local ev = Badges.new(cfg, grace)
	local lastT = 0
	for _, s in samples do
		Badges.Update(ev, s[1], s[2])
		lastT = s[1]
	end
	if outcome then
		Badges.Finish(ev, lastT, outcome)
	end
	return ev.log
end

return Badges
