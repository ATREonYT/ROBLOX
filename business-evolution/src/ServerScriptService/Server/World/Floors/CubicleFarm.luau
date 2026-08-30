--!strict
-- CubicleFarm — Floor 3. Grey felt partitions to the horizon: the hub is a
-- bright, flat, fluorescent-lit sea of cubicles (sickly green carpet, white
-- ceiling waffle, motivational posters), the grind corridor is the AUDIT WING
-- (filing-cabinet canyons, paperwork on every surface), and Deborah's
-- windowless "corner office" waits at the far end behind TWO double doors.
--
-- Pure geometry builder: everything is positioned by CFrame composition off
-- the `origin` MapService hands us, colours come only from the floor palette,
-- and the returned Manifest is the one contract other services consume.
-- Rough part budget (counted per Kit call): hub ≈ 800, wing ≈ 1270,
-- boss office ≈ 140 → ≈ 2200 total, inside the ≤ 2800 floor cap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Palettes = require(ReplicatedStorage.Shared.Config.Palettes)
local Rivals = require(ReplicatedStorage.Shared.Config.Rivals)
local Format = require(ReplicatedStorage.Shared.Util.Format)

local Kit = require(script.Parent.Parent.Kit)

type Palette = Palettes.Palette

type RivalSpot = { DefIndex: number, Cf: CFrame }
type TrainingZoneEntry = { Rate: number, MinRank: number, Zone: BasePart }
type PaydayPadEntry = { Segment: number, Pad: BasePart }

type Manifest = {
	Spawn: CFrame,
	RivalSpots: { RivalSpot },
	TrainingZones: { TrainingZoneEntry },
	PaydayPads: { PaydayPadEntry },
	Prompts: { Shop: BasePart, Coffee: BasePart, Hr: BasePart, Elevator: BasePart },
	Boards: { Eotm: BasePart, Wins: BasePart },
}

-- ── Layout constants (shared skeleton from DESIGN-MAP.md) ───────────────────
-- Hub is centred on origin; the wing runs SOUTH (+Z) so the north wall keeps
-- the elevator/boards exactly where every other floor puts them.
local HUB_SIZE = 150
local HUB_HEIGHT = 18
local WING_WIDTH = 48
local WING_HEIGHT = 16
local SEGMENT_LENGTH = 66
local SEGMENT_COUNT = 5
local WING_LENGTH = SEGMENT_LENGTH * SEGMENT_COUNT
local WING_START = HUB_SIZE / 2 -- corridor slab begins exactly where the hub slab ends
local BOSS_SIZE = 60
local BOSS_HEIGHT = 18
local BOSS_CENTER_Z = WING_START + WING_LENGTH + BOSS_SIZE / 2
local HUB_DOOR_WIDTH = 14 -- comfortably over the ≥10 walkable minimum
local BOSS_DOOR_WIDTH = 20 -- wide enough for two side-by-side double doors

-- Desktop items sit with their base sunk ~0.05 into the desk's bevel cap
-- (cap top ends at +1.925): flush contact without coplanar faces.
local DESKTOP = 1.87
-- Filing cabinets are 4.125 tall including the bevel cap; stacking at 4.1
-- rests the next body exactly on the cap with the contact faces occluded.
local CABINET_STACK = 4.1
local CABINET_TOP = 8.21 -- paperwork resting on a 2-high stack, slightly sunk

local INK = Color3.fromRGB(45, 42, 40)

-- ── Small helpers ───────────────────────────────────────────────────────────

local function yaw(degrees: number): CFrame
	return CFrame.Angles(0, math.rad(degrees), 0)
end

-- All geometry goes through this so nothing can hard-code world coordinates:
-- x/z are hub-local (origin-centred), yaw follows the Kit front = -Z rule.
local function place(root: CFrame, x: number, y: number, z: number, yawDeg: number?): CFrame
	local cf = root * CFrame.new(x, y, z)
	if yawDeg ~= nil and yawDeg ~= 0 then
		cf = cf * yaw(yawDeg)
	end
	return cf
end

local function primaryOf(model: Model): BasePart
	local part = model.PrimaryPart
	assert(part ~= nil, "Kit model is missing its PrimaryPart")
	return part
end

-- Floating sign over a training cluster: an invisible anchor so the label
-- reads from any approach angle without adding visible geometry.
local function floatingLabel(parent: Instance, cf: CFrame, width: number, text: string, color: Color3)
	local anchor = Kit.part(parent, cf, Vector3.new(0.6, 0.6, 0.6), color)
	anchor.Name = "SignAnchor"
	anchor.Transparency = 1

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(width, 0, 2.4, 0)
	gui.MaxDistance = 220
	gui.LightInfluence = 0
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeColor3 = INK
	label.TextStrokeTransparency = 0.35
	label.TextScaled = true
	label.Parent = gui
end

-- Invisible AABB volume ProductivityService tests player roots against.
-- Kit.part flips CanCollide on for big parts, so every flag is forced here.
local function buildZonePart(parent: Instance, cf: CFrame, size: Vector3, palette: Palette): BasePart
	local zone = Kit.part(parent, cf, size, Palettes.color(palette.Accent))
	zone.Name = "TrainingZone"
	zone.Transparency = 1
	zone.CanCollide = false
	zone.CanQuery = false
	zone.CanTouch = false
	zone.CastShadow = false
	return zone
end

local function trainingSignText(tier: number): string
	local rate = Balance.TrainingTierRates[tier]
	local minRank = Balance.TrainingTierMinRank[tier]
	local text = ("+%dx TRAINING ZONE"):format(rate)
	-- Tier 1 is open to everyone; printing "RANK 1+" would read as a gate.
	if minRank > 1 then
		text ..= (" · RANK %d+"):format(minRank)
	end
	return text
end

-- ── Cubicles (the whole floor identity in one prop cluster) ─────────────────

type CubicleOpts = {
	Standing: boolean?, -- tier-2 plinth variant (no chair, taller felt)
	CapEnd: boolean?, -- close the run's open -X end (first cell only)
	Seed: number, -- deterministic clutter picker so servers match
}

-- One workstation cell: back + divider partitions, desk facing the aisle
-- (cf LookVector), glowing monitor turned back toward the worker.
local function buildCubicle(parent: Instance, cf: CFrame, palette: Palette, opts: CubicleOpts)
	local feltHeight = if opts.Standing then 7 else 5
	local deskCf = cf
	if opts.Standing then
		-- Standing desk = normal desk on a chunky plinth; cheap and readable.
		local plinth = Kit.part(parent, cf * CFrame.new(0, 0.4, 0.6), Vector3.new(6, 0.8, 4.4), Palettes.color(palette.Dark))
		plinth.CanCollide = true
		deskCf = cf * CFrame.new(0, 0.8, 0)
	end

	Kit.desk(parent, deskCf, palette)
	if not opts.Standing then
		Kit.officeChair(parent, cf * CFrame.new(0, 0, 2.1), palette)
	end
	Kit.monitor(parent, deskCf * CFrame.new(0.35, DESKTOP, 0.1) * yaw(180), palette)
	Kit.keyboardProp(parent, deskCf * CFrame.new(0, DESKTOP, 0.55) * yaw(180), palette)
	if opts.Seed % 2 == 0 then
		Kit.mug(parent, deskCf * CFrame.new(-1.3, DESKTOP, 0.4), palette)
	else
		Kit.paperStack(parent, deskCf * CFrame.new(-1.35, DESKTOP, 0.25), palette)
	end

	Kit.partition(parent, cf * CFrame.new(0, 0, 3.9), palette, 7, feltHeight)
	Kit.partition(parent, cf * CFrame.new(3.6, 0, 1.2) * yaw(90), palette, 6, feltHeight)
	if opts.CapEnd then
		Kit.partition(parent, cf * CFrame.new(-3.6, 0, 1.2) * yaw(90), palette, 6, feltHeight)
	end
end

-- ── Audit-wing pieces ───────────────────────────────────────────────────────

-- A sabotaged audit desk. Returns where the rival BODY stands: behind the
-- desk, LookVector down the same aisle-facing direction as the desk front.
local function buildRivalDesk(parent: Instance, cf: CFrame, palette: Palette, seed: number): CFrame
	Kit.desk(parent, cf, palette)
	Kit.monitor(parent, cf * CFrame.new(-0.5, DESKTOP, 0.1) * yaw(180), palette)
	Kit.keyboardProp(parent, cf * CFrame.new(-0.4, DESKTOP, 0.6) * yaw(180), palette)
	Kit.paperStack(parent, cf * CFrame.new(1.35, DESKTOP, -0.3), palette)
	if seed % 2 == 0 then
		Kit.mug(parent, cf * CFrame.new(1.2, DESKTOP, 0.55), palette)
	end
	-- Overflow paperwork dumped on the carpet at the aisle edge — clutter the
	-- player walks past, never through (small parts are non-colliding).
	Kit.paperStack(parent, cf * CFrame.new((seed % 3) - 1, 0, -2.2), palette)
	Kit.partition(parent, cf * CFrame.new(0, 0, 4.7), palette, 7, 5.5)
	return cf * CFrame.new(0, 0, 2.05)
end

-- Filing cabinets flanking a gate: the canyon pinches the corridor toward the
-- arch without ever closing it (the arch mouth stays ~11 studs wide, §5).
local function buildGateCanyon(parent: Instance, root: CFrame, zGate: number, palette: Palette, heavy: boolean)
	for _, side in { -1, 1 } do
		-- Felt from the wall to the cabinet run; its outer end face rests
		-- flat against the corridor wall face (contact faces are occluded).
		Kit.partition(parent, place(root, side * 18.2, 0, zGate), palette, 9.6, 6.5)
		local bottomXs: { number } = if heavy then { 8.2, 10.2, 12.2 } else { 8.2, 10.2 }
		for _, x in bottomXs do
			Kit.filingCabinet(parent, place(root, side * x, 0, zGate), palette)
		end
		local topXs: { number } = if heavy then { 9.2, 11.2 } else { 9.2 }
		for _, x in topXs do
			Kit.filingCabinet(parent, place(root, side * x, CABINET_STACK, zGate), palette)
		end
		Kit.paperStack(parent, place(root, side * 10.2, CABINET_TOP, zGate), palette)
	end
end

-- Wall-hugging cabinet stack mid-segment: two-wide base, one bridging on top,
-- loose paperwork crowning it. Drawers face the aisle.
local function buildCabinetCluster(parent: Instance, root: CFrame, x: number, z: number, palette: Palette)
	local face = if x < 0 then -90 else 90
	Kit.filingCabinet(parent, place(root, x, 0, z - 1, face), palette)
	Kit.filingCabinet(parent, place(root, x, 0, z + 1, face), palette)
	Kit.filingCabinet(parent, place(root, x, CABINET_STACK, z, face), palette)
	Kit.paperStack(parent, place(root, x, CABINET_TOP, z, face), palette)
end

-- ── The floor builder ───────────────────────────────────────────────────────

local function build(parent: Folder, origin: Vector3, palette: Palette): Manifest
	local root = CFrame.new(origin)
	local accent = Palettes.color(palette.Accent)
	local defs = Rivals.ByFloor.CubicleFarm

	local rivalSpots: { RivalSpot } = {}
	local trainingZones: { TrainingZoneEntry } = {}
	local paydayPads: { PaydayPadEntry } = {}

	-- ════════════════════════════ HUB ══════════════════════════════════════
	local hubFolder = Instance.new("Folder")
	hubFolder.Name = "Hub"
	hubFolder.Parent = parent

	-- No windows on purpose: the Cubicle Farm joke is that daylight does not
	-- exist here — the ceiling waffle is the only sky.
	local hubOpts: Kit.RoomOpts = {
		windows = false,
		ceiling = true,
		doors = { { Wall = "S", Offset = 0, Width = HUB_DOOR_WIDTH } :: Kit.RoomDoor },
	}
	Kit.room(hubFolder, root, HUB_SIZE, HUB_HEIGHT, HUB_SIZE, palette, hubOpts)

	-- room() lays a 6×6 light grid; interleaving a second offset grid turns it
	-- into the relentless corporate fluorescent waffle the spec asks for.
	for ix = 0, 4 do
		for iz = 0, 4 do
			Kit.ceilingLight(hubFolder, place(root, -50 + ix * 25, HUB_HEIGHT - 0.2, -50 + iz * 25), palette)
		end
	end

	Kit.spawnPad(hubFolder, place(root, 0, 0, 0), palette)

	-- ── North wall: elevator bank + the two boards ──
	Kit.elevatorDoors(hubFolder, place(root, -34, 0, -73.2, 180), palette)
	Kit.elevatorDoors(hubFolder, place(root, -18, 0, -73.2, 180), palette)
	local elevatorPanel = Kit.elevatorPanel(hubFolder, place(root, -26, 5, -73.8, 180), palette)
	Kit.neonSign(hubFolder, place(root, -26, 13.5, -73.8, 180), palette, "CUBICLE FARM — FLOOR 3")

	local eotmModel = Kit.boardFrame(hubFolder, place(root, 8, 8, -73.6, 180), palette, "EMPLOYEE OF THE MONTH")
	local winsModel = Kit.boardFrame(hubFolder, place(root, 26, 8, -73.6, 180), palette, "ALL-TIME WINS")

	-- ── East wall: gear shop, the BREW-O-TRON, HR ──
	local shopModel = Kit.shopKiosk(hubFolder, place(root, 71, 0, -30, 90), palette)
	local coffeeModel = Kit.coffeeMachineBig(hubFolder, place(root, 70, 0, 0, 90), palette)
	local hrModel = Kit.hrDesk(hubFolder, place(root, 70.5, 0, 30, 90), palette)
	Kit.pottedPlant(hubFolder, place(root, 70.5, 0, -14), palette, true)
	Kit.pottedPlant(hubFolder, place(root, 70.5, 0, 15), palette, true)

	-- ── Gossip corner (NE): humming vending machine + water cooler ──
	Kit.vendingMachine(hubFolder, place(root, 58, 0, -72.8, 180), palette)
	Kit.waterCooler(hubFolder, place(root, 63.5, 0, -72.9, 180), palette)
	Kit.filingCabinet(hubFolder, place(root, 52.5, 0, -72.4, 180), palette)
	Kit.paperStack(hubFolder, place(root, 52.5, CABINET_STACK + 0.01, -72.4, 180), palette)
	Kit.rug(hubFolder, place(root, 60.5, 0, -68), palette, 12, 8)
	Kit.pottedPlant(hubFolder, place(root, 67.5, 0, -71.5), palette, true)

	-- ── Motivational posters (the load-bearing décor of this floor) ──
	-- Wall inner faces sit at ±74; posters hang 0.055 proud so nothing z-fights.
	Kit.poster(hubFolder, place(root, -52, 10, -73.87, 180), palette, 9, 7, "SYNERGY")
	-- y=10 keeps the paper's bottom edge clear of the vending machine's cap so
	-- the two near-coplanar surfaces can never shimmer against each other.
	Kit.poster(hubFolder, place(root, 61, 10, -73.87, 180), palette, 7, 8, "HANG IN THERE")
	Kit.poster(hubFolder, place(root, -73.87, 9, -30, -90), palette, 14, 7, "TEAMWORK MAKES THE DREAM WORK")
	Kit.poster(hubFolder, place(root, -73.87, 9, 8, -90), palette, 8, 7, "THE GRIND NEVER STOPS")
	Kit.poster(hubFolder, place(root, 73.87, 9, -14, 90), palette, 7, 6, "COMPLIANCE IS COOL")
	Kit.poster(hubFolder, place(root, 73.87, 9, 12, 90), palette, 7, 6, "FREE COFFEE (MANDATORY)")
	Kit.poster(hubFolder, place(root, 20, 9, 73.87, 0), palette, 8, 6, "THERE IS NO 'I' IN TEAM")
	Kit.poster(hubFolder, place(root, -20, 9, 73.87, 0), palette, 8, 6, "MONDAY IS A STATE OF MIND")

	-- ═══════════════════ TRAINING AREA (west) ══════════════════════════════
	local trainingFolder = Instance.new("Folder")
	trainingFolder.Name = "Training"
	trainingFolder.Parent = hubFolder

	-- Tier 1 — eight open cubicles, two rows both facing east so the farm
	-- reads as endless repetition the moment you spawn.
	for rowIndex, rowX in { -58, -46 } do
		for i, cellZ in { -21, -13, -5, 3 } do
			buildCubicle(trainingFolder, place(root, rowX, 0, cellZ, -90), palette, {
				Seed = rowIndex * 4 + i,
				CapEnd = i == 1,
			})
		end
	end
	local tier1Zone = buildZonePart(trainingFolder, place(root, -50, 4, -9), Vector3.new(24, 8, 34), palette)
	table.insert(trainingZones, { Rate = Balance.TrainingTierRates[1], MinRank = Balance.TrainingTierMinRank[1], Zone = tier1Zone })
	floatingLabel(trainingFolder, place(root, -50, 9.5, -9), 13, trainingSignText(1), accent)

	-- Tier 2 — three standing desks on plinths, taller felt: aspirational.
	for i, cellZ in { 22, 30, 38 } do
		buildCubicle(trainingFolder, place(root, -55, 0, cellZ, -90), palette, {
			Standing = true,
			Seed = i,
			CapEnd = i == 1,
		})
	end
	local tier2Zone = buildZonePart(trainingFolder, place(root, -52, 4, 30), Vector3.new(14, 8, 26), palette)
	table.insert(trainingZones, { Rate = Balance.TrainingTierRates[2], MinRank = Balance.TrainingTierMinRank[2], Zone = tier2Zone })
	floatingLabel(trainingFolder, place(root, -52, 10, 30), 14, trainingSignText(2), accent)

	-- Tier 3 — the corner battlestation: an L of tall felt, two desks, three
	-- monitors and the floor's only healthy plant (rank has its privileges).
	Kit.partition(trainingFolder, place(root, -64, 0, -53, 90), palette, 12, 7)
	Kit.partition(trainingFolder, place(root, -57, 0, -59.3, 0), palette, 12, 7)
	Kit.trimStrip(trainingFolder, place(root, -57, 6.4, -58.95), palette, 10)
	Kit.rug(trainingFolder, place(root, -58, 0, -52), palette, 10, 10)
	local t3DeskA = place(root, -60.6, 0, -53, -90)
	Kit.desk(trainingFolder, t3DeskA, palette)
	Kit.monitor(trainingFolder, t3DeskA * CFrame.new(-0.85, DESKTOP, 0.15) * yaw(168), palette)
	Kit.monitor(trainingFolder, t3DeskA * CFrame.new(0.85, DESKTOP, 0.15) * yaw(192), palette)
	Kit.keyboardProp(trainingFolder, t3DeskA * CFrame.new(0, DESKTOP, 0.6) * yaw(180), palette)
	Kit.swivelChair(trainingFolder, t3DeskA * CFrame.new(0, 0, 1.9), palette)
	local t3DeskB = place(root, -57, 0, -56.4, 180)
	Kit.desk(trainingFolder, t3DeskB, palette)
	Kit.monitor(trainingFolder, t3DeskB * CFrame.new(0.3, DESKTOP, 0.1) * yaw(180), palette)
	Kit.paperStack(trainingFolder, t3DeskB * CFrame.new(-1.3, DESKTOP, 0.3), palette)
	Kit.mug(trainingFolder, t3DeskA * CFrame.new(1.6, DESKTOP, -0.55), palette)
	Kit.pottedPlant(trainingFolder, place(root, -62.5, 0, -58.2), palette, false)
	local tier3Zone = buildZonePart(trainingFolder, place(root, -57.5, 4, -52.5), Vector3.new(13, 8, 13), palette)
	table.insert(trainingZones, { Rate = Balance.TrainingTierRates[3], MinRank = Balance.TrainingTierMinRank[3], Zone = tier3Zone })
	floatingLabel(trainingFolder, place(root, -57.5, 10.5, -52.5), 14, trainingSignText(3), accent)

	-- ═══════════ PARTITION MAZE (the "sea of cubicles" ring) ═══════════════
	-- Receding partition rows along the south half fake depth cheaply: from
	-- spawn the felt just keeps going until it meets the walls.
	local mazeFolder = Instance.new("Folder")
	mazeFolder.Name = "PartitionMaze"
	mazeFolder.Parent = hubFolder

	type MazeRun = { X: number, Z: number, W: number, R: number }
	local mazeRuns: { MazeRun } = {
		-- west flank, front row
		{ X = -14, Z = 69, W = 12, R = 0 },
		{ X = -27, Z = 69, W = 12, R = 0 },
		{ X = -40, Z = 69, W = 12, R = 0 },
		{ X = -53, Z = 69, W = 12, R = 0 },
		{ X = -66, Z = 69, W = 12, R = 0 },
		-- west flank, receded row
		{ X = -20.5, Z = 61, W = 12, R = 0 },
		{ X = -33.5, Z = 61, W = 12, R = 0 },
		{ X = -46.5, Z = 61, W = 12, R = 0 },
		-- west connectors (maze corners)
		{ X = -14, Z = 65, W = 7, R = 90 },
		{ X = -40, Z = 65, W = 7, R = 90 },
		{ X = -59, Z = 65, W = 7, R = 90 },
		-- east flank, mirrored
		{ X = 14, Z = 69, W = 12, R = 0 },
		{ X = 27, Z = 69, W = 12, R = 0 },
		{ X = 40, Z = 69, W = 12, R = 0 },
		{ X = 53, Z = 69, W = 12, R = 0 },
		{ X = 66, Z = 69, W = 12, R = 0 },
		{ X = 20.5, Z = 61, W = 12, R = 0 },
		{ X = 33.5, Z = 61, W = 12, R = 0 },
		{ X = 46.5, Z = 61, W = 12, R = 0 },
		{ X = 14, Z = 65, W = 7, R = 90 },
		{ X = 40, Z = 65, W = 7, R = 90 },
	}
	for _, run in mazeRuns do
		Kit.partition(mazeFolder, place(root, run.X, 0, run.Z, run.R), palette, run.W, 6)
	end

	-- Ghost workstations tucked between the rows: someone works here. Maybe.
	for i, deskX in { -53, -27, 27, 53 } do
		local deskCf = place(root, deskX, 0, 65, 180)
		Kit.desk(mazeFolder, deskCf, palette)
		Kit.officeChair(mazeFolder, deskCf * CFrame.new(0, 0, 2.1), palette)
		Kit.monitor(mazeFolder, deskCf * CFrame.new(0.3, DESKTOP, 0.1) * yaw(180), palette)
		if i % 2 == 0 then
			Kit.paperStack(mazeFolder, deskCf * CFrame.new(-1.3, DESKTOP, 0.3), palette)
		else
			Kit.mug(mazeFolder, deskCf * CFrame.new(-1.25, DESKTOP, 0.4), palette)
		end
	end
	-- Dying plants flank the wing doorway: morale décor, off the walk line.
	Kit.pottedPlant(mazeFolder, place(root, 9.5, 0, 65.5), palette, true)
	Kit.pottedPlant(mazeFolder, place(root, -9.5, 0, 65.5), palette, true)
	Kit.pottedPlant(mazeFolder, place(root, -68, 0, 52), palette, true)

	-- The wing entrance reads from spawn: neon sign above the south doorway.
	Kit.neonSign(hubFolder, place(root, 0, 14, 73.8, 0), palette, "AUDIT WING")

	-- ═══════════════════════ AUDIT WING (corridor) ═════════════════════════
	local wingFolder = Instance.new("Folder")
	wingFolder.Name = "AuditWing"
	wingFolder.Parent = parent

	local wingOpts: Kit.RoomOpts = {
		windows = false,
		ceiling = true,
		doors = {
			{ Wall = "N", Offset = 0, Width = HUB_DOOR_WIDTH } :: Kit.RoomDoor,
			{ Wall = "S", Offset = 0, Width = BOSS_DOOR_WIDTH } :: Kit.RoomDoor,
		},
	}
	Kit.room(wingFolder, root * CFrame.new(0, 0, WING_START + WING_LENGTH / 2), WING_WIDTH, WING_HEIGHT, WING_LENGTH, palette, wingOpts)
	-- room() keeps corridor lights sparse; a centre string every 25 studs
	-- keeps the audit trench as flatly overlit as the hub.
	for i = 0, 12 do
		Kit.ceilingLight(wingFolder, place(root, 0, WING_HEIGHT - 0.2, 90 + i * 25), palette)
	end
	Kit.neonSign(wingFolder, place(root, 0, 13.5, WING_START + 1.2, 180), palette, "AUDIT WING")

	-- Rival packs: DefIndex → Config/Rivals.ByFloor.CubicleFarm. Packs sit at
	-- desks on alternating sides so each segment reads as one work group.
	type RivalPlacement = { Def: number, X: number, Dz: number }
	local segmentRivals: { { RivalPlacement } } = {
		{ { Def = 1, X = -16.5, Dz = -9 }, { Def = 1, X = -16.5, Dz = 3 }, { Def = 1, X = 16.5, Dz = -3 } },
		{ { Def = 2, X = -16.5, Dz = -9 }, { Def = 2, X = 16.5, Dz = -3 }, { Def = 2, X = -16.5, Dz = 3 } },
		{ { Def = 3, X = -16.5, Dz = -9 }, { Def = 3, X = -16.5, Dz = -1 }, { Def = 4, X = 16.5, Dz = 4 } },
		{ { Def = 4, X = -16.5, Dz = -8 }, { Def = 5, X = 16.5, Dz = -2 }, { Def = 5, X = 16.5, Dz = 6 } },
		{ { Def = 6, X = -16.5, Dz = -4 }, { Def = 6, X = 16.5, Dz = 4 } },
	}
	-- Which def a gate advertises = the pack that defines the NEXT segment.
	local dominantDef = { 1, 2, 3, 5, 6 }

	local wingPosterTexts = {
		"SYNERGY",
		"HANG IN THERE",
		"TEAMWORK MAKES THE DREAM WORK",
		"AUDIT SEASON IS EVERY SEASON",
		"THE LEDGER SEES ALL",
		"FILE EARLY. FILE OFTEN.",
		"PAPERWORK BUILDS CHARACTER",
		"THIS IS FINE",
		"COMPLIANCE IS ITS OWN REWARD",
		"MANDATORY FUN: FRIDAY 3PM",
	}

	for k = 1, SEGMENT_COUNT do
		local zc = WING_START + SEGMENT_LENGTH * (k - 1) + SEGMENT_LENGTH / 2
		local segFolder = Instance.new("Folder")
		segFolder.Name = "Segment" .. k
		segFolder.Parent = wingFolder

		for i, placement in segmentRivals[k] do
			local faceAisle = if placement.X < 0 then -90 else 90
			local bodyCf = buildRivalDesk(segFolder, place(root, placement.X, 0, zc + placement.Dz, faceAisle), palette, k * 3 + i)
			table.insert(rivalSpots, { DefIndex = placement.Def, Cf = bodyCf })
		end

		-- Mid-segment cabinet stacks against both walls: the audit archive
		-- pressing in from the sides. Segment 5's east stack pulls forward so
		-- it stays clear of the boss-gate canyon felt at the segment's end.
		buildCabinetCluster(segFolder, root, -21.9, zc - 26, palette)
		buildCabinetCluster(segFolder, root, 21.9, zc + (if k == SEGMENT_COUNT then 16 else 24), palette)

		-- Corridor wall inner faces sit at ±23; posters hang 0.055 proud.
		Kit.poster(segFolder, place(root, 22.87, 8, zc - 14, 90), palette, 6, 8, wingPosterTexts[k * 2 - 1])
		Kit.poster(segFolder, place(root, -22.87, 8, zc + 10, -90), palette, 6, 8, wingPosterTexts[k * 2])

		-- Loose floor paperwork at the aisle edges: on every surface includes
		-- the carpet.
		Kit.paperStack(segFolder, place(root, 9, 0, zc - 18, 25), palette)
		Kit.paperStack(segFolder, place(root, -9, 0, zc + 16, -15), palette)

		-- One signature prop per segment so no two stretches feel copied.
		if k == 1 then
			Kit.photocopier(segFolder, place(root, 21.4, 0, zc + 16, 90), palette)
		elseif k == 2 then
			Kit.waterCooler(segFolder, place(root, -22.3, 0, zc + 14, -90), palette)
			Kit.swivelChair(segFolder, place(root, 9.5, 0, zc + 20, 140), palette)
		elseif k == 3 then
			Kit.whiteboard(segFolder, place(root, 21.8, 0, zc + 14, 90), palette)
		elseif k == 4 then
			-- zc+18 keeps the shelf's backboard off the wall poster hung at zc+10.
			Kit.bookshelf(segFolder, place(root, -22.2, 0, zc + 18, -90), palette)
			Kit.swivelChair(segFolder, place(root, -9.5, 0, zc - 16, -130), palette)
		else
			Kit.pottedPlant(segFolder, place(root, 21.5, 0, zc + 12), palette, true)
			Kit.paperStack(segFolder, place(root, -21.5, 0, zc + 10), palette)
			Kit.paperStack(segFolder, place(root, -20.6, 0, zc + 11.4, 40), palette)
		end
	end

	-- Gates + payday pads. Gates 1-4 sit on segment boundaries; gate 5 stands
	-- just short of the boss doors so its arch frames Deborah's entrance.
	for k = 1, SEGMENT_COUNT do
		local zGate = if k < SEGMENT_COUNT then WING_START + SEGMENT_LENGTH * k else WING_START + WING_LENGTH - 9
		local gateFolder = Instance.new("Folder")
		gateFolder.Name = "Gate" .. k
		gateFolder.Parent = wingFolder

		-- Label = the next pack's title + workload, straight from Config so a
		-- balance retune can never desync the signage (§5 self-select rule).
		local nextDef = if k < SEGMENT_COUNT then defs[dominantDef[k + 1]] else defs[7]
		local label = ("NEXT: %s — %s WORKLOAD"):format(nextDef.Title:upper(), Format.abbreviate(nextDef.Workload))
		Kit.gateArch(gateFolder, place(root, 0, 0, zGate), palette, label)
		buildGateCanyon(gateFolder, root, zGate, palette, k < SEGMENT_COUNT)

		-- Pad sits beside the approach lane, 8 studs before the canyon: the
		-- straight walk through the arch never touches it (§5 pure upside).
		local padSide = if k % 2 == 1 then -13 else 13
		local pad = Kit.paydayPad(gateFolder, place(root, padSide, 0, zGate - 8), palette)
		table.insert(paydayPads, { Segment = k, Pad = pad :: BasePart })
		Kit.pottedPlant(gateFolder, place(root, if padSide < 0 then -19.5 else 19.5, 0, zGate - 6), palette, true)
	end

	-- ═══════════════════════ BOSS OFFICE ═══════════════════════════════════
	local bossFolder = Instance.new("Folder")
	bossFolder.Name = "BossOffice"
	bossFolder.Parent = parent

	-- Windowless "corner office": Deborah's power is expressed entirely in
	-- door count. Both rooms cut the same 20-wide opening so the two double
	-- doors sit in one continuous frame.
	local bossOpts: Kit.RoomOpts = {
		windows = false,
		ceiling = true,
		doors = { { Wall = "N", Offset = 0, Width = BOSS_DOOR_WIDTH } :: Kit.RoomDoor },
	}
	Kit.room(bossFolder, root * CFrame.new(0, 0, BOSS_CENTER_Z), BOSS_SIZE, BOSS_HEIGHT, BOSS_SIZE, palette, bossOpts)

	local doorZ = WING_START + WING_LENGTH -- shared wall plane between wing and office
	Kit.doubleDoor(bossFolder, place(root, -4.6, 0, doorZ), palette)
	Kit.doubleDoor(bossFolder, place(root, 4.6, 0, doorZ), palette)
	-- Lintel bridges the slit between the door frames (10 tall) and the wall
	-- headers (11 up): without it you could peek over the doors into the void.
	local lintel = Kit.part(bossFolder, place(root, 0, 10.55, doorZ), Vector3.new(20.4, 1.1, 2.4), Palettes.color(palette.Dark))
	lintel.CanCollide = true

	local bossDeskCf = place(root, 0, 0, BOSS_CENTER_Z + 15)
	Kit.bossDesk(bossFolder, bossDeskCf, palette)
	-- bossDesk's cap tops out at +3.02; desk clutter sinks 0.05 into it.
	Kit.monitor(bossFolder, bossDeskCf * CFrame.new(2.2, 2.97, 0.6) * yaw(180), palette)
	Kit.paperStack(bossFolder, bossDeskCf * CFrame.new(-2.5, 2.97, 0.5), palette)
	Kit.mug(bossFolder, bossDeskCf * CFrame.new(-3.6, 2.97, -0.6), palette)
	Kit.officeChair(bossFolder, place(root, 0, 0, BOSS_CENTER_Z + 23.8), palette, Palettes.color(palette.Dark))
	Kit.rug(bossFolder, place(root, 0, 0, BOSS_CENTER_Z + 9), palette, 16, 10)

	-- The trophy wall behind the desk. Boss room inner faces sit at ±29/z 464.
	Kit.poster(bossFolder, place(root, 0, 9.5, BOSS_CENTER_Z + 28.87, 0), palette, 10, 7, "WORLD'S OKAYEST MANAGER")
	Kit.trimStrip(bossFolder, place(root, -8.5, 12, BOSS_CENTER_Z + 28.94), palette, 6)
	Kit.trimStrip(bossFolder, place(root, 8.5, 12, BOSS_CENTER_Z + 28.94), palette, 6)

	Kit.bookshelf(bossFolder, place(root, 28.1, 0, BOSS_CENTER_Z + 7, 90), palette)
	Kit.bookshelf(bossFolder, place(root, 28.1, 0, BOSS_CENTER_Z + 15, 90), palette)
	Kit.filingCabinet(bossFolder, place(root, -27.9, 0, BOSS_CENTER_Z + 9, -90), palette)
	Kit.filingCabinet(bossFolder, place(root, -27.9, 0, BOSS_CENTER_Z + 11, -90), palette)
	Kit.paperStack(bossFolder, place(root, -27.9, CABINET_STACK + 0.01, BOSS_CENTER_Z + 10, -90), palette)
	Kit.whiteboard(bossFolder, place(root, -27.8, 0, BOSS_CENTER_Z - 3, -90), palette)
	Kit.pottedPlant(bossFolder, place(root, -26, 0, BOSS_CENTER_Z + 26), palette, false)
	Kit.pottedPlant(bossFolder, place(root, 26, 0, BOSS_CENTER_Z + 26), palette, false)
	Kit.pottedPlant(bossFolder, place(root, -12, 0, BOSS_CENTER_Z - 26), palette, true)
	Kit.poster(bossFolder, place(root, 28.87, 9, BOSS_CENTER_Z - 8, 90), palette, 7, 6, "SYNERGY")

	-- Deborah stands behind her desk facing the doors she made you walk
	-- through twice. Def 7 = the floor boss in Config/Rivals.
	table.insert(rivalSpots, { DefIndex = 7, Cf = place(root, 0, 0, BOSS_CENTER_Z + 20) })

	-- ════════════════════════════ MANIFEST ═════════════════════════════════
	return {
		-- Spawn faces north: elevator, boards and both wings of stations are
		-- all in frame in the first second (10-year-old readability rule).
		Spawn = root * CFrame.new(0, 3, 0),
		RivalSpots = rivalSpots,
		TrainingZones = trainingZones,
		PaydayPads = paydayPads,
		Prompts = {
			Shop = primaryOf(shopModel),
			Coffee = primaryOf(coffeeModel),
			Hr = primaryOf(hrModel),
			Elevator = primaryOf(elevatorPanel),
		},
		Boards = {
			Eotm = primaryOf(eotmModel),
			Wins = primaryOf(winsModel),
		},
	}
end

return { build = build }
