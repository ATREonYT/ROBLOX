--[[
	Kit  (ModuleScript, child of GameClient)
	UI building blocks in the Stone Skipping style from Alex's recordings
	(Oct 30): see-through dark panels with the title floating on the top edge,
	a big icon on the corner and a red X; studded cards and buttons with thin
	black outlines and square-ish corners; chunky outlined text; and the
	animated backgrounds (moving studs/stripes, spinning rays, rainbow
	outlines, shine sweeps, sparkles).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Icons = require(ReplicatedStorage:WaitForChild("Icons"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local Kit = {}

Kit.Font = Enum.Font.FredokaOne
Kit.Colors = {
	-- measured from Alex's Stone Skipping recordings (Oct 30): neutral greys,
	-- see-through panels, black outlines
	Outline = Color3.fromRGB(10, 10, 14),
	Glass = Color3.fromRGB(26, 24, 32), -- panel body, shown 30% see-through
	Body = Color3.fromRGB(34, 32, 40),
	BodyDark = Color3.fromRGB(20, 19, 25),
	Card = Color3.fromRGB(62, 60, 72),
	CardDark = Color3.fromRGB(38, 36, 46),
	BarEdge = Color3.fromRGB(10, 10, 14),
	BarBack = Color3.fromRGB(215, 218, 226),
	HeaderTop = Color3.fromRGB(255, 240, 0),
	HeaderBottom = Color3.fromRGB(254, 179, 1),
	Green = Color3.fromRGB(150, 250, 25),
	GreenDark = Color3.fromRGB(70, 200, 10),
	Red = Color3.fromRGB(252, 31, 47),
	RedDark = Color3.fromRGB(202, 3, 34),
	Blue = Color3.fromRGB(70, 160, 255),
	BlueDark = Color3.fromRGB(30, 95, 210),
	Purple = Color3.fromRGB(170, 80, 255),
	PurpleDark = Color3.fromRGB(105, 35, 200),
	Yellow = Color3.fromRGB(255, 215, 50),
	YellowDark = Color3.fromRGB(235, 150, 10),
	Gray = Color3.fromRGB(110, 115, 135),
	GrayDark = Color3.fromRGB(70, 75, 95),
	White = Color3.new(1, 1, 1),
}

-- Emoji fallbacks while icon asset ids are empty
local FALLBACK = {
	Shop = "🛒", Rebirth = "🔄", Rewards = "🎁", Backpack = "🎒", World = "🌍", Missions = "📋",
	Quest = "📜", Trophy = "🏆", Evolve = "⬆️", Muscle = "💪", Power = "⚡", PowerMedium = "⚡",
	PowerLarge = "⚡", Cash = "💵", CashTiny = "💵", CashSmall = "💵", CashMedium = "💰", CashLarge = "💰",
	Robux = utf8.char(0xE002), Lucky = "🍀", TripleOpen = "🎲", ExtraEquip = "🎒", AutoCollect = "🧲", VIP = "👑",
	DoublePower = "⚡", DoubleCash = "💵", TenXCash = "💰", PotionRed = "🧪",
	PotionGold = "🧪", BoostBundle = "🧪", SpinWheel = "🎡", PlaytimeGift = "⏰", StarterCrate = "📦",
	Delete = "🗑️", Favorite = "⭐", Search = "🔍", Arrow = "➡️", RebirthSkip = "⏩", Chevrons = "»", RebirthSign = "🔄", Sneaker = "👟",
	Skull = "💀", XP = "⭐", Gem = "💎", Settings = "⚙️", BlockParty = "🧊", Shield = "🛡️", PowerPack1 = "⚡", PowerPack2 = "⚡", PowerPack3 = "⚡",
}

---------------------------------------------------------------------------
-- Basics
---------------------------------------------------------------------------
function Kit.new(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end
local new = Kit.new

function Kit.corner(radius, parent)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 12), Parent = parent })
end

function Kit.stroke(thickness, color, parent)
	return new("UIStroke", {
		Thickness = thickness or 3,
		Color = color or Kit.Colors.Outline,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = parent,
	})
end

function Kit.gradient(top, bottom, parent, rotation)
	return new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
		Parent = parent,
	})
end

function Kit.padding(px, parent)
	return new("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		Parent = parent,
	})
end

function Kit.list(parent, padding, horizontal, align)
	return new("UIListLayout", {
		Padding = UDim.new(0, padding or 6),
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

function Kit.grid(parent, cellSize, padding)
	return new("UIGridLayout", {
		CellSize = cellSize,
		CellPadding = UDim2.fromOffset(padding or 8, padding or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = parent,
	})
end

-- Chunky outlined text, like every label in the mockup
function Kit.text(props)
	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Kit.Font,
		TextColor3 = props.Color or Kit.Colors.White,
		Text = props.Text or "",
		TextSize = props.Size or 24,
		TextScaled = props.Scaled or false,
		TextWrapped = props.Wrapped or false,
		TextXAlignment = props.AlignX or Enum.TextXAlignment.Center,
		TextYAlignment = props.AlignY or Enum.TextYAlignment.Center,
		Size = props.FrameSize or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.Anchor or Vector2.zero,
		ZIndex = props.ZIndex or 1,
		LayoutOrder = props.Order or 0,
		Name = props.Name or "Text",
		RichText = props.Rich or false,
		Parent = props.Parent,
	})
	if props.Stroke ~= false then
		new("UIStroke", {
			Thickness = props.StrokeSize or math.clamp((props.Size or 24) / 9, 1.5, 4),
			Color = props.StrokeColor or Kit.Colors.Outline,
			LineJoinMode = Enum.LineJoinMode.Round,
			Parent = label,
		})
	end
	if props.Scaled and props.MaxSize then
		new("UITextSizeConstraint", { MaxTextSize = props.MaxSize, Parent = label })
	end
	return label
end

-- Icon from the Icons table, falling back to an emoji
function Kit.icon(name, props)
	props = props or {}
	local id = Icons[name]
	local inst
	if id and id ~= "" then
		inst = new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = id,
			ScaleType = Enum.ScaleType.Fit,
		})
	else
		inst = Kit.text({ Text = FALLBACK[name] or "⭐", Scaled = true, Stroke = false })
	end
	inst.Name = props.Name or ("Icon_" .. name)
	inst.Size = props.Size or UDim2.fromOffset(48, 48)
	inst.Position = props.Position or UDim2.new()
	inst.AnchorPoint = props.Anchor or Vector2.zero
	inst.ZIndex = props.ZIndex or 2
	inst.LayoutOrder = props.Order or 0
	inst.Rotation = props.Rotation or 0
	inst.Parent = props.Parent
	return inst
end

function Kit.hasImage(name)
	return Icons[name] ~= nil and Icons[name] ~= ""
end

---------------------------------------------------------------------------
-- Tweens + feedback
---------------------------------------------------------------------------
function Kit.tween(inst, time, props, style, dir)
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

function Kit.scale(inst)
	return inst:FindFirstChildOfClass("UIScale") or new("UIScale", { Parent = inst })
end

function Kit.pop(inst, amount)
	local s = Kit.scale(inst)
	s.Scale = amount or 1.15
	Kit.tween(s, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Sounds live in Sfx (pooled, preloaded, one volume group per kind). Kit.Sounds stays empty on purpose: the
-- Sound Effects setting goes through Sfx.setEnabled, not through per-sound volumes.
Kit.Sounds = {}
function Kit.playSound(name)
	Sfx.play(name)
end
Kit.Sfx = Sfx

-- Press feedback (vault "Squash Stretch and Anticipation"): jump straight to the squashed size, then spring back
-- with an overshoot. Tweening INTO the squash reads soft and late.
function Kit.press(inst, amount)
	local s = Kit.scale(inst)
	s.Scale = amount or 0.9
	Kit.tween(s, 0.28, { Scale = 1 }, Enum.EasingStyle.Back) -- (also replaces any running hover tween)
end

-- Panel entrance (vault "UI Motion Language": hierarchy): the cards in a panel pop in one after another, top-left
-- first, 25 ms apart, at most 12 of them so a big list never makes you wait.
function Kit.cascade(container)
	local items = {}
	for _, d in ipairs(container:GetDescendants()) do
		-- cards in a grid, or rows in a scrolling list; big enough to be a card (design pixels, not screen pixels)
		local parent = d.Parent
		local inLayout = parent and (parent:FindFirstChildOfClass("UIGridLayout") or (parent:IsA("ScrollingFrame") and parent:FindFirstChildOfClass("UIListLayout")))
		local big = d:IsA("GuiObject") and (d.Size.X.Offset >= 60 or d.Size.X.Scale >= 0.2)
		if inLayout and big and d.Visible then
			table.insert(items, d)
		end
	end
	table.sort(items, function(a, b)
		local pa, pb = a.AbsolutePosition, b.AbsolutePosition
		if math.abs(pa.Y - pb.Y) > 8 then
			return pa.Y < pb.Y
		end
		return pa.X < pb.X
	end)
	for i = 1, math.min(#items, 12) do
		local item = items[i]
		local s = Kit.scale(item)
		s.Scale = 0.7
		task.delay(0.04 + (i - 1) * 0.025, function()
			Kit.tween(s, 0.26, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
	end
end

-- A very quiet hover tick on every button in a ScreenGui, including ones made later (one place, the
-- cartoony-ui skill's "one script handles every button"). TextBoxes are skipped.
function Kit.hoverSounds(screenGui)
	-- on a phone a tap is also a "hover": no tick there, the click is enough
	local UserInputService = game:GetService("UserInputService")
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		return
	end
	local function hook(d)
		if d:IsA("GuiButton") then
			d.MouseEnter:Connect(function()
				if d.Active and d.Visible then
					Sfx.play("Hover")
				end
			end)
		end
	end
	for _, d in ipairs(screenGui:GetDescendants()) do
		hook(d)
	end
	screenGui.DescendantAdded:Connect(hook)
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------
local BUTTON_COLORS = {
	Green = { Kit.Colors.Green, Kit.Colors.GreenDark },
	Red = { Kit.Colors.Red, Kit.Colors.RedDark },
	Blue = { Kit.Colors.Blue, Kit.Colors.BlueDark },
	Purple = { Kit.Colors.Purple, Kit.Colors.PurpleDark },
	Yellow = { Kit.Colors.Yellow, Kit.Colors.YellowDark },
	Gray = { Kit.Colors.Gray, Kit.Colors.GrayDark },
	Dark = { Kit.Colors.Card, Kit.Colors.BodyDark },
}

-- props: Text, Color ("Green"...), Size, Position, Anchor, Icon, TextSize, OnClick, Parent, Order
function Kit.button(props)
	local colors = BUTTON_COLORS[props.Color or "Green"] or props.Colors
	local btn = new("TextButton", {
		Name = props.Name or "Button",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = props.Size or UDim2.fromOffset(160, 50),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.Anchor or Vector2.zero,
		LayoutOrder = props.Order or 0,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	Kit.corner(props.Radius or 8, btn)
	Kit.stroke(props.StrokeSize or 3, nil, btn)
	local grad = Kit.gradient(colors[1], colors[2], btn)
	-- flat studded face like the Stone Skipping buttons, with a thin darker
	-- strip along the bottom so it still reads as pressable (cartoony-ui skill)
	Kit.litePattern(btn, { Texture = "StudTile", ImageTransparency = 0.82, TileSize = 30, ZIndex = props.ZIndex or 1 })
	local lip = new("Frame", {
		Name = "Lip",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.72,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 5),
		Position = UDim2.new(0, 0, 1, -5),
		ZIndex = props.ZIndex or 1,
		Parent = btn,
	})
	Kit.corner(props.Radius or 8, lip)

	local content = new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = (props.ZIndex or 1) + 2,
		Parent = btn,
	})
	local textX = 0
	if props.Icon then
		Kit.icon(props.Icon, {
			Size = UDim2.new(0, (props.IconSize or 30), 0, (props.IconSize or 30)),
			Position = UDim2.new(0, 8, 0.5, 0),
			Anchor = Vector2.new(0, 0.5),
			ZIndex = (props.ZIndex or 1) + 3,
			Parent = content,
		})
		textX = (props.IconSize or 30) + 8
	end
	local label = Kit.text({
		Name = "Label",
		Text = props.Text or "",
		Size = props.TextSize or 24,
		Scaled = props.Scaled ~= false,
		MaxSize = props.TextSize or 26,
		FrameSize = UDim2.new(1, -textX - 10, 0.8, 0),
		Position = UDim2.new(0, textX + 5, 0.1, 0),
		ZIndex = (props.ZIndex or 1) + 3,
		Parent = content,
	})

	local s = Kit.scale(btn)
	-- hover: 0.3 s Back out, leave: 0.3 s Sine out (cartoony-ui skill)
	btn.MouseEnter:Connect(function()
		Kit.tween(s, 0.3, { Scale = 1.05 }, Enum.EasingStyle.Back)
	end)
	btn.MouseLeave:Connect(function()
		Kit.tween(s, 0.3, { Scale = 1 }, Enum.EasingStyle.Sine)
	end)
	-- press: straight to 0.9, then spring back past 1 (Back) and settle; the label sinks 2 px onto the lip
	btn.MouseButton1Down:Connect(function()
		Kit.tween(s, 0.03, { Scale = 0.9 }) -- (a tween, so it also stops a running hover tween)
		content.Position = UDim2.fromOffset(0, 2)
	end)
	btn.MouseButton1Up:Connect(function()
		Kit.tween(s, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
		Kit.tween(content, 0.12, { Position = UDim2.new() })
	end)
	btn.MouseLeave:Connect(function()
		content.Position = UDim2.new()
	end)
	if props.OnClick then
		btn.Activated:Connect(function()
			Kit.playSound(props.Sound or "Click")
			props.OnClick(btn)
		end)
	end

	local api = { Instance = btn, Label = label, Gradient = grad }
	function api.SetText(_, t)
		label.Text = t
	end
	function api.SetColor(_, name)
		local c = BUTTON_COLORS[name]
		grad.Color = ColorSequence.new(c[1], c[2])
	end
	return api
end

-- Square menu button with a big icon and a label underneath (top bar style)
function Kit.menuButton(props)
	local btn = new("ImageButton", {
		Name = props.Name or props.Text,
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromOffset(74, 74),
		LayoutOrder = props.Order or 0,
		Parent = props.Parent,
	})
	local icon = Kit.icon(props.Icon, {
		Size = UDim2.fromScale(0.9, 0.9),
		Position = UDim2.fromScale(0.5, 0.42),
		Anchor = Vector2.new(0.5, 0.5),
		Parent = btn,
	})
	Kit.text({
		Text = props.Text,
		Size = 20,
		Scaled = true,
		MaxSize = 20,
		FrameSize = UDim2.new(1.1, 0, 0.3, 0),
		Position = UDim2.fromScale(0.5, 1),
		Anchor = Vector2.new(0.5, 1),
		ZIndex = 3,
		Parent = btn,
	})
	local s = Kit.scale(btn)
	btn.MouseEnter:Connect(function()
		Kit.tween(s, 0.15, { Scale = 1.1 }, Enum.EasingStyle.Back)
		Kit.tween(icon, 0.15, { Rotation = -8 })
	end)
	btn.MouseLeave:Connect(function()
		Kit.tween(s, 0.15, { Scale = 1 })
		Kit.tween(icon, 0.15, { Rotation = 0 })
	end)
	btn.Activated:Connect(function()
		Kit.playSound("Click")
		Kit.press(btn, 0.85)
		if props.OnClick then
			props.OnClick()
		end
	end)
	return btn
end

-- Red notification badge ("!", "3", "97%")
function Kit.badge(parent, color)
	local b = new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = color or Kit.Colors.Red,
		Visible = false,
		ZIndex = 10,
		Parent = parent,
	})
	Kit.corner(14, b)
	Kit.stroke(2.5, nil, b)
	new("UISizeConstraint", { MinSize = Vector2.new(28, 28) }, {}).Parent = b
	local label = Kit.text({ Text = "!", Size = 18, Scaled = true, MaxSize = 18, ZIndex = 11, Parent = b })
	local api = {}
	function api.Set(_, text)
		local show = text ~= nil and text ~= ""
		-- a badge that appears (or changes) pops, so a new "!" is noticed
		if show and (not b.Visible or label.Text ~= tostring(text)) then
			Kit.pop(b, 1.4)
		end
		b.Visible = show
		label.Text = text or ""
		b.Size = UDim2.fromOffset(math.max(28, #tostring(text or "") * 11 + 10), 28)
	end
	return api
end

---------------------------------------------------------------------------
-- Animated backgrounds
---------------------------------------------------------------------------
local animated = {} -- [inst] = updater(dt, t)
RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	for inst, fn in pairs(animated) do
		if inst.Parent == nil then
			animated[inst] = nil
		elseif inst:IsDescendantOf(game) then
			local visible = true
			local p = inst
			-- gradients / strokes: check the frame they belong to
			while p and not p:IsA("GuiObject") and not p:IsA("LayerCollector") do
				p = p.Parent
			end
			-- skip invisible panels to save work
			while p and p:IsA("GuiObject") do
				if not p.Visible then
					visible = false
					break
				end
				p = p.Parent
			end
			if visible then
				fn(dt, t)
			end
		end
	end
end)

function Kit.animate(inst, fn)
	animated[inst] = fn
end

-- Scrolling tiled pattern (studs or stripes). Falls back to moving
-- gradient stripes when the texture isn't uploaded yet.
function Kit.movingPattern(parent, props)
	props = props or {}
	if props.Lite then
		return Kit.litePattern(parent, props)
	end
	local group = new("CanvasGroup", {
		Name = "MovingPattern",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = props.ZIndex or 1,
		GroupTransparency = props.Transparency or 0,
		Parent = parent,
	})
	Kit.corner(props.Radius or 12, group)
	local texture = props.Texture or "StudTile"
	local speed = props.Speed or 20 -- pixels/second
	local tile = props.TileSize or 32
	if Kit.hasImage(texture) then
		local img = new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = Icons[texture],
			ImageColor3 = props.Color or Color3.new(1, 1, 1),
			ImageTransparency = props.ImageTransparency or 0.3,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(tile, tile),
			Size = UDim2.new(1, tile * 2, 1, tile * 2),
			Position = UDim2.fromOffset(-tile, -tile),
			ZIndex = props.ZIndex or 1,
			Parent = group,
		})
		local offset = 0
		Kit.animate(img, function(dt)
			offset = (offset + dt * speed) % tile
			img.Position = UDim2.fromOffset(-tile + offset, -tile + offset)
		end)
	else
		-- gradient stripes on a double-width strip that slides and wraps
		local strip = new("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0,
			Size = UDim2.fromScale(2, 1),
			ZIndex = props.ZIndex or 1,
			Parent = group,
		})
		local keys = {}
		local cycles = 4 -- NumberSequence allows 20 keypoints max
		for i = 0, cycles - 1 do
			local a = i / cycles
			local w = 1 / cycles
			table.insert(keys, NumberSequenceKeypoint.new(a, 1))
			table.insert(keys, NumberSequenceKeypoint.new(a + w * 0.5 - 0.0001, 1))
			table.insert(keys, NumberSequenceKeypoint.new(a + w * 0.5, 0.88))
			table.insert(keys, NumberSequenceKeypoint.new(math.min(a + w - 0.0002, 0.9999), 0.88))
		end
		table.insert(keys, NumberSequenceKeypoint.new(1, 1))
		new("UIGradient", { Transparency = NumberSequence.new(keys), Rotation = 25, Parent = strip })
		local x = 0
		Kit.animate(strip, function(dt)
			x = (x + dt * 0.04 * (speed / 20)) % 0.4
			strip.Position = UDim2.fromScale(-x, 0)
		end)
	end
	return group
end

-- Still pattern on a rounded overlay (stripes, or the uploaded texture). Cheap and crisp, so
-- it's what shop tiles use (a screen of tiles would need dozens of
-- CanvasGroups otherwise, and Roblox lowers their resolution).
function Kit.litePattern(parent, props)
	props = props or {}
	local r = parent:FindFirstChildOfClass("UICorner")
	local texture = props.Texture or "StudTile"
	if Kit.hasImage(texture) then
		-- the uploaded pattern, tiled and clipped by its own rounded corners
		local img = new("ImageLabel", {
			Name = "MovingPattern",
			BackgroundTransparency = 1,
			Image = Icons[texture],
			ImageColor3 = props.Color or Color3.new(1, 1, 1),
			ImageTransparency = props.ImageTransparency or 0.3,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(props.TileSize or 32, props.TileSize or 32),
			Size = UDim2.fromScale(1, 1),
			ZIndex = props.ZIndex or 1,
			Parent = parent,
		})
		new("UICorner", { CornerRadius = r and r.CornerRadius or UDim.new(0, props.Radius or 12), Parent = img })
		return img
	end
	local overlay = new("Frame", {
		Name = "MovingPattern",
		BackgroundColor3 = props.Color or Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = props.ZIndex or 1,
		Parent = parent,
	})
	new("UICorner", { CornerRadius = r and r.CornerRadius or UDim.new(0, props.Radius or 12), Parent = overlay })
	local cycles = 4 -- NumberSequence allows 20 keypoints max
	local on = 1 - (1 - (props.ImageTransparency or 0.55)) * 0.3
	local keys = {}
	for i = 0, cycles - 1 do
		local a = i / cycles
		local w = 1 / cycles
		table.insert(keys, NumberSequenceKeypoint.new(a, 1))
		table.insert(keys, NumberSequenceKeypoint.new(a + w * 0.5 - 0.0001, 1))
		table.insert(keys, NumberSequenceKeypoint.new(a + w * 0.5, on))
		table.insert(keys, NumberSequenceKeypoint.new(math.min(a + w - 0.0002, 0.9999), on))
	end
	table.insert(keys, NumberSequenceKeypoint.new(1, 1))
	-- stays still: a sliding gradient would leave a gap at one edge, and the
	-- tile already moves with its shine sweep, sparkles and bobbing icon
	new("UIGradient", { Transparency = NumberSequence.new(keys), Rotation = 25, Parent = overlay })
	return overlay
end

-- Spinning sunburst behind a featured item
function Kit.rays(parent, props)
	props = props or {}
	local size = props.Size or UDim2.fromScale(1.6, 1.6)
	local inst
	if Kit.hasImage("Rays") then
		inst = new("ImageLabel", {
			Name = "Rays",
			BackgroundTransparency = 1,
			Image = Icons.Rays,
			ImageColor3 = props.Color or Color3.new(1, 1, 1),
			ImageTransparency = props.Transparency or 0.55,
			Size = size,
			Position = props.Position or UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = props.ZIndex or 1,
			Parent = parent,
		})
		new("UIAspectRatioConstraint", { Parent = inst })
	else
		inst = new("Frame", {
			Name = "Rays",
			BackgroundTransparency = 1,
			Size = size,
			Position = props.Position or UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = props.ZIndex or 1,
			Parent = parent,
		})
		new("UIAspectRatioConstraint", { Parent = inst })
		for i = 0, 7 do
			local ray = new("Frame", {
				BackgroundColor3 = props.Color or Color3.new(1, 1, 1),
				BackgroundTransparency = 0.82,
				BorderSizePixel = 0,
				Size = UDim2.new(0.1, 0, 1, 0),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = i * 22.5,
				ZIndex = props.ZIndex or 1,
				Parent = inst,
			})
			new("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Rotation = 90,
				Parent = ray,
			})
		end
	end
	local speed = props.Speed or 25
	Kit.animate(inst, function(dt)
		inst.Rotation = (inst.Rotation + dt * speed) % 360
	end)
	return inst
end

-- Rainbow outline that spins around a frame
function Kit.rainbowStroke(parent, thickness)
	local s = Kit.stroke(thickness or 4, Color3.new(1, 1, 1), parent)
	local g = new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
			ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 40)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(80, 255, 90)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(60, 200, 255)),
			ColorSequenceKeypoint.new(0.8, Color3.fromRGB(170, 80, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 60)),
		}),
		Parent = s,
	})
	Kit.animate(g, function(dt)
		g.Rotation = (g.Rotation + dt * 120) % 360
	end)
	return s
end

-- Rainbow fill that slides (for "Skip Rebirth"/x10 buttons)
function Kit.rainbowFill(gradient)
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 210, 50)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 230, 100)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(70, 170, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 80, 255)),
	})
	gradient.Rotation = 0
	Kit.animate(gradient, function(_, t)
		gradient.Offset = Vector2.new(math.sin(t * 1.5) * 0.3, 0)
	end)
end

-- White shine bar that sweeps across every few seconds. It's a rounded
-- overlay whose gradient band slides (no CanvasGroup: those go blurry when
-- there are many on screen).
function Kit.shine(parent, every, radius)
	local overlay = new("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Parent = parent,
	})
	local r = parent:FindFirstChildOfClass("UICorner")
	new("UICorner", { CornerRadius = r and r.CornerRadius or UDim.new(0, radius or 10), Parent = overlay })
	local grad = new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(0.5, 0.45),
			NumberSequenceKeypoint.new(0.58, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = 20,
		Offset = Vector2.new(-1, 0),
		Parent = overlay,
	})
	local period = every or 3
	local start = math.random() * period
	Kit.animate(grad, function(_, t)
		local a = math.min(((t + start) % period) / 0.7, 1)
		grad.Offset = Vector2.new(-0.6 + a * 1.2, 0)
	end)
	return overlay
end

-- Twinkling sparkles at random spots
function Kit.sparkles(parent, count, color)
	for _ = 1, count or 6 do
		local star
		local size = math.random(10, 22)
		if Kit.hasImage("Sparkle") then
			star = new("ImageLabel", { BackgroundTransparency = 1, Image = Icons.Sparkle, ImageColor3 = color or Color3.new(1, 1, 1) })
		else
			star = Kit.text({ Text = "✦", Scaled = true, Stroke = false, Color = color or Color3.new(1, 1, 1) })
		end
		star.Size = UDim2.fromOffset(size, size)
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Position = UDim2.fromScale(math.random(), math.random())
		star.ZIndex = 40
		star.Parent = parent
		local phase = math.random() * 6
		local speed = 1.5 + math.random() * 2
		Kit.animate(star, function(_, t)
			local a = (math.sin(t * speed + phase) + 1) / 2
			if star:IsA("ImageLabel") then
				star.ImageTransparency = 1 - a
			else
				star.TextTransparency = 1 - a
			end
			star.Rotation = t * 40 + phase * 30
			if a < 0.02 then
				star.Position = UDim2.fromScale(math.random(), math.random())
			end
		end)
	end
end

-- Gentle up/down bob (for featured items and eggs)
function Kit.bob(inst, amount, speed)
	local base = inst.Position
	local phase = math.random() * 6
	Kit.animate(inst, function(_, t)
		inst.Position = base + UDim2.fromOffset(0, math.sin(t * (speed or 2) + phase) * (amount or 6))
	end)
end

-- A quick side-to-side wiggle every few seconds (buy buttons, so they catch
-- the eye without flashing)
function Kit.jiggle(inst, every, degrees)
	local period = every or 3
	local start = math.random() * period
	local amount = degrees or 4
	Kit.animate(inst, function(_, t)
		local a = (t + start) % period
		inst.Rotation = a < 0.45 and math.sin(a / 0.45 * math.pi * 3) * amount * (1 - a / 0.45) or 0
	end)
end

-- Grow a little and wiggle the icon while the mouse is over a card
function Kit.hoverLift(card, icon)
	local s = Kit.scale(card)
	card.MouseEnter:Connect(function()
		Kit.tween(s, 0.15, { Scale = 1.06 }, Enum.EasingStyle.Back)
		if icon then
			Kit.tween(icon, 0.08, { Rotation = -10 })
			task.delay(0.08, function()
				Kit.tween(icon, 0.25, { Rotation = 0 }, Enum.EasingStyle.Elastic)
			end)
		end
	end)
	card.MouseLeave:Connect(function()
		Kit.tween(s, 0.15, { Scale = 1 })
	end)
end

-- Big confetti burst from the middle of a frame
function Kit.confetti(parent, count)
	local colors = { Kit.Colors.Yellow, Kit.Colors.Green, Kit.Colors.Blue, Kit.Colors.Purple, Kit.Colors.Red, Color3.new(1, 1, 1) }
	for _ = 1, count or 40 do
		local bit = new("Frame", {
			BackgroundColor3 = colors[math.random(#colors)],
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromOffset(math.random(8, 14), math.random(14, 22)),
			Rotation = math.random(0, 360),
			ZIndex = 90,
			Parent = parent,
		})
		Kit.corner(3, bit)
		local angle = math.random() * math.pi * 2
		local dist = math.random(180, 420)
		local target = UDim2.new(0.5, math.cos(angle) * dist, 0.45, math.sin(angle) * dist * 0.7 + 120)
		local time = 0.9 + math.random() * 0.6
		Kit.tween(bit, time, { Position = target, Rotation = bit.Rotation + math.random(-360, 360) }, Enum.EasingStyle.Quart)
		task.delay(time * 0.6, function()
			Kit.tween(bit, time * 0.4, { BackgroundTransparency = 1 })
		end)
		task.delay(time + 0.1, function()
			bit:Destroy()
		end)
	end
end

---------------------------------------------------------------------------
-- Viewports (3D models in the UI)
---------------------------------------------------------------------------
function Kit.viewport(parent, model, props)
	props = props or {}
	local vp = new("ViewportFrame", {
		Name = "Viewport",
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = props.ZIndex or 3,
		Ambient = Color3.fromRGB(200, 200, 200),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1),
		Parent = parent,
	})
	if not model then
		return vp
	end
	local clone = model:Clone()
	if clone:IsA("BasePart") then
		local m = Instance.new("Model")
		clone.Parent = m
		clone = m
	end
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	clone:PivotTo(CFrame.new())
	clone.Parent = vp
	local cam = new("Camera", { FieldOfView = 40, Parent = vp })
	vp.CurrentCamera = cam
	local cf, size = clone:GetBoundingBox()
	local radius = size.Magnitude / 2
	local dist = radius / math.tan(math.rad(cam.FieldOfView / 2)) * (props.Zoom or 1.05)
	local center = cf.Position
	local yaw = props.Yaw or 35
	local function place(angle)
		local dir = CFrame.Angles(0, math.rad(angle), 0) * CFrame.Angles(math.rad(-15), 0, 0)
		cam.CFrame = CFrame.new(center + dir:VectorToWorldSpace(Vector3.new(0, 0, dist)), center)
	end
	place(yaw)
	if props.Spin then
		Kit.animate(vp, function(_, t)
			place(yaw + t * props.Spin)
		end)
	end
	return vp
end

---------------------------------------------------------------------------
-- Panels
---------------------------------------------------------------------------
-- Builds a mockup-style window. Returns { Frame, Body, SetTitle }.
function Kit.panel(props)
	local frame = new("Frame", {
		Name = props.Name or props.Title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.54),
		Size = props.Size or UDim2.fromOffset(640, 440),
		BackgroundColor3 = Kit.Colors.Glass,
		BackgroundTransparency = 0.3,
		Visible = false,
		ZIndex = 20,
		Parent = props.Parent,
	})
	Kit.corner(10, frame)
	Kit.stroke(3.5, nil, frame)

	-- no header bar: the title floats on the top edge, the icon sits on the
	-- top-left corner and the X on the top-right corner
	local header = new("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, -40),
		Size = UDim2.new(1, 0, 0, 72),
		ZIndex = 24,
		Parent = frame,
	})
	if props.Icon then
		local icon = Kit.icon(props.Icon, {
			Size = UDim2.fromOffset(112, 112),
			Position = UDim2.new(0, -40, 0.5, 4),
			Anchor = Vector2.new(0, 0.5),
			Rotation = -12,
			ZIndex = 26,
			Parent = header,
		})
		Kit.bob(icon, 3, 2)
	end
	local title = Kit.text({
		Name = "Title",
		Text = props.Title,
		Size = 60,
		StrokeSize = 5,
		FrameSize = UDim2.new(1, -240, 1, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Anchor = Vector2.new(0.5, 0),
		ZIndex = 25,
		Parent = header,
	})

	local close = new("TextButton", {
		Name = "Close",
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 44),
		Size = UDim2.fromOffset(58, 58),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 26,
		Parent = header,
	})
	Kit.corner(14, close)
	Kit.stroke(3.5, nil, close)
	Kit.gradient(Kit.Colors.Red, Kit.Colors.RedDark, close)
	Kit.text({ Text = "X", Size = 38, StrokeSize = 3.5, ZIndex = 27, Parent = close })
	local cs = Kit.scale(close)
	close.MouseEnter:Connect(function()
		Kit.tween(cs, 0.12, { Scale = 1.1 })
		Kit.tween(close, 0.12, { Rotation = 8 })
	end)
	close.MouseLeave:Connect(function()
		Kit.tween(cs, 0.12, { Scale = 1 })
		Kit.tween(close, 0.12, { Rotation = 0 })
	end)

	local body = new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 40),
		Size = UDim2.new(1, -24, 1, -52),
		ZIndex = 22,
		Parent = frame,
	})

	return {
		Frame = frame,
		Body = body,
		Close = close,
		Header = header,
		SetTitle = function(_, t)
			title.Text = t
		end,
	}
end

-- Content area inside a panel. Clear by default (the see-through panel shows
-- through, like Stone Skipping); Tile = true gives a grey studded card.
function Kit.inset(props)
	local outer = new("Frame", {
		Name = props.Name or "Inset",
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.Anchor or Vector2.zero,
		ZIndex = props.ZIndex or 22,
		Parent = props.Parent,
	})
	if not props.Tile then
		return outer, outer
	end
	local inner = Kit.card({ Name = "Fill", Color = Kit.Colors.Card, Color2 = Kit.Colors.CardDark, Size = UDim2.fromScale(1, 1), ZIndex = (props.ZIndex or 22) + 1, Parent = outer })
	Kit.litePattern(inner, { Texture = "StudTile", ImageTransparency = 0.88, TileSize = 30, ZIndex = (props.ZIndex or 22) + 1 })
	return outer, inner
end

-- Pill tabs. Returns { Frame, Select(name), Current }
function Kit.tabs(props)
	local bar = new("Frame", {
		Name = "Tabs",
		BackgroundColor3 = Kit.Colors.BodyDark,
		Size = props.Size or UDim2.new(1, 0, 0, 40),
		Position = props.Position or UDim2.new(),
		ZIndex = 23,
		Parent = props.Parent,
	})
	Kit.corner(10, bar)
	Kit.padding(4, bar)
	local layout = Kit.list(bar, 6, true)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	local api = { Frame = bar, Buttons = {}, Current = nil }
	local n = #props.Names
	for i, name in ipairs(props.Names) do
		local tab = new("TextButton", {
			Name = name,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Color3.new(1, 1, 1),
			Size = UDim2.new(1 / n, -6, 1, 0),
			LayoutOrder = i,
			ZIndex = 24,
			Parent = bar,
		})
		Kit.corner(8, tab)
		Kit.stroke(2.5, nil, tab)
		local grad = Kit.gradient(Kit.Colors.Card, Kit.Colors.BodyDark, tab)
		Kit.text({ Text = name, Size = 20, Scaled = true, MaxSize = 20, FrameSize = UDim2.new(1, -8, 0.75, 0), Position = UDim2.fromScale(0.5, 0.5), Anchor = Vector2.new(0.5, 0.5), ZIndex = 25, Parent = tab })
		api.Buttons[name] = { Button = tab, Gradient = grad }
		tab.Activated:Connect(function()
			if api.Current ~= name then
				Kit.playSound("Tab")
			end
			api:Select(name)
		end)
	end
	function api.Select(_, name)
		api.Current = name
		for n2, b in pairs(api.Buttons) do
			if n2 == name then
				b.Gradient.Color = ColorSequence.new(Kit.Colors.HeaderTop, Kit.Colors.HeaderBottom)
				Kit.pop(b.Button, 1.08)
			else
				b.Gradient.Color = ColorSequence.new(Kit.Colors.Card, Kit.Colors.BodyDark)
			end
		end
		if props.OnSelect then
			props.OnSelect(name)
		end
	end
	return api
end

-- Rounded card with gradient + outline
function Kit.card(props)
	local card = new(props.Button and "TextButton" or "Frame", {
		Name = props.Name or "Card",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = props.Size or UDim2.fromOffset(100, 100),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.Anchor or Vector2.zero,
		LayoutOrder = props.Order or 0,
		ZIndex = props.ZIndex or 23,
		Parent = props.Parent,
	})
	if props.Button then
		card.Text = ""
		card.AutoButtonColor = false
	end
	local radius = props.Radius or 8
	Kit.corner(radius, card)
	Kit.stroke(props.StrokeSize or 3.5, nil, card)
	local top = props.Color or Kit.Colors.Card
	local bottom = props.Color2 or top:Lerp(Color3.new(0, 0, 0), 0.25)
	local grad = Kit.gradient(top, bottom, card)
	-- lighter inner edge just inside the black outline (Stone Skipping cards)
	local rim = new("Frame", {
		Name = "Rim",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
		ZIndex = props.ZIndex or 23,
		Parent = card,
	})
	Kit.corner(math.max(radius - 3, 2), rim)
	new("UIStroke", { Thickness = 3, Color = Color3.new(1, 1, 1), Transparency = 0.55, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = rim })
	return card, grad
end

-- Horizontal progress bar. Returns { Frame, Set(alpha, text) }
function Kit.progress(props)
	local bar = new("Frame", {
		Name = "Progress",
		BackgroundColor3 = Kit.Colors.BarBack,
		Size = props.Size or UDim2.new(1, 0, 0, 22),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.Anchor or Vector2.zero,
		LayoutOrder = props.Order or 0,
		ZIndex = props.ZIndex or 24,
		Parent = props.Parent,
	})
	Kit.corner(6, bar)
	new("UIStroke", { Thickness = 3, Color = Kit.Colors.BarEdge, Parent = bar })
	local fill = new("Frame", {
		Name = "Fill",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(0, 1),
		ZIndex = (props.ZIndex or 24) + 1,
		Parent = bar,
	})
	Kit.corner(6, fill)
	Kit.gradient(props.Color or Kit.Colors.Green, props.Color2 or Kit.Colors.GreenDark, fill)
	Kit.litePattern(fill, { Texture = "StudTile", ImageTransparency = 0.8, TileSize = 30, ZIndex = (props.ZIndex or 24) + 1 })
	local label = Kit.text({ Text = "", Size = 22, Scaled = true, MaxSize = 22, FrameSize = UDim2.new(1, -8, 0.8, 0), Position = UDim2.fromScale(0.5, 0.5), Anchor = Vector2.new(0.5, 0.5), ZIndex = (props.ZIndex or 24) + 2, Parent = bar })
	return {
		Frame = bar,
		Set = function(_, alpha, text)
			alpha = math.clamp(alpha, 0, 1)
			Kit.tween(fill, 0.25, { Size = UDim2.fromScale(alpha, 1) })
			fill.Visible = alpha > 0.01
			label.Text = text or ""
		end,
	}
end

function Kit.scrolling(props)
	local sf = new("ScrollingFrame", {
		Name = props.Name or "Scroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Kit.Colors.Yellow,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = props.ZIndex or 23,
		Parent = props.Parent,
	})
	Kit.padding(6, sf)
	return sf
end

function Kit.clear(container)
	for _, c in ipairs(container:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

-- "Robux price" label content, e.g.  [R] 349
function Kit.priceText(currency, amount, format)
	local symbol = ({ Robux = "", Cash = "💵 ", Gems = "💎 ", Free = "" })[currency] or ""
	if currency == "Free" then
		return "FREE"
	end
	return symbol .. (format and format(amount) or tostring(amount))
end

return Kit
