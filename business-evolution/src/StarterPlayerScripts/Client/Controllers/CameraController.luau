--!strict
-- Camera setup for a compact world (ART Part 4.1 / 7.6).
--
-- The map shrank to ~90x90, so the default 12.5-128 stud zoom range is wrong:
-- zoomed out you see the void past the cliffs, zoomed in you see a shoulder.
-- This pins a sensible range and owns the FOV base that CameraFx punches from.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

local BASE_FOV = 70 -- everything that punches FOV tweens back to THIS, never
-- to the current value, or repeated punches drift (ART 7.6)
local MIN_ZOOM = 14
local MAX_ZOOM = 46

local CameraController = {}

local trove = Trove.new()

function CameraController.baseFov(): number
	return BASE_FOV
end

local function applyToPlayer(player: Player)
	player.CameraMinZoomDistance = MIN_ZOOM
	player.CameraMaxZoomDistance = MAX_ZOOM
	player.CameraMode = Enum.CameraMode.Classic
end

function CameraController:Init()
	local camera = Workspace.CurrentCamera
	if camera then
		camera.FieldOfView = BASE_FOV
	end
	applyToPlayer(Players.LocalPlayer)
end

function CameraController:Start()
	-- Roblox resets these on respawn in some configurations, so reapply.
	trove:Connect(Players.LocalPlayer.CharacterAdded, function()
		task.defer(function()
			applyToPlayer(Players.LocalPlayer)
			local camera = Workspace.CurrentCamera
			if camera then
				camera.FieldOfView = BASE_FOV
			end
		end)
	end)
end

return CameraController
