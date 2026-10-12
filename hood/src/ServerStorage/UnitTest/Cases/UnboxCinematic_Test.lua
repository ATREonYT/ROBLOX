-- (brief 27/28/28c, REVEAL) The box openings: Shared/UnboxCinematic's timelines (brief 28c: every non-Secret opening is
-- an egg hatch in the world, Shared/UnboxWorld (the drop, three escalating shakes, the squeeze, the pop, the card with
-- name, rarity and chance, the hold until a tap), a Legendary's or Mythic's box is its rainbow version, a Secret from
-- any box is a chain: the prelude in the world, the cut, the crazy sheet, and a batch's summary), the kid-safe flash rules, the honest tease, the theme kit (Shared/UnboxThemes) and that a run puts
-- EVERYTHING back (camera, Lighting, the Atmosphere, the Sky) and leaves no instance behind, 50 openings in a row,
-- under the particle caps.
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
	local function robux(box) return Shoes.BoxById[box].Robux ~= nil end
	local function single(box, rank, extra)
		local info = { Box = box, Shoe = shoeOf(box, rank), Rarity = RN[rank], New = true, Count = 1, Equipped = false }
		if robux(box) then info.Product = 'ShoeBox' .. box end
		for k, v in extra or {} do info[k] = v end
		return info
	end
	local function multi(box, ranks, best)
		local list = {}
		for _, r in ranks do table.insert(list, { Shoe = shoeOf(box, r), Rarity = RN[r], New = true, Count = 1, Equipped = false }) end
		local top = list[best]
		return { Box = box, Shoe = top.Shoe, Rarity = top.Rarity, New = true, Count = 1, Equipped = false, Shoes = list, Buy = #ranks, Best = best, Product = robux(box) and ('ShoeBox' .. box .. #ranks) or nil }
	end
	local function flashesOk(P)
		for i, f in P.flashes do
			-- (each white flash <= 0.25 s; in the world the wash's Quad Out tail is long and faint: it is above a quarter of its
			-- peak for <= 0.25 s)
			local len = P.inworld and ((f[4] or 0) + 0.5 * (f[3] - (f[4] or 0))) or f[3]
			e.truthy(len <= Cine.FlashMax)
			if i > 1 then e.truthy(f[1] - P.flashes[i - 1][1] >= 1.0) end -- (and at most one a second)
		end
		-- (the soft ones are never white-out: CRITIC5's overlay caps, a plain egg's pop <= 0.2, a rainbow box's <= 0.35;
		-- in the world Common-Epic's wash <= 0.5; Reduced Motion's washes <= 0.15)
		for _, f in P.soft do e.truthy(f[2] <= (P.reduced and 0.15 or P.inworld and 0.5 or (P.rainbow and P.rainbow[P.best] or 0) > 0 and 0.35 or 0.2)) end
	end
	-- copy_spec v5 §11.5 (28c, in the world): 3 hop-and-roll shakes at 0.90 / 1.65 / 2.20 (a Legendary's or Mythic's 4 at
	-- 0.90 / 1.80 / 2.55 / 3.15), 0.18-0.25 s each, the roll x1.3-1.6 a shake, the hops growing, the gaps shrinking
	local function worldShakesOk(P, lux)
		local W = P.wobSpec
		local at = lux and { 0.9, 1.8, 2.55, 3.15 } or { 0.9, 1.65, 2.2 }
		e.equal(#W, #at)
		for k, w in W do
			e.near(w[1], at[k], 0.05)
			e.truthy(w[4] >= 0.18 - 1e-6 and w[4] <= 0.25 + 1e-6)
			if k > 1 then
				local g = w[2] / W[k - 1][2]
				e.truthy(g >= 1.3 and g <= 1.6)
				e.truthy(w[3] > W[k - 1][3])
				if k > 2 then e.truthy(w[1] - W[k - 1][1] <= W[k - 1][1] - W[k - 2][1] + 1e-6) end
			end
		end
	end
	-- CRITIC5's egg windows (rubric 28): 3 shakes of 150-260 ms, rests of 100-250 ms that shrink, each x1.3-1.6
	local function shakesOk(P)
		local W = P.wobSpec
		e.equal(#W, 3)
		for k, w in W do
			e.truthy(w[4] >= 0.15 and w[4] <= 0.26)
			if k > 1 then
				local rest = w[1] - (W[k - 1][1] + W[k - 1][4])
				e.truthy(rest >= 0.1 and rest <= 0.25)
				local g = w[2] / W[k - 1][2]
				e.truthy(g >= 1.3 and g <= 1.6)
			end
		end
		e.truthy((W[2][1] - W[1][1] - W[1][4]) > (W[3][1] - W[2][1] - W[2][4]))
	end

	t.test('every non-Secret single opens in the world (28c, copy_spec v5): the drop lands at 0.35, 3 shakes (Legendary/Mythic 4), the squeeze, the pop at 2.95 (3.80), the pair risen and settled by +0.8 s (brief 30), the reveal complete by 4.3 s (5.3), auto-close 5-7 s after, the close <= 0.6 s', function()
		e.truthy(Cine.InWorld)
		for _, box in BOXES do
			for rank = robux(box) and 2 or 1, 5 do
				local info = single(box, rank)
				e.equal(Cine.tierFor(info), 'egg')
				local P = Cine.plan(info)
				e.truthy(P.egg and P.inworld and not P.premium)
				local lux = rank >= 4
				e.near(P.land[1], 0.35, 0.05)
				e.near(P.land[1] - P.appear[1], 0.25, 0.02) -- (the drop: Quad In 0.25 s from the top of the screen)
				worldShakesOk(P, lux)
				e.near(P.pop[1], lux and 3.8 or 2.95, 0.05)
				e.near(P.squeeze[1], lux and 3.25 or 2.45, 0.05)
				e.truthy(P.squeeze[2] <= P.pop[1] and P.squeeze[3] >= 0.8 and P.squeeze[3] <= 0.9)
				-- the reveal: the pair risen out of the chest and settled (brief 30: one smooth move, <= 0.8 s), the words and the
				-- reveal card (P.tap) as it settles, the Power reel done
				e.truthy(P.accent[1] > P.pop[1] + 0.5 and P.accent[1] <= P.pop[1] + 0.8)
				e.truthy(P.nameT > P.pop[1] + 0.5 and P.nameT <= P.accent[1] and P.tap <= P.accent[1])
				e.truthy(P.count[2] <= (lux and 5.3 or 4.3) + 1e-6)
				e.near(P.count[2] - P.count[1], 0.6, 0.05)
				-- the hold: until a tap, auto-close 5-7 s after the reveal; the close <= 0.6 s
				e.truthy(P.out - P.accent[1] >= 5 and P.out - P.accent[1] <= 7)
				e.truthy(P.closeLen <= 0.6 and math.abs(P.done - P.out - P.closeLen) < 1e-6)
				-- the wash: Common-Epic soft (<= 0.5), Legendary/Mythic white (<= 0.85), at the pop
				if lux then
					e.equal(#P.flashes, 1)
					e.equal(#P.soft, 0)
					e.truthy(P.flashes[1][2] <= 0.85 and math.abs(P.flashes[1][1] - P.pop[1]) < 1e-6)
					e.truthy(P.spinBest ~= nil and P.spinBest[2] >= 2)
				else
					e.equal(#P.flashes, 0)
					e.equal(#P.soft, 1)
					e.truthy(P.soft[1][2] <= 0.5)
				end
				flashesOk(P)
				-- (the box looks like itself at every rarity: no rainbow version)
				e.equal(P.rainbow[1], 0)
				e.truthy(type(P.chance) == 'number' and P.chance > 0 and P.chance < 100)
				e.truthy(P.banner <= P.tap and P.tap < P.out)
				-- Legendary / Mythic build up harder: the 4th shake >= 1.2x the 3rd, a Mythic's >= 1.15x a Legendary's
				if lux then e.truthy(P.wobSpec[4][2] >= 1.2 * P.wobSpec[3][2]) end
				if rank == 5 then e.truthy(P.wobSpec[4][2] >= 1.15 * Cine.plan(single(box, 4)).wobSpec[4][2]) end
				-- Reduced Motion: no wash
				local R = Cine.plan(info, { reduced = true })
				e.equal(#R.flashes + #R.soft, 0)
			end
		end
		e.equal(Cine.chanceText(3), '3%')
		e.equal(Cine.chanceText(0.45), '0.45%')
		e.equal(Cine.chanceText(9.5), '9.5%')
	end)

	t.test('a Secret from any box: the prelude in the world (the drop, two shakes), the cut at 1.9-2.4 s, the crazy sheet with the reference\'s animated middle, <= 12.5 s, no flash at the cut', function()
		for _, box in BOXES do
			local info = single(box, 6)
			e.equal(Cine.tierFor(info), 'secret')
			local P = Cine.plan(info)
			e.truthy(P.secret)
			e.equal(#P.segments, 2)
			e.equal(P.segments[1].kind, 'prelude')
			e.equal(P.segments[2].kind, 'crazy')
			local pre, crazy = P.segments[1].plan, P.segments[2].plan
			e.truthy(pre.inworld)
			e.equal(#pre.wobSpec, 2)
			e.truthy(P.cutAt >= 1.9 and P.cutAt <= 2.4)
			e.truthy(pre.cue and pre.cue < P.cutAt and P.cutAt - pre.cue >= 0.15 and P.cutAt - pre.cue <= 0.45)
			e.truthy(P.total <= 12.5 + 1e-6)
			e.truthy(crazy.premium and crazy.rank == 6)
			-- (copy_spec §1 beats 9-14 in order: the whip, the carousel, the pick, the tease, the dusk, the rings)
			e.truthy(crazy.flash < crazy.whip[1] and crazy.whip[2] <= crazy.carousel[1] and crazy.carousel[2] <= crazy.pick[1])
			e.truthy(crazy.pick[2] <= crazy.tease[1] and crazy.tease[2] <= crazy.dusk[1] and crazy.dusk[2] <= crazy.rings2[1])
			e.truthy(crazy.carousel[2] - crazy.carousel[1] >= 2.0)
			-- (the prelude's box looks plain: it under-promises; never a rainbow that then reveals less)
			e.equal(pre.rainbow[1], 0)
			e.equal(#pre.flashes, 0)
			-- (the slam's white comes >= 0.5 s after the darkening (0.15 s) ends; the seam itself never flashes)
			for _, f in P.flashes do e.truthy(f[1] >= P.cutAt + 0.15 + 0.5 - 1e-6) end
			e.equal(#P.flashes, 3)
			for k = 2, 3 do e.truthy(P.flashes[k][1] - P.flashes[k - 1][1] >= 1.9 - 1e-6) end
			flashesOk(P)
			e.truthy(P.accent[P.best] > P.cutAt and P.accent[P.best] < P.out)
		end
		-- Reduced Motion: the same chain, no white flash, no hit-stop, half the shake
		local R = Cine.plan(single('Grail', 6), { reduced = true })
		e.equal(R.tier, 'secret')
		e.equal(#R.flashes, 0)
		for _, f in R.soft do e.truthy(f[2] <= 0.5) end
		e.equal(R.segments[2].plan.hs[1], 0)
	end)

	t.test('the welcome gift opens in the world: two boxes, the reveal complete by 4.6 s, auto-close 5-7 s after', function()
		local gift = multi('Street', { 1, 2 }, 2)
		e.equal(Cine.tierFor(gift), 'gift')
		e.truthy(Cine.isGift(gift))
		local P = Cine.plan(gift)
		e.equal(P.tier, 'gift')
		e.truthy(P.egg and P.inworld)
		e.equal(P.n, 2)
		e.truthy(P.count[2] <= 4.6)
		e.truthy(P.out - P.accent[P.best] >= 5 and P.out - P.accent[P.best] <= 7)
		e.equal(#P.flashes, 0)
		flashesOk(P)
		e.falsy(Cine.isGift(multi('Grail', { 2, 3, 4 }, 3)))
	end)

	t.test('Buy 3 / Buy 8 in the world (28c): staggered drops, shakes together, pops in rising rarity in place, the last reveal by 6 s / 8 s; a Secret batch <= 14 s', function()
		for _, c in { { 'Graffiti', { 1, 4, 2 }, 2 }, { 'Street', { 3, 1, 3 }, 1 }, { 'Galaxy', { 1, 2, 1, 3, 1, 1, 4, 2 }, 7 },
			{ 'Exclusive', { 2, 2, 3, 2, 5, 2, 3, 2 }, 5 }, { 'Grail', { 2, 4, 3 }, 2 } } do
			local P = Cine.plan(multi(c[1], c[2], c[3]))
			e.equal(P.tier, 'egg')
			e.truthy(P.inworld)
			e.equal(P.n, #c[2])
			local last = 0
			for i = 1, P.n do last = math.max(last, P.accent[i]) end
			e.truthy(last <= (P.n >= 5 and 8 or 6))
			e.truthy(P.out - P.accent[P.best] >= 5 and P.out - P.accent[P.best] <= 7)
			for i = 2, P.n do
				local gap = P.land[i] - P.land[i - 1]
				e.truthy(gap >= 0.06 - 1e-6 and gap <= 0.15 + 1e-6)
			end
			-- (they shake together: the same three shakes, a box's own offset <= 0.15 s)
			worldShakesOk(P, false)
			for i = 1, P.n do e.truthy(P.wobOff[i] <= 0.15) end
			e.equal(P.order[#P.order], c[3])
			for j = 2, #P.order do
				local a, b = P.order[j - 1], P.order[j]
				e.truthy(P.ranks[a] <= P.ranks[b])
				e.truthy(P.pop[b] > P.pop[a])
			end
			for i in P.ranks do e.equal(P.rainbow[i], 0) end
			-- (the best, Legendary or better, gets the bigger reveal: the extra spin and the white wash)
			if P.rank >= 4 then
				e.truthy(P.spinBest ~= nil)
				e.equal(#P.flashes, 1)
			end
			flashesOk(P)
		end
		for _, c in { { 'Exclusive', { 2, 2, 3, 2, 6, 2, 3, 2 }, 5 }, { 'Street', { 1, 6, 2 }, 2 } } do
			local P = Cine.plan(multi(c[1], c[2], c[3]))
			e.equal(P.tier, 'secret')
			e.equal(#P.segments, 3)
			e.equal(P.segments[3].kind, 'summary')
			e.truthy(P.segments[1].plan.inworld)
			e.truthy(P.total <= 14.0 + 1e-6)
			-- (the cut comes after the row's shakes)
			local pre = P.segments[1].plan
			for _, w in pre.wobSpec do e.truthy(w[1] < P.cutAt) end
			flashesOk(P)
		end
	end)

	t.test('the Secret carousel is honest: five real candidates from that box\'s odds row, the true pair among them once, picked', function()
		for _, box in BOXES do
			local P = Cine.plan(single(box, 6))
			local crazy = P.segments[2].plan
			local trueId = P.list[P.best].Shoe
			local row = {}
			for _, id in Shoes.BoxById[box].Shoes do row[id] = true end
			local ids = crazy.carouselIds
			e.equal(#ids, math.min(5, #Shoes.BoxById[box].Shoes))
			local seen, trues = {}, 0
			for _, id in ids do
				e.truthy(row[id]) -- (every candidate is from this box's odds row)
				e.falsy(seen[id])
				seen[id] = true
				if id == trueId then trues += 1 end
			end
			e.equal(trues, 1)
			e.equal(ids[crazy.carouselTrue], trueId) -- (the pick lands on the true pair)
		end
	end)

	t.test('the theme kit: 12 looks, each signature a real one; the egg tuning is data', function()
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
			e.truthy(type(th.Rings) == 'table' and #th.Rings == 3)
			-- (the Secret's neon rings stay saturated: never pastel)
			e.truthy(type(th.Neon) == 'table' and #th.Neon == 2)
			for _, c in th.Neon do
				local _, sat = c:ToHSV()
				e.truthy(sat >= 0.7)
			end
			local key = table.concat(th.Land, ',') .. '|' .. table.concat(th.Open, ',')
			e.falsy(seen[key])
			seen[key] = true
		end
		for r = 2, 6 do
			local a, b = Themes.Rarity[r - 1], Themes.Rarity[r]
			e.truthy(b.Sparks >= a.Sparks and b.Rays >= a.Rays and b.Hold >= a.Hold)
		end
		local E = Themes.Egg
		e.equal(#E.Shakes, 3)
		e.equal(#E.Pauses, 2)
		local L, Mh = E.Rainbow[1], E.Rainbow[2]
		e.truthy(L.sweep >= 0.25 and L.sweep <= 0.6)
		e.truthy(Mh.sweep >= 1.8 * L.sweep)
		e.truthy(Mh.pop > L.pop and L.pop > 1)
	end)

	-- a manual run to its end at a fixed dt (optionally tapping at `tap`), returning the job
	local function run(info, opts, dt, tap)
		local job = Cine.play(info, opts)
		local n = 0
		while not job.Done and n < 600 do
			n += 1
			if tap and job.T >= tap and not job.tapped then
				job.tapped = true
				job:skip()
			end
			job:step(dt)
		end
		return job
	end

	t.test('the smooth opening (brief 30): the crack widens and leaks light, a column rises, the pair rises out of the chest 0 -> 1.1 -> 1 while the chest sinks and fades, nothing jumps', function()
		local World = require(RS.Shared.UnboxWorld)
		local R = Themes.World.Rise
		e.truthy(R.over >= 1.05 and R.over <= 1.15 and R.scale0 <= 0.1)
		for _, rank in { 1, 3, 4, 5 } do
			local job = Cine.play(single('Street', rank), { manual = true })
			local P = job.Plan
			local pop, fit = P.pop[1], job.pairFit[1]
			local box = job.boxes[1]
			-- (the build-up: before the pop the crack leaks rays and a pool of light glows under the box)
			while job.T < pop - 0.05 do job:step(1 / 30) end
			local leaks = 0
			for _, l in box.leaks do if l.beam.Enabled then leaks += 1 end end
			e.truthy(leaks >= 3 and box.pool.Enabled)
			-- (frame by frame through the pop: the pair's scale and place change smoothly, the chest never vanishes at once)
			local lastS, lastY, lastFade = nil, nil, 0
			local slotY = job.boxes[1].home:PointToObjectSpace(job:wp(job.slots[1])).Y
			local peak, colOn = 0, false
			while job.T < pop + R.len + 0.3 do
				job:step(1 / 30)
				local t = job.T
				if t >= pop then
					local cf, S = World.pairAt(job, 1, t)
					e.truthy(cf ~= nil)
					local y = box.home:PointToObjectSpace(cf * Vector3.new(0, 0, 0)).Y
					local s = S / fit
					peak = math.max(peak, s)
					if lastS then
						e.truthy(math.abs(s - lastS) <= 0.2)
						e.truthy(math.abs(y - lastY) <= 0.2 * box.fullH)
					end
					lastS, lastY = s, y
					local _, _, _, lid = World.boxAt(job, 1, t)
					if lid.hidden then
						e.truthy(lastFade >= 0.9) -- (gone only once it has faded)
					else
						e.truthy((lid.fade or 0) >= lastFade - 1e-6)
						lastFade = lid.fade or 0
					end
					if box.column.core.Enabled then colOn = true end
				end
			end
			e.truthy(peak >= 1.05 and peak <= 1.15)
			e.near(lastS, 1, 0.02)
			e.truthy(colOn)
			e.truthy(lastFade >= 0.9)
			job:finish()
		end
	end)

	t.test('the honest tease: the seam climbs to the true rarity and never past it', function()
		for _, c in { { 'Street', 1 }, { 'Lava', 3 }, { 'Gold', 5 }, { 'Grail', 4 }, { 'Exclusive', 2 } } do
			local job = Cine.play(single(c[1], c[2]), { manual = true })
			local P = job.Plan
			local stop = P.pop[1] - 0.02
			local last = nil
			while job.T < stop do
				job:step(math.min(1 / 30, stop - job.T))
				local col = job.boxes[1].teaseColor
				if col then last = col end
			end
			local want = c[2] == 1 and Color3.new(1, 1, 1) or Cine.rarityColor(c[2])
			e.truthy(last ~= nil)
			e.near(last.R, want.R, 0.02)
			e.near(last.G, want.G, 0.02)
			e.near(last.B, want.B, 0.02)
			job:finish()
		end
	end)

	t.test('a box looks like itself at every rarity (no rainbow); a Legendary or Mythic escalates after the pop: a bigger burst, bigger rays, a longer spin', function()
		e.falsy(Cine.RainbowBoxes)
		local function colours(rank)
			local job = Cine.play(single('Street', rank), { manual = true })
			for _ = 1, 8 do job:step(0.1) end
			local out = {}
			for _, d in job.boxes[1].model:GetDescendants() do
				if d:IsA('BasePart') then table.insert(out, d.Name .. ':' .. tostring(d.Color)) end
				e.falsy(d.Name == 'RainbowFace' or d.Name == 'RainbowStars' or d.Name == 'RainbowHalo')
			end
			e.truthy(job.boxes[1].rb == nil and job.boxes[1].stars == nil and job.boxes[1].mring == nil)
			local burst, rays = job.burst, #job.rays
			job:finish()
			table.sort(out)
			return table.concat(out, '|'), burst, rays
		end
		local c3, b3 = colours(3)
		local c4, b4 = colours(4)
		local c5, b5 = colours(5)
		e.equal(c4, c3)
		e.equal(c5, c3)
		-- (the burst: Legendary >= 1.3x Epic's, Mythic >= 1.2x Legendary's)
		e.truthy(b4 >= 1.3 * b3 and b5 >= 1.2 * b4)
		local R = Themes.World.Rays
		e.truthy(R.lux >= 1.3 and R.mythic >= 1.15 * R.lux)
		local L, Mp = Cine.plan(single('Street', 4)), Cine.plan(single('Street', 5))
		e.truthy(L.spinBest[2] >= 1.5 and Mp.spinBest[2] >= 2)
	end)

	t.test('in the world: the rig stands in front of the held camera, the box centred at about a third of the height, a row all in view, each pair in its box\'s place', function()
		local World = require(RS.Shared.UnboxWorld)
		local cam = workspace.CurrentCamera
		if not cam then
			cam = Instance.new('Camera')
			cam.Parent = workspace
			workspace.CurrentCamera = cam
		end
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = 70
		cam.CFrame = CFrame.lookAt(Vector3.new(0, 9, -12), Vector3.new(0, 5, 0))
		local function boxPts(box)
			local list = {}
			for _, x in { -1, 1 } do
				for _, y in { 0, 1 } do
					for _, z in { -1, 1 } do table.insert(list, box.home * Vector3.new(x * box.W * 0.5, y * box.fullH, z * box.D * 0.5)) end
				end
			end
			return list
		end
		for _, c in { { single('Street', 1) }, { single('Galaxy', 5) }, { multi('Graffiti', { 1, 4, 2 }, 2) }, { multi('Galaxy', { 1, 2, 1, 3, 1, 1, 4, 2 }, 7) } } do
			local job = Cine.play(c[1], { manual = true })
			e.falsy(job.Failed)
			local P = job.Plan
			-- (the camera is held as it was)
			e.truthy(job.camBase == cam.CFrame or (job.camBase.Position - cam.CFrame.Position).Magnitude < 1e-4)
			local depth = -job.view.cf:PointToObjectSpace(job.O.Position).Z
			e.truthy(depth > 2 and depth <= 6.5 + 1e-6)
			for i, box in job.boxes do
				local x0, x1, y0, y1 = World.project(job.view, boxPts(box))
				e.truthy(x0 > -1 and x1 < 1 and y0 > -1 and y1 < 1)
				if P.n == 1 then
					-- (the box with its lid and topper 28-40 % of the height, its middle 47 % down, centred +-3 %)
					e.truthy((y1 - y0) / 2 >= 0.28 and (y1 - y0) / 2 <= 0.4)
					e.near((x0 + x1) / 2, 0, 0.06)
					e.near((y0 + y1) / 2, 1 - 2 * 0.47, 0.06)
				else
					e.truthy((y1 - y0) / 2 >= 0.12)
				end
				-- (its pair takes its place)
				local slot = job:wp(job.slots[i])
				e.truthy((slot - (box.home * CFrame.new(0, box.fullH * 0.5, 0)).Position).Magnitude < 1e-3)
			end
			job:finish()
		end
	end)

	t.test('a tap: to the reveal, then to the end (an egg and a Secret chain)', function()
		local gui = Instance.new('ScreenGui')
		local job = Cine.play(single('Street', 2), { manual = true, gui = gui })
		job:step(0.5)
		job:skip()
		job:step(1 / 30)
		e.truthy(job.T >= job.Plan.accent[1] - 1e-6)
		job:skip()
		job:step(1 / 30)
		e.truthy(job.T >= job.Plan.out - 1e-6)
		-- (in the world the tap closes it: the pair is in the button within 0.3 s)
		for _ = 1, 10 do job:step(1 / 30) end
		e.truthy(job.Done)
		job:finish()
		local chain = Cine.play(single('Street', 6), { manual = true, gui = gui })
		chain:step(0.6)
		chain:skip()
		chain:step(1 / 30)
		chain:step(1 / 30)
		e.equal(chain.seg.kind, 'crazy')
		e.truthy(chain.job.T >= chain.seg.plan.accent[1] - 1e-6)
		chain:finish()
		e.truthy(chain.Done)
		e.falsy(Cine.active())
		gui:Destroy()
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
			{ single('Street', 1) }, { single('Galaxy', 4) }, { single('Grail', 6) }, { multi('Graffiti', { 1, 4, 2 }, 2) },
			{ multi('Exclusive', { 2, 2, 3, 2, 6, 2, 3, 2 }, 5) }, { multi('Street', { 1, 2 }, 2), 'gift' }, { single('Gold', 5) },
			{ single('Exclusive', 3) }, { single('Street', 6), nil, true },
		}
		local gui = Instance.new('ScreenGui')
		for k = 1, 50 do
			local c = cases[(k - 1) % #cases + 1]
			local tap = (k % 3 == 0) and 1.0 or nil
			local job = run(c[1], { manual = true, tier = c[2], gui = gui, reduced = c[3] }, 0.1, tap)
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
