-- Particle budget: append to a harness snippet after building. Prints, per model directly under `root`,
-- the emitter/beam/light counts and the steady-state live particles (sum of Rate x mean Lifetime).
local function budget(root)
	for _, m in root:GetChildren() do
		local live, emitters, beams, lights = 0, 0, 0, 0
		for _, d in m:GetDescendants() do
			if d:IsA('ParticleEmitter') and d.Enabled then emitters += 1; live += d.Rate * (d.Lifetime.Min + d.Lifetime.Max) / 2
			elseif d:IsA('Beam') then beams += 1
			elseif d:IsA('Light') then lights += 1 end
		end
		if emitters + beams + lights > 0 then
			print(string.format('%-24s emitters=%-3d beams=%-2d lights=%-2d live~%.0f', m.Name, emitters, beams, lights, live))
		end
	end
end
-- e.g. at the end of the snippet:  budget(workspace.StationsPreview)
