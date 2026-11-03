-- Vice Bay builder library v2 (edit-time only). Load with:
--   local L = require(game.ServerStorage.VB.Core:Clone())
-- Source of truth: ROBLOX/Vice Bay/src (Obsidian vault). Lessons: see "Map Building Lessons".
local CS = game:GetService("CollectionService")
local MS = game:GetService("MaterialService")
local L = {}
local M = Enum.Material
L.M = M
local TAU = math.pi * 2
L.TAU = TAU
L.G = 2 -- street level (terrain top, voxel grid lands at y = 2 mod 4)
L.WATER = -4

L.rng = Random.new(1337)
function L.seed(s) L.rng = Random.new(s) end
function L.r(a, b) return a + L.rng:NextNumber() * (b - a) end
function L.ri(a, b) return L.rng:NextInteger(a, b) end
function L.pick(t) return t[L.rng:NextInteger(1, #t)] end
function L.chance(p) return L.rng:NextNumber() < p end
function L.C(r, g, b) return Color3.fromRGB(r, g, b) end
local C = L.C
function L.shade(c, k) return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1)) end
function L.jitter(c, k) k = k or 0.06 return L.shade(c, 1 + L.r(-k, k)) end

-- realistic texture set (vault: realistic-textures/texture-manifest.json): name -> {base material, studs per tile}
L.VARS = {HoodAsphaltCracked={"Asphalt",11},HoodAsphaltFaded={"Asphalt",14},HoodRoadPotholes={"Asphalt",8},AsphaltWorn={"Asphalt",7},DowntownAsphaltClean={"Asphalt",7},AsphaltGranular={"Asphalt",9},SidewalkConcrete={"Concrete",6},HoodSidewalkCracked={"Concrete",7},DowntownSidewalkTiles={"Concrete",8},DowntownPavers={"Concrete",6},SidewalkSlabs={"Concrete",7},DowntownBrickPavers={"Brick",6},ConcreteDriveway={"Concrete",6},ParkingLotStained={"Concrete",7},ConcreteStained={"Concrete",9},HoodStuccoWorn={"Plaster",7},HoodPaintedConcrete={"Concrete",7},HoodConcreteDirty={"Concrete",8},HoodStuccoCracked={"Plaster",4},HoodPlasterChipped={"Plaster",7},HoodPlasterExposedBrick={"Plaster",7},HoodPaintedBrick={"Brick",6},HoodPaintedBrickYellow={"Brick",6},HoodBrickDamaged={"Brick",11},HoodCinderBlock={"Concrete",6},StuccoSuburb={"Plaster",11},DowntownBrickRed={"Brick",9},DowntownBrickOld={"Brick",5},DowntownPrecastPanel={"Concrete",8},DowntownConcreteFacade={"Concrete",7},DowntownRibbedConcrete={"Concrete",7},DowntownStoneBlocks={"Sandstone",11},DowntownRender={"Plaster",7},BridgeConcretePanels={"Concrete",29},LobbyMarble={"Marble",14},PlazaTiles={"CeramicTiles",6},ShutterRusty={"CorrodedMetal",7},ShutterPainted={"Metal",7},CorrugatedWorn={"CorrodedMetal",6},CorrugatedRusty={"CorrodedMetal",7},ShippingContainer={"Metal",7},MetalPaintedRusty={"CorrodedMetal",8},MetalPlate={"DiamondPlate",7},IndustrialWall={"Metal",11},RoofBoxProfile={"Metal",7},WoodPaintedDistressed={"WoodPlanks",6},WoodPlanksOld={"WoodPlanks",7},RoofShinglesGrey={"RoofShingles",11},RoofClayTiles={"ClayRoofTiles",9},RoofFlatBitumen={"Asphalt",7},DirtLot={"Ground",7},GravelLot={"Pebble",11},BeachSand={"Sand",11},RockGrey={"Rock",6},RockMossy={"Rock",11},MudDry={"Mud",5},RoadDamagedB={"Asphalt",8},AsphaltDarkFresh={"Asphalt",11},AsphaltPlain={"Asphalt",7},ParkingLotAsphalt={"Asphalt",8},AsphaltTarPatch={"Asphalt",8},AsphaltAerialWide={"Asphalt",107},SidewalkWornStained={"Concrete",11},SidewalkCrackedB={"Concrete",7},LotConcreteWorn={"Concrete",7},ConcretePlain={"Concrete",14},ChannelConcreteDirty={"Concrete",11},ChannelConcreteDamaged={"Concrete",18},ConcreteLayers={"Concrete",7},OverpassConcrete={"Concrete",7},OverpassPrecast={"Concrete",14},ChannelWall={"Concrete",10},BoardFormedConcrete={"Concrete",6},CinderBlockB={"Concrete",7},StuccoWhite={"Plaster",7},StuccoBlueWeathered={"Plaster",7},StuccoPinkWeathered={"Plaster",7},StuccoYellow={"Plaster",7},StuccoBeige={"Plaster",11},PlasterWorn={"Plaster",6},PlasterCrackedB={"Plaster",6},StuccoGreyFine={"Plaster",4},PlasterMossyHumid={"Plaster",6},HoodBrickDark={"Brick",4},BrickRedClassic={"Brick",11},BrickBrownOld={"Brick",7},BrickMixed={"Brick",6},BrickBroken={"Brick",6},ConcreteBrick={"Brick",11},ShutterRustedB={"CorrodedMetal",6},ShutterWorn={"Metal",5},CorrugatedPlain={"Metal",4},CorrugatedB={"Metal",10},DumpsterGreenRust={"CorrodedMetal",4},RustyGrate={"CorrodedMetal",6},MetalBluePlate={"Metal",9},RustySheet={"CorrodedMetal",7},RustCoarse={"CorrodedMetal",8},SidingBlue={"WoodPlanks",4},SidingBlack={"WoodPlanks",6},FenceWoodRaw={"WoodPlanks",7},FenceGreenRough={"WoodPlanks",5},RoofSlatesDark={"Slate",11},RoofClayMission={"ClayRoofTiles",14},RoofCeramic={"ClayRoofTiles",12},RoofRedSlate={"Slate",9},PalmBark={"Wood",7},PalmBarkB={"Wood",5},ParkDirt={"Ground",11},DryGround={"Ground",14},LeafLitter={"LeafyGrass",11},DryLeaves={"LeafyGrass",7},MudLeaves={"Mud",5},DryMudField={"Mud",11},GravelRoad={"Pebble",7},GravelLeaves={"Pebble",6},CoralGravel={"Pebble",7},BeachSandB={"Sand",14},HerringbonePavers={"Pavement",9},InterlockPavers={"Pavement",6},BrickPavementB={"Pavement",7}}

local hasVar = {}
for _, v in ipairs(MS:GetDescendants()) do
	if v:IsA("MaterialVariant") then hasVar[v.Name] = true end
end
L.hasVar = hasVar

-- After textures are uploaded: give every tagged part its MaterialVariant in one pass.
function L.applyVariants(root)
	local have = {}
	for _, v in ipairs(MS:GetDescendants()) do
		if v:IsA("MaterialVariant") then have[v.Name] = v end
	end
	local n = 0
	for i, p in ipairs((root or workspace):GetDescendants()) do
		if p:IsA("BasePart") then
			local vn = p:GetAttribute("VBVar")
			local v = vn and have[vn]
			if v and p.Material == v.BaseMaterial then
				p.MaterialVariant = vn
				n += 1
			end
		end
		if i % 20000 == 0 then task.wait() end
	end
	return n
end

function L.folder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f
end
function L.root(name)
	return L.folder(L.folder(workspace, "ViceBay"), name)
end
function L.model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function apply(p, size, cf, color, mat, var, opt)
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color or C(200, 200, 200)
	if var then
		local vb = L.VARS[var]
		if vb then mat = M[vb[1]] end
		p:SetAttribute("VBVar", var)
	end
	p.Material = mat or M.SmoothPlastic
	if var and hasVar[var] then p.MaterialVariant = var end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	local vol = size.X * size.Y * size.Z
	if vol < 60 then
		p.CastShadow = false
		if vol < 8 then p.CanQuery = false end
	end
	if opt then for k, v in pairs(opt) do p[k] = v end end
	return p
end
function L.P(parent, size, cf, color, mat, var, opt)
	local p = apply(Instance.new("Part"), size, cf, color, mat, var, opt)
	p.Parent = parent
	return p
end
-- decoration: never collides, never shadows
function L.D(parent, size, cf, color, mat, var, opt)
	local p = apply(Instance.new("Part"), size, cf, color, mat, var, opt)
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Parent = parent
	return p
end
function L.W(parent, size, cf, color, mat, var, opt)
	local p = apply(Instance.new("WedgePart"), size, cf, color, mat, var, opt)
	p.Parent = parent
	return p
end
function L.CW(parent, size, cf, color, mat, var, opt)
	local p = apply(Instance.new("CornerWedgePart"), size, cf, color, mat, var, opt)
	p.Parent = parent
	return p
end
-- vertical cylinder: height h, diameter d, centred at cf
function L.Cyl(parent, h, d, cf, color, mat, var, opt)
	local p = apply(Instance.new("Part"), Vector3.new(h, d, d), cf * CFrame.Angles(0, 0, math.pi / 2), color, mat, var, opt)
	p.Shape = Enum.PartType.Cylinder
	p.Parent = parent
	return p
end
function L.Ball(parent, d, cf, color, mat, var, opt)
	local p = apply(Instance.new("Part"), Vector3.new(d, d, d), cf, color, mat, var, opt)
	p.Shape = Enum.PartType.Ball
	p.Parent = parent
	return p
end
-- box resting on y0 in the local frame cf
function L.B(parent, cf, x, y0, z, sx, sy, sz, color, mat, var, opt)
	return L.P(parent, Vector3.new(sx, sy, sz), cf * CFrame.new(x, y0 + sy / 2, z), color, mat, var, opt)
end
function L.BD(parent, cf, x, y0, z, sx, sy, sz, color, mat, var, opt)
	return L.D(parent, Vector3.new(sx, sy, sz), cf * CFrame.new(x, y0 + sy / 2, z), color, mat, var, opt)
end
-- a beam between two points (rails, pipes, wires that need collision)
function L.bar(parent, a, b, t, color, mat, opt)
	local len = (b - a).Magnitude
	return L.D(parent, Vector3.new(t, t, len), CFrame.lookAt((a + b) / 2, b), color, mat, nil, opt)
end

-- SLIM / streaming level of detail for a finished static building model
function L.lod(m)
	pcall(function() m.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh end)
	pcall(function() m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end)
end

-- terrain / ground height at x,z (ray from high up so hills work)
local rpT = RaycastParams.new()
rpT.FilterType = Enum.RaycastFilterType.Include
rpT.FilterDescendantsInstances = { workspace.Terrain }
rpT.IgnoreWater = false
function L.groundY(x, z)
	local r = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -500, 0), rpT)
	if r then return r.Position.Y, r.Material end
	return L.G, nil
end
function L.isWater(x, z)
	local y, m = L.groundY(x, z)
	return m == M.Water or y < L.G - 1.5
end

-- SurfaceGui text on a part face
function L.text(part, face, txt, opt)
	opt = opt or {}
	local g = Instance.new("SurfaceGui")
	g.Face = face or Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = opt.pps or 25
	g.LightInfluence = opt.light or 0.6
	g.MaxDistance = opt.dist or 260
	g.Brightness = opt.bright or 1
	g.Parent = part
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = opt.bg and 0 or 1
	if opt.bg then t.BackgroundColor3 = opt.bg end
	t.BorderSizePixel = 0
	t.Size = opt.size or UDim2.fromScale(1, 1)
	t.Position = opt.pos or UDim2.fromScale(0, 0)
	t.AnchorPoint = opt.anchor or Vector2.new(0, 0)
	t.Rotation = opt.rot or 0
	t.Text = txt
	t.TextScaled = true
	t.RichText = opt.rich or false
	t.Font = opt.font or Enum.Font.GothamBlack
	t.TextColor3 = opt.color or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = opt.stroke or 1
	t.TextStrokeColor3 = opt.strokeColor or Color3.new(0, 0, 0)
	t.TextTransparency = opt.trans or 0
	t.Parent = g
	return g, t
end
function L.sign(parent, cf, sx, sy, txt, bg, fg, font, opt)
	opt = opt or {}
	local p = L.D(parent, Vector3.new(sx, sy, opt.depth or 0.5), cf, bg or C(30, 30, 30), opt.mat or M.SmoothPlastic)
	p.Name = "Sign"
	local o2 = { color = fg, font = font, pps = opt.pps, dist = opt.dist, light = opt.light, stroke = opt.stroke, size = opt.size or UDim2.fromScale(0.92, 0.8), pos = UDim2.fromScale(0.04, 0.1), bright = opt.bright }
	L.text(p, Enum.NormalId.Front, txt, o2)
	if opt.both then L.text(p, Enum.NormalId.Back, txt, o2) end
	if opt.lit then
		local pl = Instance.new("SurfaceLight")
		pl.Face = Enum.NormalId.Front
		pl.Range = 10
		pl.Brightness = 0.8
		pl.Color = fg or Color3.new(1, 1, 1)
		pl.Shadows = false
		pl.Parent = p
	end
	return p
end

-- graffiti: kid-safe tags, only within reach (lower ~8 studs of the face)
L.TAGS = { "305", "VICE", "DREAMS", "BLESSED", "ZOE", "KING RO", "WESTSIDE", "LIBERTY", "MIAMI", "HOPE", "STAY UP", "DADE", "ROCKY", "NO DAYS OFF", "SUNNY", "REZ", "OG", "LUV", "SKY", "DUKE", "MIKO", "NOVA", "KASH", "TOY" }
L.TAGCOLORS = { C(255, 80, 160), C(80, 200, 255), C(255, 220, 60), C(120, 255, 120), C(255, 120, 40), C(240, 240, 240), C(180, 90, 255), C(255, 60, 60), C(20, 20, 20) }
function L.graffiti(part, face, txt)
	local fs = part.Size
	local fw, fh
	if face == Enum.NormalId.Left or face == Enum.NormalId.Right then fw, fh = fs.Z, fs.Y else fw, fh = fs.X, fs.Y end
	local sy = math.min(0.4, L.r(2.6, 4.6) / fh)
	local sx = math.min(0.8, L.r(7, 14) / fw)
	local py = 1 - sy - L.r(0.8, 2.4) / fh
	L.text(part, face, txt or L.pick(L.TAGS), {
		font = L.pick({ Enum.Font.PermanentMarker, Enum.Font.FredokaOne, Enum.Font.Bangers, Enum.Font.Creepster, Enum.Font.Kalam }),
		color = L.pick(L.TAGCOLORS), stroke = L.chance(0.5) and 0.2 or 1,
		size = UDim2.fromScale(sx, sy), pos = UDim2.fromScale(L.r(0.02, math.max(0.03, 1 - sx - 0.02)), py),
		rot = L.r(-7, 7), dist = 180, pps = 10, light = 1,
	})
end

-- big multi-colour graffiti "piece" across a wall (bubble letters with outline + throw-ups), like the reference walls
L.PIECES = { "VICE", "DADE", "305", "MIAMI", "LIBERTY", "SOUL", "RISE", "KING", "WAVE", "DREAM" }
function L.piece(part, face)
	local fs = part.Size
	local fw, fh
	if face == Enum.NormalId.Left or face == Enum.NormalId.Right then fw, fh = fs.Z, fs.Y else fw, fh = fs.X, fs.Y end
	local sx = math.min(0.85, L.r(22, 34) / fw)
	local sy = math.min(0.55, L.r(7, 11) / fh)
	local fill = L.pick({ C(90, 200, 255), C(255, 120, 200), C(255, 210, 60), C(120, 240, 120), C(250, 130, 50), C(180, 120, 255) })
	local px, py = L.r(0.02, math.max(0.03, 0.98 - sx)), math.max(0.05, 1 - sy - L.r(0.05, 0.35))
	local word = L.pick(L.PIECES)
	-- back shadow + outline + fill (3 stacked labels = cheap depth)
	L.text(part, face, word, { font = Enum.Font.Bangers, color = C(20, 20, 24), size = UDim2.fromScale(sx, sy), pos = UDim2.fromScale(px + 0.006, py + 0.012), pps = 6, dist = 260, light = 1, rot = L.r(-4, 4) })
	L.text(part, face, word, { font = Enum.Font.Bangers, color = fill, stroke = 0, strokeColor = L.pick({ C(255, 255, 255), C(30, 30, 30), C(255, 60, 60) }), size = UDim2.fromScale(sx, sy), pos = UDim2.fromScale(px, py), pps = 6, dist = 260, light = 1, rot = L.r(-4, 4) })
end

------------------------------------------------------------------
-- POINTS OF INTEREST (tagged for gameplay scripts + floating map icons)
L.CAT = {
	Job = { tag = "JobSpot", color = C(242, 153, 74), glyph = "JOB", prompt = "Start Job" },
	Service = { tag = "JobSpot", color = C(255, 107, 107), glyph = "+", prompt = "Clock In" },
	Finance = { tag = "Finance", color = C(255, 210, 74), glyph = "$", prompt = "Open" },
	Dealer = { tag = "Dealership", color = C(78, 168, 255), glyph = "CAR", prompt = "Browse" },
	Shop = { tag = "Shop", color = C(180, 140, 255), glyph = "SHOP", prompt = "Shop" },
	Park = { tag = "Park", color = C(63, 199, 181), glyph = "PARK" },
	Property = { tag = "Property", color = C(255, 143, 199), glyph = "HOME", prompt = "View Property" },
	Dock = { tag = "BoatDock", color = C(150, 210, 240), glyph = "DOCK", prompt = "Spawn Boat" },
	Gas = { tag = "GasStation", color = C(255, 190, 90), glyph = "GAS", prompt = "Refuel" },
	Metro = { tag = "MetroStation", color = C(255, 206, 40), glyph = "M", prompt = "Take the Metro" },
	Helipad = { tag = "Helipad", color = C(255, 214, 60), glyph = "H", prompt = "Call Helicopter" },
	ATM = { tag = "ATM", color = C(120, 220, 140), glyph = "ATM", prompt = "Use ATM" },
}
function L.poi(pos, cat, name, attrs, opts)
	opts = opts or {}
	local c = L.CAT[cat]
	local root = L.root("POIs")
	local old = root:FindFirstChild(name)
	if old then old:Destroy() end
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.new(4, 4, 4)
	p.Position = pos + Vector3.new(0, 2.5, 0)
	p:SetAttribute("Category", cat)
	p:SetAttribute("DisplayName", name)
	if attrs then for k, v in pairs(attrs) do p:SetAttribute(k, v) end end
	CS:AddTag(p, c.tag)
	CS:AddTag(p, "POI")
	if c.prompt and not opts.noPrompt then
		local pp = Instance.new("ProximityPrompt")
		pp.ActionText = opts.action or c.prompt
		pp.ObjectText = name
		pp.MaxActivationDistance = 10
		pp.RequiresLineOfSight = false
		pp.HoldDuration = 0.3
		pp.Parent = p
	end
	if not opts.noIcon then
		local bb = Instance.new("BillboardGui")
		bb.Name = "MapIcon"
		bb.Size = UDim2.fromOffset(44, 44)
		bb.StudsOffsetWorldSpace = Vector3.new(0, opts.iconH or 20, 0)
		bb.MaxDistance = opts.iconDist or 420
		bb.LightInfluence = 0
		bb.Parent = p
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = C(20, 22, 26)
		f.BackgroundTransparency = 0.1
		f.Parent = bb
		Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
		local sk = Instance.new("UIStroke")
		sk.Color = c.color
		sk.Thickness = 3
		sk.Parent = f
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(0.78, 0.78)
		t.Position = UDim2.fromScale(0.11, 0.11)
		t.Text = opts.glyph or c.glyph
		t.TextScaled = true
		t.Font = Enum.Font.GothamBlack
		t.TextColor3 = c.color
		t.Parent = f
	end
	p.Parent = root
	return p
end

-- load the other modules (each returns function(L))
local VB = game:GetService("ServerStorage"):FindFirstChild("VB")
if VB then
	for _, n in ipairs({ "Props", "Roads", "Build", "Towers", "Lux", "Villa", "VillaInt", "Street", "Gas" }) do
		local m = VB:FindFirstChild(n)
		if m then require(m:Clone())(L) end
	end
end
return L
