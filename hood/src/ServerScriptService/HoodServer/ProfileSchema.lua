--!strict
local Schema={Version=3}
local function clone(value)
 if type(value)~='table' then return value end
 local result={} for k,v in pairs(value) do result[k]=clone(v) end return result
end
Schema.Template={
 SchemaVersion=3,EquippedSkin="CornerKid",Rep=0,Cash=0,Rebirths=0,Evolution={Block=1},HighestMapIndex=1,
 UnlockedMaps={Block=true},ClearedWalls={},Crew={owned={},equipped={}},Passes={},
 DailyStreak=0,LastDaily=0,Onboarding={},Settings={Music=true,Sound=true,ReducedMotion=false},
 ProcessedReceipts={},TimePlayed=0,
 -- Guns from the ARMORY: owned ids and the equipped one (its multiplier scales punch Power).
 Guns={Owned={Pistol=true},Equipped='Pistol'},
 -- UNUSED. Speed was trained on the treadmills, which are gone (walk speed now comes from your look,
 -- Config/Skins.walkSpeed). Kept, and still validated, so saved profiles that carry it keep loading.
 Speed=0,
 -- Stage target waves: the highest stage whose wave you cleared (Shared/WaveRules; gate i needs i-1). The goal
 -- chain: the current goal's step (Shared/GoalRules); Synced false = a profile from before the chain, caught up
 -- quietly on its first check.
 Waves={Cleared=0},Goals={Step=1,Synced=true,Chain=2},
 -- Shoes from the shoe boxes (Shared/ShoeRules): pairs owned by id ({[id]=copies}), the equipped ids (up to 3; the
 -- best is worn, the others follow you) and how many boxes you have opened. Goals.Chain = GoalRules.Chain (a goal
 -- inserted into the chain moves older saves' steps; GoalRules.migrate).
 Shoes={Owned={},Equipped={},Opened=0},
}
function Schema.new() return clone(Schema.Template) end
function Schema.migrate(data)
 local version=data.SchemaVersion or 0
 assert(type(version)=='number' and version%1==0 and version>=0 and version<=Schema.Version,'Unsupported profile version')
 if version==0 then
  if type(data.Evolution)=='number' then data.Evolution={Block=math.clamp(math.floor(data.Evolution),1,5)} end
 end
 local function reconcile(target,template)
  for k,v in pairs(template) do
   if target[k]==nil then target[k]=clone(v)
   elseif type(v)=='table' then assert(type(target[k])=='table','Invalid profile field: '..k);reconcile(target[k],v) end
  end
 end
 if version<3 and data.EquippedSkin then
  local aliases={Rookie='CornerKid',RoadRunner='Pickpocket',Crook='Bandit',Gangster='Crook',MafiaBoss='StreetBoss',Legend='Capo'}
  data.EquippedSkin=aliases[data.EquippedSkin] or data.EquippedSkin
 end
 -- Profiles from before the waves and the goal chain: their passed gates count as cleared waves (nobody is
 -- re-locked), and their goals catch up without paying.
 if data.Waves==nil then data.Waves={Cleared=require(game.ReplicatedStorage.Shared.WaveRules).legacy(data.ClearedWalls)} end
 if data.Goals==nil then data.Goals={Step=1,Synced=false,Chain=require(game.ReplicatedStorage.Shared.GoalRules).Chain}
 else require(game.ReplicatedStorage.Shared.GoalRules).migrate(data.Goals) end
 -- Shoes (added with the shoe boxes): new profiles start with none; a damaged table is cleaned, never a reason to kick.
 data.Shoes=require(game.ReplicatedStorage.Shared.ShoeRules).sanitize(data.Shoes)
 reconcile(data,Schema.Template)
 require(game.ReplicatedStorage.Shared.WaveRules).sanitize(data.Waves)
 require(game.ReplicatedStorage.Shared.GoalRules).sanitize(data.Goals)
 -- Guns removed from the config fall away and the pistol stays owned, so a retired gun never locks a profile out.
 require(game.ReplicatedStorage.Shared.GunRules).sanitize(data.Guns)
 data.SchemaVersion=Schema.Version
 return data
end
function Schema.validate(data)
 for _,key in ipairs({'Rep','Cash','Rebirths','DailyStreak','LastDaily','TimePlayed','Speed'}) do
  local n=data[key]
  assert(type(n)=='number' and n==n and n>=0 and n<=1e12,'Invalid numeric profile field: '..key)
 end
 assert(type(data.EquippedSkin)=='string' and require(game.ReplicatedStorage.Shared.Config.Skins).ById[data.EquippedSkin],'Invalid equipped skin')
 assert(require(game.ReplicatedStorage.Shared.Config.Skins).available(data.Rep,data.EquippedSkin),'Equipped skin exceeds progress')
 assert(data.Rebirths%1==0,'Invalid rebirth count')
 assert(type(data.HighestMapIndex)=='number' and data.HighestMapIndex>=1 and data.HighestMapIndex%1==0,'Invalid map progress')
 for _,key in ipairs({'Evolution','UnlockedMaps','ClearedWalls','Passes','Onboarding','Settings','ProcessedReceipts','Crew'}) do
  assert(type(data[key])=='table','Invalid profile table: '..key)
 end
 assert(type(data.Crew.owned)=='table' and type(data.Crew.equipped)=='table','Invalid Crew')
 assert(data.UnlockedMaps.Block==true,'Missing starter map')
 for _,index in pairs(data.Evolution) do assert(type(index)=='number' and index>=1 and index<=5 and index%1==0,'Invalid evolution') end
 for _,enabled in pairs(data.Settings) do assert(type(enabled)=='boolean','Invalid setting') end
 local guns=require(game.ReplicatedStorage.Shared.Config.Guns)
 assert(type(data.Guns)=='table' and type(data.Guns.Owned)=='table','Invalid Guns')
 for id,owned in pairs(data.Guns.Owned) do assert(type(id)=='string' and guns.ById[id] and owned==true,'Invalid owned gun') end
 assert(type(data.Guns.Equipped)=='string' and data.Guns.Owned[data.Guns.Equipped]==true,'Equipped gun not owned')
 assert(type(data.Waves)=='table' and type(data.Waves.Cleared)=='number' and data.Waves.Cleared%1==0 and data.Waves.Cleared>=0 and data.Waves.Cleared<=64,'Invalid Waves')
 assert(type(data.Goals)=='table' and type(data.Goals.Step)=='number' and data.Goals.Step%1==0 and data.Goals.Step>=1 and type(data.Goals.Synced)=='boolean','Invalid Goals')
 assert(data.Goals.Back==nil or (type(data.Goals.Back)=='number' and data.Goals.Back%1==0 and data.Goals.Back>data.Goals.Step),'Invalid Goals.Back')
 local shoes=require(game.ReplicatedStorage.Shared.Config.Shoes)
 local s=data.Shoes
 assert(type(s)=='table' and type(s.Owned)=='table' and type(s.Equipped)=='table','Invalid Shoes')
 for id,n in pairs(s.Owned) do assert(type(id)=='string' and shoes.ById[id] and type(n)=='number' and n%1==0 and n>=1,'Invalid owned shoe') end
 assert(#s.Equipped<=shoes.MaxEquipped,'Too many shoes equipped')
 local on={}
 for _,id in ipairs(s.Equipped) do on[id]=(on[id] or 0)+1;assert((s.Owned[id] or 0)>=on[id],'Equipped shoe not owned') end
 assert(type(s.Opened)=='number' and s.Opened%1==0 and s.Opened>=0,'Invalid Shoes.Opened')
 return true
end
function Schema.public(data)
 -- Explicit allowlist: receipt ledger and entitlement cache never leave the server.
 return {EquippedSkin=data.EquippedSkin,Rep=data.Rep,Cash=data.Cash,Rebirths=data.Rebirths,Evolution=clone(data.Evolution),HighestMapIndex=data.HighestMapIndex,UnlockedMaps=clone(data.UnlockedMaps),Crew=clone(data.Crew),Settings=clone(data.Settings),Onboarding=clone(data.Onboarding),Guns=clone(data.Guns),Waves=clone(data.Waves),Goals=clone(data.Goals),Shoes=clone(data.Shoes)}
end
return Schema
