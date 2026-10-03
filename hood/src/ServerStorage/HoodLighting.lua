-- Lighting presets from the vibrancy research (research_notes/Tiered props VFX and vibrant maps/vibrant_maps.md).
-- Lighting is shared by the whole place, so nothing applies these automatically. In the Command Bar:
--   require(game.ServerStorage.HoodLighting).Apply('Day')        -- "Front-page Day": bright, warm sun, cool shade
--   require(game.ServerStorage.HoodLighting).Apply('BlockParty') -- golden-hour evening with glowing neon
--   require(game.ServerStorage.HoodLighting).Restore()           -- put back exactly what was there before
-- The first Apply saves the current Lighting setup into ServerStorage.HoodLightingBackup; Restore uses it.
local Lighting = game:GetService('Lighting')
local ServerStorage = game:GetService('ServerStorage')
local C = Color3.fromRGB

local L = {}

L.Presets = {
	-- Warm key, cool blue-lavender fill, haze pushed back, saturation up, bloom only on neon.
	Day = {
		lighting = {
			ClockTime = 14.5, GeographicLatitude = 35, Brightness = 3, ExposureCompensation = 0.1,
			Ambient = C(118, 122, 150), OutdoorAmbient = C(150, 158, 192),
			ColorShift_Top = C(255, 238, 210), ColorShift_Bottom = C(120, 150, 220),
			EnvironmentDiffuseScale = 0.6, EnvironmentSpecularScale = 0.25, ShadowSoftness = 0.15, GlobalShadows = true,
		},
		atmosphere = { Density = 0.26, Offset = 0.55, Haze = 0.25, Glare = 0, Color = C(196, 228, 255), Decay = C(120, 170, 255) },
		grade = { Saturation = 0.22, Contrast = 0.1, Brightness = 0.03, TintColor = C(255, 252, 246) },
		bloom = { Intensity = 0.6, Size = 28, Threshold = 1.1 },
		rays = { Intensity = 0.02, Spread = 0.3 },
	},
	-- The hood-at-dusk mood, but vibrant: peach haze instead of beige, purple decay, neon and string lights glow.
	BlockParty = {
		lighting = {
			ClockTime = 17.6, GeographicLatitude = 35, Brightness = 2.6, ExposureCompensation = 0.15,
			Ambient = C(120, 105, 150), OutdoorAmbient = C(156, 136, 176),
			ColorShift_Top = C(255, 196, 150), ColorShift_Bottom = C(130, 120, 210),
			EnvironmentDiffuseScale = 0.6, EnvironmentSpecularScale = 0.3, ShadowSoftness = 0.2, GlobalShadows = true,
		},
		atmosphere = { Density = 0.3, Offset = 0.4, Haze = 1, Glare = 0.3, Color = C(255, 190, 160), Decay = C(130, 110, 210) },
		grade = { Saturation = 0.28, Contrast = 0.12, Brightness = 0.02, TintColor = C(255, 246, 240) },
		bloom = { Intensity = 0.9, Size = 32, Threshold = 1 },
		rays = { Intensity = 0.04, Spread = 0.4 },
	},
}

local EFFECTS = { atmosphere = 'Atmosphere', grade = 'ColorCorrectionEffect', bloom = 'BloomEffect', rays = 'SunRaysEffect' }
local SAVED_PROPS = { 'ClockTime', 'GeographicLatitude', 'Brightness', 'ExposureCompensation', 'Ambient', 'OutdoorAmbient', 'ColorShift_Top', 'ColorShift_Bottom', 'EnvironmentDiffuseScale', 'EnvironmentSpecularScale', 'ShadowSoftness', 'GlobalShadows' }

local function backup()
	if ServerStorage:FindFirstChild('HoodLightingBackup') then return end
	local folder = Instance.new('Folder')
	folder.Name = 'HoodLightingBackup'
	for _, prop in SAVED_PROPS do folder:SetAttribute(prop, Lighting[prop]) end
	-- Move the existing effects aside rather than editing them, so Restore is exact.
	for _, child in Lighting:GetChildren() do
		if child:IsA('Atmosphere') or child:IsA('PostEffect') then child.Parent = folder end
	end
	folder.Parent = ServerStorage
end

function L.Apply(name)
	local preset = L.Presets[name or 'Day']
	assert(preset, 'unknown preset ' .. tostring(name))
	backup()
	for prop, value in preset.lighting do Lighting[prop] = value end
	for _, child in Lighting:GetChildren() do
		if child:GetAttribute('HoodLighting') then child:Destroy() end
	end
	for key, class in EFFECTS do
		local fx = Instance.new(class)
		fx.Name = 'Hood' .. class
		fx:SetAttribute('HoodLighting', name)
		for prop, value in preset[key] do fx[prop] = value end
		fx.Parent = Lighting
	end
	pcall(function() game:GetService('ChangeHistoryService'):SetWaypoint('HoodLighting ' .. name) end)
	print('[HoodLighting] Applied ' .. name .. '. Restore() puts the old lighting back.')
end

function L.Restore()
	local folder = ServerStorage:FindFirstChild('HoodLightingBackup')
	if not folder then
		warn('[HoodLighting] Nothing to restore.')
		return
	end
	for _, child in Lighting:GetChildren() do
		if child:GetAttribute('HoodLighting') then child:Destroy() end
	end
	for _, prop in SAVED_PROPS do
		local v = folder:GetAttribute(prop)
		if v ~= nil then Lighting[prop] = v end
	end
	for _, child in folder:GetChildren() do child.Parent = Lighting end
	folder:Destroy()
	pcall(function() game:GetService('ChangeHistoryService'):SetWaypoint('HoodLighting restore') end)
	print('[HoodLighting] Restored the previous lighting.')
end

return L
