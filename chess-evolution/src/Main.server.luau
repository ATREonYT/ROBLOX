--!strict
-- +1 Chess Evolution: the only server Script (ServerScriptService/Main).
-- 1. saves  2. game rules + remotes  3. the map (built from code if the place has none)  4. start loading players
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Chess")
local Config = require(ReplicatedStorage:WaitForChild("ChessConfig")) :: any
local PlayerData = require(Server:WaitForChild("PlayerData"))
local Game = require(Server:WaitForChild("Game"))

PlayerData.Configure(Config.PlayerData)
Game.Init(Config)

if not workspace:FindFirstChild("Map") then
	-- The place file ships with the map already built; this is the fallback for a bare Rojo sync.
	local MapBuilder = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("MapBuilder"))
	MapBuilder.Build(Config).Parent = workspace
	print("[Chess] map built from code (no saved Map in Workspace)")
end

require(Server:WaitForChild("Rivals")).Spawn(Config, workspace:WaitForChild("Map"))
require(Server:WaitForChild("Leaderboard")).Start(Config, workspace:WaitForChild("Map"))
PlayerData.Start()
print("[Chess] server ready")
