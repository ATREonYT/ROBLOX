--[[
	Every place the game puts a body, on the owner's real place (places/HUSSANIME.rbxl), is open ground (owner, Oct 19:
	"fix the spawn point locations, and make barriers around the spawns, and make them spawn not in the middle inside
	of objects and just make them spawn on open ground"; "make catchers spawn in the middle"; "make one lobby").
	Runs the real HuzzServer/MapService (init, the spawn pad, map loads, the line-up, the catchers' middle spots)
	with tools/world/geometry.luau standing in for Roblox's ray and box test, then checks each spot again:
	  - one lobby: the copy with nothing pasted twice is kept, the other two are put away whole, nothing of theirs is
	    left behind; each map loads in front of the one lobby exactly where it stood in front of its own copy;
	  - the spawn pad: open, 30 spots, his SpawnLocation on it, no rail (the owner removed it, Oct 19);
	  - per map, both start lines for 1 / 6 / 12 / 24 runners and the catchers' spots: floor under the feet (no edge
	    or hole), nothing solid or visible in a standing body's box, room to move, behind the line in the zone; the
	    catchers on the field's middle line (a row across it), facing the runners.
	It also measures the old spots (random over the whole plaza; random within 20 studs of the Middle box) and prints
	how many of them were bad, which is why this exists.
	Run from huzz-valley/: lune run tests/Spawns.spec.luau     (PRINT=1 lists the spots)
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Vector3, CFrame = roblox.Vector3, roblox.CFrame

local Geometry = require("../tools/world/geometry")
local LobbyLayout = require("../src/ReplicatedStorage/Shared/LobbyLayout")
local show = process.env.PRINT == "1"

local passed, failed = 0, 0
local function check(name, ok)
	if ok then passed += 1 else failed += 1 print("FAIL " .. name) end
end

-- engine methods Lune doesn't have
local pivots = setmetatable({}, { __mode = "k" })
local function partsOf(inst)
	local out = {}
	for _, d in inst:GetDescendants() do if d:IsA("BasePart") then table.insert(out, d) end end
	return out
end
local function bounds(inst)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in partsOf(inst) do
		local q = LobbyLayout.facts(p)
		lo = lo:Min(Vector3.new(q.X - q.hx, q.bottom, q.Z - q.hz))
		hi = hi:Max(Vector3.new(q.X + q.hx, q.top, q.Z + q.hz))
	end
	return lo, hi
end
pcall(roblox.implementMethod, "Model", "GetBoundingBox", function(self)
	local lo, hi = bounds(self)
	return CFrame.new((lo + hi) / 2), hi - lo
end)
-- (WorldPivot is a real property in Lune: PivotTo moves every part from it to the target, as Roblox does)
local function pivotOf(self)
	local ok, v = pcall(function() return self.WorldPivot end)
	return pivots[self] or (if ok and v then v else CFrame.new())
end
pcall(roblox.implementMethod, "Model", "GetPivot", pivotOf)
pcall(roblox.implementMethod, "Model", "PivotTo", function(self, target)
	local delta = target * pivotOf(self):Inverse()
	for _, p in partsOf(self) do p.CFrame = delta * p.CFrame end
	pivots[self] = target
	pcall(function() self.WorldPivot = target end)
end)
pcall(roblox.implementProperty, "BasePart", "Position", function(self) return self.CFrame.Position end, function(self, v)
	self.CFrame = self.CFrame - self.CFrame.Position + v
end)

local place = roblox.deserializePlace(fs.readFile("places/HUSSANIME.rbxl"))
local ws = place:GetService("Workspace")
local rs = place:GetService("ReplicatedStorage")
local ss = place:GetService("ServerStorage")

local function load(path, env)
	env = setmetatable(env or {}, { __index = _G })
	env.Vector3, env.CFrame, env.Color3, env.Instance, env.Enum = Vector3, CFrame, roblox.Color3, roblox.Instance, roblox.Enum
	return luau.load(fs.readFile(path), { environment = env })()
end
local Config = load("src/ReplicatedStorage/Shared/Config/Round.lua")
local SpawnSpots = load("src/ReplicatedStorage/Shared/SpawnSpots.lua")

-- The world as the game sees it: everything but our markers and walls (they're skipped in the game too).
local function ours(p)
	local a = p.Parent
	while a and a ~= ws do
		if string.sub(a.Name, 1, 4) == "Huzz" and a.Name ~= "HuzzSpawnPad" then return true end
		a = a.Parent
	end
	return false
end
local function zoneMarker(p)
	local k = (string.gsub(p.Name, "[%s_%-]", "")):lower()
	return k == "zonea" or k == "zoneb" or k == "middle" or k == "bench" or string.sub(k, 1, 13) == "zoneb(mirrore"
end
local geo, geoKey = nil, nil
local function world()
	local key = tostring(ws:FindFirstChild("ActiveMap")) .. "|" .. tostring(ws:FindFirstChild("HuzzSpawnPad")) .. "|" .. #ws:GetChildren()
	if key ~= geoKey or geoKey == nil then
		geoKey = key
		geo = Geometry.new(ws, { skip = function(p) return p.CanQuery == false or zoneMarker(p) or ours(p) end })
	end
	return geo
end
local api = {
	floor = function(...) return world().floor(...) end,
	blocked = function(...) return world().blocked(...) end,
}

-- The real MapService, its Roblox calls swapped for the stand-ins above.
local fakeServices = {
	Workspace = ws, ReplicatedStorage = rs, ServerStorage = ss,
	CollectionService = { GetTagged = function() return {} end, HasTag = function() return false end },
	Players = { GetPlayers = function() return {} end },
	PhysicsService = setmetatable({}, { __index = function() return function() return {} end end }),
}
local env = {
	game = { GetService = function(_, name) return fakeServices[name] end },
	workspace = ws, UDim2 = roblox.UDim2, Font = roblox.Font,
	RaycastParams = { new = function() return {} end }, OverlapParams = { new = function() return {} end },
	task = { spawn = function() end, delay = function() end, wait = function() end },
}
env.require = function(m)
	if m and m.Name == "LobbyLayout" then return LobbyLayout end
	if m and m.Name == "SpawnSpots" then return SpawnSpots end
	return Config
end
-- (MapService requires ReplicatedStorage.Shared.<Module>: the place's own Shared may be older or missing these)
do
	local shared = rs:FindFirstChild("Shared") or roblox.Instance.new("Folder")
	shared.Name = "Shared"
	shared.Parent = rs
	for _, n in { "LobbyLayout", "SpawnSpots" } do
		if not shared:FindFirstChild(n) then
			local m = roblox.Instance.new("ModuleScript")
			m.Name = n
			m.Parent = shared
		end
	end
	local cfg = shared:FindFirstChild("Config") or roblox.Instance.new("Folder")
	cfg.Name = "Config"
	cfg.Parent = shared
	if not cfg:FindFirstChild("Round") then
		local m = roblox.Instance.new("ModuleScript")
		m.Name = "Round"
		m.Parent = cfg
	end
end
local MapService = load("src/ServerScriptService/HuzzServer/MapService.lua", env)
MapService.geometry = api
do -- (a new map = a new world to read)
	local realLoad = MapService.load
	MapService.load = function(entry)
		geoKey = nil
		return realLoad(entry)
	end
end
MapService.ground = function(position, from)
	local top = from or (position.Y + 20)
	return world().floor(position.X, position.Z, top, position.Y - 60)
end

-- Is this spot (feet on the floor) open ground? (the rules again, plus how far off the floor it stands)
local function verify(feet: Vector3, what: string)
	local ok, y, why = SpawnSpots.check(api, feet.X, feet.Z, feet.Y)
	check(what .. ": open ground (" .. tostring(why) .. ")", ok and y and math.abs(y - feet.Y) < 0.05)
	return ok
end
local function feetOf(cf) return cf.Position - Vector3.new(0, SpawnSpots.RootHeight, 0) end
local Random = { new = function(seed)
	local state = seed
	return { NextNumber = function()
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end }
end }

-- SPAWN_DUMP=<file.json>: also write what tools/world/spawn_plan.py draws (docs/previews/spawns-one-lobby.jpg)
local dump = process.env.SPAWN_DUMP and { oldLobby = {}, oldSpawns = {}, maps = {} } or nil
local function footprints(list, keep)
	local out = {}
	for _, d in list do
		if d:IsA("BasePart") and d.ClassName ~= "Terrain" and d.Transparency < 0.95 and (not keep or keep(d)) then
			local cf, s = d.CFrame, d.Size
			local p = cf.Position
			local corners = {}
			for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
				local w = cf.RightVector * (c[1] * s.X / 2) + cf.LookVector * (c[2] * s.Z / 2)
				if math.abs(cf.UpVector.Y) < 0.5 then
					w = cf.UpVector * (c[1] * s.Y / 2) + (if math.abs(cf.RightVector.Y) < 0.5 then cf.RightVector * (c[2] * s.X / 2) else cf.LookVector * (c[2] * s.Z / 2))
				end
				table.insert(corners, { p.X + w.X, p.Z + w.Z })
			end
			local top = p.Y + math.abs(cf.UpVector.Y) * s.Y / 2 + math.abs(cf.RightVector.Y) * s.X / 2 + math.abs(cf.LookVector.Y) * s.Z / 2
			local col = d.Color
			table.insert(out, { c = corners, top = top, rgb = { math.floor(col.R * 255), math.floor(col.G * 255), math.floor(col.B * 255) } })
		end
	end
	return out
end
local function xz(v) return { v.X, v.Z } end
if dump then
	for _, d in ws:GetDescendants() do
		if d:IsA("SpawnLocation") then table.insert(dump.oldSpawns, xz(d.CFrame.Position)) end
	end
end

-- BEFORE: the old lobby spot (anywhere on the plaza, 3 in from its edges), on his place as it was
local floorsBefore = LobbyLayout.floors(ws)
local oldBad, oldTotal = 0, 0
do
	local f = LobbyLayout.main(ws)
	local half = f.Size / 2
	local rng = Random.new(7)
	for _ = 1, 300 do
		local l = Vector3.new((rng.NextNumber() * 2 - 1) * (half.X - 3), half.Y, (rng.NextNumber() * 2 - 1) * (half.Z - 3))
		local w = f.CFrame:PointToWorldSpace(l)
		local ok = SpawnSpots.check(api, w.X, w.Z, w.Y)
		oldTotal += 1
		if not ok then oldBad += 1 end
		if dump then table.insert(dump.oldLobby, { w.X, w.Z, ok and 1 or 0 }) end
	end
end

-- BEFORE: each map against its own copy of the lobby, as he built them (the baseline for "nothing inside the lobby")
local function clashes(mapParts, lobbyGeo)
	local n = 0
	for _, p in mapParts do
		if (p.CanCollide or p.Transparency < 0.9) and not zoneMarker(p) and not ours(p) then
			local q = LobbyLayout.facts(p)
			if lobbyGeo.blocked(Vector3.new(q.X, (q.top + q.bottom) / 2, q.Z), Vector3.new(q.hx * 2 - 0.2, q.top - q.bottom - 0.2, q.hz * 2 - 0.2), false) then
				n += 1
			end
		end
	end
	return n
end
local asBuilt = {}
do
	local lobbyGeo = Geometry.new(ws:FindFirstChild("StartingPoint"), { skip = function(p) return not (p.CanCollide or p.Transparency < 0.9) end })
	for _, m in ws:FindFirstChild("Maps"):GetChildren() do
		if m.Name ~= "Spawn" then asBuilt[m.Name] = clashes(partsOf(m), lobbyGeo) end
	end
end

MapService.init()

-- one lobby
local floors = LobbyLayout.floors(ws)
local main = MapService.lobby
check("three copies of his lobby found first (" .. #floorsBefore .. ")", #floorsBefore == 3)
check("one lobby left in Workspace", #floors == 1 and floors[1] == main)
check("the kept copy is the one with nothing pasted twice (his Base copy at -131, 49)",
	main and math.abs(main.CFrame.Position.X + 131.5) < 0.1 and math.abs(main.CFrame.Position.Z - 49) < 0.1)
local spare = ss:FindFirstChild("HuzzSpareLobbies")
check("the other two copies kept whole in ServerStorage > HuzzSpareLobbies", spare and #spare:GetChildren() == 2)
local spareParts = 0
for _, c in (spare and spare:GetChildren() or {}) do spareParts += #partsOf(c) end
check("they hold their whole copies (" .. spareParts .. " parts)", spareParts > 2000)
local left = 0
for _, d in ws:GetDescendants() do
	if d:IsA("BasePart") and not d:IsA("Terrain") then
		for _, f in floorsBefore do
			if f ~= main then
				local l = f.CFrame:PointToObjectSpace(d.CFrame.Position)
				if l.X > -200 and l.X < 60 and math.abs(l.Z) < 120 and math.abs(l.Y) < 120 then left += 1 end
			end
		end
	end
end
check("nothing of the other copies left in Workspace (" .. left .. ")", left == 0)
-- the download (tools/place/build_yours.luau puts the copies away before the game starts): their plazas are still
-- found in ServerStorage, so each map is still measured from the copy it was built beside
do
	local spareFloors = LobbyLayout.spareFloors(ss)
	local same = 0
	for _, f in floorsBefore do
		if f ~= main then
			for _, g in spareFloors do
				if (g.CFrame.Position - f.CFrame.Position).Magnitude < 0.01 then same += 1 break end
			end
		end
	end
	check("the put-away copies' plazas are found in ServerStorage (" .. #spareFloors .. ")", #spareFloors == 2 and same == 2)
end
local spawns = 0
for _, d in ws:GetDescendants() do
	if d:IsA("SpawnLocation") and d.Enabled then spawns += 1 end
end
check("one SpawnLocation on (" .. spawns .. ")", spawns == 1)

-- the spawn pad
local rec = MapService.lobbies[1]
local pad = rec and rec.pad
check("the spawn pad is open ground", pad and pad.open)
check("30 lobby spots", pad and #pad.spots == 30)
local inPad = 0
for i, s in (pad and pad.spots or {}) do
	verify(s, "lobby spot " .. i)
	local l = s - pad.centre
	local a, d = l:Dot(pad.across), l:Dot(pad.inward)
	if math.abs(a) < MapService.PAD_WIDTH / 2 and math.abs(d) < MapService.PAD_DEPTH / 2 then inPad += 1 end
	if show then print(string.format("  lobby spot %d (%.1f, %.1f, %.1f)", i, s.X, s.Y, s.Z)) end
end
check("12 spots inside the pad (" .. inPad .. ")", inPad == 12)
local sp = rec and rec.spawn
check("his SpawnLocation is on the pad", sp and (Vector3.new(sp.CFrame.Position.X, 0, sp.CFrame.Position.Z)
	- Vector3.new(pad.centre.X, 0, pad.centre.Z)).Magnitude < 0.1)
local rail = ws:FindFirstChild("HuzzSpawnPad")
-- (owner, Oct 19: "please remove that barrier in the lobby": no rail and no invisible walls round the pad)
check("no rail or invisible walls round the pad (owner removed them)", rail == nil and MapService.RAIL == false)
local opening = pad.centre + pad.inward * (MapService.PAD_DEPTH / 2 + 1)
check("the side into the plaza is open", not world().blocked(opening + Vector3.new(0, 2.5, 0), Vector3.new(6, 4, 1), true))
check("the pad faces into the lobby (towards its middle)", (main.CFrame.Position - pad.centre):Dot(pad.inward) > 0)
check("lobbySpot gives a pad spot", MapService.lobbySpot() ~= nil)
if dump and pad then
	local c = main.CFrame.Position
	dump.lobby = { cx = c.X, cz = c.Z, front = xz(-pad.inward), centre = xz(pad.centre), inward = xz(pad.inward), across = xz(pad.across),
		width = MapService.PAD_WIDTH, depth = MapService.PAD_DEPTH }
	dump.lobbyParts = footprints(ws:GetDescendants(), function(d)
		local p = d.CFrame.Position
		return math.abs(p.X - c.X) < 160 and math.abs(p.Z - c.Z) < 160 and not (rail and d:IsDescendantOf(rail)) and not zoneMarker(d)
	end)
	dump.rail = footprints(rail and rail:GetChildren() or {})
	dump.padSpots = {}
	for _, s in pad.spots do table.insert(dump.padSpots, xz(s)) end
end

-- every map, in front of the one lobby
local oldMidBad, oldMidTotal = 0, 0
for _, entry in MapService.maps do
	MapService.load(entry)
	local z = MapService.zones
	local name = entry.name
	-- where it stands: as in front of its own copy
	local stored = nil
	for _, d in entry.box:GetDescendants() do
		if d:IsA("BasePart") and (string.gsub(d.Name, "[%s_%-]", "")):lower() == "zonea" then stored = d end
	end
	local want = main.CFrame * entry.builtBeside:Inverse() * stored.CFrame.Position
	if show then print("  placement off by", z.ZoneA.CFrame.Position - want) end
	check(name .. ": in front of the lobby where it stood in front of its own copy", (z.ZoneA.CFrame.Position - want).Magnitude < 0.05
		or math.abs((z.ZoneA.CFrame.Position - want):Dot(Vector3.new(0, 1, 0))) < 0.05) -- (zones may be stretched across)
	-- nothing of the map inside the lobby
	local lobbyGeo = Geometry.new(ws:FindFirstChild("StartingPoint"), { skip = function(p) return not (p.CanCollide or p.Transparency < 0.9) end })
	local clash = clashes(partsOf(ws:FindFirstChild("ActiveMap")), lobbyGeo)
	print(string.format("  %-15s parts touching the lobby: %d (as he built it beside its own copy: %d)", name, clash, asBuilt[name] or -1))
	if show and clash > 0 then
		for _, p in partsOf(ws:FindFirstChild("ActiveMap")) do
			if (p.CanCollide or p.Transparency < 0.9) and not zoneMarker(p) and not ours(p) then
				local q = LobbyLayout.facts(p)
				local hit, what = lobbyGeo.blocked(Vector3.new(q.X, (q.top + q.bottom) / 2, q.Z), Vector3.new(q.hx * 2 - 0.2, q.top - q.bottom - 0.2, q.hz * 2 - 0.2), false)
				if hit then print("    ", p:GetFullName(), p.Size, "touches", what:GetFullName(), what.Size) end
			end
		end
	end
	check(name .. ": no part of the map in the lobby that wasn't there as he built it", clash <= (asBuilt[name] or 0))

	for _, startName in { "ZoneA", "ZoneB" } do
		for _, count in { 1, 6, 12, 24 } do
			local line, _, spots = MapService.lineup(startName, count)
			check(name .. " " .. startName .. ": " .. count .. " spots", #spots == count)
			local centre, out = line.Position, line.LookVector
			for i, cf in spots do
				local feet = feetOf(cf)
				local what = string.format("%s %s x%d spot %d", name, startName, count, i)
				verify(feet, what)
				check(what .. ": behind the line, in the zone", (feet - centre):Dot(out) < -0.9 and MapService.inZone(z[startName], feet + Vector3.new(0, 1, 0)))
				check(what .. ": facing across", cf.LookVector:Dot(out) > 0.99)
				for j = 1, i - 1 do
					check(what .. ": apart from " .. j, (feetOf(spots[j]) - feet).Magnitude >= 2.9)
				end
			end
		end
	end
	local mid, run = MapService.fieldMiddle()
	local spots = MapService.middleSpots()
	local m = nil
	if dump then
		m = { name = name, catchers = {}, lineA = {}, lineB = {}, oldCatchers = {}, mid = xz(mid), run = xz(run) }
		m.parts = footprints(ws:FindFirstChild("ActiveMap"):GetDescendants(), function(d) return not zoneMarker(d) end)
		for i = 1, 8 do table.insert(m.catchers, xz(MapService.middleSpot(i, "ZoneA").Position)) end
		for _, cf in select(3, MapService.lineup("ZoneA", 12)) do table.insert(m.lineA, xz(cf.Position)) end
		for _, cf in select(3, MapService.lineup("ZoneB", 12)) do table.insert(m.lineB, xz(cf.Position)) end
		table.insert(dump.maps, m)
	end
	if show then
		local ok, y, why = SpawnSpots.check(api, mid.X, mid.Z, mid.Y)
		local by = y and select(2, world().blocked(Vector3.new(mid.X, y + 3.1, mid.Z), SpawnSpots.Body, false))
		print("  centre:", ok, y, why, by and by:GetFullName(), by and by.Size, by and by.CFrame.Position)
	end
	check(name .. ": 24 catcher spots in the middle (" .. #spots .. ")", #spots >= 24)
	for i = 1, 8 do
		local cf = MapService.middleSpot(i, "ZoneA")
		local feet = feetOf(cf)
		local what = string.format("%s catcher %d", name, i)
		verify(feet, what)
		local along = (feet - mid):Dot(run)
		local across = (feet - mid):Dot(run:Cross(Vector3.new(0, 1, 0)))
		check(what .. ": on the middle line (" .. string.format("%.1f", along) .. " studs off)", math.abs(along) <= 6.5)
		check(what .. ": near the centre across (" .. string.format("%.1f", across) .. ")", math.abs(across) <= 23)
		local toStart = (z.ZoneA.CFrame.Position - feet) * Vector3.new(1, 0, 1)
		check(what .. ": faces the runners", cf.LookVector:Dot(toStart.Unit) > 0.95)
		if show then print(string.format("  %s at (%.1f, %.1f) along %.1f across %.1f", what, feet.X, feet.Z, along, across)) end
	end
	check(name .. ": the first catcher dead centre", (feetOf(MapService.middleSpot(1, "ZoneA")) - mid) * Vector3.new(1, 0, 1)
		== Vector3.zero or ((feetOf(MapService.middleSpot(1, "ZoneA")) - mid) * Vector3.new(1, 0, 1)).Magnitude < 2.6)
	-- BEFORE: the old catcher spot (random within 20 studs of the Middle box's centre)
	local rng = Random.new(11)
	local middle = z.Middle
	for _ = 1, 200 do
		local half = middle.Size / 2
		local sx, sz = math.min(half.X - 3, 20), math.min(half.Z - 3, 20)
		local w = middle.CFrame:PointToWorldSpace(Vector3.new((rng.NextNumber() * 2 - 1) * sx, half.Y, (rng.NextNumber() * 2 - 1) * sz))
		local y = MapService.ground(w - Vector3.new(0, middle.Size.Y, 0), w.Y + 2)
		oldMidTotal += 1
		local good = y and SpawnSpots.check(api, w.X, w.Z, y)
		if not good then oldMidBad += 1 end
		if m then table.insert(m.oldCatchers, { w.X, w.Z, good and 1 or 0 }) end
	end
	print(string.format("  %-15s field middle (%.1f, %.1f, %.1f), Middle box centre (%.1f, %.1f): %.1f studs apart",
		name, mid.X, mid.Y, mid.Z, middle.CFrame.Position.X, middle.CFrame.Position.Z, ((middle.CFrame.Position - mid) * Vector3.new(1, 0, 1)).Magnitude))
end
MapService.unload()
if dump then
	dump.oldBad, dump.oldTotal, dump.oldMidBad, dump.oldMidTotal = oldBad, oldTotal, oldMidBad, oldMidTotal
	fs.writeFile(process.env.SPAWN_DUMP, require("@lune/serde").encode("json", dump))
end
print(string.format("before: %d of %d old lobby spots and %d of %d old catcher spots were not open ground",
	oldBad, oldTotal, oldMidBad, oldMidTotal))
print(string.format("Spawns: %d passed, %d failed", passed, failed))
if failed > 0 then process.exit(1) end
