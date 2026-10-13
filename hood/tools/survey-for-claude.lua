local ss=game:GetService("ServerStorage")
local old=ss:FindFirstChild("ClaudeExport") if old then old:Destroy() end
local r=workspace:FindFirstChild("TheBlock")
local yv=r and r:FindFirstChild("MapYawValue")
local yaw=r and (r:GetAttribute("MapYaw") or (yv and yv.Value)) or 0
local f=CFrame.Angles(0,yaw,0)
local function q(v) return tostring(math.floor(v*100+0.5)/100) end
local function rel(o) return (o:GetFullName():gsub("^Workspace%.TheBlock%.","")) end
local function aabb(cf,s)
 local x,y,z,a,b,c,d,e,g,h,i,j=cf:GetComponents()
 local hx=(math.abs(a)*s.X+math.abs(b)*s.Y+math.abs(c)*s.Z)/2
 local hy=(math.abs(d)*s.X+math.abs(e)*s.Y+math.abs(g)*s.Z)/2
 local hz=(math.abs(h)*s.X+math.abs(i)*s.Y+math.abs(j)*s.Z)/2
 return x-hx,y-hy,z-hz,x+hx,y+hy,z+hz
end
local function boundsOf(o)
 local n,a1,a2,a3,b1,b2,b3=0,math.huge,math.huge,math.huge,-math.huge,-math.huge,-math.huge
 local list=o:GetDescendants()
 if o:IsA("BasePart") then table.insert(list,o) end
 for _,p in ipairs(list) do
  if p:IsA("BasePart") then
   n=n+1
   local x1,y1,z1,x2,y2,z2=aabb(f:ToObjectSpace(p.CFrame),p.Size)
   a1=math.min(a1,x1) a2=math.min(a2,y1) a3=math.min(a3,z1) b1=math.max(b1,x2) b2=math.max(b2,y2) b3=math.max(b3,z2)
  end
 end
 if n==0 then return "n=0" end
 return "n="..n.." min="..q(a1)..","..q(a2)..","..q(a3).." max="..q(b1)..","..q(b2)..","..q(b3)
end
local lines={"HOOD SURVEY yaw="..q(yaw)}
for _,c in ipairs(workspace:GetChildren()) do
 if not c:IsA("Terrain") and not c:IsA("Camera") then table.insert(lines,"W "..c.Name.." "..c.ClassName.." "..boundsOf(c)) end
end
if r then
 local function skip(o)
  local a=o.Parent
  while a and a~=r do
   if a.Name:sub(-7)=="Display" or a.Name=="StudDetails" then return true end
   a=a.Parent
  end
  return false
 end
 local function depth(o) local d=0 local a=o while a and a~=r do d=d+1 a=a.Parent end return d end
 local parts,texts={},{}
 for _,o in ipairs(r:GetDescendants()) do
  if (o:IsA("Model") or o:IsA("Folder")) and not skip(o) and depth(o)<=6 then
   table.insert(lines,"M "..rel(o).." "..o.ClassName.." "..boundsOf(o))
  elseif o:IsA("BasePart") and o.Name~="Stud" and not skip(o) then
   local cf=f:ToObjectSpace(o.CFrame)
   local p=cf.Position
   if p.X>-115 and p.X<115 and p.Z>0 and p.Z<145 and p.Y<70 and #parts<2500 then
    local rx,ry,rz=cf:ToOrientation()
    local sh=""
    if o:IsA("Part") then sh=":"..o.Shape.Name end
    local mesh=o:FindFirstChildOfClass("SpecialMesh")
    if mesh then sh=sh.."+"..mesh.MeshType.Name end
    table.insert(parts,"P "..rel(o).." "..o.ClassName..sh.." s="..q(o.Size.X)..","..q(o.Size.Y)..","..q(o.Size.Z).." p="..q(p.X)..","..q(p.Y)..","..q(p.Z).." r="..q(math.deg(rx))..","..q(math.deg(ry))..","..q(math.deg(rz)).." c="..math.floor(o.Color.R*255+0.5)..","..math.floor(o.Color.G*255+0.5)..","..math.floor(o.Color.B*255+0.5).." m="..o.Material.Name.." t="..q(o.Transparency).." cc="..(o.CanCollide and 1 or 0))
   end
  elseif o:IsA("TextLabel") and not skip(o) and #texts<400 then
   table.insert(texts,"T "..rel(o).." "..o.Text:gsub("\n"," / "))
  end
 end
 for _,l in ipairs(parts) do table.insert(lines,l) end
 for _,l in ipairs(texts) do table.insert(lines,l) end
end
local text=table.concat(lines,"\n")
local eq="==" while text:find("]"..eq.."]",1,true) do eq=eq.."=" end
local folder=Instance.new("Folder") folder.Name="ClaudeExport" folder.Parent=ss
local count=0
for i=1,#text,150000 do
 count=count+1
 local body="--["..eq.."[\n"..text:sub(i,i+149999).."\n]"..eq.."]"
 local m=Instance.new("ModuleScript") m.Name="Part"..count
 local ok=pcall(function() m.Source=body end)
 m.Parent=folder
 if not ok then pcall(function() game:GetService("ScriptEditorService"):UpdateSourceAsync(m,function() return body end) end) end
end
game:GetService("Selection"):Set({folder})
print("Claude survey done: "..#lines.." lines in "..count.." part(s) at ServerStorage > ClaudeExport")
