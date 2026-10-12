--!nonstrict
-- The server half of the HUD extras (brief 30, HUD; the rules are Shared/HudExtrasRules): what a spin, a playtime gift, a
-- mission and the Starter Pack change in a profile. Like HoodServer/Retention: everything here changes only the profile
-- (the caller sets the attributes and pushes the snapshot), checks what could fail BEFORE it changes anything, and never
-- yields, so HudExtrasService, StoreReceipts and the unit tests run the same code.
--   A reward's Cash, Power and Boost go through Retention.give (the boost queue keeps every bought minute). Spins add to
--   the wheel's Extra. A Box reward is NOT opened here: it is noted (Spin.PendingBox) so the service opens it once the
--   wheel has stopped turning, and a player who leaves first gets it opened on their next join (never lost).
local RS = game:GetService('ReplicatedStorage')
local Rules = require(RS.Shared.HudExtrasRules)
local RebirthRules = require(RS.Shared.RebirthRules)
local Retention = require(script.Parent.Retention)

local HudExtras = {}

local function need(data) return RebirthRules.need(data.Rebirths) end
function HudExtras.tables(data)
	data.Spin = Rules.sanitizeSpin(data.Spin)
	data.Playtime = Rules.sanitizePlaytime(data.Playtime)
	data.Missions = Rules.sanitizeMissions(data.Missions)
	data.StarterPack = data.StarterPack == true
	return data
end

-- A reward spec made real for this profile ({ Cash, Power, Boost, Seconds, Spins, Box }).
function HudExtras.reward(profile, spec)
	local data = profile.Data
	return Rules.make(spec, need(data), Retention.bestStage(data))
end
-- Gives a made reward (not its Box: see the header). Asserts before any change (Retention.give's boost check).
function HudExtras.give(profile, reward, now)
	local data = profile.Data
	HudExtras.tables(data)
	Retention.give(profile, reward, now)
	if reward.Spins then Rules.addSpins(data.Spin, reward.Spins) end
	if reward.Box then data.Spin.PendingBox = reward.Box end
end

---------------------------------------------------------------------------------------------- spin
-- One spin: true, the wedge index and the reward, or false and why ('none'). r = the roll in [0, 1).
function HudExtras.spin(profile, r, now)
	local data = HudExtras.tables(profile.Data)
	local st = Rules.spinState(data.Spin, now)
	if st.Total <= 0 then return false, 'none' end
	if data.Spin.PendingBox ~= '' then return false, 'busy' end
	local i = Rules.pick(r)
	local reward = HudExtras.reward(profile, Rules.Wedges[i])
	HudExtras.give(profile, reward, now) -- (may only throw before it changes anything)
	local ok = Rules.takeSpin(data.Spin, now)
	assert(ok, 'spin refused')
	return true, i, reward
end

---------------------------------------------------------------------------------------------- playtime
function HudExtras.playtimeJoin(profile, now)
	local data = HudExtras.tables(profile.Data)
	Rules.playtimeJoin(data.Playtime, now)
end
function HudExtras.playtimeTick(profile, dt, now)
	local data = HudExtras.tables(profile.Data)
	Rules.playtimeTick(data.Playtime, dt, now)
end
-- Takes gift i: true and the reward, or false and why.
function HudExtras.claimGift(profile, i, now)
	local data = HudExtras.tables(profile.Data)
	local g = Rules.Gifts[math.floor(tonumber(i) or 0)]
	if not g then return false, 'unknown' end
	if data.Spin.PendingBox ~= '' and g.Box then return false, 'busy' end
	local reward = HudExtras.reward(profile, g)
	-- (the checks first, on a copy; then the reward, which may only throw before it changes anything; then the mark)
	local ok, why = Rules.takeGift(table.clone(data.Playtime), i)
	if not ok then return false, why end
	HudExtras.give(profile, reward, now)
	Rules.takeGift(data.Playtime, i)
	return true, reward
end

---------------------------------------------------------------------------------------------- missions
-- Counts n of kind; returns the indexes that just finished.
function HudExtras.count(profile, kind, n)
	local data = HudExtras.tables(profile.Data)
	return Rules.countMission(data.Missions, kind, n)
end
-- Claims task i: true and the reward, or false and why. The list is refilled (pick, allowed: see Rules.fillMissions).
function HudExtras.claimMission(profile, i, now, pick, allowed)
	local data = HudExtras.tables(profile.Data)
	local t = data.Missions.List[math.floor(tonumber(i) or 0)]
	if not t then return false, 'unknown' end
	if t.Have < t.Goal then return false, 'notdone' end
	local reward = HudExtras.reward(profile, Rules.taskReward(t.Kind, t.Step))
	HudExtras.give(profile, reward, now) -- (may only throw before it changes anything)
	local ok, task = Rules.claimMission(data.Missions, i)
	assert(ok, 'claim refused')
	Rules.fillMissions(data.Missions, pick, allowed, task.Kind)
	return true, reward, task
end

---------------------------------------------------------------------------------------------- starter pack
-- The box the Starter Pack opens: the world's cheapest Robux box (Config/Shoes.boxesForWorld lists Robux boxes cheapest
-- first), by id, so a renamed box needs nothing here. nil when the world has none.
function HudExtras.starterBox(Shoes, world)
	for _, box in Shoes.boxesForWorld(world or Shoes.ActiveWorld or 1) do
		if box.Robux then return box.Id end
	end
	return nil
end
-- The Starter Pack's parts for this profile: { Cash, Boosts = { level, ... }, Seconds, Box = boxId or nil }. boxId: the
-- world's cheapest Robux box (the caller resolves it from Config/Shoes, so a renamed box needs no change here).
function HudExtras.starterParts(profile, boxId)
	local data = profile.Data
	local cash = Rules.nice(Rules.Starter.Cash * Rules.stageScale(Retention.bestStage(data)), Rules.Starter.Cash)
	return { Cash = cash, Boosts = table.clone(Rules.Starter.Boosts), Seconds = Rules.Starter.BoostSeconds, Box = boxId }
end

return HudExtras
