-- 37 run-down hood roads (Larp references): dark worn asphalt (stock Asphalt material, the MatPack concrete
-- remap made the hood look clean), big brown / wet blotches, light-rimmed patch repairs, crack lines, oily
-- gutters. All decals are thin non-colliding, non-query parts in RoadWear/HoodWear. Re-run after any road rebuild.
return function(L)
	local M, C = L.M, L.C
	local VB = workspace.ViceBay
	local RWf = L.folder(VB, "RoadWear")
	local old = RWf:FindFirstChild("HoodWear")
	if old then old:Destroy() end
	local HW = L.model(RWf, "HoodWear")
	local rng = Random.new(3737)
	local function r(a, b) return a + rng:NextNumber() * (b - a) end
	local X0, X1, Z0, Z1 = -2060, -920, -1165, 965
	local function inHood(p) return p.X > X0 and p.X < X1 and p.Z > Z0 and p.Z < Z1 end

	-- remove the older, lighter wear decals inside the hood
	local removed = 0
	for _, d in ipairs(RWf:GetChildren()) do
		if d ~= HW then
			for _, q in ipairs(d:IsA("BasePart") and { d } or d:GetDescendants()) do
				if q:IsA("BasePart") and inHood(q.Position) then q:Destroy() removed += 1 end
			end
		end
	end

	local function ellipse(cf, a, b, col, t)
		return L.D(HW, Vector3.new(0.04, a, b), cf * CFrame.Angles(0, r(0, math.pi), math.pi / 2), col, M.SmoothPlastic, nil, { Shape = Enum.PartType.Cylinder, Transparency = t })
	end
	local STAIN = { { C(70, 60, 50), 0.55 }, { C(22, 22, 24), 0.5 }, { C(60, 54, 48), 0.6 } }
	local IMG = { "rbxassetid://118775947", "rbxassetid://182906320", "rbxassetid://182906320", "rbxassetid://118775947" }
	local function decalStain(tcf, lx, lz, size, img, tr)
		local p = L.D(HW, Vector3.new(size, 0.05, size * r(0.8, 1.3)), tcf * CFrame.new(lx, 0.02, lz) * CFrame.Angles(0, r(0, math.pi * 2), 0), C(255, 255, 255), M.SmoothPlastic, nil, { Transparency = 1 })
		local d = Instance.new("Decal")
		d.Texture = img
		d.Face = Enum.NormalId.Top
		d.Transparency = tr
		d.Parent = p
	end
	local function blotch(tcf, lx, lz, s)
		if true then
			decalStain(tcf, lx, lz, s * r(1.8, 3), IMG[rng:NextInteger(1, #IMG)], r(0.05, 0.35))
			return
		end
		local st = STAIN[rng:NextInteger(1, #STAIN)]
		for k = 0, rng:NextInteger(1, 3) do
			ellipse(tcf * CFrame.new(lx + r(-s, s) * 0.5, 0.012 + k * 0.003, lz + r(-s, s)), r(s * 0.6, s * 1.4), r(s * 0.8, s * 2.2), st[1], st[2] + r(-0.08, 0.1))
		end
	end
	local function patch(tcf, lx, lz, pw, pl)
		local c = tcf * CFrame.new(lx, 0, lz) * CFrame.Angles(0, r(-0.06, 0.06), 0)
		L.D(HW, Vector3.new(pw + 1, 0.03, pl + 1), c * CFrame.new(0, 0.03, 0), C(122, 120, 114), M.SmoothPlastic, nil, { Transparency = 0.15 })
		L.D(HW, Vector3.new(pw, 0.03, pl), c * CFrame.new(0, 0.07, 0), C(30, 30, 32), M.SmoothPlastic, nil, { Transparency = 0.02 })
		-- rounded rim ends
		for _, sd in ipairs({ -1, 1 }) do
			L.D(HW, Vector3.new(0.03, pw + 1, 2.4), c * CFrame.new(0, 0.03, sd * (pl / 2 + 0.5)) * CFrame.Angles(0, 0, math.pi / 2), C(122, 120, 114), M.SmoothPlastic, nil, { Shape = Enum.PartType.Cylinder, Transparency = 0.15 })
		end
	end
	local function crack(tcf, lx, lz, len)

		local p = Vector3.new(lx, 0.04, lz)
		local ang = r(0, math.pi)
		local n = rng:NextInteger(3, 5)
		for _ = 1, n do
			ang += r(-0.9, 0.9)
			local seg = len / n
			local q = p + Vector3.new(math.cos(ang) * seg, 0, math.sin(ang) * seg)
			local a, b = (tcf * CFrame.new(p)).Position, (tcf * CFrame.new(q)).Position
			L.D(HW, Vector3.new(r(0.18, 0.32), 0.03, (b - a).Magnitude + 0.2), CFrame.lookAt((a + b) / 2, b), C(26, 26, 28), M.SmoothPlastic, nil, { Transparency = 0.25 })
			p = q
		end
	end

	local segs, decals0 = 0, #HW:GetChildren()
	local folders = { VB:FindFirstChild("Roads"), VB:FindFirstChild("HoodWest"), VB:FindFirstChild("HoodNorth") }
	for _, f in ipairs(folders) do
		if f then
			for _, p in ipairs(f:GetDescendants()) do
				if p:IsA("BasePart") and p.Material == M.Asphalt and inHood(p.Position) and p.Size.Y < 2 then
					if p.Name == "Asphalt" then
						-- dark, worn, stock asphalt texture
						p.MaterialVariant = ""
						local g = r(38, 46)
						p.Color = Color3.fromRGB(g, g, g + 2)
						local w, len = p.Size.X, p.Size.Z
						local tcf = p.CFrame * CFrame.new(0, p.Size.Y / 2, 0)
						for _ = 1, math.ceil(len / 24) do blotch(tcf, r(-w / 2 + 3, w / 2 - 3), r(-len / 2 + 4, len / 2 - 4), r(5, 12)) end
						for _ = 1, math.max(1, math.floor(len / 85 + rng:NextNumber())) do
							patch(tcf, r(-w / 2 + 6, w / 2 - 6), r(-len / 2 + 10, len / 2 - 10), r(5, math.min(12, w * 0.3)), r(7, 18))
						end
						for _ = 1, math.floor(len / 70 + rng:NextNumber()) do crack(tcf, r(-w / 2 + 3, w / 2 - 3), r(-len / 2 + 6, len / 2 - 6), r(8, 20)) end
						-- oily gutters along both curbs
						for _, sd in ipairs({ -1, 1 }) do
							L.D(HW, Vector3.new(2.2, 0.03, len - 2), tcf * CFrame.new(sd * (w / 2 - 1.2), 0.01, 0), C(48, 44, 40), M.SmoothPlastic, nil, { Transparency = 0.55 })
						end
						segs += 1
					elseif p.Name == "Junction" or p.Name == "Bend" then
						p.MaterialVariant = ""
						local g = r(38, 46)
						p.Color = Color3.fromRGB(g, g, g + 2)
						local top = CFrame.new(p.Position + Vector3.new(0, p.Size.X / 2, 0))
						local rad = p.Size.Y / 2
						for _ = 1, (p.Name == "Junction") and 3 or 1 do blotch(top, r(-rad * 0.5, rad * 0.5), r(-rad * 0.5, rad * 0.5), r(4, 8)) end
						if p.Name == "Junction" and rng:NextNumber() < 0.5 then crack(top, r(-rad * 0.4, rad * 0.4), r(-rad * 0.4, rad * 0.4), r(10, 18)) end
					end
				end
			end
			task.wait()
		end
	end
	-- faded paint on hood streets (keeps the bold look but shows wear)
	local faded = 0
	for _, f in ipairs(folders) do
		if f then
			for _, p in ipairs(f:GetDescendants()) do
				if p:IsA("BasePart") and p.Size.Y <= 0.06 and p.Material == M.SmoothPlastic and inHood(p.Position) and p.Transparency < 0.2 and not p:IsDescendantOf(HW) then
					local c = p.Color
					if (c.R > 0.85 and c.G > 0.85) or (c.R > 0.8 and c.G > 0.6 and c.B < 0.4) then
						p.Transparency = r(0.12, 0.3)
						faded += 1
					end
				end
			end
		end
	end
	return string.format("hood roads: %d slabs worn, decals %d (removed %d old), markings faded %d", segs, #HW:GetChildren() - decals0, removed, faded)
end
