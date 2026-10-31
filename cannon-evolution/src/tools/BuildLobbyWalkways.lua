--[[
	BuildLobbyWalkways  (run in Studio's Command Bar, Edit mode, after BuildCannonMap and before
	BuildLobbyExtras and BuildLobbyDressing; then BuildCartoonyMap for the studs)

	The lobby's paths, pirate style (Alex, Oct 31: "use the other paths, we want to keep the pirate
	spirit"). The map's own wooden plank paths stay as Alex made them (plaza to the dock, plaza to the
	west, plaza to the cannonball stand). An earlier version of this tool put them in
	ServerStorage.OldMaps.LobbyPaths; this one puts them back. New plank paths in the same style (the same
	plank size, gaps, two browns and grey stones along the edges, measured off the map file) reach the
	places the map's paths don't: a boardwalk along the front of the training booths with three links to
	it, the west path past the eggs, and a link from the dock path to the front of the cannonball stand.

	Routes are in the map file's units (Config.Map.At scales them with the map), from
	tools/map/lobby_plan.json, where plan_check.py checks no rock, palm or prop stands on them.
	Safe to run again: it replaces Workspace.LobbyWalkways, and the planks come out the same every run.
]]

local Config = require(game.ReplicatedStorage.GameConfig)
local ServerStorage = game:GetService("ServerStorage")

local TAG = "[LobbyWalkways]"
-- the map's own planks and stones (measured in the file): planks 0.92 wide, about 4.2-4.5 long and 0.3
-- thick, every 1.25 along the path, turned a little each; stones about 0.8 across along the edges
local WOOD = { Color3.fromRGB(176, 122, 69), Color3.fromRGB(156, 106, 58) }
local STONE = Color3.fromRGB(163, 156, 142)
local PLANK_W, PLANK_T, PITCH, STONE_EVERY = 0.92, 0.3, 1.25, 2.3 -- file units
local ROUTES = { -- { name, from {x, z}, to {x, z}, width } in the file's units
	{ "PathWest", { -85.4, -0.8 }, { -105, -0.4 }, 4.4 }, -- carries on from the map's west path, past the eggs
	{ "PathBooths", { -97.5, -15.2 }, { -24.5, -15.2 }, 5.4 }, -- along the booth fronts
	{ "LinkPlaza", { -60, -9.0 }, { -60, -12.4 }, 4.4 }, -- spawn plaza to the booths
	{ "LinkDock", { -30, -4.9 }, { -30, -12.4 }, 4.4 }, -- dock path to the first booth
	{ "LinkWest", { -93, -3.1 }, { -93, -12.4 }, 4.4 }, -- west path to the last booths
	{ "LinkStand", { -37, 6.0 }, { -37, 11.7 }, 4.4 }, -- dock path to the cannonball stand's front
}

local map = workspace:FindFirstChild(Config.Map.Root)
if not map then
	error(TAG .. " no CannonMap in Workspace: run BuildCannonMap first")
end
local k = Config.Map.Scale

-- 1. the map's wooden paths come back from the shelf
local restored = 0
local shelf = ServerStorage:FindFirstChild("OldMaps") and ServerStorage.OldMaps:FindFirstChild("LobbyPaths")
if shelf then
	local home = map:FindFirstChild("01_Lobby") or map
	for _, p in ipairs(shelf:GetChildren()) do
		p.Parent = home
		restored += 1
	end
	shelf:Destroy()
end

-- 2. the ground's height (the island is flat in the lobby)
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
local ground = hit and hit.Position.Y or 2.11 * k
local plankTop = ground + 0.07 * k -- the map's planks stand this far over the ground

-- 3. the new plank paths
local old = workspace:FindFirstChild("LobbyWalkways")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "LobbyWalkways"

local rng = Random.new(31) -- fixed, so every run lays the same planks
local function part(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, v in pairs(props) do
		p[key] = v
	end
	p.Parent = parent
	return p
end
local function shade(c, f)
	return Color3.new(math.clamp(c.R * f, 0, 1), math.clamp(c.G * f, 0, 1), math.clamp(c.B * f, 0, 1))
end

local planks, stones = 0, 0
for _, r in ipairs(ROUTES) do
	local route = Instance.new("Model")
	route.Name = r[1]
	local a, b = Config.Map.At(r[2][1], 0, r[2][2]), Config.Map.At(r[3][1], 0, r[3][2])
	a, b = Vector3.new(a.X, 0, a.Z), Vector3.new(b.X, 0, b.Z)
	local len = (b - a).Magnitude
	local dir = (b - a).Unit
	local side = dir:Cross(Vector3.yAxis)
	local width = r[4] * k
	local n = math.max(1, math.floor(len / (PITCH * k)))
	local step = len / n
	for i = 0, n - 1 do
		local t = (i + 0.5) * step
		local wiggle = math.sin(t / (9 * k)) * 0.3 * k -- a gentle hand-laid wander, like the map's paths
		local c = a + dir * t + side * (wiggle + rng:NextNumber(-0.12, 0.12) * k)
		local long = width + rng:NextNumber(-0.25, 0.15) * k
		local turn = math.rad(rng:NextNumber(-7, 7))
		part({
			Name = "Plank",
			Size = Vector3.new(long, PLANK_T * k, PLANK_W * k),
			CFrame = CFrame.lookAt(c, c + dir) * CFrame.Angles(0, turn, 0) + Vector3.new(0, plankTop - PLANK_T * k / 2, 0),
			Color = shade(WOOD[rng:NextInteger(1, 2)], rng:NextNumber(0.94, 1.04)),
		}, route)
		planks += 1
	end
	-- stones along the edges, now one side, now the other, now both
	local m = math.floor(len / (STONE_EVERY * k))
	for i = 0, m - 1 do
		local t = (i + rng:NextNumber(0.2, 0.8)) * (len / math.max(m, 1))
		for _, s in ipairs({ -1, 1 }) do
			if rng:NextNumber() < 0.55 then
				local size = rng:NextNumber(0.65, 0.9) * k
				local c = a + dir * t + side * s * (width / 2 + rng:NextNumber(0.15, 0.45) * k)
				part({
					Name = "Stone",
					Size = Vector3.new(size, size * 0.7, size * rng:NextNumber(0.8, 1.1)),
					CFrame = CFrame.new(c.X, ground + size * 0.12, c.Z)
						* CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-12, 12))),
					Color = shade(STONE, rng:NextNumber(0.9, 1.05)),
					CanCollide = false,
				}, route)
				stones += 1
			end
		end
	end
	route.Parent = folder
end
folder.Parent = workspace
print(TAG, ("%d new plank paths (%d planks, %d stones); %d of the map's own path pieces put back"):format(#ROUTES, planks, stones, restored))
