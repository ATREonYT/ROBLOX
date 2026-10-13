-- The lobby's ranges, every player's overhead tag, walk speed and the lobby boards, on whichever map is active (the
-- original Block's SimulatorLobby, or The Block V2). Brief 17:
--   * Power comes from shots only: here at the ranges, and at the stage goons (WaveService). At the ranges your gun
--     fires on its own (brief 18): while you stand in an open lane's shooter's box this server pays ShotRules.AutoRate
--     shots a second (each worth ShotRules.AutoValue shots: brief 32) on its own clock (ShotRules.autoShots; nobody clicks, no remote), each paying ShotRules: ShotBase x
--     the lane's Multiplier x your rebirth multiplier x boosts, x your gun, x your shoes (their fraction carries to the
--     next shot). Shoot.client shows the same shots. A lane opens at its Rebirths (Config/Skins.Stations); a locked lane
--     doesn't fire. The old Shoot remote is still there but pays nothing (old clients, no double pay).
--   * (brief 23) The two Robux lanes (PRO BAY x100, GOLD BAY x250: a Stations row with Pass) open and pay only with their
--     game pass, the Pass_<Key> attribute StoreService sets on the server (a client can't fake it). Stepping into one you
--     don't own shows that pass's purchase prompt (or the Notice "Coming soon!" while its id is 0), once per step-in.
--   * Players keep their own Roblox avatar: no costume and no look. Walk speed rises a little with rebirths
--     (RebirthRules.walkSpeed), written only when it changes, so anything else that sets WalkSpeed isn't fought.
--   * The overhead tag: your name (gold with the VIP pass), your Power and your rebirths (Roblox's own name display is
--     turned off for it).
-- Player attributes kept here (a few times a second, and Power on every paid shot):
--   Power, Cash, Rebirths and the rebirth attributes (RebirthService.publish), TrainingStation ('' off the ranges,
--   '<Id>' in an open lane, 'Locked:<Id>' in a locked one), TrainingNeed (rebirths that locked lane needs, else 0),
--   TrainingPass (the game-pass key the Robux lane you stand in needs and you don't own, else ''), BestLane (Id of your
--   best open lane, your lane passes counted), ShotBase (what one shot pays before gun and shoes where you stand: x1 off
--   the ranges, which is what a stage target pays), ShotMultiplier (rebirth x gun x shoes x boosts: everything but the
--   lane). Also leaderstats Power and Rebirths.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local MarketplaceService=game:GetService('MarketplaceService')
local Data=require(script.Parent.DataService)
local Boosts=require(script.Parent.Boosts)
local RebirthService=require(script.Parent.RebirthService)
local Rules=require(RS.Shared.LobbyRules)
local ShotRules=require(RS.Shared.ShotRules)
local LevelRules=require(RS.Shared.LevelRules)
local Levels=require(script.Parent.Levels) -- (brief 29: levels and ranks)
local FreeShot=require(script.Parent.FreeShot) -- (brief 29: every shot pays a little)
local HotTarget=require(script.Parent.HotTarget) -- (brief 29: the optional Hot Target bonus)
local RebirthRules=require(RS.Shared.RebirthRules)
local Skins=require(RS.Shared.Config.Skins)
local Products=require(RS.Shared.Config.Products)
local Net=require(RS.Shared.Net)
local Format=require(RS.Shared.Format)
local Fonts=require(RS.Shared.Fonts)
local ActiveMap=require(RS.Shared.ActiveMap)
while not RS:GetAttribute('FoundationReady') do task.wait(.1) end
local active=ActiveMap.get();if not active then return end
local f=active.Frame;local lobby=active.Lobby
local zones=Rules.zonesFrom(lobby,f)
if #zones<#Skins.Stations then warn('[LobbyService] Only '..#zones..' of '..#Skins.Stations..' ranges found; rebuild the map.') end
-- (The looks are gone; an old client's EquipSkin request is ignored.)
Net.get('EquipSkin').OnServerEvent:Connect(function() end)

---------------------------------------------------------------------------------------------- overhead tag
-- Like the reference: your name small and white, your RANK and LEVEL big in the rank's colour ("Hustler  Lv 17": brief 29,
-- levels instead of strength; Power is still what the lanes and the gates run on, under it), then "🔄 n REBIRTHS" in the
-- rebirth blue, all in the HUD's Montserrat Black (Shared/Fonts' Title; LOOP: was LuckiestGuy) with a dark outline.
-- Sized in studs so it shrinks with distance. (Waves.client hides your own on your screen; everyone else sees it.)
local TAG_FONT=Fonts.Title
local TAG_ROWS={
 {Name='User',Height=0.3,Color=Color3.fromRGB(240,242,248),Stroke=1.5},
 {Name='Power',Height=0.4,Color=Color3.fromRGB(205,245,70),Stroke=2},
 {Name='Rebirths',Height=0.3,Color=Color3.fromRGB(110,200,255),Stroke=1.8},
}
local function overheadTag(player,power,rebirths,bestLevel)
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
 tag.Power.Text=LevelRules.tag(bestLevel,power)
 tag.Power.TextColor3=Color3.fromHex(LevelRules.rankOf(bestLevel).Color)
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
 return Rules.training(rebirths,f:PointToObjectSpace(root.Position),zones,player) -- (player: its Pass_* attributes)
end
local function sync(player,profile,lane,station)
 local data=profile.Data
 local n=RebirthRules.count(data.Rebirths)
 RebirthService.publish(player,data)
 set(player,'Cash',data.Cash)
 set(player,'TrainingStation',station)
 set(player,'TrainingNeed',Rules.need(station,n))
 set(player,'TrainingPass',Rules.pass(station))
 set(player,'BestLane',RebirthRules.bestLane(n,player).Id)
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
 -- (brief 29, P5) the 2x Speed pass: exactly twice as fast (Products.SpeedPassFactor)
 if player:GetAttribute('Pass_Speed2x')==true then speed=speed*require(game:GetService('ReplicatedStorage').Shared.Config.Products).SpeedPassFactor end
 if c:GetAttribute('RebirthWalkSpeed')~=speed then h.WalkSpeed=speed;c:SetAttribute('RebirthWalkSpeed',speed) end
end

---------------------------------------------------------------------------------------------- shooting
-- The gun fires by itself in an open lane: each tick pays the shots due on the auto clock (ShotRules.autoShots), checked
-- where you stand now, against the same lane mats the attributes use.
local shoeCarry={} -- (per player: the equipped shoes' fraction of a shot, carried to the next one; ShotRules.pay)
local autoCarry={} -- (per player: the auto clock's fraction of a shot)
-- (brief 29, P4: "whenever you shoot, make it gain strength, but not as much as at a shooting range") A click off the ranges and
-- out of a fight (Shoot.client's free shot) pays a share through HoodServer/FreeShot (its own file, so the one write below
-- stays the only place this script pays a range shot); on a range or in a fight it pays nothing there.
Net.get('Shoot').OnServerEvent:Connect(function(player)
 local profile=Data.get(player)
 local c=player.Character;local root=c and c:FindFirstChild('HumanoidRootPart');local h=c and c:FindFirstChildOfClass('Humanoid')
 if not profile or not root or not h or h.Health<=0 then return end
 local _,station=standing(player,RebirthRules.count(profile.Data.Rebirths))
 shoeCarry[player]=shoeCarry[player] or {}
 FreeShot.click(player,profile,station,shoeCarry[player],RebirthService)
end)
local function autoFire(player,profile,lane,station,dt)
 autoCarry[player]=autoCarry[player] or {}
 local shots=ShotRules.autoShots(autoCarry[player],dt,station)
 if shots<=0 then return end
 local n=RebirthRules.count(profile.Data.Rebirths)
 shoeCarry[player]=shoeCarry[player] or {}
 local per=ShotRules.perShot(lane,n,Boosts.power(player))
 local gun,shoes=player:GetAttribute('GunMultiplier'),player:GetAttribute('ShoeMultiplier')
 local pay=0
 for _=1,shots do pay+=ShotRules.autoValue(ShotRules.pay(per,gun,shoes,shoeCarry[player]),autoCarry[player]) end -- (FEEL 32: each worth AutoValue shots)
 profile.Data.Rep=math.min(1e12,profile.Data.Rep+pay)
 profile.Data.Onboarding.Trained=true
 RebirthService.publish(player,profile.Data) -- (Power and RebirthReady at once, so the counter climbs with every shot)
end

---------------------------------------------------------------------------------------------- Robux lanes
-- Stepping into a Robux lane you don't own: its pass's purchase prompt (Products.canBuy: an id and Wired), else
-- "Coming soon!". Once per step-in, at most every 4 seconds (LobbyRules.offerDue). In a new player's quiet window
-- (OnboardingQuiet, HOOK's OnboardingService: no purchase prompt opens by itself) a Notice names the pass instead.
local offered={} -- (per player: the step-in state LobbyRules.offerDue keeps)
local function offer(player,pass)
 offered[player]=offered[player] or {}
 if not Rules.offerDue(offered[player],pass,os.clock()) then return end
 local entry=Products.ByKey[pass]
 if player:GetAttribute('OnboardingQuiet')==true then
  Net.get('Notice'):FireClient(player,'This lane opens with the '..(entry and entry.Title or 'lane')..' pass (Store)')
  return
 end
 if Products.canBuy(pass) then
  local ok,err=pcall(MarketplaceService.PromptGamePassPurchase,MarketplaceService,player,Products.idOf(pass))
  if ok then return end
  warn('[LobbyService] Could not prompt '..pass..': '..tostring(err))
 end
 Net.get('Notice'):FireClient(player,(entry and entry.Title or 'This lane')..': Coming soon!')
end
-- (brief 29) The optional Hot Target bonus: a hit from the corner panel (only while you train in an open range).
Net.get('HotTarget').OnServerEvent:Connect(function(player)
 local profile=Data.get(player)
 if not profile then return end
 local n=RebirthRules.count(profile.Data.Rebirths)
 local lane,station=standing(player,n)
 shoeCarry[player]=shoeCarry[player] or {}
 HotTarget.claim(player,profile,lane,station,shoeCarry[player],RebirthService)
end)
Players.PlayerRemoving:Connect(function(p) shoeCarry[p]=nil;autoCarry[p]=nil;offered[p]=nil;FreeShot.forget(p);HotTarget.forget(p) end)

---------------------------------------------------------------------------------------------- lobby boards
-- (brief 29) The three boards (TheBlockV2's Lobby.leaderboard): ten small rows of rank + name | main stat | second stat,
-- like the references' boards. Each board's model holds three TextLabels with RichText, one line per row: TextLabel (the
-- rank and the name), Values (the main stat) and Extra (the second stat). An older board with only a TextLabel (the original
-- Block's) still gets one plain list.
local BOARD_ROWS=10
local RANK_COLOR={'#FFD84A','#D0D8E8','#E8A068'}
local function plain(s) return (tostring(s):gsub('[<>&]','')) end
local function shortName(n) n=plain(n);local len=utf8.len(n);if len and len>8 then n=n:sub(1,utf8.offset(n,8)-1)..'.' end return n end
local BOARDS={
 {Live='PowerLeaderboard',Title='TOP POWER',Sort=function(a,b) return a.Power>b.Power end,
  Main=function(r) return Format.compact(r.Power) end,Extra=function(r) return tostring(r.Rebirths) end,Empty='Be the first to train!'},
 {Live='ServerLeaderboard',Title='TOP REBIRTHS',Sort=function(a,b) if a.Rebirths~=b.Rebirths then return a.Rebirths>b.Rebirths end return a.Power>b.Power end,
  Main=function(r) return tostring(r.Rebirths) end,Extra=function(r) return Format.compact(r.Power) end,Empty='Be the first to train!'},
 {Live='CashLeaderboard',Title='TOP CASH',Sort=function(a,b) return a.Cash>b.Cash end,Keep=function(r) return r.Cash>0 end,
  Main=function(r) return Format.compact(r.Cash) end,Extra=function(r) return r.Stage>0 and tostring(r.Stage) or '-' end,Empty='Clear a gate to earn Cash!'},
}
local function writeBoard(lobby,spec,rows)
 local model=lobby:FindFirstChild(spec.Live,true)
 local label=model and model:FindFirstChild('TextLabel',true)
 if not label then return end
 local list={}
 for _,r in rows do if not spec.Keep or spec.Keep(r) then table.insert(list,r) end end
 table.sort(list,spec.Sort)
 local values,extra=model:FindFirstChild('Values',true),model:FindFirstChild('Extra',true)
 if not (values and extra) then
  -- (the original Block's single-label board)
  local lines={spec.Title,'THIS SERVER'}
  for i=1,math.min(#list,5) do table.insert(lines,string.format('%d. %s  /  %s  %s',i,plain(list[i].Name),spec.Main(list[i]),spec.Extra(list[i]))) end
  if #list==0 then table.insert(lines,spec.Empty) end
  label.Text=table.concat(lines,'\n')
  return
 end
 if #list==0 then label.Text=spec.Empty;values.Text='';extra.Text='';return end
 local names,mains,extras={},{},{}
 for i=1,math.min(#list,BOARD_ROWS) do
  local r=list[i]
  names[i]=string.format('<font color="%s">%d</font>  %s',RANK_COLOR[i] or '#8FA3D8',i,shortName(r.Name))
  mains[i]=spec.Main(r)
  extras[i]=spec.Extra(r)
 end
 label.Text=table.concat(names,'\n');values.Text=table.concat(mains,'\n');extra.Text=table.concat(extras,'\n')
end
local beat=0
while true do
 local dt=task.wait(0.25)
 beat+=1
 local rows={}
 for _,player in Players:GetPlayers() do
  local profile=Data.get(player)
  if profile then
   local n=RebirthRules.count(profile.Data.Rebirths)
   local lane,station=standing(player,n)
   sync(player,profile,lane,station)
   offer(player,Rules.pass(station))
   autoFire(player,profile,lane,station,dt)
   walk(player,n)
   Levels.publish(player,profile.Data) -- (brief 29: Level, BestLevel and Rank, and the rank-up when a rank is crossed)
   if beat%4==0 then overheadTag(player,profile.Data.Rep,n,profile.Data.BestLevel) end
   local waves=profile.Data.Waves
   table.insert(rows,{Name=player.DisplayName,Power=profile.Data.Rep,Cash=profile.Data.Cash,Rebirths=n,Stage=type(waves)=='table' and tonumber(waves.Cleared) or 0})
  end
 end
 if beat%20==0 then
  -- The lobby boards: TOP POWER, TOP REBIRTHS (rebirths, then Power), TOP CASH (when the map has them).
  for _,spec in BOARDS do writeBoard(lobby,spec,rows) end
 end
end
