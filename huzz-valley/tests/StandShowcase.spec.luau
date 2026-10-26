-- lune run tests/StandShowcase.spec.luau   (from huzz-valley/)
-- The lobby stands' sword showcase (Shared/StandShowcase; owner: "showcase the swords that the gamepass includes ...
-- the swinging animation, make it look good though") on mock R15 and R6 copies holding a Game Pass knife (Hollow
-- Eclipse's baked size): in the ready guard the blade slants up and out to the right, in front of the body, clear
-- of the face and under the sign (knife check, Oct 19: the upright guard went through the sign); a move
-- plays every loop, the three take turns, stands with different seeds differ; the trail shows only in the cuts;
-- every joint and the knife move smoothly frame to frame (no pops, no jumps where a move starts or ends); each move
-- ends back in the guard; the R15 feet stay planted on the floor.
-- Oct 19: every knife's style (StandShowcase.STYLES: the guard or the low hold, its three moves) with the knife at the
-- stands' big size (KnifeLook.STAND): the low hold keeps the blade down and forward, clear of the legs and off the
-- floor; spins come round whole (the feet turn with the body and land where they stood); bursts only in moves.
-- Round 3: at rest the blade's broad face looks out of the stand (not its edge).
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
local per = knife.studs / knife.length * KnifeLook.standScale(knife.studs) -- (the stands' big knife)
local BLADE = (knife.tip - knife.grip) * per -- grip to tip, studs
local GUARD = (0 - knife.grip) * per -- grip to the guard (TrailBase)

local function build(kind, seed, style)
	local rig = if kind == "R15" then Rig.r15("S" .. seed) else Rig.r6("S" .. seed)
	rig.root.CFrame = CFrame.new(0, if kind == "R15" then Rig.REST_HEIGHT else 3, 0) -- facing -Z, as a stand facing you
	local rec = Show.new(rig, seed, style)
	return rig, rec
end

-- Poses the rig at t; returns the root-space points that matter.
local function at(rig, rec, t)
	local pose = Show.step(rec, t)
	Rig.fk(rig)
	local hand = rig.parts.RightHand or rig.parts["Right Arm"]
	local gripAt = Vector3.new(0, -hand.Size.Y / 2 + 0.1, 0)
	local handle = hand.CFrame * CFrame.new(gripAt) * Show.knifeTurn(pose, KnifeLook.handC0(gripAt).Rotation)
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

local STYLES = { "Default", "DragonsMaw", "HollowEclipse", "CrimsonRequiem", "CelestialSeraph", "FrostboundOath" }
for _, styleKey in STYLES do
local style = Show.style(styleKey)
local hold = Show.HOLDS[style.hold]
for _, kind in { "R15", "R6" } do
	local rig, rec = build(kind, 5, styleKey)
	local tag = kind .. " " .. styleKey
	check(rec ~= nil and rec.kind == kind, tag .. ": the rig is read")
	-- 1. the hold shows the knife
	local r = at(rig, rec, readyTime(5))
	local front = r.torso.Z - r.torsoSize.Z / 2 -- (forward is -Z)
	local floorY = -rig.root.CFrame.Position.Y
	print(string.format("  %s ready (%s): grip %.2f %.2f %.2f  tip %.2f %.2f %.2f  torso front z %.2f  head %.2f %.2f",
		tag, style.hold, r.grip.X, r.grip.Y, r.grip.Z, r.tip.X, r.tip.Y, r.tip.Z, front, r.head.X, r.head.Y))
	if style.hold == "Guard" then
		check(r.tip.Y - r.grip.Y > 0.55 * BLADE, tag .. " ready: the blade points up (slanting out to the right)")
		check(r.tip.X - r.grip.X > 0.4 * BLADE, tag .. " ready: the blade slants out to the right side, not straight up")
		-- knife check (Oct 19): the sign's bottom sits about 1.45 studs over the head's middle (AvatarStands: 3.1 up,
		-- 3.3 tall); the old upright guard put the tip 2.6 studs over the head, through the sign
		check(r.tip.Y < r.head.Y + 1.3, tag .. string.format(" ready: the tip stays under the sign (%.2f over the head)", r.tip.Y - r.head.Y))
		check(r.mid.Z < front - 0.2 and r.tip.Z < front, tag .. " ready: the blade is in front of the body")
		check(r.grip.Z < front, tag .. " ready: the knife hand is in front of the body")
		check(math.abs(r.tip.X - r.head.X) > r.headSize.X / 2 + 0.15 or r.tip.Y > r.head.Y + r.headSize.Y / 2 + 0.3 and math.abs(r.tip.X - r.head.X) > 0.3,
			tag .. " ready: the blade stays clear of the face")
	else
		check(r.tip.Y < r.grip.Y - 0.25 * BLADE, tag .. " low hold: the blade points down")
		check(r.tip.Z < front - 0.4, tag .. " low hold: the tip is in front of the body (round 3: the blade hangs out to the side, face out)")
		check(r.tip.Y > floorY + 0.3, tag .. string.format(" low hold: the tip stays off the floor (%.2f over it)", r.tip.Y - floorY))
		check(r.mid.X > 0.9 or r.mid.Z < front - 0.6, tag .. " low hold: the blade is clear of the legs")
	end
	check(r.grip.X > 0.3, tag .. " ready: the knife is on the right side, not across the body")
	-- round 3: at rest the blade shows its broad face to whoever stands in front (the Handle's Z is the blade's width,
	-- X its thickness): the width axis roughly perpendicular to the stand's look, the face toward it
	local look = rig.root.CFrame.LookVector
	local widthDot, faceDot = math.abs(r.handle.LookVector:Dot(look)), math.abs(r.handle.RightVector:Dot(look))
	check(widthDot < 0.35, tag .. string.format(" ready: the blade's width is across the view, not pointing at it (%.2f)", widthDot))
	check(faceDot > 0.75, tag .. string.format(" ready: the broad face looks out of the stand (%.2f)", faceDot))

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
				if (Show.sample(5, mid, styleKey).move ~= nil) == (f30[i - 1].p.pose.move ~= nil) then lo = mid else hi = mid end
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
		tag, j30, b30, e30, j60, b60))
	check(j30 < 45, tag .. ": no joint jumps more than 45 degrees in a frame (30 fps)")
	check(b30 < 65, tag .. ": the knife never turns more than 65 degrees in a frame (30 fps, twirls included)")
	check(e30 < 0.5, tag .. ": no jump where a move starts or ends")
	check(j60 < j30 * 0.65 and b60 < b30 * 0.65, tag .. ": twice the frame rate halves the steps (smooth, no pops)")

	-- moves on a cycle: one per loop, all three, trail only in moves
	local starts, names, trailOutside, trailFrames, lastMove, burstOutside = 0, {}, 0, 0, nil, 0
	for _, fr in f30 do
		local m = fr.p.pose.move
		if m and m ~= lastMove then starts += 1; names[m] = true end
		lastMove = m
		if fr.p.pose.trail then
			trailFrames += 1
			if not m then trailOutside += 1 end
		end
		if fr.p.pose.burst and not m then burstOutside += 1 end
	end
	local loops = seconds / Show.CYCLE
	check(starts >= math.floor(loops) - 1 and starts <= math.ceil(loops) + 1, tag .. ": a move every loop (" .. starts .. " in " .. seconds .. " s)")
	check(names[style.moves[1]] and names[style.moves[2]] and names[style.moves[3]], tag .. ": its three moves take turns")
	check(trailFrames > 0 and trailOutside == 0, tag .. ": the trail shows in the cuts only")
	check(burstOutside == 0, tag .. ": bursts only in moves")
	-- the swings are real swings: the tip travels far during a move
	local reach = 0
	for _, fr in f30 do
		if fr.p.pose.move then reach = math.max(reach, (fr.p.tip - r.tip).Magnitude) end
	end
	check(reach > 2.5, tag .. string.format(": the moves swing the blade wide (%.1f studs)", reach))

	-- 4. back to the hold after every move
	local back = 0
	for name, move in Show.compiled(style.hold) do
		local final = move.keys[#move.keys]
		for _, f in { "arm", "off", "waist", "neck" } do
			for i = 1, 3 do back = math.max(back, math.abs(final[f][i] - hold[f][i])) end
		end
		for _, f in { "elbow", "wrist", "offElbow", "drop" } do back = math.max(back, math.abs(final[f] - hold[f])) end
		back = math.max(back, math.abs((final.grip % 360) - (hold.grip % 360)), math.abs(final.spin % 360))
	end
	check(back < 1e-6, tag .. ": every move ends in its hold")

	-- 5. the feet stay planted (R15), except while the body spins round (then they turn with it and land where they stood)
	if kind == "R15" then
		local slide, low, high = 0, math.huge, -math.huge
		local first = f30[1].p.feet
		for _, fr in f30 do
			if math.abs(fr.p.pose.spin) < 1e-3 then
				for i = 1, 2 do
					slide = math.max(slide, (fr.p.feet[i].Position - first[i].Position).Magnitude)
					local bottom = fr.p.feet[i].Position.Y - 0.15
					low, high = math.min(low, bottom), math.max(high, bottom)
				end
			end
		end
		print(string.format("  %s feet: slide %.3f studs, soles %.3f to %.3f", tag, slide, low, high))
		check(slide < 0.08, tag .. ": the feet stay planted")
		check(low > -0.08 and high < 0.08, tag .. ": the feet stay on the floor")
	end
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
