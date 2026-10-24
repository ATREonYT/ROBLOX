-- Daily login rewards (owner, Oct 24 06:12: "lets make daily rewards, ill send you some items we will put into it";
-- 06:38: one of his reward knives "to be at day 7 of daily logins"). Screens/DailyLogin is the window (it opens by
-- itself in the lobby when today's reward is ready; the lobby's DAILY button opens it too); the server gives each day
-- once (HuzzServer/ProgressService.claimLogin, rules in Shared/LoginRules).
--   * One reward per day you play (a day = Roblox's server clock, UTC). Missing a day never loses your place: you just
--     carry on from the next day of the 7 (kid-safe: no streak to lose).
--   * After day 7 it starts again at day 1. Day 7 is his Stormfang Chokuto; if it's yours already, Owned coins instead.
-- Days 1-6 are our picks until he sends the items he wants (owner to replace).
--   Kind: "Coins" | "Aura" (Amount) | "Spins" (Amount spins on the wheel) | "Knife" (Id = a Config/CoinShop key)
return {
	Days = {
		{ Kind = "Coins", Amount = 100, Name = "100 Coins" },
		{ Kind = "Aura", Amount = 15, Name = "15 Aura" },
		{ Kind = "Spins", Amount = 1, Name = "1 Spin" },
		{ Kind = "Coins", Amount = 250, Name = "250 Coins" },
		{ Kind = "Aura", Amount = 40, Name = "40 Aura" },
		{ Kind = "Spins", Amount = 2, Name = "2 Spins" },
		{ Kind = "Knife", Id = "StormfangChokuto", Name = "Stormfang Chokuto", Owned = 1500 },
	},
	DayLength = 24 * 60 * 60,
	PopupAfter = 6, -- seconds in the lobby before the window opens by itself, once per visit, while today's is ready
}
