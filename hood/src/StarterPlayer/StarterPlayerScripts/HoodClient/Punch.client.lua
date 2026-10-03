-- Punching: while you're on a training mat, click (or tap the PUNCH button, or R2 on a gamepad) to throw a
-- punch worth a tenth of your per-second gain (the server checks and pays; LobbyService). The bag answers
-- right away on your screen: sparks in its rarity colour, a "+N" number and a small camera nudge that
-- grows with the bag's tier.
local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local TweenService = game:GetService('TweenService')
local RS = game:GetService('ReplicatedStorage')
local ActiveMap = require(RS.Shared.ActiveMap)
local Juice = require(RS.Shared.Juice)
local Format = require(RS.Shared.Format)
local Net = require(RS.Shared.Net)

local player = Players.LocalPlayer
local active = ActiveMap.wait(20)
if not active then return end
local remote = Net.get('Punch')

local models = {}
local function stationModel(id)
	local m = models[id]
	if not m or not m.Parent then
		m = active.Lobby:FindFirstChild('Training_' .. id, true)
		models[id] = m
	end
	return m
end
local function training()
	local id = player:GetAttribute('TrainingStation') or ''
	return id ~= '' and not id:find('Locked:') and id or nil
end

local last = 0
local function punch()
	local id = training()
	if not id or os.clock() - last < 0.14 then return end
	last = os.clock()
	remote:FireServer()
	local model = stationModel(id)
	local hit = model and model:GetAttribute('HitPoint')
	if not hit then return end
	local tier = model:GetAttribute('Tier') or (id == 'Ring' and 9) or 1
	local color = model:GetAttribute('HitColor')
	local gain = math.max(1, math.floor((player:GetAttribute('PowerRate') or 1) * 0.1))
	Juice.burst(hit, color, 0.8 + tier * 0.08)
	Juice.kick(tier >= 7 and 0.25 or 0.12)
	Juice.popNumber(hit + Vector3.new((math.random() - 0.5) * 2, 1.5, 0), '+' .. Format.compact(gain), color)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then punch() end
end)

-- A big round PUNCH button while you're training (the only way to punch on a phone).
local gui = Instance.new('ScreenGui')
gui.Name = 'PunchButton'
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild('PlayerGui')
local button = Instance.new('TextButton')
button.Name = 'Punch'
button.AnchorPoint = Vector2.new(1, 1)
button.Position = UDim2.new(1, -150, 1, -40)
button.Size = UDim2.fromOffset(112, 112)
button.BackgroundColor3 = Color3.fromRGB(255, 71, 87)
button.Text = 'PUNCH'
button.FontFace = Font.new('rbxasset://fonts/families/LuckiestGuy.json')
button.TextSize = 26
button.TextColor3 = Color3.new(1, 1, 1)
button.AutoButtonColor = false
button.Visible = false
button.Parent = gui
local corner = Instance.new('UICorner')
corner.CornerRadius = UDim.new(0.5, 0)
corner.Parent = button
local stroke = Instance.new('UIStroke')
stroke.Color = Color3.fromRGB(74, 11, 22)
stroke.Thickness = 4
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = button
local scale = Instance.new('UIScale')
scale.Parent = button
button.Activated:Connect(function()
	punch()
	scale.Scale = 0.88
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end)
local function refresh() button.Visible = training() ~= nil end
player:GetAttributeChangedSignal('TrainingStation'):Connect(refresh)
refresh()
