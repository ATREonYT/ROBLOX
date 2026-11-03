-- 06 I-95: elevated 6-lane highway through the rail corridor (x -810), climbing from Shore Rd,
-- crossing the river high up, coming back to grade at Port Blvd. Flagler St exit + on-ramp.
return function(L)
	local G = L.G
	local H = L.root("Highway")
	H:ClearAllChildren()
	local TOP = G + 34
	local X = -810
	local function smooth(t) t = math.clamp(t, 0, 1) return t * t * (3 - 2 * t) end
	local function prof(z)
		if z < -760 then return G + 0.3 + (TOP - G - 0.3) * smooth((z + 1066) / 306) end
		if z > 600 then return G + 0.3 + (TOP - G - 0.3) * smooth((930 - z) / 330) end
		return TOP
	end
	local pts = {}
	for z = -1066, 930, 16 do table.insert(pts, Vector3.new(X, prof(z), z)) end
	table.insert(pts, Vector3.new(X, G + 0.3, 930))
	-- arc length helper: s = z + 1066 (straight line)
	local function s(z) return z + 1066 end
	L.road3D(H, pts, 84, {
		name = "I-95", median = true, lanes = 3, lights = 140, pierStep = 64,
		gaps = { { s(-800), s(-736), 1 } },
	})
	-- SB exit to Flagler (west side): leaves the deck at z -790, lands at z -440
	local ex = {}
	for k = 0, 22 do
		local t = k / 22
		local z = -790 + t * 350
		local x = -866 - 4 * smooth(math.min(1, t * 4))
		local y = TOP - (TOP - G - 0.3) * smooth((t - 0.08) / 0.92)
		table.insert(ex, Vector3.new(x, y, z))
	end
	L.road3D(H, ex, 26, { name = "Exit 3 Flagler St", lanes = 0, pierStep = 50 })
	L.cutSidewalk(CFrame.new(-870, G + 0.5, -448), Vector3.new(30, 2, 12))
	-- (the east-side on-ramp was removed when the highway was widened to 84: the frontage road needs that space;
	-- traffic joins I-95 at the at-grade ends on Shore Rd and Port Blvd)
	-- sign gantries
	L.gantry(H, Vector3.new(X, TOP, -980 + 60), Vector3.new(0, 0, -1), 84, "EXIT 3  FLAGLER ST", "Downtown  •  Liberty Heights  1/2 MILE")
	L.gantry(H, Vector3.new(X, TOP, 260), Vector3.new(0, 0, 1), 84, "I-95 SOUTH", "Port of Vice Bay  •  Little Habana")
	local n = 0
	for _, d in ipairs(H:GetDescendants()) do if d:IsA("BasePart") then n += 1 end end
	return "highway ok, parts " .. n
end
