--==============================================================================
-- SNATCH A BRAINROT
-- A complete "Steal a Brainrot"-style game in ONE script.
--
-- HOW TO USE:
--   1. Open Roblox Studio -> new "Baseplate" place
--   2. In the Explorer, find ServerScriptService
--   3. Insert a Script inside it, delete the default code, paste ALL of this
--   4. Press Play. That's the whole setup.
--
-- Brainrots walk down the conveyor in the middle of the map. Stand next to
-- one and hold E to buy it. It goes to your base and earns cash every second
-- -- but the cash PILES UP at your base, and you have to stand in your base
-- to collect it! You can STEAL brainrots from other players' bases (hold E
-- on them), then run home to secure them. Lock your base to protect it, and
-- slap thieves with your bat to make them drop what they stole!
--==============================================================================

--==============================================================================
-- CONFIG -- play with these numbers! Nothing here can break the game.
--==============================================================================

local STARTING_CASH   = 100   -- cash a brand-new player starts with
local PASSIVE_INCOME  = 2     -- free cash per second, so nobody gets stuck at 0
local SPAWN_INTERVAL  = 4     -- seconds between brainrots appearing
local MAX_ON_CONVEYOR = 8     -- max brainrots walking at once
local WALK_SPEED      = 6     -- how fast brainrots walk (studs per second)
local SLOTS_PER_BASE  = 10    -- how many brainrots one base can hold
local LOCK_DURATION   = 45    -- seconds your base stays locked
local LOCK_COOLDOWN   = 60    -- seconds before you can lock again
local SLAP_RANGE      = 9     -- how close you must be to slap someone
local SLAP_COOLDOWN   = 1.5   -- seconds between slaps
local CARRY_WALKSPEED = 11    -- thieves are slowed while carrying (normal is 16)
local SAVE_PROGRESS   = true  -- saves cash + brainrots (needs API access, see README)

-- Rarity tiers: chance is a weight (bigger = more common).
local RARITIES = {
	{ name = "Common",       color = Color3.fromRGB(190, 190, 190), chance = 50,   },
	{ name = "Rare",         color = Color3.fromRGB( 85, 170, 255), chance = 26,   },
	{ name = "Epic",         color = Color3.fromRGB(170,  85, 255), chance = 13,   },
	{ name = "Legendary",    color = Color3.fromRGB(255, 170,   0), chance = 7,    },
	{ name = "Mythic",       color = Color3.fromRGB(255,  60,  60), chance = 2.8,  },
	{ name = "Brainrot God", color = Color3.fromRGB(255,  40, 130), chance = 1,    },
	{ name = "Secret",       color = Color3.fromRGB( 25,  25,  25), chance = 0.2,  },
}

-- Mutations: rare variants that multiply income. Rolled when one spawns.
local MUTATIONS = {
	{ name = "Gold",    chance = 0.10, incomeMult = 1.25, priceMult = 2,  color = Color3.fromRGB(255, 200,  50) },
	{ name = "Diamond", chance = 0.04, incomeMult = 1.5,  priceMult = 4,  color = Color3.fromRGB(130, 220, 255) },
	{ name = "Rainbow", chance = 0.01, incomeMult = 10,   priceMult = 20, color = Color3.fromRGB(255,   0, 255) },
}

-- The cast (the real Steal a Brainrot roster!).
-- price = cost to buy, income = cash per second, body = main color,
-- scale = how chunky it is (1 = normal).
local CHARACTERS = {
	-- Common
	{ name = "Noobini Pizzanini",      rarity = "Common",       price = 25,      income = 1,     body = Color3.fromRGB(255, 220, 120), scale = 0.8 },
	{ name = "Tim Cheese",             rarity = "Common",       price = 60,      income = 2,     body = Color3.fromRGB(255, 200,  80), scale = 0.9 },
	{ name = "Fluriflura",             rarity = "Common",       price = 90,      income = 3,     body = Color3.fromRGB(255, 170, 204), scale = 0.9 },
	{ name = "Svinina Bombardino",     rarity = "Common",       price = 120,     income = 4,     body = Color3.fromRGB(255, 190, 190), scale = 1.0 },
	-- Rare
	{ name = "Trippi Troppi",          rarity = "Rare",         price = 400,     income = 8,     body = Color3.fromRGB(255, 150, 130), scale = 0.9 },
	{ name = "Boneca Ambalabu",        rarity = "Rare",         price = 650,     income = 12,    body = Color3.fromRGB(100, 180, 110), scale = 1.0 },
	{ name = "Bananita Dolphinita",    rarity = "Rare",         price = 900,     income = 16,    body = Color3.fromRGB(255, 225, 100), scale = 1.0 },
	-- Epic
	{ name = "Cappuccino Assassino",   rarity = "Epic",         price = 2500,    income = 35,    body = Color3.fromRGB(140,  90,  60), scale = 0.9 },
	{ name = "Brr Brr Patapim",        rarity = "Epic",         price = 4000,    income = 55,    body = Color3.fromRGB( 90, 140,  80), scale = 1.2 },
	{ name = "Lirili Larila",          rarity = "Epic",         price = 6000,    income = 80,    body = Color3.fromRGB(150, 200, 150), scale = 1.2 },
	-- Legendary
	{ name = "Ballerina Cappuccina",   rarity = "Legendary",    price = 15000,   income = 175,   body = Color3.fromRGB(220, 170, 130), scale = 0.9 },
	{ name = "Chimpanzini Bananini",   rarity = "Legendary",    price = 22000,   income = 250,   body = Color3.fromRGB(180, 220,  90), scale = 1.0 },
	{ name = "Frigo Camelo",           rarity = "Legendary",    price = 30000,   income = 330,   body = Color3.fromRGB(200, 220, 230), scale = 1.4 },
	{ name = "Burbaloni Luliloli",     rarity = "Legendary",    price = 38000,   income = 400,   body = Color3.fromRGB(180, 130,  80), scale = 1.1 },
	-- Mythic
	{ name = "Bombardiro Crocodilo",   rarity = "Mythic",       price = 90000,   income = 900,   body = Color3.fromRGB( 70, 120,  70), scale = 1.4 },
	{ name = "Bombombini Gusini",      rarity = "Mythic",       price = 160000,  income = 1500,  body = Color3.fromRGB(230, 230, 230), scale = 1.3 },
	-- Brainrot God
	{ name = "Cocofanto Elefanto",     rarity = "Brainrot God", price = 500000,  income = 4200,  body = Color3.fromRGB(140, 110,  80), scale = 1.5 },
	{ name = "Odin Din Din Dun",       rarity = "Brainrot God", price = 750000,  income = 6000,  body = Color3.fromRGB(255, 150,  50), scale = 1.3 },
	{ name = "Trenostruzzo Turbo 3000", rarity = "Brainrot God", price = 1100000, income = 8500, body = Color3.fromRGB( 80, 160,  90), scale = 1.6 },
	{ name = "Tralalero Tralala",      rarity = "Brainrot God", price = 1500000, income = 11000, body = Color3.fromRGB( 60,  90, 160), scale = 1.3 },
	-- Secret
	{ name = "La Vacca Saturno Saturnita", rarity = "Secret",   price = 4000000, income = 26000, body = Color3.fromRGB( 60,  60, 100), scale = 1.7 },
	{ name = "Tung Tung Tung Sahur",   rarity = "Secret",       price = 6000000, income = 38000, body = Color3.fromRGB(160, 110,  60), scale = 1.3 },
	{ name = "Los Tralaleritos",       rarity = "Secret",       price = 8000000, income = 50000, body = Color3.fromRGB(120, 170, 230), scale = 1.2 },
	{ name = "La Grande Combinasion",  rarity = "Secret",       price = 12000000, income = 75000, body = Color3.fromRGB( 40,  40,  40), scale = 1.8 },
}

--==============================================================================
-- SERVICES & BASIC SETUP (you don't need to touch anything below this line,
-- but reading it is a great way to learn how the game works!)
--==============================================================================

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")
local DataStoreService  = game:GetService("DataStoreService")

local rng = Random.new()

local charactersByName = {}
for _, c in ipairs(CHARACTERS) do charactersByName[c.name] = c end

local rarityByName = {}
for _, r in ipairs(RARITIES) do rarityByName[r.name] = r end

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
-- SMALL HELPERS
--==============================================================================

local function newPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do part[key] = value end
	return part
end

local function makeLabel(parent, offsetY, text, textColor, textSize)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 260, 0, 44)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 130
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextSize = textSize or 18
	label.TextColor3 = textColor or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Text = text
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

-- Shows a big announcement banner on everyone's screen for a few seconds.
local function announce(text, color)
	for _, player in ipairs(Players:GetPlayers()) do
		local gui = player:FindFirstChild("PlayerGui")
		if gui then
			local screen = Instance.new("ScreenGui")
			screen.Name = "BrainrotAnnouncement"
			screen.ResetOnSpawn = false
			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, 0, 0, 42)
			label.Position = UDim2.new(0, 0, 0.12, 0)
			label.BackgroundTransparency = 0.35
			label.BackgroundColor3 = Color3.new(0, 0, 0)
			label.Font = Enum.Font.FredokaOne
			label.TextSize = 30
			label.TextColor3 = color or Color3.new(1, 1, 1)
			label.TextStrokeTransparency = 0.5
			label.Text = text
			label.Parent = screen
			screen.Parent = gui
			Debris:AddItem(screen, 4)
		end
	end
end

--==============================================================================
-- MAP: ground, conveyor, decorations
--==============================================================================

local CONVEYOR_LENGTH = 220
local CONVEYOR_START  = Vector3.new(0, 0, -CONVEYOR_LENGTH / 2)
local CONVEYOR_END    = Vector3.new(0, 0,  CONVEYOR_LENGTH / 2)
local BELT_TOP_Y      = 2

newPart({
	Name = "Ground", Size = Vector3.new(340, 2, 300),
	Position = Vector3.new(0, 0, 0),
	Color = Color3.fromRGB(120, 200, 120), Material = Enum.Material.Grass,
	Parent = mapFolder,
})

newPart({
	Name = "ConveyorBelt", Size = Vector3.new(14, 1, CONVEYOR_LENGTH + 20),
	Position = Vector3.new(0, 1.5, 0),
	Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.SmoothPlastic,
	Parent = mapFolder,
})

-- Yellow stripes so the belt looks like it's moving somewhere.
for z = -CONVEYOR_LENGTH / 2, CONVEYOR_LENGTH / 2, 20 do
	newPart({
		Name = "Stripe", Size = Vector3.new(10, 0.1, 2),
		Position = Vector3.new(0, 2.06, z),
		Color = Color3.fromRGB(255, 220, 60), Material = Enum.Material.Neon,
		Parent = mapFolder,
	})
end

-- Archways at each end of the conveyor.
for _, z in ipairs({ -CONVEYOR_LENGTH / 2 - 5, CONVEYOR_LENGTH / 2 + 5 }) do
	newPart({ Name = "ArchLeft",  Size = Vector3.new(3, 18, 3), Position = Vector3.new(-9, 9, z), Color = Color3.fromRGB(255, 90, 160), Parent = mapFolder })
	newPart({ Name = "ArchRight", Size = Vector3.new(3, 18, 3), Position = Vector3.new( 9, 9, z), Color = Color3.fromRGB(255, 90, 160), Parent = mapFolder })
	local top = newPart({ Name = "ArchTop", Size = Vector3.new(21, 3, 3), Position = Vector3.new(0, 19.5, z), Color = Color3.fromRGB(255, 90, 160), Parent = mapFolder })
	if z < 0 then makeLabel(top, 3, "BRAINROTS INCOMING", Color3.fromRGB(255, 240, 120), 24) end
end

local spawnPad = Instance.new("SpawnLocation")
spawnPad.Size = Vector3.new(14, 1, 14)
spawnPad.Position = Vector3.new(0, 1.5, CONVEYOR_LENGTH / 2 + 30)
spawnPad.Anchored = true
spawnPad.Neutral = true
spawnPad.Color = Color3.fromRGB(255, 255, 255)
spawnPad.Material = Enum.Material.SmoothPlastic
spawnPad.TopSurface = Enum.SurfaceType.Smooth
spawnPad.Duration = 0
spawnPad.Parent = mapFolder

--==============================================================================
-- BASES -- built around the conveyor, one per player
--==============================================================================

local BASE_W, BASE_D = 46, 34
local bases = {}

local BASE_COLORS = {
	Color3.fromRGB(255, 120, 120), Color3.fromRGB(120, 170, 255),
	Color3.fromRGB(130, 220, 130), Color3.fromRGB(255, 200, 100),
	Color3.fromRGB(210, 140, 255), Color3.fromRGB(120, 220, 220),
	Color3.fromRGB(255, 160, 210), Color3.fromRGB(200, 200, 140),
}

local function buildBase(index, centerPos)
	local base = {
		index = index, owner = nil, center = centerPos,
		locked = false, lockReadyAt = 0, slots = {},
	}

	local folder = Instance.new("Folder")
	folder.Name = "Base" .. index
	folder.Parent = mapFolder
	base.folder = folder

	base.floor = newPart({
		Name = "Floor", Size = Vector3.new(BASE_W, 1, BASE_D),
		Position = centerPos,
		Color = BASE_COLORS[index], Material = Enum.Material.SmoothPlastic,
		Parent = folder,
	})

	local sign = newPart({
		Name = "Sign", Size = Vector3.new(0.5, 0.5, 0.5), Transparency = 1,
		CanCollide = false, CanQuery = false,
		Position = centerPos + Vector3.new(0, 14, 0),
		Parent = folder,
	})
	local _, signLabel = makeLabel(sign, 0, "EMPTY BASE - JOIN TO CLAIM", Color3.new(1, 1, 1), 26)
	base.signLabel = signLabel

	-- Slot pads in two rows of five. Each pad gets a money label that shows
	-- the cash piling up under whatever brainrot stands on it.
	local slotIndex = 0
	for row = 0, 1 do
		for col = 0, (SLOTS_PER_BASE / 2) - 1 do
			slotIndex += 1
			local pad = newPart({
				Name = "Slot" .. slotIndex, Size = Vector3.new(7, 0.4, 7),
				Position = centerPos + Vector3.new(-16 + col * 8, 0.7, -6 + row * 12),
				Color = Color3.fromRGB(240, 240, 240), Material = Enum.Material.SmoothPlastic,
				Parent = folder,
			})
			local _, moneyLabel = makeLabel(pad, 1.2, "", Color3.fromRGB(140, 255, 140), 15)
			base.slots[slotIndex] = { pad = pad, moneyLabel = moneyLabel, brainrot = nil }
		end
	end

	-- The lock button: a red pedestal at the front of the base.
	local towardConveyor = (centerPos.X > 0) and -1 or 1
	local button = newPart({
		Name = "LockButton", Size = Vector3.new(3, 3, 3),
		Position = centerPos + Vector3.new(towardConveyor * (BASE_W / 2 - 3), 2.5, BASE_D / 2 - 3),
		Color = Color3.fromRGB(255, 80, 80), Material = Enum.Material.Neon,
		Parent = folder,
	})
	makeLabel(button, 2.5, "BASE LOCK", Color3.fromRGB(255, 120, 120), 16)
	local lockPrompt = Instance.new("ProximityPrompt")
	lockPrompt.ActionText = "Lock Base"
	lockPrompt.ObjectText = "Shield (" .. LOCK_DURATION .. "s)"
	lockPrompt.HoldDuration = 0.25
	lockPrompt.MaxActivationDistance = 8
	lockPrompt.RequiresLineOfSight = false
	lockPrompt.Parent = button
	base.lockPrompt = lockPrompt

	-- Shield walls, invisible until the base is locked.
	local shield = newPart({
		Name = "Shield", Size = Vector3.new(BASE_W + 2, 24, BASE_D + 2),
		Position = centerPos + Vector3.new(0, 12, 0),
		Color = Color3.fromRGB(90, 200, 255), Material = Enum.Material.ForceField,
		Transparency = 1, CanCollide = false,
		Parent = folder,
	})
	base.shield = shield

	return base
end

-- Four bases per side, facing the conveyor.
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
-- BRAINROT "INFO" TABLES
-- Every spawned brainrot is described by an info table:
--   { character = ..., mutation = nil or "Gold"/"Diamond"/"Rainbow",
--     displayName, price, income }
--==============================================================================

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
	local roll = rng:NextNumber()
	-- Check rarest first so Rainbow isn't swallowed by Gold's chance.
	if roll < MUTATIONS[3].chance then return "Rainbow" end
	if roll < MUTATIONS[3].chance + MUTATIONS[2].chance then return "Diamond" end
	if roll < MUTATIONS[3].chance + MUTATIONS[2].chance + MUTATIONS[1].chance then return "Gold" end
	return nil
end

--==============================================================================
-- BRAINROT CHARACTER MODELS -- goofy little blocky guys
--==============================================================================

local function buildBrainrotModel(info)
	local character = info.character
	local rarity = rarityByName[character.rarity]
	local s = character.scale
	local mutation = info.mutation and mutationsByName[info.mutation]
	local bodyColor = mutation and mutation.color or character.body

	local model = Instance.new("Model")
	model.Name = info.displayName
	model:SetAttribute("Mutation", info.mutation or "")

	local body = newPart({
		Name = "Body", Size = Vector3.new(3, 3.4, 2.2) * s,
		Color = bodyColor, Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	body.Parent = model
	model.PrimaryPart = body

	local head = newPart({
		Name = "Head", Size = Vector3.new(2.4, 2.2, 2.4) * s,
		Color = bodyColor, Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	head.Parent = model

	-- Googly eyes: two white parts with black pupils.
	for _, offset in ipairs({ -0.6, 0.6 }) do
		local eye = newPart({
			Name = "Eye", Size = Vector3.new(0.8, 0.8, 0.3) * s,
			Color = Color3.new(1, 1, 1), CanCollide = false,
		})
		eye:SetAttribute("Offset", offset)
		eye.Parent = model
		local pupil = newPart({
			Name = "Pupil", Size = Vector3.new(0.4, 0.4, 0.15) * s,
			Color = Color3.new(0, 0, 0), CanCollide = false,
		})
		pupil:SetAttribute("Offset", offset)
		pupil.Parent = model
	end

	-- Stubby legs.
	for _, offset in ipairs({ -0.8, 0.8 }) do
		local leg = newPart({
			Name = "Leg", Size = Vector3.new(0.9, 1.4, 0.9) * s,
			Color = bodyColor, CanCollide = false,
		})
		leg:SetAttribute("Offset", offset)
		leg.Parent = model
	end

	-- Gold and Diamond get shiny materials; Rainbow gets recolored live later.
	if mutation then
		local material = (info.mutation == "Gold") and Enum.Material.Metal or Enum.Material.Glass
		body.Material = material
		head.Material = material
	end

	-- Everything is anchored and moved with PivotTo, so we just position
	-- each part relative to the body once, right here.
	local function place(part, relativeCFrame)
		part.CFrame = body.CFrame * relativeCFrame
	end
	body.CFrame = CFrame.new(0, 2.4 * s, 0)
	place(head, CFrame.new(0, 2.8 * s, 0))
	for _, part in ipairs(model:GetChildren()) do
		if part.Name == "Eye" then
			place(part, CFrame.new(part:GetAttribute("Offset") * s, 2.9 * s, -1.15 * s))
		elseif part.Name == "Pupil" then
			place(part, CFrame.new(part:GetAttribute("Offset") * s, 2.9 * s, -1.32 * s))
		elseif part.Name == "Leg" then
			place(part, CFrame.new(part:GetAttribute("Offset") * s, -2.4 * s, 0))
		end
	end

	-- Name tag + income tag.
	local secret = character.rarity == "Secret"
	local nameColor = mutation and mutation.color
		or (secret and Color3.fromRGB(255, 60, 220) or rarity.color)
	makeLabel(body, 4.2 * s + 1.4, info.displayName, nameColor, 20)
	makeLabel(body, 4.2 * s + 0.4, character.rarity .. "  |  " .. formatCash(info.income) .. "/s", rarity.color, 15)

	-- The scary-rare stuff gets a glowing outline so everyone panics.
	if secret or character.rarity == "Mythic" or character.rarity == "Brainrot God" or info.mutation == "Rainbow" then
		local glow = Instance.new("Highlight")
		glow.FillTransparency = 1
		glow.OutlineColor = nameColor
		glow.Parent = model
	end

	return model
end

-- The model's feet are 3.1 * scale below the body's center, so to stand a
-- brainrot on a surface we put its body this far above that surface.
local function bodyHeightAbove(surfaceY, character)
	return surfaceY + 3.1 * character.scale
end

-- Rainbow brainrots cycle through every color.
local function applyRainbow(model)
	local color = Color3.fromHSV(os.clock() * 0.4 % 1, 0.85, 1)
	for _, part in ipairs(model:GetChildren()) do
		if part.Name == "Body" or part.Name == "Head" or part.Name == "Leg" then
			part.Color = color
		end
	end
end

--==============================================================================
-- GAME STATE
--==============================================================================

local playerData = {}     -- [player] = { base = base, carrying = nil, lastSlap = 0 }
local conveyorItems = {}  -- array of { model, t, info, walkY, sold }
local carriedItems = {}   -- [model] = { thief, fromBase, fromSlot, info }

local function getCash(player)
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Cash")
end

local function addCash(player, amount)
	local cash = getCash(player)
	if cash then cash.Value += amount end
end

local function countBrainrots(base)
	local n = 0
	for _, slot in ipairs(base.slots) do
		if slot.brainrot then n += 1 end
	end
	return n
end

local function updateBrainrotStat(player)
	local data = playerData[player]
	local stats = player:FindFirstChild("leaderstats")
	local stat = stats and stats:FindFirstChild("Brainrots")
	if stat and data and data.base then
		stat.Value = countBrainrots(data.base)
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
-- PLACING A BRAINROT INTO A BASE (used by buying AND securing a steal)
--==============================================================================

local setupStealPrompt -- (defined below; declared here so placeBrainrot can use it)

local function placeBrainrot(base, slotIndex, model, info)
	local slot = base.slots[slotIndex]
	slot.brainrot = { model = model, info = info, pile = 0 }
	local pad = slot.pad
	local padTop = pad.Position.Y + pad.Size.Y / 2
	model:PivotTo(CFrame.new(pad.Position.X, bodyHeightAbove(padTop, info.character), pad.Position.Z)
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

local function dropCarried(thief, returnIt)
	local data = playerData[thief]
	if not data or not data.carrying then return end
	local model = data.carrying
	local info = carriedItems[model]
	setCarrying(thief, nil)
	carriedItems[model] = nil
	if not info then model:Destroy() return end

	if returnIt and info.fromBase.owner then
		-- Send it back to the base it was stolen from.
		local slotIndex = info.fromSlot
		if info.fromBase.slots[slotIndex].brainrot then
			slotIndex = findEmptySlot(info.fromBase)
		end
		if slotIndex then
			placeBrainrot(info.fromBase, slotIndex, model, info.info)
			return
		end
	end
	model:Destroy()
end

function setupStealPrompt(base, slotIndex, model, info)
	-- Remove any old prompt from a previous placement.
	local old = model.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
	if old then old:Destroy() end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Steal"
	prompt.ObjectText = info.displayName
	prompt.HoldDuration = 1.5
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
		carriedItems[model] = { thief = player, fromBase = base, fromSlot = slotIndex, info = info }
		announce(player.Name .. " is stealing " .. info.displayName .. "! GET THEM!", Color3.fromRGB(255, 120, 120))
	end)
end

--==============================================================================
-- CONVEYOR: spawning and buying
--==============================================================================

local function pickRandomCharacter()
	local totalWeight = 0
	for _, r in ipairs(RARITIES) do totalWeight += r.chance end
	local roll = rng:NextNumber(0, totalWeight)
	local chosenRarity = RARITIES[1].name
	for _, r in ipairs(RARITIES) do
		roll -= r.chance
		if roll <= 0 then chosenRarity = r.name break end
	end
	local pool = {}
	for _, c in ipairs(CHARACTERS) do
		if c.rarity == chosenRarity then table.insert(pool, c) end
	end
	return pool[rng:NextInteger(1, #pool)]
end

local function spawnOnConveyor()
	if #conveyorItems >= MAX_ON_CONVEYOR then return end
	local info = makeInfo(pickRandomCharacter(), rollMutation())
	local model = buildBrainrotModel(info)
	local walkY = bodyHeightAbove(BELT_TOP_Y, info.character)
	model:PivotTo(CFrame.new(CONVEYOR_START.X, walkY, CONVEYOR_START.Z) * CFrame.Angles(0, math.pi, 0))
	model.Parent = mapFolder

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Buy"
	prompt.ObjectText = info.displayName .. "  " .. formatCash(info.price)
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart

	local item = { model = model, t = 0, info = info, walkY = walkY, sold = false }
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
		placeBrainrot(data.base, slotIndex, model, info)
	end)

	local rarity = info.character.rarity
	if rarity == "Mythic" or rarity == "Brainrot God" or rarity == "Secret" or info.mutation == "Rainbow" then
		announce("A " .. (info.mutation and (info.mutation .. " ") or "") .. rarity .. " "
			.. info.character.name .. " is on the conveyor!!", rarityByName[rarity].color)
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
	handle.Size = Vector3.new(0.8, 4.5, 0.8)
	handle.Color = Color3.fromRGB(180, 120, 70)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
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
				-- Knock them back...
				local pushDirection = (vHrp.Position - hrp.Position).Unit
				local push = Instance.new("BodyVelocity")
				push.MaxForce = Vector3.new(1e5, 1e5, 1e5)
				push.Velocity = pushDirection * 60 + Vector3.new(0, 35, 0)
				push.Parent = vHrp
				Debris:AddItem(push, 0.2)
				-- ...and make them drop anything they stole.
				local vData = playerData[victim]
				if vData and vData.carrying then
					dropCarried(victim, true)
					announce(player.Name .. " slapped the brainrot out of " .. victim.Name .. "'s hands!",
						Color3.fromRGB(255, 220, 100))
				end
			end
		end
	end
end

--==============================================================================
-- BASE LOCK
--==============================================================================

local function setStealPromptsEnabled(base, enabled)
	for _, slot in ipairs(base.slots) do
		if slot.brainrot then
			local prompt = slot.brainrot.model.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
			if prompt then prompt.Enabled = enabled end
		end
	end
end

local function setupLock(base)
	base.lockPrompt.Triggered:Connect(function(player)
		if player ~= base.owner then return end
		if base.locked then return end
		local now = os.clock()
		if now < base.lockReadyAt then return end

		base.locked = true
		base.lockReadyAt = now + LOCK_DURATION + LOCK_COOLDOWN
		base.shield.Transparency = 0.5
		base.lockPrompt.Enabled = false
		setStealPromptsEnabled(base, false)

		task.delay(LOCK_DURATION, function()
			base.locked = false
			base.shield.Transparency = 1
			setStealPromptsEnabled(base, true)
			task.delay(LOCK_COOLDOWN, function()
				base.lockPrompt.Enabled = true
			end)
		end)
	end)
end

for _, base in ipairs(bases) do setupLock(base) end

--==============================================================================
-- SAVING (safe to leave on -- if saving isn't available it just skips)
--==============================================================================

local saveStore = nil
if SAVE_PROGRESS then
	pcall(function()
		saveStore = DataStoreService:GetDataStore("SnatchABrainrot_v1")
	end)
end

local function savePlayer(player)
	if not saveStore then return end
	local data = playerData[player]
	local cash = getCash(player)
	if not data or not cash then return end
	local owned = {}
	if data.base then
		for _, slot in ipairs(data.base.slots) do
			local entry = slot.brainrot
			if entry then
				table.insert(owned, { name = entry.info.character.name, mutation = entry.info.mutation })
			end
		end
	end
	pcall(function()
		saveStore:SetAsync("player_" .. player.UserId, { cash = cash.Value, owned = owned })
	end)
end

local function loadPlayer(player)
	if not saveStore then return nil end
	local result = nil
	pcall(function()
		result = saveStore:GetAsync("player_" .. player.UserId)
	end)
	return result
end

--==============================================================================
-- PLAYERS JOINING & LEAVING
--==============================================================================

local function claimBase(player)
	for _, base in ipairs(bases) do
		if not base.owner then
			base.owner = player
			base.signLabel.Text = player.DisplayName .. "'s Base"
			return base
		end
	end
	return nil
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

	local base = claimBase(player)
	playerData[player] = { base = base, carrying = nil, lastSlap = 0 }

	-- Restore save data.
	local saved = loadPlayer(player)
	if saved then
		cash.Value = saved.cash or STARTING_CASH
		if base and saved.owned then
			for _, savedEntry in ipairs(saved.owned) do
				-- Old saves stored plain names; new ones store name + mutation.
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
	end

	player.CharacterAdded:Connect(function(char)
		-- Hand them the bat every time they spawn.
		local bat = makeBat()
		bat.Activated:Connect(function() onBatActivated(player) end)
		bat.Parent = player:WaitForChild("Backpack")

		char:WaitForChild("Humanoid").Died:Connect(function()
			dropCarried(player, true) -- dying returns the stolen brainrot
		end)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	savePlayer(player)
	dropCarried(player, true)
	local data = playerData[player]
	if data and data.base then
		local base = data.base
		base.owner = nil
		base.signLabel.Text = "EMPTY BASE - JOIN TO CLAIM"
		for _, slot in ipairs(base.slots) do
			if slot.brainrot then
				slot.brainrot.model:Destroy()
				slot.brainrot = nil
			end
			slot.moneyLabel.Text = ""
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
-- your own base collects all your piles. Everyone also gets a small
-- passive income so new players can always afford something.
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local data = playerData[player]
			if data then
				addCash(player, PASSIVE_INCOME)
				local base = data.base
				if base then
					local home = isPlayerInBase(player, base)
					local collected = 0
					for _, slot in ipairs(base.slots) do
						local entry = slot.brainrot
						if entry then
							entry.pile += entry.info.income
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
					if collected > 0 then addCash(player, collected) end
				end
			end
		end
	end
end)

-- Movement: walk conveyor brainrots forward, float carried ones over
-- the thief's head, and secure steals when the thief reaches home.
local pathVector = CONVEYOR_END - CONVEYOR_START
local pathLength = pathVector.Magnitude

RunService.Heartbeat:Connect(function(dt)
	local clockNow = os.clock()

	-- Walking down the conveyor.
	for i = #conveyorItems, 1, -1 do
		local item = conveyorItems[i]
		item.t += (WALK_SPEED * dt) / pathLength
		if item.t >= 1 then
			table.remove(conveyorItems, i)
			item.model:Destroy()
		else
			local pos = CONVEYOR_START + pathVector * item.t
			local bob = math.sin(clockNow * 8 + i) * 0.4
			local wiggle = math.sin(clockNow * 6 + i * 2) * 0.15
			item.model:PivotTo(CFrame.new(pos.X, item.walkY + bob, pos.Z)
				* CFrame.Angles(0, math.pi + wiggle, 0))
			if item.info.mutation == "Rainbow" then
				applyRainbow(item.model)
			end
		end
	end

	-- Carried brainrots hover above the thief.
	for model, info in pairs(carriedItems) do
		local char = info.thief.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local bob = math.sin(clockNow * 5) * 0.3
			model:PivotTo(hrp.CFrame * CFrame.new(0, 4.5 + bob, 0) * CFrame.Angles(0, 0, math.rad(10)))

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

print("Snatch a Brainrot loaded! Have fun :)")
