--!strict
-- OutdoorKit — the prop vocabulary for the open-air world: grass, brick
-- canyon walls, tiled plazas, trees, floating labels, pads and arches.
--
-- Everything is chunky, flat-shaded and saturated: SmoothPlastic and Neon only,
-- no realistic materials. Props are Anchored, small ones do not collide and do
-- not answer raycasts, so clicks always reach the enemy behind them.
--
-- ============================= API REFERENCE =============================
-- Conventions: `cx, cz` are centres on the ground plane; `y` is measured up
-- from the stage's own ground level (0 = standing surface). Every builder
-- parents into `parent` and returns the instance it made.
--
-- OutdoorKit.part(parent, cf, size, color, material?) -> Part
-- OutdoorKit.decor(parent, cf, size, color, material?) -> Part  (no collide/query)
-- OutdoorKit.label(parent, cf, text, color, size?, height?) -> BasePart  floating world text
-- OutdoorKit.ground(parent, base, cx, cz, sx, sz, color) -> Part
-- OutdoorKit.plaza(parent, base, cx, cz, sx, sz, color, accent) -> Part  raised tiled deck
-- OutdoorKit.cliffWall(parent, base, cx, cz, sx, sz, height, brick, top) -> Model
-- OutdoorKit.tree(parent, base, x, z, scale, trunk, leaf) -> Model
-- OutdoorKit.building(parent, base, x, z, w, h, d, body, accent, windows?) -> Model
-- OutdoorKit.arrowTrail(parent, base, x1, z1, x2, z2, count?) -> Folder
-- OutdoorKit.pad(parent, base, x, z, size, color, topText?, bottomText?) -> Part
-- OutdoorKit.punchingBag(parent, base, x, z, color, name, valueText) -> (Model, BasePart)
-- OutdoorKit.stageArch(parent, base, x, title, subtitle, accent, cliff) -> Model
-- OutdoorKit.barrier(parent, base, x, width, height, color, text) -> (Model, BasePart)
-- OutdoorKit.podium(parent, base, x, z, color) -> Part          -- shop stand
-- OutdoorKit.dummy(parent, base, x, z, yaw, shirt, trousers, accent, glow?) -> Model
-- OutdoorKit.briefcase(parent, base, x, z, color) -> (Model, BasePart)
-- OutdoorKit.pillar(parent, base, x, z, height, title, body, accent) -> Model
-- OutdoorKit.chest(parent, base, x, z, accent) -> (Model, BasePart)
-- OutdoorKit.stairs(parent, base, x, z, steps, width, rise, run, color, yaw?) -> Folder
-- OutdoorKit.fence(parent, base, x, z, length, yaw, color) -> Folder  invisible safety wall
-- =========================================================================

local OutdoorKit = {}

local DISPLAY_FONT = Enum.Font.FredokaOne

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end
OutdoorKit.rgb = rgb

local function lighten(c: Color3, amount: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), amount)
end
local function darken(c: Color3, amount: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), amount)
end
OutdoorKit.lighten = lighten
OutdoorKit.darken = darken

function OutdoorKit.part(parent: Instance, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Decoration: never collides, never eats a click meant for an enemy.
function OutdoorKit.decor(parent: Instance, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = OutdoorKit.part(parent, cf, size, color, material)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

-- Floating world text, the way the reference game labels everything. Uses a
-- BillboardGui so it always faces the camera and stays readable at distance.
function OutdoorKit.label(
	parent: Instance,
	cf: CFrame,
	text: string,
	color: Color3,
	textSize: number?,
	studWidth: number?
): BasePart
	local anchor = Instance.new("Part")
	anchor.Name = "LabelAnchor"
	anchor.Anchored = true
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = cf
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Parent = parent

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.Size = UDim2.fromScale(studWidth or 12, (studWidth or 12) * 0.32)
	billboard.SizeOffset = Vector2.new(0, 0)
	billboard.MaxDistance = 320
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = DISPLAY_FONT
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(20, 20, 28)
	label.Parent = label.Parent or billboard
	label.Parent = billboard

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = textSize or 42
	constraint.Parent = label

	return anchor
end

-- The ground you stand on. One thick slab so nothing can fall between seams.
function OutdoorKit.ground(parent: Instance, base: CFrame, cx: number, cz: number, sx: number, sz: number, color: Color3): Part
	local slab = OutdoorKit.part(parent, base * CFrame.new(cx, -2, cz), Vector3.new(sx, 4, sz), color)
	slab.Name = "Ground"
	return slab
end

-- A raised tiled deck: the white plaza the shops sit on in the reference game.
function OutdoorKit.plaza(
	parent: Instance,
	base: CFrame,
	cx: number,
	cz: number,
	sx: number,
	sz: number,
	color: Color3,
	accent: Color3
): Part
	local deck = OutdoorKit.part(parent, base * CFrame.new(cx, 0.3, cz), Vector3.new(sx, 1.2, sz), color)
	deck.Name = "Plaza"
	-- Tile seams: thin darker lines across the deck, purely visual.
	local seams = math.max(1, math.floor(sx / 12))
	for i = 1, seams do
		local px = cx - sx / 2 + i * (sx / (seams + 1))
		OutdoorKit.decor(parent, base * CFrame.new(px, 0.92, cz), Vector3.new(0.3, 0.08, sz - 1), darken(color, 0.12))
	end
	local rows = math.max(1, math.floor(sz / 12))
	for i = 1, rows do
		local pz = cz - sz / 2 + i * (sz / (rows + 1))
		OutdoorKit.decor(parent, base * CFrame.new(cx, 0.92, pz), Vector3.new(sx - 1, 0.08, 0.3), darken(color, 0.12))
	end
	-- Kerb around the edge in the theme accent.
	for _, edge in
		{
			{ cx, cz - sz / 2 - 0.4, sx + 1.6, 0.8 },
			{ cx, cz + sz / 2 + 0.4, sx + 1.6, 0.8 },
		}
	do
		OutdoorKit.decor(parent, base * CFrame.new(edge[1], 0.5, edge[2]), Vector3.new(edge[3], 1.4, edge[4]), accent)
	end
	for _, edge in { cx - sx / 2 - 0.4, cx + sx / 2 + 0.4 } do
		OutdoorKit.decor(parent, base * CFrame.new(edge, 0.5, cz), Vector3.new(0.8, 1.4, sz + 1.6), accent)
	end
	return deck
end

-- The stepped brick canyon wall that boxes every area in. Layered blocks with a
-- grass lip on top, like the reference game's cliffs.
function OutdoorKit.cliffWall(
	parent: Instance,
	base: CFrame,
	cx: number,
	cz: number,
	sx: number,
	sz: number,
	height: number,
	brick: Color3,
	top: Color3
): Model
	local model = Instance.new("Model")
	model.Name = "Cliff"
	model.Parent = parent

	-- Three stepped tiers so the wall reads as carved rock, not a flat slab.
	local tiers = 3
	for tier = 1, tiers do
		local inset = (tier - 1) * 3
		local tierHeight = height / tiers
		local y = (tier - 1) * tierHeight + tierHeight / 2
		local shade = if tier % 2 == 0 then lighten(brick, 0.06) else brick
		local block = OutdoorKit.part(
			model,
			base * CFrame.new(cx, y, cz),
			Vector3.new(sx - inset * (if sx > sz then 0 else 2), tierHeight, sz - inset * (if sz > sx then 0 else 2)),
			shade
		)
		block.Name = "Tier" .. tier
	end
	-- Grass lip on top.
	local lip = OutdoorKit.part(
		model,
		base * CFrame.new(cx, height + 0.6, cz),
		Vector3.new(sx - (tiers - 1) * (if sx > sz then 0 else 6) + 1, 1.2, sz - (tiers - 1) * (if sz > sx then 0 else 6) + 1),
		top
	)
	lip.Name = "Lip"
	return model
end

function OutdoorKit.tree(parent: Instance, base: CFrame, x: number, z: number, scale: number, trunk: Color3, leaf: Color3): Model
	local model = Instance.new("Model")
	model.Name = "Tree"
	model.Parent = parent
	OutdoorKit.part(model, base * CFrame.new(x, 3 * scale, z), Vector3.new(1.6 * scale, 6 * scale, 1.6 * scale), trunk)
	-- Three stacked slabs of foliage: cheap, chunky, unmistakably cartoon.
	local tiers = { { 9, 2.4, 6.6 }, { 7, 2.2, 8.4 }, { 4.6, 2, 9.9 } }
	for i, tier in tiers do
		local shade = if i == 2 then lighten(leaf, 0.08) else leaf
		OutdoorKit.decor(
			model,
			base * CFrame.new(x, tier[3] * scale, z),
			Vector3.new(tier[1] * scale, tier[2] * scale, tier[1] * scale),
			shade
		)
	end
	return model
end

function OutdoorKit.building(
	parent: Instance,
	base: CFrame,
	x: number,
	z: number,
	w: number,
	h: number,
	d: number,
	body: Color3,
	accent: Color3,
	windows: boolean?
): Model
	local model = Instance.new("Model")
	model.Name = "Building"
	model.Parent = parent
	OutdoorKit.part(model, base * CFrame.new(x, h / 2, z), Vector3.new(w, h, d), body)
	-- Parapet + door so it reads as a building rather than a box.
	OutdoorKit.decor(model, base * CFrame.new(x, h + 0.5, z), Vector3.new(w + 1.2, 1, d + 1.2), accent)
	OutdoorKit.decor(model, base * CFrame.new(x, 3, z - d / 2 - 0.2), Vector3.new(4, 6, 0.4), darken(body, 0.4))
	if windows ~= false then
		local cols = math.max(1, math.floor(w / 6))
		local rows = math.max(1, math.floor(h / 7))
		for row = 1, rows do
			for col = 1, cols do
				local wx = x - w / 2 + col * (w / (cols + 1))
				local wy = row * (h / (rows + 1)) + 2
				OutdoorKit.decor(
					model,
					base * CFrame.new(wx, wy, z - d / 2 - 0.25),
					Vector3.new(2.6, 3, 0.3),
					lighten(accent, 0.25),
					Enum.Material.Neon
				)
			end
		end
	end
	return model
end

-- The white arrow trail that shows a new player where to walk.
function OutdoorKit.arrowTrail(parent: Instance, base: CFrame, x1: number, z1: number, x2: number, z2: number, count: number?): Folder
	local folder = Instance.new("Folder")
	folder.Name = "ArrowTrail"
	folder.Parent = parent
	local n = count or 12
	local dx, dz = x2 - x1, z2 - z1
	local yaw = math.atan2(dx, dz)
	for i = 0, n - 1 do
		local t = i / n
		local arrow = OutdoorKit.decor(
			folder,
			base * CFrame.new(x1 + dx * t, 0.12, z1 + dz * t) * CFrame.Angles(0, yaw, 0),
			Vector3.new(2.6, 0.15, 3.4),
			Color3.fromRGB(255, 255, 255)
		)
		arrow.Name = "Arrow"
		arrow.Transparency = 0.15
	end
	return folder
end

-- A coloured floor pad with floating text above it — the shape the reference
-- game uses for training zones, win pads and shop stands alike.
function OutdoorKit.pad(
	parent: Instance,
	base: CFrame,
	x: number,
	z: number,
	size: number,
	color: Color3,
	topText: string?,
	bottomText: string?
): Part
	local pad = OutdoorKit.part(parent, base * CFrame.new(x, 0.35, z), Vector3.new(size, 0.7, size), color, Enum.Material.Neon)
	pad.Name = "Pad"
	pad.CanCollide = false
	-- Dark rim so a bright pad still reads against bright ground.
	OutdoorKit.decor(parent, base * CFrame.new(x, 0.2, z), Vector3.new(size + 1.6, 0.5, size + 1.6), darken(color, 0.55))
	if topText then
		OutdoorKit.label(parent, base * CFrame.new(x, 7.4, z), topText, lighten(color, 0.55), 44, 14)
	end
	if bottomText then
		OutdoorKit.label(parent, base * CFrame.new(x, 5.4, z), bottomText, Color3.fromRGB(255, 255, 255), 30, 13)
	end
	return pad
end

-- A training bag on its stand. Returns the model and the TOUCH pad, which is
-- what TrainingService listens to.
function OutdoorKit.punchingBag(
	parent: Instance,
	base: CFrame,
	x: number,
	z: number,
	color: Color3,
	name: string,
	valueText: string
): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "TrainingBag_" .. name
	model.Parent = parent

	local frameColor = darken(color, 0.4)
	-- Gallows frame: two uprights and a beam, exactly like the reference art.
	OutdoorKit.part(model, base * CFrame.new(x - 4.2, 6, z), Vector3.new(1.2, 12, 1.2), frameColor)
	OutdoorKit.part(model, base * CFrame.new(x + 4.2, 6, z), Vector3.new(1.2, 12, 1.2), frameColor)
	OutdoorKit.decor(model, base * CFrame.new(x, 12.2, z), Vector3.new(10, 1.2, 1.6), frameColor)
	-- Chain and bag.
	OutdoorKit.decor(model, base * CFrame.new(x, 10.6, z), Vector3.new(0.5, 2, 0.5), Color3.fromRGB(190, 194, 200))
	local bag = OutdoorKit.decor(model, base * CFrame.new(x, 7.4, z), Vector3.new(4.4, 6.4, 4.4), color)
	bag.Name = "Bag"
	OutdoorKit.decor(model, base * CFrame.new(x, 10.2, z), Vector3.new(3.4, 1, 3.4), lighten(color, 0.3))
	OutdoorKit.decor(model, base * CFrame.new(x, 4.4, z), Vector3.new(3.6, 1, 3.6), darken(color, 0.25))

	-- Stand-on pad: this is the interactive part.
	local pad = OutdoorKit.pad(model, base, x, z + 5.5, 10, color, valueText, name)
	pad.Name = "BagPad"
	model.PrimaryPart = pad
	return model, pad
end

-- The big entry arch that names a stage and its recommended power.
function OutdoorKit.stageArch(
	parent: Instance,
	base: CFrame,
	x: number,
	title: string,
	subtitle: string,
	accent: Color3,
	stone: Color3
): Model
	local model = Instance.new("Model")
	model.Name = "StageArch"
	model.Parent = parent
	for _, side in { -1, 1 } do
		OutdoorKit.part(model, base * CFrame.new(x, 11, side * 34), Vector3.new(5, 22, 8), stone)
		OutdoorKit.decor(model, base * CFrame.new(x, 22.4, side * 34), Vector3.new(6.4, 1.6, 9.4), accent)
	end
	OutdoorKit.decor(model, base * CFrame.new(x, 23.5, 0), Vector3.new(5, 2.2, 68), stone)
	OutdoorKit.label(parent, base * CFrame.new(x, 30, 0), title, accent, 64, 30)
	OutdoorKit.label(parent, base * CFrame.new(x, 26.5, 0), subtitle, Color3.fromRGB(255, 255, 255), 34, 28)
	return model
end

-- The wall that stops you leaving a stage before you have cleared it. Returns
-- the model and the blocking slab, which StageService toggles.
function OutdoorKit.barrier(
	parent: Instance,
	base: CFrame,
	x: number,
	width: number,
	height: number,
	color: Color3,
	text: string
): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "StageBarrier"
	model.Parent = parent
	local slab = OutdoorKit.part(model, base * CFrame.new(x, height / 2, 0), Vector3.new(2, height, width), color, Enum.Material.Neon)
	slab.Name = "Blocker"
	slab.Transparency = 0.55
	slab.CanQuery = false
	OutdoorKit.label(parent, base * CFrame.new(x, height + 3, 0), text, Color3.fromRGB(255, 120, 120), 40, 24)
	model.PrimaryPart = slab
	return model, slab
end

function OutdoorKit.podium(parent: Instance, base: CFrame, x: number, z: number, color: Color3): Part
	local pad = OutdoorKit.part(parent, base * CFrame.new(x, 0.4, z), Vector3.new(7, 0.8, 7), color, Enum.Material.Neon)
	pad.Name = "Podium"
	pad.CanCollide = false
	OutdoorKit.decor(parent, base * CFrame.new(x, 0.2, z), Vector3.new(8.4, 0.5, 8.4), darken(color, 0.6))
	return pad
end

-- A blocky mannequin wearing a skin, for the shop wall and for enemies.
function OutdoorKit.dummy(
	parent: Instance,
	base: CFrame,
	x: number,
	z: number,
	yawDeg: number,
	shirt: Color3,
	trousers: Color3,
	accent: Color3,
	glow: boolean?
): Model
	local model = Instance.new("Model")
	model.Name = "Dummy"
	model.Parent = parent
	local cf = base * CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yawDeg), 0)
	local skinTone = Color3.fromRGB(234, 190, 152)
	local material = if glow then Enum.Material.Neon else Enum.Material.SmoothPlastic

	local torso = OutdoorKit.decor(model, cf * CFrame.new(0, 4.6, 0), Vector3.new(3.4, 3.6, 1.8), shirt, material)
	torso.Name = "Torso"
	-- Legs
	OutdoorKit.decor(model, cf * CFrame.new(-0.9, 1.5, 0), Vector3.new(1.4, 3.4, 1.6), trousers)
	OutdoorKit.decor(model, cf * CFrame.new(0.9, 1.5, 0), Vector3.new(1.4, 3.4, 1.6), trousers)
	-- Arms
	OutdoorKit.decor(model, cf * CFrame.new(-2.3, 4.6, 0), Vector3.new(1.2, 3.4, 1.6), shirt, material)
	OutdoorKit.decor(model, cf * CFrame.new(2.3, 4.6, 0), Vector3.new(1.2, 3.4, 1.6), shirt, material)
	-- Head + tie
	OutdoorKit.decor(model, cf * CFrame.new(0, 7.4, 0), Vector3.new(2, 2, 2), skinTone)
	OutdoorKit.decor(model, cf * CFrame.new(0, 4.9, -0.95), Vector3.new(0.5, 2.6, 0.2), accent, if glow then Enum.Material.Neon else nil)
	model.PrimaryPart = torso
	return model
end

function OutdoorKit.briefcase(parent: Instance, base: CFrame, x: number, z: number, color: Color3): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "Briefcase"
	model.Parent = parent
	local body = OutdoorKit.decor(model, base * CFrame.new(x, 4.4, z), Vector3.new(7, 5, 2.6), color)
	OutdoorKit.decor(model, base * CFrame.new(x, 4.4, z), Vector3.new(7.3, 0.6, 2.9), darken(color, 0.4))
	OutdoorKit.decor(model, base * CFrame.new(x, 7.4, z), Vector3.new(2.2, 1.6, 0.6), darken(color, 0.3))
	for _, dx in { -1.8, 1.8 } do
		OutdoorKit.decor(model, base * CFrame.new(x + dx, 5.6, z - 1.4), Vector3.new(1, 0.8, 0.4), lighten(color, 0.4), Enum.Material.Neon)
	end
	OutdoorKit.decor(model, base * CFrame.new(x, 1, z), Vector3.new(2, 2, 2), darken(color, 0.5))
	model.PrimaryPart = body
	return model, body
end

-- A TOP-100 style leaderboard pillar with a lit screen.
function OutdoorKit.pillar(
	parent: Instance,
	base: CFrame,
	x: number,
	z: number,
	height: number,
	title: string,
	body: Color3,
	accent: Color3
): Model
	local model = Instance.new("Model")
	model.Name = "LeaderPillar"
	model.Parent = parent
	OutdoorKit.part(model, base * CFrame.new(x, 1, z), Vector3.new(11, 2, 7), darken(body, 0.2))
	OutdoorKit.part(model, base * CFrame.new(x, height / 2 + 2, z), Vector3.new(9, height, 4), body)
	local screen = OutdoorKit.decor(
		model,
		base * CFrame.new(x, height / 2 + 3, z - 2.1),
		Vector3.new(7.4, height - 5, 0.4),
		Color3.fromRGB(46, 96, 168),
		Enum.Material.Neon
	)
	screen.Name = "Screen"
	OutdoorKit.decor(model, base * CFrame.new(x, height + 2.6, z), Vector3.new(10.4, 1.4, 5.4), accent)
	OutdoorKit.label(parent, base * CFrame.new(x, height + 5, z), title, accent, 34, 18)
	model.PrimaryPart = screen
	return model
end

-- The FREE POWER chest from the reference hub.
function OutdoorKit.chest(parent: Instance, base: CFrame, x: number, z: number, accent: Color3): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "PowerChest"
	model.Parent = parent
	local gold = Color3.fromRGB(255, 196, 40)
	local body = OutdoorKit.part(model, base * CFrame.new(x, 2.6, z), Vector3.new(9, 5, 6), gold)
	OutdoorKit.decor(model, base * CFrame.new(x, 5.6, z), Vector3.new(9.4, 1.6, 6.4), darken(gold, 0.25))
	OutdoorKit.decor(model, base * CFrame.new(x, 3.2, z - 3.1), Vector3.new(2, 2.4, 0.5), darken(gold, 0.45))
	-- Coins spilling out of it.
	for i = 1, 6 do
		local angle = i * math.pi / 3
		OutdoorKit.decor(
			model,
			base * CFrame.new(x + math.cos(angle) * 5.5, 0.6, z + math.sin(angle) * 4),
			Vector3.new(1.6, 0.5, 1.6),
			lighten(gold, 0.2),
			Enum.Material.Neon
		)
	end
	OutdoorKit.label(parent, base * CFrame.new(x, 8.6, z), "FREE POWER", accent, 40, 16)
	model.PrimaryPart = body
	return model, body
end

function OutdoorKit.stairs(
	parent: Instance,
	base: CFrame,
	x: number,
	z: number,
	steps: number,
	width: number,
	rise: number,
	run: number,
	color: Color3,
	yawDeg: number?
): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Stairs"
	folder.Parent = parent
	local yaw = math.rad(yawDeg or 0)
	for i = 1, steps do
		local depth = (i - 0.5) * run
		local height = i * rise
		OutdoorKit.part(
			folder,
			base * CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, height - rise / 2, -depth),
			Vector3.new(width, rise, run),
			if i % 2 == 0 then lighten(color, 0.05) else color
		)
	end
	return folder
end

-- Invisible wall. The only thing standing between a player and the void.
function OutdoorKit.fence(parent: Instance, base: CFrame, x: number, z: number, length: number, yawDeg: number, color: Color3): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Fence"
	folder.Parent = parent
	local wall = OutdoorKit.part(
		folder,
		base * CFrame.new(x, 12, z) * CFrame.Angles(0, math.rad(yawDeg), 0),
		Vector3.new(1, 24, length),
		color
	)
	wall.Name = "SafetyWall"
	wall.Transparency = 1
	wall.CanQuery = false
	return folder
end

return OutdoorKit
