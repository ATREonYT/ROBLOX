--!strict
-- 88 — THE PENTHOUSE. White marble and gold, floor-to-ceiling glass on the
-- north and west walls, and a terrace through the south wall carrying the
-- infinity pool and the helipad. The BOARD WING is one 300-stud boardroom
-- table you fight your way down, ending at Maximilian's vault.
--
-- Layout follows DESIGN-MAP.md: hub 150x150 centred on origin, wing out the
-- EAST wall (5 x 66-stud segments, 48 wide), boss office (60x60) at the far
-- end. Everything composes off `origin` — no world coordinates.
--
-- Palette note: on this floor palette.Dark is POOL CYAN, not a shadow tone
-- (see Config/Palettes). Shadow/leg colours are derived from the marble
-- instead, and palette.Dark is reserved for water and glass tint.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(script.Parent.Parent.Kit)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Palettes = require(ReplicatedStorage.Shared.Config.Palettes)
local Rivals = require(ReplicatedStorage.Shared.Config.Rivals)
local Format = require(ReplicatedStorage.Shared.Util.Format)

-- Local copy of the CONTRACTS.md manifest shape (requiring MapService for its
-- export would be circular — MapService requires this module).
type Manifest = {
	Spawn: CFrame,
	RivalSpots: { { DefIndex: number, Cf: CFrame } },
	TrainingZones: { { Rate: number, MinRank: number, Zone: BasePart } },
	PaydayPads: { { Segment: number, Pad: BasePart } },
	Prompts: { Shop: BasePart, Coffee: BasePart, Hr: BasePart, Elevator: BasePart },
	Boards: { Eotm: BasePart, Wins: BasePart },
}

-- ── Layout constants (all relative to origin) ──────────────────────────────
local HUB_SIZE = 150
local HUB_H = 22 -- the tallest hub in the tower: this floor is about air
local WING_LEN = 330 -- 5 segments x 66
local WING_W = 48
local WING_H = 16
local WING_START_X = HUB_SIZE / 2 -- corridor slab butts the hub slab at x=75
local BOSS_SIZE = 60
local BOSS_H = 20
local BOSS_CX = WING_START_X + WING_LEN + BOSS_SIZE / 2 -- 435

-- Prop-top heights, so clutter never floats or sinks.
local ON_DESK = 1.98
local ON_TALL_DESK = 3.08
local ON_BOARD_TABLE = 2.68
local ON_BOSS_DESK = 3.08

local RIVAL_Y = 2.5
local TRIM_Y = 2.6 -- the gold line that circles every wall

-- The terrace sits south of the hub, one shallow step down from the marble.
local TERRACE_Z = HUB_SIZE / 2 + 46 -- centre of the terrace slab
local TERRACE_Y = -0.6

local function build(parent: Folder, origin: Vector3, palette: Palettes.Palette): Manifest
	local base = CFrame.new(origin)

	local groundCol = Palettes.color(palette.Ground)
	local accentCol = Palettes.color(palette.Accent) -- gold
	local primaryCol = Palettes.color(palette.Primary)
	local waterCol = Palettes.color(palette.Dark) -- cyan: pool + glass tint only

	local function lighten(c: Color3, amount: number): Color3
		return c:Lerp(Color3.new(1, 1, 1), amount)
	end
	local function darken(c: Color3, amount: number): Color3
		return c:Lerp(Color3.new(0, 0, 0), amount)
	end

	-- Structural "dark" for this floor is warm stone shadow, never the cyan.
	local stoneCol = darken(primaryCol, 0.45)
	local veinCol = darken(groundCol, 0.12) -- marble veining

	local function place(x: number, y: number, z: number, yawDeg: number?): CFrame
		local cf = base * CFrame.new(x, y, z)
		if yawDeg and yawDeg ~= 0 then
			cf = cf * CFrame.Angles(0, math.rad(yawDeg), 0)
		end
		return cf
	end

	local rivalSpots: { { DefIndex: number, Cf: CFrame } } = {}
	local trainingZones: { { Rate: number, MinRank: number, Zone: BasePart } } = {}
	local paydayPads: { { Segment: number, Pad: BasePart } } = {}

	local function primaryOf(model: Model): BasePart
		local part = model.PrimaryPart
		assert(part, "Kit prop is missing a PrimaryPart")
		return part
	end

	-- Decorative parts never collide and never eat clicks meant for rivals.
	local function decor(cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?): BasePart
		local part = Kit.part(parent, cf, size, color, material)
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
		return part
	end

	-- Flat disc lying face-up. Cylinders are born standing on their X axis, so
	-- the roll of 90 degrees is what lays them down; Kit.part returns a
	-- BasePart, hence the cast to reach Shape.
	local function disc(x: number, y: number, z: number, diameter: number, thickness: number, color: Color3, material: Enum.Material?): Part
		local part = Kit.part(
			parent,
			place(x, y, z) * CFrame.Angles(0, 0, math.rad(90)),
			Vector3.new(thickness, diameter, diameter),
			color,
			material
		) :: Part
		part.Shape = Enum.PartType.Cylinder
		return part
	end

	-- ── Shared helpers ────────────────────────────────────────────────────

	-- Invisible training-zone volume: ProductivityService AABB-checks against
	-- it, so it must never collide, query, or render.
	local function trainingZone(name: string, x: number, z: number, sx: number, sz: number): BasePart
		local zone = Instance.new("Part")
		zone.Name = name
		zone.Anchored = true
		zone.Transparency = 1
		zone.CanCollide = false
		zone.CanQuery = false
		zone.CanTouch = false
		zone.CastShadow = false
		zone.Size = Vector3.new(sx, 6, sz)
		zone.CFrame = place(x, 3, z)
		zone.Parent = parent
		return zone
	end

	-- Ceiling-hung tier sign on gold rods, readable from both sides.
	local function hangingSign(x: number, z: number, yawDeg: number, text: string)
		local board = decor(place(x, 10.5, z, yawDeg), Vector3.new(8, 1.8, 0.3), primaryCol)
		Kit.textLabelOn(board, Enum.NormalId.Front, text, darken(accentCol, 0.25))
		Kit.textLabelOn(board, Enum.NormalId.Back, text, darken(accentCol, 0.25))
		for _, dx in { -3.2, 3.2 } do
			decor(place(x, 16.2, z, yawDeg) * CFrame.new(dx, 0, 0), Vector3.new(0.12, 11.4, 0.12), accentCol, Enum.Material.Neon)
		end
	end

	-- Tier-1: pale marble-topped desk on gold legs.
	local function luxDesk(x: number, z: number, yawDeg: number, clutter: number)
		local cf = place(x, 0, z, yawDeg)
		Kit.desk(parent, cf, palette)
		Kit.officeChair(parent, cf * CFrame.new(0, 0, 2.0), palette, primaryCol)
		Kit.monitor(parent, cf * CFrame.new(0, ON_DESK, 0.15) * CFrame.Angles(0, math.rad(180), 0), palette)
		Kit.keyboardProp(parent, cf * CFrame.new(0, ON_DESK, 0.62), palette)
		Kit.trimStrip(parent, cf * CFrame.new(0, 0.35, -1.08), palette, 3.6)
		if clutter == 1 then
			Kit.mug(parent, cf * CFrame.new(1.3, ON_DESK, 0.3), palette)
		elseif clutter == 2 then
			Kit.paperStack(parent, cf * CFrame.new(-1.2, ON_DESK, 0.1), palette)
		end
	end

	-- Tier-2: raised marble slab on gold columns, dual screens.
	local function tallDesk(x: number, z: number, yawDeg: number)
		local cf = place(x, 0, z, yawDeg)
		for _, dx in { -1.7, 1.7 } do
			decor(cf * CFrame.new(dx, 1.2, 0), Vector3.new(0.3, 2.4, 0.3), accentCol, Enum.Material.Neon)
		end
		Kit.bevelBlock(parent, cf * CFrame.new(0, 2.65, 0), Vector3.new(4.2, 0.5, 2.1), groundCol)
		Kit.monitor(parent, cf * CFrame.new(-0.9, ON_TALL_DESK, 0.15) * CFrame.Angles(0, math.rad(186), 0), palette)
		Kit.monitor(parent, cf * CFrame.new(0.9, ON_TALL_DESK, 0.15) * CFrame.Angles(0, math.rad(174), 0), palette)
		Kit.keyboardProp(parent, cf * CFrame.new(0, ON_TALL_DESK, 0.62), palette)
		Kit.mug(parent, cf * CFrame.new(1.5, ON_TALL_DESK, 0.35), palette)
		decor(cf * CFrame.new(0, 0.06, 1.9), Vector3.new(3.8, 0.12, 2.2), lighten(accentCol, 0.25))
	end

	-- Tier-3: a marble console on its own gold-edged rug, triple screens.
	local function battlestation(x: number, z: number)
		local aCf = place(x, 0, z, -90)
		local bCf = place(x, 0, z + 4.1, -90)
		Kit.rug(parent, place(x - 1, 0, z + 2), palette, 9, 11)
		Kit.desk(parent, aCf, palette)
		Kit.desk(parent, bCf, palette)
		Kit.monitor(parent, aCf * CFrame.new(-0.9, ON_DESK, 0.15) * CFrame.Angles(0, math.rad(192), 0), palette)
		Kit.monitor(parent, aCf * CFrame.new(0.9, ON_DESK, 0.15) * CFrame.Angles(0, math.rad(168), 0), palette)
		Kit.monitor(parent, bCf * CFrame.new(0, ON_DESK, 0.15) * CFrame.Angles(0, math.rad(180), 0), palette)
		Kit.keyboardProp(parent, aCf * CFrame.new(0, ON_DESK, 0.62), palette)
		Kit.paperStack(parent, bCf * CFrame.new(-1.2, ON_DESK, 0.2), palette)
		Kit.officeChair(parent, place(x - 2, 0, z + 2.05, -90), palette, primaryCol)
		Kit.trimStrip(parent, aCf * CFrame.new(0, 0.35, -1.08), palette, 3.6)
		Kit.trimStrip(parent, bCf * CFrame.new(0, 0.35, -1.08), palette, 3.6)
	end

	-- ═══════════════════════════ HUB SHELL ════════════════════════════════

	local hubDoors: { Kit.RoomDoor } = {
		{ Wall = "E", Width = 14 }, -- to the BOARD WING
		{ Wall = "S", Offset = 0, Width = 16 }, -- out to the terrace
	}
	Kit.room(parent, base, HUB_SIZE, HUB_H, HUB_SIZE, palette, { doors = hubDoors, ceiling = true })

	-- Floor-to-ceiling glass on the north and west walls. windowWall segments
	-- sit just inside the shell so the marble frame still reads at the corners.
	for _, wx in { -52, -26, 0, 26, 52 } do
		Kit.windowWall(parent, place(wx, 0, -74.2), palette, 24, HUB_H - 1)
	end
	for _, wz in { -52, -26, 0, 26, 52 } do
		Kit.windowWall(parent, place(-74.2, 0, wz, 90), palette, 24, HUB_H - 1)
	end

	-- Gold trim chases every wall at waist height, and again at the ceiling.
	for _, seg in { { 0, -73.6, 0 }, { -73.6, 0, 90 }, { 73.6, 0, 90 } } do
		Kit.trimStrip(parent, place(seg[1], TRIM_Y, seg[2], seg[3]), palette, 146)
		Kit.trimStrip(parent, place(seg[1], HUB_H - 1.4, seg[2], seg[3]), palette, 146)
	end

	-- Marble veining: long pale streaks inlaid into the floor slab.
	for i = 1, 14 do
		local vx = -66 + (i - 1) * 10
		decor(place(vx, 0.06, -30 + (i % 5) * 12, 8 + (i % 3) * 14), Vector3.new(0.5, 0.06, 26 + (i % 4) * 9), veinCol)
	end

	-- Marble pillars ring the room without blocking sightlines to the glass.
	for _, spot in { { -46, -46 }, { 46, -46 }, { -46, 46 }, { 46, 46 } } do
		Kit.pillar(parent, place(spot[1], 0, spot[2]), palette, HUB_H)
		Kit.trimStrip(parent, place(spot[1], HUB_H - 2.2, spot[2]), palette, 3)
	end

	-- ── Spawn ─────────────────────────────────────────────────────────────

	Kit.spawnPad(parent, place(0, 0, 0), palette)
	Kit.rug(parent, place(0, 0, 0), palette, 26, 26)
	-- Face west: the training floor and the glass sell themselves.
	local spawnCf = place(0, 3.2, 0, 90)

	-- ── Elevator + boards (north wall) ────────────────────────────────────

	Kit.elevatorDoors(parent, place(0, 0, -73, 180), palette)
	local panelModel = Kit.elevatorPanel(parent, place(7.5, 5, -73.75, 180), palette)
	Kit.trimStrip(parent, place(0, 11.2, -73.6), palette, 20)
	Kit.neonSign(parent, place(0, 13.4, -73.4, 180), palette, "THE PENTHOUSE — 88", accentCol)

	local eotmModel, _eotmContent = Kit.boardFrame(parent, place(-22, 6, -73.7, 180), palette, "EMPLOYEE OF THE MONTH")
	local winsModel, _winsContent = Kit.boardFrame(parent, place(22, 6, -73.7, 180), palette, "ALL-TIME WINS")
	for _, bx in { -22, 22 } do
		Kit.pottedPlant(parent, place(bx - 7.5, 0, -70), palette)
		Kit.pottedPlant(parent, place(bx + 7.5, 0, -70), palette)
	end

	-- ═══════════════════════════ THE TERRACE ══════════════════════════════
	-- Through the south doorway: infinity pool + helipad, open to the sky.

	local terraceW, terraceL = 120, 84
	local terraceSlab = Kit.part(
		parent,
		place(0, TERRACE_Y - 0.5, TERRACE_Z),
		Vector3.new(terraceW, 1, terraceL),
		lighten(groundCol, 0.04)
	)
	terraceSlab.Name = "TerraceSlab"
	-- One shallow step down from the hub marble, so the doorway is walkable.
	decor(place(0, -0.3, HUB_SIZE / 2 + 2), Vector3.new(20, 0.6, 4), groundCol)

	-- Glass balustrade around the open edges — nobody falls off floor 88.
	for _, rail in
		{
			{ 0, TERRACE_Z + terraceL / 2, 0, terraceW },
			{ -terraceW / 2, TERRACE_Z, 90, terraceL },
			{ terraceW / 2, TERRACE_Z, 90, terraceL },
		}
	do
		local glass = Kit.part(
			parent,
			place(rail[1], TERRACE_Y + 2.5, rail[2], rail[3]),
			Vector3.new(rail[4], 5, 0.4),
			waterCol,
			Enum.Material.Glass
		)
		glass.Transparency = 0.6
		glass.CanQuery = false
		-- Gold cap rail on top of the glass.
		decor(place(rail[1], TERRACE_Y + 5.2, rail[2], rail[3]), Vector3.new(rail[4], 0.4, 0.7), accentCol)
	end

	-- The infinity pool: a Neon cyan slab in a gold rim, shimmering client-side.
	local poolCx, poolCz = -28, TERRACE_Z + 4
	local poolW, poolL = 46, 26
	local water = Kit.part(
		parent,
		place(poolCx, TERRACE_Y + 0.15, poolCz),
		Vector3.new(poolW, 0.5, poolL),
		waterCol,
		Enum.Material.Neon
	)
	water.Name = "InfinityPool"
	water.Transparency = 0.25
	water.CanCollide = false
	water.CanQuery = false
	CollectionService:AddTag(water, "WaterShimmer")
	-- Gold rim: four strips flush around the water, raised a hair to avoid
	-- z-fighting with the terrace slab.
	for _, rim in
		{
			{ poolCx, poolCz - poolL / 2 - 0.7, 0, poolW + 3 },
			{ poolCx, poolCz + poolL / 2 + 0.7, 0, poolW + 3 },
			{ poolCx - poolW / 2 - 0.7, poolCz, 90, poolL + 3 },
			{ poolCx + poolW / 2 + 0.7, poolCz, 90, poolL + 3 },
		}
	do
		decor(place(rim[1], TERRACE_Y + 0.35, rim[2], rim[3]), Vector3.new(rim[4], 0.5, 1.4), accentCol)
	end
	-- Loungers along the pool's north edge.
	for _, lx in { -46, -36, -26, -16 } do
		decor(place(lx, TERRACE_Y + 0.6, poolCz - 17), Vector3.new(2.4, 0.5, 5.5), lighten(primaryCol, 0.2))
		decor(place(lx, TERRACE_Y + 1.3, poolCz - 19.2, 0) * CFrame.Angles(math.rad(-30), 0, 0), Vector3.new(2.4, 0.4, 3), lighten(primaryCol, 0.2))
		for _, dz in { -2, 2 } do
			decor(place(lx - 1, TERRACE_Y + 0.2, poolCz - 17 + dz), Vector3.new(0.25, 0.7, 0.25), accentCol)
			decor(place(lx + 1, TERRACE_Y + 0.2, poolCz - 17 + dz), Vector3.new(0.25, 0.7, 0.25), accentCol)
		end
	end

	-- The helipad: gold "H" on a dark disc, with landing lights.
	local padCx, padCz = 34, TERRACE_Z + 6
	local helipad = disc(padCx, TERRACE_Y + 0.1, padCz, 38, 0.4, darken(primaryCol, 0.55))
	helipad.Name = "Helipad"
	-- Painted circle + H, each layer proud of the one below.
	local painted = disc(padCx, TERRACE_Y + 0.35, padCz, 32, 0.2, lighten(accentCol, 0.1))
	painted.CanCollide = false
	painted.CanQuery = false
	local inner = disc(padCx, TERRACE_Y + 0.5, padCz, 28, 0.2, darken(primaryCol, 0.5))
	inner.CanCollide = false
	inner.CanQuery = false
	decor(place(padCx - 5, TERRACE_Y + 0.65, padCz), Vector3.new(2.5, 0.2, 16), accentCol)
	decor(place(padCx + 5, TERRACE_Y + 0.65, padCz), Vector3.new(2.5, 0.2, 16), accentCol)
	decor(place(padCx, TERRACE_Y + 0.65, padCz), Vector3.new(8, 0.2, 2.5), accentCol)
	for i = 0, 7 do
		local angle = i * math.pi / 4
		decor(
			place(padCx + math.cos(angle) * 18.5, TERRACE_Y + 0.6, padCz + math.sin(angle) * 18.5),
			Vector3.new(0.8, 0.8, 0.8),
			accentCol,
			Enum.Material.Neon
		)
	end
	-- Planters soften the gap between pool and helipad.
	for _, pz in { -14, 0, 14 } do
		Kit.pottedPlant(parent, place(4, TERRACE_Y + 0.5, TERRACE_Z + pz), palette)
	end

	-- ═══════════════════════════ HUB FIXTURES ═════════════════════════════

	-- East wall service row (the wing doorway sits between shop and HR).
	local shopKioskModel = Kit.shopKiosk(parent, place(68, 0, -32, 90), palette)
	Kit.neonSign(parent, place(66, 7.5, -32, 90), palette, "GEAR", accentCol)
	local coffeeModel = Kit.coffeeMachineBig(parent, place(67, 0, -16, 90), palette)
	Kit.neonSign(parent, place(66, 9.5, -16, 90), palette, "INTERNS", accentCol)
	local hrModel = Kit.hrDesk(parent, place(66, 0, 20, 90), palette)
	Kit.neonSign(parent, place(66, 6.5, 20, 90), palette, "RESTRUCTURING", accentCol)
	Kit.officeChair(parent, place(60, 0, 20, -90), palette, primaryCol)
	Kit.pottedPlant(parent, place(62, 0, -42), palette)
	Kit.pottedPlant(parent, place(62, 0, 34), palette)

	-- Concierge island: bookshelves and a sculpture nobody is allowed to touch.
	for _, sz in { -8, 8 } do
		Kit.bookshelf(parent, place(-30, 0, sz, 90), palette)
	end
	Kit.bevelBlock(parent, place(-30, 0.7, 0), Vector3.new(3, 1.4, 3), stoneCol)
	Kit.bevelBlock(parent, place(-30, 2.6, 0) * CFrame.Angles(0, math.rad(25), 0), Vector3.new(2, 2.4, 2), accentCol)
	Kit.bevelBlock(parent, place(-30, 4.5, 0) * CFrame.Angles(0, math.rad(-15), 0), Vector3.new(1.3, 1.6, 1.3), lighten(accentCol, 0.25))

	-- ── Training floor (west): 3 / 3 / 3 luxury tiers ─────────────────────

	local rates = Balance.TrainingTierRates
	local gates = Balance.TrainingTierMinRank

	-- Tier 1: three marble desks along the west glass.
	for i, dz in { -26, -14, -2 } do
		luxDesk(-56, dz, -90, i % 3)
	end
	table.insert(trainingZones, {
		Rate = rates[1],
		MinRank = gates[1],
		Zone = trainingZone("TrainZoneT1", -55, -14, 20, 44),
	})
	hangingSign(-55, -14, 0, ("+%dx TRAINING"):format(rates[1]))

	-- Tier 2: three raised desks deeper into the room.
	for _, dz in { 12, 24, 36 } do
		tallDesk(-56, dz, -90)
	end
	table.insert(trainingZones, {
		Rate = rates[2],
		MinRank = gates[2],
		Zone = trainingZone("TrainZoneT2", -55, 24, 20, 44),
	})
	hangingSign(-55, 24, 0, ("+%dx TRAINING · RANK %d+"):format(rates[2], gates[2]))

	-- Tier 3: three consoles in the north-west corner, the best seats on 88.
	for _, dz in { -56, -44, -32 } do
		battlestation(-28, dz)
	end
	table.insert(trainingZones, {
		Rate = rates[3],
		MinRank = gates[3],
		Zone = trainingZone("TrainZoneT3", -29, -42, 22, 40),
	})
	hangingSign(-29, -42, 0, ("+%dx TRAINING · RANK %d+"):format(rates[3], gates[3]))

	-- Wing signage over the east doorway.
	Kit.neonSign(parent, place(73.8, 14.5, 0, 90), palette, "BOARD WING", accentCol)
	Kit.trimStrip(parent, place(73.8, 12.8, 0, 90), palette, 15)

	-- ═══════════════════════════ BOARD WING ═══════════════════════════════

	local wingDoors: { Kit.RoomDoor } = { { Wall = "W", Width = 14 }, { Wall = "E", Width = 14 } }
	Kit.room(
		parent,
		base * CFrame.new(WING_START_X + WING_LEN / 2, 0, 0),
		WING_LEN,
		WING_H,
		WING_W,
		palette,
		{ doors = wingDoors, ceiling = true }
	)
	Kit.neonSign(parent, place(76.2, 13.6, 0, -90), palette, "BOARD WING", accentCol)
	Kit.trimStrip(parent, place(240, TRIM_Y, -22.85), palette, 326)
	Kit.trimStrip(parent, place(240, TRIM_Y, 22.85), palette, 326)

	-- THE boardroom table: 300 studs of polished marble down the middle, built
	-- from segments so the gate arches can pass between them.
	local tableSegments: { { number } } = {
		{ 108, 56 },
		{ 174, 56 },
		{ 240, 56 },
		{ 306, 56 },
		{ 368, 44 },
	}
	for _, seg in tableSegments do
		local cx, len = seg[1], seg[2]
		-- Marble top with a gold edge band and two plinth legs.
		Kit.bevelBlock(parent, place(cx, 2.4, 0), Vector3.new(len, 0.55, 7), groundCol)
		decor(place(cx, 2.05, -3.56), Vector3.new(len, 0.3, 0.35), accentCol)
		decor(place(cx, 2.05, 3.56), Vector3.new(len, 0.3, 0.35), accentCol)
		for _, lx in { cx - len / 2 + 6, cx + len / 2 - 6 } do
			Kit.part(parent, place(lx, 1.15, 0), Vector3.new(2.4, 2.3, 4), stoneCol)
		end
		-- Table dressing: water carafes and papers, alternating down its length.
		local pieces = math.floor(len / 14)
		for i = 0, pieces do
			local px = cx - len / 2 + 7 + i * 14
			if i % 2 == 0 then
				Kit.paperStack(parent, place(px, ON_BOARD_TABLE, -1.4), palette)
			else
				Kit.mug(parent, place(px, ON_BOARD_TABLE, 1.4), palette)
			end
		end
	end

	-- Chandelier clusters: gold rings of Neon panels down the wing ceiling.
	for _, cx in { 108, 174, 240, 306, 368 } do
		for i = 0, 5 do
			local angle = i * math.pi / 3
			Kit.ceilingLight(parent, place(cx + math.cos(angle) * 4.5, WING_H - 1.2, math.sin(angle) * 4.5), palette)
		end
		decor(place(cx, WING_H - 1.9, 0), Vector3.new(11, 0.35, 11), accentCol)
	end

	-- One rival seat: chair pulled out from the table, body standing behind it,
	-- facing across the table into the aisle.
	local function boardSeat(x: number, north: boolean): CFrame
		local z = if north then -6.4 else 6.4
		local yawDeg = if north then 180 else 0
		local seatCf = place(x, 0, z, yawDeg)
		Kit.officeChair(parent, seatCf, palette, primaryCol)
		-- Each seat gets its own place setting on the table edge.
		Kit.keyboardProp(parent, place(x, ON_BOARD_TABLE, if north then -2.6 else 2.6, yawDeg), palette)
		-- Nameplate: the joke is that every one of them is "SENIOR".
		local plate = decor(place(x, ON_BOARD_TABLE + 0.35, if north then -3.2 else 3.2, yawDeg), Vector3.new(2.6, 0.6, 0.25), accentCol)
		Kit.textLabelOn(plate, Enum.NormalId.Front, "SENIOR", darken(accentCol, 0.6))
		return place(x, RIVAL_Y, if north then -9.6 else 9.6, yawDeg)
	end

	-- Rival packs per the floor spec: seg1 def1 x3 · seg2 def2 x3 ·
	-- seg3 def3 x2 + def4 · seg4 def4 + def5 x2 · seg5 def6 x2.
	local stations: { { x: number, north: boolean, def: number } } = {
		{ x = 98, north = true, def = 1 },
		{ x = 112, north = false, def = 1 },
		{ x = 126, north = true, def = 1 },
		{ x = 164, north = false, def = 2 },
		{ x = 178, north = true, def = 2 },
		{ x = 192, north = false, def = 2 },
		{ x = 230, north = true, def = 3 },
		{ x = 244, north = false, def = 3 },
		{ x = 258, north = true, def = 4 },
		{ x = 296, north = false, def = 4 },
		{ x = 310, north = true, def = 5 },
		{ x = 324, north = false, def = 5 },
		{ x = 362, north = true, def = 6 },
		{ x = 380, north = false, def = 6 },
	}
	for _, st in stations do
		table.insert(rivalSpots, { DefIndex = st.def, Cf = boardSeat(st.x, st.north) })
	end

	-- Gates + payday pads. Labels advertise the NEXT pack so under-powered
	-- players self-select back to training — never a hard block (§5).
	local penthouseDefs = Rivals.ByFloor.Penthouse
	local gateXs: { number } = { 141, 207, 273, 339, 398 }
	local gateNextDef: { number } = { 2, 3, 5, 6, 7 }
	for k = 1, 5 do
		local gx = gateXs[k]
		local nextDef = penthouseDefs[gateNextDef[k]]
		local label = ("NEXT: %s — %s WORKLOAD"):format(nextDef.Title, Format.abbreviate(nextDef.Workload))
		Kit.gateArch(parent, place(gx, 0, 0, 90), palette, label)
		-- Pads alternate sides, always clear of the table and the walkway.
		local padZ = if k % 2 == 1 then 16 else -16
		local pad: BasePart = Kit.paydayPad(parent, place(gx, 0, padZ), palette)
		table.insert(paydayPads, { Segment = k, Pad = pad })
		Kit.pillar(parent, place(gx, 0, -20.5), palette, WING_H)
		Kit.pillar(parent, place(gx, 0, 20.5), palette, WING_H)
		Kit.pottedPlant(parent, place(gx - 6, 0, if padZ > 0 then -18 else 18), palette)
	end

	-- Gold-framed portraits of former chairmen glare down both corridor walls.
	for i, px in { 100, 150, 200, 250, 300, 350, 385 } do
		local pz = if i % 2 == 0 then -22.7 else 22.7
		local yaw = if i % 2 == 0 then 0 else 180
		local frame = decor(place(px, 8, pz, yaw), Vector3.new(7, 9, 0.4), accentCol)
		local canvas = decor(place(px, 8, if pz < 0 then pz + 0.3 else pz - 0.3, yaw), Vector3.new(6, 8, 0.2), darken(primaryCol, 0.25))
		Kit.textLabelOn(canvas, if pz < 0 then Enum.NormalId.Front else Enum.NormalId.Back, "CHAIRMAN " .. tostring(i), lighten(accentCol, 0.4))
		frame.Name = "PortraitFrame"
	end

	-- ═══════════════════════════ BOSS OFFICE ══════════════════════════════
	-- Maximilian's vault: gold doors, a dais, and no window at all — the only
	-- room on 88 that does not want you to see the sky.

	local bossDoors: { Kit.RoomDoor } = { { Wall = "W", Width = 14 } }
	Kit.room(
		parent,
		base * CFrame.new(BOSS_CX, 0, 0),
		BOSS_SIZE,
		BOSS_H,
		BOSS_SIZE,
		palette,
		{ doors = bossDoors, ceiling = true }
	)
	Kit.doubleDoor(parent, place(BOSS_CX - BOSS_SIZE / 2, 0, 0, 90), palette)
	Kit.neonSign(parent, place(BOSS_CX - BOSS_SIZE / 2 + 1.2, 12.5, 0, -90), palette, "THE VAULT", accentCol)

	-- Vault door motif on the back wall: concentric gold rings and a wheel.
	local vaultZ = BOSS_CX + BOSS_SIZE / 2 - 0.6
	for i, radius in { 16, 12.5, 9 } do
		-- Rings stand vertically against the wall: yaw the disc up onto its edge.
		local ring = Kit.part(
			parent,
			place(vaultZ - i * 0.12, 9, 0),
			Vector3.new(0.3, radius * 2, radius * 2),
			if i % 2 == 1 then accentCol else darken(accentCol, 0.35)
		) :: Part
		ring.Shape = Enum.PartType.Cylinder
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CastShadow = false
	end
	for i = 0, 5 do
		local angle = i * math.pi / 3
		decor(
			place(vaultZ - 0.5, 9 + math.sin(angle) * 7, math.cos(angle) * 7, 90),
			Vector3.new(0.4, 1.2, 5),
			lighten(accentCol, 0.2),
			Enum.Material.Neon
		)
	end

	-- The dais: three marble steps up to the desk, so Maximilian always looks
	-- down at you. Steps are real geometry — you walk up them to reach him.
	for i = 1, 3 do
		local stepW = 30 - (i - 1) * 4
		Kit.part(
			parent,
			place(BOSS_CX + 4 + i * 2.2, (i - 1) * 0.9 + 0.45, 0),
			Vector3.new(2.4, 0.9, stepW),
			lighten(groundCol, 0.03)
		)
		decor(place(BOSS_CX + 4 + i * 2.2 - 1.25, (i - 1) * 0.9 + 0.92, 0), Vector3.new(0.2, 0.12, stepW), accentCol)
	end
	local daisTop = Kit.part(parent, place(BOSS_CX + 16, 1.35, 0), Vector3.new(18, 2.7, 30), lighten(groundCol, 0.03))
	daisTop.Name = "Dais"
	decor(place(BOSS_CX + 7.1, 2.75, 0), Vector3.new(0.25, 0.14, 30), accentCol)

	local bossDeskCf = place(BOSS_CX + 15, 2.7, 0, -90)
	Kit.bossDesk(parent, bossDeskCf, palette)
	Kit.officeChair(parent, place(BOSS_CX + 20, 2.7, 0, -90), palette, accentCol)
	Kit.monitor(parent, bossDeskCf * CFrame.new(-2, ON_BOSS_DESK, 0.2) * CFrame.Angles(0, math.rad(190), 0), palette)
	Kit.monitor(parent, bossDeskCf * CFrame.new(2, ON_BOSS_DESK, 0.2) * CFrame.Angles(0, math.rad(170), 0), palette)
	Kit.paperStack(parent, bossDeskCf * CFrame.new(-3.4, ON_BOSS_DESK, 1), palette)
	Kit.mug(parent, bossDeskCf * CFrame.new(3.2, ON_BOSS_DESK, 1.1), palette)

	-- Maximilian stands on the dais behind his desk, facing the doors.
	table.insert(rivalSpots, { DefIndex = 7, Cf = place(BOSS_CX + 19, 2.7 + RIVAL_Y, 0, 90) })

	-- Supplicant seating below the dais, plus gold columns flanking the room.
	for _, sz in { -7, 7 } do
		Kit.officeChair(parent, place(BOSS_CX - 6, 0, sz, -90), palette, primaryCol)
	end
	for _, spot in { { -18, -20 }, { -18, 20 }, { 12, -22 }, { 12, 22 } } do
		Kit.pillar(parent, place(BOSS_CX + spot[1], 0, spot[2]), palette, BOSS_H)
	end
	Kit.bookshelf(parent, place(BOSS_CX - 2, 0, -26.3), palette)
	Kit.bookshelf(parent, place(BOSS_CX - 2, 0, 26.3, 180), palette)
	Kit.pottedPlant(parent, place(BOSS_CX - 20, 0, -24), palette)
	Kit.pottedPlant(parent, place(BOSS_CX - 20, 0, 24), palette)
	Kit.rug(parent, place(BOSS_CX - 8, 0, 0), palette, 22, 26)

	-- ═══════════════════════════ MANIFEST ═════════════════════════════════

	return {
		Spawn = spawnCf,
		RivalSpots = rivalSpots,
		TrainingZones = trainingZones,
		PaydayPads = paydayPads,
		Prompts = {
			Shop = primaryOf(shopKioskModel),
			Coffee = primaryOf(coffeeModel),
			Hr = primaryOf(hrModel),
			Elevator = primaryOf(panelModel),
		},
		Boards = {
			Eotm = primaryOf(eotmModel),
			Wins = primaryOf(winsModel),
		},
	}
end

return { build = build }
