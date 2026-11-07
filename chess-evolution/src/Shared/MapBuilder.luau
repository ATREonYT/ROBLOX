--!strict
-- +1 Chess Evolution: the whole map, built from code (runs in Lune for the place file and in Studio).
-- Layout (studs, ground top at y = 0, hub centre at 0,0,0):
--   spawn on the orange cross path at +Z, looking -Z;
--   training terrace on the LEFT (-X), two tiers (front low = starters, rear raised = later tiers);
--   Chess Set gallery on the RIGHT (+X), two rows of plinths on a stepped deck;
--   the Board Run lane STRAIGHT AHEAD (-Z): grey slabs between orange-brown banks with green caps.
-- Gameplay anchors keep stable names: Map.Stations.<StationId>.Deck/Align,
-- Map.Stages.<StageId>.Zone/PlayerSpot/RivalSpot/Pad/Gate/Barrier/Return, Map.Gallery.<SetId>.Plinth/PieceAnchor.

local Models = require(script.Parent:WaitForChild("Models"))

local MapBuilder = {}

local GREEN = Color3.fromRGB(96, 214, 72)
local GREEN_DARK = Color3.fromRGB(70, 180, 60)
local ORANGE = Color3.fromRGB(240, 140, 50)
local BANK = Color3.fromRGB(200, 92, 48)
local GREY = Color3.fromRGB(170, 174, 182)
local GREY_DARK = Color3.fromRGB(130, 134, 144)
local TRUNK = Color3.fromRGB(196, 96, 50)
local BIRCH = Color3.fromRGB(235, 232, 220)

local part = Models.Part

local function studded(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, extra: { [string]: any }?): Part
	local props = { Material = Enum.Material.Plastic, TopSurface = Enum.SurfaceType.Studs }
	if extra then
		for k, v in extra do
			props[k] = v
		end
	end
	return part(parent, name, size, cf, color, props)
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function label(parent: BasePart, face: Enum.NormalId, lines: { { text: string, color: Color3?, scale: number? } }, ppu: number?): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppu or 40
	gui.LightInfluence = 0
	gui.Parent = parent
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = gui
	local total = 0
	for _, line in lines do
		total += line.scale or 1
	end
	for i, line in lines do
		local t = Instance.new("TextLabel")
		t.Name = "Line" .. i
		t.LayoutOrder = i
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(0.96, 0.92 * (line.scale or 1) / total)
		t.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		t.TextScaled = true
		t.Text = line.text
		t.TextColor3 = line.color or Color3.new(1, 1, 1)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 4
		stroke.Color = Color3.fromRGB(25, 25, 35)
		stroke.Parent = t
		t.Parent = gui
	end
	return gui
end
MapBuilder.Label = label

local function billboard(adornee: BasePart, name: string, size: UDim2, lines: { { text: string, color: Color3?, scale: number? } }, maxDistance: number?): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = size
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = maxDistance or 160
	gui.Adornee = adornee
	gui.Parent = adornee
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = gui
	local total = 0
	for _, line in lines do
		total += line.scale or 1
	end
	for i, line in lines do
		local t = Instance.new("TextLabel")
		t.Name = "Line" .. i
		t.LayoutOrder = i
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, (line.scale or 1) / total)
		t.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		t.TextScaled = true
		t.Text = line.text
		t.TextColor3 = line.color or Color3.new(1, 1, 1)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = Color3.fromRGB(25, 25, 35)
		stroke.Parent = t
		t.Parent = gui
	end
	return gui
end
MapBuilder.Billboard = billboard

-- Layered block tree: trunk + three stacked studded leaf blocks.
local function tree(parent: Instance, x: number, y: number, z: number, s: number, birch: boolean?)
	local m = Instance.new("Model")
	m.Name = "Tree"
	studded(m, "Trunk", Vector3.new(3, 9, 3) * s, CFrame.new(x, y + 4.5 * s, z), if birch then BIRCH else TRUNK)
	studded(m, "Leaves1", Vector3.new(12, 4, 12) * s, CFrame.new(x, y + 9 * s, z), GREEN)
	studded(m, "Leaves2", Vector3.new(8.5, 4, 8.5) * s, CFrame.new(x, y + 13 * s, z), GREEN)
	studded(m, "Leaves3", Vector3.new(5, 3.5, 5) * s, CFrame.new(x, y + 16.5 * s, z), GREEN)
	for _, p in m:GetChildren() do
		(p :: BasePart).CanCollide = p.Name == "Trunk"
	end
	m.Parent = parent
end

-- Orange-brown cliff wall with a green cap, from a to b (axis-aligned).
local function bank(parent: Instance, cx: number, cz: number, sx: number, sz: number, height: number)
	studded(parent, "Bank", Vector3.new(sx, height, sz), CFrame.new(cx, height / 2, cz), BANK)
	studded(parent, "BankCap", Vector3.new(sx + 1, 1.2, sz + 1), CFrame.new(cx, height + 0.6, cz), GREEN)
end

---------------------------------------------------------------------------
function MapBuilder.Build(config: any): Model
	local map = Instance.new("Model")
	map.Name = "Map"
	local ground = folder(map, "Ground")
	local scenery = folder(map, "Scenery")

	-- Ground and paths -------------------------------------------------------
	studded(ground, "Grass", Vector3.new(200, 2, 180), CFrame.new(0, -1, 26), GREEN)
	for _, hg in { { -130, 26, 64, 180 }, { 130, 26, 64, 180 }, { 0, 146, 324, 64 }, { -98, -92, 128, 64 }, { 98, -92, 128, 64 } } do
		studded(ground, "HighGround", Vector3.new(hg[3], 2, hg[4]), CFrame.new(hg[1], 11, hg[2]), GREEN)
	end
	local path = { Material = Enum.Material.Plastic, TopSurface = Enum.SurfaceType.Studs, CanCollide = true }
	part(ground, "PathMain", Vector3.new(14, 0.4, 136), CFrame.new(0, 0.2, 8), ORANGE, path) -- spawn -> lane (z 90 .. -50)
	part(ground, "PathCross", Vector3.new(84, 0.4, 14), CFrame.new(0, 0.21, 0), ORANGE, path) -- terrace <-> gallery
	part(ground, "PathEdgeL", Vector3.new(1, 0.5, 136), CFrame.new(-7.5, 0.25, 8), Color3.fromRGB(190, 100, 40), path)
	part(ground, "PathEdgeR", Vector3.new(1, 0.5, 136), CFrame.new(7.5, 0.25, 8), Color3.fromRGB(190, 100, 40), path)

	-- Spawn ------------------------------------------------------------------
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, 0.5, 52)
	spawn.Anchored = true
	spawn.Color = Color3.fromRGB(255, 220, 120)
	spawn.Material = Enum.Material.Plastic
	spawn.TopSurface = Enum.SurfaceType.Studs
	spawn.Duration = 0
	spawn.Parent = map
	local spawnLook = part(map, "SpawnLook", Vector3.new(1, 1, 1), CFrame.lookAt(Vector3.new(0, 3, 52), Vector3.new(0, 3, 0)), Color3.new(), { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	local _ = spawnLook

	-- Hub walls (cliffs) with the lane opening at -Z ------------------------
	local H = 12
	bank(scenery, -96, 26, 8, 180, H)
	bank(scenery, 96, 26, 8, 180, H)
	bank(scenery, 0, 112, 200, 8, H)
	bank(scenery, -57, -60, 78, 8, H) -- front wall, left of the lane
	bank(scenery, 57, -60, 78, 8, H) -- front wall, right of the lane

	-- Training terrace (left) --------------------------------------------------
	local terrace = folder(map, "Terrace")
	studded(terrace, "FrontTier", Vector3.new(28, 1.2, 76), CFrame.new(-52, 0.6, 0), GREY)
	studded(terrace, "RearTier", Vector3.new(26, 7, 76), CFrame.new(-79, 3.5, 0), GREY)
	studded(terrace, "RearLip", Vector3.new(1.2, 7.4, 76), CFrame.new(-65.6, 3.7, 0), GREY_DARK)
	-- wide, short ramps up to the rear tier at both ends and the middle
	for _, z in { -30, 30 } do
		local ramp = Instance.new("WedgePart")
		ramp.Name = "Ramp"
		ramp.Size = Vector3.new(12, 6, 10)
		ramp.CFrame = CFrame.new(-60, 4.2, z) * CFrame.Angles(0, math.rad(-90), 0)
		ramp.Color = GREY_DARK
		ramp.Anchored = true
		ramp.Material = Enum.Material.Plastic
		ramp.Parent = terrace
	end
	local stations = folder(map, "Stations")
	local frontZ = { PawnMill = 20, KnightSprint = 0, BishopRun = -20 }
	local rearZ = { RookRig = 20, QueenDash = 0, KingsEndgame = -20 }
	for id, st in config.Stations do
		local x, y, z
		if st.row == "front" then
			x, y, z = -50, 1.2, frontZ[id]
		else
			x, y, z = -79, 7, rearZ[id]
		end
		-- runner faces +X (toward the hub path)
		local cf = CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(x + 10, y, z))
		local machine = Models.Treadmill(id, cf)
		machine:SetAttribute("Built", st.built == true)
		local gain = `+{st.basePower} base per tap`
		local unlock = if not st.built then "Coming soon" elseif st.unlock then `Clear Stage {string.sub(st.unlock.stage, -1)}` else "FREE"
		local anchor = machine:FindFirstChild("LabelAnchor") :: BasePart
		billboard(anchor, "Label", UDim2.fromScale(12, 4.6), {
			{ text = st.name, scale = 1.2 },
			{ text = gain, color = Color3.fromRGB(150, 255, 140), scale = 0.8 },
			{ text = unlock, color = if not st.built or st.unlock then Color3.fromRGB(255, 210, 90) else Color3.fromRGB(150, 255, 140), scale = 0.8 },
		}, 140)
		machine.Parent = stations
	end

	-- Chess Set gallery (right) ------------------------------------------------
	local gallery = folder(map, "Gallery")
	studded(gallery, "Deck", Vector3.new(24, 1.2, 70), CFrame.new(50, 0.6, 0), GREY)
	studded(gallery, "UpperDeck", Vector3.new(22, 5, 70), CFrame.new(73, 2.5, 0), GREY)
	studded(gallery, "BackWall", Vector3.new(4, 14, 74), CFrame.new(86, 7, 0), GREY_DARK)
	for _, z in { -36, 36 } do
		studded(gallery, "SideWall", Vector3.new(46, 3, 2), CFrame.new(63, 1.5, z), GREY_DARK)
	end
	local galleryModels = folder(map, "SetDisplays")
	local rowZ = { 22, 7.5, -7.5, -22 }
	for i, setId in config.SetOrder do
		local set = config.Sets[setId]
		local rear = i > 4
		local x = if rear then 74 else 51
		local y = if rear then 5 else 1.2
		local z = rowZ[((i - 1) % 4) + 1]
		local m = Instance.new("Model")
		m.Name = setId
		local plinthColor = if set.available then set.accent else Color3.fromRGB(40, 42, 52)
		local plinth = studded(m, "Plinth", Vector3.new(9, 1.6, 9), CFrame.new(x, y + 0.8, z), plinthColor)
		studded(m, "PlinthRim", Vector3.new(10, 0.8, 10), CFrame.new(x, y + 0.4, z), GREY_DARK)
		-- glass case edges (thin frame, see-through sides)
		for _, dx in { -4.6, 4.6 } do
			for _, dz in { -4.6, 4.6 } do
				part(m, "CaseEdge", Vector3.new(0.4, 9, 0.4), CFrame.new(x + dx, y + 6.1, z + dz), Color3.fromRGB(220, 230, 240), { Transparency = 0.2 })
			end
		end
		part(m, "Glass", Vector3.new(9, 9, 9), CFrame.new(x, y + 6.1, z), Color3.fromRGB(200, 230, 255), { Transparency = 0.88, CanCollide = false, CastShadow = false, Material = Enum.Material.Glass })
		local pieceAnchor = part(m, "PieceAnchor", Vector3.new(1, 1, 1), CFrame.new(x, y + 3.2, z) * CFrame.Angles(0, math.rad(-90), 0), Color3.new(), { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
		local material = if setId == "Marble" then Enum.Material.Marble elseif setId == "Wooden" then Enum.Material.Wood elseif setId == "Gold" or setId == "Royal" then Enum.Material.Metal else Enum.Material.SmoothPlastic
		local featured = Models.Piece(if rear then "Queen" else "Knight", set.color, 0.9, pieceAnchor.CFrame, { trim = set.accent, material = material })
		featured.Name = "Featured"
		featured.Parent = m
		for _, side in { -1, 1 } do
			local small = Models.Piece("Pawn", set.color, 0.35, CFrame.new(x - 2.6, y + 1.6, z + side * 2.9), { trim = set.accent, material = material })
			small.Name = "Support"
			small.Parent = m
		end
		-- nameplate on the plinth front (faces -X toward the path)
		local plate = part(m, "Nameplate", Vector3.new(0.4, 2.2, 8.4), CFrame.new(x - 5.3, y + 1.4, z), Color3.fromRGB(40, 42, 52))
		label(plate, Enum.NormalId.Left, {
			{ text = set.name, scale = 1 },
			{ text = if set.available then `x{set.multiplier}  ·  {if set.price > 0 then tostring(set.price) .. " Wins" else "FREE"}` else "Coming soon", color = Color3.fromRGB(255, 220, 90), scale = 0.8 },
		}, 30)
		m:SetAttribute("SetId", setId)
		m:SetAttribute("Available", set.available)
		m.PrimaryPart = plinth
		m.Parent = galleryModels
	end
	local galleryZone = part(gallery, "ShopZone", Vector3.new(50, 10, 72), CFrame.new(62, 5, 0), Color3.new(), { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	local _g = galleryZone

	-- Board Run lane (straight ahead, -Z) --------------------------------------
	local lane = folder(map, "Lane")
	local stages = folder(map, "Stages")
	local LANE_W = 28
	local START = -60
	local STAGE_LEN = 64
	local nStages = #config.StageOrder
	local totalGates = nStages + (config.FutureStages or 0)
	local laneEnd = START - totalGates * STAGE_LEN - 20
	local laneLen = START - laneEnd
	local laneMid = (START + laneEnd) / 2
	-- floor, in repeated slabs with green separators
	for i = 0, totalGates do
		local z0 = START - i * STAGE_LEN
		studded(lane, "Slab", Vector3.new(LANE_W, 1, STAGE_LEN - 2), CFrame.new(0, 0.5, z0 - STAGE_LEN / 2), GREY)
		studded(lane, "Divider", Vector3.new(LANE_W, 1.05, 2), CFrame.new(0, 0.5, z0 - STAGE_LEN + 1), GREEN)
	end
	-- banks (raised orange-brown, green caps) and the high ground with trees outside
	local BH = 14
	for _, side in { -1, 1 } do
		local cx = side * (LANE_W / 2 + 8)
		bank(lane, cx, laneMid, 16, laneLen, BH)
		studded(lane, "HighGround", Vector3.new(60, 2, laneLen), CFrame.new(side * (LANE_W / 2 + 46), BH - 1, laneMid), GREEN)
	end
	studded(lane, "EndWall", Vector3.new(LANE_W, BH + 6, 4), CFrame.new(0, (BH + 6) / 2, laneEnd), BANK)

	local function gate(parent: Instance, z: number, color: Color3, text: string, locked: boolean?): Model
		local g = Instance.new("Model")
		g.Name = "Gate"
		local legs = { Material = Enum.Material.Plastic, TopSurface = Enum.SurfaceType.Studs }
		part(g, "LegL", Vector3.new(3, 20, 3), CFrame.new(-12, 10, z), color, legs)
		part(g, "LegR", Vector3.new(3, 20, 3), CFrame.new(12, 10, z), color, legs)
		local beam = part(g, "Beam", Vector3.new(27, 4.5, 3), CFrame.new(0, 21, z), color, legs)
		part(g, "BeamTrim", Vector3.new(27.4, 0.8, 3.4), CFrame.new(0, 18.7, z), Color3.fromRGB(255, 255, 255))
		label(beam, Enum.NormalId.Back, { { text = text } }, 24)
		label(beam, Enum.NormalId.Front, { { text = text } }, 24)
		local barrier = part(g, "Barrier", Vector3.new(21, 18, 1), CFrame.new(0, 9, z), color, {
			Transparency = if locked then 0.55 else 1,
			CanCollide = locked == true,
			Material = Enum.Material.ForceField,
			CastShadow = false,
		})
		barrier:SetAttribute("Locked", locked == true)
		g.Parent = parent
		return g
	end

	for i, stageId in config.StageOrder do
		local st = config.Stages[stageId]
		local z0 = START - (i - 1) * STAGE_LEN
		local m = Instance.new("Model")
		m.Name = stageId
		gate(m, z0 - 4, st.color, `STAGE {i}`, false)
		-- checker battle pad: 4 x 4 tiles of 4 studs
		local padZ = z0 - 34
		local pad = part(m, "Pad", Vector3.new(17, 0.6, 17), CFrame.new(0, 1.2, padZ), Color3.fromRGB(60, 62, 72), { Material = Enum.Material.Plastic })
		local tiles = folder(m, "Tiles")
		for r = 0, 3 do
			for c = 0, 3 do
				local light = (r + c) % 2 == 0
				part(tiles, `Tile{r}{c}`, Vector3.new(3.9, 0.2, 3.9), CFrame.new(-6 + c * 4, 1.55, padZ - 6 + r * 4), if light then Models.IVORY else Color3.fromRGB(70, 72, 84), { Material = Enum.Material.SmoothPlastic, CanCollide = false })
			end
		end
		local edge = part(m, "PadGlow", Vector3.new(18.4, 0.3, 18.4), CFrame.new(0, 0.95, padZ), st.color, { Material = Enum.Material.Neon, Transparency = 0.6, CanCollide = false, CastShadow = false })
		local _e = edge
		-- player stands just off the near edge; rival starts on the far row
		local hidden = { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }
		part(m, "PlayerSpot", Vector3.new(2, 1, 2), CFrame.lookAt(Vector3.new(0, 1, padZ + 12), Vector3.new(0, 1, padZ)), Color3.new(), hidden)
		part(m, "PlayerPieceSpot", Vector3.new(1, 1, 1), CFrame.lookAt(Vector3.new(-2, 1.65, padZ + 6), Vector3.new(-2, 1.65, padZ)), Color3.new(), hidden)
		local rivalSpot = part(m, "RivalSpot", Vector3.new(1, 1, 1), CFrame.lookAt(Vector3.new(2, 1.65, padZ - 6), Vector3.new(2, 1.65, padZ + 6)), Color3.new(), hidden)
		local rival = Models.Piece(st.rival, Models.CHARCOAL, 1.25, rivalSpot.CFrame, { trim = st.color, collide = false })
		rival.Name = "Rival"
		rival.Parent = m
		local zone = part(m, "Zone", Vector3.new(LANE_W - 2, 10, 22), CFrame.new(0, 5, padZ + 8), Color3.new(), hidden)
		local _z = zone
		-- sign: name, requirement, reward
		local sign = part(m, "Sign", Vector3.new(1, 5, 9), CFrame.new(-11.5, 4, padZ + 14), Color3.fromRGB(40, 42, 52))
		label(sign, Enum.NormalId.Right, {
			{ text = st.name, scale = 1.1 },
			{ text = `{st.power} Power`, color = Color3.fromRGB(150, 255, 140) },
			{ text = `+{st.reward} Wins first clear`, color = Color3.fromRGB(255, 220, 90) },
		}, 30)
		-- small return area
		local ret = part(m, "Return", Vector3.new(6, 0.4, 6), CFrame.new(10, 1.2, padZ + 16), Color3.fromRGB(255, 210, 60), { Material = Enum.Material.Neon, Transparency = 0.15 })
		billboard(ret, "ReturnLabel", UDim2.fromScale(5, 1.6), { { text = "Return" } }, 60).StudsOffset = Vector3.new(0, 2.5, 0)
		m:SetAttribute("StageId", stageId)
		m.Parent = stages
	end

	-- the next gate locks visually per player (client), Stage 1 never locks
	-- future section: a clearly marked "Coming soon" line, then more gates for depth
	local future = folder(map, "Future")
	local futureZ = START - nStages * STAGE_LEN
	local line = part(future, "ComingSoonLine", Vector3.new(LANE_W, 0.3, 3), CFrame.new(0, 1.1, futureZ - 2), Color3.fromRGB(255, 210, 60), { Material = Enum.Material.Neon })
	local soon = gate(future, futureZ - 6, Color3.fromRGB(60, 62, 72), "COMING SOON", true)
	soon.Name = "ComingSoonGate"
	local palette = { Color3.fromRGB(170, 70, 255), Color3.fromRGB(255, 120, 200), Color3.fromRGB(60, 220, 200), Color3.fromRGB(255, 150, 40), Color3.fromRGB(120, 220, 60) }
	for k = 1, (config.FutureStages or 0) do
		gate(future, futureZ - 6 - k * STAGE_LEN, palette[((k - 1) % #palette) + 1], `STAGE {nStages + k}`, true)
	end
	local _l = line

	-- Trees: hub corners (clear of paths and machines) and outside the lane banks
	local hubTrees = {
		{ -80, 98, 1.1 }, { -56, 100, 0.9 }, { -30, 96, 1 }, { 30, 98, 1 }, { 58, 100, 0.9 }, { 80, 96, 1.1 },
		{ -84, 66, 0.9 }, { 84, 64, 1 }, { -26, 70, 0.8 }, { 28, 72, 0.8 }, { -84, -48, 1 }, { 84, -48, 1 },
		{ -28, -46, 0.75 }, { 28, -46, 0.75 }, { -30, 36, 0.7 }, { 30, 34, 0.7 },
	}
	for i, t in hubTrees do
		tree(scenery, t[1], 0, t[2], t[3], i % 5 == 0)
	end
	local zt = START - 10
	local k = 0
	while zt > laneEnd + 10 do
		k += 1
		for _, side in { -1, 1 } do
			local x = side * (LANE_W / 2 + 24 + ((k * 7) % 11))
			tree(lane, x, BH, zt + side * 9, 0.9 + (k % 3) * 0.12, k % 4 == 0)
		end
		zt -= 30
	end
	-- trees on top of the hub cliffs
	for i = 0, 13 do
		local x = -150 + i * 23
		tree(scenery, x, H, 124 + (i % 3) * 9, 1 + (i % 2) * 0.2, i % 5 == 0)
	end
	for i = 0, 7 do
		for _, side in { -1, 1 } do
			tree(scenery, side * (110 + (i % 2) * 14), H, -50 + i * 22, 1 + (i % 3) * 0.1, i % 4 == 0)
		end
	end

	map:SetAttribute("Built", os.time())
	return map
end

-- Sunny simple lighting (applied once to Lighting).
function MapBuilder.Light(lighting: Instance)
	(lighting :: any).ClockTime = 14.5;
	(lighting :: any).Brightness = 2.6;
	(lighting :: any).Ambient = Color3.fromRGB(110, 110, 120);
	(lighting :: any).OutdoorAmbient = Color3.fromRGB(150, 150, 160);
	(lighting :: any).EnvironmentDiffuseScale = 0.6;
	(lighting :: any).EnvironmentSpecularScale = 0.3;
	(lighting :: any).GlobalShadows = true
	local bloom = lighting:FindFirstChildOfClass("BloomEffect")
	if bloom then
		(bloom :: any).Intensity = 0.25;
		(bloom :: any).Threshold = 1.6;
		(bloom :: any).Size = 20
	end
	local dof = lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	if dof then
		(dof :: any).Enabled = false
	end
	local atmo = lighting:FindFirstChildOfClass("Atmosphere")
	if atmo then
		(atmo :: any).Density = 0.22;
		(atmo :: any).Haze = 0.6;
		(atmo :: any).Color = Color3.fromRGB(200, 225, 255)
	end
end

return MapBuilder
