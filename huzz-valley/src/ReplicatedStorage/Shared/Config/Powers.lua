-- Round powers (owner, Oct 19: "make simple lingo such as rizz rush, just make it simple"). Free for everyone, reset
-- at the start of every round. Times in seconds, speeds in studs per second, distances in studs.
--   Runners  Q: this round's ability, picked at random for each runner when the round starts (one of RunnerPick, never
--               the same one twice in a row): Shield, Invisible, Glitchy or Body Double. One ability on Q, like his
--               picture c ("ONE HIT SHIELD").
--            E: Speed Boost, only while you carry the girl ("give the rush to a person only having the girl"); its
--               card shows only then.
--   Catchers Q: Bear Trap (thrown in front of you), E: Slow Wave.
-- The cards above the dash bar (Screens/PowerBar) show Card (the title), the key and the state in Accent, like his
-- pictures b and c (design/owner-oct19). The server tells each player which power is in each slot (player
-- attributes PowerName1 / PowerName2, HuzzServer/PowerService). Icon: the card's picture (Shared/Images/Icons,
-- tools/icons/ability_icons.mjs); Emoji: the fallback when the picture can't be drawn.
return {
	Runner = { "Pick", "SpeedBoost" }, -- slot 1 (Q): "Pick" = this round's ability from RunnerPick; slot 2 (E)
	RunnerPick = { "Shield", "Invisible", "Glitchy", "BodyDouble" },
	Catcher = { "BearTrap", "SlowWave" },
	Keys = { "Q", "E" },

	-- How every power looks when it's used (Gameplay/PowerEffects), timed like the other game's ability
	-- (docs/feel-study.md section 6): a glow builds (WindUp), one bright frame (Flash, never more than one a second on
	-- a screen), the effect (Burst), then it fades (Fade). Each power glows in its own Accent. Powers that work the
	-- moment you press have a shorter wind-up; Slow Wave's slow lands on the runners when its ring goes out
	-- (HuzzServer/PowerService waits WindUp); the Bear Trap flies for BearTrap.Flight after the throw.
	Fx = {
		WindUp = 0.25, Flash = 0.05, Burst = 0.35, Fade = 0.15,
		Core = Color3.fromRGB(255, 255, 255), Glow = Color3.fromRGB(255, 140, 230), Edge = Color3.fromRGB(155, 77, 255),
		Shield = { WindUp = 0.15, Sound = "heart_shield" },
		SpeedBoost = { WindUp = 0.15, Sound = "power_rush" },
		BearTrap = { WindUp = 0.2, Sound = "trap_throw", Pose = "Throw" }, -- (Pose: Config/Run.Cast.Throw)
		SlowWave = { Sound = "heart_shield", Pitch = 0.85 },
		Invisible = { WindUp = 0.12, Sound = "invisible" },
		Glitchy = { WindUp = 0.05, Sound = "glitch" },
		BodyDouble = { WindUp = 0.12, Sound = "decoy" },
	},

	-- A blue bubble for a few seconds. It blocks the next stab: the catcher gets dizzy (slow, can't stab) and you get
	-- a burst of speed to run off. Once per round.
	Shield = {
		Name = "Shield", Card = "ONE HIT SHIELD", Icon = "AbilityShield", Emoji = "🛡️", Text = "Blocks one stab",
		Accent = Color3.fromRGB(110, 205, 255),
		OncePerRound = true, Lasts = 6, Dizzy = 1.5, DizzySlow = 0.5, Boost = 6, BoostTime = 1.5,
	},
	-- Nearly see-through for a few seconds (still catchable). Others see a faint shimmer, so it stays fair; the name
	-- tag hides. Seen = how see-through others see you (0..1), Self = how you see yourself.
	Invisible = {
		Name = "Invisible", Card = "INVISIBLE", Icon = "AbilityInvisible", Emoji = "👻", Text = "Fade out of sight",
		Accent = Color3.fromRGB(200, 184, 255),
		Cooldown = 16, Lasts = 4, Seen = 0.88, Self = 0.55, Shimmer = 0.8, -- (Shimmer: pulses a second, at most 1)
	},
	-- A short glitch-blink forward (Distance studs in Time seconds, the walls still stop you) with a glitch effect.
	Glitchy = {
		Name = "Glitchy", Card = "GLITCHY", Icon = "AbilityGlitchy", Emoji = "📺", Text = "Blink forward",
		Accent = Color3.fromRGB(78, 240, 224),
		Cooldown = 8, Distance = 9, Time = 0.14,
	},
	-- A copy of you that runs straight on the way you face for Lasts seconds, then vanishes in a puff. It's only a
	-- look (it can't be caught, and it can't carry the girl): a decoy.
	BodyDouble = {
		Name = "Body Double", Card = "BODY DOUBLE", Icon = "AbilityBodyDouble", Emoji = "👯", Text = "Send out a decoy",
		Accent = Color3.fromRGB(255, 176, 96),
		Cooldown = 14, Lasts = 3.5,
		-- seconds between its fading afterimages (each a pink glowing copy: kid-safe, never more than one a second;
		-- 0.45 made one pop about twice a second, critic Oct 20). tests/PowerGhosts.spec checks it.
		AfterimageEvery = 1.2,
	},
	-- A burst of speed with a trail, only while you carry the girl.
	SpeedBoost = {
		Name = "Speed Boost", Card = "SPEED BOOST", Icon = "AbilitySpeedBoost", Emoji = "⚡", Text = "Speed burst with the girl",
		Accent = Color3.fromRGB(255, 211, 78),
		CarrierOnly = true, Cooldown = 10, Boost = 12, Time = 1.2,
	},
	-- Throw a bear trap in front of you (owner: "you throw the beartrap infront of you with a small animation"): it
	-- flies Throw studs ahead in an arc for Flight seconds, lands, and arms Arm seconds later. The first runner who
	-- steps on an armed trap is stuck for Hold seconds. Everyone can see the traps. Never lands in the runners' start
	-- zone or through a wall (shorter throws are tried first).
	BearTrap = {
		Name = "Bear Trap", Card = "BEAR TRAP", Icon = "AbilityBearTrap", Emoji = "🪤", Text = "Throw a trap ahead",
		Accent = Color3.fromRGB(222, 112, 96),
		Cooldown = 9, MaxOut = 2, Hold = 1.6, Lasts = 30, Radius = 3,
		Throw = 10, Flight = 0.6, Arc = 3.5, Arm = 0.35, -- (Flight counts from the press: the throw itself is Fx WindUp)
	},
	-- A wave round you: runners it reaches slow down for a bit.
	SlowWave = {
		Name = "Slow Wave", Card = "SLOW WAVE", Icon = "AbilitySlowWave", Emoji = "🌀", Text = "Slow runners near you",
		Accent = Color3.fromRGB(180, 140, 255),
		Cooldown = 14, Radius = 16, Slow = 0.6, Time = 2.5,
	},
}
