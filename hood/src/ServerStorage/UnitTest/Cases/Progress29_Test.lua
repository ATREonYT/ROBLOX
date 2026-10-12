-- Brief 29, P4 (progression, tutorial, optional activity): levels as a curve over Power, ranks tied to the best level,
-- the safe BestLevel migration, every shot paying a little, the Hot Target caps (the tutorial: Tutorial30_Test).
return function(t)
	local RS = game:GetService('ReplicatedStorage')
	local L = require(RS.Shared.LevelRules)
	local Balance = require(RS.Shared.Config.Balance)
	local Rebirth = require(RS.Shared.RebirthRules)
	local ShotRules = require(RS.Shared.ShotRules)
	local Goals = require(RS.Shared.GoalRules)
	local Hot = require(RS.Shared.HotTargetRules)
	local Schema = require(game.ServerScriptService.HoodServer.ProfileSchema)

	t.test('a level is a curve over Power: 1.5x more Power is one more level, the first shot is already Level 2', function()
		t.expect.equal(L.levelOf(0), 1); t.expect.equal(L.levelOf(1), 2); t.expect.equal(L.levelOf(2), 3); t.expect.equal(L.levelOf(10), 6)
		t.expect.equal(L.levelOf(-5), 1); t.expect.equal(L.levelOf(0 / 0), 1); t.expect.equal(L.levelOf('9'), 1); t.expect.equal(L.levelOf(math.huge), 1)
		t.expect.equal(L.levelOf(1e12), 69); t.expect.equal(L.levelOf(1e15), L.MaxLevel)
		local last = -1
		for l = 1, L.MaxLevel do
			t.expect.truthy(L.Thresholds[l] > last); last = L.Thresholds[l]
			t.expect.equal(L.levelOf(L.powerFor(l)), l) -- (a level starts exactly at its threshold)
			if l > 1 then t.expect.equal(L.levelOf(L.powerFor(l) - 1), l - 1) end
		end
		for l = 8, 40 do -- (about 1.5x a level, two significant figures from 100 up)
			local ratio = L.Thresholds[l + 1] / L.Thresholds[l]
			t.expect.truthy(ratio > 1.3 and ratio < 1.7)
		end
	end)

	t.test('the bar: into / span / fraction of the level, full at the top', function()
		local level, into, span, frac, maxed = L.progress(0)
		t.expect.equal(level, 1); t.expect.equal(into, 0); t.expect.equal(span, 1); t.expect.equal(frac, 0); t.expect.falsy(maxed)
		level, into, span, frac = L.progress(8) -- Level 6 starts at 7, Level 7 at 11
		t.expect.equal(level, 6); t.expect.equal(into, 1); t.expect.equal(span, 4); t.expect.near(frac, 0.25)
		level, into, span, frac, maxed = L.progress(1e15)
		t.expect.equal(level, L.MaxLevel); t.expect.equal(frac, 1); t.expect.truthy(maxed)
		t.expect.equal(select(4, L.progress('x')), 0)
	end)

	t.test('stage gates and rebirths read sensibly as levels: they only climb, stage 1 is Level 6, the first rebirth Level 16', function()
		local last = 0
		for s = 1, #Balance.StagePower do
			local lv = L.stageLevel(s)
			t.expect.truthy(lv >= last); last = lv
			t.expect.equal(lv, L.levelOf(Balance.StagePower[s]))
		end
		t.expect.equal(L.stageLevel(1), 6); t.expect.equal(L.stageLevel(4), 15); t.expect.equal(L.stageLevel(16), 44)
		t.expect.equal(L.rebirthLevel(0), 16); t.expect.equal(L.rebirthLevel(13), 49)
		for s = 1, 4 do t.expect.truthy(L.stageLevel(s) <= L.rebirthLevel(0)) end -- (stages 1-4 come before the first rebirth)
		local rl = 0
		for n = 0, 20 do local v = L.rebirthLevel(n); t.expect.truthy(v >= rl); rl = v end
		t.expect.equal(L.stageLevel(0), L.stageLevel(1)); t.expect.equal(L.stageLevel(99), L.stageLevel(16)) -- (junk is clamped)
	end)

	t.test('the goal chain speaks in Levels but still needs Power', function()
		local first = Goals.List[1]
		t.expect.equal(first.Text, 'Reach Level 6 in BAY 1'); t.expect.equal(first.Need.Power, 7) -- (Level 6 starts at 7 Power; the Stage 1 gate's own Required stays 10)
		t.expect.truthy(string.find(Goals.List[9].Where, 'Level bar', 1, true) ~= nil)
	end)

	t.test('ranks follow the best level, only go up, and pay once', function()
		t.expect.equal(#L.Ranks, 8)
		t.expect.equal(L.rankOf(1).Name, 'Rookie'); t.expect.equal(L.rankOf(9).Name, 'Rookie'); t.expect.equal(L.rankOf(10).Name, 'Street Kid')
		t.expect.equal(L.rankOf(16).Name, 'Hustler'); t.expect.equal(L.rankOf(46).Name, 'Legend'); t.expect.equal(L.rankOf(999).Name, 'Legend')
		t.expect.equal(L.rankOf(nil).Name, 'Rookie'); t.expect.equal(L.rankIndex(0 / 0), 1)
		t.expect.equal(L.nextRank(46), nil); t.expect.equal(L.nextRank(1).Name, 'Street Kid')
		local prev = 0
		for _, r in L.Ranks do t.expect.truthy(r.Level > prev); prev = r.Level end
		t.expect.equal(L.Ranks[1].Cash, 0)
		t.expect.equal(#L.ranksCrossed(1, 9), 0); t.expect.equal(L.ranksCrossed(9, 10)[1], 2)
		local many = L.ranksCrossed(1, 30); t.expect.equal(#many, 4); t.expect.equal(many[4], 5) -- (a big jump crosses every rank on the way)
		t.expect.equal(#L.ranksCrossed(30, 20), 0) -- (never down)
		t.expect.equal(L.tag(16, 440), 'Hustler  Lv 16')
		-- every rank is reached inside World 1 (the 14 rebirths): rebirth 13 asks for Level 49
		t.expect.truthy(L.rebirthLevel(13) >= L.Ranks[#L.Ranks].Level)
		-- and the first rank-up (Level 10) is early, the second (Level 16) is where the first rebirth is
		t.expect.truthy(L.powerFor(10) <= 40); t.expect.truthy(L.powerFor(16) <= Rebirth.need(0))
	end)

	t.test('BestLevel is safe: filled for old profiles, never lowered, validated', function()
		local fresh = Schema.new(); t.expect.equal(fresh.BestLevel, 1); t.expect.truthy(Schema.validate(fresh))
		-- a profile from before it (the Rebirth test's shape): Power 50000 and 2 rebirths -> the level the 2nd rebirth needed or more
		local old = { SchemaVersion = 3, Rep = 50000, Cash = 12, Rebirths = 2, EquippedSkin = 'Kingpin' }
		Schema.migrate(old)
		t.expect.equal(old.Rep, 50000); t.expect.equal(old.Cash, 12); t.expect.equal(old.Rebirths, 2)
		t.expect.equal(old.BestLevel, L.levelOf(50000)); t.expect.truthy(Schema.validate(old))
		local reborn = { SchemaVersion = 4, Rep = 0, Rebirths = 3 }; Schema.migrate(reborn)
		t.expect.equal(reborn.BestLevel, L.rebirthLevel(2)) -- (Power reset by the rebirth, the rank stays)
		local saved = Schema.new(); saved.BestLevel = 30; saved.Rep = 5; Schema.migrate(saved)
		t.expect.equal(saved.BestLevel, 30) -- (never lowered)
		local junk = Schema.new(); junk.BestLevel = 'x'; Schema.migrate(junk); t.expect.equal(junk.BestLevel, 1); t.expect.truthy(Schema.validate(junk))
		local bad = Schema.new(); bad.BestLevel = 1.5; t.expect.throws(function() Schema.validate(bad) end)
		local huge = Schema.new(); huge.BestLevel = L.MaxLevel + 1; t.expect.throws(function() Schema.validate(huge) end)
		t.expect.equal(Schema.public(saved).BestLevel, 30)
		-- the save keeps everything else as it was
		local p = Schema.new(); p.Rep = 1234; p.Cash = 99; Schema.migrate(p); t.expect.equal(p.Rep, 1234); t.expect.equal(p.Cash, 99)
	end)

	t.test('every shot pays a little, less than a range: half of a x1 shot, the first one always pays, fractions carry', function()
		t.expect.truthy(ShotRules.EnemyShare < 1 and ShotRules.EnemyShare > 0); t.expect.truthy(ShotRules.FreeShare < 1)
		local carry, got = {}, {}
		for i = 1, 6 do got[i] = ShotRules.share(1, 0.5, carry, 'Enemy') end
		t.expect.equal(table.concat(got, ','), '1,0,1,0,1,0')
		local sum = 0
		local c2 = {}
		for _ = 1, 100 do sum += ShotRules.share(3, ShotRules.EnemyShare, c2, 'Enemy') end
		t.expect.equal(sum, 150) -- (exact over time: 100 shots of 3 at half)
		t.expect.equal(ShotRules.share(4, 0.5, nil), 2); t.expect.equal(ShotRules.share(0, 0.5, {}), 0); t.expect.equal(ShotRules.share(0 / 0, 0.5, {}), 0)
		-- clearly less than a range: BAY 1 pays the whole x1 shot at 5 shots a second; the share is half of it, other lanes more
		t.expect.truthy(ShotRules.share(1, ShotRules.FreeShare, {}, 'Free') <= 1)
		local lane4 = ShotRules.pay(ShotRules.perShot(4, 0), 1, 1)
		t.expect.truthy(lane4 > 2 * ShotRules.EnemyShare * ShotRules.pay(ShotRules.perShot(1, 0), 1, 1))
		-- the click limit: a burst, then the refill rate
		local bucket, now, paid = {}, 100, 0
		for _ = 1, 20 do if ShotRules.take(bucket, now) then paid += 1 end end
		t.expect.equal(paid, ShotRules.Burst)
		t.expect.truthy(ShotRules.take(bucket, now + 1)); t.expect.falsy(ShotRules.take(0 / 0 and nil, 0))
	end)

	-- (brief 30: the tutorial's tests are Tutorial30_Test now, with its new rules)

	t.test('the optional Hot Target is capped hard and is a small bonus', function()
		local state, now, ok = {}, 10, 0
		for i = 1, 50 do if Hot.take(state, now + i * 0.7) then ok += 1 end end
		t.expect.equal(ok, Hot.PerMinute) -- (50 taps in 35 s: 20 count)
		t.expect.falsy(Hot.take(state, now + 36)); t.expect.equal(Hot.left(state, now + 36), 0)
		t.expect.truthy(Hot.take(state, now + 80)); -- (a minute later it counts again)
		local quick = {}; t.expect.truthy(Hot.take(quick, 1)); t.expect.falsy(Hot.take(quick, 1.2)); t.expect.truthy(Hot.take(quick, 1.7)) -- (MinGap)
		t.expect.falsy(Hot.take(nil, 1))
		t.expect.equal(Hot.boost(0, 100), 1); t.expect.equal(Hot.boost(200, 100), 2); t.expect.equal(Hot.boost(100, 100), 1); t.expect.equal(Hot.boost('x', 5), 1)
		t.expect.equal(Hot.gain(5, 1), 10); t.expect.equal(Hot.gain(5, 2), 20); t.expect.equal(Hot.gain(5, 99), 20); t.expect.equal(Hot.gain(-3, 1), 0)
		-- never more than 40 shots' worth a minute against the range's 300 (5 a second): a pastime, not a way to play
		t.expect.truthy(Hot.PerMinute * Hot.Shots <= 0.15 * 60 * ShotRules.AutoRate)
		t.expect.equal(Hot.BoostSeconds, 600)
	end)
end
