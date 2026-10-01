-- Wearable native geometry rebuilt from the user's v5 front/side/back references.
local Art={};local V=Vector3.new;local C=Color3.fromRGB
local dark=C(34,31,30);local white=C(245,241,225);local gold=C(231,187,55)
local function part(parent,name,size,cf,color,anchored,shape)
 local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=cf;p.Color=color;p.Material=Enum.Material.SmoothPlastic;p.Anchored=anchored;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Massless=true;p.CastShadow=false;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;if shape==Enum.PartType.Ball then local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.Sphere;mesh.Parent=p elseif shape then p.Shape=shape end;p.Parent=parent;return p
end
local function dress(parent,b,s,anchored)
 local faceParts={EyeWhite=true,Iris=true,Pupil=true,EyeGlint=true,Eyebrow=true,Eyelid=true,Nose=true,Smile=true,SmileTeeth=true,Mouth=true,CheekBandage=true,SweatDrop=true,Scar=true,Moustache=true,SunglassesFrame=true,SunglassesLens=true,LensReflection=true,GlassesBridge=true,RoundSpectacleRim=true}
 local function add(body,n,size,pos,col,shape,rotation)
  if body=='Head' and faceParts[n] then pos+=V(0,0,-.13) end
  local ref=b[body];if not ref then return end
  local cf=ref.CFrame*CFrame.new(pos*ref.Size)*(rotation or CFrame.identity)
  local p=part(parent,n,size*ref.Size,cf,col,anchored,shape)
  if not anchored then local w=Instance.new('WeldConstraint');w.Part0=ref;w.Part1=p;w.Parent=p end
  return p
 end
 local function ball(body,n,size,pos,col) return add(body,n,size,pos,col,Enum.PartType.Ball) end
 local function metal(p) p.Material=Enum.Material.Metal;p.Reflectance=.08;return p end
 for k,p in b do
  if k=='Head' then p.Color=s.Skin elseif k:find('Leg') or k:find('Shoe') then p.Color=s.Pants else p.Color=s.Color end
 end
 -- Cloth hems, cuffs, pockets and matching shoes define the silhouette.
 for _,arm in {'LeftArm','RightArm'} do
  add(arm,'HandCuff',V(1.005,.19,1.005),V(0,-.405,0),(s.Id=='Bandit' or s.Id=='Crook' or s.Id=='GetawayDriver') and dark or s.Skin)
  if s.Style=='suit' then add(arm,'ShirtCuff',V(1.015,.045,1.015),V(0,-.29,0),white) end
  if s.Style~='vest' then
   for i=1,3 do add(arm,'SleeveFold',V(.52,.018,.02),V(.03,-.08+i*.05,-.511),s.Color:Lerp(dark,.17),nil,CFrame.Angles(0,0,math.rad(i-2)*3)) end
  end
 end
 for _,leg in {'LeftLeg','RightLeg'} do
  for i=1,3 do add(leg,'KneeCrease',V(.50,.016,.02),V(0,-.03+i*.045,-.514),s.Pants:Lerp(white,.17)) end
 end
 for _,leg in {'LeftShoe','RightShoe'} do
  local shoe=s.Index<=5 or s.Id=='GetawayDriver';local col=shoe and white or s.Id=='Consigliere' and C(84,53,37) or dark
  add(leg,'ShoeSole',V(1.1,.14,1.28),V(0,-.43,-.11),s.Id=='Kingpin' and gold or shoe and white or C(42,38,37))
  ball(leg,'RoundedToe',V(1.08,.33,1.31),V(0,-.28,-.13),col)
 end
 add('Torso','WaistHem',V(1.015,.065,1.02),V(0,-.46,0),s.Color:Lerp(dark,.17))
 if s.Style=='hoodie' or s.Style=='tracksuit' then
  for _,x in {-.10,.10} do add('Torso','Drawstring',V(.022,.24,.025),V(x,.28,-.52),white) end
  add('Torso','KangarooPocket',V(.60,.26,.055),V(0,-.25,-.516),s.Color:Lerp(dark,.09))
  add('Torso','PocketLip',V(.60,.021,.03),V(0,-.11,-.55),s.Color:Lerp(dark,.23))
  if s.Id=='CornerKid' then
   for i=-2,2 do add('Torso','SkylinePrint',V(.085,.1+(.3-math.abs(i)*.09),.015),V(i*.085,.00,-.554),white) end
   for _,x in {-.12,0,.12} do for _,y in {0,.07,.14} do add('Torso','PrintedWindow',V(.015,.018,.02),V(x,y,-.57),s.Color) end end
   -- Headphones resting around the neck, with orange ear cushions.
   ball('Torso','HeadphoneBand',V(.65,.17,.8),V(0,.49,0),dark)
   for _,x in {-.40,.40} do ball('Torso','HeadphoneCup',V(.18,.25,.4),V(x,.49,0),s.Accent) end
  end
 end
 if s.Style=='puffer' then
  for _,body in {'Torso','LeftArm','RightArm'} do
   for i=0,3 do
    ball(body,'PufferBaffle',V(1.04,.28,1.12),V(0,-.24+i*.22,0),s.Color:Lerp(white,.04+(i%2)*.025))
    add(body,'PaddedPanel',V(.94,.19,.14),V(0,-.24+i*.22,-.54),s.Color:Lerp(white,.06+(i%2)*.025))
   end
  end
  add('Torso','Zip',V(.022,.97,.035),V(0,0,-.58),dark)
  ball('Torso','PufferCollar',V(.84,.24,1.04),V(0,.5,0),s.Color)
 end
 if s.Style=='racer' or s.Style=='vest' or s.Style=='furcoat' then
  add('Torso','Undershirt',V(.38,.94,.035),V(0,0,-.53),s.Style=='furcoat' and C(157,44,69) or white)
  if s.Style=='racer' then
   for i=-2,2 do for j=0,1 do if (i+j)%2==0 then add('Torso','RacingCheck',V(.08,.08,.02),V(i*.075,.22+j*.07,-.56),dark) end end end
   add('Torso','RacerZipLeft',V(.018,.94,.02),V(-.21,0,-.54),white)
   add('Torso','RacerZipRight',V(.018,.94,.02),V(.21,0,-.54),white)
  elseif s.Style=='vest' then
   for _,arm in {'LeftArm','RightArm'} do
    b[arm].Color=s.Skin
    for _,y in {.13,.28} do add(arm,'TattooBand',V(1.01,.024,1.01),V(0,y,0),C(90,71,52)) end
    for x=-.3,.31,.15 do add(arm,'TattooDiamond',V(.11,.11,.02),V(x,.2,-.516),C(90,71,52),nil,CFrame.Angles(0,0,math.pi/4)) end
   end
  end
 end
 if s.Style=='suit' or s.Style=='trench' then
  add('Torso','DressShirt',V(.38,.8,.05),V(0,.09,-.53),s.Id=='Capo' and s.Accent or s.Id=='Kingpin' and gold or s.Id=='TheDon' and dark or white)
  for _,side in {-1,1} do
   add('Torso','TailoredLapel',V(.17,.57,.08),V(side*.19,.14,-.59),s.Color:Lerp(dark,.08),nil,CFrame.Angles(0,0,side*math.rad(-23)))
   add('Torso','CoatPocket',V(.18,.016,.03),V(side*.30,-.30,-.53),s.Color:Lerp(dark,.28))
  end
  if s.Style=='suit' then
   add('Torso','Tie',V(.072,.46,.07),V(0,.15,-.586),s.Accent)
   ball('Torso','TieKnot',V(.11,.095,.09),V(0,.4,-.59),s.Accent)
   add('Torso','PocketSquare',V(.11,.085,.03),V(-.30,.20,-.54),white,nil,CFrame.Angles(0,0,math.rad(-15)))
  end
  for _,y in {-.11,-.26} do ball('Torso','JacketButton',V(.042,.042,.027),V(-.035,y,-.542),s.Color:Lerp(dark,.4)) end
 end
 if s.Id=='Gangster' or s.Id=='Kingpin' then
  for _,body in {'Torso','LeftArm','RightArm','LeftLeg','RightLeg'} do
   for x=-.38,.39,.15 do add(body,'Pinstripe',V(.008,.88,.017),V(x,.02,-.514),s.Id=='Kingpin' and C(143,124,67) or C(131,145,175)) end
  end
 end
 if s.Style=='trench' then
  for _,x in {-.19,.19} do for _,y in {-.08,-.22} do ball('Torso','DoubleBreastedButton',V(.04,.04,.04),V(x,y,-.55),s.Accent) end end
  add('Torso','TrenchBelt',V(1.04,.06,1.05),V(0,-.32,0),s.Accent)
  for _,side in {-1,1} do add('Torso','CoatTail',V(.39,.61,.13),V(side*.29,-.74,-.43),s.Color) end
 end
 if s.Id=='StreetBoss' or s.Id=='Underboss' or s.Id=='Kingpin' then
  local fur=s.Id=='Kingpin' and C(115,51,167) or white
  for i=1,10 do local a=i/10*math.pi*2;ball('Torso','FurCollar',V(.31,.23,.40),V(math.cos(a)*.43,.49,math.sin(a)*.38),fur) end
  for _,side in {-1,1} do ball('Torso','LongScarf',V(.18,.91,.18),V(side*.31,-.03,-.62),fur) end
 end
 if s.Id=='TheDon' or s.Id=='Kingpin' then
  add('Torso','Cape',V(1.13,1.72,.14),V(0,-.36,.65),s.Id=='TheDon' and C(28,27,30) or C(92,35,139))
  add('Torso','CapeShoulders',V(1.25,.12,.85),V(0,.48,.25),s.Id=='TheDon' and dark or C(112,48,157))
 end
 if s.Id=='TheDon' then
  add('Torso','RoseStem',V(.025,.16,.04),V(-.31,.17,-.64),C(61,138,57),nil,CFrame.Angles(0,0,-.3))
  for i=1,5 do local a=i/5*math.pi*2;ball('Torso','RosePetal',V(.08,.08,.075),V(-.31+math.cos(a)*.034,.25+math.sin(a)*.035,-.66),C(219,44+i*4,66)) end
 end
 local chained=s.Id=='Hustler' or s.Id=='StreetBoss' or s.Id=='Capo' or s.Id=='Kingpin'
 if chained then
  for i=-4,4 do
   local x=i*.066;local y=.28-math.sqrt(math.max(0,1-(i/4)^2))*.31
   metal(ball('Torso','GoldChainLink',V(.085,.085,.065),V(x,y,-.66),gold))
   ball('Torso','LinkOpening',V(.037,.04,.02),V(x,y,-.701),dark)
  end
  metal(ball('Torso','Pendant',V(.24,.24,.07),V(0,-.09,-.69),gold))
  if s.Id=='Kingpin' then add('Torso','DiamondPendant',V(.12,.12,.06),V(0,-.09,-.74),white,nil,CFrame.Angles(0,0,math.pi/4)) end
 end
 if s.Index>=5 then
  local watch=(s.Id=='GetawayDriver' or s.Id=='Consigliere' or s.Id=='Underboss') and C(201,210,218) or gold
  if typeof(watch)~='Color3' then watch=C(201,210,218) end
  metal(add('LeftArm','WatchBand',V(1.025,.055,1.025),V(0,-.30,0),watch))
  metal(ball('LeftArm','WatchFace',V(.25,.16,.09),V(0,-.30,-.54),watch))
 end
 -- Hair and recognizable hats from the supplied front/side views.
 local hair=s.Hat=='whitehair' and C(230,228,221) or s.Id=='Pickpocket' and C(132,87,45) or C(42,33,26)
 if s.Hat~='bald' then
  ball('Head','HairCap',V(1.02,.30,1.01),V(0,.46,.04),hair)
  for _,x in {-.46,.46} do add('Head','Sideburn',V(.1,.43,.32),V(x,.03,.02),hair) end
 end
 if s.Hat=='cap' then
  ball('Head','BackwardCap',V(1.08,.42,1.09),V(0,.57,.1),C(60,69,70))
  add('Head','CapBrim',V(.92,.075,.42),V(0,.52,.65),C(54,60,61))
  for i=-2,2 do ball('Head','FrontCurls',V(.21,.20,.20),V(i*.17,.41,-.48),hair) end
 elseif s.Hat=='hood' then
  add('Head','HoodBack',V(1.21,1.15,.22),V(0,.06,.55),s.Color)
  for _,x in {-.56,.56} do add('Head','HoodSide',V(.20,1.22,1.35),V(x,.05,.02),s.Color) end
  add('Head','HoodTop',V(1.24,.16,1.35),V(0,.64,.02),s.Color)
  for i=-1,1 do ball('Head','HoodFringe',V(.27,.13,.22),V(i*.23,.46,-.49),hair) end
 elseif s.Hat=='beanie' then
  ball('Head','KnitCap',V(1.10,.59,1.08),V(0,.58,0),dark)
  add('Head','BeanieCuff',V(1.09,.15,1.08),V(0,.39,0),C(43,44,44))
  ball('Head','PomPom',V(.22,.22,.24),V(0,.93,0),dark)
  add('Head','CapPatch',V(.18,.09,.025),V(.2,.4,-.55),s.Id=='Lookout' and s.Color or white)
 elseif s.Hat=='flatcap' then
  ball('Head','FlatCapCrown',V(1.12,.28,1.10),V(0,.54,-.03),C(99,99,103))
  ball('Head','FlatCapPeak',V(.9,.065,.55),V(0,.44,-.54),C(78,78,81))
 elseif s.Hat=='fedora' or s.Hat=='whitehat' or s.Hat=='blackhat' then
  local hc=s.Hat=='whitehat' and white or dark
  ball('Head','FedoraBrim',V(1.48,.10,1.37),V(0,.55,0),hc)
  add('Head','FedoraCrown',V(1.03,.40,.91),V(0,.78,.03),hc)
  add('Head','HatBand',V(1.05,.09,.93),V(0,.62,.03),s.Id=='Gangster' and s.Accent or dark)
  if s.Id=='Gangster' or s.Id=='TheDon' then add('Head','RedFeather',V(.025,.3,.025),V(-.46,.82,.18),C(220,52,66),nil,CFrame.Angles(0,0,-.3)) end
 elseif s.Hat=='crown' then
  local p=add('Head','CrownBand',V(1.12,.19,1.09),V(0,.61,0),gold);metal(p)
  for i=-2,2 do
   local point=add('Head','CrownPoint',V(.19,.37,.15),V(i*.22,.84,-.39),gold)
   local mesh=Instance.new('SpecialMesh');mesh.MeshType=Enum.MeshType.Wedge;mesh.Parent=point
   add('Head','CrownJewel',V(.11,.10,.03),V(i*.22,.60,-.56),i%2==0 and C(205,44,61) or C(47,99,209),nil,CFrame.Angles(0,0,math.pi/4))
  end
 end
 if s.Id=='Bandit' then
  ball('Head','Bandana',V(1.02,.43,1.02),V(0,-.25,0),C(111,117,127))
  for x=-.36,.37,.18 do for _,y in {-.15,-.30} do ball('Head','BandanaPrint',V(.03,.026,.02),V(x,y,-.515),white) end end
 end
 if s.Id=='Crook' or s.Id=='Consigliere' or s.Id=='TheDon' or s.Id=='Underboss' then
  for _,side in {-1,1} do ball('Head','Moustache',V(.29,.095,.09),V(side*.12,-.22,-.516),s.Id=='Consigliere' and C(209,207,200) or C(73,62,47)) end
 end
 if s.Id=='Enforcer' then
  ball('Head','BeardChin',V(.70,.21,.23),V(0,-.42,-.44),C(115,78,48))
  for _,side in {-1,1} do add('Head','BeardSide',V(.16,.42,.29),V(side*.45,-.28,-.27),C(115,78,48)) end
 end
 -- Layered eyes and eyebrows give every morph an expression, not blank dots.
 for _,side in {-1,1} do
  local eyeY=s.Expression=='worried' and .11 or .07
  ball('Head','EyeWhite',V(.20,.18,.035),V(side*.21,eyeY,-.505),white)
  ball('Head','Iris',V(.095,.11,.028),V(side*.21,eyeY,-.53),s.Id=='Enforcer' and C(80,127,155) or C(106,81,48))
  ball('Head','Pupil',V(.05,.07,.025),V(side*.21,eyeY,-.547),dark)
  ball('Head','EyeGlint',V(.027,.03,.017),V(side*.19,eyeY+.022,-.565),Color3.new(1,1,1))
  local angle=s.Expression=='angry' and side*-.22 or s.Expression=='worried' and side*.28 or side*.08
  add('Head','Eyebrow',V(.20,.046,.023),V(side*.21,.24,-.512),hair,nil,CFrame.Angles(0,0,angle))
  if s.Expression=='sleepy' then add('Head','Eyelid',V(.21,.069,.026),V(side*.21,.13,-.55),s.Skin) end
 end
 ball('Head','Nose',V(.07,.11,.10),V(0,-.07,-.50),s.Skin:Lerp(C(150,99,57),.12))
 if s.Id~='Bandit' then
  if s.Expression=='happy' then
   ball('Head','Smile',V(.38,.17,.035),V(0,-.25,-.51),C(65,40,31))
   add('Head','SmileTeeth',V(.30,.048,.018),V(0,-.215,-.536),white)
  elseif s.Expression=='worried' then ball('Head','SurprisedMouth',V(.075,.12,.03),V(0,-.26,-.52),dark)
  else add('Head','Mouth',V(.26,.022,.025),V(.015,-.27,-.518),C(92,61,43),nil,CFrame.Angles(0,0,s.Expression=='smirk' and .15 or 0)) end
 end
 if s.Id=='CornerKid' then add('Head','CheekBandage',V(.19,.06,.02),V(-.32,-.14,-.49),C(243,220,180),nil,CFrame.Angles(0,0,-.25)) end
 if s.Id=='Lookout' then ball('Head','SweatDrop',V(.035,.10,.025),V(-.38,.2,-.48),C(113,210,238)) end
 if s.Id=='Enforcer' then add('Head','Scar',V(.021,.26,.023),V(-.30,.1,-.53),C(171,91,78),nil,CFrame.Angles(0,0,-.14)) end
 if s.Id=='GetawayDriver' or s.Id=='StreetBoss' or s.Id=='Underboss' or s.Id=='Kingpin' then
  for _,side in {-1,1} do
   add('Head','SunglassesFrame',V(.39,.24,.07),V(side*.225,.08,-.555),dark)
   add('Head','SunglassesLens',V(.31,.17,.025),V(side*.225,.08,-.60),C(32,38,44))
   add('Head','LensReflection',V(.025,.18,.018),V(side*.225,.08,-.62),C(132,148,154),nil,CFrame.Angles(0,0,.55))
  end
  add('Head','GlassesBridge',V(.13,.025,.04),V(0,.12,-.575),gold)
 elseif s.Id=='Consigliere' then
  for _,side in {-1,1} do for i=1,12 do local a=i/12*math.pi*2;metal(ball('Head','RoundSpectacleRim',V(.037,.04,.027),V(side*.225+math.cos(a)*.145,.08+math.sin(a)*.145,-.566),gold)) end end
  add('Head','GlassesBridge',V(.16,.025,.028),V(0,.10,-.565),gold)
 end
 return parent
end
function Art.mannequin(parent,cf,s,scale)
 scale=scale or 1;local m=Instance.new('Model');m.Name=s.Id..'Display';m.Parent=parent
 local b={}
 for _,r in ipairs({{'Torso',V(2,2,1),V(0,3,0)},{'Head',V(1.55,1.5,1.38),V(0,4.76,0)},{'LeftArm',V(1,2,1),V(-1.53,3,0)},{'RightArm',V(1,2,1),V(1.53,3,0)},{'LeftLeg',V(.98,2,1),V(-.52,1,0)},{'RightLeg',V(.98,2,1),V(.52,1,0)}}) do
  b[r[1]]=part(m,r[1],r[2]*scale,cf*CFrame.new(r[3]*scale),s.Color,true)
 end
 b.LeftShoe=b.LeftLeg;b.RightShoe=b.RightLeg
 local mesh=Instance.new('SpecialMesh');mesh.MeshType=Enum.MeshType.Head;mesh.Scale=V(.95,.98,.83);mesh.Parent=b.Head
 dress(m,b,s,true)
 return m
end
function Art.equip(character,s)
 local old=character:FindFirstChild('BlockCostume');if old then old:Destroy() end
 for _,v in character:GetChildren() do if v:IsA('Accessory') or v:IsA('Shirt') or v:IsA('Pants') or v:IsA('ShirtGraphic') then v:Destroy() end end
 local head=character:FindFirstChild('Head');if not head then return end
 for _,v in head:GetChildren() do if v:IsA('Decal') or v:IsA('SurfaceGui') and v.Name=='face' then v:Destroy() end end
 local m=Instance.new('Model');m.Name='BlockCostume';m.Parent=character
 local b={Head=head,Torso=character:FindFirstChild('UpperTorso') or character:FindFirstChild('Torso'),LeftArm=character:FindFirstChild('LeftUpperArm') or character:FindFirstChild('Left Arm'),RightArm=character:FindFirstChild('RightUpperArm') or character:FindFirstChild('Right Arm'),LeftLeg=character:FindFirstChild('LeftUpperLeg') or character:FindFirstChild('Left Leg'),RightLeg=character:FindFirstChild('RightUpperLeg') or character:FindFirstChild('Right Leg'),LeftShoe=character:FindFirstChild('LeftFoot') or character:FindFirstChild('Left Leg'),RightShoe=character:FindFirstChild('RightFoot') or character:FindFirstChild('Right Leg')}
 for _,p in character:GetChildren() do if p:IsA('BasePart') and p.Name~='HumanoidRootPart' then p.Color=(p.Name:find('Leg') or p.Name:find('Foot')) and s.Pants or (p.Name=='Head' or p.Name:find('Hand')) and s.Skin or s.Color end end
 dress(m,b,s,false)
end
return Art
