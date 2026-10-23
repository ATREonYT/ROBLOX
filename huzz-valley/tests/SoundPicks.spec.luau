-- lune run tests/SoundPicks.spec.luau   (from huzz-valley/)
-- The researched sound picks (owner, Oct 19: "find good sounds that fit the secret animation, that fit the clicking
-- better, also find the sounds we can use for all of the dances, but don't create random sound by yourself";
-- docs/sound-picks.md):
--   * every ID is "" or "rbxassetid://<number>", and every real one names its source page (never invented);
--   * every dance has two picks from Dances.Tracks (docs/dance-music.md, Oct 20); Dances.track plays pick 2 when pick
--     1 is "", and nil (silence) when both are "" or the dance is unknown; no song is pick 1 for more than 4 dances;
--   * dance songs sit under the background music, and the background dips (never to silence);
--   * the Secret cutscene's cues: known beats and slots, fades only at a later beat, the riser cut at the burst;
--   * Sfx.beat on fake Sounds: Build starts riser + bed (the riser partway in, so its top lands on the burst), Burst
--     fades the riser and plays the hit and the tail; the sting comes with her name;
--   * the background dips far enough under a dance song that two songs don't clash;
--   * DancePlayer starts and stops the dance song; Kenney's button files and licence are in assets/sfx.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local ROOT = if fs.isDir("huzz-valley") then "huzz-valley/" else ""

local passed, failed = 0, 0
local function check(name, cond)
	if cond then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local function load(path, env)
	local src = fs.readFile(ROOT .. path)
	if env then return luau.load(src, { debugName = path, environment = env })() end
	-- Config modules use Color3 (Dances): give them a tiny stand-in
	return luau.load(src, { debugName = path, environment = setmetatable({
		Color3 = { fromHex = function(h) return { hex = h } end },
	}, { __index = _G }) })()
end

local ids = load("src/ReplicatedStorage/Shared/Config/SoundIds.lua")
local idsSource = fs.readFile(ROOT .. "src/ReplicatedStorage/Shared/Config/SoundIds.lua")
local Dances = load("src/ReplicatedStorage/Shared/Config/Dances.lua")
local MusicCfg = load("src/ReplicatedStorage/Shared/Config/Music.lua")
local Secret = load("src/ReplicatedStorage/Shared/Config/SecretSounds.lua")
local doc = if fs.isFile(ROOT .. "docs/sound-picks.md") then fs.readFile(ROOT .. "docs/sound-picks.md") else ""

local function goodId(id)
	return id == "" or string.match(id, "^rbxassetid://%d+$") ~= nil
end

-- 1. IDs: real format, with their source
for name, id in ids do
	check("SoundIds." .. name .. " is \"\" or rbxassetid://<number>", type(id) == "string" and goodId(id))
	if id ~= "" then
		local n = string.match(id, "%d+")
		check("SoundIds." .. name .. " cites its store page in the file", string.find(idsSource, "create.roblox.com/store/asset/" .. n, 1, true) ~= nil)
		check("SoundIds." .. name .. " is in docs/sound-picks.md", string.find(doc, n, 1, true) ~= nil)
	end
end
check("button sounds wait for the owner's upload (\"\", never a made-up ID)", ids.ui_click == "" and ids.ui_hover == "" and ids.ui_open == "" and ids.ui_close == "")

-- 2. dances and their songs (Oct 20: two picks per dance, docs/dance-music.md)
local danceDoc = if fs.isFile(ROOT .. "docs/dance-music.md") then fs.readFile(ROOT .. "docs/dance-music.md") else ""
check("docs/dance-music.md exists", danceDoc ~= "")
local used, firstUses = {}, {}
for _, d in Dances.List do
	check(d.Id .. " has a song", type(d.Music) == "string" and Dances.Tracks[d.Music] ~= nil)
	check(d.Id .. " has a second pick, different from the first", type(d.Backup) == "string" and Dances.Tracks[d.Backup] ~= nil and d.Backup ~= d.Music)
	check(d.Id .. " is in docs/dance-music.md", string.find(danceDoc, "| " .. d.Name .. " |", 1, true) ~= nil)
	if d.Music then used[d.Music] = true; firstUses[d.Music] = (firstUses[d.Music] or 0) + 1 end
	if d.Backup then used[d.Backup] = true end
end
for key, n in firstUses do
	check("track " .. key .. " is the first pick of at most 4 dances (each song stays a clear style)", n <= 4)
end
for key, t in Dances.Tracks do
	check("track " .. key .. " Id is \"\" or rbxassetid://<number>", goodId(t.Id))
	check("track " .. key .. " is used by a dance", used[key] == true)
	if t.Id ~= "" and t.Full then -- (his own upload, Oct 23: no store page; listed in docs/dance-music.md by ID)
		check("track " .. key .. " (his upload) is in docs/dance-music.md", string.find(danceDoc, string.match(t.Id, "%d+"), 1, true) ~= nil)
	elseif t.Id ~= "" then
		local n = string.match(t.Id, "%d+")
		check("track " .. key .. " Source is its store page", string.find(t.Source, "create.roblox.com/store/asset/" .. n, 1, true) ~= nil)
		check("track " .. key .. " is in docs/sound-picks.md or docs/dance-music.md", string.find(doc, n, 1, true) ~= nil or string.find(danceDoc, n, 1, true) ~= nil)
		check("track " .. key .. " is in docs/dance-music.md with its store page", string.find(danceDoc, "create.roblox.com/store/asset/" .. n, 1, true) ~= nil)
	end
	check("track " .. key .. " Start is a time", t.Start == nil or (type(t.Start) == "number" and t.Start >= 0))
end
check("Dances.track gives OrangeSwing its song", Dances.track("OrangeSwing") ~= nil and Dances.track("OrangeSwing").Id == Dances.Tracks.CrabRave.Id)
check("Dances.track gives Squat Kicks the Russian folk dance (Kalinka)", Dances.track("SquatKicks") ~= nil and Dances.track("SquatKicks").Id == Dances.Tracks.Kalinka.Id)
check("Dances.track: unknown dance = nil", Dances.track("NoSuchDance") == nil)
local crab = Dances.get("OrangeSwing")
local saved, savedBackup = Dances.Tracks.CrabRave.Id, Dances.Tracks[crab.Backup].Id
Dances.Tracks.CrabRave.Id = ""
check("Dances.track: pick 1 with Id \"\" falls back to pick 2", Dances.track("OrangeSwing") ~= nil and Dances.track("OrangeSwing").Id == savedBackup)
Dances.Tracks[crab.Backup].Id = ""
check("Dances.track: both picks \"\" = nil (dances in silence)", Dances.track("OrangeSwing") == nil)
Dances.Tracks.CrabRave.Id, Dances.Tracks[crab.Backup].Id = saved, savedBackup
check("dance songs are quieter than the background songs", Dances.MusicVolume > 0 and Dances.MusicVolume < MusicCfg.Volume)
check("the background dips under a dance song but never goes silent", Dances.MusicDuck > 0.1 and Dances.MusicDuck < 1)
check("the dip is deep enough that the dance song clearly wins (at least ~12 dB under it)", Dances.MusicDuck * MusicCfg.Volume <= Dances.MusicVolume / 4)
check("dance song fades are gentle (0.2 to 2 s)", Dances.MusicFadeIn >= 0.2 and Dances.MusicFadeIn <= 2 and Dances.MusicFadeOut >= 0.2 and Dances.MusicFadeOut <= 2)

-- 3. the Secret cutscene's cues
local order = {}
for i, b in Secret.Beats do order[b] = i end
check("beats are Build, Burst, Reveal, End", table.concat(Secret.Beats, ",") == "Build,Burst,Reveal,End")
for beat, cues in Secret.Cues do
	check("cue beat " .. beat .. " is a named beat", order[beat] ~= nil)
	for _, c in cues do
		check(beat .. ": " .. c.Slot .. " is a Config/SoundIds name", ids[c.Slot] ~= nil)
		check(beat .. ": " .. c.Slot .. " fades at a later beat", c.FadeOn == nil or (order[c.FadeOn] ~= nil and order[c.FadeOn] > order[beat]))
		check(beat .. ": " .. c.Slot .. " delay is small", c.Delay == nil or (c.Delay >= 0 and c.Delay <= 1))
	end
end
local cutAtBurst = false
for _, f in Secret.fades("Burst") do if f.slot == "secret_riser" and f.fade <= 0.3 then cutAtBurst = true end end
check("the riser is cut quickly under the burst", cutAtBurst)
check("an unknown beat has no cues", #Secret.cues("Nope") == 0)

-- 4. Sfx.beat on fake Sounds
local clock = 0
local plays = {}
local function inst(class)
	local o = { ClassName = class, Parent = nil, _kids = {}, Volume = 1 }
	function o:IsA(c) return c == class end
	function o:FindFirstChild(n)
		for _, k in self._kids do if k.Name == n then return k end end
		return nil
	end
	function o:Play() table.insert(plays, self.Name) end
	function o:Stop() end
	function o:Destroy() self.Parent = nil end
	return setmetatable(o, { __newindex = function(t, k, v)
		rawset(t, k, v)
		if k == "Parent" and v and v._kids then table.insert(v._kids, t) end
	end })
end
local SoundService = inst("SoundService")
local fakeShared = { Config = { SoundIds = ids, SecretSounds = Secret } }
local env = {
	game = { GetService = function(_, name)
		if name == "SoundService" then return SoundService end
		if name == "ReplicatedStorage" then return { WaitForChild = function() return fakeShared end } end
		return { PreloadAsync = function() end }
	end },
	require = function(x) return x end,
	Instance = { new = inst },
	task = { defer = function(fn) fn() end, delay = function(t, fn) if t < 1 then fn() end end,
		spawn = function(fn, ...) fn(...) end, wait = function(t) clock += t or 0.03 end },
	os = { clock = function() return clock end },
	pcall = pcall, math = math, string = string, table = table, type = type, setmetatable = setmetatable,
}
local Sfx = load("src/StarterPlayer/StarterPlayerScripts/HuzzClient/Gameplay/Sfx.lua", env)
check("Sfx.beat exists", type(Sfx.beat) == "function")
local riserCue
for _, c in Secret.cues("Build") do if c.Slot == "secret_riser" then riserCue = c end end
check("the riser has a Peak (where it tops out) to time it to the burst", riserCue ~= nil and type(riserCue.Peak) == "number")
Sfx.beat("Build", 3.17)
check("Build starts the riser and the magic bed", table.find(plays, "secret_riser") ~= nil and table.find(plays, "secret_shimmer") ~= nil)
local riser
for _, k in SoundService:FindFirstChild("HuzzSfx")._kids do if k.Name == "secret_riser" then riser = k end end
check("the riser starts partway in so its top lands on the burst", riser ~= nil and riserCue ~= nil
	and math.abs((riser.TimePosition or 0) - (riserCue.Peak - 3.17)) < 1e-6)
plays = {}
Sfx.beat("Burst")
check("Burst plays the hit and the sparkle tail", table.find(plays, "secret_impact") ~= nil and table.find(plays, "secret_sparkle") ~= nil)
check("Burst fades the riser out and removes it", riser ~= nil and riser.Parent == nil and riser.Volume == 0)
plays = {}
Sfx.beat("Reveal")
check("Reveal plays the sting", table.find(plays, "secret_sting") ~= nil)
plays = {}
Sfx.beat("End")
check("End starts nothing new (it only fades)", #plays == 0)
Sfx.beat("Nope") -- (an unknown beat does nothing, and doesn't error)
local sfxSource = fs.readFile(ROOT .. "src/StarterPlayer/StarterPlayerScripts/HuzzClient/Gameplay/Sfx.lua")
check("long secret sounds aren't cleared at 4 s", string.find(sfxSource, "secret_shimmer = 20", 1, true) ~= nil and string.find(sfxSource, "task.delay(LIFE[name] or 4", 1, true) ~= nil)

local reveal = fs.readFile(ROOT .. "src/StarterPlayer/StarterPlayerScripts/HuzzClient/Gameplay/SecretReveal.lua")
check("the cutscene tells Build how long until the burst", string.find(reveal, 'Sfx.beat("Build", Reveal.IMPACT - Reveal.BUILD)', 1, true) ~= nil)
check("the sting comes with her name (Reveal at Reveal.NAME)", string.find(reveal, 'if t >= Reveal.NAME then once("sting", function() Sfx.beat("Reveal") end) end', 1, true) ~= nil)
check("Sfx downloads every real ID ahead (the hit lands on time)", string.find(sfxSource, "PreloadAsync(all)", 1, true) ~= nil
	and string.find(sfxSource, "if not UI[name] and type(id) == \"string\" and id ~= \"\" then table.insert(all, id) end", 1, true) ~= nil)

-- 5. wiring and files
local dp = fs.readFile(ROOT .. "src/StarterPlayer/StarterPlayerScripts/HuzzClient/UI/DancePlayer.lua")
check("DancePlayer starts the dance song", string.find(dp, "Music.dance, id", 1, true) ~= nil)
check("DancePlayer stops the dance song", string.find(dp, "Music.danceStop", 1, true) ~= nil)
check("a dance whose animation stopped stops its song too", string.find(dp, "if ok and on == false then DancePlayer.stop() end", 1, true) ~= nil)
local feel = fs.readFile(ROOT .. "src/StarterPlayer/StarterPlayerScripts/HuzzClient/Gameplay/Feel.lua")
check("Roblox's own character sounds go through the Effects group (the sliders reach them)", string.find(feel, "s.SoundGroup = effects", 1, true) ~= nil)
for _, f in { "ui_click", "ui_hover", "ui_open", "ui_close" } do
	check("assets/sfx/" .. f .. ".ogg (Kenney, CC0) is there to upload", fs.isFile(ROOT .. "assets/sfx/" .. f .. ".ogg"))
end
check("Kenney's licence is next to the files", fs.isFile(ROOT .. "assets/sfx/LICENSE-kenney.txt"))
check("the old synthesized Secret sounds are gone", not fs.isFile(ROOT .. "assets/sfx/secret_riser.ogg"))
check("the Studio check script exists", fs.isFile(ROOT .. "tools/studio/check-sound-picks.lua"))
check("the Studio dance-song helper exists and reports on [HuzzSfx] lines", fs.isFile(ROOT .. "tools/studio/try-dance-songs.lua")
	and string.find(fs.readFile(ROOT .. "tools/studio/try-dance-songs.lua"), "[HuzzSfx] SEND", 1, true) ~= nil)

-- His uploaded songs (Oct 23): each has its ID, a loop of whole bars inside the whole file, and lengths no other song
-- shares (tools/studio/song_check.lua tells them apart by length; the two Rush cut loops are the same, their files not)
do
	local fulls, n = {}, 0
	for key, t in Dances.Tracks do
		if t.Full then
			n += 1
			check(key .. " has its uploaded ID", string.match(t.Id, "^rbxassetid://%d+$") ~= nil)
			check(key .. " loops inside its whole file", t.First >= 0 and t.Loop > 1 and t.First + t.Loop <= t.Full + 0.01)
			for other, f in fulls do
				check(key .. " and " .. other .. " have different whole-file lengths", math.abs(f - t.Full) > 0.35)
			end
			fulls[key] = t.Full
		end
	end
	check(string.format("all 11 of his songs (%d)", n), n == 11)
	check("the Studio song check exists and reports on [HuzzSongs] lines", fs.isFile(ROOT .. "tools/studio/song_check.lua")
		and string.find(fs.readFile(ROOT .. "tools/studio/song_check.lua"), "[HuzzSongs] SWAP", 1, true) ~= nil)
end

print(`SoundPicks: {passed} ok, {failed} failed`)
if failed > 0 then error("SoundPicks spec failed") end
