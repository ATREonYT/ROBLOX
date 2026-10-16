--[[
	Plays the Huss Valley sprint (Shared/RunMotion) on every R15 character on this client, so
	everyone sees everyone run the same way. Off when the owner's run animation is set
	(Config/Animations.Run). A carrier keeps the carry arms (CarryAnimator layers after this).
]]
local M = {}

function M.start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Animations = require(Shared.Config.Animations)
	local RunMotion = require(Shared.RunMotion)
	local Frame = require(script.Parent.Frame)
	if Animations.Run ~= "" then
		return
	end

	local carried = Workspace:WaitForChild("HuzzCarried")
	local recs = {} -- Player -> { character, rec }

	Players.PlayerRemoving:Connect(function(p)
		recs[p] = nil
	end)

	Frame.on(10, function(dt)
		dt = math.clamp(dt, 1 / 240, 1 / 15)
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
			if r and r.character ~= character then
				r = nil
			end
			if character and not r then
				local rec = RunMotion.new(character)
				r = rec and { character = character, rec = rec } or { character = character }
				recs[p] = r
			end
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r and r.rec and root and not character:GetAttribute("DownedAt") then
				local v = root.AssemblyLinearVelocity
				local speed = Vector3.new(v.X, 0, v.Z).Magnitude
				RunMotion.step(r.rec, dt, speed, math.abs(v.Y) < 10, carriers[p.UserId] == true)
			end
		end
	end)
end

return M
