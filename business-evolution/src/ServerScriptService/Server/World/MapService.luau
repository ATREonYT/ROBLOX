--!strict
-- MapService — builds the whole tower into workspace.BusinessEvolutionMap at
-- startup and holds every floor's Manifest for the gameplay services
-- (RivalService reads RivalSpots, ProductivityService reads TrainingZones,
-- FloorService reads Spawn, LeaderboardService reads Boards...).
--
-- Floor geometry lives in Server/World/Floors/<FloorId>.luau modules that are
-- authored independently, so this service requires them defensively: a missing
-- or broken floor is warned about and skipped, and the rest of the tower still
-- boots. Nothing here trusts a floor module to return a perfect manifest.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Floors = require(ReplicatedStorage.Shared.Config.Floors)
local Palettes = require(ReplicatedStorage.Shared.Config.Palettes)

-- The binding manifest shape from CONTRACTS.md ("Map modules"). Floor builders
-- return this; every world-reading service consumes it through this module.
export type Manifest = {
	Spawn: CFrame,
	RivalSpots: { { DefIndex: number, Cf: CFrame } },
	TrainingZones: { { Rate: number, MinRank: number, Zone: BasePart } },
	PaydayPads: { { Segment: number, Pad: BasePart } },
	Prompts: { Shop: BasePart, Coffee: BasePart, Hr: BasePart, Elevator: BasePart },
	Boards: { Eotm: BasePart, Wins: BasePart },
}

local MAP_FOLDER_NAME = "BusinessEvolutionMap"
local SPAWN_FLOOR_ID = "Mailroom"

-- The four station prompts every floor exposes. Names are load-bearing: the
-- client Hud opens the matching UI purely off ProximityPrompt.Name.
local PROMPT_SPECS = {
	{ Key = "Shop", Name = "OpenShop", Action = "Browse Gear", Object = "Gear Shop" },
	{ Key = "Coffee", Name = "OpenCoffee", Action = "Hire Interns", Object = "Coffee Machine" },
	{ Key = "Hr", Name = "OpenHr", Action = "Restructure", Object = "HR Desk" },
	{ Key = "Elevator", Name = "OpenElevator", Action = "Ride Elevator", Object = "Elevator" },
}

local MapService = {}

local manifests: { [string]: Manifest } = {}

-- Light structural check before a manifest is trusted by other services.
-- A floor that returns garbage is dropped whole: half a manifest would crash
-- RivalService/ProductivityService far from the actual culprit.
local function isManifestShaped(manifest: any): boolean
	if type(manifest) ~= "table" then
		return false
	end
	if typeof(manifest.Spawn) ~= "CFrame" then
		return false
	end
	for _, key in { "RivalSpots", "TrainingZones", "PaydayPads", "Prompts", "Boards" } do
		if type(manifest[key]) ~= "table" then
			return false
		end
	end
	return true
end

local function attachPrompts(floorId: string, manifest: Manifest)
	for _, spec in PROMPT_SPECS do
		local part = (manifest.Prompts :: any)[spec.Key]
		if typeof(part) == "Instance" and part:IsA("BasePart") then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = spec.Name
			prompt.ActionText = spec.Action
			prompt.ObjectText = spec.Object
			-- Instant trigger: hold-to-open on a shop counter reads as lag,
			-- not as deliberation.
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt.Parent = part
		else
			warn(("[MapService] %s manifest has no %s prompt part — %s will be HUD-only there"):format(floorId, spec.Key, spec.Name))
		end
	end
end

local function buildFloor(mapFolder: Folder, floorsContainer: Instance?, floor: Floors.Floor)
	local moduleScript = if floorsContainer then floorsContainer:FindFirstChild(floor.Id) else nil
	if not moduleScript or not moduleScript:IsA("ModuleScript") then
		warn(("[MapService] no floor builder module for %q — skipping (partial world boots fine)"):format(floor.Id))
		return
	end

	local okRequire, builder = pcall(require, moduleScript)
	if not okRequire or type(builder) ~= "table" or type((builder :: any).build) ~= "function" then
		warn(("[MapService] floor module %q did not return { build = function } — skipping"):format(floor.Id))
		return
	end

	local floorFolder = Instance.new("Folder")
	floorFolder.Name = floor.Id
	floorFolder.Parent = mapFolder

	local origin = Vector3.new(floor.Origin[1], floor.Origin[2], floor.Origin[3])
	local palette = Palettes.get(floor.Id)
	local okBuild, manifest = pcall((builder :: any).build, floorFolder, origin, palette)
	if not okBuild then
		warn(("[MapService] building floor %q failed: %s"):format(floor.Id, tostring(manifest)))
		-- Half a floor is worse than no floor — nothing can stand on it safely.
		floorFolder:Destroy()
		return
	end
	if not isManifestShaped(manifest) then
		warn(("[MapService] floor %q returned a malformed manifest — dropping the floor"):format(floor.Id))
		floorFolder:Destroy()
		return
	end

	manifests[floor.Id] = manifest :: Manifest
	attachPrompts(floor.Id, manifest :: Manifest)
end

-- The one SpawnLocation in the game: everyone starts (and respawns) in the
-- Mailroom. FloorService moves characters afterwards, so a single neutral
-- spawn keeps respawn behaviour predictable.
local function createSpawn(mapFolder: Folder)
	local spawnCf: CFrame
	local mailroom = manifests[SPAWN_FLOOR_ID]
	if mailroom then
		spawnCf = mailroom.Spawn
	else
		-- The Mailroom module can be missing mid-development; players still
		-- need ground under their feet or they fall forever on join.
		warn("[MapService] no Mailroom manifest — creating a bare fallback spawn slab")
		local floor = Floors.get(SPAWN_FLOOR_ID)
		local origin = if floor then Vector3.new(floor.Origin[1], floor.Origin[2], floor.Origin[3]) else Vector3.zero
		local palette = Palettes.get(SPAWN_FLOOR_ID)
		local slab = Instance.new("Part")
		slab.Name = "FallbackSpawnSlab"
		slab.Anchored = true
		slab.Size = Vector3.new(24, 1, 24)
		slab.Color = Palettes.color(palette.Ground)
		slab.Material = Enum.Material.SmoothPlastic
		slab.CFrame = CFrame.new(origin - Vector3.new(0, 0.5, 0))
		slab.Parent = mapFolder
		spawnCf = CFrame.new(origin)
	end

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "MainSpawn"
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(8, 1, 8)
	spawnLocation.CFrame = spawnCf
	-- Invisible and non-colliding: the visual is the Kit spawnPad the floor
	-- builder placed; this part only tells Roblox where characters appear.
	spawnLocation.Transparency = 1
	spawnLocation.CanCollide = false
	spawnLocation.CanQuery = false
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Parent = mapFolder
end

local function configureLighting()
	-- Bright, even, saturated daylight (§11). The Mailroom's gloom comes from
	-- its own enclosed geometry and flickering tube, never from these globals.
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(120, 120, 125)
	Lighting.OutdoorAmbient = Color3.fromRGB(165, 163, 158)
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.35

	-- Technology is plugin-locked in some run contexts; cosmetics must never
	-- be able to kill the boot.
	pcall(function()
		local lighting: any = Lighting
		lighting.Technology = Enum.Technology.ShadowMap
	end)

	if not Lighting:FindFirstChild("MapColorCorrection") then
		local colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Name = "MapColorCorrection"
		colorCorrection.Saturation = 0.05
		colorCorrection.Contrast = 0.02
		colorCorrection.Parent = Lighting
	end
	if not Lighting:FindFirstChild("MapBloom") then
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "MapBloom"
		bloom.Intensity = 0.35
		bloom.Size = 24
		bloom.Threshold = 1.1
		bloom.Parent = Lighting
	end
end

function MapService:Init()
	-- A stale copy can survive in a saved place file; duplicate geometry would
	-- double the part count and z-fight everywhere.
	local stale = Workspace:FindFirstChild(MAP_FOLDER_NAME)
	if stale then
		stale:Destroy()
	end

	local mapFolder = Instance.new("Folder")
	mapFolder.Name = MAP_FOLDER_NAME
	mapFolder.Parent = Workspace

	local floorsContainer = script.Parent:FindFirstChild("Floors")
	if not floorsContainer then
		warn("[MapService] Server/World/Floors folder is missing — the tower will be empty")
	end

	for _, floor in Floors.List do
		buildFloor(mapFolder, floorsContainer, floor)
	end

	createSpawn(mapFolder)
	configureLighting()
end

function MapService:Start()
	-- Everything is built in Init so other services can read manifests from
	-- their own Init/Start; nothing left to do here.
end

function MapService.manifestFor(floorId: string): Manifest?
	return manifests[floorId]
end

-- Returned table is the live registry — callers must treat it as read-only.
function MapService.allManifests(): { [string]: Manifest }
	return manifests
end

return MapService
