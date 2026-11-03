-- 24 metro: Vice Metro station entrances on the widest downtown sidewalks.
-- Stairs drop into a tiled pit (terrain carved) toward a lit "TRAINS" portal; glass canopy, steel balustrade,
-- totem pylon with the lit M cube. Tagged MetroStation (POI) for the game's fast travel.
return function(L)
	local M, C = L.M, L.C
	local VB = workspace.ViceBay
	local root = L.folder(VB, "Metro")
	root:ClearAllChildren()
	local NAMES = { "Government Center", "Bayfront Park", "Brickell", "Flagler Station", "Riverwalk" }
	local LINE = { C(230, 160, 30), C(30, 130, 210), C(40, 170, 90) }
	local cands = {}
	for _, seg in ipairs(VB.Roads:GetChildren()) do
		local n = seg.Name
		if seg:IsA("Model") and (n:match("Flagler") or n:match("Biscayne") or n:match("Brickell") or n:match("Miami Ave") or n:match("SE 1 St") or n:match("Bayfront")) then
			for _, p in ipairs(seg:GetChildren()) do
				if p:IsA("BasePart") and p.Name == "Sidewalk" and p.Size.Z > 80 and p.Size.X >= 11 and p.Position.X > 250 and p.Position.X < 1500 then
					table.insert(cands, p)
				end
			end
		end
	end
	table.sort(cands, function(a, b) return a.Size.Z > b.Size.Z end)
	local placed = {}
	for _, p in ipairs(cands) do
		if #placed >= 4 then break end
		local ok = true
		for _, q in ipairs(placed) do if (q - p.Position).Magnitude < 260 then ok = false end end
		if ok then
			local k = #placed + 1
			local top = p.Position.Y + p.Size.Y / 2
			local rot = p.CFrame - p.Position
			local pos = (p.CFrame * CFrame.new(0, 0, p.Size.Z * 0.22)).Position
			local base = CFrame.new(pos.X, top, pos.Z) * rot
			table.insert(placed, pos)
			L.cutSidewalk(base * CFrame.new(0, -0.5, 0), Vector3.new(6.4, 3, 17.4))
			workspace.Terrain:FillBlock(base * CFrame.new(0, -6.5, 0), Vector3.new(6.4, 13, 17.4), Enum.Material.Air)
			local m = L.model(root, "MetroEntrance")
			local TILE = C(226, 228, 226)
			-- stairs (top at z=-8, landing at the bottom end)
			local n, drop = 14, 10
			for s = 1, n do
				local ty = -s * drop / n
				L.P(m, Vector3.new(5.2, drop / n + 0.1, 0.9), base * CFrame.new(0, ty - drop / n / 2, -8 + (s - 0.5) * 0.86), C(190, 190, 186), M.Concrete, "ConcretePlain")
				L.D(m, Vector3.new(5.2, 0.06, 0.2), base * CFrame.new(0, ty + 0.03, -8 + (s - 1) * 0.86 + 0.12), C(226, 186, 40), M.SmoothPlastic)
			end
			L.P(m, Vector3.new(5.2, 1, 4.2), base * CFrame.new(0, -drop - 0.5, 6.3), C(196, 196, 192), M.CeramicTiles, "PlazaTiles")
			-- tiled pit walls + far wall with the lit portal
			for sd = -1, 1, 2 do
				L.P(m, Vector3.new(0.6, drop + 1.6, 17), base * CFrame.new(sd * 2.9, -drop / 2 - 0.2, 0), TILE, M.CeramicTiles, "PlazaTiles")
				L.D(m, Vector3.new(0.1, 0.3, 15), base * CFrame.new(sd * 2.55, -drop + 6.5, 0.5), C(255, 246, 228), M.Neon)
				L.D(m, Vector3.new(0.12, 1.2, 15), base * CFrame.new(sd * 2.56, -drop + 1.4, 0.5), LINE[(k - 1) % 3 + 1], M.SmoothPlastic)
			end
			L.P(m, Vector3.new(6.4, drop + 1.6, 0.6), base * CFrame.new(0, -drop / 2 - 0.2, 8.6), TILE, M.CeramicTiles, "PlazaTiles")
			L.P(m, Vector3.new(6.4, drop + 1.6, 0.6), base * CFrame.new(0, -drop / 2 - 0.2, -8.6), TILE, M.CeramicTiles, "PlazaTiles")
			local portal = L.D(m, Vector3.new(4, 7, 0.1), base * CFrame.new(0, -drop + 3.5, 8.26), C(255, 244, 222), M.Neon, nil, { Transparency = 0.15 })
			local sg = L.D(m, Vector3.new(4.6, 1.2, 0.1), base * CFrame.new(0, -drop + 7.8, 8.24), C(24, 24, 28), M.SmoothPlastic)
			L.text(sg, Enum.NormalId.Back, "TRAINS  ➜", { font = Enum.Font.GothamBlack, color = C(255, 206, 40), pps = 30, dist = 120 })
			local pl = Instance.new("PointLight")
			pl.Range, pl.Brightness, pl.Color, pl.Shadows = 18, 1.2, C(255, 240, 220), false
			pl.Parent = portal
			-- balustrade (glass + steel cap) around the opening
			for _, q in ipairs({ { 3.1, 0, 0.15, 17.2 }, { -3.1, 0, 0.15, 17.2 }, { 0, 8.55, 6.4, 0.15 } }) do
				L.D(m, Vector3.new(q[3], 3.4, q[4]), base * CFrame.new(q[1], 1.7, q[2]), C(170, 196, 204), M.Glass, nil, { Transparency = 0.55, CanCollide = true })
				L.D(m, Vector3.new(math.max(q[3], 0.3), 0.25, math.max(q[4], 0.3)), base * CFrame.new(q[1], 3.45, q[2]), C(150, 154, 158), M.Metal)
			end
			-- glass canopy on four slim posts
			for _, q in ipairs({ { -3.1, -7.8 }, { 3.1, -7.8 }, { -3.1, 7.8 }, { 3.1, 7.8 } }) do L.P(m, Vector3.new(0.35, 9.4, 0.35), base * CFrame.new(q[1], 4.7, q[2]), C(60, 64, 68), M.Metal) end
			L.P(m, Vector3.new(7.4, 0.5, 18.4), base * CFrame.new(0, 9.6, 0) * CFrame.Angles(math.rad(2), 0, 0), C(60, 64, 68), M.Metal)
			L.D(m, Vector3.new(6.8, 0.1, 17.8), base * CFrame.new(0, 9.9, 0) * CFrame.Angles(math.rad(2), 0, 0), C(160, 196, 210), M.Glass, nil, { Transparency = 0.4 })
			local strip = L.D(m, Vector3.new(6.6, 0.1, 0.4), base * CFrame.new(0, 9.32, -7.5), C(255, 244, 222), M.Neon)
			-- totem pylon with the lit M cube
			local tc = base * CFrame.new(0, 0, -11.2)
			L.P(m, Vector3.new(1.6, 10, 1.6), tc * CFrame.new(0, 5, 0), C(40, 42, 46), M.Metal)
			local cube = L.D(m, Vector3.new(2.2, 2.2, 2.2), tc * CFrame.new(0, 11.1, 0), C(255, 206, 40), M.Neon)
			for _, f in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do
				L.text(cube, f, "M", { font = Enum.Font.GothamBlack, color = C(24, 24, 28), size = UDim2.fromScale(0.9, 0.9), pos = UDim2.fromScale(0.05, 0.05), pps = 30, dist = 400, light = 0 })
			end
			local nm = NAMES[k]
			local pn = L.D(m, Vector3.new(1.62, 5.4, 1.62), tc * CFrame.new(0, 6.2, 0), C(40, 42, 46), M.Metal)
			for _, f in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
				L.text(pn, f, "VICE\nMETRO\n\n" .. string.upper(nm), { font = Enum.Font.GothamBold, color = Color3.new(1, 1, 1), size = UDim2.fromScale(0.9, 0.9), pos = UDim2.fromScale(0.05, 0.05), pps = 30, dist = 160 })
			end
			for li = 1, 3 do L.D(m, Vector3.new(1.64, 0.35, 1.64), tc * CFrame.new(0, 2.4 + li * 0.45, 0), LINE[li], M.SmoothPlastic) end
			pcall(function() L.poi(pos, "Metro", nm .. " Station", {}) end)
			task.wait()
		end
	end
	return "metro entrances: " .. #placed .. " (candidates " .. #cands .. ")"
end
