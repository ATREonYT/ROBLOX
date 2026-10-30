--!strict
-- Gamepasses and developer products (§10). Every Id is 0 until the passes are
-- created on the Roblox website — the server skips anything with Id == 0, so
-- the game runs fine before monetization is set up.
--
-- HOW TO WIRE UP (one-time, on the website):
--   Creator Dashboard → your experience → Monetization → Passes → create each
--   pass below at the listed Robux price, then paste its numeric id here.
--
-- The Robux multiplier applies OUTSIDE the earned-multiplier parenthesis (§9):
--   total = (rank × gear × intern × restructure) × robux

export type PassDef = {
	Key: string,
	Id: number, -- gamepass id from the website, 0 = not created yet
	Name: string,
	Price: number, -- Robux, for the in-game shop display only
	Description: string,
}

local Monetization = {
	Passes = {
		{ Key = "StarterPack", Id = 0, Name = "Starter Pack", Price = 39, Description = "500 Wins + a Membrane Keyboard to get rolling" },
		{ Key = "DoubleWins", Id = 0, Name = "2x Wins", Price = 199, Description = "Twice the Wins from every rival" },
		{ Key = "DoubleProductivity", Id = 0, Name = "2x Productivity", Price = 199, Description = "Twice the Productivity from every source" },
		{ Key = "InternSlots", Id = 0, Name = "+3 Intern Slots", Price = 249, Description = "Six interns on the payroll at once" },
		{ Key = "Delegate", Id = 0, Name = "Delegate", Price = 299, Description = "Auto-clicks for you at 5 clicks per second" },
		{ Key = "ExecutiveSkip", Id = 0, Name = "Executive Floor Skip", Price = 249, Description = "Elevator access to floor 40, no Restructures needed" },
		{ Key = "PenthouseSkip", Id = 0, Name = "Penthouse Skip", Price = 649, Description = "Elevator access to floor 88, no Restructures needed" },
		{ Key = "Buyout", Id = 0, Name = "The Buyout", Price = 1999, Description = "2x Wins + 2x Productivity + 3 Intern Slots + Delegate" },
	} :: { PassDef },

	-- Golden Briefcase trails: cosmetic ladder sold as individual passes.
	Trails = {
		{ Key = "TrailBronze", Id = 0, Name = "Bronze Briefcase Trail", Price = 19, Color = { 176, 118, 60 } },
		{ Key = "TrailSilver", Id = 0, Name = "Silver Briefcase Trail", Price = 79, Color = { 200, 205, 212 } },
		{ Key = "TrailGold", Id = 0, Name = "Gold Briefcase Trail", Price = 199, Color = { 255, 196, 40 } },
		{ Key = "TrailPlatinum", Id = 0, Name = "Platinum Briefcase Trail", Price = 499, Color = { 229, 233, 240 } },
		{ Key = "TrailQuantum", Id = 0, Name = "Quantum Briefcase Trail", Price = 999, Color = { 60, 255, 220 } },
	},

	DelegateClicksPerSecond = 5, -- what the auto-click pass actually does
}

function Monetization.passByKey(key: string): PassDef?
	for _, pass in Monetization.Passes do
		if pass.Key == key then
			return pass
		end
	end
	return nil
end

return Monetization
