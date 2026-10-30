--[[
	GameClient  (LocalScript)
	Location: StarterPlayer > StarterPlayerScripts > GameClient

	HUD, training-station shot animation, Grand Cannon launch on the client side.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local stations = workspace:WaitForChild("TrainingStations")

---------------------------------------------------------------------------
-- UI helpers
---------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "GameHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

local FONT = Enum.Font.FredokaOne

local function make(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		inst[k] = v
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	return inst
end

local function corner(r)
	return make("UICorner", { CornerRadius = UDim.new(0, r or 12) })
end

local function stroke(t, color)
	return make("UIStroke", { Thickness = t or 3, Color = color or Color3.fromRGB(20, 20, 30) })
end

local function label(text, size, color)
	return make("TextLabel", {
		BackgroundTransparency = 1,
		Font = FONT,
		Text = text,
		TextSize = size,
		TextColor3 = color or Color3.new(1, 1, 1),
	}, { make("UIStroke", { Thickness = 2.5, Color = Color3.fromRGB(20, 20, 30) }) })
end

-- Stats panel (bottom left, like the reference)
local statsPanel = make("Frame", {
	Name = "Stats",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 16, 1, -16),
	Size = UDim2.fromOffset(260, 110),
	BackgroundTransparency = 1,
	Parent = gui,
})
local strengthLabel = label("💪 0", 44, Color3.fromRGB(255, 215, 70))
strengthLabel.Size = UDim2.new(1, 0, 0, 50)
strengthLabel.TextXAlignment = Enum.TextXAlignment.Left
strengthLabel.Parent = statsPanel
local coinsLabel = label("🪙 0", 32, Color3.fromRGB(120, 255, 140))
coinsLabel.Position = UDim2.fromOffset(0, 52)
coinsLabel.Size = UDim2.new(1, 0, 0, 34)
coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
coinsLabel.Parent = statsPanel
local bestLabel = label("Best: 0 studs", 20)
bestLabel.Position = UDim2.fromOffset(0, 86)
bestLabel.Size = UDim2.new(1, 0, 0, 22)
bestLabel.TextXAlignment = Enum.TextXAlignment.Left
bestLabel.Parent = statsPanel

local showNotice -- defined below

-- Rebirth button (left side, above the stats)
local rebirthButton = make("TextButton", {
	Name = "Rebirth",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 16, 1, -140),
	Size = UDim2.fromOffset(200, 64),
	BackgroundColor3 = Color3.fromRGB(80, 170, 255),
	Font = FONT,
	Text = "",
	AutoButtonColor = true,
	Parent = gui,
}, { corner(14), stroke(4) })
local rebirthTitle = label("🔄 Rebirth (0)", 26)
rebirthTitle.Size = UDim2.new(1, 0, 0.55, 0)
rebirthTitle.Parent = rebirthButton
local rebirthCost = label("", 18, Color3.fromRGB(255, 240, 180))
rebirthCost.Position = UDim2.fromScale(0, 0.55)
rebirthCost.Size = UDim2.new(1, 0, 0.4, 0)
rebirthCost.Parent = rebirthButton

local confirmUntil = 0
rebirthButton.Activated:Connect(function()
	local cost = Config.RebirthCost(player:GetAttribute("Rebirths") or 0)
	if (player:GetAttribute("Strength") or 0) < cost then
		showNotice("You need " .. Config.Format(cost) .. " 💪 to rebirth!", Color3.fromRGB(255, 90, 90))
		return
	end
	-- tap twice to confirm, since it resets Strength
	if os.clock() > confirmUntil then
		confirmUntil = os.clock() + 3
		rebirthCost.Text = "Tap again to confirm!"
		return
	end
	confirmUntil = 0
	Remotes.RequestRebirth:FireServer()
end)

local function refreshStats()
	local rebirths = player:GetAttribute("Rebirths") or 0
	strengthLabel.Text = "💪 " .. Config.Format(player:GetAttribute("Strength") or 0)
	coinsLabel.Text = "🪙 " .. Config.Format(player:GetAttribute("Coins") or 0)
	bestLabel.Text = "Best: " .. Config.Format(player:GetAttribute("BestDistance") or 0) .. " studs"
	rebirthTitle.Text = "🔄 Rebirth (" .. rebirths .. ")"
	if os.clock() > confirmUntil then
		rebirthCost.Text = "Needs " .. Config.Format(Config.RebirthCost(rebirths)) .. " 💪"
	end
end
for _, attr in ipairs({ "Strength", "Rebirths", "Coins", "BestDistance" }) do
	player:GetAttributeChangedSignal(attr):Connect(refreshStats)
end
refreshStats()

local function pop(obj)
	local scale = obj:FindFirstChildOfClass("UIScale") or make("UIScale", { Parent = obj })
	scale.Scale = 1.15
	TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end
player:GetAttributeChangedSignal("Strength"):Connect(function()
	pop(strengthLabel)
end)

-- Training banner (bottom centre)
local trainingBar = make("Frame", {
	Name = "Training",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -20),
	Size = UDim2.fromOffset(420, 96),
	BackgroundColor3 = Color3.fromRGB(45, 120, 230),
	Visible = false,
	Parent = gui,
}, { corner(16), stroke(4) })
local trainingTitle = label("Training", 30)
trainingTitle.Size = UDim2.new(1, 0, 0, 40)
trainingTitle.Position = UDim2.fromOffset(0, 4)
trainingTitle.Parent = trainingBar
local leaveButton = make("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -8),
	Size = UDim2.fromOffset(200, 40),
	BackgroundColor3 = Color3.fromRGB(230, 70, 70),
	Font = FONT,
	Text = "Leave (Jump)",
	TextSize = 24,
	TextColor3 = Color3.new(1, 1, 1),
	Parent = trainingBar,
}, { corner(10), stroke(3) })

-- Notification (top centre)
local notice = label("", 34)
notice.AnchorPoint = Vector2.new(0.5, 0)
notice.Position = UDim2.new(0.5, 0, 0, 70)
notice.Size = UDim2.new(0.8, 0, 0, 44)
notice.TextTransparency = 1
notice.Parent = gui
local noticeStroke = notice:FindFirstChildOfClass("UIStroke")
noticeStroke.Transparency = 1

local noticeToken = 0
function showNotice(text, color)
	noticeToken += 1
	local my = noticeToken
	notice.Text = text
	notice.TextColor3 = color or Color3.new(1, 1, 1)
	notice.TextTransparency = 0
	noticeStroke.Transparency = 0
	pop(notice)
	task.delay(2.5, function()
		if my == noticeToken then
			TweenService:Create(notice, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			TweenService:Create(noticeStroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
	end)
end
Remotes.Notify.OnClientEvent:Connect(showNotice)

---------------------------------------------------------------------------
-- Training
---------------------------------------------------------------------------
local currentStation = nil

Remotes.TrainingState.OnClientEvent:Connect(function(stationId)
	currentStation = stationId
	if stationId then
		local info = Config.GetStation(stationId)
		local gain = Config.ShotGain(info, player:GetAttribute("Rebirths") or 0)
		trainingTitle.Text = info.Name .. "  •  +" .. Config.Format(gain) .. " 💪 per shot"
		trainingBar.Visible = true
		pop(trainingBar)
	else
		trainingBar.Visible = false
	end
end)

local function leave()
	if currentStation then
		Remotes.StopTraining:FireServer()
	end
end
leaveButton.Activated:Connect(leave)
UserInputService.JumpRequest:Connect(leave)

-- Shot animation ----------------------------------------------------------
local recoiling = {}

local function recoil(station)
	local cannon = station:FindFirstChild("Cannon")
	local muzzle = station:FindFirstChild("Muzzle")
	if not (cannon and muzzle) or recoiling[station] then
		return
	end
	recoiling[station] = true
	local home = cannon:GetPivot()
	local back = home - muzzle.CFrame.LookVector * 0.8
	local alpha = Instance.new("NumberValue")
	alpha.Changed:Connect(function(a)
		cannon:PivotTo(home:Lerp(back, a))
	end)
	local out = TweenService:Create(alpha, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 1 })
	local ret = TweenService:Create(alpha, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 0 })
	out.Completed:Connect(function()
		ret:Play()
	end)
	ret.Completed:Connect(function()
		cannon:PivotTo(home)
		alpha:Destroy()
		recoiling[station] = nil
	end)
	out:Play()
end

local function muzzleFlash(muzzle)
	local att = Instance.new("Attachment")
	att.Parent = muzzle
	local smoke = make("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(255, 240, 200), Color3.fromRGB(120, 120, 120)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.5) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(6, 12),
		SpreadAngle = Vector2.new(25, 25),
		EmissionDirection = Enum.NormalId.Front,
		Enabled = false,
		Parent = att,
	})
	local light = make("PointLight", { Color = Color3.fromRGB(255, 190, 90), Brightness = 6, Range = 12, Parent = att })
	smoke:Emit(12)
	TweenService:Create(light, TweenInfo.new(0.2), { Brightness = 0 }):Play()
	Debris:AddItem(att, 1)
end

local function floatingText(position, text, color)
	local anchor = make("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.one * 0.2,
		Position = position,
		Parent = workspace,
	})
	local bb = make("BillboardGui", {
		Size = UDim2.fromOffset(200, 60),
		AlwaysOnTop = true,
		StudsOffset = Vector3.new(0, 2, 0),
		Parent = anchor,
	})
	local t = label(text, 40, color)
	t.Size = UDim2.fromScale(1, 1)
	t.Parent = bb
	TweenService:Create(bb, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(math.random(-15, 15) / 10, 6, 0) }):Play()
	task.delay(0.5, function()
		TweenService:Create(t, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		TweenService:Create(t:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.4), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(anchor, 1)
end

local function hitTarget(target, position)
	local center = target:FindFirstChild("Center")
	if center and not target:GetAttribute("Shaking") then
		-- knock the target back a little, then snap it home
		target:SetAttribute("Shaking", true)
		local home = target:GetPivot()
		target:PivotTo(home - center.CFrame.LookVector * 0.4)
		task.delay(0.08, function()
			target:PivotTo(home)
			target:SetAttribute("Shaking", nil)
		end)
	end
	local att = Instance.new("Attachment")
	att.WorldPosition = position
	att.Parent = workspace.Terrain
	local sparks = make("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(255, 220, 80)),
		Size = NumberSequence.new(0.6, 0),
		Lifetime = NumberRange.new(0.3, 0.5),
		Speed = NumberRange.new(10, 20),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 1,
		Enabled = false,
		Parent = att,
	})
	sparks:Emit(20)
	Debris:AddItem(att, 1)
end

local function fireBall(station, isMine, gain)
	local muzzle = station:FindFirstChild("Muzzle")
	local target = station:FindFirstChild("Target")
	local center = target and target:FindFirstChild("Center")
	if not (muzzle and center) then
		return
	end
	recoil(station)
	muzzleFlash(muzzle)

	local ball = make("Part", {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.2,
		Color = Color3.fromRGB(35, 35, 40),
		Material = Enum.Material.SmoothPlastic,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = workspace,
	})
	make("Trail", {
		Attachment0 = make("Attachment", { Position = Vector3.new(0, 0.4, 0), Parent = ball }),
		Attachment1 = make("Attachment", { Position = Vector3.new(0, -0.4, 0), Parent = ball }),
		Lifetime = 0.15,
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
		Transparency = NumberSequence.new(0.3, 1),
		Parent = ball,
	})

	local p0 = muzzle.Position
	local p2 = center.Position
	local p1 = (p0 + p2) / 2 + Vector3.new(0, (p2 - p0).Magnitude * 0.25, 0)
	local duration = 0.35
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local a = math.min((os.clock() - t0) / duration, 1)
		local pos = (1 - a) ^ 2 * p0 + 2 * (1 - a) * a * p1 + a ^ 2 * p2
		ball.Position = pos
		if a >= 1 then
			conn:Disconnect()
			ball:Destroy()
			hitTarget(target, p2)
			if isMine then
				floatingText(p2, "+" .. Config.Format(gain) .. " 💪", Color3.fromRGB(255, 215, 70))
			end
		end
	end)
end

Remotes.TrainingShot.OnClientEvent:Connect(function(shooter, stationId, gain)
	local station = stations:FindFirstChild("Station_" .. stationId)
	if not station then
		return
	end
	-- Other players' shots only animate when nearby, to keep things cheap
	local isMine = shooter == player
	if not isMine then
		local cam = workspace.CurrentCamera
		if (cam.CFrame.Position - station:GetPivot().Position).Magnitude > 150 then
			return
		end
	end
	fireBall(station, isMine, gain)
end)

---------------------------------------------------------------------------
-- Grand Cannon launch
---------------------------------------------------------------------------
Remotes.LaunchPlayer.OnClientEvent:Connect(function(velocity)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (root and hum) then
		return
	end
	hum:ChangeState(Enum.HumanoidStateType.Freefall)
	root.AssemblyLinearVelocity = velocity

	local a0 = make("Attachment", { Position = Vector3.new(0, 1, 0), Parent = root })
	local a1 = make("Attachment", { Position = Vector3.new(0, -1, 0), Parent = root })
	make("Trail", {
		Attachment0 = a0,
		Attachment1 = a1,
		Lifetime = 0.6,
		Color = ColorSequence.new(Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 90, 60)),
		Transparency = NumberSequence.new(0.2, 1),
		LightEmission = 0.6,
		Parent = root,
	})
	Debris:AddItem(a0, Config.FLIGHT_TIMEOUT)
	Debris:AddItem(a1, Config.FLIGHT_TIMEOUT)
	showNotice("💥 BOOM!", Color3.fromRGB(255, 180, 60))
end)

Remotes.LaunchResult.OnClientEvent:Connect(function(distance, coins, isBest)
	local text = "You flew " .. Config.Format(distance) .. " studs!  +" .. Config.Format(coins) .. " 🪙"
	if isBest then
		text = "🏆 NEW BEST! " .. text
	end
	showNotice(text, isBest and Color3.fromRGB(255, 215, 70) or Color3.new(1, 1, 1))
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		for _, c in ipairs(root:GetChildren()) do
			if c:IsA("Trail") then
				c:Destroy()
			end
		end
	end
end)
