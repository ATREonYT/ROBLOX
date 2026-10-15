--[[
	Finds the owner's maps and picks one per game.
	A map is any folder or model in Workspace holding parts named ZoneA, ZoneB
	and Middle (optional: Bench). Make one set per map, e.g.
	  Workspace > Graveyard > ZoneA, ZoneB, Middle
	  Workspace > Field > ZoneA, ZoneB, Middle
	The map's name is that folder's name. A part named Lobby anywhere is
	where players wait between games. With no zones at all, a plain test
	field is built so the game still runs.
]]
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Round)

local MapService = {}
MapService.zones = {} -- the current map's zones (filled in place, so callers can keep the table)
MapService.maps = {} -- { name, ZoneA, ZoneB, Middle, Bench? }
local lastPicked

local function asPart(item)
	if item and item:IsA("BasePart") then
		return item
	elseif item and item:IsA("Model") then
		return item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function find(key)
	local name = Config.Map[key]
	local tagged = CollectionService:GetTagged("Huzz" .. key)
	return asPart(tagged[1]) or asPart(Workspace:FindFirstChild(name, true))
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
-- a fenced Bench off to the side. Only built when the map has no zones.
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
	if not Workspace:FindFirstChildWhichIsA("SpawnLocation", true) then
		local spawn = Instance.new("SpawnLocation")
		spawn.Anchored = true
		spawn.Size = Vector3.new(12, 1, 12)
		spawn.Position = Vector3.new(0, 0.1, -112)
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Parent = folder
	end
	folder.Parent = Workspace
	return folder
end

local function addMap(name, container, a, b, middle, bench)
	if a and b and middle then
		table.insert(MapService.maps, { name = name, ZoneA = a, ZoneB = b, Middle = middle, Bench = bench })
		print(`[Huzz] Map found: {name}`)
	elseif container then
		warn(`[Huzz] {container:GetFullName()} has a ZoneA but is missing ZoneB or Middle: skipped`)
	end
end

function MapService.init()
	local C = Config.Map
	-- Every container holding a ZoneA (plus its ZoneB and Middle) is a map.
	local seen = {}
	for _, d in Workspace:GetDescendants() do
		if d.Name == C.ZoneA and asPart(d) and not seen[d.Parent] then
			local box = d.Parent
			seen[box] = true
			local name = if box == Workspace then "Main" else box.Name
			addMap(name, box, asPart(d), asPart(box:FindFirstChild(C.ZoneB)), asPart(box:FindFirstChild(C.Middle)), asPart(box:FindFirstChild(C.Bench)))
		end
	end
	-- Single-map tags (HuzzZoneA, HuzzZoneB, HuzzMiddle), as before.
	if #MapService.maps == 0 then
		addMap("Main", nil, find("ZoneA"), find("ZoneB"), find("Middle"), find("Bench"))
	end
	if #MapService.maps == 0 then
		if not C.BuildTestField then
			error("[Huzz] No map has ZoneA, ZoneB and Middle (see Config/Round.lua > Map)")
		end
		warn("[Huzz] No ZoneA/ZoneB/Middle in the map: building the test field")
		local field = buildTestField()
		addMap("Test Field", field, field.ZoneA, field.ZoneB, field.Middle, field.Bench)
	end
	local lobby = Workspace:FindFirstChild(C.Lobby, true)
	MapService.lobby = asPart(CollectionService:GetTagged("HuzzLobby")[1]) or asPart(lobby)
	MapService.pick()
end

-- Chooses this game's map: random, never the same one twice in a row.
function MapService.pick()
	local maps = MapService.maps
	local choice = maps[math.random(#maps)]
	if #maps > 1 then
		while choice == lastPicked do
			choice = maps[math.random(#maps)]
		end
	end
	lastPicked = choice
	local z = MapService.zones
	z.ZoneA, z.ZoneB, z.Middle, z.Bench, z.Lobby = choice.ZoneA, choice.ZoneB, choice.Middle, choice.Bench, MapService.lobby
	return choice
end

-- Inside the zone's footprint; generous upward so jumping still counts.
function MapService.inZone(zone, position)
	local p = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size * 0.5
	return math.abs(p.X) <= half.X and math.abs(p.Z) <= half.Z and p.Y >= -half.Y - 4 and p.Y <= half.Y + 14
end

-- A random standing spot on top of the zone, facing lookAt.
function MapService.spot(zone, lookAt)
	local half = zone.Size * 0.5
	local inset = Vector3.new(math.max(half.X - 3, 0), 0, math.max(half.Z - 3, 0))
	local local_ = Vector3.new((math.random() * 2 - 1) * inset.X, half.Y + 3.2, (math.random() * 2 - 1) * inset.Z)
	local pos = zone.CFrame:PointToWorldSpace(local_)
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
