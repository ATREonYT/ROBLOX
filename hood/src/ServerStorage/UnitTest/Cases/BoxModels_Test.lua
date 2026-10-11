-- BoxModels: the 12 shoe boxes keep the contract the hall, the viewports and the box-opening cinematic use (pivot,
-- lid and hinge, topper, the names the cinematic reads) and their part budgets, and brief 28's finish: no name plate,
-- every part of the box's own at least 0.06 thick, one seated stud size, a soft gloss on the lids and metal that
-- reflects, side coins clear of the decor, and the game's own shoes on the Street and Grail lids.
return function(t)
	local RS = game:GetService('ReplicatedStorage')
	local BM = require(RS.Shared.Models.BoxModels)
	local e = t.expect
	local S = BM.Size
	-- each box's parts before brief 28 (Root and Hinge included; Galaxy's held to the phone budget): no box may grow,
	-- except the two that now carry a game shoe, held to the phone budget
	local BUDGET = { Street = 140, Graffiti = 110, Frost = 107, Lava = 103, Toxic = 86, Candy = 113, Ocean = 103, Gem = 95, Galaxy = 140, Gold = 106, Exclusive = 116, Grail = 140 }
	local function inShoe(p)
		local m = p:FindFirstAncestorOfClass('Model')
		return m ~= nil and m.Name == 'Shoe' and m:GetAttribute('ShoeId') ~= nil
	end
	local function partsOf(m)
		local list = {}
		for _, d in m:GetDescendants() do
			if d:IsA('BasePart') then table.insert(list, d) end
		end
		return list
	end
	local function corners(p)
		local out = {}
		for _, sx in { -0.5, 0.5 } do
			for _, sy in { -0.5, 0.5 } do
				for _, sz in { -0.5, 0.5 } do table.insert(out, p.CFrame:PointToWorldSpace(p.Size * Vector3.new(sx, sy, sz))) end
			end
		end
		return out
	end

	t.test('every box builds on its pivot with its lid, hinge and topper, within its part budget', function()
		e.equal(#BM.Ids, 12)
		for _, id in BM.Ids do
			e.truthy(BM.Meta[id] ~= nil and BM.Meta[id].Name == id)
			local at = CFrame.new(10, 2, -5) * CFrame.Angles(0, 0.7, 0)
			local m = BM.build(id, 1, at)
			e.truthy(m.PrimaryPart and m.PrimaryPart.Name == 'Root')
			e.truthy(m.PrimaryPart.CFrame.Position:FuzzyEq(at.Position, 1e-4))
			local lid = m:FindFirstChild('Lid')
			e.truthy(lid and lid.PrimaryPart and lid.PrimaryPart.Name == 'Hinge')
			e.truthy(at:PointToObjectSpace(lid.PrimaryPart.CFrame.Position):FuzzyEq(Vector3.new(0, S.Body, S.D / 2), 1e-4))
			e.truthy(#lid:FindFirstChild('Topper'):GetDescendants() >= 3)
			local n = #partsOf(m)
			e.equal(m:GetAttribute('Parts'), n)
			e.truthy(n <= BUDGET[id] and n <= 140)
			m:Destroy()
		end
	end)

	t.test('the names the cinematic reads are there; the name plate is gone and nothing carries text', function()
		for _, id in BM.Ids do
			local m = BM.build(id, 1)
			local lid = m.Lid
			for _, name in { 'Foot', 'Body', 'BodyBand', 'Inside' } do
				local p = m:FindFirstChild(name, true)
				e.truthy(p ~= nil and not p:IsDescendantOf(lid))
			end
			for _, name in { 'LidRim', 'LidBody', 'LidCap', 'LidInside' } do
				e.truthy(lid:FindFirstChild(name, true) ~= nil)
			end
			e.equal(m:FindFirstChild('Plate', true), nil)
			e.equal(m:FindFirstChild('PlateFrame', true), nil)
			for _, d in m:GetDescendants() do
				e.falsy(d:IsA('SurfaceGui') or d:IsA('TextLabel'))
			end
			-- each face layer is two crossed blocks: the front's block at least 3.2 wide (the cinematic's rainbow face)
			for _, name in { 'Body', 'LidBody' } do
				local front, side = nil, nil
				for _, p in partsOf(m) do
					if p.Name == name and p:IsA('Part') and p.Shape == Enum.PartType.Block then
						if p.Size.Z / S.D >= p.Size.X / S.W then front = p else side = p end
					end
				end
				e.truthy(front and side and front.Size.X >= 3.2 and side.Size.X >= S.W - 0.01)
			end
			m:Destroy()
		end
	end)

	t.test('well built: anchored ghosts, no hair-thin parts, one stud size seated on the cap, the sneaker on its lid', function()
		local studSize
		for _, id in BM.Ids do
			local m = BM.build(id, 1)
			for _, p in partsOf(m) do
				e.truthy(p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery)
				if p.Transparency < 1 and not inShoe(p) then
					e.truthy(math.min(p.Size.X, p.Size.Y, p.Size.Z) >= 0.0599)
				end
				if p.Name == 'Stud' then
					studSize = studSize or p.Size
					e.truthy(p.Size:FuzzyEq(studSize, 1e-4))
					e.near(p.CFrame.Position.Y - p.Size.X / 2, S.Top - 0.02, 0.005)
				end
			end
			if id == 'Street' then
				-- (the shoe stands on the cap, not over it)
				local low = math.huge
				for _, p in partsOf(m.Lid.Topper) do
					for _, c in corners(p) do low = math.min(low, c.Y) end
				end
				e.truthy(low <= S.Top and low >= S.Top - 0.03)
			end
			m:Destroy()
		end
	end)

	t.test('Street and Grail carry the game\'s own shoe on the lid, seated, within the phone budget', function()
		for id, shoeId in BM.TopperShoes do
			local m = BM.build(id, 1)
			local shoe = m.Lid.Topper:FindFirstChild('Shoe')
			e.truthy(shoe ~= nil and shoe:GetAttribute('ShoeId') == shoeId)
			e.equal(shoe.PrimaryPart, nil)
			e.equal(shoe:FindFirstChild('Fit'), nil)
			e.truthy(#partsOf(shoe) >= 20)
			e.truthy(m:GetAttribute('Parts') <= 140)
			-- the sole stands on the lid (Street) or the plinth (Grail): nothing below it, nothing floating
			local low = math.huge
			for _, p in partsOf(shoe) do
				for _, c in corners(p) do low = math.min(low, c.Y) end
			end
			local seat = id == 'Grail' and S.Top + 0.39 or S.Top - 0.01
			e.near(low, seat, 0.005)
			-- Grail's halo hangs clear of the shoe, at the bottom of its bob too
			local halo = m.Lid.Topper:FindFirstChild('Halo')
			if halo then
				for _, hp in partsOf(halo) do
					for _, c in corners(hp) do
						local q = c - Vector3.new(0, 0.15, 0)
						for _, p in partsOf(shoe) do
							local l = p.CFrame:PointToObjectSpace(q)
							e.falsy(math.abs(l.X) < p.Size.X / 2 and math.abs(l.Y) < p.Size.Y / 2 and math.abs(l.Z) < p.Size.Z / 2)
						end
					end
				end
			end
			m:Destroy()
		end
		-- the guard: a shoe too big for the budget loses its smallest pieces, never the box's
		local keep = BM.TopperShoes.Street
		BM.TopperShoes.Street = 'TheGrail'
		local ok, m = pcall(BM.build, 'Grail', 1)
		BM.TopperShoes.Street = keep
		e.truthy(ok and m:GetAttribute('Parts') <= 140)
	end)

	t.test('the side coins are clear: no drip, wing, crack or icicle sits on a coin or runs into it', function()
		for _, id in BM.Ids do
			local m = BM.build(id, 1)
			local coins = {}
			for _, p in partsOf(m) do
				if p.Name == 'Coin' then table.insert(coins, p) end
			end
			e.equal(#coins, 2)
			for _, c in coins do
				-- (the coin's axis is its X; the room just in front of its face, out to 0.4, over the face's disc)
				local out = math.sign(c.CFrame.Position.X)
				for _, p in partsOf(m) do
					if p.Transparency < 1 and not p.Name:match('^Coin') then
						for i = 0, 4 do
							for j = 0, 4 do
								for kk = 0, 4 do
									local q = p.CFrame:PointToWorldSpace(p.Size * Vector3.new(i / 4 - 0.5, j / 4 - 0.5, kk / 4 - 0.5))
									local l = c.CFrame:PointToObjectSpace(q)
									local ahead = l.X * out * math.sign(c.CFrame.RightVector.X)
									local r = math.sqrt(l.Y * l.Y + l.Z * l.Z)
									e.falsy(ahead > 0 and ahead < c.Size.X / 2 + 0.4 and r < c.Size.Y / 2 - 0.1)
								end
							end
						end
					end
				end
			end
			m:Destroy()
		end
	end)

	t.test('the finish: a soft gloss on the lid, metal that reflects', function()
		for _, id in BM.Ids do
			local m = BM.build(id, 1)
			for _, p in partsOf(m) do
				if p.Name == 'LidBody' then e.truthy(p.Reflectance > 0) end
				if p.Material == Enum.Material.Metal or p.Material == Enum.Material.Foil then e.truthy(p.Reflectance > 0) end
				if p.Name == 'Body' then e.equal(p.Reflectance, 0) end
			end
			m:Destroy()
		end
	end)

	t.test('the lid pops open clear of the tub, and shuts back exactly', function()
		for _, id in BM.Ids do
			local m = BM.build(id, 1)
			local lidParts = partsOf(m.Lid)
			local shut = {}
			for _, p in lidParts do shut[p] = p.CFrame end
			BM.openLid(m, 1)
			local root = m.PrimaryPart.CFrame
			for _, p in lidParts do
				if p.Transparency < 1 and not p:IsDescendantOf(m.Lid.Topper) then
					for _, c in corners(p) do
						local l = root:PointToObjectSpace(c)
						-- (nothing of the lid inside the tub below its rim; the rim's back edge, behind the hinge, may
						-- graze the back wall's top as it swings down)
						e.falsy(math.abs(l.X) < S.W / 2 - 0.1 and math.abs(l.Z) < S.D / 2 - 0.1 and l.Y < S.Body - 0.1)
					end
				end
			end
			BM.openLid(m, 0)
			for _, p in lidParts do e.truthy(p.CFrame.Position:FuzzyEq(shut[p].Position, 1e-3)) end
			m:Destroy()
		end
	end)

	t.test('floating pieces get their idle motion from animate', function()
		for _, id in BM.Ids do
			local m = BM.build(id, 1)
			BM.animate(m)
			for _, d in m:GetDescendants() do
				if d:IsA('Model') and (d:GetAttribute('AnimSpin') or d:GetAttribute('AnimBob')) then
					e.truthy(d:HasTag('HoodMotion'))
				end
			end
			m:Destroy()
		end
	end)
end
