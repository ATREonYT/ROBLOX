--[[
	BuildCannonMap: paste into the Command Bar once, right after Import 3D of map/CannonMap.glb
	(Avatar tab > Import 3D). Safe to run again.

	1. Finds the imported map, names it CannonMap and sizes and places it (the importer can scale it,
	   turn it or drop it in front of the camera): the compass plaza is the yardstick, 18.8 studs across
	   with its middle at (-60, 2.15, 0) in the file, all times Config.Map.Scale (1.3: Alex wanted the
	   map bigger, Oct 30). Running it again after changing the scale resizes the map.
	2. Collisions: sand, plaza, paths and dock you walk on; fences, rocks, towers, the ship and
	   the crates are solid; palms, mountains and water are not. The far stages are solid too, for
	   the world teleports. Mountains cast no shadow, so the lobby stays bright.
	3. The river gets the Stone Skipping water look (bright turquoise, smooth), like BuildWater.
	4. Moves one palm and the crate pile out of the training booths' way (tools/map/lobby_plan.json).
	5. Invisible edge walls round the island and along the dock, so nobody falls off the map, and a calm
	   sea round the whole map (walk-through), so past its edges there is no empty void.
	6. Puts the old map (map1b), the Baseplate and StudTest2 in ServerStorage.OldMaps; nothing is deleted.

	Then run BuildWorld1, BuildCannonBallStand, BuildLobbyWalkways and BuildLobbyExtras, which see the
	new map and place the spawn, dock launch, booths, cannonball stand, walkways, eggs and area walls on
	it, then BuildRebirthSigns and BuildCartoonyMap.
]]

local Config = require(game.ReplicatedStorage.GameConfig)
local ServerStorage = game:GetService("ServerStorage")

local TAG = "[CannonMap]"
-- the plaza in the file is 18.8 across with its middle at (-60, 2.15, 0); the map is built Config.Map.Scale times bigger
local PLAZA_WIDTH, PLAZA_CENTRE = 18.8 * Config.Map.Scale, Config.Map.At(-60, 2.15, 0)

-- 1. find it -----------------------------------------------------------------------------------
local map
for _, c in ipairs(workspace:GetChildren()) do
	if c:IsA("Model") and c.Name ~= "map1b" then
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("BasePart") and string.find(d.Name, "^Plaza_Compass_Spawn") then
				map = c
				break
			end
		end
	end
	if map then
		break
	end
end
if not map then
	error(TAG .. " no imported map in Workspace: Import 3D map/CannonMap.glb first")
end
map.Name = Config.Map.Root
-- Import 3D nests the file's own root inside the model (CannonMap > CannonMap > 01_Lobby...): lift the
-- groups up a level so the game finds CannonMap.03_River and the rest
for _, inner in ipairs(map:GetChildren()) do
	if inner:IsA("Model") and inner.Name == map.Name and not inner:FindFirstChildWhichIsA("BasePart") then
		for _, g in ipairs(inner:GetChildren()) do
			g.Parent = map
		end
		inner:Destroy()
	end
end

local function plazaBox()
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, d in ipairs(map:GetDescendants()) do
		if d:IsA("BasePart") and string.find(d.Name, "^Plaza_Compass_Spawn") then
			lo = lo:Min(d.Position - d.Size / 2)
			hi = hi:Max(d.Position + d.Size / 2)
		end
	end
	return (lo + hi) / 2, hi - lo
end
local centre, size = plazaBox()
local k = PLAZA_WIDTH / size.X
if math.abs(k - 1) > 0.01 then
	map:ScaleTo(map:GetScale() * k)
	print(TAG, ("the import was %.3fx the file's size: scaled back"):format(1 / k))
	centre, size = plazaBox()
end
if (centre - PLAZA_CENTRE).Magnitude > 0.05 then
	map:PivotTo(map:GetPivot() + (PLAZA_CENTRE - centre))
	print(TAG, "moved into place by " .. tostring(PLAZA_CENTRE - centre))
end
-- Import 3D can also turn the map (Alex's import came in 180 degrees round). The round plaza can't show
-- that, so check the launch dock is east of it (+X, the launch direction) and turn the map back if not.
local dock
for _, d in ipairs(map:GetDescendants()) do
	if d:IsA("BasePart") and string.find(d.Name, "^Dock_Launch_Dock") then
		dock = d
		break
	end
end
if dock then
	local away = dock.Position - PLAZA_CENTRE
	local turned = math.round(math.atan2(-away.Z, away.X) / (math.pi / 2)) * (math.pi / 2)
	if turned ~= 0 then
		local pivot = Vector3.new(PLAZA_CENTRE.X, 0, PLAZA_CENTRE.Z)
		map:PivotTo(CFrame.new(pivot) * CFrame.Angles(0, -turned, 0) * CFrame.new(-pivot) * map:GetPivot())
		print(TAG, ("the import was turned %d degrees: turned it back"):format(math.deg(turned)))
	end
else
	warn(TAG, "no Dock_Launch_Dock part: can't check which way the map faces")
end

-- the importer may keep the file's groups as models or flatten them; put pieces in the groups by name
local function group(name)
	local g = map:FindFirstChild(name)
	if not g then
		g = Instance.new("Model")
		g.Name = name
		g.Parent = map
	end
	return g
end
for _, d in ipairs(map:GetDescendants()) do
	if d:IsA("BasePart") and d.Parent == map then
		if string.find(d.Name, "^River_") then
			d.Parent = group(Config.Map.River)
		elseif string.find(d.Name, "^%d%d_") then
			d.Parent = group(Config.Map.Stages)
		elseif d.Position.X > 12000 then
			d.Parent = group(Config.Map.Sky)
		else
			d.Parent = group("01_Lobby")
		end
	end
end

-- 2. collisions --------------------------------------------------------------------------------
local SOLID = { "^Barrier_", "^Buildings_", "^Grand_Cannon_" }
local function matches(name, list)
	for _, pattern in ipairs(list) do
		if string.find(name, pattern) then
			return true
		end
	end
	return false
end
local function setFidelity(p, fidelity)
	if p:IsA("MeshPart") and p.CollisionFidelity ~= fidelity then
		local ok, err = pcall(function()
			p.CollisionFidelity = fidelity
		end)
		if not ok then
			warn(TAG, "couldn't set the collision shape of " .. p.Name .. ": " .. tostring(err))
		end
	end
end

local river, stages, sky = map:FindFirstChild(Config.Map.River), map:FindFirstChild(Config.Map.Stages), map:FindFirstChild(Config.Map.Sky)
local counts = { walk = 0, solid = 0, open = 0, water = 0, track = 0 }
local done = 0
for _, p in ipairs(map:GetDescendants()) do
	if p:IsA("BasePart") then
		p.Anchored = true
		local name = p.Name
		if river and p:IsDescendantOf(river) then
			-- see-through to clicks and walking, but the flights find its surface with a raycast
			p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = false, false, true, false
			counts.water += 1
		elseif (stages and p:IsDescendantOf(stages)) or (sky and p:IsDescendantOf(sky)) then
			p.CanCollide, p.CanTouch, p.CanQuery = true, false, true
			counts.track += 1
		elseif Config.Map.IsGround(name) then
			p.CanCollide, p.CanTouch, p.CanQuery = true, false, true
			setFidelity(p, Enum.CollisionFidelity.PreciseConvexDecomposition)
			counts.walk += 1
		elseif matches(name, SOLID) then
			p.CanCollide, p.CanTouch, p.CanQuery = true, false, true
			counts.solid += 1
		elseif string.find(name, "^Props_") then
			p.CanCollide, p.CanTouch, p.CanQuery = true, false, true
			setFidelity(p, Enum.CollisionFidelity.Box)
			counts.solid += 1
		else -- palms, mountains and anything new: you walk through them
			p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
			if string.find(name, "^Mountains_") then
				p.CastShadow = false -- the low sun would shade the whole lobby
			end
			counts.open += 1
		end
		done += 1
		if done % 20 == 0 then
			task.wait() -- working out collision shapes is slow; let Studio breathe
		end
	end
end
print(TAG, ("collisions: %d walkable, %d solid, %d walk-through, %d water, %d track pieces"):format(counts.walk, counts.solid, counts.open, counts.water, counts.track))

-- 3. Stone Skipping water ----------------------------------------------------------------------
if river then
	for _, p in ipairs(river:GetDescendants()) do
		if p:IsA("MeshPart") then
			if p:GetAttribute("OldTexture") == nil then
				p:SetAttribute("OldTexture", p.TextureID)
			end
			p.TextureID = ""
			p.Color = Color3.fromRGB(20, 200, 235)
			p.Material = Enum.Material.SmoothPlastic
			p.Reflectance = 0.1
		end
	end
end

-- the open sea: the map is a chain of islands with nothing round it, so past its edges you saw a flat
-- olive void. A calm sea just under the river fills it, and the lobby reads as a pirate island. Walk-
-- through and not hit by rays, so the skips, teleports and fall-catch only ever see the river.
local SEA_TOP, TILE = Config.Map.WaterY - 0.1, 2048
local oldSea = workspace:FindFirstChild("MapSea")
if oldSea then
	oldSea:Destroy()
end
local sea = Instance.new("Folder")
sea.Name = "MapSea"
for x = -6, 11 do -- out to about 12,000 studs every way, so its edge is lost in the haze
	for z = -6, 5 do
		local p = Instance.new("Part")
		p.Name = "Sea"
		p.Anchored = true
		p.Size = Vector3.new(TILE, 1, TILE)
		p.Position = Vector3.new((x + 0.5) * TILE, SEA_TOP - 0.5, (z + 0.5) * TILE)
		p.Color = Color3.fromRGB(10, 165, 215)
		p.Material = Enum.Material.SmoothPlastic
		p.Reflectance = 0.05
		p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = false, false, false, false
		p.Parent = sea
	end
end
sea.Parent = workspace

-- 4. clear the booths' spot: each group's middle goes to a spot in the file's units (tools/map/lobby_plan.json) ---
local MOVES = {
	{ { "Trees_Palm_001" }, Vector2.new(-106, -31) }, -- by the west palisade, behind the VIP booth
	{ { "Props_Crate_001", "Props_Crate_002", "Props_Crate_003", "Props_Barrel_001", "Props_Barrel_002", "Props_Treasure_Chest_001" }, Vector2.new(-16, -35) }, -- the north-east corner, by the dock
	{ { "Props_Barrel_003" }, Vector2.new(-23, -30) },
	{ { "Trees_Palm_005" }, Vector2.new(-20, -41) }, -- a little east, clear of booth 1
	{ { "Trees_Palm_003" }, Vector2.new(-109, 15) }, -- a little west, clear of the end of the egg row
}
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
local grounds = {}
for _, p in ipairs(map:GetDescendants()) do
	if p:IsA("BasePart") and Config.Map.IsGround(p.Name) then
		table.insert(grounds, p)
	end
end
groundParams.FilterDescendantsInstances = grounds
local function groundY(pos)
	local hit = workspace:Raycast(Vector3.new(pos.X, 60, pos.Z), Vector3.new(0, -120, 0), groundParams)
	return hit and hit.Position.Y
end
for _, move in ipairs(MOVES) do
	local parts = {}
	for _, name in ipairs(move[1]) do
		local p = map:FindFirstChild(name, true)
		if p and p:IsA("BasePart") then
			table.insert(parts, p)
		end
	end
	if #parts > 0 then
		local mid = Vector3.zero
		for _, p in ipairs(parts) do
			mid += p.Position / #parts
		end
		local spot = Config.Map.At(move[2].X, 0, move[2].Y)
		local step = Vector3.new(spot.X - mid.X, 0, spot.Z - mid.Z) -- zero on a second run
		local before, after = groundY(mid), groundY(mid + step)
		local lift = (before and after) and Vector3.new(0, after - before, 0) or Vector3.zero
		for _, p in ipairs(parts) do
			p.CFrame += step + lift
		end
	end
end

-- 5. edge walls (outline of the sand from tools/map/lobby_plan.json, then out along the dock) ------
local WALL = {
	{ -12, 11.5 }, { -9, 19 }, { -6.9, 27.7 }, { -2.4, 40.3 }, { -10.8, 44.2 }, { -18.8, 47.2 },
	{ -27, 48.5 }, { -34.5, 49.4 }, { -41.5, 50.5 }, { -48.3, 50.8 }, { -55, 50.8 }, { -61.8, 51.3 },
	{ -68.8, 51.4 }, { -76.1, 51 }, { -83.9, 50 }, { -92.3, 48.6 }, { -99.2, 44.2 }, { -106.6, 39.6 },
	{ -110.4, 32 }, { -113.4, 24.2 }, { -115.4, 16.2 }, { -116.5, 8.1 }, { -117.5, 0 }, { -117, -8.2 },
	{ -116.3, -16.4 }, { -114.4, -24.6 }, { -111.5, -32.6 }, { -107, -39.9 }, { -97.8, -42.8 },
	{ -90.3, -46 }, { -81.9, -46.5 }, { -74.2, -46.4 }, { -67.6, -46.8 }, { -61.2, -46.8 },
	{ -55, -47.5 }, { -48.7, -47.8 }, { -41.9, -49 }, { -34.7, -49 }, { -27, -48.5 }, { -18.8, -47.2 },
	{ -12.2, -42.8 }, { -4.8, -38.5 }, { -7.4, -27.5 }, { -11.1, -18.2 }, { -10.6, -11.9 },
	{ -10.5, -6.3 }, { 17.6, -6.3 }, { 17.6, 6.3 }, { -10.5, 6.3 },
}
local BOTTOM, TOP = -4, 16 -- from under the beach to well over a jump
local old = workspace:FindFirstChild("MapWalls")
if old then
	old:Destroy()
end
local walls = Instance.new("Folder")
walls.Name = "MapWalls"
for i, a in ipairs(WALL) do
	local b = WALL[i % #WALL + 1]
	local pa, pb = Config.Map.At(a[1], 0, a[2]), Config.Map.At(b[1], 0, b[2])
	local mid = (pa + pb) / 2 + Vector3.new(0, (BOTTOM + TOP) / 2, 0)
	local w = Instance.new("Part")
	w.Name = "EdgeWall"
	w.Anchored = true
	w.Size = Vector3.new(1, TOP - BOTTOM, (pb - pa).Magnitude + 1) -- +1 closes the corners
	w.CFrame = CFrame.lookAt(mid, mid + (pb - pa))
	w.Transparency = 1
	w.CanCollide, w.CanTouch, w.CanQuery, w.CastShadow = true, false, false, false
	w.Parent = walls
end
walls.Parent = workspace

-- 6. old map away (kept, not deleted) -----------------------------------------------------------
local oldMaps = ServerStorage:FindFirstChild("OldMaps") or Instance.new("Folder")
oldMaps.Name = "OldMaps"
oldMaps.Parent = ServerStorage
for _, name in ipairs({ "map1b", "Baseplate", "StudTest2" }) do
	local x = workspace:FindFirstChild(name)
	if x then
		x.Parent = oldMaps
		print(TAG, name .. " moved to ServerStorage.OldMaps")
	end
end

print(TAG, "done: now run BuildWorld1, BuildCannonBallStand and BuildLobbyExtras")
