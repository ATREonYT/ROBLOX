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

-- Palette sampled from Alex's reference screenshots (Nov 7), then set as base colours
-- so the sunny lighting lands on the same on-screen values.
local GRASS = Color3.fromRGB(96, 214, 52)
local LEAF = Color3.fromRGB(84, 200, 50)
local LEAF_LIGHT = Color3.fromRGB(120, 222, 64)
local PATH = Color3.fromRGB(214, 118, 40)
local BRICK = Color3.fromRGB(186, 80, 46)
local STONE = Color3.fromRGB(168, 178, 182)
local STONE_DARK = Color3.fromRGB(128, 136, 142)
local LANE = Color3.fromRGB(172, 182, 186)
local LANE_STRIPE = Color3.fromRGB(132, 146, 146)
local PAD_RED = Color3.fromRGB(226, 52, 56)
local PAD_DARK = Color3.fromRGB(10, 14, 26)
local TRUNK = Color3.fromRGB(176, 92, 42)
local BIRCH = Color3.fromRGB(236, 232, 222)
local WATER = Color3.fromRGB(80, 206, 246)

-- The owner's classic round-stud texture (the one +1 Cannon Evolution uses, Oct 30).
local STUDS = "rbxassetid://18878365966"
local STUD_TILE = 2
local FACES = { Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }

local part = Models.Part

local function addStuds(p: BasePart, alpha: number?)
	local s = p.Size
	for _, face in FACES do
		local a, b
		if face == Enum.NormalId.Top then
			a, b = s.X, s.Z
		elseif face == Enum.NormalId.Front or face == Enum.NormalId.Back then
			a, b = s.X, s.Y
		else
			a, b = s.Z, s.Y
		end
		if a >= 1.5 and b >= 1.5 then
			local t = Instance.new("Texture")
			t.Name = "Studs"
			t.Texture = STUDS
			t.Face = face
			t.StudsPerTileU = STUD_TILE
			t.StudsPerTileV = STUD_TILE
			t.Transparency = alpha or 0
			t.Parent = p
		end
	end
end
MapBuilder.AddStuds = addStuds

local function studded(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, extra: { [string]: any }?): Part
	local props = { Material = Enum.Material.SmoothPlastic }
	if extra then
		for k, v in extra do
			props[k] = v
		end
	end
	local p = part(parent, name, size, cf, color, props)
	addStuds(p)
	return p
end

local function wedge(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Anchored = true
	w.Material = Enum.Material.SmoothPlastic
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Parent = parent
	addStuds(w)
	return w
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

-- Block trees like the reference: tiered pines, chunky blob trees and birches,
-- with root slabs at the foot. s = scale (1 = about 26 studs tall).
local function tree(parent: Instance, x: number, y: number, z: number, s: number, kind: string?)
	local m = Instance.new("Model")
	m.Name = "Tree"
	local trunkColor = if kind == "birch" then BIRCH else TRUNK
	local h = 14 * s
	studded(m, "Trunk", Vector3.new(3.4, h, 3.4) * Vector3.new(s, 1, s), CFrame.new(x, y + h / 2, z), trunkColor)
	for i, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		if i <= 2 or s > 1.1 then
			studded(m, "Root", Vector3.new(if d[1] ~= 0 then 3 else 2, 1.2, if d[2] ~= 0 then 3 else 2) * s, CFrame.new(x + d[1] * 2.4 * s, y + 0.6 * s, z + d[2] * 2.4 * s), TRUNK)
		end
	end
	if kind == "pine" then
		local tiers = { { 15, 4 }, { 12.5, 4 }, { 10, 4 }, { 7.5, 3.6 }, { 5, 3.2 } }
		local yy = y + h * 0.55
		for i, t in tiers do
			studded(m, "Leaves" .. i, Vector3.new(t[1], t[2], t[1]) * s, CFrame.new(x, yy + t[2] * s / 2, z), if i % 2 == 0 then LEAF_LIGHT else LEAF)
			yy += (t[2] + 0.6) * s
		end
	else
		local c = if kind == "birch" then LEAF_LIGHT else LEAF
		studded(m, "Leaves1", Vector3.new(16, 9, 16) * s, CFrame.new(x, y + h + 3 * s, z), c)
		studded(m, "Leaves2", Vector3.new(11, 7, 11) * s, CFrame.new(x + 3 * s, y + h + 9 * s, z - 2 * s), LEAF_LIGHT)
		studded(m, "Leaves3", Vector3.new(9, 6, 9) * s, CFrame.new(x - 4 * s, y + h + 6 * s, z + 4 * s), c)
	end
	for _, p in m:GetChildren() do
		(p :: BasePart).CanCollide = p.Name == "Trunk"
	end
	m.Parent = parent
	return m
end

local function bush(parent: Instance, x: number, y: number, z: number, s: number)
	studded(parent, "Bush", Vector3.new(7, 4, 5) * s, CFrame.new(x, y + 2 * s, z), LEAF_LIGHT, { CanCollide = false })
	studded(parent, "Bush", Vector3.new(5, 3, 4) * s, CFrame.new(x + 2.5 * s, y + 4.2 * s, z + 0.5 * s), LEAF, { CanCollide = false })
end

-- High ground: a brick cliff block with a grass lip on top (the reference's walls).
local CLIFF_H = 24
local function cliff(parent: Instance, x0: number, x1: number, z0: number, z1: number, h: number?)
	local hh = h or CLIFF_H
	local sx, sz = x1 - x0, z1 - z0
	studded(parent, "Cliff", Vector3.new(sx, hh, sz), CFrame.new((x0 + x1) / 2, hh / 2, (z0 + z1) / 2), BRICK)
	studded(parent, "CliffTop", Vector3.new(sx + 1.6, 2, sz + 1.6), CFrame.new((x0 + x1) / 2, hh + 1, (z0 + z1) / 2), GRASS)
end

---------------------------------------------------------------------------
-- Layout (studs, grass top y = 0). Looking from the spawn (+Z) toward the lane (-Z):
--   the treadmill yard is on the LEFT against the cliff, the chess-set gallery on the
--   RIGHT, the orange cross path between them, the stage lane straight ahead in a
--   canyon. Copied from Alex's reference shots (hub, yard, gallery and lane views).
---------------------------------------------------------------------------
local FAR_Z = -44 -- the far cliff (lane mouth)
local LANE_HALF = 18 -- lane is 36 wide
local STAGE_LEN = 40

function MapBuilder.Build(config: any): Model
	local map = Instance.new("Model")
	map.Name = "Map"
	local ground = folder(map, "Ground")
	local scenery = folder(map, "Scenery")

	-- Ground ------------------------------------------------------------------
	studded(ground, "Grass", Vector3.new(420, 2, 260), CFrame.new(0, -1, 80), GRASS)
	-- river on the near-left, sunk into the grass
	part(ground, "River", Vector3.new(16, 1, 170), CFrame.new(-86, -0.9, 125), WATER, { Material = Enum.Material.SmoothPlastic, Transparency = 0.1, CanCollide = false })
	part(ground, "RiverBed", Vector3.new(16, 1, 170), CFrame.new(-86, -2.2, 125), Color3.fromRGB(60, 120, 170), { Material = Enum.Material.SmoothPlastic })
	for i = 0, 5 do
		studded(scenery, "Rock", Vector3.new(4 + i % 3, 2 + i % 2, 4), CFrame.new(-79 + (i % 2) * -14, 0.2, 60 + i * 22), STONE_DARK)
	end
	for i = 0, 9 do
		local zf = 55 + i * 6
		part(scenery, "FencePost", Vector3.new(0.8, 3, 0.8), CFrame.new(-76, 1.5, zf), TRUNK)
		if i < 9 then
			part(scenery, "FenceRail", Vector3.new(0.5, 0.5, 6), CFrame.new(-76, 2.4, zf + 3), TRUNK)
		end
	end

	-- Cliffs (high ground) around the hub, with the lane canyon cut through ---
	cliff(scenery, -170, -62, FAR_Z, 44)                   -- left, behind the yard
	cliff(scenery, -170, -LANE_HALF, -480, FAR_Z)         -- far-left (lane left bank)
	cliff(scenery, LANE_HALF, 170, -480, FAR_Z)           -- far-right (lane right bank)
	cliff(scenery, 86, 170, FAR_Z, 40)                    -- right, behind the gallery
	cliff(scenery, -LANE_HALF, LANE_HALF, -488, -480)     -- lane end wall
	-- a lower step down to the near ground on both sides
	cliff(scenery, -170, -96, 44, 70, 10)
	cliff(scenery, 100, 170, 40, 80, 10)

	-- Paths -------------------------------------------------------------------
	local pathProps = { CanCollide = true }
	studded(ground, "PathMain", Vector3.new(12, 0.4, 136), CFrame.new(0, 0.2, 24), PATH, pathProps) -- z 92 .. -44
	studded(ground, "PathCross", Vector3.new(48, 0.4, 12), CFrame.new(0, 0.21, 0), PATH, pathProps) -- yard <-> gallery

	-- Spawn -------------------------------------------------------------------
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(10, 0.6, 10)
	spawn.CFrame = CFrame.new(0, 0.3, 66)
	spawn.Anchored = true
	spawn.Color = PATH
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Parent = map
	part(map, "SpawnLook", Vector3.new(1, 1, 1), CFrame.lookAt(Vector3.new(0, 3, 66), Vector3.new(0, 3, 0)), Color3.new(), { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })

	-- Treadmill yard (left): stone floor, raised rear tier, two ramps ---------
	local yard = folder(map, "Terrace")
	local YX0, YX1, YZ = -62, -22, 36 -- floor x range, half length in z
	studded(yard, "Floor", Vector3.new(YX1 - YX0, 1, YZ * 2), CFrame.new((YX0 + YX1) / 2, 0.5, 0), STONE)
	local TIER_X = -44
	studded(yard, "RearTier", Vector3.new(TIER_X - YX0, 5, YZ * 2), CFrame.new((YX0 + TIER_X) / 2, 3.5, 0), STONE)
	part(yard, "RearTrim", Vector3.new(0.6, 5.2, YZ * 2), CFrame.new(TIER_X + 0.3, 3.5, 0), STONE_DARK, { Material = Enum.Material.SmoothPlastic })
	for _, z in { -16, 16 } do
		-- high end against the tier (-X), low end toward the path (+X)
		local c = Vector3.new(TIER_X + 4, 3.5, z)
		wedge(yard, "Ramp", Vector3.new(8, 5, 8), CFrame.lookAt(c, c + Vector3.new(1, 0, 0)), STONE_DARK)
	end
	for _, z in { -YZ - 0.75, YZ + 0.75 } do
		studded(yard, "EndRim", Vector3.new(YX1 - YX0, 2.4, 1.5), CFrame.new((YX0 + YX1) / 2, 1.2, z), STONE_DARK)
	end

	local stations = folder(map, "Stations")
	local frontSlots = { -26, -5, 5, 26 }
	local rearSlots = { -24, -8, 8, 24 }
	local fi, ri = 0, 0
	for _, id in config.StationOrder do
		local st = config.Stations[id]
		local x, y, z
		if st.row == "front" then
			fi += 1
			x, y, z = -31, 1, frontSlots[fi]
		else
			ri += 1
			x, y, z = -52.5, 6, rearSlots[ri]
		end
		local cf = CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(x - 10, y, z)) -- runner faces the cliff, console at the back (reference)
		local machine = Models.Treadmill(id, cf)
		machine:SetAttribute("Built", st.built == true)
		local unlock = if not st.built then "Coming soon" elseif st.unlock then `Clear Stage {string.sub(st.unlock.stage, -1)}` else "FREE"
		local anchor = machine:FindFirstChild("LabelAnchor") :: BasePart
		billboard(anchor, "Label", UDim2.fromScale(9, 2.8), {
			{ text = `+{st.basePower} Power`, color = Color3.fromRGB(255, 255, 255), scale = 1 },
			{ text = unlock, color = if not st.built or st.unlock then Color3.fromRGB(255, 210, 90) else Color3.fromRGB(120, 255, 120), scale = 0.8 },
		}, 140)
		machine.Parent = stations
	end

	-- Chess-set gallery (right): stone block, rear ledge of 6 cases, sunken front row of 5
	local gallery = folder(map, "Gallery")
	local GX0, GX1, GZ = 24, 52, 39
	local LEDGE_X = 38
	studded(gallery, "Base", Vector3.new(GX1 - GX0, 1, GZ * 2), CFrame.new((GX0 + GX1) / 2, 0.5, 0), STONE)
	studded(gallery, "Ledge", Vector3.new(GX1 - LEDGE_X, 6, GZ * 2), CFrame.new((LEDGE_X + GX1) / 2, 4, 0), STONE)
	studded(gallery, "BackWall", Vector3.new(2, 2, GZ * 2), CFrame.new(GX1 - 1, 8, 0), STONE_DARK)
	-- raised shoulders at both ends with slopes down into the sunken front row
	for _, side in { -1, 1 } do
		local zc = side * (GZ - 5)
		studded(gallery, "Shoulder", Vector3.new(LEDGE_X - GX0, 6, 10), CFrame.new((GX0 + LEDGE_X) / 2, 4, zc), STONE)
		local wc = Vector3.new((GX0 + LEDGE_X) / 2, 4, zc - side * 8)
		wedge(gallery, "Slope", Vector3.new(LEDGE_X - GX0, 6, 6), CFrame.lookAt(wc, wc + Vector3.new(0, 0, side)), STONE_DARK)
		-- outer end slopes down to the grass
		local oc = Vector3.new((GX0 + GX1) / 2, 3.5, side * (GZ + 4))
		wedge(gallery, "EndSlope", Vector3.new(GX1 - GX0, 7, 8), CFrame.lookAt(oc, oc + Vector3.new(0, 0, side)), STONE)
	end
	local displays = folder(map, "SetDisplays")
	local frontZ = { -22, -11, 0, 11, 22 }
	local rearZ = { -27.5, -16.5, -5.5, 5.5, 16.5, 27.5 }
	for i, setId in config.SetOrder do
		local set = config.Sets[setId]
		local rear = i > #frontZ
		local x = if rear then 45 else 31
		local y = if rear then 7 else 1
		local z = if rear then rearZ[i - #frontZ] else frontZ[i]
		if not z then
			continue
		end
		local m = Instance.new("Model")
		m.Name = setId
		local padColor = if set.available then set.accent else PAD_DARK
		local plinth = studded(m, "Plinth", Vector3.new(7.5, 0.6, 7.5), CFrame.new(x, y + 0.3, z), padColor)
		part(m, "PlinthRim", Vector3.new(8.5, 0.4, 8.5), CFrame.new(x, y + 0.2, z), STONE_DARK, { Material = Enum.Material.SmoothPlastic })
		part(m, "Glass", Vector3.new(7.5, 7, 7.5), CFrame.new(x, y + 4.1, z), Color3.fromRGB(210, 235, 255), { Transparency = 0.86, CanCollide = false, CastShadow = false, Material = Enum.Material.Glass })
		local pieceAnchor = part(m, "PieceAnchor", Vector3.new(1, 1, 1), CFrame.new(x, y + 2.2, z) * CFrame.Angles(0, math.rad(-90), 0), Color3.new(), { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
		local material = if setId == "Marble" then Enum.Material.Marble elseif setId == "Wooden" then Enum.Material.Wood elseif setId == "Gold" or setId == "Champion" then Enum.Material.Metal else Enum.Material.SmoothPlastic
		local featured = Models.Piece(if rear then "Queen" else "Knight", set.color, 1.05, pieceAnchor.CFrame, { trim = set.accent, material = material })
		featured.Name = "Featured"
		featured.Parent = m
		-- floating label like the reference: name, red multiplier badge, state
		local plate = part(m, "Nameplate", Vector3.new(1, 1, 1), CFrame.new(x, y + 9.4, z), Color3.new(), { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
		local bb = billboard(plate, "Sign", UDim2.fromScale(7, 2.6), {
			{ text = set.name, color = Color3.fromRGB(255, 214, 160), scale = 1 },
			{ text = if set.available then `x{set.multiplier}  ·  {if set.price > 0 then tostring(set.price) .. " Wins" else "FREE"}` else "Coming soon", color = Color3.fromRGB(255, 220, 90), scale = 0.8 },
		}, 110)
		bb.LightInfluence = 0
		m:SetAttribute("SetId", setId)
		m:SetAttribute("Available", set.available)
		m.PrimaryPart = plinth
		m.Parent = displays
	end
	part(gallery, "ShopZone", Vector3.new(GX1 - GX0 + 10, 12, GZ * 2), CFrame.new((GX0 + GX1) / 2 - 5, 6, 0), Color3.new(), { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })

	-- "World 2" portal (locked, decoration) by the right cliff ----------------
	local portal = folder(map, "Portal")
	for i = 0, 6 do
		local a = math.rad(i * 30)
		local px, py = math.cos(a) * 9, math.sin(a) * 9
		studded(portal, "Arch", Vector3.new(4, 4, 4), CFrame.new(80, 2 + py, 40 + px), Color3.fromRGB(70 + i * 20, 80, 255 - i * 10))
	end
	part(portal, "Swirl", Vector3.new(1, 16, 16), CFrame.new(80, 4, 40) * CFrame.Angles(0, 0, 0), Color3.fromRGB(190, 60, 255), { Material = Enum.Material.Neon, Transparency = 0.35, CanCollide = false, Shape = Enum.PartType.Cylinder })
	local portalSign = part(portal, "SignAnchor", Vector3.new(1, 1, 1), CFrame.new(80, 14, 40), Color3.new(), { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	billboard(portalSign, "Label", UDim2.fromScale(10, 3), { { text = "World 2" }, { text = "Coming soon", color = Color3.fromRGB(255, 210, 90), scale = 0.7 } }, 140)

	-- Stage lane (straight ahead, -Z), in its canyon ----------------------------
	local lane = folder(map, "Lane")
	local stages = folder(map, "Stages")
	local nStages = #config.StageOrder
	local totalGates = nStages + (config.FutureStages or 0)
	local START = FAR_Z
	local laneEnd = -480
	local laneLen = START - laneEnd
	studded(lane, "Floor", Vector3.new(LANE_HALF * 2, 1, laneLen), CFrame.new(0, 0.5, (START + laneEnd) / 2), LANE)
	for i = 0, totalGates do
		local z0 = START - i * STAGE_LEN
		part(lane, "Divider", Vector3.new(LANE_HALF * 2, 1.06, 1.2), CFrame.new(0, 0.5, z0 - 1), Color3.fromRGB(120, 230, 90), { Material = Enum.Material.SmoothPlastic })
		part(lane, "Stripe", Vector3.new(LANE_HALF * 2, 1.04, 2.4), CFrame.new(0, 0.5, z0 - STAGE_LEN + 4), LANE_STRIPE, { Material = Enum.Material.SmoothPlastic })
	end

	local function gate(parent: Instance, z: number, color: Color3, text: string, locked: boolean?): Model
		local g = Instance.new("Model")
		g.Name = "Gate"
		local w = LANE_HALF * 2 - 2
		local frame = { Material = Enum.Material.SmoothPlastic }
		part(g, "LegL", Vector3.new(1.4, 12, 1.4), CFrame.new(-w / 2, 7, z), color, frame)
		part(g, "LegR", Vector3.new(1.4, 12, 1.4), CFrame.new(w / 2, 7, z), color, frame)
		part(g, "Beam", Vector3.new(w + 1.4, 1.4, 1.4), CFrame.new(0, 13, z), color, frame)
		local tag = part(g, "TagAnchor", Vector3.new(1, 1, 1), CFrame.new(0, 15.2, z), Color3.new(), { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
		billboard(tag, "Tag", UDim2.fromScale(10, 2.4), { { text = text } }, 260)
		local barrier = part(g, "Barrier", Vector3.new(w - 1.4, 12, 0.6), CFrame.new(0, 7, z), color, {
			Transparency = if locked then 0.55 else 1,
			CanCollide = locked == true,
			Material = Enum.Material.ForceField,
			CastShadow = false,
		})
		barrier:SetAttribute("Locked", locked == true)
		g.Parent = parent
		return g
	end

	local hidden = { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }
	for i, stageId in config.StageOrder do
		local st = config.Stages[stageId]
		local z0 = START - (i - 1) * STAGE_LEN
		local m = Instance.new("Model")
		m.Name = stageId
		gate(m, z0 - 3, st.color, `Stage {i}`, false)
		-- the red studded duel pad (reference), with a chessboard of red and dark tiles
		local padZ = z0 - 22
		local padX = 5
		local pad = studded(m, "Pad", Vector3.new(20, 0.5, 15), CFrame.new(padX, 1.25, padZ), PAD_RED)
		local tiles = folder(m, "Tiles")
		for r = 0, 3 do
			for c = 0, 3 do
				local dark = (r + c) % 2 == 1
				part(tiles, `Tile{r}{c}`, Vector3.new(2.6, 0.12, 2.6), CFrame.new(padX - 3.9 + c * 2.6, 1.56, padZ - 3.9 + r * 2.6), if dark then Color3.fromRGB(70, 74, 86) else Color3.fromRGB(246, 238, 220), { Material = Enum.Material.SmoothPlastic, CanCollide = false })
			end
		end
		part(m, "PadGlow", Vector3.new(21, 0.3, 16), CFrame.new(padX, 1.05, padZ), st.color, { Material = Enum.Material.Neon, Transparency = 0.6, CanCollide = false, CastShadow = false })
		part(m, "PlayerSpot", Vector3.new(2, 1, 2), CFrame.lookAt(Vector3.new(padX, 1.5, padZ + 10), Vector3.new(padX, 1.5, padZ)), Color3.new(), hidden)
		part(m, "PlayerPieceSpot", Vector3.new(1, 1, 1), CFrame.lookAt(Vector3.new(padX - 1.3, 1.62, padZ + 3.9), Vector3.new(padX - 1.3, 1.62, padZ)), Color3.new(), hidden)
		local rivalSpot = part(m, "RivalSpot", Vector3.new(1, 1, 1), CFrame.lookAt(Vector3.new(padX + 1.3, 1.62, padZ - 3.9), Vector3.new(padX + 1.3, 1.62, padZ + 4)), Color3.new(), hidden)
		local rival = Models.Piece(st.rival, Models.CHARCOAL, 0.6, rivalSpot.CFrame, { trim = st.color, collide = false })
		rival.Name = "Rival"
		rival.Parent = m
		part(m, "Zone", Vector3.new(LANE_HALF * 2 - 2, 10, 24), CFrame.new(0, 5, padZ + 4), Color3.new(), hidden)
		local sign = part(m, "Sign", Vector3.new(1, 1, 1), CFrame.new(padX, 9, padZ - 9), Color3.new(), hidden)
		billboard(sign, "Info", UDim2.fromScale(12, 3.6), {
			{ text = st.name, scale = 1.1 },
			{ text = `{st.power} Power  ·  +{st.reward} Wins`, color = Color3.fromRGB(255, 220, 90) },
		}, 120)
		-- small yellow return pad on the left, like the reference's coloured pads
		local ret = studded(m, "Return", Vector3.new(5, 0.5, 5), CFrame.new(-11, 1.25, padZ + 6), Color3.fromRGB(255, 205, 50))
		billboard(ret, "ReturnLabel", UDim2.fromScale(5, 1.5), { { text = "Return" } }, 60).StudsOffset = Vector3.new(0, 2.4, 0)
		local _ = pad
		m:SetAttribute("StageId", stageId)
		m.Parent = stages
	end

	-- future stages: coming-soon line, then more gates and pads for depth
	local future = folder(map, "Future")
	local futureZ = START - nStages * STAGE_LEN
	part(future, "ComingSoonLine", Vector3.new(LANE_HALF * 2, 0.3, 2.4), CFrame.new(0, 1.15, futureZ - 1), Color3.fromRGB(255, 210, 60), { Material = Enum.Material.Neon })
	local soon = gate(future, futureZ - 3, Color3.fromRGB(60, 62, 72), `Stage {nStages + 1} · Coming soon`, true)
	soon.Name = "ComingSoonGate"
	local palette = { Color3.fromRGB(230, 60, 220), Color3.fromRGB(255, 205, 40), Color3.fromRGB(255, 140, 40), Color3.fromRGB(160, 70, 255), Color3.fromRGB(60, 220, 200), Color3.fromRGB(255, 90, 90) }
	for k = 1, (config.FutureStages or 0) do
		local zk = futureZ - (k - 1) * STAGE_LEN
		if k > 1 then
			gate(future, zk - 3, palette[((k - 1) % #palette) + 1], `Stage {nStages + k}`, true)
		end
		studded(future, "Pad", Vector3.new(20, 0.5, 15), CFrame.new(5, 1.25, zk - 22), PAD_RED)
		studded(future, "SidePad", Vector3.new(5, 0.5, 5), CFrame.new(-11, 1.25, zk - 16), palette[(k % #palette) + 1])
	end

	-- Trees ---------------------------------------------------------------------
	local kinds = { "pine", "blob", "pine", "birch", "blob" }
	local n = 0
	local function plant(x: number, y: number, z: number, s: number)
		n += 1
		tree(scenery, x, y, z, s, kinds[(n % #kinds) + 1])
	end
	-- along the top of the far cliffs, both lane banks
	local zt = FAR_Z - 8
	local k = 0
	while zt > laneEnd + 10 do
		k += 1
		for _, side in { -1, 1 } do
			plant(side * (LANE_HALF + 8 + (k * 5) % 9), CLIFF_H + 2, zt + side * 6, 0.95 + (k % 3) * 0.15)
			if k % 2 == 0 then
				plant(side * (LANE_HALF + 30 + (k * 7) % 13), CLIFF_H + 2, zt - 8, 1.1)
			end
		end
		zt -= 22
	end
	-- top of the left cliff behind the yard, and the right cliff
	for i = 0, 5 do
		plant(-74 - (i % 2) * 18, CLIFF_H + 2, FAR_Z + 10 + i * 14, 1.05 + (i % 3) * 0.12)
		plant(98 + (i % 2) * 18, CLIFF_H + 2, FAR_Z + 8 + i * 14, 1 + (i % 2) * 0.15)
	end
	-- the hub's near side and around the path
	for _, t in { { -40, 60, 0.85 }, { -24, 78, 0.7 }, { 30, 62, 0.8 }, { 58, 76, 1 }, { -58, 96, 1 }, { 22, 100, 0.9 }, { 70, 52, 0.75 }, { -12, 46, 0.55 }, { 16, 34, 0.5 } } do
		plant(t[1], 0, t[2], t[3])
	end
	for _, b in { { 14, 18, 1 }, { -16, 26, 0.8 }, { 64, 18, 1.1 }, { 60, -30, 1 }, { -14, -30, 0.8 }, { 18, -34, 0.9 } } do
		bush(scenery, b[1], 0, b[2], b[3])
	end

	map:SetAttribute("Built", os.time())
	return map
end

-- Sunny simple lighting (applied once to Lighting).
function MapBuilder.Light(lighting: Instance, world: Instance?)
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
	local cc = lighting:FindFirstChild("ChessGrade") or Instance.new("ColorCorrectionEffect")
	cc.Name = "ChessGrade";
	(cc :: any).Saturation = 0.18;
	(cc :: any).Contrast = 0.06;
	(cc :: any).Brightness = 0.03
	cc.Parent = lighting
	local terrain = (world or workspace) and (world or workspace):FindFirstChildOfClass("Terrain")
	if terrain and not terrain:FindFirstChildOfClass("Clouds") then
		local clouds = Instance.new("Clouds")
		clouds.Cover = 0.55
		clouds.Density = 0.7
		clouds.Color = Color3.new(1, 1, 1)
		clouds.Parent = terrain
	end
	local atmo = lighting:FindFirstChildOfClass("Atmosphere")
	if atmo then
		(atmo :: any).Density = 0.22;
		(atmo :: any).Haze = 0.6;
		(atmo :: any).Color = Color3.fromRGB(200, 225, 255)
	end
end

return MapBuilder
