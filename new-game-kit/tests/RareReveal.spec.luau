--!nonstrict
-- New Game Kit spec: RareReveal ladder (each tier longer, keeps lower layers, adds a new kind).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RareReveal = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("RareReveal"))

local function kinds(tier)
	local set = {}
	for _, beat in RareReveal.Plan(tier) do
		set[beat.kind] = true
	end
	return set
end

return function()
	describe("RareReveal.Plan", function()
		it("gets longer and richer every tier", function()
			local lastLength, lastKinds = -1, {}
			for _, tier in RareReveal.Order do
				local beats, length = RareReveal.Plan(tier)
				expect(length > lastLength).to.equal(true)
				local now = kinds(tier)
				for kind in lastKinds do
					expect(now[kind]).to.equal(true) -- keeps every lower layer
				end
				local added = 0
				for kind in now do
					if not lastKinds[kind] then
						added += 1
					end
				end
				if tier ~= "Common" then
					expect(added >= 1).to.equal(true)
				end
				for i = 2, #beats do
					expect(beats[i].t >= beats[i - 1].t).to.equal(true)
				end
				for _, beat in beats do
					expect(beat.t >= 0 and beat.t <= length).to.equal(true)
				end
				lastLength, lastKinds = length, now
			end
		end)
		it("shows a card with odds from Rare up and keeps Common instant", function()
			local beats, length = RareReveal.Plan("Common")
			expect(#beats).to.equal(0)
			expect(length).to.equal(0)
			for _, tier in { "Rare", "Epic", "Legendary", "Mythic", "Secret" } do
				expect(kinds(tier).card).to.equal(true)
			end
		end)
		it("never has more than one burst (one local flash) per reveal", function()
			for _, tier in RareReveal.Order do
				local bursts = 0
				for _, beat in RareReveal.Plan(tier) do
					if beat.kind == "burst" then
						bursts += 1
					end
				end
				expect(bursts <= 1).to.equal(true)
			end
		end)
		it("lets the longest reveal be skipped", function()
			expect(kinds("Secret").skip).to.equal(true)
			expect(RareReveal.Rank("Nope")).to.equal(1)
		end)
	end)
end
