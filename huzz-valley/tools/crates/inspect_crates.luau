-- The owner's crate models in a place file (Oct 20: "here is the new one with updated crates, make these crates for
-- the opening of the normal knifes"): Workspace > scrates > Standard_Crates > <set> > <crate model>, each a .glb import
-- (one MeshPart per node, in a "<name>_<n>_Node" Model). Prints each set's models with their box and parts, the node
-- names grouped (digits dropped), and every mesh / texture id, so we know what moves when it opens.
-- lune run huzz-valley/tools/crates/inspect_crates.luau [place.rbxl]     (from the repo root)
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local file = process.args[1] or "huzz-valley/places/HUSSANIME.rbxl"
local game = roblox.deserializePlace(fs.readFile(file))
local root = game:GetService("Workspace"):FindFirstChild("scrates")
root = root and root:FindFirstChild("Standard_Crates")
assert(root, "no Workspace > scrates > Standard_Crates in " .. file)

local function box(m)
	local x0, y0, z0, x1, y1, z1, n = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge, 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local p, s = d.CFrame.Position, d.Size
			n += 1
			x0, y0, z0 = math.min(x0, p.X - s.X / 2), math.min(y0, p.Y - s.Y / 2), math.min(z0, p.Z - s.Z / 2)
			x1, y1, z1 = math.max(x1, p.X + s.X / 2), math.max(y1, p.Y + s.Y / 2), math.max(z1, p.Z + s.Z / 2)
		end
	end
	return string.format("%d parts, centre (%.2f, %.2f, %.2f), size (%.2f x %.2f x %.2f), bottom %.2f", n, (x0 + x1) / 2,
		(y0 + y1) / 2, (z0 + z1) / 2, x1 - x0, y1 - y0, z1 - z0, y0)
end

local function content(p, k)
	local ok, v = pcall(function() return p[k] end)
	if not ok or v == nil then return nil end
	local s = tostring(v)
	return string.match(s, "rbxassetid://(%d+)") or (s ~= "" and s ~= "Content(None)" and s or nil)
end

local ids = {}
for _, set in root:GetChildren() do
	print(string.format("%s: %s", set.Name, box(set)))
	for _, m in set:GetChildren() do
		print(string.format("  %s %s: %s", m.ClassName, m.Name, box(m)))
		local groups, order = {}, {}
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				local base = string.gsub(string.gsub(d.Name, "_Node$", ""), "_%d+$", "")
				if not groups[base] then groups[base] = 0; table.insert(order, base) end
				groups[base] += 1
				local sa = d:FindFirstChildOfClass("SurfaceAppearance")
				for _, k in { "MeshId", "MeshContent" } do
					local id = content(d, k)
					if id then ids[id] = ids[id] or {}; ids[id][set.Name .. "/" .. m.Name] = true end
				end
				for _, k in { "TextureID", "TextureContent" } do
					local id = content(d, k)
					if id then ids[id] = ids[id] or {}; ids[id][set.Name .. "/" .. m.Name] = true end
				end
				if sa then
					for _, k in { "ColorMap", "ColorMapContent", "NormalMap", "RoughnessMap", "MetalnessMap" } do
						local id = content(sa, k)
						if id then ids[id] = ids[id] or {}; ids[id][set.Name .. "/" .. m.Name] = true end
					end
				end
			end
		end
		local bits = {}
		for _, b in order do table.insert(bits, b .. (groups[b] > 1 and ("x" .. groups[b]) or "")) end
		print("    " .. table.concat(bits, ", "))
	end
end
if process.env.IDS == "1" then
	local list = {}
	for id, users in ids do
		local u = {}
		for k in users do table.insert(u, k) end
		table.sort(u)
		table.insert(list, id .. " " .. table.concat(u, " "))
	end
	table.sort(list)
	print("ids: " .. #list)
	for _, l in list do print("  " .. l) end
end
