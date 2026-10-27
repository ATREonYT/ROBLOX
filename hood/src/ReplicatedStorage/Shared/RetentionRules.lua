--!strict
-- Reasons to come back (brief 29, P5): the 7-day Daily Rewards with a streak you can restore, the Power you earn while you
-- are away (capped at 8 hours), the Friend boost and the one-time Group reward. Pure functions, so the server
-- (HoodServer/Retention, RetentionService), the client (Retention.client) and the unit tests all agree.
-- Honest by design: no fake timers or scarcity. A day is a UTC calendar day. Every number a card shows is the number
-- that is granted.
local Balance = require(script.Parent.Config.Balance)

local R = {}
R.DaySeconds = 86400
R.Days = 7
R.RestoreWindowDays = 3 -- a streak can be restored when you missed at most this many days
R.OfflineCapSeconds = 8 * 3600
R.OfflineMinSeconds = 300 -- away for less than this earns nothing (a quick reconnect is not "offline")
R.OfflineNeedShare = 0.04 -- of the next rebirth's Power need, per hour away
R.OfflineMinPerHour = 100
R.FriendStep = 0.10 -- +10 % Power per friend in the server
R.FriendMax = 0.50 -- ... up to +50 %
R.BoostSeconds = 900

local function number(v: any, fallback: number): number
	if type(v) ~= 'number' or v ~= v or v == math.huge or v == -math.huge then return fallback end
	return v
end

-- Round to two significant figures, at least `floor`.
local function nice(n: number, floor: number): number
	n = math.max(floor, n)
	local p = 10 ^ math.max(0, math.floor(math.log10(n)) - 1)
	return math.floor(n / p + 0.5) * p
end

-- How much more a stage's Cash is worth than stage 1's (the cash packs' scale, Products.cashAmount): ^0.6.
function R.stageScale(stage: any): number
	local pads = Balance.PadCash
	local n = math.clamp(math.floor(number(stage, 1)), 1, #pads)
	return (pads[n] / pads[1]) ^ 0.6
end

---------------------------------------------------------------------------------------------- daily rewards
-- The seven cards. Rarity colours the border like the reference (blue, purple, red). Cash scales with the best stage,
-- Power is a share of the next rebirth's need (so a day-5 card is worth the same at every point of the game).
R.Daily = {
	{ Day = 1, Rarity = 'blue', Cash = 300 },
	{ Day = 2, Rarity = 'blue', PowerShare = 0.02 },
	{ Day = 3, Rarity = 'blue', Cash = 800 },
	{ Day = 4, Rarity = 'purple', Boost = 2 },
	{ Day = 5, Rarity = 'purple', PowerShare = 0.05 },
	{ Day = 6, Rarity = 'purple', Cash = 1500 },
	{ Day = 7, Rarity = 'red', Cash = 3000, PowerShare = 0.1, Boost = 3, Big = true },
}

-- What day `day` gives now: { Cash, Power, Boost (level), Seconds } (a missing part is absent). need = the Power your
-- next rebirth needs, stage = your best stage.
function R.reward(day: any, need: any, stage: any): { [string]: number }?
	local d = R.Daily[math.floor(number(day, 0))]
	if not d then return nil end
	local out: { [string]: number } = {}
	if d.Cash then out.Cash = nice(d.Cash * R.stageScale(stage), d.Cash) end
	if d.PowerShare then out.Power = nice(math.max(100, number(need, 1000)) * d.PowerShare, 100) end
	if d.Boost then
		out.Boost = d.Boost
		out.Seconds = R.BoostSeconds
	end
	return out
end

-- The card's lines, e.g. { '+300 Cash' } or { '+1.2K Power', '2x Power 15 min' }. fmt = a number formatter.
function R.lines(reward: any, fmt: (number) -> string): { string }
	local lines = {}
	if type(reward) ~= 'table' then return lines end
	if reward.Cash then table.insert(lines, '+' .. fmt(reward.Cash) .. ' Cash') end
	if reward.Power then table.insert(lines, '+' .. fmt(reward.Power) .. ' Power') end
	if reward.Boost then table.insert(lines, reward.Boost .. 'x Power ' .. math.floor(number(reward.Seconds, R.BoostSeconds) / 60) .. ' min') end
	return lines
end

function R.dayIndex(t: any): number
	return math.floor(number(t, 0) / R.DaySeconds)
end

-- The daily state for a profile ({ DailyStreak = 0..7, LastDaily = os.time of the last claim or 0 }) at time `now`:
--   Ready      a reward can be claimed now
--   Day        the day that would be claimed (1..7); after a miss with no restore it starts again at 1
--   Claimed    the days claimed so far in this round (the streak, 0..7)
--   Missed     you skipped at least one whole day (the streak would start again)
--   CanRestore a missed streak that can still be restored (RestoreWindowDays, and there is a streak to keep)
--   RestoreDay the day you would claim after a restore
--   Wait       seconds until the next claim opens (when not Ready)
function R.status(data: any, now: any): { [string]: any }
	local streak = math.clamp(math.floor(number(type(data) == 'table' and data.DailyStreak, 0)), 0, R.Days)
	local last = number(type(data) == 'table' and data.LastDaily, 0)
	local t = number(now, 0)
	if last <= 0 then return { Ready = true, Day = 1, Claimed = 0, Missed = false, CanRestore = false } end
	local gap = R.dayIndex(t) - R.dayIndex(last)
	local nextDay = streak % R.Days + 1
	if gap <= 0 then
		return { Ready = false, Day = nextDay, Claimed = streak, Missed = false, CanRestore = false, Wait = (R.dayIndex(t) + 1) * R.DaySeconds - t }
	elseif gap == 1 then
		return { Ready = true, Day = nextDay, Claimed = streak, Missed = false, CanRestore = false }
	end
	return {
		Ready = true, Day = 1, Claimed = 0, Missed = true, Gap = gap, Streak = streak,
		CanRestore = streak >= 1 and gap - 1 <= R.RestoreWindowDays, RestoreDay = nextDay,
	}
end

-- Claim: true and the day, or false and why ('notready'). A missed streak restarts at Day 1 unless it was restored first.
function R.claim(data: any, now: any): (boolean, any)
	local st = R.status(data, now)
	if not st.Ready then return false, 'notready' end
	data.DailyStreak = st.Day
	data.LastDaily = number(now, 0)
	return true, st.Day
end

-- Restore: puts LastDaily on yesterday, so the streak carries on (Day N+1 is ready now). true, or false and why
-- ('nomiss': nothing to restore; 'toolate': past the window).
function R.restore(data: any, now: any): (boolean, string?)
	local st = R.status(data, now)
	if not st.Missed or (st.Streak or 0) < 1 then return false, 'nomiss' end
	if not st.CanRestore then return false, 'toolate' end
	data.LastDaily = (R.dayIndex(now) - 1) * R.DaySeconds + R.DaySeconds / 2
	return true, nil
end

---------------------------------------------------------------------------------------------- offline earnings
-- Seconds away that count: LastSeen to now, capped at 8 hours; 0 under the minimum or for a first visit.
function R.offlineSeconds(lastSeen: any, now: any): number
	local last, t = number(lastSeen, 0), number(now, 0)
	if last <= 0 or t <= last then return 0 end
	local s = t - last
	if s < R.OfflineMinSeconds then return 0 end
	return math.min(s, R.OfflineCapSeconds)
end

-- Power earned for `seconds` away (up to the cap) when your next rebirth needs `need`: OfflineNeedShare of it per hour,
-- at least OfflineMinPerHour.
function R.offlinePower(need: any, seconds: any): number
	local s = math.clamp(number(seconds, 0), 0, R.OfflineCapSeconds)
	if s <= 0 then return 0 end
	local perHour = math.max(R.OfflineMinPerHour, math.max(1, number(need, 1000)) * R.OfflineNeedShare)
	return math.floor(perHour * s / 3600)
end

-- "IN 8 HOURS" on the Before You Go card.
function R.eightHours(need: any): number
	return R.offlinePower(need, R.OfflineCapSeconds)
end

---------------------------------------------------------------------------------------------- friend boost
-- +10 % Power per friend in this server, at most +50 %: 0..0.5.
function R.friendBoost(friends: any): number
	local n = math.max(0, math.floor(number(friends, 0)))
	return math.min(R.FriendMax, n * R.FriendStep)
end

---------------------------------------------------------------------------------------------- group reward
-- One time, for joining the group (ServerConfig.GroupId; 0 = off): Cash that scales with your best stage and 15 minutes
-- of 2x Power.
R.Group = { Cash = 1000, Boost = 2 }
function R.groupReward(stage: any): { [string]: number }
	return { Cash = nice(R.Group.Cash * R.stageScale(stage), R.Group.Cash), Boost = R.Group.Boost, Seconds = R.BoostSeconds }
end

---------------------------------------------------------------------------------------------- the profile's Retention table
R.Template = { Joins = 0, LastSeen = 0, Pending = 0, LastOffline = 0, Group = false }

-- A damaged or missing table is rebuilt, never a reason to kick (fields are whole, finite, in range).
function R.sanitize(r: any): { [string]: any }
	local out: { [string]: any } = { Joins = 0, LastSeen = 0, Pending = 0, LastOffline = 0, Group = false }
	if type(r) ~= 'table' then return out end
	for _, key in { 'Joins', 'LastSeen', 'Pending', 'LastOffline' } do
		local v = number(r[key], 0)
		out[key] = (v >= 0 and v <= 1e12) and math.floor(v) or 0
	end
	out.Group = r.Group == true
	return out
end

return R
