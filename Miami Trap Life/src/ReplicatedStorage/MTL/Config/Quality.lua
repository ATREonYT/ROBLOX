--!strict
-- Adaptive graphics (QualityController). Roblox won't let a game change the player's own Graphics Quality, so the
-- game scales its own extras instead: lamp lights, bloom, sun rays, far blur and dust.
-- The tier this client runs at is the player attribute MTL_QualityTier ("Low" | "Med" | "High"); any system can
-- read it (or QualityController.Changed) to scale itself.
local Quality = {}

Quality.Order = { "Low", "Med", "High" }

-- What each tier allows (LightingController + MoodFX read this)
--   LampRadius   studs: street lamps further than this from the camera keep their glowing head but no light
--   MaxLamps     real lamp lights on at once (the closest ones)
--   LampShadows  closest lamps that cast shadows
--   Bloom / SunRays   multiplier on the look's intensity (0 = effect off)
--   DistanceBlur  the far-skyline depth of field (MTL_DistanceBlur)
--   Dust         multiplier on MoodFX's floating dust motes (0 = off)
Quality.Tiers = {
	High = { LampRadius = 420, MaxLamps = 80, LampShadows = 6, Bloom = 1, SunRays = 1, DistanceBlur = true, Dust = 1 },
	Med = { LampRadius = 260, MaxLamps = 45, LampShadows = 2, Bloom = 0.8, SunRays = 0.6, DistanceBlur = false, Dust = 0.5 },
	Low = { LampRadius = 140, MaxLamps = 20, LampShadows = 0, Bloom = 0, SunRays = 0, DistanceBlur = false, Dust = 0 },
}

-- Starting tier from the player's own Graphics Quality (Roblox menu): 1-3 Low, 4-7 Med, 8-10 High.
Quality.FromLevel = { Low = 3, Med = 7 } -- level <= Low -> Low, <= Med -> Med, else High
Quality.Desktop = "High" -- Automatic with nothing readable, on a PC (the FPS watch steps it down if needed)
Quality.Console = "Med" -- gamepad only
Quality.Mobile = { Cap = "Med", SmallCap = "Low", SmallScreen = 360 } -- phone/tablet; shortest side < SmallScreen px = Low

-- FPS watch (rolling average over Window seconds)
Quality.Fps = {
	Window = 5,
	DownBelow = 40, DownFor = 5, -- under 40 for 5 s -> one tier down
	UpAbove = 57, UpFor = 30, UpCooldown = 120, -- over 57 for 30 s -> one tier up, at most once per 2 minutes
	Grace = 10, -- seconds ignored after each spawn (loading, streaming)
}

-- Phone > Settings > Graphics, saved as the number setting "Graphics" (Config/Phone.SettingKeys)
Quality.Choices = { [0] = "Auto", [1] = "Low", [2] = "Med", [3] = "High" }

return Quality
