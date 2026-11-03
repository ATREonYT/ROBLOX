-- 26 no grass under: terrain Grass / LeafyGrass draws decoration blades that poke up through thin parts
-- (roads, sidewalks, lawns, house floors, pools). Swap the terrain under every road surface and every
-- house / building lot to Ground (no blades). Open lawns, parks and verges keep their grass terrain.
return function(L)
	local M = L.M
	local T = workspace.Terrain
	local G = L.G
	local VB = workspace.ViceBay
	local n = 0
	local function clear(minV, maxV)
		local reg = Region3.new(Vector3.new(minV.X, G - 6, minV.Z), Vector3.new(maxV.X, G + 4, maxV.Z)):ExpandToGrid(4)
		T:ReplaceMaterial(reg, 4, M.Grass, M.Ground)
		T:ReplaceMaterial(reg, 4, M.LeafyGrass, M.Ground)
		n += 1
	end
	-- road surfaces: sample the (possibly rotated) footprint with 8-stud cells
	local SURF = { Asphalt = true, Junction = true, Bend = true, CulDeSac = true, Sidewalk = true }
	local folders = { VB:FindFirstChild("Roads"), VB:FindFirstChild("CountyRoads"), VB:FindFirstChild("Islands"), VB:FindFirstChild("Highway"), VB:FindFirstChild("CoralCauseway"), VB:FindFirstChild("County3D"), VB:FindFirstChild("Metro"), VB:FindFirstChild("Expressway"), VB:FindFirstChild("PortSol"), VB:FindFirstChild("Airport"), VB:FindFirstChild("HoodWest") }
	local k = 0
	for _, f in ipairs(folders) do
		if f then
			for _, p in ipairs(f:GetDescendants()) do
				if p:IsA("BasePart") and p.Position.Y < G + 6 and (SURF[p.Name] or (p.Material == M.Asphalt and p.Size.Y < 2)) then
					local sx, sz
					if p.Shape == Enum.PartType.Cylinder then sx, sz = p.Size.Y, p.Size.Z else sx, sz = p.Size.X, p.Size.Z end
					local cf = CFrame.new(p.Position) * (p.CFrame - p.Position)
					for x = -sx / 2 + 2, sx / 2, 8 do
						for z = -sz / 2 + 2, sz / 2, 8 do
							local c = (cf * CFrame.new(x, 0, z)).Position
							clear(c - Vector3.new(5, 0, 5), c + Vector3.new(5, 0, 5))
						end
					end
					k += 1
					if k % 40 == 0 then task.wait() end
				end
			end
		end
	end
	-- house and building lots (axis-aligned boxes are fine: lots are on the grid)
	local CS = game:GetService("CollectionService")
	for _, h in ipairs(CS:GetTagged("VBHouse")) do
		local cf, sz = h:GetBoundingBox()
		local half = Vector3.new(sz.X / 2, 0, sz.Z / 2)
		clear(cf.Position - half, cf.Position + half)
	end
	return "grass cleared under " .. k .. " parts / lots (" .. n .. " regions)"
end
