-- Friend rewards (owner, Oct 19: "make friend rewards, add a friend knife (for inviting them) and add a 10% coin boost
-- when a friend is in"; Oct 24 06:38: "one knife for exmaple rewarded for inviting 5 friends"). HuzzServer/FriendService
-- checks who in the server is your Roblox friend:
--   * while at least one friend plays in your server, every game's coin pay is +10% (CoinBoost), and the lobby HUD
--     shows BoostTag by your coins;
--   * each different friend who joins a server you're in counts once (that's what an invite does; Roblox doesn't tell
--     a game who was invited). The first one gives FirstCoins; the Need-th gives the friend knife, his Thousand Blossom
--     (Knife, once per account; FriendKnifeCoins coins instead if you somehow own it already).
-- The INVITE button on the lobby HUD opens Roblox's own invite window (SocialService); nothing is paid for an invite.
-- (Before Oct 24 the first friend gave the Sakura Blade, a placeholder: saves that got it keep it.)
return {
	CoinBoost = 1.1, -- x1.1 = +10% coins while a friend is in your server
	Need = 5, -- different friends who join you, for the knife
	Knife = "ThousandBlossom", -- Config/CoinShop key (his reward knife, never sold)
	KnifeName = "Thousand Blossom",
	FirstCoins = 500, -- the first friend who joins you
	FriendKnifeCoins = 2000, -- instead of the knife, if it's already yours
	BoostTag = "+10% COINS",
	InviteHint = "Invite friends: +10% coins while you play together, and 5 friends who join you win the Thousand Blossom knife!",
	BoostToast = "A friend is here! +10% coins while you play together.",
	KnifeToast = "5 friends joined you! The Thousand Blossom knife is yours. Wear it from your Inventory.",
	CoinsToast = "A friend joined you: +500 coins! Bring 5 friends for the Thousand Blossom knife.",
	MoreToast = "Another friend joined you! %d of 5 for the Thousand Blossom knife.",
}
