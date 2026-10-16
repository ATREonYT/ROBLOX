--[[
	Walk first, then run (owner: "make the animations slowly fade in from walking when you press W to running
	if you continue holding it, just like in the references"). When you start moving you set off at a walk
	and build up to your full speed (the server's HuzzSpeed on your Humanoid, RoundService) over Config/Run
	Ramp seconds, easing in; let go for a moment and the next start is a walk again. Gameplay/Locomotion cross-fades
	the owner's Walk into their Run by speed, so the legs follow the build-up on their own.
	Only your own character (movement is yours to run); a speed of 0 (frozen on the line, stuck, down) is kept.
]]
local M = {}

function M.start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")

	local Run = require(ReplicatedStorage:WaitForChild("Shared").Config.Run)
	local RAMP = Run.Ramp or 1.1 -- seconds from a walk to full speed
	local START = Run.StartSpeed or 9 -- studs a second you set off at
	local GRACE = 0.18 -- seconds you can let go (a quick turn) and keep your speed

	local player = Players.LocalPlayer
	local held, idle = 0, math.huge

	RunService.Heartbeat:Connect(function(dt)
		local character = player.Character
		local h = character and character:FindFirstChildOfClass("Humanoid")
		if not h then
			return
		end
		local cap = h:GetAttribute("HuzzSpeed")
		if type(cap) ~= "number" then
			return -- (the server hasn't set a speed yet: leave Roblox's)
		end
		if h.MoveDirection.Magnitude > 0.1 then
			idle = 0
			held += dt
		else
			idle += dt
			if idle > GRACE then
				held = 0
			end
		end
		local want
		if cap <= START then
			want = cap
		else
			local u = math.clamp(held / RAMP, 0, 1)
			local eased = u * u * (3 - 2 * u) -- smooth: gentle at the start and the top
			want = START + (cap - START) * eased
		end
		if math.abs(h.WalkSpeed - want) > 0.01 then
			h.WalkSpeed = want
		end
	end)
end

return M
