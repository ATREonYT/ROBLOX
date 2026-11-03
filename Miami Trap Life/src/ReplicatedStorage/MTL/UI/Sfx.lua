--!strict
-- UI sound player for the whole game (phone, HUD, menus). Sounds are named; ids live in Theme.Sfx so a reskin
-- swaps them in one place. Client only.
--   Sfx.play("Tap")                         one-shot (small random pitch so repeats don't sound copy-pasted)
--   Sfx.play("Type", { volume = 0.3 })      per-call overrides: volume, pitch, jitter
--   local h = Sfx.loop("Ring")  h:Stop()    looping sound (ringtone)
--   Sfx.setMuted(true)                      Settings > Sound effects
--   Sfx.playId(id, { volume, pitch, max })  one-shot from a raw id (job/mission/HUD helpers use this)
-- Theme.Sfx[name] = { id = "rbxassetid://...", volume = 0.5, pitch = 1, jitter = 0.04, max = 0.8 }  ("" id = silent)
-- Every one-shot is cut with a short fade after `max` seconds (default Sfx.MAX_ONESHOT), so no SFX ever drags on.
-- max = 0 turns the cap off for one sound (only for things that must play out, like a cutscene sting).
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

local Theme = require(script.Parent.Theme)

local Sfx = {}

local library: { [string]: any } = (Theme :: any).Sfx or {}
local muted = false
local folder: Folder? = nil
local pool: { [string]: { Sound } } = {}
local POOL_SIZE = 4
local FADE = 0.12 -- seconds of fade when a one-shot hits its cap
Sfx.MAX_ONESHOT = 1.2

local TweenService = game:GetService("TweenService")
local fading: { [Sound]: Tween } = setmetatable({}, { __mode = "k" }) :: any

-- Fade a playing one-shot out at `max` seconds (if it's still the same play: pooled sounds get reused).
local function cap(snd: Sound, max: number?)
	local m = if max == nil then Sfx.MAX_ONESHOT else max
	if m <= 0 then
		return
	end
	local running = fading[snd]
	if running then -- a reused pooled sound: stop the old fade so it can't mute the new play
		running:Cancel()
		fading[snd] = nil
	end
	local token = (snd:GetAttribute("MTL_Play") or 0) + 1
	snd:SetAttribute("MTL_Play", token)
	local vol = snd.Volume
	task.delay(math.max(m - FADE, 0.05), function()
		if snd.Parent == nil or not snd.IsPlaying or snd:GetAttribute("MTL_Play") ~= token then
			return
		end
		local tw = TweenService:Create(snd, TweenInfo.new(FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Volume = 0 })
		fading[snd] = tw
		tw:Play()
		tw.Completed:Wait()
		if snd:GetAttribute("MTL_Play") == token then
			fading[snd] = nil
			snd:Stop()
			snd.Volume = vol
		end
	end)
end

local function getFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = SoundService:FindFirstChild("MTL_Sfx") :: Folder?
	if not f then
		local nf = Instance.new("Folder")
		nf.Name = "MTL_Sfx"
		nf.Parent = SoundService
		f = nf
	end
	folder = f
	return f :: Folder
end

local function spec(name: string): any?
	local s = library[name]
	if type(s) == "string" then
		s = { id = s }
	end
	if type(s) ~= "table" or type(s.id) ~= "string" or s.id == "" or s.id == "rbxassetid://0" then
		return nil
	end
	return s
end

-- a free Sound for `name` (reuses a small pool, so rapid taps overlap without making new instances)
local function take(name: string, s: any): Sound
	local list = pool[name]
	if not list then
		list = {}
		pool[name] = list
	end
	for _, snd in list do
		if not snd.IsPlaying then
			return snd
		end
	end
	if #list >= POOL_SIZE then
		local oldest = table.remove(list, 1) :: Sound
		oldest:Stop()
		table.insert(list, oldest)
		return oldest
	end
	local snd = Instance.new("Sound")
	snd.Name = name
	snd.SoundId = s.id
	snd.Parent = getFolder()
	table.insert(list, snd)
	return snd
end

function Sfx.has(name: string): boolean
	return spec(name) ~= nil
end

function Sfx.play(name: string, opts: { volume: number?, pitch: number?, jitter: number? }?): Sound?
	if muted then
		return nil
	end
	local s = spec(name)
	if not s then
		return nil
	end
	local o = opts or {}
	local snd = take(name, s)
	local jitter = o.jitter or s.jitter or 0.03
	snd.Volume = o.volume or s.volume or 0.5
	snd.PlaybackSpeed = (o.pitch or s.pitch or 1) * (1 + (math.random() * 2 - 1) * jitter)
	snd.TimePosition = s.start or 0
	snd:Play()
	cap(snd, s.max)
	return snd
end

-- One-shot from a raw id (not in Theme.Sfx). Respects mute and the length cap. Pitch never goes above 1.05
-- (Alex: no squeaky sounds).
local idPool: { [string]: { Sound } } = {}
function Sfx.playId(id: string?, opts: { volume: number?, pitch: number?, max: number? }?): Sound?
	if muted or type(id) ~= "string" or id == "" or id == "rbxassetid://0" then
		return nil
	end
	local o = opts or {}
	local list = idPool[id]
	if not list then
		list = {}
		idPool[id] = list
	end
	local snd: Sound? = nil
	for _, x in list do
		if not x.IsPlaying then
			snd = x
			break
		end
	end
	if not snd then
		if #list >= POOL_SIZE then
			snd = table.remove(list, 1)
			;(snd :: Sound):Stop()
		else
			local n = Instance.new("Sound")
			n.Name = "Id"
			n.SoundId = id
			n.Parent = getFolder()
			snd = n
		end
		table.insert(list, snd :: Sound)
	end
	local sd = snd :: Sound
	sd.Volume = o.volume or 0.5
	sd.PlaybackSpeed = math.min(o.pitch or 1, 1.05)
	sd.TimePosition = 0
	sd:Play()
	cap(sd, o.max)
	return sd
end

export type LoopHandle = { Stop: (LoopHandle) -> () }

-- Looping sound. Returns a handle with :Stop() (safe to call when muted: it just does nothing).
function Sfx.loop(name: string, opts: { volume: number? }?): LoopHandle
	local s = spec(name)
	if muted or not s then
		return { Stop = function() end }
	end
	local snd = Instance.new("Sound")
	snd.Name = name .. "_Loop"
	snd.SoundId = s.id
	snd.Looped = true
	snd.Volume = (opts and opts.volume) or s.volume or 0.5
	snd.PlaybackSpeed = s.pitch or 1
	snd.Parent = getFolder()
	snd:Play()
	return {
		Stop = function()
			snd:Stop()
			snd:Destroy()
		end,
	}
end

function Sfx.setMuted(m: boolean)
	muted = m
	if m then
		for _, p in { pool, idPool } do
			for _, list in p do
				for _, snd in list do
					snd:Stop()
				end
			end
		end
	end
end

-- Loads every sound up front so the first tap isn't silent. Call once from a client controller.
function Sfx.preload()
	task.spawn(function()
		local list = {}
		for name in library do
			local s = spec(name)
			if s then
				local snd = take(name, s)
				table.insert(list, snd)
			end
		end
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
	end)
end

return Sfx
