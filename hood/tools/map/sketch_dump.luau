-- sketch_dump.luau: every visible part of the built World 1 map as JSON rows for hood/tools/map/sketch.py (see its header).
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local game = roblox.deserializePlace(fs.readFile(process.args[1]))
local map = game.Workspace:FindFirstChild("TheBlockV2")
local out = {}
local top = {}
for _, c in map:GetChildren() do
	local n = 0
	for _, d in c:GetDescendants() do if d:IsA("BasePart") then n += 1 end end
	table.insert(top, c.Name .. " (" .. c.ClassName .. ", " .. n .. ")")
end
print(table.concat(top, "\n"))
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") and d.Transparency < 0.95 then
		local cf, s = d.CFrame, d.Size
		local rx, ry, rz = cf:ToOrientation()
		local path = {}
		local p = d.Parent
		while p and p ~= map do table.insert(path, 1, p.Name); p = p.Parent end
		local col = d.Color
		table.insert(out, string.format('[%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.4f,%.4f,%.4f,%d,%d,%d,%q,%q,%q]',
			cf.Position.X, cf.Position.Y, cf.Position.Z, s.X, s.Y, s.Z, rx, ry, rz,
			math.floor(col.R * 255), math.floor(col.G * 255), math.floor(col.B * 255), d.Name, table.concat(path, "/"), d.ClassName))
	end
end
fs.writeFile(process.args[2], "[" .. table.concat(out, ",\n") .. "]")
print("parts", #out)
