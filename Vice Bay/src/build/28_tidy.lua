-- 28 tidy: map-wide placement pass after any rebuild.
-- 1) vegetation: any tree / palm / bush / plant / mangrove whose base stands on a carriageway (asphalt, junction,
--    bend, cul-de-sac, road deck) or within 1.2 studs of a curb is removed. Verge / median palms stand on grass
--    strips or medians and are kept.
-- 2) road overlaps: road surfaces of different streets that overlap at (almost) the same height z-fight; the
--    lower-priority slab is nudged 0.03 below so one surface always wins. Reports what it found.
return function(L)
	local VB = workspace.ViceBay
	local SURF = { Asphalt = true, Junction = true, Bend = true, CulDeSac = true }
	local roadParts = {}
	for _, f in ipairs({ VB:FindFirstChild("Roads"), VB:FindFirstChild("CountyRoads"), VB:FindFirstChild("CoralCauseway"), VB:FindFirstChild("Highway"), VB:FindFirstChild("Islands"), VB:FindFirstChild("Expressway"), VB:FindFirstChild("PortSol"), VB:FindFirstChild("Airport"), VB:FindFirstChild("HoodWest") }) do
		if f then
			for _, p in ipairs(f:GetDescendants()) do
				if p:IsA("BasePart") and (SURF[p.Name] or (p.Material == Enum.Material.Asphalt and p.Size.Y <= 1 and p.Size.X >= 10)) then table.insert(roadParts, p) end
			end
		end
	end
	-- medians / verges sit ON the asphalt: include them so a palm standing on one hits it first and is kept
	local keepParts = {}
	for _, f in ipairs({ VB:FindFirstChild("Roads"), VB:FindFirstChild("CountyRoads"), VB:FindFirstChild("CoralCauseway"), VB:FindFirstChild("PortSol"), VB:FindFirstChild("Airport"), VB:FindFirstChild("HoodWest") }) do
		if f then for _, p in ipairs(f:GetDescendants()) do if p:IsA("BasePart") and (p.Name == "Median" or p.Name == "Sidewalk") then table.insert(keepParts, p) end end end
	end
	local all = table.clone(roadParts)
	for _, p in ipairs(keepParts) do table.insert(all, p) end
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = all
	local VEG = { Tree = true, Palm = true, Bush = true, Plant = true, Mangrove = true, ["Oak Tree"] = true, ["Plam Tree"] = true }
	local removed, checked = 0, 0
	local list = {}
	for _, m in ipairs(VB:GetDescendants()) do
		if m:IsA("Model") and VEG[m.Name] then table.insert(list, m) end
	end
	for i, m in ipairs(list) do
		if m.Parent then
			checked += 1
			local base = m:GetPivot().Position
			local hit = false
			for _, o in ipairs({ Vector3.zero, Vector3.new(1.2, 0, 0), Vector3.new(-1.2, 0, 0), Vector3.new(0, 0, 1.2), Vector3.new(0, 0, -1.2) }) do
				local r = workspace:Raycast(base + o + Vector3.new(0, 4, 0), Vector3.new(0, -7, 0), rp)
				if r and SURF[r.Instance.Name] or (r and r.Instance.Name ~= "Median" and r.Instance.Name ~= "Sidewalk" and r.Instance.Material == Enum.Material.Asphalt) then hit = true break end
			end
			if hit then m:Destroy() removed += 1 end
		end
		if i % 400 == 0 then task.wait() end
	end
	-- road overlaps
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Include
	op.FilterDescendantsInstances = roadParts
	local fights, examples = 0, {}
	local seen = {}
	for i, a in ipairs(roadParts) do
		if a.Name == "Asphalt" then
			local topA = a.Position.Y + a.Size.Y / 2
			for _, b in ipairs(workspace:GetPartsInPart(a, op)) do
				if b ~= a and b.Parent ~= a.Parent and not seen[b] and b.Name ~= "Junction" and b.Name ~= "Bend" and b.Name ~= "CulDeSac" then
					local topB = (b.Shape == Enum.PartType.Cylinder) and (b.Position.Y + b.Size.X / 2) or (b.Position.Y + b.Size.Y / 2)
					if math.abs(topA - topB) < 0.015 then
						fights += 1
						if #examples < 10 then table.insert(examples, string.format("%s / %s @%.0f,%.0f", a.Parent.Name, b.Parent.Name, a.Position.X, a.Position.Z)) end
						-- the shorter slab yields
						local loser = (a.Size.Magnitude < b.Size.Magnitude) and a or b
						loser.CFrame = loser.CFrame - Vector3.new(0, 0.04, 0)
					end
				end
			end
			seen[a] = true
		end
		if i % 300 == 0 then task.wait() end
	end
	return string.format("vegetation checked %d removed %d | road z-fights fixed %d\n%s", checked, removed, fights, table.concat(examples, "\n"))
end
