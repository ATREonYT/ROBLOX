-- export_gun_stand.luau: the whole lobby gun shop stand (its deck, the three tiers, stairs, backdrop and the 10 pads with
-- their plates), with no guns, labels or effects, from the built place as hood/art/models/pedestal/GunStand.rbxm, plus
-- its parts as JSON for gun_pedestal_glb.py. Usage: lune run hood/tools/blender/export_gun_stand.luau <parts.json>
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local Instance, CFrame = roblox.Instance, roblox.CFrame
local game = roblox.deserializePlace(fs.readFile("hood/places/HoodEvolution.rbxl"))
local lobby = game.Workspace.TheBlockV2.Lobby
local DROP = { Display = true, LabelAnchor = true, FxCore = true, StateHazeSource = true }
local model = Instance.new("Model")
model.Name = "GunStand"
for _, src in { lobby.GunDeck, lobby.Armory.Armory } do
	local c = src:Clone()
	for _, d in c:GetDescendants() do
		if DROP[d.Name] or d.Name:match("^GunPoint_") or d:IsA("LuaSourceContainer") then d.Parent = nil end
	end
	c.Parent = model
end
local parts = {}
local lo, hi
for _, p in model:GetDescendants() do
	if p:IsA("BasePart") then
		table.insert(parts, p)
		local q = p.CFrame.Position
		lo = lo and roblox.Vector3.new(math.min(lo.X, q.X), math.min(lo.Y, q.Y - p.Size.Y / 2), math.min(lo.Z, q.Z)) or q
		hi = hi and roblox.Vector3.new(math.max(hi.X, q.X), math.max(hi.Y, q.Y), math.max(hi.Z, q.Z)) or q
	end
end
-- the origin: the middle of the footprint, on its lowest face
local origin = CFrame.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)
local rows = {}
for _, p in parts do
	p.CFrame = origin:Inverse() * p.CFrame
	p.Anchored = true
	local cf = p.CFrame
	local rx, ry, rz = cf:ToEulerAnglesXYZ()
	local kind = p:IsA("WedgePart") and "wedge" or (p:IsA("Part") and p.Shape == roblox.Enum.PartType.Cylinder and "cyl") or "box"
	if p:IsA("Part") and p.Shape == roblox.Enum.PartType.Ball then kind = "ball" end
	table.insert(rows, { name = p.Name, pos = { cf.Position.X, cf.Position.Y, cf.Position.Z }, rot = { rx, ry, rz },
		size = { p.Size.X, p.Size.Y, p.Size.Z }, color = { p.Color.R, p.Color.G, p.Color.B },
		neon = p.Material == roblox.Enum.Material.Neon, cyl = kind == "cyl", kind = kind, hidden = p.Transparency >= 0.99 })
end
model.PrimaryPart = parts[1]
fs.writeDir("hood/art/models/pedestal")
fs.writeFile("hood/art/models/pedestal/GunStand.rbxm", roblox.serializeModel({ model }))
fs.writeFile(process.args[1], serde.encode("json", rows))
print(#rows, "parts", hi - lo)
