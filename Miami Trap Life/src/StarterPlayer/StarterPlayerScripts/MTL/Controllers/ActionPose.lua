--!strict
-- Procedural body poses for job actions (Quality pass). No animation assets: arms and torso are posed in code
-- after the Animator each frame (RunService.PreSimulation), the same way GunPose works, so they blend on top of
-- the walk cycle and work on both R15 joint kinds (Motor6D and this place's AnimationConstraint joints).
--
-- Who gets posed: every character with a child "MTL_Carry" (JobService.addCarry) whose attribute "Pose" names
-- a pose below, or with the attribute "MTL_Action" on the character (a looping tool action, e.g. "Mop").
-- Everyone sees everyone's pose (each client poses all characters).
--   Hug   box / crate / tire held in front with both hands      Tray  forearms level, tray in front
--   Side  bag hanging from the right hand                       Hand  small item in the right hand
--   Mop / Wipe / Sweep / Scan / Spray / Count / Flip / Crank  looping job actions (MTL_Action)
--   Hammer / Drill / Pry  looping crime actions (MTL_Action, used by the crime thread)
--   Grab  hands in and out of a till, stuffing cash (the robbery's Grab step)
-- A gun out always wins (GunPose owns the arms then).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ActionPose = {}
ActionPose.enabled = true

local rad = math.rad
local function A(x: number, y: number, z: number): CFrame
	return CFrame.Angles(rad(x), rad(y), rad(z))
end
local function YX(y: number, x: number): CFrame
	return CFrame.Angles(0, rad(y), 0) * CFrame.Angles(rad(x), 0, 0)
end

type Pose = { [string]: CFrame }
-- Static poses (joint name -> Transform). Tuned in the Studio lab against an R15 rig with the real carry meshes.
local STATIC: { [string]: Pose } = {
	Hug = {
		Waist = A(-5, 0, 0),
		RightShoulder = YX(16, 42),
		LeftShoulder = YX(-16, 42),
		RightElbow = A(48, 0, 0),
		LeftElbow = A(48, 0, 0),
		RightWrist = A(0, 0, -20),
		LeftWrist = A(0, 0, 20),
	},
	Tray = {
		RightShoulder = YX(8, 22),
		LeftShoulder = YX(-8, 22),
		RightElbow = A(72, 0, 0),
		LeftElbow = A(72, 0, 0),
	},
	Side = {
		Waist = A(0, 0, -4),
		RightShoulder = A(-6, 0, 14),
		RightElbow = A(6, 0, 0),
		LeftShoulder = A(0, 0, -6),
	},
	Hand = {
		RightShoulder = YX(10, 28),
		RightElbow = A(62, 0, 0),
	},
}

-- Looping actions: a function of time t (seconds) -> pose. Two-handed tool work, a rhythm you can read.
local LOOPS: { [string]: (number) -> Pose } = {
	-- mop: both hands on the handle, side to side figure-eight sweeps in front of the feet
	Mop = function(t)
		local s = math.sin(t * 4.2)
		local c = math.cos(t * 8.4)
		return {
			Waist = A(-10 + 3 * c, 14 * s, 0),
			RightShoulder = YX(20 + 10 * s, 30 + 6 * c),
			LeftShoulder = YX(-26 + 10 * s, 52 + 6 * c),
			RightElbow = A(22, 0, 0),
			LeftElbow = A(38, 0, 0),
		}
	end,
	Sweep = function(t)
		local s = math.sin(t * 5)
		return {
			Waist = A(-8, 10 * s, 0),
			RightShoulder = YX(18 + 8 * s, 24),
			LeftShoulder = YX(-22 + 8 * s, 46),
			RightElbow = A(20, 0, 0),
			LeftElbow = A(34, 0, 0),
		}
	end,
	-- wipe: right hand circles flat on a surface at waist height, left hand steadies
	Wipe = function(t)
		local s, c = math.sin(t * 7), math.cos(t * 7)
		return {
			Waist = A(-14, 0, 0),
			RightShoulder = YX(6 + 10 * s, 48 + 8 * c),
			RightElbow = A(40 - 10 * c, 0, 0),
			LeftShoulder = YX(-6, 30),
			LeftElbow = A(40, 0, 0),
		}
	end,
	-- spray: right arm out pumping a trigger, left hand at the waist
	Spray = function(t)
		local p = math.max(0, math.sin(t * 9)) ^ 2
		return {
			Waist = A(-6, 0, 0),
			RightShoulder = YX(6, 62 + 4 * p),
			RightElbow = A(14, 0, 0),
			RightWrist = A(-10 * p, 0, 0),
			LeftShoulder = YX(-10, 18),
			LeftElbow = A(50, 0, 0),
		}
	end,
	-- scan / stock a shelf: reach forward and place, both hands
	Scan = function(t)
		local s = (math.sin(t * 3.5) + 1) / 2
		return {
			Waist = A(-6 - 6 * s, 0, 0),
			RightShoulder = YX(10, 40 + 30 * s),
			LeftShoulder = YX(-10, 34 + 26 * s),
			RightElbow = A(40 - 25 * s, 0, 0),
			LeftElbow = A(44 - 25 * s, 0, 0),
		}
	end,
	-- count bills / bag items: both hands low in front, right thumb flicking
	Count = function(t)
		local s = math.sin(t * 10)
		return {
			Waist = A(-6, 0, 0),
			RightShoulder = YX(10, 30),
			RightElbow = A(70 + 6 * s, 0, 0),
			RightWrist = A(8 * s, 0, 0),
			LeftShoulder = YX(-10, 32),
			LeftElbow = A(68, 0, 0),
		}
	end,
	-- spatula: right forearm flicks up off the grill, left hand resting
	Flip = function(t)
		local q = math.max(0, math.sin(t * 5)) ^ 3
		return {
			Waist = A(-8, 0, 0),
			RightShoulder = YX(10, 45 + 15 * q),
			RightElbow = A(55 - 20 * q, 0, 0),
			RightWrist = A(35 * q, 0, 0),
			LeftShoulder = YX(-8, 25),
			LeftElbow = A(45, 0, 0),
		}
	end,
	-- wrench / ratchet: right hand turning a circle at chest height, left hand bracing
	Crank = function(t)
		local s, c = math.sin(t * 6), math.cos(t * 6)
		return {
			Waist = A(-12, 0, 0),
			RightShoulder = YX(8 + 10 * s, 55 + 10 * c),
			RightElbow = A(55 + 10 * s, 0, 0),
			LeftShoulder = YX(-12, 38),
			LeftElbow = A(50, 0, 0),
		}
	end,
	-- sledgehammer: both arms come up over the shoulder and slam down (crime thread)
	Hammer = function(t)
		local u = ((math.sin(t * 4.4) + 1) / 2) ^ 0.6
		return {
			Waist = A(-15 + 15 * u, 0, 0),
			RightShoulder = YX(12, 40 + 100 * u),
			LeftShoulder = YX(-12, 40 + 100 * u),
			RightElbow = A(30 - 20 * u, 0, 0),
			LeftElbow = A(30 - 20 * u, 0, 0),
		}
	end,
	-- drill: two hands braced straight ahead, a little buzz (crime thread)
	Drill = function(t)
		local j = 1.5 * math.sin(t * 60)
		return {
			Waist = A(-6, 0, 0),
			RightShoulder = YX(10, 75 + j),
			LeftShoulder = YX(-10, 75 - j),
			RightElbow = A(25, 0, 0),
			LeftElbow = A(25, 0, 0),
		}
	end,
	-- cash grab: hands take turns diving into the drawer and pulling back to the bag
	Grab = function(t)
		local a = (math.sin(t * 6.5) + 1) / 2
		local b = (math.sin(t * 6.5 + math.pi) + 1) / 2
		return {
			Waist = A(-16, 6 * (a - b), 0),
			RightShoulder = YX(10, 25 + 40 * a),
			RightElbow = A(55 - 35 * a, 0, 0),
			LeftShoulder = YX(-10, 25 + 40 * b),
			LeftElbow = A(55 - 35 * b, 0, 0),
		}
	end,
	-- crowbar / lock pull: lever in both hands, heave back and reset (crime thread)
	Pry = function(t)
		local p = (math.sin(t * 3) + 1) / 2
		return {
			Waist = A(-5 + 8 * p, 10 * p, 0),
			RightShoulder = YX(15, 55 - 25 * p),
			LeftShoulder = YX(-5, 50 - 20 * p),
			RightElbow = A(40 + 20 * p, 0, 0),
			LeftElbow = A(40 + 20 * p, 0, 0),
		}
	end,
}

type Rig = { [string]: any }
local rigs: { [Model]: Rig } = {}
local weight: { [Model]: number } = {}
local lastPose: { [Model]: Pose } = {}

local function rigOf(char: Model): Rig
	local r = rigs[char]
	if r and r.RightShoulder and r.RightShoulder.Parent then
		return r
	end
	local nr: Rig = {}
	for _, d in char:GetDescendants() do
		if d:IsA("Motor6D") or d.ClassName == "AnimationConstraint" then
			nr[d.Name] = d
		end
	end
	rigs[char] = nr
	return nr
end

local function wanted(char: Model, t: number): Pose?
	-- a body action wins even with a gun out (GunPose tucks the gun away while MTL_Action is set)
	local act = char:GetAttribute("MTL_Action")
	if type(act) == "string" and LOOPS[act] then
		return LOOPS[act](t)
	end
	local g = char:GetAttribute("MTL_Gun")
	if type(g) == "string" and g ~= "" then
		return nil
	end
	local carry = char:FindFirstChild("MTL_Carry")
	local p = carry and carry:GetAttribute("Pose")
	if type(p) == "string" and STATIC[p] then
		return STATIC[p]
	end
	return nil
end

function ActionPose.init()
	local clock = 0
	RunService.PreSimulation:Connect(function(dt)
		clock += dt
		if not ActionPose.enabled then
			return
		end
		for _, plr in Players:GetPlayers() do
			local char = plr.Character
			if not char then
				continue
			end
			local target = wanted(char, clock)
			local w = weight[char] or 0
			-- ease in over ~0.2 s (a lift you can see), out a little faster
			if target then
				w = math.min(1, w + dt * 5)
				lastPose[char] = target
			else
				w = math.max(0, w - dt * 7)
			end
			weight[char] = w
			local pose = target or lastPose[char]
			if w <= 0 or not pose then
				lastPose[char] = nil
				continue
			end
			local k = 1 - (1 - w) * (1 - w) -- ease out
			local r = rigOf(char)
			for name, cf in pose do
				local j = r[name]
				if j then
					j.Transform = j.Transform:Lerp(cf, k)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(plr)
		local c = plr.Character
		if c then
			rigs[c], weight[c], lastPose[c] = nil, nil, nil
		end
	end)
end

return ActionPose
