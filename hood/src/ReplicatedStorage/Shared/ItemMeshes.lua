-- ItemMeshes: the showcase items as real 3D meshes (brief 31 MESH), imported ONCE by the user into
-- ReplicatedStorage.HoodItemMeshes (hood/art/MESH_IMPORT.md: one FBX + one command-bar script). Each item is a Model named
-- by its id (Box_Street, Pad_VIP, GunStand_AK, Shoe_RedRocket ...) holding MeshParts named <Group>_<Material>_<hex>
-- (a box's lid parts in its `Lid` model) and the attributes DesignMin / DesignMax: its bounds in design studs, as the
-- Blender exporter (hood/tools/blender/export_item_meshes.py) modelled it. When the folder or the item is missing (no
-- import yet, the unit tests, the offline harness), every caller keeps its Part build: nothing needs the meshes.
--
--   ItemMeshes.has(id) -> boolean
--   ItemMeshes.place(id, cf, size, parent, fallbackFn, opts?) -> (Model?, usedMesh: boolean)
--       the item's mesh scaled to fit `size` (a number: its largest side; a Vector3: fits inside that box) with its
--       BOTTOM CENTRE at cf (front toward cf's -Z), parented to `parent`; opts.center = true puts its centre at cf
--       instead. Without a mesh it returns fallbackFn(cf, size, parent) (and false).
--   ItemMeshes.build(id, cf, scale) -> Model?   the mesh in its DESIGN frame: the design origin at cf, design studs
--       times `scale` (BoxModels and ShoeModels use this so the lid hinge, seal and shoe gap stay where the Part builds
--       put them); nil without a mesh
--   ItemMeshes.bounds(id) -> (min, max)?        its design bounds
--   ItemMeshes.Alias[id] = the id to use (other names callers may ask for)
--   ItemMeshes.root                              tests may set a Folder here in place of ReplicatedStorage's
-- Every part comes back Anchored, CanCollide/CanTouch/CanQuery false, its Color and Material taken from its name, so an
-- import that skipped the setup script's recolouring still shows the right colours. No asset ids live in code.
local ItemMeshes = {}

ItemMeshes.FOLDER = 'HoodItemMeshes'
ItemMeshes.root = nil :: Instance?
-- names other agents and older briefs used for the same items
ItemMeshes.Alias = {
	Pad_AutoFight = 'Pad_AutoShoot', Pad_DoublePower = 'Pad_DoubleRep', Pad_2xPower = 'Pad_DoubleRep',
	Pad_2xCash = 'Pad_DoubleCash', Pad_TwoXCash = 'Pad_DoubleCash', Pad_SpeedX2 = 'Pad_Speed2x', Pad_ExtraSlot = 'Pad_ExtraEquip',
	Box_Chrome = 'Box_Exclusive', Box_Crown = 'Box_Grail', Box_Bundle = 'Box_GrailBundle', Box_TheGrailBundle = 'Box_GrailBundle',
	GrailBundle = 'Box_GrailBundle',
}

local MATERIALS = { SmoothPlastic = true, Plastic = true, Neon = true, Glass = true, Foil = true, Metal = true }

local function folder(): Instance?
	if ItemMeshes.root then return ItemMeshes.root end
	local ok, f = pcall(function()
		return game:GetService('ReplicatedStorage'):FindFirstChild(ItemMeshes.FOLDER)
	end)
	return ok and f or nil
end

local function template(id: string): Instance?
	local f = folder()
	if not (f and type(id) == 'string') then return nil end
	local t = f:FindFirstChild(id) or (ItemMeshes.Alias[id] and f:FindFirstChild(ItemMeshes.Alias[id]))
	if t and t:IsA('Model') and t:FindFirstChildWhichIsA('BasePart', true) then return t end
	return nil
end

function ItemMeshes.has(id: string): boolean
	return template(id) ~= nil
end

-- the world-axis box round a model's parts
local function measure(m: Instance): (Vector3, Vector3)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in m:GetDescendants() do
		if p:IsA('BasePart') then
			local cf, s = p.CFrame, p.Size
			local r, u, b = cf.RightVector, cf.UpVector, -cf.LookVector
			local e = Vector3.new(
				math.abs(r.X) * s.X + math.abs(u.X) * s.Y + math.abs(b.X) * s.Z,
				math.abs(r.Y) * s.X + math.abs(u.Y) * s.Y + math.abs(b.Y) * s.Z,
				math.abs(r.Z) * s.X + math.abs(u.Z) * s.Y + math.abs(b.Z) * s.Z
			) / 2
			lo = Vector3.new(math.min(lo.X, cf.X - e.X), math.min(lo.Y, cf.Y - e.Y), math.min(lo.Z, cf.Z - e.Z))
			hi = Vector3.new(math.max(hi.X, cf.X + e.X), math.max(hi.Y, cf.Y + e.Y), math.max(hi.Z, cf.Z + e.Z))
		end
	end
	return lo, hi
end

-- design bounds of a template: its DesignMin/DesignMax, or (an import without the setup script) its own box with the
-- origin at its bottom centre
local function design(t: Instance): (Vector3, Vector3, Vector3, Vector3)
	local mlo, mhi = measure(t)
	local dlo, dhi = t:GetAttribute('DesignMin'), t:GetAttribute('DesignMax')
	if typeof(dlo) ~= 'Vector3' or typeof(dhi) ~= 'Vector3' then
		local half = (mhi - mlo) / 2
		dlo, dhi = Vector3.new(-half.X, 0, -half.Z), Vector3.new(half.X, 2 * half.Y, half.Z)
	end
	return dlo, dhi, mlo, mhi
end

function ItemMeshes.bounds(id: string): (Vector3?, Vector3?)
	local t = template(id)
	if not t then return nil, nil end
	local dlo, dhi = design(t)
	return dlo, dhi
end

local function finish(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	local mat, hex = p.Name:match('_(%a+)_(%x%x%x%x%x%x)$')
	if hex then
		p.Color = Color3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
		if MATERIALS[mat] then
			p.Material = (Enum.Material :: any)[mat]
			if mat == 'Neon' or mat == 'Glass' then p.CastShadow = false end
		end
	end
end

-- The mesh in its design frame: design point v lands at cf * (v * scale).
function ItemMeshes.build(id: string, cf: CFrame?, scale: number?): Model?
	local t = template(id)
	if not t then return nil end
	local at, k = cf or CFrame.identity, scale or 1
	local dlo, dhi, mlo, mhi = design(t)
	local dsize, msize = dhi - dlo, mhi - mlo
	-- the import's unit against the design (1 when the importer kept studs); the largest side decides
	local r = 1
	if msize.X >= msize.Y and msize.X >= msize.Z then r = dsize.X / math.max(msize.X, 1e-4)
	elseif msize.Y >= msize.Z then r = dsize.Y / math.max(msize.Y, 1e-4)
	else r = dsize.Z / math.max(msize.Z, 1e-4) end
	local m = t:Clone()
	m.Name = t.Name
	for _, p in m:GetDescendants() do
		if p:IsA('BasePart') then
			local d = dlo + (p.CFrame.Position - mlo) * r
			p.Size = p.Size * (r * k)
			p.CFrame = at * CFrame.new(d * k) * p.CFrame.Rotation
			finish(p)
		end
	end
	m:SetAttribute('ItemMesh', t.Name)
	m:SetAttribute('Scale', k)
	return m
end

function ItemMeshes.place(id: string, cf: CFrame, size: number | Vector3, parent: Instance?, fallbackFn: ((CFrame, any, Instance?) -> any)?, opts: { center: boolean? }?)
	local t = template(id)
	if t then
		local ok, m = pcall(function()
			local dlo, dhi = design(t)
			local ds = dhi - dlo
			local k
			if typeof(size) == 'Vector3' then
				k = math.min(size.X / math.max(ds.X, 1e-4), size.Y / math.max(ds.Y, 1e-4), size.Z / math.max(ds.Z, 1e-4))
			else
				k = (tonumber(size) or 4) / math.max(ds.X, ds.Y, ds.Z, 1e-4)
			end
			local anchor = Vector3.new((dlo.X + dhi.X) / 2, (opts and opts.center) and (dlo.Y + dhi.Y) / 2 or dlo.Y, (dlo.Z + dhi.Z) / 2)
			local model = ItemMeshes.build(id, cf * CFrame.new(-anchor * k), k)
			if model then
				model.Name = id
				pcall(function() model.WorldPivot = cf end)
				model.Parent = parent
			end
			return model
		end)
		if ok and m then return m, true end
		if not ok then warn('[ItemMeshes] ' .. tostring(id) .. ': ' .. tostring(m)) end
	end
	if fallbackFn then return fallbackFn(cf, size, parent), false end
	return nil, false
end

return ItemMeshes
