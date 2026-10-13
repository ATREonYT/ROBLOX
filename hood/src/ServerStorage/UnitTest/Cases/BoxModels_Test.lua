-- BoxModels: every shoe box keeps the contract the hall, the viewports and the box opening use (pivot, lid and hinge,
-- topper, the names the reveal reads) within its part budget. (brief 30) World 1's boxes are the user's chests (BoxKit
-- rows in BoxParts): hollow, with a handle and a hinged lid that swings open onto the inside like the sheets' open view,
-- and the seal data the reveal lays its tape on. The later worlds' boxes keep brief 28's kit (coins, toppers).
return function(t)
	local RS = game:GetService('ReplicatedStorage')
	local BM = require(RS.Shared.Models.BoxModels)
	local Parts = require(RS.Shared.Models.BoxParts)
	local e = t.expect
	local S = BM.Size
	local CHESTS = { 'Street', 'Graffiti', 'Exclusive', 'Grail', 'GrailBundle' }
	local isChest = {}
	for _, id in CHESTS do isChest[id] = true end
	-- each legacy box's parts before brief 30 (Root and Hinge included): none may grow
	local BUDGET = { Frost = 107, Lava = 103, Toxic = 86, Candy = 113, Ocean = 103, Gem = 95, Galaxy = 140, Gold = 106 }
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
	local function inside(p, q)
		local l = p.CFrame:PointToObjectSpace(q)
		return math.abs(l.X) < p.Size.X / 2 and math.abs(l.Y) < p.Size.Y / 2 and math.abs(l.Z) < p.Size.Z / 2
	end

	t.test('every box builds on its pivot with its lid, hinge and topper, within its part budget', function()
		e.equal(#BM.Ids, 13)
		for _, id in BM.Ids do
			e.truthy(BM.Meta[id] ~= nil and BM.Meta[id].Name == id and type(BM.Meta[id].Display) == 'string')
			local at = CFrame.new(10, 2, -5) * CFrame.Angles(0, 0.7, 0)
			local m = BM.build(id, 1, at)
			e.truthy(m.PrimaryPart and m.PrimaryPart.Name == 'Root')
			e.truthy(m.PrimaryPart.CFrame.Position:FuzzyEq(at.Position, 1e-4))
			local lid = m:FindFirstChild('Lid')
			e.truthy(lid and lid.PrimaryPart and lid.PrimaryPart.Name == 'Hinge' and lid.PrimaryPart.Transparency == 1)
			e.truthy(at:PointToObjectSpace(lid.PrimaryPart.CFrame.Position):FuzzyEq(Vector3.new(0, S.Body, S.D / 2), 1e-4))
			e.truthy(#lid:FindFirstChild('Topper'):GetDescendants() >= 3)
			local n = #partsOf(m)
			e.equal(m:GetAttribute('Parts'), n)
			e.truthy(n <= (BUDGET[id] or 220) and n <= (isChest[id] and 220 or 140))
			m:Destroy()
		end
	end)

	t.test('the chests are BoxKit rows: shown under their new names, one frame for all, scale applies', function()
		e.equal(BM.Meta.Exclusive.Display, 'Chrome Box')
		e.equal(BM.Meta.Grail.Display, 'Crown Box')
		e.equal(BM.Meta.GrailBundle.Display, 'The Grail Bundle')
		e.truthy(Parts.Size.W == S.W and Parts.Size.D == S.D and Parts.Size.Body == S.Body and Parts.Size.Top == S.Top)
		for _, id in CHESTS do
			local rows = Parts.Boxes[id].Parts
			local m = BM.build(id, 1)
			e.equal(#partsOf(m), #rows + 1) -- (the Root)
			-- scale 2: twice the size, the hinge where the scaled tub's back top edge is
			local m2 = BM.build(id, 2)
			e.truthy(m2.PrimaryPart.CFrame:PointToObjectSpace(m2.Lid.PrimaryPart.CFrame.Position):FuzzyEq(Vector3.new(0, S.Body * 2, S.D), 1e-3))
			m:Destroy()
			m2:Destroy()
		end
	end)

	t.test('the names the reveal reads are there and nothing carries text', function()
		for _, id in BM.Ids do
			local m = BM.build(id, 1)
			local lid = m.Lid
			for _, name in { 'Foot', 'Body', 'Inside' } do
				local p = m:FindFirstChild(name, true)
				e.truthy(p ~= nil and not p:IsDescendantOf(lid))
			end
			for _, name in { 'LidBody', 'LidCap', 'LidInside' } do
				e.truthy(lid:FindFirstChild(name, true) ~= nil)
			end
			for _, d in m:GetDescendants() do
				e.falsy(d:IsA('SurfaceGui') or d:IsA('TextLabel'))
			end
			m:Destroy()
		end
	end)

	t.test('well built: anchored ghosts, no hair-thin parts, standing on its foot', function()
		for _, id in BM.Ids do
			local m = BM.build(id, 1)
			local low = math.huge
			for _, p in partsOf(m) do
				e.truthy(p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery)
				if p.Transparency < 1 then
					e.truthy(math.min(p.Size.X, p.Size.Y, p.Size.Z) >= 0.0599)
					for _, c in corners(p) do low = math.min(low, c.Y) end
				end
			end
			e.near(low, 0, 0.12)
			m:Destroy()
		end
	end)

	t.test('a chest is hollow: its tub has an inside floor and walls, its lid an inside plate', function()
		for _, id in CHESTS do
			local m = BM.build(id, 1)
			local lid = m.Lid
			-- the middle of the tub, under the seam, is empty (the open view shows the inside like the sheets)
			for _, q in { Vector3.new(0, S.Body - 0.3, 0), Vector3.new(0.8, 1.2, 0.5), Vector3.new(-1, 0.9, -0.6) } do
				for _, p in partsOf(m) do
					if not p:IsDescendantOf(lid) and p.Transparency < 1 then e.falsy(inside(p, q)) end
				end
			end
			-- the floor sits low, the walls reach the seam
			local floor, wallTop = math.huge, -math.huge
			for _, p in partsOf(m) do
				if p.Name == 'Inside' then
					local top = p.CFrame.Position.Y + p.Size.Y / 2
					if p.Size.X > S.W - 0.2 and p.Size.Z > S.D - 0.2 then floor = math.min(floor, top) else wallTop = math.max(wallTop, top) end
				end
			end
			e.truthy(floor < 0.6 and wallTop > S.Body - 0.05)
			m:Destroy()
		end
	end)

	t.test('the lid swings open clear of the tub, and shuts back exactly', function()
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
						e.falsy(math.abs(l.X) < S.W / 2 - 0.1 and math.abs(l.Z) < S.D / 2 - 0.1 and l.Y < S.Body - 0.1)
					end
				end
			end
			BM.openLid(m, 0)
			for _, p in lidParts do e.truthy(p.CFrame.Position:FuzzyEq(shut[p].Position, 1e-3)) end
			m:Destroy()
		end
	end)

	t.test('the seal data: the tape lies on the chest\'s front, crossing the seam', function()
		for _, id in CHESTS do
			local s = BM.Seal[id]
			e.truthy(type(s) == 'table' and s.Body and s.Lid and s.Low and s.Top)
			e.truthy(s.Body <= -S.D / 2 and s.Lid <= -S.D / 2 and s.Low < S.Body and s.Low > S.Body - 0.8 and s.Top >= S.Top - 0.01)
			-- nothing of the box stands in front of the tape's two pieces (the middle of the front, either side of the seam)
			local m = BM.build(id, 1)
			for _, q in { Vector3.new(0.2, (s.Low + S.Body) / 2, s.Body - 0.05), Vector3.new(-0.2, S.Body + 0.3, s.Lid - 0.05) } do
				for _, p in partsOf(m) do
					if p.Transparency < 1 then e.falsy(inside(p, q)) end
				end
			end
			m:Destroy()
		end
	end)

	t.test('the later worlds\' boxes keep their side coins and a soft gloss on the lid', function()
		for _, id in BM.Ids do
			if not isChest[id] then
				local m = BM.build(id, 1)
				local coins = 0
				for _, p in partsOf(m) do
					if p.Name == 'Coin' then coins += 1 end
					if p.Name == 'LidBody' then e.truthy(p.Reflectance > 0) end
					if p.Material == Enum.Material.Metal or p.Material == Enum.Material.Foil then e.truthy(p.Reflectance > 0) end
				end
				e.equal(coins, 2)
				m:Destroy()
			end
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
