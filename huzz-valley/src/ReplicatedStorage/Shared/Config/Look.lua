--!strict
-- The game's lighting "look". HuzzServer/LookService applies it to Lighting when the server starts (Lighting
-- replicates to everyone). Set Enabled = false to keep whatever Lighting the place has.
-- Lighting.Technology can't be set by a script: the place build sets it to ShadowMap (tools/place/build_yours.luau).
--
-- Oct 19 (owner: "make the lighting be one to one as the game, you see how the objects dont have light only around
-- them, there is even, nice, cartoony lighting over the map"; reference design/lobby-ref/oct19-lighting-ref.png):
-- the reference is lit evenly by the sky: shadows are light and a little blue, block sides barely darker than their
-- tops, soft small shadows under avatars, colours rich but not neon, no pools of lamp light. Measured on his
-- screenshot (tools/preview/feel/light_measure.py): a cast shadow keeps 53% of the sunlit floor's light, a block's
-- shaded side 82% of its lit top. Ours (Oct 17 recording) kept 25%: a strong sun over a weak ambient, plus Future
-- lighting, which gives every PointLight its own sharp pool and shadows. So:
--   * ShadowMap instead of Future (sun shadows stay; lamps no longer paint pools or cast their own shadows),
--   * a softer sun (Brightness 1.4) over a strong, near-white OutdoorAmbient (210) plus the sky's light at full
--     (EnvironmentDiffuseScale 1: the blue-tinted shade of the reference), less shine (EnvironmentSpecularScale),
--   * a higher sun (ClockTime 13) for short shadows, softer shadow edges,
--   * a gentle grade (Contrast 0.05, Saturation 0.12: the Oct 18 0.16 / 0.4 made orange floors look neon).
-- Model of the result (tools/preview/light: three.js, calibrated on the Oct 17 recording; not a Studio render):
-- cast shadow 0.49 on a dark floor and 0.54 on a light one (Oct 18 look: 0.32 / 0.27), sunlit floors as bright as
-- before or brighter. docs/previews/lighting-vs-ref.jpg. Only Studio shows the real thing.
-- Earlier: Oct 17 feel study (floor blown out at Brightness 2.8 / Exposure +0.15), Oct 18 "brighter contrast"
-- (2.2 / -0.05 / Contrast 0.16 / Saturation 0.4).
-- Oct 19 sky (owner: "try making the skybox better for the better lighting experience"; same reference): a saturated
-- cartoon blue overhead (about 87, 178, 249 on his screenshot), big soft white clouds low on the horizon, a clean
-- bright horizon over the sea. No uploads needed: Roblox's own sky stays, the Atmosphere paints the blue and the
-- bright horizon (Decay: the blue away from the sun; Color: the pale band at the horizon; little Haze so the sea's
-- edge stays clean), and Terrain Clouds add real 3D white puffs. Model: docs/previews/sky-vs-ref.jpg.
-- Gameplay/SecretReveal remembers whatever these are and puts them back after its night look.
return {
	Enabled = true,
	Lighting = {
		Brightness = 1.4, -- the sun: softer, so the sky's light can match it (Oct 18: 2.2)
		ClockTime = 13, -- a high sun: short, small shadows under players (was 14.2)
		GeographicLatitude = 23, -- (was 28: the sun a little higher still)
		Ambient = Color3.fromRGB(150, 150, 160), -- under roofs and in hollows: never dark (was 96, 100, 116)
		OutdoorAmbient = Color3.fromRGB(210, 210, 218), -- the even, cartoony fill everywhere outdoors (was 132, 134, 152)
		ColorShift_Top = Color3.fromRGB(255, 252, 245), -- sunlit tops, barely warm
		ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
		EnvironmentDiffuseScale = 1, -- the sky's own light in the shade: lighter, a touch blue (was 0.6)
		EnvironmentSpecularScale = 0.2, -- matte, toy-like plastic, few shiny glints (was 0.5)
		ShadowSoftness = 0.6, -- soft shadow edges (was 0.35)
		ExposureCompensation = 0.05, -- (was -0.05)
		GlobalShadows = true, -- shadows stay, just light
	},
	-- Post-processing, as children of Lighting (made or updated by name)
	ColorCorrection = { Brightness = 0, Contrast = 0.05, Saturation = 0.12, TintColor = Color3.fromRGB(255, 254, 250) }, -- (Oct 18: 0.16 / 0.4)
	Bloom = { Intensity = 0.4, Size = 24, Threshold = 1.6 }, -- neon and bright effects still glow; plain parts don't (was 0.55 / 22 / 1.5)
	SunRays = { Intensity = 0.03, Spread = 0.5 },
	-- Crisp to the horizon with a saturated cartoon blue sky (Oct 19 morning: Decay 106, 150, 220 / Offset 0.1 read
	-- as a pale, greyish blue; before that Density 0.26 / Haze 1.2 greyed out everything far away)
	Atmosphere = { Density = 0.22, Offset = 0.25, Color = Color3.fromRGB(178, 214, 255), Decay = Color3.fromRGB(85, 165, 245), Glare = 0, Haze = 0.3 },
	-- The sky (made in Lighting if the place has none). No texture IDs: Roblox's built-in sky stays.
	Sky = { CelestialBodiesShown = true, SunAngularSize = 14, MoonAngularSize = 11, StarCount = 3000 },
	-- Real 3D cartoon clouds (a Clouds object in Workspace.Terrain): white and puffy, a few big ones, mostly blue sky
	-- (Cover 0.5 in the model hid most of the blue; the reference is clear overhead with puffs low down)
	Clouds = { Enabled = true, Cover = 0.4, Density = 0.75, Color = Color3.fromRGB(255, 255, 255) },
	DepthOfField = false, -- (off: the reference is crisp all the way to the horizon)
}
