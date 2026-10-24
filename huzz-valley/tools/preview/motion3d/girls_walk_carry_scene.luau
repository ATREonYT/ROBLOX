-- Before / after for the owner's Oct 18 notes ("make the walking animation normal for the girls, right now its so
-- choppy" and "make the girls have some motion, not just be held straight up like that"), the game's own code:
--   0-5.5 s   your small companion (R6, 2.8 studs, Config/GirlMotion.Companion) behind a player who walks, then
--             sprints at 26 like the owner's clip, then stops. Seen from the side.
--   5.5-12 s  a carried girl (R6) over a carrier who walks, runs, then stands. Seen from behind and above.
-- Left lane BEFORE (an older copy of Shared, from GIRLS_BEFORE), right lane NOW (this checkout). Without
-- GIRLS_BEFORE both lanes run today's code.
--   git archive <old commit> huzz-valley/src/ReplicatedStorage/Shared | tar -x -C /tmp/before
--   GIRLS_BEFORE=/tmp/before/huzz-valley/src/ReplicatedStorage/Shared/ sh video.sh girls_walk_carry_scene.luau out.mp4
-- Film: docs/previews/girls-walk-carry.mp4. Numbers: girl_smooth_measure.luau.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local KFS = require("./kfs")
local Env = require("./env")

local NOW = "huzz-valley/src/ReplicatedStorage/Shared/"
local BEFORE = process.env.GIRLS_BEFORE or NOW
local function code(dir)
	return {
		Mix = Env.load(dir .. "LocomotionMix.lua"),
		GirlMoves = Env.load(dir .. "GirlMoves.lua"),
		FollowMotion = Env.load(dir .. "FollowMotion.lua"),
		CarryMath = Env.load(dir .. "CarryMath.lua"),
		CarryMotion = Env.load(dir .. "CarryMotion.lua"),
		Carry = Env.load(dir .. "Config/Carry.lua"),
		Companion = Env.load(dir .. "Config/GirlMotion.lua").Companion,
	}
end
local lanes = { { name = "BEFORE", code = code(BEFORE), x = -5 }, { name = "NOW", code = code(NOW), x = 5 } }
local Mix = lanes[2].code.Mix

local lib = roblox.Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile("huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do inst.Parent = lib end
local folder = lib:FindFirstChild("HuzzAnimations")
local A = {}
for _, name in { "Idle", "Walk", "Run" } do
	A[name] = KFS.load(folder:FindFirstChild(name))
end

local GIRL = { shirt = "#f06aa8", pants = "#3b2f5c", skin = "#f8dccb", hair = "#7a5cc8", eyes = "#2a1a40" }
local scene = Scene.new()
for i = -12, 90 do
	for j = -4, 4 do
		scene:addBox(CFrame.new(j * 4, 0.03, -i * 4), Vector3.new(0.4, 0.06, 0.4), "#b9a06a")
	end
end

-- Bounding-box centre in the root's space and the box size (as Model:GetBoundingBox).
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

-- Each lane: a player with a companion, and a carrier with a carried girl (shown one pair at a time).
local K = 2.8 / 5.25
for _, lane in lanes do
	local c = lane.code
	lane.player = scene:addRig(Rig.r15("Player" .. lane.name, { shirt = "#2b2b33", pants = "#1d1d22" }))
	lane.comp = scene:addRig(Rig.r6("Comp" .. lane.name, GIRL))
	Rig.scale(lane.comp, K)
	lane.follow = c.FollowMotion.new({ root = lane.comp.root, motors = lane.comp.motors, rootHeight = 3 * K, seed = 1, config = c.Companion, moves = c.GirlMoves.load(folder) })
	lane.carrier = scene:addRig(Rig.r15("Carrier" .. lane.name, { shirt = "#2f6fe0", pants = "#262a36" }))
	lane.girl = scene:addRig(Rig.r6("Girl" .. lane.name, GIRL))
	Rig.scale(lane.girl, c.Carry.GirlLength / 5.25)
	local centre, size = bounds(lane.girl)
	lane.motor = Rig.motor("HuzzCarryMotor", lane.carrier.parts.UpperTorso, lane.girl.root, c.CarryMath.holdC0(c.CarryMath.rig(lane.carrier), size.Z), centre)
	lane.carry = c.CarryMotion.new({
		motor = lane.motor, rig = c.CarryMath.rig(lane.carrier), root = lane.carrier.root, girlMotors = lane.girl.motors,
		start = 0, seed = 7,
	})
	lane.mixP, lane.mixC = Mix.new(), Mix.new()
end

-- The pack on an R15 body, blended by speed (as Gameplay/Locomotion and PlayerMoves).
local function animate(rig, mix, dt, speed, t)
	Mix.step(mix, dt, { speed = speed, state = "ground", lengths = { Walk = A.Walk.length, Run = A.Run.length } })
	local total = 0
	local function layer(anim, at, w)
		if w <= 1e-4 then return end
		total += w
		KFS.apply(anim, rig, at, w / total)
	end
	layer(A.Idle, t, mix.weights.Idle)
	layer(A.Walk, mix.times.Walk, mix.weights.Walk)
	layer(A.Run, mix.times.Run, mix.weights.Run)
end

local FPS, DT = 30, 1 / 30
local SUB = 2 -- (the game runs at 60: two steps a frame, filmed at 30 like the owner's clip)
local SPLIT, SECONDS = 5.5, 12
local function walkSpeed(t) return if t < 0.6 then 0 elseif t < 1.6 then 8 elseif t < 4.4 then 26 else 0 end
local function carrySpeed(t) return if t < 0.4 then 0 elseif t < 2.2 then 12 elseif t < 4 then 22 else 0 end
local camPos
local function hide(rig, hidden)
	for _, p in rig.parts do
		if p.Name ~= "HumanoidRootPart" then p.hidden = hidden end
	end
	rig.decor = if hidden then {} else rig.savedDecor
end
for _, lane in lanes do
	lane.comp.savedDecor, lane.girl.savedDecor = lane.comp.decor, lane.girl.decor
	lane.player.savedDecor, lane.carrier.savedDecor = lane.player.decor, lane.carrier.decor
	lane.pos, lane.speed, lane.cpos, lane.cspeed = Vector3.zero, 0, Vector3.zero, 0
end

for f = 0, SECONDS * FPS - 1 do
	local t = f * DT
	local first = t < SPLIT
	for _, lane in lanes do
		hide(lane.player, not first)
		hide(lane.comp, not first)
		hide(lane.carrier, first)
		hide(lane.girl, first)
	end
	for sub = 1, SUB do
		local h = DT / SUB
		local st = t + (sub - 1) * h
		for _, lane in lanes do
			local c = lane.code
			if first then
				lane.speed += (walkSpeed(st) - lane.speed) * (1 - math.exp(-h * 8))
				lane.pos += Vector3.new(0, 0, -lane.speed * h)
				animate(lane.player, lane.mixP, h, lane.speed, st)
				lane.player.root.CFrame = CFrame.new(Vector3.new(lane.x, Rig.REST_HEIGHT, 0) + lane.pos)
				Rig.fk(lane.player)
				local head = lane.player.parts.Head.CFrame.Position
				c.FollowMotion.step(lane.follow, h, st, lane.player.root.CFrame, function() return 0 end, head)
				Rig.fk(lane.comp)
			else
				local ct = st - SPLIT
				lane.cspeed += (carrySpeed(ct) - lane.cspeed) * (1 - math.exp(-h * 8))
				lane.cpos += Vector3.new(0, 0, -lane.cspeed * h)
				animate(lane.carrier, lane.mixC, h, lane.cspeed, ct)
				lane.carrier.root.CFrame = CFrame.new(Vector3.new(lane.x, Rig.REST_HEIGHT, 0) + lane.cpos)
				Rig.fk(lane.carrier, { lane.motor }, { lane.girl })
				c.CarryMotion.step(lane.carry, h, ct + 40, "Calm", 99)
				Rig.fk(lane.carrier, { lane.motor }, { lane.girl })
			end
		end
	end

	local labels = {}
	local caption
	local focus
	if first then
		local zs = (lanes[1].comp.root.CFrame.Position.Z + lanes[2].comp.root.CFrame.Position.Z) / 2
		focus = Vector3.new(1, 1.4, zs - 1)
		local target = focus + Vector3.new(0, 6, 15)
		camPos = if camPos and t > DT then camPos:Lerp(target, 0.5) else target
		for _, lane in lanes do
			table.insert(labels, { p = { lane.x + 1, 6, zs }, text = lane.name, h = 0.9, c = if lane.name == "NOW" then "#7dffa0" else "#ffffff", o = "#000000" })
		end
		caption = "Your companion: walk, then sprint at 26, then stop (30 fps, like your clip)"
	else
		local zs = lanes[1].cpos.Z
		focus = Vector3.new(0, 5.4, zs)
		local target = focus + Vector3.new(5, 5, 11.5)
		camPos = if camPos and t > SPLIT + DT then camPos:Lerp(target, 0.5) else target
		for _, lane in lanes do
			table.insert(labels, { p = { lane.x, 9.4, zs }, text = lane.name, h = 0.9, c = if lane.name == "NOW" then "#7dffa0" else "#ffffff", o = "#000000" })
		end
		caption = "Carried girl: walk, run, then stand"
	end
	if not process.env.EVERY or f % tonumber(process.env.EVERY) == 0 then -- (EVERY=n: a quick few frames to check framing)
		scene:frame(camPos, focus, { caption = caption, labels = labels })
	end
end
scene:save(nil, FPS, 1280, 720)
