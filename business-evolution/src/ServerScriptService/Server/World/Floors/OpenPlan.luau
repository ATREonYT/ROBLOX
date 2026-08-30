--!strict
-- OpenPlan — Floor 12, the relief floor. After the fluorescent purgatory of
-- the Cubicle Farm, this is a warm startup loft: exposed brick, wood floor,
-- cream furniture, plants on every surface, big windows full of sky, a neon
-- HUSTLE sign over the training desks and a kombucha tap nobody asked for.
-- The grind corridor is the GROWTH WING (whiteboards of up-and-to-the-right
-- graphs between pillar-and-brick arches) and Brett waits at the end in a
-- glass cube furnished with exactly one beanbag and the word "DISRUPT".
--
-- Pure geometry builder: everything is positioned by CFrame composition off
-- the `origin` MapService hands us, colours come only from the floor palette
-- (plus a few fixed joke colours: aged paper is aged paper on every floor),
-- and the returned Manifest is the one contract other services consume.
-- Rough part budget (counted per Kit call): hub ≈ 860, wing ≈ 680,
-- boss office ≈ 180 → ≈ 1720 total, inside the ≤ 2800 floor cap.

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

-- Window openings are carved with room() door cuts (full-height gap + header)
-- and then filled with Kit.windowWall, so brick stays brick and glass shows
-- sky instead of a brick wall pretending behind it. Cut height is 11 (room's
-- door header start), so the fill is built exactly 11 tall to meet it.
local WINDOW_HEIGHT = 11

-- Desktop items sit with their base sunk ~0.05 into the desk's bevel cap
-- (cap top ends at +1.925): flush contact without coplanar faces.
local DESKTOP = 1.87

-- Fixed non-palette colours: props whose joke depends on the exact shade.
local INK = Color3.fromRGB(45, 42, 40)
local COLOR_KOMBUCHA = Color3.fromRGB(224, 166, 80) -- scoby amber, not water blue
local COLOR_AGED_PAPER = Color3.fromRGB(233, 222, 188) -- yellowed "back in 5" card
local COLOR_MARKER_RED = Color3.fromRGB(206, 66, 60) -- whiteboard marker
local COLOR_BOARD_WHITE = Color3.fromRGB(248, 248, 246)

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

-- ── Open-plan signature props ───────────────────────────────────────────────

-- Kombucha tap = the water cooler with its bottle recoloured scoby-amber.
-- The bottle is the only translucent part in the model, so recolouring by
-- transparency is deterministic without knowing Kit's internal part names.
local function buildKombuchaTap(parent: Instance, cf: CFrame, palette: Palette): Model
	local cooler = Kit.waterCooler(parent, cf, palette)
	for _, inst in cooler:GetDescendants() do
		if inst:IsA("BasePart") and inst.Transparency > 0.05 and inst.Transparency < 1 then
			inst.Color = COLOR_KOMBUCHA
		end
	end
	return cooler
end

-- Wall-mounted plant shelf (cf = shelf centre, mounted convention): a dark
-- bracket board with healthy plants standing on its top face — the cheap way
-- to get greenery at eye level per "plants EVERYWHERE, some on shelves".
local function buildPlantShelf(parent: Instance, cf: CFrame, palette: Palette, plantOffsets: { number })
	Kit.part(parent, cf, Vector3.new(7, 0.3, 1.5), Palettes.color(palette.Dark))
	for _, dx in plantOffsets do
		Kit.pottedPlant(parent, cf * CFrame.new(dx, 0.15, 0), palette, false)
	end
end

-- Brett's whiteboard: same legs-and-board silhouette as Kit.whiteboard, but
-- instead of the hockey-stick graph it carries one giant marker-red word.
local function buildDisruptBoard(parent: Instance, cf: CFrame, palette: Palette)
	local dark = Palettes.color(palette.Dark)
	for _, x in { -2.7, 2.7 } do
		Kit.part(parent, cf * CFrame.new(x, 2.6, 0), Vector3.new(0.3, 5.2, 0.3), dark)
		Kit.part(parent, cf * CFrame.new(x, 0.1, 0), Vector3.new(0.3, 0.2, 1.3), dark)
	end
	local board = Kit.part(parent, cf * CFrame.new(0, 3.3, 0), Vector3.new(6, 3.6, 0.25), COLOR_BOARD_WHITE)
	board.CanCollide = false
	Kit.part(parent, cf * CFrame.new(0, 1.4, -0.25), Vector3.new(5, 0.15, 0.35), dark)
	local label = Kit.textLabelOn(board, Enum.NormalId.Front, "DISRUPT", COLOR_MARKER_RED)
	label.TextStrokeTransparency = 1 -- marker on a whiteboard has no outline
end

type TrainingDeskOpts = {
	Standing: boolean?, -- tier-2 plinth variant (no chair)
	Seed: number, -- deterministic clutter picker so servers match
}

-- One open-plan trestle workstation: no cubicle felt anywhere — the desks sit
-- in the open with a chair, a glowing monitor turned back toward the worker,
-- and rotating clutter (every third desk gets its own succulent, obviously).
local function buildTrainingDesk(parent: Instance, cf: CFrame, palette: Palette, opts: TrainingDeskOpts)
	local deskCf = cf
	if opts.Standing then
		-- Standing desk = trestle desk on a chunky plinth; cheap and readable.
		local plinth = Kit.part(parent, cf * CFrame.new(0, 0.4, 0.4), Vector3.new(6, 0.8, 4.6), Palettes.color(palette.Dark))
		plinth.CanCollide = true
		deskCf = cf * CFrame.new(0, 0.8, 0)
	else
		Kit.officeChair(parent, cf * CFrame.new(0, 0, 2.1), palette)
	end

	Kit.desk(parent, deskCf, palette)
	Kit.monitor(parent, deskCf * CFrame.new(0.35, DESKTOP, 0.1) * yaw(180), palette)
	Kit.keyboardProp(parent, deskCf * CFrame.new(0, DESKTOP, 0.55) * yaw(180), palette)
	local pick = opts.Seed % 3
	if pick == 0 then
		Kit.mug(parent, deskCf * CFrame.new(-1.3, DESKTOP, 0.4), palette)
	elseif pick == 1 then
		Kit.paperStack(parent, deskCf * CFrame.new(-1.35, DESKTOP, 0.25), palette)
	else
		Kit.pottedPlant(parent, deskCf * CFrame.new(-1.3, DESKTOP, 0.15), palette, false)
	end
end

-- Tier-3 battlestation: rug, dual monitors, gamer-lean swivel chair and a
-- personal plant — the open-plan status symbol is desk real estate.
local function buildBattlestation(parent: Instance, cf: CFrame, palette: Palette)
	Kit.rug(parent, cf * CFrame.new(0, 0, 1), palette, 9, 8)
	Kit.desk(parent, cf, palette)
	Kit.monitor(parent, cf * CFrame.new(-0.85, DESKTOP, 0.15) * yaw(168), palette)
	Kit.monitor(parent, cf * CFrame.new(0.85, DESKTOP, 0.15) * yaw(192), palette)
	Kit.keyboardProp(parent, cf * CFrame.new(0, DESKTOP, 0.6) * yaw(180), palette)
	Kit.swivelChair(parent, cf * CFrame.new(0, 0, 2.0), palette)
	Kit.mug(parent, cf * CFrame.new(1.6, DESKTOP, -0.5), palette)
	Kit.pottedPlant(parent, cf * CFrame.new(3.2, 0, -0.4), palette, false)
end

-- ── Growth-wing pieces ──────────────────────────────────────────────────────

-- A rival's hot desk. Returns where the rival BODY stands: behind the desk,
-- LookVector down the same aisle-facing direction as the desk front.
local function buildRivalDesk(parent: Instance, cf: CFrame, palette: Palette, seed: number): CFrame
	Kit.desk(parent, cf, palette)
	Kit.monitor(parent, cf * CFrame.new(-0.45, DESKTOP, 0.1) * yaw(180), palette)
	Kit.keyboardProp(parent, cf * CFrame.new(-0.35, DESKTOP, 0.6) * yaw(180), palette)
	local pick = seed % 3
	if pick == 0 then
		Kit.mug(parent, cf * CFrame.new(1.25, DESKTOP, 0.45), palette)
	elseif pick == 1 then
		Kit.paperStack(parent, cf * CFrame.new(1.3, DESKTOP, -0.2), palette)
	else
		Kit.pottedPlant(parent, cf * CFrame.new(1.35, DESKTOP, 0.1), palette, false)
	end
	-- Every other desk gets floor greenery beside it (along the wall axis, so
	-- it never leans into the aisle walk line).
	if seed % 2 == 0 then
		Kit.pottedPlant(parent, cf * CFrame.new(-2.9, 0, 1.2), palette, false)
	end
	return cf * CFrame.new(0, 0, 2.05)
end

-- Pillar-and-brick arch on a segment boundary: two brick-toned pillars carry
-- a brick beam overhead, and brick shoulder walls seal the sides so every
-- boundary reads as a doorway in the old warehouse shell. The Kit.gateArch
-- (with its workload label) stands inside this opening — information instead
-- of a locked door (§5: never block, never kill). Opening stays 24 wide.
local function buildBrickArch(parent: Instance, root: CFrame, zGate: number, palette: Palette)
	local wallColor = Palettes.color(palette.Wall)
	for _, side in { -1, 1 } do
		Kit.pillar(parent, place(root, side * 13, 0, zGate), palette, WING_HEIGHT)
		-- Shoulder runs 0.1 into the corridor wall body so the joint can never
		-- show a sliver gap; overlapping volumes, no coplanar faces.
		local shoulder = Kit.part(parent, place(root, side * 18.4, WING_HEIGHT / 2, zGate), Vector3.new(9.4, WING_HEIGHT, 1.6), wallColor)
		shoulder.CanCollide = true
	end
	-- Beam sits above the gateArch's own beam (tops out ≈12.1) and below the
	-- ceiling at 16, so the three horizontals never share a face.
	local beam = Kit.part(parent, place(root, 0, 13.9, zGate), Vector3.new(28, 2.6, 2.2), wallColor)
	beam.CanCollide = true
end

-- ── The floor builder ───────────────────────────────────────────────────────

local function build(parent: Folder, origin: Vector3, palette: Palette): Manifest
	local root = CFrame.new(origin)
	local accent = Palettes.color(palette.Accent)
	local defs = Rivals.ByFloor.OpenPlan

	local rivalSpots: { RivalSpot } = {}
	local trainingZones: { TrainingZoneEntry } = {}
	local paydayPads: { PaydayPadEntry } = {}

	-- ════════════════════════════ HUB ══════════════════════════════════════
	local hubFolder = Instance.new("Folder")
	hubFolder.Name = "Hub"
	hubFolder.Parent = parent

	-- windows=false keeps the shell exposed brick; the sky comes in through
	-- four hand-placed window bays cut below (two sides per the floor spec).
	local hubOpts: Kit.RoomOpts = {
		windows = false,
		ceiling = true,
		doors = {
			-- South: the real doorway into the Growth Wing…
			{ Wall = "S", Offset = 0, Width = HUB_DOOR_WIDTH } :: Kit.RoomDoor,
			-- …plus window bays on the south and west walls. Offsets run along
			-- +X for N/S walls and +Z for E/W walls (room() convention).
			{ Wall = "S", Offset = -38, Width = 24 } :: Kit.RoomDoor,
			{ Wall = "S", Offset = 38, Width = 24 } :: Kit.RoomDoor,
			{ Wall = "W", Offset = -35, Width = 28 } :: Kit.RoomDoor,
			{ Wall = "W", Offset = 35, Width = 28 } :: Kit.RoomDoor,
		},
	}
	Kit.room(hubFolder, root, HUB_SIZE, HUB_HEIGHT, HUB_SIZE, palette, hubOpts)

	-- Fill the window cuts with glass. Each fill is exactly as tall as the cut
	-- (11), so its header meets the room's brick header face-to-face.
	Kit.windowWall(hubFolder, place(root, -74.5, 0, -35, -90), palette, 28, WINDOW_HEIGHT)
	Kit.windowWall(hubFolder, place(root, -74.5, 0, 35, -90), palette, 28, WINDOW_HEIGHT)
	Kit.windowWall(hubFolder, place(root, -38, 0, 74.5, 0), palette, 24, WINDOW_HEIGHT)
	Kit.windowWall(hubFolder, place(root, 38, 0, 74.5, 0), palette, 24, WINDOW_HEIGHT)

	Kit.spawnPad(hubFolder, place(root, 0, 0, 0), palette)

	-- ── North wall: elevator bank + the two boards ──
	Kit.elevatorDoors(hubFolder, place(root, -34, 0, -73.2, 180), palette)
	Kit.elevatorDoors(hubFolder, place(root, -18, 0, -73.2, 180), palette)
	local elevatorPanel = Kit.elevatorPanel(hubFolder, place(root, -26, 5, -73.8, 180), palette)
	Kit.neonSign(hubFolder, place(root, -26, 13.5, -73.8, 180), palette, "OPEN PLAN — FLOOR 12")

	local eotmModel = Kit.boardFrame(hubFolder, place(root, 8, 8, -73.6, 180), palette, "EMPLOYEE OF THE MONTH")
	local winsModel = Kit.boardFrame(hubFolder, place(root, 26, 8, -73.6, 180), palette, "ALL-TIME WINS")
	-- Greenery under and between the boards: this floor decorates with plants
	-- where the Cubicle Farm would have filed something.
	buildPlantShelf(hubFolder, place(root, 17, 4.8, -73.2), palette, { -1.9, 1.7 })
	for _, x in { 5, 12, 23, 30 } do
		Kit.pottedPlant(hubFolder, place(root, x, 0, -71.3), palette, false)
	end

	-- NW corner: the office "library" — bookshelves with plants on top.
	Kit.bookshelf(hubFolder, place(root, -50, 0, -73.2, 180), palette)
	Kit.bookshelf(hubFolder, place(root, -45, 0, -73.2, 180), palette)
	Kit.pottedPlant(hubFolder, place(root, -50, 7.05, -73.2), palette, false)
	Kit.pottedPlant(hubFolder, place(root, -45, 7.05, -73.2), palette, false)
	Kit.pottedPlant(hubFolder, place(root, -57, 0, -71), palette, false)
	Kit.pottedPlant(hubFolder, place(root, -60, 0, -69), palette, false)
	Kit.poster(hubFolder, place(root, -62, 9, -73.87, 180), palette, 8, 6, "PLANTS ARE COWORKERS")

	-- NE corner: mindfulness lounge (rug + beanbags + one more bookshelf).
	Kit.rug(hubFolder, place(root, 58, 0, -66), palette, 12, 10)
	Kit.beanbag(hubFolder, place(root, 54.5, 0, -67.5), palette)
	Kit.beanbag(hubFolder, place(root, 61, 0, -63), palette)
	Kit.bookshelf(hubFolder, place(root, 48, 0, -73.2, 180), palette)
	Kit.pottedPlant(hubFolder, place(root, 48, 7.05, -73.2), palette, false)
	Kit.pottedPlant(hubFolder, place(root, 67, 0, -70), palette, false)
	Kit.poster(hubFolder, place(root, 56, 9, -73.87, 180), palette, 8, 6, "MINDFULNESS CORNER (AT CAPACITY)")

	-- ── East wall: gear shop, espresso hero prop, HR, and the kombucha tap ──
	local shopModel = Kit.shopKiosk(hubFolder, place(root, 71, 0, -30, 90), palette)
	local coffeeModel = Kit.coffeeMachineBig(hubFolder, place(root, 70, 0, 0, 90), palette)
	local hrModel = Kit.hrDesk(hubFolder, place(root, 70.5, 0, 30, 90), palette)

	buildKombuchaTap(hubFolder, place(root, 71, 0, 14, 90), palette)
	Kit.neonSign(hubFolder, place(root, 73.8, 7.5, 14, 90), palette, "KOMBUCHA")
	-- Crates of "small batch" refills double as clutter beside the tap.
	Kit.cardboardStack(hubFolder, place(root, 71.2, 0, 19, 15), palette, 2)

	Kit.pottedPlant(hubFolder, place(root, 70.5, 0, -14), palette, false)
	Kit.pottedPlant(hubFolder, place(root, 70.5, 0, -45), palette, false)
	Kit.pottedPlant(hubFolder, place(root, 70.5, 0, 40), palette, false)
	Kit.pottedPlant(hubFolder, place(root, 70, 0, 22), palette, false)
	-- East wall inner face sits at 74; posters hang 0.13 proud, same as every
	-- floor, so nothing z-fights against the brick.
	Kit.poster(hubFolder, place(root, 73.87, 9, -38, 90), palette, 7, 6, "GEAR UP, GO UP")
	-- z=25 keeps this poster's paper clear of the KOMBUCHA sign board (ends
	-- z≈19.3 on the same wall plane): near-coplanar overlaps shimmer.
	Kit.poster(hubFolder, place(root, 73.87, 9, 25, 90), palette, 7, 6, "KOMBUCHA: PROBABLY FINE")
	Kit.poster(hubFolder, place(root, 73.87, 9, 45, 90), palette, 7, 6, "HR IS YOUR FRIEND*")

	-- SE corner: hot-desk pod, because assigned seating is over, apparently.
	Kit.rug(hubFolder, place(root, 56, 0, 58), palette, 14, 12)
	local hotA = place(root, 53, 0, 55, 135)
	Kit.desk(hubFolder, hotA, palette)
	Kit.officeChair(hubFolder, hotA * CFrame.new(0, 0, 2.1), palette)
	Kit.monitor(hubFolder, hotA * CFrame.new(0.3, DESKTOP, 0.1) * yaw(180), palette)
	local hotB = place(root, 60, 0, 61, -160)
	Kit.desk(hubFolder, hotB, palette)
	Kit.officeChair(hubFolder, hotB * CFrame.new(0, 0, 2.1), palette)
	Kit.paperStack(hubFolder, hotB * CFrame.new(-1.3, DESKTOP, 0.3), palette)
	Kit.pottedPlant(hubFolder, place(root, 67, 0, 67), palette, false)
	Kit.pottedPlant(hubFolder, place(root, 48, 0, 69.5), palette, false)
	Kit.poster(hubFolder, place(root, 60, 9, 73.87, 0), palette, 8, 6, "HOT DESKS: BYO CHAIR")

	-- ── South wall: doorway to the wing, flanked by brick + glass + slogans ──
	Kit.neonSign(hubFolder, place(root, 0, 14, 73.8, 0), palette, "GROWTH WING")
	Kit.pottedPlant(hubFolder, place(root, -9.5, 0, 70.5), palette, false)
	Kit.pottedPlant(hubFolder, place(root, 9.5, 0, 70.5), palette, false)
	Kit.poster(hubFolder, place(root, -17, 9, 73.87, 0), palette, 8, 6, "WE'RE A FAMILY (MANDATORY)")
	Kit.poster(hubFolder, place(root, 17, 9, 73.87, 0), palette, 8, 6, "FAIL FORWARD FASTER")

	-- SW corner: the plant jungle — the floor's thesis statement.
	Kit.rug(hubFolder, place(root, -61, 0, 58), palette, 12, 12)
	Kit.pottedPlant(hubFolder, place(root, -60, 0, 55), palette, false)
	Kit.pottedPlant(hubFolder, place(root, -64, 0, 58.5), palette, false)
	Kit.pottedPlant(hubFolder, place(root, -58, 0, 61), palette, false)
	Kit.pottedPlant(hubFolder, place(root, -66, 0, 53), palette, false)
	Kit.pottedPlant(hubFolder, place(root, -61, 0, 65), palette, false)
	Kit.poster(hubFolder, place(root, -73.87, 9, 58, -90), palette, 7, 6, "BREATHE (SPONSORED)")

	-- ── Centre south: chill circle + the untouched ping-pong shrine ──
	Kit.rug(hubFolder, place(root, 0, 0, 30), palette, 16, 12)
	Kit.beanbag(hubFolder, place(root, -8, 0, 32), palette)
	Kit.beanbag(hubFolder, place(root, 8, 0, 28), palette)

	-- Beanbag cluster proper (the spec's second seating pit, west of centre).
	Kit.rug(hubFolder, place(root, -32, 0, 47), palette, 16, 14)
	Kit.beanbag(hubFolder, place(root, -37, 0, 43), palette)
	Kit.beanbag(hubFolder, place(root, -30, 0, 41.5), palette)
	Kit.beanbag(hubFolder, place(root, -26, 0, 47), palette)
	Kit.beanbag(hubFolder, place(root, -36, 0, 51), palette)
	Kit.beanbag(hubFolder, place(root, -29, 0, 52.5), palette)
	Kit.mug(hubFolder, place(root, -32.5, 0.12, 47.5), palette)
	Kit.pottedPlant(hubFolder, place(root, -40.5, 0, 51), palette, false)
	Kit.pottedPlant(hubFolder, place(root, -23.5, 0, 41), palette, false)

	-- The ping-pong table nobody has ever played on: abandoned paperwork on
	-- the tabletop, a dying plant beside it, and a yellowed "back in 5" card
	-- that has clearly been leaning against the net since 2019.
	local ppCf = place(root, 30, 0, 49, 25)
	Kit.pingpongTable(hubFolder, ppCf, palette)
	Kit.paperStack(hubFolder, ppCf * CFrame.new(2.2, 2.56, -1.3), palette)
	local backInFive = Kit.part(
		hubFolder,
		ppCf * CFrame.new(-0.6, 3.13, 0.9) * CFrame.Angles(math.rad(-12), math.rad(14), 0),
		Vector3.new(1.8, 1.2, 0.08),
		COLOR_AGED_PAPER
	)
	Kit.textLabelOn(backInFive, Enum.NormalId.Front, "BACK IN 5 — EST. 2019", INK)
	Kit.pottedPlant(hubFolder, place(root, 36, 0, 44), palette, true)

	-- ═══════════════════ TRAINING AREA (west) ══════════════════════════════
	local trainingFolder = Instance.new("Folder")
	trainingFolder.Name = "Training"
	trainingFolder.Parent = hubFolder

	-- The HUSTLE sign hangs on the brick strip between the two window bays,
	-- dead over the training rows, in the floor's Accent green.
	Kit.neonSign(trainingFolder, place(root, -73.8, 13, 0, -90), palette, "H U S T L E", accent)
	buildPlantShelf(trainingFolder, place(root, -73.2, 4.7, -9, -90), palette, { -1.9, 1.7 })
	buildPlantShelf(trainingFolder, place(root, -73.2, 4.7, 9, -90), palette, { -1.7, 1.9 })
	Kit.poster(trainingFolder, place(root, -73.87, 9, -57, -90), palette, 7, 6, "RISE & GRIND")

	-- Tier 1 — six trestle desks in two loose rows, all facing east so the
	-- whole area reads from spawn in one glance.
	for rowIndex, rowX in { -56, -44 } do
		for i, cellZ in { -18, -8, 2 } do
			buildTrainingDesk(trainingFolder, place(root, rowX, 0, cellZ, -90), palette, {
				Seed = rowIndex * 3 + i,
			})
		end
	end
	local tier1Zone = buildZonePart(trainingFolder, place(root, -50, 4, -8), Vector3.new(22, 8, 30), palette)
	table.insert(trainingZones, { Rate = Balance.TrainingTierRates[1], MinRank = Balance.TrainingTierMinRank[1], Zone = tier1Zone })
	floatingLabel(trainingFolder, place(root, -50, 9.5, -8), 13, trainingSignText(1), accent)

	-- Tier 2 — three standing desks on plinths in front of the south window
	-- bay: better light, better posture, better multiplier.
	for i, cellZ in { 20, 30, 40 } do
		buildTrainingDesk(trainingFolder, place(root, -54, 0, cellZ, -90), palette, {
			Standing = true,
			Seed = i + 1,
		})
	end
	local tier2Zone = buildZonePart(trainingFolder, place(root, -54, 4, 30), Vector3.new(14, 8, 28), palette)
	table.insert(trainingZones, { Rate = Balance.TrainingTierRates[2], MinRank = Balance.TrainingTierMinRank[2], Zone = tier2Zone })
	floatingLabel(trainingFolder, place(root, -54, 10, 30), 14, trainingSignText(2), accent)

	-- Tier 3 — two dual-monitor battlestations in the quiet NW corner.
	buildBattlestation(trainingFolder, place(root, -58, 0, -52, -90), palette)
	buildBattlestation(trainingFolder, place(root, -58, 0, -42, -90), palette)
	local tier3Zone = buildZonePart(trainingFolder, place(root, -58, 4, -47), Vector3.new(12, 8, 20), palette)
	table.insert(trainingZones, { Rate = Balance.TrainingTierRates[3], MinRank = Balance.TrainingTierMinRank[3], Zone = tier3Zone })
	floatingLabel(trainingFolder, place(root, -58, 10.5, -47), 14, trainingSignText(3), accent)

	-- Stray greenery between the desk rows: no bare wood anywhere.
	Kit.pottedPlant(trainingFolder, place(root, -38, 0, -14), palette, false)
	Kit.pottedPlant(trainingFolder, place(root, -47, 0, 9), palette, false)
	Kit.pottedPlant(trainingFolder, place(root, -63, 0, 24), palette, false)

	-- ═══════════════════════ GROWTH WING (corridor) ════════════════════════
	local wingFolder = Instance.new("Folder")
	wingFolder.Name = "GrowthWing"
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
	Kit.neonSign(wingFolder, place(root, 0, 13.5, WING_START + 1.2, 180), palette, "GROWTH WING")

	-- Rival packs: DefIndex → Config/Rivals.ByFloor.OpenPlan. Copies of a def
	-- sit on the same side at staggered depths so each pack reads as one
	-- huddle; the odd def out sits across the aisle.
	type RivalPlacement = { Def: number, X: number, Dz: number }
	local segmentRivals: { { RivalPlacement } } = {
		{ { Def = 1, X = -16.5, Dz = -10 }, { Def = 1, X = -16.5, Dz = 2 }, { Def = 1, X = 16.5, Dz = -4 } },
		{ { Def = 2, X = 16.5, Dz = -10 }, { Def = 2, X = 16.5, Dz = 2 }, { Def = 2, X = -16.5, Dz = -4 } },
		{ { Def = 3, X = -16.5, Dz = -9 }, { Def = 3, X = -16.5, Dz = -1 }, { Def = 4, X = 16.5, Dz = 4 } },
		{ { Def = 4, X = -16.5, Dz = -8 }, { Def = 5, X = 16.5, Dz = -2 }, { Def = 5, X = 16.5, Dz = 6 } },
		{ { Def = 6, X = -16.5, Dz = -4 }, { Def = 6, X = 16.5, Dz = 4 } },
	}
	-- Which def a gate advertises = the pack that defines the NEXT segment.
	local dominantDef = { 1, 2, 3, 5, 6 }

	-- Rug under each segment's main huddle: green "zones" on the wood floor.
	type PackRug = { X: number, Dz: number, W: number, L: number }
	local packRugs: { PackRug } = {
		{ X = -17.5, Dz = -4, W = 10, L = 18 },
		{ X = 17.5, Dz = -4, W = 10, L = 18 },
		{ X = -17.5, Dz = -5, W = 10, L = 14 },
		{ X = 17.5, Dz = 2, W = 10, L = 14 },
		{ X = -17.5, Dz = -4, W = 10, L = 8 },
	}

	local wingPosterTexts = {
		"UP AND TO THE RIGHT",
		"GROWTH IS A MINDSET",
		"DISRUPT YOURSELF FIRST",
		"ITERATE. ITERATE. ITERATE.",
		"THE HOCKEY STICK IS COMING",
		"MVP = MOST VALUABLE PLAYER",
		"OUR CULTURE IS OUR MOAT",
		"HUSTLE HARDER",
		"FREE FRUIT FRIDAYS (CANCELLED)",
		"SHIP IT AND SEE",
	}

	for k = 1, SEGMENT_COUNT do
		local zc = WING_START + SEGMENT_LENGTH * (k - 1) + SEGMENT_LENGTH / 2
		local segFolder = Instance.new("Folder")
		segFolder.Name = "Segment" .. k
		segFolder.Parent = wingFolder

		local rugSpec = packRugs[k]
		Kit.rug(segFolder, place(root, rugSpec.X, 0, zc + rugSpec.Dz), palette, rugSpec.W, rugSpec.L)

		for i, placement in segmentRivals[k] do
			local faceAisle = if placement.X < 0 then -90 else 90
			local bodyCf = buildRivalDesk(segFolder, place(root, placement.X, 0, zc + placement.Dz, faceAisle), palette, k * 3 + i)
			table.insert(rivalSpots, { DefIndex = placement.Def, Cf = bodyCf })
		end

		-- The wing's identity: whiteboards of graphs going up, one per wall
		-- per segment. Kit.whiteboard already draws the hockey stick.
		Kit.whiteboard(segFolder, place(root, 21.8, 0, zc + 8, 90), palette)
		Kit.whiteboard(segFolder, place(root, -21.8, 0, zc - 14, -90), palette)

		-- Corridor wall inner faces sit at ±23; posters hang 0.13 proud.
		Kit.poster(segFolder, place(root, 22.87, 8, zc - 10, 90), palette, 6, 7, wingPosterTexts[k * 2 - 1])
		Kit.poster(segFolder, place(root, -22.87, 8, zc + 12, -90), palette, 6, 7, wingPosterTexts[k * 2])

		-- Plant shelf alternates walls so greenery is always in frame.
		if k % 2 == 1 then
			buildPlantShelf(segFolder, place(root, 22.2, 4.6, zc + 22, 90), palette, { -1.8, 1.6 })
		else
			buildPlantShelf(segFolder, place(root, -22.2, 4.6, zc + 22, -90), palette, { -1.6, 1.8 })
		end
		Kit.pottedPlant(segFolder, place(root, -21.6, 0, zc - 26), palette, false)
		Kit.pottedPlant(segFolder, place(root, 21.6, 0, zc + 28), palette, false)

		-- One signature prop per segment so no two stretches feel copied.
		if k == 1 then
			-- Kombucha rest stop for the long march ahead.
			buildKombuchaTap(segFolder, place(root, 21.4, 0, zc + 18, 90), palette)
			Kit.cardboardStack(segFolder, place(root, 21.5, 0, zc + 13.5, -10), palette, 2)
		elseif k == 2 then
			Kit.rug(segFolder, place(root, 17, 0, zc + 16), palette, 10, 8)
			Kit.beanbag(segFolder, place(root, 15.5, 0, zc + 13.5), palette)
			Kit.beanbag(segFolder, place(root, 19, 0, zc + 18.5), palette)
		elseif k == 3 then
			Kit.bookshelf(segFolder, place(root, -22.2, 0, zc + 18, -90), palette)
			Kit.pottedPlant(segFolder, place(root, -22.2, 7.05, zc + 18), palette, false)
			Kit.whiteboard(segFolder, place(root, 21.8, 0, zc - 22, 90), palette)
			-- Mid-wing thesis, in neon, where segment 3 needs a landmark.
			Kit.neonSign(segFolder, place(root, 22.7, 11.5, zc, 90), palette, "UP AND TO THE RIGHT", accent)
		elseif k == 4 then
			Kit.photocopier(segFolder, place(root, 21.4, 0, zc + 16, 90), palette)
			Kit.paperStack(segFolder, place(root, 18.5, 0, zc + 14), palette)
		else
			Kit.neonSign(segFolder, place(root, -22.7, 11, zc, -90), palette, "SHIP IT", accent)
			Kit.beanbag(segFolder, place(root, 19.5, 0, zc + 8), palette)
		end
	end

	-- Gates + payday pads. Gates 1-4 sit on segment boundaries; gate 5 stands
	-- just short of the boss doors so its arch frames Brett's glass cube.
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
		buildBrickArch(gateFolder, root, zGate, palette)

		-- Pad sits beside the approach lane, 9 studs before the arch and off
		-- the 24-wide opening's line: stepping on it is always a choice, the
		-- straight walk through the arch never touches it (§5 pure upside).
		local padSide = if k % 2 == 1 then -14 else 14
		local pad = Kit.paydayPad(gateFolder, place(root, padSide, 0, zGate - 9), palette)
		table.insert(paydayPads, { Segment = k, Pad = pad :: BasePart })
		Kit.pottedPlant(gateFolder, place(root, if padSide < 0 then padSide - 5.5 else padSide + 5.5, 0, zGate - 7), palette, false)
	end

	-- ═══════════════════════ BOSS OFFICE ═══════════════════════════════════
	local bossFolder = Instance.new("Folder")
	bossFolder.Name = "BossOffice"
	bossFolder.Parent = parent

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

	-- Brett's glass cube: four windowWall partitions pinned by brick pillars,
	-- with an 8-wide gap in the north face as the "door". Open-topped, so the
	-- 2.5×-scale boss the client renders can loom over his own office.
	local CUBE_Z = BOSS_CENTER_Z + 6
	Kit.windowWall(bossFolder, place(root, 0, 0, CUBE_Z + 12, 0), palette, 22, 9)
	Kit.windowWall(bossFolder, place(root, 12, 0, CUBE_Z, 90), palette, 22, 9)
	Kit.windowWall(bossFolder, place(root, -12, 0, CUBE_Z, -90), palette, 22, 9)
	Kit.windowWall(bossFolder, place(root, -7.5, 0, CUBE_Z - 12, 0), palette, 7, 9)
	Kit.windowWall(bossFolder, place(root, 7.5, 0, CUBE_Z - 12, 0), palette, 7, 9)
	for _, corner in { Vector2.new(-12, -12), Vector2.new(12, -12), Vector2.new(-12, 12), Vector2.new(12, 12) } do
		Kit.pillar(bossFolder, place(root, corner.X, 0, CUBE_Z + corner.Y), palette, 9)
	end
	-- Nameplate hangs over the cube's entrance gap, 0.1 proud of the sill
	-- face so it reads as bolted on without sharing a plane with the glass.
	Kit.neonSign(bossFolder, place(root, 0, 8.4, CUBE_Z - 12.7, 0), palette, "BRETT'S CUBE")

	-- Inside the cube: green rug, the beanbag throne on a plinth, the DISRUPT
	-- board, one plant, and a kombucha mug abandoned on the floor.
	Kit.rug(bossFolder, place(root, 0, 0, CUBE_Z + 2), palette, 16, 14)
	Kit.bevelBlock(bossFolder, place(root, 0, 0.25, CUBE_Z + 8.5), Vector3.new(5.5, 0.5, 5.5), Palettes.color(palette.Dark))
	Kit.beanbag(bossFolder, place(root, 0, 0.57, CUBE_Z + 8.5), palette)
	-- Gold trims rest ON the plinth cap (sunk 0.02) at its edges: throne bling
	-- that never floats and never shares a face with the cap top.
	Kit.trimStrip(bossFolder, place(root, -2.4, 0.65, CUBE_Z + 8.5, 90), palette, 5.0)
	Kit.trimStrip(bossFolder, place(root, 2.4, 0.65, CUBE_Z + 8.5, 90), palette, 5.0)
	buildDisruptBoard(bossFolder, place(root, -7, 0, CUBE_Z + 9.5, 15), palette)
	Kit.pottedPlant(bossFolder, place(root, 8.5, 0, CUBE_Z + 8.5), palette, false)
	Kit.mug(bossFolder, place(root, 2.8, 0, CUBE_Z + 5.5), palette)

	-- Around the cube: a waiting rug (for meetings that could have been
	-- emails), shelving, slogans and the mandatory perimeter of plants.
	Kit.rug(bossFolder, place(root, -17, 0, BOSS_CENTER_Z - 21), palette, 12, 9)
	Kit.beanbag(bossFolder, place(root, -19, 0, BOSS_CENTER_Z - 23), palette)
	Kit.beanbag(bossFolder, place(root, -14.5, 0, BOSS_CENTER_Z - 18.5), palette)
	Kit.pottedPlant(bossFolder, place(root, -24, 0, BOSS_CENTER_Z - 24), palette, false)
	Kit.bookshelf(bossFolder, place(root, 28.1, 0, BOSS_CENTER_Z + 6, 90), palette)
	Kit.pottedPlant(bossFolder, place(root, 28.1, 7.05, BOSS_CENTER_Z + 6), palette, false)

	-- Boss room wall inner faces: z 405..464, x ±29; posters hang 0.13 proud.
	Kit.poster(bossFolder, place(root, 0, 9.5, BOSS_CENTER_Z + 28.87, 0), palette, 10, 7, "DISRUPT OR BE DISRUPTED")
	Kit.trimStrip(bossFolder, place(root, -8.5, 12.5, BOSS_CENTER_Z + 28.94), palette, 6)
	Kit.trimStrip(bossFolder, place(root, 8.5, 12.5, BOSS_CENTER_Z + 28.94), palette, 6)
	Kit.poster(bossFolder, place(root, -28.87, 9, BOSS_CENTER_Z - 5, -90), palette, 8, 6, "MOVE FAST, BREAK QUARTERLY RECORDS")
	Kit.poster(bossFolder, place(root, 28.87, 9, BOSS_CENTER_Z - 11, 90), palette, 8, 6, "THE FUTURE OF WORK IS THIS")

	for _, corner in { Vector2.new(-26.5, -26.5), Vector2.new(26.5, -26.5), Vector2.new(-26.5, 26.5), Vector2.new(26.5, 26.5) } do
		Kit.pottedPlant(bossFolder, place(root, corner.X, 0, BOSS_CENTER_Z + corner.Y), palette, false)
	end

	-- Brett stands mid-cube facing the doors, throne at his back. Def 7 = the
	-- floor boss in Config/Rivals; the client renders him at 2.5× scale.
	table.insert(rivalSpots, { DefIndex = 7, Cf = place(root, 0, 0, CUBE_Z + 4) })

	-- ════════════════════════════ MANIFEST ═════════════════════════════════
	return {
		-- Spawn faces north: elevator, boards, training rows and the shop wall
		-- are all in frame in the first second (10-year-old readability rule).
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
