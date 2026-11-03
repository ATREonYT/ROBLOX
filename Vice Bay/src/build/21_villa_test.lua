-- 21 villa test: rebuild one lot with a chosen shape / finish (for iterating on the composer)
-- R.run("21_villa_test", shape, palette, mirror)
return function(L, shape, pal, mirror)
	local SI = workspace.ViceBay.Islands.SunsetIsles
	for _, c in ipairs(SI:GetChildren()) do
		if c.Name == "Sunset Isles Villa 1" then c:Destroy() end
	end
	L.seed(11)
	local m = L.villa(SI, CFrame.new(520, L.G, -1468), 100, 68, { dock = true, name = "Sunset Isles Villa 1", shape = shape, palette = pal, mirror = mirror })
	local n = 0
	for _, p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") then n += 1 end end
	local I = game.ServerStorage.VBInteriors:FindFirstChild("Sunset Isles Villa 1")
	local ni = 0
	if I then for _, p in ipairs(I:GetDescendants()) do if p:IsA("BasePart") then ni += 1 end end end
	return string.format("%s shell parts=%d interior parts=%d", m:GetAttribute("HouseStyle"), n, ni)
end
