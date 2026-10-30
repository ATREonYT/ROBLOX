--!strict
-- Features switched off for now (the owner, Oct 27: "remove this boss fight ui for now, it will be a later update",
-- "remove this free gift for now"). Each one is off everywhere at once, and true brings it back whole:
--   WorldBoss    the World Boss pier, its countdown board and lobby stand (the map builder skips them; with no pier the
--                server, the invite and the fight HUD stay off) and its SKIP product in the store
--   WelcomeGift  the tutorial's free gift step (OnboardingRules.step goes from the first Cash pad straight on)
-- (Not frozen: the play-tests turn a feature on to keep testing it.)
return {
	WorldBoss = false,
	WelcomeGift = false,
}
