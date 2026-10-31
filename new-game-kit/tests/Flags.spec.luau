--!nonstrict
-- New Game Kit spec: Flags (kill switches: live attribute, then config default, then on).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Flags = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("Flags"))

return function()
	describe("Flags", function()
		it("is on with no flag, follows the default, and the live switch wins", function()
			Flags.SetDefaults({ Beta = false })
			expect(Flags.On("Anything")).to.equal(true)
			expect(Flags.On("Beta")).to.equal(false)
			Flags.Set("Beta", true)
			expect(Flags.On("Beta")).to.equal(true)
			Flags.Set("Anything", false)
			expect(Flags.On("Anything")).to.equal(false)
			Flags.Set("Anything", nil)
			Flags.Set("Beta", nil)
			expect(Flags.On("Anything")).to.equal(true)
			Flags.SetDefaults(nil)
		end)
	end)
end
