-- Vice Bay: villa composer. Every luxury house is put together from a SHAPE (how the volumes are stacked)
-- and a FINISH (palette of materials), so no two look the same.
-- Workspace only gets the shell (walls, glass with blinds, slabs, stairs, garden, dock).
-- The furnished interior is built into ServerStorage.VBInteriors/<HouseId> and is only cloned into the
-- house while it is claimed (house attribute Owner ~= ""). See ServerScriptService.VBHouseInteriors.
-- Lot frame: cf at lot centre on the ground, local -Z = street, +Z = garden / water.
return function(L)
	local M, C = L.M, L.C
	local SS = game:GetService("ServerStorage")
	local CS = game:GetService("CollectionService")
	local WHITE, INK = C(240, 240, 236), C(24, 24, 26)
	local GH, UH, PL = 13, 12, 1
	for k, v in pairs({ StoneFieldLight = { "Cobblestone", 10 }, StoneDark = { "Cobblestone", 10 }, PaverLargeGrey = { "CorrodedMetal", 10 } }) do
		L.VARS[k] = v
	end
	local function S(col, mat, var) return { col = col, mat = mat, var = var } end

	-- ===================================================================== finishes
	local PAL = {
		stone = { gf = S(C(234, 228, 216), M.Cobblestone, "StoneFieldLight"), uf = S(C(240, 238, 233), M.SmoothPlastic), slab = S(C(244, 243, 239), M.SmoothPlastic),
			pier = S(C(234, 228, 216), M.Cobblestone, "StoneFieldLight"), frame = C(30, 30, 32), blind = C(56, 58, 62), door = S(C(56, 48, 44), M.WoodPlanks, "SidingBlack"),
			garage = S(C(184, 146, 100), M.WoodPlanks, "WoodPlanksOld"), solar = true },
		darkstone = { gf = S(C(160, 158, 156), M.Cobblestone, "StoneDark"), uf = S(C(206, 206, 204), M.Concrete, "ConcretePlain"), slab = S(C(222, 222, 220), M.Concrete, "ConcretePlain"),
			pier = S(C(160, 158, 156), M.Cobblestone, "StoneDark"), frame = INK, blind = C(38, 40, 44), door = S(C(40, 38, 38), M.WoodPlanks, "SidingBlack"),
			garage = S(C(60, 60, 62), M.WoodPlanks, "SidingBlack"), solar = true },
		stucco = { gf = S(C(242, 240, 235), M.SmoothPlastic), uf = S(C(242, 240, 235), M.SmoothPlastic), slab = S(C(246, 245, 241), M.SmoothPlastic),
			pier = S(C(222, 212, 196), M.Cobblestone), frame = C(44, 44, 46), blind = C(214, 210, 200), door = S(C(158, 116, 78), M.WoodPlanks, "WoodPlanksOld"),
			garage = S(C(168, 126, 84), M.WoodPlanks, "WoodPlanksOld"), solar = false },
		black = { gf = S(C(46, 46, 48), M.WoodPlanks, "SidingBlack"), uf = S(C(46, 46, 48), M.WoodPlanks, "SidingBlack"), slab = S(C(236, 234, 229), M.SmoothPlastic),
			pier = S(C(178, 136, 92), M.WoodPlanks, "WoodPlanksOld"), frame = INK, blind = C(34, 34, 36), door = S(C(178, 136, 92), M.WoodPlanks, "WoodPlanksOld"),
			garage = S(C(178, 136, 92), M.WoodPlanks, "WoodPlanksOld"), solar = true },
		concrete = { gf = S(C(194, 190, 182), M.Concrete, "BoardFormedConcrete"), uf = S(C(204, 200, 192), M.Concrete, "BoardFormedConcrete"), slab = S(C(226, 222, 214), M.Concrete, "ConcretePlain"),
			pier = S(C(200, 190, 172), M.Cobblestone), frame = C(76, 62, 50), blind = C(156, 146, 130), door = S(C(116, 82, 54), M.WoodPlanks, "WoodPlanksOld"),
			garage = S(C(124, 88, 58), M.WoodPlanks, "WoodPlanksOld"), solar = false },
		med = { gf = S(C(236, 222, 196), M.Plaster, "StuccoBeige"), uf = S(C(236, 222, 196), M.Plaster, "StuccoBeige"), slab = S(C(240, 228, 206), M.Plaster, "StuccoBeige"),
			pier = S(C(214, 200, 176), M.Cobblestone), frame = C(66, 50, 40), blind = C(200, 186, 160), door = S(C(96, 66, 44), M.WoodPlanks, "WoodPlanksOld"),
			garage = S(C(110, 78, 52), M.WoodPlanks, "WoodPlanksOld"), clay = true },
	}
	for k, p in pairs(PAL) do p.land = p.land or p.pier end
	PAL.black.land = S(C(150, 148, 146), M.Cobblestone, "StoneDark")
	L.VILLA_PALETTES = PAL
	-- legacy style names from the build scripts map onto a pair of finishes
	local STYLEMAP = { noir = { "darkstone", "black" }, white = { "stone", "stucco" }, med = { "med", "stone" }, tropical = { "concrete", "stone" } }

	-- ===================================================================== shapes
	-- rects {x0, x1, z0, z1} in house space: x centred, z = 0 at the front building line, +z toward the garden
	local SHAPES = {
		bar = function(W, D) return { gf = { { -W / 2, W / 2, 0, D } }, uf = { { -W / 2 + W * 0.14, W / 2 + 2, 4, D + 4 } }, main = 1, gar = 1 } end,
		ell = function(W, D) return { gf = { { -W / 2, W / 2, 0, D * 0.66 }, { W / 2 - W * 0.32, W / 2, D * 0.66, D + 5 } }, uf = { { -W / 2 - 1, W * 0.1, -2, D * 0.66 + 6 } }, main = 1, gar = 1 } end,
		court = function(W, D) return { gf = { { -W / 2, W / 2, 0, D * 0.5 }, { -W / 2, -W / 2 + W * 0.28, D * 0.5, D + 3 }, { W / 2 - W * 0.28, W / 2, D * 0.5, D + 3 } }, uf = { { -W / 2 - 1, W * 0.06, 2, D + 5 } }, main = 1, gar = 1 } end,
		stacked = function(W, D) return { gf = { { -W * 0.16, W / 2, 3, D - 1 }, { -W / 2, -W * 0.16, 0, D * 0.62 } }, uf = { { -W / 2 + 6, W / 2 + 2, -1, D + 4 } }, main = 1, gar = 2 } end,
		split = function(W, D) return { gf = { { -W / 2, W * 0.04, 0, D }, { W * 0.04, W / 2, 5, D + 3 } }, uf = { { -W / 2 - 2, W * 0.04 + 5, 2, D + 4 } }, main = 1, gar = 2 } end,
		tower = function(W, D) return { gf = { { -W / 2, W * 0.14, 0, D }, { W * 0.14, W / 2, 4, D * 0.76 } }, uf = { { -W / 2, W * 0.02, -2, D + 4 } }, uf2 = { { -W / 2 + 3, -W * 0.16, 1, D * 0.62 } }, main = 1, gar = 2 } end,
		wing = function(W, D) return { gf = { { -W / 2, W / 2, 0, D * 0.46 }, { -W / 2, -W / 2 + W * 0.26, D * 0.46, D + 4 } }, uf = { { W * 0.0, W / 2 + 2, 1, D * 0.46 + 9 } }, main = 1, gar = 1 } end,
	}
	L.VILLA_SHAPES = { "bar", "ell", "court", "stacked", "split", "tower", "wing" }

	-- ===================================================================== small helpers
	local function inRect(r, x, z) return x > r[1] and x < r[2] and z > r[3] and z < r[4] end
	local function blinds(part, face, w, h, cover, col)
		-- horizontal venetian blinds drawn on the glass (no parts): one frame per bay with a striped gradient
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 12
		g.LightInfluence = 1
		g.MaxDistance = 420
		g.Parent = part
		local bays = math.max(1, math.floor(w / 6 + 0.5))
		for b = 0, bays - 1 do
			local cv = cover or L.pick({ 0.12, 0.3, 0.55, 0.75, 0.9 })
			if cv > 0.05 then
				local f = Instance.new("Frame")
				f.BorderSizePixel = 0
				f.BackgroundColor3 = col
				f.Position = UDim2.fromScale(b / bays + 0.004, 0)
				f.Size = UDim2.fromScale(1 / bays - 0.008, cv)
				f.Parent = g
				local n = math.clamp(math.floor(h * cv / 0.5), 4, 19)
				local kp = {}
				for i = 0, n do table.insert(kp, NumberSequenceKeypoint.new(i / n, (i % 2 == 0) and 0.02 or 0.42)) end
				local gr = Instance.new("UIGradient")
				gr.Rotation = 90
				gr.Transparency = NumberSequence.new(kp)
				gr.Parent = f
				local rail = Instance.new("Frame")
				rail.BorderSizePixel = 0
				rail.BackgroundColor3 = L.shade(col, 0.6)
				rail.Position = UDim2.new(0, 0, 1, -2)
				rail.Size = UDim2.new(1, 0, 0, 2)
				rail.Parent = f
			end
		end
	end
	L.villaBlinds = blinds
	local function stripes(part, face, n, col, alpha, vertical)
		-- slats / board grooves / panel joints on one face (no parts)
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 10
		g.LightInfluence = 1
		g.MaxDistance = 200
		g.Parent = part
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = col
		f.Size = UDim2.fromScale(1, 1)
		f.Parent = g
		n = math.clamp(n, 2, 19)
		local kp = {}
		for i = 0, n do table.insert(kp, NumberSequenceKeypoint.new(i / n, (i % 2 == 0) and alpha or 1)) end
		local gr = Instance.new("UIGradient")
		gr.Rotation = vertical and 0 or 90
		gr.Transparency = NumberSequence.new(kp)
		gr.Parent = f
		return g
	end
	L.villaStripes = stripes

	-- ===================================================================== the composer
	function L.villa(par, cf, w, d, o)
		o = o or {}
		local rng = Random.new(o.seed or (#(o.name or "") * 7919 + math.floor(cf.X * 13 + cf.Z * 7)))
		local function pick(t) return t[rng:NextInteger(1, #t)] end
		local function rr(a, b) return a + rng:NextNumber() * (b - a) end
		local pname = o.palette or (o.style and STYLEMAP[o.style] and pick(STYLEMAP[o.style])) or pick({ "stone", "darkstone", "stucco", "black", "concrete", "med" })
		local P = PAL[pname]
		local sname = o.shape or pick(L.VILLA_SHAPES)
		local mirror
		if o.mirror ~= nil then mirror = o.mirror else mirror = rng:NextNumber() < 0.5 end
		local m = Instance.new("Model")
		m.Name = o.name or ("Villa_" .. sname .. "_" .. pname)
		m:SetAttribute("HouseId", o.name or m.Name)
		m:SetAttribute("HouseStyle", sname .. "/" .. pname)
		m:SetAttribute("Owner", "")
		local I = Instance.new("Model")
		I.Name = m.Name

		-- local-space builders (everything below is in the lot frame)
		local function P_(par_, size, lcf, sp, opt) return L.P(par_, size, cf * lcf, sp.col, sp.mat, sp.var, opt) end
		local function D_(par_, size, lcf, col, mat, var, opt) return L.D(par_, size, cf * lcf, col, mat, var, opt) end
		local function B_(par_, x, y0, z, sx, sy, sz, col, mat, var, opt) return L.B(par_, cf, x, y0, z, sx, sy, sz, col, mat, var, opt) end
		local function BD_(par_, x, y0, z, sx, sy, sz, col, mat, var, opt) return L.BD(par_, cf, x, y0, z, sx, sy, sz, col, mat, var, opt) end

		-- ---- massing
		local FY = o.front or 13
		local HW = math.clamp(w - 14, 48, 84)
		local HD = math.clamp(d - FY - 22, 26, 40)
		local zf = -d / 2 + FY
		local shp = SHAPES[sname](HW, HD)
		local function fix(list)
			local out = {}
			for _, r in ipairs(list or {}) do
				local x0, x1 = r[1], r[2]
				if mirror then x0, x1 = -r[2], -r[1] end
				x0 = math.max(x0, -w / 2 + 3)
				x1 = math.min(x1, w / 2 - 3)
				table.insert(out, { x0, x1, zf + r[3], zf + r[4] })
			end
			return out
		end
		local GF, UF, UF2 = fix(shp.gf), fix(shp.uf), fix(shp.uf2)
		local main, gar = GF[shp.main], GF[shp.gar]
		local gside = mirror and 1 or -1 -- garage at the x0 end (-1) or the x1 end (+1)
		local uy = PL + GH + 1.2 -- upper floor level
		local u2y = uy + UH + 2.2 + 1.2
		local gfTop = uy - 1.25

		-- ---- garage, entrance and stair positions
		local gw = (gar[2] - gar[1] >= 40) and 25 or 15
		local gx0, gx1
		if gside < 0 then gx0, gx1 = gar[1] + 0.8, gar[1] + 0.8 + gw else gx0, gx1 = gar[2] - 0.8 - gw, gar[2] - 0.8 end
		local garDepth = math.min(gar[4] - gar[3] - 2, 27)
		local uf1 = UF[1]
		local ix0, ix1 = math.max(main[1], uf1[1]), math.min(main[2], uf1[2])
		local sz0 = math.max(main[3], uf1[3]) + 1.2
		local sz1 = sz0 + 5
		local RUN = 17.5
		local sLow, sHigh, sDir
		if gside < 0 then sHigh = ix1 - 1.2; sLow = sHigh - RUN; sDir = 1 else sHigh = ix0 + 1.2; sLow = sHigh + RUN; sDir = -1 end
		local entX = sLow - sDir * 5
		if gar == main then
			-- keep the door clear of the garage
			if gside < 0 then entX = math.max(entX, gx1 + 4.5) else entX = math.min(entX, gx0 - 4.5) end
		end
		local hole = { math.min(sLow + sDir * 6, sHigh) - 0.2, math.max(sLow + sDir * 6, sHigh) + 0.2, sz0 - 0.2, sz1 + 0.2 }
		hole[1], hole[2] = math.min(hole[1], hole[2]), math.max(hole[1], hole[2])

		-- ---- uncovered segments of a face (sampled; a face hidden by a neighbouring volume of the same level is skipped)
		local function segments(r, side, others)
			local a, b, fixed, nrm
			if side == "front" then a, b, fixed, nrm = r[1], r[2], r[3], Vector3.new(0, 0, -1)
			elseif side == "back" then a, b, fixed, nrm = r[1], r[2], r[4], Vector3.new(0, 0, 1)
			elseif side == "left" then a, b, fixed, nrm = r[3], r[4], r[1], Vector3.new(-1, 0, 0)
			else a, b, fixed, nrm = r[3], r[4], r[2], Vector3.new(1, 0, 0) end
			local segs, cur = {}, nil
			local step = 0.5
			local u = a
			while u <= b + 1e-6 do
				local px, pz
				if side == "front" or side == "back" then px, pz = u, fixed + nrm.Z * 0.6 else px, pz = fixed + nrm.X * 0.6, u end
				local cov = false
				for _, q in ipairs(others) do if q ~= r and inRect(q, px, pz) then cov = true break end end
				if not cov then
					if not cur then cur = { u, u } else cur[2] = u end
				elseif cur then
					table.insert(segs, cur); cur = nil
				end
				u += step
			end
			if cur then table.insert(segs, cur) end
			local out = {}
			for _, s in ipairs(segs) do if s[2] - s[1] > 1.4 then table.insert(out, { math.max(a, s[1] - 0.25), math.min(b, s[2] + 0.25) }) end end
			return out, fixed, nrm
		end
		-- frame for a span [u0,u1] of a face: centre point (local), facing outward
		local function faceCF(side, fixed, nrm, u, y)
			local p
			if side == "front" or side == "back" then p = Vector3.new(u, y, fixed - nrm.Z * 0.4) else p = Vector3.new(fixed - nrm.X * 0.4, y, u) end
			return CFrame.lookAt(p, p + nrm)
		end

		-- ---- facade pieces
		local function glaze(side, fixed, nrm, u0, u1, y0, h, cover)
			local len = u1 - u0
			if len < 0.6 then return end
			local uc = (u0 + u1) / 2
			local gl = D_(m, Vector3.new(len, h, 0.3), faceCF(side, fixed, nrm, uc, y0 + h / 2), C(64, 78, 86), M.Glass, nil, { Transparency = 0.42, Reflectance = 0.14, CanCollide = true, CanQuery = true })
			gl.Name = "Glazing"
			blinds(gl, Enum.NormalId.Front, len, h, cover, P.blind)
			local n = math.max(1, math.floor(len / 6 + 0.5))
			for k = 0, n do
				D_(m, Vector3.new(0.35, h, 0.55), faceCF(side, fixed, nrm, u0 + k * len / n, y0 + h / 2), P.frame, M.Metal)
			end
			D_(m, Vector3.new(len, 0.35, 0.55), faceCF(side, fixed, nrm, uc, y0 + h - 0.18), P.frame, M.Metal)
			D_(m, Vector3.new(len, 0.3, 0.55), faceCF(side, fixed, nrm, uc, y0 + 0.15), P.frame, M.Metal)
		end
		local function wall(side, fixed, nrm, u0, u1, y0, h, sp, hl)
			-- solid wall, optionally with one window hole hl = {hu0, hu1, hv0, hv1} (hv relative to y0)
			local function piece(a, b, v0, v1)
				if b - a > 0.15 and v1 - v0 > 0.15 then
					P_(m, Vector3.new(b - a, v1 - v0, 0.8), faceCF(side, fixed, nrm, (a + b) / 2, y0 + (v0 + v1) / 2), sp)
				end
			end
			if not hl then piece(u0, u1, 0, h) return end
			piece(u0, hl[1], 0, h)
			piece(hl[2], u1, 0, h)
			piece(hl[1], hl[2], 0, hl[3])
			piece(hl[1], hl[2], hl[4], h)
			local gl = D_(m, Vector3.new(hl[2] - hl[1], hl[4] - hl[3], 0.25), faceCF(side, fixed, nrm, (hl[1] + hl[2]) / 2, y0 + (hl[3] + hl[4]) / 2), C(60, 74, 82), M.Glass, nil, { Transparency = 0.38, Reflectance = 0.16, CanCollide = true })
			blinds(gl, Enum.NormalId.Front, hl[2] - hl[1], hl[4] - hl[3], nil, P.blind)
			-- reveal frame
			D_(m, Vector3.new(hl[2] - hl[1] + 0.5, 0.3, 0.9), faceCF(side, fixed, nrm, (hl[1] + hl[2]) / 2, y0 + hl[3]), P.frame, M.Metal)
			D_(m, Vector3.new(hl[2] - hl[1] + 0.5, 0.3, 0.9), faceCF(side, fixed, nrm, (hl[1] + hl[2]) / 2, y0 + hl[4]), P.frame, M.Metal)
		end
		local function slotHole(u0, u1, h, kind)
			local len = u1 - u0
			if kind == "ribbon" and len > 10 then
				local a = u0 + len * 0.18
				return { a, a + len * 0.64, 3.2, h - 2.6 }
			elseif len > 9 then
				local c = u0 + len * rr(0.3, 0.7)
				return { c - 1.6, c + 1.6, 1.2, h - 2.2 }
			end
		end

		-- ---- the front of the main volume: garage, stone piers, pivot door, transom, glass beside the stair
		local doorPart
		local function mainFront(segs, fixed, nrm, y0, h)
			local spans = {}
			if gar == main then table.insert(spans, { gx0 - 0.4, gx1 + 0.4, "garage" }) end
			table.insert(spans, { entX - 4.6, entX - 2.6, "pier" })
			table.insert(spans, { entX - 2.6, entX + 2.6, "door" })
			table.insert(spans, { entX + 2.6, entX + 4.6, "pier" })
			table.sort(spans, function(a, b) return a[1] < b[1] end)
			-- fill gaps: next to the stair = tall glass (you see the stair through it), elsewhere solid
			local full, u = {}, main[1]
			for _, s in ipairs(spans) do
				if s[1] > u then table.insert(full, { u, s[1], "fill" }) end
				table.insert(full, s)
				u = s[2]
			end
			if u < main[2] then table.insert(full, { u, main[2], "fill" }) end
			for _, sg in ipairs(segs) do
				for _, s in ipairs(full) do
					local a, b = math.max(s[1], sg[1]), math.min(s[2], sg[2])
					if b - a > 0.2 then
						local kind = s[3]
						if kind == "fill" then
							local nearStair = (a < math.max(sLow, sHigh)) and (b > math.min(sLow, sHigh))
							if nearStair and pname ~= "med" then glaze("front", fixed, nrm, a, b, y0, h, rr(0.05, 0.3))
							else wall("front", fixed, nrm, a, b, y0, h, P.gf, slotHole(a, b, h, "slot")) end
						elseif kind == "pier" then
							-- stone pier, proud of the wall, rising to the upper roof if there is a floor above
							local top = (uf1 and inRect(uf1, (a + b) / 2, fixed + 1)) and (uy + UH + 2.2) or (gfTop + 1.25)
							B_(m, (a + b) / 2, 0, fixed - 0.6, b - a, top, 3.2, P.pier.col, P.pier.mat, P.pier.var)
						elseif kind == "door" then
							local dh = 10.5
							wall("front", fixed, nrm, a, b, y0 + dh, h - dh, P.slab)
							local tr = D_(m, Vector3.new(b - a - 0.4, h - dh - 0.8, 0.2), faceCF("front", fixed, nrm, (a + b) / 2, y0 + dh + (h - dh) / 2), C(60, 72, 80), M.Glass, nil, { Transparency = 0.3, Reflectance = 0.2 })
							blinds(tr, Enum.NormalId.Front, b - a, h - dh, 0.85, P.blind)
							-- pivot door: closed when unclaimed, the interior loader swings it open
							doorPart = P_(m, Vector3.new(b - a - 0.6, dh, 0.5), faceCF("front", fixed, nrm, (a + b) / 2, y0 + dh / 2) * CFrame.new(0, 0, -0.5), P.door)
							doorPart.Name = "FrontDoor"
							stripes(doorPart, Enum.NormalId.Front, 9, L.shade(P.door.col, 0.6), 0.55, true)
							local hinge = doorPart.CFrame * CFrame.new(-(b - a - 0.6) / 2 + 1.2, 0, 0)
							doorPart:SetAttribute("OpenCF", hinge * CFrame.Angles(0, math.rad(80), 0) * CFrame.new((b - a - 0.6) / 2 - 1.2, 0, 0))
							doorPart:SetAttribute("ClosedCF", doorPart.CFrame)
							local hd = L.D(m, Vector3.new(0.35, 5.5, 0.35), doorPart.CFrame * CFrame.new((b - a) / 2 - 1.3, 0.3, -0.45), C(196, 150, 90), M.Wood)
							hd.Name = "DoorHandle"
							L.D(m, Vector3.new(0.5, dh - 2, 0.1), doorPart.CFrame * CFrame.new(-(b - a) / 2 + 1.2, 0, -0.26), C(70, 84, 90), M.Glass, nil, { Transparency = 0.2 })
						elseif kind == "garage" then
							local dh = 9.5
							wall("front", fixed, nrm, a, b, y0 + dh, h - dh, P.gf)
							local gd = P_(m, Vector3.new(dh, b - a - 0.8, 0.4), faceCF("front", fixed, nrm, (a + b) / 2, y0 + dh / 2) * CFrame.new(0, 0, 0.1) * CFrame.Angles(0, 0, math.pi / 2), P.garage)
							gd.Name = "GarageDoor"
							stripes(gd, Enum.NormalId.Front, math.floor((b - a) / 1.4), L.shade(P.garage.col, 0.55), 0.6, false)
						end
					end
				end
			end
		end

		-- ---- build one storey of volumes
		local function storey(list, y0, h, level)
			for vi, r in ipairs(list) do
				for _, side in ipairs({ "front", "back", "left", "right" }) do
					local segs, fixed, nrm = segments(r, side, list)
					if level == 0 and r == main and side == "front" then
						mainFront(segs, fixed, nrm, y0, h)
					elseif level == 0 and r == gar and side == "front" and gar ~= main then
						for _, sg in ipairs(segs) do
							local a, b = math.max(sg[1], gx0 - 0.4), math.min(sg[2], gx1 + 0.4)
							if b - a > 4 then
								local dh = 9.5
								wall("front", fixed, nrm, a, b, y0 + dh, h - dh, P.gf)
								local gd = P_(m, Vector3.new(dh, b - a - 0.8, 0.4), faceCF("front", fixed, nrm, (a + b) / 2, y0 + dh / 2) * CFrame.new(0, 0, 0.1) * CFrame.Angles(0, 0, math.pi / 2), P.garage)
								gd.Name = "GarageDoor"
								stripes(gd, Enum.NormalId.Front, math.floor((b - a) / 1.4), L.shade(P.garage.col, 0.55), 0.6, false)
								if a - sg[1] > 0.3 then wall("front", fixed, nrm, sg[1], a, y0, h, P.gf) end
								if sg[2] - b > 0.3 then wall("front", fixed, nrm, b, sg[2], y0, h, P.gf, slotHole(b, sg[2], h, "slot")) end
							else
								wall("front", fixed, nrm, sg[1], sg[2], y0, h, P.gf)
							end
						end
					else
						for _, sg in ipairs(segs) do
							local a, b = sg[1], sg[2]
							local sp = (level == 0) and P.gf or P.uf
							local kind
							if side == "back" then kind = "glass"
							elseif side == "front" then kind = (level > 0 and rng:NextNumber() < 0.45) and "glass" or "solid"
							else
								-- side faces looking into a courtyard (toward the house centre) are glass
								local toward = (side == "left" and r[1] > 0) or (side == "right" and r[2] < 0)
								kind = (toward and level == 0 and #list > 1) and "glass" or ((level > 0 and rng:NextNumber() < 0.3) and "glass" or "solid")
							end
							if pname == "med" and kind == "glass" and side ~= "back" then kind = "solid" end
							if kind == "glass" then glaze(side, fixed, nrm, a, b, y0, h)
							else wall(side, fixed, nrm, a, b, y0, h, sp, slotHole(a, b, h, (level > 0) and "ribbon" or "slot")) end
						end
					end
				end
				-- garden-facing upper glass gets a slim balcony rail
			end
		end

		-- ---- plinth + ground floor
		for _, r in ipairs(GF) do
			P_(m, Vector3.new(r[2] - r[1] + 1.6, PL, r[4] - r[3] + 1.6), CFrame.new((r[1] + r[2]) / 2, PL / 2, (r[3] + r[4]) / 2), S(C(186, 184, 178), M.Concrete, "ConcretePlain"))
			D_(m, Vector3.new(r[2] - r[1] - 0.2, 0.06, r[4] - r[3] - 0.2), CFrame.new((r[1] + r[2]) / 2, PL + 0.03, (r[3] + r[4]) / 2), C(206, 204, 198), M.Concrete, "ConcretePlain")
		end
		storey(GF, PL, gfTop - PL, 0)
		-- garage partition (it is part of the form: the garage is its own room)
		do
			local gz1 = gar[3] + garDepth
			local px = (gside < 0) and (gx1 + 0.4) or (gx0 - 0.4)
			P_(m, Vector3.new(0.6, gfTop - PL, garDepth), CFrame.new(px, PL + (gfTop - PL) / 2, gar[3] + garDepth / 2), S(C(226, 224, 218), M.Plaster, "StuccoGreyFine"))
			if gz1 < gar[4] - 1 then P_(m, Vector3.new(gx1 - gx0 + 1.2, gfTop - PL, 0.6), CFrame.new((gx0 + gx1) / 2, PL + (gfTop - PL) / 2, gz1), S(C(226, 224, 218), M.Plaster, "StuccoGreyFine")) end
		end
		-- GF roof slabs (white fascia band; holes over the stair)
		local function slab(r, y, th, ov, sp, h)
			local x0, x1, z0, z1 = r[1] - ov[3], r[2] + ov[4], r[3] - ov[1], r[4] + ov[2]
			local function pc(a0, a1, b0, b1)
				if a1 - a0 > 0.2 and b1 - b0 > 0.2 then P_(m, Vector3.new(a1 - a0, th, b1 - b0), CFrame.new((a0 + a1) / 2, y - th / 2, (b0 + b1) / 2), sp) end
			end
			if h and h[1] > x0 and h[2] < x1 and h[3] > z0 and h[4] < z1 then
				pc(x0, x1, z0, h[3]); pc(x0, x1, h[4], z1); pc(x0, h[1], h[3], h[4]); pc(h[2], x1, h[3], h[4])
			else
				pc(x0, x1, z0, z1)
			end
		end
		for _, r in ipairs(GF) do slab(r, uy - 0.05, 1.2, { 1.2, 2.6, 1.2, 1.2 }, P.slab, (r == main) and hole or nil) end

		-- ---- upper floor
		for _, r in ipairs(UF) do slab(r, uy, 1.4, { 0.4, 0.4, 0.4, 0.4 }, P.slab, (r == uf1) and hole or nil) end
		storey(UF, uy, UH, 1)
		local roofs = {}
		for _, r in ipairs(UF) do
			if P.clay then
				slab(r, uy + UH + 0.8, 0.8, { 2, 2, 2, 2 }, S(C(120, 84, 56), M.Wood))
				local lw, ld = r[2] - r[1] + 4, r[4] - r[3] + 4
				local cx, cz = (r[1] + r[2]) / 2, (r[3] + r[4]) / 2
				L.W(m, Vector3.new(lw, 6, ld / 2), cf * CFrame.new(cx, uy + UH + 3.8, cz - ld / 4), C(176, 92, 62), M.ClayRoofTiles, "RoofClayMission")
				L.W(m, Vector3.new(lw, 6, ld / 2), cf * CFrame.new(cx, uy + UH + 3.8, cz + ld / 4) * CFrame.Angles(0, math.pi, 0), C(176, 92, 62), M.ClayRoofTiles, "RoofClayMission")
			else
				slab(r, uy + UH + 2.2, 2.2, { 2.2, 3.4, 2.4, 2.4 }, P.slab)
				table.insert(roofs, { r, uy + UH + 2.2 })
			end
		end
		-- ---- exterior detail (the reference villas): metal coping, warm soffit light lines, a timber slat screen
		-- on the street face of the upper floor, a glass balcony across the garden side
		local COP = C(52, 52, 54)
		for _, rf in ipairs(roofs) do
			local r, y = rf[1], rf[2]
			local x0, x1, z0, z1 = r[1] - 2.4, r[2] + 2.4, r[3] - 2.2, r[4] + 3.4
			for _, e in ipairs({ { (x0 + x1) / 2, z0, x1 - x0, 0.35 }, { (x0 + x1) / 2, z1, x1 - x0, 0.35 }, { x0, (z0 + z1) / 2, 0.35, z1 - z0 }, { x1, (z0 + z1) / 2, 0.35, z1 - z0 } }) do
				L.D(m, Vector3.new(e[3], 0.5, e[4]), cf * CFrame.new(e[1], y + 0.25, e[2]), COP, M.Metal)
			end
			-- warm LED line under the front + back soffit edge
			for _, zz in ipairs({ z0 + 0.6, z1 - 0.6 }) do
				L.D(m, Vector3.new(x1 - x0 - 1.2, 0.12, 0.25), cf * CFrame.new((x0 + x1) / 2, y - 2.25, zz), C(255, 226, 176), M.Neon)
			end
		end
		if uf1 and not P.clay then
			-- timber slat screen over ~35% of the upper street face, proud of the wall
			local sw = (uf1[2] - uf1[1]) * 0.35
			local sx = (gside < 0) and (uf1[2] - sw / 2 - 1) or (uf1[1] + sw / 2 + 1)
			local slat = L.D(m, Vector3.new(sw, UH - 1, 0.5), cf * CFrame.new(sx, uy + UH / 2, uf1[3] - 0.9), C(150, 104, 66), M.Wood)
			stripes(slat, Enum.NormalId.Front, math.floor(sw / 0.9), C(40, 30, 20), 0.15, true)
			stripes(slat, Enum.NormalId.Back, math.floor(sw / 0.9), C(40, 30, 20), 0.15, true)
			for k = 0, 1 do L.D(m, Vector3.new(sw + 0.4, 0.3, 0.7), cf * CFrame.new(sx, uy + 0.4 + k * (UH - 1.8), uf1[3] - 0.9), COP, M.Metal) end
			-- garden balcony: slab + frameless glass + steel cap, 60% of the back face
			local bw = (uf1[2] - uf1[1]) * 0.6
			local bx = (gside < 0) and (uf1[1] + bw / 2 + 1) or (uf1[2] - bw / 2 - 1)
			local bz = uf1[4] + 2.6
			P_(m, Vector3.new(bw, 0.8, 5), CFrame.new(bx, uy - 0.4, bz), P.slab)
			L.D(m, Vector3.new(bw, 3.4, 0.2), cf * CFrame.new(bx, uy + 1.7, bz + 2.4), C(170, 200, 210), M.Glass, nil, { Transparency = 0.6, CanCollide = true })
			L.D(m, Vector3.new(bw, 0.2, 0.3), cf * CFrame.new(bx, uy + 3.45, bz + 2.4), COP, M.Metal)
			for sd = -1, 1, 2 do L.D(m, Vector3.new(0.2, 3.4, 5), cf * CFrame.new(bx + sd * bw / 2, uy + 1.7, bz), C(170, 200, 210), M.Glass, nil, { Transparency = 0.6, CanCollide = true }) end
			for k = 0, 1 do L.B(m, cf * CFrame.new(bx - bw / 4 + k * 3, uy, bz - 0.5), 0, 0, 0, 2.2, 0.9, 5, C(236, 234, 228), M.Fabric) end
		end
		-- third-floor pavilion (tower shape): glass box with its own deep roof
		for _, r in ipairs(UF2) do
			storey({ r }, u2y, UH - 1, 2)
			slab(r, u2y + UH - 1 + 2, 2, { 2.5, 2.5, 2.5, 2.5 }, P.slab)
			table.insert(roofs, { r, u2y + UH + 1 })
		end
		-- GF roofs that are mostly open become terraces with a planted edge + glass rail
		for _, r in ipairs(GF) do
			local cx, cz = (r[1] + r[2]) / 2, (r[3] + r[4]) / 2
			local covered = false
			for _, q in ipairs(UF) do if inRect(q, cx, cz) then covered = true end end
			if not covered and (r[2] - r[1]) * (r[4] - r[3]) > 200 then
				BD_(m, cx, uy - 0.05, cz, r[2] - r[1] - 1, 0.12, r[4] - r[3] - 1, C(172, 134, 96), M.WoodPlanks, "WoodPlanksOld")
				BD_(m, cx, uy - 0.05, r[4] + 0.6, r[2] - r[1] + 1.6, 1.2, 1.6, C(70, 100, 50), M.LeafyGrass)
				D_(m, Vector3.new(r[2] - r[1] + 1.6, 3.2, 0.15), CFrame.new(cx, uy + 1.6, r[4] + 1.5), C(170, 200, 210), M.Glass, nil, { Transparency = 0.65, CanCollide = true })
				D_(m, Vector3.new(r[2] - r[1] + 1.6, 0.25, 0.3), CFrame.new(cx, uy + 3.25, r[4] + 1.5), P.frame, M.Metal)
				for k = 0, 1 do L.B(m, cf * CFrame.new(cx - 4 + k * 4, uy, cz) * CFrame.Angles(0, 0.1, 0), 0, 0, 0, 2.6, 0.9, 6.4, WHITE, M.Fabric) end
			end
		end
		-- stone blade wall / chimney stack on one side of the upper floor (the reference's stone towers)
		if uf1 and not P.clay then
			local sx = (rng:NextNumber() < 0.5) and uf1[1] or uf1[2]
			local top = uy + UH + 5
			B_(m, sx, 0, (uf1[3] + uf1[4]) / 2 + rr(-4, 4), 3.4, top, 7, P.pier.col, P.pier.mat, P.pier.var)
		end
		-- roof kit: solar rows, condensers, flues, slim rail
		for _, rf in ipairs(roofs) do
			local r, y = rf[1], rf[2]
			local rw, rd = r[2] - r[1], r[4] - r[3]
			if P.solar and rw > 14 and rd > 12 then
				local rows = math.min(3, math.floor((rd - 8) / 5.5))
				local pw = math.min(rw - 12, 40)
				for k = 0, rows - 1 do
					local pz = r[4] - 5 - k * 5.5
					local pnl = L.D(m, Vector3.new(pw, 0.2, 4.2), cf * CFrame.new((r[1] + r[2]) / 2, y + 1.3, pz) * CFrame.Angles(math.rad(-12), 0, 0), C(26, 36, 58), M.Glass, nil, { Reflectance = 0.25 })
					stripes(pnl, Enum.NormalId.Top, math.floor(pw / 3.4), C(170, 180, 196), 0.35, true)
					L.D(m, Vector3.new(pw, 1, 0.2), cf * CFrame.new((r[1] + r[2]) / 2, y + 0.5, pz + 1.9), C(150, 150, 154), M.Metal)
				end
			end
			for k = 0, rng:NextInteger(1, 2) do
				B_(m, r[2] - 5 - k * 5, y, r[4] - 3, 3.6, 2.6, 2, C(232, 232, 230), M.Metal)
			end
			for k = 0, 1 do L.Cyl(m, 2.2, 0.8, cf * CFrame.new(r[1] + 4 + k * 3, y + 1.1, r[3] + 3), C(40, 40, 42), M.Metal) end
		end

		-- ---- stair (structure: it is part of the form)
		do
			local n = 14
			local rise = (uy - PL) / n
			local tz = (sz0 + sz1) / 2
			for k = 0, n - 1 do
				local x = sLow + sDir * (k + 0.5) * (RUN / n)
				P_(m, Vector3.new(RUN / n + 0.05, 0.4, 4.6), CFrame.new(x, PL + (k + 1) * rise - 0.2, tz), S(C(214, 212, 206), M.Concrete, "ConcretePlain"))
			end
			-- solid concrete stringer wall on the open side + black handrail
			local a = cf * Vector3.new(sLow, PL + 1.2, sz1 + 0.25)
			local b = cf * Vector3.new(sHigh, uy + 1.2, sz1 + 0.25)
			local len = (b - a).Magnitude
			L.P(m, Vector3.new(0.5, 3.2, len), CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, -0.4, 0), C(214, 212, 206), M.Concrete, "ConcretePlain")
			L.bar(m, a + Vector3.new(0, 2.6, 0), b + Vector3.new(0, 2.6, 0), 0.22, INK, M.Metal)
		end

		-- ===================================================================== grounds
		local gz0 = -math.huge
		for _, r in ipairs(GF) do gz0 = math.max(gz0, r[4]) end
		local gz1 = d / 2 - (o.dock and 1.5 or 1)
		local mainBack = main[4]
		-- lawn (with holes for the pool cut below), side hedges, front planters
		local lawnY = 0.12
		-- front: driveway (large grey pavers) to the garage, light path to the door, planters with box hedges, bollards
		local dz0, dz1 = -d / 2 + 0.5, gar[3] - 0.2
		BD_(m, (gx0 + gx1) / 2, 0, (dz0 + dz1) / 2, gx1 - gx0 + 4, 0.22, dz1 - dz0, C(150, 150, 152), M.CorrodedMetal, "PaverLargeGrey")
		BD_(m, entX, 0, (-d / 2 + 0.5 + main[3]) / 2, 6.5, 0.24, main[3] + d / 2 - 0.5, C(208, 206, 200), M.Concrete, "SidewalkSlabs")
		local function planter(x, z, lw, ld, h)
			B_(m, x, 0, z, lw, h, ld, P.land.col, P.land.mat, P.land.var)
			B_(m, x, h, z, lw - 0.6, 2.2, ld - 0.6, C(92, 128, 60), M.LeafyGrass)
		end
		local function bollard(x, z)
			L.Cyl(m, 2.8, 0.45, cf * CFrame.new(x, 1.4, z), C(30, 30, 32), M.Metal)
			L.D(m, Vector3.new(0.5, 0.25, 0.5), cf * CFrame.new(x, 2.6, z), C(255, 226, 180), M.Neon)
		end
		local pz0 = -d / 2 + 2
		planter(entX - 6.5, (pz0 + main[3]) / 2, 3.6, math.min(10, main[3] - pz0 - 2), 2.2)
		planter(entX + 6.5, (pz0 + main[3]) / 2 + 1, 3.6, math.min(8, main[3] - pz0 - 3), 3)
		for k = 0, 2 do
			bollard(entX - 4, pz0 + 2 + k * 4)
			bollard((gside < 0) and (gx1 + 2.6) or (gx0 - 2.6), pz0 + 1 + k * 4)
		end
		-- lawn strips: front (around drive/path) and the whole garden
		BD_(m, 0, 0, (-d / 2 + gz0) / 2, w - 1, lawnY, gz0 + d / 2 - 1, C(124, 162, 84), M.Grass, "LawnGrassB")
		-- side hedges along the lot lines
		-- open Florida lots: no walls between neighbours, just a few shrubs and a palm toward the back
		for sd = -1, 1, 2 do
			for k = 0, 1 do L.bush(m, cf * Vector3.new(sd * (w / 2 - 2.5), 0, d * (0.1 + k * 0.22)), rr(3, 4.5)) end
		end
		-- low street wall + slatted gate + mailbox
		-- curbside mailbox on a post
		local mbx = (gx0 + gx1) / 2 + (gx1 - gx0) / 2 + 3
		L.BD(m, cf, mbx, 0, -d / 2 + 1.2, 0.35, 3.6, 0.35, C(40, 40, 42), M.Metal)
		L.BD(m, cf, mbx, 3.6, -d / 2 + 1.2, 1.1, 1.1, 1.8, P.frame, M.Metal)
		local num = L.D(m, Vector3.new(2.6, 1.1, 0.1), cf * CFrame.new(entX + 4, 6.5, main[3] - 3.3), P.frame, M.Metal)
		L.label(num, Enum.NormalId.Front, tostring(rng:NextInteger(10, 98) * 100 + rng:NextInteger(0, 99)), { font = Enum.Font.Michroma, color = C(222, 204, 160), light = 0.3 })
		-- front: specimen tree on the far side, two palms framing the walk, a car on the drive
		L.tree(m, cf * Vector3.new((gside < 0) and (w / 2 - 9) or (-w / 2 + 9), 0, -d / 2 + 7), rr(0.7, 0.95))
		for sd = -1, 1, 2 do
			local pz = (-d / 2 + main[3]) / 2 + 1
			L.streetPalm(m, cf * Vector3.new(entX + sd * 9.5, 0.2, pz), rng:NextInteger(1, 99), nil, cf.LookVector)
			L.D(m, Vector3.new(0.6, 0.25, 0.6), cf * CFrame.new(entX + sd * 9.5 + 1.4, 0.3, pz - 1), C(255, 230, 190), M.Neon)
		end
		if rng:NextNumber() < 0.55 and L.supercar then
			pcall(function() L.supercar(m, cf * CFrame.new((gx0 + gx1) / 2, 0.25, (dz0 + dz1) / 2 + 1) * CFrame.Angles(0, rng:NextNumber() < 0.5 and 0 or math.pi, 0), nil, false) end)
		end

		-- garden: terrace along the back, pool with mosaic lining, deck, pergola + lounge, dining, loungers, boulders
		local gd = gz1 - gz0
		local tz1 = gz0 + 5
		local poolW = math.min(w * 0.5, 46)
		local poolD = math.clamp(gd - 9, 6, 11)
		local poolSide = (rng:NextNumber() < 0.5) and -1 or 1
		local px = poolSide * (w / 2 - 6 - poolW / 2)
		local pz0, pz1 = tz1 + 0.5, tz1 + 0.5 + poolD
		if gd > 10 then
			local deckX0, deckX1 = px - poolW / 2 - 3, px + poolW / 2 + 3
			local function deck(a0, a1, b0, b1)
				if a1 - a0 > 0.2 and b1 - b0 > 0.2 then P_(m, Vector3.new(a1 - a0, 1.2, b1 - b0), CFrame.new((a0 + a1) / 2, PL - 0.6, (b0 + b1) / 2), S(C(206, 204, 198), M.CorrodedMetal, "PaverLargeGrey")) end
			end
			-- terrace + pool surround as one paved platform with a hole for the pool
			deck(-w / 2 + 3, w / 2 - 3, gz0, pz0)
			deck(deckX0, deckX1, pz1, math.min(pz1 + 3, gz1))
			deck(deckX0, px - poolW / 2, pz0, pz1)
			deck(px + poolW / 2, deckX1, pz0, pz1)
			-- carve the basin out of the terrain, then line it
			pcall(function() workspace.Terrain:FillBlock(cf * CFrame.new(px, -1.4, (pz0 + pz1) / 2), Vector3.new(poolW, 4.4, poolD), M.Air) end)
			local tile = C(34, 70, 104)
			P_(m, Vector3.new(poolW, 0.4, poolD), CFrame.new(px, -3.2, (pz0 + pz1) / 2), S(C(70, 150, 176), M.CeramicTiles, "PlazaTiles"))
			for _, e in ipairs({ { px, pz0 + 0.2, poolW, 0.4 }, { px, pz1 - 0.2, poolW, 0.4 }, { px - poolW / 2 + 0.2, (pz0 + pz1) / 2, 0.4, poolD }, { px + poolW / 2 - 0.2, (pz0 + pz1) / 2, 0.4, poolD } }) do
				P_(m, Vector3.new(e[3], 4.2, e[4]), CFrame.new(e[1], -1.1, e[2]), S(tile, M.CeramicTiles, "PlazaTiles"))
			end
			local water = D_(m, Vector3.new(poolW - 0.8, 0.3, poolD - 0.8), CFrame.new(px, PL - 0.45, (pz0 + pz1) / 2), C(52, 168, 196), M.Glass, nil, { Transparency = 0.32, Reflectance = 0.08 })
			water.Name = "PoolWater"
			local pl = Instance.new("PointLight")
			pl.Range = 16; pl.Brightness = 0.7; pl.Color = C(120, 220, 255); pl.Shadows = false
			pl.Parent = water
			-- ladder
			for k = -1, 1, 2 do L.D(m, Vector3.new(0.25, 0.25, 2.6), cf * CFrame.new(px - poolW / 2 + 4 + k * 0.9, PL + 0.8, pz0 + 0.6) * CFrame.Angles(math.rad(-60), 0, 0), C(180, 184, 188), M.Metal) end
			-- sun loungers on the far deck
			for k = 0, 3 do
				local lx = px + (k - 1.5) * 4.2
				local lc = cf * CFrame.new(lx, PL, math.min(pz1 + 1.8, gz1 - 1))
				L.B(m, lc, 0, 0, 0, 2.2, 0.8, 6, C(176, 96, 52), M.Wood)
				L.P(m, Vector3.new(2.2, 0.3, 2.4), lc * CFrame.new(0, 1.2, -2.2) * CFrame.Angles(math.rad(-35), 0, 0), C(176, 96, 52), M.Wood)
			end
		else
			P_(m, Vector3.new(w - 6, 1.2, math.max(2, gd)), CFrame.new(0, PL - 0.6, (gz0 + gz1) / 2), S(C(206, 204, 198), M.CorrodedMetal, "PaverLargeGrey"))
		end
		-- pergola cabana on the other side: timber deck, black posts, slatted roof, timber back wall, white lounge
		local cabX = -poolSide * (w / 2 - 12)
		local cabZ = math.min(tz1 + 6, gz1 - 5)
		if gd > 12 and math.abs(cabX - px) > poolW / 2 + 11 then
			local cc = cf * CFrame.new(cabX, 0, cabZ)
			L.B(m, cc, 0, 0, 0, 16, PL + 0.2, 9, C(198, 166, 120), M.WoodPlanks, "WoodPlanksOld")
			for _, q in ipairs({ { -7.6, -4.2 }, { 7.6, -4.2 }, { -7.6, 4.2 }, { 7.6, 4.2 } }) do L.B(m, cc, q[1], PL, q[2], 0.4, 9, 0.4, INK, M.Metal) end
			L.B(m, cc, 0, PL + 9, 0, 16.6, 0.5, 9.2, INK, M.Metal)
			local roof = L.B(m, cc, 0, PL + 9.5, 0, 16.6, 0.5, 9.2, C(214, 190, 150), M.WoodPlanks, nil, { Transparency = 0 })
			stripes(roof, Enum.NormalId.Bottom, 19, C(40, 34, 28), 0.0, true)
			stripes(roof, Enum.NormalId.Top, 19, C(120, 100, 76), 0.2, true)
			L.B(m, cc, 0, PL, 4.3, 16, 8.8, 0.5, C(150, 118, 84), M.WoodPlanks, "WoodPlanksOld")
			-- deep white lounge sofa (L) + black side tables
			L.B(m, cc, -2, PL + 0.2, 2.6, 10, 1.6, 3.2, C(238, 236, 230), M.Fabric)
			L.B(m, cc, -2, PL + 1.8, 3.7, 10, 1.6, 1, C(242, 240, 236), M.Fabric)
			L.B(m, cc, -6.2, PL + 0.2, -0.6, 3.2, 1.6, 4, C(238, 236, 230), M.Fabric)
			L.B(m, cc, 4.6, PL + 0.2, 0.6, 2, 2, 2, C(22, 22, 24), M.SmoothPlastic)
			L.B(m, cc, -1, PL + 0.2, -0.8, 3.6, 1.4, 2.2, C(22, 22, 24), M.SmoothPlastic)
			local lp = L.D(m, Vector3.new(0.8, 0.6, 0.8), cc * CFrame.new(4.6, PL + 2.6, 0.6), C(255, 220, 170), M.Neon)
			L.D(m, Vector3.new(0.15, 0.8, 0.15), cc * CFrame.new(4.6, PL + 2.4, 0.6), INK, M.Metal)
		end
		-- outdoor dining under a shade sail (copper posts) on the lawn
		do
			local dx = (math.abs(cabX - px) > poolW / 2 + 11) and (cabX + poolSide * 14) or (-poolSide * (w / 2 - 10))
			local dzz = math.min(gz1 - 5, pz1 + 6)
			if gd > 16 and math.abs(dx) < w / 2 - 6 then
				local dc = cf * CFrame.new(dx, 0, dzz)
				L.B(m, dc, 0, 0, 0, 12, 0.3, 7, C(206, 204, 198), M.CorrodedMetal, "PaverLargeGrey")
				L.B(m, dc, 0, 2.6, 0, 8, 0.3, 3, C(150, 92, 52), M.Wood)
				for sd = -1, 1, 2 do L.B(m, dc, sd * 3.2, 0.3, 0, 0.4, 2.3, 2.4, INK, M.Metal) end
				for k = -1, 1 do
					for sd = -1, 1, 2 do
						local ch = dc * CFrame.new(k * 2.6, 0.3, sd * 2.6)
						L.B(m, ch, 0, 1.4, 0, 1.6, 0.25, 1.6, C(196, 100, 52), M.Wood)
						L.B(m, ch, 0, 1.65, sd * 0.75, 1.6, 1.8, 0.2, C(196, 100, 52), M.Wood)
						for lg = -1, 1, 2 do L.BD(m, ch, lg * 0.6, 0, 0, 0.2, 1.4, 1.3, C(30, 30, 32), M.Metal) end
					end
				end
				for _, q in ipairs({ { -6, -3.5, 9 }, { 6, 3.5, 9 }, { 6, -3.5, 7 } }) do L.B(m, dc, q[1], 0, q[2], 0.35, q[3], 0.35, C(176, 100, 56), M.Metal) end
				L.W(m, Vector3.new(0.12, 2, 12), dc * CFrame.new(0, 8, 0) * CFrame.Angles(0, math.rad(90), math.rad(-80)), C(52, 76, 56), M.Fabric)
			end
		end
		-- boulders + palms + garden uplights
		local FK = SS:FindFirstChild("VBFurniture")
		local function boulder(x, z, s)
			local src = FK and FK:FindFirstChild(pick({ "Boulder3", "Boulder3", "Boulders1" }))
			if src then
				local b = src:Clone()
				pcall(function() b:ScaleTo(s) end)
				b:PivotTo(cf * CFrame.new(x, -0.6 * s, z) * CFrame.Angles(0, rr(0, 6.28), 0))
				b.Parent = m
			end
		end
		boulder((gside < 0) and (gx1 + 8) or (gx0 - 8), -d / 2 + 6, rr(0.35, 0.5))
		if gd > 14 then boulder(poolSide * (w / 2 - 6), gz1 - 4, rr(0.3, 0.45)) end
		for _, q in ipairs({ { -w / 2 + 5, gz1 - 3 }, { w / 2 - 5, gz1 - 3 } }) do
			L.palm(m, cf * Vector3.new(q[1], 0, q[2]), rr(30, 40), (rng:NextNumber() < 0.5) and "hero" or "royal")
		end
		for _, r in ipairs(GF) do
			for x = r[1] + 3, r[2] - 3, 9 do L.D(m, Vector3.new(0.6, 0.3, 0.6), cf * CFrame.new(x, PL + 0.15, r[3] - 1.4), C(255, 230, 190), M.Neon) end
		end

		-- ===================================================================== dock (empty berth for the owner's boat)
		if o.dock and o.dockMode == "parallel" then
			local wz = d / 2
			P_(m, Vector3.new(w, 7.4, 2.4), CFrame.new(0, -3.4, wz - 1.2), S(C(206, 202, 194), M.Concrete, "ConcretePlain"))
			local dc = cf * CFrame.new(0, L.WATER - L.G + 1.6, wz + 3)
			L.P(m, Vector3.new(w - 8, 0.8, 6), dc, C(172, 134, 96), M.WoodPlanks, "WoodPlanksOld")
			for x = -w / 2 + 6, w / 2 - 6, 8 do
				for _, zz in ipairs({ -2.6, 2.6 }) do L.Cyl(m, 9, 1, dc * CFrame.new(x, -3.6, zz), C(110, 90, 70), M.Wood) end
				L.D(m, Vector3.new(1.4, 0.5, 0.5), dc * CFrame.new(x, 0.6, 2.6), C(220, 220, 222), M.Metal)
			end
			for x = -w / 2 + 8, w / 2 - 8, 6 do L.D(m, Vector3.new(2.2, 1.2, 0.6), dc * CFrame.new(x, -0.2, 3.2), WHITE, M.Rubber) end
			L.B(m, cf, w / 2 - 8, -0.9, wz - 0.4, 3, 0.4, 2, C(206, 202, 194), M.Concrete)
			L.houseBerth(m, dc * CFrame.new(0, -1.6, 12), w - 10, 18, o.name)
		elseif o.dock then
			local wz = d / 2
			P_(m, Vector3.new(w, 3.4, 2.4), CFrame.new(0, -1.2, wz - 1.2), S(C(206, 202, 194), M.Concrete, "ConcretePlain"))
			local dc = cf * CFrame.new(o.dockX or (-poolSide * w * 0.25), L.WATER - L.G + 1.6, wz + 1)
			local dl = o.dockLen or 26
			L.P(m, Vector3.new(8, 0.8, dl), dc * CFrame.new(0, 0, dl / 2), C(172, 134, 96), M.WoodPlanks, "WoodPlanksOld")
			L.P(m, Vector3.new(48, 0.8, 7), dc * CFrame.new(0, 0, dl - 3.5), C(172, 134, 96), M.WoodPlanks, "WoodPlanksOld")
			for x = -22, 22, 6 do L.D(m, Vector3.new(2.2, 1.2, 0.6), dc * CFrame.new(x, -0.2, dl + 0.2), WHITE, M.Rubber) end
			for x = -20, 20, 10 do L.D(m, Vector3.new(0.6, 0.6, 1.4), dc * CFrame.new(x, 0.6, dl - 1), C(220, 220, 222), M.Metal) end
			for zz = 2, dl, 6 do for _, sx in ipairs({ -4, 4 }) do L.Cyl(m, 9, 1.1, dc * CFrame.new(sx, -3.6, zz), C(110, 90, 70), M.Wood) end end
			for zz = 4, dl, 8 do
				L.D(m, Vector3.new(0.5, 2.6, 0.5), dc * CFrame.new(-3.6, 1.7, zz), INK, M.Metal)
				L.D(m, Vector3.new(0.6, 0.4, 0.6), dc * CFrame.new(-3.6, 3.1, zz), C(255, 236, 200), M.Neon)
			end
			L.houseBerth(m, dc * CFrame.new(0, -1.6, dl + 11), 70, 20, o.name)
		end

		-- ===================================================================== interior (stored, loaded on claim)
		if L.villaInterior then
			L.villaInterior(I, cf, {
				GF = GF, UF = UF, main = main, gar = gar, gx0 = gx0, gx1 = gx1, garDepth = garDepth, gside = gside,
				entX = entX, sLow = sLow, sHigh = sHigh, sDir = sDir, sz0 = sz0, sz1 = sz1, uy = uy, gfTop = gfTop, PL = PL, UH = UH,
				pal = pname, rng = rng,
			})
		end
		local store = SS:FindFirstChild("VBInteriors") or Instance.new("Folder")
		store.Name = "VBInteriors"
		store.Parent = SS
		local old = store:FindFirstChild(I.Name)
		if old then old:Destroy() end
		I.Parent = store

		m.Parent = par
		L.lod(m)
		CS:AddTag(m, "VBHouse")
		if o.price then L.poi((cf * CFrame.new(entX, 0, -d / 2 + 6)).Position, "Property", o.name or "Villa", { Price = o.price, Tier = 5, Style = sname .. "/" .. pname }) end
		return m
	end

	-- the old builder stays reachable; every caller now gets the composer
	L.luxHouseLegacy = L.luxHouse
	L.luxHouse = function(par, cf, w, d, o) return L.villa(par, cf, w, d, o) end
end
