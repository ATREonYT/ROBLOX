--!strict
-- All SFX playback goes through here, keyed by Config/Sounds. Template Sounds
-- live under one SoundGroup so a future settings menu can hang a single volume
-- slider on everything at once, and so preloading has one flat list to walk.

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))
local Sounds = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Sounds")
)

-- Every SFX in Config/Sounds is a short one-shot, so this comfortably covers
-- the longest of them. Debris (not Ended) reaps clones because Ended never
-- fires for a sound that failed to load, and that must not leak instances.
local CLONE_LIFETIME_SECONDS = 8

local SoundController = {}

local trove = Trove.new()
local templates: { [string]: Sound } = {}

local function templateFor(key: string): Sound?
	local template = templates[key]
	if not template then
		-- A typo'd key should be loud in the output but never crash gameplay.
		warn(`[SoundController] unknown sound key "{key}"`)
	end
	return template
end

-- 2D playback (UI clicks, crits, fanfares).
function SoundController.play(key: string)
	local template = templateFor(key)
	if not template then
		return
	end
	-- Clone instead of replaying the template so rapid clicks overlap
	-- instead of restarting (and therefore cutting off) each other.
	local sound = template:Clone()
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, CLONE_LIFETIME_SECONDS)
end

-- 3D playback at a world position (rival defeats, teleports).
function SoundController.playAt(key: string, position: Vector3)
	local template = templateFor(key)
	if not template then
		return
	end
	-- A Sound is only positional with a BasePart ancestor, so give it a
	-- throwaway invisible one. Debris reaps part and sound together.
	local holder = Instance.new("Part")
	holder.Name = "SfxAt_" .. key
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false -- must never eat ClickController's raycasts
	holder.CanTouch = false
	holder.CastShadow = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.CFrame = CFrame.new(position)

	local sound = template:Clone()
	sound.Parent = holder
	holder.Parent = workspace
	sound:Play()
	Debris:AddItem(holder, CLONE_LIFETIME_SECONDS)
end

function SoundController:Init()
	local group = Instance.new("SoundGroup")
	group.Name = "BusinessEvolutionSfx"
	group.Parent = SoundService
	trove:Add(group)

	for key, def in Sounds do
		local sound = Instance.new("Sound")
		sound.Name = key
		sound.SoundId = def.SoundId
		sound.Volume = def.Volume
		sound.PlaybackSpeed = def.PlaybackSpeed or 1
		sound.SoundGroup = group
		sound.Parent = group
		templates[key] = sound
	end
end

function SoundController:Start()
	-- Preload so the very first click doesn't play silence while the asset
	-- streams in. Wrapped in pcall because a failed preload is cosmetic and
	-- must never take the client down.
	local list: { Instance } = {}
	for _, sound in templates do
		table.insert(list, sound)
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
	end)
end

return SoundController
