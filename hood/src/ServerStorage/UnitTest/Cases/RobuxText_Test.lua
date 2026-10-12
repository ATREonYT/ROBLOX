-- (brief 31, ROBUX) Shared/RobuxText: every Robux price wears the Robux sign (U+E002) right before the number, with the
-- reference's thousands separators ("⬡1,499"), and it is the same sign RebirthRules / PadRules / Products use.
return function(t)
	local RS = game:GetService('ReplicatedStorage')
	local RobuxText = require(RS.Shared.RobuxText)
	local Products = require(RS.Shared.Config.Products)
	local RebirthRules = require(RS.Shared.RebirthRules)

	t.test('fmt puts the Robux sign before the number, with thousands separators', function()
		t.expect.equal(RobuxText.Mark, utf8.char(0xE002))
		t.expect.equal(RobuxText.fmt(79), '\u{E002}79')
		t.expect.equal(RobuxText.fmt(999), '\u{E002}999')
		t.expect.equal(RobuxText.fmt(1499), '\u{E002}1,499')
		t.expect.equal(RobuxText.fmt(1000000), '\u{E002}1,000,000')
		t.expect.equal(RobuxText.fmt(0), '\u{E002}0')
		t.expect.equal(RobuxText.fmt('249'), '\u{E002}249')
		t.expect.equal(RobuxText.commas(12345), '12,345')
		t.expect.equal(RobuxText.commas(99.6), '100')
		t.expect.equal(RobuxText.commas('?'), '?')
	end)

	t.test('one sign everywhere: Products, RebirthRules and the Grail Bundle price', function()
		t.expect.equal(Products.RobuxMark, RobuxText.Mark)
		t.expect.equal(RebirthRules.RobuxMark, RobuxText.Mark)
		t.expect.equal(RobuxText.fmt(Products.GrailBundlePrice), '\u{E002}1,499')
	end)
end
