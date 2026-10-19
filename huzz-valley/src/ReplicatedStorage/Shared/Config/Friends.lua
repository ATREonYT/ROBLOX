-- Friend rewards (owner, Oct 19: "make friend rewards, add a friend knife (for inviting them) and add a 10% coin boost
-- when a friend is in"). HuzzServer/FriendService checks who in the server is your Roblox friend:
--   * while at least one friend plays in your server, every game's coin pay is +10% (CoinBoost), and the lobby HUD
--     shows BoostTag by your coins;
--   * the first time a friend joins a server you're in, you get the friend knife (Knife, once per account). If you
--     already own it, FriendKnifeCoins coins instead.
-- PLACEHOLDER: the friend knife is our pick from his own 30 (Sakura Blade, pink, Rare) until he names one or sends a
-- friend knife model; it can still be bought or won in the Knife Crate too. A dedicated row (never sold) waits for
-- the knife files to be free (Config/CoinShop, owned by the knife work today).
-- The INVITE button on the lobby HUD opens Roblox's own invite window (SocialService); nothing is paid for an invite.
return {
	CoinBoost = 1.1, -- x1.1 = +10% coins while a friend is in your server
	Knife = "CandyKnife", -- Config/CoinShop key (placeholder pick: "Sakura Blade")
	KnifeName = "Sakura Blade",
	FriendKnifeCoins = 500, -- (half its coin price) when you already own the friend knife
	BoostTag = "+10% COINS",
	InviteHint = "Invite a friend: you both get +10% coins while you play together!",
	BoostToast = "A friend is here! +10% coins while you play together.",
	KnifeToast = "Friend knife! Sakura Blade is yours. Wear it in Shop > Items.",
	CoinsToast = "Friend reward: +500 coins (you already have the friend knife).",
}
