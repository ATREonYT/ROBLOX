--!strict
local Balance=require(script.Parent.Config.Balance)
local Crew=require(script.Parent.Config.Crew)
local RebirthRules=require(script.Parent.RebirthRules)
local RepMath={}
-- The foundation's per-tick formula for the later maps (Config/Maps). The Block itself pays nothing per second: Power
-- comes from shots (Shared/ShotRules). Kept consistent with it: the rebirth factor is RebirthRules.multiplier.
-- Crew bonuses add; map, evolution, rebirth and verified entitlement factors multiply.
-- Pass cache in persisted data is NOT trusted: only server-verified factors are accepted here.
function RepMath.getRepPerTick(profile, mapConfig, verifiedFactors)
 local factors=verifiedFactors or {}
 local bonus=0
 local used={}
 for _,uid in ipairs(profile.Crew.equipped) do
  local owned=profile.Crew.owned[uid]
  local member=owned and Crew.Members[owned.CrewId]
  if member and not used[uid] then bonus+=member.RepBonus;used[uid]=true end
 end
 local index=profile.Evolution[mapConfig.Id] or 1
 local evolution=mapConfig.Evolutions[index] or mapConfig.Evolutions[1]
 local social=1+math.clamp(factors.Friends or 0,0,5)*0.1+(if factors.InGroup then 0.1 else 0)
 local result=Balance.BaseRepPerSecond * mapConfig.RepMultiplier * (1+bonus) * evolution.Multiplier * RebirthRules.multiplier(profile.Rebirths) * social * (if factors.DoubleRep then 2 else 1) * (factors.TimedBoost or 1)
 assert(result==result and result>0 and result<=Balance.MaxSafeValue,'Invalid Rep rate')
 return result
end
return RepMath
