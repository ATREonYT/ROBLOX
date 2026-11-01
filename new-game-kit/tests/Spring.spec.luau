--!nonstrict
-- New Game Kit spec: Spring (exact damped spring, presets, sampling).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spring = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("Spring"))

return function()
	describe("Spring", function()
		it("settles on the target for every damping kind", function()
			for _, d in { 0.3, 0.5, 1, 2 } do
				local s = Spring.new(0, d, 4)
				s:SetTarget(10)
				for _ = 1, 600 do
					s:Step(1 / 60)
				end
				expect(s.Value).to.be.near(10, 1e-3)
				expect(s:IsResting(1e-3)).to.equal(true)
			end
		end)
		it("overshoots below damping 1 and never above", function()
			local function peak(d)
				local s = Spring.new(0, d, 5)
				s:SetTarget(1)
				local top = 0
				for _ = 1, 300 do
					top = math.max(top, s:Step(1 / 60))
				end
				return top
			end
			expect(peak(0.5) > 1.1).to.equal(true)
			expect(peak(1) <= 1 + 1e-6).to.equal(true)
			expect(peak(2) <= 1 + 1e-6).to.equal(true)
		end)
		it("gives the same result at any frame rate", function()
			local a, b = Spring.new(0, 0.5, 5), Spring.new(0, 0.5, 5)
			a:SetTarget(3)
			b:SetTarget(3)
			for _ = 1, 30 do
				a:Step(1 / 30)
			end
			for _ = 1, 144 do
				b:Step(1 / 144)
			end
			expect(a.Value).to.be.near(b.Value, 1e-6)
		end)
		it("matches Sample, and an impulse moves it away then back", function()
			expect(Spring.Sample(0.5, 5, 0, 1, 0)).to.be.near(0, 1e-9)
			local s = Spring.new(0, 0.5, 5)
			s:SetTarget(1)
			s:Step(0.2)
			expect(s.Value).to.be.near(Spring.Sample(0.5, 5, 0, 1, 0.2), 1e-9)
			local r = Spring.fromPreset(0, "Bouncy")
			r:Impulse(-20)
			expect(r:Step(0.03) < 0).to.equal(true)
			for _ = 1, 120 do
				r:Step(1 / 60)
			end
			expect(r.Value).to.be.near(0, 1e-3)
		end)
		it("works on Vector3 and reports a settle time", function()
			local s = Spring.new(Vector3.new(0, 0, 0), 1, 4)
			s:SetTarget(Vector3.new(1, 2, 3))
			for _ = 1, 240 do
				s:Step(1 / 60)
			end
			expect((s.Value - Vector3.new(1, 2, 3)).Magnitude < 1e-3).to.equal(true)
			local t = Spring.SettleTime(0.5, 5)
			expect(t > 0.2 and t < 1).to.equal(true)
		end)
	end)
end
