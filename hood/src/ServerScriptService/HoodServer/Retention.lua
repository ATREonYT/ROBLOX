--!nonstrict
-- The server half of the reasons to come back (brief 29, P5; the numbers are Shared/RetentionRules): what the Daily Rewards,
-- the Welcome back card, the Group reward and the two Robux helpers (Restore Streak, 2x Offline) change in a profile.
-- Everything here changes only the profile (the caller sets the Cash / Power attributes and pushes the snapshot), checks
-- what could fail BEFORE it changes anything, and never yields, so StoreReceipts and the unit tests run the same code.
local RS = game:GetService('ReplicatedStorage')
local Rules = require(RS.Shared.RetentionRules)
local RebirthRules = require(RS.Shared.RebirthRules)
local Format = require(RS.Shared.Format)
local Boosts = require(script.Parent.Boosts)

local Retention = {}

local function need(data) return RebirthRules.need(data.Rebirths) end
-- The best stage you have reached: the gates you ever passed (the same count the cash packs scale with).
function Retention.bestStage(data)
	local n = 0
	for _, passed in (type(data.ClearedWalls) == 'table' and data.ClearedWalls or {}) do
		if passed == true then n += 1 end
	end
	return math.max(1, n)
end

local function table_(data)
	if type(data.Retention) ~= 'table' then data.Retention = Rules.sanitize(nil) end
	return data.Retention
end

-- Gives a reward ({ Cash, Power, Boost, Seconds }) to the profile.
function Retention.give(profile, reward, now)
	local data = profile.Data
	local passes = type(data.Passes) == 'table' and data.Passes or {}
	local boost = passes.Boost
	if reward.Boost then boost = Boosts.add(boost, reward.Boost, reward.Seconds or Rules.BoostSeconds, now) end -- (pure: asserts before any change)
	if reward.Boost then
		passes.Boost = boost
		data.Passes = passes
	end
	if reward.Cash then data.Cash = math.min(1e12, data.Cash + reward.Cash) end
	if reward.Power then data.Rep = math.min(1e12, data.Rep + reward.Power) end
end

local function fmtLines(reward)
	return table.concat(Rules.lines(reward, Format.compact), ' + ')
end

-- A join: counts the visit, works out what was earned while away (capped at 8 hours; it waits in Pending until claimed,
-- never above the 8-hour amount) and stamps LastSeen. Returns the Retention table.
function Retention.onJoin(profile, now)
	local r = table_(profile.Data)
	r.Joins += 1
	local secs = Rules.offlineSeconds(r.LastSeen, now)
	if secs > 0 then
		local n = need(profile.Data)
		r.Pending = math.min(Rules.eightHours(n), r.Pending + Rules.offlinePower(n, secs))
	end
	r.LastSeen = now
	return r
end

-- While playing: LastSeen follows the clock, so a crash or a closed server still counts the time away from the last minute.
function Retention.touch(profile, now)
	table_(profile.Data).LastSeen = now
end

-- Claim today's daily reward: true, day, lines (text) or false, why.
function Retention.claimDaily(profile, now)
	local data = profile.Data
	local st = Rules.status(data, now)
	if not st.Ready then return false, 'notready' end
	local reward = Rules.reward(st.Day, need(data), Retention.bestStage(data))
	assert(reward, 'no reward for day ' .. tostring(st.Day))
	Retention.give(profile, reward, now)
	local ok, day = Rules.claim(data, now)
	assert(ok, 'claim refused')
	return true, day, fmtLines(reward), reward
end

-- Claim the Power earned while away: true, amount or false, why.
function Retention.claimOffline(profile)
	local r = table_(profile.Data)
	local amount = r.Pending
	if amount <= 0 then return false, 'none' end
	profile.Data.Rep = math.min(1e12, profile.Data.Rep + amount)
	r.LastOffline = amount
	r.Pending = 0
	return true, amount
end

-- The group reward, once: true, lines or false, why ('off': no group set; 'notin'; 'had').
function Retention.claimGroup(profile, inGroup, now, groupOn)
	if groupOn == false then return false, 'off' end
	local r = table_(profile.Data)
	if r.Group then return false, 'had' end
	if inGroup ~= true then return false, 'notin' end
	local reward = Rules.groupReward(Retention.bestStage(profile.Data))
	Retention.give(profile, reward, now)
	r.Group = true
	return true, fmtLines(reward), reward
end

-- The Restore Streak product: keeps the streak after a missed day. Asserts (the receipt then answers "ask again") only
-- when it cannot apply at all; a streak that needs no restore is simply left alone and the buyer gets the day's reward
-- ready anyway (see StoreReceipts.restoreStreak).
function Retention.restoreStreak(profile, now)
	return Rules.restore(profile.Data, now)
end

-- The 2x Offline product: the Power you are due while away, doubled. Pending (not yet claimed) counts twice at once;
-- if it was already claimed, the same amount again; with neither, one full 8-hour amount. Returns the Power given.
function Retention.offlineDouble(profile)
	local data = profile.Data
	local r = table_(data)
	local amount
	if r.Pending > 0 then
		amount = r.Pending * 2
	elseif r.LastOffline > 0 then
		amount = r.LastOffline
	else
		amount = Rules.eightHours(need(data))
	end
	data.Rep = math.min(1e12, data.Rep + amount)
	r.Pending, r.LastOffline = 0, 0
	return amount
end

-- What the client needs (the cards and their numbers), at time `now`. extras: { GroupOn, InGroup, Friends }.
function Retention.state(profile, now, extras)
	extras = extras or {}
	local data = profile.Data
	local r = table_(data)
	local n, stage = need(data), Retention.bestStage(data)
	local st = Rules.status(data, now)
	local cards = {}
	for day = 1, Rules.Days do
		local reward = Rules.reward(day, n, stage)
		cards[day] = { Day = day, Rarity = Rules.Daily[day].Rarity, Big = Rules.Daily[day].Big == true, Lines = Rules.lines(reward, Format.compact) }
	end
	local nextDay = st.Ready and st.Day or st.Day
	local group = Rules.groupReward(stage)
	return {
		Joins = r.Joins,
		Daily = { Ready = st.Ready, Day = st.Day, Claimed = st.Claimed, Missed = st.Missed, CanRestore = st.CanRestore, RestoreDay = st.RestoreDay, Wait = st.Wait, Cards = cards, NextDay = nextDay },
		Offline = { Pending = r.Pending, EightHours = Rules.eightHours(n), CapHours = Rules.OfflineCapSeconds / 3600 },
		Group = { On = extras.GroupOn == true, InGroup = extras.InGroup == true, Claimed = r.Group, Lines = Rules.lines(group, Format.compact) },
		Friends = { Count = extras.Friends or 0, Boost = Rules.friendBoost(extras.Friends or 0) },
	}
end

return Retention
