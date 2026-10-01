-- Edit-time finishing pass. Run after BlockBuilder.Finalize(); safe to rerun.
local P={}
function P.Apply()
 local r=workspace:WaitForChild('TheBlock')
 local previous=r:FindFirstChild('CommunityDetails');if previous then previous:Destroy() end
 local d=Instance.new('Model');d.Name='CommunityDetails';d.Parent=r
 local V=Vector3.new;local C=Color3.fromRGB
 local world=CFrame.Angles(0,r:GetAttribute('MapYaw') or r.MapYawValue.Value,0)
 local cream=C(239,222,185);local iron=C(39,53,49);local green=C(49,105,76)
 local function part(name,size,cf,color,mat,shape,parent)
  local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=world*cf;p.Color=color;p.Material=mat or Enum.Material.SmoothPlastic;p.Anchored=true;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
  if shape then p.Shape=shape end;p.Parent=parent or d;return p
 end
 local function box(name,size,pos,color,mat) return part(name,size,CFrame.new(pos),color,mat) end
 local function sign(name,cf,size,text,bg,fg)
  local p=part(name,size,cf,bg,Enum.Material.Wood)
  local g=Instance.new('SurfaceGui');g.Name='Signage';g.Face=Enum.NormalId.Front;g.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud;g.PixelsPerStud=65;g.LightInfluence=.35;g.Parent=p
  local t=Instance.new('TextLabel');t.Size=UDim2.fromScale(.9,.84);t.Position=UDim2.fromScale(.05,.08);t.BackgroundTransparency=1;t.Font=Enum.Font.GothamBold;t.TextColor3=fg;t.TextScaled=true;t.TextWrapped=true;t.Text=text;t.Parent=g
  return p
 end
 -- Increase contrast and stroke weight without drawing signs through buildings.
 for _,v in r:GetDescendants() do
  if v:IsA('SurfaceGui') then v.PixelsPerStud=65;v.LightInfluence=.35 end
  if v:IsA('TextLabel') then
   v.Font=Enum.Font.GothamBold
   if v.Text=='SUNNY SIDE BODEGA' then v.TextColor3=iron end
  end
 end
 -- Shop blade signs make the two corners recognizable along the avenue.
 for _,row in ipairs({{-38,18,'BODEGA',C(231,173,49),iron},{38,13,'CUTS',iron,cream}}) do
  local x,z=row[1],row[2]
  box('BladeBracket',V(4,.2,.25),V(x,13,z),iron,Enum.Material.Metal)
  local f=CFrame.new(x,11.6,z)*CFrame.Angles(0,math.pi,0)
  local s=sign('CornerBlade',f,V(4.8,2.1,.25),row[3],row[4],row[5])
  local back=s.Signage:Clone();back.Face=Enum.NormalId.Back;back.Parent=s
 end
 -- Four warm shop pools; short ranges keep the lighting local and inexpensive.
 for _,row in ipairs({{-39,7},{39,5},{-91,49},{-135,49}}) do
  local bulb=box('ShopPorchLamp',V(.7,.35,.7),V(row[1],8,row[2]),C(255,218,158),Enum.Material.Neon)
  local l=Instance.new('PointLight');l.Color=C(255,210,153);l.Brightness=.8;l.Range=12;l.Shadows=false;l.Parent=bulb
 end
 -- Community garden beds occupy the edges of the plaza, leaving its center open.
 for _,row in ipairs({{-122,-12},{-79,-12},{-137,5}}) do
  local x,z=row[1],row[2]
  box('RaisedPlanter',V(8,1.4,3),V(x,1.5,z),C(122,83,56),Enum.Material.WoodPlanks)
  box('PlanterSoil',V(7.5,.12,2.5),V(x,2.24,z),C(64,55,40),Enum.Material.Ground)
  for i=-2,2 do
   box('PlantStem',V(.09,1.1,.09),V(x+i*1.3,2.75,z),green)
   part('PlantLeaves',V(.95,.65,.85),CFrame.new(x+i*1.3,3,z),C(89+i*4,125,63),Enum.Material.Grass,Enum.PartType.Ball)
   part('Marigold',V(.38,.3,.38),CFrame.new(x+i*1.3,3.4,z),i%2==0 and C(236,174,63) or C(188,84,51),Enum.Material.SmoothPlastic,Enum.PartType.Ball)
  end
 end
 local board=CFrame.new(-120,0,-13)*CFrame.Angles(0,math.pi,0)
 sign('CommunityBoard',board*CFrame.new(0,4,0),V(10,6,.4),'',green,cream)
 sign('CommunityHeading',board*CFrame.new(0,6.25,-.24),V(9.5,1,.035),'JUNIPER COMMUNITY',green,cream)
 for _,x in ipairs({-4.4,4.4}) do part('NoticeboardPost',V(.3,6,.3),board*CFrame.new(x,3,0),iron,Enum.Material.Metal) end
 for i,text in ipairs({'COURT\nSATURDAY\n3 PM','PLANT\n& GROW\nSUNDAY','BLOCK\nPARTY\nALL WELCOME'}) do
  sign('NeighborhoodFlyer',board*CFrame.new(-3+(i-1)*3,3.2,-.24),V(2.6,3.2,.035),text,({cream,C(193,213,166),C(223,181,118)})[i],iron)
 end
 -- Replace the two standing placeholders with neighbors seated across the domino table.
 for _,bench in r.StreetDetails:GetChildren() do
  if bench.Name=='ParkBench' then
   local localPivot=world:ToObjectSpace(bench:GetPivot())
   if (localPivot.Position-V(-100,2.5125,0)).Magnitude<2 then bench:PivotTo(world*CFrame.new(-104,2.5125,-9)*CFrame.Angles(0,math.pi,0)) end
  end
 end
 local life=r.Life
 for i,row in ipairs({{-103.6,2,-math.pi/2,'SittingNeighbor',C(174,112,73),C(69,95,124)},{-96.4,2,math.pi/2,'DominoNeighbor',C(111,78,57),C(157,111,58)}}) do
  local old=life:FindFirstChild(row[4]);if old then old:Destroy() end
  local m=Instance.new('Model');m.Name=row[4];m.ModelStreamingMode=Enum.ModelStreamingMode.Atomic;m.Parent=life
  local f=CFrame.new(row[1],.8,row[2])*CFrame.Angles(0,row[3],0)
  local function p(n,s,pos,col,mat,shape) return part(n,s,f*CFrame.new(pos),col,mat,shape,m) end
  p('Torso',V(1.6,1.6,.85),V(0,2.6,0),row[6],Enum.Material.Fabric)
  p('Head',V(1.05,1.12,1.05),V(0,4,0),row[5],nil,Enum.PartType.Ball)
  p('Hair',V(1.08,.3,1.08),V(0,4.48,0),C(49,39,32),Enum.Material.Fabric)
  for _,x in ipairs({-.42,.42}) do
   p('BentThigh',V(.65,.65,1.25),V(x,1.85,-.45),C(48,62,72),Enum.Material.Fabric)
   p('Shin',V(.65,1.35,.65),V(x,.9,-.9),C(48,62,72),Enum.Material.Fabric)
   p('Shoe',V(.7,.35,1),V(x,.18,-1.05),cream)
  end
  for _,x in ipairs({-1,1}) do
   p('UpperArm',V(.5,.95,.55),V(x,2.65,0),row[6],Enum.Material.Fabric)
   p('Forearm',V(.48,.48,1.05),V(x,2.25,-.45),row[6],Enum.Material.Fabric)
   p('Hand',V(.5,.4,.5),V(x,2.25,-1),row[5])
   p('ChairLeg',V(.14,1.65,.14),V(x*.8,.825,.35),iron,Enum.Material.Metal)
   p('ChairFrontLeg',V(.14,1.65,.14),V(x*.8,.825,-.65),iron,Enum.Material.Metal)
  end
  p('ChairSeat',V(2.1,.2,1.7),V(0,1.6,-.1),C(112,91,61),Enum.Material.Wood)
  p('ChairBack',V(2.1,1.4,.18),V(0,2.5,.65),C(112,91,61),Enum.Material.Wood)
  for _,x in ipairs({-.2,.2}) do p('Eye',V(.08,.09,.04),V(x,4.05,-.52),iron) end
  -- Static seated figures keep chairs and feet firmly in place.
 end
 -- Cups and individual domino pips reward a closer look.
 for _,x in ipairs({-101.2,-98.8}) do part('PaperCup',V(.48,.5,.48),CFrame.new(x,2.9,1.25),cream) end
 for i=1,5 do
  local f=CFrame.new(-101+i*.4,2.706,2+i%2*.4)*CFrame.Angles(0,i*.3,0)
  for _,z in ipairs({-.13,.13}) do part('DominoPip',V(.055,.012,.055),f*CFrame.new(0,0,z),iron) end
 end
 game:GetService('ChangeHistoryService'):SetWaypoint('Community and storefront polish')
 return {addedParts=#d:GetDescendants(),seatedNeighbors=2}
end
return P
