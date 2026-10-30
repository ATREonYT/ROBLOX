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

-- Lighting. Every property set explicitly — Studio's baseplate defaults differ
-- from the class defaults, so "leave it alone" is not the same as "default".
--
-- IMPORTANT: Lighting.Technology no longer exists. Unified Lighting replaced it
-- with LightingStyle + PrioritizeLightingQuality, and the legacy mapping is
-- Future -> Realistic + true, ShadowMap -> Soft + true. HIGH_QUALITY_LIGHTING
-- below is the one switch: true is the Future equivalent, false the ShadowMap
-- fallback. It also ships in the place file, which is where these two are
-- reliably settable.
local HIGH_QUALITY_LIGHTING = true

local function configureLighting()
	Lighting.Brightness = 2.4 -- inside the requested 2-3
	Lighting.ExposureCompensation = 0.12 -- inside 0-0.25
	Lighting.ClockTime = 15 -- afternoon: long shadows, still bright
	Lighting.GeographicLatitude = 20
	Lighting.Ambient = Color3.fromRGB(74, 78, 92) -- dark grey-blue, never black
	Lighting.OutdoorAmbient = Color3.fromRGB(126, 140, 168) -- slightly blue
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.ColorShift_Top = Color3.fromRGB(255, 240, 214) -- warm sun
	Lighting.ColorShift_Bottom = Color3.fromRGB(126, 142, 172) -- cool shadow
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.35
	Lighting.FogEnd = 100000 -- Atmosphere owns depth; legacy Fog would fight it

	pcall(function()
		local lighting: any = Lighting
		lighting.LightingStyle = if HIGH_QUALITY_LIGHTING
			then Enum.LightingStyle.Realistic
			else Enum.LightingStyle.Soft
		lighting.PrioritizeLightingQuality = HIGH_QUALITY_LIGHTING
	end)

	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky")
		sky.Name = "WorldSky"
		sky.SunAngularSize = 13
		sky.StarCount = 0
		sky.Parent = Lighting
	end

	-- Atmosphere does most of the work here: it is what gives distance.
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	atmosphere.Name = "WorldAtmosphere"
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.15
	atmosphere.Haze = 1.2
	atmosphere.Glare = 0.15
	atmosphere.Color = Color3.fromRGB(226, 222, 214) -- light warm grey
	atmosphere.Decay = Color3.fromRGB(160, 178, 208) -- slightly blue

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
	bloom.Intensity = 0.6
	bloom.Size = 20
	bloom.Threshold = 1.4 -- high enough that only genuinely bright things bloom

	local correction = effect("ColorCorrectionEffect", "WorldGrade") :: ColorCorrectionEffect
	correction.Contrast = 0.08
	correction.Saturation = 0.08
	correction.Brightness = 0
	correction.TintColor = Color3.fromRGB(255, 252, 248) -- very slightly warm

	-- Explicitly NOT wanted: sun rays and depth of field. Remove any that a
	-- previous pass left behind rather than leaving them switched on.
	for _, child in Lighting:GetChildren() do
		if child:IsA("SunRaysEffect") then
			child:Destroy()
		elseif child:IsA("DepthOfFieldEffect") then
			child.Enabled = false
		end
	end

	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain and not terrain:FindFirstChildOfClass("Clouds") then
		local clouds = Instance.new("Clouds")
		clouds.Cover = 0.55
		clouds.Density = 0.45
		clouds.Color = Color3.fromRGB(250, 248, 255)
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
