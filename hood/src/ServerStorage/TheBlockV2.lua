-- The Block, version 2: a second take on World 1, built far away from the original so the two can be compared.
-- Edit-time builder; it only ever creates or replaces Workspace.TheBlockV2 and touches nothing else in the place.
-- Command Bar:  require(game.ServerStorage.TheBlockV2).Build()
--
-- Layout (local studs, floor top at y = 0, -Z runs from the lobby into the stages):
--   lobby    x -64..64, z 0..104   spawn plaza at the back, Drip Stand front-right, Boxing Club front-left
--   stages   x -20..20, z 0..-300  ten see-through stage walls 28 studs apart
--   terraces three stepped brick tiers (8 / 14 / 20 studs) around everything walkable
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
	lawnA = C(142, 214, 74), lawnB = C(128, 202, 64),
	pathA = C(234, 236, 240), pathB = C(218, 222, 230), pathRim = C(150, 156, 168),
	walkA = C(212, 212, 216), walkB = C(198, 198, 204),
	clubA = C(74, 82, 102), clubB = C(64, 72, 92),
	road = C(66, 68, 76), roadLine = C(255, 210, 64), paint = C(246, 246, 240),
	brick = { C(204, 108, 72), C(186, 94, 62), C(166, 82, 56) }, cap = { C(132, 210, 70), C(122, 200, 62), C(112, 190, 56) },
	trim = C(238, 230, 212), iron = C(44, 48, 54), steel = C(118, 128, 138), glass = C(64, 92, 118), glassLit = C(255, 214, 140),
	white = C(250, 250, 252), black = C(26, 26, 30), navy = C(28, 44, 92), yellow = C(255, 204, 48), cyan = C(64, 228, 242),
	magenta = C(238, 74, 172), orange = C(250, 140, 46), red = C(226, 56, 62), blue = C(56, 116, 232), purple = C(150, 84, 226),
	wood = C(150, 100, 62), woodDark = C(104, 70, 46), bark = C(116, 78, 50), leaf = { C(104, 196, 70), C(88, 178, 58), C(124, 212, 82) },
	cardboard = C(196, 150, 98), subway = C(46, 140, 92),
}

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
local G = { x0 = -96, x1 = 96, z0 = -328, z1 = 136 }
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

-- Stage walls: names and Power from the World 1 config, 28 studs apart down the corridor.
local STAGE_GAP, STAGE_FIRST = 28, -14
local function stageZ(i) return STAGE_FIRST - (i - 1) * STAGE_GAP end

local CHECKER = { lawn = { P.lawnA, P.lawnB }, path = { P.pathA, P.pathB }, walk = { P.walkA, P.walkB }, club = { P.clubA, P.clubB } }
-- Walkable floor plan. Later paints win.
local function planFloors()
	local g = newGrid()
	paint(g, -64, 0, 64, 104, 'lawn')
	paint(g, -20, -300, 20, 0, 'walk')
	paint(g, -12, -300, 12, 84, 'road')
	paint(g, -20, 0, -12, 84, 'walk')
	paint(g, 12, 0, 20, 84, 'walk')
	paint(g, -24, 84, 24, 104, 'path')
	paint(g, -60, 48, -12, 56, 'path')
	paint(g, 12, 48, 60, 56, 'path')
	paint(g, -64, 4, -24, 44, 'club')
	paint(g, 20, 0, 64, 44, 'path')
	paint(g, -56, 60, -24, 92, 'path')
	paint(g, 40, 68, 52, 80, 'pit')
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
local function buildTerraces(ctx, tier)
	local t = ctx:group('Terraces')
	merge(function(i, j)
		local h = tierTop(tier, i, j)
		return h and (tier[i][j] .. ':' .. h)
	end, function(k, x0, z0, x1, z1)
		local n, h = k:match('^(%d+):(%d+)$')
		n, h = tonumber(n), tonumber(h)
		-- Each merged block gets its own slight shade, so long walls read as separate buildings, not one copy.
		local shade = 1 + ((hash(x0 // 4, z0 // 4) % 9) - 4) * 0.014
		local b = P.brick[n]
		studs(t:box('TerraceBlock', V(x0, -1, z0), V(x1, h - 1, z1), Color3.new(math.min(1, b.R * shade), math.min(1, b.G * shade), math.min(1, b.B * shade)), M.Plastic), true)
		studs(t:box('TerraceGrass', V(x0, h - 1, z0), V(x1, h, z1), P.cap[n], M.Plastic), true)
	end)
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
		local color = P.cap[f.tier] or P.cap[1]
		for _, sp in spans do
			if sp[2] - sp[1] > 0.5 then
				local out = f.normal * LIP_OUT
				local lo, hi
				if f.alongX then
					lo, hi = V(sp[1], f.y1 - LIP_DROP, f.at), V(sp[2], f.y1, f.at + out.Z)
				else
					lo, hi = V(f.at, f.y1 - LIP_DROP, sp[1]), V(f.at + out.X, f.y1, sp[2])
				end
				studs(lips:box('GrassLip', lo, hi, color, M.Plastic), true)
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
local function window(ctx, lit)
	ctx:box('Glass', V(-1.2, 0, -0.12), V(1.2, 3, 0), lit and P.glassLit or P.glass, M.Glass)
	ctx:box('Frame', V(-1.45, 3, -0.25), V(1.45, 3.3, 0), P.trim, M.SmoothPlastic)
	ctx:box('Frame', V(-1.45, -0.3, -0.25), V(1.45, 0, 0), P.trim, M.SmoothPlastic)
	ctx:box('Frame', V(-1.45, 0, -0.25), V(-1.2, 3, 0), P.trim, M.SmoothPlastic)
	ctx:box('Frame', V(1.2, 0, -0.25), V(1.45, 3, 0), P.trim, M.SmoothPlastic)
	ctx:box('Sill', V(-1.7, -0.6, -0.6), V(1.7, -0.3, 0), P.trim, M.SmoothPlastic)
	ctx:box('Mullion', V(-0.08, 0, -0.18), V(0.08, 3, -0.12), P.trim, M.SmoothPlastic)
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
local function decorateFaces(ctx, faces, reserved)
	local d = ctx:group('Facades')
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
					if f.y0 == 0 and h % 9 == 0 then
						local tag = TAGS[h % #TAGS + 1]
						graffiti(d:at(faceFrame(f, a, 1.2)), tag[1], tag[2], 7.2, 3.6)
					elseif f.y0 == 0 and f.y1 == TIER_TOP[1] and h % 6 == 1 then
						window(d:at(faceFrame(f, a, 3.6)), h % 4 == 1)
						fireEscape(d:at(faceFrame(f, a, 3)))
					elseif h % 7 == 3 and f.y0 > 0 then
						acUnit(d:at(faceFrame(f, a, base + 0.4)))
					else
						window(d:at(faceFrame(f, a, base)), h % 5 == 0)
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
	st:box('StringCourse', V(B.x0, 7.6, backZ - 0.3), V(B.x1 + 0.3, 8.1, B.z1), P.trim, M.SmoothPlastic)
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

---------------------------------------------------------------------------------------------- lobby: Block Boxing Club
-- Station frame: origin at the pad centre on the floor, -Z toward the aisle; the bag hangs over the back half.
local function hangingBag(ctx, radius, height, bottom, color, bands, bandColor, material)
	local z = 1.4
	ctx:post('Bag', radius, height, V(0, bottom, z), color, material or M.Leather)
	ctx:post('BagCap', radius * 0.85, 0.3, V(0, bottom + height, z), P.black, M.Leather)
	for _, f in bands do ctx:post('Band', radius + 0.05, 0.3, V(0, bottom + f * height - 0.15, z), bandColor, M.Fabric) end
	local ring = bottom + height + 1.2
	for _, d in { V(1, 0, 0), V(-1, 0, 0), V(0, 0, 1), V(0, 0, -1) } do ctx:bar('Strap', V(0, bottom + height + 0.3, z) + d * radius * 0.7, V(0, ring, z), 0.09, P.iron) end
	ctx:bar('Chain', V(0, ring, z), V(0, 9.3, z), 0.16, P.steel)
end
local GEAR = {}
function GEAR.TireBag(ctx)
	for k = 0, 2 do
		local y = 2.6 + k * 1.05
		ctx:post('Tire', 1.3, 1.0, V(0, y, 1.4), C(36, 36, 38), M.Rubber)
		ctx:post('TireHole', 0.6, 1.02, V(0, y - 0.01, 1.4), C(16, 16, 18), M.Rubber)
	end
	ctx:bar('Rope', V(0, 5.75, 1.4), V(0, 9.3, 1.4), 0.16, C(176, 140, 92), M.Fabric)
end
function GEAR.TapeBag(ctx) hangingBag(ctx, 1.2, 4.2, 2.2, C(140, 88, 52), { 0.2, 0.5, 0.8 }, C(186, 190, 194)) end
function GEAR.StreetBag(ctx) hangingBag(ctx, 1.3, 4.4, 2.0, C(44, 74, 150), { 0.25, 0.75 }, P.white) end
function GEAR.HeavyBag(ctx) hangingBag(ctx, 1.5, 5, 1.6, P.red, { 0.12, 0.88 }, P.black) end
function GEAR.SpeedBag(ctx)
	ctx:post('DropRod', 0.16, 3.4, V(0, 5.9, 1.4), P.iron)
	ctx:post('Platform', 2, 0.4, V(0, 5.5, 1.4), P.woodDark, M.Wood)
	ctx:blob('SpeedBag', V(0.9, 1.3, 0.9), V(0, 4.85, 1.4), P.orange, M.Leather)
end
function GEAR.DoubleEndBag(ctx)
	ctx:blob('Ball', V(1.6, 1.9, 1.6), V(0, 4.3, 1.4), P.purple, M.Leather)
	ctx:bar('UpperCord', V(0, 5.25, 1.4), V(0, 9.3, 1.4), 0.1, P.black, M.Fabric)
	ctx:bar('LowerCord', V(0, 3.35, 1.4), V(0, 0.3, 1.4), 0.1, P.black, M.Fabric)
	ctx:post('Anchor', 0.4, 0.3, V(0, 0, 1.4), P.iron)
end
function GEAR.ProBag(ctx) hangingBag(ctx, 1.1, 6, 1.2, C(34, 176, 176), { 0.1, 0.5, 0.9 }, P.black) end
function GEAR.GoldBag(ctx) hangingBag(ctx, 1.5, 5, 1.6, P.yellow, { 0.15, 0.5, 0.85 }, P.black, M.Foil) end

local function buildStation(ctx, station)
	local st = ctx:group('Training_' .. station.Id)
	-- Raised studded pad with a darker rim; the gallows post stands on the back corner.
	local dark = station.Color:Lerp(P.black, 0.25)
	studs(st:box('PadRim', V(-4, 0, -4), V(4, 0.5, 4), dark, M.Plastic), true)
	studs(st:box('TrainingZone', V(-3.4, 0.5, -3.4), V(3.4, 0.7, 3.4), station.Color, M.Plastic))
	local eq = st:at(CFrame.new(0, 0.7, 0)):group('Equipment')
	eq:box('Post', V(-3.4, 0, 2.4), V(-2.6, 9.8, 3.2), P.steel, M.Metal)
	eq:box('PostFoot', V(-3.6, 0, 2.2), V(-2.4, 0.3, 3.4), P.iron, M.Metal)
	eq:box('Arm', V(-2.6, 9.3, 1.0), V(0.5, 9.8, 1.8), P.steel, M.Metal)
	eq:bar('Brace', V(-2.6, 7.6, 2.8), V(-1.0, 9.3, 1.4), 0.3, P.steel)
	GEAR[station.Gear](eq)
	local sign = st:box('Sign', V(-3, 10.5, 2.4), V(3, 12.5, 2.7), P.black, M.SmoothPlastic)
	local g = surface(sign, Enum.NormalId.Front)
	line(g, 'Title', 'x' .. station.Multiplier .. ' POWER', station.Color:Lerp(P.white, 0.2), FONT.loud, 0.04, 0.56, P.black, 2)
	line(g, 'Detail', station.Required == 0 and 'FREE' or compact(station.Required) .. ' POWER', P.white, FONT.body, 0.62, 0.32)
	st:box('SignStem', V(-3.4, 9.8, 2.4), V(-2.6, 10.5, 3.2), P.steel, M.Metal)
	return st
end

local function chainFence(ctx, a, b, height)
	local f = ctx:group('ChainLink')
	local dir = b - a
	local n = math.max(1, math.floor(dir.Magnitude / 6))
	for k = 0, n do f:post('FencePost', 0.18, height + 0.2, a + dir * k / n, P.steel) end
	local cf = CFrame.lookAt((a + b) / 2, b)
	f:part('TopRail', V(0.2, 0.2, dir.Magnitude), cf + V(0, height, 0), P.steel, M.Metal)
	local mesh = decor(f:part('Mesh', V(0.06, height - 0.4, dir.Magnitude), cf + V(0, height / 2 + 0.1, 0), C(170, 176, 182), M.DiamondPlate))
	mesh.Transparency = 0.55
	mesh.CanCollide = true
	return f
end

local function buildBoxingClub(ctx, stations)
	local club = ctx:group('BoxingClub')
	-- Club floor is x -64..-24, z 4..44 (lobby frame). Two rows of four face a 12-stud aisle along X.
	local cols = { -28, -38, -48, -58 }
	local rows = { { z = 36, yaw = math.pi }, { z = 12, yaw = 0 } }
	-- Row at z 36 has its back to +Z (faces the aisle at -Z): rotate 180 so local -Z points at the aisle.
	local order = 0
	for c = 1, 4 do
		for r = 1, 2 do
			order += 1
			local s = stations[order]
			local cf = CFrame.new(cols[c], 0, rows[r].z) * CFrame.Angles(0, rows[r].yaw == 0 and math.pi or 0, 0)
			Props.station(club:at(cf), PROPS_KIT, s, order)
		end
	end
	-- Fence along the street side and cross path, with gaps for the aisle and a gate.
	chainFence(club, V(-24, 0, 4), V(-24, 0, 18), 7)
	chainFence(club, V(-24, 0, 30), V(-24, 0, 44), 7)
	chainFence(club, V(-62, 0, 44), V(-48, 0, 44), 7)
	chainFence(club, V(-40, 0, 44), V(-24, 0, 44), 7)
	-- Entrance arch over the aisle mouth.
	for _, z in { 18, 30 } do studs(club:box('ArchPier', V(-25, 0, z - 0.6), V(-23, 13, z + 0.6), C(150, 82, 62), M.Plastic), true) end
	local arch = club:box('ArchSign', V(-25, 10, 18.6), V(-23, 13, 29.4), P.black, M.SmoothPlastic)
	local g = surface(arch, Enum.NormalId.Right)
	line(g, 'Club', 'BLOCK BOXING', P.yellow, FONT.loud, 0.06, 0.6, C(120, 40, 20), 3)
	line(g, 'Tag', 'STAND ON A PAD TO TRAIN', P.white, FONT.body, 0.68, 0.26)
	club:box('ArchCap', V(-25.3, 13, 17.4), V(-22.7, 13.6, 30.6), P.trim, M.SmoothPlastic)
	-- Landmark: a giant glove on the arch, visible from the spawn and down the street.
	local glove = club:at(CFrame.lookAt(V(-24, 13.6, 24), V(-23, 13.6, 24))):group('GiantGlove')
	glove:post('Cuff', 1.7, 1.8, V(0, 0, 0), C(255, 239, 210), M.SmoothPlastic)
	glove:post('CuffBand', 1.75, 0.45, V(0, 1.35, 0), P.red, M.SmoothPlastic)
	glove:blob('Mitt', V(4.8, 5.4, 5), V(0, 4.3, -0.2), P.red, M.SmoothPlastic)
	glove:blob('Knuckles', V(4.2, 3, 2.4), V(0, 5.6, -1.9), P.red, M.SmoothPlastic)
	glove:blob('Thumb', V(1.7, 3.2, 1.9), V(2.05, 3.5, -1.2), C(214, 40, 52), M.SmoothPlastic)
	glove:blob('Shine', V(1.1, 1.6, 0.5), V(-1, 5.5, -2.5), C(255, 150, 160), M.SmoothPlastic)
	for k = 0, 3 do glove:bar('Lace', V(-0.6, 2.4 + k * 0.5, 2.1), V(0.6, 2.6 + k * 0.5, 2.15), 0.18, P.white, M.Fabric) end
	-- Gym odds and ends.
	for k = 0, 2 do club:post('TireStack', 1.3, 0.9, V(-61.4, k * 0.9, 28.2), C(36, 36, 38), M.Rubber) end
	bench(club, V(-62.2, 0, 22), V(1, 0, 0))
	for k, c in { P.red, P.blue } do crate(club, CFrame.new(-61.6, 0, 17.4 - k * 1.9), c) end
	return club
end

---------------------------------------------------------------------------------------------- lobby: Champ Ring
local function buildRing(ctx, station)
	local ring = ctx:group('Training_' .. station.Id)
	local h, s = 2.4, 8
	studs(ring:box('Apron', V(-s, 0, -s), V(s, h - 0.3, s), P.navy, M.Plastic), true)
	for _, side in { -1, 1 } do
		local skirt = ring:box('Skirt', V(-s - 0.1, 0.2, side * s), V(s + 0.1, h - 0.5, side * (s + 0.1)), P.red, M.Fabric)
		local g = surface(skirt, side > 0 and Enum.NormalId.Back or Enum.NormalId.Front)
		line(g, 'Brand', 'THE BLOCK', P.white, FONT.loud, 0.08, 0.84)
	end
	ring:box('TrainingZone', V(-s, h - 0.3, -s), V(s, h, s), C(238, 236, 228), M.Fabric)
	ring:box('Logo', V(-3, h, -3), V(3, h + 0.04, 3), station.Color, M.Fabric)
	local eq = ring:group('Equipment')
	local corners = { { -1, -1, P.red }, { 1, 1, P.blue }, { -1, 1, P.white }, { 1, -1, P.white } }
	for _, c in corners do
		local x, z = c[1] * (s - 0.5), c[2] * (s - 0.5)
		eq:post('CornerPost', 0.35, 4.4, V(x, h, z), P.steel)
		eq:box('CornerPad', V(x - 0.5, h + 0.9, z - 0.5), V(x + 0.5, h + 4, z + 0.5), c[3], M.Fabric)
	end
	local ropes = { P.red, P.white, P.blue }
	for level = 1, 3 do
		local y = h + 0.9 + level * 1.05
		for _, e in { { V(-1, 0, -1), V(1, 0, -1) }, { V(1, 0, -1), V(1, 0, 1) }, { V(1, 0, 1), V(-1, 0, 1) }, { V(-1, 0, 1), V(-1, 0, -1) } } do
			decor(eq:bar('Rope', e[1] * (s - 0.5) + V(0, y, 0), e[2] * (s - 0.5) + V(0, y, 0), 0.22, ropes[level], M.Fabric))
		end
	end
	for k = 1, 2 do studs(ring:box('RingStep', V(s + (2 - k) * 1.2, 0, -2.5), V(s + (3 - k) * 1.2, k * 0.8, 2.5), P.steel, M.Plastic)) end
	local T, w = 10, 0.45
	for _, c in corners do eq:box('TrussTower', V(c[1] * T - w, 0, c[2] * T - w), V(c[1] * T + w, 13, c[2] * T + w), P.iron, M.Metal) end
	for _, z in { -T, T } do eq:box('TrussBeam', V(-T - w, 13, z - w), V(T + w, 13.9, z + w), P.iron, M.Metal) end
	for _, x in { -T, T } do eq:box('TrussBeam', V(x - w, 13, -T + w), V(x + w, 13.9, T - w), P.iron, M.Metal) end
	for _, x in { -5, 5 } do
		for _, z in { -T, T } do
			eq:box('LampCan', V(x - 0.6, 12.2, z - 0.6), V(x + 0.6, 13, z + 0.6), P.iron, M.Metal)
			local lamp = decor(eq:box('RingLamp', V(x - 0.45, 12.1, z - 0.45), V(x + 0.45, 12.2, z + 0.45), C(255, 250, 230), M.Neon))
			light(lamp, C(255, 244, 220), 1.2, 18)
		end
	end
	local sign = ring:box('Sign', V(T + w, 9.4, -6), V(T + w + 0.3, 13.9, 6), P.black, M.SmoothPlastic)
	local g = surface(sign, Enum.NormalId.Right)
	line(g, 'Title', 'CHAMP RING x' .. station.Multiplier, P.magenta, FONT.loud, 0.05, 0.56, P.black, 2)
	line(g, 'Detail', compact(station.Required) .. ' POWER', P.white, FONT.body, 0.64, 0.3)
	return ring
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
-- Subway stairs down into the floor (the cells are left open in the floor plan) to the World 2 portal.
local function buildSubway(ctx)
	local w = ctx:group('World2Subway')
	-- Opening: x 40..52, z 68..80, stairs descend toward +Z.
	local x0, x1, z0, z1, depth = 40, 52, 68, 80, 6.4
	for k = 1, 8 do
		local top = -k * 0.8
		w:box('Stair', V(x0, -depth - 1, z0 + (k - 1) * 1.2), V(x1, top, z0 + k * 1.2), C(200, 202, 208), M.Concrete)
		w:box('StairNosing', V(x0, top, z0 + (k - 1) * 1.2), V(x1, top + 0.06, z0 + (k - 1) * 1.2 + 0.3), P.yellow, M.SmoothPlastic)
	end
	w:box('Landing', V(x0, -depth - 1, z0 + 9.6), V(x1, -depth, z1), C(200, 202, 208), M.Concrete)
	-- Shaft walls under the floor edges, white subway tile.
	w:box('ShaftWall', V(x0 - 4, -depth - 1, z0), V(x0, -1, z1 + 4), C(236, 240, 238), M.SmoothPlastic)
	w:box('ShaftWall', V(x1, -depth - 1, z0), V(x1 + 4, -1, z1 + 4), C(236, 240, 238), M.SmoothPlastic)
	w:box('ShaftWall', V(x0, -depth - 1, z1), V(x1, -1, z1 + 4), C(236, 240, 238), M.SmoothPlastic)
	w:box('TileStripe', V(x0, -3.4, z0), V(x0 + 0.05, -2.8, z1), P.subway, M.SmoothPlastic)
	w:box('TileStripe', V(x1 - 0.05, -3.4, z0), V(x1, -2.8, z1), P.subway, M.SmoothPlastic)
	-- Portal at the bottom.
	w:box('PortalFrame', V(x0 + 1, -depth, z1 - 0.6), V(x1 - 1, -0.4, z1), P.subway, M.SmoothPlastic)
	local portal = decor(w:box('Portal', V(x0 + 2, -depth, z1 - 0.7), V(x1 - 2, -1.4, z1 - 0.6), C(90, 200, 255), M.Neon))
	portal.Transparency = 0.25
	light(portal, C(120, 210, 255), 2, 16)
	local pg = surface(portal, Enum.NormalId.Front)
	line(pg, 'Title', 'WORLD 2', P.white, FONT.loud, 0.2, 0.4, P.navy, 3)
	line(pg, 'Detail', 'UPTOWN TRAIN', P.white, FONT.body, 0.62, 0.2, P.navy, 2)
	-- Railings around three sides, globe lamps and the station sign at the mouth.
	for _, seg in { { V(x0 - 0.4, 0, z0), V(x0 - 0.4, 0, z1 + 0.4) }, { V(x1 + 0.4, 0, z0), V(x1 + 0.4, 0, z1 + 0.4) }, { V(x0 - 0.4, 0, z1 + 0.4), V(x1 + 0.4, 0, z1 + 0.4) } } do
		local a, b = seg[1], seg[2]
		local n = math.floor((b - a).Magnitude / 2.4)
		for k = 0, n do w:box('Railing', a + (b - a) * k / n + V(-0.1, 0, -0.1), a + (b - a) * k / n + V(0.1, 3.4, 0.1), P.subway, M.Metal) end
		w:part('RailTop', V(0.24, 0.24, (b - a).Magnitude + 0.2), CFrame.lookAt((a + b) / 2 + V(0, 3.5, 0), b + V(0, 3.5, 0)), P.subway, M.Metal)
	end
	for _, x in { x0 - 0.4, x1 + 0.4 } do
		w:post('GlobePost', 0.2, 6, V(x, 0, z0), P.subway)
		local globe = decor(w:blob('Globe', V(1.2, 1.2, 1.2), V(x, 6.6, z0), C(110, 230, 140), M.Neon))
		light(globe, C(120, 240, 150), 1, 14)
	end
	local sign = w:box('StationSign', V(x0 + 1, 7.2, z0 - 0.3), V(x1 - 1, 9.2, z0), P.subway, M.SmoothPlastic)
	local g = surface(sign, Enum.NormalId.Front)
	line(g, 'Title', 'UPTOWN TRAIN • WORLD 2', P.white, FONT.title, 0.1, 0.8)
	w:box('SignBar', V(x0 - 0.4, 9.2, z0 - 0.2), V(x1 + 0.4, 9.5, z0 + 0.1), P.iron, M.Metal)
	for _, x in { x0 - 0.4, x1 + 0.4 } do w:box('SignPost', V(x - 0.15, 6.9, z0 - 0.15), V(x + 0.15, 9.2, z0 + 0.15), P.iron, M.Metal) end
	return w
end
local function buildBoards(ctx)
	local b = ctx:group('Leaderboards')
	local defs = { { 'TOP POWER', P.yellow, 62 }, { 'TOP WINS', C(140, 230, 90), 76 }, { 'TOP REBIRTHS', P.magenta, 90 } }
	for _, d in defs do
		local z = d[3]
		for _, dz in { -5.4, 5.4 } do b:box('BoardLeg', V(59.2, 0, z + dz - 0.4), V(60, 14, z + dz + 0.4), P.iron, M.Metal) end
		local screen = b:box('Board', V(58.8, 2, z - 5), V(59.2, 12, z + 5), C(24, 30, 52), M.SmoothPlastic)
		local g = surface(screen, Enum.NormalId.Left)
		local rows = {}
		for k = 1, 8 do table.insert(rows, '#' .. k .. '   — — —') end
		local t = line(g, 'TextLabel', table.concat(rows, '\n'), P.white, FONT.body, 0.04, 0.92)
		t.TextXAlignment = Enum.TextXAlignment.Left
		local header = b:box('Header', V(58.6, 12, z - 5.4), V(59.2, 14.2, z + 5.4), d[2], M.SmoothPlastic)
		local hg = surface(header, Enum.NormalId.Left)
		line(hg, 'Title', d[1], P.black, FONT.loud, 0.1, 0.8)
	end
	return b
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

---------------------------------------------------------------------------------------------- stages
local function stageProps(ctx, i, z)
	local p = ctx:group('Stage' .. i .. 'Props')
	local zs = z + 7
	if i == 1 then
		for k, b in { { -16, 0 }, { -16, 2.4 }, { -13.4, 0 }, { 15.4, 0 } } do
			p:box('MovingBox', V(b[1] - 1.2, b[2], zs - 1.2 + k * 0.1), V(b[1] + 1.2, b[2] + 2.4, zs + 1.2 + k * 0.1), P.cardboard, M.Cardboard)
		end
	elseif i == 2 then
		chainFence(p, V(-13, 0, zs - 4), V(-13, 0, zs + 4), 6)
		chainFence(p, V(13, 0, zs - 4), V(13, 0, zs + 4), 6)
	elseif i == 3 then
		local van = p:at(CFrame.new(-16, 0, zs)):group('DeliveryVan')
		van:box('Body', V(-3, 1.2, -6), V(3, 8, 5), P.white, M.Metal)
		van:box('Cab', V(-3, 1.2, -8.6), V(3, 5.8, -6), P.white, M.Metal)
		van:box('Windshield', V(-2.6, 4, -8.7), V(2.6, 5.6, -8.6), P.glass, M.Glass)
		van:box('Stripe', V(3, 4, -6), V(3.05, 5, 5), P.red, M.SmoothPlastic)
		for _, zz in { -6.6, 3 } do for _, x in { -3.05, 3.05 } do van:rod('Wheel', 1.2, 0.8, CFrame.new(x, 1.2, zz), C(30, 30, 32), M.Rubber) end end
	elseif i == 4 then
		hydrant(p, V(15, 0, zs))
		-- An arc of water from the open nozzle to a puddle on the road.
		local function at(t) return V(14.15 - 6.6 * t, 1.25 * (1 - t) + 8 * t * (1 - t), zs) end
		for k = 0, 9 do
			local spray = decor(p:bar('Spray', at(k / 10), at((k + 1) / 10), 0.42 - k * 0.015, C(150, 220, 255), M.Glass))
			spray.Transparency = 0.35
			spray.CastShadow = false
		end
		local puddle = decor(p:part('Puddle', V(0.04, 3.4, 3.4), CFrame.new(7.55, 0.02, zs) * CFrame.Angles(0, 0, math.pi / 2), C(120, 190, 240), M.Glass, Enum.PartType.Cylinder))
		puddle.Transparency = 0.45
	elseif i == 5 then
		for _, x in { -16, -13, 13, 16 } do
			p:post('Barrel', 1.1, 2.8, V(x, 0, zs), P.orange, M.SmoothPlastic)
			p:post('BarrelBand', 1.13, 0.4, V(x, 1.6, zs), P.white, M.SmoothPlastic)
		end
	elseif i == 6 then
		for _, x in { -19.1, -14.4 } do for _, zz in { zs - 5, zs + 5 } do p:box('ScaffoldPost', V(x - 0.2, 0, zz - 0.2), V(x + 0.2, 10.3, zz + 0.2), P.steel, M.Metal) end end
		for _, y in { 5, 10 } do p:box('ScaffoldDeck', V(-19.3, y, zs - 4.8), V(-14.2, y + 0.3, zs + 4.8), P.wood, M.WoodPlanks) end
		for _, zz in { zs - 5, zs + 5 } do p:bar('ScaffoldBrace', V(-18.9, 0.4, zz), V(-14.6, 4.9, zz), 0.16, P.steel) end
		p:box('ToeBoard', V(-14.6, 10.3, zs - 4.8), V(-14.2, 11.3, zs + 4.8), P.orange, M.SmoothPlastic)
	elseif i == 7 then
		local cart = p:at(CFrame.new(15.5, 0, zs)):group('FoodCart')
		cart:box('Cart', V(-1.8, 1.2, -2.6), V(1.8, 3.6, 2.6), C(210, 214, 220), M.Metal)
		for _, zz in { -1.8, 1.8 } do cart:rod('Wheel', 1, 0.3, CFrame.new(-1.95, 1, zz), P.iron, M.Rubber) end
		cart:post('UmbrellaPole', 0.12, 4.4, V(0, 3.6, 0), P.iron)
		cart:box('Umbrella', V(-2.6, 8, -2.6), V(2.6, 8.3, 2.6), P.yellow, M.Fabric)
	elseif i == 8 then
		for _, x in { -16.5, 16.5 } do
			p:box('Speaker', V(x - 1.2, 0, zs - 1.2), V(x + 1.2, 5, zs + 1.2), P.black, M.SmoothPlastic)
			p:rod('Cone', 0.8, 0.1, CFrame.new(x, 3.4, zs - 1.25) * CFrame.Angles(0, math.pi / 2, 0), C(70, 70, 76), M.SmoothPlastic)
		end
	elseif i == 9 then
		for k = 1, 7 do
			local x, zz = (k % 2 == 0 and -1 or 1) * (6 + k), zs + (k % 3) * 1.5
			local b = p:at(CFrame.new(x, 0, zz) * CFrame.Angles(0, k, 0)):group('Pigeon')
			decor(b:blob('Body', V(0.7, 0.7, 1.1), V(0, 0.5, 0), C(150, 160, 176), M.SmoothPlastic))
			decor(b:blob('Head', V(0.4, 0.4, 0.4), V(0, 0.95, -0.45), C(110, 122, 140), M.SmoothPlastic))
		end
	else
		for _, x in { -6, 0, 6 } do
			p:box('Turnstile', V(x - 1, 0, zs - 1.5), V(x + 1, 3.4, zs + 1.5), C(150, 160, 160), M.Metal)
			p:bar('TurnstileArm', V(x + 1, 2.8, zs), V(x + 3.6, 2.8, zs), 0.16, P.steel)
		end
	end
	return p
end
local function buildStages(ctx, maps)
	local stages = ctx:group('Stages')
	local walls = maps.ById.Block.Walls
	for i, w in walls do
		local z = stageZ(i)
		local s = stages:group('Stage' .. i)
		-- Opaque white frame: posts on the terrace faces, a top beam across the full width.
		for _, side in { -1, 1 } do
			studs(s:box('GatePost', V(side * 18.4, 0, z - 0.8), V(side * 20, 12, z + 0.8), P.white, M.Plastic), true)
		end
		studs(s:box('GateBeam', V(-20, 12, z - 0.8), V(20, 13.6, z + 0.8), P.white, M.Plastic), true)
		-- The wall itself: white and see-through, with the stage text on both faces.
		local wall = s:box('StageWall', V(-18.4, 0, z - 0.25), V(18.4, 12, z + 0.25), C(245, 248, 255), M.SmoothPlastic)
		wall.Transparency = 0.65
		wall.CanCollide = false
		wall:SetAttribute('WallIndex', i)
		wall:SetAttribute('RequiredPower', w.RequiredRep)
		for _, face in { Enum.NormalId.Back, Enum.NormalId.Front } do
			local g = surface(wall, face, 30)
			pcall(function() g.MaxDistance = 32 end) -- only the wall ahead shows its text, not the ones behind it
			line(g, 'Stage', 'STAGE ' .. i, P.navy, FONT.title, 0.12, 0.3, P.white, 4)
			line(g, 'Name', string.upper(w.Name), P.navy, FONT.body, 0.44, 0.14, P.white, 3)
			line(g, 'Power', 'RECOMMENDED POWER: ' .. compact(w.RequiredRep), P.magenta, FONT.title, 0.62, 0.16, P.white, 3)
		end
		stageProps(s, i, z)
	end
	return stages
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
local function roadPaint(ctx)
	local r = ctx:group('RoadPaint')
	for z = -296, 80, 8 do
		local near = false
		for i = 1, 10 do if math.abs(z + 2 - stageZ(i)) < 3 then near = true end end
		if not near and not (z >= 44 and z <= 56) then r:box('CentreDash', V(-0.2, 0, z), V(0.2, 0.04, z + 4), P.roadLine, M.SmoothPlastic) end
	end
	for x = -10.5, 10.5, 3 do r:box('Crosswalk', V(x - 0.8, 0, 48.5), V(x + 0.8, 0.04, 55.5), P.paint, M.SmoothPlastic) end
	return r
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
	root:SetAttribute('BuildVersion', 'V2 lobby 1')
	local ctx = newCtx(root, CFrame.new())

	local floors = planFloors()
	local tier = planTerraces(floors)
	buildGround(ctx, floors)
	buildTerraces(ctx, tier)
	local reserved = {
		{ alongX = true, at = 104, a = -58, b = -38 }, { alongX = true, at = 104, a = -22, b = 22 }, { alongX = true, at = 104, a = 38, b = 58 },
		{ alongX = true, at = 0, a = 18, b = 22 }, { alongX = true, at = 0, a = -22, b = -18 },
		-- The Drip Shop building stands against these two walls.
		{ alongX = true, at = 0, a = 22, b = 64 }, { alongX = false, at = 64, a = 0, b = 22 },
	}
	for i = 1, 10 do
		for _, x in { -20, 20 } do table.insert(reserved, { alongX = false, at = x, a = stageZ(i) - 2, b = stageZ(i) + 2 }) end
	end
	for _, x in { -20, 20 } do table.insert(reserved, { alongX = false, at = x, a = -2.5, b = 2.5 }) end
	local faces = terraceFaces(floors, tier)
	decorateFaces(ctx, faces, reserved)
	buildLips(ctx, faces, reserved)

	-- Storefronts and the welcome mural on the back wall (z = 104 face, looking toward -Z).
	local back = function(x) return ctx:at(CFrame.lookAt(V(x, 0, 104), V(x, 0, 103))) end
	storefront(back(-48), 'Bodega', 'SUNNY SIDE BODEGA', C(46, 140, 90), P.white)
	storefront(back(48), 'Barbershop', 'UPTOWN CUTS', P.blue, P.white)
	local barberPole = ctx:group('BarberPole')
	barberPole:post('Pole', 0.4, 3.2, V(57.2, 2.4, 103.5), P.white, M.SmoothPlastic)
	for k = 0, 3 do barberPole:post('Stripe', 0.42, 0.4, V(57.2, 2.6 + k * 0.8, 103.5), k % 2 == 0 and P.red or P.blue, M.SmoothPlastic) end
	local mural = ghost(ctx:box('WelcomeMural', V(-20, 1, 103.95), V(20, 7.4, 104), P.white))
	local mg = surface(mural, Enum.NormalId.Front, 30)
	line(mg, 'Tag', 'WELCOME TO THE BLOCK', P.yellow, FONT.tag, 0.05, 0.9, C(40, 30, 80), 4)

	-- Spawn plaza.
	local plaza = ctx:group('SpawnPlaza')
	local function disc(name, d, y0, y1, color, material)
		return plaza:part(name, V(y1 - y0, d, d), CFrame.new(0, (y0 + y1) / 2, 92) * CFrame.Angles(0, 0, math.pi / 2), color, material or M.SmoothPlastic, Enum.PartType.Cylinder)
	end
	disc('Medallion', 15, 0, 0.1, P.trim, M.Concrete)
	disc('MedallionRing', 12, 0.1, 0.16, P.yellow)
	disc('MedallionCentre', 10, 0.16, 0.2, P.navy)
	local spawn = Instance.new('SpawnLocation')
	spawn.Name = 'Spawn'
	spawn.Anchored = true
	spawn.Enabled = false
	spawn.Neutral = true
	spawn.Size = V(6, 0.2, 6)
	spawn.CFrame = V2.Origin * CFrame.new(0, 0.3, 92)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = plaza.parent
	-- Glowing chevrons from the spawn, down the sidewalk and along the cross path to the Drip Stand.
	local arrows = plaza:group('TutorialArrows')
	local route = { V(16.5, 0, 86), V(16.5, 0, 52), V(40, 0, 52), V(42, 0, 46.5) }
	local spacing, carry = 4.5, 0
	for k = 1, #route - 1 do
		local a, b = route[k], route[k + 1]
		local len = (b - a).Magnitude
		local t = carry
		while t <= len do
			local p = a:Lerp(b, t / len)
			local arrow = arrows:at(CFrame.lookAt(p, p + (b - a)))
			for _, side in { -1, 1 } do
				local tip, tail = V(0, 0.06, -1.1), V(side * 1.25, 0.06, 0.25)
				decor(arrow:part('Chevron', V(0.55, 0.12, (tail - tip).Magnitude + 0.3), CFrame.lookAt((tip + tail) / 2, tail), P.yellow, M.Neon)).CastShadow = false
			end
			t += spacing
		end
		carry = t - len
	end

	-- The Drip Stand's shop building fills its lot back to the terrace walls (x 24..64, z 0..21 in map terms).
	buildDripStand(ctx:at(CFrame.new(42, 0, 42) * CFrame.Angles(0, math.pi, 0)), skins, art, { x0 = -22, x1 = 18, z1 = 42 })
	buildBoxingClub(ctx, skins.Stations)
	local ringStation = skins.Stations[9]
	Props.ring(ctx:at(CFrame.new(-40, 0, 76)):group('Training_' .. ringStation.Id), PROPS_KIT, ringStation, 9)
	buildCrewStand(ctx:at(CFrame.lookAt(V(-35, 0, 97), V(-34, 0, 97))), crew)
	buildStash(ctx:at(CFrame.lookAt(V(20.5, 0, 92), V(10, 0, 92))))
	buildSubway(ctx)
	buildBoards(ctx)
	buildStatue(ctx:at(CFrame.new(30, 0, 70)), skins.ById.Kingpin, art)
	buildStages(ctx, maps)

	-- Gate into the stages.
	local gate = ctx:group('StagesGate')
	for _, side in { -1, 1 } do studs(gate:box('Pier', V(side * 18, 0, -1.6), V(side * 20, 16, 0), C(150, 82, 62), M.Plastic), true) end
	local gs = gate:box('GateSign', V(-18, 12.4, -1.4), V(18, 16, -0.2), P.black, M.SmoothPlastic)
	local gg = surface(gs, Enum.NormalId.Back)
	line(gg, 'Title', 'THE STAGES', P.yellow, FONT.loud, 0.06, 0.6, C(120, 40, 20), 3)
	line(gg, 'Detail', 'BREAK THE WALLS • LEAVE THE BLOCK', P.white, FONT.body, 0.7, 0.24)
	gate:box('GateCap', V(-20, 16, -1.8), V(20, 16.7, 0.2), P.trim, M.SmoothPlastic)

	-- End of the line: the Uptown station entrance.
	local fin = ctx:group('StationEnd')
	fin:box('StationFront', V(-20, 0, -300), V(20, 2, -296), C(200, 202, 208), M.Concrete)
	local st = fin:box('StationSign', V(-14, 8, -296.3), V(14, 12, -296), P.subway, M.SmoothPlastic)
	local sg = surface(st, Enum.NormalId.Back)
	line(sg, 'Title', 'JUNIPER STATION', P.white, FONT.title, 0.08, 0.55)
	line(sg, 'Detail', 'NEXT: THE SUBURBS • WORLD 2', P.white, FONT.body, 0.68, 0.24)
	for _, x in { -14.3, 14.3 } do fin:box('SignPost', V(x - 0.3, 2, -296.6), V(x + 0.3, 12.6, -296), P.iron, M.Metal) end

	-- Street life.
	local life = ctx:group('StreetLife')
	for z = 8, 80, 24 do
		lamp(life, V(-18.6, 0, z), V(1, 0, 0))
		lamp(life, V(18.6, 0, z), V(-1, 0, 0))
	end
	for i = 1, 10 do
		local z = stageZ(i) + 14
		lamp(life, V(-18.6, 0, z), V(1, 0, 0))
		lamp(life, V(18.6, 0, z), V(-1, 0, 0))
	end
	stringLights(life, V(-18.6, 11.6, 56), V(18.6, 11.6, 56), 2, true)
	stringLights(life, V(-18.6, 11.6, 32), V(18.6, 11.6, 32), 2, false)
	roadPaint(ctx)
	hydrant(life, V(13.2, 0, 76))
	trashCan(life, V(-14.5, 0, 66))
	trashCan(life, V(14.5, 0, 22))
	bench(life, V(-14.5, 0, 74), V(1, 0, 0))
	for k, c in { { 20.6, 101.6, P.blue }, { 22.4, 101.9, P.red } } do crate(life, CFrame.new(c[1], 0, c[2]) * CFrame.Angles(0, k * 0.3, 0), c[3]) end
	-- Lobby trees; the ones near walls or boards keep their branches out of them.
	for k, t in { { V(-60, 0, 60), 'z' }, { V(-58, 0, 98), 'none' }, { V(-22, 0, 60), 'z' }, { V(28, 0, 100), 'x' }, { V(60, 0, 100), 'none' }, { V(58.5, 0, 51), 'none' } } do
		tree(life, t[1], k * 13 + 5, 0.9, t[2])
	end
	for k, pos in { V(-30, 0, 2), V(-50, 0, 2), V(-62, 0, 47), V(62, 0, 47), V(22, 0, 62), V(22, 0, 82) } do bush(life, pos, k) end
	-- Rooftop life on the terraces, each set on the real roof height under its footprint.
	local roof = ctx:group('Rooftops')
	-- Each terrace step is 8 studs deep, so props sit on a step's centre line (lobby x = ±68/±76/±84,
	-- back z = 108/116/124, street x = ±24/±32/±40) with their arms running along it.
	local trees = {
		{ V(-68, 0, 30), 'z' }, { V(-68, 0, 80), 'z' }, { V(68, 0, 34), 'z' }, { V(68, 0, 84), 'z' }, { V(-40, 0, 108), 'x' }, { V(30, 0, 108), 'x' },
		{ V(-76, 0, 56), 'z' }, { V(76, 0, 60), 'z' }, { V(-4, 0, 116), 'x' },
		{ V(-24, 0, -60), 'z' }, { V(24, 0, -128), 'z' }, { V(-24, 0, -212), 'z' }, { V(24, 0, -270), 'z' },
		{ V(32, 0, -96), 'z' }, { V(-32, 0, -170), 'z' }, { V(32, 0, -240), 'z' },
	}
	for k, t in trees do
		local y = roofTop(tier, t[1].X, t[1].Z, 3.4)
		if y then tree(roof, t[1] + V(0, y, 0), 100 + k * 7, 0.95, t[2]) end
	end
	for _, pos in { V(-84, 0, 64), V(84, 0, 20), V(84, 0, 92), V(12, 0, 124), V(-40, 0, -100), V(40, 0, -200), V(-40, 0, -264), V(40, 0, -52), V(-84, 0, 16), V(-52, 0, 124) } do
		local y = roofTop(tier, pos.X, pos.Z, 2.6)
		if y then waterTower(roof, pos + V(0, y, 0)) end
	end
	for k, pos in { V(-76, 0, 96), V(76, 0, 30), V(-32, 0, -30), V(32, 0, -150), V(-32, 0, -280), V(-60, 0, 116), V(56, 0, 116) } do
		local y = roofTop(tier, pos.X, pos.Z, 1.4)
		if y then acUnit(roof:at(CFrame.new(pos + V(0, y, 0)) * CFrame.Angles(0, k * math.pi / 2, 0))) end
	end

	root.Parent = workspace
	local count = 0
	for _, d in root:GetDescendants() do if d:IsA('BasePart') then count += 1 end end
	game:GetService('ChangeHistoryService'):SetWaypoint('TheBlockV2 built')
	print(string.format('[TheBlockV2] Built %d parts at %s. Select TheBlockV2 in the Explorer and press F to fly there.', count, tostring(V2.Origin.Position)))
	return { parts = count }
end

return V2
