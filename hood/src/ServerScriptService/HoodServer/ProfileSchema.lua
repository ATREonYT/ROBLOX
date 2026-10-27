--!strict
local Schema={Version=4}
local function clone(value)
 if type(value)~='table' then return value end
 local result={} for k,v in pairs(value) do result[k]=clone(v) end return result
end
Schema.Template={
 -- Rep is Power (it resets to 0 on a rebirth; Shared/RebirthRules). EquippedSkin is UNUSED since the looks went (players
 -- keep their own avatar); kept, as a known look id, so saved profiles keep loading.
 SchemaVersion=4,EquippedSkin="CornerKid",Rep=0,Cash=0,Rebirths=0,Evolution={Block=1},HighestMapIndex=1,
 UnlockedMaps={Block=true},ClearedWalls={},Crew={owned={},equipped={}},Passes={},
 DailyStreak=0,LastDaily=0,Onboarding={},Settings={Music=true,Sound=true,ReducedMotion=false},
 ProcessedReceipts={},TimePlayed=0,
 -- Guns from the ARMORY: owned ids and the equipped one (its multiplier scales punch Power).
 Guns={Owned={Pistol=true},Equipped='Pistol'},
 -- UNUSED. Speed was trained on the treadmills, which are gone (walk speed now comes from your rebirths,
 -- RebirthRules.walkSpeed). Kept, and still validated, so saved profiles that carry it keep loading.
 Speed=0,
 -- Stage waves: the highest stage whose crew you ever beat (Shared/WaveRules; the gates open per run now,
 -- HoodServer/Runs, never saved). The goal
 -- chain: the current goal's step (Shared/GoalRules); Synced false = a profile from before the chain, caught up
 -- quietly on its first check.
 Waves={Cleared=0},Goals={Step=1,Synced=true,Chain=5},
 -- (Oct 27) The world the fields above belong to, and the other worlds' own Waves/Goals/ClearedWalls (HoodServer/WorldData).
 CurrentWorld=1,Worlds={},
 -- Shoes from the shoe boxes (Shared/ShoeRules): pairs owned by id ({[id]=copies}), the equipped ids (up to 3; the
 -- best is worn, the others follow you) and how many boxes you have opened. Goals.Chain = GoalRules.Chain (a goal
 -- inserted into the chain moves older saves' steps; GoalRules.migrate).
 Shoes={Owned={},Equipped={},Opened=0,Favorites={}},
 -- (brief 30, PITY) The visible guarantees (Shared/PityRules): per shoe box the opens since its last Epic+ (a box that is at 0 is
 -- not stored), and the wheel's spins since its last big prize. HoodServer/ShoeOpening and HudExtras keep it; a profile from before it
 -- has none, which means 0 everywhere (migrate; no version bump: an older server keeps the field as it is).
 Pity={Boxes={},Wheel=0},
 -- (brief 27) The Store's codes used: {[CODE]=os.time used} (HoodServer/Codes: each code once per player).
 Codes={},
 -- (brief 29, P4) The best Level you ever reached (Shared/LevelRules: a level is a curve over Power; the rank follows this
 -- number, so a rebirth, which resets Power, never lowers it). Kept by HoodServer/Levels; HoodServer/ProfileSchema.migrate
 -- fills it for a profile from before it (no version bump: an older server keeps the field as it is).
 BestLevel=1,
 -- (brief 29, P5) Reasons to come back (Shared/RetentionRules, HoodServer/Retention): visits, when you were last here and the
 -- Power waiting from time away, the last offline amount (for the 2x Offline product) and whether the group reward was taken.
 -- DailyStreak (0..7, the day you reached) and LastDaily (os.time of the last claim) are the Daily Rewards'.
 Retention={Joins=0,LastSeen=0,Pending=0,LastOffline=0,Group=false},
 -- HUD30 BEGIN (brief 30, HUD: Shared/HudExtrasRules) the spin wheel (the next free spin's os.time, bought and won extra
 -- spins, spins made, a won box still to open), this session's playtime gifts (seconds played, the gifts taken as a bit set,
 -- the last tick's os.time), the three missions and how many were finished, and whether the Starter Pack was bought.
 Spin={NextFree=0,Extra=0,Spins=0,PendingBox=''},Playtime={Seconds=0,Claimed=0,LastSeen=0},Missions={List={},Done=0},StarterPack=false,
 -- HUD30 END
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
 -- Version 4 (brief 17: no looks, real rebirths): a look id that no longer exists falls back to the first one (it is
 -- never worn); the rebirth count is made a whole number in range (RebirthRules.count). Power, Cash and everything
 -- else are kept as they are.
 if version<4 then
  local Skins=require(game.ReplicatedStorage.Shared.Config.Skins)
  if type(data.EquippedSkin)~='string' or not Skins.ById[data.EquippedSkin] then data.EquippedSkin=nil end
  if data.Rebirths~=nil then data.Rebirths=require(game.ReplicatedStorage.Shared.RebirthRules).count(data.Rebirths) end
 end
 -- Shoes (added with the shoe boxes): new profiles start with none; a damaged table is cleaned, never a reason to kick.
 data.Shoes=require(game.ReplicatedStorage.Shared.ShoeRules).sanitize(data.Shoes)
 -- Pity (brief 30): missing means 0 everywhere; a damaged table (or an unknown box, or a count out of range) is cleaned, never a reason to kick.
 data.Pity=require(game.ReplicatedStorage.Shared.PityRules).sanitize(data.Pity)
 -- Codes (brief 27): a profile from before them gets an empty table; a damaged one is cleaned, never a reason to kick.
 -- No version bump: an older server that loads this profile keeps the field as it is.
 data.Codes=require(script.Parent.Codes).sanitize(data.Codes)
 -- Retention (brief 29): cleaned like the codes; a profile from before it gets the defaults.
 data.Retention=require(game.ReplicatedStorage.Shared.RetentionRules).sanitize(data.Retention)
 if type(data.DailyStreak)=='number' then data.DailyStreak=math.clamp(math.floor(data.DailyStreak),0,7) end
 -- HUD30 BEGIN (brief 30, HUD) the extras: cleaned like the codes; a profile from before them gets the defaults (no version
 -- bump: an older server keeps the fields as they are). A damaged table is rebuilt, never a reason to kick.
 do
  local X=require(game.ReplicatedStorage.Shared.HudExtrasRules)
  data.Spin=X.sanitizeSpin(data.Spin);data.Playtime=X.sanitizePlaytime(data.Playtime);data.Missions=X.sanitizeMissions(data.Missions)
  data.StarterPack=data.StarterPack==true
 end
 -- HUD30 END
 -- Worlds (Oct 27): this place's world's progress on top, the others' saved aside (HoodServer/WorldData); before
 -- the reconcile, so a first visit to a world gets a fresh set. No version bump: an older server keeps the fields.
 require(script.Parent.WorldData).enter(data,require(game.ReplicatedStorage.Shared.WorldInfo).current())
 reconcile(data,Schema.Template)
 -- BestLevel (brief 29): a damaged or missing value is rebuilt from Power and the rebirths (LevelRules.bestOf), never a reason
 -- to kick, and never below what the profile already earned (nobody loses a rank).
 data.BestLevel=require(game.ReplicatedStorage.Shared.LevelRules).bestOf(data)
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
 assert(data.Rebirths%1==0 and data.Rebirths<=require(game.ReplicatedStorage.Shared.Config.Balance).MaxRebirths,'Invalid rebirth count')
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
 -- (up to ShoeRules.MaxSlots: one more than MaxEquipped for the +1 Shoe Slot pass, brief 22; a save with the 4th pair on
 -- must keep loading even before the pass check comes back)
 assert(#s.Equipped<=require(game.ReplicatedStorage.Shared.ShoeRules).MaxSlots,'Too many shoes equipped')
 local on={}
 for _,id in ipairs(s.Equipped) do on[id]=(on[id] or 0)+1;assert((s.Owned[id] or 0)>=on[id],'Equipped shoe not owned') end
 assert(type(s.Opened)=='number' and s.Opened%1==0 and s.Opened>=0,'Invalid Shoes.Opened')
 assert(type(data.Pity)=='table' and type(data.Pity.Boxes)=='table' and type(data.Pity.Wheel)=='number' and data.Pity.Wheel%1==0 and data.Pity.Wheel>=0,'Invalid Pity')
 for id,n in pairs(data.Pity.Boxes) do assert(type(id)=='string' and shoes.BoxById[id] and type(n)=='number' and n%1==0 and n>=1,'Invalid Pity box') end
 assert(type(data.Codes)=='table','Invalid Codes')
 assert(type(data.BestLevel)=='number' and data.BestLevel%1==0 and data.BestLevel>=1 and data.BestLevel<=require(game.ReplicatedStorage.Shared.LevelRules).MaxLevel,'Invalid BestLevel')
 assert(type(data.Retention)=='table' and type(data.Retention.Pending)=='number' and type(data.Retention.LastSeen)=='number' and type(data.Retention.Group)=='boolean','Invalid Retention')
 for code,at in pairs(data.Codes) do assert(type(code)=='string' and type(at)=='number' and at==at and at>=0,'Invalid used code') end
 -- HUD30 BEGIN
 assert(type(data.Spin)=='table' and type(data.Spin.NextFree)=='number' and type(data.Spin.Extra)=='number' and data.Spin.Extra>=0,'Invalid Spin')
 assert(type(data.Playtime)=='table' and type(data.Playtime.Seconds)=='number' and type(data.Playtime.Claimed)=='number','Invalid Playtime')
 assert(type(data.Missions)=='table' and type(data.Missions.List)=='table' and #data.Missions.List<=3 and type(data.Missions.Done)=='number','Invalid Missions')
 assert(type(data.StarterPack)=='boolean','Invalid StarterPack')
 -- HUD30 END
 return true
end
function Schema.public(data)
 -- Explicit allowlist: receipt ledger and entitlement cache never leave the server.
 return {EquippedSkin=data.EquippedSkin,Rep=data.Rep,Cash=data.Cash,Rebirths=data.Rebirths,Evolution=clone(data.Evolution),HighestMapIndex=data.HighestMapIndex,UnlockedMaps=clone(data.UnlockedMaps),Crew=clone(data.Crew),Settings=clone(data.Settings),Onboarding=clone(data.Onboarding),Guns=clone(data.Guns),Waves=clone(data.Waves),Goals=clone(data.Goals),Shoes=clone(data.Shoes),BestLevel=data.BestLevel}
end
return Schema
