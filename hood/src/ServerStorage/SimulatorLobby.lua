-- Compact courtyard at the actual start of The Block. Edit-time only.
local B={}
function B.Build()
 local r=workspace.TheBlock;local V=Vector3.new;local C=Color3.fromRGB
 local f=CFrame.Angles(0,r:GetAttribute('MapYaw') or r.MapYawValue.Value,0)
 local skins=require(game.ReplicatedStorage.Shared.Config.Skins);local art=require(game.ReplicatedStorage.Shared.SkinArt)
 local old=r:FindFirstChild('SimulatorLobby');if old then old:Destroy() end
 local m=Instance.new('Model');m.Name='SimulatorLobby';m.ModelStreamingMode=Enum.ModelStreamingMode.Persistent;m.Parent=r
 local gray=C(155,169,190);local trim=C(90,107,132);local light=C(202,213,228);local lime=C(151,216,73);local cyan=C(54,222,238);local gold=C(250,207,66)
 local function part(n,size,cf,color,parent,studs)
  local p=Instance.new('Part');p.Name=n;p.Size=size;p.CFrame=f*cf;p.Color=color;p.Material=Enum.Material.SmoothPlastic;p.Anchored=true;p.TopSurface=studs and Enum.SurfaceType.Studs or Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent or m;return p
 end
 local function box(n,s,p,c,parent,studs) return part(n,s,CFrame.new(p),c,parent,studs) end
 local function model(n) local a=Instance.new('Model');a.Name=n;a.Parent=m;return a end
 local function label(parent,pos,title,sub,color)
  local a=box('LabelAnchor',V(.1,.1,.1),pos,light,parent);a.Transparency=1;a.CanCollide=false
  local g=Instance.new('BillboardGui');g.Name='WorldLabel';g.Size=UDim2.fromScale(11,3.8);g.MaxDistance=100;g.AlwaysOnTop=false;g.Parent=a
  for i,text in ipairs({title,sub}) do
   local l=Instance.new('TextLabel');l.Name=i==1 and 'Title' or 'Detail';l.Size=UDim2.fromScale(1,.48);l.Position=UDim2.fromScale(0,(i-1)*.49);l.BackgroundTransparency=1;l.Font=Enum.Font.GothamBlack;l.TextScaled=true;l.TextColor3=i==1 and color or Color3.new(1,1,1);l.TextStrokeColor3=C(25,31,42);l.TextStrokeTransparency=0;l.Text=text;l.Parent=g
  end
  return a
 end
 local function cyl(n,rad,h,pos,col,parent)
  local p=part(n,V(h,rad*2,rad*2),CFrame.new(pos)*CFrame.Angles(0,0,math.pi/2),col,parent);p.Shape=Enum.PartType.Cylinder;return p
 end
 local backup=game.ServerStorage:FindFirstChild('BeforeBlockMap') or Instance.new('Folder');backup.Name='BeforeBlockMap';backup.Parent=game.ServerStorage
 local stoop=r.Architecture:FindFirstChild('WelcomeStoop');if stoop then stoop.Parent=backup end
 for _,p in r.FinishingDetails:GetChildren() do if p.Name=='WelcomeBoard' or p.Name=='BoardPost' then p.Parent=backup end end
 for _,p in r.FinishingDetails.WalkthroughBounds:GetChildren() do if p:IsA('BasePart') and f:PointToObjectSpace(p.Position).Z>120 then p.CFrame=f*CFrame.new(0,14,127) end end
 -- Begin the elevated railway beyond Stage 1, leaving the lobby open to the sky.
 local railBackup=backup:FindFirstChild('CourtyardRail') or Instance.new('Folder');railBackup.Name='CourtyardRail';railBackup.Parent=backup
 for _,p in r.ElevatedRail:GetDescendants() do
  if p:IsA('BasePart') then
   local localCF=f:ToObjectSpace(p.CFrame);local z=localCF.Position.Z
   if p.Size.Z>100 then
    local far=z-p.Size.Z/2;local near=z+p.Size.Z/2
    if near> -30 then p.Size=V(p.Size.X,p.Size.Y,-30-far);p.CFrame=f*(localCF+V(0,0,(far-30)/2-z)) end
   elseif z> -30 then p.Parent=railBackup end
  end
 end
 -- The courtyard occupies existing land, instead of adding a long approach.
 box('CourtyardLawn',V(150,.4,96),V(0,.85,73),lime,nil,true)
 box('CenterPathBorder',V(19,.22,96),V(0,1.13,73),trim)
 box('CenterPath',V(16,.24,96),V(0,1.27,73),light,nil,true)
 box('CrossPathBorder',V(139,.22,13),V(0,1.14,87),trim)
 box('CrossPath',V(137,.24,10),V(0,1.28,87),light,nil,true)
 box('SpawnTile',V(12,.1,12),V(0,1.45,87),gray,nil,true)
 for _,side in {-1,1} do
  part('SpawnInlay',V(.28,.03,11),CFrame.new(0,1.51,87)*CFrame.Angles(0,side*math.pi/4,0),trim)
 end
 -- One shared three-tier pedestal, five normal-sized morphs per row.
 local xvalues={22,32,42,52,62}
 local pedestal=model('SharedMorphPedestal')
 for row=0,2 do
  local z=70-row*13;local y=2.0+row*3.8
  box('DisplayTier',V(50,y,13),V(42,y/2+1.05,z),gray,pedestal,true)
  box('TierRim',V(50.5,.25,13.4),V(42,y+1.1,z),light,pedestal,true)
  for col=1,5 do
   local s=skins.List[row*5+col];local x=xvalues[col];local base=y+1.25
   local stand=model('Skin_'..s.Id)
   local accent=row==0 and C(248,222,121) or row==1 and C(206,108,226) or C(237,193,67)
   box('IndividualPlinth',V(6.6,.27,5.7),V(x,base+.13,z),row==1 and C(68,64,80) or C(222,225,214),stand)
   box('PlinthTrim',V(6.8,.12,5.9),V(x,base+.03,z),accent,stand)
   local pad=box('UnlockPad',V(5.6,.08,4.7),V(x,base+.31,z),cyan,stand);pad.Material=Enum.Material.Neon
   art.mannequin(stand,f*CFrame.new(x,base+.36,z)*CFrame.Angles(0,math.pi,0),s,.94)
   local nameAnchor=label(stand,V(x,base+7.1,z),s.Name,(s.Required==0 and 'FREE' or tostring(s.Required))..' • +'..s.Gain..'/sec',gold)
   nameAnchor.WorldLabel.Size=UDim2.fromScale(7,1.9)
   local target=box('Interact',V(2,.1,2),V(x,base+.5,z+3.8),cyan,stand);target.Transparency=1;target.CanCollide=false
  end
 end
 for _,x in {13.5,70.5} do
  for i=1,16 do box('DisplayStair',V(6,i*.65,2.9),V(x,1.05+i*.325,81-i*2.8),gray,pedestal,true) end
 end
 label(m,V(42,23,34),'THE COME-UP','15 MORPHS • ONE BLOCK',cyan)
 -- Gym cluster at normal avatar scale; each pad has one clear piece of equipment.
 for _,s in skins.Stations do
  local gym=model('Training_'..s.Id);local x,z=s.X,s.Z
  box('GymFoundation',V(18,.65,18),V(x,1.38,z),trim,gym,true)
  local pad=box('TrainingZone',V(16,.2,16),V(x,1.8,z),s.Color,gym,true)
  for _,dx in {-8.4,8.4} do box('PadEdging',V(.25,.2,17),V(x+dx,1.86,z),light,gym) end
  if s.Id~='Street' then
   for _,dx in {-5,5} do box('GymPost',V(.45,8.5,.45),V(x+dx,6.1,z-3),trim,gym) end
   box('PullupBar',V(11,.45,.45),V(x,10.3,z-3),trim,gym)
   box('BagChain',V(.1,1.6,.1),V(x,9.35,z-3),light,gym)
   cyl('PunchBag',1.4,4.1,V(x,6.5,z-3),s.Id=='Boss' and gold or C(184,103,65),gym)
   for _,yy in {5.1,7.9} do cyl('BagBelt',1.43,.25,V(x,yy,z-3),trim,gym) end
  else
   box('BenchSeat',V(2.7,.5,6),V(x,3.2,z),C(55,84,115),gym)
   for _,zz in {-2,2} do box('BenchLeg',V(2,.9,.5),V(x,2.4,z+zz),trim,gym) end
   for _,dx in {-3.5,3.5} do box('RackStem',V(.35,4,.35),V(x+dx,3.8,z-3),trim,gym) end
   box('Barbell',V(10,.3,.3),V(x,5.8,z-3),light,gym)
   for _,dx in {-3.7,-4.4,3.7,4.4} do local p=part('WeightPlate',V(.5,2.5,2.5),CFrame.new(x+dx,5.8,z-3),trim,gym);p.Shape=Enum.PartType.Cylinder end
  end
  label(gym,V(x,s.Id=='Boss' and 18 or 13,z-2),'x'..s.Multiplier..' POWER',s.Required==0 and 'FREE • Train here' or tostring(s.Required)..' Power needed',s.Id=='Boss' and gold or Color3.new(1,1,1))
 end
 -- Low brick walls and blocky trees echo the reference's enclosed, studded courtyard.
 for _,side in {-1,1} do
  for z=34,112,13 do
   local wall=box('BrickGardenWall',V(3,10+(z%3)*2,13),V(side*76,5,z),C(176,111,78),nil,true);wall.FrontSurface=Enum.SurfaceType.Studs;wall.BackSurface=Enum.SurfaceType.Studs
   box('GrassWallCap',V(5,.8,13),V(side*76,wall.Size.Y/2+5.4,z),lime,nil,true)
  end
  for _,z in {36,100} do
   box('TreeTrunk',V(1.6,8,1.6),V(side*69,5,z),C(128,84,53))
   for i=1,3 do box('BlockTreeCrown',V(9-i,3,8-i),V(side*69+(i%2==0 and 2 or -1),8+i*2,z),({C(104,184,66),C(138,210,73),C(166,226,92)})[i],nil,true) end
  end
 end
 -- Entry is adjacent to the first obstacle; preserve the avenue beyond it.
 for _,x in {-13,13} do box('EntryBrickPillar',V(3,12,4),V(x,6.9,26),C(178,112,77),nil,true);box('EntryCap',V(4,.65,5),V(x,13.1,26),lime,nil,true) end
 label(m,V(0,13.3,26),'THE BLOCK','STAGE 1',cyan)
 -- Compact leaderboard placed at the edge, not across the player's view.
 local board=part('ServerLeaderboard',V(12,9,.6),CFrame.new(-62,7,34)*CFrame.Angles(0,math.pi,0),trim)
 local gui=Instance.new('SurfaceGui');gui.Name='Signage';gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud;gui.PixelsPerStud=30;gui.LightInfluence=0;gui.Parent=board
 local t=Instance.new('TextLabel');t.Name='TextLabel';t.Size=UDim2.fromScale(.9,.9);t.Position=UDim2.fromScale(.05,.05);t.BackgroundTransparency=1;t.Font=Enum.Font.GothamBold;t.TextScaled=true;t.TextWrapped=true;t.TextColor3=light;t.Text='BLOCK LEADERS\nTHIS SERVER';t.Parent=gui
 for _,x in {-67,-57} do box('BoardLeg',V(.6,3,.6),V(x,2.4,34),trim) end
 -- Explicit raised studs remain visible with modern material settings.
 local studs=model('StudDetails');local surfaces={}
 for _,p in m:GetDescendants() do
  if p:IsA('BasePart') and (p.Name=='CourtyardLawn' or p.Name=='CenterPath' or p.Name=='CrossPath' or p.Name=='TierRim' or p.Name=='TrainingZone') then table.insert(surfaces,p) end
 end
 for _,surface in surfaces do
  local grass=surface.Name=='CourtyardLawn';local step=grass and 3 or 1.8;local cf=f:ToObjectSpace(surface.CFrame)
  for x=-surface.Size.X/2+1,surface.Size.X/2-1,step do for z=-surface.Size.Z/2+1,surface.Size.Z/2-1,step do
   local stud=part('Stud',V(.55,.085,.55),cf*CFrame.new(x,surface.Size.Y/2+.04,z),surface.Color:Lerp(Color3.new(1,1,1),.08),studs)
   stud.CanCollide=false;stud.CanTouch=false;stud.CanQuery=false;stud.CastShadow=false
  end end
 end
 local spawn=r.BlockArrival;spawn.CFrame=f*CFrame.new(0,1.7,91);spawn.Size=V(7,.2,7)
 local l=game.Lighting;l.ClockTime=13.8;l.Brightness=2;l.ExposureCompensation=0;l.Ambient=C(132,139,155);l.OutdoorAmbient=C(160,169,183);l.ColorShift_Top=C(255,250,238);l.ColorShift_Bottom=C(180,193,218)
 local at=l:FindFirstChild('BlockAtmosphere');if at then at.Density=.22;at.Haze=1;at.Color=C(215,232,249) end
 local grade=l:FindFirstChild('BlockGrade');if grade then grade.Saturation=.02;grade.Contrast=.03;grade.TintColor=Color3.new(1,1,1) end
 local bloom=l:FindFirstChild('BlockBloom');if bloom then bloom.Intensity=.06 end
 workspace.CurrentCamera.CFrame=CFrame.lookAt(f:PointToWorldSpace(V(0,18,112)),f:PointToWorldSpace(V(0,5,49)))
 game:GetService('ChangeHistoryService'):SetWaypoint('Compact reference-led courtyard')
 return {spawnZ=91,firstStageZ=26,lobbyWidth=150,lobbyDepth=96}
end
return B
