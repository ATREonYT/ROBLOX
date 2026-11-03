-- Act 2 story sets (Story Bible 2.3 + 2.7). ModuleScript: require(...).build() -> report string.
--   * Royce's CASH 4 GOLD (Hood, the lot by the canal at ~(-1106, -343)): pawn shop floor with a teller
--     partition, display cases and pegboards; a back room with the crate drop-off by the alley door (canal side);
--     a stair up to Royce's office (desk + red book, wall map of Liberty with red circles, safe, couch, blinds).
--     The V2 shop that stood on the lot goes to ServerStorage.MTL_ReplacedBuildings.Hood.
--   * The Ends rooftop (the Apartments at ~(-1433, -59), which faces east to the downtown skyline): parapet,
--     roof door hut, water tank, string lights, plastic chairs, a cooler, a steel fire escape up the back wall.
-- Every cutscene anchor is an invisible, non-colliding part in <Set>.Anchors (CFrame = where to stand, facing).
local SS = game:GetService("ServerStorage")
local hood = workspace.ViceBay.Buildings.Hood
local C = Color3.fromRGB
local M = Enum.Material
local STEEL = C(38, 38, 40)
local ALU = C(150, 153, 157)
local TRIM = C(188, 184, 176)

local Sets = {}

local function maker(parent)
	local n = 0
	local function P(name, size, cf, color, mat, opts)
		local p = Instance.new("Part")
		p.Name = name; p.Anchored = true; p.Size = size; p.CFrame = cf; p.Color = color; p.Material = mat or M.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
		if opts then for k, v in pairs(opts) do if k == "shape" then p.Shape = v elseif k == "parent" then p.Parent = v else p[k] = v end end end
		if not p.Parent then p.Parent = parent end
		n += 1
		return p
	end
	local function W(name, size, cf, color, mat)
		local w = Instance.new("WedgePart")
		w.Name = name; w.Anchored = true; w.Size = size; w.CFrame = cf; w.Color = color; w.Material = mat; w.Parent = parent
		n += 1
		return w
	end
	local function count() return n end
	return P, W, count
end

local function noCol(p) p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false; return p end

local function gui(part, face, pps, build)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = pps; sg.LightInfluence = 1
	sg.Parent = part
	build(sg)
	return sg
end
local function text(parent, t, color, font, pos, size, opts)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1; l.Text = t; l.TextColor3 = color; l.Font = font; l.TextScaled = true
	l.Position = pos or UDim2.fromScale(0, 0); l.Size = size or UDim2.fromScale(1, 1)
	if opts then for k, v in pairs(opts) do l[k] = v end end
	l.Parent = parent
	return l
end

-- wall with rectangular holes (u across, v up, wall-local frame: +Z = outward, face at z = 0)
local function wall(P, frame, u0, u1, v0, v1, holes, color, mat, variant, thick)
	thick = thick or 1
	local lo, hi = v1, v0
	for _, h in holes do lo = math.min(lo, h[3]); hi = math.max(hi, h[4]) end
	if #holes == 0 then lo, hi = v1, v1 end
	local function piece(a, b, c, d)
		if b - a > 0.01 and d - c > 0.01 then
			local p = P("Wall", Vector3.new(b - a, d - c, thick), frame * CFrame.new((a + b) / 2, (c + d) / 2, -thick / 2), color, mat)
			if variant then p.MaterialVariant = variant end
		end
	end
	piece(u0, u1, v0, lo); piece(u0, u1, hi, v1)
	if #holes == 0 then return end
	local xs = { u0, u1 }
	for _, h in holes do table.insert(xs, h[1]); table.insert(xs, h[2]) end
	table.sort(xs)
	for i = 1, #xs - 1 do
		local a, b = xs[i], xs[i + 1]
		if b - a > 0.01 then
			local spans = {}
			for _, h in holes do if h[1] <= a + 0.001 and h[2] >= b - 0.001 then table.insert(spans, { h[3], h[4] }) end end
			table.sort(spans, function(p, q) return p[1] < q[1] end)
			local cur = lo
			for _, s in spans do piece(a, b, cur, s[1]); cur = s[2] end
			piece(a, b, cur, hi)
		end
	end
end

local function anchor(folder, name, cf)
	local a = Instance.new("Part")
	a.Name = name; a.Anchored = true; a.CanCollide = false; a.CanQuery = false; a.CanTouch = false; a.CastShadow = false
	a.Transparency = 1; a.Size = Vector3.new(1, 1, 1); a.CFrame = cf; a.Parent = folder
	return a
end

---------------------------------------------------------------------------------------------------------------
-- CASH 4 GOLD
local function buildCash4Gold(): string
	local lot
	for _, m in hood:GetChildren() do
		if m.Name == "Shops" or m.Name == "RoyceCash4Gold" then
			local cf = m:GetBoundingBox()
			if math.abs(cf.X + 1111) < 8 and math.abs(cf.Z + 343) < 8 then lot = m end
		end
	end
	if not lot then return "Cash 4 Gold: lot not found" end
	local fp = lot:FindFirstChild("Footprint") :: BasePart
	local fpCF, fpSize = fp.CFrame, fp.Size
	if lot.Name == "RoyceCash4Gold" then
		lot:Destroy()
	else
		local keep = SS.MTL_ReplacedBuildings:FindFirstChild("Hood")
		lot:SetAttribute("MTL_OriginalParent", hood:GetFullName())
		lot.Parent = keep
	end
	local model = Instance.new("Model")
	model.Name = "RoyceCash4Gold"
	model:SetAttribute("MTL_StorySet", "Cash4Gold")
	fp:Clone().Parent = model
	local P, Wd, count = maker(model)
	local G = 2.0 -- lot ground
	-- building frame: centre of the building at ground; local -Z = street (front), local -X = alley / canal side
	local Bw, Bd = 50, 40
	local B = CFrame.new(fpCF.Position.X, G, fpCF.Position.Z) * fpCF.Rotation * CFrame.new(3, 0, -fpSize.Z / 2 + 2.5 + Bd / 2)
	local function at(x, y, z) return B * CFrame.new(x, y, z) end
	local hx, hz = Bw / 2, Bd / 2
	local GF, UF, PT = 13, 25, 28 -- ground floor ceiling / roof / parapet top
	local WALL = C(206, 190, 160) -- sun-faded cream stucco
	local STUC = "HoodStuccoCracked"
	-- outward-facing wall frames (u along the wall, +Z out)
	local F = B * CFrame.new(0, 0, -hz) * CFrame.Angles(0, math.pi, 0)
	local Bk = B * CFrame.new(0, 0, hz)
	local Wst = B * CFrame.new(-hx, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0)
	local Est = B * CFrame.new(hx, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
	-- front: u = +x mirrored (F faces -Z): u = -x
	-- door at x 6..11, windows x -22..2 and x 14..22 (u = -x)
	wall(P, F, -hx, hx, 0, GF, { { -11, -6, 0, 9 }, { -2, 22, 2.6, 10 }, { -22, -14, 2.6, 10 } }, C(120, 64, 52), M.Brick, "HoodPaintedBrick")
	wall(P, F, -hx, hx, GF, PT, { { 10, 18, 15.5, 21.5 }, { -2, 6, 15.5, 21.5 }, { -18, -10, 15.5, 21.5 } }, WALL, M.Plaster, STUC)
	-- back
	wall(P, Bk, -hx, hx, 0, GF, { { -20, -16, 5, 9 } }, C(186, 180, 166), M.Concrete, "HoodCinderBlock")
	wall(P, Bk, -hx, hx, GF, PT, { { -6, 6, 16, 21.5 } }, WALL, M.Plaster, STUC)
	-- west (alley): back door at z 8..12 (u = z for Wst? Wst faces -X; u axis = local X of frame = world... use u = -z)
	wall(P, Wst, -(hz - 1), hz - 1, 0, GF, { { 8, 12, 0, 8.6 } }, C(186, 180, 166), M.Concrete, "HoodCinderBlock")
	wall(P, Wst, -(hz - 1), hz - 1, GF, PT, { { -4, 4, 16, 21.5 } }, WALL, M.Plaster, STUC)
	-- east: blank lower, one window upstairs
	wall(P, Est, -(hz - 1), hz - 1, 0, GF, {}, C(186, 180, 166), M.Concrete, "HoodCinderBlock")
	wall(P, Est, -(hz - 1), hz - 1, GF, PT, { { -12, -6, 16, 21.5 } }, WALL, M.Plaster, STUC)
	-- floors and roof (stairwell opening in the upper floor at x 14..22, z 4..19)
	P("GroundFloor", Vector3.new(Bw - 2, 0.6, Bd - 2), at(0, 0.3, 0), C(196, 192, 182), M.CeramicTiles)
	local slabY = GF + 0.4
	P("UpperFloor", Vector3.new(36 - 0.5, 0.8, Bd - 2), at(-hx + 1 + 17.75, slabY, 0), C(120, 84, 58), M.WoodPlanks)
	P("UpperFloor", Vector3.new(hx - 1 - 22, 0.8, Bd - 2), at(22 + (hx - 1 - 22) / 2, slabY, 0), C(120, 84, 58), M.WoodPlanks)
	P("UpperFloor", Vector3.new(8, 0.8, 4 + hz - 1), at(18, slabY, (-hz + 1 + 4) / 2), C(120, 84, 58), M.WoodPlanks)
	P("UpperFloor", Vector3.new(8, 0.8, hz - 1 - 19), at(18, slabY, 19 + (hz - 1 - 19) / 2), C(120, 84, 58), M.WoodPlanks)
	P("Ceiling", Vector3.new(Bw - 2, 0.3, Bd - 2), at(0, GF - 0.15, 0), C(236, 234, 228), M.SmoothPlastic, { CanCollide = false })
	-- (ceiling has the same stair hole)
	P("Roof", Vector3.new(Bw - 2, 0.8, Bd - 2), at(0, UF, 0), C(90, 88, 86), M.Asphalt)
	P("UpperCeiling", Vector3.new(Bw - 2, 0.3, Bd - 2), at(0, UF - 0.55, 0), C(232, 226, 214), M.SmoothPlastic)
	-- trims: plinth, string course, cornice, coping
	for _, t in { { "Plinth", 0.5, 1, 0.25, C(62, 60, 58) }, { "StringCourse", GF + 0.4, 0.7, 0.35, TRIM }, { "Cornice", UF + 0.6, 0.8, 0.4, TRIM }, { "Coping", PT + 0.2, 0.4, 0.4, C(120, 64, 52) } } do
		local name, v, h, out, col = t[1], t[2], t[3], t[4], t[5]
		P(name, Vector3.new(Bw + out * 2, h, out), at(0, v, -hz - out / 2), col, M.Concrete)
		P(name, Vector3.new(Bw + out * 2, h, out), at(0, v, hz + out / 2), col, M.Concrete)
		P(name, Vector3.new(out, h, Bd), at(-hx - out / 2, v, 0), col, M.Concrete)
		P(name, Vector3.new(out, h, Bd), at(hx + out / 2, v, 0), col, M.Concrete)
	end

	-- shop front glazing + bars + door
	local function glass(x0, x1, v0, v1, z)
		P("ShopGlass", Vector3.new(x1 - x0, v1 - v0, 0.15), at((x0 + x1) / 2, (v0 + v1) / 2, z), C(70, 90, 96), M.Glass, { Transparency = 0.6, Reflectance = 0.1 })
		P("ShopFrame", Vector3.new(x1 - x0, 0.3, 0.35), at((x0 + x1) / 2, v0 + 0.15, z), ALU, M.Metal)
		P("ShopFrame", Vector3.new(x1 - x0, 0.3, 0.35), at((x0 + x1) / 2, v1 - 0.15, z), ALU, M.Metal)
		local nb = math.floor((x1 - x0) / 0.7)
		for i = 0, nb do noCol(P("Bar", Vector3.new(0.12, v1 - v0, 0.12), at(x0 + (x1 - x0) * i / nb, (v0 + v1) / 2, -hz - 0.35), STEEL, M.Metal)) end
		for _, v in { v0 + 0.2, (v0 + v1) / 2, v1 - 0.2 } do P("BarRail", Vector3.new(x1 - x0 + 0.3, 0.18, 0.18), at((x0 + x1) / 2, v, -hz - 0.35), STEEL, M.Metal) end
		P("Sill", Vector3.new(x1 - x0 + 0.6, 0.4, 1), at((x0 + x1) / 2, v0 - 0.2, -hz - 0.3), TRIM, M.Concrete)
	end
	glass(-22, 2, 2.6, 10, -hz + 0.6)
	glass(14, 22, 2.6, 10, -hz + 0.6)
	-- steel security door (held open) + frame
	P("DoorFrame", Vector3.new(0.35, 9, 0.6), at(6, 4.5, -hz + 0.3), STEEL, M.Metal)
	P("DoorFrame", Vector3.new(0.35, 9, 0.6), at(11, 4.5, -hz + 0.3), STEEL, M.Metal)
	P("DoorHead", Vector3.new(5.4, 0.4, 0.6), at(8.5, 9.2, -hz + 0.3), STEEL, M.Metal)
	P("FrontDoor", Vector3.new(4.6, 8.8, 0.2), at(11 - 0.2, 4.4, -hz - 2.2) * CFrame.Angles(0, math.rad(-80), 0) * CFrame.new(-2.3, 0, 0), C(60, 64, 70), M.Metal, { CanCollide = false })
	P("Step", Vector3.new(6, 0.3, 1.4), at(8.5, 0.15, -hz - 0.8), C(150, 148, 142), M.Concrete)
	-- big yellow sign + lightbox + bulbs
	local sign = P("Sign", Vector3.new(36, 3.6, 0.6), at(-4, GF - 1.1, -hz - 0.5), C(250, 196, 30), M.SmoothPlastic)
	gui(sign, Enum.NormalId.Front, 30, function(sg)
		local bg = Instance.new("Frame"); bg.Size = UDim2.fromScale(1, 1); bg.BackgroundColor3 = C(250, 196, 30); bg.BorderSizePixel = 0; bg.Parent = sg
		text(bg, "CASH 4 GOLD", C(160, 20, 20), Enum.Font.GothamBlack, UDim2.fromScale(0.02, 0.05), UDim2.fromScale(0.62, 0.9), { TextStrokeTransparency = 0.6 })
		text(bg, "WE BUY · PAWN · LOANS", C(30, 30, 30), Enum.Font.GothamBold, UDim2.fromScale(0.64, 0.15), UDim2.fromScale(0.34, 0.35))
		text(bg, "ROYCE PROPERTIES CO.", C(90, 60, 20), Enum.Font.GothamBold, UDim2.fromScale(0.64, 0.55), UDim2.fromScale(0.34, 0.3))
	end)
	local l = Instance.new("SurfaceLight"); l.Face = Enum.NormalId.Front; l.Brightness = 1.2; l.Range = 12; l.Angle = 120; l.Color = C(255, 220, 140); l.Parent = sign
	P("SignTrim", Vector3.new(36.4, 0.3, 0.8), at(-4, GF + 0.8, -hz - 0.5), C(160, 20, 20), M.Metal)
	P("SignTrim", Vector3.new(36.4, 0.3, 0.8), at(-4, GF - 3, -hz - 0.5), C(160, 20, 20), M.Metal)
	-- window stickers (the reference shops are covered in them)
	for i, s in { { -18, 8.3, "GOLD\n$$$", C(250, 196, 30), C(20, 20, 20) }, { -12, 8.3, "CHECKS\nCASHED", C(30, 120, 60), C(255, 255, 255) }, { -6, 8.3, "PAWN\nLOANS", C(160, 20, 20), C(255, 255, 255) }, { 18, 8.3, "OPEN\n7 DAYS", C(20, 60, 160), C(255, 255, 255) }, { -2, 4.2, "NO\nHOODS", C(240, 240, 236), C(160, 20, 20) } } do
		local st = noCol(P("Sticker", Vector3.new(3.2, 2.2, 0.05), at(s[1], s[2], -hz + 0.45), s[4], M.SmoothPlastic))
		gui(st, Enum.NormalId.Front, 40, function(sg) text(sg, s[3], s[5], Enum.Font.GothamBlack, nil, nil, { BackgroundColor3 = s[4], BackgroundTransparency = 0 }) end)
	end

	-- SHOP FLOOR -------------------------------------------------------------------------------------------
	local shop = Instance.new("Model"); shop.Name = "ShopFloor"; shop.Parent = model
	local PS = select(1, maker(shop))
	-- counter run with glass display cases (gold inside) and a bulletproof partition with a teller slot
	local cz = -6
	PS("Counter", Vector3.new(36, 3.6, 2.4), at(-6, 1.8 + 0.6, cz), C(70, 52, 40), M.WoodPlanks)
	PS("CounterTop", Vector3.new(36.4, 0.25, 2.8), at(-6, 4.35, cz), C(40, 40, 44), M.Granite)
	for i = 0, 3 do
		local x = -20 + i * 8
		PS("CaseGlass", Vector3.new(7, 2.4, 2.2), at(x, 5.7, cz - 0.1), C(210, 230, 240), M.Glass, { Transparency = 0.75 })
		PS("CaseBase", Vector3.new(7, 0.2, 2.2), at(x, 4.55, cz - 0.1), C(30, 20, 50), M.Fabric)
		for k = 0, 5 do
			local g = noCol(PS("Gold", Vector3.new(0.8, 0.12, 0.5), at(x - 2.8 + k * 1.1, 4.75, cz - 0.4 + (k % 2) * 0.6), C(240, 190, 60), M.Neon, { Transparency = 0.1 }))
		end
		local cl = noCol(PS("CaseLight", Vector3.new(6.6, 0.1, 0.3), at(x, 6.85, cz - 0.1), C(255, 250, 230), M.Neon))
		local pl = Instance.new("PointLight"); pl.Range = 5; pl.Brightness = 0.8; pl.Color = C(255, 240, 210); pl.Parent = cl
	end
	-- partition: posts + thick glass up to the ceiling, a slot at the till
	for i = 0, 4 do PS("PartitionPost", Vector3.new(0.4, GF - 4.5, 0.4), at(-24 + i * 9, 4.5 + (GF - 4.5) / 2, cz + 1.3), ALU, M.Metal) end
	PS("PartitionGlass", Vector3.new(36, GF - 7.2, 0.3), at(-6, 7.1 + (GF - 7.2) / 2, cz + 1.3), C(200, 220, 230), M.Glass, { Transparency = 0.7 })
	PS("TellerTray", Vector3.new(2, 0.2, 1.4), at(4, 4.6, cz + 1.3), ALU, M.Metal)
	PS("Register", Vector3.new(1.4, 1, 1.1), at(4, 5.0, cz + 2.4), C(30, 30, 32), M.SmoothPlastic)
	-- back wall pegboard with guitars, TVs, power tools, chains
	local pegZ = 5
	PS("BackPartition", Vector3.new(36, GF - 0.6, 0.5), at(-7, (GF - 0.6) / 2 + 0.6, pegZ), C(200, 196, 186), M.SmoothPlastic)
	PS("Pegboard", Vector3.new(30, 6, 0.1), at(-10, 7, pegZ - 0.3), C(170, 140, 100), M.WoodPlanks)
	for i = 0, 4 do
		local x = -22 + i * 3.2
		local body = PS("Guitar", Vector3.new(1.6, 2.4, 0.3), at(x, 6, pegZ - 0.5), Color3.fromHSV((i * 0.17) % 1, 0.6, 0.6), M.SmoothPlastic)
		PS("GuitarNeck", Vector3.new(0.3, 2.6, 0.2), at(x, 8.4, pegZ - 0.5), C(70, 50, 30), M.Wood)
	end
	for i = 0, 2 do
		local tv = PS("TV", Vector3.new(3.6, 2.2, 0.4), at(-4 + i * 4.2, 8.6, pegZ - 0.6), C(20, 20, 22), M.SmoothPlastic)
		local scr = noCol(PS("TVScreen", Vector3.new(3.3, 1.9, 0.05), at(-4 + i * 4.2, 8.6, pegZ - 0.82), C(40, 60, 90), M.Neon, { Transparency = 0.2 }))
	end
	for i = 0, 6 do noCol(PS("Chain", Vector3.new(0.12, 1.8, 0.12), at(-4 + i * 0.5, 5.4, pegZ - 0.45), C(240, 190, 60), M.Neon)) end
	local tag = noCol(PS("NoRefunds", Vector3.new(5, 1.2, 0.05), at(-14, 10.6, pegZ - 0.35), C(255, 255, 255), M.SmoothPlastic))
	gui(tag, Enum.NormalId.Front, 40, function(sg) text(sg, "ALL SALES FINAL · NO REFUNDS", C(160, 20, 20), Enum.Font.GothamBlack, nil, nil, { BackgroundColor3 = C(255, 255, 255), BackgroundTransparency = 0 }) end)
	-- door through the partition to the back room (x 13..17) + customer side: ATM, chairs, camera
	PS("PartitionSide", Vector3.new(hx - 1 - 17, GF - 0.6, 0.5), at(17 + (hx - 1 - 17) / 2, (GF - 0.6) / 2 + 0.6, pegZ), C(200, 196, 186), M.SmoothPlastic)
	PS("BackDoorFrame", Vector3.new(4.4, 0.4, 0.6), at(13 + 2, 9, pegZ), STEEL, M.Metal)
	PS("PartitionTop", Vector3.new(4, GF - 9.2, 0.5), at(15, 9.2 + (GF - 9.2) / 2, pegZ), C(200, 196, 186), M.SmoothPlastic)
	local sign2 = noCol(PS("EmployeesOnly", Vector3.new(3, 0.8, 0.05), at(15, 8.2, pegZ - 0.32), C(160, 20, 20), M.SmoothPlastic))
	gui(sign2, Enum.NormalId.Front, 40, function(sg) text(sg, "EMPLOYEES ONLY", C(255, 255, 255), Enum.Font.GothamBold) end)
	PS("ATM", Vector3.new(2.6, 6, 2), at(20, 3.6, -hz + 3), C(60, 64, 72), M.Metal)
	local atmScr = noCol(PS("ATMScreen", Vector3.new(1.6, 1.2, 0.05), at(20, 5.4, -hz + 1.98), C(40, 120, 200), M.Neon))
	for i = 0, 2 do
		PS("WaitChair", Vector3.new(2, 0.4, 2), at(-22 + i * 2.6, 2.3, -hz + 3.4), C(140, 30, 30), M.Plastic)
		PS("WaitChairBack", Vector3.new(2, 2, 0.3), at(-22 + i * 2.6, 3.4, -hz + 2.4), C(140, 30, 30), M.Plastic)
	end
	PS("Camera", Vector3.new(0.6, 0.6, 1.2), at(18, GF - 1.2, -hz + 2) * CFrame.Angles(math.rad(-25), math.rad(200), 0), C(230, 230, 230), M.SmoothPlastic)
	for i = -1, 1 do
		local tube = PS("Fluoro", Vector3.new(6, 0.25, 0.8), at(-6 + i * 12, GF - 0.45, -10), C(245, 250, 255), M.Neon)
		local sl = Instance.new("SurfaceLight"); sl.Face = Enum.NormalId.Bottom; sl.Brightness = 1.2; sl.Range = 16; sl.Angle = 120; sl.Color = C(235, 245, 255); sl.Parent = tube
	end

	-- BACK ROOM: crates from the van, the alley door (west), the stair up (east)
	local back = Instance.new("Model"); back.Name = "BackRoom"; back.Parent = model
	local PB = select(1, maker(back))
	PB("AlleyDoor", Vector3.new(0.2, 8.4, 4), at(-hx + 0.3, 4.2 + 0.3, 10), C(90, 50, 40), M.Metal)
	PB("AlleyDoorBar", Vector3.new(0.15, 0.3, 3.2), at(-hx + 0.55, 4.3, 10), ALU, M.Metal)
	PB("AlleyStep", Vector3.new(1.6, 0.3, 5), at(-hx - 0.8, 0.15, 10), C(150, 148, 142), M.Concrete)
	local bulb = PB("AlleyLamp", Vector3.new(0.8, 0.8, 0.5), at(-hx - 0.3, 9.6, 10), C(255, 220, 160), M.Neon)
	local al = Instance.new("PointLight"); al.Range = 12; al.Brightness = 1.4; al.Color = C(255, 200, 140); al.Parent = bulb
	for i = 0, 6 do
		local row, col = i // 3, i % 3
		PB("Crate", Vector3.new(2.6, 2, 2.6), at(-hx + 4 + col * 2.8, 1.6 + row * 2.05, 16 + (row % 2) * 0.3), C(150, 116, 80), M.WoodPlanks)
	end
	for i = 0, 3 do PB("Box", Vector3.new(2.2, 1.6, 1.6), at(-12 + i * 2.4, 1.4, 18.5), C(170, 140, 100), M.Cardboard) end
	PB("Shelving", Vector3.new(8, 7, 2), at(0, 4.1, 19.5), C(80, 82, 88), M.Metal)
	local bulb2 = PB("BackBulb", Vector3.new(0.6, 0.6, 0.6), at(-4, GF - 1, 12), C(255, 230, 180), M.Neon, { shape = Enum.PartType.Ball })
	local bl = Instance.new("PointLight"); bl.Range = 16; bl.Brightness = 1.3; bl.Color = C(255, 214, 160); bl.Parent = bulb2
	-- stair: x 14..22, rising from z 5 (bottom) to z 19 (top), landing at the top
	local steps = 14
	local rise = (slabY + 0.4 - 0.6) / steps
	for i = 1, steps do
		PB("Stair", Vector3.new(7.6, rise, 1.0 + 0.05), at(18, 0.6 + rise * (i - 0.5), 5 + (i - 0.5) * 1.0), C(110, 84, 60), M.WoodPlanks)
		PB("StairFill", Vector3.new(7.6, rise * (i - 1) + 0.01, 1.0), at(18, 0.6 + rise * (i - 1) / 2, 5 + (i - 0.5) * 1.0), C(90, 70, 52), M.Wood)
	end
	PB("StairWall", Vector3.new(0.4, slabY, 14), at(13.8, slabY / 2, 12), C(200, 196, 186), M.SmoothPlastic)
	PB("Handrail", Vector3.new(0.2, 0.2, 15), at(14.2, 0.6 + 3.5 + slabY / 2, 12) * CFrame.Angles(math.atan2(slabY, 14), 0, 0), C(60, 40, 30), M.Wood)

	-- ROYCE'S OFFICE (upstairs) -----------------------------------------------------------------------------
	local off = Instance.new("Model"); off.Name = "RoyceOffice"; off.Parent = model
	local PO = select(1, maker(off))
	local OY = slabY + 0.4 -- office floor top
	-- stairwell rail
	PO("Railing", Vector3.new(0.2, 3, 15), at(13.9, OY + 1.5, 11.5), C(60, 40, 30), M.Wood)
	PO("Railing", Vector3.new(8, 3, 0.2), at(18, OY + 1.5, 4.1), C(60, 40, 30), M.Wood)
	PO("Rug", Vector3.new(14, 0.05, 10), at(-8, OY + 0.03, 2), C(120, 30, 34), M.Fabric)
	PO("RugBorder", Vector3.new(14.6, 0.04, 10.6), at(-8, OY + 0.02, 2), C(200, 160, 80), M.Fabric)
	-- desk (Royce sits at +z behind it, facing the door / street side)
	local dz = 7
	PO("Desk", Vector3.new(9, 3, 3.6), at(-8, OY + 1.5, dz), C(70, 40, 26), M.Wood)
	PO("DeskTop", Vector3.new(9.4, 0.25, 4), at(-8, OY + 3.12, dz), C(50, 28, 18), M.Wood)
	PO("DeskPad", Vector3.new(4, 0.05, 2.2), at(-8, OY + 3.26, dz), C(30, 60, 40), M.Leather)
	local book = PO("RedBook", Vector3.new(1.3, 0.35, 1.8), at(-6.2, OY + 3.43, dz - 0.4) * CFrame.Angles(0, math.rad(12), 0), C(150, 20, 24), M.Leather)
	book:SetAttribute("MTL_StoryProp", "RoyceLedger")
	PO("Phone", Vector3.new(1, 0.3, 0.6), at(-11.2, OY + 3.4, dz - 0.6), C(20, 20, 20), M.SmoothPlastic)
	PO("Ashtray", Vector3.new(0.12, 0.8, 0.8), at(-10.2, OY + 3.3, dz + 0.9) * CFrame.Angles(0, 0, math.pi / 2), C(160, 140, 90), M.Glass, { shape = Enum.PartType.Cylinder })
	local lampShade = PO("DeskLampShade", Vector3.new(1, 0.8, 1), at(-4.4, OY + 4.6, dz + 1), C(30, 80, 50), M.Glass)
	PO("DeskLampStem", Vector3.new(0.15, 1.3, 0.15), at(-4.4, OY + 3.9, dz + 1), C(200, 170, 80), M.Metal)
	local dl = Instance.new("PointLight"); dl.Range = 10; dl.Brightness = 1.8; dl.Color = C(255, 210, 150); dl.Shadows = true; dl.Parent = lampShade
	-- leather chair behind the desk, two cheaper chairs in front
	PO("ChairSeat", Vector3.new(2.8, 0.6, 2.6), at(-8, OY + 2.0, dz + 3.2), C(40, 24, 18), M.Leather)
	PO("ChairBack", Vector3.new(2.8, 3.6, 0.6), at(-8, OY + 3.9, dz + 4.4), C(40, 24, 18), M.Leather)
	PO("ChairBase", Vector3.new(0.4, 1.6, 0.4), at(-8, OY + 0.9, dz + 3.2), STEEL, M.Metal)
	for _, x in { -11, -5 } do
		PO("GuestSeat", Vector3.new(2.2, 0.4, 2.2), at(x, OY + 1.7, dz - 4), C(110, 100, 90), M.Fabric)
		PO("GuestBack", Vector3.new(2.2, 2.2, 0.3), at(x, OY + 2.9, dz - 5), C(110, 100, 90), M.Fabric)
		for _, o in { { -0.9, -0.9 }, { 0.9, -0.9 }, { -0.9, 0.9 }, { 0.9, 0.9 } } do PO("GuestLeg", Vector3.new(0.15, 1.6, 0.15), at(x + o[1], OY + 0.8, dz - 4 + o[2]), STEEL, M.Metal) end
	end
	-- the wall map of Liberty with red circles (west wall, inside)
	local mapZ = -2
	local map = PO("WallMap", Vector3.new(0.1, 6, 10), at(-hx + 1.15, OY + 6, mapZ), C(230, 222, 200), M.SmoothPlastic)
	PO("WallMapFrame", Vector3.new(0.15, 6.4, 10.4), at(-hx + 1.08, OY + 6, mapZ), C(60, 40, 26), M.Wood)
	gui(map, Enum.NormalId.Right, 30, function(sg)
		local bg = Instance.new("Frame"); bg.Size = UDim2.fromScale(1, 1); bg.BackgroundColor3 = C(232, 224, 200); bg.BorderSizePixel = 0; bg.Parent = sg
		-- street grid
		for i = 1, 4 do
			local v = Instance.new("Frame"); v.BorderSizePixel = 0; v.BackgroundColor3 = C(150, 140, 120); v.Position = UDim2.fromScale(i / 5, 0); v.Size = UDim2.new(0, 6, 1, 0); v.Parent = bg
			local h = Instance.new("Frame"); h.BorderSizePixel = 0; h.BackgroundColor3 = C(150, 140, 120); h.Position = UDim2.fromScale(0, i / 5); h.Size = UDim2.new(1, 0, 0, 6); h.Parent = bg
		end
		local canal = Instance.new("Frame"); canal.BorderSizePixel = 0; canal.BackgroundColor3 = C(110, 150, 180); canal.Position = UDim2.fromScale(0.9, 0); canal.Size = UDim2.fromScale(0.05, 1); canal.Parent = bg
		text(bg, "LIBERTY", C(60, 50, 40), Enum.Font.Merriweather, UDim2.fromScale(0.03, 0.02), UDim2.fromScale(0.4, 0.1))
		-- red circles over lots, the Food Mart one with a "?"
		local rng = Random.new(23)
		for i = 1, 9 do
			local cx, cy = rng:NextNumber(0.08, 0.85), rng:NextNumber(0.15, 0.9)
			local ring = Instance.new("Frame"); ring.BackgroundTransparency = 1; ring.AnchorPoint = Vector2.new(0.5, 0.5); ring.Position = UDim2.fromScale(cx, cy); ring.Size = UDim2.fromOffset(34, 34); ring.Parent = bg
			local st = Instance.new("UIStroke"); st.Color = C(200, 20, 20); st.Thickness = 3; st.Parent = ring
			local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(1, 0); cr.Parent = ring
		end
		local fm = Instance.new("Frame"); fm.BackgroundTransparency = 1; fm.AnchorPoint = Vector2.new(0.5, 0.5); fm.Position = UDim2.fromScale(0.42, 0.58); fm.Size = UDim2.fromOffset(52, 52); fm.Parent = bg
		local st = Instance.new("UIStroke"); st.Color = C(200, 20, 20); st.Thickness = 4; st.Parent = fm
		local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(1, 0); cr.Parent = fm
		text(fm, "?", C(200, 20, 20), Enum.Font.PermanentMarker)
		text(bg, "FOOD MART", C(200, 20, 20), Enum.Font.PermanentMarker, UDim2.fromScale(0.34, 0.66), UDim2.fromScale(0.2, 0.06))
	end)
	-- safe, bookshelf, couch, liquor cart, framed photo, ceiling fan, blinds on the street windows, AC unit
	PO("Safe", Vector3.new(2.6, 3.4, 2.4), at(-hx + 2.6, OY + 1.7, 15), C(50, 54, 58), M.Metal)
	PO("SafeDial", Vector3.new(0.2, 0.8, 0.8), at(-hx + 3.95, OY + 2.2, 15) * CFrame.Angles(0, 0, 0), C(200, 200, 200), M.Metal, { shape = Enum.PartType.Cylinder })
	PO("Bookshelf", Vector3.new(6, 8, 1.4), at(-2, OY + 4, hz - 1.9), C(60, 36, 22), M.Wood)
	for i = 0, 2 do for k = 0, 6 do
		PO("Book", Vector3.new(0.5, 1.4, 1.0), at(-4.6 + k * 0.8, OY + 1.6 + i * 2.4, hz - 2.2), Color3.fromHSV((i * 7 + k) * 0.13 % 1, 0.45, 0.45), M.SmoothPlastic)
	end end
	PO("Couch", Vector3.new(9, 1.6, 3.2), at(4, OY + 1.2, -hz + 3), C(30, 30, 34), M.Leather)
	PO("CouchBack", Vector3.new(9, 2.4, 0.9), at(4, OY + 2.6, -hz + 1.9), C(30, 30, 34), M.Leather)
	PO("CoffeeTable", Vector3.new(5, 0.3, 2.6), at(4, OY + 1.4, -hz + 7), C(20, 20, 22), M.Glass, { Transparency = 0.3 })
	PO("LiquorCart", Vector3.new(3, 3, 1.6), at(hx - 3, OY + 1.5, -6), C(200, 170, 80), M.Metal)
	for k = 0, 3 do PO("Bottle", Vector3.new(0.4, 1.2, 0.4), at(hx - 4 + k * 0.7, OY + 3.6, -6), Color3.fromHSV(0.05 + k * 0.08, 0.6, 0.5), M.Glass, { Transparency = 0.2 }) end
	local photo = PO("FramedPhoto", Vector3.new(3, 2.2, 0.1), at(-8, OY + 7, hz - 1.15), C(240, 236, 220), M.SmoothPlastic)
	gui(photo, Enum.NormalId.Front, 40, function(sg) text(sg, "ROYCE PROPERTIES\nEST. 1998", C(60, 40, 20), Enum.Font.Merriweather, nil, nil, { BackgroundColor3 = C(240, 236, 220), BackgroundTransparency = 0 }) end)
	local fan = PO("CeilingFan", Vector3.new(0.4, 1, 1), at(-8, UF - 1.4, 0), C(80, 60, 40), M.Wood)
	for k = 0, 3 do PO("FanBlade", Vector3.new(5, 0.08, 0.8), at(-8, UF - 1.7, 0) * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(2.6, 0, 0), C(90, 66, 44), M.Wood) end
	local ceil = PO("OfficeLight", Vector3.new(2, 0.3, 2), at(4, UF - 0.9, 6), C(255, 236, 200), M.Neon)
	local ol = Instance.new("PointLight"); ol.Range = 18; ol.Brightness = 1.1; ol.Color = C(255, 220, 170); ol.Parent = ceil
	for _, x in { 14, 2, -14 } do
		for k = 0, 9 do noCol(PO("Blind", Vector3.new(7.6, 0.15, 0.05), at(x, OY + 1.6 + 6 * k / 10 + 0.2, -hz + 1.2) * CFrame.Angles(math.rad(35), 0, 0), C(236, 232, 220), M.SmoothPlastic)) end
	end
	PO("OfficeDoorFrame", Vector3.new(0.3, 8, 0.3), at(13.9, OY + 4, 4.1), C(60, 40, 30), M.Wood)

	-- exterior extras: AC units, downpipe, roof HVAC, dumpster in the alley
	for _, x in { -14, 14 } do
		P("ACBody", Vector3.new(3, 2.3, 1.3), at(x, 23.3, -hz - 0.85), C(206, 204, 196), M.Metal)
		P("ACRust", Vector3.new(0.9, 2.3, 0.05), at(x + 1.05, 23.3, -hz - 1.52), C(122, 74, 44), M.CorrodedMetal)
		P("ACFan", Vector3.new(0.08, 1.85, 1.85), at(x - 0.35, 23.3, -hz - 1.52) * CFrame.Angles(0, math.pi / 2, 0), C(42, 42, 44), M.Metal, { shape = Enum.PartType.Cylinder })
	end
	P("Downpipe", Vector3.new(0.45, PT - 1, 0.45), at(-hx - 0.3, (PT - 1) / 2, -hz + 1), C(140, 136, 130), M.Metal)
	P("RoofHVAC", Vector3.new(7, 3, 5), at(8, UF + 1.9, 8), C(196, 196, 190), M.Metal)
	P("Dumpster", Vector3.new(3.6, 4, 6), at(-hx - 3.2, 2.2, -4), C(40, 90, 50), M.CorrodedMetal)
	P("DumpsterLid", Vector3.new(3.8, 0.2, 6.1), at(-hx - 3.2, 4.35, -4), C(30, 30, 30), M.Plastic)

	-- ANCHORS ----------------------------------------------------------------------------------------------
	local A = Instance.new("Folder"); A.Name = "Anchors"; A.Parent = model
	local function look(px, py, pz, tx, ty, tz) return CFrame.lookAt((B * CFrame.new(px, py, pz)).Position, (B * CFrame.new(tx, ty, tz)).Position) end
	anchor(A, "C4G_FrontDoor", look(8.5, 3, -hz - 4, 8.5, 3, 0))
	anchor(A, "C4G_AlleyDoor", look(-hx - 3, 3, 10, 0, 3, 10))
	anchor(A, "C4G_CrateDrop", look(-hx + 7, 3, 12, -hx + 7, 3, 20))
	anchor(A, "C4G_Counter_Customer", look(4, 3, cz - 3, 4, 3, cz + 3))
	anchor(A, "C4G_Counter_Clerk", look(4, 3, cz + 3, 4, 3, cz - 3))
	anchor(A, "C4G_StairBottom", look(18, 3, 3.5, 18, 3, 12))
	anchor(A, "C4G_StairTop", look(18, OY + 3, 20.5, 6, OY + 3, 6))
	anchor(A, "C4G_Royce_Chair", look(-8, OY + 3, dz + 3.2, -8, OY + 3, -10))
	anchor(A, "C4G_Player_AtDesk", look(-8, OY + 3, dz - 4.5, -8, OY + 3, dz + 3))
	anchor(A, "C4G_Dre_AtDesk", look(-12.5, OY + 3, dz - 6, -8, OY + 3, dz + 3))
	anchor(A, "C4G_WallMap_Look", look(-hx + 7, OY + 4.8, mapZ, -hx + 1, OY + 6, mapZ))
	anchor(A, "C4G_RedBook", book.CFrame)
	anchor(A, "C4G_Cam_OfficeWide", look(10, OY + 7, -hz + 4, -8, OY + 3, dz + 2))
	anchor(A, "C4G_Cam_OverShoulder", look(-6.5, OY + 5.2, dz - 7.5, -8, OY + 4.6, dz + 3))
	anchor(A, "C4G_Cam_Street", look(14, 6, -hz - 26, 0, 9, 0))

	model.Parent = hood
	return ("Cash 4 Gold built (%d parts) at %s"):format(#model:GetDescendants(), tostring(B.Position))
end

---------------------------------------------------------------------------------------------------------------
-- THE ENDS ROOFTOP
local function buildRooftop(): string
	local ap
	for _, m in hood:GetChildren() do
		if m.Name == "Apartments" then
			local cf = m:GetBoundingBox()
			if math.abs(cf.X + 1433) < 6 and math.abs(cf.Z + 59) < 6 then ap = m end
		end
	end
	if not ap then return "Rooftop: apartments not found" end
	local old = ap:FindFirstChild("MTL_EndsRooftop")
	if old then old:Destroy() end
	-- the roof slab
	local roof, top = nil, -math.huge
	for _, p in ap:GetDescendants() do
		if p:IsA("BasePart") and p.Size.X * p.Size.Z > 400 and p.Parent ~= ap:FindFirstChild("MTL_Decor") then
			local t = p.Position.Y + p.Size.Y / 2
			if t > top then top, roof = t, p end
		end
	end
	local model = Instance.new("Model"); model.Name = "MTL_EndsRooftop"; model:SetAttribute("MTL_StorySet", "EndsRooftop")
	local P, Wd = maker(model)
	-- roof frame: +X (local) = east = toward downtown (the apartment faces east)
	local R = CFrame.new(roof.Position.X, top, roof.Position.Z)
	local rx, rz = roof.Size.X / 2, roof.Size.Z / 2
	local function at(x, y, z) return R * CFrame.new(x, y, z) end
	-- move the roof clutter from the decorator off the east half (keep the view clear)
	local decor = ap:FindFirstChild("MTL_Decor")
	if decor then
		for _, p in decor:GetChildren() do
			if p:IsA("BasePart") and p.Position.Y > top - 0.5 and (p.Position.X - R.Position.X) > -4 then p:Destroy() end
		end
	end
	-- parapet (knee wall) with coping all round, gap for the fire-escape gate on the west
	local PH = 3.2
	local CAP = C(150, 146, 138)
	local WALLC = C(180, 172, 156)
	P("Parapet", Vector3.new(rx * 2, PH, 0.8), at(0, PH / 2, -rz + 0.4), WALLC, M.Concrete)
	P("Parapet", Vector3.new(rx * 2, PH, 0.8), at(0, PH / 2, rz - 0.4), WALLC, M.Concrete)
	P("Parapet", Vector3.new(0.8, PH, rz * 2), at(rx - 0.4, PH / 2, 0), WALLC, M.Concrete)
	P("Parapet", Vector3.new(0.8, PH, rz - 3), at(-rx + 0.4, PH / 2, -rz + (rz - 3) / 2), WALLC, M.Concrete)
	P("Parapet", Vector3.new(0.8, PH, rz - 3), at(-rx + 0.4, PH / 2, rz - (rz - 3) / 2), WALLC, M.Concrete)
	for _, c in { { 0, -rz + 0.4, rx * 2 + 0.6, 1.2 }, { 0, rz - 0.4, rx * 2 + 0.6, 1.2 } } do P("Coping", Vector3.new(c[3], 0.3, c[4]), at(c[1], PH + 0.15, c[2]), CAP, M.Concrete) end
	P("Coping", Vector3.new(1.2, 0.3, rz * 2), at(rx - 0.4, PH + 0.15, 0), CAP, M.Concrete)
	-- roofing membrane patches, puddle
	for i = 0, 3 do P("RoofPatch", Vector3.new(6 + i, 0.04, 5 + i % 2 * 2), at(-rx * 0.5 + i * 7, 0.03 + i * 0.005, (i % 2 - 0.5) * 10), C(70, 70, 72), M.Asphalt, { CanCollide = false }) end
	P("Puddle", Vector3.new(0.04, 6, 4), at(8, 0.06, -6) * CFrame.Angles(0, 0, math.pi / 2), C(40, 50, 60), M.Glass, { shape = Enum.PartType.Cylinder, Transparency = 0.3, Reflectance = 0.3, CanCollide = false })
	-- roof door hut (west side) with a lit bulb
	local hutX, hutZ = -rx + 6, rz - 6
	P("Hut", Vector3.new(7, 8, 6), at(hutX, 4, hutZ), WALLC, M.Concrete)
	P("HutRoof", Vector3.new(7.6, 0.5, 6.6), at(hutX, 8.25, hutZ), C(80, 80, 82), M.Metal)
	P("HutDoor", Vector3.new(3.6, 7, 0.2), at(hutX + 3.55, 3.6, hutZ) * CFrame.Angles(0, math.pi / 2, 0), C(70, 74, 80), M.Metal)
	local bulb = P("HutLight", Vector3.new(0.7, 0.7, 0.5), at(hutX + 3.7, 7.4, hutZ), C(255, 220, 160), M.Neon)
	local hl = Instance.new("PointLight"); hl.Range = 14; hl.Brightness = 1.4; hl.Color = C(255, 200, 140); hl.Parent = bulb
	-- water tank on legs (west), satellite dish
	for _, o in { { -1.8, -1.8 }, { 1.8, -1.8 }, { -1.8, 1.8 }, { 1.8, 1.8 } } do P("TankLeg", Vector3.new(0.4, 6, 0.4), at(-rx + 7 + o[1], 3, -rz + 7 + o[2]), STEEL, M.Metal) end
	P("Tank", Vector3.new(6, 6, 6), at(-rx + 7, 9, -rz + 7) * CFrame.Angles(0, 0, math.pi / 2), C(110, 82, 60), M.WoodPlanks, { shape = Enum.PartType.Cylinder })
	P("TankCap", Vector3.new(1.4, 6.4, 6.4), at(-rx + 7, 12.6, -rz + 7) * CFrame.Angles(0, 0, math.pi / 2), C(70, 66, 62), M.Metal, { shape = Enum.PartType.Cylinder })
	-- hangout spot at the east edge: plastic chairs, crate table, cooler, a speaker, string lights
	local ex = rx - 5
	for i, o in { { -2, -3, 30 }, { -2, 3, -30 }, { 1.5, -4.5, 80 } } do
		local base = at(ex + o[1], 0, o[2]) * CFrame.Angles(0, math.rad(o[3]), 0)
		P("PlasticChair", Vector3.new(2, 0.3, 2), base * CFrame.new(0, 1.6, 0), C(236, 236, 230), M.Plastic)
		P("PlasticChairBack", Vector3.new(2, 2, 0.25), base * CFrame.new(0, 2.7, 0.9), C(236, 236, 230), M.Plastic)
		for _, l in { { -0.8, -0.8 }, { 0.8, -0.8 }, { -0.8, 0.8 }, { 0.8, 0.8 } } do P("ChairLeg", Vector3.new(0.15, 1.5, 0.15), base * CFrame.new(l[1], 0.75, l[2]), C(236, 236, 230), M.Plastic) end
	end
	P("CrateTable", Vector3.new(2.6, 2, 2.6), at(ex - 3.5, 1, 0), C(150, 116, 80), M.WoodPlanks)
	P("Cooler", Vector3.new(2.4, 1.6, 1.6), at(ex - 6, 0.8, -2), C(30, 90, 160), M.Plastic)
	P("CoolerLid", Vector3.new(2.5, 0.25, 1.7), at(ex - 6, 1.72, -2), C(236, 236, 236), M.Plastic)
	P("Speaker", Vector3.new(1.2, 2, 1.2), at(ex - 3.5, 3, 0.4), C(20, 20, 22), M.SmoothPlastic)
	for k = 0, 2 do P("Can", Vector3.new(0.4, 0.55, 0.4), at(ex - 3.9 + k * 0.4, 2.27, -0.6), Color3.fromHSV(k * 0.3, 0.7, 0.8), M.Metal) end
	-- string lights between two poles (sagging, warm bulbs that read at night)
	local poleA = P("LightPole", Vector3.new(0.3, 7, 0.3), at(ex - 9, 3.5, -rz + 2), C(60, 60, 62), M.Metal)
	local poleB = P("LightPole", Vector3.new(0.3, 7, 0.3), at(ex - 9, 3.5, rz - 2), C(60, 60, 62), M.Metal)
	local a, b = at(ex - 9, 7, -rz + 2).Position, at(ex - 9, 7, rz - 2).Position
	local prev = a
	for i = 1, 16 do
		local t = i / 16
		local p = a:Lerp(b, t) - Vector3.new(0, 1.6 * 4 * t * (1 - t), 0)
		noCol(P("Wire", Vector3.new(0.06, 0.06, (p - prev).Magnitude), CFrame.lookAt((prev + p) / 2, p), C(20, 20, 20), M.SmoothPlastic))
		local bulbp = noCol(P("StringBulb", Vector3.new(0.35, 0.35, 0.35), CFrame.new(p - Vector3.new(0, 0.25, 0)), C(255, 210, 140), M.Neon, { shape = Enum.PartType.Ball }))
		if i % 4 == 0 then local sl = Instance.new("PointLight"); sl.Range = 8; sl.Brightness = 0.8; sl.Color = C(255, 196, 130); sl.Parent = bulbp end
		prev = p
	end
	-- FIRE ESCAPE up the west wall: switchback steel flights with landings, ground to the roof gate
	local fe = Instance.new("Model"); fe.Name = "FireEscape"; fe.Parent = model
	local PF = select(1, maker(fe))
	local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Include; rp.FilterDescendantsInstances = { ap }
	local wallHit = workspace:Raycast(at(-rx - 12, -6, 0).Position, Vector3.new(14, 0, 0), rp)
	local wx = wallHit and wallHit.Position.X or (R.Position.X - rx)
	local gY = 2
	local H = top - gY
	local flights = 5
	local fr = H / flights
	local run = 12
	local outX = wx - 2.4 -- centre line of the stair, out from the wall
	for f = 0, flights - 1 do
		local y0 = gY + f * fr
		local dir = (f % 2 == 0) and 1 or -1
		local zStart = dir > 0 and -run / 2 or run / 2
		local n = 9
		for s = 1, n do
			local zz = zStart + dir * (s - 0.5) * (run / n)
			PF("Tread", Vector3.new(3.4, 0.2, run / n + 0.05), CFrame.new(outX, y0 + s * fr / n - 0.1, R.Position.Z + zz), C(80, 82, 86), M.DiamondPlate)
		end
		local mid = Vector3.new(outX, y0 + fr / 2, R.Position.Z)
		local ang = math.atan2(fr, run) * dir
		PF("Stringer", Vector3.new(0.2, 0.8, math.sqrt(run * run + fr * fr)), CFrame.new(mid + Vector3.new(1.75, -0.3, 0)) * CFrame.Angles(-ang, 0, 0), STEEL, M.Metal)
		PF("Stringer", Vector3.new(0.2, 0.8, math.sqrt(run * run + fr * fr)), CFrame.new(mid + Vector3.new(-1.75, -0.3, 0)) * CFrame.Angles(-ang, 0, 0), STEEL, M.Metal)
		PF("Rail", Vector3.new(0.12, 0.12, math.sqrt(run * run + fr * fr)), CFrame.new(mid + Vector3.new(-1.75, 2.8, 0)) * CFrame.Angles(-ang, 0, 0), STEEL, M.Metal)
		-- landing at the top of each flight
		local zL = zStart + dir * (run + 1.8)
		PF("Landing", Vector3.new(3.6, 0.25, 3.6), CFrame.new(outX, y0 + fr - 0.12, R.Position.Z + zL), C(80, 82, 86), M.DiamondPlate)
		PF("LandingRail", Vector3.new(0.12, 3, 3.6), CFrame.new(outX - 1.8, y0 + fr + 1.4, R.Position.Z + zL), STEEL, M.Metal)
		PF("LandingRail", Vector3.new(3.6, 3, 0.12), CFrame.new(outX, y0 + fr + 1.4, R.Position.Z + zL + dir * 1.8), STEEL, M.Metal)
		PF("Bracket", Vector3.new(2.6, 0.3, 0.3), CFrame.new(outX + 1.1, y0 + fr - 0.5, R.Position.Z + zL), STEEL, M.Metal)
	end
	-- the last landing joins the roof through the parapet gap (west edge, z ~ 0)
	PF("RoofBridge", Vector3.new(math.abs((R.Position.X - rx) - outX) + 2, 0.25, 4), CFrame.new(((R.Position.X - rx) + outX) / 2, top - 0.1, R.Position.Z), C(80, 82, 86), M.DiamondPlate)
	-- anchors
	local A = Instance.new("Folder"); A.Name = "Anchors"; A.Parent = model
	local function look(px, py, pz, tx, ty, tz) return CFrame.lookAt(at(px, py, pz).Position, at(tx, ty, tz).Position) end
	anchor(A, "Roof_Nina_AtLedge", look(rx - 2.4, 3, -1.5, 0, 3, 0)) -- back to the skyline
	anchor(A, "Roof_Player_FacingNina", look(rx - 8, 3, -1.5, rx - 2.4, 3, -1.5))
	anchor(A, "Roof_Cam_SkylineTwoShot", look(rx - 16, 5.5, 4, rx, 4, -2))
	anchor(A, "Roof_Cam_NinaCloseUp", look(rx - 6.2, 4.6, -0.8, rx - 2.4, 4.4, -1.5))
	anchor(A, "Roof_Cam_Skyline", look(rx - 1.5, 6, -1.5, rx + 200, 30, -40))
	anchor(A, "Roof_Arrival_FireEscape", CFrame.lookAt(Vector3.new(R.Position.X - rx + 2, top + 3, R.Position.Z), at(0, 3, 0).Position))
	anchor(A, "Roof_FireEscape_Bottom", CFrame.lookAt(Vector3.new(outX, gY + 3, R.Position.Z - run / 2 - 2), Vector3.new(outX, gY + 3, R.Position.Z)))
	model.Parent = ap
	return ("Ends rooftop built (%d parts) on the roof at y %.1f; downtown is +X"):format(#model:GetDescendants(), top)
end

function Sets.build(): string
	local a = buildCash4Gold()
	task.wait()
	local b = buildRooftop()
	return a .. "\n" .. b
end

return Sets
