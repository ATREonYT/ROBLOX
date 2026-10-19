--[[
	Walk first, then run (owner: "make the animations slowly fade in from walking when you press W to running
	if you continue holding it, just like in the references"). When you start moving you set off at a walk
	and build up to your full speed (the server's HuzzSpeed on your Humanoid, RoundService) over Config/Run
	Ramp seconds, easing out (quick to get going, settling softly into the top); let go for a moment and the next start is a walk again. Gameplay/Locomotion cross-fades
	the owner's Walk into their Run by speed, so the legs follow the build-up on their own.
	Only your own character (movement is yours to run); a speed of 0 (frozen on the line, stuck, down) is kept.
	Feet first (owner, Oct 19: "move when your legs touch the floor", "make when legs touch the floor and then you
	move"): after you spawn, or the game moves you (the line-up, the lobby, the fall net: any jump of more than
	TELEPORT studs in one frame), you can't steer or huss until your feet are on the floor (Humanoid.FloorMaterial):
	WalkSpeed 0 meanwhile, so you drop straight down instead of walking in the air. Running off a kerb or a step is
	never held (only a spawn or a teleport arms it), so normal controls stay as quick as before. The local attribute
	HuzzFeetFirst says it's holding (Gameplay/Dash waits for it too).
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
	local idle = math.huge
	local speed = START -- the speed being built up (follows the cap smoothly)
	local TAU = RAMP / 3 -- (an easing that gets 95% of the way in RAMP seconds)

	-- Feet first: held from a spawn or a teleport until the feet touch the floor.
	local TELEPORT = 12 -- studs in one frame (faster than any run, huss or leap moves you) = the game moved you
	local GIVE_UP = 3 -- seconds: never hold longer than this (a floor that can't be stood on, a stuck fall)
	local holdSince: number? = os.clock() -- (a spawn holds too)
	local held = false
	local freeSpeed: number? = nil -- the WalkSpeed to give back when no top speed is set (Roblox's own)
	local lastPos: Vector3? = nil
	player.CharacterAdded:Connect(function()
		holdSince, lastPos = os.clock(), nil
	end)
	local function feetFirst(h: Humanoid, dt: number): boolean
		local root = h.RootPart
		if not root then
			return false
		end
		local now = os.clock()
		local pos = root.Position
		if lastPos and (pos - lastPos).Magnitude > math.max(TELEPORT, root.AssemblyLinearVelocity.Magnitude * dt * 3) then
			holdSince = now -- (moved by the game, not by running)
		end
		lastPos = pos
		if holdSince then
			local onFloor = h.FloorMaterial ~= Enum.Material.Air
			if (onFloor and now - holdSince > 0.03) or now - holdSince > GIVE_UP or h.Sit then
				holdSince = nil
			end
		end
		local hold = holdSince ~= nil
		if hold ~= held then
			held = hold
			player:SetAttribute("HuzzFeetFirst", hold)
		end
		return hold
	end

	RunService.Heartbeat:Connect(function(dt)
		local character = player.Character
		local h = character and character:FindFirstChildOfClass("Humanoid")
		if not h then
			return
		end
		if feetFirst(h, dt) then
			if h.WalkSpeed > 0 then
				freeSpeed = h.WalkSpeed
				h.WalkSpeed = 0 -- (no steering in the air until the feet land)
			end
			speed = START
			return
		end
		local cap = h:GetAttribute("HuzzSpeed")
		if type(cap) ~= "number" and freeSpeed and h.WalkSpeed == 0 then
			h.WalkSpeed = freeSpeed -- (no top speed set yet: give Roblox's own back)
		end
		freeSpeed = nil
		if type(cap) ~= "number" then
			return -- (the server hasn't set a speed yet: leave Roblox's)
		end
		if h.MoveDirection.Magnitude > 0.1 then
			idle = 0
		else
			idle += dt
			if idle > GRACE then
				speed = START -- (stopped: the next start is a walk again)
			end
		end
		local want
		if cap <= START then
			want = cap
			speed = cap
		else
			if idle == 0 then
				-- ease out toward the top: quick to get going, then settling softly (no jolt at either end);
				-- a lower cap (carrying, slowed) is followed down just as smoothly
				speed += (cap - speed) * (1 - math.exp(-dt / TAU))
			end
			speed = math.clamp(speed, START, cap)
			want = speed
		end
		if math.abs(h.WalkSpeed - want) > 0.01 then
			h.WalkSpeed = want
		end
	end)
end

return M
