--[[
	BuildLobbyWalkways  (run in Studio's Command Bar, Edit mode, after BuildCannonMap and before
	BuildLobbyExtras; then BuildCartoonyMap for the studs)

	The lobby's walkways, laid out like the reference lobby (Stone Skipping, references/image-1.png;
	Alex, Oct 31: "make the lobby better ... fix all of the paths leading to them, make it like in the
	references"): a wide lavender main walkway from the west end through the spawn plaza to the launch
	dock, with dark arrows on it pointing at the launch, and a walkway to every area off it: along the
	front of the training booths (north), the eggs' walkway (south-west) and the cannonball stand's
	(south-east). The lawn between them is two-tone checkered grass like the reference's (Oct 31), laid
	under the walkways so they frame it.
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
-- along the east spine, pointing at the dock (+X): chunky and close together like the reference's
local ARROWS_X = { -48, -43.5, -39, -34.5, -30, -25.5, -21, -16.5 }
local ARROW_W = 1.6 -- studs: each arm's thickness
-- the checkered lawn: one area in the file's units ({ x0, x1, z0, z1 }), from the booths' walkway down to
-- the ship and the lookout tower, and from the west end to the beach by the dock. Squares line up with the
-- spawn plaza; any square the walkways or the plaza hide completely is left out.
local LAWN = { -103, -17, -12.5, 24 }
local SQUARE = 6 -- studs
local GRASS_LIGHT, GRASS_DARK = Color3.fromRGB(124, 190, 58), Color3.fromRGB(100, 160, 42)

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

-- 4. the checkered lawn, a little under the walkways' rims (rims at +0.25, lawn at +0.1)
local lawnTop = ground + 0.1
local covers = {} -- world rectangles that hide the lawn: every walkway with its rim
for _, w in ipairs(WALKS) do
	local a, b = Config.Map.At(w[2], 0, w[4]), Config.Map.At(w[3], 0, w[5])
	table.insert(covers, { math.min(a.X, b.X) - BORDER, math.max(a.X, b.X) + BORDER, math.min(a.Z, b.Z) - BORDER, math.max(a.Z, b.Z) + BORDER })
end
local plaza = Config.Map.At(-60, 0, 0) -- the spawn plaza's middle; its round top hides squares near it
local PLAZA_R = 11
local la, lb = Config.Map.At(LAWN[1], 0, LAWN[3]), Config.Map.At(LAWN[2], 0, LAWN[4])
local x0, x1, z0, z1 = math.min(la.X, lb.X), math.max(la.X, lb.X), math.min(la.Z, lb.Z), math.max(la.Z, lb.Z)
local squares = 0
for i = math.floor((x0 - plaza.X) / SQUARE), math.ceil((x1 - plaza.X) / SQUARE) do
	for j = math.floor((z0 - plaza.Z) / SQUARE), math.ceil((z1 - plaza.Z) / SQUARE) do
		local ax, bx = math.max(x0, plaza.X + i * SQUARE), math.min(x1, plaza.X + (i + 1) * SQUARE)
		local az, bz = math.max(z0, plaza.Z + j * SQUARE), math.min(z1, plaza.Z + (j + 1) * SQUARE)
		if bx - ax > 0.05 and bz - az > 0.05 then
			local hidden = false
			for _, c in ipairs(covers) do
				if ax >= c[1] and bx <= c[2] and az >= c[3] and bz <= c[4] then
					hidden = true
					break
				end
			end
			if not hidden then
				hidden = true
				for _, corner in ipairs({ { ax, az }, { bx, az }, { ax, bz }, { bx, bz } }) do
					if Vector2.new(corner[1] - plaza.X, corner[2] - plaza.Z).Magnitude > PLAZA_R then
						hidden = false
					end
				end
			end
			if not hidden then
				part({
					Name = "Lawn",
					Size = Vector3.new(bx - ax, 0.4, bz - az),
					CFrame = CFrame.new((ax + bx) / 2, lawnTop - 0.2, (az + bz) / 2),
					Color = (i + j) % 2 == 0 and GRASS_LIGHT or GRASS_DARK,
				})
				squares += 1
			end
		end
	end
end

-- 5. flat arrows on the main walkway, like the reference's, pointing the way to the launch
local top = ground + LIFT + 0.03
for _, x in ipairs(ARROWS_X) do
	local c = Config.Map.At(x, 0, 0)
	local tip = Vector3.new(c.X + 0.8, top, c.Z)
	for _, side in ipairs({ -1, 1 }) do
		local tail = Vector3.new(c.X - 1.8, top, c.Z + side * 4.2)
		part({
			Name = "Arrow",
			Size = Vector3.new(ARROW_W, 0.06, (tail - tip).Magnitude + ARROW_W),
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
print(TAG, ("%d walkways, %d arrows, %d lawn squares; the map's %d wooden path pieces are in ServerStorage.OldMaps.LobbyPaths"):format(#WALKS, #ARROWS_X, squares, #paths))
