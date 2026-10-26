-- lune run huzz-valley/tools/world/measure_halloween_lobby.luau [place.rbxl]   (from the repo root)
-- Prints where the owner's Halloween lobby pieces really are (his place, places/HUSSANIME.rbxl by default), so the
-- layout plan (tools/world/halloween_layout.py -> docs/previews/halloween-lobby-layout.png) uses real positions.
-- Prints each piece's box as x0,z0,x1,z1 and its bottom/top height. Lune can't read .Position on loaded parts, so
-- everything goes through .CFrame.Position.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local place = roblox.deserializePlace(fs.readFile(process.args[1] or "huzz-valley/places/HUSSANIME.rbxl"))
local ws = place:GetService("Workspace")

local function box(inst)
	local lo, hi
	local list = if inst:IsA("BasePart") then { inst } else inst:GetDescendants()
	for _, d in list do
		if d:IsA("BasePart") then
			local cf, h = d.CFrame, d.Size / 2
			local e = roblox.Vector3.new(
				math.abs(cf.RightVector.X) * h.X + math.abs(cf.UpVector.X) * h.Y + math.abs(cf.LookVector.X) * h.Z,
				math.abs(cf.RightVector.Y) * h.X + math.abs(cf.UpVector.Y) * h.Y + math.abs(cf.LookVector.Y) * h.Z,
				math.abs(cf.RightVector.Z) * h.X + math.abs(cf.UpVector.Z) * h.Y + math.abs(cf.LookVector.Z) * h.Z)
			local p = cf.Position
			lo = if lo then lo:Min(p - e) else p - e
			hi = if hi then hi:Max(p + e) else p + e
		end
	end
	return lo, hi
end
local function show(label, inst)
	local lo, hi = box(inst)
	if lo then
		print(string.format("%-34s x %.1f..%.1f  z %.1f..%.1f  y %.1f..%.1f", label, lo.X, hi.X, lo.Z, hi.Z, lo.Y, hi.Y))
	end
end

-- The Halloween lobby floor: the SpawnBaseplate nearest the Halloween map.
local maps = ws:FindFirstChild("Maps")
local hmap = maps and maps:FindFirstChild("Halloween_Map")
assert(hmap, "no Workspace.Maps.Halloween_Map")
local mlo, mhi = box(hmap)
local mid = (mlo + mhi) / 2
local floor, best = nil, math.huge
for _, d in ws:GetDescendants() do
	if d:IsA("BasePart") and d.Name == "SpawnBaseplate" then
		local p = d.CFrame.Position
		local dist = ((p - mid) * roblox.Vector3.new(1, 0, 1)).Magnitude
		if dist < best then floor, best = d, dist end
	end
end
assert(floor, "no SpawnBaseplate")
show("Halloween_Map (whole)", hmap)
for _, c in hmap:GetDescendants() do
	if c:IsA("BasePart") and (c.Name == "GrassBaseplate" or c.Name:lower():gsub("[%s_%-]", "") == "middle") then show("  map " .. c.Name, c) end
end
show("SpawnBaseplate (lobby floor)", floor)
local flo, fhi = box(floor)
local function near(inst)
	local lo, hi = box(inst)
	return lo and hi.X > flo.X - 15 and lo.X < fhi.X + 15 and hi.Z > flo.Z - 15 and lo.Z < fhi.Z + 15
end
for _, d in ws:GetDescendants() do
	local n = string.lower(d.Name):gsub("[%s_%-]", "")
	if (d:IsA("Model") or d:IsA("BasePart")) and n:find("spin") and n:find("wheel") and not (d.Parent and string.lower(d.Parent.Name):find("wheel")) and near(d) then
		show("SpinWheel (script finds it)", d)
	elseif d:IsA("SpawnLocation") and near(d) then
		show("SpawnLocation (script uses it)", d)
	end
end
for _, s in floor.Parent:GetChildren() do
	if s ~= floor and not s:IsA("SpawnLocation") and near(s) then show("his: " .. s.Name, s) end
end
-- His loose plank path (Workspace parts named Part): centres, for the plan's path line.
local pts = {}
for _, d in ws:GetChildren() do
	if d:IsA("BasePart") and d.Name == "Part" then
		local p = d.CFrame.Position
		table.insert(pts, string.format("(%.1f, %.1f)", p.X, p.Z))
	end
end
print("plank path centres: " .. table.concat(pts, ", "))
