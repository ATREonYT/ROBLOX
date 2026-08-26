--==============================================================================
-- PLUS ONE SPEED: CANDY KEYBOARD  (server script, 1 of 2)
--
-- Our faithful take on the "+1 Speed Keyboard Escape" formula: a candy &
-- chocolate world built out of giant mechanical keyboard keys that CLICK
-- and press down under your feet. Every step = +speed. Yellow WIN buttons
-- end each stage and send you home richer. Digit plates, treadmills,
-- trails, rebirths -- the whole loop.
--
-- HOW TO USE (TWO scripts this time -- the second one is the on-screen GUI):
--   1. Open Roblox Studio -> new "Baseplate" place
--   2. Explorer -> ServerScriptService -> + -> Script
--      Delete the default line, paste ALL of THIS file.
--   3. Explorer -> StarterPlayer -> StarterPlayerScripts -> + -> LocalScript
--      Delete the default line, paste ALL of PlusOneSpeed.client.lua.
--   4. Press Play. RUN.
--==============================================================================

--==============================================================================
-- CONFIG -- play with these numbers! Nothing here can break the game.
--==============================================================================

local STEP_LENGTH     = 3.5    -- studs of movement that count as one step
local BASE_WALKSPEED  = 16     -- Roblox default walk speed (speed adds to this)
local MAX_WALKSPEED   = 350    -- your legs' limit (the Speed NUMBER keeps growing)
local LEVEL_SIZE      = 10     -- 1 Level per this much Speed
local TREADMILL_RATE  = 2      -- automatic steps per second while on a treadmill
local BOOST_COST      = 2500   -- Wins price of a 10-minute x2 speed boost
local BOOST_LENGTH    = 600    -- boost duration in seconds
local FREE_REWARD     = 15000  -- one-time free Speed from the FREE! button
local GOLDEN_BONUS    = 25000  -- Wins from the Golden Brainrot at the very end
local GOLDEN_COOLDOWN = 180    -- seconds between Golden claims (per player)
local SAVE_PROGRESS   = true   -- saves everything (see README about saving)

-- DIGIT PLATES at spawn: each one permanently raises your speed-per-step.
-- You buy them in order; the newest plate's bonus replaces the previous.
local PLATES = {
	{ bonus = 1,   cost = 0 },      -- plate 1 is free!
	{ bonus = 2,   cost = 3 },
	{ bonus = 5,   cost = 15 },
	{ bonus = 10,  cost = 100 },
	{ bonus = 25,  cost = 1000 },
	{ bonus = 50,  cost = 10000 },
	{ bonus = 100, cost = 25000 },
	{ bonus = 500, cost = 50000 },
}

-- REBIRTHS: reset your Speed for a permanent multiplier (Wins, trails,
-- plates and treadmills all survive). This is the genre's proven curve.
local REBIRTHS = {
	{ level = 15,  mult = 1.5 }, { level = 25,  mult = 2 },
	{ level = 40,  mult = 2.5 }, { level = 60,  mult = 3 },
	{ level = 75,  mult = 3.5 }, { level = 100, mult = 4 },
	{ level = 125, mult = 5 },   { level = 150, mult = 6 },
	{ level = 175, mult = 7 },   { level = 200, mult = 8 },
	-- after this the game keeps going: +50 levels and +1x per tier
}

-- TRAIL SHOP: glowing trails that multiply every point of speed you gain.
-- color = nil means the trail cycles through every color (rainbow!).
local TRAILS = {
	{ name = "Green Trail",   cost = 500,      mult = 1.5, color = Color3.fromRGB(120, 220, 120) },
	{ name = "Blue Trail",    cost = 1500,     mult = 2,   color = Color3.fromRGB(100, 181, 246) },
	{ name = "Purple Trail",  cost = 5000,     mult = 3,   color = Color3.fromRGB(186, 104, 255) },
	{ name = "Red Trail",     cost = 25000,    mult = 4,   color = Color3.fromRGB(255, 90, 90) },
	{ name = "Rainbow Trail", cost = 100000,   mult = 5,   color = nil },
	{ name = "Comet Trail",   cost = 1000000,  mult = 10,  color = Color3.fromRGB(140, 240, 255) },
	{ name = "Void Trail",    cost = 10000000, mult = 25,  color = Color3.fromRGB(60, 20, 90) },
}

-- TREADMILLS: stand on one to bank steps while AFK. Higher tiers run faster.
local TREADMILLS = {
	{ name = "Chocolate Treadmill", cost = 0,       mult = 1, color = Color3.fromRGB(121, 85, 61) },
	{ name = "Golden Treadmill",    cost = 50000,   mult = 3, color = Color3.fromRGB(255, 200, 60) },
	{ name = "Diamond Treadmill",   cost = 1000000, mult = 9, color = Color3.fromRGB(140, 225, 255) },
}

-- THE STAGES. Every stage is giant keyboard keys with a candy theme, a
-- gimmick, and a yellow WIN button at the end that pays out and sends you
-- back to spawn (teleport back to your checkpoint from the Teleport menu!).
local STAGES = {
	{ name = "Gumdrop Gateway",    keys = 8,  gap = 3,   wins = 5,    recLevel = 1,   gimmick = "none",    phrase = "GUMDROP",     capColor = Color3.fromRGB(255, 170, 190), topColor = Color3.fromRGB(255, 215, 225) },
	{ name = "Candy Cane Crossing", keys = 10, gap = 3.5, wins = 12,  recLevel = 5,   gimmick = "zigzag",  phrase = "CANDYCANE",   capColor = Color3.fromRGB(255, 110, 110), topColor = Color3.fromRGB(255, 240, 240) },
	{ name = "Jawbreaker Alley",   keys = 11, gap = 3.5, wins = 30,   recLevel = 10,  gimmick = "ball",    phrase = "JAWBREAKER",  capColor = Color3.fromRGB(170, 140, 220), topColor = Color3.fromRGB(225, 210, 250) },
	{ name = "Choco Tsunami",      keys = 12, gap = 4,   wins = 75,   recLevel = 20,  gimmick = "wave",    phrase = "CHOCOWAVE",   capColor = Color3.fromRGB(140, 95, 65),  topColor = Color3.fromRGB(190, 145, 110) },
	{ name = "Marshmallow Hop",    keys = 10, gap = 6,   wins = 200,  recLevel = 35,  gimmick = "bouncy",  phrase = "MARSHMALLOW", capColor = Color3.fromRGB(245, 245, 250), topColor = Color3.fromRGB(255, 255, 255) },
	{ name = "Truffle Gates",      keys = 12, gap = 4,   wins = 500,  recLevel = 55,  gimmick = "gates",   phrase = "TRUFFLE",     capColor = Color3.fromRGB(110, 75, 55),  topColor = Color3.fromRGB(160, 120, 95) },
	{ name = "Sugar Sprint",       keys = 14, gap = 5.5, wins = 1500, recLevel = 80,  gimmick = "none",    phrase = "SUGARRUSH",   capColor = Color3.fromRGB(255, 225, 130), topColor = Color3.fromRGB(255, 245, 200) },
	{ name = "Gummy Guardian",     keys = 13, gap = 4,   wins = 5000, recLevel = 120, gimmick = "chasers", phrase = "GUMMYRUN",    capColor = Color3.fromRGB(120, 220, 140), topColor = Color3.fromRGB(190, 250, 200) },
}

local TELEPORT_COST_PER_STAGE = 2 -- Wins per stage number to teleport there

--==============================================================================
-- SERVICES & NETWORK (the GUI LocalScript talks to us through these)
--==============================================================================

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")
local Lighting          = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService  = game:GetService("DataStoreService")

local rng = Random.new()

local net = Instance.new("Folder")
net.Name = "PlusOneSpeedNet"
local stateRemote = Instance.new("RemoteEvent")
stateRemote.Name = "State"
stateRemote.Parent = net
local actionRemote = Instance.new("RemoteEvent")
actionRemote.Name = "Action"
actionRemote.Parent = net
net.Parent = ReplicatedStorage

local mapFolder = Instance.new("Folder")
mapFolder.Name = "KeyboardMap"
mapFolder.Parent = workspace

-- Clear out the template: its spawn, its giant baseplate (we float over a
-- desk instead -- and falling must actually FALL), and its post-effects.
for _, obj in ipairs(workspace:GetChildren()) do
	if obj:IsA("SpawnLocation") or (obj:IsA("BasePart") and obj.Name == "Baseplate") then
		obj:Destroy()
	end
end
for _, effect in ipairs(Lighting:GetChildren()) do
	if effect:IsA("PostEffect") or effect:IsA("Atmosphere") then
		effect:Destroy()
	end
end

--==============================================================================
-- PART & LABEL HELPERS (the same cartoony kit as our other games)
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

local function styleText(label, textSize, color)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextSize = textSize
	label.TextColor3 = color or Color3.new(1, 1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(60, 35, 30)
	stroke.Thickness = 2
	stroke.Parent = label
	return label
end

local function makeLabel(parent, offsetY, text, textColor, textSize, maxDistance)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 340, 0, 50)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = maxDistance or 200
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Text = text
	styleText(label, textSize or 24, textColor)
	label.Parent = gui
	gui.Parent = parent
	return gui, label
end

local function formatNum(n)
	if n >= 1e12 then return string.format("%.2fT", n / 1e12) end
	if n >= 1e9 then return string.format("%.2fB", n / 1e9) end
	if n >= 1e6 then return string.format("%.2fM", n / 1e6) end
	if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
	return tostring(math.floor(n))
end

local function worldPopup(position, text, color)
	local anchor = newPart({
		Name = "Popup", Size = Vector3.new(0.4, 0.4, 0.4), Transparency = 1,
		CanCollide = false, CanQuery = false,
		Position = position, Parent = mapFolder,
	})
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 220, 0, 44)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 140
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Text = text
	styleText(label, 28, color or Color3.fromRGB(140, 255, 140))
	label.Parent = gui
	gui.Parent = anchor
	task.spawn(function()
		for step = 1, 20 do
			task.wait(0.05)
			gui.StudsOffset = Vector3.new(0, step * 0.25, 0)
			label.TextTransparency = step / 20
		end
		anchor:Destroy()
	end)
	Debris:AddItem(anchor, 3)
end

local function announce(text, color)
	for _, player in ipairs(Players:GetPlayers()) do
		local gui = player:FindFirstChild("PlayerGui")
		if gui then
			local existing = 0
			for _, child in ipairs(gui:GetChildren()) do
				if child.Name == "KeyboardAnnouncement" then existing += 1 end
			end
			local screen = Instance.new("ScreenGui")
			screen.Name = "KeyboardAnnouncement"
			screen.ResetOnSpawn = false
			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(0.7, 0, 0, 40)
			label.Position = UDim2.new(0.15, 0, 0.08, existing * 46)
			label.BackgroundColor3 = Color3.fromRGB(62, 40, 34)
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
-- SWEET, CREAMY LIGHTING
--==============================================================================

Lighting.ClockTime = 13.5
Lighting.Brightness = 3
Lighting.Ambient = Color3.fromRGB(150, 145, 155)
Lighting.OutdoorAmbient = Color3.fromRGB(165, 158, 165)

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.7
bloom.Size = 30
bloom.Threshold = 1.05
bloom.Parent = Lighting

local colorPunch = Instance.new("ColorCorrectionEffect")
colorPunch.Saturation = 0.22
colorPunch.Contrast = 0.05
colorPunch.TintColor = Color3.fromRGB(255, 250, 242)
colorPunch.Parent = Lighting

local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.22
atmosphere.Offset = 0.5
atmosphere.Color = Color3.fromRGB(235, 225, 240)
atmosphere.Decay = Color3.fromRGB(255, 190, 170)
atmosphere.Glare = 0.15
atmosphere.Haze = 0.8
atmosphere.Parent = Lighting

--==============================================================================
-- KEYCAPS -- the star of the show. Every key has a pink under-skirt, a
-- chunky candy-colored cap, and a lighter top plate with a letter printed
-- on it. The top plate PRESSES DOWN with a click when you step on it.
--==============================================================================

local OBBY_Y = 6            -- the walking surface height of the whole obby
local KEY_SIZE = 8          -- keycap footprint (studs)
local keyGrid = {}          -- [cellKey] = { key, key, ... } for fast underfoot lookup
local CELL = 4

local function gridCell(x, z)
	return math.floor(x / CELL) .. ":" .. math.floor(z / CELL)
end

local function registerKey(key, x, z, half)
	for cx = math.floor((x - half) / CELL), math.floor((x + half) / CELL) do
		for cz = math.floor((z - half) / CELL), math.floor((z + half) / CELL) do
			local cell = cx .. ":" .. cz
			keyGrid[cell] = keyGrid[cell] or {}
			table.insert(keyGrid[cell], key)
		end
	end
end

-- Build one keycap whose TOP surface sits at surfaceY.
local function makeKeycap(x, z, surfaceY, capColor, topColor, letter, bouncy)
	newPart({
		Name = "KeySkirt", Size = Vector3.new(KEY_SIZE, 0.7, KEY_SIZE),
		Position = Vector3.new(x, surfaceY - 2.75, z),
		Color = Color3.fromRGB(255, 170, 200),
		Parent = mapFolder,
	})
	newPart({
		Name = "KeyBase", Size = Vector3.new(KEY_SIZE - 0.4, 2, KEY_SIZE - 0.4),
		Position = Vector3.new(x, surfaceY - 1.4, z),
		Color = capColor,
		Parent = mapFolder,
	})
	local top = newPart({
		Name = "KeyTop", Size = Vector3.new(KEY_SIZE - 1.4, 0.8, KEY_SIZE - 1.4),
		Position = Vector3.new(x, surfaceY - 0.4, z),
		Color = topColor,
		Parent = mapFolder,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Rotation = 180
	label.Text = letter or ""
	styleText(label, 100, Color3.fromRGB(120, 85, 90))
	label.TextScaled = true
	label.Parent = gui
	gui.Parent = top

	local key = {
		top = top, restCF = top.CFrame, x = x, z = z, surfaceY = surfaceY,
		pressGeneration = 0, sound = nil, bouncy = bouncy or false,
	}
	registerKey(key, x, z, KEY_SIZE / 2)
	return key
end

-- Press animation + the all-important click.
local function pressKey(key, playbackSpeed)
	key.pressGeneration += 1
	local generation = key.pressGeneration
	key.top.CFrame = key.restCF * CFrame.new(0, -0.35, 0)
	if not key.sound then
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxasset://sounds/clickfast.wav"
		sound.Volume = 0.5
		sound.RollOffMaxDistance = 70
		sound.Parent = key.top
		key.sound = sound
	end
	key.sound.PlaybackSpeed = playbackSpeed or 1
	key.sound:Play()
	task.delay(0.16, function()
		if key.pressGeneration == generation then
			key.top.CFrame = key.restCF
		end
	end)
end

local function keyUnderPosition(x, z)
	local bucket = keyGrid[gridCell(x, z)]
	if not bucket then return nil end
	for _, key in ipairs(bucket) do
		if math.abs(x - key.x) < KEY_SIZE / 2 + 0.4 and math.abs(z - key.z) < KEY_SIZE / 2 + 0.4 then
			return key
		end
	end
	return nil
end

--==============================================================================
-- THE DESK far below (what you see while you fall)
--==============================================================================

newPart({
	Name = "Desk", Size = Vector3.new(400, 4, 1800),
	Position = Vector3.new(0, -42, 700),
	Color = Color3.fromRGB(196, 148, 110), Material = Enum.Material.Wood,
	Parent = mapFolder,
})
newPart({
	Name = "DeskMat", Size = Vector3.new(220, 1, 1700),
	Position = Vector3.new(0, -39.5, 700),
	Color = Color3.fromRGB(150, 110, 220),
	Parent = mapFolder,
})
-- a giant mug of hot chocolate on the desk, because of course
tube("Y", 40, 44, Color3.fromRGB(255, 120, 150), {
	Name = "Mug", Position = Vector3.new(-130, -20, 240), Parent = mapFolder,
})
tube("Y", 3, 38, Color3.fromRGB(110, 70, 50), {
	Name = "Cocoa", Position = Vector3.new(-130, -1, 240), Parent = mapFolder,
})
tube("Z", 5, 16, Color3.fromRGB(255, 120, 150), {
	Name = "MugHandle", Position = Vector3.new(-152, -22, 240), Parent = mapFolder,
})
-- and a giant pencil
tube("Z", 160, 8, Color3.fromRGB(255, 200, 80), {
	Name = "Pencil", Position = Vector3.new(120, -36, 500), Parent = mapFolder,
})

--==============================================================================
-- THE LOBBY -- a floor of giant clicking keys, with everything around it
--==============================================================================

local LOBBY_PHRASE = "PLUSONESPEEDCANDYKEYBOARDRUNFASTCLICKCLACKZOOMSNACK"

-- Solid slab under the lobby keys so the cracks between them are safe.
newPart({
	Name = "LobbyBase", Size = Vector3.new(78, 1, 76),
	Position = Vector3.new(0, OBBY_Y - 3.35, -36),
	Color = Color3.fromRGB(120, 80, 60),
	Parent = mapFolder,
})

do
	local letterIndex = 0
	for col = -4, 4 do
		for row = 0, 8 do
			letterIndex += 1
			local letter = LOBBY_PHRASE:sub((letterIndex - 1) % #LOBBY_PHRASE + 1, (letterIndex - 1) % #LOBBY_PHRASE + 1)
			local shade = (col + row) % 2 == 0
			makeKeycap(col * 8.2, -69 + row * 8.2, OBBY_Y,
				shade and Color3.fromRGB(150, 100, 75) or Color3.fromRGB(255, 185, 205),
				shade and Color3.fromRGB(200, 150, 120) or Color3.fromRGB(255, 225, 235),
				letter)
		end
	end
end

local spawnPad = Instance.new("SpawnLocation")
spawnPad.Size = Vector3.new(10, 1, 10)
spawnPad.Position = Vector3.new(0, OBBY_Y + 0.5, -36)
spawnPad.Anchored = true
spawnPad.Neutral = true
spawnPad.Color = Color3.fromRGB(255, 255, 255)
spawnPad.Material = Enum.Material.SmoothPlastic
spawnPad.TopSurface = Enum.SurfaceType.Smooth
spawnPad.Duration = 0
spawnPad.Parent = mapFolder
local SPAWN_POS = Vector3.new(0, OBBY_Y + 4, -36)

local welcomeSign = newPart({
	Name = "WelcomeSign", Size = Vector3.new(0.5, 0.5, 0.5), Transparency = 1,
	CanCollide = false, CanQuery = false,
	Position = Vector3.new(0, OBBY_Y + 18, -36),
	Parent = mapFolder,
})
makeLabel(welcomeSign, 1.6, "PLUS ONE SPEED: CANDY KEYBOARD", Color3.fromRGB(255, 110, 180), 32, 500)
makeLabel(welcomeSign, -1, "Every step = +Speed! Follow the keys, smash the yellow WIN buttons!", Color3.fromRGB(255, 244, 220), 18, 400)

--==============================================================================
-- TREADMILLS (west side of the lobby)
--==============================================================================

local treadmillPads = {} -- [tier] = { pos, prompt or nil }
for tier, treadmill in ipairs(TREADMILLS) do
	local pos = Vector3.new(-32, OBBY_Y, -18 - (tier - 1) * 18)
	newPart({
		Name = "TreadmillFrame", Size = Vector3.new(10, 1, 15),
		Position = pos + Vector3.new(0, 0.2, 0),
		Color = Color3.fromRGB(70, 60, 65),
		Parent = mapFolder,
	})
	local belt = newPart({
		Name = "TreadmillBelt", Size = Vector3.new(8, 0.4, 13),
		Position = pos + Vector3.new(0, 0.9, 0),
		Color = treadmill.color,
		Parent = mapFolder,
	})
	for z = -5, 5, 2 do
		newPart({
			Name = "BeltStripe", Size = Vector3.new(7, 0.1, 0.7),
			Position = belt.Position + Vector3.new(0, 0.26, z),
			Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Neon,
			CanCollide = false, CanQuery = false,
			Parent = mapFolder,
		})
	end
	makeLabel(belt, 5, treadmill.name, treadmill.color, 20, 140)
	makeLabel(belt, 3.8, "x" .. treadmill.mult .. " AFK steps" .. (treadmill.cost > 0 and ("  |  " .. formatNum(treadmill.cost) .. " Wins") or "  |  FREE"),
		Color3.fromRGB(255, 244, 220), 14, 100)
	local entry = { pos = belt.Position, tier = tier }
	if treadmill.cost > 0 then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Buy"
		prompt.ObjectText = treadmill.name
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.Parent = belt
		entry.prompt = prompt
	end
	treadmillPads[tier] = entry
end

--==============================================================================
-- DIGIT PLATES (east side) -- giant numbered buttons, buy them in order
--==============================================================================

local plateParts = {} -- [index] = { part, prompt, costLabel }
for i, plate in ipairs(PLATES) do
	local pos = Vector3.new(32, OBBY_Y, -8 - (i - 1) * 8)
	local hue = 0.32 - (i - 1) * 0.04
	local button = newPart({
		Name = "DigitPlate" .. i, Size = Vector3.new(6.5, 1.6, 6.5),
		Position = pos + Vector3.new(0, 0.5, 0),
		Color = Color3.fromHSV(math.max(hue, 0), 0.55, 1),
		Parent = mapFolder,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	local digit = Instance.new("TextLabel")
	digit.Size = UDim2.new(1, 0, 1, 0)
	digit.Rotation = 180
	digit.Text = "+" .. plate.bonus
	styleText(digit, 100, Color3.fromRGB(70, 45, 55))
	digit.TextScaled = true
	digit.Parent = gui
	gui.Parent = button
	local _, costLabel = makeLabel(button, 3.2,
		plate.cost == 0 and "FREE - your first plate!" or (formatNum(plate.cost) .. " Wins"),
		Color3.fromRGB(255, 244, 220), 15, 90)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Buy"
	prompt.ObjectText = "+" .. plate.bonus .. " Speed per step"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Enabled = plate.cost > 0
	prompt.Parent = button
	plateParts[i] = { part = button, prompt = prompt, costLabel = costLabel }
end
local plateSign = newPart({
	Name = "PlateSign", Size = Vector3.new(0.5, 0.5, 0.5), Transparency = 1,
	CanCollide = false, CanQuery = false,
	Position = Vector3.new(32, OBBY_Y + 10, -36),
	Parent = mapFolder,
})
makeLabel(plateSign, 0, "DIGIT PLATES - permanently raise your Speed per step!", Color3.fromRGB(140, 255, 160), 20, 220)

--==============================================================================
-- SERVER LEADERBOARD BOARD (back of the lobby)
--==============================================================================

local board = newPart({
	Name = "Leaderboard", Size = Vector3.new(26, 14, 1.2),
	Position = Vector3.new(0, OBBY_Y + 8, -76),
	Color = Color3.fromRGB(62, 40, 34),
	Parent = mapFolder,
})
local boardGui = Instance.new("SurfaceGui")
boardGui.Face = Enum.NormalId.Front
local boardTitle = Instance.new("TextLabel")
boardTitle.Size = UDim2.new(1, 0, 0.2, 0)
boardTitle.Text = "FASTEST ON THE SERVER"
styleText(boardTitle, 60, Color3.fromRGB(255, 213, 79))
boardTitle.TextScaled = true
boardTitle.Parent = boardGui
local boardList = Instance.new("TextLabel")
boardList.Size = UDim2.new(1, -40, 0.75, 0)
boardList.Position = UDim2.new(0, 20, 0.22, 0)
boardList.Text = ""
styleText(boardList, 44, Color3.fromRGB(255, 244, 220))
boardList.TextYAlignment = Enum.TextYAlignment.Top
boardList.TextXAlignment = Enum.TextXAlignment.Left
boardList.Parent = boardGui
boardGui.Parent = board

--==============================================================================
-- TELEPORT PORTAL + STAGE-ONE ARCHWAY (front of the lobby)
--==============================================================================

for _, x in ipairs({ -8, 8 }) do
	tube("Y", 14, 2.2, Color3.fromRGB(255, 110, 180), {
		Name = "ArchPillar", Position = Vector3.new(x, OBBY_Y + 7, 2), Parent = mapFolder,
	})
	ball(Vector3.new(3, 3, 3), Color3.fromRGB(255, 160, 210), {
		Name = "ArchBall", Position = Vector3.new(x, OBBY_Y + 14.6, 2), Parent = mapFolder,
	})
end
local archTop = tube("X", 18, 2.2, Color3.fromRGB(255, 110, 180), {
	Name = "ArchTop", Position = Vector3.new(0, OBBY_Y + 14.6, 2), Parent = mapFolder,
})
makeLabel(archTop, 3, "STAGE 1: " .. STAGES[1].name .. "  -->", Color3.fromRGB(255, 244, 220), 22, 300)

local portalRing = tube("Z", 1.4, 12, Color3.fromRGB(140, 240, 255), {
	Name = "TeleportPortal", Material = Enum.Material.Neon,
	Position = Vector3.new(-24, OBBY_Y + 6.5, 0),
	Parent = mapFolder,
})
makeLabel(portalRing, 8, "TELEPORT", Color3.fromRGB(140, 240, 255), 22, 200)
makeLabel(portalRing, 6.6, "use the swirl button on your screen!", Color3.fromRGB(255, 244, 220), 14, 150)

--==============================================================================
-- STAGE CONSTRUCTION -- keys, safe zones, WIN buttons, and gimmicks
--==============================================================================

local SAFE_ZONES = {}    -- [i] = { pos, size } ; index 1 = lobby, i+1 = after stage i
local WIN_BUTTONS = {}   -- [i] = { pos, stage, reward, key }
local STAGE_STARTS = {}  -- [i] = position just before stage i begins
local gimmicks = {}      -- moving hazards, driven each Heartbeat
local chaserModels = {}  -- patrolling gummy blobs

table.insert(SAFE_ZONES, { pos = Vector3.new(0, OBBY_Y, -36), size = Vector3.new(78, 0, 76) })

-- A patrolling angry gummy blob.
local function buildChaser(color)
	local model = Instance.new("Model")
	model.Name = "Gummy Guard"
	local root = newPart({
		Name = "Root", Size = Vector3.new(0.4, 0.4, 0.4),
		Transparency = 1, CanCollide = false, CanQuery = false,
		Position = Vector3.new(0, 0.2, 0),
	})
	root.Parent = model
	model.PrimaryPart = root
	local body = ball(Vector3.new(3.6, 3.8, 3.2), color, { Name = "Body", Position = Vector3.new(0, 2.3, 0), Transparency = 0.15 })
	body.CanCollide = false
	body.Parent = model
	for _, x in ipairs({ -0.7, 0.7 }) do
		local eye = ball(Vector3.new(0.8, 0.8, 0.45), Color3.new(1, 1, 1), { Name = "Eye", Position = Vector3.new(x, 3.1, -1.35) })
		eye.CanCollide = false
		eye.Parent = model
		local pupil = ball(Vector3.new(0.4, 0.4, 0.25), Color3.new(0, 0, 0), { Name = "Pupil", Position = Vector3.new(x, 3.1, -1.55) })
		pupil.CanCollide = false
		pupil.Parent = model
		local brow = newPart({ Name = "Brow", Size = Vector3.new(0.95, 0.22, 0.2), Color = Color3.fromRGB(30, 60, 35) })
		brow.CFrame = CFrame.new(x, 3.7, -1.4) * CFrame.Angles(0, 0, math.rad(x < 0 and -20 or 20))
		brow.CanCollide = false
		brow.Parent = model
	end
	local mouth = ball(Vector3.new(1.2, 0.7, 0.3), Color3.fromRGB(40, 80, 45), { Name = "Mouth", Position = Vector3.new(0, 2.2, -1.5) })
	mouth.CanCollide = false
	mouth.Parent = model
	return model
end

local cursorZ = 12
local laneOffsets = { -7, 0, 7 }

for stageIndex, stage in ipairs(STAGES) do
	STAGE_STARTS[stageIndex] = Vector3.new(0, OBBY_Y + 4, cursorZ - 6)
	local lane = 2
	local stageStartZ = cursorZ

	for k = 1, stage.keys do
		if stage.gimmick == "zigzag" then
			lane = (k % 2 == 0) and 1 or 3 -- hard left-right weave
		else
			lane = math.clamp(lane + rng:NextInteger(-1, 1), 1, 3)
		end
		local x = laneOffsets[lane]
		local z = cursorZ + (k - 1) * (KEY_SIZE + stage.gap)
		local letter = stage.phrase:sub((k - 1) % #stage.phrase + 1, (k - 1) % #stage.phrase + 1)
		makeKeycap(x, z, OBBY_Y, stage.capColor, stage.topColor, letter, stage.gimmick == "bouncy")
	end

	local stageEndZ = cursorZ + (stage.keys - 1) * (KEY_SIZE + stage.gap)

	-- Gimmicks that live on this stage's stretch of keys.
	if stage.gimmick == "ball" then
		local jawbreaker = ball(Vector3.new(9, 9, 9), Color3.fromRGB(230, 220, 255), {
			Name = "Jawbreaker", Position = Vector3.new(0, OBBY_Y + 4.5, stageStartZ),
			Parent = mapFolder, CanCollide = false,
		})
		makeLabel(jawbreaker, 6, "JAWBREAKER!", Color3.fromRGB(200, 170, 255), 18, 160)
		table.insert(gimmicks, {
			type = "ball", part = jawbreaker, z0 = stageStartZ, z1 = stageEndZ,
			speed = 0.35, radius = 6,
		})
	elseif stage.gimmick == "wave" then
		local wave = newPart({
			Name = "ChocoWave", Size = Vector3.new(26, 16, 4),
			Position = Vector3.new(0, OBBY_Y + 8, stageEndZ),
			Color = Color3.fromRGB(110, 70, 50), Transparency = 0.25,
			CanCollide = false, Material = Enum.Material.SmoothPlastic,
			Parent = mapFolder,
		})
		makeLabel(wave, 9.5, "CHOCO TSUNAMI!", Color3.fromRGB(190, 145, 110), 20, 200)
		table.insert(gimmicks, {
			type = "wave", part = wave, z0 = stageStartZ - 6, z1 = stageEndZ + 6,
			period = 9, travelTime = 3.2,
		})
	elseif stage.gimmick == "gates" then
		for g = 1, 3 do
			local z = stageStartZ + (stageEndZ - stageStartZ) * (g / 4) + (KEY_SIZE + stage.gap) / 2
			local gate = newPart({
				Name = "TruffleGate", Size = Vector3.new(24, 11, 1.5),
				Position = Vector3.new(0, OBBY_Y + 5.5, z),
				Color = Color3.fromRGB(90, 55, 40), Transparency = 0.15,
				Parent = mapFolder,
			})
			makeLabel(gate, 6.6, "TIMED GATE", Color3.fromRGB(255, 200, 140), 16, 120)
			table.insert(gimmicks, {
				type = "gate", part = gate, openTime = 2.6, closedTime = 2, offset = g * 1.6,
			})
		end
	elseif stage.gimmick == "chasers" then
		for c = 1, 2 do
			local chaser = buildChaser(Color3.fromRGB(110, 220, 130))
			chaser.Parent = mapFolder
			local z = stageStartZ + (stageEndZ - stageStartZ) * (c / 3)
			table.insert(chaserModels, {
				model = chaser, center = 0, range = 12, z = z,
				speed = 1 + 0.3 * c, phase = c * 2.3,
			})
		end
	end

	-- SAFE ZONE + the yellow WIN button.
	local zoneZ = stageEndZ + stage.gap + KEY_SIZE / 2 + 12
	newPart({
		Name = "SafeZone" .. stageIndex, Size = Vector3.new(36, 1.2, 24),
		Position = Vector3.new(0, OBBY_Y - 0.6, zoneZ),
		Color = Color3.fromRGB(255, 236, 200),
		Parent = mapFolder,
	})
	newPart({
		Name = "SafeZoneTrim", Size = Vector3.new(39, 0.8, 27),
		Position = Vector3.new(0, OBBY_Y - 1.2, zoneZ),
		Color = Color3.fromRGB(255, 150, 200),
		Parent = mapFolder,
	})

	-- The WIN button is itself a giant golden keycap that presses down.
	local winKey = makeKeycap(0, zoneZ, OBBY_Y + 0.4, Color3.fromRGB(255, 190, 40), Color3.fromRGB(255, 230, 90), "WIN")
	makeLabel(winKey.top, 3.4, "+" .. formatNum(stage.wins) .. " WINS", Color3.fromRGB(255, 230, 60), 24, 200)
	table.insert(WIN_BUTTONS, { pos = Vector3.new(0, OBBY_Y, zoneZ), stage = stageIndex, reward = stage.wins, key = winKey })
	table.insert(SAFE_ZONES, { pos = Vector3.new(0, OBBY_Y, zoneZ), size = Vector3.new(36, 0, 24) })

	local signPost = tube("Y", 5, 0.8, Color3.fromRGB(255, 200, 80), {
		Name = "StageSign", Position = Vector3.new(14, OBBY_Y + 2.5, zoneZ + 6), Parent = mapFolder,
	})
	if stageIndex < #STAGES then
		makeLabel(signPost, 4.6, "NEXT: " .. STAGES[stageIndex + 1].name, Color3.fromRGB(255, 244, 220), 18, 200)
		makeLabel(signPost, 3.4, "recommended Level " .. STAGES[stageIndex + 1].recLevel, Color3.fromRGB(255, 213, 79), 14, 150)
	else
		makeLabel(signPost, 4.6, "THE GOLDEN BRAINROT AWAITS...", Color3.fromRGB(255, 220, 90), 18, 200)
	end

	cursorZ = zoneZ + 12 + 10
end

--==============================================================================
-- THE GOLDEN BRAINROT + the locked World 2 gate
--==============================================================================

local goldenZ = cursorZ + 8
newPart({
	Name = "GoldenPlatform", Size = Vector3.new(46, 1.2, 42),
	Position = Vector3.new(0, OBBY_Y - 0.6, goldenZ),
	Color = Color3.fromRGB(255, 236, 170),
	Parent = mapFolder,
})
tube("Y", 2, 10, Color3.fromRGB(255, 255, 255), {
	Name = "GoldenPedestal", Position = Vector3.new(0, OBBY_Y + 1, goldenZ + 10), Parent = mapFolder,
})
local golden = ball(Vector3.new(5, 5.4, 4.6), Color3.fromRGB(255, 200, 60), {
	Name = "GoldenBrainrot", Material = Enum.Material.Metal,
	Position = Vector3.new(0, OBBY_Y + 4.8, goldenZ + 10),
	Parent = mapFolder,
})
for _, x in ipairs({ -1, 1 }) do
	ball(Vector3.new(1.1, 1.1, 0.6), Color3.new(1, 1, 1), {
		Name = "GoldenEye", Position = golden.Position + Vector3.new(x, 0.9, -2.1), Parent = mapFolder,
	})
	ball(Vector3.new(0.5, 0.5, 0.3), Color3.new(0, 0, 0), {
		Name = "GoldenPupil", Position = golden.Position + Vector3.new(x, 0.9, -2.35), Parent = mapFolder,
	})
end
makeLabel(golden, 4.6, "THE GOLDEN BRAINROT", Color3.fromRGB(255, 220, 90), 24, 300)
makeLabel(golden, 3.4, "+" .. formatNum(GOLDEN_BONUS) .. " Wins, every " .. math.floor(GOLDEN_COOLDOWN / 60) .. " min!", Color3.fromRGB(255, 244, 220), 15, 200)
local goldenGlow = Instance.new("Highlight")
goldenGlow.FillTransparency = 1
goldenGlow.OutlineColor = Color3.fromRGB(255, 220, 90)
goldenGlow.Parent = golden

local goldenPrompt = Instance.new("ProximityPrompt")
goldenPrompt.ActionText = "Claim"
goldenPrompt.ObjectText = "Golden Brainrot"
goldenPrompt.HoldDuration = 0.3
goldenPrompt.MaxActivationDistance = 10
goldenPrompt.RequiresLineOfSight = false
goldenPrompt.Parent = golden

table.insert(SAFE_ZONES, { pos = Vector3.new(0, OBBY_Y, goldenZ), size = Vector3.new(46, 0, 42) })

-- World 2: a locked candy gate, waiting for us to mod it in.
local gateZ = goldenZ + 26
for _, x in ipairs({ -10, 10 }) do
	tube("Y", 18, 3, Color3.fromRGB(190, 120, 220), {
		Name = "W2Pillar", Position = Vector3.new(x, OBBY_Y + 9, gateZ), Parent = mapFolder,
	})
end
local w2gate = newPart({
	Name = "World2Gate", Size = Vector3.new(17, 15, 1.6),
	Position = Vector3.new(0, OBBY_Y + 7.5, gateZ),
	Color = Color3.fromRGB(120, 60, 150), Transparency = 0.2,
	Parent = mapFolder,
})
makeLabel(w2gate, 9.4, "WORLD 2", Color3.fromRGB(220, 160, 255), 28, 300)
makeLabel(w2gate, 8, "Level 120+  |  coming soon (we'll build it together!)", Color3.fromRGB(255, 244, 220), 15, 250)

--==============================================================================
-- GAME STATE & MATH
--==============================================================================

local playerData = {} -- [player] = full per-player state (see PlayerAdded)

local function getStat(player, name)
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild(name)
end

local function rebirthMult(rebirths)
	if rebirths <= 0 then return 1 end
	if rebirths <= #REBIRTHS then return REBIRTHS[rebirths].mult end
	return REBIRTHS[#REBIRTHS].mult + (rebirths - #REBIRTHS)
end

local function nextRebirthInfo(rebirths)
	local tier = rebirths + 1
	if tier <= #REBIRTHS then
		return REBIRTHS[tier].level, REBIRTHS[tier].mult
	end
	local last = REBIRTHS[#REBIRTHS]
	local extra = tier - #REBIRTHS
	return last.level + extra * 50, last.mult + extra
end

local function trailMult(data)
	if data.trailIndex > 0 then return TRAILS[data.trailIndex].mult end
	return 1
end

local function stepValue(data)
	local boost = (os.clock() < data.boostUntil) and 2 or 1
	return (1 + PLATES[data.plateIndex].bonus) * rebirthMult(data.rebirths) * trailMult(data) * boost
end

local function playerLevel(data)
	return math.floor(data.speed / LEVEL_SIZE)
end

--==============================================================================
-- SPEED, TRAILS, OVERHEAD TAGS
--==============================================================================

local function applySpeed(player)
	local data = playerData[player]
	if not data then return end
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = math.min(BASE_WALKSPEED + math.floor(data.speed), MAX_WALKSPEED)
	end
	local stat = getStat(player, "Speed")
	if stat then stat.Value = math.floor(data.speed) end
end

local function setupCharacterExtras(player, char)
	local hrp = char:WaitForChild("HumanoidRootPart", 10)
	if not hrp then return end
	local data = playerData[player]
	if not data then return end

	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 1, 0)
	a0.Parent = hrp
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -1, 0)
	a1.Parent = hrp
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.4
	trail.MinLength = 0.1
	trail.FaceCamera = true
	trail.LightEmission = 0.6
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Enabled = false
	trail.Parent = hrp
	data.trail = trail

	local head = char:FindFirstChild("Head") or hrp
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 220, 0, 34)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 250
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Text = ""
	styleText(label, 20, Color3.fromRGB(255, 213, 79))
	label.Parent = gui
	gui.Parent = head
	data.overheadLabel = label

	data.lastPos = nil
	data.lastKey = nil
end

local function updateTrail(player)
	local data = playerData[player]
	local trail = data and data.trail
	if not trail or not trail.Parent then return end
	if data.trailIndex == 0 then
		trail.Enabled = false
		return
	end
	trail.Enabled = true
	local color = TRAILS[data.trailIndex].color
	if not color then
		color = Color3.fromHSV(os.clock() * 0.5 % 1, 0.8, 1)
	end
	trail.Color = ColorSequence.new(color)
end

--==============================================================================
-- NETWORK: snapshots to the GUI LocalScript
--==============================================================================

local function snapshot(player)
	local data = playerData[player]
	local wins = getStat(player, "Wins")
	if not data then return nil end
	local nextLevel, nextMult = nextRebirthInfo(data.rebirths)
	return {
		speed = math.floor(data.speed),
		wins = wins and wins.Value or 0,
		level = playerLevel(data),
		rebirths = data.rebirths,
		curMult = rebirthMult(data.rebirths),
		nextRebirthLevel = nextLevel,
		nextRebirthMult = nextMult,
		trailIndex = data.trailIndex,
		plateIndex = data.plateIndex,
		treadmillTier = data.treadmillTier,
		boostRemaining = math.max(0, math.floor(data.boostUntil - os.clock())),
		checkpointMax = data.checkpointMax,
		stepValue = stepValue(data),
		freeClaimed = data.freeClaimed,
	}
end

local function pushState(player)
	local snap = snapshot(player)
	if snap then
		stateRemote:FireClient(player, "state", snap)
	end
end

local function sendInit(player)
	local trails = {}
	for i, trail in ipairs(TRAILS) do
		trails[i] = { name = trail.name, cost = trail.cost, mult = trail.mult, color = trail.color }
	end
	local plates = {}
	for i, plate in ipairs(PLATES) do
		plates[i] = { bonus = plate.bonus, cost = plate.cost }
	end
	local treadmills = {}
	for i, treadmill in ipairs(TREADMILLS) do
		treadmills[i] = { name = treadmill.name, cost = treadmill.cost, mult = treadmill.mult }
	end
	local stages = {}
	for i, stage in ipairs(STAGES) do
		stages[i] = { name = stage.name, wins = stage.wins, recLevel = stage.recLevel }
	end
	stateRemote:FireClient(player, "init", {
		trails = trails, plates = plates, treadmills = treadmills, stages = stages,
		teleportCostPerStage = TELEPORT_COST_PER_STAGE,
		boostCost = BOOST_COST, boostLength = BOOST_LENGTH, freeReward = FREE_REWARD,
	})
end

--==============================================================================
-- SAVING (same battle-tested guards as our other games)
--==============================================================================

local saveStore = nil
if SAVE_PROGRESS then
	pcall(function()
		saveStore = DataStoreService:GetDataStore("CandyKeyboard_v1")
	end)
end

local alreadySaved = {}

local function savePlayer(player)
	if not saveStore then return end
	if alreadySaved[player] then return end
	local data = playerData[player]
	local wins = getStat(player, "Wins")
	if not data or not wins then return end
	if not data.loaded or data.loadFailed then return end
	local ok = pcall(function()
		saveStore:SetAsync("player_" .. player.UserId, {
			speed = data.speed, wins = wins.Value, rebirths = data.rebirths,
			trailIndex = data.trailIndex, plateIndex = data.plateIndex,
			treadmillTier = data.treadmillTier, freeClaimed = data.freeClaimed,
			checkpointMax = data.checkpointMax,
		})
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

Players.PlayerAdded:Connect(function(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in ipairs({ "Speed", "Wins", "Rebirths" }) do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Value = 0
		value.Parent = stats
	end
	stats.Parent = player

	playerData[player] = {
		speed = 0, rebirths = 0, trailIndex = 0, plateIndex = 1,
		treadmillTier = 1, boostUntil = 0, checkpointMax = 0,
		distAcc = 0, lastPos = nil, lastKey = nil, lastKeyAt = 0,
		onWinButton = false, goldenAt = 0, lastHit = 0, freeClaimed = false,
		loaded = false, loadFailed = false,
	}

	local function onCharacter(char)
		setupCharacterExtras(player, char)
		applySpeed(player)
		updateTrail(player)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then task.spawn(onCharacter, player.Character) end

	local data = playerData[player]
	local ok, saved = loadPlayer(player)
	if player.Parent ~= Players or playerData[player] ~= data then return end
	if not ok then
		data.loadFailed = true
		announce(player.Name .. "'s save couldn't load - progress won't overwrite it this visit.", Color3.fromRGB(255, 200, 140))
	else
		data.loaded = true
		if saved then
			data.speed = math.max(saved.speed or 0, 0)
			data.rebirths = saved.rebirths or 0
			data.trailIndex = math.clamp(saved.trailIndex or 0, 0, #TRAILS)
			data.plateIndex = math.clamp(saved.plateIndex or 1, 1, #PLATES)
			data.treadmillTier = math.clamp(saved.treadmillTier or 1, 1, #TREADMILLS)
			data.freeClaimed = saved.freeClaimed or false
			data.checkpointMax = math.clamp(saved.checkpointMax or 0, 0, #STAGES)
			local wins = getStat(player, "Wins")
			if wins then wins.Value = saved.wins or 0 end
			local rebirthStat = getStat(player, "Rebirths")
			if rebirthStat then rebirthStat.Value = data.rebirths end
			applySpeed(player)
			updateTrail(player)
		end
	end
	sendInit(player)
	pushState(player)
end)

Players.PlayerRemoving:Connect(function(player)
	savePlayer(player)
	playerData[player] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayer(player)
	end
end)

--==============================================================================
-- PURCHASES: digit plates, treadmills, the Golden Brainrot
--==============================================================================

local function hrpOf(player)
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

for i, plate in ipairs(plateParts) do
	plate.prompt.Triggered:Connect(function(player)
		local data = playerData[player]
		local wins = getStat(player, "Wins")
		if not data or not wins then return end
		local hrp = hrpOf(player)
		if data.plateIndex >= i then
			if hrp then worldPopup(hrp.Position + Vector3.new(0, 4, 0), "Already owned!", Color3.fromRGB(255, 220, 140)) end
			return
		end
		if data.plateIndex ~= i - 1 then
			if hrp then worldPopup(hrp.Position + Vector3.new(0, 4, 0), "Buy plate " .. (data.plateIndex + 1) .. " first!", Color3.fromRGB(255, 180, 180)) end
			return
		end
		if wins.Value < PLATES[i].cost then
			if hrp then worldPopup(hrp.Position + Vector3.new(0, 4, 0), "Need " .. formatNum(PLATES[i].cost) .. " Wins!", Color3.fromRGB(255, 180, 180)) end
			return
		end
		wins.Value -= PLATES[i].cost
		data.plateIndex = i
		if hrp then worldPopup(hrp.Position + Vector3.new(0, 4, 0), "+" .. PLATES[i].bonus .. " per step!", Color3.fromRGB(140, 255, 160)) end
		if i == #PLATES then
			announce(player.Name .. " bought the FINAL digit plate! +" .. PLATES[i].bonus .. " per step!", Color3.fromRGB(140, 255, 160))
		end
		pushState(player)
	end)
end

for tier, pad in ipairs(treadmillPads) do
	if pad.prompt then
		pad.prompt.Triggered:Connect(function(player)
			local data = playerData[player]
			local wins = getStat(player, "Wins")
			if not data or not wins then return end
			local hrp = hrpOf(player)
			if data.treadmillTier >= tier then
				if hrp then worldPopup(hrp.Position + Vector3.new(0, 4, 0), "Already owned!", Color3.fromRGB(255, 220, 140)) end
				return
			end
			if wins.Value < TREADMILLS[tier].cost then
				if hrp then worldPopup(hrp.Position + Vector3.new(0, 4, 0), "Need " .. formatNum(TREADMILLS[tier].cost) .. " Wins!", Color3.fromRGB(255, 180, 180)) end
				return
			end
			wins.Value -= TREADMILLS[tier].cost
			data.treadmillTier = tier
			if hrp then worldPopup(hrp.Position + Vector3.new(0, 4, 0), TREADMILLS[tier].name .. "!", Color3.fromRGB(255, 220, 90)) end
			pushState(player)
		end)
	end
end

goldenPrompt.Triggered:Connect(function(player)
	local data = playerData[player]
	local wins = getStat(player, "Wins")
	if not data or not wins then return end
	local now = os.clock()
	local hrp = hrpOf(player)
	if now - data.goldenAt < GOLDEN_COOLDOWN then
		local waitMin = math.ceil((GOLDEN_COOLDOWN - (now - data.goldenAt)) / 60)
		if hrp then worldPopup(hrp.Position + Vector3.new(0, 4, 0), "Come back in ~" .. waitMin .. " min!", Color3.fromRGB(255, 220, 140)) end
		return
	end
	data.goldenAt = now
	wins.Value += GOLDEN_BONUS
	if hrp then worldPopup(hrp.Position + Vector3.new(0, 5, 0), "+" .. formatNum(GOLDEN_BONUS) .. " WINS!", Color3.fromRGB(255, 230, 60)) end
	announce(player.Name .. " reached the GOLDEN BRAINROT! +" .. formatNum(GOLDEN_BONUS) .. " Wins!", Color3.fromRGB(255, 220, 90))
	pushState(player)
end)

--==============================================================================
-- GUI ACTIONS (rebirth, trails, teleport, boost, free reward)
--==============================================================================

actionRemote.OnServerEvent:Connect(function(player, action)
	if type(action) ~= "table" then return end
	local data = playerData[player]
	local wins = getStat(player, "Wins")
	if not data or not wins then return end
	local hrp = hrpOf(player)

	if action.t == "rebirth" then
		local neededLevel = nextRebirthInfo(data.rebirths)
		if playerLevel(data) < neededLevel then return end
		data.rebirths += 1
		data.speed = 0
		data.distAcc = 0
		applySpeed(player)
		local rebirthStat = getStat(player, "Rebirths")
		if rebirthStat then rebirthStat.Value = data.rebirths end
		if hrp then worldPopup(hrp.Position + Vector3.new(0, 4, 0), "REBIRTH " .. data.rebirths .. "!", Color3.fromRGB(255, 160, 220)) end
		announce(player.Name .. " rebirthed! Permanent x" .. rebirthMult(data.rebirths) .. " speed gain!", Color3.fromRGB(255, 160, 220))

	elseif action.t == "buyTrail" then
		local i = tonumber(action.i)
		if not i or not TRAILS[i] then return end
		if data.trailIndex >= i then return end
		if i ~= data.trailIndex + 1 then return end -- buy them in order
		if wins.Value < TRAILS[i].cost then return end
		wins.Value -= TRAILS[i].cost
		data.trailIndex = i
		updateTrail(player)
		if hrp then worldPopup(hrp.Position + Vector3.new(0, 4, 0), TRAILS[i].name .. "!", TRAILS[i].color or Color3.fromRGB(255, 120, 255)) end
		if i >= 5 then
			announce(player.Name .. " unlocked the " .. TRAILS[i].name .. "! (x" .. TRAILS[i].mult .. " speed gain)", TRAILS[i].color or Color3.fromRGB(255, 120, 255))
		end

	elseif action.t == "teleport" then
		local stage = tonumber(action.stage)
		if not stage or stage < 1 or stage > #STAGES then return end
		if stage > data.checkpointMax + 1 then return end -- only stages you've reached
		local cost = stage * TELEPORT_COST_PER_STAGE
		if wins.Value < cost then return end
		local char = player.Character
		if not char then return end
		wins.Value -= cost
		char:PivotTo(CFrame.new(STAGE_STARTS[stage]))
		local newHrp = hrpOf(player)
		if newHrp then newHrp.AssemblyLinearVelocity = Vector3.zero end
		data.lastPos = nil

	elseif action.t == "boost" then
		if os.clock() < data.boostUntil then return end
		if wins.Value < BOOST_COST then return end
		wins.Value -= BOOST_COST
		data.boostUntil = os.clock() + BOOST_LENGTH
		if hrp then worldPopup(hrp.Position + Vector3.new(0, 4, 0), "x2 SPEED BOOST!", Color3.fromRGB(255, 230, 60)) end

	elseif action.t == "free" then
		if data.freeClaimed then return end
		data.freeClaimed = true
		data.speed += FREE_REWARD
		applySpeed(player)
		if hrp then worldPopup(hrp.Position + Vector3.new(0, 4, 0), "+" .. formatNum(FREE_REWARD) .. " SPEED!", Color3.fromRGB(140, 255, 160)) end
	end
	pushState(player)
end)

--==============================================================================
-- ONCE-A-SECOND LOOP: treadmills, tags, trails, leaderboard, state pushes
--==============================================================================

task.spawn(function()
	local boardTick = 0
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local data = playerData[player]
			if data then
				local hrp = hrpOf(player)
				if hrp then
					for tier, pad in ipairs(treadmillPads) do
						local offset = hrp.Position - pad.pos
						if math.abs(offset.X) < 4.5 and math.abs(offset.Z) < 7 and math.abs(offset.Y) < 7 then
							if data.treadmillTier >= tier then
								data.speed += TREADMILL_RATE * TREADMILLS[tier].mult * stepValue(data)
								applySpeed(player)
							end
							break
						end
					end
				end
				if data.overheadLabel and data.overheadLabel.Parent then
					data.overheadLabel.Text = formatNum(data.speed) .. " SPEED  |  Lv " .. playerLevel(data)
						.. (data.rebirths > 0 and ("  |  R" .. data.rebirths) or "")
				end
				updateTrail(player)
				pushState(player)
			end
		end
		boardTick += 1
		if boardTick >= 5 then
			boardTick = 0
			local ranked = {}
			for _, player in ipairs(Players:GetPlayers()) do
				local data = playerData[player]
				if data then table.insert(ranked, { name = player.DisplayName, speed = data.speed }) end
			end
			table.sort(ranked, function(a, b) return a.speed > b.speed end)
			local lines = {}
			for i = 1, math.min(5, #ranked) do
				table.insert(lines, i .. ".  " .. ranked[i].name .. "  -  " .. formatNum(ranked[i].speed))
			end
			boardList.Text = table.concat(lines, "\n")
		end
	end
end)

--==============================================================================
-- EVERY-FRAME LOOP: steps, key clicks, falls, win buttons, hazards
--==============================================================================

RunService.Heartbeat:Connect(function(dt)
	local clockNow = os.clock()

	-- Gimmicks move first.
	for _, gimmick in ipairs(gimmicks) do
		if gimmick.type == "ball" then
			local travel = 0.5 + 0.5 * math.sin(clockNow * gimmick.speed * 2)
			local z = gimmick.z0 + (gimmick.z1 - gimmick.z0) * travel
			local roll = z / gimmick.radius
			gimmick.part.CFrame = CFrame.new(0, OBBY_Y + gimmick.radius - 1.5, z) * CFrame.Angles(roll, 0, 0)
			gimmick.z = z
		elseif gimmick.type == "wave" then
			local cycle = clockNow % gimmick.period
			if cycle < gimmick.travelTime then
				local z = gimmick.z1 - (gimmick.z1 - gimmick.z0) * (cycle / gimmick.travelTime)
				gimmick.part.Position = Vector3.new(0, OBBY_Y + 8, z)
				gimmick.part.Transparency = 0.25
				gimmick.active = true
				gimmick.z = z
			else
				gimmick.part.Transparency = 0.92
				gimmick.active = false
			end
		elseif gimmick.type == "gate" then
			local cycle = (clockNow + gimmick.offset) % (gimmick.openTime + gimmick.closedTime)
			local closed = cycle < gimmick.closedTime
			gimmick.part.CanCollide = closed
			gimmick.part.Transparency = closed and 0.15 or 0.85
		end
	end

	for i, chaser in ipairs(chaserModels) do
		local x = chaser.center + math.sin(clockNow * chaser.speed + chaser.phase) * chaser.range
		local nextX = chaser.center + math.sin(clockNow * chaser.speed + chaser.phase + 0.05) * chaser.range
		local hop = math.abs(math.sin(clockNow * 7 + i)) * 0.5
		chaser.model:PivotTo(CFrame.lookAt(
			Vector3.new(x, OBBY_Y + hop, chaser.z),
			Vector3.new(nextX >= x and nextX + 0.1 or nextX - 0.1, OBBY_Y + hop, chaser.z)))
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local data = playerData[player]
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if data and hrp then
			local pos = hrp.Position

			-- STEP COUNTING (yes, this is the entire heart of the game).
			if data.lastPos then
				local delta = Vector3.new(pos.X - data.lastPos.X, 0, pos.Z - data.lastPos.Z).Magnitude
				if delta < 30 then
					data.distAcc += delta
					if data.distAcc >= STEP_LENGTH then
						local steps = math.floor(data.distAcc / STEP_LENGTH)
						data.distAcc -= steps * STEP_LENGTH
						data.speed += steps * stepValue(data)
						applySpeed(player)
					end
				end
			end
			data.lastPos = pos

			-- KEY PRESSES: click the key under your feet.
			local key = keyUnderPosition(pos.X, pos.Z)
			if key and math.abs((pos.Y - 3) - key.surfaceY) < 4 then
				if key ~= data.lastKey or clockNow - data.lastKeyAt > 0.25 then
					data.lastKey = key
					data.lastKeyAt = clockNow
					pressKey(key, 0.9 + math.min(data.speed, 2000) / 3000 + rng:NextNumber(0, 0.15))
					if key.bouncy then
						local velocity = hrp.AssemblyLinearVelocity
						hrp.AssemblyLinearVelocity = Vector3.new(velocity.X, 85, velocity.Z)
					end
				end
			elseif not key then
				data.lastKey = nil
			end

			-- FALLING: the classic hard reset back to spawn.
			if pos.Y < -12 then
				char:PivotTo(CFrame.new(SPAWN_POS))
				hrp.AssemblyLinearVelocity = Vector3.zero
				data.lastPos = nil
				stateRemote:FireClient(player, "fell")
			end

			-- SAFE ZONES: remember the furthest stage you've completed.
			for zoneIndex, zone in ipairs(SAFE_ZONES) do
				local offset = pos - zone.pos
				if math.abs(offset.X) < zone.size.X / 2 and math.abs(offset.Z) < zone.size.Z / 2
					and offset.Y > -2 and offset.Y < 14 then
					local completedStage = zoneIndex - 1
					if completedStage > data.checkpointMax and completedStage <= #STAGES then
						data.checkpointMax = completedStage
						pushState(player)
					end
				end
			end

			-- WIN BUTTONS: pay on ENTRY, then whoosh back to spawn.
			local onButton = false
			for _, button in ipairs(WIN_BUTTONS) do
				local offset = pos - button.pos
				if math.abs(offset.X) < 4.5 and math.abs(offset.Z) < 4.5 and offset.Y > -2 and offset.Y < 12 then
					onButton = true
					if not data.onWinButton then
						local wins = getStat(player, "Wins")
						if wins then wins.Value += button.reward end
						pressKey(button.key, 0.7)
						worldPopup(pos + Vector3.new(0, 5, 0), "+" .. formatNum(button.reward) .. " WINS!", Color3.fromRGB(255, 230, 60))
						stateRemote:FireClient(player, "win", button.stage, button.reward)
						pushState(player)
						local victoryStage = button.stage
						task.delay(1.2, function()
							local currentChar = player.Character
							local currentHrp = currentChar and currentChar:FindFirstChild("HumanoidRootPart")
							if currentHrp and playerData[player] then
								currentChar:PivotTo(CFrame.new(SPAWN_POS))
								currentHrp.AssemblyLinearVelocity = Vector3.zero
								playerData[player].lastPos = nil
							end
						end)
						if victoryStage == #STAGES then
							announce(player.Name .. " beat " .. STAGES[#STAGES].name .. "! +" .. formatNum(button.reward) .. " Wins!", Color3.fromRGB(140, 255, 160))
						end
					end
					break
				end
			end
			data.onWinButton = onButton

			-- HAZARD HITS (2-second immunity between bonks).
			if clockNow - data.lastHit > 2 then
				local hit = nil
				for _, gimmick in ipairs(gimmicks) do
					if gimmick.type == "ball" and gimmick.z then
						local delta = pos - Vector3.new(0, OBBY_Y + 4.5, gimmick.z)
						if Vector3.new(delta.X, 0, delta.Z).Magnitude < gimmick.radius + 1.5 and math.abs(delta.Y) < 9 then
							hit = Vector3.new(delta.X, 0, delta.Z)
						end
					elseif gimmick.type == "wave" and gimmick.active and gimmick.z then
						if math.abs(pos.X) < 13 and math.abs(pos.Z - gimmick.z) < 3.5 and pos.Y > OBBY_Y - 2 and pos.Y < OBBY_Y + 16 then
							hit = Vector3.new(0, 0, -1) -- swept backwards
						end
					end
				end
				if not hit then
					for _, chaser in ipairs(chaserModels) do
						local chaserPos = chaser.model.PrimaryPart.Position
						local delta = pos - chaserPos
						if math.abs(delta.Y) < 8 and Vector3.new(delta.X, 0, delta.Z).Magnitude < 4.5 then
							hit = Vector3.new(delta.X, 0, delta.Z)
							break
						end
					end
				end
				if hit then
					data.lastHit = clockNow
					local pushDirection = hit.Magnitude > 0.05 and hit.Unit or Vector3.new(0, 0, -1)
					hrp.AssemblyLinearVelocity = pushDirection * 70 + Vector3.new(0, 40, 0)
					worldPopup(pos + Vector3.new(0, 5, 0), "BONK!", Color3.fromRGB(255, 130, 130))
				end
			end
		end
	end
end)

print("Plus One Speed: Candy Keyboard loaded! Every step counts :)")
