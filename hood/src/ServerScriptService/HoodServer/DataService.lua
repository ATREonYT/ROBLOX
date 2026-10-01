local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local ProfileStore=require(script.Parent.Vendor.ProfileStore)
local Schema=require(script.Parent.ProfileSchema)
local Config=require(script.Parent.ServerConfig)
local Net=require(ReplicatedStorage.Shared.Net)
local DataService={}
local profiles={}
local loading={}
local releasing={}
local closing=false
local mode='Persistent'
local store
local map
local started=false
local function snapshot(player)
 local profile=profiles[player]
 if not profile or not profile:IsActive() then return nil end
 local data=Schema.public(profile.Data)
 data.MapId=map.Id;data.MapName=map.Name;data.DataMode=mode
 data.SessionLoadCount=profile.SessionLoadCount
 return data
end
function DataService.get(player)
 local p=profiles[player]
 return if p and p:IsActive() then p else nil
end
function DataService.snapshot(player) return snapshot(player) end
function DataService.push(player)
 local data=snapshot(player)
 if data then Net.get('ProfileUpdated'):FireClient(player,data) end
end
function DataService.release(player)
 local profile=profiles[player]
 if not profile then return end
 releasing[player]=true
 profiles[player]=nil
 player:SetAttribute('ProfileReady',false)
 profile:EndSession()
end
function DataService.setSetting(player,key,value)
 if type(key)~='string' or type(value)~='boolean' then return false end
 if key~='Music' and key~='Sound' and key~='ReducedMotion' then return false end
 local p=DataService.get(player)
 if not p then return false end
 p.Data.Settings[key]=value
 DataService.push(player)
 return true
end
local function load(player)
 if loading[player] or profiles[player] then return end
 loading[player]=true
 player:SetAttribute('ProfileReady',false)
 local began=os.clock()
 local ok,profile=pcall(function()
  return store:StartSessionAsync('Player_'..player.UserId,{Cancel=function()
   return closing or player.Parent~=Players or os.clock()-began>Config.LoadTimeoutSeconds
  end})
 end)
 loading[player]=nil
 if not ok or not profile then
  warn('[DataService] Could not acquire profile: '..tostring(profile))
  if player.Parent==Players then player:Kick('Your progress could not load. Please rejoin.') end
  return
 end
 profile.OnSessionEnd:Connect(function()
  profiles[player]=nil
  player:SetAttribute('ProfileReady',false)
  if not releasing[player] and not closing and player.Parent==Players then player:Kick('Your data session ended. Please rejoin to keep progress safe.') end
 end)
 local valid,reason=pcall(function()
  -- Work on a copy: failed migrations never partially rewrite a saved profile.
  local HttpService=game:GetService('HttpService')
  local candidate=HttpService:JSONDecode(HttpService:JSONEncode(profile.Data))
  Schema.migrate(candidate);Schema.validate(candidate)
  profile.Data=candidate
 end)
 if not valid then
  warn('[DataService] Invalid profile: '..tostring(reason))
  releasing[player]=true;profile:EndSession()
  if player.Parent==Players then player:Kick('This profile needs support before it can load.') end
  return
 end
 if player.UserId>0 then profile:AddUserId(player.UserId) end
 if closing or player.Parent~=Players or not profile:IsActive() then
  releasing[player]=true;profile:EndSession();return
 end
 -- Later-place routing is added with MoveOutService in milestone 6. Fail closed now.
 if profile.Data.UnlockedMaps[map.Id]~=true then
  releasing[player]=true;profile:EndSession()
  player:Kick('This neighborhood is locked. Please join The Block from the experience page.')
  return
 end
 releasing[player]=nil
 profiles[player]=profile
 player:SetAttribute('ProfileReady',true)
 player:SetAttribute('DataMode',mode)
 DataService.push(player)
end
function DataService.start(mapConfig)
 assert(not started,'DataService already started');started=true;map=mapConfig
 local studio=RunService:IsStudio()
 mode=if studio and Config.StudioDataMode=='Mock' then 'Mock' else 'Persistent'
 if not studio then assert(game.GameId>0,'Publish experience before loading live profiles') end
 store=ProfileStore.New(if studio then Config.StudioStoreName else Config.LiveStoreName,Schema.Template)
 if mode=='Mock' then
  store=store.Mock
  warn('[Foundation] MOCK DATA: discarded when this Studio server stops.')
 else
  local deadline=os.clock()+Config.LoadTimeoutSeconds
  while ProfileStore.DataStoreState=='NotReady' and os.clock()<deadline do task.wait(0.1) end
  assert(ProfileStore.DataStoreState=='Access','Persistent storage unavailable; refusing to run on unsaved data')
 end
 Players.PlayerAdded:Connect(load)
 Players.PlayerRemoving:Connect(function(player)
  DataService.release(player)
  loading[player]=nil
  -- Keep release flag until all session callbacks have run; player object is no longer reused.
  task.delay(10,function() releasing[player]=nil end)
 end)
 for _,player in ipairs(Players:GetPlayers()) do task.spawn(load,player) end
 game:BindToClose(function()
  closing=true
  for player in pairs(profiles) do DataService.release(player) end
  -- ProfileStore owns its shutdown save-wait handler.
 end)
end
return DataService
