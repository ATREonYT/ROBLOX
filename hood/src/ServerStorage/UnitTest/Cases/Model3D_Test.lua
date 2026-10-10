-- (brief 27, INV3D) The items' real 3D models in the UI: UIKit's Kit.model3d / Kit.model3dRow and their studios. One
-- studio per kind, every item framed to the same apparent size, locked items as black silhouettes, the live-viewport
-- cap, and rows of items sharing one viewport. The shared driver is stepped by hand here (Kit.model3dStep).
return function(t)
	local RS = game.ReplicatedStorage
	local Kit = require(RS.Shared.UIKit)
	local Shoes = require(RS.Shared.Config.Shoes)
	local e = t.expect
	local KINDS = { 'shoe', 'gun', 'box' }
	local function idsOf(kind)
		if kind == 'shoe' then return require(RS.Shared.Models.ShoeModels).AllIds end
		if kind == 'gun' then return require(RS.Shared.Models.GunModels).Ids end
		local list = {}
		for _, b in Shoes.Boxes do table.insert(list, b.Id) end
		return list
	end
	local function screen()
		local g = Instance.new('ScreenGui')
		g.Name = 'Model3DTest'
		g.Parent = workspace
		return g
	end
	local function settle()
		for _ = 1, 30 do Kit.model3dStep(1 / 30) end
	end

	t.test('one studio per kind: a 25-40 degree turn, 10-20 down, FOV 20-40, the top brightest, the main face 20-35% darker, no black faces', function()
		for _, kind in KINDS do
			local s = Kit.Studio[kind]
			e.truthy(s ~= nil)
			e.truthy(s.Yaw >= 25 and s.Yaw <= 40)
			e.truthy(s.Pitch >= 10 and s.Pitch <= 20)
			e.truthy(s.Fov >= 20 and s.Fov <= 40)
			-- the key light travels down and into the picture (camera space): from above and in front
			e.truthy(s.Key.Y < 0 and s.Key.Z < 0)
			local amb = 0.299 * s.Ambient.R + 0.587 * s.Ambient.G + 0.114 * s.Ambient.B
			e.truthy(amb >= 0.35 and amb <= 0.55)
			-- a box's faces as the viewport lights them (ambient + light x the lit share, capped): the top brightest, the
			-- main face (Side) 20-35% darker, the end face (Toward) darkest but never black
			local back = Kit.studioView(kind)
			local L = CFrame.lookAt(back * 10, Vector3.zero):VectorToWorldSpace(s.Key.Unit)
			local lit = 0.299 * s.Light.R + 0.587 * s.Light.G + 0.114 * s.Light.B
			local function face(n) return math.min(1, amb + lit * math.max(0, n:Dot(-L))) end
			local top, main, side = face(Vector3.yAxis), face(s.Side), face(s.Toward)
			e.truthy(top >= 0.99 and main <= top * 0.8 and main >= top * 0.65 and side < main and side >= 0.35)
			e.truthy(s.Spin > 0 and s.Spin <= 45)
			e.truthy(s.Bob > 0 and s.Bob <= 0.04 and s.BobHz >= 0.4 and s.BobHz <= 0.6)
			-- the view looks down onto the item by its pitch
			local v = Kit.studioView(kind)
			e.near(math.deg(math.asin(v.Y)), s.Pitch, 0.01)
		end
	end)

	t.test('every shoe pair, gun and box builds from its game model and its BODY fills its cell the same (80%), unless a decoration already reaches MaxReach', function()
		for _, kind in KINDS do
			local s = Kit.Studio[kind]
			for _, id in idsOf(kind) do
				local m, parts = Kit.build3d(kind, id)
				e.truthy(m ~= nil)
				e.truthy(parts >= 10 and parts <= 140) -- (low part counts: phones)
				for _, d in m:GetDescendants() do
					e.falsy(d:IsA('ParticleEmitter') or d:IsA('Light') or d:IsA('Beam') or d:IsA('Trail'))
					if d:IsA('BasePart') then e.truthy(d.Transparency < 0.99) end
				end
				-- framed on the body (wings, spikes and toppers don't shrink a decorated item; guns on max(length, 1.8 x height))
				local cf, dist, _, reach = Kit.frame3d(m, Kit.studioView(kind), s.Fov, 1, s.Fill, nil, Kit.studioFrame(s))
				e.truthy(dist > 0)
				local body = math.max(reach[1], (s.YWeight or 1) * reach[2])
				e.truthy(body <= s.Fill + 0.01 and body >= s.Fill * 0.8)
				-- and the whole model, decorations too, stays inside MaxReach of the cell (inside its viewport: never cut)
				local tanV = math.tan(math.rad(s.Fov / 2))
				local whole = 0
				for _, p in Kit.corners3d(m) do
					local v = cf:PointToObjectSpace(p)
					whole = math.max(whole, math.abs(v.X / (-v.Z * tanV)), math.abs(v.Y / (-v.Z * tanV)))
				end
				e.truthy(whole <= s.MaxReach + 0.01 and s.MaxReach <= (s.Overflow or Kit.Model3DOverflow))
				-- a body under its fill only because a decoration is at MaxReach (the only thing that may make it smaller)
				if body < s.Fill - 0.01 then e.near(whole, s.MaxReach, 0.01) end
				-- every box's tub at the same size (its topper rises, the tub sits lower: never a smaller box)
				if kind == 'box' then e.near(body, s.Fill, 0.04 * s.Fill) end
				m:Destroy()
			end
		end
	end)

	t.test('no part crosses its viewport\'s edge (nothing cut flat): every item in its cell, the hero boxes, the gun in hand, the odds rows', function()
		local g = screen()
		local function worstOf(model, cam, aspect)
			local tanV = math.tan(math.rad(cam.FieldOfView / 2))
			local worst = 0
			for _, p in Kit.corners3d(model) do
				local v = cam.CFrame:PointToObjectSpace(p)
				worst = math.max(worst, math.abs(v.X / (-v.Z * tanV * aspect)), math.abs(v.Y / (-v.Z * tanV)))
			end
			return worst
		end
		local cases = {}
		for _, kind in KINDS do
			for _, id in idsOf(kind) do table.insert(cases, { kind, id, Vector2.new(120, 120), {} }) end
		end
		-- (as Store.client's Exclusive cards and Inventory.client's Guns tab make them)
		for _, b in Shoes.Boxes do
			if b.Robux then table.insert(cases, { 'box', b.Id, Vector2.new(285, 307), { Whole = true, Fill = 0.99, MaxReach = 0.99, Overflow = 1, Pitch = 24, Fov = 14 } }) end
		end
		for _, id in idsOf('gun') do table.insert(cases, { 'gun', id, Vector2.new(170, 170), { Fill = 0.92, YWeight = 1.4 } }) end
		for _, c in cases do
			local h = Kit.model3d(c[1], c[2], c[3], c[4])
			h.Parent = g
			settle()
			local model = h.Viewport:FindFirstChildOfClass('Model')
			e.truthy(model ~= nil)
			if model then e.truthy(worstOf(model, h.Viewport:FindFirstChildOfClass('Camera'), c[3].X / c[3].Y) <= 1) end
			h:Destroy()
		end
		for _, b in Shoes.Boxes do
			local items = {}
			for _, id in b.Shoes do table.insert(items, { Id = id }) end
			local row = Kit.model3dRow('shoe', items, 96, 118, {})
			row.Parent = g
			settle()
			local vp = row.Viewport
			local aspect = (row.Size.X.Offset + vp.Size.X.Offset) / (row.Size.Y.Offset + vp.Size.Y.Offset)
			local n = 0
			for _, m in vp:GetChildren() do
				if m:IsA('Model') then
					n += 1
					e.truthy(worstOf(m, vp:FindFirstChildOfClass('Camera'), aspect) <= 1)
				end
			end
			e.equal(n, #items)
			row:Destroy()
		end
		g:Destroy()
	end)

	t.test('an unknown item shows its drawn picture, never a blank cell', function()
		local g = screen()
		local h = Kit.model3d('shoe', 'NoSuchShoe', 100, {})
		h.Parent = g
		settle()
		local flat = h:FindFirstChild('Flat2D')
		e.truthy(flat ~= nil and flat.Visible)
		e.falsy(h.Viewport.Visible)
		g:Destroy()
	end)

	t.test('a cell builds only once it is on screen; locked items are black silhouettes of the same model', function()
		local g = screen()
		g.Enabled = false
		local h = Kit.model3d('box', 'Street', 120, {})
		h.Parent = g
		settle()
		e.equal(#h.Viewport:GetChildren(), 1) -- (just its camera)
		g.Enabled = true
		settle()
		e.truthy(h.Viewport.Visible)
		e.truthy(h.Viewport:FindFirstChildOfClass('Model') ~= nil)
		local dark = Kit.model3d('shoe', 'FreshCanvas', 100, { Locked = true })
		dark.Parent = g
		settle()
		e.equal(dark.Viewport.ImageColor3, Color3.new(0, 0, 0))
		e.equal(dark:FindFirstChild('RarityGlow'), nil)
		g:Destroy()
	end)

	t.test('at most Kit.Model3DCap live viewports: the rest show their drawn picture', function()
		local g = screen()
		local holders = {}
		for i = 1, Kit.Model3DCap.PC + 6 do
			local h = Kit.model3d('gun', 'Pistol', 60, {})
			h.Parent = g
			holders[i] = h
		end
		for _ = 1, 20 do settle() end
		local live, flat = 0, 0
		for _, h in holders do
			if h.Viewport.Visible then live += 1 end
			local f = h:FindFirstChild('Flat2D')
			if f and f.Visible then flat += 1 end
		end
		e.equal(live, Kit.Model3DCap.PC)
		e.equal(flat, 6)
		e.truthy(Kit.model3dStats().Live <= Kit.Model3DCap.PC)
		e.truthy(Kit.Model3DCap.Phone <= 12)
		g:Destroy()
	end)

	t.test('a row of items shares ONE viewport, each item centred in its own cell at the same fill', function()
		local g = screen()
		local items = {}
		for _, id in Shoes.BoxById.Street.Shoes do table.insert(items, { Id = id, Rarity = Shoes.ById[id].Rarity }) end
		items[#items].Locked = true
		local cell, pitch = 96, 118
		local row = Kit.model3dRow('shoe', items, cell, pitch, {})
		row.Parent = g
		settle()
		local vps = 0
		for _, d in row:GetDescendants() do if d:IsA('ViewportFrame') then vps += 1 end end
		e.equal(vps, 1)
		e.truthy(row.Viewport.Visible)
		local cam = row.Viewport:FindFirstChildOfClass('Camera')
		local models = {}
		for _, d in row.Viewport:GetChildren() do if d:IsA('Model') then table.insert(models, d) end end
		e.equal(#models, #items)
		-- each model's BODY silhouette (its body's corners, seen from the camera) fills ~80% of a cell, centred on its cell
		local tanV = math.tan(math.rad(cam.FieldOfView / 2))
		local studs = 2 * (cam.CFrame.Position.Magnitude) * tanV -- (the viewport's height in studs at the focal plane)
		local perPx = studs / (row.Size.Y.Offset + row.Viewport.Size.Y.Offset) -- (it's taller than the row: its overflow)
		for _, m in models do
			local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
			for _, p in Kit.corners3d(m, Kit.Studio.shoe.Body) do
				local v = cam.CFrame:PointToObjectSpace(p)
				local k = -1 / v.Z * (cam.CFrame.Position.Magnitude)
				x0, x1, y0, y1 = math.min(x0, v.X * k), math.max(x1, v.X * k), math.min(y0, v.Y * k), math.max(y1, v.Y * k)
			end
			local size = math.max(x1 - x0, y1 - y0) / perPx
			e.near(size / cell, Kit.Studio.shoe.Fill, 0.06)
			local cx = (x0 + x1) / 2 / perPx + row.Size.X.Offset / 2
			local nearest = math.huge
			for i = 1, #items do nearest = math.min(nearest, math.abs(cx - Kit.model3dRowX(i, cell, pitch))) end
			e.truthy(nearest < cell * 0.08)
		end
		-- the locked one is black
		local black = 0
		for _, m in models do
			local all = true
			for _, d in m:GetDescendants() do if d:IsA('BasePart') and d.Color ~= Color3.new(0, 0, 0) then all = false end end
			if all then black += 1 end
		end
		e.equal(black, 1)
		g:Destroy()
	end)

	t.test('the gentle spin stays inside MaxReach of the cell (and its viewport) and eases back to the show side', function()
		local g = screen()
		for _, spec in { { 'gun', 'AK' }, { 'shoe', 'StreetAngel' }, { 'box', 'Grail' } } do
			local kind = spec[1]
			local h = Kit.model3d(kind, spec[2], 200, {})
			h.Parent = g
			settle()
			local cam = h.Viewport:FindFirstChildOfClass('Camera')
			local model = h.Viewport:FindFirstChildOfClass('Model')
			local rest = cam.CFrame
			Kit.model3dActive(h, 'hover', true)
			local worst, turned = 0, 0
			local tanV = math.tan(math.rad(Kit.Studio[kind].Fov / 2)) -- (the cell's; the viewport's FOV is wider: its overflow)
			e.near(math.tan(math.rad(cam.FieldOfView / 2)), tanV * (Kit.Studio[kind].Overflow or Kit.Model3DOverflow), 1e-6)
			for _ = 1, 200 do
				Kit.model3dStep(1 / 30)
				turned = math.max(turned, (cam.CFrame.Position - rest.Position).Magnitude)
				for _, p in Kit.corners3d(model) do
					local v = cam.CFrame:PointToObjectSpace(p)
					worst = math.max(worst, math.abs(v.X / (-v.Z * tanV)), math.abs(v.Y / (-v.Z * tanV)))
				end
			end
			e.truthy(turned > 0.5) -- (it turned)
			e.truthy(worst <= Kit.Studio[kind].MaxReach + 0.01) -- (and stayed inside its cell)
			Kit.model3dActive(h, 'hover', false)
			for _ = 1, 120 do Kit.model3dStep(1 / 30) end
			e.truthy((cam.CFrame.Position - rest.Position).Magnitude < 0.05)
		end
		g:Destroy()
	end)

	t.test('a cell scrolled away has no live viewport (just off screen: built, not drawn); scrolled back it shows again', function()
		local g = screen()
		local list = Instance.new('ScrollingFrame')
		list.Size = UDim2.fromOffset(500, 300)
		list.Parent = g
		local row = Kit.model3dRow('shoe', { { Id = 'FreshCanvas' }, { Id = 'RedRocket' } }, 96, 118, {})
		row.Parent = list
		local was = Kit.AbsBox
		local rowY = 900 -- (far below the list's 300 px)
		Kit.AbsBox = function(gui)
			if gui == list then return Vector2.new(0, 0), Vector2.new(500, 300) end
			if gui == row then return Vector2.new(10, rowY), Vector2.new(214, 96) end
			return nil
		end
		local ok, err = pcall(function()
			settle()
			e.falsy(row.Viewport.Visible)
			e.equal(#row.Viewport:GetChildren() - 3, 0) -- (only its camera and two cell marks: never built)
			rowY = 340 -- (just under the list's bottom edge: built and ready, but not drawn)
			settle()
			e.falsy(row.Viewport.Visible)
			e.truthy(#row.Viewport:GetChildren() - 3 == 2)
			e.equal(Kit.model3dStats().Live, 0)
			rowY = 120
			settle()
			e.truthy(row.Viewport.Visible)
			rowY = 900
			settle()
			e.falsy(row.Viewport.Visible)
		end)
		Kit.AbsBox = was
		g:Destroy()
		assert(ok, err)
	end)

	t.test('past the live-parts budget the least-seen cell (a card scrolled mostly away) shows its drawn picture', function()
		local g = screen()
		local list = Instance.new('ScrollingFrame')
		list.Size = UDim2.fromOffset(500, 300)
		list.Parent = g
		local ys, hs = {}, {}
		for i, y in { 20, 150, 280 } do
			local h = Kit.model3d('shoe', 'FreshCanvas', 100, {})
			h.Parent = list
			ys[h], hs[i] = y, h
		end
		local was, budget = Kit.AbsBox, Kit.Model3DParts.PC
		Kit.AbsBox = function(gui)
			if gui == list then return Vector2.new(0, 0), Vector2.new(500, 300) end
			if ys[gui] then return Vector2.new(10, ys[gui]), Vector2.new(100, 100) end
			return nil
		end
		local ok, err = pcall(function()
			settle()
			local one = Kit.model3dStats().Parts / 3
			Kit.Model3DParts.PC = math.floor(one * 2.5)
			settle()
			e.truthy(hs[1].Viewport.Visible and hs[2].Viewport.Visible)
			e.falsy(hs[3].Viewport.Visible) -- (80% of it scrolled away: its picture instead)
			e.truthy(hs[3].Flat2D.Visible)
			e.truthy(Kit.model3dStats().Parts <= Kit.Model3DParts.PC)
			e.equal(Kit.model3dStats().Over, 1)
		end)
		Kit.AbsBox, Kit.Model3DParts.PC = was, budget
		g:Destroy()
		assert(ok, err)
	end)

	t.test('a phone\'s small cells leave out the tiny trim (parts under Kit.LodMin studs), never the body', function()
		for _, id in { 'FreshCanvas', 'BlockRoyalty', 'CandyKingdom' } do
			local full, nFull = Kit.build3d('shoe', id)
			local lite, nLite, counted = Kit.build3d('shoe', id, true)
			e.equal(counted, nFull)
			e.truthy(nLite < nFull)
			local names = {}
			for _, d in lite:GetDescendants() do if d:IsA('BasePart') then names[d.Name] = true end end
			for _, body in { 'Outsole', 'Sole', 'ToeBox', 'Quarter', 'Collar', 'Tongue' } do e.truthy(names[body]) end
			full:Destroy()
			lite:Destroy()
		end
	end)
end
