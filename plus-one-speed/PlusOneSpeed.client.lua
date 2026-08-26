--==============================================================================
-- PLUS ONE SPEED: CANDY KEYBOARD  (client script, 2 of 2)
--
-- This is the on-screen GUI: the big speed counter, the wins counter, the
-- left-side buttons (Shop, Trails, Rebirth, Teleport, FREE!), all their
-- windows, and the little "+X" popups every step.
--
-- PASTE THIS into a LocalScript inside StarterPlayer -> StarterPlayerScripts.
-- (The main game script goes in ServerScriptService -- see the README.)
--==============================================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")

local player = Players.LocalPlayer
local net = ReplicatedStorage:WaitForChild("PlusOneSpeedNet")
local stateRemote = net:WaitForChild("State")
local actionRemote = net:WaitForChild("Action")

local config = nil  -- filled by the server's "init" message
local state = nil   -- latest snapshot from the server

--==============================================================================
-- STYLE HELPERS
--==============================================================================

local COLORS = {
	panel = Color3.fromRGB(62, 40, 34),      -- chocolate
	panelLight = Color3.fromRGB(84, 56, 47),
	cream = Color3.fromRGB(255, 244, 220),
	pink = Color3.fromRGB(255, 130, 175),
	yellow = Color3.fromRGB(255, 213, 79),
	green = Color3.fromRGB(140, 255, 160),
	blue = Color3.fromRGB(140, 240, 255),
	red = Color3.fromRGB(255, 120, 120),
}

local function styleText(label, textSize, color)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextSize = textSize
	label.TextColor3 = color or COLORS.cream
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(50, 30, 26)
	stroke.Thickness = 2
	stroke.Parent = label
	return label
end

local function roundFrame(parent, size, position, color)
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = color or COLORS.panel
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.pink
	stroke.Thickness = 3
	stroke.Parent = frame
	frame.Parent = parent
	return frame
end

local function textButton(parent, size, position, text, textSize, bgColor)
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.Text = text
	button.AutoButtonColor = true
	button.BackgroundColor3 = bgColor or COLORS.pink
	button.BorderSizePixel = 0
	styleText(button, textSize or 20, COLORS.cream)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(50, 30, 26)
	stroke.Thickness = 2
	stroke.Parent = button
	button.Parent = parent
	return button
end

local function formatNum(n)
	if n >= 1e12 then return string.format("%.2fT", n / 1e12) end
	if n >= 1e9 then return string.format("%.2fB", n / 1e9) end
	if n >= 1e6 then return string.format("%.2fM", n / 1e6) end
	if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
	return tostring(math.floor(n))
end

--==============================================================================
-- THE SCREEN
--==============================================================================

local screen = Instance.new("ScreenGui")
screen.Name = "CandyKeyboardGui"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = false
screen.Parent = player:WaitForChild("PlayerGui")

-- TOP CENTER: the big speed counter.
local speedPanel = roundFrame(screen, UDim2.new(0, 320, 0, 76), UDim2.new(0.5, -160, 0, 8))
local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(1, -16, 0.58, 0)
speedLabel.Position = UDim2.new(0, 8, 0, 2)
speedLabel.Text = "0 SPEED"
styleText(speedLabel, 34, COLORS.yellow)
speedLabel.Parent = speedPanel
local levelLabel = Instance.new("TextLabel")
levelLabel.Size = UDim2.new(1, -16, 0.36, 0)
levelLabel.Position = UDim2.new(0, 8, 0.6, 0)
levelLabel.Text = ""
styleText(levelLabel, 17, COLORS.cream)
levelLabel.Parent = speedPanel

-- TOP RIGHT: wins.
local winsPanel = roundFrame(screen, UDim2.new(0, 190, 0, 52), UDim2.new(1, -200, 0, 8))
local winsLabel = Instance.new("TextLabel")
winsLabel.Size = UDim2.new(1, -16, 1, 0)
winsLabel.Position = UDim2.new(0, 8, 0, 0)
winsLabel.Text = "WINS: 0"
styleText(winsLabel, 24, COLORS.green)
winsLabel.Parent = winsPanel

--==============================================================================
-- WINDOWS (one open at a time)
--==============================================================================

local openWindow = nil

local function makeWindow(title)
	local window = roundFrame(screen, UDim2.new(0, 420, 0, 380), UDim2.new(0.5, -210, 0.5, -190), COLORS.panel)
	window.Visible = false
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -60, 0, 44)
	titleLabel.Position = UDim2.new(0, 16, 0, 4)
	titleLabel.Text = title
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	styleText(titleLabel, 28, COLORS.yellow)
	titleLabel.Parent = window
	local close = textButton(window, UDim2.new(0, 36, 0, 36), UDim2.new(1, -44, 0, 8), "X", 22, COLORS.red)
	close.Activated:Connect(function()
		window.Visible = false
		openWindow = nil
	end)
	return window
end

local function toggleWindow(window)
	if openWindow == window then
		window.Visible = false
		openWindow = nil
		return
	end
	if openWindow then openWindow.Visible = false end
	window.Visible = true
	openWindow = window
end

local shopWindow = makeWindow("SHOP")
local trailsWindow = makeWindow("TRAILS")
local rebirthWindow = makeWindow("REBIRTH")
local teleportWindow = makeWindow("TELEPORT")
local freeWindow = makeWindow("FREE STUFF!")

-- LEFT COLUMN: the buttons that open the windows.
local buttonDefs = {
	{ label = "SHOP",  window = shopWindow,     color = COLORS.pink },
	{ label = "TRAILS", window = trailsWindow,  color = Color3.fromRGB(186, 104, 255) },
	{ label = "REBIRTH", window = rebirthWindow, color = Color3.fromRGB(255, 160, 220) },
	{ label = "TELEPORT", window = teleportWindow, color = COLORS.blue },
	{ label = "FREE!", window = freeWindow,     color = COLORS.green },
}
for i, def in ipairs(buttonDefs) do
	local button = textButton(screen, UDim2.new(0, 110, 0, 44),
		UDim2.new(0, 10, 0.28, (i - 1) * 52), def.label, 19, def.color)
	button.Activated:Connect(function() toggleWindow(def.window) end)
end

--==============================================================================
-- SHOP WINDOW: the x2 boost + where to find plates and treadmills
--==============================================================================

local boostButton = textButton(shopWindow, UDim2.new(1, -32, 0, 54), UDim2.new(0, 16, 0, 56), "", 20, COLORS.yellow)
boostButton.Activated:Connect(function()
	actionRemote:FireServer({ t = "boost" })
end)
local shopInfo = Instance.new("TextLabel")
shopInfo.Size = UDim2.new(1, -32, 0, 240)
shopInfo.Position = UDim2.new(0, 16, 0, 122)
shopInfo.TextWrapped = true
shopInfo.TextYAlignment = Enum.TextYAlignment.Top
shopInfo.TextXAlignment = Enum.TextXAlignment.Left
shopInfo.Text = ""
styleText(shopInfo, 18, COLORS.cream)
shopInfo.Parent = shopWindow

--==============================================================================
-- TRAILS WINDOW: buy them in order, each multiplies your speed gain
--==============================================================================

local trailRows = {}
local function buildTrailRows()
	for _, row in ipairs(trailRows) do row.frame:Destroy() end
	table.clear(trailRows)
	if not config then return end
	for i, trail in ipairs(config.trails) do
		local rowFrame = Instance.new("Frame")
		rowFrame.Size = UDim2.new(1, -32, 0, 40)
		rowFrame.Position = UDim2.new(0, 16, 0, 50 + (i - 1) * 45)
		rowFrame.BackgroundColor3 = COLORS.panelLight
		rowFrame.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = rowFrame
		rowFrame.Parent = trailsWindow

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(0.55, 0, 1, 0)
		name.Position = UDim2.new(0, 10, 0, 0)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = trail.name .. "  (x" .. trail.mult .. ")"
		styleText(name, 17, trail.color or COLORS.pink)
		name.Parent = rowFrame

		local buy = textButton(rowFrame, UDim2.new(0.38, 0, 0, 32), UDim2.new(0.6, 0, 0, 4), "", 15, COLORS.green)
		buy.Activated:Connect(function()
			actionRemote:FireServer({ t = "buyTrail", i = i })
		end)
		trailRows[i] = { frame = rowFrame, buy = buy, trail = trail }
	end
end

--==============================================================================
-- REBIRTH WINDOW
--==============================================================================

local rebirthInfo = Instance.new("TextLabel")
rebirthInfo.Size = UDim2.new(1, -32, 0, 150)
rebirthInfo.Position = UDim2.new(0, 16, 0, 52)
rebirthInfo.TextWrapped = true
rebirthInfo.TextYAlignment = Enum.TextYAlignment.Top
rebirthInfo.Text = ""
styleText(rebirthInfo, 20, COLORS.cream)
rebirthInfo.Parent = rebirthWindow

local rebirthBarBack = Instance.new("Frame")
rebirthBarBack.Size = UDim2.new(1, -32, 0, 22)
rebirthBarBack.Position = UDim2.new(0, 16, 0, 210)
rebirthBarBack.BackgroundColor3 = COLORS.panelLight
rebirthBarBack.BorderSizePixel = 0
local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 11)
barCorner.Parent = rebirthBarBack
rebirthBarBack.Parent = rebirthWindow
local rebirthBarFill = Instance.new("Frame")
rebirthBarFill.Size = UDim2.new(0, 0, 1, 0)
rebirthBarFill.BackgroundColor3 = Color3.fromRGB(255, 160, 220)
rebirthBarFill.BorderSizePixel = 0
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 11)
fillCorner.Parent = rebirthBarFill
rebirthBarFill.Parent = rebirthBarBack

local rebirthButton = textButton(rebirthWindow, UDim2.new(1, -32, 0, 56), UDim2.new(0, 16, 1, -76), "REBIRTH!", 26, Color3.fromRGB(255, 160, 220))
rebirthButton.Activated:Connect(function()
	actionRemote:FireServer({ t = "rebirth" })
end)

--==============================================================================
-- TELEPORT WINDOW
--==============================================================================

local teleportRows = {}
local lastReachable = -1
local function rebuildTeleportRows()
	if not config or not state then return end
	local reachable = math.min(state.checkpointMax + 1, #config.stages)
	if reachable == lastReachable then return end -- don't rebuild under the user's cursor
	lastReachable = reachable
	for _, row in ipairs(teleportRows) do row:Destroy() end
	table.clear(teleportRows)
	for stage = 1, reachable do
		local cost = stage * config.teleportCostPerStage
		local row = textButton(teleportWindow,
			UDim2.new(1, -32, 0, 36), UDim2.new(0, 16, 0, 50 + (stage - 1) * 41),
			"Stage " .. stage .. ": " .. config.stages[stage].name .. "  (" .. formatNum(cost) .. " Wins)",
			16, stage <= state.checkpointMax and COLORS.blue or COLORS.yellow)
		row.Activated:Connect(function()
			actionRemote:FireServer({ t = "teleport", stage = stage })
		end)
		table.insert(teleportRows, row)
	end
end

--==============================================================================
-- FREE WINDOW
--==============================================================================

local freeInfo = Instance.new("TextLabel")
freeInfo.Size = UDim2.new(1, -32, 0, 160)
freeInfo.Position = UDim2.new(0, 16, 0, 56)
freeInfo.TextWrapped = true
freeInfo.TextYAlignment = Enum.TextYAlignment.Top
freeInfo.Text = "Welcome gift! Claim a one-time speed boost to get you flying. (In big games this is where 'join the group' rewards live -- for us it's just free.)"
styleText(freeInfo, 19, COLORS.cream)
freeInfo.Parent = freeWindow

local freeButton = textButton(freeWindow, UDim2.new(1, -32, 0, 56), UDim2.new(0, 16, 1, -76), "CLAIM!", 26, COLORS.green)
freeButton.Activated:Connect(function()
	actionRemote:FireServer({ t = "free" })
end)

--==============================================================================
-- BANNERS + PER-STEP POPUPS
--==============================================================================

local function banner(text, color)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 400, 0, 46)
	label.Position = UDim2.new(0.5, -200, 0.22, 0)
	label.BackgroundColor3 = COLORS.panel
	label.BackgroundTransparency = 0.15
	label.Text = text
	styleText(label, 28, color)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = label
	label.Parent = screen
	local tween = TweenService:Create(label, TweenInfo.new(1.6, Enum.EasingStyle.Quad),
		{ Position = UDim2.new(0.5, -200, 0.14, 0), TextTransparency = 1, BackgroundTransparency = 1 })
	tween:Play()
	task.delay(1.7, function() label:Destroy() end)
end

-- Little "+X" popups as you run: tracked from our own character's movement.
local stepAcc = 0
local lastPos = nil
local activePopups = 0

local function stepPopup()
	if not state or activePopups > 8 then return end
	activePopups += 1
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0, 120, 0, 30)
	label.Position = UDim2.new(0.5, math.random(-90, 60), 0.62, math.random(-16, 16))
	label.Text = "+" .. formatNum(state.stepValue)
	styleText(label, 22, COLORS.yellow)
	label.Rotation = math.random(-12, 12)
	label.Parent = screen
	local tween = TweenService:Create(label, TweenInfo.new(0.7, Enum.EasingStyle.Quad),
		{ Position = label.Position - UDim2.new(0, 0, 0, 46), TextTransparency = 1 })
	tween:Play()
	task.delay(0.75, function()
		label:Destroy()
		activePopups -= 1
	end)
end

RunService.Heartbeat:Connect(function()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then lastPos = nil return end
	if lastPos then
		local delta = Vector3.new(hrp.Position.X - lastPos.X, 0, hrp.Position.Z - lastPos.Z).Magnitude
		if delta < 30 then
			stepAcc += delta
			if stepAcc >= 3.5 then
				stepAcc -= 3.5
				stepPopup()
			end
		end
	end
	lastPos = hrp.Position
end)

--==============================================================================
-- STATE UPDATES FROM THE SERVER
--==============================================================================

local function refresh()
	if not state then return end
	speedLabel.Text = formatNum(state.speed) .. " SPEED"
	levelLabel.Text = "Level " .. state.level .. "   |   +" .. formatNum(state.stepValue) .. " per step"
		.. (state.boostRemaining > 0 and ("   |   x2 BOOST " .. math.floor(state.boostRemaining / 60) .. ":" .. string.format("%02d", state.boostRemaining % 60)) or "")
	winsLabel.Text = "WINS: " .. formatNum(state.wins)

	-- shop
	if state.boostRemaining > 0 then
		boostButton.Text = "x2 BOOST ACTIVE (" .. math.floor(state.boostRemaining / 60) .. " min left)"
	elseif config then
		boostButton.Text = "Buy x2 Speed Boost - " .. formatNum(config.boostCost) .. " Wins (" .. math.floor(config.boostLength / 60) .. " min)"
	end
	if config then
		local plateLine
		if state.plateIndex >= #config.plates then
			plateLine = "DIGIT PLATES: all " .. #config.plates .. " owned! (+" .. config.plates[#config.plates].bonus .. "/step)"
		else
			local nextPlate = config.plates[state.plateIndex + 1]
			plateLine = "DIGIT PLATES: " .. state.plateIndex .. "/" .. #config.plates
				.. " owned. Next: +" .. nextPlate.bonus .. "/step for " .. formatNum(nextPlate.cost)
				.. " Wins - buy it AT THE PLATES in the lobby (east side)."
		end
		local treadmillLine
		if state.treadmillTier >= #config.treadmills then
			treadmillLine = "TREADMILLS: best tier owned (" .. config.treadmills[state.treadmillTier].name .. ")"
		else
			local nextTreadmill = config.treadmills[state.treadmillTier + 1]
			treadmillLine = "TREADMILLS: using " .. config.treadmills[state.treadmillTier].name
				.. ". Upgrade: " .. nextTreadmill.name .. " (x" .. nextTreadmill.mult .. ") for "
				.. formatNum(nextTreadmill.cost) .. " Wins - buy it AT THE TREADMILLS (west side)."
		end
		shopInfo.Text = plateLine .. "\n\n" .. treadmillLine .. "\n\nTrails are in their own window - they multiply EVERYTHING."
	end

	-- trails
	for i, row in ipairs(trailRows) do
		if state.trailIndex >= i then
			row.buy.Text = (state.trailIndex == i) and "EQUIPPED" or "OWNED"
			row.buy.BackgroundColor3 = COLORS.panelLight
		elseif i == state.trailIndex + 1 then
			row.buy.Text = "BUY - " .. formatNum(row.trail.cost)
			row.buy.BackgroundColor3 = COLORS.green
		else
			row.buy.Text = formatNum(row.trail.cost) .. " Wins"
			row.buy.BackgroundColor3 = COLORS.panelLight
		end
	end

	-- rebirth
	rebirthInfo.Text = "Rebirths: " .. state.rebirths .. "  (current multiplier x" .. state.curMult .. ")"
		.. "\n\nNext rebirth: permanent x" .. state.nextRebirthMult .. " speed gain"
		.. "\nRequires Level " .. state.nextRebirthLevel .. "  (you are Level " .. state.level .. ")"
		.. "\n\nRebirthing resets your Speed to 0. Wins, trails, plates and treadmills all stay!"
	local progress = math.clamp(state.level / state.nextRebirthLevel, 0, 1)
	rebirthBarFill.Size = UDim2.new(progress, 0, 1, 0)
	if state.level >= state.nextRebirthLevel then
		rebirthButton.Text = "REBIRTH! (x" .. state.nextRebirthMult .. ")"
		rebirthButton.BackgroundColor3 = Color3.fromRGB(255, 160, 220)
	else
		rebirthButton.Text = "Need Level " .. state.nextRebirthLevel
		rebirthButton.BackgroundColor3 = COLORS.panelLight
	end

	-- free
	if state.freeClaimed then
		freeButton.Text = "CLAIMED!"
		freeButton.BackgroundColor3 = COLORS.panelLight
	elseif config then
		freeButton.Text = "CLAIM +" .. formatNum(config.freeReward) .. " SPEED!"
		freeButton.BackgroundColor3 = COLORS.green
	end

	rebuildTeleportRows()
end

stateRemote.OnClientEvent:Connect(function(kind, payload, extra)
	if kind == "init" then
		config = payload
		buildTrailRows()
		refresh()
	elseif kind == "state" then
		state = payload
		refresh()
	elseif kind == "win" then
		banner("STAGE " .. tostring(payload) .. " CLEAR!  +" .. formatNum(extra) .. " WINS!", COLORS.yellow)
	elseif kind == "fell" then
		banner("YOU FELL! Back to spawn... (Teleport menu saves your legs)", COLORS.red)
	end
end)

print("Candy Keyboard GUI ready!")
