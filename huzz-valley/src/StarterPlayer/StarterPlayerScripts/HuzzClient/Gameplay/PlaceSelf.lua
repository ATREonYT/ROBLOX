--[[
	The server asks this screen to move your own body (HuzzServer/PlaceService: the line-up, the lobby, a catcher
	pushed back out of a safe zone, a safe runner kept across, the fall net). Your client simulates your body, so it
	moves it: stopped (no velocity), then put there; the next physics update carries the new spot to the server and
	every other screen at once, with no jump back (owner, Oct 20 15:13: "the peoples locations are off on eachothers
	screens"). A move for a body you no longer have (you respawned meanwhile) is dropped: the server places the new one.
	Gameplay/Sprint sees the jump as a teleport (feet first: no steering until your feet touch the floor).
]]
local M = {}

local function waiting(root): boolean -- (held by holdUntilFloor below)
	local ok, v = pcall(function() return root:GetAttribute("HuzzFloorWait") end)
	return ok and v == true
end

-- Moves this character (yours) to cf, stopped. False when it isn't yours to move.
function M.apply(player, character, cf): boolean
	if typeof(cf) ~= "CFrame" or not character or character ~= player.Character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) or (root.Anchored and not waiting(root)) then
		return false -- (the server owns an anchored body and moves it itself; ours only while waiting for a floor)
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
	M.holdUntilFloor(character, root)
	return true
end

-- Owner, Oct 22 19:09: "make it so that we dont fall when you go back to the lobby". A long move (the lobby, the
-- line-up) can land you where the floor hasn't loaded on your screen yet (streaming), and your body, simulated
-- here, dropped through it. Held still (anchored, on this screen only) until a floor shows up under you, at most
-- HOLD seconds; then let go where you are.
M.HOLD = 4
M.REACH = 14 -- studs down a floor counts
function M.floorUnder(character, root): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	return workspace:Raycast(root.Position, Vector3.new(0, -M.REACH, 0), params) ~= nil
end
function M.holdUntilFloor(character, root)
	local ok, hasFloor = pcall(M.floorUnder, character, root)
	if not ok or hasFloor then return end
	root.Anchored = true
	root:SetAttribute("HuzzFloorWait", true)
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < M.HOLD and root.Parent and root.Anchored do
			task.wait(0.05)
			local ok2, found = pcall(M.floorUnder, character, root)
			if ok2 and found then break end
		end
		if root.Parent and waiting(root) then
			root:SetAttribute("HuzzFloorWait", nil)
			root.Anchored = false
		end
	end)
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
