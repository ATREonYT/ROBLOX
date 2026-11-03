--!strict
-- Pure maths for the day-night cycle (no Instances; unit-tested in tools/tests/test_daynight_rules.py).
-- "Position" = real seconds into the cycle, 0 = the start of the first phase (Morning). The clock runs at a
-- different speed in each phase (Config/DayNight.Phases), so position <-> clock is piecewise linear.
local DayNight = require(script.Parent.Parent.Config.DayNight)

local DayNightRules = {}

local function wrap24(h: number): number
	return h % 24
end

function DayNightRules.cycleSeconds(phases: any?): number
	local total = 0
	for _, p in phases or DayNight.Phases do
		total += p.minutes * 60
	end
	return total
end

-- clock hour (0-24) at `pos` real seconds into the cycle
function DayNightRules.clockAt(pos: number, phases: any?): number
	local list = phases or DayNight.Phases
	local total = DayNightRules.cycleSeconds(list)
	local t = pos % total
	for _, p in list do
		local len = p.minutes * 60
		if t < len then
			return wrap24(p.from + (p.to - p.from) * (t / len))
		end
		t -= len
	end
	return wrap24(list[1].from)
end

-- inverse: real seconds into the cycle for a clock hour (used to jump the clock: debug, server start)
function DayNightRules.positionFor(clock: number, phases: any?): number
	local list = phases or DayNight.Phases
	local h = wrap24(clock)
	local start = 0
	for _, p in list do
		local len = p.minutes * 60
		-- the phase's range, unwrapped so it can cross midnight (Night: 19.6 -> 29.6)
		local hh = h
		if hh < p.from then
			hh += 24
		end
		if hh >= p.from and hh < p.to then
			return start + len * (hh - p.from) / (p.to - p.from)
		end
		start += len
	end
	return 0
end

function DayNightRules.phaseOf(clock: number, phases: any?): string
	local list = phases or DayNight.Phases
	local h = wrap24(clock)
	for _, p in list do
		local hh = h
		if hh < p.from then
			hh += 24
		end
		if hh >= p.from and hh < p.to then
			return p.id
		end
	end
	return list[1].id
end

local function smooth(x: number): number
	return x * x * (3 - 2 * x)
end

-- the two keys around `clock` and the eased blend between them: (keyA, keyB, alpha 0..1)
function DayNightRules.sample(clock: number, keys: any?): (any, any, number)
	local list = keys or DayNight.Keys
	local h = wrap24(clock)
	local n = #list
	for i = 1, n do
		local a = list[i]
		local b = list[i + 1]
		local bAt = if b then b.at else list[1].at + 24
		if not b then
			b = list[1]
		end
		if h >= a.at and h < bAt then
			return a, b, smooth((h - a.at) / (bAt - a.at))
		end
	end
	-- before the first key (only if the first key isn't at 0): blend from the last key across midnight
	local last = list[n]
	local first = list[1]
	local span = first.at + 24 - last.at
	return last, first, smooth((h + 24 - last.at) / span)
end

-- shortest way round the clock from `from` to `to` (hours, -12..12) for blending a held clock back
function DayNightRules.clockDelta(from: number, to: number): number
	local d = (to - from) % 24
	if d > 12 then
		d -= 24
	end
	return d
end

return DayNightRules
