--!strict
-- Kit — the shared prop kit every floor is assembled from (§11 "reuse
-- aggressively"). One module, everything parameterized by the floor palette, so
-- six floors can look distinct while sharing one part vocabulary.
--
-- ============================= API REFERENCE =============================
-- Conventions (read these first):
--   * FLOOR-STANDING props: `cf` is the point on the floor UNDER the prop's
--     centre; the prop's front faces cf.LookVector (local -Z).
--   * MOUNTED props (marked "cf = centre"): `cf` is the prop's own centre —
--     use these for anything hung on a wall or ceiling.
--   * Every builder parents what it makes under `parent` and returns its root.
--   * Small props are CanCollide/CanQuery/CastShadow false so clicks ray
--     straight through to rivals; walls/floors/large furniture collide.
--
-- Kit.part(parent, cf, size: Vector3, color: Color3, material: Enum.Material?) -> Part
-- Kit.bevelBlock(parent, cf, size: Vector3, color: Color3) -> Part      -- cf = block centre; adds a thin inset top cap
-- Kit.textLabelOn(part: BasePart, face: Enum.NormalId, text: string, color: Color3, textSize: number?) -> TextLabel
--
-- Kit.desk(parent, cf, palette) -> Model                                -- 4 x 2 x 2
-- Kit.officeChair(parent, cf, palette, seatColor: Color3?) -> Model     -- 2 x 3 x 2
-- Kit.monitor(parent, cf, palette) -> Model                             -- 1.6 x 1.2 Neon screen, tag GlowScreen
-- Kit.keyboardProp(parent, cf, palette) -> Model
-- Kit.mug(parent, cf, palette) -> Model                                 -- oversized, 0.9 tall
-- Kit.paperStack(parent, cf, palette) -> Model
-- Kit.filingCabinet(parent, cf, palette) -> Model                       -- 2 x 4 x 2
-- Kit.partition(parent, cf, palette, width: number, height: number) -> Model
-- Kit.pottedPlant(parent, cf, palette, dying: boolean?) -> Model
-- Kit.poster(parent, cf, palette, width: number, height: number, text: string, onPart: BasePart?) -> BasePart
--                                                                       -- cf = centre; with onPart the poster fills that part's Front face
-- Kit.waterCooler(parent, cf, palette) -> Model
-- Kit.photocopier(parent, cf, palette) -> Model                         -- 3 x 3.5 x 2.5
-- Kit.vendingMachine(parent, cf, palette) -> Model                      -- 3 x 6 x 2
-- Kit.coffeeMachineBig(parent, cf, palette) -> Model                    -- 6 x 8 x 4 hero prop, display tagged GlowScreen
-- Kit.ceilingLight(parent, cf, palette) -> Part                         -- 4 x 0.3 x 4 Neon panel, cf = centre
-- Kit.fluorescentTube(parent, cf, palette, flicker: boolean?) -> Model  -- 6 long, cf = centre, tube runs along local +X; tag FlickerLight when flicker
-- Kit.windowWall(parent, cf, palette, width: number, height: number) -> Model
--                                                                       -- full wall segment: sill + glass band + header
-- Kit.doubleDoor(parent, cf, palette) -> Model                          -- 8 x 10, doors swung OPEN (walkthrough)
-- Kit.elevatorDoors(parent, cf, palette) -> Model                       -- 8 x 10, closed, gold seam
-- Kit.elevatorPanel(parent, cf, palette) -> Model                       -- 1 x 2 glowing, cf = centre (good Prompt part)
-- Kit.rug(parent, cf, palette, width: number, length: number) -> Model
-- Kit.bookshelf(parent, cf, palette) -> Model                           -- 4 x 7 x 1.5
-- Kit.whiteboard(parent, cf, palette) -> Model                          -- 6 x 4 on legs, graph going up
-- Kit.beanbag(parent, cf, palette) -> Model                             -- 3 dia squashed ball
-- Kit.pingpongTable(parent, cf, palette) -> Model                       -- 9 x 3 x 5 + net
-- Kit.pillar(parent, cf, palette, height: number) -> Model              -- 2 dia x height
-- Kit.trimStrip(parent, cf, palette, length: number) -> Part            -- gold Neon strip, cf = centre, runs along local +X
-- Kit.gateArch(parent, cf, palette, labelText: string) -> Model         -- 14 wide x 12 tall, floating billboard label
-- Kit.paydayPad(parent, cf, palette) -> Part                            -- 6 dia gold Neon cylinder, tag IdleBob (the returned Part is the Touched pad)
-- Kit.spawnPad(parent, cf, palette) -> Part                             -- 8 dia two-tone disc
-- Kit.boardFrame(parent, cf, palette, title: string) -> (Model, Frame)  -- 10 x 6 wall board, cf = centre.
--                                                                       -- Model.PrimaryPart carries the SurfaceGui (use it as the manifest Boards part);
--                                                                       -- the returned Frame is the empty content area under the title bar.
-- Kit.hrDesk(parent, cf, palette) -> Model                              -- red-stamp paperwork desk
-- Kit.shopKiosk(parent, cf, palette) -> Model                           -- 8 x 4 x 3 counter + shelves + sign
-- Kit.bossDesk(parent, cf, palette) -> Model                            -- 10 x 3 x 5
-- Kit.swivelChair(parent, cf, palette) -> Model                         -- the comedic low-back rival chair
-- Kit.cardboardStack(parent, cf, palette, count: number) -> Model
-- Kit.mailCart(parent, cf, palette) -> Model
-- Kit.conveyor(parent, cf, palette, length: number) -> Model            -- belt runs along local Z, letters on top
-- Kit.neonSign(parent, cf, palette, text: string, color: Color3?) -> Model -- cf = centre
-- Kit.room(parent, origin: CFrame, w, h, l, palette, opts: RoomOpts?) -> Folder
--   The workhorse: floor slab + skirting + 4 walls + optional window bands and
--   ceiling with a ceilingLight grid. `origin` = floor-top centre of the room.
--   Walls: N = local -Z, S = +Z, E = +X, W = -X.
--   opts = { windows: boolean?, ceiling: boolean?, doors: { RoomDoor }? }
--   RoomDoor = { Wall: "N"|"S"|"E"|"W", Offset: number?, Width: number? }
--   Door offsets run along the room's local +X for N/S walls and local +Z for
--   E/W walls; openings get a header so the wall still reads as one surface.
-- =========================================================================

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palettes = require(ReplicatedStorage.Shared.Config.Palettes)

type Palette = Palettes.Palette

export type RoomDoor = {
	Wall: "N" | "S" | "E" | "W",
	Offset: number?,
	Width: number?,
}

export type RoomOpts = {
	windows: boolean?,
	ceiling: boolean?,
	doors: { RoomDoor }?,
}

local Kit = {}

-- Fixed colours that must read the same on every floor regardless of palette
-- (paper is always paper, coffee is always coffee).
local COLOR_PAPER = Color3.fromRGB(245, 242, 230)
local COLOR_GOLD = Color3.fromRGB(255, 203, 88)
local COLOR_STEEL = Color3.fromRGB(168, 176, 184)
local COLOR_TERRACOTTA = Color3.fromRGB(194, 108, 72)
local COLOR_LEAF = Color3.fromRGB(88, 166, 92)
local COLOR_DEAD_LEAF = Color3.fromRGB(146, 124, 68)
local COLOR_COFFEE = Color3.fromRGB(74, 52, 35)
local COLOR_WATER = Color3.fromRGB(130, 200, 235)
local COLOR_RED = Color3.fromRGB(206, 66, 60)
local COLOR_BOARD_WHITE = Color3.fromRGB(248, 248, 246)
local COLOR_TABLE_GREEN = Color3.fromRGB(52, 140, 96)
local COLOR_WARM_LIGHT = Color3.fromRGB(255, 248, 228)
local COLOR_CARDBOARD = Color3.fromRGB(187, 148, 97)
local COLOR_INK = Color3.fromRGB(45, 42, 40)

local function lighten(c: Color3, amount: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), amount)
end

local function darken(c: Color3, amount: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), amount)
end

local function pcol(rgb: { number }): Color3
	return Palettes.color(rgb)
end

local function tag(instance: Instance, tagName: string)
	CollectionService:AddTag(instance, tagName)
end

local function newModel(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

-- ============================== base helpers ==============================

function Kit.part(parent: Instance, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = material or Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	-- Small bits never collide or catch rays: clicks must pass through clutter
	-- to hit rivals, and hundreds of tiny shadow casters would cost mobile fps.
	local small = size.Magnitude < 6
	p.CastShadow = not small
	p.CanCollide = not small
	p.CanQuery = not small
	p.Parent = parent
	return p
end

function Kit.bevelBlock(parent: Instance, cf: CFrame, size: Vector3, color: Color3): Part
	local main = Kit.part(parent, cf, size, color)
	-- The inset lighter cap fakes a bevelled highlight — flat-shaded chunky
	-- parts read as toys instead of grey boxes with this one trick.
	local inset = math.min(0.4, size.X * 0.15, size.Z * 0.15)
	local capHeight = math.min(0.25, size.Y * 0.25)
	Kit.part(
		main,
		cf * CFrame.new(0, size.Y / 2 + capHeight / 2, 0),
		Vector3.new(size.X - inset, capHeight, size.Z - inset),
		lighten(color, 0.18)
	)
	return main
end

function Kit.textLabelOn(part: BasePart, face: Enum.NormalId, text: string, color: Color3, textSize: number?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeColor3 = COLOR_INK
	label.TextStrokeTransparency = 0.6
	if textSize then
		label.TextSize = textSize
		label.TextWrapped = true
	else
		label.TextScaled = true
	end
	label.Parent = gui
	return label
end

-- Roblox cylinders lie along their X axis; this stands one upright.
local function uprightCylinder(parent: Instance, cf: CFrame, diameter: number, height: number, color: Color3, material: Enum.Material?): Part
	local p = Kit.part(parent, cf * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(height, diameter, diameter), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- SpecialMesh spheres scale to the part size, which Ball-shaped parts refuse
-- to do — that's how we get squashed cartoon blobs.
local function squashBall(parent: Instance, cf: CFrame, size: Vector3, color: Color3): Part
	local p = Kit.part(parent, cf, size, color)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function billboardText(part: BasePart, worldOffset: Vector3, widthStuds: number, heightStuds: number, text: string, color: Color3): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(widthStuds, 0, heightStuds, 0)
	-- World-space offset because several anchor parts are rotated cylinders
	-- whose local up is sideways.
	gui.StudsOffsetWorldSpace = worldOffset
	gui.AlwaysOnTop = false
	gui.MaxDistance = 250
	gui.LightInfluence = 0
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeColor3 = COLOR_INK
	label.TextStrokeTransparency = 0.35
	label.TextScaled = true
	label.Parent = gui
	return label
end

-- ============================== desk & seat ==============================

function Kit.desk(parent: Instance, cf: CFrame, palette: Palette): Model
	local model = newModel(parent, "Desk")
	local dark = pcol(palette.Dark)

	local top = Kit.bevelBlock(model, cf * CFrame.new(0, 1.55, 0), Vector3.new(4, 0.5, 2), pcol(palette.Primary))
	top.CanCollide = true -- furniture you can hop onto; CanQuery stays false so clicks pass to rivals

	for _, x in { -1.7, 1.7 } do
		Kit.part(model, cf * CFrame.new(x, 0.65, 0), Vector3.new(0.35, 1.3, 1.8), dark)
	end
	-- Modesty panel on the aisle side gives the desk its second colour zone.
	Kit.part(model, cf * CFrame.new(0, 0.95, -0.7), Vector3.new(3.4, 0.9, 0.2), darken(pcol(palette.Accent), 0.15))

	model.PrimaryPart = top
	return model
end

function Kit.officeChair(parent: Instance, cf: CFrame, palette: Palette, seatColor: Color3?): Model
	local model = newModel(parent, "OfficeChair")
	local dark = pcol(palette.Dark)
	local seat = seatColor or pcol(palette.Primary)

	uprightCylinder(model, cf * CFrame.new(0, 0.15, 0), 1.8, 0.3, dark)
	Kit.part(model, cf * CFrame.new(0, 0.75, 0), Vector3.new(0.3, 0.9, 0.3), dark)
	local seatPart = Kit.bevelBlock(model, cf * CFrame.new(0, 1.35, 0), Vector3.new(1.8, 0.45, 1.8), seat)
	-- Positive pitch leans the backrest away from the desk — slouch included.
	Kit.part(model, cf * CFrame.new(0, 2.3, 0.78) * CFrame.Angles(math.rad(8), 0, 0), Vector3.new(1.8, 1.5, 0.3), seat)

	model.PrimaryPart = seatPart
	return model
end

function Kit.swivelChair(parent: Instance, cf: CFrame, palette: Palette): Model
	local model = newModel(parent, "SwivelChair")
	local dark = pcol(palette.Dark)

	uprightCylinder(model, cf * CFrame.new(0, 0.12, 0), 1.9, 0.25, dark)
	Kit.part(model, cf * CFrame.new(0, 0.55, 0), Vector3.new(0.28, 0.7, 0.28), dark)
	local seatPart = Kit.bevelBlock(model, cf * CFrame.new(0, 1.1, 0), Vector3.new(1.7, 0.4, 1.7), pcol(palette.Primary))
	Kit.part(model, cf * CFrame.new(0, 1.95, 0.7) * CFrame.Angles(math.rad(10), 0, 0), Vector3.new(1.7, 1.1, 0.28), pcol(palette.Primary))

	model.PrimaryPart = seatPart
	return model
end

-- ============================ desktop clutter ============================

function Kit.monitor(parent: Instance, cf: CFrame, palette: Palette): Model
	local model = newModel(parent, "Monitor")
	local dark = pcol(palette.Dark)

	Kit.part(model, cf * CFrame.new(0, 0.06, 0.1), Vector3.new(0.9, 0.12, 0.5), dark)
	Kit.part(model, cf * CFrame.new(0, 0.35, 0.1), Vector3.new(0.22, 0.5, 0.22), dark)
	local bezel = Kit.part(model, cf * CFrame.new(0, 1.2, 0.1), Vector3.new(1.85, 1.45, 0.16), dark)
	local screen = Kit.part(model, cf * CFrame.new(0, 1.2, 0.0), Vector3.new(1.6, 1.2, 0.06), lighten(pcol(palette.Accent), 0.25), Enum.Material.Neon)
	tag(screen, "GlowScreen")

	model.PrimaryPart = bezel
	return model
end

function Kit.keyboardProp(parent: Instance, cf: CFrame, palette: Palette): Model
	local model = newModel(parent, "Keyboard")
	local deck = Kit.bevelBlock(model, cf * CFrame.new(0, 0.09, 0), Vector3.new(1.6, 0.16, 0.7), pcol(palette.Dark))
	Kit.part(model, cf * CFrame.new(0, 0.22, 0.18), Vector3.new(0.8, 0.07, 0.16), lighten(pcol(palette.Dark), 0.35))
	model.PrimaryPart = deck
	return model
end

function Kit.mug(parent: Instance, cf: CFrame, palette: Palette): Model
	local model = newModel(parent, "Mug")
	local body = uprightCylinder(model, cf * CFrame.new(0, 0.45, 0), 0.75, 0.9, pcol(palette.Accent))
	uprightCylinder(model, cf * CFrame.new(0, 0.86, 0), 0.58, 0.1, COLOR_COFFEE)
	Kit.part(model, cf * CFrame.new(0.48, 0.45, 0), Vector3.new(0.15, 0.5, 0.32), pcol(palette.Accent))
	model.PrimaryPart = body
	return model
end

function Kit.paperStack(parent: Instance, cf: CFrame, palette: Palette): Model
	local model = newModel(parent, "PaperStack")
	-- Deterministic yaws so every stack looks hand-dumped without RNG making
	-- the map differ between servers.
	local yaws = { -8, 5, -3 }
	local root: Part? = nil
	for i, yaw in yaws do
		local sheet = Kit.part(
			model,
			cf * CFrame.new(0, 0.08 + (i - 1) * 0.16, 0) * CFrame.Angles(0, math.rad(yaw), 0),
			Vector3.new(1, 0.16, 1.3),
			if i == 2 then lighten(pcol(palette.Accent), 0.55) else COLOR_PAPER
		)
		if not root then
			root = sheet
		end
	end
	model.PrimaryPart = root
	return model
end

-- ============================ hub furniture ==============================

function Kit.filingCabinet(parent: Instance, cf: CFrame, palette: Palette): Model
	local model = newModel(parent, "FilingCabinet")
	local body = Kit.bevelBlock(model, cf * CFrame.new(0, 1.95, 0), Vector3.new(2, 3.85, 2), pcol(palette.Primary))
	body.CanCollide = true
	for _, y in { 0.75, 1.95, 3.15 } do
		Kit.part(model, cf * CFrame.new(0, y, -1.05), Vector3.new(1.7, 1.0, 0.12), lighten(pcol(palette.Primary), 0.15))
		Kit.part(model, cf * CFrame.new(0, y + 0.28, -1.12), Vector3.new(0.7, 0.14, 0.1), pcol(palette.Dark))
	end
	model.PrimaryPart = body
	return model
end

function Kit.partition(parent: Instance, cf: CFrame, palette: Palette, width: number, height: number): Model
	local model = newModel(parent, "Partition")
	local dark = pcol(palette.Dark)

	local panel = Kit.part(model, cf * CFrame.new(0, (height - 0.3) / 2, 0), Vector3.new(width, height - 0.3, 0.35), pcol(palette.Primary))
	panel.CanCollide = true -- partitions are the cubicle maze walls
	Kit.part(model, cf * CFrame.new(0, height - 0.15, 0), Vector3.new(width + 0.1, 0.3, 0.45), dark)
	for _, x in { -(width / 2 - 0.3), width / 2 - 0.3 } do
		Kit.part(model, cf * CFrame.new(x, 0.12, 0), Vector3.new(0.4, 0.24, 1.2), dark)
	end

	model.PrimaryPart = panel
	return model
end

function Kit.pottedPlant(parent: Instance, cf: CFrame, palette: Palette, dying: boolean?): Model
	local model = newModel(parent, "PottedPlant")
	local pot = Kit.bevelBlock(model, cf * CFrame.new(0, 0.45, 0), Vector3.new(1.1, 0.9, 1.1), COLOR_TERRACOTTA)
	local leaf = if dying then COLOR_DEAD_LEAF else COLOR_LEAF
	Kit.part(model, cf * CFrame.new(0, 1.4, 0), Vector3.new(0.18, 1.1, 0.18), darken(leaf, 0.35))
	if dying then
		-- Drooped blobs hang low and outward — the plant is giving up.
		squashBall(model, cf * CFrame.new(0.45, 1.55, 0.2), Vector3.new(1.1, 0.7, 1.1), leaf)
		squashBall(model, cf * CFrame.new(-0.4, 1.4, -0.25), Vector3.new(0.9, 0.6, 0.9), darken(leaf, 0.12))
	else
		squashBall(model, cf * CFrame.new(0, 2.25, 0), Vector3.new(1.5, 1.2, 1.5), leaf)
		squashBall(model, cf * CFrame.new(0.5, 1.85, 0.3), Vector3.new(1.0, 0.8, 1.0), darken(leaf, 0.1))
		squashBall(model, cf * CFrame.new(-0.5, 1.95, -0.2), Vector3.new(0.9, 0.75, 0.9), lighten(leaf, 0.12))
	end
	model.PrimaryPart = pot
	return model
end

function Kit.poster(parent: Instance, cf: CFrame, palette: Palette, width: number, height: number, text: string, onPart: BasePart?): BasePart
	local paper: BasePart
	if onPart then
		paper = onPart
	else
		local p = Kit.part(parent, cf, Vector3.new(width, height, 0.15), COLOR_PAPER)
		p.Name = "Poster"
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		paper = p
	end

	local accent = pcol(palette.Accent)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.Parent = paper

	local bg = Instance.new("Frame")
	bg.BackgroundColor3 = COLOR_PAPER
	bg.BorderSizePixel = 0
	bg.Size = UDim2.fromScale(1, 1)
	bg.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Color = darken(accent, 0.2)
	stroke.Thickness = 6
	stroke.Parent = bg

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.06, 0.06)
	title.Size = UDim2.fromScale(0.88, 0.68)
	title.Font = Enum.Font.FredokaOne
	title.Text = text
	title.TextColor3 = COLOR_INK
	title.TextScaled = true
	title.TextWrapped = true
	title.Parent = bg

	local footer = Instance.new("Frame")
	footer.BackgroundColor3 = accent
	footer.BorderSizePixel = 0
	footer.Position = UDim2.fromScale(0, 0.84)
	footer.Size = UDim2.fromScale(1, 0.16)
	footer.Parent = bg

	local footerText = Instance.new("TextLabel")
	footerText.BackgroundTransparency = 1
	footerText.Size = UDim2.fromScale(1, 1)
	footerText.Font = Enum.Font.Gotham
	footerText.Text = "MEMO FROM MANAGEMENT"
	footerText.TextColor3 = Color3.new(1, 1, 1)
	footerText.TextScaled = true
	footerText.Parent = footer

	return paper
end

function Kit.waterCooler(parent: Instance, cf: CFrame, palette: Palette): Model
	local model = newModel(parent, "WaterCooler")
	local body = Kit.bevelBlock(model, cf * CFrame.new(0, 1.3, 0), Vector3.new(1.2, 2.6, 1.2), lighten(pcol(palette.Wall), 0.35))
	local bottle = uprightCylinder(model, cf * CFrame.new(0, 3.2, 0), 1.0, 1.1, COLOR_WATER)
	bottle.Transparency = 0.35
	tag(bottle, "WaterShimmer")
	Kit.part(model, cf * CFrame.new(0.2, 1.95, -0.62), Vector3.new(0.16, 0.26, 0.2), pcol(palette.Accent))
	Kit.part(model, cf * CFrame.new(-0.2, 1.95, -0.62), Vector3.new(0.16, 0.26, 0.2), pcol(palette.Dark))
	Kit.part(model, cf * CFrame.new(0, 1.6, -0.62), Vector3.new(0.7, 0.12, 0.3), pcol(palette.Dark))
	model.PrimaryPart = body
	return model
end

function Kit.photocopier(parent: Instance, cf: CFrame, palette: Palette): Model
	local model = newModel(parent, "Photocopier")
	local beige = Color3.fromRGB(222, 218, 205)
	local dark = pcol(palette.Dark)

	Kit.part(model, cf * CFrame.new(0, 0.2, 0), Vector3.new(3, 0.4, 2.5), dark)
	local body = Kit.bevelBlock(model, cf * CFrame.new(0, 1.7, 0), Vector3.new(3, 2.6, 2.5), beige)
	body.CanCollide = true
	Kit.part(model, cf * CFrame.new(0, 3.2, 0), Vector3.new(2.7, 0.35, 2.2), dark)
	-- Angled control panel with a glowing readout — the machine is Thinking.
	Kit.part(model, cf * CFrame.new(0.9, 3.0, -1.0) * CFrame.Angles(math.rad(20), 0, 0), Vector3.new(1.0, 0.14, 0.7), dark)
	local screen = Kit.part(model, cf * CFrame.new(0.9, 3.12, -1.02) * CFrame.Angles(math.rad(20), 0, 0), Vector3.new(0.55, 0.1, 0.35), lighten(pcol(palette.Accent), 0.3), Enum.Material.Neon)
	tag(screen, "GlowScreen")
	Kit.part(model, cf * CFrame.new(-1.9, 1.8, 0), Vector3.new(1.6, 0.14, 1.1), lighten(dark, 0.2))
	Kit.part(model, cf * CFrame.new(-1.9, 1.92, 0), Vector3.new(1.2, 0.08, 0.85), COLOR_PAPER)

	model.PrimaryPart = body
	return model
end

function Kit.vendingMachine(parent: Instance, cf: CFrame, palette: Palette): Model
	local model = newModel(parent, "VendingMachine")
	local accent = pcol(palette.Accent)

	local body = Kit.bevelBlock(model, cf * CFrame.new(0, 2.95, 0), Vector3.new(3, 5.9, 2), accent)
	body.CanCollide = true
	local window = Kit.part(model, cf * CFrame.new(-0.25, 3.7, -1.05), Vector3.new(2.1, 3.3, 0.15), Color3.fromRGB(30, 32, 38))
	window.Transparency = 0.2
	window.CanCollide = false
	window.CanQuery = false
	-- Snacks sit just behind the glass in cheerful mismatched colours.
	local snackColors = { lighten(pcol(palette.Primary), 0.2), COLOR_GOLD, COLOR_PAPER, COLOR_RED, lighten(accent, 0.45), COLOR_LEAF }
	for i, snackColor in snackColors do
		local column = (i - 1) % 3
		local row = if i <= 3 then 0 else 1
		Kit.part(
			model,
			cf * CFrame.new(-0.85 + column * 0.62, 4.45 - row * 1.0, -0.85),
			Vector3.new(0.5, 0.55, 0.35),
			snackColor
		)
	end
	Kit.part(model, cf * CFrame.new(-0.25, 1.1, -1.05), Vector3.new(1.8, 0.65, 0.15), pcol(palette.Dark))
	local strip = Kit.part(model, cf * CFrame.new(1.2, 2.95, -1.05), Vector3.new(0.22, 5.2, 0.12), lighten(accent, 0.4), Enum.Material.Neon)
	tag(strip, "GlowScreen")

	local brand = Kit.textLabelOn(body, Enum.NormalId.Front, "SNAX", Color3.new(1, 1, 1))
	brand.Position = UDim2.fromScale(0, 0.01)
	brand.Size = UDim2.fromScale(1, 0.13)

	model.PrimaryPart = body
	return model
end

function Kit.coffeeMachineBig(parent: Instance, cf: CFrame, palette: Palette): Model
	local model = newModel(parent, "CoffeeMachineBig")
	local dark = pcol(palette.Dark)
	local primary = pcol(palette.Primary)

	local base = Kit.bevelBlock(model, cf * CFrame.new(0, 0.6, 0), Vector3.new(6, 1.2, 4), dark)
	base.CanCollide = true
	local body = Kit.bevelBlock(model, cf * CFrame.new(0, 3.6, 0), Vector3.new(5.2, 4.8, 3.4), primary)
	body.CanCollide = true
	uprightCylinder(model, cf * CFrame.new(0, 6.85, 0), 3.0, 1.5, lighten(primary, 0.25))
	local cap = Kit.part(model, cf * CFrame.new(0, 7.8, 0), Vector3.new(1.1, 1.1, 1.1), COLOR_GOLD)
	cap.Shape = Enum.PartType.Ball

	local screen = Kit.part(model, cf * CFrame.new(0, 4.6, -1.78), Vector3.new(2, 1.2, 0.16), lighten(pcol(palette.Accent), 0.3), Enum.Material.Neon)
	tag(screen, "GlowScreen")

	-- Portafilter, spout and a giant cup: the gacha "mouth" players stare at.
	Kit.part(model, cf * CFrame.new(0.9, 2.9, -1.9) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(1.4, 0.45, 0.45), dark)
	Kit.part(model, cf * CFrame.new(0, 2.7, -1.9), Vector3.new(0.5, 0.7, 0.5), dark)
	uprightCylinder(model, cf * CFrame.new(0, 1.7, -1.7), 1.5, 1.0, COLOR_PAPER)
	Kit.part(model, cf * CFrame.new(2.2, 5.2, -1.5) * CFrame.Angles(0, 0, math.rad(-15)), Vector3.new(0.3, 1.3, 0.3), COLOR_GOLD)
	Kit.part(model, cf * CFrame.new(-2.4, 6.4, 0), Vector3.new(0.25, 2.2, 0.25), COLOR_GOLD)

	local plate = Kit.textLabelOn(body, Enum.NormalId.Front, "BREW-O-TRON", lighten(pcol(palette.Accent), 0.35))
	plate.Position = UDim2.fromScale(0, 0.78)
	plate.Size = UDim2.fromScale(1, 0.14)

	model.PrimaryPart = body
	return model
end

-- ============================ lights & walls =============================

function Kit.ceilingLight(parent: Instance, cf: CFrame, palette: Palette): Part
	local panel = Kit.part(parent, cf, Vector3.new(4, 0.3, 4), COLOR_WARM_LIGHT, Enum.Material.Neon)
	panel.Name = "CeilingLight"
	local frame = Kit.part(panel, cf * CFrame.new(0, 0.2, 0), Vector3.new(4.4, 0.16, 4.4), pcol(palette.Dark))
	frame.CanCollide = false
	frame.CanQuery = false
	frame.CastShadow = false
	return panel
end

function Kit.fluorescentTube(parent: Instance, cf: CFrame, palette: Palette, flicker: boolean?): Model
	local model = newModel(parent, "FluorescentTube")
	local dark = pcol(palette.Dark)

	local housing = Kit.part(model, cf * CFrame.new(0, 0.3, 0), Vector3.new(6.4, 0.25, 0.55), dark)
	housing.CanCollide = false
	housing.CanQuery = false
	housing.CastShadow = false
	-- Cylinder axis is already X, which is the direction the tube runs.
	local tube = Kit.part(model, cf, Vector3.new(6, 0.35, 0.35), Color3.fromRGB(228, 248, 228), Enum.Material.Neon)
	tube.Shape = Enum.PartType.Cylinder
	for _, x in { -2.5, 2.5 } do
		Kit.part(model, cf * CFrame.new(x, 0.75, 0), Vector3.new(0.12, 0.7, 0.12), dark)
	end

	-- A real light source: the Mailroom's gloom comes from geometry plus this
	-- one local pool of light, not from Lighting settings.
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(225, 245, 225)
	light.Brightness = 1.2
	light.Range = 22
	light.Parent = tube

	if flicker then
		tag(tube, "FlickerLight")
	end

	model.PrimaryPart = tube
	return model
end

function Kit.windowWall(parent: Instance, cf: CFrame, palette: Palette, width: number, height: number): Model
	local model = newModel(parent, "WindowWall")
	local wallColor = pcol(palette.Wall)
	local dark = pcol(palette.Dark)
	local glassHeight = math.max(1, height - 3)
	local glassCentreY = 2.2 + glassHeight / 2

	local sill = Kit.part(model, cf * CFrame.new(0, 1.1, 0), Vector3.new(width, 2.2, 0.9), wallColor)
	sill.CanCollide = true
	local header = Kit.part(model, cf * CFrame.new(0, height - 0.4, 0), Vector3.new(width, 0.8, 0.9), wallColor)
	header.CanCollide = true
	header.CanQuery = true

	local glass = Kit.part(model, cf * CFrame.new(0, glassCentreY, 0), Vector3.new(width, glassHeight, 0.3), Color3.fromRGB(185, 222, 240))
	glass.Transparency = 0.55
	glass.CanCollide = true -- players must not clip out of the tower
	glass.CastShadow = false -- daylight should pour through

	-- Mullions every 6 studs keep huge glass runs from reading as one flat sheet.
	local x = -width / 2 + 6
	while x < width / 2 - 0.5 do
		local post = Kit.part(model, cf * CFrame.new(x, glassCentreY, 0), Vector3.new(0.3, glassHeight, 0.35), dark)
		post.CanCollide = false
		post.CanQuery = false
		post.CastShadow = false
		x += 6
	end

	model.PrimaryPart = sill
	return model
end

function Kit.doubleDoor(parent: Instance, cf: CFrame, palette: Palette): Model
	local model = newModel(parent, "DoubleDoor")
	local dark = pcol(palette.Dark)
	local primary = pcol(palette.Primary)

	for _, x in { -3.6, 3.6 } do
		Kit.part(model, cf * CFrame.new(x, 5, 0), Vector3.new(0.8, 10, 1), dark)
	end
	Kit.part(model, cf * CFrame.new(0, 9.4, 0), Vector3.new(8, 1.2, 1), dark)

	-- Doors are swung wide open: this is a walkthrough, never a blocker (§5).
	local hinges = { { x = -3.2, swing = 115, lean = 1.45 }, { x = 3.2, swing = -115, lean = -1.45 } }
	for _, h in hinges do
		local door = Kit.part(
			model,
			cf * CFrame.new(h.x, 4.1, 0) * CFrame.Angles(0, math.rad(h.swing), 0) * CFrame.new(h.lean, 0, 0),
			Vector3.new(2.9, 8.2, 0.4),
			primary
		)
		Kit.part(model, door.CFrame * CFrame.new(0, 2.5, -0.26), Vector3.new(0.7, 0.7, 0.1), lighten(primary, 0.3))
		Kit.part(model, door.CFrame * CFrame.new(if h.lean > 0 then 1.05 else -1.05, 0, -0.26), Vector3.new(0.22, 1.1, 0.1), COLOR_GOLD)
	end

	model.PrimaryPart = model:FindFirstChildOfClass("Part")
	return model
end

function Kit.elevatorDoors(parent: Instance, cf: CFrame, palette: Palette): Model
	local model = newModel(parent, "ElevatorDoors")
	local dark = pcol(palette.Dark)

	local back = Kit.part(model, cf * CFrame.new(0, 4.7, 0.5), Vector3.new(7.2, 9.4, 0.4), darken(pcol(palette.Wall), 0.3))
	for _, x in { -3.75, 3.75 } do
		Kit.part(model, cf * CFrame.new(x, 5, 0), Vector3.new(0.7, 10, 1.2), dark)
	end
	Kit.part(model, cf * CFrame.new(0, 9.5, 0), Vector3.new(8.2, 1.0, 1.2), dark)

	for _, x in { -1.68, 1.68 } do
		Kit.part(model, cf * CFrame.new(x, 4.3, 0), Vector3.new(3.3, 8.6, 0.5), COLOR_STEEL)
	end
	-- The gold seam sells "elevator" from across the room.
	local seam = Kit.part(model, cf * CFrame.new(0, 4.3, -0.06), Vector3.new(0.16, 8.6, 0.45), COLOR_GOLD, Enum.Material.Neon)
	seam.CanCollide = false
	seam.CanQuery = false
	seam.CastShadow = false

	Kit.part(model, cf * CFrame.new(0, 9.5, -0.65), Vector3.new(1.6, 0.6, 0.15), dark)
	local indicator = Kit.part(model, cf * CFrame.new(0, 9.5, -0.72), Vector3.new(1.2, 0.3, 0.08), COLOR_GOLD, Enum.Material.Neon)
	tag(indicator, "GlowScreen")

	model.PrimaryPart = back
	return model
end

function Kit.elevatorPanel(parent: Instance, cf: CFrame, palette: Palette): Model
	local model = newModel(parent, "ElevatorPanel")
	local plate = Kit.part(model, cf, Vector3.new(1, 2, 0.22), pcol(palette.Dark))
	plate.CanCollide = false
	local screen = Kit.part(model, cf * CFrame.new(0, 0.5, -0.12), Vector3.new(0.72, 0.6, 0.1), lighten(pcol(palette.Accent), 0.3), Enum.Material.Neon)
	tag(screen, "GlowScreen")
	Kit.part(model, cf * CFrame.new(0, -0.15, -0.12), Vector3.new(0.3, 0.3, 0.08), COLOR_GOLD, Enum.Material.Neon)
	Kit.part(model, cf * CFrame.new(0, -0.6, -0.12), Vector3.new(0.3, 0.3, 0.08), COLOR_GOLD, Enum.Material.Neon)
	model.PrimaryPart = plate
	return model
end

-- ============================= soft furniture ============================

function Kit.rug(parent: Instance, cf: CFrame, palette: Palette, width: number, length: number): Model
	local model = newModel(parent, "Rug")
	local border = Kit.part(model, cf * CFrame.new(0, 0.05, 0), Vector3.new(width, 0.1, length), darken(pcol(palette.Accent), 0.3))
	local inner = Kit.part(model, cf * CFrame.new(0, 0.07, 0), Vector3.new(width - 1, 0.1, length - 1), pcol(palette.Accent))
	for _, p in { border, inner } do
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
	end
	model.PrimaryPart = border
	return model
end

function Kit.bookshelf(parent: Instance, cf: CFrame, palette: Palette): Model
	local model = newModel(parent, "Bookshelf")
	local dark = pcol(palette.Dark)
	local primary = pcol(palette.Primary)

	local back = Kit.part(model, cf * CFrame.new(0, 3.5, 0.6), Vector3.new(4, 7, 0.25), darken(primary, 0.2))
	for _, x in { -1.85, 1.85 } do
		Kit.part(model, cf * CFrame.new(x, 3.5, 0), Vector3.new(0.3, 7, 1.5), dark)
	end
	Kit.part(model, cf * CFrame.new(0, 6.9, 0), Vector3.new(4, 0.3, 1.5), dark)

	local bookColors = { pcol(palette.Accent), lighten(pcol(palette.Accent), 0.35), lighten(primary, 0.25), COLOR_PAPER, COLOR_RED, darken(pcol(palette.Accent), 0.2) }
	for shelfIndex, shelfY in { 1.8, 3.6, 5.4 } do
		Kit.part(model, cf * CFrame.new(0, shelfY, 0.1), Vector3.new(3.4, 0.2, 1.3), primary)
		-- Two uneven book runs per shelf: enough variety, few parts.
		for run = 1, 2 do
			local colorIndex = ((shelfIndex - 1) * 2 + run - 1) % #bookColors + 1
			Kit.part(
				model,
				cf * CFrame.new(-0.85 + (run - 1) * 1.7, shelfY + 0.65, 0.15),
				Vector3.new(1.4, 1.1 - run * 0.15, 1.0),
				bookColors[colorIndex]
			)
		end
	end

	model.PrimaryPart = back
	return model
end

function Kit.whiteboard(parent: Instance, cf: CFrame, palette: Palette): Model
	local model = newModel(parent, "Whiteboard")
	local dark = pcol(palette.Dark)

	for _, x in { -2.7, 2.7 } do
		Kit.part(model, cf * CFrame.new(x, 2.6, 0), Vector3.new(0.3, 5.2, 0.3), dark)
		Kit.part(model, cf * CFrame.new(x, 0.1, 0), Vector3.new(0.3, 0.2, 1.3), dark)
	end
	local board = Kit.part(model, cf * CFrame.new(0, 3.3, 0), Vector3.new(6, 3.6, 0.25), COLOR_BOARD_WHITE)
	board.CanCollide = false
	Kit.part(model, cf * CFrame.new(0, 1.4, -0.25), Vector3.new(5, 0.15, 0.35), dark)

	-- The obligatory hockey-stick graph, drawn with rotated frames.
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.Parent = board

	local axisColor = COLOR_INK
	local axisY = Instance.new("Frame")
	axisY.BackgroundColor3 = axisColor
	axisY.BorderSizePixel = 0
	axisY.Position = UDim2.fromScale(0.1, 0.12)
	axisY.Size = UDim2.fromScale(0.015, 0.72)
	axisY.Parent = gui
	local axisX = Instance.new("Frame")
	axisX.BackgroundColor3 = axisColor
	axisX.BorderSizePixel = 0
	axisX.Position = UDim2.fromScale(0.1, 0.82)
	axisX.Size = UDim2.fromScale(0.78, 0.025)
	axisX.Parent = gui

	local segments = {
		{ x = 0.26, y = 0.72, rot = -18 },
		{ x = 0.46, y = 0.58, rot = -32 },
		{ x = 0.68, y = 0.38, rot = -48 },
	}
	for _, seg in segments do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BackgroundColor3 = COLOR_RED
		line.BorderSizePixel = 0
		line.Position = UDim2.fromScale(seg.x, seg.y)
		line.Size = UDim2.fromScale(0.24, 0.035)
		line.Rotation = seg.rot
		line.Parent = gui
	end

	local caption = Instance.new("TextLabel")
	caption.BackgroundTransparency = 1
	caption.Position = UDim2.fromScale(0.5, 0.86)
	caption.Size = UDim2.fromScale(0.42, 0.1)
	caption.Font = Enum.Font.Gotham
	caption.Text = "Q4 SYNERGY"
	caption.TextColor3 = axisColor
	caption.TextScaled = true
	caption.Parent = gui

	model.PrimaryPart = board
	return model
end

function Kit.beanbag(parent: Instance, cf: CFrame, palette: Palette): Model
	local model = newModel(parent, "Beanbag")
	local bag = squashBall(model, cf * CFrame.new(0, 0.85, 0), Vector3.new(3, 1.7, 3), pcol(palette.Accent))
	squashBall(model, cf * CFrame.new(0, 1.5, 0), Vector3.new(1.7, 0.7, 1.7), lighten(pcol(palette.Accent), 0.25))
	model.PrimaryPart = bag
	return model
end

function Kit.pingpongTable(parent: Instance, cf: CFrame, palette: Palette): Model
	local model = newModel(parent, "PingpongTable")
	local dark = pcol(palette.Dark)

	local top = Kit.part(model, cf * CFrame.new(0, 2.4, 0), Vector3.new(9, 0.35, 5), COLOR_TABLE_GREEN)
	top.CanCollide = true
	top.CanQuery = false
	Kit.part(model, cf * CFrame.new(0, 2.61, 0), Vector3.new(9, 0.06, 0.2), COLOR_PAPER)
	Kit.part(model, cf * CFrame.new(0, 2.95, 0), Vector3.new(0.12, 0.75, 5.2), COLOR_PAPER)
	for _, corner in { Vector2.new(-3.8, -1.9), Vector2.new(3.8, -1.9), Vector2.new(-3.8, 1.9), Vector2.new(3.8, 1.9) } do
		Kit.part(model, cf * CFrame.new(corner.X, 1.1, corner.Y), Vector3.new(0.4, 2.2, 0.4), dark)
	end
	-- One dusty paddle and ball: nobody has ever played (per DESIGN-MAP).
	Kit.part(model, cf * CFrame.new(2.6, 2.65, 1.2) * CFrame.Angles(0, math.rad(35), 0), Vector3.new(0.9, 0.12, 0.7), COLOR_RED)
	local ball = Kit.part(model, cf * CFrame.new(3.4, 2.75, -0.8), Vector3.new(0.35, 0.35, 0.35), COLOR_PAPER)
	ball.Shape = Enum.PartType.Ball

	model.PrimaryPart = top
	return model
end

function Kit.pillar(parent: Instance, cf: CFrame, palette: Palette, height: number): Model
	local model = newModel(parent, "Pillar")
	local dark = pcol(palette.Dark)
	local shaft = uprightCylinder(model, cf * CFrame.new(0, height / 2, 0), 2, height - 0.8, lighten(pcol(palette.Wall), 0.12))
	shaft.CanCollide = true
	Kit.part(model, cf * CFrame.new(0, 0.2, 0), Vector3.new(2.6, 0.4, 2.6), dark)
	Kit.part(model, cf * CFrame.new(0, height - 0.2, 0), Vector3.new(2.6, 0.4, 2.6), dark)
	model.PrimaryPart = shaft
	return model
end

function Kit.trimStrip(parent: Instance, cf: CFrame, palette: Palette, length: number): Part
	local strip = Kit.part(parent, cf, Vector3.new(length, 0.22, 0.22), COLOR_GOLD, Enum.Material.Neon)
	strip.Name = "TrimStrip"
	strip.CanCollide = false
	strip.CanQuery = false
	strip.CastShadow = false
	return strip
end

-- ============================ wing set pieces ============================

function Kit.gateArch(parent: Instance, cf: CFrame, palette: Palette, labelText: string): Model
	local model = newModel(parent, "GateArch")
	local dark = pcol(palette.Dark)
	local accent = pcol(palette.Accent)

	for _, x in { -6.3, 6.3 } do
		Kit.bevelBlock(model, cf * CFrame.new(x, 6, 0), Vector3.new(1.4, 12, 1.4), dark)
	end
	local beam = Kit.bevelBlock(model, cf * CFrame.new(0, 11.3, 0), Vector3.new(14, 1.4, 1.4), accent)
	local underGlow = Kit.part(model, cf * CFrame.new(0, 10.45, 0), Vector3.new(12.6, 0.18, 0.18), lighten(accent, 0.3), Enum.Material.Neon)
	underGlow.CanCollide = false
	underGlow.CanQuery = false
	underGlow.CastShadow = false

	-- Floating workload label: the "self-select back to training" signpost —
	-- information instead of a locked door (§5: never block, never kill).
	billboardText(beam, Vector3.new(0, -3.2, 0), 13, 2.4, labelText, lighten(accent, 0.4))

	model.PrimaryPart = beam
	return model
end

function Kit.paydayPad(parent: Instance, cf: CFrame, palette: Palette): Part
	local pad = uprightCylinder(parent, cf * CFrame.new(0, 0.3, 0), 6, 0.35, COLOR_GOLD, Enum.Material.Neon)
	pad.Name = "PaydayPad"
	-- Walk-over trigger: no collision lip, but Touched must still fire.
	pad.CanCollide = false
	pad.CanQuery = false
	pad.CastShadow = false
	pad.CanTouch = true
	tag(pad, "IdleBob")

	local ring = uprightCylinder(pad, cf * CFrame.new(0, 0.09, 0), 7, 0.18, pcol(palette.Dark))
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CastShadow = false

	billboardText(pad, Vector3.new(0, 3.5, 0), 8, 2, "PAYDAY", COLOR_GOLD)
	return pad
end

function Kit.spawnPad(parent: Instance, cf: CFrame, palette: Palette): Part
	local disc = uprightCylinder(parent, cf * CFrame.new(0, 0.15, 0), 8, 0.3, lighten(pcol(palette.Primary), 0.25))
	disc.Name = "SpawnPad"
	disc.CanCollide = false
	disc.CanQuery = false
	local ring = uprightCylinder(disc, cf * CFrame.new(0, 0.07, 0), 8.8, 0.16, pcol(palette.Accent))
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CastShadow = false
	return disc
end

function Kit.boardFrame(parent: Instance, cf: CFrame, palette: Palette, title: string): (Model, Frame)
	local model = newModel(parent, "BoardFrame")
	local accent = pcol(palette.Accent)

	Kit.part(model, cf, Vector3.new(10, 6, 0.5), pcol(palette.Dark))
	local face = Kit.part(model, cf * CFrame.new(0, 0, -0.15), Vector3.new(9.2, 5.2, 0.3), Color3.fromRGB(240, 240, 236))
	face.CanCollide = false
	for _, corner in { Vector2.new(-4.6, -2.6), Vector2.new(4.6, -2.6), Vector2.new(-4.6, 2.6), Vector2.new(4.6, 2.6) } do
		Kit.part(model, cf * CFrame.new(corner.X, corner.Y, -0.28), Vector3.new(0.3, 0.3, 0.1), COLOR_GOLD, Enum.Material.Neon)
	end

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.Parent = face

	local header = Instance.new("Frame")
	header.BackgroundColor3 = accent
	header.BorderSizePixel = 0
	header.Size = UDim2.fromScale(1, 0.22)
	header.Parent = gui

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.fromScale(1, 1)
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.Text = title
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextScaled = true
	titleLabel.Parent = header

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Position = UDim2.fromScale(0, 0.24)
	content.Size = UDim2.fromScale(1, 0.76)
	content.Parent = gui

	-- PrimaryPart carries the SurfaceGui: LeaderboardService finds it via the
	-- manifest Boards part, so the face must be the part floor agents hand over.
	model.PrimaryPart = face
	return model, content
end

-- ============================ station props ==============================

function Kit.hrDesk(parent: Instance, cf: CFrame, palette: Palette): Model
	local model = newModel(parent, "HrDesk")
	local dark = pcol(palette.Dark)

	for _, x in { -2.2, 2.2 } do
		Kit.part(model, cf * CFrame.new(x, 0.65, 0), Vector3.new(0.35, 1.3, 2.0), dark)
	end
	local top = Kit.bevelBlock(model, cf * CFrame.new(0, 1.55, 0), Vector3.new(5, 0.5, 2.2), pcol(palette.Primary))
	top.CanCollide = true
	Kit.part(model, cf * CFrame.new(0, 1.0, -1.0), Vector3.new(4.6, 1.0, 0.2), darken(pcol(palette.Accent), 0.15))

	-- Paperwork tray + red stamp: the whole Restructure fantasy in two props.
	Kit.part(model, cf * CFrame.new(1.5, 2.0, 0.3), Vector3.new(1.5, 0.4, 1.05), dark)
	Kit.part(model, cf * CFrame.new(1.5, 2.14, 0.3), Vector3.new(1.2, 0.26, 0.85), COLOR_PAPER)
	Kit.part(model, cf * CFrame.new(-1.4, 1.98, 0.2), Vector3.new(0.5, 0.32, 0.5), COLOR_RED)
	Kit.part(model, cf * CFrame.new(-1.4, 2.3, 0.2), Vector3.new(0.16, 0.4, 0.16), dark)

	local plate = Kit.part(model, cf * CFrame.new(0, 1.95, -1.0), Vector3.new(1.9, 0.45, 0.15), COLOR_GOLD)
	Kit.textLabelOn(plate, Enum.NormalId.Front, "HUMAN RESOURCES", COLOR_INK)

	model.PrimaryPart = top
	return model
end

function Kit.shopKiosk(parent: Instance, cf: CFrame, palette: Palette): Model
	local model = newModel(parent, "ShopKiosk")
	local dark = pcol(palette.Dark)

	local counter = Kit.bevelBlock(model, cf * CFrame.new(0, 1.3, -0.7), Vector3.new(8, 2.6, 1.5), pcol(palette.Primary))
	counter.CanCollide = true
	local shelfBack = Kit.part(model, cf * CFrame.new(0, 2.1, 1.3), Vector3.new(8, 4.2, 0.3), dark)
	shelfBack.CanCollide = true
	for _, y in { 1.7, 2.9 } do
		Kit.part(model, cf * CFrame.new(0, y, 0.95), Vector3.new(7.4, 0.22, 1.0), lighten(dark, 0.25))
	end

	-- The three gear ladders on display: keyboard, coffee, chair (miniature).
	Kit.keyboardProp(model, cf * CFrame.new(-2.5, 1.81, 0.95) * CFrame.Angles(0, math.rad(10), 0), palette)
	Kit.mug(model, cf * CFrame.new(0, 1.81, 0.95), palette)
	Kit.part(model, cf * CFrame.new(2.5, 3.1, 0.95), Vector3.new(0.7, 0.18, 0.7), pcol(palette.Accent))
	Kit.part(model, cf * CFrame.new(2.5, 3.5, 1.2), Vector3.new(0.7, 0.8, 0.15), pcol(palette.Accent))

	local sign = Kit.part(model, cf * CFrame.new(0, 4.7, 1.2), Vector3.new(8.4, 1.1, 0.4), pcol(palette.Accent))
	Kit.textLabelOn(sign, Enum.NormalId.Front, "GEAR SHOP", Color3.new(1, 1, 1))
	local trim = Kit.part(model, cf * CFrame.new(0, 4.05, 1.0), Vector3.new(8.4, 0.15, 0.15), COLOR_GOLD, Enum.Material.Neon)
	trim.CanCollide = false
	trim.CanQuery = false
	trim.CastShadow = false

	model.PrimaryPart = counter
	return model
end

function Kit.bossDesk(parent: Instance, cf: CFrame, palette: Palette): Model
	local model = newModel(parent, "BossDesk")
	local dark = pcol(palette.Dark)
	local wood = darken(pcol(palette.Primary), 0.2)

	local top = Kit.bevelBlock(model, cf * CFrame.new(0, 2.5, 0), Vector3.new(10, 0.7, 5), wood)
	top.CanCollide = true
	for _, x in { -4.4, 4.4 } do
		Kit.part(model, cf * CFrame.new(x, 1.1, 0), Vector3.new(0.8, 2.2, 4.6), dark)
	end
	local front = Kit.part(model, cf * CFrame.new(0, 1.1, -2.1), Vector3.new(8.8, 2.2, 0.5), darken(pcol(palette.Primary), 0.05))
	front.CanCollide = true
	local trim = Kit.part(model, cf * CFrame.new(0, 2.1, -2.38), Vector3.new(9, 0.18, 0.1), COLOR_GOLD, Enum.Material.Neon)
	trim.CanCollide = false
	trim.CanQuery = false
	trim.CastShadow = false

	local plate = Kit.part(model, cf * CFrame.new(0, 3.1, -2.1), Vector3.new(2.4, 0.55, 0.2), COLOR_GOLD)
	Kit.textLabelOn(plate, Enum.NormalId.Front, "MANAGEMENT", COLOR_INK)

	model.PrimaryPart = top
	return model
end

-- =========================== mailroom set ================================

function Kit.cardboardStack(parent: Instance, cf: CFrame, palette: Palette, count: number): Model
	local model = newModel(parent, "CardboardStack")
	local yCursor = 0
	local root: Part? = nil
	for i = 1, count do
		local side = math.max(1.3, 2.5 - i * 0.28)
		local boxHeight = side * 0.75
		-- Index-seeded jitter: messy-looking, but identical on every server.
		local dx = (((i * 37) % 5) - 2) * 0.18
		local dz = (((i * 61) % 5) - 2) * 0.18
		local yaw = (((i * 97) % 9) - 4) * 5
		local box = Kit.part(
			model,
			cf * CFrame.new(dx, yCursor + boxHeight / 2, dz) * CFrame.Angles(0, math.rad(yaw), 0),
			Vector3.new(side, boxHeight, side),
			lighten(COLOR_CARDBOARD, (i % 2) * 0.08)
		)
		Kit.part(box, box.CFrame * CFrame.new(0, boxHeight / 2 + 0.03, 0), Vector3.new(0.35, 0.06, side + 0.05), darken(COLOR_CARDBOARD, 0.25))
		if not root then
			root = box
		end
		yCursor += boxHeight
	end
	model.PrimaryPart = root
	return model
end

function Kit.mailCart(parent: Instance, cf: CFrame, palette: Palette): Model
	local model = newModel(parent, "MailCart")
	local dark = pcol(palette.Dark)
	local canvas = pcol(palette.Accent)

	local bottom = Kit.part(model, cf * CFrame.new(0, 0.9, 0), Vector3.new(2.4, 0.15, 1.5), dark)
	for _, z in { -0.7, 0.7 } do
		Kit.part(model, cf * CFrame.new(0, 1.4, z), Vector3.new(2.4, 0.9, 0.12), canvas)
	end
	for _, x in { -1.15, 1.15 } do
		Kit.part(model, cf * CFrame.new(x, 1.4, 0), Vector3.new(0.12, 0.9, 1.5), canvas)
	end
	for _, corner in { Vector2.new(-1.0, -0.6), Vector2.new(1.0, -0.6), Vector2.new(-1.0, 0.6), Vector2.new(1.0, 0.6) } do
		local wheel = Kit.part(model, cf * CFrame.new(corner.X, 0.25, corner.Y), Vector3.new(0.2, 0.5, 0.5), dark)
		wheel.Shape = Enum.PartType.Cylinder
	end
	for _, x in { -0.9, 0.9 } do
		Kit.part(model, cf * CFrame.new(x, 2.0, 0.8), Vector3.new(0.12, 0.7, 0.12), dark)
	end
	Kit.part(model, cf * CFrame.new(0, 2.35, 0.8), Vector3.new(1.9, 0.14, 0.14), dark)
	for i, yaw in { -14, 8, 20 } do
		Kit.part(model, cf * CFrame.new(-0.6 + i * 0.4, 1.9, -0.1) * CFrame.Angles(math.rad(6), math.rad(yaw), 0), Vector3.new(0.75, 0.55, 0.08), COLOR_PAPER)
	end

	model.PrimaryPart = bottom
	return model
end

function Kit.conveyor(parent: Instance, cf: CFrame, palette: Palette, length: number): Model
	local model = newModel(parent, "Conveyor")
	local dark = pcol(palette.Dark)

	local belt = Kit.part(model, cf * CFrame.new(0, 1.55, 0), Vector3.new(3, 0.5, length), darken(dark, 0.2))
	belt.CanCollide = true
	for _, x in { -1.62, 1.62 } do
		Kit.part(model, cf * CFrame.new(x, 1.85, 0), Vector3.new(0.25, 0.85, length), lighten(dark, 0.2))
	end
	local z = -length / 2 + 1.5
	while z < length / 2 do
		for _, x in { -1.2, 1.2 } do
			Kit.part(model, cf * CFrame.new(x, 0.65, z), Vector3.new(0.35, 1.3, 0.35), dark)
		end
		z += 6
	end

	local letterCount = math.max(1, math.floor(length / 3.5))
	for i = 1, letterCount do
		local letterZ = -length / 2 + 2 + (i - 1) * 3.5
		if i % 3 == 0 then
			Kit.part(model, cf * CFrame.new(0.2, 2.2, letterZ) * CFrame.Angles(0, math.rad(15), 0), Vector3.new(1.1, 0.8, 0.9), COLOR_CARDBOARD)
		else
			Kit.part(model, cf * CFrame.new(0, 1.85, letterZ) * CFrame.Angles(0, math.rad(((i % 3) - 1) * 15), 0), Vector3.new(0.95, 0.1, 0.7), COLOR_PAPER)
		end
	end

	model.PrimaryPart = belt
	return model
end

function Kit.neonSign(parent: Instance, cf: CFrame, palette: Palette, text: string, color: Color3?): Model
	local model = newModel(parent, "NeonSign")
	local glow = color or lighten(pcol(palette.Accent), 0.2)
	local width = math.max(4, #text * 1.1 + 1.8)

	local board = Kit.part(model, cf, Vector3.new(width, 2.6, 0.3), darken(pcol(palette.Dark), 0.3))
	board.CanCollide = false
	board.CanQuery = false
	-- Neon tube border around a dark board: reads "sign" from any angle.
	for _, y in { -1.05, 1.05 } do
		local strip = Kit.part(model, cf * CFrame.new(0, y, -0.18), Vector3.new(width - 0.4, 0.14, 0.12), glow, Enum.Material.Neon)
		strip.CanCollide = false
		strip.CanQuery = false
		strip.CastShadow = false
	end
	for _, x in { -(width / 2 - 0.25), width / 2 - 0.25 } do
		Kit.part(model, cf * CFrame.new(x, 0, -0.18), Vector3.new(0.14, 2.0, 0.12), glow, Enum.Material.Neon)
	end

	local label = Kit.textLabelOn(board, Enum.NormalId.Front, text, lighten(glow, 0.15))
	label.Position = UDim2.fromScale(0.05, 0.15)
	label.Size = UDim2.fromScale(0.9, 0.7)

	model.PrimaryPart = board
	return model
end

-- ================================ room ===================================

-- Builds one wall run along wallCf's local +X, splitting around door gaps and
-- topping each gap with a header so nothing reads as a missing tooth.
local function buildWallRun(
	folder: Instance,
	wallCf: CFrame,
	span: number,
	height: number,
	palette: Palette,
	windows: boolean,
	gaps: { { offset: number, width: number } }
)
	table.sort(gaps, function(a, b)
		return a.offset < b.offset
	end)
	local wallColor = pcol(palette.Wall)
	local doorHeight = math.min(height - 1, 11)

	local function emit(fromX: number, toX: number)
		local segWidth = toX - fromX
		if segWidth < 0.5 then
			return
		end
		local segCf = wallCf * CFrame.new((fromX + toX) / 2, 0, 0)
		if windows and segWidth >= 4 then
			Kit.windowWall(folder, segCf, palette, segWidth, height)
		else
			local solid = Kit.part(folder, segCf * CFrame.new(0, height / 2, 0), Vector3.new(segWidth, height, 1), wallColor)
			solid.CanCollide = true -- narrow slivers must still contain players
			solid.CanQuery = true
		end
	end

	local cursor = -span / 2
	for _, gap in gaps do
		local left = math.clamp(gap.offset - gap.width / 2, -span / 2, span / 2)
		local right = math.clamp(gap.offset + gap.width / 2, -span / 2, span / 2)
		emit(cursor, left)
		local headerHeight = height - doorHeight
		if headerHeight > 0.1 and right > left then
			local header = Kit.part(
				folder,
				wallCf * CFrame.new((left + right) / 2, doorHeight + headerHeight / 2, 0),
				Vector3.new(right - left, headerHeight, 1),
				wallColor
			)
			header.CanCollide = true
		end
		cursor = math.max(cursor, right)
	end
	emit(cursor, span / 2)
end

function Kit.room(parent: Instance, origin: CFrame, w: number, h: number, l: number, palette: Palette, opts: RoomOpts?): Folder
	local o: RoomOpts = opts or {}
	local folder = Instance.new("Folder")
	folder.Name = "Room"
	folder.Parent = parent

	local dark = pcol(palette.Dark)

	local slab = Kit.part(folder, origin * CFrame.new(0, -0.5, 0), Vector3.new(w, 1, l), pcol(palette.Ground))
	slab.Name = "Floor"
	slab.CanCollide = true

	-- Dark skirting around the interior: grounds the walls, hides the seam.
	for _, z in { -(l / 2 - 1.15), l / 2 - 1.15 } do
		local strip = Kit.part(folder, origin * CFrame.new(0, 0.25, z), Vector3.new(w - 2, 0.5, 0.25), dark)
		strip.CanCollide = false
		strip.CanQuery = false
		strip.CastShadow = false
	end
	for _, x in { -(w / 2 - 1.15), w / 2 - 1.15 } do
		local strip = Kit.part(folder, origin * CFrame.new(x, 0.25, 0), Vector3.new(0.25, 0.5, l - 2.5), dark)
		strip.CanCollide = false
		strip.CanQuery = false
		strip.CastShadow = false
	end

	local cuts: { [string]: { { offset: number, width: number } } } = { N = {}, S = {}, E = {}, W = {} }
	if o.doors then
		for _, door in o.doors do
			local list = cuts[door.Wall]
			if list then
				table.insert(list, { offset = door.Offset or 0, width = door.Width or 12 })
			end
		end
	end

	local windows = o.windows == true
	-- N/S walls span the full width; E/W walls tuck between them, and their
	-- local +X is rotated onto the room's +Z so door offsets stay intuitive.
	buildWallRun(folder, origin * CFrame.new(0, 0, -(l - 1) / 2), w, h, palette, windows, cuts.N)
	buildWallRun(folder, origin * CFrame.new(0, 0, (l - 1) / 2), w, h, palette, windows, cuts.S)
	buildWallRun(folder, origin * CFrame.new((w - 1) / 2, 0, 0) * CFrame.Angles(0, math.rad(-90), 0), l - 2, h, palette, windows, cuts.E)
	buildWallRun(folder, origin * CFrame.new(-(w - 1) / 2, 0, 0) * CFrame.Angles(0, math.rad(-90), 0), l - 2, h, palette, windows, cuts.W)

	if o.ceiling then
		local ceiling = Kit.part(folder, origin * CFrame.new(0, h + 0.5, 0), Vector3.new(w, 1, l), lighten(pcol(palette.Wall), 0.25))
		ceiling.Name = "Ceiling"
		-- A sparse grid of glowing panels: bright and even, capped so a big hub
		-- room can't blow the part budget on lights alone.
		local countX = math.clamp(math.floor(w / 18), 1, 6)
		local countZ = math.clamp(math.floor(l / 18), 1, 6)
		local stepX = w / countX
		local stepZ = l / countZ
		for ix = 1, countX do
			for iz = 1, countZ do
				local x = -w / 2 + stepX * (ix - 0.5)
				local z = -l / 2 + stepZ * (iz - 0.5)
				Kit.ceilingLight(folder, origin * CFrame.new(x, h - 0.2, z), palette)
			end
		end
	end

	return folder
end

return Kit
