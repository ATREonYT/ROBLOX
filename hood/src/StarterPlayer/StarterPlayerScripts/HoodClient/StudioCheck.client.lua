-- Studio-only playtest check: shows on screen what broke, so a plain screenshot of a playtest is enough to report it.
-- Players never see it (it stops at once outside Studio). Top-right: a small "UI OK" tag once every UI screen has
-- loaded (the build name goes to the Output). If something fails, a red panel lists the client's script errors (from LogService,
-- including errors that happened before this script started), "Infinite yield" warnings (a script waiting forever),
-- and any of our screens still missing after 10 seconds. HUD.client prints "[HoodHUD] start" and "[HoodHUD] ready",
-- so a HUD that started but never finished is named too. Tap the panel to hide it.
local RunService = game:GetService('RunService')
if not RunService:IsStudio() then return end

local LogService = game:GetService('LogService')
local Players = game:GetService('Players')
local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')

local SCREENS = { 'HoodHUD', 'HoodGoals', 'HoodStore', 'HoodInventory', 'HoodWorld' }
local MAX_LINES = 10

local gui = Instance.new('ScreenGui')
gui.Name = 'HoodStudioCheck'
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local tag = Instance.new('TextLabel')
tag.Name = 'Tag'
tag.AnchorPoint = Vector2.new(1, 0)
tag.Position = UDim2.new(1, -8, 0, 8) -- (top-right, clear of the bottom bar's prices)
tag.Size = UDim2.fromOffset(150, 18)
tag.BackgroundTransparency = 0.35
tag.BackgroundColor3 = Color3.fromRGB(20, 22, 40)
tag.TextColor3 = Color3.fromRGB(235, 238, 255)
tag.Font = Enum.Font.GothamBold
tag.TextSize = 12
tag.TextXAlignment = Enum.TextXAlignment.Right
tag.Text = 'Studio check: loading...'
tag.Parent = gui

local panel = Instance.new('TextButton')
panel.Name = 'Problems'
panel.AutoButtonColor = false
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -34)
panel.Size = UDim2.new(0.7, 0, 0, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = Color3.fromRGB(150, 20, 30)
panel.BackgroundTransparency = 0.08
panel.TextColor3 = Color3.fromRGB(255, 255, 255)
panel.Font = Enum.Font.Code
panel.TextSize = 14
panel.TextWrapped = true
panel.TextXAlignment = Enum.TextXAlignment.Left
panel.TextYAlignment = Enum.TextYAlignment.Top
panel.Visible = false
panel.Parent = gui
local pad = Instance.new('UIPadding')
pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
pad.Parent = panel
panel.Activated:Connect(function() panel.Visible = false end)

gui.Parent = playerGui

local problems, seen = {}, {}
local hudStarted, hudReady = false, false
local function refresh()
	panel.Text = 'STUDIO CHECK (screenshot this, tap to hide)\n' .. table.concat(problems, '\n')
	panel.Visible = #problems > 0
end
local function add(line)
	line = string.sub(line, 1, 400)
	if seen[line] then return end
	seen[line] = true
	if #problems >= MAX_LINES then table.remove(problems, 1) end
	table.insert(problems, '• ' .. line)
	refresh()
end
local function consider(message, messageType)
	if message == '[HoodHUD] start' then hudStarted = true return end
	if message == '[HoodHUD] ready' then hudReady = true return end
	if messageType == Enum.MessageType.MessageError then
		add(message)
	elseif messageType == Enum.MessageType.MessageWarning and string.find(message, 'Infinite yield', 1, true) then
		add(message)
	end
end
for _, entry in LogService:GetLogHistory() do
	consider(entry.message, entry.messageType)
end
LogService.MessageOut:Connect(consider)

task.delay(10, function()
	local missing = {}
	for _, name in SCREENS do
		if not playerGui:FindFirstChild(name) then table.insert(missing, name) end
	end
	if not hudStarted then
		add('HUD script never started (is HUD under StarterPlayerScripts > HoodClient, and enabled?)')
	elseif not hudReady then
		add('HUD script started but did not finish: look for the error or yield above')
	end
	if #missing > 0 then add('Screens not loaded after 10 s: ' .. table.concat(missing, ', ')) end
	local root = workspace:FindFirstChild('TheBlockV2')
	local build = root and root:GetAttribute('BuildVersion') or 'map not found'
	tag.Text = (#problems == 0) and 'Studio check: UI OK' or 'Studio check: PROBLEMS'
	print('[StudioCheck] build: ' .. tostring(build) .. ' | UI ' .. ((#problems == 0) and 'OK' or 'PROBLEMS'))
	tag.TextColor3 = (#problems == 0) and Color3.fromRGB(140, 240, 160) or Color3.fromRGB(255, 150, 150)
end)
