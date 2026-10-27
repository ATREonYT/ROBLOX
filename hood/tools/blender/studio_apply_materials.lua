-- Paste into Studio's command bar after importing hood/art/models/fbx/*.fbx with the 3D Importer.
-- Select the imported model(s) first. MeshParts are named <Id>_<Material>[_<hex colour>] by
-- export_fbx.py; this sets each one's Material, and for Neon/Glass (which cannot glow or tint through a
-- texture) clears the palette texture and uses the colour from the name instead.
local Selection = game:GetService('Selection')
local GLASS_TRANSPARENCY = 0.35
for _, root in Selection:Get() do
	for _, mp in root:GetDescendants() do
		if mp:IsA('MeshPart') then
			local matName, hex = mp.Name:match('_(%a+)_(%x%x%x%x%x%x)$')
			matName = matName or mp.Name:match('_(%a+)$')
			local ok, mat = pcall(function() return Enum.Material[matName] end)
			if ok and mat then
				mp.Material = mat
			end
			if hex then
				mp.TextureID = ''
				mp.Color = Color3.fromHex(hex)
			end
			if matName == 'Glass' then
				mp.Transparency = GLASS_TRANSPARENCY
				mp.CastShadow = false
			elseif matName == 'Neon' then
				mp.CastShadow = false
			end
			mp.Anchored = true
			mp.CanCollide = false
		end
	end
end
