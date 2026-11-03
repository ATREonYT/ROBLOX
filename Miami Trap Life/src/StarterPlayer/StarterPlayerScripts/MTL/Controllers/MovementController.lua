--!strict
-- How moving feels: sprint, eased speed changes, the sprint FOV kick, a small camera bob / strafe roll / landing
-- dip, the character leaning into sprints and turns, and a short jump cooldown. Numbers: Config/Movement.lua
-- (why: Research/Movement and Game Feel.md).
--
-- The only client script that writes Humanoid.WalkSpeed. Speed = base x sprint x every modifier, eased:
--   base   = Config WalkSpeed, or whatever someone else last wrote (the server's job carry writes Jobs.Carry.WalkSpeed, a map script
--            may write 0): a write we didn't make becomes the new base. When the carry ends it goes back to walk.
--   sprint = PC hold LeftShift · gamepad click L3 (toggle, switches off when you stop) · touch RUN button (same)
--            Never while carrying a job prop (char attribute MTL_WalkSpeedBeforeCarry), aiming, phone open,
--            or UIState lockControls (cutscenes, minigames, payout, fades).
-- In a cutscene (player attribute MTL_Cutscene set, or the camera isn't Custom) there is no sway, roll, dip, FOV
-- kick or lean: the offset comes off and the lean snaps back the moment it starts.
-- Camera effects are a transient offset: last frame's is taken off before the camera module runs
-- (RenderPriority.Camera - 1) and the new one goes on after the gun's recoil step (Camera + 2), so nothing builds
-- up. The FOV kick is additive: if someone else set FieldOfView (gun aim, mission zoom, cutscene, phone camera),
-- their value is the new base and the kick sits on top of it.
--
-- API (Master Plan §3.6)
--   MovementController.setModifier(name, mult) / clearModifier(name)   e.g. setModifier("Aim", 0.6)
--   MovementController.isSprinting() -> bool      MovementController.Changed: Signal(sprinting)
--   MovementController.sprintGate: (() -> bool)?  set by Stamina; false = too winded to sprint
--   MovementController.punch(pitchDeg, fovDeg?)   a camera kick that springs back (PERFECT tasks, gun kills: Juice.lua)
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Signal = require(ReplicatedStorage.MTL.Signal)
local Movement = require(ReplicatedStorage.MTL.Config.Movement)
local GunRules = require(ReplicatedStorage.MTL.Rules.GunRules)
local UIState = require(script.Parent.UIState)
local ClientData = require(script.Parent.ClientData)

local M = Movement

local MovementController = {}
MovementController.Changed = Signal.new()

local player = Players.LocalPlayer
local SPRINT_ACTION = "MTL_Sprint"
local CARRY_ATTR = "MTL_WalkSpeedBeforeCarry"

-- character
local hum: Humanoid? = nil
local root: BasePart? = nil
local joint: Instance? = nil -- the frame we tilt: a Motor6D (writes C0) or an AnimationConstraint's Attachment0
local jointProp = "C0" -- "C0" (Motor6D) or "CFrame" (Attachment0 of an AnimationConstraint)
local jointC0 = CFrame.identity
local pivot = Vector3.zero
local charConns: { RBXScriptConnection } = {}
-- speed
local base = M.WalkSpeed
local current = M.WalkSpeed
local lastWritten: number? = nil
local wasCarrying = false
local modifiers: { [string]: number } = {}
-- sprint input
local held = false
local toggled = false
local idleFor = 0
local sprinting = false
local sprintAmt = 0 -- 0..1, eased: drives bob / lean
-- camera
local applied = CFrame.identity
local fovApplied = 0
local lastFov: number? = nil
local ownFov: { [number]: number } = {} -- FOVs we wrote with a kick in them -> that kick (a later restore of one)
local ownFovCount = 0
local bobPhase = 0
local roll = 0
local land = { x = 0, v = 0 }
local punchPitch = { x = 0, v = 0 }
local punchFov = { x = 0, v = 0 }
local fovTotal = 0 -- what we added to FieldOfView last frame (sprint kick + punch)
local maxFall = 0
-- lean
local leanFwd = { x = 0, v = 0 }
local leanSide = { x = 0, v = 0 }
local lastYaw: number? = nil
local leanWritten = false
-- jump
local jumpGen = 0

local Phone: any = nil

local function reducedMotion(): boolean
	local d = ClientData.get()
	return d ~= nil and d.Settings ~= nil and d.Settings.ReducedMotion == true
end

local function phoneOpen(): boolean
	return Phone and Phone.isOpen and Phone.isOpen() or false
end

local function inCutscene(): boolean
	return player:GetAttribute("MTL_Cutscene") ~= nil
end

local function carrying(): boolean
	local c = player.Character
	return c ~= nil and c:GetAttribute(CARRY_ATTR) ~= nil
end

local function firstPerson(cam: Camera): boolean
	local c = player.Character
	local head = c and c:FindFirstChild("Head") :: BasePart?
	return head ~= nil and (cam.CFrame.Position - head.Position).Magnitude < 1.6
end

-- exponential approach: ~95% of the way in `seconds`
local function approach(from: number, to: number, seconds: number, dt: number): number
	if seconds <= 0 then
		return to
	end
	return from + (to - from) * (1 - math.exp(-3 * dt / seconds))
end

-- spring toward a target (GunRules.springStep springs toward 0)
local function springTo(s: any, target: number, k: number, z: number, dt: number)
	local tmp = { x = s.x - target, v = s.v }
	GunRules.springStep(tmp, k, z, dt)
	s.x, s.v = tmp.x + target, tmp.v
end

local function multiplier(): number
	local m = 1
	for _, v in modifiers do
		m *= v
	end
	return m
end

local function canSprint(h: Humanoid): boolean
	if h.Health <= 0 or h.Sit or modifiers.Aim ~= nil or carrying() or phoneOpen() then
		return false
	end
	if MovementController.sprintGate and not MovementController.sprintGate() then
		return false -- out of breath (Stamina)
	end
	if UIState.get().lockControls or inCutscene() or UserInputService:GetFocusedTextBox() then
		return false
	end
	local st = h:GetState()
	return st ~= Enum.HumanoidStateType.Swimming and st ~= Enum.HumanoidStateType.Climbing and st ~= Enum.HumanoidStateType.Seated
end

local function touchButton(): ImageButton?
	local b = ContextActionService:GetButton(SPRINT_ACTION)
	return if b and b:IsA("ImageButton") then b else nil
end

local function setSprinting(on: boolean)
	if on == sprinting then
		return
	end
	sprinting = on
	local b = touchButton()
	if b then
		b.ImageColor3 = if on then Color3.fromRGB(255, 214, 110) else Color3.new(1, 1, 1)
	end
	MovementController.Changed:Fire(on)
end

---------------------------------------------------------------- speed

local function speedStep(h: Humanoid, dt: number)
	local seen = h.WalkSpeed
	local carry = carrying()
	if lastWritten == nil or math.abs(seen - lastWritten) > 0.01 then
		if lastWritten ~= nil then
			-- someone else wrote it. The carry's restore puts back a speed that may have had our sprint in it.
			base = if not carry and wasCarrying then M.WalkSpeed else seen
		end
		current = seen
	end
	wasCarrying = carry

	local moving = h.MoveDirection.Magnitude > 0.1
	if toggled then
		idleFor = if moving then 0 else idleFor + dt
		if idleFor > M.ToggleOffIdleSeconds then
			toggled = false
		end
	end
	setSprinting((held or toggled) and moving and canSprint(h))

	local target = base * multiplier() * (if sprinting then M.SprintSpeed / M.WalkSpeed else 1)
	current = approach(current, target, if target > current then M.EaseUpSeconds else M.EaseDownSeconds, dt)
	if math.abs(target - current) < 0.05 then
		current = target
	end
	if math.abs(h.WalkSpeed - current) > 0.001 then
		h.WalkSpeed = current
	end
	lastWritten = h.WalkSpeed
end

---------------------------------------------------------------- lean

-- The lean joint: R15 LowerTorso.Root, R6 HumanoidRootPart.RootJoint. Pivot = the feet, in root space.
-- Two kinds of rig exist: classic Motor6D joints (we tilt C0) and Roblox's newer AnimationConstraint joints (this
-- place uses those: no Motor6Ds at all, seen in the 2026-11-02 play-test), where Attachment0's CFrame on the root
-- part plays the role of C0, so we tilt that. Looked up again whenever it's gone (loading the avatar rebuilds joints).
local nextJointLook = 0
local function getFrame(): CFrame
	return (joint :: any)[jointProp]
end
local function setFrame(cf: CFrame)
	(joint :: any)[jointProp] = cf
end
local function findJoint(h: Humanoid, r: BasePart): Instance?
	local j = joint
	local c = h.Parent
	if j and j.Parent and c and j:IsDescendantOf(c) then
		return j
	end
	local now = os.clock()
	if now < nextJointLook or not c then
		return nil
	end
	nextJointLook = now + 0.5
	local lt = c:FindFirstChild("LowerTorso")
	local found = (lt and lt:FindFirstChild("Root")) or r:FindFirstChild("RootJoint")
	joint = nil
	if found and found:IsA("Motor6D") then
		joint, jointProp = found, "C0"
	elseif found and found.ClassName == "AnimationConstraint" then
		local a0 = (found :: any).Attachment0
		if a0 and a0:IsA("Attachment") and a0.Parent == r then
			joint, jointProp = a0, "CFrame"
		end
	end
	if joint then
		jointC0 = getFrame()
		leanWritten = false
		local legs = if h.RigType == Enum.HumanoidRigType.R6 then 2 else h.HipHeight
		pivot = Vector3.new(0, -(r.Size.Y / 2 + legs), 0)
	end
	return joint
end

local function leanStep(h: Humanoid, r: BasePart, speed: number, dt: number)
	local j = findJoint(h, r)
	if not j then
		return
	end
	if not leanWritten then
		jointC0 = getFrame() -- whatever the rig has while we aren't leaning is the rest pose (scaling can change it)
	end
	local look = r.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	local yawRate = 0
	if lastYaw and dt > 0 then
		local d = yaw - lastYaw
		d = (d + math.pi) % (2 * math.pi) - math.pi
		yawRate = d / dt
	end
	lastYaw = yaw
	if inCutscene() or Workspace.CurrentCamera.CameraType ~= Enum.CameraType.Custom then
		-- a cutscene may pose / place the character: hand the joint straight back
		leanFwd.x, leanFwd.v, leanSide.x, leanSide.v = 0, 0, 0, 0
		if leanWritten then
			setFrame(jointC0)
			leanWritten = false
		end
		return
	end
	local st = h:GetState()
	local ok = h.Health > 0
		and not h.Sit
		and modifiers.Aim == nil
		and not UIState.get().lockControls
		and st ~= Enum.HumanoidStateType.Climbing
		and st ~= Enum.HumanoidStateType.Swimming
	local fwd = if ok then M.SprintLean * sprintAmt else 0
	local side = if ok then M.TurnLean * math.clamp(yawRate / M.TurnLeanRate, -1, 1) * math.clamp(speed / M.WalkSpeed, 0, 1) else 0
	springTo(leanFwd, fwd, M.LeanStiffness, M.LeanDamping, dt)
	springTo(leanSide, side, M.LeanStiffness, M.LeanDamping, dt)
	if math.abs(leanFwd.x) < 0.01 and math.abs(leanSide.x) < 0.01 and fwd == 0 and side == 0 then
		if leanWritten then
			setFrame(jointC0)
			leanWritten = false
		end
		return
	end
	-- rotate about the feet, in the root part's space: forward = tip the top toward -Z, side = toward the turn
	local rot = CFrame.Angles(math.rad(-leanFwd.x), 0, math.rad(leanSide.x))
	setFrame(CFrame.new(pivot) * rot * CFrame.new(-pivot) * jointC0)
	leanWritten = true
end

---------------------------------------------------------------- camera

local function camActive(cam: Camera): boolean
	if cam.CameraType ~= Enum.CameraType.Custom or inCutscene() then
		return false
	end
	local ui = UIState.get()
	return not (ui.lockCamera or ui.lockControls)
end

local function rememberFov(value: number, kick: number)
	if ownFovCount > 256 then
		table.clear(ownFov)
		ownFovCount = 0
	end
	local key = math.floor(value * 100 + 0.5)
	if ownFov[key] == nil then
		ownFovCount += 1
	end
	ownFov[key] = kick
end

local function fovStep(cam: Camera, active: boolean, dt: number)
	springTo(punchFov, 0, 160, 0.75, dt)
	if not active then
		-- a cutscene / scripted camera owns the FOV now; start fresh when we're back
		fovApplied, fovTotal = 0, 0
		punchFov.x, punchFov.v = 0, 0
		lastFov = nil
		return
	end
	local cur = cam.FieldOfView
	local baseFov
	if lastFov and math.abs(cur - lastFov) < 0.001 then
		baseFov = cur - fovTotal
	else
		-- someone else set it. A restore of a value we wrote (saved mid-sprint) still has our kick in it.
		baseFov = cur - (ownFov[math.floor(cur * 100 + 0.5)] or 0)
	end
	local target = if sprinting and not reducedMotion() then M.SprintFov else 0
	fovApplied = approach(fovApplied, target, M.FovEaseSeconds, dt)
	if math.abs(target - fovApplied) < 0.01 then
		fovApplied = target
	end
	fovTotal = fovApplied + (if reducedMotion() then 0 else punchFov.x)
	local out = math.clamp(baseFov + fovTotal, 1, 120)
	if math.abs(out - cur) > 0.001 then
		cam.FieldOfView = out
	end
	lastFov = cam.FieldOfView
	if math.abs(fovTotal) > 0.3 then
		rememberFov(cam.FieldOfView, fovTotal)
	end
end

-- Camera - 1: take last frame's offset off before the camera module reads the camera
local function preCamera(dt: number)
	local cam = Workspace.CurrentCamera
	if applied ~= CFrame.identity then
		-- always take it off a Custom camera, even on the frame a cutscene starts, so nothing is left baked in
		if cam.CameraType == Enum.CameraType.Custom then
			cam.CFrame = cam.CFrame * applied:Inverse()
		end
		applied = CFrame.identity
	end

	local h, r = hum, root
	if not h or not r or not h.Parent or not r.Parent then
		return
	end
	speedStep(h, dt)

	local v = r.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local grounded = h.FloorMaterial ~= Enum.Material.Air
	sprintAmt = approach(sprintAmt, if sprinting and grounded and speed > 4 then 1 else 0, 0.3, dt)
	if v.Y < -maxFall then
		maxFall = -v.Y
	end
	leanStep(h, r, speed, dt)
end

-- Camera + 2: after the camera module (Camera) and the gun's recoil (Camera + 1)
local function postCamera(dt: number)
	local cam = Workspace.CurrentCamera
	local active = camActive(cam)
	fovStep(cam, active, dt)

	springTo(land, 0, 140, 0.7, dt)
	springTo(punchPitch, 0, 220, 0.7, dt)
	local r = root
	local v = if r and r.Parent then r.AssemblyLinearVelocity else Vector3.zero
	local flat = Vector3.new(v.X, 0, v.Z)
	bobPhase = (bobPhase + flat.Magnitude * M.BobStepsPerStud * dt) % 2
	local lateral = math.clamp(flat:Dot(cam.CFrame.RightVector) / M.SprintSpeed, -1, 1)
	roll = approach(roll, -lateral * M.StrafeRoll, 0.25, dt)

	if not active or not r or firstPerson(cam) then
		return
	end
	if reducedMotion() then
		-- only the punch, scaled down (like the gun's recoil)
		if math.abs(punchPitch.x) > 0.01 then
			local offset = CFrame.Angles(math.rad(punchPitch.x * 0.4), 0, 0)
			cam.CFrame = cam.CFrame * offset
			applied = offset
		end
		return
	end
	local pitch = M.BobPitch * sprintAmt * math.sin(2 * math.pi * bobPhase) - M.LandDipMax * land.x + punchPitch.x
	local rollNow = roll + M.BobRoll * sprintAmt * math.sin(math.pi * bobPhase)
	local offset = CFrame.new(0, -M.LandDipDrop * land.x, 0) * CFrame.Angles(math.rad(pitch), 0, math.rad(rollNow))
	cam.CFrame = cam.CFrame * offset
	applied = offset
end

---------------------------------------------------------------- character

local function onLanded()
	local fall = maxFall
	maxFall = 0
	local share = math.clamp((fall - M.LandDipMinFallSpeed) / (M.LandDipFallSpeed - M.LandDipMinFallSpeed), 0, 1)
	if share > 0 then
		land.v += GunRules.kickVelocity(share, 140)
	end
	-- jump cooldown: no hop for a moment after touching down
	local h = hum
	if h and M.JumpCooldown > 0 then
		jumpGen += 1
		local gen = jumpGen
		h:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		task.delay(M.JumpCooldown, function()
			if gen == jumpGen and h.Parent then
				h:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			end
		end)
	end
end

local function onCharacter(c: Model)
	for _, conn in charConns do
		conn:Disconnect()
	end
	table.clear(charConns)
	local h = c:WaitForChild("Humanoid", 10) :: Humanoid?
	local r = c:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not h or not r or player.Character ~= c then
		return
	end
	hum, root = h, r
	base, current, lastWritten, wasCarrying = M.WalkSpeed, h.WalkSpeed, nil, false
	leanFwd.x, leanFwd.v, leanSide.x, leanSide.v, lastYaw, leanWritten = 0, 0, 0, 0, nil, false
	land.x, land.v, maxFall, sprintAmt = 0, 0, 0, 0
	toggled = false
	setSprinting(false)

	joint = nil

	table.insert(charConns, h.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Landed then
			onLanded()
		end
	end))
end

---------------------------------------------------------------- input

local function onSprintAction(_: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
	if input.UserInputType == Enum.UserInputType.Keyboard then
		local d = ClientData.get()
		if d and d.Settings and d.Settings.SprintToggle == true then
			-- Settings > Sprint: Toggle (HUD Settings panel). Tap Shift to start, again to stop; stops when you stand still
			if state == Enum.UserInputState.Begin then
				toggled = not toggled
				idleFor = 0
			end
		else
			held = state == Enum.UserInputState.Begin
		end
		return Enum.ContextActionResult.Pass
	end
	-- gamepad L3 / the touch button: toggle
	if state == Enum.UserInputState.Begin then
		toggled = not toggled
		idleFor = 0
	end
	return Enum.ContextActionResult.Sink
end

local function bindInput()
	local keys: { any } = {}
	for _, k in M.SprintKeys do
		table.insert(keys, k)
	end
	for _, k in M.SprintToggleKeys do
		table.insert(keys, k)
	end
	ContextActionService:BindAction(SPRINT_ACTION, onSprintAction, true, table.unpack(keys))
	ContextActionService:SetTitle(SPRINT_ACTION, M.TouchButton.title)
	ContextActionService:SetPosition(SPRINT_ACTION, M.TouchButton.position)
	UserInputService.WindowFocusReleased:Connect(function()
		held = false
	end)
	-- touch: RUN sits just above the jump button (the phone sits left of it, PhoneController), and hides with the HUD
	-- (cutscenes, the phone camera) and while the gun's FIRE/AIM/R buttons are up (they use the same corner).
	if UserInputService.TouchEnabled then
		task.spawn(function()
			local pg = player:WaitForChild("PlayerGui")
			while task.wait(0.5) do
				local b = touchButton()
				if not b then
					continue
				end
				local touchGui = pg:FindFirstChild("TouchGui")
				local jump = touchGui and touchGui:FindFirstChild("JumpButton", true) :: GuiObject?
				if jump and jump.Visible and jump.AbsoluteSize.X > 0 then
					local want = jump.AbsolutePosition + Vector2.new((jump.AbsoluteSize.X - b.AbsoluteSize.X) / 2, -b.AbsoluteSize.Y - M.TouchButton.gap)
					local delta = want - b.AbsolutePosition
					if delta.Magnitude > 1 then
						b.Position = b.Position + UDim2.fromOffset(math.floor(delta.X + 0.5), math.floor(delta.Y + 0.5))
					end
				end
				local gunGui = pg:FindFirstChild("MTL_Gun")
				local gunTouch = gunGui and gunGui:FindFirstChild("Touch") :: GuiObject?
				b.Visible = not UIState.get().hideHUD and not (gunTouch and gunTouch.Visible)
			end
		end)
	end
end

---------------------------------------------------------------- API

function MovementController.setModifier(name: string, mult: number)
	modifiers[name] = mult
end

function MovementController.clearModifier(name: string)
	modifiers[name] = nil
end

function MovementController.isSprinting(): boolean
	return sprinting
end

-- A short camera kick: pitchDeg (+ = look up a touch) and an FOV pop, both spring back in ~0.2 s.
function MovementController.punch(pitchDeg: number, fovDeg: number?)
	punchPitch.v += GunRules.kickVelocity(pitchDeg, 220)
	if fovDeg and fovDeg ~= 0 then
		punchFov.v += GunRules.kickVelocity(fovDeg, 160)
	end
end

function MovementController.init()
	bindInput()
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	RunService:BindToRenderStep("MTL_MovePre", Enum.RenderPriority.Camera.Value - 1, preCamera)
	RunService:BindToRenderStep("MTL_MovePost", Enum.RenderPriority.Camera.Value + 2, postCamera)
	-- the phone boots after this controller; pick it up once it has loaded
	task.defer(function()
		local m = script.Parent:WaitForChild("PhoneController", 30)
		if m then
			local ok, p = pcall(require, m)
			Phone = if ok then p else nil
		end
	end)
end

return MovementController
