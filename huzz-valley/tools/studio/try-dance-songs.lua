-- Huzz Valley: listen to each dance's two songs in Studio, and try a song you found yourself (owner, Oct 20: "find
-- popular audios we can use with these dances. But make them logically fit the dances that we have in game").
-- The picks and why: huzz-valley/docs/dance-music.md. Your step-by-step: huzz-valley/docs/STUDIO-STEPS.md Part 5.
--
-- How: open the place in Studio (Edit mode is fine), View > Command Bar, paste ALL of this file, press Enter.
-- Turn your volume up a little. For each dance it plays pick 1, then pick 2, for SECONDS each (from a quarter of the
-- way in, past the intro) and prints:
--   [HuzzSfx] <Dance> pick 1: <song> by <uploader> PLAYS <length> s     (the one the game plays)
--   [HuzzSfx] <Dance> pick 2: ...                                         (plays only if pick 1 is emptied)
--   [HuzzSfx]    NOT LICENSED?   when the uploader isn't APMOfficial or Monstercat (a look-alike: tell Claude)
--   [HuzzSfx]    WON'T PLAY      when it didn't load (private or removed)
-- To hear only some dances, put their names in ONLY, e.g. local ONLY = { "Flapper", "TheTwist" }.
-- To try a song you found in the Toolbox (Audio, right-click > Copy Asset ID), put it in TRY, e.g.
--   local TRY = { Flapper = "rbxassetid://1234567890" }
-- It plays that one too and prints "[HuzzSfx] SEND Flapper = ...": screenshot it and send it to Claude, who puts it
-- in the game (Config/Dances). It doesn't change the game itself: with Rojo connected, an edit made here in Studio
-- would be put back by the files on the next sync. Untested here (needs Studio).
local ONLY = {} -- empty = every dance
local TRY = {} -- { DanceId = "rbxassetid://..." }
local SECONDS = 6

local MarketplaceService = game:GetService("MarketplaceService")
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LICENSED = { Monstercat = true, APMOfficial = true, ProSoundEffects = true }

local okCfg, Dances = pcall(function() return require(ReplicatedStorage.Shared.Config.Dances) end)
if not okCfg then
	warn("[HuzzSfx] can't read Config/Dances: " .. tostring(Dances))
	return
end

local only = {}
for _, name in ONLY do only[name] = true end

local function listen(label, id)
	if type(id) ~= "string" or id == "" then
		print(string.format("[HuzzSfx] %s: no ID yet", label))
		return
	end
	local number = tonumber(string.match(id, "%d+"))
	local got, info = pcall(function() return MarketplaceService:GetProductInfo(number, Enum.InfoType.Asset) end)
	local name = if got and type(info) == "table" and info.Name then info.Name else "?"
	local creator = if got and type(info) == "table" and info.Creator then info.Creator.Name or "?" else "?"
	local s = Instance.new("Sound")
	s.Name = "HuzzDanceSongCheck"
	s.SoundId = id
	s.Volume = 0.5
	s.Parent = SoundService
	pcall(function() ContentProvider:PreloadAsync({ s }) end)
	local untilT = os.clock() + 6
	while not s.IsLoaded and os.clock() < untilT do task.wait(0.1) end
	if s.IsLoaded and s.TimeLength > 0 then
		print(string.format("[HuzzSfx] %s: %s by %s PLAYS %.0f s", label, name, creator, s.TimeLength))
		if not LICENSED[creator] then print("[HuzzSfx]    NOT LICENSED? (uploader " .. creator .. ")") end
		pcall(function()
			s.TimePosition = math.floor(s.TimeLength / 4)
			s:Play()
		end)
		task.wait(math.min(SECONDS, s.TimeLength) + 0.3)
		pcall(function() s:Stop() end)
	else
		print(string.format("[HuzzSfx] %s: %s %s WON'T PLAY (private, removed, or not allowed here)", label, name, id))
	end
	s:Destroy()
end

task.spawn(function()
	print("[HuzzSfx] Dance songs: pick 1 then pick 2 for each dance")
	for _, d in Dances.List do
		if next(only) == nil or only[d.Id] or only[d.Name] then
			local one = d.Music and Dances.Tracks[d.Music]
			local two = d.Backup and Dances.Tracks[d.Backup]
			listen(d.Id .. " pick 1", one and one.Id or "")
			listen(d.Id .. " pick 2", two and two.Id or "")
		end
	end
	for danceId, id in TRY do
		listen(danceId .. " (your try)", id)
		print(string.format("[HuzzSfx] SEND %s = %s", danceId, tostring(id)))
	end
	print("[HuzzSfx] Done. Screenshot the Output and send it to Claude with the ones you like or don't.")
end)
