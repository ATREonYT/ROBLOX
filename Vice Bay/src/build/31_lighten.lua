-- 31 lighten: swap every heavy palm mesh (more than 12 parts) for the 3-part coconut palm at the same spot and
-- height. Same look from the street, a fraction of the parts.
return function(L)
	local A = game:GetService("ServerStorage").VBAssets
	local src = A:FindFirstChild("PalmB")
	local _, s0 = src:GetBoundingBox()
	local swapped, saved = 0, 0
	local list = {}
	for _, m in ipairs(workspace.ViceBay:GetDescendants()) do
		if m:IsA("Model") and m.Name == "Palm" then table.insert(list, m) end
	end
	for i, m in ipairs(list) do
		if m.Parent then
			local n = 0
			for _, p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") then n += 1 end end
			if n > 12 then
				local cf, sz = m:GetBoundingBox()
				local base = m:GetPivot().Position
				local c = src:Clone()
				c:ScaleTo(math.clamp(sz.Y / s0.Y, 0.4, 3))
				c:PivotTo(CFrame.new(base) * CFrame.Angles(0, math.random() * 6.28, 0))
				c.Name = "Palm"
				c.Parent = m.Parent
				m:Destroy()
				swapped += 1
				saved += n - 3
			end
		end
		if i % 300 == 0 then task.wait() end
	end
	return "palms swapped " .. swapped .. ", parts saved ~" .. saved
end
