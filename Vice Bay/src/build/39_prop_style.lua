-- 39 Prop style pass: "realistic low poly" (same recipe as the hood buildings).
-- Simple honest shapes at real sizes, muted colours (<= ~200), real materials (brushed steel, matte plastic,
-- cardboard), small believable details (knobs, lips, price strips, tape, casters) and wear via decals - not
-- noisy textures or toy colours. Rebuilds the flat-looking props from scratch; keeps the good textured meshes
-- (forklift, pallet, jack, tyres, car lift, pallet jack, hydrant) and only mutes the saturated ones.
-- Old versions go to ServerStorage.VBPropsOld (never deleted). Pivot = bottom centre, front = -Z.
return function(L)
	local C, M = L.C, L.M
	local SS = game:GetService("ServerStorage")
	local LIB = SS:FindFirstChild("VBProps") or Instance.new("Folder", SS)
	LIB.Name = "VBProps"
	local OLD = SS:FindFirstChild("VBPropsOld") or Instance.new("Folder", SS)
	OLD.Name = "VBPropsOld"
	local STREAK, OIL = "rbxassetid://729943180", "rbxassetid://118775947"
	local CARD = M.Cardboard or M.SmoothPlastic

	local STEEL, DSTEEL, BLACKP, OFFW = C(170, 172, 174), C(120, 122, 126), C(36, 37, 40), C(214, 214, 208)

	local function newModel(cat, name)
		local f = LIB:FindFirstChild(cat) or Instance.new("Folder")
		f.Name = cat
		f.Parent = LIB
		local old = f:FindFirstChild(name)
		if old then
			local of = OLD:FindFirstChild(cat) or Instance.new("Folder", OLD)
			of.Name = cat
			local prev = of:FindFirstChild(name)
			if prev then prev:Destroy() end
			old.Parent = of
		end
		local m = Instance.new("Model")
		m.Name = name
		return m, f
	end
	local function P(m, size, cf, col, mat, props)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanTouch = false
		p.CanQuery = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Size = size
		p.CFrame = cf
		p.Color = col
		p.Material = mat or M.SmoothPlastic
		local small = size.X * size.Y * size.Z < 2
		p.CastShadow = not small
		if small then p.CanCollide = false end
		if props then for k, v in pairs(props) do p[k] = v end end
		p.Parent = m
		return p
	end
	-- box resting on y0 in frame cf
	local function B(m, cf, x, y0, z, sx, sy, sz, col, mat, props)
		return P(m, Vector3.new(sx, sy, sz), cf * CFrame.new(x, y0 + sy / 2, z), col, mat, props)
	end
	local function Cyl(m, len, dia, cf, col, mat, props) -- axis along local Y
		local p = P(m, Vector3.new(len, dia, dia), cf * CFrame.Angles(0, 0, math.pi / 2), col, mat, props)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	local function decal(part, face, img, tr)
		local d = Instance.new("Decal")
		d.Texture = img
		d.Face = face
		d.Transparency = tr
		d.Parent = part
	end
	local function label(part, face, txt, col, font, bg)
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.LightInfluence = 1
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 60
		g.MaxDistance = 80
		g.Parent = part
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(0.9, 0.8)
		t.Position = UDim2.fromScale(0.05, 0.1)
		t.BackgroundTransparency = bg and 0 or 1
		if bg then t.BackgroundColor3 = bg end
		t.TextScaled = true
		t.Font = font or Enum.Font.GothamBlack
		t.TextColor3 = col
		t.Text = txt
		t.Parent = g
	end
	local function finish(m, f)
		m.WorldPivot = CFrame.new()
		m.Parent = f
		return m
	end
	local O = CFrame.new()
	local made = {}

	-- ===================== STORE =====================
	do -- double-sided gondola: kick plate, centre pegboard, uprights, end panels, 4 shelves a side with price strips
		local m, f = newModel("Store", "ShelfBay")
		local Lg, D, H = 12, 4, 6.5
		local PAINT = C(186, 188, 190)
		B(m, O, 0, 0, 0, Lg, 0.5, D, C(140, 142, 144), M.Metal)
		local back = B(m, O, 0, 0.5, 0, Lg, H - 0.5, 0.12, PAINT, M.SmoothPlastic)
		for _, fc in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do if L.villaStripes then L.villaStripes(back, fc, 18, C(150, 152, 154), 0.6, false) end end
		for k = 0, 3 do B(m, O, -Lg / 2 + 0.15 + k * (Lg - 0.3) / 3, 0.5, 0, 0.25, H - 0.5, 0.4, C(150, 152, 156), M.Metal) end
		for _, sx in ipairs({ -1, 1 }) do
			local e = B(m, O, sx * (Lg / 2 + 0.06), 0, 0, 0.12, H, D, PAINT, M.SmoothPlastic)
			decal(e, sx < 0 and Enum.NormalId.Left or Enum.NormalId.Right, STREAK, 0.85)
		end
		for _, sz in ipairs({ -1, 1 }) do
			for lv = 0, 3 do
				local y = 0.5 + lv * 1.45
				B(m, O, 0, y, sz * (D / 4 + 0.05), Lg - 0.3, 0.1, D / 2 - 0.2, PAINT, M.SmoothPlastic)
				local lip = B(m, O, 0, y - 0.05, sz * (D / 2 - 0.05), Lg - 0.3, 0.32, 0.06, C(226, 226, 220), M.SmoothPlastic)
				if L.villaStripes then L.villaStripes(lip, sz < 0 and Enum.NormalId.Front or Enum.NormalId.Back, 19, C(206, 176, 70), 0.25, true) end
			end
		end
		finish(m, f)
		table.insert(made, "Store/ShelfBay")
	end
	do -- POS register: base + drawer, tilted touch screen on a post, receipt printer, card reader
		local m, f = newModel("Store", "Register")
		B(m, O, 0, 0, 0, 1.5, 0.3, 1.3, BLACKP, M.Plastic)
		B(m, O, 0, 0.06, -0.66, 1.3, 0.18, 0.02, C(60, 62, 66), M.Plastic)
		B(m, O, -0.3, 0.3, 0.2, 0.14, 0.55, 0.14, DSTEEL, M.Metal)
		local scr = P(m, Vector3.new(1.1, 0.75, 0.08), O * CFrame.new(-0.3, 1.15, 0.12) * CFrame.Angles(math.rad(-15), 0, 0), BLACKP, M.Plastic)
		local face = P(m, Vector3.new(1.0, 0.65, 0.02), scr.CFrame * CFrame.new(0, 0, -0.05), C(28, 38, 48), M.Glass, { Reflectance = 0.15 })
		label(face, Enum.NormalId.Front, "SALE   $4.29\nTOTAL  $4.29", C(170, 200, 210), Enum.Font.Code)
		B(m, O, 0.48, 0.3, 0.25, 0.45, 0.35, 0.55, C(48, 49, 52), M.Plastic)
		B(m, O, 0.48, 0.66, 0.22, 0.3, 0.02, 0.06, OFFW, M.SmoothPlastic)
		B(m, O, 0.55, 0.3, -0.42, 0.28, 0.1, 0.42, BLACKP, M.Plastic)
		B(m, O, 0.55, 0.4, -0.38, 0.2, 0.01, 0.14, C(60, 90, 100), M.Glass)
		finish(m, f)
		table.insert(made, "Store/Register")
	end

	-- ===================== KITCHEN =====================
	do -- flat-top griddle on a steel stand
		local m, f = newModel("Kitchen", "Grill")
		local W, D = 5, 2.8
		for _, sx in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do Cyl(m, 2.2, 0.2, O * CFrame.new(sx * (W / 2 - 0.25), 1.1, sz * (D / 2 - 0.25)), STEEL, M.Metal) end end
		B(m, O, 0, 0.45, 0, W - 0.3, 0.08, D - 0.3, STEEL, M.Metal)
		local body = B(m, O, 0, 2.2, 0, W, 1.0, D, STEEL, M.Metal)
		decal(body, Enum.NormalId.Front, STREAK, 0.75)
		local plate = B(m, O, 0, 3.2, 0.15, W - 0.4, 0.12, D - 0.6, C(46, 46, 48), M.Metal)
		decal(plate, Enum.NormalId.Top, OIL, 0.35)
		B(m, O, 0, 3.2, D / 2 - 0.05, W, 0.9, 0.1, STEEL, M.Metal)
		for _, sx in ipairs({ -1, 1 }) do B(m, O, sx * (W / 2 - 0.05), 3.2, 0.1, 0.1, 0.55, D - 0.2, STEEL, M.Metal) end
		B(m, O, 0, 3.15, -D / 2 + 0.2, W - 0.4, 0.12, 0.25, DSTEEL, M.Metal)
		for k = 0, 3 do Cyl(m, 0.18, 0.28, O * CFrame.new(-1.5 + k, 2.7, -D / 2 - 0.05) * CFrame.Angles(math.pi / 2, 0, 0), BLACKP, M.Plastic) end
		finish(m, f)
		table.insert(made, "Kitchen/Grill")
	end
	do -- double deep fryer: cabinet, two oil vats, baskets on the back rail, control panel
		local m, f = newModel("Kitchen", "Fryer")
		local W, D = 2.2, 2.8
		local cab = B(m, O, 0, 0.3, 0, W, 2.9, D, STEEL, M.Metal)
		decal(cab, Enum.NormalId.Front, STREAK, 0.7)
		B(m, O, 0, 0.3, -D / 2 - 0.01, 0.04, 2.2, 0.02, DSTEEL, M.Metal)
		for _, sx in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do Cyl(m, 0.3, 0.2, O * CFrame.new(sx * (W / 2 - 0.2), 0.15, sz * (D / 2 - 0.2)), DSTEEL, M.Metal) end end
		for _, sx in ipairs({ -0.5, 0.5 }) do
			B(m, O, sx, 3.17, -0.1, 0.85, 0.05, 1.5, C(150, 116, 52), M.SmoothPlastic, { Reflectance = 0.2 })
			local bk = B(m, O, sx, 3.15, 0.1, 0.75, 0.45, 1.1, C(160, 160, 158), M.DiamondPlate, { Transparency = 0.35 })
			B(m, O, sx, 3.5, -0.6, 0.08, 0.08, 0.7, BLACKP, M.Rubber)
			local _ = bk
		end
		local panel = B(m, O, 0, 3.2, D / 2 - 0.1, W, 0.7, 0.2, STEEL, M.Metal)
		for _, sx in ipairs({ -0.5, 0.5 }) do B(m, O, sx, 3.45, D / 2 - 0.21, 0.4, 0.2, 0.02, C(30, 40, 30), M.Glass) end
		local _ = panel
		finish(m, f)
		table.insert(made, "Kitchen/Fryer")
	end
	do -- exhaust hood (wall mounted, hang it so its bottom is ~6.5 studs up)
		local m, f = newModel("Kitchen", "ExhaustHood")
		local W, D = 10, 3.5
		local box = B(m, O, 0, 0.8, 0.4, W, 1.2, D - 0.8, STEEL, M.Metal)
		decal(box, Enum.NormalId.Front, STREAK, 0.7)
		local w = Instance.new("WedgePart")
		w.Anchored, w.CanTouch, w.CanQuery = true, false, false
		w.Size = Vector3.new(W, 0.8, D)
		w.CFrame = O * CFrame.new(0, 0.4, 0) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(math.pi, 0, 0)
		w.Color, w.Material = STEEL, M.Metal
		w.Parent = m
		for k = 0, 3 do P(m, Vector3.new(2.2, 0.9, 0.06), O * CFrame.new(-3.6 + k * 2.4, 0.9, 0.3) * CFrame.Angles(math.rad(35), 0, 0), C(110, 112, 114), M.DiamondPlate) end
		B(m, O, 0, 0, -D / 2 + 0.1, W, 0.15, 0.2, DSTEEL, M.Metal)
		finish(m, f)
		table.insert(made, "Kitchen/ExhaustHood")
	end
	do -- stainless prep table with a cutting board and sauce bottles
		local m, f = newModel("Kitchen", "PrepTable")
		local W, D = 6, 2.5
		for _, sx in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do Cyl(m, 3.1, 0.18, O * CFrame.new(sx * (W / 2 - 0.2), 1.55, sz * (D / 2 - 0.2)), STEEL, M.Metal) end end
		B(m, O, 0, 3.1, 0, W, 0.1, D, STEEL, M.Metal)
		B(m, O, 0, 3.2, D / 2 - 0.04, W, 0.5, 0.08, STEEL, M.Metal)
		B(m, O, 0, 0.5, 0, W - 0.3, 0.08, D - 0.3, STEEL, M.Metal)
		B(m, O, -1.2, 3.2, -0.1, 2, 0.1, 1.4, C(206, 198, 182), M.SmoothPlastic)
		for k, col in ipairs({ C(150, 52, 42), C(186, 156, 52) }) do
			Cyl(m, 0.7, 0.3, O * CFrame.new(1.2 + k * 0.45, 3.55, 0.6), col, M.Plastic)
			Cyl(m, 0.18, 0.12, O * CFrame.new(1.2 + k * 0.45, 4.0, 0.6), OFFW, M.Plastic)
		end
		B(m, O, 1.2, 3.2, -0.3, 1.2, 0.5, 0.9, STEEL, M.Metal)
		B(m, O, 1.2, 0.58, 0, 1.4, 0.8, 1.2, C(176, 140, 96), CARD)
		finish(m, f)
		table.insert(made, "Kitchen/PrepTable")
	end

	-- ===================== JOBS =====================
	do -- A-frame wet floor sign
		local m, f = newModel("Jobs", "WetFloorSign")
		local Y = C(204, 172, 44)
		for _, sd in ipairs({ -1, 1 }) do
			local pnl = P(m, Vector3.new(1.0, 2.15, 0.06), O * CFrame.new(0, 2.15, 0) * CFrame.Angles(sd * math.rad(13), 0, 0) * CFrame.new(0, -1.08, 0), Y, M.Plastic)
			label(pnl, sd < 0 and Enum.NormalId.Front or Enum.NormalId.Back, "⚠\nCAUTION\nWET FLOOR", C(28, 28, 28), Enum.Font.GothamBlack)
		end
		B(m, O, 0, 2.1, 0, 0.6, 0.18, 0.18, Y, M.Plastic)
		finish(m, f)
		table.insert(made, "Jobs/WetFloorSign")
	end
	do -- commercial mop bucket with wringer, casters and a mop
		local m, f = newModel("Jobs", "MopBucket")
		local Y = C(196, 162, 46)
		B(m, O, 0, 0.25, 0, 1.6, 1.3, 1.2, Y, M.Plastic)
		B(m, O, -0.15, 1.5, 0, 1.2, 0.04, 1.0, C(104, 96, 78), M.SmoothPlastic, { Transparency = 0.15 })
		B(m, O, 0.5, 1.55, 0, 0.55, 0.7, 1.0, C(170, 140, 40), M.Plastic)
		P(m, Vector3.new(0.08, 1.2, 0.08), O * CFrame.new(0.75, 2.4, 0) * CFrame.Angles(0, 0, math.rad(-20)), DSTEEL, M.Metal)
		for _, sx in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do P(m, Vector3.new(0.18, 0.25, 0.25), O * CFrame.new(sx * 0.65, 0.12, sz * 0.45), BLACKP, M.Rubber, { Shape = Enum.PartType.Cylinder }) end end
		P(m, Vector3.new(0.1, 5, 0.1), O * CFrame.new(-0.2, 2.6, 0.1) * CFrame.Angles(math.rad(8), 0, math.rad(10)), C(140, 110, 70), M.Wood)
		B(m, O, -0.4, 1.0, 0.0, 0.7, 0.5, 0.5, C(170, 168, 160), M.Fabric)
		finish(m, f)
		table.insert(made, "Jobs/MopBucket")
	end
	do -- taped cardboard shipping box (the restock carry)
		local m, f = newModel("Jobs", "CardboardBox")
		local b = B(m, O, 0, 0, 0, 1.6, 1.2, 1.2, C(176, 140, 96), CARD)
		B(m, O, 0, 1.2, 0, 1.62, 0.02, 0.28, C(196, 174, 128), M.SmoothPlastic, { Transparency = 0.2 })
		for _, sz in ipairs({ -1, 1 }) do B(m, O, 0, 0.85, sz * 0.61, 0.28, 0.35, 0.02, C(196, 174, 128), M.SmoothPlastic, { Transparency = 0.2 }) end
		B(m, O, 0, 1.2, 0, 0.02, 0.01, 1.2, C(120, 92, 60), M.SmoothPlastic)
		local lab = B(m, O, 0.35, 0.35, -0.61, 0.6, 0.4, 0.02, C(220, 218, 210), M.SmoothPlastic)
		label(lab, Enum.NormalId.Front, "↑↑ THIS SIDE UP", C(40, 40, 40), Enum.Font.GothamBold)
		label(b, Enum.NormalId.Right, "FRAGILE", C(130, 46, 40), Enum.Font.GothamBlack)
		finish(m, f)
		table.insert(made, "Jobs/CardboardBox")
	end
	do -- black trash bag, tied at the top
		local m, f = newModel("Jobs", "TrashBag")
		P(m, Vector3.new(1.4, 1.5, 1.3), O * CFrame.new(0, 0.75, 0), C(28, 28, 30), M.Plastic, { Shape = Enum.PartType.Ball, Reflectance = 0.06 })
		Cyl(m, 0.35, 0.3, O * CFrame.new(0, 1.55, 0), C(30, 30, 32), M.Plastic)
		P(m, Vector3.new(0.5, 0.3, 0.3), O * CFrame.new(0, 1.78, 0), C(30, 30, 32), M.Plastic, { Shape = Enum.PartType.Ball })
		finish(m, f)
		table.insert(made, "Jobs/TrashBag")
	end

	-- ===================== DEPOT / STREET =====================
	do -- 20 ft shipping container: corrugated sides, corner posts, rails, door end with lock bars
		local m, f = newModel("Depot", "Container")
		local Lc, W, H = 21.8, 8.7, 9.3
		local col = L.pick and L.pick({ C(138, 64, 48), C(52, 78, 104), C(70, 94, 72), C(150, 150, 146) }) or C(138, 64, 48)
		local body = B(m, O, 0, 0.3, 0, W - 0.2, H - 0.6, Lc - 0.2, col, M.Metal)
		for _, fc in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right }) do
			if L.villaStripes then L.villaStripes(body, fc, 19, L.shade(col, 0.6), 0.5, true) end
			decal(body, fc, STREAK, 0.45)
		end
		local fr = L.shade(col, 0.75)
		for _, sx in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do B(m, O, sx * (W / 2 - 0.3), 0, sz * (Lc / 2 - 0.3), 0.6, H, 0.6, fr, M.Metal) end end
		for _, y in ipairs({ 0, H - 0.4 }) do
			for _, sx in ipairs({ -1, 1 }) do B(m, O, sx * (W / 2 - 0.2), y, 0, 0.4, 0.4, Lc, fr, M.Metal) end
			for _, sz in ipairs({ -1, 1 }) do B(m, O, 0, y, sz * (Lc / 2 - 0.2), W, 0.4, 0.4, fr, M.Metal) end
		end
		B(m, O, 0, 0.4, -Lc / 2 + 0.05, 0.08, H - 0.8, 0.06, L.shade(col, 0.55), M.Metal)
		for _, x in ipairs({ -3, -1.4, 1.4, 3 }) do Cyl(m, H - 1, 0.18, O * CFrame.new(x, H / 2, -Lc / 2 - 0.08), C(150, 150, 146), M.Metal) end
		local plate = B(m, O, 2.4, H - 1.9, -Lc / 2 - 0.02, 2.6, 0.7, 0.02, col, M.Metal, { Transparency = 1 })
		label(plate, Enum.NormalId.Front, "VBXU 204188 2", C(226, 224, 216), Enum.Font.Arial)
		finish(m, f)
		table.insert(made, "Depot/Container")
	end
	do -- unbranded street payphone on a post
		local m, f = newModel("Street", "Payphone")
		B(m, O, 0, 0, 0.2, 0.3, 4.2, 0.3, DSTEEL, M.Metal)
		local box = B(m, O, 0, 3.2, 0, 1.4, 2.2, 0.7, C(158, 160, 162), M.Metal)
		decal(box, Enum.NormalId.Front, STREAK, 0.6)
		B(m, O, 0, 5.4, 0.05, 1.9, 0.12, 1.2, C(140, 142, 144), M.Metal)
		local sg = B(m, O, 0, 5.52, -0.4, 1.9, 0.5, 0.08, C(40, 64, 98), M.SmoothPlastic)
		label(sg, Enum.NormalId.Front, "PHONE", C(226, 226, 222), Enum.Font.GothamBold)
		local kp = B(m, O, 0.15, 3.9, -0.36, 0.55, 0.7, 0.04, C(52, 54, 58), M.Metal)
		label(kp, Enum.NormalId.Front, "1 2 3\n4 5 6\n7 8 9\n* 0 #", C(200, 200, 196), Enum.Font.Code)
		B(m, O, -0.5, 3.6, -0.4, 0.25, 0.9, 0.25, BLACKP, M.Plastic)
		B(m, O, 0.4, 4.7, -0.36, 0.25, 0.08, 0.04, C(30, 30, 32), M.Metal)
		finish(m, f)
		table.insert(made, "Street/Payphone")
	end

	-- ===================== low-poly versions of the detailed textured meshes =====================
	-- (so the whole kit reads as one style: chunky honest shapes, flat muted colours, no photo textures)
	local function HCyl(m, len, dia, cf, col, mat, props) -- axis along local X
		local p = P(m, Vector3.new(len, dia, dia), cf, col, mat, props)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	local RUB, YEL, RED = C(30, 30, 32), C(192, 158, 44), C(148, 44, 38)
	do -- stack of four used tyres
		local m, f = newModel("Garage", "TireStack")
		local rng = Random.new(4)
		for k = 0, 3 do
			local c = O * CFrame.new(rng:NextNumber(-0.12, 0.12), 0.4 + k * 0.8, rng:NextNumber(-0.12, 0.12))
			Cyl(m, 0.78, 2.6, c, RUB, M.Rubber)
			if k == 3 then Cyl(m, 0.8, 1.35, c, C(16, 16, 18), M.Rubber) end
		end
		finish(m, f)
		table.insert(made, "Garage/TireStack")
	end
	do -- hydraulic floor jack
		local m, f = newModel("Garage", "Jack")
		B(m, O, 0, 0.25, 0, 1.0, 0.4, 2.6, RED, M.Metal)
		for _, sx in ipairs({ -1, 1 }) do
			HCyl(m, 0.2, 0.55, O * CFrame.new(sx * 0.55, 0.28, -1.0), RUB, M.Rubber)
			HCyl(m, 0.2, 0.4, O * CFrame.new(sx * 0.45, 0.2, 1.1), RUB, M.Rubber)
		end
		P(m, Vector3.new(0.6, 0.25, 1.8), O * CFrame.new(0, 0.85, -0.4) * CFrame.Angles(math.rad(-14), 0, 0), RED, M.Metal)
		Cyl(m, 0.15, 0.6, O * CFrame.new(0, 1.12, -1.25), DSTEEL, M.Metal)
		P(m, Vector3.new(0.12, 0.12, 3.2), O * CFrame.new(0, 1.5, 2.3) * CFrame.Angles(math.rad(35), 0, 0), DSTEEL, M.Metal)
		finish(m, f)
		table.insert(made, "Garage/Jack")
	end
	do -- rolling mechanic tool chest (top box + cabinet, drawers, casters)
		local m, f = newModel("Garage", "ToolChest")
		local cab = B(m, O, 0, 0.35, 0, 3, 2.4, 1.6, RED, M.Plastic)
		decal(cab, Enum.NormalId.Front, STREAK, 0.8)
		B(m, O, 0, 2.75, 0.05, 3, 1.2, 1.45, RED, M.Plastic)
		B(m, O, 0, 3.95, 0.05, 3.05, 0.12, 1.5, C(60, 60, 64), M.Rubber)
		for k = 0, 4 do
			local y = 0.55 + k * 0.45
			B(m, O, 0, y + 0.38, -0.81, 2.9, 0.03, 0.02, C(70, 30, 26), M.SmoothPlastic)
			B(m, O, 0, y + 0.18, -0.84, 2.4, 0.07, 0.06, C(176, 178, 180), M.Metal)
		end
		for k = 0, 1 do B(m, O, 0, 3.0 + k * 0.45, -0.75, 2.4, 0.07, 0.06, C(176, 178, 180), M.Metal) end
		for _, sx in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do HCyl(m, 0.18, 0.32, O * CFrame.new(sx * 1.25, 0.16, sz * 0.55), RUB, M.Rubber) end end
		finish(m, f)
		table.insert(made, "Garage/ToolChest")
	end
	do -- two-post car lift (posts 11 apart, top beam, folded arms, power unit)
		local m, f = newModel("Garage", "CarLift")
		local COL = C(66, 86, 112)
		for _, sx in ipairs({ -1, 1 }) do
			B(m, O, sx * 5.6, 0, 0, 1.6, 0.15, 1.6, DSTEEL, M.Metal)
			local post = B(m, O, sx * 5.6, 0.15, 0, 0.9, 11.6, 0.9, COL, M.Metal)
			decal(post, Enum.NormalId.Front, STREAK, 0.75)
			B(m, O, sx * 5.0, 2.4, 0, 0.5, 0.9, 0.7, C(90, 92, 96), M.Metal)
			for _, sz in ipairs({ -1, 1 }) do
				local arm = P(m, Vector3.new(0.35, 0.25, 3.6), O * CFrame.new(sx * 4.4, 2.6, sz * 1.6) * CFrame.Angles(0, sx * sz * math.rad(25), 0), DSTEEL, M.Metal)
				Cyl(m, 0.25, 0.6, arm.CFrame * CFrame.new(0, 0.2, sz * 1.6), C(176, 150, 50), M.Rubber)
			end
		end
		B(m, O, 0, 11.75, 0, 12.1, 0.5, 0.6, COL, M.Metal)
		B(m, O, 6.35, 4, 0, 0.6, 1.6, 0.9, C(48, 50, 54), M.Metal)
		finish(m, f)
		table.insert(made, "Garage/CarLift")
	end
	do -- wooden pallet (real size ~1.2 x 1.0 m)
		local m, f = newModel("Depot", "Pallet")
		local WD, WD2 = C(166, 134, 96), C(140, 112, 80)
		for _, x in ipairs({ -1.9, 0, 1.9 }) do B(m, O, x, 0, 0, 0.5, 0.12, 3.6, WD2, M.Wood) B(m, O, x, 0.12, 0, 0.5, 0.3, 3.6, WD2, M.Wood) end
		for k = 0, 6 do B(m, O, 0, 0.42, -1.65 + k * 0.55, 4.4, 0.1, 0.38, (k % 3 == 1) and WD2 or WD, M.Wood) end
		finish(m, f)
		table.insert(made, "Depot/Pallet")
	end
	do -- manual pallet jack
		local m, f = newModel("Depot", "PalletJack")
		for _, sx in ipairs({ -0.75, 0.75 }) do
			B(m, O, sx, 0.05, -1.6, 0.55, 0.25, 4.2, YEL, M.Metal)
			HCyl(m, 0.4, 0.25, O * CFrame.new(sx, 0.13, -3.5), RUB, M.Rubber)
		end
		B(m, O, 0, 0.05, 0.75, 2.1, 0.9, 0.7, YEL, M.Metal)
		Cyl(m, 0.8, 0.45, O * CFrame.new(0, 1.3, 0.75), DSTEEL, M.Metal)
		HCyl(m, 0.5, 0.6, O * CFrame.new(0, 0.3, 1.0), RUB, M.Rubber)
		P(m, Vector3.new(0.14, 3.4, 0.14), O * CFrame.new(0, 3.2, 1.35) * CFrame.Angles(math.rad(-15), 0, 0), C(40, 40, 42), M.Metal)
		B(m, O, 0, 4.85, 1.8, 1.0, 0.16, 0.16, C(40, 40, 42), M.Rubber)
		finish(m, f)
		table.insert(made, "Depot/PalletJack")
	end
	do -- forklift (chassis, counterweight, overhead guard, mast, carriage + forks, seat, wheels)
		local m, f = newModel("Depot", "Forklift")
		local body = B(m, O, 0, 0.9, 0.6, 4.0, 1.6, 5.4, YEL, M.Metal)
		decal(body, Enum.NormalId.Left, STREAK, 0.75)
		decal(body, Enum.NormalId.Right, STREAK, 0.75)
		B(m, O, 0, 0.9, 3.6, 4.0, 2.6, 1.4, C(52, 54, 58), M.Metal)
		B(m, O, 0, 2.5, 1.4, 1.5, 0.45, 1.3, C(40, 40, 42), M.Plastic)
		B(m, O, 0, 2.95, 2.05, 1.5, 1.4, 0.35, C(40, 40, 42), M.Plastic)
		Cyl(m, 0.12, 1.1, O * CFrame.new(0, 3.2, -0.2) * CFrame.Angles(math.rad(-35), 0, 0), C(30, 30, 32), M.Plastic)
		B(m, O, 0, 2.5, -0.6, 2.4, 0.9, 0.5, YEL, M.Metal)
		for _, sx in ipairs({ -1, 1 }) do
			B(m, O, sx * 1.8, 2.5, -1.4, 0.2, 4.6, 0.2, C(36, 36, 38), M.Metal)
			B(m, O, sx * 1.8, 2.5, 3.0, 0.2, 4.6, 0.2, C(36, 36, 38), M.Metal)
			HCyl(m, 0.9, 2.0, O * CFrame.new(sx * 1.7, 1.0, -1.2), RUB, M.Rubber)
			HCyl(m, 0.8, 1.6, O * CFrame.new(sx * 1.7, 0.8, 3.0), RUB, M.Rubber)
			B(m, O, sx * 1.2, 0.2, -2.0, 0.35, 8.4, 0.45, C(48, 50, 54), M.Metal)
		end
		local roof = B(m, O, 0, 7.1, 0.8, 3.8, 0.2, 4.6, C(36, 36, 38), M.Metal)
		if L.villaStripes then L.villaStripes(roof, Enum.NormalId.Top, 8, C(20, 20, 22), 0.2, true) end
		B(m, O, 0, 1.0, -2.35, 3.2, 1.5, 0.25, C(48, 50, 54), M.Metal)
		for _, sx in ipairs({ -0.9, 0.9 }) do
			B(m, O, sx, 0.15, -4.2, 0.4, 0.15, 3.8, C(60, 62, 66), M.Metal)
			B(m, O, sx, 0.15, -2.4, 0.4, 1.6, 0.15, C(60, 62, 66), M.Metal)
		end
		finish(m, f)
		table.insert(made, "Depot/Forklift")
	end
	do -- fire hydrant (muted yellow, silver caps)
		local m, f = newModel("Street", "Hydrant")
		local HY, SIL = C(188, 158, 58), C(170, 172, 172)
		Cyl(m, 0.25, 1.2, O * CFrame.new(0, 0.12, 0), HY, M.Metal)
		local bd = Cyl(m, 1.9, 0.85, O * CFrame.new(0, 1.2, 0), HY, M.Metal)
		decal(bd, Enum.NormalId.Front, STREAK, 0.7)
		Cyl(m, 0.2, 1.0, O * CFrame.new(0, 2.2, 0), HY, M.Metal)
		P(m, Vector3.new(0.8, 0.6, 0.8), O * CFrame.new(0, 2.4, 0), SIL, M.Metal, { Shape = Enum.PartType.Ball })
		Cyl(m, 0.25, 0.22, O * CFrame.new(0, 2.78, 0), SIL, M.Metal)
		for _, sx in ipairs({ -1, 1 }) do HCyl(m, 0.4, 0.38, O * CFrame.new(sx * 0.55, 1.55, 0), SIL, M.Metal) end
		P(m, Vector3.new(0.4, 0.55, 0.55), O * CFrame.new(0, 1.35, -0.5) * CFrame.Angles(0, math.pi / 2, 0), SIL, M.Metal, { Shape = Enum.PartType.Cylinder })
		finish(m, f)
		table.insert(made, "Street/Hydrant")
	end

	-- ===================== mute the kept props (no toy colours) =====================
	local muted = 0
	for _, cat in ipairs(LIB:GetChildren()) do
		for _, m in ipairs(cat:GetChildren()) do
			if m:IsA("Model") and not table.find(made, cat.Name .. "/" .. m.Name) then
				for _, d in ipairs(m:GetDescendants()) do
					if d:IsA("BasePart") and not (d:IsA("MeshPart") and d.TextureID ~= "") and not d:FindFirstChildOfClass("SurfaceAppearance") and d.Material ~= M.Neon then
						local h, s, v = d.Color:ToHSV()
						local s2, v2 = s * 0.7, math.min(v, 0.8)
						if math.abs(s2 - s) > 0.01 or math.abs(v2 - v) > 0.01 then d.Color = Color3.fromHSV(h, s2, v2) muted += 1 end
						if d.Material == M.SmoothPlastic and d.Size.Magnitude > 1.5 then d.Material = M.Plastic end
					end
				end
			end
		end
	end

	-- ===================== low-poly textures =====================
	-- Keep every shape; just give each surface a simple real material texture instead of flat plastic:
	-- painted metal -> Metal, bare steel -> Metal / DiamondPlate, plastic -> Plastic, wood -> WoodPlanks,
	-- boxes -> Cardboard, rubber -> Rubber, mop/fabric -> Fabric. Light wear only (one faint streak decal on big faces).
	local textured = 0
	local function isGrey(c)
		local _, sat = c:ToHSV()
		return sat < 0.12
	end
	for _, cat in ipairs(LIB:GetChildren()) do
		for _, m in ipairs(cat:GetChildren()) do
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") and not d:IsA("MeshPart") and d.Material ~= M.Neon and d.Material ~= M.Glass and d.Transparency < 0.5 and not d:FindFirstChildOfClass("SurfaceGui") then
					local mat = d.Material
					local _, sat, val = d.Color:ToHSV()
					local big = d.Size.X * d.Size.Y * d.Size.Z > 3
					if mat == M.SmoothPlastic or mat == M.Plastic then
						if val < 0.2 then
							d.Material = M.Plastic
						elseif isGrey(d.Color) and val > 0.55 then
							d.Material = M.Metal -- painted shelving / panels
						elseif sat > 0.25 then
							d.Material = M.Plastic
						end
					end
					if d.Material == M.Wood then d.Material = M.WoodPlanks end
					if cat.Name == "Depot" and m.Name == "Pallet" then d.Material = M.WoodPlanks end
					if m.Name == "CardboardBox" and d.Size.Magnitude > 1.5 then d.Material = CARD end
					d.MaterialVariant = ""
					if big and not d:FindFirstChildOfClass("Decal") then
						decal(d, Enum.NormalId.Front, STREAK, 0.88)
					end
					textured += 1
				end
			end
		end
	end

	-- a few stronger material reads so the texture shows from a distance (built-in materials only: the
	-- MatPack metal variants render near-black in this game)
	local PEEL = "rbxassetid://164688340"
	local function each(cat, name, fn)
		local f = LIB:FindFirstChild(cat)
		local m = f and f:FindFirstChild(name)
		if m then for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") and not d:IsA("MeshPart") then fn(d) end end end
	end
	each("Depot", "Container", function(d) if d.Size.Magnitude > 4 and d.Transparency < 1 then d.Material = M.CorrodedMetal end end)
	each("Store", "ShelfBay", function(d) if d.Size.Y <= 0.5 and d.Position.Y < 0.6 then d.Material = M.DiamondPlate end end)
	each("Garage", "ToolChest", function(d) if d.Material == M.Plastic and d.Size.Magnitude > 2 then d.Material = M.Metal end end)
	for _, it in ipairs({ { "Depot", "Forklift" }, { "Depot", "PalletJack" }, { "Garage", "CarLift" }, { "Garage", "ToolChest" }, { "Garage", "Jack" }, { "Jobs", "MopBucket" } }) do
		each(it[1], it[2], function(d)
			local _, sat = d.Color:ToHSV()
			if sat > 0.3 and d.Size.Magnitude > 2.5 then
				local dd = Instance.new("Decal")
				dd.Texture = PEEL
				dd.Face = Enum.NormalId.Right
				dd.Transparency = 0.55
				dd.Parent = d
				local dl = dd:Clone()
				dl.Face = Enum.NormalId.Left
				dl.Parent = d
			end
		end)
	end
	each("Kitchen", "Grill", function(d) if d.Size.X >= 4.9 and d.Size.Y >= 0.9 and d.Size.Z < 0.2 then d.Material = M.DiamondPlate end end)

	-- lineup for review (out at sea), cleared by the next run
	local lab = workspace:FindFirstChild("VBPropLab")
	if lab then lab:Destroy() end
	lab = Instance.new("Model")
	lab.Name = "VBPropLab"
	local floor = Instance.new("Part")
	floor.Anchored = true
	floor.Size = Vector3.new(170, 1, 40)
	floor.CFrame = CFrame.new(-5200, 1.5, 200)
	floor.Material = M.Concrete
	floor.Color = C(150, 148, 142)
	floor.Parent = lab
	local x = -5280
	for _, cat in ipairs({ "Store", "Kitchen", "Jobs", "Street", "Garage", "Depot" }) do
		local f = LIB:FindFirstChild(cat)
		if f then
			for _, m in ipairs(f:GetChildren()) do
				local c = m:Clone()
				local _, s = c:GetBoundingBox()
				c:PivotTo(CFrame.new(x + s.X / 2, 2, 200))
				c.Parent = lab
				x += s.X + 2.5
			end
		end
	end
	lab.Parent = workspace
	return string.format("rebuilt %d props, muted %d, textured %d parts", #made, muted, textured)
end
