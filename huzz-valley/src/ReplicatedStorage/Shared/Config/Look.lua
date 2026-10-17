--!strict
-- The game's lighting "look" (owner: "find the filters that make the game feel more premium"; the reference is the
-- owner's video of another game: bright, saturated, crisp colours, glowing neon; then two Oct 16 videos, Huss Valley
-- and another game, both bright and crisp to the horizon).
-- HuzzServer/LookService applies it to Lighting when the server starts (Lighting replicates to everyone).
-- Lighting.Technology can't be set by a script: the place build sets it to Future (tools/place/build_yours.luau).
-- Set Enabled = false to keep whatever Lighting the place has.
return {
	Enabled = true,
	Lighting = {
		Brightness = 2.8,
		ClockTime = 14.2, -- early afternoon: high sun, short soft shadows
		GeographicLatitude = 28,
		Ambient = Color3.fromRGB(92, 96, 112), -- shadows lifted and a touch cool, never black
		OutdoorAmbient = Color3.fromRGB(138, 140, 156),
		ColorShift_Top = Color3.fromRGB(255, 246, 228), -- warm sunlit tops
		ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
		EnvironmentDiffuseScale = 0.6,
		EnvironmentSpecularScale = 0.5,
		ShadowSoftness = 0.35,
		ExposureCompensation = 0.15,
		GlobalShadows = true,
	},
	-- Post-processing, as children of Lighting (made or updated by name)
	-- (Oct 17, "it looks still a bit bland and plain": more colour and punch, like the owner's second reference game)
	ColorCorrection = { Brightness = 0.02, Contrast = 0.14, Saturation = 0.28, TintColor = Color3.fromRGB(255, 252, 247) },
	Bloom = { Intensity = 0.55, Size = 22, Threshold = 1.5 }, -- neon and bright effects glow; plain parts don't
	SunRays = { Intensity = 0.05, Spread = 0.55 },
	-- Crisp to the horizon with a clear blue sky (was Density 0.26 / Haze 1.2, which greyed out everything far away)
	Atmosphere = { Density = 0.2, Offset = 0.1, Color = Color3.fromRGB(199, 225, 255), Decay = Color3.fromRGB(106, 150, 220), Glare = 0, Haze = 0.3 },
	DepthOfField = false, -- (off: the reference is crisp all the way to the horizon)
}
