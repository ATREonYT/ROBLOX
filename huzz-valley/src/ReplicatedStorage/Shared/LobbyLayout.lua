--[[
	Where the lobby is and where its leaderboards and avatar stands go (owner, Oct 18: "i made a new lobby for the
	game ... I made it the lobby for all of the maps, please add all of these leaderboards, all of the gamepass things
	to the new lobby").

	His new Halloween lobby lives in Workspace > StartingPoint: one copy in front of each map (Base, BasketBall,
	Halloween; two of them pasted twice on top of each other). Each copy: a square brown plaza (124 x 136 studs,
	top 12.5) with the red carpet and the fenced girl display, the haunted house and terraced hills behind it, three
	grey Podiums along one side, five small round grey pads at the front (three on one side, two on the other), a spin
	wheel on the other side. His old lobby islands (Maps > Spawn > SpawnBaseplate) still sit off to the side; they are
	no longer lobbies.

	Used by the server at game start (MapService: the lobby floors; LeaderboardService: the boards; AvatarStandService:
	the stands; LobbyPropService: the props on the pads) and by the place build (tools/place/build_yours.luau saves the same boards and stands), so his own
	Rojo-synced place and the downloaded build agree. Only instance reads that Lune can do too (CFrame, Size, Name,
	GetDescendants); anything new is built with the `api` table passed in (Roblox's or Lune's datatypes).

	floors(root)          lobby floors: parts tagged HuzzLobby, else parts named Lobby, else the biggest flat part of
	                      each lobby copy in the StartingPoint folder (copies on top of each other count once), else
	                      the SpawnBaseplates (his older places).
	pads(root, floor)     the round pads at the front (three on one side, two on the other).
	propSpots(...)        his five lobby props, one on each pad (Config/LobbyProps says which goes where).
	standSpots(...)       the avatar stands: a row of STANDS (3) along the side of the plaza opposite his podiums,
	                      facing into it, where nothing is in the way (owner, Oct 20 20:34: "make 3 characters be
	                      there, not 5": Hunter, Moonlit and Sunrise; the other knife passes stay in the Shop).
	boardSpots(...)       the leaderboards: his grey Podiums by the plaza first, then the lowest terrace step on each
	                      side behind the plaza (clear of the house in the middle), facing the plaza; else along the
	                      back edge of the floor.
]]
local LobbyLayout = {}

LobbyLayout.FOLDER = "StartingPoint" -- his new lobby's folder in Workspace
LobbyLayout.MIN_FLOOR_AREA = 8000 -- studs² (the plaza is 124 x 136 = 16,864; terraces are under 5,100)
LobbyLayout.CLUSTER = 150 -- floors closer than this are the same lobby copy (the copies are 550+ studs apart)

local function key(name: string): string
	return (string.gsub(name, "[%s_%-]", "")):lower()
end

local function hasTag(d, tag: string): boolean
	local ok, has = pcall(function() return d:HasTag(tag) end)
	return ok and has == true
end

-- Inside something we built (boards, stands, effects), so never part of his lobby.
local function ours(d): boolean
	local p = d.Parent
	while p do
		local n = p.Name
		if n == "HuzzLeaderboards" or n == "HuzzAvatarStands" or n == "HuzzStandAvatars" or n == "HuzzAuraFX" or n == "HuzzLobbyProps"
			or n == "HuzzSpawnPad" or n == "HuzzSpareLobbies" then return true end
		p = p.Parent
	end
	return false
end

-- A part's facts as plain numbers (world space; the footprint along its own axes).
local function facts(p)
	local cf, s = p.CFrame, p.Size
	local pos = cf.Position
	local up = cf.UpVector
	local ext = function(axis)
		return math.abs(cf.RightVector[axis]) * s.X / 2 + math.abs(cf.UpVector[axis]) * s.Y / 2 + math.abs(cf.LookVector[axis]) * s.Z / 2
	end
	return {
		ref = p, X = pos.X, Y = pos.Y, Z = pos.Z, SX = s.X, SY = s.Y, SZ = s.Z, flat = math.abs(up.Y) > 0.99,
		top = pos.Y + ext("Y"), bottom = pos.Y - ext("Y"), hx = ext("X"), hz = ext("Z"),
	}
end
LobbyLayout.facts = facts

--[[
	Pure: which of these big parts are lobby floors. `list` = facts() rows. Flat parts of at least MIN_FLOOR_AREA;
	exact copies on top of each other count once; within CLUSTER studs, the biggest wins (then the higher top: the
	plaza over the grey slab under it). Sorted by X, then Z, so every run picks the same order.
]]
function LobbyLayout.pickFloors(list: { any }): { any }
	local big = {}
	for _, f in list do
		if f.flat and f.SX * f.SZ >= LobbyLayout.MIN_FLOOR_AREA and f.SY <= 20 then table.insert(big, f) end
	end
	table.sort(big, function(a, b)
		local aa, ab = a.SX * a.SZ, b.SX * b.SZ
		if math.abs(aa - ab) > 1 then return aa > ab end
		if math.abs(a.top - b.top) > 0.01 then return a.top > b.top end
		if a.X ~= b.X then return a.X < b.X end
		return a.Z < b.Z
	end)
	local out = {}
	for _, f in big do
		local taken = false
		for _, o in out do
			local dx, dz = f.X - o.X, f.Z - o.Z
			if dx * dx + dz * dz < LobbyLayout.CLUSTER * LobbyLayout.CLUSTER then taken = true break end
		end
		if not taken then table.insert(out, f) end
	end
	table.sort(out, function(a, b)
		if math.abs(a.X - b.X) > 0.5 then return a.X < b.X end
		return a.Z < b.Z
	end)
	return out
end

-- The lobby floors under `root` (Workspace), best source first (see the header).
function LobbyLayout.floors(root): { BasePart }
	local tagged, named, bases, folders = {}, {}, {}, {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			if hasTag(d, "HuzzLobby") then table.insert(tagged, d)
			elseif key(d.Name) == "lobby" then table.insert(named, d)
			elseif key(d.Name) == "spawnbaseplate" then table.insert(bases, d) end
		elseif (d:IsA("Folder") or d:IsA("Model")) and key(d.Name) == key(LobbyLayout.FOLDER) then
			table.insert(folders, d)
		end
	end
	if #tagged > 0 then return tagged end
	if #named > 0 then return named end
	if #folders > 0 then
		local rows = {}
		for _, folder in folders do
			for _, d in folder:GetDescendants() do
				if d:IsA("BasePart") and not ours(d) and d.Size.X * d.Size.Z >= LobbyLayout.MIN_FLOOR_AREA then
					table.insert(rows, facts(d))
				end
			end
		end
		local out = {}
		for _, f in LobbyLayout.pickFloors(rows) do table.insert(out, f.ref) end
		if #out > 0 then return out end
	end
	return bases
end

-- Roblox's yaw (0 = facing -Z) that faces from one point towards another.
local BOARD_HEIGHT = 22 -- studs a board stands up off its step (slab 18 + lift), for the "nothing in the way" test

local function yawTo(fromX: number, fromZ: number, toX: number, toZ: number): number
	return math.atan2(-(toX - fromX), -(toZ - fromZ))
end
LobbyLayout.yawTo = yawTo

--[[
	Pure: the round stand pads. `hx, hz` = half the floor's size (its own frame), `top` = its top, `rows` = candidates
	{ ref, x, z (floor frame), wx, wz (world), top, w, d (footprint) }. Keeps pads lying on the floor (top within 2.5)
	inside it, 4 to 11 studs across (the Halloween stands' pads are 1.5x his 6.5 since Oct 20: LobbyPropBuild.grow); copies on top of each other count once. The edge most of them sit by is the front:
	each stand faces away from it, into the plaza (nx, nz in the floor frame). The side with more pads is VIP (three
	knives), the other Dance Pack (two); Turn counts each pass's pads in order along the edge.
]]
function LobbyLayout.pickPads(hx: number, hz: number, top: number, rows: { any }): { any }
	local keep = {}
	for _, r in rows do
		if math.abs(r.x) <= hx + 2 and math.abs(r.z) <= hz + 2 and math.abs(r.top - top) <= 2.5
			and r.w >= 4 and r.w <= 11 and r.d >= 4 and r.d <= 11 then -- (11: his 6.5 pads, and the Halloween stands' 1.5x)
			local dup = false
			for _, k in keep do
				if math.abs(k.x - r.x) < 1 and math.abs(k.z - r.z) < 1 then dup = true break end
			end
			if not dup then table.insert(keep, r) end
		end
	end
	if #keep == 0 then return {} end
	-- the front edge: the one most pads are nearest
	local votes = { nz = 0, pz = 0, nx = 0, px = 0 }
	for _, r in keep do
		local dist = { nz = hz + r.z, pz = hz - r.z, nx = hx + r.x, px = hx - r.x }
		local best, bestD = "nz", math.huge
		for _, k in { "nz", "pz", "nx", "px" } do
			if dist[k] < bestD then best, bestD = k, dist[k] end
		end
		votes[best] += 1
	end
	local edge, most = "nz", -1
	for _, k in { "nz", "pz", "nx", "px" } do
		if votes[k] > most then edge, most = k, votes[k] end
	end
	local nx, nz = 0, 0 -- inward: away from the front edge, into the plaza
	if edge == "nz" then nz = 1 elseif edge == "pz" then nz = -1 elseif edge == "nx" then nx = 1 else nx = -1 end
	local a, b = {}, {}
	for _, r in keep do
		r.along = if nz ~= 0 then r.x else r.z
		table.insert(if r.along < 0 then a else b, r)
	end
	local function byAlong(p, q) return p.along < q.along end
	table.sort(a, byAlong)
	table.sort(b, byAlong)
	local vip, dance = a, b
	if #b > #a then vip, dance = b, a end
	local out = {}
	for i, r in vip do
		table.insert(out, { ref = r.ref, x = r.x, z = r.z, wx = r.wx, wz = r.wz, top = r.top, Pass = "VIP", Turn = i, nx = nx, nz = nz, along = r.along })
	end
	for i, r in dance do
		table.insert(out, { ref = r.ref, x = r.x, z = r.z, wx = r.wx, wz = r.wz, top = r.top, Pass = "DancePack", Turn = i, nx = nx, nz = nz, along = r.along })
	end
	return out
end

-- The world box of a few parts: centre x/z, bottom, top, width x/z.
local function boxOf(parts: { BasePart })
	local lo, hi = math.huge, -math.huge
	local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
	for _, p in parts do
		local q = facts(p)
		lo, hi = math.min(lo, q.bottom), math.max(hi, q.top)
		x0, x1 = math.min(x0, q.X - q.hx), math.max(x1, q.X + q.hx)
		z0, z1 = math.min(z0, q.Z - q.hz), math.max(z1, q.Z + q.hz)
	end
	return (x0 + x1) / 2, (z0 + z1) / 2, lo, hi, x1 - x0, z1 - z0
end

-- The round pads on this floor (Models of one to four flat parts, at least one a cylinder), picked by pickPads.
function LobbyLayout.pads(api, root, floor): { any }
	local rows = {}
	for _, m in root:GetDescendants() do
		if m:IsA("Model") and not ours(m) then
			local parts, round = {}, false
			for _, c in m:GetDescendants() do
				if c:IsA("BasePart") then
					table.insert(parts, c)
					local ok, shape = pcall(function() return c.Shape end)
					if ok and tostring(shape) == "Enum.PartType.Cylinder" then round = true end
				end
			end
			if round and #parts <= 4 then
				local cx, cz, lo, hi, w, d = boxOf(parts)
				if hi - lo <= 1.5 then
					local r = floor.CFrame:PointToObjectSpace(api.Vector3.new(cx, hi, cz))
					table.insert(rows, { ref = m, x = r.X, z = r.Z, wx = cx, wz = cz, top = hi, w = w, d = d })
				end
			end
		end
	end
	return LobbyLayout.pickPads(floor.Size.X / 2, floor.Size.Z / 2, facts(floor).top, rows)
end

-- The top block of every "Podium" model under `root` (the highest one), copies on top of each other once.
local function podiums(root): { BasePart }
	local out = {}
	for _, d in root:GetDescendants() do
		if d:IsA("Model") and key(d.Name) == "podium" and not ours(d) then
			local best, bestTop = nil, -math.huge
			for _, p in d:GetDescendants() do
				if p:IsA("BasePart") then
					local t = facts(p).top
					if t > bestTop then best, bestTop = p, t end
				end
			end
			if best then
				local dup = false
				for _, o in out do
					if (o.CFrame.Position - best.CFrame.Position).Magnitude < 1 then dup = true break end
				end
				if not dup then table.insert(out, best) end
			end
		end
	end
	return out
end

--[[
	Pure: the props on the pads (owner, Oct 18: "implementing these objects into the lobby on top of the already placed
	circles"). `pads` = pickPads rows; `three` / `two` = the prop names for the side with more pads and the side with
	fewer, each from the pad nearest the middle of the plaza outwards. Returns { pad row, Prop, Rank }.
]]
function LobbyLayout.pickProps(pads: { any }, three: { string }, two: { string }): { any }
	local sides = { VIP = {}, DancePack = {} }
	for _, p in pads do
		if sides[p.Pass] then table.insert(sides[p.Pass], p) end
	end
	local out = {}
	for pass, names in { VIP = three, DancePack = two } do
		local list = sides[pass]
		table.sort(list, function(a, b) return math.abs(a.along or 0) < math.abs(b.along or 0) end)
		for i, p in list do
			if names[i] then table.insert(out, { pad = p, Prop = names[i], Rank = i }) end
		end
	end
	table.sort(out, function(a, b) return a.Prop < b.Prop end)
	return out
end

-- The props' spots on this floor: { at (CFrame on the pad's top, facing into the plaza), Prop, Rank, pad }.
function LobbyLayout.propSpots(api, root, floor, three: { string }, two: { string }): { any }
	local out = {}
	for _, s in LobbyLayout.pickProps(LobbyLayout.pads(api, root, floor), three, two) do
		local p = s.pad
		local inward = floor.CFrame:VectorToWorldSpace(api.Vector3.new(p.nx, 0, p.nz))
		local at = api.CFrame.new(p.wx, p.top, p.wz) * api.CFrame.Angles(0, yawTo(0, 0, inward.X, inward.Z), 0)
		table.insert(out, { at = at, Prop = s.Prop, Rank = s.Rank, pad = p.ref })
	end
	return out
end

local ROW = {
	R = 3.5, -- half the room one stand needs (its avatar, arms out), along and across
	LOW = 1, -- anything taller than this over the floor where a stand would stand is in the way (not the carpet or bones)
	TALL = 8, -- anything taller than this between a stand and the edge would be hidden behind it (the spin wheel, trees)
	FRONT = 20, -- studs from the front edge at least (and 12 behind the pads: clear of his props on them)
	BACK = 20,
	INSETS = { 9, 24 }, -- studs in from the side edge, tried from the edge inwards (every half stud)
	GAPS = { 13, 12, 11, 10, 9, 8 }, -- studs between stands (their signs are 9 wide), the widest that fits (3 stands
	-- since Oct 20 20:34: room for wider gaps, so the signs don't overlap seen from the plaza)
}
LobbyLayout.ROW = ROW
LobbyLayout.STANDS = 3 -- avatar stands in the row (owner, Oct 20 20:34: "make 3 characters be there, not 5")

--[[
	Pure: a row of `count` avatar stands along one side of the plaza, facing into it (owner, Oct 18: the stands came off
	the pads so his props could go there). `o` = { cx, cz (floor centre), top, ix, iz (inward: from the front edge to the
	back), sx, sz (towards the stands' side edge), across, depth (the floor's half sizes along those), front (optional:
	studs from the front edge where the row may start) }, `rows` =
	facts() of the parts round the lobby. Spots stand on the floor where nothing is in the way (a grave, a lantern)
	and nothing tall is hidden behind them (the spin wheel), from the front back; the line nearest the edge where all
	fit: an even row at the widest gap that has one, else the tightest row with holes. Returns { x, z, yaw, depth } front to back ({} when none fit).
]]
function LobbyLayout.pickRow(o, rows: { any }, count: number): { any }
	local function frame(x, z)
		local dx, dz = x - o.cx, z - o.cz
		return dx * o.ix + dz * o.iz + o.depth, o.across - (dx * o.sx + dz * o.sz)
	end
	local near = {}
	for _, r in rows do
		if r.top > o.top + ROW.LOW and r.bottom < o.top + 12 then
			local d, out = frame(r.X, r.Z)
			local ed = math.abs(o.ix) * r.hx + math.abs(o.iz) * r.hz
			local eo = math.abs(o.sx) * r.hx + math.abs(o.sz) * r.hz
			if ed < 40 and eo < 40 and out + eo > -2 and out - eo < 40 then
				table.insert(near, { d = d, out = out, ed = ed, eo = eo, tall = r.top > o.top + ROW.TALL })
			end
		end
	end
	local R = ROW.R
	local function clear(inset, d)
		for _, n in near do
			if math.abs(n.d - d) <= n.ed + R then
				if n.out + n.eo >= inset - R and n.out - n.eo <= inset + R then return false end
				if n.tall and n.out + n.eo >= -1 and n.out - n.eo <= inset then return false end
			end
		end
		return true
	end
	local yaw = yawTo(0, 0, -o.sx, -o.sz)
	local function place(list, inset)
		local out = {}
		for _, dd in list do
			local a, b = dd - o.depth, o.across - inset -- (inward and sideways from the centre)
			table.insert(out, { x = o.cx + o.ix * a + o.sx * b, z = o.cz + o.iz * a + o.sz * b, yaw = yaw, depth = dd, inset = inset })
		end
		return out
	end
	-- first an even row (the same gap between every two stands, nothing in the way at any of them), the widest gap,
	-- the line nearest the edge, the row nearest the front (Oct 20 20:34: three stands, spaced so their signs read)
	local back = 2 * o.depth - ROW.BACK
	for _, gap in ROW.GAPS do
		for inset = ROW.INSETS[1], ROW.INSETS[2], 0.5 do
			local d = o.front or ROW.FRONT
			while d + gap * (count - 1) <= back do
				local all = true
				for k = 0, count - 1 do
					if not clear(inset, d + gap * k) then all = false break end
				end
				if all then
					local list = {}
					for k = 0, count - 1 do table.insert(list, d + gap * k) end
					return place(list, inset)
				end
				d += 0.5
			end
		end
	end
	-- else the tightest row with holes where something's in the way
	for _, gap in ROW.GAPS do
		-- every line from the edge inwards; the tightest row wins (fewest holes where something's in the way), then the
		-- line nearest the edge
		local best, bestSpan, bestInset
		for inset = ROW.INSETS[1], ROW.INSETS[2], 0.5 do
			local got, last = {}, -math.huge
			local d = o.front or ROW.FRONT
			while d <= 2 * o.depth - ROW.BACK and #got < count do
				if d - last >= gap and clear(inset, d) then
					table.insert(got, d)
					last = d
				end
				d += 0.5
			end
			if #got >= count then
				local span = got[#got] - got[1]
				if not best or span < bestSpan - 0.5 then best, bestSpan, bestInset = got, span, inset end
			end
		end
		if best then return place(best, bestInset) end
	end
	return {}
end

--[[
	The avatar stand spots: a row of STANDS along the side of the plaza opposite his podiums (the boards are there),
	facing into the plaza (owner, Oct 20 20:34: "make 3 characters be there, not 5"). Each is listed as a VIP stand
	(VIP gives no knife now), so AvatarStandRules.assign hands them the first three knife passes in his card order:
	Hunter, Moonlit, Sunrise. { at, Pass, Turn }
]]
function LobbyLayout.standSpots(api, root, floor): { any }
	local pads = LobbyLayout.pads(api, root, floor)
	if #pads == 0 then return {} end
	local f = facts(floor)
	local centre = floor.CFrame.Position
	local inward = floor.CFrame:VectorToWorldSpace(api.Vector3.new(pads[1].nx, 0, pads[1].nz))
	local ix, iz = inward.X, inward.Z
	local rx, rz = -iz, ix -- (across the plaza)
	-- the boards' side: his podiums (else the side with more pads); the stands go on the other side
	local lean, vip = 0, 0
	for _, p in podiums(root) do
		local q = p.CFrame.Position
		if math.abs(q.X - centre.X) <= f.hx + 10 and math.abs(q.Z - centre.Z) <= f.hz + 10 then
			lean += (q.X - centre.X) * rx + (q.Z - centre.Z) * rz
		end
	end
	local counts = { VIP = 0, DancePack = 0 }
	for _, p in pads do
		counts[p.Pass] += 1
		if p.Pass == "VIP" then vip += (p.wx - centre.X) * rx + (p.wz - centre.Z) * rz end
	end
	if lean == 0 then lean = vip end
	local sx, sz = rx, rz
	if lean > 0 then sx, sz = -rx, -rz end
	local o = {
		cx = centre.X, cz = centre.Z, top = f.top, ix = ix, iz = iz, sx = sx, sz = sz,
		across = math.abs(sx) * f.hx + math.abs(sz) * f.hz, depth = math.abs(ix) * f.hx + math.abs(iz) * f.hz,
	}
	local rows = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and not d:IsA("Terrain") and d ~= floor and not ours(d) then
			local p = d.CFrame.Position
			if math.abs(p.X - centre.X) <= f.hx + 30 and math.abs(p.Z - centre.Z) <= f.hz + 30 then
				table.insert(rows, facts(d))
			end
		end
	end
	-- clear of the pads and the props on them: at least 12 studs behind the furthest pad from the front
	local front = ROW.FRONT
	for _, p in pads do
		front = math.max(front, (p.wx - centre.X) * ix + (p.wz - centre.Z) * iz + o.depth + 12)
	end
	o.front = front
	local count = math.min(counts.VIP + counts.DancePack, LobbyLayout.STANDS)
	local spots = LobbyLayout.pickRow(o, rows, count)
	if #spots < count then
		-- nothing fits: evenly along that side anyway, 10 in from the edge
		spots = {}
		for i = 1, count do
			local a, b = front + (i - 1) * 10 - o.depth, o.across - 10
			table.insert(spots, { x = o.cx + ix * a + sx * b, z = o.cz + iz * a + sz * b, yaw = yawTo(0, 0, -sx, -sz) })
		end
	end
	-- front to back; AvatarStandRules.assign hands out the knife passes in this order (Hunter, Moonlit, Sunrise)
	local out = {}
	for i, s in spots do
		local at = api.CFrame.new(s.x, f.top + 0.2, s.z) * api.CFrame.Angles(0, s.yaw, 0)
		table.insert(out, { at = at, Pass = "VIP", Turn = i })
	end
	return out
end

--[[
	The stand itself: an invisible flat part on top of the pad (named AvatarStand, so Gameplay/AvatarStands draws the
	viewer's copy standing on it, facing the way it faces), with its Pass and StandOn = Top. The caller sets Knife and
	the HuzzAvatarStand tag. He can drag it in Studio (Workspace > HuzzAvatarStands) or type another Pass / Knife.
]]
function LobbyLayout.standPart(api, spot)
	local p = api.Instance.new("Part")
	p.Name = "AvatarStand"
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.Transparency = 1
	p.Size = api.Vector3.new(5, 0.4, 5)
	p.CFrame = spot.at
	p:SetAttribute("Pass", spot.Pass)
	p:SetAttribute("StandOn", "Top")
	return p
end

--[[
	Pure: the terrace steps for boards. World numbers: the floor's centre (fx, fz) and top, its half extents (hx, hz),
	`ix, iz` = inward (from the front edge towards the back), `rows` = facts() of every part near the lobby. A step is
	a flat top 5 to 16 studs over the floor, at least 16 x 16, behind the floor's middle. The board stands on it as near
	the plaza as fits, facing the front like the stands (each screen then turns it towards you), and only where it
	stands clear: the step holds
	the whole slab, and nothing (a higher step, a tree's branches, a pumpkin) is inside the slab's height. The best one on each
	side (nearest the plaza), then the next best. Returns { x, z, top, yaw }.
]]
function LobbyLayout.pickSteps(fx: number, fz: number, ftop: number, hx: number, hz: number, ix: number, iz: number, rows: { any }, count: number): { any }
	local found = {}
	for _, c in rows do
		local up = c.top - ftop
		local behind = (c.X - fx) * ix + (c.Z - fz) * iz
		if c.flat and up >= 5 and up <= 16 and c.hx >= 8 and c.hz >= 8 and behind > 0
			and math.abs(c.X - fx) <= hx + 60 and math.abs(c.Z - fz) <= hz + 60 then
			-- what could be in the way: parts over this step, up to the board's height (and a little round it)
			local near = {}
			for _, r in rows do
				if math.abs(r.X - c.X) <= r.hx + c.hx + 2 and math.abs(r.Z - c.Z) <= r.hz + c.hz + 2
					and r.top > c.top - 1 and r.bottom < c.top + BOARD_HEIGHT then
					table.insert(near, r)
				end
			end
			-- every spot on the step (2 studs apart; 7 in from its ends along the slab, 2 from its front and back), the
			-- clear one nearest the plaza. The slab faces the front, so it fits a narrow ledge.
			local best, bestLen = nil, math.huge
			local wideX = math.abs(iz) >= math.abs(ix) -- (the slab's width runs along X)
			local ex, ez = if wideX then 7 else 2, if wideX then 2 else 7
			local x0, x1, z0, z1 = c.X - c.hx + ex, c.X + c.hx - ex, c.Z - c.hz + ez, c.Z + c.hz - ez
			local nx, nz = math.max(0, math.floor((x1 - x0) / 2)), math.max(0, math.floor((z1 - z0) / 2))
			for i = 0, nx do
				for j = 0, nz do
					local x = if nx == 0 then (x0 + x1) / 2 else x0 + i * (x1 - x0) / nx
					local z = if nz == 0 then (z0 + z1) / 2 else z0 + j * (z1 - z0) / nz
					local dx, dz = fx - x, fz - z
					local len = math.sqrt(dx * dx + dz * dz)
					if len > 1 and len < bestLen then
						local wx, wz = -iz, ix -- (along the board's width)
						local clear = true
						for k = -3, 3 do -- seven points across the 14-stud slab
							local px, pz = x + wx * 2 * k, z + wz * 2 * k
							local held = false
							for _, r in near do
								if math.abs(px - r.X) <= r.hx + 0.75 and math.abs(pz - r.Z) <= r.hz + 0.75 then
									if r.top > c.top + 0.6 then clear = false break end
								end
								if math.abs(px - r.X) <= r.hx and math.abs(pz - r.Z) <= r.hz and math.abs(r.top - c.top) <= 0.6 then held = true end
							end
							if not clear or not held then clear = false break end
						end
						if clear then best, bestLen = { x = x, z = z }, len end
					end
				end
			end
			if best then
				local side = (best.x - fx) * -iz + (best.z - fz) * ix
				table.insert(found, { x = best.x, z = best.z, top = c.top, yaw = yawTo(0, 0, -ix, -iz), side = if side < 0 then -1 else 1, score = bestLen })
			end
		end
	end
	table.sort(found, function(a, b)
		if math.abs(a.score - b.score) > 0.01 then return a.score < b.score end
		if a.x ~= b.x then return a.x < b.x end
		return a.z < b.z
	end)
	local out, used = {}, {}
	local function far(f)
		for _, o in out do
			if (f.x - o.x) ^ 2 + (f.z - o.z) ^ 2 < 16 * 16 then return false end
		end
		return true
	end
	for _, side in { -1, 1 } do -- the best on each side first
		for _, f in found do
			if #out < count and f.side == side and not used[f] and far(f) then
				table.insert(out, f)
				used[f] = true
				break
			end
		end
	end
	for _, f in found do
		if #out >= count then break end
		if not used[f] and far(f) then table.insert(out, f) used[f] = true end
	end
	table.sort(out, function(a, b) return a.side < b.side end)
	return out
end

--[[
	Where this floor's `count` boards go: { at (CFrame on the ground, facing the plaza), podium (stands on one of his
	grey Podiums: no base of its own) }. His Podiums by the floor first (lying on it: the one up by his billboard
	doesn't count), then terrace steps behind the plaza (only when the pads show which side is the front), then along
	the floor's back edge (rules.defaultSpots, Shared/LeaderboardRules).
]]
function LobbyLayout.boardSpots(api, rules, root, floor, count: number): { any }
	local CFrame = api.CFrame
	local f = facts(floor)
	local centre = floor.CFrame.Position
	local hx, hz = floor.Size.X / 2, floor.Size.Z / 2
	local out = {}
	local mine = {}
	for _, p in podiums(root) do
		local q = facts(p)
		local r = floor.CFrame:PointToObjectSpace(p.CFrame.Position)
		if math.abs(r.X) <= hx + 2 and math.abs(r.Z) <= hz + 2 and q.top - f.top >= 0 and q.top - f.top <= 6 then
			table.insert(mine, { part = p, z = r.Z, x = r.X })
		end
	end
	table.sort(mine, function(a, b)
		if math.abs(a.z - b.z) > 0.5 then return a.z < b.z end
		return a.x < b.x
	end)
	for _, m in mine do
		if #out >= count then break end
		local p = m.part
		local pc, pos = p.CFrame, p.CFrame.Position
		local long = if p.Size.Z >= p.Size.X then pc.LookVector else pc.RightVector
		local fx, fz = -long.Z, long.X -- (across the podium)
		if fx * (centre.X - pos.X) + fz * (centre.Z - pos.Z) < 0 then fx, fz = -fx, -fz end
		table.insert(out, { at = CFrame.new(pos.X, facts(p).top, pos.Z) * CFrame.Angles(0, yawTo(0, 0, fx, fz), 0), podium = true })
	end
	-- the front (from the pads): inward, in world space
	local pads = LobbyLayout.pads(api, root, floor)
	local inward
	if pads[1] then inward = floor.CFrame:VectorToWorldSpace(api.Vector3.new(pads[1].nx, 0, pads[1].nz)) end
	if #out < count and inward then
		local rows = {}
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") and not d:IsA("Terrain") and d ~= floor and not ours(d) then
				local p = d.CFrame.Position
				if math.abs(p.X - centre.X) <= f.hx + 90 and math.abs(p.Z - centre.Z) <= f.hz + 90 then
					local r = facts(d)
					-- only a plain block's top is a step to stand a board on (not a pumpkin, a mesh or a wedge)
					local ok, shape = pcall(function() return d.Shape end)
					r.flat = r.flat and d.ClassName == "Part" and ok and tostring(shape) == "Enum.PartType.Block"
					table.insert(rows, r)
				end
			end
		end
		for _, s in LobbyLayout.pickSteps(centre.X, centre.Z, f.top, f.hx, f.hz, inward.X, inward.Z, rows, count - #out) do
			table.insert(out, { at = CFrame.new(s.x, s.top, s.z) * CFrame.Angles(0, s.yaw, 0), podium = false })
		end
	end
	local rest = count - #out
	if rest > 0 then
		local frame, across, along
		if inward then
			-- local +Z = the back (CFrame.Angles(0, yaw): its back is (sin yaw, cos yaw))
			local yaw = math.atan2(inward.X, inward.Z)
			frame = CFrame.new(centre) * CFrame.Angles(0, yaw, 0)
			local right = frame.RightVector
			across = 2 * (math.abs(right.X) * f.hx + math.abs(right.Z) * f.hz)
			along = 2 * (math.abs(inward.X) * f.hx + math.abs(inward.Z) * f.hz)
		else
			local _, yaw = floor.CFrame:ToEulerAnglesYXZ()
			frame = CFrame.new(centre) * CFrame.Angles(0, yaw, 0)
			across, along = floor.Size.X, floor.Size.Z
		end
		local _, yaw = frame:ToEulerAnglesYXZ()
		local spots = rules.defaultSpots(across, along, rest)
		for i = 1, rest do
			local q = frame * api.Vector3.new(spots[i].X, 0, spots[i].Z)
			table.insert(out, { at = CFrame.new(q.X, f.top, q.Z) * CFrame.Angles(0, yaw, 0), podium = false })
		end
	end
	return out
end

--[[
	One lobby (owner, Oct 19: "make one lobby"). His lobby is pasted in front of each map; the game keeps ONE copy and
	puts the others away (ServerStorage > HuzzSpareLobbies, every piece as it was, so nothing of his is lost).
	main(root)            the copy kept: a floor with the attribute MainLobby = true if he marks one, else the copy
	                      with the fewest parts pasted twice on top of each other (his Base copy: the BasketBall and
	                      Halloween copies are doubled), then the first by position.
	spareItems(root, floors, main)
	                      what belongs to each other copy: every StartingPoint piece nearest it, plus loose pieces
	                      (in Workspace or a plain folder in it, e.g. his SpawnLocations in Maps > Spawn) whose middle
	                      lies inside the copy's area (COPY_AREA, in the plaza's own frame: the plaza, the house and
	                      hills behind it, the sides). Never a map, a player, something of ours or a huge part (Ocean).
	                      A piece he means for the lobby itself (KEEP: his Combine machine, Oct 20, or anything with
	                      the attribute HuzzKeep = true) isn't put away: it is listed in `keep` and moves into the
	                      kept lobby, to the same place beside it (his machine stood beside the copy at (-230, -692),
	                      so the game would otherwise have hidden it).
	putAwaySpares(api, root, storage)
	                      moves them to storage.HuzzSpareLobbies and the KEEP pieces into the kept lobby; returns the
	                      main floor, how many pieces moved away and how many came over.
	spawnPad(api, root, floor)
	                      where the lobby's spawn pad goes: open ground at the plaza's front, between his two groups of
	                      round pads (the red carpet in his lobby): { centre (Vector3 on the floor), inward (Vector3,
	                      into the plaza), across (Vector3) }. MapService checks it is really open (Shared/SpawnSpots).
]]
LobbyLayout.COPY_AREA = { x0 = -225, x1 = 75, z = 145 } -- studs, in the plaza's frame (his copies: x -207..57, z +-125)
LobbyLayout.SPARE_FOLDER = "HuzzSpareLobbies"
LobbyLayout.KEEP = { Combine = true } -- (Workspace children by name: his Combine machine, Config/Combine.Folder)

local function keeps(inst): boolean
	if LobbyLayout.KEEP[inst.Name] then return true end
	local ok, v = pcall(function() return inst:GetAttribute("HuzzKeep") end)
	return ok and v == true
end

-- The middle of a piece (its parts' average position), or nil when it has none.
local function middleOf(inst)
	if inst:IsA("BasePart") then
		local p = inst.CFrame.Position
		return { X = p.X, Y = p.Y, Z = p.Z }
	end
	local sx, sy, sz, n = 0, 0, 0, 0
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			local p = d.CFrame.Position
			sx, sy, sz, n = sx + p.X, sy + p.Y, sz + p.Z, n + 1
		end
	end
	if n == 0 then return nil end
	return { X = sx / n, Y = sy / n, Z = sz / n }
end

-- Parts pasted twice: same name, place and size as another part of the same copy.
local function doubled(parts: { BasePart }): number
	local seen, count = {}, 0
	for _, p in parts do
		local q, s = p.CFrame.Position, p.Size
		local k = string.format("%s|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f", p.Name, q.X, q.Y, q.Z, s.X, s.Y, s.Z)
		if seen[k] then count += 1 else seen[k] = true end
	end
	return count
end

local function nearestFloor(floors: { BasePart }, p): number
	local best, bestD = 1, math.huge
	for i, f in floors do
		local q = f.CFrame.Position
		local d = (p.X - q.X) ^ 2 + (p.Z - q.Z) ^ 2
		if d < bestD then best, bestD = i, d end
	end
	return best
end

local function startingPoints(root): { Instance }
	local out = {}
	for _, d in root:GetDescendants() do
		if (d:IsA("Folder") or d:IsA("Model")) and key(d.Name) == key(LobbyLayout.FOLDER) then table.insert(out, d) end
	end
	return out
end

function LobbyLayout.main(root): BasePart?
	local floors = LobbyLayout.floors(root)
	if #floors <= 1 then return floors[1] end
	for _, f in floors do
		if f:GetAttribute("MainLobby") == true then return f end
	end
	local partsOf = {}
	for i in floors do partsOf[i] = {} end
	for _, folder in startingPoints(root) do
		for _, d in folder:GetDescendants() do
			if d:IsA("BasePart") and not ours(d) then
				table.insert(partsOf[nearestFloor(floors, d.CFrame.Position)], d)
			end
		end
	end
	local best, bestCount = floors[1], math.huge
	for i, f in floors do
		local n = doubled(partsOf[i])
		if n < bestCount then best, bestCount = f, n end
	end
	return best
end

-- Inside this floor's copy area (its own frame)?
local function inCopy(floor: BasePart, p): boolean
	local cf = floor.CFrame
	local o = cf.Position
	local dx, dy, dz = p.X - o.X, p.Y - o.Y, p.Z - o.Z
	local r, k = cf.RightVector, cf.LookVector
	local l = { X = r.X * dx + r.Y * dy + r.Z * dz, Z = -(k.X * dx + k.Y * dy + k.Z * dz) }
	-- (measured with the plaza's front along its +X, as all his copies are built)
	local A = LobbyLayout.COPY_AREA
	return l.X >= A.x0 and l.X <= A.x1 and math.abs(l.Z) <= A.z
end

function LobbyLayout.spareItems(root, floors: { BasePart }, main: BasePart): { { floor: BasePart, items: { Instance }, keep: { Instance }? } }
	local out, byFloor = {}, {}
	for i, f in floors do
		if f ~= main then
			byFloor[i] = { floor = f, items = {} }
			table.insert(out, byFloor[i])
		end
	end
	if #out == 0 then return out end
	local mainIndex = table.find(floors, main)
	-- his copies' own folder: each piece goes with the plaza it's nearest
	local sps = startingPoints(root)
	for _, folder in sps do
		for _, c in folder:GetChildren() do
			local p = not ours(c) and middleOf(c)
			if p then
				local i = nearestFloor(floors, p)
				if i ~= mainIndex and byFloor[i] then table.insert(byFloor[i].items, c) end
			end
		end
	end
	-- loose pieces: Workspace's children and those of plain folders in it (not a map, not his copies' folder)
	local function isMap(inst)
		for _, d in inst:GetDescendants() do
			if key(d.Name) == "zonea" then return true end
		end
		return false
	end
	local function consider(inst)
		if table.find(sps, inst) or ours(inst) or string.sub(inst.Name, 1, 4) == "Huzz" then return end
		if keeps(inst) then -- (comes over to the kept lobby instead: putAwaySpares)
			local p = middleOf(inst)
			local i = p and nearestFloor(floors, p)
			if i and i ~= mainIndex and byFloor[i] and inCopy(floors[i], p) then
				byFloor[i].keep = byFloor[i].keep or {}
				table.insert(byFloor[i].keep, inst)
			end
			return
		end
		if inst:IsA("Terrain") or inst:IsA("Camera") or inst:IsA("Player") then return end
		if inst:IsA("Model") and inst:FindFirstChildOfClass("Humanoid") then return end
		if inst:IsA("BasePart") and math.max(inst.Size.X, inst.Size.Z) > 600 then return end -- (his Ocean)
		if not (inst:IsA("BasePart") or inst:IsA("Model")) then return end
		local p = middleOf(inst)
		if not p then return end
		local i = nearestFloor(floors, p)
		if i ~= mainIndex and byFloor[i] and inCopy(floors[i], p) and not isMap(inst) then
			table.insert(byFloor[i].items, inst)
		end
	end
	for _, c in root:GetChildren() do
		if c:IsA("Folder") then
			if not table.find(sps, c) and not isMap(c) or c.Name == "Maps" then
				for _, cc in c:GetChildren() do
					if cc:IsA("Folder") and not isMap(cc) then
						for _, ccc in cc:GetChildren() do consider(ccc) end
					else
						consider(cc)
					end
				end
			end
		else
			consider(c)
		end
	end
	return out
end

-- His pieces for the lobby itself (KEEP: the Combine machine) beside a spare copy move to the same place beside the
-- kept lobby (every part by the same shift and turn; the model's pivot too where Roblox has one). Safe to call more
-- than once (a moved piece is no longer by a spare copy): AvatarStandService calls it before it picks its row, so the
-- stands step round the machine whichever server script runs first. Returns how many it moved.
function LobbyLayout.bringKept(api, root): number
	local floors = LobbyLayout.floors(root)
	local main = LobbyLayout.main(root)
	if not main or #floors <= 1 then return 0 end
	local kept = 0
	for _, copy in LobbyLayout.spareItems(root, floors, main) do
		local shift = main.CFrame * copy.floor.CFrame:Inverse()
		for _, item in copy.keep or {} do
			local parts = if item:IsA("BasePart") then { item } else {}
			for _, d in item:GetDescendants() do
				if d:IsA("BasePart") then table.insert(parts, d) end
			end
			for _, part in parts do part.CFrame = shift * part.CFrame end
			local models = if item:IsA("Model") then { item } else {}
			for _, d in item:GetDescendants() do
				if d:IsA("Model") then table.insert(models, d) end
			end
			for _, m in models do pcall(function() m.WorldPivot = shift * m.WorldPivot end) end
			pcall(function() item:SetAttribute("HuzzMovedFrom", copy.floor.CFrame.Position) end)
			kept += 1
		end
	end
	return kept
end

function LobbyLayout.putAwaySpares(api, root, storage): (BasePart?, number, number)
	local floors = LobbyLayout.floors(root)
	local main = LobbyLayout.main(root)
	if not main or #floors <= 1 then return main, 0, 0 end
	local kept = LobbyLayout.bringKept(api, root)
	local holder = storage:FindFirstChild(LobbyLayout.SPARE_FOLDER) or api.Instance.new("Folder")
	holder.Name = LobbyLayout.SPARE_FOLDER
	holder.Parent = storage
	local moved = 0
	for _, copy in LobbyLayout.spareItems(root, floors, main) do
		local c = copy.floor.CFrame.Position
		local box = api.Instance.new("Folder")
		box.Name = string.format("Lobby copy at (%d, %d)", math.round(c.X), math.round(c.Z))
		box.Parent = holder
		for _, item in copy.items do
			pcall(function() item:SetAttribute("HuzzFrom", item.Parent and item.Parent:GetFullName() or "") end)
			item.Parent = box
			moved += 1
		end
	end
	return main, moved, kept
end

-- The plazas of the copies already put away (ServerStorage > HuzzSpareLobbies: the place build does it, so his
-- download opens with one lobby): MapService still measures where each map stood from the copy it was built beside.
function LobbyLayout.spareFloors(storage): { BasePart }
	local holder = storage and storage:FindFirstChild(LobbyLayout.SPARE_FOLDER)
	local out = {}
	for _, copy in (if holder then holder:GetChildren() else {}) do
		local rows = {}
		for _, d in copy:GetDescendants() do -- (only his parts are put away: nothing of ours is in there)
			if d:IsA("BasePart") and d.Size.X * d.Size.Z >= LobbyLayout.MIN_FLOOR_AREA then
				table.insert(rows, facts(d))
			end
		end
		for _, f in LobbyLayout.pickFloors(rows) do table.insert(out, f.ref) end
	end
	return out
end

function LobbyLayout.spawnPad(api, root, floor)
	local Vector3 = api.Vector3
	local f = facts(floor)
	local pads = LobbyLayout.pads(api, root, floor)
	local hx, hz = floor.Size.X / 2, floor.Size.Z / 2
	local nx, nz = 0, -1 -- (no pads: the floor's -Z side counts as the front)
	if pads[1] then nx, nz = pads[1].nx, pads[1].nz end
	-- between the two groups of pads along the front (his red carpet), else the front edge's middle
	local along = 0
	local lo, hi = -math.huge, math.huge
	for _, p in pads do
		if p.along < 0 then lo = math.max(lo, p.along) else hi = math.min(hi, p.along) end
	end
	if lo > -math.huge and hi < math.huge then along = (lo + hi) / 2 end
	local depth = (if nz ~= 0 then hz else hx) - 12 -- 12 studs in from the front edge
	local x = if nz ~= 0 then along else -nx * depth
	local z = if nz ~= 0 then -nz * depth else along
	local centre = floor.CFrame:PointToWorldSpace(Vector3.new(x, 0, z))
	local inward = floor.CFrame:VectorToWorldSpace(Vector3.new(nx, 0, nz))
	inward = Vector3.new(inward.X, 0, inward.Z).Unit
	return {
		centre = Vector3.new(centre.X, f.top, centre.Z),
		inward = inward,
		across = Vector3.new(-inward.Z, 0, inward.X),
	}
end

return LobbyLayout

