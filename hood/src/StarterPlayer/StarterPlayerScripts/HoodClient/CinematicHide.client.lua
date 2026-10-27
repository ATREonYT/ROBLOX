-- The box opening has the screen to itself (open item "Box opening: hide the HUD during the cinematic"; Huzz Valley's
-- lesson: no menus or prompts over a cinematic). While PlayerGui's Unboxing is true, every other screen of ours is
-- switched off, and Roblox's backpack and player list too; they come back as they were when it ends. HoodHUD stays on:
-- its column already steps aside for the moment (UnboxingCalm) and the new pair flies into its Shoes square at the end.
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
