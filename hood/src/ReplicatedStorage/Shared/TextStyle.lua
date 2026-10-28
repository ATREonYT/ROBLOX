-- TextStyle (brief 31, rule 27: the user's "make the text font way better"): the reference's chunky cartoon text as
-- presets, for headlines, prices and buttons on screen. Copied from the reference frames (ref_W01.0_spawn_view_north:
-- "x2 Wins" white, "ONLY ⬡79" lime, "Playtime Rewards" gold; ref_V3-00.5_store_exclusive / ref_V3-03.5_store_passes:
-- white titles, cyan and yellow sub-lines, white prices on the green button):
--   Montserrat Black (Fonts.Title = Roblox's GothamBlack), a THICK near-black UIStroke (about 14% of the text size,
--   never under 2.5 px; Round joins), a vertical UIGradient fill (light at the top, deeper at the foot) and, on
--   headlines, a soft drop shadow (a dark copy 1-2 px under it, like the reference's heavy foot).
--
--   TextStyle.Presets[name] = { Top, Bottom (the fill, top -> bottom), Stroke (the outline colour) }
--   TextStyle.apply(label, name, opts) restyles a TextLabel / TextButton in place and returns it.
--     opts.Thickness  the outline (default max(2.5, TextSize * 0.14); a TextScaled label uses its frame height)
--     opts.Shadow     true: add the drop shadow (a sibling copy that follows the label's Text and Visible)
--     opts.Font       false: keep the label's font (a body line); default Montserrat Black
--   TextStyle.seq(name) the preset's fill as a ColorSequence (for UIGradients the caller already owns).
-- The user's own artboards stay the authority for their screens (ShoeScreens / ArtKit): those keep their own text.
local Fonts = require(script.Parent.Fonts)

local TextStyle = {}

local function hex(s) return Color3.fromHex(s) end

local INK = hex('0B0B14') -- the reference's near-black outline
TextStyle.Ink = INK
TextStyle.Presets = {
	white = { Top = hex('FFFFFF'), Bottom = hex('D9DEE8'), Stroke = INK }, -- titles, "x2 Wins", window heads
	gold = { Top = hex('FFF27A'), Bottom = hex('FFA81A'), Stroke = INK }, -- "Playtime Rewards", multipliers, BEST VALUE
	cyan = { Top = hex('B8F6FF'), Bottom = hex('2FB4FF'), Stroke = INK }, -- sub-lines on warm cards, "Recommended"
	price = { Top = hex('E8FF4A'), Bottom = hex('4EE020'), Stroke = INK }, -- "ONLY ⬡79", Robux prices in lime
	button = { Top = hex('FFFFFF'), Bottom = hex('E6F4D8'), Stroke = hex('0E3A00') }, -- the price on the green button
	red = { Top = hex('FF9A8A'), Bottom = hex('FF3A3A'), Stroke = INK }, -- Locked, struck-through prices
	green = { Top = hex('C8FF6A'), Bottom = hex('3CD02A'), Stroke = INK }, -- Unlocked, OWNED
}

function TextStyle.seq(name)
	local p = TextStyle.Presets[name] or TextStyle.Presets.white
	return ColorSequence.new(p.Top, p.Bottom)
end

local function sizeOf(label)
	if label.TextScaled then
		local h = label.AbsoluteSize.Y
		if h <= 0 then h = label.Size.Y.Offset end
		return math.max(14, h * 0.8)
	end
	return label.TextSize
end

function TextStyle.apply(label, name, opts)
	if typeof(label) ~= 'Instance' or not label:IsA('GuiObject') then return label end
	opts = opts or {}
	local p = TextStyle.Presets[name] or TextStyle.Presets.white
	if opts.Font ~= false then label.FontFace = Fonts.Title end
	label.TextColor3 = Color3.new(1, 1, 1) -- (the gradient carries the colour)
	label.TextStrokeTransparency = 1
	local thickness = opts.Thickness or math.max(2.5, sizeOf(label) * 0.14)
	local stroke = label:FindFirstChildOfClass('UIStroke')
	if not stroke then
		stroke = Instance.new('UIStroke')
		stroke.Parent = label
	end
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color, stroke.Thickness, stroke.Transparency = p.Stroke, thickness, 0
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	local grad = label:FindFirstChild('TextFill')
	for _, g in label:GetChildren() do
		if g:IsA('UIGradient') and g ~= grad then g:Destroy() end
	end
	if not grad then
		grad = Instance.new('UIGradient')
		grad.Name = 'TextFill'
		grad.Parent = label
	end
	grad.Rotation = 90
	grad.Color = ColorSequence.new(p.Top, p.Bottom)
	if opts.Shadow and label.Parent and not label:GetAttribute('Shadowed') then
		label:SetAttribute('Shadowed', true)
		local drop = math.max(1, math.floor(thickness * 0.5 + 0.5))
		local sh = label:Clone()
		sh.Name = label.Name .. 'Shadow'
		for _, c in sh:GetChildren() do
			if not c:IsA('UIStroke') then c:Destroy() end
		end
		sh.TextColor3 = INK
		sh.TextTransparency = 0.25
		local s2 = sh:FindFirstChildOfClass('UIStroke')
		if s2 then s2.Color, s2.Transparency = INK, 0.25 end
		sh.Position = label.Position + UDim2.fromOffset(0, drop)
		sh.ZIndex = math.max(1, label.ZIndex - 1)
		sh.Parent = label.Parent
		label:GetPropertyChangedSignal('Text'):Connect(function() sh.Text = label.Text end)
		label:GetPropertyChangedSignal('Visible'):Connect(function() sh.Visible = label.Visible end)
		label:GetPropertyChangedSignal('TextSize'):Connect(function() sh.TextSize = label.TextSize end)
		label:GetPropertyChangedSignal('Position'):Connect(function() sh.Position = label.Position + UDim2.fromOffset(0, drop) end)
		label.AncestryChanged:Connect(function() if not label.Parent then sh:Destroy() end end)
	end
	return label
end

-- (Oct 28, the owner after playing in Studio: "make the text shown to the user on the screen match the UI more ... more
-- cartoony") The same look for words whose colour a script owns and changes (a lane's price, Locked / Unlocked, a
-- "+N" pop in its lane's colour, the world's signs): their fill keeps its TextColor3 but is lit from the top and
-- deeper at its foot (a UIGradient that multiplies it: white -> Foot), their outline joins round, and on screen the
-- outline is TextStyle's thick one (TextStyle.outlineFor the words' height in px). Shadow twins (attribute ShadowOf)
-- stay flat ink. Returns the label.
TextStyle.Foot = Color3.fromRGB(196, 196, 204) -- (the fill's foot: about 77 % of its colour)
function TextStyle.world(label)
	if typeof(label) ~= 'Instance' or not (label:IsA('TextLabel') or label:IsA('TextButton')) then return label end
	if label:GetAttribute('ShadowOf') or label.Name:sub(-6) == 'Shadow' then return label end
	if not label:FindFirstChildOfClass('UIGradient') then
		local g = Instance.new('UIGradient')
		g.Name = 'TextFill'
		g.Rotation = 90
		g.Color = ColorSequence.new(Color3.new(1, 1, 1), TextStyle.Foot)
		g.Parent = label
	end
	local s = label:FindFirstChildOfClass('UIStroke')
	if s then s.LineJoinMode = Enum.LineJoinMode.Round end
	label:SetAttribute('Cartoon', true)
	return label
end
-- The outline for words `h` px tall on screen: about 13 % of their height, never under 2 px nor over 7 px.
function TextStyle.outlineFor(h)
	if type(h) ~= 'number' or h ~= h then return 2 end
	return math.clamp(h * 0.13, 2, 7)
end
-- A bouncy pop-in for a GuiObject (its own UIScale 'Pop' from `from` to a little over 1 and back, Back out, over
-- `seconds`); ReducedMotion players get none. Returns the tween or nil.
function TextStyle.pop(gui, from, seconds)
	if typeof(gui) ~= 'Instance' or not gui:IsA('GuiObject') then return nil end
	local ok, tw = pcall(function()
		local Players = game:GetService('Players')
		local me = Players.LocalPlayer
		local sc = gui:FindFirstChild('Pop')
		if not (sc and sc:IsA('UIScale')) then
			sc = Instance.new('UIScale')
			sc.Name = 'Pop'
			sc.Parent = gui
		end
		if me and me:GetAttribute('ReducedMotion') == true then sc.Scale = 1 return nil end
		sc.Scale = from or 0.5
		local t = game:GetService('TweenService'):Create(sc, TweenInfo.new(seconds or 0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		t:Play()
		return t
	end)
	return ok and tw or nil
end

return TextStyle
