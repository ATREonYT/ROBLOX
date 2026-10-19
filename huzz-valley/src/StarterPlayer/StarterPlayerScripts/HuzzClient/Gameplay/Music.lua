-- Background music (owner, Oct 18: "randomly play in the background these audios in a volume that isn't too loud").
-- Plays the owner's songs (SoundService > Music > Background_Music, else Config/Music.Background) in a shuffled
-- order, never the same song twice in a row, fading in and out, through the Music sound group (Settings > Audio:
-- Music Volume, Background Music ON/OFF, Next Song). Winner_Music_Showcase plays over the end of every game: the
-- background fades out under it and comes back after. The Secret cutscene fades it out too. Each player's client
-- plays its own copy (a song set to play by itself in the place is stopped by the server's Bootstrap).
-- Dance songs (owner, Oct 19: "find the sounds we can use for all of the dances"): Music.dance(id) plays that dance's
-- song from Config/Dances (Monstercat / APM, Roblox's licensed library) for you only, looped, quieter than the
-- background (Dances.MusicVolume), and dips the background to Dances.MusicDuck of its volume; Music.danceStop()
-- fades it out and brings the background back. UI/DancePlayer calls both. No song = no dip.
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.Music)
local okDances, Dances = pcall(require, Shared.Config.Dances)

local Music = {}

local FADE_IN, FADE_OUT, GAP, WINNER_MAX = 2, 1.2, 1.5, 40

local quietUntil = 0 -- the background stays faded out until then (the Secret cutscene)
local winnerPlaying = false -- and while the win song plays
local skipAsked = false
local holder: Folder? = nil

local function home(): Folder
	if not (holder and holder.Parent) then
		local f = Instance.new("Folder")
		f.Name = "HuzzMusic"
		f.Parent = SoundService
		holder = f
	end
	return holder :: Folder
end

local function group(): SoundGroup?
	local master = SoundService:FindFirstChild("Master")
	local g = master and master:FindFirstChild("Music")
	return if g and g:IsA("SoundGroup") then g else nil
end

local okState, State = pcall(require, script.Parent.Parent:WaitForChild("UI"):WaitForChild("State"))
local function enabled(): boolean
	return not okState or State.setting("MusicOn") ~= false
end
local function quiet(): boolean
	return winnerPlaying or os.clock() < quietUntil
end

local function folder(name: string): Instance?
	local root = SoundService:FindFirstChild("Music")
	return root and root:FindFirstChild(name)
end

-- Every song we can play, as { id, volume } (the owner's Sound volumes are kept relative to each other).
local function songs(): { { id: string, volume: number } }
	local list = {}
	local bg = folder("Background_Music")
	if bg then
		local sounds = {}
		for _, s in bg:GetChildren() do
			if s:IsA("Sound") and s.SoundId ~= "" then table.insert(sounds, s) end
		end
		table.sort(sounds, function(a, b) return a.Name < b.Name end)
		for _, s in sounds do
			table.insert(list, { id = s.SoundId, volume = Config.Volume * math.clamp(s.Volume / 0.5, 0.5, 1.5) })
		end
	end
	if #list == 0 then
		for _, id in Config.Background do
			if id ~= "" then table.insert(list, { id = id, volume = Config.Volume }) end
		end
	end
	return list
end

local function winnerSong(): { id: string, volume: number }?
	local w = folder("Important_Song_Actions")
	local s = w and w:FindFirstChild("Winner_Music_Showcase")
	if s and s:IsA("Sound") and s.SoundId ~= "" then
		return { id = s.SoundId, volume = Config.Volume * 1.3 * math.clamp(s.Volume / 0.5, 0.5, 1.5) }
	end
	if Config.Winner ~= "" then return { id = Config.Winner, volume = Config.Volume * 1.3 } end
	return nil
end

local function make(song: { id: string, volume: number }, name: string): Sound
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = song.id
	s.Volume = 0
	s.Looped = false
	local g = group()
	if g then s.SoundGroup = g end
	s.Parent = home()
	return s
end

-- Each sound's own level (what the fades move). A background song plays at its level x duckNow, so a dance song
-- can dip it without fighting its fades. (A plain table, cleared in gone(): never a weak table keyed by Instance.)
local level: { [Sound]: number } = {}
local duckWant, duckNow = 1, 1
local bgNow: Sound? = nil -- the background song playing now
local function apply(s: Sound)
	s.Volume = (level[s] or 0) * (if s.Name == "Song" then duckNow else 1)
end
local function gone(s: Sound)
	level[s] = nil
	s:Destroy()
end

-- Moves a sound's volume to `to` over `time` seconds (stops early if `stop()` says so).
local function fade(s: Sound, to: number, time: number, stop: (() -> boolean)?)
	local from, t0 = level[s] or s.Volume, os.clock()
	while s.Parent do
		local x = math.min((os.clock() - t0) / time, 1)
		level[s] = from + (to - from) * x
		apply(s)
		if x >= 1 or (stop and stop()) then break end
		task.wait(0.05)
	end
end

local function loaded(s: Sound): boolean
	local ok = pcall(function() return s.IsLoaded end)
	if not ok then return true end -- (the offline preview's copy of the Roblox API)
	-- (a slow phone can take a while to download a song: wait up to 30 s; one that never loads is skipped)
	local untilT = os.clock() + 30
	while not s.IsLoaded and os.clock() < untilT and s.Parent do task.wait(0.1) end
	return s.IsLoaded
end

local function playing(s: Sound): boolean
	local ok, yes = pcall(function() return s.IsPlaying end)
	return ok and yes
end

-- Next song now (Settings > Audio > Next Song). False when there's nothing to play.
function Music.skip(): boolean
	if #songs() == 0 or not enabled() or quiet() then return false end
	skipAsked = true
	return true
end

-- The dance song playing now (only you hear it), and which dance it's for.
local danceSound: Sound? = nil
local danceFor: string? = nil

-- Fades your dance song out and lets the background come back up.
function Music.danceStop()
	duckWant = 1
	local s = danceSound
	danceSound, danceFor = nil, nil
	if s then
		s.Name = "DanceFading"
		task.spawn(function()
			fade(s, 0, if okDances then Dances.MusicFadeOut else 0.8)
			gone(s)
		end)
	end
end

-- Plays the song of this dance (Config/Dances Music -> Tracks), looped, and dips the background under it.
-- Nothing when the dance has no song, its Id is "", or Background Music is off in Settings.
function Music.dance(id: string)
	if danceFor == id and danceSound and danceSound.Parent then return end
	Music.danceStop()
	if not okDances or not enabled() or winnerPlaying or os.clock() < quietUntil then return end
	local track = Dances.track(id)
	if not track then return end
	local s = make({ id = track.Id, volume = Dances.MusicVolume }, "Dance")
	s.Looped = true
	danceSound, danceFor = s, id
	duckWant = Dances.MusicDuck
	local start = track.Start or 0
	pcall(function() s.TimePosition = start end)
	s:Play()
	if start > 0 then -- (a song that hasn't downloaded yet can drop its start point: set it again once it has)
		task.spawn(function()
			if loaded(s) and danceSound == s and s.TimePosition < start then s.TimePosition = start end
		end)
	end
	task.spawn(function()
		fade(s, Dances.MusicVolume, Dances.MusicFadeIn, function() return danceSound ~= s end)
	end)
end

-- Fades the background out for `seconds` (the Secret cutscene); a dance song stops too.
function Music.quiet(seconds: number)
	quietUntil = math.max(quietUntil, os.clock() + seconds)
	Music.danceStop()
end

-- The win song over the end of a game; the background comes back once it ends.
function Music.winner()
	local song = winnerSong()
	if not song or not enabled() or winnerPlaying then return end
	winnerPlaying = true
	Music.danceStop()
	task.spawn(function()
		local s = make(song, "Winner")
		task.wait(0.4) -- (let the background start fading first)
		s:Play()
		if loaded(s) then
			fade(s, song.volume, 0.5)
			local untilT = os.clock() + WINNER_MAX - 2
			while s.Parent and playing(s) and os.clock() < untilT and enabled() do task.wait(0.25) end
			fade(s, 0, FADE_OUT)
		end
		gone(s)
		winnerPlaying = false
	end)
end

function Music.start()
	-- the win song when a game ends (Round remote "Results", sent to each player as the game finishes)
	pcall(function()
		local Net = require(Shared.Net)
		Net.get("Round").OnClientEvent:Connect(function(kind, data)
			-- someone won (not the Practice Bot): the win song over the end of the game
			if kind == "Results" and type(data) == "table" and data.outcome ~= "Bot" then Music.winner() end
		end)
	end)
	task.spawn(function()
		-- the volume sliders need the Music group (made by the server) and your saved settings (Music on or off)
		pcall(function() SoundService:WaitForChild("Master", 10):WaitForChild("Music", 10) end)
		local untilT = os.clock() + 10
		while okState and not State.data.Loaded and os.clock() < untilT do task.wait(0.2) end
		local bag, last = {}, nil
		while true do
			local list = songs()
			if #list == 0 or not enabled() or quiet() then
				skipAsked = false
				task.wait(1)
				continue
			end
			if #bag == 0 then -- a fresh shuffle, never starting with the song that just played
				for i = 1, #list do bag[i] = i end
				for i = #bag, 2, -1 do
					local j = math.random(i)
					bag[i], bag[j] = bag[j], bag[i]
				end
				if #bag > 1 and list[bag[#bag]] and list[bag[#bag]].id == last then
					bag[1], bag[#bag] = bag[#bag], bag[1]
				end
			end
			local song = list[table.remove(bag)]
			if not song then continue end
			last = song.id
			skipAsked = false
			local s = make(song, "Song")
			bgNow = s
			s:Play()
			if loaded(s) then
				local function interrupted() return skipAsked or not enabled() or quiet() end
				fade(s, song.volume, FADE_IN, interrupted)
				while s.Parent and playing(s) do
					if skipAsked or not enabled() then break end
					if not s.SoundGroup then local g = group(); if g then s.SoundGroup = g end end
					if quiet() then -- fade out, wait, carry on where it was
						fade(s, 0, FADE_OUT)
						s:Pause()
						while quiet() and enabled() do task.wait(0.25) end
						if not enabled() then break end
						s:Resume()
						fade(s, song.volume, FADE_IN, function() return skipAsked or quiet() end)
					end
					task.wait(0.25)
				end
				if playing(s) then fade(s, 0, if skipAsked then 0.4 else FADE_OUT) end
			end
			gone(s)
			task.wait(if skipAsked then 0.2 else GAP)
		end
	end)
	-- the dip under a dance song: eases over ~0.4 s each way; a dance song stops if Background Music is turned off
	task.spawn(function()
		while true do
			task.wait(0.05)
			if danceSound and not enabled() then Music.danceStop() end
			if duckNow ~= duckWant then
				local step = 0.05 / 0.4 * (1 - (if okDances then Dances.MusicDuck else 0.15))
				duckNow = if duckNow < duckWant then math.min(duckWant, duckNow + step) else math.max(duckWant, duckNow - step)
				local s = bgNow
				if s and s.Parent then apply(s) end
			end
		end
	end)
	-- a song set to play by itself in the place: stop it here too, in case it started before the server could
	local root = SoundService:FindFirstChild("Music")
	if root then
		for _, d in root:GetDescendants() do
			if d:IsA("Sound") and playing(d) then d:Stop() end
		end
	end
end

return Music
