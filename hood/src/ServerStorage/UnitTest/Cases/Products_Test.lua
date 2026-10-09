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
		for _, key in { 'DoubleRep', 'DoubleCash', 'AutoShoot', 'VIP', 'Lucky', 'TripleOpen', 'ExtraEquip', 'PowerPack1', 'SmallCash', 'SkipRebirth' } do
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
