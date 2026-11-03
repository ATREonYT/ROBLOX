-- Swaps every Workspace.ViceBay.Buildings.Hood "Shops" model for a new-style hood shop sized to the same lot
-- (the look of MTL_BuildingLab.MTL_ShopStrip: bays with roll-up shutters / barred glass fronts, rusty boxes over
-- each bay, AC units with rust drips, painted-brick piers, grime decal). Originals go to
-- ServerStorage.MTL_ReplacedBuildings.Hood (attribute MTL_OriginalParent), so they can be put back.
-- The biggest lot gets the lab corner store instead.
local SS = game:GetService("ServerStorage")
local hood = workspace.ViceBay.Buildings.Hood
local GRIME = "rbxassetid://100588449546910"
local C = Color3.fromRGB
local M = Enum.Material

local store = SS:FindFirstChild("MTL_ReplacedBuildings") or Instance.new("Folder")
store.Name = "MTL_ReplacedBuildings"
store.Parent = SS
local keep = store:FindFirstChild("Hood") or Instance.new("Folder")
keep.Name = "Hood"
keep.Parent = store

local STEEL = C(38, 38, 40)
local ALU = C(150, 153, 157)
local TRIM = C(188, 184, 176)
local T = 1

local PALETTES = {
	{ color = C(150, 182, 204), mat = M.Plaster, variant = "HoodStuccoCracked", cap = C(132, 160, 180) },
	{ color = C(140, 170, 140), mat = M.Plaster, variant = "HoodStuccoCracked", cap = C(118, 146, 118) },
	{ color = C(222, 218, 206), mat = M.Plaster, variant = "HoodStuccoCracked", cap = TRIM },
	{ color = C(222, 176, 164), mat = M.Plaster, variant = "HoodStuccoCracked", cap = C(196, 150, 140) },
	{ color = C(226, 212, 172), mat = M.Plaster, variant = "HoodStuccoCracked", cap = C(198, 184, 146) },
	{ color = C(190, 186, 176), mat = M.Concrete, variant = "HoodCinderBlock", cap = TRIM },
	{ color = C(168, 168, 172), mat = M.Brick, variant = "HoodPaintedBrick", cap = TRIM },
	{ color = C(184, 92, 72), mat = M.Brick, variant = "HoodPaintedBrick", cap = C(186, 182, 174) },
}
local NAMES = { "CORNER MART", "PHONE REPAIR", "WIRELESS", "BEAUTY SUPPLY", "LIQUOR", "CHECKS CASHED", "TACOS",
	"LAUNDROMAT", "FISH MARKET", "TIRE SHOP", "BARBER", "99¢ STORE", "PAWN", "WINGS", "BOTANICA", "TAX PREP" }
local SIGNCOLORS = {
	{ C(255, 255, 255), C(30, 80, 160) }, { C(250, 250, 250), C(150, 30, 30) }, { C(30, 30, 30), C(245, 210, 60) },
	{ C(255, 255, 255), C(30, 120, 70) }, { C(255, 240, 200), C(60, 40, 90) },
}

local function signText(m: Instance): string?
	for _, d in m:GetDescendants() do
		if d:IsA("TextLabel") and #d.Text > 2 and d.Text:upper() == d.Text then
			return d.Text
		end
	end
	return nil
end

local function build(lot: Model, seed: number)
	local rng = Random.new(seed)
	local fp = lot:FindFirstChild("Footprint") :: BasePart
	local piv = lot:GetPivot()
	local ground = fp.Position.Y + fp.Size.Y / 2
	local B = CFrame.new(fp.Position.X, ground, fp.Position.Z) * piv.Rotation
	local W = math.floor(fp.Size.X - 2)
	local D = math.min(fp.Size.Z - 8, 36)
	local zf = -fp.Size.Z / 2 + 2.5
	local FW = B * CFrame.new(0, 0, zf) * CFrame.Angles(0, math.pi, 0) -- +Z = out to the street
	local function at(u, v, z) return FW * CFrame.new(u, v, z) end

	local look = PALETTES[rng:NextInteger(1, #PALETTES)]
	-- shop archetype: changes the front treatment so neighbours read as clearly different places
	local TYPES = { "rust", "awning", "tiled", "bigsign", "mural", "rust", "awning" }
	local kindOf = TYPES[rng:NextInteger(1, #TYPES)]
	local twoStorey = rng:NextNumber() < 0.4
	local H = if twoStorey then rng:NextInteger(24, 28) else rng:NextInteger(15, 20)
	local AWNING = { { C(200, 40, 40), C(240, 240, 236) }, { C(30, 110, 70), C(240, 240, 236) }, { C(30, 70, 150), C(250, 250, 246) }, { C(230, 170, 30), C(60, 40, 30) } }
	local awn = AWNING[rng:NextInteger(1, #AWNING)]
	local tileColor = Color3.fromHSV(rng:NextNumber(), 0.4, 0.6)
	if kindOf == "mural" and twoStorey then kindOf = "bigsign" end

	local model = Instance.new("Model")
	model.Name = "Shops"
	model:SetAttribute("MTL_Style", "HoodShopV2")
	local n = 0
	local function P(name, size, cf, color, mat, variant, opts)
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
		if opts then for k, v in pairs(opts) do if k == "shape" then p.Shape = v else p[k] = v end end end
		p.Parent = model
		n += 1
		return p
	end
	local function noCol(p) p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; return p end

	-- footprint pad (keeps the lot's ground) + floor
	local pad = fp:Clone()
	pad.Parent = model
	P("Floor", Vector3.new(W - 2, 0.4, D - 2), at(0, 0.2, -D / 2), C(120, 118, 112), M.Concrete)

	-- bays
	local PIER = 1.4
	local nb = math.max(1, math.floor(W / 13))
	local bw = (W - (nb + 1) * PIER) / nb
	local holes = {}
	local bays = {}
	for i = 1, nb do
		local u0 = -W / 2 + PIER + (i - 1) * (bw + PIER)
		local u1 = u0 + bw
		local r = rng:NextNumber()
		local kind = if r < 0.45 then "shutter" elseif r < 0.8 then "glass" else "door"
		local top = 9.4
		table.insert(bays, { u0 = u0, u1 = u1, kind = kind, top = top })
		if kind == "door" then
			local dw = math.min(4.5, bw * 0.4)
			table.insert(holes, { u0 + 0.8, u0 + 0.8 + dw, 0, 8.6 })
			table.insert(holes, { u0 + 1.8 + dw, u1 - 0.8, 3, 8.6 })
		elseif kind == "glass" then
			local dw = math.min(4.5, bw * 0.35)
			table.insert(holes, { u0 + 0.5, u0 + 0.5 + dw, 0, 9 })
			table.insert(holes, { u0 + 1.4 + dw, u1 - 0.5, 2.5, 9 })
		else
			table.insert(holes, { u0 + 0.4, u1 - 0.4, 0, top })
		end
	end
	local upper = {}
	if twoStorey then
		local nw = math.max(2, math.floor(W / 11))
		for i = 1, nw do
			local u = -W / 2 + W * (i - 0.5) / nw
			table.insert(upper, { u - 2.5, u + 2.5, 15.5, 21 })
		end
	end
	for _, h in upper do table.insert(holes, h) end

	-- front wall around the openings
	local lo, hi = H, 0
	for _, h in holes do lo = math.min(lo, h[3]); hi = math.max(hi, h[4]) end
	local function piece(a, b, c, d)
		if b - a > 0.01 and d - c > 0.01 then
			P("Wall", Vector3.new(b - a, d - c, T), at((a + b) / 2, (c + d) / 2, -T / 2), look.color, look.mat, look.variant)
		end
	end
	piece(-W / 2, W / 2, 0, lo)
	piece(-W / 2, W / 2, hi, H)
	local xs = { -W / 2, W / 2 }
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
	-- sides, back, roof, coping, plinth
	P("Back", Vector3.new(W, H, T), at(0, H / 2, -D + T / 2), look.color, look.mat, look.variant)
	P("Side", Vector3.new(T, H, D - 2 * T), at(-W / 2 + T / 2, H / 2, -D / 2), look.color, look.mat, look.variant)
	P("Side", Vector3.new(T, H, D - 2 * T), at(W / 2 - T / 2, H / 2, -D / 2), look.color, look.mat, look.variant)
	P("Roof", Vector3.new(W - 2, 0.6, D - 2), at(0, H - 2.6, -D / 2), C(96, 94, 92), M.Asphalt)
	P("Coping", Vector3.new(W + 0.4, 0.4, 1.6), at(0, H + 0.2, -0.5), look.cap, M.Concrete)
	P("CopingBack", Vector3.new(W + 0.4, 0.4, 1.2), at(0, H + 0.2, -D + 0.6), look.cap, M.Concrete)
	P("CopingSide", Vector3.new(1.2, 0.4, D), at(-W / 2 + 0.6, H + 0.2, -D / 2), look.cap, M.Concrete)
	P("CopingSide", Vector3.new(1.2, 0.4, D), at(W / 2 - 0.6, H + 0.2, -D / 2), look.cap, M.Concrete)
	P("Plinth", Vector3.new(W, 1.1, 0.25), at(0, 0.55, 0.1), C(62, 60, 58), M.Concrete)
	if twoStorey then
		P("StringCourse", Vector3.new(W + 0.4, 0.6, 0.4), at(0, 13.4, 0.2), look.cap, M.Concrete)
	end
	if rng:NextNumber() < 0.35 then -- mission-style stepped crown
		for i, s in { { 0.45, 1.2 }, { 0.28, 2.4 } } do
			P("Crown", Vector3.new(W * s[1], 1.2, 1), at(0, H + s[2] - 0.6, -0.5), look.color, look.mat, look.variant)
			P("CrownCap", Vector3.new(W * s[1] + 0.4, 0.3, 1.4), at(0, H + s[2] + 0.15, -0.5), look.cap, M.Concrete)
		end
	end

	-- piers between bays
	for i = 0, nb do
		local u = -W / 2 + PIER / 2 + i * (bw + PIER)
		if kindOf == "tiled" then
			P("Pier", Vector3.new(PIER + 0.2, 12.4, 0.8), at(u, 6.8, 0.3), tileColor, M.CeramicTiles)
		else
			P("Pier", Vector3.new(PIER, 12.4, 0.7), at(u, 6.8, 0.3), C(196, 192, 184), M.Brick, "HoodPaintedBrick")
		end
		P("PierBase", Vector3.new(PIER + 0.3, 1.2, 0.95), at(u, 0.6, 0.42), C(78, 76, 72), M.Concrete)
	end

	-- bay fronts
	local glassBays = {}
	for _, b in bays do
		local w, u = b.u1 - b.u0, (b.u0 + b.u1) / 2
		if b.kind == "shutter" then
			local open = if rng:NextNumber() < 0.3 then 3 else 0
			local sw = w - 0.8
			P("Shutter", Vector3.new(sw, b.top - open, 0.2), at(u, (b.top + open) / 2, -0.45),
				if rng:NextNumber() < 0.3 then C(92, 124, 116) else C(112, 120, 132), M.Metal)
			local sh = model:GetChildren()[#model:GetChildren()] :: BasePart
			local slats = Instance.new("SurfaceGui"); slats.Face = Enum.NormalId.Back; slats.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; slats.PixelsPerStud = 10; slats.LightInfluence = 1; slats.Parent = sh
			local ns = math.floor(sh.Size.Y / 0.55)
			for j = 0, ns do
				local f = Instance.new("Frame"); f.BorderSizePixel = 0; f.BackgroundColor3 = C(40, 44, 50); f.BackgroundTransparency = 0.15; f.Position = UDim2.new(0, 0, j / ns, 0); f.Size = UDim2.new(1, 0, 0, 2); f.Parent = slats
				local hl = Instance.new("Frame"); hl.BorderSizePixel = 0; hl.BackgroundColor3 = C(200, 206, 214); hl.BackgroundTransparency = 0.55; hl.Position = UDim2.new(0, 0, j / ns, 2); hl.Size = UDim2.new(1, 0, 0, 1); hl.Parent = slats
			end
			P("BottomBar", Vector3.new(sw, 0.3, 0.35), at(u, open + 0.15, -0.42), C(70, 66, 60), M.Metal)
			P("Guide", Vector3.new(0.3, b.top, 0.4), at(u - sw / 2 + 0.15, b.top / 2, -0.3), STEEL, M.Metal)
			P("Guide", Vector3.new(0.3, b.top, 0.4), at(u + sw / 2 - 0.15, b.top / 2, -0.3), STEEL, M.Metal)
			if open > 0 then P("Dark", Vector3.new(sw, open + 0.4, 4), at(u, open / 2, -3), C(16, 16, 18), M.SmoothPlastic) end
		else
			local dw = if b.kind == "glass" then math.min(4.5, w * 0.35) else math.min(4.5, w * 0.4)
			local d0 = b.u0 + (if b.kind == "glass" then 0.5 else 0.8)
			local g0, g1 = d0 + dw + (if b.kind == "glass" then 0.9 else 1.0), b.u1 - (if b.kind == "glass" then 0.5 else 0.8)
			local gb = if b.kind == "glass" then 2.5 else 3
			local gt = if b.kind == "glass" then 9 else 8.6
			-- door
			P("Door", Vector3.new(dw, gt, 0.15), at(d0 + dw / 2, gt / 2, -0.6),
				if b.kind == "glass" then C(60, 78, 86) else C(70, 74, 80),
				if b.kind == "glass" then M.Glass else M.Metal, nil, { Transparency = if b.kind == "glass" then 0.5 else 0 })
			P("DoorHead", Vector3.new(dw + 0.6, 0.5, 0.6), at(d0 + dw / 2, gt + 0.25, 0.25), C(60, 60, 62), M.Metal)
			-- window
			local gw = g1 - g0
			P("Glass", Vector3.new(gw, gt - gb, 0.1), at((g0 + g1) / 2, (gb + gt) / 2, -0.6), C(60, 78, 86), M.Glass, nil, { Transparency = 0.55, Reflectance = 0.1 })
			P("Sill", Vector3.new(gw + 0.6, 0.4, 1), at((g0 + g1) / 2, gb - 0.2, -0.1), TRIM, M.Concrete)
			P("Inside", Vector3.new(gw + dw + 1, gt, 0.3), at(u, gt / 2, -6), if b.kind == "glass" then C(232, 226, 210) else C(36, 36, 40), M.SmoothPlastic)
			-- bars over the window
			local nbar = math.floor(gw / 0.7)
			for k = 0, nbar do noCol(P("Bar", Vector3.new(0.12, gt - gb, 0.12), at(g0 + gw * k / nbar, (gb + gt) / 2, 0.25), STEEL, M.Metal)) end
			P("BarRail", Vector3.new(gw + 0.3, 0.18, 0.18), at((g0 + g1) / 2, gb + 0.1, 0.25), STEEL, M.Metal)
			P("BarRail", Vector3.new(gw + 0.3, 0.18, 0.18), at((g0 + g1) / 2, gt - 0.1, 0.25), STEEL, M.Metal)
			if b.kind == "glass" then
				table.insert(glassBays, b)
				-- stocked shelves + light
				for k = 0, math.floor(gw / 3) - 1 do
					P("Rack", Vector3.new(2.2, 4.5, 1.2), at(g0 + 1.4 + k * 3, 2.4, -4.5), C(80, 82, 88), M.Metal)
					noCol(P("Goods", Vector3.new(1.8, 2.6, 0.3), at(g0 + 1.4 + k * 3, 3, -3.8),
						Color3.fromHSV(rng:NextNumber(), 0.6, 0.85), M.SmoothPlastic))
				end
				local tube = P("Tube", Vector3.new(math.max(2, gw * 0.6), 0.2, 0.4), at((g0 + g1) / 2, gt + 0.6, -3.5), C(245, 250, 255), M.Neon)
				local pl = Instance.new("PointLight")
				pl.Color = C(235, 240, 255); pl.Brightness = 2; pl.Range = 12; pl.Shadows = false; pl.Parent = tube
			end
		end
		if kindOf == "awning" then
			-- striped fabric awning sloping out over the bay
			local stripes = math.max(3, math.floor(w / 1.4))
			for k = 0, stripes - 1 do
				local su = b.u0 + (k + 0.5) * w / stripes
				P("Awning", Vector3.new(w / stripes, 0.15, 3.4), at(su, 10.9, 1.5) * CFrame.Angles(math.rad(-22), 0, 0), if k % 2 == 0 then awn[1] else awn[2], M.Fabric)
			end
			P("AwningValance", Vector3.new(w, 0.7, 0.12), at(u, 9.95, 3.1), awn[1], M.Fabric)
		elseif kindOf == "tiled" then
			-- clean metal fascia + tiled kick band under the windows
			P("Fascia", Vector3.new(w + 0.4, 1.8, 0.5), at(u, 10.5, 0.25), C(60, 62, 68), M.Metal)
		else
			-- rusty box over the bay
			P("RustBox", Vector3.new(w + 0.4, 1.9, 0.8), at(u, 10.5, 0.4), C(132, 80, 48), M.CorrodedMetal)
			P("RustBoxTop", Vector3.new(w + 0.5, 0.18, 0.9), at(u, 11.5, 0.42), C(70, 50, 38), M.Metal)
		end
	end

	-- sign over the first glass bay (keeps the old shop's name when it had one)
	local sb = glassBays[1] or bays[1]
	local text = signText(lot) or NAMES[rng:NextInteger(1, #NAMES)]
	local sc = SIGNCOLORS[rng:NextInteger(1, #SIGNCOLORS)]
	local sw = math.min(sb.u1 - sb.u0, 14)
	local sign = P("Sign", Vector3.new(sw, 1.8, 0.25), at((sb.u0 + sb.u1) / 2, 12.6, 0.15), sc[2], M.SmoothPlastic)
	do
		local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Back; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 40; sg.LightInfluence = 1; sg.Parent = sign
		local t = Instance.new("TextLabel"); t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1; t.Text = text; t.TextColor3 = sc[1]; t.Font = Enum.Font.GothamBlack; t.TextScaled = true; t.Parent = sg
		local pad2 = Instance.new("UIPadding"); pad2.PaddingLeft = UDim.new(0.04, 0); pad2.PaddingRight = UDim.new(0.04, 0); pad2.PaddingTop = UDim.new(0.1, 0); pad2.PaddingBottom = UDim.new(0.1, 0); pad2.Parent = t
		local l = Instance.new("PointLight"); l.Range = 7; l.Brightness = 0.9; l.Color = sc[2]:Lerp(Color3.new(1, 1, 1), 0.4); l.Parent = sign
	end

	if kindOf == "bigsign" then
		-- tall rooftop sign on posts
		local bw2 = math.min(W * 0.6, 20)
		local post = H + 1
		for _, du in { -bw2 / 2 + 1, bw2 / 2 - 1 } do
			P("SignPost", Vector3.new(0.5, 6, 0.5), at(du, post + 3, -3), STEEL, M.Metal)
		end
		local big = P("RoofSign", Vector3.new(bw2, 4, 0.4), at(0, post + 6.5, -3), sc[2], M.SmoothPlastic)
		local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Back; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 25; sg.LightInfluence = 1; sg.Parent = big
		local t = Instance.new("TextLabel"); t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1; t.Text = text; t.TextColor3 = sc[1]; t.Font = Enum.Font.GothamBlack; t.TextScaled = true; t.Parent = sg
		local l = Instance.new("PointLight"); l.Range = 14; l.Brightness = 1.2; l.Color = sc[2]:Lerp(Color3.new(1, 1, 1), 0.5); l.Parent = big
	elseif kindOf == "mural" then
		-- painted mural band across the upper wall
		local mh = math.min(H - 12.4, 8)
		if mh > 2 then
			local mp = P("Mural", Vector3.new(W - 3, mh, 0.05), at(0, 12.4 + mh / 2 + (H - 12.4 - mh) / 2, 0.04), C(255, 255, 255), M.SmoothPlastic, nil, { Transparency = 1, CanCollide = false })
			local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Back; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 20; sg.LightInfluence = 1; sg.Parent = mp
			local bg = Instance.new("Frame"); bg.Size = UDim2.fromScale(1, 1); bg.BorderSizePixel = 0; bg.Parent = sg
			local h0 = rng:NextNumber()
			local gr = Instance.new("UIGradient"); gr.Rotation = rng:NextInteger(0, 60)
			gr.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHSV(h0, 0.7, 0.95)), ColorSequenceKeypoint.new(0.5, Color3.fromHSV((h0 + 0.15) % 1, 0.75, 0.9)), ColorSequenceKeypoint.new(1, Color3.fromHSV((h0 + 0.35) % 1, 0.7, 0.85)) }); gr.Parent = bg
			local t = Instance.new("TextLabel"); t.Size = UDim2.fromScale(0.9, 0.8); t.Position = UDim2.fromScale(0.05, 0.1); t.BackgroundTransparency = 1
			t.Text = ({ "305 FOREVER", "STAY UP", "NORTH SIDE", "LIL HAITI", "NO DAYS OFF", "MIAMI MADE" })[rng:NextInteger(1, 6)]
			t.Font = Enum.Font.PermanentMarker; t.TextScaled = true; t.TextColor3 = C(255, 248, 210); t.TextStrokeTransparency = 0; t.TextStrokeColor3 = C(20, 14, 30); t.Rotation = rng:NextInteger(-5, 5); t.Parent = bg
		end
	end

	-- upper windows
	for i, h in upper do
		local u, w, v0, hh = (h[1] + h[2]) / 2, h[2] - h[1], h[3], h[4] - h[3]
		local lit = rng:NextNumber() < 0.35
		P("Room", Vector3.new(w, hh, 0.1), at(u, v0 + hh / 2, -0.98), if lit then C(236, 196, 140) else C(28, 28, 32), if lit then M.Fabric else M.SmoothPlastic)
		noCol(P("WinGlass", Vector3.new(w, hh, 0.08), at(u, v0 + hh / 2, -0.7), C(52, 70, 80), M.Glass, nil, { Transparency = if lit then 0.7 else 0.45, Reflectance = 0.12 }))
		P("Frame", Vector3.new(w, 0.22, 0.3), at(u, v0 + 0.11, -0.65), ALU, M.Metal)
		P("Frame", Vector3.new(w, 0.22, 0.3), at(u, v0 + hh - 0.11, -0.65), ALU, M.Metal)
		P("Mullion", Vector3.new(0.22, hh, 0.2), at(u, v0 + hh / 2, -0.65), ALU, M.Metal)
		P("Sill", Vector3.new(w + 0.8, 0.35, 0.9), at(u, v0 - 0.17, -0.15), TRIM, M.Concrete)
		if rng:NextNumber() < 0.6 then
			local k = math.floor(w / 0.75)
			for j = 0, k do noCol(P("Bar", Vector3.new(0.12, hh, 0.12), at(u - w / 2 + w * j / k, v0 + hh / 2, 0.32), STEEL, M.Metal)) end
		end
		if lit then
			local s = noCol(P("LightSrc", Vector3.new(0.2, 0.2, 0.2), at(u, v0 + hh * 0.6, -0.8), C(0, 0, 0), M.SmoothPlastic, nil, { Transparency = 1 }))
			local l = Instance.new("PointLight"); l.Color = C(255, 196, 130); l.Brightness = 5; l.Range = 5; l.Shadows = false; l.Parent = s
		end
	end

	-- AC condensers (rust-brown side panel, drip below)
	local acV = if twoStorey then 18 else 13.2
	for k = 1, if kindOf == "mural" then 0 else rng:NextInteger(1, math.max(1, math.min(3, nb + 1))) do
		local u = -W / 2 + W * (k - 0.5) / (math.max(1, math.min(3, nb + 1))) + rng:NextNumber(-1.5, 1.5)
		if twoStorey then u = -W / 2 + W * rng:NextNumber(0.15, 0.85) end
		P("ACBody", Vector3.new(3, 2.3, 1.3), at(u, acV, 0.85), C(206, 204, 196), M.Metal)
		P("ACRust", Vector3.new(0.9, 2.3, 0.05), at(u - 1.05, acV, 1.52), C(122, 74, 44), M.CorrodedMetal)
		P("ACFan", Vector3.new(0.08, 1.85, 1.85), at(u + 0.35, acV, 1.52) * CFrame.Angles(0, math.pi / 2, 0), C(42, 42, 44), M.Metal, nil, { shape = Enum.PartType.Cylinder })
		P("ACDrip", Vector3.new(1.2, 2, 0.04), at(u - 0.5, acV - 2.2, 0.02), C(150, 96, 60), M.CorrodedMetal, nil, { Transparency = 0.3 })
	end
	-- roof unit
	P("RoofUnit", Vector3.new(4, 2.2, 3), at(rng:NextNumber(-W / 4, W / 4), H - 2.3 + 1.1, -D * 0.6), C(190, 190, 186), M.Metal)

	-- grime decal on the facade and sides (shows once the image is shared with the experience)
	for _, f in {
		{ at(0, H / 2, 0.06), W, H },
	} do
		local g = Instance.new("Part")
		g.Name = "Grime"; g.Anchored = true; g.CanCollide = false; g.CanQuery = false; g.CanTouch = false; g.CastShadow = false
		g.Transparency = 1; g.Size = Vector3.new(f[2], f[3], 0.05); g.CFrame = f[1]; g.Parent = model
		local d = Instance.new("Decal"); d.Texture = GRIME; d.Face = Enum.NormalId.Back; d.Transparency = 0.35; d.Parent = g
	end
	return model, n
end

-- ModuleScript API: Swap.lots() -> the old shops still in the map; Swap.swap(lot, seed) -> builds the new shop,
-- parents it where the old one was and moves the old one to storage.
local Swap = {}

function Swap.lots(): { Model }
	local lots = {}
	for _, m in hood:GetChildren() do
		if m.Name == "Shops" and m:IsA("Model") and m:FindFirstChild("Footprint") and m:GetAttribute("MTL_Style") ~= "HoodShopV2" then
			table.insert(lots, m)
		end
	end
	return lots
end

function Swap.swap(lot: Model, seed: number): number
	local model, n = build(lot, seed)
	model:SetAttribute("MTL_ReplacedOriginal", lot:GetFullName())
	lot:SetAttribute("MTL_OriginalParent", lot.Parent:GetFullName())
	lot.Parent = keep
	model.Parent = hood
	return n
end

return Swap
