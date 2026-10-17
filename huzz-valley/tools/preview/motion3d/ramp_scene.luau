-- Your own walk, run, huss and jump exactly as the game blends them (Gameplay/Locomotion runs Shared/LocomotionMix;
-- this runs the same module on the owner's animations from src/ServerStorage/HuzzAnimations.rbxm), filmed from
-- behind and a little above, like Huss Valley's camera:
--   0-1 s     standing (Idle)
--   1-6.6 s   holding W: Gameplay/Sprint builds the speed from Run.StartSpeed to the runner's 24 over Run.Ramp, the
--             walk cross-fading into the run; a turn left then right (the lean into turns)
--   3.8 s     huss right, 5.1 s huss left (DashRight / DashLeft over the run, the sideways push of Config/Round)
--   6.6-8 s   let go: the run fades back to a stand (a little lean back)
--   8.3 s     a jump in place (Jump, then Fall, landing back into Idle)
-- sh video.sh ramp_scene.luau out.mp4      (HUSS_ONLY=1: just the two husses, for stills)
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local KFS = require("./kfs")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local Run = Env.load(SHARED .. "Config/Run.lua")
local Round = Env.load(SHARED .. "Config/Round.lua")
local Mix = Env.load(SHARED .. "LocomotionMix.lua")

local lib = roblox.Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile("huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do inst.Parent = lib end
local A = {}
for _, name in { "Idle", "Walk", "Run", "Jump", "Fall", "Climb", "DashLeft", "DashRight" } do
	A[name] = KFS.load(lib:FindFirstChild(name, true))
end

local scene = Scene.new()
local rig = scene:addRig(Rig.r15("Runner", { shirt = "#1d1f2a", pants = "#15161d", hair = "#2a1a10" }))
-- ground markers every 4 studs (and two side rows) so speed and sideways moves show
for i = -4, 70 do
	for _, x in { -12, -6, 0, 6, 12 } do
		scene:addBox(CFrame.new(x, 0.03, -i * 4), Vector3.new(0.5, 0.06, 0.5), "#6f9a52")
	end
end

local FPS, DT, SECONDS = 30, 1 / 30, 10
local CAP, START, RAMP = 24, Run.StartSpeed, Run.Ramp
local HIP = Rig.REST_HEIGHT - 1 -- (Humanoid.HipHeight of the preview rig: root part bottom to the ground)
local function smooth(u) u = math.clamp(u, 0, 1) return u * u * (3 - 2 * u) end

local mix = Mix.new()
local pos, yaw, speed, held = Vector3.new(0, 0, 0), 0, 0, 0
local y, vy, airborne, jumpedAt = 0, 0, false, nil
local dash = nil -- { at, side, name }
local DASHES = if process.env.HUSS_ONLY then { [1.0] = 1, [2.2] = -1 } else { [3.8] = 1, [5.1] = -1 }
local holdFrom, holdTo = if process.env.HUSS_ONLY then 0 else 1, if process.env.HUSS_ONLY then 99 else 6.6
local push = nil -- { untilT, vel }
local idleT, jumpT, fallT, climbT = 0, 0, 0, 0
local root = rig.parts.LowerTorso.joints.Root

for f = 0, SECONDS * FPS - 1 do
	local t = f * DT
	-- input: hold W, turn a little, huss, let go, jump
	local holding = t >= holdFrom and t < holdTo
	held = if holding then held + DT else 0
	local turn = if not process.env.HUSS_ONLY and t > 2.2 and t < 3.2 then 1.1 elseif not process.env.HUSS_ONLY and t > 5.8 and t < 6.5 then -1.3 else 0
	yaw += turn * DT
	local want = if holding then START + (CAP - START) * smooth(held / RAMP) else 0 -- (Gameplay/Sprint)
	speed += (want - speed) * (1 - math.exp(-DT * (if holding then 30 else 18))) -- (the Humanoid's acceleration)
	local look = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
	local right = Vector3.new(math.cos(yaw), 0, -math.sin(yaw))
	for at, side in DASHES do
		if math.abs(t - at) < DT / 2 then
			dash = { at = t, side = side, name = if side > 0 then "DashRight" else "DashLeft" }
			push = { untilT = t + Round.Dash.Time, vel = right * side * Round.Dash.Speed + look * speed } -- (Gameplay/Dash)
		end
	end
	local vel = look * speed
	if push and t < push.untilT then vel = push.vel end
	pos += vel * DT
	if not process.env.HUSS_ONLY and math.abs(t - 8.3) < DT / 2 then
		airborne, vy, jumpedAt = true, 50, t
	end
	local state = "ground"
	if airborne then
		vy -= 196.2 * DT
		y += vy * DT
		if y <= 0 then y, vy, airborne = 0, 0, false end
		state = if vy > 0 and t - jumpedAt < 0.1 then "jump" else "fall"
	end

	-- the blend, exactly as Gameplay/Locomotion asks for it
	Mix.step(mix, DT, {
		speed = Vector3.new(vel.X, 0, vel.Z).Magnitude, state = state, jumped = jumpedAt ~= nil and math.abs(t - jumpedAt) < DT / 2,
		lengths = { Walk = A.Walk.length, Run = A.Run.length },
	})
	idleT += DT
	jumpT = if jumpedAt and math.abs(t - jumpedAt) < DT / 2 then 0 else jumpT + DT
	fallT += DT
	-- Roblox blends tracks of one priority by weight: lerp each in by its share of the weight so far
	local total = 0
	local function layer(anim, at, w)
		if w <= 1e-4 then return end
		total += w
		KFS.apply(anim, rig, at, w / total)
	end
	layer(A.Idle, idleT, mix.weights.Idle)
	layer(A.Walk, mix.times.Walk, mix.weights.Walk)
	layer(A.Run, mix.times.Run, mix.weights.Run)
	layer(A.Jump, jumpT, mix.weights.Jump)
	layer(A.Fall, fallT, mix.weights.Fall)
	-- the huss on top (Action priority), faded in 0.04 s and handed back over the last 0.12 s (Gameplay/Dash)
	local quiet = 0
	if dash then
		local anim = A[dash.name]
		local age = t - dash.at
		if age <= anim.length then
			local w = math.min(1, age / 0.04, (anim.length - age) / 0.12)
			KFS.apply(anim, rig, age, math.clamp(w, 0, 1))
			quiet = 1
		else
			dash = nil
		end
	end
	-- the lean on top (Gameplay/Locomotion)
	local roll, pitch = Mix.lean(mix, DT, yaw, if state ~= "ground" then 1 else quiet)
	root.Transform = root.C0:Inverse() * Mix.leanCFrame(roll, pitch, 1 + HIP) * root.C0 * root.Transform

	rig.root.CFrame = CFrame.new(pos + Vector3.new(0, Rig.REST_HEIGHT + y, 0)) * CFrame.Angles(0, yaw, 0)
	Rig.fk(rig)
	-- camera: behind and a little above, like Huss Valley's (follows, eased)
	local camAt = pos - look * 8 + Vector3.new(0, 4.2 + y * 0.7, 0) + right * 0.5
	scene:frame(camAt, pos + Vector3.new(0, 2.4 + y * 0.7, 0) + look * 3)
end
scene:save(nil, FPS, 1280, 720, { sky = "#9fd3f7", ground = "#3fbf4f" })
