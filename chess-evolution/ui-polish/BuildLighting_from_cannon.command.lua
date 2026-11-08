-- Bright cartoony lighting for the island map (Alex, Oct 31: "there is alot of shadows, remove them and add
-- cartoony lighting"): a high early-afternoon sun, no cast shadows, a bright warm ambient so every side of a
-- part is lit, punchy colours and a soft glow on neon. Phones at low quality show no shadows anyway
-- (Sector Brief - Worlds, Lighting and Performance), so the map is built to read without them.
-- Paste into the Command Bar. The old Sky objects move to ServerStorage.OldLighting so nothing is lost.
local Lighting = game:GetService("Lighting")
local SS = game:GetService("ServerStorage")

local backup = SS:FindFirstChild("OldLighting") or Instance.new("Folder")
backup.Name = "OldLighting"
backup.Parent = SS

local function get(class, name)
	local x = Lighting:FindFirstChild(name)
	if x and x.ClassName ~= class then
		x = nil
	end
	if not x then
		x = Instance.new(class)
		x.Name = name
		x.Parent = Lighting
	end
	return x
end

-- The pale cartoon skybox fights the warm sky, so park it
for _, s in ipairs(Lighting:GetChildren()) do
	if s:IsA("Sky") and s.Name ~= "WarmSky" then
		s.Parent = backup
	end
end

Lighting.ClockTime = 14.2 -- a high sun: the sunny side and the shade side of a part differ only a little
Lighting.GeographicLatitude = 25
Lighting.Brightness = 2.5
Lighting.ExposureCompensation = 0
Lighting.Ambient = Color3.fromRGB(160, 150, 165)
Lighting.OutdoorAmbient = Color3.fromRGB(180, 172, 170) -- bright: the side away from the sun stays colourful
Lighting.ColorShift_Top = Color3.fromRGB(255, 225, 190)
Lighting.ColorShift_Bottom = Color3.fromRGB(140, 120, 160)
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 0.3
Lighting.GlobalShadows = false -- no cast shadows (Alex, Oct 31)
Lighting.ShadowSoftness = 1
pcall(function()
	Lighting.LightingStyle = Enum.LightingStyle.Soft
	Lighting.PrioritizeLightingQuality = true
end)

local sky = get("Sky", "WarmSky")
sky.CelestialBodiesShown = true
sky.SunAngularSize = 13
sky.MoonAngularSize = 0
sky.StarCount = 0

local atmo = get("Atmosphere", "Atmosphere")
atmo.Density = 0.24
atmo.Offset = 0.25
atmo.Color = Color3.fromRGB(255, 225, 190) -- a light warm haze, not the old sunset orange
atmo.Decay = Color3.fromRGB(150, 200, 255)
atmo.Glare = 0
atmo.Haze = 0.05 -- Oct 31: the haze turned the mountains grey; Stone Skipping's air is clear and bright

local cc = get("ColorCorrectionEffect", "Warmth")
cc.Saturation = 0.32 -- Oct 31: "fuller and brighter", like Stone Skipping's punchy colours
cc.Contrast = 0.08
cc.Brightness = 0
cc.TintColor = Color3.fromRGB(255, 250, 240)

-- neon stays bright but no glow spills round it, and the haze no longer washes out the eggs (Alex, Oct 30)
local bloom = get("BloomEffect", "Bloom")
-- a little more bloom so the booths' neon glows like Alex's booth pictures; the threshold keeps it on neon only
bloom.Intensity = 0.3 -- Oct 31: the lanterns, fires and neon glow a little more; the threshold keeps sand and white parts clean
bloom.Size = 8
bloom.Threshold = 1.6

local rays = get("SunRaysEffect", "SunRays")
rays.Intensity = 0.03
rays.Spread = 0.6

local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
if dof then
	dof.Enabled = false
end

print("[Lighting] bright cartoony lighting applied (no cast shadows)")
