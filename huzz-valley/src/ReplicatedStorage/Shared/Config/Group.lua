-- The "join our group" reward (owner, Oct 22 19:09: "make a 'join the group' ui pop up for a reward in the style of
-- our ui, and make the reward 5 free spins on the wheel"). Screens/GroupReward is the window; the server checks
-- you're really in the group with Roblox (HuzzServer/ProgressService.claimGroup) and gives the spins once per save.
return {
	-- YOUR group's number (owner to fill in: the digits in its page link, roblox.com/communities/<number>/...).
	-- 0 = not set yet: the window says the group is coming soon and gives nothing, and it never pops up live.
	Id = 0,
	Name = "", -- its name, shown in the window (optional; empty = "our group")
	Spins = 5, -- the reward: spins on the wheel (the same kind of spins the shop sells)
	PopupAfter = 20, -- seconds in the lobby before the window opens by itself, once per visit, until it's claimed
}
