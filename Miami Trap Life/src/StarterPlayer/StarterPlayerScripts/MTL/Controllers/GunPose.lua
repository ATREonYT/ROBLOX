--!strict
-- Gun body animation (Piece 5, rebuilt 2026-11-02). Procedural, full upper body, for every character holding a gun:
-- a two-bone arm solver puts the right hand on the grip and the left hand on the gun's Support attachment, the
-- spine and head follow the aim pitch, and timelines drive the draw, the shot (kick + slide / bolt / pump /
-- cylinder), and per-gun reloads (mag out, drop, new mag from the belt, insert, rack; revolver speed-loader;
-- shotgun shell-by-shell + pump). Nothing here needs an uploaded animation: it runs after the Animator each
-- frame (PreSimulation) and blends over whatever the character is playing (walk, idle), so legs keep walking.
--
-- Works on Motor6D and AnimationConstraint rigs (this place's avatars): both expose C0/C1 frames (Motor6D C0/C1,
-- AnimationConstraint Attachment0/1) and a Transform the engine applies on top.
--
-- Gun model contract (ReplicatedStorage.MTL_Assets.Guns.<Model>, see Services/GunModels):
--   Handle (grip, -Z = barrel) with Attachments Grip, Muzzle, Support (left hand), Eject (shell port)
--   parts with attribute GunRole = "Mag" | "Slide" | "Pump" | "Cylinder" get a Motor6D "Role_<role>" to the Handle
--
-- API (GunController):
--   GunPose.init()
--   GunPose.setLocal(pitchDeg, raised)        your own aim, every frame
--   GunPose.kick(back, rotDeg)                your own shot (recoil through the arms)
--   GunPose.fired(char?)                      a shot by any character (slide / pump / cylinder / shell)
--   GunPose.reload(char?, seconds)            start the reload timeline (nil char = you)
--   GunPose.cancelReload(char?)
--   GunPose.solve(char, st) -> frames         pure: world CFrames for the posed parts (used by the Edit preview)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Guns = require(ReplicatedStorage.MTL.Config.Guns)

local GunPose = {}
GunPose.enabled = true

---------------------------------------------------------------- poses (handle CFrame in the aim frame)
-- Aim frame: origin at shoulder height in the middle of the chest, X right, Y up, -Z where you aim (pitched).
-- Low poses are in the same frame but use only part of the pitch (see LOW_PITCH).
local rad = math.rad
local CF = CFrame.new
local ANG = CFrame.Angles

type Style = {
	aim: CFrame,
	low: CFrame,
	lowLeft: number, -- left hand on the gun at low ready (0 = arm hangs, 1 = on the gun)
	aimLeft: number,
	magDrop: number, -- how far the mag slides out before it falls
	kind: string, -- "mag" | "revolver" | "shotgun"
	holster: CFrame, -- where the hand starts the draw (hip / back)
}

local STYLES: { [string]: Style } = {
	Pistol = {
		aim = CF(0.12, -0.28, -1.6),
		low = CF(0.95, -1.25, -0.75) * ANG(rad(-62), rad(10), rad(4)),
		lowLeft = 0,
		aimLeft = 1,
		magDrop = 0.55,
		kind = "mag",
		holster = CF(1.05, -1.75, 0.05) * ANG(rad(-95), 0, 0),
	},
	Revolver = {
		aim = CF(0.12, -0.28, -1.6),
		low = CF(0.95, -1.25, -0.75) * ANG(rad(-62), rad(10), rad(4)),
		lowLeft = 0,
		aimLeft = 1,
		magDrop = 0,
		kind = "revolver",
		holster = CF(1.05, -1.75, 0.05) * ANG(rad(-95), 0, 0),
	},
	Uzi = {
		aim = CF(0.38, -0.25, -1.7),
		low = CF(0.55, -0.95, -1.05) * ANG(rad(-38), rad(22), 0),
		lowLeft = 1,
		aimLeft = 1,
		magDrop = 0.75,
		kind = "mag",
		holster = CF(1.05, -1.7, 0.05) * ANG(rad(-95), 0, 0),
	},
	AK = {
		aim = CF(0.5, -0.45, -0.55) * ANG(0, rad(7), 0),
		low = CF(0.5, -1.0, -0.75) * ANG(rad(-30), rad(38), rad(8)),
		lowLeft = 1,
		aimLeft = 1,
		magDrop = 0.85,
		kind = "mag",
		holster = CF(0.7, 0.2, 0.9) * ANG(rad(70), rad(150), 0),
	},
	Shotgun = {
		aim = CF(0.5, -0.45, -0.55) * ANG(0, rad(7), 0),
		low = CF(0.5, -1.0, -0.75) * ANG(rad(-30), rad(38), rad(8)),
		lowLeft = 1,
		aimLeft = 1,
		magDrop = 0,
		kind = "shotgun",
		holster = CF(0.7, 0.2, 0.9) * ANG(rad(70), rad(150), 0),
	},
}
GunPose.STYLES = STYLES

local LOW_PITCH = 0.35 -- share of the aim pitch the low-ready pose follows
local SPINE_PITCH = 0.3 -- share of the pitch taken by the waist (the rest by the shoulders)
local NECK_PITCH = 0.45
local BELT = CF(-0.55, -1.45, 0.15) -- left hand reaches here for a new mag / shells (aim-frame, no pitch)

local function styleOf(gunId: string?): Style
	local def = gunId and Guns.Defs[gunId]
	local model = def and def.Model or "Pistol"
	return STYLES[model] or STYLES.Pistol
end

---------------------------------------------------------------- tiny curve helpers

local function clamp01(x: number): number
	return if x < 0 then 0 elseif x > 1 then 1 else x
end
local function smooth(x: number): number
	x = clamp01(x)
	return x * x * (3 - 2 * x)
end
-- 0 before a, eased 0..1 between a and b, 1 after
local function seg(u: number, a: number, b: number): number
	return smooth((u - a) / (b - a))
end
local function backOut(x: number): number
	x = clamp01(x)
	local c1, c3 = 1.4, 2.4
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

---------------------------------------------------------------- rig access

type Joint = { inst: Instance, c0: CFrame, c1: CFrame }
type Rig = {
	root: Joint?, waist: Joint?, neck: Joint?,
	rs: Joint?, re: Joint?, rw: Joint?,
	ls: Joint?, le: Joint?, lw: Joint?,
	hrp: BasePart,
}

local function jointOf(part: Instance?, name: string): Joint?
	local j = part and part:FindFirstChild(name)
	if not j then
		return nil
	end
	if j:IsA("Motor6D") then
		return { inst = j, c0 = j.C0, c1 = j.C1 }
	elseif j.ClassName == "AnimationConstraint" then
		local a0 = (j :: any).Attachment0 :: Attachment?
		local a1 = (j :: any).Attachment1 :: Attachment?
		if a0 and a1 then
			return { inst = j, c0 = a0.CFrame, c1 = a1.CFrame }
		end
	end
	return nil
end

local rigCache: { [Model]: Rig } = {}
local function rigOf(char: Model): Rig?
	local r = rigCache[char]
	if r and r.rs and r.rs.inst.Parent and r.hrp.Parent then
		return r
	end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp or not char:FindFirstChild("RightUpperArm") then
		return nil
	end
	local nr: Rig = {
		hrp = hrp,
		root = jointOf(char:FindFirstChild("LowerTorso"), "Root"),
		waist = jointOf(char:FindFirstChild("UpperTorso"), "Waist"),
		neck = jointOf(char:FindFirstChild("Head"), "Neck"),
		rs = jointOf(char:FindFirstChild("RightUpperArm"), "RightShoulder"),
		re = jointOf(char:FindFirstChild("RightLowerArm"), "RightElbow"),
		rw = jointOf(char:FindFirstChild("RightHand"), "RightWrist"),
		ls = jointOf(char:FindFirstChild("LeftUpperArm"), "LeftShoulder"),
		le = jointOf(char:FindFirstChild("LeftLowerArm"), "LeftElbow"),
		lw = jointOf(char:FindFirstChild("LeftHand"), "LeftWrist"),
	}
	if not (nr.root and nr.waist and nr.rs and nr.re and nr.rw and nr.ls and nr.le and nr.lw) then
		return nil
	end
	rigCache[char] = nr
	return nr
end

local function transformOf(j: Joint?): CFrame
	if not j then
		return CFrame.identity
	end
	return (j.inst :: any).Transform
end

local function setTransform(j: Joint?, t: CFrame)
	if j then
		(j.inst :: any).Transform = t
	end
end

-- Transform that puts part1 at world cf1 given part0 at world cf0
local function solveT(j: Joint, cf0: CFrame, cf1: CFrame): CFrame
	return j.c0:Inverse() * cf0:Inverse() * cf1 * j.c1
end

---------------------------------------------------------------- two-bone arm

-- frame whose -Y runs along `bone` and whose -Z leans toward `bend` (both world), as a rotation
local function boneFrame(bone: Vector3, bend: Vector3): CFrame
	local y = -bone.Unit
	local f = bend - y * bend:Dot(y)
	if f.Magnitude < 1e-4 then
		f = Vector3.new(0, 0, -1) - y * (-y.Z)
		if f.Magnitude < 1e-4 then
			f = Vector3.xAxis
		end
	end
	local z = -f.Unit
	local x = y:Cross(z)
	return CFrame.fromMatrix(Vector3.zero, x, y, z)
end

type ArmOut = { upper: CFrame, lower: CFrame, hand: CFrame }

-- shoulder joint s (UpperTorso -> UpperArm), elbow e, wrist w. torsoCF = UpperTorso world CFrame.
-- handCF = where the hand should be. pole = world direction the elbow points to.
local function solveArm(s: Joint, e: Joint, w: Joint, torsoCF: CFrame, handCF: CFrame, pole: Vector3): ArmOut
	-- The elbow is a real hinge (its own X axis), and R15's shoulder pivot sits off the arm's centre line, so
	-- the upper-arm bone isn't perpendicular to the hinge. Solve the elbow angle for the reach first, then the
	-- one shoulder rotation that points the whole chain at the wrist with the elbow toward the pole.
	local S = (torsoCF * s.c0).Position
	local boneU = e.c0.Position - s.c1.Position -- shoulder pivot -> elbow pivot (UpperArm space)
	local boneL = w.c0.Position - e.c1.Position -- elbow pivot -> wrist pivot (LowerArm space)
	local Wt = (handCF * w.c1).Position -- where the wrist pivot should go
	local want = (Wt - S).Magnitude
	local function chain(theta: number): Vector3
		return boneU + e.c0.Rotation * ANG(theta, 0, 0) * e.c1.Rotation:Inverse() * boneL
	end
	-- reach shrinks as the elbow bends (0 .. 150 deg): bisect
	local lo, hi = 0, rad(150)
	if chain(lo).Magnitude <= want then
		hi = 0
	elseif chain(hi).Magnitude >= want then
		lo = hi
	else
		for _ = 1, 18 do
			local mid = (lo + hi) / 2
			if chain(mid).Magnitude > want then
				lo = mid
			else
				hi = mid
			end
		end
	end
	local theta = (lo + hi) / 2
	local q = chain(theta)
	-- local frame: a1 along the chain, a2 toward the elbow
	local a1 = q.Unit
	local a2 = boneU - a1 * boneU:Dot(a1)
	a2 = if a2.Magnitude > 1e-4 then a2.Unit else Vector3.new(0, 0, 1)
	local dirW = Wt - S
	local b1 = if dirW.Magnitude > 1e-4 then dirW.Unit else Vector3.new(0, -1, 0)
	local b2 = pole - b1 * pole:Dot(b1)
	b2 = if b2.Magnitude > 1e-4 then b2.Unit else Vector3.new(0, -1, 0)
	local A = CFrame.fromMatrix(Vector3.zero, a1, a2, a1:Cross(a2))
	local B = CFrame.fromMatrix(Vector3.zero, b1, b2, b1:Cross(b2))
	local R = B * A:Inverse()
	local upper = CFrame.new(S) * R * s.c1:Inverse()
	local lower = upper * e.c0 * ANG(theta, 0, 0) * e.c1:Inverse()
	local wrist = (lower * w.c0).Position
	local rotH = handCF.Rotation
	local hand = CFrame.new(wrist - rotH:VectorToWorldSpace(w.c1.Position)) * rotH
	return { upper = upper, lower = lower, hand = hand }
end

---------------------------------------------------------------- per-character state

type CharState = {
	gunId: string?,
	equipAt: number, -- os.clock() the gun came out
	raise: number, -- 0 low .. 1 aimed (eased)
	pitch: number, -- smoothed aim pitch (deg)
	reloadStart: number, -- os.clock(), 0 = none
	reloadLen: number,
	lastShot: number,
	shotCount: number,
	kickZ: number, -- studs, gun pushed back
	kickR: number, -- deg, muzzle up
	kickV: number,
	kickRV: number,
	magDropped: boolean,
	swayYaw: number,
	lastYaw: number?,
	seenReload: number?,
	pumped: boolean,
	tucked: boolean, -- gun in the waistband while an MTL_Action (e.g. the robbery's Grab) owns the arms
}

local states: { [Model]: CharState } = {}
local function stateOf(char: Model): CharState
	local s = states[char]
	if not s then
		s = {
			gunId = nil,
			equipAt = 0,
			raise = 0,
			pitch = 0,
			reloadStart = 0,
			reloadLen = 1,
			lastShot = -10,
			shotCount = 0,
			kickZ = 0,
			kickR = 0,
			kickV = 0,
			kickRV = 0,
			magDropped = false,
			swayYaw = 0,
			lastYaw = nil,
			seenReload = nil,
			pumped = true,
			tucked = false,
		}
		states[char] = s
	end
	return s :: CharState
end

local localPitch, localRaised = 0, false

function GunPose.setLocal(pitchDeg: number, raised: boolean)
	localPitch = pitchDeg
	localRaised = raised
end

local function me(): Model?
	return Players.LocalPlayer and Players.LocalPlayer.Character
end

function GunPose.kick(back: number, rotDeg: number)
	local c = me()
	if not c then
		return
	end
	local s = stateOf(c)
	s.kickV += back * 38
	s.kickRV += rotDeg * 38
end

local shellAt: (Model, CharState) -> () -- forward

function GunPose.fired(char: Model?)
	local c = char or me()
	if not c then
		return
	end
	local s = stateOf(c)
	s.lastShot = os.clock()
	s.shotCount += 1
	s.pumped = false
	if c ~= me() then
		-- other players: same kick feel, from the gun's own numbers
		local def = s.gunId and Guns.Defs[s.gunId]
		if def then
			s.kickV += def.Recoil.Kick * 38
			s.kickRV += def.Recoil.KickRot * 38
		end
	end
	local style = STYLES[(s.gunId and Guns.Defs[s.gunId] and Guns.Defs[s.gunId].Model) or "Pistol"] or STYLES.Pistol
	if style.kind == "mag" then
		shellAt(c, s)
	end
end

function GunPose.reload(char: Model?, seconds: number)
	local c = char or me()
	if not c then
		return
	end
	local s = stateOf(c)
	s.reloadStart = os.clock()
	s.reloadLen = math.max(seconds, 0.3)
	s.magDropped = false
end

function GunPose.cancelReload(char: Model?)
	local c = char or me()
	if c and states[c] then
		states[c].reloadStart = 0
	end
end

---------------------------------------------------------------- gun parts (mag / slide / pump / cylinder)

type RolePart = { part: BasePart, motor: Motor6D? }
type GunParts = { model: Model, handle: BasePart, grip: Motor6D?, roles: { [string]: RolePart }, support: Attachment?, eject: Attachment? }

local function gunParts(char: Model): GunParts?
	local m = char:FindFirstChild("MTL_Gun")
	if not m or not m:IsA("Model") then
		return nil
	end
	local h = m.PrimaryPart
	if not h then
		return nil
	end
	local roles: { [string]: RolePart } = {}
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") then
			local r = p:GetAttribute("GunRole")
			if type(r) == "string" then
				roles[r] = { part = p, motor = h:FindFirstChild("Role_" .. r) :: Motor6D? }
			end
		end
	end
	return {
		model = m,
		handle = h,
		grip = h:FindFirstChild("MTL_GunGrip") :: Motor6D?,
		roles = roles,
		support = h:FindFirstChild("Support") :: Attachment?,
		eject = h:FindFirstChild("Eject") :: Attachment?,
	}
end

---------------------------------------------------------------- debris: falling mag, brass

local function debrisFolder(): Instance
	local f = Workspace:FindFirstChild("MTL_GunFX_Local")
	if not f then
		local nf = Instance.new("Folder")
		nf.Name = "MTL_GunFX_Local"
		nf.Parent = Workspace
		f = nf
	end
	return f :: Instance
end

local brassPool: { BasePart } = {}
local function brass(color: Color3, size: Vector3): BasePart
	local p = table.remove(brassPool)
	if not p then
		local np = Instance.new("Part")
		np.Name = "Brass"
		np.Shape = Enum.PartType.Cylinder
		np.Material = Enum.Material.Metal
		np.CanQuery = false
		np.CanTouch = false
		np.CastShadow = false
		np.Massless = true
		p = np
	end
	assert(p)
	p.Size = size
	p.Color = color
	p.Transparency = 0
	p.CanCollide = true
	p.Anchored = false
	return p
end

local function dropBrass(cf: CFrame, vel: Vector3, color: Color3, size: Vector3)
	local p = brass(color, size)
	p.CFrame = cf
	p.Parent = debrisFolder()
	p.AssemblyLinearVelocity = vel
	p.AssemblyAngularVelocity = Vector3.new(math.random(-30, 30), math.random(-30, 30), math.random(-30, 30))
	task.delay(1.6, function()
		p.Parent = nil
		if #brassPool < 40 then
			table.insert(brassPool, p)
		end
	end)
end

shellAt = function(char: Model, s: CharState)
	local gp = gunParts(char)
	if not gp or not gp.eject then
		return
	end
	local cf = gp.eject.WorldCFrame
	local right = gp.handle.CFrame.RightVector
	local up = gp.handle.CFrame.UpVector
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local base = if hrp then hrp.AssemblyLinearVelocity else Vector3.zero
	local big = s.gunId == "AK"
	dropBrass(cf * CFrame.Angles(0, rad(90), 0), base + right * math.random(9, 13) + up * math.random(5, 8), Color3.fromRGB(201, 158, 70), if big then Vector3.new(0.18, 0.07, 0.07) else Vector3.new(0.12, 0.06, 0.06))
end

local function dropMag(gp: GunParts, magPart: BasePart)
	local c = magPart:Clone()
	for _, d in c:GetChildren() do
		if not (d:IsA("SpecialMesh") or d:IsA("SurfaceAppearance") or d:IsA("Decal") or d:IsA("Texture")) then
			d:Destroy()
		end
	end
	c.Anchored = false
	c.CanCollide = true
	c.CanQuery = false
	c.CanTouch = false
	c.Massless = false
	c.LocalTransparencyModifier = 0
	c.CFrame = magPart.CFrame
	c.Parent = debrisFolder()
	c.AssemblyLinearVelocity = -gp.handle.CFrame.UpVector * 6
	c.AssemblyAngularVelocity = gp.handle.CFrame.RightVector * 4
	task.delay(4, function()
		c:Destroy()
	end)
end

---------------------------------------------------------------- the pose

export type SolveIn = {
	gunId: string,
	pitch: number, -- deg
	raise: number, -- 0..1
	equip: number, -- 0..1 draw progress (1 = done)
	reload: number?, -- 0..1 or nil
	sinceShot: number, -- seconds since the last shot
	kickZ: number,
	kickR: number,
	bob: Vector3, -- small sway / walk bob in world studs
	swayYaw: number, -- deg, the gun trails turns
	shotCount: number,
}

export type Frames = {
	lower: CFrame,
	upper: CFrame,
	head: CFrame?,
	right: ArmOut,
	left: ArmOut?,
	leftWeight: number,
	handle: CFrame,
	roles: { [string]: CFrame }, -- role part offsets (handle space)
	hideMag: boolean,
}

-- Reload timelines, u = 0..1. Returns: extra handle motion (handle space), how far the left hand is toward the
-- belt (0 = on the gun, 1 = at the belt), role part offsets (handle space), whether the mag is hidden.
local function reloadMotion(style: Style, u: number): (CFrame, number, { [string]: CFrame }, boolean)
	local roles: { [string]: CFrame } = {}
	local tilt = seg(u, 0, 0.12) * (1 - seg(u, 0.86, 1))
	if style.kind == "mag" then
		-- tilt the gun in and roll it so the mag well faces the left hand
		local pull = if style.aim.Position.Z > -1 then 0.08 else 0.35 -- shouldered guns barely come back (they'd go into the chest)
		local move = CF(-0.12 * tilt, 0.12 * tilt, pull * tilt) * ANG(rad(14 * tilt), rad(-8 * tilt), rad(28 * tilt))
		-- old mag slides out (0.10-0.20) and falls (0.22); hand to the belt and back up with a new one (0.22-0.60),
		-- seats it (0.62-0.70), racks the slide / bolt (0.74-0.83)
		local belt = seg(u, 0.18, 0.34) * (1 - seg(u, 0.42, 0.6))
		local hide = u >= 0.22 and u < 0.42
		if u < 0.22 then
			local out = seg(u, 0.1, 0.2)
			roles.Mag = CF(0, -style.magDrop * out, 0.04 * out)
		elseif u < 0.62 then
			roles.Mag = CF(0, -style.magDrop * (1 - 0.75 * seg(u, 0.42, 0.6)), 0)
		else
			roles.Mag = CF(0, -style.magDrop * 0.25 * (1 - seg(u, 0.62, 0.7)), 0)
		end
		local rack = seg(u, 0.74, 0.79) * (1 - seg(u, 0.8, 0.84))
		roles.Slide = CF(0, 0, 0.22 * rack)
		return move, belt, roles, hide
	elseif style.kind == "revolver" then
		local up = seg(u, 0, 0.14) * (1 - seg(u, 0.84, 1))
		local move = CF(-0.15 * up, 0.25 * up, 0.55 * up) * ANG(rad(55 * up), rad(-10 * up), rad(20 * up))
		local open = seg(u, 0.12, 0.2) * (1 - seg(u, 0.76, 0.82))
		roles.Cylinder = CF(-0.16 * open, -0.04 * open, 0) * ANG(0, 0, rad(-60 * open))
		local belt = seg(u, 0.26, 0.4) * (1 - seg(u, 0.46, 0.62))
		return move, belt, roles, false
	else -- shotgun: four shells, one at a time, then the pump
		local move = CF(-0.1 * tilt, 0.05 * tilt, 0.3 * tilt) * ANG(rad(6 * tilt), rad(-10 * tilt), rad(-35 * tilt))
		local belt = 0
		if u > 0.08 and u < 0.74 then
			local k = (u - 0.08) / 0.66 * 4
			local ph = k - math.floor(k)
			belt = 0.8 * (if ph < 0.5 then smooth(ph / 0.5) else 1 - smooth((ph - 0.5) / 0.5))
		end
		local pump = seg(u, 0.78, 0.85) * (1 - seg(u, 0.86, 0.93))
		roles.Pump = CF(0, 0, 0.4 * pump)
		return move, belt, roles, false
	end
end

-- Pure solve: world CFrames for a character at the current root, from a pose request.
function GunPose.solve(char: Model, st: SolveIn): Frames?
	local rig = rigOf(char)
	if not rig then
		return nil
	end
	local style = styleOf(st.gunId)
	local root = rig.root :: Joint
	local waist = rig.waist :: Joint
	local hrpCF = rig.hrp.CFrame
	local lower = hrpCF * root.c0 * transformOf(root) * root.c1:Inverse()

	local raise = st.raise
	local pitch = math.clamp(st.pitch, -70, 75)
	local usePitch = pitch * (LOW_PITCH + (1 - LOW_PITCH) * raise)
	local spine = usePitch * SPINE_PITCH * (0.4 + 0.6 * raise)
	local waistT = transformOf(waist) * ANG(rad(spine), 0, 0)
	local upper = lower * waist.c0 * waistT * waist.c1:Inverse()
	local head: CFrame? = nil
	if rig.neck then
		local neck = rig.neck :: Joint
		local neckT = transformOf(neck) * ANG(rad((usePitch - spine) * NECK_PITCH), 0, 0)
		head = upper * neck.c0 * neckT * neck.c1:Inverse()
	end

	-- aim frame: shoulder height, the character's yaw, pitched
	local sh = (rig.rs :: Joint).c0.Position.Y
	local flat = Vector3.new(hrpCF.LookVector.X, 0, hrpCF.LookVector.Z)
	flat = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	local yawOnly = CFrame.fromMatrix(Vector3.zero, Vector3.yAxis:Cross(-flat), Vector3.yAxis, -flat)
	local origin = (upper * CF(0, sh, 0)).Position
	local aimF = CFrame.new(origin) * yawOnly * ANG(0, rad(st.swayYaw), 0) * ANG(rad(usePitch), 0, 0)
	local flatF = CFrame.new(origin) * yawOnly * ANG(0, rad(st.swayYaw), 0) * ANG(rad(usePitch * LOW_PITCH), 0, 0)

	-- pose: low <-> aim, then the draw from the holster
	local poseAim = aimF * style.aim
	local poseLow = flatF * style.low
	local pose = poseLow:Lerp(poseAim, raise)
	if st.equip < 1 then
		local e = backOut(st.equip)
		local from = CFrame.new(origin) * yawOnly * style.holster
		pose = from:Lerp(pose, math.clamp(e, 0, 1.08))
	end

	-- reload
	local roles: { [string]: CFrame } = {}
	local belt = 0
	local hideMag = false
	if st.reload then
		local move, bAmt, rr, hide = reloadMotion(style, st.reload)
		-- the reload happens in close, in front of the chest, whatever the aim was
		local rel = poseLow:Lerp(poseAim, 0.55)
		local w = seg(st.reload, 0, 0.1) * (1 - seg(st.reload, 0.9, 1))
		pose = pose:Lerp(rel, w) * move
		roles = rr
		hideMag = hide
		belt = bAmt
	end

	-- shot cycling: slide / bolt / pump / cylinder
	local since = st.sinceShot
	if style.kind == "mag" and since < 0.08 then
		local k = if since < 0.025 then since / 0.025 else 1 - (since - 0.025) / 0.055
		roles.Slide = (roles.Slide or CFrame.identity) * CF(0, 0, 0.2 * clamp01(k))
	elseif style.kind == "shotgun" and since > 0.12 and since < 0.55 then
		local k = seg(since, 0.12, 0.28) * (1 - seg(since, 0.32, 0.5))
		roles.Pump = (roles.Pump or CFrame.identity) * CF(0, 0, 0.4 * k)
	end
	if style.kind == "revolver" then
		local turn = st.shotCount * 60 + 60 * seg(since, 0, 0.08)
		roles.Cylinder = (roles.Cylinder or CFrame.identity) * ANG(0, 0, rad(-turn))
	end

	-- kick + bob
	pose = (CFrame.new(st.bob) * pose) * CF(0, 0, st.kickZ) * ANG(rad(st.kickR), 0, 0)

	-- right hand from the handle through the grip motor
	local gp = gunParts(char)
	local gripC0, gripC1 = CF(0, -0.15, 0) * ANG(rad(-90), 0, 0), CFrame.identity
	if gp and gp.grip then
		gripC0, gripC1 = gp.grip.C0, gp.grip.C1
	end
	local rightHand = pose * gripC1 * gripC0:Inverse()
	local up = aimF.UpVector
	local rgt = aimF.RightVector
	local back = -aimF.LookVector
	local rPole = (-up * 1.0 + rgt * 0.9 + back * 0.25)
	local right = solveArm(rig.rs :: Joint, rig.re :: Joint, rig.rw :: Joint, upper, rightHand, rPole)
	local handle = right.hand * gripC0 * gripC1:Inverse()

	-- left hand on the Support point (or reaching for the belt), palm on the gun
	local leftWeight = (style.lowLeft + (style.aimLeft - style.lowLeft) * raise)
	if st.reload then
		leftWeight = 1
	end
	if st.equip < 1 then
		leftWeight *= smooth((st.equip - 0.45) / 0.55)
	end
	local left: ArmOut? = nil
	if leftWeight > 0.001 then
		local supportLocal = if gp and gp.support then gp.support.CFrame else CF(-0.1, -0.1, -0.3)
		local pumpOff = roles.Pump or CFrame.identity
		local onGun = handle * pumpOff * supportLocal * GunPose.LEFT_GRIP
		local target = onGun
		if belt > 0 then
			local beltWorld = CFrame.new(origin) * yawOnly * BELT * ANG(rad(-70), rad(20), 0)
			target = onGun:Lerp(beltWorld, belt)
		end
		local lPole = (-up * 1.0 - rgt * 0.9 + back * 0.15)
		left = solveArm(rig.ls :: Joint, rig.le :: Joint, rig.lw :: Joint, upper, target, lPole)
	end
	return {
		lower = lower,
		upper = upper,
		head = head,
		right = right,
		left = left,
		leftWeight = leftWeight,
		handle = handle,
		roles = roles,
		hideMag = hideMag,
	}
end
-- how the left hand sits relative to a Support attachment (palm up under the gun, fingers wrapping)
GunPose.LEFT_GRIP = ANG(0, 0, rad(-90)) * CF(0, -0.12, 0)

---------------------------------------------------------------- apply (runtime)

local function blendSet(j: Joint?, t: CFrame, w: number)
	if not j then
		return
	end
	if w >= 0.999 then
		setTransform(j, t)
	else
		setTransform(j, transformOf(j):Lerp(t, w))
	end
end

local function apply(char: Model, f: Frames)
	local rig = rigOf(char) :: Rig
	setTransform(rig.waist, solveT(rig.waist :: Joint, f.lower, f.upper))
	if rig.neck and f.head then
		setTransform(rig.neck, solveT(rig.neck :: Joint, f.upper, f.head))
	end
	setTransform(rig.rs, solveT(rig.rs :: Joint, f.upper, f.right.upper))
	setTransform(rig.re, solveT(rig.re :: Joint, f.right.upper, f.right.lower))
	setTransform(rig.rw, solveT(rig.rw :: Joint, f.right.lower, f.right.hand))
	if f.left then
		local w = f.leftWeight
		blendSet(rig.ls, solveT(rig.ls :: Joint, f.upper, f.left.upper), w)
		blendSet(rig.le, solveT(rig.le :: Joint, f.left.upper, f.left.lower), w)
		blendSet(rig.lw, solveT(rig.lw :: Joint, f.left.lower, f.left.hand), w)
	end
	local gp = gunParts(char)
	if gp then
		if gp.grip then
			gp.grip.Transform = CFrame.identity
		end
		for role, r in gp.roles do
			if r.motor then
				r.motor.Transform = f.roles[role] or CFrame.identity
			end
			if role == "Mag" then
				r.part.LocalTransparencyModifier = if f.hideMag then 1 else 0
			end
		end
	end
end

-- Edit-mode preview: pose an anchored copy of a rig (parts moved directly, no Transforms).
function GunPose.previewApply(char: Model, f: Frames)
	local function put(name: string, cf: CFrame?)
		local p = char:FindFirstChild(name) :: BasePart?
		if p and cf then
			p.CFrame = cf
		end
	end
	put("LowerTorso", f.lower)
	put("UpperTorso", f.upper)
	put("Head", f.head)
	put("RightUpperArm", f.right.upper)
	put("RightLowerArm", f.right.lower)
	put("RightHand", f.right.hand)
	if f.left and f.leftWeight > 0.5 then
		put("LeftUpperArm", f.left.upper)
		put("LeftLowerArm", f.left.lower)
		put("LeftHand", f.left.hand)
	end
	local gp = gunParts(char)
	if gp then
		gp.handle.CFrame = f.handle
		for role, r in gp.roles do
			if r.motor then
				r.part.CFrame = f.handle * r.motor.C0 * (f.roles[role] or CFrame.identity) * r.motor.C1:Inverse()
				r.part.Transparency = if role == "Mag" and f.hideMag then 1 else 0
			end
		end
		for _, p in gp.model:GetChildren() do
			if p:IsA("BasePart") and p ~= gp.handle and not p:GetAttribute("GunRole") then
				local off = p:GetAttribute("HandleOffset")
				if typeof(off) == "CFrame" then
					p.CFrame = f.handle * off
				end
			end
		end
	end
end

---------------------------------------------------------------- per frame

local function step(dt: number)
	local now = os.clock()
	local mine = me()
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		if not char then
			continue
		end
		local gunId = char:GetAttribute("MTL_Gun")
		local s = stateOf(char)
		if type(gunId) ~= "string" or gunId == "" or not Guns.Defs[gunId] then
			s.gunId = nil
			continue
		end
		if s.gunId ~= gunId then
			s.gunId = gunId
			s.equipAt = now
			s.reloadStart = 0
			s.raise = 0
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then
			continue
		end
		-- a body action (MTL_Action, e.g. stuffing cash at the till) owns both arms: the gun goes in the waistband
		-- (hidden here) and ActionPose poses the arms; when the action ends the gun is drawn again
		local act = char:GetAttribute("MTL_Action")
		local busy = type(act) == "string" and act ~= ""
		if busy or s.tucked then
			local m = char:FindFirstChild("MTL_Gun")
			if m then
				for _, p in m:GetDescendants() do
					if p:IsA("BasePart") then
						p.LocalTransparencyModifier = if busy then 1 else 0
					end
				end
			end
			if busy then
				s.tucked = true
				s.reloadStart = 0
				continue
			end
			s.tucked = false
			s.equipAt = now -- draw it back out
			s.raise = 0
		end
		local def = Guns.Defs[gunId]
		local style = styleOf(gunId)
		local isMe = char == mine
		local pitch = if isMe then localPitch else (char:GetAttribute("MTL_AimPitch") or 0) :: number
		local raised = if isMe then localRaised else char:GetAttribute("MTL_Aiming") == true
		-- others: the reload arrives as a server time stamp
		if not isMe then
			local at = char:GetAttribute("MTL_ReloadAt")
			if type(at) == "number" and at ~= s.seenReload then
				s.seenReload = at
				local ago = Workspace:GetServerTimeNow() - at
				if ago < def.Reload then
					s.reloadStart = now - ago
					s.reloadLen = def.Reload
					s.magDropped = false
				end
			end
		end
		s.pitch += (pitch - s.pitch) * clamp01(dt * 20)
		local reloading = s.reloadStart > 0 and now - s.reloadStart < s.reloadLen
		if s.reloadStart > 0 and not reloading then
			s.reloadStart = 0
		end
		local target = if raised and not reloading then 1 else 0
		s.raise += (target - s.raise) * clamp01(dt * (if target > s.raise then 16 else 9))
		-- kick springs
		local k, c = 520, 34
		s.kickV += (-k * s.kickZ - c * s.kickV) * dt
		s.kickZ += s.kickV * dt
		s.kickRV += (-k * s.kickR - c * s.kickRV) * dt
		s.kickR += s.kickRV * dt
		-- the gun trails turns a little
		local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local yaw = if hrp then math.deg(math.atan2(-hrp.CFrame.LookVector.X, -hrp.CFrame.LookVector.Z)) else 0
		if s.lastYaw then
			local dy = (yaw - (s.lastYaw :: number) + 540) % 360 - 180
			s.swayYaw = math.clamp(s.swayYaw - dy * 0.35, -8, 8)
		end
		s.lastYaw = yaw
		s.swayYaw -= s.swayYaw * clamp01(dt * 8)
		-- breathing + walk bob
		local speed = if hrp then Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z).Magnitude else 0
		local walk = math.clamp(speed / 16, 0, 1.4) * (1 - 0.6 * s.raise)
		local bob = Vector3.new(0, math.abs(math.cos(now * 5.5)) * -0.06 * walk + math.sin(now * 1.4) * 0.012, 0)
		if hrp then
			bob += hrp.CFrame.RightVector * math.sin(now * 5.5) * 0.04 * walk
		end

		local u: number? = if reloading then (now - s.reloadStart) / s.reloadLen else nil
		-- drop the old mag once, the moment it leaves the gun (revolver: six empties)
		if u and u >= 0.22 and not s.magDropped then
			s.magDropped = true
			local gp = gunParts(char)
			if gp and style.kind == "mag" and gp.roles.Mag then
				dropMag(gp, gp.roles.Mag.part)
			elseif gp and style.kind == "revolver" and gp.eject then
				for i = 1, 6 do
					local cf = gp.eject.WorldCFrame * CFrame.new(math.cos(i) * 0.06, math.sin(i) * 0.06, 0)
					dropBrass(cf, Vector3.new(0, -2, 0), Color3.fromRGB(201, 158, 70), Vector3.new(0.12, 0.06, 0.06))
				end
			end
		end
		-- shotgun: the spent red shell flies out on the pump
		if style.kind == "shotgun" and not s.pumped and now - s.lastShot > 0.22 then
			s.pumped = true
			local gp = gunParts(char)
			if gp and gp.eject then
				local h = gp.handle.CFrame
				dropBrass(gp.eject.WorldCFrame, h.RightVector * 8 + h.UpVector * 6, Color3.fromRGB(160, 30, 30), Vector3.new(0.26, 0.11, 0.11))
			end
		end

		local f = GunPose.solve(char, {
			gunId = gunId,
			pitch = s.pitch,
			raise = s.raise,
			equip = clamp01((now - s.equipAt) / math.max(def.EquipTime or 0.35, 0.25)),
			reload = u,
			sinceShot = now - s.lastShot,
			kickZ = s.kickZ,
			kickR = s.kickR,
			bob = bob,
			swayYaw = s.swayYaw,
			shotCount = s.shotCount,
		})
		if f then
			apply(char, f)
		end
	end
end

function GunPose.init()
	RunService.PreSimulation:Connect(function(dt)
		if GunPose.enabled then
			step(dt)
		end
	end)
	Players.PlayerRemoving:Connect(function(plr)
		local c = plr.Character
		if c then
			rigCache[c] = nil
			states[c] = nil
		end
	end)
end

return GunPose
