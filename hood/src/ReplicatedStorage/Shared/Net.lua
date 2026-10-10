--!strict
local RunService=game:GetService('RunService')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local Net={}
local definitions={EquipSkin='RemoteEvent',RequestSnapshot='RemoteFunction',ProfileUpdated='RemoteEvent',Notice='RemoteEvent',HatchCrew='RemoteEvent',EquipCrew='RemoteEvent',Rebirth='RemoteEvent',MoveOut='RemoteEvent',SelectMap='RemoteEvent',SetSettings='RemoteEvent',Cinematic='RemoteEvent',Shoot='RemoteEvent',BuyGun='RemoteEvent',EquipGun='RemoteEvent',WaveShot='RemoteEvent',WaveState='RemoteEvent',Goal='RemoteEvent',OpenShoeBox='RemoteEvent',ShoeAction='RemoteEvent',ShoeOpened='RemoteEvent',Travel='RemoteEvent'}
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
