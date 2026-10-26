-- lobby_metrics.luau: the lobby's numbers after a build (run through export.sh's harness, or append to a Build snippet):
--   dist      straight-line studs from the spawn (LobbySpawn) to each station (map frame, on the floor)
--   labels    billboards readable from the spawn's follow camera (12 back, 9 up, looking north; inside a ~106-degree
--             forward cone and HoodClient/LabelFade's band: readable = at least half faded in), with their names
--   empty     the share of the hall's floor (inside the warehouse walls) with nothing standing on it taller than 0.7
--             (walks, decks and plinths count as floor; lanes, pads, props and stands do not)
--   upright   design models (ItemMesh) tilted more than 2 degrees
-- Usage: lune run harness.luau <hood/src> - "<fake import> require(game.ServerStorage.TheBlockV2).Build() <this file>"
local root = workspace.TheBlockV2
local V2 = require(game.ServerStorage.TheBlockV2)
local Lobby = V2.Lobby
local o = root:GetAttribute('Origin') or Vector3.new(2400, 0, 0)
local sp = root:GetAttribute('LobbySpawn') or Vector3.new(0, 0, 55)
local function flat(p) return Vector3.new(p.X, 0, p.Z) end
local function d(p) return math.floor((flat(p) - flat(sp)).Magnitude + 0.5) end
local S = Lobby.Slots
local out, dist = {}, {}
local function add(name, p) if p then table.insert(dist, name .. '=' .. d(p)) end end
add('gate', Vector3.new(0, 0, 0))
-- the lanes: each TrainingZone (the shooter's box), nearest and farthest, and the head lane
local near, far, head = math.huge, 0, nil
for _, m in root:GetDescendants() do
	if m:IsA('Model') and m.Name:find('^Training_') then
		local z = m:FindFirstChild('TrainingZone', true)
		local p = z and (z.CFrame.Position - o)
		if p and p.Z > -10 then
			near, far = math.min(near, d(p)), math.max(far, d(p))
			if m.Name == 'Training_Head' then head = d(p) end
		end
	end
end
table.insert(dist, 'laneNearest=' .. near) table.insert(dist, 'laneFarthest=' .. far) table.insert(dist, 'laneHead=' .. tostring(head))
add('gunStand', S.Armory and S.Armory.Position)
local bx = math.huge
for k = 1, 8 do if S['ShoeBox' .. k] then bx = math.min(bx, d(S['ShoeBox' .. k].Position)) end end
table.insert(dist, 'boxRow=' .. bx)
add('portal', S.World2 and S.World2.Position)
add('bossBoard', S.WorldBossBoard and S.WorldBossBoard.Position)
for k = 1, 3 do add('board' .. k, S['Leaderboard' .. k] and S['Leaderboard' .. k].Position) end
local g = Lobby.Plan.Group
add('chest', Vector3.new(g.chest[1], 0, g.chest[2])) add('codes', Vector3.new(g.codes[1], 0, g.codes[2]))
if Lobby.SpinAt then add('spin', Vector3.new(Lobby.SpinAt.x, 0, Lobby.SpinAt.z)) end
local pmin, pmax, np = math.huge, 0, 0
for k, cf in S do
	if type(k) == 'string' and (k:find('^Stand_') or k:find('^BoxPad_')) then np += 1; pmin, pmax = math.min(pmin, d(cf.Position)), math.max(pmax, d(cf.Position)) end
end
table.insert(dist, ('pads=%d nearest %d farthest %d'):format(np, pmin, pmax))
out.dist = table.concat(dist, ' ')
-- labels from the spawn's follow camera
local eye = o + sp + Vector3.new(0, 9, 12)
local n, names, nbb, nbad, nvis = 0, {}, 0, 0, 0
local okLF, LF = pcall(function() return require(game.ReplicatedStorage.Shared.LabelFade) end)
if not okLF then LF = nil end
for _, b in (root:FindFirstChild('Lobby', true) or root):GetDescendants() do
	if b:IsA('BillboardGui') and b.Enabled ~= false then
		local a = b.Adornee or b.Parent
		local ok, p = pcall(function() if a:IsA('BasePart') then return a.CFrame.Position elseif a:IsA('Attachment') then return a.WorldPosition end return nil end)
		nbb += 1
		if not (ok and p) then nbad += 1 end
		if ok and p then
			local v = p - eye
			-- (HoodClient/LabelFade's bands: a label is readable while it is at least half faded in)
			local far2 = (b.MaxDistance or 0) > 0 and b.MaxDistance or math.huge
			local mid = far2
			local kind = LF and LF.kindOf(b)
			if kind then
				local cfg = LF.config(b, kind, b.MaxDistance)
				far2, mid = cfg.Far, (cfg.Near + cfg.Far) / 2
			end
			if -v.Z / v.Magnitude > 0.6 then
				if v.Magnitude <= mid then n += 1; table.insert(names, (a.Parent and a.Parent.Name or '?') .. '/' .. b.Name .. '@' .. math.floor(v.Magnitude)) end
				if v.Magnitude <= far2 then nvis += 1 end
			end
		end
	end
end
out.labels = ('%d readable (at least half faded in), %d drawn at all'):format(n, nvis)
out.billboards = ('%d in the lobby, %d unplaced'):format(nbb, nbad)
out.labelNames = table.concat(names, ', ')
-- empty floor inside the walls
local Wh = Lobby.WH
if Wh then
	local x0, x1, z0, z1 = Wh.x0, Wh.x1, Wh.z0, Wh.z1
	local nx, nz = math.floor(x1 - x0), math.floor(z1 - z0)
	local busy = {}
	local lobby = root:FindFirstChild('Lobby', true)
	local skip = { Hall = true, Roof = true, HallLamps = true, HallFloor = true }
	for _, p in lobby:GetDescendants() do
		if p:IsA('BasePart') and (p.Transparency < 1 or p.CanCollide) then
			local top = p
			local skipIt = false
			while top and top ~= lobby do if skip[top.Name] then skipIt = true break end top = top.Parent end
			if not skipIt then
				local cf, s = p.CFrame, p.Size
				local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
				local h = Vector3.new(math.abs(r00) * s.X + math.abs(r01) * s.Y + math.abs(r02) * s.Z, math.abs(r10) * s.X + math.abs(r11) * s.Y + math.abs(r12) * s.Z, math.abs(r20) * s.X + math.abs(r21) * s.Y + math.abs(r22) * s.Z) / 2
				local c = cf.Position - o
				if c.Y + h.Y > 0.7 and c.Y - h.Y < 10 and h.X < 60 and h.Z < 60 then
					for i = math.max(0, math.floor(c.X - h.X - x0)), math.min(nx - 1, math.floor(c.X + h.X - x0)) do
						local cx = x0 + i + 0.5
						if cx >= c.X - h.X and cx <= c.X + h.X then
							for j = math.max(0, math.floor(c.Z - h.Z - z0)), math.min(nz - 1, math.floor(c.Z + h.Z - z0)) do
								local cz = z0 + j + 0.5
								if cz >= c.Z - h.Z and cz <= c.Z + h.Z then busy[i * 100000 + j] = true end
							end
						end
					end
				end
			end
		end
	end
	local nb = 0
	for _ in busy do nb += 1 end
	out.hall = ('%dx%d'):format(nx, nz)
	out.empty = ('%.0f%%'):format(100 * (1 - nb / (nx * nz)))
end
-- upright check
local bad, worst, models = 0, 0, 0
local tilted = {}
for _, m in root:GetDescendants() do
	if m:IsA('Model') and m:GetAttribute('ItemMesh') then
		models += 1
		for _, p in m:GetDescendants() do
			if p:IsA('BasePart') then
				local ang = math.deg(math.acos(math.clamp(p.CFrame.UpVector.Y, -1, 1)))
				worst = math.max(worst, ang)
				if ang > 2 then bad += 1; table.insert(tilted, m.Name) break end
			end
		end
	end
end
out.upright = ('%d design models, %d tilted, worst %.2f deg %s'):format(models, bad, worst, table.concat(tilted, ','))
return out
