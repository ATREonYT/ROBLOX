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

-- Bright, sunny, high-contrast cartoon daylight: sun high enough for short
-- shadows, a real atmosphere so distance reads, and clouds overhead. This is
-- most of what makes the reference screenshots look "finished" rather than
-- like grey parts in a void.
local function configureLighting()
	Lighting.ClockTime = 13.6
	Lighting.GeographicLatitude = 12 -- sun high and slightly off-axis
	Lighting.Brightness = 3
	Lighting.ExposureCompensation = 0.12
	Lighting.Ambient = Color3.fromRGB(128, 130, 138)
	Lighting.OutdoorAmbient = Color3.fromRGB(158, 166, 178)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 248, 226)
	Lighting.ColorShift_Bottom = Color3.fromRGB(96, 106, 122)
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.22
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.4
	-- Fog is handled by Atmosphere below; the legacy fields would fight it.
	Lighting.FogEnd = 100000

	pcall(function()
		local lighting: any = Lighting
		lighting.Technology = Enum.Technology.Future
	end)

	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky")
		sky.Name = "WorldSky"
		sky.SunAngularSize = 12
		sky.MoonAngularSize = 8
		sky.StarCount = 0
		sky.Parent = Lighting
	end

	-- Atmosphere gives the haze that makes far-off stages feel far off.
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "WorldAtmosphere"
		atmosphere.Density = 0.28
		atmosphere.Offset = 0.1
		atmosphere.Color = Color3.fromRGB(202, 214, 232)
		atmosphere.Decay = Color3.fromRGB(148, 172, 204)
		atmosphere.Glare = 0.25
		atmosphere.Haze = 1.2
		atmosphere.Parent = Lighting
	end

	if not Lighting:FindFirstChild("WorldSunRays") then
		local rays = Instance.new("SunRaysEffect")
		rays.Name = "WorldSunRays"
		rays.Intensity = 0.14
		rays.Spread = 0.68
		rays.Parent = Lighting
	end

	if not Lighting:FindFirstChild("WorldSaturation") then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "WorldSaturation"
		cc.Saturation = 0.18 -- the reference art is punchy, not muted
		cc.Contrast = 0.08
		cc.Brightness = 0.01
		cc.TintColor = Color3.fromRGB(255, 253, 248)
		cc.Parent = Lighting
	end

	if not Lighting:FindFirstChild("WorldBloom") then
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "WorldBloom"
		bloom.Intensity = 0.5
		bloom.Size = 20
		bloom.Threshold = 1.1
		bloom.Parent = Lighting
	end

	-- Fat cartoon clouds overhead. Terrain has to exist for these to render.
	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain and not terrain:FindFirstChildOfClass("Clouds") then
		local clouds = Instance.new("Clouds")
		clouds.Cover = 0.62
		clouds.Density = 0.55
		clouds.Color = Color3.fromRGB(255, 255, 255)
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
