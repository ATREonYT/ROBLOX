-- 19 road wear: cracks, oil stains, potholes and puddles over the existing road network.
-- Heavy in the hood (Liberty Heights / The Ends), light in Habana / Wynwood, none downtown.
-- Lives in its own folder so it can be re-run without touching the roads.
return function(L)
	local VB = L.folder(workspace, "ViceBay")
	local old = VB:FindFirstChild("RoadWear")
	if old then old:Destroy() end
	local RW = L.folder(VB, "RoadWear")
	L.seed(1919)
	local DENS = {
		HoodAsphaltCracked = 2.2, HoodAsphaltFaded = 1.6, HoodRoadPotholes = 2.8, -- hood streets / avenues / alleys
		AsphaltWorn = 0.7, AsphaltGranular = 0.5, -- Habana, Wynwood
		HoodSidewalkCracked = 1.0, SidewalkWornStained = 0.8, SidewalkSlabs = 0.35, DowntownAsphaltClean = 0.25, AsphaltPlain = 0.15, -- hood sidewalks (cracks + stains)
	}
	local n, segs = 0, 0
	local chunk = Instance.new("Folder")
	chunk.Name = "Chunk"
	for _, p in ipairs(VB.Roads:GetDescendants()) do
		if p:IsA("BasePart") then
			local dn = DENS[p.MaterialVariant]
			if dn and math.max(p.Size.X, p.Size.Z) > 12 and p.Size.Y < 3 then
				local before = #chunk:GetChildren()
				L.roadGrime(chunk, p, dn)
				n += #chunk:GetChildren() - before
				segs += 1
				if #chunk:GetChildren() > 600 then
					chunk.Parent = RW
					chunk = Instance.new("Folder")
					chunk.Name = "Chunk"
					task.wait()
				end
			end
		end
	end
	chunk.Parent = RW
	return string.format("road wear: %d decals over %d segments", n, segs)
end
