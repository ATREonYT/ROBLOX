-- The owner's crates keep their .glb's groups: a nameless "Node<n>" Model inside a crate holds the parts that were one
-- moving piece in his file (the Storm Vault's lid with its crystals' cover, the Beast Chest's jaw with its teeth and
-- horns). Lists each crate's direct children that are groups, with how many parts and which names they hold.
-- lune run huzz-valley/tools/crates/lid_groups.luau [place.rbxl]     (from the repo root)
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local game = roblox.deserializePlace(fs.readFile(process.args[1] or "huzz-valley/places/HUSSANIME.rbxl"))
for _, set in game:GetService("Workspace").scrates.Standard_Crates:GetChildren() do
	local crate, most = nil, 0
	for _, m in set:GetChildren() do
		local n = 0
		for _, d in m:GetDescendants() do if d:IsA("BasePart") then n += 1 end end
		if m:IsA("Model") and n > most then crate, most = m, n end
	end
	local loose = 0
	for _, ch in crate:GetChildren() do
		if ch:IsA("Model") and string.match(ch.Name, "^Node%d+$") then
			local names, n = {}, 0
			for _, d in ch:GetDescendants() do
				if d:IsA("BasePart") then
					n += 1
					local base = string.gsub(d.Name, "_%d+$", "")
					names[base] = (names[base] or 0) + 1
				end
			end
			local list = {}
			for k, v in names do table.insert(list, k .. (if v > 1 then "x" .. v else "")) end
			table.sort(list)
			print(string.format("%s / %s: group %s, %d parts: %s", set.Name, crate.Name, ch.Name, n, table.concat(list, ", ")))
		else
			loose += 1
		end
	end
	print(string.format("%s / %s: %d other children", set.Name, crate.Name, loose))
end
