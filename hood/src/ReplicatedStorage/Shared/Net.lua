--!strict
local RunService=game:GetService('RunService')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local Net={}
local definitions={EquipSkin='RemoteEvent',RequestSnapshot='RemoteFunction',ProfileUpdated='RemoteEvent',Notice='RemoteEvent',HatchCrew='RemoteEvent',EquipCrew='RemoteEvent',Rebirth='RemoteEvent',MoveOut='RemoteEvent',SelectMap='RemoteEvent',SetSettings='RemoteEvent',Cinematic='RemoteEvent',Shoot='RemoteEvent',BuyGun='RemoteEvent',EquipGun='RemoteEvent',WaveShot='RemoteEvent',WaveState='RemoteEvent',Goal='RemoteEvent',OpenShoeBox='RemoteEvent',ShoeAction='RemoteEvent',ShoeOpened='RemoteEvent',UnboxDone='RemoteEvent',Travel='RemoteEvent',RedeemCode='RemoteFunction',WorldBoss='RemoteEvent',WorldBossShot='RemoteEvent',WorldBossJoin='RemoteEvent'}
-- (brief 29, P4) The rank-up screen's remote, and the optional Hot Target bonus's request (HoodServer/HotTarget).
definitions.RankUp='RemoteEvent'
definitions.HotTarget='RemoteEvent'
-- (brief 29, P5) The daily / welcome back / group window's requests (HoodServer/RetentionService).
definitions.Retention='RemoteFunction'
-- (brief 30, SHOP) Gift A Player: the buyer's chosen target, sent right before a gift-able purchase prompt (HoodServer/StoreService).
definitions.GiftTarget='RemoteEvent'
-- HUD30 BEGIN (brief 30, HUD) the spin wheel, playtime gifts, missions and Starter Pack requests (HoodServer/HudExtrasService).
definitions.HudExtras='RemoteFunction'
-- HUD30 END
function Net.init()
 assert(RunService:IsServer(),'Only server creates network objects')
 local folder=ReplicatedStorage:FindFirstChild('HoodNet')
 if not folder then folder=Instance.new('Folder');folder.Name='HoodNet';folder.Parent=ReplicatedStorage end
 for name,className in pairs(definitions) do
  local existing=folder:FindFirstChild(name)
  if existing then assert(existing.ClassName==className,'Wrong remote class: '..name)
  else local remote=Instance.new(className);remote.Name=name;remote.Parent=folder end
 end
 return folder
end
function Net.get(name: string)
 assert(definitions[name], 'Unknown remote: '..name)
 return ReplicatedStorage:WaitForChild('HoodNet',15):WaitForChild(name,15)
end
return Net
