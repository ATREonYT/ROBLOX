return function(t)
 local S=require(game.ReplicatedStorage.Shared.Config.Skins)
 local Art=require(game.ReplicatedStorage.Shared.SkinArt)
 local V=Vector3.new
 -- Saved in profiles and balanced: the looks' ids, unlock power and gain never change.
 t.test('look ids, requirements and gains are unchanged',function()
  local want={{'CornerKid',0,1},{'Pickpocket',25,2},{'Lookout',75,3},{'Bandit',150,4},{'Hustler',300,6},{'Crook',600,8},{'GetawayDriver',1000,10},{'Enforcer',1500,12},{'StreetBoss',2000,16},{'Gangster',3000,22},{'Capo',5000,30},{'Consigliere',8000,42},{'Underboss',12000,58},{'TheDon',18000,80},{'Kingpin',30000,110}}
  for i,w in want do local s=S.List[i];t.expect.equal(s.Id,w[1]);t.expect.equal(s.Required,w[2]);t.expect.equal(s.Gain,w[3]);t.expect.equal(s.Index,i) end
 end)
 t.test('every look has a recipe within the part budget',function()
  for _,s in S.List do
   t.expect.truthy(Art.Looks[s.Look or s.Id])
   local r=Art.recipe(s)
   t.expect.truthy(#r.pieces>=30 and #r.pieces<=85)
   for _,p in r.pieces do t.expect.truthy(Art.Rig[p.seg]);t.expect.truthy(p.size.X>0 and p.size.Y>0 and p.size.Z>0) end
   for seg in Art.Rig do t.expect.truthy(typeof(r.body[seg])=='Color3') end
   t.expect.truthy(type(s.Pose)=='string' and Art.Poses[s.Pose])
  end
 end)
 t.test('display figures build in every pose',function()
  local folder=Instance.new('Folder')
  for _,s in S.List do
   local m=Art.posed(folder,CFrame.new(),s,1.1)
   t.expect.truthy(m.PrimaryPart and m:FindFirstChild('Head') and m:FindFirstChild('LeftUpperArm'))
   for _,d in m:GetDescendants() do if d:IsA('BasePart') then t.expect.truthy(d.Anchored and not d.CanCollide) end end
  end
  for name in Art.Poses do Art.posed(folder,CFrame.new(),S.List[15],1,name) end
  Art.mannequin(folder,CFrame.new(),S.List[1],1)
  folder:Destroy()
 end)
 -- A block rig with Motor6Ds (R15 or R6), posed by each joint's 'Pose' attribute.
 local function rig(r15)
  local rows=r15 and {{'HumanoidRootPart',V(2,2,1),V(0,3,0)},{'LowerTorso',V(2,.4,1),V(0,2.2,0)},{'UpperTorso',V(2,1.6,1),V(0,3.2,0)},{'Head',V(1.2,1.2,1.2),V(0,4.6,0)},
   {'LeftUpperArm',V(1,1.169,1),V(-1.5,3.4155,0)},{'LeftLowerArm',V(1,1.052,1),V(-1.5,2.826,0)},{'LeftHand',V(1,.3,1),V(-1.5,2.15,0)},
   {'RightUpperArm',V(1,1.169,1),V(1.5,3.4155,0)},{'RightLowerArm',V(1,1.052,1),V(1.5,2.826,0)},{'RightHand',V(1,.3,1),V(1.5,2.15,0)},
   {'LeftUpperLeg',V(1,1.217,1),V(-.5,1.3915,0)},{'LeftLowerLeg',V(1,1.193,1),V(-.5,.8965,0)},{'LeftFoot',V(1,.3,1),V(-.5,.15,0)},
   {'RightUpperLeg',V(1,1.217,1),V(.5,1.3915,0)},{'RightLowerLeg',V(1,1.193,1),V(.5,.8965,0)},{'RightFoot',V(1,.3,1),V(.5,.15,0)}}
   or {{'HumanoidRootPart',V(2,2,1),V(0,3,0)},{'Torso',V(2,2,1),V(0,3,0)},{'Head',V(2,1,1),V(0,4.5,0)},{'Left Arm',V(1,2,1),V(-1.5,3,0)},{'Right Arm',V(1,2,1),V(1.5,3,0)},{'Left Leg',V(1,2,1),V(-.5,1,0)},{'Right Leg',V(1,2,1),V(.5,1,0)}}
  local joints=r15 and {{'Root','HumanoidRootPart','LowerTorso',V(0,2,0)},{'Waist','LowerTorso','UpperTorso',V(0,2.4,0)},{'Neck','UpperTorso','Head',V(0,4,0)},
   {'LeftShoulder','UpperTorso','LeftUpperArm',V(-1,3.76,0)},{'LeftElbow','LeftUpperArm','LeftLowerArm',V(-1.5,3.05,0)},{'LeftWrist','LeftLowerArm','LeftHand',V(-1.5,2.3,0)},
   {'RightShoulder','UpperTorso','RightUpperArm',V(1,3.76,0)},{'RightElbow','RightUpperArm','RightLowerArm',V(1.5,3.05,0)},{'RightWrist','RightLowerArm','RightHand',V(1.5,2.3,0)},
   {'LeftHip','LowerTorso','LeftUpperLeg',V(-.5,2,0)},{'LeftKnee','LeftUpperLeg','LeftLowerLeg',V(-.5,1.05,0)},{'LeftAnkle','LeftLowerLeg','LeftFoot',V(-.5,.3,0)},
   {'RightHip','LowerTorso','RightUpperLeg',V(.5,2,0)},{'RightKnee','RightUpperLeg','RightLowerLeg',V(.5,1.05,0)},{'RightAnkle','RightLowerLeg','RightFoot',V(.5,.3,0)}}
   or {{'RootJoint','HumanoidRootPart','Torso',V(0,3,0)},{'Neck','Torso','Head',V(0,4,0)},{'Left Shoulder','Torso','Left Arm',V(-1,3.5,0)},{'Right Shoulder','Torso','Right Arm',V(1,3.5,0)},{'Left Hip','Torso','Left Leg',V(-.5,2,0)},{'Right Hip','Torso','Right Leg',V(.5,2,0)}}
  local m=Instance.new('Model');local parts={}
  for _,r in rows do local p=Instance.new('Part');p.Name=r[1];p.Size=r[2];p.CFrame=CFrame.new(r[3]);p.Parent=m;parts[r[1]]=p end
  for _,j in joints do local mo=Instance.new('Motor6D');mo.Name=j[1];mo.Part0=parts[j[2]];mo.Part1=parts[j[3]];mo.C0=parts[j[2]].CFrame:Inverse()*CFrame.new(j[4]);mo.C1=parts[j[3]].CFrame:Inverse()*CFrame.new(j[4]);mo.Parent=parts[j[3]] end
  local mesh=Instance.new('SpecialMesh');mesh.MeshType=Enum.MeshType.Head;mesh.Scale=r15 and V(1,1,1) or V(1.25,1.25,1.25);mesh.Parent=parts.Head
  Instance.new('Humanoid').Parent=m;Instance.new('Accessory').Parent=m;Instance.new('Shirt').Parent=m
  local face=Instance.new('Decal');face.Name='face';face.Parent=parts.Head
  return m,parts
 end
 -- Physics stand-in: joints from the root out, then every weld.
 local function solve(m)
  local done={[m.HumanoidRootPart]=true};local again=true
  while again do again=false
   for _,d in m:GetDescendants() do if d:IsA('Motor6D') and done[d.Part0] and not done[d.Part1] then d.Part1.CFrame=d.Part0.CFrame*d.C0*(d:GetAttribute('Pose') or CFrame.new())*d.C1:Inverse();done[d.Part1]=true;again=true end end
  end
  for _,d in m:GetDescendants() do if d:IsA('Weld') then d.Part1.CFrame=d.Part0.CFrame*d.C0*d.C1:Inverse() end end
 end
 for _,r15 in {true,false} do
  t.test((r15 and 'R15' or 'R6')..' characters wear every look safely',function()
   for _,s in S.List do
    local m,parts=rig(r15)
    Art.equip(m,s);Art.equip(m,s) -- re-equip replaces
    local n=0;for _,c in m:GetChildren() do if c.Name=='BlockCostume' then n+=1 end end
    t.expect.equal(n,1);t.expect.falsy(m:FindFirstChildOfClass('Accessory'));t.expect.falsy(m:FindFirstChildOfClass('Shirt'));t.expect.falsy(parts.Head:FindFirstChildOfClass('Decal'))
    for _,p in m.BlockCostume:GetDescendants() do
     if p:IsA('BasePart') then
      t.expect.truthy(not p.Anchored and p.Massless and not p.CanCollide and not p.CanTouch and not p.CanQuery)
      local w=p:FindFirstChildOfClass('Weld');t.expect.truthy(w and w.Part1==p and w.Part0 and w.Part0.Parent==m)
     end
    end
    m:Destroy()
   end
  end)
 end
 -- Pieces follow only their own part, so equipping mid-animation gives the same costume once back at rest.
 t.test('costume does not depend on the pose it was equipped in',function()
  for _,s in {S.List[1],S.List[8],S.List[15]} do
   local a=rig(true);Art.equip(a,s);solve(a)
   local b=rig(true)
   for _,d in b:GetDescendants() do if d:IsA('Motor6D') then d:SetAttribute('Pose',CFrame.Angles(math.rad(25),math.rad(10),math.rad(-15))) end end
   solve(b);Art.equip(b,s);for _,d in b:GetDescendants() do if d:IsA('Motor6D') then d:SetAttribute('Pose',nil) end end;solve(b)
   local pa,pb=a.BlockCostume:GetChildren(),b.BlockCostume:GetChildren()
   t.expect.equal(#pa,#pb)
   for i,p in pa do t.expect.truthy((p.CFrame.Position-pb[i].CFrame.Position).Magnitude<1e-3) end
   a:Destroy();b:Destroy()
  end
 end)
 t.test('a recoloured copy (lobby NPC) keeps its recipe',function()
  local copy=table.clone(S.ById.Crook);copy.Id='SparRed';copy.Color=Color3.new(1,0,0)
  local r=Art.recipe(copy);t.expect.equal(#r.pieces,#Art.recipe(S.ById.Crook).pieces);t.expect.equal(r.body.UpperTorso,Color3.new(1,0,0))
 end)
 -- The costume never changes who the player is: their skin tone stays, and unequip gives the avatar back
 -- (accessories, dynamic-head face, textures, colours).
 t.test('keeps the player skin tone and unequip restores the avatar',function()
  local m,parts=rig(true)
  local tone=Color3.fromRGB(92,58,40)
  for _,p in m:GetChildren() do if p:IsA('BasePart') then p.Color=tone end end
  local bc=Instance.new('BodyColors');bc.HeadColor3=tone;bc.Parent=m
  local head=Instance.new('MeshPart');head.Name='Head';head.Size=Vector3.new(1.2,1.2,1.2);head.CFrame=parts.Head.CFrame;head.TextureID='rbxassetid://1';head.Color=tone
  local fc=Instance.new('FaceControls');fc.Parent=head;local sa=Instance.new('SurfaceAppearance');sa.Parent=head
  parts.Head:Destroy();head.Parent=m
  local acc=m:FindFirstChildOfClass('Accessory')
  Art.equip(m,S.ById.Kingpin);Art.equip(m,S.ById.TheDon)
  t.expect.equal(head.Color,tone);t.expect.equal(m.LeftHand.Color,tone)
  t.expect.falsy(head:FindFirstChildOfClass('FaceControls'));t.expect.falsy(head:FindFirstChildOfClass('SurfaceAppearance'));t.expect.equal(head.TextureID,'')
  t.expect.falsy(acc.Parent)
  Art.unequip(m)
  t.expect.falsy(m:FindFirstChild('BlockCostume'));t.expect.equal(acc.Parent,m);t.expect.equal(fc.Parent,head);t.expect.equal(sa.Parent,head)
  t.expect.equal(head.TextureID,'rbxassetid://1');t.expect.equal(m.UpperTorso.Color,tone);t.expect.truthy(m:FindFirstChildOfClass('BodyColors'))
  m:Destroy()
 end)
 t.test('only the top tiers carry one small sparkle emitter',function()
  for _,s in S.List do
   local m=rig(true);Art.equip(m,s)
   local n=0;for _,d in m.BlockCostume:GetDescendants() do if d:IsA('ParticleEmitter') then n+=1;t.expect.truthy(d.Rate<=4) end end
   t.expect.equal(n,s.Glow and 1 or 0);t.expect.equal(s.Glow~=nil,s.Index>=11)
   m:Destroy()
  end
 end)
end
