-- city_reach.luau (Oct 27 release fixes, World 2's play sanity): can a player walk everywhere they need to in World 2,
-- and can they never get stuck? A 2-stud grid over the hall and the whole track (gates open, as a run opens them): each
-- cell's floor is the highest solid top a foot can stand on, a body (1-5.5 over the floor) must fit, a step up is at
-- most a jump (6 studs), a step down any height. From the spawn: the Stage 1 gate, every stage's pads, the rooftop, the
-- portal home, the boards, the box dais, the ranges and the gun shop must be reachable; and from every cell you can
-- reach, the spawn must be reachable again ("stuck": a pit or a ledge you can't climb out of). (Oct 27 review) A body is
-- about 2 studs wide (a cell's body must fit R either side), a thin wall between two cells (a fence plank, a barrier)
-- blocks the step, and the grid runs out to the boundary walls (x +-124) and past the hall's south wall, so a strip
-- behind a fence or a house is looked at too.
-- Run (run_checks.sh does): lune run harness_unit.luau <src> - "$(cat city_reach.luau)"; prints "[reach] N checks / M failed".
-- (Oct 27 review) World 1 the same way: put REACH_MAP='TheBlockV2' before the script (run_checks.sh's block_reach; its
-- lines print "[reach1]").
local W1 = REACH_MAP == 'TheBlockV2'
local TAG = W1 and '[reach1]' or '[reach]'
if not W1 then workspace:SetAttribute('HoodWorld', 2) end
local V2 = require(game.ServerStorage[W1 and 'TheBlockV2' or 'TheCity'])
V2.Build()
local root = workspace:FindFirstChild(V2.Name)
local ActiveMap = require(game.ReplicatedStorage.Shared.ActiveMap)
local a = ActiveMap.get()
local frame = a and a.Frame or CFrame.new()
local n, failed = 0, {}
local function check(name, ok, detail)
	n += 1
	if not ok then table.insert(failed, name); print(TAG .. ' FAIL ' .. name .. (detail and (' (' .. detail .. ')') or '')) end
end

-- every solid part as an axis-aligned box in the map's frame, binned 8 studs
local B = 8
local bins = {}
local function key(i, j) return i * 100000 + j end
local gateBoxes = {} -- (round 5) each gate's barrier footprint, by its stage: the "no way round a shut gate" check
local function passable(p)
	-- a gate's barrier and fields open for the run; invisible walls stay (Bounds keep you in)
	local m = p:FindFirstAncestorWhichIsA('Model')
	while m and not m:HasTag('HoodStageGate') do m = m.Parent and m.Parent:FindFirstAncestorWhichIsA('Model') end
	if m and (p.Name == 'Barrier' or p.Name:sub(1, 5) == 'Field' or p.Name:sub(1, 4) == 'Lock') then
		local st = m:GetAttribute('Stage')
		if st and p.Name == 'Barrier' then
			local cf, h = frame:ToObjectSpace(p.CFrame), p.Size / 2
			local ex = math.abs(cf.RightVector.X) * h.X + math.abs(cf.UpVector.X) * h.Y + math.abs(cf.LookVector.X) * h.Z
			local ez = math.abs(cf.RightVector.Z) * h.X + math.abs(cf.UpVector.Z) * h.Y + math.abs(cf.LookVector.Z) * h.Z
			gateBoxes[st] = gateBoxes[st] or {}
			table.insert(gateBoxes[st], { cf.Position.X - ex, cf.Position.Z - ez, cf.Position.X + ex, cf.Position.Z + ez })
		end
		return true
	end
	return false
end
local count = 0
for _, p in root:GetDescendants() do
	if p:IsA('BasePart') and p.CanCollide and not passable(p) then
		local cf = frame:ToObjectSpace(p.CFrame)
		local h = p.Size / 2
		local rx, ry, rz = cf.RightVector, cf.UpVector, cf.LookVector
		local ex = math.abs(rx.X) * h.X + math.abs(ry.X) * h.Y + math.abs(rz.X) * h.Z
		local ey = math.abs(rx.Y) * h.X + math.abs(ry.Y) * h.Y + math.abs(rz.Y) * h.Z
		local ez = math.abs(rx.Z) * h.X + math.abs(ry.Z) * h.Y + math.abs(rz.Z) * h.Z
		local c = cf.Position
		local box = { c.X - ex, c.Y - ey, c.Z - ez, c.X + ex, c.Y + ey, c.Z + ez }
		if box[5] > -2 and box[2] < 60 then
			count += 1
			for i = math.floor(box[1] / B), math.floor(box[4] / B) do
				for j = math.floor(box[3] / B), math.floor(box[6] / B) do
					local k = key(i, j)
					bins[k] = bins[k] or {}
					table.insert(bins[k], box)
				end
			end
		end
	end
end

local S = 2
local X0, X1 = -130, 130
local Z0, Z1 = (V2.BossEnd or -1056) - 12, 132
local function floorAt(x, z)
	local top = nil
	for _, b in bins[key(math.floor(x / B), math.floor(z / B))] or {} do
		if x >= b[1] and x <= b[4] and z >= b[3] and z <= b[6] and b[5] <= 30 then
			if not top or b[5] > top then top = b[5] end
		end
	end
	return top
end
-- the floor a body standing there would rest on: the highest top at most a jump over `from`, then the body must fit
local R = 0.6 -- (half a body's width, a little under: only a gap a body can't fit through counts)
local function around(x, z)
	local out, seen = {}, {}
	for _, d in { { -R, -R }, { R, -R }, { -R, R }, { R, R } } do
		local k = key(math.floor((x + d[1]) / B), math.floor((z + d[2]) / B))
		if not seen[k] then seen[k] = true; table.insert(out, bins[k] or {}) end
	end
	return out
end
local cells = {}
local function cell(i, j)
	local k = key(i, j)
	local c = cells[k]
	if c ~= nil then return c end
	local x, z = X0 + i * S + S / 2, Z0 + j * S + S / 2
	local list = bins[key(math.floor(x / B), math.floor(z / B))] or {}
	local tops = {}
	for _, b in list do
		if x >= b[1] and x <= b[4] and z >= b[3] and z <= b[6] then table.insert(tops, b[5]) end
	end
	table.sort(tops)
	local best = false
	for _, t in tops do
		-- a body fits over t when no box covers (t + 0.3 .. t + 5.5) within R of here
		local clear = true
		for _, lb in around(x, z) do
			for _, b in lb do
				if x + R > b[1] and x - R < b[4] and z + R > b[3] and z - R < b[6] and b[2] < t + 5.5 and b[5] > t + 0.3 then clear = false break end
			end
			if not clear then break end
		end
		if clear then best = t break end -- the lowest standable top (ground under a roof stays ground)
	end
	cells[k] = best
	return best
end
local NI, NJ = math.floor((X1 - X0) / S), math.floor((Z1 - Z0) / S)
local function idx(x, z) return math.floor((x - X0) / S), math.floor((z - Z0) / S) end
-- a thin wall between two cell centres (a fence plank, a gate's barrier): the step is sampled every half stud at body height
local function wall(i, j, i2, j2, h)
	local xa, za = X0 + i * S + S / 2, Z0 + j * S + S / 2
	local xb, zb = X0 + i2 * S + S / 2, Z0 + j2 * S + S / 2
	for _, t in { 0.25, 0.5, 0.75 } do
		local x, z = xa + (xb - xa) * t, za + (zb - za) * t
		for _, b in bins[key(math.floor(x / B), math.floor(z / B))] or {} do
			if x >= b[1] and x <= b[4] and z >= b[3] and z <= b[6] and b[2] < h + 5.5 and b[5] > h + 0.3 then return true end
		end
	end
	return false
end
local function bfs(starts, up, down, blocked)
	local seen, q, head = {}, {}, 1
	for _, s in starts do seen[key(s[1], s[2])] = true; table.insert(q, s) end
	while head <= #q do
		local i, j = q[head][1], q[head][2]
		head += 1
		local f = cell(i, j)
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local i2, j2 = i + d[1], j + d[2]
			if i2 >= 0 and i2 < NI and j2 >= 0 and j2 < NJ and not seen[key(i2, j2)] then
				local g = cell(i2, j2)
				if g and f and g - f <= up and f - g <= down and not wall(i, j, i2, j2, math.max(f, g)) and not (blocked and blocked(i2, j2)) then
					seen[key(i2, j2)] = true
					table.insert(q, { i2, j2 })
				end
			end
		end
	end
	return seen, #q
end
local spawn = a and a.Root:FindFirstChild('Spawn', true)
local sp = spawn and frame:PointToObjectSpace(spawn.CFrame.Position) or Vector3.new(0, 0, 45)
local si, sj = idx(sp.X, sp.Z)
check('the spawn stands on a floor with room', cell(si, sj) ~= false, tostring(cell(si, sj)))
local fwd, reached = bfs({ { si, sj } }, 6, math.huge)
local function near(x, z, r)
	r = r or 4
	for dx = -r, r, S do
		for dz = -r, r, S do
			local i, j = idx(x + dx, z + dz)
			if fwd[key(i, j)] then return true end
		end
	end
	return false
end
-- the places a player must reach
check('the Stage 1 gate (its doorway out of the hall)', near(0, -4))
local top = V2.StageTop or function(i) return -(i - 1) * 64 end
for i = 1, 15 do check('Stage ' .. i .. ' (its middle)', near(0, top(i) - 30)) end
for i = 2, 16 do check('the pads before gate ' .. i, near(11.8, top(i) + 8.5, 4)) end
check('the rooftop (Stage 16)', near(0, (V2.BossTop or -960) - 40))
local L = V2.Lobby
check('the portal home (in front of it)', near(L.Plan.World2.x, L.Plan.World2.z - 8, 6))
for k, b in L.Plan.Boards do check('board ' .. k .. ' (in front of it)', near(b[1], b[2] - 8, 6)) end
check('the box dais (its front step)', near(0, 77))
check('the ranges (the training aisle)', near(-40, L.CrossZ))
check('the gun shop (in buying range of its deck)', near(40, L.CrossZ, 10)) -- (GunRules.Range 14; the stands fill the deck)
-- (Oct 27 round 5: World 2's stages have open lots and fewer buildings now) no way round a shut gate: with gate i's
-- barrier standing (and every other gate open), the stage past it can't be walked to
for gi = 2, 16 do
	local boxes = gateBoxes[gi]
	if boxes then
		local function shut(i, j)
			local x, z = X0 + i * S + S / 2, Z0 + j * S + S / 2
			for _, b in boxes do
				-- (a barrier is thinner than a cell: its band is widened by a stud, so a step can't hop it)
				if x + R + 1 > b[1] and x - R - 1 < b[3] and z + R + 1 > b[2] and z - R - 1 < b[4] then return true end
			end
			return false
		end
		local seen = bfs({ { si, sj } }, 6, math.huge, shut)
		local tx, tz = 0, gi <= 15 and top(gi) - 30 or (V2.BossTop or -960) - 40
		local past = false
		for dx = -4, 4, S do
			for dz = -4, 4, S do
				local i, j = idx(tx + dx, tz + dz)
				if seen[key(i, j)] then past = true end
			end
		end
		check('no way round gate ' .. gi .. ' while it is shut', not past)
	else
		check('gate ' .. gi .. ' has a barrier', false)
	end
end
-- nowhere to get stuck: every reachable cell walks back to the spawn (reverse: up any height you came down, down at
-- most a jump... i.e. from each cell, can you get to the spawn going forward?)
local back = bfs({ { si, sj } }, math.huge, 6) -- cells from which the spawn is reachable (the moves reversed)
local stuck, where = 0, ''
for k in fwd do
	if not back[k] then
		stuck += 1
	end
end
local groups = {}
for k in fwd do
	if not back[k] then
		local i, j = k // 100000, k % 100000
		local x, z = X0 + i * S, Z0 + j * S
		local g = math.floor(z / 64)
		local e = groups[g] or { x0 = x, x1 = x, z0 = z, z1 = z, n = 0 }
		e.x0, e.x1, e.z0, e.z1, e.n = math.min(e.x0, x), math.max(e.x1, x), math.min(e.z0, z), math.max(e.z1, z), e.n + 1
		groups[g] = e
	end
end
for _, e in groups do where = (where and where ~= '' and where .. '; ' or '') .. string.format('%d cells x %.0f..%.0f z %.0f..%.0f', e.n, e.x0, e.x1, e.z0, e.z1) end
check('no cell you can reach is a trap (the spawn reachable from each)', stuck == 0, stuck .. ' cells: ' .. tostring(where))
print((TAG .. ' %d solid boxes, %d cells reached'):format(count, reached))
print((TAG .. ' %d checks / %d failed'):format(n, #failed))
return { checks = n, failed = #failed, reached = reached, stuck = stuck }
