-- Huzz Valley: collect the uploaded sound IDs (Studio Command Bar). Untested here: cloud sessions can't run Studio.
-- Before this: Asset Manager > Bulk Import every file in huzz-valley/assets/sfx, then select them all in Asset
-- Manager > Audio and drag them into Workspace. This finds those Sounds by name (ui_click, safe, ...) anywhere in
-- the place and prints src/ReplicatedStorage/Shared/Config/SoundIds.lua filled in, on lines starting with [HuzzSfx].
-- Copy the Output and send it to Claude (or paste it over that file). The dragged-in Sounds can then be deleted.
-- every sound name the game uses (the keys of Config/SoundIds), so new sounds are never missed
local NAMES = {}
for name in require(game:GetService("ReplicatedStorage").Shared.Config.SoundIds) do table.insert(NAMES, name) end
table.sort(NAMES)
local found = {}
for _, d in game:GetDescendants() do
	local ok, isSound = pcall(function() return d:IsA("Sound") or d:IsA("AudioPlayer") end)
	if ok and isSound then
		local id = if d:IsA("Sound") then d.SoundId else d.AssetId
		local key = string.lower(d.Name):gsub("%.ogg$", ""):gsub("%.mp3$", ""):gsub("%.wav$", "")
		if id ~= "" and string.find(id, "%d") then
			found[key] = id
		end
	end
end
local missing = {}
print("[HuzzSfx] return {")
for _, n in NAMES do
	print(string.format('[HuzzSfx] \t%s = "%s",', n, found[n] or ""))
	if not found[n] then table.insert(missing, n) end
end
print("[HuzzSfx] }")
print(if #missing == 0 then "[HuzzSfx] All " .. #NAMES .. " found." else "[HuzzSfx] Missing: " .. table.concat(missing, ", "))
