-- The "join our group" reward (owner, Oct 22 19:09: "make a 'join the group' ui pop up for a reward in the style of
-- our ui, and make the reward 5 free spins on the wheel"). Screens/GroupReward is the window; the server checks
-- you're really in the group with Roblox (HuzzServer/ProgressService.claimGroup) and gives the spins once per save.
return {
	-- YOUR group's number (owner to fill in: the digits in its page link, roblox.com/communities/<number>/...).
	-- 0 = not set yet: the window says the group is coming soon and gives nothing, and it never pops up live.
	-- Owner, Oct 23 17:48: the group is Emergent Gaming ("the game that made the game"); its link from him, Oct 23
	-- 20:05: roblox.com/communities/836119652/Emergent-Gaming.
	Id = 836119652,
	Name = "Emergent Gaming", -- its name, shown in the window (empty = "our group")
	Spins = 5, -- the reward: spins on the wheel (the same kind of spins the shop sells)
	PopupAfter = 20, -- seconds in the lobby before the window opens by itself, once per visit, until it's claimed
	-- Roblox's own "add this game to your favourites?" (owner, Oct 23 14:03: "make the thing on roblox pop up asking you
	-- if you want to add the game to your favourites randomly"; Gameplay/FavouritePrompt): once per visit, at a random
	-- moment this many seconds in, in the lobby with nothing open; never if it's already a favourite.
	FavouriteAfter = { 240, 540 },
}
