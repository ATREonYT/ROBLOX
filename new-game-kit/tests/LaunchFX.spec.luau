--!nonstrict
-- New Game Kit spec: LaunchFX pure maths (stretch, arc, landing time, trauma, tiers).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LaunchFX = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("LaunchFX"))

return function()
	describe("LaunchFX", function()
		it("stretches with speed, keeps volume, and caps the stretch", function()
			local z0, xy0 = LaunchFX.StretchFor(0)
			expect(z0).to.equal(1)
			expect(xy0).to.equal(1)
			local z, xy = LaunchFX.StretchFor(60)
			expect(z).to.be.near(1.5, 1e-9)
			expect(z * xy * xy).to.be.near(1, 1e-9)
			expect(LaunchFX.StretchFor(10000)).to.be.near(1 + LaunchFX.Recipe.maxStretch, 1e-9)
		end)
		it("predicts where an arc lands", function()
			local origin, vel = Vector3.new(0, 10, 0), Vector3.new(50, 60, 0)
			local t = LaunchFX.LandingTime(origin, vel, 0)
			expect(t ~= nil).to.equal(true)
			local hit = LaunchFX.Arc(origin, vel, t)
			expect(hit.Y).to.be.near(0, 1e-6)
			expect(hit.X).to.be.near(50 * t, 1e-6)
			expect(LaunchFX.LandingTime(Vector3.new(0, 0, 0), Vector3.new(1, 1, 0), 100)).to.equal(nil)
		end)
		it("shakes as trauma squared and decays to nothing", function()
			local tr = LaunchFX.Trauma.new(1, 2)
			tr:Add(0.5)
			expect(tr:Step(0)).to.be.near(2 * 0.25, 1e-9)
			tr:Add(5)
			expect(tr.value).to.equal(1)
			for _ = 1, 120 do
				tr:Step(1 / 60)
			end
			expect(tr:Step(1 / 60)).to.equal(0)
		end)
		it("grows every tier and keeps kid-safe caps", function()
			local order = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret" }
			local last
			for _, name in order do
				local t = LaunchFX.Tier(name)
				expect(t.shake <= 0.5).to.equal(true) -- never above a "Bump"
				expect(t.stop <= 0.12).to.equal(true)
				expect(1 + t.sparks + 1 + t.puffs + 22 < 100).to.equal(true) -- muzzle + landing particles
				if last then
					expect(t.power >= last.power).to.equal(true)
				end
				last = t
			end
			expect(LaunchFX.Tier("Nope")).to.equal(LaunchFX.Tiers.Common)
		end)
	end)
end
