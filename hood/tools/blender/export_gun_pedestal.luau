-- export_gun_pedestal.luau: one gun-shop pad (no gun, no labels) from the built place as hood/art/models/pedestal/GunPedestal.rbxm,
-- plus its parts as JSON for gun_pedestal_glb.py. Usage: lune run hood/tools/blender/export_gun_pedestal.luau <parts.json>
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local Instance, CFrame, Vector3 = roblox.Instance, roblox.CFrame, roblox.Vector3
local game = roblox.deserializePlace(fs.readFile("hood/places/HoodEvolution.rbxl"))
local slot
for _, d in game.Workspace:GetDescendants() do
	if d.Name == "GunSlot_Pistol" then slot = d break end
end
local KEEP = { StateMat = true, MatRim = true, PadPlinth = true, PadBase = true, StateTop = true, PadLip = true,
	StateShade = true, StateGlow = true, StateStrip = true, PlateCap = true, PlateBolt = true }
local model = Instance.new("Model")
model.Name = "GunPedestal"
-- centre: the mat's middle on the floor
local mat = slot:FindFirstChild("StateMat")
local mp = mat.CFrame.Position
local origin = CFrame.new(mp.X, mp.Y - mat.Size.Y / 2, mp.Z)
local rows = {}
for _, p in slot:GetChildren() do
	if p:IsA("BasePart") and KEEP[p.Name] then
		local c = p:Clone()
		for _, d in c:GetDescendants() do
			if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then d:Destroy() end
		end
		c.CFrame = origin:Inverse() * p.CFrame
		c.Anchored = true
		c.Parent = model
		local cf = c.CFrame
		local rx, ry, rz = cf:ToEulerAnglesXYZ()
		table.insert(rows, { name = c.Name, pos = { cf.Position.X, cf.Position.Y, cf.Position.Z }, rot = { rx, ry, rz },
			size = { c.Size.X, c.Size.Y, c.Size.Z }, color = { c.Color.R, c.Color.G, c.Color.B },
			neon = c.Material == roblox.Enum.Material.Neon, cyl = c:IsA("Part") and c.Shape == roblox.Enum.PartType.Cylinder })
	end
end
local primary = model:FindFirstChild("PadBase")
model.PrimaryPart = primary
fs.writeDir("hood/art/models/pedestal")
fs.writeFile("hood/art/models/pedestal/GunPedestal.rbxm", roblox.serializeModel({ model }))
fs.writeFile(process.args[1], serde.encode("json", rows))
print(#rows, "parts")
