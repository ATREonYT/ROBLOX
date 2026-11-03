--!strict
-- Procedural poses for humanoid rigs (R15 and R6), shared by client cutscene actors and server NPCs (the clerk).
-- Placeholder for real animations: Config/Missions.Animations[gesture] ~= 0 makes actors play that animation instead.
--
-- Poses are rotations in the PARENT part's space (X right, Y up, -Z forward), as Euler degrees {x, y, z}
-- applied z first, then x, then y (CFrame.fromEulerAnglesYXZ):
--   z = raise sideways (right arm out = +z, left arm out = -z), x = swing forward (arm/leg forward = +x),
--   y = twist around the vertical. Neck x < 0 looks down; Waist x < 0 leans forward.
-- Converting to a joint: Transform = C0rot^-1 * R * C0rot, so the same numbers work on any rig's joint frames.
--   local joints = Rig.joints(model)
--   Rig.apply(joints, Rig.compose(state, now), "Transform")   -- client, every frame (Transform isn't replicated)
--   Rig.apply(joints, Rig.compose(state, now), "C0")          -- server (C0 replicates), e.g. the clerk's hands up
local Rig = {}

export type Joint = { motor: Motor6D, rot0: CFrame, c0: CFrame }
export type Joints = { [string]: Joint }

local NAMES: { [string]: string } = {
	Neck = "Neck",
	Waist = "Waist",
	RightShoulder = "RShoulder",
	["Right Shoulder"] = "RShoulder",
	LeftShoulder = "LShoulder",
	["Left Shoulder"] = "LShoulder",
	RightElbow = "RElbow",
	LeftElbow = "LElbow",
	RightHip = "RHip",
	["Right Hip"] = "RHip",
	LeftHip = "LHip",
	["Left Hip"] = "LHip",
	RightKnee = "RKnee",
	LeftKnee = "LKnee",
}

type Pose = { [string]: { number } }

-- Held poses (base layer). `_drop` = studs the root sits lower (sitting).
Rig.Poses = {
	None = {},
	Cross = { RShoulder = { 25, 0, -10 }, RElbow = { 100, 55, 0 }, LShoulder = { 25, 0, 10 }, LElbow = { 100, -55, 0 } },
	Lean = {
		RShoulder = { 25, 0, -10 },
		RElbow = { 100, 55, 0 },
		LShoulder = { 25, 0, 10 },
		LElbow = { 100, -55, 0 },
		Waist = { 7, 0, -3 },
		LHip = { 10, 0, -8 },
		Neck = { -4, 10, 0 },
	},
	Phone = { RShoulder = { 40, 0, -8 }, RElbow = { 85, 20, 0 }, LShoulder = { 30, 0, 8 }, LElbow = { 70, -30, 0 }, Neck = { -22, 0, 0 } },
	HandsUp = { RShoulder = { 0, 0, 85 }, RElbow = { 0, 0, 90 }, LShoulder = { 0, 0, -85 }, LElbow = { 0, 0, -90 }, Neck = { 8, 0, 0 }, Waist = { 4, 0, 0 } },
	Sit = { RHip = { 90, 0, 0 }, LHip = { 90, 0, 0 }, RKnee = { -90, 0, 0 }, LKnee = { -90, 0, 0 }, _drop = { 1.7 } },
	Point = { RShoulder = { 85, 0, -5 }, RElbow = { 5, 0, 0 } },
	Aim = { RShoulder = { 88, 0, -4 }, RElbow = { 4, 0, 0 }, LShoulder = { 80, 30, 0 }, LElbow = { 20, 0, 0 } },
	-- Piece 4 (the flat): seated variants. Same legs and drop as Sit.
	SitType = { RHip = { 90, 0, 0 }, LHip = { 90, 0, 0 }, RKnee = { -90, 0, 0 }, LKnee = { -90, 0, 0 }, RShoulder = { 62, 0, -4 }, RElbow = { 38, 0, 0 }, LShoulder = { 62, 0, 4 }, LElbow = { 38, 0, 0 }, Waist = { -6, 0, 0 }, Neck = { -8, 0, 0 }, _drop = { 1.7 } },
	SitSlump = { RHip = { 84, 0, 0 }, LHip = { 84, 0, 0 }, RKnee = { -80, 0, 0 }, LKnee = { -80, 0, 0 }, RShoulder = { 8, 0, -14 }, LShoulder = { 8, 0, 14 }, Waist = { 9, 0, 0 }, Neck = { -10, 0, 0 }, _drop = { 1.7 } },
	SitPhone = { RHip = { 90, 0, 0 }, LHip = { 90, 0, 0 }, RKnee = { -90, 0, 0 }, LKnee = { -90, 0, 0 }, RShoulder = { 40, 0, -8 }, RElbow = { 85, 20, 0 }, LShoulder = { 30, 0, 8 }, LElbow = { 70, -30, 0 }, Waist = { -4, 0, 0 }, Neck = { -24, 0, 0 }, _drop = { 1.7 } },
}

local S = math.sin

-- Gestures (top layer, play once). fn(localTime, duration) -> pose. Envelope in/out is added by compose().
Rig.Gestures = {
	Wave = function(lt: number): Pose
		return { RShoulder = { 0, 0, 145 }, RElbow = { 0, 0, 25 + 25 * S(lt * 9) } }
	end,
	Point = function(): Pose
		return Rig.Poses.Point
	end,
	Shrug = function(): Pose
		return { RShoulder = { 10, 0, 25 }, LShoulder = { 10, 0, -25 }, RElbow = { 80, -35, 0 }, LElbow = { 80, 35, 0 }, Neck = { 0, 0, 12 } }
	end,
	Nod = function(lt: number): Pose
		return { Neck = { -16 * math.abs(S(lt * 7)), 0, 0 } }
	end,
	Open = function(lt: number): Pose
		local w = 6 * S(lt * 5)
		return { RShoulder = { 35 + w, 0, 20 }, RElbow = { 60, -30, 0 }, LShoulder = { 35 - w, 0, -20 }, LElbow = { 60, 30, 0 } }
	end,
	Laugh = function(lt: number): Pose
		return { Waist = { -10 + 4 * S(lt * 14), 0, 0 }, Neck = { 12, 0, 0 }, RShoulder = { 15, 0, -6 }, LShoulder = { 15, 0, 6 } }
	end,
	Smash = function(lt: number): Pose
		local a = 30 * S(lt * 16)
		return { RShoulder = { 60 + a, 0, -6 }, LShoulder = { 60 - a, 0, 6 }, RElbow = { 40, 0, 0 }, LElbow = { 40, 0, 0 }, Neck = { -15, 0, 0 } }
	end,
	-- Act 2: handing something over (a bill, a card, an envelope): the right arm reaches out, palm up
	Give = function(lt: number): Pose
		local r = math.min(lt / 0.35, 1)
		return { RShoulder = { 70 * r, 0, -6 }, RElbow = { 25 * r, 0, 0 }, Neck = { -6, 0, 0 } }
	end,
	-- counting bills in front of the chest, the thumb flicking
	Count = function(lt: number): Pose
		local f = 4 * S(lt * 12)
		return { RShoulder = { 48, 0, -10 }, RElbow = { 75 + f, 25, 0 }, LShoulder = { 45, 0, 10 }, LElbow = { 80, -30, 0 }, Neck = { -24, 0, 0 } }
	end,
	Flop = function(): Pose
		return { Waist = { 22, 0, 0 }, RShoulder = { -10, 0, 30 }, LShoulder = { -10, 0, -30 } }
	end,
	-- Piece 4: poke the PC's power button; stretch after waking up
	Press = function(lt: number): Pose
		local jab = 10 * math.max(0, S(lt * 9))
		return { RShoulder = { 70 + jab, 0, -4 }, RElbow = { 18 - jab, 0, 0 }, Neck = { -6, 0, 0 } }
	end,
	Stretch = function(lt: number): Pose
		local w = 8 * S(lt * 3)
		return { RShoulder = { 0, 0, 155 + w }, LShoulder = { 0, 0, -155 - w }, RElbow = { 0, 0, 10 }, LElbow = { 0, 0, -10 }, Waist = { 8, 0, 0 }, Neck = { 14, 0, 0 } }
	end,
	HandsUp = function(lt: number): Pose
		local p = table.clone(Rig.Poses.HandsUp) :: any
		p.Neck = { 8 + 3 * S(lt * 20), 0, 0 } -- shaking
		return p
	end,
}

local function rad(v: { number }?): CFrame
	if not v then
		return CFrame.identity
	end
	return CFrame.fromEulerAnglesYXZ(math.rad(v[1] or 0), math.rad(v[2] or 0), math.rad(v[3] or 0))
end

local KEYS = { "Neck", "Waist", "RShoulder", "LShoulder", "RElbow", "LElbow", "RHip", "LHip", "RKnee", "LKnee" }

function Rig.joints(model: Instance): Joints
	local out: Joints = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			local key = NAMES[d.Name]
			if key and not out[key] then
				local c0 = d.C0
				out[key] = { motor = d, rot0 = c0.Rotation, c0 = c0 }
			end
		end
	end
	return out
end

function Rig.isR6(model: Instance): boolean
	local h = model:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.RigType == Enum.HumanoidRigType.R6
end

-- Height of the root part's centre above the ground (feet on the floor).
function Rig.rootHeight(model: Model): number
	local h = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not h or not root then
		return 3
	end
	if h.RigType == Enum.HumanoidRigType.R6 then
		return 3 * (root.Size.Y / 2)
	end
	return h.HipHeight + root.Size.Y / 2
end

local function blend(a: CFrame, b: CFrame, w: number): CFrame
	if w <= 0 then
		return a
	elseif w >= 1 then
		return b
	end
	return a:Lerp(b, w)
end

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

export type State = {
	pose: string?, -- held pose name (Rig.Poses)
	prevPose: string?,
	poseT0: number?, -- when `pose` started (blends in over 0.35 s)
	gesture: string?, -- Rig.Gestures name
	gestureT0: number?,
	gestureDur: number?,
	walk: number?, -- 0..1 how much the walk cycle shows
	walkPhase: number?, -- radians, advanced by distance walked
	lookYaw: number?, -- head turn in radians (+ = left), clamped by compose
	breath: boolean?, -- idle breathing (default on)
}

-- Rotations for every joint at time `now` (parent space). Missing joints are simply not driven.
function Rig.compose(s: State, now: number): { [string]: CFrame }
	local base: Pose = Rig.Poses[s.pose or "None"] or {}
	local prev: Pose = Rig.Poses[s.prevPose or "None"] or {}
	local wPose = smooth((now - (s.poseT0 or -10)) / 0.35)
	local g: Pose? = nil
	local wG = 0
	if s.gesture and Rig.Gestures[s.gesture] and s.gestureT0 then
		local lt = now - s.gestureT0
		local dur = s.gestureDur or 1.2
		if lt >= 0 and lt <= dur then
			g = Rig.Gestures[s.gesture](lt, dur)
			wG = math.min(smooth(lt / 0.25), smooth((dur - lt) / 0.3))
		end
	end
	local walk = s.walk or 0
	local ph = s.walkPhase or 0
	local out: { [string]: CFrame } = {}
	for _, k in KEYS do
		local cf = blend(rad(prev[k]), rad(base[k]), wPose)
		if g and g[k] then
			cf = blend(cf, rad(g[k]), wG)
		end
		if walk > 0 then
			local swing = math.sin(ph)
			local add: { number }? = nil
			if k == "RHip" then
				add = { 28 * swing, 0, 0 }
			elseif k == "LHip" then
				add = { -28 * swing, 0, 0 }
			elseif k == "RKnee" then
				add = { -25 * math.max(0, -swing), 0, 0 }
			elseif k == "LKnee" then
				add = { -25 * math.max(0, swing), 0, 0 }
			elseif k == "RShoulder" and not (g and g.RShoulder) and not base.RShoulder then
				add = { -18 * swing, 0, 0 }
			elseif k == "LShoulder" and not (g and g.LShoulder) and not base.LShoulder then
				add = { 18 * swing, 0, 0 }
			end
			if add then
				cf = rad({ add[1] * walk, 0, 0 }) * cf
			end
		end
		if k == "Waist" and s.breath ~= false then
			cf = cf * CFrame.fromEulerAnglesYXZ(math.rad(1.2 * math.sin(now * 1.7)), 0, 0)
		end
		if k == "Neck" and s.lookYaw then
			cf = CFrame.fromEulerAnglesYXZ(0, math.clamp(s.lookYaw, -0.8, 0.8), 0) * cf
		end
		out[k] = cf
	end
	return out
end

-- How far the root drops for the current held pose (sitting).
function Rig.drop(s: State): number
	local p = Rig.Poses[s.pose or "None"] :: any
	return if p and p._drop then p._drop[1] else 0
end

-- Writes rotations into the joints. mode "Transform" (client, per frame) or "C0" (server, replicates).
function Rig.apply(joints: Joints, rots: { [string]: CFrame }, mode: string?)
	for k, j in joints do
		local r = rots[k]
		if r then
			local t = j.rot0:Inverse() * r * j.rot0
			if mode == "C0" then
				j.motor.C0 = j.c0 * t
			else
				j.motor.Transform = t
			end
		end
	end
end

-- Back to the rest pose.
function Rig.reset(joints: Joints, mode: string?)
	for _, j in joints do
		if mode == "C0" then
			j.motor.C0 = j.c0
		else
			j.motor.Transform = CFrame.identity
		end
	end
end

return Rig
