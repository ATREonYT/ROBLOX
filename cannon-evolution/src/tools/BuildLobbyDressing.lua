--[[
	BuildLobbyDressing  (run in Studio's Command Bar, Edit mode, after BuildLobbyWalkways and
	BuildLobbyExtras)

	Pirate dressing for the lobby (Alex, Oct 31: "we want to keep the pirate spirit ... make the lobby
	actually good"). Following the vault's set-dressing rules (LihFolk "World Composition and Set Dressing"):
	props sit in small groups at path corners and edges, never on a path or in front of a booth, egg or the
	stand; made things line up with the paths; everything stands on the ground.
	  - three groups of crates and barrels, copied from the map's own (Alex's) crates and barrels
	  - two more of the map's palms in the empty grass between the eggs and the ship
	  - ship's lanterns on posts along the paths; the four that frame the way to the launch glow
	  - a wooden signpost by the spawn plaza: TRAINING, LAUNCH, EGGS

	Spots are in the map file's units, from tools/map/lobby_plan.json (plan_check.py checks them).
	Safe to run again: it replaces Workspace.LobbyDressing.
]]

local Config = require(game.ReplicatedStorage.GameConfig)

local TAG = "[LobbyDressing]"
local k = Config.Map.Scale
local POST_WOOD, IRON = Color3.fromRGB(102, 66, 38), Color3.fromRGB(45, 40, 40)
local GLOW = Color3.fromRGB(255, 196, 110)
local BOARD_WOOD, TEXT_EDGE = Color3.fromRGB(196, 140, 80), Color3.fromRGB(70, 40, 20)

-- groups of the map's crates and barrels: centre {x, z} in file units and how the group is turned
local GROUPS = {
	{ -100.5, -9, 0 }, -- by the west link, outside the last booth
	{ -24, -9, 180 }, -- by the dock link, outside the first booth
	{ -106, 4.5, 90 }, -- the west end of the egg path
}
-- one group: { template, x, z (studs, before the turn), turn, stacked on the item before }
local GROUP = {
	{ "Crate", 0, 0, 5 },
	{ "SmallCrate", 0.2, 0.1, -18, true },
	{ "Barrel", -2.9, 0.6, 0 },
	{ "Barrel", -2.2, -1.9, 40 },
	{ "SmallCrate", 2.6, 1.2, 12 },
}
local PALMS = { { -91, 18.5, 40 }, { -63, 20.5, 200 } }
-- lanterns: { x, z, the way the arm reaches {x, z}, glows }
local LANTERNS = {
	{ -37.8, -11.7, { 0, -1 } }, -- along the booth boardwalk, between booths
	{ -49.4, -11.7, { 0, -1 } },
	{ -72.6, -11.7, { 0, -1 } },
	{ -84.2, -11.7, { 0, -1 } },
	{ -81, 2.2, { 0, -1 } }, -- along the egg path, between eggs
	{ -97, 2.2, { 0, -1 } },
	{ -48.5, -2.6, { 0, 1 }, true }, -- framing the dock path where it leaves the plaza
	{ -48.5, 6.4, { 0, -1 }, true },
	{ -16, -5.9, { 0, 1 }, true }, -- and where it reaches the dock
	{ -16, 3.0, { 0, -1 }, true },
}
local SIGN = { -53, -10.5 }
local BOARDS = { -- { text, way it points {x, z}, height over the ground }
	{ "TRAINING", { 0, -1 }, 6.3 },
	{ "LAUNCH", { 1, 0 }, 5.2 },
	{ "EGGS", { -1, 0.55 }, 4.1 },
}

local map = workspace:FindFirstChild(Config.Map.Root)
if not map then
	error(TAG .. " no CannonMap in Workspace: run BuildCannonMap first")
end

-- the map's own props to copy
local function template(name)
	for _, d in ipairs(map:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == name then
			local node = d.Parent
			return (node:IsA("Model") and node.Name == name .. "_Node") and node or d
		end
	end
	warn(TAG, "the map has no " .. name .. "; that prop is left out")
	return nil
end
local TEMPLATES = {
	Crate = template("Props_Crate_004"),
	SmallCrate = template("Props_Crate_005"),
	Barrel = template("Props_Barrel_004"),
	Palm = template("Trees_Palm_006"),
}

-- the ground
local islands = {}
for _, d in ipairs(map:GetDescendants()) do
	if d:IsA("BasePart") and string.find(d.Name, "^Island_") then
		table.insert(islands, d)
	end
end
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = islands
local function groundAt(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), params)
	return hit and hit.Position.Y or 2.11 * k
end

local old = workspace:FindFirstChild("LobbyDressing")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "LobbyDressing"

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

-- a copy of a map prop at (x, z) in studs, turned, its bottom on `floor` (sunk a hair into it)
local function place(name, x, z, turn, floor, parent)
	local t = TEMPLATES[name]
	if not t then
		return nil
	end
	local c = t:Clone()
	local box, size
	if c:IsA("Model") then
		-- turn it, then move its middle to the spot and its bottom onto the floor
		c:PivotTo(CFrame.Angles(0, math.rad(turn), 0) * c:GetPivot())
		box, size = c:GetBoundingBox()
		c:PivotTo(c:GetPivot() + Vector3.new(x - box.X, floor - 0.05 - (box.Y - size.Y / 2), z - box.Z))
		box, size = c:GetBoundingBox()
	else
		c.CFrame = CFrame.new(x, floor - 0.05 + c.Size.Y / 2, z) * CFrame.Angles(0, math.rad(turn), 0) * c.CFrame.Rotation
		box, size = c.CFrame, c.Size
	end
	c.Parent = parent
	return box.Y + size.Y / 2 -- its top
end

-- 1. crates and barrels
local props = 0
for gi, g in ipairs(GROUPS) do
	local group = Instance.new("Model")
	group.Name = "Props" .. gi
	local centre = Config.Map.At(g[1], 0, g[2])
	local turn = CFrame.Angles(0, math.rad(g[3]), 0)
	local lastTop
	for _, item in ipairs(GROUP) do
		local off = turn * Vector3.new(item[2], 0, item[3])
		local x, z = centre.X + off.X, centre.Z + off.Z
		local floor = item[5] and lastTop or groundAt(x, z)
		local top = place(item[1], x, z, g[3] + item[4], floor, group)
		if top then
			lastTop = top
			props += 1
		end
	end
	group.Parent = folder
end

-- 2. palms
for _, p in ipairs(PALMS) do
	local at = Config.Map.At(p[1], 0, p[2])
	if place("Palm", at.X, at.Z, p[3], groundAt(at.X, at.Z), folder) then
		props += 1
	end
end

-- 3. ship's lanterns
for i, l in ipairs(LANTERNS) do
	local at = Config.Map.At(l[1], 0, l[2])
	local y = groundAt(at.X, at.Z)
	local way = Vector3.new(l[3][1], 0, l[3][2]).Unit
	local lantern = Instance.new("Model")
	lantern.Name = "Lantern" .. i
	local top = y + 5.4
	part({ Name = "Post", Size = Vector3.new(0.5, 5.7, 0.5), CFrame = CFrame.new(at.X, y + 5.7 / 2 - 0.3, at.Z), Color = POST_WOOD }, lantern)
	local tip = Vector3.new(at.X, top - 0.1, at.Z) + way * 1.5
	part({ Name = "Arm", Size = Vector3.new(0.3, 0.3, 1.8), CFrame = CFrame.lookAt(Vector3.new(at.X, top - 0.1, at.Z) + way * 0.75, tip), Color = POST_WOOD, CanCollide = false }, lantern)
	part({ Name = "Hook", Size = Vector3.new(0.1, 0.45, 0.1), CFrame = CFrame.new(tip - Vector3.new(0, 0.35, 0)), Color = IRON, CanCollide = false }, lantern)
	part({ Name = "Cap", Size = Vector3.new(0.85, 0.2, 0.85), CFrame = CFrame.new(tip - Vector3.new(0, 0.65, 0)), Color = IRON, CanCollide = false }, lantern)
	local glass = part({ Name = "Glass", Size = Vector3.new(0.6, 0.8, 0.6), CFrame = CFrame.new(tip - Vector3.new(0, 1.15, 0)), Color = GLOW, Material = Enum.Material.Neon, CanCollide = false, CastShadow = false }, lantern)
	part({ Name = "Base", Size = Vector3.new(0.75, 0.15, 0.75), CFrame = CFrame.new(tip - Vector3.new(0, 1.62, 0)), Color = IRON, CanCollide = false }, lantern)
	if l[4] then
		local light = Instance.new("PointLight")
		light.Color = GLOW
		light.Range = 12
		light.Brightness = 1.5
		light.Parent = glass
	end
	lantern.Parent = folder
end

-- 4. the signpost
do
	local at = Config.Map.At(SIGN[1], 0, SIGN[2])
	local y = groundAt(at.X, at.Z)
	local sign = Instance.new("Model")
	sign.Name = "Signpost"
	part({ Name = "Post", Size = Vector3.new(0.6, 7.6, 0.6), CFrame = CFrame.new(at.X, y + 7.6 / 2 - 0.3, at.Z), Color = POST_WOOD }, sign)
	for _, b in ipairs(BOARDS) do
		local way = Vector3.new(b[2][1], 0, b[2][2]).Unit
		local mid = Vector3.new(at.X, y + b[3], at.Z) + way * 2.55
		local cf = CFrame.fromMatrix(mid, way, Vector3.yAxis)
		local board = part({ Name = "Board_" .. b[1], Size = Vector3.new(4.6, 1, 0.25), CFrame = cf, Color = BOARD_WOOD, CanCollide = false }, sign)
		part({ Name = "Tip", Size = Vector3.new(0.72, 0.72, 0.25), CFrame = cf * CFrame.new(2.3, 0, 0) * CFrame.Angles(0, 0, math.rad(45)), Color = BOARD_WOOD, CanCollide = false }, sign)
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			local gui = Instance.new("SurfaceGui")
			gui.Face = face
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 60
			gui.LightInfluence = 0.3
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(0.9, 0.8)
			label.Position = UDim2.fromScale(0.05, 0.1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.FredokaOne
			label.TextScaled = true
			label.Text = b[1]
			label.TextColor3 = Color3.new(1, 1, 1)
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 3
			stroke.Color = TEXT_EDGE
			stroke.Parent = label
			label.Parent = gui
			gui.Parent = board
		end
	end
	sign.Parent = folder
end

folder.Parent = workspace
print(TAG, ("%d props (map crates, barrels and palms), %d lanterns, 1 signpost"):format(props, #LANTERNS))
