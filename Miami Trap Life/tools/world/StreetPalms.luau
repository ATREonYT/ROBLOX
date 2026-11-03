-- Street palms for the hood (Quality pass, LihFolk Build List item 13). Edit-time, run once; re-run replaces.
-- Clones the map's own script-free Palm (Hood.GasStation.Palm: 4 MeshParts + SurfaceAppearance) along every hood
-- sidewalk about every 42 studs, skipping spots near an existing tree, blocked at trunk height (doors, poles,
-- furniture) or with something solid in the canopy. Each gets an invisible trunk collider so you can't walk through.
-- Output: workspace.MTL_WorldDetail.StreetPalms
local MIN,MAX=Vector3.new(-1720,-10,-960),Vector3.new(-980,40,-60)
local template=workspace.ViceBay.Landmarks.Hood.GasStation:FindFirstChild("Palm")
local root=workspace:FindFirstChild("MTL_WorldDetail") or Instance.new("Folder") root.Name="MTL_WorldDetail" root.Parent=workspace
local old=root:FindFirstChild("StreetPalms") if old then old:Destroy() end
local out=Instance.new("Folder") out.Name="StreetPalms" out.Parent=root
local rp=RaycastParams.new() rp.FilterType=Enum.RaycastFilterType.Exclude rp.FilterDescendantsInstances={out}
local placed,skipped=0,0
local trees={}
for _,d in workspace.ViceBay:GetDescendants() do if d:IsA("Model") and (d.Name=="Palm" or d.Name=="Oak Tree" or d.Name=="Plam Tree") then table.insert(trees,d:GetPivot().Position) end end
local function farFromTrees(p) for _,t in trees do if (Vector3.new(t.X,0,t.Z)-Vector3.new(p.X,0,p.Z)).Magnitude<18 then return false end end return true end
for _,street in workspace.ViceBay.Roads:GetChildren() do
 for _,sw in street:GetChildren() do
  if sw:IsA("BasePart") and sw.Name=="Sidewalk" then
   local pp=sw.Position
   if pp.X>MIN.X and pp.X<MAX.X and pp.Z>MIN.Z and pp.Z<MAX.Z then
    local alongX=sw.Size.X>sw.Size.Z
    local len=math.max(sw.Size.X,sw.Size.Z)
    local rng=Random.new(math.floor(pp.X*3+pp.Z*5))
    for i=0,math.floor(len/42) do
     local t=-len/2+21+i*42+rng:NextNumber(-4,4)
     if math.abs(t)<len/2-6 then
      local lp=sw.CFrame*CFrame.new(alongX and t or 0,0,alongX and 0 or t)
      local base=Vector3.new(lp.X,sw.Position.Y+sw.Size.Y/2,lp.Z)
      local ok=farFromTrees(base)
      if ok then local h=workspace:Raycast(base+Vector3.new(0,20,0),Vector3.new(0,-30,0),rp) ok=h~=nil and h.Instance==sw end
      if ok then
       local op=OverlapParams.new() op.FilterType=Enum.RaycastFilterType.Exclude op.FilterDescendantsInstances={sw,out}
       for _,x in workspace:GetPartBoundsInBox(CFrame.new(base+Vector3.new(0,7.5,0)),Vector3.new(3.5,14,3.5),op) do if x.Transparency<1 then ok=false break end end
       if ok then for _,x in workspace:GetPartBoundsInBox(CFrame.new(base+Vector3.new(0,30,0)),Vector3.new(12,14,12),op) do local s=x.Size if math.min(s.X,s.Y,s.Z)>0.6 and x.Transparency<1 then ok=false break end end end
      end
      if ok then
       local m=template:Clone() m.Name="Palm"
       m:PivotTo(CFrame.new(base)*CFrame.Angles(0,rng:NextNumber(0,math.pi*2),0)*CFrame.Angles(math.rad(rng:NextNumber(-3,3)),0,math.rad(rng:NextNumber(-3,3))))
       m:ScaleTo(rng:NextNumber(0.8,1.1))
       local c=Instance.new("Part") c.Name="TrunkCollider" c.Shape=Enum.PartType.Cylinder c.Size=Vector3.new(12,1.6,1.6)
       c.CFrame=CFrame.new(base+Vector3.new(0,6,0))*CFrame.Angles(0,0,math.rad(90)) c.Transparency=1 c.Anchored=true c.CanTouch=false c.Parent=m
       m.Parent=out table.insert(trees,base) placed+=1
      else skipped+=1 end
     end
    end
   end
  end
 end
 task.wait()
end
return placed.." palms, "..skipped.." spots skipped"
