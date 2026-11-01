--!nonstrict
-- New Game Kit spec: Rounds (vault note 32).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rounds = require(ReplicatedStorage:WaitForChild("Kit"):WaitForChild("Rounds"))

local CFG = { minPlayers = 2, intermission = 10, countdown = 3, roundLength = 60, results = 5, joinInProgress = 10 }

local function kinds(events)
	local out = {}
	for _, e in events do
		table.insert(out, e.kind)
	end
	return table.concat(out, ",")
end

local function toPlaying(r)
	r:Join(1)
	r:Join(2)
	r:Tick(0) -- Intermission
	r:Tick(10) -- Countdown
	return r:Tick(13) -- Started
end

return function()
	describe("Rounds", function()
		it("waits for enough players, then runs lobby, countdown and play", function()
			local r = Rounds.new(CFG)
			r:Join(1)
			expect(kinds(r:Tick(0))).to.equal("")
			expect(r.state).to.equal("Waiting")
			local ev = toPlaying(r)
			expect(kinds(ev)).to.equal("Started")
			expect(r.round).to.equal(1)
			expect(#ev[1].players).to.equal(2)
		end)
		it("cancels the lobby when a player leaves", function()
			local r = Rounds.new(CFG)
			r:Join(1)
			r:Join(2)
			r:Tick(0)
			r:Leave(2)
			expect(kinds(r:Tick(3))).to.equal("Cancelled")
			expect(r.state).to.equal("Waiting")
		end)
		it("ends early when one player is left, and pays only real rounds", function()
			local r = Rounds.new(CFG)
			toPlaying(r)
			r:Eliminate(2)
			local ev = r:Tick(20) -- 7 s of play: too short to pay
			expect(kinds(ev)).to.equal("EndedUnpaid")
			local r2 = Rounds.new(CFG)
			toPlaying(r2)
			r2:Eliminate(1)
			ev = r2:Tick(40) -- 27 s of play
			expect(kinds(ev)).to.equal("Ended")
			expect(ev[1].players[1]).to.equal(2)
		end)
		it("ends on the timer and loops back to the lobby", function()
			local r = Rounds.new(CFG)
			toPlaying(r)
			expect(kinds(r:Tick(73))).to.equal("Ended")
			expect(kinds(r:Tick(78))).to.equal("Intermission")
			expect(next(r.alive)).to.equal(nil)
		end)
		it("lets late joiners in only during the grace window", function()
			local r = Rounds.new(CFG)
			toPlaying(r)
			expect(r:Join(3, 20)).to.equal(true)
			expect(r:Join(4, 30)).to.equal(false)
			expect(r.alive[4]).to.equal(nil)
		end)
		it("ignores eliminations outside play and leaving removes the player", function()
			local r = Rounds.new(CFG)
			expect(r:Eliminate(1)).to.equal(false)
			toPlaying(r)
			r:Leave(1)
			expect(r.alive[1]).to.equal(nil)
			expect(r:Eliminate(1)).to.equal(false)
		end)
	end)
end
