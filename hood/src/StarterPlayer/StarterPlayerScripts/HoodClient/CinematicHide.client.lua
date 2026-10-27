-- The box opening has the screen to itself (open item "Box opening: hide the HUD during the cinematic"; Huzz Valley's
-- lesson: no menus or prompts over a cinematic). While PlayerGui's Unboxing is true, every other screen of ours is
-- switched off, and Roblox's backpack and player list too; they come back as they were when it ends. HoodHUD slides
-- aside first (UnboxingCalm), then goes off too (below); it is back on before the new pair flies into its Shoes square.
local Players = game:GetService('Players')
local StarterGui = game:GetService('StarterGui')
local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')

local KEEP = { HoodUnboxing = true, HoodUnboxCinematic = true, HoodAutoStop = true, HoodHotTarget = true, HoodHUD = true, HoodLoading = true, HoodStudioCheck = true }
local CORE = { Enum.CoreGuiType.Backpack, Enum.CoreGuiType.PlayerList }
local hidden, coreWas = {}, {}
local on = false

local function hide()
	if on then return end
	on = true
	for _, g in playerGui:GetChildren() do
		if g:IsA('ScreenGui') and g.Enabled and not KEEP[g.Name] then
			g.Enabled = false
			table.insert(hidden, g)
		end
	end
	for _, t in CORE do
		local ok, was = pcall(function() return StarterGui:GetCoreGuiEnabled(t) end)
		coreWas[t] = ok and was or false
		if coreWas[t] then pcall(function() StarterGui:SetCoreGuiEnabled(t, false) end) end
	end
end

local function show()
	if not on then return end
	on = false
	for _, g in hidden do
		if g.Parent and not g.Enabled then g.Enabled = true end
	end
	table.clear(hidden)
	for t, was in coreWas do
		if was then pcall(function() StarterGui:SetCoreGuiEnabled(t, true) end) end
	end
	table.clear(coreWas)
end

local function sync()
	local ok, err = pcall(function()
		if playerGui:GetAttribute('Unboxing') == true then hide() else show() end
	end)
	if not ok then warn('[CinematicHide] ' .. tostring(err)) end
end
playerGui:GetAttributeChangedSignal('Unboxing'):Connect(sync)
sync()

-- (Oct 27, release fixes) the HUD itself goes too: once its column, cards and bottom block have slid aside (UnboxingCalm,
-- 0.1 s), HoodHUD is switched off, so nothing of it shows over the cinematic; it is switched back on the moment the calm
-- ends, before its pieces slide back and the new pair flies into its Shoes square.
local hudOff = false
local calmTicket = 0
local function hudBack()
	calmTicket += 1
	if not hudOff then return end
	hudOff = false
	local hud = playerGui:FindFirstChild('HoodHUD')
	if hud then hud.Enabled = true end
end
local function syncCalm()
	local ok, err = pcall(function()
		if playerGui:GetAttribute('UnboxingCalm') ~= true then return hudBack() end
		calmTicket += 1
		local ticket = calmTicket
		task.delay(0.12, function()
			if ticket ~= calmTicket or playerGui:GetAttribute('UnboxingCalm') ~= true then return end
			local hud = playerGui:FindFirstChild('HoodHUD')
			if hud and hud.Enabled then
				hud.Enabled = false
				hudOff = true
			end
		end)
	end)
	if not ok then warn('[CinematicHide] ' .. tostring(err)) end
end
playerGui:GetAttributeChangedSignal('UnboxingCalm'):Connect(syncCalm)
-- (a moment that ends without its calm ending first, e.g. a failed cinematic, never leaves the HUD off)
playerGui:GetAttributeChangedSignal('Unboxing'):Connect(function()
	if playerGui:GetAttribute('Unboxing') ~= true then pcall(hudBack) end
end)
