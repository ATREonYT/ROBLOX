--!strict
-- Split-body aim (Quality pass, Benchmark Gap List 1.1). While a character aims a gun, its root faces the camera
-- (GunController turns AutoRotate off), so the walk animation used to play facing the camera whatever way you moved:
-- strafing slid sideways, backpedalling moonwalked. Here the hips and legs turn toward the way you are actually
-- moving and the waist turns back by the same amount, so the chest, arms and gun stay on the crosshair.
--
-- How: every frame, before GunPose (this controller boots before GunController), for every character with a gun out
-- that is aiming, RootJoint.Transform gets a yaw toward the move direction and Waist.Transform gets the opposite yaw.
-- GunPose reads both Transforms and builds the upper body on top, so its aim is unchanged.
-- Works for everyone on every client from replicated data alone (the root's facing + velocity + MTL_Gun/MTL_Aiming),
-- so nothing new goes over the network.
--   moving sideways      legs turn up to MAX_TWIST toward the strafe, the chest stays on target
--   moving backwards     legs stay facing forward (a backpedal), no twist
--   standing / slow      no twist (eases back)
-- Works on Motor6D and AnimationConstraint rigs (both have Transform).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SplitAim = {}
SplitAim.enabled = true

local MAX_TWIST = math.rad(65) -- most the hips turn away from the chest
local BACK_LIMIT = math.rad(115) -- beyond this the move counts as a backpedal (legs face forward)
local MIN_SPEED = 2.5 -- studs/s before the legs turn
local RATE = 10 -- how quickly the twist follows (1/s)

type Rig = { root: any?, waist: any? }
local rigs: { [Model]: Rig } = setmetatable({}, { __mode = "k" }) :: any -- characters drop out when they despawn
local twist: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function rigOf(char: Model): Rig
	local r = rigs[char]
	if r and r.root and r.root.Parent and r.waist and r.waist.Parent then
		return r
	end
	local nr: Rig = {}
	for _, d in char:GetDescendants() do
		if d:IsA("Motor6D") or d.ClassName == "AnimationConstraint" then
			if d.Name == "Root" or d.Name == "RootJoint" then
				nr.root = d
			elseif d.Name == "Waist" then
				nr.waist = d
			end
		end
	end
	rigs[char] = nr
	return nr
end

local function aiming(char: Model, isMe: boolean): boolean
	local g = char:GetAttribute("MTL_Gun")
	if type(g) ~= "string" or g == "" then
		return false
	end
	local act = char:GetAttribute("MTL_Action")
	if type(act) == "string" and act ~= "" then
		return false -- the gun is tucked away while a body action owns the arms
	end
	if isMe then
		local hum = char:FindFirstChildOfClass("Humanoid")
		return hum ~= nil and hum.AutoRotate == false
	end
	return char:GetAttribute("MTL_Aiming") == true
end

-- the yaw (radians, + = toward the character's left) that turns the hips from the facing to the move direction
local function wantedTwist(hrp: BasePart): number
	local v = hrp.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	if flat.Magnitude < MIN_SPEED then
		return 0
	end
	local d = flat.Unit
	local look, right = hrp.CFrame.LookVector, hrp.CFrame.RightVector
	local a = math.atan2(-d:Dot(right), d:Dot(look))
	if math.abs(a) > BACK_LIMIT then
		return 0 -- backpedal: keep the legs under the chest
	end
	return math.clamp(a, -MAX_TWIST, MAX_TWIST)
end

function SplitAim.init()
	local me = Players.LocalPlayer
	RunService.PreSimulation:Connect(function(dt)
		if not SplitAim.enabled then
			return
		end
		local k = 1 - math.exp(-RATE * dt)
		for _, plr in Players:GetPlayers() do
			local char = plr.Character
			if not char then
				continue
			end
			local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
			local hum = char:FindFirstChildOfClass("Humanoid")
			local cur = twist[char] or 0
			local want = 0
			if hrp and hum and hum.Health > 0 and aiming(char, plr == me) then
				want = wantedTwist(hrp)
			end
			cur += (want - cur) * k
			if math.abs(cur) < 1e-3 and want == 0 then
				twist[char] = nil
				continue
			end
			twist[char] = cur
			local r = rigOf(char)
			if r.root and r.waist then
				r.root.Transform = CFrame.Angles(0, cur, 0) * r.root.Transform
				r.waist.Transform = CFrame.Angles(0, -cur, 0) * r.waist.Transform
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(plr)
		local c = plr.Character
		if c then
			rigs[c], twist[c] = nil, nil
		end
	end)
end

-- for previews / tests: the twist a character would get right now (radians)
SplitAim.wantedTwist = wantedTwist

return SplitAim
