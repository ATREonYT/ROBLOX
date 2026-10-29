-- Dumps one lobby in 3D (every visible part's CFrame, size, colour, material, shape, and every light) to JSON for
-- tools/preview/light/render_light.mjs, which lights it with a model of Roblox's lighting to compare Config/Look
-- settings (owner Oct 19: "even, nice, cartoony lighting over the map").
-- Run from the repo root:
--   lune run huzz-valley/tools/world/scene_dump.luau <place.rbxl> <out.json> [centreX centreZ radius]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local placeFile, outFile = process.args[1], process.args[2]
local game = roblox.deserializePlace(fs.readFile(placeFile))
local ws = game:GetService("Workspace")
local cx, cz, radius = tonumber(process.args[3]) or -131, tonumber(process.args[4]) or 49, tonumber(process.args[5]) or 170

local function near(p)
	return math.abs(p.X - cx) <= radius and math.abs(p.Z - cz) <= radius and p.Y > -60 and p.Y < 200
end
local function r(x) return math.floor(x * 1000 + 0.5) / 1000 end

local parts, lights = {}, {}
for _, d in ws:GetDescendants() do
	if d:IsA("BasePart") and not d:IsA("Terrain") then
		local cf, s = d.CFrame, d.Size
		if near(cf.Position) and d.Transparency < 0.95 then
			local shape = "Block"
			if d:IsA("Part") then shape = tostring(d.Shape):match("%.(%w+)$") or "Block" end
			if d:IsA("WedgePart") then shape = "Wedge" end
			if d:IsA("CornerWedgePart") then shape = "CornerWedge" end
			if d:IsA("MeshPart") then shape = "Mesh" end
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
			local c = d.Color
			table.insert(parts, {
				p = { r(x), r(y), r(z) }, rot = { r(r00), r(r01), r(r02), r(r10), r(r11), r(r12), r(r20), r(r21), r(r22) },
				s = { r(s.X), r(s.Y), r(s.Z) }, c = { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) },
				m = tostring(d.Material):match("%.(%w+)$"), shape = shape, t = r(d.Transparency),
			})
		end
	elseif d:IsA("Light") and d.Enabled then
		local at = d.Parent
		local pos
		if at and at:IsA("Attachment") and at.Parent and at.Parent:IsA("BasePart") then
			pos = (at.Parent.CFrame * at.CFrame).Position -- (Lune has no WorldCFrame)
		elseif at and at:IsA("BasePart") then pos = at.CFrame.Position end
		if pos and near(pos) then
			local c = d.Color
			table.insert(lights, {
				kind = d.ClassName, p = { r(pos.X), r(pos.Y), r(pos.Z) }, c = { c.R, c.G, c.B }, b = d.Brightness,
				range = (pcall(function() return d.Range end)) and d.Range or 0, shadows = d.Shadows,
				owner = (function()
					local top = d
					while top.Parent and top.Parent ~= ws and top.Parent ~= game do top = top.Parent end
					return top.Name
				end)(),
			})
		end
	end
end
fs.writeFile(outFile, serde.encode("json", { centre = { cx, cz }, parts = parts, lights = lights }))
print(string.format("scene dump: %d parts, %d lights round (%d, %d) -> %s", #parts, #lights, cx, cz, outFile))
