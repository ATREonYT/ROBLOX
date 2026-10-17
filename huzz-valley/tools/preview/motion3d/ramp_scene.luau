-- Your own walk, run and huss exactly as the game does them (Gameplay/Locomotion runs Shared/LocomotionMix on the
-- owner's animations from src/ServerStorage/HuzzAnimations.rbxm; Gameplay/Sprint's speed build; Gameplay/Dash's
-- eased push, Shared/RunMotion.pushSpeed; the huss pose drawn over the pack run by Shared/RunMotion, as
-- Gameplay/RunAnimator does for you; Gameplay/Feel's speed lines, Shared/RunMotion.hussLines), filmed with the round camera
-- Gameplay/Cinematic hands back (Shared/CinematicShot: 12 studs back, 14 degrees down, over the right shoulder):
--   0-1 s     standing (Idle)
--   1-6.6 s   holding W: Gameplay/Sprint sets off at Run.StartSpeed and builds to the runner's speed over Run.Ramp,
--             the walk cross-fading into the run; a turn left then right (the lean into turns)
--   3.8 s     huss right, 5.1 s huss left
--   6.6-8 s   let go: the run fades back to a stand (a little lean back)
-- sh video.sh ramp_scene.luau out.mp4      (HUSS_ONLY=1: running from the start, husses at 1.0 s and 2.2 s, for the
-- frame-by-frame sheet against Huss Valley: tools/preview/motion3d/huss_sheet.py)
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
local RunMotion = Env.load(SHARED .. "RunMotion.lua")
local Shot = Env.load(SHARED .. "CinematicShot.lua")
local HUSS_ONLY = process.env.HUSS_ONLY ~= nil

local lib = roblox.Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile("huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do inst.Parent = lib end
local A = {}
for _, name in { "Idle", "Walk", "Run" } do
	A[name] = KFS.load(lib:FindFirstChild(name, true))
end

local scene = Scene.new()
local rig = scene:addRig(Rig.r15("Runner", { shirt = "#1d1f2a", pants = "#15161d", hair = "#2a1a10" }))
local huss = RunMotion.new(rig)
-- ground markers every 4 studs (and side rows) so speed and sideways moves show
for i = -4, 90 do
	for _, x in { -18, -12, -6, 0, 6, 12, 18 } do
		scene:addBox(CFrame.new(x, 0.03, -i * 4), Vector3.new(0.5, 0.06, 0.5), "#6f9a52")
	end
end

local FPS, DT = 30, 1 / 30
local SECONDS = if HUSS_ONLY then 3.4 else 8
local CAP, START, TAU = Round.Speeds.Runner, Run.StartSpeed, Run.Ramp / 3
local HIP = Rig.REST_HEIGHT - 1 -- (Humanoid.HipHeight of the preview rig: root part bottom to the ground)
local LINES = Run.Dash.Lines

local mix = Mix.new()
local pos, yaw, speed, held, built = Vector3.new(0, 0, 0), 0, 0, 0, START
local dash = nil -- { at, side }
local DASHES = if HUSS_ONLY then { [1.0] = 1, [2.2] = -1 } else { [3.8] = 1, [5.1] = -1 }
local holdFrom, holdTo = if HUSS_ONLY then 0 else 1, if HUSS_ONLY then 99 else 6.6
local push = nil -- { at, dir, carry }
local idleT = 0
local root = rig.parts.LowerTorso.joints.Root
local fov = 70

for f = 0, SECONDS * FPS - 1 do
	local t = f * DT
	-- input: hold W, turn a little, huss, let go
	local holding = t >= holdFrom and t < holdTo
	if holding and held == 0 then built = START end
	held = if holding then held + DT else 0
	local turn = if not HUSS_ONLY and t > 2.2 and t < 3.2 then 1.1 elseif not HUSS_ONLY and t > 5.8 and t < 6.5 then -1.3 else 0
	yaw += turn * DT
	-- Gameplay/Sprint: from StartSpeed, easing out to the cap (95% after Run.Ramp)
	if holding then built += (CAP - built) * (1 - math.exp(-DT / TAU)) end
	local want = if holding then built else 0
	speed += (want - speed) * (1 - math.exp(-DT * (if holding then 30 else 18))) -- (the Humanoid's acceleration)
	local look = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
	local right = Vector3.new(math.cos(yaw), 0, -math.sin(yaw))
	for at, side in DASHES do
		if math.abs(t - at) < DT / 2 then
			dash = { at = t, side = side }
			push = { at = t, dir = right * side, carry = look * speed } -- (Gameplay/Dash: sideways, keeping the run)
		end
	end
	local vel = look * speed
	if push then
		local v = RunMotion.pushSpeed(Round.Dash, t - push.at)
		if v then vel = push.dir * v + push.carry else push = nil end
	end
	pos += vel * DT

	-- the blend, exactly as Gameplay/Locomotion asks for it
	Mix.step(mix, DT, {
		speed = Vector3.new(vel.X, 0, vel.Z).Magnitude, state = "ground", jumped = false,
		lengths = { Walk = A.Walk.length, Run = A.Run.length },
	})
	idleT += DT
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
	-- the huss on top (Gameplay/RunAnimator: your run is the pack's, so only the huss is drawn, speed 0)
	local age = if dash then t - dash.at else nil
	RunMotion.step(huss, DT, 0, true, false, age, if dash then Vector3.new(dash.side, 0, 0) else nil)
	-- the lean on top (Gameplay/Locomotion; held still through a huss)
	local quiet = if age and age < Run.Dash.Length + 0.1 then 1 else 0
	local roll, pitch = Mix.lean(mix, DT, yaw, quiet)
	root.Transform = root.C0:Inverse() * Mix.leanCFrame(roll, pitch, 1 + HIP) * root.C0 * root.Transform

	rig.root.CFrame = CFrame.new(pos + Vector3.new(0, Rig.REST_HEIGHT, 0)) * CFrame.Angles(0, yaw, 0)
	Rig.fk(rig)

	-- the speed lines (Gameplay/Feel draws Shared/RunMotion.hussLines as Beams riding with you)
	local ribbons = {}
	local lines = if dash then RunMotion.hussLines(rig.root.CFrame, right * dash.side, t - dash.at) else nil
	for _, l in lines or {} do
		table.insert(ribbons, { pts = { { l.from.X, l.from.Y, l.from.Z }, { l.to.X, l.to.Y, l.to.Z } },
			w = { LINES.Width, LINES.Width * 0.7 }, a = { l.alpha, l.alpha * 0.25 }, c = "#ffffff" })
	end

	-- camera: the round camera (Shared/CinematicShot.behind), shift lock over the right shoulder; Gameplay/Feel adds
	-- up to 2 degrees of field of view at full sprint and holds it through a huss
	local focus = rig.root.CFrame.Position + Vector3.new(0, Shot.FocusHeight, 0) + right * 1.75
	local eye, at = Shot.behind(look, focus)
	local sprint = math.clamp((speed - Run.From) / math.max(CAP - Run.From, 4), 0, 1) ^ 1.4
	fov += (70 + 2 * sprint - fov) * (1 - math.exp(-DT * (if 70 + 2 * sprint > fov then 10 else 4)))
	scene:frame(eye, at, { ribbons = ribbons, fov = fov })
end
scene:save(nil, FPS, 1280, 720, { sky = "#9fd3f7", ground = "#3fbf4f" })
