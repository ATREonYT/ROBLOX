-- lune run tools/check_maps.luau   (from the repo root): finds the maps in places/HuzzValley-yours.rbxl the way the game will.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local place = roblox.deserializePlace(fs.readFile("huzz-valley/places/HuzzValley-yours.rbxl"))
local ws = place:GetService("Workspace")
local Config = luau.load(fs.readFile("huzz-valley/src/ReplicatedStorage/Shared/Config/Round.lua"), { environment = { Color3 = roblox.Color3, Vector3 = roblox.Vector3 } })()
local fakeGame = {
	GetService = function(_, name)
		if name == "Workspace" then return ws end
		if name == "CollectionService" then return { GetTagged = function() return {} end } end
		if name == "ReplicatedStorage" then return place:GetService("ReplicatedStorage") end
		if name == "Players" then return { GetPlayers = function() return {} end } end
	end,
}
local env = setmetatable({
	game = fakeGame, workspace = ws, Instance = roblox.Instance, CFrame = roblox.CFrame, Vector3 = roblox.Vector3, Color3 = roblox.Color3,
	Enum = roblox.Enum, RaycastParams = { new = function() return {} end },
	require = function() return Config end,
}, { __index = _G })
env.game = { GetService = function(_, name) if name == "Workspace" then return ws end return fakeGame:GetService(name) end }
local MapService = luau.load(fs.readFile("huzz-valley/src/ServerScriptService/HuzzServer/MapService.lua"), { environment = env })()
MapService.init()
for _, m in MapService.maps do
	print(string.format("map %-15s shown as %-12s stored in %s", m.name, m.display, m.box:GetFullName()))
end
print("lobby:", MapService.lobby and MapService.lobby:GetFullName())
local spawn = place:GetService("Workspace"):FindFirstChild("HuzzLobbySpawn")
print("lobby spawn made:", spawn ~= nil, spawn and spawn.CFrame.Position)
for i = 1, 4 do
	local a, b = MapService.candidates()
	print("vote " .. i .. ":", a.name, "vs", b.name, a ~= b and "" or "SAME MAP!")
end
