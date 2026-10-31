--[[
	BuildLobbyDressing  (run in Studio's Command Bar, Edit mode, after BuildWorld1, BuildLobbyWalkways and
	BuildLobbyExtras; run it again after BuildWorld1 moves the booths)

	Pirate dressing for the lobby (Alex, Oct 31: "we want to keep the pirate spirit ... make the lobby
	actually good"). Following the vault's set-dressing rules (LihFolk "World Composition and Set Dressing"):
	props sit in small groups at path corners and edges, never on a path or in front of a booth, egg or the
	stand; made things line up with the paths; everything stands on the ground.
	  - groups of crates and barrels, copied from the map's own (Alex's), and nooks of barrels and rocks
	    on the bare grass and sand (the vault's hub rule: no empty patch bigger than about 30x30 studs)
	  - two more of the map's palms in the empty grass between the eggs and the ship
	  - ship's lanterns on posts along the paths; the two by the plaza glow
	  - a wooden signpost by the spawn plaza (TRAINING, LAUNCH, EGGS) and a CANNONBALLS board by the stand
	  - a LAUNCH gate where the dock path reaches the dock: the lobby's focal point, framing the way out
	  - two palms framing the LAUNCH gate on the lobby side
	Oct 31, evening (Alex: "make the lobby way better"; vault notes 18-20, "World Composition and Set Dressing"):
	  - the LAUNCH gate became the lobby's hero: a tall arch with a big red LAUNCH! sign, gold bands, a glowing
	    gold strip and a fire bowl on each pillar, the brightest and tallest thing the spawn looks at
	  - festival flag strings on poles over the dock path, the leading line from the spawn to the arch
	  - bushes and flower clumps at the plaza edges (dense at the edges, nothing on the paths)
	  - the eggs moved next to the dock path (BuildLobbyExtras), so the CANNONBALLS board and the EGGS arm moved too
	  - nothing on or round the training lanes: they stay clean, like Stone Skipping's (Alex, Oct 31)

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
	{ -15.5, 15, 90 }, -- the cannonball stand's east end
}
-- nooks: { x, z (file units), turn, big } of barrels, a small crate and rocks
local NOOKS = {
	{ -77, 17.5, 20, true }, -- the grass between the eggs and the ship
	{ -100, 20, -30, true },
	{ -77, -8, 0 }, -- the grass strips between the plaza and the booths
	{ -42, -8, 0 },
	{ -26, 7.5, 60, true }, -- between the dock path and the stand
}
local NOOK_BIG = { -- { "Barrel"/"SmallCrate"/"Rock", x, z (studs), turn or rock size }
	{ "Barrel", -1.2, 0.5, 0 },
	{ "Barrel", 0.9, 1.3, 30 },
	{ "SmallCrate", 0.2, -1.4, 15 },
	{ "Rock", 2.6, -0.6, 1.7 },
	{ "Rock", -2.8, -1.2, 1.2 },
	{ "Rock", 1.9, 2.4, 0.9 },
}
local NOOK_SMALL = {
	{ "Barrel", 0, 0, 0 },
	{ "Barrel", 1.6, 0.7, 25 },
	{ "Rock", -1.5, -0.5, 1.3 },
	{ "Rock", -0.6, 1.5, 0.8 },
}
local ROCK = Color3.fromRGB(128, 124, 118)
-- one group: { template, x, z (studs, before the turn), turn, stacked on the item before }
local GROUP = {
	{ "Crate", 0, 0, 5 },
	{ "SmallCrate", 0.2, 0.1, -18, true },
	{ "Barrel", -2.9, 0.6, 0 },
	{ "Barrel", -2.2, -1.9, 40 },
	{ "SmallCrate", 2.6, 1.2, 12 },
}
local PALMS = { { -91, 18.5, 40 }, { -63, 20.5, 200 }, { -18.5, -10.5, 120 }, { -19, 9.5, 290 } }
-- lanterns: { x, z, the way the arm reaches {x, z}, glows }
local LANTERNS = {
	{ -81, 3.8, { 0, -1 } }, -- along the egg path, between eggs
	{ -97, 2.2, { 0, -1 } },
	{ -48.5, -2.6, { 0, 1 }, true }, -- framing the dock path where it leaves the plaza
	{ -48.5, 6.4, { 0, -1 }, true },
}
local GATE = { { -16, -6.4 }, { -16, 3.5 } } -- its two posts, either side of the dock path
local BALL_SIGN = { -31, 8 } -- between the dock path and the stand's west end (the eggs took the old spot, Oct 31)
local SIGN = { -53, -10.5 }
-- festival poles in pairs either side of the dock path, from the plaza to the arch: { x, z one side, z other side }
local FLAG_POLES = { { -44, -2.5, 6.25 }, { -37, -4, 5 }, { -30, -4.25, 1.75 } }
local FLAG_COLORS = { Color3.fromRGB(235, 60, 60), Color3.fromRGB(255, 205, 50), Color3.fromRGB(60, 150, 255), Color3.fromRGB(80, 210, 90), Color3.fromRGB(255, 255, 255) }
-- bush and flower clumps at the plaza edges: { x, z, bushes } (never on a path, a booth front, an egg or the stand)
local CLUMPS = { { -68, 7, 2 }, { -76, 9.5, 3 }, { -86, 7.5, 2 }, { -68.5, -7, 2 }, { -47, -7, 1 }, { -20, -7, 2 }, { -20, 6, 2 } }
local GOLD, NEON_GOLD, SIGN_RED = Color3.fromRGB(255, 196, 60), Color3.fromRGB(255, 214, 90), Color3.fromRGB(205, 48, 48)
local BOARDS = { -- { text, way it points {x, z}, height over the ground }
	{ "TRAINING", { 0, -1 }, 6.3 },
	{ "LAUNCH", { 1, 0 }, 5.2 },
	{ "EGGS", { 0.1, 1 }, 4.1 }, -- the eggs are south of the dock path now (Oct 31)
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

-- thin posts and poles don't collide, so running kids never snag on them (found walking it in Play)
-- a wooden board with words on both sides, its long side along cf's X
local function board(parent, text, cf, long, tall)
	local b = part({ Name = "Board_" .. text, Size = Vector3.new(long, tall, 0.25), CFrame = cf, Color = BOARD_WOOD, CanCollide = false }, parent)
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
		label.Text = text
		label.TextColor3 = Color3.new(1, 1, 1)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = TEXT_EDGE
		stroke.Parent = label
		label.Parent = gui
		gui.Parent = b
	end
	return b
end

-- a grey boulder, turned any way and sunk into the ground (grown things vary)
local rockRng = Random.new(11)
local function rock(parent, x, z, size, floor)
	part({
		Name = "Rock",
		Size = Vector3.new(size, size * 0.75, size * rockRng:NextNumber(0.8, 1.1)),
		CFrame = CFrame.new(x, floor + size * 0.15, z)
			* CFrame.Angles(math.rad(rockRng:NextNumber(-20, 20)), rockRng:NextNumber(0, math.pi * 2), math.rad(rockRng:NextNumber(-20, 20))),
		Color = ROCK:Lerp(Color3.new(1, 1, 1), rockRng:NextNumber(-0.05, 0.1)),
	}, parent)
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

-- 2b. nooks of barrels and rocks
for ni, nk in ipairs(NOOKS) do
	local nook = Instance.new("Model")
	nook.Name = "Nook" .. ni
	local centre = Config.Map.At(nk[1], 0, nk[2])
	local turn = CFrame.Angles(0, math.rad(nk[3]), 0)
	for _, item in ipairs(nk[4] and NOOK_BIG or NOOK_SMALL) do
		local off = turn * Vector3.new(item[2], 0, item[3])
		local x, z = centre.X + off.X, centre.Z + off.Z
		if item[1] == "Rock" then
			rock(nook, x, z, item[4], groundAt(x, z))
		elseif place(item[1], x, z, nk[3] + item[4], groundAt(x, z), nook) then
			props += 1
		end
	end
	nook.Parent = folder
end

-- 3. ship's lanterns
-- a lantern hanging from `tip` (the end of an arm or a beam)
local function hangLantern(parent, tip, glows)
	part({ Name = "Hook", Size = Vector3.new(0.1, 0.45, 0.1), CFrame = CFrame.new(tip - Vector3.new(0, 0.35, 0)), Color = IRON, CanCollide = false }, parent)
	part({ Name = "Cap", Size = Vector3.new(0.85, 0.2, 0.85), CFrame = CFrame.new(tip - Vector3.new(0, 0.65, 0)), Color = IRON, CanCollide = false }, parent)
	local glass = part({ Name = "Glass", Size = Vector3.new(0.6, 0.8, 0.6), CFrame = CFrame.new(tip - Vector3.new(0, 1.15, 0)), Color = GLOW, Material = Enum.Material.Neon, CanCollide = false, CastShadow = false }, parent)
	part({ Name = "Base", Size = Vector3.new(0.75, 0.15, 0.75), CFrame = CFrame.new(tip - Vector3.new(0, 1.62, 0)), Color = IRON, CanCollide = false }, parent)
	if glows then
		local light = Instance.new("PointLight")
		light.Color = GLOW
		light.Range = 12
		light.Brightness = 1.5
		light.Parent = glass
	end
end
for i, l in ipairs(LANTERNS) do
	local at = Config.Map.At(l[1], 0, l[2])
	local y = groundAt(at.X, at.Z)
	local way = Vector3.new(l[3][1], 0, l[3][2]).Unit
	local lantern = Instance.new("Model")
	lantern.Name = "Lantern" .. i
	local top = y + 5.4
	part({ Name = "Post", Size = Vector3.new(0.5, 5.7, 0.5), CFrame = CFrame.new(at.X, y + 5.7 / 2 - 0.3, at.Z), Color = POST_WOOD, CanCollide = false }, lantern)
	local tip = Vector3.new(at.X, top - 0.1, at.Z) + way * 1.5
	part({ Name = "Arm", Size = Vector3.new(0.3, 0.3, 1.8), CFrame = CFrame.lookAt(Vector3.new(at.X, top - 0.1, at.Z) + way * 0.75, tip), Color = POST_WOOD, CanCollide = false }, lantern)
	hangLantern(lantern, tip, l[4])
	lantern.Parent = folder
end

-- a string of diamond flags from a to b (thin, never collides or blocks the camera)
local function bunting(parent, a, b)
	local d = b - a
	local len = d.Magnitude
	local mid = (a + b) / 2
	part({ Name = "Rope", Size = Vector3.new(0.12, 0.12, len), CFrame = CFrame.lookAt(mid, b), Color = TEXT_EDGE, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }, parent)
	local n = math.max(2, math.floor(len / 1.7))
	for i = 1, n do
		local at = a + d * ((i - 0.5) / n) - Vector3.new(0, 0.42, 0)
		part({
			Name = "Flag",
			Size = Vector3.new(0.85, 0.85, 0.08),
			CFrame = CFrame.fromMatrix(at, d.Unit, Vector3.yAxis) * CFrame.Angles(0, 0, math.rad(45)),
			Color = FLAG_COLORS[(i - 1) % #FLAG_COLORS + 1],
			CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		}, parent)
	end
end

-- 3b. the LAUNCH arch over the dock path: the lobby's hero, the tallest and brightest thing the spawn faces
do
	local a, b = Config.Map.At(GATE[1][1], 0, GATE[1][2]), Config.Map.At(GATE[2][1], 0, GATE[2][2])
	local y = math.max(groundAt(a.X, a.Z), groundAt(b.X, b.Z))
	local gate = Instance.new("Model")
	gate.Name = "LaunchGate"
	local across = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local toPlaza = Vector3.new(-1, 0, 0) -- the spawn is west of the dock
	local H = 15
	for _, p in ipairs({ a, b }) do
		local base = Vector3.new(p.X, y, p.Z)
		part({ Name = "Plinth", Size = Vector3.new(3.8, 1.2, 3.8), CFrame = CFrame.new(base + Vector3.new(0, 0.4, 0)), Color = Color3.fromRGB(150, 150, 162) }, gate)
		part({ Name = "Pillar", Size = Vector3.new(2.6, H, 2.6), CFrame = CFrame.new(base + Vector3.new(0, H / 2, 0)), Color = POST_WOOD }, gate)
		for _, h in ipairs({ 2.6, 7.5, 12.4 }) do
			part({ Name = "Band", Size = Vector3.new(2.85, 0.5, 2.85), CFrame = CFrame.new(base + Vector3.new(0, h, 0)), Color = GOLD, CanCollide = false }, gate)
		end
		-- a glowing gold strip up the side that faces the spawn (steady, never flashing)
		part({ Name = "GlowStrip", Size = Vector3.new(0.25, H - 3.4, 0.5), CFrame = CFrame.new(base + toPlaza * 1.36 + Vector3.new(0, H / 2 + 0.3, 0)), Color = NEON_GOLD,
			Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CastShadow = false }, gate)
		part({ Name = "Cap", Size = Vector3.new(3.3, 0.8, 3.3), CFrame = CFrame.new(base + Vector3.new(0, H + 0.4, 0)), Color = GOLD }, gate)
		-- a fire bowl on top: real fire and a warm light, seen from the whole plaza
		local bowl = part({ Name = "FireBowl", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 2.8, 2.8),
			CFrame = CFrame.new(base + Vector3.new(0, H + 1.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = IRON, CanCollide = false }, gate)
		local fire = Instance.new("Fire")
		fire.Size = 6
		fire.Heat = 10
		fire.Color = Color3.fromRGB(255, 140, 40)
		fire.SecondaryColor = Color3.fromRGB(255, 225, 90)
		fire.Parent = bowl
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 170, 80)
		light.Range = 22
		light.Brightness = 2.2
		light.Shadows = false
		light.Parent = bowl
	end
	-- the crossbeam and the big LAUNCH! sign under it, words on both faces
	local top = Vector3.new((a.X + b.X) / 2, y + H - 1.6, (a.Z + b.Z) / 2)
	part({ Name = "Beam", Size = Vector3.new(1.8, 1.8, across.Magnitude + 3.6), CFrame = CFrame.lookAt(top, top + across), Color = POST_WOOD }, gate)
	local signCf = CFrame.fromMatrix(top - Vector3.new(0, 3.1, 0), across.Unit, Vector3.yAxis)
	local SW, SH = 15, 4
	part({ Name = "SignFrame", Size = Vector3.new(SW + 0.8, SH + 0.8, 0.4), CFrame = signCf, Color = GOLD, CanCollide = false }, gate)
	local sign = part({ Name = "Board_LAUNCH", Size = Vector3.new(SW, SH, 0.55), CFrame = signCf, Color = SIGN_RED, CanCollide = false }, gate)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 24 -- low on purpose: TextScaled stops at 100 px, so a dense canvas left the words small
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.92, 0.84)
		label.Position = UDim2.fromScale(0.04, 0.08)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = "LAUNCH!"
		label.TextColor3 = Color3.new(1, 1, 1)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 6
		stroke.Color = Color3.fromRGB(90, 20, 20)
		stroke.Parent = label
		label.Parent = gui
		gui.Parent = sign
	end
	-- flags along the beam, and a glowing lantern under each end
	local half = across.Unit * (across.Magnitude / 2 + 1.2)
	bunting(gate, top - half - Vector3.new(0, 0.9, 0), top + half - Vector3.new(0, 0.9, 0))
	for _, s in ipairs({ -1, 1 }) do
		hangLantern(gate, top + across.Unit * s * (across.Magnitude / 2 - 2) - Vector3.new(0, 1.2, 0), true)
	end
	gate.Parent = folder
end

-- 3c. festival flag strings over the dock path: the leading line from the spawn to the arch
do
	local avenue = Instance.new("Model")
	avenue.Name = "FlagStrings"
	local tops = {}
	for i, fp in ipairs(FLAG_POLES) do
		tops[i] = {}
		for side = 1, 2 do
			local at = Config.Map.At(fp[1], 0, fp[side + 1])
			local y = groundAt(at.X, at.Z)
			local H = 9.4
			part({ Name = "Pole", Size = Vector3.new(0.5, H, 0.5), CFrame = CFrame.new(at.X, y + H / 2 - 0.3, at.Z), Color = POST_WOOD, CanCollide = false }, avenue)
			part({ Name = "Knob", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), CFrame = CFrame.new(at.X, y + H - 0.1, at.Z), Color = GOLD, CanCollide = false }, avenue)
			part({ Name = "Pennant", Size = Vector3.new(0.08, 1.1, 1.7), CFrame = CFrame.new(at.X, y + H - 1.2, at.Z + 0.9), Color = FLAG_COLORS[(i + side) % 3 + 1], CanCollide = false, CanQuery = false }, avenue)
			tops[i][side] = Vector3.new(at.X, y + H - 1.6, at.Z)
		end
		bunting(avenue, tops[i][1], tops[i][2]) -- across the path
		if i > 1 then
			for side = 1, 2 do
				bunting(avenue, tops[i - 1][side], tops[i][side]) -- along each side
			end
		end
	end
	avenue.Parent = folder
end

-- 3d. the CANNONBALLS board by the stand
do
	local at = Config.Map.At(BALL_SIGN[1], 0, BALL_SIGN[2])
	local y = groundAt(at.X, at.Z)
	local sign = Instance.new("Model")
	sign.Name = "BallSign"
	part({ Name = "Post", Size = Vector3.new(0.6, 7, 0.6), CFrame = CFrame.new(at.X, y + 3.2, at.Z), Color = POST_WOOD, CanCollide = false }, sign)
	local way = Vector3.new(1, 0, 0)
	local cf = CFrame.fromMatrix(Vector3.new(at.X, y + 5.6, at.Z) + way * 3.4, way, Vector3.yAxis)
	board(sign, "CANNONBALLS", cf, 6.4, 1.3)
	part({ Name = "Tip", Size = Vector3.new(0.92, 0.92, 0.25), CFrame = cf * CFrame.new(3.2, 0, 0) * CFrame.Angles(0, 0, math.rad(45)), Color = BOARD_WOOD, CanCollide = false }, sign)
	sign.Parent = folder
end

-- 4. the signpost
do
	local at = Config.Map.At(SIGN[1], 0, SIGN[2])
	local y = groundAt(at.X, at.Z)
	local sign = Instance.new("Model")
	sign.Name = "Signpost"
	part({ Name = "Post", Size = Vector3.new(0.6, 7.6, 0.6), CFrame = CFrame.new(at.X, y + 7.6 / 2 - 0.3, at.Z), Color = POST_WOOD, CanCollide = false }, sign)
	for _, b in ipairs(BOARDS) do
		local way = Vector3.new(b[2][1], 0, b[2][2]).Unit
		local mid = Vector3.new(at.X, y + b[3], at.Z) + way * 2.55
		local cf = CFrame.fromMatrix(mid, way, Vector3.yAxis)
		board(sign, b[1], cf, 4.6, 1)
		part({ Name = "Tip", Size = Vector3.new(0.72, 0.72, 0.25), CFrame = cf * CFrame.new(2.3, 0, 0) * CFrame.Angles(0, 0, math.rad(45)), Color = BOARD_WOOD, CanCollide = false }, sign)
	end
	sign.Parent = folder
end

-- 5. bushes and flower clumps at the plaza edges: odd groups, grown things turned any way, nothing on a path
do
	local rng = Random.new(31)
	local GREENS = { Color3.fromRGB(70, 175, 70), Color3.fromRGB(95, 200, 80), Color3.fromRGB(55, 150, 75) }
	local PETALS = { Color3.fromRGB(255, 120, 190), Color3.fromRGB(255, 220, 70), Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 120, 255), Color3.fromRGB(255, 90, 80) }
	local deco = { CanCollide = false, CanQuery = false, CanTouch = false }
	for ci, c in ipairs(CLUMPS) do
		local clump = Instance.new("Model")
		clump.Name = "Clump" .. ci
		local at = Config.Map.At(c[1], 0, c[2])
		for bi = 1, c[3] do
			local ang = rng:NextNumber(0, math.pi * 2)
			local off = bi == 1 and Vector3.zero or Vector3.new(math.cos(ang), 0, math.sin(ang)) * rng:NextNumber(2.2, 3.2)
			local x, z = at.X + off.X, at.Z + off.Z
			local y = groundAt(x, z)
			local big = (bi == 1 and 3.6 or 2.6) * rng:NextNumber(0.9, 1.1)
			for _, ball in ipairs({ { 0, 0, 1 }, { 0.45, 0.3, 0.75 }, { -0.4, -0.35, 0.7 } }) do
				local sz = big * ball[3]
				local p = part({ Name = "Bush", Shape = Enum.PartType.Ball, Size = Vector3.new(sz, sz, sz),
					CFrame = CFrame.new(x + ball[1] * big * 0.6, y + sz * 0.38, z + ball[2] * big * 0.6), Color = GREENS[rng:NextInteger(1, #GREENS)] }, clump)
				for key, v in pairs(deco) do
					p[key] = v
				end
			end
		end
		-- a ring of flowers round the front of the clump
		for fi = 1, 7 do
			local ang = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(2.4, 4.4)
			local x, z = at.X + math.cos(ang) * r, at.Z + math.sin(ang) * r
			local y = groundAt(x, z)
			local stem = part({ Name = "Stem", Size = Vector3.new(0.18, 0.9, 0.18), CFrame = CFrame.new(x, y + 0.4, z), Color = GREENS[3] }, clump)
			local color = PETALS[(ci + fi) % #PETALS + 1]
			local flower = part({ Name = "Flower", Size = Vector3.new(0.75, 0.32, 0.75), CFrame = CFrame.new(x, y + 0.95, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color = color }, clump)
			local middle = part({ Name = "Middle", Size = Vector3.new(0.32, 0.36, 0.32), CFrame = flower.CFrame, Color = Color3.fromRGB(255, 200, 40) }, clump)
			for _, q in ipairs({ stem, flower, middle }) do
				for key, v in pairs(deco) do
					q[key] = v
				end
			end
		end
		clump.Parent = folder
	end
end

folder.Parent = workspace
print(TAG, ("%d props (map crates, barrels and palms), %d nooks, %d lanterns, the LAUNCH arch, %d flag poles, %d flower clumps and two signs"):format(props, #NOOKS, #LANTERNS, #FLAG_POLES * 2, #CLUMPS))
