-- A few of the owner's crate parts with their look (material, colour, transparency, SurfaceAppearance), to know how
-- the opening can tint his "glow_" parts by rarity without redrawing anything.
-- lune run huzz-valley/tools/crates/peek_parts.luau [place.rbxl] [pattern]     (from the repo root)
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local game = roblox.deserializePlace(fs.readFile(process.args[1] or "huzz-valley/places/HUSSANIME.rbxl"))
local pattern = process.args[2] or "glow"
local root = game:GetService("Workspace"):FindFirstChild("scrates")
root = root and root:FindFirstChild("Standard_Crates")
assert(root, "no Standard_Crates")
local seen = {}
for _, set in root:GetChildren() do
	for _, d in set:GetDescendants() do
		if d:IsA("BasePart") and string.find(d.Name, pattern) then
			local base = set.Name .. "/" .. string.gsub(string.gsub(d.Name, "_Node$", ""), "_%d+$", "")
			if not seen[base] then
				seen[base] = true
				local kids = {}
				for _, c in d:GetChildren() do
					local extra = ""
					if c:IsA("SurfaceAppearance") then
						local ok, col = pcall(function() return c.Color end)
						extra = ok and (" color " .. tostring(col)) or ""
					end
					table.insert(kids, c.ClassName .. extra)
				end
				print(string.format("%-40s %s %s col %s tr %.2f anch %s coll %s [%s]", base, d.ClassName, tostring(d.Material), tostring(d.Color),
					d.Transparency, tostring(d.Anchored), tostring(d.CanCollide), table.concat(kids, ", ")))
			end
		end
	end
end
