local ReplicatedStorage=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local Players=game:GetService('Players')
local ServerStorage=game:GetService('ServerStorage')
local Net=require(ReplicatedStorage.Shared.Net)
local Maps=require(ReplicatedStorage.Shared.Config.Maps)
local DataService=require(script.Parent.DataService)
local RateLimiter=require(script.Parent.RateLimiter)
local buildMap=ServerStorage:FindFirstChild('MapBuildId')
local map=Maps.resolve(game.PlaceId,RunService:IsStudio(),buildMap and buildMap.Value)
Net.init()
local snapshotLimit=RateLimiter.new(3,1)
local intentLimit=RateLimiter.new(5,2)
Net.get('RequestSnapshot').OnServerInvoke=function(player)
 if not snapshotLimit.allow(player) then return {Ready=false,Reason='Please wait'} end
 local data=DataService.snapshot(player)
 return if data then {Ready=true,Profile=data} else {Ready=false,Reason='Loading progress'}
end
Net.get('SetSettings').OnServerEvent:Connect(function(player,key,value)
 if intentLimit.allow(player) then DataService.setSetting(player,key,value) end
end)
for _,name in ipairs({'HatchCrew','EquipCrew','Rebirth','MoveOut','SelectMap'}) do
 Net.get(name).OnServerEvent:Connect(function(player)
  if intentLimit.allow(player) then Net.get('Notice'):FireClient(player,'This feature arrives in a later build milestone.') end
 end)
end
Players.PlayerRemoving:Connect(function(player) snapshotLimit.remove(player);intentLimit.remove(player) end)
DataService.start(map)
ReplicatedStorage:SetAttribute('FoundationReady',true)
ReplicatedStorage:SetAttribute('MapName',map.Name)
print('[Foundation] Ready: '..map.Name..'. Lobby training and skins enabled when present.')
