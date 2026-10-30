-- Stone Skipping style lighting: a warm late-afternoon sun, orange haze on the
-- horizon, punchy colours and a soft glow on neon. Paste into the Command Bar.
-- The old Sky objects move to ServerStorage.OldLighting so nothing is lost.
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

Lighting.ClockTime = 16.9
Lighting.GeographicLatitude = 20
Lighting.Brightness = 2.6
Lighting.ExposureCompensation = 0
Lighting.Ambient = Color3.fromRGB(125, 100, 115)
Lighting.OutdoorAmbient = Color3.fromRGB(160, 125, 110)
Lighting.ColorShift_Top = Color3.fromRGB(255, 185, 120)
Lighting.ColorShift_Bottom = Color3.fromRGB(120, 80, 140)
Lighting.EnvironmentDiffuseScale = 0.6
Lighting.EnvironmentSpecularScale = 0.4
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.35
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
atmo.Density = 0.36
atmo.Offset = 0.2
atmo.Color = Color3.fromRGB(255, 160, 100)
atmo.Decay = Color3.fromRGB(255, 110, 160)
atmo.Glare = 0
atmo.Haze = 0.5

local cc = get("ColorCorrectionEffect", "Warmth")
cc.Saturation = 0.3
cc.Contrast = 0.1
cc.Brightness = 0
cc.TintColor = Color3.fromRGB(255, 244, 228)

-- neon stays bright but no glow spills round it, and the haze no longer washes out the eggs (Alex, Oct 30)
local bloom = get("BloomEffect", "Bloom")
-- a little more bloom so the booths' neon glows like Alex's booth pictures; the threshold keeps it on neon only
bloom.Intensity = 0.15
bloom.Size = 8
bloom.Threshold = 1.6

local rays = get("SunRaysEffect", "SunRays")
rays.Intensity = 0.03
rays.Spread = 0.6

local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
if dof then
	dof.Enabled = false
end

print("[Lighting] Stone Skipping style lighting applied")
