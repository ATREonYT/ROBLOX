--!strict
-- +1 Chess Evolution: the battle meter (pure; used by the server, the tests and the badge preview).
-- 50 at the start. Taps push toward 100 (win), rival pressure pushes toward 0 (loss).
-- At timeout the side above 50 wins; exactly 50 is a tie (free retry).

local Battle = {}

export type Fight = { perTap: number, grace: number, timeout: number, phases: { { untilT: number, perSecond: number } } }
export type State = { fight: Fight, meter: number, t: number, done: boolean, outcome: string?, taps: number }

local function pressure(fight: Fight, t: number): number
	if t < fight.grace then
		return 0
	end
	for _, phase in fight.phases do
		if t < phase.untilT then
			return phase.perSecond
		end
	end
	return fight.phases[#fight.phases].perSecond
end
Battle.Pressure = pressure

function Battle.new(fight: Fight): State
	return { fight = fight, meter = 50, t = 0, done = false, outcome = nil, taps = 0 }
end

local function settle(state: State)
	if state.meter >= 100 then
		state.meter = 100
		state.done, state.outcome = true, "win"
	elseif state.meter <= 0 then
		state.meter = 0
		state.done, state.outcome = true, "lose"
	end
end

-- One accepted tap. Returns true when it changed the meter.
function Battle.Tap(state: State): boolean
	if state.done then
		return false
	end
	state.taps += 1
	state.meter += state.fight.perTap
	settle(state)
	return true
end

-- Advance time. Splits dt so a phase boundary is integrated exactly.
function Battle.Step(state: State, dt: number)
	if state.done or dt <= 0 then
		return
	end
	local fight = state.fight
	local remaining = math.min(dt, fight.timeout - state.t)
	while remaining > 1e-9 and not state.done do
		local t = state.t
		local nextEdge = fight.timeout
		if t < fight.grace then
			nextEdge = fight.grace
		else
			for _, phase in fight.phases do
				if t < phase.untilT then
					nextEdge = math.min(phase.untilT, fight.timeout)
					break
				end
			end
		end
		local slice = math.min(remaining, math.max(nextEdge - t, 1e-6))
		state.meter -= pressure(fight, t) * slice
		state.t = t + slice
		remaining -= slice
		settle(state)
	end
	if not state.done and state.t >= fight.timeout - 1e-9 then
		state.done = true
		if math.abs(state.meter - 50) < 1e-6 then
			state.outcome = "tie"
		elseif state.meter > 50 then
			state.outcome = "win"
		else
			state.outcome = "lose"
		end
	end
end

-- Simulates a whole fight with taps at a steady rate (0 = idle). For tests and tuning.
function Battle.Simulate(fight: Fight, tapsPerSecond: number, dt: number?): (State, { { number } })
	local step = dt or 0.05
	local state = Battle.new(fight)
	local samples = {}
	local nextTap = if tapsPerSecond > 0 then 1 / tapsPerSecond else math.huge
	while not state.done do
		Battle.Step(state, step)
		while not state.done and state.t >= nextTap do
			Battle.Tap(state)
			nextTap += 1 / tapsPerSecond
		end
		table.insert(samples, { state.t, state.meter })
	end
	return state, samples
end

return Battle
