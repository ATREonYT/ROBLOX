--!strict
-- Builds the whole outdoor world at startup and holds every manifest the
-- gameplay services read: the hub's bag/skin/egg pads, and each stage's enemy
-- spots, cash-out pads and barrier.
--
-- One folder, workspace.BusinessEvolutionWorld, rebuilt from scratch on boot.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Hub = require(script.Parent.Hub)
local StageBuilder = require(script.Parent.StageBuilder)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Surfaces = require(ReplicatedStorage.Shared.Config.Surfaces)
local Kit = require(script.Parent.OutdoorKit)

export type StageManifest = StageBuilder.StageManifest
export type HubManifest = Hub.HubManifest

local WORLD_FOLDER = "BusinessEvolutionWorld"

local WorldService = {}

local hubManifest: HubManifest? = nil
local stageManifests: { [number]: StageManifest } = {}

-- Lighting, to ART Part 3 exactly. Every property is set explicitly: Studio's
-- baseplate defaults differ from the class defaults, so "leave it alone" is
-- never the same as "set it to the default".
--
-- NOTE on Lighting.Technology: it is GONE (Unified Lighting replaced it with
-- LightingStyle + PrioritizeLightingQuality). Those two are set in the place
-- file via Rojo $properties, since they are not reliably scriptable; the
-- pcall below is a belt-and-braces attempt in case this engine build allows
-- it. Setting the old Technology property here would silently do nothing.
local function configureLighting()
	Lighting.Ambient = Color3.fromRGB(120, 118, 130) -- high floor = cartoon, not realistic
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 160, 185) -- cool sky bounce
	Lighting.Brightness = 2.6
	Lighting.ExposureCompensation = 0.15
	Lighting.ColorShift_Top = Color3.fromRGB(255, 236, 200) -- warm sun
	Lighting.ColorShift_Bottom = Color3.fromRGB(120, 140, 175) -- cool shadow
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.25
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.35
	Lighting.ClockTime = 15.2 -- ~45 degree sun: form reads, shadows stay short
	Lighting.GeographicLatitude = 12
	Lighting.FogEnd = 100000 -- Atmosphere owns depth; legacy Fog would fight it

	-- Unified Lighting. Soft is documented as the classic Roblox look and is
	-- the cheapest; PrioritizeLightingQuality false degrades lighting before
	-- draw distance, which is right when players must see distant stages.
	pcall(function()
		local lighting: any = Lighting
		lighting.LightingStyle = Enum.LightingStyle.Soft
		lighting.PrioritizeLightingQuality = false
	end)

	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky")
		sky.Name = "WorldSky"
		sky.SunAngularSize = 13
		sky.MoonAngularSize = 8
		sky.StarCount = 0
		sky.Parent = Lighting
	end

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	atmosphere.Name = "WorldAtmosphere"
	atmosphere.Density = 0.28 -- above 0.5 fogs the stages out
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(210, 226, 255)
	atmosphere.Decay = Color3.fromRGB(150, 175, 215)
	atmosphere.Glare = 0.15
	atmosphere.Haze = 0.9

	local function effect(className: string, name: string): Instance
		local existing = Lighting:FindFirstChild(name)
		if existing then
			return existing
		end
		local made = Instance.new(className)
		made.Name = name
		made.Parent = Lighting
		return made
	end

	local bloom = effect("BloomEffect", "WorldBloom") :: BloomEffect
	bloom.Intensity = 0.85 -- 0.6-1.0 candy look; above 1.2 smears
	bloom.Size = 32
	bloom.Threshold = 0.9

	local correction = effect("ColorCorrectionEffect", "WorldGrade") :: ColorCorrectionEffect
	correction.Saturation = 0.22
	correction.Contrast = 0.1
	correction.Brightness = 0.02
	correction.TintColor = Color3.fromRGB(255, 250, 244)

	local sun = effect("SunRaysEffect", "WorldSunRays") :: SunRaysEffect
	sun.Intensity = 0.12 -- this is not a god-ray game
	sun.Spread = 0.85

	-- Depth of field belongs in menus, never in gameplay.
	for _, child in Lighting:GetChildren() do
		if child:IsA("DepthOfFieldEffect") then
			child.Enabled = false
		end
	end

	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain and not terrain:FindFirstChildOfClass("Clouds") then
		local clouds = Instance.new("Clouds")
		clouds.Cover = 0.6
		clouds.Density = 0.5
		clouds.Color = Color3.fromRGB(252, 250, 255) -- PAPER, never pure white
		clouds.Parent = terrain
	end
end

function WorldService:Init()
	local stale = Workspace:FindFirstChild(WORLD_FOLDER)
	if stale then
		stale:Destroy()
	end

	local worldFolder = Instance.new("Folder")
	worldFolder.Name = WORLD_FOLDER
	worldFolder.Parent = Workspace

	-- Hub first: its spawn is where every player starts.
	local hubFolder = Instance.new("Folder")
	hubFolder.Name = "Hub"
	hubFolder.Parent = worldFolder
	local hubStage = Stages.get("Hub")
	assert(hubStage, "Stages config has no Hub entry")
	local hubOrigin = Vector3.new(hubStage.Origin[1], hubStage.Origin[2], hubStage.Origin[3])

	local okHub, hubResult = pcall(function()
		return Hub.build(hubFolder, hubOrigin)
	end)
	if okHub then
		hubManifest = hubResult
	else
		warn("[WorldService] hub failed to build:", hubResult)
	end

	-- Then every numbered stage. A stage that throws is skipped, not fatal:
	-- a partly-built world still lets the rest of the game be played.
	for _, stage in Stages.List do
		if stage.Number == 0 then
			continue
		end
		local folder = Instance.new("Folder")
		folder.Name = stage.Id
		folder.Parent = worldFolder
		local ok, result = pcall(function()
			return StageBuilder.build(folder, stage)
		end)
		if ok then
			stageManifests[stage.Number] = result
		else
			warn(("[WorldService] stage %s failed to build: %s"):format(stage.Id, tostring(result)))
			folder:Destroy()
		end
	end

	-- ── Connecting passes ──────────────────────────────────────────────────
	-- Areas are laid out along +X with deliberate gaps; without these the world
	-- is a chain of islands separated by open sky.
	local ordered = {}
	for _, stage in Stages.List do
		table.insert(ordered, stage)
	end
	table.sort(ordered, function(a, b)
		return a.Origin[1] < b.Origin[1]
	end)

	local passFolder = Instance.new("Folder")
	passFolder.Name = "Passes"
	passFolder.Parent = worldFolder

	for i = 1, #ordered - 1 do
		local from, to = ordered[i], ordered[i + 1]
		local fromEdge = from.Origin[1] + from.Size[1] / 2
		local toEdge = to.Origin[1] - to.Size[1] / 2
		if toEdge - fromEdge < 4 then
			continue -- already touching; nothing to bridge
		end
		-- The pass is built in the FROM area's local space and blends toward
		-- the TO area's palette, so both ends match their neighbour.
		Kit.setSurfaces(Surfaces.forStage(from.Id))
		local ok, err = pcall(function()
			Kit.connector(
				passFolder,
				CFrame.new(0, from.Origin[2], 0),
				fromEdge - 2,
				toEdge + 2,
				44,
				Kit.rgb(from.Theme.Ground),
				Kit.rgb(to.Theme.Ground),
				Kit.rgb(from.Theme.Cliff),
				Kit.rgb(to.Theme.Cliff),
				Kit.rgb(from.Theme.CliffTop),
				Kit.rgb(to.Theme.CliffTop),
				Kit.rgb(from.Theme.Plaza),
				Kit.rgb(from.Theme.Accent)
			)
		end)
		if not ok then
			warn(("[WorldService] pass %s -> %s failed: %s"):format(from.Id, to.Id, tostring(err)))
		end
	end

	-- The single spawn: everyone starts (and respawns) in the hub plaza.
	local spawnCf = if hubManifest then hubManifest.Spawn else CFrame.new(0, 8, 0)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MainSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = spawnCf
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = worldFolder

	configureLighting()
end

function WorldService:Start() end

function WorldService.hub(): HubManifest?
	return hubManifest
end

function WorldService.stage(stageNumber: number): StageManifest?
	return stageManifests[stageNumber]
end

function WorldService.allStages(): { [number]: StageManifest }
	return stageManifests
end

function WorldService.spawnCf(): CFrame
	return if hubManifest then hubManifest.Spawn else CFrame.new(0, 8, 0)
end

return WorldService
