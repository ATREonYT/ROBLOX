-- (brief 27, REVEAL) The box-opening cinematic: Shared/UnboxCinematic's timelines (ANIMLAB's beat sheets: NORMAL,
-- the welcome gift, PREMIUM, Buy 3 / Buy 8), the kid-safe flash rules, the honest tease, the theme kit (Shared/
-- UnboxThemes: 12 looks, every signature real) and that a run puts EVERYTHING back (camera, Lighting, the Atmosphere,
-- the Sky) and leaves no instance behind, 50 openings in a row, under the particle caps.
return function(t)
	local RS = game.ReplicatedStorage
	local Cine = require(RS.Shared.UnboxCinematic)
	local Themes = require(RS.Shared.UnboxThemes)
	local Shoes = require(RS.Shared.Config.Shoes)
	local Lighting = game:GetService('Lighting')
	local e = t.expect
	local RN = { 'Common', 'Rare', 'Epic', 'Legendary', 'Mythic', 'Secret' }
	local BOXES = { 'Street', 'Graffiti', 'Frost', 'Lava', 'Toxic', 'Candy', 'Ocean', 'Gem', 'Galaxy', 'Gold', 'Exclusive', 'Grail' }

	local function shoeOf(box, rank)
		local b = Shoes.BoxById[box]
		return b.Shoes[b.Robux and rank - 1 or rank]
	end
	local function single(box, rank, extra)
		local info = { Box = box, Shoe = shoeOf(box, rank), Rarity = RN[rank], New = true, Count = 1, Equipped = false }
		for k, v in extra or {} do info[k] = v end
		return info
	end
	local function multi(box, ranks, best, product)
		local list = {}
		for _, r in ranks do table.insert(list, { Shoe = shoeOf(box, r), Rarity = RN[r], New = true, Count = 1, Equipped = false }) end
		local top = list[best]
		return { Box = box, Shoe = top.Shoe, Rarity = top.Rarity, New = true, Count = 1, Equipped = false, Shoes = list, Buy = #ranks, Best = best, Product = product }
	end
	local function robux(box) return Shoes.BoxById[box].Robux ~= nil end
	local function flashesOk(P)
		e.truthy(#P.flashes <= 2)
		for i, f in P.flashes do
			e.truthy(f[3] <= Cine.FlashMax) -- (each white flash <= 0.25 s)
			if i > 1 then e.truthy(f[1] - P.flashes[i - 1][1] >= 1.0) end -- (and at most one a second)
		end
		for _, f in P.soft do e.truthy(f[2] < 0.5) end -- (the soft ones are never white-out)
	end

	t.test('single openings follow the beat sheets: normal ~4.75 s, premium 8.55-9.95 s, all under 10 s', function()
		for _, box in BOXES do
			local first = robux(box) and 2 or 1
			for rank = first, 6 do
				local info = single(box, rank, robux(box) and { Product = 'ShoeBox' .. box } or nil)
				local tier = Cine.tierFor(info)
				e.equal(tier, robux(box) and 'premium' or 'normal')
				local P = Cine.plan(info, { tier = tier })
				e.truthy(P.total <= Cine.MaxSeconds)
				if tier == 'normal' then
					e.near(P.land[1], 0.75, 0.01)
					e.near(P.pop[1], 2.5, 0.01)
					e.truthy(P.land[1] - P.fall0[1] >= 0.25 and P.land[1] - P.fall0[1] <= 0.36) -- (CRITIC5's fall window)
					e.truthy(P.hs[1] >= 0.04 and P.hs[1] <= 0.07)
					if rank == 1 then e.near(P.total, 4.75, 0.01) end
					e.truthy(P.total <= 6.6)
				else
					e.near(P.land[1], 1.25, 0.01)
					e.truthy(P.land[1] - P.fall0[1] >= 0.38 and P.land[1] - P.fall0[1] <= 0.5)
					e.truthy(P.hs[1] >= 0.08 and P.hs[1] <= 0.12)
					e.truthy(P.total >= 8.5 and P.total <= 9.95 + 0.01)
					e.near(P.flash, 4.25, 0.01)
					e.truthy(#P.flashes >= 1 and P.flashes[1][1] == P.flash)
				end
				-- the reveal comes after the pop, the words after the reveal starts, the way out last
				local b = P.best
				e.truthy(P.pop[b] < P.accent[b] and P.accent[b] - 0.1 <= P.banner + 0.5 and P.banner < P.tap and P.tap < P.out)
				flashesOk(P)
			end
		end
	end)

	t.test('the welcome gift is short (auto-continues at 4.4 s) and Reduced Motion plays premium as normal', function()
		local gift = multi('Street', { 1, 2 }, 2)
		e.equal(Cine.tierFor(gift), 'gift')
		e.truthy(Cine.isGift(gift))
		local P = Cine.plan(gift)
		e.equal(P.tier, 'gift')
		e.near(P.out, 4.4, 0.01)
		e.truthy(P.total <= 4.6 + 0.01) -- (ANIMLAB's check 9: the welcome gift <= 4.6 s)
		e.equal(#P.flashes, 0)
		-- even a lucky gift stays short (its extras stop at the Legendary row)
		e.truthy(Cine.plan(multi('Street', { 1, 6 }, 2), { tier = 'gift' }).total <= 4.6 + 0.01)
		-- a paid Buy 3 is never a gift
		e.falsy(Cine.isGift(multi('Grail', { 2, 3, 4 }, 3, 'ShoeBoxGrail3')))
		local R = Cine.plan(single('Grail', 6, { Product = 'ShoeBoxGrail' }), { reduced = true })
		e.equal(R.tier, 'normal')
		e.equal(#R.flashes, 0)
		e.equal(R.hs[1], 0)
	end)

	t.test('Buy 3 / Buy 8: staggered landings, opens in ascending rarity with the best last', function()
		for _, c in { { 'Graffiti', { 1, 4, 2 }, 2 }, { 'Street', { 3, 1, 3 }, 1 }, { 'Galaxy', { 1, 2, 1, 3, 1, 1, 4, 2 }, 7 },
			{ 'Exclusive', { 2, 2, 3, 2, 5, 2, 3, 2 }, 5, 'ShoeBoxExclusive8' }, { 'Grail', { 2, 4, 3 }, 2, 'ShoeBoxGrail3' } } do
			local P = Cine.plan(multi(c[1], c[2], c[3], c[4]))
			e.equal(P.n, #c[2])
			e.truthy(P.total <= Cine.MaxSeconds)
			for i = 2, P.n do e.truthy(P.land[i] > P.land[i - 1]) end
			e.equal(P.order[#P.order], c[3])
			for j = 2, #P.order do
				local a, b = P.order[j - 1], P.order[j]
				e.truthy(P.ranks[a] <= P.ranks[b])
				e.truthy(P.pop[b] >= P.pop[a])
			end
			e.truthy(P.group ~= nil and P.group >= P.pop[c[3]])
			flashesOk(P)
		end
	end)

	t.test('the theme kit: 12 looks, each signature a real one, premium looks complete', function()
		local seen = {}
		for _, box in BOXES do
			local th = Themes.get(box)
			e.truthy(type(th) == 'table' and th.Id == box)
			for _, k in { 'Color', 'Accent', 'Third', 'Rim', 'Deep', 'Relit' } do e.truthy(typeof(th[k]) == 'Color3') end
			e.truthy(type(th.Debris) == 'table' and type(th.Debris.kind) == 'string' and #th.Debris.colors >= 2)
			for _, list in { th.Arrive or {}, th.Land, th.Open, th.Charge or {}, th.Dip or {} } do
				for _, name in list do e.truthy(type(Cine.Sig[name]) == 'function') end
			end
			e.truthy(#th.Land >= 1 and #th.Open >= 1)
			if robux(box) then
				e.truthy(type(th.Rings) == 'table' and #th.Rings == 3)
				e.truthy(type(th.Night) == 'table' and type(th.Lit) == 'table')
				e.truthy(#(th.Charge or {}) >= 1)
			end
			-- every look is its own (a different signature set)
			local key = table.concat(th.Land, ',') .. '|' .. table.concat(th.Open, ',')
			e.falsy(seen[key])
			seen[key] = true
		end
		-- the rarity ladder escalates by channel
		for r = 2, 6 do
			local a, b = Themes.Rarity[r - 1], Themes.Rarity[r]
			e.truthy(b.Sparks >= a.Sparks and b.Rays >= a.Rays and b.Hold >= a.Hold)
		end
	end)

	-- a manual run to its end at a fixed dt (optionally tapping at `tap`), returning the job
	local function run(info, opts, dt, tap)
		local job = Cine.play(info, opts)
		local n = 0
		while not job.Done and n < 400 do
			n += 1
			if tap and job.T >= tap and not job.tapped then
				job.tapped = true
				job:skip()
			end
			job:step(dt)
		end
		return job
	end

	t.test('the honest tease: the seam climbs to the true rarity and never past it', function()
		for _, c in { { 'Street', 1 }, { 'Lava', 3 }, { 'Gold', 5 }, { 'Grail', 4 }, { 'Exclusive', 2 } } do
			local info = single(c[1], c[2], robux(c[1]) and { Product = 'ShoeBox' .. c[1] } or nil)
			local job = Cine.play(info, { manual = true })
			local P = job.Plan
			local stop = P.pop[1] - 0.02
			local last = nil
			while job.T < stop do
				job:step(math.min(1 / 30, stop - job.T))
				local col = job.boxes[1].teaseColor
				if col then last = col end
			end
			local want = c[2] == 1 and Color3.new(1, 1, 1) or Cine.rarityColor(c[2])
			if P.premium then want = want:Lerp(Color3.new(1, 1, 1), 0.7) end -- (white-hot in the dark beat)
			e.truthy(last ~= nil)
			e.near(last.R, want.R, 0.02)
			e.near(last.G, want.G, 0.02)
			e.near(last.B, want.B, 0.02)
			job:finish()
		end
	end)

	t.test('a Buy 8 line-up: all eight in view, none hiding another, the best front and centre', function()
		for _, c in { { 'Galaxy', { 1, 2, 1, 3, 1, 1, 4, 2 }, 7 }, { 'Exclusive', { 2, 2, 3, 2, 5, 2, 3, 2 }, 5, 'ShoeBoxExclusive8' } } do
			local job = Cine.play(multi(c[1], c[2], c[3], c[4]), { manual = true })
			e.falsy(job.Failed)
			local slots = job.slots
			e.truthy(slots ~= nil)
			local rows = {}
			for i = 1, 8 do
				local sl = slots[i]
				e.truthy(sl ~= nil)
				local key = string.format('%.2f', sl.Z)
				rows[key] = rows[key] or {}
				table.insert(rows[key], { x = sl.X, w = i == c[3] and job.pairs[i].width * 1.35 or job.pairs[i].width, i = i })
			end
			-- within a row, neighbours never overlap by more than a sliver
			for _, row in rows do
				table.sort(row, function(a, b) return a.x < b.x end)
				for k = 2, #row do e.truthy(row[k].x - row[k - 1].x >= (row[k].w + row[k - 1].w) * 0.5 * 0.85) end
			end
			local b = slots[c[3]]
			e.near(b.X, 0, 1e-6)
			for i = 1, 8 do e.truthy(slots[i].Z >= b.Z) end -- (nothing in front of the best)
			job:finish()
		end
	end)

	t.test('50 openings in a row: caps kept, camera and Lighting restored exactly, nothing left behind', function()
		local cam = workspace.CurrentCamera
		if not cam then
			cam = Instance.new('Camera')
			cam.Parent = workspace
			workspace.CurrentCamera = cam
		end
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = 70
		cam.CFrame = CFrame.new(10, 20, 30)
		local function snap()
			local s = { cam.CameraType, cam.FieldOfView, cam.CFrame, #Lighting:GetChildren(), #cam:GetChildren(), #workspace:GetChildren() }
			for _, k in Cine.LightProps do
				local ok, v = pcall(function() return (Lighting :: any)[k] end)
				if ok then s[k] = v end
			end
			local atm = Lighting:FindFirstChildOfClass('Atmosphere')
			if atm then
				for _, k in Cine.AtmProps do s['a' .. k] = (atm :: any)[k] end
			end
			local sky = Lighting:FindFirstChildOfClass('Sky')
			if sky then s.stars = sky.StarCount end
			return s
		end
		local before = snap()
		local cases = {
			{ single('Street', 1), nil }, { single('Galaxy', 4), nil }, { single('Grail', 6, { Product = 'ShoeBoxGrail' }), 'premium' },
			{ multi('Graffiti', { 1, 4, 2 }, 2), nil }, { multi('Exclusive', { 2, 2, 3, 2, 5, 2, 3, 2 }, 5, 'ShoeBoxExclusive8'), nil },
			{ multi('Street', { 1, 2 }, 2), 'gift' }, { single('Gold', 6), nil }, { single('Exclusive', 3, { Product = 'ShoeBoxExclusive' }), nil },
		}
		local gui = Instance.new('ScreenGui')
		for k = 1, 50 do
			local c = cases[(k - 1) % #cases + 1]
			local tap = (k % 3 == 0) and 1.0 or nil
			local job = run(c[1], { manual = true, tier = c[2], gui = gui }, 0.1, tap)
			e.truthy(job.Done)
			e.falsy(job.Failed)
			e.truthy((job.peak or 0) <= Cine.Caps[job.Plan.tier] + 0.001)
			e.falsy(Cine.active())
		end
		local after = snap()
		for k, v in before do
			if typeof(v) == 'CFrame' then e.truthy((v.Position - after[k].Position).Magnitude < 1e-4)
			elseif type(v) == 'number' then e.near(after[k], v, 1e-4)
			else e.equal(after[k], v) end
		end
		e.equal(#gui:GetChildren(), 0)
		e.falsy(workspace:FindFirstChild('HoodUnboxStage'))
		gui:Destroy()
	end)
end
