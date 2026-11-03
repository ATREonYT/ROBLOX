--!strict
-- Builds the MTL_Property ScreenGui (Piece 4): the FOR SALE card at the flat's door and the door fade.
-- Used two ways, same as HUD/Phone/Job/Mission:
--   1. Edit time: tools/Install.lua saves it into StarterGui as real instances (Alex reskins it there)
--   2. Runtime fallback: PropertyController builds it only if PlayerGui has no MTL_Property
-- PropertyController finds things BY NAME. Keep these names when reskinning:
--   Fade · Listing (Dim) · Listing/Card/{Photo/{Image, Sign}, Tag, Title, Area, Blurb, Facts, Price, Cash, Short,
--   Buttons/{Buy, Later}} · Facts gets one "Fact" row per line (cloned from Facts/FactTemplate: Key, Value)
local Theme = require(script.Parent.Parent.Theme)

local C = Theme.Colors
local K = Theme.Property

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

local function corner(r: UDim?): UICorner
	return new("UICorner", { CornerRadius = r or Theme.Corner })
end

local function label(parent: Instance, name: string, text: string, size: number, opts: { [string]: any }?): TextLabel
	local o = opts or {}
	return new("TextLabel", {
		Name = name,
		LayoutOrder = o.order or 0,
		Size = UDim2.new(1, 0, 0, size + 6),
		AutomaticSize = if o.wrap then Enum.AutomaticSize.Y else Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		FontFace = if o.bold then Theme.Fonts.Bold elseif o.display then Theme.Fonts.Display else Theme.Fonts.Body,
		Text = text,
		TextColor3 = o.color or C.Text,
		TextSize = size,
		TextWrapped = o.wrap == true,
		TextXAlignment = o.align or Enum.TextXAlignment.Left,
		Parent = parent,
	})
end

local Property = {}

function Property.build(): ScreenGui
	local gui = new("ScreenGui", {
		Name = "MTL_Property",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 45, -- the door fade covers the HUD and the phone; cutscenes (50) cover it
		Enabled = true,
	})

	-- the FOR SALE card (dims the world behind it)
	local listing = new("Frame", {
		Name = "Listing",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Shadow,
		BackgroundTransparency = K.DimTransparency,
		Visible = false,
		Parent = gui,
	})
	local card = new("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = K.Card,
		Parent = listing,
	}, {
		corner(UDim.new(0, 16)),
		new("UIStroke", { Color = C.Stroke, Transparency = C.StrokeTransparency }),
		new("UIPadding", { PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 16), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }),
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UISizeConstraint", { MaxSize = Vector2.new(380, math.huge) }),
		new("UIScale", { Name = "Scale" }),
	})
	-- photo (TODO(Alex art): Config/Property.Homes[..].photo) with a hand-written sign on top
	local photo = new("Frame", {
		Name = "Photo",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 150),
		BackgroundColor3 = K.PhotoBack,
		ClipsDescendants = true,
		Parent = card,
	}, { corner(UDim.new(0, 12)) })
	new("ImageLabel", {
		Name = "Image",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = "rbxassetid://0",
		ScaleType = Enum.ScaleType.Crop,
		Parent = photo,
	})
	new("TextLabel", {
		Name = "Sign",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(170, 52),
		Rotation = -4,
		BackgroundColor3 = K.Sign,
		FontFace = Theme.Fonts.Display,
		Text = "FOR SALE",
		TextColor3 = K.SignText,
		TextSize = 26,
		Parent = photo,
	}, { corner(UDim.new(0, 4)) })
	label(card, "Tag", "FOR SALE  ·  CASH ONLY", 12, { order = 2, bold = true, color = K.Tag })
	label(card, "Title", "Flat 3B", 24, { order = 3, display = true })
	label(card, "Area", "The Ends", 14, { order = 4, color = C.TextDim })
	label(card, "Blurb", "", 14, { order = 5, wrap = true })
	local facts = new("Frame", {
		Name = "Facts",
		LayoutOrder = 6,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = card,
	}, { new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local fact = new("Frame", {
		Name = "FactTemplate",
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = facts,
	})
	label(fact, "Key", "Power", 13, { color = C.TextDim }).Size = UDim2.new(0.38, 0, 1, 0)
	local value = label(fact, "Value", "Off", 13, { bold = true })
	value.Position = UDim2.fromScale(0.38, 0)
	value.Size = UDim2.new(0.62, 0, 1, 0)
	label(card, "Price", "$1,200", 34, { order = 7, display = true, color = C.Accent })
	label(card, "Cash", "You have $0", 13, { order = 8, color = C.TextDim })
	label(card, "Short", "", 13, { order = 9, bold = true, color = C.Danger, wrap = true })
	local buttons = new("Frame", {
		Name = "Buttons",
		LayoutOrder = 10,
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundTransparency = 1,
		Parent = card,
	}, { new("UIListLayout", { Padding = UDim.new(0, 8), FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder }) })
	new("TextButton", {
		Name = "Buy",
		LayoutOrder = 1,
		Size = UDim2.new(0.64, -4, 1, 0),
		BackgroundColor3 = C.Accent,
		AutoButtonColor = false,
		FontFace = Theme.Fonts.Bold,
		Text = "BUY IT",
		TextColor3 = C.Glass,
		TextSize = 18,
		Parent = buttons,
	}, { corner(Theme.CornerSmall) })
	new("TextButton", {
		Name = "Later",
		LayoutOrder = 2,
		Size = UDim2.new(0.36, -4, 1, 0),
		BackgroundColor3 = K.Secondary,
		AutoButtonColor = false,
		FontFace = Theme.Fonts.Bold,
		Text = "Not now",
		TextColor3 = C.Text,
		TextSize = 15,
		Parent = buttons,
	}, { corner(Theme.CornerSmall) })

	-- the door fade (walking in / out). Above the card.
	new("Frame", {
		Name = "Fade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 20,
		Visible = false,
		Parent = gui,
	})
	return gui
end

return Property
