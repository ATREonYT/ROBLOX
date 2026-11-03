-- 25 clear roads: nothing solid may stand in the driving volume above any carriageway.
-- * long barriers (canal parapets, river walls, causeway / highway rails, rail) are split where a road crosses them
-- * cars (burnt / parked) sitting on the carriageway are removed
-- * anything else small becomes non-colliding; big things are reported
-- Precise test: GetPartsInPart against a query volume per asphalt slab / junction disc.
return function(L)
	local VB = workspace.ViceBay
	local inc = {}
	for _, n in ipairs({ "River", "Canal", "Highway", "CoralCauseway", "Landmarks", "Rail", "Buildings", "Parks", "Islands", "Metro", "County3D" }) do
		if VB:FindFirstChild(n) then table.insert(inc, VB[n]) end
	end
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Include
	op.FilterDescendantsInstances = inc
	op.RespectCanCollide = true
	local ROAD = { Asphalt = true, Junction = true, Bend = true, CulDeSac = true, Sidewalk = true }
	local vols, vols2 = {}, {}
	for _, roadsF in ipairs({ VB.Roads, VB:FindFirstChild("CountyRoads"), VB:FindFirstChild("PortSol") }) do
		if roadsF then
			for _, a in ipairs(roadsF:GetDescendants()) do
				if a:IsA("BasePart") and (a.Name == "Asphalt" or a.Name == "Junction" or a.Name == "Bend") then
					local q = Instance.new("Part")
					q.Anchored, q.CanCollide, q.CanTouch = true, false, false
					q.Transparency = 1
					if a.Shape == Enum.PartType.Cylinder then
						q.Shape = Enum.PartType.Cylinder
						local top = a.Position.Y + a.Size.X / 2
						q.Size = Vector3.new(5, a.Size.Y * 0.8, a.Size.Z * 0.8)
						q.CFrame = CFrame.new(a.Position.X, top + 2.7, a.Position.Z) * CFrame.Angles(0, 0, math.pi / 2)
					else
						q.Size = Vector3.new(math.max(1, a.Size.X - 1), 5, a.Size.Z)
						q.CFrame = a.CFrame * CFrame.new(0, a.Size.Y / 2 + 2.7, 0)
					end
					table.insert(vols, q)
					local q2 = q:Clone()
					if a.Shape == Enum.PartType.Cylinder then
						local top = a.Position.Y + a.Size.X / 2
						q2.Size = Vector3.new(9.6, a.Size.Y * 0.7, a.Size.Z * 0.7)
						q2.CFrame = CFrame.new(a.Position.X, top + 5.1, a.Position.Z) * CFrame.Angles(0, 0, math.pi / 2)
					else
						q2.Size = Vector3.new(math.max(1, a.Size.X - 1.6), 9.6, a.Size.Z)
						q2.CFrame = a.CFrame * CFrame.new(0, a.Size.Y / 2 + 5.1, 0)
					end
					table.insert(vols2, q2)
				end
			end
		end
	end
	local split, cars, soft, report = 0, 0, 0, {}
	local function corners(q)
		local s = q.Size / 2
		local out = {}
		for _, x in ipairs({ -1, 1 }) do for _, y in ipairs({ -1, 1 }) do for _, z in ipairs({ -1, 1 }) do
			table.insert(out, (q.CFrame * CFrame.new(x * s.X, y * s.Y, z * s.Z)).Position)
		end end end
		return out
	end
	local function splitAround(p, q)
		local s = p.Size
		local axisIdx, L0 = 3, s.Z
		if s.X >= s.Y and s.X >= s.Z then axisIdx, L0 = 1, s.X elseif s.Y >= s.Z then axisIdx, L0 = 2, s.Y end
		local ax = ({ p.CFrame.XVector, p.CFrame.YVector, p.CFrame.ZVector })[axisIdx]
		local lo, hi = math.huge, -math.huge
		for _, c in ipairs(corners(q)) do
			local t = (c - p.Position):Dot(ax)
			lo, hi = math.min(lo, t), math.max(hi, t)
		end
		lo, hi = lo - 1.5, hi + 1.5
		local pieces = { { -L0 / 2, math.min(lo, L0 / 2) }, { math.max(hi, -L0 / 2), L0 / 2 } }
		for _, pc in ipairs(pieces) do
			local len = pc[2] - pc[1]
			if len > 0.6 then
				local n = p:Clone()
				local sz = p.Size
				if axisIdx == 1 then n.Size = Vector3.new(len, sz.Y, sz.Z) elseif axisIdx == 2 then n.Size = Vector3.new(sz.X, len, sz.Z) else n.Size = Vector3.new(sz.X, sz.Y, len) end
				n.CFrame = p.CFrame + ax * ((pc[1] + pc[2]) / 2)
				n.Parent = p.Parent
			end
		end
		p:Destroy()
		split += 1
	end
	for i, q in ipairs(vols) do
		q.Parent = workspace
		for _, p in ipairs(workspace:GetPartsInPart(q, op)) do
			if p.Parent and p.CanCollide and not ROAD[p.Name] then
				local mdl = p:FindFirstAncestorWhichIsA("Model")
				local mname = mdl and mdl.Name or ""
				local s = p.Size
				local long = math.max(s.X, s.Y, s.Z)
				local others = s.X + s.Y + s.Z - long
				local carM = p:FindFirstAncestor("BurntCar") or p:FindFirstAncestor("ParkedCar") or p:FindFirstAncestor("Supercar")
				if carM then
					carM:Destroy()
					cars += 1
				elseif long >= 18 and others <= 18.5 and p.Shape == Enum.PartType.Block then
					splitAround(p, q)
				elseif long < 30 then
					p.CanCollide = false
					soft += 1
					if #report < 12 then table.insert(report, "soft " .. p:GetFullName():gsub("Workspace.ViceBay.", "")) end
				else
					if #report < 24 then table.insert(report, string.format("BIG %s %.0fx%.0fx%.0f", p:GetFullName():gsub("Workspace.ViceBay.", ""), s.X, s.Y, s.Z)) end
				end
			end
		end
		q:Destroy()
		if i % 150 == 0 then task.wait() end
	end
	-- pass 2: visual clutter across the lanes (fences, railings, parapets, wall caps) even when it doesn't collide.
	-- Only infrastructure folders: long pieces are cut back to the road edge, small pieces removed.
	local infra = {}
	for _, n in ipairs({ "River", "Canal", "Rail", "CoralCauseway" }) do
		if VB:FindFirstChild(n) then table.insert(infra, VB[n]) end
	end
	local op2 = OverlapParams.new()
	op2.FilterType = Enum.RaycastFilterType.Include
	op2.FilterDescendantsInstances = infra
	op2.RespectCanCollide = false
	local cut, gone = 0, 0
	-- decoration parts are CanQuery=false; make them visible to the overlap test for this pass
	local restore = {}
	for _, f in ipairs(infra) do
		for _, d in ipairs(f:GetDescendants()) do
			if d:IsA("BasePart") and not d.CanQuery then d.CanQuery = true table.insert(restore, d) end
		end
	end
	for i, a in ipairs(vols2) do
		a.Parent = workspace
		for _, p in ipairs(workspace:GetPartsInPart(a, op2)) do
			if p.Parent and p.Transparency < 1 and not ROAD[p.Name] then
				local sz = p.Size
				local long = math.max(sz.X, sz.Y, sz.Z)
				if long >= 12 and p.Shape == Enum.PartType.Block then
					splitAround(p, a)
					cut += 1
				else
					p:Destroy()
					gone += 1
				end
			end
		end
		a:Destroy()
		if i % 150 == 0 then task.wait() end
	end
	for _, d in ipairs(restore) do if d.Parent then d.CanQuery = false end end
	return string.format("volumes %d, barriers split %d, cars removed %d, softened %d | clutter cut %d removed %d\n%s", #vols, split, cars, soft, cut, gone, table.concat(report, "\n"))
end
