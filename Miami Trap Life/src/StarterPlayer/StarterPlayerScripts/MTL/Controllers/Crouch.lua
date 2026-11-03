--!strict
-- Crouch (Quality pass, Benchmark Gap List 1.3). C (PC) / D-pad down (gamepad) / the CROUCH button (touch) toggles a
-- low stance: hips drop, knees bend, the chest leans in, and you move at CROUCH_SPEED of your walk. Moving while
-- crouched plays a procedural crouch-walk (short, low steps timed to the ground speed), so it needs no uploaded
-- animation. If Alex later publishes the pack's Crouch clip, this file is where it would be swapped in.
--
-- Everyone sees everyone crouch: the client asks the server (Net StanceAction {crouch = bool}); StanceService sets
-- the character attribute MTL_Stance = "Crouch", and every client poses every character that has it. Your own
-- character crouches the same frame you press (no wait for the round trip).
--
-- You stand up when you: press crouch again, sprint (Shift / L3 / RUN), jump, sit (car seat), swim, climb, pick up a
-- job prop, or a cutscene/minigame takes the controls.
-- Runs on PreSimulation after the Animator, before GunPose/ActionPose (it owns the legs and hips; they own the arms).
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.MTL.Net)
local Movement = require(ReplicatedStorage.MTL.Config.Movement)
local UIState = require(script.Parent.UIState)
local MovementController = require(script.Parent.MovementController)

local Crouch = {}
Crouch.enabled = true

local ACTION = "MTL_Crouch"
local KEYS = { Enum.KeyCode.C, Enum.KeyCode.DPadDown }
local CROUCH_SPEED = 0.55 -- share of walk speed
local HIP = 70 -- deg, thigh forward (+X on a hip/shoulder/elbow swings a hanging limb forward)
local KNEE = -115 -- deg, shin back (relative to the thigh)
local LEAN = 20 -- deg, chest forward over the knees (-X on the waist; +X would lean back)
local NECK = 12 -- deg, head back up so the eyes stay level
local ARM, ELBOW = 16, 30 -- deg, arms forward + bent, hands over the knees (GunPose/ActionPose override them)
local STEP_LEN = 1.6 -- studs per step while crouch-walking
local SWING = 22 -- deg of thigh swing per step
local LIFT = 18 -- deg of extra knee bend on the swinging leg
local EASE_IN, EASE_OUT = 9, 11 -- 1/s

local player = Players.LocalPlayer
local localCrouch = false

local rad = math.rad
local function RX(d: number): CFrame
	return CFrame.Angles(rad(d), 0, 0)
end

---------------------------------------------------------------- rig + leg lengths
type Rig = { [string]: any }
local rigs: { [Model]: Rig } = setmetatable({}, { __mode = "k" }) :: any
local weight: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local phase: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function frames(j: Instance): (CFrame, CFrame)
	if j:IsA("Motor6D") then
		return j.C0, j.C1
	end
	local a0 = (j :: any).Attachment0 :: Attachment?
	local a1 = (j :: any).Attachment1 :: Attachment?
	return if a0 then a0.CFrame else CFrame.identity, if a1 then a1.CFrame else CFrame.identity
end

local function rigOf(char: Model): Rig?
	local r = rigs[char]
	if r and r.Root and r.Root.Parent and r.LeftKnee and r.LeftKnee.Parent then
		return r
	end
	local nr: Rig = {}
	for _, d in char:GetDescendants() do
		if d:IsA("Motor6D") or d.ClassName == "AnimationConstraint" then
			local n = if d.Name == "RootJoint" then "Root" else d.Name
			nr[n] = d
		end
	end
	if not (nr.Root and nr.Waist and nr.LeftHip and nr.RightHip and nr.LeftKnee and nr.RightKnee) then
		return nil
	end
	-- thigh = hip pivot -> knee pivot (both in the UpperLeg's frame); shin = knee -> ankle (in the LowerLeg)
	local _, hipC1 = frames(nr.LeftHip)
	local kneeC0, kneeC1 = frames(nr.LeftKnee)
	local thigh = (kneeC0.Position - hipC1.Position).Magnitude
	local shin = 1.1
	if nr.LeftAnkle then
		local ankleC0 = frames(nr.LeftAnkle)
		shin = (ankleC0.Position - kneeC1.Position).Magnitude
	end
	nr.thigh, nr.shin = thigh, shin
	rigs[char] = nr
	return nr
end

-- how far the hips must drop so both feet stay on the ground with the thigh at `hip` and the knee at `knee`
local function drop(r: Rig, hip: number, knee: number): number
	return r.thigh * (1 - math.cos(rad(hip))) + r.shin * (1 - math.cos(rad(hip + knee)))
end

local function crouched(char: Model): boolean
	if char == player.Character then
		return localCrouch
	end
	return char:GetAttribute("MTL_Stance") == "Crouch"
end

---------------------------------------------------------------- local stance
local function hum(): Humanoid?
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function allowed(h: Humanoid): boolean
	if h.Health <= 0 or h.Sit then
		return false
	end
	local c = h.Parent :: Model?
	if c and (c:GetAttribute("MTL_WalkSpeedBeforeCarry") ~= nil) then
		return false
	end
	if UIState.get().lockControls or player:GetAttribute("MTL_Cutscene") then
		return false
	end
	local st = h:GetState()
	return st ~= Enum.HumanoidStateType.Swimming and st ~= Enum.HumanoidStateType.Climbing and st ~= Enum.HumanoidStateType.Seated
end

local function setCrouch(on: boolean)
	if on == localCrouch then
		return
	end
	localCrouch = on
	if on then
		MovementController.setModifier("Crouch", CROUCH_SPEED)
	else
		MovementController.clearModifier("Crouch")
	end
	local b = ContextActionService:GetButton(ACTION)
	if b then
		ContextActionService:SetTitle(ACTION, if on then "STAND" else "CROUCH")
	end
	Net.get("StanceAction"):FireServer({ crouch = on })
end

function Crouch.isCrouching(): boolean
	return localCrouch
end

function Crouch.stand()
	setCrouch(false)
end

local function onAction(_: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if UserInputService:GetFocusedTextBox() then
		return Enum.ContextActionResult.Pass
	end
	local h = hum()
	if not h then
		return Enum.ContextActionResult.Pass
	end
	if localCrouch then
		setCrouch(false)
	elseif allowed(h) then
		setCrouch(true)
	end
	return Enum.ContextActionResult.Sink
end

---------------------------------------------------------------- the pose (every character)
local function pose(char: Model, dt: number)
	local r = rigOf(char)
	if not r then
		return
	end
	local want = crouched(char)
	local w = weight[char] or 0
	if want then
		w = math.min(1, w + dt * EASE_IN * (1 - w + 0.15))
	else
		w = math.max(0, w - dt * EASE_OUT)
	end
	weight[char] = if w > 0 then w else nil
	if w <= 0 then
		phase[char] = nil
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local speed = 0
	if hrp then
		local v = hrp.AssemblyLinearVelocity
		speed = Vector3.new(v.X, 0, v.Z).Magnitude
	end
	-- step phase: one full cycle (left + right step) every 2 * STEP_LEN studs
	local ph = (phase[char] or 0) + speed * dt / (2 * STEP_LEN) * 2 * math.pi
	phase[char] = ph % (2 * math.pi)
	local moving = math.clamp((speed - 0.5) / 3, 0, 1)
	local s = math.sin(ph)
	local liftL = math.max(0, math.cos(ph)) * moving
	local liftR = math.max(0, -math.cos(ph)) * moving
	local hipL = HIP + SWING * s * moving
	local hipR = HIP - SWING * s * moving
	local kneeL = KNEE - LIFT * liftL
	local kneeR = KNEE - LIFT * liftR
	-- the hips drop by what the standing (planted) leg needs; a little bob as weight shifts
	local d = math.min(drop(r, hipL, KNEE), drop(r, hipR, KNEE))
	local e = 1 - (1 - w) * (1 - w)
	local function set(j: any, cf: CFrame)
		if j then
			j.Transform = j.Transform:Lerp(cf, e)
		end
	end
	-- root: keep whatever yaw SplitAim / the animation put there, add the drop
	r.Root.Transform = CFrame.new(0, -d * e, 0) * r.Root.Transform
	set(r.Waist, RX(-LEAN) * (r.Waist.Transform - r.Waist.Transform.Position))
	set(r.Neck, RX(NECK))
	set(r.LeftShoulder, RX(ARM))
	set(r.RightShoulder, RX(ARM))
	set(r.LeftElbow, RX(ELBOW))
	set(r.RightElbow, RX(ELBOW))
	set(r.LeftHip, RX(hipL))
	set(r.RightHip, RX(hipR))
	set(r.LeftKnee, RX(kneeL))
	set(r.RightKnee, RX(kneeR))
	set(r.LeftAnkle, RX(-(hipL + kneeL)))
	set(r.RightAnkle, RX(-(hipR + kneeR)))
end

function Crouch.init()
	ContextActionService:BindAction(ACTION, onAction, true, table.unpack(KEYS))
	ContextActionService:SetTitle(ACTION, "CROUCH")
	ContextActionService:SetPosition(ACTION, UDim2.new(1, -190, 1, -90))

	-- things that stand you up
	UserInputService.InputBegan:Connect(function(input, processed)
		if localCrouch and not processed then
			for _, k in Movement.SprintKeys do
				if input.KeyCode == k then
					setCrouch(false)
				end
			end
		end
	end)
	MovementController.Changed:Connect(function(sprinting)
		if sprinting then
			setCrouch(false)
		end
	end)
	local function watch(char: Model)
		local h = char:WaitForChild("Humanoid", 10) :: Humanoid?
		if not h then
			return
		end
		h.StateChanged:Connect(function(_, new)
			if localCrouch and (new == Enum.HumanoidStateType.Jumping or new == Enum.HumanoidStateType.Seated
				or new == Enum.HumanoidStateType.Swimming or new == Enum.HumanoidStateType.Climbing
				or new == Enum.HumanoidStateType.Dead) then
				setCrouch(false)
			end
		end)
	end
	player.CharacterAdded:Connect(function(c)
		localCrouch = false
		MovementController.clearModifier("Crouch")
		watch(c)
	end)
	if player.Character then
		task.spawn(watch, player.Character)
	end

	RunService.PreSimulation:Connect(function(dt)
		if not Crouch.enabled then
			return
		end
		-- the controls can be taken mid-crouch (cutscene, minigame, job carry): stand up
		if localCrouch then
			local h = hum()
			if not h or not allowed(h) then
				setCrouch(false)
			end
		end
		for _, plr in Players:GetPlayers() do
			local c = plr.Character
			if c then
				pose(c, dt)
			end
		end
	end)
end

return Crouch
