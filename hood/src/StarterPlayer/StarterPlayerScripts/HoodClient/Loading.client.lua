-- The loading screen (brief 29, P4: "make avatar load in correctly, many games do that, make it like Tower Incremental"). A
-- branded cover goes up the moment this script runs and stays until what a player would otherwise see half-made is ready:
--   * the map is built (ActiveMap), * the profile is loaded (ProfileReady, the server's attribute), * your character is in
--   the world, and * your avatar's look has loaded (Player:HasAppearanceLoaded: no grey blocks, no bald or naked frames).
-- A studded bar fills as each one arrives. Then the cover fades (0.4 s) and the game is there, complete. It never traps a
-- player: after MaxWait seconds it opens whatever has not finished (a slow avatar finishes under the open game), and it is
-- shown once per join, never on a respawn. It sits above every other screen (DisplayOrder 1000) and is flat 2D UIKit.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')
local Kit = require(RS.Shared.UIKit)
local ActiveMap = require(RS.Shared.ActiveMap)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')
local MIN_SHOW, MAX_WAIT = 0.6, 12
local hex = Kit.hex

local gui, root, fit = Kit.screen('HoodLoading', nil, 1000)
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None
local cover = Kit.new('Frame', { Name = 'Cover', Size = UDim2.fromScale(1, 1), BackgroundColor3 = hex('0E1020'), BorderSizePixel = 0, Active = true, ZIndex = 1, Parent = root })
Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(hex('1B2140'), hex('080A14')), Parent = cover })
local title = Kit.text({ Name = 'Title', Text = '+1 HOOD EVOLUTION', TextSize = 64, Stroke = hex('060608'), StrokeThickness = 7, TextColor3 = hex('FFD21F'), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(900, 90), ZIndex = 2, Parent = root })
local sub = Kit.text({ Name = 'Line', Text = 'Getting your look ready...', TextSize = 24, Stroke = hex('060608'), StrokeThickness = 3, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.54), Size = UDim2.fromOffset(700, 36), ZIndex = 2, Parent = root })
local bar, fill = Kit.bar({ Name = 'Progress', Width = 420, Height = 34, Tone = 'level', Value = 0.05, ZIndex = 2 })
bar.AnchorPoint, bar.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.62)
bar.Parent = root
gui.Parent = playerGui
pcall(function() fit(gui.AbsoluteSize) end)

local t0 = os.clock()
local function mapReady() return ActiveMap.get() ~= nil end
local function dataReady() return player:GetAttribute('ProfileReady') == true end
local function bodyReady()
	local c = player.Character
	return c ~= nil and c.Parent ~= nil and c:FindFirstChild('HumanoidRootPart') ~= nil and c:FindFirstChildOfClass('Humanoid') ~= nil
end
local function lookReady()
	if not bodyReady() then return false end
	local ok, loaded = pcall(function() return player:HasAppearanceLoaded() end)
	return not ok or loaded == true -- (no such call here, e.g. a preview: the body is enough)
end
local function progress()
	local n = 0.05
	for _, ready in { mapReady(), dataReady(), bodyReady(), lookReady() } do
		if ready then n += 0.2375 end
	end
	return n
end

local shownOnce = false
task.spawn(function()
	while os.clock() - t0 < MAX_WAIT do
		local p = progress()
		TweenService:Create(fill, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(math.min(p, 1), 1) }):Play()
		if p >= 0.999 and os.clock() - t0 >= MIN_SHOW then break end
		task.wait(0.1)
	end
	fill.Size = UDim2.fromScale(1, 1)
	sub.Text = 'Ready!'
	task.wait(0.15)
	shownOnce = true
	-- the cover goes: every part of it fades together
	local info = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(cover, info, { BackgroundTransparency = 1 }):Play()
	for _, d in { title, sub } do
		TweenService:Create(d, info, { TextTransparency = 1 }):Play()
		local st = d:FindFirstChildOfClass('UIStroke')
		if st then TweenService:Create(st, info, { Transparency = 1 }):Play() end
	end
	for _, d in bar:GetDescendants() do
		if d:IsA('Frame') then TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play() end
		if d:IsA('TextLabel') then TweenService:Create(d, info, { TextTransparency = 1 }):Play() end
		if d:IsA('UIStroke') then TweenService:Create(d, info, { Transparency = 1 }):Play() end
	end
	task.wait(0.45)
	gui:Destroy()
end)
