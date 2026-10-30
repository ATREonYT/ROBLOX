-- What changed between two of the owner's place files (Oct 20: he sent a new place "with updated crates"): every
-- instance by its path (same-named siblings numbered), the ones only in the new place, only in the old one, and the
-- ones whose look or script changed (parts: size, place, colour, material, transparency; meshes: MeshId, TextureID;
-- scripts: Source; anything: its attributes). Prints a summary per top-level folder, then the details.
-- lune run huzz-valley/tools/place/diff_places.luau <old.rbxl> <new.rbxl> [depth]     (from the repo root)
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local oldFile, newFile = process.args[1], process.args[2]
local depth = tonumber(process.args[3] or "3") or 3
assert(oldFile and newFile, "usage: diff_places.luau <old.rbxl> <new.rbxl> [depth]")

local SERVICES = { "Workspace", "ServerStorage", "ReplicatedStorage", "ServerScriptService", "StarterGui", "StarterPack",
	"StarterPlayer", "Lighting", "SoundService", "Teams", "MaterialService", "ReplicatedFirst" }

local function r3(v) return string.format("%.2f,%.2f,%.2f", v.X, v.Y, v.Z) end

-- one line that changes when the instance's look or code changes
local function sig(i)
	local bits = { i.ClassName }
	local function add(k)
		local ok, v = pcall(function() return i[k] end)
		if ok and v ~= nil then
			local t = typeof(v)
			if t == "Vector3" then v = r3(v)
			elseif t == "CFrame" then v = r3(v.Position) .. "/" .. r3(v.LookVector) .. "/" .. r3(v.UpVector)
			elseif t == "Color3" then v = string.format("%d,%d,%d", math.round(v.R * 255), math.round(v.G * 255), math.round(v.B * 255))
			elseif t == "number" then v = string.format("%.3f", v)
			end
			table.insert(bits, k .. "=" .. tostring(v))
		end
	end
	if i:IsA("BasePart") then
		for _, k in { "Size", "CFrame", "Color", "Material", "Transparency" } do add(k) end
	end
	if i:IsA("MeshPart") then add("MeshId"); add("MeshContent"); add("TextureID"); add("TextureContent") end
	if i.ClassName == "SpecialMesh" or i.ClassName == "Decal" or i.ClassName == "Texture" then add("MeshId"); add("TextureId"); add("Texture") end
	if i:IsA("LuaSourceContainer") then
		local ok, src = pcall(function() return i.Source end)
		if ok then table.insert(bits, "src#" .. #src .. ":" .. string.sub(src, 1, 40):gsub("%s+", " ")) end
	end
	local ok, attrs = pcall(function() return i:GetAttributes() end)
	if ok then
		local keys = {}
		for k in attrs do table.insert(keys, k) end
		table.sort(keys)
		for _, k in keys do table.insert(bits, "@" .. k .. "=" .. tostring(attrs[k])) end
	end
	return table.concat(bits, " ")
end

local function index(game)
	local out, order = {}, {}
	local function walk(inst, path)
		local seen = {}
		for _, c in inst:GetChildren() do
			local n = (seen[c.Name] or 0) + 1
			seen[c.Name] = n
			local p = path .. "/" .. c.Name .. (n > 1 and ("#" .. n) or "")
			out[p] = { inst = c, sig = sig(c) }
			table.insert(order, p)
			walk(c, p)
		end
	end
	for _, s in SERVICES do
		local ok, svc = pcall(function() return game:GetService(s) end)
		if ok and svc then walk(svc, s) end
	end
	return out, order
end

local old = index(roblox.deserializePlace(fs.readFile(oldFile)))
local new, newOrder = index(roblox.deserializePlace(fs.readFile(newFile)))
local _, oldOrder = index(roblox.deserializePlace(fs.readFile(oldFile)))

local function top(p)
	local parts = string.split(p, "/")
	local t = {}
	for i = 1, math.min(depth, #parts) do t[i] = parts[i] end
	return table.concat(t, "/")
end

local summary, tops = {}, {}
local function bump(p, k)
	local t = top(p)
	if not summary[t] then summary[t] = { added = 0, removed = 0, changed = 0 }; table.insert(tops, t) end
	summary[t][k] += 1
end
local added, removed, changed = {}, {}, {}
for _, p in newOrder do
	if not old[p] then table.insert(added, p); bump(p, "added")
	elseif old[p].sig ~= new[p].sig then table.insert(changed, p); bump(p, "changed") end
end
for _, p in oldOrder do
	if not new[p] then table.insert(removed, p); bump(p, "removed") end
end
table.sort(tops)
print(string.format("== %d added, %d removed, %d changed (by folder, depth %d)", #added, #removed, #changed, depth))
for _, t in tops do
	local s = summary[t]
	print(string.format("  %-70s +%d -%d ~%d", t, s.added, s.removed, s.changed))
end

-- details: the top of each added / removed subtree (not every child), and every changed instance
local function roots(list, set)
	local out = {}
	for _, p in list do
		local parent = string.match(p, "^(.*)/[^/]+$")
		if not (parent and set[parent] and table.find(list, parent)) then table.insert(out, p) end
	end
	return out
end
local function count(set, p)
	local n = 0
	for q in set do if string.sub(q, 1, #p + 1) == p .. "/" then n += 1 end end
	return n
end
print("== added (subtree roots)")
for _, p in roots(added, new) do print("  + " .. p .. "  [" .. new[p].inst.ClassName .. ", " .. count(new, p) .. " inside]") end
print("== removed (subtree roots)")
for _, p in roots(removed, old) do print("  - " .. p .. "  [" .. old[p].inst.ClassName .. ", " .. count(old, p) .. " inside]") end
if process.env.CHANGED == "1" then
	print("== changed")
	for _, p in changed do
		print("  ~ " .. p)
		print("      old " .. old[p].sig)
		print("      new " .. new[p].sig)
	end
end
