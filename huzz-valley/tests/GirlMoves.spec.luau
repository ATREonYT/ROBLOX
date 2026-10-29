-- lune run tests/GirlMoves.spec.luau
-- The girls' walk/run/idle from the owner's movement pack (Shared/GirlMoves), on a stock R6 girl and an R15 one:
-- the pack loads, the blend picks idle / walk / run by speed, her feet stay on the ground (never sink), the
-- planted foot barely slides at walking speeds, nothing pops, the prize's head turns toward a player, and
-- FollowMotion uses the pack when it has it (and the scripted walk when it doesn't).
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Env = require("../tools/preview/motion3d/env")
local Rig = require("../tools/preview/motion3d/rig")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local GirlMoves = Env.load(SHARED .. "GirlMoves.lua")
local GirlMotion = Env.load(SHARED .. "GirlMotion.lua")
local FollowMotion = Env.load(SHARED .. "FollowMotion.lua")
local Pack = Env.load(SHARED .. "Config/GirlMotion.lua").Pack
local Sampler = Env.load(SHARED .. "KeyframeSampler.lua")
local Mix = Env.load(SHARED .. "LocomotionMix.lua")

local failed, passed = 0, 0
local function check(ok, what)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL " .. what)
	end
end

local lib = roblox.Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile(Env.root .. "/huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do
	inst.Parent = lib
end
local folder = lib:FindFirstChild("HuzzAnimations")
local anims = GirlMoves.load(folder)
check(anims ~= nil, "the pack's Idle, Walk and Run load from HuzzAnimations")
check(GirlMoves.load(nil) == nil, "no folder = nil (scripted walk)")
local partial = roblox.Instance.new("Folder")
folder:FindFirstChild("Idle"):Clone().Parent = partial
check(GirlMoves.load(partial) == nil, "a folder missing Walk/Run = nil (scripted walk)")
if not anims then
	print(`GirlMoves: {passed} ok, {failed} failed`)
	return
end

local DT = 1 / 60
local std = GirlMoves.new(anims, 3).mix.C
print(string.format("  measured from the pack: walk 1x at %.2f studs/s, run 1x at %.2f studs/s (standard size)", std.WalkAt, std.RunAt))
check(std.WalkAt > 2 and std.WalkAt < 6, "the walk's own speed is a walking speed")
check(std.RunAt > 6 and std.RunAt < 16, "the run's own speed is a running speed")

-- Lowest point of each leg in the world (R6: the leg's bottom face centre).
local function feet(rig)
	local out = {}
	for _, n in { "Left Leg", "Right Leg" } do
		local p = rig.parts[n]
		out[n] = (p.CFrame * CFrame.new(0, -p.Size.Y / 2, 0)).Position
	end
	return out
end

local function angleBetween(a, b)
	local _, ang = (a:Inverse() * b):ToAxisAngle()
	return math.abs(ang)
end

-- Walks a standard R6 girl (root 3 studs up) along -Z at a steady speed; returns slide (planted foot's ground
-- speed / her speed), worst sink below the ground (either foot), worst gap between the planted foot and the
-- ground, and the weights at the end.
local function walkAt(speed, seconds)
	local rig = Rig.r6("G")
	local J = GirlMotion.joints(rig.motors)
	local s = GirlMoves.new(anims, 3)
	local z, w = 0, nil
	local slide, n, sink, float = 0, 0, 0, 0
	local last
	for f = 0, math.floor(seconds / DT) do
		z -= speed * DT
		rig.root.CFrame = CFrame.new(0, 3, z)
		w = GirlMoves.step(s, J, DT, speed)
		Rig.fk(rig)
		local ft = feet(rig)
		-- the planted foot: the one the animation stands on (the other may dip a sliver into the ground)
		local main = if w.Run > w.Walk then "Run" else "Walk"
		local side = GirlMoves.stanceSide(Sampler.sample(anims[main], s.mix.times[main]))
		local low = if side == "L" then "Left Leg" else "Right Leg"
		local y = ft[low].Y
		if f * DT > 1 then -- (after the blend settles)
			sink = math.max(sink, -math.min(ft["Left Leg"].Y, ft["Right Leg"].Y))
			float = math.max(float, math.abs(y))
			if last and last.name == low then
				local d = ft[low] - last.pos
				slide += Vector3.new(d.X, 0, d.Z).Magnitude
				n += 1
			end
		end
		last = { name = low, pos = ft[low] }
	end
	return (slide / math.max(n, 1) / DT) / math.max(speed, 1e-3), sink, float, w
end

local _, sink0, float0, w0 = walkAt(0, 3)
check(w0.Idle > 0.99, "standing = Idle")
check(sink0 < 0.05 and float0 < 0.05, string.format("standing: feet on the ground (sink %.3f, float %.3f)", sink0, float0))

for _, v in { 2.5, std.WalkAt, 5 } do
	local slide, sink, float, w = walkAt(v, 3)
	print(string.format("  walk %.1f studs/s: slide %.0f%%, sink %.3f, float %.3f, walk weight %.2f", v, slide * 100, sink, float, w.Walk))
	check(w.Walk > 0.6, `{v} studs/s is a walk`)
	-- (the pack's own walk on an R15 body at an even speed slides ~100% on this measure: the lock makes the difference)
	check(slide < 0.4, string.format("walking at %.1f: the planted foot slides under 40%% (%.0f%%)", v, slide * 100))
	check(sink < Pack.Clip * 1.5 + 0.01, string.format("walking at %.1f: no foot dips more than a sliver into the ground (%.2f)", v, sink))
	check(float < 0.2, string.format("walking at %.1f: the planted foot stays near the ground (%.2f)", v, float))
end
for _, v in { std.RunAt, 14, 30 } do
	local slide, sink, _, w = walkAt(v, 3)
	print(string.format("  run %.1f studs/s: slide %.0f%%, sink %.3f, run weight %.2f", v, slide * 100, sink, w.Run))
	check(w.Run > 0.95, `{v} studs/s is a run`)
	check(sink < Pack.Clip * 1.5 + 0.01, string.format("running at %.1f: no foot dips more than a sliver into the ground (%.2f)", v, sink))
	if v <= std.RunAt + 0.01 then
		-- (45%: the Run's surge is softened, Config.Pack.Surge.Run, so the body doesn't lurch every step; was 30%)
		check(slide < 0.45, string.format("running at %.1f: the planted foot slides under 45%% (%.0f%%)", v, slide * 100))
	end
end

-- No pops: speeding up from standing to a full run and stopping again, no joint turns faster (checked at 240 fps)
-- than in the full-speed run itself (plus a little), so the blends never jump.
local function biggestTurn(speedAt, seconds)
	local rig = Rig.r6("G")
	local J = GirlMotion.joints(rig.motors)
	local s = GirlMoves.new(anims, 3)
	local prev, worst = {}, 0
	local h = 1 / 240
	for f = 0, seconds / h do
		GirlMoves.step(s, J, h, speedAt(f * h))
		if f * h > 0.5 then
			for _, m in rig.motors do
				if prev[m] then
					worst = math.max(worst, angleBetween(prev[m], m.Transform))
				end
			end
		end
		for _, m in rig.motors do
			prev[m] = m.Transform
		end
	end
	return math.deg(worst)
end
do
	local steady = biggestTurn(function() return 26 end, 3)
	local ramp = biggestTurn(function(t)
		return if t < 1 then 0 elseif t < 3 then (t - 1) * 13 elseif t < 4 then 26 else math.max(0, 26 - (t - 4) * 26)
	end, 6)
	print(string.format("  biggest joint turn in 1/240 s: %.1f° (steady full run %.1f°)", ramp, steady))
	check(ramp < steady * 1.15 + 1, "no pops from standing to running and back")
	-- (the steady run itself: 8.1° before Oct 18, when a fast girl played the Run at up to 1.6x)
	check(steady < 7, string.format("the full run itself swings no joint more than 7° in 1/240 s (%.1f°)", steady))
end

-- Owner Oct 18: "make the walking animation normal for the girls, right now its so choppy" (his clip: the small
-- companion sprinting beside him, legs and body jumping frame to frame). The game's FollowMotion + GirlMoves on a
-- 2.8-stud companion at 60 fps (tools/preview/motion3d/girl_smooth_measure.luau). Before the fix, at a sprint:
-- 43.7°/frame joint turns, 24°/frame² jerks, a 0.78-stud body lurch, a planted foot hopping 0.43, 9 steps a second.
do
	_G.NO_MAIN = true
	local Measure = require("../tools/preview/motion3d/girl_smooth_measure")
	for _, v in { 8, 22, 28 } do
		local r = Measure.run(v, { seconds = 5 })
		print(string.format("  companion behind a leader at %d: turn %.1f°/frame, jerk %.1f°/frame², body lurch %.3f, planted foot %.3f", v, r.turn, r.jerk, r.bodyJerkZ, r.footJitter))
		check(r.turn < 30, string.format("companion at %d: no joint jumps more than 30° a frame (%.1f)", v, r.turn))
		check(r.jerk < 12, string.format("companion at %d: joints swing smoothly, no snaps (jerk %.1f°/frame²)", v, r.jerk))
		check(r.bodyJerkZ < 0.15, string.format("companion at %d: her body doesn't lurch back and forth (%.3f)", v, r.bodyJerkZ))
		check(r.bodyJerkY < 0.12, string.format("companion at %d: her body doesn't pop up and down (%.3f)", v, r.bodyJerkY))
		check(r.footJitter < 0.2, string.format("companion at %d: a foot on the ground doesn't jitter (%.3f)", v, r.footJitter))
		local mix = r.rec.pack.mix
		local steps = Mix.stepsPerSecond(mix, { Walk = Measure.anims.Walk.length, Run = Measure.anims.Run.length })
		check(steps <= Pack.MaxSteps + 0.05, string.format("companion at %d: at most %.1f steps a second (%.1f)", v, Pack.MaxSteps, steps))
	end
	local jumpy = Measure.run(22, { seconds = 5, jitter = 0.3 })
	check(jumpy.jerk < 12 and jumpy.bodyJerkZ < 0.15, "companion: smooth even when the leader's position steps unevenly")
end

-- A small companion (half size) steps quicker but still plants her feet.
do
	local rig = Rig.r6("G")
	Rig.scale(rig, 0.53)
	local J = GirlMotion.joints(rig.motors)
	local s = GirlMoves.new(anims, 3 * 0.53)
	local sink = 0
	for f = 0, 120 do
		rig.root.CFrame = CFrame.new(0, 3 * 0.53, -f * DT * 3)
		GirlMoves.step(s, J, DT, 3)
		Rig.fk(rig)
		local ft = feet(rig)
		if f > 60 then
			sink = math.max(sink, -math.min(ft["Left Leg"].Y, ft["Right Leg"].Y))
		end
	end
	check(sink < (Pack.Clip * 1.5 + 0.01) * 0.53, "small companion: feet don't sink")
	check(s.mix.C.WalkAt < std.WalkAt, "small companion: her walk is made for a lower speed")
end

-- R15 girl: the pack as it is (no errors, joints move).
do
	local rig = Rig.r15("G")
	local J = GirlMotion.joints(rig.motors)
	local s = GirlMoves.new(anims, Rig.REST_HEIGHT)
	local ok, err = pcall(function()
		for _ = 1, 60 do GirlMoves.step(s, J, DT, 8) end
	end)
	check(ok, "R15 girl walks: " .. tostring(err))
	check(angleBetween(CFrame.identity, J.LHip.Transform) > math.rad(3), "R15 girl's legs move")
end

-- The prize: the pack's Idle with her head turned toward a player on her left.
do
	local rig = Rig.r6("G")
	rig.root.CFrame = CFrame.new(0, 3, 0) -- facing -Z
	Rig.fk(rig)
	local J = GirlMotion.joints(rig.motors)
	local s, state = GirlMoves.new(anims, 3), GirlMotion.new(1)
	for i = 1, 180 do
		local look = GirlMotion.look(state, J, DT, i * DT, { target = Vector3.new(-10, 4.5, -3), distance = 10 })
		GirlMoves.idle(s, J, DT, look)
		Rig.fk(rig)
	end
	local facing = rig.parts.Head.CFrame.LookVector
	check(facing.X < -0.5, string.format("prize looks toward the player on her left (head facing x %.2f)", facing.X))
	local ft = feet(rig)
	check(math.abs(math.min(ft["Left Leg"].Y, ft["Right Leg"].Y)) < 0.03, "prize stands on the ground")
end

-- FollowMotion: the pack when it has it, the scripted walk without.
for _, withPack in { true, false } do
	local rig = Rig.r6("G")
	local rec = FollowMotion.new({ root = rig.root, motors = rig.motors, rootHeight = 3, seed = 3, moves = if withPack then anims else nil })
	local leader = CFrame.new(0, 3, 0)
	local ok, err = pcall(function()
		for f = 1, 180 do
			leader = leader * CFrame.new(0, 0, -12 * DT)
			FollowMotion.step(rec, DT, f * DT, leader, function() return 0 end, leader.Position + Vector3.new(0, 1.5, 0))
		end
	end)
	check(ok, `follower ({if withPack then "pack" else "scripted"}) runs: {err}`)
	check((rec.pack ~= nil) == withPack, `follower uses the pack only when it has it ({withPack})`)
	check(angleBetween(CFrame.identity, rec.joints.LHip.Transform) > math.rad(2) or angleBetween(CFrame.identity, rec.joints.RHip.Transform) > math.rad(2), "follower's legs move")
end

print(`GirlMoves: {passed} ok, {failed} failed`)
if failed > 0 then
	error("GirlMoves spec failed")
end
