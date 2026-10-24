-- lune run huzz-valley/tools/world/light_audit.luau [place.rbxl]   (repo root)
-- Lists a place's Lighting settings, its post effects and every light in it (where, how bright, how far), so we can
-- see what makes pools of light (owner Oct 19: "the objects dont have light only around them, there is even, nice,
-- cartoony lighting over the map").
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local path = process.args[1] or "huzz-valley/places/HUSSANIME.rbxl"
local game = roblox.deserializePlace(fs.readFile(path))
local L = game:GetService("Lighting")
local function show(inst, props)
	local out = {}
	for _, p in props do
		local ok, v = pcall(function() return inst[p] end)
		table.insert(out, p .. "=" .. (ok and tostring(v) or "?"))
	end
	print(inst.ClassName .. " " .. inst.Name .. ": " .. table.concat(out, "  "))
end
show(L, { "Technology", "Brightness", "ClockTime", "Ambient", "OutdoorAmbient", "ColorShift_Top", "ColorShift_Bottom",
	"EnvironmentDiffuseScale", "EnvironmentSpecularScale", "ExposureCompensation", "GlobalShadows", "ShadowSoftness",
	"GeographicLatitude" })
for _, c in L:GetChildren() do
	if c:IsA("PostEffect") or c:IsA("Atmosphere") or c:IsA("Sky") or c:IsA("Clouds") then
		local props = { "Enabled" }
		if c:IsA("ColorCorrectionEffect") then props = { "Enabled", "Brightness", "Contrast", "Saturation", "TintColor" } end
		if c:IsA("BloomEffect") then props = { "Enabled", "Intensity", "Size", "Threshold" } end
		if c:IsA("Atmosphere") then props = { "Density", "Offset", "Color", "Decay", "Glare", "Haze" } end
		show(c, props)
	end
end
local kinds, byParent = {}, {}
for _, d in game:GetDescendants() do
	if d:IsA("Light") then
		kinds[d.ClassName] = (kinds[d.ClassName] or 0) + 1
		local top = d
		while top.Parent and top.Parent ~= game and top.Parent.Parent ~= game do top = top.Parent end
		local key = top:GetFullName() .. " / " .. (d.Parent and d.Parent.Name or "?")
		local b = byParent[key] or { n = 0, bright = 0, range = 0, shadows = 0 }
		b.n += 1
		b.bright = math.max(b.bright, d.Brightness)
		b.range = math.max(b.range, (pcall(function() return d.Range end)) and d.Range or 0)
		if d.Shadows then b.shadows += 1 end
		byParent[key] = b
	end
end
for k, n in kinds do print("lights: " .. k .. " x" .. n) end
local rows = {}
for k, b in byParent do table.insert(rows, { k = k, b = b }) end
table.sort(rows, function(a, b) return a.b.n > b.b.n end)
for i, r in rows do
	if i > 40 then break end
	print(string.format("  %3d  bright<=%.2f range<=%.1f shadows %d  %s", r.b.n, r.b.bright, r.b.range, r.b.shadows, r.k))
end
