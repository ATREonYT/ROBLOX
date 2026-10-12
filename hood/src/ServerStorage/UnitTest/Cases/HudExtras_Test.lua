-- Brief 30, HUD: the soldier game's HUD extras the user chose: the spin wheel (a real free-spin clock, honest odds, a won
-- box opened after the wheel stops), the Playtime Rewards (session playtime, a short drop keeps the session), the Missions
-- (three tasks, counted only from what the server sees, claimed and replaced) and the Starter Pack (once, its parts exactly
-- as listed), their saves (ProfileSchema: defaults for old profiles, damaged tables rebuilt) and their receipts.
return function(t)
	local RS = game:GetService('ReplicatedStorage')
	local Products = require(RS.Shared.Config.Products)
	local Rules = require(RS.Shared.HudExtrasRules)
	local Shoes = require(RS.Shared.Config.Shoes)
	local RebirthRules = require(RS.Shared.RebirthRules)
	local HS = game.ServerScriptService.HoodServer
	local S = require(HS.ProfileSchema)
	local X = require(HS.HudExtras)
	local Receipts = require(HS.StoreReceipts)
	local Boosts = require(HS.Boosts)
	local T0 = 1700000000

	local function fakePlayer()
		local attrs = {}
		local p = { DisplayName = 'Tester', Name = 'Tester', UserId = 4242, Parent = nil, Attrs = attrs }
		function p:GetAttribute(k) return attrs[k] end
		function p:SetAttribute(k, v) attrs[k] = v end
		return p
	end
	local function profile() return { Data = S.new() } end
	local function seq(list)
		local i = 0
		return function(n) i += 1 return math.clamp(list[(i - 1) % #list + 1], 1, n) end
	end

	t.test('the wheel: eight wedges, weights out of 100, the odds it shows are the odds it rolls', function()
		t.expect.equal(#Rules.Wedges, 8)
		t.expect.equal(Rules.WedgeTotal, 100)
		local seen = {}
		local sum = 0
		for i = 1, #Rules.Wedges do
			sum += tonumber((string.gsub(Rules.chanceText(i), '%%', ''))) or 0
			seen[Rules.Wedges[i].Id] = true
		end
		t.expect.near(sum, 100, 0.5)
		-- the roll's edges: r = 0 is the first wedge, just under 1 the last, the cumulative weights split the rest
		t.expect.equal(Rules.pick(0), 1)
		t.expect.equal(Rules.pick(0.9999), #Rules.Wedges)
		t.expect.equal(Rules.pick(Rules.Wedges[1].Weight / 100 - 0.0001), 1)
		t.expect.equal(Rules.pick(Rules.Wedges[1].Weight / 100 + 0.0001), 2)
		t.expect.equal(Rules.pick(0 / 0), 1)
		t.expect.equal(Rules.pick(-3), 1)
		t.expect.equal(Rules.pick(7), #Rules.Wedges)
		-- every wedge has a picture and a line
		for _, w in Rules.Wedges do
			local r = Rules.make(w, 1000, 1)
			t.expect.truthy(#Rules.lines(r, tostring) >= 1)
			t.expect.truthy(type(Rules.iconOf(r)) == 'string' and Rules.iconOf(r) ~= '')
		end
		-- each wedge's centre angle: clockwise from the top, 45 degrees apart
		t.expect.equal(Rules.wedgeAngle(1), 0)
		t.expect.equal(Rules.wedgeAngle(3), 90)
		t.expect.equal(Rules.chanceText(3), '14%')
	end)

	t.test('the free spin is a real clock: one free spin, then FreeEvery later the next; extras after the free one', function()
		local s = Rules.sanitizeSpin(nil)
		local st = Rules.spinState(s, T0)
		t.expect.truthy(st.Free)
		t.expect.equal(st.Total, 1)
		local ok, which = Rules.takeSpin(s, T0)
		t.expect.truthy(ok)
		t.expect.equal(which, 'free')
		t.expect.equal(s.NextFree, T0 + Rules.Spin.FreeEvery)
		t.expect.falsy((Rules.takeSpin(s, T0 + 10)))
		t.expect.equal(Rules.spinState(s, T0 + 10).Wait, Rules.Spin.FreeEvery - 10)
		Rules.addSpins(s, Rules.Spin.PackSpins)
		t.expect.equal(Rules.spinState(s, T0 + 10).Total, Rules.Spin.PackSpins)
		local _, w2 = Rules.takeSpin(s, T0 + 10)
		t.expect.equal(w2, 'extra')
		t.expect.equal(s.Extra, Rules.Spin.PackSpins - 1)
		-- when the clock comes round the free one is used before the extras
		local _, w3 = Rules.takeSpin(s, T0 + Rules.Spin.FreeEvery)
		t.expect.equal(w3, 'free')
		t.expect.equal(s.Extra, Rules.Spin.PackSpins - 1)
		-- junk is rebuilt
		local j = Rules.sanitizeSpin({ NextFree = 'x', Extra = -4, Spins = 0 / 0, PendingBox = 5 })
		t.expect.deepEqual(j, { NextFree = 0, Extra = 0, Spins = 0, PendingBox = '' })
		t.expect.equal(Rules.sanitizeSpin({ Extra = 1e9 }).Extra, Rules.Spin.MaxExtra)
	end)

	t.test('a spin on a profile: the prize is granted once, a won box waits to open, no second spin while it waits', function()
		local p = profile()
		X.tables(p.Data)
		-- a Cash wedge (r = 0: the first wedge)
		local ok, i, reward = X.spin(p, 0, T0)
		t.expect.truthy(ok)
		t.expect.equal(i, 1)
		t.expect.equal(p.Data.Cash, reward.Cash)
		t.expect.equal(p.Data.Spin.Spins, 1)
		local again, why = X.spin(p, 0, T0 + 5)
		t.expect.falsy(again)
		t.expect.equal(why, 'none')
		-- the box wedge: noted for the service to open after the wheel stops
		local boxAt
		for k, w in Rules.Wedges do if w.Box then boxAt = k end end
		local acc = 0
		for k = 1, boxAt - 1 do acc += Rules.Wedges[k].Weight end
		Rules.addSpins(p.Data.Spin, 2)
		local okBox, iBox, rBox = X.spin(p, (acc + 0.5) / 100, T0 + 6)
		t.expect.truthy(okBox)
		t.expect.equal(iBox, boxAt)
		t.expect.equal(p.Data.Spin.PendingBox, rBox.Box)
		t.expect.truthy(Shoes.BoxById[rBox.Box] ~= nil and not Shoes.BoxById[rBox.Box].Robux)
		local busy, whyBusy = X.spin(p, 0, T0 + 7)
		t.expect.falsy(busy)
		t.expect.equal(whyBusy, 'busy')
		-- the jackpot gives a spin back on top of its Cash
		p.Data.Spin.PendingBox = ''
		local cash = p.Data.Cash
		local extra = p.Data.Spin.Extra
		local okJ, _, rJ = X.spin(p, 0.9999, T0 + 8)
		t.expect.truthy(okJ)
		t.expect.truthy(rJ.Spins == 1 and rJ.Cash > 0)
		t.expect.equal(p.Data.Cash, cash + rJ.Cash)
		t.expect.equal(p.Data.Spin.Extra, extra - 1 + 1)
		-- a Boost wedge goes into the boost queue (StoreService publishes it)
		local p2 = profile()
		X.tables(p2.Data)
		local okB, iB = X.spin(p2, (Rules.Wedges[1].Weight + Rules.Wedges[2].Weight + 0.5) / 100, T0)
		t.expect.truthy(okB)
		t.expect.equal(Rules.Wedges[iB].Boost, 2)
		t.expect.equal((Boosts.running(p2.Data.Passes.Boost, T0 + 1)), 2)
	end)

	t.test('playtime: gifts open with this session\'s playtime; a short drop keeps the session, a long one starts again', function()
		local pt = Rules.sanitizePlaytime(nil)
		Rules.playtimeJoin(pt, T0)
		t.expect.equal(pt.Seconds, 0)
		local list, ready = Rules.playtimeState(pt)
		t.expect.equal(#list, #Rules.Gifts)
		t.expect.equal(ready, 0)
		t.expect.equal(list[1].Left, Rules.Gifts[1].Minutes * 60)
		for _ = 1, 5 do Rules.playtimeTick(pt, 60, T0) end
		t.expect.equal(pt.Seconds, 300)
		local _, ready5 = Rules.playtimeState(pt)
		t.expect.equal(ready5, 1)
		t.expect.falsy((Rules.takeGift(pt, 2)))
		local _, early = Rules.takeGift(pt, 2)
		t.expect.equal(early, 'early')
		t.expect.truthy((Rules.takeGift(pt, 1)))
		local _, taken = Rules.takeGift(pt, 1)
		t.expect.equal(taken, 'taken')
		t.expect.truthy(Rules.giftTaken(pt, 1))
		-- a tick never adds more than a minute (a hitch can't skip the clock)
		Rules.playtimeTick(pt, 5000, T0 + 300)
		t.expect.equal(pt.Seconds, 360)
		-- back after 5 minutes away: the same session; after 20: a new one
		Rules.playtimeJoin(pt, T0 + 300 + 5 * 60)
		t.expect.equal(pt.Seconds, 360)
		t.expect.truthy(Rules.giftTaken(pt, 1))
		Rules.playtimeJoin(pt, T0 + 300 + 5 * 60 + 20 * 60)
		t.expect.equal(pt.Seconds, 0)
		t.expect.falsy(Rules.giftTaken(pt, 1))
		-- junk
		t.expect.deepEqual(Rules.sanitizePlaytime({ Seconds = -1, Claimed = 1e9, LastSeen = 'x' }), { Seconds = 0, Claimed = 2 ^ #Rules.Gifts - 1, LastSeen = 0 })
	end)

	t.test('playtime gifts on a profile: paid once; the hour gift\'s box waits for its opening', function()
		local p = profile()
		X.tables(p.Data)
		X.playtimeJoin(p, T0)
		local okEarly = X.claimGift(p, 1, T0)
		t.expect.falsy(okEarly)
		p.Data.Playtime.Seconds = 3600
		local ok, r = X.claimGift(p, 1, T0)
		t.expect.truthy(ok)
		t.expect.equal(p.Data.Cash, r.Cash)
		t.expect.falsy((X.claimGift(p, 1, T0)))
		t.expect.equal(p.Data.Cash, r.Cash)
		local ok5, r5 = X.claimGift(p, 5, T0)
		t.expect.truthy(ok5)
		t.expect.equal(r5.Spins, 1)
		t.expect.equal(p.Data.Spin.Extra, 1)
		local ok6, r6 = X.claimGift(p, 6, T0)
		t.expect.truthy(ok6)
		t.expect.equal(p.Data.Spin.PendingBox, r6.Box)
		t.expect.truthy(p.Data.Rep >= r6.Power)
		t.expect.falsy((X.claimGift(p, 99, T0)))
	end)

	t.test('missions: three different tasks; counting, finishing, claiming and a new one in its place', function()
		local m = Rules.sanitizeMissions(nil)
		Rules.fillMissions(m, seq({ 1, 1, 1 }))
		t.expect.equal(#m.List, 3)
		local kinds = {}
		for _, task in m.List do
			t.expect.falsy(kinds[task.Kind])
			kinds[task.Kind] = true
			t.expect.equal(task.Have, 0)
			t.expect.equal(task.Goal, Rules.Tasks[task.Kind].Goals[1])
		end
		-- a map without shoe boxes never deals a box task
		local noBoxes = Rules.sanitizeMissions(nil)
		Rules.fillMissions(noBoxes, seq({ 3, 3, 3 }), function(kind) return kind ~= 'Boxes' end)
		for _, task in noBoxes.List do t.expect.truthy(task.Kind ~= 'Boxes') end
		-- counting: only that kind, capped at the goal, the finished index reported once
		local first = m.List[1]
		local done = Rules.countMission(m, first.Kind, first.Goal - 1)
		t.expect.equal(#done, 0)
		t.expect.equal(Rules.missionsReady(m), 0)
		done = Rules.countMission(m, first.Kind, 50)
		t.expect.equal(#done, 1)
		t.expect.equal(first.Have, first.Goal)
		t.expect.equal(#Rules.countMission(m, first.Kind, 5), 0)
		t.expect.equal(Rules.missionsReady(m), 1)
		t.expect.equal(#Rules.countMission(m, 'NoSuchKind', 5), 0)
		t.expect.equal(#Rules.countMission(m, first.Kind, -3), 0)
		-- an unfinished task can't be claimed
		local okNot, why = Rules.claimMission(m, 2)
		t.expect.falsy(okNot)
		t.expect.equal(why, 'notdone')
		-- text reads like the reference's tasks
		t.expect.equal(Rules.taskText('Goons', 20), 'Defeat 20 goons')
		t.expect.equal(Rules.taskText('Boxes', 1), 'Open a shoe box')
		t.expect.equal(Rules.taskText('Shots', 200), 'Shoot 200 times at a range')
		-- goals grow a little with the tasks done
		t.expect.equal(Rules.taskStep(0), 1)
		t.expect.equal(Rules.taskStep(6), 2)
		t.expect.equal(Rules.taskStep(999), 4)
		t.expect.truthy(Rules.taskReward('Goons', 3).Cash > Rules.taskReward('Goons', 1).Cash)
	end)

	t.test('missions on a profile: the claim pays, the task goes, a different one comes', function()
		local p = profile()
		X.tables(p.Data)
		Rules.fillMissions(p.Data.Missions, seq({ 1 }))
		local task = p.Data.Missions.List[1]
		local kind = task.Kind
		X.count(p, kind, task.Goal)
		local ok, r, claimedTask = X.claimMission(p, 1, T0, seq({ 1 }))
		t.expect.truthy(ok)
		t.expect.equal(claimedTask.Kind, kind)
		t.expect.equal(p.Data.Cash, r.Cash)
		t.expect.equal(p.Data.Missions.Done, 1)
		t.expect.equal(#p.Data.Missions.List, 3)
		for _, tk in p.Data.Missions.List do t.expect.truthy(tk.Kind ~= kind) end
		local again = X.claimMission(p, 3, T0, seq({ 1 }))
		t.expect.falsy(again)
	end)

	t.test('saves: old profiles get the extras, damaged ones are rebuilt, new ones validate', function()
		local fresh = S.new()
		t.expect.truthy(S.validate(fresh))
		t.expect.equal(fresh.StarterPack, false)
		t.expect.equal(type(fresh.Spin), 'table')
		-- a profile from before brief 30: none of the fields
		local old = S.new()
		old.Spin, old.Playtime, old.Missions, old.StarterPack = nil, nil, nil, nil
		local m = S.migrate(old)
		t.expect.truthy(S.validate(m))
		t.expect.deepEqual(m.Spin, Rules.SpinTemplate)
		t.expect.deepEqual(m.Playtime, Rules.PlaytimeTemplate)
		t.expect.equal(#m.Missions.List, 0)
		-- damaged fields are cleaned, never a reason to kick
		local bad = S.new()
		bad.Spin = 'oops'
		bad.Playtime = { Seconds = -50, Claimed = 'x' }
		bad.Missions = { Done = -1, List = { { Kind = 'Goons', Goal = 10, Have = 99, Step = 9 }, { Kind = 'Nope' }, 5, { Kind = 'Spins', Goal = 1, Have = 0 }, { Kind = 'Boxes', Goal = 1 }, { Kind = 'Shots', Goal = 2 } } }
		bad.StarterPack = 'yes'
		local b = S.migrate(bad)
		t.expect.truthy(S.validate(b))
		t.expect.equal(b.Playtime.Seconds, 0)
		t.expect.equal(#b.Missions.List, 3)
		t.expect.equal(b.Missions.List[1].Have, 10)
		t.expect.equal(b.Missions.List[1].Step, 4)
		t.expect.equal(b.Missions.Done, 0)
		t.expect.equal(b.StarterPack, false)
		-- the extras never leave the server in the public snapshot
		t.expect.equal(S.public(b).Spin, nil)
	end)

	t.test('products: the Starter Pack and 3 Spins exist, are wired, priced, and stay out of the Store list', function()
		local sp, pack = Products.ByKey.StarterPack, Products.ByKey.SpinPack
		t.expect.truthy(sp and pack)
		t.expect.equal(sp.Kind, 'Product')
		t.expect.equal(pack.Kind, 'Product')
		t.expect.truthy(sp.Wired and pack.Wired)
		t.expect.equal(sp.Price, 149)
		t.expect.equal(pack.Price, 39)
		t.expect.equal(Products.DeveloperProducts.StarterPack, 0)
		t.expect.equal(Products.DeveloperProducts.SpinPack, 0)
		for _, s in Products.Sections do
			t.expect.truthy(s.Id ~= sp.Section and s.Id ~= pack.Section)
		end
		t.expect.falsy(Products.giftable('StarterPack'))
		-- with no id yet it can't be prompted (the HUD says "coming soon")
		t.expect.falsy((Products.canBuy('StarterPack')))
	end)

	t.test('receipts: the Starter Pack grants Cash, 30 minutes of 2x Power and the world\'s cheapest Robux box, and marks it owned', function()
		local box = X.starterBox(Shoes, Shoes.ActiveWorld or 1)
		t.expect.truthy(box ~= nil and Shoes.BoxById[box].Robux ~= nil)
		for _, b in Shoes.boxesForWorld(Shoes.ActiveWorld or 1) do
			if b.Robux then t.expect.truthy(Shoes.BoxById[box].RobuxPrice <= b.RobuxPrice) end
		end
		local notices = {}
		local grants = Receipts.grants({ notice = function(_, text) table.insert(notices, text) end, now = function() return T0 end })
		local player = fakePlayer()
		local p = profile()
		local before = p.Data.Shoes.Opened or 0
		local ok, why = Receipts.apply(grants, player, p, 'StarterPack', 'buy-1')
		t.expect.truthy(ok)
		t.expect.equal(why, 'granted')
		local parts = X.starterParts(p, box)
		t.expect.equal(p.Data.Cash, parts.Cash)
		t.expect.equal(p.Data.StarterPack, true)
		t.expect.equal(player:GetAttribute('StarterOwned'), true)
		t.expect.equal(math.floor(Boosts.total(p.Data.Passes.Boost, T0) + 0.5), #parts.Boosts * parts.Seconds)
		t.expect.equal((p.Data.Shoes.Opened or 0) - before, Rules.Starter.Boxes)
		-- a retried receipt never grants twice
		local ok2, why2 = Receipts.apply(grants, player, p, 'StarterPack', 'buy-1')
		t.expect.truthy(ok2)
		t.expect.equal(why2, 'had')
		t.expect.equal(p.Data.Cash, parts.Cash)
		-- 3 Spins
		local okS = Receipts.apply(grants, player, p, 'SpinPack', 'buy-2')
		t.expect.truthy(okS)
		t.expect.equal(p.Data.Spin.Extra, Rules.Spin.PackSpins)
		t.expect.equal(player:GetAttribute('SpinExtra'), Rules.Spin.PackSpins)
		t.expect.truthy(#notices >= 2)
		-- the parts the card lists are the parts granted (Cash scales with the best stage like the Cash Packs)
		local far = profile()
		for i = 1, 8 do far.Data.ClearedWalls[i] = true end
		t.expect.truthy(X.starterParts(far, box).Cash > X.starterParts(profile(), box).Cash)
		t.expect.equal(RebirthRules.need(0) > 0, true)
	end)

	t.test('the goal line: every goal is one short line (the reference\'s "Hatch an egg"), its "where" kept for the goal list', function()
		local GoalRules = require(RS.Shared.GoalRules)
		for _, g in GoalRules.List do
			t.expect.truthy(#g.Text <= GoalRules.MaxText)
			t.expect.falsy(string.find(g.Text, '\n', 1, true))
			t.expect.truthy(type(g.Where) == 'string' and #g.Where > 0)
		end
	end)
end
