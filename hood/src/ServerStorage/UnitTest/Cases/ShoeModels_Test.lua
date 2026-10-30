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
   -- the tongue rides the shin; the collar and the sole ride the foot; the soles reach the ground at this scale
   local lowY,seen=math.huge,{}
   for _,d in m.HoodShoes:GetDescendants() do
    if d:IsA('BasePart') then
     local w=d:FindFirstChildOfClass('Weld')
     if d.Name=='Tongue' then t.expect.truthy(w.Part0.Name:find('LowerLeg'));seen.Tongue=true end
     if d.Name=='Collar' then t.expect.truthy(w.Part0.Name:find('Foot'));seen.Collar=true end
     if d.Name:find('Sole') then t.expect.truthy(w.Part0.Name:find('Foot')) end
     lowY=math.min(lowY,bottom(d))
    end
   end
   t.expect.truthy(seen.Tongue and seen.Collar)
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
 -- (brief 30) the 22 World 1 shoes: the user's render sheets as BoxKit rows
 local W1={'FreshCanvas','RedRocket','Checkmate','ChromeKicks','StreetAngel','BlockRoyalty','SprayTag','DripTag','PaintSplash','NeonBomb','WildStyle','Masterpiece',
  'SilverStreak','MidnightChrome','RainbowDrip','Hologram','PlatinumWings','GoldenHour','Starlight','SolarFlare','AstroCrown','TheGrail'}
 local function named(m,name) local n=0 for _,d in m:GetDescendants() do if d:IsA('BasePart') and d.Name==name then n+=1 end end return n end
 t.test('the 22 World 1 shoes are their BoxKit rows, with the sheets\' anatomy',function()
  local P=require(game.ReplicatedStorage.Shared.Models.ShoeParts)
  t.expect.equal(#P.Ids,22)
  for i,id in W1 do
   t.expect.equal(P.Ids[i],id)
   local m=M.shoe(id,'R',1)
   -- (Oct 28) plus the polish's sole line where the sheet has no stripe
   local extra=named(m,'SoleLine')
   t.expect.equal(parts(m)-1,#P.Shoes[id]+extra);t.expect.equal(M.Meta[id].Parts,#P.Shoes[id]+extra)
   -- a layered sole, a toe cap, the stepped upper, the lace bed and its bars, the square collar with round corners, the
   -- lining, the tongue and the heel tab (Astro Crown's crown takes the tab's place)
   t.expect.truthy(named(m,'Outsole')>=2 and named(m,'Sole')>=2 and named(m,'ToeBox')>=2 and named(m,'Quarter')==3 and named(m,'Eyestay')==1)
   t.expect.truthy(named(m,'Lace')>=3 and named(m,'Collar')==4 and named(m,'CollarCorner')==4 and named(m,'Lining')==1 and named(m,'Tongue')==1)
   t.expect.truthy(named(m,'HeelTab')==(id=='AstroCrown' and 0 or 1))
   m:Destroy()
  end
 end)
 t.test('wings, crowns and spikes where the sheets have them',function()
  local winged={StreetAngel=true,Hologram=true,PlatinumWings=true,AstroCrown=true,TheGrail=true}
  local crowned={BlockRoyalty=true,AstroCrown=true}
  for _,id in W1 do
   local m=M.shoe(id,'R',1)
   t.expect.equal(named(m,'Feather')>=4,winged[id]==true)
   t.expect.equal(named(m,'CrownBand')==1,crowned[id]==true)
   t.expect.equal(named(m,'Spike')>=8,id=='SolarFlare')
   m:Destroy()
  end
 end)
 t.test('a worn pair never crosses the body\'s centre line; the marks read the same way on both shoes',function()
  for _,id in W1 do
   -- built on a canonical foot: the right shoe stays right of x = -0.5 (its foot's inner face), the left mirrors it
   local r=M.shoe(id,'R',1);local l=M.shoe(id,'L',1)
   local lo=math.huge for _,d in r:GetDescendants() do if d:IsA('BasePart') and d.Name~='Fit' then local _,_,_,a,b,c=d.CFrame:GetComponents() lo=math.min(lo,d.CFrame.Position.X-(math.abs(a)*d.Size.X+math.abs(b)*d.Size.Y+math.abs(c)*d.Size.Z)/2) end end
   t.expect.truthy(lo>=-0.506)
   r:Destroy();l:Destroy()
  end
  -- Fresh Canvas's C: on the left shoe it is the right shoe's C turned 180 degrees about its own upright centre line
  local spec=M._specs('FreshCanvas')
  local text
  for _,s in spec do if s.text then text=s.text break end end
  t.expect.truthy(text and text.face=='x')
  local r=M.shoe('FreshCanvas','R',1);local l=M.shoe('FreshCanvas','L',1)
  local function cs(m) local out={} for _,d in m:GetDescendants() do if d.Name=='MarkC' then table.insert(out,d.CFrame.Position) end end return out end
  local a,b=cs(r),cs(l)
  t.expect.equal(#a,3);t.expect.equal(#b,3)
  for i=1,3 do
   local zc=text.centre.Z
   t.expect.truthy(b[i]:FuzzyEq(Vector3.new(-a[i].X,a[i].Y,2*zc-a[i].Z),1e-3))
  end
  r:Destroy();l:Destroy()
 end)
 t.test('viewport frames a pair',function()
  local vf=M.viewport('Comet')
  t.expect.truthy(vf:IsA('ViewportFrame') and vf:FindFirstChildOfClass('Camera') and vf:FindFirstChild('Comet'))
  vf:Destroy()
 end)
 -- (Oct 28) the polish: same shapes, a cleaner finish
 t.test('the polish: clean finish by rarity, laces that read, no z-fighting, a sole line only where it fits',function()
  local Pol=M._polish
  local lines=0
  for _,id in M.AllIds do
   local list,def=M._specs(id)
   -- every coplanar overlap was tidied when the specs were made (a second pass finds none)
   t.expect.equal(Pol.tidy(list),0)
   local bed
   for _,s in list do if s.name=='Eyestay' then bed=s.color break end end
   local rarity=M.Meta[id].Rarity
   local m=M.shoe(id,'R',1)
   for _,d in m:GetDescendants() do
    if d:IsA('BasePart') and d.Name~='Fit' then
     t.expect.truthy(d.Material~=Enum.Material.Plastic and d.Material~=Enum.Material.Fabric)
     if d.Name=='Lace' and bed and not def.rainbowLaces then t.expect.falsy(Pol.near(d.Color,bed)) end
     if d.Name=='Quarter' and d.Material==Enum.Material.SmoothPlastic then t.expect.equal(d.Reflectance>0,rarity>=2) end
    end
   end
   local n=named(m,'SoleLine')
   if n>0 then lines+=1;t.expect.equal(named(m,'Stripe')+named(m,'Seam'),0) end
   t.expect.truthy(parts(m)-1<=60)
   m:Destroy()
  end
  t.expect.truthy(lines>=3)
 end)
 t.test('rounded blocks and wedges when RoundMesh is ready: same pieces, sizes and places; Parts again without it',function()
  local R=M.RoundMesh
  t.expect.truthy(R)
  -- the packed meshes decode to size 1 meshes with valid triangles
  for _,name in R.Names do
   local v,n,tr=R.decode(name)
   t.expect.equal(#tr,R.Data[name].Tris)
   for _,p in v do t.expect.truthy(math.abs(p.X)<=0.5001 and math.abs(p.Y)<=0.5001 and math.abs(p.Z)<=0.5001) end
   for _,q in tr do for i=1,3 do t.expect.truthy(v[q[i]]~=nil and n[q[i+3]]~=nil) end end
  end
  local sharp=M.shoe('SilverStreak','R',1)
  local function tpl(name) local ok,p=pcall(Instance.new,'MeshPart');if not ok then p=Instance.new('Part') end;p.Name=name;p:SetAttribute('Tpl',name);return p end
  R.inject({RoundBox=tpl('RoundBox'),RoundWedge=tpl('RoundWedge')})
  local ok,err=pcall(function()
   local soft=M.shoe('SilverStreak','R',1)
   local a,b={},{}
   for _,d in sharp:GetDescendants() do if d:IsA('BasePart') then table.insert(a,d) end end
   for _,d in soft:GetDescendants() do if d:IsA('BasePart') then table.insert(b,d) end end
   t.expect.equal(#a,#b)
   local rounded=0
   for i,d in a do
    local e=b[i]
    t.expect.equal(d.Name,e.Name)
    t.expect.truthy((d.Size-e.Size).Magnitude<1e-4 and (d.CFrame.Position-e.CFrame.Position).Magnitude<1e-4 and d.Color==e.Color)
    if e:GetAttribute('Tpl') then
     rounded+=1
     t.expect.equal(e:GetAttribute('Tpl'),d:IsA('WedgePart') and 'RoundWedge' or 'RoundBox')
     t.expect.truthy(e.Anchored and not e.CanCollide and not e.CanQuery)
    end
   end
   t.expect.truthy(rounded>=20)
   -- worn: welded like the Parts
   local ch=Instance.new('Model')
   for _,n in {'LeftFoot','RightFoot','LeftLowerLeg','RightLowerLeg'} do local p=Instance.new('Part');p.Name=n;p.Size=n:find('Foot') and V(1,0.3,1) or V(1,1.193,1);p.Parent=ch end
   local cleanup=M.wear(ch,'SilverStreak',{noFx=true})
   local welded=0
   for _,d in ch.HoodShoes:GetChildren() do if d:GetAttribute('Tpl') and d:FindFirstChild('ShoeWeld') then welded+=1 end end
   t.expect.equal(welded,2*rounded)
   cleanup();t.expect.falsy(ch:FindFirstChild('HoodShoes'))
   soft:Destroy()
  end)
  R.inject(nil)
  t.expect.truthy(ok,err)
  local again=M.shoe('SilverStreak','R',1)
  for _,d in again:GetDescendants() do t.expect.falsy(d:GetAttribute('Tpl')) end
  again:Destroy();sharp:Destroy()
 end)
end
