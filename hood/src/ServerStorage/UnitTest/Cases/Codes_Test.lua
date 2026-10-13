-- (brief 27, INV3D) The Store's Codes box: HoodServer/Codes (the list and the rules CodesService runs), the profile's
-- Codes field (HoodServer/ProfileSchema) and the RedeemCode remote. Each code gives one small gift, once per player.
return function(t)
	local HS = game.ServerScriptService.HoodServer
	local Codes = require(HS.Codes)
	local Boosts = require(HS.Boosts)
	local Schema = require(HS.ProfileSchema)
	local e = t.expect
	local NOW = 1760000000

	t.test('every code is clean, unique and a small one-time gift of Cash or a boost', function()
		e.truthy(#Codes.List >= 3)
		local seen = {}
		for _, c in Codes.List do
			e.equal(Codes.normalize(c.Code), c.Code)
			e.falsy(seen[c.Code])
			seen[c.Code] = true
			local cash, boost = type(c.Cash) == 'number', type(c.Boost) == 'number'
			e.truthy(cash ~= boost) -- (one gift, never both)
			if cash then e.truthy(c.Cash > 0 and c.Cash <= Codes.MaxCash and c.Cash % 1 == 0) end
			if boost then
				e.truthy(c.Boost >= 2 and c.Boost <= 3 and c.Boost % 1 == 0)
				e.truthy(type(c.Minutes) == 'number' and c.Minutes > 0 and c.Minutes <= Codes.MaxMinutes)
			end
			e.equal(Codes.ByCode[c.Code], c)
		end
		-- the answers are short, friendly lines (no pressure words, nothing scary)
		for _, line in Codes.Text do
			e.truthy(type(line) == 'string' and #line > 0 and #line <= 48)
			for _, bad in { 'limited', 'hurry', 'last chance', 'stupid', 'wrong!' } do e.falsy(string.find(string.lower(line), bad, 1, true)) end
		end
	end)

	t.test('a typed code is matched in any case, with spaces or dashes; junk is refused without a lookup', function()
		e.equal(Codes.normalize('hoodlaunch'), 'HOODLAUNCH')
		e.equal(Codes.normalize('  Hood Launch '), 'HOODLAUNCH')
		e.equal(Codes.normalize('hood-launch'), 'HOODLAUNCH')
		e.equal(Codes.normalize(''), nil)
		e.equal(Codes.normalize('   '), nil)
		e.equal(Codes.normalize(string.rep('A', Codes.MaxLength + 1)), nil)
		e.equal(Codes.normalize('HOOD!'), nil)
		e.equal(Codes.normalize('héllo'), nil)
		e.equal(Codes.normalize(42), nil)
		e.equal(Codes.normalize({}), nil)
	end)

	t.test('a Cash code adds its Cash once; the second try changes nothing', function()
		local data = Schema.new()
		data.Cash = 100
		local ok, text, change = Codes.redeem(data, 'hoodlaunch', NOW, Boosts.add)
		e.truthy(ok)
		e.equal(data.Cash, 100 + Codes.ByCode.HOODLAUNCH.Cash)
		e.equal(change.Cash, Codes.ByCode.HOODLAUNCH.Cash)
		e.truthy(string.find(text, 'Cash', 1, true))
		e.equal(data.Codes.HOODLAUNCH, NOW)
		local ok2, text2 = Codes.redeem(data, 'HOOD LAUNCH', NOW + 60, Boosts.add)
		e.falsy(ok2)
		e.equal(text2, Codes.Text.used)
		e.equal(data.Cash, 100 + Codes.ByCode.HOODLAUNCH.Cash)
		e.equal(data.Codes.HOODLAUNCH, NOW)
	end)

	t.test('a boost code queues its timed boost once (HoodServer/Boosts), kept in the profile', function()
		local data = Schema.new()
		local code
		for _, c in Codes.List do if c.Boost then code = c; break end end
		e.truthy(code ~= nil)
		local ok, text, change = Codes.redeem(data, string.lower(code.Code), NOW, Boosts.add)
		e.truthy(ok)
		e.truthy(string.find(text, 'Power', 1, true))
		e.equal(change.Boost, code.Boost)
		local level, ends = Boosts.running(data.Passes.Boost, NOW)
		e.equal(level, code.Boost)
		e.equal(ends, NOW + code.Minutes * 60)
		local ok2 = Codes.redeem(data, code.Code, NOW + 1, Boosts.add)
		e.falsy(ok2)
		e.equal(Boosts.total(data.Passes.Boost, NOW), code.Minutes * 60)
	end)

	t.test('unknown, switched-off, ended and empty codes give a kind answer and change nothing', function()
		local data = Schema.new()
		data.Cash = 50
		local before = Codes.sanitize(data.Codes)
		for _, typed in { 'NOTACODE', 'h@ck', string.rep('B', 200) } do
			local ok, text = Codes.redeem(data, typed, NOW, Boosts.add)
			e.falsy(ok)
			e.equal(text, Codes.Text.unknown)
		end
		local ok, text = Codes.redeem(data, '   ', NOW, Boosts.add)
		e.falsy(ok)
		e.equal(text, Codes.Text.empty)
		local okN = Codes.redeem(data, nil, NOW, Boosts.add)
		e.falsy(okN)
		-- a code past its end, and one switched off
		Codes.ByCode.ZZTESTENDED = { Code = 'ZZTESTENDED', Cash = 10, Ends = NOW - 1 }
		Codes.ByCode.ZZTESTOFF = { Code = 'ZZTESTOFF', Cash = 10, Off = true }
		local okE, textE = Codes.redeem(data, 'zztestended', NOW, Boosts.add)
		local okO, textO = Codes.redeem(data, 'zztestoff', NOW, Boosts.add)
		Codes.ByCode.ZZTESTENDED, Codes.ByCode.ZZTESTOFF = nil, nil
		e.falsy(okE)
		e.equal(textE, Codes.Text.ended)
		e.falsy(okO)
		e.equal(textO, Codes.Text.unknown)
		e.equal(data.Cash, 50)
		e.deepEqual(Codes.sanitize(data.Codes), before)
	end)

	t.test('the profile keeps the used codes: new and old saves get the field, damaged ones are cleaned, bad ones fail', function()
		local fresh = Schema.new()
		e.equal(type(fresh.Codes), 'table')
		e.equal(next(fresh.Codes), nil)
		e.truthy(Schema.validate(fresh))
		-- a save from before codes (no field) keeps everything and gains an empty table
		local old = Schema.new()
		old.Codes = nil
		old.Cash = 777
		Schema.migrate(old)
		e.equal(old.Cash, 777)
		e.equal(type(old.Codes), 'table')
		e.truthy(Schema.validate(old))
		-- a damaged table is cleaned, not a reason to kick
		local damaged = Schema.new()
		damaged.Codes = { HOODLAUNCH = NOW, bad = true, [5] = NOW, ['lower'] = NOW, NAN = 0 / 0 }
		Schema.migrate(damaged)
		e.equal(damaged.Codes.HOODLAUNCH, NOW)
		e.equal(damaged.Codes.bad, nil)
		e.equal(damaged.Codes[5], nil)
		e.equal(damaged.Codes.lower, nil)
		e.equal(damaged.Codes.NAN, nil)
		e.truthy(Schema.validate(damaged))
		local broken = Schema.new()
		broken.Codes = 'oops'
		Schema.migrate(broken)
		e.deepEqual(broken.Codes, {})
		-- validate fails closed on a bad value written after load
		local bad = Schema.new()
		bad.Codes.HOODLAUNCH = 'yes'
		e.throws(function() Schema.validate(bad) end)
		-- the used codes never go to the client
		e.equal(Schema.public(fresh).Codes, nil)
		-- at most Codes.Kept are remembered, newest kept
		local many = {}
		for i = 1, Codes.Kept + 20 do many['C' .. i] = i end
		local kept = Codes.sanitize(many)
		local n = 0
		for _ in kept do n += 1 end
		e.equal(n, Codes.Kept)
		e.equal(kept['C' .. (Codes.Kept + 20)], Codes.Kept + 20)
		e.equal(kept.C1, nil)
	end)

	t.test('a redeemed code survives a save and a load: one time is enforced across sessions', function()
		local data = Schema.new()
		e.truthy(Codes.redeem(data, 'BLOCKPARTY', NOW, Boosts.add))
		local cash = data.Cash
		-- (a save round trip: what ProfileStore keeps, then the load path's migrate + validate)
		local function copy(v)
			if type(v) ~= 'table' then return v end
			local out = {}
			for k, x in v do out[k] = copy(x) end
			return out
		end
		local loaded = copy(data)
		Schema.migrate(loaded)
		Schema.validate(loaded)
		local ok, text = Codes.redeem(loaded, 'blockparty', NOW + 86400, Boosts.add)
		e.falsy(ok)
		e.equal(text, Codes.Text.used)
		e.equal(loaded.Cash, cash)
	end)

	t.test('the RedeemCode remote is a RemoteFunction the Store can call', function()
		local Net = require(game.ReplicatedStorage.Shared.Net)
		-- (Net.get asserts the name is defined; offline there is no HoodNet folder, so only that assert is checked)
		local ok, err = pcall(Net.get, 'RedeemCode')
		e.truthy(ok or not string.find(tostring(err), 'Unknown remote', 1, true))
		local okBad, errBad = pcall(Net.get, 'NoSuchRemote')
		e.falsy(okBad)
		e.truthy(string.find(tostring(errBad), 'Unknown remote', 1, true))
		local folder = game.ReplicatedStorage:FindFirstChild('HoodNet')
		local remote = folder and folder:FindFirstChild('RedeemCode')
		if remote then e.equal(remote.ClassName, 'RemoteFunction') end
		e.truthy(HS:FindFirstChild('CodesService') ~= nil)
	end)
end
