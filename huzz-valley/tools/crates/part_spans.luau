-- Where each named group of one of the owner's crates sits, up and down and front to back (in the crate's middle's
-- frame): bottom, top, front and back of every part with that base name. To see which parts sit inside the body
-- (crystals in a chest) and which ride on the lid. lune run huzz-valley/tools/crates/part_spans.luau <set> [place.rbxl]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3

local game = roblox.deserializePlace(fs.readFile(process.args[2] or "huzz-valley/places/HUSSANIME.rbxl"))
local set = game:GetService("Workspace").scrates.Standard_Crates:FindFirstChild(process.args[1] or "storm_set")
local crate, most = nil, 0 -- (his crate: the model with the most parts; the rest are his little knives)
for _, m in set:GetChildren() do
	local n = 0
	for _, d in m:GetDescendants() do if d:IsA("BasePart") then n += 1 end end
	if m:IsA("Model") and n > most then crate, most = m, n end
end
local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
for _, d in crate:GetDescendants() do
	if d:IsA("BasePart") then
		local p, h = d.CFrame.Position, d.Size / 2
		lo = Vector3.new(math.min(lo.X, p.X - h.X), math.min(lo.Y, p.Y - h.Y), math.min(lo.Z, p.Z - h.Z))
		hi = Vector3.new(math.max(hi.X, p.X + h.X), math.max(hi.Y, p.Y + h.Y), math.max(hi.Z, p.Z + h.Z))
	end
end
local mid = (lo + hi) / 2
local groups, order = {}, {}
for _, d in crate:GetDescendants() do
	if d:IsA("BasePart") then
		local base = string.gsub(string.gsub(d.Name, "_Node$", ""), "_%d+$", "")
		local p, h = d.CFrame.Position - mid, d.Size / 2
		local g = groups[base]
		if not g then g = { n = 0, y0 = math.huge, y1 = -math.huge, z0 = math.huge, z1 = -math.huge }; groups[base] = g; table.insert(order, base) end
		g.n += 1
		g.y0, g.y1 = math.min(g.y0, p.Y - h.Y), math.max(g.y1, p.Y + h.Y)
		g.z0, g.z1 = math.min(g.z0, p.Z - h.Z), math.max(g.z1, p.Z + h.Z)
	end
end
table.sort(order, function(a, b) return groups[a].y0 < groups[b].y0 end)
for _, k in order do
	local g = groups[k]
	print(string.format("%-22s x%-3d y %6.2f .. %6.2f   z %6.2f .. %6.2f", k, g.n, g.y0, g.y1, g.z0, g.z1))
end
