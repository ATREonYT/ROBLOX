-- Lists what each of the owner's girls carries besides her body (places/HUSSANIME.rbxl, Workspace > ANIME GIRLS):
-- scripts, Animation objects (and their ids), Animators, AnimationControllers, KeyframeSequences, her rig type and
-- joint kinds. Owner Oct 20: "some of the common girls have a nice animation of them when you are holding them".
-- Run from huzz-valley/: lune run tools/girl_survey.luau [place.rbxl]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local place = roblox.deserializePlace(fs.readFile(process.args[1] or "places/HUSSANIME.rbxl"))
local folder = place:GetService("Workspace"):FindFirstChild("ANIME GIRLS")
assert(folder, "no Workspace > ANIME GIRLS")
for _, rarity in folder:GetChildren() do
	for _, girl in rarity:GetChildren() do
		local counts, extra = {}, {}
		for _, d in girl:GetDescendants() do
			local c = d.ClassName
			if d:IsA("LuaSourceContainer") or c == "Animation" or c == "Animator" or c == "AnimationController"
				or c == "KeyframeSequence" or c == "Motor6D" or c == "AnimationConstraint" or c == "Humanoid" then
				counts[c] = (counts[c] or 0) + 1
			end
			if c == "Animation" then
				table.insert(extra, `{d:GetFullName():gsub("^.-ANIME GIRLS%.", "")}={d.AnimationId}`)
			elseif d:IsA("LuaSourceContainer") then
				table.insert(extra, `{c} {d.Name}`)
			end
		end
		local line = {}
		for c, n in counts do table.insert(line, `{c} {n}`) end
		table.sort(line)
		local h = girl:FindFirstChildOfClass("Humanoid")
		print(`{rarity.Name}/{girl.Name} [{girl:GetAttribute("DisplayName") or ""}] rig {h and tostring(h.RigType) or "-"}: {table.concat(line, ", ")}`)
		for _, e in extra do print("    " .. e) end
	end
end
