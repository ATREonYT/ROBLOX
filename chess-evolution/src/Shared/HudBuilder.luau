--!strict
-- +1 Chess Evolution: builds the ChessHUD ScreenGui (run by tools/build_place.luau, saved to
-- src/StarterGui/ChessHUD.rbxm so the owner can see and edit it in Studio; the client reuses these parts).
-- Look: bold simulator HUD. Dark outlines, white display text, saturated panels, small shadow.
-- Gold = Wins, green = training, cyan = Chess Sets, red = battle, purple/pink = rare.
-- Icons are small 3D chess models in ViewportFrames (our own, no uploaded images).

local Models = require(script.Parent:WaitForChild("Models"))
local DuelHud = require(script.Parent:WaitForChild("DuelHud"))
local BadgeArt = require(script.Parent:WaitForChild("BadgeArt"))
local FeelKit = require(script.Parent:WaitForChild("FeelKit"))

local Hud = {}

local FONT = Font.fromEnum(Enum.Font.FredokaOne)
local INK = Color3.fromRGB(28, 26, 40)
local WHITE = Color3.new(1, 1, 1)
local C = {
	gold = Color3.fromRGB(255, 196, 40),
	green = Color3.fromRGB(70, 210, 80),
	cyan = Color3.fromRGB(40, 200, 240),
	red = Color3.fromRGB(240, 70, 70),
	purple = Color3.fromRGB(170, 80, 240),
	grey = Color3.fromRGB(110, 116, 132),
	panel = Color3.fromRGB(44, 46, 66),
	orange = Color3.fromRGB(255, 140, 40),
	ivory = Color3.fromRGB(246, 238, 220),
}
Hud.Colors = C

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end
Hud.New = new

local function corner(parent: Instance, r: number?)
	new("UICorner", { CornerRadius = UDim.new(0, r or 12) }, parent)
end

local function stroke(parent: Instance, thickness: number?, color: Color3?)
	new("UIStroke", { Thickness = thickness or 3, Color = color or INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
end

local function shade(parent: Instance)
	-- subtle top highlight: lighter top, slightly darker bottom
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(235, 235, 235)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 190, 190)),
		}),
	}, parent)
end

-- Text with a dark outline (display text).
local function text(parent: Instance, name: string, props: { [string]: any }): TextLabel
	local t = new("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		FontFace = FONT,
		TextColor3 = WHITE,
		TextScaled = false,
		TextSize = 24,
		Text = "",
	}, nil)
	for k, v in props do
		if k ~= "StrokeThickness" then
			(t :: any)[k] = v
		end
	end
	new("UIStroke", { Thickness = props.StrokeThickness or 2.5, Color = INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Name = "Outline" }, t)
	t.Parent = parent
	return t
end
Hud.Text = text

-- A chunky coloured panel/button with outline, highlight and a small drop shadow.
local function block(parent: Instance, name: string, className: string, color: Color3, size: UDim2, pos: UDim2, anchor: Vector2?): any
	local holder = new("Frame", { Name = name, BackgroundTransparency = 1, Size = size, Position = pos, AnchorPoint = anchor or Vector2.zero }, parent)
	local shadow = new("Frame", { Name = "Shadow", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 5), ZIndex = 1 }, holder)
	corner(shadow)
	local face = new(className, {
		Name = "Face",
		BackgroundColor3 = color,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		AutoButtonColor = if className == "TextButton" then false else nil,
	}, holder)
	if className == "TextButton" then
		face.Text = ""
	end
	corner(face)
	stroke(face, 3)
	shade(face)
	new("UIScale", { Name = "Press" }, holder)
	return holder, face
end
Hud.Block = block

-- 3D icon: a ViewportFrame with a small model.
local function viewport(parent: Instance, name: string, size: UDim2, pos: UDim2, build: (Model) -> (), camPos: Vector3, lookAt: Vector3, fov: number?): ViewportFrame
	local vf = new("ViewportFrame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = size,
		Position = pos,
		Ambient = Color3.fromRGB(190, 190, 200),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -2, -1.5),
		ZIndex = 4,
	}, parent)
	local model = new("Model", { Name = "Icon" }, nil)
	build(model)
	model.Parent = vf
	local cam = new("Camera", { Name = "Cam", FieldOfView = fov or 30, CFrame = CFrame.lookAt(camPos, lookAt) }, vf)
	vf.CurrentCamera = cam
	return vf
end
Hud.Viewport = viewport

local function pieceIcon(kind: string, color: Color3, trim: Color3?): (Model) -> ()
	return function(m: Model)
		local p = Models.Piece(kind, color, 1, CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(200), 0), { trim = trim })
		for _, part in p:GetChildren() do
			part.Parent = m
		end
	end
end
Hud.PieceIcon = pieceIcon
local PIECE_CAM, PIECE_LOOK = Vector3.new(0, 4.6, -14), Vector3.new(0, 3.1, 0)

local function trophy(m: Model)
	local g = C.gold
	Models.Cyl(m, "Base", 3.2, 0.7, CFrame.new(0, 0.35, 0), Color3.fromRGB(150, 90, 40))
	Models.Cyl(m, "Stem", 0.9, 1.6, CFrame.new(0, 1.5, 0), g)
	Models.Cyl(m, "Cup", 3.6, 2.4, CFrame.new(0, 3.4, 0), g)
	Models.Cyl(m, "Rim", 4.0, 0.4, CFrame.new(0, 4.7, 0), Color3.fromRGB(255, 225, 110))
	Models.Part(m, "HandleL", Vector3.new(0.6, 1.8, 0.6), CFrame.new(-2.2, 3.6, 0), g)
	Models.Part(m, "HandleR", Vector3.new(0.6, 1.8, 0.6), CFrame.new(2.2, 3.6, 0), g)
	-- a little crown cross on the front: chess trophy
	Models.Part(m, "CrossV", Vector3.new(0.4, 1.3, 0.3), CFrame.new(0, 3.4, -1.85), Color3.fromRGB(255, 245, 200))
	Models.Part(m, "CrossH", Vector3.new(1.0, 0.35, 0.3), CFrame.new(0, 3.6, -1.85), Color3.fromRGB(255, 245, 200))
end

local function gateIcon(m: Model)
	local r = C.red
	Models.Part(m, "LegL", Vector3.new(1, 5, 1), CFrame.new(-2.4, 2.5, 0), r)
	Models.Part(m, "LegR", Vector3.new(1, 5, 1), CFrame.new(2.4, 2.5, 0), r)
	Models.Part(m, "Beam", Vector3.new(6.2, 1.4, 1.2), CFrame.new(0, 5.4, 0), r)
	for i = 0, 3 do
		Models.Part(m, "Tile", Vector3.new(1, 0.3, 1), CFrame.new(-1.5 + i, 0.15, 0), if i % 2 == 0 then C.ivory else Color3.fromRGB(60, 62, 72))
	end
end

local function powerIcon(m: Model)
	pieceIcon("Pawn", C.green, Color3.fromRGB(240, 255, 200))(m)
	-- lightning chip on the chest
	Models.Part(m, "Bolt1", Vector3.new(0.5, 1.4, 0.3), CFrame.new(0.2, 2.6, -1.0) * CFrame.Angles(0, 0, math.rad(-25)), C.gold)
	Models.Part(m, "Bolt2", Vector3.new(0.5, 1.4, 0.3), CFrame.new(-0.1, 1.7, -1.0) * CFrame.Angles(0, 0, math.rad(-25)), C.gold)
end

-- Gear and retry glyphs from frames (flat, same outline weight).
local function gear(parent: Instance, size: number): Frame
	local f = new("Frame", { Name = "Gear", BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), ZIndex = 4 }, parent)
	for i = 0, 3 do
		local tooth = new("Frame", { BackgroundColor3 = C.ivory, Size = UDim2.new(0.26, 0, 1, 0), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Rotation = i * 45, ZIndex = 4 }, f)
		corner(tooth, 4)
		stroke(tooth, 2.5)
	end
	local ring = new("Frame", { BackgroundColor3 = C.ivory, Size = UDim2.fromScale(0.72, 0.72), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 5 }, f)
	corner(ring, 999)
	stroke(ring, 2.5)
	local hole = new("Frame", { BackgroundColor3 = C.grey, Size = UDim2.fromScale(0.34, 0.34), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 6 }, f)
	corner(hole, 999)
	stroke(hole, 2.5)
	return f
end

local function retryGlyph(parent: Instance, size: number): Frame
	local f = new("Frame", { Name = "RetryIcon", BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), ZIndex = 4 }, parent)
	local ring = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(0.8, 0.8), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 4 }, f)
	corner(ring, 999)
	new("UIStroke", { Thickness = 6, Color = WHITE }, ring)
	local gap = new("Frame", { BackgroundColor3 = C.red, BorderSizePixel = 0, Size = UDim2.fromScale(0.3, 0.22), Position = UDim2.fromScale(0.62, 0.0), ZIndex = 5 }, f)
	local _ = gap
	local tip = new("Frame", { BackgroundColor3 = WHITE, Size = UDim2.fromScale(0.3, 0.3), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.72, 0.14), Rotation = 45, ZIndex = 6 }, f)
	stroke(tip, 2)
	return f
end
Hud.Retry = retryGlyph

local function button(parent: Instance, name: string, color: Color3, size: UDim2, pos: UDim2, label: string, textSize: number, anchor: Vector2?): (Frame, TextButton, TextLabel)
	local holder, face = block(parent, name, "TextButton", color, size, pos, anchor)
	local t = text(face, "Label", { Text = label, TextSize = textSize, Size = UDim2.fromScale(1, 1), ZIndex = 5 })
	return holder, face, t
end
Hud.Button = button

---------------------------------------------------------------------------
function Hud.Build(config: any): ScreenGui
	local gui = new("ScreenGui", {
		Name = "ChessHUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = false,
		DisplayOrder = 0,
	}, nil)
	new("UIScale", { Name = "Scale" }, gui)

	-- Left rail -----------------------------------------------------------------
	local rail = new("Frame", { Name = "Rail", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 10), Size = UDim2.fromOffset(214, 330) }, gui)
	local winsHolder, winsFace = block(rail, "Wins", "Frame", Color3.fromRGB(60, 50, 30), UDim2.fromOffset(214, 66), UDim2.fromOffset(0, 0))
	winsFace.BackgroundTransparency = 0.25
	viewport(winsFace, "Icon", UDim2.fromOffset(70, 70), UDim2.fromOffset(-6, -6), trophy, Vector3.new(0, 4.2, -11), Vector3.new(0, 2.6, 0), 34)
	text(winsFace, "Value", { Text = "0", TextSize = 42, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(66, 0), Size = UDim2.new(1, -72, 1, 0), ZIndex = 5, StrokeThickness = 3 })
	local _w = winsHolder
	local stageHolder, stageFace = block(rail, "Stage", "Frame", Color3.fromRGB(50, 40, 40), UDim2.fromOffset(214, 40), UDim2.fromOffset(0, 74))
	stageFace.BackgroundTransparency = 0.25
	text(stageFace, "Value", { Text = "Stage 1 · Pawn Rival", TextSize = 20, Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(6, 0), ZIndex = 5 })
	local _s = stageHolder
	local setsHolder, setsFace, setsLabel = button(rail, "SetsButton", C.cyan, UDim2.fromOffset(214, 76), UDim2.fromOffset(0, 124), "Chess Sets", 30)
	setsLabel.Position = UDim2.fromOffset(30, 0)
	viewport(setsFace, "Icon", UDim2.fromOffset(78, 82), UDim2.fromOffset(-14, -12), pieceIcon("Knight", Color3.fromRGB(236, 240, 246), C.cyan), PIECE_CAM, PIECE_LOOK, 30)
	local _sh = setsHolder
	local boardHolder, boardFace, boardLabel = button(rail, "BoardButton", C.orange, UDim2.fromOffset(103, 92), UDim2.fromOffset(0, 210), "Board Run", 18)
	boardLabel.Size = UDim2.new(1, 0, 0, 26)
	boardLabel.Position = UDim2.new(0, 0, 1, -28)
	viewport(boardFace, "Icon", UDim2.fromOffset(70, 64), UDim2.new(0.5, -35, 0, 2), gateIcon, Vector3.new(4, 5, -12), Vector3.new(0, 2.8, 0), 36)
	local _b = boardHolder
	local settingsHolder, settingsFace, settingsLabel = button(rail, "SettingsButton", C.grey, UDim2.fromOffset(103, 92), UDim2.fromOffset(111, 210), "Settings", 18)
	settingsLabel.Size = UDim2.new(1, 0, 0, 26)
	settingsLabel.Position = UDim2.new(0, 0, 1, -28)
	gear(settingsFace, 46)
	local _st = settingsHolder

	-- Bottom centre: Power, progress / battle meter, context line -----------
	local bottom = new("Frame", { Name = "Bottom", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(640, 168) }, gui)
	local power = new("Frame", { Name = "Power", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 64), Position = UDim2.fromOffset(0, 0) }, bottom)
	new("UIScale", { Name = "Bump" }, power)
	local powerRow = new("Frame", { Name = "Row", BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0) }, power)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, powerRow)
	local pIcon = viewport(powerRow, "Icon", UDim2.fromOffset(62, 66), UDim2.new(), powerIcon, PIECE_CAM, PIECE_LOOK, 30)
	pIcon.LayoutOrder = 1
	text(powerRow, "Value", { Text = "0 Power", TextSize = 54, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 2, StrokeThickness = 4 })
	text(power, "Gain", { Text = "+1", TextSize = 34, TextColor3 = Color3.fromRGB(140, 255, 120), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, -110, 0.5, -26), Size = UDim2.fromOffset(120, 40), TextTransparency = 1, StrokeThickness = 3 })

	-- progress bar to the next rival
	local barHolder = new("Frame", { Name = "Progress", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 46), Position = UDim2.fromOffset(0, 70) }, bottom)
	local barShadow = new("Frame", { Name = "Shadow", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 5) }, barHolder)
	corner(barShadow, 14)
	local bar = new("Frame", { Name = "Bar", BackgroundColor3 = Color3.fromRGB(38, 40, 56), Size = UDim2.fromScale(1, 1), ClipsDescendants = false }, barHolder)
	corner(bar, 14)
	stroke(bar, 4)
	local fill = new("Frame", { Name = "Fill", BackgroundColor3 = C.green, Size = UDim2.fromScale(0.3, 1) }, bar)
	corner(fill, 14)
	shade(fill)
	-- checker trim strip along the top of the bar (selective ivory/charcoal)
	local trim = new("Frame", { Name = "Checker", BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 6), Position = UDim2.fromOffset(12, 4), ZIndex = 3 }, bar)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder }, trim)
	for i = 1, 40 do
		new("Frame", { BackgroundColor3 = if i % 2 == 0 then C.ivory else Color3.fromRGB(50, 52, 64), BackgroundTransparency = 0.55, BorderSizePixel = 0, Size = UDim2.new(1 / 40, 0, 1, 0), LayoutOrder = i, ZIndex = 3 }, trim)
	end
	text(bar, "Label", { Text = "Pawn Rival · 0 / 25 Power", TextSize = 26, Size = UDim2.fromScale(1, 1), ZIndex = 4, StrokeThickness = 3 })

	-- battle meter (hidden until a fight): player (green, left) vs rival (red, right)
	local meter = new("Frame", { Name = "Meter", BackgroundTransparency = 1, Visible = false, Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 66) }, bottom)
	local mShadow = new("Frame", { Name = "Shadow", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 5) }, meter)
	corner(mShadow, 16)
	local mBar = new("Frame", { Name = "Bar", BackgroundColor3 = C.red, Size = UDim2.fromScale(1, 1) }, meter)
	corner(mBar, 16)
	stroke(mBar, 4)
	shade(mBar)
	local mFill = new("Frame", { Name = "Fill", BackgroundColor3 = C.green, Size = UDim2.fromScale(0.5, 1) }, mBar)
	corner(mFill, 16)
	shade(mFill)
	new("Frame", { Name = "Mid", BackgroundColor3 = WHITE, BackgroundTransparency = 0.3, Size = UDim2.new(0, 4, 1, -8), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 }, mBar)
	local knob = new("Frame", { Name = "Knob", BackgroundColor3 = WHITE, Size = UDim2.fromOffset(18, 70), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 5 }, mBar)
	corner(knob, 8)
	stroke(knob, 3)
	text(mBar, "You", { Text = "YOU", TextSize = 26, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(0.5, -16, 1, 0), ZIndex = 4, StrokeThickness = 3 })
	text(mBar, "Rival", { Text = "PAWN RIVAL", TextSize = 26, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, -16, 1, 0), ZIndex = 4, StrokeThickness = 3 })
	text(meter, "Hint", { Text = "Keep clicking!", TextSize = 30, TextColor3 = Color3.fromRGB(255, 230, 90), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, 14, 0.5, 0), Size = UDim2.fromOffset(190, 40), TextXAlignment = Enum.TextXAlignment.Left, Visible = false, StrokeThickness = 3 })
	text(meter, "Timer", { Text = "16", TextSize = 24, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -2), Size = UDim2.fromOffset(80, 28) })

	text(bottom, "Context", { Text = "", TextSize = 24, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 126), TextColor3 = Color3.fromRGB(230, 255, 220) })

	-- Badge slot above the meter (one prominent badge at a time)
	local badge = new("Frame", { Name = "Badge", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -6), Size = UDim2.fromOffset(300, 74), Visible = false }, bottom)
	new("UIScale", { Name = "Pop" }, badge)
	local disc = new("Frame", { Name = "Disc", BackgroundColor3 = C.green, Size = UDim2.fromOffset(66, 66), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), ZIndex = 6 }, badge)
	corner(disc, 999)
	stroke(disc, 4)
	text(disc, "Glyph", { Text = "!!", TextSize = 36, Size = UDim2.fromScale(1, 1), ZIndex = 7, StrokeThickness = 3 })
	text(badge, "Label", { Text = "Brilliant", TextSize = 40, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(76, 0), Size = UDim2.new(1, -76, 1, 0), ZIndex = 6, StrokeThickness = 4 })
	local ring = new("Frame", { Name = "Ring", BackgroundTransparency = 1, Size = UDim2.fromOffset(66, 66), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(33, 37), ZIndex = 5, Visible = false }, badge)
	corner(ring, 999)
	new("UIStroke", { Thickness = 6, Color = Color3.fromRGB(30, 215, 200) }, ring)
	BadgeArt.Paint(disc, "Brilliant", config.BadgeLook.Brilliant)
	-- 1v1 duel layer (VS cards, combo, sparks, danger edges): hidden until a fight
	DuelHud.Build(bottom, gui)
	-- vault feel pieces: Level chip, Level Up line, confetti layer, big-moment layer
	FeelKit.Build(gui)

	-- Main action button (TRAIN / CHALLENGE / CLICK TO WIN): fixed position, bottom right
	local mainHolder, mainFace, mainLabel = button(gui, "MainButton", C.green, UDim2.fromOffset(236, 112), UDim2.new(1, -22, 1, -22), "TRAIN", 46, Vector2.new(1, 1))
	mainLabel.Size = UDim2.new(1, 0, 0.66, 0)
	text(mainFace, "Sub", { Text = "+1 per tap", TextSize = 22, Size = UDim2.new(1, 0, 0.34, 0), Position = UDim2.fromScale(0, 0.62), ZIndex = 5 })
	new("UIGradient", { Name = "Shine", Rotation = 20, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 1),
	}), Offset = Vector2.new(-1, 0) }, new("Frame", { Name = "ShineFx", BackgroundColor3 = WHITE, BackgroundTransparency = 0, Size = UDim2.fromScale(1, 1), ZIndex = 6 }, mainFace))
	corner(mainFace:FindFirstChild("ShineFx") :: Instance)
	mainHolder.Visible = false
	text(gui, "KeyHint", { Text = "", TextSize = 18, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -22, 1, -138), Size = UDim2.fromOffset(236, 22), TextColor3 = Color3.fromRGB(230, 230, 240) })

	-- Message line + guide (top centre) -----------------------------------------
	text(gui, "Message", { Text = "", TextSize = 30, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52), Size = UDim2.fromOffset(900, 36), TextTransparency = 1, StrokeThickness = 3 })
	local guideHolder, guideFace = block(gui, "Guide", "Frame", Color3.fromRGB(40, 36, 70), UDim2.fromOffset(520, 46), UDim2.new(0.5, 0, 0, 8), Vector2.new(0.5, 0))
	guideFace.BackgroundTransparency = 0.15
	text(guideFace, "Step", { Text = "1/4", TextSize = 22, TextColor3 = C.gold, Size = UDim2.fromOffset(60, 46), ZIndex = 5 })
	text(guideFace, "Text", { Text = "Walk onto the Pawn Mill and tap TRAIN", TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(60, 0), Size = UDim2.new(1, -70, 1, 0), ZIndex = 5 })
	local _g = guideHolder

	-- Dim layer behind panels ------------------------------------------------------
	new("Frame", { Name = "Dim", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, Size = UDim2.new(1, 0, 1, 60), Position = UDim2.fromOffset(0, -60), Visible = false, ZIndex = 20, Active = true }, gui)

	-- Panel helper: floating title, close button ------------------------------------
	local function panel(name: string, title: string, color: Color3, size: Vector2): Frame
		local holder, face = block(gui, name, "Frame", C.panel, UDim2.fromOffset(size.X, size.Y), UDim2.fromScale(0.5, 0.52), Vector2.new(0.5, 0.5))
		holder.Visible = false
		holder.ZIndex = 30
		for _, d in holder:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex += 30
			end
		end
		face.BackgroundTransparency = 0.08
		local titleHolder, titleFace = block(face, "Title", "Frame", color, UDim2.fromOffset(300, 56), UDim2.new(0.5, 0, 0, -30), Vector2.new(0.5, 0))
		for _, d in titleHolder:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex += 34
			end
		end
		text(titleFace, "Label", { Text = title, TextSize = 34, Size = UDim2.fromScale(1, 1), ZIndex = 40, StrokeThickness = 3 })
		local closeHolder, closeFace = button(face, "Close", C.red, UDim2.fromOffset(52, 52), UDim2.new(1, 14, 0, -14), "X", 30, Vector2.new(1, 0))
		for _, d in closeHolder:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex += 36
			end
		end
		local _c = closeFace
		new("UIScale", { Name = "Open" }, holder)
		return face
	end

	-- Chess Sets ------------------------------------------------------------------
	local sets = panel("SetsPanel", "Chess Sets", C.cyan, Vector2.new(880, 520))
	local grid = new("ScrollingFrame", { Name = "Grid", BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 44), Size = UDim2.new(1, -360, 1, -64), ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 33 }, sets)
	new("UIGridLayout", { CellSize = UDim2.fromOffset(118, 150), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, grid)
	-- card template (the client clones it for each set)
	local cardHolder, cardFace = block(sets, "CardTemplate", "TextButton", C.cyan, UDim2.fromOffset(118, 150), UDim2.new(), nil)
	cardHolder.Visible = false
	text(cardFace, "NameText", { Text = "Marble", TextSize = 20, Size = UDim2.new(1, -8, 0, 24), Position = UDim2.new(0, 4, 1, -50), ZIndex = 36 })
	text(cardFace, "State", { Text = "8 Wins", TextSize = 18, TextColor3 = C.gold, Size = UDim2.new(1, -8, 0, 22), Position = UDim2.new(0, 4, 1, -26), ZIndex = 36 })
	text(cardFace, "Mult", { Text = "x2", TextSize = 20, TextColor3 = Color3.fromRGB(150, 255, 140), Size = UDim2.fromOffset(44, 24), Position = UDim2.fromOffset(4, 4), ZIndex = 36, TextXAlignment = Enum.TextXAlignment.Left })
	local lock = new("Frame", { Name = "Lock", BackgroundTransparency = 1, Size = UDim2.fromOffset(34, 38), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), ZIndex = 37, Visible = false }, cardFace)
	local shackle = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(6, 0), ZIndex = 37 }, lock)
	corner(shackle, 999)
	new("UIStroke", { Thickness = 5, Color = C.gold }, shackle)
	local body = new("Frame", { BackgroundColor3 = C.gold, Size = UDim2.fromOffset(34, 24), Position = UDim2.fromOffset(0, 14), ZIndex = 38 }, lock)
	corner(body, 6)
	stroke(body, 2.5)
	local _cf = cardFace
	for _, d in cardHolder:GetDescendants() do
		if d:IsA("GuiObject") and d.ZIndex < 33 then
			d.ZIndex += 32
		end
	end
	-- selected preview
	local preview = new("Frame", { Name = "Preview", BackgroundColor3 = Color3.fromRGB(30, 32, 48), BackgroundTransparency = 0.2, Position = UDim2.new(1, -330, 0, 44), Size = UDim2.new(0, 310, 1, -64), ZIndex = 33 }, sets)
	corner(preview, 14)
	stroke(preview, 3)
	local pv = viewport(preview, "Viewport", UDim2.new(1, 0, 0, 190), UDim2.fromOffset(0, 4), pieceIcon("Knight", Color3.fromRGB(236, 240, 246), C.cyan), Vector3.new(0, 4.4, -11), Vector3.new(0, 3, 0), 34)
	pv.ZIndex = 34
	text(preview, "NameText", { Text = "Marble Set", TextSize = 32, Position = UDim2.fromOffset(0, 196), Size = UDim2.new(1, 0, 0, 36), ZIndex = 35 })
	text(preview, "Mult", { Text = "x2 Power per tap", TextSize = 22, TextColor3 = Color3.fromRGB(150, 255, 140), Position = UDim2.fromOffset(0, 232), Size = UDim2.new(1, 0, 0, 26), ZIndex = 35 })
	text(preview, "Change", { Text = "Pawn Mill: +1 → +2 per tap", TextSize = 20, TextColor3 = Color3.fromRGB(200, 240, 255), Position = UDim2.fromOffset(6, 260), Size = UDim2.new(1, -12, 0, 26), ZIndex = 35, TextWrapped = true })
	local actionHolder, actionFace, actionLabel = button(preview, "Action", C.green, UDim2.new(1, -40, 0, 66), UDim2.new(0.5, 0, 1, -16), "Buy · 8 Wins", 28, Vector2.new(0.5, 1))
	for _, d in actionHolder:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex += 34
		end
	end
	local _a, _al = actionFace, actionLabel

	-- Board Run --------------------------------------------------------------------
	local board = panel("BoardPanel", "Board Run", C.orange, Vector2.new(640, 470))
	local list = new("ScrollingFrame", { Name = "List", BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 44), Size = UDim2.new(1, -40, 1, -64), ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 33 }, board)
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }, list)
	local rowHolder, rowFace = block(board, "RowTemplate", "Frame", Color3.fromRGB(60, 64, 88), UDim2.new(1, -16, 0, 100), UDim2.new(), nil)
	rowHolder.Visible = false
	text(rowFace, "Number", { Text = "1", TextSize = 44, TextColor3 = C.gold, Size = UDim2.fromOffset(60, 100), ZIndex = 36, StrokeThickness = 3 })
	local rv = viewport(rowFace, "Rival", UDim2.fromOffset(80, 92), UDim2.fromOffset(56, 4), pieceIcon("Pawn", Models.CHARCOAL, C.red), PIECE_CAM, PIECE_LOOK, 30)
	rv.ZIndex = 36
	text(rowFace, "NameText", { Text = "Pawn Rival", TextSize = 28, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(144, 8), Size = UDim2.fromOffset(260, 32), ZIndex = 36 })
	text(rowFace, "Info", { Text = "25 Power · +10 Wins", TextSize = 20, TextColor3 = Color3.fromRGB(220, 230, 255), TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(144, 42), Size = UDim2.fromOffset(300, 24), ZIndex = 36 })
	text(rowFace, "Unlock", { Text = "", TextSize = 18, TextColor3 = Color3.fromRGB(120, 220, 255), TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(144, 68), Size = UDim2.fromOffset(300, 22), ZIndex = 36 })
	local statusHolder, statusFace = block(rowFace, "Status", "Frame", C.green, UDim2.fromOffset(130, 54), UDim2.new(1, -12, 0.5, 0), Vector2.new(1, 0.5))
	text(statusFace, "Label", { Text = "READY", TextSize = 24, Size = UDim2.fromScale(1, 1), ZIndex = 38 })
	local _sf = statusHolder
	for _, d in rowHolder:GetDescendants() do
		if d:IsA("GuiObject") and d.ZIndex < 33 then
			d.ZIndex += 32
		end
	end

	-- Battle result ------------------------------------------------------------------
	local result = panel("ResultPanel", "Victory!", C.gold, Vector2.new(480, 360))
	local rr = viewport(result, "Rival", UDim2.fromOffset(150, 150), UDim2.new(0.5, -75, 0, 34), pieceIcon("Pawn", Models.CHARCOAL, C.red), PIECE_CAM, PIECE_LOOK, 30)
	rr.ZIndex = 34
	text(result, "Line1", { Text = "Pawn Rival defeated", TextSize = 28, Position = UDim2.fromOffset(0, 186), Size = UDim2.new(1, 0, 0, 32), ZIndex = 35 })
	text(result, "Line2", { Text = "+10 Wins", TextSize = 36, TextColor3 = C.gold, Position = UDim2.fromOffset(0, 220), Size = UDim2.new(1, 0, 0, 40), ZIndex = 35, StrokeThickness = 3 })
	local primaryHolder, primaryFace, primaryLabel = button(result, "Primary", C.green, UDim2.fromOffset(250, 66), UDim2.new(0.5, -60, 1, -18), "Buy Marble", 28, Vector2.new(0.5, 1))
	local secondaryHolder, secondaryFace, secondaryLabel = button(result, "Secondary", C.grey, UDim2.fromOffset(150, 56), UDim2.new(0.5, 150, 1, -22), "Close", 24, Vector2.new(0.5, 1))
	for _, h in { primaryHolder, secondaryHolder } do
		for _, d in h:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex += 34
			end
		end
	end
	local _p = { primaryFace, primaryLabel, secondaryFace, secondaryLabel }
	retryGlyph(primaryFace, 40).Visible = false

	-- Settings ---------------------------------------------------------------------
	local settings = panel("SettingsPanel", "Settings", C.grey, Vector2.new(440, 310))
	for i, row in { { "Music", "Music" }, { "Sound", "Sound effects" }, { "Reduced", "Reduced effects" } } do
		local r = new("Frame", { Name = row[1], BackgroundTransparency = 1, Position = UDim2.fromOffset(30, 50 + (i - 1) * 76), Size = UDim2.new(1, -60, 0, 64), ZIndex = 33 }, settings)
		text(r, "Label", { Text = row[2], TextSize = 28, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -140, 1, 0), ZIndex = 34 })
		local tHolder, tFace = button(r, "Toggle", C.green, UDim2.fromOffset(120, 54), UDim2.new(1, 0, 0.5, 0), "ON", 26, Vector2.new(1, 0.5))
		for _, d in tHolder:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex += 34
			end
		end
		local _t = tFace
	end

	-- Pop-up for coalesced world gains / toasts (client fills)
	text(gui, "Toast", { Text = "", TextSize = 34, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(700, 44), TextTransparency = 1, StrokeThickness = 4, ZIndex = 50 })
	return gui
end

return Hud
