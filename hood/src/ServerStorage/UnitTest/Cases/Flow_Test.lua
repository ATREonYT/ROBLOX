-- (Oct 27, flow) The flow round's pure rules: the one moment queue, the tutorial's sequences and why lines, the quiet
-- tutorial goals, the first-join check and the tougher first crew.
return function(t)
	local RS = game:GetService('ReplicatedStorage')
	local MQ = require(RS.Shared.MomentQueue)
	local Tut = require(RS.Shared.TutorialRules)
	local Goals = require(RS.Shared.GoalRules)
	local Ob = require(RS.Shared.OnboardingRules)
	local E = require(RS.Shared.EnemyRules)

	t.test('the moment queue: one at a time, first come first served, a calm after each', function()
		t.expect.equal(MQ.gapAfter('small'), MQ.Gap); t.expect.equal(MQ.gapAfter('big'), MQ.BigGap); t.expect.equal(MQ.gapAfter(nil), MQ.BigGap)
		t.expect.truthy(MQ.Gap >= 1.5 and MQ.BigGap >= 2 and MQ.BigGap <= 3) -- (the owner's breathing room: 2-3 s after a big one)
		local w = { { Ready = false }, { Ready = true }, { Ready = true } }
		t.expect.equal(MQ.pick(w, { Active = false, Now = 10, CalmUntil = 9 }), 2) -- (the first that may start)
		t.expect.equal(MQ.pick(w, { Active = true, Now = 10, CalmUntil = 0 }), nil) -- (one on screen: none)
		t.expect.equal(MQ.pick(w, { Active = false, Now = 10, CalmUntil = 11 }), nil) -- (the calm: none)
		t.expect.equal(MQ.pick({}, { Active = false, Now = 10, CalmUntil = 0 }), nil)
		t.expect.equal(MQ.pick(w, nil), nil)
	end)

	t.test('the tutorial: BAY 1 says why Power matters and boxes the Power count; Gun and Run talk without arrows', function()
		local list, target = Tut.lines('Train', true, false)
		t.expect.equal(#list, 2); t.expect.equal(list[1].Text, Tut.Steps.Train.InLane); t.expect.equal(list[1].Box, 'Power'); t.expect.equal(Tut.lineOf(list[1].Text), list[1]); t.expect.equal(list[2], Tut.Why.Power); t.expect.equal(target, nil)
		t.expect.equal(list[2].Box, 'Power')
		list, target = Tut.lines('Train', false, false)
		t.expect.equal(#list, 1); t.expect.equal(target, 'Lane')
		list, target = Tut.lines('Gun')
		t.expect.equal(list[1], Tut.Why.Cash); t.expect.equal(target, nil)
		t.expect.truthy(Tut.plain(list[2].Text):find('ARMORY', 1, true) ~= nil)
		list = Tut.lines('Run'); t.expect.equal(#list, 1)
		t.expect.equal(#Tut.lines('Done'), 0); t.expect.equal(#Tut.lines(nil), 0)
		-- the why lines are honest about the game: Power beats crews (it opens no gate), Cash buys guns and boxes, a rebirth keeps them
		t.expect.truthy(Tut.plain(Tut.Why.Power.Text):lower():find('crew') ~= nil)
		t.expect.falsy(Tut.plain(Tut.Why.Power.Text):lower():find('gate'))
		t.expect.truthy(Tut.plain(Tut.Why.Cash.Text):lower():find('gun') ~= nil and Tut.plain(Tut.Why.Cash.Text):lower():find('box') ~= nil)
		t.expect.truthy(Tut.plain(Tut.Why.Keep.Text):lower():find('keep') ~= nil)
		t.expect.equal(Tut.Lesson.After.Before, 'Keep')
		-- a why line is read longer than a plain one before the next takes its place
		local why, plain = Tut.Why.Power.Text, Tut.Steps.Train.InLane
		t.expect.truthy(Tut.holdLeft(why, 0, 0) - select(2, Tut.plain(why)) / Tut.TypeRate > Tut.holdLeft(plain, 0, 0) - select(2, Tut.plain(plain)) / Tut.TypeRate)
		t.expect.equal(Tut.lineOf(why), Tut.Why.Power); t.expect.equal(Tut.lineOf('nope'), nil); t.expect.equal(Tut.lineOf(nil), nil)
		-- every line fits the hint (short)
		for _, l in Tut.Why do t.expect.truthy(#Tut.plain(l.Text) <= 40) end
		for _, ls in Tut.Talk do for _, l in ls do t.expect.truthy(#Tut.plain(l.Text) <= 40) end end
	end)

	t.test('the tutorial goals complete quietly; the first one is in Power, at the gate\'s Power', function()
		local quiet = {}
		for _, g in Goals.List do if g.Tutorial then quiet[g.Id] = true end end
		for _, id in { 'FreeRange', 'Stage1', 'Wave1', 'CashOut', 'Gun' } do t.expect.truthy(quiet[id]) end
		t.expect.falsy(quiet.CashOut2); t.expect.falsy(quiet.Rebirth1)
		t.expect.equal(Goals.List[1].Need.Power, Goals.FirstPower)
		t.expect.truthy(Goals.List[1].Text:find(tostring(Goals.FirstPower) .. ' Power', 1, true) ~= nil)
		t.expect.truthy(#Goals.List[1].Text <= Goals.MaxText)
	end)

	t.test('the welcome is for the very first join only', function()
		t.expect.truthy(Ob.firstJoin({}))
		t.expect.truthy(Ob.firstJoin(Ob.sanitize({})))
		t.expect.falsy(Ob.firstJoin({ Seconds = 3 }))
		t.expect.falsy(Ob.firstJoin({ Done = true }))
		t.expect.falsy(Ob.firstJoin({ Gift = true }))
		t.expect.falsy(Ob.firstJoin(nil))
	end)

	t.test('the first crew is a little tougher, the rest as before', function()
		t.expect.truthy(E.FirstCrewShots > E.HpShots)
		t.expect.truthy(E.maxHp(2, 'Goon') > E.maxHp(1, 'Goon'))
	end)
end
