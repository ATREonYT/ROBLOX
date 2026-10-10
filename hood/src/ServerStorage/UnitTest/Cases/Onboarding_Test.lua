-- The first-session guidance (HOOK, brief 23; Shared/OnboardingRules): the step machine a new player walks through
-- (Train, Door, Fight, Cash, Gift, Gun, Run, Done), the once-ever welcome gift, the quiet window (no automatic
-- purchase prompts for the first 5 minutes) and the saved fields inside the profile's Onboarding table.
return function(t)
	local RS = game:GetService('ReplicatedStorage')
	local R = require(RS.Shared.OnboardingRules)
	local Guns = require(RS.Shared.Config.Guns)
	local Shoes = require(RS.Shared.Config.Shoes)
	local Schema = require(game.ServerScriptService.HoodServer.ProfileSchema)

	t.test('a new player walks Train, Door, Fight, Cash, Gift, Gun, Run, then Done', function()
		local s = { Power = 0, Need = 10, Beaten = 0, WaveStage = 0, Guns = 1, Cash = 0 }
		t.expect.equal(R.step(s), 'Train')
		s.Power = 10
		t.expect.equal(R.step(s), 'Door')
		s.WaveStage, s.WaveLeft = 1, 3
		t.expect.equal(R.step(s), 'Fight')
		s.WaveLeft, s.RunCleared, s.Beaten = 0, 1, 1
		t.expect.equal(R.step(s), 'Cash')
		s.WaveStage, s.RunCleared, s.Cash = 0, 0, 40 -- (the pad took you home: the run ended)
		t.expect.equal(R.step(s), 'Gift')
		s.Gift, s.GunCost = true, 10
		t.expect.equal(R.step(s), 'Gun')
		s.Guns, s.GunCost = 2, 60
		t.expect.equal(R.step(s), 'Run')
		s.WaveStage, s.WaveLeft = 1, 3
		t.expect.equal(R.step(s), 'Done')
	end)

	t.test('the steps never stall: no pad, no Cash, a second stage, a rebirth, a saved Done', function()
		-- walked home without the pad: the gift still waits
		t.expect.equal(R.step({ Power = 30, Beaten = 1, WaveStage = 0 }), 'Gift')
		-- a gun you cannot afford yet is skipped: back out to run
		t.expect.equal(R.step({ Beaten = 1, Gift = true, Guns = 1, Cash = 5, GunCost = 10 }), 'Run')
		-- ran on into Stage 2: fight its crew, then its pad
		t.expect.equal(R.step({ Beaten = 1, WaveStage = 2, WaveLeft = 2, RunCleared = 1 }), 'Fight')
		t.expect.equal(R.step({ Beaten = 2, WaveStage = 2, WaveLeft = 0, RunCleared = 2 }), 'Cash')
		-- in a stage before the server counted its crew: a fight, never a pad
		t.expect.equal(R.step({ Power = 12, WaveStage = 1 }), 'Fight')
		t.expect.equal(R.step({ Rebirths = 1 }), 'Done')
		t.expect.equal(R.step({ Done = true, Power = 0 }), 'Done')
		t.expect.equal(R.step(nil), 'Train')
		t.expect.equal(R.step({ Power = 0 / 0, Need = 'x' }), 'Train')
		t.expect.equal(R.step({ Power = 9, Need = 0 }), 'Train') -- (an unknown need is Stage 1's 10)
	end)

	t.test('a returning player past the opening is a veteran: no guidance, no gift', function()
		t.expect.falsy(R.veteran({}))
		t.expect.falsy(R.veteran({ Stages = 1, Guns = 1 }))
		t.expect.truthy(R.veteran({ Rebirths = 1 }))
		t.expect.truthy(R.veteran({ Stages = 2 }))
		t.expect.truthy(R.veteran({ Beaten = 2 }))
		t.expect.falsy(R.veteran({ Beaten = 1 }))
		t.expect.truthy(R.veteran({ Guns = 2 }))
		t.expect.truthy(R.veteran({ Boxes = 1 }))
	end)

	t.test('the saved table is cleaned, keeps other keys and caps the clock', function()
		local ob = R.sanitize({ Gift = 'yes', Done = 1, Seconds = 0 / 0, Trained = true })
		t.expect.equal(ob.Gift, nil)
		t.expect.equal(ob.Done, nil)
		t.expect.equal(ob.Seconds, 0)
		t.expect.equal(ob.Trained, true)
		ob = R.sanitize({ Gift = true, Done = true, Seconds = 1e9 })
		t.expect.truthy(ob.Gift and ob.Done)
		t.expect.equal(ob.Seconds, R.MaxSeconds)
		t.expect.deepEqual(R.sanitize(nil), { Seconds = 0 })
		t.expect.equal(R.sanitize({ Seconds = -5 }).Seconds, 0)
	end)

	t.test('the quiet window is the first 300 s of play, counted and capped', function()
		t.expect.equal(R.QuietSeconds, 300)
		local ob = R.sanitize({})
		t.expect.truthy(R.quietFor(ob))
		R.tick(ob, 299)
		t.expect.truthy(R.quietFor(ob))
		R.tick(ob, 1)
		t.expect.falsy(R.quietFor(ob))
		R.tick(ob, -50)
		t.expect.equal(ob.Seconds, 300)
		R.tick(ob, 1e9)
		t.expect.equal(ob.Seconds, R.MaxSeconds)
		t.expect.falsy(R.quietFor(nil))
	end)

	t.test('quiet(player) reads only a real true OnboardingQuiet attribute', function()
		local p = Instance.new('Folder')
		t.expect.falsy(R.quiet(p))
		p:SetAttribute('OnboardingQuiet', true)
		t.expect.truthy(R.quiet(p))
		p:SetAttribute('OnboardingQuiet', 'true')
		t.expect.falsy(R.quiet(p))
		t.expect.falsy(R.quiet(nil))
		p:Destroy()
	end)

	t.test('the gift: 2 pairs from a real Cash box, waiting ahead of the spawn, opened within reach', function()
		local box = Shoes.BoxById[R.GiftBox]
		t.expect.truthy(box ~= nil and box.Price ~= nil and box.Robux == nil) -- (a Cash box: its normal odds, nothing paid)
		t.expect.equal(R.GiftCount, 2)
		local spawn = Vector3.new(2400, 0.4, 55)
		local at = R.giftSpot(spawn, CFrame.new(2400, 0, 0))
		t.expect.near((at - spawn).Magnitude, R.GiftOffset.Magnitude, 1e-4)
		t.expect.truthy(at.Z < spawn.Z) -- (ahead of you: the spawn faces -Z)
		t.expect.truthy(R.atGift(at + Vector3.new(3, 2.5, 0), at))
		t.expect.falsy(R.atGift(at + Vector3.new(6, 0, 0), at))
		t.expect.falsy(R.atGift(at + Vector3.new(0, 20, 0), at))
		t.expect.falsy(R.atGift(nil, at))
	end)

	t.test('the next gun is the cheapest priced one you do not own', function()
		local id, cost = R.nextGun(Guns.List, R.ownedSet('Pistol'))
		t.expect.equal(id, 'Revolver')
		t.expect.equal(cost, Guns.ById.Revolver.Cost)
		id = R.nextGun(Guns.List, R.ownedSet('Pistol,Revolver'))
		t.expect.equal(id, 'Uzi')
		local all = {}
		for _, g in Guns.List do all[g.Id] = true end
		t.expect.equal(R.nextGun(Guns.List, all), nil)
		t.expect.deepEqual(R.ownedSet({ 'Pistol', Uzi = true }), { Pistol = true, Uzi = true })
		t.expect.deepEqual(R.ownedSet(nil), {})
	end)

	t.test('one word per step, and the gun callout', function()
		for _, s in R.Steps do
			if s ~= 'Done' then
				local w = R.Words[s]
				t.expect.truthy(type(w) == 'string' and #w <= 8 and not w:find(' '))
			end
		end
		t.expect.equal(R.gunWord(2), 'x2 POWER!')
		t.expect.equal(R.gunWord(1), 'NEW GUN!')
		t.expect.equal(R.announce(nil, 'Train'), 'TRAIN!')
		t.expect.equal(R.announce('Train', 'Door'), 'GO!')
		t.expect.equal(R.announce('Door', 'Train'), nil) -- (no backwards nagging)
		t.expect.equal(R.announce('Cash', 'Fight'), 'FIGHT!') -- (every new fight)
		t.expect.equal(R.announce('Run', 'Done'), nil)
		t.expect.equal(R.announce('Gift', 'Gift'), nil)
	end)

	t.test('the timed hint fires only after 6 s without getting closer, then waits again', function()
		local tr = {}
		t.expect.falsy(R.stuck(tr, 30, 0))
		t.expect.falsy(R.stuck(tr, 29.5, 3)) -- (half a stud is not progress)
		t.expect.falsy(R.stuck(tr, 29.5, 5.9))
		t.expect.truthy(R.stuck(tr, 29.5, 6))
		t.expect.falsy(R.stuck(tr, 29.5, 8))
		t.expect.truthy(R.stuck(tr, 29.5, 12))
		t.expect.falsy(R.stuck(tr, 20, 12.5)) -- (walking on resets it)
		t.expect.falsy(R.stuck(tr, 20, 18))
		t.expect.falsy(R.stuck(nil, 1, 1))
		t.expect.truthy(R.StuckRepeats >= 1 and R.StuckRepeats <= 3) -- (the client caps the nudges per step)
	end)

	t.test('the saved fields ride in the existing Onboarding table: new and old profiles migrate and validate', function()
		local p = Schema.new()
		p.Onboarding = R.sanitize(p.Onboarding)
		p.Onboarding.Gift, p.Onboarding.Done = true, true
		R.tick(p.Onboarding, 42)
		Schema.migrate(p)
		t.expect.truthy(Schema.validate(p))
		t.expect.equal(p.Onboarding.Gift, true)
		t.expect.equal(p.Onboarding.Seconds, 42)
		t.expect.equal(Schema.public(p).Onboarding.Gift, true)
		-- an old save without the table gets an empty one, and the rules start it fresh
		local old = { Rep = 5, Cash = 7, SchemaVersion = 3 }
		Schema.migrate(old)
		t.expect.truthy(Schema.validate(old))
		local ob = R.sanitize(old.Onboarding)
		t.expect.equal(ob, old.Onboarding)
		t.expect.equal(ob.Gift, nil)
		t.expect.equal(ob.Seconds, 0)
		t.expect.truthy(Schema.validate(old))
	end)
end
