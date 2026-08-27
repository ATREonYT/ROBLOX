-- TRAIL SHOP GUI -- a card-style shop like the big games use.
-- LOCALSCRIPT in StarterPlayer -> StarterPlayerScripts.
--
-- THE LESSON: everything below is just Frames + UICorner + UIStroke +
-- UIGradient + text, and ONE makeCard() function looped over a table.
-- Change the TRAILS table at the top and the shop rebuilds itself.

local Players = game:GetService("Players")
local player = Players.LocalPlayer

--==============================================================================
-- CONFIG -- the shop's contents. Add a line = a new card appears!
--==============================================================================

local TRAILS = {
	{ name = "Grey Trail",   rarity = "Common",    speed = 1.5, price = 100,    color = Color3.fromRGB(190, 190, 195) },
	{ name = "Green Trail",  rarity = "Uncommon",  speed = 2,   price = 5000,   color = Color3.fromRGB( 80, 200,  90) },
	{ name = "Blue Trail",   rarity = "Rare",      speed = 2.5, price = 25000,  color = Color3.fromRGB( 60, 140, 255) },
	{ name = "Purple Trail", rarity = "Epic",      speed = 3,   price = 100000, color = Color3.fromRGB(170,  90, 255) },
	{ name = "Gold Trail",   rarity = "Legendary", speed = 4,   price = 500000, color = Color3.fromRGB(255, 200,  60) },
}

local RARITY_COLORS = {
	Common = Color3.fromRGB(120, 120, 125), Uncommon = Color3.fromRGB(60, 160, 70),
	Rare = Color3.fromRGB(40, 100, 200), Epic = Color3.fromRGB(130, 60, 200),
	Legendary = Color3.fromRGB(220, 140, 30),
}

local DEMO_CASH = 10000 -- pretend money so you can test buying

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
-- GIVING THE TRAIL (so equipping actually DOES something)
--==============================================================================

local currentTrail = nil

local function equipTrail(color)
	if currentTrail then currentTrail:Destroy() currentTrail = nil end
	if not color then return end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local a0 = Instance.new("Attachment") a0.Position = Vector3.new(0, 1, 0) a0.Parent = hrp
	local a1 = Instance.new("Attachment") a1.Position = Vector3.new(0, -1, 0) a1.Parent = hrp
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.4
	trail.FaceCamera = true
	trail.LightEmission = 0.6
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = hrp
	currentTrail = trail
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

-- Demo cash display (top-right, under the X).
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

local cash = DEMO_CASH
local ownedTrails = {}   -- [name] = true once bought
local equippedName = nil
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

	-- the "x2 Speed" chip: dark translucent bar
	local chip = Instance.new("Frame")
	chip.Size = UDim2.new(1, -24, 0, 38)
	chip.Position = UDim2.new(0, 12, 0, 192)
	chip.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	chip.BackgroundTransparency = 0.35
	corner(chip, 10)
	chip.Parent = card
	local chipText = text(chip, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), "", 24)
	chipText.RichText = true -- lets us color just the "x2" part green
	chipText.Text = '<font color="#7CFF7C">x' .. trail.speed .. '</font> Speed'

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
		cashLabel.Text = formatCash(cash)
		if equippedName == trail.name then
			action.Text = "Unequip"
			action.BackgroundColor3 = Color3.fromRGB(110, 190, 110)
		elseif ownedTrails[trail.name] then
			action.Text = "Equip"
			action.BackgroundColor3 = Color3.fromRGB(70, 150, 255)
		else
			action.Text = formatCash(trail.price)
			action.BackgroundColor3 = Color3.fromRGB(60, 200, 80)
		end
	end

	action.Activated:Connect(function()
		if equippedName == trail.name then
			equippedName = nil
			equipTrail(nil)
		elseif ownedTrails[trail.name] then
			equippedName = trail.name
			equipTrail(trail.color)
		elseif cash >= trail.price then
			cash -= trail.price
			ownedTrails[trail.name] = true
			equippedName = trail.name
			equipTrail(trail.color)
		else
			action.Text = "Too poor!" -- brief feedback, then back to price
			task.delay(0.7, refresh)
			return
		end
		refreshAll()
	end)

	return refresh
end

-- Build every card from the table, keep their refresh functions.
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
end)
closeButton.Activated:Connect(function()
	window.Visible = false
end)

-- Re-give the equipped trail after you respawn.
player.CharacterAdded:Connect(function()
	task.wait(0.5)
	for _, trail in ipairs(TRAILS) do
		if trail.name == equippedName then equipTrail(trail.color) end
	end
end)

--==============================================================================
-- SHOP ZONE -- step into the area and the shop opens by itself.
-- Needs a part named "TrailShopZone" covering the area.
--==============================================================================

local RunService = game:GetService("RunService")

task.spawn(function()
	local zone = workspace:FindFirstChild("TrailShopZone", true)
	local waited = 0
	while not zone do
		task.wait(0.2)
		waited += 0.2
		if waited > 5 and waited < 5.4 then
			warn("[TrailShop] No part named 'TrailShopZone' found! Make one covering your shop area.")
			warn("[TrailShop] Things I can see in the workspace:")
			for _, child in ipairs(workspace:GetChildren()) do
				if child:IsA("BasePart") or child:IsA("Model") then
					warn("   -> " .. child.Name .. "  (" .. child.ClassName .. ")")
				end
			end
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
		elseif not inside and wasInside then
			window.Visible = false     -- just walked OUT -> close it
		end
		wasInside = inside
	end)
end)
