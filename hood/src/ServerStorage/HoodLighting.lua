-- Lighting presets (research_notes/Front page feel and gamey stages/lighting_and_gates.md).
-- Lighting is shared by the whole place. TheBlockV2.Build() applies HoodSun for you; otherwise, in the
-- Command Bar:
--   require(game.ServerStorage.HoodLighting).Apply()              -- "HoodSun": warm side sun, cool shade (default)
--   require(game.ServerStorage.HoodLighting).Apply('HoodSoft')    -- the previous default: high sun, flatter
--   require(game.ServerStorage.HoodLighting).Apply('FrontPage')   -- the older bright, high-sun, cool-shade look
--   require(game.ServerStorage.HoodLighting).Apply('HoodCalm')    -- warm-neutral and muted
--   require(game.ServerStorage.HoodLighting).Apply('GoldenBlock') -- hood evening that stays bright (events)
--   require(game.ServerStorage.HoodLighting).Restore()            -- put back exactly what was there before
-- The first Apply saves the current Lighting setup (properties, effects, Sky, Clouds, wind) into
-- ServerStorage.HoodLightingBackup; Restore uses it.
--
-- Why the old look read dark: a 17.2 o'clock sun shading most of the street, the Realistic lighting style,
-- a beige haze at 1.6 with a dimming tint, Bloom too high for Neon to glow, and dark large surfaces.
local Lighting = game:GetService('Lighting')
local ServerStorage = game:GetService('ServerStorage')
local C = Color3.fromRGB

local L = {}

L.Presets = {
	-- Default for every map: high sun behind the camera, cool bright shade, no veil. Saturation stays low so
	-- the colour comes from the build (hood_games_maps.md: the brick street must not go candy).
	FrontPage = {
		lighting = {
			LightingStyle = Enum.LightingStyle.Soft, PrioritizeLightingQuality = true,
			ClockTime = 13, GeographicLatitude = 30, Brightness = 3, ExposureCompensation = 0.2,
			Ambient = C(128, 130, 158), OutdoorAmbient = C(162, 168, 200),
			ColorShift_Top = C(255, 238, 210), ColorShift_Bottom = C(130, 160, 225),
			EnvironmentDiffuseScale = 0.5, EnvironmentSpecularScale = 0.15, ShadowSoftness = 0.2, GlobalShadows = true,
		},
		atmosphere = { Density = 0.22, Offset = 0.6, Haze = 0.2, Glare = 0, Color = C(196, 228, 255), Decay = C(140, 180, 255) },
		grade = { Brightness = 0.04, Contrast = 0.1, Saturation = 0.08, TintColor = C(255, 255, 255) },
		bloom = { Intensity = 0.65, Size = 28, Threshold = 1.1 },
		rays = { Intensity = 0.015, Spread = 0.25 },
		sky = { SunAngularSize = 16, MoonAngularSize = 11, StarCount = 0, CelestialBodiesShown = true },
		clouds = { Cover = 0.55, Density = 0.25, Color = C(255, 255, 255) },
		wind = Vector3.new(8, 0, 4),
	},
	-- The default: FrontPage's bright high sun and crisp shade, a little softer. The ambient is a neutral grey
	-- (FrontPage's violet tinted the grey warehouse lavender), the grade adds no saturation, and the bloom only
	-- haloes real neon instead of every bright face.
	HoodSoft = {
		lighting = {
			LightingStyle = Enum.LightingStyle.Soft, PrioritizeLightingQuality = true,
			ClockTime = 13, GeographicLatitude = 30, Brightness = 2.8, ExposureCompensation = 0.15,
			Ambient = C(140, 142, 150), OutdoorAmbient = C(164, 168, 182),
			ColorShift_Top = C(255, 240, 220), ColorShift_Bottom = C(146, 156, 186),
			EnvironmentDiffuseScale = 0.45, EnvironmentSpecularScale = 0.12, ShadowSoftness = 0.25, GlobalShadows = true,
		},
		atmosphere = { Density = 0.2, Offset = 0.55, Haze = 0.15, Glare = 0, Color = C(210, 226, 242), Decay = C(160, 180, 218) },
		grade = { Brightness = 0.03, Contrast = 0.08, Saturation = -0.04, TintColor = C(255, 255, 255) },
		bloom = { Intensity = 0.45, Size = 26, Threshold = 1.15 },
		rays = { Intensity = 0.012, Spread = 0.2 },
		sky = { SunAngularSize = 16, MoonAngularSize = 11, StarCount = 0, CelestialBodiesShown = true },
		clouds = { Cover = 0.55, Density = 0.25, Color = C(255, 255, 255) },
		wind = Vector3.new(8, 0, 4),
	},
	-- The side-lit day (BRIEF13/15), the default: a warm sun from +X (morning side), direction (0.50, 0.80, 0.33): about
	-- 53 degrees up and leaning ~20 degrees to +Z (Roblox's sun rises at +X and leans to +Z by latitude - 23.5), so a
	-- street seen down -Z has its left facades well lit and its right ones in shade while both sidewalks stay in sun (the
	-- right buildings' shadow reaches 0.63 x their height across: just the grass, as ref1_street), with soft shadows; a
	-- cool ambient so shade reads blue-grey, not black; thick white clouds; a light haze at distance; bloom only on Neon.
	-- Calibrated with RENDER in render13 (Roblox's lighting model; its suggestion was Brightness 1.75 / OutdoorAmbient
	-- 92,96,108) so a lit top face shows about its own Color3: ref1_street's road and sidewalks within a few sRGB, the
	-- hall walkway on the reference's 176-184,179-187,221-227 (HoodSoft washed both out by +35..+60). Haze 0.1 keeps
	-- the far hall wall crisp. The lobby hall's shell casts no shadows, so its interior takes this light like the
	-- reference's bright, nearly shadowless hall, plus the cool PointLights in its light bars. (v4: the sun moved from
	-- ClockTime 10.5 / latitude 45 to 9.85 / 43 for brighter street facades, and Brightness rose 1.85 -> 2.0 by the
	-- ratio of the sun's old and new height, 0.86 / 0.80, so floors and roads keep their brightness.)
	HoodSun = {
		lighting = {
			LightingStyle = Enum.LightingStyle.Soft, PrioritizeLightingQuality = true,
			ClockTime = 9.85, GeographicLatitude = 43, Brightness = 2.0, ExposureCompensation = 0,
			Ambient = C(90, 93, 104), OutdoorAmbient = C(100, 105, 122),
			ColorShift_Top = C(255, 236, 210), ColorShift_Bottom = C(120, 130, 160),
			EnvironmentDiffuseScale = 0.4, EnvironmentSpecularScale = 0.15, ShadowSoftness = 0.3, GlobalShadows = true,
		},
		atmosphere = { Density = 0.2, Offset = 0.5, Haze = 0.1, Glare = 0, Color = C(210, 226, 242), Decay = C(150, 170, 210) },
		grade = { Brightness = 0.02, Contrast = 0.1, Saturation = 0.05, TintColor = C(255, 255, 255) },
		bloom = { Intensity = 0.5, Size = 24, Threshold = 1.2 },
		rays = { Intensity = 0.01, Spread = 0.2 },
		sky = { SunAngularSize = 16, MoonAngularSize = 11, StarCount = 0, CelestialBodiesShown = true },
		clouds = { Cover = 0.6, Density = 0.6, Color = C(255, 255, 255) },
		wind = Vector3.new(8, 0, 4),
	},
	-- Warm-neutral and muted (the calm pass; no longer the default). A warm grey ambient (the roofed lobby hall is lit
	-- mostly by Ambient, and FrontPage's violet doubled its floor), slightly desaturated grade, soft bloom that
	-- only haloes real neon, a light warm depth haze (research/lobby_art_direction.md, "HallCalm").
	HoodCalm = {
		lighting = {
			LightingStyle = Enum.LightingStyle.Soft, PrioritizeLightingQuality = true,
			ClockTime = 14.5, GeographicLatitude = 30, Brightness = 2.4, ExposureCompensation = 0.15,
			Ambient = C(150, 142, 132), OutdoorAmbient = C(160, 154, 146),
			ColorShift_Top = C(255, 235, 210), ColorShift_Bottom = C(110, 104, 98),
			EnvironmentDiffuseScale = 0.35, EnvironmentSpecularScale = 0.1, ShadowSoftness = 0.35, GlobalShadows = true,
		},
		atmosphere = { Density = 0.22, Offset = 0.3, Haze = 0.3, Glare = 0, Color = C(226, 216, 200), Decay = C(170, 160, 148) },
		grade = { Brightness = 0.02, Contrast = 0.06, Saturation = -0.1, TintColor = C(255, 248, 238) },
		bloom = { Intensity = 0.3, Size = 24, Threshold = 1.25 },
		rays = { Intensity = 0.01, Spread = 0.15 },
		sky = { SunAngularSize = 14, MoonAngularSize = 11, StarCount = 0, CelestialBodiesShown = true },
		clouds = { Cover = 0.5, Density = 0.22, Color = C(255, 252, 246) },
		wind = Vector3.new(6, 0, 3),
	},
	-- Evening that stays bright: peach haze instead of beige, violet shade, neon and string lights glow.
	GoldenBlock = {
		lighting = {
			LightingStyle = Enum.LightingStyle.Soft, PrioritizeLightingQuality = true,
			ClockTime = 16.3, GeographicLatitude = 30, Brightness = 2.8, ExposureCompensation = 0.3,
			Ambient = C(130, 112, 160), OutdoorAmbient = C(176, 150, 196),
			ColorShift_Top = C(255, 200, 150), ColorShift_Bottom = C(140, 130, 220),
			EnvironmentDiffuseScale = 0.5, EnvironmentSpecularScale = 0.2, ShadowSoftness = 0.2, GlobalShadows = true,
		},
		atmosphere = { Density = 0.26, Offset = 0.45, Haze = 0.9, Glare = 0.35, Color = C(255, 196, 170), Decay = C(150, 120, 220) },
		grade = { Brightness = 0.05, Contrast = 0.12, Saturation = 0.3, TintColor = C(255, 250, 245) },
		bloom = { Intensity = 0.9, Size = 32, Threshold = 1 },
		rays = { Intensity = 0.04, Spread = 0.35 },
		sky = { SunAngularSize = 16, MoonAngularSize = 11, StarCount = 0, CelestialBodiesShown = true },
		clouds = { Cover = 0.5, Density = 0.3, Color = C(255, 214, 200) },
		wind = Vector3.new(8, 0, 4),
	},
}
-- Older names still work.
L.Presets.Day = L.Presets.FrontPage
L.Presets.BlockParty = L.Presets.GoldenBlock

local EFFECTS = { atmosphere = 'Atmosphere', grade = 'ColorCorrectionEffect', bloom = 'BloomEffect', rays = 'SunRaysEffect' }
local SAVED_PROPS = {
	'LightingStyle', 'PrioritizeLightingQuality', 'ClockTime', 'GeographicLatitude', 'Brightness', 'ExposureCompensation',
	'Ambient', 'OutdoorAmbient', 'ColorShift_Top', 'ColorShift_Bottom', 'EnvironmentDiffuseScale', 'EnvironmentSpecularScale',
	'ShadowSoftness', 'GlobalShadows',
}
-- Some properties are newer than others; a place on an engine without one just skips it.
local function set(inst, prop, value) pcall(function() inst[prop] = value end) end
local function get(inst, prop)
	local ok, value = pcall(function() return inst[prop] end)
	return ok and value or nil
end

local function backup()
	if ServerStorage:FindFirstChild('HoodLightingBackup') then return end
	local folder = Instance.new('Folder')
	folder.Name = 'HoodLightingBackup'
	for _, prop in SAVED_PROPS do
		local v = get(Lighting, prop)
		if typeof(v) == 'EnumItem' then folder:SetAttribute(prop, v.Name) elseif v ~= nil then folder:SetAttribute(prop, v) end
	end
	folder:SetAttribute('GlobalWind', workspace.GlobalWind)
	-- Move the existing effects, sky and clouds aside rather than editing them, so Restore is exact.
	for _, child in Lighting:GetChildren() do
		if child:IsA('Atmosphere') or child:IsA('PostEffect') or child:IsA('Sky') then child.Parent = folder end
	end
	local clouds = workspace.Terrain:FindFirstChildOfClass('Clouds')
	if clouds then
		clouds:SetAttribute('HoodFromTerrain', true)
		clouds.Parent = folder
	end
	folder.Parent = ServerStorage
end

local function clearOurs()
	for _, child in Lighting:GetChildren() do
		if child:GetAttribute('HoodLighting') then child:Destroy() end
	end
	for _, child in workspace.Terrain:GetChildren() do
		if child:GetAttribute('HoodLighting') then child:Destroy() end
	end
end

local function make(class, name, props, parent)
	local ok, inst = pcall(Instance.new, class)
	if not ok then return nil end
	inst.Name = 'Hood' .. class
	inst:SetAttribute('HoodLighting', name)
	for prop, value in props do set(inst, prop, value) end
	inst.Parent = parent
	return inst
end

-- Apply a preset (default HoodSoft). If the sun would end up in front of players walking down the
-- street (toward -Z), the latitude flips so the lit faces of gates and facades face the player.
function L.Apply(name)
	name = name or 'HoodSun'
	local preset = L.Presets[name]
	assert(preset, 'unknown preset ' .. tostring(name))
	backup()
	for prop, value in preset.lighting do set(Lighting, prop, value) end
	clearOurs()
	for key, class in EFFECTS do make(class, name, preset[key], Lighting) end
	-- Default tonemapper ("vivid colours and high contrast"), where the engine has ColorGradingEffect.
	make('ColorGradingEffect', name, { TonemapperPreset = Enum.TonemapperPreset and Enum.TonemapperPreset.Default or nil }, Lighting)
	local sky = make('Sky', name, preset.sky, Lighting)
	if sky then sky:SetAttribute('Spin', 0.5) end -- HoodClient/WorldMotion turns the skybox slowly
	make('Clouds', name, preset.clouds, workspace.Terrain)
	workspace.GlobalWind = preset.wind
	local ok, sun = pcall(function() return Lighting:GetSunDirection() end)
	if ok and sun.Z < 0 then
		Lighting.GeographicLatitude = -preset.lighting.GeographicLatitude
	end
	pcall(function() game:GetService('ChangeHistoryService'):SetWaypoint('HoodLighting ' .. name) end)
	print('[HoodLighting] Applied ' .. name .. '. require(game.ServerStorage.HoodLighting).Restore() puts the old lighting back.')
end

function L.Restore()
	local folder = ServerStorage:FindFirstChild('HoodLightingBackup')
	if not folder then
		warn('[HoodLighting] Nothing to restore.')
		return
	end
	clearOurs()
	for _, prop in SAVED_PROPS do
		local v = folder:GetAttribute(prop)
		if v ~= nil then
			if prop == 'LightingStyle' then set(Lighting, prop, Enum.LightingStyle[v]) else set(Lighting, prop, v) end
		end
	end
	local wind = folder:GetAttribute('GlobalWind')
	if wind then workspace.GlobalWind = wind end
	for _, child in folder:GetChildren() do
		if child:GetAttribute('HoodFromTerrain') then
			child:SetAttribute('HoodFromTerrain', nil)
			child.Parent = workspace.Terrain
		else
			child.Parent = Lighting
		end
	end
	folder:Destroy()
	pcall(function() game:GetService('ChangeHistoryService'):SetWaypoint('HoodLighting restore') end)
	print('[HoodLighting] Restored the previous lighting.')
end

return L
