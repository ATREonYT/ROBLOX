--!strict
-- B1 — THE MAILROOM. The starter floor and the only moody one: an enclosed
-- basement with a low ceiling, exposed pipes and pools of fluorescent light so
-- floor 3 feels like sunrise. All gloom comes from geometry + local lights —
-- Lighting globals stay bright (see MapService) — so the room reads "dingy
-- basement" while every prop stays cartoon-legible.
--
-- Layout follows DESIGN-MAP.md: hub 150x150 centred on origin, SORTING WING
-- corridor (5 x 66-stud segments, 48 wide) out the EAST wall, Gary's boss
-- office (60x60) at the far end. Everything is positioned relative to `origin`
-- via CFrame composition so the floor can be restacked freely.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(script.Parent.Parent.Kit)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Palettes = require(ReplicatedStorage.Shared.Config.Palettes)
local Rivals = require(ReplicatedStorage.Shared.Config.Rivals)
local Format = require(ReplicatedStorage.Shared.Util.Format)

-- Local copy of the CONTRACTS.md manifest shape. Requiring MapService for its
-- export would be circular (MapService requires this module), so the contract
-- is restated here verbatim.
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
local HUB_H = 14 -- LOW ceiling: the basement squeeze is the whole mood
local WING_LEN = 330 -- 5 segments x 66
local WING_W = 48
local WING_H = 13
local WING_START_X = HUB_SIZE / 2 -- corridor slab butts the hub slab at x=75
local BOSS_SIZE = 60
local BOSS_H = 14
local BOSS_CX = WING_START_X + WING_LEN + BOSS_SIZE / 2 -- 435

-- Items placed on a Kit.desk top sit here: the bevel cap tops out at ~1.93,
-- +0.05 clearance keeps prop bottoms safely off the cap face (no z-fighting).
local ON_DESK = 1.98
local ON_STANDING_DESK = 3.08 -- same clearance over the taller tier-2 top
local ON_BOSS_DESK = 3.08

-- Rival body spots are handed over at torso height so the client renderer's
-- pivot lands a blocky suit-guy with feet on the carpet.
local RIVAL_Y = 2.5

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

	-- Single positioning helper: every prop composes off `base`, never off a
	-- world coordinate, so the whole floor moves with Config/Floors origins.
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

	-- ── Shared basement dressing helpers ──────────────────────────────────

	-- Dingy ceiling slab (rooms are built ceiling-less so the warm office
	-- light-panel grid never appears down here — tubes are the only light).
	local function basementCeiling(cx: number, cz: number, w: number, l: number, h: number)
		local slab = Kit.part(parent, place(cx, h + 0.5, cz), Vector3.new(w, 1, l), darken(wallCol, 0.3))
		slab.Name = "BasementCeiling"
	end

	local pipeColor = darken(darkCol, 0.1)
	-- Exposed pipe run: long thin cylinder below the ceiling. Non-colliding /
	-- non-query so overhead decor never eats a click raycast.
	local function pipeRun(x: number, y: number, z: number, yawDeg: number, length: number, dia: number)
		local p = Kit.part(parent, place(x, y, z, yawDeg), Vector3.new(length, dia, dia), pipeColor)
		p.Shape = Enum.PartType.Cylinder
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
	end
	local function pipeSleeve(x: number, y: number, z: number)
		local s = Kit.part(parent, place(x, y, z), Vector3.new(1.15, 1.15, 1.15), darkCol)
		s.CanCollide = false
		s.CanQuery = false
	end
	local function pipeStrap(x: number, y: number, z: number)
		local s = Kit.part(parent, place(x, y, z), Vector3.new(0.18, 0.6, 0.18), darkCol)
		s.CanCollide = false
		s.CanQuery = false
	end

	-- Invisible training-zone volume: ProductivityService does an AABB check
	-- against this part, so it must never collide, query, or render.
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
			local rod = Kit.part(parent, place(x, 12, z, yawDeg) * CFrame.new(dx, 0, 0), Vector3.new(0.15, 4, 0.15), darkCol)
			rod.CanCollide = false
			rod.CanQuery = false
		end
	end

	-- One tier-1 workstation: desk facing the aisle-side `yawDeg`, chair and
	-- monitor arranged so a seated employee would face the screen.
	local function trainingDesk(x: number, z: number, yawDeg: number, clutter: number)
		local deskCf = place(x, 0, z, yawDeg)
		Kit.desk(parent, deskCf, palette)
		Kit.officeChair(parent, deskCf * CFrame.new(0, 0, 2.0), palette)
		-- Monitor spins 180° so the screen faces the chair behind the desk.
		Kit.monitor(parent, deskCf * CFrame.new(0, ON_DESK, 0.15) * CFrame.Angles(0, math.rad(180), 0), palette)
		Kit.keyboardProp(parent, deskCf * CFrame.new(0, ON_DESK, 0.62), palette)
		if clutter == 1 then
			Kit.mug(parent, deskCf * CFrame.new(1.3, ON_DESK, 0.3), palette)
		elseif clutter == 2 then
			Kit.paperStack(parent, deskCf * CFrame.new(-1.2, ON_DESK, 0.1), palette)
		end
	end

	-- Tier-2 standing desk: taller legs, no chair, anti-fatigue mat where the
	-- keen employee stands.
	local function standingDesk(x: number, z: number, yawDeg: number)
		local cf = place(x, 0, z, yawDeg)
		for _, dx in { -1.7, 1.7 } do
			Kit.part(parent, cf * CFrame.new(dx, 1.2, 0), Vector3.new(0.35, 2.4, 1.8), darkCol)
		end
		Kit.bevelBlock(parent, cf * CFrame.new(0, 2.65, 0), Vector3.new(4, 0.5, 2), primaryCol)
		Kit.monitor(parent, cf * CFrame.new(0, ON_STANDING_DESK, 0.15) * CFrame.Angles(0, math.rad(180), 0), palette)
		Kit.keyboardProp(parent, cf * CFrame.new(0, ON_STANDING_DESK, 0.62), palette)
		local mat = Kit.part(parent, cf * CFrame.new(0, 0.06, 1.9), Vector3.new(3.6, 0.12, 2.2), darken(accentCol, 0.25))
		mat.CanCollide = false
		mat.CanQuery = false
		mat.CastShadow = false
	end

	-- Simple wall-side package rack for the sorting wing: two shelves of
	-- undelivered parcels (palette.Primary IS cardboard on this floor).
	local function packageRack(x: number, z: number, yawDeg: number)
		local cf = place(x, 0, z, yawDeg)
		for _, dx in { -3.8, 3.8 } do
			Kit.part(parent, cf * CFrame.new(dx, 3.5, 0), Vector3.new(0.4, 7, 0.4), darkCol)
		end
		for tier, y in { 2.5, 5.0 } do
			Kit.part(parent, cf * CFrame.new(0, y, 0), Vector3.new(8, 0.3, 2), darken(primaryCol, 0.2))
			-- Deterministic offsets: hand-stacked look, identical every boot.
			for i = 1, 2 do
				local dx = (i - 1.5) * 3.4 + tier * 0.4
				Kit.part(parent, cf * CFrame.new(dx, y + 0.95, 0) * CFrame.Angles(0, math.rad(tier * 14 + i * 9), 0), Vector3.new(1.6, 1.6, 1.6), primaryCol)
			end
		end
	end

	-- One sabotaged rival workstation. Returns the CFrame where the rival BODY
	-- stands: behind the desk, LookVector aimed at the corridor aisle.
	local function rivalStation(x: number, z: number, yawDeg: number, clutter: number): CFrame
		local deskCf = place(x, 0, z, yawDeg)
		Kit.desk(parent, deskCf, palette)
		Kit.monitor(parent, deskCf * CFrame.new(0, ON_DESK, 0.15) * CFrame.Angles(0, math.rad(180), 0), palette)
		-- The comedic low-back chair, shoved aside — rivals grind standing up.
		Kit.swivelChair(parent, deskCf * CFrame.new(2.4, 0, 1.7) * CFrame.Angles(0, math.rad(40), 0), palette)
		if clutter == 1 then
			Kit.paperStack(parent, deskCf * CFrame.new(-1.2, ON_DESK, 0.15), palette)
		elseif clutter == 2 then
			Kit.mug(parent, deskCf * CFrame.new(1.25, ON_DESK, 0.35), palette)
		end
		return place(x, RIVAL_Y, z, yawDeg) * CFrame.new(0, 0, 2.0)
	end

	-- ═══════════════════════════════ HUB ═════════════════════════════════

	-- No windows (we're underground), no kit ceiling (its cheerful light
	-- grid would kill the basement mood) — just a doorway to the wing.
	local hubDoors: { Kit.RoomDoor } = { { Wall = "E", Width = 14 } }
	Kit.room(parent, base, HUB_SIZE, HUB_H, HUB_SIZE, palette, { doors = hubDoors })
	basementCeiling(0, 0, HUB_SIZE, HUB_SIZE, HUB_H)

	-- Exposed pipes hugging the ceiling: two east-west runs on the north side,
	-- two north-south crossers, plus chunky joint sleeves.
	pipeRun(0, 13.2, -58, 0, 148, 0.9)
	pipeRun(0, 13.0, -50, 0, 148, 0.7)
	pipeRun(-55, 12.9, 0, 90, 148, 0.8)
	pipeRun(38, 13.35, 0, 90, 148, 0.7)
	pipeSleeve(-55, 12.9, -30)
	pipeSleeve(-55, 12.9, 30)
	pipeSleeve(38, 13.35, -35)
	pipeSleeve(38, 13.35, 35)
	pipeSleeve(-30, 13.2, -58)
	pipeSleeve(30, 13.2, -58)

	-- Lighting: ONE flickering tube over the training area (the joke every new
	-- player spawns under) and a few dim steady tubes — pools of light, not a
	-- lit office.
	Kit.fluorescentTube(parent, place(-48, 12.4, 22), palette, true)
	Kit.fluorescentTube(parent, place(0, 12.5, 6), palette)
	Kit.fluorescentTube(parent, place(58, 12.5, -20, 90), palette)
	Kit.fluorescentTube(parent, place(58, 12.5, 26, 90), palette)
	Kit.fluorescentTube(parent, place(-46, 12.4, -68), palette)
	Kit.fluorescentTube(parent, place(-16, 12.5, 52), palette)

	-- ── Spawn centre ──
	Kit.spawnPad(parent, place(0, 0, 0), palette)
	-- Welcome mat sits south of the pad instead of under it: keeps the pad's
	-- base ring off the rug faces (z-fight-free) and points at the room.
	Kit.rug(parent, place(0, 0, 10), palette, 12, 8)
	local spawnCf = place(0, 3.2, 0, 90) -- face west: training + the flicker gag

	-- The groaning photocopier, first prop a new hire meets.
	Kit.photocopier(parent, place(12, 0, 8, 90), palette)
	local copierSign = Kit.part(parent, place(10.4, 1.05, 8, 90) * CFrame.Angles(math.rad(-14), 0, 0), Vector3.new(2, 1.4, 0.18), lighten(wallCol, 0.4))
	copierSign.CanCollide = false
	copierSign.CanQuery = false
	Kit.textLabelOn(copierSign, Enum.NormalId.Front, "OUT OF TONER SINCE '19", darken(darkCol, 0.3))

	-- Exactly one dying plant, spotlit like an art piece. The SpotLight is the
	-- punchline: the only deliberate lighting on the whole floor.
	Kit.pottedPlant(parent, place(20, 0, -16), palette, true)
	local spotHousing = Kit.part(parent, place(20, 13.7, -16), Vector3.new(1.2, 0.5, 1.2), darkCol)
	spotHousing.CanCollide = false
	spotHousing.CanQuery = false
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Angle = 26
	spot.Range = 18
	spot.Brightness = 4
	spot.Color = lighten(accentCol, 0.5)
	spot.Parent = spotHousing
	local plaquePost = Kit.part(parent, place(20, 0.6, -13.2), Vector3.new(0.15, 1.2, 0.15), darkCol)
	plaquePost.CanCollide = false
	local plaque = Kit.part(parent, place(20, 1.5, -13.2, 90) * CFrame.Angles(math.rad(-10), 0, 0), Vector3.new(1.8, 1.0, 0.12), lighten(wallCol, 0.4))
	plaque.CanCollide = false
	plaque.CanQuery = false
	Kit.textLabelOn(plaque, Enum.NormalId.Front, "WELLNESS INITIATIVE", darken(darkCol, 0.3))

	-- ── Training area (west): 6x tier-1, 2x tier-2, 1x tier-3 ──
	local tierRates = Balance.TrainingTierRates
	local tierRanks = Balance.TrainingTierMinRank
	local function tierLabel(i: number): string
		local text = ("+%dx TRAINING ZONE"):format(tierRates[i])
		if tierRanks[i] > 1 then
			-- Gates are advertised on the sign so under-ranked players know
			-- why the zone ignores them (§5: inform, never mystify).
			text ..= (" · RANK %d+"):format(tierRanks[i])
		end
		return text
	end

	-- Tier 1: two columns of three, all facing the hub centre.
	local t1Index = 0
	for _, dx in { -52, -44 } do
		for _, dz in { 14, 22, 30 } do
			t1Index += 1
			trainingDesk(dx, dz, -90, t1Index % 3)
		end
	end
	table.insert(trainingZones, {
		Rate = tierRates[1],
		MinRank = tierRanks[1],
		Zone = trainingZone("TrainingZoneT1", -48, 22, 16, 24),
	})
	hangingSign(-46, 22, -90, tierLabel(1))

	-- Tier 2: standing desks, rank-gated.
	standingDesk(-50, -18, -90)
	standingDesk(-50, -28, -90)
	table.insert(trainingZones, {
		Rate = tierRates[2],
		MinRank = tierRanks[2],
		Zone = trainingZone("TrainingZoneT2", -49, -23, 12, 18),
	})
	hangingSign(-47, -23, -90, tierLabel(2))

	-- Tier 3: the corner battlestation — an L of two desks, three screens and
	-- one gold glow strip, wedged into the south-west corner.
	local deskACf = place(-68, 0, 52, -90)
	local deskBCf = place(-61, 0, 59, 0)
	Kit.desk(parent, deskACf, palette)
	Kit.desk(parent, deskBCf, palette)
	Kit.monitor(parent, deskACf * CFrame.new(-0.9, ON_DESK, 0.15) * CFrame.Angles(0, math.rad(192), 0), palette)
	Kit.monitor(parent, deskACf * CFrame.new(0.9, ON_DESK, 0.15) * CFrame.Angles(0, math.rad(168), 0), palette)
	Kit.monitor(parent, deskBCf * CFrame.new(0, ON_DESK, 0.15) * CFrame.Angles(0, math.rad(180), 0), palette)
	Kit.keyboardProp(parent, deskACf * CFrame.new(0, ON_DESK, 0.62), palette)
	Kit.mug(parent, deskBCf * CFrame.new(1.2, ON_DESK, 0.4), palette)
	Kit.paperStack(parent, deskBCf * CFrame.new(-1.2, ON_DESK, 0.2), palette)
	Kit.swivelChair(parent, place(-64.5, 0, 55, -60), palette)
	Kit.trimStrip(parent, deskACf * CFrame.new(0, 0.35, -1.08), palette, 3.6)
	table.insert(trainingZones, {
		Rate = tierRates[3],
		MinRank = tierRanks[3],
		Zone = trainingZone("TrainingZoneT3", -64, 55, 16, 14),
	})
	hangingSign(-62, 51, -90, tierLabel(3))

	-- ── East stations: shop, coffee gacha, HR, snacks ──
	local shopKioskModel = Kit.shopKiosk(parent, place(68, 0, -30, 90), palette)
	local coffeeModel = Kit.coffeeMachineBig(parent, place(67, 0, -14, 90), palette)
	local hrModel = Kit.hrDesk(parent, place(66, 0, 16, 90), palette)
	Kit.vendingMachine(parent, place(70, 0, 30, 90), palette)
	Kit.waterCooler(parent, place(70, 0, 40, 90), palette)
	Kit.waterCooler(parent, place(-32, 0, -44, 135), palette)

	-- ── North wall: elevator bank, boards, letter conveyor ──
	Kit.elevatorDoors(parent, place(0, 0, -73, 180), palette)
	-- The glowing call panel is the Prompt part — a 1x2 target at hand height.
	local panelModel = Kit.elevatorPanel(parent, place(7.5, 5, -73.75, 180), palette)
	Kit.trimStrip(parent, place(0, 10.6, -73.8), palette, 12)
	Kit.neonSign(parent, place(0, 12.3, -73.5, 180), palette, "THE MAILROOM")
	local eotmModel, _eotmContent = Kit.boardFrame(parent, place(-17, 6, -73.7, 180), palette, "EMPLOYEE OF THE MONTH")
	local winsModel, _winsContent = Kit.boardFrame(parent, place(17, 6, -73.7, 180), palette, "ALL-TIME WINS")

	-- Letter conveyor rumbling along the north wall (belt runs along local Z,
	-- so yaw 90 lays it east-west).
	Kit.conveyor(parent, place(-47, 0, -69, 90), palette, 42)
	Kit.cardboardStack(parent, place(-20, 0, -69), palette, 3) -- overflow pile at the belt's end
	Kit.mailCart(parent, place(-28, 0, -63, 25), palette)

	-- ── Motivational poster parodies ──
	Kit.poster(parent, place(-73.85, 7.5, 10, -90), palette, 12, 8, "THE MAIL MUST FLOW")
	Kit.poster(parent, place(-12, 7, 73.85, 0), palette, 10, 7, "YOU ARE REPLACEABLE :)")
	Kit.poster(parent, place(30, 6.5, 73.85, 0), palette, 8, 6, "LOST MAIL IS JUST EARLY RECYCLING")
	Kit.poster(parent, place(-52, 6, -73.85, 180), palette, 7, 5, "SORT WITH PURPOSE")
	Kit.poster(parent, place(73.85, 6.5, 36, 90), palette, 7, 5, "BREAKS ARE EARNED")

	-- ── Structure + clutter: pillars, cabinets, carts, cardboard everywhere ──
	for _, corner in { Vector2.new(-28, -28), Vector2.new(28, -28), Vector2.new(-28, 28), Vector2.new(28, 28) } do
		Kit.pillar(parent, place(corner.X, 0, corner.Y), palette, HUB_H)
	end
	Kit.filingCabinet(parent, place(69, 0, -46, 90), palette)
	Kit.filingCabinet(parent, place(69, 0, -43.5, 90), palette)
	Kit.filingCabinet(parent, place(-70, 0, 8, -90), palette)
	Kit.mailCart(parent, place(14, 0, 34, 40), palette)
	Kit.mailCart(parent, place(-18, 0, -38, -70), palette)
	Kit.mailCart(parent, place(48, 0, 26, -30), palette)

	-- Sorting table pair south of spawn: keeps the hub's south half busy and
	-- sells "mailroom" before the wing does.
	for _, sx in { 6, 13 } do
		local sortCf = place(sx, 0, 52, 0)
		Kit.desk(parent, sortCf, palette)
		Kit.paperStack(parent, sortCf * CFrame.new(0.8, ON_DESK, 0.2), palette)
	end
	Kit.mailCart(parent, place(9.5, 0, 46, 70), palette)

	-- Cardboard stack clusters, everywhere the spec promises. Deterministic
	-- list (not RNG) so every server builds the identical basement.
	local hubStacks: { { number } } = {
		{ -70, -60, 3 }, { -70, -44, 2 }, { -25, -34, 2 }, { 30, -34, 3 },
		{ 34, -68, 3 }, { 52, -66, 2 }, { 70, 52, 3 }, { 58, 64, 4 },
		{ 40, 66, 2 }, { 12, 66, 3 }, { -8, 68, 4 }, { -28, 64, 2 },
		{ -48, 68, 3 }, { -70, 20, 2 }, { 22, 18, 2 }, { -16, 40, 3 },
		{ 46, -12, 2 }, { 40, 34, 3 }, { 2, 58, 2 }, { 18, 58, 3 },
	}
	for i, stack in hubStacks do
		Kit.cardboardStack(parent, place(stack[1], 0, stack[2], i * 23 % 360), palette, stack[3])
	end

	-- ═══════════════════════════ SORTING WING ════════════════════════════

	local wingDoors: { Kit.RoomDoor } = { { Wall = "W", Width = 14 }, { Wall = "E", Width = 14 } }
	Kit.room(parent, base * CFrame.new(WING_START_X + WING_LEN / 2, 0, 0), WING_LEN, WING_H, WING_W, palette, { doors = wingDoors })
	basementCeiling(WING_START_X + WING_LEN / 2, 0, WING_LEN, WING_W, WING_H)

	-- Two pipes chase the whole corridor — the wing reads as one long duct.
	pipeRun(WING_START_X + WING_LEN / 2, 12.5, -17, 0, WING_LEN - 2, 0.8)
	pipeRun(WING_START_X + WING_LEN / 2, 12.7, 15, 0, WING_LEN - 2, 0.7)
	for _, sx in { 110, 176, 242, 308, 374 } do
		pipeStrap(sx, 12.75, -17)
		pipeStrap(sx, 12.95, 15)
	end

	local segCentres: { number } = { 108, 174, 240, 306, 372 }

	-- Dim + one flicker tube per segment: enough light to click by, enough
	-- flicker to stay a basement.
	for _, cx in segCentres do
		Kit.fluorescentTube(parent, place(cx - 16, 11.9, -6), palette)
		Kit.fluorescentTube(parent, place(cx + 12, 11.9, 5), palette, true)
	end

	-- Rival packs: DefIndex placement per the floor spec (seg1 def1 x3 ...
	-- seg5 def6 x2). North-side desks face south (+Z) and vice versa, so every
	-- rival's LookVector crosses the central walkway.
	local stations: { { x: number, north: boolean, def: number } } = {
		{ x = 98, north = true, def = 1 }, { x = 110, north = false, def = 1 }, { x = 122, north = true, def = 1 },
		{ x = 162, north = false, def = 2 }, { x = 175, north = true, def = 2 }, { x = 188, north = false, def = 2 },
		{ x = 228, north = true, def = 3 }, { x = 241, north = false, def = 3 }, { x = 254, north = true, def = 4 },
		{ x = 294, north = false, def = 4 }, { x = 308, north = true, def = 5 }, { x = 321, north = false, def = 5 },
		{ x = 362, north = true, def = 6 }, { x = 381, north = false, def = 6 },
	}
	for i, st in stations do
		local z = if st.north then -12 else 12
		local yawDeg = if st.north then 180 else 0
		local bodyCf = rivalStation(st.x, z, yawDeg, i % 3)
		table.insert(rivalSpots, { DefIndex = st.def, Cf = bodyCf })
	end

	-- Gates + payday pads between segments. The gate label advertises the NEXT
	-- pack (dominant def of the following segment; the boss after seg 5) so
	-- under-powered players self-select back to training — never a hard block.
	local mailroomDefs = Rivals.ByFloor.Mailroom
	local gateXs: { number } = { 141, 207, 273, 339, 398 }
	local gateNextDef: { number } = { 2, 3, 5, 6, 7 }
	local gateCartYaw: { number } = { -35, 20, -15, 40, 10 }
	for k = 1, 5 do
		local gx = gateXs[k]
		local nextDef = mailroomDefs[gateNextDef[k]]
		local label = ("NEXT: %s — %s WORKLOAD"):format(nextDef.Title, Format.abbreviate(nextDef.Workload))
		-- Arch spans across the corridor (yaw 90 lays its width along Z).
		Kit.gateArch(parent, place(gx, 0, 0, 90), palette, label)
		-- Pad sits SOUTH of the arch, off the walkway: stepping on it is a
		-- choice, walking past it costs nothing.
		local pad: BasePart = Kit.paydayPad(parent, place(gx, 0, 14), palette)
		table.insert(paydayPads, { Segment = k, Pad = pad })
		-- Divider clutter so each gate reads as a checkpoint, not a hoop.
		Kit.cardboardStack(parent, place(gx - 1, 0, -19, k * 31 % 360), palette, 3)
		Kit.cardboardStack(parent, place(gx + 3, 0, 20, k * 47 % 360), palette, 2)
		Kit.mailCart(parent, place(gx + 4, 0, -13, gateCartYaw[k]), palette)
	end

	-- Per-segment wall dressing: package racks, cabinets, stacks, posters.
	-- Rack spots alternate walls and dodge the cabinets/gate clutter below.
	for _, rackSpot in { Vector2.new(112, 21), Vector2.new(170, -21), Vector2.new(250, 21), Vector2.new(344, -21) } do
		packageRack(rackSpot.X, rackSpot.Y, if rackSpot.Y > 0 then 0 else 180)
	end
	local wingPosters: { string } = {
		"SORT. SEAL. REPEAT.",
		"THE MAIL MUST FLOW",
		"OVERTIME IS A MINDSET",
		"GARY SEES ALL",
		"ALMOST THERE. PROBABLY.",
	}
	for k, cx in segCentres do
		Kit.filingCabinet(parent, place(cx + 18, 0, -21, 180), palette)
		Kit.cardboardStack(parent, place(cx - 24, 0, -20, k * 53 % 360), palette, 3)
		Kit.cardboardStack(parent, place(cx + 26, 0, 20, k * 71 % 360), palette, 2)
		if k % 2 == 1 then
			Kit.poster(parent, place(cx + 6, 6.5, -22.85, 180), palette, 7, 5, wingPosters[k])
		else
			Kit.poster(parent, place(cx + 6, 6.5, 22.85, 0), palette, 7, 5, wingPosters[k])
		end
	end

	-- ═══════════════════════════ BOSS OFFICE ═════════════════════════════

	local bossDoors: { Kit.RoomDoor } = { { Wall = "W", Width = 14 } }
	Kit.room(parent, base * CFrame.new(BOSS_CX, 0, 0), BOSS_SIZE, BOSS_H, BOSS_SIZE, palette, { doors = bossDoors })
	basementCeiling(BOSS_CX, 0, BOSS_SIZE, BOSS_SIZE, BOSS_H)
	pipeRun(BOSS_CX + 5, 12.8, 0, 90, 58, 0.8)
	pipeStrap(BOSS_CX + 5, 13.15, -12)
	pipeStrap(BOSS_CX + 5, 13.15, 12)
	Kit.fluorescentTube(parent, place(BOSS_CX - 7, 12.2, -8), palette)
	Kit.fluorescentTube(parent, place(BOSS_CX + 13, 12.2, 8), palette)

	-- Gary's den: bossDesk facing the door, ringed by a cardboard-box fort
	-- with its opening toward the entrance — intimidating AND inviting.
	local bossDeskCf = place(446, 0, 0, 90)
	Kit.bossDesk(parent, bossDeskCf, palette)
	Kit.swivelChair(parent, place(452, 0, 3, 90), palette)
	Kit.rug(parent, place(438, 0, 0), palette, 16, 20)
	Kit.neonSign(parent, place(446, 10.8, -1, 90), palette, "GARY'S DEN")
	table.insert(rivalSpots, { DefIndex = 7, Cf = place(450.5, RIVAL_Y, 0, 90) })

	local fortStacks: { { number } } = {
		{ 439, -8, 4 }, { 439, 8, 4 }, -- gate towers, gap facing the door
		{ 442, -12, 3 }, { 442, 12, 3 },
		{ 447, -13, 4 }, { 447, 13, 3 },
		{ 452, -11, 4 }, { 452, 11, 4 },
		{ 456, -6, 3 }, { 456, 6, 3 }, { 456, 0, 2 }, -- low rear wall keeps Gary visible
	}
	for i, stack in fortStacks do
		Kit.cardboardStack(parent, place(stack[1], 0, stack[2], i * 37 % 360), palette, stack[3])
	end

	-- Desk paperwork + scattered backlog: the boss is buried in it.
	Kit.paperStack(parent, bossDeskCf * CFrame.new(-2.5, ON_BOSS_DESK, 0.4), palette)
	Kit.paperStack(parent, bossDeskCf * CFrame.new(2.2, ON_BOSS_DESK, -0.3), palette)
	Kit.mug(parent, bossDeskCf * CFrame.new(0.8, ON_BOSS_DESK, 1.2), palette)
	Kit.paperStack(parent, place(438, 0, -7), palette)
	Kit.paperStack(parent, place(437, 0, 6), palette)
	Kit.mailCart(parent, place(440, 0, -18, -55), palette)
	Kit.filingCabinet(parent, place(462, 0, -26, 90), palette)
	Kit.filingCabinet(parent, place(462, 0, -23.5, 90), palette)
	Kit.cardboardStack(parent, place(412, 0, -20, 40), palette, 2)
	Kit.cardboardStack(parent, place(416, 0, 24, 130), palette, 3)
	Kit.cardboardStack(parent, place(430, 0, -25, 220), palette, 3)
	Kit.cardboardStack(parent, place(426, 0, 26, 310), palette, 2)

	Kit.poster(parent, place(446, 7.5, -28.85, 180), palette, 9, 6, "THE MAIL STOPS FOR NO ONE.")
	Kit.poster(parent, place(463.85, 7, 6, 90), palette, 8, 6, "EMPLOYEE OF THE MONTH: GARY. AGAIN.")

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
