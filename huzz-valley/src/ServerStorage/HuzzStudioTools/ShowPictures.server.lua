-- Huzz Valley Studio helper: shows every icon and picture on StarterGui > HuzzUI while you edit (no Play needed).
-- The pictures are built into the game (ReplicatedStorage > Shared > Images) and normally only drawn when it runs;
-- this draws them in Studio too. Nothing is saved or changed: it only displays them.
--
-- Install once: right-click this script (ServerStorage > HuzzStudioTools > ShowPictures) > "Save as Local Plugin...",
-- press Save. From then on it runs by itself every time you open the place in Studio. (In the game itself this
-- script never runs: scripts in ServerStorage don't.) You can also paste it into View > Command Bar to show the
-- pictures once, for this Studio session.
local RunService = game:GetService("RunService")
local okEdit, isEdit = pcall(function() return RunService:IsEdit() end)
if okEdit and not isEdit then return end -- only while editing, never in Play

local StarterGui = game:GetService("StarterGui")

local function loader()
	local ui = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
	ui = ui and ui:FindFirstChild("HuzzClient")
	ui = ui and ui:FindFirstChild("UI")
	local module = ui and ui:FindFirstChild("ImageLoader")
	if not module then return nil end
	local ok, result = pcall(require, module)
	return ok and result or nil
end

local shown = setmetatable({}, { __mode = "k" })
local function show(d: Instance, ImageLoader)
	if shown[d] or not (d:IsA("ImageLabel") or d:IsA("ImageButton")) then return end
	if d.Image ~= "" then return end -- it already has a real (uploaded) image
	local icon, art = d:GetAttribute("Icon"), d:GetAttribute("Art")
	local content = (icon and ImageLoader.content("Icons", icon)) or (art and ImageLoader.content("Art", art))
	if content then
		d.ImageContent = content
		shown[d] = true
	end
end

local function showAll()
	local ui = StarterGui:FindFirstChild("HuzzUI")
	local ImageLoader = ui and loader()
	if not ImageLoader then return 0 end
	local n = 0
	for _, d in ui:GetDescendants() do
		local before = shown[d]
		show(d, ImageLoader)
		if shown[d] and not before then n += 1 end
	end
	return n
end

task.spawn(function()
	-- wait until the place has loaded its UI
	for _ = 1, 60 do
		if StarterGui:FindFirstChild("HuzzUI") then break end
		task.wait(1)
	end
	local n = showAll()
	if n > 0 then print("[Huzz] Showing " .. n .. " pictures in StarterGui > HuzzUI (Studio only).") end
	-- pictures added or re-added while editing (undo, copy-paste, a new HuzzUI) show too
	local pending = false
	StarterGui.DescendantAdded:Connect(function()
		if pending then return end
		pending = true
		task.delay(0.5, function()
			pending = false
			showAll()
		end)
	end)
end)
