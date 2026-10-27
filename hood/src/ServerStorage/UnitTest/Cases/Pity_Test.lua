-- Brief 30, PITY: the VISIBLE pity counters (Shared/PityRules). Every open of a shoe box that is not Epic or better counts
-- up that box's counter; the 10th (Cash boxes) or 8th (Robux boxes) open since the last Epic+ is GUARANTEED Epic+, rolled
-- among the box's Epic+ entries by their own relative weights, then the counter resets; Epic+ by luck resets it too.
-- A multi-open counts its boxes in order. The wheel's best prize has the same kind of counter (15 spins). All of it is
-- server-side (ShoeOpening, HudExtras), saved in the profile (missing = 0), and the shown odds never change.
return function(t)
	local RS = game:GetService('ReplicatedStorage')
	local Shoes = require(RS.Shared.Config.Shoes)
	local R = require(RS.Shared.ShoeRules)
	local Pity = require(RS.Shared.PityRules)
	local X = require(RS.Shared.HudExtrasRules)
	local HS = game.ServerScriptService.HoodServer
	local S = require(HS.ProfileSchema)
	local Opening = require(HS.ShoeOpening)
	local HX = require(HS.HudExtras)
	local T0 = 1700000000
	local EPIC = Shoes.RarityById.Epic.Rank

	local function fakePlayer()
		local attrs = {}
		local p = { DisplayName = 'Tester', Name = 'Tester', UserId = 4242, Parent = nil, Attrs = attrs }
		function p:GetAttribute(k) return attrs[k] end
		function p:SetAttribute(k, v) attrs[k] = v end
		return p
	end
	local function profile() return { Data = S.new() } end
	local function rank(id) return Shoes.ById[id].Rank end
	-- n opens of one box, one at a time, all with roll r (r = 0.1 is a Common in a Cash box, a Rare in a Robux box)
	local function openEach(p, prof, box, n, r)
		local last
		for _ = 1, n do
			local _, info = Opening.open(p, prof, box, r)
			last = info
		end
		return last
	end

	t.test('config: one table, 10 opens for the Cash boxes, 8 for the Robux boxes, Epic and up; the wheel 15', function()
		t.expect.equal(Pity.Boxes.Cash, 10)
		t.expect.equal(Pity.Boxes.Robux, 8)
		t.expect.equal(Pity.minRank(), EPIC)
		t.expect.equal(Pity.rarityName(), 'Epic')
		for _, box in Shoes.Boxes do
			t.expect.equal(Pity.boxEvery(box.Id), box.Robux and 8 or 10)
			-- every box has an Epic+ entry to be guaranteed
			local reach = false
			for _, id in box.Shoes do
				if rank(id) >= EPIC then reach = true end
			end
			t.expect.truthy(reach)
		end
		t.expect.equal(Pity.boxEvery('Nope'), nil)
		t.expect.equal(Pity.boxEvery(7), nil)
		t.expect.equal(Pity.Wheel.Every, 15)
		for _, id in Pity.Wheel.Wedges do
			local found = false
			for _, w in X.Wedges do
				if w.Id == id then found = true end
			end
			t.expect.truthy(found)
		end
		-- the lines the panels print
		t.expect.equal(Pity.boxLine(7), 'Epic+ guaranteed in 7 opens')
		t.expect.equal(Pity.boxLine(10), 'Epic+ guaranteed in 10 opens')
		t.expect.equal(Pity.boxLine(1), 'Epic+ guaranteed on your next open!')
		t.expect.equal(Pity.boxLine(0), 'Epic+ guaranteed on your next open!')
		t.expect.equal(Pity.wheelLine(15), 'Big prize guaranteed in 15 spins')
		t.expect.equal(Pity.wheelLine(1), 'Big prize guaranteed on your next spin!')
	end)

	t.test('remaining(counters, boxId): the call a UI makes, from the profile table, the boxes map or the attribute', function()
		local p, prof = fakePlayer(), profile()
		t.expect.equal(Pity.remaining(nil, 'Street'), 10)
		t.expect.equal(Pity.remaining(prof.Data.Pity, 'Exclusive'), 8)
		openEach(p, prof, 'Street', 3, 0.1)
		t.expect.equal(Pity.remaining(prof.Data.Pity, 'Street'), 7) -- (the profile's own Pity table)
		t.expect.equal(Pity.remaining(prof.Data.Pity.Boxes, 'Street'), 7) -- (the boxes map alone)
		t.expect.equal(Pity.remaining(p.Attrs.ShoePity, 'Street'), 7) -- (the ShoePity attribute the client holds)
		t.expect.equal(Pity.remaining({ Street = 9 }, 'Street'), 1)
		t.expect.equal(Pity.remaining('Street:9', 'Street'), 1)
		t.expect.equal(Pity.remaining(prof.Data.Pity, 'Graffiti'), 10)
		t.expect.equal(Pity.remaining(prof.Data.Pity, 'Nope'), 0)
		t.expect.equal(Pity.remaining(12, 'Street'), 10) -- (junk counts as nothing counted)
		t.expect.equal(Pity.boxLine(Pity.remaining(prof.Data.Pity, 'Street')), 'Epic+ guaranteed in 7 opens')
	end)

	t.test('PityUI: the labels, the board tab and the GUARANTEED! tag are painted from the server\'s counter', function()
		local PityUI = require(RS.Shared.PityUI)
		local p = fakePlayer()
		-- (the attribute's change signal: the board tab follows the counter while it is up)
		local fire
		function p:GetAttributeChangedSignal() return { Connect = function(_, fn) fire = fn return { Disconnect = function() fire = nil end } end } end
		local label = { Text = '', TextColor3 = nil }
		PityUI.paint(label, 'Street', p)
		t.expect.equal(label.Text, 'Epic+ guaranteed in 10 opens')
		p:SetAttribute('ShoePity', 'Street:3,Exclusive:7')
		PityUI.paint(label, 'Street', p)
		t.expect.equal(label.Text, 'Epic+ guaranteed in 7 opens')
		t.expect.truthy(label.TextColor3 == PityUI.CountText)
		PityUI.paint(label, 'Exclusive', p)
		t.expect.equal(label.Text, 'Epic+ guaranteed on your next open!')
		t.expect.truthy(label.TextColor3 == PityUI.NextText)
		PityUI.paint(nil, 'Street', p) -- (no label: nothing happens)
		-- the payload's guaranteed opens
		t.expect.equal(PityUI.guaranteedCount({ Guaranteed = true }), 1)
		t.expect.equal(PityUI.guaranteedCount({ Guaranteed = true, Shoes = { { Guaranteed = false }, { Guaranteed = true }, { Guaranteed = true } } }), 2)
		t.expect.equal(PityUI.guaranteedCount({ Guaranteed = false, Shoes = { { Guaranteed = false } } }), 0)
		t.expect.equal(PityUI.guaranteedCount({}), 0)
		t.expect.equal(PityUI.guaranteedCount(nil), 0)
		-- no guarantee: no tag
		t.expect.equal(PityUI.revealTag({ Shoes = { { Guaranteed = false } } }, Instance.new('Frame'), { from = 0, to = 3, now = function() return 0 end }), nil)
		-- the key panel's line goes under the price and the cards make room for it
		local panel = Instance.new('Frame')
		panel.Size = UDim2.fromOffset(470, 270)
		local price = Instance.new('TextLabel')
		price.Name = 'Price'
		price.Position = UDim2.fromOffset(0, 46)
		price.Size = UDim2.fromOffset(470, 34)
		price.Parent = panel
		local card = Instance.new('TextButton')
		card.Name = 'CardE'
		card.Position = UDim2.fromOffset(8, 88)
		card.Parent = panel
		local line = PityUI.keyLine(panel)
		t.expect.equal(line.Name, 'PityLine')
		t.expect.equal(line.Position.Y.Offset, 80)
		t.expect.equal(card.Position.Y.Offset, 114)
		t.expect.equal(panel.Size.Y.Offset, 296)
		-- the odds board's tab: the gui grows by the tab, the board keeps its place
		local gui = Instance.new('BillboardGui')
		gui.Size = UDim2.fromScale(13, 5)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
		local board = Instance.new('Frame')
		board.Size = UDim2.fromScale(1, 1)
		board.Parent = gui
		local tabLabel = PityUI.boardTab(gui, board, 'Street', p)
		t.expect.equal(tabLabel.Text, 'Epic+ guaranteed in 7 opens')
		t.expect.near(gui.Size.Y.Scale, 5 + PityUI.TabHeight, 1e-4)
		t.expect.near(gui.StudsOffsetWorldSpace.Y, 7 - PityUI.TabHeight / 2, 1e-4)
		t.expect.near(board.Size.Y.Scale * gui.Size.Y.Scale, 5, 1e-4)
		-- it follows the counter live (an open while the board is up)
		p:SetAttribute('ShoePity', 'Street:9,Exclusive:7')
		t.expect.truthy(fire ~= nil)
		fire()
		t.expect.equal(tabLabel.Text, 'Epic+ guaranteed on your next open!')
	end)

	t.test('the counter counts every open below Epic, per box, and Epic+ by luck resets it', function()
		local p, prof = fakePlayer(), profile()
		t.expect.equal(Pity.left(prof.Data.Pity, 'Street'), 10)
		openEach(p, prof, 'Street', 3, 0.1) -- (Commons)
		t.expect.equal(Pity.count(prof.Data.Pity, 'Street'), 3)
		t.expect.equal(Pity.left(prof.Data.Pity, 'Street'), 7)
		t.expect.equal(p.Attrs.ShoePity, 'Street:3')
		-- a Rare (r = 0.8) is still no result
		openEach(p, prof, 'Street', 1, 0.8)
		t.expect.equal(Pity.count(prof.Data.Pity, 'Street'), 4)
		-- another box has its own counter
		openEach(p, prof, 'Graffiti', 2, 0.1)
		t.expect.equal(Pity.count(prof.Data.Pity, 'Graffiti'), 2)
		t.expect.equal(Pity.count(prof.Data.Pity, 'Street'), 4)
		t.expect.equal(p.Attrs.ShoePity, 'Street:4,Graffiti:2')
		-- a natural Epic (r = 0.9) resets only its own box, and is no guarantee
		local info = openEach(p, prof, 'Street', 1, 0.9)
		t.expect.equal(info.Rarity, 'Epic')
		t.expect.equal(info.Guaranteed, false)
		t.expect.equal(Pity.count(prof.Data.Pity, 'Street'), 0)
		t.expect.equal(prof.Data.Pity.Boxes.Street, nil) -- (a counter at 0 is not stored)
		t.expect.equal(Pity.count(prof.Data.Pity, 'Graffiti'), 2)
		t.expect.equal(p.Attrs.ShoePity, 'Graffiti:2')
		t.expect.truthy(S.validate(prof.Data))
	end)

	t.test('the 10th open of a Cash box is guaranteed Epic or better, whatever the roll, then it resets', function()
		local p, prof = fakePlayer(), profile()
		for i = 1, 9 do
			local info = openEach(p, prof, 'Street', 1, 0.1)
			t.expect.equal(info.Rarity, 'Common')
			t.expect.equal(info.Guaranteed, false)
			t.expect.equal(Pity.left(prof.Data.Pity, 'Street'), 10 - i)
		end
		t.expect.equal(Pity.due(prof.Data.Pity, 'Street'), true)
		local info = openEach(p, prof, 'Street', 1, 0.1) -- (the same roll that gave Commons nine times)
		t.expect.truthy(rank(info.Shoe) >= EPIC)
		t.expect.equal(info.Guaranteed, true)
		t.expect.equal(info.Shoes[1].Guaranteed, true)
		t.expect.equal(Pity.count(prof.Data.Pity, 'Street'), 0)
		t.expect.equal(Pity.due(prof.Data.Pity, 'Street'), false)
		t.expect.equal(p.Attrs.ShoePity, '')
		-- and the next one is an ordinary open again
		info = openEach(p, prof, 'Street', 1, 0.1)
		t.expect.equal(info.Rarity, 'Common')
		t.expect.equal(info.Guaranteed, false)
		t.expect.equal(Pity.count(prof.Data.Pity, 'Street'), 1)
		-- every possible roll on a due open lands on Epic or better (and a Lucky owner too)
		for _, lucky in { false, true } do
			local q = fakePlayer()
			q:SetAttribute('Pass_Lucky', lucky)
			local qp = profile()
			for i = 0, 100 do
				qp.Data.Pity = { Boxes = { Street = 9 }, Wheel = 0 }
				local _, got = Opening.open(q, qp, 'Street', math.min(i / 100, 0.999999))
				t.expect.truthy(rank(got.Shoe) >= EPIC)
				t.expect.equal(got.Guaranteed, true)
			end
		end
		t.expect.truthy(S.validate(prof.Data))
	end)

	t.test('the Robux boxes guarantee on the 8th open', function()
		for _, box in { 'Exclusive', 'Grail' } do
			local p, prof = fakePlayer(), profile()
			for i = 1, 7 do
				local info = openEach(p, prof, box, 1, 0.1) -- (a Rare in a Robux box)
				t.expect.equal(info.Rarity, 'Rare')
				t.expect.equal(info.Guaranteed, false)
				t.expect.equal(Pity.left(prof.Data.Pity, box), 8 - i)
			end
			local info = openEach(p, prof, box, 1, 0.1)
			t.expect.truthy(rank(info.Shoe) >= EPIC)
			t.expect.equal(info.Guaranteed, true)
			t.expect.equal(Pity.count(prof.Data.Pity, box), 0)
		end
	end)

	t.test('a guaranteed open rolls by the box\'s own relative weights, so the shown odds stay true', function()
		for _, box in Shoes.Boxes do
			-- the weights of the Epic+ entries and their total
			local want, total = {}, 0
			for i, id in box.Shoes do
				if rank(id) >= EPIC then
					want[id] = box.Weights[i]
					total += box.Weights[i]
				end
			end
			local got, N = {}, 20000
			for i = 0, N - 1 do
				local id = R.roll(box.Id, i / N, false, EPIC)
				got[id] = (got[id] or 0) + 1
			end
			for id, w in want do
				t.expect.near((got[id] or 0) / N, w / total, 0.001)
			end
			for id in got do t.expect.truthy(want[id] ~= nil) end
			-- the chances of a guaranteed open add up to 100 and are Epic+ only; a Lucky owner's relative split is the same
			local sum = 0
			local plain, lucky = R.chances(box.Id, false, EPIC), R.chances(box.Id, true, EPIC)
			for i, c in plain do
				sum += c.Chance
				if rank(c.Id) < EPIC then t.expect.equal(c.Chance, 0) end
				if not box.Robux then t.expect.near(c.Chance, lucky[i].Chance, 1e-9) end
			end
			t.expect.near(sum, 100, 1e-9)
		end
		-- the shown odds (no minRank) are the box's odds, to the letter
		local street = R.chances('Street')
		t.expect.near(street[1].Chance, 62, 1e-9)
		t.expect.near(street[3].Chance, 9.5, 1e-9)
		t.expect.near(street[6].Chance, 0.05, 1e-9)
		local ex = R.chances('Exclusive')
		t.expect.near(ex[1].Chance, 60, 1e-9)
		t.expect.near(ex[2].Chance, 28, 1e-9)
		-- an unreachable rank changes nothing; no rank is the plain roll
		for _, r in { 0, 0.3, 0.7, 0.99 } do
			t.expect.equal(R.roll('Street', r, false, 99), R.roll('Street', r))
			t.expect.equal(R.roll('Street', r, false, nil), R.roll('Street', r))
		end
		-- the guaranteed split in numbers: Street's Epic 950, Legendary 300, Mythic 45, Secret 5 of 1300
		t.expect.equal(R.roll('Street', 0.5, false, EPIC), 'Checkmate') -- (r * 1300 = 650: inside Epic's 950)
		t.expect.equal(R.roll('Street', 0.9, false, EPIC), 'ChromeKicks') -- (1170: past Epic, inside Legendary's 300)
		t.expect.equal(R.roll('Street', 0.97, false, EPIC), 'StreetAngel') -- (1261: Mythic's 45)
		t.expect.equal(R.roll('Street', 0.9999, false, EPIC), 'BlockRoyalty') -- (Secret's 5)
	end)

	t.test('a x3 or x8 counts its boxes in order: the guaranteed one is the one the counter says', function()
		local p, prof = fakePlayer(), profile()
		prof.Data.Pity = { Boxes = { Street = 8 }, Wheel = 0 }
		-- 8 misses: open 1 is the 9th miss, open 2 is due, open 3 starts a new count
		local ids, info = Opening.openMany(p, prof, 'Street', 3, { Rolls = { 0.1, 0.1, 0.1 } })
		t.expect.equal(rank(ids[1]), 1)
		t.expect.truthy(rank(ids[2]) >= EPIC)
		t.expect.equal(rank(ids[3]), 1)
		t.expect.equal(info.Shoes[1].Guaranteed, false)
		t.expect.equal(info.Shoes[2].Guaranteed, true)
		t.expect.equal(info.Shoes[3].Guaranteed, false)
		t.expect.equal(info.Best, 2)
		t.expect.equal(info.Guaranteed, true) -- (the top-level fields describe the best pair, the guaranteed one)
		t.expect.equal(Pity.count(prof.Data.Pity, 'Street'), 1)
		t.expect.equal(p.Attrs.ShoePity, 'Street:1')
		-- the first of a batch can be the guaranteed one
		prof.Data.Pity = { Boxes = { Street = 9 }, Wheel = 0 }
		_, info = Opening.openMany(p, prof, 'Street', 3, { Rolls = { 0.1, 0.1, 0.1 } })
		t.expect.equal(info.Shoes[1].Guaranteed, true)
		t.expect.equal(info.Shoes[2].Guaranteed, false)
		t.expect.equal(info.Shoes[3].Guaranteed, false)
		t.expect.equal(Pity.count(prof.Data.Pity, 'Street'), 2)
		-- a Buy 8 of a Robux box from a fresh count: 7 Rares, then the 8th is the guarantee
		local q, qp = fakePlayer(), profile()
		_, info = Opening.openMany(q, qp, 'Exclusive', 8, { Rolls = { 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1 } })
		for i = 1, 7 do t.expect.equal(info.Shoes[i].Guaranteed, false) end
		t.expect.equal(info.Shoes[8].Guaranteed, true)
		t.expect.equal(info.Best, 8)
		t.expect.equal(Pity.count(qp.Data.Pity, 'Exclusive'), 0)
		-- a natural Epic+ in the middle of a batch resets it: no guarantee follows
		local r, rp = fakePlayer(), profile()
		rp.Data.Pity = { Boxes = { Street = 7 }, Wheel = 0 }
		_, info = Opening.openMany(r, rp, 'Street', 4, { Rolls = { 0.1, 0.9, 0.1, 0.1 } })
		for i = 1, 4 do t.expect.equal(info.Shoes[i].Guaranteed, false) end
		t.expect.equal(Pity.count(rp.Data.Pity, 'Street'), 2)
		-- batches add up with single opens: 9 singles then a x3 = guaranteed first
		local u, up = fakePlayer(), profile()
		openEach(u, up, 'Graffiti', 9, 0.1)
		_, info = Opening.openMany(u, up, 'Graffiti', 3, { Rolls = { 0.1, 0.1, 0.1 } })
		t.expect.equal(info.Shoes[1].Guaranteed, true)
		t.expect.equal(Pity.count(up.Data.Pity, 'Graffiti'), 2)
		t.expect.truthy(S.validate(up.Data))
	end)

	t.test('only the server decides: nothing the caller passes moves the counter or the roll', function()
		local p, prof = fakePlayer(), profile()
		local ids, info = Opening.openMany(p, prof, 'Street', 1, { Rolls = { 0.1 }, Guaranteed = true, MinRank = 6, Pity = { Boxes = { Street = 9 } } })
		t.expect.equal(rank(ids[1]), 1)
		t.expect.equal(info.Guaranteed, false)
		t.expect.equal(Pity.count(prof.Data.Pity, 'Street'), 1)
		-- a damaged counter in the profile never breaks an open: it is cleaned first
		prof.Data.Pity = { Boxes = { Street = 'many', Nope = 4, Graffiti = 1e9 }, Wheel = 'x' }
		_, info = Opening.openMany(p, prof, 'Graffiti', 1, { Rolls = { 0.1 } })
		t.expect.equal(info.Guaranteed, true) -- (a huge count means due)
		t.expect.equal(prof.Data.Pity.Boxes.Nope, nil)
		t.expect.truthy(S.validate(prof.Data))
		-- the Cash remote takes (boxId, count) and nothing else: ShoeService reads no pity argument
		local src = game.ServerScriptService.HoodServer.ShoeService.Source
		t.expect.truthy(string.find(src, 'OnServerEvent:Connect(function(player, boxId, count)', 1, true) ~= nil)
	end)

	t.test('streaks: no box ever goes past its threshold without an Epic or better', function()
		local rng = Random.new(11)
		for _, box in { 'Street', 'Graffiti', 'Exclusive', 'Grail' } do
			local p, prof = fakePlayer(), profile()
			local every = Pity.boxEvery(box)
			local streak, worst, forced, natural = 0, 0, 0, 0
			for _ = 1, 1500 do
				local _, info = Opening.open(p, prof, box, rng:NextNumber())
				if rank(info.Shoe) >= EPIC then
					streak = 0
					if info.Guaranteed then forced += 1 else natural += 1 end
				else
					streak += 1
					worst = math.max(worst, streak)
				end
				-- (a pair that is no result never comes out of a due open)
				if info.Guaranteed then t.expect.truthy(rank(info.Shoe) >= EPIC) end
			end
			t.expect.truthy(worst <= every - 1)
			t.expect.truthy(forced > 0)
			t.expect.truthy(natural > 0)
			-- the natural rate is still the box's: Street gives Epic+ 13 % of its opens, so most Epic+ come by luck
			if box == 'Street' then t.expect.truthy(natural > forced) end
		end
	end)

	t.test('saves: a profile from before the counters gets 0 everywhere; damaged ones are cleaned; counters survive a save', function()
		-- from before: no Pity at all
		local old = { Rep = 123, Cash = 456, Evolution = { Block = 3 }, Shoes = { Owned = { FreshCanvas = 2 }, Equipped = { 'FreshCanvas' }, Opened = 9 } }
		S.migrate(old)
		t.expect.deepEqual(old.Pity, { Boxes = {}, Wheel = 0 })
		t.expect.equal(old.Shoes.Opened, 9)
		t.expect.equal(Pity.left(old.Pity, 'Street'), 10)
		t.expect.truthy(S.validate(old))
		-- the template and the public snapshot
		t.expect.deepEqual(S.new().Pity, { Boxes = {}, Wheel = 0 })
		t.expect.equal(S.public(S.new()).Pity, nil)
		-- junk
		local junk = S.new()
		junk.Pity = 'lots'
		S.migrate(junk)
		t.expect.deepEqual(junk.Pity, { Boxes = {}, Wheel = 0 })
		local dmg = S.new()
		dmg.Pity = { Boxes = { Street = 3, Nope = 5, Graffiti = -2, Gold = 1e9, Grail = 'x', Exclusive = 2.7, Frost = 0 / 0, Lava = math.huge }, Wheel = 99 }
		S.migrate(dmg)
		t.expect.equal(dmg.Pity.Boxes.Street, 3)
		t.expect.equal(dmg.Pity.Boxes.Nope, nil)
		t.expect.equal(dmg.Pity.Boxes.Graffiti, nil)
		t.expect.equal(dmg.Pity.Boxes.Gold, 9) -- (clamped to Every - 1: it is due)
		t.expect.equal(dmg.Pity.Boxes.Grail, nil)
		t.expect.equal(dmg.Pity.Boxes.Exclusive, 2)
		t.expect.equal(dmg.Pity.Boxes.Frost, nil)
		t.expect.equal(dmg.Pity.Boxes.Lava, nil)
		t.expect.equal(dmg.Pity.Wheel, 14)
		t.expect.truthy(S.validate(dmg))
		-- a counter survives a save and a rejoin: the attribute is rebuilt from the profile
		local p, prof = fakePlayer(), profile()
		openEach(p, prof, 'Street', 4, 0.1)
		openEach(p, prof, 'Exclusive', 2, 0.1)
		local saved = S.migrate(table.clone(prof.Data))
		local q = fakePlayer()
		Opening.sync(q, { Data = saved })
		t.expect.equal(q.Attrs.ShoePity, 'Street:4,Exclusive:2')
		t.expect.equal(Pity.count(saved.Pity, 'Street'), 4)
		t.expect.truthy(S.validate(saved))
		-- encode / decode
		local back = Pity.decode(q.Attrs.ShoePity)
		t.expect.equal(back.Boxes.Street, 4)
		t.expect.equal(back.Boxes.Exclusive, 2)
		t.expect.deepEqual(Pity.decode(nil), { Boxes = {}, Wheel = 0 })
		t.expect.deepEqual(Pity.decode('junk,Nope:3,Street:x'), { Boxes = {}, Wheel = 0 })
	end)

	---------------------------------------------------------------------------------------------- the wheel
	local function spinner()
		local prof = { Data = { Rebirths = 0, Rep = 0, Cash = 0, ClearedWalls = {}, Passes = {} } }
		HX.tables(prof.Data)
		prof.Data.Spin.Extra = 60
		return prof
	end
	local function wedgeIndex(id)
		for i, w in X.Wedges do
			if w.Id == id then return i end
		end
		return nil
	end

	t.test('the wheel: a limited roll picks among the big prizes by weight; no limit is the normal roll', function()
		local jackpot = wedgeIndex('Jackpot')
		for i = 0, 100 do
			t.expect.equal(X.pick(math.min(i / 100, 0.999999), { 'Jackpot' }), jackpot)
		end
		-- two wedges split by their own weights (Cash1 24, Cash2 12)
		local c1, c2 = wedgeIndex('Cash1'), wedgeIndex('Cash2')
		t.expect.equal(X.pick(0.1, { 'Cash1', 'Cash2' }), c1)
		t.expect.equal(X.pick(0.65, { 'Cash1', 'Cash2' }), c1)
		t.expect.equal(X.pick(0.7, { 'Cash1', 'Cash2' }), c2)
		t.expect.equal(X.pick(0.999, { 'Cash1', 'Cash2' }), c2)
		-- ids that match nothing change nothing; the normal roll is untouched
		for _, r in { 0, 0.2, 0.5, 0.9, 0.999 } do
			t.expect.equal(X.pick(r, { 'Nope' }), X.pick(r))
			t.expect.equal(X.pick(r, nil), X.pick(r))
		end
		t.expect.equal(X.pick(0.9999), #X.Wedges)
	end)

	t.test('the wheel: the 15th spin since the big prize is guaranteed, then it resets; a lucky big prize resets it too', function()
		local prof = spinner()
		local jackpot = wedgeIndex('Jackpot')
		-- 14 ordinary spins (r = 0 is the first wedge)
		for i = 1, 14 do
			local ok, wedge, _, guaranteed = HX.spin(prof, 0, T0)
			t.expect.equal(ok, true)
			t.expect.equal(wedge, 1)
			t.expect.equal(guaranteed, false)
			t.expect.equal(Pity.wheelLeft(prof.Data.Pity), 15 - i)
		end
		t.expect.equal(Pity.wheelDue(prof.Data.Pity), true)
		local extraBefore = prof.Data.Spin.Extra
		local ok, wedge, reward, guaranteed = HX.spin(prof, 0, T0) -- (the same roll)
		t.expect.equal(ok, true)
		t.expect.equal(wedge, jackpot)
		t.expect.equal(guaranteed, true)
		t.expect.truthy(reward.Cash and reward.Cash > 0)
		t.expect.equal(reward.Spins, 1)
		t.expect.equal(prof.Data.Spin.Extra, extraBefore - 1 + 1) -- (a spin spent, the Jackpot's free one given)
		t.expect.equal(Pity.wheelCount(prof.Data.Pity), 0)
		t.expect.equal(Pity.wheelLeft(prof.Data.Pity), 15)
		-- the next is ordinary again
		local _, w2, _, g2 = HX.spin(prof, 0, T0)
		t.expect.equal(w2, 1)
		t.expect.equal(g2, false)
		t.expect.equal(Pity.wheelCount(prof.Data.Pity), 1)
		-- a lucky Jackpot (r near 1) resets the counter and is no guarantee
		for _ = 1, 5 do HX.spin(prof, 0, T0) end
		t.expect.equal(Pity.wheelCount(prof.Data.Pity), 6)
		local _, w3, _, g3 = HX.spin(prof, 0.999, T0)
		t.expect.equal(w3, jackpot)
		t.expect.equal(g3, false)
		t.expect.equal(Pity.wheelCount(prof.Data.Pity), 0)
		t.expect.truthy(S.validate((function() local d = S.new(); d.Pity = prof.Data.Pity; return d end)()))
	end)

	t.test('the wheel: a refused spin does not move the counter; the shown odds are the wheel\'s weights', function()
		local prof = spinner()
		for _ = 1, 3 do HX.spin(prof, 0, T0) end
		t.expect.equal(Pity.wheelCount(prof.Data.Pity), 3)
		-- no spins left
		local none = spinner()
		none.Data.Spin.Extra = 0
		none.Data.Spin.NextFree = T0 + 3600
		local ok, why = HX.spin(none, 0, T0)
		t.expect.equal(ok, false)
		t.expect.equal(why, 'none')
		t.expect.equal(Pity.wheelCount(none.Data.Pity), 0)
		-- a box still waiting to open
		prof.Data.Spin.PendingBox = 'Graffiti'
		ok, why = HX.spin(prof, 0, T0)
		t.expect.equal(ok, false)
		t.expect.equal(why, 'busy')
		t.expect.equal(Pity.wheelCount(prof.Data.Pity), 3)
		-- the chances the window prints are untouched (Jackpot 3 %)
		t.expect.equal(X.chanceText(wedgeIndex('Jackpot')), '3%')
		t.expect.equal(X.WedgeTotal, 100)
	end)
end
