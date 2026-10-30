-- The imported GLB cannons came in about 2 studs long and far from the origin,
-- so the Cannons menu showed empty cards. This scales each one to the
-- placeholders' length and puts its pivot where the placeholders' is.
-- Paste into the Command Bar. Safe to run twice (it skips cannons already sized).
local C = game.ReplicatedStorage.Cannons
local ref = C.Cannon02_Iron
local rcf, rsize = ref:GetBoundingBox()
local rel = ref:GetPivot():ToObjectSpace(rcf)
for _, m in ipairs(C:GetChildren()) do
	if m:IsA("Model") and not m.PrimaryPart then
		local cf, size = m:GetBoundingBox()
		if size.Z < 4 then
			m.WorldPivot = CFrame.new(cf.Position)
			m:ScaleTo(m:GetScale() * (rsize.Z / size.Z))
			local _, size2 = m:GetBoundingBox()
			m:PivotTo(CFrame.new(rcf.Position.X, rcf.Position.Y - rsize.Y / 2 + size2.Y / 2, rcf.Position.Z))
			local cf3, s3 = m:GetBoundingBox()
			m.WorldPivot = CFrame.new(cf3.Position.X, cf3.Position.Y - s3.Y / 2 + 1.2 - (rcf.Position.Y - rsize.Y / 2), cf3.Position.Z - rel.Position.Z)
			print("[Cannons] sized " .. m.Name)
		end
	end
end
