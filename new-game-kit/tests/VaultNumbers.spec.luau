--!nonstrict
-- New Game Kit spec: the vault's numbers and the kit's code must agree.
-- If you change a timing in the code, change the note too (and the other way round).
-- Notes: 16 (cannon recipe), 17 §1-2 (measured reference, reveal ladder), 19 R1 (catch-up
-- hit-stop), repo CLAUDE.md (kid-safe caps).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Kit = ReplicatedStorage:WaitForChild("Kit")
local LaunchFX = require(Kit.LaunchFX)
local RareReveal = require(Kit.RareReveal)
local Spring = require(Kit.Spring)
local Emit = require(Kit.Emit)
local AnimeFX = require(Kit.AnimeFX)

local function near(a, b)
	return math.abs(a - b) < 1e-6
end

return function()
	describe("Vault numbers (notes 16, 17, 19)", function()
		it("a normal shot stays quiet, like the measured reference (note 17 §1)", function()
			local common = LaunchFX.Tiers.Common
			expect(common.shake).to.equal(0)
			expect(common.stop).to.equal(0)
			expect(common.fov).to.equal(0)
			expect(LaunchFX.Tiers.Rare.shake).to.equal(0)
		end)
		it("charge is 0.25-0.3 s and the FOV kick is 0.08 s (note 16 §4)", function()
			expect(LaunchFX.Recipe.chargeSeconds >= 0.25 and LaunchFX.Recipe.chargeSeconds <= 0.3).to.equal(true)
			expect(near(LaunchFX.Recipe.fovKickSeconds, 0.08)).to.equal(true)
		end)
		it("launch extras only grow with rarity and stay under the kid-safe caps", function()
			local previous
			for _, name in RareReveal.Order do
				local tier = LaunchFX.Tiers[name]
				expect(tier ~= nil).to.equal(true)
				expect(tier.shake <= 0.5).to.equal(true) -- never above a Bump
				expect(tier.stop <= 0.12).to.equal(true)
				expect(tier.sparks + tier.puffs <= 40).to.equal(true) -- about 100 live particles per shot
				if previous then
					expect(tier.power >= previous.power and tier.shake >= previous.shake).to.equal(true)
					expect(tier.stop >= previous.stop and tier.fov >= previous.fov).to.equal(true)
				end
				previous = tier
			end
		end)
		it("the reveal ladder lasts 0 / 0.6 / 1.2 / 2 / 3 / 4.5 s (note 17 §2)", function()
			local want = { Common = 0, Rare = 0.6, Epic = 1.2, Legendary = 2, Mythic = 3, Secret = 4.5 }
			for name, seconds in want do
				expect(near(RareReveal.Tiers[name].seconds, seconds)).to.equal(true)
				local _, length = RareReveal.Plan(name)
				expect(near(length, seconds)).to.equal(true)
			end
			expect(RareReveal.Tiers.Secret.skipAfter ~= nil).to.equal(true) -- the longest one can be skipped
		end)
		it("each rarer tier keeps every beat of the tier below and adds at least one", function()
			local below
			for _, name in RareReveal.Order do
				local beats = RareReveal.Plan(name)
				local kinds = {}
				for _, beat in beats do
					kinds[beat.kind] = true
					expect(beat.t >= 0).to.equal(true)
				end
				if below then
					local added = 0
					for kind in kinds do
						if not below[kind] then
							added += 1
						end
					end
					for kind in below do
						expect(kinds[kind]).to.equal(true)
					end
					if name ~= "Rare" then
						expect(added >= 1).to.equal(true)
					end
				end
				below = kinds
			end
		end)
		it("at most one flash per second (repo CLAUDE.md)", function()
			expect(Emit.FLASH_GAP >= 1).to.equal(true)
		end)
		it("hit-stop: none for light hits, catch-up length 0.03 + 0.045 x strength, capped (note 19 R1)", function()
			expect(AnimeFX.StopFor(0.3)).to.equal(0)
			expect(near(AnimeFX.StopFor(1), 0.075)).to.equal(true)
			expect(AnimeFX.StopFor(10) <= 0.12).to.equal(true)
			expect(AnimeFX.HitSizes.Light.stop).to.equal(0)
			for _, size in AnimeFX.HitSizes do
				expect(size.stop <= 0.12).to.equal(true)
			end
		end)
		it("springs settle in time: panels by 0.4 s (measured), cannon return under 0.45 s", function()
			local pop = Spring.Presets.Pop
			expect(Spring.SettleTime(pop.damping, pop.frequency, 0.02) <= 0.4).to.equal(true)
			local bouncy = Spring.Presets.Bouncy
			expect(Spring.SettleTime(bouncy.damping, bouncy.frequency, 0.05) <= 0.45).to.equal(true)
			local clean = Spring.Presets.Clean
			expect(Spring.SettleTime(clean.damping, clean.frequency, 0.02) <= 0.4).to.equal(true)
		end)
	end)
end
