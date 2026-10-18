--[[
	Builds a lobby leaderboard: the slab, its stone base and the board's face (title, subtitle, 12 rows that scroll
	to 50). Huss Valley's boards one to one (owner, Oct 18: "make the leaderboards just like in the video", then
	"make them also look more like the reference ones but keep some halloween mood to it"), measured from his clip
	(design/lobby-ref/lb_f1.jpg: the MOST WINS board's corners 727,175 / 1178,153 / 734,758, 451 x 583 px, 14 x 18
	studs counted on its stud grid): the slab is 14 x 18 studs and the face is a 700 x 900 canvas (50 px a stud):
	  title     white Gotham Heavy, x 25, cap 27 to 60 (HIGHEST LEVEL = 62% of the width), a dark outline
	  subtitle  Gotham Bold caps, x 25, cap 79 to 96 ("GLOBAL · ALL TIME · TOP 50" = 46% of the width)
	  rows      12 shown, 65 apart, row 1 centred at y 152 (61 tall bands the slab's colour, a hair lighter, a light
	            top edge and a dark gap under each), round headshot 56 at x 8, "#1 name" centred at x 308 in a 348
	            wide box (long names shrink like theirs; Gotham Medium, cap 33 for #1 to #3), the value right-aligned
	            to x 668 in Gotham Bold caps (a Trophy board's number ends at 586 with the 42 px trophy after it),
	            a thin scroll bar at the right edge; all text white with a soft dark outline
	  studs     one stud every 50 px, a raised square 23 px across with a dark lower edge (assets/icons/board-stud.png,
	            tools/icons/make_board_studs.py), over the whole face
	  colour    on screen the clip's slab is a muted grey-mauve: 113, 71, 97 (MOST WINS) to 134, 86, 108 (HIGHEST
	            LEVEL, nearer the light), so we aim at 124, 80, 103
	Text sizes: Roblox draws Gotham smaller than the preview's Montserrat at the same TextSize (cap height 0.64 of the
	size against 0.70: measured on the owner's Studio screenshot design/owner-tests/oct18-boards.png, rows 32 px
	apart there = 0.49 of the canvas), so sizes are the reference's cap heights / 0.64 (title 52, names 52 / 46).
	Why the face paints its own colour (Oct 18 fix): the old face drew only the rows (unlit) on a lit, 12% see-through
	slab, so in his daylight Studio the header showed the blue sky through a lit slab (purple, 112, 75, 143) and the
	rows went magenta (119, 49, 82) under the game's colour grade (Config/Look: Saturation +0.35, Contrast +0.12,
	Exposure -0.1, which also works on SurfaceGuis). Now one unlit Backdrop in Colors.Face covers the face (same
	colour lit or in shade, day or night) with the studs drawn on it, and Colors.Face is the target with that grade
	undone (125, 94, 110 -> about 124, 80, 102 on screen; tests/Leaderboards.spec.luau checks it against Config/Look).
	Halloween (owner: "keep some halloween mood to it"), calm and still (nothing flashes): a faint spider web in the
	face's top-right corner (assets/icons/board-web.png), a carved pumpkin with a warm light sitting on the slab's
	top-right corner and a small candle on the top-left, and a soft orange glow under the slab. They are welded to the
	slab, so they turn with it (Gameplay/Leaderboards) and never hang off his podiums.
	No requires and no Roblox globals: every Roblox type comes in through `api` ({ Instance, UDim2, UDim, Color3,
	Vector2, Vector3, CFrame, Enum, Font }), so the game (Gameplay/Leaderboards, HuzzServer/LeaderboardService) and
	the place build (tools/place/build_yours.luau, plain Lune) build the very same board.
	(straightened side by side: docs/previews/leaderboard-vs-ref.jpg, tools/preview/leaderboard_vs_ref.py)
]]
local LeaderboardLook = {}

LeaderboardLook.Canvas = { W = 700, H = 900 }
LeaderboardLook.Row = { Top = 122, Pitch = 65, Height = 61, Left = 4, Width = 680, Avatar = 56 }
LeaderboardLook.Colors = {
	Target = { 124, 80, 103 }, -- what the face should look like on screen (the clip's slab, measured)
	Face = { 125, 94, 110 }, -- what we set: the target with the game's colour grade undone (see the header)
	Slab = { 125, 94, 110 }, -- the part itself (seen from behind and at the edges)
	Base = { 99, 95, 98 }, -- the stone base (the owner's grey)
	Text = { 255, 255, 255 },
	Stroke = { 34, 16, 28 },
	Pumpkin = { 236, 120, 28 },
	Glow = { 255, 150, 60 },
}
LeaderboardLook.Text = { Title = 52, Subtitle = 18, Name = 46, NameTop = 52, Value = 33, Trophy = 36 }
LeaderboardLook.RowLift = 0.05 -- how much lighter a row band is than the slab (they read almost the same in the clip)
LeaderboardLook.SlabTransparency = 0 -- (it was 0.12: the sky showed through in daylight)
local GOTHAM = "rbxasset://fonts/families/GothamSSm.json"

local function rgb(api, t) return api.Color3.fromRGB(t[1], t[2], t[3]) end

local function new(api, class: string, props: { [string]: any }, parent: any?)
	local inst = api.Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	if parent then inst.Parent = parent end
	return inst
end

local function outline(api, label, thickness: number, transparency: number)
	new(api, "UIStroke", { Name = "Outline", Color = rgb(api, LeaderboardLook.Colors.Stroke), Thickness = thickness, Transparency = transparency }, label)
end

local function text(api, props, parent)
	props.BackgroundTransparency = 1
	props.TextColor3 = props.TextColor3 or rgb(api, LeaderboardLook.Colors.Text)
	return new(api, "TextLabel", props, parent)
end

local function font(api, weight: string)
	return api.Font.new(GOTHAM, api.Enum.FontWeight[weight])
end

-- An image the game draws itself (Shared/Images, loaded by Gameplay/Leaderboards on each screen) and the preview
-- finds by file.
local function picture(api, name: string, file: string, props, parent)
	local img = new(api, "ImageLabel", props, parent)
	img:SetAttribute("Icon", name)
	img:SetAttribute("PreviewFile", file)
	return img
end

-- The face: backdrop + studs + web, title, subtitle and the scrolling list, filling `parent` (a SurfaceGui or a
-- 700 x 900 frame).
function LeaderboardLook.canvas(api, parent, def, subtitle: string)
	local Enum, UDim2, T = api.Enum, api.UDim2, LeaderboardLook.Text
	local canvas = new(api, "Frame", { Name = "Canvas", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, parent)
	local back = new(api, "Frame", {
		Name = "Backdrop", BackgroundColor3 = rgb(api, LeaderboardLook.Colors.Face), BackgroundTransparency = 0, BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1), ZIndex = 0,
	}, canvas)
	picture(api, "BoardStud", "assets/icons/board-stud.png", {
		Name = "Studs", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(50, 50), Image = "", ZIndex = 0,
	}, back)
	picture(api, "BoardWeb", "assets/icons/board-web.png", {
		Name = "Web", BackgroundTransparency = 1, AnchorPoint = api.Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(150, 150), ScaleType = Enum.ScaleType.Fit, Image = "", ImageTransparency = 0.45, ZIndex = 0,
	}, back)
	local title = text(api, {
		Name = "Title", Text = def.Title, FontFace = font(api, "Heavy"), TextSize = T.Title,
		TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(25, 14), Size = UDim2.fromOffset(650, 58),
	}, canvas)
	outline(api, title, 3, 0.3)
	local sub = text(api, {
		Name = "Subtitle", Text = subtitle, FontFace = font(api, "Bold"), TextSize = T.Subtitle,
		TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(25, 77), Size = UDim2.fromOffset(650, 22),
	}, canvas)
	outline(api, sub, 1.5, 0.45)
	local R = LeaderboardLook.Row
	new(api, "ScrollingFrame", {
		Name = "List", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(R.Left, R.Top - 2),
		Size = UDim2.fromOffset(LeaderboardLook.Canvas.W - R.Left, 12 * R.Pitch), CanvasSize = UDim2.fromOffset(0, 12 * R.Pitch),
		ScrollBarThickness = 6, ScrollBarImageColor3 = api.Color3.fromRGB(255, 255, 255), ScrollBarImageTransparency = 0.25,
		ScrollingDirection = Enum.ScrollingDirection.Y, VerticalScrollBarInset = Enum.ScrollBarInset.None,
	}, canvas)
	return canvas
end

-- One row band (kept and refilled; made when missing). Rows are named Row1, Row2 ...
local function row(api, list, i: number)
	local existing = list:FindFirstChild("Row" .. i)
	if existing then return existing end
	local Enum, UDim2, R, T = api.Enum, api.UDim2, LeaderboardLook.Row, LeaderboardLook.Text
	local f, k = LeaderboardLook.Colors.Face, LeaderboardLook.RowLift
	local band = new(api, "Frame", {
		Name = "Row" .. i, BackgroundColor3 = api.Color3.fromRGB(f[1] + (255 - f[1]) * k, f[2] + (255 - f[2]) * k, f[3] + (255 - f[3]) * k), BackgroundTransparency = 0.2,
		BorderSizePixel = 0, Position = UDim2.fromOffset(0, 2 + (i - 1) * R.Pitch), Size = UDim2.fromOffset(R.Width, R.Height),
		LayoutOrder = i,
	}, list)
	new(api, "Frame", { Name = "Shine", BackgroundColor3 = api.Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.85, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 2) }, band)
	new(api, "Frame", { Name = "Shade", BackgroundColor3 = api.Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.72, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -3), Size = UDim2.new(1, 0, 0, 3) }, band)
	local a = R.Avatar
	local avatar = new(api, "ImageLabel", {
		Name = "Avatar", BackgroundTransparency = 1, Image = "", Position = UDim2.fromOffset(4, (R.Height - a) // 2),
		Size = UDim2.fromOffset(a, a), ScaleType = Enum.ScaleType.Crop,
	}, band)
	local corner = new(api, "UICorner", { CornerRadius = api.UDim.new(0.5, 0) }, avatar) -- (the picture itself is round: no clipping)
	corner:SetAttribute("HuzzRadius", api.UDim.new(0.5, 0)) -- (a place file built by Lune can lose the radius: the game puts it back)
	local name = text(api, {
		Name = "PlayerName", Text = "#" .. i, FontFace = font(api, "Medium"), TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(140, 3), Size = UDim2.fromOffset(330, 56),
	}, band)
	new(api, "UITextSizeConstraint", { Name = "Fit", MaxTextSize = if i <= 3 then T.NameTop else T.Name, MinTextSize = 14 }, name)
	outline(api, name, 2, 0.45)
	local value = text(api, {
		Name = "Value", Text = "", FontFace = font(api, "Bold"), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(454, 10), Size = UDim2.fromOffset(210, 42),
	}, band)
	new(api, "UITextSizeConstraint", { Name = "Fit", MaxTextSize = T.Value, MinTextSize = 12 }, value)
	outline(api, value, 2, 0.45)
	return band
end

--[[
	Writes the entries ({ u, n, v } sorted) into the face. `format(def, v) -> text, icon` is
	LeaderboardRules.format; `icon(name, props)` makes an icon ImageLabel (the game's Kit.icon; nil = a blank one
	named for the preview). Always at least `shown` bands, empty ones under the last player.
]]
function LeaderboardLook.fill(api, canvas, def, entries: { any }, shown: number, format, icon)
	local UDim2, R, T = api.UDim2, LeaderboardLook.Row, LeaderboardLook.Text
	local list = canvas:FindFirstChild("List")
	if not list then return end
	local count = math.max(shown, #entries)
	for i = 1, count do
		local band = row(api, list, i)
		local e = entries[i]
		local name, value, avatar = band:FindFirstChild("PlayerName"), band:FindFirstChild("Value"), band:FindFirstChild("Avatar")
		local trophy = band:FindFirstChild("Trophy")
		if e then
			name.Text = "#" .. i .. " " .. (if e.n ~= "" then e.n else "Player")
			local t, iconName = format(def, e.v)
			value.Text = t
			avatar.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", math.max(1, math.floor(e.u)))
			if iconName then
				if not trophy then
					local props = { Name = "Trophy", BackgroundTransparency = 1, Position = UDim2.fromOffset(590, 9), Size = UDim2.fromOffset(42, 42), ScaleType = api.Enum.ScaleType.Fit }
					trophy = if icon then icon(iconName, props) else new(api, "ImageLabel", props)
					trophy:SetAttribute("Icon", iconName)
					trophy:SetAttribute("PreviewFile", "assets/icons/rewards-trophy.png")
					trophy.Parent = band
				end
				trophy.Visible = true
				value.Size = UDim2.fromOffset(124, 46)
				value.Position = UDim2.fromOffset(458, 7)
				value:FindFirstChild("Fit").MaxTextSize = T.Trophy
			else
				if trophy then trophy.Visible = false end
				value.Size = UDim2.fromOffset(210, 42)
				value.Position = UDim2.fromOffset(454, 10)
				value:FindFirstChild("Fit").MaxTextSize = T.Value
			end
		else
			name.Text = ""
			value.Text = ""
			avatar.Image = ""
			if trophy then trophy.Visible = false end
		end
		band.Visible = true
	end
	for _, child in list:GetChildren() do
		local n = tonumber(string.match(child.Name, "^Row(%d+)$"))
		if n and n > count then child.Visible = false end
	end
	list.CanvasSize = UDim2.fromOffset(0, count * R.Pitch + 2)
end

--[[
	The Halloween touches on a slab (calm, nothing flashes): a carved pumpkin with a warm light on its top-right corner,
	a small lit candle on its top-left, a soft orange glow under it. Welded (not anchored) to the slab, so they turn
	with it on each screen and stay where they belong.
]]
function LeaderboardLook.decorate(api, board)
	local Vector3, CFrame, Enum = api.Vector3, api.CFrame, api.Enum
	local holder = new(api, "Model", { Name = "Halloween" }, board)
	local size = board.Size
	local function piece(props, offset)
		local p = new(api, props.Class or "Part", {
			Anchored = false, CanCollide = false, CanQuery = false, CanTouch = false, Massless = true, CastShadow = false,
			TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth,
		})
		props.Class = nil
		for k, v in props do p[k] = v end
		p.CFrame = board.CFrame * offset
		p.Parent = holder
		new(api, "WeldConstraint", { Part0 = board, Part1 = p }, p)
		return p
	end
	local top = size.Y / 2
	-- the pumpkin: an orange ball, a stem, and a carved face glowing from inside (small Neon pieces on its front).
	-- (seen from the front, the face's right is the part's -X)
	local px, pr = -(size.X / 2 - 1.1), 0.8
	local pumpkin = piece({ Name = "Pumpkin", Shape = Enum.PartType.Ball, Size = Vector3.new(pr * 2, pr * 2, pr * 2), Color = rgb(api, LeaderboardLook.Colors.Pumpkin), Material = Enum.Material.SmoothPlastic }, CFrame.new(px, top + pr * 0.85, 0))
	piece({ Name = "Stem", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.45, 0.22, 0.22), Color = api.Color3.fromRGB(70, 110, 40), Material = Enum.Material.SmoothPlastic }, CFrame.new(px, top + pr * 1.85, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local carve = rgb(api, { 255, 196, 70 })
	local fz = -(pr - 0.08) -- (the front: the face shows on the slab's front, -Z)
	for _, side in { -1, 1 } do
		piece({ Name = "Eye", Size = Vector3.new(0.24, 0.24, 0.12), Color = carve, Material = Enum.Material.Neon }, CFrame.new(px + side * 0.28, top + pr * 1.0, fz + 0.06) * CFrame.Angles(0, 0, math.rad(45)))
	end
	piece({ Name = "Mouth", Size = Vector3.new(0.62, 0.14, 0.12), Color = carve, Material = Enum.Material.Neon }, CFrame.new(px, top + pr * 0.6, fz + 0.1))
	new(api, "PointLight", { Name = "PumpkinLight", Color = rgb(api, LeaderboardLook.Colors.Glow), Brightness = 0.8, Range = 7, Shadows = false }, pumpkin)
	-- the candle: a short wax stick and a small steady flame
	local cx = size.X / 2 - 0.7
	piece({ Name = "Candle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 0.36, 0.36), Color = api.Color3.fromRGB(240, 232, 214), Material = Enum.Material.SmoothPlastic }, CFrame.new(cx, top + 0.45, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local flame = piece({ Name = "Flame", Shape = Enum.PartType.Ball, Size = Vector3.new(0.26, 0.26, 0.26), Color = rgb(api, { 255, 186, 80 }), Material = Enum.Material.Neon }, CFrame.new(cx, top + 1.05, 0))
	new(api, "PointLight", { Name = "CandleLight", Color = rgb(api, LeaderboardLook.Colors.Glow), Brightness = 0.5, Range = 5, Shadows = false }, flame)
	-- the soft orange glow at the base (lights the ground and the podium, not the face: the face is unlit)
	local glowAt = new(api, "Attachment", { Name = "BaseGlow", Position = Vector3.new(0, -size.Y / 2 + 0.3, -1.2) }, board)
	new(api, "PointLight", { Name = "BaseLight", Color = rgb(api, LeaderboardLook.Colors.Glow), Brightness = 0.6, Range = 9, Shadows = false }, glowAt)
	return holder
end

--[[
	The whole board as a Model named "Leaderboard" (attribute Stat): a low stone Base on the ground and the Board slab
	standing on it with the face drawn on its front (a SurfaceGui named "LeaderboardFace", saved with the place
	so the owner sees and moves it in Studio; in a game every screen draws its own copy that can scroll).
	`at` = the CFrame of the base's bottom centre, facing the board's front. Rows start empty ("#1" ...).
]]
function LeaderboardLook.model(api, def, at, size, lift: number, subtitle: string, shown: number, onPodium: boolean?)
	local Vector3, CFrame, Enum = api.Vector3, api.CFrame, api.Enum
	local model = new(api, "Model", { Name = "Leaderboard" })
	model:SetAttribute("Stat", def.Stat)
	if onPodium then lift = 0 end -- (his podium is the base)
	local base = new(api, "Part", {
		Name = "Base", Anchored = true, Size = Vector3.new(size.X * 0.6, math.max(lift, 0.2), 3), CFrame = at * CFrame.new(0, lift / 2, 0),
		Color = rgb(api, LeaderboardLook.Colors.Base), Material = Enum.Material.Slate,
		TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth,
		Transparency = if onPodium then 1 else 0, CanCollide = not onPodium,
	}, model)
	local board = new(api, "Part", {
		Name = "Board", Anchored = true, CanCollide = false, CastShadow = false,
		Size = Vector3.new(size.X, size.Y, size.Z), CFrame = at * CFrame.new(0, lift + size.Y / 2, 0),
		Color = rgb(api, LeaderboardLook.Colors.Slab), Material = Enum.Material.SmoothPlastic,
		Transparency = LeaderboardLook.SlabTransparency,
		FrontSurface = Enum.SurfaceType.Studs, BackSurface = Enum.SurfaceType.Studs,
		TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth,
		LeftSurface = Enum.SurfaceType.Smooth, RightSurface = Enum.SurfaceType.Smooth,
	}, model)
	local gui = LeaderboardLook.surface(api, board)
	local canvas = LeaderboardLook.canvas(api, gui, def, subtitle)
	LeaderboardLook.fill(api, canvas, def, {}, shown, function() return "", nil end, nil)
	for i = 1, shown do
		local band = canvas.List:FindFirstChild("Row" .. i)
		if band then band.PlayerName.Text = "#" .. i end
	end
	pcall(LeaderboardLook.decorate, api, board)
	model.PrimaryPart = base
	return model
end

--[[
	Where each board stands round one lobby floor: on the owner's podiums first (his lobbies each have three grey
	5 x 3 x 14 podiums east of the girls: the board's width runs along the podium and its face turns to the lobby's
	middle), then along the back edge (rules.defaultSpots). floor: the lobby floor part; podiums: the top block of
	each "Podium" model; rules: Shared/LeaderboardRules. Returns { { at = CFrame (bottom centre, facing the
	board's front), podium = bool } } in board order.
]]
function LeaderboardLook.layout(api, rules, floor, podiums, count: number)
	local CFrame, Vector3 = api.CFrame, api.Vector3
	local cf, size = floor.CFrame, floor.Size
	local centre = cf.Position
	local _, yaw = cf:ToEulerAnglesYXZ()
	local flat = CFrame.new(centre) * CFrame.Angles(0, yaw, 0)
	local top = centre.Y + size.Y / 2
	local mine = {}
	for _, p in podiums do
		local rel = flat:PointToObjectSpace(p.CFrame.Position)
		if math.abs(rel.X) <= size.X / 2 + 2 and math.abs(rel.Z) <= size.Z / 2 + 2 then
			table.insert(mine, { part = p, z = rel.Z })
		end
	end
	table.sort(mine, function(a, b) return a.z < b.z end)
	local out = {}
	for _, m in mine do
		if #out >= count then break end
		local p = m.part
		local pc, pos = p.CFrame, p.CFrame.Position
		local long = if p.Size.Z >= p.Size.X then pc.LookVector else pc.RightVector
		local fx, fz = -long.Z, long.X -- (across the podium)
		if fx * (centre.X - pos.X) + fz * (centre.Z - pos.Z) < 0 then fx, fz = -fx, -fz end
		local y = rules.yawTo(0, 0, fx, fz)
		table.insert(out, { at = CFrame.new(pos.X, pos.Y + p.Size.Y / 2, pos.Z) * CFrame.Angles(0, y, 0), podium = true })
	end
	local rest = count - #out
	if rest > 0 then
		local spots = rules.defaultSpots(size.X, size.Z, rest)
		for i = 1, rest do
			local q = flat * Vector3.new(spots[i].X, 0, spots[i].Z)
			table.insert(out, { at = CFrame.new(q.X, top, q.Z) * CFrame.Angles(0, yaw, 0), podium = false })
		end
	end
	return out
end

-- The top block of every "Podium" model under `root` (the one highest up).
function LeaderboardLook.podiums(root): { any }
	local out = {}
	for _, d in root:GetDescendants() do
		if d:IsA("Model") and string.lower((string.gsub(d.Name, "[%s_%-]", ""))) == "podium" then
			local best, bestTop = nil, -math.huge
			for _, p in d:GetDescendants() do
				if p:IsA("BasePart") then
					local t = p.CFrame.Position.Y + p.Size.Y / 2
					if t > bestTop then best, bestTop = p, t end
				end
			end
			if best then table.insert(out, best) end
		end
	end
	return out
end

-- The SurfaceGui on the slab's front (unlit, so the face keeps its colour in sun, shade and at night).
function LeaderboardLook.surface(api, board)
	local Enum = api.Enum
	return new(api, "SurfaceGui", {
		Name = "LeaderboardFace", Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		CanvasSize = api.Vector2.new(LeaderboardLook.Canvas.W, LeaderboardLook.Canvas.H), LightInfluence = 0,
		ClipsDescendants = true, ResetOnSpawn = false, MaxDistance = 400,
	}, board)
end

--[[
	The game's colour grade on a colour (Config/Look ColorCorrection Saturation / Contrast and the Lighting's
	ExposureCompensation), 0-255 in and out: what the face looks like on screen. Pure maths, used by the spec (the
	face must land on Colors.Target) and the side by side.
]]
function LeaderboardLook.graded(c: { number }, saturation: number, contrast: number, exposure: number): { number }
	local l = 0.299 * c[1] + 0.587 * c[2] + 0.114 * c[3]
	local gain = 2 ^ exposure
	local out = {}
	for i = 1, 3 do
		local s = l + (c[i] - l) * (1 + saturation)
		s = (s - 128) * (1 + contrast) + 128
		out[i] = math.clamp(s * gain, 0, 255)
	end
	return out
end

return LeaderboardLook
