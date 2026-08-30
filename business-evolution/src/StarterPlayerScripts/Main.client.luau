--!strict
-- THE single client entry point (§13.1). Mirrors the server's two-phase init.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- The world is built server-side on startup; wait for the handshake folder so
-- controllers never race the map. (Set by MapService when geometry is ready.)
ReplicatedStorage:WaitForChild("Remotes")

local playerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
local Client = playerScripts:WaitForChild("Client")
local Controllers = Client:WaitForChild("Controllers")
local Ui = Client:WaitForChild("Ui")

local controllers: { any } = {
	require(Controllers:WaitForChild("StateController")),
	require(Controllers:WaitForChild("SoundController")),
	require(Controllers:WaitForChild("ClickController")),
	require(Controllers:WaitForChild("PopupController")),
	require(Controllers:WaitForChild("RivalRenderer")),
	require(Controllers:WaitForChild("InternRenderer")),
	require(Controllers:WaitForChild("CameraFx")),
	require(Ui:WaitForChild("Theme")),
	require(Ui:WaitForChild("Hud")),
	require(Ui:WaitForChild("ShopUi")),
	require(Ui:WaitForChild("InternUi")),
	require(Ui:WaitForChild("RestructureUi")),
	require(Ui:WaitForChild("ElevatorUi")),
	require(Ui:WaitForChild("RankUpFx")),
}

for _, controller in controllers do
	if controller.Init then
		controller:Init()
	end
end

for _, controller in controllers do
	if controller.Start then
		controller:Start()
	end
end

print("[BusinessEvolution] client up —", #controllers, "controllers started")
