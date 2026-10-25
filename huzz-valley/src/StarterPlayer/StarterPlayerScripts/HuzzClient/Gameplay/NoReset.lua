--[[
	No respawning (owner, Oct 25: "make players not be able to respawn, it ruins the game mechanics"): Roblox's
	Reset Character button in the Esc menu is turned off for everyone, in the lobby and in a game. Roblox only takes
	this once its own menu has loaded, so it keeps trying for a while. (A fall off the map still brings you back as
	before: RoundService places the new body.)
	And whenever a new body does come (a fall, or a reset on an old copy of the game), the camera follows it again:
	owner's clip, Oct 25 11:32: a reset in the Hero's solo run left the camera standing still far behind the new body.
	Unless a camera shot (Gameplay/Cinematic, SecretReveal, CombineMachine) is playing, it goes back to Roblox's own
	camera on the new body's Humanoid.
]]
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local M = {}

function M.start()
	task.spawn(function()
		for _ = 1, 30 do
			if pcall(function() StarterGui:SetCore("ResetButtonCallback", false) end) then
				print("[Huzz] NoReset: the Reset Character button is off")
				return
			end
			task.wait(1)
		end
		warn("[Huzz] NoReset: couldn't turn the Reset Character button off")
	end)

	local player = Players.LocalPlayer
	local function follow(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid or player.Character ~= character then return end
		for _ = 1, 3 do -- (now, and again once Roblox's own camera script has had its turn)
			local camera = Workspace.CurrentCamera
			if camera and player:GetAttribute("HuzzCinematic") ~= true then
				if camera.CameraSubject ~= humanoid then camera.CameraSubject = humanoid end
				if camera.CameraType == Enum.CameraType.Scriptable or camera.CameraType == Enum.CameraType.Fixed then
					camera.CameraType = Enum.CameraType.Custom
				end
			end
			task.wait(0.5)
			if player.Character ~= character then return end
		end
	end
	player.CharacterAdded:Connect(follow)
end

return M
