--[[
	BuildLobbyWalkways  (run in Studio's Command Bar, Edit mode, after BuildCannonMap and before
	BuildLobbyExtras; then BuildCartoonyMap for the studs)

	The lobby's walkways, laid out like the reference lobby (Stone Skipping, references/image-1.png;
	Alex, Oct 31: "make the lobby better ... fix all of the paths leading to them, make it like in the
	references"): a wide lavender main walkway from the west end through the spawn plaza to the launch
	dock, with dark arrows on it pointing at the launch, and a walkway to every area off it: along the
	front of the training booths (north), the eggs' walkway (south-west) and the cannonball stand's
	(south-east). The lawns between them are left as they are, framed by the walkways like the reference.
	The map's own wooden paths led to nothing in particular, so they go to ServerStorage.OldMaps.LobbyPaths
	(drag them back into CannonMap.01_Lobby to undo).

	Spots are in the map file's units (Config.Map.At scales them with the map), from
	tools/map/lobby_plan.json, where plan_check.py checks no rock, palm or prop stands on them.
	Safe to run again: it replaces Workspace.LobbyWalkways.
]]

local Config = require(game.ReplicatedStorage.GameConfig)
local ServerStorage = game:GetService("ServerStorage")

local TAG = "[LobbyWalkways]"
-- the reference's walkways: pinkish lavender tiles with a darker rim, dark flat arrows
local WALK, RIM, ARROW = Color3.fromRGB(210, 178, 222), Color3.fromRGB(165, 128, 190), Color3.fromRGB(80, 66, 96)
local BORDER, LIFT = 0.8, 0.3 -- studs: the rim round the outside, and how far the top stands over the lawn
local WALKS = { -- { name, x0, x1, z0, z1 } in the file's units
	{ "SpineEast", -51.8, -13, -4.5, 4.5 }, -- from under the plaza's rim to under the dock
	{ "SpineWest", -103, -68.2, -4.5, 4.5 },
	{ "Training", -95.5, -26.5, -17.9, -12.5 }, -- along the booth fronts
	{ "LinkMid", -63, -57, -12.5, -8 }, -- plaza to the booths
	{ "LinkEast", -33, -27, -12.5, -4.5 },
	{ "LinkWest", -95.5, -89.5, -12.5, -4.5 },
	{ "Eggs", -103, -63, 4.5, 15.5 }, -- the eggs stand on it (BuildLobbyExtras)
	{ "Stand", -48.5, -17.5, 4.5, 12.2 }, -- runs under the front of the cannonball stand
}
local ARROWS_X = { -44, -37, -30, -23, -16 } -- along the east spine, pointing at the dock (+X)

local map = workspace:FindFirstChild(Config.Map.Root)
if not map then
	error(TAG .. " no CannonMap in Workspace: run BuildCannonMap first")
end

-- 1. the map's wooden paths go on the shelf
local oldMaps = ServerStorage:FindFirstChild("OldMaps") or Instance.new("Folder")
oldMaps.Name = "OldMaps"
oldMaps.Parent = ServerStorage
local shelf = oldMaps:FindFirstChild("LobbyPaths") or Instance.new("Folder")
shelf.Name = "LobbyPaths"
shelf.Parent = oldMaps
local paths = {}
for _, d in ipairs(map:GetDescendants()) do
	if d:IsA("BasePart") and string.find(d.Name, "^Path_") then
		table.insert(paths, d)
	end
end
for _, p in ipairs(paths) do
	local node = p.Parent
	if node and node:IsA("Model") and node.Name == p.Name .. "_Node" then
		node.Parent = shelf
	else
		p.Parent = shelf
	end
end

-- 2. the lawn's height (the island is flat in the lobby)
local islands = {}
for _, d in ipairs(map:GetDescendants()) do
	if d:IsA("BasePart") and string.find(d.Name, "^Island_") then
		table.insert(islands, d)
	end
end
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = islands
local probe = Config.Map.At(-60, 0, -30)
local hit = workspace:Raycast(Vector3.new(probe.X, 200, probe.Z), Vector3.new(0, -400, 0), params)
local ground = hit and hit.Position.Y or 2.11 * Config.Map.Scale

-- 3. the walkways: every rim first, then every top a little higher, so where two walkways meet the
-- tops cover each other's rims and only the outside edge shows
local old = workspace:FindFirstChild("LobbyWalkways")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "LobbyWalkways"

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = folder
	return p
end
local function slab(name, w, top, color, grow)
	local a, b = Config.Map.At(w[2], 0, w[4]), Config.Map.At(w[3], 0, w[5])
	return part({
		Name = name,
		Size = Vector3.new(math.abs(b.X - a.X) + grow * 2, 0.8, math.abs(b.Z - a.Z) + grow * 2),
		CFrame = CFrame.new((a.X + b.X) / 2, top - 0.4, (a.Z + b.Z) / 2),
		Color = color,
	})
end
for _, w in ipairs(WALKS) do
	slab(w[1] .. "Rim", w, ground + LIFT - 0.05, RIM, BORDER)
end
for _, w in ipairs(WALKS) do
	slab(w[1], w, ground + LIFT, WALK, 0)
end

-- 4. flat arrows on the main walkway, like the reference's, pointing the way to the launch
local top = ground + LIFT + 0.03
for _, x in ipairs(ARROWS_X) do
	local c = Config.Map.At(x, 0, 0)
	local tip = Vector3.new(c.X + 0.8, top, c.Z)
	for _, side in ipairs({ -1, 1 }) do
		local tail = Vector3.new(c.X - 1.8, top, c.Z + side * 4.2)
		part({
			Name = "Arrow",
			Size = Vector3.new(1, 0.06, (tail - tip).Magnitude + 1),
			CFrame = CFrame.lookAt((tip + tail) / 2, tail),
			Color = ARROW,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		})
	end
end
folder.Parent = workspace
print(TAG, ("%d walkways, %d arrows; the map's %d wooden path pieces are in ServerStorage.OldMaps.LobbyPaths"):format(#WALKS, #ARROWS_X, #paths))
