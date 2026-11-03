-- 22 villas: rebuild every luxury house with the composer (Villa.lua) by re-running the districts that own them,
-- then re-fit landmarks. Interiors land in ServerStorage.VBInteriors (loaded only when a house is claimed).
return function(L)
	local SS = game:GetService("ServerStorage")
	local store = SS:FindFirstChild("VBInteriors")
	if store then store:ClearAllChildren() end
	return "use R.run on 12_islands, 13_county, 17_mangrove, 20_fit_landmarks in order"
end
