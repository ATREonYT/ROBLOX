-- 01 terrain: ocean, seabed, mainland, beach, river, glades
return function(L)
	local T = workspace.Terrain
	local M = L.M
	local function fill(x0, x1, y0, y1, z0, z1, mat)
		-- chunked FillBlock (keeps Studio responsive)
		local step = 512
		local x = x0
		while x < x1 do
			local z = z0
			local xe = math.min(x1, x + step)
			while z < z1 do
				local ze = math.min(z1, z + step)
				T:FillBlock(CFrame.new((x + xe) / 2, (y0 + y1) / 2, (z + ze) / 2), Vector3.new(xe - x, y1 - y0, ze - z), mat)
				z = ze
			end
			x = xe
			task.wait()
		end
	end
	L.fillT = fill
	T:Clear()
	task.wait()
	-- seabed + ocean
	fill(-2600, 3200, -24, -12, -1900, 2200, M.Sand)
	fill(-2600, 3200, -12, -4, -1900, 2200, M.Water)
	-- mainland: filling to y = 0 makes the rendered surface land at y = 2 (= L.G)
	fill(-2048, 1460, -12, 0, -1152, 652, M.Concrete)
	fill(-2048, -100, -12, 0, 652, 1140, M.Concrete)
	fill(-100, 1000, -12, 0, 652, 1000, M.Concrete)
	-- beach: flat sand then a slope into the water
	fill(1460, 1600, -12, 0, -1152, 652, M.Sand)
	for k = 0, 4 do
		local x0 = 1600 + k * 20
		fill(x0, x0 + 20, -12, -(k + 1) * 2, -1152, 652, M.Sand)
	end
	-- glades (west edge): marsh ground with ponds
	fill(-2048, -1800, -12, 0, -1152, 1140, M.Mud)
	fill(-2048, -1800, -4, 0, -1152, 1140, M.LeafyGrass)
	local ponds = { { -1960, -900, 70, 40 }, { -1900, -620, 50, 60 }, { -1980, -250, 60, 40 }, { -1930, 420, 80, 50 }, { -1970, 820, 60, 70 } }
	for _, p in ipairs(ponds) do
		T:FillBlock(CFrame.new(p[1], -1, p[2]), Vector3.new(p[3], 6, p[4]), M.Air)
		T:FillBlock(CFrame.new(p[1], -6, p[2]), Vector3.new(p[3], 4, p[4]), M.Water)
	end
	-- the Vice River (sea level -4, bed -12), 64 wide
	L.RIVER = { { -2120, 160 }, { -1750, 200 }, { -1450, 150 }, { -1150, 210 }, { -930, 260 }, { -700, 320 }, { -400, 380 }, { -100, 430 }, { 200, 480 }, { 500, 560 }, { 760, 620 }, { 1060, 700 } }
	local R = L.RIVER
	for i = 1, #R - 1 do
		local a = Vector3.new(R[i][1], 0, R[i][2])
		local b = Vector3.new(R[i + 1][1], 0, R[i + 1][2])
		local len = (b - a).Magnitude
		local cf = CFrame.lookAt((a + b) / 2, b)
		T:FillBlock(cf * CFrame.new(0, -1, 0), Vector3.new(64, 6, len + 40), M.Air)
		T:FillBlock(cf * CFrame.new(0, -8, 0), Vector3.new(64, 8, len + 40), M.Water)
		T:FillBlock(cf * CFrame.new(0, -14, 0), Vector3.new(64, 4, len + 40), M.Mud)
		task.wait()
	end
	-- part-built river seawall caps (Miami River has concrete bulkheads)
	local root = L.root("River")
	root:ClearAllChildren()
	for i = 1, #R - 1 do
		local a = Vector3.new(R[i][1], L.G, R[i][2])
		local b = Vector3.new(R[i + 1][1], L.G, R[i + 1][2])
		local len = (b - a).Magnitude
		local cf = CFrame.lookAt((a + b) / 2, b)
		for side = -1, 1, 2 do
			L.P(root, Vector3.new(2.4, 8, len + 4), cf * CFrame.new(side * 32.6, -3.4, 0), L.C(176, 172, 162), M.Concrete, "ChannelWall")
			L.D(root, Vector3.new(2.8, 0.5, len + 4), cf * CFrame.new(side * 32.6, 0.85, 0), L.C(200, 196, 188), M.Concrete, "ConcretePlain")
		end
	end
	return "terrain ok"
end
