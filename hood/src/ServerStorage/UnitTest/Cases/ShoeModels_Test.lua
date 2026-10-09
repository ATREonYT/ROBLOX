return function(t)
 local M=require(game.ReplicatedStorage.Shared.Models.ShoeModels)
 local V=Vector3.new
 local function parts(m) local n=0 for _,d in m:GetDescendants() do if d:IsA('BasePart') then n+=1 end end return n end
 -- lowest point of a (possibly turned) part
 local function bottom(d) local _,_,_,_,_,_,a,b,c=d.CFrame:GetComponents() return d.CFrame.Position.Y-(math.abs(a)*d.Size.X+math.abs(b)*d.Size.Y+math.abs(c)*d.Size.Z)/2 end
 t.test('60 shoes, ten boxes of six, one per rarity',function()
  t.expect.equal(#M.Ids,60)
  local seen={}
  for i,id in M.Ids do
   local meta=M.Meta[id];t.expect.truthy(meta and type(meta.Name)=='string')
   t.expect.equal(meta.Box,M.BoxIds[math.floor((i-1)/6)+1]);t.expect.equal(meta.Rarity,(i-1)%6+1)
   t.expect.falsy(seen[id]);seen[id]=true
  end
 end)
 t.test('ids agree with Config.Shoes when it exists',function()
  local ok,Shoes=pcall(function() local c=game.ReplicatedStorage.Shared.Config:FindFirstChild('Shoes');return c and require(c) end)
  if not ok or type(Shoes)~='table' or type(Shoes.ById)~='table' then return end
  for id,s in Shoes.ById do local meta=M.Meta[id];t.expect.truthy(meta);if meta and s.Box then t.expect.equal(meta.Box,s.Box) end end
 end)
 t.test('every shoe builds within the part budget, Fit box on the foot',function()
  for _,id in M.Ids do
   for _,side in {'L','R'} do
    local m=M.shoe(id,side,1)
    t.expect.truthy(m.PrimaryPart and m.PrimaryPart.Name=='Fit')
    t.expect.truthy((m.PrimaryPart.Size-V(1,0.3,1)).Magnitude<1e-4)
    t.expect.truthy(m.PrimaryPart.CFrame.Position.Magnitude<1e-4)
    local n=parts(m)-1;t.expect.truthy(n<=60);t.expect.equal(n,M.Meta[id].Parts)
    for _,d in m:GetDescendants() do
     if d:IsA('BasePart') then t.expect.truthy(d.Anchored and not d.CanCollide and not d.CanTouch and not d.CanQuery and d.Size.X>0) end
    end
    m:Destroy()
   end
  end
 end)
 t.test('left and right are mirror images; the sole sits on the ground',function()
  local r=M.shoe('BlockRoyalty','R',1);local l=M.shoe('BlockRoyalty','L',1)
  local function lowX(m,f) local v=f==1 and -math.huge or math.huge for _,d in m:GetDescendants() do if d:IsA('BasePart') and d.Name~='Fit' then local x=d.CFrame.Position.X;if f==1 then v=math.max(v,x) else v=math.min(v,x) end end end return v end
  t.expect.near(lowX(r,1),-lowX(l,-1),1e-3)
  local lo=math.huge
  for _,d in r:GetDescendants() do if d:IsA('BasePart') and d.Name~='Fit' then lo=math.min(lo,bottom(d)) end end
  t.expect.near(lo,-0.15,0.02)
 end)
 t.test('pairs: two shoes, pivot at the soles, scale applies',function()
  for _,id in {'FreshCanvas','PlusOneInfinity'} do
   local m=M.pair(id,2)
   t.expect.truthy(m.PrimaryPart and m.PrimaryPart.Name=='Root')
   t.expect.truthy(m:FindFirstChild(id..'_L') and m:FindFirstChild(id..'_R'))
   t.expect.truthy(parts(m)<=123)
   local lo=math.huge for _,d in m:GetDescendants() do if d:IsA('BasePart') and d.Transparency<1 then lo=math.min(lo,bottom(d)) end end
   t.expect.near(lo,0,0.02)
   m:Destroy()
  end
 end)
 -- Fake characters: block R15 (canonical sizes, or scaled) and R6.
 local function rig(r15,k)
  k=k or 1
  local rows=r15 and {{'HumanoidRootPart',V(2,2,1),V(0,3,0)},{'LowerTorso',V(2,.4,1),V(0,2.2,0)},{'UpperTorso',V(2,1.6,1),V(0,3.2,0)},{'Head',V(1.2,1.2,1.2),V(0,4.6,0)},
   {'LeftUpperLeg',V(1,1.217,1),V(-.5,1.3915,0)},{'LeftLowerLeg',V(1,1.193,1),V(-.5,.8965,0)},{'LeftFoot',V(1,.3,1),V(-.5,.15,0)},
   {'RightUpperLeg',V(1,1.217,1),V(.5,1.3915,0)},{'RightLowerLeg',V(1,1.193,1),V(.5,.8965,0)},{'RightFoot',V(1,.3,1),V(.5,.15,0)}}
   or {{'HumanoidRootPart',V(2,2,1),V(0,3,0)},{'Torso',V(2,2,1),V(0,3,0)},{'Head',V(2,1,1),V(0,4.5,0)},{'Left Leg',V(1,2,1),V(-.5,1,0)},{'Right Leg',V(1,2,1),V(.5,1,0)}}
  local m=Instance.new('Model');local p={}
  for _,r in rows do local x=Instance.new('Part');x.Name=r[1];x.Size=r[2]*k;x.CFrame=CFrame.new(r[3]*k);x.Parent=m;p[r[1]]=x end
  return m,p
 end
 local function checkWorn(m,hosts)
  local shoes=m:FindFirstChild('HoodShoes');t.expect.truthy(shoes)
  local n=0
  for _,d in shoes:GetDescendants() do
   if d:IsA('BasePart') and d.Name~='ShoeFX' then
    n+=1
    t.expect.truthy(not d.Anchored and d.Massless and not d.CanCollide and not d.CanTouch and not d.CanQuery)
    local w=d:FindFirstChildOfClass('Weld');t.expect.truthy(w and w.Part1==d and hosts[w.Part0])
    -- the weld puts the part where it was built
    t.expect.truthy((w.Part0.CFrame*w.C0).Position:FuzzyEq(d.CFrame.Position,1e-3))
   end
  end
  return n
 end
 t.test('wear() welds a pair onto an R15 character (feet and lower legs), any scale',function()
  for _,k in {1,1.3} do
   local m,p=rig(true,k)
   local hosts={[p.LeftFoot]=true,[p.RightFoot]=true,[p.LeftLowerLeg]=true,[p.RightLowerLeg]=true}
   local cleanup=M.wear(m,'StreetAngel')
   local n=checkWorn(m,hosts);t.expect.equal(n,2*M.Meta.StreetAngel.Parts)
   -- the collar rides the shin, the sole the foot; the soles reach the ground at this scale
   local lowY=math.huge
   for _,d in m.HoodShoes:GetDescendants() do
    if d:IsA('BasePart') then
     local w=d:FindFirstChildOfClass('Weld')
     if d.Name=='Collar' then t.expect.truthy(w.Part0.Name:find('LowerLeg')) end
     if d.Name:find('Sole') then t.expect.truthy(w.Part0.Name:find('Foot')) end
     lowY=math.min(lowY,bottom(d))
    end
   end
   t.expect.near(lowY,0,0.02*k)
   cleanup();t.expect.falsy(m:FindFirstChild('HoodShoes'))
   m:Destroy()
  end
 end)
 t.test('wear() welds a pair onto an R6 character (leg bottoms)',function()
  local m,p=rig(false)
  M.wear(m,'BlockRoyalty')
  local n=checkWorn(m,{[p['Left Leg']]=true,[p['Right Leg']]=true});t.expect.equal(n,2*M.Meta.BlockRoyalty.Parts)
  m:Destroy()
 end)
 t.test('re-wearing replaces the pair; the look\'s own shoe pieces hide and come back',function()
  local m,p=rig(true)
  local costume=Instance.new('Model');costume.Name='BlockCostume';costume.Parent=m
  local sole=Instance.new('Part');sole.Name='Sole';sole.Transparency=0;sole.Parent=costume
  local tie=Instance.new('Part');tie.Name='Tie';tie.Parent=costume
  M.wear(m,'FreshCanvas')
  local cleanup=M.wear(m,'Phoenix')
  local n=0 for _,c in m:GetChildren() do if c.Name=='HoodShoes' then n+=1 end end
  t.expect.equal(n,1);t.expect.equal(m.HoodShoes:GetAttribute('ShoeId'),'Phoenix')
  t.expect.equal(sole.Transparency,1);t.expect.equal(tie.Transparency,0)
  cleanup();t.expect.equal(sole.Transparency,0);t.expect.falsy(m:FindFirstChild('HoodShoes'))
  m:Destroy()
 end)
 t.test('fx escalates with rarity and accepts names',function()
  local counts={}
  for r=1,6 do
   local m=M.pair(M.Ids[r],1)
   local h=M.fx(m,r)
   local n=0
   if h then for _,d in h:GetDescendants() do if d:IsA('ParticleEmitter') or d:IsA('PointLight') then n+=1 end end end
   counts[r]=n
   m:Destroy()
  end
  t.expect.equal(counts[1],0)
  for r=2,6 do t.expect.truthy(counts[r]>=counts[r-1]) end
  local m=M.pair('Glacier',1);t.expect.truthy(M.fx(m,'Legendary'));m:Destroy()
 end)
 t.test('viewport frames a pair',function()
  local vf=M.viewport('Comet')
  t.expect.truthy(vf:IsA('ViewportFrame') and vf:FindFirstChildOfClass('Camera') and vf:FindFirstChild('Comet'))
  vf:Destroy()
 end)
end
