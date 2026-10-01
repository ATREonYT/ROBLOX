local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Data=require(script.Parent.DataService)
local Skins=require(RS.Shared.Config.Skins)
local Art=require(RS.Shared.SkinArt)
local Rules=require(RS.Shared.LobbyRules)
local Net=require(RS.Shared.Net)
while not RS:GetAttribute('FoundationReady') do task.wait(.1) end
local map=workspace:FindFirstChild('TheBlock');if not map or not map:FindFirstChild('SimulatorLobby') then return end
local f=CFrame.Angles(0,map:GetAttribute('MapYaw') or map.MapYawValue.Value,0)
local remote=Net.get('EquipSkin');local cooldown={};local applied={}
local function sync(player,profile,multiplier,station)
 local id=profile.Data.EquippedSkin;local s=Skins.ById[id] or Skins.List[1]
 player:SetAttribute('Power',profile.Data.Rep);player:SetAttribute('EquippedSkin',s.Id)
 player:SetAttribute('PowerRate',s.Gain*multiplier);player:SetAttribute('TrainingStation',station)
 local stats=player:FindFirstChild('leaderstats')
 if not stats then stats=Instance.new('Folder');stats.Name='leaderstats';stats.Parent=player;local p=Instance.new('NumberValue');p.Name='Power';p.Parent=stats end
 stats.Power.Value=profile.Data.Rep
end
local function equipAppearance(player,id)
 local c=player.Character
 if not c or not c:FindFirstChild('Head') or not c:FindFirstChild('Humanoid') then return end
 if not player:HasAppearanceLoaded() then return end
 if applied[player]~=c or c:GetAttribute('BlockSkin')~=id then
  Art.equip(c,Skins.ById[id] or Skins.List[1]);c:SetAttribute('BlockSkin',id);applied[player]=c
 end
end
remote.OnServerEvent:Connect(function(player,id)
 if type(id)~='string' or not Skins.ById[id] then return end
 local now=os.clock();if now-(cooldown[player] or 0)<.35 then return end;cooldown[player]=now
 local profile=Data.get(player);local c=player.Character;local root=c and c:FindFirstChild('HumanoidRootPart');local h=c and c:FindFirstChild('Humanoid')
 if not profile or not root or not h or h.Health<=0 then return end
 local stand=map.SimulatorLobby.Morphs:FindFirstChild('Skin_'..id);local target=stand and stand:FindFirstChild('Interact')
 if not target then return end
 local distance=(root.Position-target.Position).Magnitude
 if not Rules.canEquip(profile.Data.Rep,id,distance) then
  Net.get('Notice'):FireClient(player,distance>14 and 'Walk to this character display to equip it.' or ('Reach '..Skins.ById[id].Required..' Power to unlock this look.'));return
 end
 profile.Data.EquippedSkin=id;profile.Data.Onboarding.EquippedSkin=true
 equipAppearance(player,id);sync(player,profile,1,'');Data.push(player)
 Net.get('Notice'):FireClient(player,Skins.ById[id].Name..' equipped! +'..Skins.ById[id].Gain..' Power / second.')
end)
Players.PlayerRemoving:Connect(function(p) cooldown[p]=nil;applied[p]=nil end)
local boardTime=0
while task.wait(1) do
 local rows={}
 for _,player in Players:GetPlayers() do
  local profile=Data.get(player);local c=player.Character;local root=c and c:FindFirstChild('HumanoidRootPart');local h=c and c:FindFirstChild('Humanoid')
  if profile then
   local multiplier,station=1,''
   if root and h and h.Health>0 then
    multiplier,station=Rules.training(profile.Data.Rep,f:PointToObjectSpace(root.Position))
    profile.Data.Rep=math.min(1e12,profile.Data.Rep+Skins.gain(profile.Data.EquippedSkin,multiplier))
    if multiplier>1 then profile.Data.Onboarding.Trained=true end
    equipAppearance(player,profile.Data.EquippedSkin)
   end
   sync(player,profile,multiplier,station)
   table.insert(rows,{Name=player.DisplayName,Power=profile.Data.Rep})
  end
 end
 boardTime+=1
 if boardTime%5==0 then
  table.sort(rows,function(a,b) return a.Power>b.Power end)
  local lines={'BLOCK LEADERS','THIS SERVER'}
  for i=1,math.min(#rows,5) do table.insert(lines,string.format('%d. %s  /  %s',i,rows[i].Name,tostring(math.floor(rows[i].Power)))) end
  if #rows==0 then table.insert(lines,'Be the first to train!') end
  local label=map.SimulatorLobby.Leaderboards.ServerLeaderboard.Signage.TextLabel;label.Text=table.concat(lines,'\n')
 end
end
