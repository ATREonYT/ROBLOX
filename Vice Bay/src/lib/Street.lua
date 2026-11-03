-- Vice Bay: street furniture by district tier, called per road side from Roads.buildRoads.
--   tier 1 (hood):       corner street-name posts only (the hood has its own clutter: poles, wires, trash)
--   tier 2 (Habana, Wynwood): + pedestrian signals, tactile pads, newspaper boxes, benches, some signs
--   tier 3 (downtown, boulevards): + parking meters, bike racks, no-parking / speed / one-way signs,
--                                    "ONLY" lane text, bus lanes, tree grates, wayfinding to the metro
-- Everything is cheap (a few parts per item, SurfaceGui text), placed on the sidewalk clear of the curb.
return function(L)
	local M, C = L.M, L.C
	local INK = C(30, 32, 34)
	local POLE = C(84, 88, 92)
	local GREEN = C(18, 104, 62)

	local function plate(m, cf, w, h, bg, txt, fg, font, sizeK)
		local p = L.D(m, Vector3.new(w, h, 0.08), cf, bg, M.SmoothPlastic)
		if txt then
			L.text(p, Enum.NormalId.Front, txt, { font = font or Enum.Font.GothamBold, color = fg or Color3.new(1, 1, 1), size = UDim2.fromScale(0.92, sizeK or 0.8), pos = UDim2.fromScale(0.04, (1 - (sizeK or 0.8)) / 2), pps = 30, dist = 140 })
			L.text(p, Enum.NormalId.Back, txt, { font = font or Enum.Font.GothamBold, color = fg or Color3.new(1, 1, 1), size = UDim2.fromScale(0.92, sizeK or 0.8), pos = UDim2.fromScale(0.04, (1 - (sizeK or 0.8)) / 2), pps = 30, dist = 140 })
		end
		return p
	end
	L.signPlate = plate

	-- corner post with two crossed street-name blades
	function L.streetNamePost(m, pos, dirAlong, nameA, nameB)
		local cf = CFrame.lookAt(pos, pos + dirAlong)
		L.Cyl(m, 12, 0.3, cf * CFrame.new(0, 6, 0), POLE, M.Metal)
		local function blade(c, name, y)
			plate(m, c * CFrame.new(0, y, -2.2), 5.6, 1, GREEN, string.upper(name or ""), Color3.new(1, 1, 1), Enum.Font.Highway, 0.74)
		end
		blade(cf * CFrame.Angles(0, math.pi / 2, 0), nameA, 11.3)
		blade(cf, nameB, 12.4)
	end

	-- pedestrian signal head (walk man / hand) + push button, facing across the crosswalk
	function L.pedSignal(m, cf)
		L.Cyl(m, 9, 0.35, cf * CFrame.new(0, 4.5, 0), POLE, M.Metal)
		local box = L.D(m, Vector3.new(1.4, 1.4, 0.8), cf * CFrame.new(0, 8.2, -0.5), C(36, 38, 34), M.Metal)
		local face = L.D(m, Vector3.new(1.1, 1.1, 0.05), cf * CFrame.new(0, 8.2, -0.92), C(20, 20, 20), M.SmoothPlastic)
		L.text(face, Enum.NormalId.Front, "✋", { font = Enum.Font.GothamBold, color = C(255, 120, 30), size = UDim2.fromScale(1, 1), pos = UDim2.fromScale(0, 0), pps = 40, dist = 90, light = 0 })
		L.D(m, Vector3.new(0.6, 0.9, 0.35), cf * CFrame.new(0, 3.8, -0.3), C(196, 170, 60), M.Metal)
	end

	local function meter(m, cf)
		L.Cyl(m, 3.6, 0.22, cf * CFrame.new(0, 1.8, 0), INK, M.Metal)
		local hd = L.D(m, Vector3.new(0.7, 1, 0.5), cf * CFrame.new(0, 4, 0), C(56, 60, 66), M.Metal)
		return hd
	end
	local function newsBoxes(m, cf)
		local cols = { C(196, 40, 40), C(30, 70, 150), C(230, 190, 40), C(40, 120, 70), C(236, 236, 230) }
		for k = 0, 2 do
			local c = cf * CFrame.new((k - 1) * 1.7, 0, 0)
			L.B(m, c, 0, 0, 0, 1.5, 2.8, 1.4, L.pick(cols), M.Metal)
		end
	end
	local function bikeRack(m, cf)
		for k = 0, 2 do
			local c = cf * CFrame.new((k - 1) * 1.6, 0, 0)
			for sd = -1, 1, 2 do L.BD(m, c, 0, 0, sd * 0.9, 0.18, 2.6, 0.18, C(150, 154, 158), M.Metal) end
			L.BD(m, c, 0, 2.5, 0, 0.18, 0.18, 1.98, C(150, 154, 158), M.Metal)
		end
	end
	local function signPost(m, cf, kind)
		L.Cyl(m, 8.5, 0.2, cf * CFrame.new(0, 4.25, 0), POLE, M.Metal)
		if kind == "noparking" then
			plate(m, cf * CFrame.new(0, 7.4, -0.15), 1.6, 2.2, C(240, 240, 236), "NO\nPARKING\nANY TIME", C(200, 30, 30), Enum.Font.GothamBold, 0.86)
		elseif kind == "speed" then
			plate(m, cf * CFrame.new(0, 7.4, -0.15), 1.7, 2.2, C(240, 240, 236), "SPEED\nLIMIT\n30", INK, Enum.Font.Highway, 0.88)
		elseif kind == "oneway" then
			plate(m, cf * CFrame.new(0, 7.6, -0.15) * CFrame.Angles(0, math.pi / 2, 0), 3.4, 1.1, INK, "ONE WAY  ➜", Color3.new(1, 1, 1), Enum.Font.GothamBold, 0.7)
		elseif kind == "tow" then
			plate(m, cf * CFrame.new(0, 7.4, -0.15), 1.6, 2.2, C(240, 240, 236), "TOW\nAWAY\nZONE", C(200, 30, 30), Enum.Font.GothamBold, 0.86)
		elseif kind == "bus" then
			plate(m, cf * CFrame.new(0, 7.4, -0.15), 1.8, 1.8, C(18, 84, 160), "🚌\nBUS STOP", Color3.new(1, 1, 1), Enum.Font.GothamBold, 0.86)
		elseif kind == "metro" then
			plate(m, cf * CFrame.new(0, 7.6, -0.15) * CFrame.Angles(0, math.pi / 2, 0), 4.2, 1.1, C(24, 24, 28), "Ⓜ  METRO  ➜", C(255, 206, 40), Enum.Font.GothamBlack, 0.72)
		end
	end
	L.streetSignPost = signPost

	-- one side of one road segment
	-- o: { tier, cf0, side, hw, sw, h, l0, l1, corner1, corner2, name, cross1, cross2, signal1, signal2, oneway }
	function L.streetSide(seg, o)
		local tier = o.tier or 1
		local sw = o.sw or 0
		if sw < 6 then return end
		local side, hw, cf0, h = o.side, o.hw, o.cf0, o.h
		local len = o.l1 - o.l0
		local m = Instance.new("Model")
		m.Name = "StreetFurniture"
		local function F(z, off, faceRoad)
			-- frame on the sidewalk: off = distance behind the curb; -Z faces the road if faceRoad, else runs along the street
			local p = (cf0 * CFrame.new(side * (hw + off), h, -z)).Position
			local toRoad = cf0:VectorToWorldSpace(Vector3.new(-side, 0, 0))
			local along = cf0:VectorToWorldSpace(Vector3.new(0, 0, -1))
			return CFrame.lookAt(p, p + (faceRoad and toRoad or along))
		end
		local along = cf0:VectorToWorldSpace(Vector3.new(0, 0, -1))
		-- corners (right-hand corner of each approach so every corner is done exactly once)
		for k = 1, 2 do
			if o["corner" .. k] then
				local z = (k == 1) and (o.l0 + 1.6) or (o.l1 - 1.6)
				local zc = (k == 1) and (o.l0 + 5) or (o.l1 - 5)
				local fz = F(z, 1.4, false)
				L.streetNamePost(m, fz.Position, along, o.name, o["cross" .. k])
				if tier >= 2 then
					-- tactile pad at the curb ramp + pedestrian signal facing across the crosswalk
					L.BD(m, F(zc, 1.2, true), 0, 0, 0, 7, 0.06, 1.8, C(226, 186, 40), M.DiamondPlate)
					if o["signal" .. k] then L.pedSignal(m, F(zc + ((k == 1) and 5 or -5), 1.2, false) * CFrame.Angles(0, (k == 1) and math.pi or 0, 0)) end
				end
				if tier == 3 and L.chance(0.45) then newsBoxes(m, F((k == 1) and (o.l0 + 9) or (o.l1 - 9), sw - 1.4, true) * CFrame.Angles(0, math.pi, 0)) end
				if tier == 3 and L.chance(0.5) then signPost(m, F((k == 1) and (o.l0 + 13) or (o.l1 - 13), 1.2, true) * CFrame.Angles(0, math.pi / 2 * side, 0), o.oneway and "oneway" or "tow") end
			end
		end
		if tier >= 2 and len > 70 then
			-- mid-block: bench + bike rack (tier 3), no-parking / speed signs
			local zm = o.l0 + len * L.r(0.35, 0.65)
			if L.chance(0.6) then L.bench(m, F(zm, sw - 1.6, true) * CFrame.Angles(0, math.pi, 0)) end
			if tier == 3 and L.chance(0.7) then bikeRack(m, F(zm + 8, 2.6, false)) end
			if L.chance(0.7) then signPost(m, F(o.l0 + 22, 1.1, true) * CFrame.Angles(0, math.pi, 0), L.pick({ "noparking", "speed", "noparking" })) end
		end
		if tier == 3 and len > 60 then
			-- parking meters along the curb (skip the corners)
			local z = o.l0 + 18
			while z < o.l1 - 18 do
				meter(m, F(z, 1.3, true))
				z += 54
			end
			if o.metroNear and L.chance(0.5) then signPost(m, F(o.l0 + len * 0.5 + 6, 1.1, true) * CFrame.Angles(0, math.pi / 2 * side, 0), "metro") end
		end
		for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then d.CanCollide = false end end
		m.Parent = seg
	end

	-- painted text on the road ("ONLY", "BUS ONLY", "SLOW"): cf on the surface, -Z = travel direction
	function L.roadText(par, cf, txt, w, l)
		local p = L.D(par, Vector3.new(w or 6, 0.04, l or 3.4), cf, Color3.new(1, 1, 1), M.SmoothPlastic, nil, { Transparency = 1 })
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Top
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 20
		g.LightInfluence = 1
		g.MaxDistance = 220
		g.Parent = p
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Text = txt
		t.TextScaled = true
		t.Font = Enum.Font.Highway
		t.TextColor3 = C(232, 232, 228)
		t.TextTransparency = 0.08
		t.Rotation = 180
		t.Parent = g
		return p
	end
end
