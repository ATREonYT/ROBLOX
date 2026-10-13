--!strict
-- The OPTIONAL "Hot Target" bonus (brief 29, P4). The user: "the grinding at ranges dont force it, make it optional because
-- people might start calling us out for trying to make them addicted". So this is a small corner mini-game a player opens
-- on purpose, from a button that never pulses, badges or pops up; nothing is lost by ignoring it; there are no streaks, no
-- combos, no timers to beat and no daily anything. While you train in an open lane, you can tap the glowing cell of a
-- 3x3 panel for a small bonus: Shots of the lane's shots at once. The rules cap it hard so it can never matter more than a
-- little (PerMinute x Shots = 40 shots a minute against the range's 300): it is a pastime, not a way to play.
--   The server pays it (HoodServer/HotTarget); the panel (HoodClient/HotTarget) only draws the cells and asks.
--   The one product hook: a timed "2x bonus" (HotTargetBoostEnds, the os.time it ends, on the player). HoodServer/HotTarget's
--   grantBoost(player, seconds) sets it; the StoreService can call it for a developer product. Nothing else changes.
local HotTargetRules = {}
HotTargetRules.Shots = 2 -- a hit pays this many shots at your lane (your gun, shoes, rebirths and boosts counted)
HotTargetRules.PerMinute = 20 -- at most this many hits count in any minute
HotTargetRules.MinGap = 0.6 -- seconds between two hits that count
HotTargetRules.BoostMultiplier = 2 -- the timed bonus
HotTargetRules.BoostSeconds = 600 -- ... for 10 minutes
HotTargetRules.Cells = 9 -- the panel's 3x3 grid
HotTargetRules.GlowSeconds = 1.6 -- a cell glows this long, then the glow just moves (nothing is lost)

local function number(v: any, fallback: number): number
	if type(v) ~= 'number' or v ~= v or v == math.huge or v == -math.huge then return fallback end
	return v
end

-- May a hit count now? state = {} per player (keeps the times of the last minute); now in seconds. Records the hit when it does.
function HotTargetRules.take(state: any, now: any): boolean
	if type(state) ~= 'table' then return false end
	local t = number(now, 0)
	local times: { number } = state.Times or {}
	state.Times = times
	while #times > 0 and t - times[1] >= 60 do table.remove(times, 1) end
	if #times > 0 and t - times[#times] < HotTargetRules.MinGap then return false end
	if #times >= HotTargetRules.PerMinute then return false end
	table.insert(times, t)
	return true
end

-- Hits still to spare in the minute.
function HotTargetRules.left(state: any, now: any): number
	if type(state) ~= 'table' or type(state.Times) ~= 'table' then return HotTargetRules.PerMinute end
	local t, n = number(now, 0), 0
	for _, x in state.Times do
		if t - x < 60 then n += 1 end
	end
	return math.max(0, HotTargetRules.PerMinute - n)
end

-- x2 while the timed bonus runs (endsAt = os.time it ends, now = os.time), else x1.
function HotTargetRules.boost(endsAt: any, now: any): number
	if number(endsAt, 0) > number(now, 0) then return HotTargetRules.BoostMultiplier end
	return 1
end

-- Power for a hit: Shots of the lane's shot (`one`, what one shot pays), times the boost.
function HotTargetRules.gain(one: any, boost: any): number
	return math.floor(HotTargetRules.Shots * math.max(0, number(one, 0)) * math.clamp(number(boost, 1), 1, HotTargetRules.BoostMultiplier) + 1e-7)
end

return HotTargetRules
