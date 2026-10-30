-- Prompts (Oct 28, the owner: "make the text shown to the user on the screen match the UI more ... more cartoony"):
-- every "press E" prompt in the game (the ARMORY's guns, the pass pads, the portals, the wheel) drawn as the UI's own
-- card instead of Roblox's thin grey one: the mockup windows' navy card with a thick ink outline, a gold key badge
-- ("E", a pad's button, or TAP on a phone), the action in TextStyle's white words and the object under it in cyan,
-- popping in with a small overshoot. Holding fills a green bar along its foot. The prompts keep working exactly as
-- before (ProximityPromptService still owns the keys); this only draws them (each prompt's Style is set to Custom on
-- this client), and a click or a tap on the card holds it like the key.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local PPS = game:GetService('ProximityPromptService')
local TweenService = game:GetService('TweenService')
local Kit = require(RS.Shared.UIKit)
local TextStyle = require(RS.Shared.TextStyle)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')
local W, H = 236, 66 -- (px: the card; the badge is H - 16 square)

local function custom(p)
	if p:IsA('ProximityPrompt') then pcall(function() p.Style = Enum.ProximityPromptStyle.Custom end) end
end
for _, d in workspace:GetDescendants() do custom(d) end
workspace.DescendantAdded:Connect(custom)

local function keyText(prompt, inputType)
	if inputType == Enum.ProximityPromptInputType.Touch then return 'TAP' end
	if inputType == Enum.ProximityPromptInputType.Gamepad then
		local name = prompt.GamepadKeyCode.Name
		return (name:gsub('^Button', ''))
	end
	local k = prompt.KeyboardKeyCode
	return k == Enum.KeyCode.Unknown and '' or k.Name
end

local cards = {} -- [n] = { Prompt, Gui, Fill, Conns }
local function close(i)
	local c = cards[i]
	if not c then return end
	table.remove(cards, i)
	for _, conn in c.Conns do conn:Disconnect() end
	c.Gui:Destroy()
end
local function find(prompt)
	for i, c in cards do if c.Prompt == prompt then return i end end
	return nil
end

local function show(prompt, inputType)
	local old = find(prompt)
	if old then close(old) end
	local gui = Instance.new('BillboardGui')
	gui.Name = 'HoodPrompt'
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(W, H)
	gui.SizeOffset = Vector2.new(prompt.UIOffset.X / W, prompt.UIOffset.Y / H)
	gui.StudsOffset = Vector3.new(0, 0.6, 0)
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Adornee = prompt.Parent
	gui.Active = true
	local holder = Kit.new('Frame', { Name = 'Card', AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -8, 1, -8), BackgroundColor3 = Kit.Color.white, BorderSizePixel = 0, Parent = gui })
	Kit.corner(12).Parent = holder
	Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(Kit.Skin.bodyTop, Kit.Skin.bodyBase), Parent = holder })
	Kit.stroke(Kit.Skin.outline, 3.5, true).Parent = holder
	local rim = Kit.new('Frame', { Name = 'Rim', Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4), BackgroundTransparency = 1, Parent = holder })
	Kit.corner(10).Parent = rim
	Kit.stroke(Kit.Skin.rim, 1.5, true, 0.15).Parent = rim
	-- the key badge
	local b = H - 22
	local badge = Kit.new('Frame', { Name = 'Key', AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(b, b), BackgroundColor3 = Kit.Color.white, BorderSizePixel = 0, ZIndex = 2, Parent = holder })
	Kit.corner(9).Parent = badge
	Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(Kit.hex('FFEA5C'), Kit.hex('F7B400')), Parent = badge })
	Kit.stroke(Kit.hex('5A3A00'), 3, true).Parent = badge
	local key = keyText(prompt, inputType)
	local kt = Kit.text({ Name = 'K', Text = key, TextSize = #key > 1 and 15 or 24, Position = UDim2.fromOffset(0, -1), ZIndex = 3, Parent = badge })
	TextStyle.apply(kt, 'white', { Thickness = 2.5 })
	-- the words
	local left = 8 + b + 10
	local hasObject = prompt.ObjectText ~= ''
	local action = Kit.text({ Name = 'Action', Text = prompt.ActionText, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(left, hasObject and 6 or 0), Size = UDim2.new(1, -left - 8, hasObject and 0.5 or 1, 0), ZIndex = 2, Parent = holder })
	action.TextSize = Kit.fitSize(prompt.ActionText, 21, W - left - 18, 13)
	TextStyle.apply(action, 'white', { Thickness = 2.8 })
	local object = Kit.text({ Name = 'Object', Text = prompt.ObjectText, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, left, 0.5, 0), Size = UDim2.new(1, -left - 8, 0.4, 0), ZIndex = 2, Parent = holder })
	object.Visible = hasObject
	TextStyle.apply(object, 'cyan', { Thickness = 2.2 })
	-- the hold bar along its foot
	local track = Kit.new('Frame', { Name = 'Hold', AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -4), Size = UDim2.new(1, -20, 0, 5), BackgroundColor3 = Kit.Skin.well, BorderSizePixel = 0, Visible = prompt.HoldDuration > 0, ZIndex = 2, Parent = holder })
	Kit.corner(UDim.new(0.5, 0)).Parent = track
	local fill = Kit.new('Frame', { Name = 'Fill', Size = UDim2.fromScale(0, 1), BackgroundColor3 = Kit.hex('5CE01E'), BorderSizePixel = 0, ZIndex = 3, Parent = track })
	Kit.corner(UDim.new(0.5, 0)).Parent = fill
	-- a click or a tap holds it like the key
	local hit = Kit.new('TextButton', { Name = 'Hit', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = holder })
	local conns = {}
	table.insert(conns, hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pcall(function() prompt:InputHoldBegin() end)
		end
	end))
	table.insert(conns, hit.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pcall(function() prompt:InputHoldEnd() end)
		end
	end))
	-- the words follow the prompt if a script rewrites them (the ARMORY's prices)
	table.insert(conns, prompt:GetPropertyChangedSignal('ActionText'):Connect(function()
		action.Text = prompt.ActionText
		action.TextSize = Kit.fitSize(prompt.ActionText, 21, W - left - 18, 13)
	end))
	table.insert(conns, prompt:GetPropertyChangedSignal('ObjectText'):Connect(function()
		object.Text = prompt.ObjectText
		object.Visible = prompt.ObjectText ~= ''
	end))
	gui.Parent = playerGui
	TextStyle.pop(holder, 0.5, 0.3)
	table.insert(cards, { Prompt = prompt, Gui = gui, Fill = fill, Conns = conns })
end

local okHook, hookErr = pcall(function()
	PPS.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then return end
		local ok, err = pcall(show, prompt, inputType)
		if not ok then warn('[Prompts] ' .. tostring(err)) end
	end)
	PPS.PromptHidden:Connect(function(prompt)
		local i = find(prompt)
		if i then close(i) end
	end)
	PPS.PromptButtonHoldBegan:Connect(function(prompt)
		local i = find(prompt)
		local c = i and cards[i]
		if not c or prompt.HoldDuration <= 0 then return end
		c.Fill.Size = UDim2.fromScale(0, 1)
		TweenService:Create(c.Fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) }):Play()
	end)
	PPS.PromptButtonHoldEnded:Connect(function(prompt)
		local i = find(prompt)
		local c = i and cards[i]
		if not c then return end
		TweenService:Create(c.Fill, TweenInfo.new(0.15), { Size = UDim2.fromScale(0, 1) }):Play()
	end)
end)
if not okHook then warn('[Prompts] ' .. tostring(hookErr)) end
