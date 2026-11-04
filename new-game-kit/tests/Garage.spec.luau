--!nonstrict
-- New Game Kit spec: Garage (dealership, fuel, repairs, impound). Vault "Realistic City RP/03".
local ServerScriptService = game:GetService("ServerScriptService")
local Garage = require(ServerScriptService:WaitForChild("Kit"):WaitForChild("Garage"))

local CATALOG = {
	Sedan = { price = 4000 },
	Super = { price = 90000, level = 10 },
	Lowrider = { price = 1000, pass = true },
}

return function()
	describe("Garage", function()
		it("sells a car once, checks level, pass and garage space", function()
			local ok, why, price = Garage.CanBuy(CATALOG, {}, "Sedan", 1)
			expect(ok).to.equal(true)
			expect(why).to.equal("Ok")
			expect(price).to.equal(4000)
			expect(select(2, Garage.CanBuy(CATALOG, { Sedan = true }, "Sedan", 1))).to.equal("Owned")
			expect(select(2, Garage.CanBuy(CATALOG, {}, "Super", 1))).to.equal("Level")
			expect((Garage.CanBuy(CATALOG, {}, "Super", 10))).to.equal(true)
			expect(select(2, Garage.CanBuy(CATALOG, {}, "Lowrider", 50))).to.equal("NeedsPass")
			expect((Garage.CanBuy(CATALOG, {}, "Lowrider", 1, true))).to.equal(true)
			expect(select(2, Garage.CanBuy(CATALOG, {}, "Jet", 1))).to.equal("Unknown")
			local full = {}
			for i = 1, Garage.Rules.maxOwned do
				full["Car" .. i] = true
			end
			expect(select(2, Garage.CanBuy(CATALOG, full, "Sedan", 1))).to.equal("GarageFull")
		end)
		it("burns fuel by distance, less when coasting, never below empty", function()
			expect(Garage.Burn(60, 1000, 60, 1)).to.be.near(54)
			expect(Garage.Burn(60, 1000, 60, 0)).to.be.near(58.5)
			expect(Garage.Burn(1, 10000, 60)).to.equal(0)
			expect(Garage.Burn(60, -5, 60)).to.equal(60)
			expect(Garage.Burn(60, 0 / 0, 60)).to.equal(60)
		end)
		it("prices the pump by whole units with a minimum", function()
			local units, cost = Garage.RefuelCost(54.4, 60, 3)
			expect(units).to.equal(6)
			expect(cost).to.equal(18)
			expect(select(2, Garage.RefuelCost(60, 60, 3))).to.equal(0)
			expect(select(2, Garage.RefuelCost(59.5, 60, 3))).to.equal(5)
		end)
		it("charges repairs, impound and buys back at fair rates", function()
			expect(Garage.RepairCost(4000, 0)).to.equal(1000)
			expect(Garage.RepairCost(4000, 0.5)).to.equal(500)
			expect(Garage.RepairCost(4000, 1)).to.equal(0)
			expect(Garage.ImpoundFee(4000)).to.equal(200)
			expect(Garage.ImpoundFee(500)).to.equal(50)
			expect(Garage.SellBack(4000)).to.equal(2400)
		end)
	end)
end
