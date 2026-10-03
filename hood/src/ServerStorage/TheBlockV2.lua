-- The Block, version 2: World 1 rebuilt to match the reference screenshots the team picked (a "+1"
-- simulator lobby: lime studded grass, stepped brown cliffs with grass tops and blocky trees, grey studded
-- plazas with dark trim, a grey morph stand with cyan pads, grey gallows bags on diamond-plate pads), then a
-- real-looking hood street for the stages. Colour lives on the things you use; everything else stays calm.
-- Edit-time builder: creates or replaces Workspace.TheBlockV2, makes it the map the game runs on, and
-- applies the Front-page Day lighting (both reversible: SetActive(false), HoodLighting.Restore()).
-- Command Bar:  require(game.ServerStorage.TheBlockV2).Build()
--
-- Layout (local studs, floor top at y = 0, -Z runs from the lobby down the street):
--   lobby    x -88..88, z 0..128   grass bowl ringed by cliffs. Spawn plaza at z 92..116, the bag stations
--                                  either side of the main walk, the morph stand east, boards and portal west
--   street   x -24..24, z 0..-500  ten stage walls 48 studs apart; brick buildings line both sides
--   cliffs   three stepped tiers (10 / 18 / 26 studs) around everything walkable
local V2 = {}
local Props, PROPS_KIT -- ServerStorage.HoodProps (the Champ Ring) and the helpers it borrows, set in Build

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local V, C = Vector3.new, Color3.fromRGB
local M = Enum.Material
local S = Enum.SurfaceType

V2.Origin = CFrame.new(2400, 0, 0)

-- Palette, sampled from the reference screenshots and kept small: grass, cliff, concrete, one accent each.
local P = {
	grassA = C(132, 204, 74), grassB = C(124, 196, 68), cap = { C(116, 190, 62), C(108, 182, 58) },
	cliff = { C(184, 120, 96), C(170, 108, 86) },
	plazaA = C(206, 214, 232), plazaB = C(192, 200, 222), edge = C(140, 150, 180), pad = C(100, 114, 150), truss = C(150, 160, 186),
	cyan = C(0, 236, 255), magenta = C(255, 30, 255), padYellow = C(255, 248, 50),
	leaf = { C(120, 196, 66), C(108, 186, 60), C(130, 204, 74) }, bark = C(150, 96, 66),
	wood = C(152, 88, 56), woodDark = C(104, 66, 44), rubble = C(132, 140, 164),
	board = C(30, 64, 136), boardFrame = C(116, 122, 140),
	-- The hood: brick, concrete, asphalt and dark iron; colour only on signs, awnings and the odd door.
	asphalt = C(66, 68, 74), sidewalk = C(196, 196, 198), sidewalkB = C(186, 186, 189), curb = C(156, 156, 160),
	lineYellow = C(232, 196, 64), lineWhite = C(236, 236, 236),
	brick = { C(150, 74, 56), C(132, 64, 50), C(168, 96, 70), C(116, 84, 70), C(158, 152, 144), C(140, 82, 60) },
	stone = C(222, 216, 204), glass = C(46, 56, 72), glassLit = C(236, 206, 140),
	iron = C(46, 46, 52), shutter = C(150, 154, 160), roof = C(92, 92, 98),
	awning = { C(40, 112, 64), C(168, 44, 44), C(232, 186, 48), C(40, 70, 130) },
	-- Small accents used by kept helpers (pets, court, hydrant, crates).
	white = C(248, 248, 248), black = C(26, 26, 30), ink = C(26, 26, 30), red = C(200, 44, 48), orange = C(240, 130, 46),
	yellow = C(255, 204, 48), navy = C(28, 44, 92), glassBlue = C(64, 92, 118),
	flower = { C(255, 70, 160), C(255, 210, 63), C(255, 255, 255), C(99, 191, 255) },
	crate = { C(47, 123, 255), C(200, 44, 48), C(40, 140, 80) },
}
P.trim = P.stone -- window frames and sills in kept helpers
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
local G = { x0 = -120, x1 = 120, z0 = -552, z1 = 160 }
local NX, NZ = (G.x1 - G.x0) / CELL, (G.z1 - G.z0) / CELL

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

---------------------------------------------------------------------------------------------- layout
-- Stage walls 48 studs apart down the street; stage i's block is the 48 studs behind wall i.
local STAGE_GAP, STAGE_FIRST = 48, -16
local function stageZ(i) return STAGE_FIRST - (i - 1) * STAGE_GAP end
local STREET_END = stageZ(10) - 56 -- -504: the station closes the street
V2.StageZ = stageZ

-- Bag stations in the lobby, either side of the main walk (tier order: nearest the spawn first).
local STATIONS = {
	{ x = -14, z = 62 }, { x = 14, z = 62 }, { x = -30, z = 62 }, { x = 30, z = 62 },
	{ x = -14, z = 44 }, { x = 14, z = 44 }, { x = -30, z = 44 }, { x = 30, z = 44 },
}
V2.Stations = STATIONS
local SPAWN = V(0, 0, 100)
local FACADE, ROAD, SW = 20, 10, 0.6 -- building line and kerb line (x = ±), sidewalk height
local CANYON = STAGE_FIRST -- the street runs between cliffs down to here, then the buildings start

local PLAN -- the floor plan of the current build (set in Build)
-- Walkable floor plan. Later paints win. 'pit' cells get no floor and no cliff (a building stands there).
local function planFloors()
	local g = newGrid()
	-- The lobby bowl.
	paint(g, -72, 0, 72, 120, 'lawn')
	paint(g, -12, 88, 12, 112, 'path') -- spawn plaza
	paint(g, -8, 72, 8, 88, 'path') -- walk to the stations
	paint(g, -40, 36, 40, 72, 'path') -- station plaza
	paint(g, -8, 0, 8, 36, 'path') -- main walk on to the street
	paint(g, 12, 92, 40, 100, 'path') -- branch east to the morph stand
	paint(g, 40, 68, 72, 112, 'path') -- morph stand platform
	paint(g, -40, 92, -12, 100, 'path') -- branch west to the boards
	paint(g, -72, 68, -40, 112, 'path') -- leaderboards
	paint(g, -64, 40, -40, 60, 'path') -- World 2 portal
	paint(g, 40, 40, 64, 60, 'path') -- the stash
	-- The street (road and sidewalks come from the street builder), buildings either side once it leaves
	-- the canyon, the station across its end.
	paint(g, -FACADE, STREET_END, FACADE, 0, 'street')
	paint(g, -FACADE - 40, STREET_END - 24, -FACADE, CANYON, 'pit')
	paint(g, FACADE, STREET_END - 24, FACADE + 40, CANYON, 'pit')
	paint(g, -FACADE, STREET_END - 24, FACADE, STREET_END, 'pit')
	return g
end
---------------------------------------------------------------------------------------------- ground and cliffs
-- Floors: grass in 8-stud checker tiles, plazas in 4-stud white/grey tiles with dark diamond-plate trim
-- where they meet the grass. The street builds its own road and sidewalks.
local function buildGround(ctx, floors)
	local ground = ctx:group('Ground')
	local function key(i, j)
		local k = floors[i][j]
		if not k or k == 'pit' or k == 'street' then return nil end
		if k == 'lawn' then return 'lawn' .. (math.floor((i - 1) / 2) + math.floor((j - 1) / 2)) % 2 end
		if k == 'path' then return 'path' .. ((i + j) % 2) end
		return k
	end
	local look = {
		lawn0 = { P.grassA, M.Plastic, 0, true }, lawn1 = { P.grassB, M.Plastic, 0, true },
		path0 = { P.plazaA, M.Plastic, 0, true }, path1 = { P.plazaB, M.Plastic, 0, true },
	}
	merge(key, function(k, x0, z0, x1, z1)
		local l = look[k]
		local p = ground:box('Floor_' .. k:gsub('%d', ''), V(x0, -1, z0), V(x1, l[3], z1), l[1], l[2])
		if l[4] then studs(p) end
	end)
	-- Dark trim where a plaza meets grass (reference: chunky diamond-plate borders, a step up from both).
	local rim = ground:group('PlazaTrim')
	local W, H = 1.2, 0.45
	local function isPath(i, j) local k = floors[i] and floors[i][j]; return k == 'path' end
	local function isLawn(i, j) local k = floors[i] and floors[i][j]; return k == 'lawn' end
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
					rim:box('Trim', V(x0, 0, z), V(x1, H, z - dz * W), P.edge, M.DiamondPlate)
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
					rim:box('Trim', V(x, 0, z0), V(x - dx * W, H, z1), P.edge, M.DiamondPlate)
				end
				j += 1
			end
		end
	end
end

-- Cliffs on an 8-stud grid (pairs of floor cells). Every column rises in 8-stud layers that alternate
-- two browns, so the faces read as the reference's big checkered blocks, under a grass cap that hangs over
-- each open edge. Height grows with distance from where you can walk, plus blocky noise so the ledges step
-- unevenly; columns next to a building are left out.
local LAYER, CAP, LIP = 8, 1.2, 0.7
local BX, BZ = NX // 2, NZ // 2
local function planCliffs(floors)
	local walk, pit = {}, {}
	for bi = 1, BX do
		walk[bi], pit[bi] = {}, {}
		for bj = 1, BZ do
			for _, c in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
				local k = floors[2 * bi - 1 + c[1]][2 * bj - 1 + c[2]]
				if k == 'pit' then pit[bi][bj] = true elseif k then walk[bi][bj] = true end
			end
		end
	end
	local dist, queue, head = {}, {}, 1
	for bi = 1, BX do
		dist[bi] = {}
		for bj = 1, BZ do
			if walk[bi][bj] or pit[bi][bj] then dist[bi][bj] = 0; table.insert(queue, { bi, bj }) end
		end
	end
	while head <= #queue do
		local bi, bj = queue[head][1], queue[head][2]
		head += 1
		for di = -1, 1 do
			for dj = -1, 1 do
				local a, b = bi + di, bj + dj
				if a >= 1 and a <= BX and b >= 1 and b <= BZ and dist[a][b] == nil then
					dist[a][b] = dist[bi][bj] + 1
					table.insert(queue, { a, b })
				end
			end
		end
	end
	-- Layers per column: 1-2 at the foot, up to 5 at the back; nothing past six columns out.
	local h = {}
	for bi = 1, BX do
		h[bi] = {}
		for bj = 1, BZ do
			local d = dist[bi][bj]
			if d and d >= 1 and d <= 6 then
				local bump = hash(bi // 3 + 7, bj // 3 + 3) % 3
				local foot = d == 1 and hash(bi // 2 + 1, bj // 2 + 9) % 2 or 0
				h[bi][bj] = math.min(6, math.max(1, d + (bump == 0 and 1 or 0) - (bump == 2 and d > 2 and 1 or 0) + foot))
			else
				h[bi][bj] = 0
			end
		end
	end
	return { h = h, pit = pit, dist = dist }
end
local function blockRect(bi, bj) return G.x0 + (bi - 1) * 8, G.z0 + (bj - 1) * 8, G.x0 + bi * 8, G.z0 + bj * 8 end
local function blockOf(x, z) return math.floor((x - G.x0) / 8) + 1, math.floor((z - G.z0) / 8) + 1 end
-- Top of the cliff column under (x, z), or nil where there's no cliff.
local function cliffTop(cliffs, x, z)
	local bi, bj = blockOf(x, z)
	local n = cliffs.h[bi] and cliffs.h[bi][bj]
	return n and n > 0 and n * LAYER or nil
end
local function buildCliffs(ctx, cliffs)
	local t = ctx:group('Cliffs')
	local h, pit = cliffs.h, cliffs.pit
	local function nb(bi, bj)
		if bi < 1 or bi > BX or bj < 1 or bj > BZ then return 99 end
		if pit[bi][bj] then return 99 end -- against a building: nobody sees that side
		return h[bi][bj]
	end
	for bi = 1, BX do
		for bj = 1, BZ do
			local n = h[bi][bj]
			if n > 0 then
				local x0, z0, x1, z1 = blockRect(bi, bj)
				local W, E, S_, N = nb(bi - 1, bj), nb(bi + 1, bj), nb(bi, bj - 1), nb(bi, bj + 1)
				local low = math.min(W, E, S_, N)
				-- Layers nobody can see (below every neighbour's top) are left out.
				for L = math.max(1, math.min(low, n - 1) + 1), n do
					local y0 = L == 1 and -1 or (L - 1) * LAYER
					local y1 = L == n and n * LAYER - CAP or L * LAYER
					local color = P.cliff[(bi + bj + L) % 2 + 1]
					studs(t:box('Cliff', V(x0, y0, z0), V(x1, y1, z1), color, M.Plastic), true)
				end
				local top = n * LAYER
				local function lip(o) return o < n and LIP or 0 end
				local cap = t:box('CliffGrass', V(x0 - lip(W), top - CAP - (low < n and 0.5 or 0), z0 - lip(S_)), V(x1 + lip(E), top, z1 + lip(N)), P.cap[(bi + bj) % 2 + 1], M.Plastic)
				studs(cap, true)
			end
		end
	end
	return t
end
---------------------------------------------------------------------------------------------- lobby props
-- Blocky tree (reference): a studded trunk that forks into two arms, each carrying a big studded leaf
-- block, with a smaller block on top. scale 1 is about 18 studs tall.
local function tree(ctx, pos, seed, scale)
	scale = scale or 1
	local r = Random.new(seed)
	local s = scale
	local t = ctx:at(CFrame.new(pos) * CFrame.Angles(0, math.rad(r:NextInteger(0, 3) * 90 + r:NextNumber(-10, 10)), 0)):group('Tree')
	local trunk = 7 * s + r:NextNumber(0, 2) * s
	studs(t:box('Trunk', V(-1.1 * s, -0.5, -1.1 * s), V(1.1 * s, trunk, 1.1 * s), P.bark, M.Plastic), true)
	local lean = r:NextNumber(-0.25, 0.25)
	for k, side in { -1, 1 } do
		local top = V(side * 3.2 * s, trunk + 3.2 * s, lean * 4 * s)
		local arm = t:bar('Branch', V(0, trunk - 0.8 * s, 0), top, 1.2 * s, P.bark, M.Plastic)
		studs(arm, true)
		local w = (k == 1 and 8 or 9.5) * s + r:NextNumber(0, 1.5) * s
		local hgt = 5 * s + r:NextNumber(0, 1) * s
		studs(t:box('Leaves', top + V(-w / 2, -1, -w / 2), top + V(w / 2, hgt - 1, w / 2), P.leaf[k], M.Plastic), true)
	end
	local w = 6 * s
	studs(t:box('LeavesTop', V(-w / 2, trunk + 3.2 * s + 4 * s, -w / 2 + lean * 3 * s), V(w / 2, trunk + 3.2 * s + 8 * s, w / 2 + lean * 3 * s), P.leaf[3], M.Plastic), true)
	return t
end

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
---------------------------------------------------------------------------------------------- lawn details
-- Grass tufts: three thin blades leaning out, a cheap "alive" detail the reference scatters everywhere.
local function tuft(ctx, pos, seed)
	local r = Random.new(seed)
	local t = ctx:at(CFrame.new(pos) * CFrame.Angles(0, r:NextNumber(0, math.pi), 0)):group('Tuft')
	for k = -1, 1 do
		local h = 1.2 + r:NextNumber(0, 0.8)
		decor(t:part('Blade', V(0.28, h, 0.28), CFrame.new(k * 0.32, h / 2, 0) * CFrame.Angles(0, 0, math.rad(-k * 14)), P.cap[1]:Lerp(P.leaf[2], 0.3), M.SmoothPlastic)).CastShadow = false
	end
	return t
end
-- Grey studded rubble blocks (reference: a small pile near the cliffs).
local function rubble(ctx, pos, seed)
	local r = Random.new(seed)
	local g = ctx:at(CFrame.new(pos) * CFrame.Angles(0, r:NextNumber(0, math.pi), 0)):group('Rubble')
	studs(g:box('Block', V(-1.6, 0, -1.2), V(1.6, 1.8, 1.2), P.rubble, M.Plastic), true)
	studs(g:box('Block', V(1.6, 0, -0.8), V(3.2, 1.2, 0.8), P.rubble, M.Plastic), true)
	studs(g:box('Block', V(-1.0, 1.8, -0.8), V(0.8, 2.8, 0.8), P.rubble, M.Plastic), true)
	return g
end

---------------------------------------------------------------------------------------------- lobby pieces
-- Steel truss beam from a to b along one axis (TrussPart: the reference's grey X-braced gallows).
local function truss(ctx, name, center, length, axis, color)
	local p = Instance.new('TrussPart')
	p.Name = name
	p.Anchored = true
	p.Size = V(2, length, 2)
	local rot = axis == 'x' and CFrame.Angles(0, 0, math.pi / 2) or axis == 'z' and CFrame.Angles(math.pi / 2, 0, 0) or CFrame.new()
	p.CFrame = ctx:world(CFrame.new(center) * rot)
	p.Color = color
	p.Material = M.Plastic
	p.Parent = ctx.parent
	return p
end
local function emit(holder, props)
	local e = Instance.new('ParticleEmitter')
	for k, v in props do
		if k == 'Preview' then e:SetAttribute('PreviewTexture', v) else e[k] = v end
	end
	e.Parent = holder
	return e
end

-- Bag station (reference: a two-step diamond-plate pad, a grey truss gallows on the back-left corner, a
-- barrel bag on a strap). Each tier keeps the shape and changes the set's colour and effects; locked
-- stations show as black silhouettes on each player's screen (HoodClient/Lobby paints the Equipment).
-- Frame: origin at the pad centre, -Z toward the walk.
local SETS = {
	Starter = { pad = P.pad, frame = P.truss, bag = 'tires' },
	Tape = { pad = P.pad, frame = P.truss, bag = P.wood, band = C(196, 200, 206) },
	Street = { pad = P.pad, frame = P.truss, bag = C(70, 96, 150), band = C(232, 232, 236) },
	Heavy = { pad = C(96, 100, 112), frame = C(70, 72, 80), bag = C(186, 40, 44), band = C(30, 30, 34) },
	Speed = { pad = C(132, 70, 196), frame = C(150, 86, 214), bag = C(170, 96, 230), band = C(96, 44, 150), fx = 'fire' },
	DoubleEnd = { pad = C(30, 150, 200), frame = C(40, 170, 220), bag = C(64, 200, 240), band = C(20, 100, 150), fx = 'spark' },
	Pro = { pad = C(30, 170, 70), frame = C(40, 200, 80), bag = C(60, 230, 100), band = C(20, 110, 50), fx = 'smoke', neon = true },
	Gold = { pad = C(236, 196, 40), frame = C(250, 214, 60), bag = C(255, 222, 70), band = C(200, 150, 20), fx = 'sparkle', neon = true },
}
local function buildStation(ctx, s, tier)
	local set = SETS[s.Id]
	local st, model = ctx:group('Training_' .. s.Id)
	local eq = st:group('Equipment')
	-- Two-step studded pad.
	studs(eq:box('Pad', V(-6, 0, -5), V(6, 0.45, 5), set.pad:Lerp(C(0, 0, 0), 0.12), M.DiamondPlate))
	studs(eq:box('PadTop', V(-5.2, 0.45, -4.2), V(5.2, 0.9, 4.2), set.pad, M.DiamondPlate))
	-- Truss gallows: a post on the back-left corner, an arm over the bag, a diagonal brace.
	truss(eq, 'Post', V(-3.6, 0.9 + 5, 2.6), 10, 'y', set.frame)
	truss(eq, 'Arm', V(-1.6, 11.9, 2.6), 6, 'x', set.frame)
	eq:bar('Brace', V(-3.6, 8.2, 2.6), V(-1.0, 10.9, 2.6), 0.5, set.frame, M.Plastic)
	local hangX, hangZ = 0.4, 2.6
	-- The bag: a barrel (fat middle, two dark bands) on a short strap, or a tyre stack for the starter.
	local bottom, height = 3.4, 4.6
	if set.bag == 'tires' then
		for k = 0, 2 do
			local y = 3.6 + k * 1.3
			eq:blob('Tire', V(3.2, 1.1, 3.2), V(hangX, y, hangZ), C(40, 40, 46), M.SmoothPlastic)
			eq:post('TireHole', 0.62, 1.12, V(hangX, y - 0.56, hangZ), C(16, 16, 20), M.SmoothPlastic)
		end
		eq:bar('Rope', V(hangX, 7.2, hangZ), V(hangX, 10.9, hangZ), 0.24, C(176, 140, 90), M.Fabric)
	else
		local mat = set.neon and M.SmoothPlastic or (s.Id == 'Tape' and M.WoodPlanks or M.SmoothPlastic)
		eq:post('BagEnd', 1.15, height * 0.2, V(hangX, bottom, hangZ), set.bag, mat)
		eq:post('BagBelly', 1.32, height * 0.6, V(hangX, bottom + height * 0.2, hangZ), set.bag, mat)
		eq:post('BagEnd', 1.15, height * 0.2, V(hangX, bottom + height * 0.8, hangZ), set.bag, mat)
		for _, f in { 0.2, 0.8 } do eq:post('BagBand', 1.36, 0.36, V(hangX, bottom + height * f - 0.18, hangZ), set.band, set.neon and M.Neon or M.SmoothPlastic) end
		eq:post('BagCap', 1.0, 0.25, V(hangX, bottom + height, hangZ), set.band, M.SmoothPlastic)
		eq:bar('Strap', V(hangX, bottom + height + 0.25, hangZ), V(hangX, 10.9, hangZ), 0.3, C(40, 36, 34), M.Fabric)
	end
	-- Higher tiers glow and shed particles (reference: fire on the purple set, smoke on green, sparkles on gold).
	if set.fx then
		local shell = ghost(st:box('FX', V(-4.6, 0.9, -3.8), V(4.6, 1.2, 3.8), P.white))
		local fxProps = {
			fire = { Texture = 'rbxasset://textures/particles/fire_main.dds', Preview = 'glow', Rate = 18, Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(2, 4),
				Size = NumberSequence.new(0.9, 0.1), Color = ColorSequence.new(C(255, 210, 90), C(255, 80, 30)), LightEmission = 1, LightInfluence = 0, SpreadAngle = Vector2.new(10, 10) },
			spark = { Texture = 'rbxasset://textures/particles/sparkles_main.dds', Preview = 'sparkle', Rate = 8, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(1, 3),
				Size = NumberSequence.new(0.6, 0), Color = ColorSequence.new(C(200, 250, 255), set.bag), LightEmission = 1, LightInfluence = 0 },
			smoke = { Texture = 'rbxasset://textures/particles/smoke_main.dds', Preview = 'smoke', Rate = 6, Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(1, 2),
				Size = NumberSequence.new(1.5, 3), Color = ColorSequence.new(C(60, 200, 90), C(20, 60, 30)), Transparency = NumberSequence.new(0.4, 1), LightInfluence = 0 },
			sparkle = { Texture = 'rbxasset://textures/particles/sparkles_main.dds', Preview = 'sparkle', Rate = 12, Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(0.5, 2),
				Size = NumberSequence.new(0.7, 0), Color = ColorSequence.new(C(255, 255, 220), set.bag), LightEmission = 1, LightInfluence = 0 },
		}
		emit(shell, fxProps[set.fx])
	end
	local zone = st:box('TrainingZone', V(-4.4, 0.9, -3.6), V(4.4, 0.96, 3.6), set.pad, M.SmoothPlastic)
	zone.Transparency, zone.CanCollide, zone.CastShadow = 1, false, false
	-- Floating label (the reference's "x50 Power / Locked"); the client rewrites Detail as you progress.
	local label = billboard(st, V(0, 14.2, 0), 7, 2.2, {
		{ 'Title', 'x' .. s.Multiplier .. ' POWER', set.neon and set.bag or C(255, 255, 255), FONT.loud, 0, 0.55 },
		{ 'Detail', s.Required == 0 and 'FREE' or compact(s.Required) .. ' POWER', C(255, 255, 255), FONT.title, 0.57, 0.4 },
	})
	label.Name = 'Sign'
	label.WorldLabel.MaxDistance = 80
	model:SetAttribute('Tier', tier)
	model:SetAttribute('HitPoint', st:world(CFrame.new(hangX, bottom + height / 2, hangZ)).Position)
	model:SetAttribute('HitColor', set.neon and set.bag or C(255, 220, 120))
	return model
end

-- Morph stand (reference: a grey studded bleacher with stairs at both ends; every look on a white tile
-- with a cyan glowing square, a price label over its head). Frame: origin front-centre, -Z to the crowd.
local function buildMorphStand(ctx, skins, art)
	local st = ctx:group('MorphStand')
	local cols, spacing, depth, rise = 5, 6.4, 6, 3.2
	local hw = cols * spacing / 2 + 1
	for row = 0, 2 do
		local z0 = 1 + row * depth
		studs(st:box('Tier', V(-hw, 0, z0), V(hw, (row + 1) * rise + 0.4, z0 + depth), row % 2 == 0 and C(146, 158, 190) or C(156, 168, 198), M.Plastic), true)
	end
	-- Stairs up both ends.
	for _, side in { -1, 1 } do
		for k = 1, 9 do
			studs(st:box('Step', V(side * hw, 0, (k - 1) * 2 + 1), V(side * (hw + 3.2), k * 0.95, 3 * depth + 1), C(150, 162, 194), M.Plastic), true)
		end
	end
	local morphs = st:group('Morphs', 'Folder')
	for row = 0, 2 do
		local floor, z = row * rise + 0.4, 1 + row * depth + depth / 2
		for col = 1, cols do
			local s = skins.List[row * cols + col]
			local x = (col - (cols + 1) / 2) * spacing
			local stand = morphs:group('Skin_' .. s.Id)
			studs(stand:box('Tile', V(x - 2.2, floor + rise, z - 2.2), V(x + 2.2, floor + rise + 0.3, z + 2.2), P.plazaA, M.Plastic))
			decor(stand:box('Glow', V(x - 1.8, floor + rise + 0.3, z - 1.8), V(x + 1.8, floor + rise + 0.36, z + 1.8), P.cyan, M.Neon))
			art.mannequin(stand.parent, stand:world(CFrame.new(x, floor + rise + 0.26, z)), s, 0.86)
			local label = billboard(stand, V(x, floor + rise + 0.26 + 5.6 * 0.86 + 1.2, z), 4.6, 1.5, {
				{ 'Title', (s.Required == 0 and '🏆 FREE' or '🏆 ' .. compact(s.Required)), C(255, 255, 255), FONT.title, 0, 0.36 },
				{ 'Detail', 'BUY', C(255, 210, 63), FONT.loud, 0.36, 0.34 },
				{ 'Gain', '+' .. s.Gain .. '/sec', C(255, 255, 255), FONT.title, 0.7, 0.3 },
			})
			label.WorldLabel.MaxDistance = 60
			ghost(stand:box('Interact', V(x - 1.2, floor + rise, z - 3.6), V(x + 1.2, floor + rise + 0.1, z - 1.8), P.white))
		end
	end
	return st
end

-- Leaderboard (reference: a tall board between two studded grey pillars, dark blue screen, title on top).
local function leaderboard(ctx, title, color, name)
	local b = ctx:group(name)
	for _, x in { -6.2, 6.2 } do
		studs(b:box('Pillar', V(x - 1, 0, -1), V(x + 1, 17, 1), P.boardFrame, M.Plastic), true)
		studs(b:box('PillarCap', V(x - 1.3, 17, -1.3), V(x + 1.3, 17.8, 1.3), P.edge, M.Plastic), true)
	end
	studs(b:box('Frame', V(-5.2, 2.6, -0.6), V(5.2, 16.4, 0.6), P.boardFrame, M.Plastic), true)
	local screen = b:box('Board', V(-4.6, 3.2, -0.7), V(4.6, 15.8, -0.6), P.board, M.SmoothPlastic)
	local rows = {}
	for q = 1, 10 do table.insert(rows, '#' .. q .. '   — — —') end
	local t = line(surface(screen, Enum.NormalId.Front, 30), 'TextLabel', table.concat(rows, '\n'), P.white, FONT.title, 0.03, 0.94)
	t.TextXAlignment = Enum.TextXAlignment.Left
	local header = ghost(b:box('Header', V(-7, 17.9, -0.1), V(7, 20.9, 0), P.white))
	line(surface(header, Enum.NormalId.Front, 25), 'Title', title, color, FONT.loud, 0, 1, C(60, 30, 10), 3)
	return b
end

-- The Bodega Box on a red pedestal (reference: eggs on red pedestals), with its four crew pets around it.
local function bodegaBox(ctx, crew)
	local e = ctx:group('BodegaBox')
	e:post('Pedestal', 2.4, 2.2, V(0, 0, 0), C(206, 44, 52), M.SmoothPlastic)
	e:post('PedestalRim', 2.55, 0.35, V(0, 2.2, 0), P.white, M.SmoothPlastic)
	e:box('Box', V(-1.5, 2.55, -1.5), V(1.5, 5.3, 1.5), C(196, 150, 98), M.Cardboard)
	e:box('Tape', V(-1.52, 5.0, -0.3), V(1.52, 5.32, 0.3), C(214, 190, 140), M.SmoothPlastic)
	e:box('Tape', V(-0.3, 2.55, -1.52), V(0.3, 5.32, 1.52), C(214, 190, 140), M.SmoothPlastic)
	local box = crew.Boxes.BlockBox
	billboard(e, V(0, 8, 0), 7, 2, { { 'Title', string.upper(box.Name), C(255, 210, 63), FONT.loud, 0, 0.55 }, { 'Detail', box.CashCost .. ' CASH', P.white, FONT.title, 0.58, 0.4 } })
	local kinds = { 'BodegaCat', 'StoopPigeon', 'DeliveryPup', 'CourtCaptain' }
	for k = 1, 4 do
		local a = math.rad(-135 + (k - 1) * 90)
		local pos = V(math.cos(a) * 4.6, 0, math.sin(a) * 4.6)
		e:post('PetStand', 1.1, 0.6, pos, C(206, 44, 52), M.SmoothPlastic)
		pet(e, kinds[k], CFrame.lookAt(pos + V(0, 0.6, 0), pos * 2 + V(0, 0.6, 0)))
	end
	return e
end

-- World 2 arch (reference: a studded arch with a glowing portal); ours points at the Suburbs: green, a
-- white picket fence and hedges.
local function worldPortal(ctx)
	local w = ctx:group('World2Portal')
	local green = C(96, 168, 70)
	for _, x in { -5, 5 } do studs(w:box('Pier', V(x - 1.6, 0, -1.6), V(x + 1.6, 12, 1.6), green, M.Plastic), true) end
	studs(w:box('Lintel', V(-6.6, 12, -1.6), V(6.6, 15.2, 1.6), green, M.Plastic), true)
	local portal = decor(w:box('Portal', V(-3.4, 0, -0.3), V(3.4, 12, 0.3), C(150, 240, 160), M.Neon))
	portal.Transparency = 0.35
	local g = surface(portal, Enum.NormalId.Front, 30)
	line(g, 'Title', 'World 2', P.white, FONT.loud, 0.3, 0.16, C(30, 80, 30), 3)
	line(g, 'Detail', 'CLEAR STAGE 10', P.white, FONT.title, 0.48, 0.08, C(30, 80, 30), 2)
	for k = 0, 5 do
		local x = -7 + k * 2.8
		w:box('Picket', V(x - 0.3, 0, -3.2), V(x + 0.3, 2.6, -3), P.white, M.SmoothPlastic)
	end
	w:box('FenceRail', V(-7.4, 1.6, -3.25), V(7.4, 1.9, -2.95), P.white, M.SmoothPlastic)
	for _, x in { -8.6, 8.6 } do w:part('Hedge', V(2.6, 2.4, 2.6), CFrame.new(x, 1.2, 0), C(70, 150, 60), M.Plastic, Enum.PartType.Ball) end
	return w
end

-- Free stash chest on a gold pad with sparkles (reference: "FREE 15K POWER" chest).
local function stashChest(ctx)
	local c = ctx:group('FreeStash')
	studs(c:box('Pad', V(-3.4, 0, -3.4), V(3.4, 0.4, 3.4), C(240, 200, 50), M.Plastic))
	c:box('Chest', V(-2, 0.4, -1.4), V(2, 2.6, 1.4), C(196, 48, 52), M.WoodPlanks)
	c:box('Lid', V(-2.1, 2.6, -1.5), V(2.1, 3.3, 1.5), C(176, 40, 46), M.WoodPlanks)
	for _, x in { -1.7, 1.7 } do c:box('Band', V(x - 0.2, 0.4, -1.45), V(x + 0.2, 2.65, 1.45), C(255, 210, 63), M.SmoothPlastic) end
	c:box('Lock', V(-0.4, 1.6, -1.55), V(0.4, 2.4, -1.4), C(255, 210, 63), M.SmoothPlastic)
	emit(ghost(c:box('FX', V(-2.6, 0.5, -2.2), V(2.6, 3.6, 2.2), P.white)), { Texture = 'rbxasset://textures/particles/sparkles_main.dds', Preview = 'sparkle', Rate = 6,
		Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(0.5, 1.5), Size = NumberSequence.new(0.6, 0), Color = ColorSequence.new(C(255, 250, 200), C(255, 210, 63)), LightEmission = 1, LightInfluence = 0 })
	billboard(c, V(0, 6.4, 0), 7, 2, { { 'Title', 'FREE STASH', C(255, 210, 63), FONT.loud, 0, 0.55 }, { 'Detail', 'CLAIM EVERY 15 MIN', P.white, FONT.title, 0.58, 0.4 } })
	return c
end

-- A big sign on a post (reference: the grey studded HERO sign).
local function bigSign(ctx, text)
	local s = ctx:group('BlockSign')
	for _, x in { -6, 6 } do studs(s:box('Post', V(x - 1, 0, -1), V(x + 1, 6, 1), P.boardFrame, M.Plastic), true) end
	studs(s:box('Panel', V(-11, 5, -1.2), V(11, 15, 1.2), P.boardFrame, M.Plastic), true)
	local plate = s:box('Plate', V(-10, 6, -1.3), V(10, 14, -1.2), C(70, 74, 88), M.SmoothPlastic)
	line(surface(plate, Enum.NormalId.Front, 25), 'Title', text, P.white, FONT.loud, 0.1, 0.8, C(30, 30, 40), 3)
	return s
end

-- Featured look (reference: a big morph on a glowing pedestal beside the path, "SUPER OP" over its head).
local function featured(ctx, skin, art, tagline, tagColor)
	local f = ctx:group('Featured_' .. skin.Id)
	studs(f:box('PedestalBase', V(-3.2, 0, -3.2), V(3.2, 1.2, 3.2), C(40, 60, 120), M.Plastic), true)
	decor(f:box('PedestalGlow', V(-2.6, 1.2, -2.6), V(2.6, 1.32, 2.6), P.cyan, M.Neon))
	art.mannequin(f.parent, f:world(CFrame.new(0, 1.32, 0)), skin, 2)
	billboard(f, V(0, 15, 0), 9, 3.4, {
		{ 'Tagline', tagline, tagColor, FONT.loud, 0, 0.34 },
		{ 'Title', skin.Name, C(255, 70, 70), FONT.loud, 0.34, 0.36 },
		{ 'Detail', '+' .. skin.Gain .. '/sec • ' .. compact(skin.Required), P.white, FONT.title, 0.72, 0.28 },
	}).WorldLabel.MaxDistance = 90
	return f
end
---------------------------------------------------------------------------------------------- the lobby
local function buildLobby(ctx, cliffs, skins, crew, art)
	local lobby = ctx:group('Lobby')
	-- Spawn on its plaza, facing the stations and the street beyond.
	local spawn = Instance.new('SpawnLocation')
	spawn.Name = 'Spawn'
	spawn.Anchored = true
	spawn.Enabled = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = V(6, 0.2, 6)
	spawn.CFrame = V2.Origin * CFrame.new(SPAWN + V(0, 0.3, 0))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = lobby.parent
	-- White tutorial chevrons from the spawn to the free Tire Bag (reference: arrows along the walk).
	local arrows = lobby:group('TutorialArrows')
	local first = STATIONS[1]
	local route = { SPAWN + V(0, 0, -4), V(0, 0, first.z + 2), V(first.x + 6, 0, first.z + 2) }
	local carry = 0
	for k = 1, #route - 1 do
		local a, b = route[k], route[k + 1]
		local len = (b - a).Magnitude
		local t = carry
		while t <= len do
			local p = a:Lerp(b, t / len)
			local arrow = arrows:at(CFrame.lookAt(p, p + (b - a)))
			for _, side in { -1, 1 } do
				local tip, tail = V(0, 0.16, -0.7), V(side * 1.1, 0.16, 0.5)
				local c = decor(arrow:part('Chevron', V(0.55, 0.14, (tail - tip).Magnitude + 0.5), CFrame.lookAt((tip + tail) / 2, tail), P.white, M.SmoothPlastic))
				c.CastShadow = false
			end
			t += 3.2
		end
		carry = t - len
	end
	-- Bag stations either side of the walk, fronts turned to it.
	for i, pos in STATIONS do
		local c = V(pos.x, 0, pos.z)
		buildStation(lobby:at(CFrame.lookAt(c, c + V(pos.x < 0 and 1 or -1, 0, 0))), skins.Stations[i], i)
	end
	-- The morph stand on its platform to the east, the top look on a pedestal by the spawn.
	buildMorphStand(lobby:at(CFrame.lookAt(V(46, 0, 90), V(45, 0, 90))), skins, art)
	featured(lobby:at(CFrame.lookAt(V(30, 0, 108), V(20, 0, 96))), skins.ById.Kingpin, art, 'SUPER OP', C(70, 170, 255))
	featured(lobby:at(CFrame.lookAt(V(30, 0, 84), V(20, 0, 96))), skins.ById.TheDon, art, 'BEST DEAL', C(255, 210, 60))
	-- Leaderboards to the west, the Bodega Box by the spawn, the World 2 arch and the free stash.
	for k, d in { { 'TOP 50 POWER', C(255, 196, 40), 'ServerLeaderboard' }, { 'TOP 50 WINS', C(110, 230, 80), 'WinsLeaderboard' }, { 'TOP 50 REBIRTHS', C(255, 70, 70), 'RebirthLeaderboard' } } do
		local z = 76 + (k - 1) * 14
		leaderboard(lobby:at(CFrame.lookAt(V(-64, 0, z), V(-63, 0, z))), d[1], d[2], d[3])
	end
	bodegaBox(lobby:at(CFrame.new(-20, 0, 84)), crew)
	worldPortal(lobby:at(CFrame.lookAt(V(-56, 0, 50), V(-55, 0, 50))))
	stashChest(lobby:at(CFrame.lookAt(V(54, 0, 50), V(53, 0, 50))))
	-- Grass tufts and rubble on the lawn.
	local r = Random.new(7)
	local n, tries = 0, 0
	while n < 40 and tries < 400 do
		tries += 1
		local x, z = r:NextInteger(-70, 70), r:NextInteger(2, 118)
		local i, j = cellOf(x, z)
		local clear = true
		for di = -1, 1 do for dj = -1, 1 do if PLAN[i + di] and PLAN[i + di][j + dj] ~= 'lawn' then clear = false end end end
		if clear and not ((x + 20) ^ 2 + (z - 84) ^ 2 < 64 or (x - 30) ^ 2 + (z - 108) ^ 2 < 40 or (x - 30) ^ 2 + (z - 84) ^ 2 < 40) then
			n += 1
			tuft(lobby, V(x, 0, z), n)
		end
	end
	for k, p in { V(-66, 0, 8), V(64, 0, 24), V(-30, 0, 116), V(30, 0, 6) } do rubble(lobby, p, k) end
	-- Trees on the cliff tops: every other column two or three out, skipping the street's canyon.
	local trees = lobby:group('Trees')
	local seed = 0
	for bi = 1, BX do
		for bj = 1, BZ do
			local d = cliffs.dist[bi][bj]
			local x0, z0 = blockRect(bi, bj)
			if d and d >= 1 and d <= 4 and z0 >= -8 and hash(bi * 3, bj * 5) % (d == 1 and 4 or 3) == 0 then
				seed += 1
				tree(trees, V(x0 + 4, cliffTop(cliffs, x0 + 4, z0 + 4), z0 + 4), seed * 13, 0.8 + (seed % 3) * 0.12)
			end
		end
	end
	-- The game's name over the way into the street, on the cliffs.
	bigSign(lobby:at(CFrame.lookAt(V(40, cliffTop(cliffs, 40, -4) or 16, -4), V(20, 0, 60))), 'THE BLOCK')
	return lobby
end
---------------------------------------------------------------------------------------------- the hood: palette
-- research_notes/.../hood_games_maps.md, section 8: twelve colours with fixed jobs. About 60% greys, 30%
-- three bricks and iron, 10% accents (deli green, signal red, warm light), one accent per facade. The
-- stage walls are the only saturated thing in view.
local H = {
	asphalt = C(66, 68, 72), lineYellow = C(204, 170, 72), offWhite = C(229, 228, 223), concrete = C(163, 162, 165),
	darkConcrete = C(99, 95, 98), red = C(148, 70, 54), brown = C(105, 64, 40), buff = C(194, 160, 112), ink = C(38, 40, 46),
	green = C(40, 127, 71), signal = C(170, 44, 38), warm = C(240, 196, 96), navy = C(34, 56, 104),
	litGlass = C(176, 146, 92), transom = C(132, 112, 76), -- warm light seen in daylight: muted, not yellow
}
local DEPTH = 36 -- buildings run back from the building line to the cliffs
local function floorY(f) return SW + 12 + (f - 2) * 10 end -- bottom of floor f (f >= 2)
local function roofY(floors) return SW + 12 + (floors - 1) * 10 end

---------------------------------------------------------------------------------------------- facade kit
-- Building frame: origin at the front-left corner on the ground, +X along the sidewalk, +Z out of the
-- facade to the street, so one builder serves both sides. Facade clutter has no collisions.
local function plank(c, name, a, b, width, thick, color, material)
	return c:part(name, V(width, thick, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, material or M.SmoothPlastic)
end
-- Text on the street face of a part (+Z in a building frame is the part's Back face).
local function streetText(part, text, color, font, y, h)
	return line(surface(part, Enum.NormalId.Back, 20), 'Text', text, color, font or FONT.title, y or 0.12, h or 0.76)
end

-- Upper window: ink glass a little proud of the brick, a sill and a lintel in the trim colour; now and
-- then a half-drawn shade, a warm-lit pane, or bars (ground floor).
local function window(c, x, y, o)
	local w, h = o.w or 3, o.h or 5
	decor(c:box('Glass', V(x - w / 2, y, 0), V(x + w / 2, y + h, 0.12), o.lit and H.litGlass or H.ink, M.SmoothPlastic))
	decor(c:box('Sill', V(x - w / 2 - 0.3, y - 0.4, 0), V(x + w / 2 + 0.3, y, 0.6), o.trim, M.SmoothPlastic))
	decor(c:box('Lintel', V(x - w / 2 - 0.3, y + h, 0), V(x + w / 2 + 0.3, y + h + 0.6, o.hood and 0.6 or 0.3), o.hood or o.trim, M.SmoothPlastic))
	if o.shade then decor(c:box('Shade', V(x - w / 2, y + h - o.shade, 0.12), V(x + w / 2, y + h, 0.16), H.offWhite, M.SmoothPlastic)) end
	if o.bars then
		for k = -1, 1 do decor(c:box('Bars', V(x + k * w / 4 - 0.08, y, 0.14), V(x + k * w / 4 + 0.08, y + h, 0.3), H.ink, M.Metal)) end
		decor(c:box('Bars', V(x - w / 2, y + h / 2 - 0.08, 0.14), V(x + w / 2, y + h / 2 + 0.08, 0.3), H.ink, M.Metal))
	end
end
local function acUnit(c, x, y)
	decor(c:box('AC', V(x - 1.2, y, 0), V(x + 1.2, y + 1.6, 1.8), H.offWhite, M.SmoothPlastic))
	decor(c:box('ACGrille', V(x - 0.9, y + 0.3, 1.8), V(x + 0.9, y + 1.3, 1.86), H.darkConcrete, M.SmoothPlastic))
	for _, dx in { -0.9, 0.9 } do decor(c:bar('ACBracket', V(x + dx, y, 1.6), V(x + dx, y - 1.2, 0.05), 0.15, H.ink)) end
end

-- Street door: frame, door, warm transom, one step.
local function streetDoor(c, x, color, frame)
	local y = SW + 0.4
	c:box('Step', V(x - 2, SW, 0), V(x + 2, y, 1), H.concrete, M.Concrete)
	decor(c:box('DoorFrame', V(x - 2, y, 0), V(x + 2, y + 8.6, 0.3), frame or H.offWhite, M.SmoothPlastic))
	c:box('Door', V(x - 1.6, y, 0), V(x + 1.6, y + 7.2, 0.4), color or H.brown, M.SmoothPlastic)
	decor(c:box('Transom', V(x - 1.6, y + 7.4, 0), V(x + 1.6, y + 8.3, 0.36), H.transom, M.SmoothPlastic))
end

-- Shopfront between x0 and x1: kneewall, glass with mullions and a door (or the roll-down gate shut),
-- the gate box, a sign band, and an optional awning with its valance.
local SHOP_TOP = SW + 8.2
local function shopfront(c, x0, x1, o)
	local y0, top = SW, SHOP_TOP
	if o.gate == 'down' then
		c:box('ShopGate', V(x0, y0, 0), V(x1, top, 0.3), H.concrete, M.Metal)
		for y = y0 + 1, top - 0.6, 1 do decor(c:box('GateSlat', V(x0, y, 0.3), V(x1, y + 0.12, 0.4), H.darkConcrete, M.Metal)) end
	else
		c:box('Kneewall', V(x0, y0, 0), V(x1, y0 + 1.2, 0.3), o.kick or H.brown, M.SmoothPlastic)
		c:box('ShopGlass', V(x0, y0 + 1.2, 0), V(x1, top, 0.12), H.ink, M.SmoothPlastic)
		for x = x0 + 4, x1 - 1, 4 do decor(c:box('Mullion', V(x - 0.15, y0 + 1.2, 0), V(x + 0.15, top, 0.22), H.offWhite, M.SmoothPlastic)) end
		local dx = o.door == 'left' and x0 + 2 or x1 - 2
		decor(c:box('ShopDoorFrame', V(dx - 1.75, y0, 0), V(dx + 1.75, top, 0.26), H.offWhite, M.SmoothPlastic))
		c:box('ShopDoor', V(dx - 1.45, y0, 0), V(dx + 1.45, y0 + 7.2, 0.32), H.ink, M.SmoothPlastic)
	end
	decor(c:box('GateBox', V(x0, top, 0), V(x1, top + 0.9, 0.9), H.darkConcrete, M.Metal))
	local sign = c:box('SignBand', V(x0, top + 0.9, 0), V(x1, top + 2.9, 0.4), o.band or H.ink, M.SmoothPlastic)
	if o.sign then streetText(sign, o.sign, o.text or H.offWhite, o.font) end
	if o.awning then
		decor(c:wedge('Awning', V(x1 - x0, 1.6, 3.5), CFrame.new((x0 + x1) / 2, top + 0.2, 1.75) * CFrame.Angles(0, math.pi, 0), o.awning, M.Fabric))
		decor(c:box('Valance', V(x0, top - 1.4, 3.3), V(x1, top - 0.6, 3.5), o.awning, M.Fabric))
		decor(c:box('ValanceStripe', V(x0, top - 1.4, 3.5), V(x1, top - 1.2, 3.55), H.offWhite, M.Fabric))
	end
	return sign
end

-- Fire escape over the bays between x0 and x1: a deck per floor, rails and posts, zig-zag stairs and a
-- drop ladder that stops well above the sidewalk.
local function fireEscape(c, x0, x1, floors)
	for f = 2, floors do
		local d = floorY(f) + 2.4
		decor(c:box('EscapeDeck', V(x0, d, 0), V(x1, d + 0.3, 3.6), H.ink, M.DiamondPlate))
		decor(c:box('EscapeRail', V(x0, d + 3, 3.35), V(x1, d + 3.25, 3.6), H.ink, M.Metal))
		for _, x in { x0, x1 - 0.25 } do decor(c:box('EscapeRail', V(x, d + 3, 0), V(x + 0.25, d + 3.25, 3.6), H.ink, M.Metal)) end
		for k = 0, 3 do
			local x = x0 + (x1 - x0 - 0.25) * k / 3
			decor(c:box('EscapePost', V(x, d + 0.3, 3.35), V(x + 0.25, d + 3, 3.6), H.ink, M.Metal))
		end
		if f < floors then
			-- Stairs up to the next deck, alternating ends.
			local up = floorY(f + 1) + 2.4
			local left = f % 2 == 0
			local a = V(left and x0 + 1 or x1 - 1, d + 0.3, 1.6)
			local b = V(left and x0 + 7 or x1 - 7, up, 1.6)
			for _, z in { 0.9, 2.3 } do decor(plank(c, 'EscapeStringer', V(a.X, a.Y, z), V(b.X, b.Y, z), 0.25, 0.4, H.ink, M.Metal)) end
			for k = 1, 5 do
				local p = a:Lerp(b, k / 6)
				decor(c:box('EscapeTread', V(p.X - 0.25, p.Y - 0.08, 0.9), V(p.X + 0.25, p.Y + 0.08, 2.3), H.ink, M.Metal))
			end
		end
	end
	-- Drop ladder from the first deck, ending about 7 above the sidewalk.
	local d = floorY(2) + 2.4
	local lx = x1 - 2.2
	for _, x in { lx - 0.7, lx + 0.7 } do decor(c:box('DropLadder', V(x - 0.1, SW + 7.4, 3.3), V(x + 0.1, d, 3.5), H.ink, M.Metal)) end
	for y = SW + 8, d - 0.5, 1.2 do decor(c:box('DropRung', V(lx - 0.7, y, 3.3), V(lx + 0.7, y + 0.12, 3.5), H.ink, M.Metal)) end
end

-- Cedar water tank on a steel stand (about 1 per side per block). pos is on the roof.
local function waterTank(c, pos)
	local t = c:group('WaterTank')
	for _, dx in { -3, 3 } do
		for _, dz in { -3, 3 } do t:box('TankLeg', pos + V(dx - 0.3, 0, dz - 0.3), pos + V(dx + 0.3, 4, dz + 0.3), H.ink, M.Metal) end
	end
	t:bar('TankBrace', pos + V(-3, 0.3, -3), pos + V(3, 3.7, -3), 0.25, H.ink)
	t:bar('TankBrace', pos + V(-3, 0.3, 3), pos + V(3, 3.7, 3), 0.25, H.ink)
	studs(t:box('TankDeck', pos + V(-4, 4, -4), pos + V(4, 4.4, 4), H.brown, M.Plastic))
	t:post('Tank', 4, 8, pos + V(0, 4.4, 0), H.brown, M.WoodPlanks)
	for _, y in { 5.6, 8.4, 11.2 } do t:post('TankHoop', 4.06, 0.3, pos + V(0, y, 0), H.ink, M.Metal) end
	for k, r in { 4.2, 2.8, 1.4 } do t:post('TankRoof', r, 0.8, pos + V(0, 12.4 + (k - 1) * 0.8, 0), H.darkConcrete, M.SmoothPlastic) end
	t:blob('TankFinial', V(0.8, 0.8, 0.8), pos + V(0, 15.2, 0), H.ink, M.Metal)
	return t
end

-- Pigeons resting on a ledge.
local function pigeons(c, x0, x1, y, z, n)
	for k = 1, n do
		local x = x0 + (x1 - x0) * (k - 0.5) / n + (k % 2 == 0 and 0.4 or -0.3)
		decor(c:blob('Pigeon', V(0.7, 0.6, 0.9), V(x, y + 0.3, z), H.concrete, M.SmoothPlastic))
		decor(c:blob('PigeonHead', V(0.4, 0.4, 0.4), V(x, y + 0.75, z + 0.35), H.darkConcrete, M.SmoothPlastic))
	end
end

-- The walk-up: one brick box from the building line back to the cliffs, a parapet with a cap, a projecting
-- cornice on brackets, a string course over the shop floor, and window bays on every upper floor.
-- o: w, floors, wall, trim, cornice, bays = { x... }, seed, ground(c, o), escape = { x0, x1 }, tank, sideAt (0 or w)
local function walkup(ctx, name, o)
	local c, model = ctx:group(name)
	local roof = roofY(o.floors)
	c:box('Wall', V(0, -1, -DEPTH), V(o.w, roof, 0), o.wall, M.Brick)
	studs(c:box('Roof', V(0, roof, -DEPTH), V(o.w, roof + 0.2, -1), H.darkConcrete, M.Plastic))
	c:box('Parapet', V(0, roof, -1), V(o.w, roof + 2, 0), o.wall, M.Brick)
	decor(c:box('ParapetCap', V(0, roof + 2, -1.3), V(o.w, roof + 2.4, 0.3), o.trim, M.SmoothPlastic))
	decor(c:box('Cornice', V(0, roof - 1.2, 0), V(o.w, roof + 0.6, 1.3), o.cornice or o.trim, M.SmoothPlastic))
	local n = math.max(2, math.floor(o.w / 4.5))
	for k = 0, n do
		local x = 0.6 + (o.w - 1.2) * k / n
		decor(c:box('CorniceBracket', V(x - 0.4, roof - 2.4, 0), V(x + 0.4, roof - 1.2, 1.0), o.cornice or o.trim, M.SmoothPlastic))
	end
	decor(c:box('StringCourse', V(0, floorY(2) - 0.6, 0), V(o.w, floorY(2), 0.4), o.trim, M.SmoothPlastic))
	local seed = o.seed or 1
	for f = 2, o.floors do
		for k, x in o.bays do
			local h = hash(seed + f * 13, k * 7 + seed)
			local y = floorY(f) + 3
			local lit = (o.lit and o.lit[f .. ':' .. k]) or (not o.lit and h % 9 == 0)
			window(c, x, y, { trim = o.trim, lit = lit, shade = not lit and h % 4 == 1 and (1.2 + (h % 3) * 0.5) or nil })
			if not lit and h % 5 == 2 then acUnit(c, x, y) end
		end
	end
	-- A side wall that faces open ground (the canyon, a lot) gets two window bays per floor.
	if o.sideAt then
		local s = c:at(CFrame.new(o.sideAt, 0, 0) * CFrame.Angles(0, o.sideAt == 0 and -math.pi / 2 or math.pi / 2, 0))
		local sign = o.sideAt == 0 and -1 or 1
		for f = 3, o.floors do -- floor 2 can be behind the canyon's cliffs
			for k, d in { 7, 14 } do
				local h = hash(seed + f * 5, k + 40)
				window(s, sign * d, floorY(f) + 3, { trim = o.trim, shade = h % 4 == 1 and 1.5 or nil })
			end
		end
	end
	if o.ground then o.ground(c, o) end
	if o.escape then fireEscape(c, o.escape[1], o.escape[2], o.floors) end
	if o.tank then waterTank(c, V(o.w / 2, roof + 0.2, -DEPTH / 2)) end
	model:SetAttribute('Floors', o.floors)
	return c, model
end

-- Five bays at the standard 5-stud pitch, centred in width w.
local function bays(w, n, pitch)
	pitch = pitch or 5
	local t = {}
	for k = 1, n do table.insert(t, w / 2 + (k - (n + 1) / 2) * pitch) end
	return t
end

-- Brownstone: facade set back 3 behind an iron-fenced areaway, a stoop up to a parlour floor 6 above
-- the sidewalk, tall parlour windows, window hoods and a dark bracketed cornice.
local function brownstone(ctx, name, w, o)
	o = o or {}
	local c, model = ctx:group(name)
	local back = 3
	local parlour = SW + 6
	local roof = parlour + 33
	local f = c:at(CFrame.new(0, 0, -back))
	f:box('Wall', V(0, -1, -DEPTH + back), V(w, roof, 0), H.brown, M.Brick)
	studs(f:box('Roof', V(0, roof, -DEPTH + back), V(w, roof + 0.2, -1), H.darkConcrete, M.Plastic))
	decor(f:box('Cornice', V(0, roof - 2, 0), V(w, roof, 1.4), H.ink, M.SmoothPlastic))
	for k = 0, 3 do
		local x = 0.8 + (w - 1.6) * k / 3
		decor(f:box('CorniceBracket', V(x - 0.4, roof - 3.6, 0), V(x + 0.4, roof - 2, 1.2), H.ink, M.SmoothPlastic))
	end
	-- Areaway floor and fence.
	studs(c:box('Areaway', V(0, -1, -back), V(w, SW, 0), H.concrete, M.Plastic))
	local stoopX = o.stoopX or w - 3.5
	for x = 0.5, w - 0.4, 1 do
		if math.abs(x - stoopX) > 2.6 then decor(c:box('FencePicket', V(x - 0.1, SW, -0.2), V(x + 0.1, SW + 3, 0), H.ink, M.Metal)) end
	end
	c:box('FenceRail', V(0, SW + 3, -0.25), V(stoopX - 2.6, SW + 3.25, 0), H.ink, M.Metal)
	c:box('FenceRail', V(stoopX + 2.6, SW + 3, -0.25), V(w, SW + 3.25, 0), H.ink, M.Metal)
	-- Basement windows behind bars, tall parlour windows, then two upper floors with hoods.
	local others = {}
	for _, x in bays(w, 3, 5) do if math.abs(x - stoopX) > 2.6 then table.insert(others, x) end end
	for _, x in others do
		window(f, x, SW + 0.8, { w = 3, h = 2.4, trim = H.brown, bars = true })
		window(f, x, parlour + 1.8, { w = 3, h = 7, trim = H.brown, hood = H.brown, lit = o.litParlour })
	end
	for fl = 0, 1 do
		for k, x in bays(w, 3, 5) do
			local h = hash(fl * 7 + (o.seed or 3), k)
			window(f, x, parlour + 11 + fl * 10 + 3, { w = 3, h = 5.5, trim = H.brown, hood = H.brown, shade = h % 4 == 1 and 1.7 or nil })
			if h % 5 == 2 then acUnit(f, x, parlour + 11 + fl * 10 + 3) end
		end
	end
	-- The stoop: landing at the parlour door, four treads stepping out across the building line.
	local door = o.door or H.signal
	f:box('StoopLanding', V(stoopX - 2.2, SW, 0), V(stoopX + 2.2, parlour, 1.5), H.brown, M.SmoothPlastic)
	for k = 1, 5 do
		local z0, top = 1.5 + (k - 1) * 1.0, parlour - k * 1.08
		f:box('StoopTread', V(stoopX - 2.2, SW, z0), V(stoopX + 2.2, top, z0 + 1), H.brown, M.SmoothPlastic)
	end
	for _, dx in { -2.2, 2.2 } do
		decor(plank(f, 'StoopRail', V(stoopX + dx, parlour + 3, 1.2), V(stoopX + dx, SW + 3.2, 6.5), 0.25, 0.25, H.ink, M.Metal))
		decor(f:box('StoopPost', V(stoopX + dx - 0.15, SW, 6.3), V(stoopX + dx + 0.15, SW + 3.2, 6.6), H.ink, M.Metal))
		decor(f:blob('StoopNewel', V(0.7, 0.7, 0.7), V(stoopX + dx, SW + 3.5, 6.45), H.ink, M.Metal))
	end
	decor(f:box('DoorFrame', V(stoopX - 2, parlour, 0), V(stoopX + 2, parlour + 8.6, 0.3), H.brown, M.SmoothPlastic))
	f:box('Door', V(stoopX - 1.6, parlour, 0), V(stoopX + 1.6, parlour + 7, 0.4), door, M.SmoothPlastic)
	decor(f:box('Transom', V(stoopX - 1.6, parlour + 7.2, 0), V(stoopX + 1.6, parlour + 8.2, 0.36), H.transom, M.SmoothPlastic))
	decor(f:box('DoorHood', V(stoopX - 2.2, parlour + 8.6, 0), V(stoopX + 2.2, parlour + 9.4, 0.8), H.brown, M.SmoothPlastic))
	if o.pigeons then pigeons(f, 1, w - 1, roof, 0.9, 4) end
	model:SetAttribute('Floors', 4)
	return c, model, f, stoopX, parlour
end

-- Chain-link fence along a line (posts, top rail, see-through mesh), with optional gaps {a, b} in
-- distance along the line.
local function chainLink(c, a, b, h, gaps)
	local dir = b - a
	local len = dir.Magnitude
	local u = dir.Unit
	local n = math.max(1, math.ceil(len / 8))
	for k = 0, n do
		local t = len * k / n
		c:post('FencePost', 0.2, h, a + u * t, H.concrete, M.Metal)
	end
	local seg = len / n
	for k = 1, n do
		local t0, t1 = (k - 1) * seg, k * seg
		local pieces = { { t0, t1 } }
		for _, g in gaps or {} do
			local nextPieces = {}
			for _, p in pieces do
				if g[2] <= p[1] or g[1] >= p[2] then table.insert(nextPieces, p)
				else
					if g[1] > p[1] then table.insert(nextPieces, { p[1], g[1] }) end
					if g[2] < p[2] then table.insert(nextPieces, { g[2], p[2] }) end
				end
			end
			pieces = nextPieces
		end
		for _, p in pieces do
			if p[2] - p[1] > 0.3 then
				local p0, p1 = a + u * p[1], a + u * p[2]
				local mesh = c:part('ChainLink', V(0.1, h - 0.4, (p1 - p0).Magnitude), CFrame.lookAt((p0 + p1) / 2 + V(0, (h - 0.4) / 2 + 0.2, 0), p1 + V(0, (h - 0.4) / 2 + 0.2, 0)), H.concrete, M.DiamondPlate)
				mesh.Transparency = 0.55
				mesh.CastShadow = false
				decor(c:rod('FenceRail', 0.12, (p1 - p0).Magnitude, CFrame.lookAt((p0 + p1) / 2 + V(0, h, 0), p1 + V(0, h, 0)) * CFrame.Angles(0, math.pi / 2, 0), H.concrete))
			end
		end
	end
end
---------------------------------------------------------------------------------------------- street furniture
-- World frame helpers: these take positions in map coordinates. `toRoad` is +1 or -1 in x: which way the
-- road is from the prop.
local function cobraLamp(ctx, pos, toRoad)
	local m = ctx:at(CFrame.lookAt(pos, pos + V(toRoad, 0, 0))):group('StreetLamp')
	m:post('LampCollar', 0.5, 1.5, V(0, 0, 0), H.concrete, M.Metal)
	m:post('LampPole', 0.3, 17, V(0, 1.5, 0), H.concrete, M.Metal)
	m:bar('LampArm', V(0, 17.6, 0), V(0, 18.4, -2), 0.35, H.concrete)
	m:bar('LampArm', V(0, 18.4, -2), V(0, 18.4, -5.4), 0.35, H.concrete)
	m:box('LampHead', V(-0.5, 18, -7.4), V(0.5, 18.7, -5.2), H.darkConcrete, M.Metal)
	decor(m:box('LampLens', V(-0.35, 17.9, -7.2), V(0.35, 18, -5.6), H.warm, M.SmoothPlastic))
	return m
end
local function trafficSignal(ctx, pos, toRoad)
	local m = ctx:at(CFrame.lookAt(pos, pos + V(toRoad, 0, 0))):group('TrafficSignal')
	m:post('SignalPole', 0.35, 16, V(0, 0, 0), H.concrete, M.Metal)
	m:bar('SignalArm', V(0, 15.6, 0), V(0, 15.6, -9), 0.3, H.concrete)
	for _, d in { -4.5, -8.5 } do
		m:box('SignalHead', V(-0.6, 12, d - 0.6), V(0.6, 15.2, d + 0.6), H.ink, M.Metal)
		for k, col in { H.signal, H.warm, H.green } do
			decor(m:part('SignalLens', V(0.1, 0.8, 0.8), CFrame.new(0, 15.2 - k * 1.0, d + 0.62) * CFrame.Angles(0, math.pi / 2, 0), col, k == 3 and M.Neon or M.SmoothPlastic, Enum.PartType.Cylinder))
		end
	end
	return m
end
local function hydrantProp(ctx, pos)
	local h = ctx:group('FireHydrant')
	h:post('HydrantFoot', 0.8, 0.25, pos, H.signal, M.Metal)
	h:post('HydrantBarrel', 0.65, 2.4, pos + V(0, 0.25, 0), H.signal, M.Metal)
	h:blob('HydrantDome', V(1.3, 1, 1.3), pos + V(0, 2.65, 0), H.signal, M.Metal)
	h:post('HydrantNut', 0.25, 0.4, pos + V(0, 3.0, 0), H.green, M.Metal)
	h:rod('HydrantCaps', 0.3, 2, CFrame.new(pos + V(0, 1.8, 0)), H.green, M.Metal)
	return h
end
local function litterBasket(ctx, pos)
	local b = ctx:group('LitterBasket')
	b:post('Basket', 1.0, 3.0, pos, H.green, M.Metal)
	b:post('BasketRim', 1.05, 0.25, pos + V(0, 3.0, 0), H.ink, M.Metal)
	return b
end
local function mailboxProp(ctx, pos, toRoad)
	local m = ctx:at(CFrame.lookAt(pos, pos + V(toRoad, 0, 0))):group('Mailbox')
	for _, x in { -0.8, 0.8 } do for _, z in { -0.8, 0.8 } do m:box('MailboxLeg', V(x - 0.15, 0, z - 0.15), V(x + 0.15, 0.6, z + 0.15), H.ink, M.Metal) end end
	m:box('MailboxBody', V(-1.1, 0.6, -1.1), V(1.1, 3.6, 1.1), H.navy, M.SmoothPlastic)
	m:part('MailboxTop', V(2.2, 2.2, 2.2), CFrame.new(0, 3.6, 0), H.navy, M.SmoothPlastic, Enum.PartType.Cylinder)
	decor(m:box('MailboxSlot', V(-0.6, 3.0, -1.15), V(0.6, 3.2, -1.1), H.ink, M.SmoothPlastic))
	return m
end
local function trashBags(ctx, pos)
	local t = ctx:group('TrashBags')
	t:blob('TrashBag', V(2.2, 1.9, 2.2), pos + V(0, 0.95, 0), H.ink, M.SmoothPlastic)
	t:blob('TrashBag', V(1.8, 1.6, 1.8), pos + V(0.4, 0.8, 1.9), H.ink, M.SmoothPlastic)
	t:blob('TrashBag', V(2.0, 1.7, 2.0), pos + V(-0.3, 2.3, 0.8), H.ink, M.SmoothPlastic)
	t:post('TrashCan', 0.9, 2.6, pos + V(0.2, 0, -1.9), H.concrete, M.Metal)
	t:post('TrashLid', 0.95, 0.2, pos + V(0.2, 2.6, -1.9), H.darkConcrete, M.Metal)
	return t
end
-- Boxy generic cars (no brands). Frame: front toward -Z. kind 'sedan' | 'suv' | 'truck'.
local function car(ctx, cf, color, kind)
	local c = ctx:at(cf):group(kind == 'truck' and 'BoxTruck' or 'ParkedCar')
	local suv, truck = kind == 'suv', kind == 'truck'
	local hw = suv and 2.3 or truck and 2.6 or 2.2
	local half = suv and 5.5 or truck and 8 or 5
	local wheel = suv and 1.0 or truck and 1.1 or 0.9
	for _, x in { -hw + 0.3, hw - 0.3 } do
		for _, z in { -half + 1.8, half - 1.8 } do
			c:part('Wheel', V(0.7, wheel * 2, wheel * 2), CFrame.new(x, wheel, z), H.ink, M.SmoothPlastic, Enum.PartType.Cylinder)
			decor(c:part('Hubcap', V(0.74, wheel, wheel), CFrame.new(x, wheel, z), H.concrete, M.Metal, Enum.PartType.Cylinder))
		end
	end
	local low = wheel
	if truck then
		c:box('TruckCab', V(-hw, low, -half), V(hw, low + 3.4, -half + 4), color, M.SmoothPlastic)
		decor(c:box('Windshield', V(-hw + 0.3, low + 1.8, -half - 0.05), V(hw - 0.3, low + 3.1, -half + 0.2), H.ink, M.SmoothPlastic))
		c:box('TruckBox', V(-hw - 0.1, low, -half + 4.2), V(hw + 0.1, low + 6.4, half), H.offWhite, M.SmoothPlastic)
		decor(c:box('TruckStripe', V(-hw - 0.15, low + 2, -half + 4.3), V(hw + 0.15, low + 2.6, half - 0.1), H.green, M.SmoothPlastic))
		c:box('Bumper', V(-hw - 0.1, low - 0.3, -half - 0.3), V(hw + 0.1, low + 0.3, -half + 0.1), H.concrete, M.Metal)
		return c
	end
	local body = suv and 2.6 or 1.8
	c:box('CarBody', V(-hw, low, -half), V(hw, low + body, half), color, M.SmoothPlastic)
	local cab0, cab1 = suv and -half + 2.4 or -2.0, suv and half - 0.6 or 3.2
	local cabH = suv and 1.8 or 1.5
	c:box('CarCabin', V(-hw + 0.2, low + body, cab0), V(hw - 0.2, low + body + cabH, cab1), color, M.SmoothPlastic)
	decor(c:box('CarGlass', V(-hw + 0.15, low + body + 0.2, cab0 - 0.05), V(hw - 0.15, low + body + cabH - 0.2, cab1 + 0.05), H.ink, M.SmoothPlastic))
	for _, z in { -half - 0.2, half - 0.2 } do c:box('Bumper', V(-hw - 0.1, low - 0.1, z), V(hw + 0.1, low + 0.5, z + 0.4), H.concrete, M.Metal) end
	for _, x in { -hw + 0.6, hw - 1.5 } do
		decor(c:box('Headlight', V(x, low + body - 0.8, -half - 0.05), V(x + 0.9, low + body - 0.4, -half), H.warm, M.SmoothPlastic))
		decor(c:box('TailLight', V(x, low + body - 0.8, half), V(x + 0.9, low + body - 0.4, half + 0.05), H.signal, M.SmoothPlastic))
	end
	return c
end
local function streetTree(ctx, pos)
	local t = ctx:group('StreetTree')
	studs(t:box('TreePit', pos + V(-2, -0.05, -2), pos + V(2, 0.05, 2), H.darkConcrete, M.Plastic))
	t:post('TreeTrunk', 0.4, 7, pos, H.brown, M.Wood)
	t:blob('TreeCanopy', V(5, 4.4, 5), pos + V(0, 9.2, 0), H.green, M.Grass)
	t:blob('TreeCanopy', V(4.5, 4, 4.5), pos + V(1.4, 10.6, 0.8), H.green, M.Grass)
	t:blob('TreeCanopy', V(4, 3.6, 4), pos + V(-1.2, 10.8, -0.9), H.green, M.Grass)
	return t
end
local function milkCrates(ctx, pos, cat)
	local m = ctx:group('MilkCrates')
	m:box('MilkCrate', pos + V(-0.8, 0, -0.8), pos + V(0.8, 1.6, 0.8), H.signal, M.SmoothPlastic)
	m:box('MilkCrate', pos + V(-0.8, 1.6, -0.8), pos + V(0.8, 3.2, 0.8), H.signal, M.SmoothPlastic)
	if cat then
		decor(m:blob('BodegaCat', V(1.0, 0.8, 1.3), pos + V(0, 3.6, 0), H.brown, M.SmoothPlastic))
		decor(m:blob('BodegaCatHead', V(0.7, 0.65, 0.65), pos + V(0, 4.2, -0.6), H.brown, M.SmoothPlastic))
		for _, x in { -0.2, 0.2 } do decor(m:box('BodegaCatEar', pos + V(x - 0.08, 4.45, -0.65), pos + V(x + 0.08, 4.75, -0.55), H.brown, M.SmoothPlastic)) end
	end
	return m
end
local function aFrame(ctx, pos, toRoad, text)
	local a = ctx:at(CFrame.lookAt(pos, pos + V(toRoad, 0, 0))):group('AFrameBoard')
	local board = a:part('Board', V(1.6, 2.6, 0.2), CFrame.new(0, 1.3, -0.4) * CFrame.Angles(math.rad(-12), 0, 0), H.ink, M.SmoothPlastic)
	a:part('BoardBack', V(1.6, 2.6, 0.2), CFrame.new(0, 1.3, 0.4) * CFrame.Angles(math.rad(12), 0, 0), H.ink, M.SmoothPlastic)
	line(surface(board, Enum.NormalId.Front, 30), 'Text', text, H.offWhite, FONT.tag, 0.1, 0.8)
	return a
end
local function dumpster(ctx, cf)
	local d = ctx:at(cf):group('Dumpster')
	d:box('DumpsterBody', V(-3, 0.5, -2), V(3, 4, 2), H.darkConcrete, M.Metal)
	d:box('DumpsterLid', V(-3.1, 4, -2.1), V(3.1, 4.3, 2.1), H.ink, M.Metal)
	for _, x in { -2.4, 2.4 } do for _, z in { -1.5, 1.5 } do d:part('Caster', V(0.3, 0.5, 0.5), CFrame.new(x, 0.25, z), H.ink, M.Metal, Enum.PartType.Cylinder) end end
	return d
end
-- Barber pole: off-white with red rings, turned slowly by HoodClient/WorldMotion.
local function barberPole(ctx, pos)
	local b, model = ctx:group('BarberPole')
	b:post('PoleBody', 0.4, 4, pos, H.offWhite, M.SmoothPlastic)
	for k = 0, 3 do
		b:part('PoleStripe', V(0.3, 0.85, 0.85), CFrame.new(pos + V(0, 0.6 + k * 0.95, 0)) * CFrame.Angles(0, 0, math.pi / 2) * CFrame.Angles(math.rad(20), 0, 0), H.signal, M.SmoothPlastic, Enum.PartType.Cylinder)
	end
	for _, y in { -0.1, 4.1 } do b:blob('PoleCap', V(0.9, 0.5, 0.9), pos + V(0, y, 0), H.concrete, M.Metal) end
	model:SetAttribute('Spin', 60)
	model:AddTag('HoodMotion')
	model.WorldPivot = b:world(CFrame.new(pos + V(0, 2, 0)))
	return b
end
local function bench(ctx, pos, facing)
	local b = ctx:at(CFrame.lookAt(pos, pos + facing)):group('Bench')
	for _, x in { -2.6, 2.6 } do
		b:box('BenchLeg', V(x - 0.2, 0, -0.8), V(x + 0.2, 1.5, 0.8), H.ink, M.Metal)
		b:box('BenchBackPost', V(x - 0.2, 1.5, 0.6), V(x + 0.2, 3.4, 0.8), H.ink, M.Metal)
	end
	for k = -1, 1 do b:box('BenchSlat', V(-3.2, 1.5, k * 0.52 - 0.22), V(3.2, 1.72, k * 0.52 + 0.22), H.brown, M.WoodPlanks) end
	for k = 0, 1 do b:box('BenchBackSlat', V(-3.2, 2.2 + k * 0.6, 0.8), V(3.2, 2.6 + k * 0.6, 1.0), H.brown, M.WoodPlanks) end
	return b
end
local function movingBoxes(ctx, pos, n)
	local m = ctx:group('MovingBoxes')
	local sizes = { 2.0, 1.6, 1.4, 1.8, 1.5 }
	local x = 0
	for k = 1, n do
		local s = sizes[(k - 1) % #sizes + 1]
		local stacked = k % 3 == 0
		local p = pos + V(stacked and x - 1.6 or x, stacked and 2 or 0, (k % 2) * 0.3)
		m:box('MovingBox', p + V(-s / 2, 0, -s / 2), p + V(s / 2, s, s / 2), H.buff, M.Cardboard)
		decor(m:box('BoxTape', p + V(-0.15, 0, -s / 2 - 0.02), p + V(0.15, s + 0.02, s / 2 + 0.02), H.brown, M.SmoothPlastic))
		if not stacked then x += s + 0.3 end
	end
	return m
end
---------------------------------------------------------------------------------------------- stage walls
-- The reference's stage wall: a see-through pink sheet across the whole street, "Stage N" and the power
-- it takes in a pixel font, and two flat pads in front of it (magenta: back to the lobby, yellow: your
-- furthest stage). HoodClient/Stages makes the sheet solid while you're short, turns it green when you
-- can pass and clears it once you have; StageService records the clear and pays the reward.
local WALL_PINK = C(255, 150, 205)
local WALL_TEXT, WALL_SUB, WALL_STROKE = C(236, 242, 255), C(150, 186, 255), C(30, 38, 92)
local function teleportPad(g, name, x, z, color, target, action, label)
	local pad = g:box(name, V(x - 4, 0, z - 2), V(x + 4, 0.35, z + 2), color, M.SmoothPlastic)
	decor(g:box(name .. 'Glow', V(x - 3.4, 0.35, z - 1.4), V(x + 3.4, 0.42, z + 1.4), color, M.Neon)).CastShadow = false
	local prompt = Instance.new('ProximityPrompt')
	prompt.Name = 'Teleport'
	prompt.ActionText = action
	prompt.ObjectText = label
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute('Target', target)
	prompt:AddTag('HoodTeleport')
	prompt.Parent = pad
	local tag = billboard(g, V(x, 3.2, z), 6, 1.4, { { 'Title', label, P.white, FONT.title, 0, 1 } })
	tag.WorldLabel.MaxDistance = 50
	return pad
end
local function buildGate(ctx, i, wall)
	local z = stageZ(i)
	local g, model = ctx:at(CFrame.new(0, 0, z)):group('StageGate' .. i)
	local barrier = g:box('Barrier', V(-FACADE, 0, -0.3), V(FACADE, 26, 0.3), WALL_PINK, M.SmoothPlastic)
	barrier.Transparency = 0.45
	barrier.CastShadow = false
	for _, face in { Enum.NormalId.Back, Enum.NormalId.Front } do
		local gui = surface(barrier, face, 16)
		pcall(function() gui.MaxDistance = 260 end)
		line(gui, 'Title', 'Stage ' .. i, WALL_TEXT, Enum.Font.Arcade, 0.1, 0.26, WALL_STROKE, 5)
		line(gui, 'Recommended', 'Required', WALL_SUB, Enum.Font.Arcade, 0.42, 0.13, WALL_STROKE, 3)
		line(gui, 'Power', 'Power: ' .. compact(wall.RequiredRep), WALL_SUB, Enum.Font.Arcade, 0.56, 0.13, WALL_STROKE, 3)
		line(gui, 'Status', 'NEED 💪 ' .. compact(wall.RequiredRep), P.white, FONT.loud, 0.76, 0.08, WALL_STROKE, 2)
	end
	-- Pads on the approach side.
	teleportPad(g, 'LobbyPad', -7, 9, P.magenta, 'Lobby', 'Teleport', 'LOBBY')
	teleportPad(g, 'FurthestPad', 7, 9, P.padYellow, 'Furthest', 'Teleport', 'FURTHEST STAGE')
	-- Confetti the client fires when you break through.
	local shell = ghost(g:box('PassShell', V(-15, 20, -1), V(15, 21, 1), P.white))
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
	fx.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, WALL_PINK), ColorSequenceKeypoint.new(0.5, P.padYellow), ColorSequenceKeypoint.new(1, P.white) })
	fx.EmissionDirection = Enum.NormalId.Bottom
	fx.LightInfluence = 1
	fx.Parent = shell
	model:SetAttribute('Stage', i)
	model:SetAttribute('WallId', wall.Id)
	model:SetAttribute('Required', wall.RequiredRep)
	model:SetAttribute('Reward', wall.CashReward)
	model:SetAttribute('LineZ', z)
	model:SetAttribute('PadZ', z + 9)
	model:SetAttribute('HalfWidth', FACADE)
	model:SetAttribute('Color', WALL_PINK)
	model:SetAttribute('Light', WALL_PINK)
	model:AddTag('HoodStageGate')
	return model
end
---------------------------------------------------------------------------------------------- lots and set pieces
-- Frame for one lot on side s (-1 left, +1 right) whose gate-end edge is at za: +X along the sidewalk,
-- +Z toward the street. On the left x runs down the street from za; on the right it runs back up to za.
local function lotFrame(ctx, s, za, w)
	if s < 0 then return ctx:at(CFrame.lookAt(V(-FACADE, 0, za), V(-FACADE - 1, 0, za))) end
	return ctx:at(CFrame.lookAt(V(FACADE, 0, za - w), V(FACADE + 1, 0, za - w)))
end
-- x measured from the gate end of a lot of width w on side s.
local function fromGate(x, w, s) return s < 0 and x or w - x end

local function lotGround(c, w, color)
	studs(c:box('LotGround', V(0, -1, -DEPTH), V(w, SW - 0.1, 0), color or H.darkConcrete, M.Plastic))
end

-- A painted sign on a lot's side wall (the neighbour's brick, exposed by the gap). wallX is 0 or w.
local function wallMural(c, w, wallX, title)
	local into = wallX == 0 and 1 or -1
	local panel = decor(c:box('Mural', V(wallX, 14, -17), V(wallX + into * 0.06, 24, -3), H.offWhite, M.SmoothPlastic))
	local face = into > 0 and Enum.NormalId.Right or Enum.NormalId.Left
	local g = surface(panel, face, 16)
	local sun = Instance.new('Frame')
	sun.Name = 'Sun'
	sun.BackgroundColor3 = H.signal
	sun.BorderSizePixel = 0
	sun.Position = UDim2.fromScale(0.62, 0.08)
	sun.Size = UDim2.fromScale(0.3, 0.5)
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = sun
	sun.Parent = g
	local band = Instance.new('Frame')
	band.Name = 'Band'
	band.BackgroundColor3 = H.green
	band.BorderSizePixel = 0
	band.Position = UDim2.fromScale(0, 0.62)
	band.Size = UDim2.fromScale(1, 0.16)
	band.Parent = g
	line(g, 'Title', title, H.ink, FONT.loud, 0.2, 0.36, H.offWhite, 4)
	return panel
end

-- Vacant lot turned community garden: chain-link with a gate, a NO DUMPING sign, raised beds, a dumpster.
local function gardenLot(c, w)
	lotGround(c, w)
	chainLink(c, V(0.2, SW - 0.1, 0.2), V(w - 0.2, SW - 0.1, 0.2), 9, { { w / 2 - 2, w / 2 + 2 } })
	local sign = decor(c:box('LotSign', V(1.4, 4.4, 0.3), V(4.6, 5.9, 0.4), H.offWhite, M.SmoothPlastic))
	streetText(sign, 'NO DUMPING', H.signal, FONT.body)
	for _, x in { w * 0.27, w * 0.73 } do
		c:box('RaisedBed', V(x - 1.2, SW - 0.1, -10), V(x + 1.2, SW + 0.9, -4), H.brown, M.WoodPlanks)
		for q = -1, 1 do c:blob('Plant', V(1.3, 1.2, 1.3), V(x, SW + 1.4, -7 + q * 1.8), H.green, M.Grass) end
	end
	dumpster(c, CFrame.new(w / 2, SW - 0.1, -18))
end

-- Basketball cage: grey court with one green key at each end, chalk-white lines, two hoops, 14-tall
-- chain-link all round with a gate, and a freestanding handball wall at the back.
local function hoop(c, x, z, toward)
	local m = c:at(CFrame.lookAt(V(x, 0, z), V(x + toward, 0, z))):group('Hoop')
	m:post('HoopPole', 0.3, 10, V(0, SW, 1.2), H.concrete, M.Metal)
	m:box('HoopArm', V(-0.2, SW + 9.4, -0.2), V(0.2, SW + 9.8, 1.2), H.concrete, M.Metal)
	m:box('Backboard', V(-2.2, SW + 8.4, -0.4), V(2.2, SW + 11, -0.2), H.offWhite, M.SmoothPlastic)
	decor(m:box('BoardSquare', V(-0.8, SW + 9, -0.45), V(0.8, SW + 10.1, -0.4), H.signal, M.SmoothPlastic))
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		decor(m:part('Rim', V(0.62, 0.1, 0.12), CFrame.new(math.cos(a) * 0.75, SW + 9, -1.2 + math.sin(a) * 0.75) * CFrame.Angles(0, -a + math.pi / 2, 0), H.signal, M.Metal))
		decor(m:bar('Net', V(math.cos(a) * 0.72, SW + 8.95, -1.2 + math.sin(a) * 0.72), V(math.cos(a) * 0.4, SW + 8, -1.2 + math.sin(a) * 0.4), 0.06, H.offWhite, M.Fabric))
	end
	return m
end
local function courtLot(c, w)
	lotGround(c, w, H.asphalt)
	local x0, x1, z0, z1 = 3, w - 3, -26, -4
	c:box('Court', V(x0, SW - 0.1, z0), V(x1, SW, z1), H.darkConcrete, M.SmoothPlastic)
	local zc = (z0 + z1) / 2
	local function stripe(a, b) decor(c:box('CourtLine', a, b + V(0, 0.02, 0), H.offWhite, M.SmoothPlastic)) end
	stripe(V(x0, SW, z1 - 0.3), V(x1, SW + 0.04, z1))
	stripe(V(x0, SW, z0), V(x1, SW + 0.04, z0 + 0.3))
	stripe(V(x0, SW, z0), V(x0 + 0.3, SW + 0.04, z1))
	stripe(V(x1 - 0.3, SW, z0), V(x1, SW + 0.04, z1))
	stripe(V(w / 2 - 0.15, SW, z0), V(w / 2 + 0.15, SW + 0.04, z1))
	for _, e in { { x0, 1 }, { x1, -1 } } do
		local kx = e[1] + e[2] * 6
		decor(c:box('Key', V(math.min(e[1], kx) + 0.3, SW, zc - 3), V(math.max(e[1], kx) - 0.3, SW + 0.02, zc + 3), H.green, M.SmoothPlastic))
		hoop(c, e[1] - e[2] * 1.4, zc, e[2])
	end
	chainLink(c, V(0.3, SW, 0.3), V(w - 0.3, SW, 0.3), 14, { { w / 2 - 2.5, w / 2 + 2.5 } })
	chainLink(c, V(0.3, SW, 0.3), V(0.3, SW, -30), 14)
	chainLink(c, V(w - 0.3, SW, 0.3), V(w - 0.3, SW, -30), 14)
	chainLink(c, V(0.3, SW, -30), V(w - 0.3, SW, -30), 14)
	c:box('HandballWall', V(w / 2 - 8, SW, -34), V(w / 2 + 8, SW + 16, -33), H.concrete, M.Concrete)
	decor(c:box('HandballLine', V(w / 2 - 8, SW + 3, -33), V(w / 2 + 8, SW + 3.3, -32.95), H.signal, M.SmoothPlastic))
	c:part('Basketball', V(1.2, 1.2, 1.2), CFrame.new(w / 2 + 5, SW + 0.6, zc + 4), H.signal:Lerp(C(230, 120, 40), 0.6), M.SmoothPlastic, Enum.PartType.Ball)
	bench(c, V(w / 2 - 8, SW, -1.6), V(0, 0, -1))
	bench(c, V(w / 2 + 8, SW, -1.6), V(0, 0, -1))
end

-- Gas station: concrete apron, a canopy on four columns over two pump islands, a small mart at the back
-- and a price sign by the sidewalk.
local function gasLot(c, w)
	lotGround(c, w, H.concrete)
	local cx = w / 2
	for _, x in { cx - 11, cx + 11 } do
		for _, z in { -6, -20 } do c:box('CanopyColumn', V(x - 0.6, SW, z - 0.6), V(x + 0.6, SW + 14, z + 0.6), H.offWhite, M.SmoothPlastic) end
	end
	studs(c:box('Canopy', V(cx - 14, SW + 14, -23), V(cx + 14, SW + 15.6, -3), H.offWhite, M.Plastic))
	local fascia = c:box('CanopyFascia', V(cx - 14.1, SW + 14.2, -3.1), V(cx + 14.1, SW + 15.4, -2.9), H.green, M.SmoothPlastic)
	streetText(fascia, 'GAS • AIR • MINI MART', H.offWhite, FONT.title)
	for _, x in { cx - 5, cx + 5 } do
		c:box('PumpIsland', V(x - 1.4, SW, -19), V(x + 1.4, SW + 0.5, -7), H.offWhite, M.Concrete)
		for _, z in { -10, -16 } do
			c:box('Pump', V(x - 0.7, SW + 0.5, z - 1.1), V(x + 0.7, SW + 5, z + 1.1), H.offWhite, M.SmoothPlastic)
			decor(c:box('PumpTop', V(x - 0.75, SW + 4.2, z - 1.15), V(x + 0.75, SW + 5.1, z + 1.15), H.green, M.SmoothPlastic))
			for _, sx in { -0.76, 0.76 } do decor(c:box('PumpScreen', V(x + sx - 0.03, SW + 2.6, z - 0.6), V(x + sx + 0.03, SW + 3.6, z + 0.6), H.ink, M.SmoothPlastic)) end
		end
	end
	-- The mart at the back, its front facing the street.
	local m = c:at(CFrame.new(cx - 11, 0, -26))
	m:box('MartWall', V(0, -1, -10), V(22, SW + 12, 0), H.offWhite, M.SmoothPlastic)
	studs(m:box('MartRoof', V(0, SW + 12, -10), V(22, SW + 12.4, 0), H.darkConcrete, M.Plastic))
	shopfront(m, 2, 20, { sign = 'MINI MART', band = H.green, kick = H.concrete, door = 'left' })
	-- Price sign.
	c:post('PriceSignPole', 0.3, 10, V(2.6, SW, -1.2), H.ink, M.Metal)
	local board = c:box('PriceSign', V(0.6, SW + 10, -1.5), V(4.6, SW + 15, -0.9), H.ink, M.SmoothPlastic)
	line(surface(board, Enum.NormalId.Back, 30), 'Text', 'GAS\n3.49', H.offWhite, FONT.title, 0.08, 0.84)
end

-- Projects tower: a plain brick slab set back on an asphalt plaza, a grid of identical windows, a concrete
-- base band and an entrance canopy; benches and a small playground out front.
local function projectsLot(c, w, floors, setback)
	lotGround(c, w, H.asphalt)
	local f = c:at(CFrame.new(0, 0, -setback))
	local top = SW + floors * 9
	f:box('Tower', V(2, -1, -26), V(w - 2, top, 0), H.red, M.Brick)
	studs(f:box('TowerRoof', V(2, top, -26), V(w - 2, top + 0.4, 0), H.darkConcrete, M.Plastic))
	f:box('TowerBase', V(2, SW, 0), V(w - 2, SW + 3, 0.4), H.concrete, M.Concrete)
	for fl = 1, floors - 1 do
		local y = SW + fl * 9 + 2.5
		for x = 6, w - 6, 6 do
			decor(f:box('Glass', V(x - 1.4, y, 0), V(x + 1.4, y + 4, 0.12), (hash(fl, x) % 11 == 0) and H.warm or H.ink, M.SmoothPlastic))
			decor(f:box('Sill', V(x - 1.6, y - 0.3, 0), V(x + 1.6, y, 0.4), H.concrete, M.SmoothPlastic))
		end
	end
	f:box('EntranceCanopy', V(w / 2 - 5, SW + 8, 0), V(w / 2 + 5, SW + 8.6, 5), H.concrete, M.Concrete)
	for _, x in { w / 2 - 4.6, w / 2 + 4.6 } do f:post('CanopyPost', 0.2, 7.4, V(x, SW + 0.6, 4.6), H.ink, M.Metal) end
	f:box('EntranceDoor', V(w / 2 - 2.5, SW, 0), V(w / 2 + 2.5, SW + 7.4, 0.55), H.ink, M.SmoothPlastic)
	-- Plaza: a path to the door, benches, a climbing frame and slide.
	studs(c:box('PlazaPath', V(w / 2 - 3, SW - 0.1, -setback), V(w / 2 + 3, SW, 0), H.concrete, M.Plastic))
	bench(c, V(w / 2 - 8, SW, -setback / 2), V(1, 0, 0))
	bench(c, V(w / 2 + 8, SW, -setback / 2), V(-1, 0, 0))
	local px = w * 0.2
	for _, dx in { -2, 2 } do for _, dz in { -2, 2 } do c:post('PlayFrame', 0.2, 5, V(px + dx, SW - 0.1, -setback / 2 + dz), H.signal, M.Metal) end end
	studs(c:box('PlayDeck', V(px - 2.2, SW + 4, -setback / 2 - 2.2), V(px + 2.2, SW + 4.4, -setback / 2 + 2.2), H.green, M.Plastic))
	c:wedge('Slide', V(1.6, 4.3, 6), CFrame.new(px, SW + 2.05, -setback / 2 + 5.2) * CFrame.Angles(0, math.pi, 0), H.warm, M.SmoothPlastic)
	chainLink(c, V(0.3, SW, 0.3), V(w / 2 - 3.5, SW, 0.3), 4)
	chainLink(c, V(w / 2 + 3.5, SW, 0.3), V(w - 0.3, SW, 0.3), 4)
end

-- Sidewalk shed (NYC scaffolding tunnel): green posts at the kerb, a deck 10 up with a plywood parapet
-- and a few wheatpaste posters. a and b are world points on the kerb line.
local function sidewalkShed(ctx, x0, x1, za, zb)
	local s = ctx:group('SidewalkShed')
	local kerbX = math.abs(x0) < math.abs(x1) and x0 or x1
	for z = za, zb, -8 do
		s:box('ShedPost', V(kerbX - 0.3, SW, z - 0.3), V(kerbX + 0.3, SW + 12.8, z + 0.3), H.green, M.SmoothPlastic)
	end
	studs(s:box('ShedDeck', V(math.min(x0, x1), SW + 12.8, zb), V(math.max(x0, x1), SW + 13.4, za), H.green, M.Plastic))
	s:box('ShedParapet', V(kerbX - 0.2, SW + 13.4, zb), V(kerbX + 0.2, SW + 16.4, za), H.green, M.WoodPlanks)
	local r = Random.new(41)
	for k = 1, 5 do
		local z = za - k * 8 -- on the sidewalk face of a post
		local poster = decor(s:part('Poster', V(0.06, 3, 2), CFrame.new(kerbX + (x0 < 0 and -0.33 or 0.33), SW + 4.5, z) * CFrame.Angles(math.rad(r:NextNumber(-4, 4)), 0, 0), H.offWhite, M.SmoothPlastic))
		line(surface(poster, x0 < 0 and Enum.NormalId.Left or Enum.NormalId.Right, 30), 'Text', ({ 'THE BLOCK', 'LIVE • SAT', 'NEW DROP', 'BOXING NIGHT', 'COME UP' })[k], H.ink, FONT.loud, 0.2, 0.6)
	end
	return s
end

-- Pipe scaffold up part of a facade (building frame): standards every 6, ledgers per floor, plank decks.
local function pipeScaffold(c, x0, x1, floors)
	local top = floorY(floors) + 4
	for x = x0, x1 + 0.01, 6 do
		for _, z in { 1, 4 } do decor(c:box('ScaffoldPipe', V(x - 0.15, SW, z - 0.15), V(x + 0.15, top, z + 0.15), H.concrete, M.Metal)) end
	end
	for f = 2, floors do
		local y = floorY(f)
		for _, z in { 1, 4 } do decor(c:box('ScaffoldLedger', V(x0, y + 3, z - 0.15), V(x1, y + 3.3, z + 0.15), H.concrete, M.Metal)) end
		decor(c:box('ScaffoldPlanks', V(x0, y, 0.8), V(x1, y + 0.3, 4.2), H.brown, M.WoodPlanks))
	end
end

-- Elevated train over the street: two-column bents on the kerb lines every 22, girders along both kerbs
-- and a track deck with two rails.
local function elevated(ctx, za, zb)
	local e = ctx:group('ElevatedTrain')
	for z = za - 4, zb + 4, -22 do
		for _, x in { -ROAD - 1.4, ROAD + 1.4 } do e:box('ElColumn', V(x - 0.6, 0, z - 0.6), V(x + 0.6, 24, z + 0.6), H.ink, M.Metal) end
		e:box('ElBent', V(-ROAD - 2, 24, z - 0.6), V(ROAD + 2, 25.6, z + 0.6), H.ink, M.Metal)
	end
	for _, x in { -ROAD - 1.4, ROAD + 1.4 } do e:box('ElGirder', V(x - 0.7, 24.6, zb), V(x + 0.7, 28, za), H.ink, M.Metal) end
	e:box('ElDeck', V(-ROAD + 1, 25.6, zb), V(ROAD - 1, 26.2, za), H.darkConcrete, M.Metal)
	for _, x in { -3, 3 } do e:box('ElRail', V(x - 0.2, 26.2, zb), V(x + 0.2, 26.6, za), H.concrete, M.Metal) end
	return e
end

-- Food cart with an umbrella.
local function foodCart(ctx, pos, toRoad, label)
	local f = ctx:at(CFrame.lookAt(pos, pos + V(toRoad, 0, 0))):group('FoodCart')
	f:box('CartBody', V(-2.2, 1.2, -1.2), V(2.2, 4, 1.2), H.offWhite, M.Metal)
	for _, x in { -1.6, 1.6 } do f:part('CartWheel', V(0.4, 1.4, 1.4), CFrame.new(x, 0.7, 1.25), H.ink, M.SmoothPlastic, Enum.PartType.Cylinder) end
	local sign = f:box('CartSign', V(-2.2, 2.2, -1.3), V(2.2, 3.6, -1.2), H.ink, M.SmoothPlastic)
	line(surface(sign, Enum.NormalId.Front, 30), 'Text', label, H.warm, FONT.title, 0.1, 0.8)
	f:post('UmbrellaPole', 0.1, 4.5, V(0, 4, 0), H.concrete, M.Metal)
	f:part('Umbrella', V(0.6, 6, 6), CFrame.new(0, 8.6, 0) * CFrame.Angles(0, 0, math.pi / 2), H.green, M.Fabric, Enum.PartType.Cylinder)
	return f
end

-- Blue-and-white police-style sawhorse, block party edition.
local function sawhorse(ctx, cf)
	local s = ctx:at(cf):group('Barricade')
	for _, x in { -2.6, 2.6 } do
		s:bar('BarricadeLeg', V(x, 0, -0.8), V(x, 3, 0), 0.25, H.offWhite)
		s:bar('BarricadeLeg', V(x, 0, 0.8), V(x, 3, 0), 0.25, H.offWhite)
	end
	s:box('BarricadeBoard', V(-3, 2.4, -0.15), V(3, 3.4, 0.15), H.navy, M.SmoothPlastic)
	for k = 0, 2 do decor(s:box('BarricadeStripe', V(-2.2 + k * 1.8, 2.45, -0.18), V(-1.6 + k * 1.8, 3.35, 0.18), H.offWhite, M.SmoothPlastic)) end
	return s
end
local function speakerStack(ctx, pos)
	local s = ctx:group('SpeakerStack')
	for k = 0, 1 do
		s:box('Speaker', pos + V(-1.3, k * 3, -1.2), pos + V(1.3, k * 3 + 3, 1.2), H.ink, M.SmoothPlastic)
		decor(s:part('SpeakerCone', V(0.1, 1.8, 1.8), CFrame.new(pos + V(0, k * 3 + 1.5, 1.22)) * CFrame.Angles(0, math.pi / 2, 0), H.darkConcrete, M.SmoothPlastic, Enum.PartType.Cylinder))
	end
	return s
end
local function warmLights(ctx, a, b, sag)
	local g = ctx:group('StringLights')
	local n = 16
	local function at(t) return a:Lerp(b, t) - V(0, sag * 4 * t * (1 - t), 0) end
	for k = 0, n - 1 do
		decor(g:bar('Wire', at(k / n), at((k + 1) / n), 0.06, H.ink)).CastShadow = false
		if k > 0 then decor(g:blob('Bulb', V(0.4, 0.5, 0.4), at(k / n) - V(0, 0.3, 0), H.warm, M.Neon)).CastShadow = false end
	end
	return g
end
local function orangeDrum(ctx, pos)
	local d = ctx:group('Drum')
	d:post('DrumBody', 0.9, 3, pos, C(222, 112, 40), M.SmoothPlastic)
	for _, y in { 0.8, 2 } do decor(d:post('DrumStripe', 0.92, 0.4, pos + V(0, y, 0), H.offWhite, M.SmoothPlastic)) end
	return d
end
local function tireStack(ctx, pos, n)
	local t = ctx:group('Tires')
	for k = 0, n - 1 do t:part('Tire', V(0.9, 2.6, 2.6), CFrame.new(pos + V(0, 0.45 + k * 0.9, 0)) * CFrame.Angles(0, 0, math.pi / 2), H.ink, M.Rubber, Enum.PartType.Cylinder) end
	return t
end
---------------------------------------------------------------------------------------------- ground floors
local function homeFloor(doorX, doorColor)
	return function(c, o)
		for _, x in o.bays do
			if math.abs(x - doorX) > 3.2 then window(c, x, SW + 2.6, { w = 2.8, h = 5, trim = o.trim, bars = true }) end
		end
		streetDoor(c, doorX, doorColor)
	end
end
local function shopFloor(x0, x1, shop, doorX)
	return function(c)
		shopfront(c, x0, x1, shop)
		if doorX then streetDoor(c, doorX, H.brown) end
	end
end

---------------------------------------------------------------------------------------------- the ten blocks
-- Each block is the 48 studs behind its stage wall (hood_games_maps.md section 6). L and R list the lots
-- from the gate end down the street; props use stage-local positions (z = 0 at the wall).
local function lay(ctx, s, za, lots)
	local z = za
	for _, lot in lots do
		lot[2](lotFrame(ctx, s, z, lot[1]), lot[1], s)
		z -= lot[1]
	end
end
local function cars(ctx, za, list)
	for _, c in list do
		local x, zl, color, kind = c[1], c[2], c[3], c[4]
		car(ctx, CFrame.new(x, 0, za + zl) * CFrame.Angles(0, x < 0 and math.pi or 0, 0), color, kind)
	end
end
local function lamps(ctx, za, list)
	for _, l in list do cobraLamp(ctx, V(l[1], SW, za + l[2]), l[1] < 0 and 1 or -1) end
end

local BLOCKS = {}

-- 1. The Block: a corner deli, a brownstone on moving day, a red walk-up with a fire escape and a tank;
-- across the street a buff six-storey with the barbershop, the garden lot and a closed shop.
BLOCKS[1] = function(ctx, za)
	lay(ctx, -1, za, {
		{ 18, function(f, w)
			local c = walkup(f, 'L1_Deli', { w = w, floors = 4, wall = H.red, trim = H.offWhite, bays = { 4, 9, 14 }, seed = 11, sideAt = 0,
				lit = { ['3:2'] = true }, ground = shopFloor(0.5, 12.5, { sign = 'SUNNY DELI • GROCERY', band = H.green, awning = H.green, door = 'right' }, 15.3) })
			decor(c:box('OpenSign', V(2, SW + 5, 0.12), V(4, SW + 5.8, 0.2), H.warm, M.Neon))
		end },
		{ 16, function(f, w)
			local _, _, front, stoopX, parlour = brownstone(f, 'L2_Brownstone', w, { pigeons = true, litParlour = true, seed = 5 })
			movingBoxes(front, V(stoopX - 1.2, parlour, 0.4), 2)
			movingBoxes(front, V(stoopX + 3.2, SW, 7.4), 3)
		end },
		{ 14, function(f, w)
			walkup(f, 'L3_WalkUp', { w = w, floors = 5, wall = H.red, trim = H.offWhite, cornice = H.darkConcrete, bays = { 2.8, 7, 11.2 }, seed = 23,
				lit = { ['5:3'] = true }, ground = homeFloor(7, H.ink), escape = { 0.8, 13.2 }, tank = true })
		end },
	})
	lay(ctx, 1, za, {
		{ 20, function(f, w, s)
			walkup(f, 'R1_Barbershop', { w = w, floors = 6, wall = H.buff, trim = H.brown, bays = { 2.5, 7.5, 12.5, 17.5 }, seed = 31, sideAt = w,
				lit = { ['4:2'] = true, ['6:4'] = true },
				ground = shopFloor(9, 19, { sign = 'FRESH CUTS', band = H.ink, door = 'left' }, 5), escape = { 0.5, 10 } })
			barberPole(f, V(8.4, SW + 4, 0.7))
		end },
		{ 12, function(f, w)
			gardenLot(f, w)
			wallMural(f, w, w, 'THE BLOCK')
		end },
		{ 16, function(f, w)
			local c = walkup(f, 'R3_ClosedShop', { w = w, floors = 3, wall = H.brown, trim = H.offWhite, bays = { 3, 8, 13 }, seed = 41,
				ground = shopFloor(5, 15, { sign = '99¢ & UP', band = H.offWhite, text = H.ink, gate = 'down' }, 2.4) })
			-- The block's one tag, low on the gate, and wheatpaste posters on the pier.
			for _, d in { { 7, 3, 9.6, 5.2 }, { 8.8, 2.6, 10.6, 5.6 }, { 10.2, 3.4, 11.4, 6 }, { 7.6, 5.4, 11, 5.3 } } do
				decor(plank(c, 'Tag', V(d[1], d[2], 0.42), V(d[3], d[4], 0.42), 0.05, 0.3, H.ink))
			end
			for k = 0, 2 do decor(c:part('Poster', V(2, 3, 0.05), CFrame.new(3.4, SW + 4 + k * 0.4, 0.33) * CFrame.Angles(0, 0, math.rad(k * 4 - 4)), H.offWhite, M.SmoothPlastic)) end
		end },
	})
	-- Street props (spec 8.4).
	lamps(ctx, za, { { -11.2, -10 }, { 11.2, -26 }, { -11.2, -40 } })
	trafficSignal(ctx, V(11.2, SW, za - 1.5), -1)
	hydrantProp(ctx, V(11.6, SW, za - 22.5))
	litterBasket(ctx, V(-11.4, SW, za - 2.5))
	mailboxProp(ctx, V(-11.8, SW, za - 6), 1)
	trashBags(ctx, V(-12, SW, za - 16))
	streetTree(ctx, V(-14.5, SW, za - 24))
	milkCrates(ctx, V(-18.6, SW, za - 1.8), true)
	aFrame(ctx, V(-16.5, SW, za - 8), 1, 'CHOPPED CHEESE')
	cars(ctx, za, { { -7.4, -18, H.offWhite }, { -7.4, -31, H.darkConcrete, 'suv' }, { 7.4, -12, H.ink }, { 7.4, -27, H.signal } })
end

-- 2. The Court: a fenced cage with a handball wall on the right; a buff school and a walk-up opposite.
BLOCKS[2] = function(ctx, za)
	lay(ctx, -1, za, {
		{ 32, function(f, w)
			local c = walkup(f, 'PS48', { w = w, floors = 4, wall = H.buff, trim = H.offWhite, cornice = H.offWhite, bays = bays(w, 6), seed = 51,
				ground = function(c2, o)
					for _, x in o.bays do if math.abs(x - w / 2) > 5 then window(c2, x, SW + 3, { w = 3, h = 5.5, trim = o.trim }) end end
					for _, x in { w / 2 - 1.8, w / 2 + 1.8 } do streetDoor(c2, x, H.green) end
				end })
			local plate = c:box('SchoolName', V(w / 2 - 6, floorY(2) + 0.6, 0), V(w / 2 + 6, floorY(2) + 2.6, 0.3), H.offWhite, M.SmoothPlastic)
			streetText(plate, 'P.S. 48 • THE BLOCK SCHOOL', H.ink, FONT.title)
		end },
		{ 16, function(f, w)
			walkup(f, 'WalkUp', { w = w, floors = 4, wall = H.red, trim = H.offWhite, bays = bays(w, 3), seed = 57,
				ground = shopFloor(0.5, 11, { sign = 'CELL REPAIR', band = H.ink, door = 'left' }, 13.5) })
		end },
	})
	lay(ctx, 1, za, { { 48, function(f, w) courtLot(f, w); wallMural(f, w, 0, 'BOXING NIGHT') end } })
	lamps(ctx, za, { { -11.2, -8 }, { 11.2, -24 }, { -11.2, -40 } })
	hydrantProp(ctx, V(-11.6, SW, za - 30))
	litterBasket(ctx, V(11.4, SW, za - 4))
	cars(ctx, za, { { -7.4, -16, H.concrete }, { -7.4, -29, H.offWhite }, { 7.4, -14, H.darkConcrete, 'suv' } })
end

-- 3. Corner-store Avenue: a two-storey taxpayer row of four shops, a deli and a walk-up opposite, a bus
-- shelter, and a box truck double-parked (the Delivery Truck wall).
BLOCKS[3] = function(ctx, za)
	lay(ctx, -1, za, {
		{ 48, function(f, w)
			walkup(f, 'TaxpayerRow', { w = w, floors = 2, wall = H.brown, trim = H.offWhite, bays = bays(w, 8, 5.6), seed = 61,
				ground = function(c)
					shopfront(c, 0.5, 11.5, { sign = 'LAUNDROMAT', band = H.offWhite, text = H.ink })
					shopfront(c, 12.5, 23.5, { sign = 'CELL REPAIR', band = H.ink })
					shopfront(c, 24.5, 35.5, { sign = 'WING SPOT', band = H.signal, awning = H.signal })
					shopfront(c, 36.5, 47.5, { sign = '99¢ & UP', band = H.offWhite, text = H.ink, gate = 'down' })
				end })
		end },
	})
	lay(ctx, 1, za, {
		{ 24, function(f, w)
			walkup(f, 'CornerDeli', { w = w, floors = 5, wall = H.brown, trim = H.offWhite, bays = bays(w, 4), seed = 67,
				ground = shopFloor(6, 23.5, { sign = 'CORNER DELI • 24/7', band = H.green, awning = H.green, door = 'left' }, 2.6), tank = true })
		end },
		{ 24, function(f, w)
			walkup(f, 'WalkUp', { w = w, floors = 5, wall = H.red, trim = H.offWhite, cornice = H.darkConcrete, bays = bays(w, 4), seed = 71,
				ground = homeFloor(12, H.brown), escape = { 6.5, 17.5 } })
		end },
	})
	-- Bus shelter on the right sidewalk.
	local bs = ctx:at(CFrame.lookAt(V(13.4, SW, za - 20), V(12.4, SW, za - 20))):group('BusShelter')
	for _, x in { -6.5, 6.5 } do for _, z in { -2.2, 2.2 } do bs:box('ShelterPost', V(x - 0.15, 0, z - 0.15), V(x + 0.15, 8.6, z + 0.15), H.concrete, M.Metal) end end
	bs:box('ShelterRoof', V(-6.8, 8.6, -2.6), V(6.8, 9, 2.6), H.concrete, M.Metal)
	local back = bs:box('ShelterBack', V(-6.5, 1, 2.1), V(6.5, 8, 2.2), H.concrete, M.Glass)
	back.Transparency = 0.7
	local ad = bs:box('ShelterAd', V(-6.6, 1, -2.2), V(-6.5, 8, 2.2), H.ink, M.SmoothPlastic)
	line(surface(ad, Enum.NormalId.Left, 20), 'Text', 'THE BLOCK\nBOXING', H.warm, FONT.loud, 0.2, 0.6)
	bench(bs, V(0, 0, 0.8), V(0, 0, -1))
	lamps(ctx, za, { { -11.2, -12 }, { 11.2, -16 }, { -11.2, -38 } })
	car(ctx, CFrame.new(-3, 0, za - 24) * CFrame.Angles(0, math.pi, 0), H.offWhite, 'truck')
	cars(ctx, za, { { 7.4, -8, H.ink }, { -7.4, -36, H.concrete } })
	trashBags(ctx, V(-12, SW, za - 30))
	hydrantProp(ctx, V(11.6, SW, za - 40))
end

-- 4. Summer Block: two-storey rowhouses with porches under striped metal awnings, an open hydrant
-- spraying into the street (the Hydrant Spray wall), chalk on the sidewalk.
local function rowhouse(f, w, wall, stripe, seed)
	local c = walkup(f, 'Rowhouse', { w = w, floors = 2, wall = wall, trim = H.offWhite, bays = bays(w, 2, 6), seed = seed,
		ground = function(c2) window(c2, w * 0.3, SW + 3.6, { w = 3.6, h = 5, trim = H.offWhite }); streetDoor(c2, w * 0.75, H.brown) end })
	studs(c:box('Porch', V(0.4, SW, 0), V(w - 0.4, SW + 1.2, 5), H.offWhite, M.Plastic))
	for _, x in { 0.8, w - 0.8 } do c:post('PorchPost', 0.2, 8, V(x, SW + 1.2, 4.6), H.offWhite, M.Metal) end
	c:box('PorchRail', V(0.4, SW + 3.8, 4.5), V(w * 0.62, SW + 4.1, 4.8), H.offWhite, M.Metal)
	-- Striped aluminium awning over the porch.
	for k = 0, 7 do
		local x0 = 0.4 + (w - 0.8) * k / 8
		local x1 = 0.4 + (w - 0.8) * (k + 1) / 8
		decor(c:wedge('PorchAwning', V(x1 - x0, 1.6, 5.2), CFrame.new((x0 + x1) / 2, SW + 10, 2.6) * CFrame.Angles(0, math.pi, 0), k % 2 == 0 and stripe or H.offWhite, M.Metal))
	end
	return c
end
BLOCKS[4] = function(ctx, za)
	lay(ctx, -1, za, {
		{ 16, function(f, w) rowhouse(f, w, H.red, H.green, 81) end },
		{ 16, function(f, w) rowhouse(f, w, H.brown, H.offWhite:Lerp(H.ink, 0.5), 83) end },
		{ 16, function(f, w) rowhouse(f, w, H.red, H.green, 85) end },
	})
	lay(ctx, 1, za, {
		{ 16, function(f, w) rowhouse(f, w, H.brown, H.green, 87) end },
		{ 16, function(f, w) rowhouse(f, w, H.red, H.offWhite:Lerp(H.ink, 0.5), 89) end },
		{ 16, function(f, w) rowhouse(f, w, H.buff, H.green, 91) end },
	})
	-- The open hydrant: spray across the gutter and a puddle.
	hydrantProp(ctx, V(11.6, SW, za - 22))
	local puddle = decor(ctx:box('Puddle', V(2, 0, za - 27), V(10, 0.05, za - 17), C(120, 150, 170), M.Glass))
	puddle.Transparency = 0.35
	local nozzle = ghost(ctx:box('SprayNozzle', V(10.4, SW + 1.4, za - 22.4), V(10.8, SW + 2.2, za - 21.6), P.white))
	local spray = Instance.new('ParticleEmitter')
	spray.Name = 'HydrantSpray'
	spray.Texture = 'rbxasset://textures/particles/smoke_main.dds'
	spray:SetAttribute('PreviewTexture', 'smoke')
	spray.Rate, spray.Lifetime, spray.Speed = 60, NumberRange.new(0.6, 0.9), NumberRange.new(18, 24)
	spray.EmissionDirection = Enum.NormalId.Left
	spray.SpreadAngle = Vector2.new(8, 8)
	spray.Acceleration = V(0, -40, 0)
	spray.Size = NumberSequence.new(0.6, 1.6)
	spray.Transparency = NumberSequence.new(0.2, 1)
	spray.Color = ColorSequence.new(C(230, 244, 255))
	spray.LightInfluence = 1
	spray.Parent = nozzle
	-- Hopscotch chalk on the left sidewalk.
	for k = 0, 5 do decor(ctx:box('Chalk', V(-17, SW, za - 10.4 - k * 1.8), V(-15.4, SW + 0.04, za - 12 - k * 1.8), H.offWhite, M.SmoothPlastic)) end
	lamps(ctx, za, { { -11.2, -10 }, { 11.2, -34 } })
	streetTree(ctx, V(-14.5, SW, za - 40))
	cars(ctx, za, { { -7.4, -14, H.darkConcrete }, { -7.4, -34, H.offWhite, 'suv' }, { 7.4, -36, H.ink } })
end

-- 5. Gas & Auto: a gas station on the right; an auto shop with roll-up doors and a fenced yard of drums
-- and tyres on the left (the Construction Barrier wall).
BLOCKS[5] = function(ctx, za)
	lay(ctx, -1, za, {
		{ 24, function(f, w)
			local c = walkup(f, 'AutoShop', { w = w, floors = 2, wall = H.buff, trim = H.offWhite, bays = bays(w, 4), seed = 101,
				ground = function(c2)
					for _, x in { 6, 18 } do
						c2:box('GarageDoor', V(x - 4.8, SW, 0), V(x + 4.8, SW + 9.4, 0.3), H.concrete, M.Metal)
						for y = SW + 1, SW + 9, 1.2 do decor(c2:box('GarageSlat', V(x - 4.8, y, 0.3), V(x + 4.8, y + 0.12, 0.38), H.darkConcrete, M.Metal)) end
					end
					local sign = c2:box('SignBand', V(0.5, SW + 9.6, 0), V(w - 0.5, SW + 11.2, 0.4), H.ink, M.SmoothPlastic)
					streetText(sign, 'AUTO REPAIR • TIRES', H.warm)
				end })
			tireStack(c, V(12, SW, 1.6), 4)
			tireStack(c, V(13.6, SW, 3), 3)
		end },
		{ 24, function(f, w)
			lotGround(f, w)
			chainLink(f, V(0.2, SW - 0.1, 0.2), V(w - 0.2, SW - 0.1, 0.2), 9, { { 8, 16 } })
			for _, p in { V(4, SW - 0.1, -6), V(6, SW - 0.1, -9), V(18, SW - 0.1, -7) } do orangeDrum(f, p) end
			tireStack(f, V(20, SW - 0.1, -14), 5)
			car(f, CFrame.new(w / 2, SW - 0.1, -22) * CFrame.Angles(0, math.pi / 2, 0), H.concrete, 'sedan')
		end },
	})
	lay(ctx, 1, za, { { 48, function(f, w) gasLot(f, w); wallMural(f, w, 0, 'COME UP') end } })
	-- Barrier stripes on the parking lane where the street is being dug up.
	for k = 0, 2 do orangeDrum(ctx, V(-7.4, 0, za - 34 - k * 4)) end
	lamps(ctx, za, { { -11.2, -6 }, { -11.2, -40 } })
	cars(ctx, za, { { 7.4, -40, H.offWhite } })
end

-- 6. Sidewalk-Shed Street: walk-ups both sides, a green shed over the left sidewalk with posters, and a
-- pipe scaffold climbing a facade on the right (the Scaffolding wall).
BLOCKS[6] = function(ctx, za)
	lay(ctx, -1, za, {
		{ 24, function(f, w) walkup(f, 'WalkUp', { w = w, floors = 5, wall = H.red, trim = H.offWhite, bays = bays(w, 4), seed = 121, ground = shopFloor(0.5, 15, { sign = 'HARDWARE', band = H.ink }, 19) }) end },
		{ 24, function(f, w) walkup(f, 'WalkUp', { w = w, floors = 4, wall = H.buff, trim = H.brown, cornice = H.brown, bays = bays(w, 4), seed = 123, ground = homeFloor(12, H.brown), tank = true }) end },
	})
	lay(ctx, 1, za, {
		{ 24, function(f, w)
			local c = walkup(f, 'WalkUp', { w = w, floors = 6, wall = H.brown, trim = H.offWhite, bays = bays(w, 4), seed = 125, ground = homeFloor(12, H.ink) })
			pipeScaffold(c, 1, w - 1, 6)
		end },
		{ 24, function(f, w) walkup(f, 'WalkUp', { w = w, floors = 4, wall = H.red, trim = H.offWhite, cornice = H.darkConcrete, bays = bays(w, 4), seed = 127, ground = shopFloor(9, 23.5, { sign = 'NAILS & BEAUTY', band = H.offWhite, text = H.ink }, 4), escape = { 1, 12 } }) end },
	})
	sidewalkShed(ctx, -ROAD - 0.8, -FACADE, za - 4, za - 44)
	lamps(ctx, za, { { 11.2, -12 }, { 11.2, -40 } })
	cars(ctx, za, { { -7.4, -20, H.ink }, { 7.4, -24, H.concrete, 'suv' } })
end

-- 7. Under the El: black steel columns on the kerb lines, the track overhead, food carts on the sidewalks
-- (the Food Cart Line wall).
BLOCKS[7] = function(ctx, za)
	lay(ctx, -1, za, {
		{ 20, function(f, w) walkup(f, 'WalkUp', { w = w, floors = 3, wall = H.brown, trim = H.offWhite, bays = bays(w, 4), seed = 141, ground = shopFloor(0.5, 14, { sign = 'TACOS • SANDWICHES', band = H.green, awning = H.green }, 17) }) end },
		{ 28, function(f, w) walkup(f, 'WalkUp', { w = w, floors = 4, wall = H.red, trim = H.offWhite, bays = bays(w, 5), seed = 143, ground = homeFloor(14, H.brown), escape = { 2, 13 } }) end },
	})
	lay(ctx, 1, za, {
		{ 28, function(f, w) walkup(f, 'WalkUp', { w = w, floors = 4, wall = H.buff, trim = H.brown, cornice = H.brown, bays = bays(w, 5), seed = 145, ground = shopFloor(10, 27.5, { sign = 'RECORDS • SNEAKERS', band = H.ink }, 5) }) end },
		{ 20, function(f, w) walkup(f, 'WalkUp', { w = w, floors = 3, wall = H.red, trim = H.offWhite, bays = bays(w, 4), seed = 147, ground = homeFloor(10, H.ink) }) end },
	})
	elevated(ctx, za - 2, za - 46)
	foodCart(ctx, V(-14, SW, za - 18), 1, 'HOT FOOD')
	foodCart(ctx, V(14, SW, za - 30), -1, 'ICE • FRUIT')
	cars(ctx, za, { { 7.4, -14, H.offWhite }, { -7.4, -34, H.darkConcrete } })
end

-- 8. Block Party: the street closed with sawhorses, a DJ table and speakers, warm string lights between
-- the fire escapes.
BLOCKS[8] = function(ctx, za)
	lay(ctx, -1, za, {
		{ 16, function(f, w) brownstone(f, 'Brownstone', w, { seed = 161, door = H.green }) end },
		{ 16, function(f, w) brownstone(f, 'Brownstone', w, { seed = 163, door = H.brown, pigeons = true }) end },
		{ 16, function(f, w) brownstone(f, 'Brownstone', w, { seed = 165, door = H.signal }) end },
	})
	lay(ctx, 1, za, {
		{ 24, function(f, w) walkup(f, 'WalkUp', { w = w, floors = 4, wall = H.red, trim = H.offWhite, bays = bays(w, 4), seed = 167, ground = homeFloor(12, H.brown), escape = { 6.5, 17.5 } }) end },
		{ 24, function(f, w) walkup(f, 'WalkUp', { w = w, floors = 5, wall = H.buff, trim = H.brown, cornice = H.brown, bays = bays(w, 4), seed = 169, ground = homeFloor(12, H.ink), tank = true }) end },
	})
	for _, zl in { -4, -44 } do
		for _, x in { -7, 7 } do sawhorse(ctx, CFrame.new(x, 0, za + zl)) end
	end
	-- DJ table and speakers on the right sidewalk.
	ctx:box('DJTable', V(13, SW + 2.6, za - 26), V(16, SW + 3, za - 20), H.ink, M.SmoothPlastic)
	for _, z in { -25.4, -20.6 } do ctx:box('DJTableLeg', V(14.3, SW, za + z - 0.2), V(14.7, SW + 2.6, za + z + 0.2), H.concrete, M.Metal) end
	speakerStack(ctx, V(14.5, SW, za - 29))
	speakerStack(ctx, V(14.5, SW, za - 17))
	for k, zl in { -12, -24, -36 } do warmLights(ctx, V(-FACADE, 22 + k, za + zl), V(FACADE, 24 - k, za + zl - 4), 3) end
	lamps(ctx, za, { { -11.2, -30 }, { 11.2, -10 } })
end

-- 9. The Projects: plain brick towers set back on asphalt plazas, benches and a playground.
BLOCKS[9] = function(ctx, za)
	lay(ctx, -1, za, { { 48, function(f, w) projectsLot(f, w, 10, 12) end } })
	lay(ctx, 1, za, { { 48, function(f, w) projectsLot(f, w, 12, 10) end } })
	lamps(ctx, za, { { -11.2, -12 }, { 11.2, -24 }, { -11.2, -38 } })
	cars(ctx, za, { { -7.4, -24, H.concrete }, { 7.4, -36, H.offWhite } })
end

-- 10. The Station: the Champ Ring in the street and Juniper St station across the end, the way out to
-- World 2 (the Station Turnstile wall).
BLOCKS[10] = function(ctx, za, skins)
	lay(ctx, -1, za, {
		{ 24, function(f, w) walkup(f, 'WalkUp', { w = w, floors = 4, wall = H.red, trim = H.offWhite, bays = bays(w, 4), seed = 181, ground = shopFloor(0.5, 15, { sign = 'BOXING SUPPLY', band = H.signal }, 19) }) end },
		{ 32, function(f, w) walkup(f, 'WalkUp', { w = w, floors = 5, wall = H.buff, trim = H.brown, cornice = H.brown, bays = bays(w, 6), seed = 183, ground = homeFloor(16, H.brown), escape = { 3.5, 14.5 } }) end },
	})
	lay(ctx, 1, za, {
		{ 32, function(f, w) walkup(f, 'WalkUp', { w = w, floors = 5, wall = H.brown, trim = H.offWhite, bays = bays(w, 6), seed = 185, ground = homeFloor(16, H.ink), tank = true }) end },
		{ 24, function(f, w) walkup(f, 'WalkUp', { w = w, floors = 4, wall = H.red, trim = H.offWhite, cornice = H.darkConcrete, bays = bays(w, 4), seed = 187, ground = shopFloor(9, 23.5, { sign = 'HOOD GYM', band = H.ink }, 4) }) end },
	})
	local ring = skins.Stations[9]
	Props.ring(ctx:at(CFrame.new(0, 0, za - 24)):group('Training_' .. ring.Id), PROPS_KIT, ring, 6)
	-- Juniper St station across the end of the street.
	local st = ctx:at(CFrame.lookAt(V(0, 0, STREET_END), V(0, 0, STREET_END + 1)))
	st:box('StationFace', V(-FACADE, -1, 0), V(FACADE, 22, 24), H.offWhite, M.SmoothPlastic)
	studs(st:box('StationRoof', V(-FACADE, 22, 0), V(FACADE, 22.4, 24), H.darkConcrete, M.Plastic))
	decor(st:box('StationStripe', V(-FACADE, SW + 9.6, -0.1), V(FACADE, SW + 10.6, 0), H.green, M.SmoothPlastic))
	local sign = st:box('StationSign', V(-14, 14, -0.5), V(14, 18, 0), H.ink, M.SmoothPlastic)
	local sg = surface(sign, Enum.NormalId.Front, 25)
	line(sg, 'Title', 'JUNIPER ST STATION', H.offWhite, FONT.title, 0.08, 0.5)
	line(sg, 'Detail', 'WORLD 2 • COMING SOON', C(255, 200, 60), FONT.body, 0.62, 0.3)
	st:box('StairWell', V(-6, 0, -0.2), V(6, SW + 9, 0), H.ink, M.SmoothPlastic)
	for _, x in { -6.4, 6.4 } do
		st:box('StairRail', V(x - 0.2, SW, -6), V(x + 0.2, SW + 3.4, 0), H.green, M.Metal)
		st:post('GlobePost', 0.2, 6, V(x, SW, -6.4), H.green, M.Metal)
		local globe = decor(st:blob('Globe', V(1.2, 1.2, 1.2), V(x, SW + 6.6, -6.4), C(120, 230, 150), M.Neon))
		light(globe, C(120, 230, 150), 1, 12)
	end
	lamps(ctx, za, { { -11.2, -6 }, { 11.2, -6 }, { -11.2, -44 }, { 11.2, -44 } })
end

---------------------------------------------------------------------------------------------- road and sidewalks
-- Asphalt road between off-white kerbs, concrete sidewalks with joints every 5, a dashed faded-yellow
-- centre line, a crosswalk just behind every stage wall, the odd manhole and patch.
local function buildRoad(ctx)
	local r = ctx:group('Road')
	r:box('Road', V(-ROAD, -1, STREET_END), V(ROAD, 0, 0), H.asphalt, M.Asphalt)
	for _, s in { -1, 1 } do
		r:box('Sidewalk', V(s * (ROAD + 0.6), -1, STREET_END), V(s * FACADE, SW, 0), H.concrete, M.Concrete)
		r:box('Kerb', V(s * ROAD, -1, STREET_END), V(s * (ROAD + 0.6), SW + 0.02, 0), H.offWhite, M.Concrete)
		for z = -5, STREET_END + 1, -5 do decor(r:box('SidewalkJoint', V(s * (ROAD + 0.6), SW, z - 0.08), V(s * FACADE, SW + 0.02, z + 0.08), H.darkConcrete, M.SmoothPlastic)) end
	end
	for z = -6, STREET_END + 4, -8 do decor(r:box('CentreDash', V(-0.25, 0, z - 4), V(0.25, 0.04, z), H.lineYellow, M.SmoothPlastic)) end
	for i = 1, 10 do
		local z = stageZ(i) - 2.5
		for _, x in { -8, -4.8, -1.6, 1.6, 4.8, 8 } do decor(r:box('Crosswalk', V(x - 0.7, 0, z - 2), V(x + 0.7, 0.05, z + 2), H.offWhite, M.SmoothPlastic)) end
		decor(r:part('Manhole', V(0.06, 2.4, 2.4), CFrame.new(3, 0.03, stageZ(i) - 20) * CFrame.Angles(0, 0, math.pi / 2), H.darkConcrete, M.Metal, Enum.PartType.Cylinder))
		decor(r:box('Patch', V(-6, 0, stageZ(i) - 33), V(-1, 0.03, stageZ(i) - 29), C(84, 84, 88), M.Asphalt))
	end
	return r
end

local function buildStreet(ctx, walls, skins)
	local street = ctx:group('Street')
	buildRoad(street)
	for i, w in walls do
		buildGate(street, i, w)
		local block = street:group('Block' .. i)
		BLOCKS[i](block, stageZ(i), skins)
	end
	-- Canyon dressing before the first wall: lamps and the sign pointing in.
	cobraLamp(street, V(-11.2, SW, -4), 1)
	cobraLamp(street, V(11.2, SW, -4), -1)
	return street
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
	root:SetAttribute('BuildVersion', 'V2 reference 1')
	root:SetAttribute('Origin', V2.Origin.Position)
	root:SetAttribute('LobbySpawn', SPAWN)
	local ctx = newCtx(root, CFrame.new())

	local floors = planFloors()
	PLAN = floors
	local cliffs = planCliffs(floors)
	buildGround(ctx, floors)
	buildCliffs(ctx, cliffs)
	buildLobby(ctx, cliffs, skins, crew, art)
	buildStreet(ctx, maps.ById.Block.Walls, skins)

	root.Parent = workspace
	local count = 0
	for _, d in root:GetDescendants() do if d:IsA('BasePart') then count += 1 end end
	pcall(function() game:GetService('ChangeHistoryService'):SetWaypoint('TheBlockV2 built') end)
	pcall(function() require(game:GetService('ServerStorage').HoodLighting).Apply('FrontPage') end)
	V2.SetActive(true)
	print(string.format('[TheBlockV2] Built %d parts at %s. Press Play to spawn on the Block; select TheBlockV2 and press F to fly there.', count, tostring(V2.Origin.Position)))
	return { parts = count }
end

return V2
