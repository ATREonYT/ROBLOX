--[[
	Plays the Huss Valley run and the huss dash (Shared/RunMotion) on every R15 character on this
	client, so everyone sees everyone run and dash the same way (the dash from the character's
	DashAt/DashDir attributes, Gameplay/Dash). Off when the owner's run can play (Shared/AnimationLibrary:
	published, or raw in Studio). A carrier keeps the carry arms (CarryAnimator layers after this).
]]
local M = {}

function M.start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Library = require(Shared.AnimationLibrary)
	local RunMotion = require(Shared.RunMotion)
	local Frame = require(script.Parent.Frame)
	if Library.has("Run") then
		return -- (the owner's run plays instead: Gameplay/AvatarAnimations, and the dash: Gameplay/Dash)
	end

	local carried = Workspace:WaitForChild("HuzzCarried")
	local recs = {} -- Player -> { character, rec }

	Players.PlayerRemoving:Connect(function(p)
		recs[p] = nil
	end)

	Frame.on(10, function(dt)
		dt = math.clamp(dt, 1 / 240, 1 / 15)
		local now = Workspace:GetServerTimeNow()
		local carriers = {}
		for _, model in carried:GetChildren() do
			local id = model:GetAttribute("Carrier")
			if id then
				carriers[id] = true
			end
		end
		for _, p in Players:GetPlayers() do
			local character = p.Character
			local r = recs[p]
			-- (Re)build when the character changes, its joints were replaced, or it wasn't complete yet.
			if r and (r.character ~= character or not (r.rec and r.rec.joints.root.Parent)) then
				r = nil
			end
			if character and not r then
				local rec = RunMotion.new(character)
				if rec then
					r = { character = character, rec = rec }
					recs[p] = r
				end
			end
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r and root then
				local v = root.AssemblyLinearVelocity
				-- Knocked down: speed 0, so the sprint fades out under the fall instead of snapping off.
				local speed = if character:GetAttribute("DownedAt") then 0 else Vector3.new(v.X, 0, v.Z).Magnitude
				-- The huss dash: its age and its direction in the body's frame (x right, z forward).
				local dashAt, dashDir = character:GetAttribute("DashAt"), character:GetAttribute("DashDir")
				local age, localDir = nil, nil
				if type(dashAt) == "number" and typeof(dashDir) == "Vector3" then
					age = now - dashAt
					local d = root.CFrame:VectorToObjectSpace(dashDir)
					localDir = Vector3.new(d.X, 0, -d.Z)
				end
				RunMotion.step(r.rec, dt, speed, math.abs(v.Y) < 10, carriers[p.UserId] == true, age, localDir)
			end
		end
	end)
end

return M
