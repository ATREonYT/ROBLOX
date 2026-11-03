--!strict
-- The day-night cycle and the look of every time of day (Master Plan §4 "Lighting and time of day").
-- Target look: Alex's hood references (vault: Vice Bay/References/Larp + Quality Target):
--   day     warm, slightly hazy blue sky, strong crisp shadows, a little desaturated
--   evening low gold sun, long shadows, orange-to-magenta sky, then a purple dusk
--   night   purple-blue fog, dark asphalt, warm sodium street lights and lit signs
-- The server only owns the clock (TimeService); every client draws the look itself (LightingController), so the
-- sun moves smoothly and a cutscene can show one player a different time (NextDay's morning) without touching
-- anyone else. Lighting.Technology must be Future (Studio only: Lighting > Technology).
local DayNight = {}

-- One full day in real minutes, split by phase. The clock runs at a different speed in each phase so the day gets
-- most of the real time and the night is long enough to feel, but never drags. Phases follow the clock order.
DayNight.Phases = {
	{ id = "Morning", from = 5.6, to = 9.5, minutes = 4 },
	{ id = "Day", from = 9.5, to = 16.6, minutes = 11 },
	{ id = "Evening", from = 16.6, to = 19.6, minutes = 5 },
	{ id = "Night", from = 19.6, to = 29.6, minutes = 8 }, -- to = 5.6 next day (+24)
}
DayNight.Latitude = 41 -- tilts the noon sun (Miami's real 26 puts it straight overhead: flat, shadowless streets)
DayNight.HideMapSky = true -- in game, use Roblox's soft default sky (hazy, real sunsets) instead of the place's Sky
DayNight.StartClock = 8.2 -- a fresh server starts in the morning (the first thing players see is a nice light)

-- Clock hours used by the story (local holds, see LightingController.hold)
DayNight.Story = {
	MoveIn = 21.4, -- PowerOut: you move in at night
	Sleep = 23.3, -- NextDay: the window at night before the card
	Wake = 7.0, -- NextDay: "6:58 AM", low morning sun through the boards
}

local RGB = Color3.fromRGB

-- Keyframes by clock hour (0-24). The look between two keys is blended (smoothstep). Every key lists every field.
--   Lighting: Brightness, Exposure, Ambient (indoors), Outdoor (outdoor ambient = shadow colour), Top/Bottom
--             (colour shift), EnvDiffuse, EnvSpecular, Softness (shadow softness)
--   Atmosphere: Density, Offset, AtmoColor, Decay, Glare, Haze
--   Grade (ColorCorrection): GBright, Contrast, Saturation, Tint
--   Bloom: Bloom, BloomSize, Threshold · SunRays: Rays, Spread · Clouds: Cover, CloudDensity, CloudColor
--   Lamps: 0..1, street lights and night-only neon (1 = fully on)
DayNight.Keys = {
	{
		at = 0, -- midnight
		Brightness = 2.0, Exposure = 0.45, Ambient = RGB(30, 32, 44), Outdoor = RGB(92, 96, 120),
		Top = RGB(176, 180, 208), Bottom = RGB(72, 72, 92), EnvDiffuse = 0.45, EnvSpecular = 0.7, Softness = 0.4,
		Density = 0.164, Offset = 0.06, AtmoColor = RGB(122, 120, 142), Decay = RGB(92, 90, 112), Glare = 0, Haze = 1.32,
		GBright = 0.02, Contrast = 0.1, Saturation = -0.25, Tint = RGB(236, 236, 248),
		Bloom = 0.7, BloomSize = 28, Threshold = 1.15, Rays = 0, Spread = 0.3,
		Cover = 0.72, CloudDensity = 0.4, CloudColor = RGB(84, 82, 96), Lamps = 1,
	},
	{
		at = 5.0, -- before dawn: still night, the sky starts to lift
		Brightness = 2.0, Exposure = 0.45, Ambient = RGB(32, 34, 46), Outdoor = RGB(96, 100, 124),
		Top = RGB(176, 180, 208), Bottom = RGB(74, 74, 96), EnvDiffuse = 0.4, EnvSpecular = 0.8, Softness = 0.35,
		Density = 0.164, Offset = 0.06, AtmoColor = RGB(128, 126, 148), Decay = RGB(96, 94, 116), Glare = 0, Haze = 1.32,
		GBright = 0.02, Contrast = 0.1, Saturation = -0.25, Tint = RGB(236, 236, 248),
		Bloom = 0.7, BloomSize = 28, Threshold = 1.15, Rays = 0, Spread = 0.3,
		Cover = 0.72, CloudDensity = 0.4, CloudColor = RGB(90, 88, 102), Lamps = 1,
	},
	{
		at = 6.1, -- sunrise: pink-orange sky, soft long light, lamps going off
		Brightness = 1.7, Exposure = 0.1, Ambient = RGB(52, 44, 50), Outdoor = RGB(126, 98, 112),
		Top = RGB(255, 168, 118), Bottom = RGB(96, 96, 150), EnvDiffuse = 0.7, EnvSpecular = 0.85, Softness = 0.45,
		Density = 0.156, Offset = 0.06, AtmoColor = RGB(255, 196, 172), Decay = RGB(196, 120, 146), Glare = 0.6, Haze = 2.0,
		GBright = 0.02, Contrast = 0.1, Saturation = -0.04, Tint = RGB(255, 236, 228),
		Bloom = 0.6, BloomSize = 26, Threshold = 1.3, Rays = 0.12, Spread = 0.3,
		Cover = 0.5, CloudDensity = 0.3, CloudColor = RGB(255, 206, 192), Lamps = 0.35,
	},
	{
		at = 7.4, -- morning: golden, hazy and fresh
		Brightness = 2.4, Exposure = 0.08, Ambient = RGB(54, 54, 60), Outdoor = RGB(134, 130, 140),
		Top = RGB(255, 222, 182), Bottom = RGB(140, 158, 196), EnvDiffuse = 0.9, EnvSpecular = 0.95, Softness = 0.32,
		Density = 0.161, Offset = 0.06, AtmoColor = RGB(214, 204, 192), Decay = RGB(132, 128, 136), Glare = 0.35, Haze = 2.0,
		GBright = 0.02, Contrast = 0.1, Saturation = -0.1, Tint = RGB(255, 246, 236),
		Bloom = 0.45, BloomSize = 26, Threshold = 1.6, Rays = 0.08, Spread = 0.45,
		Cover = 0.5, CloudDensity = 0.3, CloudColor = RGB(255, 248, 240), Lamps = 0,
	},
	{
		at = 9.8, -- day: bright, warm, crisp shadows, a little desaturated
		Brightness = 3.2, Exposure = -0.15, Ambient = RGB(52, 52, 58), Outdoor = RGB(128, 126, 132),
		Top = RGB(255, 244, 228), Bottom = RGB(140, 160, 196), EnvDiffuse = 0.9, EnvSpecular = 0.55, Softness = 0.18,
		Density = 0.186, Offset = 0.06, AtmoColor = RGB(205, 198, 186), Decay = RGB(150, 150, 152), Glare = 0.15, Haze = 3,
		GBright = 0.01, Contrast = 0.14, Saturation = -0.16, Tint = RGB(255, 248, 236),
		Bloom = 0.35, BloomSize = 24, Threshold = 1.8, Rays = 0.05, Spread = 0.6,
		Cover = 0.55, CloudDensity = 0.3, CloudColor = RGB(255, 255, 255), Lamps = 0,
	},
	{
		at = 15.2, -- afternoon: same as day, a touch warmer
		Brightness = 3.2, Exposure = -0.12, Ambient = RGB(54, 52, 56), Outdoor = RGB(132, 128, 130),
		Top = RGB(255, 236, 212), Bottom = RGB(140, 156, 192), EnvDiffuse = 0.9, EnvSpecular = 0.6, Softness = 0.18,
		Density = 0.186, Offset = 0.06, AtmoColor = RGB(208, 198, 184), Decay = RGB(154, 150, 148), Glare = 0.2, Haze = 3,
		GBright = 0.01, Contrast = 0.14, Saturation = -0.14, Tint = RGB(255, 246, 232),
		Bloom = 0.38, BloomSize = 24, Threshold = 1.8, Rays = 0.06, Spread = 0.55,
		Cover = 0.55, CloudDensity = 0.3, CloudColor = RGB(255, 252, 246), Lamps = 0,
	},
	{
		at = 16.9, -- golden hour: low gold sun, long shadows
		Brightness = 2.6, Exposure = 0.05, Ambient = RGB(44, 36, 38), Outdoor = RGB(140, 114, 110),
		Top = RGB(255, 196, 140), Bottom = RGB(140, 138, 182), EnvDiffuse = 0.9, EnvSpecular = 1, Softness = 0.28,
		Density = 0.186, Offset = 0.06, AtmoColor = RGB(226, 186, 150), Decay = RGB(150, 110, 100), Glare = 0.5, Haze = 2.2,
		GBright = 0.02, Contrast = 0.14, Saturation = -0.04, Tint = RGB(255, 238, 220),
		Bloom = 0.5, BloomSize = 26, Threshold = 1.4, Rays = 0.1, Spread = 0.4,
		Cover = 0.5, CloudDensity = 0.3, CloudColor = RGB(255, 228, 204), Lamps = 0,
	},
	{
		at = 17.9, -- sunset: orange to magenta, signs and lamps flicker on
		Brightness = 2.0, Exposure = 0.1, Ambient = RGB(50, 38, 46), Outdoor = RGB(140, 100, 124),
		Top = RGB(255, 142, 92), Bottom = RGB(118, 98, 172), EnvDiffuse = 0.7, EnvSpecular = 0.9, Softness = 0.38,
		Density = 0.156, Offset = 0.06, AtmoColor = RGB(250, 172, 152), Decay = RGB(170, 100, 152), Glare = 0.8, Haze = 1.38,
		GBright = 0.02, Contrast = 0.14, Saturation = 0, Tint = RGB(255, 226, 220),
		Bloom = 0.65, BloomSize = 28, Threshold = 1.3, Rays = 0.14, Spread = 0.3,
		Cover = 0.55, CloudDensity = 0.32, CloudColor = RGB(255, 172, 152), Lamps = 0.6,
	},
	{
		at = 18.7, -- dusk: purple-blue, warm windows and lamps take over
		Brightness = 1.8, Exposure = 0.35, Ambient = RGB(40, 36, 52), Outdoor = RGB(104, 98, 124),
		Top = RGB(214, 168, 190), Bottom = RGB(80, 76, 112), EnvDiffuse = 0.5, EnvSpecular = 0.8, Softness = 0.38,
		Density = 0.156, Offset = 0.06, AtmoColor = RGB(150, 136, 164), Decay = RGB(112, 98, 136), Glare = 0.2, Haze = 1.1,
		GBright = 0.01, Contrast = 0.13, Saturation = -0.03, Tint = RGB(238, 226, 255),
		Bloom = 0.7, BloomSize = 30, Threshold = 1.15, Rays = 0, Spread = 0.3,
		Cover = 0.55, CloudDensity = 0.28, CloudColor = RGB(150, 122, 172), Lamps = 1,
	},
	{
		at = 19.7, -- night
		Brightness = 2.0, Exposure = 0.45, Ambient = RGB(30, 32, 44), Outdoor = RGB(92, 96, 120),
		Top = RGB(176, 180, 208), Bottom = RGB(72, 72, 92), EnvDiffuse = 0.45, EnvSpecular = 0.7, Softness = 0.4,
		Density = 0.164, Offset = 0.06, AtmoColor = RGB(122, 120, 142), Decay = RGB(92, 90, 112), Glare = 0, Haze = 1.32,
		GBright = 0.02, Contrast = 0.1, Saturation = -0.25, Tint = RGB(236, 236, 248),
		Bloom = 0.7, BloomSize = 28, Threshold = 1.15, Rays = 0, Spread = 0.3,
		Cover = 0.72, CloudDensity = 0.4, CloudColor = RGB(84, 82, 96), Lamps = 1,
	},
}

-- Street lights (the map's "StreetLight" / "ParkLamp" models: the Neon part is the lamp head).
DayNight.Lamps = {
	Models = { StreetLight = true, ParkLamp = true },
	On = 0.5, -- Lamps value above which heads glow and lights switch on
	MaxLights = 40, -- real SpotLights at once (the closest lamps to the camera)
	Radius = 320, -- studs: lamps further than this never get a light (the glowing head still reads)
	Shadows = 6, -- the closest N of those cast shadows (Future lighting)
	Refresh = 0.4, -- seconds between nearest-lamp updates
	HeadDay = RGB(214, 210, 200), -- unlit glass by day
	HeadNight = RGB(255, 184, 112), -- sodium orange
	Light = { Color = RGB(255, 180, 110), Brightness = 3.5, Range = 60, Angle = 130 },
	ParkLight = { Color = RGB(255, 206, 150), Brightness = 2.4, Range = 28 },
}

-- Indoors (eye adaptation): when the camera has a roof over it, the exposure drops and bloom backs off, so shop and
-- flat interiors keep their shape instead of washing out white. Smooth, so walking through a door feels like eyes
-- adjusting, not a switch.
DayNight.Indoor = {
	Check = 0.25, -- seconds between roof checks (one ray straight up from the camera)
	Height = 60, -- studs: a roof within this counts as indoors
	Exposure = -0.25, -- added to ExposureCompensation indoors
	Threshold = 0.4, -- added to Bloom.Threshold indoors (whites stop glowing under strip lights)
	Blend = 0.8, -- seconds to adapt
}

-- View distance (Alex, 2026-11-02: "show the city in the background"): Atmosphere Density is kept low and Offset
-- near 0, so far blocks keep their silhouette against the sky instead of fading into it; Haze still tints the horizon.

-- Rooms (instanced interiors far from the map) - a story hold ends when you walk out of one.
DayNight.RoomArea = { MinY = 250 } -- interiors sit at Y ~400 (Config/Property.Slots); the map is far below

return DayNight
