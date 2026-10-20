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

	The lobby is a part named Lobby, else his new lobby's plaza in Workspace > StartingPoint (one copy in front of
	each map, Shared/LobbyLayout), else the SpawnBaseplate. With no zones at
	all a plain test field is built in place so the game still runs.
	One lobby (owner, Oct 19: "make one lobby"; he had pasted one copy in front of each map): the copy with nothing
	pasted twice stays (LobbyLayout.main; a floor with the attribute MainLobby = true wins), the other copies go whole
	to ServerStorage > HuzzSpareLobbies, and each map loads in front of the one lobby exactly where it stood in front
	of its own copy (entry.builtBeside), so nobody ever moves between lobbies.

	Where bodies go (owner, Oct 19: "make them spawn not in the middle inside of objects and just make them spawn on
	open ground"; "make barriers around the spawns"; "make catchers spawn in the middle"): every spot is checked with
	Shared/SpawnSpots (floor under the feet, nothing solid or visible in a standing body's box):
	  - the lobby: a spawn pad on his red carpet between the front pads (spawnPad), with a low wooden rail on three
	    sides and an invisible wall behind it that only stops players (Workspace > HuzzSpawnPad, built at start unless
	    the place has one); his SpawnLocation moves onto it; lobbySpot() gives one of its 30 spots;
	  - the start lines: lineup() nudges each spot to open ground behind the line;
	  - catchers: middleSpot(i) = a row across the field's middle line, facing the runners.
	tests/Spawns.spec.luau runs this file on his real place and checks every spot.
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local PhysicsService = game:GetService("PhysicsService")

local Config = require(ReplicatedStorage.Shared.Config.Round)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local SpawnSpots = require(ReplicatedStorage.Shared.SpawnSpots)

local MapService = {}
MapService.zones = {} -- the loaded map's zones (filled in place, so callers can keep the table)
MapService.maps = {} -- { name, box (stored container), fixed (test field: used where it is) }
MapService.current = nil -- the loaded map's entry
MapService.lobbies = {} -- { floor, spawn, pad }: the one lobby (kept a list so older callers still work)
local loaded -- the copy in Workspace
local marks, wall -- the current map's safe lines and sign, and the start-line wall before GO
local gate -- the goal line's gate: only runners already safe bump into it (holdGoal)
local catcherWalls -- both safe zones' walls that only catchers bump into (holdCatchers)
local lastPicked
local zoneParts = {} -- every zone part, so floor checks look through them
local field -- the loaded map's walled field { frame, lo, hi, floor } (boundary), for putting fallers back
local middleSpots -- the loaded map's catcher spots (MapService.middleSpots), made once per map
local edge -- (a zone's edge facing the middle: defined further down)

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

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- An invisible spawn on top of a lobby floor that has none.
local function makeSpawn(floor: BasePart): SpawnLocation
	local s = Instance.new("SpawnLocation")
	s.Name = "HuzzLobbySpawn"
	s.Anchored, s.CanCollide, s.Transparency, s.Neutral, s.Duration = true, false, 1, true, 0
	s.Size = Vector3.new(12, 1, 12)
	s.CFrame = CFrame.new(floor.CFrame.Position + Vector3.new(0, floor.Size.Y / 2 + 0.6, 0))
	s.Parent = Workspace
	return s
end

local activeLobby -- the MapService.lobbies record in use

local function useLobby(rec)
	activeLobby = rec
	MapService.lobby = rec and rec.floor
	MapService.zones.Lobby = MapService.lobby
	if #MapService.lobbies > 1 then
		for _, r in MapService.lobbies do
			if r.spawn then r.spawn.Enabled = r == rec end
		end
	end
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
	-- Loose parts lying on a map's floor belong to that map (owner: "fix the trail being there whilst the map is
	-- not even there": the path he laid across the Halloween field sits loose in Workspace, so with another map on
	-- it floated over the sea). Each loose part (or loose model) resting on one of a map's parts moves into that
	-- map before the maps are put away; the rest of the path, on the lobby island, stays where it is.
	local function bounds(part: BasePart)
		local cf, s = part.CFrame, part.Size
		local function e(axis)
			return math.abs(cf.RightVector[axis]) * s.X / 2 + math.abs(cf.UpVector[axis]) * s.Y / 2 + math.abs(cf.LookVector[axis]) * s.Z / 2
		end
		local p = cf.Position
		return Vector3.new(p.X - e("X"), p.Y - e("Y"), p.Z - e("Z")), Vector3.new(p.X + e("X"), p.Y + e("Y"), p.Z + e("Z"))
	end
	local mapParts = {}
	for _, box in boxes do
		local list = {}
		for _, d in box:GetDescendants() do
			if d:IsA("BasePart") and d.CanCollide then
				local lo, hi = bounds(d)
				table.insert(list, { lo = lo, hi = hi })
			end
		end
		mapParts[box] = list
	end
	local function restsOn(lo: Vector3, hi: Vector3)
		local x, z = (lo.X + hi.X) / 2, (lo.Z + hi.Z) / 2
		for box, list in mapParts do
			for _, b in list do
				if x >= b.lo.X and x <= b.hi.X and z >= b.lo.Z and z <= b.hi.Z and b.hi.Y >= lo.Y - 1.5 and b.hi.Y <= lo.Y + 0.5 then
					return box
				end
			end
		end
		return nil
	end
	for _, item in Workspace:GetChildren() do
		local box
		local k = key(item.Name)
		if k == key(C.Lobby) or k == "spawnbaseplate" or k == "mapspot" or k == key(LobbyLayout.FOLDER) or select(2, pcall(CollectionService.HasTag, CollectionService, item, "HuzzLobby")) == true then
			box = nil -- (a lobby's own floor never moves into a map)
		elseif item:IsA("BasePart") and not item:IsA("Terrain") and not item:IsA("SpawnLocation") then
			box = restsOn(bounds(item))
		elseif item:IsA("Model") and not item:FindFirstChildOfClass("Humanoid") then
			local ok, cf, size = pcall(function() return item:GetBoundingBox() end)
			if ok and cf then
				box = restsOn(cf.Position - size / 2, cf.Position + size / 2)
			end
		end
		if box then
			item.Parent = box
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

	-- The lobby (Shared/LobbyLayout): parts tagged HuzzLobby, else parts named Lobby, else the plaza of his new lobby
	-- in Workspace > StartingPoint, else the SpawnBaseplates (his old islands, now unused in Maps > Spawn).
	-- ONE lobby (owner, Oct 19: "make one lobby"): his lobby is pasted in front of each map; the copy with no parts
	-- pasted twice is kept (LobbyLayout.main) and the others go to ServerStorage > HuzzSpareLobbies, untouched.
	-- Each map then loads in front of the one lobby exactly where it stood in front of its own copy (placement).
	local spot = nil
	for _, d in Workspace:GetDescendants() do
		if d:IsA("BasePart") and key(d.Name) == "mapspot" then
			spot = spot or d
		end
	end
	MapService.mapSpot = spot
	local floors = LobbyLayout.floors(Workspace)
	local main = LobbyLayout.main(Workspace)
	-- Each map remembers the copy it was built in front of (its nearest), so it keeps that place beside the lobby.
	-- (copies the place build already put away count too: the download opens with one lobby in Workspace)
	local copies = table.clone(floors)
	for _, f in LobbyLayout.spareFloors(game:GetService("ServerStorage")) do table.insert(copies, f) end
	for _, entry in MapService.maps do
		local middle = select(3, zonesOf(entry.box, entry.name, true))
		local best, bestDist = nil, math.huge
		for _, f in copies do
			local d = middle and flat(f.CFrame.Position - middle.CFrame.Position).Magnitude or 0
			if d < bestDist then best, bestDist = f, d end
		end
		-- (only a map built beside a copy, as his are, 160-170 studs off; one built anywhere else keeps the old rule)
		entry.builtBeside = if best and bestDist < 400 then best.CFrame else nil
	end
	local okAway, err = pcall(LobbyLayout.putAwaySpares, { Instance = Instance, Vector3 = Vector3, CFrame = CFrame }, Workspace, game:GetService("ServerStorage"))
	if not okAway then warn("[Huzz] Couldn't put the spare lobby copies away: " .. tostring(err)) end
	MapService.lobbies = {}
	if main then
		table.insert(MapService.lobbies, { floor = main })
	end
	for _, entry in MapService.maps do
		entry.lobby = MapService.lobbies[1]
	end
	-- The lobby's own SpawnLocation (the one on it, else one made), moved onto the spawn pad (MapService.spawnPad).
	if main then
		local rec = MapService.lobbies[1]
		local reach = math.max(main.Size.X, main.Size.Z) / 2 + 30
		local best, bestDist = nil, reach
		for _, d in Workspace:GetDescendants() do
			if d:IsA("SpawnLocation") then
				local dist = flat(d.CFrame.Position - main.CFrame.Position).Magnitude
				if dist < bestDist then best, bestDist = d, dist end
			end
		end
		rec.spawn = best or makeSpawn(main)
		local okPad, padErr = pcall(MapService.spawnPad, rec)
		if not okPad then warn("[Huzz] Spawn pad: " .. tostring(padErr)) end
	end
	useLobby(MapService.lobbies[1])
	task.spawn(MapService.catchFalls)
end

-- One lobby: every map's lobby is the same one, so nobody ever moves between lobbies (kept so RoundService can ask).
function MapService.useLobbyFor(entry): boolean
	local rec = entry and entry.lobby
	if not rec or rec.floor == MapService.lobby then return false end
	useLobby(rec)
	return true
end

-- Where players stand in the lobby: the middle of its spawn pad, else its spawn, else the top of its floor.
function MapService.lobbySpawn(): Vector3?
	local pad = activeLobby and activeLobby.pad
	if pad then return pad.centre + Vector3.new(0, SpawnSpots.RootHeight, 0) end
	local spawn = activeLobby and activeLobby.spawn
	if spawn and spawn.Parent then return spawn.CFrame.Position end
	local lobby = MapService.lobby
	return if lobby then lobby.CFrame.Position + Vector3.new(0, lobby.Size.Y / 2, 0) else nil
end

--[[
	The world as Shared/SpawnSpots reads it in the game: a ray down for the floor (only things you can stand on), and
	Roblox's box test (every part's bounding box, as the offline check does) for "is anything here". Never counted:
	players, bots, girls, effects, zone markers, and our invisible walls (CanQuery off, or a collision group of
	their own). tools/world/geometry.luau is the same thing for Lune.
]]
local ignoreCache, ignoreAt = nil, -math.huge
local function ignoreList()
	-- (one list for a whole burst of checks: a line-up asks thousands of times in the same moment)
	if ignoreCache and os.clock() - ignoreAt < 0.25 then return ignoreCache end
	local list = table.clone(zoneParts)
	for _, ours in { marks, wall, gate, catcherWalls } do -- (the lines, the start wall and the safe zones' walls)
		if ours then table.insert(list, ours) end
	end
	for _, name in { "HuzzCarried", "HuzzFollowers", "HuzzAuraFX", "HuzzCompanions" } do
		local f = Workspace:FindFirstChild(name)
		if f then table.insert(list, f) end
	end
	for _, p in game:GetService("Players"):GetPlayers() do
		if p.Character then table.insert(list, p.Character) end
	end
	local ok, bots = pcall(CollectionService.GetTagged, CollectionService, "HuzzBot")
	for _, m in if ok then bots else {} do table.insert(list, m) end
	ignoreCache, ignoreAt = list, os.clock()
	return list
end
MapService.geometry = {
	floor = function(x: number, z: number, top: number, bottom: number): number?
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignoreList()
		pcall(function() params.RespectCanCollide = true end)
		local hit = Workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, bottom - top, 0), params)
		return hit and hit.Position.Y
	end,
	blocked = function(centre: Vector3, size: Vector3, solidOnly: boolean): boolean
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignoreList()
		for _, p in Workspace:GetPartBoundsInBox(CFrame.new(centre), size, params) do
			if not p:IsA("Terrain") then
				local solid = p.CanCollide and (p.CollisionGroup == "Default" or p.CollisionGroup == "")
				if solid or (not solidOnly and p.Transparency < 0.9) then return true end
			end
		end
		return false
	end,
}

-- A root CFrame standing on a floor spot, facing `at` (level).
local function facing(pos: Vector3, at: Vector3?): CFrame
	local root = pos + Vector3.new(0, SpawnSpots.RootHeight, 0)
	if at then
		local flatAt = Vector3.new(at.X, root.Y, at.Z)
		if (flatAt - root).Magnitude > 0.1 then return CFrame.lookAt(root, flatAt) end
	end
	return CFrame.new(root)
end
MapService.facing = facing

--[[
	The lobby's spawn pad (owner, Oct 19: "fix the spawn point locations, and make barriers around the spawns, and make
	them spawn not in the middle inside of objects and just make them spawn on open ground"). Everyone who joins,
	respawns or comes back from a game stands on it: open ground at the front of his plaza (the red carpet between
	his two groups of round pads, LobbyLayout.spawnPad), facing into the lobby, the girls' display ahead of them,
	the podium boards on one side and the Game Pass stands on the other.
	  - The pad is PAD_WIDTH x PAD_DEPTH studs with nothing at all in it (checked here; moved along the carpet and a
	    little inwards until it is, never onto his props); 12 spots in it, 4 apart (Shared/SpawnSpots: floor, body,
	    room), and more open spots beyond its open side for a full server.
	  - Barriers (OFF since Oct 19, owner: "please remove that barrier in the lobby"; MapService.RAIL): a low wooden rail on three sides (his display fence's brown, as wood, 2.4 studs tall, posts about
	    3.4 apart), open on the side facing into the plaza; an invisible wall 7 studs tall along each rail so nobody
	    steps over it or is pushed off the plaza's front edge while a crowd spawns. It never blocks a camera or a ray
	    (CanQuery off). Built when the game starts, so it shows in Play, not in Studio's edit view; a place that
	    already has a Workspace > HuzzSpawnPad (e.g. one he copied out of a Play test and moved) keeps its own.
	  - His SpawnLocation moves onto the pad, so Roblox drops new players there too.
]]
local PAD_WIDTH, PAD_DEPTH = 20, 18
MapService.RAIL = false -- (the rail and its invisible walls: removed by the owner, Oct 19)
MapService.PAD_WIDTH, MapService.PAD_DEPTH = PAD_WIDTH, PAD_DEPTH
function MapService.spawnPad(rec)
	ignoreCache = nil -- (a fresh look at the world for this burst of checks)
	local floor = rec.floor
	local plan = LobbyLayout.spawnPad({ Instance = Instance, Vector3 = Vector3, CFrame = CFrame }, Workspace, floor)
	local geo = MapService.geometry
	local inward, across = plan.inward, plan.across
	local top = plan.centre.Y
	local function padOpen(c: Vector3): boolean
		local box = Vector3.new(math.abs(across.X) * PAD_WIDTH + math.abs(inward.X) * PAD_DEPTH, 5.4,
			math.abs(across.Z) * PAD_WIDTH + math.abs(inward.Z) * PAD_DEPTH)
		if geo.blocked(c + Vector3.new(0, SpawnSpots.Lift + 2.7, 0), box, false) then return false end
		for _, o in { { 0, 0 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			local p = c + across * (o[1] * PAD_WIDTH / 2) + inward * (o[2] * PAD_DEPTH / 2)
			local y = geo.floor(p.X, p.Z, top + 3, top - 3)
			if not y or math.abs(y - top) > SpawnSpots.MaxStep then return false end
		end
		return true
	end
	-- the planned spot, else along the carpet and a little inwards (never more than 10 studs)
	local centre = nil
	for _, d in { 0, 2, -2, 4, -4, 6, -6 } do
		for _, k in { 0, 2, 4, 6, 8, 10 } do
			local c = plan.centre + across * d + inward * k
			if padOpen(c) then
				centre = c
				break
			end
		end
		if centre then break end
	end
	local found = centre ~= nil
	centre = centre or plan.centre
	centre = Vector3.new(centre.X, geo.floor(centre.X, centre.Z, top + 3, top - 3) or top, centre.Z) -- (on his carpet)
	local pad = { centre = centre, inward = inward, across = across, open = found }
	rec.pad = pad
	-- the rail (unless the place has its own). Off since the owner's Oct 19 screenshot: "please remove that barrier
	-- in the lobby"; MapService.RAIL = true brings it back.
	local rail = Workspace:FindFirstChild("HuzzSpawnPad")
	if not rail and MapService.RAIL then
		rail = MapService.buildRail(centre, inward, across, function(x, z) return geo.floor(x, z, top + 3, top - 3) end)
		rail.Parent = Workspace
	end
	pad.rail = rail
	-- his SpawnLocation onto the pad
	if rec.spawn then
		local at = centre + Vector3.new(0, 0.6, 0)
		rec.spawn.CFrame = CFrame.lookAt(at, at + inward)
	end
	-- the spots: 3 across x 4 deep in the pad, then on beyond its open side
	local wanted = {}
	for row = 0, 9 do
		for _, col in { 0, -1, 1 } do
			local p = centre + inward * (-6 + row * 4) + across * (col * 4)
			table.insert(wanted, { p.X, p.Z })
		end
	end
	pad.spots = SpawnSpots.fill(geo, wanted, top, 30, 3.5, 2)
	pad.lookAt = centre + inward * 40
	return pad
end

-- The rail round the spawn pad (see spawnPad). floorAt(x, z) -> y? (optional): each post stands on what is under it.
function MapService.buildRail(centre: Vector3, inward: Vector3, across: Vector3, floorAt: ((number, number) -> number?)?): Folder
	local folder = Instance.new("Folder")
	folder.Name = "HuzzSpawnPad"
	local wood = Color3.fromRGB(106, 57, 9) -- (his display fence's colour)
	-- x = across, z = towards the plaza's front edge (away from where people walk in)
	local frame = CFrame.fromMatrix(centre, across, Vector3.yAxis, -inward)
	local function piece(name, cf, size, visible)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored, p.CastShadow, p.CanTouch = true, visible, false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Size = size
		p.CFrame = cf
		if visible then
			p.Color, p.Material, p.CanCollide = wood, Enum.Material.Wood, false
		else
			p.Transparency, p.CanCollide, p.CanQuery = 1, true, false
		end
		p.Parent = folder
		return p
	end
	local hw, hd = PAD_WIDTH / 2 + 0.4, PAD_DEPTH / 2 + 0.4
	-- three sides: left, front (the plaza's edge), right; the side into the plaza stays open
	local sides = {
		{ Vector3.new(-hw, 0, -hd), Vector3.new(-hw, 0, hd) },
		{ Vector3.new(-hw, 0, hd), Vector3.new(hw, 0, hd) },
		{ Vector3.new(hw, 0, hd), Vector3.new(hw, 0, -hd) },
	}
	for i, s in sides do
		local a, b = s[1], s[2]
		local len = (b - a).Magnitude
		local dir = (b - a).Unit
		local posts = math.max(2, math.round(len / 3.4) + 1)
		for k = 0, posts - 1 do
			local q = a + dir * (len * k / (posts - 1))
			local w = frame * q
			local lift = if floorAt then (floorAt(w.X, w.Z) or centre.Y) - centre.Y else 0
			piece("Post", frame * CFrame.new(q + Vector3.new(0, lift + 1.2, 0)), Vector3.new(0.7, 2.4, 0.7), true)
		end
		local mid = (a + b) / 2
		local function along(y)
			local m = mid + Vector3.new(0, y, 0)
			return frame * CFrame.lookAt(m, m + dir)
		end
		piece("Rail", along(2.05), Vector3.new(0.35, 0.35, len), true)
		piece("Rail", along(1.0), Vector3.new(0.25, 0.25, len), true)
		piece("Barrier" .. i, along(3.5), Vector3.new(0.6, 7, len + 0.6), false)
	end
	return folder
end

-- A spot in the lobby for a player (the spawn pad's spots, a free one first), as a root CFrame facing the plaza.
function MapService.lobbySpot(): CFrame?
	local pad = activeLobby and activeLobby.pad
	if not (pad and pad.spots and #pad.spots > 0) then return nil end
	local taken = {}
	for _, p in game:GetService("Players"):GetPlayers() do
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if r and r:IsA("BasePart") then table.insert(taken, r.Position) end
	end
	local free = {}
	for _, s in pad.spots do
		local ok = true
		for _, q in taken do
			if (Vector3.new(q.X, 0, q.Z) - Vector3.new(s.X, 0, s.Z)).Magnitude < 2.5 then
				ok = false
				break
			end
		end
		if ok then table.insert(free, s) end
	end
	local list = if #free > 0 then free else pad.spots
	-- (the pad's own spots come first in the list: a random one of the first few, so a crowd fills it evenly)
	local s = list[math.random(1, math.min(#list, 6))]
	return facing(s, pad.lookAt)
end

-- The middle of the loaded field: halfway between the two safe lines, in the middle across; and the run's way.
function MapService.fieldMiddle(): (Vector3?, Vector3?)
	local a, b = MapService.zones.ZoneA, MapService.zones.ZoneB
	if not (a and b and MapService.zones.Middle) then return nil, nil end
	local ca, cb = edge(a), edge(b)
	local mid = (ca + cb) / 2
	local run = Vector3.new(cb.X - ca.X, 0, cb.Z - ca.Z)
	return mid, if run.Magnitude > 0.1 then run.Unit else Vector3.zAxis
end

--[[
	Catchers start in the middle (owner, Oct 19: "make catchers spawn in the middle"): a row across the field on the
	line halfway between the safe lines, 5 studs apart, the first one dead centre, then rows 4 studs either side;
	every spot open ground (Shared/SpawnSpots) inside the walls and outside both safe zones, facing the start line
	the runners stand on. Worked out once per map (MapService.load clears it).
]]
function MapService.middleSpots(): { Vector3 }
	if middleSpots then return middleSpots end
	ignoreCache = nil
	local mid, run = MapService.fieldMiddle()
	if not (mid and run) then return {} end
	local side = run:Cross(Vector3.yAxis).Unit
	local wanted = {}
	for _, row in { 0, -4, 4, -8, 8 } do
		for _, k in { 0, 1, -1, 2, -2, 3, -3, 4, -4 } do
			local p = mid + side * (k * 5) + run * row
			table.insert(wanted, { p.X, p.Z })
		end
	end
	local keep = function(x, z)
		local p = Vector3.new(x, mid.Y + 1, z)
		local a, b = MapService.zones.ZoneA, MapService.zones.ZoneB
		if (a and MapService.inZone(a, p)) or (b and MapService.inZone(b, p)) then return false end
		if field then
			local l = field.frame:PointToObjectSpace(p)
			if l.X < field.lo.X + 3 or l.X > field.hi.X - 3 or l.Z < field.lo.Z + 3 or l.Z > field.hi.Z - 3 then return false end
		end
		return true
	end
	middleSpots = SpawnSpots.fill(MapService.geometry, wanted, if field then field.floor else mid.Y, 24, 4, 2.5, keep)
	return middleSpots
end

-- Catcher number `index`'s spot in the middle, facing the runners' start zone (startName).
function MapService.middleSpot(index: number, startName: string?): CFrame?
	local start = startName and MapService.zones[startName]
	local look = start and start.CFrame.Position or nil
	local list = MapService.middleSpots()
	local s = list[((index - 1) % math.max(#list, 1)) + 1]
	if not s then
		local middle = MapService.zones.Middle
		return middle and MapService.spot(middle, look, Config.Map.MiddleSpawn)
	end
	return facing(s, look)
end

-- A spot on the bench (or nil without one): open ground nearest a random point along its middle.
function MapService.benchSpot(lookAt: Vector3?): CFrame?
	local bench = MapService.zones.Bench
	if not bench then return nil end
	local top = bench.CFrame.Position + Vector3.new(0, bench.Size.Y / 2, 0)
	local floorY = MapService.ground(top, top.Y + 2) or top.Y
	local c = bench.CFrame:PointToWorldSpace(Vector3.new((math.random() * 2 - 1) * math.max(bench.Size.X / 2 - 3, 0) * 0.5, 0, 0))
	local s = SpawnSpots.near(MapService.geometry, c.X, c.Z, floorY, 10, 1)
	return if s then facing(s, lookAt) else MapService.spot(bench, lookAt)
end

--[[
	The safety net under the walls (owner: "so people can't fall down"): anyone who still drops off the field
	(a gap in a map's floor, a glitch through a wall) is put straight back on it at the nearest point inside the
	walls, a moment later; anyone falling far below the lobby goes back to the lobby spawn.
]]
-- The floor runners stand on in a map: the visible part found most often right under a 5 x 5 grid of points across
-- its field (ZoneA to ZoneB; a single point can land on a court line or a path). Read from the stored copy, so it
-- works before the map is in the world. The part, or nil.
local function floorPart(box: Instance): BasePart?
	local a, b, middle = zonesOf(box, "", true)
	if not (a and b and middle) then return nil end
	local pa, pb, y = a.CFrame.Position, b.CFrame.Position, middle.CFrame.Position.Y
	local reach = y + middle.Size.Y / 2 + 2 -- floors up to just over the Middle box's top (Halloween's grass pokes out)
	local run = Vector3.new(pb.X - pa.X, 0, pb.Z - pa.Z)
	if run.Magnitude < 1 then return nil end
	local side = run:Cross(Vector3.yAxis).Unit
	local parts = {}
	for _, p in box:GetDescendants() do
		if p:IsA("BasePart") and p ~= a and p ~= b and p ~= middle and p.Transparency < 0.9 then table.insert(parts, p) end
	end
	local votes = {}
	for i = 0, 4 do
		for j = -2, 2 do
			local pt = Vector3.new(pa.X, y, pa.Z) + run * (0.1 + i * 0.2) + side * (j * middle.Size.Z * 0.18)
			local best, bestTop
			for _, p in parts do
				local l = p.CFrame:PointToObjectSpace(pt)
				local top = p.CFrame.Position.Y + p.Size.Y / 2
				if math.abs(l.X) <= p.Size.X / 2 and math.abs(l.Z) <= p.Size.Z / 2 and top <= reach and (not bestTop or top > bestTop) then
					best, bestTop = p, top
				end
			end
			if best then votes[best] = (votes[best] or 0) + 1 end
		end
	end
	local top, n = nil, 0
	for p, c in votes do
		if c > n then top, n = p, c end
	end
	return top
end

--[[
	The lobby floor takes on the chosen map's floor (owner: "when a map gets selected make the ground floor the same
	as the map's, for example the Halloween one, make it the same orange"): its colour fades over a second, its
	material switches, and the map floor's textures (the Halloween grass is orange from its Texture) are copied on,
	with the lobby's own textures hidden meanwhile. Called when the vote picks a map (MapVoteService) and when a map
	loads.
]]
function MapService.paintLobby(mapName: string)
	local entry = MapService.byName(mapName)
	local lobby = MapService.lobby
	-- Only the lobby in use: a map with its own lobby is painted when it loads, once everyone has moved there
	-- and can watch the fade.
	if not (entry and lobby) or (entry.lobby and entry.lobby.floor ~= lobby) then return end
	local floor = floorPart(entry.box)
	if not floor then return end
	lobby.Material = floor.Material
	pcall(function() lobby.MaterialVariant = floor.MaterialVariant end)
	game:GetService("TweenService"):Create(lobby, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Color = floor.Color }):Play()
	for _, c in lobby:GetChildren() do
		if c:GetAttribute("HuzzMapLook") then
			c:Destroy()
		elseif c:IsA("Decal") then -- (Texture is a Decal too) the lobby's own: hidden while a map's look is on
			if c:GetAttribute("HuzzOwnTransparency") == nil then c:SetAttribute("HuzzOwnTransparency", c.Transparency) end
			c.Transparency = 1
		end
	end
	for _, c in floor:GetChildren() do
		if c:IsA("Decal") then
			local copy = c:Clone()
			copy:SetAttribute("HuzzMapLook", true)
			copy.Parent = lobby
		end
	end
end

-- A random spot on the floor of the loaded map's crossing area (the Middle, between the safe zones), at least
-- inset studs inside it and inside the invisible walls (Aura stars), or nil. No walled field, no spot.
function MapService.playSpot(inset: number): Vector3?
	local middle, a, b = MapService.zones.Middle, MapService.zones.ZoneA, MapService.zones.ZoneB
	if not (middle and field) then return nil end
	local lo, hi = field.lo, field.hi
	local half = middle.Size / 2
	for _ = 1, 10 do
		local x = (math.random() * 2 - 1) * math.max(half.X - inset, 0)
		local z = (math.random() * 2 - 1) * math.max(half.Z - inset, 0)
		local w = middle.CFrame:PointToWorldSpace(Vector3.new(x, 0, z))
		local f = field.frame:PointToObjectSpace(w)
		local inWalls = f.X > lo.X + inset and f.X < hi.X - inset and f.Z > lo.Z + inset and f.Z < hi.Z - inset
		local inSafe = (a and MapService.inZone(a, w)) or (b and MapService.inZone(b, w))
		local y = inWalls and not inSafe and MapService.ground(Vector3.new(w.X, middle.Position.Y, w.Z), middle.Position.Y + half.Y + 4)
		if y and math.abs(y - field.floor) < 2 then return Vector3.new(w.X, y, w.Z) end
	end
	return nil
end

-- A random spot on the loaded map's field floor, at least inset studs inside its walls, or nil.
function MapService.fieldSpot(inset: number): Vector3?
	if not field then return nil end
	local lo, hi = field.lo, field.hi
	for _ = 1, 8 do
		local x = lo.X + inset + math.random() * math.max(hi.X - lo.X - 2 * inset, 0)
		local z = lo.Z + inset + math.random() * math.max(hi.Z - lo.Z - 2 * inset, 0)
		local w = field.frame:PointToWorldSpace(Vector3.new(x, 0, z))
		local y = MapService.ground(Vector3.new(w.X, field.floor, w.Z), field.floor + 6)
		if y and math.abs(y - field.floor) < 2 then return Vector3.new(w.X, y, w.Z) end
	end
	return nil
end

-- A point and a flat direction in the walled field's own frame (x along the run, z across) with the walls' inner box
-- corners lo/hi, or nil when no map is loaded. KnockdownService stops a catch's slide short of the invisible walls
-- (Shared/DownMotion.fieldSlide): they can't be hit by a ray (CanQuery off).
function MapService.fieldLocal(position: Vector3, dir: Vector3)
	if not field then return nil end
	local l = field.frame:PointToObjectSpace(position)
	local d = field.frame:VectorToObjectSpace(dir)
	return l.X, l.Z, d.X, d.Z, field.lo, field.hi
end

local MARGIN = 8 -- studs past the walls that still count as the field (less than Config.Map.Gap to the lobby)

local function catchOne(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then return end
	local pos = root.Position
	local back
	if field then
		local l = field.frame:PointToObjectSpace(pos)
		local over = l.X > field.lo.X - MARGIN and l.X < field.hi.X + MARGIN and l.Z > field.lo.Z - MARGIN and l.Z < field.hi.Z + MARGIN
		if over and pos.Y < field.floor - 12 then
			local x = math.clamp(l.X, field.lo.X + 4, field.hi.X - 4)
			local z = math.clamp(l.Z, field.lo.Z + 4, field.hi.Z - 4)
			local w = field.frame:PointToWorldSpace(Vector3.new(x, 0, z))
			back = Vector3.new(w.X, field.floor + 3.5, w.Z)
		end
	end
	local lobby = MapService.lobby
	if not back and lobby and pos.Y < lobby.Position.Y - 60 then
		back = MapService.lobbySpawn() + Vector3.new(0, 4, 0)
	end
	if back then
		-- (their own screen moves them, HuzzServer/PlaceService; required here, not at the top: the offline map tools
		-- load this file on its own)
		local okP, PlaceService = pcall(require, script.Parent.PlaceService)
		if okP and type(PlaceService) == "table" then
			if not PlaceService.pending(player) then PlaceService.place(player, CFrame.new(back) * root.CFrame.Rotation, "fall net") end
		else
			root.AssemblyLinearVelocity = Vector3.zero
			character:PivotTo(CFrame.new(back) * root.CFrame.Rotation)
		end
	end
end

function MapService.catchFalls()
	local Players = game:GetService("Players")
	while true do
		task.wait(0.25)
		for _, player in Players:GetPlayers() do
			pcall(catchOne, player) -- (one odd character can't stop the net for everyone)
		end
	end
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

-- The lowest bottom of the visible parts in a folder or model (zones and markers don't count); with near, only
-- the parts over or close to that part (one lobby island in a folder holding several).
local function lowest(container, near: BasePart?)
	local low = math.huge
	local reach = near and math.max(near.Size.X, near.Size.Z) / 2 + 40
	for _, d in container:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1
			and not (near and reach and flat(d.CFrame.Position - near.CFrame.Position).Magnitude > reach) then
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

-- How far a map built floating higher than its lobby island's ground comes down to stand on it (owner: the
-- basketball map floated); one built lower keeps its height.
local function dropFor(model, lobby)
	if not model then return 0 end
	local island = if lobby.Parent and lobby.Parent ~= Workspace then lobby.Parent else lobby
	local mapLow, groundLow = lowest(model), math.min(lowest(island, lobby), lobby.CFrame.Position.Y - lobby.Size.Y / 2)
	if mapLow < math.huge and groundLow < math.huge and mapLow > groundLow then
		return mapLow - groundLow
	end
	return 0
end

-- Where the map's middle goes: MapSpot if there is one; a map built in front of a copy of his lobby (each of his
-- maps: floors level with it) goes in front of the one lobby exactly as it stood in front of that copy (same
-- distance, height and turn: built beside the kept copy = right where it was built); else just in front of the
-- lobby, turned so its open side (see openSide) faces it, and lowered to its ground (dropFor).
local function placement(middle, open, model, entry)
	local spot = MapService.mapSpot
	if spot then
		return spot.CFrame
	end
	local lobby = MapService.lobby
	local mid = middle.CFrame.Position
	if not lobby then
		return CFrame.lookAt(mid, mid + open) -- no lobby: the map stays where it was built
	end
	if entry and entry.builtBeside then
		return lobby.CFrame * entry.builtBeside:Inverse() * CFrame.lookAt(mid, mid + open)
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
	centre = Vector3.new(centre.X, mid.Y - dropFor(model, lobby), centre.Z)
	return CFrame.lookAt(centre, centre - front) -- the open side looks back at the lobby
end

-- Invisible walls round the field (ZoneA, Middle and ZoneB), so nobody jumps or falls off the map. They stand at
-- the floor's real edge (inside the zone boxes when those overhang the floor).
local boundsOn = false -- (MapService.setBounds)
local function boundary(model, a, b, middle)
	for _, zone in { a, b, middle } do -- (the floor checks look through the zone boxes)
		if not table.find(zoneParts, zone) then table.insert(zoneParts, zone) end
	end
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
	local floorY = MapService.ground(mid, mid.Y + middle.Size.Y / 2 + 6) or (mid.Y + lo.Y)
	local height = Config.Map.BoundsHeight
	local y = floorY - mid.Y - 2 + height / 2
	local folder = Instance.new("Folder")
	folder.Name = "HuzzBounds"
	-- The zone boxes can be bigger than the floor (owner: people fell off past the walls): bring each side in to
	-- where the floor really ends, read along three lanes (the nearest edge wins, so no lane is left open).
	local function floorAt(x, z, level)
		local w = frame:PointToWorldSpace(Vector3.new(x, 0, z))
		local gy, on = MapService.ground(Vector3.new(w.X, floorY, w.Z), floorY + 6)
		if level then -- (past the zone boxes only the map's own level floor counts: a fence, a lobby or ground beside it ends it)
			return gy ~= nil and math.abs(gy - floorY) <= 1.5 and on ~= nil and on:IsDescendantOf(model)
		end
		return gy ~= nil and gy >= floorY - 1.5 -- (a prop or a raised pad is still floor: only a hole or a drop ends it)
	end
	-- limit: the zone boxes' own edge; reading may go past it (to) where the floor goes on level.
	local function reach(axis, dir, from, to, lanes, limit)
		local best = to
		for _, lane in lanes do
			local last, found = from, false
			local v = from
			while (to - v) * dir > 0 do
				local nextV = v + 2 * dir
				if (to - nextV) * dir < 0 then nextV = to end
				local level = (nextV - limit) * dir > 0
				local ok = if axis == "x" then floorAt(nextV, lane, level) else floorAt(lane, nextV, level)
				if not ok then break end
				last, found, v = nextV, true, nextV
			end
			if found and (last - best) * dir < 0 then best = last end
		end
		return best
	end
	do
		local cx, cz = (hi.X + lo.X) / 2, (hi.Z + lo.Z) / 2
		local lanesZ = { cz, lo.Z + (hi.Z - lo.Z) * 0.2, lo.Z + (hi.Z - lo.Z) * 0.8 }
		local lanesX = { cx, lo.X + (hi.X - lo.X) * 0.2, lo.X + (hi.X - lo.X) * 0.8 }
		-- Across the run the floor may also go on past the zone boxes (owner, Halloween: "you cant go past the green
		-- line ... its still part of the map": its zones sit 15 studs off the floor's middle). Read up to 40 studs
		-- further, then fit the zones to the floor, so the walls, safe lines, lineup and the girl over the middle
		-- all follow the real field.
		local extra = 40
		local nlo = Vector3.new(reach("x", -1, cx, lo.X, lanesZ, lo.X), lo.Y, reach("z", -1, cz, lo.Z - extra, lanesX, lo.Z))
		local nhi = Vector3.new(reach("x", 1, cx, hi.X, lanesZ, hi.X), hi.Y, reach("z", 1, cz, hi.Z + extra, lanesX, hi.Z))
		-- (only when the floor was read on both sides and leaves a real field)
		if nhi.X - nlo.X > 20 and nhi.Z - nlo.Z > 10 then
			lo, hi = nlo, nhi
			for _, zone in { a, b, middle } do
				local r, l = math.abs(zone.CFrame.RightVector:Dot(side)), math.abs(zone.CFrame.LookVector:Dot(side))
				if math.max(r, l) > 0.99 then -- (a box turned to the run: stretch it across to the floor's edges)
					local p = frame:PointToObjectSpace(zone.CFrame.Position)
					local width = hi.Z - lo.Z
					zone.Size = if r > l then Vector3.new(width, zone.Size.Y, zone.Size.Z) else Vector3.new(zone.Size.X, zone.Size.Y, width)
					zone.CFrame = zone.CFrame.Rotation + frame:PointToWorldSpace(Vector3.new(p.X, p.Y, (lo.Z + hi.Z) / 2))
				end
			end
		end
	end
	field = { frame = frame, lo = lo, hi = hi, floor = floorY }
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
		-- (solid only while a game runs: MapService.setBounds; between games anyone can walk in from the lobby)
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, boundsOn, false, false, false
		p.Transparency = 1
		p.Size = w[2]
		p.CFrame = frame * w[1]
		p.Parent = folder
	end
	folder.Parent = model
end

-- The invisible walls round the field stand only while a game runs: they keep the players in and everyone else out.
-- Between games they're open, so people can walk from the lobby onto the map (owner: "on the side next to the lobby,
-- there is an invisible block that doesn't allow you to walk through it").
function MapService.setBounds(on: boolean)
	boundsOn = on
	local folder = loaded and loaded:FindFirstChild("HuzzBounds")
	if folder then
		for _, w in folder:GetChildren() do
			if w:IsA("BasePart") then w.CanCollide = on end
		end
	end
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
		model:PivotTo(placement(middle, open, model, entry))
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
	if not entry.fixed then pcall(MapService.paintLobby, entry.name) end
	return entry
end

function MapService.unload()
	for _, item in { marks, wall, gate, catcherWalls } do
		item:Destroy()
	end
	marks, wall, gate, catcherWalls = nil, nil, nil, nil
	field = nil
	middleSpots = nil
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
	return hit and hit.Position.Y, hit and hit.Instance -- (and the part it landed on)
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
function edge(zone)
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
	Before GO: an invisible wall on the start line keeps runners in their zone (they can still
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
	-- Nothing to see (owner, Oct 18: "get rid of laser wall"): the white safe line on the floor marks the start.
	wall.Parent = loaded or Workspace
end

--[[
	The goal's gate (owner: once you're across you stay across, you can't wander back into the middle): a
	thick invisible block on the goal line in the "HuzzSafeWall" collision group, which only collides with the
	"HuzzSafe" group (the parts of runners who are Safe: MapService.setSafe). Runners still running pass straight
	through it. It's invisible: the white line on the floor is the finish.
]]
local SAFE, SAFE_WALL = "HuzzSafe", "HuzzSafeWall"
-- Catchers keep out of both safe zones (owner, Oct 18: "make catcher not be able to go into the safe zone"): an
-- invisible wall on each zone's edge in "HuzzCatcherWall", which only collides with "HuzzCatcher" (catchers' parts:
-- MapService.setCatcher), so runners pass through it.
local CATCHER, CATCHER_WALL = "HuzzCatcher", "HuzzCatcherWall"
pcall(function()
	PhysicsService:RegisterCollisionGroup(SAFE)
	PhysicsService:RegisterCollisionGroup(SAFE_WALL)
	PhysicsService:RegisterCollisionGroup(CATCHER)
	PhysicsService:RegisterCollisionGroup(CATCHER_WALL)
end)
local function setUpGroups()
	pcall(function()
		for _, g in PhysicsService:GetRegisteredCollisionGroups() do
			local name = g.name
			if name ~= SAFE and name ~= SAFE_WALL and name ~= CATCHER and name ~= CATCHER_WALL then
				-- safe runners and catchers collide with everything a normal part does; each wall only with its group
				local normal = PhysicsService:CollisionGroupsAreCollidable("Default", name)
				PhysicsService:CollisionGroupSetCollidable(SAFE, name, normal)
				PhysicsService:CollisionGroupSetCollidable(CATCHER, name, normal)
				PhysicsService:CollisionGroupSetCollidable(SAFE_WALL, name, false)
				PhysicsService:CollisionGroupSetCollidable(CATCHER_WALL, name, false)
			end
		end
		PhysicsService:CollisionGroupSetCollidable(SAFE, SAFE, true)
		PhysicsService:CollisionGroupSetCollidable(CATCHER, CATCHER, true)
		PhysicsService:CollisionGroupSetCollidable(SAFE, CATCHER, true)
		PhysicsService:CollisionGroupSetCollidable(SAFE_WALL, SAFE_WALL, false)
		PhysicsService:CollisionGroupSetCollidable(SAFE_WALL, SAFE, true)
		PhysicsService:CollisionGroupSetCollidable(SAFE_WALL, CATCHER, false)
		PhysicsService:CollisionGroupSetCollidable(CATCHER_WALL, CATCHER_WALL, false)
		PhysicsService:CollisionGroupSetCollidable(CATCHER_WALL, SAFE_WALL, false)
		PhysicsService:CollisionGroupSetCollidable(CATCHER_WALL, SAFE, false)
		PhysicsService:CollisionGroupSetCollidable(CATCHER_WALL, CATCHER, true)
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
	-- Nothing to see (owner, Oct 18: "get rid of laser wall"): the white safe line on the floor is the finish.
	gate.Parent = loaded or Workspace
end

-- The catchers' walls on both safe zones' edges, for the whole game (on = false takes them down).
function MapService.holdCatchers(on)
	if catcherWalls then
		catcherWalls:Destroy()
		catcherWalls = nil
	end
	local z = MapService.zones
	if not (on and z.ZoneA and z.ZoneB and z.Middle) then
		return
	end
	setUpGroups()
	catcherWalls = Instance.new("Folder")
	catcherWalls.Name = "HuzzCatcherWalls"
	local h = Config.Map.WallHeight
	for _, name in { "ZoneA", "ZoneB" } do
		local centre, out, length = edge(z[name])
		-- on the line, its zone side flush with the edge (a catcher's arm still reaches over it: stabs need the
		-- runner out of the zone anyway)
		local base = CFrame.lookAt(centre, centre + out) + out * 1
		local block = markPart({
			Name = "Block" .. name, Size = Vector3.new(length + 4, h, 2), CFrame = base + Vector3.new(0, h / 2 - 2, 0),
			CanCollide = true, Transparency = 1, Parent = catcherWalls,
		})
		block.CollisionGroup = CATCHER_WALL
	end
	catcherWalls.Parent = loaded or Workspace
end

-- A point inside a safe zone pushed back out over its line onto the field (1.5 studs out), or nil if it's not in
-- the zone: the fallback for a catcher who got past the wall (a lunge through a corner, lag).
function MapService.pushOut(zone, position)
	if not (zone and MapService.zones.Middle and MapService.inZone(zone, position)) then
		return nil
	end
	local centre, out = edge(zone)
	local d = (position - centre):Dot(out)
	if d >= 0 then
		return nil
	end
	return position + out * (4 - d) -- (clear of the catcher wall, 0 to 2 studs out, plus a body: critic)
end

-- Puts a catcher's parts in the catcher group (true) or back to Default (false); other groups are left alone.
function MapService.setCatcher(character, on)
	if not character then
		return
	end
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			if on and d.CollisionGroup == "Default" then
				d.CollisionGroup = CATCHER
			elseif not on and d.CollisionGroup == CATCHER then
				d.CollisionGroup = "Default"
			end
		end
	end
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
	Every spot is open ground (Shared/SpawnSpots: owner, Oct 19 "make them spawn on open ground"): one that lands in
	a prop moves up to 2 studs (staying behind the line, in the zone, 3 studs from the others), else the runner takes
	the next free place along the line or in the next row; only if the whole zone is full does a spot stay as planned.
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
	local function planned(i, total)
		local row = (i - 1) // perRow
		local inRow = math.min(perRow, total - row * perRow)
		local k = (i - 1) % perRow
		local x = (k - (inRow - 1) / 2) * gap
		return line * CFrame.new(x, 0, 2.5 + row * 4) -- (CFrame z points back, away from the field)
	end
	ignoreCache = nil
	local chosen = {}
	local function fits(x, z)
		local p = Vector3.new(x, centre.Y + 1, z)
		if (p - centre):Dot(out) > -1 or not MapService.inZone(zone, p) then return false end
		for _, c in chosen do
			if (Vector3.new(c.X, 0, c.Z) - Vector3.new(x, 0, z)).Magnitude < 3 then return false end
		end
		return true
	end
	local spots = {}
	local missing = {}
	for i = 1, count do
		local at = planned(i, count).Position
		local hit = SpawnSpots.near(MapService.geometry, at.X, at.Z, centre.Y, 2, 0.5, fits)
		if hit then
			table.insert(chosen, hit)
			spots[i] = hit
		else
			table.insert(missing, i)
		end
	end
	-- the runners whose place was taken by a prop: the next free places (the rest of the row, then rows behind)
	local extra = count
	while #missing > 0 and extra < count + perRow * 4 do
		extra += 1
		local at = planned(extra, count + perRow * 4).Position
		local hit = SpawnSpots.near(MapService.geometry, at.X, at.Z, centre.Y, 2, 0.5, fits)
		if hit then
			table.insert(chosen, hit)
			spots[table.remove(missing, 1)] = hit
		end
	end
	for i = 1, count do
		local s = spots[i]
		if s then
			local pos = s + Vector3.new(0, SpawnSpots.RootHeight, 0)
			spots[i] = CFrame.lookAt(pos, pos + out)
		else -- (no open ground left in the zone: the planned spot, as before)
			local at = planned(i, count)
			local floor = MapService.ground(at.Position, at.Position.Y + 6) or at.Position.Y
			local pos = Vector3.new(at.Position.X, floor + SpawnSpots.RootHeight, at.Position.Z)
			spots[i] = CFrame.lookAt(pos, pos + out)
		end
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
