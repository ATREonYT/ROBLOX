-- lune run tests/StandShowcase.spec.luau   (from huzz-valley/)
-- The lobby stands' sword showcase (Shared/StandShowcase; owner: "showcase the swords that the gamepass includes ...
-- the swinging animation, make it look good though") on mock R15 and R6 copies holding a Game Pass knife (Hollow
-- Eclipse's baked size): in the ready guard the blade is up, in front of the body and clear of the face; a move
-- plays every loop, the three take turns, stands with different seeds differ; the trail shows only in the cuts;
-- every joint and the knife move smoothly frame to frame (no pops, no jumps where a move starts or ends); each move
-- ends back in the guard; the R15 feet stay planted on the floor.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local ROOT = if fs.isDir("huzz-valley") then "huzz-valley/" else ""
local Env = require("../tools/preview/motion3d/env")
local Rig = require("../tools/preview/motion3d/rig")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local Show = Env.load(SHARED .. "StandShowcase.lua")
local KnifeLook = Env.load(SHARED .. "KnifeLook.lua")

local failed, passed = 0, 0
local function check(ok, what)
	if ok then passed += 1 else failed += 1; print("FAIL " .. what) end
end

local knife
for _, k in serde.decode("json", fs.readFile(ROOT .. "tools/knives/knives.json")) do
	if k.key == "HollowEclipse" then knife = k end
end
local per = knife.studs / knife.length
local BLADE = (knife.tip - knife.grip) * per -- grip to tip, studs
local GUARD = (0 - knife.grip) * per -- grip to the guard (TrailBase)

local function build(kind, seed)
	local rig = if kind == "R15" then Rig.r15("S" .. seed) else Rig.r6("S" .. seed)
	rig.root.CFrame = CFrame.new(0, if kind == "R15" then Rig.REST_HEIGHT else 3, 0) -- facing -Z, as a stand facing you
	local rec = Show.new(rig, seed)
	return rig, rec
end

-- Poses the rig at t; returns the root-space points that matter.
local function at(rig, rec, t)
	local pose = Show.step(rec, t)
	Rig.fk(rig)
	local hand = rig.parts.RightHand or rig.parts["Right Arm"]
	local gripAt = Vector3.new(0, -hand.Size.Y / 2 + 0.1, 0)
	local handle = hand.CFrame * CFrame.new(gripAt) * CFrame.Angles(math.rad(pose.gripAngle), 0, 0) * KnifeLook.handC0(gripAt).Rotation
	local root = rig.root.CFrame
	local function local_(p) return root:PointToObjectSpace(p) end
	local torso = rig.parts.UpperTorso or rig.parts.Torso
	return {
		pose = pose, handle = handle,
		grip = local_(handle.Position), tip = local_(handle * Vector3.new(0, BLADE, 0)), guard = local_(handle * Vector3.new(0, GUARD, 0)),
		mid = local_(handle * Vector3.new(0, (GUARD + BLADE) / 2, 0)),
		torso = local_(torso.CFrame.Position), torsoSize = torso.Size, head = local_(rig.parts.Head.CFrame.Position), headSize = rig.parts.Head.Size,
		feet = rig.parts.RightFoot and { rig.parts.RightFoot.CFrame, rig.parts.LeftFoot.CFrame } or nil,
	}
end

-- A time in the seed's ready guard (well before its move).
local function readyTime(seed)
	for t = 0, 10, 0.05 do
		local _, mt = Show.timing(seed, t)
		if mt < -0.8 and mt > -1.2 then return t end
	end
	return 0
end

for _, kind in { "R15", "R6" } do
	local rig, rec = build(kind, 5)
	check(rec ~= nil and rec.kind == kind, kind .. ": the rig is read")
	-- 1. the ready guard shows the knife
	local r = at(rig, rec, readyTime(5))
	local front = r.torso.Z - r.torsoSize.Z / 2 -- (forward is -Z)
	print(string.format("  %s ready: grip %.2f %.2f %.2f  tip %.2f %.2f %.2f  torso front z %.2f  head %.2f %.2f",
		kind, r.grip.X, r.grip.Y, r.grip.Z, r.tip.X, r.tip.Y, r.tip.Z, front, r.head.X, r.head.Y))
	check(r.tip.Y - r.grip.Y > 0.8 * BLADE, kind .. " ready: the blade points up")
	check(r.mid.Z < front - 0.2 and r.tip.Z < front, kind .. " ready: the blade is in front of the body")
	check(r.grip.Z < front, kind .. " ready: the knife hand is in front of the body")
	check(math.abs(r.tip.X - r.head.X) > r.headSize.X / 2 + 0.15 or r.tip.Y > r.head.Y + r.headSize.Y / 2 + 0.3 and math.abs(r.tip.X - r.head.X) > 0.3,
		kind .. " ready: the blade stays clear of the face")
	check(r.grip.X > 0.3, kind .. " ready: the knife is on the right side, not across the body")

	-- 2 + 3. a run over several loops at 30 and 60 fps
	local function run(fps, seconds)
		local frames = {}
		for f = 0, seconds * fps do
			local t = f / fps
			local p = at(rig, rec, t)
			local tf = {}
			for name, m in rec.j do tf[name] = m.Transform end
			table.insert(frames, { t = t, p = p, tf = tf })
		end
		return frames
	end
	local seconds = math.ceil(Show.CYCLE * 4)
	local f30, f60 = run(30, seconds), run(60, seconds)
	local function worst(frames)
		local joint, blade, edge = 0, 0, 0
		for i = 2, #frames do
			local a, b = frames[i - 1], frames[i]
			for name, cf in b.tf do
				local d = a.tf[name]:ToObjectSpace(cf)
				local _, ang = d:ToAxisAngle()
				joint = math.max(joint, math.deg(math.abs(ang)))
			end
			local _, kang = a.p.handle:ToObjectSpace(b.p.handle):ToAxisAngle()
			blade = math.max(blade, math.deg(math.abs(kang)))
		end
		return joint, blade, edge
	end
	local j30, b30 = worst(f30)
	-- where a move starts and ends: the pose a millisecond before and after
	local e30 = 0
	for i = 2, #f30 do
		if (f30[i - 1].p.pose.move ~= nil) ~= (f30[i].p.pose.move ~= nil) then
			local lo, hi = f30[i - 1].t, f30[i].t
			for _ = 1, 30 do -- (find the switch)
				local mid = (lo + hi) / 2
				if (Show.sample(5, mid).move ~= nil) == (f30[i - 1].p.pose.move ~= nil) then lo = mid else hi = mid end
			end
			at(rig, rec, lo)
			local before = {}
			for name, m in rec.j do before[name] = m.Transform end
			at(rig, rec, hi)
			for name, m in rec.j do
				local _, ang = before[name]:ToObjectSpace(m.Transform):ToAxisAngle()
				e30 = math.max(e30, math.deg(math.abs(ang)))
			end
		end
	end
	local j60, b60 = worst(f60)
	print(string.format("  %s per frame at 30 fps: joints %.1f deg, knife %.1f deg, where a move starts/ends %.2f deg; at 60 fps %.1f / %.1f",
		kind, j30, b30, e30, j60, b60))
	check(j30 < 45, kind .. ": no joint jumps more than 45 degrees in a frame (30 fps)")
	check(b30 < 65, kind .. ": the knife never turns more than 65 degrees in a frame (30 fps, twirls included)")
	check(e30 < 0.5, kind .. ": no jump where a move starts or ends")
	check(j60 < j30 * 0.65 and b60 < b30 * 0.65, kind .. ": twice the frame rate halves the steps (smooth, no pops)")

	-- moves on a cycle: one per loop, all three, trail only in moves
	local starts, names, trailOutside, trailFrames, lastMove = 0, {}, 0, 0, nil
	for _, fr in f30 do
		local m = fr.p.pose.move
		if m and m ~= lastMove then starts += 1; names[m] = true end
		lastMove = m
		if fr.p.pose.trail then
			trailFrames += 1
			if not m then trailOutside += 1 end
		end
	end
	local loops = seconds / Show.CYCLE
	check(starts >= math.floor(loops) - 1 and starts <= math.ceil(loops) + 1, kind .. ": a move every loop (" .. starts .. " in " .. seconds .. " s)")
	check(names.Combo and names.Flourish and names.Rising, kind .. ": the three moves take turns")
	check(trailFrames > 0 and trailOutside == 0, kind .. ": the trail shows in the cuts only")
	-- the swings are real swings: the tip travels far during a move
	local reach = 0
	for _, fr in f30 do
		if fr.p.pose.move then reach = math.max(reach, (fr.p.tip - r.tip).Magnitude) end
	end
	check(reach > 2.5, kind .. string.format(": the moves swing the blade wide (%.1f studs)", reach))

	-- 4. back to the guard after every move
	local back = 0
	for name, move in Show.MOVES do
		local final = move.keys[#move.keys]
		for _, f in { "arm", "off", "waist", "neck" } do
			for i = 1, 3 do back = math.max(back, math.abs(final[f][i] - Show.READY[f][i])) end
		end
		for _, f in { "elbow", "wrist", "offElbow", "drop" } do back = math.max(back, math.abs(final[f] - Show.READY[f])) end
		back = math.max(back, math.abs((final.grip % 360) - Show.READY.grip))
	end
	check(back < 1e-6, kind .. ": every move ends in the ready guard")

	-- 5. the feet stay planted (R15)
	if kind == "R15" then
		local slide, low, high = 0, math.huge, -math.huge
		local first = f30[1].p.feet
		for _, fr in f30 do
			for i = 1, 2 do
				slide = math.max(slide, (fr.p.feet[i].Position - first[i].Position).Magnitude)
				local bottom = fr.p.feet[i].Position.Y - 0.15
				low, high = math.min(low, bottom), math.max(high, bottom)
			end
		end
		print(string.format("  R15 feet: slide %.3f studs, soles %.3f to %.3f", slide, low, high))
		check(slide < 0.08, "R15: the feet stay planted")
		check(low > -0.08 and high < 0.08, "R15: the feet stay on the floor")
	end
end

-- stands side by side don't move together
do
	local same = 0
	for t = 0, 12, 0.1 do
		local a, b = Show.sample(5, t), Show.sample(11, t)
		if (a.move ~= nil) == (b.move ~= nil) and a.move == b.move and math.abs(a.arm[2] - b.arm[2]) < 3 then same += 1 end
	end
	check(same < 60, "two stands with different seeds don't move in step (" .. same .. " of 121 samples alike)")
end

print(`StandShowcase: {passed} ok, {failed} failed`)
if failed > 0 then error("StandShowcase spec failed") end
