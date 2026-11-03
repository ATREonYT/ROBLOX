--!strict
-- The volume mixer behind the Settings sliders. Four SoundGroups in SoundService (client-local):
--   MTL_Music (cutscene / menu music), MTL_UI (Sfx.lua clicks, phone), MTL_Ambience (AmbientSound's city bed),
--   MTL_SFX (everything else: guns, cars, footsteps, jobs).
-- Any Sound that shows up without a SoundGroup is sorted into one by where it lives, so other systems don't have to
-- know about the mixer. Volumes come from the save (Settings.MusicVol / SfxVol / UIVol / AmbVol, 0-100).
--   AudioMixer.preview(key, percent)   set a group live while a slider is dragged (saving happens on release)
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local ClientData = require(script.Parent.ClientData)

local AudioMixer = {}

-- setting key -> SoundGroup name, default %
AudioMixer.Groups = {
	MusicVol = { group = "MTL_Music", default = 80 },
	SfxVol = { group = "MTL_SFX", default = 100 },
	UIVol = { group = "MTL_UI", default = 100 },
	AmbVol = { group = "MTL_Ambience", default = 100 },
}

local groups: { [string]: SoundGroup } = {}
local previewing: { [string]: number } = {}

local function group(name: string): SoundGroup
	local g = groups[name]
	if g and g.Parent then
		return g
	end
	local found = SoundService:FindFirstChild(name)
	if not (found and found:IsA("SoundGroup")) then
		local sg = Instance.new("SoundGroup")
		sg.Name = name
		sg.Volume = 1
		sg.Parent = SoundService
		found = sg
	end
	groups[name] = found :: SoundGroup
	return found :: SoundGroup
end

function AudioMixer.percent(key: string): number
	if previewing[key] then
		return previewing[key]
	end
	local d = ClientData.get()
	local v = d and d.Settings and d.Settings[key]
	local def = AudioMixer.Groups[key]
	return math.clamp(if type(v) == "number" then v else (if def then def.default else 100), 0, 100)
end

local function apply()
	for key, def in AudioMixer.Groups do
		group(def.group).Volume = AudioMixer.percent(key) / 100
	end
end

function AudioMixer.preview(key: string, percent: number?)
	previewing[key] = percent
	apply()
end

-- which group a loose Sound belongs to
local function classify(s: Sound): string
	if s.Name == "MTL_Music" or string.find(string.lower(s.Name), "music", 1, true) then
		return "MTL_Music"
	end
	local p = s.Parent
	while p and p ~= game do
		local n = p.Name
		if n == "MTL_Sfx" then
			return "MTL_UI" -- the Sfx.lua pool: clicks, phone sounds
		elseif n == "MTL_Phone" or n == "MTL_HUD" or n == "MTL_Tutorial" then
			return "MTL_UI"
		elseif string.find(string.lower(n), "music", 1, true) then
			return "MTL_Music"
		end
		p = p.Parent
	end
	return "MTL_SFX"
end

local function adopt(inst: Instance)
	if inst:IsA("Sound") and inst.SoundGroup == nil then
		-- next frame: whoever made it may set the group / name right after parenting
		task.defer(function()
			if inst.Parent and inst.SoundGroup == nil then
				inst.SoundGroup = group(classify(inst))
			end
		end)
	end
end

function AudioMixer.init()
	for _, def in AudioMixer.Groups do
		group(def.group)
	end
	apply()
	ClientData.Changed:Connect(apply)
	local roots: { Instance } = { workspace, SoundService, Players.LocalPlayer:WaitForChild("PlayerGui") }
	for _, root in roots do
		for _, d in root:GetDescendants() do
			adopt(d)
		end
		root.DescendantAdded:Connect(adopt)
	end
end

return AudioMixer
