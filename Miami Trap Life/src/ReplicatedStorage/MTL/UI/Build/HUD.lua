--!strict
-- Builds the MTL_HUD ScreenGui. Used two ways:
--   1. Edit time (Studio command bar / MCP): require(...).build().Parent = game.StarterGui  -> real instances Alex can reskin
--   2. Runtime fallback: HUDController builds it only if PlayerGui has no MTL_HUD (StarterGui copy missing).
-- Layout from Alex's reference shots (icon menu grid, cash bar with a money icon, status rings, round hotbar),
-- in plain everyday colours (Theme.HUD): dark grey panels, white text, green only for money, gold for level.
-- Controllers find things BY NAME. Keep these names when reskinning:
--   Top/Cash/{IconHolder/Icon, Amount}, Top/Status/{XP/{Title, Text}, Boosts, Level/{Center/Num}, Health/{Center/Glyph}}
--   Objective/{Dot, Text}, Toasts, Banner/{Ribbon, Title, Sub}, Pops
--   Menu/Toggle, Menu/Panel/{Collapse, Grid/TileTemplate/{Icon, Label}}, Panels/Dim + the Store / Emotes popups
--   Hotbar/SlotTemplate/{Disc/{Icon, Stroke}, Key, ItemName}
-- Map markers sit in their own ScreenGui (MTL_Markers, built at runtime by MapMarkers with HUD.marker()).
local Theme = require(script.Parent.Parent.Theme)

local H = (Theme :: any).HUD

local function new(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(r: UDim?)
	return new("UICorner", { CornerRadius = r or H.Corner })
end

-- border (Name "Stroke" so controllers can recolour it for hover / selection)
local function border(color: Color3?, transparency: number?, thickness: number?)
	return new("UIStroke", {
		Name = "Stroke",
		Color = color or H.Line,
		Transparency = transparency or H.LineTransparency,
		Thickness = thickness or 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- soft shadow on text so it reads over the world
local function textShadow(strength: number?)
	return new("UIStroke", { Color = H.Shadow, Transparency = 1 - (strength or 0.4), Thickness = 1.2 })
end

local function label(props: { [string]: any }): any
	if props.BackgroundTransparency == nil then
		props.BackgroundTransparency = 1
	end
	props.FontFace = props.FontFace or H.Font
	props.TextColor3 = props.TextColor3 or H.Paper
	return new("TextLabel", props)
end

-- emoji icon, or Alex's image when Theme.HUD.Images[key] is set
local function icon(parent: Instance, emoji: string, size: number, imageKey: string?): GuiObject
	local img = imageKey and H.Images[imageKey]
	if img and img ~= "" and img ~= "rbxassetid://0" then
		return new("ImageLabel", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size, size),
			BackgroundTransparency = 1,
			Image = img,
			ScaleType = Enum.ScaleType.Fit,
			Parent = parent,
		})
	end
	return new("TextLabel", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Text = emoji,
		TextScaled = true,
		FontFace = H.Font,
		TextColor3 = H.Paper,
		Parent = parent,
	})
end

local HUD = {}
HUD.icon = icon

-- A round progress ring. Progress is drawn by two half-masks, each holding a full circle outline with a hard
-- transparency step; HUD.setRing() turns the gradients. Children: Track, Right/Arc, Left/Arc, Center.
function HUD.ring(name: string, color: Color3, size: number, thick: number): Frame
	local ring = new("Frame", {
		Name = name,
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
	})
	local inset = UDim2.new(1, -thick * 2, 1, -thick * 2)
	new("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = inset,
		BackgroundColor3 = H.Ink,
		BackgroundTransparency = H.InkTransparency,
		Parent = ring,
	}, {
		corner(UDim.new(1, 0)),
		new("UIStroke", { Color = H.Ink2, Transparency = 0, Thickness = thick }),
	})
	local step = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.502, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	for _, side in { "Right", "Left" } do
		local half = new("Frame", {
			Name = side,
			Position = if side == "Right" then UDim2.fromScale(0.5, 0) else UDim2.fromScale(0, 0),
			Size = UDim2.fromScale(0.5, 1),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Parent = ring,
		})
		local arc = new("Frame", {
			Name = "Arc",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = if side == "Right" then UDim2.fromScale(0, 0.5) else UDim2.fromScale(1, 0.5),
			Size = UDim2.new(2, -thick * 2, 1, -thick * 2),
			BackgroundTransparency = 1,
			Parent = half,
		}, { corner(UDim.new(1, 0)) })
		new("UIStroke", { Name = "Stroke", Color = color, Thickness = thick, Parent = arc }, {
			new("UIGradient", { Name = "Gradient", Transparency = step, Rotation = 0 }),
		})
	end
	new("Frame", {
		Name = "Center",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -thick * 2, 1, -thick * 2),
		BackgroundTransparency = 1,
		Parent = ring,
	})
	return ring
end

-- p = 0..1, clockwise from the top
function HUD.setRing(ring: Instance, p: number, color: Color3?)
	local a = math.clamp(p, 0, 1) * 360
	for _, side in { "Right", "Left" } do
		local half = ring:FindFirstChild(side)
		local arc = half and half:FindFirstChild("Arc")
		local s = arc and arc:FindFirstChild("Stroke") :: UIStroke?
		if s then
			local g = s:FindFirstChild("Gradient") :: UIGradient?
			if g then
				g.Rotation = if side == "Right" then math.clamp(a, 0, 180) else math.clamp(a, 180, 360)
			end
			if color then
				s.Color = color
			end
		end
	end
end

function HUD.build(): ScreenGui
	local gui = new("ScreenGui", {
		Name = "MTL_HUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 5,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	})

	---------------------------------------------------------------- top right: cash bar + status rings
	local top = new("Frame", {
		Name = "Top",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 10),
		Size = UDim2.fromOffset(300, 120),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { new("UIScale", { Name = "Scale" }) })

	local cash = new("Frame", {
		Name = "Cash",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(240, 52),
		BackgroundColor3 = H.Ink,
		BackgroundTransparency = H.InkTransparency,
		Parent = top,
	}, { corner(UDim.new(1, 0)), border(H.Money, 0.35, 2) })
	-- the cash stack pokes out past the left end, tilted
	local iconHolder = new("Frame", {
		Name = "IconHolder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 6, 0.5, 1),
		Size = UDim2.fromOffset(56, 56),
		Rotation = -12,
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = cash,
	})
	icon(iconHolder, "💵", 48, "Cash").ZIndex = 3
	local amount = label({
		Name = "Amount",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -22, 0.5, 0),
		Size = UDim2.new(1, -70, 0, 38),
		FontFace = H.CashFont,
		Text = "$0",
		TextColor3 = H.Money,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 2,
		Parent = cash,
	})
	new("UITextSizeConstraint", { MaxTextSize = 32, Parent = amount })

	-- status row under the bar: [boosts] [LEVEL text] (level ring) (health ring)
	local status = new("Frame", {
		Name = "Status",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 60),
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 1,
		Parent = top,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
	label({
		Name = "Boosts",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "",
		TextColor3 = H.Gold,
		TextSize = 13,
		Parent = status,
	})
	local xp = new("Frame", { Name = "XP", LayoutOrder = 2, Size = UDim2.fromOffset(96, 40), BackgroundTransparency = 1, Parent = status })
	label({
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 20),
		Text = "LEVEL 1",
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = xp,
	})
	label({
		Name = "Text",
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 0, 16),
		FontFace = H.BodyFont,
		Text = "0 / 60 XP",
		TextColor3 = H.Muted,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = xp,
	})
	for _, l in xp:GetChildren() do
		textShadow(0.45).Parent = l
	end
	local level = HUD.ring("Level", H.Level, 48, 4)
	level.LayoutOrder = 3
	level.Parent = status
	label({ Name = "Num", Size = UDim2.fromScale(1, 1), FontFace = H.CashFont, Text = "1", TextSize = 18, Parent = level.Center })
	local health = HUD.ring("Health", H.Health, 48, 4)
	health.LayoutOrder = 4
	health.Parent = status
	local glyph = icon(health.Center, "❤️", 20)
	glyph.Name = "Glyph"
	HUD.setRing(level, 0)
	HUD.setRing(health, 1)

	---------------------------------------------------------------- top centre: the one objective line
	local objective = new("Frame", {
		Name = "Objective",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64), -- under the VBX News ticker
		Size = UDim2.fromOffset(0, 36),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = H.Ink,
		BackgroundTransparency = H.InkTransparency,
		Visible = false,
		Parent = gui,
	}, {
		corner(UDim.new(1, 0)),
		border(),
		new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 18) }),
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	new("Frame", {
		Name = "Dot",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = H.Gold,
		Parent = objective,
	}, { corner(UDim.new(1, 0)) })
	label({
		Name = "Text",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 36),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "",
		TextSize = 15,
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
		Parent = objective,
	})

	---------------------------------------------------------------- left: toasts stack (right of the menu button)
	new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 84, 0.4, 0),
		Size = UDim2.fromOffset(340, 260),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		new("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	---------------------------------------------------------------- centre: the big-moment band (level up, mission passed)
	local banner = new("Frame", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.new(1, 0, 0, 120),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	new("Frame", {
		Name = "Ribbon",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = H.Ink,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = banner,
	}, {
		new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.25, 0),
				NumberSequenceKeypoint.new(0.75, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	local title = label({
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.new(1, 0, 0, 56),
		Text = "",
		TextColor3 = H.Gold,
		TextSize = 50,
		Parent = banner,
	})
	textShadow(0.5).Parent = title
	label({
		Name = "Sub",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 76),
		Size = UDim2.new(1, 0, 0, 22),
		FontFace = H.BodyFont,
		Text = "",
		TextSize = 17,
		Parent = banner,
	})

	-- reward pops rise up into the cash bar
	new("Frame", {
		Name = "Pops",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -30, 0, 128),
		Size = UDim2.fromOffset(230, 120),
		BackgroundTransparency = 1,
		Parent = gui,
	})

	---------------------------------------------------------------- left: the icon menu (hidden until Toggle)
	local menu = new("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.45, 0), -- high enough that the open panel clears the minimap (bottom left)
		Size = UDim2.fromOffset(260, 460),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { new("UIScale", { Name = "Scale" }) })
	local toggle = new("TextButton", {
		Name = "Toggle",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(56, 56),
		BackgroundColor3 = H.Ink,
		BackgroundTransparency = H.InkTransparency,
		AutoButtonColor = false,
		Text = "",
		Parent = menu,
	}, { corner(UDim.new(0, 14)), border() })
	local glyphBox = new("Frame", {
		Name = "Glyph",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -2),
		Size = UDim2.fromOffset(24, 24),
		BackgroundTransparency = 1,
		Parent = toggle,
	})
	for i = 0, 3 do
		new("Frame", {
			Name = "Sq" .. i,
			Position = UDim2.fromOffset((i % 2) * 14, math.floor(i / 2) * 14),
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = H.Paper,
			Parent = glyphBox,
		}, { corner(UDim.new(0, 3)) })
	end
	label({
		Name = "Key",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.fromOffset(20, 12),
		Text = "G",
		TextColor3 = H.Muted,
		TextSize = 10,
		Parent = toggle,
	})

	local panel = new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = H.Ink,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = menu,
	}, {
		corner(UDim.new(0, 14)),
		border(),
		new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }),
		new("UIScale", { Name = "Pop" }),
	})
	-- tab on the right edge that slides the menu away again
	new("TextButton", {
		Name = "Collapse",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, 10, 0.5, 0),
		Size = UDim2.fromOffset(26, 58),
		BackgroundColor3 = H.Ink2,
		AutoButtonColor = false,
		FontFace = H.Font,
		Text = "<",
		TextColor3 = H.Paper,
		TextSize = 22,
		ZIndex = 2,
		Parent = panel,
	}, { corner(UDim.new(1, 0)), border() })
	local grid = new("Frame", {
		Name = "Grid",
		Size = UDim2.fromOffset(192, 0), -- 2 columns of 92 px; MenuController sets the height for the visible tiles
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		new("UIGridLayout", {
			CellSize = UDim2.fromOffset(92, 92),
			CellPadding = UDim2.fromOffset(8, 8),
			FillDirectionMaxCells = 2,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	-- one tile; MenuController clones it per Config/HUD.Menu entry (Tile_<id>)
	local tile = new("TextButton", {
		Name = "TileTemplate",
		BackgroundColor3 = H.Ink2,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		Parent = grid,
	}, { corner(UDim.new(0, 12)), border() })
	local tIcon = icon(tile, "❔", 44)
	tIcon.Position = UDim2.fromScale(0.5, 0.42)
	local tLabel = label({
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -8, 0, 18),
		Text = "ITEM",
		TextScaled = true,
		Parent = tile,
	})
	new("UITextSizeConstraint", { MaxTextSize = 14, Parent = tLabel })
	textShadow(0.5).Parent = tLabel
	new("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = H.Danger,
		Visible = false,
		Parent = tile,
	}, { corner(UDim.new(1, 0)) })

	-- popups opened from the menu (Store, Emotes) are built into here by MenuController.
	-- Dim darkens the game behind an open popup; clicking it closes the popup.
	local panelsFrame = new("Frame", {
		Name = "Panels",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	new("TextButton", {
		Name = "Dim",
		Size = UDim2.new(1, 0, 1, 80),
		Position = UDim2.fromOffset(0, -60),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		ZIndex = 0,
		Parent = panelsFrame,
	})

	---------------------------------------------------------------- bottom centre: hotbar (round slots, key number above)
	local hotbar = new("Frame", {
		Name = "Hotbar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(420, 92),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		new("UIScale", { Name = "Scale" }),
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 12),
		}),
	})
	local slot = new("TextButton", {
		Name = "SlotTemplate",
		Size = UDim2.fromOffset(64, 92),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		Parent = hotbar,
	}, { new("UIScale", { Name = "Pop" }) })
	local key = label({
		Name = "Key",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(40, 22),
		Text = "1",
		TextSize = 18,
		Parent = slot,
	})
	textShadow(0.5).Parent = key
	local disc = new("Frame", {
		Name = "Disc",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(62, 62),
		BackgroundColor3 = H.Ink,
		BackgroundTransparency = H.InkTransparency,
		Parent = slot,
	}, { corner(UDim.new(1, 0)), border(H.Line, 0.7, 2) })
	icon(disc, "👊", 38)
	local itemName = label({
		Name = "ItemName",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -66),
		Size = UDim2.fromOffset(140, 18),
		Text = "",
		TextSize = 13,
		Visible = false,
		Parent = slot,
	})
	textShadow(0.5).Parent = itemName

	return gui
end

-- One toast row (built at runtime per message): dark strip with a colour edge.
function HUD.toast(text: string, color: Color3?): Frame
	local row = new("Frame", {
		Name = "Toast",
		Size = UDim2.fromOffset(0, 36),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = H.Ink,
		BackgroundTransparency = H.InkTransparency,
	}, {
		corner(),
		new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 14) }),
		new("UIScale", { Name = "Pop" }),
	})
	new("Frame", {
		Name = "Accent",
		Position = UDim2.new(0, -16, 0, 6),
		Size = UDim2.new(0, 3, 1, -12),
		BackgroundColor3 = color or H.Gold,
		BorderSizePixel = 0,
		Parent = row,
	}, { corner(UDim.new(1, 0)) })
	label({
		Name = "Text",
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = H.BodyFont,
		Text = text,
		TextSize = 14,
		Parent = row,
	})
	return row
end

function HUD.pop(text: string, color: Color3): TextLabel
	local l = label({
		Name = "Pop",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 40),
		Size = UDim2.new(1, 0, 0, 28),
		FontFace = H.CashFont,
		Text = text,
		TextColor3 = color,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	textShadow(0.55).Parent = l
	return l
end

-- A popup panel (Store, Emotes): title, close button and a scrolling List. Built at runtime.
function HUD.panel(name: string, title: string, width: number, height: number): Frame
	local p = new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = H.Ink,
		BackgroundTransparency = 0.04,
		Visible = false,
	}, {
		corner(UDim.new(0, 14)),
		border(),
		new("UIScale", { Name = "Pop" }),
	})
	label({
		Name = "Title",
		Position = UDim2.fromOffset(24, 14),
		Size = UDim2.new(1, -80, 0, 36),
		Text = title,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = p,
	})
	new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = H.Ink2,
		AutoButtonColor = false,
		FontFace = H.BodyFont,
		Text = "X",
		TextColor3 = H.Paper,
		TextSize = 16,
		Parent = p,
	}, { corner(UDim.new(1, 0)), border() })
	new("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(16, 60),
		Size = UDim2.new(1, -32, 1, -74),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = H.Muted,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = p,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 3), PaddingBottom = UDim.new(0, 6) }),
	})
	return p
end

-- A store tab: a pill that fills when selected (Tab_<id>; MenuController sets the colours).
function HUD.storeTab(id: string, text: string): TextButton
	return new("TextButton", {
		Name = "Tab_" .. id,
		Size = UDim2.fromOffset(160, 38),
		BackgroundColor3 = H.Ink2,
		AutoButtonColor = false,
		FontFace = H.Font,
		Text = text,
		TextColor3 = H.Muted,
		TextSize = 14,
	}, { corner(UDim.new(1, 0)), border() })
end

-- One product card: art panel with a big icon, ribbon, title, blurb and a price button.
-- Children MenuController uses: Buy (TextButton; its Text is the price) / Buy/Press / Pop / Stroke.
function HUD.storeCard(def: any): Frame
	local tint = def.color or H.Gold
	local card = new("Frame", {
		Name = "Card_" .. def.item,
		Size = UDim2.fromOffset(236, 320),
		BackgroundColor3 = H.Ink2,
	}, { corner(UDim.new(0, 12)), border(), new("UIScale", { Name = "Pop" }) })
	local art = new("Frame", {
		Name = "Art",
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 0, 150),
		BackgroundColor3 = tint,
		BackgroundTransparency = 0.78, -- a soft tint, not a loud block of colour
		Parent = card,
	}, { corner(UDim.new(0, 10)) })
	icon(art, def.emoji or "", 84, "Store_" .. def.item)
	if def.ribbon then
		local r = label({
			Name = "Ribbon",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -18, 0, 18),
			Size = UDim2.fromOffset(0, 22),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 0,
			BackgroundColor3 = H.Gold,
			Text = def.ribbon,
			TextColor3 = H.Ink,
			TextSize = 11,
			ZIndex = 3,
			Parent = card,
		})
		corner(UDim.new(1, 0)).Parent = r
		new("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9), Parent = r })
	end
	label({
		Name = "Title",
		Position = UDim2.fromOffset(16, 172),
		Size = UDim2.new(1, -32, 0, 26),
		Text = def.title,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = card,
	})
	label({
		Name = "Blurb",
		Position = UDim2.fromOffset(16, 202),
		Size = UDim2.new(1, -32, 0, 50),
		FontFace = H.BodyFont,
		Text = def.blurb,
		TextColor3 = H.Muted,
		TextSize = 14,
		LineHeight = 1.1,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = card,
	})
	new("TextButton", {
		Name = "Buy",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(1, -28, 0, 44),
		BackgroundColor3 = H.Money,
		AutoButtonColor = false,
		FontFace = H.CashFont,
		Text = "...",
		TextColor3 = H.Paper,
		TextSize = 18,
		Parent = card,
	}, { corner(UDim.new(0, 10)), new("UIScale", { Name = "Press" }) })
	return card
end

-- One map marker: dark disc with the emoji, a thin ring, a name + distance tag under it.
function HUD.marker(emoji: string, name: string, size: number): Frame
	local m = new("Frame", {
		Name = "Marker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
	}, { new("UIScale", { Name = "Scale" }) })
	local disc = new("Frame", {
		Name = "Disc",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = H.Marker,
		BackgroundTransparency = H.MarkerTransparency,
		Parent = m,
	}, { corner(UDim.new(1, 0)), border(H.Paper, 0.75, 1.5) })
	icon(disc, emoji, math.floor(size * 0.56))
	local tag = label({
		Name = "Tag",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 6),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = H.InkTransparency,
		BackgroundColor3 = H.Ink,
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
		RichText = true,
		Text = name,
		TextSize = 13,
		Visible = false,
		Parent = m,
	})
	new("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = tag })
	corner(UDim.new(1, 0)).Parent = tag
	return m
end

-- An interaction prompt (PromptController): key tile + action text, in a BillboardGui. Names used:
-- Body (TextButton) / Body/Pop, Body/Key/{Letter, Fill}, Body/Info/{Action, Object, Hold}
function HUD.prompt(): BillboardGui
	local bb = new("BillboardGui", {
		Size = UDim2.fromOffset(300, 64),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Active = true,
		ResetOnSpawn = false,
		ClipsDescendants = false,
	})
	local body = new("TextButton", {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Parent = bb,
	}, {
		new("UIScale", { Name = "Pop" }),
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local key = new("Frame", {
		Name = "Key",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = H.Paper,
		ClipsDescendants = true,
		Parent = body,
	}, { corner(UDim.new(0, 10)) })
	new("Frame", {
		Name = "Fill",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BorderSizePixel = 0,
		BackgroundColor3 = H.Money,
		Parent = key,
	})
	label({
		Name = "Letter",
		Size = UDim2.fromScale(1, 1),
		FontFace = H.CashFont,
		Text = "E",
		TextColor3 = H.Ink,
		TextSize = 22,
		ZIndex = 2,
		Parent = key,
	})
	local info = new("Frame", {
		Name = "Info",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = H.Ink,
		BackgroundTransparency = H.InkTransparency,
		Parent = body,
	}, {
		corner(UDim.new(0, 10)),
		new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 14) }),
		new("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	label({
		Name = "Hold",
		LayoutOrder = 0,
		Size = UDim2.fromOffset(0, 12),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "HOLD",
		TextColor3 = H.Gold,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = false,
		Parent = info,
	})
	label({
		Name = "Action",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "Interact",
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = info,
	})
	label({
		Name = "Object",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 14),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = H.BodyFont,
		Text = "",
		TextColor3 = H.Muted,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = info,
	})
	return bb
end

-- Settings rows (MenuController's Settings popup). A row = caption on the left, control on the right.
-- Slider: Row/{Caption, Value, Track/{Fill, Knob}} (Track is the hit area).
function HUD.slider(caption: string): Frame
	local row = new("Frame", { Name = "Slider", Size = UDim2.new(1, -6, 0, 44), BackgroundTransparency = 1 })
	label({ Name = "Caption", Size = UDim2.new(0.42, 0, 1, 0), Text = caption, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	label({
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(46, 44),
		FontFace = H.BodyFont,
		Text = "100%",
		TextColor3 = H.Muted,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})
	local track = new("TextButton", {
		Name = "Track",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0.42, 0, 0.5, 0),
		Size = UDim2.new(0.58, -56, 0, 6),
		BackgroundColor3 = H.Ink2,
		AutoButtonColor = false,
		Text = "",
		Parent = row,
	}, { corner(UDim.new(1, 0)) })
	new("Frame", { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = H.Accent, Parent = track }, { corner(UDim.new(1, 0)) })
	new("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = H.Paper,
		ZIndex = 2,
		Parent = track,
	}, { corner(UDim.new(1, 0)), new("UIStroke", { Color = H.Ink, Transparency = 0.5, Thickness = 1 }) })
	return row
end

-- Segmented choice: Row/{Caption, Options/Opt_<value>}. MenuController colours the selected one.
function HUD.segmented(caption: string, options: { { value: any, text: string } }): Frame
	local row = new("Frame", { Name = "Choice", Size = UDim2.new(1, -6, 0, 44), BackgroundTransparency = 1 })
	label({ Name = "Caption", Size = UDim2.new(0.42, 0, 1, 0), Text = caption, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	local opts = new("Frame", {
		Name = "Options",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0.58, 0, 0, 32),
		BackgroundColor3 = H.Ink2,
		Parent = row,
	}, {
		corner(UDim.new(1, 0)),
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3), PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3) }),
	})
	for i, o in options do
		new("TextButton", {
			Name = "Opt_" .. tostring(o.value),
			LayoutOrder = i,
			Size = UDim2.new(1 / #options, 0, 1, 0),
			BackgroundColor3 = H.Accent,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			FontFace = H.Font,
			Text = o.text,
			TextColor3 = H.Muted,
			TextSize = 13,
			Parent = opts,
		}, { corner(UDim.new(1, 0)) })
	end
	return row
end

-- A small section heading in a popup list.
function HUD.sectionTitle(text: string): TextLabel
	return label({
		Name = "Section",
		Size = UDim2.new(1, -6, 0, 30),
		Text = string.upper(text),
		TextColor3 = H.Muted,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Bottom,
	})
end

-- Keybind hints (KeyHints controller): a column above the minimap. Hints/{Row template: Key, Text}
function HUD.keyHint(key: string, text: string): Frame
	local row = new("Frame", {
		Name = "Hint",
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local k = label({
		Name = "Key",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = H.InkTransparency,
		BackgroundColor3 = H.Ink,
		Text = key,
		TextSize = 12,
		Parent = row,
	})
	corner(UDim.new(0, 5)).Parent = k
	border(H.Line, 0.75, 1).Parent = k
	new("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7), Parent = k })
	local t = label({
		Name = "Text",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = H.BodyFont,
		Text = text,
		TextSize = 13,
		Parent = row,
	})
	textShadow(0.55).Parent = t
	return row
end

return HUD
