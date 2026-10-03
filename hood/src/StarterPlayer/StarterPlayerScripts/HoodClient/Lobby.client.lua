local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Tween=game:GetService('TweenService')
local player=Players.LocalPlayer;local Skins=require(RS.Shared.Config.Skins);local Net=require(RS.Shared.Net)
-- Runs on whichever map is active (the original Block's SimulatorLobby, or The Block V2).
local ActiveMap=require(RS.Shared.ActiveMap)
local active=ActiveMap.wait(20);if not active then return end
local lobby=active.Lobby
local morphs=ActiveMap.find(lobby,'Morphs',20);if not morphs then return end
local training=lobby:FindFirstChild('Training') or lobby
local C=Color3.fromRGB;local gui=Instance.new('ScreenGui');gui.Name='ComeUpHUD';gui.ResetOnSpawn=false;gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.Parent=player:WaitForChild('PlayerGui')
local function round(p,r) local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,r);c.Parent=p end
local function label(parent,name,size,pos,textsize)
 local t=Instance.new('TextLabel');t.Name=name;t.Size=size;t.Position=pos;t.BackgroundTransparency=1;t.TextColor3=C(247,249,255);t.Font=Enum.Font.GothamBold;t.TextSize=textsize;t.TextWrapped=true;t.Parent=parent;return t
end
local panel=Instance.new('Frame');panel.Name='PowerCard';panel.Size=UDim2.fromOffset(220,112);panel.Position=UDim2.fromOffset(12,12);panel.BackgroundColor3=C(29,42,75);panel.BackgroundTransparency=.06;panel.Parent=gui;round(panel,14)
local scale=Instance.new('UIScale');scale.Parent=panel
local function resize() scale.Scale=workspace.CurrentCamera.ViewportSize.X<1000 and .68 or 1 end
workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Connect(resize);resize()
local title=label(panel,'Title',UDim2.new(1,-20,0,19),UDim2.fromOffset(10,8),13);title.Text='THE BLOCK  /  POWER';title.TextColor3=C(109,234,224)
local power=label(panel,'Power',UDim2.new(1,-20,0,35),UDim2.fromOffset(10,27),28)
local rate=label(panel,'Rate',UDim2.new(1,-20,0,24),UDim2.fromOffset(10,64),15)
local skinLabel=label(panel,'Skin',UDim2.new(1,-20,0,18),UDim2.fromOffset(10,88),12)
local tutorial=Instance.new('Frame');tutorial.Name='NextStep';tutorial.AnchorPoint=Vector2.new(.5,1);tutorial.Position=UDim2.new(.5,0,1,-14);tutorial.Size=UDim2.new(.50,0,0,76);tutorial.BackgroundColor3=C(29,42,75);tutorial.BackgroundTransparency=.07;tutorial.Parent=gui;round(tutorial,13)
local limit=Instance.new('UISizeConstraint');limit.MaxSize=Vector2.new(560,76);limit.MinSize=Vector2.new(265,76);limit.Parent=tutorial
local step=label(tutorial,'Instruction',UDim2.new(1,-24,0,41),UDim2.fromOffset(12,4),16)
local progress=label(tutorial,'Progress',UDim2.new(1,-24,0,17),UDim2.fromOffset(12,45),12)
local track=Instance.new('Frame');track.Size=UDim2.new(1,-24,0,5);track.Position=UDim2.new(0,12,1,-10);track.BackgroundColor3=C(72,87,120);track.BorderSizePixel=0;track.Parent=tutorial;round(track,3)
local fill=Instance.new('Frame');fill.Size=UDim2.fromScale(0,1);fill.BackgroundColor3=C(81,231,169);fill.BorderSizePixel=0;fill.Parent=track;round(fill,3)
local notice=label(gui,'Notice',UDim2.new(.6,0,0,48),UDim2.new(.2,0,0,10),17);notice.BackgroundColor3=C(38,55,86);notice.BackgroundTransparency=.05;notice.Visible=false;round(notice,12)
local noticeToken=0
Net.get('Notice').OnClientEvent:Connect(function(message)
 noticeToken+=1;local token=noticeToken;notice.Text=tostring(message);notice.Visible=true
 task.delay(3,function() if token==noticeToken then notice.Visible=false end end)
end)
local prompts={}
for _,s in Skins.List do
 local stand=morphs:WaitForChild('Skin_'..s.Id);local target=stand:WaitForChild('Interact')
 local p=Instance.new('ProximityPrompt');p.Name='Equip_'..s.Id;p.MaxActivationDistance=11;p.RequiresLineOfSight=false;p.HoldDuration=0;p.ObjectText=s.Name;p.ActionText='Equip';p.Parent=target
 p.Triggered:Connect(function() Net.get('EquipSkin'):FireServer(s.Id) end)
 prompts[s.Id]=p
end
local indicator=Instance.new('BillboardGui');indicator.Name='NextDestination';indicator.Size=UDim2.fromOffset(170,46);indicator.StudsOffset=Vector3.new(0,7,0);indicator.AlwaysOnTop=true;indicator.MaxDistance=150;indicator.ResetOnSpawn=false;indicator.Parent=player.PlayerGui
local pointer=label(indicator,'Destination',UDim2.fromScale(1,1),UDim2.fromScale(0,0),19);pointer.TextColor3=C(255,224,80);pointer.TextStrokeColor3=C(25,38,71);pointer.TextStrokeTransparency=0
local function compact(v)
 if v>=1e6 then return string.format('%.1fM',v/1e6) elseif v>=1000 then return string.format('%.1fK',v/1000) end;return tostring(math.floor(v))
end
-- Training stations in the built lobby: mat, sign, gear. Locked gear shows as a black silhouette.
local stations={}
for _,s in Skins.Stations do
 local model=training:FindFirstChild('Training_'..s.Id,true)
 if model then
  local entry={Zone=model:FindFirstChild('TrainingZone',true),Sign=model:FindFirstChild('Sign',true) or model:FindFirstChild('Nameplate',true),Parts={},Swing={}}
  local gear=model:FindFirstChild('Equipment')
  if gear then
   for _,p in gear:GetDescendants() do if p:IsA('BasePart') and p.Transparency<1 then table.insert(entry.Parts,{Part=p,Color=p.Color,Material=p.Material}) end end
   local hinge=gear:FindFirstChild('Hinge');local swing=gear:FindFirstChild('Swing')
   if hinge and swing then
    entry.Hinge=hinge.CFrame
    for _,p in swing:GetDescendants() do if p:IsA('BasePart') then table.insert(entry.Swing,{Part=p,Offset=hinge.CFrame:ToObjectSpace(p.CFrame)}) end end
   end
  end
  stations[s.Id]=entry
 end
end
local SILHOUETTE=C(18,18,22)
local function paintStations(n)
 for _,s in Skins.Stations do
  local e=stations[s.Id]
  if e then
   local locked=n<s.Required
   if e.Locked~=locked then
    e.Locked=locked
    for _,r in e.Parts do r.Part.Color=locked and SILHOUETTE or r.Color;r.Part.Material=locked and Enum.Material.SmoothPlastic or r.Material end
   end
   local detail=e.Sign and e.Sign:FindFirstChild('Detail',true)
   if detail then
    detail.Text=locked and ('LOCKED • '..compact(s.Required)..' POWER') or (s.Required==0 and 'FREE • TRAIN HERE' or 'UNLOCKED • TRAIN HERE')
    detail.TextColor3=locked and C(255,128,128) or C(126,255,171)
   end
  end
 end
end
local function zoneOf(id) local e=stations[id];return e and e.Zone end
local lastPower;local previouslyUnlocked={};local pulse
local function refresh()
 local n=player:GetAttribute('Power');if n==nil then power.Text='Loading...';step.Text='Getting your neighborhood ready';return end
 local id=player:GetAttribute('EquippedSkin') or 'CornerKid';local skin=Skins.ById[id] or Skins.List[1];local station=player:GetAttribute('TrainingStation') or '';local gain=player:GetAttribute('PowerRate') or skin.Gain
 power.Text=compact(n)..' POWER';rate.Text='+'..gain..' / SECOND'..(station~='' and not station:find('Locked:') and '  •  TRAINING' or '');rate.TextColor3=C(111,238,174);skinLabel.Text=skin.Name
 local best=Skins.List[1]
 for _,s in Skins.List do
  local unlocked=n>=s.Required;prompts[s.Id].ActionText=(id==s.Id and 'Equipped') or (unlocked and 'Equip  +'..s.Gain..'/sec') or (compact(s.Required)..' Power needed')
  local anchor=morphs['Skin_'..s.Id]:FindFirstChild('LabelAnchor')
  local detail=anchor and anchor:FindFirstChild('WorldLabel') and anchor.WorldLabel:FindFirstChild('Detail')
  if detail then
   -- Labels with their own Gain row (The Block V2's stand) keep the price, the action and the gain apart.
   local split=anchor.WorldLabel:FindFirstChild('Gain')
   detail.Text=split and (id==s.Id and 'EQUIPPED' or unlocked and 'EQUIP' or 'BUY') or (id==s.Id and 'EQUIPPED' or unlocked and 'EQUIP' or compact(s.Required)..' PWR')..' • +'..s.Gain..'/sec'
   detail.TextColor3=id==s.Id and C(255,126,119) or unlocked and C(109,244,133) or C(255,255,255)
  end
  if unlocked then best=s end
 end
 paintStations(n)
 local nextSkin=Skins.nextSkin(n)
 local bestGym=Skins.Stations[1];for _,g in Skins.Stations do if n>=g.Required then bestGym=g end end
 if station:find('Locked:') then
  local gym=Skins.StationById[station:sub(8)];step.Text=gym.Name..' needs '..compact(gym.Required)..' Power';indicator.Adornee=zoneOf(bestGym.Id);pointer.Text='TRAIN x'..bestGym.Multiplier..' HERE ↓'
 elseif best.Gain>skin.Gain then
  step.Text='New look unlocked! Equip '..best.Name;indicator.Adornee=morphs['Skin_'..best.Id].Interact;pointer.Text='EQUIP YOUR LOOK ↓'
 elseif station=='' then
  step.Text='Stand on the '..bestGym.Name..' mat to train faster';indicator.Adornee=zoneOf(bestGym.Id);pointer.Text='TRAIN x'..bestGym.Multiplier..' HERE ↓'
 else
  step.Text='Training x'..Skins.StationById[station].Multiplier..' — walk off to stop';indicator.Adornee=nil
 end
 progress.Text=nextSkin and (compact(n)..' / '..compact(nextSkin.Required)..'  →  '..nextSkin.Name) or 'ALL 15 LOOKS UNLOCKED — EXPLORE THE BLOCK'
 fill.Size=UDim2.fromScale(nextSkin and math.clamp(n/nextSkin.Required,0,1) or 1,1)
 if lastPower and n>lastPower then
  local c=player.Character;local head=c and c:FindFirstChild('Head')
  if head then
   if pulse then pulse:Destroy() end
   pulse=Instance.new('BillboardGui');pulse.Name='PowerGain';pulse.Size=UDim2.fromOffset(140,35);pulse.Adornee=head;pulse.StudsOffset=Vector3.new(0,3,0);pulse.AlwaysOnTop=true;pulse.ResetOnSpawn=false;pulse.Parent=player.PlayerGui
   local t=label(pulse,'Gain',UDim2.fromScale(1,1),UDim2.fromScale(0,0),23);t.Text='+'..compact(n-lastPower)..' POWER';t.TextColor3=C(126,255,171);t.TextStrokeTransparency=.1
   Tween:Create(t,TweenInfo.new(.8),{TextTransparency=1,TextStrokeTransparency=1}):Play()
  end
 end
 lastPower=n
end
for _,key in {'Power','EquippedSkin','TrainingStation','PowerRate'} do player:GetAttributeChangedSignal(key):Connect(refresh) end
refresh()

-- Only the bag you're training on sways, and only on your screen.
local lastStation=''
game:GetService('RunService').Heartbeat:Connect(function()
 local station=player:GetAttribute('TrainingStation') or ''
 local last=stations[lastStation]
 if lastStation~=station and last and last.Hinge then for _,r in last.Swing do r.Part.CFrame=last.Hinge*r.Offset end end
 lastStation=station
 local e=stations[station]
 if e and e.Hinge then
  local sway=e.Hinge*CFrame.Angles(math.sin(os.clock()*6)*.12,0,0)
  for _,r in e.Swing do r.Part.CFrame=sway*r.Offset end
 end
end)
