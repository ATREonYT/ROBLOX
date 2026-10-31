--!nonstrict
-- New Game Kit spec: Offers (price ladders, real earnings, A/B buckets, offer pacing).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Offers = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("Offers"))

return function()
	describe("Offers", function()
		it("labels a fair ladder from the real numbers (note 21 §2)", function()
			local labels = Offers.Ladder({
				{ key = "Small", amount = 100, price = 99 },
				{ key = "Medium", amount = 600, price = 449 },
				{ key = "Large", amount = 1300, price = 899 },
				{ key = "Huge", amount = 3000, price = 1999 },
			})
			expect(labels.Small).to.equal(0)
			expect(labels.Medium).to.equal(32)
			expect(labels.Large).to.equal(43)
			expect(labels.Huge).to.equal(49)
		end)
		it("refuses a bigger pack that is worse value", function()
			local ok = pcall(Offers.Ladder, {
				{ key = "Small", amount = 100, price = 99 },
				{ key = "Big", amount = 450, price = 499 },
			})
			expect(ok).to.equal(false)
		end)
		it("refuses a top pack that jumps more than the one below", function()
			local ok = pcall(Offers.Ladder, {
				{ key = "A", amount = 100, price = 100 },
				{ key = "B", amount = 220, price = 200 },
				{ key = "C", amount = 600, price = 300 },
			})
			expect(ok).to.equal(false)
		end)
		it("counts 70% and regional prices", function()
			expect(Offers.NetRobux(100)).to.equal(70)
			expect(Offers.NetRobux(499, 0.7, 0.6)).to.equal(307)
		end)
		it("gives each player the same bucket every time", function()
			local a = Offers.Bucket(12345, "starter_timing")
			expect(a).to.equal(Offers.Bucket(12345, "starter_timing"))
			expect(a >= 0 and a < 100).to.equal(true)
		end)
		it("keeps unasked offers rare and polite (note 21 §4)", function()
			local s = { firstSession = true, sessionStart = 0, isPayer = false, shownThisSession = 0 }
			expect((Offers.CanShow(s, 60))).to.equal(false)
			expect((Offers.CanShow(s, 200))).to.equal(true)
			s.shownThisSession, s.lastShown = 1, 200
			local ok, why = Offers.CanShow(s, 205)
			expect(ok).to.equal(false)
			expect(why).to.equal("TooSoon")
			ok, why = Offers.CanShow(s, 900)
			expect(why).to.equal("SessionCap")
			s.isPayer = true
			s.lastDeclined = 850
			ok, why = Offers.CanShow(s, 900)
			expect(why).to.equal("JustDeclined")
			expect((Offers.CanShow(s, 1500))).to.equal(true)
		end)
	end)
end
