-- Round powers: two for runners, two for catchers, on Q and E (or tap the cards at the bottom of the screen).
-- Free for everyone, reset at the start of every round. Times in seconds, speeds in studs per second,
-- distances in studs. Icon is the emoji on the card until the owner sends icon pictures.
return {
	Runner = { "HeartShield", "RizzRush" }, -- slot 1 (Q), slot 2 (E)
	Catcher = { "LoveTrap", "CharmWave" },
	Keys = { "Q", "E" },

	-- How every power looks when it's used (Gameplay/PowerEffects), timed like the other game's ability
	-- (docs/feel-study.md section 6, its Soul Reaper slash): a glow builds (WindUp), one bright frame (Flash, never more
	-- than one a second on a screen), the effect (Burst), then it fades to purple (Fade). Colours run from a white
	-- core to pink to purple edges. Shield and Rush work the moment you press, so their wind-up is shorter; Charm
	-- Wave's slow lands on the runners when its ring goes out (HuzzServer/PowerService waits WindUp).
	Fx = {
		WindUp = 0.25, Flash = 0.05, Burst = 0.35, Fade = 0.15,
		Core = Color3.fromRGB(255, 255, 255), Glow = Color3.fromRGB(255, 140, 230), Edge = Color3.fromRGB(155, 77, 255),
		HeartShield = { WindUp = 0.15, Sound = "heart_shield" },
		RizzRush = { WindUp = 0.15, Sound = "power_rush" },
		LoveTrap = { Sound = "trap_set" },
		CharmWave = { Sound = "heart_shield", Pitch = 0.85 },
	},

	-- A pink bubble for a few seconds. It blocks the next stab: the catcher gets dizzy (slow, can't stab)
	-- and you get a burst of speed to run off. Once per round.
	HeartShield = {
		Name = "Heart Shield", Icon = "💖", Text = "Blocks one stab",
		OncePerRound = true, Lasts = 6, Dizzy = 1.5, DizzySlow = 0.5, Boost = 6, BoostTime = 1.5,
	},
	-- A burst of speed with a pink trail.
	RizzRush = {
		Name = "Rizz Rush", Icon = "⚡", Text = "Speed burst",
		Cooldown = 10, Boost = 12, Time = 1.2,
	},
	-- Drop a heart trap where you stand. The first runner who steps on it is stuck for a moment.
	-- Everyone can see the traps. Not inside the runners' start zone.
	LoveTrap = {
		Name = "Love Trap", Icon = "💘", Text = "Drop a heart trap",
		Cooldown = 9, MaxOut = 2, Hold = 1.6, Lasts = 30, Radius = 3,
	},
	-- A wave of hearts round you: runners it reaches are charmed and slow down for a bit.
	CharmWave = {
		Name = "Charm Wave", Icon = "💞", Text = "Slow runners near you",
		Cooldown = 14, Radius = 16, Slow = 0.6, Time = 2.5,
	},
}
