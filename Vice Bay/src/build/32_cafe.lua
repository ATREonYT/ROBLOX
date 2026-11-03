-- 32: rebuild Cafe La Habana (Calle Ocho job) with its walk-in interior, without re-running all of Habana
return function(L)
	local C, M = L.C, L.M
	local VB = workspace.ViceBay
	local G = L.G
	local cf = CFrame.new(-480, G, 590) * CFrame.Angles(0, math.pi, 0)
	local removed = 0
	for _, d in ipairs(VB:GetDescendants()) do
		if d:IsA("Model") and (d.Name == "Shops" or d.Name == "CafeLaHabana") and d.Parent and (d:GetPivot().Position - cf.Position).Magnitude < 30 then
			d:Destroy()
			removed += 1
		end
	end
	local LM = L.folder(L.folder(VB, "Landmarks"), "Habana")
	L.seed(58)
	local m = L.shop(LM, cf, 70, 50, { units = 2, floors = 2, rundown = false, signs = { "CAFE LA HABANA", "CAFE VENTANITA" }, color = C(244, 170, 180), interior = true, menu = "CAFECITO  •  CROQUETAS  •  PASTELITOS  •  CUBANO", accent = C(40, 110, 80), front = "cornice" })
	m.Name = "CafeLaHabana"
	local n = 0
	for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then n += 1 end end
	return string.format("cafe rebuilt (removed %d old), %d parts", removed, n)
end
