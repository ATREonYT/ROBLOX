--[[
	Walk first, then run (owner: "make the animations slowly fade in from walking when you press W to running
	if you continue holding it, just like in the references"). When you start moving you set off at a walk
	and build up to your full speed (the server's HuzzSpeed on your Humanoid, RoundService) in exactly Config/Run
	Ramp seconds (owner, Oct 20 07:55: "Make acceleration 1 second long"; Shared/RunMotion.rampSpeed, easing out: the
	quickest gain at the start, settling softly into the top); let go for a moment and the next start is a walk
	again. Gameplay/Locomotion cross-fades the owner's Walk into their Run by speed, so the legs follow the build-up
	on their own.
	The halt (same message: "after they randomly stop after fully running they move a little forward as a sort of
	"hault" like in the game Huss valley"): let go of every key while running at Config/Run.Halt.From of your top
	speed or more and you carry on ~2.3 studs, slowing to a stand over Halt.Time (Shared/Halt moves the real body:
	walls, the server and every screen see it). Pressing any direction ends it at once (turning round is never a
	halt: the new key takes over), and so do a huss or a dive, being downed or frozen (HuzzSpeed at or under the
	walk), sitting or leaving the floor. The local attribute HuzzHalt on your character says it's on, so
	Gameplay/Locomotion and Gameplay/PlayerMoves plant the legs (a skid, not a run).
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

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Run = require(Shared.Config.Run)
	local RunMotion = require(Shared.RunMotion)
	local Halt = require(Shared.Halt)
	local RAMP = Run.Ramp or 1 -- seconds from a walk to full speed
	local START = Run.StartSpeed or 16 -- studs a second you set off at
	local GRACE = 0.18 -- seconds you can let go (a quick turn) and keep your speed
	local CAP_EASE = 0.15 -- seconds: once built up, a new top speed (a boost, carrying, slowed) is followed this softly

	local player = Players.LocalPlayer
	local idle = math.huge
	local speed = START -- the speed being built up
	local built = 0 -- seconds of the build so far (RunMotion.rampSpeed)
	local lastRun = Vector3.zero -- your ground velocity on the last frame a key was held (the halt starts from it:
	-- by the first frame after letting go, Roblox's Humanoid has already braked)
	local stopHalt: (() -> ())? = nil

	-- The halt: on the first frame with no key after a full run.
	local function busy(character: Model, h: Humanoid, root: BasePart): boolean
		return h.Sit or h.PlatformStand or root.Anchored or h.FloorMaterial == Enum.Material.Air
			or character:GetAttribute("DownedAt") ~= nil
			or root:FindFirstChild("HuzzDash") ~= nil or root:FindFirstChild("HuzzLunge") ~= nil
	end
	local function tryHalt(character: Model, h: Humanoid, cap: number)
		local root = h.RootPart
		if stopHalt or not root or not RunMotion.haltFrom(lastRun.Magnitude, cap, START) or busy(character, h, root) then
			return
		end
		character:SetAttribute("HuzzHalt", true)
		stopHalt = Halt.start(root, lastRun, lastRun.Magnitude, function()
			local top = h:GetAttribute("HuzzSpeed")
			return h.Parent ~= nil and h.MoveDirection.Magnitude <= 0.1 and type(top) == "number" and top > START
				and h.WalkSpeed > 0 and not busy(character, h, root)
		end, function()
			stopHalt = nil
			character:SetAttribute("HuzzHalt", nil)
		end)
	end

	-- Feet first: held from a spawn or a teleport until the feet touch the floor.
	local TELEPORT = 12 -- studs in one frame (faster than any run, huss or leap moves you) = the game moved you
	local GIVE_UP = 3 -- seconds: never hold longer than this (a floor that can't be stood on, a stuck fall)
	local holdSince: number? = os.clock() -- (a spawn holds too)
	local held = false
	local freeSpeed: number? = nil -- the WalkSpeed to give back when no top speed is set (Roblox's own)
	local lastPos: Vector3? = nil
	player.CharacterAdded:Connect(function()
		holdSince, lastPos = os.clock(), nil
		if stopHalt then
			stopHalt()
		end
		lastRun, built = Vector3.zero, 0
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
			speed, built, lastRun = START, 0, Vector3.zero
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
		local root = h.RootPart
		if h.MoveDirection.Magnitude > 0.1 then
			if stopHalt then
				stopHalt() -- (a key again: the halt ends, the run carries on from where it was)
			end
			idle = 0
			if root then
				local v = root.AssemblyLinearVelocity
				lastRun = Vector3.new(v.X, 0, v.Z)
			end
		else
			if idle == 0 then
				tryHalt(character, h, cap) -- (just let go: a halt if you were at full speed)
			end
			idle += dt
			lastRun = Vector3.zero
			if idle > GRACE then
				speed, built = START, 0 -- (stopped: the next start is a walk again)
			end
		end
		local want
		if cap <= START then
			want = cap
			speed, built = cap, 0
		else
			if idle == 0 then
				-- from the walk to the top in exactly RAMP seconds, easing out (no jolt at either end)
				built += dt
				local target = RunMotion.rampSpeed(START, cap, built)
				if built < RAMP then
					speed = target
				else
					speed += (target - speed) * (1 - math.exp(-dt / CAP_EASE)) -- (a new top speed, followed softly)
				end
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
