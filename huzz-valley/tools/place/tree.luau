-- Prints one part of a place file as a tree (class, name, size, centre, mesh ids, attributes), to look at what the
-- owner built (Oct 20: his crates in Workspace > scrates > Standard_Crates).
-- lune run huzz-valley/tools/place/tree.luau <place.rbxl> <Service/Path/To/Thing> [depth]     (from the repo root)
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local file, path = process.args[1], process.args[2]
local depth = tonumber(process.args[3] or "2") or 2
local game = roblox.deserializePlace(fs.readFile(file))
local parts = string.split(path, "/")
local inst = game:GetService(parts[1])
for i = 2, #parts do
	inst = inst:FindFirstChild(parts[i])
	assert(inst, "no " .. parts[i])
end

local function box(m)
	local lo, hi = Vector3 and nil, nil
	local x0, y0, z0, x1, y1, z1 = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
	local n = 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local p, s = d.CFrame.Position, d.Size
			n += 1
			x0, y0, z0 = math.min(x0, p.X - s.X / 2), math.min(y0, p.Y - s.Y / 2), math.min(z0, p.Z - s.Z / 2)
			x1, y1, z1 = math.max(x1, p.X + s.X / 2), math.max(y1, p.Y + s.Y / 2), math.max(z1, p.Z + s.Z / 2)
		end
	end
	if n == 0 then return "" end
	return string.format(" parts %d centre (%.1f, %.1f, %.1f) size (%.1f, %.1f, %.1f)", n, (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, x1 - x0, y1 - y0, z1 - z0)
end

local function line(i, indent)
	local extra = ""
	if i:IsA("BasePart") then
		local p, s = i.CFrame.Position, i.Size
		extra = string.format(" size (%.2f, %.2f, %.2f) at (%.1f, %.1f, %.1f) %s", s.X, s.Y, s.Z, p.X, p.Y, p.Z, tostring(i.Material):gsub("Enum.Material.", ""))
		if i:IsA("MeshPart") then
			for _, k in { "MeshId", "MeshContent", "TextureID", "TextureContent" } do
				local okK, v = pcall(function() return i[k] end)
				if okK and v ~= nil and tostring(v) ~= "" then extra ..= " " .. k .. " " .. tostring(v) end
			end
		end
	elseif i:IsA("Model") or i:IsA("Folder") then
		extra = box(i)
	end
	local ok, attrs = pcall(function() return i:GetAttributes() end)
	if ok then
		for k, v in attrs do extra ..= " @" .. k .. "=" .. tostring(v) end
	end
	print(string.rep("  ", indent) .. i.ClassName .. " " .. i.Name .. extra)
end

local function walk(i, d)
	line(i, d)
	if d >= depth then
		if #i:GetChildren() > 0 then print(string.rep("  ", d + 1) .. "... " .. #i:GetDescendants() .. " inside") end
		return
	end
	for _, c in i:GetChildren() do walk(c, d + 1) end
end
walk(inst, 0)
