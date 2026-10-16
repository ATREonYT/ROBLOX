--[[
	The owner's maps: found at start, stored away, and the chosen one copied in
	front of the lobby island for each game (the owner's call: the voted map
	"spawns in front of the lobby", where people in the lobby can watch).

	A map is any folder or model in Workspace holding parts named ZoneA, ZoneB
	and Middle (names match loosely: "Zone A" works; optional: Bench), e.g.
	  Workspace > Maps > Halloween_Map > Zone A, Zone B, Middle
	At start every map moves to ReplicatedStorage.HuzzMaps (so clients can show
	it in the vote cards). load(map) copies it in front of the lobby as it was
	built, only turned so its open side faces the lobby (openSide), with invisible
	walls round the field; unload() removes it.
	A part named MapSpot (optional) sets exactly where the map's middle goes;
	its front face points the way the open side should face.

	The lobby is a part named Lobby, else the SpawnBaseplate. With no zones at
	all a plain test field is built in place so the game still runs.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local PhysicsService = game:GetService("PhysicsService")

local Config = require(ReplicatedStorage.Shared.Config.Round)

local MapService = {}
MapService.zones = {} -- the loaded map's zones (filled in place, so callers can keep the table)
MapService.maps = {} -- { name, box (stored container), fixed (test field: used where it is) }
MapService.current = nil -- the loaded map's entry
local loaded -- the copy in Workspace
local marks, wall -- the current map's safe lines and sign, and the start-line wall before GO
local gate -- the goal line's gate: only runners already safe bump into it (holdGoal)
local lastPicked
local zoneParts = {} -- every zone part, so floor checks look through them

local function asPart(item)
	if item and item:IsA("BasePart") then
		return item
	elseif item and item:IsA("Model") then
		return item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

-- Names match loosely: "Zone A", "zonea" and "ZoneA" are all ZoneA.
local function key(name)
	return (string.gsub(name, "[%s_%-]", "")):lower()
end

local function childNamed(box, name)
	local want = key(name)
	for _, c in box:GetChildren() do
		if key(c.Name) == want then
			return asPart(c)
		end
	end
	return nil
end

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	return p
end

-- A sandy 240-stud lane: ZoneA and ZoneB at the ends, Middle in the centre,
-- a fenced Bench off to the side. Only built when no map has zones.
local function buildTestField()
	local folder = Instance.new("Folder")
	folder.Name = "HuzzTestField"
	local sand = Color3.fromRGB(236, 200, 140)
	part({ Name = "Floor", Size = Vector3.new(72, 1, 250), Position = Vector3.new(0, -0.4, 0), Color = sand, Material = Enum.Material.Sand, Parent = folder })
	local function zone(name, z, color)
		return part({
			Name = name, Size = Vector3.new(72, 0.2, 26), Position = Vector3.new(0, 0.2, z), Color = color,
			Material = Enum.Material.Neon, Transparency = 0.55, CanCollide = false, Parent = folder,
		})
	end
	zone("ZoneA", -112, Color3.fromRGB(90, 220, 140))
	zone("ZoneB", 112, Color3.fromRGB(90, 220, 140))
	part({
		Name = "Middle", Size = Vector3.new(24, 0.2, 24), Position = Vector3.new(0, 0.2, 0), Color = Color3.fromRGB(255, 90, 90),
		Material = Enum.Material.Neon, Transparency = 0.6, CanCollide = false, Parent = folder,
	})
	for _, x in { -37, 37 } do
		part({ Name = "Wall", Size = Vector3.new(2, 12, 250), Position = Vector3.new(x, 6, 0), Transparency = 0.7, Color = sand, Parent = folder })
	end
	for _, z in { -126, 126 } do
		part({ Name = "Wall", Size = Vector3.new(76, 12, 2), Position = Vector3.new(0, 6, z), Transparency = 0.7, Color = sand, Parent = folder })
	end
	part({ Name = "Bench", Size = Vector3.new(20, 1, 40), Position = Vector3.new(52, 3.5, 0), Color = Color3.fromRGB(120, 110, 160), Parent = folder })
	folder.Parent = Workspace
	return folder
end

-- The zones inside a map container (adds a mirrored ZoneB when it's missing).
local function zonesOf(box, name, quiet)
	local C = Config.Map
	local a, b, middle = childNamed(box, C.ZoneA), childNamed(box, C.ZoneB), childNamed(box, C.Middle)
	if a and middle and not b then
		-- No ZoneB: mirror ZoneA across the Middle (same size), so the map still works.
		b = a:Clone()
		b:ClearAllChildren()
		b.Name = "ZoneB (mirrored)"
		local m, p = middle.CFrame.Position, a.CFrame.Position
		b.CFrame = a.CFrame.Rotation + Vector3.new(2 * m.X - p.X, p.Y, 2 * m.Z - p.Z)
		b.Transparency = 1
		b.Parent = box
		if not quiet then
			warn(`[Huzz] {name} has no ZoneB: using one mirrored from ZoneA across the Middle`)
		end
	end
	return a, b, middle, childNamed(box, C.Bench)
end

local function prepare(zone)
	if zone then
		-- Zones are markers: anchored (or they'd fall through the map), not solid.
		zone.Anchored = true
		zone.CanCollide = false
		zone.CanTouch = false
		table.insert(zoneParts, zone)
	end
	return zone
end

local function displayName(name)
	return Config.Map.Names[name] or (name:gsub("_?[Mm][Aa][Pp]$", ""):gsub("_", " "))
end

function MapService.init()
	local C = Config.Map
	local storage = ReplicatedStorage:FindFirstChild("HuzzMaps") or Instance.new("Folder")
	storage.Name = "HuzzMaps"
	storage.Parent = ReplicatedStorage

	-- Every container holding a ZoneA (plus Middle) is a map.
	local boxes = {}
	for _, d in Workspace:GetDescendants() do
		if key(d.Name) == key(C.ZoneA) and asPart(d) and not table.find(boxes, d.Parent) then
			table.insert(boxes, d.Parent)
		end
	end
	for _, box in boxes do
		-- Named after its folder; a folder just called "Zones" takes its parent's name.
		local named = if box.Name:lower():find("zone") and box.Parent ~= Workspace then box.Parent else box
		local name = if named == Workspace then "Main" else named.Name
		local a, b, middle = zonesOf(box, name)
		if a and b and middle then
			box.Name = name
			box.Parent = storage
			table.insert(MapService.maps, { name = name, display = displayName(name), box = box })
			print(`[Huzz] Map found: {name}`)
		else
			warn(`[Huzz] {box:GetFullName()} has a ZoneA but is missing Middle: skipped`)
		end
	end
	if #MapService.maps == 0 then
		if not C.BuildTestField then
			error("[Huzz] No map has ZoneA, ZoneB and Middle (see Config/Round.lua > Map)")
		end
		warn("[Huzz] No ZoneA/ZoneB/Middle in the map: building the test field")
		table.insert(MapService.maps, { name = "Test Field", display = "Test Field", box = buildTestField(), fixed = true })
	end

	-- The lobby: a part named Lobby, else the SpawnBaseplate.
	local lobby, base, spot
	for _, d in Workspace:GetDescendants() do
		if d:IsA("BasePart") then
			if key(d.Name) == key(C.Lobby) then
				lobby = lobby or d
			elseif key(d.Name) == "spawnbaseplate" then
				base = base or d
			elseif key(d.Name) == "mapspot" then
				spot = spot or d
			end
		end
	end
	MapService.lobby = asPart(CollectionService:GetTagged("HuzzLobby")[1]) or lobby or base
	MapService.mapSpot = spot

	-- Players must still spawn somewhere once the maps (and their SpawnLocations) are stored away.
	local hasSpawn = false
	for _, d in Workspace:GetDescendants() do
		if d:IsA("SpawnLocation") and d.Enabled then
			hasSpawn = true
		end
	end
	if not hasSpawn and MapService.lobby then
		local s = Instance.new("SpawnLocation")
		s.Name = "HuzzLobbySpawn"
		s.Anchored, s.CanCollide, s.Transparency, s.Neutral, s.Duration = true, false, 1, true, 0
		s.Size = Vector3.new(12, 1, 12)
		s.CFrame = CFrame.new(MapService.lobby.CFrame.Position + Vector3.new(0, MapService.lobby.Size.Y / 2 + 0.6, 0))
		s.Parent = Workspace
	end
	MapService.zones.Lobby = MapService.lobby
end

function MapService.byName(name)
	for _, m in MapService.maps do
		if m.name == name then
			return m
		end
	end
	return nil
end

-- Two different maps for the vote (avoiding the last one played when there are 3+).
function MapService.candidates()
	local pool = {}
	for _, m in MapService.maps do
		if #MapService.maps < 3 or m ~= lastPicked then
			table.insert(pool, m)
		end
	end
	local i = math.random(#pool)
	local a = table.remove(pool, i)
	local b = if #pool > 0 then pool[math.random(#pool)] else a
	return a, b
end

-- A random map (no vote): never the same one twice in a row.
function MapService.pick()
	local maps = MapService.maps
	local choice = maps[math.random(#maps)]
	if #maps > 1 then
		while choice == lastPicked do
			choice = maps[math.random(#maps)]
		end
	end
	return choice
end

-- The middle of a group of parts (a model's pivot without needing one).
local function centroid(item)
	if item:IsA("BasePart") then
		return item.CFrame.Position
	end
	local sum, n = Vector3.zero, 0
	for _, d in item:GetDescendants() do
		if d:IsA("BasePart") then
			sum += d.CFrame.Position
			n += 1
		end
	end
	return if n > 0 then sum / n else nil
end

--[[
	Which long side of the field should face the lobby (owner's call: people in the lobby watch
	through the open side). Returns that side's outward direction (flat, as the map was built).
	  1. Config.Map.FarSide[name] names a landmark (e.g. Halloween's "Mausoleum") that goes on the
	     far side, away from the lobby.
	  2. Config.Map.OpenSide[name] = true: the side with fewer tall things along it (fences, walls)
	     faces the lobby; when both are much the same, the side that faced it as built.
	  3. Anything else keeps the side that faced the lobby as built (owner: maps came out flipped).
]]
local function openSide(box, middle, run, name)
	local mid = middle.CFrame.Position
	local side = run:Cross(Vector3.yAxis).Unit
	local midLocal = middle.CFrame:VectorToObjectSpace(side)
	local half = math.abs(midLocal.X) * middle.Size.X / 2 + math.abs(midLocal.Z) * middle.Size.Z / 2
	local far = Config.Map.FarSide and Config.Map.FarSide[name]
	local landmark = far and box:FindFirstChild(far, true)
	local at = landmark and centroid(landmark)
	if at then
		return if (at - mid):Dot(side) > 0 then -side else side
	end
	local sign = 1
	local lobby = MapService.lobby
	if lobby and (lobby.CFrame.Position - mid):Dot(side) < 0 then
		sign = -1 -- as built, the other side faced the lobby
	end
	if not (Config.Map.OpenSide and Config.Map.OpenSide[name]) then
		return side * sign
	end
	local cover = { [1] = 0, [-1] = 0 }
	for _, d in box:GetDescendants() do
		if d:IsA("BasePart") and d ~= middle and d.Transparency < 1 then
			local rel = d.CFrame.Position - mid
			local across = rel:Dot(side)
			local top = rel.Y + d.Size.Y / 2
			if top > 4 and math.abs(across) > half * 0.6 and math.abs(across) < half + 40 then
				local s = if across > 0 then 1 else -1
				cover[s] += math.max(d.Size.X, d.Size.Z) * math.min(top, 30)
			end
		end
	end
	if cover[sign] > cover[-sign] * 1.15 + 50 then
		sign = -sign
	end
	return side * sign
end
MapService.openSide = openSide

-- The lowest bottom of the visible parts in a folder or model (zones and markers don't count).
local function lowest(container)
	local low = math.huge
	for _, d in container:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local k = key(d.Name)
			if k ~= "zonea" and k ~= "zoneb" and k ~= "middle" and k ~= "bench" then
				local cf, h = d.CFrame, d.Size / 2
				local extent = math.abs(cf.RightVector.Y) * h.X + math.abs(cf.UpVector.Y) * h.Y + math.abs(cf.LookVector.Y) * h.Z
				low = math.min(low, cf.Position.Y - extent)
			end
		end
	end
	return low
end

-- Where the map's middle goes: MapSpot if there is one, else just in front of the lobby, turned so its
-- open side (see openSide) faces the lobby. A map built floating higher than the lobby island's ground is
-- lowered to stand on it (owner: the basketball map floated); one built lower keeps its height.
local function placement(middle, open, model)
	local spot = MapService.mapSpot
	if spot then
		return spot.CFrame
	end
	local lobby = MapService.lobby
	local mid = middle.CFrame.Position
	if not lobby then
		return CFrame.lookAt(mid, mid + open) -- no lobby: the map stays where it was built
	end
	-- "In front": the side of the lobby that faces where the maps were built.
	local away = Vector3.zero
	for _, m in MapService.maps do
		local p = select(3, zonesOf(m.box, m.name, true))
		if p then
			away += p.CFrame.Position - lobby.CFrame.Position
		end
	end
	away = Vector3.new(away.X, 0, away.Z)
	local axes = { lobby.CFrame.LookVector, -lobby.CFrame.LookVector, lobby.CFrame.RightVector, -lobby.CFrame.RightVector }
	local front = axes[1]
	for _, ax in axes do
		if away.Magnitude > 0 and ax:Dot(away) > front:Dot(away) then
			front = ax
		end
	end
	front = Vector3.new(front.X, 0, front.Z).Unit
	-- Distance: the lobby's half-depth + a gap + the map's half-depth (across its run).
	local lobbyLocal = lobby.CFrame:VectorToObjectSpace(front)
	local lobbyHalf = math.abs(lobbyLocal.X) * lobby.Size.X / 2 + math.abs(lobbyLocal.Z) * lobby.Size.Z / 2
	local midLocal = middle.CFrame:VectorToObjectSpace(open)
	local mapHalf = math.abs(midLocal.X) * middle.Size.X / 2 + math.abs(midLocal.Z) * middle.Size.Z / 2
	local centre = lobby.CFrame.Position + front * (lobbyHalf + Config.Map.Gap + mapHalf)
	local drop = 0
	if model then
		local island = if lobby.Parent and lobby.Parent ~= Workspace then lobby.Parent else lobby
		local mapLow, groundLow = lowest(model), math.min(lowest(island), lobby.CFrame.Position.Y - lobby.Size.Y / 2)
		if mapLow < math.huge and groundLow < math.huge and mapLow > groundLow then
			drop = mapLow - groundLow
		end
	end
	centre = Vector3.new(centre.X, mid.Y - drop, centre.Z)
	return CFrame.lookAt(centre, centre - front) -- the open side looks back at the lobby
end

-- Invisible walls round the field (ZoneA, Middle and ZoneB), so nobody jumps off the map.
local function boundary(model, a, b, middle)
	local mid = middle.CFrame.Position
	local run = Vector3.new(b.CFrame.Position.X - a.CFrame.Position.X, 0, b.CFrame.Position.Z - a.CFrame.Position.Z).Unit
	local side = run:Cross(Vector3.yAxis).Unit
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in { a, b, middle } do
		local h = part.Size / 2
		for _, c in { Vector3.new(-1, -1, -1), Vector3.new(1, -1, -1), Vector3.new(-1, 1, -1), Vector3.new(1, 1, -1),
			Vector3.new(-1, -1, 1), Vector3.new(1, -1, 1), Vector3.new(-1, 1, 1), Vector3.new(1, 1, 1) } do
			local w = part.CFrame:PointToWorldSpace(h * c) - mid
			local p = Vector3.new(w:Dot(run), w.Y, w:Dot(side))
			lo, hi = lo:Min(p), hi:Max(p)
		end
	end
	local frame = CFrame.fromMatrix(mid, run, Vector3.yAxis, side) -- x = along the run, z = across (right-handed)
	local floorY = MapService.ground(mid, mid.Y + middle.Size.Y) or (mid.Y + lo.Y)
	local height = Config.Map.BoundsHeight
	local y = floorY - mid.Y - 2 + height / 2
	local folder = Instance.new("Folder")
	folder.Name = "HuzzBounds"
	local lengthX, lengthZ = hi.X - lo.X, hi.Z - lo.Z
	local midX, midZ = (hi.X + lo.X) / 2, (hi.Z + lo.Z) / 2
	for _, w in {
		{ CFrame.new(lo.X - 1, y, midZ), Vector3.new(2, height, lengthZ + 4) },
		{ CFrame.new(hi.X + 1, y, midZ), Vector3.new(2, height, lengthZ + 4) },
		{ CFrame.new(midX, y, lo.Z - 1), Vector3.new(lengthX + 4, height, 2) },
		{ CFrame.new(midX, y, hi.Z + 1), Vector3.new(lengthX + 4, height, 2) },
	} do
		local p = Instance.new("Part")
		p.Name = "Wall"
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, true, false, false, false
		p.Transparency = 1
		p.Size = w[2]
		p.CFrame = frame * w[1]
		p.Parent = folder
	end
	folder.Parent = model
end

-- Copies a map in front of the lobby (as it was built, its open side facing the lobby) and makes it
-- the current map.
function MapService.load(entry)
	MapService.unload()
	lastPicked = entry
	local model
	if entry.fixed then
		model = entry.box
	else
		model = Instance.new("Model")
		model.Name = "ActiveMap"
		for _, c in entry.box:Clone():GetChildren() do
			c.Parent = model
		end
		local a, b, middle = zonesOf(model, entry.name, true)
		local mid = middle.CFrame.Position
		local run = Vector3.new(b.CFrame.Position.X - a.CFrame.Position.X, 0, b.CFrame.Position.Z - a.CFrame.Position.Z).Unit
		local open = openSide(model, middle, run, entry.name)
		model.WorldPivot = CFrame.lookAt(mid, mid + open)
		model:PivotTo(placement(middle, open, model))
		for _, d in model:GetDescendants() do
			if d:IsA("SpawnLocation") then
				d.Enabled = false -- players respawn in the lobby, not on the map
			end
		end
		model.Parent = Workspace
		loaded = model
		if Config.Map.BoundsHeight > 0 then
			boundary(model, a, b, middle) -- after it's in the world, so the floor check hits the map
		end
	end
	local a, b, middle, bench = zonesOf(model, entry.name, true)
	local z = MapService.zones
	z.ZoneA, z.ZoneB, z.Middle, z.Bench = prepare(a), prepare(b), prepare(middle), prepare(bench)
	MapService.current = entry
	return entry
end

function MapService.unload()
	for _, item in { marks, wall, gate } do
		item:Destroy()
	end
	marks, wall, gate = nil, nil, nil
	if loaded then
		loaded:Destroy()
		loaded = nil
	end
	local z = MapService.zones
	z.ZoneA, z.ZoneB, z.Middle, z.Bench = nil, nil, nil, nil
	MapService.current = nil
end

-- Inside the zone's footprint; generous upward so jumping still counts.
function MapService.inZone(zone, position)
	local p = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size * 0.5
	return math.abs(p.X) <= half.X and math.abs(p.Z) <= half.Z and p.Y >= -half.Y - 4 and p.Y <= half.Y + 14
end

-- The floor height under a point (ignoring zones, players and girls), or nil.
function MapService.ground(position, from)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = table.clone(zoneParts)
	for _, name in { "HuzzCarried", "HuzzFollowers" } do
		table.insert(ignore, Workspace:FindFirstChild(name))
	end
	for _, p in game:GetService("Players"):GetPlayers() do
		table.insert(ignore, p.Character)
	end
	params.FilterDescendantsInstances = ignore
	local top = from or (position.Y + 20)
	local hit = Workspace:Raycast(Vector3.new(position.X, top, position.Z), Vector3.new(0, -(top - position.Y) - 60, 0), params)
	return hit and hit.Position.Y
end

-- A random standing spot in the zone, on the floor under it, facing lookAt.
-- maxSpread limits how far from the zone's centre (catchers stay in the real middle).
function MapService.spot(zone, lookAt, maxSpread)
	local half = zone.Size * 0.5
	local spread = maxSpread or math.huge
	local inset = Vector3.new(math.min(math.max(half.X - 3, 0), spread), 0, math.min(math.max(half.Z - 3, 0), spread))
	local local_ = Vector3.new((math.random() * 2 - 1) * inset.X, half.Y, (math.random() * 2 - 1) * inset.Z)
	local top = zone.CFrame:PointToWorldSpace(local_)
	local floor = MapService.ground(top - Vector3.new(0, zone.Size.Y, 0), top.Y + 2)
	local pos = Vector3.new(top.X, (floor or top.Y) + 3.2, top.Z)
	local flat = lookAt and Vector3.new(lookAt.X, pos.Y, lookAt.Z)
	if flat and (flat - pos).Magnitude > 0.1 then
		return CFrame.lookAt(pos, flat)
	end
	return CFrame.new(pos)
end

-- A zone's edge that faces the middle: its centre, the way out (toward the middle) and its length.
-- Zones are boxes (they may be turned), so the edge is the box face most in line with the middle.
local function edge(zone)
	local middle = MapService.zones.Middle
	local zc = zone.CFrame
	local d = zc:PointToObjectSpace(middle.CFrame.Position)
	local half = zone.Size * 0.5
	local useX = math.abs(d.X) / math.max(half.X, 0.1) >= math.abs(d.Z) / math.max(half.Z, 0.1)
	local sign = if useX then (if d.X >= 0 then 1 else -1) else (if d.Z >= 0 then 1 else -1)
	local localOut = if useX then Vector3.new(sign, 0, 0) else Vector3.new(0, 0, sign)
	local centre = zc:PointToWorldSpace(if useX then Vector3.new(sign * half.X, 0, 0) else Vector3.new(0, 0, sign * half.Z))
	local length = if useX then zone.Size.Z else zone.Size.X
	local floor = MapService.ground(centre, centre.Y + half.Y + 1) or (centre.Y - half.Y)
	local out = zc:VectorToWorldSpace(localOut)
	-- Zone boxes are often wider than the floor: trim the line to where there is floor at this height, so the
	-- line, the start wall and the goal gate never stick out past the map's edge or through its fences.
	local along = out:Cross(Vector3.yAxis)
	along = if along.Magnitude > 0.01 then along.Unit else Vector3.xAxis
	local function reach(dir)
		local d = 0
		while d + 2 <= length / 2 do
			local p = Vector3.new(centre.X, floor, centre.Z) + along * (dir * (d + 2))
			local y = MapService.ground(p, floor + 6)
			if not y or math.abs(y - floor) > 1.5 then break end
			d += 2
		end
		return d
	end
	local plus, minus = reach(1), reach(-1)
	if plus + minus >= 8 then -- (keep the zone's own length when the floor can't be read, e.g. no floor yet)
		local mid = Vector3.new(centre.X, floor, centre.Z) + along * ((plus - minus) / 2)
		return mid, out, plus + minus
	end
	return Vector3.new(centre.X, floor, centre.Z), out, length
end

local function markPart(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	return p
end

--[[
	The safe lines: a white line on the floor where each zone meets the field, and a green
	SAFE ZONE sign over the line of the side runners must reach this round (as in the
	reference). Config.Map.SafeLines = false turns them off (for maps with painted lines).
]]
function MapService.showGoal(goalName)
	local z = MapService.zones
	if not (z.ZoneA and z.ZoneB and z.Middle) or Config.Map.SafeLines == false then
		return
	end
	if not (marks and marks.Parent) then
		marks = Instance.new("Folder")
		marks.Name = "HuzzSafeLines"
		for _, name in { "ZoneA", "ZoneB" } do
			local centre, out, length = edge(z[name])
			markPart({
				Name = "SafeLine" .. name, Size = Vector3.new(length, 0.06, Config.Map.LineWidth),
				CFrame = CFrame.lookAt(centre, centre + out) + Vector3.new(0, 0.05, 0),
				Color = Color3.new(1, 1, 1), Parent = marks,
			})
			local signPart = markPart({
				Name = "Sign" .. name, Size = Vector3.new(1, 1, 1), Transparency = 1,
				CFrame = CFrame.new(centre + Vector3.new(0, Config.Map.SignHeight, 0)), Parent = marks,
			})
			local gui = Instance.new("BillboardGui")
			gui.Name = "SafeZone"
			gui.Size = UDim2.new(18, 0, 3.2, 0) -- studs: shrinks with distance like the reference sign
			gui.LightInfluence = 0
			gui.MaxDistance = 600
			gui.Enabled = false
			gui.Parent = signPart
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = "SAFE ZONE"
			label.TextScaled = true
			label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
			label.TextColor3 = Color3.fromRGB(64, 255, 92)
			label.Parent = gui
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 3
			stroke.Color = Color3.fromRGB(10, 60, 20)
			stroke.Parent = label
		end
		marks.Parent = loaded or Workspace
	end
	for _, name in { "ZoneA", "ZoneB" } do
		local sign = marks:FindFirstChild("Sign" .. name)
		if sign then
			sign.SafeZone.Enabled = name == goalName
		end
	end
end

--[[
	Before GO: a see-through wall on the start line keeps runners in their zone (they can still
	walk around in it), and keepIn() puts back anyone who found a way round it.
]]
function MapService.holdStart(startName, on)
	if wall then
		wall:Destroy()
		wall = nil
	end
	local zone = MapService.zones[startName]
	if not (on and zone and MapService.zones.Middle) then
		return
	end
	local centre, out, length = edge(zone)
	local h = Config.Map.WallHeight
	local base = CFrame.lookAt(centre, centre + out) + out * 0.5 -- on the line, x along it
	wall = Instance.new("Folder")
	wall.Name = "HuzzStartWall"
	-- What stops you: tall and invisible, so nobody jumps over it.
	markPart({
		Name = "Block", Size = Vector3.new(length + 2, h, 1), CFrame = base + Vector3.new(0, h / 2, 0),
		CanCollide = true, Transparency = 1, Parent = wall,
	})
	-- What you see: a faint strip of blue glass with a glowing top edge and thin posts.
	local glassH, blue = 5, Color3.fromRGB(120, 200, 255)
	markPart({
		Name = "Glass", Size = Vector3.new(length, glassH, 0.2), CFrame = base + Vector3.new(0, glassH / 2, 0),
		Color = blue, Material = Enum.Material.Glass, Transparency = 0.82, Parent = wall,
	})
	markPart({
		Name = "Edge", Size = Vector3.new(length, 0.18, 0.24), CFrame = base + Vector3.new(0, glassH, 0),
		Color = blue, Material = Enum.Material.Neon, Transparency = 0.25, Parent = wall,
	})
	local posts = math.max(2, math.floor(length / 16) + 1)
	for i = 0, posts - 1 do
		local x = -length / 2 + length * i / (posts - 1)
		markPart({
			Name = "Post", Size = Vector3.new(0.18, glassH, 0.24), CFrame = base * CFrame.new(x, glassH / 2, 0),
			Color = blue, Material = Enum.Material.Neon, Transparency = 0.45, Parent = wall,
		})
	end
	wall.Parent = loaded or Workspace
end

--[[
	The goal's gate (owner: once you're across you stay across, you can't wander back into the middle): a
	thick invisible block on the goal line in the "HuzzSafeWall" collision group, which only collides with the
	"HuzzSafe" group (the parts of runners who are Safe: MapService.setSafe). Runners still running pass straight
	through it. What everyone sees is a very faint green glass strip with a glowing top: the finish line.
]]
local SAFE, SAFE_WALL = "HuzzSafe", "HuzzSafeWall"
pcall(function()
	PhysicsService:RegisterCollisionGroup(SAFE)
	PhysicsService:RegisterCollisionGroup(SAFE_WALL)
end)
local function setUpGroups()
	pcall(function()
		for _, g in PhysicsService:GetRegisteredCollisionGroups() do
			local name = g.name
			if name ~= SAFE and name ~= SAFE_WALL then
				-- a safe runner collides with everything a normal part does; the gate only with safe runners
				PhysicsService:CollisionGroupSetCollidable(SAFE, name, PhysicsService:CollisionGroupsAreCollidable("Default", name))
				PhysicsService:CollisionGroupSetCollidable(SAFE_WALL, name, false)
			end
		end
		PhysicsService:CollisionGroupSetCollidable(SAFE, SAFE, true)
		PhysicsService:CollisionGroupSetCollidable(SAFE_WALL, SAFE_WALL, false)
		PhysicsService:CollisionGroupSetCollidable(SAFE_WALL, SAFE, true)
	end)
end

function MapService.holdGoal(goalName, on)
	if gate then
		gate:Destroy()
		gate = nil
	end
	local zone = goalName and MapService.zones[goalName]
	if not (on and zone and MapService.zones.Middle) then
		return
	end
	setUpGroups() -- (again each round: KnockdownService may have registered its group after us)
	local centre, out, length = edge(zone)
	local h = Config.Map.WallHeight
	local base = CFrame.lookAt(centre, centre + out) + out * 3.5 -- outside the zone with a gap, so a runner's trailing arm
	-- isn't inside it at the moment they turn Safe (a shove)
	gate = Instance.new("Folder")
	gate.Name = "HuzzGoalGate"
	local block = markPart({
		Name = "Block", Size = Vector3.new(length + 2, h, 4), CFrame = base + Vector3.new(0, h / 2, 0),
		CanCollide = true, Transparency = 1, Parent = gate,
	})
	block.CollisionGroup = SAFE_WALL
	local glassH, green = 4, Color3.fromRGB(110, 255, 150)
	local face = CFrame.lookAt(centre, centre + out) + out * 0.3
	markPart({
		Name = "Glass", Size = Vector3.new(length, glassH, 0.15), CFrame = face + Vector3.new(0, glassH / 2, 0),
		Color = green, Material = Enum.Material.Glass, Transparency = 0.9, Parent = gate,
	})
	markPart({
		Name = "Edge", Size = Vector3.new(length, 0.14, 0.2), CFrame = face + Vector3.new(0, glassH, 0),
		Color = green, Material = Enum.Material.Neon, Transparency = 0.45, Parent = gate,
	})
	gate.Parent = loaded or Workspace
end

-- Puts a character's parts in the safe group (true) or back to Default (false). Parts in another group
-- (a knocked-down body's) are left alone.
function MapService.setSafe(character, on)
	if not character then
		return
	end
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			if on and d.CollisionGroup == "Default" then
				d.CollisionGroup = SAFE
			elseif not on and d.CollisionGroup == SAFE then
				d.CollisionGroup = "Default"
			end
		end
	end
end

--[[
	The line-up (Huss Valley): runners stand shoulder to shoulder just behind their safe line, facing
	across. Returns the line's CFrame (on the floor at its middle, looking across the field), its length,
	and `count` spots (CFrames for the root): one row centred on the middle, a second row behind if it's full.
]]
function MapService.lineup(zoneName, count)
	local zone = MapService.zones[zoneName]
	if not (zone and MapService.zones.Middle) then
		return nil, 0, {}
	end
	local centre, out, length = edge(zone)
	local line = CFrame.lookAt(centre, centre + out)
	local gap = Config.Map.LineupGap or 4
	local perRow = math.max(1, math.floor((length - 6) / gap) + 1)
	local spots = {}
	for i = 1, count do
		local row = (i - 1) // perRow
		local inRow = math.min(perRow, count - row * perRow)
		local k = (i - 1) % perRow
		local x = (k - (inRow - 1) / 2) * gap
		local at = line * CFrame.new(x, 0, 2.5 + row * 4) -- (CFrame z points back, away from the field)
		local floor = MapService.ground(at.Position, at.Position.Y + 6) or at.Position.Y
		local pos = Vector3.new(at.Position.X, floor + 3.2, at.Position.Z)
		spots[i] = CFrame.lookAt(pos, pos + out)
	end
	return line, length, spots
end

-- The same point pulled back inside the zone (1.5 studs in from the edges), or nil if already in.
function MapService.keepIn(zone, position)
	if MapService.inZone(zone, position) then
		return nil
	end
	local p = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size * 0.5 - Vector3.new(1.5, 0, 1.5)
	local inside = Vector3.new(math.clamp(p.X, -half.X, half.X), p.Y, math.clamp(p.Z, -half.Z, half.Z))
	return zone.CFrame:PointToWorldSpace(inside)
end

function MapService.goalFor(round)
	return if round % 2 == 1 then "ZoneB" else "ZoneA"
end

function MapService.startFor(round)
	return if round % 2 == 1 then "ZoneA" else "ZoneB"
end

return MapService
