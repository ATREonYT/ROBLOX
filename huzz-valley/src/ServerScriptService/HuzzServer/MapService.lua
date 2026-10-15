--[[
	The owner's maps: found at start, stored away, and the chosen one copied in
	front of the lobby island for each game (the owner's call: the voted map
	"spawns in front of the lobby", where people in the lobby can watch).

	A map is any folder or model in Workspace holding parts named ZoneA, ZoneB
	and Middle (names match loosely: "Zone A" works; optional: Bench), e.g.
	  Workspace > Maps > Halloween_Map > Zone A, Zone B, Middle
	At start every map moves to ReplicatedStorage.HuzzMaps (so clients can show
	it in the vote cards). load(map) copies it in front of the lobby, turned so
	runners cross left to right as seen from the lobby; unload() removes it.
	A part named MapSpot (optional) sets exactly where the map's middle goes
	and which way it runs (its front face points from ZoneA to ZoneB).

	The lobby is a part named Lobby, else the SpawnBaseplate. With no zones at
	all a plain test field is built in place so the game still runs.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Round)

local MapService = {}
MapService.zones = {} -- the loaded map's zones (filled in place, so callers can keep the table)
MapService.maps = {} -- { name, box (stored container), fixed (test field: used where it is) }
MapService.current = nil -- the loaded map's entry
local loaded -- the copy in Workspace
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

-- Where the map's middle goes and which way it runs: MapSpot if there is one, else
-- just in front of the lobby, its run crossing left to right as seen from the lobby.
local function placement(middle, runAxis)
	local spot = MapService.mapSpot
	if spot then
		return spot.CFrame
	end
	local lobby = MapService.lobby
	local mid = middle.CFrame.Position
	if not lobby then
		return CFrame.lookAt(mid, mid + runAxis) -- no lobby: the map stays where it was built
	end
	-- "In front": the side of the lobby that faces where the maps were built.
	local away = Vector3.zero
	for _, m in MapService.maps do
		local p = select(3, zonesOf(m.box, m.name, true))
		if p then
			away += p.CFrame.Position - lobby.Position
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
	local right = front:Cross(Vector3.yAxis).Unit
	-- Distance: the lobby's half-depth + a gap + the map's half-depth (across its run).
	local lobbyLocal = lobby.CFrame:VectorToObjectSpace(front)
	local lobbyHalf = math.abs(lobbyLocal.X) * lobby.Size.X / 2 + math.abs(lobbyLocal.Z) * lobby.Size.Z / 2
	local across = runAxis:Cross(Vector3.yAxis).Unit
	local midLocal = middle.CFrame:VectorToObjectSpace(across)
	local mapHalf = math.abs(midLocal.X) * middle.Size.X / 2 + math.abs(midLocal.Z) * middle.Size.Z / 2
	local centre = lobby.Position + front * (lobbyHalf + Config.Map.Gap + mapHalf)
	centre = Vector3.new(centre.X, mid.Y, centre.Z) -- the map keeps its own height
	return CFrame.lookAt(centre, centre + right)
end

-- Copies a map in front of the lobby and makes it the current map.
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
		model.WorldPivot = CFrame.lookAt(mid, mid + run)
		model:PivotTo(placement(middle, run))
		for _, d in model:GetDescendants() do
			if d:IsA("SpawnLocation") then
				d.Enabled = false -- players respawn in the lobby, not on the map
			end
		end
		model.Parent = Workspace
		loaded = model
	end
	local a, b, middle, bench = zonesOf(model, entry.name, true)
	local z = MapService.zones
	z.ZoneA, z.ZoneB, z.Middle, z.Bench = prepare(a), prepare(b), prepare(middle), prepare(bench)
	MapService.current = entry
	return entry
end

function MapService.unload()
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

function MapService.goalFor(round)
	return if round % 2 == 1 then "ZoneB" else "ZoneA"
end

function MapService.startFor(round)
	return if round % 2 == 1 then "ZoneA" else "ZoneB"
end

return MapService
