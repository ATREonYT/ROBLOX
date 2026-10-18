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
	the stands) and by the place build (tools/place/build_yours.luau saves the same boards and stands), so his own
	Rojo-synced place and the downloaded build agree. Only instance reads that Lune can do too (CFrame, Size, Name,
	GetDescendants); anything new is built with the `api` table passed in (Roblox's or Lune's datatypes).

	floors(root)          lobby floors: parts tagged HuzzLobby, else parts named Lobby, else the biggest flat part of
	                      each lobby copy in the StartingPoint folder (copies on top of each other count once), else
	                      the SpawnBaseplates (his older places).
	pads(root, floor)     the round pads at the front: the avatar stands go on them (one per Game Pass knife: the side
	                      with more pads is VIP, the other Dance Pack).
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
		if n == "HuzzLeaderboards" or n == "HuzzAvatarStands" or n == "HuzzStandAvatars" or n == "HuzzAuraFX" then return true end
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
	inside it, 4 to 9 studs across; copies on top of each other count once. The edge most of them sit by is the front:
	each stand faces away from it, into the plaza (nx, nz in the floor frame). The side with more pads is VIP (three
	knives), the other Dance Pack (two); Turn counts each pass's pads in order along the edge.
]]
function LobbyLayout.pickPads(hx: number, hz: number, top: number, rows: { any }): { any }
	local keep = {}
	for _, r in rows do
		if math.abs(r.x) <= hx + 2 and math.abs(r.z) <= hz + 2 and math.abs(r.top - top) <= 2.5
			and r.w >= 4 and r.w <= 9 and r.d >= 4 and r.d <= 9 then
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
		table.insert(out, { ref = r.ref, x = r.x, z = r.z, wx = r.wx, wz = r.wz, top = r.top, Pass = "VIP", Turn = i, nx = nx, nz = nz })
	end
	for i, r in dance do
		table.insert(out, { ref = r.ref, x = r.x, z = r.z, wx = r.wx, wz = r.wz, top = r.top, Pass = "DancePack", Turn = i, nx = nx, nz = nz })
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

-- The avatar stand spots: one on top of each pad, facing into the plaza. { at, Pass, Turn, pad }
function LobbyLayout.standSpots(api, root, floor): { any }
	local out = {}
	for _, p in LobbyLayout.pads(api, root, floor) do
		local inward = floor.CFrame:VectorToWorldSpace(api.Vector3.new(p.nx, 0, p.nz))
		local yaw = yawTo(0, 0, inward.X, inward.Z)
		local at = api.CFrame.new(p.wx, p.top + 0.2, p.wz) * api.CFrame.Angles(0, yaw, 0)
		table.insert(out, { at = at, Pass = p.Pass, Turn = p.Turn, pad = p.ref })
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

return LobbyLayout

