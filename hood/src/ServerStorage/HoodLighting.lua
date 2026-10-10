-- Lighting presets (research_notes/Front page feel and gamey stages/lighting_and_gates.md).
-- Lighting is shared by the whole place. TheBlockV2.Build() applies HoodSun for you; otherwise, in the
-- Command Bar:
--   require(game.ServerStorage.HoodLighting).Apply()              -- "HoodSun": bright, soft, even simulator daylight (default)
--   require(game.ServerStorage.HoodLighting).Apply('HoodSun20')   -- LIGHT2's (BRIEF20) preset, what the user saw on 2026-10-10
--   require(game.ServerStorage.HoodLighting).Apply('HoodSoft')    -- an older default: high sun, flatter
--   require(game.ServerStorage.HoodLighting).Apply('FrontPage')   -- the older bright, high-sun, cool-shade look
--   require(game.ServerStorage.HoodLighting).Apply('HoodCalm')    -- warm-neutral and muted
--   require(game.ServerStorage.HoodLighting).Apply('GoldenBlock') -- hood evening that stays bright (events)
--   require(game.ServerStorage.HoodLighting).Restore()            -- put back exactly what was there before
-- The first Apply saves the current Lighting setup (properties, effects, Sky, Clouds, wind) into
-- ServerStorage.HoodLightingBackup; Restore uses it. Every Apply sets EVERY Lighting property the look depends on and
-- moves any other Atmosphere / Sky / post effect / Clouds into that backup, so a place saved with other settings (or
-- with effects someone added later) still gets exactly this look.
--
-- light17 (BRIEF17): Roblox ADDS ColorShift_Top to the sun (~4.5x its colour), so every preset with a bright ColorShift_Top
-- and Brightness 2-3 is ~5x brighter in Studio than it was tuned for. Scale the old presets' Brightness down ~6x before
-- using them.
-- LIGHT2 (BRIEF20): Roblox's tone curve is filmic (ACES-like) and Ambient/OutdoorAmbient carry most of the light.
-- LIGHT3 (BRIEF23), measured on the user's Studio frame brief/ref23/ours_studio_spawn.png (render13 recalibrated on it):
--   - The place renders with VOXEL lighting (the saved place says Technology = Voxel; no character shadow shows, small
--     PointLights barely show), ExposureCompensation 0.3 had no visible effect, and ColorCorrection Saturation 0.45 acted
--     like a mild boost. So HoodSun keeps ExposureCompensation at 0, puts its brightness in the light itself, and asks for
--     the same technology through every switch Roblox has (Technology, LightingStyle, PrioritizeLightingQuality).
--   - Why voxel: the simulator look is flat, bright and almost shadowless (the references show no hard cast shadows);
--     voxel's 4-stud shadows are soft, local lights stay soft (no hot pools), it is the cheapest technology, and phones
--     on low graphics quality get the same picture as a PC because the look lives in Ambient + a soft sun, not in shadow
--     maps, Bloom or SunRays (which low quality levels drop). It is also what render13 is calibrated on.
--   - To try crisp shadow-mapped sun shadows: set HoodSun.technology = 'ShadowMap' (uncalibrated; check in Studio).
--     Scripts cannot set Lighting.Technology: Apply sets it where the engine allows (the place file that
--     hood/tools/place/build_place.sh writes); in your own place set it in Properties (Lighting > Technology) if shown.
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
	-- The default (LIGHT3, BRIEF23): simulator daylight. "Its not that simulator lighting ... make the lighting way better
	-- so its nice for the eyes": bright, soft, even light; colours that read as themselves; soft shadows; no muddy shade;
	-- no white wash-out (brief/ref17/user_24 is the limit); a clean sky; the same look in the lobby and on the streets.
	--   - A high sun (65 degrees) from BEHIND a player who walks north (toward the gates, -Z): the floors and every face the
	--     player looks at (gates, signs, stand fronts, the door wall) are lit; shadows fall away from the camera; the two
	--     side walls of the hall and of every street get the same light.
	--   - A neutral Ambient = OutdoorAmbient carries ~70% of the light, so shade is only ~10% darker than sun on the walls
	--     (render13: lit 83,166,187 / shade 70,153,179 on the hall teal 126,183,193) and the floor shows a touch under its
	--     Color3 (186,188,224 -> ~175,177,217: light, not washed out). A little sky light (EnvironmentDiffuse 0.2) and a
	--     warm-white sun add shape.
	--   - ExposureCompensation 0 (it did nothing in the user's Studio). Saturation 0.65 in the grade: Studio shows
	--     ColorCorrection saturation at ~0.4 of its value (0.45 looked like ~0.18), so this is a moderate boost; reds stay
	--     red, the sky a clear blue. Contrast 0.1.
	--   - A thin blue-white Atmosphere (Haze 0.1: more whitens the far gates), Bloom only on Neon, white clouds.
	-- To brighten or darken the whole look in Studio, move Ambient and OutdoorAmbient together in steps of 6 (e.g.
	-- 172 -> 178), not ExposureCompensation (no effect with voxel lighting).
	HoodSun = {
		technology = 'Voxel',
		lighting = {
			LightingStyle = Enum.LightingStyle.Soft, PrioritizeLightingQuality = false,
			ClockTime = 12.4, GeographicLatitude = 48.5, Brightness = 0.5, ExposureCompensation = 0,
			Ambient = C(172, 172, 180), OutdoorAmbient = C(172, 172, 180),
			ColorShift_Top = C(255, 240, 220), ColorShift_Bottom = C(150, 165, 200),
			EnvironmentDiffuseScale = 0.2, EnvironmentSpecularScale = 0.1, ShadowSoftness = 0.5, GlobalShadows = true,
		},
		atmosphere = { Density = 0.18, Offset = 0.25, Haze = 0.1, Glare = 0, Color = C(215, 230, 250), Decay = C(190, 210, 240) },
		grade = { Brightness = 0, Contrast = 0.1, Saturation = 0.65, TintColor = C(255, 255, 255) },
		bloom = { Intensity = 0.5, Size = 24, Threshold = 1.1 },
		rays = { Intensity = 0.01, Spread = 0.15 },
		sky = { SunAngularSize = 14, MoonAngularSize = 11, StarCount = 0, CelestialBodiesShown = true },
		clouds = { Cover = 0.5, Density = 0.35, Color = C(255, 255, 255) },
		wind = Vector3.new(8, 0, 4),
	},
	-- LIGHT2's HoodSun (BRIEF20-22): what the user saw in Studio on 2026-10-10 (brief/ref23/ours_studio_spawn.png,
	-- "the lighting is off ... not that simulator lighting"). Comparison only. A warm side sun from +X at 53 degrees,
	-- ambient 178, ExposureCompensation 0.3 (no effect in Studio), Saturation 0.45.
	HoodSun20 = {
		lighting = {
			LightingStyle = Enum.LightingStyle.Soft, PrioritizeLightingQuality = true,
			ClockTime = 9.85, GeographicLatitude = 43, Brightness = 0.36, ExposureCompensation = 0.3,
			Ambient = C(178, 176, 172), OutdoorAmbient = C(178, 176, 172),
			ColorShift_Top = C(255, 236, 210), ColorShift_Bottom = C(120, 130, 160),
			EnvironmentDiffuseScale = 0.1, EnvironmentSpecularScale = 0.15, ShadowSoftness = 0.3, GlobalShadows = true,
		},
		atmosphere = { Density = 0.1, Offset = 0.5, Haze = 0, Glare = 0, Color = C(205, 222, 240), Decay = C(140, 165, 210) },
		grade = { Brightness = 0, Contrast = 0.14, Saturation = 0.45, TintColor = C(255, 255, 255) },
		bloom = { Intensity = 0.5, Size = 24, Threshold = 1.3 },
		rays = { Intensity = 0.01, Spread = 0.2 },
		sky = { SunAngularSize = 16, MoonAngularSize = 11, StarCount = 0, CelestialBodiesShown = true },
		clouds = { Cover = 0.6, Density = 0.6, Color = C(255, 255, 255) },
		wind = Vector3.new(8, 0, 4),
	},
	-- light17's HoodSun (BRIEF17-19): what the user saw in Studio on 2026-10-09 afternoon ("still too dark"). Comparison only.
	HoodSun17 = {
		lighting = {
			LightingStyle = Enum.LightingStyle.Soft, PrioritizeLightingQuality = true,
			ClockTime = 9.85, GeographicLatitude = 43, Brightness = 0.32, ExposureCompensation = 0,
			Ambient = C(140, 143, 155), OutdoorAmbient = C(146, 151, 170),
			ColorShift_Top = C(255, 236, 210), ColorShift_Bottom = C(120, 130, 160),
			EnvironmentDiffuseScale = 0.2, EnvironmentSpecularScale = 0.15, ShadowSoftness = 0.3, GlobalShadows = true,
		},
		atmosphere = { Density = 0.12, Offset = 0.5, Haze = 0, Glare = 0, Color = C(205, 222, 240), Decay = C(140, 165, 210) },
		grade = { Brightness = 0, Contrast = 0.1, Saturation = 0.08, TintColor = C(255, 255, 255) },
		bloom = { Intensity = 0.6, Size = 24, Threshold = 1.25 },
		rays = { Intensity = 0.01, Spread = 0.2 },
		sky = { SunAngularSize = 16, MoonAngularSize = 11, StarCount = 0, CelestialBodiesShown = true },
		clouds = { Cover = 0.6, Density = 0.6, Color = C(255, 255, 255) },
		wind = Vector3.new(8, 0, 4),
	},
	-- The HoodSun of BRIEF13-16 (what the user saw in Studio on 2026-10-09: far too bright). Kept for comparison only.
	HoodSun16 = {
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
	'Technology', 'LightingStyle', 'PrioritizeLightingQuality', 'ClockTime', 'GeographicLatitude', 'Brightness',
	'ExposureCompensation', 'Ambient', 'OutdoorAmbient', 'ColorShift_Top', 'ColorShift_Bottom', 'EnvironmentDiffuseScale',
	'EnvironmentSpecularScale', 'ShadowSoftness', 'GlobalShadows', 'FogStart', 'FogEnd', 'FogColor',
}
-- LIGHT3: one technology, asked for through every switch Roblox reads (Technology is the legacy one; LightingStyle +
-- PrioritizeLightingQuality the current ones: Soft without PrioritizeLightingQuality is voxel lighting, Soft with it
-- shadow maps, Realistic with it Future), so whichever one this engine honours, the place renders the same way.
L.Technologies = {
	Voxel = { LightingStyle = 'Soft', PrioritizeLightingQuality = false },
	ShadowMap = { LightingStyle = 'Soft', PrioritizeLightingQuality = true },
	Future = { LightingStyle = 'Realistic', PrioritizeLightingQuality = true },
}
-- Some properties are newer than others, and scripts may not write Technology (Studio's Command Bar and game scripts
-- can't; Lune, which writes hood/places/HoodEvolution.rbxl, can): a property that can't be set is skipped.
local function set(inst, prop, value) pcall(function() inst[prop] = value end) end
local function get(inst, prop)
	local ok, value = pcall(function() return inst[prop] end)
	return ok and value or nil
end
local function enumItem(enumName, itemName)
	local ok, item = pcall(function() return Enum[enumName][itemName] end)
	return ok and item or nil
end

local function backupFolder()
	local folder = ServerStorage:FindFirstChild('HoodLightingBackup')
	if folder then return folder end
	folder = Instance.new('Folder')
	folder.Name = 'HoodLightingBackup'
	for _, prop in SAVED_PROPS do
		local v = get(Lighting, prop)
		if typeof(v) == 'EnumItem' then folder:SetAttribute(prop, v.Name) elseif v ~= nil then folder:SetAttribute(prop, v) end
	end
	folder:SetAttribute('GlobalWind', workspace.GlobalWind)
	folder.Parent = ServerStorage
	return folder
end

-- Every Apply: anything in Lighting that changes the picture and isn't ours (an Atmosphere, Sky or post effect from the
-- place, a plugin or an older build) and the Terrain's own Clouds move into the backup folder, so they can't stack on
-- this look; Restore puts them back. Moved, not edited, so Restore is exact.
local function setAside(folder)
	for _, child in Lighting:GetChildren() do
		if not child:GetAttribute('HoodLighting') and (child:IsA('Atmosphere') or child:IsA('PostEffect') or child:IsA('Sky')) then
			child.Parent = folder
		end
	end
	for _, child in workspace.Terrain:GetChildren() do
		if child:IsA('Clouds') and not child:GetAttribute('HoodLighting') then
			child:SetAttribute('HoodFromTerrain', true)
			child.Parent = folder
		end
	end
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
	set(inst, 'Enabled', true)
	for prop, value in props do set(inst, prop, value) end
	inst.Parent = parent
	return inst
end

-- Apply a preset (default HoodSun). If the sun would end up in front of players walking down the street (toward
-- -Z), the latitude flips so the lit faces of gates and facades face the player.
function L.Apply(name)
	name = name or 'HoodSun'
	local preset = L.Presets[name]
	assert(preset, 'unknown preset ' .. tostring(name))
	local folder = backupFolder()
	setAside(folder)
	-- the technology first, then the preset's own properties (they win where they name the same property)
	local tech = preset.technology and L.Technologies[preset.technology]
	if tech then
		set(Lighting, 'Technology', enumItem('Technology', preset.technology))
		set(Lighting, 'LightingStyle', enumItem('LightingStyle', tech.LightingStyle))
		set(Lighting, 'PrioritizeLightingQuality', tech.PrioritizeLightingQuality)
	end
	-- the legacy fog off (an Atmosphere replaces it, but a place with a short FogEnd would still grey everything)
	set(Lighting, 'FogStart', 0)
	set(Lighting, 'FogEnd', 100000)
	for prop, value in preset.lighting do set(Lighting, prop, value) end
	clearOurs()
	for key, class in EFFECTS do
		if preset[key] then make(class, name, preset[key], Lighting) end
	end
	-- Default tonemapper ("vivid colours and high contrast"), where the engine has ColorGradingEffect.
	make('ColorGradingEffect', name, { TonemapperPreset = enumItem('TonemapperPreset', 'Default') }, Lighting)
	local sky = make('Sky', name, preset.sky, Lighting)
	if sky then sky:SetAttribute('Spin', 0.5) end -- HoodClient/WorldMotion turns the skybox slowly
	if preset.clouds then make('Clouds', name, preset.clouds, workspace.Terrain) end
	workspace.GlobalWind = preset.wind or Vector3.new(8, 0, 4)
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
			if prop == 'LightingStyle' or prop == 'Technology' then set(Lighting, prop, enumItem(prop, v)) else set(Lighting, prop, v) end
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
