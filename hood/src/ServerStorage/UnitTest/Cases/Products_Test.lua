-- The Store's catalog (Shared/Config/Products, brief 17): every entry has an id slot and a sane price, nothing can be
-- bought while its id is 0 or its effect isn't wired, receipts map back to their keys, and packs scale with progress.
return function(t)
	local RS = game:GetService('ReplicatedStorage')
	local Products = require(RS.Shared.Config.Products)
	local UIKit = require(RS.Shared.UIKit)

	t.test('every catalog entry has an id slot, a price, a section and a tone', function()
		local sections = { Rebirth = true }
		for _, s in Products.Sections do sections[s.Id] = true end
		local seen = {}
		for _, e in Products.Catalog do
			t.expect.truthy(not seen[e.Key])
			seen[e.Key] = true
			t.expect.truthy(e.Kind == 'Pass' or e.Kind == 'Product')
			local ids = e.Kind == 'Pass' and Products.Passes or Products.DeveloperProducts
			t.expect.equal(type(ids[e.Key]), 'number')
			t.expect.truthy(type(e.Price) == 'number' and e.Price > 0 and e.Price % 1 == 0)
			t.expect.truthy(sections[e.Section])
			t.expect.truthy(UIKit.Tone[e.Tone] ~= nil)
			t.expect.truthy(type(e.Title) == 'string' and e.Title ~= '')
			t.expect.truthy(type(e.Art) == 'string' and e.Art:match('^%w+:.+$') ~= nil)
		end
		-- and every id slot is in the catalog
		for key in Products.Passes do t.expect.truthy(Products.ByKey[key] and Products.ByKey[key].Kind == 'Pass') end
		for key in Products.DeveloperProducts do t.expect.truthy(Products.ByKey[key] and Products.ByKey[key].Kind == 'Product') end
	end)

	t.test('the pad passes and the shoe-box passes are all in the store', function()
		for _, key in { 'DoubleRep', 'DoubleCash', 'AutoShoot', 'VIP', 'Lucky', 'TripleOpen', 'ExtraEquip', 'PowerPack1', 'SmallCash', 'SkipRebirth', 'TenXCash', 'RangeVIP1', 'RangeVIP2' } do
			t.expect.truthy(Products.ByKey[key] ~= nil)
		end
	end)

	t.test('nothing can be bought with id 0, an unwired item never, a wired one with an id', function()
		local saved = { Products.Passes.DoubleRep, Products.Passes.VIP, Products.DeveloperProducts.PowerPack1, Products.Enabled }
		for _, e in Products.Catalog do
			local ok, why = Products.canBuy(e.Key)
			if Products.idOf(e.Key) == 0 then
				t.expect.falsy(ok)
				t.expect.equal(why, Products.Enabled and 'noid' or 'off')
			end
		end
		Products.Enabled = true
		Products.Passes.DoubleRep = 111
		Products.Passes.VIP = 222
		Products.DeveloperProducts.PowerPack1 = 333
		local ok = Products.canBuy('DoubleRep')
		t.expect.equal(ok, Products.ByKey.DoubleRep.Wired == true)
		local okVip, whyVip = Products.canBuy('VIP')
		if Products.ByKey.VIP.Wired ~= true then
			t.expect.falsy(okVip)
			t.expect.equal(whyVip, 'unwired')
		end
		t.expect.equal(Products.keyFor('Pass', 111), 'DoubleRep')
		t.expect.equal(Products.keyFor('Product', 333), 'PowerPack1')
		t.expect.equal(Products.keyFor('Product', 111), nil)
		t.expect.equal(Products.keyFor('Pass', 0), nil)
		Products.Enabled = false
		t.expect.falsy((Products.canBuy('DoubleRep')))
		Products.Passes.DoubleRep, Products.Passes.VIP, Products.DeveloperProducts.PowerPack1, Products.Enabled = saved[1], saved[2], saved[3], saved[4]
		t.expect.falsy((Products.canBuy('NoSuchThing')))
	end)

	-- Brief 23: the 10x Cash pad and the two Robux lanes are passes like the others: an id slot, a card, a purchase that
	-- maps back to its key (StoreService sets Pass_<Key> from it) and a prompt only once the owner pastes an id.
	t.test('the 10x Cash and lane passes: id slots, wired cards, purchases map back to their keys', function()
		local saved = { Products.Passes.TenXCash, Products.Passes.RangeVIP1, Products.Passes.RangeVIP2, Products.Enabled }
		Products.Enabled = true
		for i, key in { 'TenXCash', 'RangeVIP1', 'RangeVIP2' } do
			local e = Products.ByKey[key]
			t.expect.truthy(e ~= nil and e.Kind == 'Pass' and e.Section == 'Gamepass' and e.Wired == true)
			t.expect.equal(Products.idOf(key), saved[i] > 0 and saved[i] or 0)
			Products.Passes[key] = 9000 + i
			t.expect.equal(Products.idOf(key), 9000 + i)
			t.expect.equal(Products.keyFor('Pass', 9000 + i), key)
			t.expect.equal(Products.keyFor('Product', 9000 + i), nil)
			t.expect.truthy((Products.canBuy(key)))
			Products.Passes[key] = 0
			local ok, why = Products.canBuy(key)
			t.expect.falsy(ok); t.expect.equal(why, 'noid')
		end
		t.expect.equal(Products.ByKey.TenXCash.Price, 199)
		t.expect.equal(Products.ByKey.RangeVIP1.Price, 99)
		t.expect.equal(Products.ByKey.RangeVIP2.Price, 249)
		Products.Passes.TenXCash, Products.Passes.RangeVIP1, Products.Passes.RangeVIP2, Products.Enabled = saved[1], saved[2], saved[3], saved[4]
	end)

	t.test('ids must be whole positive numbers', function()
		local saved = Products.Passes.Lucky
		Products.Passes.Lucky = -5
		t.expect.equal(Products.idOf('Lucky'), 0)
		Products.Passes.Lucky = 1.5
		t.expect.equal(Products.idOf('Lucky'), 0)
		Products.Passes.Lucky = saved
	end)

	t.test('power packs grow with the next rebirth and round to two figures; cash packs are fixed', function()
		local small, big = Products.powerAmount('PowerPack1', 2500), Products.powerAmount('PowerPack1', 250000)
		t.expect.truthy(small >= 100 and big > small)
		t.expect.truthy(Products.powerAmount('PowerPack3', 2500) > Products.powerAmount('PowerPack2', 2500))
		t.expect.truthy(Products.powerAmount('PowerPack2', 123456) % 1000 == 0) -- 61728 -> 62000
		t.expect.equal(Products.powerAmount('PowerPack1', 0 / 0), Products.powerAmount('PowerPack1', 1000))
		t.expect.equal(Products.powerAmount('SmallCash', 5000), 0)
		t.expect.truthy(Products.cashAmount('SmallCash') > 0 and Products.cashAmount('LargeCash') > Products.cashAmount('SmallCash'))
		t.expect.equal(Products.cashAmount('PowerPack1'), 0)
	end)
end
