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
	Owner, Oct 25 15:06: "make the teleportation be right on point ... the players either dont appear for a few seconds
	or look like they are being dragged there". Someone else's move reaches this screen too (drawAt): their body is
	drawn at the spot at once (their root joint's C0, on this screen only, never sent) while Roblox's own copy of it
	catches up, which it does late and by sliding across; once that copy is within ARRIVE studs the drawing eases off
	in EASE seconds (at most HOLD_OTHERS seconds, then as Roblox has it).
	Owner, Oct 25 15:11: "make the players positions locked in when its the selection of hero or chicken, so they are
	perfectly lined up". While you wait in a game (HuzzFrozen: the line-up, the pick, the countdown) your body is held
	on the spot the server put you (holdSpot): same place, same facing, nothing pushes it off.
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
	M.lastFrom = root.Position
	character:PivotTo(cf)
	if not pcall(M.setDown, character, root) then
		M.holdUntilFloor(character, root)
	end
	M.spot = { character = character, cf = cf }
	pcall(M.turnCamera, player, root, cf)
	return true
end

-- After a long move in a game, your camera turns to look the way the spot faces (owner, Oct 25 15:17: "make the
-- catcher spawn facing the opponents"): Roblox's camera keeps its old direction across a move, and shift lock then
-- turned the body round to it. Not during the round's own camera shots (Gameplay/Cinematic hands back itself), and
-- not for a short push (a safe-zone wall, the line).
M.TURN_FROM = 20 -- studs: a move at least this long turns the camera
function M.turnCamera(player, root, cf)
	local role = player:GetAttribute("HuzzRole")
	if (role ~= "Runner" and role ~= "Catcher") or player:GetAttribute("HuzzCinematic") == true then return end
	if M.lastFrom and (M.lastFrom - cf.Position).Magnitude < M.TURN_FROM then return end
	local cam = workspace.CurrentCamera
	if not cam or cam.CameraType ~= Enum.CameraType.Custom then return end
	local look = cf.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then return end
	flat = flat.Unit
	local dist = math.clamp((cam.CFrame.Position - cam.Focus.Position).Magnitude, 8, 24)
	local head = root.Position + Vector3.new(0, 1.5, 0)
	local eye = head - flat * dist * 0.97 + Vector3.new(0, dist * 0.25, 0)
	cam.CFrame = CFrame.lookAt(eye, head)
end

-- Someone else's body: drawn at `cf` on this screen until Roblox's copy gets there.
M.ARRIVE = 8 -- studs: Roblox's copy this close to the spot, the drawing eases off
M.EASE = 0.12 -- seconds it eases off in
M.HOLD_OTHERS = 3 -- seconds at most
local drawn = {} -- character -> { joint, base, cf, untilAt, fade } (a plain table, cleared as each one ends)

local function rootJointOf(character): Motor6D?
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then return nil end
	for _, j in root:GetChildren() do -- R6: RootJoint in the root
		if j:IsA("Motor6D") and j.Part0 == root and j.Part1 then return j end
	end
	local lower = character:FindFirstChild("LowerTorso") -- R15: Root in the LowerTorso
	local j = lower and lower:FindFirstChild("Root")
	if j and j:IsA("Motor6D") and j.Part0 == root then return j end
	return nil
end

local function release(character)
	local d = drawn[character]
	drawn[character] = nil
	if d and d.joint.Parent then pcall(function() d.joint.C0 = d.base end) end
end

function M.drawAt(character, cf)
	if typeof(cf) ~= "CFrame" or not character then return end
	local ok, root = pcall(function() return character:FindFirstChild("HumanoidRootPart") end)
	if not ok then return end
	if not (root and root:IsA("BasePart")) or root.Anchored then return end
	if (root.Position - cf.Position).Magnitude <= M.ARRIVE then return end -- (already about there)
	local d = drawn[character]
	if d and d.joint.Parent then
		d.cf, d.untilAt, d.fade = cf, os.clock() + M.HOLD_OTHERS, nil -- (a newer move: the same joint, its own base)
		return
	end
	local joint = rootJointOf(character)
	if not joint then return end
	drawn[character] = { joint = joint, base = joint.C0, cf = cf, untilAt = os.clock() + M.HOLD_OTHERS }
end

function M.stepDrawn(dt: number)
	for character, d in drawn do
		local root = d.joint.Part0
		if not (d.joint.Parent and root and root.Parent == character and character.Parent) or root.Anchored
			or os.clock() > d.untilAt then
			release(character)
			continue
		end
		if not d.fade and (root.Position - d.cf.Position).Magnitude <= M.ARRIVE then d.fade = 1 end
		if d.fade then
			d.fade -= dt / M.EASE
			if d.fade <= 0 then
				release(character)
				continue
			end
		end
		-- (the body where it would be with its root at the spot; fading: part way back to its own root)
		local rel = root.CFrame:ToObjectSpace(d.cf)
		if d.fade then
			local w = d.fade * d.fade * (3 - 2 * d.fade)
			rel = CFrame.identity:Lerp(rel, w)
		end
		d.joint.C0 = rel * d.base
	end
end

-- Your own body while you wait for the pick: held on the spot the server put you (flat, and facing), so the line
-- stays straight. Only in the pick's stages: from the countdown on, shift lock turns you to the camera, and the two
-- would fight. Not when it's far from there (a move still on its way: the server sends the next one).
M.HOLD_NEAR = 6 -- studs
M.HOLD_STAGES = { Lineup = true, Picking = true, Chosen = true }
function M.holdSpot(player, stage: string?)
	local spot = M.spot
	local character = player.Character
	if not (spot and character and spot.character == character and M.HOLD_STAGES[stage or ""]) then return end
	if player:GetAttribute("HuzzFrozen") ~= true or character:GetAttribute("DownedAt") ~= nil then return end
	local role = player:GetAttribute("HuzzRole")
	if role ~= "Runner" and role ~= "Catcher" then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) or root.Anchored then return end
	local at = spot.cf.Position
	local here = root.Position
	local off = Vector3.new(here.X - at.X, 0, here.Z - at.Z)
	if off.Magnitude > M.HOLD_NEAR then return end
	local look = spot.cf.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then return end
	local want = CFrame.new(at.X, here.Y, at.Z) * CFrame.Angles(0, math.atan2(-flat.X, -flat.Z), 0) -- (upright, its facing)
	if off.Magnitude > 0.02 or root.CFrame.LookVector:Dot(flat.Unit) < 0.9995 then
		character:PivotTo(want * root.CFrame:ToObjectSpace(character:GetPivot()))
	end
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(0, math.min(v.Y, 0), 0)
	root.AssemblyAngularVelocity = Vector3.zero
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
		if character == player.Character then
			M.apply(player, character, cf)
		else
			M.drawAt(character, cf)
		end
	end)
	-- (first in the frame: the others drawn where they are, your own body back on its spot before anything poses it)
	local round = Net.get("Round")
	require(script.Parent.Frame).on(0, function(dt)
		M.stepDrawn(dt)
		M.holdSpot(player, round:GetAttribute("Stage"))
	end)
end

return M
