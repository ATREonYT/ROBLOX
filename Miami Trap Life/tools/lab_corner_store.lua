-- Builds "MTL_CornerStore": a two-storey hood corner store with apartments above, on its own pad off the map.
-- Low-poly parts + the place's Realistic MaterialVariants. Everything lives in Workspace.MTL_BuildingLab.
local O = CFrame.new(3300, 2, 0) -- ground level of the lab pad
local old = workspace:FindFirstChild("MTL_BuildingLab")
if old then old:Destroy() end

local lab = Instance.new("Model")
lab.Name = "MTL_BuildingLab"
local pad = Instance.new("Model"); pad.Name = "LabStreet"; pad.Parent = lab
local bld = Instance.new("Model"); bld.Name = "MTL_CornerStore"; bld.Parent = lab
local function grp(name, parent) local m = Instance.new("Model"); m.Name = name; m.Parent = parent or bld; return m end

local C = Color3.fromRGB
local M = Enum.Material
local count = 0
local function P(parent, name, size, cf, color, mat, variant, opts)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or M.SmoothPlastic
	if variant then p.MaterialVariant = variant end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts then for k, v in pairs(opts) do
		if k == "shape" then p.Shape = v else p[k] = v end
	end end
	p.Parent = parent
	count += 1
	return p
end
local function W(parent, name, size, cf, color, mat, variant, opts)
	local w = Instance.new("WedgePart")
	w.Name = name; w.Anchored = true; w.Size = size; w.CFrame = cf; w.Color = color
	w.Material = mat or M.SmoothPlastic
	if variant then w.MaterialVariant = variant end
	if opts then for k, v in pairs(opts) do w[k] = v end end
	w.Parent = parent
	count += 1
	return w
end
local function noCol(p) p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; return p end

-- palette
local BRICK = C(118, 50, 44)
local STUCCO = C(216, 210, 196)
local TRIM = C(188, 184, 176)
local BASE = C(66, 64, 62)
local BLOCK = C(204, 200, 190)
local STEEL = C(38, 38, 40)
local ALU = C(150, 153, 157)
local GLASS = C(52, 70, 80)

---------------------------------------------------------------------------------------------------------------
-- walls: wall-local frame, X along the wall, Y up, +Z out of the building; the outer face is Z = 0
local W2 = 28   -- half width (x)
local D2 = 20   -- half depth (z)
local GF = 14   -- ground floor height
local UF = 26   -- top of upper floor
local PT = 29.2 -- top of parapet
local T = 1     -- wall thickness

local walls = {
	front = O * CFrame.new(0, 0, -D2) * CFrame.Angles(0, math.pi, 0),       -- u -28..28, + to the viewer's right
	back  = O * CFrame.new(0, 0, D2),                                       -- u -28..28
	right = O * CFrame.new(-W2, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0),  -- u -19 (front) .. 19 (back)
	left  = O * CFrame.new(W2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0),    -- u -19 (back) .. 19 (front)
}
local function at(wcf, u, v, z) return wcf * CFrame.new(u, v, z) end

-- fills [u0,u1]x[v0,v1] around rectangular openings {u0,u1,v0,v1}
local function wall(parent, wcf, u0, u1, v0, v1, holes, color, mat, variant)
	local lo, hi = v1, v0
	for _, h in ipairs(holes) do lo = math.min(lo, h[3]); hi = math.max(hi, h[4]) end
	if #holes == 0 then lo, hi = v1, v1 end
	local function piece(a, b, c, d)
		if b - a > 0.01 and d - c > 0.01 then
			P(parent, "Wall", Vector3.new(b - a, d - c, T), at(wcf, (a + b) / 2, (c + d) / 2, -T / 2), color, mat, variant)
		end
	end
	piece(u0, u1, v0, lo)
	piece(u0, u1, hi, v1)
	if #holes == 0 then return end
	local xs = { u0, u1 }
	for _, h in ipairs(holes) do table.insert(xs, h[1]); table.insert(xs, h[2]) end
	table.sort(xs)
	for i = 1, #xs - 1 do
		local a, b = xs[i], xs[i + 1]
		if b - a > 0.01 then
			local spans = {}
			for _, h in ipairs(holes) do
				if h[1] <= a + 0.001 and h[2] >= b - 0.001 then table.insert(spans, { h[3], h[4] }) end
			end
			table.sort(spans, function(x, y) return x[1] < y[1] end)
			local cur = lo
			for _, s in ipairs(spans) do piece(a, b, cur, s[1]); cur = s[2] end
			piece(a, b, cur, hi)
		end
	end
end

---------------------------------------------------------------------------------------------------------------
-- window kit
local function window(parent, wcf, u, v0, w, h, opts)
	opts = opts or {}
	local g = grp("Window", parent)
	-- interior: dark room or lit curtain
	if opts.lit then
		P(g, "Curtain", Vector3.new(w, h, 0.1), at(wcf, u, v0 + h / 2, -0.98), C(206, 176, 128), M.Fabric)
		local glow = noCol(P(g, "LightSrc", Vector3.new(0.2, 0.2, 0.2), at(wcf, u, v0 + h * 0.6, -0.8), C(0, 0, 0), M.SmoothPlastic, nil, { Transparency = 1 }))
		local l = Instance.new("PointLight"); l.Color = C(255, 196, 130); l.Brightness = 1.6; l.Range = 6; l.Shadows = false; l.Parent = glow
	else
		P(g, "Room", Vector3.new(w, h, 0.1), at(wcf, u, v0 + h / 2, -0.98), C(28, 28, 32), M.SmoothPlastic)
		if opts.blinds then
			P(g, "Blind", Vector3.new(w, h * 0.45, 0.05), at(wcf, u, v0 + h * 0.775, -0.9), C(226, 222, 210), M.Fabric)
		end
	end
	noCol(P(g, "Glass", Vector3.new(w, h, 0.08), at(wcf, u, v0 + h / 2, -0.7), GLASS, M.Glass, nil, { Transparency = 0.45, Reflectance = 0.12 }))
	-- aluminium frame + transom
	local f = 0.22
	P(g, "Frame", Vector3.new(w, f, 0.3), at(wcf, u, v0 + f / 2, -0.65), ALU, M.Metal)
	P(g, "Frame", Vector3.new(w, f, 0.3), at(wcf, u, v0 + h - f / 2, -0.65), ALU, M.Metal)
	P(g, "Frame", Vector3.new(f, h, 0.3), at(wcf, u - w / 2 + f / 2, v0 + h / 2, -0.65), ALU, M.Metal)
	P(g, "Frame", Vector3.new(f, h, 0.3), at(wcf, u + w / 2 - f / 2, v0 + h / 2, -0.65), ALU, M.Metal)
	P(g, "Mullion", Vector3.new(f, h, 0.2), at(wcf, u, v0 + h / 2, -0.65), ALU, M.Metal)
	-- sill + lintel
	P(g, "Sill", Vector3.new(w + 0.8, 0.35, 0.9), at(wcf, u, v0 - 0.17, -0.15), TRIM, M.Concrete, "ConcreteStained")
	P(g, "Lintel", Vector3.new(w + 0.6, 0.55, 0.25), at(wcf, u, v0 + h + 0.27, 0.12), TRIM, M.Concrete, "ConcreteStained")
	-- security bars
	if opts.bars ~= false then
		local bz = 0.32
		P(g, "BarFrame", Vector3.new(w + 0.3, 0.18, 0.18), at(wcf, u, v0 + 0.15, bz), STEEL, M.Metal)
		P(g, "BarFrame", Vector3.new(w + 0.3, 0.18, 0.18), at(wcf, u, v0 + h - 0.1, bz), STEEL, M.Metal)
		P(g, "BarFrame", Vector3.new(w + 0.3, 0.18, 0.18), at(wcf, u, v0 + h * 0.5, bz), STEEL, M.Metal)
		local n = math.max(3, math.floor(w / 0.75))
		for i = 0, n do
			local x = u - w / 2 - 0.05 + (w + 0.1) * i / n
			noCol(P(g, "Bar", Vector3.new(0.12, h, 0.12), at(wcf, x, v0 + h / 2, bz), STEEL, M.Metal))
		end
	end
	return g
end

-- wall-mounted AC condenser on brackets
local function condenser(parent, wcf, u, v)
	local g = grp("ACUnit", parent)
	local body = P(g, "Body", Vector3.new(3, 2.3, 1.3), at(wcf, u, v, 0.85), C(214, 212, 204), M.Metal, "PaintedMetalA")
	P(g, "Top", Vector3.new(3.1, 0.12, 1.4), at(wcf, u, v + 1.2, 0.85), C(190, 188, 180), M.Metal)
	P(g, "FanGuard", Vector3.new(0.08, 1.85, 1.85), at(wcf, u - 0.35, v, 1.52) * CFrame.Angles(0, math.pi / 2, 0), C(42, 42, 44), M.Metal, nil, { shape = Enum.PartType.Cylinder })
	P(g, "FanHub", Vector3.new(0.12, 0.45, 0.45), at(wcf, u - 0.35, v, 1.57) * CFrame.Angles(0, math.pi / 2, 0), C(120, 120, 122), M.Metal, nil, { shape = Enum.PartType.Cylinder })
	for i = -1, 1 do noCol(P(g, "Grille", Vector3.new(1.85, 0.06, 0.06), at(wcf, u - 0.35, v + i * 0.45, 1.6), C(60, 60, 62), M.Metal)) end
	P(g, "Vent", Vector3.new(0.7, 1.6, 0.05), at(wcf, u + 1.05, v, 1.52), C(170, 168, 160), M.Metal, "CorrugatedPlain")
	for _, du in ipairs({ -1.1, 1.1 }) do
		P(g, "Bracket", Vector3.new(0.15, 0.15, 1.6), at(wcf, du + u, v - 1.25, 0.8), STEEL, M.Metal)
		W(g, "Brace", Vector3.new(0.12, 1.2, 1.4), at(wcf, du + u, v - 1.95, 0.75) * CFrame.Angles(0, math.pi, 0), STEEL, M.Metal)
	end
	noCol(P(g, "Pipe", Vector3.new(0.18, 0.18, 0.9), at(wcf, u + 1.3, v - 0.6, 0.25), C(176, 120, 80), M.Metal))
	return g
end

-- downpipe from roof to ground
local function downpipe(parent, wcf, u)
	local g = grp("Downpipe", parent)
	P(g, "Pipe", Vector3.new(0.45, PT - 1.2, 0.45), at(wcf, u, (PT - 1.2) / 2 + 0.3, 0.3), C(150, 146, 140), M.Metal, "PaintedMetalB")
	P(g, "Head", Vector3.new(1, 0.9, 0.9), at(wcf, u, PT - 1.3, 0.45), C(140, 136, 130), M.Metal)
	P(g, "Shoe", Vector3.new(0.45, 0.45, 0.9), at(wcf, u, 0.35, 0.6), C(150, 146, 140), M.Metal)
	for v = 4, PT - 3, 6 do P(g, "Clip", Vector3.new(0.6, 0.15, 0.55), at(wcf, u, v, 0.28), STEEL, M.Metal) end
end

local function label(part, face, text, color, bg, font, opts)
	opts = opts or {}
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = opts.pps or 40
	sg.LightInfluence = opts.light or 1
	sg.Brightness = opts.bright or 1
	sg.Parent = part
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = bg and 0 or 1
	if bg then t.BackgroundColor3 = bg end
	t.Text = text
	t.TextColor3 = color
	t.Font = font or Enum.Font.GothamBlack
	t.TextScaled = true
	t.Parent = sg
	if opts.stroke then t.TextStrokeTransparency = 0; t.TextStrokeColor3 = opts.stroke end
	return t
end

---------------------------------------------------------------------------------------------------------------
-- 1. shell
local shell = grp("Shell")
local F = walls.front
local frontHoles = {
	{ -25.5, -15.5, 0, 10.2 },  -- roll-up shutter A
	{ -12.5, 1.5, 2.6, 10.2 },  -- shop window
	{ 3, 8, 0, 9.4 },          -- shop door
	{ 11, 22.5, 0, 10.2 },     -- roll-up shutter B
}
wall(shell, F, -W2, W2, 0, GF, frontHoles, BRICK, M.Brick, "HoodPaintedBrick")
local upperFront = {}
for _, u in ipairs({ -21, -10.5, 0, 10.5, 21 }) do table.insert(upperFront, { u - 2.6, u + 2.6, 16.6, 23.2 }) end
wall(shell, F, -W2, W2, GF, UF, upperFront, STUCCO, M.Plaster, "HoodStuccoCracked")
wall(shell, F, -W2, W2, UF, PT, {}, STUCCO, M.Plaster, "HoodStuccoCracked")

local B = walls.back
wall(shell, B, -W2, W2, 0, GF, { { -18, -14, 0, 8.4 }, { 8, 12, 5, 9 }, { 16, 20, 5, 9 } }, BLOCK, M.Concrete, "HoodCinderBlock")
local upperBack = {}
for _, u in ipairs({ -18, -6, 6, 18 }) do table.insert(upperBack, { u - 2, u + 2, 17, 22.5 }) end
wall(shell, B, -W2, W2, GF, UF, upperBack, BLOCK, M.Concrete, "HoodCinderBlock")
wall(shell, B, -W2, W2, UF, PT, {}, BLOCK, M.Concrete, "HoodCinderBlock")

local R = walls.right -- faces the side street, carries the stair
local SL = D2 - T -- side wall half length
wall(shell, R, -SL, SL, 0, GF, { { -14, -10, 5, 9 }, { 1, 5, 0, 8.4 } }, BLOCK, M.Concrete, "HoodCinderBlock")
wall(shell, R, -SL, SL, GF, UF, { { -14.5, -9.5, 16.6, 23.2 }, { -5, 0, 16.6, 23.2 }, { 11, 15, 14, 21.6 } }, STUCCO, M.Plaster, "HoodStuccoCracked")
wall(shell, R, -SL, SL, UF, PT, {}, STUCCO, M.Plaster, "HoodStuccoCracked")

local Lw = walls.left -- blank-ish wall with a mural
wall(shell, Lw, -SL, SL, 0, GF, { { -12, -8, 5, 9 } }, BLOCK, M.Concrete, "HoodCinderBlock")
wall(shell, Lw, -SL, SL, GF, UF, { { -10, -5, 16.6, 23.2 }, { 3, 8, 16.6, 23.2 } }, STUCCO, M.Plaster, "HoodStuccoCracked")
wall(shell, Lw, -SL, SL, UF, PT, {}, STUCCO, M.Plaster, "HoodStuccoCracked")

-- floor slabs + roof
P(shell, "GroundSlab", Vector3.new(W2 * 2 - 2, 0.6, D2 * 2 - 2), O * CFrame.new(0, 0.3, 0), C(120, 118, 112), M.Concrete, "ConcreteStained")
P(shell, "FloorSlab", Vector3.new(W2 * 2 - 2, 0.8, D2 * 2 - 2), O * CFrame.new(0, GF, 0), C(120, 118, 112), M.Concrete)
P(shell, "Roof", Vector3.new(W2 * 2 - 2, 0.8, D2 * 2 - 2), O * CFrame.new(0, UF - 0.2, 0), C(58, 58, 60), M.Asphalt, "RoofFlatBitumen")

-- 2. trim bands that wrap all four walls: plinth, floor string course, cornice, parapet coping
local trim = grp("Trim")
local function band(name, v, h, out, color, mat, variant)
	P(trim, name, Vector3.new(W2 * 2 + out * 2, h, out), O * CFrame.new(0, v, -D2 - out / 2), color, mat, variant)
	P(trim, name, Vector3.new(W2 * 2 + out * 2, h, out), O * CFrame.new(0, v, D2 + out / 2), color, mat, variant)
	P(trim, name, Vector3.new(out, h, D2 * 2), O * CFrame.new(-W2 - out / 2, v, 0), color, mat, variant)
	P(trim, name, Vector3.new(out, h, D2 * 2), O * CFrame.new(W2 + out / 2, v, 0), color, mat, variant)
end
band("Plinth", 0.45, 0.9, 0.18, BASE, M.Concrete, "HoodConcreteDirty")
band("StringCourse", GF + 0.3, 0.7, 0.35, TRIM, M.Concrete, "ConcreteStained")
band("Cornice", UF + 0.35, 0.7, 0.3, TRIM, M.Concrete, "ConcreteStained")
band("CorniceLip", UF + 0.85, 0.3, 0.5, TRIM, M.Concrete, "ConcreteStained")
band("Coping", PT + 0.2, 0.4, 0.35, BRICK, M.Concrete, "ConcretePlain")
-- coping inner lip so the parapet reads thick from the roof
P(trim, "CopingIn", Vector3.new(W2 * 2, 0.4, 1.4), O * CFrame.new(0, PT + 0.2, -D2 + 0.7), BRICK, M.Concrete)
P(trim, "CopingIn", Vector3.new(W2 * 2, 0.4, 1.4), O * CFrame.new(0, PT + 0.2, D2 - 0.7), BRICK, M.Concrete)
P(trim, "CopingIn", Vector3.new(1.4, 0.4, D2 * 2), O * CFrame.new(-W2 + 0.7, PT + 0.2, 0), BRICK, M.Concrete)
P(trim, "CopingIn", Vector3.new(1.4, 0.4, D2 * 2), O * CFrame.new(W2 - 0.7, PT + 0.2, 0), BRICK, M.Concrete)
-- stone cladding on the front corners of the ground floor (gun-shop style)
for _, u in ipairs({ -26.75, 26 }) do
	local wdt = (u < 0) and 2.5 or 4
	P(trim, "StoneCorner", Vector3.new(wdt + 0.4, GF - 0.9, 0.35), at(F, u < 0 and -26.75 or 25.75, 0.9 + (GF - 0.9) / 2, 0.17), C(150, 144, 136), M.Cobblestone, "StoneFieldLight")
end
P(trim, "StoneCornerSide", Vector3.new(0.35, GF - 0.9, 3), O * CFrame.new(-W2 - 0.17, 0.9 + (GF - 0.9) / 2, -D2 + 1.5), C(150, 144, 136), M.Cobblestone, "StoneFieldLight")
P(trim, "StoneCornerSide", Vector3.new(0.35, GF - 0.9, 3), O * CFrame.new(W2 + 0.17, 0.9 + (GF - 0.9) / 2, -D2 + 1.5), C(150, 144, 136), M.Cobblestone, "StoneFieldLight")

-- 3. upper-floor windows
local win = grp("Windows")
local litFront = { [2] = true, [5] = true }
for i, u in ipairs({ -21, -10.5, 0, 10.5, 21 }) do
	window(win, F, u, 16.6, 5.2, 6.6, { lit = litFront[i], blinds = (i == 3) })
end
for i, u in ipairs({ -18, -6, 6, 18 }) do window(win, B, u, 17, 4, 5.5, { lit = (i == 2) }) end
window(win, R, -12, 16.6, 5, 6.6, { lit = true })
window(win, R, -2.5, 16.6, 5, 6.6, { blinds = true })
window(win, Lw, -7.5, 16.6, 5, 6.6, {})
window(win, Lw, 5.5, 16.6, 5, 6.6, { lit = true })
-- small barred ground windows on the side + back
window(win, R, -12, 5, 4, 4, {})
window(win, Lw, -10, 5, 4, 4, {})
window(win, B, 10, 5, 4, 4, {})
window(win, B, 18, 5, 4, 4, { lit = true })

-- 4. storefront
local shop = grp("Storefront")
-- roll-up shutters (one half open)
local function shutter(u0, u1, openTo)
	local w = u1 - u0
	local u = (u0 + u1) / 2
	local top = 10.2
	local bottom = openTo or 0
	P(shop, "Shutter", Vector3.new(w, top - bottom, 0.2), at(F, u, (top + bottom) / 2, -0.45), C(150, 140, 126), M.CorrodedMetal, "ShutterRusty")
	P(shop, "BottomBar", Vector3.new(w, 0.3, 0.35), at(F, u, bottom + 0.15, -0.42), C(80, 76, 70), M.Metal)
	P(shop, "Housing", Vector3.new(w + 0.6, 1.3, 1.1), at(F, u, top + 0.55, 0.15), C(120, 116, 108), M.Metal, "MetalPaintedRusty")
	P(shop, "Guide", Vector3.new(0.3, top, 0.4), at(F, u0 + 0.15, top / 2, -0.3), STEEL, M.Metal)
	P(shop, "Guide", Vector3.new(0.3, top, 0.4), at(F, u1 - 0.15, top / 2, -0.3), STEEL, M.Metal)
	P(shop, "Padlock", Vector3.new(0.35, 0.45, 0.2), at(F, u, bottom + 0.4, -0.2), C(170, 150, 80), M.Metal)
	if bottom > 0 then
		-- dark garage interior under a half-open shutter
		P(shop, "Dark", Vector3.new(w, bottom, 0.1), at(F, u, bottom / 2, -3), C(18, 18, 20), M.SmoothPlastic)
	end
end
shutter(-25.5, -15.5)
shutter(11, 22.5, 3.2)
-- graffiti tag on shutter A (text, sprayed look)
local tagPart = noCol(P(shop, "Tag", Vector3.new(8, 3.2, 0.05), at(F, -20.5, 5, -0.33), C(0, 0, 0), M.SmoothPlastic, nil, { Transparency = 1 }))
local tag = label(tagPart, Enum.NormalId.Back, "TRAP$IDE", C(64, 196, 120), nil, Enum.Font.PermanentMarker, { stroke = C(20, 20, 20) })
tag.Rotation = -6

-- shop window with an interior you can read through the glass
local SW = -5.5 -- window centre u
P(shop, "ShopGlass", Vector3.new(14, 7.6, 0.1), at(F, SW, 2.6 + 3.8, -0.6), C(70, 90, 96), M.Glass, nil, { Transparency = 0.6, Reflectance = 0.08, CanCollide = true })
P(shop, "ShopSill", Vector3.new(14.6, 0.4, 1.0), at(F, SW, 2.4, -0.2), TRIM, M.Concrete, "ConcreteStained")
for _, du in ipairs({ -7, 7 }) do P(shop, "ShopFrame", Vector3.new(0.3, 7.6, 0.35), at(F, SW + du + (du < 0 and 0.15 or -0.15), 6.4, -0.6), ALU, M.Metal) end
P(shop, "ShopFrame", Vector3.new(14, 0.3, 0.35), at(F, SW, 10.05, -0.6), ALU, M.Metal)
P(shop, "ShopMullion", Vector3.new(0.25, 7.6, 0.3), at(F, SW, 6.4, -0.6), ALU, M.Metal)
-- security grille over the shop window
for i = 0, 18 do noCol(P(shop, "Grille", Vector3.new(0.12, 7.8, 0.12), at(F, SW - 7 + 14 * i / 18, 6.4, 0.25), STEEL, M.Metal)) end
for _, v in ipairs({ 2.8, 6.4, 10 }) do P(shop, "GrilleRail", Vector3.new(14.3, 0.18, 0.18), at(F, SW, v, 0.25), STEEL, M.Metal) end
-- interior: floor, back wall, shelves stocked with colourful goods, ceiling light
local inside = grp("Interior", shop)
P(inside, "Floor", Vector3.new(24, 0.2, 14), at(F, -1, 0.7, -8), C(200, 196, 186), M.CeramicTiles)
P(inside, "BackWall", Vector3.new(24, GF - 1, 0.4), at(F, -1, GF / 2, -15), C(236, 230, 214), M.SmoothPlastic)
P(inside, "SideWall", Vector3.new(0.4, GF - 1, 14), at(F, -13.2, GF / 2, -8), C(236, 230, 214), M.SmoothPlastic)
P(inside, "SideWall", Vector3.new(0.4, GF - 1, 14), at(F, 10.6, GF / 2, -8), C(236, 230, 214), M.SmoothPlastic)
P(inside, "Ceiling", Vector3.new(24, 0.2, 14), at(F, -1, GF - 0.6, -8), C(240, 238, 232), M.SmoothPlastic)
local goods = { C(220, 50, 40), C(250, 200, 40), C(40, 120, 220), C(60, 180, 80), C(240, 120, 30), C(150, 60, 200), C(240, 240, 240) }
local gi = 0
for _, row in ipairs({ { -9, -4.5 }, { -2.5, -10 }, { 4, -4.5 } }) do
	local su, sz = row[1], row[2]
	P(inside, "Shelf", Vector3.new(5, 6.5, 1.6), at(F, su, 0.8 + 3.25, sz), C(90, 92, 98), M.Metal)
	for level = 0, 3 do
		for k = 0, 4 do
			gi += 1
			noCol(P(inside, "Goods", Vector3.new(0.8, 0.9 + (k % 2) * 0.3, 0.5), at(F, su - 2 + k * 1, 1.6 + level * 1.5 + 0.5, sz + 0.75), goods[(gi % #goods) + 1], M.SmoothPlastic))
		end
	end
end
-- drinks cooler on the back wall, glowing
local cooler = P(inside, "Cooler", Vector3.new(8, 7.5, 0.3), at(F, -1, 4.6, -14.6), C(200, 230, 255), M.Neon, nil, { Transparency = 0.15 })
for i = -3, 3 do noCol(P(inside, "CoolerDoor", Vector3.new(0.15, 7.5, 0.2), at(F, -1 + i * 1.15, 4.6, -14.3), ALU, M.Metal)) end
P(inside, "Counter", Vector3.new(6, 3.6, 2), at(F, 8, 2.6, -6), C(110, 80, 60), M.WoodPlanks, "WoodPlanksOld")
P(inside, "Register", Vector3.new(1.2, 0.9, 1), at(F, 8, 4.85, -6), C(30, 30, 30), M.SmoothPlastic)
for _, du in ipairs({ -7, 1, 7 }) do
	local tube = P(inside, "Tube", Vector3.new(4, 0.2, 0.4), at(F, du, GF - 0.8, -7), C(245, 250, 255), M.Neon)
	local pl = Instance.new("PointLight"); pl.Color = C(235, 245, 255); pl.Brightness = 1.4; pl.Range = 14; pl.Shadows = false; pl.Parent = tube
end
-- window posters + neon OPEN sign
local function poster(u, v, w, h, text, fg, bg)
	local p = noCol(P(shop, "Poster", Vector3.new(w, h, 0.05), at(F, u, v, -0.68), bg, M.SmoothPlastic))
	label(p, Enum.NormalId.Back, text, fg, bg, Enum.Font.GothamBlack)
end
poster(-10.4, 8.4, 2.6, 1.5, "SALE", C(255, 230, 40), C(210, 30, 30))
poster(-10.4, 4.0, 2.6, 2.6, "COLD\nBEER", C(255, 255, 255), C(20, 70, 170))
poster(-0.6, 4.0, 2.6, 2.0, "WE ACCEPT\nEBT", C(20, 20, 20), C(250, 250, 240))
poster(-0.6, 8.5, 2.4, 1.3, "LOTTO", C(255, 255, 255), C(30, 140, 60))
local openSign = noCol(P(shop, "OpenSign", Vector3.new(3.4, 1.4, 0.1), at(F, -5.5, 7.6, -0.9), C(255, 40, 60), M.SmoothPlastic, nil, { Transparency = 1 }))
label(openSign, Enum.NormalId.Back, "OPEN", C(255, 60, 90), nil, Enum.Font.Arcade, { light = 0, bright = 3, stroke = C(255, 0, 40) })
local openGlow = Instance.new("PointLight"); openGlow.Color = C(255, 40, 80); openGlow.Brightness = 0.8; openGlow.Range = 5; openGlow.Parent = openSign

-- shop door: glass door in an aluminium frame, push bar, step
P(shop, "DoorGlass", Vector3.new(4.6, 8.6, 0.12), at(F, 5.5, 4.7, -0.65), C(70, 90, 96), M.Glass, nil, { Transparency = 0.55, Reflectance = 0.08 })
P(shop, "DoorFrame", Vector3.new(5, 0.4, 0.3), at(F, 5.5, 9.2, -0.62), ALU, M.Metal)
P(shop, "DoorFrame", Vector3.new(5, 0.9, 0.3), at(F, 5.5, 0.9, -0.62), ALU, M.Metal)
P(shop, "DoorFrame", Vector3.new(0.3, 9.4, 0.3), at(F, 3.15, 4.7, -0.62), ALU, M.Metal)
P(shop, "DoorFrame", Vector3.new(0.3, 9.4, 0.3), at(F, 7.85, 4.7, -0.62), ALU, M.Metal)
P(shop, "PushBar", Vector3.new(3.6, 0.2, 0.3), at(F, 5.5, 4.4, -0.4), ALU, M.Metal)
P(shop, "Step", Vector3.new(6, 0.35, 1.4), at(F, 5.5, 0.17, 0.6), C(150, 148, 142), M.Concrete, "ConcreteStained")
local hours = noCol(P(shop, "Hours", Vector3.new(1.4, 1.6, 0.05), at(F, 6.4, 6.2, -0.75), C(255, 255, 255), M.SmoothPlastic))
label(hours, Enum.NormalId.Back, "OPEN\n7AM-2AM\n7 DAYS", C(30, 30, 30), C(250, 250, 250), Enum.Font.GothamBold)

-- fascia sign over the shop + rusty awning bands over the shutters
local sign = P(shop, "SignBoard", Vector3.new(21, 3, 0.6), at(F, -2.5, 12, 0.3), C(250, 205, 30), M.SmoothPlastic)
local st = label(sign, Enum.NormalId.Back, "LUCKY STAR MARKET", C(200, 25, 25), C(250, 205, 30), Enum.Font.GothamBlack, { pps = 30 })
P(shop, "SignTrim", Vector3.new(21.4, 0.25, 0.75), at(F, -2.5, 13.55, 0.3), C(200, 25, 25), M.Metal)
P(shop, "SignTrim", Vector3.new(21.4, 0.25, 0.75), at(F, -2.5, 10.45, 0.3), C(200, 25, 25), M.Metal)
local tagline = noCol(P(shop, "Tagline", Vector3.new(13, 0.8, 0.05), at(F, -2.5, 10.9, 0.62), C(0, 0, 0), M.SmoothPlastic, nil, { Transparency = 1 }))
label(tagline, Enum.NormalId.Back, "LIQUOR · LOTTO · ATM · CHECKS CASHED", C(40, 30, 20), nil, Enum.Font.GothamBold)
for _, uu in ipairs({ -10, -2.5, 5 }) do
	local g = grp("SignLamp", shop)
	P(g, "Arm", Vector3.new(0.18, 0.18, 2.2), at(F, uu, 14.3, 1.1), STEEL, M.Metal)
	P(g, "ArmDrop", Vector3.new(0.18, 0.7, 0.18), at(F, uu, 14.6, 0.1), STEEL, M.Metal)
	local head = P(g, "Shade", Vector3.new(1.0, 0.45, 0.8), at(F, uu, 14.1, 2.2), C(30, 60, 40), M.Metal)
	local sp = Instance.new("SpotLight"); sp.Face = Enum.NormalId.Back; sp.Angle = 70; sp.Range = 9; sp.Brightness = 2.2; sp.Color = C(255, 214, 160); sp.Parent = head
	head.CFrame = head.CFrame * CFrame.Angles(math.rad(-35), 0, 0)
end
-- awning band: sloped rusty corrugated strip over each shutter
for _, s in ipairs({ { -25.5, -15.5 }, { 11, 22.5 } }) do
	local w = s[2] - s[1] + 1
	local u = (s[1] + s[2]) / 2
	P(shop, "Awning", Vector3.new(w, 0.15, 2.6), at(F, u, 12.4, 1.2) * CFrame.Angles(math.rad(-18), 0, 0), C(150, 96, 64), M.CorrodedMetal, "CorrugatedRusty")
	P(shop, "AwningFace", Vector3.new(w, 0.8, 0.12), at(F, u, 11.65, 2.45), C(120, 60, 40), M.CorrodedMetal, "MetalPaintedRusty")
end

-- 5. condensers, conduit, meters, downpipes
local mep = grp("Services")
condenser(mep, F, -15.75, 18.5)
condenser(mep, F, 15.75, 18.2)
condenser(mep, R, -7.2, 18.5)
condenser(mep, Lw, -1, 19)
condenser(mep, B, 0, 18.5)
condenser(mep, B, 12, 17.5)
downpipe(mep, B, -26.5)
downpipe(mep, B, 26.5)
downpipe(mep, Lw, 18)
-- electric meter bank + conduit on the left wall
P(mep, "MeterPanel", Vector3.new(4, 3, 0.6), at(Lw, 10, 5.5, 0.3), C(150, 152, 150), M.Metal, "PaintedMetalB")
for i = -1, 1 do
	P(mep, "Meter", Vector3.new(0.3, 0.9, 0.9), at(Lw, 10 + i * 1.2, 5.7, 0.75) * CFrame.Angles(0, math.pi / 2, 0), C(210, 215, 215), M.Glass, nil, { shape = Enum.PartType.Cylinder })
end
P(mep, "Conduit", Vector3.new(0.3, PT - 8, 0.3), at(Lw, 11.6, 7 + (PT - 8) / 2, 0.25), C(120, 122, 120), M.Metal)
P(mep, "Weatherhead", Vector3.new(0.5, 0.6, 0.5), at(Lw, 11.6, PT + 0.6, 0.25), C(90, 90, 90), M.Metal)

-- 6. side mural on the left (alley) wall
local muralPart = P(mep, "Mural", Vector3.new(14, 8.5, 0.06), at(Lw, 0, 5.2, 0.03), C(255, 255, 255), M.SmoothPlastic, nil, { Transparency = 1, CanCollide = false })
do
	local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Back; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 30; sg.Parent = muralPart
	local bg = Instance.new("Frame"); bg.Size = UDim2.fromScale(1, 1); bg.BackgroundColor3 = C(40, 110, 160); bg.BorderSizePixel = 0; bg.Parent = sg
	local gr = Instance.new("UIGradient"); gr.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C(250, 120, 60)), ColorSequenceKeypoint.new(0.5, C(220, 60, 120)), ColorSequenceKeypoint.new(1, C(60, 90, 200)) }); gr.Rotation = 25; gr.Parent = bg
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 18); corner.Parent = bg
	local t1 = Instance.new("TextLabel"); t1.BackgroundTransparency = 1; t1.Size = UDim2.fromScale(0.95, 0.62); t1.Position = UDim2.fromScale(0.025, 0.05)
	t1.Text = "NORTH SIDE"; t1.Font = Enum.Font.PermanentMarker; t1.TextScaled = true; t1.TextColor3 = C(255, 240, 90); t1.TextStrokeTransparency = 0; t1.TextStrokeColor3 = C(20, 10, 40); t1.Rotation = -4; t1.Parent = bg
	local t2 = Instance.new("TextLabel"); t2.BackgroundTransparency = 1; t2.Size = UDim2.fromScale(0.7, 0.25); t2.Position = UDim2.fromScale(0.15, 0.68)
	t2.Text = "rest easy lil rome"; t2.Font = Enum.Font.Kalam; t2.TextScaled = true; t2.TextColor3 = C(255, 255, 255); t2.TextStrokeTransparency = 0.3; t2.Parent = bg
end

-- 7. side stair to the upstairs apartments (right wall)
local stair = grp("ExteriorStair")
local landingU0, landingU1 = 9.5, 17.5
local LZ = 4 -- stair depth out from the wall
P(stair, "Landing", Vector3.new(landingU1 - landingU0, 0.35, LZ), at(R, (landingU0 + landingU1) / 2, GF - 0.18, LZ / 2 + 0.1), C(110, 112, 114), M.DiamondPlate, "MetalPlate")
P(stair, "LandingEdge", Vector3.new(landingU1 - landingU0, 0.7, 0.25), at(R, (landingU0 + landingU1) / 2, GF - 0.5, LZ + 0.1), STEEL, M.Metal)
for _, uu in ipairs({ landingU0 + 0.3, landingU1 - 0.3 }) do
	P(stair, "Post", Vector3.new(0.45, GF, 0.45), at(R, uu, GF / 2, LZ - 0.1), STEEL, M.Metal)
end
local steps = 14
local runU0 = landingU0 - 15 -- bottom of the flight
for i = 1, steps do
	local u = runU0 + (i - 0.5) * (15 / steps)
	P(stair, "Tread", Vector3.new(15 / steps + 0.05, 0.22, LZ - 0.6), at(R, u, i * (GF / steps) - 0.11, LZ / 2 + 0.2), C(110, 112, 114), M.DiamondPlate, "MetalPlate")
end
local len = math.sqrt(15 ^ 2 + GF ^ 2)
local ang = math.atan2(GF, 15)
for _, z in ipairs({ 0.25, LZ - 0.15 }) do
	P(stair, "Stringer", Vector3.new(len, 0.9, 0.2), at(R, runU0 + 7.5, GF / 2 - 0.3, z) * CFrame.Angles(0, 0, ang), STEEL, M.Metal)
end
-- railing: sloped rail + landing rail + balusters
P(stair, "Rail", Vector3.new(len, 0.15, 0.15), at(R, runU0 + 7.5, GF / 2 + 3.2, LZ - 0.15) * CFrame.Angles(0, 0, ang), STEEL, M.Metal)
P(stair, "Rail", Vector3.new(landingU1 - landingU0, 0.15, 0.15), at(R, (landingU0 + landingU1) / 2, GF + 3.4, LZ - 0.15), STEEL, M.Metal)
P(stair, "Rail", Vector3.new(0.15, 0.15, LZ), at(R, landingU1 - 0.1, GF + 3.4, LZ / 2), STEEL, M.Metal)
for i = 0, 10 do
	local u = runU0 + 0.7 + i * 1.4
	local v = (u - runU0) / 15 * GF
	noCol(P(stair, "Baluster", Vector3.new(0.12, 3.3, 0.12), at(R, u, v + 1.65, LZ - 0.15), STEEL, M.Metal))
end
for i = 0, 5 do
	noCol(P(stair, "Baluster", Vector3.new(0.12, 3.4, 0.12), at(R, landingU0 + 0.4 + i * 1.45, GF + 1.7, LZ - 0.15), STEEL, M.Metal))
end
-- upstairs door (steel security door) + porch light
P(stair, "AptDoor", Vector3.new(4, 7.6, 0.2), at(R, 13, GF + 3.8, -0.4), C(70, 74, 80), M.Metal, "PaintedMetalA")
P(stair, "DoorGate", Vector3.new(4.2, 7.8, 0.12), at(R, 13, GF + 3.9, 0.15), STEEL, M.Metal, nil, { Transparency = 0.0 })
for i = 0, 6 do noCol(P(stair, "GateBar", Vector3.new(0.1, 7.6, 0.14), at(R, 11.1 + i * 0.63, GF + 3.9, 0.22), STEEL, M.Metal)) end
local porch = P(stair, "PorchLight", Vector3.new(0.7, 0.9, 0.5), at(R, 15.8, GF + 7, 0.25), C(255, 220, 160), M.Neon)
local pl = Instance.new("PointLight"); pl.Color = C(255, 200, 140); pl.Brightness = 1.2; pl.Range = 10; pl.Parent = porch
-- side + back doors on the ground floor
P(stair, "BackDoor", Vector3.new(4, 8.4, 0.2), at(B, -16, 4.2, -0.4), C(80, 84, 90), M.Metal, "PaintedMetalA")
P(stair, "SideDoor", Vector3.new(4, 8.4, 0.2), at(R, 3, 4.2, -0.4), C(90, 50, 40), M.Metal, "MetalPaintedRusty")

-- 8. roof: HVAC, hatch, vents, satellite dish, rooftop billboard
local roof = grp("Roof")
local RY = UF + 0.2
local function rp(name, size, x, y, z, color, mat, variant, rot)
	return P(roof, name, size, O * CFrame.new(x, RY + y, z) * (rot or CFrame.identity), color, mat, variant)
end
rp("HVAC", Vector3.new(7, 3.2, 5), -12, 1.6, 4, C(196, 196, 190), M.Metal, "PaintedMetalA")
rp("HVACFan", Vector3.new(0.4, 2.6, 2.6), -13.5, 3.3, 4, C(50, 50, 52), M.Metal, nil, CFrame.Angles(0, 0, math.pi / 2)).Shape = Enum.PartType.Cylinder
rp("HVACVent", Vector3.new(2, 1.8, 0.1), -12, 1.6, 1.45, C(150, 150, 146), M.Metal, "CorrugatedPlain")
rp("Duct", Vector3.new(1.6, 1.6, 6), -12, 1, 9.5, C(176, 176, 172), M.Metal)
rp("Hatch", Vector3.new(3.4, 1.2, 3.4), 8, 0.6, 8, C(130, 128, 120), M.Metal, "PaintedMetalB")
for i, x in ipairs({ 2, 4, 14 }) do
	local v = rp("Vent", Vector3.new(2.4, 0.6, 0.6), x, 1.2, -6 + i * 3, C(150, 150, 150), M.Metal, nil, CFrame.Angles(0, 0, math.pi / 2))
	v.Shape = Enum.PartType.Cylinder
	local cap = rp("VentCap", Vector3.new(0.3, 1.1, 1.1), x, 2.5, -6 + i * 3, C(110, 110, 110), M.Metal, nil, CFrame.Angles(0, 0, math.pi / 2))
	cap.Shape = Enum.PartType.Cylinder
end
rp("DishPole", Vector3.new(0.25, 2.4, 0.25), 20, 1.2, -12, STEEL, M.Metal)
local dish = rp("Dish", Vector3.new(0.4, 2.6, 2.6), 20, 2.6, -12.3, C(220, 220, 216), M.SmoothPlastic, nil, CFrame.Angles(0, math.rad(80), math.rad(20)))
dish.Shape = Enum.PartType.Cylinder
-- billboard on a steel frame, set back on the roof, facing the street
local bb = grp("Billboard", roof)
local BBY0, BBY1 = RY + 9, RY + 19
local bz = 10
for _, x in ipairs({ -8, 8 }) do
	P(bb, "Column", Vector3.new(0.9, BBY1 - RY, 0.9), O * CFrame.new(x, RY + (BBY1 - RY) / 2, bz + 1), STEEL, M.Metal, "RustCoarse")
	P(bb, "Brace", Vector3.new(0.4, math.sqrt(9 ^ 2 + 4 ^ 2), 0.4), O * CFrame.new(x, RY + 4.5, bz + 3) * CFrame.Angles(math.atan2(4, 9), 0, 0), STEEL, M.Metal, "RustCoarse")
	P(bb, "Foot", Vector3.new(2, 0.4, 2), O * CFrame.new(x, RY + 0.2, bz + 1), C(120, 118, 112), M.Concrete)
end
P(bb, "Truss", Vector3.new(26, 0.5, 0.5), O * CFrame.new(0, BBY0 + 2, bz + 0.6), STEEL, M.Metal, "RustCoarse")
P(bb, "Truss", Vector3.new(26, 0.5, 0.5), O * CFrame.new(0, BBY1 - 2, bz + 0.6), STEEL, M.Metal, "RustCoarse")
P(bb, "Catwalk", Vector3.new(26, 0.2, 2.2), O * CFrame.new(0, BBY0 - 0.6, bz - 1), C(90, 90, 90), M.Metal, "RustyGrate")
P(bb, "CatwalkRail", Vector3.new(26, 0.12, 0.12), O * CFrame.new(0, BBY0 + 2.4, bz - 2), STEEL, M.Metal)
local board = P(bb, "Board", Vector3.new(26, BBY1 - BBY0, 0.4), O * CFrame.new(0, (BBY0 + BBY1) / 2, bz), C(230, 230, 225), M.SmoothPlastic)
P(bb, "BoardFrame", Vector3.new(26.6, 0.5, 0.6), O * CFrame.new(0, BBY1 + 0.2, bz), C(60, 60, 62), M.Metal)
P(bb, "BoardFrame", Vector3.new(26.6, 0.5, 0.6), O * CFrame.new(0, BBY0 - 0.2, bz), C(60, 60, 62), M.Metal)
do
	local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Front; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 20; sg.Parent = board
	local bg = Instance.new("Frame"); bg.Size = UDim2.fromScale(1, 1); bg.BackgroundColor3 = C(16, 26, 60); bg.BorderSizePixel = 0; bg.Parent = sg
	local band = Instance.new("Frame"); band.Size = UDim2.fromScale(0.36, 1); band.Position = UDim2.fromScale(0.64, 0); band.BackgroundColor3 = C(240, 190, 30); band.BorderSizePixel = 0; band.Parent = bg
	local t1 = Instance.new("TextLabel"); t1.BackgroundTransparency = 1; t1.Size = UDim2.fromScale(0.6, 0.42); t1.Position = UDim2.fromScale(0.03, 0.06)
	t1.Text = "HURT IN A WRECK?"; t1.Font = Enum.Font.GothamBlack; t1.TextScaled = true; t1.TextColor3 = C(255, 255, 255); t1.Parent = bg
	local t2 = Instance.new("TextLabel"); t2.BackgroundTransparency = 1; t2.Size = UDim2.fromScale(0.6, 0.36); t2.Position = UDim2.fromScale(0.03, 0.56)
	t2.Text = "305-555-0142"; t2.Font = Enum.Font.GothamBlack; t2.TextScaled = true; t2.TextColor3 = C(240, 190, 30); t2.Parent = bg
	local t3 = Instance.new("TextLabel"); t3.BackgroundTransparency = 1; t3.Size = UDim2.fromScale(0.32, 0.8); t3.Position = UDim2.fromScale(0.66, 0.1)
	t3.Text = "DELGADO\n& ROSS\nINJURY LAW"; t3.Font = Enum.Font.Merriweather; t3.TextScaled = true; t3.TextColor3 = C(16, 26, 60); t3.Parent = bg
	-- weathering: a few pale peel patches
	for i, pz in ipairs({ { 0.12, 0.8, 0.1, 0.12 }, { 0.47, 0.02, 0.08, 0.1 }, { 0.83, 0.86, 0.12, 0.1 }, { 0.3, 0.9, 0.05, 0.08 } }) do
		local f = Instance.new("Frame"); f.Position = UDim2.fromScale(pz[1], pz[2]); f.Size = UDim2.fromScale(pz[3], pz[4]); f.BackgroundColor3 = C(214, 210, 200); f.BorderSizePixel = 0; f.Rotation = i * 7; f.Parent = bg
	end
end
for _, x in ipairs({ -8, 0, 8 }) do
	P(bb, "LampArm", Vector3.new(0.2, 0.2, 2.5), O * CFrame.new(x, BBY0 - 0.4, bz - 2.2), STEEL, M.Metal)
	local lh = P(bb, "LampHead", Vector3.new(1.2, 0.5, 0.8), O * CFrame.new(x, BBY0 - 0.3, bz - 3.4) * CFrame.Angles(math.rad(60), 0, 0), C(60, 60, 60), M.Metal)
	local s = Instance.new("SpotLight"); s.Face = Enum.NormalId.Top; s.Angle = 80; s.Range = 14; s.Brightness = 3; s.Color = C(255, 240, 220); s.Parent = lh
end

-- 9. street props: dumpster, trash, utility pole with transformer and service drop, sidewalk trees
local props = grp("Props")
local function dumpster(cf)
	local g = grp("Dumpster", props)
	P(g, "Bin", Vector3.new(6, 4, 3.6), cf * CFrame.new(0, 2.2, 0), C(40, 90, 50), M.CorrodedMetal, "DumpsterGreenRust")
	P(g, "Lid", Vector3.new(6.1, 0.2, 3.8), cf * CFrame.new(0, 4.35, -0.1) * CFrame.Angles(math.rad(-6), 0, 0), C(30, 30, 30), M.Plastic)
	P(g, "Rim", Vector3.new(6.2, 0.4, 0.3), cf * CFrame.new(0, 3.9, 1.85), C(30, 70, 40), M.Metal)
	for _, x in ipairs({ -2.4, 2.4 }) do for _, z in ipairs({ -1.4, 1.4 }) do
		P(g, "Wheel", Vector3.new(0.4, 0.5, 0.5), cf * CFrame.new(x, 0.25, z), C(20, 20, 20), M.Rubber, nil, { shape = Enum.PartType.Cylinder })
	end end
	local lbl = noCol(P(g, "Label", Vector3.new(3.4, 0.8, 0.05), cf * CFrame.new(0, 2.6, -1.83), C(0, 0, 0), M.SmoothPlastic, nil, { Transparency = 1 }))
	label(lbl, Enum.NormalId.Front, "DRY GARBAGE", C(240, 240, 230), nil, Enum.Font.GothamBold)
end
dumpster(O * CFrame.new(-18, 0, D2 + 4) * CFrame.Angles(0, math.pi, 0))
for i, p in ipairs({ { -12.5, 22.5 }, { -13.6, 23.6 }, { -21.6, 22.4 }, { -32, -9 }, { -31.4, -10.5 } }) do
	local bag = P(props, "TrashBag", Vector3.new(1.6, 1.4, 1.6), O * CFrame.new(p[1], 0.7, p[2]) * CFrame.Angles(0, i, 0), C(18, 18, 20), M.Plastic, nil, { shape = Enum.PartType.Ball })
	bag.Size = Vector3.new(1.7, 1.7, 1.7)
end
-- utility pole at the front corner + transformer + sagging service drop to the weatherhead
local pole = grp("UtilityPole", props)
local PP = O * CFrame.new(-33, 0, -26)
P(pole, "Pole", Vector3.new(0.9, 38, 0.9), PP * CFrame.new(0, 19, 0), C(84, 62, 46), M.Wood, "PalmBark")
P(pole, "Crossarm", Vector3.new(0.4, 0.4, 9), PP * CFrame.new(0, 35.5, 0), C(90, 70, 50), M.Wood, "WoodPlanksOld")
P(pole, "Crossarm", Vector3.new(0.4, 0.4, 7), PP * CFrame.new(0, 33.5, 0), C(90, 70, 50), M.Wood, "WoodPlanksOld")
for _, z in ipairs({ -4, -1.5, 1.5, 4 }) do P(pole, "Insulator", Vector3.new(0.3, 0.5, 0.3), PP * CFrame.new(0, 36, z), C(170, 180, 175), M.Glass) end
local can = P(pole, "Transformer", Vector3.new(2.2, 3.2, 2.2), PP * CFrame.new(-1.4, 29, 0), C(120, 125, 125), M.Metal, "PaintedMetalB", { shape = Enum.PartType.Cylinder })
can.Size = Vector3.new(3.2, 2.2, 2.2); can.CFrame = PP * CFrame.new(-1.4, 29, 0) * CFrame.Angles(0, 0, math.pi / 2)
P(pole, "Bracket", Vector3.new(1.4, 0.3, 0.3), PP * CFrame.new(-0.7, 29.8, 0), STEEL, M.Metal)
local function cable(a: Vector3, b: Vector3, sag: number, segs: number)
	local prev = a
	for i = 1, segs do
		local t = i / segs
		local p = a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
		local mid = (prev + p) / 2
		noCol(P(pole, "Cable", Vector3.new(0.1, 0.1, (p - prev).Magnitude), CFrame.lookAt(mid, p), C(18, 18, 18), M.SmoothPlastic, nil, { CastShadow = false }))
		prev = p
	end
end
local wh = (Lw * CFrame.new(11.6, PT + 0.8, 0.25)).Position
local poleTop = (PP * CFrame.new(-1.4, 30.6, 0)).Position
-- line along the street (both directions off the lab) + drops
for _, z in ipairs({ -4, -1.5, 1.5, 4 }) do
	local a = (PP * CFrame.new(0, 36.2, z)).Position
	cable(a, a + Vector3.new(-60, 0, 0), 2.2, 10)
	cable(a, a + Vector3.new(95, 0, 0), 3.2, 14)
end
cable(poleTop, (R * CFrame.new(-16, UF + 1.5, 0.3)).Position, 2.4, 10)
cable((PP * CFrame.new(0, 35.7, -1.5)).Position, wh, 4, 16)
-- sidewalk palms (simple: trunk + frond wedges)
local function palm(x, z, h)
	local g = grp("Palm", props)
	local base = O * CFrame.new(x, 0, z)
	P(g, "Planter", Vector3.new(4, 0.4, 4), base * CFrame.new(0, 0.2, 0), C(90, 70, 50), M.Ground, "DryGround")
	local lean = CFrame.Angles(math.rad(4), 0, math.rad(-3))
	P(g, "Trunk", Vector3.new(1.1, h, 1.1), base * lean * CFrame.new(0, h / 2, 0), C(120, 100, 80), M.Wood, "PalmBark")
	local top = base * lean * CFrame.new(0, h, 0)
	for i = 0, 8 do
		local a = i / 9 * math.pi * 2
		W(g, "Frond", Vector3.new(0.2, 1.2, 7), top * CFrame.Angles(0, a, 0) * CFrame.new(0, -0.4, 3.4) * CFrame.Angles(math.rad(-20), 0, 0), C(70, 110, 50), M.Grass, nil, { CanCollide = false })
	end
	P(g, "Crown", Vector3.new(1.8, 1.8, 1.8), top, C(110, 90, 60), M.Wood, nil, { shape = Enum.PartType.Ball, CanCollide = false })
end
palm(-14, -27, 26)
palm(18, -27, 30)

---------------------------------------------------------------------------------------------------------------
-- 10. lab street (sidewalk, curb, asphalt, paint) so the building can be judged in context
P(pad, "Sidewalk", Vector3.new(140, 4, 70), O * CFrame.new(-5, -2, 5), C(176, 172, 164), M.Concrete, "SidewalkWornStained")
P(pad, "Curb", Vector3.new(140, 4.4, 1), O * CFrame.new(-5, -2.2, -30.5), C(190, 186, 178), M.Concrete, "ConcretePlain")
P(pad, "CurbRed", Vector3.new(14, 0.05, 1.02), O * CFrame.new(-60, 0.01, -30.5), C(170, 40, 35), M.SmoothPlastic)
P(pad, "Road", Vector3.new(140, 4, 44), O * CFrame.new(-5, -2.4, -53), C(62, 62, 64), M.Asphalt, "AsphaltWorn")
P(pad, "SideStreet", Vector3.new(36, 4, 70), O * CFrame.new(-93, -2.4, 5), C(62, 62, 64), M.Asphalt, "AsphaltWorn")
for i = -6, 6 do
	P(pad, "CenterLine", Vector3.new(6, 0.05, 0.3), O * CFrame.new(i * 10, -0.38, -52.7), C(230, 190, 40), M.SmoothPlastic)
	P(pad, "CenterLine", Vector3.new(6, 0.05, 0.3), O * CFrame.new(i * 10, -0.38, -53.3), C(230, 190, 40), M.SmoothPlastic)
end
for i = 0, 7 do P(pad, "Crosswalk", Vector3.new(6, 0.05, 2.2), O * CFrame.new(-68, -0.38, -34 - i * 5), C(235, 235, 230), M.SmoothPlastic) end
for i = 0, 6 do P(pad, "Zebra", Vector3.new(2.2, 0.05, 6), O * CFrame.new(-108 + i * 5, -0.38, -25), C(235, 235, 230), M.SmoothPlastic) end
-- patch repairs with pale rims (the Larp signature)
for i, pz in ipairs({ { -20, -44, 8, 5 }, { 25, -60, 10, 6 }, { -45, -58, 6, 4 } }) do
	P(pad, "PatchRim", Vector3.new(pz[3] + 0.6, 0.04, pz[4] + 0.6), O * CFrame.new(pz[1], -0.39, pz[2]), C(150, 146, 138), M.Concrete, "ConcreteStained")
	P(pad, "Patch", Vector3.new(pz[3], 0.05, pz[4]), O * CFrame.new(pz[1], -0.37, pz[2]), C(34, 34, 36), M.Asphalt, "AsphaltTarPatch")
end

lab.Parent = workspace
return "built parts=" .. count
