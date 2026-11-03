-- 29 gas: replace every older gas station on the map with the new Florida / Larp style station (Gas.lua).
-- The lot frame is recovered from the old model: the big forecourt slab gives the centre + size, the canopy
-- sits on the street side, so -Z points from the slab centre toward the canopy.
return function(L)
	local VB = workspace.ViceBay
	local list = {}
	for _, m in ipairs(VB:GetDescendants()) do
		if m:IsA("Model") and m.Name == "GasStation" then table.insert(list, m) end
	end
	local done, keys = 0, { "sunshine", "gulfstar", "palm", "vice", "coastal" }
	L.seed(2929)
	for i, m in ipairs(list) do
		local slab, roofp
		for _, p in ipairs(m:GetChildren()) do
			if p:IsA("BasePart") then
				if not slab or (p.Size.X * p.Size.Z > slab.Size.X * slab.Size.Z and p.Size.Y < 0.5) then slab = p end
			end
		end
		for _, p in ipairs(m:GetChildren()) do
			if p:IsA("BasePart") and p.Position.Y > L.G + 14 and p.Size.X * p.Size.Z > 600 then roofp = p end
		end
		if slab then
			local c = Vector3.new(slab.Position.X, L.G, slab.Position.Z)
			local toFront = roofp and Vector3.new(roofp.Position.X - c.X, 0, roofp.Position.Z - c.Z) or -slab.CFrame.LookVector
			if toFront.Magnitude < 0.5 then toFront = -slab.CFrame.LookVector end
			-- snap to the slab's own axes
			local ax = { slab.CFrame.LookVector, -slab.CFrame.LookVector, slab.CFrame.RightVector, -slab.CFrame.RightVector }
			local best = ax[1]
			for _, v in ipairs(ax) do if v:Dot(toFront) > best:Dot(toFront) then best = v end end
			best = Vector3.new(best.X, 0, best.Z).Unit
			local along = math.abs(best:Dot(slab.CFrame.LookVector)) > 0.5
			local w = (along and slab.Size.X or slab.Size.Z) + 1
			local d = (along and slab.Size.Z or slab.Size.X) + 1
			local cf = CFrame.lookAt(c, c + best)
			local par = m.Parent
			local rd = m:IsDescendantOf(VB.Landmarks:FindFirstChild("Hood") or m) or (par and par.Name == "Hood")
			local ok, err = pcall(function() L.gasStation(par, cf, w, d, { brand = rd and "palm" or keys[(i % #keys) + 1], rundown = rd }) end)
			if ok then m:Destroy() done += 1 else warn("gas station failed: " .. tostring(err)) end
			task.wait()
		end
	end
	return "gas stations rebuilt: " .. done
end
