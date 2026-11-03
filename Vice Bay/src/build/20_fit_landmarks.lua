-- 20 fit landmarks to their blocks after the streets were widened for full-size cars.
-- For every hand-placed landmark that touches a road (asphalt or sidewalk): measure the free block around it
-- with rays, move it to the middle of that free space and, if it still doesn't fit, scale it down.
-- Its Footprint part (used by the overlap audit / lot fill) moves and shrinks with it.
return function(L)
	local VB = workspace.ViceBay
	local roadsF = { VB.Roads, VB:FindFirstChild("CountyRoads") }
	local rop = OverlapParams.new()
	rop.FilterType = Enum.RaycastFilterType.Include
	rop.FilterDescendantsInstances = roadsF
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = roadsF
	local SKIP = { MainStreet = true, TheEnds = true, SoHoArch = true, Quay = true, Gangway = true, StringLights = true }
	local function onRoad(inst)
		local list = inst:GetDescendants()
		if inst:IsA("BasePart") then table.insert(list, inst) end
		for _, p in ipairs(list) do
			if p:IsA("BasePart") and p.Transparency < 1 and p.Size.Magnitude > 2 and p.Position.Y < L.G + 30 then
				for _, q in ipairs(workspace:GetPartBoundsInBox(p.CFrame, p.Size - Vector3.new(0.6, 0, 0.6), rop)) do
					if q.Name == "Asphalt" or q.Name == "Sidewalk" then return true end
				end
			end
		end
		return false
	end
	local function free(c, dir)
		-- distance from c to the first road surface in direction dir (rays at curb height, a few lateral samples)
		local best = 400
		for _, off in ipairs({ -12, 0, 12 }) do
			local lat = Vector3.new(dir.Z, 0, -dir.X) * off
			local r = workspace:Raycast(c + lat + Vector3.new(0, 0.1, 0), dir * 400, rp)
			if r then best = math.min(best, (r.Position - (c + lat)).Magnitude) end
			local r2 = workspace:Raycast(c + lat + Vector3.new(0, 0.6, 0), dir * 400, rp)
			if r2 then best = math.min(best, (r2.Position - (c + lat)).Magnitude) end
		end
		return best
	end
	local moved, scaled = {}, 0
	for _, district in ipairs(VB.Landmarks:GetChildren()) do
		for _, m in ipairs(district:GetChildren()) do
			if m:IsA("Model") and not SKIP[m.Name] and onRoad(m) then
				local cf, sz = m:GetBoundingBox()
				local c = Vector3.new(cf.X, L.G, cf.Z)
				local xp, xn = free(c, Vector3.new(1, 0, 0)), free(c, Vector3.new(-1, 0, 0))
				local zp, zn = free(c, Vector3.new(0, 0, 1)), free(c, Vector3.new(0, 0, -1))
				-- the model's footprint in world X/Z
				local bx, bz = 0, 0
				for _, p in ipairs(m:GetDescendants()) do
					if p:IsA("BasePart") and p.Transparency < 1 and p.Position.Y < L.G + 6 then
						bx = math.max(bx, math.abs(p.Position.X - c.X) + p.Size.X / 2)
						bz = math.max(bz, math.abs(p.Position.Z - c.Z) + p.Size.Z / 2)
					end
				end
				-- smallest move that clears the road on each axis; scale down only if the block is too small
				local fw, fd = xp + xn - 3, zp + zn - 3
				local s = math.min(1, fw / math.max(1, 2 * bx), fd / math.max(1, 2 * bz))
				local hx, hz = bx * s, bz * s
				local sx, sz2 = 0, 0
				if hx > xp - 1.5 then sx -= hx - (xp - 1.5) end
				if hx > xn - 1.5 then sx += hx - (xn - 1.5) end
				if hz > zp - 1.5 then sz2 -= hz - (zp - 1.5) end
				if hz > zn - 1.5 then sz2 += hz - (zn - 1.5) end
				local shift = Vector3.new(sx, 0, sz2)
				if shift.Magnitude < 40 and s > 0.6 then
					local piv = m:GetPivot()
					if s < 0.999 then
						m:ScaleTo(m:GetScale() * s)
						scaled += 1
						-- keep it standing on the ground
						local _, sz2 = m:GetBoundingBox()
						piv = m:GetPivot()
					end
					m:PivotTo(piv + shift)
					-- drop anything that still pokes onto a road (tree, sign, bollard)
					for _, p in ipairs(m:GetDescendants()) do
						if p:IsA("BasePart") and p.Transparency < 1 and p.Position.Y < L.G + 30 then
							for _, q in ipairs(workspace:GetPartBoundsInBox(p.CFrame, p.Size - Vector3.new(0.6, 0, 0.6), rop)) do
								if q.Name == "Asphalt" or q.Name == "Sidewalk" then
									local mm = p:FindFirstAncestorWhichIsA("Model")
									if mm and mm ~= m and (mm.Name == "Tree" or mm.Name == "Palm" or mm.Name == "Bush" or mm.Name == "Plant" or mm.Name == "ParkedCar") then mm:Destroy() else p:Destroy() end
									break
								end
							end
						end
					end
					-- move / shrink the matching footprint
					for _, fp in ipairs(district:GetChildren()) do
						if fp:IsA("BasePart") and fp.Name == "Footprint" and (Vector3.new(fp.Position.X, 0, fp.Position.Z) - Vector3.new(c.X, 0, c.Z)).Magnitude < 25 then
							fp.Size = Vector3.new(fp.Size.X * s, fp.Size.Y, fp.Size.Z * s)
							fp.CFrame = fp.CFrame + shift
						end
					end
					table.insert(moved, string.format("%s(%.0f,%.0f s%.2f)", m.Name, shift.X, shift.Z, s))
				else
					table.insert(moved, "SKIP " .. m.Name .. string.format(" shift %.0f s %.2f", shift.Magnitude, s))
				end
			end
		end
	end
	-- landmarks win: any filler building whose footprint now overlaps a landmark footprint is removed
	local bfps = {}
	for _, d in ipairs(VB.Buildings:GetDescendants()) do if d:IsA("BasePart") and d.Name == "Footprint" then table.insert(bfps, d) end end
	local fop = OverlapParams.new()
	fop.FilterType = Enum.RaycastFilterType.Include
	fop.FilterDescendantsInstances = bfps
	local removed = 0
	for _, district in ipairs(VB.Landmarks:GetChildren()) do
		for _, fp in ipairs(district:GetChildren()) do
			if fp:IsA("BasePart") and fp.Name == "Footprint" then
				for _, q in ipairs(workspace:GetPartBoundsInBox(fp.CFrame, Vector3.new(math.max(0.1, fp.Size.X - 3), 4, math.max(0.1, fp.Size.Z - 3)), fop)) do
					local m = q.Parent
					if m and m:IsA("Model") and m:IsDescendantOf(VB.Buildings) then m:Destroy() removed += 1 end
				end
			end
		end
	end
	return string.format("fitted %d (scaled %d), removed %d overlapping filler buildings: %s", #moved, scaled, removed, table.concat(moved, ", "))
end
