-- (brief 29) The goons' bodies and their moves, client side (Waves.client). A goon is the user's HoodEnemies avatar when
-- the server has built its look (ReplicatedStorage.HoodEnemyModels, HoodServer/EnemyModels: a blocky R15 rig in catalog
-- clothes), else today's goon (Shared/GoonRig) stands in. Both take the same pose parameters, so the fight code doesn't
-- care which it has.
--   EnemyRig.build(look, kind, crew, variant, parent) -> rig { Model, Kind, Scale, Height, Head, Chest, R15 }
--   EnemyRig.pose(rig, root, p)   root = CFrame on the ground facing its LookVector; p = GoonRig's pose fields (walk,
--     stride, bob, lean, twist, look, guard, arms, punch, windup, flinch, ko) plus, for an R15 rig:
--       idle = clock (breathing and weight shift), crouch 0..1, move = a big move's name (EnemyRules.Moves) with
--       ready 0..1 (its anticipation, built up through the red telegraph) and strike 0..1 (the hit: snaps to 1, eases
--       back with a little overshoot), jump = studs off the ground, roar 0..1 (phase 2), tremble 0..1
--   EnemyRig.strike(t)            the strike curve: a fast snap, a short hold, a recovery that overshoots (-0.08) and settles
--   EnemyRig.ready(a)             the anticipation curve (slow start, quicker end)
-- R15 rigs are animated from code: every joint's Motor6D.Transform is set each frame (no animation assets: none can be
-- uploaded for this game), so the motion is crisp and keyed by hand: anticipation, a snap, a hold, recovery with
-- overshoot. Only the root part is anchored; Roblox's joint solver places the rest. EnemyRig.Solve = true (the offline
-- previews, which have no solver) places every part from the joints in Lua instead.
local RS = game:GetService('ReplicatedStorage')
local GoonRig = require(script.Parent.GoonRig)

local EnemyRig = {}
EnemyRig.FolderName = 'HoodEnemyModels'
EnemyRig.Solve = false

local A = CFrame.Angles
local clamp = math.clamp

-- The template for a look key (nil while it's being built, or when it never will be).
function EnemyRig.template(look)
	local folder = look and RS:FindFirstChild(EnemyRig.FolderName)
	return folder and folder:FindFirstChild(look) or nil
end

local function fromTemplate(template, kind, parent)
	local model = template:Clone()
	local root = model:FindFirstChild('HumanoidRootPart')
	local hum = model:FindFirstChildOfClass('Humanoid')
	local head = model:FindFirstChild('Head')
	if not root or not hum or not head then
		model:Destroy()
		return nil
	end
	for _, d in model:GetDescendants() do
		if d:IsA('BasePart') then
			d.Anchored = false
			d.CanCollide, d.CanTouch, d.CanQuery = false, false, false
		elseif d:IsA('BaseScript') then
			d:Destroy()
		end
	end
	root.Anchored = true
	root.Transparency = 1
	pcall(function() hum.EvaluateStateMachine = false end)
	pcall(function() hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff end)
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local joints = {}
	for _, d in model:GetDescendants() do
		if d:IsA('Motor6D') then joints[d.Name] = d end
	end
	local okS, scale = pcall(function() return model:GetScale() end)
	scale = okS and type(scale) == 'number' and scale or 1
	local box, size = model:GetBoundingBox()
	local feet = box.Position.Y - size.Y / 2
	-- (accessories can reach below the feet or far above the head: measure the body itself)
	local lo, hi = math.huge, -math.huge
	for _, name in { 'LeftFoot', 'RightFoot', 'Head' } do
		local p = model:FindFirstChild(name)
		if p and p:IsA('BasePart') then
			lo = math.min(lo, p.CFrame.Position.Y - p.Size.Y / 2)
			hi = math.max(hi, p.CFrame.Position.Y + p.Size.Y / 2)
		end
	end
	if lo < math.huge then feet = lo end
	local rig = {
		Model = model, Kind = kind, R15 = true, Joints = joints, Root = root, Head = head,
		Chest = model:FindFirstChild('UpperTorso') or head, Scale = scale,
		HipY = root.CFrame.Position.Y - feet, Height = (hi > -math.huge and hi or box.Position.Y + size.Y / 2) - feet,
		Pose = {},
	}
	model.Parent = parent
	return rig
end

function EnemyRig.build(look, kind, crew, variant, parent)
	local template = EnemyRig.template(look)
	if template then
		local ok, rig = pcall(fromTemplate, template, kind, parent)
		if ok and rig then
			rig.Look = look
			return rig
		end
	end
	local rig = GoonRig.build(kind, crew, variant, parent)
	rig.Chest = rig.Head
	return rig
end

---------------------------------------------------------------------------------------------- curves
local function smooth(a) a = clamp(a, 0, 1) return a * a * (3 - 2 * a) end
function EnemyRig.ready(a)
	a = clamp(a, 0, 1)
	return 1 - (1 - a * a) ^ 1.6 -- (slow start, settles into the held pose)
end
local SNAP, HOLD, BACK = 0.06, 0.1, 0.42
function EnemyRig.strike(t)
	if t < 0 then return 0 end
	if t < SNAP then
		local a = t / SNAP
		return 1 - (1 - a) ^ 3
	end
	if t < SNAP + HOLD then return 1 end
	local a = (t - SNAP - HOLD) / BACK
	if a >= 1 then return 0 end
	-- back toward 0, overshooting a touch past it, then settling
	local c = 1.7
	local e = 1 + (c + 1) * (a - 1) ^ 3 + c * (a - 1) ^ 2 -- (easeOutBack, 0 -> 1 with overshoot)
	return 1 - e
end
EnemyRig.StrikeTime = SNAP + HOLD + BACK

---------------------------------------------------------------------------------------------- poses (R15)
-- Joint angles {pitch, yaw, roll} in each joint's own frame (+pitch: an arm or leg swings forward; the waist and neck
-- lean back). Arms turn yaw-then-pitch-then-roll so a raised arm can point inward.
local POSES = {
	guard = { LeftShoulder = { 1.15, -0.4, -0.05 }, LeftElbow = { 1.75 }, RightShoulder = { 1.0, 0.35, 0.05 }, RightElbow = { 1.85 },
		LeftHip = { 0.2 }, LeftKnee = { -0.35 }, RightHip = { 0.1 }, RightKnee = { -0.3 }, Waist = { -0.06, 0.12 } },
	crossed = { LeftShoulder = { 0.75, -0.95, 0 }, LeftElbow = { 1.75 }, RightShoulder = { 0.7, 0.95, 0 }, RightElbow = { 1.8 }, Neck = { 0.08 } },
	windup = { RightShoulder = { 0.35, -0.35, 0.45 }, RightElbow = { 2.2 }, LeftShoulder = { 1.35, -0.5, -0.1 }, LeftElbow = { 1.5 },
		Waist = { 0.1, -0.55 }, RightHip = { -0.15 }, LeftHip = { 0.35 }, LeftKnee = { -0.45 } },
	punch = { RightShoulder = { 1.62, 0.18, 0 }, RightElbow = { 0.05 }, LeftShoulder = { 0.8, -0.25, -0.25 }, LeftElbow = { 2.0 },
		Waist = { -0.14, 0.6 }, LeftHip = { 0.45 }, LeftKnee = { -0.3 }, RightHip = { -0.3 }, Neck = { -0.1 } },
	-- big moves: ready (built up through the telegraph) and strike (the hit)
	StompReady = { LeftShoulder = { 2.95, 0, -0.3 }, LeftElbow = { 0.4 }, RightShoulder = { 2.95, 0, 0.3 }, RightElbow = { 0.4 },
		Waist = { 0.3 }, Neck = { 0.25 }, LeftHip = { 0.55 }, LeftKnee = { -0.5 } },
	StompStrike = { LeftShoulder = { 0.85, 0, -0.15 }, LeftElbow = { 0.25 }, RightShoulder = { 0.85, 0, 0.15 }, RightElbow = { 0.25 },
		Waist = { -0.55 }, Neck = { -0.2 }, LeftHip = { 1.0 }, LeftKnee = { -1.25 }, RightHip = { 1.0 }, RightKnee = { -1.25 }, LeftAnkle = { 0.3 }, RightAnkle = { 0.3 } },
	ChargeReady = { LeftShoulder = { -0.55, 0, -0.25 }, LeftElbow = { 0.7 }, RightShoulder = { -0.55, 0, 0.25 }, RightElbow = { 0.7 },
		Waist = { -0.45 }, Neck = { 0.4 }, LeftHip = { 0.75 }, LeftKnee = { -0.9 }, RightHip = { -0.35 }, RightKnee = { -0.4 } },
	ChargeStrike = { LeftShoulder = { -0.9, 0, -0.35 }, LeftElbow = { 0.5 }, RightShoulder = { 1.3, 0.4, 0.2 }, RightElbow = { 0.5 },
		Waist = { -0.65, 0.3 }, Neck = { 0.5 }, LeftHip = { 1.1 }, LeftKnee = { -0.6 }, RightHip = { -0.8 }, RightKnee = { -0.5 } },
	ThrowReady = { RightShoulder = { 2.75, -0.35, 0.35 }, RightElbow = { 1.35 }, LeftShoulder = { 1.45, -0.2, 0 }, LeftElbow = { 0.1 },
		Waist = { 0.3, -0.6 }, Neck = { -0.1, 0.3 }, LeftHip = { 0.45 }, LeftKnee = { -0.2 }, RightHip = { -0.25 } },
	ThrowStrike = { RightShoulder = { 1.25, 0.45, 0 }, RightElbow = { 0.1 }, LeftShoulder = { 0.2, 0, -0.45 }, LeftElbow = { 0.6 },
		Waist = { -0.4, 0.55 }, LeftHip = { 0.6 }, LeftKnee = { -0.45 }, RightHip = { -0.5 } },
	BlastReady = { LeftShoulder = { 0.6, 0.55, -0.4 }, LeftElbow = { 2.2 }, RightShoulder = { 0.6, -0.55, 0.4 }, RightElbow = { 2.2 },
		Waist = { 0.35 }, Neck = { 0.2 }, LeftHip = { 0.3 }, LeftKnee = { -0.3 } },
	BlastStrike = { LeftShoulder = { 1.55, -0.25, 0 }, LeftElbow = { 0 }, RightShoulder = { 1.55, 0.25, 0 }, RightElbow = { 0 },
		Waist = { -0.3 }, Neck = { -0.15 }, LeftHip = { 0.55 }, LeftKnee = { -0.4 }, RightHip = { -0.35 } },
	RollReady = { LeftShoulder = { -0.7, 0, -0.1 }, LeftElbow = { 0.3 }, RightShoulder = { -0.7, 0, 0.1 }, RightElbow = { 0.3 },
		Waist = { -0.55 }, Neck = { 0.45 }, LeftHip = { 1.0 }, LeftKnee = { -1.2 }, RightHip = { 0.8 }, RightKnee = { -1.1 } },
	RollStrike = { LeftShoulder = { 1.45, 0.15, -0.1 }, LeftElbow = { 0.1 }, RightShoulder = { 1.45, -0.15, 0.1 }, RightElbow = { 0.1 },
		Waist = { -0.3 }, LeftHip = { 0.7 }, LeftKnee = { -0.6 }, RightHip = { -0.2 } },
	roar = { LeftShoulder = { 2.4, 0, -0.95 }, LeftElbow = { 0.9 }, RightShoulder = { 2.4, 0, 0.95 }, RightElbow = { 0.9 },
		Waist = { 0.35 }, Neck = { 0.45 }, LeftHip = { 0.15 }, RightHip = { -0.15 } },
	ko = { LeftShoulder = { 2.7, 0, -0.7 }, LeftElbow = { 0.3 }, RightShoulder = { 2.7, 0, 0.7 }, RightElbow = { 0.3 },
		Neck = { 0.35 }, LeftHip = { 0.5 }, LeftKnee = { -0.5 }, RightHip = { 0.25 }, RightKnee = { -0.2 } },
}
local ALIAS = { Volley = 'Throw', Leap = 'Stomp' } -- (Volley throws like Throw; Leap lands like a Stomp)
EnemyRig.Poses = POSES

local JOINTS = { 'Waist', 'Neck', 'LeftShoulder', 'LeftElbow', 'RightShoulder', 'RightElbow', 'LeftHip', 'LeftKnee', 'LeftAnkle', 'RightHip', 'RightKnee', 'RightAnkle' }

local function mix(q, pose, w)
	if not pose or w == 0 then return end
	for name, v in pose do
		local cur = q[name]
		cur[1] += ((v[1] or 0) - cur[1]) * w
		cur[2] += ((v[2] or 0) - cur[2]) * w
		cur[3] += ((v[3] or 0) - cur[3]) * w
	end
end

-- The joint angles and the root's offset for pose p (pure: the unit tests and previews call it too).
function EnemyRig.angles(p)
	local q = {}
	for _, name in JOINTS do q[name] = { 0, 0, 0 } end
	local walk, stride = p.walk or 0, clamp(p.stride or 0, 0, 1)
	local sw = math.sin(walk) * stride
	local idle = p.idle or 0
	-- the walk/run cycle (arms against legs, knees fold on the swing, the chest counter-turns), or standing easy
	q.LeftHip[1], q.RightHip[1] = sw * 0.8, -sw * 0.8
	q.LeftKnee[1] = -stride * (0.15 + 0.95 * math.max(0, math.cos(walk)))
	q.RightKnee[1] = -stride * (0.15 + 0.95 * math.max(0, -math.cos(walk)))
	q.LeftAnkle[1], q.RightAnkle[1] = -q.LeftKnee[1] * 0.3, -q.RightKnee[1] * 0.3
	q.LeftShoulder[1], q.RightShoulder[1] = -sw * 0.75, sw * 0.75
	q.LeftElbow[1] = 0.2 + 0.45 * stride
	q.RightElbow[1] = 0.2 + 0.45 * stride
	q.Waist[2] = -sw * 0.15
	local rest = 1 - stride
	q.LeftShoulder[3] = -0.07 * rest - math.sin(idle * 2.1) * 0.025 * rest
	q.RightShoulder[3] = 0.07 * rest + math.sin(idle * 2.1) * 0.025 * rest
	q.Waist[1] = math.sin(idle * 2.1) * 0.025 * rest
	q.Neck[2] = math.sin(idle * 0.7) * 0.18 * rest
	mix(q, POSES.crossed, clamp(p.arms or 0, 0, 1) * rest)
	mix(q, POSES.guard, clamp(p.guard or 0, 0, 1))
	-- a punch: wind up, snap out, back to guard
	mix(q, POSES.windup, clamp(p.windup or 0, 0, 1))
	local punch = p.punch or 0
	if punch > 0 then mix(q, POSES.punch, punch) elseif punch < 0 then mix(q, POSES.windup, -punch) end
	-- a big move: its ready pose through the telegraph, then the strike
	if p.move then
		local m = ALIAS[p.move] or p.move
		mix(q, POSES[m .. 'Ready'], clamp(p.ready or 0, 0, 1))
		local s = p.strike or 0
		if s > 0 then mix(q, POSES[m .. 'Strike'], s) elseif s < 0 then mix(q, POSES[m .. 'Ready'], -s * 0.5) end
	end
	mix(q, POSES.roar, clamp(p.roar or 0, 0, 1))
	-- tension just before a big move lands: a fast shiver
	local tr = (p.tremble or 0) * 0.05
	if tr > 0 then
		local n = math.sin(idle * 61) * tr
		q.Waist[2] += n
		q.LeftShoulder[1] += n
		q.RightShoulder[1] -= n
	end
	-- hit react: head and chest snap back, arms fly out (additive, a spring in Waves.client)
	local f = clamp(p.flinch or 0, -0.5, 0.6)
	q.Waist[1] += f * 0.7
	q.Neck[1] += f * 0.9
	q.LeftShoulder[3] -= f * 0.6
	q.RightShoulder[3] += f * 0.6
	q.LeftElbow[1] += f * 0.5
	q.RightElbow[1] += f * 0.5
	mix(q, POSES.ko, clamp(p.ko or 0, 0, 1))
	-- the root: bob, dip into a crouch, lean (forward is -pitch), a turn, the lunge of a strike, the jump
	local s = p.scale or 1
	local crouch = clamp(p.crouch or 0, 0, 1)
	local y = (p.bob or 0) + math.abs(math.cos(walk)) * 0.18 * stride * s - crouch * 0.55 * s + (p.jump or 0)
	y -= (q.LeftKnee[1] < -0.8 and q.RightKnee[1] < -0.8) and 0.35 * s or 0
	local lean = (p.lean or 0) + 0.12 * stride - f * 0.25
	local push = f * 0.35 * s -- (knocked back a little)
	return q, y, lean, (p.twist or 0), push
end

local function armCF(v) return A(0, v[2], 0) * A(v[1], 0, 0) * A(0, 0, v[3]) end
local function jointCF(v) return A(v[1], v[2], v[3]) end

-- Knocked out: tips back about its heels (on the ground, a little behind the feet) and lies flat on its back at ko = 1.
local function koRoot(ko, s)
	if ko <= 0 then return CFrame.identity end
	local ang = ko * math.pi / 2 * 0.97
	return CFrame.new(0, 0.25 * s * ko, 0.3 * s) * A(ang, 0, 0) * CFrame.new(0, 0, -0.3 * s)
end

function EnemyRig.pose(rig, root, p)
	p = p or {}
	if not rig.R15 then
		-- today's goon: map the big moves onto its wind-up and punch
		if p.move then
			local q = table.clone(p)
			q.windup = math.max(q.windup or 0, (p.ready or 0) * 0.8)
			q.punch = math.max(q.punch or 0, p.strike or 0)
			q.lean = (q.lean or 0) + (p.move == 'Charge' and 0.25 * (p.ready or 0) or 0)
			q.bob = (q.bob or 0) + (p.jump or 0) - (p.crouch or 0) * 0.4
			p = q
		end
		return GoonRig.pose(rig, root, p)
	end
	local s = rig.Scale or 1
	p.scale = s
	local q, y, lean, twist, push = EnemyRig.angles(p)
	local ko = clamp(p.ko or 0, 0, 1)
	local base = root * koRoot(ko, s) * CFrame.new(0, rig.HipY + y * (1 - ko), push) * A(-lean * (1 - ko), twist, 0)
	rig.Root.CFrame = base
	local pose = rig.Pose
	for name, v in q do
		local cf = (name:find('Shoulder') and armCF(v)) or jointCF(v)
		pose[name] = cf
		local m = rig.Joints[name]
		if m and not EnemyRig.Solve then m.Transform = cf end
	end
	if EnemyRig.Solve then EnemyRig.solve(rig) end
end

-- Offline only: place every part from its joints (part1 = part0 * C0 * Transform * C1^-1), the way Roblox's solver does.
function EnemyRig.solve(rig)
	local done = { [rig.Root] = true }
	local pending = {}
	for name, m in rig.Joints do pending[name] = m end
	local moved = true
	while moved do
		moved = false
		for name, m in pending do
			if m.Part0 and m.Part1 and done[m.Part0] then
				m.Part1.CFrame = m.Part0.CFrame * m.C0 * (rig.Pose[name] or CFrame.identity) * m.C1:Inverse()
				done[m.Part1] = true
				pending[name] = nil
				moved = true
			end
		end
	end
end

EnemyRig.smooth = smooth
return EnemyRig
