-- Builds MTL_BuildingLab.MTL_ShopStrip: a weathered one/two-storey strip of five shops east of the corner store.
local O = CFrame.new(3300, 2, 0)
local lab = workspace.MTL_BuildingLab
local old = lab:FindFirstChild("MTL_ShopStrip"); if old then old:Destroy() end
local strip = Instance.new("Model"); strip.Name = "MTL_ShopStrip"
local C = Color3.fromRGB
local M = Enum.Material
local count = 0
local function P(parent, name, size, cf, color, mat, variant, opts)
	local p = Instance.new("Part")
	p.Name = name; p.Anchored = true; p.Size = size; p.CFrame = cf; p.Color = color
	p.Material = mat or M.SmoothPlastic
	if variant then p.MaterialVariant = variant end
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if opts then for k, v in pairs(opts) do if k == "shape" then p.Shape = v else p[k] = v end end end
	p.Parent = parent
	count += 1
	return p
end
local function W(parent, name, size, cf, color, mat, variant)
	local w = Instance.new("WedgePart"); w.Name = name; w.Anchored = true; w.Size = size; w.CFrame = cf; w.Color = color
	w.Material = mat or M.SmoothPlastic; if variant then w.MaterialVariant = variant end; w.Parent = parent; count += 1; return w
end
local function noCol(p) p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; return p end
local function grp(name, parent) local m = Instance.new("Model"); m.Name = name; m.Parent = parent; return m end

local STEEL = C(38, 38, 40)
local ALU = C(150, 153, 157)
local TRIM = C(188, 184, 176)
local T = 1
local ZF = -20 -- front line of the strip
-- front frame: +Z out to the street, u = -x so we can think in world-local x
local G = O * CFrame.new(0, 0, ZF) * CFrame.Angles(0, math.pi, 0)
local function F(x, v, z) return G * CFrame.new(-x, v, z) end

local function frontWall(parent, x0, x1, v0, v1, holes, color, mat, variant)
	-- holes in x: {x0,x1,v0,v1}; converted to u
	local lo, hi = v1, v0
	for _, h in ipairs(holes) do lo = math.min(lo, h[3]); hi = math.max(hi, h[4]) end
	if #holes == 0 then lo, hi = v1, v1 end
	local function piece(a, b, c, d)
		if b - a > 0.01 and d - c > 0.01 then
			P(parent, "Wall", Vector3.new(b - a, d - c, T), F((a + b) / 2, (c + d) / 2, -T / 2), color, mat, variant)
		end
	end
	piece(x0, x1, v0, lo); piece(x0, x1, hi, v1)
	if #holes == 0 then return end
	local xs = { x0, x1 }
	for _, h in ipairs(holes) do table.insert(xs, h[1]); table.insert(xs, h[2]) end
	table.sort(xs)
	for i = 1, #xs - 1 do
		local a, b = xs[i], xs[i + 1]
		if b - a > 0.01 then
			local spans = {}
			for _, h in ipairs(holes) do if h[1] <= a + 0.001 and h[2] >= b - 0.001 then table.insert(spans, { h[3], h[4] }) end end
			table.sort(spans, function(p, q) return p[1] < q[1] end)
			local cur = lo
			for _, s in ipairs(spans) do piece(a, b, cur, s[1]); cur = s[2] end
			piece(a, b, cur, hi)
		end
	end
end

local function shutter(parent, x0, x1, top, openTo)
	local w, x = x1 - x0, (x0 + x1) / 2
	local b = openTo or 0
	P(parent, "Shutter", Vector3.new(w, top - b, 0.2), F(x, (top + b) / 2, -0.45), C(196, 192, 184), M.Metal, "MTL_RollShutter")
	P(parent, "BottomBar", Vector3.new(w, 0.3, 0.35), F(x, b + 0.15, -0.42), C(70, 66, 60), M.Metal)
	P(parent, "Guide", Vector3.new(0.3, top, 0.4), F(x0 + 0.15, top / 2, -0.3), STEEL, M.Metal)
	P(parent, "Guide", Vector3.new(0.3, top, 0.4), F(x1 - 0.15, top / 2, -0.3), STEEL, M.Metal)
	P(parent, "Handle", Vector3.new(0.8, 0.2, 0.25), F(x, b + 0.9, -0.25), C(60, 60, 60), M.Metal)
	if b > 0 then P(parent, "Dark", Vector3.new(w + 1, b + 0.4, 6), F(x, b / 2, -3.6), C(16, 16, 18), M.SmoothPlastic) end
end

local function glassFront(parent, x0, x1, v0, v1, lit)
	local w, x = x1 - x0, (x0 + x1) / 2
	P(parent, "Glass", Vector3.new(w, v1 - v0, 0.1), F(x, (v0 + v1) / 2, -0.6), C(60, 78, 86), M.Glass, nil, { Transparency = 0.55, Reflectance = 0.1 })
	P(parent, "Frame", Vector3.new(w, 0.3, 0.35), F(x, v0 + 0.15, -0.6), ALU, M.Metal)
	P(parent, "Frame", Vector3.new(w, 0.3, 0.35), F(x, v1 - 0.15, -0.6), ALU, M.Metal)
	for i = 0, math.max(1, math.floor(w / 4)) do
		local xx = x0 + 0.15 + (w - 0.3) * i / math.max(1, math.floor(w / 4))
		P(parent, "Mullion", Vector3.new(0.25, v1 - v0, 0.3), F(xx, (v0 + v1) / 2, -0.6), ALU, M.Metal)
	end
	-- interior box so the glass reads as a room
	P(parent, "Back", Vector3.new(w, v1 - v0 + 2, 0.3), F(x, (v0 + v1) / 2, -7), lit and C(232, 226, 210) or C(40, 40, 44), M.SmoothPlastic)
	P(parent, "Floor", Vector3.new(w, 0.2, 6.5), F(x, 0.1, -3.8), C(150, 146, 140), M.CeramicTiles)
	if lit then
		local tube = P(parent, "Tube", Vector3.new(w * 0.6, 0.2, 0.4), F(x, v1 + 0.6, -4), C(245, 250, 255), M.Neon)
		local pl = Instance.new("PointLight"); pl.Color = C(235, 240, 255); pl.Brightness = 2.5; pl.Range = 12; pl.Shadows = false; pl.Parent = tube
		for k = 0, math.floor(w / 3) - 1 do
			P(parent, "Rack", Vector3.new(2.2, 4.5, 1.2), F(x0 + 1.6 + k * 3, 2.4, -5.5), C(80, 82, 88), M.Metal)
			for j = 0, 2 do noCol(P(parent, "Goods", Vector3.new(1.8, 0.8, 0.4), F(x0 + 1.6 + k * 3, 1.2 + j * 1.4, -4.85), Color3.fromHSV(((k * 3 + j) * 0.17) % 1, 0.7, 0.85), M.SmoothPlastic)) end
		end
	end
end

local function bars(parent, x0, x1, v0, v1, z)
	local w, x = x1 - x0, (x0 + x1) / 2
	P(parent, "BarRail", Vector3.new(w + 0.3, 0.18, 0.18), F(x, v0 + 0.1, z), STEEL, M.Metal)
	P(parent, "BarRail", Vector3.new(w + 0.3, 0.18, 0.18), F(x, v1 - 0.1, z), STEEL, M.Metal)
	P(parent, "BarRail", Vector3.new(w + 0.3, 0.18, 0.18), F(x, (v0 + v1) / 2, z), STEEL, M.Metal)
	local n = math.floor(w / 0.7)
	for i = 0, n do noCol(P(parent, "Bar", Vector3.new(0.12, v1 - v0, 0.12), F(x0 + w * i / n, (v0 + v1) / 2, z), STEEL, M.Metal)) end
end

local function window(parent, x, v0, w, h, lit)
	P(parent, "Room", Vector3.new(w, h, 0.1), F(x, v0 + h / 2, -0.98), lit and C(236, 196, 140) or C(28, 28, 32), lit and M.Fabric or M.SmoothPlastic)
	if lit then
		local s = noCol(P(parent, "LightSrc", Vector3.new(0.2, 0.2, 0.2), F(x, v0 + h * 0.6, -0.8), C(0, 0, 0), M.SmoothPlastic, nil, { Transparency = 1 }))
		local l = Instance.new("PointLight"); l.Color = C(255, 196, 130); l.Brightness = 5; l.Range = 5; l.Shadows = false; l.Parent = s
	end
	noCol(P(parent, "Glass", Vector3.new(w, h, 0.08), F(x, v0 + h / 2, -0.7), C(52, 70, 80), M.Glass, nil, { Transparency = lit and 0.7 or 0.45, Reflectance = 0.12 }))
	P(parent, "Frame", Vector3.new(w, 0.22, 0.3), F(x, v0 + 0.11, -0.65), ALU, M.Metal)
	P(parent, "Frame", Vector3.new(w, 0.22, 0.3), F(x, v0 + h - 0.11, -0.65), ALU, M.Metal)
	P(parent, "Frame", Vector3.new(0.22, h, 0.3), F(x - w / 2 + 0.11, v0 + h / 2, -0.65), ALU, M.Metal)
	P(parent, "Frame", Vector3.new(0.22, h, 0.3), F(x + w / 2 - 0.11, v0 + h / 2, -0.65), ALU, M.Metal)
	P(parent, "Sill", Vector3.new(w + 0.8, 0.35, 0.9), F(x, v0 - 0.17, -0.15), TRIM, M.Concrete, "ConcreteStained")
	bars(parent, x - w / 2, x + w / 2, v0, v0 + h, 0.3)
end

local function condenser(parent, x, v)
	local g = grp("ACUnit", parent)
	P(g, "Body", Vector3.new(3, 2.3, 1.3), F(x, v, 0.85), C(206, 204, 196), M.Metal)
	P(g, "Top", Vector3.new(3.1, 0.12, 1.4), F(x, v + 1.2, 0.85), C(180, 178, 170), M.Metal)
	P(g, "FanGuard", Vector3.new(0.08, 1.85, 1.85), F(x + 0.35, v, 1.52) * CFrame.Angles(0, math.pi / 2, 0), C(42, 42, 44), M.Metal, nil, { shape = Enum.PartType.Cylinder })
	P(g, "FanHub", Vector3.new(0.12, 0.45, 0.45), F(x + 0.35, v, 1.57) * CFrame.Angles(0, math.pi / 2, 0), C(120, 120, 122), M.Metal, nil, { shape = Enum.PartType.Cylinder })
	for i = -1, 1 do noCol(P(g, "Grille", Vector3.new(1.85, 0.06, 0.06), F(x + 0.35, v + i * 0.45, 1.6), C(60, 60, 62), M.Metal)) end
	-- rust streak running down from the unit
	P(g, "RustStreak", Vector3.new(1.4, 2.2, 0.04), F(x - 0.6, v - 2.2, 0.02), C(150, 96, 60), M.CorrodedMetal, "MTL_RustBand", { Transparency = 0.25 })
	for _, dx in ipairs({ -1.1, 1.1 }) do P(g, "Bracket", Vector3.new(0.15, 0.15, 1.6), F(x + dx, v - 1.25, 0.8), STEEL, M.Metal) end
	noCol(P(g, "Pipe", Vector3.new(0.18, 0.18, 0.9), F(x - 1.3, v - 0.6, 0.25), C(176, 120, 80), M.Metal))
end

local function rustBand(parent, x0, x1, v)
	local w, x = x1 - x0, (x0 + x1) / 2
	P(parent, "RustBand", Vector3.new(w, 1.8, 0.5), F(x, v, 0.25), C(176, 120, 82), M.CorrodedMetal, "MTL_RustBand")
	P(parent, "RustBandCap", Vector3.new(w + 0.2, 0.2, 0.7), F(x, v + 1, 0.3), C(90, 70, 56), M.Metal)
	P(parent, "RustBandLip", Vector3.new(w, 0.15, 0.55), F(x, v - 0.95, 0.27), C(70, 54, 44), M.Metal)
end

local function sign(parent, x, v, w, h, text, fg, bg, font)
	local p = P(parent, "Sign", Vector3.new(w, h, 0.25), F(x, v, 0.15), bg, M.SmoothPlastic)
	local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Back; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 40; sg.Parent = p
	local t = Instance.new("TextLabel"); t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1; t.Text = text; t.TextColor3 = fg; t.Font = font or Enum.Font.GothamBlack; t.TextScaled = true; t.Parent = sg
	local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0.04, 0); pad.PaddingRight = UDim.new(0.04, 0); pad.PaddingTop = UDim.new(0.1, 0); pad.PaddingBottom = UDim.new(0.1, 0); pad.Parent = t
end

-- the body of each unit: front wall + sides + back + roof + parapet trim
local function unit(name, x0, x1, h, depth, look, holes)
	local u = grp(name, strip)
	frontWall(u, x0, x1, 0, h, holes, look.color, look.mat, look.variant)
	local d = depth
	local zc = ZF + d / 2
	P(u, "Back", Vector3.new(x1 - x0, h, T), O * CFrame.new((x0 + x1) / 2, h / 2, ZF + d - T / 2), look.color, look.mat, look.variant)
	P(u, "SideL", Vector3.new(T, h, d - 2), O * CFrame.new(x0 + T / 2, h / 2, zc), look.color, look.mat, look.variant)
	P(u, "SideR", Vector3.new(T, h, d - 2), O * CFrame.new(x1 - T / 2, h / 2, zc), look.color, look.mat, look.variant)
	P(u, "Roof", Vector3.new(x1 - x0 - 2, 0.6, d - 2), O * CFrame.new((x0 + x1) / 2, h - 2.6, zc), C(96, 94, 92), M.Asphalt, "RoofFlatBitumen")
	P(u, "Coping", Vector3.new(x1 - x0 + 0.3, 0.35, 1.5), F((x0 + x1) / 2, h + 0.17, -0.5), look.cap or TRIM, M.Concrete, "ConcreteStained")
	P(u, "Plinth", Vector3.new(x1 - x0, 1.1, 0.25), F((x0 + x1) / 2, 0.55, 0.1), C(62, 60, 58), M.Concrete, "HoodConcreteDirty")
	return u
end

---------------------------------------------------------------------------------------------------------------
local BLUE = { color = C(170, 196, 214), mat = M.Plaster, variant = "MTL_StuccoBlueFaded", cap = C(150, 170, 186) }
local CINDER = { color = C(196, 194, 188), mat = M.Concrete, variant = "MTL_CinderPainted" }
local SAGE = { color = C(150, 178, 150), mat = M.Plaster, variant = "MTL_StuccoStreaked", cap = C(120, 146, 120) }
local WHITE = { color = C(226, 222, 212), mat = M.Plaster, variant = "MTL_StuccoStreaked" }

-- U1: two-storey pale blue end block, glass door + barred window, flat parapet with a stepped crown
local u1 = unit("Unit1_Blue", 40, 60, 25, 32, BLUE, { { 42, 47, 0, 9 }, { 49, 58, 2.5, 9 }, { 44, 50, 15.5, 21 } })
glassFront(u1, 42, 47, 0, 9, true)
glassFront(u1, 49, 58, 2.5, 9, true)
bars(u1, 49, 58, 2.5, 9, 0.25)
P(u1, "Sill", Vector3.new(9.6, 0.4, 1), F(53.5, 2.3, -0.1), TRIM, M.Concrete, "ConcreteStained")
window(u1, 47, 15.5, 6, 5.5, true)
rustBand(u1, 40.5, 59.5, 10.4)
sign(u1, 50, 12.6, 11, 1.8, "PHONE REPAIR · PREPAID", C(255, 255, 255), C(30, 80, 160))
condenser(u1, 55, 18)
P(u1, "Crown", Vector3.new(8, 2, 1), F(50, 26, -0.5), BLUE.color, BLUE.mat, BLUE.variant)
P(u1, "CrownCap", Vector3.new(8.4, 0.35, 1.5), F(50, 27.15, -0.5), BLUE.cap, M.Concrete, "ConcreteStained")
P(u1, "StringCourse", Vector3.new(20, 0.6, 0.4), F(50, 13.9, 0.2), BLUE.cap, M.Concrete, "ConcreteStained")

-- U2: grey cinder block, one wide roll-up shutter
local u2 = unit("Unit2_Cinder", 60, 78, 15, 30, CINDER, { { 62, 76, 0, 9.4 } })
shutter(u2, 62, 76, 9.4)
rustBand(u2, 60.3, 77.7, 10.5)
condenser(u2, 65, 13)
condenser(u2, 72, 13)
P(u2, "Hood", Vector3.new(15, 1.2, 1.1), F(69, 10.1, -0.1), C(110, 106, 100), M.Metal, "MTL_RustBand")

-- U3: sage-green barber shop with a glass front behind a grille
local u3 = unit("Unit3_Sage", 78, 96, 16, 30, SAGE, { { 80, 85, 0, 9 }, { 86.5, 94, 2.5, 9 } })
glassFront(u3, 80, 85, 0, 9, true)
glassFront(u3, 86.5, 94, 2.5, 9, true)
bars(u3, 86.5, 94, 2.5, 9, 0.25)
P(u3, "Sill", Vector3.new(8.1, 0.4, 1), F(90.25, 2.3, -0.1), TRIM, M.Concrete, "ConcreteStained")
rustBand(u3, 78.3, 95.7, 10.4)
sign(u3, 87, 12.6, 12, 2, "FRESH CUTZ BARBER", C(250, 250, 250), C(140, 30, 30), Enum.Font.Bangers)
condenser(u3, 92, 14)
local pole = P(u3, "BarberPole", Vector3.new(0.7, 3, 0.7), F(85.7, 6, 0.6), C(240, 240, 240), M.SmoothPlastic, nil, { shape = Enum.PartType.Cylinder })
pole.CFrame = F(85.7, 6, 0.6) * CFrame.Angles(0, 0, math.pi / 2)
for i = 0, 3 do P(u3, "PoleStripe", Vector3.new(0.75, 0.35, 0.75), F(85.7, 4.9 + i * 0.75, 0.6) * CFrame.Angles(0, i, math.rad(20)), i % 2 == 0 and C(200, 30, 30) or C(30, 60, 170), M.SmoothPlastic) end

-- U4: cinder block, two narrow shutters (one half up) + graffiti
local u4 = unit("Unit4_Cinder", 96, 116, 16, 30, CINDER, { { 98, 105.5, 0, 9.4 }, { 107, 114.5, 0, 9.4 } })
shutter(u4, 98, 105.5, 9.4)
shutter(u4, 107, 114.5, 9.4, 3)
rustBand(u4, 96.3, 115.7, 10.5)
condenser(u4, 101, 13.5)
condenser(u4, 110.5, 13.5)
do
	local tagPart = noCol(P(u4, "Tag", Vector3.new(7, 3.5, 0.05), F(101.75, 4.5, -0.32), C(0, 0, 0), M.SmoothPlastic, nil, { Transparency = 1 }))
	local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Back; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 40; sg.Parent = tagPart
	local t = Instance.new("TextLabel"); t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1; t.Text = "K-LOW 305"; t.Font = Enum.Font.PermanentMarker; t.TextScaled = true
	t.TextColor3 = C(230, 60, 140); t.TextStrokeTransparency = 0; t.TextStrokeColor3 = C(20, 20, 30); t.Rotation = 4; t.Parent = sg
end

-- U5: white two-storey with a stepped mission-style parapet, door + shutters below, two windows above
local u5 = unit("Unit5_White", 116, 140, 22, 32, WHITE, { { 118, 126, 0, 9.4 }, { 128, 132, 0, 8.6 }, { 134, 138.5, 3, 8.6 }, { 120, 125, 13.5, 19 }, { 131, 136, 13.5, 19 } })
shutter(u5, 118, 126, 9.4)
glassFront(u5, 128, 132, 0, 8.6, false)
P(u5, "SecurityDoor", Vector3.new(4.2, 8.6, 0.12), F(130, 4.3, 0.12), STEEL, M.Metal, nil, { Transparency = 1 })
bars(u5, 128, 132, 0.2, 8.6, 0.2)
window(u5, 136.25, 3, 4.5, 5.6, false)
window(u5, 122.5, 13.5, 5, 5.5, true)
window(u5, 133.5, 13.5, 5, 5.5, false)
rustBand(u5, 116.3, 139.7, 10.5)
sign(u5, 124, 12.6, 9, 1.6, "TIENDA LA ESQUINA", C(30, 30, 30), C(245, 210, 60))
condenser(u5, 128, 16.5)
-- stepped crown (centre raised in three steps)
for i, s in ipairs({ { 14, 1.2 }, { 9, 2.4 }, { 4, 3.6 } }) do
	P(u5, "Step" .. i, Vector3.new(s[1], 1.2, 1), F(128, 22 + s[2] - 0.6, -0.5), WHITE.color, WHITE.mat, WHITE.variant)
	P(u5, "StepCap" .. i, Vector3.new(s[1] + 0.4, 0.3, 1.4), F(128, 22 + s[2] + 0.15, -0.5), TRIM, M.Concrete, "ConcreteStained")
end
P(u5, "StringCourse", Vector3.new(24, 0.6, 0.4), F(128, 12.6 - 0.1 + 0.9, 0.2), TRIM, M.Concrete, "ConcreteStained")

-- downpipes between units
for _, x in ipairs({ 60, 78, 96, 116 }) do
	P(strip, "Downpipe", Vector3.new(0.45, 14.5, 0.45), F(x, 7.5, 0.35), C(140, 136, 130), M.Metal)
end

-- peeling billboard behind units 3-4
local bb = grp("PeelingBillboard", strip)
local bx, bzz = 97, 4
local BY0, BY1 = 22, 36
for _, dx in ipairs({ -9, 0, 9 }) do
	P(bb, "Post", Vector3.new(0.8, BY0 + 1, 0.8), O * CFrame.new(bx + dx, (BY0 + 1) / 2, bzz + 1.5), C(110, 70, 46), M.CorrodedMetal, "MTL_RustBand")
	P(bb, "Brace", Vector3.new(0.35, 10, 0.35), O * CFrame.new(bx + dx, BY0 - 5, bzz + 4) * CFrame.Angles(math.rad(25), 0, 0), C(110, 70, 46), M.CorrodedMetal, "MTL_RustBand")
end
P(bb, "Rail", Vector3.new(30, 0.4, 0.4), O * CFrame.new(bx, BY0 + 3, bzz + 0.9), C(100, 66, 44), M.CorrodedMetal, "MTL_RustBand")
P(bb, "Rail", Vector3.new(30, 0.4, 0.4), O * CFrame.new(bx, BY1 - 3, bzz + 0.9), C(100, 66, 44), M.CorrodedMetal, "MTL_RustBand")
P(bb, "Catwalk", Vector3.new(30, 0.2, 2), O * CFrame.new(bx, BY0 - 0.5, bzz - 1), C(80, 76, 70), M.Metal, "RustyGrate")
local board = P(bb, "Board", Vector3.new(30, BY1 - BY0, 0.4), O * CFrame.new(bx, (BY0 + BY1) / 2, bzz), C(240, 238, 232), M.SmoothPlastic)
do
	local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Front; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 16; sg.Parent = board
	local bg = Instance.new("Frame"); bg.Size = UDim2.fromScale(1, 1); bg.BackgroundColor3 = C(238, 236, 230); bg.BorderSizePixel = 0; bg.ClipsDescendants = true; bg.Parent = sg
	-- a faded old ad left underneath
	local ghost = Instance.new("TextLabel"); ghost.BackgroundTransparency = 1; ghost.Size = UDim2.fromScale(0.9, 0.4); ghost.Position = UDim2.fromScale(0.05, 0.06)
	ghost.Text = "COMING SOON"; ghost.Font = Enum.Font.GothamBlack; ghost.TextScaled = true; ghost.TextColor3 = C(200, 196, 188); ghost.Parent = bg
	-- peeled patches: clusters of rotated brown/grey blotches, denser at the middle and bottom
	local rng = Random.new(305)
	for i = 1, 140 do
		local cx = rng:NextNumber(0.02, 0.95)
		local cy = math.clamp(rng:NextNumber(0.15, 1.0) ^ 0.7, 0, 0.98)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(cx, cy)
		f.Size = UDim2.fromScale(rng:NextNumber(0.015, 0.09), rng:NextNumber(0.03, 0.14))
		f.Rotation = rng:NextNumber(-40, 40)
		local tone = rng:NextNumber()
		f.BackgroundColor3 = tone < 0.45 and C(122, 96, 72) or (tone < 0.8 and C(92, 84, 76) or C(160, 140, 110))
		f.BackgroundTransparency = rng:NextNumber(0, 0.25)
		f.BorderSizePixel = 0
		f.Parent = bg
	end
end

-- back-of-strip clutter: rooftop AC boxes
for _, x in ipairs({ 50, 69, 105, 128 }) do
	P(strip, "RoofUnit", Vector3.new(4, 2.2, 3), O * CFrame.new(x, (x < 60 or x > 116) and 23.5 or 13.5 + ((x > 96) and 1 or 0), 2), C(190, 190, 186), M.Metal)
end

---------------------------------------------------------------------------------------------------------------
-- extend the lab street east to carry the strip
local pad = lab.LabStreet
for _, n in ipairs({ "SidewalkE", "CurbE", "RoadE" }) do local o = pad:FindFirstChild(n); if o then o:Destroy() end end
P(pad, "SidewalkE", Vector3.new(90, 4, 70), O * CFrame.new(110, -2, 5), C(176, 172, 164), M.Concrete, "SidewalkWornStained")
P(pad, "CurbE", Vector3.new(90, 4.4, 1), O * CFrame.new(110, -2.2, -30.5), C(190, 186, 178), M.Concrete, "ConcretePlain")
P(pad, "RoadE", Vector3.new(90, 4, 44), O * CFrame.new(110, -2.4, -53), C(62, 62, 64), M.Asphalt, "AsphaltWorn")
for i = 0, 8 do
	P(pad, "CenterLineE", Vector3.new(6, 0.05, 0.3), O * CFrame.new(70 + i * 10, -0.38, -52.7), C(230, 190, 40), M.SmoothPlastic)
	P(pad, "CenterLineE", Vector3.new(6, 0.05, 0.3), O * CFrame.new(70 + i * 10, -0.38, -53.3), C(230, 190, 40), M.SmoothPlastic)
end
P(pad, "CurbRedE", Vector3.new(20, 0.05, 1.02), O * CFrame.new(88, 0.01, -30.5), C(170, 40, 35), M.SmoothPlastic)

strip.Parent = lab
return "strip parts=" .. count
