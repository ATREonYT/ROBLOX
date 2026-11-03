--!strict
-- The GTA-style sit-down at the desk PC (vault: Research/Desk Computer Empire.md §4; timings in Config/OS.Desk).
--   server DeskState {type="sit", screen, chair}  ->  walk up, chair slides out, sit (Rig SitType), chair slides in,
--   camera: player cam -> over the shoulder -> pushes into the monitor -> Liberty OS fades in over it.
--   Leaving (OS close button, Backspace, B, or the server) runs it backwards and fires DeskAction {type="stand"}.
-- The room is per-owner (PropertyService), so moving its chair on the client is safe: nobody else sees it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.MTL.Net)
local OS = require(ReplicatedStorage.MTL.Config.OS)
local Rig = require(ReplicatedStorage.MTL.Rig)

local DeskController = {}

local player = Players.LocalPlayer
local K = OS.Desk

local active = false
local busy = false
local poseState: any = nil
local poseConn: RBXScriptConnection? = nil
local saved: any = {}

local function sibling(name: string): any?
	local m = script.Parent:FindFirstChild(name)
	if not m then
		return nil
	end
	local ok, mod = pcall(require, m)
	return if ok then mod else nil
end

local function settingsReduced(): boolean
	local CD = sibling("ClientData")
	local d = CD and CD.get()
	return d ~= nil and d.Settings ~= nil and d.Settings.ReducedMotion == true
end

local function myRoom(): Model?
	local f = workspace:FindFirstChild("MTL_Flats")
	local m = f and f:FindFirstChild("Flat_" .. player.UserId)
	return if m and m:IsA("Model") then m else nil
end

local function tween(obj: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- Tween a CFrame on anything (Model pivot / camera / anchored root) with a NumberValue driver.
local function tweenCF(t: number, from: CFrame, to: CFrame, set: (CFrame) -> (), style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local v = Instance.new("NumberValue")
	local conn = v.Changed:Connect(function(a)
		set(from:Lerp(to, a))
	end)
	local tw = tween(v, t, { Value = 1 }, style, dir)
	tw.Completed:Once(function()
		conn:Disconnect()
		v:Destroy()
		set(to)
	end)
	return tw
end

local function setPose(char: Model, pose: string?)
	if not pose then
		if poseConn then
			poseConn:Disconnect()
			poseConn = nil
		end
		if poseState then
			Rig.reset(poseState.joints, "Transform")
		end
		poseState = nil
		return
	end
	local now = os.clock()
	if not poseState then
		poseState = { joints = Rig.joints(char), s = { pose = pose, prevPose = "None", poseT0 = now } }
		poseConn = RunService.Stepped:Connect(function()
			if poseState then
				Rig.apply(poseState.joints, Rig.compose(poseState.s, os.clock()), "Transform")
			end
		end)
	else
		poseState.s.prevPose = poseState.s.pose
		poseState.s.pose = pose
		poseState.s.poseT0 = now
	end
end

-- A key tap while using the OS (arms twitch on the keyboard).
function DeskController.tap()
	if poseState then
		poseState.s.gesture = "Press"
		poseState.s.gestureT0 = os.clock()
		poseState.s.gestureDur = 0.35
	end
end

local function freezeAnimations(char: Model, on: boolean)
	local animate = char:FindFirstChild("Animate")
	if animate and animate:IsA("LocalScript") then
		animate.Enabled = not on
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if on and animator then
		for _, tr in animator:GetPlayingAnimationTracks() do
			tr:Stop(0.15)
		end
	end
end

local function screenCameraCF(screen: BasePart, fov: number): CFrame
	-- the screen's front face is its +Z (SurfaceGui Face = Back); frame its height with a hair of margin
	local h = screen.Size.Y
	local w = screen.Size.X
	local cam = workspace.CurrentCamera
	local aspect = cam.ViewportSize.X / math.max(1, cam.ViewportSize.Y)
	local vfov = math.rad(fov)
	local distH = (h / 2) / math.tan(vfov / 2)
	local distW = (w / 2) / (math.tan(vfov / 2) * aspect)
	local dist = math.max(distH, distW) * 1.04
	local front = screen.CFrame * CFrame.new(0, 0, screen.Size.Z / 2 + dist)
	return CFrame.lookAt(front.Position, screen.Position)
end

local function liberty(): any?
	local os_ = script.Parent:FindFirstChild("OS")
	local m = os_ and os_:FindFirstChild("LibertyOS")
	if not m then
		return nil
	end
	local ok, mod = pcall(require, m)
	return if ok then mod else nil
end

local function sit(msg: any)
	if active or busy then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local room = myRoom()
	if not char or not hum or not root or not room then
		Net.get("DeskAction"):FireServer({ type = "stand" })
		return
	end
	busy = true
	active = true
	local UIState = sibling("UIState")
	if UIState then
		UIState.push("Desk", { hideHUD = true, hidePhone = true, hideWaypoints = true, lockControls = true, lockCamera = true })
	end
	local reduced = settingsReduced()
	local screen = room:FindFirstChild("Screen", true) :: BasePart?
	local chair = room:FindFirstChild("DeskChair", true) :: Model?
	local chairCF: CFrame = msg.chair -- floor point under the chair, facing the desk (world)
	local fwd = chairCF.LookVector
	local height = Rig.rootHeight(char)
	local drop = Rig.Poses.SitType and (Rig.Poses.SitType :: any)._drop[1] or 1.7

	saved = {
		anchored = root.Anchored,
		autoRotate = hum.AutoRotate,
		camType = workspace.CurrentCamera.CameraType,
		camFov = workspace.CurrentCamera.FieldOfView,
		chairPivot = if chair then chair:GetPivot() else nil,
		rootCF = root.CFrame,
	}
	hum.AutoRotate = false
	root.Anchored = true
	root.AssemblyLinearVelocity = Vector3.zero
	freezeAnimations(char, true)

	-- 1) walk up: to the side of the chair, facing the desk
	local right = fwd:Cross(Vector3.yAxis).Unit
	local standPos = chairCF.Position + right * 1.6 + Vector3.new(0, height, 0)
	local standCF = CFrame.lookAt(standPos, standPos + fwd)
	tweenCF(K.WalkUp, root.CFrame, standCF, function(cf)
		root.CFrame = cf
	end, Enum.EasingStyle.Sine)

	-- camera starts its move at once (it reads as one motion)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local back = -fwd
	local shoulderPos = chairCF.Position + right * K.ShoulderOffset.X + Vector3.yAxis * K.ShoulderOffset.Y + back * K.ShoulderOffset.Z
	local shoulderCF = CFrame.lookAt(shoulderPos, if screen then screen.Position else chairCF.Position + fwd * 3 + Vector3.yAxis * 3.5)
	tweenCF(if reduced then 0.01 else K.CamShoulder, cam.CFrame, shoulderCF, function(cf)
		cam.CFrame = cf
	end, Enum.EasingStyle.Quint)
	tween(cam, K.CamShoulder, { FieldOfView = K.FovShoulder })
	task.wait(K.WalkUp)

	-- 2) chair out (slides back and turns a little toward you)
	local chairOut: CFrame? = nil
	if chair and saved.chairPivot then
		chairOut = saved.chairPivot * CFrame.new(0, 0, 0) + back * K.ChairBack
		chairOut = (chairOut :: CFrame) * CFrame.Angles(0, math.rad(K.ChairTurn), 0)
		tweenCF(K.ChairOut, saved.chairPivot, chairOut :: CFrame, function(cf)
			chair:PivotTo(cf)
		end)
	end
	-- turn toward the seat while it moves
	local seatPos = chairCF.Position + back * K.ChairBack + Vector3.new(0, height - drop + 0.55, 0)
	task.wait(K.ChairOut * 0.6)

	-- 3) sit: drop onto the pulled-out chair, the pose blends in
	setPose(char, "SitType")
	local sitCF = CFrame.lookAt(seatPos, seatPos + fwd)
	tweenCF(K.Sit, root.CFrame, sitCF, function(cf)
		root.CFrame = cf
	end, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	task.wait(K.Sit)

	-- 4) roll in: chair + you slide forward together
	local inCF = sitCF + fwd * K.ChairBack
	tweenCF(K.ChairIn, sitCF, inCF, function(cf)
		root.CFrame = cf
	end, Enum.EasingStyle.Sine)
	if chair and saved.chairPivot then
		tweenCF(K.ChairIn, chairOut :: CFrame, saved.chairPivot, function(cf)
			chair:PivotTo(cf)
		end, Enum.EasingStyle.Sine)
	end
	local stillTurning = math.max(0, K.CamShoulder - K.WalkUp - K.ChairOut * 0.6 - K.Sit)
	task.wait(math.max(K.ChairIn, stillTurning))

	-- 5) push into the screen
	if screen then
		local target = screenCameraCF(screen, K.FovScreen)
		if reduced then
			cam.CFrame = target
			cam.FieldOfView = K.FovScreen
		else
			tweenCF(K.CamPush, cam.CFrame, target, function(cf)
				cam.CFrame = cf
			end, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			tween(cam, K.CamPush, { FieldOfView = K.FovScreen }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(K.CamPush * 0.8)
		end
	end

	-- 6) hand-off to the full-screen OS
	local L = liberty()
	if L then
		L.open({ fade = K.HandOff, onClose = function()
			DeskController.stand()
		end, onTap = DeskController.tap })
	end
	busy = false
end

function DeskController.stand(fromServer: boolean?)
	if not active or busy then
		return
	end
	busy = true
	local L = liberty()
	if L then
		L.close(0.15)
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local cam = workspace.CurrentCamera
	if root and char then
		-- pull back, stand up beside the chair
		local fwd = root.CFrame.LookVector
		local right = fwd:Cross(Vector3.yAxis).Unit
		local height = Rig.rootHeight(char)
		local standPos = root.Position + right * 1.6 + Vector3.new(0, 0, 0)
		standPos = Vector3.new(standPos.X, (saved.rootCF and saved.rootCF.Position.Y) or (root.Position.Y + 1.7), standPos.Z)
		_ = height
		tweenCF(K.Exit, cam.CFrame, cam.CFrame * CFrame.new(0, 1.2, 4.5), function(cf)
			cam.CFrame = cf
		end, Enum.EasingStyle.Sine)
		tween(cam, K.Exit, { FieldOfView = saved.camFov or 70 })
		task.wait(K.Exit * 0.4)
		setPose(char, nil)
		tweenCF(K.Exit * 0.6, root.CFrame, CFrame.lookAt(standPos, standPos + fwd), function(cf)
			root.CFrame = cf
		end, Enum.EasingStyle.Quad)
		task.wait(K.Exit * 0.6)
		root.Anchored = saved.anchored or false
		freezeAnimations(char, false)
	end
	if hum then
		hum.AutoRotate = if saved.autoRotate == nil then true else saved.autoRotate
	end
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = saved.camFov or 70
	local UIState = sibling("UIState")
	if UIState then
		UIState.pop("Desk")
	end
	active = false
	busy = false
	if not fromServer then
		Net.get("DeskAction"):FireServer({ type = "stand" })
	end
end

function DeskController.isActive(): boolean
	return active
end

function DeskController.init()
	Net.get("DeskState").OnClientEvent:Connect(function(msg: any)
		if type(msg) ~= "table" then
			return
		end
		if msg.type == "sit" then
			task.spawn(sit, msg)
		elseif msg.type == "stand" then
			task.spawn(DeskController.stand, true)
		elseif msg.type == "push" then
			local L = liberty()
			if L and L.push then
				L.push(msg.app, msg.data)
			end
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not active or busy then
			return
		end
		if input.KeyCode == Enum.KeyCode.ButtonB or (not processed and input.KeyCode == Enum.KeyCode.Backspace) then
			local L = liberty()
			if L and L.back and L.back() then
				return -- the OS used it (closed an app first)
			end
			DeskController.stand()
		end
	end)
	player.CharacterAdded:Connect(function()
		if active then
			setPose(player.Character :: Model, nil)
			local L = liberty()
			if L then
				L.close(0)
			end
			local UIState = sibling("UIState")
			if UIState then
				UIState.pop("Desk")
			end
			workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
			active = false
			busy = false
		end
	end)
end

return DeskController
