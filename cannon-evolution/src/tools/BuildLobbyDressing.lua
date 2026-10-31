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
	  - red, white and black flag bunting on poles along the booth boardwalk
	  - rope fences on wooden posts with brass caps down both sides of every training booth; the booths
	    themselves keep their colours and glow (from Alex's booth pictures, Oct 30)
	  - two palms framing the LAUNCH gate on the lobby side

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
local BRASS, ROPE = Color3.fromRGB(214, 172, 74), Color3.fromRGB(196, 164, 112)
-- lanterns: { x, z, the way the arm reaches {x, z}, glows }
local LANTERNS = {
	{ -37.8, -11.7, { 0, -1 } }, -- along the booth boardwalk, between booths
	{ -49.4, -11.7, { 0, -1 } },
	{ -72.6, -11.7, { 0, -1 } },
	{ -84.2, -11.7, { 0, -1 } },
	{ -81, 3.8, { 0, -1 } }, -- along the egg path, between eggs
	{ -97, 2.2, { 0, -1 } },
	{ -48.5, -2.6, { 0, 1 }, true }, -- framing the dock path where it leaves the plaza
	{ -48.5, 6.4, { 0, -1 }, true },
}
local GATE = { { -16, -6.4 }, { -16, 3.5 } } -- its two posts, either side of the dock path
local BUNTING = { { -97, -63.5 }, { -56.5, -25 } } -- spans along the booth boardwalk's south edge (x from, to)
local BUNTING_Z, POLE_H, SAG = -11.7, 9, 1.4
local FLAGS = { Color3.fromRGB(205, 45, 45), Color3.fromRGB(245, 240, 230), Color3.fromRGB(40, 36, 36) }
local BALL_SIGN = { -46.5, 9.8 }
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
	part({ Name = "Post", Size = Vector3.new(0.5, 5.7, 0.5), CFrame = CFrame.new(at.X, y + 5.7 / 2 - 0.3, at.Z), Color = POST_WOOD }, lantern)
	local tip = Vector3.new(at.X, top - 0.1, at.Z) + way * 1.5
	part({ Name = "Arm", Size = Vector3.new(0.3, 0.3, 1.8), CFrame = CFrame.lookAt(Vector3.new(at.X, top - 0.1, at.Z) + way * 0.75, tip), Color = POST_WOOD, CanCollide = false }, lantern)
	hangLantern(lantern, tip, l[4])
	lantern.Parent = folder
end

-- 3b. the LAUNCH gate over the dock path
do
	local a, b = Config.Map.At(GATE[1][1], 0, GATE[1][2]), Config.Map.At(GATE[2][1], 0, GATE[2][2])
	local y = math.max(groundAt(a.X, a.Z), groundAt(b.X, b.Z))
	local gate = Instance.new("Model")
	gate.Name = "LaunchGate"
	for _, p in ipairs({ a, b }) do
		part({ Name = "Post", Size = Vector3.new(1.1, 9.8, 1.1), CFrame = CFrame.new(p.X, y + 9.8 / 2 - 0.4, p.Z), Color = POST_WOOD }, gate)
	end
	local across = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local mid = Vector3.new((a.X + b.X) / 2, y + 9.2, (a.Z + b.Z) / 2)
	part({ Name = "Beam", Size = Vector3.new(1, 1, across.Magnitude + 2.6), CFrame = CFrame.lookAt(mid, mid + across), Color = POST_WOOD }, gate)
	-- the board hangs under the beam on two chains, its words facing the plaza and the dock
	local boardCf = CFrame.fromMatrix(mid - Vector3.new(0, 2.3, 0), across.Unit, Vector3.yAxis)
	board(gate, "LAUNCH", boardCf, 7, 1.9)
	for _, s in ipairs({ -2.6, 2.6 }) do
		local c = mid + across.Unit * s - Vector3.new(0, 0.9, 0)
		part({ Name = "Chain", Size = Vector3.new(0.12, 0.9, 0.12), CFrame = CFrame.new(c), Color = IRON, CanCollide = false }, gate)
	end
	-- a glowing lantern under each end of the beam, just inside the posts
	for _, s in ipairs({ -1, 1 }) do
		hangLantern(gate, mid + across.Unit * s * (across.Magnitude / 2 - 1.3) - Vector3.new(0, 0.5, 0), true)
	end
	gate.Parent = folder
end

-- 3c. flag bunting along the booth boardwalk
do
	local bunting = Instance.new("Model")
	bunting.Name = "Bunting"
	local flagN = 0
	for _, span in ipairs(BUNTING) do
		local a, b = Config.Map.At(span[1], 0, BUNTING_Z), Config.Map.At(span[2], 0, BUNTING_Z)
		local y = groundAt(a.X, a.Z)
		for _, p in ipairs({ a, b }) do
			part({ Name = "Pole", Size = Vector3.new(0.45, POLE_H + 0.4, 0.45), CFrame = CFrame.new(p.X, y + POLE_H / 2 - 0.2, p.Z), Color = POST_WOOD }, bunting)
		end
		local len = (b - a).Magnitude
		local n = math.floor(len / 1.6)
		local function at(t)
			local p = a:Lerp(b, t)
			return Vector3.new(p.X, y + POLE_H - 0.3 - SAG * 4 * t * (1 - t), p.Z)
		end
		local dir = (b - a).Unit
		local side = dir:Cross(Vector3.yAxis)
		local prev = at(0)
		for i = 1, n do
			local t = i / n
			local q = at(t)
			part({ Name = "Rope", Size = Vector3.new(0.08, 0.08, (q - prev).Magnitude), CFrame = CFrame.lookAt((prev + q) / 2, q), Color = Color3.fromRGB(90, 70, 50), CanCollide = false, CastShadow = false }, bunting)
			if i < n then
				-- a pennant pointing down: two thin wedges side by side
				flagN += 1
				local c = q - Vector3.new(0, 0.55, 0)
				local base = CFrame.fromMatrix(c, side, Vector3.yAxis)
				local col = FLAGS[(flagN - 1) % #FLAGS + 1]
				for _, half in ipairs({ base * CFrame.new(0, 0, 0.225) * CFrame.Angles(math.pi, 0, 0), base * CFrame.new(0, 0, -0.225) * CFrame.Angles(0, 0, math.pi) }) do
					local w = Instance.new("WedgePart")
					w.Name = "Flag"
					w.Anchored = true
					w.CanCollide = false
					w.CastShadow = false
					w.Size = Vector3.new(0.06, 1.1, 0.45)
					w.CFrame = half
					w.Color = col
					w.Material = Enum.Material.SmoothPlastic
					w.Parent = bunting
				end
			end
			prev = q
		end
	end
	bunting.Parent = folder
end

-- 3d. the CANNONBALLS board by the stand
do
	local at = Config.Map.At(BALL_SIGN[1], 0, BALL_SIGN[2])
	local y = groundAt(at.X, at.Z)
	local sign = Instance.new("Model")
	sign.Name = "BallSign"
	part({ Name = "Post", Size = Vector3.new(0.6, 7, 0.6), CFrame = CFrame.new(at.X, y + 3.2, at.Z), Color = POST_WOOD }, sign)
	local way = Vector3.new(1, 0, 0)
	local cf = CFrame.fromMatrix(Vector3.new(at.X, y + 5.6, at.Z) + way * 3.4, way, Vector3.yAxis)
	board(sign, "CANNONBALLS", cf, 6.4, 1.3)
	part({ Name = "Tip", Size = Vector3.new(0.92, 0.92, 0.25), CFrame = cf * CFrame.new(3.2, 0, 0) * CFrame.Angles(0, 0, math.rad(45)), Color = BOARD_WOOD, CanCollide = false }, sign)
	sign.Parent = folder
end

-- 3e. rope fences down both sides of every booth: posts at the front, middle and back, brass caps
do
	local stations = workspace:FindFirstChild("TrainingStations")
	local fences = Instance.new("Model")
	fences.Name = "BoothFences"
	local function rope(a, b)
		-- a rope from a to b, sagging a little in the middle, in four pieces
		local prev = a
		for i = 1, 4 do
			local t = i / 4
			local q = a:Lerp(b, t) - Vector3.new(0, 0.35 * 4 * t * (1 - t), 0)
			part({ Name = "Rope", Size = Vector3.new(0.14, 0.14, (q - prev).Magnitude + 0.05), CFrame = CFrame.lookAt((prev + q) / 2, q), Color = ROPE, CanCollide = false, CastShadow = false }, fences)
			prev = q
		end
	end
	for _, st in ipairs(stations and stations:GetChildren() or {}) do
		local booth = st:FindFirstChild("Booth")
		local rimCf, W, L
		for _, p in ipairs(booth and booth:GetChildren() or {}) do
			if p.Name == "Rim" then
				rimCf = rimCf or p.CFrame
				W, L = math.max(W or 0, p.Size.X), math.max(L or 0, p.Size.Z)
			end
		end
		if rimCf then
			local floorY = rimCf.Y - 0.3 -- the rim's bottom
			for _, sx in ipairs({ -1, 1 }) do
				local tops = {}
				for _, z in ipairs({ L / 2 - 0.4, 0, -(L / 2 - 0.4) }) do -- front (the way in), middle, back
					local base = (rimCf * CFrame.new(sx * (W / 2 + 0.45), 0, z)).Position
					local h = z > 0 and 3.6 or 3
					local post = Vector3.new(base.X, floorY, base.Z)
					part({ Name = "Post", Size = Vector3.new(0.55, h + 0.3, 0.55), CFrame = CFrame.new(post + Vector3.new(0, (h + 0.3) / 2 - 0.3, 0)), Color = POST_WOOD }, fences)
					local cap = part({ Name = "Cap", Shape = Enum.PartType.Ball, Size = Vector3.new(0.75, 0.75, 0.75), CFrame = CFrame.new(post + Vector3.new(0, h + 0.15, 0)), Color = BRASS, Material = Enum.Material.Metal, CanCollide = false }, fences)
					table.insert(tops, post + Vector3.new(0, 2.4, 0))
					if z > 0 then
						-- a little glow on the way in, in the booth's own colour
						local glow = part({ Name = "CapGlow", Size = Vector3.new(0.62, 0.1, 0.62), CFrame = CFrame.new(post + Vector3.new(0, h - 0.12, 0)), Color = st:GetAttribute("Accent") or GLOW, Material = Enum.Material.Neon, CanCollide = false, CastShadow = false }, fences)
						glow.Shape = Enum.PartType.Cylinder
						glow.Size = Vector3.new(0.1, 0.62, 0.62)
						glow.CFrame = CFrame.new(post + Vector3.new(0, h - 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
						cap.Size = Vector3.new(0.85, 0.85, 0.85)
					end
				end
				rope(tops[1], tops[2])
				rope(tops[2], tops[3])
			end
		end
	end
	fences.Parent = folder
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
		board(sign, b[1], cf, 4.6, 1)
		part({ Name = "Tip", Size = Vector3.new(0.72, 0.72, 0.25), CFrame = cf * CFrame.new(2.3, 0, 0) * CFrame.Angles(0, 0, math.rad(45)), Color = BOARD_WOOD, CanCollide = false }, sign)
	end
	sign.Parent = folder
end

folder.Parent = workspace
print(TAG, ("%d props (map crates, barrels and palms), %d nooks, %d lanterns, the LAUNCH gate, bunting and two signs"):format(props, #NOOKS, #LANTERNS))
