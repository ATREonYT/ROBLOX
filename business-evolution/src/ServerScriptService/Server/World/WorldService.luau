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

export type StageManifest = StageBuilder.StageManifest
export type HubManifest = Hub.HubManifest

local WORLD_FOLDER = "BusinessEvolutionWorld"

local WorldService = {}

local hubManifest: HubManifest? = nil
local stageManifests: { [number]: StageManifest } = {}

local function configureLighting()
	-- Bright, saturated, midday: the whole genre lives in this look.
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(126, 126, 132)
	Lighting.OutdoorAmbient = Color3.fromRGB(168, 168, 164)
	Lighting.GlobalShadows = true
	Lighting.FogEnd = 4000
	pcall(function()
		local lighting: any = Lighting
		lighting.Technology = Enum.Technology.ShadowMap
	end)
	if not Lighting:FindFirstChild("WorldSky") then
		local sky = Instance.new("Sky")
		sky.Name = "WorldSky"
		sky.Parent = Lighting
	end
	if not Lighting:FindFirstChild("WorldSaturation") then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "WorldSaturation"
		cc.Saturation = 0.12
		cc.Contrast = 0.04
		cc.Parent = Lighting
	end
	if not Lighting:FindFirstChild("WorldBloom") then
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "WorldBloom"
		bloom.Intensity = 0.4
		bloom.Size = 24
		bloom.Threshold = 1.05
		bloom.Parent = Lighting
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
