--[[
	The girls, Oct 19 (owner: "make the girls be seen on everyones screen"; "add the nice girl animations when they
	are picked up"; "make synced dancing"):
	  - the pickup (Shared/CarryMotion, Config/Carry): won from far away she starts standing on the ground in front of
	    him (never a long flight across the field), rises, turns once and lies into his arms with no jump at the start
	    or the landing; taken off a head close by she flies from there; his arms ease up to meet her;
	  - every girl the server makes reaches every screen whole (GirlService: ModelStreamingMode Persistent before
	    she is parented) and each screen waits for her parts before moving her (Gameplay/CarryAnimator);
	  - synced dancing (Gameplay/DanceSync): the time in a dance from its beat, wrapped round the loop; two dancers on
	    one beat are at the same moment on any screen.
	Run from huzz-valley/: lune run tests/GirlPickup.spec.luau
]]
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3

local passed, failed = 0, 0
local function check(name, ok)
	if ok then passed += 1 else failed += 1 print("FAIL " .. name) end
end

-- the preview's rigs and module loader (the same code the films run)
local Rig = require("../tools/preview/motion3d/rig")
local Env = require("../tools/preview/motion3d/env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local CarryMath = Env.load(SHARED .. "CarryMath.lua")
local CarryMotion = Env.load(SHARED .. "CarryMotion.lua")
local Carry = Env.load(SHARED .. "Config/Carry.lua")

local function bounds(rig)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), -Vector3.new(math.huge, math.huge, math.huge)
	for _, p in rig.parts do
		local c = rig.root.CFrame:PointToObjectSpace(p.CFrame.Position)
		lo, hi = lo:Min(c - p.Size / 2), hi:Max(c + p.Size / 2)
	end
	return CFrame.new((lo + hi) / 2), hi - lo
end

local function setup(from)
	local carrier = Rig.r15("Carrier", {})
	local girl = Rig.r6("Girl", {})
	Rig.scale(girl, Carry.GirlLength / 5.25)
	local centre, size = bounds(girl)
	local motor = Rig.motor("HuzzCarryMotor", carrier.parts.UpperTorso, girl.root, CarryMath.holdC0(CarryMath.rig(carrier), size.Z), centre)
	carrier.root.CFrame = CFrame.new(0, Rig.REST_HEIGHT, 0)
	Rig.fk(carrier, { motor }, { girl })
	local rec = CarryMotion.new({ motor = motor, rig = CarryMath.rig(carrier), root = carrier.root, girlMotors = girl.motors, start = 0, from = from, seed = 3 })
	local function at(t)
		Rig.fk(carrier, { motor }, { girl })
		CarryMotion.step(rec, 1 / 60, t, "Excited", t)
		Rig.fk(carrier, { motor }, { girl })
		return (girl.root.CFrame * centre).Position, girl.root.CFrame
	end
	return rec, at, carrier
end

-- won from the big girl over the map (far away): she starts on the ground in front of him
do
	local rec, at, carrier = setup(Vector3.new(0, 40, -80))
	local root = carrier.root.CFrame.Position
	check("from far: she starts in front of him, not up at the big girl", rec.onGround and (rec.from - root).Magnitude < 4)
	check("from far: on his ground level (her middle near his root's height)", math.abs(rec.from.Y - root.Y) < 1)
	check("from far: in front of him (he faces -Z)", (rec.from - root):Dot(carrier.root.CFrame.LookVector) > 2.5)
	local start = at(0)
	check("no jump at the start: her middle is where she appears (" .. string.format("%.2f", (start - rec.from).Magnitude) .. ")", (start - rec.from).Magnitude < 0.1)
	local _, startCF = at(0)
	check("she starts standing up", startCF.UpVector:Dot(Vector3.yAxis) > 0.9)
	local T = Carry.PickupTime
	local last, rises, maxStep = at(0), 0, 0
	for i = 1, 60 do
		local p = at(T * i / 60)
		if i <= 30 and p.Y > last.Y - 0.01 then rises += 1 end
		maxStep = math.max(maxStep, (p - last).Magnitude)
		last = p
	end
	check("she rises through the first half (" .. rises .. " of 30 steps up; then the arc settles down into his arms)", rises >= 28)
	check("smooth flight: no step over 0.6 studs at 60 fps (" .. string.format("%.2f", maxStep) .. ")", maxStep < 0.6)
	local landed, landedCF = at(T)
	local after = at(T + 1 / 60)
	check("no jump at the landing (" .. string.format("%.3f", (after - landed).Magnitude) .. ")", (after - landed).Magnitude < 0.15)
	check("she ends lying over his head", landed.Y > carrier.parts.Head.CFrame.Position.Y and math.abs(landedCF.UpVector:Dot(Vector3.yAxis)) < 0.7)
	check("the pickup takes " .. T .. " s (0.6 to 1.2: quick, still seen)", T >= 0.6 and T <= 1.2)
	check("progress 0 at the start, 1 at the end", CarryMotion.progress(rec, 0) == 0 and CarryMotion.progress(rec, T) == 1)
end

-- taken off a head close by: she flies from there, lying as she was
do
	local head = Vector3.new(4, 7.5, -1)
	local rec, at = setup(head)
	check("from a head close by: she starts there", not rec.onGround and (rec.from - head).Magnitude < 1e-3)
	local start = at(0)
	check("from a head: no jump at the start", (start - head).Magnitude < 0.1)
end

-- his arms ease up (the carry's arm weight: 0 at the start, all the way by 0.625 of the pickup)
do
	local _, at, carrier = setup(nil)
	at(0)
	local rest = carrier.motors.RightUpperArm and carrier.motors.RightUpperArm.Transform
	local shoulder = nil
	for _, m in carrier.motors do
		if m.Part1 and m.Part1.Name == "RightUpperArm" then shoulder = m end
	end
	check("found his right shoulder", shoulder ~= nil or rest ~= nil)
	if shoulder then
		local a0 = shoulder.Transform
		at(Carry.PickupTime)
		local a1 = shoulder.Transform
		check("his arm moves up during the pickup", (a0.LookVector - a1.LookVector).Magnitude > 0.3 or (a0.UpVector - a1.UpVector).Magnitude > 0.3)
	end
end

-- every girl reaches every screen whole, and each screen waits for her parts
do
	local src = fs.readFile("src/ServerScriptService/HuzzServer/GirlService.lua")
	local makeCopy = string.match(src, "function GirlService%.makeCopy(.-)\nend\n")
	local persistent = makeCopy and string.find(makeCopy, "ModelStreamingMode = Enum.ModelStreamingMode.Persistent", 1, true)
	local parented = makeCopy and string.find(makeCopy, "model.Parent = parent", 1, true)
	check("GirlService.makeCopy: Persistent before she is parented", persistent ~= nil and parented ~= nil and persistent < parented)
	local anim = fs.readFile("src/StarterPlayer/StarterPlayerScripts/HuzzClient/Gameplay/CarryAnimator.lua")
	for _, fn in { "startCarry", "startPrize", "startFollower" } do
		local body = string.match(anim, "local function " .. fn .. "%(model%)(.-)\n\tend\n")
		check("CarryAnimator." .. fn .. " waits for her parts (streaming)", body ~= nil and string.find(body, "whenWhole(model)", 1, true) ~= nil)
	end
end

-- synced dancing: where a dance is, from its beat
do
	local DanceSync = Env.load("huzz-valley/src/StarterPlayer/StarterPlayerScripts/HuzzClient/Gameplay/DanceSync.lua")
	check("time from the beat", math.abs(DanceSync.timeAt(105.5, 100, 4) - 1.5) < 1e-9)
	check("wraps round the loop", math.abs(DanceSync.timeAt(100 + 4 * 7 + 0.25, 100, 4) - 0.25) < 1e-9)
	check("a zero-length dance stays at 0", DanceSync.timeAt(5, 1, 0) == 0)
	-- two dancers on one beat, seen from two screens a little apart in time: the same moment at the same server time
	local beat = 1000.2
	local a, b = DanceSync.timeAt(1003.7, beat, 2.4), DanceSync.timeAt(1003.7, beat, 2.4)
	check("same beat, same moment", a == b)
	check("off by, across the loop's seam (3.9 vs 0.05 of 4 = 0.15 apart)", math.abs(DanceSync.offBy(3.9, 0.05, 4) + 0.15) < 1e-9)
	check("off by, plain", math.abs(DanceSync.offBy(1.3, 1.0, 4) - 0.3) < 1e-9)
	check("in step: no nudge under 0.12 s", math.abs(DanceSync.offBy(2.05, 2.0, 4)) <= 0.12)
end

print(string.format("GirlPickup: %d passed, %d failed", passed, failed))
if failed > 0 then require("@lune/process").exit(1) end
