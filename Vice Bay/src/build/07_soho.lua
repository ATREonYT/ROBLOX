-- 07 SoHo Vice: x 80..300, z -1110..-690 (north of the park). Cast-iron lofts, boutiques, string lights,
-- and the Car Meet: a plaza where players show off exotic cars.
return function(L)
	local M, C = L.M, L.C
	local G = L.G
	local lines = require(game.ServerStorage.VBBuild.lines:Clone())(L)
	local net = L.net(lines)
	local VB = L.folder(workspace, "ViceBay")
	local LM = L.folder(L.folder(VB, "Landmarks"), "SoHo")
	local B = L.folder(L.folder(VB, "Buildings"), "SoHo")
	LM:ClearAllChildren()
	B:ClearAllChildren()
	L.seed(808)
	local function at(x, z, yaw) return CFrame.new(x, G, z) * CFrame.Angles(0, yaw or 0, 0) end
	-- ground: cobbles everywhere between the buildings
	local T = workspace.Terrain
	T:ReplaceMaterial(Region3.new(Vector3.new(80, -8, -1110), Vector3.new(300, 4, -690)):ExpandToGrid(4), 4, M.Concrete, M.Pavement)

	-- ===== THE CAR MEET (middle block: x 106..257, z -949..-862) =====
	do
		local cm = L.model(LM, "CarMeet")
		local c = at(181, -905)
		local W, D = 148, 84
		L.BD(cm, c, 0, 0.03, 0, W, 0.2, D, C(70, 70, 74), M.Asphalt, "AsphaltDarkFresh")
		-- painted stalls
		for k = 0, 9 do
			local x = -W / 2 + 10 + k * 14
			for _, z in ipairs({ -26, 26 }) do
				L.BD(cm, c, x - 7, 0.24, z, 0.4, 0.02, 20, C(250, 210, 40), M.SmoothPlastic)
			end
		end
		-- the cars: two rows facing the centre aisle
		for k = 0, 9 do
			local x = -W / 2 + 17 + k * 14
			L.supercar(cm, c * CFrame.new(x, 0.2, -26), nil, true)
			if k ~= 4 and k ~= 5 then L.supercar(cm, c * CFrame.new(x, 0.2, 26) * CFrame.Angles(0, math.pi, 0), nil, true) end
		end
		-- turntable showpiece
		L.Cyl(cm, 0.6, 22, c * CFrame.new(-W / 2 + 80, 0.4, 26), C(30, 30, 34), M.Metal)
		L.Cyl(cm, 0.1, 22.4, c * CFrame.new(-W / 2 + 80, 0.71, 26), C(255, 0, 200), M.Neon, nil, { Transparency = 0.2 })
		L.supercar(cm, c * CFrame.new(-W / 2 + 80, 0.8, 26) * CFrame.Angles(0, 0.6, 0), C(255, 200, 0), true)
		-- light towers + neon arch
		for _, q in ipairs({ { -W / 2 + 3, -D / 2 + 3 }, { W / 2 - 3, -D / 2 + 3 }, { -W / 2 + 3, D / 2 - 3 }, { W / 2 - 3, D / 2 - 3 } }) do
			L.B(cm, c, q[1], 0, q[2], 1.2, 30, 1.2, C(40, 40, 44), M.Metal)
			local hd = L.BD(cm, c, q[1], 30, q[2], 5, 1.4, 5, C(255, 255, 240), M.Neon)
			local sl = Instance.new("SpotLight")
			sl.Face = Enum.NormalId.Bottom
			sl.Range = 60
			sl.Angle = 80
			sl.Brightness = 2
			sl.Shadows = false
			sl.Parent = hd
		end
		local arch = L.sign(cm, c * CFrame.new(0, 16, D / 2 - 1) * CFrame.Angles(0, math.pi, 0), 40, 6, "SOHO CAR MEET", C(10, 10, 12), C(255, 0, 200), Enum.Font.Bangers, { both = true, dist = 600, lit = true })
		for _, x in ipairs({ -21, 21 }) do L.B(cm, c, x, 0, D / 2 - 1, 1, 19, 1, C(30, 30, 34), M.Metal) end
		-- DJ booth + speakers + bleachers
		L.B(cm, c, W / 2 - 10, 0, 0, 10, 3, 8, C(20, 20, 22), M.Metal)
		L.BD(cm, c, W / 2 - 10, 3, -3.6, 9, 0.3, 0.3, C(0, 220, 255), M.Neon)
		for _, z in ipairs({ -7, 7 }) do L.B(cm, c, W / 2 - 4, 0, z, 3, 7, 3, C(16, 16, 18), M.Metal) end
		for r = 0, 3 do L.B(cm, c, -W / 2 + 6 + r * 2.4, r * 1.4, 0, 2.4, 1.4, 30, C(150, 152, 156), M.Metal, "MetalPlate") end
		L.footprint(LM, c, W + 2, D + 2)
		L.poi((c * CFrame.new(0, 0, 0)).Position, "Park", "SoHo Car Meet", { Note = "Show off your cars" })
		L.poi((c * CFrame.new(W / 2 - 10, 0, 0)).Position, "Job", "Car Meet DJ", { Job = "DJ", Pay = 80 })
	end

	-- ===== SoHo arch over North Ave + string lights across the streets =====
	do
		local ar = L.model(LM, "SoHoArch")
		local c = at(190, -830)
		for _, x in ipairs({ -36, 36 }) do L.B(ar, c, x, 0, 0, 2, 26, 2, C(30, 30, 32), M.Metal) end
		L.B(ar, c, 0, 26, 0, 74, 2, 2, C(30, 30, 32), M.Metal)
		local s = L.sign(ar, c * CFrame.new(0, 30, 0), 36, 5, "SOHO VICE", C(16, 16, 18), C(222, 190, 110), Enum.Font.Merriweather, { both = true, dist = 600, lit = true })
	end
	local function stringLights(a, b, y, n)
		local m = L.model(LM, "StringLights")
		for k = 0, n do
			local p = a:Lerp(b, k / n)
			local sag = math.sin(k / n * math.pi) * 2.5
			L.D(m, Vector3.new(0.7, 0.7, 0.7), CFrame.new(p + Vector3.new(0, y - sag, 0)), C(255, 220, 150), M.Neon, nil, { Shape = Enum.PartType.Ball })
		end
	end
	for z = -1100, -700, 36 do
		stringLights(Vector3.new(66, G, z), Vector3.new(94, G, z), 18, 8) -- across NE 2 Ave
	end
	for x = 110, 250, 30 do
		stringLights(Vector3.new(x, G, -989), Vector3.new(x, G, -961), 18, 8) -- across NE 14/36 St
		stringLights(Vector3.new(x, G, -704), Vector3.new(x, G, -676), 18, 8)
	end

	-- ===== lofts along every SoHo street =====
	local built = L.fill(B, net, function(x, z, st, side, e)
		if not (x > 70 and x < 296 and z > -1115 and z < -686) then return nil end
		return { kind = "loft", w = L.r(28, 42), d = L.r(36, 42), gap = 0 }
	end)
	local parts = 0
	for _, d in ipairs(B:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end
	for _, d in ipairs(LM:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end
	return "soho lofts " .. built .. ", parts " .. parts
end
