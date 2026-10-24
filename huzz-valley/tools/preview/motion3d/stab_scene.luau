-- The catcher's stab (Shared/StabMotion, the game's own code) over the pack's run, knife in hand.
--   0-2.4 s    running (side view), stab at 1.0 s at full speed
--   2.4-5.4 s  standing, the same stab at 1/4 speed (front three-quarter view), to judge the shape
--   5.4-7 s    standing, full speed, same view
-- sh video.sh stab_scene.luau out.mp4
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local KFS = require("./kfs")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local Mix = Env.load(SHARED .. "LocomotionMix.lua")
local CarryMath = Env.load(SHARED .. "CarryMath.lua")
local StabMotion = Env.load(SHARED .. "StabMotion.lua")
local Round = Env.load(SHARED .. "Config/Round.lua")
local rad = math.rad

local lib = roblox.Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile("huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do inst.Parent = lib end
local A = {}
for _, name in { "Idle", "Walk", "Run" } do A[name] = KFS.load(lib:FindFirstChild(name, true)) end

-- The knife as KnifeService holds it (as action_scene.luau).
local function giveKnife(rig)
	local hand = rig.parts.RightHand
	local grip = CFrame.new(0, -0.15, 0) * CFrame.Angles(rad(-150), 0, 0)
	local dark, steel = "#201e26", "#cdd4e0"
	for _, b in {
		{ CFrame.new(0, 0, 0), Vector3.new(0.22, 0.75, 0.26), dark },
		{ CFrame.new(0, -0.42, 0), Vector3.new(0.26, 0.12, 0.3), steel },
		{ CFrame.new(0, 0.42, 0), Vector3.new(0.24, 0.1, 0.62), steel },
		{ CFrame.new(0, 0.995, 0.02), Vector3.new(0.07, 1.05, 0.3), steel },
		{ CFrame.new(0, 1.66, 0.08), Vector3.new(0.07, 0.3, 0.16), steel },
	} do
		table.insert(rig.decor, { part = hand, offset = grip * b[1], Size = b[2], Color = b[3] })
	end
end

local scene = Scene.new()
for i = -10, 30 do
	for j = -4, 4 do
		scene:addBox(CFrame.new(j * 4, 0.03, -i * 4), Vector3.new(0.4, 0.06, 0.4), "#b9a06a")
	end
end
local catcher = scene:addRig(Rig.r15("Catcher", { shirt = "#e0453a", pants = "#2b2f3a" }))
giveKnife(catcher)
local stab = StabMotion.new(CarryMath.rig(catcher), catcher.root)

local FPS, DT, SECONDS = 30, 1 / 30, 7
local mix = Mix.new()
local pos, speed, idleT = Vector3.new(0, 0, 40), 0, 0
local clock, stabs = 0, { [1.0] = true, [3.0] = true, [5.9] = true }
local runEnd = 2.4
local camPos
for f = 0, SECONDS * FPS - 1 do
	local t = f * DT
	local slow = t >= runEnd and t < 5.4
	local h = if slow then DT / 4 else DT
	clock += h
	for at in stabs do
		if t >= at and t - DT < at then StabMotion.play(stab, clock) end
	end
	local want = if t < runEnd - 0.4 then 24 else 0
	speed += (want - speed) * (1 - math.exp(-h * 10))
	pos += Vector3.new(0, 0, -speed * h)
	Mix.step(mix, h, { speed = speed, state = "ground", lengths = { Walk = A.Walk.length, Run = A.Run.length } })
	idleT += h
	local total = 0
	local function layer(anim, at, w)
		if w <= 1e-4 then return end
		total += w
		KFS.apply(anim, catcher, at, w / total)
	end
	layer(A.Idle, idleT, mix.weights.Idle)
	layer(A.Walk, mix.times.Walk, mix.weights.Walk)
	layer(A.Run, mix.times.Run, mix.weights.Run)
	StabMotion.step(stab, clock) -- (after the animations, as Gameplay/Frame order 30)
	catcher.root.CFrame = CFrame.new(pos + Vector3.new(0, Rig.REST_HEIGHT, 0))
	Rig.fk(catcher)
	local target = if t < runEnd then pos + Vector3.new(10, 3.2, -1.5) else pos + Vector3.new(5.5, 3.6, -6.5)
	camPos = if camPos and math.abs(t - runEnd) > DT / 2 then camPos:Lerp(target, 0.4) else target
	local u = StabMotion.progress(stab, clock)
	local label = if u >= 0 and u <= 1 then string.format("  stab %.2f s", u * Round.Stab.Time) else ""
	scene:frame(camPos, pos + Vector3.new(0, 3, -1), { caption = (if slow then "1/4 speed" else "full speed") .. label })
end
scene:save(nil, FPS, 1280, 720)
