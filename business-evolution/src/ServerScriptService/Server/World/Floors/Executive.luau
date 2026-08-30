--!strict
-- 40 — EXECUTIVE FLOOR. Dark marble, charcoal walls, gold trim at waist height
-- all the way around, warm wood furniture and glass-walled corner offices. The
-- STRATEGY WING corridor runs east (war-room tables, gold world maps), ending
-- in Preston's all-glass corner office at altitude.
--
-- Layout follows DESIGN-MAP.md: hub 150x150 centred on origin, wing out the
-- EAST wall (5 x 66-stud segments, 48 wide), boss office (60x60) at the far
-- end. Everything composes off `origin` — no world coordinates — so the floor
-- restacks freely with Config/Floors.

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
local HUB_H = 18 -- tall ceiling: the executive floor should feel grand
local WING_LEN = 330 -- 5 segments x 66
local WING_W = 48
local WING_H = 14
local WING_START_X = HUB_SIZE / 2 -- corridor slab butts the hub slab at x=75
local BOSS_SIZE = 60
local BOSS_H = 16
local BOSS_CX = WING_START_X + WING_LEN + BOSS_SIZE / 2 -- 435

-- Items on a Kit.desk top sit here: bevel cap tops out ~1.93; +0.05 clearance
-- keeps prop bottoms off the cap face (no z-fighting on coplanar faces).
local ON_DESK = 1.98
local ON_TALL_DESK = 3.08 -- over the raised tier-2 desk top
local ON_BOSS_DESK = 3.08

-- Rival body spots are handed over at torso height so the client renderer's
-- blocky suit-guy lands with feet on the marble.
local RIVAL_Y = 2.5
local WAIST_Y = 2.6 -- the gold trim line that circles every wall

-- Typed placement records for the glass offices, so the office loop stays
-- data-driven instead of 4x copy-pasted geometry.
type XZYaw = { x: number, z: number, yaw: number }
type WallSeg = { x: number, z: number, yaw: number, w: number }
type OfficeSpec = {
	front: WallSeg,
	sides: { WallSeg },
	desk: XZYaw,
	shelf: XZYaw,
	rug: XZYaw,
	plant: XZYaw,
	plaque: { x: number, z: number, yaw: number, text: string },
}

local function build(parent: Folder, origin: Vector3, palette: Palettes.Palette): Manifest
	local base = CFrame.new(origin)

	local wallCol = Palettes.color(palette.Wall)
	local darkCol = Palettes.color(palette.Dark)
	local accentCol = Palettes.color(palette.Accent)
	local primaryCol = Palettes.color(palette.Primary)

	local function lighten(c: Color3, amount: number): Color3
		return c:Lerp(Color3.new(1, 1, 1), amount)
	end
	local function darken(c: Color3, amount: number): Color3
		return c:Lerp(Color3.new(0, 0, 0), amount)
	end

	-- Dark leather derived from the floor's wood tone — palette-driven so a
	-- palette retune restains every chair on the floor at once.
	local leatherCol = darken(primaryCol, 0.45)

	-- Single positioning helper: every prop composes off `base`, never off a
	-- world coordinate.
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

	-- ── Shared executive dressing helpers ─────────────────────────────────

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

	-- Ceiling-hung tier sign, readable from both sides of the training aisle.
	local function hangingSign(x: number, z: number, yawDeg: number, text: string)
		local board = Kit.part(parent, place(x, 9.2, z, yawDeg), Vector3.new(7, 1.6, 0.3), darken(accentCol, 0.2))
		board.CanCollide = false
		board.CanQuery = false
		Kit.textLabelOn(board, Enum.NormalId.Front, text, lighten(accentCol, 0.55))
		Kit.textLabelOn(board, Enum.NormalId.Back, text, lighten(accentCol, 0.55))
		for _, dx in { -2.8, 2.8 } do
			-- Rods reach the 18-stud hub ceiling so the sign never floats.
			local rod = Kit.part(parent, place(x, 14, z, yawDeg) * CFrame.new(dx, 0, 0), Vector3.new(0.15, 8, 0.15), darkCol)
			rod.CanCollide = false
			rod.CanQuery = false
		end
	end

	-- Tier-1 workstation: mahogany desk + dark leather chair facing the aisle.
	local function trainingDesk(x: number, z: number, yawDeg: number, clutter: number)
		local deskCf = place(x, 0, z, yawDeg)
		Kit.desk(parent, deskCf, palette)
		Kit.officeChair(parent, deskCf * CFrame.new(0, 0, 2.0), palette, leatherCol)
		-- Monitor spins 180° so the screen faces the chair behind the desk.
		Kit.monitor(parent, deskCf * CFrame.new(0, ON_DESK, 0.15) * CFrame.Angles(0, math.rad(180), 0), palette)
		Kit.keyboardProp(parent, deskCf * CFrame.new(0, ON_DESK, 0.62), palette)
		if clutter == 1 then
			Kit.mug(parent, deskCf * CFrame.new(1.3, ON_DESK, 0.3), palette)
		elseif clutter == 2 then
			Kit.paperStack(parent, deskCf * CFrame.new(-1.2, ON_DESK, 0.1), palette)
		end
	end

	-- Tier-2 raised mahogany desk: taller legs, dual monitors, gold trim —
	-- the "promoted but still grinding" tier.
	local function tallDesk(x: number, z: number, yawDeg: number)
		local cf = place(x, 0, z, yawDeg)
		for _, dx in { -1.7, 1.7 } do
			Kit.part(parent, cf * CFrame.new(dx, 1.2, 0), Vector3.new(0.35, 2.4, 1.8), darkCol)
		end
		Kit.bevelBlock(parent, cf * CFrame.new(0, 2.65, 0), Vector3.new(4, 0.5, 2), primaryCol)
		Kit.monitor(parent, cf * CFrame.new(-0.85, ON_TALL_DESK, 0.15) * CFrame.Angles(0, math.rad(186), 0), palette)
		Kit.monitor(parent, cf * CFrame.new(0.85, ON_TALL_DESK, 0.15) * CFrame.Angles(0, math.rad(174), 0), palette)
		Kit.keyboardProp(parent, cf * CFrame.new(0, ON_TALL_DESK, 0.62), palette)
		Kit.trimStrip(parent, cf * CFrame.new(0, 2.5, -1.08), palette, 3.6)
		local mat = Kit.part(parent, cf * CFrame.new(0, 0.06, 1.9), Vector3.new(3.6, 0.12, 2.2), darken(accentCol, 0.35))
		mat.CanCollide = false
		mat.CanQuery = false
		mat.CastShadow = false
	end

	-- Tier-3 battlestation: two desks fused into a console, triple screens,
	-- gold trim, its own rug — the corner-office audition.
	local function battlestation(x: number, z: number)
		local deskACf = place(x, 0, z, -90)
		local deskBCf = place(x, 0, z + 4.1, -90)
		Kit.rug(parent, place(x - 1, 0, z + 2), palette, 8, 10)
		Kit.desk(parent, deskACf, palette)
		Kit.desk(parent, deskBCf, palette)
		Kit.monitor(parent, deskACf * CFrame.new(-0.9, ON_DESK, 0.15) * CFrame.Angles(0, math.rad(192), 0), palette)
		Kit.monitor(parent, deskACf * CFrame.new(0.9, ON_DESK, 0.15) * CFrame.Angles(0, math.rad(168), 0), palette)
		Kit.monitor(parent, deskBCf * CFrame.new(0, ON_DESK, 0.15) * CFrame.Angles(0, math.rad(180), 0), palette)
		Kit.keyboardProp(parent, deskACf * CFrame.new(0, ON_DESK, 0.62), palette)
		Kit.mug(parent, deskBCf * CFrame.new(1.2, ON_DESK, 0.4), palette)
		Kit.paperStack(parent, deskBCf * CFrame.new(-1.2, ON_DESK, 0.2), palette)
		Kit.officeChair(parent, place(x - 2, 0, z + 2.05, -90), palette, leatherCol)
		Kit.trimStrip(parent, deskACf * CFrame.new(0, 0.35, -1.08), palette, 3.6)
		Kit.trimStrip(parent, deskBCf * CFrame.new(0, 0.35, -1.08), palette, 3.6)
	end

	-- One sabotaged rival workstation. Returns the CFrame where the rival BODY
	-- stands: behind the desk, LookVector aimed across the corridor aisle.
	local function rivalStation(x: number, z: number, yawDeg: number, clutter: number): CFrame
		local deskCf = place(x, 0, z, yawDeg)
		Kit.desk(parent, deskCf, palette)
		Kit.monitor(parent, deskCf * CFrame.new(0, ON_DESK, 0.15) * CFrame.Angles(0, math.rad(180), 0), palette)
		-- Chair shoved aside — even executives grind standing up.
		Kit.swivelChair(parent, deskCf * CFrame.new(2.4, 0, 1.7) * CFrame.Angles(0, math.rad(40), 0), palette)
		-- Gold desk trim: every desk on floor 40 is over-specified.
		Kit.trimStrip(parent, deskCf * CFrame.new(0, 0.35, -1.08), palette, 3.6)
		if clutter == 1 then
			Kit.paperStack(parent, deskCf * CFrame.new(-1.2, ON_DESK, 0.15), palette)
		elseif clutter == 2 then
			Kit.mug(parent, deskCf * CFrame.new(1.25, ON_DESK, 0.35), palette)
		else
			Kit.paperStack(parent, deskCf * CFrame.new(-1.2, ON_DESK, 0.15), palette)
			Kit.mug(parent, deskCf * CFrame.new(1.25, ON_DESK, 0.35), palette)
		end
		return place(x, RIVAL_Y, z, yawDeg) * CFrame.new(0, 0, 2.0)
	end

	-- STRATEGY WING war-room table: bossDesk used as plain furniture, staffed
	-- with leather chairs and buried in coffee + briefing paperwork.
	local function warTable(x: number, z: number, yawDeg: number)
		local cf = place(x, 0, z, yawDeg)
		Kit.bossDesk(parent, cf, palette)
		for _, dx in { -2.5, 2.5 } do
			Kit.officeChair(parent, cf * CFrame.new(dx, 0, 3.2), palette, leatherCol)
		end
		Kit.mug(parent, cf * CFrame.new(1.5, ON_BOSS_DESK, 0.3), palette)
		Kit.paperStack(parent, cf * CFrame.new(-2.2, ON_BOSS_DESK, 0.2), palette)
		Kit.paperStack(parent, cf * CFrame.new(2.8, ON_BOSS_DESK, -0.8), palette)
	end

	-- Wall-mounted "world map": dark board + gold continents. Gold-on-charcoal
	-- keeps it palette-pure while reading as an antique conquest map.
	local function worldMap(cf: CFrame)
		local board = Kit.part(parent, cf, Vector3.new(8, 4.5, 0.25), lighten(darkCol, 0.08))
		board.CanCollide = false
		board.CanQuery = false
		board.CastShadow = false
		local continents: { { number } } = {
			{ -2.6, 0.8, 1.7, 1.5 }, { -1.2, -0.9, 1.3, 1.2 }, { 0.6, 1.0, 1.9, 0.9 },
			{ 1.9, -0.5, 2.1, 1.6 }, { 3.1, 1.3, 0.9, 0.7 },
		}
		for i, blob in continents do
			-- Continents float 0.055 proud of the board face: attached-looking,
			-- never coplanar.
			local landCol = if i % 2 == 0 then lighten(accentCol, 0.3) else lighten(accentCol, 0.12)
			local land = Kit.part(parent, cf * CFrame.new(blob[1], blob[2], -0.24), Vector3.new(blob[3], blob[4], 0.12), landCol)
			land.CanCollide = false
			land.CanQuery = false
			land.CastShadow = false
		end
		local title = Kit.textLabelOn(board, Enum.NormalId.Front, "GLOBAL SYNERGY MAP", lighten(accentCol, 0.4))
		title.Position = UDim2.fromScale(0, 0.8)
		title.Size = UDim2.fromScale(1, 0.2)
	end

	-- Abstract sculpture: stacked, twisted bevelBlocks on a pedestal. Preston
	-- owns two; nobody knows what they cost.
	local function sculpture(x: number, z: number, mirror: boolean)
		local sign = if mirror then -1 else 1
		Kit.bevelBlock(parent, place(x, 0.7, z), Vector3.new(2.2, 1.4, 2.2), darkCol)
		local stack: { { number } } = {
			-- {height, sideX, sideZ, yawDeg}
			{ 1.1, 1.6, 1.3, 25 },
			{ 1.3, 1.1, 0.9, -18 },
			{ 0.8, 0.8, 0.8, 40 },
		}
		local cursor = 1.65 -- pedestal top incl. bevel cap
		for i, blk in stack do
			local col = if i % 2 == 1 then accentCol else primaryCol
			Kit.bevelBlock(
				parent,
				place(x, cursor + blk[1] / 2, z, sign * blk[4]),
				Vector3.new(blk[2], blk[1], blk[3]),
				col
			)
			cursor += blk[1] + 0.25 -- +0.25: clear each bevel cap below
		end
	end

	-- ═══════════════════════════════ HUB ═════════════════════════════════

	-- Charcoal walls with a warm light grid; the east door leads to the wing,
	-- and four wall cuts get filled with windowWalls (high-altitude sky).
	local hubDoors: { Kit.RoomDoor } = {
		{ Wall = "E", Width = 14 },
		{ Wall = "S", Offset = -22, Width = 20 },
		{ Wall = "S", Offset = 22, Width = 20 },
		{ Wall = "W", Offset = -58, Width = 20 },
		{ Wall = "W", Offset = 58, Width = 20 },
	}
	Kit.room(parent, base, HUB_SIZE, HUB_H, HUB_SIZE, palette, { doors = hubDoors, ceiling = true })

	-- Sky windows filling the wall cuts. Height 11 matches the cut height, so
	-- each window's own header meets the room's header cleanly at y=11.
	Kit.windowWall(parent, place(-22, 0, 74.5, 180), palette, 20, 11)
	Kit.windowWall(parent, place(22, 0, 74.5, 180), palette, 20, 11)
	Kit.windowWall(parent, place(-74.5, 0, -58, -90), palette, 20, 11)
	Kit.windowWall(parent, place(-74.5, 0, 58, -90), palette, 20, 11)

	-- Gold trim at waist height all the way around (the floor's signature).
	-- Runs split only where the elevator bank and the wing doorway interrupt.
	Kit.trimStrip(parent, place(-39.5, WAIST_Y, -73.8), palette, 67) -- N, west run
	Kit.trimStrip(parent, place(39.5, WAIST_Y, -73.8), palette, 67) -- N, east run
	Kit.trimStrip(parent, place(0, WAIST_Y, 73.85), palette, 146) -- S, continuous
	Kit.trimStrip(parent, place(-73.85, WAIST_Y, 0, 90), palette, 146) -- W, continuous
	Kit.trimStrip(parent, place(73.85, WAIST_Y, -40.5, 90), palette, 65) -- E, north of door
	Kit.trimStrip(parent, place(73.85, WAIST_Y, 40.5, 90), palette, 65) -- E, south of door

	-- ── Spawn centre + gold carpet runners toward elevator and wing ──
	Kit.spawnPad(parent, place(0, 0, 0), palette)
	Kit.rug(parent, place(0, 0, 10), palette, 12, 8)
	Kit.rug(parent, place(0, 0, -38), palette, 8, 64) -- runner to the elevator
	Kit.rug(parent, place(37, 0, 0), palette, 66, 8) -- runner to the wing door
	local spawnCf = place(0, 3.2, 0, 90) -- face west: the training floor sells itself

	-- ── North wall: elevator bank flanked by pillars, boards, THE painting ──
	Kit.elevatorDoors(parent, place(0, 0, -73, 180), palette)
	local panelModel = Kit.elevatorPanel(parent, place(7.5, 5, -73.75, 180), palette)
	Kit.pillar(parent, place(-11, 0, -70), palette, HUB_H)
	Kit.pillar(parent, place(11, 0, -70), palette, HUB_H)
	Kit.trimStrip(parent, place(0, 10.8, -73.8), palette, 12)
	Kit.neonSign(parent, place(0, 12.5, -73.5, 180), palette, "EXECUTIVE FLOOR")
	local eotmModel, _eotmContent = Kit.boardFrame(parent, place(-20, 6, -73.7, 180), palette, "EMPLOYEE OF THE MONTH")
	local winsModel, _winsContent = Kit.boardFrame(parent, place(20, 6, -73.7, 180), palette, "ALL-TIME WINS")

	-- ONE enormous abstract painting (20x10) dominating the north wall.
	-- Depth layers step out 0.05+ per layer so nothing z-fights: frame at
	-- -73.7, canvas -73.3, rect layer A -73.05, rect layer B -72.8.
	local paintFrame = Kit.part(parent, place(-47, 9, -73.7), Vector3.new(20.8, 10.8, 0.5), darkCol)
	paintFrame.CanCollide = false
	paintFrame.CanQuery = false
	local canvas = Kit.part(parent, place(-47, 9, -73.3), Vector3.new(20, 10, 0.2), lighten(wallCol, 0.5))
	canvas.CanCollide = false
	canvas.CanQuery = false
	local paintColors: { Color3 } = {
		accentCol,
		lighten(primaryCol, 0.25),
		lighten(wallCol, 0.3),
		darken(accentCol, 0.25),
		lighten(accentCol, 0.45),
		primaryCol,
		darken(wallCol, 0.25),
	}
	local paintRects: { { number } } = {
		-- {dx, dy, w, h, colorIndex} on the 20x10 canvas
		{ -6.8, 1.6, 4.6, 5.6, 1 },
		{ -1.6, 2.9, 4.6, 2.6, 3 },
		{ 2.2, -1.7, 6.8, 4.4, 2 },
		{ 6.4, 2.6, 4.2, 3.2, 4 },
		{ -3.4, -2.6, 4.0, 3.0, 5 },
		{ 7.6, -2.0, 2.6, 2.2, 6 },
		{ 0.4, 0.4, 2.0, 1.6, 7 },
		{ -8.2, -3.2, 2.2, 1.8, 4 },
	}
	for i, rect in paintRects do
		local depth = if i % 2 == 1 then -73.05 else -72.8
		local swatch = Kit.part(parent, place(-47 + rect[1], 9 + rect[2], depth), Vector3.new(rect[3], rect[4], 0.2), paintColors[rect[5]])
		swatch.CanCollide = false
		swatch.CanQuery = false
		swatch.CastShadow = false
	end
	local paintPlaque = Kit.part(parent, place(-47, 3.4, -73.8, 180), Vector3.new(4.2, 0.9, 0.12), accentCol)
	paintPlaque.CanCollide = false
	paintPlaque.CanQuery = false
	Kit.textLabelOn(paintPlaque, Enum.NormalId.Front, "UNTITLED NO. 40 — DO NOT EXPENSE", darken(darkCol, 0.3))

	-- Library run on the north wall's east side + a parody memo.
	Kit.bookshelf(parent, place(36, 0, -73.1, 180), palette)
	Kit.bookshelf(parent, place(41, 0, -73.1, 180), palette)
	Kit.poster(parent, place(52, 7, -73.85, 180), palette, 8, 6, "DRESS FOR THE FLOOR ABOVE")

	-- ── Training area (west): 4x tier-1, 3x tier-2, 2x tier-3 ──
	local tierRates = Balance.TrainingTierRates
	local tierRanks = Balance.TrainingTierMinRank
	local function tierLabel(i: number): string
		local text = ("+%dx TRAINING ZONE"):format(tierRates[i])
		if tierRanks[i] > 1 then
			-- Advertise the gate on the sign so under-ranked players know why
			-- the zone ignores them (§5: inform, never mystify).
			text ..= (" · RANK %d+"):format(tierRanks[i])
		end
		return text
	end

	-- Tier 1: 2x2 block of mahogany desks facing the hub centre.
	local t1Index = 0
	for _, dx in { -52, -44 } do
		for _, dz in { -22, -14 } do
			t1Index += 1
			trainingDesk(dx, dz, -90, t1Index % 3)
		end
	end
	table.insert(trainingZones, {
		Rate = tierRates[1],
		MinRank = tierRanks[1],
		Zone = trainingZone("TrainingZoneT1", -48, -18, 16, 16),
	})
	hangingSign(-46, -18, -90, tierLabel(1))

	-- Tier 2: three raised desks, rank-gated.
	tallDesk(-50, -2, -90)
	tallDesk(-50, 6, -90)
	tallDesk(-50, 14, -90)
	table.insert(trainingZones, {
		Rate = tierRates[2],
		MinRank = tierRanks[2],
		Zone = trainingZone("TrainingZoneT2", -50, 6, 12, 22),
	})
	hangingSign(-48, 6, -90, tierLabel(2))

	-- Tier 3: two battlestations sharing one gated pen.
	battlestation(-63, 24)
	battlestation(-49, 24)
	table.insert(trainingZones, {
		Rate = tierRates[3],
		MinRank = tierRanks[3],
		Zone = trainingZone("TrainingZoneT3", -56, 26, 22, 12),
	})
	hangingSign(-56, 20, -90, tierLabel(3))
	Kit.waterCooler(parent, place(-38, 0, -30, 60), palette)

	-- ── East stations: gear shop, coffee gacha, HR ──
	local shopKioskModel = Kit.shopKiosk(parent, place(68, 0, -30, 90), palette)
	local coffeeModel = Kit.coffeeMachineBig(parent, place(67, 0, -14, 90), palette)
	local hrModel = Kit.hrDesk(parent, place(66, 0, 16, 90), palette)
	Kit.pottedPlant(parent, place(69, 0, -22), palette)
	Kit.pottedPlant(parent, place(69, 0, 8), palette)
	Kit.poster(parent, place(73.85, 7, 16, 90), palette, 7, 5, "RESTRUCTURING IS SELF-CARE")
	Kit.poster(parent, place(73.85, 7, -45, 90), palette, 7, 5, "MEETINGS ARE MERGERS")

	-- ── Glass-walled offices along the WEST and SOUTH sides ──
	-- windowWall as interior partitions; each office backs onto one of the
	-- exterior sky windows, so the corner-office fantasy comes with a view.
	local offices: { OfficeSpec } = {
		{ -- NW corner suite, entry at its south end
			front = { x = -52, z = -61, yaw = -90, w = 18 },
			sides = { { x = -62.9, z = -70, yaw = 0, w = 21 }, { x = -62.9, z = -46, yaw = 0, w = 21 } },
			desk = { x = -66, z = -58, yaw = -90 },
			shelf = { x = -62, z = -68.6, yaw = 0 },
			rug = { x = -63, z = -58, yaw = 0 },
			plant = { x = -56, z = -67, yaw = 0 },
			plaque = { x = -51.4, z = -61, yaw = -90, text = "MERGERS & ACQUISITIONS" },
		},
		{ -- SW corner suite, entry at its north end
			front = { x = -52, z = 61, yaw = -90, w = 18 },
			sides = { { x = -62.9, z = 46, yaw = 0, w = 21 }, { x = -62.9, z = 70, yaw = 0, w = 21 } },
			desk = { x = -66, z = 58, yaw = -90 },
			shelf = { x = -62, z = 68.6, yaw = 180 },
			rug = { x = -63, z = 58, yaw = 0 },
			plant = { x = -56, z = 67, yaw = 0 },
			plaque = { x = -51.4, z = 61, yaw = -90, text = "STRATEGIC FORESIGHT" },
		},
		{ -- South suite west of the alcove, entry beside the aisle
			front = { x = -25, z = 50, yaw = 180, w = 18 },
			sides = { { x = -34, z = 61.9, yaw = 90, w = 23 }, { x = -10, z = 61.9, yaw = 90, w = 23 } },
			desk = { x = -22, z = 65, yaw = 0 },
			shelf = { x = -32.7, z = 60, yaw = -90 },
			rug = { x = -22, z = 59, yaw = 0 },
			plant = { x = -13, z = 69, yaw = 0 },
			plaque = { x = -25, z = 49.4, yaw = 180, text = "OFFICE OF SYNERGY" },
		},
		{ -- South suite east of the alcove
			front = { x = 25, z = 50, yaw = 180, w = 18 },
			sides = { { x = 34, z = 61.9, yaw = 90, w = 23 }, { x = 10, z = 61.9, yaw = 90, w = 23 } },
			desk = { x = 22, z = 65, yaw = 0 },
			shelf = { x = 32.7, z = 60, yaw = 90 },
			rug = { x = 22, z = 59, yaw = 0 },
			plant = { x = 13, z = 69, yaw = 0 },
			plaque = { x = 25, z = 49.4, yaw = 180, text = "GROWTH DIVISION" },
		},
	}
	for i, office in offices do
		Kit.windowWall(parent, place(office.front.x, 0, office.front.z, office.front.yaw), palette, office.front.w, 9)
		for _, side in office.sides do
			Kit.windowWall(parent, place(side.x, 0, side.z, side.yaw), palette, side.w, 9)
		end
		local deskCf = place(office.desk.x, 0, office.desk.z, office.desk.yaw)
		Kit.rug(parent, place(office.rug.x, 0, office.rug.z), palette, 8, 8)
		Kit.desk(parent, deskCf, palette)
		Kit.officeChair(parent, deskCf * CFrame.new(0, 0, 2.0), palette, leatherCol)
		Kit.monitor(parent, deskCf * CFrame.new(0, ON_DESK, 0.15) * CFrame.Angles(0, math.rad(180), 0), palette)
		Kit.keyboardProp(parent, deskCf * CFrame.new(0, ON_DESK, 0.62), palette)
		if i % 2 == 0 then
			Kit.mug(parent, deskCf * CFrame.new(1.3, ON_DESK, 0.3), palette)
		else
			Kit.paperStack(parent, deskCf * CFrame.new(-1.2, ON_DESK, 0.1), palette)
		end
		Kit.trimStrip(parent, deskCf * CFrame.new(0, 0.35, -1.08), palette, 3.6)
		Kit.bookshelf(parent, place(office.shelf.x, 0, office.shelf.z, office.shelf.yaw), palette)
		Kit.pottedPlant(parent, place(office.plant.x, 0, office.plant.z), palette)
		local plaque = Kit.part(parent, place(office.plaque.x, 8.6, office.plaque.z, office.plaque.yaw), Vector3.new(3.4, 0.9, 0.15), accentCol)
		plaque.CanCollide = false
		plaque.CanQuery = false
		Kit.textLabelOn(plaque, Enum.NormalId.Front, office.plaque.text, darken(darkCol, 0.3))
	end

	-- South alcove between the two suites: a quiet gallery moment.
	Kit.poster(parent, place(0, 7, 73.85, 0), palette, 10, 6, "QUARTERLY VISION: MORE")
	Kit.waterCooler(parent, place(0, 0, 70, 0), palette)
	Kit.pottedPlant(parent, place(-6, 0, 70), palette)
	Kit.pottedPlant(parent, place(6, 0, 70), palette)

	-- ── SE lounge: leather seating around a low wood table ──
	Kit.rug(parent, place(56, 0, 56), palette, 16, 12)
	Kit.bevelBlock(parent, place(56, 0.55, 56), Vector3.new(4, 1.1, 2.5), primaryCol)
	Kit.mug(parent, place(56.6, 1.62, 56.4), palette)
	Kit.paperStack(parent, place(55.2, 1.62, 55.6), palette)
	Kit.officeChair(parent, place(51, 0, 56, -90), palette, leatherCol)
	Kit.officeChair(parent, place(61, 0, 56, 90), palette, leatherCol)
	Kit.officeChair(parent, place(56, 0, 50, 180), palette, leatherCol)
	Kit.officeChair(parent, place(56, 0, 62, 0), palette, leatherCol)
	Kit.bookshelf(parent, place(72.9, 0, 48, 90), palette)
	Kit.pottedPlant(parent, place(64, 0, 64), palette)

	-- ── NE corner: records + refreshments ──
	Kit.filingCabinet(parent, place(70.9, 0, -50, 90), palette)
	Kit.filingCabinet(parent, place(70.9, 0, -47.5, 90), palette)
	Kit.filingCabinet(parent, place(70.9, 0, -45, 90), palette)
	Kit.waterCooler(parent, place(70, 0, -58, 90), palette)
	Kit.pottedPlant(parent, place(70, 0, -66), palette)
	Kit.bookshelf(parent, place(72.9, 0, -64, 90), palette)

	-- ── Structure: marble colonnade + palms + wall memos ──
	for _, corner in { Vector2.new(-32, -32), Vector2.new(32, -32), Vector2.new(-32, 32), Vector2.new(32, 32) } do
		Kit.pillar(parent, place(corner.X, 0, corner.Y), palette, HUB_H)
	end
	Kit.pottedPlant(parent, place(-30, 0, -36), palette)
	Kit.pottedPlant(parent, place(30, 0, -36), palette)
	Kit.pottedPlant(parent, place(-14, 0, 36), palette)
	Kit.pottedPlant(parent, place(18, 0, 40), palette)
	Kit.poster(parent, place(-73.85, 7, 0, -90), palette, 10, 7, "PROFIT IS A LIFESTYLE")
	Kit.poster(parent, place(-73.85, 7, 34, -90), palette, 7, 5, "CLIMB QUIETLY")

	-- Wing doorway signage on the hub side, over the 14-wide opening.
	Kit.neonSign(parent, place(73.8, 12.7, 0, 90), palette, "STRATEGY WING")
	Kit.trimStrip(parent, place(73.8, 11.2, 0, 90), palette, 15)

	-- ═══════════════════════════ STRATEGY WING ═══════════════════════════

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
	Kit.neonSign(parent, place(76.2, 12.2, 0, -90), palette, "STRATEGY WING")
	-- Waist-height gold trim chases both corridor walls end to end.
	Kit.trimStrip(parent, place(240, WAIST_Y, -22.85), palette, 326)
	Kit.trimStrip(parent, place(240, WAIST_Y, 22.85), palette, 326)
	-- Gold runner carpet the length of the aisle: the wing IS a red carpet.
	Kit.rug(parent, place(240, 0, 0), palette, 322, 6)

	-- Rival packs per the floor spec: seg1 def1 x3 · seg2 def2 x3 ·
	-- seg3 def3 x2 + def4 · seg4 def4 + def5 x2 · seg5 def6 x2. North-side
	-- desks face south and vice versa, so every LookVector crosses the aisle.
	local stations: { { x: number, north: boolean, def: number } } = {
		{ x = 98, north = true, def = 1 }, { x = 110, north = false, def = 1 }, { x = 122, north = true, def = 1 },
		{ x = 162, north = false, def = 2 }, { x = 175, north = true, def = 2 }, { x = 188, north = false, def = 2 },
		{ x = 228, north = true, def = 3 }, { x = 241, north = false, def = 3 }, { x = 254, north = true, def = 4 },
		{ x = 294, north = false, def = 4 }, { x = 308, north = true, def = 5 }, { x = 321, north = false, def = 5 },
		{ x = 360, north = true, def = 6 }, { x = 381, north = false, def = 6 },
	}
	for i, st in stations do
		local z = if st.north then -12 else 12
		local yawDeg = if st.north then 180 else 0
		local bodyCf = rivalStation(st.x, z, yawDeg, i % 3)
		table.insert(rivalSpots, { DefIndex = st.def, Cf = bodyCf })
	end

	-- Gates + payday pads. Each label advertises the NEXT pack (dominant def
	-- of the following segment; the boss after seg 5) so under-powered players
	-- self-select back to training — never a hard block (§5).
	local executiveDefs = Rivals.ByFloor.Executive
	local gateXs: { number } = { 141, 207, 273, 339, 398 }
	local gateNextDef: { number } = { 2, 3, 5, 6, 7 }
	for k = 1, 5 do
		local gx = gateXs[k]
		local nextDef = executiveDefs[gateNextDef[k]]
		local label = ("NEXT: %s — %s WORKLOAD"):format(nextDef.Title, Format.abbreviate(nextDef.Workload))
		-- Arch spans the corridor (yaw 90 lays its width along Z).
		Kit.gateArch(parent, place(gx, 0, 0, 90), palette, label)
		-- Pads alternate sides, always off the runner: stepping on one is a
		-- choice, walking past costs nothing.
		local padZ = if k % 2 == 1 then 14 else -14
		local pad: BasePart = Kit.paydayPad(parent, place(gx, 0, padZ), palette)
		table.insert(paydayPads, { Segment = k, Pad = pad })
		Kit.pottedPlant(parent, place(gx - 5, 0, 19), palette)
		Kit.pottedPlant(parent, place(gx + 4, 0, -19), palette)
	end
	-- Colonnade pairs at the mid-wing gates keep the corridor feeling load-bearing.
	for _, gx in { 207, 339 } do
		Kit.pillar(parent, place(gx, 0, -20), palette, WING_H)
		Kit.pillar(parent, place(gx, 0, 20), palette, WING_H)
	end

	-- War-room tables, one per segment, each under its gold world map.
	local warSpots: { { number } } = { { 94, 17, 0 }, { 200, -17, 180 }, { 218, 17, 0 }, { 326, -17, 180 }, { 350, 17, 0 } }
	for _, spot in warSpots do
		warTable(spot[1], spot[2], spot[3])
		local mapZ = if spot[2] > 0 then 22.8 else -22.8
		local mapYaw = if spot[2] > 0 then 0 else 180
		worldMap(place(spot[1], 7, mapZ, mapYaw))
	end
	Kit.whiteboard(parent, place(232, 0, 20.5, 25), palette)

	-- Per-segment wall dressing: shelves, records, memos.
	Kit.bookshelf(parent, place(134, 0, -21.9, 180), palette)
	Kit.bookshelf(parent, place(260, 0, 21.9, 0), palette)
	Kit.bookshelf(parent, place(300, 0, -21.9, 180), palette)
	Kit.bookshelf(parent, place(388, 0, 21.9, 0), palette)
	Kit.filingCabinet(parent, place(156, 0, -21, 180), palette)
	Kit.filingCabinet(parent, place(247, 0, 21, 0), palette)
	local wingPosters: { string } = {
		"SYNERGY IS A VERB",
		"THE ORG CHART SEES ALL",
		"ALIGNMENT. LEVERAGE. LUNCH.",
		"MARKET SHARE IS A STATE OF MIND",
		"PRESTON IS WATCHING",
	}
	local segCentres: { number } = { 108, 174, 240, 306, 372 }
	for k, cx in segCentres do
		if k % 2 == 1 then
			Kit.poster(parent, place(cx + 6, 6.5, -22.85, 180), palette, 7, 5, wingPosters[k])
		else
			Kit.poster(parent, place(cx + 6, 6.5, 22.85, 0), palette, 7, 5, wingPosters[k])
		end
	end

	-- Suite signage over the far door, facing arrivals.
	Kit.neonSign(parent, place(403.8, 12.2, 0, 90), palette, "EXECUTIVE SUITE")

	-- ═══════════════════════════ BOSS OFFICE ═════════════════════════════

	-- Preston's corner office: windows=true turns every wall segment into
	-- floor-to-ceiling glass — nothing but sky on three sides.
	local bossDoors: { Kit.RoomDoor } = { { Wall = "W", Width = 14 } }
	Kit.room(
		parent,
		base * CFrame.new(BOSS_CX, 0, 0),
		BOSS_SIZE,
		BOSS_H,
		BOSS_SIZE,
		palette,
		{ doors = bossDoors, windows = true, ceiling = true }
	)

	-- Double doors centred in the shared opening; wall-coloured jamb fills
	-- close the gap flanks so the entrance reads as one framed portal.
	Kit.doubleDoor(parent, place(405, 0, 0, 90), palette)
	for _, jz in { -5.5, 5.5 } do
		Kit.part(parent, place(405, 5.5, jz), Vector3.new(2.2, 11, 3), wallCol)
	end
	-- The boss line hangs over the door on the only solid band in the room.
	Kit.poster(parent, place(406.15, 13.5, 0, -90), palette, 12, 4.5, "\"I OPTIMIZE OPTIMIZERS.\" — PRESTON")

	-- Twin pillars just inside the doors.
	Kit.pillar(parent, place(413, 0, -8), palette, BOSS_H)
	Kit.pillar(parent, place(413, 0, 8), palette, BOSS_H)

	-- The desk, the man, the art collection.
	local bossDeskCf = place(446, 0, 0, 90)
	Kit.rug(parent, place(441, 0, 0), palette, 14, 18)
	Kit.bossDesk(parent, bossDeskCf, palette)
	Kit.swivelChair(parent, place(452, 0, 4, 90), palette)
	Kit.neonSign(parent, place(447, 13, 0, 90), palette, "PRESTON")
	table.insert(rivalSpots, { DefIndex = 7, Cf = place(450.5, RIVAL_Y, 0, 90) })
	sculpture(446, -10, false)
	sculpture(446, 10, true)
	Kit.paperStack(parent, bossDeskCf * CFrame.new(-2.5, ON_BOSS_DESK, 0.4), palette)
	Kit.paperStack(parent, bossDeskCf * CFrame.new(2.2, ON_BOSS_DESK, -0.3), palette)
	Kit.mug(parent, bossDeskCf * CFrame.new(0.8, ON_BOSS_DESK, 1.2), palette)

	-- Supplicant seating + strategy clutter.
	Kit.officeChair(parent, place(439, 0, -5, -90), palette, leatherCol)
	Kit.officeChair(parent, place(439, 0, 5, -90), palette, leatherCol)
	Kit.whiteboard(parent, place(455, 0, -16, 150), palette)
	Kit.bookshelf(parent, place(462.3, 0, -10, 90), palette)
	Kit.bookshelf(parent, place(462.3, 0, 10, 90), palette)
	Kit.pottedPlant(parent, place(410, 0, -24), palette)
	Kit.pottedPlant(parent, place(410, 0, 24), palette)

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
