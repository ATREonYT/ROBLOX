-- TRAIL SHOP GUI -- a card-style shop like the big games use.
-- LOCALSCRIPT in StarterPlayer -> StarterPlayerScripts.
--
-- THE LESSON: this script only DRAWS the shop. The SERVER (EggGame) owns
-- the truth: the trail catalog, your cash, what you own, what's equipped.
-- We ask for the catalog once, show it as cards, and every button press
-- just sends a polite request -- the server checks your cash, grants the
-- trail, and tells us to redraw. That's why exploiters can't give
-- themselves free trails, and why everyone else SEES your trail too.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

--==============================================================================
-- TALKING TO THE SERVER -- the three remotes EggGame created for us
--==============================================================================

local remotes = ReplicatedStorage:WaitForChild("EggRemotes", 30)
if not remotes then
	warn("[TrailShop] Can't find EggRemotes - is EggGame.server.lua in ServerScriptService?")
	return
end
local getTrailData = remotes:WaitForChild("GetTrailData")
local trailAction = remotes:WaitForChild("TrailAction")
local trailUpdate = remotes:WaitForChild("TrailUpdate")

-- One InvokeServer call fetches everything: the catalog + what we own.
local shopData = getTrailData:InvokeServer()
local TRAILS = shopData.catalog
local owned = shopData.owned or {}
local equippedName = shopData.equipped ~= "" and shopData.equipped or nil

local RARITY_COLORS = {
	Common = Color3.fromRGB(120, 120, 125), Uncommon = Color3.fromRGB(60, 160, 70),
	Rare = Color3.fromRGB(40, 100, 200), Epic = Color3.fromRGB(130, 60, 200),
	Legendary = Color3.fromRGB(220, 140, 30),
}

-- Real cash comes from leaderstats (the server updates it every second).
local cashValue = nil
task.spawn(function()
	local stats = player:WaitForChild("leaderstats", 30)
	cashValue = stats and stats:WaitForChild("Cash", 30)
end)

local function getCash()
	return cashValue and cashValue.Value or 0
end

--==============================================================================
-- LITTLE STYLE HELPERS (these four ARE the whole art style)
--==============================================================================

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 12)
	c.Parent = parent
end

local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(30, 30, 40)
	s.Thickness = thickness or 3
	s.Parent = parent
end

-- The subtle top-to-bottom shine every "pro" panel has.
local function shine(parent, topColor, bottomColor)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(topColor, bottomColor)
	g.Rotation = 90
	g.Parent = parent
end

local function text(parent, size, position, str, textSize, color, isButton)
	local label = Instance.new(isButton and "TextButton" or "TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextSize = textSize
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.Text = str
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(30, 30, 40)
	s.Thickness = 2
	s.Parent = label
	label.Parent = parent
	return label
end

--==============================================================================
-- THE WINDOW
--==============================================================================

local screen = Instance.new("ScreenGui")
screen.Name = "TrailShopGui"
screen.ResetOnSpawn = false
screen.Parent = player:WaitForChild("PlayerGui")

-- The main panel: one dark frame in the middle of the screen.
local window = Instance.new("Frame")
window.Size = UDim2.new(0, 720, 0, 430)
window.Position = UDim2.new(0.5, -360, 0.5, -215)
window.BackgroundColor3 = Color3.fromRGB(45, 40, 55)
window.Visible = false
corner(window, 18)
stroke(window, Color3.fromRGB(25, 22, 32), 4)
window.Parent = screen

-- TITLE BAR: pink, with a gradient shine, title on the left, X on the right.
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 62)
titleBar.BackgroundColor3 = Color3.fromRGB(255, 70, 200)
corner(titleBar, 18)
shine(titleBar, Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 140, 220))
titleBar.Parent = window
text(titleBar, UDim2.new(0.6, 0, 1, 0), UDim2.new(0, 22, 0, 0), "Trail Shop", 38).TextXAlignment = Enum.TextXAlignment.Left

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 46, 0, 46)
closeButton.Position = UDim2.new(1, -56, 0, 8)
closeButton.BackgroundColor3 = Color3.fromRGB(235, 50, 50)
closeButton.Font = Enum.Font.FredokaOne
closeButton.TextSize = 28
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.Text = "X"
corner(closeButton, 10)
stroke(closeButton)
closeButton.Parent = titleBar

-- Cash display (top-right, under the X) -- your REAL cash this time!
local cashLabel = text(window, UDim2.new(0, 200, 0, 30), UDim2.new(1, -212, 0, 68), "", 20, Color3.fromRGB(140, 255, 140))
cashLabel.TextXAlignment = Enum.TextXAlignment.Right

-- SCROLLER: a horizontal strip that holds the cards. The UIListLayout
-- inside it lines the cards up automatically -- you never position cards!
local scroller = Instance.new("ScrollingFrame")
scroller.Size = UDim2.new(1, -32, 1, -116)
scroller.Position = UDim2.new(0, 16, 0, 100)
scroller.BackgroundTransparency = 1
scroller.BorderSizePixel = 0
scroller.ScrollingDirection = Enum.ScrollingDirection.X
scroller.ScrollBarThickness = 8
scroller.Parent = window

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 14)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = scroller

--==============================================================================
-- ONE CARD FUNCTION + A LOOP = THE WHOLE SHOP (this is the big trick!)
--==============================================================================

local refreshAll -- declared here so cards can call it

local function formatCash(n)
	if n >= 1e6 then return string.format("$%.1fM", n / 1e6) end
	if n >= 1e3 then return string.format("$%.0fK", n / 1e3) end
	return "$" .. n
end

local function makeCard(trail, order)
	local rarityColor = RARITY_COLORS[trail.rarity] or Color3.fromRGB(100, 100, 100)

	-- the card itself, tinted toward the trail's color
	local card = Instance.new("Frame")
	card.Size = UDim2.new(0, 210, 0, 296)
	card.LayoutOrder = order
	card.BackgroundColor3 = trail.color
	corner(card, 14)
	stroke(card, Color3.fromRGB(25, 22, 32), 3)
	shine(card, Color3.fromRGB(255, 255, 255), Color3.fromRGB(140, 140, 150))
	card.Parent = scroller

	text(card, UDim2.new(1, 0, 0, 34), UDim2.new(0, 0, 0, 8), trail.name, 24)
	text(card, UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 40), trail.rarity, 17, rarityColor)

	-- "preview": a glossy circle in the trail's color
	local preview = Instance.new("Frame")
	preview.Size = UDim2.new(0, 110, 0, 110)
	preview.Position = UDim2.new(0.5, -55, 0, 70)
	preview.BackgroundColor3 = trail.color
	corner(preview, 55) -- radius = half the size makes it a circle!
	stroke(preview, Color3.fromRGB(25, 22, 32), 4)
	shine(preview, Color3.fromRGB(255, 255, 255), trail.color)
	preview.Parent = card

	-- the "+2 Speed" chip: dark translucent bar. Trails make you FASTER --
	-- that's your getaway upgrade when you're carrying a stolen egg!
	local chip = Instance.new("Frame")
	chip.Size = UDim2.new(1, -24, 0, 38)
	chip.Position = UDim2.new(0, 12, 0, 192)
	chip.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	chip.BackgroundTransparency = 0.35
	corner(chip, 10)
	chip.Parent = card
	local chipText = text(chip, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), "", 24)
	chipText.RichText = true -- lets us color just the "+2" part green
	chipText.Text = '<font color="#7CFF7C">+' .. trail.speed .. '</font> Speed'

	-- the action button: its text/color changes with the trail's state
	local action = Instance.new("TextButton")
	action.Size = UDim2.new(1, -24, 0, 42)
	action.Position = UDim2.new(0, 12, 0, 240)
	action.Font = Enum.Font.FredokaOne
	action.TextSize = 24
	action.TextColor3 = Color3.new(1, 1, 1)
	corner(action, 10)
	stroke(action)
	action.Parent = card

	local function refresh()
		cashLabel.Text = formatCash(getCash())
		if equippedName == trail.name then
			action.Text = "Unequip"
			action.BackgroundColor3 = Color3.fromRGB(110, 190, 110)
		elseif owned[trail.name] then
			action.Text = "Equip"
			action.BackgroundColor3 = Color3.fromRGB(70, 150, 255)
		else
			action.Text = formatCash(trail.price)
			action.BackgroundColor3 = Color3.fromRGB(60, 200, 80)
		end
	end

	action.Activated:Connect(function()
		-- Every press is just a REQUEST -- the server has the final say,
		-- then fires TrailUpdate and refreshAll() redraws every card.
		if equippedName == trail.name then
			trailAction:FireServer("unequip")
		elseif owned[trail.name] then
			trailAction:FireServer("equip", trail.name)
		elseif getCash() >= trail.price then
			trailAction:FireServer("buy", trail.name)
		else
			action.Text = "Too poor!" -- brief feedback, then back to price
			task.delay(0.7, refresh)
		end
	end)

	return refresh
end

-- Build every card from the server's catalog, keep their refresh functions.
local refreshers = {}
for i, trail in ipairs(TRAILS) do
	table.insert(refreshers, makeCard(trail, i))
end
function refreshAll()
	for _, refresh in ipairs(refreshers) do refresh() end
end
refreshAll()

-- Tell the scroller how wide its content is, so it can actually scroll.
scroller.CanvasSize = UDim2.new(0, #TRAILS * (210 + 14), 0, 0)

-- The server tells us whenever our trails change (a buy went through, an
-- equip stuck, or our save loaded) -- we just redraw.
trailUpdate.OnClientEvent:Connect(function(newOwned, newEquipped)
	owned = newOwned or {}
	equippedName = newEquipped ~= "" and newEquipped or nil
	refreshAll()
end)

-- Keep the cash label live while the window is open.
task.spawn(function()
	while true do
		task.wait(1)
		if window.Visible then
			cashLabel.Text = formatCash(getCash())
		end
	end
end)

--==============================================================================
-- OPEN / CLOSE
--==============================================================================

local toggle = Instance.new("TextButton")
toggle.Size = UDim2.new(0, 120, 0, 48)
toggle.Position = UDim2.new(0, 12, 0.4, 0)
toggle.BackgroundColor3 = Color3.fromRGB(255, 70, 200)
toggle.Font = Enum.Font.FredokaOne
toggle.TextSize = 22
toggle.TextColor3 = Color3.new(1, 1, 1)
toggle.Text = "TRAILS"
corner(toggle, 12)
stroke(toggle)
toggle.Parent = screen

toggle.Activated:Connect(function()
	window.Visible = not window.Visible
	if window.Visible then refreshAll() end
end)
closeButton.Activated:Connect(function()
	window.Visible = false
end)

--==============================================================================
-- SHOP ZONE -- step into the area and the shop opens by itself.
-- Needs a part named "TrailShopZone" covering the area (EggGame builds a
-- shop stand with one in the SAFE ZONE if your map doesn't have one).
--==============================================================================

task.spawn(function()
	local zone = workspace:FindFirstChild("TrailShopZone", true)
	local waited = 0
	while not zone do
		task.wait(0.2)
		waited += 0.2
		if waited > 5 and waited < 5.4 then
			warn("[TrailShop] No part named 'TrailShopZone' found! Make one covering your shop area.")
		end
		zone = workspace:FindFirstChild("TrailShopZone", true)
	end
	if zone:IsA("Model") then
		zone = zone:FindFirstChildWhichIsA("BasePart", true)
		if not zone then return end
	end

	local wasInside = false
	RunService.Heartbeat:Connect(function()
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		-- Am I inside the zone's box? (works even if the zone is rotated)
		local localPos = zone.CFrame:PointToObjectSpace(hrp.Position)
		local half = zone.Size / 2
		local inside = math.abs(localPos.X) <= half.X
			and math.abs(localPos.Y) <= half.Y
			and math.abs(localPos.Z) <= half.Z

		if inside and not wasInside then
			window.Visible = true      -- just walked IN -> open the shop
			refreshAll()
		elseif not inside and wasInside then
			window.Visible = false     -- just walked OUT -> close it
		end
		wasInside = inside
	end)
end)
