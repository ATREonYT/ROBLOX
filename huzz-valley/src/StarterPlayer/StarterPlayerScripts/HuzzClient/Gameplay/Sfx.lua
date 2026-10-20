--[[
	One place that plays the game's sound effects by name: Sfx.play("safe"), Sfx.play("step", { at = part }).
	IDs come from Config/SoundIds (our own sounds, assets/sfx); until the owner uploads them, some play
	Roblox's built-in stand-ins (FALLBACK, never pitched up) and the rest stay silent. Sfx.loop plays a loop. Each sound has its own level (LEVEL:
	the quiet ones are mixed low on purpose) and a little pitch spread so repeats don't sound copy-pasted.
	Game sounds go through SoundService.Master.Effects, button sounds (ui_*) through Master.Interface, so the
	Settings sliders apply.
	Button sounds (owner, Oct 18: "the clicking sounds ... sound glitchy, and dont feel too premium"): each is made
	once, loaded ahead and replayed (a small pool, so a quick second click never cuts the first one off mid-sound,
	which clicks); never pitch-wobbled (the same press must sound the same every time); and one press sounds once:
	a ui_* sound asked for again within UI_GAP of the last one is skipped (rapid taps don't pile up, and two
	handlers answering the same press can't double it). The stand-in click is Roblox's button.wav played lower
	(pitch 0.9) and quieter until the owner uploads ours.
	Real, researched sounds (owner, Oct 19: "find good sounds that fit the secret animation, that fit the clicking
	better ... don't create random sound by yourself"; docs/sound-picks.md): the button sounds are Kenney's CC0
	Interface Sounds (louder files than ours, so their levels are lower), and the Secret cutscene plays Roblox's
	licensed library through Sfx.beat("Build" / "Burst" / "Reveal" / "End"), the cues in Config/SecretSounds: each
	beat starts its sounds and fades out the ones that end there (a riser cut under the burst, the bed at the end).
	Every sound with a real ID is downloaded ahead (preloaded) when the game starts: a sound heard for the first time
	otherwise starts late while it downloads, and the Secret cutscene's hit must land on the burst, not after it.
	Not started on its own: other parts require it.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ids = require(Shared.Config.SoundIds)
local okSecret, SecretSounds = pcall(require, Shared.Config.SecretSounds)

local Sfx = {}

-- How loud each one plays (0-1) and how much its pitch may wander (+/-). Our files all have the same loudness,
-- so this table is the mix: the quiet ones (hover, ticks, steps, wind) are low on purpose.
local LEVEL = {
	-- (Kenney's files peak at -1 dB, ours at -3; open/close are ~6 dB louder on average than the click: measured with
	-- tools/sfx/measure_sfx.py, so they sit lower to land at the same loudness)
	ui_click = { 0.28, 0 }, ui_hover = { 0.1, 0 }, ui_open = { 0.15, 0 }, ui_close = { 0.13, 0 }, ui_error = { 0.4, 0 },
	coin = { 0.45, 0.02 }, reward = { 0.55, 0 }, level_up = { 0.6, 0 },
	countdown_tick = { 0.5, 0 }, countdown_go = { 0.6, 0 },
	roulette_tick = { 0.3, 0.02 }, pick_land = { 0.55, 0 }, hero_chosen = { 0.6, 0 }, chicken_chosen = { 0.55, 0 },
	dash = { 0.45, 0.05 }, stab = { 0.45, 0.05 }, caught = { 0.5, 0 }, rescue = { 0.55, 0 }, safe = { 0.55, 0 },
	round_win = { 0.6, 0 }, round_lose = { 0.5, 0 },
	step = { 0.3, 0.1 }, heart_shield = { 0.5, 0 }, power_rush = { 0.5, 0 },
	spin_tick = { 0.3, 0.02 }, spin_win = { 0.55, 0 }, spin_big_win = { 0.65, 0 },
	-- the 3D crate opening (Oct 20 15:13): weight first, then the reveal ring
	crate_thud = { 0.55, 0.02 }, crate_latch = { 0.45, 0 }, crate_open = { 0.6, 0 }, crate_rise = { 0.35, 0 },
	crate_reveal = { 0.55, 0 }, crate_reveal_big = { 0.65, 0 },
	lunge = { 0.5, 0.04 }, trap_set = { 0.45, 0 }, trap_snap = { 0.55, 0 }, knock_down = { 0.55, 0 },
	revive = { 0.55, 0 }, aura_pickup = { 0.5, 0.02 }, speed_wind = { 0.22, 0 },
	-- the Oct 19 powers and the heartbeat (Gameplay/Heartbeat sets its own volume by how close the catcher is)
	trap_throw = { 0.45, 0 }, invisible = { 0.45, 0 }, glitch = { 0.45, 0 }, decoy = { 0.45, 0 }, heartbeat = { 0.5, 0 },
	-- the Secret cutscene (Roblox's library: first guesses from the listings, tune after hearing them in Studio;
	-- the bed and the tail stay well under the hit and the sting, nothing jumps out)
	secret_riser = { 0.45, 0 }, secret_shimmer = { 0.18, 0 }, secret_impact = { 0.55, 0 },
	secret_sparkle = { 0.3, 0 }, secret_sting = { 0.5, 0 }, secret_land = { 0.5, 0 },
	-- the Combine machine's merge (Gameplay/CombineMachine; others' merges play from the machine)
	combine_charge = { 0.45, 0 }, combine_merge = { 0.55, 0 }, combine_reveal = { 0.5, 0 },
}

-- Sounds longer than 4 s (a stuck sound is cleared after this many seconds, or 4).
local LIFE = { secret_riser = 8, secret_shimmer = 20, secret_sparkle = 11, secret_sting = 11 }

-- Roblox's own sounds standing in until ours are uploaded: { id, volume multiplier, pitch }.
-- Owner: "not some random high pitch sounds". So: never above pitch 1.1, soft clicks for the UI, and no stand-in
-- where a built-in can only sound wrong (silence beats a squeaky ping). Only built-ins every client has.
local PING = "rbxasset://sounds/electronicpingshort.wav"
-- (Roblox's swoosh.wav is refused in Studio: "Asset is not approved for the requester", so no swoosh stand-in.)
local BUTTON = "rbxasset://sounds/button.wav"
local CLICK = "rbxasset://sounds/clickfast.wav"
local FALLBACK = {
	ui_click = { BUTTON, 0.45, 0.9 }, -- (a little lower and softer than as shipped: rounder, less clicky)
	ui_hover = { CLICK, 0.4, 0.9 },
	countdown_tick = { PING, 0.6, 0.8 },
	countdown_go = { PING, 0.8, 1.05 },
	roulette_tick = { CLICK, 0.6, 0.95 },
	spin_tick = { CLICK, 0.6, 0.85 },
	pick_land = { PING, 0.7, 0.9 },
	caught = { "rbxasset://sounds/uuhhh.mp3", 0.8, 1 },
	knock_down = { "rbxasset://sounds/action_jump_land.mp3", 1, 0.9 },
	trap_set = { CLICK, 0.7, 0.8 },
	step = { "rbxasset://sounds/action_jump_land.mp3", 0.8, 1.05 }, -- (a soft thud: not Roblox's running loop)
	trap_snap = { "rbxasset://sounds/snap.mp3", 0.8, 1 },
	safe = { PING, 0.7, 1 },
	round_win = { PING, 0.8, 1 },
	-- the powers and the Aura stars (Oct 17 feel pass: "make the usage of items smoother"; a power with no sound
	-- read as nothing happening): soft, low pings until ours are uploaded
	heart_shield = { PING, 0.55, 0.85 },
	power_rush = { "rbxasset://sounds/action_jump.mp3", 0.9, 1.05 },
	aura_pickup = { PING, 0.45, 1.1 },
	-- Oct 19: the heartbeat is a soft low thump (Roblox's landing thud played low), the new powers soft and low
	heartbeat = { "rbxasset://sounds/action_jump_land.mp3", 1, 0.55 },
	trap_throw = { "rbxasset://sounds/action_jump.mp3", 0.8, 0.85 },
	invisible = { PING, 0.45, 0.7 },
	glitch = { CLICK, 0.7, 0.75 },
	decoy = { PING, 0.45, 0.8 },
	-- the 3D crate opening (Oct 20 15:13): low thuds and a soft low ping until ours are uploaded (no stand-in for the
	-- knife's rise: silence beats a wrong sound)
	crate_thud = { "rbxasset://sounds/action_jump_land.mp3", 1, 0.7 },
	crate_latch = { CLICK, 0.6, 0.8 },
	crate_open = { "rbxasset://sounds/action_jump_land.mp3", 1, 0.6 },
	crate_reveal = { PING, 0.6, 0.9 },
	crate_reveal_big = { PING, 0.7, 0.8 },
	-- the Combine machine: the burst borrows the Secret cutscene's licensed "Magic Burst 2" (Config/SoundIds
	-- secret_impact) and the reveal a soft low ping until ours are uploaded; the charge stays silent
	combine_merge = { "rbxassetid://9116384799", 0.6, 1 },
	combine_reveal = { PING, 0.4, 0.9 },
}

-- Button and menu sounds go through the Interface group (Settings > Audio > Button Sounds), the rest through Effects.
local function group(name: string?): SoundGroup?
	local master = SoundService:FindFirstChild("Master")
	local g = master and master:FindFirstChild(if name and string.sub(name, 1, 3) == "ui_" then "Interface" else "Effects")
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

local function source(name: string): (string?, number, number)
	local level = LEVEL[name] or { 0.5, 0 }
	local id = Ids[name]
	if type(id) == "string" and id ~= "" then return id, level[1], 1 end
	local f = FALLBACK[name]
	if not f then return nil, 0, 1 end
	return f[1], level[1] * f[2], f[3]
end

-- UI sounds are made once, loaded ahead and replayed, so a click sounds the moment you press (owner: "make the sound
-- for buttons not delayed"; a new Sound per click had to load first). A few copies each, so a fast second click
-- starts a fresh copy instead of restarting one that's still sounding (a cut-off sound clicks).
local UI = { ui_click = 3, ui_hover = 2, ui_open = 2, ui_close = 2, ui_error = 2 }
-- One press = one sound: the same ui_* sound again within this many seconds is skipped (owner: "glitchy").
local UI_GAP = { ui_click = 0.08, ui_hover = 0.06, ui_open = 0.15, ui_close = 0.15, ui_error = 0.15 }
Sfx.UI_GAP = UI_GAP
local ready: { [string]: { Sound } } = {}
local turn: { [string]: number } = {}
local lastAt: { [string]: number } = {}

-- True when a ui_* sound may play now (and notes the time): false inside its UI_GAP. now: os.clock() by default.
function Sfx.allow(name: string, now: number?): boolean
	local gap = UI_GAP[name]
	if not gap then return true end
	local t = now or os.clock()
	if lastAt[name] and t - lastAt[name] < gap then return false end
	lastAt[name] = t
	return true
end
local function readyCopies(name: string): { Sound }?
	local list = ready[name]
	if list and list[1] and list[1].Parent then return list end
	local id, volume, pitch = source(name)
	if not id then return nil end
	list = {}
	for i = 1, UI[name] do
		local s = Instance.new("Sound")
		s.Name = name .. i
		s.SoundId = id
		s.Volume = volume
		s.PlaybackSpeed = pitch
		local g = group(name)
		if g then s.SoundGroup = g end
		s.Parent = home()
		list[i] = s
	end
	ready[name] = list
	return list
end
task.defer(function()
	local all = {}
	for name in UI do
		for _, s in readyCopies(name) or {} do table.insert(all, s) end
	end
	-- and every other sound with a real ID (the Secret cutscene's, uploaded game sounds), by its content ID
	for name, id in Ids do
		if not UI[name] and type(id) == "string" and id ~= "" then table.insert(all, id) end
	end
	pcall(function() game:GetService("ContentProvider"):PreloadAsync(all) end)
end)

-- opts: volume (multiplier), pitch (multiplier), at (a BasePart/Attachment: heard in the world from there),
-- from (seconds into the sound to start at: the Secret riser starts partway in so its top lands on the burst).
function Sfx.play(name: string, opts: { volume: number?, pitch: number?, at: Instance?, from: number? }?)
	local o = opts or {}
	local level = LEVEL[name] or { 0.5, 0 }
	if UI[name] and not o.at then
		local list = readyCopies(name)
		if not list then return nil end
		if not Sfx.allow(name) then return nil end
		turn[name] = (turn[name] or 0) % #list + 1
		local s = list[turn[name]]
		local id, volume, pitch = source(name)
		local g = group(name)
		if g then s.SoundGroup = g end
		s.Volume = volume * (o.volume or 1)
		s.PlaybackSpeed = pitch * (o.pitch or 1) * (1 + (math.random() * 2 - 1) * level[2])
		s.TimePosition = 0
		s:Play()
		return s
	end
	local id, volume, pitch = source(name)
	if not id then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Volume = volume * (o.volume or 1)
	s.PlaybackSpeed = pitch * (o.pitch or 1) * (1 + (math.random() * 2 - 1) * level[2])
	local g = group(name)
	if g then s.SoundGroup = g end
	if o.at then
		s.RollOffMaxDistance = 90
		s.RollOffMinDistance = 8
	end
	s.Parent = o.at or home()
	local from = o.from
	if from and from > 0 then
		local t0 = os.clock()
		pcall(function() s.TimePosition = from end)
		-- (a sound that isn't loaded yet may drop the start point: set it again, plus the time it took, once loaded)
		pcall(function()
			if not s.IsLoaded then
				s.Loaded:Once(function() s.TimePosition = from + (os.clock() - t0) end)
			end
		end)
	end
	s:Play()
	pcall(function() -- (guarded: the offline preview's copy of the Roblox API has no Ended)
		s.Ended:Once(function()
			s:Destroy()
		end)
	end)
	task.delay(LIFE[name] or 4, function() -- (in case Ended never fires: a sound that failed to load)
		if s.Parent then
			s:Destroy()
		end
	end)
	return s
end

-- Fades a playing sound to silence over `time` seconds, then removes it.
local function fadeOut(s: Sound, time: number)
	task.spawn(function()
		local from, t0 = s.Volume, os.clock()
		while s.Parent do
			local x = if time > 0 then math.min((os.clock() - t0) / time, 1) else 1
			s.Volume = from * (1 - x)
			if x >= 1 then break end
			task.wait(0.03)
		end
		pcall(function() s:Stop() end)
		s:Destroy()
	end)
end

-- The Secret cutscene's sounds by beat (Config/SecretSounds): Sfx.beat("Build"), "Burst", "Reveal", "End".
-- Each beat first fades out the sounds that end there, then starts its own (after their Delay).
-- nextIn = seconds until the next beat (the cutscene knows it): a cue with a Peak (the moment in its file where it
-- tops out) starts that far in, or that much later, so its top lands exactly on the next beat (the riser on the burst).
local live: { [string]: Sound } = {} -- the playing sound of each secret slot
function Sfx.beat(beat: string, nextIn: number?)
	if not okSecret or type(SecretSounds) ~= "table" then return end
	for _, f in SecretSounds.fades(beat) do
		local s = live[f.slot]
		live[f.slot] = nil
		if s and s.Parent then fadeOut(s, f.fade) end
	end
	for _, cue in SecretSounds.cues(beat) do
		local from: number? = nil
		local function start()
			local old = live[cue.Slot]
			if old and old.Parent then fadeOut(old, 0.1) end -- (a replay never doubles a sound)
			-- (guarded: a sound that fails must never stop the cutscene that asked for it)
			local ok, s = pcall(Sfx.play, cue.Slot, { from = from })
			live[cue.Slot] = if ok then s else nil
		end
		local wait = cue.Delay or 0
		if cue.Peak and nextIn then
			local lead = cue.Peak - nextIn
			if lead > 0 then from = lead else wait += -lead end
		end
		if wait > 0 then task.delay(wait, start) else start() end
	end
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
	local g = group(name)
	if g then s.SoundGroup = g end
	if o.at then
		s.RollOffMaxDistance = 90
		s.RollOffMinDistance = 8
	end
	s.Parent = o.at or home()
	s:Play()
	return s
end

return Sfx
