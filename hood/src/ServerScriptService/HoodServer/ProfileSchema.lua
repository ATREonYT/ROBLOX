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
 reconcile(data,Schema.Template)
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
 return true
end
function Schema.public(data)
 -- Explicit allowlist: receipt ledger and entitlement cache never leave the server.
 return {EquippedSkin=data.EquippedSkin,Rep=data.Rep,Cash=data.Cash,Rebirths=data.Rebirths,Evolution=clone(data.Evolution),HighestMapIndex=data.HighestMapIndex,UnlockedMaps=clone(data.UnlockedMaps),Crew=clone(data.Crew),Settings=clone(data.Settings),Onboarding=clone(data.Onboarding),Guns=clone(data.Guns)}
end
return Schema
