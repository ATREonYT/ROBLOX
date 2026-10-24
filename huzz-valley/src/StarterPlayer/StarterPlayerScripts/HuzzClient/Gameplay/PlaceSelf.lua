--[[
	The server asks this screen to move your own body (HuzzServer/PlaceService: the line-up, the lobby, a catcher
	pushed back out of a safe zone, a safe runner kept across, the fall net). Your client simulates your body, so it
	moves it: stopped (no velocity), then put there; the next physics update carries the new spot to the server and
	every other screen at once, with no jump back (owner, Oct 20 15:13: "the peoples locations are off on eachothers
	screens"). A move for a body you no longer have (you respawned meanwhile) is dropped: the server places the new one.
	Gameplay/Sprint sees the jump as a teleport (feet first: no steering until your feet touch the floor).
	Landing on your feet (owner, Oct 23 03:37: "make the user character not fall when getting transported back to the
	main lobby, it always happens like that, so please redo that and make it well done"): the body is set down
	standing on the floor under the spot (no drop at all), upright, with no spin left from a huss or a dive, and
	Roblox's own trip-over states (FallingDown, Ragdoll) are off on your character for good, so a bump, a landing or a
	move straight after lying caught can never tip it over; a body still in a trip, a stand-up or a free fall is put
	back to standing. Where the floor hasn't loaded yet (streaming), it is held in the air until it has
	(holdUntilFloor), then set down on it the same way.
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
	if not pcall(M.setDown, character, root) then
		M.holdUntilFloor(character, root)
	end
	return true
end

-- How high a standing root sits over the floor: R6 its legs plus half the root, R15 its HipHeight plus half.
function M.standHeight(character, root): number
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local leg = character:FindFirstChild("Left Leg") or character:FindFirstChild("Right Leg")
	local hip = if humanoid and humanoid.RigType == Enum.HumanoidRigType.R6 and leg and leg:IsA("BasePart") then leg.Size.Y
		elseif humanoid then humanoid.HipHeight else 2
	return hip + root.Size.Y / 2
end

-- The floor straight under the root (within REACH, from a little above it), or nil.
local function floorY(character, root): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true -- (only what you can stand on: never a zone marker or a see-through prop)
	local skip = { character }
	for _, p in game:GetService("Players"):GetPlayers() do
		if p.Character and p.Character ~= character then table.insert(skip, p.Character) end
	end
	for _, name in { "HuzzCarried", "HuzzFollowers" } do
		local f = workspace:FindFirstChild(name)
		if f then table.insert(skip, f) end
	end
	params.FilterDescendantsInstances = skip
	local hit = workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, -(M.REACH + 2), 0), params)
	return hit and hit.Position.Y or nil
end

-- Standing, back to normal: upright, still, out of any trip or stand-up (not while lying caught: Knockdown owns that).
local function stand(character, root)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or character:GetAttribute("DownedAt") ~= nil then return end
	humanoid.PlatformStand = false
	humanoid.Sit = false
	local state = humanoid:GetState()
	local S = Enum.HumanoidStateType
	if state == S.FallingDown or state == S.Ragdoll or state == S.GettingUp or state == S.Freefall
		or state == S.PlatformStanding or state == S.Physics or state == S.Landed then
		humanoid:ChangeState(S.Running)
	end
end

-- Puts a moved body down standing on the floor under it (upright, no drop); false when there is no floor there yet.
function M.setDown(character, root): boolean
	local y = floorY(character, root)
	if not y then error("no floor") end
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then flat = Vector3.new(0, 0, -1) end
	local at = Vector3.new(root.Position.X, y + M.standHeight(character, root), root.Position.Z)
	character:PivotTo(CFrame.lookAt(at, at + flat.Unit) * root.CFrame:ToObjectSpace(character:GetPivot()))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	stand(character, root)
	return true
end

-- Your character never trips over (Roblox's FallingDown and Ragdoll states: a bump at speed, a landing at an angle).
function M.noTrip(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	pcall(function()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	end)
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
			pcall(M.setDown, character, root) -- (standing on the floor that has loaded, no drop)
		end
	end)
end

function M.start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
	local player = Players.LocalPlayer
	local function added(character)
		local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
		if humanoid then M.noTrip(character) end
	end
	if player.Character then task.spawn(added, player.Character) end
	player.CharacterAdded:Connect(added)
	Net.get("Place").OnClientEvent:Connect(function(character, cf)
		M.apply(player, character, cf)
	end)
end

return M
