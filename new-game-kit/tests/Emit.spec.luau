--!nonstrict
-- New Game Kit spec: Emit (effect timelines from attributes, flash and motion gates).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Emit = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("Emit"))

return function()
	describe("Emit.Plan", function()
		it("orders pieces by EmitDelay and reads counts", function()
			local root = Instance.new("Attachment")
			local smoke = Instance.new("ParticleEmitter")
			smoke.Name = "Smoke"
			smoke:SetAttribute("EmitDelay", 0.05)
			smoke:SetAttribute("EmitCount", 8)
			smoke.Parent = root
			local flash = Instance.new("ParticleEmitter")
			flash.Name = "Flash"
			flash:SetAttribute("EmitCount", 2)
			flash.Parent = root
			local sparks = Instance.new("ParticleEmitter")
			sparks.Name = "Sparks"
			sparks:SetAttribute("EmitDelay", 0.02)
			sparks.Parent = root
			local steps = Emit.Plan(root)
			expect(#steps).to.equal(3)
			expect(steps[1].instance.Name).to.equal("Flash")
			expect(steps[1].count).to.equal(2)
			expect(steps[2].instance.Name).to.equal("Sparks")
			expect(steps[2].count).to.equal(Emit.DEFAULT_COUNT)
			expect(steps[3].instance.Name).to.equal("Smoke")
		end)
		it("uses EmitDuration instead of a burst, and scales counts", function()
			local root = Instance.new("Attachment")
			local aura = Instance.new("ParticleEmitter")
			aura:SetAttribute("EmitDuration", 0.5)
			aura.Parent = root
			local burst = Instance.new("ParticleEmitter")
			burst:SetAttribute("EmitCount", 10)
			burst.Parent = root
			Emit.Scale = 0.5
			local steps = Emit.Plan(root)
			Emit.Scale = 1
			local byDuration = if steps[1].duration > 0 then steps[1] else steps[2]
			local byCount = if steps[1].duration > 0 then steps[2] else steps[1]
			expect(byDuration.count).to.equal(0)
			expect(byDuration.duration).to.equal(0.5)
			expect(byCount.count).to.equal(5)
		end)
	end)
	describe("Emit gates", function()
		it("allows at most one flash per second", function()
			Emit.ResetFlash()
			expect(Emit.TryFlash(10)).to.equal(true)
			expect(Emit.TryFlash(10.5)).to.equal(false)
			expect(Emit.TryFlash(11.01)).to.equal(true)
		end)
	end)
end
