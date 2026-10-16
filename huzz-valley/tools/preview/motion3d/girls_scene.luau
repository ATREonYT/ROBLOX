-- The girl animations, run through the game's own code (CarryMotion, GirlMotion, CarryMath):
--   0-2 s   she stands in the middle; a runner walks up to her (she watches him)
--   ~2 s    he reaches her: she's picked up and flies into his hands
--   2-12 s  carry: walk, turn, hard stop, stand, run, stand
-- sh video.sh girls_scene.luau out.mp4      (ORBIT=1: he holds her standing still and the camera circles)
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local CarryMath = Env.load(SHARED .. "CarryMath.lua")
local CarryMotion = Env.load(SHARED .. "CarryMotion.lua")
local GirlMotion = Env.load(SHARED .. "GirlMotion.lua")
local Carry = Env.load(SHARED .. "Config/Carry.lua")
local Round = Env.load(SHARED .. "Config/Round.lua")

local ORBIT = process.env.ORBIT ~= nil
local FPS, DT, SECONDS = 30, 1 / 30, 12
local rad, sin, cos = math.rad, math.sin, math.cos
local GIRL = { shirt = "#f06aa8", pants = "#3b2f5c", skin = "#f8dccb", hair = "#b88cf0", eyes = "#3a2350" }

-- Scales a mock rig like Model:ScaleTo.
local function scale(rig, k)
	for _, p in rig.parts do p.Size *= k end
	for _, m in rig.motors do
		m.C0 = CFrame.new(m.C0.Position * k) * m.C0.Rotation
		m.C1 = CFrame.new(m.C1.Position * k) * m.C1.Rotation
	end
	for _, d in rig.decor do
		d.offset = CFrame.new(d.offset.Position * k) * d.offset.Rotation
		d.Size *= k
	end
	Rig.fk(rig)
end

-- Bounding-box centre in the root's space, and the box size (as Model:GetBoundingBox).
local function bounds(rig)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), -Vector3.new(math.huge, math.huge, math.huge)
	for _, p in rig.parts do
		if not p.hidden then
			local c = rig.root.CFrame:PointToObjectSpace(p.CFrame.Position)
			lo, hi = lo:Min(c - p.Size / 2), hi:Max(c + p.Size / 2)
		end
	end
	return CFrame.new((lo + hi) / 2), hi - lo
end

-- A simple walk cycle standing in for Roblox's (or the owner's huss) walk animation.
local function walkAnim(rig, phase, amount)
	local M = rig.byName
	local swing = rad(32) * sin(phase) * amount
	M.RightHip.Transform = CFrame.Angles(swing, 0, 0)
	M.LeftHip.Transform = CFrame.Angles(-swing, 0, 0)
	M.RightKnee.Transform = CFrame.Angles(-rad(50) * math.max(0, -sin(phase)) * amount, 0, 0)
	M.LeftKnee.Transform = CFrame.Angles(-rad(50) * math.max(0, sin(phase)) * amount, 0, 0)
	M.RightShoulder.Transform = CFrame.Angles(-swing * 0.9, 0, 0)
	M.LeftShoulder.Transform = CFrame.Angles(swing * 0.9, 0, 0)
	M.RightElbow.Transform = CFrame.Angles(rad(20) * amount, 0, 0)
	M.LeftElbow.Transform = CFrame.Angles(rad(20) * amount, 0, 0)
	M.Root.Transform = CFrame.new(0, -2.7 * (1 - cos(swing)) + 0.12 * math.abs(sin(phase)) * amount, 0)
end

local function named(rig)
	rig.byName = {}
	for _, m in rig.motors do rig.byName[m.Name] = m end
	return rig
end

local scene = Scene.new()
local carrier = named(scene:addRig(Rig.r15("Carrier", { shirt = "#2f6fe0", pants = "#262a36" })))
local girl = named(scene:addRig(Rig.r15("Girl", GIRL)))
scale(girl, Carry.GirlLength / 5.9)
local centre, size = bounds(girl)
local standHeight = girl.root.CFrame.Position.Y
scene:addBox(CFrame.new(0, -0.45, 0), Vector3.new(24, 1, 24), "#ff8a8a") -- the Middle zone

-- She stands in the middle facing +Z, where the runner comes from.
girl.root.CFrame = CFrame.new(0, standHeight, 0) * CFrame.Angles(0, math.pi, 0)
Rig.fk(girl)
local idleState, idleJoints = GirlMotion.new(3), GirlMotion.joints(girl.motors)

local carry = Rig.motor("HuzzCarryMotor", carrier.parts.UpperTorso, girl.root, CarryMath.holdC0(CarryMath.rig(carrier), size.Z), centre)
local rec = nil
local carrierPos = if ORBIT then Vector3.new(1.5, 0, 2) else Vector3.new(1.5, 0, 22)
local facing = 0 -- radians, 0 = walking toward -Z
local speed, phase, camPos = 0, 0, nil

for f = 0, SECONDS * FPS - 1 do
	local t = f * DT
	-- Path: walk up to her, grab her in passing, keep going, turn, hard stop, stand, run, stand
	local target = 0
	if not ORBIT then
		if t < 5.5 then target = 14 elseif t > 7.2 and t < 10.4 then target = 20 end
		if t > 3.6 and t < 5.2 then facing -= DT * 1.1 end
		if t > 8.2 and t < 9.2 then facing += DT * 1.4 end
	end
	if not ORBIT and t >= 5.5 and t < 5.65 then speed = 0 else speed += (target - speed) * math.min(1, DT * 5) end
	local dir = Vector3.new(-sin(-facing), 0, -cos(-facing))
	carrierPos += dir * speed * DT
	phase += speed * DT * 2 * math.pi / 5
	walkAnim(carrier, phase, math.min(1, speed / 12))
	carrier.root.CFrame = Rig.lookAt(carrierPos + Vector3.new(0, Rig.REST_HEIGHT, 0), carrierPos + Vector3.new(0, Rig.REST_HEIGHT, 0) + dir)

	-- The grab, as in RoundService.step: the first runner within GrabRange of her centre.
	local girlCentre = (girl.root.CFrame * centre).Position
	if not rec and (ORBIT and t > 1 or (carrier.root.CFrame.Position - girlCentre).Magnitude <= 6) then -- (the old grab range)
		for _, m in girl.motors do m.Transform = CFrame.identity end
		rec = CarryMotion.new({
			motor = carry, rig = CarryMath.rig(carrier), root = carrier.root, girlMotors = girl.motors,
			start = t, from = girlCentre, seed = 7,
		})
		print(string.format("grabbed at %.2f s", t))
	end
	if rec then
		CarryMotion.step(rec, DT, t, "Calm", 99)
		Rig.fk(carrier, { carry }, { girl })
	else
		Rig.fk(carrier)
		local head = carrier.parts.Head.CFrame.Position
		GirlMotion.idle(idleState, idleJoints, DT, t, { target = head, distance = (head - girlCentre).Magnitude })
		Rig.fk(girl)
	end

	-- Camera: behind and a little to the left, low, like the reference video
	local back = CFrame.Angles(0, -facing + rad(-25), 0).LookVector * -12
	local camTarget = carrierPos + back + Vector3.new(0, 5, 0)
	camPos = if camPos then camPos:Lerp(camTarget, 0.12) else camTarget
	if ORBIT then
		camPos = carrierPos + CFrame.Angles(0, t * 2 * math.pi / SECONDS, 0):VectorToWorldSpace(Vector3.new(0, 4, 11))
	end
	scene:frame(camPos, carrierPos + Vector3.new(0, 5, 0))
end
scene:save(nil, FPS, 1280, 720)
