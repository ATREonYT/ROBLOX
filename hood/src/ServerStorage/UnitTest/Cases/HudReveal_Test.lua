-- (Oct 27, round 8) The calm first screen: which HUD parts a player sees, from what they have done (Shared/HudReveal),
-- and the tutorial's YOU'RE READY! line (GoalRules.readyLine).
return function(t)
	local RS = game:GetService('ReplicatedStorage')
	local R = require(RS.Shared.HudReveal)
	local Goals = require(RS.Shared.GoalRules)

	t.test('first screen: a fresh kid sees none of the buttons or the Robux offers', function()
		local w = R.wants({ Cash = 0, CheapestBox = 50, Guns = 1, Power = 0, RebirthNeed = 100 })
		for _, p in R.All do t.expect.falsy(w[p]) end
		t.expect.equal(next(R.wants(nil)), nil)
	end)

	t.test('a returning player sees everything at once', function()
		local w = R.wants({ Returning = true })
		for _, p in R.All do t.expect.truthy(w[p]) end
	end)

	t.test('each button comes when it first matters', function()
		t.expect.truthy(R.wants({ Shoes = 1 }).Shoes) -- (the free gift's pair)
		t.expect.truthy(R.wants({ Unboxing = true }).Shoes) -- (the pair flies into it)
		t.expect.truthy(R.wants({ Cash = 50, CheapestBox = 50 }).Shoes) -- (the first box you can afford)
		t.expect.falsy(R.wants({ Cash = 49, CheapestBox = 50 }).Shoes)
		t.expect.falsy(R.wants({ Cash = 5 }).Shoes) -- (no box known: no claim)
		t.expect.truthy(R.wants({ Guns = 2 }).Skins); t.expect.falsy(R.wants({ Guns = 1 }).Skins)
		t.expect.truthy(R.wants({ RebirthReady = true }).Rebirth)
		t.expect.truthy(R.wants({ Power = 100, RebirthNeed = 100 }).Rebirth); t.expect.falsy(R.wants({ Power = 99, RebirthNeed = 100 }).Rebirth)
		t.expect.truthy(R.wants({ Rebirths = 1 }).Rebirth)
		t.expect.truthy(R.wants({ Passes = 1 }).Items); t.expect.truthy(R.wants({ Boosts = 1 }).Items)
		t.expect.falsy(R.wants({ Shoes = 3 }).Items) -- (during the tutorial a shoe alone doesn't bring Items)
		t.expect.truthy(R.wants({ Shoes = 3, TutorialDone = true }).Items)
	end)

	t.test('the Robux offers and Friend Boost wait for the end of the tutorial', function()
		local w = R.wants({ Shoes = 2, Guns = 2, Cash = 999, CheapestBox = 50 })
		for _, p in R.Offers do t.expect.falsy(w[p]) end
		w = R.wants({ TutorialDone = true })
		for _, p in R.Offers do t.expect.truthy(w[p]) end
		t.expect.truthy(R.wants({ Rebirths = 2 }).Offers)
		for _, p in R.Offers do t.expect.falsy(R.isButton(p)) end
		for _, p in R.Buttons do t.expect.truthy(R.isButton(p)) end
	end)

	t.test('shown parts stay; each one is new only once', function()
		local shown = {}
		local f = R.step(shown, { Shoes = 1 })
		t.expect.equal(#f, 1); t.expect.equal(f[1], 'Shoes')
		t.expect.equal(#R.step(shown, { Shoes = 1 }), 0)
		t.expect.equal(#R.step(shown, {}), 0); t.expect.truthy(shown.Shoes) -- (sold the pair: the button stays)
		f = R.step(shown, { Shoes = 1, Guns = 2, TutorialDone = true })
		t.expect.equal(f[1], 'Skins'); t.expect.equal(f[2], 'Items'); t.expect.equal(f[3], 'Offers') -- (the buttons first)
		t.expect.equal(#R.step(nil, { Returning = true }), 0)
	end)

	t.test("YOU'RE READY! says what's next: train and beat the next stage", function()
		t.expect.equal(Goals.readyLine(1), 'Next: train and beat Stage 2')
		t.expect.equal(Goals.readyLine(0), 'Next: train and beat Stage 2') -- (at least Stage 2: Stage 1 is the tutorial's)
		t.expect.equal(Goals.readyLine(nil), 'Next: train and beat Stage 2')
		t.expect.equal(Goals.readyLine(4), 'Next: train and beat Stage 5')
	end)
end
