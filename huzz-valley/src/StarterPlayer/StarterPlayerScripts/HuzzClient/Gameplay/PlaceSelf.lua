--[[
	The server asks this screen to move your own body (HuzzServer/PlaceService: the line-up, the lobby, a catcher
	pushed back out of a safe zone, a safe runner kept across, the fall net). Your client simulates your body, so it
	moves it: stopped (no velocity), then put there; the next physics update carries the new spot to the server and
	every other screen at once, with no jump back (owner, Oct 20 15:13: "the peoples locations are off on eachothers
	screens"). A move for a body you no longer have (you respawned meanwhile) is dropped: the server places the new one.
	Gameplay/Sprint sees the jump as a teleport (feet first: no steering until your feet touch the floor).
]]
local M = {}

-- Moves this character (yours) to cf, stopped. False when it isn't yours to move.
function M.apply(player, character, cf): boolean
	if typeof(cf) ~= "CFrame" or not character or character ~= player.Character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) or root.Anchored then
		return false -- (the server owns an anchored body and moves it itself)
	end
	-- (a huss, dive or halt still pushing would carry the body off the spot, and the server would send it back again)
	pcall(function()
		for _, c in root:GetChildren() do
			if c.Name == "HuzzDash" or c.Name == "HuzzLunge" or c.Name == "HuzzHalt" or c.Name == "HuzzLasso" then c:Destroy() end
		end
	end)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.AssemblyLinearVelocity = Vector3.zero
			d.AssemblyAngularVelocity = Vector3.zero
		end
	end
	character:PivotTo(cf)
	return true
end

function M.start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
	local player = Players.LocalPlayer
	Net.get("Place").OnClientEvent:Connect(function(character, cf)
		M.apply(player, character, cf)
	end)
end

return M
