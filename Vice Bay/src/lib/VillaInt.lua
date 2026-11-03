-- Vice Bay: villa interiors. Built into a separate model (stored in ServerStorage.VBInteriors) and only
-- cloned into a house while someone owns it. Layout follows the shell from L.villa: open-plan kitchen /
-- dining / living in the main volume, guest suite or media room in the wings, master suite upstairs.
-- Mesh furniture comes from ServerStorage.VBFurniture (free Creator Store models, scripts stripped).
return function(L)
	local M, C = L.M, L.C
	local SS = game:GetService("ServerStorage")
	local WHITE, INK = C(240, 240, 236), C(24, 24, 26)
	local OAK, WALNUT = C(196, 158, 116), C(120, 82, 54)
	local FLOORS = { C(226, 204, 170), C(214, 190, 156), C(200, 180, 150), C(232, 222, 206) }
	local FLOOR = FLOORS[1]
	local COPPER, BRASS = C(186, 112, 72), C(196, 160, 96)
	local CAB = { C(132, 150, 136), C(46, 48, 50), C(214, 210, 200), C(150, 112, 78), C(70, 88, 84) }
	local FABRIC = { C(150, 170, 160), C(214, 206, 192), C(96, 100, 104), C(178, 160, 132), C(70, 84, 108), C(196, 196, 190) }
	local CURTAIN = { C(52, 78, 60), C(196, 188, 172), C(60, 62, 66), C(150, 120, 92) }

	function L.villaInterior(I, cf, v)
		local rng = v.rng
		local function pick(t) return t[rng:NextInteger(1, #t)] end
		local function rr(a, b) return a + rng:NextNumber() * (b - a) end
		local FK = SS:FindFirstChild("VBFurniture")
		local PL, uy, gfTop, UH = v.PL, v.uy, v.gfTop, v.UH
		local cabCol, fab, cur = pick(CAB), pick(FABRIC), pick(CURTAIN)
		FLOOR = pick(FLOORS)
		local lights = 0

		-- ---------------------------------------------------------------- helpers (group frame g: -Z = front)
		local function G(x, y, z, dir)
			local p = Vector3.new(x, y, z)
			return cf * CFrame.lookAt(p, p + dir)
		end
		local function B(g, x, y0, z, sx, sy, sz, col, mat, var, opt) return L.B(I, g, x, y0, z, sx, sy, sz, col, mat, var, opt) end
		local function BD(g, x, y0, z, sx, sy, sz, col, mat, var, opt) return L.BD(I, g, x, y0, z, sx, sy, sz, col, mat, var, opt) end
		local function light(part, range, bright, col)
			if lights >= 9 then return end
			lights += 1
			local pl = Instance.new("PointLight")
			pl.Range = range or 18
			pl.Brightness = bright or 0.9
			pl.Color = col or C(255, 222, 180)
			pl.Shadows = false
			pl.Parent = part
		end
		local function furn(name, g, s)
			local src = FK and FK:FindFirstChild(name)
			if not src then return nil end
			local c = src:Clone()
			if s and s ~= 1 then pcall(function() c:ScaleTo(s) end) end
			c:PivotTo(g)
			c.Parent = I
			return c
		end
		local function plant(g, x, z, s)
			s = s or 1
			L.Cyl(I, 2.2 * s, 2 * s, g * CFrame.new(x, 1.1 * s, z), pick({ C(196, 170, 120), C(110, 128, 120), C(230, 226, 218), C(52, 52, 54) }), pick({ M.Fabric, M.Concrete, M.SmoothPlastic }))
			local p = L.plant(I, (g * CFrame.new(x, 2.1 * s, z)).Position, rr(3.5, 5) * s)
			if not p then L.bush(I, (g * CFrame.new(x, 2.2 * s, z)).Position, 2.6 * s) end
		end
		local function art(g, w, h)
			local cv = L.D(I, Vector3.new(w, h, 0.2), g, C(236, 234, 228), M.Fabric)
			L.D(I, Vector3.new(w + 0.3, h + 0.3, 0.12), g * CFrame.new(0, 0, 0.08), INK, M.Wood)
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Front
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 20
			gui.LightInfluence = 1
			gui.Parent = cv
			local cols = { C(30, 30, 34), C(60, 84, 120), C(196, 120, 70), C(150, 140, 120), C(40, 70, 60) }
			for k = 1, rng:NextInteger(2, 4) do
				local f = Instance.new("Frame")
				f.BorderSizePixel = 0
				f.BackgroundColor3 = pick(cols)
				f.AnchorPoint = Vector2.new(0.5, 0.5)
				f.Position = UDim2.fromScale(rr(0.25, 0.75), rr(0.2, 0.8))
				f.Size = UDim2.fromScale(rr(0.3, 0.9), rr(0.04, 0.25))
				f.Rotation = rr(-40, 40)
				f.Parent = gui
				local gr = Instance.new("UIGradient")
				gr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.3, 0.1), NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 1) })
				gr.Parent = f
			end
		end
		local function curtain(g, w, h)
			local p = L.D(I, Vector3.new(w, h, 0.4), g, cur, M.Fabric)
			L.villaStripes(p, Enum.NormalId.Front, math.floor(w * 1.6), L.shade(cur, 0.6), 0.45, true)
			L.villaStripes(p, Enum.NormalId.Back, math.floor(w * 1.6), L.shade(cur, 0.6), 0.45, true)
		end
		local function slatWall(g, w, h, col)
			local p = L.D(I, Vector3.new(w, h, 0.5), g, col or OAK, M.WoodPlanks, "WoodPlanksOld")
			L.villaStripes(p, Enum.NormalId.Front, 19, C(40, 30, 22), 0.15, true)
			local q = L.D(I, Vector3.new(w, h, 0.45), g * CFrame.new(w / 38, 0, 0.03), col or OAK, M.WoodPlanks, "WoodPlanksOld")
			L.villaStripes(q, Enum.NormalId.Front, 19, C(40, 30, 22), 0.15, true)
		end
		local function pendant(g, x, y, z, s, lit)
			-- copper dome industrial pendant on a chain
			s = s or 1
			local top = g * CFrame.new(x, y, z)
			L.D(I, Vector3.new(0.1, 3, 0.1), top * CFrame.new(0, 1.5, 0), COPPER, M.Metal)
			L.Cyl(I, 0.8 * s, 0.9 * s, top * CFrame.new(0, -0.2, 0), COPPER, M.Metal)
			local dome = L.Cyl(I, 1.3 * s, 2.6 * s, top * CFrame.new(0, -1.2 * s, 0), COPPER, M.Metal)
			L.D(I, Vector3.new(1.6 * s, 0.1, 1.6 * s), top * CFrame.new(0, -1.9 * s, 0), C(255, 236, 200), M.Neon, nil, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 1.8 * s, 1.8 * s), CFrame = top * CFrame.new(0, -1.9 * s, 0) * CFrame.Angles(0, 0, math.pi / 2) })
			if lit then light(dome, 18, 1) end
		end
		local function books(g, x, y, z, w)
			-- a run of books standing on a shelf (few parts: blocks of 3)
			local u = x - w / 2
			while u < x + w / 2 - 0.4 do
				local bw = rr(0.5, 1.1)
				BD(g, u + bw / 2, y, z, bw, rr(1.1, 1.6), 0.9, pick({ C(160, 60, 50), C(40, 60, 90), C(220, 214, 200), C(60, 90, 70), C(30, 30, 32), C(196, 170, 120) }), M.SmoothPlastic)
				u += bw + rr(0, 0.2)
			end
		end
		local function floorLamp(g, x, z)
			L.Cyl(I, 0.2, 1.4, g * CFrame.new(x, 0.1, z), INK, M.Metal)
			L.D(I, Vector3.new(0.15, 5.6, 0.15), g * CFrame.new(x, 2.9, z), INK, M.Metal)
			local sh = L.Cyl(I, 1.6, 1.8, g * CFrame.new(x, 6.2, z), C(232, 226, 210), M.Fabric)
			light(sh, 12, 0.6)
		end
		local function floorWood(r, y, col)
			L.D(I, Vector3.new(r[2] - r[1] - 0.4, 0.08, r[4] - r[3] - 0.4), cf * CFrame.new((r[1] + r[2]) / 2, y + 0.04, (r[3] + r[4]) / 2), col or FLOOR, M.WoodPlanks)
		end
		local function ceilingStrip(x0, x1, z, y)
			local s = L.D(I, Vector3.new(x1 - x0, 0.1, 0.25), cf * CFrame.new((x0 + x1) / 2, y, z), C(255, 240, 214), M.Neon)
			return s
		end

		-- ---------------------------------------------------------------- room builders
		local function kitchen(g, len)
			-- wall run (group frame: user stands at -Z), tall pantry + ovens, mosaic backsplash, oak shelves
			B(g, 0, 0, 1.2, len, 3.2, 2.4, cabCol, M.SmoothPlastic)
			local base = I:GetChildren()[#I:GetChildren()]
			L.villaStripes(base, Enum.NormalId.Front, math.floor(len / 1.6), L.shade(cabCol, 0.7), 0.2, true)
			B(g, 0, 3.2, 1.1, len + 0.2, 0.3, 2.6, C(214, 216, 212), M.Marble, "LobbyMarble")
			BD(g, 0, 3.5, 2.35, len, 3.4, 0.1, C(104, 146, 116), M.CeramicTiles, "PlazaTiles")
			BD(g, -len * 0.22, 3.52, 1.0, 2.8, 0.06, 1.7, C(70, 72, 74), M.Metal)
			L.D(I, Vector3.new(0.18, 2, 0.18), g * CFrame.new(-len * 0.22, 4.5, 2.0), BRASS, M.Metal)
			L.D(I, Vector3.new(0.16, 0.16, 1.2), g * CFrame.new(-len * 0.22, 5.45, 1.5), BRASS, M.Metal)
			BD(g, len * 0.2, 3.52, 1.0, 2.8, 0.05, 1.9, C(14, 14, 16), M.Glass, nil, { Reflectance = 0.3 })
			for k = 0, 1 do
				BD(g, -len * 0.25, 7.2 + k * 2.2, 1.6, len * 0.42, 0.25, 1.4, OAK, M.Wood)
				for j = 0, 2 do L.Cyl(I, 0.9, 0.6, g * CFrame.new(-len * 0.4 + j * 0.9, 7.9 + k * 2.2, 1.6), pick({ C(220, 210, 190), C(180, 120, 70), WHITE }), M.Glass, nil, { Transparency = 0.2 }) end
			end
			B(g, len * 0.22, 7.2, 1.5, len * 0.5, 4.2, 1.8, cabCol, M.SmoothPlastic)
			for sd = -1, 1, 2 do
				B(g, sd * (len / 2 + 1.7), 0, 1.2, 3.2, 11.6, 2.4, cabCol, M.SmoothPlastic)
			end
			for k = 0, 1 do BD(g, len / 2 + 1.7, 4.2 + k * 2.6, -0.02, 2.5, 2.2, 0.1, C(16, 16, 18), M.Glass, nil, { Reflectance = 0.3 }) end
		end
		local function island(g, len)
			B(g, 0, 0, 0, len, 3.3, 3.6, cabCol, M.SmoothPlastic)
			B(g, 0, 3.3, 0, len + 0.3, 0.3, 4, C(206, 210, 206), M.Marble, "LobbyMarble")
			BD(g, len * 0.2, 3.62, 0.4, 2.6, 0.04, 1.8, C(14, 14, 16), M.Glass)
			local n = math.floor(len / 2.6)
			for k = 0, n - 1 do
				local sc = g * CFrame.new(-len / 2 + 1.4 + k * (len - 2.8) / math.max(1, n - 1), 0, -2.9)
				L.Cyl(I, 0.3, 1.7, sc * CFrame.new(0, 2.6, 0), C(204, 176, 120), M.Fabric)
				L.D(I, Vector3.new(1.6, 1.4, 0.2), sc * CFrame.new(0, 3.4, -0.75) * CFrame.Angles(math.rad(-8), 0, 0), C(204, 176, 120), M.Fabric)
				L.D(I, Vector3.new(0.15, 2.5, 0.15), sc * CFrame.new(0, 1.25, 0), BRASS, M.Metal)
				L.Cyl(I, 0.1, 1.3, sc * CFrame.new(0, 0.05, 0), BRASS, M.Metal)
			end
			-- book stand + bottles on the island
			L.D(I, Vector3.new(1.6, 0.2, 1.2), g * CFrame.new(-len * 0.25, 3.8, 0) * CFrame.Angles(math.rad(20), 0, 0), C(196, 180, 150), M.Wood)
			for k = 0, 1 do L.Cyl(I, 1.3, 0.35, g * CFrame.new(len * 0.35 + k * 0.5, 4.3, 0.8), C(40, 60, 40), M.Glass) end
		end
		local function dining(g, len, chairs)
			B(g, 0, 2.7, 0, len - 3.4, 0.25, 3.6, OAK, M.Wood)
			for sd = -1, 1, 2 do L.Cyl(I, 0.25, 3.6, g * CFrame.new(sd * (len / 2 - 1.7), 2.825, 0), OAK, M.Wood) end
			for sd = -1, 1, 2 do L.D(I, Vector3.new(0.3, 3.2, 0.3), g * CFrame.new(sd * 1.2, 1.35, 0) * CFrame.Angles(0, 0, sd * 0.45), INK, M.Metal) end
			local n = chairs or 3
			for k = 0, n - 1 do
				for sd = -1, 1, 2 do
					local x = -len / 2 + 2.2 + k * (len - 4.4) / math.max(1, n - 1)
					local ch = g * CFrame.new(x, 0, sd * 2.9) * CFrame.Angles(0, sd > 0 and 0 or math.pi, 0)
					L.D(I, Vector3.new(1.8, 0.3, 1.8), ch * CFrame.new(0, 1.7, 0), C(200, 176, 140), M.Wood)
					L.D(I, Vector3.new(1.6, 0.2, 1.5), ch * CFrame.new(0, 1.92, -0.05), C(150, 172, 200), M.Fabric)
					L.D(I, Vector3.new(1.8, 2.2, 0.25), ch * CFrame.new(0, 2.9, 0.85) * CFrame.Angles(math.rad(-10), 0, 0), C(200, 176, 140), M.Wood)
					for lg = -1, 1, 2 do L.D(I, Vector3.new(0.18, 1.6, 1.5), ch * CFrame.new(lg * 0.75, 0.8, 0), INK, M.Metal) end
				end
			end
			B(g, 0, 2.95, 0, 3.4, 0.4, 1.4, COPPER, M.Metal)
			L.bush(I, (g * CFrame.new(0, 3.4, 0)).Position, 1.6)
		end
		local function mediaWall(g, len, h)
			-- dark built-in shelving with a faceted oak panel behind the TV
			B(g, 0, 0, 1.0, len, h - 0.6, 0.3, C(36, 36, 38), M.Wood)
			B(g, 0, 0, 0.2, len, 2.6, 1.6, C(36, 36, 38), M.Wood)
			local pnl = L.B(I, g, 0, 2.6, 0.75, len * 0.38, h - 3.4, 0.2, C(206, 150, 76), M.Wood)
			L.villaStripes(pnl, Enum.NormalId.Front, 12, C(150, 96, 40), 0.35, true)
			L.villaStripes(pnl, Enum.NormalId.Back, 9, C(120, 80, 34), 0.5, false)
			BD(g, 0, 4.4, 0.55, len * 0.32, len * 0.18, 0.2, C(10, 10, 12), M.Glass, nil, { Reflectance = 0.35 })
			for sd = -1, 1, 2 do
				local cx = sd * len * 0.33
				for k = 0, 3 do BD(g, cx, 2.6 + k * 2.4, 0.4, len * 0.28, 0.2, 1.2, C(36, 36, 38), M.Wood) end
				BD(g, sd * len * 0.19, 2.6, 0.4, 0.25, h - 3.2, 1.2, C(36, 36, 38), M.Wood)
				for k = 0, 2 do
					if rng:NextNumber() < 0.65 then books(g, cx + rr(-1, 1), 2.8 + k * 2.4, 0.4, rr(1.6, 3))
					else L.Cyl(I, rr(0.8, 1.6), rr(0.6, 1), g * CFrame.new(cx + rr(-1.5, 1.5), 2.8 + k * 2.4 + 0.6, 0.4), pick({ C(140, 160, 150), WHITE, INK, COPPER }), M.SmoothPlastic) end
				end
				-- trailing pothos from the top shelf
				L.plant(I, (g * CFrame.new(cx + sd * 1.5, 2.8 + 3 * 2.4, 0.4)).Position, 2.4)
			end
		end
		local function bedroom(r, y, master)
			-- bed against the street-side wall facing the garden, slat wall, art, sideboard, lounge chair, plant, curtains
			local cx = (r[1] + r[2]) / 2
			local g = G(cx, y, r[3] + 0.9, Vector3.new(0, 0, 1))
			slatWall(g * CFrame.new(0, 5.6, 0), math.min(20, r[2] - r[1] - 2), 11, pick({ OAK, C(214, 190, 150) }))
			local bedName = pick({ "BedWhite", "BedLow" })
			local bed = furn(bedName, G(cx, y + 0.1, (r[3] + r[4]) / 2, Vector3.new(0, 0, 1)))
			if bed then
				local bcf, bsz = bed:GetBoundingBox()
				local zc = cf:PointToObjectSpace(bcf.Position).Z
				local shift = (r[3] + 1.4) - (zc - bsz.Z / 2)
				bed:PivotTo(bed:GetPivot() + cf:VectorToWorldSpace(Vector3.new(0, 0, shift)))
			end
			do
				for sd = -1, 1, 2 do
					local ns = G(cx + sd * 8, y, r[3] + 2.4, Vector3.new(0, 0, 1))
					B(ns, 0, 0, 0, 2.6, 2.2, 2.2, WALNUT, M.Wood)
					L.D(I, Vector3.new(1.4, 1.6, 1.4), ns * CFrame.new(0, 3, 0), BRASS, M.Metal, nil, { Transparency = 0.6 })
					local bulb = L.D(I, Vector3.new(0.6, 0.6, 0.6), ns * CFrame.new(0, 3, 0), C(255, 236, 200), M.Neon, nil, { Shape = Enum.PartType.Ball })
					if sd > 0 then light(bulb, 12, 0.5) end
				end
			end
			-- triptych above the bed
			for k = -1, 1 do art(G(cx + k * 3.6, y + 9.6, r[3] + 1.25, Vector3.new(0, 0, 1)), 3, 4.2) end
			-- rattan sideboard on a side wall, lounge chair + lamp by the glass, rug
			local sx = (rng:NextNumber() < 0.5) and (r[1] + 1.6) or (r[2] - 1.6)
			local sg = G(sx, y, (r[3] + r[4]) / 2, Vector3.new(cx - sx, 0, 0))
			local sb = L.B(I, sg, 0, 0, 0, 9, 3.4, 2.2, WALNUT, M.Wood)
			L.villaStripes(sb, Enum.NormalId.Front, 19, C(196, 160, 110), 0.5, true)
			L.Cyl(I, 1.6, 1, sg * CFrame.new(-2.5, 4.2, 0), WHITE, M.SmoothPlastic)
			plant(sg, 3.8, 0, 0.9)
			BD(G(cx, y, (r[3] + r[4]) / 2 + 2, Vector3.new(0, 0, 1)), 0, 0.1, 0, 14, 0.06, 10, pick({ C(226, 222, 214), C(150, 146, 140), C(196, 180, 160) }), M.Fabric)
			local cxn = cx + ((sx < cx) and 8 or -8)
			furn(pick({ "ChairAccent", "Arm1", "Arm2" }), G(cxn, y + 0.1, r[4] - 4, Vector3.new(cx - cxn, 0, -1)))
			floorLamp(G(cxn + ((sx < cx) and 2.6 or -2.6), y, r[4] - 2.4, Vector3.new(0, 0, 1)), 0, 0)
			for sd = -1, 1, 2 do curtain(G(cx + sd * ((r[2] - r[1]) / 2 - 1.6), y + 6, r[4] - 0.9, Vector3.new(0, 0, -1)), 2.4, 11.4) end
			if master then
				-- freestanding tub by the glass with a floor-standing copper filler
				local tg = G(sx - ((sx < cx) and -5 or 5), y, r[4] - 4.2, Vector3.new(1, 0, 0))
				B(tg, 0, 0, 0, 4, 2.2, 3.4, C(76, 98, 92), M.SmoothPlastic)
				for sd = -1, 1, 2 do L.Cyl(I, 2.2, 3.4, tg * CFrame.new(sd * 2, 1.1, 0), C(76, 98, 92), M.SmoothPlastic) end
				L.D(I, Vector3.new(5.2, 0.12, 2.6), tg * CFrame.new(0, 2.1, 0), C(150, 200, 210), M.Glass, nil, { Transparency = 0.3 })
				L.D(I, Vector3.new(0.2, 4, 0.2), tg * CFrame.new(-4.4, 2, 0), COPPER, M.Metal)
				L.D(I, Vector3.new(1.2, 0.2, 0.2), tg * CFrame.new(-3.9, 3.9, 0), COPPER, M.Metal)
			end
			local c = ceilingStrip(r[1] + 3, r[2] - 3, (r[3] + r[4]) / 2, y + (master and UH or (gfTop - PL)) - 0.2)
			light(c, 22, 0.8)
		end
		local function bathroom(r, y, partX, dirIn)
			-- partition with a door gap, walk-in shower (black grid glass), floating oak vanity, vessel sink, WC
			local h = UH
			local z0, z1 = r[3], r[4]
			L.P(I, Vector3.new(0.6, h, (z1 - z0) - 5.5), cf * CFrame.new(partX, y + h / 2, z0 + ((z1 - z0) - 5.5) / 2), C(232, 230, 224), M.Plaster, "StuccoGreyFine")
			L.P(I, Vector3.new(0.6, h - 9, 5.5), cf * CFrame.new(partX, y + 9 + (h - 9) / 2, z1 - 2.75), C(232, 230, 224), M.Plaster, "StuccoGreyFine")
			local bx = partX + dirIn * ((r[2] - r[1]) / 2)
			local bw = math.abs(r[2] - r[1])
			L.D(I, Vector3.new(bw - 1, 0.08, z1 - z0 - 1), cf * CFrame.new((partX + (partX + dirIn * bw)) / 2, y + 0.05, (z0 + z1) / 2), C(226, 228, 228), M.CeramicTiles, "PlazaTiles")
			-- shower in the street-side corner
			local sx = partX + dirIn * (bw - 4)
			L.D(I, Vector3.new(0.2, h - 1, 7), cf * CFrame.new(sx - dirIn * 3.6, y + (h - 1) / 2, z0 + 4), C(150, 170, 176), M.Glass, nil, { Transparency = 0.55 })
			for k = 0, 2 do L.D(I, Vector3.new(0.25, h - 1, 0.25), cf * CFrame.new(sx - dirIn * 3.6, y + (h - 1) / 2, z0 + 0.5 + k * 3.5), INK, M.Metal) end
			for k = 1, 2 do L.D(I, Vector3.new(0.25, 0.25, 7), cf * CFrame.new(sx - dirIn * 3.6, y + k * (h - 1) / 3, z0 + 4), INK, M.Metal) end
			L.Cyl(I, 0.15, 2.2, cf * CFrame.new(sx, y + h - 2.4, z0 + 3.5), C(120, 130, 120), M.Metal)
			L.D(I, Vector3.new(0.15, 1.6, 0.15), cf * CFrame.new(sx, y + h - 1.6, z0 + 3.5), C(120, 130, 120), M.Metal)
			L.D(I, Vector3.new(0.1, 1.6, 3), cf * CFrame.new(partX + dirIn * (bw - 0.5), y + 6, z0 + 4), C(214, 216, 214), M.CeramicTiles, "PlazaTiles")
			-- vanity on the partition
			local vg = G(partX + dirIn * 1.5, y, (z0 + z1) / 2 + 2, Vector3.new(dirIn, 0, 0))
			B(vg, 0, 2.2, 0.4, 7, 1.6, 2.2, OAK, M.Wood)
			for sd = -1, 1, 2 do
				L.Cyl(I, 0.8, 1.8, vg * CFrame.new(sd * 1.8, 4.2, 0.3), WHITE, M.SmoothPlastic)
				L.D(I, Vector3.new(0.15, 1.4, 0.15), vg * CFrame.new(sd * 1.8, 4.8, 1.3), INK, M.Metal)
				L.D(I, Vector3.new(0.12, 0.12, 0.9), vg * CFrame.new(sd * 1.8, 5.45, 0.9), INK, M.Metal)
			end
			L.D(I, Vector3.new(6.4, 4, 0.1), vg * CFrame.new(0, 7.6, 1.45), C(200, 214, 220), M.Glass, nil, { Reflectance = 0.6 })
			-- WC
			local wg = G(partX + dirIn * 1.4, y, z1 - 7.5, Vector3.new(dirIn, 0, 0))
			B(wg, 0, 1.2, 0.2, 1.8, 1.4, 2.4, WHITE, M.SmoothPlastic)
			B(wg, 0, 0, 0.6, 1.2, 1.2, 1.2, WHITE, M.SmoothPlastic)
			local c = ceilingStrip(partX + dirIn * 2, partX + dirIn * (bw - 2), (z0 + z1) / 2, y + h - 0.2)
			light(c, 16, 0.7, C(255, 244, 228))
		end
		local function office(r, y, outerX)
			local cx = (r[1] + r[2]) / 2
			local g = G(cx, y, r[4] - 4, Vector3.new(0, 0, -1))
			B(g, 0, 2.8, 0, 7, 0.25, 2.8, WALNUT, M.Wood)
			for sd = -1, 1, 2 do B(g, sd * 3.2, 0, 0, 0.3, 2.8, 2.6, INK, M.Metal) end
			BD(g, 0, 3.05, 0.7, 3.4, 2, 0.12, C(14, 14, 16), M.Glass)
			furn("ChairDesk", G(cx, y + 0.1, r[4] - 6.4, Vector3.new(0, 0, 1)))
			local ox = outerX or r[1]
			local sh = G(ox + ((ox < (r[1] + r[2]) / 2) and 1.4 or -1.4), y, (r[3] + r[4]) / 2, Vector3.new((ox < (r[1] + r[2]) / 2) and 1 or -1, 0, 0))
			B(sh, 0, 0, 0.4, 8, 9, 1.4, C(36, 36, 38), M.Wood)
			for k = 0, 2 do books(sh, rr(-2, 2), 1.2 + k * 2.8, 0.2, rr(2, 4)) end
			plant(G(r[2] - 2.4, y, r[4] - 2.4, Vector3.new(0, 0, 1)), 0, 0, 1.1)
		end
		local function living(r, y, mediaAtX1)
			local cx, cz = (r[1] + r[2]) / 2, (r[3] + r[4]) / 2
			local mx = mediaAtX1 and (r[2] - 1.2) or (r[1] + 1.2)
			local dirToRoom = Vector3.new(mediaAtX1 and -1 or 1, 0, 0)
			local mg = G(mx, y, cz, dirToRoom)
			mediaWall(mg, math.min(r[4] - r[3] - 4, 22), gfTop - PL - 0.2)
			-- sofa facing the media wall, coffee table, chairs, rug, lamp, plants
			local wid = r[2] - r[1]
			local sx = mx + dirToRoom.X * math.clamp(wid * 0.5, 10, 14)
			BD(G(sx - dirToRoom.X * 3, y, cz, dirToRoom), 0, 0.1, 0, 16, 0.06, 12, pick({ C(232, 228, 220), C(180, 176, 168), C(120, 124, 130) }), M.Fabric)
			local sofa = (wid >= 30) and pick({ "SectionalU", "SofaChaise", "LoungeLeather" }) or pick({ "SofaChaise", "SofaWalnut", "SofaLeather", "Loveseat" })
			furn(sofa, G(sx, y + 0.1, cz, -dirToRoom))
			furn("CoffeeBench", G(sx - dirToRoom.X * 5.5, y + 0.1, cz, dirToRoom))
			furn(pick({ "ChairAccent", "Arm1", "Arm2" }), G(mx + dirToRoom.X * 7, y + 0.1, cz + 7, Vector3.new(0, 0, -1)))
			furn(pick({ "SideTable" }), G(sx, y + 0.1, cz - 7.5, dirToRoom))
			floorLamp(G(sx + dirToRoom.X * 2, y, cz + 8, dirToRoom), 0, 0)
			plant(G(mx + dirToRoom.X * 2, y, r[4] - 2.5, dirToRoom), 0, 0, 1.5)
			plant(G(mx + dirToRoom.X * 2, y, r[3] + 7.5, dirToRoom), 0, 0, 1.2)
			curtain(G(r[2] - 2, y + PL + 5.6, r[4] - 0.9, Vector3.new(0, 0, -1)), 2.6, 11.2)
			curtain(G(r[1] + 2, y + PL + 5.6, r[4] - 0.9, Vector3.new(0, 0, -1)), 2.6, 11.2)
			art(G((r[1] + r[2]) / 2, y + 7.5, r[3] + 0.95, Vector3.new(0, 0, 1)), 6, 4)
			local c = ceilingStrip(r[1] + 3, r[2] - 3, cz, gfTop - 0.2)
			light(c, 26, 0.9)
		end

		-- ---------------------------------------------------------------- lay out the house
		local main, gar = v.main, v.gar
		for _, r in ipairs(v.GF) do floorWood(r, PL + 0.06) end
		for _, r in ipairs(v.UF) do floorWood(r, uy) end
		-- garage: epoxy floor, shelving, ceiling strips
		do
			local gz1 = gar[3] + v.garDepth
			L.D(I, Vector3.new(v.gx1 - v.gx0, 0.1, v.garDepth), cf * CFrame.new((v.gx0 + v.gx1) / 2, PL + 0.16, gar[3] + v.garDepth / 2), C(120, 124, 128), M.SmoothPlastic, nil, { Reflectance = 0.1 })
			local sg = G((v.gx0 + v.gx1) / 2, PL, gz1 - 1.2, Vector3.new(0, 0, -1))
			B(sg, 0, 0, 0, v.gx1 - v.gx0 - 4, 8, 1.6, C(60, 62, 66), M.Metal)
			for k = 0, 1 do ceilingStrip(v.gx0 + 2, v.gx1 - 2, gar[3] + 6 + k * 10, gfTop - 0.2) end
		end
		-- main volume: kitchen at the garage end, dining in the middle by the glass, living at the stair end
		local fx0, fx1 = main[1] + 0.8, main[2] - 0.8
		if gar == main then
			if v.gside < 0 then fx0 = v.gx1 + 1.2 else fx1 = v.gx0 - 1.2 end
		end
		local span = fx1 - fx0
		local kitAtLow = v.gside < 0
		local kLen = math.clamp(span * 0.34, 14, 22)
		local kx0, kx1
		if kitAtLow then kx0, kx1 = fx0, fx0 + kLen else kx0, kx1 = fx1 - kLen, fx1 end
		local depth = main[4] - main[3]
		local runLen = math.clamp(depth - 12, 10, 18)
		-- kitchen run along the side wall (faces into the room), island parallel to it
		local kwx = kitAtLow and (kx0 + 1.4) or (kx1 - 1.4)
		local inward = Vector3.new(kitAtLow and 1 or -1, 0, 0)
		kitchen(G(kwx + inward.X * 1.2, PL + 0.14, main[3] + 2.5 + runLen / 2 + 1.8, -inward) * CFrame.new(0, 0, 2.4), runLen)
		local isl = G(kwx + inward.X * 10, PL + 0.14, main[3] + 2.5 + runLen / 2 + 1.8, -inward)
		island(isl, math.min(runLen - 2, 11))
		for k = -1, 1 do pendant(isl, k * 3.2, gfTop - PL - 4, 0, 1, k == 0) end
		-- dining toward the garden glass
		local dx = kitAtLow and (kx1 + 6) or (kx0 - 6)
		if math.abs(dx - (kitAtLow and fx1 or fx0)) > 14 then
			local dg = G(dx, PL + 0.14, main[4] - 7, Vector3.new(1, 0, 0))
			dining(dg, 10, 3)
			for k = -1, 1, 2 do pendant(dg, k * 2.6, gfTop - PL - 3.6, 0, 0.9, k > 0) end
		end
		-- living at the far end
		local lx0, lx1
		if kitAtLow then lx0, lx1 = kx1 + 12, fx1 else lx0, lx1 = fx0, kx0 - 12 end
		if lx1 - lx0 > 18 then living({ lx0, lx1, math.max(main[3], v.sz1 + 1), main[4] }, PL + 0.14, kitAtLow) end
		-- other ground-floor volumes: guest suite or media lounge
		for _, r in ipairs(v.GF) do
			if r ~= main then
				local rr2 = { r[1] + 0.8, r[2] - 0.8, r[3] + 0.8, r[4] - 0.8 }
				if r == gar then
					if v.gside < 0 then rr2[1] = v.gx1 + 1.2 else rr2[2] = v.gx0 - 1.2 end
					rr2[3] = math.max(rr2[3], gar[3] + v.garDepth + 1)
				end
				if rr2[2] - rr2[1] > 14 and rr2[4] - rr2[3] > 14 then
					if rng:NextNumber() < 0.6 then bedroom(rr2, PL + 0.14, false) else living(rr2, PL + 0.14, rng:NextNumber() < 0.5) end
				end
			end
		end
		-- upper floor: landing + office at the stair top, master bedroom in the middle, bath at the far end
		local u = v.UF[1]
		if u then
			local ux0, ux1 = u[1] + 0.8, u[2] - 0.8
			local stairTopAtHigh = v.sDir > 0 -- stair rises toward +x
			local bathW = 13
			local bathR, bedR, offR
			if stairTopAtHigh then
				bathR = { ux0, ux0 + bathW, u[3] + 0.8, u[4] - 0.8 }
				offR = { ux1 - 16, ux1, v.sz1 + 1.5, u[4] - 0.8 }
				bedR = { ux0 + bathW + 0.6, ux1 - 16.5, u[3] + 0.8, u[4] - 0.8 }
				bathroom(bathR, uy, ux0 + bathW, -1)
			else
				bathR = { ux1 - bathW, ux1, u[3] + 0.8, u[4] - 0.8 }
				offR = { ux0, ux0 + 16, v.sz1 + 1.5, u[4] - 0.8 }
				bedR = { ux0 + 16.5, ux1 - bathW - 0.6, u[3] + 0.8, u[4] - 0.8 }
				bathroom(bathR, uy, ux1 - bathW, 1)
			end
			if bedR[2] - bedR[1] > 20 then
				bedroom(bedR, uy, true)
				office(offR, uy, stairTopAtHigh and offR[2] or offR[1])
			else
				bedroom({ math.min(bedR[1], offR[1]), math.max(bedR[2], offR[2]), bedR[3], bedR[4] }, uy, true)
			end
		end
		return I
	end
end
