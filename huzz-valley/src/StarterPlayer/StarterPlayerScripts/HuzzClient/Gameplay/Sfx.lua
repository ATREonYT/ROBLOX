--[[
	One place that plays the game's sound effects by name: Sfx.play("safe"), Sfx.play("step", { at = part }).
	IDs come from Config/SoundIds (our own sounds, assets/sfx); until the owner uploads them, some play
	Roblox's built-in stand-ins (FALLBACK, never pitched up) and the rest stay silent. Sfx.loop plays a loop. Each sound has its own level (LEVEL:
	the quiet ones are mixed low on purpose) and a little pitch spread so repeats don't sound copy-pasted.
	Everything goes through SoundService.Master.Effects, so the Settings volume slider applies.
	Not started on its own: other parts require it.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Ids = require(ReplicatedStorage:WaitForChild("Shared").Config.SoundIds)

local Sfx = {}

-- How loud each one plays (0-1) and how much its pitch may wander (+/-). Our files all have the same loudness,
-- so this table is the mix: the quiet ones (hover, ticks, steps, wind) are low on purpose.
local LEVEL = {
	ui_click = { 0.35, 0.03 }, ui_hover = { 0.15, 0.03 }, ui_open = { 0.4, 0 }, ui_close = { 0.35, 0 }, ui_error = { 0.4, 0 },
	coin = { 0.45, 0.02 }, reward = { 0.55, 0 }, level_up = { 0.6, 0 },
	countdown_tick = { 0.5, 0 }, countdown_go = { 0.6, 0 },
	roulette_tick = { 0.3, 0.02 }, pick_land = { 0.55, 0 }, hero_chosen = { 0.6, 0 }, chicken_chosen = { 0.55, 0 },
	dash = { 0.45, 0.05 }, stab = { 0.45, 0.05 }, caught = { 0.5, 0 }, rescue = { 0.55, 0 }, safe = { 0.55, 0 },
	round_win = { 0.6, 0 }, round_lose = { 0.5, 0 },
	step = { 0.12, 0.08 }, heart_shield = { 0.5, 0 }, power_rush = { 0.5, 0 },
	spin_tick = { 0.3, 0.02 }, spin_win = { 0.55, 0 }, spin_big_win = { 0.65, 0 },
	lunge = { 0.5, 0.04 }, trap_set = { 0.45, 0 }, trap_snap = { 0.55, 0 }, knock_down = { 0.55, 0 },
	revive = { 0.55, 0 }, aura_pickup = { 0.5, 0.02 }, speed_wind = { 0.22, 0 },
}

-- Roblox's own sounds standing in until ours are uploaded: { id, volume multiplier, pitch }.
-- Owner: "not some random high pitch sounds". So: never above pitch 1.1, soft clicks for the UI, and no stand-in
-- where a built-in can only sound wrong (silence beats a squeaky ping). Only built-ins every client has.
local PING = "rbxasset://sounds/electronicpingshort.wav"
local SWOOSH = "rbxasset://sounds/swoosh.wav"
local BUTTON = "rbxasset://sounds/button.wav"
local CLICK = "rbxasset://sounds/clickfast.wav"
local FALLBACK = {
	ui_click = { BUTTON, 0.5, 1 },
	ui_hover = { CLICK, 0.4, 0.9 },
	ui_open = { SWOOSH, 0.35, 1.05 },
	ui_close = { SWOOSH, 0.3, 0.85 },
	countdown_tick = { PING, 0.6, 0.8 },
	countdown_go = { PING, 0.8, 1.05 },
	roulette_tick = { CLICK, 0.6, 0.95 },
	spin_tick = { CLICK, 0.6, 0.85 },
	pick_land = { PING, 0.7, 0.9 },
	hero_chosen = { SWOOSH, 1, 0.9 },
	chicken_chosen = { SWOOSH, 0.8, 1 },
	dash = { SWOOSH, 0.8, 1.05 },
	power_rush = { SWOOSH, 0.8, 0.95 },
	lunge = { SWOOSH, 0.9, 0.8 },
	stab = { SWOOSH, 0.5, 1.1 },
	caught = { "rbxasset://sounds/uuhhh.mp3", 0.8, 1 },
	knock_down = { "rbxasset://sounds/action_jump_land.mp3", 1, 0.9 },
	trap_set = { CLICK, 0.7, 0.8 },
	trap_snap = { "rbxasset://sounds/snap.mp3", 0.8, 1 },
	safe = { PING, 0.7, 1 },
	round_win = { PING, 0.8, 1 },
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

-- A looping sound (speed_wind) that plays until you stop it: local s = Sfx.loop("speed_wind") ... s:Destroy().
-- Nil until it has an uploaded ID (loops get no stand-in). opts as for play.
function Sfx.loop(name: string, opts: { volume: number?, pitch: number?, at: Instance? }?): Sound?
	if not Sfx.has(name) then
		return nil
	end
	local o = opts or {}
	local level = LEVEL[name] or { 0.5, 0 }
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = Ids[name]
	s.Looped = true
	s.Volume = level[1] * (o.volume or 1)
	s.PlaybackSpeed = o.pitch or 1
	s.SoundGroup = group()
	if o.at then
		s.RollOffMaxDistance = 90
		s.RollOffMinDistance = 8
	end
	s.Parent = o.at or home()
	s:Play()
	return s
end

return Sfx
