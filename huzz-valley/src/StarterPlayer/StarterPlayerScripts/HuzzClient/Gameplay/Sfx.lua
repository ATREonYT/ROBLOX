--[[
	One place that plays the game's sound effects by name: Sfx.play("safe"), Sfx.play("step", { at = part }).
	IDs come from Config/SoundIds (our own sounds, assets/sfx); until the owner uploads them, a few play
	Roblox's built-in stand-ins (FALLBACK) and the rest stay silent. Each sound has its own level (LEVEL:
	the quiet ones are mixed low on purpose) and a little pitch spread so repeats don't sound copy-pasted.
	Everything goes through SoundService.Master.Effects, so the Settings volume slider applies.
	Not started on its own: other parts require it.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Ids = require(ReplicatedStorage:WaitForChild("Shared").Config.SoundIds)

local Sfx = {}

-- How loud each one plays (0-1) and how much its pitch may wander (+/-).
local LEVEL = {
	ui_click = { 0.35, 0.04 }, ui_hover = { 0.18, 0.05 }, ui_open = { 0.4, 0 }, ui_close = { 0.35, 0 }, ui_error = { 0.4, 0 },
	coin = { 0.45, 0.03 }, reward = { 0.55, 0 }, level_up = { 0.6, 0 },
	countdown_tick = { 0.55, 0 }, countdown_go = { 0.65, 0 },
	roulette_tick = { 0.28, 0.02 }, pick_land = { 0.6, 0 }, hero_chosen = { 0.6, 0 }, chicken_chosen = { 0.55, 0 },
	dash = { 0.45, 0.06 }, stab = { 0.5, 0.06 }, caught = { 0.5, 0 }, rescue = { 0.55, 0 }, safe = { 0.55, 0 },
	round_win = { 0.6, 0 }, round_lose = { 0.5, 0 },
	step = { 0.12, 0.1 }, heart_shield = { 0.5, 0 }, power_rush = { 0.5, 0 },
}

-- Roblox's own sounds standing in until ours are uploaded: { id, volume multiplier, pitch }.
local FALLBACK = {
	countdown_tick = { "rbxasset://sounds/electronicpingshort.wav", 0.8, 0.85 },
	countdown_go = { "rbxasset://sounds/electronicpingshort.wav", 1, 1.45 },
	roulette_tick = { "rbxasset://sounds/electronicpingshort.wav", 0.7, 1.9 },
	pick_land = { "rbxasset://sounds/electronicpingshort.wav", 1, 1.1 },
	hero_chosen = { "rbxasset://sounds/swoosh.wav", 1, 0.9 },
	chicken_chosen = { "rbxasset://sounds/swoosh.wav", 0.8, 1.3 },
	dash = { "rbxasset://sounds/swoosh.wav", 0.8, 1.35 },
	caught = { "rbxasset://sounds/uuhhh.mp3", 0.9, 1 },
	safe = { "rbxasset://sounds/electronicpingshort.wav", 1, 1.3 },
	rescue = { "rbxasset://sounds/electronicpingshort.wav", 1, 1.6 },
	round_win = { "rbxasset://sounds/electronicpingshort.wav", 1, 1.6 },
}

local function group(): SoundGroup?
	local master = SoundService:FindFirstChild("Master")
	local g = master and master:FindFirstChild("Effects")
	return if g and g:IsA("SoundGroup") then g else nil
end

local holder: Instance? = nil
local function home(): Instance
	if not (holder and holder.Parent) then
		local f = Instance.new("Folder")
		f.Name = "HuzzSfx"
		f.Parent = SoundService
		holder = f
	end
	return holder :: Instance
end

-- True when this sound has a real (uploaded) ID.
function Sfx.has(name: string): boolean
	local id = Ids[name]
	return type(id) == "string" and id ~= ""
end

-- opts: volume (multiplier), pitch (multiplier), at (a BasePart/Attachment: heard in the world from there).
function Sfx.play(name: string, opts: { volume: number?, pitch: number?, at: Instance? }?)
	local o = opts or {}
	local level = LEVEL[name] or { 0.5, 0 }
	local id, volume, pitch = Ids[name], level[1], 1
	if not (type(id) == "string" and id ~= "") then
		local f = FALLBACK[name]
		if not f then
			return nil
		end
		id, volume, pitch = f[1], volume * f[2], f[3]
	end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Volume = volume * (o.volume or 1)
	s.PlaybackSpeed = pitch * (o.pitch or 1) * (1 + (math.random() * 2 - 1) * level[2])
	s.SoundGroup = group()
	if o.at then
		s.RollOffMaxDistance = 90
		s.RollOffMinDistance = 8
	end
	s.Parent = o.at or home()
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	task.delay(4, function() -- (in case Ended never fires: a sound that failed to load)
		if s.Parent then
			s:Destroy()
		end
	end)
	return s
end

return Sfx
