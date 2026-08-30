--!strict
-- ??? — ORBITAL HQ. No walls, no ceiling: a chrome deck floating in space with
-- Earth turning underneath, visible through glass floor panels in the middle
-- of the hub. The ORBITAL WING is a chain of platforms joined by light bridges.
--
-- Layout follows DESIGN-MAP.md: hub 150x150 centred on origin, wing running
-- EAST (5 x 66-stud segments), boss ring (60x60) at the far end. Everything
-- composes off `origin` — no world coordinates.
--
-- SAFETY: this is the only floor with open edges, so every walkable surface is
-- fenced with invisible collision walls. FloorService has a fall-catch, but a
-- player should never reach it — falling off the endgame floor would feel like
-- a bug, not a thrill.

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
local WING_LEN = 330
local WING_W = 44
local WING_START_X = HUB_SIZE / 2
local BOSS_SIZE = 60
local BOSS_CX = WING_START_X + WING_LEN + BOSS_SIZE / 2 -- 435

local DECK_THICK = 2 -- every platform is one 2-stud chrome slab
local RAIL_H = 14 -- invisible safety wall height
local RIVAL_Y = 2.5
local ON_DESK = 1.98

-- Earth hangs far below the deck; the dome of stars wraps everything.
local EARTH_Y = -320
local EARTH_R = 210
local STAR_R = 430

local function build(parent: Folder, origin: Vector3, palette: Palettes.Palette): Manifest
	local base = CFrame.new(origin)

	local groundCol = Palettes.color(palette.Ground) -- deck panels
	local chromeCol = Palettes.color(palette.Wall) -- chrome
	local accentCol = Palettes.color(palette.Accent) -- cyan neon
	local primaryCol = Palettes.color(palette.Primary)
	local voidCol = Palettes.color(palette.Dark) -- deep space

	local function lighten(c: Color3, amount: number): Color3
		return c:Lerp(Color3.new(1, 1, 1), amount)
	end
	local function darken(c: Color3, amount: number): Color3
		return c:Lerp(Color3.new(0, 0, 0), amount)
	end

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

	local function decor(cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?): BasePart
		local part = Kit.part(parent, cf, size, color, material)
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
		return part
	end

	-- ── Structural helpers ────────────────────────────────────────────────

	-- One chrome deck slab with a glowing cyan edge band. Returns the slab so
	-- callers can name it; the trim is purely decorative.
	local function deck(cx: number, cz: number, sx: number, sz: number, name: string): BasePart
		local slab = Kit.part(parent, place(cx, -DECK_THICK / 2, cz), Vector3.new(sx, DECK_THICK, sz), groundCol)
		slab.Name = name
		-- Panel seams: thin darker lines inlaid across the deck.
		local seams = math.max(1, math.floor(sx / 18))
		for i = 1, seams do
			local px = cx - sx / 2 + i * (sx / (seams + 1))
			decor(place(px, 0.04, cz), Vector3.new(0.4, 0.08, sz - 1), darken(groundCol, 0.35))
		end
		-- Cyan edge trim on all four sides, standing just proud of the slab.
		for _, edge in
			{
				{ cx, cz - sz / 2 - 0.35, 0, sx + 1.4 },
				{ cx, cz + sz / 2 + 0.35, 0, sx + 1.4 },
				{ cx - sx / 2 - 0.35, cz, 90, sz + 1.4 },
				{ cx + sx / 2 + 0.35, cz, 90, sz + 1.4 },
			}
		do
			decor(place(edge[1], -0.25, edge[2], edge[3]), Vector3.new(edge[4], 0.55, 0.7), accentCol, Enum.Material.Neon)
		end
		return slab
	end

	-- Invisible fence. This is what actually stops a fall; the glowing posts
	-- next to it are only there so the player can SEE where the edge is.
	local function safetyRail(cx: number, cz: number, sx: number, sz: number, yawDeg: number?)
		local wall = Kit.part(parent, place(cx, RAIL_H / 2, cz, yawDeg), Vector3.new(sx, RAIL_H, sz), accentCol)
		wall.Name = "SafetyRail"
		wall.Transparency = 1
		wall.CanCollide = true
		wall.CanQuery = false
		wall.CastShadow = false
	end

	-- Fence a rectangular platform on the sides named in `open` = false.
	local function fencePlatform(cx: number, cz: number, sx: number, sz: number, skip: { [string]: boolean }?)
		local s: { [string]: boolean } = skip or {}
		if not s.N then
			safetyRail(cx, cz - sz / 2 - 0.5, sx + 2, 1)
		end
		if not s.S then
			safetyRail(cx, cz + sz / 2 + 0.5, sx + 2, 1)
		end
		if not s.W then
			safetyRail(cx - sx / 2 - 0.5, cz, 1, sz + 2)
		end
		if not s.E then
			safetyRail(cx + sx / 2 + 0.5, cz, 1, sz + 2)
		end
	end

	-- Glowing edge posts: the visible half of the safety story.
	local function edgePosts(cx: number, cz: number, sx: number, sz: number, spacing: number)
		local countX = math.max(2, math.floor(sx / spacing))
		for i = 0, countX do
			local px = cx - sx / 2 + i * (sx / countX)
			for _, pz in { cz - sz / 2, cz + sz / 2 } do
				decor(place(px, 1.6, pz), Vector3.new(0.35, 3.2, 0.35), accentCol, Enum.Material.Neon)
			end
		end
		local countZ = math.max(2, math.floor(sz / spacing))
		for i = 1, countZ - 1 do
			local pz = cz - sz / 2 + i * (sz / countZ)
			for _, px in { cx - sx / 2, cx + sx / 2 } do
				decor(place(px, 1.6, pz), Vector3.new(0.35, 3.2, 0.35), accentCol, Enum.Material.Neon)
			end
		end
	end

	-- A light bridge: walkable Neon slab, railed on both sides.
	local function lightBridge(cx: number, cz: number, sx: number, sz: number)
		local bridge = Kit.part(parent, place(cx, -DECK_THICK / 2, cz), Vector3.new(sx, DECK_THICK, sz), accentCol, Enum.Material.Neon)
		bridge.Name = "LightBridge"
		bridge.Transparency = 0.15
		decor(place(cx, 0.15, cz), Vector3.new(sx - 1, 0.1, sz - 1.5), lighten(accentCol, 0.4), Enum.Material.Neon)
		safetyRail(cx, cz - sz / 2 - 0.5, sx, 1)
		safetyRail(cx, cz + sz / 2 + 0.5, sx, 1)
		for i = 0, math.floor(sx / 8) do
			local px = cx - sx / 2 + i * 8
			for _, pz in { cz - sz / 2, cz + sz / 2 } do
				decor(place(px, 1.4, pz), Vector3.new(0.3, 2.8, 0.3), lighten(accentCol, 0.3), Enum.Material.Neon)
			end
		end
	end

	-- Invisible training-zone volume (ProductivityService AABB-checks it).
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

	-- Floating tier sign on a chrome post (there is no ceiling to hang from).
	local function tierSign(x: number, z: number, yawDeg: number, text: string)
		decor(place(x, 3.5, z, yawDeg), Vector3.new(0.4, 7, 0.4), chromeCol)
		local board = decor(place(x, 8, z, yawDeg), Vector3.new(9, 2, 0.35), darken(primaryCol, 0.2))
		Kit.textLabelOn(board, Enum.NormalId.Front, text, lighten(accentCol, 0.35))
		Kit.textLabelOn(board, Enum.NormalId.Back, text, lighten(accentCol, 0.35))
		decor(place(x, 6.9, z, yawDeg), Vector3.new(9.4, 0.25, 0.5), accentCol, Enum.Material.Neon)
	end

	-- A zero-g workstation: the desk floats on a beam of light instead of legs.
	local function zeroGDesk(x: number, z: number, yawDeg: number, screens: number)
		local cf = place(x, 0, z, yawDeg)
		-- The light column IS the leg: no contact point, but visually grounded.
		decor(cf * CFrame.new(0, 0.9, 0), Vector3.new(2.6, 1.8, 1.6), accentCol, Enum.Material.Neon)
		Kit.bevelBlock(parent, cf * CFrame.new(0, 2.1, 0), Vector3.new(4.4, 0.45, 2.2), chromeCol)
		if screens >= 1 then
			Kit.monitor(parent, cf * CFrame.new(0, ON_DESK + 0.5, 0.15) * CFrame.Angles(0, math.rad(180), 0), palette)
		end
		if screens >= 2 then
			Kit.monitor(parent, cf * CFrame.new(-1.7, ON_DESK + 0.5, 0.3) * CFrame.Angles(0, math.rad(196), 0), palette)
		end
		if screens >= 3 then
			Kit.monitor(parent, cf * CFrame.new(1.7, ON_DESK + 0.5, 0.3) * CFrame.Angles(0, math.rad(164), 0), palette)
		end
		Kit.keyboardProp(parent, cf * CFrame.new(0, ON_DESK + 0.5, 0.62), palette)
		Kit.officeChair(parent, cf * CFrame.new(0, 0, 2.2), palette, darken(primaryCol, 0.2))
	end

	-- Holo-display: a screen floating on a thin chrome post.
	local function holoDisplay(x: number, z: number, yawDeg: number)
		decor(place(x, 2.2, z, yawDeg), Vector3.new(0.3, 4.4, 0.3), chromeCol)
		Kit.monitor(parent, place(x, 5.2, z, yawDeg), palette)
		decor(place(x, 0.2, z, yawDeg), Vector3.new(1.8, 0.4, 1.8), accentCol, Enum.Material.Neon)
	end

	-- ═══════════════════════════ SPACE ════════════════════════════════════

	-- Starfield: cubes scattered over a sphere shell around the whole floor.
	-- Deterministic placement (no RNG) so every server builds the same sky.
	local starCount = 220
	local golden = math.pi * (3 - math.sqrt(5)) -- golden-angle spiral
	for i = 1, starCount do
		local t = (i - 0.5) / starCount
		local inclination = math.acos(1 - 2 * t)
		local azimuth = golden * i
		local sx = math.sin(inclination) * math.cos(azimuth)
		local sy = math.cos(inclination)
		local sz = math.sin(inclination) * math.sin(azimuth)
		-- Keep the sky above and around, never underfoot where Earth sits.
		local size = 1.6 + (i % 5) * 0.7
		local star = decor(
			place(WING_LEN / 4 + sx * STAR_R, sy * STAR_R * 0.75 + 60, sz * STAR_R),
			Vector3.new(size, size, size),
			if i % 7 == 0 then lighten(accentCol, 0.4) else Color3.new(1, 1, 1),
			Enum.Material.Neon
		)
		star.Name = "Star"
	end

	-- Earth: a layered sphere far below the deck, with an atmosphere halo.
	local earth = Kit.part(
		parent,
		place(0, EARTH_Y, 0),
		Vector3.new(EARTH_R * 2, EARTH_R * 2, EARTH_R * 2),
		Color3.fromRGB(38, 96, 168)
	) :: Part
	earth.Name = "Earth"
	earth.Shape = Enum.PartType.Ball
	earth.CanCollide = false
	earth.CanQuery = false
	earth.CastShadow = false
	-- Continents: green caps tucked against the ocean sphere's surface.
	local landmasses: { { number } } = {
		{ 0.55, 0.35, 0.2, 70 },
		{ -0.4, 0.5, 0.3, 55 },
		{ 0.1, -0.45, 0.6, 62 },
		{ -0.6, -0.2, -0.4, 48 },
		{ 0.3, 0.15, -0.7, 58 },
	}
	for _, land in landmasses do
		local dir = Vector3.new(land[1], land[2], land[3]).Unit
		local blob = decor(
			place(dir.X * EARTH_R * 0.94, EARTH_Y + dir.Y * EARTH_R * 0.94, dir.Z * EARTH_R * 0.94),
			Vector3.new(land[4], land[4], land[4]),
			Color3.fromRGB(74, 148, 84)
		) :: Part
		blob.Shape = Enum.PartType.Ball
	end
	local atmosphere = decor(
		place(0, EARTH_Y, 0),
		Vector3.new(EARTH_R * 2.12, EARTH_R * 2.12, EARTH_R * 2.12),
		Color3.fromRGB(120, 205, 255),
		Enum.Material.Neon
	) :: Part
	atmosphere.Shape = Enum.PartType.Ball
	atmosphere.Transparency = 0.82

	-- ═══════════════════════════ HUB DECK ═════════════════════════════════

	deck(0, 0, HUB_SIZE, HUB_SIZE, "HubDeck")
	-- Open only to the east, where the wing bridge leaves.
	fencePlatform(0, 0, HUB_SIZE, HUB_SIZE, { E = true })
	-- The east side is fenced except for the bridge mouth.
	safetyRail(HUB_SIZE / 2 + 0.5, -46, 1, 58)
	safetyRail(HUB_SIZE / 2 + 0.5, 46, 1, 58)
	edgePosts(0, 0, HUB_SIZE, HUB_SIZE, 12)

	-- Glass floor panels in the middle of the hub: Earth, straight down.
	-- Laid flat and non-collidable, sitting inside a cut-out ring of trim.
	for _, panel in { { -12, -12 }, { 12, -12 }, { -12, 12 }, { 12, 12 } } do
		local glass = Kit.part(
			parent,
			place(panel[1], 0.06, panel[2]),
			Vector3.new(22, 0.3, 22),
			Color3.fromRGB(150, 215, 255),
			Enum.Material.Glass
		)
		glass.Transparency = 0.85
		glass.CanCollide = false -- you stand on the deck slab underneath
		glass.CanQuery = false
		glass.CastShadow = false
	end
	-- Cut the deck away under the glass so Earth is actually visible: four
	-- viewing wells punched through the slab, ringed in cyan.
	for _, panel in { { -12, -12 }, { 12, -12 }, { -12, 12 }, { 12, 12 } } do
		for _, edge in
			{
				{ panel[1], panel[2] - 11.4, 0, 23 },
				{ panel[1], panel[2] + 11.4, 0, 23 },
				{ panel[1] - 11.4, panel[2], 90, 23 },
				{ panel[1] + 11.4, panel[2], 90, 23 },
			}
		do
			decor(place(edge[1], 0.2, edge[2], edge[3]), Vector3.new(edge[4], 0.4, 0.8), accentCol, Enum.Material.Neon)
		end
	end

	-- ── Spawn ─────────────────────────────────────────────────────────────

	Kit.spawnPad(parent, place(0, 0, -34), palette)
	-- Face south across the glass wells: the first thing you see is Earth.
	local spawnCf = place(0, 3.2, -34, 180)
	decor(place(0, 0.08, -34), Vector3.new(26, 0.1, 20), lighten(accentCol, 0.15), Enum.Material.Neon)

	-- ── Elevator + boards (north edge) ────────────────────────────────────

	-- The elevator arrives inside a chrome arch — there is no wall to mount on.
	for _, dx in { -7, 7 } do
		Kit.pillar(parent, place(dx, 0, -66), palette, 20)
	end
	decor(place(0, 20.5, -66), Vector3.new(18, 1.2, 3), chromeCol)
	Kit.elevatorDoors(parent, place(0, 0, -66, 180), palette)
	local panelModel = Kit.elevatorPanel(parent, place(7.5, 5, -66.8, 180), palette)
	Kit.neonSign(parent, place(0, 23, -66, 180), palette, "ORBITAL HQ", accentCol)

	local eotmModel, _eotmContent = Kit.boardFrame(parent, place(-30, 6, -66, 180), palette, "EMPLOYEE OF THE MONTH")
	local winsModel, _winsContent = Kit.boardFrame(parent, place(30, 6, -66, 180), palette, "ALL-TIME WINS")
	-- Boards float on chrome legs, since nothing here is wall-mounted.
	for _, bx in { -30, 30 } do
		for _, dx in { -4, 4 } do
			decor(place(bx + dx, 1.5, -66), Vector3.new(0.4, 3, 0.4), chromeCol)
		end
	end

	-- A scrolling ticker board: the client fills it with market headlines.
	local ticker = Kit.part(parent, place(0, 12, -60, 180), Vector3.new(52, 3.4, 0.6), darken(voidCol, 0.2))
	ticker.Name = "TickerBoard"
	ticker.CanCollide = false
	ticker.CanQuery = false
	ticker.CastShadow = false
	CollectionService:AddTag(ticker, "TickerSign")
	decor(place(0, 10.1, -60), Vector3.new(52, 0.4, 0.8), accentCol, Enum.Material.Neon)
	for _, dx in { -24, 24 } do
		decor(place(dx, 5.5, -60), Vector3.new(0.5, 11, 0.5), chromeCol)
	end

	-- ── Hub fixtures (east side, flanking the wing mouth) ─────────────────

	local shopKioskModel = Kit.shopKiosk(parent, place(56, 0, -34, 90), palette)
	Kit.neonSign(parent, place(54, 7.5, -34, 90), palette, "GEAR", accentCol)
	local coffeeModel = Kit.coffeeMachineBig(parent, place(56, 0, -16, 90), palette)
	Kit.neonSign(parent, place(54, 9.5, -16, 90), palette, "INTERNS", accentCol)
	local hrModel = Kit.hrDesk(parent, place(56, 0, 22, 90), palette)
	Kit.neonSign(parent, place(54, 6.5, 22, 90), palette, "RESTRUCTURING", accentCol)
	Kit.officeChair(parent, place(50, 0, 22, -90), palette, darken(primaryCol, 0.2))

	-- Holo-displays scattered around the hub, all quietly glowing.
	for _, spot in { { -44, -20, 90 }, { -44, 8, 90 }, { 34, 40, 180 }, { -20, 52, 0 }, { 20, 52, 0 } } do
		holoDisplay(spot[1], spot[2], spot[3])
	end
	for _, spot in { { -60, -60 }, { 60, -60 }, { -60, 60 }, { 60, 60 } } do
		Kit.pillar(parent, place(spot[1], 0, spot[2]), palette, 18)
		decor(place(spot[1], 18.4, spot[2]), Vector3.new(3.6, 0.6, 3.6), accentCol, Enum.Material.Neon)
	end

	-- ── Training platforms: three satellites off the west side ────────────

	local rates = Balance.TrainingTierRates
	local gates = Balance.TrainingTierMinRank
	local satellites: { { z: number, tier: number, screens: number } } = {
		{ z = -40, tier = 1, screens = 1 },
		{ z = 0, tier = 2, screens = 2 },
		{ z = 40, tier = 3, screens = 3 },
	}
	for _, sat in satellites do
		local cx = -108
		deck(cx, sat.z, 42, 32, "TrainDeck" .. tostring(sat.tier))
		fencePlatform(cx, sat.z, 42, 32, { E = true })
		safetyRail(cx + 21.5, sat.z - 11, 1, 12)
		safetyRail(cx + 21.5, sat.z + 11, 1, 12)
		edgePosts(cx, sat.z, 42, 32, 10)
		-- Bridge from the hub's west edge out to the satellite.
		lightBridge(-87.5, sat.z, 21, 10)
		-- Three desks per platform, all facing the hub.
		for i, dz in { -9, 0, 9 } do
			zeroGDesk(cx + (if i == 2 then 4 else 0), sat.z + dz, -90, sat.screens)
		end
		table.insert(trainingZones, {
			Rate = rates[sat.tier],
			MinRank = gates[sat.tier],
			Zone = trainingZone("TrainZoneT" .. tostring(sat.tier), cx, sat.z, 44, 34),
		})
		local label = if sat.tier == 1
			then ("+%dx TRAINING"):format(rates[sat.tier])
			else ("+%dx TRAINING · RANK %d+"):format(rates[sat.tier], gates[sat.tier])
		tierSign(cx, sat.z - 18, 0, label)
		holoDisplay(cx - 17, sat.z, 90)
	end

	Kit.neonSign(parent, place(72, 14, 0, 90), palette, "ORBITAL WING", accentCol)

	-- ═══════════════════════════ ORBITAL WING ═════════════════════════════
	-- Five platforms strung along a chain of light bridges over the void.

	local segCentres: { number } = { 108, 174, 240, 306, 372 }
	local segLen = 54 -- platform length; the gaps between are bridges
	for i, cx in segCentres do
		deck(cx, 0, segLen, WING_W, "WingDeck" .. tostring(i))
		fencePlatform(cx, 0, segLen, WING_W, { W = true, E = true })
		-- Fence the open ends except for the bridge mouth in the middle.
		for _, side in { -1, 1 } do
			local ex = cx + side * (segLen / 2 + 0.5)
			safetyRail(ex, -16, 1, 12)
			safetyRail(ex, 16, 1, 12)
		end
		edgePosts(cx, 0, segLen, WING_W, 11)
		-- Chrome arch over each platform so the corridor still reads as a room.
		for _, dz in { -20, 20 } do
			Kit.pillar(parent, place(cx - 18, 0, dz), palette, 16)
			Kit.pillar(parent, place(cx + 18, 0, dz), palette, 16)
		end
		decor(place(cx, 16.4, -20), Vector3.new(38, 0.8, 1.2), chromeCol)
		decor(place(cx, 16.4, 20), Vector3.new(38, 0.8, 1.2), chromeCol)
	end

	-- Bridges: hub → seg1, then between every pair of platforms.
	lightBridge(88, 0, 28, 16)
	for i = 1, #segCentres - 1 do
		local gapCentre = (segCentres[i] + segCentres[i + 1]) / 2
		lightBridge(gapCentre, 0, 12, 16)
	end
	-- Final bridge into the boss ring.
	lightBridge(BOSS_CX - 33, 0, 24, 16)

	-- Rival packs per the floor spec: seg1 def1 x3 · seg2 def2 x3 ·
	-- seg3 def3 x2 + def4 · seg4 def4 + def5 x2 · seg5 def6 x2.
	local function wingStation(x: number, north: boolean, def: number)
		local z = if north then -13 else 13
		local yawDeg = if north then 180 else 0
		zeroGDesk(x, z, yawDeg, if def >= 5 then 3 else 2)
		-- Body stands behind the desk, facing across the aisle.
		table.insert(rivalSpots, { DefIndex = def, Cf = place(x, RIVAL_Y, if north then z - 3 else z + 3, yawDeg) })
	end

	local stations: { { x: number, north: boolean, def: number } } = {
		{ x = 94, north = true, def = 1 },
		{ x = 108, north = false, def = 1 },
		{ x = 122, north = true, def = 1 },
		{ x = 160, north = false, def = 2 },
		{ x = 174, north = true, def = 2 },
		{ x = 188, north = false, def = 2 },
		{ x = 228, north = true, def = 3 },
		{ x = 242, north = false, def = 3 },
		{ x = 256, north = true, def = 4 },
		{ x = 292, north = false, def = 4 },
		{ x = 306, north = true, def = 5 },
		{ x = 320, north = false, def = 5 },
		{ x = 360, north = true, def = 6 },
		{ x = 384, north = false, def = 6 },
	}
	for _, st in stations do
		wingStation(st.x, st.north, st.def)
	end

	-- Gates + payday pads. Gates straddle the bridges between platforms, so
	-- crossing one is a visible commitment.
	local orbitalDefs = Rivals.ByFloor.OrbitalHQ
	local gateXs: { number } = { 141, 207, 273, 339, 400 }
	local gateNextDef: { number } = { 2, 3, 5, 6, 7 }
	for k = 1, 5 do
		local gx = gateXs[k]
		local nextDef = orbitalDefs[gateNextDef[k]]
		local label = ("NEXT: %s — %s WORKLOAD"):format(nextDef.Title, Format.abbreviate(nextDef.Workload))
		Kit.gateArch(parent, place(gx, 0, 0, 90), palette, label)
		-- Pads sit on the platform decks, alternating sides, clear of the walk.
		local padX = if k < 5 then segCentres[k] + 18 else segCentres[5] + 14
		local padZ = if k % 2 == 1 then 15 else -15
		local pad: BasePart = Kit.paydayPad(parent, place(padX, 0, padZ), palette)
		table.insert(paydayPads, { Segment = k, Pad = pad })
	end

	-- ═══════════════════════════ BOSS RING ════════════════════════════════
	-- A floating boardroom ring. The Chairman Emeritus waits at a crescent
	-- desk with Earth turning behind him.

	deck(BOSS_CX, 0, BOSS_SIZE, BOSS_SIZE, "BossDeck")
	fencePlatform(BOSS_CX, 0, BOSS_SIZE, BOSS_SIZE, { W = true })
	safetyRail(BOSS_CX - BOSS_SIZE / 2 - 0.5, -18, 1, 24)
	safetyRail(BOSS_CX - BOSS_SIZE / 2 - 0.5, 18, 1, 24)
	edgePosts(BOSS_CX, 0, BOSS_SIZE, BOSS_SIZE, 10)

	-- The crescent desk: a curved run of bevelled blocks on light columns.
	local crescentR = 13
	for i = 0, 10 do
		local angle = math.rad(-72 + i * 14.4)
		local dx = BOSS_CX + 10 + math.cos(angle) * crescentR
		local dz = math.sin(angle) * crescentR
		Kit.bevelBlock(
			parent,
			place(dx, 2.3, dz, math.deg(angle) + 90),
			Vector3.new(4.2, 0.5, 2.4),
			chromeCol
		)
		decor(place(dx, 1.1, dz, math.deg(angle) + 90), Vector3.new(2.4, 2.2, 1.4), accentCol, Enum.Material.Neon)
	end

	-- Chrome ring arch overhead, the boardroom's only "ceiling".
	for i = 0, 15 do
		local angle = i * math.pi / 8
		decor(
			place(BOSS_CX + math.cos(angle) * 26, 0.4, math.sin(angle) * 26),
			Vector3.new(1.6, 0.8, 1.6),
			chromeCol
		)
		decor(
			place(BOSS_CX + math.cos(angle) * 26, 18, math.sin(angle) * 26),
			Vector3.new(1.2, 0.6, 1.2),
			accentCol,
			Enum.Material.Neon
		)
	end
	for i = 0, 7 do
		local angle = i * math.pi / 4
		decor(
			place(BOSS_CX + math.cos(angle) * 26, 9, math.sin(angle) * 26),
			Vector3.new(0.5, 18, 0.5),
			chromeCol
		)
	end

	Kit.neonSign(parent, place(BOSS_CX, 21, 0, 90), palette, "THE BOARD", accentCol)
	Kit.rug(parent, place(BOSS_CX - 4, 0, 0), palette, 26, 30)

	-- The Chairman Emeritus, behind the crescent, Earth at his back.
	table.insert(rivalSpots, { DefIndex = 7, Cf = place(BOSS_CX + 22, RIVAL_Y, 0, 90) })
	Kit.officeChair(parent, place(BOSS_CX + 26, 0, 0, -90), palette, accentCol)
	for _, sz in { -8, 8 } do
		Kit.officeChair(parent, place(BOSS_CX - 8, 0, sz, -90), palette, darken(primaryCol, 0.2))
	end
	holoDisplay(BOSS_CX + 4, -20, 0)
	holoDisplay(BOSS_CX + 4, 20, 180)

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
