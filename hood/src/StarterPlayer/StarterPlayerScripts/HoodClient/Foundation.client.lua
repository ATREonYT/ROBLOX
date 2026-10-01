-- Studio-only review screen; not the production HUD (milestone 4).
local RunService=game:GetService('RunService')
if not RunService:IsStudio() then return end
local Players=game:GetService('Players')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local Net=require(ReplicatedStorage:WaitForChild('Shared'):WaitForChild('Net'))
local Format=require(ReplicatedStorage.Shared.Format)
local player=Players.LocalPlayer
local gui=Instance.new('ScreenGui')
gui.Name='FoundationReview';gui.ResetOnSpawn=false;gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.Parent=player:WaitForChild('PlayerGui')
local frame=Instance.new('Frame')
frame.Name='ReviewPanel';frame.AnchorPoint=Vector2.new(0.5,0);frame.Position=UDim2.new(0.5,0,0,8);frame.Size=UDim2.new(0.9,0,0,216);frame.BackgroundColor3=Color3.fromRGB(22,30,45);frame.Parent=gui
local constraint=Instance.new('UISizeConstraint');constraint.MaxSize=Vector2.new(490,216);constraint.Parent=frame
local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,12);corner.Parent=frame
local stroke=Instance.new('UIStroke');stroke.Color=Color3.fromRGB(97,110,127);stroke.Thickness=2;stroke.Parent=frame
local function label(name,text,y,height,size,color,font)
 local l=Instance.new('TextLabel');l.Name=name;l.Text=text;l.Position=UDim2.new(0,18,0,y);l.Size=UDim2.new(1,-36,0,height);l.BackgroundTransparency=1;l.TextColor3=color or Color3.fromRGB(234,238,242);l.Font=font or Enum.Font.BuilderSans;l.TextSize=size;l.TextXAlignment=Enum.TextXAlignment.Left;l.TextWrapped=true;l.Parent=frame;return l
end
label('Eyebrow','FROM THE BLOCK  /  FOUNDATION',12,20,13,Color3.fromRGB(242,182,50),Enum.Font.BuilderSansBold)
local heading=label('Heading','Loading your profile',36,32,25,nil,Enum.Font.FredokaOne)
local status=label('Status','Connecting to the server...',74,34,14)
local stats=label('Stats','REP  —     CASH  —',113,22,17,nil,Enum.Font.BuilderSansBold)
local button=Instance.new('TextButton');button.Name='MusicToggle';button.Position=UDim2.new(0,18,0,151);button.Size=UDim2.new(0,140,0,46);button.Text='Music: on';button.TextSize=16;button.Font=Enum.Font.BuilderSansBold;button.BackgroundColor3=Color3.fromRGB(242,182,50);button.TextColor3=Color3.fromRGB(22,30,45);button.Parent=frame
local bc=Instance.new('UICorner');bc.CornerRadius=UDim.new(0,8);bc.Parent=button
local count=label('Session','SESSION —',154,42,12);count.Position=UDim2.new(0,175,0,154);count.Size=UDim2.new(1,-193,0,42)
local current
local function apply(data)
 current=data;heading.Text=data.MapName
 status.Text=if data.DataMode=='Mock' then 'Studio preview · progress resets when Play stops.' else 'Persistent test data · rejoin to verify your setting.'
 stats.Text='REP  '..Format.compact(data.Rep)..'     CASH  '..Format.compact(data.Cash)
 button.Text=if data.Settings.Music then 'Music: on' else 'Music: off'
 count.Text='SESSION '..tostring(data.SessionLoadCount)..'\nGameplay is next'
end
Net.get('ProfileUpdated').OnClientEvent:Connect(apply)
Net.get('Notice').OnClientEvent:Connect(function(message) status.Text=message end)
button.Activated:Connect(function()
 if current then Net.get('SetSettings'):FireServer('Music',not current.Settings.Music) end
end)
for _=1,45 do
 if current then break end
 local ok,response=pcall(function() return Net.get('RequestSnapshot'):InvokeServer() end)
 if ok and response and response.Ready then apply(response.Profile);break end
 task.wait(1)
end
if not current then status.Text='Profile unavailable. Check Studio Output for the setup error.' end
