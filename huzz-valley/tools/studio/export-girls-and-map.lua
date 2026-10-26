-- Paste into Studio's Command Bar and press Enter. It writes a text report of
-- your girls, map and scripts to ServerStorage > ClaudeExport (Part1, Part2...).
-- Open each Part, copy all, paste into the chat. Delete ClaudeExport afterwards.
local ss = game:GetService("ServerStorage")
local old = ss:FindFirstChild("ClaudeExport") if old then old:Destroy() end
local lines = {}
local function add(s) table.insert(lines, s) end
local function v3(v) return string.format("%.1f,%.1f,%.1f", v.X, v.Y, v.Z) end
local function describe(m)
 local parts, motors, meshes = 0, 0, 0
 for _, d in ipairs(m:GetDescendants()) do
  if d:IsA("BasePart") then parts = parts + 1 end
  if d:IsA("Motor6D") then motors = motors + 1 end
  if d:IsA("MeshPart") or d:IsA("SpecialMesh") then meshes = meshes + 1 end
 end
 local h = m:FindFirstChildOfClass("Humanoid")
 local rig = m:FindFirstChild("UpperTorso") and "R15" or (m:FindFirstChild("Torso") and "R6" or "none")
 local ok, size = pcall(function() return m:GetExtentsSize() end)
 return string.format("parts=%d motors=%d meshes=%d humanoid=%s rig=%s size=%s rarityAttr=%s primary=%s",
  parts, motors, meshes, tostring(h ~= nil), rig, ok and v3(size) or "?", tostring(m:GetAttribute("Rarity")), m.PrimaryPart and m.PrimaryPart.Name or "nil")
end
add("== GIRL CANDIDATES (models with a Humanoid or in a folder named like girls)")
for _, svc in ipairs({ workspace, game:GetService("ReplicatedStorage"), ss }) do
 for _, d in ipairs(svc:GetDescendants()) do
  if d:IsA("Model") and (d:FindFirstChildOfClass("Humanoid") or (d.Parent and d.Parent.Name:lower():find("girl"))) and not game:GetService("Players"):GetPlayerFromCharacter(d) then
   add(d:GetFullName() .. " | " .. describe(d))
  end
 end
end
add("\n== WORKSPACE TREE (folders/models, 3 levels)")
local function tree(inst, depth)
 if depth > 3 then return end
 for _, c in ipairs(inst:GetChildren()) do
  if c:IsA("Folder") or c:IsA("Model") or (c:IsA("BasePart") and depth <= 2) then
   local extra = c:IsA("BasePart") and (" size=" .. v3(c.Size) .. " pos=" .. v3(c.Position)) or (" children=" .. #c:GetChildren())
   add(string.rep("  ", depth) .. c.Name .. " (" .. c.ClassName .. ")" .. extra)
   if not c:IsA("BasePart") then tree(c, depth + 1) end
  end
 end
end
tree(workspace, 0)
add("\n== TAGS")
for _, tag in ipairs(game:GetService("CollectionService"):GetAllTags()) do add(tag) end
add("\n== SCRIPTS")
for _, svc in ipairs({ game:GetService("ServerScriptService"), game:GetService("ReplicatedStorage"), game:GetService("StarterPlayer"), game:GetService("StarterGui"), ss, workspace }) do
 for _, d in ipairs(svc:GetDescendants()) do
  if d:IsA("LuaSourceContainer") then
   local ok, src = pcall(function() return d.Source end)
   add("\n----- " .. d:GetFullName() .. " (" .. d.ClassName .. ")\n" .. (ok and src or "[unreadable]"))
  end
 end
end
local text = table.concat(lines, "\n")
local eq = "==" while text:find("]" .. eq .. "]", 1, true) do eq = eq .. "=" end
local folder = Instance.new("Folder") folder.Name = "ClaudeExport" folder.Parent = ss
local n = 0
for i = 1, #text, 150000 do
 n = n + 1
 local body = "--[" .. eq .. "[\n" .. text:sub(i, i + 149999) .. "\n]" .. eq .. "]"
 local m = Instance.new("ModuleScript") m.Name = "Part" .. n
 if not pcall(function() m.Source = body end) then
  pcall(function() game:GetService("ScriptEditorService"):UpdateSourceAsync(m, function() return body end) end)
 end
 m.Parent = folder
end
game:GetService("Selection"):Set({ folder })
print("Claude export done: " .. n .. " part(s) in ServerStorage > ClaudeExport")
