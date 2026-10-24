--[[
	Crown Pose (a Robux cosmetic, Config/Products): the victory pose and its crown, as plain numbers, so the game
	(HuzzClient/Gameplay/CrownPose) and the offline video (tools/preview/motion3d/crown_scene.luau) show the same.
	  The pose: right fist punched up to the sky, left hand on the hip, chest out, chin up; it snaps in, pumps the
	  fist once, holds, and eases back into whatever you were doing (walking, standing).
	  The crown: a ring of five points with round gems, which drops onto your head with a bounce, spins slowly
	  and floats off at the end. Built from plain parts (no uploads needed).
]]
local CrownPose = {}

local rad = math.rad

CrownPose.LENGTH = 3.4 -- seconds, start to finish
local IN, OUT = 0.22, 0.45

-- Each R15 joint's pose (its Motor6D.Transform at full strength). R6 bodies keep their animation.
CrownPose.TARGET = {
	RightShoulder = CFrame.Angles(rad(-6), 0, rad(146)),
	RightElbow = CFrame.Angles(rad(8), 0, 0),
	RightWrist = CFrame.Angles(0, rad(30), 0),
	LeftShoulder = CFrame.Angles(rad(-6), 0, rad(-62)),
	LeftElbow = CFrame.Angles(0, 0, rad(112)),
	LeftWrist = CFrame.Angles(0, 0, rad(10)),
	Waist = CFrame.Angles(rad(-8), rad(8), 0),
	Neck = CFrame.Angles(rad(-14), rad(-8), 0),
	RightHip = CFrame.Angles(0, 0, rad(5)),
	LeftHip = CFrame.Angles(0, 0, rad(-5)),
}

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- How strongly the pose shows at t seconds (0..1): a fast snap in with a little overshoot, then a slow ease out.
function CrownPose.weight(t: number): number
	if t < 0 or t > CrownPose.LENGTH then return 0 end
	if t < IN then
		local x = t / IN
		return 1 - (1 - x) ^ 3
	end
	if t > CrownPose.LENGTH - OUT then return 1 - smooth((t - (CrownPose.LENGTH - OUT)) / OUT) end
	return 1
end

-- The fist pump: an extra lift of the raised arm a moment after it lands (radians).
local function pump(t: number): number
	local x = (t - 0.35) / 0.35
	if x < 0 or x > 1 then return 0 end
	return math.sin(x * math.pi) * rad(14)
end

-- Poses the joints (joints[name] = a Motor6D, or the preview's table) on top of their current Transform.
-- written (optional, kept by the caller between frames) remembers what we wrote: a joint no animation drives keeps
-- our last pose, so it blends from rest instead (otherwise the pose would never let go).
function CrownPose.apply(joints: { [string]: any }, t: number, written: { [string]: CFrame }?)
	local w = CrownPose.weight(t)
	for name, target in CrownPose.TARGET do
		local m = joints[name]
		if m then
			local now = m.Transform
			if written and written[name] and now == written[name] then now = CFrame.identity end
			if w <= 0 then
				if written and written[name] then m.Transform = now; written[name] = nil end
				continue
			end
			local goal = target
			if name == "RightShoulder" then goal = target * CFrame.Angles(0, 0, -pump(t)) end
			if name == "RightElbow" then goal = target * CFrame.Angles(pump(t) * 0.8, 0, 0) end
			m.Transform = now:Lerp(goal, w)
			if written then written[name] = m.Transform end
		end
	end
end

-- The crown: its parts relative to its centre (y up), for a head 1.2 studs wide (scaled by the head's size).
-- Each { shape = "Block" | "Ball", cf, size, kind = "Metal" | "Gem" }.
local POINTS = 5
CrownPose.RADIUS = 0.62
function CrownPose.parts(): { { shape: string, cf: CFrame, size: Vector3, kind: string } }
	local list = {}
	-- the band: short blocks round a ring (a ring from plain parts)
	local band = 14
	for i = 0, band - 1 do
		local a = i / band * math.pi * 2
		table.insert(list, {
			shape = "Block", kind = "Metal",
			cf = CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -CrownPose.RADIUS),
			size = Vector3.new(2 * math.pi * CrownPose.RADIUS / band + 0.03, 0.26, 0.09),
		})
	end
	for i = 0, POINTS - 1 do
		local a = i / POINTS * math.pi * 2
		local around = CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -CrownPose.RADIUS)
		-- a point: a square turned on its corner standing on the band (a diamond), a gem ball at its tip
		table.insert(list, { shape = "Block", kind = "Metal", cf = around * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.pi / 4), size = Vector3.new(0.3, 0.3, 0.08) })
		table.insert(list, { shape = "Ball", kind = "Gem", cf = around * CFrame.new(0, 0.46, 0), size = Vector3.new(0.13, 0.13, 0.13) })
		-- a gem on the band under each point
		table.insert(list, { shape = "Ball", kind = "Gem", cf = around * CFrame.new(0, 0, -0.04), size = Vector3.new(0.14, 0.14, 0.14) })
	end
	return list
end

-- Where the crown sits over the head at t (its height above the head's top, its spin, its scale 0..1).
function CrownPose.crownAt(t: number): (number, number, number)
	local spin = t * rad(40)
	if t < 0 or t > CrownPose.LENGTH then return 0, spin, 0 end
	if t < 0.5 then -- drops in from above with a bounce
		local x = t / 0.5
		local fall = 1 - x * x
		local bounce = if x > 0.75 then math.sin((x - 0.75) / 0.25 * math.pi) * 0.12 else 0
		return 1.6 * fall + bounce, spin, math.min(1, x * 2)
	end
	local endAt = CrownPose.LENGTH - 0.5
	if t > endAt then -- floats up and shrinks away
		local x = (t - endAt) / 0.5
		return 0.08 + x * 1.2, spin, 1 - smooth(x)
	end
	return 0.08 + math.sin((t - 0.5) * 3) * 0.04, spin, 1
end

return CrownPose
