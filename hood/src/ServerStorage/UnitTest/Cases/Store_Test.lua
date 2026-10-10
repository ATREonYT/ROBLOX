-- The brief 22 Store products (Config/Products, HoodServer/StoreReceipts, HoodServer/ShoeOpening, HoodServer/Boosts):
-- shoe-box bundles roll N pairs in one grant and one reveal, timed boosts queue without losing time, the Boost Bundle
-- grants its parts, the cash packs are priced honestly, and every receipt is granted once, even across a leave and a
-- rejoin. And the three game passes (+1 Shoe Slot, Lucky, Triple Open).
return function(t)
	local RS = game:GetService('ReplicatedStorage')
	local Products = require(RS.Shared.Config.Products)
	local Shoes = require(RS.Shared.Config.Shoes)
	local Guns = require(RS.Shared.Config.Guns)
	local Balance = require(RS.Shared.Config.Balance)
	local R = require(RS.Shared.ShoeRules)
	local UIKit = require(RS.Shared.UIKit)
	local HS = game.ServerScriptService.HoodServer
	local S = require(HS.ProfileSchema)
	local Boosts = require(HS.Boosts)
	local Opening = require(HS.ShoeOpening)
	local Receipts = require(HS.StoreReceipts)
	local DEC = Enum.ProductPurchaseDecision

	-- a stand-in player (attributes only; not in Players, so no remotes fire)
	local function fakePlayer()
		local attrs = {}
		local p = { DisplayName = 'Tester', Name = 'Tester', UserId = 4242, Parent = nil, Attrs = attrs }
		function p:GetAttribute(k) return attrs[k] end
		function p:SetAttribute(k, v) attrs[k] = v end
		return p
	end
	-- a ProfileStore-like profile: Save copies Data into LastSavedData and fires OnAfterSave
	local function deep(x)
		if type(x) ~= 'table' then return x end
		local c = {}
		for k, v in x do c[k] = deep(v) end
		return c
	end
	local function newProfile(data)
		local after = {}
		local prof = { Data = data or S.new(), LastSavedData = nil, Active = true, Saves = 0 }
		prof.OnAfterSave = { Connect = function(_, fn)
			table.insert(after, fn)
			return { Disconnect = function() local i = table.find(after, fn); if i then table.remove(after, i) end end }
		end }
		function prof:Save()
			self.Saves += 1
			self.LastSavedData = deep(self.Data)
			for _, fn in table.clone(after) do fn(self.LastSavedData) end
		end
		function prof:IsActive() return self.Active end
		return prof
	end
	-- runs fn with product ids set (as if the owner pasted them in), and always puts the zeros back
	local function withIds(fn)
		local saved = table.clone(Products.DeveloperProducts)
		local n = 0
		for key in Products.DeveloperProducts do
			n += 1
			Products.DeveloperProducts[key] = 900000 + n
		end
		local ok, err = pcall(fn)
		for key, v in saved do Products.DeveloperProducts[key] = v end
		if not ok then error(err, 0) end
	end

	---------------------------------------------------------------------------------------------- catalog
	t.test('the Store sections are in the reference order with their titles, and nothing claims limited stock', function()
		local ids, titles = {}, {}
		for _, s in Products.Sections do
			table.insert(ids, s.Id)
			table.insert(titles, s.Title)
		end
		t.expect.equal(table.concat(ids, ','), 'Box,Gamepass,Boost,Cash,Power')
		t.expect.equal(table.concat(titles, ','), '~Shoe Boxes~,~Gamepass~,~Boosts~,~Cash Packs~,~Power Packs~')
		local function honest(text)
			t.expect.truthy(type(text) ~= 'string' or not string.find(string.lower(text), 'limited', 1, true))
		end
		for _, s in Products.Sections do honest(s.Title) end
		for _, e in Products.Catalog do
			for _, field in { 'Title', 'Detail', 'Big', 'Offer', 'Sticker' } do honest(e[field]) end
			for _, line in e.Lines or {} do honest(line) end
		end
	end)

	t.test('the new products have id slots (0 until the owner makes them: Coming soon!) and are wired', function()
		for _, key in { 'ShoeBoxExclusive3', 'ShoeBoxExclusive8', 'ShoeBoxGrail3', 'ShoeBoxGrail8', 'TinyCash', 'BoostBundle', 'PowerPack4' } do
			local e = Products.ByKey[key]
			t.expect.truthy(e and e.Kind == 'Product' and e.Wired == true)
			t.expect.equal(Products.DeveloperProducts[key], 0)
			t.expect.equal(select(2, Products.canBuy(key)), 'noid')
			t.expect.truthy(UIKit.Tone[e.Tone] ~= nil)
		end
		-- every wired product has a grant, and only products do
		local grants = Receipts.grants({})
		for _, e in Products.Catalog do
			if e.Kind == 'Product' and e.Wired then t.expect.truthy(type(grants[e.Key]) == 'function') end
			if e.Kind == 'Pass' then t.expect.equal(grants[e.Key], nil) end
		end
	end)

	t.test('box bundles: Buy 1 / 3 / 8 per Robux box, honest WasPrice = Count x the single price', function()
		local want = { Exclusive = { [1] = 99, [3] = 249, [8] = 599 }, Grail = { [1] = 199, [3] = 499, [8] = 1199 } }
		local rows = {}
		for _, e in Products.Catalog do
			if e.Section == 'Box' then
				rows[e.Box] = rows[e.Box] or {}
				rows[e.Box][e.Count] = e
			end
		end
		for boxId, prices in want do
			local box = Shoes.BoxById[boxId]
			local single = rows[boxId][1]
			t.expect.equal(single.Key, box.Robux)
			t.expect.equal(single.Price, box.RobuxPrice)
			t.expect.equal(single.WasPrice, nil)
			for count, price in prices do
				local e = rows[boxId][count]
				t.expect.truthy(e ~= nil)
				t.expect.equal(e.Price, price)
				t.expect.equal(e.Title, single.Title)
				t.expect.equal(e.Tone, single.Tone)
				local b, n = Products.boxOpen(e.Key)
				t.expect.equal(b, boxId)
				t.expect.equal(n, count)
				if count > 1 then
					t.expect.equal(e.WasPrice, count * single.Price)
					t.expect.truthy(e.Price < e.WasPrice)
				end
			end
		end
		t.expect.equal(Products.boxOpen('TinyCash'), nil)
	end)

	t.test('the Boost Bundle: two 2x + one 3x, WasPrice = the sum of the parts, a lower price', function()
		local e = Products.ByKey.BoostBundle
		t.expect.equal(table.concat(Products.boostLevels('BoostBundle'), ','), '2,2,3')
		local sum = 0
		for _, part in e.Bundle do
			t.expect.truthy(Products.ByKey[part] and Products.ByKey[part].Section == 'Boost')
			sum += Products.ByKey[part].Price
		end
		t.expect.equal(e.WasPrice, sum)
		t.expect.truthy(e.Price < e.WasPrice)
		t.expect.truthy(e.Wide == true and #e.Lines == 2)
		t.expect.equal(table.concat(Products.boostLevels('RepBoost2x'), ','), '2')
		t.expect.equal(table.concat(Products.boostLevels('RepBoost3x'), ','), '3')
		t.expect.equal(#Products.boostLevels('TinyCash'), 0)
		t.expect.equal(Products.ByKey.RepBoost2x.Title, '2x Power')
		t.expect.equal(Products.ByKey.RepBoost3x.Title, '3x Power')
	end)

	t.test('cash packs: Tiny / Small / Medium / Large at 19 / 49 / 129 / 399, a little more Cash per Robux each size, no early-game skip', function()
		local keys = { 'TinyCash', 'SmallCash', 'MediumCash', 'LargeCash' }
		local prices = { 19, 49, 129, 399 }
		local last
		for i, key in keys do
			local e = Products.ByKey[key]
			t.expect.equal(e.Section, 'Cash')
			t.expect.equal(e.Price, prices[i])
			t.expect.equal(e.Order < (Products.ByKey[keys[i + 1]] or { Order = math.huge }).Order, true)
			local per = Products.cashAmount(key) / e.Price
			if last then
				t.expect.truthy(per > last) -- more for your Robux in a bigger pack...
				t.expect.truthy(per <= last * 1.2) -- ...but only a little
			end
			last = per
		end
		-- the Tiny pack is less than one cash-out at each of the first eight stages (their Return pads), and no pack buys
		-- the end-of-world guns
		local early = 0
		for s = 1, 8 do early += Balance.PadCash[s] end
		t.expect.truthy(Products.cashAmount('TinyCash') < early)
		t.expect.truthy(Products.cashAmount('LargeCash') < Guns.ById.Blaster.Cost)
		t.expect.truthy(Products.cashAmount('LargeCash') < Guns.ById.Diamond.Cost)
	end)

	t.test('power packs: four sizes, a little more Power per Robux each size', function()
		local last
		for i = 1, 4 do
			local e = Products.ByKey['PowerPack' .. i]
			t.expect.equal(e.Section, 'Power')
			local per = e.Pack / e.Price
			if last then t.expect.truthy(per > last and per <= last * 1.2) end
			last = per
			t.expect.truthy(Products.powerAmount(e.Key, 2000) >= 100)
		end
	end)

	---------------------------------------------------------------------------------------------- boosts
	t.test('timed boosts queue: the strongest runs first, a weaker one waits, no time is lost or merged', function()
		t.expect.equal(Boosts.running(nil, 1000), 1)
		t.expect.equal(select(2, Boosts.running(nil, 1000)), 0)
		t.expect.equal(Boosts.queueString(nil, 1000), '')
		-- x2 for 15 min at t=1000
		local b = Boosts.add(nil, 2, 900, 1000)
		t.expect.equal(Boosts.running(b, 1000), 2)
		t.expect.equal(select(2, Boosts.running(b, 1000)), 1900)
		-- 5 min later a x3: it runs now, the x2's 10 min left wait behind it
		b = Boosts.add(b, 3, 900, 1300)
		t.expect.equal(Boosts.queueString(b, 1300), '3:2200,2:2800')
		t.expect.equal(Boosts.total(b, 1300), 1500)
		t.expect.equal(Boosts.running(b, 2199), 3)
		t.expect.equal(Boosts.running(b, 2200), 2)
		t.expect.equal(select(2, Boosts.running(b, 2500)), 2800)
		-- a x2 bought while the x3 runs adds to the x2's turn, not to the x3
		local c = Boosts.add(b, 2, 900, 1400)
		t.expect.equal(Boosts.queueString(c, 1400), '3:2200,2:3700')
		t.expect.equal(Boosts.total(c, 1400), 1400 + 900)
		-- another x3 extends the x3 and pushes the x2 back
		local d = Boosts.add(b, 3, 900, 1400)
		t.expect.equal(Boosts.queueString(d, 1400), '3:3100,2:3700')
		-- the old table is never changed
		t.expect.equal(Boosts.queueString(b, 1300), '3:2200,2:2800')
		-- all over
		t.expect.equal(Boosts.running(d, 3700), 1)
		t.expect.equal(Boosts.queueString(d, 3700), '')
		-- a save from before brief 22 reads the same, and junk is dropped
		t.expect.equal(Boosts.running({ Level = 3, Until = 5000 }, 4000), 3)
		t.expect.equal(Boosts.queueString({ Level = 3, Until = 5000, Next = { 'x', { Level = 0 / 0, Until = 1 } } }, 4000), '3:5000')
		t.expect.equal(Boosts.running({ Level = 'x' }, 4000), 1)
		t.expect.equal(Boosts.running({ Level = 99, Until = 5000 }, 4000), Boosts.MaxLevel)
		t.expect.throws(function() Boosts.add(nil, 1, 900, 0) end)
		t.expect.throws(function() Boosts.add(nil, 2, -5, 0) end)
	end)

	t.test('the boost grants: one boost, the bundle (45 min, 3x first), stacking on a running boost', function()
		local now = 10000
		local published = 0
		local grants = Receipts.grants({ now = function() return now end, publish = function() published += 1 end })
		local p = fakePlayer()
		local prof = newProfile()
		grants.RepBoost2x(p, prof, 'RepBoost2x')
		t.expect.equal(Boosts.queueString(prof.Data.Passes.Boost, now), '2:10900')
		now = 10300 -- 10 min of x2 left; the bundle adds 3x 15 min and 2x 30 min
		grants.BoostBundle(p, prof, 'BoostBundle')
		t.expect.equal(Boosts.queueString(prof.Data.Passes.Boost, now), '3:11200,2:13600')
		t.expect.equal(Boosts.total(prof.Data.Passes.Boost, now), 600 + 2700)
		t.expect.equal(published, 2)
		t.expect.truthy(S.validate(prof.Data))
		-- a fresh profile: the bundle alone
		local fresh = newProfile()
		grants.BoostBundle(p, fresh, 'BoostBundle')
		t.expect.equal(Boosts.queueString(fresh.Data.Passes.Boost, now), '3:11200,2:13000')
	end)

	---------------------------------------------------------------------------------------------- shoe boxes
	t.test('openMany: N pairs in one go, one payload listing them all, the best one up top', function()
		local p = fakePlayer()
		local prof = newProfile()
		local ids, info = Opening.openMany(p, prof, 'Exclusive', 3, { Rolls = { 0.1, 0.9, 0.1 }, Product = 'ShoeBoxExclusive3' })
		t.expect.equal(table.concat(ids, ','), 'SilverStreak,RainbowDrip,SilverStreak')
		t.expect.equal(info.Buy, 3)
		t.expect.equal(#info.Shoes, 3)
		t.expect.equal(info.Best, 2)
		t.expect.equal(info.Shoe, 'RainbowDrip')
		t.expect.equal(info.Rarity, 'Legendary')
		t.expect.equal(info.Box, 'Exclusive')
		t.expect.equal(info.Product, 'ShoeBoxExclusive3')
		t.expect.equal(info.Shoes[1].New, true)
		t.expect.equal(info.Shoes[3].New, false) -- (the second Silver Streak of the batch isn't new)
		t.expect.equal(info.Shoes[3].Count, 2)
		t.expect.equal(info.Shoes[1].Equipped and info.Shoes[2].Equipped and info.Shoes[3].Equipped, true)
		t.expect.equal(prof.Data.Shoes.Opened, 3)
		t.expect.equal(prof.Data.Shoes.Owned.SilverStreak, 2)
		t.expect.equal(p.Attrs.ShoesOpened, 3)
		t.expect.equal(p.Attrs.ShoeWorn, 'RainbowDrip')
		-- a single open: the same fields as before, plus a one-entry list
		local id, one = Opening.open(p, prof, 'Grail', 0.1)
		t.expect.equal(id, 'GoldenHour')
		t.expect.equal(one.Buy, 1)
		t.expect.equal(#one.Shoes, 1)
		t.expect.equal(one.Best, 1)
		t.expect.equal(one.Shoes[1].Shoe, one.Shoe)
		t.expect.equal(one.Product, nil)
		-- bad counts change nothing
		local before = R.ownedString(prof.Data.Shoes)
		t.expect.throws(function() Opening.openMany(p, prof, 'Exclusive', 0) end)
		t.expect.throws(function() Opening.openMany(p, prof, 'Exclusive', Opening.MaxBatch + 1) end)
		t.expect.throws(function() Opening.openMany(p, prof, 'Nope', 3) end)
		t.expect.equal(R.ownedString(prof.Data.Shoes), before)
	end)

	t.test('a Buy 8 grant gives 8 pairs even with a full rack, and is a valid save', function()
		local p = fakePlayer()
		local prof = newProfile()
		prof.Data.Shoes.Owned.FreshCanvas = R.MaxOwned -- (a full rack never blocks a paid grant)
		local ids, info = Opening.openMany(p, prof, 'Grail', 8, { Rolls = { 0.1, 0.6, 0.1, 0.9, 0.1, 0.97, 0.6, 0.995 } })
		t.expect.equal(#ids, 8)
		t.expect.equal(info.Best, 8)
		t.expect.equal(info.Shoe, 'TheGrail')
		t.expect.equal(R.count(prof.Data.Shoes), R.MaxOwned + 8)
		t.expect.equal(prof.Data.Shoes.Owned.GoldenHour, 3)
		for _, id in ids do t.expect.equal(Shoes.ById[id].Box, 'Grail') end
		t.expect.truthy(S.validate(prof.Data))
		-- random rolls: always 8 pairs from that box
		local _, rand = Opening.openMany(p, prof, 'Exclusive', 8)
		t.expect.equal(#rand.Shoes, 8)
		for _, s in rand.Shoes do t.expect.equal(Shoes.ById[s.Shoe].Box, 'Exclusive') end
		t.expect.equal(prof.Data.Shoes.Opened, 16)
	end)

	---------------------------------------------------------------------------------------------- receipts
	t.test('every new product through ProcessReceipt: granted once per purchase id', function()
		withIds(function()
			local p = fakePlayer()
			local prof = newProfile()
			prof.Data.Shoes.Owned.FreshCanvas = R.MaxOwned
			local notes = {}
			local deps = {
				playerOf = function(id) return id == 4242 and p or nil end,
				profileOf = function() return prof end,
				push = function() end,
				grants = Receipts.grants({ notice = function(_, text) table.insert(notes, text) end, now = function() return 50000 end }),
				wait = 1,
			}
			local function buy(key, purchaseId)
				return Receipts.process({ PlayerId = 4242, ProductId = Products.idOf(key), PurchaseId = purchaseId }, deps)
			end
			-- shoe-box bundles: N pairs each
			local expect = { ShoeBoxExclusive3 = 3, ShoeBoxExclusive8 = 8, ShoeBoxGrail3 = 3, ShoeBoxGrail8 = 8, ShoeBoxExclusive = 1, ShoeBoxGrail = 1 }
			for key, n in expect do
				local before = prof.Data.Shoes.Opened
				t.expect.equal(buy(key, 'p-' .. key), DEC.PurchaseGranted)
				t.expect.equal(prof.Data.Shoes.Opened - before, n)
				-- Roblox asks again with the same purchase id: no more pairs
				t.expect.equal(buy(key, 'p-' .. key), DEC.PurchaseGranted)
				t.expect.equal(prof.Data.Shoes.Opened - before, n)
				t.expect.truthy(table.find(prof.LastSavedData.ProcessedReceipts, 'p-' .. key) ~= nil)
			end
			t.expect.equal(notes[#notes] ~= nil, true)
			-- cash packs: their amounts, once
			for _, key in { 'TinyCash', 'SmallCash', 'MediumCash', 'LargeCash' } do
				local cash = prof.Data.Cash
				t.expect.equal(buy(key, 'c-' .. key), DEC.PurchaseGranted)
				t.expect.equal(buy(key, 'c-' .. key), DEC.PurchaseGranted)
				t.expect.equal(prof.Data.Cash - cash, Products.cashAmount(key))
				t.expect.equal(p.Attrs.Cash, prof.Data.Cash)
			end
			-- the Boost Bundle, once
			t.expect.equal(buy('BoostBundle', 'b-1'), DEC.PurchaseGranted)
			t.expect.equal(buy('BoostBundle', 'b-1'), DEC.PurchaseGranted)
			t.expect.equal(Boosts.total(prof.Data.Passes.Boost, 50000), 2700)
			-- the fourth power pack
			local rep = prof.Data.Rep
			t.expect.equal(buy('PowerPack4', 'w-1'), DEC.PurchaseGranted)
			t.expect.truthy(prof.Data.Rep > rep)
			t.expect.truthy(S.validate(prof.Data))
			-- an unknown product id: not granted, nothing recorded
			local n = #prof.Data.ProcessedReceipts
			t.expect.equal(Receipts.process({ PlayerId = 4242, ProductId = 12345, PurchaseId = 'x-1' }, deps), DEC.NotProcessedYet)
			t.expect.equal(#prof.Data.ProcessedReceipts, n)
		end)
	end)

	t.test('the player leaves: a receipt waits; one granted mid-leave is kept by the release save and not given twice', function()
		withIds(function()
			local p = fakePlayer()
			local prof = newProfile()
			local present = true
			local deps = {
				playerOf = function() return present and p or nil end,
				profileOf = function() return prof end,
				push = function() end,
				grants = Receipts.grants({}),
				wait = 1,
			}
			local info = { PlayerId = 4242, ProductId = Products.idOf('ShoeBoxGrail8'), PurchaseId = 'leave-1' }
			-- away: Roblox will ask again on the next join; nothing given yet
			present = false
			t.expect.equal(Receipts.process(info, deps), DEC.NotProcessedYet)
			t.expect.equal(prof.Data.Shoes.Opened, 0)
			-- back, but they leave before the save goes through: the pairs are in the profile, the answer waits
			present = true
			prof.Save = function(self) self.Saves += 1 end
			prof.Active = false
			t.expect.equal(Receipts.process(info, deps), DEC.NotProcessedYet)
			t.expect.equal(prof.Data.Shoes.Opened, 8)
			-- the release save kept the pairs and the purchase id; they rejoin and Roblox asks again
			local saved = deep(prof.Data)
			prof = newProfile(saved)
			prof.LastSavedData = deep(saved)
			t.expect.equal(Receipts.process(info, deps), DEC.PurchaseGranted)
			t.expect.equal(prof.Data.Shoes.Opened, 8)
			t.expect.equal(R.count(prof.Data.Shoes), 8)
			-- the same for the Boost Bundle: no double time after the rejoin
			local binfo = { PlayerId = 4242, ProductId = Products.idOf('BoostBundle'), PurchaseId = 'leave-2' }
			prof.Save = function(self) self.Saves += 1 end
			prof.Active = false
			t.expect.equal(Receipts.process(binfo, deps), DEC.NotProcessedYet)
			local total = Boosts.total(prof.Data.Passes.Boost, os.time())
			t.expect.truthy(total > 2600)
			saved = deep(prof.Data)
			prof = newProfile(saved)
			prof.LastSavedData = deep(saved)
			t.expect.equal(Receipts.process(binfo, deps), DEC.PurchaseGranted)
			t.expect.truthy(Boosts.total(prof.Data.Passes.Boost, os.time()) <= total)
		end)
	end)

	t.test('a grant that fails records nothing and asks Roblox to try again', function()
		local prof = newProfile()
		local grants = { Boom = function(_, profile) error('nope') end }
		local ok, why = Receipts.apply(grants, fakePlayer(), prof, 'Boom', 'f-1')
		t.expect.falsy(ok)
		t.expect.truthy(string.find(why, 'nope', 1, true) ~= nil)
		t.expect.equal(#prof.Data.ProcessedReceipts, 0)
		t.expect.equal(select(2, Receipts.apply(grants, fakePlayer(), prof, 'Missing', 'f-2')), 'nogrant')
		-- a bad box count fails before any pair is added
		local before = prof.Data.Shoes.Opened
		t.expect.throws(function() Opening.openMany(fakePlayer(), prof, 'Grail', 99) end)
		t.expect.equal(prof.Data.Shoes.Opened, before)
		-- the receipt list stays at most Kept long
		local g = { Ok = function() end }
		for i = 1, Receipts.Kept + 5 do Receipts.apply(g, fakePlayer(), prof, 'Ok', 'k-' .. i) end
		t.expect.equal(#prof.Data.ProcessedReceipts, Receipts.Kept)
		t.expect.equal(prof.Data.ProcessedReceipts[Receipts.Kept], 'k-' .. (Receipts.Kept + 5))
	end)

	---------------------------------------------------------------------------------------------- game passes
	t.test('+1 Shoe Slot: 4 pairs on with the pass, saves with 4 load, and a 4th pair is never lost at join', function()
		t.expect.equal(R.MaxSlots, R.MaxEquipped + 1)
		t.expect.equal(R.slotsFor(true), 4)
		t.expect.equal(R.slotsFor(nil), 3)
		t.expect.equal(R.slotsOf(99), R.MaxSlots)
		local four = { 'BlockRoyalty', 'StreetAngel', 'ChromeKicks', 'Checkmate' }
		local owned = {}
		for _, id in four do owned[id] = 1 end
		local s = R.sanitize({ Owned = table.clone(owned), Equipped = { 'BlockRoyalty', 'StreetAngel', 'ChromeKicks' }, Opened = 0 })
		t.expect.equal(select(2, R.canEquip(s, 'Checkmate')), 'full') -- (no pass: 3)
		t.expect.truthy(R.equip(s, 'Checkmate', 4))
		t.expect.equal(#s.Equipped, 4)
		t.expect.equal(select(2, R.canEquip(s, 'Checkmate', 4)), 'all')
		t.expect.equal(#R.sanitize(s).Equipped, 4) -- (a save keeps up to MaxSlots)
		t.expect.equal(#R.best(s, 4), 4)
		t.expect.equal(#R.best(s), 3)
		-- the save loads (ProfileSchema allows MaxSlots, no more)
		local data = S.new()
		data.Shoes = { Owned = table.clone(owned), Equipped = table.clone(four), Opened = 4 }
		t.expect.truthy(S.validate(data))
		data.Shoes.Owned.FreshCanvas = 1
		table.insert(data.Shoes.Equipped, 'FreshCanvas')
		t.expect.throws(function() S.validate(data) end)
		-- ShoeOpening.sync: with the pass, 4 on and ShoesMax 4
		local p = fakePlayer()
		local prof = newProfile()
		prof.Data.Shoes = { Owned = table.clone(owned), Equipped = table.clone(four), Opened = 4 }
		p:SetAttribute('Pass_ExtraEquip', true)
		Opening.sync(p, prof)
		t.expect.equal(p.Attrs.ShoesMax, 4)
		t.expect.equal(p.Attrs.ShoesEquipped, 'BlockRoyalty,StreetAngel,ChromeKicks,Checkmate')
		t.expect.equal(p.Attrs.ShoeBonus, 48 + 28 + 17 + 10)
		-- at join, before the pass check is back: the 4th stays in the save, only 3 count
		p:SetAttribute('Pass_ExtraEquip', nil)
		Opening.sync(p, prof)
		t.expect.equal(p.Attrs.ShoesMax, 3)
		t.expect.equal(#prof.Data.Shoes.Equipped, 4)
		t.expect.equal(p.Attrs.ShoesEquipped, 'BlockRoyalty,StreetAngel,ChromeKicks')
		t.expect.equal(p.Attrs.ShoeBonus, 48 + 28 + 17)
		-- the check came back with the pass: all 4 count again
		p:SetAttribute('Pass_ExtraEquip', true)
		p:SetAttribute('PassesChecked', true)
		Opening.sync(p, prof)
		t.expect.equal(#prof.Data.Shoes.Equipped, 4)
		t.expect.equal(p.Attrs.ShoeBonus, 48 + 28 + 17 + 10)
		-- the check came back without it: the weakest pair comes off (still owned)
		p:SetAttribute('Pass_ExtraEquip', nil)
		Opening.sync(p, prof)
		t.expect.equal(#prof.Data.Shoes.Equipped, 3)
		t.expect.equal(table.find(prof.Data.Shoes.Equipped, 'Checkmate'), nil)
		t.expect.equal(prof.Data.Shoes.Owned.Checkmate, 1)
		-- a new pair goes straight onto the 4th slot with the pass
		local q = fakePlayer()
		q:SetAttribute('Pass_ExtraEquip', true)
		local fresh = newProfile()
		local _, info = Opening.openMany(q, fresh, 'Street', 4, { Rolls = { 0.1, 0.1, 0.1, 0.1 } })
		t.expect.equal(info.Shoes[4].Equipped, true)
		t.expect.equal(#fresh.Data.Shoes.Equipped, 4)
		local r = fakePlayer()
		local plain = newProfile()
		_, info = Opening.openMany(r, plain, 'Street', 4, { Rolls = { 0.1, 0.1, 0.1, 0.1 } })
		t.expect.equal(info.Shoes[4].Equipped, false)
		t.expect.equal(r.Attrs.ShoesMax, 3)
	end)

	t.test('Lucky: Epic and up weigh double in a Cash box (renormalised), the Robux boxes never change', function()
		local plain, lucky = R.chances('Street'), R.chances('Street', true)
		local sum = 0
		for i, c in lucky do
			sum += c.Chance
			if Shoes.ById[c.Id].Rank >= 3 then
				t.expect.truthy(c.Chance > plain[i].Chance)
			else
				t.expect.truthy(c.Chance < plain[i].Chance)
			end
		end
		t.expect.near(sum, 100, 1e-6)
		t.expect.near(lucky[3].Chance, 1900 / 11300 * 100, 1e-9) -- (Epic: 950 x 2 of 6200 + 2500 + (950 + 300 + 45 + 5) x 2)
		t.expect.equal(plain[3].Chance, 9.5)
		t.expect.equal(R.chanceOf('Checkmate', true), lucky[3].Chance)
		t.expect.equal(R.chanceOf('Checkmate'), 9.5)
		t.expect.equal(R.chanceOf('SilverStreak', true), 60)
		-- a roll that is Rare without the pass is Epic with it
		t.expect.equal(R.roll('Street', 0.8), 'RedRocket')
		t.expect.equal(R.roll('Street', 0.8, true), 'Checkmate')
		-- the Robux boxes: the same odds and rolls either way
		for _, id in { 'Exclusive', 'Grail' } do
			local a, b = R.chances(id), R.chances(id, true)
			for i in a do t.expect.equal(a[i].Chance, b[i].Chance) end
			for _, x in { 0.1, 0.59, 0.61, 0.9, 0.98, 0.999 } do t.expect.equal(R.roll(id, x), R.roll(id, x, true)) end
		end
		-- ShoeOpening rolls with the owner's odds
		local p = fakePlayer()
		p:SetAttribute('Pass_Lucky', true)
		local prof = newProfile()
		local ids = Opening.openMany(p, prof, 'Street', 1, { Rolls = { 0.8 } })
		t.expect.equal(ids[1], 'Checkmate')
		ids = Opening.openMany(fakePlayer(), newProfile(), 'Street', 1, { Rolls = { 0.8 } })
		t.expect.equal(ids[1], 'RedRocket')
		-- the Lucky card says what it does (Cash boxes only)
		t.expect.truthy(string.find(Products.ByKey.Lucky.Detail, 'Cash boxes', 1, true) ~= nil)
	end)

	t.test('Triple Open: 3 at once for 3x the Price, with room for 3 pairs', function()
		local s = R.sanitize({ Owned = {}, Equipped = {}, Opened = 0 })
		t.expect.truthy(R.canOpen(s, 75, 'Street', 1, nil, 3))
		t.expect.equal(select(2, R.canOpen(s, 74, 'Street', 1, nil, 3)), 'cash')
		t.expect.truthy(R.canOpen(s, 25, 'Street', 1)) -- (one is still one)
		s.Owned.FreshCanvas = R.MaxOwned - 2
		t.expect.equal(select(2, R.canOpen(s, 1e9, 'Street', 1, nil, 3)), 'full')
		t.expect.truthy(R.canOpen(s, 1e9, 'Street', 1, nil, 1))
		t.expect.equal(select(2, R.canOpen(s, 1e9, 'Exclusive', 1, nil, 3)), 'robux')
		t.expect.equal(select(2, R.canOpen(s, 1e9, 'Street', 1, nil, 0)), 'unknown')
		t.expect.truthy(string.find(Products.ByKey.TripleOpen.Detail, '3x', 1, true) ~= nil)
		-- all three passes are sold now (their effects and every display that shows them are in)
		for _, key in { 'ExtraEquip', 'Lucky', 'TripleOpen' } do t.expect.equal(Products.ByKey[key].Wired, true) end
	end)
end
