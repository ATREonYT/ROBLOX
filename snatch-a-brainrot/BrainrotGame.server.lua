--==============================================================================
-- SNATCH A BRAINROT  (v2 -- the pretty one)
-- A complete "Steal a Brainrot"-style game in ONE script.
--
-- HOW TO USE:
--   1. Open Roblox Studio -> new "Baseplate" place
--   2. In the Explorer, find ServerScriptService
--   3. Insert a Script inside it, delete the default code, paste ALL of this
--   4. Press Play. That's the whole setup.
--
-- Brainrots walk down the red carpet in the middle of the map. TAP E next to
-- one to buy it -- it then walks itself to your base and earns cash every
-- second. The cash piles up at your base: stand in your base to collect it!
-- STEAL from other players (hold E on their brainrots), run home to keep it.
-- Lock your base to protect it, slap thieves with your bat, fuse 3 identical
-- brainrots at your Fusion Altar, and don't miss the Brainrot Rush events!
--==============================================================================

--==============================================================================
-- CONFIG -- play with these numbers! Nothing here can break the game.
--==============================================================================

local STARTING_CASH   = 100   -- cash a brand-new player starts with
local PASSIVE_INCOME  = 2     -- free cash per second, so nobody gets stuck at 0
local SPAWN_INTERVAL  = 4     -- seconds between brainrots appearing
local MAX_ON_CONVEYOR = 8     -- max brainrots walking at once
local WALK_SPEED      = 6     -- how fast brainrots walk (studs per second)
local DELIVERY_SPEED  = 16    -- how fast a bought brainrot runs to your base
local SLOTS_PER_BASE  = 10    -- how many brainrots one base can hold
local LOCK_DURATION   = 45    -- seconds your base stays locked
local LOCK_COOLDOWN   = 60    -- seconds before you can lock again
local JOIN_SHIELD     = 60    -- free shield seconds when you first join
local SLAP_RANGE      = 9     -- how close you must be to slap someone
local SLAP_COOLDOWN   = 1.5   -- seconds between slaps
local CARRY_WALKSPEED = 11    -- thieves are slowed while carrying (normal is 16)
local PITY_MINUTES    = 5     -- guaranteed Legendary+ spawn at least this often
local RUSH_EVERY      = 480   -- seconds between Brainrot Rush events
local RUSH_LENGTH     = 60    -- how long a Rush lasts (2x income, juiced luck)
local SAVE_PROGRESS   = true  -- saves cash + brainrots (needs API access, see README)

-- Rarity tiers: chance is a weight (bigger = more common).
local RARITIES = {
	{ name = "Common",       color = Color3.fromRGB(176, 190, 197), chance = 50,   },
	{ name = "Rare",         color = Color3.fromRGB( 66, 165, 245), chance = 26,   },
	{ name = "Epic",         color = Color3.fromRGB(171,  71, 188), chance = 13,   },
	{ name = "Legendary",    color = Color3.fromRGB(255, 179,   0), chance = 7,    },
	{ name = "Mythic",       color = Color3.fromRGB(255,  82,  82), chance = 2.8,  },
	{ name = "Brainrot God", color = Color3.fromRGB(255,  64, 160), chance = 1,    },
	{ name = "Secret",       color = Color3.fromRGB(124,  77, 255), chance = 0.2,  },
}

-- Mutations: rare variants that multiply income. Rolled when one spawns.
local MUTATIONS = {
	{ name = "Gold",    chance = 0.10, incomeMult = 1.25, priceMult = 2,  color = Color3.fromRGB(255, 200,  50) },
	{ name = "Diamond", chance = 0.04, incomeMult = 1.5,  priceMult = 4,  color = Color3.fromRGB(130, 220, 255) },
	{ name = "Rainbow", chance = 0.01, incomeMult = 10,   priceMult = 20, color = Color3.fromRGB(255,   0, 255) },
}

-- The cast (the real Steal a Brainrot roster!).
-- price = cost to buy, income = cash per second, scale = size (1 = normal),
-- look = which body builder to use (see CHARACTER LOOKS section),
-- c1/c2 = main and accent colors.
local CHARACTERS = {
	-- Common
	{ name = "Noobini Pizzanini",      rarity = "Common",       price = 25,      income = 1,     scale = 0.8, look = "blob",   c1 = Color3.fromRGB(255, 213,  79), c2 = Color3.fromRGB(255, 138, 101), hat = "pizza" },
	{ name = "Tim Cheese",             rarity = "Common",       price = 60,      income = 2,     scale = 0.9, look = "cheese", c1 = Color3.fromRGB(255, 202,  40), c2 = Color3.fromRGB(141, 110,  99) },
	{ name = "Fluriflura",             rarity = "Common",       price = 90,      income = 3,     scale = 0.9, look = "blob",   c1 = Color3.fromRGB(244, 143, 177), c2 = Color3.fromRGB(255, 235, 130), hat = "petals" },
	{ name = "Svinina Bombardino",     rarity = "Common",       price = 120,     income = 4,     scale = 1.0, look = "piggy",  c1 = Color3.fromRGB(255, 171, 171), c2 = Color3.fromRGB(239, 108, 108) },
	-- Rare
	{ name = "Trippi Troppi",          rarity = "Rare",         price = 400,     income = 8,     scale = 0.9, look = "shrimp", c1 = Color3.fromRGB(255, 138, 101), c2 = Color3.fromRGB(255, 204, 128) },
	{ name = "Boneca Ambalabu",        rarity = "Rare",         price = 650,     income = 12,    scale = 1.0, look = "tire",   c1 = Color3.fromRGB( 66,  66,  66), c2 = Color3.fromRGB(129, 199, 132) },
	{ name = "Bananita Dolphinita",    rarity = "Rare",         price = 900,     income = 16,    scale = 1.0, look = "banana", c1 = Color3.fromRGB(255, 224,  90), c2 = Color3.fromRGB(100, 181, 246) },
	-- Epic
	{ name = "Cappuccino Assassino",   rarity = "Epic",         price = 2500,    income = 35,    scale = 0.9, look = "cup",    c1 = Color3.fromRGB(161, 110,  75), c2 = Color3.fromRGB(255, 248, 225), katana = true },
	{ name = "Brr Brr Patapim",        rarity = "Epic",         price = 4000,    income = 55,    scale = 1.2, look = "blob",   c1 = Color3.fromRGB(102, 187, 106), c2 = Color3.fromRGB( 56, 142,  60), hat = "leaves", bigfeet = true },
	{ name = "Lirili Larila",          rarity = "Epic",         price = 6000,    income = 80,    scale = 1.2, look = "trunk",  c1 = Color3.fromRGB(129, 199, 132), c2 = Color3.fromRGB(158, 158, 158) },
	-- Legendary
	{ name = "Ballerina Cappuccina",   rarity = "Legendary",    price = 15000,   income = 175,   scale = 0.9, look = "cup",    c1 = Color3.fromRGB(161, 110,  75), c2 = Color3.fromRGB(248, 187, 208), tutu = true },
	{ name = "Chimpanzini Bananini",   rarity = "Legendary",    price = 22000,   income = 250,   scale = 1.0, look = "banana", c1 = Color3.fromRGB(255, 224,  90), c2 = Color3.fromRGB(129, 199, 132) },
	{ name = "Frigo Camelo",           rarity = "Legendary",    price = 30000,   income = 330,   scale = 1.4, look = "fridge", c1 = Color3.fromRGB(236, 239, 241), c2 = Color3.fromRGB(215, 170, 120) },
	{ name = "Burbaloni Luliloli",     rarity = "Legendary",    price = 38000,   income = 400,   scale = 1.1, look = "blob",   c1 = Color3.fromRGB(161, 136, 127), c2 = Color3.fromRGB(109,  76,  65), hat = "coconut" },
	-- Mythic
	{ name = "Bombardiro Crocodilo",   rarity = "Mythic",       price = 90000,   income = 900,   scale = 1.4, look = "plane",  c1 = Color3.fromRGB( 85, 139,  87), c2 = Color3.fromRGB(120, 144, 156) },
	{ name = "Bombombini Gusini",      rarity = "Mythic",       price = 160000,  income = 1500,  scale = 1.3, look = "plane",  c1 = Color3.fromRGB(245, 245, 245), c2 = Color3.fromRGB(255, 152,   0), goose = true },
	-- Brainrot God
	{ name = "Cocofanto Elefanto",     rarity = "Brainrot God", price = 500000,  income = 4200,  scale = 1.5, look = "trunk",  c1 = Color3.fromRGB(141, 110,  99), c2 = Color3.fromRGB(189, 189, 189), tusks = true },
	{ name = "Odin Din Din Dun",       rarity = "Brainrot God", price = 750000,  income = 6000,  scale = 1.3, look = "blob",   c1 = Color3.fromRGB(255, 145,  40), c2 = Color3.fromRGB(230,  60,  50), shades = true },
	{ name = "Trenostruzzo Turbo 3000", rarity = "Brainrot God", price = 1100000, income = 8500, scale = 1.6, look = "train",  c1 = Color3.fromRGB( 67, 160,  71), c2 = Color3.fromRGB( 55,  71,  79) },
	{ name = "Tralalero Tralala",      rarity = "Brainrot God", price = 1500000, income = 11000, scale = 1.3, look = "shark",  c1 = Color3.fromRGB( 63, 114, 175), c2 = Color3.fromRGB(236, 239, 241) },
	-- Secret
	{ name = "La Vacca Saturno Saturnita", rarity = "Secret",   price = 4000000, income = 26000, scale = 1.7, look = "cow",    c1 = Color3.fromRGB(250, 250, 250), c2 = Color3.fromRGB(255, 167,  38) },
	{ name = "Tung Tung Tung Sahur",   rarity = "Secret",       price = 6000000, income = 38000, scale = 1.3, look = "log",    c1 = Color3.fromRGB(188, 143,  91), c2 = Color3.fromRGB(121,  85,  61) },
	{ name = "Los Tralaleritos",       rarity = "Secret",       price = 8000000, income = 50000, scale = 1.2, look = "trio",   c1 = Color3.fromRGB(100, 160, 220), c2 = Color3.fromRGB(236, 239, 241) },
	{ name = "La Grande Combinasion",  rarity = "Secret",       price = 12000000, income = 75000, scale = 1.8, look = "combo", c1 = Color3.fromRGB( 62,  50,  60), c2 = Color3.fromRGB(255, 224,  90) },
}

--==============================================================================
-- SERVICES & BASIC SETUP (you don't need to touch anything below this line,
-- but reading it is a great way to learn how the game works!)
--==============================================================================

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")
local Lighting          = game:GetService("Lighting")
local DataStoreService  = game:GetService("DataStoreService")

local rng = Random.new()

local charactersByName = {}
for _, c in ipairs(CHARACTERS) do charactersByName[c.name] = c end

local rarityByName, rarityIndex = {}, {}
for i, r in ipairs(RARITIES) do
	rarityByName[r.name] = r
	rarityIndex[r.name] = i
end

local mutationsByName = {}
for _, m in ipairs(MUTATIONS) do mutationsByName[m.name] = m end

-- One folder holds everything we build, so the Explorer stays tidy.
local mapFolder = Instance.new("Folder")
mapFolder.Name = "BrainrotMap"
mapFolder.Parent = workspace

-- Remove any spawn points the template came with; we place our own.
for _, obj in ipairs(workspace:GetChildren()) do
	if obj:IsA("SpawnLocation") then obj:Destroy() end
end

--==============================================================================
-- PART HELPERS -- everything is built from these bright, rounded pieces
--==============================================================================

local function newPart(props)
	local parent = props.Parent
	local part = Instance.new(props.Wedge and "WedgePart" or "Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in pairs(props) do
		if key ~= "Parent" and key ~= "Wedge" then part[key] = value end
	end
	if parent then part.Parent = parent end
	return part
end

-- A rounded "ball" that can be stretched into any egg/pill shape.
local function ball(size, color, props)
	props = props or {}
	props.Size = size
	props.Color = color
	local part = newPart(props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- A cylinder lying along the given axis ("X", "Y" or "Z").
-- diameter/length describe the shape; Roblox cylinders lie along X natively.
local function tube(axis, length, diameter, color, props)
	props = props or {}
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(length, diameter, diameter)
	props.Color = color
	local part = newPart(props)
	if axis == "Y" then
		part.CFrame = part.CFrame * CFrame.Angles(0, 0, math.rad(90))
	elseif axis == "Z" then
		part.CFrame = part.CFrame * CFrame.Angles(0, math.rad(90), 0)
	end
	return part
end

--==============================================================================
-- CARTOONY LABELS -- rounded bubbles with thick outlines
--==============================================================================

local function styleText(label, textSize, color)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextSize = textSize
	label.TextColor3 = color or Color3.new(1, 1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(40, 30, 50)
	stroke.Thickness = 2
	stroke.Parent = label
	return label
end

-- A floating rounded bubble with up to two lines of text.
local function makeBubble(parent, offsetY, line1, line2, accentColor, maxDistance)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 250, 0, line2 and 62 or 40)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = maxDistance or 110

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(35, 28, 48)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = accentColor or Color3.new(1, 1, 1)
	stroke.Thickness = 3
	stroke.Parent = frame
	frame.Parent = gui

	local top = Instance.new("TextLabel")
	top.Size = UDim2.new(1, -12, line2 and 0.55 or 1, 0)
	top.Position = UDim2.new(0, 6, 0, 0)
	top.Text = line1
	styleText(top, 22, accentColor)
	top.Parent = frame

	local bottom = nil
	if line2 then
		bottom = Instance.new("TextLabel")
		bottom.Size = UDim2.new(1, -12, 0.45, 0)
		bottom.Position = UDim2.new(0, 6, 0.55, 0)
		bottom.Text = line2
		styleText(bottom, 16, Color3.fromRGB(190, 255, 190))
		bottom.Parent = frame
	end

	gui.Parent = parent
	return gui, top, bottom
end

-- A plain floating text label (no bubble), for signs and small tags.
local function makeLabel(parent, offsetY, text, textColor, textSize, maxDistance)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 320, 0, 50)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = maxDistance or 160
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Text = text
	styleText(label, textSize or 24, textColor)
	label.Parent = gui
	gui.Parent = parent
	return gui, label
end

local function formatCash(n)
	if n >= 1e9 then return string.format("$%.1fB", n / 1e9) end
	if n >= 1e6 then return string.format("$%.1fM", n / 1e6) end
	if n >= 1e3 then return string.format("$%.1fK", n / 1e3) end
	return "$" .. tostring(math.floor(n))
end

-- Floating "+$X" popup that rises out of a position and fades.
local function cashPopup(position, text, color)
	local anchor = newPart({
		Name = "Popup", Size = Vector3.new(0.4, 0.4, 0.4), Transparency = 1,
		CanCollide = false, CanQuery = false,
		Position = position, Parent = mapFolder,
	})
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 180, 0, 36)
	gui.StudsOffset = Vector3.new(0, 0, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Text = text
	styleText(label, 26, color or Color3.fromRGB(140, 255, 140))
	label.Parent = gui
	gui.Parent = anchor
	task.spawn(function()
		for step = 1, 20 do
			task.wait(0.05)
			gui.StudsOffset = Vector3.new(0, step * 0.22, 0)
			label.TextTransparency = step / 20
		end
		anchor:Destroy()
	end)
	Debris:AddItem(anchor, 3)
end

-- Big announcement banner on everyone's screen. Banners stack so they
-- never overprint each other.
local function announce(text, color)
	for _, player in ipairs(Players:GetPlayers()) do
		local gui = player:FindFirstChild("PlayerGui")
		if gui then
			local existing = 0
			for _, child in ipairs(gui:GetChildren()) do
				if child.Name == "BrainrotAnnouncement" then existing += 1 end
			end
			local screen = Instance.new("ScreenGui")
			screen.Name = "BrainrotAnnouncement"
			screen.ResetOnSpawn = false
			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(0.7, 0, 0, 40)
			label.Position = UDim2.new(0.15, 0, 0.1, existing * 46)
			label.BackgroundColor3 = Color3.fromRGB(35, 28, 48)
			label.BackgroundTransparency = 0.2
			label.Text = text
			styleText(label, 26, color)
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 14)
			corner.Parent = label
			local stroke = Instance.new("UIStroke")
			stroke.Color = color or Color3.new(1, 1, 1)
			stroke.Thickness = 2
			stroke.Parent = label
			label.Parent = screen
			screen.Parent = gui
			Debris:AddItem(screen, 4)
		end
	end
end

--==============================================================================
-- BRIGHT CARTOON LIGHTING -- sunny noon, punchy colors, soft bloom
--==============================================================================

Lighting.ClockTime = 13.5
Lighting.Brightness = 3
Lighting.Ambient = Color3.fromRGB(150, 150, 160)
Lighting.OutdoorAmbient = Color3.fromRGB(160, 160, 170)
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 0.5

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.6
bloom.Size = 28
bloom.Threshold = 1.1
bloom.Parent = Lighting

local colorPunch = Instance.new("ColorCorrectionEffect")
colorPunch.Name = "CartoonPunch"
colorPunch.Saturation = 0.25
colorPunch.Contrast = 0.06
colorPunch.Brightness = 0.02
colorPunch.Parent = Lighting

local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.25
atmosphere.Offset = 0.6
atmosphere.Color = Color3.fromRGB(220, 235, 255)
atmosphere.Decay = Color3.fromRGB(255, 200, 150)
atmosphere.Glare = 0.2
atmosphere.Haze = 1
atmosphere.Parent = Lighting

--==============================================================================
-- MAP: candy-colored island, red carpet conveyor, cave, decorations
--==============================================================================

local CONVEYOR_LENGTH = 220
local CONVEYOR_START  = Vector3.new(0, 0, -CONVEYOR_LENGTH / 2)
local CONVEYOR_END    = Vector3.new(0, 0,  CONVEYOR_LENGTH / 2)
local BELT_TOP_Y      = 2

-- Bright pastel grass with a rounded rim so the island looks like a big
-- cartoon cookie instead of a flat slab.
newPart({
	Name = "Ground", Size = Vector3.new(340, 2, 300),
	Position = Vector3.new(0, 0, 0),
	Color = Color3.fromRGB(124, 218, 123), Material = Enum.Material.Grass,
	Parent = mapFolder,
})
newPart({
	Name = "GroundRim", Size = Vector3.new(352, 1.2, 312),
	Position = Vector3.new(0, -0.6, 0),
	Color = Color3.fromRGB(255, 214, 140),
	Parent = mapFolder,
})

-- THE RED CARPET (this is what the conveyor is in the real game).
newPart({
	Name = "CarpetBase", Size = Vector3.new(16, 1, CONVEYOR_LENGTH + 24),
	Position = Vector3.new(0, 1.4, 0),
	Color = Color3.fromRGB(255, 215, 120),
	Parent = mapFolder,
})
newPart({
	Name = "RedCarpet", Size = Vector3.new(12, 1.02, CONVEYOR_LENGTH + 20),
	Position = Vector3.new(0, 1.49, 0),
	Color = Color3.fromRGB(220, 60, 70), Material = Enum.Material.Fabric,
	Parent = mapFolder,
})

-- Golden stanchion posts with a rounded top along both carpet edges.
for z = -CONVEYOR_LENGTH / 2, CONVEYOR_LENGTH / 2, 22 do
	for _, x in ipairs({ -9, 9 }) do
		tube("Y", 3.4, 0.7, Color3.fromRGB(255, 200, 80), {
			Name = "Stanchion", Position = Vector3.new(x, 3.2, z),
			Material = Enum.Material.Metal, Parent = mapFolder,
		})
		ball(Vector3.new(1.1, 1.1, 1.1), Color3.fromRGB(255, 220, 110), {
			Name = "StanchionTop", Position = Vector3.new(x, 5.2, z),
			Material = Enum.Material.Metal, Parent = mapFolder,
		})
	end
end

-- The cave the brainrots march out of: a big rounded rock arch over the
-- carpet's start, with a dark doorway.
do
	local caveZ = -CONVEYOR_LENGTH / 2 - 8
	ball(Vector3.new(46, 34, 26), Color3.fromRGB(120, 110, 140), {
		Name = "CaveRock", Position = Vector3.new(0, 12, caveZ - 6),
		Parent = mapFolder,
	})
	ball(Vector3.new(30, 22, 20), Color3.fromRGB(100, 92, 120), {
		Name = "CaveRock2", Position = Vector3.new(-20, 8, caveZ - 2),
		Parent = mapFolder,
	})
	ball(Vector3.new(26, 18, 18), Color3.fromRGB(100, 92, 120), {
		Name = "CaveRock3", Position = Vector3.new(18, 7, caveZ - 2),
		Parent = mapFolder,
	})
	newPart({
		Name = "CaveMouth", Size = Vector3.new(14, 12, 1),
		Position = Vector3.new(0, 7, caveZ + 6.2),
		Color = Color3.fromRGB(25, 20, 35),
		Parent = mapFolder,
	})
	local caveSign = newPart({
		Name = "CaveSign", Size = Vector3.new(0.5, 0.5, 0.5), Transparency = 1,
		CanCollide = false, CanQuery = false,
		Position = Vector3.new(0, 26, caveZ),
		Parent = mapFolder,
	})
	makeLabel(caveSign, 0, "BRAINROTS INCOMING!", Color3.fromRGB(255, 240, 120), 30, 260)
end

-- Cartoon trees: brown trunk + a cluster of bright green balls.
local function makeTree(position, size)
	tube("Y", 6 * size, 2 * size, Color3.fromRGB(161, 110,  75), {
		Name = "Trunk", Position = position + Vector3.new(0, 3 * size, 0),
		Parent = mapFolder,
	})
	local leafColors = {
		Color3.fromRGB(106, 199, 106), Color3.fromRGB(84, 186, 108), Color3.fromRGB(130, 210, 100),
	}
	for i, offset in ipairs({
		Vector3.new(0, 8, 0), Vector3.new(2.6, 6.6, 1), Vector3.new(-2.6, 6.6, -0.6),
		Vector3.new(0.6, 6.9, -2.4), Vector3.new(-0.8, 7, 2.4),
	}) do
		ball(Vector3.new(6, 5.4, 6) * size, leafColors[(i % #leafColors) + 1], {
			Name = "Leaves", Position = position + offset * size,
			Parent = mapFolder,
		})
	end
end

for _, spot in ipairs({
	{ Vector3.new(-150, 1, -120), 1.4 }, { Vector3.new(155, 1, -90), 1.1 },
	{ Vector3.new(-155, 1, 60), 1.2 },  { Vector3.new(150, 1, 110), 1.5 },
	{ Vector3.new(-120, 1, 135), 1.0 }, { Vector3.new(120, 1, -140), 1.2 },
}) do
	makeTree(spot[1], spot[2])
end

-- Puffy clouds floating overhead.
for _, spot in ipairs({
	Vector3.new(-90, 55, -60), Vector3.new(70, 62, 30), Vector3.new(10, 58, -130),
	Vector3.new(120, 66, 120), Vector3.new(-130, 60, 100),
}) do
	for i, offset in ipairs({
		Vector3.new(0, 0, 0), Vector3.new(7, -1, 2), Vector3.new(-7, -1, -1), Vector3.new(2, 2.5, -2),
	}) do
		ball(Vector3.new(14 - i, 8 - i * 0.5, 12 - i), Color3.fromRGB(255, 255, 255), {
			Name = "Cloud", Position = spot + offset,
			CanCollide = false, Parent = mapFolder,
		})
	end
end

-- Spawn plaza: a big rounded disc with a welcome sign and tutorial tips.
local spawnCenter = Vector3.new(0, 1.6, CONVEYOR_LENGTH / 2 + 21)
tube("Y", 1.2, 34, Color3.fromRGB(255, 244, 200), {
	Name = "SpawnPlaza", Position = spawnCenter, Parent = mapFolder,
})
local spawnPad = Instance.new("SpawnLocation")
spawnPad.Size = Vector3.new(12, 1, 12)
spawnPad.Position = spawnCenter + Vector3.new(0, 0.7, 0)
spawnPad.Anchored = true
spawnPad.Neutral = true
spawnPad.Color = Color3.fromRGB(255, 255, 255)
spawnPad.Material = Enum.Material.SmoothPlastic
spawnPad.TopSurface = Enum.SurfaceType.Smooth
spawnPad.Duration = 0
spawnPad.Parent = mapFolder

local welcomeSign = newPart({
	Name = "WelcomeSign", Size = Vector3.new(0.5, 0.5, 0.5), Transparency = 1,
	CanCollide = false, CanQuery = false,
	Position = spawnCenter + Vector3.new(0, 12, 0),
	Parent = mapFolder,
})
makeLabel(welcomeSign, 1.6, "SNATCH A BRAINROT", Color3.fromRGB(255, 110, 180), 34, 300)
makeLabel(welcomeSign, -1, "Tap E on the carpet to BUY - stand in YOUR base to collect!", Color3.fromRGB(255, 244, 200), 18, 300)

-- Tutorial signs along the way.
local function tipSign(position, text, color)
	local post = tube("Y", 5, 0.8, Color3.fromRGB(255, 200, 80), {
		Name = "TipPost", Position = position + Vector3.new(0, 2.5, 0), Parent = mapFolder,
	})
	makeLabel(post, 4, text, color or Color3.fromRGB(255, 255, 255), 20, 120)
end

tipSign(Vector3.new(-10, 1, CONVEYOR_LENGTH / 2 + 6), "This is the carpet! Tap E on a brainrot to buy it", Color3.fromRGB(140, 255, 160))
tipSign(Vector3.new(12, 1, 40), "Hold E on someone ELSE's brainrot to STEAL it...", Color3.fromRGB(255, 160, 140))
tipSign(Vector3.new(-12, 1, -40), "...then RUN HOME to keep it! Slap thieves with your bat!", Color3.fromRGB(255, 220, 120))

--==============================================================================
-- BASES -- rounded pastel islands, one per player
--==============================================================================

local BASE_W, BASE_D = 46, 34
local bases = {}

local BASE_COLORS = {
	Color3.fromRGB(255, 138, 128), Color3.fromRGB(100, 181, 246),
	Color3.fromRGB(129, 222, 132), Color3.fromRGB(255, 213,  79),
	Color3.fromRGB(206, 147, 216), Color3.fromRGB( 77, 208, 225),
	Color3.fromRGB(255, 171, 209), Color3.fromRGB(220, 231, 117),
}

local function buildBase(index, centerPos)
	local base = {
		index = index, owner = nil, center = centerPos,
		locked = false, lockReadyAt = 0, lockGeneration = 0, slots = {},
	}

	local folder = Instance.new("Folder")
	folder.Name = "Base" .. index
	folder.Parent = mapFolder
	base.folder = folder

	-- Rounded floor: a pastel slab with a white "frosting" border.
	newPart({
		Name = "FloorTrim", Size = Vector3.new(BASE_W + 3, 0.9, BASE_D + 3),
		Position = centerPos + Vector3.new(0, -0.1, 0),
		Color = Color3.fromRGB(255, 255, 255),
		Parent = folder,
	})
	base.floor = newPart({
		Name = "Floor", Size = Vector3.new(BASE_W, 1, BASE_D),
		Position = centerPos,
		Color = BASE_COLORS[index],
		Parent = folder,
	})

	local sign = newPart({
		Name = "Sign", Size = Vector3.new(0.5, 0.5, 0.5), Transparency = 1,
		CanCollide = false, CanQuery = false,
		Position = centerPos + Vector3.new(0, 15, 0),
		Parent = folder,
	})
	local _, signLabel = makeLabel(sign, 1.2, "EMPTY BASE - JOIN TO CLAIM", Color3.new(1, 1, 1), 26, 260)
	local _, incomeLabel = makeLabel(sign, -1, "", Color3.fromRGB(190, 255, 190), 18, 200)
	base.signLabel = signLabel
	base.incomeLabel = incomeLabel

	-- Round slot pads arranged in two rows, spaced to fit the floor
	-- whatever SLOTS_PER_BASE is set to.
	local cols = math.ceil(SLOTS_PER_BASE / 2)
	local usable = BASE_W - 10
	local spacing = cols > 1 and usable / (cols - 1) or 0
	local slotIndex = 0
	for row = 0, 1 do
		for col = 0, cols - 1 do
			slotIndex += 1
			if slotIndex > SLOTS_PER_BASE then break end
			local pad = tube("Y", 0.45, 6.5, Color3.fromRGB(255, 255, 255), {
				Name = "Slot" .. slotIndex,
				Position = centerPos + Vector3.new(-usable / 2 + col * spacing, 0.73, -6 + row * 12),
				Parent = folder,
			})
			local ring = tube("Y", 0.4, 7.3, BASE_COLORS[index], {
				Name = "SlotRing",
				Position = pad.Position + Vector3.new(0, -0.08, 0),
				Parent = folder,
			})
			local _, moneyLabel = makeLabel(pad, 1.4, "", Color3.fromRGB(140, 255, 140), 16, 70)
			base.slots[slotIndex] = { pad = pad, ring = ring, moneyLabel = moneyLabel, brainrot = nil }
		end
	end

	local towardConveyor = (centerPos.X > 0) and -1 or 1

	-- The lock button: a chunky red mushroom button, flush on the floor.
	local buttonBasePos = centerPos + Vector3.new(towardConveyor * (BASE_W / 2 - 4), 0.5, BASE_D / 2 - 4)
	tube("Y", 1.2, 4.4, Color3.fromRGB(255, 255, 255), {
		Name = "LockButtonBase", Position = buttonBasePos + Vector3.new(0, 0.6, 0), Parent = folder,
	})
	local button = ball(Vector3.new(3.4, 2.6, 3.4), Color3.fromRGB(255, 82, 82), {
		Name = "LockButton", Material = Enum.Material.Neon,
		Position = buttonBasePos + Vector3.new(0, 2.1, 0),
		Parent = folder,
	})
	makeLabel(button, 2.6, "BASE LOCK", Color3.fromRGB(255, 130, 130), 18, 60)
	local lockPrompt = Instance.new("ProximityPrompt")
	lockPrompt.ActionText = "Lock Base"
	lockPrompt.ObjectText = "Shield (" .. LOCK_DURATION .. "s)"
	lockPrompt.HoldDuration = 0
	lockPrompt.MaxActivationDistance = 8
	lockPrompt.RequiresLineOfSight = false
	lockPrompt.Parent = button
	base.lockPrompt = lockPrompt

	-- THE FUSION ALTAR (our unique twist!): a glowing purple pedestal.
	-- Own 3 copies of the SAME brainrot -> fuse them into a random one
	-- from the next rarity tier up.
	local altarPos = centerPos + Vector3.new(towardConveyor * (BASE_W / 2 - 4), 0.5, -(BASE_D / 2 - 4))
	tube("Y", 1.2, 4.4, Color3.fromRGB(255, 255, 255), {
		Name = "AltarBase", Position = altarPos + Vector3.new(0, 0.6, 0), Parent = folder,
	})
	local altar = ball(Vector3.new(2.8, 3.4, 2.8), Color3.fromRGB(186, 104, 255), {
		Name = "FusionAltar", Material = Enum.Material.Neon,
		Position = altarPos + Vector3.new(0, 2.6, 0),
		Parent = folder,
	})
	makeLabel(altar, 2.8, "FUSION ALTAR", Color3.fromRGB(216, 160, 255), 18, 60)
	makeLabel(altar, 1.8, "3 identical = 1 rarer!", Color3.fromRGB(230, 210, 255), 13, 40)
	local fusePrompt = Instance.new("ProximityPrompt")
	fusePrompt.ActionText = "Fuse"
	fusePrompt.ObjectText = "3 identical brainrots"
	fusePrompt.HoldDuration = 0.5
	fusePrompt.MaxActivationDistance = 8
	fusePrompt.RequiresLineOfSight = false
	fusePrompt.Parent = altar
	base.fusePrompt = fusePrompt
	base.altar = altar

	-- Shield dome, invisible until the base is locked.
	local shield = ball(Vector3.new(BASE_W + 8, 30, BASE_D + 8), Color3.fromRGB(90, 200, 255), {
		Name = "Shield", Material = Enum.Material.ForceField,
		Position = centerPos + Vector3.new(0, 2, 0),
		Transparency = 1, CanCollide = false, CanQuery = false,
		Parent = folder,
	})
	base.shield = shield

	return base
end

-- Four bases per side, facing the carpet.
do
	local index = 0
	for side = -1, 1, 2 do
		for i = 0, 3 do
			index += 1
			local x = side * (BASE_W / 2 + 40)
			local z = -85 + i * 56
			bases[index] = buildBase(index, Vector3.new(x, 0.6, z))
		end
	end
end

local function isPlayerInBase(player, base)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	local offset = hrp.Position - base.center
	return math.abs(offset.X) < BASE_W / 2 and math.abs(offset.Z) < BASE_D / 2
end

--==============================================================================
-- BRAINROT CHARACTER MODELS
-- Each character has a distinctive rounded cartoon body. Everything is
-- built facing -Z, standing on y = 0, at unit scale, then scaled up.
-- Parts named "Tint" recolor with Gold/Diamond/Rainbow mutations.
--==============================================================================

local function charPart(model, part)
	part.CanCollide = false
	part.CanQuery = true
	part.Parent = model
	return part
end

local function tinted(model, part)
	part.Name = "Tint"
	return charPart(model, part)
end

-- Googly eyes: white balls with black pupils, stuck on the front (-Z).
local function addEyes(model, centerY, centerZ, gap, size)
	size = size or 0.7
	for _, x in ipairs({ -gap, gap }) do
		charPart(model, ball(Vector3.new(size, size, size * 0.55), Color3.new(1, 1, 1), {
			Name = "Eye", Position = Vector3.new(x, centerY, centerZ),
		}))
		charPart(model, ball(Vector3.new(size * 0.45, size * 0.45, size * 0.3), Color3.new(0, 0, 0), {
			Name = "Pupil", Position = Vector3.new(x, centerY, centerZ - size * 0.18),
		}))
	end
end

local function addSmile(model, centerY, centerZ, width)
	charPart(model, ball(Vector3.new(width, 0.25, 0.3), Color3.fromRGB(60, 30, 40), {
		Name = "Smile", Position = Vector3.new(0, centerY, centerZ),
	}))
end

local function addFeet(model, gap, color, big)
	local size = big and Vector3.new(1.6, 0.7, 2.2) or Vector3.new(0.9, 0.55, 1.2)
	for _, x in ipairs({ -gap, gap }) do
		charPart(model, ball(size, color, {
			Name = "Foot", Position = Vector3.new(x, size.Y / 2, 0),
		}))
	end
end

-- Each builder returns the model's height (used for name tags & carrying).
local LOOKS = {}

LOOKS.blob = function(model, c)
	tinted(model, ball(Vector3.new(3, 3.4, 2.6), c.c1, { Position = Vector3.new(0, 2.2, 0) }))
	addEyes(model, 3, -1.15, 0.6)
	addSmile(model, 2.3, -1.25, 1)
	addFeet(model, 0.8, c.c1, c.bigfeet)
	if c.hat == "pizza" then
		charPart(model, tube("Y", 0.35, 2.6, Color3.fromRGB(255, 190, 90), { Position = Vector3.new(0, 4.1, 0) }))
		charPart(model, ball(Vector3.new(0.7, 0.25, 0.7), Color3.fromRGB(200, 60, 50), { Position = Vector3.new(0.5, 4.3, 0.3) }))
		charPart(model, ball(Vector3.new(0.7, 0.25, 0.7), Color3.fromRGB(200, 60, 50), { Position = Vector3.new(-0.5, 4.3, -0.3) }))
	elseif c.hat == "petals" then
		for i = 0, 5 do
			local angle = i * math.pi / 3
			charPart(model, ball(Vector3.new(1.1, 0.5, 1.1), c.c2, {
				Position = Vector3.new(math.cos(angle) * 1.5, 4 + math.sin(angle * 2) * 0.1, math.sin(angle) * 1.1),
			}))
		end
	elseif c.hat == "leaves" then
		for _, offset in ipairs({ Vector3.new(0, 4.3, 0), Vector3.new(0.9, 4, 0.4), Vector3.new(-0.9, 4, -0.2) }) do
			charPart(model, ball(Vector3.new(1.6, 1.1, 1.6), c.c2, { Position = offset }))
		end
	elseif c.hat == "coconut" then
		charPart(model, ball(Vector3.new(2.4, 1.2, 2.4), Color3.fromRGB(90, 62, 50), { Position = Vector3.new(0, 4.1, 0.2) }))
	end
	if c.shades then
		charPart(model, newPart({ Size = Vector3.new(2.1, 0.5, 0.3), Color = Color3.fromRGB(20, 20, 25),
			Position = Vector3.new(0, 3.05, -1.25) }))
	end
	return 4.6
end

LOOKS.cheese = function(model, c)
	local wedge = newPart({ Wedge = true, Size = Vector3.new(2.8, 2.6, 3.2), Color = c.c1,
		CFrame = CFrame.new(0, 1.9, 0) * CFrame.Angles(0, math.pi, 0) })
	wedge.Name = "Tint"
	charPart(model, wedge)
	for _, hole in ipairs({ Vector3.new(0.8, 1.5, -1), Vector3.new(-0.7, 1.1, -0.4), Vector3.new(0.2, 2.2, 0.6) }) do
		charPart(model, ball(Vector3.new(0.55, 0.55, 0.55), Color3.fromRGB(230, 170, 40), { Position = hole }))
	end
	charPart(model, ball(Vector3.new(0.8, 0.8, 0.3), c.c2, { Name = "Ear", Position = Vector3.new(-0.9, 3.4, 0.6) }))
	charPart(model, ball(Vector3.new(0.8, 0.8, 0.3), c.c2, { Name = "Ear", Position = Vector3.new(0.9, 3.4, 0.6) }))
	addEyes(model, 1.9, -1.45, 0.55, 0.6)
	addFeet(model, 0.8, c.c2)
	return 3.8
end

LOOKS.piggy = function(model, c)
	tinted(model, ball(Vector3.new(3.6, 2.6, 4.4), c.c1, { Position = Vector3.new(0, 2, 0) }))
	charPart(model, ball(Vector3.new(1.1, 0.9, 0.5), c.c2, { Name = "Snout", Position = Vector3.new(0, 2.1, -2.3) }))
	charPart(model, ball(Vector3.new(0.7, 0.9, 0.4), c.c1, { Name = "Ear", Position = Vector3.new(-1.2, 3.4, -0.8) }))
	charPart(model, ball(Vector3.new(0.7, 0.9, 0.4), c.c1, { Name = "Ear", Position = Vector3.new(1.2, 3.4, -0.8) }))
	addEyes(model, 2.9, -1.9, 0.75, 0.6)
	for _, x in ipairs({ -1.2, 1.2 }) do
		for _, z in ipairs({ -1.3, 1.3 }) do
			charPart(model, tube("Y", 0.9, 0.8, c.c2, { Name = "Leg", Position = Vector3.new(x, 0.45, z) }))
		end
	end
	return 3.7
end

LOOKS.shrimp = function(model, c)
	tinted(model, ball(Vector3.new(2.6, 2.6, 3.6), c.c1, { Position = Vector3.new(0, 2.2, 0.2) }))
	-- curled shrimp tail rising behind
	for i = 1, 3 do
		charPart(model, ball(Vector3.new(1.8 - i * 0.35, 1.4 - i * 0.25, 1.4), c.c2, {
			Name = "TailSeg", Position = Vector3.new(0, 2.4 + i * 0.75, 1.7 + i * 0.55),
		}))
	end
	addEyes(model, 3, -1.5, 0.6)
	addSmile(model, 2.3, -1.6, 0.9)
	addFeet(model, 0.7, c.c2)
	return 5

end

LOOKS.tire = function(model, c)
	charPart(model, tube("Z", 1.6, 3.4, c.c1, { Name = "TireBody", Position = Vector3.new(0, 2.2, 0), Material = Enum.Material.Rubber }))
	charPart(model, tube("Z", 1.7, 1.4, Color3.fromRGB(120, 120, 120), { Name = "Hub", Position = Vector3.new(0, 2.2, 0) }))
	tinted(model, ball(Vector3.new(2, 1.8, 1.8), c.c2, { Position = Vector3.new(0, 4.6, 0) }))
	addEyes(model, 4.7, -0.85, 0.5, 0.6)
	addSmile(model, 4.2, -0.9, 0.8)
	for _, x in ipairs({ -0.7, 0.7 }) do
		charPart(model, tube("Y", 1, 0.7, Color3.fromRGB(255, 220, 180), { Name = "Leg", Position = Vector3.new(x, 0.5, 0) }))
	end
	return 5.5
end

LOOKS.banana = function(model, c)
	-- a leaning banana: three stacked tilted segments
	local tilt = CFrame.Angles(0, 0, math.rad(18))
	tinted(model, ball(Vector3.new(1.9, 3.6, 2), c.c1, { CFrame = CFrame.new(0, 2.1, 0) * tilt }))
	charPart(model, ball(Vector3.new(1, 1, 1.1), c.c2, { Name = "Stem", Position = Vector3.new(-0.75, 4.15, 0) }))
	charPart(model, ball(Vector3.new(0.8, 0.7, 0.8), Color3.fromRGB(120, 90, 60), { Name = "Tip", Position = Vector3.new(0.7, 0.6, 0) }))
	addEyes(model, 2.9, -0.95, 0.5, 0.6)
	addSmile(model, 2.2, -1, 0.8)
	addFeet(model, 0.7, c.c2)
	return 4.7
end

LOOKS.cup = function(model, c)
	tinted(model, tube("Y", 2.6, 2.7, c.c1, { Position = Vector3.new(0, 2.1, 0) }))
	charPart(model, tube("Y", 0.5, 2.9, c.c2, { Name = "Foam", Position = Vector3.new(0, 3.6, 0) }))
	charPart(model, ball(Vector3.new(0.5, 0.4, 0.5), Color3.fromRGB(255, 255, 255), { Name = "FoamBlob", Position = Vector3.new(0.4, 3.95, 0.2) }))
	charPart(model, tube("Z", 0.6, 1.5, c.c1, { Name = "HandleTop", Position = Vector3.new(1.8, 2.5, 0) }))
	addEyes(model, 2.6, -1.35, 0.6)
	addSmile(model, 1.9, -1.4, 0.9)
	addFeet(model, 0.7, c.c1)
	if c.katana then
		charPart(model, newPart({ Size = Vector3.new(0.18, 3.4, 0.5), Color = Color3.fromRGB(220, 225, 235),
			Material = Enum.Material.Metal,
			CFrame = CFrame.new(1.1, 2.6, 1.5) * CFrame.Angles(0, 0, math.rad(35)) }))
		charPart(model, newPart({ Size = Vector3.new(0.3, 0.8, 0.3), Color = Color3.fromRGB(60, 45, 45),
			CFrame = CFrame.new(0.15, 1.25, 1.5) * CFrame.Angles(0, 0, math.rad(35)) }))
	end
	if c.tutu then
		charPart(model, tube("Y", 0.5, 4.2, c.c2, { Name = "Tutu", Position = Vector3.new(0, 1.5, 0) }))
	end
	return 4.3
end

LOOKS.trunk = function(model, c)
	tinted(model, ball(Vector3.new(3.4, 3.6, 3), c.c1, { Position = Vector3.new(0, 2.4, 0) }))
	charPart(model, ball(Vector3.new(2.4, 2.2, 2.2), c.c2, { Name = "Head", Position = Vector3.new(0, 4.6, -0.7) }))
	charPart(model, ball(Vector3.new(1.4, 1.6, 0.6), c.c2, { Name = "EarL", Position = Vector3.new(-1.5, 4.8, -0.5) }))
	charPart(model, ball(Vector3.new(1.4, 1.6, 0.6), c.c2, { Name = "EarR", Position = Vector3.new(1.5, 4.8, -0.5) }))
	charPart(model, tube("Y", 1.6, 0.7, c.c2, { Name = "TrunkTop", CFrame = CFrame.new(0, 3.9, -1.9) * CFrame.Angles(math.rad(25), 0, 0) }))
	charPart(model, ball(Vector3.new(0.75, 0.75, 0.75), c.c2, { Name = "TrunkTip", Position = Vector3.new(0, 3.1, -2.25) }))
	if c.tusks then
		for _, x in ipairs({ -0.9, 0.9 }) do
			charPart(model, ball(Vector3.new(0.4, 1.1, 0.4), Color3.fromRGB(255, 250, 235), {
				Name = "Tusk", CFrame = CFrame.new(x, 3.7, -1.6) * CFrame.Angles(math.rad(20), 0, 0) }))
		end
	end
	addEyes(model, 5, -1.65, 0.6, 0.6)
	addFeet(model, 1, c.c1, true)
	return 5.9
end

LOOKS.fridge = function(model, c)
	tinted(model, newPart({ Size = Vector3.new(2.8, 4, 2.4), Color = c.c1, Position = Vector3.new(0, 2.7, 0) }))
	charPart(model, newPart({ Size = Vector3.new(2.85, 0.12, 2.45), Color = Color3.fromRGB(160, 170, 180), Position = Vector3.new(0, 3.3, 0) }))
	charPart(model, newPart({ Size = Vector3.new(0.2, 1.2, 0.25), Color = Color3.fromRGB(160, 170, 180), Position = Vector3.new(-1.1, 4, -1.25) }))
	charPart(model, ball(Vector3.new(1.7, 1.5, 1.6), c.c2, { Name = "CamelHead", Position = Vector3.new(0, 5.5, -0.8) }))
	charPart(model, tube("Y", 1.4, 0.9, c.c2, { Name = "Neck", CFrame = CFrame.new(0, 4.8, -0.4) * CFrame.Angles(math.rad(15), 0, 0) }))
	addEyes(model, 5.7, -1.5, 0.5, 0.55)
	addFeet(model, 1, c.c2)
	return 6.3
end

LOOKS.plane = function(model, c)
	tinted(model, ball(Vector3.new(2.6, 2.4, 5.6), c.c1, { Position = Vector3.new(0, 2.6, 0.2) }))
	-- wings
	for _, x in ipairs({ -1, 1 }) do
		charPart(model, ball(Vector3.new(3.4, 0.35, 1.8), c.c2, { Name = "Wing", Position = Vector3.new(x * 2.6, 2.7, 0.3) }))
	end
	charPart(model, ball(Vector3.new(0.4, 1.4, 1.1), c.c2, { Name = "TailFin", Position = Vector3.new(0, 3.8, 2.6) }))
	if c.goose then
		charPart(model, tube("Y", 1.5, 0.8, c.c1, { Name = "Neck", CFrame = CFrame.new(0, 3.9, -2.3) * CFrame.Angles(math.rad(15), 0, 0) }))
		charPart(model, ball(Vector3.new(1.2, 1.1, 1.2), c.c1, { Name = "Head", Position = Vector3.new(0, 4.8, -2.6) }))
		charPart(model, ball(Vector3.new(0.5, 0.35, 1), c.c2, { Name = "Beak", Position = Vector3.new(0, 4.6, -3.4) }))
		addEyes(model, 5, -3, 0.4, 0.45)
		for _, x in ipairs({ -2.2, 2.2 }) do
			charPart(model, tube("Z", 2, 1, Color3.fromRGB(90, 100, 110), { Name = "Engine", Position = Vector3.new(x, 2, 0.4), Material = Enum.Material.Metal }))
		end
	else
		-- crocodile snout
		charPart(model, ball(Vector3.new(1.6, 1, 2.6), c.c1, { Name = "Snout", Position = Vector3.new(0, 2.6, -3.4) }))
		charPart(model, ball(Vector3.new(1.3, 0.4, 0.8), Color3.fromRGB(255, 255, 255), { Name = "Teeth", Position = Vector3.new(0, 2.2, -3.9) }))
		addEyes(model, 3.6, -2.4, 0.6, 0.6)
	end
	addFeet(model, 1, c.c2)
	return c.goose and 5.4 or 4.6
end

LOOKS.train = function(model, c)
	tinted(model, newPart({ Size = Vector3.new(3, 2.6, 5.4), Color = c.c1, Position = Vector3.new(0, 2.4, 0.2) }))
	charPart(model, tube("Y", 1.4, 1.1, c.c2, { Name = "Chimney", Position = Vector3.new(0, 4.4, -1.6) }))
	charPart(model, ball(Vector3.new(1.3, 0.6, 1.3), Color3.fromRGB(200, 210, 220), { Name = "Smoke", Position = Vector3.new(0, 5.4, -1.6) }))
	for _, z in ipairs({ -1.6, 1.8 }) do
		for _, x in ipairs({ -1.5, 1.5 }) do
			charPart(model, tube("X", 0.5, 1.6, Color3.fromRGB(50, 50, 55), { Name = "Wheel", Position = Vector3.new(x, 0.8, z) }))
		end
	end
	-- ostrich neck + head poking out the top
	charPart(model, tube("Y", 2.6, 0.7, Color3.fromRGB(240, 210, 170), { Name = "Neck", Position = Vector3.new(0, 4.9, 1) }))
	charPart(model, ball(Vector3.new(1.2, 1, 1.2), Color3.fromRGB(240, 210, 170), { Name = "Head", Position = Vector3.new(0, 6.4, 0.8) }))
	charPart(model, ball(Vector3.new(0.4, 0.3, 0.8), Color3.fromRGB(255, 170, 60), { Name = "Beak", Position = Vector3.new(0, 6.3, 0.1) }))
	addEyes(model, 6.6, 0.35, 0.35, 0.4)
	return 7
end

LOOKS.shark = function(model, c)
	tinted(model, ball(Vector3.new(2.6, 2.6, 6), c.c1, { Position = Vector3.new(0, 2.8, 0.2) }))
	charPart(model, ball(Vector3.new(2, 1.6, 2.4), Color3.fromRGB(245, 248, 250), { Name = "Belly", Position = Vector3.new(0, 2.1, -1.4) }))
	local fin = newPart({ Wedge = true, Size = Vector3.new(0.5, 1.8, 2),
		Color = c.c1, CFrame = CFrame.new(0, 4.8, 0.8) * CFrame.Angles(0, math.pi, 0) })
	fin.Name = "Tint"
	charPart(model, fin)
	charPart(model, ball(Vector3.new(0.5, 1.8, 1.2), c.c1, { Name = "Tail", CFrame = CFrame.new(0, 3, 3.3) * CFrame.Angles(math.rad(-20), 0, 0) }))
	charPart(model, ball(Vector3.new(1.4, 0.5, 0.9), Color3.fromRGB(255, 255, 255), { Name = "Teeth", Position = Vector3.new(0, 2.15, -2.7) }))
	addEyes(model, 3.4, -2.5, 0.8, 0.55)
	-- THE THREE SNEAKERS (iconic!)
	for _, x in ipairs({ -1.1, 0, 1.1 }) do
		charPart(model, ball(Vector3.new(1, 0.7, 1.7), c.c2, { Name = "Sneaker", Position = Vector3.new(x, 0.35, x == 0 and 1.4 or -0.5) }))
		charPart(model, ball(Vector3.new(1.05, 0.3, 1.75), Color3.fromRGB(235, 80, 80), { Name = "SneakerSole", Position = Vector3.new(x, 0.15, x == 0 and 1.4 or -0.5) }))
	end
	return 5.7
end

LOOKS.cow = function(model, c)
	tinted(model, ball(Vector3.new(3.6, 3, 5), c.c1, { Position = Vector3.new(0, 2.8, 0.3) }))
	for _, spot in ipairs({ Vector3.new(1.4, 3.4, 1), Vector3.new(-1.3, 2.6, -0.6), Vector3.new(0.6, 2.2, 1.8) }) do
		charPart(model, ball(Vector3.new(1.1, 1.1, 0.5), Color3.fromRGB(40, 40, 45), { Name = "Spot", Position = spot }))
	end
	for _, x in ipairs({ -1.3, 1.3 }) do
		for _, z in ipairs({ -1.2, 1.5 }) do
			charPart(model, tube("Y", 1.3, 0.8, c.c1, { Name = "Leg", Position = Vector3.new(x, 0.65, z) }))
		end
	end
	-- SATURN HEAD: an orange planet with a glowing ring
	charPart(model, ball(Vector3.new(2.6, 2.6, 2.6), c.c2, { Name = "Planet", Position = Vector3.new(0, 5.6, -1.8) }))
	local ring = tube("Y", 0.18, 4.6, Color3.fromRGB(255, 220, 130), {
		Name = "PlanetRing", Material = Enum.Material.Neon,
	})
	ring.CFrame = CFrame.new(0, 5.6, -1.8) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(0, 0, math.rad(-70)) * CFrame.Angles(math.rad(12), 0, 0)
	charPart(model, ring)
	addEyes(model, 5.8, -2.9, 0.55, 0.5)
	return 7

end

LOOKS.log = function(model, c)
	tinted(model, tube("Y", 4.4, 2.6, c.c1, { Position = Vector3.new(0, 2.6, 0) }))
	charPart(model, tube("Y", 0.4, 2.7, c.c2, { Name = "LogTop", Position = Vector3.new(0, 4.85, 0) }))
	charPart(model, tube("Y", 0.4, 2.7, c.c2, { Name = "LogBottom", Position = Vector3.new(0, 0.45, 0) }))
	-- flat scared face
	addEyes(model, 3.6, -1.3, 0.55, 0.75)
	charPart(model, ball(Vector3.new(0.7, 1, 0.4), Color3.fromRGB(40, 25, 25), { Name = "Mouth", Position = Vector3.new(0, 2.4, -1.3) }))
	-- his baseball bat
	charPart(model, tube("Y", 3, 0.55, c.c2, { Name = "Bat", CFrame = CFrame.new(2, 2.6, 0) * CFrame.Angles(0, 0, math.rad(-12)) }))
	addFeet(model, 0.8, c.c2)
	return 5.2
end

LOOKS.trio = function(model, c)
	-- three baby sharks huddled together
	for i, x in ipairs({ -1.7, 0, 1.7 }) do
		local z = (i == 2) and -0.8 or 0.6
		tinted(model, ball(Vector3.new(1.6, 1.6, 3.2), c.c1, { Position = Vector3.new(x, 1.7, z) }))
		local fin = newPart({ Wedge = true, Size = Vector3.new(0.35, 1, 1.1),
			Color = c.c1, CFrame = CFrame.new(x, 2.9, z + 0.4) * CFrame.Angles(0, math.pi, 0) })
		fin.Name = "Tint"
		charPart(model, fin)
		addEyes(model, 2.1, z - 1.3, 0.45, 0.4)
		charPart(model, ball(Vector3.new(0.7, 0.45, 1.1), c.c2, { Name = "Sneaker", Position = Vector3.new(x, 0.25, z) }))
	end
	return 3.4
end

LOOKS.combo = function(model, c)
	-- the mega-fusion: log body, shark fin, banana arm, saturn ring, shades
	tinted(model, tube("Y", 4.6, 3, c.c1, { Position = Vector3.new(0, 2.8, 0) }))
	local fin = newPart({ Wedge = true, Size = Vector3.new(0.5, 1.6, 1.8),
		Color = Color3.fromRGB(63, 114, 175), CFrame = CFrame.new(0, 5.8, 0.6) * CFrame.Angles(0, math.pi, 0) })
	charPart(model, fin)
	charPart(model, ball(Vector3.new(1.2, 2.6, 1.3), c.c2, { Name = "BananaArm", CFrame = CFrame.new(-2.1, 3.4, 0) * CFrame.Angles(0, 0, math.rad(-25)) }))
	local ring = tube("Y", 0.16, 5.4, Color3.fromRGB(186, 104, 255), { Name = "Ring", Material = Enum.Material.Neon })
	ring.CFrame = CFrame.new(0, 3.4, 0) * CFrame.Angles(math.rad(14), 0, 0)
	charPart(model, ring)
	charPart(model, newPart({ Size = Vector3.new(2.3, 0.55, 0.3), Color = Color3.fromRGB(15, 15, 20), Position = Vector3.new(0, 4.1, -1.5) }))
	addSmile(model, 3, -1.5, 1.1)
	addFeet(model, 1, c.c2, true)
	return 6.4
end

--==============================================================================
-- MODEL ASSEMBLY -- build the body, scale it, tag it, add the name bubble
--==============================================================================

local function buildBrainrotModel(info)
	local character = info.character
	local rarity = rarityByName[character.rarity]
	local mutation = info.mutation and mutationsByName[info.mutation]

	local model = Instance.new("Model")
	model.Name = info.displayName
	model:SetAttribute("Mutation", info.mutation or "")

	-- Invisible root at the feet: the pivot every PivotTo moves.
	local root = newPart({
		Name = "Root", Size = Vector3.new(0.4, 0.4, 0.4),
		Transparency = 1, CanCollide = false, CanQuery = false,
		Position = Vector3.new(0, 0.2, 0),
	})
	root.Parent = model
	model.PrimaryPart = root

	local builder = LOOKS[character.look] or LOOKS.blob
	local height = builder(model, character)

	-- Mutations recolor the "Tint" parts and add shine.
	if mutation then
		for _, part in ipairs(model:GetChildren()) do
			if part.Name == "Tint" then
				part.Color = mutation.color
				if info.mutation == "Gold" then
					part.Material = Enum.Material.Metal
				elseif info.mutation == "Diamond" then
					part.Material = Enum.Material.Glass
				end
			end
		end
	end

	model:ScaleTo(character.scale)
	height = height * character.scale
	model:SetAttribute("Height", height)

	-- Name bubble: name on top, rarity + income below.
	local nameColor = mutation and mutation.color or rarity.color
	makeBubble(root, height + 2.2,
		info.displayName,
		character.rarity .. "  |  " .. formatCash(info.income) .. "/s",
		nameColor, 110)

	-- Only the truly scary stuff gets a glowing outline (Roblox renders at
	-- most 31 highlights, so we save them for the top tiers).
	if character.rarity == "Secret" or info.mutation == "Rainbow" then
		local glow = Instance.new("Highlight")
		glow.FillTransparency = 1
		glow.OutlineColor = nameColor
		glow.Parent = model
	elseif character.rarity == "Brainrot God" then
		local halo = tube("Y", 0.25, 2.2, Color3.fromRGB(255, 230, 120), {
			Name = "Halo", Material = Enum.Material.Neon, CanCollide = false,
			Position = Vector3.new(0, height + 0.8, 0),
		})
		halo.Parent = model
	end

	return model
end

-- Rainbow brainrots cycle through every color.
local function applyRainbow(model)
	local color = Color3.fromHSV(os.clock() * 0.4 % 1, 0.85, 1)
	for _, part in ipairs(model:GetChildren()) do
		if part.Name == "Tint" then part.Color = color end
	end
end

--==============================================================================
-- BRAINROT "INFO" TABLES
-- Every spawned brainrot is described by an info table:
--   { character, mutation = nil/"Gold"/"Diamond"/"Rainbow",
--     displayName, price, income }
--==============================================================================

local rushActive = false

local function makeInfo(character, mutationName)
	local info = {
		character = character,
		mutation = mutationName,
		displayName = character.name,
		price = character.price,
		income = character.income,
	}
	local mutation = mutationName and mutationsByName[mutationName]
	if mutation then
		info.displayName = mutation.name .. " " .. character.name
		info.price = math.floor(character.price * mutation.priceMult)
		info.income = math.floor(character.income * mutation.incomeMult + 0.5)
	end
	return info
end

local function rollMutation()
	local luck = rushActive and 3 or 1
	local roll = rng:NextNumber()
	-- Check rarest first so Rainbow isn't swallowed by Gold's chance.
	local rainbow = MUTATIONS[3].chance * luck
	local diamond = MUTATIONS[2].chance * luck
	local gold = MUTATIONS[1].chance * luck
	if roll < rainbow then return "Rainbow" end
	if roll < rainbow + diamond then return "Diamond" end
	if roll < rainbow + diamond + gold then return "Gold" end
	return nil
end

--==============================================================================
-- GAME STATE
--==============================================================================

local playerData = {}     -- [player] = { base, carrying, lastSlap, loaded, loadFailed, savedOwned }
local conveyorItems = {}  -- array of { model, t, info, sold }
local carriedItems = {}   -- [model] = { thief, victim, fromBase, fromSlot, info }
local deliveries = {}     -- array of { model, info, base, slotIndex, pos }

local function getCash(player)
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Cash")
end

local function addCash(player, amount)
	local cash = getCash(player)
	if cash then cash.Value += amount end
end

local function updateBrainrotStat(player)
	local data = playerData[player]
	local stats = player:FindFirstChild("leaderstats")
	local stat = stats and stats:FindFirstChild("Brainrots")
	if stat and data and data.base then
		local n = 0
		for _, slot in ipairs(data.base.slots) do
			if slot.brainrot then n += 1 end
		end
		stat.Value = n
	end
end

local function findEmptySlot(base)
	for i, slot in ipairs(base.slots) do
		if not slot.brainrot then return i end
	end
	return nil
end

local function setCarrying(player, model)
	local data = playerData[player]
	if not data then return end
	data.carrying = model
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = model and CARRY_WALKSPEED or 16
	end
end

--==============================================================================
-- PLACING & REMOVING BRAINROTS
--==============================================================================

local setupStealPrompt -- (defined below; declared here so placeBrainrot can use it)

local function placeBrainrot(base, slotIndex, model, info)
	local slot = base.slots[slotIndex]
	slot.brainrot = { model = model, info = info, pile = 0 }
	local pad = slot.pad
	local padTop = pad.Position.Y + pad.Size.X / 2 -- pad is a Y-axis cylinder: height is Size.X
	model:PivotTo(CFrame.new(pad.Position.X, padTop, pad.Position.Z)
		* CFrame.Angles(0, math.rad(rng:NextNumber(0, 360)), 0))
	model.Parent = base.folder
	setupStealPrompt(base, slotIndex, model, info)
	if base.owner then updateBrainrotStat(base.owner) end
end

local function removeFromSlot(base, slotIndex)
	local slot = base.slots[slotIndex]
	local entry = slot.brainrot
	slot.brainrot = nil
	slot.moneyLabel.Text = ""
	-- Whatever cash was piled up here goes straight to the owner, so
	-- getting robbed doesn't also burn your uncollected earnings.
	if entry and entry.pile > 0 and base.owner then
		addCash(base.owner, entry.pile)
		entry.pile = 0
	end
	if base.owner then updateBrainrotStat(base.owner) end
	return entry
end

--==============================================================================
-- STEALING
--==============================================================================

local function dropCarried(thief)
	local data = playerData[thief]
	if not data or not data.carrying then return end
	local model = data.carrying
	local info = carriedItems[model]
	setCarrying(thief, nil)
	carriedItems[model] = nil
	if not info then model:Destroy() return end

	-- Return it to the ORIGINAL victim -- never to a stranger who claimed
	-- the victim's old base after they left.
	if info.victim and info.fromBase.owner == info.victim then
		local slotIndex = info.fromSlot
		if info.fromBase.slots[slotIndex].brainrot then
			slotIndex = findEmptySlot(info.fromBase)
		end
		if slotIndex then
			placeBrainrot(info.fromBase, slotIndex, model, info.info)
			return
		end
		-- Base refilled while it was carried: insurance payout instead of
		-- deleting value from the game.
		addCash(info.victim, info.info.price)
		announce(info.victim.Name .. "'s base was full - insurance paid " .. formatCash(info.info.price) .. "!",
			Color3.fromRGB(190, 255, 190))
	end
	model:Destroy()
end

function setupStealPrompt(base, slotIndex, model, info)
	local old = model.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
	if old then old:Destroy() end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Steal"
	prompt.ObjectText = info.displayName
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Enabled = not base.locked
	prompt.Parent = model.PrimaryPart

	prompt.Triggered:Connect(function(player)
		local data = playerData[player]
		if not data or not data.base then return end
		if player == base.owner then return end        -- can't steal your own
		if base.locked then return end                 -- base is shielded
		if data.carrying then return end               -- one at a time, thief
		if carriedItems[model] then return end         -- someone beat you to it
		local entry = base.slots[slotIndex].brainrot
		if not entry or entry.model ~= model then return end

		removeFromSlot(base, slotIndex)
		prompt:Destroy()
		setCarrying(player, model)
		carriedItems[model] = {
			thief = player, victim = base.owner,
			fromBase = base, fromSlot = slotIndex, info = info,
		}
		announce(player.Name .. " is stealing " .. info.displayName .. "! GET THEM!", Color3.fromRGB(255, 120, 120))
	end)
end

--==============================================================================
-- CONVEYOR: spawning, the pity timer, and buying
--==============================================================================

local lastBigSpawn = os.clock()

local function pickRandomCharacter()
	local pityTriggered = (os.clock() - lastBigSpawn) > PITY_MINUTES * 60
	local pool = {}
	local totalWeight = 0
	for _, r in ipairs(RARITIES) do
		if not pityTriggered or rarityIndex[r.name] >= 4 then
			totalWeight += r.chance
		end
	end
	local roll = rng:NextNumber(0, totalWeight)
	local chosenRarity = pityTriggered and "Legendary" or RARITIES[1].name
	for _, r in ipairs(RARITIES) do
		if not pityTriggered or rarityIndex[r.name] >= 4 then
			roll -= r.chance
			if roll <= 0 then chosenRarity = r.name break end
		end
	end
	for _, c in ipairs(CHARACTERS) do
		if c.rarity == chosenRarity then table.insert(pool, c) end
	end
	return pool[rng:NextInteger(1, #pool)]
end

local function spawnOnConveyor()
	if #conveyorItems >= MAX_ON_CONVEYOR then return end
	local character = pickRandomCharacter()
	if rarityIndex[character.rarity] >= 4 then lastBigSpawn = os.clock() end
	local info = makeInfo(character, rollMutation())
	local model = buildBrainrotModel(info)
	model:PivotTo(CFrame.new(CONVEYOR_START.X, BELT_TOP_Y, CONVEYOR_START.Z) * CFrame.Angles(0, math.pi, 0))
	model.Parent = mapFolder

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Buy"
	prompt.ObjectText = info.displayName .. "  " .. formatCash(info.price)
	prompt.HoldDuration = 0 -- tap E, instant!
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart

	local item = { model = model, t = 0, info = info, sold = false }
	table.insert(conveyorItems, item)

	prompt.Triggered:Connect(function(player)
		if item.sold then return end
		local data = playerData[player]
		if not data or not data.base then return end
		local cash = getCash(player)
		if not cash or cash.Value < info.price then return end
		local slotIndex = findEmptySlot(data.base)
		if not slotIndex then return end

		item.sold = true
		cash.Value -= info.price
		prompt:Destroy()
		for i, it in ipairs(conveyorItems) do
			if it == item then table.remove(conveyorItems, i) break end
		end
		cashPopup(model.PrimaryPart.Position + Vector3.new(0, 3, 0), "-" .. formatCash(info.price), Color3.fromRGB(255, 150, 150))

		-- Reserve the slot, then let the little guy RUN to its new home.
		data.base.slots[slotIndex].brainrot = { model = model, info = info, pile = 0, inTransit = true }
		table.insert(deliveries, {
			model = model, info = info, base = data.base, slotIndex = slotIndex,
			pos = model.PrimaryPart.Position,
		})
	end)

	local rarity = character.rarity
	if rarityIndex[rarity] >= 5 or info.mutation == "Rainbow" then
		announce("A " .. (info.mutation and (info.mutation .. " ") or "") .. rarity .. " "
			.. character.name .. " is on the carpet!!", rarityByName[rarity].color)
	end
end

--==============================================================================
-- THE SLAP BAT
--==============================================================================

local function makeBat()
	local tool = Instance.new("Tool")
	tool.Name = "Slap Bat"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Slap thieves to make them drop stolen brainrots!"

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.8, 4.2, 0.8)
	handle.Color = Color3.fromRGB(255, 170, 90)
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = handle
	handle.Parent = tool

	return tool
end

local function onBatActivated(player)
	local data = playerData[player]
	if not data then return end
	local now = os.clock()
	if now - data.lastSlap < SLAP_COOLDOWN then return end
	data.lastSlap = now

	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	for _, victim in ipairs(Players:GetPlayers()) do
		if victim ~= player then
			local vChar = victim.Character
			local vHrp = vChar and vChar:FindFirstChild("HumanoidRootPart")
			if vHrp and (vHrp.Position - hrp.Position).Magnitude <= SLAP_RANGE then
				local delta = vHrp.Position - hrp.Position
				local pushDirection = delta.Magnitude > 0.05 and delta.Unit or hrp.CFrame.LookVector
				vHrp.AssemblyLinearVelocity = pushDirection * 60 + Vector3.new(0, 35, 0)
				local vData = playerData[victim]
				if vData and vData.carrying then
					dropCarried(victim)
					announce(player.Name .. " slapped the brainrot out of " .. victim.Name .. "'s hands!",
						Color3.fromRGB(255, 220, 100))
				end
			end
		end
	end
end

--==============================================================================
-- BASE LOCK & JOIN SHIELD
--==============================================================================

local function setStealPromptsEnabled(base, enabled)
	for _, slot in ipairs(base.slots) do
		if slot.brainrot and not slot.brainrot.inTransit then
			local prompt = slot.brainrot.model.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
			if prompt then prompt.Enabled = enabled end
		end
	end
end

local function lockBase(base, duration)
	base.lockGeneration += 1
	local generation = base.lockGeneration
	base.locked = true
	base.shield.Transparency = 0.5
	setStealPromptsEnabled(base, false)
	task.delay(duration, function()
		if base.lockGeneration ~= generation then return end -- superseded
		base.locked = false
		base.shield.Transparency = 1
		setStealPromptsEnabled(base, true)
	end)
end

local function resetBaseLock(base)
	base.lockGeneration += 1 -- cancels any pending unlock timers
	base.locked = false
	base.lockReadyAt = 0
	base.shield.Transparency = 1
	base.lockPrompt.Enabled = true
end

local function setupLock(base)
	base.lockPrompt.Triggered:Connect(function(player)
		if player ~= base.owner then return end
		if base.locked then return end
		local now = os.clock()
		if now < base.lockReadyAt then return end
		base.lockReadyAt = now + LOCK_DURATION + LOCK_COOLDOWN
		base.lockPrompt.Enabled = false
		lockBase(base, LOCK_DURATION)
		local generation = base.lockGeneration
		task.delay(LOCK_DURATION + LOCK_COOLDOWN, function()
			if base.lockGeneration ~= generation then return end
			base.lockPrompt.Enabled = true
		end)
	end)
end

for _, base in ipairs(bases) do setupLock(base) end

--==============================================================================
-- THE FUSION ALTAR -- 3 identical brainrots become 1 from the next tier up
--==============================================================================

local function setupFusion(base)
	base.fusePrompt.Triggered:Connect(function(player)
		if player ~= base.owner then return end

		-- Group occupied slots by character name.
		local groups = {}
		for i, slot in ipairs(base.slots) do
			local entry = slot.brainrot
			if entry and not entry.inTransit then
				local name = entry.info.character.name
				groups[name] = groups[name] or {}
				table.insert(groups[name], i)
			end
		end

		-- Find a name with 3+ copies (prefer fusing the cheapest mutations,
		-- so a Rainbow copy is never burned before a plain one).
		for name, slotIndices in pairs(groups) do
			if #slotIndices >= 3 then
				local character = charactersByName[name]
				local nextTier = rarityIndex[character.rarity] + 1
				if nextTier > #RARITIES then continue end -- can't fuse past Secret

				table.sort(slotIndices, function(a, b)
					local ma = base.slots[a].brainrot.info.mutation
					local mb = base.slots[b].brainrot.info.mutation
					local ia = ma and mutationsByName[ma].incomeMult or 1
					local ib = mb and mutationsByName[mb].incomeMult or 1
					return ia < ib
				end)

				for k = 1, 3 do
					local entry = removeFromSlot(base, slotIndices[k])
					if entry then entry.model:Destroy() end
				end

				local pool = {}
				for _, c in ipairs(CHARACTERS) do
					if c.rarity == RARITIES[nextTier].name then table.insert(pool, c) end
				end
				local reward = pool[rng:NextInteger(1, #pool)]
				local info = makeInfo(reward, rollMutation())
				local slotIndex = findEmptySlot(base)
				if slotIndex then
					placeBrainrot(base, slotIndex, buildBrainrotModel(info), info)
				end
				announce(player.Name .. " FUSED 3x " .. name .. " into " .. info.displayName .. "!",
					rarityByName[reward.rarity].color)
				cashPopup(base.altar.Position + Vector3.new(0, 3, 0), "FUSION!", Color3.fromRGB(216, 160, 255))
				return
			end
		end
		cashPopup(base.altar.Position + Vector3.new(0, 3, 0), "Need 3 identical!", Color3.fromRGB(255, 180, 180))
	end)
end

for _, base in ipairs(bases) do setupFusion(base) end

--==============================================================================
-- BRAINROT RUSH -- periodic 2x income + juiced luck event
--==============================================================================

task.spawn(function()
	while true do
		task.wait(RUSH_EVERY)
		rushActive = true
		announce("BRAINROT RUSH! 2x income + juiced luck for " .. RUSH_LENGTH .. "s!", Color3.fromRGB(255, 110, 255))
		colorPunch.Saturation = 0.45
		colorPunch.TintColor = Color3.fromRGB(255, 235, 215)
		task.wait(RUSH_LENGTH)
		rushActive = false
		colorPunch.Saturation = 0.25
		colorPunch.TintColor = Color3.new(1, 1, 1)
		announce("The rush is over... for now.", Color3.fromRGB(200, 180, 255))
	end
end)

--==============================================================================
-- CASH HUD -- a chunky rounded counter at the bottom of everyone's screen
--==============================================================================

local function makeHud(player)
	local gui = player:FindFirstChild("PlayerGui")
	if not gui then return end
	local old = gui:FindFirstChild("BrainrotHud")
	if old then old:Destroy() end

	local screen = Instance.new("ScreenGui")
	screen.Name = "BrainrotHud"
	screen.ResetOnSpawn = false

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 240, 0, 64)
	frame.Position = UDim2.new(0.5, -120, 1, -84)
	frame.BackgroundColor3 = Color3.fromRGB(35, 28, 48)
	frame.BackgroundTransparency = 0.15
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(140, 255, 140)
	stroke.Thickness = 3
	stroke.Parent = frame

	local cashLabel = Instance.new("TextLabel")
	cashLabel.Name = "CashText"
	cashLabel.Size = UDim2.new(1, -16, 0.6, 0)
	cashLabel.Position = UDim2.new(0, 8, 0, 2)
	cashLabel.Text = "$0"
	styleText(cashLabel, 30, Color3.fromRGB(140, 255, 140))
	cashLabel.Parent = frame

	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Name = "IncomeText"
	incomeLabel.Size = UDim2.new(1, -16, 0.34, 0)
	incomeLabel.Position = UDim2.new(0, 8, 0.62, 0)
	incomeLabel.Text = ""
	styleText(incomeLabel, 16, Color3.fromRGB(255, 244, 200))
	incomeLabel.Parent = frame

	frame.Parent = screen
	screen.Parent = gui
end

local function updateHud(player, cashValue, incomePerSec)
	local gui = player:FindFirstChild("PlayerGui")
	local screen = gui and gui:FindFirstChild("BrainrotHud")
	if not screen then return end
	local frame = screen:FindFirstChildOfClass("Frame")
	if not frame then return end
	frame.CashText.Text = formatCash(cashValue)
	frame.IncomeText.Text = "+" .. formatCash(incomePerSec) .. "/s"
		.. (rushActive and "  (RUSH 2x!)" or "")
end

--==============================================================================
-- SAVING (safe to leave on -- if saving isn't available it just skips)
--==============================================================================

local saveStore = nil
if SAVE_PROGRESS then
	pcall(function()
		saveStore = DataStoreService:GetDataStore("SnatchABrainrot_v2")
	end)
end

local alreadySaved = {}

local function savePlayer(player)
	if not saveStore then return end
	if alreadySaved[player] then return end
	local data = playerData[player]
	local cash = getCash(player)
	if not data or not cash then return end
	-- Never write until a load finished cleanly: a failed or unfinished
	-- load must not overwrite the real save with a fresh state.
	if not data.loaded or data.loadFailed then return end

	local cashValue = cash.Value
	local owned = {}
	if data.base then
		for _, slot in ipairs(data.base.slots) do
			local entry = slot.brainrot
			if entry then
				table.insert(owned, { name = entry.info.character.name, mutation = entry.info.mutation })
				cashValue += entry.pile -- uncollected piles come with us
			end
		end
	elseif data.savedOwned then
		-- Joined a full server and never got a base: keep the stored
		-- collection exactly as it was.
		owned = data.savedOwned
	end
	-- A brainrot of ours that a thief is carrying right now is still ours.
	for _, info in pairs(carriedItems) do
		if info.victim == player then
			table.insert(owned, { name = info.info.character.name, mutation = info.info.mutation })
		end
	end

	local ok = pcall(function()
		saveStore:SetAsync("player_" .. player.UserId, { cash = cashValue, owned = owned })
	end)
	if ok then alreadySaved[player] = true end
end

local function loadPlayer(player)
	if not saveStore then return true, nil end
	local result = nil
	local ok = pcall(function()
		result = saveStore:GetAsync("player_" .. player.UserId)
	end)
	return ok, result
end

--==============================================================================
-- PLAYERS JOINING & LEAVING
--==============================================================================

local function restoreOwned(base, ownedList)
	for _, savedEntry in ipairs(ownedList) do
		local name = (type(savedEntry) == "table") and savedEntry.name or savedEntry
		local mutation = (type(savedEntry) == "table") and savedEntry.mutation or nil
		local character = charactersByName[name]
		local slotIndex = findEmptySlot(base)
		if character and slotIndex then
			local info = makeInfo(character, mutation)
			placeBrainrot(base, slotIndex, buildBrainrotModel(info), info)
		end
	end
end

local function giveBase(player, base)
	local data = playerData[player]
	base.owner = player
	data.base = base
	base.signLabel.Text = player.DisplayName .. "'s Base"
	resetBaseLock(base)
	lockBase(base, JOIN_SHIELD) -- free protection while they find their feet
	if data.savedOwned then
		restoreOwned(base, data.savedOwned)
		data.savedOwned = nil
	end
	updateBrainrotStat(player)
end

Players.PlayerAdded:Connect(function(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = STARTING_CASH
	cash.Parent = stats
	local count = Instance.new("IntValue")
	count.Name = "Brainrots"
	count.Value = 0
	count.Parent = stats
	stats.Parent = player

	playerData[player] = {
		base = nil, carrying = nil, lastSlap = 0,
		loaded = false, loadFailed = false, savedOwned = nil,
	}

	-- Hook the character FIRST (before any yielding), so the first life
	-- always gets its bat and death handler.
	local function onCharacter(char)
		local bat = makeBat()
		bat.Activated:Connect(function() onBatActivated(player) end)
		bat.Parent = player:WaitForChild("Backpack")
		char:WaitForChild("Humanoid").Died:Connect(function()
			dropCarried(player) -- dying returns the stolen brainrot
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then task.spawn(onCharacter, player.Character) end

	makeHud(player)

	-- Load the save BEFORE placing anything.
	local data = playerData[player]
	local ok, saved = loadPlayer(player)
	-- The load yielded: the player may have left in the meantime.
	if player.Parent ~= Players or playerData[player] ~= data then return end
	if not ok then
		data.loadFailed = true
		announce(player.Name .. "'s save couldn't load - progress won't overwrite it this visit.", Color3.fromRGB(255, 200, 140))
	else
		data.loaded = true
		if saved then
			cash.Value = saved.cash or STARTING_CASH
			data.savedOwned = saved.owned
		end
	end

	-- Claim a base if one is free (a full server queues you for the next
	-- one that opens up).
	local freeBase = nil
	for _, base in ipairs(bases) do
		if not base.owner then freeBase = base break end
	end
	if freeBase then
		giveBase(player, freeBase)
	else
		announce("All bases are full! " .. player.Name .. " gets the next free one.", Color3.fromRGB(255, 220, 140))
	end
end)

Players.PlayerRemoving:Connect(function(player)
	savePlayer(player)
	dropCarried(player)
	local data = playerData[player]
	if data and data.base then
		local base = data.base
		base.owner = nil
		base.signLabel.Text = "EMPTY BASE - JOIN TO CLAIM"
		base.incomeLabel.Text = ""
		for _, slot in ipairs(base.slots) do
			if slot.brainrot then
				slot.brainrot.model:Destroy()
				slot.brainrot = nil
			end
			slot.moneyLabel.Text = ""
		end
		resetBaseLock(base)
		-- Hand the freed base to anyone who was waiting.
		for _, waiting in ipairs(Players:GetPlayers()) do
			local wData = playerData[waiting]
			if waiting ~= player and wData and not wData.base and wData.loaded then
				giveBase(waiting, base)
				announce(waiting.Name .. " claimed a base!", Color3.fromRGB(190, 255, 190))
				break
			end
		end
	end
	playerData[player] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayer(player)
	end
end)

--==============================================================================
-- MAIN LOOPS
--==============================================================================

-- Conveyor spawner.
task.spawn(function()
	while true do
		task.wait(SPAWN_INTERVAL)
		spawnOnConveyor()
	end
end)

-- Income: every second each brainrot adds cash to its pile. Standing in
-- your own base collects all your piles (with a juicy +$ popup). Everyone
-- also gets a small passive income so new players can always afford
-- something.
task.spawn(function()
	while true do
		task.wait(1)
		local mult = rushActive and 2 or 1
		for _, player in ipairs(Players:GetPlayers()) do
			local data = playerData[player]
			if data then
				addCash(player, PASSIVE_INCOME)
				local incomePerSec = PASSIVE_INCOME
				local base = data.base
				if base then
					local home = isPlayerInBase(player, base)
					local collected = 0
					for _, slot in ipairs(base.slots) do
						local entry = slot.brainrot
						if entry and not entry.inTransit then
							entry.pile += entry.info.income * mult
							incomePerSec += entry.info.income * mult
							if home then
								collected += entry.pile
								entry.pile = 0
							end
							slot.moneyLabel.Text = entry.pile > 0 and formatCash(entry.pile) or ""
							if entry.info.mutation == "Rainbow" then
								applyRainbow(entry.model)
							end
						end
					end
					base.incomeLabel.Text = "earns " .. formatCash(incomePerSec - PASSIVE_INCOME) .. "/s"
					if collected > 0 then
						addCash(player, collected)
						local char = player.Character
						local hrp = char and char:FindFirstChild("HumanoidRootPart")
						if hrp then
							cashPopup(hrp.Position + Vector3.new(0, 4, 0), "+" .. formatCash(collected), Color3.fromRGB(140, 255, 140))
						end
					end
				end
				local cash = getCash(player)
				updateHud(player, cash and cash.Value or 0, incomePerSec)
			end
		end
	end
end)

-- Movement: brainrots waddle down the carpet, bought ones run home,
-- carried ones hover over the thief, steals secure at home base.
local pathVector = CONVEYOR_END - CONVEYOR_START
local pathLength = pathVector.Magnitude

RunService.Heartbeat:Connect(function(dt)
	local clockNow = os.clock()

	-- Waddling down the carpet.
	for i = #conveyorItems, 1, -1 do
		local item = conveyorItems[i]
		item.t += (WALK_SPEED * dt) / pathLength
		if item.t >= 1 then
			table.remove(conveyorItems, i)
			item.model:Destroy()
		else
			local pos = CONVEYOR_START + pathVector * item.t
			local hop = math.abs(math.sin(clockNow * 6 + i)) * 0.5
			local waddle = math.sin(clockNow * 6 + i) * 0.08
			item.model:PivotTo(CFrame.new(pos.X, BELT_TOP_Y + hop, pos.Z)
				* CFrame.Angles(0, math.pi, waddle))
			if item.info.mutation == "Rainbow" then
				applyRainbow(item.model)
			end
		end
	end

	-- Bought brainrots running to their new home.
	for i = #deliveries, 1, -1 do
		local delivery = deliveries[i]
		local base, slotIndex = delivery.base, delivery.slotIndex
		local slot = base.slots[slotIndex]
		local entry = slot.brainrot
		-- The base emptied or changed hands mid-delivery: cancel.
		if not base.owner or not entry or entry.model ~= delivery.model then
			table.remove(deliveries, i)
			delivery.model:Destroy()
			if entry and entry.model == delivery.model then slot.brainrot = nil end
		else
			local padTop = slot.pad.Position.Y + slot.pad.Size.X / 2
			local target = Vector3.new(slot.pad.Position.X, padTop, slot.pad.Position.Z)
			local flat = Vector3.new(target.X - delivery.pos.X, 0, target.Z - delivery.pos.Z)
			local step = DELIVERY_SPEED * dt
			if flat.Magnitude <= step + 0.1 then
				-- Arrived: settle onto the pad and become stealable.
				table.remove(deliveries, i)
				entry.inTransit = nil
				placeBrainrot(base, slotIndex, delivery.model, delivery.info)
			else
				delivery.pos += flat.Unit * step
				local hop = math.abs(math.sin(clockNow * 9)) * 0.8
				delivery.model:PivotTo(CFrame.lookAt(
					Vector3.new(delivery.pos.X, target.Y + hop, delivery.pos.Z),
					Vector3.new(target.X, target.Y + hop, target.Z)))
			end
		end
	end

	-- Carried brainrots hover above the thief.
	for model, info in pairs(carriedItems) do
		local char = info.thief.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local bob = math.sin(clockNow * 5) * 0.3
			model:PivotTo(hrp.CFrame * CFrame.new(0, 2.4 + bob, 0) * CFrame.Angles(0, 0, math.rad(8)))
			if info.info.mutation == "Rainbow" then
				applyRainbow(model)
			end

			-- Home safe? Secure the steal!
			local thiefData = playerData[info.thief]
			local homeBase = thiefData and thiefData.base
			if homeBase and isPlayerInBase(info.thief, homeBase) then
				local slotIndex = findEmptySlot(homeBase)
				if slotIndex then
					carriedItems[model] = nil
					setCarrying(info.thief, nil)
					placeBrainrot(homeBase, slotIndex, model, info.info)
					announce(info.thief.Name .. " got away with " .. info.info.displayName .. "!",
						Color3.fromRGB(120, 255, 120))
				end
			end
		end
	end
end)

print("Snatch a Brainrot v2 loaded! Have fun :)")
