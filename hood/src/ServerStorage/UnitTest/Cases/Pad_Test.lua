-- The two pads before every gate (brief 23, Shared/PadRules): the yellow Return pad pays +10 Cash at Stage 1 and more
-- every stage; the magenta pad pays 10x that with the 10x Cash pass; the labels read "+10 Cash / Return" and
-- "+100 Cash / 10x Cash" (with the pass's Robux price while you don't own it).
return function(t)
	local RS = game:GetService('ReplicatedStorage')
	local PadRules = require(RS.Shared.PadRules)
	local Balance = require(RS.Shared.Config.Balance)
	local Products = require(RS.Shared.Config.Products)

	t.test('the Return pad pays 10 at Stage 1 and more every stage, up to the boss yard', function()
		t.expect.equal(PadRules.reward(1, false), 10)
		t.expect.equal(PadRules.Stages, #Balance.StagePower) -- (one pad reward per stage, the boss yard included)
		local last = 0
		for s = 1, PadRules.Stages do
			local v = PadRules.reward(s, false)
			t.expect.truthy(v > last and v % 1 == 0)
			-- round numbers: two significant figures at most
			local digits = string.format('%d', v):gsub('0+$', '')
			t.expect.truthy(#digits <= 2)
			last = v
		end
	end)

	t.test('the 10x pad pays exactly ten times the Return pad', function()
		t.expect.equal(PadRules.TenX, 10)
		t.expect.equal(PadRules.reward(1, true), 100)
		for s = 1, PadRules.Stages do t.expect.equal(PadRules.reward(s, true), 10 * PadRules.reward(s, false)) end
	end)

	t.test('junk stages are clamped, never an error or a nil', function()
		t.expect.equal(PadRules.reward(0, false), PadRules.reward(1, false))
		t.expect.equal(PadRules.reward(-3, true), PadRules.reward(1, true))
		t.expect.equal(PadRules.reward(999, false), PadRules.reward(PadRules.Stages, false))
		t.expect.equal(PadRules.reward(2.7, false), PadRules.reward(2, false))
		t.expect.equal(PadRules.reward(0 / 0, false), 10)
		t.expect.equal(PadRules.reward('3', false), 10)
		t.expect.equal(PadRules.reward(nil, nil), 10)
		t.expect.equal(PadRules.reward(1, 'yes'), 10) -- (only a real true is the 10x pad)
	end)

	t.test('labels: "+10 Cash / Return" and "+100 Cash / 10x Cash", the Robux price only while you lack the pass', function()
		local big, small, price = PadRules.labels(1, 'Return')
		t.expect.equal(big, '+10 Cash'); t.expect.equal(small, 'Return'); t.expect.equal(price, nil)
		big, small, price = PadRules.labels(1, 'TenX', false)
		t.expect.equal(big, '+100 Cash'); t.expect.equal(small, '10x Cash')
		t.expect.equal(price, Products.RobuxMark .. Products.ByKey.TenXCash.Price)
		t.expect.equal(Products.RobuxMark, utf8.char(0xE002))
		big, small, price = PadRules.labels(1, 'TenX', true)
		t.expect.equal(big, '+100 Cash'); t.expect.equal(price, nil)
		t.expect.equal(PadRules.text(1500), '+1.5K Cash')
		t.expect.equal(PadRules.text(-5), '+0 Cash')
		t.expect.equal(Balance.CashName, 'Cash') -- (the currency's name lives in one place)
	end)

	t.test('the 10x Cash pass is a Store pass with an id slot; ownership is the Pass_TenXCash attribute', function()
		t.expect.equal(PadRules.Pass, 'TenXCash')
		local e = Products.ByKey.TenXCash
		t.expect.truthy(e ~= nil and e.Kind == 'Pass' and e.Section == 'Gamepass')
		t.expect.equal(type(Products.Passes.TenXCash), 'number')
		local p = Instance.new('Folder')
		t.expect.falsy(PadRules.owns(p))
		p:SetAttribute('Pass_TenXCash', true)
		t.expect.truthy(PadRules.owns(p))
		p:SetAttribute('Pass_TenXCash', 1)
		t.expect.falsy(PadRules.owns(p))
		p:Destroy()
		t.expect.falsy(PadRules.owns(nil))
		t.expect.falsy(PadRules.owns({ Pass_TenXCash = true }))
	end)
end
