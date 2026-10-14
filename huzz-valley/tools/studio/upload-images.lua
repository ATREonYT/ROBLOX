-- Huzz Valley: upload every UI picture to Roblox once, so they show everywhere, including StarterGui while you edit.
-- How: open the Huzz Valley place in Studio (not while playing), open View > Command Bar, paste this whole file,
-- press Enter, and wait for "Done" in the Output window (about a minute). Run it again any time: images that
-- already have an ID are skipped.
-- What it does:
--   1. uploads each built-in picture (ReplicatedStorage > Shared > Images) to your Roblox account (or your group,
--      if the place belongs to one);
--   2. writes the new IDs into ReplicatedStorage > Shared > Config > ImageIds, which the game reads;
--   3. puts each ID on the matching image in StarterGui > HuzzUI, so you see the pictures while editing.
-- New uploads are checked by Roblox first, so a picture can stay grey for a few minutes.
local AssetService = game:GetService("AssetService")
local StudioService = game:GetService("StudioService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ImageLoader = require(game:GetService("StarterPlayer").StarterPlayerScripts.HuzzClient.UI.ImageLoader)

local idsModule = Shared.Config:FindFirstChild("ImageIds")
local ids = {}
if idsModule then -- (read the text: a required ModuleScript would be stale after a re-run)
	for key, id in string.gmatch(idsModule.Source, '%["([^"]+)"%]%s*=%s*"([^"]*)"') do ids[key] = id end
end

local creatorType, creatorId = Enum.AssetCreatorType.User, StudioService:GetUserId()
if game.CreatorType == Enum.CreatorType.Group and game.CreatorId > 0 then
	creatorType, creatorId = Enum.AssetCreatorType.Group, game.CreatorId
end

local uploaded, skipped, failed = 0, 0, {}
for _, kind in { "Icons", "Art" } do
	for _, module in Shared.Images[kind]:GetChildren() do
		local key = kind .. "/" .. module.Name
		if ids[key] and ids[key] ~= "" then
			skipped += 1
			continue
		end
		local lastError
		for _ = 1, 3 do
			local ok, err = pcall(function()
				local image = ImageLoader.editable(kind, module.Name)
				local result, assetId = AssetService:CreateAssetAsync(image, Enum.AssetType.Image, {
					Name = "HuzzValley " .. module.Name,
					Description = "Huzz Valley UI picture",
					CreatorId = creatorId,
					CreatorType = creatorType,
				})
				image:Destroy()
				if result ~= Enum.CreateAssetResult.Success then error(tostring(result)) end
				ids[key] = "rbxassetid://" .. tostring(assetId)
			end)
			if ok then lastError = nil break end
			lastError = err
			task.wait(2)
		end
		if lastError then
			table.insert(failed, key .. ": " .. tostring(lastError))
		else
			uploaded += 1
			print("[Huzz] uploaded " .. key .. " -> " .. ids[key])
		end
		task.wait(0.3)
	end
end

-- 2. Save the IDs where the game reads them.
local keys = {}
for key in ids do table.insert(keys, key) end
table.sort(keys)
local lines = {
	"-- Uploaded image IDs, written by tools/studio/upload-images.lua (run once in Studio's Command Bar).",
	"-- Keys are \"Icons/<Name>\" and \"Art/<Name>\". Config/Assets checks here first.",
	"return {",
}
for _, key in keys do table.insert(lines, string.format('\t["%s"] = "%s",', key, ids[key])) end
table.insert(lines, "}")
if not idsModule then
	idsModule = Instance.new("ModuleScript")
	idsModule.Name = "ImageIds"
	idsModule.Parent = Shared.Config
end
idsModule.Source = table.concat(lines, "\n") .. "\n"

-- 3. Show them in StarterGui.
local placed = 0
local ui = game:GetService("StarterGui"):FindFirstChild("HuzzUI")
if ui then
	for _, d in ui:GetDescendants() do
		if d:IsA("ImageLabel") or d:IsA("ImageButton") then
			local icon, art = d:GetAttribute("Icon"), d:GetAttribute("Art")
			local id = (icon and ids["Icons/" .. icon]) or (art and ids["Art/" .. art])
			if id and d.Image == "" then
				d.Image = id
				placed += 1
			end
		end
	end
end

print(string.format("[Huzz] Done: %d uploaded, %d already had IDs, %d images filled in StarterGui.", uploaded, skipped, placed))
if #failed > 0 then
	warn("[Huzz] " .. #failed .. " could not be uploaded (send Claude a screenshot of this):")
	for _, f in failed do warn("  " .. f) end
end
print("[Huzz] Next: File > Save, then send Claude ReplicatedStorage > Shared > Config > ImageIds (or its text).")
