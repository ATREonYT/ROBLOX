-- Brief 30 (MOCKUP): the control rules of the user's shoe UI handoff, through the pure rules the screens and the server
-- share (Shared/ShoeRules, Shared/ShoeUIRules) and the server's own pieces (Retention, StoreReceipts):
--   Lock and Favourite protect from Delete; an equipped pair (every copy on) is never deleted; Delete has a review
--   Equip puts exactly one pair on (a full set swaps out exactly one); Unequip keeps ownership
--   the gift review never passes without a player, never for yourself, never for an item that can't be gifted
--   a daily reward is claimed once a day (a second claim is refused); the bundle's receipt grants once per purchase
--   discovery is kept apart from the copies owned; Auto Open stops at the rarity threshold, no Cash, a full rack
--   the artboard screens build from config with no errors
return function(t)
	local RS = game:GetService('ReplicatedStorage')
	local Shoes = require(RS.Shared.Config.Shoes)
	local ShoeRules = require(RS.Shared.ShoeRules)
	local U = require(RS.Shared.ShoeUIRules)
	local Products = require(RS.Shared.Config.Products)
	local e = t.expect

	local function rack(owned, equipped)
		local r = ShoeRules.new()
		for id, n in owned do r.Owned[id] = n end
		for _, id in equipped or {} do table.insert(r.Equipped, id) end
		return ShoeRules.sanitize(r)
	end

	t.test('Lock and Favourite keep a pair out of Delete; the server refuses it too', function()
		local r = rack({ FreshCanvas = 2, RedRocket = 2, Checkmate = 2 })
		e.truthy(ShoeRules.setLocked(r, 'FreshCanvas', true))
		e.falsy(ShoeRules.setLocked(r, 'FreshCanvas', true)) -- (no change)
		e.falsy(ShoeRules.setLocked(r, 'TheGrail', true)) -- (not owned)
		ShoeRules.setFavorite(r, 'RedRocket', true)
		e.deepEqual({ ShoeRules.canRecycle(r, 'FreshCanvas') }, { false, 'lock' })
		e.deepEqual({ ShoeRules.canRecycle(r, 'RedRocket') }, { false, 'favorite' })
		e.equal(ShoeRules.recycle(r, 'FreshCanvas'), 0)
		e.equal(r.Owned.FreshCanvas, 2)
		local rv = U.deleteReview(r, { 'FreshCanvas', 'RedRocket', 'Checkmate', 'Checkmate' })
		e.deepEqual(rv.Delete, { 'Checkmate' })
		e.equal(#rv.Kept, 2)
		e.equal(rv.Cash, ShoeRules.refund('Checkmate'))
		-- unlocking makes it deletable again; the lock survives a save round trip and drops a pair you no longer own
		e.truthy(ShoeRules.setLocked(r, 'FreshCanvas', false))
		e.truthy((ShoeRules.canRecycle(r, 'FreshCanvas')))
		ShoeRules.setLocked(r, 'Checkmate', true)
		local back = ShoeRules.fromAttributes(ShoeRules.ownedString(r), '', 0, '', ShoeRules.lockedString(r))
		e.truthy(back.Locked.Checkmate)
		r.Owned.Checkmate = nil
		ShoeRules.sanitize(r)
		e.equal(r.Locked.Checkmate, nil)
	end)

	t.test('an equipped pair is never deleted; a spare copy of it can be', function()
		local r = rack({ TheGrail = 1, NeonBomb = 2 }, { 'TheGrail', 'NeonBomb' })
		e.deepEqual({ U.canDelete(r, 'TheGrail') }, { false, 'equipped' })
		e.truthy((U.canDelete(r, 'NeonBomb')))
		local rv = U.deleteReview(r, { 'TheGrail', 'NeonBomb' })
		e.deepEqual(rv.Delete, { 'NeonBomb' })
		e.equal(rv.Kept[1].Why, 'equipped')
		e.equal(ShoeRules.recycle(r, 'NeonBomb'), ShoeRules.refund('NeonBomb'))
		e.equal(r.Owned.NeonBomb, 1)
		e.deepEqual({ U.canDelete(r, 'NeonBomb') }, { false, 'equipped' })
	end)

	t.test('Equip puts exactly one pair on; a full set swaps out exactly one; Unequip keeps the pair', function()
		local r = rack({ FreshCanvas = 1, RedRocket = 1, Checkmate = 1, BlockRoyalty = 1 }, { 'FreshCanvas', 'RedRocket' })
		local before = #r.Equipped
		e.equal(U.equipPlan(r, 'Checkmate', 3).Kind, 'equip')
		e.truthy(U.applyEquip(r, 'Checkmate', 3))
		e.equal(#r.Equipped, before + 1)
		-- full: the weakest by the configured bonus comes off, the new one goes on; the count stays the same
		local plan = U.equipPlan(r, 'BlockRoyalty', 3)
		e.equal(plan.Kind, 'swap')
		e.equal(plan.Out, 'FreshCanvas')
		e.truthy(U.applyEquip(r, 'BlockRoyalty', 3))
		e.equal(#r.Equipped, 3)
		e.equal(ShoeRules.equippedCount(r, 'BlockRoyalty'), 1)
		e.equal(ShoeRules.equippedCount(r, 'FreshCanvas'), 0)
		e.equal(U.equipPlan(r, 'BlockRoyalty', 3).Why, 'all') -- (every copy is on: nothing to do)
		e.equal(U.equipPlan(r, 'TheGrail', 3).Why, 'none')
		-- Unequip: the pair stays owned
		e.truthy((ShoeRules.unequip(r, 'BlockRoyalty')))
		e.equal(r.Owned.BlockRoyalty, 1)
		-- Equip Best compares the configured bonus
		local best = U.bestBy(rack({ FreshCanvas = 1, BlockRoyalty = 1, RedRocket = 1, Checkmate = 1 }), 2)
		e.deepEqual(best, { 'BlockRoyalty', 'Checkmate' })
	end)

	t.test('the gift review: never without a player, never to yourself, never for an item that cannot be gifted', function()
		local key
		for _, entry in Products.Catalog do
			if Products.giftable(entry.Key) then key = entry.Key break end
		end
		e.truthy(key ~= nil)
		e.equal(U.giftReview(Products, key, nil, 1).Why, 'nobody')
		e.equal(U.giftReview(Products, key, { UserId = 1, Name = 'Me' }, 1).Why, 'self')
		e.equal(U.giftReview(Products, 'DoubleCash', { UserId = 2, Name = 'Ann' }, 1).Why, 'notgiftable')
		e.equal(U.giftReview(Products, 'NoSuchThing', { UserId = 2, Name = 'Ann' }, 1).Why, 'unknown')
		local saved = Products.DeveloperProducts[key]
		Products.DeveloperProducts[key] = 0
		e.equal(U.giftReview(Products, key, { UserId = 2, Name = 'Ann' }, 1).Why, 'soon')
		Products.DeveloperProducts[key] = 990077
		local ok = U.giftReview(Products, key, { UserId = 2, Name = 'Ann' }, 1)
		Products.DeveloperProducts[key] = saved
		e.truthy(ok.Ok and ok.To == 'Ann' and ok.Price == Products.ByKey[key].Price)
	end)

	t.test('a daily reward is claimed once: the second claim the same day is refused', function()
		local Retention = require(game.ServerScriptService.HoodServer.Retention)
		local S = require(game.ServerScriptService.HoodServer.ProfileSchema)
		local p = { Data = S.new() }
		local T0 = 1800000000
		e.truthy((Retention.claimDaily(p, T0)))
		local cash = p.Data.Cash
		e.equal(select(1, Retention.claimDaily(p, T0 + 5)), false)
		e.equal(p.Data.Cash, cash)
		local st = Retention.state(p, T0 + 5)
		e.equal(U.dayState(st.Daily, 1), 'claimed')
		e.equal(U.dayState(st.Daily, 2), 'locked')
	end)

	t.test('the Grail Bundle: one price, its three pairs, granted once per purchase', function()
		e.equal(Products.ByKey.GrailBundle.Price, 1499)
		e.deepEqual(Products.bundleShoes('GrailBundle'), { 'TheGrail', 'AstroCrown', 'PlatinumWings' })
		e.falsy(Products.isWeekly('GrailBundle'))
		local HS = game.ServerScriptService.HoodServer
		local S = require(HS.ProfileSchema)
		local Receipts = require(HS.StoreReceipts)
		local attrs = {}
		local p = { UserId = 4242, Name = 'B', DisplayName = 'B' }
		function p:GetAttribute(k) return attrs[k] end
		function p:SetAttribute(k, v) attrs[k] = v end
		local function deep(x)
			if type(x) ~= 'table' then return x end
			local c = {}
			for k, v in x do c[k] = deep(v) end
			return c
		end
		local after = {}
		local prof = { Data = S.new(), LastSavedData = nil, Active = true }
		prof.OnAfterSave = { Connect = function(_, fn)
			table.insert(after, fn)
			return { Disconnect = function() local i = table.find(after, fn); if i then table.remove(after, i) end end }
		end }
		function prof:Save()
			self.LastSavedData = deep(self.Data)
			for _, fn in table.clone(after) do fn(self.LastSavedData) end
		end
		function prof:IsActive() return self.Active end
		local saved = Products.DeveloperProducts.GrailBundle
		Products.DeveloperProducts.GrailBundle = 990002
		local ok, err = pcall(function()
			local deps = { playerOf = function() return p end, profileOf = function() return prof end, push = function() end, grants = Receipts.grants({}), wait = 1 }
			local info = { PlayerId = 4242, ProductId = 990002, PurchaseId = 'gb-1' }
			e.equal(Receipts.process(info, deps), Enum.ProductPurchaseDecision.PurchaseGranted)
			e.equal(Receipts.process(info, deps), Enum.ProductPurchaseDecision.PurchaseGranted)
			e.equal(prof.Data.Shoes.Owned.TheGrail, 1)
			e.equal(prof.Data.Shoes.Owned.PlatinumWings, 1)
			e.truthy(U.bundleArrived({}, prof.Data.Shoes.Owned, { 'TheGrail', 'AstroCrown', 'PlatinumWings' }))
			e.truthy(S.validate(prof.Data))
		end)
		Products.DeveloperProducts.GrailBundle = saved
		if not ok then error(err, 0) end
	end)

	t.test('the Collection keeps a discovered design after its last pair goes; owned copies are counted apart', function()
		local r = rack({ FreshCanvas = 1, Starlight = 2 })
		e.truthy(ShoeRules.discover(r))
		e.falsy(ShoeRules.discover(r))
		e.equal(ShoeRules.recycle(r, 'FreshCanvas'), ShoeRules.refund('FreshCanvas'))
		ShoeRules.sanitize(r)
		local list = U.collection(r)
		e.equal(#list, 22)
		local byId = {}
		for _, x in list do byId[x.Id] = x end
		e.truthy(byId.FreshCanvas.Discovered and byId.FreshCanvas.Count == 0)
		e.truthy(byId.Starlight.Discovered and byId.Starlight.Count == 2)
		e.falsy(byId.TheGrail.Discovered)
		e.deepEqual({ U.discoveredCount(r) }, { 2, 22 })
		e.equal(#U.collection(r, 'Chrome'), 5)
		e.equal(#U.collection(r, 'Street'), 6)
	end)

	t.test('Auto Open stops at the rarity threshold, without the Cash for the next one, or with a full rack', function()
		local box = Shoes.BoxById.Street
		local r = rack({ FreshCanvas = 1 })
		e.equal(U.autoStop({ Shoe = 'FreshCanvas' }, r, 1000, box), nil)
		e.equal(U.autoStop({ Shoe = box.Shoes[U.AutoStopRank] }, r, 1000, box), 'rarity')
		e.equal(U.autoStop({ Shoe = 'FreshCanvas', Shoes = { 'FreshCanvas', box.Shoes[6] } }, r, 1000, box), 'rarity')
		e.equal(U.autoStop({ Shoe = 'FreshCanvas' }, r, box.Price - 1, box), 'cash')
		local full = rack({ FreshCanvas = ShoeRules.MaxOwned })
		e.equal(U.autoStop({ Shoe = 'FreshCanvas' }, full, 1e6, box), 'full')
	end)

	t.test('inventory search, sort and filter work on display names and config values', function()
		local r = rack({ FreshCanvas = 2, BlockRoyalty = 1, SprayTag = 1, TheGrail = 1 }, { 'TheGrail' })
		local names = function(list) local out = {} for _, x in list do table.insert(out, x.Id) end return out end
		e.deepEqual(names(U.inventory(r, { Sort = 'Name' })), { 'BlockRoyalty', 'FreshCanvas', 'SprayTag', 'TheGrail' })
		e.equal(U.inventory(r, { Sort = 'Power' })[1].Id, 'TheGrail')
		e.deepEqual(names(U.inventory(r, { Query = 'fresh' })), { 'FreshCanvas' })
		e.deepEqual(names(U.inventory(r, { Filter = 'Crown' })), { 'TheGrail' })
		e.deepEqual(names(U.inventory(r, { Filter = 'Equipped' })), { 'TheGrail' })
		e.equal(select(1, U.capacity(r)), 5)
	end)

	t.test('the artboard names and colours come from config (one rarity colour map, no invented sixth design)', function()
		local A = require(RS.Shared.ArtKit)
		e.equal(#Shoes.BoxById.Exclusive.Shoes, 5)
		e.equal(#Shoes.BoxById.Grail.Shoes, 5)
		e.equal(A.boxName('Exclusive'), 'Chrome Box')
		e.equal(A.boxName('Grail'), 'Crown Box')
		e.equal(A.shoeName('TheGrail'), 'The Grail')
		for _, r in Shoes.Rarities do e.equal(A.rarity(r.Id).Color, r.Color) end
		e.truthy(A.rarity('TheGrail').Rainbow)
		e.falsy(A.rarity('FreshCanvas').Rainbow)
	end)
end
