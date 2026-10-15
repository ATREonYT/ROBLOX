-- lune run tools/check_maps.luau   (from the repo root): finds the maps in places/HUSSANIME.rbxl the way the game will.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local place = roblox.deserializePlace(fs.readFile("huzz-valley/places/HUSSANIME.rbxl"))
local ws = place:GetService("Workspace")
local Config = luau.load(fs.readFile("huzz-valley/src/ReplicatedStorage/Shared/Config/Round.lua"), { environment = { Color3 = roblox.Color3, Vector3 = roblox.Vector3 } })()
local fakeGame = {
	GetService = function(_, name)
		if name == "Workspace" then return ws end
		if name == "CollectionService" then return { GetTagged = function() return {} end } end
		if name == "ReplicatedStorage" then
			local any; any = setmetatable({}, { __index = function() return any end })
			return any
		end
		if name == "Players" then return { GetPlayers = function() return {} end } end
	end,
}
local env = setmetatable({
	game = fakeGame, workspace = ws, Instance = roblox.Instance, CFrame = roblox.CFrame, Vector3 = roblox.Vector3, Color3 = roblox.Color3,
	Enum = roblox.Enum, RaycastParams = { new = function() return {} end },
	require = function() return Config end,
}, { __index = _G })
-- Raycast stand-in: the floor is the top of the biggest part under the point (zones excluded)
ws = setmetatable({}, { __index = function(_, k)
	local real = place:GetService("Workspace")
	if k == "Raycast" then return function() return nil end end
	local v = real[k]
	if type(v) == "function" then return function(_, ...) return v(real, ...) end end
	return v
end })
env.game = { GetService = function(_, name) if name == "Workspace" then return ws end return fakeGame:GetService(name) end }
local MapService = luau.load(fs.readFile("huzz-valley/src/ServerScriptService/HuzzServer/MapService.lua"), { environment = env })()
MapService.init()
for _, m in MapService.maps do
	print(m.name, "A", m.ZoneA.CFrame.Position, "B", m.ZoneB.Name, m.ZoneB.CFrame.Position, "Middle", m.Middle.CFrame.Position, "anchored", m.ZoneA.Anchored, m.ZoneB.Anchored)
end
print("lobby:", MapService.lobby and MapService.lobby:GetFullName())
local picks = {} for i = 1, 6 do table.insert(picks, MapService.pick().name) end print("picks:", table.concat(picks, ", "))
