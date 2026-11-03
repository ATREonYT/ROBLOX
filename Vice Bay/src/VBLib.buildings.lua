-- ===== BUILDINGS =====
L.HOOD_COLS = { C(214, 198, 166), C(176, 198, 186), C(206, 174, 170), C(172, 186, 206), C(228, 218, 196), C(196, 166, 126), C(160, 168, 146), C(214, 152, 104), C(186, 180, 172), C(222, 206, 150) }
L.SHOP_NAMES = { "FOOD MART", "WASH N FOLD", "CHECK CASHING", "WIRELESS 4 LESS", "LIQUOR", "TIRES", "BEAUTY SUPPLY", "BARBER", "PAWN", "CELL REPAIR", "WINGS", "BAIL BONDS", "99 CENT", "SNEAKERS", "TAQUERIA", "DOLLAR STORE", "GOLD BUYER", "TAX PREP", "LOTTO", "JERK CHICKEN", "PHONE REPAIR", "SEAFOOD", "MEAT MARKET", "FURNITURE", "DISCOUNT" }
L.SIGN_COLS = { { C(200, 30, 30), C(255, 255, 255) }, { C(250, 210, 40), C(20, 20, 20) }, { C(20, 60, 140), C(255, 255, 255) }, { C(255, 255, 255), C(200, 20, 20) }, { C(20, 120, 60), C(255, 255, 255) }, { C(30, 30, 30), C(255, 200, 40) } }
local GRIME = "VB_GrimeStucco"
local STUC = "VB_Stucco"
local function glass(m, cf, x, y0, z, w, h)
	return L.B(m, cf, x, y0, z, w, h, 0.3, C(38, 44, 52), M.Glass, nil, { Reflectance = 0.2 })
end
local function boarded(m, cf, x, y0, z, w, h)
	return L.B(m, cf, x, y0, z, w, h, 0.35, C(150, 122, 92), M.WoodPlanks)
end
L.glass = glass

function L.house(par, cf, w, d, o)
	o = o or {}
	local m = Instance.new("Model")
	m.Name = o.name or "House"
	local rundown = o.rundown
	local col = o.color or L.pick(L.HOOD_COLS)
	local h = L.r(11, 13)
	local bw = math.min(w - 14, L.r(24, 34))
	local bd = math.min(d - 18, L.r(24, 32))
	local bx = -w / 2 + 3 + bw / 2
	local bz = -d / 2 + L.r(11, 15) + bd / 2
	local fz = bz - bd / 2
	L.B(m, cf, bx, 0, bz, bw, h, bd, col, M.Plaster, rundown and GRIME or STUC)
	-- roof
	if L.chance(0.55) then
		local rh = L.r(4, 6)
		local rc = L.pick({ C(120, 110, 100), C(150, 86, 62), C(90, 88, 86), C(170, 100, 70) })
		local rm = (rc.R > 0.55) and M.ClayRoofTiles or M.RoofShingles
		L.W(m, Vector3.new(bw + 2, rh, bd / 2 + 1), cf * CFrame.new(bx, h + rh / 2, bz - bd / 4 - 0.5), rc, rm)
		L.W(m, Vector3.new(bw + 2, rh, bd / 2 + 1), cf * CFrame.new(bx, h + rh / 2, bz + bd / 4 + 0.5) * CFrame.Angles(0, math.pi, 0), rc, rm)
	else
		L.B(m, cf, bx, h, bz, bw + 0.8, 1.2, bd + 0.8, L.shade(col, 0.85), M.Concrete)
		if L.chance(0.35) then L.Cyl(m, 0.3, 2.6, cf * CFrame.new(bx + bw / 3, h + 2.4, bz) * CFrame.Angles(0.6, 0, 0), C(225, 225, 225), M.SmoothPlastic) end
	end
	-- facade
	local bad = rundown and L.chance(0.22)
	for _, sx in ipairs({ -1, 1 }) do
		local f = bad and boarded or glass
		f(m, cf, bx + sx * bw / 3.2, 3.5, fz - 0.12, 5, 4.5)
	end
	L.B(m, cf, bx, 0.6, fz - 0.12, 4, 7.5, 0.3, L.pick({ C(90, 60, 40), C(240, 240, 235), C(40, 60, 90), C(150, 40, 40) }), M.Wood)
	L.B(m, cf, bx, 0, fz - 2.5, 8, 0.7, 5, C(170, 166, 158), M.Concrete)
	-- side AC unit
	L.B(m, cf, bx + bw / 2 + 1.2, 1, bz + bd / 4, 2.2, 3, 3.5, C(200, 200, 196), M.Metal)
	-- driveway
	local dx = bx + bw / 2 + 6
	if dx + 5 < w / 2 + 0.5 then
		L.B(m, cf, dx, 0, -d / 2 + (bz + bd / 2 + d / 2) / 2, 10, 0.3, bz + bd / 2 + d / 2, C(168, 164, 156), M.Concrete)
		if L.chance(o.carChance or 0.3) then
			L.car(m, cf * CFrame.new(dx, 0.3, -d / 2 + 12) * CFrame.Angles(0, L.chance(0.5) and 0 or math.pi, 0), nil, L.chance(0.3) and "suv" or "sedan")
		end
	end
	-- front fence
	local fk = rundown and L.pick({ "chain", "chain", "wall", "none" }) or L.pick({ "wall", "iron", "none" })
	if fk ~= "none" then
		local x1 = (dx + 5 < w / 2) and (dx - 5.5) or w / 2 - 1
		L.fence(m, (cf * CFrame.new(-w / 2 + 1, 0, -d / 2 + 1)).Position, (cf * CFrame.new(x1, 0, -d / 2 + 1)).Position, fk == "wall" and 3.5 or 4.5, fk)
	end
	if L.chance(0.35) then L.tree(m, (cf * CFrame.new(bx - bw / 4, 0, -d / 2 + 6)).Position, L.r(0.6, 0.9)) end
	if rundown and L.chance(0.2) then
		local side = m:GetChildren()[1]
		L.graffiti(side, Enum.NormalId.Right)
	end
	m.Parent = par
	return m
end

function L.shop(par, cf, w, d, o)
	o = o or {}
	local m = Instance.new("Model")
	m.Name = o.name or "Shop"
	local rundown = o.rundown
	local floors = o.floors or (L.chance(0.4) and 2 or 1)
	local h = floors == 1 and L.r(14, 16) or L.r(23, 26)
	local col = o.color or L.pick(L.HOOD_COLS)
	local bd = math.min(d - 4, L.r(30, 42))
	local bz = -d / 2 + 2 + bd / 2
	local fz = bz - bd / 2
	local brick = L.chance(0.25)
	local body = L.B(m, cf, 0, 0, bz, w, h, bd, brick and L.pick({ C(150, 84, 66), C(170, 110, 86) }) or col, brick and M.Brick or M.Plaster, (not brick) and (rundown and GRIME or STUC) or nil)
	L.B(m, cf, 0, h, bz, w + 0.6, 1.4, bd + 0.6, L.shade(col, 0.8), M.Concrete)
	-- storefront
	glass(m, cf, 0, 0.6, fz - 0.1, w - 4, 8.5)
	local n = math.max(1, math.floor(w / 14))
	local pw = (w - 4) / n
	for k = 0, n - 1 do
		local x = -w / 2 + 2 + pw * (k + 0.5)
		if rundown or L.chance(0.3) then
			local closed = L.chance(rundown and 0.6 or 0.3)
			local sh = closed and 8.5 or L.r(2, 4)
			L.B(m, cf, x, 9.1 - sh, fz - 0.35, pw - 0.6, sh, 0.3, C(200, 200, 196), M.Metal, "VB_RollShutter")
		end
	end
	L.B(m, cf, 0, 9.1, fz - 0.25, w - 3, 0.6, 0.6, C(60, 60, 60), M.Metal)
	-- awning
	if L.chance(0.5) then
		local ac = L.pick({ C(180, 30, 30), C(30, 90, 50), C(30, 50, 110), C(220, 160, 30), C(60, 60, 60) })
		L.P(m, Vector3.new(w * 0.85, 0.4, 5), cf * CFrame.new(0, 10.2, fz - 2.3) * CFrame.Angles(math.rad(-14), 0, 0), ac, M.Fabric)
	end
	-- sign
	local sc = L.pick(L.SIGN_COLS)
	local name = o.sign or L.pick(L.SHOP_NAMES)
	local signP = L.sign(m, cf * CFrame.new(0, 12.3, fz - 0.45), math.min(w - 4, #name * 2.2 + 6), 2.8, name, sc[1], sc[2], L.pick({ Enum.Font.GothamBlack, Enum.Font.Arimo, Enum.Font.Oswald }), {})
	if floors == 2 then
		local wn = math.max(2, math.floor(w / 12))
		for k = 0, wn - 1 do
			local x = -w / 2 + (k + 0.5) * w / wn
			local f = (rundown and L.chance(0.2)) and boarded or glass
			f(m, cf, x, 15.5, fz - 0.12, 4.5, 5)
		end
	end
	-- roof units
	L.B(m, cf, L.r(-w / 4, w / 4), h + 1.4, bz + L.r(-3, 3), 5, 3, 5, C(190, 190, 186), M.Metal)
	if rundown and L.chance(0.55) then L.graffiti(body, L.pick({ Enum.NormalId.Left, Enum.NormalId.Right })) end
	if rundown and L.chance(0.25) then L.graffiti(body, Enum.NormalId.Back) end
	m.Parent = par
	return m, body
end

function L.walkup(par, cf, w, d, o)
	o = o or {}
	local m = Instance.new("Model")
	m.Name = o.name or "Apartments"
	local rundown = o.rundown
	local floors = o.floors or L.ri(2, 3)
	local fh = 10
	local h = floors * fh + 1
	local col = o.color or L.pick(L.HOOD_COLS)
	local bd = math.min(d - 12, L.r(28, 36))
	local bw = w - 6
	local bz = -d / 2 + 10 + bd / 2
	local fz = bz - bd / 2
	local body = L.B(m, cf, 0, 0, bz, bw, h, bd, col, M.Plaster, rundown and GRIME or STUC)
	L.B(m, cf, 0, h, bz, bw + 0.6, 1.2, bd + 0.6, L.shade(col, 0.8), M.Concrete)
	-- exterior walkways + railings on front
	for f = 1, floors - 1 do
		L.B(m, cf, 0, f * fh - 0.5, fz - 2.5, bw, 0.6, 5, C(180, 176, 168), M.Concrete)
		L.B(m, cf, 0, f * fh + 0.1, fz - 4.9, bw, 3, 0.25, C(40, 40, 40), M.Metal, nil, { Transparency = 0.35 })
	end
	-- window bands (one strip per floor; doors read as darker)
	for f = 0, floors - 1 do
		local wcount = math.max(2, math.floor(bw / 14))
		for k = 0, wcount - 1 do
			local x = -bw / 2 + (k + 0.5) * bw / wcount
			local f2 = (rundown and L.chance(0.15)) and boarded or glass
			f2(m, cf, x + 2.5, f * fh + 3.5, fz - 0.12, 4, 4)
			L.B(m, cf, x - 2.5, f * fh + 0.6, fz - 0.12, 3.5, 7.2, 0.3, L.pick({ C(90, 60, 40), C(60, 70, 90), C(120, 40, 40) }), M.Wood)
		end
	end
	-- stair (wedge)
	if floors > 1 then
		L.W(m, Vector3.new(4, fh, 12), cf * CFrame.new(bw / 2 + 2.2, fh / 2, fz + 6) * CFrame.Angles(0, math.pi, 0), C(150, 150, 146), M.Concrete)
	end
	if L.chance(0.5) then L.fence(m, (cf * CFrame.new(-w / 2 + 1, 0, -d / 2 + 1)).Position, (cf * CFrame.new(w / 2 - 1, 0, -d / 2 + 1)).Position, 4.5, rundown and "chain" or "iron") end
	if L.chance(0.5) then L.car(m, cf * CFrame.new(L.r(-bw / 3, bw / 3), 0, -d / 2 + 5) * CFrame.Angles(0, math.pi / 2, 0)) end
	if rundown and L.chance(0.4) then L.graffiti(body, L.pick({ Enum.NormalId.Left, Enum.NormalId.Right })) end
	m.Parent = par
	return m
end

function L.emptyLot(par, cf, w, d, o)
	o = o or {}
	local m = Instance.new("Model")
	m.Name = "EmptyLot"
	L.B(m, cf, 0, 0, 0, w - 2, 0.2, d - 2, L.pick({ C(120, 104, 84), C(110, 112, 80) }), M.Ground)
	local a = (cf * CFrame.new(-w / 2 + 1, 0, -d / 2 + 1)).Position
	local b = (cf * CFrame.new(w / 2 - 1, 0, -d / 2 + 1)).Position
	local c2 = (cf * CFrame.new(w / 2 - 1, 0, d / 2 - 1)).Position
	local d2 = (cf * CFrame.new(-w / 2 + 1, 0, d / 2 - 1)).Position
	L.fence(m, a, b, 7, "chain")
	if L.chance(0.6) then L.fence(m, b, c2, 7, "chain") end
	if L.chance(0.6) then L.fence(m, d2, a, 7, "chain") end
	for _ = 1, L.ri(2, 5) do
		L.Ball(m, L.r(1.4, 2.4), cf * CFrame.new(L.r(-w / 3, w / 3), 0.8, L.r(-d / 3, d / 3)), C(25, 25, 25), M.Plastic, nil, { CanCollide = false })
	end
	if L.chance(0.4) then L.B(m, cf, L.r(-w / 4, w / 4), 0.2, L.r(-d / 4, d / 4), 5, 1.2, 7, C(200, 196, 170), M.Fabric) end
	if L.chance(0.35) then
		local t = L.P(m, Vector3.new(1, 3, 3), cf * CFrame.new(L.r(-w / 3, w / 3), 1.5, L.r(-d / 3, d / 3)), C(25, 25, 25), M.Rubber, nil, { Shape = Enum.PartType.Cylinder })
	end
	local sgn = o.sign or (L.chance(0.5) and "WE BUY HOUSES  CASH" or nil)
	if sgn then
		local post = L.B(m, cf, 0, 0, -d / 2 + 4, 0.6, 7, 0.6, C(90, 80, 70), M.Wood)
		L.sign(m, cf * CFrame.new(0, 8, -d / 2 + 4) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(0, math.pi, 0), 9, 3.5, sgn, C(255, 255, 255), C(200, 20, 20), Enum.Font.GothamBlack, {})
	end
	for _ = 1, L.ri(0, 3) do L.bush(m, (cf * CFrame.new(L.r(-w / 3, w / 3), 0, L.r(-d / 3, d / 3))).Position, L.r(3, 6)) end
	m.Parent = par
	return m
end

function L.condoBoard(par, cf, w, d)
	-- gentrification: fenced lot with "luxury condos coming soon" billboard
	local m = L.emptyLot(par, cf, w, d, { sign = "NO TRESPASSING" })
	m.Name = "FutureCondoLot"
	local bc = cf * CFrame.new(0, 0, d / 4)
	L.B(m, bc, -8, 0, 0, 1, 18, 1, C(60, 60, 64), M.Metal)
	L.B(m, bc, 8, 0, 0, 1, 18, 1, C(60, 60, 64), M.Metal)
	local s = L.sign(m, bc * CFrame.new(0, 21, 0), 28, 9, "THE VUE  LUXURY CONDOS  COMING SOON", C(240, 240, 236), C(30, 30, 34), Enum.Font.Oswald, { both = true })
	return m
end

function L.church(par, cf, w, d, o)
	local m = Instance.new("Model")
	m.Name = "Church"
	local bd = math.min(d - 10, 40)
	local bw = math.min(w - 8, 30)
	local bz = -d / 2 + 8 + bd / 2
	local col = C(236, 232, 222)
	L.B(m, cf, 0, 0, bz, bw, 16, bd, col, M.Plaster, STUC)
	L.W(m, Vector3.new(bw + 1.5, 8, bd / 2 + 0.5), cf * CFrame.new(0, 20, bz - bd / 4), C(120, 60, 50), M.ClayRoofTiles)
	L.W(m, Vector3.new(bw + 1.5, 8, bd / 2 + 0.5), cf * CFrame.new(0, 20, bz + bd / 4) * CFrame.Angles(0, math.pi, 0), C(120, 60, 50), M.ClayRoofTiles)
	L.B(m, cf, 0, 0, bz - bd / 2 - 3, 8, 26, 6, col, M.Plaster, STUC)
	L.B(m, cf, 0, 31, bz - bd / 2 - 3, 0.8, 8, 0.8, C(230, 200, 90), M.Metal)
	L.B(m, cf, 0, 34, bz - bd / 2 - 3, 4.5, 0.8, 0.8, C(230, 200, 90), M.Metal)
	L.B(m, cf, 0, 0.5, bz - bd / 2 - 6.1, 5, 9, 0.3, C(110, 70, 40), M.Wood)
	glass(m, cf, -bw / 3, 5, bz - bd / 2 - 0.12, 3, 8)
	glass(m, cf, bw / 3, 5, bz - bd / 2 - 0.12, 3, 8)
	L.sign(m, cf * CFrame.new(0, 3, -d / 2 + 3), 14, 4, (o and o.sign) or "NEW HOPE BAPTIST CHURCH", C(250, 250, 245), C(30, 30, 80), Enum.Font.Merriweather, {})
	m.Parent = par
	return m
end

function L.warehouse(par, cf, w, d, o)
	o = o or {}
	local m = Instance.new("Model")
	m.Name = o.name or "Warehouse"
	local h = o.h or L.r(20, 28)
	local bd = d - 6
	local bz = -d / 2 + 4 + bd / 2
	local col = o.color or L.pick({ C(190, 186, 178), C(160, 164, 168), C(180, 160, 130), C(140, 150, 140) })
	local body = L.B(m, cf, 0, 0, bz, w - 4, h, bd, col, o.metal and M.CorrodedMetal or M.Concrete)
	L.B(m, cf, 0, h, bz, w - 3.4, 1, bd + 0.6, L.shade(col, 0.8), M.Metal)
	local n = math.max(1, math.floor((w - 8) / 20))
	for k = 0, n - 1 do
		local x = -(w - 4) / 2 + (k + 0.5) * (w - 4) / n
		L.B(m, cf, x, 0.2, bz - bd / 2 - 0.25, 12, 13, 0.3, C(196, 196, 192), M.Metal, "VB_RollShutter")
	end
	L.B(m, cf, 0, 0, bz - bd / 2 - 6, w - 4, 3.5, 12, C(150, 148, 142), M.Concrete)
	if o.sign then L.sign(m, cf * CFrame.new(0, h - 4, bz - bd / 2 - 0.3), math.min(w - 8, #o.sign * 2.4 + 6), 3.5, o.sign, C(30, 30, 34), C(255, 255, 255), Enum.Font.GothamBlack, {}) end
	if o.mural then
		L.text(body, Enum.NormalId.Front, o.mural, { font = Enum.Font.Bangers, color = L.pick(L.TAGCOLORS), stroke = 0, bg = L.pick({ C(30, 60, 140), C(200, 60, 120), C(250, 190, 40), C(40, 160, 140) }), dist = 400, pps = 6, light = 1 })
	elseif o.rundown and L.chance(0.6) then
		L.graffiti(body, L.pick({ Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Front }))
	end
	m.Parent = par
	return m
end

-- ===== LOT FILLER =====
-- edges from L.net; chooser(x, z, edgeStyle, side) -> nil | {kind, w, d, opts}
function L.fill(par, net, chooser, filterFn)
	local VB = workspace.ViceBay
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Include
	op.FilterDescendantsInstances = { VB:FindFirstChild("Roads"), VB:FindFirstChild("Buildings"), VB:FindFirstChild("Reserved"), VB:FindFirstChild("Landmarks") }
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { workspace.Terrain }
	rp.IgnoreWater = false
	local function dry(p)
		local r = workspace:Raycast(p + Vector3.new(0, 30, 0), Vector3.new(0, -60, 0), rp)
		return r and r.Material ~= Enum.Material.Water and r.Position.Y > 0
	end
	local built = 0
	for i, e in ipairs(net.edges) do
		local A, B = net.nodes[e[1]], net.nodes[e[2]]
		local a = Vector3.new(A[1], L.G, A[2])
		local b = Vector3.new(B[1], L.G, B[2])
		local len = (b - a).Magnitude
		local mid = (a + b) / 2
		if len > 40 and (not filterFn or filterFn(mid.X, mid.Z, e)) then
			local dir = (b - a).Unit
			local right = Vector3.new(-dir.Z, 0, dir.X)
			local st = e[4]
			local edgeOff = e[3] / 2 + (st.sw or 0) + 1
			for side = -1, 1, 2 do
				local s = 16
				while s < len - 16 do
					local p0 = a + dir * s
					local ch = chooser(p0.X, p0.Z, st, side, e)
					if not ch then
						s += 20
					else
						local w, d = ch.w, ch.d
						if s + w > len - 12 then break end
						local center = a + dir * (s + w / 2) + right * side * (edgeOff + d / 2)
						local cf = CFrame.lookAt(center, center - right * side)
						local ok = #workspace:GetPartBoundsInBox(cf * CFrame.new(0, 6, 0), Vector3.new(w - 1, 10, d - 1), op) == 0
						if ok then
							for _, q in ipairs({ { 0, 0 }, { -w / 2 + 2, -d / 2 + 2 }, { w / 2 - 2, d / 2 - 2 }, { -w / 2 + 2, d / 2 - 2 }, { w / 2 - 2, -d / 2 + 2 } }) do
								if not dry((cf * CFrame.new(q[1], 0, q[2])).Position) then ok = false; break end
							end
						end
						if ok then
							local folder = par
							local gen = L[ch.kind]
							gen(folder, cf, w, d, ch.opts)
							built += 1
							s += w + (ch.gap or L.r(2, 6))
						else
							s += 8
						end
					end
				end
			end
		end
		if i % 15 == 0 then task.wait() end
	end
	return built
end
