-- Stone Skipping style water: bright turquoise, smooth, no studs. The drifting
-- light lines are added at runtime by Effects.lua once Icons.Caustics has an id.
-- Paste into the Command Bar. The old texture id is kept as an OldTexture attribute.
local ocean = workspace.map1b:FindFirstChild("Ocean", true)
local n = 0
for _, p in ipairs(ocean:GetDescendants()) do
	if p:IsA("MeshPart") then
		if p:GetAttribute("OldTexture") == nil then
			p:SetAttribute("OldTexture", p.TextureID)
		end
		p.TextureID = ""
		p.Color = Color3.fromRGB(20, 200, 235)
		p.Material = Enum.Material.SmoothPlastic
		p.Reflectance = 0.1
		for _, t in ipairs(p:GetChildren()) do
			if t:IsA("Texture") and t.Name == "Studs" then
				t.Transparency = 1
			end
		end
		n += 1
	end
end
print("[Water] restyled " .. n .. " ocean parts")
