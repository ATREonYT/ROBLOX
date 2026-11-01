--!nonstrict
-- New Game Kit: build the HUD and the place file offline with Lune.
--   lune run tools/build_place.luau          (from the kit folder)
-- 1. Runs src/Shared/HudBuilder.luau with Lune's Roblox types and saves the
--    result as src/StarterGui/KitHUD.rbxm (repo rule: UI lives in StarterGui).
-- 2. Builds places/<project name>.rbxl from default.project.json (scripts as real
--    Script/LocalScript/ModuleScript instances, the HUD in StarterGui).
-- Open the .rbxl in Studio to try it. Rojo users can `rojo serve` instead.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Instance = roblox.Instance

-- 1. HUD ---------------------------------------------------------------------
local env = {
	Instance = Instance,
	Enum = roblox.Enum,
	Font = roblox.Font,
	Color3 = roblox.Color3,
	ColorSequence = roblox.ColorSequence,
	NumberSequence = roblox.NumberSequence,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	Vector2 = roblox.Vector2,
}
local builder = luau.load(fs.readFile("src/Shared/HudBuilder.luau"), { debugName = "HudBuilder", environment = env })()
local hud = builder.Build()
fs.writeFile("src/StarterGui/KitHUD.rbxm", roblox.serializeModel({ hud }))
print(`[build] src/StarterGui/KitHUD.rbxm ({#hud:GetDescendants()} parts)`)

-- Every name in Config.HudStages must be a real HUD piece, spelled with the exact case
-- (Roblox names are case-sensitive; vault note 14 §2).
do
	local config = luau.load(fs.readFile("src/Config/GameConfig.luau"), { debugName = "GameConfig" })()
	local stagesLib = luau.load(fs.readFile("src/Shared/HudStages.luau"), { debugName = "HudStages" })()
	local missing = {}
	for _, stage in config.HudStages or {} do
		local names = if type(stage.Show) == "table" then table.clone(stage.Show) else {}
		if stage.Spotlight then
			table.insert(names, stage.Spotlight)
		end
		for _, name in names do
			if not stagesLib.Find(hud, name) then
				table.insert(missing, `{stage.Step}: {name}`)
			end
		end
	end
	if #missing > 0 then
		error("[build] Config.HudStages names HUD pieces that don't exist: " .. table.concat(missing, ", "))
	end
	print(`[build] Config.HudStages: {#(config.HudStages or {})} stages, every name found in the HUD`)
end

-- 2. Place -------------------------------------------------------------------
local game = Instance.new("DataModel")
local function classAndName(fileName)
	for _, rule in { { "%.server%.luau?$", "Script" }, { "%.client%.luau?$", "LocalScript" }, { "%.luau?$", "ModuleScript" } } do
		if string.match(fileName, rule[1]) then
			return rule[2], (string.gsub(fileName, rule[1], ""))
		end
	end
	return nil, nil
end
local function mountPath(path, name, parent)
	if fs.isDir(path) then
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
		local entries = fs.readDir(path)
		table.sort(entries)
		for _, entry in entries do
			mountPath(path .. "/" .. entry, nil, folder)
		end
		return
	end
	local fileName = string.match(path, "[^/]+$")
	if string.match(fileName, "%.rbxm$") then
		for _, inst in roblox.deserializeModel(fs.readFile(path)) do
			if name then
				inst.Name = name
			end
			inst.Parent = parent
		end
		return
	end
	local className, baseName = classAndName(fileName)
	if not className then
		return
	end
	local script = Instance.new(className)
	script.Name = name or baseName
	script.Source = fs.readFile(path)
	script.Parent = parent
end
local function mountNode(node, inst)
	for key, child in node do
		if string.sub(key, 1, 1) ~= "$" then
			if child["$path"] then
				mountPath(child["$path"], key, inst)
			else
				local target = inst:FindFirstChild(key)
				if not target then
					if inst == game then
						target = game:GetService(key)
					else
						target = Instance.new(child["$className"] or "Folder")
						target.Name = key
						target.Parent = inst
					end
				end
				mountNode(child, target)
			end
		end
	end
end
local project = serde.decode("json", fs.readFile("default.project.json"))
mountNode(project.tree, game)
fs.writeDir("places")
local placePath = `places/{project.name}.rbxl`
fs.writeFile(placePath, roblox.serializePlace(game))
print(`[build] {placePath}`)
