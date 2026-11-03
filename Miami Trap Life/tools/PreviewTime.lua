-- [MTL] Edit-mode preview of a time of day (Studio Command Bar or MCP execute_luau, Edit mode).
-- Applies Config/DayNight exactly like LightingController does in game, so you can look around the map at any
-- hour without pressing Play. Set HOUR below. Lamps: heads glow + a light on the nearest lamps to the camera.
-- HOUR = nil: puts the lamp heads back to how the map ships them (Neon) and removes the preview lights.
-- Run it with HOUR = nil before saving, so the map never keeps preview changes.
local HOUR = 12
local RS = game:GetService("ReplicatedStorage")
local tmp = RS.MTL:Clone() -- fresh copies (require caches)
local DayNight = require(tmp.Config.DayNight)
local Rules = require(tmp.Rules.DayNightRules)
local L = game:GetService("Lighting")
local h = HOUR or 12
local a, b, t = Rules.sample(h)
local function n(k) return a[k] + (b[k] - a[k]) * t end
local function c(k) return a[k]:Lerp(b[k], t) end
local atmo = L:FindFirstChildOfClass("Atmosphere")
local cc = L:FindFirstChild("ColorCorrection")
local bloom = L:FindFirstChildOfClass("BloomEffect")
local rays = L:FindFirstChildOfClass("SunRaysEffect")
local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
L.ClockTime = h
L.GeographicLatitude = DayNight.Latitude or L.GeographicLatitude
L.Brightness = n("Brightness"); L.ExposureCompensation = n("Exposure")
L.Ambient = c("Ambient"); L.OutdoorAmbient = c("Outdoor")
L.ColorShift_Top = c("Top"); L.ColorShift_Bottom = c("Bottom")
L.EnvironmentDiffuseScale = n("EnvDiffuse"); L.EnvironmentSpecularScale = n("EnvSpecular"); L.ShadowSoftness = n("Softness")
atmo.Density = n("Density"); atmo.Offset = n("Offset"); atmo.Color = c("AtmoColor"); atmo.Decay = c("Decay"); atmo.Glare = n("Glare"); atmo.Haze = n("Haze")
cc.Brightness = n("GBright"); cc.Contrast = n("Contrast"); cc.Saturation = n("Saturation"); cc.TintColor = c("Tint")
bloom.Intensity = n("Bloom"); bloom.Size = n("BloomSize"); bloom.Threshold = n("Threshold")
rays.Intensity = n("Rays"); rays.Spread = n("Spread")
if clouds then clouds.Cover = n("Cover"); clouds.Density = n("CloudDensity"); clouds.Color = c("CloudColor") end
-- lamps (preview only: tagged lights are removed on the next run)
for _, d in workspace:GetDescendants() do if d.Name == "MTL_PreviewLamp" then d:Destroy() end end
local lamps = n("Lamps")
local LC = DayNight.Lamps
local cam = workspace.CurrentCamera.CFrame.Position
local heads = {}
for _, m in workspace.ViceBay:GetDescendants() do
	if m:IsA("Model") and LC.Models[m.Name] then
		for _, p in m:GetChildren() do
			if p:IsA("BasePart") and (p.Material == Enum.Material.Neon or p:GetAttribute("MTL_LampHead")) then
				p:SetAttribute("MTL_LampHead", true)
				if HOUR == nil then
					p.Material = Enum.Material.Neon
					p.Color = Color3.fromRGB(255, 214, 160)
					continue
				end
				local on = lamps >= LC.On
				p.Material = Enum.Material.Neon
				p.Color = if on then LC.HeadNight else LC.HeadDay
				if not on then p.Material = Enum.Material.SmoothPlastic end
				if on then table.insert(heads, { p = p, d = (p.Position - cam).Magnitude, park = m.Name ~= "StreetLight" }) end
			end
		end
	end
end
table.sort(heads, function(x, y) return x.d < y.d end)
for i = 1, if HOUR == nil then 0 else math.min(#heads, LC.MaxLights) do
	local e = heads[i]
	local l = Instance.new(if e.park then "PointLight" else "SpotLight")
	l.Name = "MTL_PreviewLamp"
	if not e.park then l.Face = Enum.NormalId.Bottom; l.Angle = LC.Light.Angle end
	local cfg = if e.park then LC.ParkLight else LC.Light
	l.Color = cfg.Color; l.Range = cfg.Range; l.Brightness = cfg.Brightness * math.clamp((lamps - 0.3) / 0.7, 0, 1)
	l.Shadows = (not e.park) and i <= LC.Shadows
	l.Parent = e.p
end
tmp:Destroy()
return string.format("%.2f %s lamps=%.2f lit=%d", h, Rules.phaseOf(h), lamps, math.min(#heads, LC.MaxLights))
