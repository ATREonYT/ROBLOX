-- Another player seen over a jumpy network, before and after the Oct 18 fix (owner: "player to player less choppy",
-- "make the walking animations way way better"). Both bodies move along the SAME bursty positions (Roblox's
-- interpolation delay wobbling and two short network stalls with a catch-up), so only the legs differ:
--   left  BEFORE (what other players looked like in Studio): Shared/RunMotion's scripted run driven by the speed
--         read frame to frame (the jumpy replicated velocity), nothing at walking pace (their Studio-only walk
--         doesn't reach other screens);
--   right NOW: Gameplay/PlayerMoves' maths: the owner's pack (Idle/Walk/Run) by hand, the speed from
--         LocomotionMix.track and the blend's spring, Config/Run.Loco's planted-feet numbers.
--   0-1 s stand, 1-4 s slow walk (5 studs/s, a light thumbstick), 4-8 s hold W (16 -> 28 in ~0.5 s), 8-9 s stop.
-- Then 9-12 s: the NOW body alone from behind (HV's camera: 12 studs, 14 degrees down) setting off from standing
-- (W pressed at 10.0 s), for the side by side with Huss Valley's set-off (docs/previews/walk-vs-hv.jpg).
-- sh video.sh remote_walk_scene.luau out.mp4   (STILLS=1 with MOTION3D_KEEP=dir keeps the set-off frames)
local process = require("@lune/process")
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local KFS = require("./kfs")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local Mix = Env.load(SHARED .. "LocomotionMix.lua")
local RunMotion = Env.load(SHARED .. "RunMotion.lua")
local Run = Env.load(SHARED .. "Config/Run.lua")
local Round = Env.load(SHARED .. "Config/Round.lua")

local lib = roblox.Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile("huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do inst.Parent = lib end
local folder = lib:FindFirstChild("HuzzAnimations")
local A = {}
for _, name in { "Idle", "Walk", "Run" } do A[name] = KFS.load(folder:FindFirstChild(name)) end
local lengths = { Walk = A.Walk.length, Run = A.Run.length }

local scene = Scene.new()
for i = -4, 40 do -- ground dots every 4 studs, so foot sliding shows
	for j = -3, 3 do scene:addBox(CFrame.new(j * 4, 0.03, -i * 4), Vector3.new(0.4, 0.06, 0.4), "#b9a06a") end
end
local before = scene:addRig(Rig.r15("Before", { shirt = "#8a8f9c", pants = "#454a55" }))
local now = scene:addRig(Rig.r15("Now", { shirt = "#e0453a", pants = "#2b2f3a" }))
local K = Rig.REST_HEIGHT / Run.Loco.RootHeight -- (the preview body's size, as PlayerMoves reads it)

-- the true path: speed by time (Gameplay/Sprint's ramp while W is held)
local SIM, FPS = 60, 30
local SECONDS = 12
local function want(t)
	if t < 1 then return 0 elseif t < 4 then return 5 elseif t < 8 then return Round.Speeds.Runner else return 0 end
end
local trueZ, speedNow = {}, 0
do
	local z, v = 0, 0
	for f = 0, 9 * SIM do
		local t = f / SIM
		local target = want(t)
		if target == 0 then v = 0
		elseif target <= 5 then v += (target - v) * (1 - math.exp(-(1 / SIM) / 0.08))
		else
			if v < Run.StartSpeed then v = Run.StartSpeed end
			v += (target - v) * (1 - math.exp(-(1 / SIM) / (Run.Ramp / 3)))
		end
		z -= v / SIM
		trueZ[f] = z
	end
end
-- what this screen sees: the path delayed by Roblox's interpolation (~0.1 s, wobbling), with two stalls (no update
-- for 0.12 s, then a quick catch-up) at 2.6 s and 6.1 s
local function delay(t)
	local d = 0.1 + 0.025 * math.sin(t * 7.3) + 0.015 * math.sin(t * 19.1 + 1)
	for _, s in { 2.6, 6.1 } do
		local u = t - s
		if u > 0 and u < 0.12 then d += u -- (frozen)
		elseif u >= 0.12 and u < 0.22 then d += 0.12 * (1 - (u - 0.12) / 0.1) end -- (catching up)
	end
	return d
end
local function seenZ(f)
	local t = math.max(f / SIM - delay(f / SIM), 0)
	local i = math.floor(t * SIM)
	local a = trueZ[math.min(i, #trueZ)] or 0
	local b = trueZ[math.min(i + 1, #trueZ)] or a
	return a + (b - a) * (t * SIM - i)
end

-- BEFORE: RunMotion fed the frame-to-frame speed
local recB = assert(RunMotion.new(before), "rig")
-- NOW: PlayerMoves' maths
local mix, tracker = Mix.new(Mix.sized(Run.Loco, K)), Mix.tracker(Run.Track)
local idleT = 0
local function applyPose(rig, pose)
	for _, m in rig.motors do
		local cf = pose[m.Part1.Name]
		if cf then
			if m.Part1.Name == "LowerTorso" then cf = CFrame.new(cf.Position * K) * cf.Rotation end
			m.Transform = cf
		end
	end
end

local GAP = 3.5 -- studs: NOW walks this far ahead of BEFORE (side by side on screen), BEFORE this far behind
local lastSeen = seenZ(0)
local camPos
local stills = {}
local frameNo = 0
for f = 1, 9 * SIM do
	local t = f / SIM
	local z = seenZ(f)
	local rawV = math.abs(z - lastSeen) * SIM
	lastSeen = z
	-- BEFORE
	for _, m in before.motors do m.Transform = CFrame.identity end
	RunMotion.step(recB, 1 / SIM, rawV, true, false)
	before.root.CFrame = CFrame.new(0, Rig.REST_HEIGHT, z + GAP)
	Rig.fk(before)
	-- NOW
	local v = Mix.track(tracker, t, Vector3.new(0, 0, z))
	Mix.step(mix, 1 / SIM, { speed = v, state = "ground", lengths = lengths })
	idleT += 1 / SIM
	applyPose(now, Mix.pose(mix, A, idleT, KFS.sample))
	now.root.CFrame = CFrame.new(0, Rig.REST_HEIGHT, z - GAP)
	Rig.fk(now)
	if f % (SIM / FPS) == 0 then
		local mid = Vector3.new(0, 2.4, z)
		local target = mid + Vector3.new(19, 3.5, 0)
		camPos = if camPos then camPos:Lerp(target, 0.3) else target
		local phase = if t < 1 then "STAND" elseif t < 4 then "SLOW WALK" elseif t < 8 then "HOLD W (RUN)" else "STOP"
		scene:frame(camPos, mid, {
			caption = "Another player over a jumpy network   left: BEFORE   right: NOW   " .. phase,
			labels = {
				{ p = { 0, 6.6, z + GAP }, text = "BEFORE", h = 0.9, c = "#d8dbe2", o = "#000000" },
				{ p = { 0, 6.6, z - GAP }, text = "NOW", h = 0.9, c = "#ffffff", o = "#000000" },
			},
		})
		frameNo += 1
	end
end

-- Part 2: the NOW body alone from behind, setting off from standing (own character: its real speed).
before.root.CFrame = CFrame.new(0, -50, 0) -- (out of the way)
Rig.fk(before)
local startZ = lastSeen - GAP - 30
local z, v = startZ, 0
local own = Mix.new(Mix.sized(Run.Loco, K))
local PRESS = 10.0
for f = 9 * SIM + 1, SECONDS * SIM do
	local t = f / SIM
	if t >= PRESS then
		if v < Run.StartSpeed then v = Run.StartSpeed end
		v += (Round.Speeds.Runner - v) * (1 - math.exp(-(1 / SIM) / (Run.Ramp / 3)))
	end
	z -= v / SIM
	Mix.step(own, 1 / SIM, { speed = v, state = "ground", lengths = lengths })
	idleT += 1 / SIM
	applyPose(now, Mix.pose(own, A, idleT, KFS.sample))
	now.root.CFrame = CFrame.new(0, Rig.REST_HEIGHT, z)
	Rig.fk(now)
	if f % (SIM / FPS) == 0 then
		local at = Vector3.new(0, Rig.REST_HEIGHT + 0.5, z)
		local pitch = math.rad(14)
		local eye = at + Vector3.new(0, math.sin(pitch) * 12, math.cos(pitch) * 12)
		scene:frame(eye, at, { caption = string.format("NOW from behind: W pressed at %.1f s  (t = %.2f)", PRESS, t) })
		-- the set-off, for the HV side by side: 0.1 s before the press to 0.8 s after, every 2 frames (0.067 s)
		local rel = t - PRESS
		if process.env.STILLS and rel > -0.12 and rel < 0.85 and frameNo % 2 == 0 then table.insert(stills, frameNo) end
		frameNo += 1
	end
end
scene:save(nil, FPS, 1280, 720, { stills = stills })
print("stills: " .. table.concat(stills, ","))
