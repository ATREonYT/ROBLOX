-- Huzz Valley: check every picked sound and song in Studio (owner, Oct 19: "find good sounds ... logically select the
-- best sounds/songs possible"; the picks and why: huzz-valley/docs/sound-picks.md).
-- Cloud sessions can't reach Roblox, so they couldn't confirm the IDs themselves: this does, on your computer.
--
-- How: open the place in Studio (Edit mode is fine), View > Command Bar, paste ALL of this file, press Enter.
-- Turn your volume up a little: it plays each sound for up to 4 seconds, one after another.
-- Output prints, for every picked ID (Config/SoundIds, Config/Dances Tracks):
--   [HuzzSfx] OK <slot> <id> <name> by <creator>        Roblox knows the asset (its name and who made it)
--   [HuzzSfx] MISSING <slot> <id> <why>                  Roblox has no such asset, or wouldn't say
--   [HuzzSfx] PLAYS <slot> <seconds> s                   it loaded and has sound (so it will play in your game)
--   [HuzzSfx] WON'T PLAY <slot>                          it didn't load: private, removed, or not allowed here
-- and a last line "[HuzzSfx] Done: ...". Screenshot the Output and send it to Claude.
-- Audio rules (why something may not play): Roblox's own licensed library (Monstercat, APM Music, Pro Sound
-- Effects, uploaded by Roblox's accounts) is public and plays in any game. Sounds YOU upload are private to you:
-- they play in games you own (or your group's, if you upload them to the group or share them with it).
-- Untested here (needs Studio). Change PREVIEW to false to only check, without playing.
local PREVIEW = true
local SECONDS = 4

local MarketplaceService = game:GetService("MarketplaceService")
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function config(name)
	local ok, m = pcall(function() return require(ReplicatedStorage.Shared.Config[name]) end)
	if not ok then warn("[HuzzSfx] can't read Config/" .. name .. ": " .. tostring(m)) end
	return if ok then m else nil
end

local picks = {}
local function add(slot, id, note)
	if type(id) == "string" and id ~= "" then table.insert(picks, { slot = slot, id = id, note = note }) end
end
local ids = config("SoundIds")
if ids then
	local names = {}
	for name in ids do table.insert(names, name) end
	table.sort(names)
	for _, name in names do add(name, ids[name]) end
end
local dances = config("Dances")
if dances and dances.Tracks then
	local users = {}
	for _, d in dances.List do
		if d.Music then
			users[d.Music] = users[d.Music] or {}
			table.insert(users[d.Music], d.Name)
		end
	end
	local keys = {}
	for key in dances.Tracks do table.insert(keys, key) end
	table.sort(keys)
	for _, key in keys do
		add("dance:" .. key, dances.Tracks[key].Id, "for " .. table.concat(users[key] or { "(no dance)" }, ", "))
	end
end

task.spawn(function()
	local ok, missing, silent = 0, 0, 0
	print(string.format("[HuzzSfx] Checking %d picked sounds%s", #picks, if PREVIEW then " (each plays for a moment)" else ""))
	for _, p in picks do
		local number = tonumber(string.match(p.id, "%d+"))
		local got, info = pcall(function() return MarketplaceService:GetProductInfo(number, Enum.InfoType.Asset) end)
		if got and type(info) == "table" and info.Name then
			local creator = info.Creator and info.Creator.Name or "?"
			print(string.format("[HuzzSfx] OK %s %s %s by %s%s", p.slot, p.id, info.Name, creator,
				if info.AssetTypeId ~= 3 then "  (not an audio asset!)" else ""))
			if p.note then print("[HuzzSfx]    " .. p.note) end
		else
			missing += 1
			print(string.format("[HuzzSfx] MISSING %s %s %s", p.slot, p.id, if got then "(no info)" else tostring(info)))
		end
		local s = Instance.new("Sound")
		s.Name = "HuzzSfxCheck"
		s.SoundId = p.id
		s.Volume = 0.5
		s.Parent = SoundService
		pcall(function() ContentProvider:PreloadAsync({ s }) end)
		local untilT = os.clock() + 6
		while not s.IsLoaded and os.clock() < untilT do task.wait(0.1) end
		if s.IsLoaded and s.TimeLength > 0 then
			ok += 1
			print(string.format("[HuzzSfx] PLAYS %s %.1f s", p.slot, s.TimeLength))
			if PREVIEW then
				pcall(function() SoundService:PlayLocalSound(s) end)
				task.wait(math.min(SECONDS, s.TimeLength) + 0.3)
				pcall(function() s:Stop() end)
			end
		else
			silent += 1
			print(string.format("[HuzzSfx] WON'T PLAY %s %s (private, removed, or not allowed in this game)", p.slot, p.id))
		end
		s:Destroy()
	end
	print(string.format("[HuzzSfx] Done: %d play, %d missing, %d won't play (of %d).", ok, missing, silent, #picks))
end)
