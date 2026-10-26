-- (B32 ASSETS) Fake ReplicatedStorage.HoodItemMeshes as studio_item_meshes.lua leaves it after importing the four
-- Items_*.glb files: one Model per id, MeshParts named as in the GLB (<Id>, <Id>_2, <Id>_Glow_<hex>), white bodies (the
-- palette texture carries the colour), glow parts left grey (ItemMeshes recolours them from the name), DesignMin /
-- DesignMax / Collision / Muzzle, the gate's Colliders. Each MeshPart carries PreviewGlb + PreviewNode so render14 draws
-- the real GLB mesh with its palette colours. The items sit far from their design origin (an import), so shots also
-- prove ItemMeshes' mapping.
local function __fakeItemMeshes(manifestPath)
	local man = __serde.decode('json', __fs.readFile(manifestPath))
	local RS = game:GetService('ReplicatedStorage')
	local folder = RS:FindFirstChild('HoodItemMeshes') or Instance.new('Folder')
	folder.Name = 'HoodItemMeshes'
	folder.Parent = RS
	local V = Vector3.new
	local n = 0
	for _, it in man.items do
		n += 1
		local m = Instance.new('Model')
		m.Name = it.id
		local off = V(900 + n * 40, 400, 300)
		for _, me in it.meshes do
			local mp = Instance.new('MeshPart')
			mp.Name = me.name
			local lo, hi = V(me.min[1], me.min[2], me.min[3]), V(me.max[1], me.max[2], me.max[3])
			mp.Size = hi - lo
			mp.CFrame = CFrame.new((lo + hi) / 2 + off)
			mp.Color = me.kind == 'glow' and Color3.fromRGB(163, 162, 165) or Color3.new(1, 1, 1)
			mp.Material = Enum.Material.SmoothPlastic
			mp:SetAttribute('PreviewGlb', 'glb/' .. it.package)
			mp:SetAttribute('PreviewNode', me.name)
			mp.Parent = m
		end
		for _, c in it.colliders or {} do
			local p = Instance.new('Part')
			p.Name = 'Collider'
			p.Size = V(c.size[1], c.size[2], c.size[3])
			p.CFrame = CFrame.new(V(c.centre[1], c.centre[2], c.centre[3]) + off)
			p.Transparency = 1
			p.Parent = m
		end
		m:SetAttribute('DesignMin', V(it.min[1], it.min[2], it.min[3]))
		m:SetAttribute('DesignMax', V(it.max[1], it.max[2], it.max[3]))
		m:SetAttribute('Collision', it.collision)
		if it.muzzle then m:SetAttribute('Muzzle', V(it.muzzle[1], it.muzzle[2], it.muzzle[3])) end
		m.Parent = folder
	end
	return folder, n
end
