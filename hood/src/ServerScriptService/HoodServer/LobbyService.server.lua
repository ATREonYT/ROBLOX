-- The lobby's ranges, every player's overhead tag, walk speed and the lobby boards, on whichever map is active (the
-- original Block's SimulatorLobby, or The Block V2). Brief 17:
--   * No Power per second. Power comes from shots only: here at the ranges, and at the stage targets (WaveService).
--     While you stand in an open lane's shooter's box, each shot (click, tap SHOOT or R2; Shoot.client fires the Shoot
--     remote) pays ShotRules: ShotBase x the lane's Multiplier x your rebirth multiplier x boosts, x your gun, x your
--     shoes (their fraction carries to the next shot), about 7 a second at most. A lane opens at its Rebirths
--     (Config/Skins.Stations); a shot in a locked lane pays nothing.
--   * Players keep their own Roblox avatar: no costume and no look. Walk speed rises a little with rebirths
--     (RebirthRules.walkSpeed), written only when it changes, so anything else that sets WalkSpeed isn't fought.
--   * The overhead tag: your name (gold with the VIP pass), your Power and your rebirths (Roblox's own name display is
--     turned off for it).
-- Player attributes kept here (a few times a second, and Power on every paid shot):
--   Power, Cash, Rebirths and the rebirth attributes (RebirthService.publish), TrainingStation ('' off the ranges,
--   '<Id>' in an open lane, 'Locked:<Id>' in a locked one), TrainingNeed (rebirths that locked lane needs, else 0),
--   BestLane (Id of your best open lane), ShotBase (what one shot pays before gun and shoes where you stand: x1 off
--   the ranges, which is what a stage target pays), ShotMultiplier (rebirth x gun x shoes x boosts: everything but the
--   lane). Also leaderstats Power and Rebirths.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Data=require(script.Parent.DataService)
local Boosts=require(script.Parent.Boosts)
local RebirthService=require(script.Parent.RebirthService)
local Rules=require(RS.Shared.LobbyRules)
local ShotRules=require(RS.Shared.ShotRules)
local RebirthRules=require(RS.Shared.RebirthRules)
local Skins=require(RS.Shared.Config.Skins)
local Net=require(RS.Shared.Net)
local Format=require(RS.Shared.Format)
local ActiveMap=require(RS.Shared.ActiveMap)
local RateLimiter=require(script.Parent.RateLimiter)
while not RS:GetAttribute('FoundationReady') do task.wait(.1) end
local active=ActiveMap.get();if not active then return end
local f=active.Frame;local lobby=active.Lobby
local zones=Rules.zonesFrom(lobby,f)
if #zones<#Skins.Stations then warn('[LobbyService] Only '..#zones..' of '..#Skins.Stations..' ranges found; rebuild the map.') end
-- (The looks are gone; an old client's EquipSkin request is ignored.)
Net.get('EquipSkin').OnServerEvent:Connect(function() end)

---------------------------------------------------------------------------------------------- overhead tag
-- Like the reference: your name small and white, "<Power> POWER" big in yellow-green, then "🔄 n REBIRTHS" in the
-- rebirth blue, all in LuckiestGuy with a dark outline. Sized in studs so it shrinks with distance.
local TAG_FONT=Font.new('rbxasset://fonts/families/LuckiestGuy.json')
local TAG_ROWS={
 {Name='User',Height=0.3,Color=Color3.fromRGB(240,242,248),Stroke=1.5},
 {Name='Power',Height=0.4,Color=Color3.fromRGB(205,245,70),Stroke=2},
 {Name='Rebirths',Height=0.3,Color=Color3.fromRGB(110,200,255),Stroke=1.8},
}
local function overheadTag(player,power,rebirths)
 local c=player.Character
 local head=c and c:FindFirstChild('Head')
 if not head then return end
 local tag=head:FindFirstChild('HoodTag')
 if not tag then
  tag=Instance.new('BillboardGui')
  tag.Name='HoodTag'
  tag.Size=UDim2.fromScale(6,2.3)
  tag.StudsOffset=Vector3.new(0,3,0)
  tag.MaxDistance=120
  tag.LightInfluence=0
  local y=0
  for _,row in TAG_ROWS do
   local t=Instance.new('TextLabel')
   t.Name=row.Name
   t.BackgroundTransparency=1
   t.Position=UDim2.fromScale(0,y)
   t.Size=UDim2.fromScale(1,row.Height)
   t.FontFace=TAG_FONT
   t.TextScaled=true
   t.TextColor3=row.Color
   local st=Instance.new('UIStroke')
   st.Color=Color3.fromRGB(28,24,48)
   st.Thickness=row.Stroke
   st.LineJoinMode=Enum.LineJoinMode.Round
   st.Parent=t
   t.Parent=tag
   y+=row.Height
  end
  tag.Parent=head
  -- Our tag carries the name: Roblox's own name over the head would sit on top of it.
  local h=c:FindFirstChildOfClass('Humanoid')
  if h then h.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None end
 end
 tag.User.Text=player.DisplayName
 tag.User.TextColor3=player:GetAttribute('Pass_VIP')==true and Color3.fromRGB(255,206,64) or TAG_ROWS[1].Color
 tag.Power.Text=Format.compact(power)..' POWER'
 tag.Rebirths.Text='🔄 '..rebirths..(rebirths==1 and ' REBIRTH' or ' REBIRTHS')
end

---------------------------------------------------------------------------------------------- attributes
local function set(player,name,value) if player:GetAttribute(name)~=value then player:SetAttribute(name,value) end end
local function stat(stats,class,name)
 local v=stats:FindFirstChild(name)
 if not v then v=Instance.new(class);v.Name=name;v.Parent=stats end
 return v
end
-- Where you stand now: the lane multiplier (0 locked, 1 off the ranges) and the TrainingStation value.
local function standing(player,rebirths)
 local c=player.Character;local root=c and c:FindFirstChild('HumanoidRootPart');local h=c and c:FindFirstChildOfClass('Humanoid')
 if not root or not h or h.Health<=0 then return 1,'' end
 return Rules.training(rebirths,f:PointToObjectSpace(root.Position),zones)
end
local function sync(player,profile,lane,station)
 local data=profile.Data
 local n=RebirthRules.count(data.Rebirths)
 RebirthService.publish(player,data)
 set(player,'Cash',data.Cash)
 set(player,'TrainingStation',station)
 set(player,'TrainingNeed',Rules.need(station,n))
 set(player,'BestLane',RebirthRules.bestLane(n).Id)
 local boost=Boosts.power(player)
 set(player,'ShotBase',ShotRules.perShot(math.max(lane,1),n,boost))
 local gun=player:GetAttribute('GunMultiplier');local shoes=player:GetAttribute('ShoeMultiplier')
 set(player,'ShotMultiplier',RebirthRules.multiplier(n)*boost*(type(gun)=='number' and gun or 1)*(type(shoes)=='number' and shoes or 1))
 local stats=player:FindFirstChild('leaderstats')
 if not stats then stats=Instance.new('Folder');stats.Name='leaderstats';stats.Parent=player end
 stat(stats,'NumberValue','Power').Value=data.Rep
 stat(stats,'IntValue','Rebirths').Value=n
end
-- Walk speed from rebirths, written when this character's speed should change (a new character or a rebirth).
local function walk(player,n)
 local c=player.Character;local h=c and c:FindFirstChildOfClass('Humanoid')
 if not h then return end
 local speed=RebirthRules.walkSpeed(n)
 if c:GetAttribute('RebirthWalkSpeed')~=speed then h.WalkSpeed=speed;c:SetAttribute('RebirthWalkSpeed',speed) end
end

---------------------------------------------------------------------------------------------- shooting
-- Where you stand is checked at the shot, against the same lane mats the attributes use.
local shotLimit=RateLimiter.new(ShotRules.Burst,ShotRules.PerSecond)
local shoeCarry={} -- (per player: the equipped shoes' fraction of a shot, carried to the next one; ShotRules.pay)
Net.get('Shoot').OnServerEvent:Connect(function(player)
 if not shotLimit.allow(player) then return end
 local profile=Data.get(player);local c=player.Character;local root=c and c:FindFirstChild('HumanoidRootPart');local h=c and c:FindFirstChildOfClass('Humanoid')
 if not profile or not root or not h or h.Health<=0 then return end
 local n=RebirthRules.count(profile.Data.Rebirths)
 local lane,station=Rules.training(n,f:PointToObjectSpace(root.Position),zones)
 if not ShotRules.counts(station) then return end -- (off the ranges, or a lane that needs more rebirths)
 shoeCarry[player]=shoeCarry[player] or {}
 local pay=ShotRules.pay(ShotRules.perShot(lane,n,Boosts.power(player)),player:GetAttribute('GunMultiplier'),player:GetAttribute('ShoeMultiplier'),shoeCarry[player])
 profile.Data.Rep=math.min(1e12,profile.Data.Rep+pay)
 profile.Data.Onboarding.Trained=true
 RebirthService.publish(player,profile.Data) -- (Power and RebirthReady at once, so the counter climbs with every shot)
end)
Players.PlayerRemoving:Connect(function(p) shotLimit.remove(p);shoeCarry[p]=nil end)

---------------------------------------------------------------------------------------------- loop
local beat=0
while task.wait(0.25) do
 beat+=1
 local rows={}
 for _,player in Players:GetPlayers() do
  local profile=Data.get(player)
  if profile then
   local n=RebirthRules.count(profile.Data.Rebirths)
   local lane,station=standing(player,n)
   sync(player,profile,lane,station)
   walk(player,n)
   if beat%4==0 then overheadTag(player,profile.Data.Rep,n) end
   table.insert(rows,{Name=player.DisplayName,Power=profile.Data.Rep,Cash=profile.Data.Cash,Rebirths=n})
  end
 end
 if beat%20==0 then
  -- The lobby boards: BLOCK LEADERS by rebirths then Power, TOP CASH (when the map has them).
  table.sort(rows,function(a,b) if a.Rebirths~=b.Rebirths then return a.Rebirths>b.Rebirths end return a.Power>b.Power end)
  local lines={'BLOCK LEADERS','THIS SERVER'}
  for i=1,math.min(#rows,5) do table.insert(lines,string.format('%d. %s  /  🔄%d  %s',i,rows[i].Name,rows[i].Rebirths,Format.compact(rows[i].Power))) end
  if #rows==0 then table.insert(lines,'Be the first to train!') end
  local board=lobby:FindFirstChild('ServerLeaderboard',true);local label=board and board:FindFirstChild('TextLabel',true)
  if label then label.Text=table.concat(lines,'\n') end
  local cashBoard=lobby:FindFirstChild('CashLeaderboard',true);local cashLabel=cashBoard and cashBoard:FindFirstChild('TextLabel',true)
  if cashLabel then
   table.sort(rows,function(a,b) return a.Cash>b.Cash end)
   local cash={'TOP CASH','THIS SERVER'}
   for i=1,math.min(#rows,5) do if rows[i].Cash>0 then table.insert(cash,string.format('%d. %s  /  %s',i,rows[i].Name,Format.compact(rows[i].Cash))) end end
   if #cash==2 then table.insert(cash,'Clear a gate to earn Cash!') end
   cashLabel.Text=table.concat(cash,'\n')
  end
 end
end
