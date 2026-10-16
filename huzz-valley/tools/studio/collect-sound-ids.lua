-- Huzz Valley: collect the uploaded sound IDs (Studio Command Bar). Untested here: cloud sessions can't run Studio.
-- Before this: Asset Manager > Bulk Import every file in huzz-valley/assets/sfx, then select them all in Asset
-- Manager > Audio and drag them into Workspace. This finds those Sounds by name (ui_click, safe, ...) anywhere in
-- the place and prints src/ReplicatedStorage/Shared/Config/SoundIds.lua filled in, on lines starting with [HuzzSfx].
-- Copy the Output and send it to Claude (or paste it over that file). The dragged-in Sounds can then be deleted.
local NAMES = { "ui_click", "ui_hover", "ui_open", "ui_close", "ui_error", "coin", "reward", "level_up",
	"countdown_tick", "countdown_go", "roulette_tick", "pick_land", "hero_chosen", "chicken_chosen", "dash", "stab",
	"caught", "rescue", "safe", "round_win", "round_lose", "step", "heart_shield", "power_rush" }
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
print(if #missing == 0 then "[HuzzSfx] All 24 found." else "[HuzzSfx] Missing: " .. table.concat(missing, ", "))
