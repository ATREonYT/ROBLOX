-- The Block, version 2: a second take on World 1, built far away from the original so the two can be compared.
-- Edit-time builder; it creates or replaces Workspace.TheBlockV2, makes it the map the game runs on, and
-- brightens the place lighting (both reversible: SetActive(false), HoodLighting.Restore()).
-- Command Bar:  require(game.ServerStorage.TheBlockV2).Build()
--
-- Layout (local studs, floor top at y = 0, -Z runs from the lobby down the street):
--   lobby    x -44..44, z 0..44     a closed-off block-party plaza: you spawn 15 studs from the free Tire
--                                   Bag with Stage 1's gate in view; Drip Shop right, Bodega Box left
--   street   x -20..20, z 0..-368   ten stage gates 40 studs apart. Past each gate the next bag waits in an
--                                   alcove, and the street climbs from the hood toward uptown as you go
--   finale   x -40..40, z -368..-412  the Champ Ring plaza, the Kingpin statue and Juniper Station
--   terraces three stepped tiers (8 / 14 / 20 studs) around everything walkable
-- Floors and terraces come from one 4-stud grid and are merged into rectangles, so every piece meets its
-- neighbours edge to edge with nothing overlapping.
local V2 = {}
local Props, PROPS_KIT -- ServerStorage.HoodProps and the helpers it borrows, set in Build

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local V, C = Vector3.new, Color3.fromRGB
local M = Enum.Material
local S = Enum.SurfaceType

V2.Origin = CFrame.new(2400, 0, 0)

local P = {
	-- Ground stage (vibrancy research palette P3): light neutrals, 3-tone lime grass, blue-grey asphalt.
	lawnA = C(122, 217, 87), lawnB = C(94, 198, 75),
	pathA = C(240, 236, 228), pathB = C(226, 220, 208), pathRim = C(196, 188, 172),
	walkA = C(237, 230, 218), walkB = C(222, 214, 200),
	clubA = C(74, 82, 102), clubB = C(64, 72, 92),
	road = C(104, 112, 134), roadLine = C(255, 210, 63), paint = C(246, 246, 240),
	-- Candy rowhouse facades (palette P1); brick-red keeps the "brick row" identity every few blocks.
	candy = { C(216, 96, 63), C(255, 122, 92), C(255, 216, 110), C(116, 217, 181), C(99, 191, 255), C(180, 155, 255), C(34, 191, 176), C(255, 143, 184) },
	-- Doors and awnings (palette P2), always contrasting with the wall behind them.
	accent = { C(255, 63, 127), C(47, 123, 255), C(255, 194, 26), C(25, 179, 107) },
	flower = { C(255, 46, 154), C(255, 210, 63), C(255, 255, 255), C(99, 191, 255) },
	brick = { C(204, 108, 72), C(186, 94, 62), C(166, 82, 56) }, cap = { C(132, 210, 70), C(122, 200, 62), C(112, 190, 56) },
	trim = C(238, 230, 212), iron = C(43, 38, 51), steel = C(118, 128, 138), glass = C(64, 92, 118), glassLit = C(255, 214, 140),
	white = C(250, 250, 252), black = C(26, 26, 30), navy = C(28, 44, 92), yellow = C(255, 204, 48), cyan = C(64, 228, 242),
	magenta = C(238, 74, 172), orange = C(250, 140, 46), red = C(226, 56, 62), blue = C(56, 116, 232), purple = C(150, 84, 226),
	wood = C(150, 100, 62), woodDark = C(104, 70, 46), bark = C(116, 78, 50), leaf = { C(104, 196, 70), C(88, 178, 58), C(124, 212, 82) },
	cardboard = C(196, 150, 98), subway = C(46, 140, 92),
	-- Hood accents (hood_style_and_bags.md 1.3): every hero prop wears one saturated "toy" colour, iron is
	-- black-plum, never black.
	awning = C(255, 199, 44), hotRed = C(230, 59, 46), signGreen = C(31, 138, 76), globe = C(45, 190, 96),
	brownstone = C(184, 102, 74), plinth = C(142, 75, 54), chain = C(184, 192, 204), cream = C(255, 244, 222), ink = C(26, 26, 30),
	chalk = { C(255, 143, 184), C(99, 191, 255), C(255, 244, 222), C(255, 210, 63) },
	memphis = { C(255, 93, 162), C(255, 210, 63), C(51, 195, 240), C(142, 92, 247), C(46, 196, 182) },
	crate = { C(47, 123, 255), C(255, 63, 127), C(25, 179, 107) },
	win = C(255, 212, 0),
	-- Facades by how far out of the hood you are (1 the block, 2 fixing up, 3 nearly uptown). Never darker
	-- or dirtier at the start: just warmer, busier and more brick.
	era = {
		{ C(216, 96, 63), C(184, 102, 74), C(255, 122, 92), C(255, 201, 74), C(46, 196, 182), C(99, 191, 255), C(255, 143, 184), C(230, 59, 46) },
		{ C(255, 122, 92), C(255, 216, 110), C(116, 217, 181), C(99, 191, 255), C(180, 155, 255), C(34, 191, 176), C(255, 143, 184), C(216, 96, 63) },
		{ C(243, 233, 210), C(168, 216, 240), C(255, 231, 163), C(205, 235, 192), C(247, 198, 217), C(255, 244, 222) },
	},
	-- Flat roofs (light pavers read clean from above) for the block; rooftop gardens once you're nearly uptown.
	roof = { C(206, 198, 186), C(196, 188, 176), C(186, 178, 166) },
}
-- Stage colour ladder (lighting_and_gates.md): cool to hot, then gold, then the rainbow boss gate.
-- { base, dark (header, text stroke), light (neon, barrier) }
local STAGE = {
	{ C(120, 214, 72), C(58, 140, 40), C(190, 255, 140) }, { C(38, 200, 180), C(14, 120, 112), C(140, 255, 235) },
	{ C(64, 170, 255), C(26, 96, 190), C(160, 220, 255) }, { C(72, 104, 255), C(36, 52, 170), C(150, 170, 255) },
	{ C(150, 84, 240), C(88, 40, 160), C(210, 170, 255) }, { C(255, 90, 190), C(170, 40, 120), C(255, 170, 225) },
	{ C(240, 60, 64), C(150, 24, 34), C(255, 150, 150) }, { C(255, 140, 40), C(170, 80, 16), C(255, 200, 130) },
	{ C(255, 200, 40), C(176, 120, 10), C(255, 236, 150) }, { C(250, 250, 252), C(40, 40, 60), C(255, 220, 90) },
}
V2.StageColors = STAGE

---------------------------------------------------------------------------------------------- build context
local Ctx = {}
Ctx.__index = Ctx
local function newCtx(parent, cf) return setmetatable({ parent = parent, cf = cf }, Ctx) end
function Ctx:at(cf) return newCtx(self.parent, self.cf * cf) end
function Ctx:into(parent) return newCtx(parent, self.cf) end
function Ctx:group(name, class)
	local g = Instance.new(class or 'Model')
	g.Name = name
	g.Parent = self.parent
	return newCtx(g, self.cf), g
end
function Ctx:world(cf) return V2.Origin * self.cf * cf end
local function smooth(p)
	for _, face in { 'TopSurface', 'BottomSurface', 'FrontSurface', 'BackSurface', 'LeftSurface', 'RightSurface' } do p[face] = S.Smooth end
end
function Ctx:part(name, size, cf, color, material, shape)
	local p = Instance.new('Part')
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = V2.Origin * self.cf * cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	smooth(p)
	if shape then p.Shape = shape end
	p.Parent = self.parent
	return p
end
-- Axis-aligned box between two corners (in this context's frame).
function Ctx:box(name, a, b, color, material)
	local lo = V(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
	local hi = V(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
	return self:part(name, hi - lo, CFrame.new((lo + hi) / 2), color, material)
end
-- Upright cylinder standing on pos.
function Ctx:post(name, radius, height, pos, color, material)
	return self:part(name, V(height, radius * 2, radius * 2), CFrame.new(pos + V(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, material or M.Metal, Enum.PartType.Cylinder)
end
-- Cylinder lying along the X axis of cf.
function Ctx:rod(name, radius, length, cf, color, material)
	return self:part(name, V(length, radius * 2, radius * 2), cf, color, material or M.Metal, Enum.PartType.Cylinder)
end
-- Square bar from a to b.
function Ctx:bar(name, a, b, width, color, material)
	local dir = b - a
	local up = math.abs(dir.Unit.Y) > 0.99 and V(1, 0, 0) or V(0, 1, 0)
	return self:part(name, V(width, width, dir.Magnitude), CFrame.lookAt((a + b) / 2, b, up), color, material or M.Metal)
end
function Ctx:blob(name, size, pos, color, material)
	local p = self:part(name, size, CFrame.new(pos), color, material)
	local mesh = Instance.new('SpecialMesh')
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end
function Ctx:wedge(name, size, cf, color, material)
	local p = Instance.new('WedgePart')
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = V2.Origin * self.cf * cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	smooth(p)
	p.Parent = self.parent
	return p
end

-- Classic Roblox studs on the top (and optionally the sides) of a part.
local function studs(p, sides)
	p.Material = M.Plastic
	p.TopSurface = S.Studs
	if sides then
		p.FrontSurface, p.BackSurface, p.LeftSurface, p.RightSurface = S.Studs, S.Studs, S.Studs, S.Studs
	end
	return p
end
local function decor(p)
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	return p
end
local function ghost(p)
	decor(p).Transparency = 1
	return p
end
local function light(p, color, brightness, range)
	local l = Instance.new('PointLight')
	l.Color, l.Brightness, l.Range, l.Shadows = color, brightness, range, false
	l.Parent = p
	return l
end

---------------------------------------------------------------------------------------------- text
local FONT = { title = Enum.Font.FredokaOne, loud = Enum.Font.LuckiestGuy, body = Enum.Font.GothamBlack, tag = Enum.Font.PermanentMarker }
local function surface(p, face, ppS)
	local g = Instance.new('SurfaceGui')
	g.Name = 'Signage'
	g.Face = face or Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = ppS or 40
	g.LightInfluence = 0
	g.Parent = p
	return g
end
-- One line of text in a band of the gui (y and h are 0-1), with a clean outline.
local function line(gui, name, value, color, font, y, h, outline, thickness)
	local t = Instance.new('TextLabel')
	t.Name = name
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromScale(0.04, y)
	t.Size = UDim2.fromScale(0.92, h)
	t.Font = font
	t.Text = value
	t.TextColor3 = color
	t.TextScaled = true
	t.TextWrapped = true
	t.TextStrokeTransparency = 1
	if outline then
		local s = Instance.new('UIStroke')
		s.Color = outline
		s.Thickness = thickness or 2
		s.LineJoinMode = Enum.LineJoinMode.Round
		s.Parent = t
	end
	t.Parent = gui
	return t
end
local function billboard(ctx, pos, w, h, rows)
	local a = ghost(ctx:part('LabelAnchor', V(0.2, 0.2, 0.2), CFrame.new(pos), P.white))
	local g = Instance.new('BillboardGui')
	g.Name = 'WorldLabel'
	g.Size = UDim2.fromScale(w, h)
	g.MaxDistance = 90
	g.LightInfluence = 0
	g.Parent = a
	for _, r in rows do line(g, r[1], r[2], r[3], r[4], r[5], r[6], P.black, 2) end
	return a
end
local function compact(n)
	if n >= 1e6 then return (string.format('%.1fM', n / 1e6):gsub('%.0M', 'M')) end
	if n >= 1000 then return (string.format('%.1fK', n / 1000):gsub('%.0K', 'K')) end
	return tostring(n)
end

---------------------------------------------------------------------------------------------- the grid
local CELL = 4
local G = { x0 = -84, x1 = 84, z0 = -440, z1 = 72 }
local NX, NZ = (G.x1 - G.x0) / CELL, (G.z1 - G.z0) / CELL
local TIER_TOP = { 8, 14, 20 }
V2.TierTop = TIER_TOP

local function newGrid()
	local g = {}
	for i = 1, NX do g[i] = {} end
	return g
end
local function cellOf(x, z) return math.floor((x - G.x0) / CELL) + 1, math.floor((z - G.z0) / CELL) + 1 end
local function cellRect(i, j) return G.x0 + (i - 1) * CELL, G.z0 + (j - 1) * CELL, G.x0 + i * CELL, G.z0 + j * CELL end
local function paint(grid, x0, z0, x1, z1, kind)
	assert(x0 % CELL == 0 and x1 % CELL == 0 and z0 % CELL == 0 and z1 % CELL == 0, 'floor rectangles snap to the 4-stud grid')
	local i0, j0 = cellOf(x0, z0)
	local i1, j1 = cellOf(x1 - 1, z1 - 1)
	for i = i0, i1 do for j = j0, j1 do grid[i][j] = kind end end
end
-- Greedy rectangle merge: every emitted rectangle is a maximal run of cells sharing one key.
local function merge(keyOf, emit)
	local done = newGrid()
	for j = 1, NZ do
		for i = 1, NX do
			local k = not done[i][j] and keyOf(i, j)
			if k then
				local w = 1
				while i + w <= NX and not done[i + w][j] and keyOf(i + w, j) == k do w += 1 end
				local h = 1
				while j + h <= NZ do
					local ok = true
					for a = i, i + w - 1 do
						if done[a][j + h] or keyOf(a, j + h) ~= k then ok = false; break end
					end
					if not ok then break end
					h += 1
				end
				for a = i, i + w - 1 do for b = j, j + h - 1 do done[a][b] = true end end
				local x0, z0 = cellRect(i, j)
				local _, _, x1, z1 = cellRect(i + w - 1, j + h - 1)
				emit(k, x0, z0, x1, z1)
			end
		end
	end
end
local function hash(a, b) return (a * 73856093 + b * 19349663) % 1000 end

-- Stage gates: names and Power from the World 1 config, 40 studs apart down the street.
local STAGE_GAP, STAGE_FIRST = 40, -4
local function stageZ(i) return STAGE_FIRST - (i - 1) * STAGE_GAP end
local FINALE_Z0, FINALE_Z1 = stageZ(10) - 48, stageZ(10) - 4 -- -412 .. -368
-- What waits past each gate (segment k runs from gate k to gate k+1), alternating sides of the street.
-- Each bag sits just past the first gate whose number is at or under the bag's price, so it is usable
-- almost as soon as you reach it. The Champ Ring waits past gate 10 in the finale plaza.
local SEGMENTS = {
	{ station = 'Tape', side = -1 }, { station = 'Street', side = 1 }, { piece = 'Court', side = -1 },
	{ station = 'Heavy', side = 1 }, { station = 'Speed', side = -1 }, { station = 'DoubleEnd', side = 1 },
	{ station = 'Pro', side = -1 }, { piece = 'Party', side = 1 }, { station = 'Gold', side = -1 },
}
V2.Segments = SEGMENTS
-- Alcove beside the street for segment k: x0, z0, x1, z1 (16 deep, 28 long, opening onto the sidewalk).
local function alcove(k)
	local s, z = SEGMENTS[k].side, stageZ(k)
	return math.min(s * 20, s * 36), z - 36, math.max(s * 20, s * 36), z - 8
end
-- How far out of the hood a point of the street is: 1 = the block, 2 = fixing up, 3 = nearly uptown.
local function era(z)
	if z > stageZ(4) then return 1 elseif z > stageZ(9) then return 2 end
	return 3
end

local CHECKER = { lawn = { P.lawnA, P.lawnB }, path = { P.pathA, P.pathB }, walk = { P.walkA, P.walkB }, club = { P.clubA, P.clubB } }
-- Walkable floor plan. Later paints win. 'pit' cells get no floor and no terrace (a building stands there).
local function planFloors()
	local g = newGrid()
	-- Lobby: lawn lots either side of the plaza, the Drip Shop stand on the right with its building behind.
	paint(g, -44, 0, 44, 44, 'lawn')
	paint(g, -20, 0, 20, 44, 'path')
	paint(g, 20, 4, 44, 40, 'walk')
	paint(g, 44, 4, 60, 40, 'pit')
	paint(g, -44, 4, -32, 40, 'walk')
	-- The street: sidewalks and road from the lobby to the finale plaza.
	paint(g, -20, FINALE_Z1, 20, 0, 'walk')
	paint(g, -12, FINALE_Z1, 12, 0, 'road')
	for k, seg in SEGMENTS do
		local x0, z0, x1, z1 = alcove(k)
		paint(g, x0, z0, x1, z1, seg.piece == 'Court' and 'lawn' or 'path')
	end
	paint(g, -40, FINALE_Z0, 40, FINALE_Z1, 'path')
	return g
end

---------------------------------------------------------------------------------------------- floors, rims, terraces
local function buildGround(ctx, floors)
	local ground = ctx:group('Ground')
	local function key(i, j)
		local k = floors[i][j]
		if not k or k == 'pit' then return nil end
		if CHECKER[k] then return k .. (math.floor((i - 1) / 2) + math.floor((j - 1) / 2)) % 2 end
		return k
	end
	merge(key, function(k, x0, z0, x1, z1)
		local kind, parity = k:match('^(%a+)(%d?)$')
		local color = CHECKER[kind] and CHECKER[kind][tonumber(parity) + 1] or P.road
		local p = ground:box('Floor_' .. kind, V(x0, -1, z0), V(x1, 0, z1), color, kind == 'road' and M.Asphalt or M.Plastic)
		if kind ~= 'road' then studs(p) end
	end)
	-- Raised rim where a light path meets lawn: x-runs run full length, z-runs stop short of them at corners.
	local rim = ground:group('PathRims')
	local W, H = 0.8, 0.35
	local function isPath(i, j) local k = floors[i] and floors[i][j]; return k == 'path' end
	local function isLawn(i, j) local k = floors[i] and floors[i][j]; return k == 'lawn' or k == 'club' end
	local xEdges = {}
	for j = 1, NZ do
		for _, dz in { -1, 1 } do
			local i = 1
			while i <= NX do
				if isPath(i, j) and isLawn(i, j + dz) then
					local s = i
					while i + 1 <= NX and isPath(i + 1, j) and isLawn(i + 1, j + dz) do i += 1 end
					local x0, z0, _, z1 = cellRect(s, j)
					local _, _, x1 = cellRect(i, j)
					local z = dz < 0 and z0 or z1
					local p = rim:box('PathRim', V(x0, 0, z), V(x1, H, z - dz * W), P.pathRim, M.Plastic)
					studs(p)
					for a = s, i do xEdges[a .. ',' .. j .. ',' .. dz] = true end
				end
				i += 1
			end
		end
	end
	for i = 1, NX do
		for _, dx in { -1, 1 } do
			local j = 1
			while j <= NZ do
				if isPath(i, j) and isLawn(i + dx, j) then
					local s = j
					while j + 1 <= NZ and isPath(i, j + 1) and isLawn(i + dx, j + 1) do j += 1 end
					local x0, z0, x1 = cellRect(i, s)
					local _, _, _, z1 = cellRect(i, j)
					if xEdges[i .. ',' .. s .. ',-1'] then z0 += W end
					if xEdges[i .. ',' .. j .. ',1'] then z1 -= W end
					local x = dx < 0 and x0 or x1
					studs(rim:box('PathRim', V(x, 0, z0), V(x - dx * W, H, z1), P.pathRim, M.Plastic))
				end
				j += 1
			end
		end
	end
end

-- Tier of every non-walkable cell: 1-3 by distance (in cells) from the nearest walkable cell.
local function planTerraces(floors)
	local dist = newGrid()
	local queue, head = {}, 1
	for i = 1, NX do
		for j = 1, NZ do
			if floors[i][j] then dist[i][j] = 0; table.insert(queue, { i, j }) end
		end
	end
	while head <= #queue do
		local i, j = queue[head][1], queue[head][2]
		head += 1
		for di = -1, 1 do
			for dj = -1, 1 do
				local a, b = i + di, j + dj
				if a >= 1 and a <= NX and b >= 1 and b <= NZ and dist[a][b] == nil then
					dist[a][b] = dist[i][j] + 1
					table.insert(queue, { a, b })
				end
			end
		end
	end
	local tier = newGrid()
	for i = 1, NX do
		for j = 1, NZ do
			local d = dist[i][j]
			tier[i][j] = d and d > 0 and d <= 6 and math.ceil(d / 2) or 0
		end
	end
	return tier
end
local function tierTop(tier, i, j)
	local t = tier[i][j]
	if t == 0 then return nil end
	-- A few raised blocks on the top tier break up the skyline.
	if t == 3 and hash(math.floor(i / 3), math.floor(j / 3)) % 4 == 0 then return 24 end
	return TIER_TOP[t]
end
-- Roof height under a square footprint, or nil if the footprint isn't one flat terrace top.
local function roofTop(tier, x, z, r)
	local h
	for _, dx in { -r, r } do
		for _, dz in { -r, r } do
			local i, j = cellOf(x + dx, z + dz)
			if i < 1 or i > NX or j < 1 or j > NZ then return nil end
			local t = tierTop(tier, i, j)
			if not t or (h and h ~= t) then return nil end
			h = t
		end
	end
	return h
end
-- Facade colour of the terrace block at a world-plan point (filled by buildTerraces; used for doors).
local facadeAt = {}
local function facadeColor(x, z)
	local i, j = cellOf(x, z)
	return facadeAt[i .. ',' .. j]
end
-- Which colour zone a terrace cell belongs to: the lobby, segment k of the street (between gate k and
-- gate k+1) or the finale plaza. Facades take the palette of the zone's era.
local function zoneOf(i, j)
	local _, z0, _, z1 = cellRect(i, j)
	local zc = (z0 + z1) / 2
	if zc > STAGE_FIRST then return 'lobby', 1 end
	if zc < FINALE_Z1 then return 'fin', 3 end
	local k = math.clamp(math.floor((STAGE_FIRST - zc) / STAGE_GAP) + 1, 1, 9)
	return 's' .. k, era(zc)
end
local function buildTerraces(ctx, tier)
	local t = ctx:group('Terraces')
	local rects = {}
	merge(function(i, j)
		local h = tierTop(tier, i, j)
		local zone, e = zoneOf(i, j)
		return h and (tier[i][j] .. ':' .. h .. ':' .. zone .. ':' .. e)
	end, function(k, x0, z0, x1, z1)
		local n, h, zone, e = k:match('^(%d+):(%d+):([^:]+):(%d)$')
		table.insert(rects, { n = tonumber(n), h = tonumber(h), zone = zone, era = tonumber(e), x0 = x0, z0 = z0, x1 = x1, z1 = z1 })
	end)
	-- Rowhouse colouring: no two touching blocks share a colour, so the street reads as separate houses.
	local function touches(a, b)
		local xo = math.min(a.x1, b.x1) - math.max(a.x0, b.x0)
		local zo = math.min(a.z1, b.z1) - math.max(a.z0, b.z0)
		return (xo >= 0 and zo > 0) or (zo >= 0 and xo > 0)
	end
	for idx, r in rects do
		local palette = P.era[r.era]
		local used = {}
		for k = 1, idx - 1 do
			local o = rects[k]
			if o.era == r.era and touches(r, o) then used[o.ci] = true end
		end
		local start = (hash(r.x0 // 4, r.z0 // 4) % #palette) + 1
		for step = 0, #palette - 1 do
			local ci = (start - 1 + step) % #palette + 1
			if not used[ci] then r.ci = ci; break end
		end
		r.ci = r.ci or 1
		-- Higher steps a touch deeper so the terraces still read as separate levels.
		local color = palette[r.ci]:Lerp(Color3.new(0, 0, 0), (r.n - 1) * (r.era == 3 and 0.05 or 0.08))
		studs(t:box('TerraceBlock', V(r.x0, -1, r.z0), V(r.x1, r.h - 1, r.z1), color, M.Plastic), true)
		-- Flat paver roofs on the block; rooftop gardens once the street is nearly uptown.
		if r.era == 3 then
			studs(t:box('TerraceGrass', V(r.x0, r.h - 1, r.z0), V(r.x1, r.h, r.z1), P.cap[r.n], M.Plastic), true)
		else
			-- Roofs take a light tint of their own facade, so the map stays colourful from above.
			studs(t:box('TerraceRoof', V(r.x0, r.h - 1, r.z0), V(r.x1, r.h, r.z1), palette[r.ci]:Lerp(P.roof[r.n], 0.55), M.Plastic), true)
		end
		local i0, j0 = cellOf(r.x0, r.z0)
		local i1, j1 = cellOf(r.x1 - 1, r.z1 - 1)
		for i = i0, i1 do for j = j0, j1 do facadeAt[i .. ',' .. j] = color end end
	end
end

-- Every visible terrace face, as straight runs: {from, to, a, b (along-axis range), at (face plane), normal, y0, y1}.
local function terraceFaces(floors, tier)
	local faces = {}
	local function heightAt(i, j)
		if i < 1 or i > NX or j < 1 or j > NZ then return nil end
		if floors[i][j] then return 0 end
		return tierTop(tier, i, j)
	end
	for _, dir in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local alongX = dir[1] == 0
		local outer, inner = alongX and NZ or NX, alongX and NX or NZ
		for o = 1, outer do
			local s
			local function flush(e)
				if not s then return end
				local i0, j0 = alongX and s.k or o, alongX and o or s.k
				local x0, z0, x1, z1 = cellRect(i0, j0)
				local ie, je = alongX and e or o, alongX and o or e
				local ex0, ez0, ex1, ez1 = cellRect(ie, je)
				local face = { y0 = s.lo, y1 = s.hi, normal = V(-dir[1], 0, -dir[2]) }
				face.tier = tier[i0 + dir[1]][j0 + dir[2]]
				if alongX then
					-- An end is an outside corner when neither cell beyond it rises to this face's top.
					local function outside(k) return (heightAt(k, o + dir[2]) or -1) < s.hi and (heightAt(k, o) or -1) < s.hi end
					face.outA, face.outB = outside(s.k - 1), outside(e + 1)
				end
				if alongX then
					face.a, face.b = x0, ex1
					face.at = dir[2] > 0 and z1 or z0
				else
					face.a, face.b = z0, ez1
					face.at = dir[1] > 0 and x1 or x0
				end
				face.alongX = alongX
				table.insert(faces, face)
				s = nil
			end
			for k = 1, inner do
				local i, j = alongX and k or o, alongX and o or k
				local lo = heightAt(i, j)
				local hi = heightAt(i + dir[1], j + dir[2])
				if lo and hi and hi > lo then
					if s and s.lo == lo and s.hi == hi then s.e = k else flush(k - 1); s = { k = k, lo = lo, hi = hi } end
				else
					flush(k - 1)
				end
			end
			flush(inner)
		end
	end
	return faces
end

-- Grass lip: the cap overhangs each terrace face by 0.6 studs, like the grass on a canyon terrace.
-- Faces along X carry the corner pieces at outside corners; faces along Z stop at the corner line, so lips
-- meet without overlapping. Reserved stretches (storefronts, gates, the shop building) are left bare.
local LIP_OUT, LIP_DROP = 0.6, 1.1
local function buildLips(ctx, faces, reserved)
	local lips = ctx:group('TerraceLips')
	for _, f in faces do
		local a = f.a - ((f.alongX and f.outA) and LIP_OUT or 0)
		local b = f.b + ((f.alongX and f.outB) and LIP_OUT or 0)
		-- Subtract reserved ranges on this face's plane.
		local spans = { { a, b } }
		for _, r in reserved do
			if r.alongX == f.alongX and math.abs(r.at - f.at) < 0.5 then
				local out = {}
				for _, sp in spans do
					if r.b <= sp[1] or r.a >= sp[2] then table.insert(out, sp)
					else
						if r.a > sp[1] then table.insert(out, { sp[1], r.a }) end
						if r.b < sp[2] then table.insert(out, { r.b, sp[2] }) end
					end
				end
				spans = out
			end
		end
		-- Cream cornice along every roofline on the block; a grass fringe with flowers on rooftop gardens.
		-- Faces running along the street are cut where the era changes.
		if not f.alongX then
			local cut = {}
			for _, sp in spans do
				local from = sp[1]
				for _, z in { stageZ(9), stageZ(4), STAGE_FIRST } do
					if z > from and z < sp[2] then table.insert(cut, { from, z }); from = z end
				end
				table.insert(cut, { from, sp[2] })
			end
			spans = cut
		end
		for _, sp in spans do
			local z = f.alongX and f.at or (sp[1] + sp[2]) / 2
			local garden = z <= STAGE_FIRST and era(z) == 3
			local color = garden and (P.cap[f.tier] or P.cap[1]) or P.cream
			if garden and sp[2] - sp[1] > 2 then
				local k = 0
				for u = sp[1] + 1.2, sp[2] - 1.2, 2.4 do
					k += 1
					local out = f.normal * 0.3
					local pos = f.alongX and V(u, f.y1 + 0.28, f.at + out.Z) or V(f.at + out.X, f.y1 + 0.28, u)
					lips:part('LipFlower', V(0.8, 0.8, 0.8), CFrame.new(pos), P.flower[(k + math.floor(u)) % #P.flower + 1], M.SmoothPlastic, Enum.PartType.Ball)
				end
			end
			if sp[2] - sp[1] > 0.5 then
				local out = f.normal * LIP_OUT
				local lo, hi
				if f.alongX then
					lo, hi = V(sp[1], f.y1 - LIP_DROP, f.at), V(sp[2], f.y1, f.at + out.Z)
				else
					lo, hi = V(f.at, f.y1 - LIP_DROP, sp[1]), V(f.at + out.X, f.y1, sp[2])
				end
				if garden then studs(lips:box('GrassLip', lo, hi, color, M.Plastic), true)
				else lips:box('Cornice', lo, hi, color, M.SmoothPlastic) end
			end
		end
	end
	return lips
end

---------------------------------------------------------------------------------------------- facade details
-- Frame for a face: origin on the face plane at (along, y), local -Z points out of the wall.
local function faceFrame(f, along, y)
	local p = f.alongX and V(along, y, f.at) or V(f.at, y, along)
	return CFrame.lookAt(p, p + f.normal)
end
local function window(ctx, lit, flowers)
	if flowers then
		-- Flower box in front of the sill: a wood trough with four blooms.
		ctx:box('FlowerBox', V(-1.5, -1.15, -1.25), V(1.5, -0.6, -0.6), P.woodDark, M.WoodPlanks)
		for k = 0, 3 do
			ctx:part('Bloom', V(0.55, 0.55, 0.55), CFrame.new(-1.05 + k * 0.7, -0.45, -0.92), P.flower[(flowers + k) % #P.flower + 1], M.SmoothPlastic, Enum.PartType.Ball)
		end
	end
	ctx:box('Glass', V(-1.2, 0, -0.12), V(1.2, 3, 0), lit and P.glassLit or P.glass, M.Glass)
	ctx:box('Frame', V(-1.45, 3, -0.25), V(1.45, 3.3, 0), P.trim, M.SmoothPlastic)
	ctx:box('Frame', V(-1.45, -0.3, -0.25), V(1.45, 0, 0), P.trim, M.SmoothPlastic)
	ctx:box('Frame', V(-1.45, 0, -0.25), V(-1.2, 3, 0), P.trim, M.SmoothPlastic)
	ctx:box('Frame', V(1.2, 0, -0.25), V(1.45, 3, 0), P.trim, M.SmoothPlastic)
	ctx:box('Sill', V(-1.7, -0.6, -0.6), V(1.7, -0.3, 0), P.trim, M.SmoothPlastic)
	ctx:box('Mullion', V(-0.08, 0, -0.18), V(0.08, 3, -0.12), P.trim, M.SmoothPlastic)
end
-- Front door on a ground-floor face: stoop, colour door with panels, trim, striped awning, planter.
local function hueDistance(a, b)
	local ha = a:ToHSV()
	local hb = b:ToHSV()
	local d = math.abs(ha - hb)
	return math.min(d, 1 - d)
end
local function door(ctx, wall, seed)
	-- The accent furthest round the colour wheel from the wall.
	local best, bestD = P.accent[1], -1
	for _, c in P.accent do
		local d = hueDistance(c, wall or P.brick[1])
		if d > bestD then best, bestD = c, d end
	end
	ctx:box('Stoop', V(-2.2, 0, -1.4), V(2.2, 0.45, 0), P.trim, M.Concrete)
	ctx:box('StoopTop', V(-1.9, 0.45, -0.7), V(1.9, 0.9, 0), P.trim, M.Concrete)
	ctx:box('Door', V(-1.4, 0.9, -0.12), V(1.4, 5.6, 0), best, M.SmoothPlastic)
	for _, y in { 1.4, 3.5 } do ctx:box('DoorPanel', V(-1.0, y, -0.2), V(1.0, y + 1.6, -0.12), best:Lerp(Color3.new(0, 0, 0), 0.18), M.SmoothPlastic) end
	ctx:part('Knob', V(0.32, 0.32, 0.32), CFrame.new(1.0, 3.2, -0.3), P.yellow, M.Metal, Enum.PartType.Ball)
	ctx:box('DoorFrame', V(-1.8, 0.9, -0.3), V(-1.4, 5.6, 0), P.trim, M.SmoothPlastic)
	ctx:box('DoorFrame', V(1.4, 0.9, -0.3), V(1.8, 5.6, 0), P.trim, M.SmoothPlastic)
	ctx:box('DoorHead', V(-1.9, 5.6, -0.35), V(1.9, 6.05, 0), P.trim, M.SmoothPlastic)
	-- Striped awning, tilted out over the stoop.
	local awn = P.accent[(seed % #P.accent) + 1] == best and P.accent[((seed + 1) % #P.accent) + 1] or P.accent[(seed % #P.accent) + 1]
	for k = 0, 3 do
		local stripe = ctx:box('Awning', V(-2.2 + k * 1.1, -0.08, -1.6), V(-1.1 + k * 1.1, 0.08, 0), k % 2 == 0 and awn or P.white, M.Fabric)
		stripe.CFrame = ctx:world(CFrame.new(-1.65 + k * 1.1, 6.45, -0.75) * CFrame.Angles(math.rad(-22), 0, 0))
	end
	ctx:box('AwningValance', V(-2.2, 5.95, -1.62), V(2.2, 6.2, -1.42), awn, M.Fabric)
	-- Planter beside the stoop.
	ctx:box('Planter', V(2.4, 0, -0.9), V(3.5, 0.9, 0), P.woodDark, M.WoodPlanks)
	ctx:part('Shrub', V(1.3, 1.1, 1.0), CFrame.new(2.95, 1.25, -0.45), P.leaf[2], M.SmoothPlastic, Enum.PartType.Ball)
	for k = 0, 1 do ctx:part('Bloom', V(0.5, 0.5, 0.5), CFrame.new(2.7 + k * 0.5, 1.75, -0.6), P.flower[(seed + k) % #P.flower + 1], M.SmoothPlastic, Enum.PartType.Ball) end
end
local function acUnit(ctx)
	ctx:box('ACUnit', V(-1, 0, -1.2), V(1, 1.2, 0), C(198, 202, 196), M.Metal)
	ctx:box('ACGrille', V(-0.8, 0.2, -1.25), V(0.8, 1, -1.2), C(120, 126, 122), M.DiamondPlate)
end
-- Fire escape bolted to a wall; origin on the wall at platform-top height.
local function fireEscape(ctx)
	local f = ctx:group('FireEscape')
	f:box('Platform', V(-3.6, -0.25, -2.4), V(3.6, 0, 0), P.iron, M.DiamondPlate)
	f:box('TopRail', V(-3.6, 2.4, -2.4), V(3.6, 2.6, -2.2), P.iron, M.Metal)
	for _, x in { -3.6, 3.4 } do f:box('SideRail', V(x, 2.4, -2.2), V(x + 0.2, 2.6, 0), P.iron, M.Metal) end
	for k = 0, 6 do
		local x = -3.5 + k * 7 / 6
		f:box('Baluster', V(x - 0.06, 0, -2.36), V(x + 0.06, 2.4, -2.24), P.iron, M.Metal)
	end
	for _, x in { -3.5, 3.5 } do f:box('Baluster', V(x - 0.06, 0, -1.26), V(x + 0.06, 2.4, -1.14), P.iron, M.Metal) end
	for _, x in { -3.2, 3.2 } do f:bar('Bracket', V(x, -2, -0.09), V(x, -0.34, -2.1), 0.18, P.iron) end
	for _, x in { 1.8, 2.8 } do f:box('LadderRail', V(x - 0.08, -2.6, -2.36), V(x + 0.08, -0.25, -2.2), P.iron, M.Metal) end
	for y = -2.3, -0.6, 0.55 do f:box('Rung', V(1.88, y - 0.05, -2.32), V(2.72, y + 0.05, -2.24), P.iron, M.Metal) end
	return f
end
local function graffiti(ctx, value, color, w, h)
	local panel = ghost(ctx:box('GraffitiTag', V(-w / 2, 0, -0.05), V(w / 2, h, 0), P.white))
	local g = surface(panel, Enum.NormalId.Front, 40)
	line(g, 'Tag', value, color, FONT.tag, 0.05, 0.9, P.black, 3)
	return panel
end
local TAGS = { { 'BLOCK', P.magenta }, { 'COME UP', P.cyan }, { 'JUNIPER', P.yellow }, { 'NO DAYS OFF', P.orange }, { 'STAY UP', P.cap[1] } }
-- Windows, AC units and tags along every face, skipping the stretches reserved for storefronts and gates.
local function decorateFaces(ctx, faces, reserved, doorAvoid)
	local d = ctx:group('Facades')
	local function doorOK(f, a)
		for _, r in doorAvoid do
			if r.alongX == f.alongX and math.abs(r.at - f.at) < 0.5 and a + 3.6 > r.a and a - 3.6 < r.b then return false end
		end
		return true
	end
	local function blocked(f, a)
		for _, r in reserved do
			if r.alongX == f.alongX and math.abs(r.at - f.at) < 0.5 and a + 2 > r.a and a - 2 < r.b then return true end
		end
		return false
	end
	for _, f in faces do
		local len = f.b - f.a
		local n = math.floor(len / 8)
		for k = 0, n - 1 do
			local a = f.a + (len - n * 8) / 2 + k * 8 + 4
			if not blocked(f, a) then
				local h = hash(math.floor(a), math.floor(f.at))
				local base = f.y0 + (f.y0 == 0 and 2.6 or 1.6)
				if f.y1 - base >= 3.8 then
					if f.y0 == 0 and f.y1 == TIER_TOP[1] and h % 4 == 2 and doorOK(f, a) then
						local probe = f.alongX and V(a, 0, f.at - f.normal.Z * 2) or V(f.at - f.normal.X * 2, 0, a)
						door(d:at(faceFrame(f, a, 0)), facadeColor(probe.X, probe.Z), h)
					elseif f.y0 == 0 and h % 9 == 0 then
						local tag = TAGS[h % #TAGS + 1]
						graffiti(d:at(faceFrame(f, a, 1.2)), tag[1], tag[2], 7.2, 3.6)
					elseif f.y0 == 0 and f.y1 == TIER_TOP[1] and h % 6 == 1 then
						window(d:at(faceFrame(f, a, 3.6)), h % 4 == 1)
						fireEscape(d:at(faceFrame(f, a, 3)))
					elseif h % 7 == 3 and f.y0 > 0 then
						acUnit(d:at(faceFrame(f, a, base + 0.4)))
					else
						-- Flower boxes everywhere except street-level corridor walls, where lamps stand close.
						local corridor = not f.alongX and math.abs(f.at) == 20 and f.y0 == 0
						local flowers = h % 3 == 0 and not corridor and (f.y0 > 0 or doorOK(f, a))
						window(d:at(faceFrame(f, a, base)), h % 5 == 0, flowers and h or nil)
					end
				end
			end
		end
	end
	return d
end

---------------------------------------------------------------------------------------------- props
local function lamp(ctx, pos, facing)
	local m = ctx:at(CFrame.lookAt(pos, pos + facing)):group('StreetLamp')
	m:post('Base', 0.8, 0.9, V(0, 0, 0), P.iron)
	m:post('BaseRing', 0.55, 0.5, V(0, 0.9, 0), P.iron)
	m:post('Pole', 0.32, 10.6, V(0, 1.4, 0), P.iron)
	m:post('Collar', 0.42, 0.4, V(0, 8, 0), P.iron)
	m:box('Arm', V(-0.3, 11.6, -3.2), V(0.3, 12.2, 0.32), P.iron, M.Metal)
	m:bar('Brace', V(0, 9.9, -0.3), V(0, 11.62, -1.9), 0.26, P.iron)
	m:box('LampHood', V(-1.1, 11.2, -4.4), V(1.1, 11.6, -2.2), P.iron, M.Metal)
	m:box('LampHoodTop', V(-0.7, 11.6, -4), V(0.7, 11.95, -2.6), P.iron, M.Metal)
	local bulb = decor(m:box('Lamp', V(-0.85, 10.8, -4.15), V(0.85, 11.2, -2.45), C(255, 230, 170), M.Neon))
	light(bulb, C(255, 218, 160), 1, 20)
	return m
end
local function hydrant(ctx, pos)
	local h = ctx:group('FireHydrant')
	h:post('Foot', 0.75, 0.2, pos, P.iron)
	h:post('Barrel', 0.55, 1.9, pos + V(0, 0.2, 0), P.red)
	h:post('Collar', 0.68, 0.25, pos + V(0, 1.5, 0), P.red)
	h:blob('Dome', V(1.1, 0.8, 1.1), pos + V(0, 2.1, 0), P.red, M.Metal)
	h:post('Nut', 0.16, 0.3, pos + V(0, 2.45, 0), C(200, 190, 60))
	h:rod('Nozzles', 0.28, 1.7, CFrame.new(pos + V(0, 1.25, 0)), P.red)
	return h
end
local function bench(ctx, pos, facing)
	local b = ctx:at(CFrame.lookAt(pos, pos + facing)):group('Bench')
	for _, x in { -2.6, 2.6 } do
		b:box('Leg', V(x - 0.2, 0, -0.8), V(x + 0.2, 1.5, 0.8), P.iron, M.Metal)
		b:box('BackPost', V(x - 0.2, 1.5, 0.6), V(x + 0.2, 3.4, 0.8), P.iron, M.Metal)
	end
	for k = -1, 1 do b:box('Slat', V(-3.2, 1.5, k * 0.52 - 0.22), V(3.2, 1.72, k * 0.52 + 0.22), P.wood, M.WoodPlanks) end
	for k = 0, 1 do b:box('BackSlat', V(-3.2, 2.2 + k * 0.6, 0.8), V(3.2, 2.6 + k * 0.6, 1.0), P.wood, M.WoodPlanks) end
	return b
end
local function trashCan(ctx, pos)
	local t = ctx:group('TrashCan')
	t:post('Can', 0.9, 2.4, pos, C(70, 104, 84), M.Metal)
	t:post('Rim', 0.98, 0.2, pos + V(0, 2.4, 0), C(52, 80, 64), M.Metal)
	t:post('Lid', 0.8, 0.15, pos + V(0, 2.6, 0), C(52, 80, 64), M.Metal)
	return t
end
local function crate(ctx, cf, color)
	local c = ctx:at(cf):group('MilkCrate')
	c:box('CrateBase', V(-0.8, 0, -0.8), V(0.8, 0.15, 0.8), color, M.SmoothPlastic)
	for _, s in { { V(-0.8, 0.15, -0.8), V(0.8, 1.4, -0.65) }, { V(-0.8, 0.15, 0.65), V(0.8, 1.4, 0.8) }, { V(-0.8, 0.15, -0.65), V(-0.65, 1.4, 0.65) }, { V(0.65, 0.15, -0.65), V(0.8, 1.4, 0.65) } } do
		c:box('CrateSide', s[1], s[2], color, M.SmoothPlastic)
	end
	return c
end

-- Blocky trees: tapered trunk, two branch arms, and stacked leaf blocks that sit on each other face to face.
-- axis ('x' or 'z') keeps the branch arms along a narrow terrace step instead of across it.
local function tree(ctx, pos, seed, scale, axis)
	scale = scale or 1
	local r = Random.new(seed)
	local t = ctx:at(CFrame.new(pos) * CFrame.Angles(0, math.rad(r:NextInteger(0, 3) * 90 + r:NextNumber(-8, 8)), 0)):group('Tree')
	local s = scale
	t:box('RootFlare', V(-1.3 * s, 0, -1.3 * s), V(1.3 * s, 0.6 * s, 1.3 * s), P.bark, M.Wood)
	t:box('Trunk', V(-0.9 * s, 0.6 * s, -0.9 * s), V(0.9 * s, 4.4 * s, 0.9 * s), P.bark, M.Wood)
	t:box('TrunkUpper', V(-0.7 * s, 4.4 * s, -0.7 * s), V(0.7 * s, 7 * s, 0.7 * s), P.bark, M.Wood)
	-- Branch arms reach out of the trunk and carry the side clumps.
	local sides = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	local first = r:NextInteger(1, 4)
	local arms = { sides[first], sides[(first + 1) % 4 + 1] }
	if axis == 'none' then arms = {} -- tight spots next to walls: crown only
	elseif axis then arms = axis == 'x' and { sides[1], sides[2] } or { sides[3], sides[4] } end
	local top = 7 * s
	local crown = 5.2 * s + r:NextNumber(0, 1.2) * s
	local leaf = P.leaf
	studs(t:box('Crown', V(-crown / 2, top, -crown / 2), V(crown / 2, top + 4.2 * s, crown / 2), leaf[1], M.Plastic), true)
	studs(t:box('CrownTop', V(-crown / 3, top + 4.2 * s, -crown / 3), V(crown / 3, top + 6 * s, crown / 3), leaf[3], M.Plastic), true)
	for k, a in arms do
		local d = V(a[1], 0, a[2])
		local armY = (4.2 + k * 0.6) * s
		local reach = crown / 2 + 0.8 * s
		local inner, outer = d * 0.7 * s, d * reach
		t:box('Branch', V(math.min(inner.X, outer.X) - (a[1] == 0 and 0.35 * s or 0), armY, math.min(inner.Z, outer.Z) - (a[2] == 0 and 0.35 * s or 0)),
			V(math.max(inner.X, outer.X) + (a[1] == 0 and 0.35 * s or 0), armY + 0.7 * s, math.max(inner.Z, outer.Z) + (a[2] == 0 and 0.35 * s or 0)), P.bark, M.Wood)
		local c = 2.6 * s + r:NextNumber(0, 0.8) * s
		local centre = d * (reach + c / 2)
		studs(t:box('SideClump', V(centre.X - c / 2, armY + 0.7 * s, centre.Z - c / 2), V(centre.X + c / 2, armY + 0.7 * s + c * 0.8, centre.Z + c / 2), leaf[2], M.Plastic), true)
	end
	return t
end
local function bush(ctx, pos, seed)
	local r = Random.new(seed)
	local b = ctx:group('Bush')
	local w = 2.4 + r:NextNumber(0, 1)
	studs(b:box('Bush', pos + V(-w / 2, 0, -w / 2), pos + V(w / 2, 1.8, w / 2), P.leaf[(seed % 3) + 1], M.Plastic), true)
	studs(b:box('BushTop', pos + V(-w / 3, 1.8, -w / 3), pos + V(w / 3, 2.6, w / 3), P.leaf[((seed + 1) % 3) + 1], M.Plastic), true)
	return b
end
local function waterTower(ctx, pos)
	local w = ctx:group('WaterTower')
	for _, x in { -1.6, 1.6 } do for _, z in { -1.6, 1.6 } do w:box('Leg', pos + V(x - 0.25, 0, z - 0.25), pos + V(x + 0.25, 4, z + 0.25), P.iron, M.Metal) end end
	w:box('Deck', pos + V(-2.4, 4, -2.4), pos + V(2.4, 4.4, 2.4), P.woodDark, M.WoodPlanks)
	w:post('Tank', 2.2, 4.6, pos + V(0, 4.4, 0), P.wood, M.WoodPlanks)
	for _, y in { 5.3, 7.1, 8.5 } do w:post('Hoop', 2.26, 0.22, pos + V(0, y, 0), P.iron) end
	w:wedge('RoofL', V(4.6, 1.4, 2.3), CFrame.new(pos + V(0, 9.7, -1.15)) * CFrame.Angles(0, math.pi, 0), P.iron, M.Metal)
	w:wedge('RoofR', V(4.6, 1.4, 2.3), CFrame.new(pos + V(0, 9.7, 1.15)), P.iron, M.Metal)
	return w
end

---------------------------------------------------------------------------------------------- lobby: Drip Stand
-- Stand frame: origin at front-centre on the floor, -Z faces the crowd, rows climb toward +Z.
-- The shop building behind it runs back to the terrace wall, so nothing is left as a gap.
local STAND = { spacing = 6, rowDepth = 7, rise = 3.2, halfWidth = 17, scale = 0.86 }
V2.Stand = STAND
local function marquee(ctx, x0, y0, x1, y1, z)
	local n = 0
	for x = x0, x1 + 0.01, 1.2 do
		for _, y in { y0, y1 } do
			n += 1
			decor(ctx:box('MarqueeBulb', V(x - 0.18, y - 0.18, z - 0.25), V(x + 0.18, y + 0.18, z), n % 2 == 0 and C(255, 236, 160) or C(255, 196, 90), M.Neon))
		end
	end
	for y = y0 + 1.2, y1 - 0.6, 1.2 do
		for _, x in { x0, x1 } do decor(ctx:box('MarqueeBulb', V(x - 0.18, y - 0.18, z - 0.25), V(x + 0.18, y + 0.18, z), C(255, 236, 160), M.Neon)) end
	end
end
local function buildDripStand(ctx, skins, art, building)
	local st = ctx:group('DripStand')
	local hw, rise = STAND.halfWidth, STAND.rise
	local backZ = 3 * STAND.rowDepth
	for row = 1, 2 do
		local top, front = row * rise, row * STAND.rowDepth
		studs(st:box('Tier', V(-hw, top - rise, front), V(hw, top, backZ), row == 1 and C(206, 210, 218) or C(190, 196, 206), M.Plastic), true)
		st:box('TierNosing', V(-hw, top, front), V(hw, top + 0.12, front + 0.6), P.yellow, M.SmoothPlastic)
	end
	-- Side stairs (0.8 risers) with iron railings like a brownstone stoop.
	local steps = math.floor(rise / 0.8 + 0.5) - 1
	for _, side in { -1, 1 } do
		for row = 1, 2 do
			local front, base = row * STAND.rowDepth, (row - 1) * rise
			for step = 1, steps do
				local z0 = front - (steps + 1 - step) * 1.4
				studs(st:box('Step', V(side * (hw - 3), base, z0), V(side * hw, base + step * 0.8, z0 + 1.4), C(214, 218, 226), M.Plastic))
			end
			local z0 = front - steps * 1.4
			local a, b = V(side * (hw + 0.25), base + 3.6, z0 + 0.2), V(side * (hw + 0.25), base + rise + 3.6, front + 0.2)
			st:bar('StoopRail', a, b, 0.2, P.iron)
			for _, t in { 0, 0.5, 1 } do
				local p = a:Lerp(b, t)
				local foot = t == 1 and base + rise or base
				st:box('Baluster', V(p.X - 0.1, foot, p.Z - 0.1), V(p.X + 0.1, p.Y, p.Z + 0.1), P.iron, M.Metal)
			end
		end
	end
	-- The shop: a brownstone that fills the lot behind the stand (bounds handed in by the caller).
	local B = building
	local H = 20
	studs(st:box('ShopBuilding', V(B.x0, 0, backZ), V(B.x1, H, B.z1), C(150, 82, 62), M.Plastic), true)
	-- Cornice on the two show faces, a parapet on the party walls, tar roof inside.
	st:box('Cornice', V(B.x0, H, backZ - 0.6), V(B.x1 + 0.6, H + 1, backZ + 0.8), P.trim, M.SmoothPlastic)
	st:box('Cornice', V(B.x1 - 0.8, H, backZ + 0.8), V(B.x1 + 0.6, H + 1, B.z1), P.trim, M.SmoothPlastic)
	studs(st:box('Parapet', V(B.x0, H, B.z1 - 0.8), V(B.x1 - 0.8, H + 1, B.z1), C(150, 82, 62), M.Plastic))
	studs(st:box('Parapet', V(B.x0, H, backZ + 0.8), V(B.x0 + 0.8, H + 1, B.z1 - 0.8), C(150, 82, 62), M.Plastic))
	studs(st:box('Roof', V(B.x0 + 0.8, H, backZ + 0.8), V(B.x1 - 0.8, H + 0.3, B.z1 - 0.8), C(78, 80, 88), M.Plastic))
	st:box('StringCourse', V(B.x0, 7.6, backZ - 0.3), V(B.x1 + 0.3, 8.1, B.z1 - 0.2), P.trim, M.SmoothPlastic)
	local sign = st:box('SignBoard', V(-11, 14.2, backZ - 0.3), V(11, 18.6, backZ), P.black, M.SmoothPlastic)
	local sg = surface(sign, Enum.NormalId.Front)
	line(sg, 'Name', 'DRIP SHOP', P.yellow, FONT.loud, 0.06, 0.6, C(120, 40, 20), 3)
	line(sg, 'Tag', '15 LOOKS • WALK UP + PRESS E', P.white, FONT.body, 0.7, 0.24)
	marquee(st, -11.8, 13.6, 11.8, 19.2, backZ)
	-- Street-facing side: shop door, two floors of windows, a fire escape and a rooftop water tower.
	local side = st:at(CFrame.lookAt(V(B.x1, 0, 0), V(B.x1 + 1, 0, 0)))
	for k, z in { backZ + 4, backZ + 9, backZ + 14, backZ + 19 } do
		if k > 1 then window(side:at(CFrame.new(z, 2.6, 0)), k == 3) end
		window(side:at(CFrame.new(z, 10, 0)), k % 2 == 0)
		window(side:at(CFrame.new(z, 15.4, 0)), false)
	end
	side:box('SideDoor', V(backZ + 2.6, 0, -0.15), V(backZ + 5.4, 5.8, 0), P.woodDark, M.Wood)
	side:box('SideDoorHead', V(backZ + 2.2, 5.8, -0.4), V(backZ + 5.8, 6.2, 0), P.trim, M.SmoothPlastic)
	fireEscape(side:at(CFrame.new(backZ + 14, 9.4, 0)))
	-- Neon blade sign on the street corner: dark board, lime + magenta neon frame, stacked letters.
	local blade = side:at(CFrame.new(backZ + 2.4, 0, 0))
	local board = blade:box('BladeSign', V(-0.25, 9.5, -2.6), V(0.25, 17.5, -0.4), C(26, 26, 30), M.SmoothPlastic)
	for _, e in { { V(-0.3, 17.5, -2.75), V(0.3, 17.8, -0.4) }, { V(-0.3, 9.2, -2.75), V(0.3, 9.5, -0.4) }, { V(-0.3, 9.5, -2.75), V(0.3, 17.5, -2.6) } } do
		decor(blade:box('BladeNeon', e[1], e[2], C(184, 255, 46), M.Neon))
	end
	decor(blade:box('BladeNeonInner', V(-0.28, 9.8, -2.45), V(0.28, 10.0, -0.55), C(255, 46, 154), M.Neon))
	blade:box('BladeBracket', V(-0.15, 16.2, -0.4), V(0.15, 16.6, 0), C(40, 40, 46), M.Metal)
	blade:box('BladeBracket', V(-0.15, 10.4, -0.4), V(0.15, 10.8, 0), C(40, 40, 46), M.Metal)
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local g = surface(board, face, 40)
		line(g, 'Letters', 'D\nR\nI\nP', C(255, 46, 154), FONT.loud, 0.04, 0.92, C(255, 255, 255), 2)
	end
	waterTower(st, V((B.x0 + B.x1) / 2 - 6, H + 0.3, (backZ + B.z1) / 2))
	acUnit(st:at(CFrame.lookAt(V(B.x1 - 6, H + 0.3, backZ + 4), V(B.x1 - 6, H + 0.3, backZ + 3))))
	st:box('RoofHatch', V(B.x1 - 7, H + 0.3, B.z1 - 6), V(B.x1 - 4, H + 1.3, B.z1 - 3), P.steel, M.Metal)
	-- Three rows of five looks on cyan pads, cheapest in front, ascending left to right from the crowd.
	local morphs = st:group('Morphs', 'Folder')
	local accent = { P.cyan, P.purple, P.yellow }
	for row = 0, 2 do
		local floor, z = row * rise, row * STAND.rowDepth + 4.6
		for col = 1, 5 do
			local s = skins.List[row * 5 + col]
			local x = 3 * STAND.spacing - col * STAND.spacing
			local stand = morphs:group('Skin_' .. s.Id)
			studs(stand:box('Plinth', V(x - 2.1, floor, z - 1.7), V(x + 2.1, floor + 0.5, z + 1.7), C(244, 244, 248), M.Plastic))
			decor(stand:box('Pad', V(x - 1.6, floor + 0.5, z - 1.2), V(x + 1.6, floor + 0.6, z + 1.2), accent[row + 1], M.Neon))
			art.mannequin(stand.parent, stand:world(CFrame.new(x, floor + 0.6, z)), s, STAND.scale)
			local label = billboard(stand, V(x, floor + 0.6 + 5.6 * STAND.scale + 0.9, z), 4.4, 1.35, {
				{ 'Title', s.Name, P.yellow, FONT.title, 0, 0.52 },
				{ 'Detail', (s.Required == 0 and 'FREE' or compact(s.Required)) .. ' • +' .. s.Gain .. '/sec', P.white, FONT.body, 0.54, 0.42 },
			})
			label.WorldLabel.MaxDistance = 60
			ghost(stand:box('Interact', V(x - 1, floor, z - 4.2), V(x + 1, floor + 0.1, z - 2.2), P.white))
		end
	end
	return st
end


-- Landmark: a giant red glove with a spinning cyan ring, on top of whatever ctx stands for.
local function giantGlove(ctx)
	local glove = ctx:group('GiantGlove')
	glove:post('Cuff', 1.7, 1.8, V(0, 0, 0), C(255, 239, 210), M.SmoothPlastic)
	glove:post('CuffBand', 1.75, 0.45, V(0, 1.35, 0), P.red, M.SmoothPlastic)
	glove:blob('Mitt', V(4.8, 5.4, 5), V(0, 4.3, -0.2), P.red, M.SmoothPlastic)
	glove:blob('Knuckles', V(4.2, 3, 2.4), V(0, 5.6, -1.9), P.red, M.SmoothPlastic)
	glove:blob('Thumb', V(1.7, 3.2, 1.9), V(2.05, 3.5, -1.2), C(214, 40, 52), M.SmoothPlastic)
	glove:blob('Shine', V(1.1, 1.6, 0.5), V(-1, 5.5, -2.5), C(255, 150, 160), M.SmoothPlastic)
	for k = 0, 3 do glove:bar('Lace', V(-0.6, 2.4 + k * 0.5, 2.1), V(0.6, 2.6 + k * 0.5, 2.15), 0.18, P.white, M.Fabric) end
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		glove:part('GloveRing', V(0.9, 0.22, 0.3), CFrame.new(math.cos(a) * 2.3, 0.9, math.sin(a) * 2.3) * CFrame.Angles(0, -a + math.pi / 2, 0), C(34, 229, 255), M.Neon)
	end
	glove.parent:SetAttribute('Spin', 30)
	glove.parent.WorldPivot = glove:world(CFrame.new(0, 0, 0))
	glove.parent:AddTag('HoodMotion')
	return glove
end

---------------------------------------------------------------------------------------------- lobby: crew, stash, portal, boards, statue
local function pet(ctx, kind, cf)
	local p = ctx:at(cf):group(kind)
	if kind == 'BodegaCat' then
		local fur, dark = C(238, 158, 70), C(196, 112, 42)
		p:box('Body', V(-0.7, 0.6, -1.1), V(0.7, 1.7, 1.1), fur, M.SmoothPlastic)
		p:box('Head', V(-0.65, 1.2, -2.1), V(0.65, 2.4, -1.1), fur, M.SmoothPlastic)
		for _, x in { -0.4, 0.4 } do p:wedge('Ear', V(0.4, 0.5, 0.4), CFrame.new(x, 2.65, -1.6) * CFrame.Angles(0, math.pi, 0), dark, M.SmoothPlastic) end
		for _, x in { -0.3, 0.3 } do p:box('Eye', V(x - 0.12, 1.85, -2.14), V(x + 0.12, 2.1, -2.1), P.black, M.SmoothPlastic) end
		p:box('Nose', V(-0.1, 1.6, -2.16), V(0.1, 1.72, -2.1), C(240, 120, 140), M.SmoothPlastic)
		for _, x in { -0.45, 0.45 } do for _, z in { -0.8, 0.8 } do p:box('Leg', V(x - 0.2, 0, z - 0.2), V(x + 0.2, 0.6, z + 0.2), fur, M.SmoothPlastic) end end
		for k = -1, 1 do p:box('Stripe', V(-0.72, 1.2, k * 0.6 - 0.12), V(0.72, 1.72, k * 0.6 + 0.12), dark, M.SmoothPlastic) end
		p:bar('Tail', V(0, 1.4, 1.1), V(0, 2.6, 1.9), 0.25, fur, M.SmoothPlastic)
	elseif kind == 'StoopPigeon' then
		p:blob('Body', V(1.2, 1.2, 1.8), V(0, 1.1, 0), C(150, 160, 176), M.SmoothPlastic)
		p:blob('Head', V(0.75, 0.75, 0.75), V(0, 1.95, -0.75), C(120, 132, 150), M.SmoothPlastic)
		p:blob('Neck', V(0.8, 0.5, 0.6), V(0, 1.6, -0.55), C(96, 160, 140), M.SmoothPlastic)
		p:wedge('Beak', V(0.18, 0.18, 0.35), CFrame.new(0, 1.9, -1.25), C(240, 180, 80), M.SmoothPlastic)
		for _, x in { -0.18, 0.18 } do p:box('Eye', V(x - 0.07, 2.02, -1.13), V(x + 0.07, 2.14, -1.08), C(230, 110, 40), M.SmoothPlastic) end
		for _, x in { -0.55, 0.55 } do p:box('Wing', V(x - 0.12, 0.9, -0.5), V(x + 0.12, 1.5, 0.8), C(110, 120, 138), M.SmoothPlastic) end
		for _, x in { -0.25, 0.25 } do p:box('Foot', V(x - 0.08, 0, -0.1), V(x + 0.08, 0.55, 0.1), C(220, 120, 110), M.SmoothPlastic) end
	elseif kind == 'DeliveryPup' then
		local fur = C(212, 176, 128)
		p:box('Body', V(-0.75, 0.7, -0.9), V(0.75, 1.8, 1.2), fur, M.SmoothPlastic)
		p:box('Head', V(-0.7, 1.4, -2.0), V(0.7, 2.6, -0.9), fur, M.SmoothPlastic)
		p:box('Snout', V(-0.35, 1.5, -2.5), V(0.35, 2.0, -2.0), C(238, 214, 178), M.SmoothPlastic)
		p:box('Nose', V(-0.15, 1.8, -2.56), V(0.15, 2.0, -2.5), P.black, M.SmoothPlastic)
		for _, x in { -0.8, 0.8 } do p:box('Ear', V(x - 0.15, 1.5, -1.7), V(x + 0.15, 2.4, -1.2), C(150, 106, 70), M.SmoothPlastic) end
		for _, x in { -0.3, 0.3 } do p:box('Eye', V(x - 0.1, 2.05, -2.04), V(x + 0.1, 2.27, -2.0), P.black, M.SmoothPlastic) end
		p:box('Cap', V(-0.72, 2.6, -2.0), V(0.72, 2.95, -0.9), P.red, M.Fabric)
		p:box('CapBrim', V(-0.6, 2.6, -2.5), V(0.6, 2.7, -2.0), P.red, M.Fabric)
		for _, x in { -0.45, 0.45 } do for _, z in { -0.6, 0.9 } do p:box('Leg', V(x - 0.2, 0, z - 0.2), V(x + 0.2, 0.7, z + 0.2), fur, M.SmoothPlastic) end end
		p:bar('Tail', V(0, 1.6, 1.2), V(0, 2.3, 1.7), 0.22, fur, M.SmoothPlastic)
	else -- CourtCaptain: a basketball with shades and a sweatband
		p:blob('Ball', V(2.2, 2.2, 2.2), V(0, 1.1, 0), P.orange, M.Rubber)
		p:rod('SeamH', 1.11, 0.08, CFrame.new(0, 1.1, 0) * CFrame.Angles(0, 0, math.pi / 2), P.black, M.Rubber)
		p:rod('SeamV', 1.11, 0.08, CFrame.new(0, 1.1, 0), P.black, M.Rubber)
		p:box('Shades', V(-0.75, 1.35, -1.12), V(0.75, 1.65, -0.95), P.black, M.SmoothPlastic)
		p:rod('Sweatband', 1.0, 0.3, CFrame.new(0, 1.85, 0) * CFrame.Angles(0, 0, math.pi / 2), P.white, M.Fabric)
	end
	return p
end
local function buildCrewStand(ctx, crew)
	local cs = ctx:group('BodegaBox')
	-- Counter with the box on top, four crew members on pedestals in a gentle arc in front.
	cs:box('Counter', V(-4, 0, -1.6), V(4, 3, 1.6), P.wood, M.WoodPlanks)
	cs:box('CounterTop', V(-4.3, 3, -1.9), V(4.3, 3.3, 1.9), P.trim, M.SmoothPlastic)
	cs:box('Box', V(-1.8, 3.3, -1.4), V(1.8, 6.1, 1.4), P.cardboard, M.Cardboard)
	cs:box('BoxFlapL', V(-1.8, 6.1, -1.4), V(-0.1, 6.3, 1.4), P.cardboard:Lerp(P.black, 0.1), M.Cardboard)
	cs:box('BoxFlapR', V(0.1, 6.1, -1.4), V(1.8, 6.3, 1.4), P.cardboard:Lerp(P.black, 0.1), M.Cardboard)
	local tag = cs:box('BoxLabel', V(-1.5, 4, -1.45), V(1.5, 5.6, -1.4), P.white, M.SmoothPlastic)
	local g = surface(tag, Enum.NormalId.Front)
	line(g, 'Name', 'BODEGA BOX', P.red, FONT.loud, 0.1, 0.8)
	-- Bodega-style striped canopy on two back posts.
	for _, x in { -4.6, 4.6 } do cs:box('CanopyPost', V(x - 0.2, 0, 1.6), V(x + 0.2, 7.6, 2.0), P.iron, M.Metal) end
	for k = 0, 7 do
		cs:box('Canopy', V(-5 + k * 1.25, 7.6, -2.8), V(-3.75 + k * 1.25, 7.9, 2.0), k % 2 == 0 and C(46, 140, 90) or P.white, M.Fabric)
	end
	cs:box('CanopyValance', V(-5, 7.1, -2.8), V(5, 7.6, -2.6), C(46, 140, 90), M.Fabric)
	local box = crew.Boxes.BlockBox
	billboard(cs, V(0, 10, 0), 8, 2, { { 'Title', string.upper(box.Name), P.yellow, FONT.loud, 0, 0.55 }, { 'Detail', box.CashCost .. ' CASH • CREW PETS', P.white, FONT.body, 0.56, 0.4 } })
	local kinds = { 'BodegaCat', 'StoopPigeon', 'DeliveryPup', 'CourtCaptain' }
	local rarity = { P.white, P.cyan, P.purple, P.yellow }
	for k, o in box.Outcomes do
		local x = -6.75 + (k - 1) * 4.5
		local zc = -5 + math.abs(k - 2.5) * 0.8
		cs:post('Pedestal', 1.4, 1, V(x, 0, zc), C(240, 240, 244), M.SmoothPlastic)
		decor(cs:post('PedestalGlow', 1.45, 0.12, V(x, 1, zc), rarity[k], M.Neon))
		pet(cs, kinds[k], CFrame.new(x, 1.12, zc))
		local member = crew.Members[o.CrewId]
		billboard(cs, V(x, 5, zc), 3.8, 1.2, { { 'Title', member.Name, rarity[k], FONT.title, 0, 0.55 }, { 'Detail', member.Rarity .. ' ' .. o.Percent .. '%', P.white, FONT.body, 0.56, 0.4 } })
	end
	return cs
end
local function buildStash(ctx)
	local s = ctx:group('FreeStash')
	s:box('Safe', V(-2, 0, -1.8), V(2, 3.8, 1.8), C(54, 60, 70), M.Metal)
	s:box('SafeDoor', V(-1.7, 0.3, -1.95), V(1.7, 3.5, -1.8), C(72, 80, 92), M.Metal)
	s:rod('Dial', 0.55, 0.2, CFrame.new(0.6, 2.2, -2.05) * CFrame.Angles(0, math.pi / 2, 0), P.yellow, M.Metal)
	s:box('Handle', V(-1.2, 1.5, -2.2), V(-0.9, 2.6, -1.95), P.yellow, M.Metal)
	for k = 0, 2 do s:box('GoldBar', V(-1.6 + k * 1.1, 3.8, -0.6), V(-0.7 + k * 1.1, 4.3, 0.6), P.yellow, M.Foil) end
	s:box('CashStack', V(-0.9, 4.3, -0.5), V(0.9, 4.7, 0.5), C(90, 170, 90), M.Fabric)
	billboard(s, V(0, 6.4, 0), 6.5, 1.9, { { 'Title', 'FREE STASH', P.yellow, FONT.loud, 0, 0.56 }, { 'Detail', 'CLAIM EVERY 15 MIN', P.white, FONT.body, 0.58, 0.38 } })
	return s
end
local function buildStatue(ctx, skin, art)
	local s = ctx:group('KingpinStatue')
	s:post('Pedestal', 3.4, 1.6, V(0, 0, 0), C(236, 236, 240), M.Marble)
	decor(s:post('PedestalGlow', 3.5, 0.2, V(0, 1.6, 0), P.yellow, M.Neon))
	s:post('PedestalTop', 3.0, 0.3, V(0, 1.8, 0), C(236, 236, 240), M.Marble)
	art.mannequin(s.parent, s:world(CFrame.new(0, 2.1, 0) * CFrame.Angles(0, math.pi, 0)), skin, 2.2)
	billboard(s, V(0, 19.6, 0), 10, 2.6, { { 'Title', 'KINGPIN', P.yellow, FONT.loud, 0, 0.56 }, { 'Detail', 'TOP LOOK • ' .. compact(skin.Required) .. ' POWER', P.white, FONT.body, 0.58, 0.38 } })
	return s
end

-- Storefront set into a terrace face (face frame: x along the wall, -Z out of the wall, y from the floor).
local function storefront(ctx, name, signText, awningA, awningB)
	local s = ctx:group(name)
	s:box('Door', V(-1.6, 0, -0.15), V(1.6, 6.2, 0), P.woodDark, M.Wood)
	s:box('DoorFrame', V(-2, 6.2, -0.35), V(2, 6.6, 0), P.trim, M.SmoothPlastic)
	for _, x in { -2, 1.6 } do s:box('DoorJamb', V(x, 0, -0.35), V(x + 0.4, 6.2, 0), P.trim, M.SmoothPlastic) end
	for _, side in { -1, 1 } do
		local cx = side * 5
		s:box('Window', V(cx - 2.6, 1.6, -0.12), V(cx + 2.6, 5.6, 0), P.glassLit, M.Glass)
		s:box('Sill', V(cx - 2.9, 1.2, -0.6), V(cx + 2.9, 1.6, 0), P.trim, M.SmoothPlastic)
		s:box('WindowHead', V(cx - 2.9, 5.6, -0.3), V(cx + 2.9, 6, 0), P.trim, M.SmoothPlastic)
	end
	local sign = s:box('Sign', V(-8, 6.6, -0.3), V(8, 7.8, 0), P.black, M.SmoothPlastic)
	local g = surface(sign, Enum.NormalId.Front)
	line(g, 'Name', signText, P.yellow, FONT.loud, 0.06, 0.88)
	for k = 0, 7 do
		local stripe = s:box('Awning', V(-8 + k * 2, -0.08, -2.4), V(-6 + k * 2, 0.08, 0), k % 2 == 0 and awningA or awningB, M.Fabric)
		stripe.CFrame = ctx:world(CFrame.new(-7 + k * 2, 6.3, -1.1) * CFrame.Angles(math.rad(-18), 0, 0))
	end
	return s
end

---------------------------------------------------------------------------------------------- stage gates
-- Gate i across the street (lighting_and_gates.md, "Stage gate spec"). Gate frame: origin at the street
-- centre on the floor, +Z toward the approaching player. Clients make the barrier block you until your
-- Power reaches the number and run the pass feedback (HoodClient/Stages); the server records clears and
-- pays rewards (StageService). About 40 parts per gate.
local function gateGui(part, face, ppS, maxDistance)
	local g = surface(part, face, ppS)
	pcall(function() g.MaxDistance = maxDistance end)
	return g
end
local function padlock(ctx, y)
	-- Parts are all named Lock so clients can hide them once the gate opens for them.
	local gold, dark = C(255, 214, 60), C(150, 104, 20)
	decor(ctx:box('Lock', V(-1.7, y, -0.7), V(1.7, y + 2.8, 0.7), gold, M.SmoothPlastic))
	for _, x in { -1.15, 0.65 } do decor(ctx:box('Lock', V(x, y + 2.8, -0.3), V(x + 0.5, y + 4.3, 0.3), P.chain, M.Metal)) end
	decor(ctx:box('Lock', V(-1.15, y + 4.3, -0.3), V(1.15, y + 4.8, 0.3), P.chain, M.Metal))
	for _, z in { -0.75, 0.7 } do
		decor(ctx:box('Lock', V(-0.3, y + 0.6, z), V(0.3, y + 1.7, z + 0.05), dark, M.SmoothPlastic))
		decor(ctx:part('Lock', V(0.05, 0.8, 0.8), CFrame.new(0, y + 1.8, z + 0.025) * CFrame.Angles(0, math.pi / 2, math.pi / 2), dark, M.SmoothPlastic, Enum.PartType.Cylinder))
	end
end
local function chevron(ctx, z, color, size)
	for _, side in { -1, 1 } do
		local tip, tail = V(0, 0.06, z - size * 0.45), V(side * size * 0.55, 0.06, z + size * 0.25)
		local c = decor(ctx:part('Chevron', V(size * 0.16, 0.1, (tail - tip).Magnitude + size * 0.16), CFrame.lookAt((tip + tail) / 2, tail), color, M.Neon))
		c.CastShadow = false
	end
end
local function buildGate(ctx, i, wall, padSide)
	local base, dark, lite = STAGE[i][1], STAGE[i][2], STAGE[i][3]
	local last = i == 10
	local z = stageZ(i)
	local g, model = ctx:at(CFrame.new(0, 0, z)):group('StageGate' .. i)
	local frame = last and P.ink or base
	local trim = last and C(255, 200, 40) or P.white
	-- Pillars: 4x16x4 studded blocks with a white base band and a neon strip framing the opening.
	local pillars = {}
	for _, sx in { -1, 1 } do
		local pillar = studs(g:box('Pillar', V(sx * 16, 0, -2), V(sx * 20, 16, 2), frame, M.Plastic), true)
		table.insert(pillars, pillar)
		g:box('PillarBand', V(sx * 15.8, 0, -2.2), V(sx * 19.9, 1.2, 2.2), trim, M.SmoothPlastic)
		decor(g:box('PillarNeon', V(sx * 15.7, 2, -0.6), V(sx * 16, 14, 0.6), lite, M.Neon))
		local glow = Instance.new('SurfaceLight')
		glow.Face = sx < 0 and Enum.NormalId.Right or Enum.NormalId.Left
		glow.Color, glow.Brightness, glow.Range, glow.Angle, glow.Shadows = lite, 1.5, 12, 90, false
		glow.Parent = pillar
		-- Sparkles drifting off the pillar tops.
		local a = Instance.new('Attachment')
		a.Position = V(0, 8.2, 0)
		a.Parent = pillar
		local e = Instance.new('ParticleEmitter')
		e.Name = 'PillarSparkles'
		e.Texture = 'rbxasset://textures/particles/sparkles_main.dds'
		e:SetAttribute('PreviewTexture', 'sparkle')
		e.Rate, e.Lifetime, e.Speed = 3, NumberRange.new(1.2, 1.8), NumberRange.new(1, 2)
		e.Size = NumberSequence.new(0.5, 0)
		e.Color = ColorSequence.new(lite, P.white)
		e.LightEmission, e.LightInfluence = 1, 0
		e.SpreadAngle = Vector2.new(40, 40)
		e.Parent = a
	end
	-- Header beam: 40 x 6 with a cap, a row of marquee bulbs under its front edge.
	local header = studs(g:box('Header', V(-20, 16, -1.5), V(20, 22, 1.5), last and P.ink or dark, M.Plastic), true)
	g:box('HeaderCap', V(-20, 22, -1.9), V(20, 22.8, 1.9), trim, M.SmoothPlastic)
	for k = 0, 15 do
		local bulb = decor(g:part('MarqueeBulb', V(0.5, 0.5, 0.5), CFrame.new(-15 + k * 2, 15.75, 1.6), k % 2 == 0 and C(255, 236, 160) or lite, M.Neon, Enum.PartType.Ball))
		bulb.CastShadow = false
	end
	-- The number to beat, readable three gates away; the stage name on the back face.
	local front = gateGui(header, Enum.NormalId.Back, 25, 150)
	local need = line(front, 'Need', '💪 ' .. compact(wall.RequiredRep), P.white, FONT.loud, 0.04, 0.64, P.ink, 6)
	line(front, 'Unit', last and 'POWER TO WIN THE BLOCK' or 'POWER', last and C(255, 220, 90) or lite, FONT.title, 0.68, 0.28, P.ink, 3)
	if last then
		local grad = Instance.new('UIGradient')
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, C(255, 90, 90)), ColorSequenceKeypoint.new(0.25, C(255, 220, 60)), ColorSequenceKeypoint.new(0.5, C(90, 255, 140)),
			ColorSequenceKeypoint.new(0.75, C(80, 180, 255)), ColorSequenceKeypoint.new(1, C(220, 110, 255)),
		})
		grad.Parent = need
	end
	local back = gateGui(header, Enum.NormalId.Front, 25, 60)
	line(back, 'Name', 'STAGE ' .. i .. ' • ' .. string.upper(wall.Name), P.white, FONT.title, 0.2, 0.6, P.ink, 3)
	-- Stage badge: a disc crowning the header, poking above the rooftops as a landmark.
	g:part('BadgeRim', V(1, 9, 9), CFrame.new(0, 27.3, 0) * CFrame.Angles(0, math.pi / 2, 0), last and C(255, 200, 40) or dark, M.SmoothPlastic, Enum.PartType.Cylinder)
	g:part('BadgeFace', V(1.4, 7.6, 7.6), CFrame.new(0, 27.3, 0) * CFrame.Angles(0, math.pi / 2, 0), P.white, M.SmoothPlastic, Enum.PartType.Cylinder)
	for _, side in { 1, -1 } do
		local label = ghost(g:box('BadgeLabel', V(-3.5, 23.8, side * 0.75), V(3.5, 30.8, side * 0.8), P.white))
		local bg = gateGui(label, side > 0 and Enum.NormalId.Back or Enum.NormalId.Front, 25, 150)
		line(bg, 'Word', last and 'FINAL' or 'STAGE', last and C(200, 140, 10) or dark, FONT.loud, 0.12, 0.2, P.white, 2)
		line(bg, 'Number', tostring(i), last and C(200, 140, 10) or dark, FONT.loud, 0.3, 0.6, P.white, 4)
	end
	-- The barrier: a force-field sheet the client makes solid while you're short, with a padlock, a
	-- per-player status line and a progress bar on both faces.
	local barrier = g:box('Barrier', V(-15.7, 0, -0.2), V(15.7, 16, 0.2), lite, M.ForceField)
	barrier.Transparency = 0.45
	barrier.CastShadow = false
	for _, face in { Enum.NormalId.Back, Enum.NormalId.Front } do
		local bg = gateGui(barrier, face, 20, 70)
		line(bg, 'Status', 'NEED 💪 ' .. compact(wall.RequiredRep), P.white, FONT.loud, 0.47, 0.13, P.ink, 4)
		-- Progress bar as three siblings (track, fill, count) so nothing depends on nesting; clients
		-- resize Fill to Power / requirement.
		local function frame(name, color, transparency, z)
			local f = Instance.new('Frame')
			f.Name = name
			f.Position = UDim2.fromScale(0.19, 0.66)
			f.Size = UDim2.fromScale(0.62, 0.09)
			f.BackgroundColor3 = color
			f.BackgroundTransparency = transparency
			f.BorderSizePixel = 0
			f.ZIndex = z
			local corner = Instance.new('UICorner')
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = f
			f.Parent = bg
			return f
		end
		frame('Bar', P.ink, 0.2, 1)
		frame('Fill', lite, 0, 2).Size = UDim2.fromScale(0, 0.09)
		local count = line(bg, 'Count', '0 / ' .. compact(wall.RequiredRep), P.white, FONT.title, 0.66, 0.09, P.ink, 2)
		count.Position = UDim2.fromScale(0.19, 0.665)
		count.Size = UDim2.fromScale(0.62, 0.08)
		count.ZIndex = 3
	end
	padlock(g, 9.6)
	-- Laser lines across the opening, with neon nubs where they leave the pillars.
	for _, y in { 3, 6.5, 10, 13.5 } do
		local a0, a1 = Instance.new('Attachment'), Instance.new('Attachment')
		a0.Name, a1.Name = 'LaserL', 'LaserR'
		a0.Parent, a1.Parent = pillars[1], pillars[2]
		a0.Position = pillars[1].CFrame:PointToObjectSpace(g:world(CFrame.new(-15.6, y, 0.6)).Position)
		a1.Position = pillars[2].CFrame:PointToObjectSpace(g:world(CFrame.new(15.6, y, 0.6)).Position)
		local beam = Instance.new('Beam')
		beam.Name = 'Laser'
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, lite), ColorSequenceKeypoint.new(0.5, P.white), ColorSequenceKeypoint.new(1, lite) })
		beam.Width0, beam.Width1 = 0.35, 0.35
		beam.LightEmission, beam.LightInfluence = 1, 0
		beam.FaceCamera = true
		beam.Transparency = NumberSequence.new(0.15)
		beam.Parent = barrier
		for _, x in { -15.6, 15.6 } do decor(g:part('LaserNub', V(0.8, 0.8, 0.8), CFrame.new(x, y, 0.6), lite, M.Neon, Enum.PartType.Ball)) end
	end
	-- Threshold line under the barrier, the yellow-and-ink "you made it" strip behind it, and chevrons
	-- in the stage colour leading up to it.
	decor(g:box('ThresholdLine', V(-16, 0, -0.6), V(16, 0.12, 0.6), lite, M.Neon)).CastShadow = false
	decor(g:box('WinStrip', V(-16, 0, -4.6), V(16, 0.1, -0.6), P.win, M.SmoothPlastic))
	for k = 0, 15 do
		local row = k % 2
		decor(g:box('WinCheck', V(-16 + k * 2, 0.1, -4.6 + row * 2), V(-14 + k * 2, 0.12, -2.6 + row * 2), P.ink, M.SmoothPlastic))
	end
	for _, cz in { 6, 10, 14 } do chevron(g, cz, lite, 6) end
	-- Confetti the client fires when you break through.
	local shell = ghost(g:box('PassShell', V(-15, 14, -1), V(15, 15, 1), P.white))
	local fx = Instance.new('ParticleEmitter')
	fx.Name = 'PassFX'
	fx.Texture = 'rbxasset://textures/particles/SquareParticle.png'
	fx:SetAttribute('PreviewTexture', 'confetti')
	fx.Enabled = false
	fx.Rate = 0
	fx.Lifetime, fx.Speed = NumberRange.new(1.6, 2.6), NumberRange.new(8, 18)
	fx.SpreadAngle = Vector2.new(70, 70)
	fx.Acceleration = V(0, -18, 0)
	fx.Drag = 1.2
	fx.Size = NumberSequence.new(0.5)
	fx.RotSpeed, fx.Rotation = NumberRange.new(-260, 260), NumberRange.new(0, 360)
	fx.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, base), ColorSequenceKeypoint.new(0.5, P.win), ColorSequenceKeypoint.new(1, P.white) })
	fx.EmissionDirection = Enum.NormalId.Bottom
	fx.LightInfluence = 1
	fx.Parent = shell
	-- Win pad past the gate (not after the last): stand on it to go back to the block.
	if padSide then
		local pad = g:part('WinPad', V(0.4, 8, 8), CFrame.new(padSide * 15.2, 0.2, -12) * CFrame.Angles(0, 0, math.pi / 2), P.win, M.SmoothPlastic, Enum.PartType.Cylinder)
		decor(g:part('WinPadRim', V(0.3, 8.8, 8.8), CFrame.new(padSide * 15.2, 0.15, -12) * CFrame.Angles(0, 0, math.pi / 2), lite, M.Neon, Enum.PartType.Cylinder))
		local prompt = Instance.new('ProximityPrompt')
		prompt.Name = 'BackToBlock'
		prompt.ActionText = 'Back to the Block'
		prompt.ObjectText = 'Stage ' .. i .. ' cleared'
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute('Target', 'Lobby')
		prompt:AddTag('HoodTeleport')
		prompt.Parent = pad
		billboard(g, V(padSide * 15.2, 4.6, -12), 5, 1.6, { { 'Title', 'STAGE ' .. i .. ' ✓', P.win, FONT.loud, 0, 0.56 }, { 'Detail', 'BACK TO THE BLOCK', P.white, FONT.body, 0.58, 0.38 } })
	end
	model:SetAttribute('Stage', i)
	model:SetAttribute('WallId', wall.Id)
	model:SetAttribute('Required', wall.RequiredRep)
	model:SetAttribute('Reward', wall.CashReward)
	model:SetAttribute('LineZ', z)
	model:SetAttribute('PadZ', z - 12)
	model:SetAttribute('HalfWidth', 20)
	model:SetAttribute('Color', base)
	model:SetAttribute('Light', lite)
	model:AddTag('HoodStageGate')
	return model
end

---------------------------------------------------------------------------------------------- hood set pieces
-- Mural on a wall (ctx frame: x along the wall, -Z out of it, y up from the floor): a base coat, Memphis
-- shapes with ink outlines, and bubble letters.
local function mural(ctx, w, h, base, text, seed, sub)
	local m = ctx:group('Mural')
	local panel = m:box('MuralBase', V(-w / 2, 0.6, -0.12), V(w / 2, 0.6 + h, 0), base, M.SmoothPlastic)
	local r = Random.new(seed)
	for k = 1, 5 do
		local col = P.memphis[(seed + k) % #P.memphis + 1]
		local x, y = -w / 2 + 1.4 + (k - 1) * (w - 2.8) / 4, 0.6 + r:NextNumber(0.6, h - 1.4)
		local kind = (seed + k) % 3
		if kind == 0 then -- dot
			decor(m:part('MemphisOutline', V(0.08, 1.9, 1.9), CFrame.new(x, y, -0.16) * CFrame.Angles(0, math.pi / 2, 0), P.ink, M.SmoothPlastic, Enum.PartType.Cylinder))
			decor(m:part('MemphisDot', V(0.1, 1.5, 1.5), CFrame.new(x, y, -0.19) * CFrame.Angles(0, math.pi / 2, 0), col, M.SmoothPlastic, Enum.PartType.Cylinder))
		elseif kind == 1 then -- zig-zag
			for q = 0, 2 do
				local a, b = V(x - 1.2 + q * 0.8, y + (q % 2) * 0.7, -0.17), V(x - 0.4 + q * 0.8, y + ((q + 1) % 2) * 0.7, -0.17)
				decor(m:bar('MemphisZig', a, b, 0.32, col, M.SmoothPlastic))
			end
		else -- triangle
			decor(m:wedge('MemphisTri', V(0.1, 1.4, 1.6), CFrame.new(x, y, -0.18) * CFrame.Angles(0, math.pi / 2, 0), col, M.SmoothPlastic))
		end
	end
	local g = surface(panel, Enum.NormalId.Front, 30)
	line(g, 'Tag', text, P.white, FONT.loud, sub and 0.14 or 0.2, sub and 0.5 or 0.6, P.ink, 5)
	if sub then line(g, 'Sub', sub, P.ink, FONT.title, 0.66, 0.2, P.white, 3) end
	return m
end

-- Chain-link panel from a to b with woven privacy slats in `slat` (hood_style_and_bags.md kit #7).
local function slatFence(ctx, a, b, height, slat)
	local f = ctx:group('SlatFence')
	local dir = b - a
	local n = math.max(1, math.floor(dir.Magnitude / 6))
	for k = 0, n do f:post('FencePost', 0.2, height + 0.2, a + dir * k / n, P.chain) end
	local cf = CFrame.lookAt((a + b) / 2, b)
	f:part('TopRail', V(0.2, 0.2, dir.Magnitude), cf + V(0, height, 0), P.chain, M.Metal)
	local mesh = decor(f:part('Mesh', V(0.06, height - 0.4, dir.Magnitude), cf + V(0, height / 2 + 0.1, 0), P.chain, M.DiamondPlate))
	mesh.Transparency = 0.55
	mesh.CanCollide = true
	if slat then
		local steps = math.floor(dir.Magnitude / 1.2)
		for k = 1, steps - 1, 2 do
			local p = a + dir * (k / steps)
			decor(f:part('Slat', V(0.12, height - 0.8, 0.5), CFrame.lookAt(p + V(0, height / 2, 0), p + V(0, height / 2, 0) + dir), slat, M.SmoothPlastic))
		end
	end
	return f
end

-- Hero-scale open hydrant (1.6x) spraying an arc of water into a puddle with a mini rainbow.
local function hydrantSpray(ctx, pos, toward)
	local h = ctx:at(CFrame.lookAt(pos, pos + toward)):group('OpenHydrant')
	h:post('Foot', 1.2, 0.3, V(0, 0, 0), P.iron)
	h:post('Barrel', 0.9, 2.8, V(0, 0.3, 0), C(226, 56, 62))
	h:post('Collar', 1.08, 0.4, V(0, 2.3, 0), C(226, 56, 62))
	h:blob('Cap', V(1.8, 1.2, 1.8), V(0, 3.2, 0), C(255, 194, 26), M.SmoothPlastic)
	h:rod('SideNozzles', 0.42, 2.6, CFrame.new(0, 1.7, 0), C(226, 56, 62))
	h:part('Nozzle', V(1.2, 0.9, 0.9), CFrame.new(0, 1.7, -1.0) * CFrame.Angles(0, math.pi / 2, 0), C(255, 194, 26), M.Metal, Enum.PartType.Cylinder)
	local nozzle = ghost(h:box('SprayFX', V(-0.3, 1.4, -1.8), V(0.3, 2.0, -1.4), P.white))
	local e = Instance.new('ParticleEmitter')
	e.Name = 'Spray'
	e.Texture = 'rbxasset://textures/particles/sparkles_main.dds'
	e:SetAttribute('PreviewTexture', 'sparkle')
	e.Rate, e.Lifetime, e.Speed = 60, NumberRange.new(0.6), NumberRange.new(16, 20)
	e.EmissionDirection = Enum.NormalId.Front
	e.SpreadAngle = Vector2.new(10, 25)
	e.Acceleration = V(0, -40, 0)
	e.Size = NumberSequence.new(0.7, 0.3)
	e.Color = ColorSequence.new(C(158, 231, 255), P.white)
	e.Transparency = NumberSequence.new(0.2, 0.6)
	e.LightInfluence = 1
	e.Parent = nozzle
	local puddle = decor(h:part('Puddle', V(0.05, 7, 7), CFrame.new(0, 0.03, -7) * CFrame.Angles(0, 0, math.pi / 2), C(111, 211, 255), M.Glass, Enum.PartType.Cylinder))
	puddle.Transparency = 0.4
	for k, col in { C(255, 90, 90), C(255, 220, 60), C(90, 200, 255) } do
		for q = 0, 5 do
			local a0, a1 = q / 6 * math.pi, (q + 1) / 6 * math.pi
			local r = 2.6 - k * 0.35
			local p0, p1 = V(math.cos(a0) * r, math.sin(a0) * r, -7), V(math.cos(a1) * r, math.sin(a1) * r, -7)
			local band = decor(h:bar('Rainbow', p0, p1, 0.3, col, M.Neon))
			band.Transparency = 0.55
			band.CastShadow = false
		end
	end
	return h
end

-- Boombox on a milk crate, cones ringed in neon (kit #11).
local function boombox(ctx, cf)
	local b = ctx:at(cf):group('Boombox')
	local crateColor = P.crate[1]
	b:box('CrateBase', V(-0.8, 0, -0.8), V(0.8, 1.4, 0.8), crateColor, M.SmoothPlastic)
	b:box('Body', V(-1.5, 1.4, -0.5), V(1.5, 3.0, 0.5), P.iron, M.SmoothPlastic)
	b:box('Face', V(-1.4, 1.5, -0.55), V(1.4, 2.9, -0.5), P.chain, M.SmoothPlastic)
	for k, x in { -0.8, 0.8 } do
		decor(b:part('Cone', V(0.08, 1.1, 1.1), CFrame.new(x, 2.2, -0.6) * CFrame.Angles(0, math.pi / 2, 0), P.ink, M.SmoothPlastic, Enum.PartType.Cylinder))
		decor(b:part('ConeRing', V(0.06, 1.3, 1.3), CFrame.new(x, 2.2, -0.57) * CFrame.Angles(0, math.pi / 2, 0), P.memphis[k == 1 and 1 or 3], M.Neon, Enum.PartType.Cylinder))
	end
	b:bar('Handle', V(-1.1, 3.4, 0), V(1.1, 3.4, 0), 0.2, P.chain)
	for _, x in { -1.1, 1.1 } do b:bar('HandlePost', V(x, 3.0, 0), V(x, 3.4, 0), 0.2, P.chain) end
	return b
end

-- Street-corner kit: lamp post with crossed street-name blades, a mailbox and a newspaper box.
local function streetCorner(ctx, pos, nameA, nameB)
	local c = ctx:group('StreetCorner')
	c:post('SignPole', 0.25, 11, pos, P.signGreen)
	for k, n in { nameA, nameB } do
		local blade = c:at(CFrame.new(pos + V(0, 9.4 + k * 0.7, 0)) * CFrame.Angles(0, k * math.pi / 2, 0)):box('StreetBlade', V(-2.6, 0, -0.08), V(2.6, 0.6, 0.08), P.signGreen, M.SmoothPlastic)
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do line(surface(blade, face, 40), 'Name', n, P.white, FONT.title, 0.1, 0.8) end
	end
	return c
end
local function mailbox(ctx, pos, facing)
	local m = ctx:at(CFrame.lookAt(pos, pos + facing)):group('Mailbox')
	for _, x in { -0.7, 0.7 } do m:box('Leg', V(x - 0.15, 0, -0.5), V(x + 0.15, 0.8, 0.5), P.iron, M.Metal) end
	m:box('Box', V(-1.0, 0.8, -0.9), V(1.0, 3.0, 0.9), P.crate[1], M.SmoothPlastic)
	m:part('Top', V(1.8, 2.0, 2.0), CFrame.new(0, 3.0, 0) * CFrame.Angles(0, math.pi / 2, 0), P.crate[1], M.SmoothPlastic, Enum.PartType.Cylinder)
	m:box('Slot', V(-0.6, 2.4, -0.95), V(0.6, 2.6, -0.9), P.ink, M.SmoothPlastic)
	return m
end
local function newsBox(ctx, pos, facing)
	local n = ctx:at(CFrame.lookAt(pos, pos + facing)):group('NewsBox')
	n:box('Box', V(-0.8, 0.4, -0.7), V(0.8, 2.6, 0.7), P.crate[2], M.SmoothPlastic)
	n:box('Window', V(-0.6, 1.4, -0.75), V(0.6, 2.3, -0.7), P.cream, M.SmoothPlastic)
	n:box('Foot', V(-0.7, 0, -0.6), V(0.7, 0.4, 0.6), P.iron, M.Metal)
	return n
end

-- Props along the approach to gate i (the "street gets nicer" ladder, hood_style_and_bags.md 2.4). Each
-- stage adds one privilege on top of the last; everything stays on the side away from the next alcove.
local function stageProps(ctx, i, z, free)
	local p = ctx:group('Stage' .. i .. 'Props')
	local zs = z + 9
	local x = free * 15.5
	local hue = STAGE[i][1]
	if i == 1 then
		for k, b in { { -16, 0 }, { -16, 2.4 }, { -13.4, 0 }, { 15.4, 0 } } do
			p:box('MovingBox', V(b[1] - 1.2, b[2], zs - 1.2 + k * 0.1), V(b[1] + 1.2, b[2] + 2.4, zs + 1.2 + k * 0.1), P.cardboard, M.Cardboard)
		end
	elseif i == 2 then
		slatFence(p, V(free * 13.5, 0, zs - 5), V(free * 13.5, 0, zs + 5), 6, hue)
		slatFence(p, V(-free * 13.5, 0, zs - 3), V(-free * 13.5, 0, zs + 3), 6, hue)
	elseif i == 3 then
		local van = p:at(CFrame.new(x, 0, zs)):group('DeliveryVan')
		van:box('Body', V(-2.6, 1.2, -5), V(2.6, 7.6, 4.4), P.white, M.SmoothPlastic)
		van:box('Cab', V(-2.6, 1.2, -7.4), V(2.6, 5.4, -5), P.white, M.SmoothPlastic)
		van:box('Windshield', V(-2.2, 3.6, -7.5), V(2.2, 5.1, -7.4), P.glass, M.Glass)
		van:box('Stripe', V(2.6, 3.8, -5), V(2.65, 4.8, 4.4), hue, M.SmoothPlastic)
		van:box('Stripe', V(-2.65, 3.8, -5), V(-2.6, 4.8, 4.4), hue, M.SmoothPlastic)
		for _, zz in { -5.6, 2.6 } do for _, xx in { -2.65, 2.65 } do van:rod('Wheel', 1.2, 0.8, CFrame.new(xx, 1.2, zz), P.iron, M.Rubber) end end
	elseif i == 4 then
		hydrantSpray(p, V(x, 0, zs), V(-free, 0, 0))
	elseif i == 5 then
		for _, xx in { free * 13, free * 16.5 } do
			p:post('Barrel', 1.1, 2.8, V(xx, 0, zs), P.orange, M.SmoothPlastic)
			p:post('BarrelBand', 1.13, 0.4, V(xx, 1.6, zs), P.white, M.SmoothPlastic)
		end
		local sign = p:box('WetPaint', V(x - 1.6, 3, zs + 3), V(x + 1.6, 5, zs + 3.2), P.white, M.SmoothPlastic)
		p:box('SignLeg', V(x - 0.15, 0, zs + 3.05), V(x + 0.15, 3, zs + 3.15), P.wood, M.Wood)
		line(surface(sign, Enum.NormalId.Back, 40), 'Text', 'WET PAINT', hue, FONT.loud, 0.15, 0.7)
	elseif i == 6 then
		local wx = free * 19.1
		for _, xx in { wx, free * 14.4 } do for _, zz in { zs - 5, zs + 5 } do p:box('ScaffoldPost', V(xx - 0.2, 0, zz - 0.2), V(xx + 0.2, 10.3, zz + 0.2), P.steel, M.Metal) end end
		for _, y in { 5, 10 } do p:box('ScaffoldDeck', V(free * 19.3, y, zs - 4.8), V(free * 14.2, y + 0.3, zs + 4.8), P.wood, M.WoodPlanks) end
		p:box('ToeBoard', V(free * 14.6, 10.3, zs - 4.8), V(free * 14.2, 11.3, zs + 4.8), hue, M.SmoothPlastic)
	elseif i == 7 then
		local cart = p:at(CFrame.new(x, 0, zs)):group('FoodCart')
		cart:box('Cart', V(-1.8, 1.2, -2.6), V(1.8, 3.6, 2.6), C(210, 214, 220), M.Metal)
		for _, zz in { -1.8, 1.8 } do cart:rod('Wheel', 1, 0.3, CFrame.new(-1.95, 1, zz), P.iron, M.Rubber) end
		cart:post('UmbrellaPole', 0.12, 4.4, V(0, 3.6, 0), P.iron)
		for k = 0, 5 do
			cart:box('Umbrella', V(-2.6 + k * 5.2 / 6, 8, -2.6), V(-2.6 + (k + 1) * 5.2 / 6, 8.3, 2.6), k % 2 == 0 and hue or P.white, M.Fabric)
		end
	elseif i == 8 then
		for _, zz in { zs - 3, zs + 3 } do
			p:box('Speaker', V(x - 1.3, 0, zz - 1.3), V(x + 1.3, 5, zz + 1.3), P.iron, M.SmoothPlastic)
			for _, y in { 1.4, 3.6 } do
				decor(p:part('Cone', V(0.1, 1.6, 1.6), CFrame.new(x - free * 1.32, y, zz) , P.ink, M.SmoothPlastic, Enum.PartType.Cylinder))
				decor(p:part('ConeRing', V(0.08, 1.9, 1.9), CFrame.new(x - free * 1.3, y, zz), hue, M.Neon, Enum.PartType.Cylinder))
			end
		end
	elseif i == 9 then
		for k = 1, 7 do
			local xx, zz = free * (6 + k * 1.3), zs + (k % 3) * 1.5
			local b = p:at(CFrame.new(xx, 0, zz) * CFrame.Angles(0, k, 0)):group('Pigeon')
			decor(b:blob('Body', V(0.9, 0.9, 1.4), V(0, 0.6, 0), C(154, 163, 181), M.SmoothPlastic))
			decor(b:blob('Neck', V(0.62, 0.45, 0.5), V(0, 1.0, -0.4), k % 2 == 0 and C(110, 75, 168) or C(63, 191, 143), M.SmoothPlastic))
			decor(b:blob('Head', V(0.5, 0.5, 0.5), V(0, 1.25, -0.55), C(120, 130, 150), M.SmoothPlastic))
		end
		for _, zz in { zs - 4, zs + 4 } do
			p:box('Planter', V(x - 1.4, 0, zz - 1.4), V(x + 1.4, 1.6, zz + 1.4), P.cream, M.SmoothPlastic)
			p:part('Boxwood', V(2.6, 2.6, 2.6), CFrame.new(x, 2.7, zz), C(63, 166, 90), M.SmoothPlastic, Enum.PartType.Ball)
		end
	else
		for _, xx in { free * 8, free * 12, free * 16 } do
			p:box('Turnstile', V(xx - 0.9, 0, zs - 1.5), V(xx + 0.9, 3.4, zs + 1.5), C(150, 160, 160), M.Metal)
			p:bar('TurnstileArm', V(xx - 0.9, 2.8, zs), V(xx - 3.0, 2.8, zs), 0.16, P.steel)
		end
	end
	return p
end

---------------------------------------------------------------------------------------------- street furniture
local function stringLights(ctx, a, b, sag, sneakers)
	local g = ctx:group('StringLights')
	local n = 14
	local function at(t) return a:Lerp(b, t) - V(0, sag * 4 * t * (1 - t), 0) end
	local colors = { C(255, 214, 120), C(255, 120, 90), C(120, 220, 255), C(255, 236, 170) }
	for k = 0, n - 1 do
		decor(g:bar('Wire', at(k / n), at((k + 1) / n), 0.06, P.iron)).CastShadow = false
		if k > 0 then
			local bulb = decor(g:blob('Bulb', V(0.42, 0.55, 0.42), at(k / n) - V(0, 0.31, 0), colors[k % #colors + 1], M.Neon))
			bulb.CastShadow = false
		end
	end
	if sneakers then
		local mid = at(0.5)
		for k, side in { -1, 1 } do
			local hang = mid + V(side * 0.45, -1.4 - k * 0.2, 0)
			decor(g:bar('Lace', mid, hang + V(0, 0.42, 0), 0.05, P.white, M.Fabric))
			local shoe = g:at(CFrame.new(hang) * CFrame.Angles(math.rad(70), 0, math.rad(side * 8)))
			decor(shoe:box('Sneaker', V(-0.35, -0.3, -0.75), V(0.35, 0.3, 0.75), P.white, M.Leather))
			decor(shoe:box('Sole', V(-0.37, -0.44, -0.77), V(0.37, -0.3, 0.77), P.red, M.Rubber))
		end
	end
	return g
end

---------------------------------------------------------------------------------------------- basketball court
-- Half court on the east lawn (x 24..38, z 78..98): orange floor, blue key, white lines, a full hoop,
-- a ball, and a few leaves drifting down. A landmark and a thumbnail spot.
local function buildCourt(ctx)
	local c = ctx:group('BasketballCourt')
	local x0, x1, z0, z1 = 24, 38, 78, 98
	local cx = (x0 + x1) / 2
	c:box('CourtFloor', V(x0, 0, z0), V(x1, 0.12, z1), C(255, 138, 61), M.SmoothPlastic)
	c:box('Key', V(cx - 3, 0.12, z1 - 7.5), V(cx + 3, 0.15, z1), C(43, 184, 240), M.SmoothPlastic)
	local white = C(250, 250, 248)
	local function lineBox(a, b) c:box('CourtLine', a, b, white, M.SmoothPlastic) end
	lineBox(V(x0, 0.12, z0), V(x1, 0.17, z0 + 0.3))
	lineBox(V(x0, 0.12, z0), V(x0 + 0.3, 0.17, z1))
	lineBox(V(x1 - 0.3, 0.12, z0), V(x1, 0.17, z1))
	lineBox(V(cx - 3, 0.15, z1 - 7.8), V(cx + 3, 0.18, z1 - 7.5))
	-- Three-point arc as short bars around the hoop.
	local hoopZ = z1 - 1.6
	for k = 0, 10 do
		local a0, a1 = math.rad(200 + k * 14), math.rad(200 + (k + 1) * 14)
		local p0 = V(cx + math.cos(a0) * 6.2, 0.15, hoopZ + math.sin(a0) * 6.2)
		local p1 = V(cx + math.cos(a1) * 6.2, 0.15, hoopZ + math.sin(a1) * 6.2)
		c:part('ArcLine', V(0.3, 0.05, (p1 - p0).Magnitude + 0.05), CFrame.lookAt((p0 + p1) / 2, p1), white, M.SmoothPlastic)
	end
	-- Hoop: pole, arm, backboard with a red square, rim and a short net.
	c:post('HoopPole', 0.3, 9.4, V(cx, 0, z1 + 0.4), C(40, 44, 52), M.Metal)
	c:box('HoopArm', V(cx - 0.2, 8.7, z1 - 0.7), V(cx + 0.2, 9.1, z1 + 0.4), C(40, 44, 52), M.Metal)
	c:box('Backboard', V(cx - 1.9, 8.0, z1 - 0.9), V(cx + 1.9, 10.4, z1 - 0.7), white, M.SmoothPlastic)
	for _, e in { { V(cx - 0.8, 8.6, z1 - 0.95), V(cx + 0.8, 8.72, z1 - 0.9) }, { V(cx - 0.8, 9.5, z1 - 0.95), V(cx + 0.8, 9.62, z1 - 0.9) }, { V(cx - 0.8, 8.6, z1 - 0.95), V(cx - 0.68, 9.62, z1 - 0.9) }, { V(cx + 0.68, 8.6, z1 - 0.95), V(cx + 0.8, 9.62, z1 - 0.9) } } do
		c:box('BoardSquare', e[1], e[2], P.red, M.SmoothPlastic)
	end
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		c:part('Rim', V(0.62, 0.1, 0.12), CFrame.new(cx + math.cos(a) * 0.75, 8.55, hoopZ + 0.55 + math.sin(a) * 0.75) * CFrame.Angles(0, -a + math.pi / 2, 0), P.orange, M.Metal)
		decor(c:bar('Net', V(cx + math.cos(a) * 0.72, 8.5, hoopZ + 0.55 + math.sin(a) * 0.72), V(cx + math.cos(a) * 0.4, 7.5, hoopZ + 0.55 + math.sin(a) * 0.4), 0.06, white, M.Fabric))
	end
	c:part('Basketball', V(1.2, 1.2, 1.2), CFrame.new(cx - 2.5, 0.72, z0 + 6), P.orange, M.SmoothPlastic, Enum.PartType.Ball)
	bench(c, V(x1 + 0.9, 0, z0 + 12), V(-1, 0, 0)) -- clear of the subway railing at z 68..80.5
	-- Leaves drifting over the court (Rate 3, slow, lit by the sun).
	local leafHolder = c:part('LeavesFX', V(16, 0.2, 20), CFrame.new(cx, 15, (z0 + z1) / 2), P.white)
	ghost(leafHolder)
	local e = Instance.new('ParticleEmitter')
	e.Name = 'Leaves'
	e.Texture = 'rbxasset://textures/particles/SquareParticle.png'
	e:SetAttribute('PreviewTexture', 'confetti')
	e.Rate, e.Lifetime, e.Speed = 3, NumberRange.new(5, 7), NumberRange.new(0.3, 0.8)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Acceleration = V(0.4, -0.9, 0.2)
	e.Drag = 0.4
	e.Size = NumberSequence.new(0.5)
	e.Color = ColorSequence.new(C(122, 217, 87), C(255, 196, 70))
	e.RotSpeed, e.Rotation = NumberRange.new(-120, 120), NumberRange.new(0, 360)
	e.LightInfluence = 1
	e.Parent = leafHolder
	return c
end

---------------------------------------------------------------------------------------------- street alcoves
-- Block party (segment 8): a dance floor that cycles colour, a DJ booth with speaker stacks, balloons.
local function buildParty(ctx)
	local b = ctx:group('BlockParty')
	local floor, floorModel = b:group('DanceFloor')
	for ix = 0, 3 do
		for iz = 0, 3 do
			local x0, z0 = -6 + ix * 3, -6 + iz * 3
			floor:box('DanceTile', V(x0 + 0.08, 0, z0 + 0.08), V(x0 + 2.92, 0.15, z0 + 2.92), Color3.fromHSV(((ix + iz) % 4) / 4 + 0.05, 0.75, 1), M.Neon)
		end
	end
	floorModel:SetAttribute('Hue', 4)
	floorModel:AddTag('HoodMotion')
	-- DJ booth against the back wall (local +Z).
	b:box('Booth', V(-3.5, 0, 5.4), V(3.5, 3.2, 7.4), P.iron, M.SmoothPlastic)
	b:box('BoothFront', V(-3.5, 0.4, 5.3), V(3.5, 2.8, 5.4), STAGE[8][1], M.SmoothPlastic)
	for _, x in { -1.6, 1.6 } do b:part('Turntable', V(0.2, 1.8, 1.8), CFrame.new(x, 3.3, 6.4) * CFrame.Angles(0, 0, math.pi / 2), P.ink, M.SmoothPlastic, Enum.PartType.Cylinder) end
	for _, x in { -6.5, 6.5 } do
		for y = 0, 2 do
			b:box('SpeakerStack', V(x - 1.3, y * 2.6, 5.2), V(x + 1.3, (y + 1) * 2.6, 7.8), P.iron, M.SmoothPlastic)
			decor(b:part('Cone', V(0.1, 1.8, 1.8), CFrame.new(x, y * 2.6 + 1.3, 5.15) * CFrame.Angles(0, math.pi / 2, 0), P.ink, M.SmoothPlastic, Enum.PartType.Cylinder))
			decor(b:part('ConeRing', V(0.08, 2.1, 2.1), CFrame.new(x, y * 2.6 + 1.3, 5.18) * CFrame.Angles(0, math.pi / 2, 0), P.memphis[y + 1], M.Neon, Enum.PartType.Cylinder))
		end
	end
	local banner = b:box('PartyBanner', V(-5, 4.2, 7.7), V(5, 7.4, 8), P.ink, M.SmoothPlastic)
	line(surface(banner, Enum.NormalId.Front, 30), 'Text', 'BLOCK PARTY', P.win, FONT.loud, 0.1, 0.8, STAGE[8][2], 3)
	-- Balloon bunches bobbing on strings.
	for k, x in { -9, 9 } do
		local bunch, bunchModel = b:group('Balloons')
		for q = 0, 2 do
			local top = V(x + (q - 1) * 0.8, 7 + (q % 2) * 0.8, 4)
			decor(bunch:bar('String', V(x, 3, 4), top, 0.05, P.white, M.Fabric))
			decor(bunch:blob('Balloon', V(1.4, 1.7, 1.4), top + V(0, 0.8, 0), P.memphis[(k + q) % #P.memphis + 1], M.SmoothPlastic))
		end
		bunch:post('Weight', 0.3, 0.5, V(x, 0, 4), P.iron)
		bunchModel:SetAttribute('Bob', 0.35)
		bunchModel:SetAttribute('BobPeriod', 2.6 + k * 0.3)
		bunchModel:AddTag('HoodMotion')
	end
	local e = Instance.new('ParticleEmitter')
	e.Name = 'PartyConfetti'
	e.Texture = 'rbxasset://textures/particles/SquareParticle.png'
	e:SetAttribute('PreviewTexture', 'confetti')
	e.Rate, e.Lifetime, e.Speed = 8, NumberRange.new(3, 4), NumberRange.new(0.5, 1.5)
	e.Acceleration, e.Drag = V(0, -2.2, 0), 0.6
	e.Size = NumberSequence.new(0.4)
	e.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, P.memphis[1]), ColorSequenceKeypoint.new(0.5, P.memphis[2]), ColorSequenceKeypoint.new(1, P.memphis[3]) })
	e.RotSpeed, e.Rotation, e.LightInfluence = NumberRange.new(-180, 180), NumberRange.new(0, 360), 1
	e.Parent = ghost(b:box('ConfettiFX', V(-7, 12, -7), V(7, 12.2, 7), P.white))
	return b
end

-- What waits past gate k: a bag station facing the street, a mural on the alcove's back wall, and
-- era-appropriate edging (chain-link with slats on the block, planters further on, gold rails nearly uptown).
local function buildAlcove(ctx, k, skins)
	local seg = SEGMENTS[k]
	local x0, z0, x1, z1 = alcove(k)
	local s = seg.side
	local cz = (z0 + z1) / 2
	local e = era(cz)
	local hue = STAGE[k][1]
	local a = ctx:group('Alcove' .. k)
	local back = a:at(CFrame.lookAt(V(s * 36, 0, cz), V(s * 35, 0, cz)))
	if seg.station then
		local st = skins.StationById[seg.station]
		local tier = table.find(skins.Stations, st)
		local pos = V(s * 28.5, 0, cz)
		Props.station(a:at(CFrame.lookAt(pos, V(0, 0, cz))), PROPS_KIT, st, tier)
		local words = { Tape = 'TAPE IT UP', Street = 'STREET TOUGH', Heavy = 'HIT HARD', Speed = 'FAST HANDS', DoubleEnd = 'LIVE WIRE', Pro = 'GO PRO', Gold = 'STAY GOLDEN' }
		mural(back, 24, 7, hue, words[seg.station] or 'TRAIN', k * 7, string.upper(st.Name) .. ' • x' .. st.Multiplier)
	elseif seg.piece == 'Court' then
		buildCourt(a:at(CFrame.new((x0 + x1) / 2 - 31, 0, cz - 88)))
		mural(back, 24, 7, hue, 'NOTHING BUT NET', k * 7)
	else
		buildParty(a:at(CFrame.lookAt(V(s * 28, 0, cz), V(0, 0, cz))))
	end
	-- Edging along the alcove's open side walls (kept off the opening itself).
	for _, zz in { z0 + 0.6, z1 - 0.6 } do
		if e == 1 then
			slatFence(a, V(s * 22, 0, zz), V(s * 35.4, 0, zz), 6, hue)
		elseif e == 2 then
			for q = 0, 1 do
				local px = s * (24 + q * 8)
				a:box('Planter', V(px - 1.4, 0, zz - 0.6), V(px + 1.4, 1.2, zz + 0.6), P.brownstone, M.SmoothPlastic)
				for f = 0, 2 do a:part('Bloom', V(0.7, 0.7, 0.7), CFrame.new(px - 0.8 + f * 0.8, 1.45, zz), P.flower[(k + f + q) % #P.flower + 1], M.SmoothPlastic, Enum.PartType.Ball) end
			end
		else
			a:box('BrassRail', V(math.min(s * 22, s * 35.4), 2.6, zz - 0.12), V(math.max(s * 22, s * 35.4), 2.84, zz + 0.12), C(255, 200, 60), M.Metal)
			for q = 0, 3 do a:post('RailPost', 0.14, 2.6, V(s * (22.5 + q * 4.2), 0, zz), C(255, 200, 60)) end
		end
	end
	return a
end

---------------------------------------------------------------------------------------------- lobby
-- Corner deli (kit #5): yellow slanted awning with red letters, a neon OPEN sign, stacked goods in the
-- window, a rolled-up shutter and the bodega cat on a crate. Face frame: x along the wall, -Z out of it.
local function bodega(ctx)
	local s = ctx:group('Bodega')
	s:box('Door', V(-1.6, 0, -0.15), V(1.6, 6.2, 0), P.crate[3], M.SmoothPlastic)
	s:box('DoorGlass', V(-1.1, 2.4, -0.2), V(1.1, 5.4, -0.15), P.glassLit, M.Glass)
	s:post('Shutter', 0.45, 0.1, V(0, 6.4, -0.5), P.chain)
	s:rod('ShutterRoll', 0.45, 3.4, CFrame.new(0, 6.6, -0.5), P.chain)
	for _, side in { -1, 1 } do
		local cx = side * 5
		s:box('Window', V(cx - 2.6, 1.6, -0.12), V(cx + 2.6, 5.6, 0), P.glassLit, M.Glass)
		s:box('Sill', V(cx - 2.9, 1.2, -0.6), V(cx + 2.9, 1.6, 0), P.cream, M.SmoothPlastic)
		-- Goods stacked behind the glass in six toy colours.
		for q = 0, 5 do
			local col = ({ P.hotRed, P.awning, P.crate[1], P.crate[2], P.crate[3], P.memphis[4] })[(q + side) % 6 + 1]
			local bx = cx - 2.1 + (q % 3) * 1.45
			local by = 1.6 + math.floor(q / 3) * 1.1
			s:box('Goods', V(bx, by, 0.02), V(bx + 1.1, by + 1.0, 0.5), col, M.SmoothPlastic)
		end
	end
	local open = decor(s:box('OpenSign', V(2.8, 4.2, -0.24), V(6.6, 5.4, -0.13), P.ink, M.SmoothPlastic))
	line(surface(open, Enum.NormalId.Front, 40), 'Open', 'OPEN', P.memphis[1], FONT.loud, 0.08, 0.84)
	light(open, P.memphis[1], 1, 10)
	-- Slanted awning with the letters on its valance.
	local awn = s:at(CFrame.new(0, 7.4, -1.6) * CFrame.Angles(math.rad(-24), 0, 0)):box('Awning', V(-8.4, -0.15, -1.9), V(8.4, 0.15, 1.9), P.awning, M.Fabric)
	local valance = s:box('AwningValance', V(-8.4, 5.9, -3.4), V(8.4, 6.9, -3.2), P.awning, M.Fabric)
	line(surface(valance, Enum.NormalId.Front, 40), 'Name', 'DELI • GROCERY • 24/7', P.hotRed, FONT.loud, 0.06, 0.88, P.white, 2)
	local sign = s:box('Sign', V(-8, 8.0, -0.3), V(8, 9.8, 0), P.hotRed, M.SmoothPlastic)
	for _, x in { -6, 0, 6 } do s:box('SignStrut', V(x - 0.15, 8.0, 0), V(x + 0.15, 9.5, 1.2), P.iron, M.Metal) end
	line(surface(sign, Enum.NormalId.Front, 40), 'Name', 'SUNNY SIDE BODEGA', P.white, FONT.loud, 0.08, 0.84, P.ink, 2)
	-- The bodega cat on a milk crate by the door.
	crate(s, CFrame.new(3.2, 0, -1.6), P.crate[1])
	pet(s, 'BodegaCat', CFrame.new(3.2, 1.4, -1.0))
	return s, awn
end

local function buildLobby(ctx, skins, crew, art)
	local lobby = ctx:group('Lobby')
	-- Spawn: a medallion at (0, 30) facing down the street; Stage 1's gate is 34 studs ahead.
	local function disc(name, d, y0, y1, color, material)
		return lobby:part(name, V(y1 - y0, d, d), CFrame.new(0, (y0 + y1) / 2, 30) * CFrame.Angles(0, 0, math.pi / 2), color, material or M.SmoothPlastic, Enum.PartType.Cylinder)
	end
	disc('Medallion', 12, 0, 0.1, P.cream, M.SmoothPlastic)
	disc('MedallionRing', 10, 0.1, 0.16, P.win, M.SmoothPlastic)
	disc('MedallionCentre', 8, 0.16, 0.2, P.navy, M.SmoothPlastic)
	local spawn = Instance.new('SpawnLocation')
	spawn.Name = 'Spawn'
	spawn.Anchored = true
	spawn.Enabled = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = V(6, 0.2, 6)
	spawn.CFrame = V2.Origin * CFrame.new(0, 0.3, 30)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = lobby.parent
	-- The free Tire Bag, about 10 studs from spawn and turned toward it, with chevrons leading over.
	Props.station(lobby:at(CFrame.lookAt(V(-8, 0, 24.5), V(0, 0, 30))), PROPS_KIT, skins.Stations[1], 1)
	local arrows = lobby:group('TutorialArrows')
	for k = 0, 1 do
		local p = V(-2.4 - k * 2.4, 0, 27.6 - k * 1.6)
		local arrow = arrows:at(CFrame.lookAt(p, p + V(-1.5, 0, -1)))
		for _, side in { -1, 1 } do
			local tip, tail = V(0, 0.06, -1.1), V(side * 1.25, 0.06, 0.25)
			decor(arrow:part('Chevron', V(0.55, 0.12, (tail - tip).Magnitude + 0.3), CFrame.lookAt((tip + tail) / 2, tail), P.win, M.Neon)).CastShadow = false
		end
	end
	-- Returning players: a pad beside spawn jumps you to the win pad past your furthest cleared gate.
	local pad = lobby:part('StagePad', V(0.4, 6, 6), CFrame.new(11.5, 0.2, 31) * CFrame.Angles(0, 0, math.pi / 2), P.win, M.SmoothPlastic, Enum.PartType.Cylinder)
	decor(lobby:part('StagePadRim', V(0.3, 6.8, 6.8), CFrame.new(11.5, 0.15, 31) * CFrame.Angles(0, 0, math.pi / 2), P.memphis[3], M.Neon, Enum.PartType.Cylinder))
	local prompt = Instance.new('ProximityPrompt')
	prompt.Name = 'ToFurthest'
	prompt.ActionText = 'Go to my best stage'
	prompt.ObjectText = 'Teleport'
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute('Target', 'Furthest')
	prompt:AddTag('HoodTeleport')
	prompt.Parent = pad
	billboard(lobby, V(11.5, 4.4, 31), 5.4, 1.6, { { 'Title', 'BEST STAGE', P.win, FONT.loud, 0, 0.56 }, { 'Detail', 'TELEPORT ➜', P.white, FONT.body, 0.58, 0.38 } })
	-- Drip Shop: the 15 looks face the plaza from the right lot, the shop building behind them.
	buildDripStand(lobby:at(CFrame.new(22, 0, 22) * CFrame.Angles(0, math.pi / 2, 0)), skins, art, { x0 = -18, x1 = 18, z1 = 38 })
	-- Left lot: the corner deli in the wall, the Bodega Box with its crew pets out front.
	bodega(lobby:at(CFrame.lookAt(V(-44, 0, 22), V(-43, 0, 22))))
	buildCrewStand(lobby:at(CFrame.lookAt(V(-29, 0, 22), V(-20, 0, 22))), crew)
	-- Leaderboards on the back wall (the power board is filled live by LobbyService), the free stash,
	-- and a THE BLOCK sign on the roof behind them that reads from the street.
	local boards = lobby:group('Leaderboards')
	local defs = { { 'TOP POWER', P.win, -12, 'ServerLeaderboard' }, { 'TOP WINS', C(140, 230, 90), 0, 'WinsLeaderboard' }, { 'TOP REBIRTHS', P.magenta, 12, 'RebirthLeaderboard' } }
	for _, d in defs do
		local b = boards:at(CFrame.new(d[3], 0, 42.6)):group(d[4])
		for _, x in { -5.4, 5.4 } do b:box('BoardLeg', V(x - 0.4, 0, -0.4), V(x + 0.4, 14, 0.4), P.iron, M.Metal) end
		local screen = b:box('Board', V(-5, 2, -0.6), V(5, 12, -0.2), C(24, 30, 52), M.SmoothPlastic)
		local rows = {}
		for q = 1, 8 do table.insert(rows, '#' .. q .. '   — — —') end
		local t = line(surface(screen, Enum.NormalId.Front), 'TextLabel', table.concat(rows, '\n'), P.white, FONT.body, 0.04, 0.92)
		t.TextXAlignment = Enum.TextXAlignment.Left
		local header = b:box('Header', V(-5.4, 12, -0.8), V(5.4, 14.2, -0.2), d[2], M.SmoothPlastic)
		line(surface(header, Enum.NormalId.Front), 'Title', d[1], P.ink, FONT.loud, 0.1, 0.8)
	end
	buildStash(lobby:at(CFrame.lookAt(V(16, 0, 38), V(8, 0, 30))))
	local roofSign = lobby:box('BlockSign', V(-16, 8, 47.6), V(16, 15, 48.2), P.ink, M.SmoothPlastic)
	for _, x in { -12, 0, 12 } do lobby:box('SignStrut', V(x - 0.3, 8, 48.2), V(x + 0.3, 14, 49.4), P.iron, M.Metal) end
	local rg = surface(roofSign, Enum.NormalId.Front, 25)
	line(rg, 'Title', 'THE BLOCK', P.win, FONT.loud, 0.04, 0.62, P.hotRed, 6)
	line(rg, 'Sub', '+1 POWER EVERY SECOND • BREAK THE GATES', P.white, FONT.title, 0.68, 0.24, P.ink, 3)
	decor(lobby:box('BlockSignNeon', V(-16.2, 7.8, 47.4), V(16.2, 8.1, 47.7), P.memphis[1], M.Neon))
	decor(lobby:box('BlockSignNeon', V(-16.2, 14.9, 47.4), V(16.2, 15.2, 47.7), P.memphis[1], M.Neon))
	-- Landmark glove on a brick pier at the front-left corner, visible from spawn and down the street.
	studs(lobby:box('GlovePier', V(-25.2, 0, 0.8), V(-22.8, 14, 3.2), P.brownstone, M.Plastic), true)
	giantGlove(lobby:at(CFrame.lookAt(V(-24, 14, 2), V(-23, 14, 2))))
	-- Barbershop in the right lot's front wall, with a spinning pole.
	storefront(lobby:at(CFrame.lookAt(V(32, 0, 0), V(32, 0, 1))), 'Barbershop', 'FRESH CUTS', P.hotRed, P.white)
	local pole, poleModel = lobby:group('BarberPole')
	pole:post('PoleCapBottom', 0.55, 0.4, V(41.2, 2.0, 0.6), P.chain, M.Metal)
	for k = 0, 5 do pole:post('Stripe', 0.42, 0.6, V(41.2, 2.4 + k * 0.6, 0.6), ({ P.hotRed, P.white, P.crate[1] })[k % 3 + 1], M.SmoothPlastic) end
	pole:blob('PoleCapTop', V(1.1, 0.8, 1.1), V(41.2, 6.0, 0.6), P.chain, M.Metal)
	poleModel:SetAttribute('Spin', 90)
	poleModel:AddTag('HoodMotion')
	poleModel.WorldPivot = pole:world(CFrame.new(41.2, 4, 0.6))
	-- Street corner, mailbox, newspaper box, a boombox on the stoop of the plaza.
	streetCorner(lobby, V(18.2, 0, 2.2), 'BLOCK ST', 'HOOD AVE')
	mailbox(lobby, V(-17.6, 0, 6), V(1, 0, 0))
	newsBox(lobby, V(-17.6, 0, 9.4), V(1, 0, 0))
	boombox(lobby, CFrame.new(-17.4, 0, 24) * CFrame.Angles(0, math.rad(-120), 0))
	-- A chalk hopscotch on the plaza between spawn and the street.
	for q = 0, 5 do
		local zz = 14 - q * 1.9
		local cols = (q == 2 or q == 4) and { -1, 1 } or { 0 }
		for _, c in cols do
			decor(lobby:box('Hopscotch', V(4 + c * 0.95 - 0.85, 0, zz - 0.85), V(4 + c * 0.95 + 0.85, 0.03, zz + 0.85), P.chalk[(q + c + 3) % #P.chalk + 1], M.SmoothPlastic)).CastShadow = false
		end
	end
	-- Lawn life.
	for k, t in { { V(-26, 0, 38), 'none' }, { V(-26, 0, 7), 'none' } } do tree(lobby, t[1], k * 13 + 5, 0.9, t[2]) end
	for k, pos in { V(-40, 0, 2), V(30, 0, 2), V(40, 0, 2), V(-38, 0, 42) } do bush(lobby, pos, k) end
	return lobby
end

---------------------------------------------------------------------------------------------- finale
-- Past gate 10: the Champ Ring in the middle of a clean plaza, the Kingpin statue, a trophy, and
-- Juniper Station, the way out to World 2 (with the only gold trim in World 1).
local function buildFinale(ctx, skins, art)
	local f = ctx:group('Finale')
	local zc = (FINALE_Z0 + FINALE_Z1) / 2
	local ring = skins.Stations[9]
	Props.ring(f:at(CFrame.new(0, 0, zc + 2) * CFrame.Angles(0, math.pi, 0)):group('Training_' .. ring.Id), PROPS_KIT, ring, 9)
	buildStatue(f:at(CFrame.new(-30, 0, zc + 2) * CFrame.Angles(0, math.pi, 0)), skins.ById.Kingpin, art)
	-- Trophy on a pedestal, spinning slowly.
	f:post('TrophyPedestal', 4, 3, V(30, 0, zc + 2), C(255, 200, 40), M.Plastic)
	decor(f:post('TrophyRim', 4.1, 0.3, V(30, 3, zc + 2), C(255, 236, 150), M.Neon))
	local cup, cupModel = f:group('Trophy')
	cup:box('CupBase', V(29, 3.3, zc + 1), V(31, 4.3, zc + 3), C(255, 200, 40), M.SmoothPlastic)
	cup:post('CupStem', 0.4, 1.6, V(30, 4.3, zc + 2), C(255, 200, 40), M.SmoothPlastic)
	cup:blob('Cup', V(4, 4, 4), V(30, 7.6, zc + 2), C(255, 200, 40), M.SmoothPlastic)
	for _, x in { 27.9, 32.1 } do cup:part('Handle', V(0.5, 1.8, 1.8), CFrame.new(x, 8, zc + 2), C(255, 200, 40), M.SmoothPlastic, Enum.PartType.Cylinder) end
	cupModel:SetAttribute('Spin', 30)
	cupModel:AddTag('HoodMotion')
	cupModel.WorldPivot = f:world(CFrame.new(30, 6, zc + 2))
	-- Juniper Station on the back wall.
	local st = f:at(CFrame.lookAt(V(0, 0, FINALE_Z0), V(0, 0, FINALE_Z0 + 1)))
	st:box('StationStep', V(-13.6, 0, -2.4), V(13.6, 0.6, -0.6), P.cream, M.SmoothPlastic)
	st:box('StationFace', V(-14, 0, -0.6), V(14, 13, 0), C(255, 244, 230), M.SmoothPlastic)
	st:box('StationStripe', V(-14, 0.6, -0.66), V(14, 1.4, -0.6), P.globe, M.SmoothPlastic)
	local portal = decor(st:box('Portal', V(-6, 0.6, -0.7), V(6, 9.6, -0.6), C(90, 220, 150), M.Neon))
	portal.Transparency = 0.25
	light(portal, C(120, 240, 160), 2, 18)
	local pg = surface(portal, Enum.NormalId.Front, 30)
	line(pg, 'Title', 'WORLD 2', P.white, FONT.loud, 0.2, 0.36, P.signGreen, 4)
	line(pg, 'Detail', 'COMING SOON', P.white, FONT.title, 0.6, 0.16, P.signGreen, 3)
	local sign = st:box('StationSign', V(-11, 10, -1.2), V(11, 12.6, -0.6), P.ink, M.SmoothPlastic)
	local sg = surface(sign, Enum.NormalId.Front, 30)
	line(sg, 'Title', 'JUNIPER STATION', P.white, FONT.title, 0.06, 0.52)
	line(sg, 'Detail', 'NEXT STOP: THE SUBURBS • COMING SOON', C(255, 220, 90), FONT.body, 0.62, 0.3)
	for _, e in { { V(-11.3, 9.7, -1.4), V(11.3, 10, -0.6) }, { V(-11.3, 12.6, -1.4), V(11.3, 12.9, -0.6) }, { V(-11.3, 9.7, -1.4), V(-11, 12.9, -0.6) }, { V(11, 9.7, -1.4), V(11.3, 12.9, -0.6) } } do
		st:box('GoldTrim', e[1], e[2], C(255, 200, 60), M.Metal)
	end
	for _, x in { -9, 9 } do
		st:post('GlobePost', 0.22, 6, V(x, 0, -2), P.signGreen)
		local globe = decor(st:blob('Globe', V(1.4, 1.4, 1.4), V(x, 6.7, -2), P.globe, M.Neon))
		light(globe, P.globe, 1, 14)
	end
	-- Era 3 dressing: boxwood planters along the plaza edges.
	for _, x in { -36, 36 } do
		for q = 0, 2 do
			local zz = FINALE_Z0 + 8 + q * 14
			f:box('Planter', V(x - 1.6, 0, zz - 1.6), V(x + 1.6, 1.6, zz + 1.6), P.cream, M.SmoothPlastic)
			f:part('Boxwood', V(3, 3, 3), CFrame.new(x, 3, zz), C(63, 166, 90), M.SmoothPlastic, Enum.PartType.Ball)
		end
	end
	return f
end

---------------------------------------------------------------------------------------------- horizon
-- The goal on the horizon (hood_style_and_bags.md 2.3): an Uptown skyline past the station and THE HILLS
-- lettered on a far hill, both faded by the atmosphere.
local function buildHorizon(ctx)
	local h = ctx:group('Horizon')
	local towers = { { -70, 70, 18 }, { -42, 110, 22 }, { -14, 86, 16 }, { 12, 128, 20 }, { 38, 96, 18 }, { 64, 76, 16 }, { 90, 60, 14 } }
	for k, t in towers do
		local x, ht, w = t[1], t[2], t[3]
		local z = -500 - (k % 3) * 18
		local glass = k % 2 == 0 and C(124, 196, 255) or C(201, 209, 220)
		decor(h:box('Tower', V(x - w / 2, 0, z - w / 2), V(x + w / 2, ht, z + w / 2), glass, M.SmoothPlastic)).CastShadow = false
		decor(h:box('TowerCap', V(x - w / 2 - 0.6, ht, z - w / 2 - 0.6), V(x + w / 2 + 0.6, ht + 1.2, z + w / 2 + 0.6), P.white, M.SmoothPlastic)).CastShadow = false
		for y = 10, ht - 8, 12 do
			decor(h:box('WindowStrip', V(x - w / 2 + 1, y, z + w / 2), V(x + w / 2 - 1, y + 1.2, z + w / 2 + 0.2), k % 3 == 0 and C(255, 46, 154) or C(34, 229, 255), M.Neon)).CastShadow = false
		end
	end
	local hill = decor(h:blob('Hill', V(320, 120, 160), V(-40, -20, -640), C(122, 200, 90), M.SmoothPlastic))
	hill.CastShadow = false
	local letters = ghost(h:box('HillsSign', V(-80, 22, -566), V(0, 34, -565.8), P.white))
	local hg = surface(letters, Enum.NormalId.Back, 6)
	pcall(function() hg.MaxDistance = 3000 end)
	line(hg, 'Title', 'THE HILLS', P.white, FONT.loud, 0, 1, C(255, 200, 61), 4)
	return h
end

---------------------------------------------------------------------------------------------- play here
-- Make The Block V2 the map the game runs on (players spawn here; gameplay services and the HUD use it),
-- or hand the game back to the original Block. Other spawn points are switched off, never deleted: each
-- remembers it was on (attribute HoodSpawnWasEnabled), and SetActive(false) switches it back on.
function V2.SetActive(on)
	local root = workspace:FindFirstChild('TheBlockV2')
	assert(root, 'Build The Block V2 first: require(game.ServerStorage.TheBlockV2).Build()')
	for _, d in workspace:GetDescendants() do
		if d:IsA('SpawnLocation') and not d:IsDescendantOf(root) then
			if on and d.Enabled then
				d:SetAttribute('HoodSpawnWasEnabled', true)
				d.Enabled = false
			elseif not on and d:GetAttribute('HoodSpawnWasEnabled') then
				d.Enabled = true
				d:SetAttribute('HoodSpawnWasEnabled', nil)
			end
		end
	end
	for _, d in root:GetDescendants() do
		if d:IsA('SpawnLocation') then d.Enabled = on end
	end
	root:SetAttribute('Active', on)
	pcall(function() game:GetService('ChangeHistoryService'):SetWaypoint('TheBlockV2 active ' .. tostring(on)) end)
	print(on and '[TheBlockV2] Active: press Play to spawn here. SetActive(false) gives the game back to the original Block.'
		or '[TheBlockV2] Inactive: the original Block is the game map again.')
end

---------------------------------------------------------------------------------------------- street furniture
local function roadPaint(ctx)
	local r = ctx:group('RoadPaint')
	for z = FINALE_Z1 + 2, -2, 8 do
		local near = false
		for i = 1, 10 do if z + 4 > stageZ(i) - 16 and z < stageZ(i) + 16 then near = true end end
		if not near then r:box('CentreDash', V(-0.2, 0, z), V(0.2, 0.04, z + 4), P.roadLine, M.SmoothPlastic) end
	end
	return r
end
-- Street lamps on the side away from each alcove, string lights across the Avenue stretch.
local function streetLife(ctx)
	local life = ctx:group('StreetLife')
	for _, z in { 12, 36 } do
		lamp(life, V(-18.6, 0, z), V(1, 0, 0))
		lamp(life, V(18.6, 0, z), V(-1, 0, 0))
	end
	stringLights(life, V(-18.6, 11.6, 36), V(18.6, 11.6, 36), 2, false)
	stringLights(life, V(-18.6, 11.6, 12), V(18.6, 11.6, 12), 2, true)
	for k, seg in SEGMENTS do
		local free = -seg.side
		lamp(life, V(free * 18.6, 0, stageZ(k) - 21), V(-free, 0, 0))
	end
	-- From the Avenue on, string lights cross the street just past each gate, wall to wall.
	for _, k in { 6, 7, 8, 9 } do stringLights(life, V(-19.9, 6.6, stageZ(k) - 6), V(19.9, 6.6, stageZ(k) - 6), 1.4, k == 8) end
	hydrant(life, V(13.2, 0, 20))
	trashCan(life, V(14.6, 0, 6))
	bench(life, V(-14.5, 0, 40), V(0, 0, -1))
	return life
end
local function rooftops(ctx, tier)
	local roof = ctx:group('Rooftops')
	local function at(x, z, r) local y = roofTop(tier, x, z, r); return y and V(x, y, z) end
	-- The lobby skyline: water towers (the block's signature) and AC units.
	for _, p in { V(-56, 0, 56), V(52, 0, 60), V(-4, 0, 60), V(72, 0, 24) } do
		local q = at(p.X, p.Z, 3.4)
		if q then waterTower(roof, q) end
	end
	for k, seg in SEGMENTS do
		local z = stageZ(k)
		local free = -seg.side
		local e = era(z - 20)
		local q = at(free * 40, z - 20, 3.4)
		if q and e < 3 and k % 2 == 1 then waterTower(roof, q) end
		q = at(free * 32, z - 8, 1.4)
		if q and e < 3 then acUnit(roof:at(CFrame.new(q) * CFrame.Angles(0, k * math.pi / 2, 0))) end
		q = at(free * 24, z - 30, 3.4)
		if q and e >= 2 then tree(roof, q, 100 + k * 7, 0.95, 'z') end
		q = at(seg.side * 44, z - 22, 3.4)
		if q and e == 3 then tree(roof, q, 200 + k * 7, 0.95, 'z') end
	end
	for _, x in { -48, 48 } do
		local q = at(x, (FINALE_Z0 + FINALE_Z1) / 2, 3.4)
		if q then tree(roof, q, 300 + x, 1, 'z') end
	end
	return roof
end

---------------------------------------------------------------------------------------------- build
function V2.Build()
	Props = require(game:GetService('ServerStorage').HoodProps)
	PROPS_KIT = { studs = studs, decor = decor, ghost = ghost, light = light, surface = surface, line = line, billboard = billboard, compact = compact, FONT = FONT }
	local skins = require(ReplicatedStorage.Shared.Config.Skins)
	local maps = require(ReplicatedStorage.Shared.Config.Maps)
	local crew = require(ReplicatedStorage.Shared.Config.Crew)
	local art = require(ReplicatedStorage.Shared.SkinArt)

	local old = workspace:FindFirstChild('TheBlockV2')
	if old then
		local backup = Instance.new('Folder')
		backup.Name = 'TheBlockV2_Before_' .. os.date('!%Y%m%d_%H%M%S')
		backup.Parent = game:GetService('ServerStorage')
		old.Parent = backup
	end
	local root = Instance.new('Model')
	root.Name = 'TheBlockV2'
	root:SetAttribute('BuildVersion', 'V2 street 1')
	root:SetAttribute('Origin', V2.Origin.Position)
	local ctx = newCtx(root, CFrame.new())

	local floors = planFloors()
	local tier = planTerraces(floors)
	buildGround(ctx, floors)
	buildTerraces(ctx, tier)
	-- Faces that get no windows, doors, tags or cornice because something stands against them.
	local reserved = {
		{ alongX = true, at = 44, a = -18, b = 18 }, -- leaderboards
		{ alongX = false, at = -44, a = 13, b = 31 }, -- the bodega
		{ alongX = false, at = 60, a = 4, b = 40 }, { alongX = true, at = 4, a = 44, b = 60 }, { alongX = true, at = 40, a = 44, b = 60 }, -- shop building
		{ alongX = false, at = 44, a = 0, b = 4 }, { alongX = false, at = 44, a = 40, b = 44 },
		{ alongX = true, at = FINALE_Z0, a = -16, b = 16 }, -- Juniper Station
		{ alongX = true, at = 0, a = 23, b = 42 }, -- barbershop
	}
	for i = 1, 10 do
		for _, x in { -20, 20 } do table.insert(reserved, { alongX = false, at = x, a = stageZ(i) - 3, b = stageZ(i) + 3 }) end
	end
	for k, seg in SEGMENTS do
		local x0, z0, x1, z1 = alcove(k)
		table.insert(reserved, { alongX = false, at = seg.side * 36, a = z0, b = z1 })
	end
	-- Doors with stoops (and street-level flower boxes) also keep clear of lamps, alcove side walls,
	-- the glove pier and the scaffolding at stage 6.
	local doorAvoid = { { alongX = true, at = 0, a = -28, b = -20 } }
	for k, seg in SEGMENTS do
		local x0, z0, x1, z1 = alcove(k)
		for _, zz in { z0, z1 } do table.insert(doorAvoid, { alongX = true, at = zz, a = x0, b = x1 }) end
		table.insert(doorAvoid, { alongX = false, at = -seg.side * 20, a = stageZ(k) - 24, b = stageZ(k) - 18 })
	end
	for _, x in { -20, 20 } do table.insert(doorAvoid, { alongX = false, at = x, a = stageZ(6) + 2, b = stageZ(6) + 16 }) end
	local faces = terraceFaces(floors, tier)
	decorateFaces(ctx, faces, reserved, doorAvoid)
	buildLips(ctx, faces, reserved)

	buildLobby(ctx, skins, crew, art)
	local street = ctx:group('Street')
	local walls = maps.ById.Block.Walls
	for i, w in walls do
		local seg = SEGMENTS[i]
		buildGate(street, i, w, seg and -seg.side or nil)
		local before = SEGMENTS[i - 1]
		stageProps(street, i, stageZ(i), before and -before.side or -1)
	end
	for k = 1, #SEGMENTS do buildAlcove(street, k, skins) end
	buildFinale(ctx, skins, art)
	buildHorizon(ctx)
	streetLife(ctx)
	roadPaint(ctx)
	rooftops(ctx, tier)

	root.Parent = workspace
	local count = 0
	for _, d in root:GetDescendants() do if d:IsA('BasePart') then count += 1 end end
	-- Shadows from the terraces lining the street are what made it read dark; the sun still shades props.
	for _, d in root:GetDescendants() do
		if d:IsA('BasePart') and (d.Name == 'TerraceBlock' or d.Name == 'TerraceRoof' or d.Name == 'TerraceGrass' or d.Name == 'Cornice' or d.Name == 'GrassLip') then d.CastShadow = false end
	end
	pcall(function() game:GetService('ChangeHistoryService'):SetWaypoint('TheBlockV2 built') end)
	pcall(function() require(game:GetService('ServerStorage').HoodLighting).Apply('FrontPage') end)
	V2.SetActive(true)
	print(string.format('[TheBlockV2] Built %d parts at %s. Press Play to spawn on the Block; select TheBlockV2 and press F to fly there.', count, tostring(V2.Origin.Position)))
	return { parts = count }
end

return V2
