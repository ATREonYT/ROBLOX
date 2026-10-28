-- The first-join welcome (Oct 27, flow: the owner's "there aren't any welcoming traits"; the audit,
-- hood/docs/research/OUR_FIRST_10_MIN.md, found the kid dropped from the loading cover straight into a full HUD and an
-- instruction). Once per save, on its very first join (the server's FirstJoin, OnboardingRules.firstJoin):
--   * the camera starts in front of the Stage 1 gate, inside the hall, looking back down it at you, and glides down to its usual place
--     behind you (Duration seconds, eased in and out);
--   * "WELCOME TO THE BLOCK," and your name, in the game's title style (Shared/TextStyle: Montserrat Black, the thick dark
--     outline, the gold and white fills), on the UI's navy card (Oct 28: on a see-through band the world's own signs
--     showed through the words);
--   * then the camera is yours again, and the tutorial's first line types in.
-- ANY input (a key, a click, a touch, a pad button) ends it at once: the camera snaps back and the words fade. Nothing is
-- sold, nothing is timed against you, no flash. Sound stays off (the owner's call, Config/Sound).
-- It owns the screen meanwhile: PlayerGui HoodWelcome = true and the moment queue's 'Welcome' (Shared/MomentQueue), so
-- the tutorial's hint, the goal guide and every popup wait for it. Reduced Motion: no camera move, the words only.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')
local CollectionService = game:GetService('CollectionService')
local Kit = require(RS.Shared.UIKit)
local TextStyle = require(RS.Shared.TextStyle)
local ActiveMap = require(RS.Shared.ActiveMap)
local MomentQueue = require(RS.Shared.MomentQueue)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')

local Welcome = {
	Duration = 3.2, -- the camera's glide
	WordsIn = 0.35, -- the words start
	WordsOut = 3.1, -- the words start to leave (0.35 s)
	Height = 9, -- studs over your floor where the camera starts
	Front = 10, -- studs in front of the gate, on the hall's side (toward you): inside the hall, never through its walls
	WaitFor = 12, -- seconds after the cover lifts to hear whether this is a first join
}

---------------------------------------------------------------------------------------------- is it a first join?
local active = ActiveMap.wait(20)
if not active then playerGui:SetAttribute('HoodWelcome', false); return end
local t0 = os.clock()
while playerGui:FindFirstChild('HoodLoading') and os.clock() - t0 < 30 do task.wait(0.05) end
t0 = os.clock()
while player:GetAttribute('FirstJoin') == nil and os.clock() - t0 < Welcome.WaitFor do task.wait(0.05) end
if player:GetAttribute('FirstJoin') ~= true then return end
local char = player.Character or player.CharacterAdded:Wait()
local root = char:WaitForChild('HumanoidRootPart', 10)
if not root then playerGui:SetAttribute('HoodWelcome', false); return end

---------------------------------------------------------------------------------------------- the words
local gui, groot, fit = Kit.screen('HoodWelcome', nil, 60)
gui.IgnoreGuiInset = true
local holder = Kit.new('Frame', { Name = 'Words', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(900, 170), Parent = groot })
local scale = Kit.new('UIScale', { Scale = 0.6, Parent = holder })
-- (Oct 28) the backing: the mockup windows' navy card, as the tutorial's hint (a top-lit navy face, a thick ink outline,
-- a light rim inside it, a soft light band on its top half, an ink drop under it). It is solid, so no sign or label of
-- the world behind ever mixes with the words.
local CARD = { Pad = 26, Corner = 22, Outline = 5, Rim = 3, Drop = 7 }
local drop = Kit.new('Frame', { Name = 'CardDrop', AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, CARD.Drop), Size = UDim2.new(1, CARD.Pad, 1, 0), BackgroundColor3 = Kit.Skin.outline, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1, Parent = holder })
Kit.corner(CARD.Corner).Parent = drop
local card = Kit.new('Frame', { Name = 'Card', AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, CARD.Pad, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1, Parent = holder })
Kit.corner(CARD.Corner).Parent = card
Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(Kit.Skin.bodyTop, Kit.Skin.bodyBase), Parent = card })
Kit.stroke(Kit.Skin.outline, CARD.Outline, true).Parent = card
local rim = Kit.new('Frame', { Name = 'CardRim', AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -2 * CARD.Rim, 1, -2 * CARD.Rim), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1, Parent = card })
Kit.corner(CARD.Corner - CARD.Rim).Parent = rim
Kit.stroke(Kit.Skin.rim, CARD.Rim, true, 0.15).Parent = rim
local gloss = Kit.new('Frame', { Name = 'CardGloss', Position = UDim2.fromOffset(CARD.Rim + 1, CARD.Rim + 1), Size = UDim2.new(1, -2 * CARD.Rim - 2, 0.46, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1, Parent = card })
Kit.corner(CARD.Corner - CARD.Rim - 1).Parent = gloss
Kit.new('UIGradient', { Rotation = 90, Transparency = NumberSequence.new(0.86, 1), Parent = gloss })
local title = Kit.text({ Name = 'Title', Text = 'WELCOME TO THE BLOCK,', TextSize = 58, ZIndex = 3, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 72), Parent = holder })
TextStyle.apply(title, 'gold', { Shadow = true }) -- (ZIndex 3: over its drop shadow, which TextStyle puts at ZIndex - 1)
local name = player.DisplayName ~= '' and player.DisplayName or player.Name
local who = Kit.text({ Name = 'Name', Text = string.upper(name) .. '!', TextSize = 50, ZIndex = 3, Position = UDim2.fromOffset(0, 86), Size = UDim2.new(1, 0, 0, 64), Parent = holder })
who.TextScaled = true -- (a long name shrinks to fit; the outline is given, so nothing measures the label first)
Kit.new('UITextSizeConstraint', { MaxTextSize = 50, MinTextSize = 20, Parent = who })
TextStyle.apply(who, 'white', { Shadow = true, Thickness = 6 })
local function wordsAlpha(a) -- 0 hidden .. 1 shown
	card.BackgroundTransparency = 1 - a
	gloss.BackgroundTransparency = 1 - a
	drop.BackgroundTransparency = 1 - 0.5 * a
	for _, d in holder:GetDescendants() do
		local k = (d:IsA('TextLabel') and d.Name:find('Shadow$') or (d.Parent and d.Parent.Name:find('Shadow$'))) and 0.75 or 1 -- (the drop shadow stays see-through)
		if d:IsA('TextLabel') then d.TextTransparency = 1 - a * k end
		if d:IsA('UIStroke') then d.Transparency = 1 - a * k end
	end
end
wordsAlpha(0)
gui.Parent = playerGui
pcall(function() fit(gui.AbsoluteSize) end)

---------------------------------------------------------------------------------------------- the camera
local function gateOne()
	for _, g in CollectionService:GetTagged('HoodStageGate') do
		if g:GetAttribute('Stage') == 1 and g:IsDescendantOf(active.Root) then return g end
	end
	return nil
end
local cam = workspace.CurrentCamera
local reduced = player:GetAttribute('ReducedMotion') == true
local from, to, oldType = nil, nil, nil
local gate = gateOne()
if cam and gate and not reduced then
	local ok = pcall(function()
		to = cam.CFrame
		oldType = cam.CameraType
		local g = gate:GetPivot().Position
		local you = root.Position
		local toYou = Vector3.new(you.X - g.X, 0, you.Z - g.Z)
		local dist = toYou.Magnitude
		toYou = dist > 0.1 and toYou.Unit or Vector3.new(0, 0, 1)
		local aim = you + Vector3.new(0, 2, 0)
		-- (Oct 27, flow r2) in front of the gate, inside the hall, with a clear line to you: a wall, a sign or a
		-- prop in the way moves the start toward you until the line is clear
		local okP, params = pcall(function()
			local rp = RaycastParams.new()
			rp.FilterType = Enum.RaycastFilterType.Exclude
			rp.FilterDescendantsInstances = { char }
			return rp
		end)
		local function clear(eye)
			if not okP then return true end -- (no raycasts here, an offline preview: the first spot)
			local okR, hit = pcall(function() return workspace:Raycast(eye, aim - eye, params) end)
			return not okR or hit == nil
		end
		local eye
		for k = 0, 8 do
			local along = math.min(Welcome.Front + k * 4, math.max(dist - 12, 0))
			eye = Vector3.new(g.X, you.Y + Welcome.Height, g.Z) + toYou * along
			if clear(eye) then break end
		end
		from = CFrame.lookAt(eye, aim)
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = from
	end)
	if not ok then from, to = nil, nil end
end
if from and to then -- (where the glide runs, for the play-test's clear-path check)
	gui:SetAttribute('From', from.Position); gui:SetAttribute('To', to.Position)
end

---------------------------------------------------------------------------------------------- the moment
playerGui:SetAttribute('HoodWelcome', true)
local token = MomentQueue.acquire('Welcome', { Timeout = 1 })
local clock, done = 0, false
local conn, inputConn
local function ease(x) return (1 - math.cos(math.pi * math.clamp(x, 0, 1))) / 2 end
local function finish(skipped)
	if done then return end
	done = true
	if conn then conn:Disconnect() end
	if inputConn then inputConn:Disconnect() end
	pcall(function()
		if from and to and cam then
			cam.CFrame = to
			cam.CameraType = oldType or Enum.CameraType.Custom
		end
	end)
	gui:SetAttribute('Skipped', skipped == true)
	-- the words leave (faster when skipped), then the screen is the game's
	local out = skipped and 0.2 or 0.35
	local start = clock
	local fade
	fade = RunService.Heartbeat:Connect(function(dt)
		clock += math.clamp(type(dt) == 'number' and dt or 1 / 60, 0, 0.1)
		local a = 1 - math.clamp((clock - start) / out, 0, 1)
		wordsAlpha(math.min(a, gui:GetAttribute('Alpha') or 1))
		if a <= 0 then
			fade:Disconnect()
			gui:Destroy()
			playerGui:SetAttribute('HoodWelcome', false)
			MomentQueue.release(token)
		end
	end)
end
inputConn = UserInputService.InputBegan:Connect(function(input)
	local t = input and input.UserInputType
	if t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.MouseWheel or t == Enum.UserInputType.Focus then return end
	finish(true)
end)
conn = RunService.Heartbeat:Connect(function(dt)
	clock += math.clamp(type(dt) == 'number' and dt or 1 / 60, 0, 0.1)
	local ok = pcall(function()
		if from and to and cam then cam.CFrame = from:Lerp(to, ease(clock / Welcome.Duration)) end
		local a = math.clamp((clock - Welcome.WordsIn) / 0.3, 0, 1) * (1 - math.clamp((clock - Welcome.WordsOut) / 0.35, 0, 1))
		gui:SetAttribute('Alpha', a)
		wordsAlpha(a)
		scale.Scale = 0.6 + 0.4 * (1 - (1 - math.clamp((clock - Welcome.WordsIn) / 0.35, 0, 1)) ^ 3)
	end)
	if not ok or clock >= math.max(Welcome.Duration, Welcome.WordsOut + 0.35) then finish(false) end
end)
