--!strict
-- The road network as a graph, for GPS routes along the streets (minimap + full map). Pure: no instances.
-- Input is the baked road data (ReplicatedStorage.MTL_RoadMap, from tools/BakeRoadMap.lua): every flat asphalt
-- rectangle of the map. Each rectangle is cut into cells (about 56 studs long, up to 64 wide); a cell is a node.
-- Neighbouring cells of one rectangle are linked, and cells of different rectangles are linked where they overlap
-- or touch at the same height (so an overpass never links to the street under it, but a ramp's slices do link).
--   local g = RoadGraph.build(data)            -- data = require(MTL_RoadMap)
--   local pts = RoadGraph.route(g, from, to)   -- { Vector3 } from -> along the roads -> to, or nil if no road path
--   RoadGraph.nearest(g, pos) -> node index?   RoadGraph.streetAt(g, pos) -> "NW 52 Ave" or ""
local RoadGraph = {}

local CELL_L = 56
local CELL_W = 64
local BUCKET = 64
local TOUCH = 3 -- studs of slack when deciding two cells touch
local MAX_DY = 5 -- height step allowed between linked cells

export type Rect = { x: number, z: number, y: number, ang: number, L: number, W: number, name: number }
export type Graph = {
	rects: { Rect },
	names: { string },
	nx: { number },
	nz: { number },
	ny: { number },
	nrect: { number },
	adj: { { number } },
	buckets: { [number]: { number } },
	comp: { number }, -- connected piece each node belongs to (lots, the raceway and airside are their own pieces)
	mainComp: number, -- the biggest piece: the street network
}

function RoadGraph.parse(s: string): { Rect }
	local out = {}
	for chunk in string.gmatch(s or "", "[^;]+") do
		local v = {}
		for num in string.gmatch(chunk, "%-?%d+") do
			table.insert(v, tonumber(num) :: number)
		end
		if #v >= 6 then
			table.insert(out, { x = v[1], z = v[2], y = v[3], ang = v[4], L = v[5], W = v[6], name = v[7] or 0 })
		end
	end
	return out
end

function RoadGraph.parseWater(s: string): { Rect }
	local out = {}
	for chunk in string.gmatch(s or "", "[^;]+") do
		local v = {}
		for num in string.gmatch(chunk, "%-?%d+") do
			table.insert(v, tonumber(num) :: number)
		end
		if #v >= 5 then
			table.insert(out, { x = v[1], z = v[2], y = 0, ang = v[3], L = v[4], W = v[5], name = 0 })
		end
	end
	return out
end

local function key(bx: number, bz: number): number
	return (bx + 2048) * 4096 + (bz + 2048)
end

-- cell geometry kept only while building
type Cell = { x: number, z: number, ux: number, uz: number, hl: number, hw: number, y: number, rect: number }

local function separated(a: Cell, b: Cell): boolean
	local dx, dz = b.x - a.x, b.z - a.z
	local axes = { { a.ux, a.uz }, { -a.uz, a.ux }, { b.ux, b.uz }, { -b.uz, b.ux } }
	for _, ax in axes do
		local px, pz = ax[1], ax[2]
		local d = math.abs(dx * px + dz * pz)
		local ra = a.hl * math.abs(a.ux * px + a.uz * pz) + a.hw * math.abs(-a.uz * px + a.ux * pz)
		local rb = b.hl * math.abs(b.ux * px + b.uz * pz) + b.hw * math.abs(-b.uz * px + b.ux * pz)
		if d > ra + rb + TOUCH then
			return true
		end
	end
	return false
end

-- yieldEvery: call task.wait() every N cells (client builds it in the background); nil = never yield
function RoadGraph.build(data: any, yieldEvery: number?): Graph
	local rects = RoadGraph.parse(data.Roads)
	local g: Graph = { rects = rects, names = data.Names or {}, nx = {}, nz = {}, ny = {}, nrect = {}, adj = {}, buckets = {}, comp = {}, mainComp = 0 }
	local cells: { Cell } = {}
	local cellBuckets: { [number]: { number } } = {}

	local function link(a: number, b: number)
		table.insert(g.adj[a], b)
		table.insert(g.adj[b], a)
	end

	for ri, r in rects do
		local a = math.rad(r.ang)
		local ux, uz = math.cos(a), math.sin(a)
		local vx, vz = -uz, ux
		local nL = math.max(1, math.ceil(r.L / CELL_L))
		local nW = math.max(1, math.ceil(r.W / CELL_W))
		local hl, hw = r.L / nL / 2, r.W / nW / 2
		for i = 1, nL do
			for j = 1, nW do
				local fl = ((i - 0.5) / nL - 0.5) * r.L
				local fw = ((j - 0.5) / nW - 0.5) * r.W
				local c: Cell = { x = r.x + ux * fl + vx * fw, z = r.z + uz * fl + vz * fw, ux = ux, uz = uz, hl = hl, hw = hw, y = r.y, rect = ri }
				table.insert(cells, c)
				local id = #cells
				g.nx[id], g.nz[id], g.ny[id], g.nrect[id], g.adj[id] = c.x, c.z, c.y, ri, {}
				-- inside the rectangle: link to the cell before along each axis
				if j > 1 then
					link(id, id - 1)
				end
				if i > 1 then
					link(id, id - nW)
				end
				-- buckets for the overlap test (cell box + slack) and for nearest-node lookups (centre)
				local ex = math.abs(ux) * hl + math.abs(vx) * hw + TOUCH
				local ez = math.abs(uz) * hl + math.abs(vz) * hw + TOUCH
				for bx = math.floor((c.x - ex) / BUCKET), math.floor((c.x + ex) / BUCKET) do
					for bz = math.floor((c.z - ez) / BUCKET), math.floor((c.z + ez) / BUCKET) do
						local k = key(bx, bz)
						local list = cellBuckets[k]
						if not list then
							list = {}
							cellBuckets[k] = list
						end
						table.insert(list, id)
					end
				end
				local k = key(math.floor(c.x / BUCKET), math.floor(c.z / BUCKET))
				local nb = g.buckets[k]
				if not nb then
					nb = {}
					g.buckets[k] = nb
				end
				table.insert(nb, id)
			end
		end
	end

	-- link touching cells of different rectangles
	local tested: { [number]: boolean } = {}
	local n = 0
	for _, list in cellBuckets do
		for i = 1, #list do
			local a = list[i]
			local ca = cells[a]
			for j = i + 1, #list do
				local b = list[j]
				local cb = cells[b]
				if ca.rect ~= cb.rect and math.abs(ca.y - cb.y) <= MAX_DY then
					local lo, hi = math.min(a, b), math.max(a, b)
					local pk = lo * 1048576 + hi
					if not tested[pk] then
						tested[pk] = true
						if not separated(ca, cb) then
							link(a, b)
						end
					end
				end
			end
		end
		n += 1
		if yieldEvery and n % yieldEvery == 0 then
			task.wait()
		end
	end

	-- connected pieces
	local sizes: { number } = {}
	for i = 1, #g.nx do
		if not g.comp[i] then
			local id = #sizes + 1
			local stack, size = { i }, 0
			g.comp[i] = id
			while #stack > 0 do
				local c = table.remove(stack) :: number
				size += 1
				for _, nb in g.adj[c] do
					if not g.comp[nb] then
						g.comp[nb] = id
						table.insert(stack, nb)
					end
				end
			end
			sizes[id] = size
			if g.mainComp == 0 or size > sizes[g.mainComp] then
				g.mainComp = id
			end
		end
	end
	return g
end

-- nearest node to a position (prefers nodes at the same height: on an overpass you route from the overpass)
-- comp: only nodes of that connected piece
function RoadGraph.nearest(g: Graph, pos: Vector3, maxDist: number?, comp: number?): number?
	local limit = maxDist or 600
	local bx0, bz0 = math.floor(pos.X / BUCKET), math.floor(pos.Z / BUCKET)
	local best, bestScore = nil, math.huge
	local ring = 0
	while ring * BUCKET <= limit + BUCKET do
		for bx = bx0 - ring, bx0 + ring do
			for bz = bz0 - ring, bz0 + ring do
				if math.max(math.abs(bx - bx0), math.abs(bz - bz0)) == ring then
					local list = g.buckets[key(bx, bz)]
					if list then
						for _, id in list do
							if comp and g.comp[id] ~= comp then
								continue
							end
							local dx, dz = g.nx[id] - pos.X, g.nz[id] - pos.Z
							local score = math.sqrt(dx * dx + dz * dz) + 3 * math.max(0, math.abs(g.ny[id] - pos.Y) - 4)
							if score < bestScore then
								best, bestScore = id, score
							end
						end
					end
				end
			end
		end
		-- anything found in this ring is closer than any node two rings out
		if best and bestScore < ring * BUCKET then
			break
		end
		ring += 1
	end
	if best and bestScore <= limit then
		return best
	end
	return nil
end

-- binary heap keyed by f
local function push(heap: { any }, item: { any })
	table.insert(heap, item)
	local i = #heap
	while i > 1 do
		local p = i // 2
		if heap[p][1] <= heap[i][1] then
			break
		end
		heap[p], heap[i] = heap[i], heap[p]
		i = p
	end
end

local function pop(heap: { any }): { any }?
	local n = #heap
	if n == 0 then
		return nil
	end
	local top = heap[1]
	heap[1] = heap[n]
	heap[n] = nil
	n -= 1
	local i = 1
	while true do
		local l, r, s = i * 2, i * 2 + 1, i
		if l <= n and heap[l][1] < heap[s][1] then
			s = l
		end
		if r <= n and heap[r][1] < heap[s][1] then
			s = r
		end
		if s == i then
			break
		end
		heap[s], heap[i] = heap[i], heap[s]
		i = s
	end
	return top
end

-- A* between two nodes; returns the node list or nil
function RoadGraph.path(g: Graph, a: number, b: number): { number }?
	if a == b then
		return { a }
	end
	local nx, nz, ny = g.nx, g.nz, g.ny
	local function h(i: number): number
		local dx, dz = nx[i] - nx[b], nz[i] - nz[b]
		return math.sqrt(dx * dx + dz * dz)
	end
	local gs: { [number]: number } = { [a] = 0 }
	local from: { [number]: number } = {}
	local closed: { [number]: boolean } = {}
	local heap = {}
	push(heap, { h(a), a })
	while true do
		local item = pop(heap)
		if not item then
			return nil
		end
		local cur = item[2]
		if cur == b then
			break
		end
		if not closed[cur] then
			closed[cur] = true
			local gc = gs[cur]
			for _, nb in g.adj[cur] do
				if not closed[nb] then
					local dx, dz, dy = nx[nb] - nx[cur], nz[nb] - nz[cur], ny[nb] - ny[cur]
					local ng = gc + math.sqrt(dx * dx + dz * dz + dy * dy)
					if ng < (gs[nb] or math.huge) then
						gs[nb] = ng
						from[nb] = cur
						push(heap, { ng + h(nb), nb })
					end
				end
			end
		end
	end
	local out = { b }
	local cur = b
	while from[cur] do
		cur = from[cur]
		table.insert(out, 1, cur)
	end
	return out
end

-- distance from point p to segment ab (x/z only)
local function segDist(p: Vector3, a: Vector3, b: Vector3): number
	local abx, abz = b.X - a.X, b.Z - a.Z
	local len2 = abx * abx + abz * abz
	local t = if len2 > 0 then math.clamp(((p.X - a.X) * abx + (p.Z - a.Z) * abz) / len2, 0, 1) else 0
	local dx, dz = a.X + abx * t - p.X, a.Z + abz * t - p.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- Douglas-Peucker: drops the zig-zag of cell centres, keeps the corners
function RoadGraph.simplify(points: { Vector3 }, tolerance: number): { Vector3 }
	if #points <= 2 then
		return points
	end
	local keep = { [1] = true, [#points] = true }
	local stack = { { 1, #points } }
	while #stack > 0 do
		local span = table.remove(stack) :: { number }
		local i0, i1 = span[1], span[2]
		local worst, wi = 0, 0
		for i = i0 + 1, i1 - 1 do
			local d = segDist(points[i], points[i0], points[i1])
			if d > worst then
				worst, wi = d, i
			end
		end
		if worst > tolerance then
			keep[wi] = true
			table.insert(stack, { i0, wi })
			table.insert(stack, { wi, i1 })
		end
	end
	local out = {}
	for i, p in points do
		if keep[i] then
			table.insert(out, p)
		end
	end
	return out
end

-- Route along the roads: from -> nearest road -> ... -> nearest road to the target -> to. nil when either end is
-- far from any road or the two roads aren't connected (callers then draw a straight line).
function RoadGraph.route(g: Graph, from: Vector3, to: Vector3): ({ Vector3 }?, number)
	local a = RoadGraph.nearest(g, from)
	local b = RoadGraph.nearest(g, to)
	if not a or not b then
		return nil, 0
	end
	if g.comp[a] ~= g.comp[b] then
		-- one end is on a piece that doesn't join the streets (a lot, the raceway): route on the street network to
		-- the closest point, the last stretch is drawn straight
		local a2 = if g.comp[a] == g.mainComp then a else RoadGraph.nearest(g, from, 900, g.mainComp)
		local b2 = if g.comp[b] == g.mainComp then b else RoadGraph.nearest(g, to, 2000, g.mainComp)
		if not a2 or not b2 then
			return nil, 0
		end
		a, b = a2, b2
	end
	local nodes = RoadGraph.path(g, a, b)
	if not nodes then
		return nil, 0
	end
	local pts = { from }
	for _, id in nodes do
		table.insert(pts, Vector3.new(g.nx[id], g.ny[id], g.nz[id]))
	end
	table.insert(pts, to)
	pts = RoadGraph.simplify(pts, 7)
	local len = 0
	for i = 2, #pts do
		len += (pts[i] - pts[i - 1]).Magnitude
	end
	return pts, len
end

-- the street name under (or nearest to) a position, "" off-road or on a nameless junction far from any street
function RoadGraph.streetAt(g: Graph, pos: Vector3): string
	local id = RoadGraph.nearest(g, pos, 40)
	if not id then
		return ""
	end
	local r = g.rects[g.nrect[id]]
	if r.name > 0 then
		return g.names[r.name] or ""
	end
	-- a junction: borrow the name of a linked street
	for _, nb in g.adj[id] do
		local rr = g.rects[g.nrect[nb]]
		if rr.name > 0 then
			return g.names[rr.name] or ""
		end
	end
	return ""
end

return RoadGraph
