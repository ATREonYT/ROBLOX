--!strict
-- The game's lighting "look" (owner: "find the filters that make the game feel more premium"; the reference is the
-- owner's video of another game: bright, saturated, crisp colours, glowing neon, a soft haze far away).
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
		ExposureCompensation = 0.12,
		GlobalShadows = true,
	},
	-- Post-processing, as children of Lighting (made or updated by name)
	ColorCorrection = { Brightness = 0.02, Contrast = 0.1, Saturation = 0.18, TintColor = Color3.fromRGB(255, 252, 247) },
	Bloom = { Intensity = 0.55, Size = 22, Threshold = 1.5 }, -- neon and bright effects glow; plain parts don't
	SunRays = { Intensity = 0.05, Spread = 0.55 },
	Atmosphere = { Density = 0.26, Offset = 0.12, Color = Color3.fromRGB(205, 218, 240), Decay = Color3.fromRGB(110, 125, 160), Glare = 0.15, Haze = 1.2 },
	DepthOfField = false, -- (off: the reference is crisp all the way to the horizon)
}
