-- The Block: deterministic edit-time environment builder. Never runs during gameplay.
-- Run Build phases in Studio. Output geometry is saved in Workspace.TheBlock.
local B={}
local V=Vector3.new
local C=Color3.fromRGB
local P={brick=C(139,74,58),red=C(110,59,48),tan=C(184,150,110),soot=C(99,79,68),stone=C(168,157,134),cream=C(230,213,174),asphalt=C(58,58,60),walk=C(156,154,147),steel=C(49,67,62),iron=C(36,43,43),yellow=C(242,182,50),green=C(46,139,87),navy=C(25,39,46),wood=C(111,82,53),leaf=C(77,109,59),orange=C(208,107,49)}
local function model(parent,name)
 local m=Instance.new('Model');m.Name=name;m.Parent=parent;return m
end
local function part(parent,name,size,cf,color,material,shape)
 local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=cf;p.Color=color or P.stone;p.Material=material or Enum.Material.Concrete;p.Anchored=true;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
 if shape then p.Shape=shape end
 p.Parent=parent;return p
end
local function box(parent,name,size,pos,color,material) return part(parent,name,size,CFrame.new(pos),color,material) end
local function ball(parent,name,size,pos,color,material) return part(parent,name,size,CFrame.new(pos),color,material,Enum.PartType.Ball) end
local function cylinder(parent,name,r,h,cf,color,mat)
 return part(parent,name,V(h,r*2,r*2),cf*CFrame.Angles(0,0,math.pi/2),color,mat or Enum.Material.Metal,Enum.PartType.Cylinder)
end
local function beam(parent,name,a,b,width,color,mat)
 return part(parent,name,V(width,width,(b-a).Magnitude),CFrame.lookAt((a+b)/2,b),color,mat or Enum.Material.Metal)
end
local function textFace(p,text,color,face,font)
 local gui=Instance.new('SurfaceGui');gui.Name='Signage';gui.Face=face or Enum.NormalId.Front;gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud;gui.PixelsPerStud=35;gui.LightInfluence=0.8;gui.AlwaysOnTop=false;gui.Parent=p
 local label=Instance.new('TextLabel');label.Size=UDim2.fromScale(0.94,0.9);label.Position=UDim2.fromScale(0.03,0.05);label.BackgroundTransparency=1;label.Font=font or Enum.Font.Oswald;label.Text=text;label.TextColor3=color or P.cream;label.TextScaled=true;label.TextWrapped=true;label.Parent=gui
 return gui
end
local function sign(parent,name,cf,size,bg,text,fg)
 local p=part(parent,name,size,cf,bg,Enum.Material.Metal);textFace(p,text,fg);return p
end
local function point(parent,color,brightness,range)
 local l=Instance.new('PointLight');l.Color=color;l.Brightness=brightness;l.Range=range;l.Shadows=false;l.Parent=parent;return l
end
local function root() return assert(workspace:FindFirstChild('TheBlock'),'Build layout first') end
local function phase(name)
 local r=root();local old=r:FindFirstChild(name);if old then old:Destroy() end;return model(r,name)
end
local function facpart(m,frame,name,size,pos,color,material)
 return part(m,name,size,frame*CFrame.new(pos),color,material)
end
local function facadeSign(m,frame,name,x,y,z,w,h,bg,label,fg)
 return sign(m,name,frame*CFrame.new(x,y,z),V(w,h,0.35),bg,label,fg)
end
local function lamp(parent,pos,short)
 local m=model(parent,'StreetLamp');local h=short and 10 or 16
 cylinder(m,'CastBase',0.6,0.6,CFrame.new(pos+V(0,0.3,0)),P.iron)
 cylinder(m,'Pole',0.2,h,CFrame.new(pos+V(0,h/2,0)),P.iron)
 local globe=ball(m,'WarmGlobe',V(1.5,1.7,1.5),pos+V(0,h,0),C(255,221,161),Enum.Material.Neon)
 cylinder(m,'Crown',0.9,0.2,CFrame.new(pos+V(0,h+1,0)),P.iron)
 point(globe,C(255,204,144),0.65,19)
 return m
end
local function bench(parent,pos,yaw)
 local m=model(parent,'ParkBench');local f=CFrame.new(pos)*CFrame.Angles(0,yaw or 0,0)
 for _,x in ipairs({-2.4,2.4}) do facpart(m,f,'IronLeg',V(0.3,1.6,1.6),V(x,0.8,0),P.iron,Enum.Material.Metal) end
 for i=-1,1 do facpart(m,f,'SeatSlat',V(6,0.22,0.45),V(0,1.7,i*0.55),P.wood,Enum.Material.WoodPlanks) end
 for i=0,2 do facpart(m,f,'BackSlat',V(6,0.35,0.2),V(0,2.25+i*0.5,0.7),P.wood,Enum.Material.WoodPlanks) end
 return m
end
function B.BuildLayout()
 local ss=game:GetService('ServerStorage')
 local backup=ss:FindFirstChild('BeforeBlockMap') or Instance.new('Folder');backup.Name='BeforeBlockMap';backup.Parent=ss
 for _,n in ipairs({'Baseplate','SpawnLocation','FoundationPlatform'}) do local p=workspace:FindFirstChild(n);if p then p.Parent=backup end end
 local old=workspace:FindFirstChild('TheBlock');if old then old:Destroy() end
 local r=model(workspace,'TheBlock');r:SetAttribute('BuildSeed',73017);r:SetAttribute('MapId','Block');r:SetAttribute('BuildVersion','Environment 1')
 local ground=model(r,'Ground')
 box(ground,'NeighborhoodFoundation',V(400,5,770),V(0,-3,-255),P.soot,Enum.Material.Ground)
 box(ground,'TheAveAsphalt',V(44,0.6,680),V(0,-0.3,-280),P.asphalt,Enum.Material.Asphalt)
 box(ground,'HubCrossStreet',V(350,0.6,34),V(0,-0.28,69),P.asphalt,Enum.Material.Asphalt)
 for _,side in ipairs({-1,1}) do
  box(ground,'Sidewalk',V(12,0.8,648),V(side*28,0.4,-294),P.walk,Enum.Material.Concrete)
  box(ground,'StoopApron',V(8,0.8,650),V(side*38,0.4,-294),C(142,139,129),Enum.Material.Pavement)
  for z=24,-615,-12 do box(ground,'SidewalkExpansionJoint',V(11.8,0.018,0.055),V(side*28,0.81,z),C(107,106,100),Enum.Material.Concrete) end
  box(ground,'CurbCap',V(0.6,0.8,650),V(side*22.3,0.4,-294),C(183,178,163),Enum.Material.Concrete)
  for z=15,-590,-28 do box(ground,'ParkingLine',V(0.14,0.018,15),V(side*16,0.018,z),C(188,183,158),Enum.Material.Concrete) end
 end
 for z=12,-602,-28 do for _,x in ipairs({-0.3,0.3}) do box(ground,'Centerline',V(0.13,0.02,15),V(x,0.015,z),C(221,179,79),Enum.Material.Concrete) end end
 for _,z in ipairs({40,-180,-390}) do for x=-18,18,6 do box(ground,'CrosswalkPaint',V(3.8,0.022,7),V(x,0.02,z),C(213,206,183),Enum.Material.Concrete) end end
 box(ground,'HubPlaza',V(90,0.8,72),V(-94,0.4,17),C(149,138,117),Enum.Material.Pavement)
 box(ground,'CourtApron',V(96,0.8,105),V(100,0.4,0),P.walk,Enum.Material.Concrete)
 box(ground,'WelcomeSidewalk',V(350,0.8,19),V(0,0.4,96),P.walk,Enum.Material.Concrete)
 local markers=model(r,'LayoutMarkers')
 for i=1,10 do
  local z=5-(i-1)*64
  local p=box(markers,'Wall'..i,V(32,0.04,3),V(0,0.05,z),P.yellow,Enum.Material.Concrete)
  p.Transparency=1;p.CanCollide=false;p.CanTouch=false;p:SetAttribute('WallIndex',i);p:SetAttribute('MapId','Block')
 end
 local spawn=Instance.new('SpawnLocation');spawn.Name='BlockArrival';spawn.Size=V(7,0.2,5);spawn.Anchored=true;spawn.Neutral=true;spawn.Transparency=1;spawn.CanCollide=false;spawn.Duration=0;spawn.CFrame=CFrame.new(0,1.1,91)*CFrame.Angles(0,0,0);spawn.Parent=r
 -- Testable, broad walking surface. No progression gates are made functional in the art pass.
 local el=model(r,'ElevatedRail')
 for _,x in ipairs({-18,18}) do
  box(el,'RivetedLongGirder',V(0.8,2.8,722),V(x,34.5,-285),P.steel,Enum.Material.Metal)
  box(el,'GirderCap',V(1.6,0.22,722),V(x,36,-285),C(68,82,72),Enum.Material.Metal)
 end
 for z=28,-632,-40 do
  for _,x in ipairs({-19.5,19.5}) do
   box(el,'ColumnFooting',V(2.6,0.6,2.6),V(x,0.3,z),P.stone,Enum.Material.Concrete)
   box(el,'ColumnWeb',V(0.5,31.8,0.85),V(x,16.5,z),P.steel,Enum.Material.Metal)
   for _,dx in ipairs({-0.55,0.55}) do box(el,'ColumnFlange',V(0.2,31.8,1.5),V(x+dx,16.5,z),P.steel,Enum.Material.Metal) end
   beam(el,'KneeBrace',V(x,27,z),V(x-math.sign(x)*6,32.8,z),0.6,P.steel)
   for _,y in ipairs({3,15,27}) do box(el,'ColumnRivetPlate',V(1.4,1.2,0.12),V(x,y,z+0.82),C(67,79,70),Enum.Material.Metal) end
  end
  box(el,'CrossGirder',V(41,1.6,1.2),V(0,32.6,z),P.steel,Enum.Material.Metal)
 end
 for z=60,-640,-4 do box(el,'RailSleeper',V(35,0.48,0.7),V(0,35.8,z),C(82,70,55),Enum.Material.WoodPlanks) end
 for _,x in ipairs({-12,-5,5,12}) do box(el,'PolishedRail',V(0.28,0.45,725),V(x,36.3,-285),C(135,138,135),Enum.Material.Metal) end
 for _,x in ipairs({-16,16}) do box(el,'MaintenanceWalk',V(2,0.2,725),V(x,36.2,-285),P.steel,Enum.Material.DiamondPlate) end
 workspace.StreamingEnabled=true
 return 'Layout complete: 44-stud road, 12-stud sidewalks, 10 markers, 36-stud elevated rail.'
end
local function makeWindow(parent,frame,x,y,lit)
 local pane=facpart(parent,frame,'InsetWindow',V(3.5,5,0.16),V(x,y,0.55),lit and C(191,153,98) or C(47,66,68),Enum.Material.Glass)
 pane.Reflectance=0.12
 for _,dx in ipairs({-1.92,1.92}) do facpart(parent,frame,'WindowJamb',V(0.28,5.6,0.7),V(x+dx,y,0.16),P.cream,Enum.Material.Concrete) end
 facpart(parent,frame,'Sill',V(4.35,0.4,1.05),V(x,y-2.7,-0.05),P.stone,Enum.Material.Concrete)
 facpart(parent,frame,'Lintel',V(4.3,0.45,0.8),V(x,y+2.8,0),P.cream,Enum.Material.Concrete)
 facpart(parent,frame,'Sash',V(3.5,0.14,0.16),V(x,y,0.38),C(126,132,117),Enum.Material.Wood)
end
local function fireEscape(m,f,w,stories)
 for floor=1,stories-1 do
  local y=12+floor*11.6
  facpart(m,f,'EscapeLanding',V(9,0.22,3.5),V(0,y,-1.9),P.iron,Enum.Material.DiamondPlate)
  for _,x in ipairs({-4.4,4.4}) do facpart(m,f,'RailUpright',V(0.14,2.6,0.14),V(x,y+1.3,-3.5),P.iron,Enum.Material.Metal) end
  facpart(m,f,'EscapeHandrail',V(9,0.14,0.14),V(0,y+2.6,-3.5),P.iron,Enum.Material.Metal)
  for x=-3.2,3.2,1.6 do facpart(m,f,'EscapeRail',V(0.11,2.5,0.11),V(x,y+1.25,-3.5),P.iron,Enum.Material.Metal) end
  if floor<stories-1 then
   local direction=if floor%2==0 then 1 else -1
   for s=0,10 do facpart(m,f,'EscapeStep',V(1.8,0.15,0.65),V(direction*(-3+s*0.6),y+s*1.05,-2.1),P.iron,Enum.Material.Metal) end
   for _,dz in ipairs({-1.15,-3.05}) do beam(m,'EscapeStringer',f:PointToWorldSpace(V(-3*direction,y,dz)),f:PointToWorldSpace(V(3*direction,y+11.6,dz)),0.17,P.iron) end
  end
 end
end
local function building(parent,frame,width,stories,tone,storeName,awning,escape,seed)
 local m=model(parent,storeName or 'WalkUp');local h=12+stories*11.6;local d=28
 local rng=Random.new(seed)
 -- Shell is behind the inset glazing. Separate piers and spandrels create real depth.
 facpart(m,frame,'RearMass',V(width,h,d-2),V(0,h/2,d/2+2),tone,Enum.Material.Brick)
 for _,x in ipairs({-width/2+0.6,width/2-0.6}) do facpart(m,frame,'CornerPier',V(1.2,h,2),V(x,h/2,0.7),tone,Enum.Material.Brick) end
 facpart(m,frame,'StoneBase',V(width,1.8,2),V(0,1.7,0.6),P.stone,Enum.Material.Concrete)
 local bays=math.floor(width/7)
 local spacing=(width-4)/bays
 for floor=1,stories do
  local y=11.8+(floor-1)*11.6
  facpart(m,frame,'FloorSpandrel',V(width,6,1.6),V(0,y+1.7,0.8),tone,Enum.Material.Brick)
  for j=0,bays do
   local x=-width/2+2+j*spacing
   facpart(m,frame,'WindowPier',V(math.max(1,spacing-3.6),5.8,1.6),V(x,y+7.4,0.8),tone,Enum.Material.Brick)
  end
  for j=1,bays do local x=-width/2+2+(j-0.5)*spacing;makeWindow(m,frame,x,y+7.4,rng:NextNumber()<0.22) end
 end
 for _,band in ipairs({{h-0.3,1.2,0.8},{h+0.5,0.45,1.8},{h+0.95,0.25,2.1}}) do facpart(m,frame,'Cornice',V(width+band[3],band[2],2.7),V(0,band[1],0.3),P.stone,Enum.Material.Concrete) end
 facpart(m,frame,'Roof',V(width+0.6,0.3,d),V(0,h+0.15,d/2+1),C(80,78,68),Enum.Material.Asphalt)
 -- Shopfront: 8-stud door and deep dark window bays with framing.
 for _,x in ipairs({-width/2+1.2,0,width/2-1.2}) do facpart(m,frame,'ShopPier',V(1.1,9,1.9),V(x,5.3,0.3),P.stone,Enum.Material.Concrete) end
 facpart(m,frame,'ShopRecess',V(width-2,8,0.25),V(0,5.2,0.9),P.navy,Enum.Material.Glass)
 facpart(m,frame,'ShopDoor',V(4.5,8,0.3),V(width/2-4.5,4.9,0.35),C(42,55,51),Enum.Material.Wood)
 facpart(m,frame,'DoorHandle',V(0.12,1.2,0.2),V(width/2-6,4.9,0.1),C(186,166,101),Enum.Material.Metal)
 facadeSign(m,frame,'StoreHeader',0,10.9,-0.7,width-1,2.2,awning,storeName or 'NEIGHBORHOOD GOODS',P.cream)
 local canopy=facpart(m,frame,'FabricAwning',V(width-1,0.22,4.5),V(0,8.9,-1.5),awning,Enum.Material.Fabric);canopy.CFrame*=CFrame.Angles(math.rad(10),0,0)
 facpart(m,frame,'AwningValance',V(width-1,0.8,0.18),V(0,8.15,-3.65),awning,Enum.Material.Fabric)
 for x=-width/2+3,width/2-2,4 do facpart(m,frame,'AwningStripe',V(0.6,0.03,4.4),V(x,9.07,-1.5),P.cream,Enum.Material.Fabric).CFrame*=CFrame.Angles(math.rad(10),0,0) end
 facadeSign(m,frame,'Address',width/2-4.5,9.15,-0.65,2,0.65,P.iron,tostring(101+seed%700),P.cream)
 if escape then fireEscape(m,frame,width,stories) end
 if seed%3==0 then
  for k=1,2 do facpart(m,frame,'WindowAC',V(2.7,1.6,1.7),V(-width/2+5,23+k*11.6,-0.65),C(159,163,152),Enum.Material.Metal) end
 end
 return m,h,frame
end
function B.BuildArchitecture()
 local a=phase('Architecture')
 local tones={P.brick,P.tan,P.red,P.soot}
 local awnings={C(72,100,75),C(129,70,51),C(66,79,89),C(155,118,65)}
 local shops={'FAMILY MARKET','AVENUE REPAIRS','SUNRISE BAKERY','PAPER & POST','CORNER FLOWERS','RECORD ROOM','FRESH PRODUCE','ELM BOOKS','COMMUNITY KITCHEN','CYCLE WORKS','NEIGHBORHOOD CAFE','STATION GOODS','TAILOR & THREAD','LOCAL PRINT','PLANT HOUSE','THE CORNER'}
 for _,side in ipairs({-1,1}) do
  local z=-70;local i=0
  while z>-580 do
   i+=1;local w=({32,24,40,32,40,24})[(i+(side==1 and 2 or 0)-1)%6+1]
   local f=CFrame.lookAt(V(side*42,0,z),V(0,0,z))
   building(a,f,w,({5,4,5,6,4})[(i+(side==1 and 1 or 0)-1)%5+1],tones[(i+(side==1 and 2 or 0)-1)%4+1],shops[(i+(side==1 and 5 or 0)-1)%#shops+1],awnings[(i-1)%4+1],i%2==0,73017+i+(side+1)*25)
   z-=w/2+(({32,24,40,32,40,24})[(i+(side==1 and 2 or 0))%6+1])/2+5
  end
 end
 local f=CFrame.lookAt(V(-42,0,7),V(0,0,7));building(a,f,40,5,P.brick,'SUNNY SIDE BODEGA',P.yellow,true,52)
 local f2=CFrame.lookAt(V(42,0,5),V(0,0,5));building(a,f2,32,5,P.tan,'UPTOWN CUTS',C(56,81,92),false,65)
 local f3=CFrame.new(-85,0,46)*CFrame.Angles(0,math.pi,0);building(a,f3,40,4,P.red,'FRESH START  •  LAUNDRY',C(58,113,107),true,87)
 local f4=CFrame.new(-133,0,46)*CFrame.Angles(0,math.pi,0);building(a,f4,32,5,P.tan,'THE STOOP',C(103,113,65),false,66)
 -- Stepped spawn stoop faces the avenue. Low enough to preserve station sightline.
 local stoop=model(a,'WelcomeStoop')
 for i=1,4 do box(stoop,'StoopStep',V(12,0.8,1.8),V(0,(i-0.5)*0.8,84+i*1.8),P.stone,Enum.Material.Concrete) end
 for _,x in ipairs({-6,6}) do beam(stoop,'IronHandrail',V(x,2.8,85),V(x,5.2,92),0.16,P.iron);for _,z in ipairs({85,89,92}) do box(stoop,'RailingPost',V(0.15,2.8,0.15),V(x,(z-85)*0.3+1.4,z),P.iron,Enum.Material.Metal) end end
 root().BlockArrival.CFrame=CFrame.new(0,3.8,91)
 -- The station is the destination, readable below the rails.
 local s=model(a,'JuniperStation');s.ModelStreamingMode=Enum.ModelStreamingMode.Persistent
 for _,x in ipairs({-28,28}) do
  box(s,'Platform',V(16,1,78),V(x,36,-605),P.stone,Enum.Material.Concrete)
  box(s,'YellowSafetyStrip',V(1.4,0.08,78),V(x-math.sign(x)*7,36.55,-605),P.yellow,Enum.Material.Concrete)
  for z=-578,-636,-19 do
   box(s,'CanopyPost',V(0.4,11,0.4),V(x,42,z),P.steel,Enum.Material.Metal)
  end
  box(s,'PlatformCanopy',V(18,0.5,80),V(x,47.5,-605),P.steel,Enum.Material.Metal)
 end
 -- 44 risers at 0.8 studs, plus a short upper landing; generous 10-stud stair width.
 for i=1,44 do box(s,'StationStair',V(10,0.8,1.6),V(28,0.4+i*0.8,-500-i*1.6),P.stone,Enum.Material.Concrete) end
 for _,x in ipairs({22.5,33.5}) do
  beam(s,'StairRail',V(x,3.2,-501),V(x,38.4,-571),0.18,P.steel)
  for i=0,10 do box(s,'StairBaluster',V(0.14,3,0.14),V(x,1.9+i*3.2,-501-i*6.4),P.steel,Enum.Material.Metal) end
 end
 box(s,'UpperStairLanding',V(10,1,5),V(28,35.8,-572),P.stone,Enum.Material.Concrete)
 for _,x in ipairs({-21,21}) do box(s,'PortalPost',V(1,25,1),V(x,12.5,-585),P.steel,Enum.Material.Metal) end
 sign(s,'DestinationSign',CFrame.new(0,22,-585)*CFrame.Angles(0,math.pi,0),V(43,6,0.8),P.green,'JUNIPER STATION',P.cream)
 sign(s,'MoveOutSign',CFrame.new(0,17.8,-585)*CFrame.Angles(0,math.pi,0),V(30,2.1,0.5),P.navy,'NORTHBOUND  /  THE SUBURBS  →',P.yellow)
 for _,x in ipairs({-21,21}) do
  local g=ball(s,'StationGlobe',V(2.7,2.7,2.7),V(x,25.5,-585),C(130,210,152),Enum.Material.Neon);point(g,C(128,221,160),1,18)
 end
 for _,x in ipairs({-32,32}) do
  for _,z in ipairs({-578,-607,-634}) do box(s,'PlatformSupport',V(0.9,35.4,0.9),V(x,17.7,z),P.steel,Enum.Material.Metal) end
  box(s,'PlatformEdgeBeam',V(1,1.6,78),V(x,34.8,-605),P.steel,Enum.Material.Metal)
  box(s,'PlatformOuterRail',V(0.16,0.16,78),V(math.sign(x)*35,39.5,-605),P.steel,Enum.Material.Metal)
  for z=-569,-641,-8 do box(s,'PlatformRailPost',V(0.12,3,0.12),V(math.sign(x)*35,38,z),P.steel,Enum.Material.Metal) end
 end
 local back=phase('Backdrop')
 for _,side in ipairs({-1,1}) do
  for i=0,10 do
   local height=({52,67,45,80})[i%4+1]
   box(back,'DistantMasonry',V(36,height,42),V(side*(120+i%3*18),height/2,-i*67),tones[(i+1)%4+1],Enum.Material.Brick)
   box(back,'DistantRoofline',V(38,1.4,44),V(side*(120+i%3*18),height,-i*67),P.stone,Enum.Material.Concrete)
  end
 end
 box(back,'EndBlock',V(240,45,30),V(0,22.5,-690),C(126,113,93),Enum.Material.Brick)
 return 'Architecture complete: varied masonry, recessed windows, cornices, shopfronts, fire escapes, station.'
end
local function tree(parent,pos,seed)
 local rng=Random.new(seed);local m=model(parent,'StreetTree')
 box(m,'SoilBed',V(5,0.15,5),pos+V(0,0.08,0),C(85,78,55),Enum.Material.Ground)
 for _,x in ipairs({-2.6,2.6}) do box(m,'TreeGrateEdge',V(0.2,0.12,5.4),pos+V(x,0.15,0),P.iron,Enum.Material.Metal) end
 for z=-2.5,2.5,0.6 do box(m,'GrateBar',V(5.2,0.12,0.12),pos+V(0,0.15,z),P.iron,Enum.Material.Metal) end
 cylinder(m,'Trunk',0.5,10,CFrame.new(pos+V(0,5,0)),C(96,79,55),Enum.Material.Wood)
 for i=1,4 do
  local off=V(rng:NextNumber(-3,3),rng:NextNumber(10,15),rng:NextNumber(-2.5,2.5))
  beam(m,'Branch',pos+V(0,7,0),pos+off,0.55,C(96,79,55),Enum.Material.Wood)
  local leaf=ball(m,'LeafMass',V(7.5,7,7),pos+off,C(69+i*5,100+i*6,49+i*3),Enum.Material.Grass);leaf.CanCollide=false
 end
 return m
end
local function hydrant(parent,pos)
 local m=model(parent,'FireHydrant');cylinder(m,'Body',0.62,2.2,CFrame.new(pos+V(0,1.1,0)),P.red)
 cylinder(m,'Foot',0.85,0.2,CFrame.new(pos+V(0,0.1,0)),P.iron)
 ball(m,'Cap',V(1.3,0.7,1.3),pos+V(0,2.3,0),P.red,Enum.Material.Metal)
 for _,x in ipairs({-0.8,0.8}) do cylinder(m,'Outlet',0.35,0.5,CFrame.new(pos+V(x,1.4,0))*CFrame.Angles(0,0,math.pi/2),P.red) end
 return m
end
local function crate(parent,cf,color)
 local m=model(parent,'ProduceCrate')
 for _,y in ipairs({0.2,0.65,1.1}) do for _,z in ipairs({-0.9,0.9}) do part(m,'CrateSlat',V(2.7,0.3,0.18),cf*CFrame.new(0,y,z),P.wood,Enum.Material.WoodPlanks) end end
 for _,x in ipairs({-1.3,1.3}) do part(m,'CrateEnd',V(0.2,1.3,2),cf*CFrame.new(x,0.65,0),P.wood,Enum.Material.WoodPlanks) end
 for x=-0.8,0.8,0.8 do for z=-0.45,0.45,0.9 do part(m,'Produce',V(0.65,0.65,0.65),cf*CFrame.new(x,1,z),color,Enum.Material.SmoothPlastic,Enum.PartType.Ball) end end
 return m
end
local function car(parent,cf,color,kind)
 local m=model(parent,kind or 'ParkedSedan');local van=kind=='DeliveryVan' or kind=='IceCreamTruck';local len=van and 18 or 16
 facpart(m,cf,'Chassis',V(6.8,1.5,len),V(0,2,0),color,Enum.Material.Metal)
 facpart(m,cf,'Hood',V(6.6,1.1,4),V(0,3,-len/2+2),color,Enum.Material.Metal)
 facpart(m,cf,'Cabin',V(6.1,2.6,van and 11 or 7),V(0,3.8,van and 2 or 0.5),color,Enum.Material.Metal)
 facpart(m,cf,'Windshield',V(5.4,1.6,0.12),V(0,4.1,van and -3.56 or -3.06),C(53,76,78),Enum.Material.Glass)
 facpart(m,cf,'Roof',V(6.3,0.3,van and 11.2 or 7.3),V(0,5.3,van and 2 or 0.5),color,Enum.Material.Metal)
 for _,side in ipairs({-1,1}) do
  for _,z in ipairs({-len/2+3,len/2-3}) do
   cylinder(m,'Tire',1.25,0.8,cf*CFrame.new(side*3.4,1.25,z)*CFrame.Angles(0,0,math.pi/2),C(36,35,32),Enum.Material.Rubber)
   cylinder(m,'Hubcap',0.7,0.83,cf*CFrame.new(side*3.4,1.25,z)*CFrame.Angles(0,0,math.pi/2),C(142,142,128),Enum.Material.Metal)
  end
  facpart(m,cf,'SideWindow',V(0.12,1.5,van and 2.2 or 5.7),V(side*3.1,4.1,van and -1.8 or 0.5),C(53,76,78),Enum.Material.Glass)
  facpart(m,cf,'DoorHandle',V(0.15,0.15,0.6),V(side*3.2,3.1,0.3),P.cream,Enum.Material.Metal)
  facpart(m,cf,'Headlamp',V(1.3,0.6,0.12),V(side*2.1,2.6,-len/2-0.06),C(221,205,153),Enum.Material.Glass)
  facpart(m,cf,'Taillamp',V(1.3,0.6,0.12),V(side*2.1,2.6,len/2+0.06),C(164,55,40),Enum.Material.Glass)
 end
 for _,z in ipairs({-len/2,len/2}) do facpart(m,cf,'Bumper',V(7,0.4,0.25),V(0,1.75,z),C(146,151,140),Enum.Material.Metal) end
 if kind=='IceCreamTruck' then
  sign(m,'IceCreamMenu',cf*CFrame.new(3.5,4,1)*CFrame.Angles(0,-math.pi/2,0),V(8,2,0.2),P.cream,'SUNNY SCOOPS\nDAILY TREATS',P.navy)
 end
 return m
end
local function fence(parent,a,b,height)
 local d=(b-a).Magnitude;local f=CFrame.lookAt((a+b)/2,b)*CFrame.Angles(0,math.pi/2,0)
 for x=-d/2,d/2,8 do cylinder(parent,'FencePost',0.12,height,f*CFrame.new(x,height/2,0),P.iron) end
 for _,y in ipairs({0.4,height}) do part(parent,'FenceRail',V(d,0.12,0.12),f*CFrame.new(0,y,0),P.iron,Enum.Material.Metal) end
 -- Sparse diagonal wire geometry reads as chain link without transparent texture stacks.
 for x=-d/2+2,d/2-2,3 do
  beam(parent,'FenceWire',f:PointToWorldSpace(V(x-1.5,0.5,0)),f:PointToWorldSpace(V(x+1.5,height,0)),0.045,C(99,108,99))
  beam(parent,'FenceWire',f:PointToWorldSpace(V(x+1.5,0.5,0)),f:PointToWorldSpace(V(x-1.5,height,0)),0.045,C(99,108,99))
 end
end
local function waterTower(parent,pos)
 local m=model(parent,'RoofWaterTower')
 for _,x in ipairs({-3.2,3.2}) do for _,z in ipairs({-3.2,3.2}) do beam(m,'TowerLeg',pos+V(x,0,z),pos+V(x*0.8,7,z*0.8),0.35,P.iron) end end
 cylinder(m,'WoodenTank',4.4,8,CFrame.new(pos+V(0,11,0)),P.wood,Enum.Material.WoodPlanks)
 for _,y in ipairs({7.4,10.7,14.7}) do cylinder(m,'TankBand',4.48,0.18,CFrame.new(pos+V(0,y,0)),P.iron) end
 ball(m,'TankCap',V(9,2,9),pos+V(0,15,0),P.iron,Enum.Material.Metal)
end
function B.BuildDetails()
 local d=phase('StreetDetails');local rng=Random.new(73017)
 -- Asphalt maintenance patches are sparse and offset, not a regular grid.
 for i=1,17 do
  part(d,'AsphaltPatch',V(rng:NextNumber(2,5),0.018,rng:NextNumber(3,9)),CFrame.new(rng:NextNumber(-13,13),0.025,rng:NextNumber(-580,30))*CFrame.Angles(0,math.rad(rng:NextNumber(-6,6)),0),C(48,49,49),Enum.Material.Asphalt)
 end
 for _,z in ipairs({10,-132,-319,-490}) do
  cylinder(d,'Manhole',1.35,0.035,CFrame.new(7,0.055,z),C(67,69,66),Enum.Material.DiamondPlate)
 end
 for _,row in ipairs({{-28,-31},{28,-97},{-28,-185},{28,-260},{-28,-341},{28,-414},{-28,-505},{-112,10},{-65,22},{138,40}}) do tree(d,V(row[1],0.81,row[2]),math.abs(row[1]*12+row[2])) end
 for _,row in ipairs({{-25,23},{25,-61},{-25,-153},{25,-235},{-25,-328},{25,-430},{-25,-523},{-62,79},{62,79}}) do lamp(d,V(row[1],0.8,row[2])) end
 for _,row in ipairs({{-24,-85},{24,-207},{-24,-400},{24,-490}}) do hydrant(d,V(row[1],0.8,row[2])) end
 local colors={C(109,132,124),C(139,86,67),C(198,181,142),C(81,104,121),C(173,165,144),C(96,108,80)}
 for i,row in ipairs({{-16,-34},{16,-120},{-16,-218},{16,-310},{-16,-419},{16,-492},{112,69},{-88,68}}) do car(d,CFrame.new(row[1],0,row[2])*CFrame.Angles(0,math.rad(i%2==0 and 180 or 0),0),colors[(i-1)%6+1],i==6 and 'DeliveryVan' or 'ParkedSedan') end
 car(d,CFrame.new(-126,0,69)*CFrame.Angles(0,math.pi/2,0),C(224,210,158),'IceCreamTruck')
 -- Bodega fruit stand follows the storefront transform and rests on the sidewalk.
 local bf=CFrame.lookAt(V(-42,0,7),V(0,0,7))
 for i=1,3 do crate(d,bf*CFrame.new(-11+i*3,0.82,-4.4)*CFrame.Angles(0,math.rad(i*2-4),0),({C(179,61,42),C(218,161,49),C(103,153,63)})[i]) end
 local open=facadeSign(d,bf,'OpenSign',-8,5.8,-0.1,5,1.8,P.navy,'OPEN 24/7',P.yellow);point(open,P.yellow,0.8,10)
 facadeSign(d,bf,'BodegaSubline',0,7.1,-0.5,22,0.85,P.green,'FRESH FOOD  •  GOOD NEIGHBORS',P.cream)
 -- Barber pole: geometry bands rather than an unrelated free model.
 local barber=model(d,'BarberPole');local pf=CFrame.new(38.8,5.8,13)
 cylinder(barber,'WhiteCylinder',0.48,3.5,pf,P.cream)
 for i=0,5 do cylinder(barber,'Stripe',0.5,0.25,pf*CFrame.new(0,-1.4+i*0.55,0),i%2==0 and C(167,59,43) or C(57,96,135)) end
 -- Washing-machine fronts are visible beneath the laundry awning.
 for i=1,4 do
  local f=CFrame.new(-103+i*6,0,47.2)*CFrame.Angles(0,math.pi,0)
  facpart(d,f,'WasherBody',V(4.5,4.8,1),V(0,3.2,0),C(175,187,177),Enum.Material.Metal)
  cylinder(d,'WasherDoor',1.45,0.18,f*CFrame.new(0,3.2,-0.6)*CFrame.Angles(math.pi/2,0,0),P.navy,Enum.Material.Glass)
 end
 -- Basketball court: painted surface, linework, two hoops, and social seating.
 local court=model(d,'JuniperCourt')
 box(court,'CourtSurface',V(66,0.06,88),V(104,0.84,0),C(103,130,105),Enum.Material.Concrete)
 box(court,'CenterStripe',V(66,0.025,0.14),V(104,0.89,0),P.cream,Enum.Material.Concrete)
 for _,x in ipairs({71,137}) do box(court,'Sideline',V(0.14,0.025,88),V(x,0.89,0),P.cream,Enum.Material.Concrete) end
 for _,z in ipairs({-44,44}) do box(court,'Baseline',V(66,0.025,0.14),V(104,0.89,z),P.cream,Enum.Material.Concrete) end
 for _,z in ipairs({-32,32}) do
  box(court,'KeyPaint',V(18,0.025,24),V(104,0.9,z),C(164,131,88),Enum.Material.Concrete)
  local backZ=z<0 and -39 or 39
  box(court,'HoopPost',V(0.4,13,0.4),V(104,7.3,backZ),P.iron,Enum.Material.Metal)
  box(court,'Backboard',V(8,4.3,0.35),V(104,12,backZ+(z<0 and 1 or -1)),P.cream,Enum.Material.Wood)
  local center=V(104,10.8,backZ+(z<0 and 3 or -3))
  for j=0,11 do local a=j*math.pi/6;local b=(j+1)*math.pi/6;beam(court,'Rim',center+V(math.cos(a),0,math.sin(a)),center+V(math.cos(b),0,math.sin(b)),0.1,P.orange);beam(court,'ChainNet',center+V(math.cos(a),0,math.sin(a)),center+V(math.cos(a)*0.55,-1.4,math.sin(a)*0.55),0.04,P.cream) end
 end
 for j=0,31 do local a=j*math.pi/16;local b=(j+1)*math.pi/16;beam(court,'CenterCircle',V(104+math.cos(a)*8,0.92,math.sin(a)*8),V(104+math.cos(b)*8,0.92,math.sin(b)*8),0.1,P.cream,Enum.Material.Concrete) end
 fence(court,V(68,0.8,-48),V(142,0.8,-48),9);fence(court,V(146,0.8,-48),V(146,0.8,48),9)
 bench(d,V(62,0.8,-20),-math.pi/2);bench(d,V(62,0.8,16),-math.pi/2);bench(d,V(-100,0.8,0),math.pi/2)
 -- Mural is original type and color geometry on a masonry wall.
 local mural=box(d,'CommunityMuralWall',V(62,18,2),V(-100,9.8,-26),P.brick,Enum.Material.Brick)
 sign(d,'MuralTitle',CFrame.new(-100,11,-24.85)*CFrame.Angles(0,math.pi,0),V(57,11,0.15),C(53,93,83),'FROM THE BLOCK\nWE RISE TOGETHER',P.cream)
 for i=1,7 do box(d,'MuralColorBand',V(6,2+i%3*1.2,0.1),V(-128+i*7,3,-24.7),colors[(i-1)%6+1],Enum.Material.Concrete) end
 -- Newspaper and mailboxes: clustered beside a bench, with readable fictional signage.
 for i,row in ipairs({{-33,26},{-30,27},{32,-20},{29,-22}}) do
  local p=box(d,'NewspaperBox',V(1.5,3,1.4),V(row[1],2.3,row[2]),i%2==0 and P.yellow or P.green,Enum.Material.Metal)
  textFace(p,i%2==0 and 'THE\nBLOCK' or 'LOCAL\nNEWS',P.cream)
 end
 -- Litter clusters sit at curb level, intentionally asymmetric.
 for i,row in ipairs({{-24,-56},{25,-168},{-24,-282},{25,-362},{-24,-468}}) do
  for j=1,3 do ball(d,'TiedBag',V(1.05+j*0.12,1.1+j*0.1,1.2),V(row[1]+(j-2)*1.1,1.45,row[2]+j%2),C(47+j*4,49+j*4,43+j*4),Enum.Material.Fabric) end
 end
 -- Roof silhouettes, HVAC and aerials are limited to selected buildings.
 local buildings=root().Architecture:GetChildren()
 for i,m in ipairs(buildings) do
  local roof=m:FindFirstChild('Roof')
  if roof then
   local cf=roof.CFrame
   if i%3==0 then waterTower(d,(cf*CFrame.new(0,0.25,2)).Position) end
   if i%4==0 then
    part(d,'RoofHVAC',V(4,2.2,5),cf*CFrame.new(7,1.3,2),C(123,131,120),Enum.Material.Metal)
    beam(d,'AntennaMast',(cf*CFrame.new(-7,0,0)).Position,(cf*CFrame.new(-7,8,0)).Position,0.12,P.iron)
    beam(d,'AntennaCrossbar',(cf*CFrame.new(-10,7,0)).Position,(cf*CFrame.new(-4,7,0)).Position,0.1,P.iron)
   end
  end
 end
 return 'Street detail pass complete: court, mural, trees, lamps, vehicles, bodega produce, laundry, roof silhouettes.'
end
function B.BuildObstacles()
 local o=phase('Obstacles');local maps=require(game.ReplicatedStorage.Shared.Config.Maps);local format=require(game.ReplicatedStorage.Shared.Format)
 -- Art markers retain a six-stud center opening for an unrestricted environment walkthrough.
 for i=1,10 do
  local z=5-(i-1)*64;local m=model(o,string.format('%02d_%s',i,maps.ById.Block.Walls[i].Name));m:SetAttribute('WallIndex',i)
  local board=sign(m,'RepRequirement',CFrame.new(-12,5,z+4)*CFrame.Angles(0,math.pi,0),V(6.8,3.1,0.25),P.navy,string.format('%02d  /  %s REP',i,format.compact(maps.ById.Block.Walls[i].RequiredRep)),P.yellow)
  for _,x in ipairs({-14.7,-9.3}) do box(m,'SignPost',V(0.16,4,0.16),V(x,2,z+4),P.iron,Enum.Material.Metal) end
  if i==1 then
   for j=1,7 do local x=j<5 and -10+(j%3)*2.7 or 7+(j%3)*2.7;local h=j==4 and 3.8 or 1.3;local p=part(m,'MovingBox',V(2.5,2.5,2.5),CFrame.new(x,h,z)*CFrame.Angles(0,math.rad(j*3),0),C(174+j*3,139+j*2,87),Enum.Material.Cardboard);textFace(p,'↑  ↑',P.wood) end
  elseif i==2 then fence(m,V(-17,0,z),V(-4,0,z),7);fence(m,V(4,0,z),V(17,0,z),7)
  elseif i==3 then car(m,CFrame.new(10,0,z)*CFrame.Angles(0,math.rad(-5),0),C(173,168,139),'DeliveryVan')
  elseif i==4 then
   hydrant(m,V(-18,0,z));for j=1,7 do ball(m,'WaterArc',V(0.15,0.15,0.4),V(-17+j,1.3+math.sin(j/7*math.pi)*2.5,z),C(143,188,197),Enum.Material.Glass).CanCollide=false end
  elseif i==5 then
   for _,x in ipairs({-14,-8,8,14}) do cylinder(m,'OrangeBarrel',1.3,3,CFrame.new(x,1.5,z),P.orange);cylinder(m,'ReflectiveBand',1.32,0.45,CFrame.new(x,2,z),P.cream) end
  elseif i==6 then
   for _,x in ipairs({-16,16}) do for _,zz in ipairs({z-4,z+4}) do box(m,'ScaffoldUpright',V(0.22,12,0.22),V(x,6,zz),P.steel,Enum.Material.Metal) end end
   box(m,'ScaffoldDeck',V(34,0.35,9),V(0,12,z),P.wood,Enum.Material.WoodPlanks)
   for _,zz in ipairs({z-4,z+4}) do box(m,'ScaffoldBeam',V(34,0.3,0.3),V(0,11.6,zz),P.steel,Enum.Material.Metal) end
  elseif i==7 then
   box(m,'IceCart',V(4,3,5),V(11,2,z),C(179,200,171),Enum.Material.Metal)
   for _,zz in ipairs({-1.5,1.5}) do cylinder(m,'CartWheel',0.65,0.3,CFrame.new(13,0.65,z+zz)*CFrame.Angles(0,0,math.pi/2),P.iron) end
   box(m,'CartCanopy',V(6,0.3,6),V(11,7,z),P.yellow,Enum.Material.Fabric)
   for _,x in ipairs({8.5,13.5}) do box(m,'CartPole',V(0.12,5,0.12),V(x,4.5,z),P.iron,Enum.Material.Metal) end
   sign(m,'IcesSign',CFrame.new(11,3,z+2.7)*CFrame.Angles(0,math.pi,0),V(4,1.8,0.2),P.green,'JUNIPER ICES',P.cream)
  elseif i==8 then
   box(m,'DJTable',V(9,3,3),V(10,1.5,z),P.wood,Enum.Material.WoodPlanks)
   for _,x in ipairs({6,14}) do box(m,'Speaker',V(2,4,2),V(x,2,z-2),P.navy,Enum.Material.Fabric) end
   sign(m,'BlockPartyPoster',CFrame.new(10,6,z)*CFrame.Angles(0,math.pi,0),V(11,3,0.3),P.red,'BLOCK PARTY\nEVERYONE WELCOME',P.cream)
  elseif i==9 then
   for j=1,8 do local x=j%2==0 and -7-j*0.7 or 7+j*0.7;ball(m,'PigeonBody',V(0.65,0.65,0.9),V(x,0.5,z+j%3),C(119,131,133));ball(m,'PigeonHead',V(0.38,0.4,0.38),V(x,0.95,z+j%3-0.3),C(71,88,82)) end
  else
   for _,x in ipairs({-12,12}) do box(m,'TurnstilePedestal',V(2,4,3),V(x,2,z),C(138,152,135),Enum.Material.Metal);beam(m,'TurnstileArm',V(x-3,2.9,z),V(x+3,2.9,z),0.15,P.iron) end
  end
 end
 return 'Ten themed obstacle compositions installed; walkthrough path kept open.'
end
function B.BuildTrain()
 local life=phase('Life');local train=model(life,'JuniperTrain');train.ModelStreamingMode=Enum.ModelStreamingMode.Persistent
 for n=0,2 do
  local f=CFrame.new(-8.5,36.8,-190+n*36)
  facpart(train,f,'TrainBody',V(10.8,7.5,32),V(0,5,0),C(171,178,159),Enum.Material.Metal)
  facpart(train,f,'GreenStripe',V(11,1,31.8),V(0,3.4,0),P.green,Enum.Material.Metal)
  facpart(train,f,'TrainRoof',V(11.2,0.6,32.5),V(0,9,0),C(96,112,100),Enum.Material.Metal)
  for _,side in ipairs({-1,1}) do
   for z=-11,11,5.5 do facpart(train,f,'TrainWindow',V(0.08,2.7,3.5),V(side*5.45,6,z),C(47,70,70),Enum.Material.Glass) end
   for _,z in ipairs({-6,6}) do facpart(train,f,'TrainDoor',V(0.13,6,2.2),V(side*5.5,4.5,z),C(134,152,135),Enum.Material.Metal) end
  end
  for _,z in ipairs({-10,10}) do facpart(train,f,'Bogie',V(8,1.5,3),V(0,0.5,z),P.iron,Enum.Material.Metal) end
  local face=facpart(train,f,'EndWindow',V(7,3,0.08),V(0,6,-16.05),P.navy,Enum.Material.Glass)
  for _,x in ipairs({-3.7,3.7}) do facpart(train,f,'Headlight',V(0.8,0.8,0.1),V(x,3,-16.1),C(247,226,174),Enum.Material.Neon) end
  facadeSign(train,f,'RouteRoundel',0,8,-16.14,2,1,P.green,'J',P.cream)
 end
 train.WorldPivot=CFrame.new(0,0,0)
 -- Friendly, stylized ambient neighbors with distinct poses. No expensive humanoid simulation.
 local neighbors={
  {-104,1,2,25,'SittingNeighbor',C(174,112,73),C(69,95,124)},
  {-96,1,2,-20,'DominoNeighbor',C(111,78,57),C(157,111,58)},
  {-37,1,20,90,'BodegaNeighbor',C(188,141,101),C(63,119,96)},
  {65,1,20,-90,'CourtNeighbor',C(123,85,64),C(171,119,62)},
  {118,1,-15,0,'BasketballNeighbor',C(179,130,87),C(119,73,60)},
  {-30,1,-120,60,'WalkingNeighbor',C(114,79,57),C(122,139,158)},
  {30,1,-212,-60,'WalkingNeighbor',C(206,166,127),C(164,146,83)},
  {-31,1,-337,80,'ReadingNeighbor',C(149,103,72),C(103,133,102)},
 }
 for i,row in ipairs(neighbors) do
  local m=model(life,row[5]);m.ModelStreamingMode=Enum.ModelStreamingMode.Atomic;local f=CFrame.new(row[1],row[2],row[3])*CFrame.Angles(0,math.rad(row[4]),0)
  facpart(m,f,'Torso',V(1.6,1.8,0.85),V(0,2.65,0),row[7],Enum.Material.Fabric)
  ball(m,'Head',V(1.05,1.12,1.05),(f*CFrame.new(0,4.1,0)).Position,row[6],Enum.Material.SmoothPlastic)
  for _,x in ipairs({-0.42,0.42}) do facpart(m,f,'TrouserLeg',V(0.65,1.8,0.7),V(x,0.95,0),C(48,62,72),Enum.Material.Fabric);facpart(m,f,'Shoe',V(0.68,0.3,1),V(x,0.16,-0.15),P.cream,Enum.Material.SmoothPlastic) end
  for _,x in ipairs({-1.05,1.05}) do local arm=facpart(m,f,'Arm',V(0.55,1.6,0.6),V(x,2.7,0),row[7],Enum.Material.Fabric);arm.CFrame*=CFrame.Angles(math.rad(i%2==0 and -20 or 12),0,0);ball(m,'Hand',V(0.5,0.5,0.5),(f*CFrame.new(x,1.8,-0.15)).Position,row[6],Enum.Material.SmoothPlastic) end
  facpart(m,f,'Hair',V(1.08,0.3,1.08),V(0,4.58,0),C(50+i*3,42+i*2,34+i*2),Enum.Material.Fabric)
  for _,x in ipairs({-0.2,0.2}) do facpart(m,f,'Eye',V(0.085,0.09,0.03),V(x,4.17,-0.52),P.iron,Enum.Material.SmoothPlastic) end
  m:SetAttribute('AmbientIndex',i)
 end
 box(life,'DominoTable',V(4,0.25,3),V(-100,2.5,2),C(163,166,132),Enum.Material.Wood)
 for _,x in ipairs({-101.5,-98.5}) do box(life,'TableLeg',V(0.12,2.4,0.12),V(x,1.2,2),P.iron,Enum.Material.Metal) end
 for i=1,5 do part(life,'Domino',V(0.25,0.06,0.5),CFrame.new(-101+i*0.4,2.67,2+i%2*0.4)*CFrame.Angles(0,i*0.3,0),P.cream,Enum.Material.SmoothPlastic) end
 ball(life,'Basketball',V(1.1,1.1,1.1),V(117,1.4,-17),P.orange,Enum.Material.Rubber)
 -- Bodega cat in a sunny window sill.
 local cat=model(life,'BodegaCat');ball(cat,'Body',V(1.3,0.7,0.8),V(-40.9,3.1,4),C(179,139,78),Enum.Material.Fabric);ball(cat,'Head',V(0.6,0.6,0.6),V(-40.8,3.3,3.35),C(179,139,78),Enum.Material.Fabric)
 for _,z in ipairs({3.17,3.5}) do part(cat,'Ear',V(0.16,0.35,0.2),CFrame.new(-40.8,3.65,z),C(133,95,57),Enum.Material.Fabric) end
 return 'Train and eight ambient neighbors installed.'
end
function B.SetLighting()
 local l=game:GetService('Lighting')
 l.ClockTime=17.2;l.GeographicLatitude=28;l.GlobalShadows=true;l.ShadowSoftness=0.2;l.Brightness=2.8;l.ExposureCompensation=0.2
 l.Ambient=C(109,115,126);l.OutdoorAmbient=C(145,149,153);l.ColorShift_Top=C(255,220,175);l.ColorShift_Bottom=C(137,163,194)
 l.EnvironmentDiffuseScale=0.65;l.EnvironmentSpecularScale=0.65
 pcall(function() l.LightingStyle=Enum.LightingStyle.Realistic end)
 for _,name in ipairs({'BlockAtmosphere','BlockBloom','BlockGrade','BlockSunRays'}) do local old=l:FindFirstChild(name);if old then old:Destroy() end end
 -- Preserve original effects outside Lighting for reversible authoring.
 local ss=game:GetService('ServerStorage');local backup=ss:FindFirstChild('BeforeBlockMap')
 for _,v in ipairs(l:GetChildren()) do if v:IsA('Atmosphere') or v:IsA('PostEffect') then v.Parent=backup end end
 local at=Instance.new('Atmosphere');at.Name='BlockAtmosphere';at.Density=0.28;at.Offset=0.12;at.Haze=1.6;at.Glare=0.25;at.Color=C(218,201,172);at.Decay=C(141,155,165);at.Parent=l
 local bloom=Instance.new('BloomEffect');bloom.Name='BlockBloom';bloom.Intensity=0.18;bloom.Size=24;bloom.Threshold=1.2;bloom.Parent=l
 local cc=Instance.new('ColorCorrectionEffect');cc.Name='BlockGrade';cc.Contrast=0.05;cc.Saturation=-0.05;cc.TintColor=C(255,245,228);cc.Parent=l
 local rays=Instance.new('SunRaysEffect');rays.Name='BlockSunRays';rays.Intensity=0.035;rays.Spread=0.65;rays.Parent=l
 return tostring(l:GetSunDirection())
end
function B.Finalize()
 local r=root();local sun=game.Lighting:GetSunDirection();local yaw=math.atan2(-sun.X,-sun.Z)
 r.WorldPivot=CFrame.identity;r:PivotTo(CFrame.Angles(0,yaw,0));r:SetAttribute('MapYaw',yaw)
 -- Keep the full hub and station present, allow long facade streets to stream normally.
 for _,n in ipairs({'Ground','ElevatedRail'}) do r[n].ModelStreamingMode=Enum.ModelStreamingMode.Persistent end
 local ss=game:GetService('ServerStorage');local kits=ss:FindFirstChild('Kits') or Instance.new('Folder');kits.Name='Kits';kits.Parent=ss
 local old=kits:FindFirstChild('Block');if old then old:Destroy() end
 local kit=Instance.new('Folder');kit.Name='Block';kit.Parent=kits
 for _,name in ipairs({'StreetLamp','ParkBench','StreetTree','FireHydrant','ProduceCrate','ParkedSedan'}) do
  local source=r.StreetDetails:FindFirstChild(name)
  if source then local clone=source:Clone();clone:PivotTo(CFrame.identity);clone.Parent=kit end
 end
 local f=CFrame.Angles(0,yaw,0)
 workspace.CurrentCamera.CFrame=CFrame.lookAt(f:PointToWorldSpace(V(10,12,91)),f:PointToWorldSpace(V(-4,10,-160)))
 local count=0;for _,v in ipairs(r:GetDescendants()) do if v:IsA('BasePart') then count+=1 end end
 game:GetService('ChangeHistoryService'):SetWaypoint('The Block environment built')
 return {parts=count,yaw=yaw,spawn=tostring(r.BlockArrival.Position)}
end

function B.Refine()
 local d=phase('FinishingDetails')
 local rear=building(d,CFrame.new(0,0,107),32,5,P.soot,'JUNIPER HOUSE',P.green,true,103)
 for _,x in ipairs({-175,-132,-84,76,125,174}) do
  building(d,CFrame.new(x,0,111),32,4+(math.abs(x)%2),math.abs(x)%2==0 and P.tan or P.brick,'NEIGHBORHOOD GOODS',P.green,false,math.abs(x)+31)
 end
 local bounds=model(d,'WalkthroughBounds')
 for _,row in ipairs({{V(2,30,770),V(-198,14,-255)},{V(2,30,770),V(198,14,-255)},{V(400,30,2),V(0,14,127)},{V(400,30,2),V(0,14,-638)}}) do
  local p=box(bounds,'Boundary',row[1],row[2],P.iron);p.Transparency=1
 end
 -- The corner bodega and barber are seen from two sides on arrival.
 for _,row in ipairs({{-57,28.2,5},{57,22.2,5}}) do
  local f=CFrame.new(row[1],0,row[2])*CFrame.Angles(0,math.pi,0)
  for floor=1,row[3] do for _,x in ipairs({-8,0,8}) do makeWindow(d,f,x,19.2+(floor-1)*11.6,floor%3==0) end end
  for _,y in ipairs({12,35,58}) do facpart(d,f,'SideStoneCourse',V(30,0.5,0.5),V(0,y,0),P.stone,Enum.Material.Concrete) end
  facadeSign(d,f,'CornerStoreSign',0,10.5,-0.1,27,2.6,row[1]<0 and P.yellow or P.navy,row[1]<0 and 'SUNNY SIDE BODEGA' or 'UPTOWN CUTS',row[1]<0 and P.navy or P.cream)
 end
 -- Community notice board anchors the hub; warm panels echo the bodega awning.
 local f=CFrame.new(-59,0,57)*CFrame.Angles(0,math.pi,0)
 facadeSign(d,f,'WelcomeBoard',0,7,0,13,7,P.green,'WELCOME TO JUNIPER\nTHE BLOCK\nGOOD THINGS START HERE',P.cream)
 for _,x in ipairs({-5.7,5.7}) do facpart(d,f,'BoardPost',V(0.3,7,0.3),V(x,3.5,0),P.wood,Enum.Material.Wood) end
 -- Bus shelter and neighborhood update poster.
 local bus=CFrame.new(-160,0.8,92)
 for _,x in ipairs({-5,5}) do facpart(d,bus,'ShelterPost',V(0.25,8,0.25),V(x,4,0),P.steel,Enum.Material.Metal) end
 facpart(d,bus,'ShelterRoof',V(12,0.3,5),V(0,8.2,0),P.steel,Enum.Material.Metal)
 facadeSign(d,bus,'BusPoster',5,4,0,3,6,P.navy,'NEXT STOP\nYOUR FUTURE',P.yellow)
 bench(d,V(-160,0.8,92),0)
 -- Laundry line between two roofs, with mismatched cloth silhouettes.
 beam(d,'ClothesLine',V(-80,52,-222),V(-80,57,-266),0.055,P.iron)
 for i=1,5 do part(d,'DryingLaundry',V(0.15,2.5,2.2),CFrame.new(-80,51+i*0.9,-226-i*6)*CFrame.Angles(0,math.rad(i*3),math.rad(4)),({P.cream,C(100,136,161),C(177,102,76)})[(i-1)%3+1],Enum.Material.Fabric) end
 return 'Arrival facades and hub finishing details added.'
end
return B
