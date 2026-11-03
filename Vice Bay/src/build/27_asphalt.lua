-- 27 asphalt: the public asphalt the realistic variants were remapped to reads brown and noisy. Point every road
-- variant at fine-grain public concrete aggregate maps instead (they read as fresh / worn asphalt in dark grey).
-- clean = MatPackE "Concrete" (fine), worn = MatPackE "LinedCement" (coarse aggregate). Re-run after 15_textures.
return function(L)
	local SS = game:GetService("ServerStorage")
	local MS = game:GetService("MaterialService")
	local R = MS:FindFirstChild("Realistic")
	local function src(pack, name) return SS[pack]:FindFirstChild(name, true) end
	local CLEAN, WORN = src("MatPackE", "Concrete"), src("MatPackE", "LinedCement")
	local SET = {
		DowntownAsphaltClean = { CLEAN, 12 }, AsphaltPlain = { CLEAN, 12 }, AsphaltDarkFresh = { CLEAN, 12 }, AI_CleanAsphalt = { CLEAN, 12 },
		HoodAsphaltCracked = { WORN, 14 }, HoodAsphaltFaded = { WORN, 14 }, AsphaltWorn = { WORN, 14 }, AsphaltGranular = { WORN, 14 },
		RoadDamagedB = { WORN, 14 }, HoodRoadPotholes = { WORN, 12 }, ParkingLotAsphalt = { WORN, 14 }, AsphaltTarPatch = { CLEAN, 8 },
	}
	local n = 0
	for name, s in pairs(SET) do
		local v = R and R:FindFirstChild(name)
		if v and s[1] then
			if v:GetAttribute("PreAsphaltColor") == nil then v:SetAttribute("PreAsphaltColor", v.ColorMap) end
			v.ColorMap = s[1].ColorMap
			v.NormalMap = s[1].NormalMap
			v.RoughnessMap = s[1].RoughnessMap
			v.MetalnessMap = s[1].MetalnessMap
			v.StudsPerTile = s[2]
			n += 1
		end
	end
	return "asphalt variants remapped: " .. n
end
