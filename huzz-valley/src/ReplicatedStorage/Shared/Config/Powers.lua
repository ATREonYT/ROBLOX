-- Round powers (owner, Oct 19: "make simple lingo such as rizz rush, just make it simple"; Oct 20 15:13: "Please then
-- make the abilities be bought, add a few more abilities, but make them well made, right now they are kind of quick
-- and feel cheap"). Reset at the start of every round. Times in seconds, speeds in studs per second, distances in studs.
--   Runners  Q: the runner ability you bring (your loadout, picked in the Shop's ABILITIES), or RANDOM: one of the runner abilities
--               you own, picked for you each round (never the same twice in a row). One ability on Q, like his
--               picture c ("ONE HIT SHIELD").
--            E: Speed Boost, only while you carry the girl ("give the rush to a person only having the girl"); its
--               card shows only then. Free for everyone, never sold.
--   Catchers Q and E: the two catcher abilities you bring (two different ones).
-- Bought with coins, kept for good (Shared/AbilityRules, ActionService "BuyAbility" / "EquipAbility"). Everyone
-- starts with Shield (runner), Bear Trap and Slow Wave (catcher): Starter = true; the rest are bought and equipped
-- (owner, Oct 22). Old saves are no longer given the abilities they could roll before Oct 20 (Grandfathered is empty).
-- Prices against the pay (Config/Round.Pay: 25 coins a game, 50 a win; the knives are 200 / 500 / 1,000 / 2,000 /
-- 4,000): one ability is about the price of an Uncommon to Rare knife, a few evenings of play.
-- The cards above the dash bar (Screens/PowerBar) show Card (the title), the key and the state in Accent, like his
-- pictures b and c (design/owner-oct19). The server tells each player which power is in each slot (player
-- attributes PowerName1 / PowerName2, HuzzServer/PowerService). Icon: the card's picture, his own power pictures
-- (owner, Oct 20 20:34: "bring back the old pictures for the powers ... We want to stand out": cut from his sheet by
-- tools/icons/cut_power_tiles.py; Speed Boost has none in his sheet, so it keeps our render, ability_icons.mjs);
-- Tile: his tile's rim colour, drawn round the picture (UI/AbilityCards, Screens/PowerBar). Emoji: the glyph shown
-- only if a picture can't be drawn.
return {
	-- What each slot holds: { Loadout = key } = the ability saved in that loadout key, a name = that power for everyone.
	Runner = { { Loadout = "Runner" }, "SpeedBoost" },
	Catcher = { { Loadout = "CatcherQ" }, { Loadout = "CatcherE" } },
	Keys = { "Q", "E" },
	-- The shop and the loadout panel list them in this order (UI/AbilityCards).
	Shop = {
		Runner = { "Shield", "Invisible", "Glitchy", "BodyDouble", "BananaPeel", "SmokeBomb" },
		Catcher = { "BearTrap", "SlowWave", "Radar", "Lasso" },
	},
	-- Loadout keys: which side's abilities go there, and what a fresh save brings. "Random" (runner only): one of the
	-- runner abilities you own, picked each round, only if you pick it. Owner, Oct 22 12:26: "make everyone start with
	-- the shield ability, and then for the other abilities you have to buy them and equip them": a fresh save brings
	-- Shield (was Random, which played bought ones without equipping them).
	Loadout = {
		Sides = { Runner = "Runner", CatcherQ = "Catcher", CatcherE = "Catcher" },
		Default = { Runner = "Shield", CatcherQ = "BearTrap", CatcherE = "SlowWave" },
	},
	-- Runner abilities an old save (from before abilities were bought, Oct 20) got for free. None since Oct 22 (the
	-- owner: everyone starts with Shield only, the rest are bought): old test saves keep what they were already given.
	Grandfathered = {},

	-- How every power looks when it's used (Gameplay/PowerEffects). Oct 20 15:13 ("kind of quick and feel cheap"):
	-- each one has a real wind-up now (a gathering ring and a rising charge sound, the body's cast pose), one bright
	-- frame (Flash, never more than one a second on a screen), the effect long enough to read (Burst), then a soft
	-- fade (Fade), and a clean end of its own (a fizzle, a reappear shimmer, a puff). Powers that move you (Glitchy)
	-- keep a short wind-up so they still answer the key at once. The server waits each power's WindUp before it
	-- lands (Slow Wave's slow, Radar's sweep, the Lasso's rope, the Bear Trap's flight counts from the press).
	-- Sound: played as the effect bursts; Charge: the wind-up's riser (power_charge), off for the quick ones.
	Fx = {
		WindUp = 0.3, Flash = 0.05, Burst = 0.6, Fade = 0.4,
		Core = Color3.fromRGB(255, 255, 255), Glow = Color3.fromRGB(255, 140, 230), Edge = Color3.fromRGB(155, 77, 255),
		Shield = { WindUp = 0.3, Sound = "heart_shield", Charge = true },
		SpeedBoost = { WindUp = 0.18, Sound = "power_rush" },
		BearTrap = { WindUp = 0.32, Sound = "trap_throw", Pose = "Throw" }, -- (Pose: Config/Run.Cast.Throw)
		SlowWave = { WindUp = 0.45, Sound = "heart_shield", Pitch = 0.85, Charge = true },
		Invisible = { WindUp = 0.35, Sound = "invisible", Charge = true },
		Glitchy = { WindUp = 0.1, Sound = "glitch" },
		BodyDouble = { WindUp = 0.3, Sound = "decoy", Charge = true },
		BananaPeel = { WindUp = 0.22, Sound = "banana_drop", Pose = "Throw" },
		SmokeBomb = { WindUp = 0.18, Sound = "smoke_bomb", Pose = "Throw" }, -- (0.3 felt slow: owner, Oct 23)
		Lasso = { WindUp = 0.18, Sound = "lasso_throw", Pose = "Throw" },
		Radar = { WindUp = 0.4, Sound = "radar_ping", Charge = true },
	},

	-- A pink bubble for a few seconds. It blocks the next stab: the catcher gets dizzy (slow, can't stab) and you get
	-- a burst of speed to run off. Once a game (all its rounds). Lasts counts from when the bubble shows (after the wind-up).
	Shield = {
		Name = "Shield", Card = "ONE HIT SHIELD", Icon = "AbilityShield", Tile = Color3.fromRGB(32, 176, 245), Emoji = "🛡️", Text = "Blocks one stab",
		Accent = Color3.fromRGB(110, 205, 255), Side = "Runner", Starter = true, Price = 0,
		Counter = "Wait it out: it lasts 6 s",
		OncePerGame = true, Lasts = 6, Dizzy = 1.5, DizzySlow = 0.5, Boost = 6, BoostTime = 1.5,
	},
	-- Gone for a few seconds (owner, Oct 21: "the invisible should be completely invisible"; still catchable, and
	-- your footsteps still sound). Other screens lose all of you: body, knife, name tag, trail, aura and the girl you
	-- carry (Gameplay/PowerEffects). Radar shows you again. Seen = how see-through others see you (0..1, 1 = gone),
	-- Self = how you see yourself.
	Invisible = {
		Name = "Invisible", Card = "INVISIBLE", Icon = "AbilityInvisible", Tile = Color3.fromRGB(81, 74, 147), Emoji = "👻", Text = "Fade out of sight",
		Accent = Color3.fromRGB(200, 184, 255), Side = "Runner", Price = 500,
		Counter = "Listen for footsteps, or use Radar",
		Cooldown = 16, Lasts = 4, Seen = 1, Self = 1, -- (owner, Oct 22 12:26: "make the invisible actually 1.00 invisible": was 0.55 on your own screen)
	},
	-- A short glitch-blink forward (Distance studs in Time seconds, the walls still stop you) with a glitch effect.
	Glitchy = {
		Name = "Glitchy", Card = "GLITCHY", Icon = "AbilityGlitchy", Tile = Color3.fromRGB(17, 99, 113), Emoji = "📺", Text = "Blink forward",
		Accent = Color3.fromRGB(78, 240, 224), Side = "Runner", Price = 500,
		Counter = "It only goes forward: wait for it",
		Cooldown = 8, Distance = 9, Time = 0.14,
	},
	-- A copy of you that runs straight on the way you face for Lasts seconds, then vanishes in a puff. It's only a
	-- look (it can't be caught): a decoy. Other screens see you exactly, name tag and the girl you carry included
	-- (owner, Oct 21); your own screen shows it with a pink shimmer so you know which one is you.
	BodyDouble = {
		Name = "Body Double", Card = "BODY DOUBLE", Icon = "AbilityBodyDouble", Tile = Color3.fromRGB(156, 95, 44), Emoji = "👯", Text = "Send out a decoy",
		Accent = Color3.fromRGB(255, 176, 96), Side = "Runner", Price = 750,
		Counter = "It only runs straight ahead",
		Cooldown = 14, Lasts = 3.5,
		-- (owner, Oct 22: "make it 0.00 invisible so its actually useful": solid and plain on your own screen too;
		-- Marked = true gives it back the pink shimmer and afterimages there, Gameplay/PowerEffects)
		Marked = false,
		-- seconds between its fading afterimages (each a pink glowing copy: kid-safe, never more than one a second;
		-- 0.45 made one pop about twice a second, critic Oct 20). tests/PowerGhosts.spec checks it.
		AfterimageEvery = 1.2,
	},
	-- New Oct 20. Drop a banana peel behind you: the first catcher who steps on it slips (stuck and can't stab for
	-- Slip seconds, stars over the head). Runners walk over it. One out at a time; it goes after Lasts.
	BananaPeel = {
		Name = "Banana Peel", Card = "BANANA PEEL", Icon = "AbilityBananaPeel", Tile = Color3.fromRGB(131, 106, 42), Emoji = "🍌", Text = "Catchers slip on it",
		Accent = Color3.fromRGB(255, 226, 74), Side = "Runner", Price = 600,
		Counter = "It's bright yellow: walk round it",
		Cooldown = 12, Lasts = 15, Radius = 2.2, Slip = 1.4, Back = 2.5, Arm = 0.4, MaxOut = 1,
	},
	-- New Oct 20. A big puff of smoke where you stand for Lasts seconds: a runner inside it can't be seen on other
	-- screens (body, name tag, trail all fade out, Oct 21), and catchers in it are slowed to Slow. It stays where it was dropped.
	SmokeBomb = {
		Name = "Smoke Bomb", Card = "SMOKE BOMB", Icon = "AbilitySmokeBomb", Tile = Color3.fromRGB(54, 93, 137), Emoji = "💨", Text = "Hide in a smoke cloud",
		Accent = Color3.fromRGB(196, 170, 255), Side = "Runner", Price = 900,
		Counter = "Go round it, or use Radar",
		Cooldown = 16, Lasts = 5, Radius = 8, Slow = 0.75,
	},
	-- A burst of speed with a trail, only while you carry the girl.
	SpeedBoost = {
		Name = "Speed Boost", Card = "SPEED BOOST", Icon = "AbilitySpeedBoost", Emoji = "⚡", Text = "Speed burst with the girl",
		Accent = Color3.fromRGB(255, 211, 78), Side = "Runner", Free = true, Price = 0,
		CarrierOnly = true, Cooldown = 10, Boost = 12, Time = 1.2,
	},
	-- Throw a bear trap in front of you (owner: "you throw the beartrap infront of you with a small animation"): it
	-- flies Throw studs ahead in an arc for Flight seconds, lands, and arms Arm seconds later. The first runner who
	-- steps on an armed trap is stuck for Hold seconds. Everyone can see the traps. Never lands in the runners' start
	-- zone or through a wall (shorter throws are tried first).
	BearTrap = {
		Name = "Bear Trap", Card = "BEAR TRAP", Icon = "AbilityBearTrap", Tile = Color3.fromRGB(75, 47, 147), Emoji = "🪤", Text = "Throw a trap ahead",
		Accent = Color3.fromRGB(222, 112, 96), Side = "Catcher", Starter = true, Price = 0,
		Counter = "It glows when armed: step round it",
		Cooldown = 9, MaxOut = 2, Hold = 1.6, Lasts = 30, Radius = 3,
		Throw = 10, Flight = 0.7, Arc = 3.5, Arm = 0.35, -- (Flight counts from the press: the throw itself is Fx WindUp)
	},
	-- A wave round you: runners it reaches slow down for a bit.
	SlowWave = {
		Name = "Slow Wave", Card = "SLOW WAVE", Icon = "AbilitySlowWave", Tile = Color3.fromRGB(117, 60, 227), Emoji = "🌀", Text = "Slow runners near you",
		Accent = Color3.fromRGB(180, 140, 255), Side = "Catcher", Starter = true, Price = 0,
		Counter = "Keep 16 studs away when it gathers",
		Cooldown = 14, Radius = 16, Slow = 0.6, Time = 2.5,
	},
	-- New Oct 20. A ping that sweeps out Range studs: every runner it reaches glows through walls for Lasts seconds
	-- on every screen (shows Invisible runners and runners in smoke too: they come back to Reveal see-through). It only
	-- shows them.
	Radar = {
		Name = "Radar", Card = "RADAR", Icon = "AbilityRadar", Tile = Color3.fromRGB(125, 46, 80), Emoji = "📡", Text = "Spot every runner near you",
		Accent = Color3.fromRGB(255, 120, 150), Side = "Catcher", Price = 750,
		Counter = "It only shows you: keep running",
		Cooldown = 18, Range = 70, Sweep = 0.9, Lasts = 4, Reveal = 0.45,
	},
	-- New Oct 20. Throw a lasso straight ahead: the rope flies at Speed up to Range; the first runner it touches (Width
	-- across) is pulled Pull studs towards you over PullTime (never closer than MinGap), then slowed to Slow for Hold.
	-- A Shield stops it. Never runners who are safe or still in their start zone.
	Lasso = {
		Name = "Lasso", Card = "LASSO", Icon = "AbilityLasso", Tile = Color3.fromRGB(130, 78, 29), Emoji = "🤠", Text = "Pull a runner to you",
		Accent = Color3.fromRGB(240, 170, 90), Side = "Catcher", Price = 1000,
		Counter = "Huss sideways when the rope flies",
		-- (owner, Oct 23 16:52: "make the lasso go further and quicker": Range 24 -> 40, Speed 70 -> 130, WindUp
		-- 0.3 -> 0.18 in Fx)
		-- Owner, Oct 24: "make the lasso work better (all the way to you and you can throw it to near the end of the
		-- map)": Range 40 -> 220 (the fields are about 160 to 330 studs end to end), Speed 130 -> 240 (the far end in
		-- under a second), Width 3 -> 5 (easier to land far off), and the pull drags them all the way to MinGap
		-- studs from you (Pull was 10) at PullSpeed studs a second, PullTime to MaxPullTime long
		-- (AbilityRules.pullTime).
		Cooldown = 15, Range = 220, Speed = 240, Width = 5, Pull = 1000, PullSpeed = 110, PullTime = 0.3, MaxPullTime = 2.2,
		MinGap = 4, Hold = 0.6, Slow = 0.6,
	},
}
