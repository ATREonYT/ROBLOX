-- [SFX thread] Patches the sound ids in ReplicatedStorage.MTL.UI.Theme in place (plain find/replace, one hit each),
-- then compile-checks it by requiring a throwaway clone. Leaves every other line (TextBlip, music, colours) alone.
-- Safe to re-run: a pair whose new text is already there counts as done.
local theme = game.ReplicatedStorage.MTL.UI.Theme
local src = theme.Source
local pairs_ = {
	{ 'LevelUp = "rbxassetid://1842141543", -- Victory Lap (sting) (APM)', 'LevelUp = "rbxassetid://105625891237078", -- short UI level-up (CoreKit); HUD plays Theme.Sfx.LevelUp' },
	{ 'Prompt = "rbxassetid://9120917861", -- Wood Impacts Soft Impacts On Temple Blocks 7 (PSE)', 'Prompt = "rbxassetid://10128760939", -- RBLX UI Select 01 (Roblox)' },
	{ 'Hit = "rbxassetid://9113578184", -- Box Slide Cardboard Rub 2 (PSE)', 'Hit = "rbxassetid://10066968815", -- RBLX UI Select 02 (Roblox), pitched up per streak' },
	{ 'Miss = "rbxassetid://9120915095", -- Wood Impacts 2 (PSE)', 'Miss = "rbxassetid://80099403859001", -- UI - Error (SodaBreadle)' },
	{ 'Done = "rbxassetid://9113728756", -- Cash Register 5 (PSE)', 'Done = "rbxassetid://10066947742", -- RBLX UI Purchase (Roblox)' },
	{ 'Step = "rbxassetid://9120917438", -- Wood Impacts Soft Impacts On Temple Blocks 1 (PSE)', 'Step = "rbxassetid://10066968815", -- RBLX UI Select 02 (Roblox)' },
	{ 'Done = "rbxassetid://9113728042", -- Cash Register 1 (PSE)', 'Done = "rbxassetid://10066947742", -- RBLX UI Purchase (Roblox)' },
	{ 'Buy = "rbxassetid://9113728049", -- Cash Register 2 (PSE)', 'Buy = "rbxassetid://10066947742", -- RBLX UI Purchase (Roblox)' },
	{ 'Tap = { id = "rbxassetid://9120232133", volume = 0.4, jitter = 0.04 }, -- mouse click (PSE)', 'Tap = { id = "rbxassetid://10128760939", volume = 0.4, jitter = 0.04 }, -- RBLX UI Select 01 (Roblox)' },
	{ 'Close = { id = "rbxassetid://10128766965", volume = 0.35, pitch = 0.85, jitter = 0 }, -- same swipe, lower', 'Close = { id = "rbxassetid://10066914500", volume = 0.35, jitter = 0 }, -- RBLX UI Back (Roblox)' },
	{ 'Confirm = { id = "rbxassetid://9120917794", volume = 0.45 }, -- soft temple block (PSE)', 'Confirm = { id = "rbxassetid://10066968815", volume = 0.45 }, -- RBLX UI Select 02 (Roblox)' },
	{ 'Error = { id = "rbxassetid://9120915492", volume = 0.4 }, -- dull wood knock (PSE)', 'Error = { id = "rbxassetid://80099403859001", volume = 0.4 }, -- UI - Error (SodaBreadle)\n\t\t-- rewards: short and punchy like other games (each capped at max seconds by UI/Sfx)\n\t\tLevelUp = { id = "rbxassetid://105625891237078", volume = 0.6, jitter = 0, max = 1.5 }, -- UI levelup (CoreKit)\n\t\tToast = { id = "rbxassetid://10066931761", volume = 0.25, jitter = 0.03, max = 0.5 }, -- RBLX UI Hover 01 (Roblox)\n\t\tBuy = { id = "rbxassetid://10066947742", volume = 0.5, jitter = 0 }, -- RBLX UI Purchase (Roblox)' },
	{ 'PhoneBack = { id = "rbxassetid://9113745498", volume = 0.4, pitch = 0.9, jitter = 0.03 },', 'PhoneBack = { id = "rbxassetid://10066914500", volume = 0.35, jitter = 0.03 }, -- RBLX UI Back (Roblox)' },
}
local report = {}
for i, p in pairs_ do
	local a, b = p[1], p[2]
	local s = string.find(src, a, 1, true)
	if s then
		local again = string.find(src, a, s + #a, true)
		if again then
			table.insert(report, i .. ": MORE THAN ONE MATCH, skipped")
		else
			src = string.sub(src, 1, s - 1) .. b .. string.sub(src, s + #a)
			table.insert(report, i .. ": ok")
		end
	elseif string.find(src, (string.split(b, "\n"))[1], 1, true) then
		table.insert(report, i .. ": already done")
	else
		table.insert(report, i .. ": NOT FOUND")
	end
end
-- compile check on a throwaway clone before touching the real module
local tmp = theme:Clone()
tmp.Source = src
tmp.Name = "MTL_SfxPatchCheck"
tmp.Parent = game.ServerStorage
local ok, res = pcall(require, tmp)
tmp:Destroy()
if not ok or type(res) ~= "table" or type(res.Sfx) ~= "table" or not res.Sfx.LevelUp then
	return "COMPILE CHECK FAILED, Theme not changed: " .. tostring(res) .. "\n" .. table.concat(report, "\n")
end
theme.Source = src
return "Theme patched + compiles\n" .. table.concat(report, "\n")
