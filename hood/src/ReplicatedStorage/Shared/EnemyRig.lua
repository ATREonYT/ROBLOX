-- (brief 29) The goons' bodies and their moves, client side (Waves.client). A goon is the user's HoodEnemies avatar when
-- the server has built its look (ReplicatedStorage.HoodEnemyModels, HoodServer/EnemyModels: a blocky R15 rig in catalog
-- clothes), else today's goon (Shared/GoonRig) stands in. Both take the same pose parameters, so the fight code doesn't
-- care which it has.
--   EnemyRig.build(look, kind, crew, variant, parent) -> rig { Model, Kind, Scale, Height, Head, Chest, R15 }
--   EnemyRig.pose(rig, root, p)   root = CFrame on the ground facing its LookVector; p = GoonRig's pose fields (walk,
--     stride, bob, lean, twist, look, guard, arms, punch, windup, flinch, ko) plus, for an R15 rig:
--       idle = clock (breathing and weight shift), crouch 0..1, move = a big move's name (EnemyRules.Moves) with
--       ready 0..1 (its anticipation, built up through the red telegraph) and strike 0..1 (the hit: snaps to 1, eases
--       back with a little overshoot), jump = studs off the ground, roar 0..1, tremble 0..1
--     (brief 30, "more fighting animations just like in the references") swing = a punch's kind (EnemyRules.Swings:
--       Jab, Hook, Uppercut, Kick, Shove, Haymaker) with windup 0..1 and punch (the strike curve); charge 0..1 (the run-in,
--       arms forward, like the reference's guards); flinchSide (a hit from the side twists it away); knock = Vector3
--       (studs, its own frame: X its right, Z its back: knocked back by a hit, a spring in Waves.client); fall = 'Back' |
--       'Forward' | 'Twist' with ko 0..1 (the fall) and pile 0..1 (settled into a heap: limbs folded, head loose beside
--       it, like the reference's dead guards)
--   EnemyRig.strike(t)            the strike curve: a fast snap, a short hold, a recovery that overshoots (-0.08) and settles
--   EnemyRig.ready(a)             the anticipation curve (slow start, quicker end)
-- (brief 30, the user: "make the animations smooth though, like in the references") Nothing snaps: every joint and the
-- body's own lean, turn and lunge ease toward the pose through Shared/JointSpring's damped springs, stepped with the
-- time since the rig's last pose (Waves.client and WorldBoss.client pose every rig once a frame, at PreRender), so each
-- new state (idle, run, wind-up, strike, hit, fall, heap) cross-fades in about 0.1-0.2 s, the arms follow through past
-- a strike and settle, the chest lags them and the head settles after a hit. p.snap = true lands exactly on the pose
-- (a rig just built or popped back). The box-built fallback (GoonRig) gets the same ease on its pose numbers.
-- R15 rigs are animated from code: every joint's Motor6D.Transform is set each frame (no animation assets: none can be
-- uploaded for this game), so the motion is crisp and keyed by hand: anticipation, a snap, a hold, recovery with
-- overshoot. Only the root part is anchored; Roblox's joint solver places the rest. EnemyRig.Solve = true (the offline
-- previews, which have no solver) places every part from the joints in Lua instead.
local RS = game:GetService('ReplicatedStorage')
local GoonRig = require(script.Parent.GoonRig)
local JointSpring = require(script.Parent.JointSpring)

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

local function fromTemplate(template, kind, parent, scaleTo)
	local model = template:Clone()
	-- (brief 29, P3b: the World Boss is a crew boss grown huge; Model:ScaleTo scales the clothes and accessories too)
	if scaleTo then pcall(function() model:ScaleTo(scaleTo) end) end
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

function EnemyRig.build(look, kind, crew, variant, parent, scaleTo)
	local template = EnemyRig.template(look)
	if template then
		local ok, rig = pcall(fromTemplate, template, kind, parent, scaleTo)
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
-- (brief 30) A knocked-out goon: the fall (FallTime, an ease-in like gravity, one small bounce), then it settles into
-- its heap (PileTime more) and lies there.
EnemyRig.FallTime, EnemyRig.PileTime = 0.28, 0.22
function EnemyRig.fallCurve(t)
	if t <= 0 then return 0, 0 end
	local k = math.min(1, t / EnemyRig.FallTime)
	local ko = k * k -- (gravity: slow off the feet, fast into the ground)
	if t > EnemyRig.FallTime and t < EnemyRig.FallTime + 0.16 then ko -= math.sin((t - EnemyRig.FallTime) / 0.16 * math.pi) * 0.06 end
	local pile = smooth((t - EnemyRig.FallTime * 0.7) / EnemyRig.PileTime)
	return ko, pile
end

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
	-- (brief 29, P3b) the Harbor Boss's anchor sweep: wound back over its right shoulder, then swung right across
	AnchorReady = { RightShoulder = { 2.2, -0.9, 0.6 }, RightElbow = { 0.9 }, LeftShoulder = { 2.0, -0.7, 0.3 }, LeftElbow = { 1.1 },
		Waist = { 0.15, -0.95 }, Neck = { 0.1, 0.4 }, LeftHip = { 0.4 }, LeftKnee = { -0.5 }, RightHip = { -0.2 } },
	AnchorStrike = { RightShoulder = { 1.3, 0.95, -0.2 }, RightElbow = { 0.15 }, LeftShoulder = { 1.2, 0.9, -0.4 }, LeftElbow = { 0.3 },
		Waist = { -0.25, 0.95 }, Neck = { -0.1, -0.35 }, LeftHip = { 0.7 }, LeftKnee = { -0.55 }, RightHip = { -0.45 } },
	roar = { LeftShoulder = { 2.4, 0, -0.95 }, LeftElbow = { 0.9 }, RightShoulder = { 2.4, 0, 0.95 }, RightElbow = { 0.9 },
		Waist = { 0.35 }, Neck = { 0.45 }, LeftHip = { 0.15 }, RightHip = { -0.15 } },
	ko = { LeftShoulder = { 2.7, 0, -0.7 }, LeftElbow = { 0.3 }, RightShoulder = { 2.7, 0, 0.7 }, RightElbow = { 0.3 },
		Neck = { 0.35 }, LeftHip = { 0.5 }, LeftKnee = { -0.5 }, RightHip = { 0.25 }, RightKnee = { -0.2 } },
	-- (brief 30) the run-in: arms reaching forward, chest down (the reference's guards charging at you)
	charge = { LeftShoulder = { 1.35, 0.12, -0.12 }, LeftElbow = { 0.35 }, RightShoulder = { 1.3, -0.12, 0.12 }, RightElbow = { 0.4 },
		Waist = { -0.1 }, Neck = { 0.12 } },
	-- (brief 30) the punches a goon throws in turn (EnemyRules.Swings): each a wind-up (Ready) and a hit (Strike)
	JabReady = { RightShoulder = { 0.9, 0.3, 0.1 }, RightElbow = { 2.1 }, LeftShoulder = { 1.4, -0.25, -0.1 }, LeftElbow = { 1.3 },
		Waist = { 0.04, -0.3 }, LeftHip = { 0.3 }, LeftKnee = { -0.35 } },
	JabStrike = { RightShoulder = { 1.6, -0.05, 0 }, RightElbow = { 0.05 }, LeftShoulder = { 1.2, -0.3, -0.2 }, LeftElbow = { 1.9 },
		Waist = { -0.12, 0.45 }, Neck = { -0.08 }, LeftHip = { 0.4 }, LeftKnee = { -0.3 }, RightHip = { -0.25 } },
	HookReady = { RightShoulder = { 1.0, -0.9, 0.9 }, RightElbow = { 1.6 }, LeftShoulder = { 1.3, -0.4, -0.1 }, LeftElbow = { 1.6 },
		Waist = { 0.08, -0.8 }, Neck = { 0, 0.4 }, RightHip = { -0.2 }, LeftHip = { 0.35 }, LeftKnee = { -0.45 } },
	HookStrike = { RightShoulder = { 1.45, 0.75, 0.55 }, RightElbow = { 1.15 }, LeftShoulder = { 0.9, -0.2, -0.3 }, LeftElbow = { 1.9 },
		Waist = { -0.1, 0.8 }, Neck = { -0.05, -0.35 }, LeftHip = { 0.45 }, LeftKnee = { -0.3 }, RightHip = { -0.35 } },
	UppercutReady = { RightShoulder = { -0.25, 0.2, 0.2 }, RightElbow = { 1.5 }, LeftShoulder = { 1.3, -0.4, -0.1 }, LeftElbow = { 1.6 },
		Waist = { -0.35, -0.35 }, Neck = { 0.25 }, LeftHip = { 0.7 }, LeftKnee = { -0.9 }, RightHip = { 0.55 }, RightKnee = { -0.8 } },
	UppercutStrike = { RightShoulder = { 2.5, -0.1, 0.1 }, RightElbow = { 1.3 }, LeftShoulder = { 0.9, -0.3, -0.2 }, LeftElbow = { 1.8 },
		Waist = { 0.18, 0.35 }, Neck = { -0.15 }, LeftHip = { 0.1 }, RightHip = { -0.15 } },
	KickReady = { RightHip = { 1.35 }, RightKnee = { -1.7 }, RightAnkle = { 0.3 }, LeftKnee = { -0.25 }, LeftShoulder = { 1.0, -0.4, -0.5 }, LeftElbow = { 1.4 },
		RightShoulder = { 0.6, 0.3, 0.6 }, RightElbow = { 1.2 }, Waist = { 0.15 } },
	KickStrike = { RightHip = { 1.55 }, RightKnee = { -0.1 }, RightAnkle = { -0.3 }, LeftKnee = { -0.2 }, LeftShoulder = { 0.5, -0.3, -0.9 }, LeftElbow = { 0.8 },
		RightShoulder = { 0.3, 0.3, 0.9 }, RightElbow = { 0.6 }, Waist = { 0.3 }, Neck = { -0.15 } },
	ShoveReady = { LeftShoulder = { 1.3, 0.2, -0.1 }, LeftElbow = { 2.0 }, RightShoulder = { 1.3, -0.2, 0.1 }, RightElbow = { 2.0 },
		Waist = { 0.2 }, Neck = { 0.1 }, RightHip = { -0.2 }, LeftHip = { 0.3 }, LeftKnee = { -0.4 } },
	ShoveStrike = { LeftShoulder = { 1.55, 0.1, 0 }, LeftElbow = { 0.1 }, RightShoulder = { 1.55, -0.1, 0 }, RightElbow = { 0.1 },
		Waist = { -0.3 }, Neck = { -0.1 }, LeftHip = { 0.55 }, LeftKnee = { -0.35 }, RightHip = { -0.4 } },
	HaymakerReady = { RightShoulder = { 2.9, -0.2, 0.4 }, RightElbow = { 1.4 }, LeftShoulder = { 2.7, 0.2, -0.4 }, LeftElbow = { 1.4 },
		Waist = { 0.35 }, Neck = { 0.25 }, LeftHip = { 0.3 }, LeftKnee = { -0.35 } },
	HaymakerStrike = { RightShoulder = { 1.2, -0.25, 0.1 }, RightElbow = { 0.3 }, LeftShoulder = { 1.1, 0.25, -0.1 }, LeftElbow = { 0.3 },
		Waist = { -0.55 }, Neck = { -0.25 }, LeftHip = { 0.85 }, LeftKnee = { -0.9 }, RightHip = { 0.6 }, RightKnee = { -0.7 } },
	-- (brief 30) the three falls (on the way down) and the heaps they end in (the reference's piles of dark limbs)
	FallBack = { LeftShoulder = { 2.4, 0, -1.0 }, LeftElbow = { 0.4 }, RightShoulder = { 2.4, 0, 1.0 }, RightElbow = { 0.4 },
		Neck = { -0.35 }, Waist = { 0.25 }, LeftHip = { 0.6 }, LeftKnee = { -0.7 }, RightHip = { 0.35 }, RightKnee = { -0.3 } },
	FallForward = { LeftShoulder = { 2.9, 0, -0.5 }, LeftElbow = { 0.3 }, RightShoulder = { 2.8, 0, 0.6 }, RightElbow = { 0.4 },
		Neck = { -0.3 }, Waist = { -0.4 }, LeftHip = { 1.0 }, LeftKnee = { -1.4 }, RightHip = { 0.8 }, RightKnee = { -1.2 } },
	FallTwist = { LeftShoulder = { 1.5, 0, 0.5 }, LeftElbow = { 0.6 }, RightShoulder = { 0.6, -0.4, 0.9 }, RightElbow = { 1.2 },
		Neck = { 0.2, 0.6 }, Waist = { 0.1, 0.6 }, LeftHip = { 0.7 }, LeftKnee = { -1.0 }, RightHip = { 0.2 }, RightKnee = { -0.4 } },
	PileBack = { LeftShoulder = { 0.3, 0, -1.45 }, LeftElbow = { 1.1 }, RightShoulder = { 2.6, 0, 1.25 }, RightElbow = { 0.7 },
		Neck = { -0.3, 0.5 }, Waist = { 0.15, 0.2 }, LeftHip = { 0.9, 0.5 }, LeftKnee = { -1.5 }, RightHip = { 0.25, -0.3 }, RightKnee = { -0.6 }, LeftAnkle = { 0.4 } },
	PileForward = { LeftShoulder = { 3.05, 0, -0.6 }, LeftElbow = { 1.2 }, RightShoulder = { 0.6, 0, 1.3 }, RightElbow = { 1.5 },
		Neck = { -0.4, -0.5 }, Waist = { -0.1, -0.2 }, LeftHip = { -0.25 }, LeftKnee = { -1.7 }, RightHip = { 0.5, 0.4 }, RightKnee = { -1.1 }, RightAnkle = { 0.5 } },
	PileTwist = { LeftShoulder = { 0.3, 0, 0.6 }, LeftElbow = { 1.6 }, RightShoulder = { 1.0, -0.3, 0.6 }, RightElbow = { 1.9 },
		Neck = { 0.2, 0.7 }, Waist = { 0.2, 0.4 }, LeftHip = { 1.3 }, LeftKnee = { -1.8 }, RightHip = { 0.9 }, RightKnee = { -1.5 } },
}
local ALIAS = { Volley = 'Throw', Leap = 'Stomp', Shockwave = 'Stomp', Forklift = 'Roll', Containers = 'Throw', Crew = 'Blast' } -- (Volley throws like Throw; Leap lands like a Stomp; P3b: the shockwave is a stomp, the forklift a shove, the crane a wave of the arm, the crew call a shout)
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
	-- (brief 30) the run-in: arms forward
	mix(q, POSES.charge, clamp(p.charge or 0, 0, 1))
	-- a punch: wind up, snap out, back to guard (brief 30: in its own kind, p.swing: a jab, a hook, an uppercut, a kick ...)
	local ready = p.swing and POSES[p.swing .. 'Ready'] or POSES.windup
	local hit = p.swing and POSES[p.swing .. 'Strike'] or POSES.punch
	mix(q, ready, clamp(p.windup or 0, 0, 1))
	local punch = p.punch or 0
	if punch > 0 then mix(q, hit, punch) elseif punch < 0 then mix(q, ready, -punch) end
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
	-- hit react: head and chest snap back, arms fly out (additive, a spring in Waves.client); (brief 30) a hit from the
	-- side twists the chest away and tips the head, the arm on that side flung out further
	local f = clamp(p.flinch or 0, -0.5, 0.6)
	local fs = clamp(p.flinchSide or 0, -0.6, 0.6)
	q.Waist[1] += f * 0.7
	q.Neck[1] += f * 0.9
	q.LeftShoulder[3] -= f * 0.6 + math.max(0, -fs) * 0.8
	q.RightShoulder[3] += f * 0.6 + math.max(0, fs) * 0.8
	q.LeftElbow[1] += f * 0.5
	q.RightElbow[1] += f * 0.5
	q.Waist[2] += fs * 0.55
	q.Waist[3] += fs * 0.35
	q.Neck[3] += fs * 0.5
	-- (brief 30) knocked out: the fall (its own way down), then the heap
	local ko, pile = clamp(p.ko or 0, 0, 1), clamp(p.pile or 0, 0, 1)
	if p.fall then
		mix(q, POSES['Fall' .. p.fall] or POSES.ko, ko)
		mix(q, POSES['Pile' .. p.fall], pile)
	else
		mix(q, POSES.ko, ko)
	end
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
-- (brief 30) Or falls forward onto its front about its toes, or turns and drops onto its side; the heap (pile) settles a
-- little lower and, for the side fall, rolls it on a little further.
local function koRoot(ko, s, fall, pile)
	if ko <= 0 then return CFrame.identity end
	pile = pile or 0
	if fall == 'Forward' then
		local ang = ko * math.pi / 2 * 0.97
		return CFrame.new(0, (0.3 - 0.12 * pile) * s * ko, -0.45 * s) * A(-ang, 0, 0) * CFrame.new(0, 0, 0.45 * s)
	elseif fall == 'Twist' then
		local ang = ko * math.pi / 2 * 0.95 + pile * 0.12
		return A(0, ko * 0.9, 0) * CFrame.new(-0.55 * s, (0.3 - 0.1 * pile) * s * ko, 0) * A(0, 0, ang) * CFrame.new(0.55 * s, 0, 0)
	end
	local ang = ko * math.pi / 2 * 0.97
	return CFrame.new(0, (0.25 - 0.08 * pile) * s * ko, 0.3 * s) * A(ang, 0, 0) * CFrame.new(0, 0, -0.3 * s)
end
-- (brief 30) In the heap the head lies loose beside the shoulders (the reference's dead guards: "the head loose beside
-- it"): the Neck joint's offset, in its own frame, per fall (+X its right, -Y toward the hips, +Z its back).
local HEAD_LOOSE = {
	Back = { Vector3.new(1.0, -0.45, -0.15), A(-0.2, 0.6, 1.1) },
	Forward = { Vector3.new(-1.05, -0.4, -0.25), A(-0.3, -0.5, -1.0) },
	Twist = { Vector3.new(0.15, -0.5, -0.95), A(-0.9, 0.2, 0.4) },
}

-- (brief 30) Down on the ground nothing sinks into it: on the way down and in the heap the body's lowest point is found
-- from the joints (part1 = part0 * C0 * Transform * C1^-1, as the engine places them) and the whole body is lifted
-- onto the floor. Settled heaps keep their lift instead of measuring again.
local function jointOrder(rig)
	if rig.Order then return rig.Order end
	local order, done, pending = {}, { [rig.Root] = true }, {}
	for name, m in rig.Joints do pending[name] = m end
	local moved = true
	while moved do
		moved = false
		for name, m in pending do
			if m.Part0 and m.Part1 and done[m.Part0] then
				table.insert(order, { name, m, m.Part0, m.Part1, m.C1:Inverse(), m.Part1.Size, m.Part1.Transparency < 1 })
				done[m.Part1] = true
				pending[name] = nil
				moved = true
			end
		end
	end
	rig.Order = order
	return order
end
local function lowestPoint(rig, base)
	local at = { [rig.Root] = base }
	local lo = math.huge
	for _, j in jointOrder(rig) do
		local p0 = at[j[3]]
		if p0 then
			local cf = p0 * j[2].C0 * (rig.Pose[j[1]] or CFrame.identity) * j[5]
			at[j[4]] = cf
			if j[7] then
				local s = j[6]
				lo = math.min(lo, cf.Y - 0.5 * (math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z))
			end
		end
	end
	return lo
end

-- (the pose numbers of the box-built fallback that change state by state; the rest are already smooth curves)
local EASED = { 'windup', 'punch', 'guard', 'charge', 'arms', 'flinch', 'flinchSide', 'lean', 'twist', 'ready', 'strike', 'roar', 'crouch' }
function EnemyRig.pose(rig, root, p)
	p = p or {}
	-- the time since this rig's last pose (0 on its first, or a second call in the same instant: then exactly the pose)
	local now = os.clock()
	local dt = rig.PoseAt and (now - rig.PoseAt) or 0
	rig.PoseAt = now
	rig.Springs = rig.Springs or JointSpring.new()
	local set = rig.Springs
	if p.snap then JointSpring.snap(set) end
	if not rig.R15 then
		local q0 = table.clone(p)
		for _, key in EASED do
			if q0[key] ~= nil or (set.scalars and set.scalars[key]) then q0[key] = JointSpring.scalar(set, key, q0[key] or 0, dt, 24, 0.8) end
		end
		JointSpring.done(set)
		p = q0
		-- today's goon: map the big moves onto its wind-up and punch (and a kick or a shove onto the punch too)
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
	local ko, pile = clamp(p.ko or 0, 0, 1), clamp(p.pile or 0, 0, 1)
	local knock = typeof(p.knock) == 'Vector3' and p.knock or Vector3.zero
	-- (the body's own offset rides a spring too: lean, turn, lunge and bob ease in and out)
	local off = JointSpring.step(set, 'Root', CFrame.new(0, y * (1 - ko), push) * A(-lean * (1 - ko), twist, 0), dt)
	local base = root * CFrame.new(knock.X, 0, knock.Z) * koRoot(ko, s, p.fall, pile) * CFrame.new(0, rig.HipY, 0) * off
	local pose = rig.Pose
	local loose = p.fall and pile > 0 and HEAD_LOOSE[p.fall] or nil
	for name, v in q do
		local cf = (name:find('Shoulder') and armCF(v)) or jointCF(v)
		if name == 'Neck' and loose then cf = CFrame.new(loose[1] * s * pile) * CFrame.identity:Lerp(loose[2], pile) * cf end
		pose[name] = JointSpring.step(set, name, cf, dt)
	end
	JointSpring.done(set)
	-- (on the ground: lifted so nothing sinks through the floor; a settled heap keeps the lift it measured)
	if ko > 0 then
		if not (rig.Lift and pile >= 1 and JointSpring.resting(set, 2e-3)) then
			rig.Lift = math.max(0, root.Y - lowestPoint(rig, base))
		end
		base = CFrame.new(0, rig.Lift, 0) * base
	else
		rig.Lift = nil
	end
	rig.Root.CFrame = base
	if not EnemyRig.Solve then
		for name, cf in pose do
			local m = rig.Joints[name]
			if m then m.Transform = cf end
		end
	end
	if EnemyRig.Solve then EnemyRig.solve(rig) end
end

-- Offline only: place every part from its joints (part1 = part0 * C0 * Transform * C1^-1), the way Roblox's solver does.
function EnemyRig.solve(rig)
	pcall(function() rig.Root.Position = rig.Root.CFrame.Position end)
	local done = { [rig.Root] = true }
	local pending = {}
	for name, m in rig.Joints do pending[name] = m end
	local moved = true
	while moved do
		moved = false
		for name, m in pending do
			if m.Part0 and m.Part1 and done[m.Part0] then
				m.Part1.CFrame = m.Part0.CFrame * m.C0 * (rig.Pose[name] or CFrame.identity) * m.C1:Inverse()
				pcall(function() m.Part1.Position = m.Part1.CFrame.Position end) -- (offline stand-ins keep Position apart)
				done[m.Part1] = true
				pending[name] = nil
				moved = true
			end
		end
	end
end

-- (brief 30) A heap is dark (the reference's piles of black limb blocks): every part, the clothes and the face darkened
-- by k (0..1). Once per rig (a rebuilt heap is darkened again when it is made).
function EnemyRig.darken(rig, k)
	if rig.Dark then return end
	rig.Dark = true
	local ink = Color3.new(0.08, 0.08, 0.1)
	for _, d in rig.Model:GetDescendants() do
		if d:IsA('BasePart') then
			d.Color = d.Color:Lerp(ink, k)
		elseif d:IsA('Clothing') or d:IsA('ShirtGraphic') then
			pcall(function() d.Color3 = Color3.new(1, 1, 1):Lerp(ink, k) end)
		elseif d:IsA('Decal') then
			pcall(function() d.Color3 = Color3.new(1, 1, 1):Lerp(ink, k * 0.8) end)
		end
	end
end

EnemyRig.smooth = smooth
return EnemyRig
