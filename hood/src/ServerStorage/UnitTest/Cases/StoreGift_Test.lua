-- Brief 30 (SHOP, the Exclusive Shop): the weekly Featured pack's real rotation, what can be gifted, the Featured packs'
-- grants, and Gift A Player's routing at the receipt (HoodServer/StoreReceipts): to the chosen player when they are still
-- here, else to the buyer with a notice; the receipt id is always the buyer's, a retry never grants twice, and nothing is
-- ever left at NotProcessedYet because of a gift.
return function(t)
	local RS = game:GetService('ReplicatedStorage')
	local Products = require(RS.Shared.Config.Products)
	local Guns = require(RS.Shared.Config.Guns)
	local UIKit = require(RS.Shared.UIKit)
	local HS = game.ServerScriptService.HoodServer
	local S = require(HS.ProfileSchema)
	local Boosts = require(HS.Boosts)
	local Receipts = require(HS.StoreReceipts)
	local DEC = Enum.ProductPurchaseDecision
	local MONDAY = 1791763200 -- 2026-10-12 00:00 UTC, a Monday

	local function fakePlayer(id, name)
		local attrs = {}
		local p = { DisplayName = name, Name = name, UserId = id, Parent = nil, Attrs = attrs }
		function p:GetAttribute(k) return attrs[k] end
		function p:SetAttribute(k, v) attrs[k] = v end
		return p
	end
	local function deep(x)
		if type(x) ~= 'table' then return x end
		local c = {}
		for k, v in x do c[k] = deep(v) end
		return c
	end
	local function newProfile()
		local after = {}
		local prof = { Data = S.new(), LastSavedData = nil, Active = true, Saves = 0 }
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
	local function withIds(fn)
		local saved = table.clone(Products.DeveloperProducts)
		local n = 0
		for key in Products.DeveloperProducts do
			n += 1
			Products.DeveloperProducts[key] = 800000 + n
		end
		local ok, err = pcall(fn)
		for key, v in saved do Products.DeveloperProducts[key] = v end
		if not ok then error(err, 0) end
	end

	t.test('the weekly Featured pack rotates for real: one pack a week, the same for everyone, turning over on Monday', function()
		local keys = Products.FeaturedKeys
		t.expect.equal(#keys, 3)
		local seen = {}
		for _, k in keys do
			local e = Products.ByKey[k]
			t.expect.truthy(e and e.Section == 'Featured' and e.Kind == 'Product' and e.Wired == true)
			t.expect.truthy(e.Cash > 0 and e.Boost >= 2 and type(e.Box) == 'string' and e.Count >= 1)
			t.expect.truthy(UIKit.Tone[e.Tone] ~= nil)
		end
		-- the whole week is one pack; its countdown is the time to the next Monday 00:00 UTC
		local k0, left0 = Products.featuredAt(MONDAY)
		t.expect.equal(left0, 7 * 86400)
		for _, dt in { 0, 1, 3600, 3 * 86400 + 17, 7 * 86400 - 1 } do
			local k, left = Products.featuredAt(MONDAY + dt)
			t.expect.equal(k, k0)
			t.expect.equal(left, 7 * 86400 - dt)
		end
		-- the moment the countdown reaches 0 the pack is the next one; three weeks later it is back
		local k1, left1 = Products.featuredAt(MONDAY + 7 * 86400)
		t.expect.truthy(k1 ~= k0)
		t.expect.equal(left1, 7 * 86400)
		local order = {}
		for w = 0, 5 do
			local k = Products.featuredAt(MONDAY + w * 7 * 86400 + 5)
			table.insert(order, k)
			seen[k] = true
		end
		t.expect.equal(order[1], order[4])
		t.expect.equal(order[2], order[5])
		t.expect.truthy(order[1] ~= order[2] and order[2] ~= order[3] and order[1] ~= order[3])
		t.expect.truthy(seen.FeaturedPack1 and seen.FeaturedPack2 and seen.FeaturedPack3)
		-- (a second before Monday is still last week's pack)
		t.expect.equal(select(1, Products.featuredAt(MONDAY - 1)), select(1, Products.featuredAt(MONDAY - 7 * 86400)))
		t.expect.truthy(select(1, Products.featuredAt(MONDAY - 1)) ~= k0)
		-- bad times fall back to the clock instead of erroring
		t.expect.truthy(Products.ByKey[(Products.featuredAt(nil))] ~= nil)
	end)

	t.test('only Cash Packs and Robux boxes can be gifted', function()
		for _, e in Products.Catalog do
			local want = e.Kind == 'Product' and (e.Section == 'Cash' or e.Section == 'Box')
			t.expect.equal(Products.giftable(e.Key), want and e.Wired == true)
		end
		t.expect.equal(Products.giftable('DoubleCash'), false) -- passes never
		t.expect.equal(Products.giftable('PowerPack1'), false)
		t.expect.equal(Products.giftable('BlockParty'), false)
		t.expect.equal(Products.giftable('FeaturedPack1'), false)
		t.expect.equal(Products.giftable('LargeCash'), true)
		t.expect.equal(Products.giftable('ShoeBoxGrail3'), true)
		t.expect.equal(Products.giftable('Nope'), false)
		local gifts = {}
		t.expect.equal(select(2, Receipts.setGift(gifts, 1, 2, 'DoubleCash', 0)), 'notgiftable')
		t.expect.equal(select(2, Receipts.setGift(gifts, 1, 1, 'TinyCash', 0)), 'badtarget') -- not yourself
		t.expect.equal(select(2, Receipts.setGift(gifts, 1, 2, 'TinyCash', 0)), 'set')
		t.expect.equal(select(2, Receipts.setGift(gifts, 1, 0, 'TinyCash', 0)), 'cleared')
		t.expect.equal(gifts[1], nil)
	end)

	t.test('the three Featured packs: Cash + boost + box in one grant, once per purchase', function()
		withIds(function()
			local early = Products.cashAmount('FeaturedPack3', 1)
			t.expect.truthy(early < Guns.ById.Blaster.Cost) -- (no pack buys the end-of-world guns)
			for _, key in Products.FeaturedKeys do
				local e = Products.ByKey[key]
				t.expect.equal(select(2, Products.canBuy(key)), nil)
				local p = fakePlayer(4242, 'Buyer')
				local prof = newProfile()
				prof.Data.StagesCleared = 1
				local notes = {}
				local grants = Receipts.grants({ notice = function(_, text) table.insert(notes, text) end, now = function() return 70000 end })
				t.expect.equal(type(grants[key]), 'function')
				local deps = { playerOf = function() return p end, profileOf = function() return prof end, push = function() end, grants = grants, wait = 1 }
				local info = { PlayerId = 4242, ProductId = Products.idOf(key), PurchaseId = 'f-' .. key }
				local cash, opened = prof.Data.Cash, prof.Data.Shoes.Opened
				t.expect.equal(Receipts.process(info, deps), DEC.PurchaseGranted)
				t.expect.equal(prof.Data.Cash - cash, Products.cashAmount(key, 1))
				t.expect.equal(prof.Data.Shoes.Opened - opened, e.Count)
				t.expect.equal(Boosts.total(prof.Data.Passes.Boost, 70000), Products.BoostDurationSeconds)
				t.expect.equal(Boosts.running(prof.Data.Passes.Boost, 70000), e.Boost)
				t.expect.truthy(S.validate(prof.Data))
				t.expect.truthy(#notes >= 1)
				-- Roblox asks again: nothing more
				t.expect.equal(Receipts.process(info, deps), DEC.PurchaseGranted)
				t.expect.equal(prof.Data.Cash - cash, Products.cashAmount(key, 1))
				t.expect.equal(prof.Data.Shoes.Opened - opened, e.Count)
				t.expect.equal(Boosts.total(prof.Data.Passes.Boost, 70000), Products.BoostDurationSeconds)
			end
		end)
	end)

	t.test('Gift A Player: the grant goes to the chosen player, the receipt stays the buyer\'s, both are told', function()
		withIds(function()
			local buyer, friend = fakePlayer(4242, 'Buyer'), fakePlayer(777, 'Friend')
			local bprof, fprof = newProfile(), newProfile()
			bprof.Data.StagesCleared = 1
			local here = { [4242] = buyer, [777] = friend }
			local profs = { [buyer] = bprof, [friend] = fprof }
			local clock = 1000
			local notes = {}
			local gifts = {}
			local deps = {
				playerOf = function(id) return here[id] end, profileOf = function(p) return profs[p] end, push = function() end,
				grants = Receipts.grants({ notice = function(p, text) table.insert(notes, p.Name .. ': ' .. text) end }),
				gifts = gifts, now = function() return clock end, notice = function(p, text) table.insert(notes, p.Name .. ': ' .. text) end, wait = 1,
			}
			local function buy(key, id) return Receipts.process({ PlayerId = 4242, ProductId = Products.idOf(key), PurchaseId = id }, deps) end
			-- cash: the friend gets the buyer's amount, the buyer gets nothing, the id is the buyer's
			Receipts.setGift(gifts, 4242, 777, 'MediumCash', clock)
			local bc, fc = bprof.Data.Cash, fprof.Data.Cash
			t.expect.equal(buy('MediumCash', 'g-1'), DEC.PurchaseGranted)
			t.expect.equal(fprof.Data.Cash - fc, Products.cashAmount('MediumCash', 1))
			t.expect.equal(bprof.Data.Cash, bc)
			t.expect.equal(friend.Attrs.Cash, fprof.Data.Cash)
			t.expect.truthy(table.find(bprof.Data.ProcessedReceipts, 'g-1') ~= nil)
			t.expect.equal(table.find(fprof.Data.ProcessedReceipts or {}, 'g-1'), nil)
			local told = table.concat(notes, '|')
			t.expect.truthy(string.find(told, 'Friend: Buyer gifted you', 1, true) ~= nil)
			t.expect.truthy(string.find(told, 'Buyer: Your gift is on its way to Friend', 1, true) ~= nil)
			t.expect.equal(gifts[4242], nil) -- (used up)
			-- Roblox asks again with the same id: no second grant to anyone
			t.expect.equal(buy('MediumCash', 'g-1'), DEC.PurchaseGranted)
			t.expect.equal(fprof.Data.Cash - fc, Products.cashAmount('MediumCash', 1))
			t.expect.equal(bprof.Data.Cash, bc)
			-- no gift chosen: the buyer's own
			t.expect.equal(buy('TinyCash', 'g-2'), DEC.PurchaseGranted)
			t.expect.equal(bprof.Data.Cash - bc, Products.cashAmount('TinyCash', 1))
			-- a box gift: the friend opens it
			Receipts.setGift(gifts, 4242, 777, 'ShoeBoxExclusive3', clock)
			local fo, bo = fprof.Data.Shoes.Opened, bprof.Data.Shoes.Opened
			t.expect.equal(buy('ShoeBoxExclusive3', 'g-3'), DEC.PurchaseGranted)
			t.expect.equal(fprof.Data.Shoes.Opened - fo, 3)
			t.expect.equal(bprof.Data.Shoes.Opened, bo)
			-- a gift chosen for another product does not redirect this one
			Receipts.setGift(gifts, 4242, 777, 'LargeCash', clock)
			local fc2 = fprof.Data.Cash
			t.expect.equal(buy('SmallCash', 'g-4'), DEC.PurchaseGranted)
			t.expect.equal(fprof.Data.Cash, fc2)
			-- stale (picked more than a minute ago): the buyer's, with a notice
			Receipts.setGift(gifts, 4242, 777, 'SmallCash', clock)
			clock += Receipts.GiftFresh + 1
			bc = bprof.Data.Cash
			notes = table.clone({})
			t.expect.equal(buy('SmallCash', 'g-5'), DEC.PurchaseGranted)
			t.expect.equal(bprof.Data.Cash - bc, Products.cashAmount('SmallCash', 1))
			t.expect.equal(fprof.Data.Cash, fc2)
			-- the friend left: the buyer's, and told so
			Receipts.setGift(gifts, 4242, 777, 'SmallCash', clock)
			here[777] = nil
			bc = bprof.Data.Cash
			t.expect.equal(buy('SmallCash', 'g-6'), DEC.PurchaseGranted)
			t.expect.equal(bprof.Data.Cash - bc, Products.cashAmount('SmallCash', 1))
			t.expect.truthy(string.find(table.concat(notes, '|'), 'left the server', 1, true) ~= nil)
			t.expect.equal(gifts[4242], nil)
			-- the friend is here but their grant fails: the buyer gets it instead, never nothing
			here[777] = friend
			fprof.Data.Cash = nil
			Receipts.setGift(gifts, 4242, 777, 'TinyCash', clock)
			bc = bprof.Data.Cash
			t.expect.equal(buy('TinyCash', 'g-7'), DEC.PurchaseGranted)
			t.expect.equal(bprof.Data.Cash - bc, Products.cashAmount('TinyCash', 1))
			t.expect.equal(fprof.Data.Cash, nil)
		end)
	end)

	t.test('a gift is worth what the buyer\'s card showed: the buyer\'s best stage sets the Cash, not the receiver\'s', function()
		withIds(function()
			local buyer, friend = fakePlayer(4242, 'Buyer'), fakePlayer(777, 'Friend')
			local bprof, fprof = newProfile(), newProfile()
			bprof.Data.StagesCleared = 9
			fprof.Data.StagesCleared = 1
			local gifts = {}
			Receipts.setGift(gifts, 4242, 777, 'LargeCash', 5)
			local deps = {
				playerOf = function(id) return ({ [4242] = buyer, [777] = friend })[id] end,
				profileOf = function(p) return p == buyer and bprof or fprof end, push = function() end,
				grants = Receipts.grants({}), gifts = gifts, now = function() return 5 end, wait = 1,
			}
			t.expect.equal(Receipts.process({ PlayerId = 4242, ProductId = Products.idOf('LargeCash'), PurchaseId = 'w-1' }, deps), DEC.PurchaseGranted)
			local Retention = require(HS.Retention)
			t.expect.equal(fprof.Data.Cash - S.new().Cash, Products.cashAmount('LargeCash', Retention.bestStage(bprof.Data)))
		end)
	end)

	t.test('the six-step Cash and Power ladders (19 / 49 / 129 / 249 / 399 / 999): more per Robux every step, the MEGA the best value', function()
		local prices = { 19, 49, 129, 249, 399, 999 }
		local cash = { 'TinyCash', 'SmallCash', 'MediumCash', 'BigCash', 'LargeCash', 'MegaCash' }
		local power = { 'PowerPack1', 'PowerPack2', 'PowerPack3', 'PowerPackBig', 'PowerPack4', 'PowerPackMega' }
		local lastC, lastP
		for i = 1, 6 do
			local c, p = Products.ByKey[cash[i]], Products.ByKey[power[i]]
			t.expect.equal(c.Price, prices[i])
			t.expect.equal(p.Price, prices[i])
			t.expect.equal(c.Section, 'Cash')
			t.expect.equal(p.Section, 'Power')
			t.expect.truthy(c.Wired and p.Wired and Products.giftable(cash[i]) and not Products.giftable(power[i]))
			local perC, perP = Products.cashAmount(cash[i]) / c.Price, p.Pack / p.Price
			if lastC then
				t.expect.truthy(perC > lastC and perC <= lastC * 1.2)
				t.expect.truthy(perP > lastP and perP <= lastP * 1.2)
			end
			lastC, lastP = perC, perP
			-- (the Store shows them in catalog order: Tiny ... Big, Large, Mega)
			if i > 1 then
				t.expect.truthy(Products.ByKey[cash[i]].Order > Products.ByKey[cash[i - 1]].Order)
				t.expect.truthy(Products.ByKey[power[i]].Order > Products.ByKey[power[i - 1]].Order)
			end
		end
		-- the new packs grant their amount once and can be gifted
		withIds(function()
			local buyer, friend = fakePlayer(4242, 'Buyer'), fakePlayer(777, 'Friend')
			local bprof, fprof = newProfile(), newProfile()
			local gifts = {}
			local deps = {
				playerOf = function(id) return ({ [4242] = buyer, [777] = friend })[id] end,
				profileOf = function(p) return p == buyer and bprof or fprof end, push = function() end,
				grants = Receipts.grants({}), gifts = gifts, now = function() return 9 end, wait = 1,
			}
			local b0 = bprof.Data.Cash
			t.expect.equal(Receipts.process({ PlayerId = 4242, ProductId = Products.idOf('BigCash'), PurchaseId = 'n-1' }, deps), DEC.PurchaseGranted)
			t.expect.equal(bprof.Data.Cash - b0, Products.cashAmount('BigCash', 1))
			Receipts.setGift(gifts, 4242, 777, 'MegaCash', 9)
			local f0 = fprof.Data.Cash
			t.expect.equal(Receipts.process({ PlayerId = 4242, ProductId = Products.idOf('MegaCash'), PurchaseId = 'n-2' }, deps), DEC.PurchaseGranted)
			t.expect.equal(fprof.Data.Cash - f0, Products.cashAmount('MegaCash', 1))
		end)
	end)
end
