--!strict
-- Downed state on the client (LihFolk build list item 4). Helper of GunController (required + init'd by it).
-- Every character with attribute MTL_Downed (Services/GunDowned) is posed lying face down and crawling, on every
-- screen: a procedural pose written over the animation each frame (PreSimulation, after GunPose), so nothing to
-- upload. Arms reach and pull, legs drag, the head looks up; the crawl speeds up with how fast they move.
-- Your own downed state: crawl speed (MovementController modifier), no jump, no sprint, the camera drops low, and a
-- "YOU'RE DOWN" card counts the bleed-out. The finish prompt (MTL_FinishPrompt) shows only to players who could
-- shoot you, never on your own body. Works on Motor6D and AnimationConstraint rigs (R15).
--   DownedPose.localDowned(seconds)   GunController calls this on the server's "downed" effect
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Guns = require(ReplicatedStorage.MTL.Config.Guns)
local Movement = require(ReplicatedStorage.MTL.Config.Movement)
local Theme = require(ReplicatedStorage.MTL.UI.Theme)
local MovementController = require(script.Parent.MovementController)

local D = Guns.Downed
local C = Theme.Colors
local player = Players.LocalPlayer

local DownedPose = {}

type Joint = { inst: Instance, c0: CFrame }
type Rig = { hrp: BasePart, hum: Humanoid, j: { [string]: Joint }, blend: number, phase: number }

local NAMES = {
	root = { "LowerTorso", "Root" },
	waist = { "UpperTorso", "Waist" },
	neck = { "Head", "Neck" },
	rs = { "RightUpperArm", "RightShoulder" },
	re = { "RightLowerArm", "RightElbow" },
	ls = { "LeftUpperArm", "LeftShoulder" },
	le = { "LeftLowerArm", "LeftElbow" },
	rh = { "RightUpperLeg", "RightHip" },
	rk = { "RightLowerLeg", "RightKnee" },
	lh = { "LeftUpperLeg", "LeftHip" },
	lk = { "LeftLowerLeg", "LeftKnee" },
}

local rigs: { [Model]: Rig } = {}

local function jointOf(part: Instance?, name: string): Joint?
	local j = part and part:FindFirstChild(name)
	if not j then
		return nil
	end
	if j:IsA("Motor6D") then
		return { inst = j, c0 = j.C0 }
	elseif j.ClassName == "AnimationConstraint" then
		local a0 = (j :: any).Attachment0 :: Attachment?
		if a0 then
			return { inst = j, c0 = a0.CFrame }
		end
	end
	return nil
end

local function rigOf(char: Model): Rig?
	local r = rigs[char]
	if r and r.hrp.Parent then
		return r
	end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then
		return nil
	end
	local j: { [string]: Joint } = {}
	for key, n in NAMES do
		local found = jointOf(char:FindFirstChild(n[1]), n[2])
		if not found then
			return nil -- R6 or a custom rig: leave it alone
		end
		j[key] = found
	end
	local nr: Rig = { hrp = hrp, hum = hum, j = j, blend = 0, phase = math.random() * 6 }
	rigs[char] = nr
	return nr
end

-- A Transform that rotates the child by `rot` (axes of the parent part) about the joint, then moves it by `off`
-- (parent part space). Conjugating by C0's rotation makes it right whatever way the joint frame is turned.
local function tf(j: Joint, rot: CFrame, off: Vector3?): CFrame
	local r = j.c0.Rotation
	local ri = r:Inverse()
	return CFrame.new(ri * (off or Vector3.zero)) * ri * rot * r
end

local function set(j: Joint, t: CFrame, w: number)
	local inst = j.inst :: any
	inst.Transform = if w >= 0.999 then t else (inst.Transform :: CFrame):Lerp(t, w)
end

local rad = math.rad
local function rx(d: number): CFrame
	return CFrame.Angles(rad(d), 0, 0)
end

local function pose(char: Model, r: Rig, dt: number)
	r.blend = math.min(1, r.blend + dt / 0.35)
	local w = r.blend
	local v = r.hrp.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local moving = math.clamp(speed / math.max(1, D.CrawlSpeed), 0, 1)
	r.phase += dt * (1.2 + 5 * moving)
	local s = math.sin(r.phase)
	local amp = 0.25 + 0.75 * moving
	local j = r.j

	-- the body lies face down: tip the lower torso forward and drop it to the ground
	local drop = r.hum.HipHeight + r.hrp.Size.Y / 2 + j.root.c0.Position.Y - 0.55
	set(j.root, tf(j.root, CFrame.Angles(rad(-86), rad(4 * s * amp), 0), Vector3.new(0, -drop, 0)), w)
	set(j.waist, tf(j.waist, CFrame.Angles(rad(9 + 3 * s * amp), rad(-6 * s * amp), 0)), w)
	set(j.neck, tf(j.neck, rx(62)), w)
	-- arms reach out in front and pull, one after the other
	set(j.rs, tf(j.rs, CFrame.Angles(rad(150 + 28 * s * amp), 0, rad(-12))), w)
	set(j.ls, tf(j.ls, CFrame.Angles(rad(150 - 28 * s * amp), 0, rad(12))), w)
	set(j.re, tf(j.re, rx(25 + 30 * math.max(0, -s) * amp)), w)
	set(j.le, tf(j.le, rx(25 + 30 * math.max(0, s) * amp)), w)
	-- legs drag, a little push on each side
	set(j.rh, tf(j.rh, CFrame.Angles(rad(-6 - 14 * s * amp), 0, rad(6))), w)
	set(j.lh, tf(j.lh, CFrame.Angles(rad(-6 + 14 * s * amp), 0, rad(-6))), w)
	set(j.rk, tf(j.rk, rx(-12 - 22 * math.max(0, s) * amp)), w)
	set(j.lk, tf(j.lk, rx(-12 - 22 * math.max(0, -s) * amp)), w)
end

---------------------------------------------------------------- finish prompt visibility

local function canFinishHere(char: Model): boolean
	if char == player.Character then
		return false
	end
	local me = player.Character
	if not me or me:GetAttribute("MTL_Downed") == true then
		return false
	end
	local hum = me:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0 and player:GetAttribute("MTL_Path") == "Criminal"
end

---------------------------------------------------------------- your own downed state

local gui: ScreenGui? = nil
local localOn = false
local localGen = 0

local function card(): ScreenGui
	if gui and gui.Parent then
		return gui
	end
	local g = Instance.new("ScreenGui")
	g.Name = "MTL_Downed"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 39
	g.Enabled = false
	local panel = Instance.new("CanvasGroup")
	panel.Name = "Card"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -150)
	panel.Size = UDim2.fromOffset(340, 92)
	panel.BackgroundColor3 = C.Glass
	panel.BackgroundTransparency = C.GlassTransparency
	panel.Parent = g
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.Danger
	stroke.Transparency = 0.4
	stroke.Parent = panel
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(0, 12)
	title.Size = UDim2.new(1, 0, 0, 28)
	title.FontFace = Theme.Fonts.Display
	title.Text = "YOU'RE DOWN"
	title.TextColor3 = C.Danger
	title.TextSize = 26
	title.Parent = panel
	local sub = Instance.new("TextLabel")
	sub.Name = "Sub"
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromOffset(0, 44)
	sub.Size = UDim2.new(1, 0, 0, 18)
	sub.FontFace = Theme.Fonts.Body
	sub.Text = "Crawl to cover"
	sub.TextColor3 = C.TextDim
	sub.TextSize = 15
	sub.Parent = panel
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 72)
	bar.Size = UDim2.new(1, -48, 0, 4)
	bar.BackgroundColor3 = C.Shadow
	bar.BackgroundTransparency = 0.5
	bar.BorderSizePixel = 0
	bar.Parent = panel
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = C.Danger
	fill.BorderSizePixel = 0
	fill.Parent = bar
	g.Parent = player:WaitForChild("PlayerGui")
	gui = g
	return g
end

local function setLocal(on: boolean, char: Model?)
	if on == localOn then
		return
	end
	localOn = on
	localGen += 1
	local gen = localGen
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if on then
		MovementController.setModifier("Downed", D.CrawlSpeed / Movement.WalkSpeed)
		if hum then
			hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
			task.delay(0.2, function()
				if gen == localGen and hum.Parent then
					TweenService:Create(hum, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { CameraOffset = Vector3.new(0, -2.2, 0) }):Play()
				end
			end)
		end
		local g = card()
		g.Enabled = true
		local panel = g:FindFirstChild("Card") :: CanvasGroup
		panel.GroupTransparency = 1
		TweenService:Create(panel, TweenInfo.new(0.3), { GroupTransparency = 0 }):Play()
		task.spawn(function()
			local sub = panel:FindFirstChild("Sub") :: TextLabel
			local fill = (panel :: any).Bar.Fill :: Frame
			while gen == localGen do
				local at = char and char:GetAttribute("MTL_DownedAt")
				local left = if type(at) == "number" then D.BleedSeconds - (Workspace:GetServerTimeNow() - at) else D.BleedSeconds
				left = math.max(0, left)
				sub.Text = "Crawl to cover. Bleeding out in " .. math.ceil(left)
				fill.Size = UDim2.fromScale(left / D.BleedSeconds, 1)
				task.wait(0.1)
			end
		end)
	else
		MovementController.clearModifier("Downed")
		if hum and hum.Parent then
			hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			hum.CameraOffset = Vector3.zero
		end
		if gui then
			gui.Enabled = false
		end
	end
end

function DownedPose.localDowned(_seconds: number)
	local char = player.Character
	if char and char:GetAttribute("MTL_Downed") == true then
		setLocal(true, char)
	end
end

---------------------------------------------------------------- loop

function DownedPose.init()
	local prevGate = MovementController.sprintGate
	MovementController.sprintGate = function()
		if localOn then
			return false
		end
		return prevGate == nil or prevGate()
	end
	RunService.PreSimulation:Connect(function(dt)
		for _, p in Players:GetPlayers() do
			local char = p.Character
			if char then
				local down = char:GetAttribute("MTL_Downed") == true
				local hum = char:FindFirstChildOfClass("Humanoid")
				if down and hum and hum.Health > 0 then
					local r = rigOf(char)
					if r then
						pose(char, r, dt)
					end
					local hrp = char:FindFirstChild("HumanoidRootPart")
					local prompt = hrp and hrp:FindFirstChild("MTL_FinishPrompt")
					if prompt and prompt:IsA("ProximityPrompt") then
						local want = canFinishHere(char)
						if prompt.Enabled ~= want then
							prompt.Enabled = want
						end
					end
				else
					rigs[char] = nil
				end
				if p == player then
					setLocal(down and hum ~= nil and hum.Health > 0, char)
				end
			elseif p == player then
				setLocal(false, nil)
			end
		end
	end)
end

return DownedPose
