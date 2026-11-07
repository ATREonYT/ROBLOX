--!strict
-- +1 Chess Evolution: builds the ChessHUD ScreenGui (run by tools/build_place.luau, saved to
-- src/StarterGui/ChessHUD.rbxm so the owner can see and edit it in Studio; the client reuses these parts).
-- Layout: copied from the long reference recording (measured at 1512 x 861 points, so 1 design unit = 1 point there).
-- Look: studded slabs, black outlines, burning colours, white Fredoka One with a heavy outline (Folk Stud rules).
-- Icons: our own glossy art (assets/hud-icons, drawn by tools/make_hud_icons.py).

local Models = require(script.Parent:WaitForChild("Models"))
local DuelHud = require(script.Parent:WaitForChild("DuelHud"))
local BadgeArt = require(script.Parent:WaitForChild("BadgeArt"))
local FeelKit = require(script.Parent:WaitForChild("FeelKit"))

local Hud = {}
Hud.RailX, Hud.RailY = 25, 0.476 -- left grid, shared with ChessLoop so both sets of squares line up

local FONT = Font.fromEnum(Enum.Font.FredokaOne)
local INK = Color3.fromRGB(16, 14, 22)
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
	slabRed = Color3.fromRGB(240, 32, 56),
	slabBlue = Color3.fromRGB(28, 176, 255),
	slabPink = Color3.fromRGB(250, 40, 200),
	slabGold = Color3.fromRGB(255, 208, 30),
	slabGreen = Color3.fromRGB(110, 240, 60),
	slabGrey = Color3.fromRGB(74, 78, 86),
	priceGreen = Color3.fromRGB(120, 255, 70),
}
Hud.Colors = C

-- Uploaded icon images, one per file in assets/hud-icons.
Hud.Icons = {
	arrow = "rbxassetid://123693844646821",
	calendar = "rbxassetid://75173533368410",
	check = "rbxassetid://111489647581391",
	crown = "rbxassetid://132665288523989",
	cursor = "rbxassetid://126394085493872",
	evolve = "rbxassetid://97947776861130",
	gear = "rbxassetid://96418692338482",
	gift = "rbxassetid://74769477753636",
	lock = "rbxassetid://73571572847118",
	power = "rbxassetid://126951566723057",
	promote = "rbxassetid://114267223482724",
	smile = "rbxassetid://130000267549633",
	trophy = "rbxassetid://92674975310556",
	wheel = "rbxassetid://127985229803226",
}
Hud.StudImage = "rbxassetid://3014551673"
Hud.Robux = utf8.char(0xE002)

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
	new("UIStroke", { Thickness = thickness or 3.5, Color = color or INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
end

local function shade(parent: Instance)
	-- subtle top highlight: lighter top, slightly darker bottom
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(245, 245, 245)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(215, 215, 215)),
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
	-- Bevel joins keep the holes in O and 0 open under a thick outline (Folk Stud rule)
	new("UIStroke", { Thickness = props.StrokeThickness or 3, Color = INK, LineJoinMode = Enum.LineJoinMode.Bevel, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Name = "Outline" }, t)
	t.Parent = parent
	return t
end
Hud.Text = text

-- Stud pattern over a slab face. The texture holds 2 x 2 studs, so a 48 tile is a 24 stud step.
local function studs(face: Instance, transparency: number?): ImageLabel
	local img = new("ImageLabel", {
		Name = "Studs",
		BackgroundTransparency = 1,
		Image = Hud.StudImage,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(48, 48),
		ImageTransparency = transparency or 0.55,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
	}, face)
	corner(img)
	return img
end
Hud.Studs = studs

-- Fits an icon inside a box. It draws above the slab face and below the slab's words.
local function icon(parent: Instance, name: string, key: string, size: UDim2, pos: UDim2, zindex: number?, anchor: Vector2?): ImageLabel
	return new("ImageLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Image = Hud.Icons[key] or "",
		ScaleType = Enum.ScaleType.Fit,
		Size = size,
		Position = pos,
		AnchorPoint = anchor or Vector2.zero,
		ZIndex = zindex or 4,
	}, parent)
end
Hud.Icon = icon

-- The rainbow face used on the top offers (replaces the plain shade).
local function rainbow(face: Instance)
	(face :: any).BackgroundColor3 = WHITE
	local old = face:FindFirstChildOfClass("UIGradient")
	if old then
		old:Destroy()
	end
	new("UIGradient", {
		Name = "Rainbow",
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 30)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(70, 230, 80)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(30, 170, 255)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(170, 60, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 40, 170)),
		}),
	}, face)
end
Hud.Rainbow = rainbow

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
	stroke(face)
	shade(face)
	studs(face)
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
-- Reference colours, sampled from the long recording's pixels. Change a slab's look here.
-- Each entry runs top to bottom (or left to right for the rainbow).
---------------------------------------------------------------------------
Hud.Palette = {
	red = { "#FF3A50", "#E81830", "#D8102A" },
	evolve = { "#39FFEC", "#3FECEA", "#1A9BD4" },
	pink = { "#FF71F7", "#F24FE8", "#E438DC" },
	white = { "#FFFFFF", "#E0E2E1", "#B2B2B0" },
	lemon = { "#F8F238", "#F8DD36", "#F8BC20" },
	gold = { "#F8F045", "#E9C622", "#F6AE1B" },
	goldDeep = { "#FBF966", "#F8D12C", "#E69C1F" },
	cyan = { "#0FEFFB", "#0CD3FA", "#09B2F7" },
	lime = { "#C4FF7E", "#AEFF69", "#8CF040" },
	go = { "#B4FF3A", "#7CF02A", "#3EDC1F" },
	grey = { "#5A5A5A", "#4B4B4B", "#3C3C3C" },
	purple = { "#C81CFF", "#B300FD", "#9D00D0" },
	blueCard = { "#39ECEC", "#1FB4EA", "#1A80E0" },
	rainbow = { "#E44605", "#C0CC08", "#9CFA1D", "#1B8CE0", "#BD00F0", "#E800CE", "#FF1D7D" },
}

function Hud.Paint(face: any, key: string, rotation: number?)
	local stops = Hud.Palette[key]
	local keys = {}
	for i, hex in stops do
		keys[i] = ColorSequenceKeypoint.new((i - 1) / (#stops - 1), Color3.fromHex(hex))
	end
	face.BackgroundColor3 = WHITE
	local g = face:FindFirstChildOfClass("UIGradient")
	if not g then
		g = new("UIGradient", {}, face)
	end
	g.Color = ColorSequence.new(keys)
	g.Rotation = rotation or 90
end

-- Soft studs and no drop shadows everywhere, as in the reference.
function Hud.Soften(root: Instance)
	for _, d in root:GetDescendants() do
		if d.Name == "Studs" and d:IsA("ImageLabel") then
			d.ImageTransparency = 0.72
		elseif d.Name == "Shadow" and d:IsA("Frame") then
			d.Visible = false
		end
	end
end

function Hud.Theme(gui: any)
	local P = Hud.Paint
	P(gui.Rail.SetsButton.Face, "evolve")
	P(gui.TopBar.AutoWins.Face, "gold")
	P(gui.TopBar.AutoTrain.Face, "rainbow", 0)
	P(gui.RightOffers.Offer1.Face, "rainbow", 0)
	P(gui.RightOffers.Offer2.Face, "goldDeep")
	P(gui.Bottom.Buy.Pack1.Face, "red")
	P(gui.Bottom.Buy.Pack2.Face, "cyan")
	P(gui.Bottom.Buy.Pack3.Face, "rainbow", 0)
	P(gui.Bottom.Buy.PackMore.Face, "lime")
	P(gui.Bottom.Clicker.OpClicker.Face, "rainbow", 0)
	P(gui.Bottom.Clicker.FreeClicker.Face, "grey")
	P(gui.Invite.Face.Plus.Face, "purple")
	P(gui.Bottom.Progress.Level.Face, "lime")
	local bar = gui.Bottom.Progress.Bar
	bar.BackgroundColor3 = Color3.new(0, 0, 0)
	bar.BackgroundTransparency = 0.55
	bar.Fill.BackgroundColor3 = Color3.fromHex("#E21228")
	-- menus: see-through sheet, header flush with the top edge
	local heads = { SetsPanel = "cyan", BoardPanel = "gold", SettingsPanel = "grey", ResultPanel = false }
	for name, head in heads do
		local face = gui[name].Face
		face.BackgroundColor3 = Color3.new(0, 0, 0)
		face.BackgroundTransparency = 0.5
		local title = face.Title
		title.Size = UDim2.new(1, 0, 0, 70)
		title.Position = UDim2.new(0.5, 0, 0, 0)
		title.Face.Label.TextSize = 44
		if head then
			P(title.Face, head)
		end
		P(face.Close.Face, "red");
		(face.Close.Face:FindFirstChild("Studs") :: any).Visible = false
	end
	Hud.Soften(gui)
end

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
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets

	-- Left rail: counters, then the squares (ChessLoop adds Shop, Promote, Rewards and Daily in the same grid) -----
	local rail = new("Frame", { Name = "Rail", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, Hud.RailX, Hud.RailY, 0), Size = UDim2.fromOffset(205, 410) }, gui)
	local function counter(name: string, key: string, y: number, color: Color3)
		local holder = new("Frame", { Name = name, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(205, 56) }, rail)
		new("UIScale", { Name = "Press" }, holder)
		local f = new("Frame", { Name = "Face", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, holder)
		icon(f, "Icon", key, UDim2.fromOffset(58, 58), UDim2.fromOffset(0, -1))
		text(f, "Value", { Text = "0", TextSize = 40, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(64, 0), Size = UDim2.new(1, -64, 1, 0), ZIndex = 5, StrokeThickness = 3.5 })
	end
	counter("Wins", "trophy", 0, C.slabGold)
	counter("Promos", "promote", 63, Color3.fromRGB(255, 70, 80))
	-- the next rival's name stays as data for the client; the reference has no such row
	local stageHolder = new("Frame", { Name = "Stage", BackgroundTransparency = 1, Visible = false, Size = UDim2.fromOffset(1, 1) }, rail)
	local stageFace = new("Frame", { Name = "Face", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, stageHolder)
	text(stageFace, "Value", { Text = "", Size = UDim2.fromScale(1, 1) })
	local function square(name: string, label: string, color: Color3, x: number, y: number, key: string): (Frame, any)
		local h, f, l = button(rail, name, color, UDim2.fromOffset(97, 99), UDim2.fromOffset(x, y), label, 27)
		l.Size = UDim2.new(1, 8, 0, 32)
		l.Position = UDim2.new(0, -4, 1, -32)
		l.ZIndex = 6
		icon(f, "Icon", key, UDim2.fromOffset(84, 84), UDim2.new(0.5, 0, 0, 2), 4, Vector2.new(0.5, 0))
		return h, f
	end
	local _sets = square("SetsButton", "Evolve", C.slabBlue, 0, 203, "evolve")
	-- Board Run has no spot in the reference: the path itself leads to every rival. Kept for its panel.
	local boardHolder = square("BoardButton", "Board", C.orange, 0, 312, "crown")
	boardHolder.Visible = false

	-- Top centre: the two auto toggles ------------------------------------------
	local top = new("Frame", { Name = "TopBar", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(412, 84) }, gui)
	new("UIScale", { Name = "Press" }, top)
	local function toggle(name: string, label: string, x: number, key: string, size: number): any
		local h, f, l = button(top, name, C.slabGold, UDim2.fromOffset(198, 69), UDim2.fromOffset(x, 0), label, size)
		l.Size = UDim2.new(1, 0, 0, 40)
		l.Position = UDim2.fromOffset(0, 12)
		l.ZIndex = 6
		icon(f, "Icon", key, UDim2.fromOffset(50, 50), UDim2.new(0.5, 0, 0, -16), 4, Vector2.new(0.5, 0))
		text(h, "State", { Text = "OFF", TextSize = 30, TextColor3 = Color3.fromRGB(255, 50, 60), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 46), Size = UDim2.fromOffset(100, 34), ZIndex = 8, StrokeThickness = 3.5 })
		return f
	end
	toggle("AutoWins", "Auto Wins", 0, "trophy", 31)
	rainbow(toggle("AutoTrain", "Auto Train Here", 214, "crown", 25))

	-- The wheel beside the toggles, with the next free reward's countdown over it
	local wheelHolder, wheelFace = block(gui, "Wheel", "TextButton", WHITE, UDim2.fromOffset(100, 118), UDim2.new(0.5, 399, 0, 4), Vector2.new(0.5, 0))
	wheelFace.BackgroundTransparency = 1;
	(wheelHolder:FindFirstChild("Shadow") :: Frame).Visible = false;
	(wheelFace:FindFirstChildOfClass("UIStroke") :: UIStroke).Enabled = false;
	(wheelFace:FindFirstChild("Studs") :: ImageLabel).Visible = false
	icon(wheelFace, "Icon", "wheel", UDim2.fromOffset(100, 100), UDim2.fromOffset(0, 18))
	text(wheelFace, "Timer", { Text = "Spin", TextSize = 30, Position = UDim2.fromOffset(-20, -2), Size = UDim2.new(1, 40, 0, 32), ZIndex = 6, StrokeThickness = 3 })

	-- Settings: round gear, top right
	local settingsHolder, settingsFace = block(gui, "SettingsButton", "TextButton", Color3.fromRGB(26, 30, 40), UDim2.fromOffset(46, 46), UDim2.new(1, -8, 0, 11), Vector2.new(1, 0));
	(settingsHolder:FindFirstChild("Shadow") :: Frame).Visible = false;
	(settingsFace:FindFirstChild("Studs") :: ImageLabel).Visible = false
	settingsFace.BackgroundTransparency = 0.25;
	(settingsFace:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius = UDim.new(1, 0)
	icon(settingsFace, "Icon", "gear", UDim2.fromOffset(34, 34), UDim2.fromScale(0.5, 0.5), 4, Vector2.new(0.5, 0.5))

	-- Right side: free gift, then the two offers ----------------------------------
	local right = new("Frame", { Name = "RightOffers", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.378, 0), Size = UDim2.fromOffset(196, 382) }, gui)
	new("UIScale", { Name = "Press" }, right)
	local giftHolder, giftFace = block(right, "FreeGift", "TextButton", WHITE, UDim2.fromOffset(130, 116), UDim2.fromOffset(1, 0))
	giftFace.BackgroundTransparency = 1;
	(giftHolder:FindFirstChild("Shadow") :: Frame).Visible = false;
	(giftFace:FindFirstChildOfClass("UIStroke") :: UIStroke).Enabled = false;
	(giftFace:FindFirstChild("Studs") :: ImageLabel).Visible = false
	icon(giftFace, "Icon", "gift", UDim2.fromOffset(92, 92), UDim2.new(0.5, 0, 0, 0), 4, Vector2.new(0.5, 0))
	text(giftFace, "Label", { Text = "Free Gift!", TextSize = 26, Position = UDim2.fromOffset(0, 88), Size = UDim2.new(1, 0, 0, 28), ZIndex = 6, StrokeThickness = 3 })
	local function offer(name: string, y: number, label: string, key: string, color: Color3?): any
		local h, f, l = button(right, name, color or C.slabGold, UDim2.fromOffset(196, 67), UDim2.fromOffset(0, y), label, 29)
		l.Size = UDim2.new(1, 0, 0, 40)
		l.Position = UDim2.fromOffset(0, 12)
		l.ZIndex = 6
		icon(f, "Icon", key, UDim2.fromOffset(62, 62), UDim2.new(0.5, 0, 0, -8), 4, Vector2.new(0.5, 0))
		text(h, "Price", { Text = "", TextSize = 25, TextColor3 = C.priceGreen, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 46), Size = UDim2.fromOffset(180, 30), ZIndex = 8, StrokeThickness = 3 })
		return f
	end
	rainbow(offer("Offer1", 212, "2x Power", "power"))
	offer("Offer2", 315, "2x Wins", "trophy")

	-- Bottom left: Invite Friends
	local inviteHolder, inviteFace = block(gui, "Invite", "TextButton", WHITE, UDim2.fromOffset(270, 38), UDim2.new(0, 14, 1, -10), Vector2.new(0, 1))
	inviteFace.BackgroundTransparency = 1;
	(inviteHolder:FindFirstChild("Shadow") :: Frame).Visible = false;
	(inviteFace:FindFirstChildOfClass("UIStroke") :: UIStroke).Enabled = false;
	(inviteFace:FindFirstChild("Studs") :: ImageLabel).Visible = false
	icon(inviteFace, "Icon", "smile", UDim2.fromOffset(36, 36), UDim2.fromOffset(0, 1))
	text(inviteFace, "Label", { Text = "Invite Friends", TextSize = 31, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(38, 0), Size = UDim2.fromOffset(200, 38), ZIndex = 6, StrokeThickness = 3 })
	local _plus, plusFace, plusLabel = button(inviteFace, "Plus", C.purple, UDim2.fromOffset(32, 32), UDim2.fromOffset(226, 3), "+", 26)
	plusFace.Active = false
	plusLabel.ZIndex = 6;
	(plusFace:FindFirstChild("Studs") :: ImageLabel).Visible = false

	-- Bottom centre: Power, level bar, Power packs, auto clickers ----------------
	local bottom = new("Frame", { Name = "Bottom", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(682, 178) }, gui)
	local power = new("Frame", { Name = "Power", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48), Position = UDim2.fromOffset(0, 0) }, bottom)
	new("UIScale", { Name = "Bump" }, power)
	local powerRow = new("Frame", { Name = "Row", BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0) }, power)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, powerRow)
	local pIcon = icon(powerRow, "Icon", "power", UDim2.fromOffset(60, 48), UDim2.new())
	pIcon.LayoutOrder = 1
	text(powerRow, "Value", { Text = "0 Power", TextSize = 44, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 2, StrokeThickness = 3.5 })
	text(power, "Gain", { Text = "+1", TextSize = 34, TextColor3 = Color3.fromRGB(140, 255, 120), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, -110, 0.5, -26), Size = UDim2.fromOffset(120, 40), TextTransparency = 1, StrokeThickness = 3 });
	(power:FindFirstChild("Gain"):FindFirstChild("Outline") :: UIStroke).Transparency = 1

	-- level bar: red studded fill on a see-through dark track
	local barHolder = new("Frame", { Name = "Progress", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 53) }, bottom)
	local bar = new("Frame", { Name = "Bar", BackgroundColor3 = Color3.fromRGB(16, 40, 22), BackgroundTransparency = 0.35, Size = UDim2.fromScale(1, 1), ClipsDescendants = false }, barHolder)
	corner(bar, 5)
	stroke(bar, 4)
	local fill = new("Frame", { Name = "Fill", BackgroundColor3 = C.slabRed, Size = UDim2.fromScale(0.3, 1) }, bar)
	corner(fill, 5)
	stroke(fill, 3)
	studs(fill).ZIndex = 1
	text(bar, "Label", { Text = "Level 1", TextSize = 36, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(22, 0), Size = UDim2.new(0.6, 0, 1, 0), ZIndex = 4, StrokeThickness = 3.5 })
	text(bar, "Count", { Text = "0/0", TextSize = 34, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -32, 0, 0), Size = UDim2.new(0.5, 0, 1, 0), ZIndex = 4, StrokeThickness = 3.5 })

	-- Power packs (open the Shop)
	local buy = new("Frame", { Name = "Buy", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(0, 118) }, bottom)
	local function pack(name: string, x: number, label: string, color: Color3?, price: number): any
		local h, f, l = button(buy, name, color or WHITE, UDim2.fromOffset(192, 60), UDim2.fromOffset(x, 0), label, 24)
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Position = UDim2.fromOffset(60, 0)
		l.Size = UDim2.new(1, -62, 1, 0)
		l.ZIndex = 6
		icon(f, "Icon", "power", UDim2.fromOffset(52, 44), UDim2.fromOffset(6, 8))
		text(h, "Price", { Text = `{Hud.Robux} {price}`, TextSize = 24, TextColor3 = C.priceGreen, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(-10, -18), Size = UDim2.fromOffset(100, 28), ZIndex = 8, StrokeThickness = 3 })
		return f
	end
	local packs = (config.PowerPacks or {}) :: any
	local function packInfo(i: number): (string, number)
		local p = packs[i]
		return if p then p.label else "", if p then p.price else 0
	end
	local l1, r1 = packInfo(1)
	local l2, r2 = packInfo(2)
	local l3, r3 = packInfo(3)
	pack("Pack1", 9, l1, C.slabRed, r1)
	pack("Pack2", 211, l2, C.slabBlue, r2)
	rainbow(pack("Pack3", 413, l3, nil, r3))
	local _pp, ppFace, ppLabel = button(buy, "PackMore", C.slabGreen, UDim2.fromOffset(57, 60), UDim2.fromOffset(615, 0), "+", 44)
	ppLabel.ZIndex = 6
	local _ = ppFace

	-- Auto clicker pair, right of the bar
	local clicker = new("Frame", { Name = "Clicker", BackgroundTransparency = 1, Position = UDim2.fromOffset(694, 34), Size = UDim2.fromOffset(129, 144) }, bottom)
	local function clickerBtn(name: string, y: number, h: number, label: string, color: Color3?): any
		local holder, f = block(clicker, name, "TextButton", color or WHITE, UDim2.fromOffset(129, h), UDim2.fromOffset(0, y))
		icon(f, "Icon", "cursor", UDim2.fromOffset(58, 58), UDim2.new(0.5, 0, 0, -6), 4, Vector2.new(0.5, 0))
		text(holder, "Label", { Text = label, TextSize = 21, Position = UDim2.fromOffset(-16, -19), Size = UDim2.new(1, 32, 0, 26), ZIndex = 8, StrokeThickness = 2.5 })
		return f
	end
	rainbow(clickerBtn("OpClicker", 21, 50, "OP Auto Clicker"))
	local freeFace = clickerBtn("FreeClicker", 96, 48, "FREE Gift", C.slabGrey)
	text(freeFace, "Timer", { Text = "0:00", TextSize = 30, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 2), Size = UDim2.new(1, 0, 0, 34), ZIndex = 6, StrokeThickness = 3 })

	-- battle meter (hidden until a fight): player (green, left) vs rival (red, right)
	local meter = new("Frame", { Name = "Meter", BackgroundTransparency = 1, Visible = false, Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 53) }, bottom)
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
	text(meter, "Hint", { Text = "Keep clicking!", TextSize = 30, TextColor3 = Color3.fromRGB(255, 230, 90), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, 10, 0.5, 0), Size = UDim2.fromOffset(142, 40), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Visible = false, StrokeThickness = 3 })
	text(meter, "Timer", { Text = "16", TextSize = 24, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -2), Size = UDim2.fromOffset(80, 28) })

	text(bottom, "Context", { Text = "", TextSize = 24, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 126), TextColor3 = Color3.fromRGB(230, 255, 220), Visible = false })

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
	mainLabel.Size = UDim2.new(1, -16, 0.6, 0)
	mainLabel.Position = UDim2.new(0, 8, 0.04, 0)
	mainLabel.TextScaled = true
	new("UITextSizeConstraint", { MaxTextSize = 46 }, mainLabel)
	text(mainFace, "Sub", { Text = "+1 per tap", TextSize = 22, Size = UDim2.new(1, 0, 0.34, 0), Position = UDim2.fromScale(0, 0.62), ZIndex = 5 })
	new("UIGradient", { Name = "Shine", Rotation = 20, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 1),
	}), Offset = Vector2.new(-1, 0) }, new("Frame", { Name = "ShineFx", BackgroundColor3 = WHITE, BackgroundTransparency = 0, Size = UDim2.fromScale(1, 1), ZIndex = 6 }, mainFace))
	corner(mainFace:FindFirstChild("ShineFx") :: Instance)
	mainHolder.Visible = false
	text(gui, "KeyHint", { Text = "", TextSize = 18, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -22, 1, -138), Size = UDim2.fromOffset(236, 22), TextColor3 = Color3.fromRGB(230, 230, 240) })

	-- Message line + guide (top centre) -----------------------------------------
	text(gui, "Message", { Text = "", TextSize = 50, TextColor3 = Color3.fromRGB(255, 225, 40), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 112), Size = UDim2.fromOffset(1100, 60), TextTransparency = 1, StrokeThickness = 4 })
	-- Guide: plain words along the top, no plate (the toggles only appear once it is finished)
	local guideHolder = new("Frame", { Name = "Guide", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(760, 40) }, gui)
	local guideFace = new("Frame", { Name = "Face", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, guideHolder)
	text(guideFace, "Step", { Text = "1/4", TextSize = 28, TextColor3 = C.slabGold, Size = UDim2.fromOffset(60, 40), ZIndex = 5, StrokeThickness = 3 })
	text(guideFace, "Text", { Text = "Walk onto the Pawn Mill and tap TRAIN", TextSize = 28, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(66, 0), Size = UDim2.new(1, -70, 1, 0), ZIndex = 5, StrokeThickness = 3 })

	-- Dim layer behind panels ------------------------------------------------------
	new("Frame", { Name = "Dim", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 60), Position = UDim2.fromOffset(0, -60), Visible = false, ZIndex = 20, Active = true }, gui)

	-- Panel helper: floating title, close button ------------------------------------
	local function panel(name: string, title: string, color: Color3, size: Vector2): Frame
		local holder, face = block(gui, name, "Frame", C.panel, UDim2.fromOffset(size.X, size.Y), UDim2.fromScale(0.5, 0.47), Vector2.new(0.5, 0.5))
		holder.Visible = false
		holder.ZIndex = 30
		for _, d in holder:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex += 30
			end
		end
		face.BackgroundColor3 = Color3.fromRGB(38, 44, 40)
		face.BackgroundTransparency = 0.2;
		(face:FindFirstChild("Studs") :: ImageLabel).Visible = false
		-- full-width header bar inside the sheet (the reference's menu look); the words sit on it
		local titleHolder, titleFace = block(face, "Title", "Frame", color, UDim2.new(1, -16, 0, 60), UDim2.new(0.5, 0, 0, 8), Vector2.new(0.5, 0))
		titleFace.ClipsDescendants = false
		for _, d in titleHolder:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex += 34
			end
		end
		text(titleFace, "Label", { Text = title, TextSize = 34, Size = UDim2.fromScale(1, 1), ZIndex = 40, StrokeThickness = 3 })
		local closeHolder, closeFace = button(face, "Close", C.slabRed, UDim2.fromOffset(50, 50), UDim2.new(1, -16, 0, 13), "X", 30, Vector2.new(1, 0))
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
	local sets = panel("SetsPanel", "Chess Sets", C.cyan, Vector2.new(880, 560))
	local grid = new("ScrollingFrame", { Name = "Grid", BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 78), Size = UDim2.new(1, -360, 1, -98), ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 33 }, sets)
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
	local preview = new("Frame", { Name = "Preview", BackgroundColor3 = Color3.fromRGB(30, 32, 48), BackgroundTransparency = 0.2, Position = UDim2.new(1, -330, 0, 78), Size = UDim2.new(0, 310, 1, -98), ZIndex = 33 }, sets)
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
	local board = panel("BoardPanel", "Board Run", C.orange, Vector2.new(660, 520))
	local list = new("ScrollingFrame", { Name = "List", BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 78), Size = UDim2.new(1, -40, 1, -98), ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 33 }, board)
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
	local result = panel("ResultPanel", "Victory!", C.gold, Vector2.new(520, 420))
	local rr = viewport(result, "Rival", UDim2.fromOffset(150, 150), UDim2.new(0.5, -75, 0, 72), pieceIcon("Pawn", Models.CHARCOAL, C.red), PIECE_CAM, PIECE_LOOK, 30)
	rr.ZIndex = 34
	text(result, "Line1", { Text = "Pawn Rival defeated", TextSize = 28, Position = UDim2.fromOffset(0, 226), Size = UDim2.new(1, 0, 0, 32), ZIndex = 35 })
	text(result, "Line2", { Text = "+10 Wins", TextSize = 36, TextColor3 = C.gold, Position = UDim2.fromOffset(0, 262), Size = UDim2.new(1, 0, 0, 40), ZIndex = 35, StrokeThickness = 3 })
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
	local settings = panel("SettingsPanel", "Settings", C.grey, Vector2.new(460, 340))
	for i, row in { { "Music", "Music" }, { "Sound", "Sound effects" }, { "Reduced", "Reduced effects" } } do
		local r = new("Frame", { Name = row[1], BackgroundTransparency = 1, Position = UDim2.fromOffset(30, 82 + (i - 1) * 76), Size = UDim2.new(1, -60, 0, 64), ZIndex = 33 }, settings)
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
	Hud.Theme(gui)
	return gui
end

return Hud
