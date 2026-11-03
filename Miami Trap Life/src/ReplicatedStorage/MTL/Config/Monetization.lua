--!strict
-- Game Pass and Developer Product ids. ALL ZERO until Alex creates them on the Creator Dashboard.
-- An id of 0 means "not set up": the pass reads as not owned and the buy button shows "coming soon".
-- Never invent an id.
return {
	Passes = {
		StarterPack = 0, -- TODO(Alex): create pass, paste id
		XP2x = 0, -- TODO(Alex)
		Cash2x = 0, -- TODO(Alex)
	},
	Products = {
		XPBoost = 0, -- TODO(Alex): 2x XP for 30 min of play time
		CashBoost = 0, -- TODO(Alex): 2x cash for 30 min of play time
	},
	StarterPack = { Cash = 2500 }, -- what the pass gives once (content TBD with Alex)
}
