--!nonstrict
-- New Game Kit spec: HudStages (the HUD arrives a piece at a time during the tutorial).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HudStages = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("HudStages"))

local STAGES = {
	{ Step = "Train", Show = { "PowerBar" } },
	{ Step = "Launch", Show = { "Coins" } },
	{ Step = "Rebirth", Show = { "Menu.Rebirth" }, Spotlight = "Menu.Rebirth" },
	{ Step = "Done", Show = "*" },
}
local ALL = { "PowerBar", "Coins", "Menu.Shop", "Menu.Rebirth", "Menu.Pets" }

return function()
	describe("HudStages", function()
		it("shows only the bar at join", function()
			expect(HudStages.Visible(STAGES, 1, "PowerBar")).to.equal(true)
			expect(HudStages.Visible(STAGES, 1, "Coins")).to.equal(false)
			expect(HudStages.Visible(STAGES, 1, "Menu.Shop")).to.equal(false)
		end)
		it("keeps what earlier steps showed", function()
			expect(HudStages.Visible(STAGES, 3, "Coins")).to.equal(true)
			expect(HudStages.Visible(STAGES, 3, "Menu.Rebirth")).to.equal(true)
			expect(HudStages.Visible(STAGES, 3, "Menu.Pets")).to.equal(false)
		end)
		it("shows everything at the last stage", function()
			for _, name in ALL do
				expect(HudStages.Visible(STAGES, 4, name)).to.equal(true)
			end
		end)
		it("lists what arrives, in order", function()
			local list = HudStages.Arriving(STAGES, 3, 4, ALL)
			expect(#list).to.equal(2)
			expect(list[1]).to.equal("Menu.Shop")
			expect(list[2]).to.equal("Menu.Pets")
			expect(#HudStages.Arriving(STAGES, 1, 3, ALL)).to.equal(2)
		end)
		it("spotlights the step's button", function()
			expect(HudStages.Spotlight(STAGES, 3)).to.equal("Menu.Rebirth")
			expect(HudStages.Spotlight(STAGES, 1)).to.equal(nil)
		end)
		it("gives returning players the full HUD", function()
			expect(HudStages.StageFor(STAGES, 0, false)).to.equal(1)
			expect(HudStages.StageFor(STAGES, 2, false)).to.equal(3)
			expect(HudStages.StageFor(STAGES, 9, false)).to.equal(4)
			expect(HudStages.StageFor(STAGES, 0, true)).to.equal(4)
		end)
	end)
end
