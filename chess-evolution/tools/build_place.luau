--!nonstrict
-- +1 Chess Evolution: build the map, the HUD and the place file offline with Lune.
--   cd chess-evolution && lune run tools/build_place.luau
-- 1. Builds the map (src/Shared/MapBuilder.luau) into Workspace.Map.
-- 2. Builds the HUD (src/Shared/HudBuilder.luau) and saves src/StarterGui/ChessHUD.rbxm (UI lives in StarterGui).
-- 3. Writes places/ChessEvolution.rbxl from default.project.json.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Instance = roblox.Instance

local modules = {}
local env
local function loadModule(path, name)
	if modules[name] then
		return modules[name]
	end
	local scriptStub = { Parent = { WaitForChild = function(_, child)
		return { __module = child }
	end } }
	local e = setmetatable({ script = scriptStub }, { __index = env })
	local result = luau.load(fs.readFile(path), { debugName = name, environment = e, injectGlobals = false })()
	modules[name] = result
	return result
end
env = setmetatable({
	Instance = Instance, Enum = roblox.Enum, Font = roblox.Font, Color3 = roblox.Color3, ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, NumberSequence = roblox.NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	NumberRange = roblox.NumberRange, UDim = roblox.UDim, UDim2 = roblox.UDim2, Vector2 = roblox.Vector2, Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Rect = roblox.Rect,
	require = function(stub)
		local name = stub.__module
		return loadModule(`src/Shared/{name}.luau`, name)
	end,
}, { __index = getfenv() })

local config = luau.load(fs.readFile("src/Config/ChessConfig.luau"), { debugName = "ChessConfig", environment = env })()
local MapBuilder = loadModule("src/Shared/MapBuilder.luau", "MapBuilder")
local map = MapBuilder.Build(config)
local count = 0
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		count += 1
	end
end
print(`[build] map: {count} parts`)

if fs.isFile("src/Shared/HudBuilder.luau") then
	local Hud = loadModule("src/Shared/HudBuilder.luau", "HudBuilder")
	local hud = Hud.Build(config)
	fs.writeFile("src/StarterGui/ChessHUD.rbxm", roblox.serializeModel({ hud }))
	print(`[build] src/StarterGui/ChessHUD.rbxm ({#hud:GetDescendants()} parts)`)
end

-- Place ------------------------------------------------------------------------
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
	if not fs.isDir(path) and not fs.isFile(path) then
		print(`[build] missing {path} (skipped)`)
		return
	end
	if fs.isDir(path) then
		local f = Instance.new("Folder")
		f.Name = name or string.match(path, "[^/]+$")
		f.Parent = parent
		local entries = fs.readDir(path)
		table.sort(entries)
		for _, entry in entries do
			mountPath(path .. "/" .. entry, nil, f)
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
	local s = Instance.new(className)
	s.Name = name or baseName
	s.Source = fs.readFile(path)
	s.Parent = parent
end
local function mountTree(node, inst)
	for key, child in node do
		if string.sub(key, 1, 1) ~= "$" then
			if child["$path"] then
				mountPath(child["$path"], key, inst)
			else
				local target = inst:FindFirstChild(key)
				if not target then
					local ok, svc = pcall(function()
						return game:GetService(key)
					end)
					target = if ok and svc then svc else Instance.new(child["$className"] or "Folder")
					target.Name = key
					target.Parent = inst
				end
				mountTree(child, target)
			end
		end
	end
end
local project = serde.decode("json", fs.readFile("default.project.json"))
mountTree(project.tree, game)
map.Parent = game:GetService("Workspace")
MapBuilder.Light(game:GetService("Lighting"), game:GetService("Workspace"))
local name = project.name
fs.writeDir("places")
fs.writeFile(`places/{name}.rbxl`, roblox.serializePlace(game))
print(`[build] places/{name}.rbxl`)

-- Studio install bundle: places/Install.rbxm (one Folder per service), loaded by
-- tools/studio/install.lua through the Studio MCP / Command Bar.
local bundle = Instance.new("Folder")
bundle.Name = "ChessInstall"
for key, child in project.tree do
	if string.sub(key, 1, 1) ~= "$" then
		local svcFolder = Instance.new("Folder")
		svcFolder.Name = key
		svcFolder.Parent = bundle
		mountTree(child, svcFolder)
	end
end
local ws = Instance.new("Folder")
ws.Name = "Workspace"
ws.Parent = bundle
map:Clone().Parent = ws
fs.writeFile("places/Install.rbxm", roblox.serializeModel({ bundle }))
print("[build] places/Install.rbxm")
