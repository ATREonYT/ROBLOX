-- The two round moves, played by the game's own code (Shared/StabMotion, Shared/CarryMotion.huss):
--   0-5 s   a catcher (red, knife in hand) chases a runner (blue): stabs and misses at 1.1 s, stabs and
--           hits at 2.6 s; the runner falls flat (Shared/DownMotion)
--   5-11 s  a runner carries her and hits two huss moves (5.6 s walking, 8.4 s standing): she flies up,
--           twirls, he flexes under her, then catches her
-- sh video.sh action_scene.luau out.mp4
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local CarryMath = Env.load(SHARED .. "CarryMath.lua")
local CarryMotion = Env.load(SHARED .. "CarryMotion.lua")
local StabMotion = Env.load(SHARED .. "StabMotion.lua")
local DownMotion = Env.load(SHARED .. "DownMotion.lua")
local Carry = Env.load(SHARED .. "Config/Carry.lua")

local FPS, DT, SECONDS = 30, 1 / 30, 11
local rad, sin, cos = math.rad, math.sin, math.cos

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

local function named(rig)
	rig.byName = {}
	for _, m in rig.motors do rig.byName[m.Name] = m end
	return rig
end

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
	M.RightWrist.Transform = CFrame.identity
	M.Waist.Transform = CFrame.identity
	M.Root.Transform = CFrame.new(0, -2.7 * (1 - cos(swing)) + 0.12 * math.abs(sin(phase)) * amount, 0)
end

local function mover(pos, facing)
	return { pos = pos, facing = facing, speed = 0, phase = 0 }
end
local function move(rig, m, target)
	m.speed += (target - m.speed) * math.min(1, DT * 5)
	local dir = Vector3.new(-sin(-m.facing), 0, -cos(-m.facing))
	m.pos += dir * m.speed * DT
	m.phase += m.speed * DT * 2 * math.pi / 5
	walkAnim(rig, m.phase, math.min(1, m.speed / 12))
	rig.root.CFrame = Rig.lookAt(m.pos + Vector3.new(0, Rig.REST_HEIGHT, 0), m.pos + Vector3.new(0, Rig.REST_HEIGHT, 0) + dir)
end

-- The knife as KnifeService builds it, held where KnifeService puts it (grip at the hand's grip point,
-- handle +Y turned 150 degrees round the hand's X: blade down and forward).
local function giveKnife(rig)
	local hand = rig.parts.RightHand
	local grip = CFrame.new(0, -0.15, 0) * CFrame.Angles(rad(-150), 0, 0)
	local dark, steel = "#201e26", "#cdd4e0"
	for _, b in {
		{ CFrame.new(0, 0, 0), Vector3.new(0.22, 0.75, 0.26), dark },
		{ CFrame.new(0, -0.42, 0), Vector3.new(0.26, 0.12, 0.3), steel },
		{ CFrame.new(0, 0.42, 0), Vector3.new(0.24, 0.1, 0.62), steel },
		{ CFrame.new(0, 0.995, 0.02), Vector3.new(0.07, 1.05, 0.3), steel },
		{ CFrame.new(0, 1.66, 0.08), Vector3.new(0.07, 0.3, 0.16), steel }, -- the tip (a box stands in for the wedge)
	} do
		table.insert(rig.decor, { part = hand, offset = grip * b[1], Size = b[2], Color = b[3] })
	end
end

local scene = Scene.new()
local catcher = named(scene:addRig(Rig.r15("Catcher", { shirt = "#e0453a", pants = "#2b2f3a" })))
local runner = named(scene:addRig(Rig.r15("Runner", { shirt = "#2f6fe0", pants = "#262a36" })))
local carrier = named(scene:addRig(Rig.r15("Carrier", { shirt = "#2f6fe0", pants = "#262a36" })))
local girl = named(scene:addRig(Rig.r15("Girl", { shirt = "#f06aa8", pants = "#3b2f5c", skin = "#f8dccb", hair = "#b88cf0", eyes = "#3a2350" })))
giveKnife(catcher)
scale(girl, Carry.GirlLength / 5.9)
local centre, size = bounds(girl)
local carryRig = CarryMath.rig(carrier)
local carry = Rig.motor("HuzzCarryMotor", carrier.parts.UpperTorso, girl.root, CarryMath.holdC0(carryRig, size.Z), centre)
local carryRec = CarryMotion.new({ motor = carry, rig = carryRig, root = carrier.root, girlMotors = girl.motors, start = -10, seed = 7 })
local stab = StabMotion.new(CarryMath.rig(catcher), catcher.root)
carrier.root.CFrame = CFrame.new(Vector3.new(200, Rig.REST_HEIGHT, 0))

-- Part two happens 200 studs away, so part one's actors stay out of shot.
local AWAY = Vector3.new(200, 0, 0)
local C = mover(Vector3.new(0, 0, 14), 0)
local R = mover(Vector3.new(1.2, 0, 0), 0)
local K = mover(AWAY, rad(90))
local HUSS = { 5.6, 8.4 }
local down, downFeet
local camPos
for f = 0, SECONDS * FPS - 1 do
	local t = f * DT
	if t < 5 then
		-- the chase
		if not down then
			move(runner, R, if t < 2.6 then 12 else 0)
		end
		move(catcher, C, if t < 2.8 then 15.5 else 0)
		for _, at in { 1.1, 2.6 } do
			if t >= at and t - DT < at then StabMotion.play(stab, t) end
		end
		StabMotion.step(stab, t)
		if t >= 2.6 + 0.19 and not down then -- the thrust lands
			down = DownMotion.new(runner.motors)
			local dir = Vector3.new(0, 0, -1)
			downFeet = Rig.lookAt(R.pos, R.pos + dir)
			walkAnim(runner, R.phase, 0)
		end
		if down then
			DownMotion.step(down, t - 2.79)
			runner.root.CFrame = DownMotion.rootCFrame(downFeet, Rig.REST_HEIGHT, t - 2.79)
		end
		Rig.fk(catcher)
		Rig.fk(runner)
		Rig.fk(carrier, { carry }, { girl })
		local target = Vector3.new(C.pos.X + 11, 4.5, C.pos.Z - 3)
		camPos = if camPos and t > DT then camPos:Lerp(target, 0.12) else target
		scene:frame(camPos, Vector3.new(C.pos.X, 2.6, C.pos.Z - 3))
	else
		-- the huss: walking at the first, standing still at the second
		move(carrier, K, if t < 7.2 then 8 else 0)
		local hussAge = nil
		for _, at in HUSS do
			if t >= at and t < at + Carry.Huss.Time then hussAge = t - at end
		end
		CarryMotion.step(carryRec, DT, t, "Calm", 99, hussAge)
		Rig.fk(carrier, { carry }, { girl })
		-- side-on while he walks, then from the front for the standing huss (to see his flex)
		local target = if t < 7.6 then K.pos + Vector3.new(-2, 6, -15) else K.pos + Vector3.new(14, 6, -4)
		camPos = if t - DT < 5 then target else camPos:Lerp(target, 0.12)
		scene:frame(camPos, K.pos + Vector3.new(0, 6.5, 0))
	end
end
scene:save(nil, FPS, 1280, 720)
