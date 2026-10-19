--!strict
-- The Secret cutscene's sounds, keyed to its named beats rather than to seconds, so they fit at any length
-- (owner, Oct 19: "please find good sounds that fit the secret animation"; the cutscene is being re-cut shorter).
-- The shape is build -> burst -> reveal -> end. Gameplay/SecretReveal calls Sfx.beat("<Beat>") once at each beat:
--   Build  = the orb appears and the night falls (the riser and the magic bed start)
--   Burst  = the big impact, she appears (the riser is cut off right under the burst, the sparkle tail follows)
--   Reveal = she has landed and holds her pose (the musical sting: her "ta-da")
--   End    = the camera hands back (what's still ringing fades out)
-- Each cue: Slot = a Config/SoundIds name (an empty ID plays nothing), Delay = seconds after the beat,
-- FadeOn = the beat that fades it out (if it's still playing), Fade = how long that fade takes.
-- Why each sound was picked, with its source: docs/sound-picks.md. Levels: Gameplay/Sfx LEVEL.
export type Cue = { Slot: string, Delay: number?, FadeOn: string?, Fade: number? }

local SecretSounds = {}

SecretSounds.Beats = { "Build", "Burst", "Reveal", "End" }

SecretSounds.Cues = {
	Build = {
		-- a reverse-cymbal build: rises from the first beat; whatever is left of it is cut under the burst, so it
		-- always "lands" on the burst however short the build is (a riser into an impact)
		{ Slot = "secret_riser", FadeOn = "Burst", Fade = 0.12 },
		-- a soft glistening shimmer under the whole night part (18 s long, so it outlasts any cut), faded at the end
		{ Slot = "secret_shimmer", FadeOn = "End", Fade = 1.2 },
	},
	Burst = {
		{ Slot = "secret_impact" },
		-- pixie-dust twinkles drifting after the hit (8.6 s), a hair late so the impact's front is heard clean
		{ Slot = "secret_sparkle", Delay = 0.15, FadeOn = "End", Fade = 1.0 },
	},
	Reveal = {
		-- the 8 s fantasy sting (glockenspiel + orchestra) as she holds her pose; its tail may ring past the end
		{ Slot = "secret_sting", FadeOn = "End", Fade = 2.0 },
	},
	End = {},
} :: { [string]: { Cue } }

-- The cues that start at this beat (an unknown beat has none).
function SecretSounds.cues(beat: string): { Cue }
	return SecretSounds.Cues[beat] or {}
end

-- The slots this beat fades out, with each fade's length: { { slot, fade } }.
function SecretSounds.fades(beat: string): { { slot: string, fade: number } }
	local out = {}
	for _, name in SecretSounds.Beats do
		for _, cue in SecretSounds.Cues[name] or {} do
			if cue.FadeOn == beat then table.insert(out, { slot = cue.Slot, fade = cue.Fade or 0.5 }) end
		end
	end
	return out
end

return SecretSounds
