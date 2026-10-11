-- The optional Hot Target bonus on the server (brief 29, P4; the rules and the "why" are Shared/HotTargetRules). A ModuleScript:
-- LobbyService calls HotTarget.claim when the HotTarget remote arrives (it knows where you stand).
--   claim pays a hit only while the player stands in an OPEN range (the lane they are training at), at most
--   HotTargetRules.PerMinute a minute, MinGap apart: HotTargetRules.Shots of that lane's shots (gun, shoes, rebirths and
--   boosts counted), x2 while the timed bonus runs. The answer to the client is the remote HotTarget { Gain, Left }.
--   THE PRODUCT HOOK (for P5): HotTarget.grantBoost(player, seconds) starts or extends the "2x bonus" (the player attribute
--   HotTargetBoostEnds, os.time). Call it from StoreService's ProcessReceipt for a developer product (HotTargetRules.
--   BoostSeconds is 10 minutes). It is not saved; the panel shows the bonus chip only while it runs.
local RS = game:GetService('ReplicatedStorage')
local Rules = require(RS.Shared.HotTargetRules)
local ShotRules = require(RS.Shared.ShotRules)
local RebirthRules = require(RS.Shared.RebirthRules)
local Boosts = require(script.Parent.Boosts)
local Net = require(RS.Shared.Net)

local HotTarget = {}
local states = {}

-- Adds `seconds` of the 2x bonus (from now, or after the one that is running).
function HotTarget.grantBoost(player, seconds)
	local now = os.time()
	local ends = player:GetAttribute('HotTargetBoostEnds')
	local from = (type(ends) == 'number' and ends > now) and ends or now
	player:SetAttribute('HotTargetBoostEnds', from + math.clamp(seconds or Rules.BoostSeconds, 1, 86400))
end

-- A hit: returns the Power paid (0 when it doesn't count). `carry` is the player's shoeCarry table.
function HotTarget.claim(player, profile, lane, station, carry, RebirthService)
	if not ShotRules.counts(station) then return 0 end -- (only while you train in an open range)
	states[player] = states[player] or {}
	if not Rules.take(states[player], os.clock()) then return 0 end
	local n = RebirthRules.count(profile.Data.Rebirths)
	local one = ShotRules.pay(ShotRules.perShot(lane, n, Boosts.power(player)), player:GetAttribute('GunMultiplier'), player:GetAttribute('ShoeMultiplier'), carry)
	local gain = Rules.gain(one, Rules.boost(player:GetAttribute('HotTargetBoostEnds'), os.time()))
	if gain <= 0 then return 0 end
	profile.Data.Rep = math.min(1e12, profile.Data.Rep + gain)
	if RebirthService then RebirthService.publish(player, profile.Data) end
	Net.get('HotTarget'):FireClient(player, { Gain = gain, Left = Rules.left(states[player], os.clock()) })
	return gain
end

function HotTarget.forget(player) states[player] = nil end

return HotTarget
