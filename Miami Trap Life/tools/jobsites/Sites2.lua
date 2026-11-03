-- The Level 8+ / 15+ job sites: Coral Hotel valet (Bayfront Tower), Bayside Mall (Security, new building on the
-- NW 66 Alley empty lot next to Westside Auto), Vice Bay Freight (Trucker) and the Port of Vice Bay (Dockworker).
-- Run:  require(game.ServerStorage.MTL_Tools.JobSite_Sites2)()
-- Each site builds one model (rebuilt on every run) and moves its stations; replaced map pieces go to
-- ServerStorage.MTL_ReplacedJobSites.<site>. Time clocks keep Prop = "TimeClock": JobFX draws the real model from
-- ReplicatedStorage.MTL_JobProps there.
local CS = game:GetService("CollectionService")
local K = require(script.Parent.JobSiteKit)
local C, M = K.C, K.M
local V = Vector3.new

local function moveStation(job: string, id: string, pos: Vector3, keepProp: boolean?)
	local f = workspace:FindFirstChild("MTL_Stations") and workspace.MTL_Stations:FindFirstChild(job)
	local p = f and f:FindFirstChild(id)
	if not p then
		return false
	end
	if p:GetAttribute("MTL_OldPos") == nil then
		p:SetAttribute("MTL_OldPos", p.Position)
	end
	p.CFrame = CFrame.new(pos)
	if not keepProp then
		p:SetAttribute("Prop", "")
	end
	return true
end

local function fresh(parent: Instance, name: string): Model
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("MTL_Style", "JobSiteV2")
	return m
end

-- shipping container (20 ft-ish), corrugated by ribs. cf = floor centre, long axis = local X
local function container(b, parent, cf: CFrame, color: Color3, label: string?)
	local g = b.group("Container", parent)
	local L, Wd, H = 20, 8, 8.6
	b.P("Box", V(L, H, Wd), cf * CFrame.new(0, H / 2, 0), color, M.Metal, { parent = g })
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.25)
	for i = 0, 8 do
		local x = -L / 2 + 1.2 + i * 2.2
		for _, s in { -1, 1 } do
			b.P("Rib", V(0.7, H - 0.8, 0.12), cf * CFrame.new(x, H / 2, s * (Wd / 2 + 0.05)), dark, M.Metal, { parent = g, deco = true })
		end
	end
	for _, y in { 0.25, H - 0.25 } do
		b.P("Rail", V(L + 0.1, 0.5, Wd + 0.1), cf * CFrame.new(0, y, 0), dark, M.Metal, { parent = g, deco = true })
	end
	b.P("Doors", V(0.15, H - 0.6, Wd - 0.4), cf * CFrame.new(L / 2 + 0.05, H / 2, 0), dark, M.Metal, { parent = g, deco = true })
	for _, z in { -1.2, -0.4, 0.4, 1.2 } do
		b.P("Bar", V(0.12, H - 1, 0.12), cf * CFrame.new(L / 2 + 0.15, H / 2, z), C(160, 160, 160), M.Metal, { parent = g, deco = true })
	end
	if label then
		local s = b.P("Label", V(10, 2.2, 0.05), cf * CFrame.new(0, H * 0.62, -(Wd / 2 + 0.13)), color, M.SmoothPlastic, { parent = g, deco = true, Transparency = 1 })
		K.sign(s, Enum.NormalId.Front, label, nil, C(245, 245, 240), { font = Enum.Font.GothamBlack })
	end
	return g
end

local function forklift(b, parent, cf: CFrame)
	local g = b.group("Forklift", parent)
	local Y = C(240, 180, 20)
	b.P("Body", V(3.2, 2.2, 5.0), cf * CFrame.new(0, 1.6, 0.6), Y, M.Metal, { parent = g })
	b.P("Counterweight", V(3.2, 1.8, 1.2), cf * CFrame.new(0, 1.9, 3.2), C(40, 40, 42), M.Metal, { parent = g })
	b.P("Seat", V(1.4, 0.6, 1.2), cf * CFrame.new(0, 3.0, 1.4), C(30, 30, 30), M.Fabric, { parent = g })
	for _, x in { -1.4, 1.4 } do
		b.P("CagePost", V(0.2, 3.6, 0.2), cf * CFrame.new(x, 4.4, -0.6), C(40, 40, 42), M.Metal, { parent = g })
		b.P("CagePost", V(0.2, 3.6, 0.2), cf * CFrame.new(x, 4.4, 2.6), C(40, 40, 42), M.Metal, { parent = g })
		b.P("Mast", V(0.3, 6.5, 0.3), cf * CFrame.new(x * 0.7, 3.25, -2.2), C(50, 50, 52), M.Metal, { parent = g })
		b.P("Fork", V(0.35, 0.15, 3.4), cf * CFrame.new(x * 0.6, 0.35, -3.9), C(50, 50, 52), M.Metal, { parent = g })
	end
	b.P("CageRoof", V(3.2, 0.2, 3.6), cf * CFrame.new(0, 6.2, 1.0), C(40, 40, 42), M.Metal, { parent = g })
	for _, p in { V(-1.5, 0.7, -1.2), V(1.5, 0.7, -1.2), V(-1.5, 0.6, 2.8), V(1.5, 0.6, 2.8) } do
		b.P("Wheel", V(0.6, 1.3, 1.3), cf * CFrame.new(p), C(20, 20, 20), M.Rubber, { parent = g, shape = Enum.PartType.Cylinder })
	end
	b.P("Beacon", V(0.4, 0.3, 0.4), cf * CFrame.new(0, 6.45, 2.4), C(255, 140, 20), M.Neon, { parent = g, deco = true })
	return g
end

local function floodPole(b, parent, pos: Vector3, h: number)
	local p = b.P("Pole", V(0.6, h, 0.6), CFrame.new(pos + V(0, h / 2, 0)), C(120, 122, 126), M.Metal, { parent = parent })
	local head = b.P("Flood", V(2.6, 0.8, 1.4), CFrame.new(pos + V(0, h + 0.2, 0)), C(60, 60, 64), M.Metal, { parent = parent })
	b.P("FloodLens", V(2.2, 0.06, 1.0), CFrame.new(pos + V(0, h - 0.22, 0)), C(255, 240, 210), M.Neon, { parent = parent, deco = true })
	local l = Instance.new("SpotLight")
	l.Face = Enum.NormalId.Bottom
	l.Range = 50
	l.Angle = 120
	l.Brightness = 1.6
	l.Color = C(255, 236, 200)
	l.Parent = head
	return p
end

local function booth(b, parent, cf: CFrame, title: string, color: Color3)
	-- 7x7 shack, window + door on the local -Z side; returns the outside clock spot
	local g = b.group("Booth", parent)
	b.P("Floor", V(7, 0.4, 7), cf * CFrame.new(0, 0.2, 0), C(150, 150, 146), M.Concrete, { parent = g })
	b.P("WallBack", V(7, 8, 0.25), cf * CFrame.new(0, 4.4, 3.4), C(236, 236, 230), M.Metal, { parent = g })
	b.P("WallL", V(0.25, 8, 7), cf * CFrame.new(-3.4, 4.4, 0), C(236, 236, 230), M.Metal, { parent = g })
	b.P("WallR", V(0.25, 8, 7), cf * CFrame.new(3.4, 4.4, 0), C(236, 236, 230), M.Metal, { parent = g })
	b.P("FrontLow", V(4.2, 3.4, 0.25), cf * CFrame.new(1.3, 2.1, -3.4), C(236, 236, 230), M.Metal, { parent = g })
	b.P("Window", V(4.2, 3.8, 0.12), cf * CFrame.new(1.3, 5.7, -3.4), C(170, 200, 220), M.Glass, { parent = g, Transparency = 0.5 })
	b.P("Header", V(7, 0.8, 0.25), cf * CFrame.new(0, 8.0, -3.4), C(236, 236, 230), M.Metal, { parent = g })
	b.P("Door", V(2.3, 7.4, 0.15), cf * CFrame.new(-2.2, 4.1, -3.9) * CFrame.Angles(0, math.rad(-70), 0) * CFrame.new(-1.1, 0, 0), C(200, 200, 196), M.Metal, { parent = g, deco = true })
	b.P("Roof", V(8, 0.5, 8), cf * CFrame.new(0, 8.65, 0), color, M.Metal, { parent = g })
	local s = b.P("Sign", V(6.5, 1.0, 0.1), cf * CFrame.new(0, 9.4, -3.95), color, M.SmoothPlastic, { parent = g, deco = true })
	K.sign(s, Enum.NormalId.Front, title, color, C(255, 255, 255), { lit = true })
	b.P("Desk", V(4.2, 0.2, 1.4), cf * CFrame.new(1.3, 3.4, -2.5), C(120, 90, 60), M.Wood, { parent = g })
	b.P("Monitor", V(1.2, 0.9, 0.15), cf * CFrame.new(1.8, 4.0, -2.4), C(30, 30, 32), M.SmoothPlastic, { parent = g, deco = true })
	b.P("MonitorGlow", V(1.0, 0.7, 0.02), cf * CFrame.new(1.8, 4.0, -2.48), C(110, 190, 150), M.Neon, { parent = g, deco = true })
	b.P("Clipboard", V(0.8, 0.05, 1.0), cf * CFrame.new(0.5, 3.53, -2.6), C(150, 110, 70), M.Wood, { parent = g, deco = true })
	b.P("Stool", V(1.0, 2.6, 1.0), cf * CFrame.new(1.3, 1.5, -0.8), C(30, 30, 34), M.SmoothPlastic, { parent = g })
	b.P("AC", V(1.6, 1.0, 1.0), cf * CFrame.new(3.9, 6.5, 1.5), C(220, 220, 216), M.Metal, { parent = g })
	return (cf * CFrame.new(-1.0, 0, -6.0)).Position
end

---------------------------------------------------------------- valet: Bayfront Tower porte-cochere
local function valet(report)
	local tower = workspace.ViceBay.Buildings.Downtown:FindFirstChild("Bayfront Tower (stepped crown)")
	if not tower then
		table.insert(report, "valet: tower not found")
		return
	end
	local m = fresh(tower, "ValetV2")
	local b = K.builder(m)
	local GY = 2.35 -- driveway asphalt top
	local function W(x, y, z)
		return CFrame.new(x, GY + y, z)
	end
	-- valet stand upgrade around the existing podium (829,-732)
	b.P("KeyCabinet", V(1.6, 2.4, 0.4), W(831.6, 1.2 + 0.6, -730.6), C(40, 30, 24), M.Wood, {})
	for i = 0, 7 do
		b.P("Key", V(0.1, 0.3, 0.05), W(831.0 + (i % 4) * 0.4, 2.2 + math.floor(i / 4) * 0.7, -730.85), C(220, 190, 70), M.Metal, { deco = true })
	end
	b.P("UmbrellaStand", V(0.8, 1.6, 0.8), W(826.6, 0.8, -731.0), C(30, 30, 32), M.Metal, { shape = Enum.PartType.Cylinder, CFrame = W(826.6, 0.8, -731.0) * CFrame.Angles(0, 0, math.rad(90)) })
	for i = 0, 2 do
		b.P("Umbrella", V(0.15, 3.6, 0.15), W(826.5 + i * 0.15, 2.3, -731.0) * CFrame.Angles(0, 0, math.rad(-6 + i * 6)), ({ C(200, 30, 40), C(30, 30, 34), C(240, 240, 236) })[i + 1], M.Fabric, { deco = true })
	end
	local sign = b.P("ValetSign", V(3.0, 2.2, 0.2), W(834.5, 3.4, -731.5), C(110, 26, 36), M.SmoothPlastic, {})
	K.sign(sign, Enum.NormalId.Front, "VALET\nPARKING", C(110, 26, 36), C(230, 200, 110), { font = Enum.Font.Garamond })
	b.P("SignPost", V(0.25, 2.4, 0.25), W(834.5, 1.2, -731.5), C(200, 170, 80), M.Metal, {})
	for _, x in { 822, 824.5, 838, 840.5 } do
		b.P("Stanchion", V(0.35, 3.0, 0.35), W(x, 1.5, -730.4), C(200, 170, 80), M.Metal, {})
	end
	b.P("Rope", V(2.5, 0.2, 0.2), W(823.25, 2.5, -730.4), C(110, 26, 36), M.Fabric, { deco = true })
	b.P("Rope", V(2.5, 0.2, 0.2), W(839.25, 2.5, -730.4), C(110, 26, 36), M.Fabric, { deco = true })
	b.P("RedCarpet", V(8, 0.04, 3.6), W(829, 0.02, -728.2), C(150, 20, 30), M.Fabric, { deco = true })
	-- valet stalls along the west part of the drive (parallel, south half of the lane)
	local spots = {}
	for i, x in { 762, 775, 788, 801 } do
		b.P("StallLine", V(0.3, 0.03, 6.6), W(x - 6.5, 0.02, -740.8), C(240, 240, 236), M.SmoothPlastic, { deco = true })
		local num = b.P("StallNum", V(2.4, 0.03, 2.4), W(x, 0.025, -742.2), C(240, 240, 236), M.SmoothPlastic, { deco = true, Transparency = 1 })
		K.sign(num, Enum.NormalId.Top, "V" .. i, nil, C(240, 240, 236), { font = Enum.Font.GothamBlack })
		spots[i] = V(x, GY + 2.5, -740.8)
	end
	b.P("StallLine", V(0.3, 0.03, 6.6), W(807.5, 0.02, -740.8), C(240, 240, 236), M.SmoothPlastic, { deco = true })
	b.P("StallEdge", V(52, 0.03, 0.3), W(781.5, 0.02, -737.5), C(240, 240, 236), M.SmoothPlastic, { deco = true })
	local vo = b.P("ValetOnly", V(1.6, 2.0, 0.15), W(756, 3.2, -743.8), C(255, 255, 255), M.SmoothPlastic, {})
	K.sign(vo, Enum.NormalId.Front, "VALET\nONLY", C(255, 255, 255), C(110, 26, 36))
	b.P("VOPost", V(0.2, 2.2, 0.2), W(756, 1.1, -743.8), C(120, 120, 124), M.Metal, {})
	for i = 0, 3 do
		b.P("Cone", V(0.9, 1.4, 0.9), W(812 + i * 1.8, 0.7, -743.2), C(250, 110, 20), M.Plastic, {})
	end
	m.Parent = tower
	K.quietFootprints(V(800, 0, -721), 70)
	local ok = moveStation("Valet", "Stand", V(829, GY + 2.5, -733.6))
	moveStation("Valet", "TimeClock", V(820.5, GY + 2.5, -728.4), true)
	for i = 1, 4 do
		moveStation("Valet", "Spot" .. i, spots[i], true)
	end
	table.insert(report, string.format("valet: %d parts, stations %s", b.n, tostring(ok)))
end

---------------------------------------------------------------- Bayside Mall (Security) on the NW 66 Alley lot
local function mall(report)
	local hood = workspace.ViceBay.Buildings.Hood
	local lot
	for _, d in hood:GetChildren() do
		if d.Name == "EmptyLot" and (d:GetPivot().Position - V(-1016, 6, -579)).Magnitude < 10 then
			lot = d
		end
	end
	local mallOld = hood:FindFirstChild("BaysideMall")
	if lot then
		K.stash("BaysideMall", lot)
	end
	if mallOld then
		mallOld:Destroy()
	end
	local m = fresh(hood, "BaysideMall")
	local b = K.builder(m)
	local P, group = b.P, b.group
	-- frame: front (alley) is -Z. Lot x -1036..-996, z -595..-564.
	local X0, X1, Z0, Z1 = -1035.5, -996.5, -593.5, -565.5 -- walls' outer faces (Z0 = back, Z1 = front)
	local XC, ZC = (X0 + X1) / 2, (Z0 + Z1) / 2
	local FY = 2.65 -- slab top
	local H = 15 -- wall height
	local function W(x, y, z)
		return CFrame.new(x, FY + y, z)
	end
	local STUCCO, TRIM, ACCENT = C(232, 222, 200), C(196, 186, 168), C(20, 110, 150)
	-- footprint marker (keeps the lot tagged like the other map lots)
	if lot and lot:FindFirstChild("Footprint") then
		local fp = lot.Footprint:Clone()
		fp.CanQuery = false
		fp.Parent = m
	end
	-- slab, walls, roof
	P("Slab", V(X1 - X0 + 1, 0.5, Z1 - Z0 + 4), CFrame.new(XC, FY - 0.25, ZC - 1.5), C(170, 168, 160), M.Concrete, {})
	P("Apron", V(X1 - X0 + 1, 0.3, 3.5), CFrame.new(XC, FY - 0.15, Z1 + 1.75), C(186, 184, 176), M.Concrete, {})
	local function wall(name, size, cf)
		local p = P(name, size, cf, STUCCO, M.Plaster, {})
		p.MaterialVariant = "HoodStuccoCracked"
		return p
	end
	wall("WallBack", V(X1 - X0, H, 1), W(XC, H / 2, Z0 + 0.5))
	wall("WallW", V(1, H, Z1 - Z0), W(X0 + 0.5, H / 2, ZC))
	wall("WallE", V(1, H, Z1 - Z0), W(X1 - 0.5, H / 2, ZC))
	-- front: piers + big glass entrance in the middle, shop windows each side
	wall("FrontTop", V(X1 - X0, H - 10, 1), W(XC, 10 + (H - 10) / 2, Z1 - 0.5))
	for _, x in { X0 + 1.5, XC - 6, XC + 6, X1 - 1.5 } do
		wall("Pier", V(3, 10, 1.2), W(x, 5, Z1 - 0.5))
	end
	for _, seg in { { X0 + 3, XC - 7.5 }, { XC + 7.5, X1 - 3 } } do
		P("ShopGlass", V(seg[2] - seg[1], 8.6, 0.25), W((seg[1] + seg[2]) / 2, 5.4, Z1 - 0.5), C(150, 170, 180), M.Glass, { Transparency = 0.55 })
		P("Bulkhead", V(seg[2] - seg[1], 1.1, 1.0), W((seg[1] + seg[2]) / 2, 0.55, Z1 - 0.5), TRIM, M.Concrete, {})
	end
	P("EntryGlassTop", V(9, 2.2, 0.25), W(XC, 8.9, Z1 - 0.5), C(150, 170, 180), M.Glass, { Transparency = 0.55 })
	for _, x in { XC - 4.6, XC + 4.6 } do
		P("EntryFrame", V(0.4, 10, 0.5), W(x, 5, Z1 - 0.5), C(40, 40, 42), M.Metal, {})
	end
	P("EntryHeader", V(9.6, 0.4, 0.5), W(XC, 7.8, Z1 - 0.5), C(40, 40, 42), M.Metal, {})
	for _, s in { -1, 1 } do
		P("SlideDoor", V(2.3, 7.6, 0.12), W(XC + s * 3.3, 3.9, Z1 - 0.2), C(150, 170, 180), M.Glass, { deco = true, Transparency = 0.55 })
	end
	-- roof, parapet, canopy, sign, AC units
	P("Roof", V(X1 - X0, 1, Z1 - Z0), W(XC, H + 0.5, ZC), C(150, 150, 150), M.Concrete, {})
	P("RoofTop", V(X1 - X0 - 0.4, 0.15, Z1 - Z0 - 0.4), W(XC, H + 1.08, ZC), C(70, 68, 66), M.Asphalt, {}).MaterialVariant = "RoofFlatBitumen"
	for _, seg in { { V(X1 - X0 + 0.4, 2, 0.8), W(XC, H + 2, Z1 - 0.4) }, { V(X1 - X0 + 0.4, 2, 0.8), W(XC, H + 2, Z0 + 0.4) }, { V(0.8, 2, Z1 - Z0), W(X0 + 0.4, H + 2, ZC) }, { V(0.8, 2, Z1 - Z0), W(X1 - 0.4, H + 2, ZC) } } do
		P("Parapet", seg[1], seg[2], TRIM, M.Plaster, {})
	end
	P("Canopy", V(14, 0.5, 5), W(XC, 10.4, Z1 + 2.2), ACCENT, M.Metal, {})
	for _, x in { XC - 6.6, XC + 6.6 } do
		P("CanopyPost", V(0.4, 10.2, 0.4), W(x, 5.1, Z1 + 4.4), C(40, 40, 42), M.Metal, {})
	end
	local sign = P("MallSign", V(22, 3.2, 0.5), W(XC, 12.6, Z1 + 0.3), C(250, 250, 246), M.SmoothPlastic, {})
	K.sign(sign, Enum.NormalId.Front, "BAYSIDE MALL", C(250, 250, 246), ACCENT, { font = Enum.Font.GothamBlack })
	local sl = Instance.new("SurfaceLight")
	sl.Face = Enum.NormalId.Front
	sl.Range = 12
	sl.Brightness = 1.2
	sl.Parent = sign
	for i, x in { X0 + 6, X1 - 8 } do
		P("RoofAC", V(5, 3, 4), W(x, H + 2.5, Z0 + 6 + i * 2), C(200, 200, 196), M.Metal, {})
		P("RoofFan", V(0.2, 2.6, 2.6), W(x, H + 4.05, Z0 + 6 + i * 2) * CFrame.Angles(0, 0, math.rad(90)), C(60, 60, 64), M.DiamondPlate, { shape = Enum.PartType.Cylinder, deco = true })
	end
	task.wait()

	-- interior: marble corridor + 4 shop units + security desk
	local g = group("Inside")
	local IX0, IX1, IZ0, IZ1 = X0 + 1, X1 - 1, Z0 + 1, Z1 - 1
	local CH = H - 1 -- ceiling height above floor
	P("Floor", V(IX1 - IX0, 0.05, IZ1 - IZ0), CFrame.new(XC, FY + 0.02, (IZ0 + IZ1) / 2), C(226, 222, 214), M.Marble, { parent = g })
	P("Ceiling", V(IX1 - IX0, 0.1, IZ1 - IZ0), W(XC, CH, (IZ0 + IZ1) / 2), C(240, 240, 238), M.SmoothPlastic, { parent = g })
	local cw = 5.2 -- half corridor width
	-- unit partitions (glass fronts onto the corridor)
	local units = {
		{ x0 = IX0, x1 = XC - cw, z0 = IZ0 + 0.0, z1 = ZC - 0.25, name = "KICKS 305", color = C(220, 40, 40), kind = "shoes" },
		{ x0 = IX0, x1 = XC - cw, z0 = ZC + 0.25, z1 = IZ1, name = "PHONE FIX", color = C(30, 120, 220), kind = "phones" },
		{ x0 = XC + cw, x1 = IX1, z0 = IZ0, z1 = ZC - 0.25, name = "GOLD & GRILLZ", color = C(200, 160, 40), kind = "gold" },
		{ x0 = XC + cw, x1 = IX1, z0 = ZC + 0.25, z1 = IZ1, name = "NAILS & LASHES", color = C(230, 110, 170), kind = "nails" },
	}
	P("UnitDivW", V(XC - cw - IX0, CH, 0.5), W((IX0 + XC - cw) / 2, CH / 2, ZC), C(236, 232, 224), M.Plaster, { parent = g })
	P("UnitDivE", V(IX1 - XC - cw, CH, 0.5), W((IX1 + XC + cw) / 2, CH / 2, ZC), C(236, 232, 224), M.Plaster, { parent = g })
	for _, u in units do
		local ug = group("Unit", g)
		local fx = if u.x1 <= XC then u.x1 else u.x0 -- the corridor-side face
		local zc, L = (u.z0 + u.z1) / 2, u.z1 - u.z0
		local inward = if u.x1 <= XC then -1 else 1
		-- storefront: bulkhead + glass + door gap (door near the middle)
		local dz0, dz1 = zc - 1.8, zc + 1.8
		for _, seg in { { u.z0, dz0 }, { dz1, u.z1 } } do
			P("UnitGlass", V(0.2, 8.2, seg[2] - seg[1]), W(fx, 4.9, (seg[1] + seg[2]) / 2), C(160, 180, 190), M.Glass, { parent = ug, Transparency = 0.6 })
			P("UnitKick", V(0.4, 0.8, seg[2] - seg[1]), W(fx, 0.4, (seg[1] + seg[2]) / 2), C(40, 40, 42), M.Metal, { parent = ug })
		end
		P("UnitTransom", V(0.4, CH - 9, L), W(fx, 9 + (CH - 9) / 2, zc), C(236, 232, 224), M.Plaster, { parent = ug })
		local us = P("UnitSign", V(0.3, 1.6, L - 2), W(fx - inward * 0.25, 10.0, zc), u.color, M.SmoothPlastic, { parent = ug, deco = true })
		K.sign(us, if inward < 0 then Enum.NormalId.Right else Enum.NormalId.Left, u.name, u.color, C(255, 255, 255), { lit = true, font = Enum.Font.GothamBlack })
		-- shop contents
		local backX = if inward < 0 then u.x0 + 0.6 else u.x1 - 0.6
		local cz = zc + (if zc > ZC then 2.4 else -2.4) -- toward the outer wall, clear of the door
		P("Counter", V(1.6, 3.2, 5.0), W(fx + inward * 3.0, 1.6, cz), C(30, 30, 34), M.SmoothPlastic, { parent = ug })
		P("CounterTop", V(1.8, 0.12, 5.2), W(fx + inward * 3.0, 3.26, cz), C(220, 220, 224), M.Marble, { parent = ug })
		P("BackWall", V(0.1, CH - 1, L - 0.6), W(backX - inward * 0.25, (CH - 1) / 2, zc), u.color:Lerp(Color3.new(1, 1, 1), 0.75), M.SmoothPlastic, { parent = ug, deco = true })
		local rng = Random.new(#u.name)
		if u.kind == "shoes" or u.kind == "phones" then
			for row = 0, 4 do
				P("WallShelf", V(1.2, 0.1, L - 2.0), W(backX + inward * 0.4, 1.6 + row * 1.5, zc), C(240, 240, 240), M.SmoothPlastic, { parent = ug, deco = true })
				local zz = u.z0 + 1.4
				while zz < u.z1 - 1.4 do
					local col = Color3.fromHSV(rng:NextNumber(), 0.6, rng:NextNumber(0.5, 0.95))
					if u.kind == "shoes" then
						P("Shoe", V(0.9, 0.55, 0.4), W(backX + inward * 0.45, 1.95 + row * 1.5, zz), if rng:NextNumber() < 0.3 then C(245, 245, 245) else col, M.SmoothPlastic, { parent = ug, deco = true })
						P("Sole", V(0.92, 0.12, 0.42), W(backX + inward * 0.45, 1.71 + row * 1.5, zz), C(240, 240, 236), M.SmoothPlastic, { parent = ug, deco = true })
						zz += 1.0
					else
						P("Case", V(0.08, 0.9, 0.5), W(backX + inward * 0.1, 2.1 + row * 1.5, zz), col, M.SmoothPlastic, { parent = ug, deco = true })
						zz += 0.7
					end
				end
			end
			if u.kind == "shoes" then
				P("Bench", V(1.6, 1.4, 4.0), W(fx + inward * 6.5, 0.7, zc), C(30, 30, 34), M.Fabric, { parent = ug })
				P("Mirror", V(0.1, 4, 1.6), W(fx + inward * 0.4, 3, u.z0 + 1.2), C(220, 228, 236), M.Glass, { parent = ug, deco = true, Reflectance = 0.4 })
			else
				P("RepairMat", V(1.4, 0.04, 2.0), W(fx + inward * 3.0, 3.34, zc - 0.5), C(30, 120, 80), M.Rubber, { parent = ug, deco = true })
				P("PhoneOpen", V(0.6, 0.05, 1.1), W(fx + inward * 3.0, 3.38, zc - 0.5), C(20, 20, 24), M.Glass, { parent = ug, deco = true })
			end
		elseif u.kind == "gold" then
			for i = 0, 2 do
				local cz = u.z0 + 2.4 + i * 3.4
				P("Showcase", V(2.2, 3.2, 2.8), W(fx + inward * 4.5, 1.6, cz), C(30, 30, 34), M.SmoothPlastic, { parent = ug })
				P("ShowGlass", V(2.0, 1.0, 2.6), W(fx + inward * 4.5, 3.7, cz), C(220, 230, 236), M.Glass, { parent = ug, Transparency = 0.6 })
				for k = 0, 5 do
					P("Chain", V(0.5, 0.06, 0.12), W(fx + inward * (3.9 + (k % 2) * 0.9), 3.27, cz - 1.0 + math.floor(k / 2) * 0.9) * CFrame.Angles(0, k, 0), C(240, 200, 60), M.Metal, { parent = ug, deco = true, Reflectance = 0.3 })
				end
			end
			P("ShowLight", V(0.3, 0.1, L - 2), W(fx + inward * 4.5, CH - 0.2, zc), C(255, 240, 210), M.Neon, { parent = ug, deco = true })
		else -- nails
			for i = 0, 1 do
				local cz = u.z0 + 3 + i * 4.5
				P("NailTable", V(2.0, 0.15, 3.2), W(fx + inward * 4.5, 2.8, cz), C(250, 250, 250), M.Marble, { parent = ug })
				P("NailBase", V(1.6, 2.7, 2.6), W(fx + inward * 4.5, 1.35, cz), C(230, 110, 170), M.SmoothPlastic, { parent = ug })
				P("Lamp", V(0.3, 1.6, 0.3), W(fx + inward * 4.5, 3.6, cz - 1.2), C(250, 250, 250), M.SmoothPlastic, { parent = ug, deco = true })
				for _, s in { -1, 1 } do
					P("Chair", V(1.4, 1.4, 1.4), W(fx + inward * (4.5 + s * 1.9), 0.9, cz), C(250, 250, 250), M.Fabric, { parent = ug })
				end
			end
			for k = 0, 23 do
				P("Polish", V(0.18, 0.4, 0.18), W(backX + inward * 0.3, 2.2 + math.floor(k / 8) * 0.9, u.z0 + 1.5 + (k % 8) * 0.55), Color3.fromHSV(k / 24, 0.75, 0.95), M.Glass, { parent = ug, deco = true })
			end
			P("PolishRack", V(0.5, 0.1, 5), W(backX + inward * 0.3, 1.95, u.z0 + 3.4), C(240, 240, 240), M.SmoothPlastic, { parent = ug, deco = true })
		end
		local light = P("UnitLight", V(0.2, 0.2, 0.2), W((u.x0 + u.x1) / 2, CH - 0.8, zc), C(255, 255, 255), M.SmoothPlastic, { parent = ug, deco = true, Transparency = 1 })
		local pl = Instance.new("PointLight")
		pl.Range = 18
		pl.Brightness = 0.9
		pl.Color = C(255, 246, 236)
		pl.Shadows = false
		pl.Parent = light
		for _, z in { u.z0 + L * 0.3, u.z0 + L * 0.7 } do
			P("Panel", V(2, 0.08, 3.4), W((u.x0 + u.x1) / 2, CH - 0.06, z), C(246, 248, 255), M.Neon, { parent = ug, deco = true })
		end
	end
	task.wait()
	-- corridor: security desk (Post), planters, bench, directory, ATM, lights
	local desk = group("SecurityDesk", g)
	local dz = ZC + 1.0
	P("DeskBody", V(5.0, 3.4, 2.0), W(XC, 1.7, dz), C(30, 40, 60), M.SmoothPlastic, { parent = desk })
	P("DeskTop", V(5.4, 0.15, 2.4), W(XC, 3.47, dz), C(220, 220, 224), M.Marble, { parent = desk })
	local ds = P("DeskSign", V(3.4, 0.7, 0.05), W(XC, 2.2, dz + 1.03), C(30, 40, 60), M.SmoothPlastic, { parent = desk, deco = true })
	K.sign(ds, Enum.NormalId.Back, "SECURITY", C(30, 40, 60), C(255, 255, 255), { font = Enum.Font.GothamBlack })
	for i = 0, 1 do
		local mon = P("Monitor", V(1.6, 1.1, 0.15), W(XC - 0.9 + i * 1.8, 4.2, dz - 0.4) * CFrame.Angles(0, math.rad(180), 0), C(30, 30, 32), M.SmoothPlastic, { parent = desk, deco = true })
		K.grid(P("MonScreen", V(1.4, 0.9, 0.02), mon.CFrame * CFrame.new(0, 0, -0.09), C(0, 0, 0), M.SmoothPlastic, { parent = desk, deco = true }), Enum.NormalId.Front, 2, 2, C(60, 76, 70), C(10, 10, 10), true)
	end
	P("Radio", V(0.3, 0.7, 0.2), W(XC + 2.0, 3.9, dz), C(20, 20, 20), M.SmoothPlastic, { parent = desk, deco = true })
	P("Chair", V(1.6, 1.4, 1.6), W(XC, 1.2, dz - 2.0), C(20, 20, 24), M.Fabric, { parent = desk })
	P("ChairBack", V(1.6, 2.0, 0.3), W(XC, 2.6, dz - 2.8), C(20, 20, 24), M.Fabric, { parent = desk })
	for _, z in { Z1 - 4.0, Z0 + 4.0 } do
		P("Planter", V(2.4, 2.0, 2.4), W(XC - 3.6, 1.0, z), C(200, 196, 186), M.Concrete, { parent = g })
		P("Plant", V(2.6, 3.2, 2.6), W(XC - 3.6, 3.4, z), C(60, 130, 60), M.Grass, { parent = g, shape = Enum.PartType.Ball, deco = true })
		P("Bench", V(1.6, 1.4, 4.0), W(XC + 3.8, 0.7, z), C(120, 90, 60), M.Wood, { parent = g })
	end
	local dir = P("Directory", V(0.4, 5.0, 3.0), W(XC + 3.9, 2.5, ZC - 4.0), C(30, 30, 34), M.SmoothPlastic, { parent = g })
	K.sign(dir, Enum.NormalId.Left, "<b>DIRECTORY</b>\nKICKS 305\nPHONE FIX\nGOLD & GRILLZ\nNAILS & LASHES", C(30, 30, 34), C(255, 255, 255), { lit = true, font = Enum.Font.GothamBold, pad = 0.12 })
	P("ATM", V(2.2, 5.4, 1.6), W(XC - 3.6, 2.7, ZC - 4.5), C(40, 70, 130), M.SmoothPlastic, { parent = g })
	P("AtmScreen", V(1.0, 0.75, 0.05), W(XC - 3.6, 4.3, ZC - 3.66), C(100, 180, 255), M.Neon, { parent = g, deco = true })
	for _, z in { Z1 - 6, ZC, Z0 + 6 } do
		P("Panel", V(3, 0.08, 4), W(XC, CH - 0.06, z), C(246, 248, 255), M.Neon, { parent = g, deco = true })
		local a = P("LightPoint", V(0.2, 0.2, 0.2), W(XC, CH - 0.8, z), C(255, 255, 255), M.SmoothPlastic, { parent = g, deco = true, Transparency = 1 })
		local l = Instance.new("PointLight")
		l.Range = 22
		l.Brightness = 0.9
		l.Shadows = false
		l.Parent = a
	end
	-- the map JobSpot for Security: JobService uses it as the site centre (and the GPS points here)
	-- interior faces of the outer walls (the stucco texture showed through inside)
	P("InnerBack", V(IX1 - IX0, CH, 0.1), W(XC, CH / 2, IZ0 + 0.06), C(236, 232, 222), M.Concrete, { parent = g })
	P("InnerW", V(0.1, CH, IZ1 - IZ0), W(IX0 + 0.06, CH / 2, (IZ0 + IZ1) / 2), C(236, 232, 222), M.Concrete, { parent = g })
	P("InnerE", V(0.1, CH, IZ1 - IZ0), W(IX1 - 0.06, CH / 2, (IZ0 + IZ1) / 2), C(236, 232, 222), M.Concrete, { parent = g })
	K.dress(g, { InnerBack = "MTL_Drywall", InnerW = "MTL_Drywall", InnerE = "MTL_Drywall", Floor = "MTL_MallTile", Ceiling = "MTL_CeilingTile", UnitDivW = "MTL_Drywall", UnitDivE = "MTL_Drywall", UnitTransom = "MTL_Drywall", Bench = "MTL_CounterWood" })
	for _, u in g:GetChildren() do -- shop floors: planks in the phone/nails units, oak in sneakers/gold
		if u.Name == "Unit" then
			local f = Instance.new("Part")
			f.Name = "UnitFloor"
			f.Anchored = true
			local back = u:FindFirstChild("BackWall")
			if back then
				local ux = (back.Position.X + XC) / 2
				local w = math.abs(back.Position.X - XC) - cw + 0.6
				f.Size = V(w, 0.05, back.Size.Z + 0.6)
				f.CFrame = CFrame.new(back.Position.X + (if back.Position.X < XC then w / 2 - 0.3 else -w / 2 + 0.3), FY + 0.05, back.Position.Z)
				f.Color = C(170, 160, 146)
				f.Parent = u
				local sign = u:FindFirstChild("UnitSign")
				local t = sign and sign:FindFirstChildWhichIsA("SurfaceGui") and sign:FindFirstChildWhichIsA("SurfaceGui"):FindFirstChildWhichIsA("TextLabel")
				local txt = t and t.Text or ""
				K.dressPart(f, if txt:find("KICKS") or txt:find("GOLD") then "MTL_OakFloor" else "MTL_VinylPlank")
				_ = ux
			end
		end
	end
	local spot = P("JobSpot", V(1, 1, 1), W(XC, 0.5, ZC + 3.5), C(255, 255, 255), M.SmoothPlastic, { deco = true, Transparency = 1 })
	spot:SetAttribute("Job", "Security Guard")
	CS:AddTag(spot, "JobSpot")
	m.Parent = hood
	local post = W(XC, 2.5, ZC + 4.5).Position
	moveStation("Security", "Post", post)
	moveStation("Security", "TimeClock", W(XC - 3.0, 2.5, Z0 + 2.4).Position, true)
	table.insert(report, string.format("mall: %d parts", b.n))
end

---------------------------------------------------------------- port: freight depot (Trucker) + quay post (Dockworker)
local function port(report)
	local portF = workspace.ViceBay.Landmarks.Port
	local m = fresh(portF, "JobSitesV2")
	local b = K.builder(m)
	local GY = 2.0
	local function W(x, y, z)
		return CFrame.new(x, GY + y, z)
	end
	local colors = { C(200, 60, 40), C(30, 90, 160), C(40, 130, 80), C(220, 150, 30), C(120, 120, 126), C(150, 40, 60) }
	-- Freight depot west of the middle crane
	local dep = b.group("FreightDepot")
	local clock = booth(b, dep, W(-1214, 0, 1121), "SUNCOAST FREIGHT · DISPATCH", C(230, 120, 20))
	for i = 0, 2 do
		container(b, dep, W(-1196, i * 8.6, 1135), colors[i + 1], ({ "VBF", "SUNCOAST", "OCEANLINK" })[i + 1])
	end
	container(b, dep, W(-1175, 0, 1135), colors[4], "VICE BAY")
	container(b, dep, W(-1185, 0, 1135) * CFrame.new(0, 8.6, 0), colors[5], nil)
	local props = game:GetService("ReplicatedStorage"):FindFirstChild("MTL_JobProps")
	for i, x in { -1192, -1186 } do
		local t = props and props:FindFirstChild("Crates")
		if t then
			local c = t:Clone()
			c:PivotTo(W(x, 0, 1123))
			for _, d in c:GetDescendants() do
				if d:IsA("BasePart") then
					d.CanCollide = true
					d.CanQuery = false
				end
			end
			c.Name = "CratePallet" .. i
			c.Parent = dep
		end
	end
	forklift(b, dep, W(-1179, 0, 1122) * CFrame.Angles(0, math.rad(-35), 0))
	floodPole(b, dep, V(-1203, GY, 1127), 18)
	for i = 0, 4 do
		b.P("Barrier", V(4, 2.6, 1.2), W(-1242 + i * 4.3, 1.3, 1116.4), if i % 2 == 0 then C(220, 220, 214) else C(200, 40, 30), M.Concrete, { parent = dep })
	end
	local ds = b.P("DepotSign", V(14, 3, 0.4), W(-1214, 6.0, 1113.8), C(230, 120, 20), M.SmoothPlastic, { parent = dep })
	K.sign(ds, Enum.NormalId.Front, "VICE BAY FREIGHT · TRUCK LOADING", C(230, 120, 20), C(255, 255, 255), { font = Enum.Font.GothamBlack })
	for _, x in { -1220.5, -1207.5 } do
		b.P("SignLeg", V(0.4, 4.6, 0.4), W(x, 2.3, 1113.8), C(80, 80, 84), M.Metal, { parent = dep })
	end
	b.P("LoadingBay", V(12, 0.04, 9), W(-1189, 0.02, 1122), C(240, 200, 30), M.SmoothPlastic, { parent = dep, deco = true, Transparency = 0.5 })
	moveStation("Trucker", "Dock", V(-1189, GY + 2.5, 1121))
	moveStation("Trucker", "TimeClock", V(-1218.5, GY + 2.5, 1117.5), true)
	_ = clock
	task.wait()
	-- Dockworker post on the quay at x -700
	local dock = b.group("QuayPost")
	booth(b, dock, W(-716, 0, 1121), "PORT OF VICE BAY · CHECKER", C(30, 90, 160))
	local stack = { { -732, 0, 1 }, { -732, 1, 2 }, { -732, 2, 3 }, { -682, 0, 4 }, { -682, 1, 6 }, { -660, 0, 2 } }
	for _, s in stack do
		container(b, dock, W(s[1], s[2] * 8.6, 1131), colors[s[3]], if s[2] == 0 then ({ "PORT VB", "SOL LINE", "CARIBE", "VBF" })[(s[3] % 4) + 1] else nil)
	end
	for x = -712, -688, 6 do
		b.P("Bollard", V(1.2, 1.4, 1.2), W(x, 0.7, 1139), C(40, 40, 44), M.Metal, { parent = dock, shape = Enum.PartType.Cylinder, CFrame = W(x, 0.7, 1139) * CFrame.Angles(0, 0, math.rad(90)) })
		b.P("BollardCap", V(0.3, 1.6, 1.6), W(x, 1.5, 1139) * CFrame.Angles(0, 0, math.rad(90)), C(240, 200, 30), M.Metal, { parent = dock, shape = Enum.PartType.Cylinder })
	end
	b.P("EdgeLine", V(40, 0.04, 0.6), W(-700, 0.02, 1137.5), C(240, 200, 30), M.SmoothPlastic, { parent = dock, deco = true })
	b.P("PostZone", V(16, 0.03, 12), W(-700, 0.02, 1128), C(240, 200, 30), M.SmoothPlastic, { parent = dock, deco = true, Transparency = 0.6 })
	local ps = b.P("PostSign", V(5, 1.6, 0.2), W(-700, 3.2, 1121.8), C(30, 90, 160), M.SmoothPlastic, { parent = dock })
	K.sign(ps, Enum.NormalId.Front, "DOCKWORKER POST · HARD HATS", C(30, 90, 160), C(255, 255, 255))
	b.P("PostLeg", V(0.25, 2.4, 0.25), W(-700, 1.2, 1121.8), C(80, 80, 84), M.Metal, { parent = dock })
	b.P("ManifestDesk", V(3.0, 3.0, 1.6), W(-695, 1.5, 1123), C(150, 110, 70), M.WoodPlanks, { parent = dock })
	b.P("Clipboard", V(0.9, 0.05, 1.1), W(-695, 3.03, 1123), C(240, 236, 220), M.SmoothPlastic, { parent = dock, deco = true })
	b.P("HardHat", V(0.9, 0.5, 0.9), W(-694.2, 3.25, 1123.3), C(250, 200, 30), M.Plastic, { parent = dock, deco = true, shape = Enum.PartType.Ball })
	floodPole(b, dock, V(-708, GY, 1135), 18)
	forklift(b, dock, W(-674, 0, 1124) * CFrame.Angles(0, math.rad(80), 0))
	moveStation("Dockworker", "Post", V(-700, GY + 2.5, 1128))
	moveStation("Dockworker", "TimeClock", V(-721.5, GY + 2.5, 1117.5), true)
	m.Parent = portF
	table.insert(report, string.format("port: %d parts", b.n))
end

return function(which: { string }?)
	local report = {}
	local run = which or { "valet", "mall", "port" }
	for _, w in run do
		if w == "valet" then
			valet(report)
		elseif w == "mall" then
			mall(report)
		elseif w == "port" then
			port(report)
		end
		task.wait()
	end
	return table.concat(report, " | ")
end
