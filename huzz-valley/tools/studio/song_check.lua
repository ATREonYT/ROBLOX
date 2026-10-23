-- Huzz Valley: which song is each uploaded ID really? (Oct 23: the owner's uploads, matched by their names in his
-- Creator Hub list; the three German hardtekks and the six "2026-10-22 ..." ones are matched by name order, a guess.)
-- How: open the place in Studio (Edit mode is fine), View > Command Bar, paste ALL of this file, press Enter.
-- For each of his songs in Config/Dances it loads the ID and measures it. Every song has its own length (the whole
-- file and the cut loop), so the length says which song it is:
--   [HuzzSongs] OK   Balenci (whole file, 17.9 s)
--   [HuzzSongs] SWAP Hardtekk 1 has 36.1 s = Hardtekk 2's whole file: send this line to Claude
--   [HuzzSongs] WON'T LOAD Tick 138 (still being checked by Roblox, private, or removed)
-- Screenshot the [HuzzSongs] lines and send them to Claude if any says SWAP or WON'T LOAD. (Rush 180 A and B cut
-- loops are the same length; their whole files are not.) It changes nothing in the game.
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local okCfg, Dances = pcall(function() return require(ReplicatedStorage.Shared.Config.Dances) end)
if not okCfg then
	warn("[HuzzSongs] can't read Config/Dances: " .. tostring(Dances))
	return
end

-- every song that carries the whole file's length (his own songs)
local songs = {}
for key, t in Dances.Tracks or {} do
	if type(t) == "table" and t.Full and t.Loop then table.insert(songs, { key = key, t = t }) end
end
table.sort(songs, function(a, b) return a.t.Name < b.t.Name end)
if #songs == 0 then
	warn("[HuzzSongs] no songs with lengths in Config/Dances (pull the newest version in GitHub Desktop)")
	return
end

local function whichIs(length: number): string?
	for _, s in songs do
		if math.abs(length - s.t.Full) < 0.35 then return s.t.Name .. "'s whole file" end
		if math.abs(length - s.t.Loop) < 0.1 then return s.t.Name .. "'s cut loop" end
	end
	return nil
end

for _, s in songs do
	local t = s.t
	if t.Id == "" then
		print(string.format("[HuzzSongs] NO ID %s", t.Name))
		continue
	end
	local sound = Instance.new("Sound")
	sound.SoundId = t.Id
	sound.Volume = 0
	sound.Parent = SoundService
	pcall(function() ContentProvider:PreloadAsync({ sound }) end)
	local untilT = os.clock() + 10
	while not sound.IsLoaded and os.clock() < untilT do task.wait(0.1) end
	local length = sound.TimeLength
	sound:Destroy()
	if length <= 0 then
		print(string.format("[HuzzSongs] WON'T LOAD %s (%s): still being checked by Roblox, private, or removed", t.Name, t.Id))
	elseif math.abs(length - t.Full) < 0.35 then
		print(string.format("[HuzzSongs] OK   %s (whole file, %.1f s)", t.Name, length))
	elseif math.abs(length - t.Loop) < 0.1 then
		print(string.format("[HuzzSongs] OK   %s (cut loop, %.1f s)", t.Name, length))
	else
		print(string.format("[HuzzSongs] SWAP %s (%s) has %.1f s = %s", t.Name, t.Id, length, whichIs(length) or "none of his songs"))
	end
end
print("[HuzzSongs] done")
