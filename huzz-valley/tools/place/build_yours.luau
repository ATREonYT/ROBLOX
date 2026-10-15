-- Builds places/HuzzValley-yours.rbxl: the owner's own place (places/HUSSANIME.rbxl: maps, girls, lobby) with
-- every current script and the saved UI swapped in, so it plays without Rojo. Also strips the known
-- CoreValidation scam out of any free model. Run from the repo root after build_place.sh:
--   lune run huzz-valley/tools/place/build_yours.luau
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local ROOT = "huzz-valley/places/"
local theirs = roblox.deserializePlace(fs.readFile(ROOT .. "HUSSANIME.rbxl"))
local ours = roblox.deserializePlace(fs.readFile(ROOT .. "HuzzValley.rbxl"))

-- Each of these is replaced by the current build's version (path from the service).
local SWAP = {
	{ "ServerScriptService", "HuzzServer" },
	{ "ReplicatedStorage", "Shared" },
	{ "StarterPlayer", "StarterPlayerScripts", "HuzzClient" },
	{ "StarterGui", "HuzzUI" },
	{ "ServerStorage", "HuzzStudioTools" },
}
local function at(game, path)
	local inst = game:GetService(path[1])
	for i = 2, #path - 1 do
		inst = inst:FindFirstChild(path[i])
		if not inst then return nil end
	end
	return inst
end
for _, path in SWAP do
	local parentTheirs, parentOurs = at(theirs, path), at(ours, path)
	local name = path[#path]
	local fresh = parentOurs and parentOurs:FindFirstChild(name)
	if parentTheirs and fresh then
		local old = parentTheirs:FindFirstChild(name)
		if old then old:Destroy() end
		fresh:Clone().Parent = parentTheirs
		print("swapped " .. table.concat(path, "."))
	else
		print("skipped " .. table.concat(path, ".") .. " (missing)")
	end
end

-- The scam in free models: a hidden Dependencies > Utilities > CoreValidation script.
local removed = 0
for _, d in theirs:GetDescendants() do
	if d.ClassName == "Script" and d.Name == "CoreValidation" and d.Parent and d.Parent.Name == "Utilities" then
		local deps = d.Parent.Parent
		if deps and deps.Name == "Dependencies" then deps:Destroy() else d.Parent:Destroy() end
		removed += 1
	end
end
print("scam scripts removed: " .. removed)

fs.writeFile(ROOT .. "HuzzValley-yours.rbxl", roblox.serializePlace(theirs))
print("saved " .. ROOT .. "HuzzValley-yours.rbxl")
