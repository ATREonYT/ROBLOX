-- 40 Mangrove Bay out, hood in (2026-11-02, Alex: the game is the hood).
-- Step 1 (done by hand before this ran): Workspace.ViceBay.Buildings.MangroveBay, Landmarks.MangroveBay and the 14
-- Mangrove* POIs were MOVED to ServerStorage.MTL_Stored.MangroveBay (not deleted).
-- This file: fill the north canals (x -2048..-1832, z -1152..-460) to ground at G, then lay a hood street ladder
-- off Glades Rd (back street NW 52 Ave North + 3 cross streets) and fill it with rundown hood lots, Westside style.
-- The strip under the Coral Causeway (z -460..-420) stays water. Run 37_hood_roads afterwards for road wear.
return function(L)
	local M = L.M
	local G = L.G
	local T = workspace.Terrain
	local VB = workspace.ViceBay
	L.seed(4040)
	local t0 = os.clock()
	local X0, X1, Z0, Z1 = -2048, -1832, -1152, -416 -- includes the band under the Coral Causeway

	-- ===== 1. fill the canals: solid ground at exactly G, dirt with patchy grass =====
	local CH = 128
	local rng = Random.new(40)
	for x0 = X0, X1 - 1, CH do
		for z0 = Z0, Z1 - 1, CH do
			local reg = Region3.new(Vector3.new(x0, -16, z0), Vector3.new(math.min(x0 + CH, X1), 8, math.min(z0 + CH, Z1))):ExpandToGrid(4)
			local sz = reg.Size / 4
			local base = reg.CFrame.Position - reg.Size / 2
			local mats, occ = {}, {}
			for ix = 1, sz.X do
				mats[ix], occ[ix] = {}, {}
				for iy = 1, sz.Y do
					mats[ix][iy], occ[ix][iy] = {}, {}
					local yb = base.Y + (iy - 1) * 4
					local o = (yb < 0) and 1 or 0 -- measured: this puts the surface at exactly y 2 (= G). (G - 2 - yb)/4 gave y 0, which L.isWater() calls 'wet' (buildRoads then adds bridge-rail walls); (G - yb)/4 gave y 4
					for iz = 1, sz.Z do
						local mt = M.Ground
						if yb >= -4 and rng:NextNumber() < 0.35 then mt = M.LeafyGrass end
						mats[ix][iy][iz] = (o > 0) and mt or M.Air
						occ[ix][iy][iz] = o
					end
				end
			end
			T:WriteVoxels(reg, 4, mats, occ)
		end
		task.wait()
	end

	-- ===== 2. streets: a ladder off Glades Rd =====
	local S = L.STY
	local lines = {}
	local function ln(style, p, o)
		o = o or {}
		table.insert(lines, { style = S[style], pts = p, name = o.name, cul = o.cul })
	end
	local CROSS = { { -1010, "NW 48 St" }, { -780, "NW 46 St" }, { -550, "NW 44 St" } }
	local back = {}
	for _, c in ipairs(CROSS) do table.insert(back, { -1960, c[1] }) end
	ln("HOOD", back, { name = "NW 52 Ave" })
	for _, c in ipairs(CROSS) do ln("HOOD", { { -1960, c[1] }, { -1822, c[1] } }, { name = c[2] }) end
	local net = L.net(lines)
	L.buildRoads(VB, net, "HoodNorth")
	-- guard: no bridge railings on dry hood streets (2026-11-02 the first run left 9 x 3.4-stud curb walls)
	local hn = VB:FindFirstChild("HoodNorth")
	if hn then
		for _, d in ipairs(hn:GetDescendants()) do
			if d:IsA("BasePart") and math.abs(d.Size.Y - 3.4) < 0.05 and d.Size.X < 1 then d:Destroy() end
		end
	end
	if not table.find(L.FILL_BLOCKERS, "HoodNorth") then table.insert(L.FILL_BLOCKERS, "HoodNorth") end
	if not table.find(L.FILL_BLOCKERS, "HoodWest") then table.insert(L.FILL_BLOCKERS, "HoodWest") end
	for _, c in ipairs(CROSS) do
		pcall(function() L.cutSidewalk(CFrame.new(-1827, G + 0.5, c[1]), Vector3.new(14, 3, 40), "Roads") end)
	end
	task.wait()

	-- ===== 3. lots: The Ends / Westside mix =====
	local Bh = L.folder(VB.Buildings, "HoodNorth")
	Bh:ClearAllChildren()
	local built = L.fill(Bh, net, function(x, z, st, side, e)
		if x < X0 or x > X1 + 4 or z < Z0 or z > Z1 then return nil end
		local r = L.rng:NextNumber()
		if r < 0.42 then return { kind = "house", w = L.r(40, 48), d = L.r(42, 48), opts = { abandoned = L.chance(0.2), carChance = 0.35, tagChance = 0.4, twoChance = 0.4 }, gap = L.r(0, 3) } end
		if r < 0.6 then return { kind = "walkup", w = L.r(52, 64), d = 50, opts = { rundown = true } } end
		if r < 0.72 then return { kind = "shop", w = L.r(38, 50), d = 48, opts = { rundown = true, floors = L.pick({ 1, 2, 2, 3 }) } } end
		if r < 0.8 then return { kind = "court", w = 56, d = 80 } end
		if r < 0.9 then return { kind = "bays", w = L.r(54, 64), d = 56 } end
		return { kind = "emptyLot", w = L.r(30, 44), d = 46 }
	end, function(x, z) return x > X0 and x < X1 + 4 and z > Z0 and z < Z1 end)

	local parts = 0
	for _, f in ipairs({ Bh, VB:FindFirstChild("HoodNorth") }) do if f then for _, d in ipairs(f:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end end end
	return string.format("HoodNorth: lots %d, parts %d (%.1fs)", built, parts, os.clock() - t0)
end
-- Run log 2026-11-02: first pass gave 12 lots. Then the water band z -464..-416 (under the causeway) was filled to
-- ground too, and two extra L.fill passes (seed 4141; houses 32-40 wide, small shops, empty lots) brought it to 23.
-- Fix 2026-11-02: the fill top was at y 0 (G - 2), which L.isWater() reads as water, so buildRoads put 3.4-stud
-- bridge railings along every curb and blocked the lots. The map thread moved those 9 walls to
-- ServerStorage.MTL_ReplacedBuildings.HoodNorthBarriers. Fill now tops out at G, plus a guard that strips any railing.
-- Fix 2 (19:20): live terrain in the strip rewritten with the rule above; raycast check 1,037 samples all at y 2.00, no water.
