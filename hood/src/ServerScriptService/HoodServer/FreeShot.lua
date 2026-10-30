-- A click that is not at a range and not in a fight still pays a little (brief 29, P4: "whenever you shoot, make it gain
-- strength, but not as much as when you are at a shooting range"). A ModuleScript: LobbyService calls FreeShot.click when
-- Shoot.client's free shot arrives (the 'Shoot' remote), with where the player stands.
--   * On an open range the gun fires by itself and that pays (LobbyService.autoFire), and in a fight the goon hit pays
--     (WaveService), so a click there pays nothing here: every shot is paid once, in one place.
--   * Anywhere else (the lobby, the street between crews) it pays ShotRules.FreeShare of a x1 shot (the fraction carries,
--     the first click always pays), held to ShotRules.take's token bucket (Burst, PerSecond) like a goon hit.
local RS = game:GetService('ReplicatedStorage')
local ShotRules = require(RS.Shared.ShotRules)
local RebirthRules = require(RS.Shared.RebirthRules)
local Boosts = require(script.Parent.Boosts)

local FreeShot = {}
local buckets = {}

-- Returns the Power paid (0 when it pays nothing).
function FreeShot.click(player, profile, station, carry, RebirthService)
	buckets[player] = buckets[player] or {}
	if not ShotRules.take(buckets[player], os.clock()) then return 0 end
	if ShotRules.counts(station) then return 0 end
	local stage, left = player:GetAttribute('WaveStage'), player:GetAttribute('WaveLeft')
	if type(stage) == 'number' and stage > 0 and type(left) == 'number' and left > 0 then return 0 end
	local n = RebirthRules.count(profile.Data.Rebirths)
	local whole = ShotRules.pay(ShotRules.perShot(1, n, Boosts.power(player)), player:GetAttribute('GunMultiplier'), player:GetAttribute('ShoeMultiplier'), carry)
	local gain = ShotRules.share(whole, ShotRules.FreeShare, carry, 'Free')
	if gain <= 0 then return 0 end
	profile.Data.Rep = math.min(1e15, profile.Data.Rep + gain)
	if RebirthService then RebirthService.publish(player, profile.Data) end
	return gain
end

function FreeShot.forget(player) buckets[player] = nil end

return FreeShot
