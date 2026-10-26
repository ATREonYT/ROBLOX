--!strict
--[[
	The huss pose on R6 bodies (owner, Oct 22 17:21: "make the huss animation not like that, but actually like the huss
	movement, just adjusted to the new animations"). The game's own huss (Shared/RunMotion's dash pose, made after
	Huss Valley's frames: a wide low crouch leaning into the move, the inside thigh up, the outside leg kicked out
	wide, fists held in front, the head nearly upright) rebuilt for R6's six blocks, in place of his pack's Dash
	Left / Right. R6 legs can't bend, so the crouch comes from the legs spreading: the outside leg is planted on the
	floor wide out (that sets how low the body sits), the inside leg is lifted forward and out with its foot just
	off the floor. Pure maths on the joints (any C0), so the offline preview and the tests run this exact code.
	pose(motors, side, k, w): motors = part name -> Motor6D ("Torso" is the RootJoint); side +1 right / -1 left
	(in the body's own frame); k 0..1 how deep (the push settles deeper, Config/Run.Dash.Settle); w the blend over
	what the joints already hold this frame.
]]
local R6HussPose = {}

local rad, cos, sin = math.rad, math.cos, math.sin
local DOWN = Vector3.new(0, -1, 0)

-- The pose's numbers (degrees, studs). Ours, shaped on RunMotion's (Config/Run.Dash) for six rigid blocks.
R6HussPose.Shape = {
	Lean = 12, -- forward, the whole body (RunMotion: 12 at the hips)
	Roll = 18, -- tipped into the move (RunMotion: 12 hips + 14 waist = 26; R6 has no waist, and more drops the inside hip into the floor)
	Turn = 5, -- the chest turned a little toward the move
	Shift = 0.3, -- the hips shifted the way you go (Run.Dash.SideShift)
	HeadBack = 8, -- the head held up, looking ahead...
	HeadRoll = 12, -- ...and nearly upright against the roll
	Plant = 48, -- the outside leg, degrees out from straight down, its foot on the floor
	PlantBack = 0.12, -- (a touch behind)
	Lift = 0.3, -- studs the inside foot clears the floor
	LiftForward = 0.55, -- the inside leg reaches this much forward for every 1 out (the thigh comes up)
	LiftMax = 72, -- degrees: never flung out flatter than this
	Fists = 74, -- both arms forward and up, fists held in front of the chest like the run...
	FistsIn = 0.22, -- ...a little inward
	TrailFists = 60, -- the outside arm lower...
	TrailOut = 0.18, -- ...and a little out, swung behind the lead one
}

local function fromTo(a: Vector3, b: Vector3): CFrame
	local d = math.clamp(a:Dot(b), -1, 1)
	if d > 0.99999 then
		return CFrame.identity
	end
	local axis = a:Cross(b)
	if axis.Magnitude < 1e-5 then
		axis = Vector3.xAxis
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(d))
end

-- A part's turn in its parent's space -> the joint's Transform (through its own C0), blended by w.
local function put(m: any, cf: CFrame, w: number)
	if not m then
		return
	end
	local r = m.C0.Rotation
	local t = r:Inverse() * cf * r
	m.Transform = if w >= 1 then t else m.Transform:Lerp(t, w)
end

-- A leg pointing along `dir` (world, unit), as its turn in the torso's space.
local function legTurn(torso: CFrame, dir: Vector3): CFrame
	return torso.Rotation:Inverse() * fromTo(DOWN, dir)
end

-- The height of the foot's bottom, for a leg hanging from its joint `hip` (world) along `dir`. The joint sits at the
-- leg's top edge (C1, half a stud in from its middle), so a leg swung out lifts or drops that edge too.
local function footY(hip: Vector3, dir: Vector3, c1: Vector3): number
	return (hip + fromTo(DOWN, dir):VectorToWorldSpace(-c1 + Vector3.new(0, -1, 0))).Y
end

-- The direction out from straight down by `deg` toward the level direction `flat`.
local function tilt(flat: Vector3, deg: number): Vector3
	return flat * sin(rad(deg)) + DOWN * cos(rad(deg))
end

function R6HussPose.pose(motors: { [string]: any }, side: number, k: number, w: number)
	if w <= 0 then
		return
	end
	local S = R6HussPose.Shape
	local root, neck = motors.Torso, motors.Head
	if not root then
		return
	end
	local lead, trail = if side > 0 then "Right" else "Left", if side > 0 then "Left" else "Right"
	local turn = CFrame.Angles(rad(-S.Lean * k), rad(-S.Turn * side * k), rad(-S.Roll * side * k))
	-- where the hips sit with the root at the floor's height above (the root stands 3 studs up: legs 2, half the torso 1)
	local function hipOf(name: string, torso: CFrame): Vector3
		local m = motors[name .. " Leg"]
		local at = if m then m.C0.Position else Vector3.new(if name == "Right" then 1 else -1, -1, 0)
		return torso * at
	end
	local function c1Of(name: string): Vector3
		local m = motors[name .. " Leg"]
		return if m then m.C1.Position else Vector3.new(if name == "Right" then 0.5 else -0.5, 1, 0)
	end
	-- the outside leg planted wide: drop the body until its foot meets the floor at Plant degrees
	local plantDir = tilt(Vector3.new(-side, 0, S.PlantBack).Unit, S.Plant * k)
	local torso0 = CFrame.new(S.Shift * side * k, 0, 0) * turn
	local drop = math.max(0, footY(hipOf(trail, torso0), plantDir, c1Of(trail)) - -3)
	local torso = CFrame.new(0, -drop, 0) * torso0
	put(root, torso, w)
	put(neck, CFrame.Angles(rad(S.HeadBack * k), 0, rad(S.HeadRoll * side * k)), w)
	put(motors[trail .. " Leg"], legTurn(torso, plantDir), w)
	-- the inside leg out and forward, its foot just off the floor (as wide as that takes, at most LiftMax)
	local flat = Vector3.new(side, 0, -S.LiftForward).Unit
	local hip = hipOf(lead, torso)
	local deg = 0
	for _ = 1, 20 do -- (the foot rises as the leg swings out: find the least swing that clears the floor)
		if footY(hip, tilt(flat, deg), c1Of(lead)) >= -3 + S.Lift * k or deg >= S.LiftMax then
			break
		end
		deg += 4
	end
	put(motors[lead .. " Leg"], legTurn(torso, tilt(flat, math.min(deg, S.LiftMax))), w)
	-- fists in front (arms in the torso's own space: forward is -Z)
	local function arm(name: string, up: number, inward: number)
		local x = (if name == "Right" then -1 else 1) * inward
		local dir = Vector3.new(x, -cos(rad(up)), -sin(rad(up))).Unit
		put(motors[name .. " Arm"], fromTo(DOWN, dir), w)
	end
	arm(lead, S.Fists * k, S.FistsIn)
	arm(trail, S.TrailFists * k, -S.TrailOut)
end

return R6HussPose
