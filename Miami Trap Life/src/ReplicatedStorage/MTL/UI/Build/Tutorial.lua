--!strict
-- Builds the MTL_Tutorial ScreenGui (the new-player coach). Same two uses as the other screens: saved into
-- StarterGui at install (Alex reskins it there), or built at runtime if PlayerGui has none.
-- TutorialController finds things BY NAME. Keep these names when reskinning:
--   Card/{Step, Title, Body, Keys/KeyTemplate/Label, Dots/DotTemplate, Ok, Skip, Tick}   Ring/Stroke   Arrow
local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)

local C = Theme.Colors
local T = (Theme :: any).Tutorial
local new = UIKit.new

local Build = {}

function Build.build(): ScreenGui
	local gui = new("ScreenGui", {
		Name = "MTL_Tutorial",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 11, -- above the HUD (5) ... phone (10) so the ring shows on phone apps; below fades (45) and cutscenes (50)
	})

	-- the coach card: a small, minimal hint strip, top LEFT just under Roblox's own top bar (Alex 2026-11-03: "on
	-- the side", "more up", "make it minimal"). Semi-transparent dark, no frame decoration, auto-sized to its text.
	-- Like the hint strips in the big simulators: a tiny step count, a bold line, one short instruction.
	local card = new("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(16, 64),
		Size = UDim2.fromOffset(236, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.Card,
		BackgroundTransparency = 0.3,
		Visible = false,
		Parent = gui,
	}, {
		UIKit.corner(UDim.new(0, 6)),
		new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 7) }),
		new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIScale", { Name = "Pop" }),
	})
	new("TextLabel", {
		Name = "Step",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 11),
		BackgroundTransparency = 1,
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
		TextSize = 10,
		TextColor3 = T.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "STEP 1 OF 7",
		Parent = card,
	})
	new("TextLabel", {
		Name = "Title",
		LayoutOrder = 2,
		Size = UDim2.new(1, -26, 0, 17),
		BackgroundTransparency = 1,
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy),
		TextSize = 15,
		TextColor3 = C.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Parent = card,
	})
	new("TextLabel", {
		Name = "Body",
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Body,
		TextSize = 13,
		LineHeight = 1.05,
		TextWrapped = true,
		TextColor3 = C.Text,
		TextTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = card,
	})
	local keys = new("Frame", {
		Name = "Keys",
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Parent = card,
	}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }) })
	new("Frame", {
		Name = "KeyTemplate",
		Visible = false,
		Size = UDim2.fromOffset(22, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = T.Key,
		Parent = keys,
	}, {
		UIKit.corner(UDim.new(0, 4)),
		new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
		new("TextLabel", {
			Name = "Label",
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			FontFace = Theme.Fonts.Bold,
			TextSize = 11,
			TextColor3 = T.KeyText,
			Text = "M",
		}),
	})

	-- bottom row: tiny progress dots on the left, "Got it" + "Skip" on the right
	local bottom = new("Frame", { Name = "Bottom", LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Parent = card })
	local dots = new("Frame", {
		Name = "Dots",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(110, 6),
		BackgroundTransparency = 1,
		Parent = bottom,
	}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }) })
	new("Frame", { Name = "DotTemplate", Visible = false, Size = UDim2.fromOffset(5, 5), BackgroundColor3 = T.Dim, Parent = dots }, { UIKit.corner(UDim.new(1, 0)) })
	new("TextButton", {
		Name = "Skip",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Body,
		TextSize = 11,
		TextColor3 = T.Dim,
		Text = "Skip",
		Parent = bottom,
	})
	new("TextButton", {
		Name = "Ok",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -36, 0.5, 0),
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = T.Accent,
		FontFace = Theme.Fonts.Bold,
		TextSize = 11,
		TextColor3 = T.KeyText,
		Text = "Got it",
		Visible = false,
		Parent = bottom,
	}, { UIKit.corner(UDim.new(0, 4)), new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }) })
	-- the small green tick that pops when a step is done (top right corner, outside the list layout's flow)
	new("TextLabel", {
		Name = "Tick",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = Color3.fromRGB(92, 196, 104), -- the HUD's green (Theme.HUD.Money): "done"
		FontFace = Theme.Fonts.Display,
		TextSize = 12,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "✓",
		Visible = false,
		ZIndex = 3,
		Parent = card,
	}, { UIKit.corner(UDim.new(1, 0)), new("UIScale", { Name = "Pop" }) })

	-- the ring that goes around the HUD element the card is talking about (positioned by the controller)
	new("Frame", {
		Name = "Ring",
		Visible = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(60, 60),
		Parent = gui,
	}, {
		UIKit.corner(UDim.new(0, 14)),
		new("UIStroke", { Name = "Stroke", Color = T.Ring, Thickness = 3, Transparency = 0 }),
	})
	-- a small bouncing arrow next to the ring
	new("TextLabel", {
		Name = "Arrow",
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(32, 32),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Display,
		TextSize = 30,
		TextColor3 = T.Ring,
		TextStrokeTransparency = 0.4,
		Text = "▼",
		Parent = gui,
	})
	return gui
end

return Build
