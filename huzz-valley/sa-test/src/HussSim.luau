--!strict
-- HussSim: the run build-up, the huss, the dive and the catch under Roblox's Server Authority (test place only:
-- huzz-valley/sa-test, owner Oct 21: "check the desync again ... run it on a server client so it works best").
-- The same code runs on the server (the truth) and on your screen (the guess ahead of it). When the server's answer
-- differs, Roblox rewinds your screen and replays this step, so it must give the same answer every time:
-- no wall clocks (only dt), no randomness, no new parts, no sounds or effects (SATestClient draws those).
-- Numbers come from the real game's Config/Round and Config/Run (copied in by sa-test/build.luau).
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("SATestConfig")
local Round = require(Config:WaitForChild("Round")) :: any
local Run = require(Config:WaitForChild("Run")) :: any

local HussSim = {}
HussSim.DOWN_TIME = 2 -- seconds a caught player stays down here (the real game keeps them down to the round's end)
HussSim.PUSH = "SAPush" -- the LinearVelocity the server puts on every root at spawn (the sim only sets its targets)

local UP = Vector3.yAxis
local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- The state of one character. It lives in attributes on the HumanoidRootPart, so it rewinds with everything else.
export type State = {
	HussAge: number, HussDir: Vector3, Side: number, -- -1 = no huss; the way it goes; the last side (1 right, -1 left)
	DiveAge: number, DiveDir: Vector3,
	Cd: number, -- seconds until Space or the dive works again (they share one cooldown, like the game's tile)
	Held: number, -- seconds of moving (the 1 s build-up to full speed)
	Down: number, -- seconds left lying caught
	PH: boolean, PD: boolean, -- last step's Huss and Dive buttons (a press is the step it goes down)
}
export type Input = { huss: boolean, dive: boolean, steer: Vector2, look: Vector3, speed: number }

local FIELDS = { "HussAge", "HussDir", "Side", "DiveAge", "DiveDir", "Cd", "Held", "Down", "PH", "PD" }
local START: State = {
	HussAge = -1, HussDir = Vector3.zero, Side = 1, DiveAge = -1, DiveDir = Vector3.zero,
	Cd = 0, Held = 0, Down = 0, PH = false, PD = false,
}
HussSim.START = START

function HussSim.fresh(): State
	return table.clone(START)
end

-- The push curves, the same as Shared/RunMotion's.
function HussSim.pushSpeed(cfg: any, age: number): number?
	if age < 0 or age >= cfg.Time then return nil end
	local u = 1 - age / cfg.Time
	local finish = cfg.EndSpeed or cfg.Speed
	return finish + (cfg.Speed - finish) * u ^ (cfg.Ease or 2)
end
function HussSim.diveSpeed(cfg: any, age: number): number?
	local v = HussSim.pushSpeed(cfg, age)
	if v or age < 0 then return v end
	local s = age - cfg.Time
	local slide = cfg.Slide or 0
	if s >= slide then return nil end
	return (cfg.EndSpeed or cfg.Speed) * (1 - s / slide) ^ 2
end
function HussSim.walkSpeed(held: number): number
	local start, cap = Run.StartSpeed or 16, Round.Speeds.Runner
	local p = math.clamp(held / (Run.Ramp or 1), 0, 1)
	return start + (cap - start) * (1 - (1 - p) ^ (Run.RampEase or 2))
end

-- The owner's step (the server for everyone, your screen for you): buttons into state.
function HussSim.ownerStep(s: State, inp: Input, dt: number)
	local D, L = Round.Dash, Round.Lunge
	if s.HussAge >= 0 then
		s.HussAge += dt
		if s.HussAge >= D.Time then s.HussAge = -1 end
	end
	if s.DiveAge >= 0 then
		s.DiveAge += dt
		if s.DiveAge >= L.Time + (L.Slide or 0) then s.DiveAge = -1 end
	end
	s.Cd = math.max(0, s.Cd - dt)
	s.Down = math.max(0, s.Down - dt)
	local busy = s.Down > 0 or s.HussAge >= 0 or s.DiveAge >= 0
	local look = flat(inp.look)
	if look.Magnitude > 1e-3 then look = look.Unit else look = Vector3.zero end
	if inp.huss and not s.PH and s.Cd <= 0 and not busy and look ~= Vector3.zero then
		-- left or right on your screen: A / D, or the side you went last (Gameplay/Dash)
		local side = if inp.steer.X > 0.3 then 1 elseif inp.steer.X < -0.3 then -1 else s.Side
		s.Side = side
		s.HussDir = look:Cross(UP) * side
		s.HussAge = 0
		s.Cd = D.Cooldown
	elseif inp.dive and not s.PD and s.Cd <= 0 and not busy and look ~= Vector3.zero then
		s.DiveDir = look
		s.DiveAge = 0
		s.Cd = L.Cooldown
	end
	s.Held = if inp.speed > 2 and s.Down <= 0 then math.min(s.Held + dt, Run.Ramp or 1) else 0
	s.PH, s.PD = inp.huss, inp.dive
end

-- Every screen's step, for every character: state into the push and the speed.
-- push: the flat velocity the LinearVelocity holds (nil = off, the Humanoid steers); kick: an upward speed this step.
function HussSim.drive(s: State, velocity: Vector3): (Vector3?, number?, number)
	if s.Down > 0 then
		return Vector3.zero, nil, 0
	end
	local walk = HussSim.walkSpeed(s.Held)
	if s.HussAge >= 0 then
		local v = HussSim.pushSpeed(Round.Dash, s.HussAge)
		if v then
			-- keep whatever run you had across the huss, as the game does
			local f = flat(velocity)
			local run = f - s.HussDir * f:Dot(s.HussDir)
			return s.HussDir * v + run, nil, walk
		end
	end
	if s.DiveAge >= 0 then
		local v = HussSim.diveSpeed(Round.Lunge, s.DiveAge)
		if v then
			return s.DiveDir * v, if s.DiveAge == 0 then Round.Lunge.Up else nil, walk
		end
	end
	return nil, nil, walk
end

-- Does a diver at `from` (state d) catch the body at `to` (state v)? Within the dive's hit window and reach.
function HussSim.catches(d: State, from: Vector3, v: State, to: Vector3): boolean
	local L = Round.Lunge
	if d.DiveAge < 0 or d.DiveAge > L.HitWindow or v.Down > 0 then return false end
	local gap = to - from
	return math.abs(gap.Y) < 6 and flat(gap).Magnitude <= L.HitRange
end

-- Attributes <-> state.
function HussSim.read(root: BasePart): State
	local s = HussSim.fresh() :: any
	for _, k in FIELDS do
		local v = root:GetAttribute(k)
		if v ~= nil then s[k] = v end
	end
	return s
end
function HussSim.write(root: BasePart, s: State)
	local t = s :: any
	for _, k in FIELDS do
		if root:GetAttribute(k) ~= t[k] then root:SetAttribute(k, t[k]) end
	end
end

-- Camera and buttons, from the InputContext the server gave each player (SATestServer).
local function action(player: Player, name: string): any
	local ctx = player:FindFirstChild("HussContext")
	local a = ctx and ctx:FindFirstChild(name)
	return a and (a :: any):GetState()
end
local function inputOf(player: Player, root: BasePart): Input
	local look = action(player, "CameraDir")
	local steer = action(player, "Steer")
	return {
		huss = action(player, "Huss") == true,
		dive = action(player, "Dive") == true,
		steer = if typeof(steer) == "Vector2" then steer else Vector2.zero,
		look = if typeof(look) == "Vector3" then look else root.CFrame.LookVector,
		speed = flat(root.AssemblyLinearVelocity).Magnitude,
	}
end

local warned = false
function HussSim.Initialize()
	local isServer = RunService:IsServer()
	local me = Players.LocalPlayer
	local function step(dt: number)
		local bodies = {}
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = humanoid and humanoid.RootPart
			if root then
				local s = HussSim.read(root)
				local owner = isServer or player == me
				if owner then
					HussSim.ownerStep(s, inputOf(player, root), dt)
				end
				table.insert(bodies, { player = player, root = root, humanoid = humanoid, s = s, owner = owner })
			end
		end
		-- the catch: written by whoever owns the caught body (the server, and the caught player's own screen)
		for _, d in bodies do
			for _, v in bodies do
				if d ~= v and v.owner and HussSim.catches(d.s, d.root.Position, v.s, v.root.Position) then
					v.s.Down = HussSim.DOWN_TIME
					v.s.HussAge, v.s.DiveAge = -1, -1
				end
			end
		end
		for _, b in bodies do
			if b.owner then HussSim.write(b.root, b.s) end
			local push, kick, walk = HussSim.drive(b.s, b.root.AssemblyLinearVelocity)
			local lv = b.root:FindFirstChild(HussSim.PUSH) :: LinearVelocity?
			if lv then
				lv.Enabled = push ~= nil
				if push then lv.PlaneVelocity = Vector2.new(push.X, push.Z) end
			end
			if kick then
				local v = b.root.AssemblyLinearVelocity
				b.root.AssemblyLinearVelocity = Vector3.new(v.X, kick, v.Z)
			end
			local ok, err = pcall(function() b.humanoid.WalkSpeed = walk end)
			if not ok and not warned then
				warned = true
				task.defer(warn, "[SATest] WalkSpeed can't be set in the simulation here: " .. tostring(err))
			end
		end
	end
	-- one tagged line if a step ever fails (no red box), then it keeps trying
	local failedOnce = false
	RunService:BindToSimulation(function(dt: number)
		local ok, err = pcall(step, dt)
		if not ok and not failedOnce then
			failedOnce = true
			task.defer(warn, "[SATest] simulation step failed (" .. (if isServer then "server" else "your screen") .. "): " .. tostring(err))
		end
	end, Enum.StepFrequency.Hz60)
end

return HussSim
