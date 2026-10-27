-- Brief 29, P5 (money and retention): packs that scale with you, the daily streak and its restore, the offline cap and the
-- 2x Offline product, the friend boost cap, the new passes, and the receipts of the new products.
return function(t)
	local RS = game:GetService('ReplicatedStorage')
	local Products = require(RS.Shared.Config.Products)
	local Rules = require(RS.Shared.RetentionRules)
	local RebirthRules = require(RS.Shared.RebirthRules)
	local HS = game.ServerScriptService.HoodServer
	local S = require(HS.ProfileSchema)
	local Retention = require(HS.Retention)
	local Receipts = require(HS.StoreReceipts)
	local Boosts = require(HS.Boosts)
	local DAY = 86400
	local T0 = 1700000000 - (1700000000 % DAY) + 3600 -- an hour into a UTC day

	local function fakePlayer()
		local attrs = {}
		local p = { DisplayName = 'Tester', Name = 'Tester', UserId = 4242, Parent = nil, Attrs = attrs }
		function p:GetAttribute(k) return attrs[k] end
		function p:SetAttribute(k, v) attrs[k] = v end
		return p
	end
	local function profile() return { Data = S.new() } end

	t.test('power packs: the larger of the rebirth-based amount and a share of your current Power', function()
		local need = 100000
		-- with no Power the amount is today's: Pack x need, two figures
		for _, key in { 'PowerPack1', 'PowerPack2', 'PowerPack3', 'PowerPack4' } do
			t.expect.equal(Products.powerAmount(key, need, 0), Products.powerAmount(key, need))
		end
		-- holding more than the rebirth needs makes a pack bigger, never smaller
		local base = Products.powerAmount('PowerPack2', need, 0)
		local rich = Products.powerAmount('PowerPack2', need, need * 1.2)
		t.expect.truthy(rich > base)
		t.expect.truthy(Products.powerAmount('PowerPack2', need, need * 0.05) >= base)
		-- the ladder stays cheap to expensive, and so do the amounts at any strength
		local prev, prevPrice = 0, 0
		for _, key in { 'PowerPack1', 'PowerPack2', 'PowerPack3', 'PowerPack4' } do
			local e = Products.ByKey[key]
			t.expect.truthy(e.Price > prevPrice)
			local a = Products.powerAmount(key, need, need * 0.8)
			t.expect.truthy(a > prev)
			prev, prevPrice = a, e.Price
		end
		t.expect.equal(Products.ByKey.PowerPack1.Price, 19)
		t.expect.equal(Products.ByKey.PowerPack4.Price, 399)
		-- junk is safe
		t.expect.equal(Products.powerAmount('PowerPack1', need, 0 / 0), Products.powerAmount('PowerPack1', need, 0))
		t.expect.equal(Products.powerAmount('PowerPack1', need, -5), Products.powerAmount('PowerPack1', need, 0))
	end)

	t.test('cash packs: the base amount at stage 1, more at later stages, still cheap to expensive', function()
		for _, key in { 'TinyCash', 'SmallCash', 'MediumCash', 'LargeCash' } do
			t.expect.equal(Products.cashAmount(key, 1), Products.cashAmount(key))
			t.expect.truthy(Products.cashAmount(key, 8) > Products.cashAmount(key, 1))
			t.expect.truthy(Products.cashAmount(key, 16) > Products.cashAmount(key, 8))
			t.expect.equal(Products.cashAmount(key, 999), Products.cashAmount(key, 16)) -- clamped
			t.expect.equal(Products.cashAmount(key, 0 / 0), Products.cashAmount(key, 1))
		end
		for stage = 1, 16 do
			t.expect.truthy(Products.cashAmount('SmallCash', stage) > Products.cashAmount('TinyCash', stage))
			t.expect.truthy(Products.cashAmount('LargeCash', stage) > Products.cashAmount('MediumCash', stage))
		end
	end)

	t.test('the new passes and products are in the catalog, wired, with real prices', function()
		for _, key in { 'AutoOpen', 'Speed2x', 'AutoCollect' } do
			local e = Products.ByKey[key]
			t.expect.truthy(e and e.Kind == 'Pass' and e.Wired == true and e.Price > 0)
			t.expect.equal(Products.Passes[key], 0) -- placeholders: the owner pastes the real ids in
		end
		for _, key in { 'OfflineX2', 'RestoreStreak' } do
			local e = Products.ByKey[key]
			t.expect.truthy(e and e.Kind == 'Product' and e.Wired == true and e.Price > 0)
			t.expect.equal(Products.DeveloperProducts[key], 0)
		end
		t.expect.equal(Products.SpeedPassFactor, 2) -- "2x Speed" is exactly 2x
		t.expect.equal(Products.canBuy('Speed2x'), false) -- no id yet: nothing can be bought
	end)

	t.test('daily rewards: a first claim, then a streak across days that ends at Day 7 and starts again', function()
		local data = S.new()
		local st = Rules.status(data, T0)
		t.expect.truthy(st.Ready and st.Day == 1 and not st.Missed)
		local ok, day = Rules.claim(data, T0)
		t.expect.truthy(ok and day == 1)
		t.expect.falsy(Rules.status(data, T0 + 100).Ready) -- once a day
		t.expect.equal(select(1, Rules.claim(data, T0 + 100)), false)
		for d = 2, 7 do
			local now = T0 + (d - 1) * DAY
			t.expect.truthy(Rules.status(data, now).Ready)
			local _, got = Rules.claim(data, now)
			t.expect.equal(got, d)
		end
		-- after Day 7 the next day is Day 1 again
		local after = Rules.status(data, T0 + 7 * DAY)
		t.expect.truthy(after.Ready and after.Day == 1 and not after.Missed)
	end)

	t.test('a missed day: the streak starts again, or is restored (once, inside the window)', function()
		local data = S.new()
		for d = 1, 3 do Rules.claim(data, T0 + (d - 1) * DAY) end
		t.expect.equal(data.DailyStreak, 3)
		-- skip a day (day 4 missed), come back on day 5
		local now = T0 + 4 * DAY
		local st = Rules.status(data, now)
		t.expect.truthy(st.Ready and st.Missed and st.Day == 1 and st.CanRestore and st.RestoreDay == 4)
		-- without a restore: Day 1 again
		local copy = table.clone(data)
		local _, d1 = Rules.claim(copy, now)
		t.expect.equal(d1, 1)
		-- with the restore: Day 4
		t.expect.truthy(Rules.restore(data, now))
		local after = Rules.status(data, now)
		t.expect.truthy(after.Ready and not after.Missed and after.Day == 4)
		local _, d4 = Rules.claim(data, now)
		t.expect.equal(d4, 4)
		-- nothing to restore now; too late is refused; a fresh player has nothing to restore
		t.expect.equal(select(1, Rules.restore(data, now)), false)
		local late = S.new()
		for d = 1, 3 do Rules.claim(late, T0 + (d - 1) * DAY) end
		local far = Rules.status(late, T0 + (3 + Rules.RestoreWindowDays + 3) * DAY)
		t.expect.truthy(far.Missed and not far.CanRestore)
		t.expect.equal(select(2, Rules.restore(late, T0 + (3 + Rules.RestoreWindowDays + 3) * DAY)), 'toolate')
		t.expect.equal(select(1, Rules.restore(S.new(), now)), false)
	end)

	t.test('daily reward cards: seven days, Day 7 the big one, amounts scale with your stage and your need', function()
		t.expect.equal(#Rules.Daily, 7)
		t.expect.truthy(Rules.Daily[7].Big)
		local need = RebirthRules.need(0)
		for day = 1, 7 do t.expect.truthy(Rules.reward(day, need, 1)) end
		t.expect.truthy(Rules.reward(1, need, 12).Cash > Rules.reward(1, need, 1).Cash)
		t.expect.truthy(Rules.reward(5, RebirthRules.need(5), 1).Power > Rules.reward(5, need, 1).Power)
		t.expect.equal(Rules.reward(8, need, 1), nil)
		local lines = Rules.lines(Rules.reward(7, need, 1), function(n) return tostring(n) end)
		t.expect.equal(#lines, 3) -- Cash, Power and a 3x boost
	end)

	t.test('claiming a daily reward pays it once, and the profile stays valid', function()
		local p = profile()
		local cash0, rep0 = p.Data.Cash, p.Data.Rep
		local ok, day, text = Retention.claimDaily(p, T0)
		t.expect.truthy(ok and day == 1 and type(text) == 'string' and text ~= '')
		t.expect.truthy(p.Data.Cash > cash0)
		t.expect.equal(select(1, Retention.claimDaily(p, T0 + 60)), false)
		-- Day 2 is Power, Day 4 a timed boost
		local ok2 = Retention.claimDaily(p, T0 + DAY)
		t.expect.truthy(ok2 and p.Data.Rep > rep0)
		Retention.claimDaily(p, T0 + 2 * DAY)
		Retention.claimDaily(p, T0 + 3 * DAY)
		t.expect.truthy(Boosts.running(p.Data.Passes.Boost, T0 + 3 * DAY) == 2)
		t.expect.truthy(S.validate(p.Data))
	end)

	t.test('offline earnings: nothing for a quick reconnect, capped at 8 hours, claimed once', function()
		local need = 10000
		t.expect.equal(Rules.offlineSeconds(0, T0), 0) -- a first visit
		t.expect.equal(Rules.offlineSeconds(T0 - 60, T0), 0) -- a reconnect
		t.expect.equal(Rules.offlineSeconds(T0 - 3600, T0), 3600)
		t.expect.equal(Rules.offlineSeconds(T0 - 30 * 3600, T0), 8 * 3600) -- capped
		t.expect.equal(Rules.offlineSeconds(T0 + 5, T0), 0) -- a clock that went backwards
		local eight = Rules.offlinePower(need, 8 * 3600)
		t.expect.equal(Rules.offlinePower(need, 99 * 3600), eight) -- never above the 8-hour amount
		t.expect.equal(Rules.eightHours(need), eight)
		t.expect.truthy(Rules.offlinePower(need, 3600) * 8 <= eight + 8)
		t.expect.truthy(Rules.offlinePower(1, 3600) >= Rules.OfflineMinPerHour) -- a floor for a new player
		-- through a profile: a join, away 12 hours, rejoin
		local p = profile()
		Retention.onJoin(p, T0)
		t.expect.equal(p.Data.Retention.Joins, 1)
		t.expect.equal(p.Data.Retention.Pending, 0)
		Retention.onJoin(p, T0 + 12 * 3600)
		local n = RebirthRules.need(p.Data.Rebirths)
		t.expect.equal(p.Data.Retention.Pending, Rules.eightHours(n))
		-- a second rejoin without claiming never stacks past the cap
		Retention.onJoin(p, T0 + 40 * 3600)
		t.expect.equal(p.Data.Retention.Pending, Rules.eightHours(n))
		local rep = p.Data.Rep
		local ok, amount = Retention.claimOffline(p)
		t.expect.truthy(ok and amount == Rules.eightHours(n) and p.Data.Rep == rep + amount)
		t.expect.equal(select(1, Retention.claimOffline(p)), false) -- once
		t.expect.truthy(S.validate(p.Data))
	end)

	t.test('friend boost: +10% a friend, never above +50%, and it multiplies the shot boost', function()
		t.expect.equal(Rules.friendBoost(0), 0)
		t.expect.near(Rules.friendBoost(1), 0.1)
		t.expect.near(Rules.friendBoost(3), 0.3)
		t.expect.near(Rules.friendBoost(5), 0.5)
		t.expect.near(Rules.friendBoost(40), 0.5)
		t.expect.equal(Rules.friendBoost(-3), 0)
		t.expect.equal(Rules.friendBoost(0 / 0), 0)
		local p = fakePlayer()
		t.expect.equal(Boosts.power(p), 1)
		p:SetAttribute('FriendBoost', 0.3)
		t.expect.near(Boosts.power(p), 1.3)
		p:SetAttribute('Pass_DoubleRep', true)
		t.expect.near(Boosts.power(p), 2.6)
		p:SetAttribute('FriendBoost', 99) -- a forged number cannot go past +50%
		t.expect.near(Boosts.power(p), 3)
	end)

	t.test('the group reward is once, only for members, and off while the group id is 0', function()
		local p = profile()
		t.expect.equal(select(2, Retention.claimGroup(p, true, T0, false)), 'off')
		t.expect.equal(select(2, Retention.claimGroup(p, false, T0, true)), 'notin')
		local cash = p.Data.Cash
		local ok = Retention.claimGroup(p, true, T0, true)
		t.expect.truthy(ok and p.Data.Cash > cash and p.Data.Retention.Group == true)
		t.expect.equal(select(2, Retention.claimGroup(p, true, T0, true)), 'had')
		t.expect.truthy(Boosts.running(p.Data.Passes.Boost, T0) == 2)
		t.expect.equal(require(HS.ServerConfig).GroupId, 0)
	end)

	t.test('receipts: scaled packs, 2x Offline and Restore Streak are granted once', function()
		local grants = Receipts.grants({ now = function() return T0 + 4 * DAY end })
		-- scaled Power pack from the current Power (rich: more than the rebirth-based amount)
		local p, pl = profile(), fakePlayer()
		p.Data.Rep = RebirthRules.need(0) * 1.4
		local before = p.Data.Rep
		local want = Products.powerAmount('PowerPack2', RebirthRules.need(0), before)
		t.expect.truthy(select(1, Receipts.apply(grants, pl, p, 'PowerPack2', 'r1')))
		t.expect.equal(p.Data.Rep, before + want)
		t.expect.equal(select(2, Receipts.apply(grants, pl, p, 'PowerPack2', 'r1')), 'had') -- once
		t.expect.equal(p.Data.Rep, before + want)
		-- cash pack at the best stage reached
		local c = profile()
		for i = 1, 8 do c.Data.ClearedWalls['W' .. i] = true end
		local cash = c.Data.Cash
		Receipts.apply(grants, pl, c, 'SmallCash', 'r2')
		t.expect.equal(c.Data.Cash, cash + Products.cashAmount('SmallCash', 8))
		t.expect.truthy(c.Data.Cash - cash > Products.cashAmount('SmallCash', 1))
		-- 2x Offline: pending counts twice
		local o = profile()
		o.Data.Retention.Pending = 1000
		local rep = o.Data.Rep
		t.expect.truthy(select(1, Receipts.apply(grants, pl, o, 'OfflineX2', 'r3')))
		t.expect.equal(o.Data.Rep, rep + 2000)
		t.expect.equal(o.Data.Retention.Pending, 0)
		-- 2x Offline after the free claim: the same amount again
		local q = profile()
		q.Data.Retention.LastOffline = 700
		local rq = q.Data.Rep
		Receipts.apply(grants, pl, q, 'OfflineX2', 'r4')
		t.expect.equal(q.Data.Rep, rq + 700)
		-- Restore Streak: a real miss keeps the streak
		local r = profile()
		for d = 1, 3 do Rules.claim(r.Data, T0 + (d - 1) * DAY) end
		t.expect.truthy(select(1, Receipts.apply(grants, pl, r, 'RestoreStreak', 'r5')))
		t.expect.truthy(Rules.status(r.Data, T0 + 4 * DAY).Day == 4 and not Rules.status(r.Data, T0 + 4 * DAY).Missed)
		-- ... and with nothing to restore the buyer still gets something real (never nothing for Robux)
		local f = profile()
		local fc = f.Data.Cash
		t.expect.truthy(select(1, Receipts.apply(grants, pl, f, 'RestoreStreak', 'r6')))
		t.expect.truthy(f.Data.Cash > fc)
	end)

	t.test('the profile gets a Retention table, and a damaged one is cleaned (nobody is kicked)', function()
		local d = S.new()
		t.expect.equal(d.Retention.Joins, 0)
		d.Retention = nil
		S.migrate(d)
		t.expect.truthy(S.validate(d))
		local bad = S.new()
		bad.Retention = { Joins = -4, LastSeen = 'x', Pending = 0 / 0, LastOffline = 1e99, Group = 'yes' }
		bad.DailyStreak = 99
		S.migrate(bad)
		t.expect.truthy(S.validate(bad))
		t.expect.equal(bad.Retention.Pending, 0)
		t.expect.equal(bad.Retention.Group, false)
		t.expect.equal(bad.DailyStreak, 7)
		local worse = S.new()
		worse.Retention = 'junk'
		S.migrate(worse)
		t.expect.equal(worse.Retention.Joins, 0)
	end)
end
