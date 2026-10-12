-- Brief 30 (MODELS): The Grail Bundle, a Robux product that adds one pair each of The Grail, Astro Crown and Platinum
-- Wings in one grant, once per purchase (HoodServer/StoreReceipts), sold at its one configured price (the user's
-- R$1,499) with no countdown, no struck price and no sale; its box art is the bundle's own chest.
return function(t)
	local RS = game:GetService('ReplicatedStorage')
	local Products = require(RS.Shared.Config.Products)
	local Shoes = require(RS.Shared.Config.Shoes)
	local HS = game.ServerScriptService.HoodServer
	local S = require(HS.ProfileSchema)
	local Receipts = require(HS.StoreReceipts)
	local DEC = Enum.ProductPurchaseDecision

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
		return prof
	end

	t.test('the bundle: a Featured product at its one configured price, honest, not gifted, not weekly', function()
		local e = Products.ByKey.GrailBundle
		t.expect.truthy(e and e.Kind == 'Product' and e.Section == 'Featured' and e.Wired == true)
		t.expect.equal(Products.GrailBundlePrice, 1499)
		t.expect.equal(e.Price, Products.GrailBundlePrice)
		t.expect.equal(type(Products.DeveloperProducts.GrailBundle), 'number')
		t.expect.equal(e.Art, 'box:GrailBundle')
		t.expect.deepEqual(Products.bundleShoes('GrailBundle'), { 'TheGrail', 'AstroCrown', 'PlatinumWings' })
		for _, id in e.Shoes do t.expect.truthy(Shoes.ById[id] ~= nil) end
		t.expect.equal(Products.bundleShoes('TinyCash'), nil)
		t.expect.falsy(Products.isWeekly('GrailBundle'))
		t.expect.truthy(Products.isWeekly(Products.FeaturedKeys[1]))
		t.expect.falsy(Products.giftable('GrailBundle'))
		t.expect.equal(Products.savings('GrailBundle'), nil)
		t.expect.equal(e.WasPrice, nil)
		t.expect.equal(select(1, Products.boxOpen('GrailBundle')), nil)
		-- (never a made-up deal in its words)
		for _, text in { e.Title, e.Sub, e.Detail } do
			local low = string.lower(text or '')
			for _, bad in { 'limited', 'sale', '% off', 'hurry', 'only today', 'left' } do
				t.expect.equal(string.find(low, bad, 1, true), nil)
			end
		end
		-- the id is a placeholder until the owner makes the product: no purchase prompt yet
		if Products.idOf('GrailBundle') == 0 then t.expect.equal(select(2, Products.canBuy('GrailBundle')), Products.Enabled and 'noid' or 'off') end
	end)

	t.test('one purchase adds one pair of each, once: a retry never grants twice', function()
		local saved = Products.DeveloperProducts.GrailBundle
		Products.DeveloperProducts.GrailBundle = 990001
		local ok, err = pcall(function()
			local p = fakePlayer(5151, 'Buyer')
			local prof = newProfile()
			-- one Astro Crown already owned, two pairs already on
			prof.Data.Shoes.Owned.AstroCrown = 1
			prof.Data.Shoes.Owned.FreshCanvas = 1
			prof.Data.Shoes.Equipped = { 'AstroCrown', 'FreshCanvas' }
			local notes = {}
			local grants = Receipts.grants({ notice = function(_, text) table.insert(notes, text) end })
			t.expect.equal(type(grants.GrailBundle), 'function')
			local deps = { playerOf = function() return p end, profileOf = function() return prof end, push = function() end, grants = grants, wait = 1 }
			local info = { PlayerId = 5151, ProductId = 990001, PurchaseId = 'bundle-1' }
			local opened = prof.Data.Shoes.Opened
			t.expect.equal(Receipts.process(info, deps), DEC.PurchaseGranted)
			local owned = prof.Data.Shoes.Owned
			t.expect.equal(owned.TheGrail, 1)
			t.expect.equal(owned.AstroCrown, 2)
			t.expect.equal(owned.PlatinumWings, 1)
			t.expect.equal(prof.Data.Shoes.Opened, opened) -- (no box was opened)
			t.expect.equal(#prof.Data.Shoes.Equipped, 3) -- (the free slot took the first new pair)
			t.expect.truthy(S.validate(prof.Data))
			t.expect.truthy(string.find(p.Attrs.ShoesOwned or '', 'TheGrail', 1, true) ~= nil)
			t.expect.truthy(#notes == 1 and string.find(notes[1], 'The Grail, Astro Crown and Platinum Wings', 1, true) ~= nil)
			-- Roblox asks again: nothing more
			t.expect.equal(Receipts.process(info, deps), DEC.PurchaseGranted)
			t.expect.equal(owned.TheGrail, 1)
			t.expect.equal(prof.Data.Shoes.Owned.PlatinumWings, 1)
			-- a second purchase is a second bundle
			t.expect.equal(Receipts.process({ PlayerId = 5151, ProductId = 990001, PurchaseId = 'bundle-2' }, deps), DEC.PurchaseGranted)
			t.expect.equal(prof.Data.Shoes.Owned.TheGrail, 2)
		end)
		Products.DeveloperProducts.GrailBundle = saved
		if not ok then error(err, 0) end
	end)
end
