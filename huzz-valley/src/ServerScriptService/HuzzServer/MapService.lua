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
	Several lobbies (the owner built one beside each map: "one per map"): each
	map belongs to the lobby nearest it and loads where it was built; after the
	vote everyone moves to the winning map's lobby (useLobbyFor), and only that
	lobby's SpawnLocation stays on.
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
MapService.lobbies = {} -- { floor, spawn }: every lobby island; maps' entries point at theirs (entry.lobby)
local loaded -- the copy in Workspace
local marks, wall -- the current map's safe lines and sign, and the start-line wall before GO
local gate -- the goal line's gate: only runners already safe bump into it (holdGoal)
local catcherWalls -- both safe zones' walls that only catchers bump into (holdCatchers)
local lastPicked
local zoneParts = {} -- every zone part, so floor checks look through them
local field -- the loaded map's walled field { frame, lo, hi, floor } (boundary), for putting fallers back

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
		if k == key(C.Lobby) or k == "spawnbaseplate" or k == "mapspot" or select(2, pcall(CollectionService.HasTag, CollectionService, item, "HuzzLobby")) == true then
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

	-- The lobbies: parts tagged HuzzLobby, else parts named Lobby, else the SpawnBaseplates (the owner has one
	-- lobby island beside each map: "one per map").
	local tagged, named, bases, spot = {}, {}, {}, nil
	for _, t in CollectionService:GetTagged("HuzzLobby") do
		local p = asPart(t)
		if p and not table.find(tagged, p) then table.insert(tagged, p) end
	end
	for _, d in Workspace:GetDescendants() do
		if d:IsA("BasePart") then
			if key(d.Name) == key(C.Lobby) then
				table.insert(named, d)
			elseif key(d.Name) == "spawnbaseplate" then
				table.insert(bases, d)
			elseif key(d.Name) == "mapspot" then
				spot = spot or d
			end
		end
	end
	local floors = if #tagged > 0 then tagged elseif #named > 0 then named else bases
	MapService.mapSpot = spot
	MapService.lobbies = {}
	for _, floor in floors do
		table.insert(MapService.lobbies, { floor = floor })
	end

	-- Each map belongs to the lobby nearest where it was built.
	for _, entry in MapService.maps do
		local middle = select(3, zonesOf(entry.box, entry.name, true))
		local best, bestDist = nil, math.huge
		for _, rec in MapService.lobbies do
			local d = middle and flat(rec.floor.CFrame.Position - middle.CFrame.Position).Magnitude or 0
			if d < bestDist then best, bestDist = rec, d end
		end
		entry.lobby = best
	end

	if #MapService.lobbies > 1 then
		-- Each lobby's own SpawnLocation (the one on it), made when it has none; only the lobby in use keeps
		-- its spawn on, so new and respawning players land where everyone is.
		for _, rec in MapService.lobbies do
			local f = rec.floor
			local reach = math.max(f.Size.X, f.Size.Z) / 2 + 30
			local best, bestDist = nil, reach
			for _, d in Workspace:GetDescendants() do
				if d:IsA("SpawnLocation") then
					local dist = flat(d.CFrame.Position - f.CFrame.Position).Magnitude
					if dist < bestDist then best, bestDist = d, dist end
				end
			end
			rec.spawn = best or makeSpawn(f)
		end
	elseif MapService.lobbies[1] then
		-- One lobby: players must still spawn somewhere once the maps (and their SpawnLocations) are stored away.
		local hasSpawn = false
		for _, d in Workspace:GetDescendants() do
			if d:IsA("SpawnLocation") and d.Enabled then
				hasSpawn = true
			end
		end
		local f = MapService.lobbies[1].floor
		MapService.lobbies[1].spawn = if hasSpawn then Workspace:FindFirstChild("HuzzLobbySpawn") else makeSpawn(f)
	end
	useLobby(MapService.lobbies[1])
	task.spawn(MapService.catchFalls)
end

--[[
	The lobby beside this map becomes the one in use (owner: "one per map": after the vote everyone waits
	in the lobby next to the winning map). True when it changed, so the caller moves everyone over.
]]
function MapService.useLobbyFor(entry): boolean
	local rec = entry and entry.lobby
	if not rec or rec.floor == MapService.lobby then return false end
	useLobby(rec)
	return true
end

-- Where players stand in the lobby in use: its spawn, else the top of its floor (or nil with no lobby).
function MapService.lobbySpawn(): Vector3?
	local spawn = activeLobby and activeLobby.spawn
	if spawn and spawn.Parent then return spawn.CFrame.Position end
	local lobby = MapService.lobby
	return if lobby then lobby.CFrame.Position + Vector3.new(0, lobby.Size.Y / 2, 0) else nil
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
		root.AssemblyLinearVelocity = Vector3.zero
		character:PivotTo(CFrame.new(back) * root.CFrame.Rotation)
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

-- Where the map's middle goes: MapSpot if there is one; with a lobby beside every map (the owner built each
-- lobby in front of its map, floors level) the map stays exactly where it was built; else just in front of the
-- one lobby, turned so its open side (see openSide) faces the lobby, and lowered to its ground (dropFor).
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
	if #MapService.lobbies > 1 then
		return CFrame.lookAt(mid, mid + open) -- built level with its own lobby: stays exactly as built
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
	if not entry.fixed then pcall(MapService.paintLobby, entry.name) end
	return entry
end

function MapService.unload()
	for _, item in { marks, wall, gate, catcherWalls } do
		item:Destroy()
	end
	marks, wall, gate, catcherWalls = nil, nil, nil, nil
	field = nil
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
	return position + out * (1.5 - d)
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
