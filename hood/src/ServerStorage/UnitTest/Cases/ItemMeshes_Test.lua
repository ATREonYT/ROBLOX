-- ItemMeshes (brief 31 MESH): the showcase items' imported meshes, with the Part build as the fallback. Both paths: no
-- folder (every place calls its fallback), and a fake ReplicatedStorage.HoodItemMeshes laid out as the Studio setup script
-- leaves it (an item Model of MeshParts named <Group>_<Material>_<hex>, a box's `Lid`, DesignMin / DesignMax), imported at
-- another unit and somewhere else, which the mesh must undo; then BoxModels' chest from the mesh keeps its lid contract.
return function(t)
	local RS = game:GetService('ReplicatedStorage')
	local IM = require(RS.Shared.ItemMeshes)
	local BM = require(RS.Shared.Models.BoxModels)
	local SM = require(RS.Shared.Models.ShoeModels)
	local e = t.expect
	local V = Vector3.new

	local function bounds(m)
		local lo, hi = V(1e9, 1e9, 1e9), V(-1e9, -1e9, -1e9)
		for _, p in m:GetDescendants() do
			if p:IsA('BasePart') and p.Transparency < 1 then
				lo = V(math.min(lo.X, p.CFrame.X - p.Size.X / 2), math.min(lo.Y, p.CFrame.Y - p.Size.Y / 2), math.min(lo.Z, p.CFrame.Z - p.Size.Z / 2))
				hi = V(math.max(hi.X, p.CFrame.X + p.Size.X / 2), math.max(hi.Y, p.CFrame.Y + p.Size.Y / 2), math.max(hi.Z, p.CFrame.Z + p.Size.Z / 2))
			end
		end
		return lo, hi
	end
	local function meshPart(name, size, pos, parent)
		local ok, p = pcall(Instance.new, 'MeshPart')
		if not ok then p = Instance.new('Part') end
		p.Name = name
		p.Size = size
		p.CFrame = CFrame.new(pos)
		p.Color = Color3.fromRGB(163, 162, 165) -- the importer's grey
		p.Anchored = false
		p.CanCollide = true
		p.Parent = parent
		return p
	end
	-- A fake import at half scale (0.5 import units per design stud), 300 studs away from the design origin.
	local K, OFF = 0.5, V(300, 40, -200)
	local function fakeFolder()
		local f = Instance.new('Folder')
		f.Name = 'HoodItemMeshes'
		-- a pad item: design bounds x -1..1, y 0..4, z -0.5..0.5 (two parts: a 2x2x1 base, a 1x2x1 top)
		local pad = Instance.new('Model')
		pad.Name = 'Pad_AutoShoot'
		pad:SetAttribute('DesignMin', V(-1, 0, -0.5))
		pad:SetAttribute('DesignMax', V(1, 4, 0.5))
		meshPart('Body_SmoothPlastic_ff2030', V(2, 2, 1) * K, OFF + V(0, 1, 0) * K, pad)
		meshPart('Body_Neon_20c0ff', V(1, 2, 1) * K, OFF + V(0, 3, 0) * K, pad)
		pad.Parent = f
		-- a chest: the tub (4.4 x 2.1 x 3.4) and a lid (4.5 x 0.98 x 3.5 over the seam)
		local box = Instance.new('Model')
		box.Name = 'Box_Street'
		box:SetAttribute('DesignMin', V(-2.25, 0, -1.75))
		box:SetAttribute('DesignMax', V(2.25, 3.08, 1.75))
		meshPart('Body_SmoothPlastic_e21e28', V(4.4, 2.1, 3.4) * K, OFF + V(0, 1.05, 0) * K, box)
		local lid = Instance.new('Model')
		lid.Name = 'Lid'
		lid.Parent = box
		meshPart('Lid_SmoothPlastic_f6f6f8', V(4.5, 0.98, 3.5) * K, OFF + V(0, 2.59, 0) * K, lid)
		box.Parent = f
		return f
	end
	local function with(folder, fn)
		local before = IM.root
		IM.root = folder
		local ok, err = pcall(fn)
		IM.root = before
		if not ok then error(err, 0) end
	end

	t.test('without the folder every item uses its Part fallback', function()
		with(nil, function()
			if RS:FindFirstChild(IM.FOLDER) then return end -- (a place with the import: covered below)
			e.falsy(IM.has('Box_Street'))
			e.falsy(IM.has('Pad_VIP'))
			e.equal(IM.build('Box_Street', CFrame.new(), 1), nil)
			local got
			local parent = Instance.new('Model')
			local m, used = IM.place('Pad_VIP', CFrame.new(1, 2, 3), 5, parent, function(cf, size, p)
				got = { cf = cf, size = size, parent = p }
				local fb = Instance.new('Model')
				fb.Name = 'Fallback'
				fb.Parent = p
				return fb
			end)
			e.falsy(used)
			e.truthy(m and m.Name == 'Fallback' and m.Parent == parent)
			e.truthy(got and got.size == 5 and got.parent == parent and got.cf.Position == V(1, 2, 3))
			-- no fallback: nothing, and no error
			local none, used2 = IM.place('Pad_VIP', CFrame.new(), 5, parent, nil)
			e.equal(none, nil)
			e.falsy(used2)
		end)
		with(Instance.new('Folder'), function()
			e.falsy(IM.has('Box_Street'))
			local _, used = IM.place('Box_Street', CFrame.new(), 5, nil, function() return 'parts' end)
			e.falsy(used)
		end)
	end)

	t.test('an imported item is cloned, fitted to the size, bottom centre on cf, coloured from its names', function()
		local f = fakeFolder()
		with(f, function()
			e.truthy(IM.has('Pad_AutoShoot'))
			e.truthy(IM.has('Pad_AutoFight')) -- (an alias other code may use)
			local lo0, hi0 = IM.bounds('Pad_AutoShoot')
			e.truthy(lo0 == V(-1, 0, -0.5) and hi0 == V(1, 4, 0.5))
			local parent = Instance.new('Model')
			local called = false
			local at = CFrame.new(10, 5, -3)
			local m, used = IM.place('Pad_AutoShoot', at, 6, parent, function() called = true end)
			e.truthy(used)
			e.falsy(called)
			e.truthy(m and m.Parent == parent and m.Name == 'Pad_AutoShoot')
			local lo, hi = bounds(m)
			e.near(hi.Y - lo.Y, 6, 1e-3) -- the largest side (4 design studs) fitted to 6
			e.near(hi.X - lo.X, 3, 1e-3)
			e.near(lo.Y, 5, 1e-3) -- standing on cf
			e.near((lo.X + hi.X) / 2, 10, 1e-3)
			e.near((lo.Z + hi.Z) / 2, -3, 1e-3)
			local red, neon = m:FindFirstChild('Body_SmoothPlastic_ff2030'), m:FindFirstChild('Body_Neon_20c0ff')
			e.truthy(red and neon)
			e.truthy(red.Color == Color3.fromRGB(255, 32, 48) and red.Material == Enum.Material.SmoothPlastic)
			e.truthy(neon.Material == Enum.Material.Neon and neon.CastShadow == false)
			for _, p in m:GetDescendants() do
				if p:IsA('BasePart') then e.truthy(p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery) end
			end
			-- the template is untouched
			e.truthy(f.Pad_AutoShoot.Body_SmoothPlastic_ff2030.Color == Color3.fromRGB(163, 162, 165))
			-- a Vector3 size fits inside that box; center = true centres it on cf
			local m2 = IM.place('Pad_AutoShoot', CFrame.new(0, 10, 0), V(1, 100, 100), nil, nil, { center = true })
			local lo2, hi2 = bounds(m2)
			e.near(hi2.X - lo2.X, 1, 1e-3)
			e.near((lo2.Y + hi2.Y) / 2, 10, 1e-3)
			-- build: design studs x scale at cf (the top part's centre is design (0, 3, 0))
			local m3 = IM.build('Pad_AutoShoot', CFrame.new(0, 1, 0), 2)
			e.near(m3.Body_Neon_20c0ff.CFrame.Y, 1 + 3 * 2, 1e-3)
			e.near(m3.Body_Neon_20c0ff.Size.X, 2, 1e-3)
		end)
	end)

	t.test("a chest from its mesh keeps BoxModels' Root, Lid and Hinge contract; no lid means the Part chest", function()
		local f = fakeFolder()
		with(f, function()
			local s, at = 2, CFrame.new(50, 0, 20)
			local m = BM.build('Street', s, at)
			e.truthy(m:GetAttribute('Mesh'))
			e.truthy(m.PrimaryPart and m.PrimaryPart.Name == 'Root')
			local lid = m:FindFirstChild('Lid')
			e.truthy(lid and lid.PrimaryPart and lid.PrimaryPart.Name == 'Hinge')
			local h = lid.PrimaryPart.CFrame.Position
			local want = (at * CFrame.new(0, BM.Size.Body * s, BM.Size.D / 2 * s)).Position
			e.near((h - want).Magnitude, 0, 1e-3)
			local tub, top = m:FindFirstChild('Body_SmoothPlastic_e21e28'), lid:FindFirstChild('Lid_SmoothPlastic_f6f6f8')
			e.truthy(tub and top)
			e.near(tub.Size.X, 4.4 * s, 1e-3)
			e.near(tub.CFrame.Y, 1.05 * s, 1e-3)
			-- the lid swings open about the hinge
			local y0 = top.CFrame.Y
			BM.openLid(m, 1)
			e.truthy(top.CFrame.Y > y0 + 0.5)
			-- display extras still attach
			BM.fx(m)
			e.truthy(m:FindFirstChild('SeamGlow') ~= nil)
			-- a chest mesh without its lid: BoxModels builds the Parts instead
			f.Box_Street.Lid:Destroy()
			local parts = BM.build('Street', 1)
			e.falsy(parts:GetAttribute('Mesh'))
			e.truthy(parts:FindFirstChild('Lid') and parts.Lid.PrimaryPart.Name == 'Hinge')
		end)
	end)

	t.test('a pair on display comes from its mesh with the same Root and attributes; without it, the Part shoes', function()
		local f = fakeFolder()
		local shoe = Instance.new('Model')
		shoe.Name = 'Shoe_RedRocket'
		shoe:SetAttribute('DesignMin', V(-1.3, 0, -1))
		shoe:SetAttribute('DesignMax', V(1.3, 1.45, 0.7))
		meshPart('Body_SmoothPlastic_e21e28', V(2.6, 1.45, 1.7) * K, OFF + V(0, 0.725, -0.15) * K, shoe)
		shoe.Parent = f
		with(f, function()
			local m = SM.pair('RedRocket', 2)
			e.truthy(m:GetAttribute('Mesh'))
			e.truthy(m.PrimaryPart and m.PrimaryPart.Name == 'Root' and m:GetAttribute('ShoeId') == 'RedRocket' and m:GetAttribute('Scale') == 2)
			e.equal(m:FindFirstChild('RedRocket_L'), nil)
			local body = m:FindFirstChild('Body_SmoothPlastic_e21e28')
			e.truthy(body)
			e.near(body.CFrame.Y - body.Size.Y / 2, 0, 1e-3) -- soles on the ground, like the Part pair
			e.near(body.Size.X, 5.2, 1e-3)
		end)
		with(Instance.new('Folder'), function()
			local m = SM.pair('RedRocket', 1)
			e.falsy(m:GetAttribute('Mesh'))
			e.truthy(m:FindFirstChild('RedRocket_L') and m:FindFirstChild('RedRocket_R'))
		end)
	end)

	-- (brief 32) the user's blocky designs: every packaged id, the fitting rule, textures/glow/collision, guns
	t.test('brief 32: the package ids are all in ItemMeshes.Design with sane sizes', function()
		local Guns = require(RS.Shared.Config.Guns)
		local Products = require(RS.Shared.Config.Products)
		local D = IM.Design
		local n = 0
		for id, d in D do
			n += 1
			local s = d.Max - d.Min
			e.truthy(s.X > 0.2 and s.Y > 0.2 and s.Z > 0.2 and s.Magnitude < 40)
			e.truthy(d.Collision == 'solid' or d.Collision == 'prop' or d.Collision == 'gun')
			if id:match('^Gun_') then
				e.equal(d.Collision, 'gun')
				e.truthy(d.Muzzle and d.Muzzle.Z <= d.Min.Z + 0.05) -- the muzzle is the front (-Z) end
				e.truthy(d.Min.Z < 0 and d.Max.Z > 0 and d.Min.Y < 0) -- the grip is the origin
			else
				e.near(d.Min.Y, 0, 1e-3) -- props stand on their bottom centre
				e.near((d.Min.X + d.Max.X) / 2, 0, 0.05)
			end
		end
		e.equal(n, 57)
		for _, g in Guns.List do
			e.truthy(D['Gun_' .. g.Id] and not D['Gun_' .. g.Id].Exclusive)
		end
		for _, x in { 'NeonViper', 'GalaxyRay', 'InfernoCannon', 'Frostbite', 'RoyalCrown' } do
			e.truthy(D['Gun_' .. x] and D['Gun_' .. x].Exclusive)
			e.falsy(Guns.ById[x]) -- packaged only: not a game gun (yet)
		end
		local pads = 0
		for _, p in Products.Catalog do
			if type(p) == 'table' and p.Kind == 'Pass' and D['Pad_' .. tostring(p.Key)] then pads += 1 end
		end
		e.equal(pads, 10)
		for _, id in { 'Pad_Base', 'Gate_Stage1', 'Board_Boxes', 'Pedestal_Box', 'Stand_Guns', 'Board_Leaderboard', 'Chest_Codes',
			'Chest_GroupReward', 'Stand_SpinWheel', 'Portal_World2', 'Spawn_Pad', 'Target_Dummy', 'Scn_Tree_1', 'Scn_Tree_2',
			'Scn_Bush_1', 'Scn_Cliff_Block', 'Scn_Building_1', 'Scn_Building_2', 'Scn_Building_3', 'Scn_Building_4', 'Scn_Hydrant' } do
			e.truthy(D[id])
		end
		e.near(IM.size('Scn_Cliff_Block').X, 16, 1e-3)
		e.near(IM.size('Tree_1').Y, D.Scn_Tree_1.Max.Y, 1e-6) -- the user's file name is an alias
		e.truthy(IM.size('GunStand_AK') == IM.size('Gun_AK'))
		e.near(IM.muzzle('Gun_AK').Z, D.Gun_AK.Muzzle.Z, 1e-6)
	end)

	t.test('brief 32: the fitting rule keeps proportions (box, largest side, design size)', function()
		local ds = IM.size('Scn_Building_2')
		local k, got = IM.fit('Scn_Building_2', V(10, 100, 100))
		e.near(got.X, 10, 1e-3)
		e.near(got.Y / got.X, ds.Y / ds.X, 1e-4)
		local k2, got2 = IM.fit('Scn_Building_2', 11)
		e.near(math.max(got2.X, got2.Y, got2.Z), 11, 1e-3)
		e.truthy(k2 > 0 and k > 0)
		local k3, got3 = IM.fit('Scn_Building_2')
		e.equal(k3, 1)
		e.truthy(got3 == ds)
	end)

	-- a fake import of new-style items: textured bodies, glow parts, the gate's Colliders, a gun
	local function newFolder()
		local f = Instance.new('Folder')
		f.Name = 'HoodItemMeshes'
		local gate = Instance.new('Model')
		gate.Name = 'Gate_Stage1'
		gate:SetAttribute('Collision', 'solid')
		meshPart('Gate_Stage1', V(20.2, 14.17, 4.7) * K, OFF + V(0, 7.085, -0.15) * K, gate)
		local c = meshPart('Collider', V(5.7, 10, 4.7) * K, OFF + V(7.25, 5, -0.15) * K, gate)
		c.Transparency = 1
		gate.Parent = f
		local b = Instance.new('Model')
		b.Name = 'Scn_Building_1'
		local d = IM.Design.Scn_Building_1
		meshPart('Scn_Building_1', (d.Max - d.Min) * K, OFF + (d.Max + d.Min) / 2 * K, b)
		b.Parent = f
		local pad = Instance.new('Model')
		pad.Name = 'Pad_Base'
		meshPart('Pad_Base', V(8.12, 1.385, 8.12) * K, OFF + V(0, 0.6925, 0) * K, pad)
		meshPart('Pad_Base_Glow_2FD6FF', V(6.66, 0.2, 6.66) * K, OFF + V(0, 0.99, 0) * K, pad)
		pad.Parent = f
		local vip = Instance.new('Model')
		vip.Name = 'Pad_VIP'
		local dv = IM.Design.Pad_VIP
		meshPart('Pad_VIP', (dv.Max - dv.Min) * K, OFF + (dv.Max + dv.Min) / 2 * K, vip)
		vip.Parent = f
		local gun = Instance.new('Model')
		gun.Name = 'Gun_AK'
		local dg = IM.Design.Gun_AK
		gun:SetAttribute('DesignMin', dg.Min)
		gun:SetAttribute('DesignMax', dg.Max)
		gun:SetAttribute('Muzzle', dg.Muzzle)
		gun:SetAttribute('Collision', 'gun')
		meshPart('Gun_AK', (dg.Max - dg.Min) * K, OFF + (dg.Max + dg.Min) / 2 * K, gun)
		gun.Parent = f
		return f
	end

	t.test('brief 32: glow is Neon in its colour, solid items collide (through Colliders when they have them), props do not', function()
		with(newFolder(), function()
			local pad = IM.place('Pad_Base', CFrame.new(0, 3, 0), nil, nil, nil)
			local lo, hi = bounds(pad)
			e.near(hi.X - lo.X, 8.12, 1e-3) -- no size: the design size
			e.near(lo.Y, 3, 1e-3)
			local glow = pad:FindFirstChild('Pad_Base_Glow_2FD6FF')
			e.truthy(glow.Material == Enum.Material.Neon and glow.Color == Color3.fromHex('2FD6FF') and not glow.CanCollide)
			e.truthy(pad.Pad_Base.CanCollide and pad.Pad_Base.Anchored) -- a slab players stand on
			local gate = IM.place('Gate_Stage1', CFrame.new(), V(100, 100, 100), nil, nil)
			e.falsy(gate.Gate_Stage1.CanCollide) -- the opening stays walkable
			e.truthy(gate.Collider.CanCollide and gate.Collider.Transparency == 1)
			local glo, ghi = bounds(gate) -- (Colliders are invisible: the visible box)
			e.near(math.max(ghi.X - glo.X, ghi.Y - glo.Y, ghi.Z - glo.Z), 100, 1e-3)
			e.near(gate.Collider.Size.Y, 10 * 100 / 20.2, 1e-3)
			local b = IM.place('Building_1', CFrame.new(), 30, nil, nil) -- (the user's file name)
			e.truthy(b and b.Scn_Building_1.CanCollide)
			local v = IM.place('Pad_VIP', CFrame.new(), 4, nil, nil)
			e.falsy(v.Pad_VIP.CanCollide or v.Pad_VIP.CanTouch or v.Pad_VIP.CanQuery)
		end)
	end)

	t.test('brief 32: guns use the mesh when imported (grip at the Handle, muzzle forward), Parts otherwise', function()
		local GM = require(RS.Shared.Models.GunModels)
		local GT = require(RS.Shared.GunTool)
		with(Instance.new('Folder'), function()
			local m = GM.build('AK', 1)
			e.falsy(m:GetAttribute('Mesh'))
			local tool = GT.build('AK')
			e.falsy(tool:GetAttribute('Mesh'))
			e.near(tool.Handle.Muzzle.CFrame.Position.Z, GM.Meta.AK.Muzzle.Z, 1e-3)
		end)
		with(newFolder(), function()
			local m = GM.build('AK', 2)
			e.truthy(m:GetAttribute('Mesh'))
			e.truthy(m.PrimaryPart and m.PrimaryPart.Name == 'Handle' and m.PrimaryPart.CFrame.Position.Magnitude < 1e-6)
			local body = m:FindFirstChild('Gun_AK')
			e.truthy(body and body.Massless and not body.CanCollide)
			local lo, hi = bounds(m)
			local dg = IM.Design.Gun_AK
			e.near(lo.Z, dg.Min.Z * 2, 1e-3) -- design studs x scale, grip at the origin
			e.near(hi.Y, dg.Max.Y * 2, 1e-3)
			e.near(m:GetAttribute('Muzzle').Z, dg.Muzzle.Z * 2, 1e-4)
			e.falsy(GM.build('AK', 1, true):GetAttribute('Mesh')) -- partsOnly
			e.falsy(GM.build('Pistol', 1):GetAttribute('Mesh')) -- no mesh for it: Parts
			local tool = GT.build('AK')
			e.truthy(tool:GetAttribute('Mesh') and tool.Handle.Name == 'Handle')
			e.near(tool.Handle.Muzzle.CFrame.Position.Z, dg.Muzzle.Z, 1e-3)
			for _, p in tool:GetDescendants() do
				if p:IsA('BasePart') then e.truthy(not p.Anchored and p.Massless and not p.CanCollide) end
			end
		end)
	end)
end
