--[[
	Sfx  (ModuleScript, child of GameClient)
	Plays the game's sounds by name: Sfx.play("Click"). Kit.playSound(name) calls this, so every older call works.

	Where each sound comes from (GameConfig.Sounds holds the ids):
	  * Button sounds (Click, Hover, Open, Close, Confirm, Error, Tab): Kenney "Interface Sounds" (CC0), the same
	    family Alex picked for Huzz Valley, in cannon-evolution/assets/sfx/UI_*.ogg. They need Alex's upload; until
	    then they stay silent (or a licensed pick in GameConfig plays instead).
	  * Hatch: "Magic Burst 2" from Roblox's free licensed library (Pro Sound Effects): public, plays as it is.
	  * Launch, Skip, Reward, Rebirth: Roblox's licensed library too (picked in Studio's Toolbox, Oct 30).
	  * Shot: a low built-in thump until a licensed pick goes into GameConfig. Coin: silent until then.
	  * Both groups have a soft high cut and a gentle compressor (warmer, nothing jumps out).

	Rules (vault: UI Motion Language, Sound Design Pitfalls; Huzz Valley's button notes):
	  * Button sounds are never pitch-wobbled (the same press sounds the same); game sounds get a small spread so
	    repeats don't sound copy-pasted.
	  * One press sounds once: a button sound asked for again within GAP seconds is skipped (two handlers on the
	    same press, or fast taps, don't pile up).
	  * A small pool per sound, so a second play never cuts the first off mid-sound (that clicks).
	  * Everything is preloaded at start: a sound heard for the first time otherwise starts late.
	  * Two SoundGroups (Interface, Effects) under SoundService > CannonSfx; the Sound Effects setting mutes both.
]]

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))

local Sfx = {}

-- name = { volume, pitch spread (+/-), group }. Our files are all about the same loudness, so this is the mix:
-- hover is barely there, clicks sit under the game sounds, the big moments are loudest.
local LEVEL = {
	Click = { 0.3, 0, "Interface" },
	Hover = { 0.1, 0, "Interface" },
	Open = { 0.16, 0, "Interface" },
	Close = { 0.14, 0, "Interface" },
	Confirm = { 0.3, 0, "Interface" },
	Error = { 0.3, 0, "Interface" },
	Tab = { 0.25, 0, "Interface" },
	Coin = { 0.25, 0.03, "Effects" },
	Reward = { 0.45, 0, "Effects" },
	Hatch = { 0.4, 0, "Effects" },
	Rebirth = { 0.4, 0, "Effects" },
	Shot = { 0.55, 0.04, "Effects" },
	Launch = { 0.55, 0.03, "Effects" },
	Skip = { 0.35, 0.08, "Effects" },
}

-- Roblox's own sounds standing in until ours are uploaded: { id, volume multiplier, pitch }. Only built-ins every
-- client has; never pitched above 1.1 (Alex: "not some random high pitch sounds"); no stand-in where a built-in
-- can only sound wrong (silence beats a squeaky ping). Open/Close stay silent: there is no soft swell built in.
local THUD = "rbxasset://sounds/action_jump_land.mp3"
-- Alex, Oct 30, after hearing the built-in clicks and pings: "these are bad, make them smooth and not sound bad
-- and harsh". So the only stand-in left is the low soft thump under the cannon shot; every other slot stays silent
-- until it has a real id (silence beats a harsh sound).
local FALLBACK = {
	Shot = { THUD, 1, 0.6 },
}

local GAP = 0.06 -- a button sound asked for again this soon is the same press
-- The big "ta-da" sounds never stack: a rebirth that also unlocks a cannon would otherwise play two stings at once
local STINGS = { Reward = true, Rebirth = true, Hatch = true }
local STING_GAP = 1.5
local lastSting = -math.huge
local POOL = 3

local folder = Instance.new("Folder")
folder.Name = "CannonSfx"
folder.Parent = SoundService
local groups = {}
for _, name in ipairs({ "Interface", "Effects" }) do
	local g = Instance.new("SoundGroup")
	g.Name = name
	g.Volume = 1
	g.Parent = folder
	-- Warmer and smoother: take the edge off the highs (the part that sounds harsh on phone and laptop speakers)
	-- and even out the loud peaks, so no sound jumps out of the mix
	local eq = Instance.new("EqualizerSoundEffect")
	eq.HighGain = -7
	eq.MidGain = -1
	eq.LowGain = 1
	eq.Parent = g
	local comp = Instance.new("CompressorSoundEffect")
	comp.Threshold = -16
	comp.Ratio = 3
	comp.Attack = 0.005
	comp.Release = 0.15
	comp.Priority = 1
	comp.Parent = g
	groups[name] = g
end

local pools = {} -- name = { sounds = {...}, next = 1, pitch = base pitch }
local lastPlayed = {}

local function build(name)
	local level = LEVEL[name] or { 0.4, 0, "Effects" }
	local id = Config.Sounds and Config.Sounds[name]
	local volume, pitch = level[1], 1
	if not id or id == "" then
		local fb = FALLBACK[name]
		if not fb then
			return false
		end
		id, volume, pitch = fb[1], level[1] * fb[2], fb[3]
	end
	local pool = { sounds = {}, next = 1, pitch = pitch, spread = level[2] }
	for i = 1, POOL do
		local s = Instance.new("Sound")
		s.Name = name .. i
		s.SoundId = id
		s.Volume = math.min(volume, 1)
		s.PlaybackSpeed = pitch
		s.SoundGroup = groups[level[3]]
		s.Parent = folder
		pool.sounds[i] = s
	end
	return pool
end

function Sfx.play(name)
	local pool = pools[name]
	if pool == nil then
		pool = build(name)
		pools[name] = pool
	end
	if not pool then
		return
	end
	local now = os.clock()
	if LEVEL[name] and LEVEL[name][3] == "Interface" and lastPlayed[name] and now - lastPlayed[name] < GAP then
		return
	end
	if STINGS[name] then
		if now - lastSting < STING_GAP then
			return
		end
		lastSting = now
	end
	lastPlayed[name] = now
	local s = pool.sounds[pool.next]
	pool.next = pool.next % #pool.sounds + 1
	if pool.spread > 0 then
		s.PlaybackSpeed = pool.pitch * (1 + (math.random() * 2 - 1) * pool.spread)
	end
	s.TimePosition = 0
	s:Play()
end

-- The Sound Effects setting (off = both groups silent)
function Sfx.setEnabled(on)
	for _, g in pairs(groups) do
		g.Volume = on and 1 or 0
	end
end

-- Build and preload everything now, so the first click isn't late
task.spawn(function()
	local all = {}
	for name in pairs(LEVEL) do
		local pool = build(name)
		pools[name] = pool
		if pool then
			table.insert(all, pool.sounds[1])
		end
	end
	pcall(ContentProvider.PreloadAsync, ContentProvider, all)
end)

return Sfx
