--!strict
-- The game's lighting "look" (owner: "find the filters that make the game feel more premium"; the reference is the
-- owner's video of another game: bright, saturated, crisp colours, glowing neon; then two Oct 16 videos, Huss Valley
-- and another game, both bright and crisp to the horizon).
-- HuzzServer/LookService applies it to Lighting when the server starts (Lighting replicates to everyone).
-- Lighting.Technology can't be set by a script: the place build sets it to Future (tools/place/build_yours.luau).
-- Set Enabled = false to keep whatever Lighting the place has.
-- Oct 17 feel study (docs/feel-study.md, gap 3): the floor was blown out (mean brightness 0.76 to 0.87, 35 to 48%
-- of pixels at the top of the range, vs Huss Valley 0.62 and 15%), so lit and shaded sides looked the same and the
-- picture went flat ("bland"). Less sun and exposure bring it to mid-tone; the grade keeps the colour rich. The
-- owner's map parts keep their own colours. Estimate (tools/preview/feel/look_estimate.py on his recording):
-- lobby 0.76 -> ~0.64, round 0.87 -> ~0.72, saturation 0.56 to 0.61 -> ~0.61 to 0.65. Only Studio shows the real look.
-- Gameplay/SecretReveal remembers whatever these are and puts them back after its night look.
return {
	Enabled = true,
	Lighting = {
		Brightness = 2.0, -- was 2.8 (blown out)
		ClockTime = 14.2, -- early afternoon: high sun, short soft shadows
		GeographicLatitude = 28,
		Ambient = Color3.fromRGB(92, 96, 112), -- shadows lifted and a touch cool, never black
		OutdoorAmbient = Color3.fromRGB(128, 130, 148), -- a touch lower with the sun, so shade still reads
		ColorShift_Top = Color3.fromRGB(255, 250, 240), -- sunlit tops, barely warm (the warm cast pushed orange floors to white)
		ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
		EnvironmentDiffuseScale = 0.6,
		EnvironmentSpecularScale = 0.5,
		ShadowSoftness = 0.35,
		ExposureCompensation = -0.1, -- was +0.15
		GlobalShadows = true,
	},
	-- Post-processing, as children of Lighting (made or updated by name)
	-- (Oct 17, "it looks still a bit bland and plain": more colour and punch, like the owner's second reference game)
	-- (feel study: Brightness 0.02 -> 0, Contrast 0.14 -> 0.12, Saturation 0.28 -> 0.35 once nothing clips)
	ColorCorrection = { Brightness = 0, Contrast = 0.12, Saturation = 0.35, TintColor = Color3.fromRGB(255, 252, 247) },
	Bloom = { Intensity = 0.55, Size = 22, Threshold = 1.5 }, -- neon and bright effects glow; plain parts don't
	SunRays = { Intensity = 0.05, Spread = 0.55 },
	-- Crisp to the horizon with a clear blue sky (was Density 0.26 / Haze 1.2, which greyed out everything far away)
	Atmosphere = { Density = 0.2, Offset = 0.1, Color = Color3.fromRGB(199, 225, 255), Decay = Color3.fromRGB(106, 150, 220), Glare = 0, Haze = 0.3 },
	DepthOfField = false, -- (off: the reference is crisp all the way to the horizon)
}
