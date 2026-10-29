-- Lists what's inside a HuzzKnives file (or a place's ServerStorage > HuzzKnives): each knife's parts, their class,
-- mesh, size, colour, material and texture, so a knife that would show as a plain box in Studio is easy to spot.
-- Usage (repo root): lune run huzz-valley/tools/knives/inspect_knives.luau [file.rbxm|place.rbxl] [knifeKey]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local path = process.args[1] or "huzz-valley/assets/knives/HuzzKnives.rbxm"
local only = process.args[2]
local folder
if string.sub(path, -5) == ".rbxl" then
	local game = roblox.deserializePlace(fs.readFile(path))
	folder = game:GetService("ServerStorage"):FindFirstChild("HuzzKnives")
else
	folder = roblox.deserializeModel(fs.readFile(path))[1]
end
assert(folder, "no HuzzKnives in " .. path)
local function prop(inst, name)
	local ok, v = pcall(function() return inst[name] end)
	return if ok then v else nil
end
for _, m in folder:GetChildren() do
	if only and m.Name ~= only then continue end
	local parts = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local mesh = prop(d, "MeshId") or ""
			local content = prop(d, "MeshContent")
			local cs = if content ~= nil then tostring(content) else ""
			local sm = d:FindFirstChildOfClass("SpecialMesh")
			table.insert(parts, string.format("    %-22s %-9s mesh=%s content=%s tex=%s size=(%.2f %.2f %.2f) col=%s mat=%s tr=%.2f%s",
				d.Name, d.ClassName, if mesh == "" then "-" else mesh, if cs == "" then "-" else string.sub(cs, 1, 40),
				tostring(prop(d, "TextureID") or ""), d.Size.X, d.Size.Y, d.Size.Z, tostring(d.Color), tostring(d.Material),
				d.Transparency, if sm then " SpecialMesh=" .. tostring(sm.MeshId) else ""))
		end
	end
	print(string.format("%s (%s) %d parts, Studs=%s Wear=%s", m.Name, m.ClassName, #parts, tostring(m:GetAttribute("Studs")), tostring(m:GetAttribute("Wear"))))
	if only or process.env.ALL then
		for _, l in parts do print(l) end
	end
end
