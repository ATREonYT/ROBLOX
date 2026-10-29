-- gun_stand_same_pads.luau: paints the first pad of an exported gun stand (green, the equipped gun) like the second
-- (pink, locked), so all ten look the same, and writes the parts as JSON for gun_pedestal_glb.py.
-- Usage: lune run hood/tools/blender/gun_stand_same_pads.luau <in.rbxm> <out.rbxm> <parts.json>
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local model = roblox.deserializeModel(fs.readFile(process.args[1]))[1]
local slots = {}
for _, d in model:GetDescendants() do
	if d:IsA("Model") and d.Name:match("^GunSlot_") then table.insert(slots, d) end
end
table.sort(slots, function(a, b) return (a:GetAttribute("Cost") or 0) < (b:GetAttribute("Cost") or 0) end)
local first, second = slots[1], slots[2]
local function list(slot)
	local out = {}
	for _, d in slot:GetDescendants() do
		local key = d.ClassName .. ":" .. d.Name
		out[key] = out[key] or {}
		table.insert(out[key], d)
	end
	return out
end
local from, to = list(second), list(first)
for key, items in to do
	for i, d in items do
		local s = from[key] and from[key][i]
		if s then
			if d:IsA("BasePart") then d.Color = s.Color; d.Material = s.Material end
			if d:IsA("PointLight") then d.Color = s.Color end
			if d:IsA("TextLabel") then d.Text = s.Text; d.TextColor3 = s.TextColor3 end
			if d:IsA("UIStroke") then d.Color = s.Color end
			if d:IsA("ParticleEmitter") then d.Color = s.Color end
		end
	end
end
fs.writeFile(process.args[2], roblox.serializeModel({ model }))
local rows = {}
for _, p in model:GetDescendants() do
	if p:IsA("BasePart") then
		local cf = p.CFrame
		local rx, ry, rz = cf:ToEulerAnglesXYZ()
		local cyl = p:IsA("Part") and p.Shape == roblox.Enum.PartType.Cylinder
		table.insert(rows, { name = p.Name, pos = { cf.Position.X, cf.Position.Y, cf.Position.Z }, rot = { rx, ry, rz },
			size = { p.Size.X, p.Size.Y, p.Size.Z }, color = { p.Color.R, p.Color.G, p.Color.B },
			neon = p.Material == roblox.Enum.Material.Neon, cyl = cyl })
	end
end
fs.writeFile(process.args[3], serde.encode("json", rows))
print(first.Name, "painted like", second.Name, #rows, "parts")
