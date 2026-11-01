--!strict
-- New Game Kit: WorldClock (vault "Realistic City RP/09 Day-Night, Weather and a Living City")
-- Install: ReplicatedStorage/Kit/WorldClock (ModuleScript). Pure maths, same on client and server.
--
-- One shared clock from the server's start time, so every player sees the same sunset and
-- stores open and close together. The server sets one attribute (workspace "ClockEpoch");
-- each client computes the time itself, so nothing is sent every frame.
--
--   WorldClock.ClockTime(elapsed)   -> 0..24 for Lighting.ClockTime
--   WorldClock.IsNight(clock, wasNight) -> boolean (with a small band so street lights don't flicker)
--   WorldClock.IsOpen(hours, clock) -> boolean (a store's opening hours, wraps midnight; "24/7" = always)
--   WorldClock.Label(clock)         -> "9:41 PM" for the phone
-- Status: covered by tests/WorldClock.spec.luau (offline).

local WorldClock = {}

WorldClock.Rules = {
	dayMinutes = 14, -- 06:00 -> 18:00 takes 14 real minutes
	nightMinutes = 6, -- 18:00 -> 06:00 takes 6 (night is moody, short, never the whole session)
	startClock = 8, -- a new server starts in the morning
	lightsOnAt = 18.25,
	lightsOffAt = 6.5,
	band = 0.1, -- hours of hysteresis
}

-- elapsed: seconds since the server's ClockEpoch.
function WorldClock.ClockTime(elapsed: number): number
	local r = WorldClock.Rules
	local daySec, nightSec = r.dayMinutes * 60, r.nightMinutes * 60
	local cycle = daySec + nightSec
	-- convert the start clock into seconds into the cycle (cycle starts at 06:00)
	local function clockToCycle(clock: number): number
		local h = (clock - 6) % 24
		if h < 12 then
			return h / 12 * daySec
		end
		return daySec + (h - 12) / 12 * nightSec
	end
	local t = (clockToCycle(r.startClock) + math.max(0, elapsed)) % cycle
	local clock
	if t < daySec then
		clock = 6 + t / daySec * 12
	else
		clock = 18 + (t - daySec) / nightSec * 12
	end
	return clock % 24
end

function WorldClock.IsNight(clock: number, wasNight: boolean?): boolean
	local r = WorldClock.Rules
	local band = if wasNight == nil then 0 else r.band
	if wasNight then
		-- stay night until clearly past lightsOffAt
		return not (clock >= r.lightsOffAt + band and clock < r.lightsOnAt)
	end
	return clock >= r.lightsOnAt + band or clock < r.lightsOffAt - band
end

export type Hours = { open: number, close: number } | string

function WorldClock.IsOpen(hours: Hours, clock: number): boolean
	if hours == "24/7" then
		return true
	end
	if type(hours) ~= "table" then
		return false
	end
	local h = hours :: { open: number, close: number }
	if h.open == h.close then
		return true
	end
	if h.open < h.close then
		return clock >= h.open and clock < h.close
	end
	return clock >= h.open or clock < h.close -- wraps midnight (a club 20:00-04:00)
end

function WorldClock.Label(clock: number): string
	local total = math.floor((clock % 24) * 60 + 1e-6)
	local h, m = total // 60, total % 60
	local suffix = if h >= 12 then "PM" else "AM"
	local h12 = h % 12
	if h12 == 0 then
		h12 = 12
	end
	return string.format("%d:%02d %s", h12, m, suffix)
end

return WorldClock
