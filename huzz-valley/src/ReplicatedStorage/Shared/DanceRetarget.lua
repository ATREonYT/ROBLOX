--[[
	Puts a dance on your companion girl (owner: "make the anime characters dance when you dance"; Oct 22 16:22 "make
	the girls dance with you"). Since Oct 22 the dances are R6 (his packs and ours, tools/anim): each R6 joint's turn
	is read in its parent part's space (through the R6 rig's own C0 turns) and put on her joints the same way, so an
	R6 girl gets the dance exactly and an R15 girl gets it on her matching joints (waist, elbows and knees straight).
	The older dances were R15 (the owner's 200-dance file); most girls are R6 (one torso, rigid arms and legs), so each frame's R15 pose
	(Shared/KeyframeSampler) is retargeted:
	  Torso (RootJoint)    <- LowerTorso then UpperTorso (their turns combined; the hips' bounce scaled to her size)
	  Head (Neck)          <- the Head
	  arms (shoulders)     <- where the whole R15 arm points (upper arm + forearm), so a bent elbow still aims right
	  legs (hips)          <- where the whole R15 leg points (thigh + shin), seen from her torso
	Each pose is worked out in the parent part's space and turned into the R6 joint's own C0 frame (R6 joints are
	turned 90°, R15's aren't). An R15 girl gets the dance as it is. Pure maths on joint tables (Shared/GirlMotion
	.joints), so the offline preview runs this exact code (tools/preview/motion3d/dance_scene.luau).
	procedural(): a cute built-in dance (sway, bounce, arm waves) when no dance file can be read.
]]
local DanceRetarget = {}
local rad, sin, pi, abs = math.rad, math.sin, math.pi, math.abs

local DOWN = Vector3.new(0, -1, 0)

-- The turn that takes direction a onto direction b (both unit).
local function fromTo(a: Vector3, b: Vector3): CFrame
	local d = math.clamp(a:Dot(b), -1, 1)
	if d > 0.99999 then
		return CFrame.identity
	end
	local axis = a:Cross(b)
	if axis.Magnitude < 1e-5 then
		axis = if abs(a.X) < 0.9 then a:Cross(Vector3.xAxis) else a:Cross(Vector3.zAxis)
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(d))
end
DanceRetarget.fromTo = fromTo

-- A pose in the parent part's space -> this joint's Transform, blended in by weight.
local function put(m, cf: CFrame, weight: number)
	if not m then
		return
	end
	local r = m.C0.Rotation
	local t = r:Inverse() * cf * r
	m.Transform = if weight >= 1 then t else m.Transform:Lerp(t, weight)
end
DanceRetarget.put = put

local function rot(pose, name)
	local cf = pose[name]
	return if cf then cf.Rotation else CFrame.identity
end

-- An R6 rig's joint turns (Roblox's standard R6 C0s, rotation only): each part's pose -> its parent's space.
local R6_C0 = {
	Torso = CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 1, 0)),
	Head = CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 1, 0)),
	["Right Arm"] = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, -1), Vector3.new(0, 1, 0), Vector3.new(1, 0, 0)),
	["Left Arm"] = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, 1), Vector3.new(0, 1, 0), Vector3.new(-1, 0, 0)),
	["Right Leg"] = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, -1), Vector3.new(0, 1, 0), Vector3.new(1, 0, 0)),
	["Left Leg"] = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, 1), Vector3.new(0, 1, 0), Vector3.new(-1, 0, 0)),
}
local R6_PARTS = { Root = "Torso", Neck = "Head", RShoulder = "Right Arm", LShoulder = "Left Arm", RHip = "Right Leg", LHip = "Left Leg" }
DanceRetarget.R6_C0 = R6_C0

-- Where a two-bone limb points, in its parent's space: upper turn, then the lower bone's turn after it.
local function limbDir(pose, upper, lower)
	local u, l = rot(pose, upper), rot(pose, lower)
	local d = u:VectorToWorldSpace(DOWN) + (u * l):VectorToWorldSpace(DOWN)
	return if d.Magnitude > 1e-4 then d.Unit else DOWN
end

--[[ J: joints by role (GirlMotion.joints). pose: partName -> CFrame (KeyframeSampler.sample). weight 0-1 over
	what's already on her joints this frame. scale: her size against an R15 avatar (for the hips' bounce). ]]
function DanceRetarget.apply(J, pose, weight: number, scale: number)
	if weight <= 0 then
		return
	end
	scale = scale or 1
	if pose.Torso then
		-- an R6 dance: Pose.CFrame is the R6 joint's Transform, turned by that joint's C0 into the parent part's space
		for joint, part in R6_PARTS do
			local t = pose[part]
			if t then
				local r = R6_C0[part]
				local cf = r * t * r:Inverse()
				local m = J[joint]
				if joint == "Root" and m and J.Waist then
					-- R15 girl (C.C., Oct 23 "make cc's body move normally"): her root joint sits at her hips, the R6
					-- one in the middle of the torso, so the dance's leans swung her whole body round her hips (head
					-- and feet up to 15% of her height off the R6 girls'). Turn her about her root's middle instead.
					local c0 = m.C0
					local want = c0:Inverse() * CFrame.new(cf.Position * scale) * cf.Rotation * c0
					m.Transform = if weight >= 1 then want else m.Transform:Lerp(want, weight)
				else
					if joint == "Root" then
						cf = CFrame.new(cf.Position * scale) * cf.Rotation
					else
						cf = cf.Rotation
					end
					put(m, cf, weight)
				end
			end
		end
		for _, joint in { "Waist", "LElbow", "RElbow", "LWrist", "RWrist", "LKnee", "RKnee", "LAnkle", "RAnkle" } do
			put(J[joint], CFrame.identity, weight)
		end
		return
	end
	if J.Waist then
		-- R15 girl: the dance as it is (the hips' movement scaled to her size)
		for _, m in J do
			local cf = m.Part1 and pose[m.Part1.Name]
			if cf then
				if m == J.Root then
					cf = CFrame.new(cf.Position * scale) * cf.Rotation
				end
				m.Transform = if weight >= 1 then cf else m.Transform:Lerp(cf, weight)
			end
		end
		return
	end
	local lower, upper = pose.LowerTorso or CFrame.identity, rot(pose, "UpperTorso")
	local torso = lower.Rotation * upper
	-- (her legs can't bend: a deep squat would sink her feet, so the hips only dip a little)
	local p = lower.Position * scale
	put(J.Root, CFrame.new(p.X, math.clamp(p.Y, -0.3 * scale, 0.6 * scale), p.Z) * torso, weight)
	put(J.Neck, rot(pose, "Head"), weight)
	for side, name in { L = "Left", R = "Right" } do
		local arm = limbDir(pose, name .. "UpperArm", name .. "LowerArm") -- (in the upper torso's space)
		put(J[side .. "Shoulder"], fromTo(DOWN, arm), weight)
		local leg = upper:Inverse():VectorToWorldSpace(limbDir(pose, name .. "UpperLeg", name .. "LowerLeg"))
		put(J[side .. "Hip"], fromTo(DOWN, leg), weight)
	end
end

--[[ The built-in dance: swaying hips, a bounce on every beat, arms waving overhead in turn, head bobbing.
	t: seconds since she started; works on R6 and R15 girls. ]]
function DanceRetarget.procedural(J, t: number, weight: number, scale: number)
	if weight <= 0 then
		return
	end
	scale = scale or 1
	local beat = t * 2 * pi * 1.1 -- ~132 beats a minute, two bounces a sway
	local sway = sin(beat / 2)
	local bounce = abs(sin(beat))
	put(J.Root, CFrame.new(0.25 * sway * scale, -0.18 * bounce * scale, 0) * CFrame.Angles(0, rad(10) * sway, rad(-7) * sway), weight)
	put(J.Waist, CFrame.Angles(0, -rad(6) * sway, rad(4) * sway), weight)
	put(J.Neck, CFrame.Angles(rad(8) * bounce - rad(4), 0, rad(10) * sway), weight)
	for side, sign in { L = -1, R = 1 } do
		-- one arm high and waving, the other low and pumping, swapping each sway
		local up = 0.5 + 0.5 * sign * sway
		local wave = sin(beat * 1.5 + (if sign > 0 then 0 else pi))
		put(J[side .. "Shoulder"], CFrame.Angles(rad(15) * (1 - up), 0, sign * (rad(20 + 135 * up) + rad(18) * wave * up)), weight)
		put(J[side .. "Elbow"], CFrame.Angles(rad(25 + 40 * (1 - up)), 0, 0), weight)
		put(J[side .. "Hip"], CFrame.Angles(rad(12) * bounce * (if sign * sway > 0 then 1 else 0.3), 0, sign * rad(4)), weight)
		put(J[side .. "Knee"], CFrame.Angles(-rad(22) * bounce, 0, 0), weight)
	end
end

return DanceRetarget
