--!strict
-- Builds the MTL_Cutscene ScreenGui (Piece 3): letterbox bars, subtitles, title card, fade, skip hint.
-- Used two ways, same as HUD/Phone/Job:
--   1. Edit time: tools/Install.lua saves it into StarterGui as real instances (Alex reskins it there)
--   2. Runtime fallback: CutsceneController builds it only if PlayerGui has no MTL_Cutscene
-- CutsceneController finds things BY NAME. Keep these names when reskinning:
--   Fade, BarTop, BarBottom, Subtitle/{Portrait/{View, Initial, Ring}, Text/{Speaker, Line}, Next}, Title/Main, Title/Rule, Title/Sub,
--   Skip/Hint, Skip/Bar/Fill, Tap
local Theme = require(script.Parent.Parent.Theme)

local C = Theme.Colors
local K = Theme.Cutscene

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


local Cutscene = {}

function Cutscene.build(): ScreenGui
	local gui = new("ScreenGui", {
		Name = "MTL_Cutscene",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 50, -- above everything
		Enabled = false,
	})

	-- full-screen catcher for clicks/taps (tap = next line, hold = skip). Under everything else.
	new("TextButton", {
		Name = "Tap",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 1,
		Parent = gui,
	})

	new("Frame", {
		Name = "BarTop",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 0), -- slides to (0, BarShare)
		Size = UDim2.fromScale(1, K.BarShare),
		BackgroundColor3 = K.Bar,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = gui,
	})
	new("Frame", {
		Name = "BarBottom",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromScale(0, 1), -- slides to (0, 1 - BarShare)
		Size = UDim2.fromScale(1, K.BarShare),
		BackgroundColor3 = K.Bar,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = gui,
	})

	-- dialogue box (Alex: "a box with the character's face on the side, bold text people can read"). It sits on the
	-- top edge of the bottom letterbox bar: a speaker portrait (a live 3D head of whoever talks, or their initial),
	-- a name tag in the speaker's colour, the line in bold, a small "next" arrow once it has finished typing.
	-- Flat dark panel, one thin border: no glow, no gradient. Names kept: Subtitle/{Speaker, Line} (+ Portrait, Next).
	local sub = new("Frame", {
		Name = "Subtitle",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1 - K.BarShare * 0.35, 0),
		Size = UDim2.new(0.64, 0, 0, 104),
		BackgroundColor3 = Color3.fromRGB(12, 13, 16),
		BackgroundTransparency = 0.12,
		Visible = false,
		ZIndex = 6, -- above the Fade (5): lines over black still read
		Parent = gui,
	}, {
		new("UISizeConstraint", { MaxSize = Vector2.new(820, 104), MinSize = Vector2.new(300, 104) }),
		new("UICorner", { CornerRadius = UDim.new(0, 12) }),
		new("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Transparency = 0.86, Thickness = 1 }),
		new("UIScale", { Name = "Pop" }),
	})
	-- portrait: a square with the speaker's head rendered live (ViewportFrame "View"), or a big initial
	local portrait = new("Frame", {
		Name = "Portrait",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(80, 80),
		BackgroundColor3 = Color3.fromRGB(30, 32, 38),
		ZIndex = 6,
		Parent = sub,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, 10) }),
		new("UIStroke", { Name = "Ring", Color = K.SpeakerDefault, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	new("ViewportFrame", {
		Name = "View",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(196, 194, 200),
		LightColor = Color3.fromRGB(255, 244, 230),
		LightDirection = Vector3.new(-0.6, -0.4, -1),
		ZIndex = 6,
		Parent = portrait,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 10) }) })
	new("TextLabel", {
		Name = "Initial",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy),
		Text = "",
		TextColor3 = Color3.fromRGB(245, 246, 250),
		TextScaled = true,
		ZIndex = 7,
		Parent = portrait,
	}, { new("UIPadding", { PaddingTop = UDim.new(0.22, 0), PaddingBottom = UDim.new(0.22, 0) }) })
	-- text column right of the portrait
	local col = new("Frame", {
		Name = "Text",
		Position = UDim2.new(0, 108, 0, 14),
		Size = UDim2.new(1, -132, 1, -26),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = sub,
	})
	new("TextLabel", {
		Name = "Speaker", -- the name tag: speaker colour, small caps feel
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy),
		Text = "",
		TextColor3 = K.SpeakerDefault,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = col,
	})
	new("TextLabel", {
		Name = "Line",
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 1, -24),
		BackgroundTransparency = 1,
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
		Text = "",
		TextColor3 = K.SubtitleText,
		TextScaled = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = 1.08,
		ZIndex = 6,
		Parent = col,
	}, { new("UITextSizeConstraint", { MaxTextSize = 22, MinTextSize = 12 }) })
	new("TextLabel", {
		Name = "Next", -- shows when the line has finished typing (tap = next)
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -8),
		Size = UDim2.fromOffset(16, 16),
		BackgroundTransparency = 1,
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
		Text = "▼",
		TextColor3 = Color3.fromRGB(245, 246, 250),
		TextTransparency = 0.3,
		TextSize = 12,
		Visible = false,
		ZIndex = 6,
		Parent = sub,
	})

	-- choice card (story choices inside a scene): a prompt and 2-3 numbered options, same flat dark style as the box
	local choice = new("Frame", {
		Name = "Choice",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1 - K.BarShare * 0.35, -6),
		Size = UDim2.new(0.5, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(12, 13, 16),
		BackgroundTransparency = 0.08,
		Visible = false,
		ZIndex = 8,
		Parent = gui,
	}, {
		new("UISizeConstraint", { MaxSize = Vector2.new(620, 400), MinSize = Vector2.new(300, 0) }),
		new("UICorner", { CornerRadius = UDim.new(0, 12) }),
		new("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Transparency = 0.86, Thickness = 1 }),
		new("UIPadding", { PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }),
		new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIScale", { Name = "Pop" }),
	})
	new("TextLabel", {
		Name = "Prompt",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy),
		Text = "",
		TextColor3 = K.TitleSub,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 8,
		Parent = choice,
	})
	local opts = new("Frame", {
		Name = "Options",
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 8,
		Parent = choice,
	}, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local optT = new("TextButton", {
		Name = "OptionTemplate",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Color3.fromRGB(38, 40, 46),
		AutoButtonColor = true,
		Text = "",
		Visible = false,
		ZIndex = 8,
		Parent = opts,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, 8) }),
		new("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Transparency = 0.88, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	new("TextLabel", {
		Name = "Num",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Color3.fromRGB(245, 245, 245),
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy),
		Text = "1",
		TextColor3 = Color3.fromRGB(24, 25, 29),
		TextSize = 14,
		ZIndex = 9,
		Parent = optT,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 6) }) })
	new("TextLabel", {
		Name = "Label",
		Position = UDim2.new(0, 48, 0, 0),
		Size = UDim2.new(1, -58, 1, 0),
		BackgroundTransparency = 1,
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
		Text = "",
		TextColor3 = Color3.fromRGB(245, 245, 245),
		TextSize = 17,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 9,
		Parent = optT,
	})

	-- chapter title card: a heavy wide title, a thin gold rule, a quiet subtitle (on black or over the picture)
	local title = new("Frame", {
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.new(0.8, 0, 0, 120),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 6,
		Parent = gui,
	}, { new("UISizeConstraint", { MaxSize = Vector2.new(900, 120) }) })
	new("TextLabel", {
		Name = "Main",
		Size = UDim2.new(1, 0, 0, 66),
		BackgroundTransparency = 1,
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy),
		Text = "",
		TextColor3 = K.TitleColor,
		TextScaled = true,
		ZIndex = 6,
		Parent = title,
	}, {
		new("UITextSizeConstraint", { MaxTextSize = 60, MinTextSize = 24 }),
		new("UIStroke", { Color = K.SubtitleShadow, Transparency = 0.7, Thickness = 1.5 }),
	})
	new("Frame", {
		Name = "Rule",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.fromOffset(64, 2),
		BackgroundColor3 = K.TitleSub,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = title,
	})
	new("TextLabel", {
		Name = "Sub",
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
		Text = "",
		TextColor3 = K.TitleSub,
		TextSize = 19,
		ZIndex = 6,
		Parent = title,
	}, { new("UIStroke", { Color = K.SubtitleShadow, Transparency = 0.75, Thickness = 1 }) })

	-- fade to/from black (between the bars and the title card)
	new("Frame", {
		Name = "Fade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = K.Fade,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = gui,
	})

	-- skip hint: bottom right, inside the bottom bar
	local skip = new("Frame", {
		Name = "Skip",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -24, 1 - K.BarShare / 2, 0),
		Size = UDim2.fromOffset(190, 30),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 7,
		Parent = gui,
	})
	new("TextLabel", {
		Name = "Hint",
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Bold,
		Text = "Hold SPACE to skip",
		TextColor3 = C.TextDim,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 7,
		Parent = skip,
	})
	local bar = new("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 22),
		Size = UDim2.new(0.6, 0, 0, 3),
		BackgroundColor3 = C.TextDim,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = skip,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = K.SkipFill,
		BorderSizePixel = 0,
		ZIndex = 7,
		Parent = bar,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })

	return gui
end

return Cutscene
