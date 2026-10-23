-- (r6_swing_scene: the swing only, Oct 23 20:07 "fix the swing animation ... make more of a swing to it and make it
-- look more premium": 0-2.4 s running, swings at 0.4 and 1.4 s (front three-quarter); 2.4-6.4 s one swing at 1/4
-- speed (front three-quarter); 6.4-8 s one at full speed from the side. STAB_OLD = a module path: the old StabMotion copied next to the new one.)
-- The catcher's knife swing and dive on an R6 body (owner, Oct 22 18:53-18:55: "make the animations for swinging the
-- knives"; "make the jumping animation way better"): Shared/StabMotion's own code (its R6 part) over the R6 run, knife
-- in the right hand as KnifeService holds it, the dive's push and hop as Gameplay/Dash moves the body.
--   0-3.2 s    running (side view): a swing at 0.6 s, a dive at 1.8 s
--   3.2-6.4 s  the same swing at 1/4 speed (front three-quarter view)
--   6.4-10 s   the same dive at 1/3 speed (side view)
-- sh video.sh r6_knife_scene.luau out.mp4   (repo root; uses HuzzAnimations' R6Run, his pack: private file only)
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local KFS = require("./kfs")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local CarryMath = Env.load(SHARED .. "CarryMath.lua")
local StabMotion = Env.load(require("@lune/process").env.STAB_OLD or (SHARED .. "StabMotion.lua"))
local RunMotion = Env.load(SHARED .. "RunMotion.lua")
local Round = Env.load(SHARED .. "Config/Round.lua")
local rad = math.rad

local lib = roblox.Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile("huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do inst.Parent = lib end
local runAnim = lib:FindFirstChild("R6Run", true)
local run = runAnim and KFS.load(runAnim)

local scene = Scene.new()
for i = -10, 60 do
	for j = -4, 4 do
		scene:addBox(CFrame.new(j * 4, 0.03, -i * 4), Vector3.new(0.4, 0.06, 0.4), "#b9a06a")
	end
end
local catcher = scene:addRig(Rig.r6("Catcher", { shirt = "#e0453a", pants = "#2b2f3a", skin = "#e9c29a", hair = "#1a1414" }))
-- the knife at the R6 grip (Right Arm's RightGripAttachment, 1 stud down), blade down and forward (KnifeLook.HAND)
do
	local arm = catcher.parts["Right Arm"]
	local grip = CFrame.new(0, -1, 0) * CFrame.Angles(rad(-150), 0, 0)
	local dark, steel = "#201e26", "#cdd4e0"
	for _, b in {
		{ CFrame.new(0, 0, 0), Vector3.new(0.22, 0.75, 0.26), dark },
		{ CFrame.new(0, 0.42, 0), Vector3.new(0.24, 0.1, 0.62), steel },
		{ CFrame.new(0, 0.995, 0.02), Vector3.new(0.07, 1.05, 0.3), steel },
		{ CFrame.new(0, 1.66, 0.08), Vector3.new(0.07, 0.3, 0.16), steel },
	} do
		table.insert(catcher.decor, { part = arm, offset = grip * b[1], Size = b[2], Color = b[3] })
	end
end
local rec = StabMotion.new(CarryMath.rig(catcher), catcher.root)

local FPS, DT, SECONDS = 30, 1 / 30, 8
local L = Round.Lunge
local pos, clock, runT = Vector3.new(0, 0, 40), 0, 0
local diveAt = nil
local events = { { at = 0.4, kind = "swing" }, { at = 1.4, kind = "swing" }, { at = 2.6, kind = "swing" }, { at = 6.7, kind = "swing" } }
local camPos
for f = 0, SECONDS * FPS - 1 do
	local t = f * DT
	local h = if t >= 2.4 and t < 6.4 then DT / 4 else DT
	local running = t < 2.4 or t >= 6.4
	clock += h
	for _, e in events do
		if t >= e.at and t - DT < e.at then
			StabMotion.play(rec, clock, e.kind == "dive")
			if e.kind == "dive" then diveAt = clock end
		end
	end
	-- the body: running ahead at the catcher's speed, the dive's push and hop, held still through the stun
	local age = diveAt and clock - diveAt
	local speed = if running then Round.Speeds.Catcher else 0
	local y = 0
	if age and age < StabMotion.LEAP.Up then
		speed = RunMotion.lungeSpeed(L, age) or (if age < (L.StunAfter + L.Stun) then 0 else speed)
		local air = StabMotion.air()
		if age < air then y = L.Up * age - 0.5 * StabMotion.LEAP.Gravity * age * age end
	end
	pos += Vector3.new(0, 0, -speed * h)
	for _, m in catcher.motors do m.Transform = CFrame.identity end
	if run and (running or (age and age < StabMotion.LEAP.Up)) then
		runT += h
		KFS.apply(run, catcher, runT % run.length)
	end
	StabMotion.slashStart(rec, clock)
	StabMotion.step(rec, clock) -- (after the animations, as Gameplay/Frame order 30)
	catcher.root.CFrame = CFrame.new(pos + Vector3.new(0, 3 + math.max(y, 0), 0))
	Rig.fk(catcher)
	local front = t < 6.4
	local target = if front then pos + Vector3.new(5, 3.6, -7) else pos + Vector3.new(11, 3.4, -2)
	camPos = if camPos and math.abs(t - 6.4) > DT / 2 then camPos:Lerp(target, 0.4) else target
	local u = StabMotion.progress(rec, clock)
	local label = if u >= 0 and u <= 1 then "  swing" elseif age and age < StabMotion.LEAP.Up then "  dive" else ""
	local rate = if h < DT / 3.5 then "1/4 speed" elseif h < DT then "1/3 speed" else "full speed"
	scene:frame(camPos, pos + Vector3.new(0, 2.6, -1), { caption = rate .. label })
end
scene:save(nil, FPS, 1280, 720)
