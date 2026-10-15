-- Huzz Valley Studio helper. Install once: right-click this script (ServerStorage > HuzzStudioTools > ShowPictures)
-- > "Save as Local Plugin..." > Save. A "Huzz Valley" toolbar then appears in Studio's Plugins tab, with two buttons:
--   Show Pictures   - draws every icon and picture on StarterGui > HuzzUI while you edit (it also runs by itself
--                     each time you open the place). Display only: nothing is saved.
--   Upload Pictures - uploads every picture to Roblox once and puts the real image IDs on StarterGui > HuzzUI and in
--                     ReplicatedStorage > Shared > Config > ImageIds. After that they show everywhere, with or without
--                     this helper. Save the place afterwards, and send Claude the ImageIds text.
-- Everything it does is written in the Output window (View > Output), starting with [Huzz].
-- In the game this script never runs (scripts in ServerStorage don't). Pasting it into the Command Bar runs
-- Show Pictures once.
local RunService = game:GetService("RunService")
local okEdit, isEdit = pcall(function() return RunService:IsEdit() end)
if okEdit and not isEdit then return end -- only while editing, never in Play

local AssetService = game:GetService("AssetService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function say(text: string) print("[Huzz] " .. text) end

local function imageLoader()
	local module = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
	module = module and module:FindFirstChild("HuzzClient")
	module = module and module:FindFirstChild("UI")
	module = module and module:FindFirstChild("ImageLoader")
	if not module then return nil, "StarterPlayerScripts > HuzzClient > UI > ImageLoader is missing" end
	local ok, result = pcall(require, module)
	if not ok then return nil, tostring(result) end
	return result
end

local function images(): { Instance }
	local ui = StarterGui:FindFirstChild("HuzzUI")
	local list = {}
	if not ui then return list end
	for _, d in ui:GetDescendants() do
		if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and (d:GetAttribute("Icon") or d:GetAttribute("Art")) then
			table.insert(list, d)
		end
	end
	return list
end

-- Show Pictures ---------------------------------------------------------------------------------------------------
local function showPictures(quiet: boolean?)
	if not StarterGui:FindFirstChild("HuzzUI") then
		say("StarterGui > HuzzUI is missing, so there is nothing to show.")
		return
	end
	local ImageLoader, why = imageLoader()
	if not ImageLoader then
		say("Can't load the pictures: " .. tostring(why))
		return
	end
	local shown, already, failed, firstError = 0, 0, 0, nil
	for _, d in images() do
		if d.Image ~= "" then
			already += 1
		else
			local kind = if d:GetAttribute("Icon") then "Icons" else "Art"
			local name = d:GetAttribute("Icon") or d:GetAttribute("Art")
			local ok, err = pcall(function()
				local image = ImageLoader.editable(kind, name)
				d.ImageContent = Content.fromObject(image)
			end)
			if ok then shown += 1 else
				failed += 1
				firstError = firstError or (kind .. "/" .. tostring(name) .. ": " .. tostring(err))
			end
		end
	end
	if not quiet or shown > 0 or failed > 0 then
		say(string.format("Show Pictures: %d shown, %d already have uploaded images, %d failed.", shown, already, failed))
	end
	if firstError then
		warn("[Huzz] First problem: " .. firstError)
		warn("[Huzz] If this keeps happening, use Upload Pictures instead, or send Claude a screenshot of this Output window.")
	end
end

-- Upload Pictures -------------------------------------------------------------------------------------------------
local function uploadPictures()
	local ImageLoader, why = imageLoader()
	if not ImageLoader then
		say("Can't load the pictures: " .. tostring(why))
		return
	end
	local Shared = ReplicatedStorage:FindFirstChild("Shared")
	if not (Shared and Shared:FindFirstChild("Images") and Shared:FindFirstChild("Config")) then
		say("ReplicatedStorage > Shared is missing its Images or Config folder.")
		return
	end
	local idsModule = Shared.Config:FindFirstChild("ImageIds")
	local ids = {}
	if idsModule then -- (read the text: a required ModuleScript would be stale after a re-run)
		for key, id in string.gmatch(idsModule.Source, '%["([^"]+)"%]%s*=%s*"([^"]*)"') do ids[key] = id end
	end
	local creatorType, creatorId = Enum.AssetCreatorType.User, game:GetService("StudioService"):GetUserId()
	if game.CreatorType == Enum.CreatorType.Group and game.CreatorId > 0 then
		creatorType, creatorId = Enum.AssetCreatorType.Group, game.CreatorId
	end
	say("Uploading pictures... this takes about a minute. Studio may ask you to confirm.")
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
				if #failed == 3 and uploaded == 0 then break end -- the same problem every time; stop and report it
			else
				uploaded += 1
			end
			task.wait(0.3)
		end
	end
	local keys = {}
	for key in ids do table.insert(keys, key) end
	table.sort(keys)
	local lines = {
		"-- Uploaded image IDs, written by the Huzz Valley Studio helper (Upload Pictures).",
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
	local placed = 0
	for _, d in images() do
		local icon, art = d:GetAttribute("Icon"), d:GetAttribute("Art")
		local id = (icon and ids["Icons/" .. icon]) or (art and ids["Art/" .. art])
		if id and id ~= "" and d.Image ~= id then
			d.Image = id
			placed += 1
		end
	end
	say(string.format("Upload Pictures: %d uploaded, %d already uploaded, %d images updated in StarterGui.", uploaded, skipped, placed))
	if #failed > 0 then
		warn("[Huzz] " .. #failed .. " could not be uploaded. First problem: " .. failed[1])
		warn("[Huzz] Send Claude a screenshot of this Output window.")
	else
		say("Done. Now save the place (File > Save) and send Claude the text of ReplicatedStorage > Shared > Config > ImageIds.")
	end
end

-- Start -----------------------------------------------------------------------------------------------------------
local pluginObject = plugin -- (nil when pasted into the Command Bar)
if pluginObject then
	local toolbar = pluginObject:CreateToolbar("Huzz Valley")
	local showButton = toolbar:CreateButton("Show Pictures", "Show every icon and picture in StarterGui while editing", "")
	local uploadButton = toolbar:CreateButton("Upload Pictures", "Upload the pictures to Roblox once, so they show everywhere", "")
	showButton.ClickableWhenViewportHidden = true
	uploadButton.ClickableWhenViewportHidden = true
	showButton.Click:Connect(function() showPictures(false) end)
	uploadButton.Click:Connect(function() task.spawn(uploadPictures) end)
end

task.spawn(function()
	for _ = 1, 60 do -- wait until the place has loaded its UI
		if StarterGui:FindFirstChild("HuzzUI") then break end
		task.wait(1)
	end
	if not StarterGui:FindFirstChild("HuzzUI") then return end -- another place: stay quiet
	say("Huzz Valley helper is on.")
	showPictures(false)
	local pending = false
	StarterGui.DescendantAdded:Connect(function()
		if pending then return end
		pending = true
		task.delay(0.5, function()
			pending = false
			showPictures(true)
		end)
	end)
end)
