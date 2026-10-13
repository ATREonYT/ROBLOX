return function(t)
 local RS=game.ReplicatedStorage
 local FX=require(RS.Shared.ShoeFX)
 local M=require(RS.Shared.Models.ShoeModels)
 local Shoes=require(RS.Shared.Config.Shoes)
 local V=Vector3.new
 local ORDER={'Common','Rare','Epic','Legendary','Mythic','Secret'}
 local function count(root,class) local n=0 for _,d in root:GetDescendants() do if d:IsA(class) then n+=1 end end return n end
 -- the invisible holder parts (a Secret's halo beads are ShoeFX parts too, but visible)
 local function holders(root) local n=0 for _,d in root:GetDescendants() do if d:IsA('BasePart') and d.Name=='ShoeFX' and d.Transparency>=1 then n+=1 end end return n end
 local function beads(root) local n=0 for _,d in root:GetDescendants() do if d:IsA('BasePart') and d.Name=='ShoeFX' and d.Transparency<1 then n+=1 end end return n end

 t.test('tiers: pure data, one row per rarity, escalating, the rarity colours',function()
  for rank,id in ORDER do
   local row=FX.tier(id)
   t.expect.equal(row.Rank,rank);t.expect.equal(row.Id,id);t.expect.equal(FX.tier(rank),row);t.expect.equal(FX.Tiers[id],row)
   t.expect.equal(FX.tier(Shoes.RarityById[id]),row)
   t.expect.equal(row.Color,Shoes.RarityById[id].Color)
   t.expect.truthy(typeof(row.Accent)=='Color3' and typeof(row.Gradient)=='ColorSequence')
   if rank>1 then
    local prev=FX.tier(rank-1)
    for _,k in {'Glow','Rays','Sparkles','Shake','Hold'} do t.expect.truthy(row[k]>=prev[k]) end
   end
  end
  t.expect.equal(FX.tier('nope').Rank,1);t.expect.equal(FX.tier(99).Rank,6)
  t.expect.falsy(FX.tier(1).Glint);t.expect.truthy(FX.tier(2).Glint)
  t.expect.truthy(FX.tier(4).Trail and not FX.tier(3).Trail)
  t.expect.truthy(FX.tier(5).EdgeGlow and not FX.tier(4).EdgeGlow)
  t.expect.truthy(FX.tier(6).Rainbow and FX.tier(6).Halo and not FX.tier(5).Rainbow)
  t.expect.truthy(table.isfrozen(FX.Tiers) and table.isfrozen(FX.tier(3)))
 end)

 t.test('pair effects escalate by rank within the budget; every emitter is set up the house way',function()
  FX.Quality='high'
  local lastLive=-1
  for rank,id in ORDER do
   local m=M.pair(Shoes.Boxes[1].Shoes[rank],1)
   local h=FX.apply(m,id,{context='follower'})
   if rank==1 then t.expect.falsy(h) else
    t.expect.truthy(h and h.Name=='ShoeFX' and h.Transparency==1 and not h.CanCollide and not h.CanQuery and not h.CanTouch)
    local live=FX.live(m)
    t.expect.truthy(live>lastLive);lastLive=live
    t.expect.truthy(live<=FX.Budget.follower[rank]+1)
    for _,d in m:GetDescendants() do
     if d:IsA('ParticleEmitter') then
      t.expect.equal(d.LightInfluence,0);t.expect.truthy(d.Rate<=8)
      local k=d.Transparency.Keypoints;local s=d.Size.Keypoints
      -- fades in and out (transparency 1 or size 0 at both ends)
      t.expect.truthy(k[1].Value>=0.99 or s[1].Value<=1e-3);t.expect.truthy(k[#k].Value>=0.99 or s[#s].Value<=1e-3 or k[#k].Value>=0.3)
      t.expect.truthy(type(d:GetAttribute('PreviewTexture'))=='string' and d.Texture~='')
     end
    end
    t.expect.equal(count(m,'PointLight'),rank>=4 and 1 or 0)
    for _,l in m:GetDescendants() do if l:IsA('PointLight') then t.expect.falsy(l.Shadows) end end
    t.expect.equal(count(m,'Trail'),rank>=4 and 1 or 0)
    t.expect.equal(m:FindFirstChild('Halo',true)~=nil,rank==6)
    t.expect.equal(beads(m),rank==6 and 12 or 0)
   end
   m:Destroy()
  end
  FX.Quality=nil
 end)

 t.test('low graphics keeps each tier\'s signature at a lower rate, with no light',function()
  for rank=2,6 do
   FX.Quality='high'
   local a=M.pair(Shoes.Boxes[2].Shoes[rank],1);FX.apply(a,rank)
   FX.Quality='low'
   local b=M.pair(Shoes.Boxes[2].Shoes[rank],1);FX.apply(b,rank)
   t.expect.truthy(FX.live(b)<FX.live(a));t.expect.truthy(FX.live(b)<=FX.Budget.low[rank]+0.5)
   t.expect.equal(count(b,'PointLight'),0);t.expect.truthy(count(b,'ParticleEmitter')>=1)
   t.expect.equal(count(b,'Trail'),rank>=4 and 1 or 0)
   a:Destroy();b:Destroy()
  end
  FX.Quality=nil
 end)

 t.test('worn effects: per foot, welded to the feet, one light, a trail per foot from Legendary',function()
  FX.Quality='high'
  local rows={{'HumanoidRootPart',V(2,2,1),V(0,3,0)},{'LeftUpperLeg',V(1,1.217,1),V(-.5,1.3915,0)},{'LeftLowerLeg',V(1,1.193,1),V(-.5,.8965,0)},{'LeftFoot',V(1,.3,1),V(-.5,.15,0)},
   {'RightUpperLeg',V(1,1.217,1),V(.5,1.3915,0)},{'RightLowerLeg',V(1,1.193,1),V(.5,.8965,0)},{'RightFoot',V(1,.3,1),V(.5,.15,0)}}
  for rank,id in ORDER do
   local m=Instance.new('Model')
   for _,r in rows do local x=Instance.new('Part');x.Name=r[1];x.Size=r[2];x.CFrame=CFrame.new(r[3]);x.Parent=m end
   local shoe=Shoes.Boxes[1].Shoes[rank]
   M.wear(m,shoe)
   local shoes=m:FindFirstChild('HoodShoes')
   t.expect.equal(holders(shoes),rank>=2 and 2 or 0)
   for _,d in shoes:GetDescendants() do
    if d:IsA('BasePart') and d.Name=='ShoeFX' and d.Transparency>=1 then
     local w=d:FindFirstChildOfClass('Weld');t.expect.truthy(w and w.Part0 and w.Part0.Name:find('Foot'))
     t.expect.truthy(d.Massless and not d.CanCollide and not d.Anchored)
    elseif d:IsA('BasePart') and d.Name=='ShoeFX' then
     -- a halo bead: welded to its holder, untouchable
     local w=d:FindFirstChildOfClass('WeldConstraint');t.expect.truthy(w and w.Part0 and w.Part0.Name=='ShoeFX' and w.Part0.Transparency>=1)
     t.expect.truthy(d.Massless and not d.CanCollide and not d.CanQuery and not d.CanTouch and not d.Anchored)
    end
   end
   t.expect.equal(beads(shoes),rank==6 and 16 or 0)
   t.expect.equal(count(shoes,'PointLight'),rank>=4 and 1 or 0)
   t.expect.equal(count(shoes,'Trail'),rank>=4 and 2 or 0)
   t.expect.truthy(FX.live(shoes)<=FX.Budget.worn[rank]+1)
   m:Destroy()
  end
  FX.Quality=nil
 end)

 t.test('LOD: setEnabled and setDensity write the emitters, trails and lights',function()
  local m=M.pair('BlockRoyalty',1);FX.apply(m,'Secret')
  local before=FX.live(m)
  FX.setDensity(m,0.5);t.expect.near(FX.live(m),before*0.5,1e-3)
  FX.setDensity(m,1);t.expect.near(FX.live(m),before,1e-3)
  FX.setEnabled(m,false)
  for _,d in m:GetDescendants() do if d:IsA('ParticleEmitter') or d:IsA('Trail') or d:IsA('Light') then t.expect.falsy(d.Enabled) end end
  t.expect.equal(FX.live(m),0)
  FX.setEnabled(m,true);t.expect.near(FX.live(m),before,1e-3)
  m:Destroy()
 end)
end
