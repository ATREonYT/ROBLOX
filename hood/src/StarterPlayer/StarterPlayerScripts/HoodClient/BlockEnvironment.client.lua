-- Local visual motion avoids replicating the train's individual parts every frame.
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local TweenService=game:GetService('TweenService')
local player=Players.LocalPlayer
local map=workspace:WaitForChild('TheBlock',20)
if not map then return end
local yawValue=map:FindFirstChild('MapYawValue')
local f=CFrame.Angles(0,map:GetAttribute('MapYaw') or (yawValue and yawValue.Value) or 0,0)
local function point(v) return f:PointToWorldSpace(v) end
-- The spawn camera looks down the active map's street (The Block V2 when it is switched on).
local ActiveMap=require(game:GetService('ReplicatedStorage').Shared.ActiveMap)
local function faceArrival(character)
 local hrp=character:WaitForChild('HumanoidRootPart',10)
 if not hrp then return end
 task.wait(0.3)
 local active=ActiveMap.get()
 local view=active and active.Id=='V2' and CFrame.new() or f
 local camera=workspace.CurrentCamera
 camera.CFrame=CFrame.lookAt(hrp.Position+view:VectorToWorldSpace(Vector3.new(0,7,15)),hrp.Position+view:VectorToWorldSpace(Vector3.new(0,3,-24)))
end
player.CharacterAdded:Connect(faceArrival)
if player.Character then task.spawn(faceArrival,player.Character) end
local gui=Instance.new('ScreenGui');gui.Name='BlockWalkthrough';gui.ResetOnSpawn=false;gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.Parent=player:WaitForChild('PlayerGui')
local label=Instance.new('TextLabel');label.Name='Location';label.Size=UDim2.new(0,240,0,56);label.Position=UDim2.new(0,14,0,8);label.BackgroundTransparency=0.1;label.BackgroundColor3=Color3.fromRGB(25,39,46);label.TextColor3=Color3.fromRGB(242,220,172);label.Font=Enum.Font.BuilderSansBold;label.TextSize=16;label.Text='THE BLOCK\nYour come-up starts here';label.Parent=gui
if map:FindFirstChild('SimulatorLobby') then label.Visible=false end
local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,9);corner.Parent=label
-- (COMBAT: every game sound is behind Config/Sound, off for now: the street bed and the train rumble are nil while it is.)
local Sound=require(game:GetService('ReplicatedStorage').Shared.Config.Sound)
local city=Sound.new('rbxassetid://9112758500',0.12,game:GetService('SoundService'),{Name='JuniperCityBed',Looped=true});Sound.play(city)
local trainSound=Sound.new('rbxassetid://5870203641',0.22,nil,{Name='JuniperTrainRumble',RollOffMinDistance=15,RollOffMaxDistance=140})
local lastPhase=0
local start=os.clock();local train;local original;local neighbors={};local lastScan=0
RunService.Heartbeat:Connect(function()
 local now=workspace:GetServerTimeNow()
 if os.clock()-lastScan>2 then
  lastScan=os.clock()
  local life=map:FindFirstChild('Environment') and map.Environment:FindFirstChild('Life')
  if life then
   local nextTrain=life:FindFirstChild('JuniperTrain')
   if nextTrain~=train then train=nextTrain;original=train and train:GetPivot() end
   for _,n in ipairs(life:GetChildren()) do
    if n:IsA('Model') and (n:GetAttribute('AmbientIndex') or n:FindFirstChild('AmbientIndexValue')) and not neighbors[n] then neighbors[n]=n:GetPivot() end
   end
  end
 end
 if train and train.Parent and original then
  -- A bidirectional 52-second shuttle stays entirely on the authored track.
  local phase=now%52
  if trainSound and not trainSound.Parent then trainSound.Parent=train:FindFirstChild('TrainBody') end
  if phase<lastPhase then Sound.play(trainSound) end
  lastPhase=phase
  local offset
  if phase<20 then offset=60-phase/20*210
  elseif phase<26 then offset=-150
  elseif phase<46 then offset=-150+(phase-26)/20*210
  else offset=60 end
  train:PivotTo(CFrame.new(f:VectorToWorldSpace(Vector3.new(0,0,offset)))*original)
 end
 for n,base in pairs(neighbors) do
  if not n.Parent then neighbors[n]=nil
  else
   local i=n:GetAttribute('AmbientIndex') or n.AmbientIndexValue.Value
   local yaw=math.sin(now*0.6+i)*0.045
   n:PivotTo(base*CFrame.Angles(0,yaw,0))
  end
 end
 if label.Visible and os.clock()-start>12 then
  label.Visible=false
 end
end)
