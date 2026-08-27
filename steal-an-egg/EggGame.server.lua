--==============================================================================
-- STEAL AN EGG
-- The complete game in ONE server script: the farm, the conveyor, the eggs,
-- hatching, stealing, base locks, the economy, saving, and the Trail Shop's
-- server side (the TrailShop LocalScript draws the shop; THIS script owns
-- the money and hands out the actual trails).
--
-- HOW TO USE:
--   1. This file lives in ServerScriptService (Rojo puts it there for you,
--      or paste it into a Script there by hand).
--   2. Press Play. The whole farm builds itself.
--
-- THE GAME: a long canyon of zones, just like the real map -- SAFE ZONE,
-- Meadow, Desert, Grove, Snowfields, and the Egg Machine at the far end.
-- Wild eggs appear scattered around the zones (the deeper you go, the
-- rarer they get). Tap E to buy one -- it tumbles to a nest at your base
-- and earns cash every second. Wait out its timer and it HATCHES into a
-- bird worth 3x! Stand in your base to collect your piles. Hold E on
-- someone ELSE's egg to steal it, then run home -- eggs keep their hatch
-- progress, so a nearly-hatched Legendary egg is the juiciest heist in the
-- game. Bonk thieves with your frying pan, lock your base to shield it,
-- and watch for the Golden Goose!
--==============================================================================

--==============================================================================
-- CONFIG -- play with these numbers! Nothing here can break the game.
--==============================================================================

local STARTING_CASH   = 100   -- cash a brand-new player starts with
local PASSIVE_INCOME  = 2     -- free cash per second, so nobody gets stuck at 0
local SPAWN_INTERVAL  = 4     -- seconds between wild eggs appearing
local MAX_WILD_EGGS   = 12    -- max unbought wild eggs out in the field
local EGG_LIFETIME    = 75    -- a wild egg nobody buys rolls away after this
local DELIVERY_SPEED  = 28    -- how fast a bought egg tumbles to your nest
local NESTS_PER_BASE  = 6     -- how many nests one base has
local HATCH_MULT      = 3     -- hatched birds earn this many times the egg's income
local LOCK_DURATION   = 45    -- seconds your base stays locked
local LOCK_COOLDOWN   = 60    -- seconds before you can lock again
local JOIN_SHIELD     = 60    -- free shield seconds when you first join
local BONK_RANGE      = 9     -- how close you must be to bonk someone
local BONK_COOLDOWN   = 1.5   -- seconds between frying-pan bonks
local BASE_WALKSPEED  = 16    -- normal walk speed (trails add on top of this)
local CARRY_WALKSPEED = 11    -- thieves are slowed while carrying an egg
local PITY_MINUTES    = 5     -- guaranteed Legendary+ egg at least this often
local EVENT_EVERY     = 360   -- seconds between events (Goose / Egg Rain alternate)
local RAIN_LENGTH     = 30    -- how long Egg Rain lasts
local AUTOSAVE_EVERY  = 180   -- autosave everyone this often (seconds)
local SAVE_PROGRESS   = true  -- saves cash + eggs + trails (needs API access, see README)

-- Rarity tiers: chance is a weight (bigger = more common). hatchTime is how
-- many seconds an egg of that tier takes to hatch.
local RARITIES = {
	{ name = "Common",    color = Color3.fromRGB(176, 190, 197), chance = 52,  hatchTime = 45   },
	{ name = "Rare",      color = Color3.fromRGB( 66, 165, 245), chance = 26,  hatchTime = 120  },
	{ name = "Epic",      color = Color3.fromRGB(171,  71, 188), chance = 12,  hatchTime = 240  },
	{ name = "Legendary", color = Color3.fromRGB(255, 179,   0), chance = 6.5, hatchTime = 480  },
	{ name = "Mythic",    color = Color3.fromRGB(255,  82,  82), chance = 2.5, hatchTime = 900  },
	{ name = "Secret",    color = Color3.fromRGB(124,  77, 255), chance = 1,   hatchTime = 1500 },
}

-- Mutations: rare shell variants that multiply income. Rolled when one spawns.
local MUTATIONS = {
	{ name = "Shiny",   chance = 0.10, incomeMult = 1.25, priceMult = 2,  color = Color3.fromRGB(255, 236, 190) },
	{ name = "Glowing", chance = 0.04, incomeMult = 1.5,  priceMult = 4,  color = Color3.fromRGB(150, 255, 210) },
	{ name = "Rainbow", chance = 0.01, incomeMult = 10,   priceMult = 20, color = Color3.fromRGB(255,   0, 255) },
}

-- The eggs! Every egg hatches into a bird (its "bird" name) worth 3x.
--   price = cost, income = cash/sec while still an egg,
--   shell/accent = colors, pattern = "plain"/"speckles"/"stripes"/"stars"/"spikes",
--   birdBody = the hatched bird's color, scale = size, sparkle = glitter,
--   material = fancy shell material, hatchTime = override the rarity's timer.
local EGGS = {
	-- Common
	{ name = "Plain Egg",   bird = "Peep",    rarity = "Common", price = 25,  income = 1, pattern = "plain",
	  shell = Color3.fromRGB(245, 238, 220), accent = Color3.fromRGB(210, 180, 140), birdBody = Color3.fromRGB(255, 225, 120) },
	{ name = "Speckle Egg", bird = "Freckle", rarity = "Common", price = 70,  income = 2, pattern = "speckles",
	  shell = Color3.fromRGB(250, 250, 245), accent = Color3.fromRGB(160, 120,  85), birdBody = Color3.fromRGB(222, 184, 135) },
	{ name = "Minty Egg",   bird = "Sprout",  rarity = "Common", price = 120, income = 3, pattern = "speckles",
	  shell = Color3.fromRGB(170, 230, 190), accent = Color3.fromRGB(255, 255, 255), birdBody = Color3.fromRGB(140, 220, 170) },
	-- Rare
	{ name = "Sunny Egg", bird = "Sunbeam", rarity = "Rare", price = 400,  income = 7,  pattern = "stripes",
	  shell = Color3.fromRGB(255, 210,  80), accent = Color3.fromRGB(255, 150,  60), birdBody = Color3.fromRGB(255, 170,  70) },
	{ name = "Ocean Egg", bird = "Splashy", rarity = "Rare", price = 700,  income = 11, pattern = "stripes",
	  shell = Color3.fromRGB( 90, 170, 240), accent = Color3.fromRGB(240, 250, 255), birdBody = Color3.fromRGB(100, 180, 250) },
	{ name = "Rosy Egg",  bird = "Blossom", rarity = "Rare", price = 1000, income = 15, pattern = "speckles",
	  shell = Color3.fromRGB(255, 170, 200), accent = Color3.fromRGB(255, 245, 250), birdBody = Color3.fromRGB(255, 150, 190) },
	-- Epic
	{ name = "Lava Egg",  bird = "Ember", rarity = "Epic", price = 3000, income = 32, pattern = "stripes", sparkle = true,
	  shell = Color3.fromRGB( 62,  44,  44), accent = Color3.fromRGB(255, 120,  40), accentNeon = true, birdBody = Color3.fromRGB(255, 110,  60) },
	{ name = "Leafy Egg", bird = "Fern",  rarity = "Epic", price = 5500, income = 50, pattern = "speckles",
	  shell = Color3.fromRGB(120, 190,  90), accent = Color3.fromRGB( 60, 130,  60), birdBody = Color3.fromRGB(110, 190, 100) },
	-- Legendary
	{ name = "Thunder Egg", bird = "Zappy",  rarity = "Legendary", price = 16000, income = 130, pattern = "stripes", sparkle = true,
	  shell = Color3.fromRGB( 90,  95, 110), accent = Color3.fromRGB(255, 235,  60), accentNeon = true, birdBody = Color3.fromRGB(255, 230,  90) },
	{ name = "Frosty Egg",  bird = "Shiver", rarity = "Legendary", price = 24000, income = 180, pattern = "speckles", material = Enum.Material.Ice,
	  shell = Color3.fromRGB(190, 230, 250), accent = Color3.fromRGB(255, 255, 255), birdBody = Color3.fromRGB(200, 235, 250) },
	{ name = "Galaxy Egg",  bird = "Nova",   rarity = "Legendary", price = 34000, income = 240, pattern = "stars", sparkle = true,
	  shell = Color3.fromRGB( 60,  40, 110), accent = Color3.fromRGB(255, 255, 255), birdBody = Color3.fromRGB(150, 110, 230) },
	-- Mythic
	{ name = "Golden Egg",  bird = "Midas", rarity = "Mythic", price = 100000, income = 650,  pattern = "plain", sparkle = true, material = Enum.Material.Metal,
	  shell = Color3.fromRGB(255, 200,  60), accent = Color3.fromRGB(255, 235, 150), birdBody = Color3.fromRGB(255, 205,  80) },
	{ name = "Diamond Egg", bird = "Prism", rarity = "Mythic", price = 180000, income = 1050, pattern = "plain", sparkle = true, material = Enum.Material.Glass,
	  shell = Color3.fromRGB(180, 235, 250), accent = Color3.fromRGB(255, 255, 255), birdBody = Color3.fromRGB(240, 250, 255) },
	-- Secret
	{ name = "Dragon Egg", bird = "Drako", rarity = "Secret", price = 600000,  income = 3000, pattern = "spikes", material = Enum.Material.Slate,
	  shell = Color3.fromRGB(120,  40,  45), accent = Color3.fromRGB( 70,  20,  25), birdBody = Color3.fromRGB(170,  50,  55) },
	{ name = "Void Egg",   bird = "Umbra", rarity = "Secret", price = 1000000, income = 4600, pattern = "stars", sparkle = true,
	  shell = Color3.fromRGB( 30,  25,  40), accent = Color3.fromRGB(190, 120, 255), accentNeon = true, birdBody = Color3.fromRGB( 80,  60, 110) },
	-- Event-only: the Golden Goose lays this on the belt during her event.
	{ name = "Goose Egg", bird = "The Golden Goose", rarity = "Secret", price = 200000, income = 2500, pattern = "plain",
	  sparkle = true, material = Enum.Material.Metal, scale = 1.6, hatchTime = 300, goose = true, eventOnly = true,
	  shell = Color3.fromRGB(255, 215,  90), accent = Color3.fromRGB(255, 240, 180), birdBody = Color3.fromRGB(250, 245, 235) },
}

-- The trails sold in the Trail Shop. The LocalScript asks the server for
-- this list, so this table is the ONE place the shop is defined.
-- speed = extra WalkSpeed while equipped -- your getaway upgrade!
local TRAILS = {
	{ name = "Grey Trail",   rarity = "Common",    speed = 1.5, price = 100,    color = Color3.fromRGB(190, 190, 195) },
	{ name = "Green Trail",  rarity = "Uncommon",  speed = 2,   price = 5000,   color = Color3.fromRGB( 80, 200,  90) },
	{ name = "Blue Trail",   rarity = "Rare",      speed = 2.5, price = 25000,  color = Color3.fromRGB( 60, 140, 255) },
	{ name = "Purple Trail", rarity = "Epic",      speed = 3,   price = 100000, color = Color3.fromRGB(170,  90, 255) },
	{ name = "Gold Trail",   rarity = "Legendary", speed = 4,   price = 500000, color = Color3.fromRGB(255, 200,  60) },
}

--==============================================================================
-- SERVICES & BASIC SETUP (you don't need to touch anything below this line,
-- but reading it is a great way to learn how the game works!)
--==============================================================================

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local Debris             = game:GetService("Debris")
local Lighting           = game:GetService("Lighting")
local DataStoreService   = game:GetService("DataStoreService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local rng = Random.new()

local eggsByName = {}
for _, e in ipairs(EGGS) do eggsByName[e.name] = e end

local rarityByName, rarityIndex = {}, {}
for i, r in ipairs(RARITIES) do
	rarityByName[r.name] = r
	rarityIndex[r.name] = i
end

local mutationsByName = {}
for _, m in ipairs(MUTATIONS) do mutationsByName[m.name] = m end

local trailsByName = {}
for _, t in ipairs(TRAILS) do trailsByName[t.name] = t end

-- The remotes the TrailShop LocalScript talks to. Made FIRST so the client
-- never has to wait long for them.
local remotes = Instance.new("Folder")
remotes.Name = "EggRemotes"
local getTrailData = Instance.new("RemoteFunction")
getTrailData.Name = "GetTrailData"
getTrailData.Parent = remotes
local trailAction = Instance.new("RemoteEvent")
trailAction.Name = "TrailAction"
trailAction.Parent = remotes
local trailUpdate = Instance.new("RemoteEvent")
trailUpdate.Name = "TrailUpdate"
trailUpdate.Parent = remotes
remotes.Parent = ReplicatedStorage

-- One folder holds everything we build, so the Explorer stays tidy.
-- (Delete "EggMap" from the workspace and the whole built farm is gone.)
local mapFolder = Instance.new("Folder")
mapFolder.Name = "EggMap"
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

	if line2 then
		local bottom = Instance.new("TextLabel")
		bottom.Size = UDim2.new(1, -12, 0.45, 0)
		bottom.Position = UDim2.new(0, 6, 0.55, 0)
		bottom.Text = line2
		styleText(bottom, 16, Color3.fromRGB(190, 255, 190))
		bottom.Parent = frame
	end

	gui.Parent = parent
	return gui, top
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

local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 60 then
		return string.format("%d:%02d", seconds // 60, seconds % 60)
	end
	return seconds .. "s"
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
				if child.Name == "EggAnnouncement" then existing += 1 end
			end
			local screen = Instance.new("ScreenGui")
			screen.Name = "EggAnnouncement"
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
-- BRIGHT MORNING-ON-THE-FARM LIGHTING
--==============================================================================

for _, effect in ipairs(Lighting:GetChildren()) do
	if effect:IsA("PostEffect") or effect:IsA("Atmosphere") then
		effect:Destroy()
	end
end

Lighting.ClockTime = 10.5
Lighting.Brightness = 3
Lighting.Ambient = Color3.fromRGB(150, 150, 160)
Lighting.OutdoorAmbient = Color3.fromRGB(165, 162, 168)
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
atmosphere.Color = Color3.fromRGB(225, 238, 255)
atmosphere.Decay = Color3.fromRGB(255, 205, 160)
atmosphere.Glare = 0.2
atmosphere.Haze = 1
atmosphere.Parent = Lighting

--==============================================================================
-- MAP: THE LONG VALLEY -- a walled canyon of themed zones, copied from the
-- real Steal an Egg map. You spawn in the SAFE ZONE with the bases, and
-- the deeper you walk, the rarer the wild eggs get:
--   SAFE ZONE -> Meadow -> Desert -> Grove -> Snowfields -> the EGG MACHINE
--==============================================================================

local FIELD_HALF_W = 60          -- half the playable width (walls just outside)
local FIELD_Z_NEAR = 290         -- back of the safe zone (behind the bases)
local FIELD_Z_FAR  = -310        -- far end, behind the Egg Machine
local FLOOR_TOP    = 2.1         -- the Y where feet (and eggs) rest
local POND_CENTER  = Vector3.new(26, FLOOR_TOP, -120) -- the Grove's pond

-- Spots wild eggs must NOT spawn on, so they never appear buried inside
-- the pyramid, a bush, a tree... Every decor helper registers itself here.
local NO_SPAWN = { { x = POND_CENTER.X, z = POND_CENTER.Z, r = 17 } }
local function blockSpawns(x, z, r)
	table.insert(NO_SPAWN, { x = x, z = z, r = r })
end

-- Every zone: where it sits along Z, its two checker shades, and the color
-- of the banner that flashes when you walk in.
local ZONES = {
	{ name = "SAFE ZONE",       zMin = 140,  zMax = 290,  floor = Color3.fromRGB( 95, 200,  80), alt = Color3.fromRGB(118, 218,  95), banner = Color3.fromRGB(140, 255, 140) },
	{ name = "THE MEADOW",      zMin = 30,   zMax = 140,  floor = Color3.fromRGB( 95, 200,  80), alt = Color3.fromRGB(118, 218,  95), banner = Color3.fromRGB(170, 255, 120) },
	{ name = "THE DESERT",      zMin = -80,  zMax = 30,   floor = Color3.fromRGB(225, 195, 135), alt = Color3.fromRGB(238, 211, 158), banner = Color3.fromRGB(255, 220, 130) },
	{ name = "THE GROVE",       zMin = -190, zMax = -80,  floor = Color3.fromRGB( 88, 190,  92), alt = Color3.fromRGB(110, 210, 112), banner = Color3.fromRGB(120, 230, 160) },
	{ name = "THE SNOWFIELDS",  zMin = -280, zMax = -190, floor = Color3.fromRGB(232, 238, 244), alt = Color3.fromRGB(249, 251, 255), banner = Color3.fromRGB(200, 235, 255) },
	{ name = "THE EGG MACHINE", zMin = -310, zMax = -280, floor = Color3.fromRGB( 58,  62,  84), alt = Color3.fromRGB( 74,  80, 106), banner = Color3.fromRGB(120, 240, 255) },
}

-- A checkered floor band: one solid slab plus thin lighter tiles on every
-- other square -- that's how the real map gets its diamond-checker look.
local function checkerFloor(zone)
	local length = zone.zMax - zone.zMin
	local midZ = (zone.zMin + zone.zMax) / 2
	newPart({
		Name = "Floor", Size = Vector3.new(FIELD_HALF_W * 2 + 8, 2, length),
		Position = Vector3.new(0, 1, midZ),
		Color = zone.floor, Parent = mapFolder,
	})
	local tile = 12
	local cols = math.floor((FIELD_HALF_W * 2) / tile)
	local rows = math.floor(length / tile)
	for col = 0, cols - 1 do
		for row = 0, rows - 1 do
			if (col + row) % 2 == 0 then
				newPart({
					Name = "Tile", Size = Vector3.new(tile, 0.12, tile),
					Position = Vector3.new(-FIELD_HALF_W + tile / 2 + col * tile, 2.06,
						zone.zMin + tile / 2 + row * tile),
					Color = zone.alt, CanQuery = false, Parent = mapFolder,
				})
			end
		end
	end
end

for _, zone in ipairs(ZONES) do checkerFloor(zone) end

-- The glowing red line where the safe zone ends and the wild field begins.
newPart({
	Name = "SafeLine", Size = Vector3.new(FIELD_HALF_W * 2 + 4, 0.2, 1.4),
	Position = Vector3.new(0, 2.13, ZONES[1].zMin),
	Color = Color3.fromRGB(255, 70, 90), Material = Enum.Material.Neon,
	CanQuery = false, Parent = mapFolder,
})

-- THE CANYON WALLS: giant sloped dirt ramps with grassy tops, hugging the
-- field on both sides and closing it off behind the spawn.
local mapLength = FIELD_Z_NEAR - FIELD_Z_FAR
local mapMidZ = (FIELD_Z_NEAR + FIELD_Z_FAR) / 2
for _, side in ipairs({ -1, 1 }) do
	local wall = newPart({
		Wedge = true, Name = "CanyonWall", Size = Vector3.new(mapLength + 70, 42, 35),
		Color = Color3.fromRGB(206, 132, 84), Material = Enum.Material.Sandstone,
		Parent = mapFolder,
	})
	wall.CFrame = CFrame.new(side * (FIELD_HALF_W + 17.5), 23, mapMidZ)
		* CFrame.Angles(0, math.rad(90 * side), 0)
	newPart({
		Name = "CanyonCap", Size = Vector3.new(24, 2, mapLength + 70),
		Position = Vector3.new(side * (FIELD_HALF_W + 35 + 12), 44, mapMidZ),
		Color = Color3.fromRGB(95, 200, 80), Material = Enum.Material.Grass,
		Parent = mapFolder,
	})
	-- Invisible barrier so nobody can hike up the ramp and out of the map.
	newPart({
		Name = "InvisibleWall", Size = Vector3.new(1, 90, mapLength + 70),
		Position = Vector3.new(side * (FIELD_HALF_W + 0.5), 45, mapMidZ),
		Transparency = 1, CanQuery = false, Parent = mapFolder,
	})
end
do -- the wall behind the spawn end
	local wall = newPart({
		Wedge = true, Name = "CanyonWallBack", Size = Vector3.new(FIELD_HALF_W * 2 + 140, 42, 35),
		Color = Color3.fromRGB(206, 132, 84), Material = Enum.Material.Sandstone,
		Parent = mapFolder,
	})
	wall.CFrame = CFrame.new(0, 23, FIELD_Z_NEAR + 17.5)
end
-- ...and invisible barriers across both ends of the field.
for _, endZ in ipairs({ FIELD_Z_NEAR + 0.5, FIELD_Z_FAR - 0.5 }) do
	newPart({
		Name = "InvisibleWall", Size = Vector3.new(FIELD_HALF_W * 2 + 2, 90, 1),
		Position = Vector3.new(0, 45, endZ),
		Transparency = 1, CanQuery = false, Parent = mapFolder,
	})
end

-- THE EGG MACHINE: the huge dark contraption that seals the far end of the
-- valley, humming with cyan light. The rarest eggs pop out in front of it.
do
	local wallZ = -299
	newPart({
		Name = "MachineBody", Size = Vector3.new(FIELD_HALF_W * 2 + 10, 34, 22),
		Position = Vector3.new(0, 19, wallZ),
		Color = Color3.fromRGB(30, 34, 58), Parent = mapFolder,
	})
	newPart({
		Name = "MachineRoof", Size = Vector3.new(FIELD_HALF_W * 2 + 14, 3, 26),
		Position = Vector3.new(0, 37.5, wallZ),
		Color = Color3.fromRGB(24, 27, 46), Parent = mapFolder,
	})
	-- glowing cyan trim lines across the face
	for _, y in ipairs({ 5, 30 }) do
		newPart({
			Name = "MachineTrim", Size = Vector3.new(FIELD_HALF_W * 2 + 10.2, 0.8, 0.8),
			Position = Vector3.new(0, y, wallZ + 11.2),
			Color = Color3.fromRGB(90, 240, 255), Material = Enum.Material.Neon,
			CanQuery = false, Parent = mapFolder,
		})
	end
	-- chunky side pillars with glowing tops
	for _, x in ipairs({ -52, 52 }) do
		newPart({
			Name = "MachinePillar", Size = Vector3.new(7, 36, 7),
			Position = Vector3.new(x, 20, wallZ + 9),
			Color = Color3.fromRGB(40, 45, 74), Parent = mapFolder,
		})
		ball(Vector3.new(4, 4, 4), Color3.fromRGB(90, 240, 255), {
			Name = "MachinePillarLight", Material = Enum.Material.Neon,
			Position = Vector3.new(x, 39.5, wallZ + 9), Parent = mapFolder,
		})
	end
	-- THE PORTAL: a glowing ring with a dark core, where new eggs come from
	tube("Z", 1.2, 19, Color3.fromRGB(90, 240, 255), {
		Name = "PortalRing", Material = Enum.Material.Neon,
		Position = Vector3.new(0, 13, wallZ + 11),
		Parent = mapFolder,
	})
	tube("Z", 1.4, 15.5, Color3.fromRGB(12, 14, 26), {
		Name = "PortalCore",
		Position = Vector3.new(0, 13, wallZ + 11.4),
		Parent = mapFolder,
	})
	-- two little neon "gauges" beside the portal
	for _, x in ipairs({ -26, 26 }) do
		tube("Z", 1, 7, Color3.fromRGB(255, 110, 160), {
			Name = "MachineGauge", Material = Enum.Material.Neon,
			Position = Vector3.new(x, 12, wallZ + 11.2),
			Parent = mapFolder,
		})
	end
	local machineSign = newPart({
		Name = "MachineSign", Size = Vector3.new(0.5, 0.5, 0.5), Transparency = 1,
		CanCollide = false, CanQuery = false,
		Position = Vector3.new(0, 43, wallZ + 6),
		Parent = mapFolder,
	})
	makeLabel(machineSign, 1.4, "THE EGG MACHINE", Color3.fromRGB(120, 240, 255), 32, 500)
	makeLabel(machineSign, -1.2, "Mythic & Secret eggs appear out here...", Color3.fromRGB(255, 130, 170), 18, 320)
end

--==============================================================================
-- ZONE DECOR -- every helper takes a GROUND position (y = FLOOR_TOP) and
-- builds upward from it, so moving a decoration is just changing X and Z.
--==============================================================================

-- Blocky cube bushes, like the real map's.
local function makeBush(position, size)
	blockSpawns(position.X, position.Z, 6 * size)
	newPart({
		Name = "Bush", Size = Vector3.new(6.5, 4, 5.5) * size,
		Position = position + Vector3.new(0, 2 * size, 0),
		Color = Color3.fromRGB(96, 186, 76), Parent = mapFolder,
	})
	newPart({
		Name = "BushTop", Size = Vector3.new(4, 3, 3.6) * size,
		Position = position + Vector3.new(1.8 * size, 4.4 * size, 0.6 * size),
		Color = Color3.fromRGB(110, 200, 86), Parent = mapFolder,
	})
	for _, offset in ipairs({ Vector3.new(-1.6, 3.6, 1.4), Vector3.new(0.6, 4.7, -1), Vector3.new(2.6, 5.6, 1) }) do
		ball(Vector3.new(0.8, 0.8, 0.8) * size, Color3.fromRGB(60, 140, 55), {
			Name = "BushSpot", Position = position + offset * size, CanCollide = false,
			Parent = mapFolder,
		})
	end
end

-- Cartoon trees: brown trunk + a cluster of bright balls (pass snowy
-- leaf colors for the Snowfields' trees).
local function makeTree(position, size, leafColors)
	blockSpawns(position.X, position.Z, 7 * size)
	tube("Y", 6 * size, 2 * size, Color3.fromRGB(161, 110, 75), {
		Name = "Trunk", Position = position + Vector3.new(0, 3 * size, 0),
		Parent = mapFolder,
	})
	leafColors = leafColors or {
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

-- Desert cacti: a fat column with two stubby arms.
local function makeCactus(position)
	blockSpawns(position.X, position.Z, 4)
	tube("Y", 4.6, 1.7, Color3.fromRGB(80, 175, 95), {
		Name = "Cactus", Position = position + Vector3.new(0, 2.3, 0),
		Parent = mapFolder,
	})
	tube("Y", 1.8, 1, Color3.fromRGB(80, 175, 95), {
		Name = "CactusArm", Position = position + Vector3.new(1.5, 3.4, 0),
		Parent = mapFolder,
	})
	tube("Y", 1.4, 1, Color3.fromRGB(80, 175, 95), {
		Name = "CactusArm", Position = position + Vector3.new(-1.5, 2.9, 0),
		Parent = mapFolder,
	})
	ball(Vector3.new(0.9, 0.6, 0.9), Color3.fromRGB(255, 140, 180), {
		Name = "CactusFlower", Position = position + Vector3.new(0, 4.9, 0),
		CanCollide = false, Parent = mapFolder,
	})
end

-- Ice crystals for the Snowfields.
local function makeCrystal(position, size)
	blockSpawns(position.X, position.Z, 4 * size)
	local icy = Color3.fromRGB(180, 225, 255)
	local shard = ball(Vector3.new(1.6, 5, 1.6) * size, icy, {
		Name = "Crystal", Material = Enum.Material.Glass,
		Parent = mapFolder,
	})
	shard.CFrame = CFrame.new(position + Vector3.new(0, 2.2 * size, 0)) * CFrame.Angles(0, 0, math.rad(8))
	local shard2 = ball(Vector3.new(1, 3, 1) * size, icy, {
		Name = "Crystal", Material = Enum.Material.Glass,
		Parent = mapFolder,
	})
	shard2.CFrame = CFrame.new(position + Vector3.new(1.4 * size, 1.3 * size, 0.6 * size)) * CFrame.Angles(0, 0, math.rad(-14))
end

-- Tufts of tall teal grass, scattered everywhere on the real map.
local function makeTuft(position)
	for i = -1, 1 do
		local blade = ball(Vector3.new(0.35, 2.4 - math.abs(i) * 0.6, 0.35), Color3.fromRGB(110, 220, 200), {
			Name = "Tuft", CanCollide = false, CanQuery = false,
			Parent = mapFolder,
		})
		blade.CFrame = CFrame.new(position + Vector3.new(i * 0.5, 1 - math.abs(i) * 0.25, i * 0.2))
			* CFrame.Angles(0, 0, math.rad(i * 14))
	end
end

-- A sleeping wild bird ("Z z z...") snoozing next to its little nest of
-- decor eggs -- pure set dressing, straight from the screenshot.
local function makeSleepyBird(position, bodyColor)
	blockSpawns(position.X, position.Z, 5)
	bodyColor = bodyColor or Color3.fromRGB(250, 250, 245)
	ball(Vector3.new(2.6, 2, 3.2), bodyColor, {
		Name = "SleepyBird", Position = position + Vector3.new(0, 1, 0),
		Parent = mapFolder,
	})
	ball(Vector3.new(1.4, 1.2, 1.4), bodyColor, {
		Name = "SleepyBirdHead", Position = position + Vector3.new(0, 2, -1.4),
		CanCollide = false, Parent = mapFolder,
	})
	ball(Vector3.new(0.5, 0.3, 0.8), Color3.fromRGB(255, 170, 60), {
		Name = "SleepyBirdBeak", Position = position + Vector3.new(0, 1.9, -2.1),
		CanCollide = false, Parent = mapFolder,
	})
	-- closed eyes: two thin dark lines
	for _, x in ipairs({ -0.4, 0.4 }) do
		ball(Vector3.new(0.4, 0.08, 0.2), Color3.fromRGB(50, 40, 45), {
			Name = "SleepyEye", Position = position + Vector3.new(x, 2.2, -1.95),
			CanCollide = false, CanQuery = false, Parent = mapFolder,
		})
	end
	local anchor = newPart({
		Name = "SleepyAnchor", Size = Vector3.new(0.4, 0.4, 0.4), Transparency = 1,
		CanCollide = false, CanQuery = false,
		Position = position + Vector3.new(0, 3.4, -1), Parent = mapFolder,
	})
	makeLabel(anchor, 0.8, "Z z z...", Color3.fromRGB(200, 220, 255), 18, 70)
end

local function makeDecorNest(position)
	blockSpawns(position.X, position.Z, 4)
	tube("Y", 0.5, 3.4, Color3.fromRGB(200, 165, 115), {
		Name = "DecorNest", Position = position + Vector3.new(0, 0.25, 0),
		Parent = mapFolder,
	})
	for _, offset in ipairs({ Vector3.new(-0.6, 0, 0.3), Vector3.new(0.6, 0, 0.2), Vector3.new(0, 0, -0.6) }) do
		ball(Vector3.new(0.9, 1.2, 0.9), Color3.fromRGB(250, 248, 240), {
			Name = "DecorEgg", Position = position + offset + Vector3.new(0, 0.9, 0),
			CanCollide = false, Parent = mapFolder,
		})
	end
end

-- MEADOW: bushes, tufts, a snoozing goose by her nest.
for _, spot in ipairs({ { -32, 116, 1 }, { 38, 92, 0.8 }, { -18, 52, 1.1 }, { 44, 44, 0.9 } }) do
	makeBush(Vector3.new(spot[1], FLOOR_TOP, spot[2]), spot[3])
end
for _, spot in ipairs({ { -44, 128 }, { 12, 108 }, { -6, 74 }, { 50, 66 }, { -38, 40 } }) do
	makeTuft(Vector3.new(spot[1], FLOOR_TOP, spot[2]))
end
makeSleepyBird(Vector3.new(24, FLOOR_TOP, 60))
makeDecorNest(Vector3.new(20, FLOOR_TOP, 55))

-- DESERT: the step pyramid, cacti, and sun-baked rocks.
do
	local pyBase = Vector3.new(-34, FLOOR_TOP, -14)
	blockSpawns(pyBase.X, pyBase.Z, 20)
	for tier, width in ipairs({ 26, 19, 12, 6 }) do
		newPart({
			Name = "Pyramid", Size = Vector3.new(width, 3.2, width),
			Position = pyBase + Vector3.new(0, tier * 3.2 - 1.6, 0),
			Color = Color3.fromRGB(210 - tier * 8, 165 - tier * 6, 105), Parent = mapFolder,
		})
	end
end
for _, spot in ipairs({ { 30, 18 }, { 46, -12 }, { -8, -34 }, { 20, -58 }, { -48, -66 } }) do
	makeCactus(Vector3.new(spot[1], FLOOR_TOP, spot[2]))
end
for _, spot in ipairs({ { 8, -8, 2.4 }, { -20, -52, 1.7 }, { 42, -44, 2 } }) do
	blockSpawns(spot[1], spot[2], 5)
	ball(Vector3.new(spot[3], spot[3] * 0.7, spot[3]) * 1.6, Color3.fromRGB(190, 160, 130), {
		Name = "DesertRock", Position = Vector3.new(spot[1], FLOOR_TOP + spot[3] * 0.3, spot[2]),
		Parent = mapFolder,
	})
end

-- GROVE: the pond, leafy trees, more bushes and a snoozing duck.
tube("Y", 0.3, 30, Color3.fromRGB(240, 228, 180), {
	Name = "PondRim", Position = POND_CENTER + Vector3.new(0, 0.02, 0), Parent = mapFolder,
})
tube("Y", 0.32, 26, Color3.fromRGB(120, 200, 250), {
	Name = "Pond", Position = POND_CENTER + Vector3.new(0, 0.1, 0),
	Material = Enum.Material.Glass, Parent = mapFolder,
})
for _, offset in ipairs({ Vector3.new(-5, 0.3, 3), Vector3.new(6, 0.3, -2) }) do
	ball(Vector3.new(2.2, 0.3, 2.2), Color3.fromRGB(100, 200, 110), {
		Name = "LilyPad", Position = POND_CENTER + offset, CanCollide = false,
		Parent = mapFolder,
	})
end
for _, spot in ipairs({ { -36, -100, 1.2 }, { -42, -160, 1 }, { 40, -170, 1.3 } }) do
	makeTree(Vector3.new(spot[1], FLOOR_TOP, spot[2]), spot[3])
end
for _, spot in ipairs({ { 14, -92, 0.9 }, { -14, -140, 1 } }) do
	makeBush(Vector3.new(spot[1], FLOOR_TOP, spot[2]), spot[3])
end
for _, spot in ipairs({ { -30, -122 }, { 46, -138 }, { 4, -176 } }) do
	makeTuft(Vector3.new(spot[1], FLOOR_TOP, spot[2]))
end
makeSleepyBird(Vector3.new(38, FLOOR_TOP, -108), Color3.fromRGB(255, 235, 160))

-- SNOWFIELDS: snowy trees, ice crystals, one very cold sleeping bird.
local SNOW_LEAVES = {
	Color3.fromRGB(240, 246, 252), Color3.fromRGB(222, 234, 246), Color3.fromRGB(250, 252, 255),
}
for _, spot in ipairs({ { -38, -206, 1.1 }, { 42, -232, 1.2 }, { -20, -262, 0.9 } }) do
	makeTree(Vector3.new(spot[1], FLOOR_TOP, spot[2]), spot[3], SNOW_LEAVES)
end
for _, spot in ipairs({ { 24, -204, 1 }, { -46, -240, 1.4 }, { 8, -246, 0.8 }, { 46, -266, 1.1 } }) do
	makeCrystal(Vector3.new(spot[1], FLOOR_TOP, spot[2]), spot[3])
end
makeSleepyBird(Vector3.new(-8, FLOOR_TOP, -222), Color3.fromRGB(225, 240, 255))
makeDecorNest(Vector3.new(-13, FLOOR_TOP, -227))

-- Puffy clouds floating over the valley.
for _, spot in ipairs({
	Vector3.new(-45, 58, 100), Vector3.new(38, 64, -20), Vector3.new(-30, 60, -150),
	Vector3.new(50, 66, -250), Vector3.new(0, 62, 210),
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

-- Spawn pad in the SAFE ZONE, right by the red line, facing the field.
local spawnPad = Instance.new("SpawnLocation")
spawnPad.Size = Vector3.new(12, 1, 12)
spawnPad.Position = Vector3.new(0, FLOOR_TOP + 0.4, 152)
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
	Position = Vector3.new(0, 14, 158),
	Parent = mapFolder,
})
makeLabel(welcomeSign, 1.6, "STEAL AN EGG", Color3.fromRGB(255, 200, 80), 34, 300)
makeLabel(welcomeSign, -1, "Wild eggs get RARER the deeper you go - they HATCH into birds worth 3x!", Color3.fromRGB(255, 244, 200), 18, 300)

-- Tutorial signs along the way.
local function tipSign(position, text, color)
	blockSpawns(position.X, position.Z, 3)
	local post = tube("Y", 5, 0.8, Color3.fromRGB(190, 140, 95), {
		Name = "TipPost", Position = position + Vector3.new(0, 2.5, 0), Parent = mapFolder,
	})
	makeLabel(post, 4, text, color or Color3.fromRGB(255, 255, 255), 20, 120)
end

tipSign(Vector3.new(-14, FLOOR_TOP, 134), "Past the red line the eggs are WILD - tap E to buy one!", Color3.fromRGB(140, 255, 160))
tipSign(Vector3.new(16, FLOOR_TOP, 84), "Bought eggs tumble home to your nest all by themselves", Color3.fromRGB(190, 230, 255))
tipSign(Vector3.new(-16, FLOOR_TOP, 24), "Hold E on someone ELSE's nest egg to STEAL it...", Color3.fromRGB(255, 160, 140))
tipSign(Vector3.new(14, FLOOR_TOP, -84), "...then RUN HOME! Stolen eggs KEEP their hatch timer!", Color3.fromRGB(255, 220, 120))
tipSign(Vector3.new(-12, FLOOR_TOP, -194), "Bonk thieves with your frying pan to make them drop eggs!", Color3.fromRGB(255, 190, 255))

-- THE TRAIL SHOP STAND. The invisible "TrailShopZone" part is what the
-- TrailShop LocalScript looks for -- walk in and the shop opens. If you
-- already built your own TrailShopZone somewhere, we leave yours alone.
if not workspace:FindFirstChild("TrailShopZone", true) then
	local standCenter = Vector3.new(0, FLOOR_TOP, 276)
	newPart({
		Name = "ShopCounter", Size = Vector3.new(12, 3.4, 4),
		Position = standCenter + Vector3.new(0, 1.7, 0),
		Color = Color3.fromRGB(255, 170, 200), Parent = mapFolder,
	})
	for _, x in ipairs({ -5.4, 5.4 }) do
		tube("Y", 8, 0.8, Color3.fromRGB(250, 250, 245), {
			Name = "ShopPost", Position = standCenter + Vector3.new(x, 4, -1.4),
			Parent = mapFolder,
		})
	end
	local awning = newPart({
		Name = "ShopAwning", Size = Vector3.new(14, 0.6, 7),
		Color = Color3.fromRGB(255, 70, 200), Parent = mapFolder,
	})
	awning.CFrame = CFrame.new(standCenter + Vector3.new(0, 8.4, -0.2)) * CFrame.Angles(math.rad(-12), 0, 0)
	local shopSign = newPart({
		Name = "ShopSignAnchor", Size = Vector3.new(0.5, 0.5, 0.5), Transparency = 1,
		CanCollide = false, CanQuery = false,
		Position = standCenter + Vector3.new(0, 11, 0),
		Parent = mapFolder,
	})
	makeLabel(shopSign, 0, "TRAIL SHOP - run faster, escape with eggs!", Color3.fromRGB(255, 140, 220), 22, 200)
	newPart({
		Name = "TrailShopZone", Size = Vector3.new(18, 10, 14),
		Position = standCenter + Vector3.new(0, 5, 4),
		Transparency = 1, CanCollide = false, Anchored = true,
		Parent = mapFolder,
	})
end

--==============================================================================
-- BASES -- rounded pastel yards full of nests, one per player
--==============================================================================

local BASE_W, BASE_D = 30, 22
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
		locked = false, lockReadyAt = 0, lockGeneration = 0, nests = {},
	}

	local folder = Instance.new("Folder")
	folder.Name = "Base" .. index
	folder.Parent = mapFolder
	base.folder = folder

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

	-- The NESTS: cozy twig rings in two rows, spaced to fit the floor
	-- whatever NESTS_PER_BASE is set to.
	local cols = math.ceil(NESTS_PER_BASE / 2)
	local usable = BASE_W - 10
	local spacing = cols > 1 and usable / (cols - 1) or 0
	local nestIndex = 0
	for row = 0, 1 do
		for col = 0, cols - 1 do
			nestIndex += 1
			if nestIndex > NESTS_PER_BASE then break end
			local nestPos = centerPos + Vector3.new(-usable / 2 + col * spacing, 0, -6 + row * 12)
			local ring = tube("Y", 0.9, 6.2, Color3.fromRGB(150, 105, 70), {
				Name = "NestRing" .. nestIndex,
				Position = nestPos + Vector3.new(0, 0.95, 0),
				Material = Enum.Material.Wood,
				Parent = folder,
			})
			local pad = tube("Y", 0.6, 4.8, Color3.fromRGB(230, 200, 150), {
				Name = "Nest" .. nestIndex,
				Position = nestPos + Vector3.new(0, 1.0, 0),
				Parent = folder,
			})
			local _, moneyLabel = makeLabel(ring, 1.4, "", Color3.fromRGB(140, 255, 140), 16, 70)
			base.nests[nestIndex] = { pad = pad, ring = ring, moneyLabel = moneyLabel, egg = nil }
		end
	end

	local towardConveyor = (centerPos.X > 0) and -1 or 1

	-- The lock button: a chunky red mushroom button on the base's front
	-- edge, clear of the nest grid (nests sit at x = +/-10, z = +/-6).
	local buttonBasePos = centerPos + Vector3.new(towardConveyor * (BASE_W / 2 - 2.5), 0.5, 0)
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

-- Two columns of four bases fill the SAFE ZONE, with a walkway down the
-- middle leading out to the field.
do
	local index = 0
	for _, x in ipairs({ -32, 32 }) do
		for row = 0, 3 do
			index += 1
			bases[index] = buildBase(index, Vector3.new(x, 2.7, 168 + row * 35))
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

-- Which zone is this position in? (drives the banner that flashes when you
-- cross into a new part of the valley)
local function zoneAt(position)
	if math.abs(position.X) > FIELD_HALF_W + 6 then return nil end
	for _, zone in ipairs(ZONES) do
		if position.Z >= zone.zMin and position.Z < zone.zMax then
			return zone
		end
	end
	return nil
end

local function showZoneBanner(player, zone)
	local gui = player:FindFirstChild("PlayerGui")
	if not gui then return end
	local old = gui:FindFirstChild("EggZoneBanner")
	if old then old:Destroy() end
	local screen = Instance.new("ScreenGui")
	screen.Name = "EggZoneBanner"
	screen.ResetOnSpawn = false
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.34, 0, 0, 46)
	label.Position = UDim2.new(0.33, 0, 0.86, 0)
	label.BackgroundColor3 = Color3.fromRGB(35, 28, 48)
	label.BackgroundTransparency = 0.25
	label.Text = zone.name
	styleText(label, 30, zone.banner)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = zone.banner
	stroke.Thickness = 3
	stroke.Parent = label
	label.Parent = screen
	screen.Parent = gui
	Debris:AddItem(screen, 2.5)
end

--==============================================================================
-- EGG & BIRD MODELS
-- An egg is a stretched ball with a pattern painted on. A bird is a round
-- chick built from balls. Parts named "Tint" recolor with mutations.
--==============================================================================

local function eggPart(model, part)
	part.CanCollide = false
	part.CanQuery = true
	part.Parent = model
	return part
end

local function tinted(model, part)
	part.Name = "Tint"
	return eggPart(model, part)
end

-- Googly eyes: white balls with black pupils, stuck on the front (-Z).
local function addEyes(model, centerY, centerZ, gap, size)
	size = size or 0.7
	for _, x in ipairs({ -gap, gap }) do
		eggPart(model, ball(Vector3.new(size, size, size * 0.55), Color3.new(1, 1, 1), {
			Name = "Eye", Position = Vector3.new(x, centerY, centerZ),
		}))
		eggPart(model, ball(Vector3.new(size * 0.45, size * 0.45, size * 0.3), Color3.new(0, 0, 0), {
			Name = "Pupil", Position = Vector3.new(x, centerY, centerZ - size * 0.18),
		}))
	end
end

-- Fixed directions around the shell so speckles look scattered but are the
-- same on every copy of an egg (no two Speckle Eggs looking mismatched).
local SPECKLE_SPOTS = {
	Vector3.new( 0.5,  0.55, -0.65), Vector3.new(-0.7,  0.3,  -0.5),
	Vector3.new( 0.75, 0.0,   0.5),  Vector3.new(-0.45, -0.35, -0.7),
	Vector3.new( 0.2,  0.8,   0.4),  Vector3.new(-0.6,  0.6,   0.35),
}

-- Builds JUST the egg shape (used for nests, the belt, and being carried).
local function buildEggBody(model, egg)
	local shellSize = Vector3.new(2.3, 3.0, 2.3)
	local center = Vector3.new(0, 1.5, 0)
	local shell = ball(shellSize, egg.shell, { Position = center })
	if egg.material then shell.Material = egg.material end
	tinted(model, shell)

	local radius = Vector3.new(shellSize.X, shellSize.Y, shellSize.Z) / 2

	if egg.pattern == "speckles" or egg.pattern == "stars" then
		for _, dir in ipairs(SPECKLE_SPOTS) do
			local unit = dir.Unit
			local spot = ball(Vector3.new(0.55, 0.55, 0.3), egg.accent, {
				Name = "Speckle",
				CFrame = CFrame.lookAt(
					center + Vector3.new(unit.X * radius.X, unit.Y * radius.Y, unit.Z * radius.Z) * 0.97,
					center),
			})
			if egg.pattern == "stars" or egg.accentNeon then spot.Material = Enum.Material.Neon end
			eggPart(model, spot)
		end
	elseif egg.pattern == "stripes" then
		-- Bands slightly WIDER than the shell's cross-section at their
		-- height, so they poke out as rings instead of hiding inside it.
		for _, band in ipairs({ { y = 1.1, d = 2.35 }, { y = 1.9, d = 2.3 } }) do
			local stripe = tube("Y", 0.22, band.d, egg.accent, {
				Name = "Stripe", Position = Vector3.new(0, band.y, 0),
			})
			if egg.accentNeon then stripe.Material = Enum.Material.Neon end
			eggPart(model, stripe)
		end
	elseif egg.pattern == "spikes" then
		for i = 0, 4 do
			local angle = i * math.pi * 2 / 5
			eggPart(model, ball(Vector3.new(0.45, 1.1, 0.45), egg.accent, {
				Name = "Spike",
				CFrame = CFrame.new(center + Vector3.new(math.cos(angle) * 0.95, 0.45, math.sin(angle) * 0.95))
					* CFrame.Angles(0, 0, -math.cos(angle) * 0.5) * CFrame.Angles(math.sin(angle) * 0.5, 0, 0),
			}))
		end
		eggPart(model, ball(Vector3.new(0.5, 1.2, 0.5), egg.accent, {
			Name = "Spike", Position = center + Vector3.new(0, radius.Y * 0.95, 0),
		}))
	end

	return 3.2 -- the egg's height before scaling
end

-- Builds the hatched bird: a round chick with eyes, beak, wings and a tail.
-- The Goose Egg hatches into a proper long-necked golden goose instead.
local function buildBirdBody(model, egg)
	local body = egg.birdBody or egg.accent
	local belly = body:Lerp(Color3.new(1, 1, 1), 0.45)

	if egg.goose then
		tinted(model, ball(Vector3.new(3.2, 2.6, 4.2), body, { Position = Vector3.new(0, 1.9, 0.3) }))
		eggPart(model, ball(Vector3.new(2, 1.6, 2.6), belly, { Name = "Belly", Position = Vector3.new(0, 1.3, -0.6) }))
		eggPart(model, tube("Y", 2.2, 0.8, body, { Name = "Neck", CFrame = CFrame.new(0, 3.4, -1.5) * CFrame.Angles(math.rad(12), 0, 0) }))
		eggPart(model, ball(Vector3.new(1.3, 1.2, 1.3), body, { Name = "Head", Position = Vector3.new(0, 4.7, -1.8) }))
		eggPart(model, ball(Vector3.new(0.5, 0.35, 1), Color3.fromRGB(255, 170, 60), { Name = "Beak", Position = Vector3.new(0, 4.6, -2.6) }))
		addEyes(model, 4.9, -2.2, 0.4, 0.45)
		-- golden crown, because she IS the event
		eggPart(model, tube("Y", 0.5, 1.1, Color3.fromRGB(255, 220, 90), {
			Name = "Crown", Material = Enum.Material.Neon, Position = Vector3.new(0, 5.5, -1.8),
		}))
		for _, x in ipairs({ -1, 1 }) do
			eggPart(model, ball(Vector3.new(0.6, 1.4, 2.2), body:Lerp(Color3.new(1, 1, 0.8), 0.2), {
				Name = "Wing", Position = Vector3.new(x * 1.7, 2.1, 0.4),
			}))
		end
		addEyesFeet(model)
		return 5.8
	end

	-- The standard chick: one chubby ball with everything stuck on.
	tinted(model, ball(Vector3.new(2.6, 2.6, 2.3), body, { Position = Vector3.new(0, 1.7, 0) }))
	eggPart(model, ball(Vector3.new(1.6, 1.5, 1), belly, { Name = "Belly", Position = Vector3.new(0, 1.3, -0.75) }))
	addEyes(model, 2.2, -1.05, 0.5, 0.55)
	eggPart(model, ball(Vector3.new(0.55, 0.4, 0.8), Color3.fromRGB(255, 170, 60), { Name = "Beak", Position = Vector3.new(0, 1.75, -1.35) }))
	for _, x in ipairs({ -1, 1 }) do
		eggPart(model, ball(Vector3.new(0.5, 1.1, 1.4), body, { Name = "Wing", Position = Vector3.new(x * 1.35, 1.7, 0.1) }))
	end
	for i = -1, 1 do
		eggPart(model, ball(Vector3.new(0.45, 0.85, 0.45), body, {
			Name = "TailFeather",
			CFrame = CFrame.new(0.35 * i, 2.1, 1.15) * CFrame.Angles(math.rad(-30), 0, math.rad(i * 18)),
		}))
	end
	for _, x in ipairs({ -0.55, 0.55 }) do
		eggPart(model, ball(Vector3.new(0.7, 0.4, 1), Color3.fromRGB(255, 170, 60), {
			Name = "Foot", Position = Vector3.new(x, 0.2, -0.15),
		}))
	end
	-- Epic and up get a fancy head tuft.
	if rarityIndex[egg.rarity] >= 3 then
		for i = -1, 1 do
			eggPart(model, ball(Vector3.new(0.35, 0.9, 0.35), egg.accent, {
				Name = "Tuft",
				CFrame = CFrame.new(0.3 * i, 3.2, 0) * CFrame.Angles(0, 0, math.rad(i * -20)),
			}))
		end
	end
	return 3.1
end

-- (tiny helper used by the goose above -- little orange feet)
function addEyesFeet(model)
	for _, x in ipairs({ -0.8, 0.8 }) do
		eggPart(model, ball(Vector3.new(0.8, 0.45, 1.2), Color3.fromRGB(255, 170, 60), {
			Name = "Foot", Position = Vector3.new(x, 0.25, -0.2),
		}))
	end
end

--==============================================================================
-- EGG "INFO" TABLES
-- Every egg in play is described by an info table:
--   { egg, mutation = nil/"Shiny"/"Glowing"/"Rainbow",
--     price, hatched = false/true, elapsed = seconds of hatching done }
--==============================================================================

local function makeInfo(egg, mutationName)
	local info = {
		egg = egg,
		mutation = mutationName,
		price = egg.price,
		hatched = false,
		elapsed = 0,
	}
	local mutation = mutationName and mutationsByName[mutationName]
	if mutation then
		info.price = math.floor(egg.price * mutation.priceMult)
	end
	return info
end

-- What's this thing called right now? "Shiny Sunny Egg" -> "Shiny Sunbeam".
local function displayNameOf(info)
	local base = info.hatched and info.egg.bird or info.egg.name
	return info.mutation and (info.mutation .. " " .. base) or base
end

-- How much does it earn per second right now?
local function incomeOf(info)
	local mult = 1
	local mutation = info.mutation and mutationsByName[info.mutation]
	if mutation then mult = mutation.incomeMult end
	if info.hatched then mult *= HATCH_MULT end
	return math.floor(info.egg.income * mult + 0.5)
end

local function hatchTimeOf(egg)
	return egg.hatchTime or rarityByName[egg.rarity].hatchTime
end

local function rollMutation()
	local roll = rng:NextNumber()
	-- Check rarest first so Rainbow isn't swallowed by Shiny's chance.
	if roll < MUTATIONS[3].chance then return "Rainbow" end
	if roll < MUTATIONS[3].chance + MUTATIONS[2].chance then return "Glowing" end
	if roll < MUTATIONS[3].chance + MUTATIONS[2].chance + MUTATIONS[1].chance then return "Shiny" end
	return nil
end

--==============================================================================
-- MODEL ASSEMBLY -- build the body, scale it, add the name bubble
--==============================================================================

local function buildModelFor(info)
	local egg = info.egg
	local mutation = info.mutation and mutationsByName[info.mutation]

	local model = Instance.new("Model")
	model.Name = displayNameOf(info)

	-- Invisible root at the feet: the pivot every PivotTo moves.
	local root = newPart({
		Name = "Root", Size = Vector3.new(0.4, 0.4, 0.4),
		Transparency = 1, CanCollide = false, CanQuery = false,
		Position = Vector3.new(0, 0.2, 0),
	})
	root.Parent = model
	model.PrimaryPart = root

	local height
	if info.hatched then
		height = buildBirdBody(model, egg)
	else
		height = buildEggBody(model, egg)
	end

	-- Mutations recolor the "Tint" parts and add shine.
	if mutation then
		for _, part in ipairs(model:GetChildren()) do
			if part.Name == "Tint" then
				if info.mutation == "Shiny" then
					part.Color = part.Color:Lerp(mutation.color, 0.55)
				elseif info.mutation == "Glowing" then
					part.Color = part.Color:Lerp(mutation.color, 0.4)
					part.Material = Enum.Material.Neon
				else
					part.Color = mutation.color
				end
			end
		end
	end

	local scale = egg.scale or (0.85 + rarityIndex[egg.rarity] * 0.08)
	model:ScaleTo(scale)
	height = height * scale
	model:SetAttribute("Height", height)

	-- Name bubble: name on top, rarity + income below.
	local rarity = rarityByName[egg.rarity]
	local nameColor = mutation and mutation.color or rarity.color
	makeBubble(root, height + 2.2,
		displayNameOf(info),
		egg.rarity .. "  |  " .. formatCash(incomeOf(info)) .. "/s",
		nameColor, 110)

	-- Unhatched eggs get a countdown tag the income loop keeps updated.
	if not info.hatched then
		local gui = makeLabel(root, height + 0.9, "", Color3.fromRGB(255, 235, 140), 15, 80)
		gui.Name = "HatchGui"
	end

	-- Sparkly eggs sparkle; the scariest stuff gets a glowing outline
	-- (Roblox renders at most 31 highlights, so we save them for the top).
	if egg.sparkle or info.mutation == "Shiny" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = nameColor
		sparkles.Parent = root
	end
	if egg.rarity == "Secret" or info.mutation == "Rainbow" then
		local glow = Instance.new("Highlight")
		glow.FillTransparency = 1
		glow.OutlineColor = nameColor
		glow.Parent = model
	end

	return model, height
end

-- Rainbow eggs (and birds) cycle through every color.
local function applyRainbow(model)
	local color = Color3.fromHSV(os.clock() * 0.4 % 1, 0.85, 1)
	for _, part in ipairs(model:GetChildren()) do
		if part.Name == "Tint" then part.Color = color end
	end
end

--==============================================================================
-- GAME STATE
--==============================================================================

local playerData = {}     -- [player] = { base, carrying, lastBonk, trails, equippedTrail, loaded, loadFailed, savedEggs, lastZone }
local wildEggs = {}       -- array of { model, info, sold, bornAt }
local carriedItems = {}   -- [model] = { thief, victim, fromBase, fromNest, info }
local deliveries = {}     -- array of { model, info, base, nestIndex, pos, roll }

local function getCash(player)
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Cash")
end

local function addCash(player, amount)
	local cash = getCash(player)
	if cash then cash.Value += amount end
end

local function updateEggStat(player)
	local data = playerData[player]
	local stats = player:FindFirstChild("leaderstats")
	local stat = stats and stats:FindFirstChild("Eggs")
	if stat and data and data.base then
		local n = 0
		for _, nest in ipairs(data.base.nests) do
			if nest.egg then n += 1 end
		end
		stat.Value = n
	end
end

local function findEmptyNest(base)
	for i, nest in ipairs(base.nests) do
		if not nest.egg then return i end
	end
	return nil
end

-- One function owns everyone's WalkSpeed, so trails and carrying always
-- combine correctly: carrying slows you, your trail speeds you up.
local function setWalkSpeed(player)
	local data = playerData[player]
	if not data then return end
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local trail = data.equippedTrail and trailsByName[data.equippedTrail]
	local bonus = trail and trail.speed or 0
	humanoid.WalkSpeed = (data.carrying and CARRY_WALKSPEED or BASE_WALKSPEED) + bonus
end

local function setCarrying(player, model)
	local data = playerData[player]
	if not data then return end
	data.carrying = model
	setWalkSpeed(player)
end

--==============================================================================
-- PLACING & REMOVING EGGS
--==============================================================================

local setupStealPrompt -- (defined below; declared here so placeEgg can use it)

local function placeEgg(base, nestIndex, model, info, pile)
	local nest = base.nests[nestIndex]
	local pad = nest.pad
	local padTop = pad.Position.Y + pad.Size.X / 2 -- pad is a Y-axis cylinder: height is Size.X
	local baseCF = CFrame.new(pad.Position.X, padTop, pad.Position.Z)
		* CFrame.Angles(0, math.rad(rng:NextNumber(0, 360)), 0)
	nest.egg = { model = model, info = info, pile = pile or 0, baseCF = baseCF }
	model:PivotTo(baseCF)
	model.Parent = base.folder
	setupStealPrompt(base, nestIndex, model, info)
	if base.owner then updateEggStat(base.owner) end
end

local function removeFromNest(base, nestIndex)
	local nest = base.nests[nestIndex]
	local entry = nest.egg
	nest.egg = nil
	nest.moneyLabel.Text = ""
	-- Whatever cash was piled up here goes straight to the owner, so
	-- getting robbed doesn't also burn your uncollected earnings.
	if entry and entry.pile > 0 and base.owner then
		addCash(base.owner, entry.pile)
		entry.pile = 0
	end
	if base.owner then updateEggStat(base.owner) end
	return entry
end

--==============================================================================
-- HATCHING! -- the egg pops, sparkles fly, and a bird worth 3x appears
--==============================================================================

local function hatchEgg(base, nestIndex)
	local nest = base.nests[nestIndex]
	local entry = nest.egg
	if not entry or entry.info.hatched then return end

	local info = entry.info
	info.hatched = true
	local oldModel = entry.model
	local model = buildModelFor(info)
	entry.model = model
	model:PivotTo(entry.baseCF)
	model.Parent = base.folder
	oldModel:Destroy()
	setupStealPrompt(base, nestIndex, model, info)

	-- Celebration!
	local burst = Instance.new("Sparkles")
	burst.SparkleColor = rarityByName[info.egg.rarity].color
	burst.Parent = model.PrimaryPart
	Debris:AddItem(burst, 3)
	cashPopup(nest.pad.Position + Vector3.new(0, 5, 0), "HATCHED!", Color3.fromRGB(255, 235, 140))
	if base.owner and rarityIndex[info.egg.rarity] >= 4 then
		announce(base.owner.Name .. "'s " .. info.egg.name .. " hatched into " .. displayNameOf(info) .. "!",
			rarityByName[info.egg.rarity].color)
	end
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
		local nestIndex = info.fromNest
		if info.fromBase.nests[nestIndex].egg then
			nestIndex = findEmptyNest(info.fromBase)
		end
		if nestIndex then
			placeEgg(info.fromBase, nestIndex, model, info.info, 0)
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

function setupStealPrompt(base, nestIndex, model, info)
	local old = model.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
	if old then old:Destroy() end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Steal"
	prompt.ObjectText = displayNameOf(info)
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Enabled = not base.locked
	prompt.Parent = model.PrimaryPart

	prompt.Triggered:Connect(function(player)
		local data = playerData[player]
		if not data or not data.base then return end
		-- Exploiters can fire prompts from across the map, so never trust
		-- the trigger alone -- re-check the distance on the server.
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp or not model.PrimaryPart then return end
		if (hrp.Position - model.PrimaryPart.Position).Magnitude > prompt.MaxActivationDistance + 5 then return end
		if player == base.owner then return end        -- can't steal your own
		if base.locked then return end                 -- base is shielded
		if data.carrying then return end               -- one at a time, thief
		if carriedItems[model] then return end         -- someone beat you to it
		local entry = base.nests[nestIndex].egg
		if not entry or entry.model ~= model then return end

		removeFromNest(base, nestIndex)
		prompt:Destroy()
		setCarrying(player, model)
		carriedItems[model] = {
			thief = player, victim = base.owner,
			fromBase = base, fromNest = nestIndex, info = info,
		}
		announce(player.Name .. " is stealing " .. displayNameOf(info) .. "! GET THEM!", Color3.fromRGB(255, 120, 120))
	end)
end

--==============================================================================
-- WILD EGGS: they appear scattered around the zones (the deeper the zone,
-- the rarer the egg), plus the pity timer and buying
--==============================================================================

local lastBigSpawn = os.clock()

-- Where eggs like to appear. weight = how often that zone gets the next
-- egg; rarities = the odds within that zone. The last row is the glowing
-- strip right in front of the Egg Machine.
local SPAWN_SPOTS = {
	{ zone = ZONES[2], weight = 34, rarities = { Common = 70, Rare = 30 } },
	{ zone = ZONES[3], weight = 26, rarities = { Rare = 55, Epic = 45 } },
	{ zone = ZONES[4], weight = 20, rarities = { Epic = 60, Legendary = 40 } },
	{ zone = ZONES[5], weight = 13, rarities = { Legendary = 70, Mythic = 30 } },
	{ zone = { name = "THE EGG MACHINE", zMin = -276, zMax = -240 }, weight = 7, rarities = { Mythic = 65, Secret = 35 } },
}

local function pickWildSpawn()
	local pityTriggered = (os.clock() - lastBigSpawn) > PITY_MINUTES * 60
	-- Pity spawns only use the deep zones, and only Legendary+.
	local spots = {}
	for i, spot in ipairs(SPAWN_SPOTS) do
		if not pityTriggered or i >= 4 then table.insert(spots, spot) end
	end
	local total = 0
	for _, s in ipairs(spots) do total += s.weight end
	local roll = rng:NextNumber(0, total)
	local chosen = spots[#spots]
	for _, s in ipairs(spots) do
		roll -= s.weight
		if roll <= 0 then chosen = s break end
	end

	local rarityTotal = 0
	for name, w in pairs(chosen.rarities) do
		if not pityTriggered or rarityIndex[name] >= 4 then rarityTotal += w end
	end
	local rarityRoll = rng:NextNumber(0, rarityTotal)
	local chosenRarity = nil
	for name, w in pairs(chosen.rarities) do
		if not pityTriggered or rarityIndex[name] >= 4 then
			rarityRoll -= w
			if rarityRoll <= 0 and not chosenRarity then chosenRarity = name end
		end
	end
	chosenRarity = chosenRarity or "Legendary"

	local pool = {}
	for _, e in ipairs(EGGS) do
		if e.rarity == chosenRarity and not e.eventOnly then table.insert(pool, e) end
	end
	return chosen.zone, pool[rng:NextInteger(1, #pool)]
end

-- A random open spot inside a zone, dodging everything in NO_SPAWN (the
-- pond, the pyramid, bushes, trees...) so eggs never spawn buried.
local function randomWildPosition(zone)
	for _ = 1, 20 do
		local x = rng:NextNumber(-(FIELD_HALF_W - 10), FIELD_HALF_W - 10)
		local z = rng:NextNumber(zone.zMin + 6, zone.zMax - 6)
		local clear = true
		for _, spot in ipairs(NO_SPAWN) do
			local dx, dz = spot.x - x, spot.z - z
			if dx * dx + dz * dz < spot.r * spot.r then clear = false break end
		end
		if clear then
			return Vector3.new(x, FLOOR_TOP, z)
		end
	end
	return Vector3.new(0, FLOOR_TOP, (zone.zMin + zone.zMax) / 2)
end

local function spawnWildEgg(specialEgg, overridePosition)
	if not specialEgg and #wildEggs >= MAX_WILD_EGGS then return end
	local zone, egg
	if specialEgg then
		egg = specialEgg
		zone = ZONES[3] -- the Goose lands mid-valley, in the Desert
	else
		zone, egg = pickWildSpawn()
	end
	if rarityIndex[egg.rarity] >= 4 then lastBigSpawn = os.clock() end
	-- A plain if, on purpose: `specialEgg and nil or rollMutation()` would
	-- ALWAYS roll (classic Lua trap), and event eggs must never mutate.
	local mutation = nil
	if not specialEgg then mutation = rollMutation() end
	local info = makeInfo(egg, mutation)
	local model = buildModelFor(info)
	local pos = overridePosition or randomWildPosition(zone)
	model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, math.rad(rng:NextNumber(0, 360)), 0))
	model.Parent = mapFolder

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Buy"
	prompt.ObjectText = displayNameOf(info) .. "  " .. formatCash(info.price)
	prompt.HoldDuration = 0 -- tap E, instant!
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart

	local item = { model = model, info = info, sold = false, bornAt = os.clock() }
	table.insert(wildEggs, item)

	prompt.Triggered:Connect(function(player)
		if item.sold then return end
		local data = playerData[player]
		if not data or not data.base then return end
		-- Same anti-exploit distance check as stealing: no remote buying.
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp or not model.PrimaryPart then return end
		if (hrp.Position - model.PrimaryPart.Position).Magnitude > prompt.MaxActivationDistance + 5 then return end
		local cash = getCash(player)
		if not cash or cash.Value < info.price then return end
		local nestIndex = findEmptyNest(data.base)
		if not nestIndex then return end

		item.sold = true
		cash.Value -= info.price
		prompt:Destroy()
		for i, it in ipairs(wildEggs) do
			if it == item then table.remove(wildEggs, i) break end
		end
		cashPopup(model.PrimaryPart.Position + Vector3.new(0, 3, 0), "-" .. formatCash(info.price), Color3.fromRGB(255, 150, 150))

		-- Reserve the nest, then let the egg tumble over to its new home.
		data.base.nests[nestIndex].egg = { model = model, info = info, pile = 0, inTransit = true }
		table.insert(deliveries, {
			model = model, info = info, base = data.base, nestIndex = nestIndex,
			pos = model.PrimaryPart.Position, roll = 0,
		})
	end)

	if rarityIndex[egg.rarity] >= 5 or info.mutation == "Rainbow" then
		announce("A " .. (info.mutation and (info.mutation .. " ") or "") .. egg.rarity .. " "
			.. egg.name .. " appeared in " .. zone.name .. "!!", rarityByName[egg.rarity].color)
	end
end

--==============================================================================
-- THE FRYING PAN -- bonk thieves and they drop the egg
--==============================================================================

local function makePan()
	local tool = Instance.new("Tool")
	tool.Name = "Frying Pan"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Bonk thieves to make them drop stolen eggs!"

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Shape = Enum.PartType.Cylinder
	handle.Size = Vector3.new(0.5, 2.8, 2.8)
	handle.Color = Color3.fromRGB(70, 70, 80)
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Parent = tool

	return tool
end

local function onPanActivated(player)
	local data = playerData[player]
	if not data then return end
	local now = os.clock()
	if now - data.lastBonk < BONK_COOLDOWN then return end
	data.lastBonk = now

	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	for _, victim in ipairs(Players:GetPlayers()) do
		if victim ~= player then
			local vChar = victim.Character
			local vHrp = vChar and vChar:FindFirstChild("HumanoidRootPart")
			if vHrp and (vHrp.Position - hrp.Position).Magnitude <= BONK_RANGE then
				local delta = vHrp.Position - hrp.Position
				local pushDirection = delta.Magnitude > 0.05 and delta.Unit or hrp.CFrame.LookVector
				vHrp.AssemblyLinearVelocity = pushDirection * 60 + Vector3.new(0, 35, 0)
				local vData = playerData[victim]
				if vData and vData.carrying then
					dropCarried(victim)
					announce(player.Name .. " bonked the egg out of " .. victim.Name .. "'s hands!",
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
	for _, nest in ipairs(base.nests) do
		if nest.egg and not nest.egg.inTransit then
			local prompt = nest.egg.model.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
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
-- EVENTS -- the Golden Goose and Egg Rain take turns
--==============================================================================

local function goldenGooseEvent()
	announce("HONK! THE GOLDEN GOOSE has landed in THE DESERT!", Color3.fromRGB(255, 215, 90))
	announce("Her Goose Egg is worth a fortune - first come, first served!", Color3.fromRGB(255, 240, 180))
	spawnWildEgg(eggsByName["Goose Egg"], Vector3.new(0, FLOOR_TOP, -25))
end

local function eggRainEvent()
	announce("EGG RAIN! Catch the falling eggs for free cash!", Color3.fromRGB(140, 220, 255))
	local pastels = {
		Color3.fromRGB(255, 180, 200), Color3.fromRGB(180, 220, 255),
		Color3.fromRGB(200, 255, 190), Color3.fromRGB(255, 235, 160),
	}
	local endAt = os.clock() + RAIN_LENGTH
	while os.clock() < endAt do
		local drop = ball(Vector3.new(1.6, 2.1, 1.6), pastels[rng:NextInteger(1, #pastels)], {
			Name = "RainEgg", Anchored = false, CanCollide = true,
			Position = Vector3.new(rng:NextNumber(-50, 50), 70, rng:NextNumber(-270, 130)),
			Parent = mapFolder,
		})
		local claimed = false
		drop.Touched:Connect(function(hit)
			if claimed then return end
			local character = hit.Parent
			local player = character and Players:GetPlayerFromCharacter(character)
			if not player then return end
			claimed = true
			local reward = rng:NextInteger(50, 400)
			addCash(player, reward)
			cashPopup(drop.Position, "+" .. formatCash(reward), Color3.fromRGB(140, 255, 140))
			drop:Destroy()
		end)
		Debris:AddItem(drop, 15)
		task.wait(0.7)
	end
	announce("The egg rain drizzles out...", Color3.fromRGB(190, 210, 255))
end

task.spawn(function()
	local gooseNext = true
	while true do
		task.wait(EVENT_EVERY)
		if gooseNext then goldenGooseEvent() else eggRainEvent() end
		gooseNext = not gooseNext
	end
end)

--==============================================================================
-- CASH HUD -- a chunky rounded counter at the bottom of everyone's screen
--==============================================================================

local function makeHud(player)
	local gui = player:FindFirstChild("PlayerGui")
	if not gui then return end
	local old = gui:FindFirstChild("EggHud")
	if old then old:Destroy() end

	local screen = Instance.new("ScreenGui")
	screen.Name = "EggHud"
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
	local screen = gui and gui:FindFirstChild("EggHud")
	if not screen then return end
	local frame = screen:FindFirstChildOfClass("Frame")
	if not frame then return end
	frame.CashText.Text = formatCash(cashValue)
	frame.IncomeText.Text = "+" .. formatCash(incomePerSec) .. "/s"
end

--==============================================================================
-- TRAILS -- the server side of the Trail Shop. The LocalScript only DRAWS
-- the shop; every purchase is checked and granted right here, so exploiters
-- can't give themselves free trails, and everyone SEES your trail.
--==============================================================================

local function applyTrail(player)
	local data = playerData[player]
	if not data then return end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Clear the old trail (and its attachments) first.
	for _, name in ipairs({ "EggTrail", "EggTrailA0", "EggTrailA1" }) do
		local old = hrp:FindFirstChild(name)
		if old then old:Destroy() end
	end

	local trail = data.equippedTrail and trailsByName[data.equippedTrail]
	if trail then
		local a0 = Instance.new("Attachment")
		a0.Name = "EggTrailA0"
		a0.Position = Vector3.new(0, 1, 0)
		a0.Parent = hrp
		local a1 = Instance.new("Attachment")
		a1.Name = "EggTrailA1"
		a1.Position = Vector3.new(0, -1, 0)
		a1.Parent = hrp
		local t = Instance.new("Trail")
		t.Name = "EggTrail"
		t.Attachment0 = a0
		t.Attachment1 = a1
		t.Lifetime = 0.4
		t.FaceCamera = true
		t.LightEmission = 0.6
		t.Color = ColorSequence.new(trail.color)
		t.Transparency = NumberSequence.new(0.2, 1)
		t.Parent = hrp
	end
	setWalkSpeed(player)
end

local function sendTrailUpdate(player)
	local data = playerData[player]
	if not data then return end
	trailUpdate:FireClient(player, data.trails, data.equippedTrail or "")
end

getTrailData.OnServerInvoke = function(player)
	local data = playerData[player]
	return {
		catalog = TRAILS,
		owned = data and data.trails or {},
		equipped = data and data.equippedTrail or "",
	}
end

trailAction.OnServerEvent:Connect(function(player, action, name)
	local data = playerData[player]
	if not data then return end
	if type(action) ~= "string" then return end

	if action == "buy" and type(name) == "string" then
		local trail = trailsByName[name]
		if not trail or data.trails[name] then return end
		local cash = getCash(player)
		if not cash or cash.Value < trail.price then return end
		cash.Value -= trail.price
		data.trails[name] = true
		data.equippedTrail = name
		applyTrail(player)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			cashPopup(hrp.Position + Vector3.new(0, 4, 0), name .. "!", trail.color)
		end
	elseif action == "equip" and type(name) == "string" then
		if not data.trails[name] then return end
		data.equippedTrail = name
		applyTrail(player)
	elseif action == "unequip" then
		data.equippedTrail = nil
		applyTrail(player)
	end
	sendTrailUpdate(player)
end)

--==============================================================================
-- SAVING (safe to leave on -- if saving isn't available it just skips)
--==============================================================================

local saveStore = nil
if SAVE_PROGRESS then
	pcall(function()
		saveStore = DataStoreService:GetDataStore("StealAnEgg_v1")
	end)
end

local alreadySaved = {}

local function savePlayer(player, final)
	if not saveStore then return end
	if alreadySaved[player] then return end
	local data = playerData[player]
	local cash = getCash(player)
	if not data or not cash then return end
	-- Never write until a load finished cleanly: a failed or unfinished
	-- load must not overwrite the real save with a fresh state.
	if not data.loaded or data.loadFailed then return end
	if data.saving then return end
	data.saving = true

	local cashValue = cash.Value
	local eggs = {}
	if data.base then
		for _, nest in ipairs(data.base.nests) do
			local entry = nest.egg
			if entry then
				table.insert(eggs, {
					name = entry.info.egg.name, mutation = entry.info.mutation,
					hatched = entry.info.hatched, elapsed = entry.info.elapsed,
				})
				cashValue += entry.pile -- uncollected piles come with us
			end
		end
	elseif data.savedEggs then
		-- Joined a full server and never got a base: keep the stored
		-- collection exactly as it was.
		eggs = data.savedEggs
	end
	-- An egg of ours that a thief is carrying right now is still ours.
	for _, info in pairs(carriedItems) do
		if info.victim == player then
			table.insert(eggs, {
				name = info.info.egg.name, mutation = info.info.mutation,
				hatched = info.info.hatched, elapsed = info.info.elapsed,
			})
		end
	end

	local trailList = {}
	for name in pairs(data.trails) do table.insert(trailList, name) end

	local ok = pcall(function()
		saveStore:SetAsync("player_" .. player.UserId, {
			cash = cashValue, eggs = eggs,
			trails = trailList, equipped = data.equippedTrail,
		})
	end)
	data.saving = false
	if ok and final then
		alreadySaved[player] = true
		-- Forget the flag once it can't matter anymore, so the table
		-- doesn't slowly collect every player who ever left.
		task.delay(60, function() alreadySaved[player] = nil end)
	end
end

local function loadPlayer(player)
	if not saveStore then return true, nil end
	local result = nil
	local ok = pcall(function()
		result = saveStore:GetAsync("player_" .. player.UserId)
	end)
	return ok, result
end

-- Autosave everyone every few minutes, so a server crash can't cost more
-- than a couple minutes of progress.
task.spawn(function()
	while true do
		task.wait(AUTOSAVE_EVERY)
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(savePlayer, player, false)
		end
	end
end)

--==============================================================================
-- PLAYERS JOINING & LEAVING
--==============================================================================

local function restoreEggs(base, eggList)
	for _, saved in ipairs(eggList) do
		local egg = eggsByName[saved.name]
		if egg then
			local info = makeInfo(egg, saved.mutation)
			info.hatched = saved.hatched == true
			info.elapsed = math.min(tonumber(saved.elapsed) or 0, hatchTimeOf(egg))
			local nestIndex = findEmptyNest(base)
			if nestIndex then
				placeEgg(base, nestIndex, buildModelFor(info), info, 0)
			elseif base.owner then
				-- More saved eggs than nests (e.g. one was being carried by a
				-- thief at save time): pay out instead of deleting it.
				addCash(base.owner, info.price)
			end
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
	if data.savedEggs then
		restoreEggs(base, data.savedEggs)
		data.savedEggs = nil
	end
	updateEggStat(player)
end

Players.PlayerAdded:Connect(function(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = STARTING_CASH
	cash.Parent = stats
	local count = Instance.new("IntValue")
	count.Name = "Eggs"
	count.Value = 0
	count.Parent = stats
	stats.Parent = player

	playerData[player] = {
		base = nil, carrying = nil, lastBonk = 0,
		trails = {}, equippedTrail = nil,
		loaded = false, loadFailed = false, savedEggs = nil,
	}

	-- Hook the character FIRST (before any yielding), so the first life
	-- always gets its pan, trail, and death handler.
	local function onCharacter(char)
		local pan = makePan()
		pan.Activated:Connect(function() onPanActivated(player) end)
		pan.Parent = player:WaitForChild("Backpack")
		char:WaitForChild("Humanoid").Died:Connect(function()
			dropCarried(player) -- dying returns the stolen egg
		end)
		task.wait(0.2) -- let the character finish assembling, then dress it up
		applyTrail(player)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then task.spawn(onCharacter, player.Character) end

	-- PlayerGui only exists once the character has spawned, so wait for it.
	task.spawn(function()
		player:WaitForChild("PlayerGui", 60)
		makeHud(player)
	end)

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
			data.savedEggs = saved.eggs
			for _, name in ipairs(saved.trails or {}) do
				if trailsByName[name] then data.trails[name] = true end
			end
			if saved.equipped and data.trails[saved.equipped] then
				data.equippedTrail = saved.equipped
				applyTrail(player)
			end
		else
			-- Brand new player: a free Plain Egg to get the farm going!
			data.savedEggs = { { name = "Plain Egg" } }
		end
	end
	sendTrailUpdate(player)

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
	-- task.spawn: the save SNAPSHOT is taken synchronously right now, but
	-- the slow SetAsync yields -- and the cleanup below must not wait for
	-- it, or the leaver's eggs sit stealable during the yield.
	task.spawn(savePlayer, player, true)
	dropCarried(player)
	-- Anything of theirs still being carried by thieves was just written
	-- into their save, so remove the live copy -- otherwise the thief could
	-- secure it and the same egg would exist twice.
	for model, info in pairs(carriedItems) do
		if info.victim == player then
			carriedItems[model] = nil
			setCarrying(info.thief, nil)
			model:Destroy()
		end
	end
	local data = playerData[player]
	if data and data.base then
		local base = data.base
		base.owner = nil
		base.signLabel.Text = "EMPTY BASE - JOIN TO CLAIM"
		base.incomeLabel.Text = ""
		for _, nest in ipairs(base.nests) do
			if nest.egg then
				nest.egg.model:Destroy()
				nest.egg = nil
			end
			nest.moneyLabel.Text = ""
		end
		resetBaseLock(base)
		-- Hand the freed base to anyone who was waiting.
		for _, waiting in ipairs(Players:GetPlayers()) do
			local wData = playerData[waiting]
			if waiting ~= player and wData and not wData.base and (wData.loaded or wData.loadFailed) then
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
		savePlayer(player, true)
	end
end)

--==============================================================================
-- MAIN LOOPS
--==============================================================================

-- Wild egg spawner (and the sweeper that clears eggs nobody bought).
task.spawn(function()
	while true do
		task.wait(SPAWN_INTERVAL)
		for i = #wildEggs, 1, -1 do
			local item = wildEggs[i]
			if os.clock() - item.bornAt > EGG_LIFETIME then
				table.remove(wildEggs, i)
				item.model:Destroy()
			end
		end
		spawnWildEgg()
	end
end)

-- Income & hatching: every second each egg adds cash to its pile and its
-- hatch timer ticks down (with a little wobble when it's about to pop!).
-- Standing in your own base collects all your piles.
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local data = playerData[player]
			if data then
				-- Flash the zone banner when they cross into a new zone.
				local char = player.Character
				local zoneHrp = char and char:FindFirstChild("HumanoidRootPart")
				if zoneHrp then
					local zone = zoneAt(zoneHrp.Position)
					local zoneName = zone and zone.name or ""
					if zoneName ~= data.lastZone then
						data.lastZone = zoneName
						if zone then showZoneBanner(player, zone) end
					end
				end
				addCash(player, PASSIVE_INCOME)
				local incomePerSec = PASSIVE_INCOME
				local base = data.base
				if base then
					local home = isPlayerInBase(player, base)
					local collected = 0
					for nestIndex, nest in ipairs(base.nests) do
						local entry = nest.egg
						if entry and not entry.inTransit then
							local gain = incomeOf(entry.info)
							entry.pile += gain
							incomePerSec += gain
							if home then
								collected += entry.pile
								entry.pile = 0
							end
							nest.moneyLabel.Text = entry.pile > 0 and formatCash(entry.pile) or ""
							if entry.info.mutation == "Rainbow" then
								applyRainbow(entry.model)
							end
							if not entry.info.hatched then
								entry.info.elapsed += 1
								local remaining = hatchTimeOf(entry.info.egg) - entry.info.elapsed
								if remaining <= 0 then
									hatchEgg(base, nestIndex)
								else
									local gui = entry.model.PrimaryPart:FindFirstChild("HatchGui")
									local label = gui and gui:FindFirstChildOfClass("TextLabel")
									if label then
										label.Text = "Hatches in " .. formatTime(remaining)
									end
									if remaining <= 15 then
										-- so close! wiggle with excitement
										entry.model:PivotTo(entry.baseCF
											* CFrame.Angles(0, 0, math.rad(entry.info.elapsed % 2 == 0 and 8 or -8)))
									end
								end
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

-- Movement: bought eggs tumble home, carried ones hover over the thief,
-- steals secure at home base, and Rainbow wild eggs cycle their colors.
RunService.Heartbeat:Connect(function(dt)
	local clockNow = os.clock()

	for _, item in ipairs(wildEggs) do
		if item.info.mutation == "Rainbow" then
			applyRainbow(item.model)
		end
	end

	-- Bought eggs tumbling over to their new home.
	for i = #deliveries, 1, -1 do
		local delivery = deliveries[i]
		local base, nestIndex = delivery.base, delivery.nestIndex
		local nest = base.nests[nestIndex]
		local entry = nest.egg
		-- The base emptied or changed hands mid-delivery: cancel.
		if not base.owner or not entry or entry.model ~= delivery.model then
			table.remove(deliveries, i)
			delivery.model:Destroy()
			if entry and entry.model == delivery.model then nest.egg = nil end
		else
			local pad = nest.pad
			local padTop = pad.Position.Y + pad.Size.X / 2
			local target = Vector3.new(pad.Position.X, padTop, pad.Position.Z)
			local flat = Vector3.new(target.X - delivery.pos.X, 0, target.Z - delivery.pos.Z)
			local step = DELIVERY_SPEED * dt
			if flat.Magnitude <= step + 0.1 then
				-- Arrived: settle into the nest and become stealable.
				table.remove(deliveries, i)
				entry.inTransit = nil
				placeEgg(base, nestIndex, delivery.model, delivery.info, 0)
			else
				delivery.pos += flat.Unit * step
				delivery.roll += DELIVERY_SPEED * dt / 1.4
				local centerY = (delivery.model:GetAttribute("Height") or 3) / 2
				local direction = CFrame.lookAt(delivery.pos, Vector3.new(target.X, delivery.pos.Y, target.Z))
				delivery.model:PivotTo(
					CFrame.new(delivery.pos.X, target.Y + centerY, delivery.pos.Z)
					* (direction - direction.Position)
					* CFrame.Angles(delivery.roll, 0, 0) * CFrame.new(0, -centerY, 0))
			end
		end
	end

	-- Carried eggs hover above the thief.
	for model, info in pairs(carriedItems) do
		local char = info.thief.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local bob = math.sin(clockNow * 5) * 0.3
			model:PivotTo(hrp.CFrame * CFrame.new(0, 2.6 + bob, 0) * CFrame.Angles(0, 0, math.rad(8)))
			if info.info.mutation == "Rainbow" then
				applyRainbow(model)
			end

			-- Home safe? Secure the steal!
			local thiefData = playerData[info.thief]
			local homeBase = thiefData and thiefData.base
			if homeBase and isPlayerInBase(info.thief, homeBase) then
				local nestIndex = findEmptyNest(homeBase)
				if nestIndex then
					carriedItems[model] = nil
					setCarrying(info.thief, nil)
					placeEgg(homeBase, nestIndex, model, info.info, 0)
					announce(info.thief.Name .. " got away with " .. displayNameOf(info.info) .. "!",
						Color3.fromRGB(120, 255, 120))
				end
			end
		end
	end
end)

print("Steal an Egg loaded! Go get those eggs :)")
