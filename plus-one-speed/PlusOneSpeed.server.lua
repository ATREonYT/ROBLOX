--==============================================================================
-- PLUS ONE SPEED: KEYBOARD RUN
-- A complete "+1 Speed Keyboard Escape"-style game in ONE script.
--
-- HOW TO USE:
--   1. Open Roblox Studio -> new "Baseplate" place
--   2. In the Explorer, find ServerScriptService
--   3. Insert a Script inside it, delete the default code, paste ALL of this
--   4. Press Play. That's the whole setup.
--
-- EVERY STEP you take gives +1 Speed, forever. Run across giant candy
-- keyboard keys, grab the yellow WINS pad at the end of each stage, and buy
-- glowing trails that multiply your speed gain. Rebirth at the statue to
-- trade your speed for a permanent multiplier. Get fast enough and you can
-- RUN straight over gaps you used to have to jump. Watch out for the angry
-- brainrots patrolling the later stages!
--==============================================================================

--==============================================================================
-- CONFIG -- play with these numbers! Nothing here can break the game.
--==============================================================================

local SPEED_PER_STEP  = 1     -- speed gained per step (multiplied by rebirths/trails)
local STEP_LENGTH     = 3.5   -- how many studs of walking count as one step
local BASE_WALKSPEED  = 16    -- Roblox default walking speed (speed adds to this)
local MAX_WALKSPEED   = 350   -- your legs' limit (the Speed NUMBER keeps growing)
local TREADMILL_GAIN  = 2     -- free speed per second while on the AFK treadmill
local LEVEL_SIZE      = 10    -- 1 Level per this much Speed
local REBIRTH_BONUS   = 0.5   -- each rebirth adds +0.5x to your speed multiplier
local STAGE_COUNT     = 8     -- how many keyboard stages to build
local WINS_COOLDOWN   = 8     -- seconds before the same wins pad pays you again
local GOLDEN_BONUS    = 250   -- wins from the Golden Brainrot at the very end
local GOLDEN_COOLDOWN = 180   -- seconds between Golden Brainrot claims (per player)
local SAVE_PROGRESS   = true  -- saves speed + wins + rebirths + trail (needs API access)

-- Rebirth requirements in LEVELS (the real game's curve: x1.5 multiplier at
-- level 15, then +0.5x per tier). After the list runs out it grows 1.5x each.
local REBIRTH_LEVELS = { 15, 25, 40, 60, 90, 135, 200, 300 }

-- The trail shop: bought with Wins, each is a glowing trail AND a permanent
-- multiplier on every point of speed you gain. They survive rebirths.
local TRAILS = {
	{ name = "White Trail",   cost = 50,    bonus = 0.25, color = Color3.fromRGB(255, 255, 255) },
	{ name = "Blue Trail",    cost = 250,   bonus = 0.5,  color = Color3.fromRGB(100, 181, 246) },
	{ name = "Purple Trail",  cost = 1000,  bonus = 1,    color = Color3.fromRGB(186, 104, 255) },
	{ name = "Gold Trail",    cost = 5000,  bonus = 2,    color = Color3.fromRGB(255, 213,  79) },
	{ name = "RAINBOW Trail", cost = 20000, bonus = 4,    color = nil }, -- nil = cycles all colors!
}

--==============================================================================
-- SERVICES & HELPERS (same cartoony kit as Snatch a Brainrot)
--==============================================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local Debris           = game:GetService("Debris")
local Lighting         = game:GetService("Lighting")
local DataStoreService = game:GetService("DataStoreService")

local rng = Random.new()

local mapFolder = Instance.new("Folder")
mapFolder.Name = "SpeedMap"
mapFolder.Parent = workspace

for _, obj in ipairs(workspace:GetChildren()) do
	if obj:IsA("SpawnLocation") then obj:Destroy() end
end

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
	stroke.Color = Color3.fromRGB(40, 30, 50)
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
	if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
	if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
	return tostring(math.floor(n))
end

local function cashPopup(position, text, color)
	local anchor = newPart({
		Name = "Popup", Size = Vector3.new(0.4, 0.4, 0.4), Transparency = 1,
		CanCollide = false, CanQuery = false,
		Position = position, Parent = mapFolder,
	})
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 200, 0, 40)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
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
				if child.Name == "SpeedAnnouncement" then existing += 1 end
			end
			local screen = Instance.new("ScreenGui")
			screen.Name = "SpeedAnnouncement"
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
-- BRIGHT CARTOON LIGHTING
--==============================================================================

Lighting.ClockTime = 13.5
Lighting.Brightness = 3
Lighting.Ambient = Color3.fromRGB(150, 150, 160)
Lighting.OutdoorAmbient = Color3.fromRGB(160, 160, 170)

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.6
bloom.Size = 28
bloom.Threshold = 1.1
bloom.Parent = Lighting

local colorPunch = Instance.new("ColorCorrectionEffect")
colorPunch.Saturation = 0.25
colorPunch.Contrast = 0.06
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
-- MAP: a giant desk with a floating candy-keyboard obby running down it.
-- Spawn plaza at the near end; stages stretch away in a line. Fall off a
-- key and you're teleported back to the start of that stage.
--==============================================================================

local OBBY_Y = 6 -- the walking surface height for the whole obby

-- The desk far below (what you see when you fall).
newPart({
	Name = "Desk", Size = Vector3.new(220, 2, 1560),
	Position = Vector3.new(0, -15, 700),
	Color = Color3.fromRGB(255, 183, 197),
	Parent = mapFolder,
})
newPart({
	Name = "DeskMat", Size = Vector3.new(150, 0.6, 1500),
	Position = Vector3.new(0, -13.7, 700),
	Color = Color3.fromRGB(186, 140, 255),
	Parent = mapFolder,
})

--==============================================================================
-- SPAWN PLAZA -- spawn, AFK treadmill, trail shop, rebirth statue
--==============================================================================

local PLAZA_DEPTH = 70
newPart({
	Name = "Plaza", Size = Vector3.new(64, 1.2, PLAZA_DEPTH),
	Position = Vector3.new(0, OBBY_Y - 0.6, PLAZA_DEPTH / 2),
	Color = Color3.fromRGB(255, 244, 200),
	Parent = mapFolder,
})
newPart({
	Name = "PlazaTrim", Size = Vector3.new(68, 0.8, PLAZA_DEPTH + 4),
	Position = Vector3.new(0, OBBY_Y - 1.2, PLAZA_DEPTH / 2),
	Color = Color3.fromRGB(255, 150, 200),
	Parent = mapFolder,
})

local spawnPad = Instance.new("SpawnLocation")
spawnPad.Size = Vector3.new(12, 1, 12)
spawnPad.Position = Vector3.new(0, OBBY_Y + 0.5, 12)
spawnPad.Anchored = true
spawnPad.Neutral = true
spawnPad.Color = Color3.fromRGB(255, 255, 255)
spawnPad.Material = Enum.Material.SmoothPlastic
spawnPad.TopSurface = Enum.SurfaceType.Smooth
spawnPad.Duration = 0
spawnPad.Parent = mapFolder
local SPAWN_POS = Vector3.new(0, OBBY_Y + 4, 12)

local welcomeSign = newPart({
	Name = "WelcomeSign", Size = Vector3.new(0.5, 0.5, 0.5), Transparency = 1,
	CanCollide = false, CanQuery = false,
	Position = Vector3.new(0, OBBY_Y + 16, 6),
	Parent = mapFolder,
})
makeLabel(welcomeSign, 1.6, "PLUS ONE SPEED", Color3.fromRGB(255, 110, 180), 34, 500)
makeLabel(welcomeSign, -1, "Every STEP = +1 Speed! Run the keyboard, grab the WINS pads!", Color3.fromRGB(255, 244, 200), 18, 400)

-- AFK TREADMILL: stand on it to gain speed while doing nothing.
local treadmill = newPart({
	Name = "Treadmill", Size = Vector3.new(10, 0.6, 14),
	Position = Vector3.new(-22, OBBY_Y + 0.3, 16),
	Color = Color3.fromRGB(70, 70, 85),
	Parent = mapFolder,
})
for z = -5, 5, 2 do
	newPart({
		Name = "TreadmillStripe", Size = Vector3.new(8, 0.1, 0.8),
		Position = treadmill.Position + Vector3.new(0, 0.36, z),
		Color = Color3.fromRGB(140, 255, 140), Material = Enum.Material.Neon,
		CanCollide = false, CanQuery = false,
		Parent = mapFolder,
	})
end
makeLabel(treadmill, 4, "AFK TREADMILL  (+" .. TREADMILL_GAIN .. " speed/s)", Color3.fromRGB(140, 255, 140), 18, 140)
local TREADMILL_POS = treadmill.Position

-- REBIRTH STATUE: a golden runner on a pedestal.
local statueBase = Vector3.new(22, OBBY_Y, 16)
tube("Y", 2, 8, Color3.fromRGB(255, 255, 255), {
	Name = "StatuePedestal", Position = statueBase + Vector3.new(0, 1, 0), Parent = mapFolder,
})
local statueBody = ball(Vector3.new(3, 4, 2.6), Color3.fromRGB(255, 200, 80), {
	Name = "StatueBody", Material = Enum.Material.Metal,
	Position = statueBase + Vector3.new(0, 4.6, 0),
	Parent = mapFolder,
})
ball(Vector3.new(2, 1.9, 2), Color3.fromRGB(255, 200, 80), {
	Name = "StatueHead", Material = Enum.Material.Metal,
	Position = statueBase + Vector3.new(0, 7.4, 0),
	Parent = mapFolder,
})
makeLabel(statueBody, 5.4, "REBIRTH STATUE", Color3.fromRGB(255, 213, 79), 22, 250)
local _, rebirthInfoLabel = makeLabel(statueBody, 4.2, "", Color3.fromRGB(255, 244, 200), 15, 150)

local rebirthPrompt = Instance.new("ProximityPrompt")
rebirthPrompt.ActionText = "Rebirth"
rebirthPrompt.ObjectText = "Reset Speed, permanent multiplier!"
rebirthPrompt.HoldDuration = 0.5
rebirthPrompt.MaxActivationDistance = 10
rebirthPrompt.RequiresLineOfSight = false
rebirthPrompt.Parent = statueBody

-- TRAIL SHOP: five stands along the back of the plaza.
local trailPrompts = {}
for i, trail in ipairs(TRAILS) do
	local x = -28 + (i - 1) * 14
	local standPos = Vector3.new(x, OBBY_Y, 58)
	tube("Y", 3.6, 2, Color3.fromRGB(255, 255, 255), {
		Name = "TrailStand", Position = standPos + Vector3.new(0, 1.8, 0), Parent = mapFolder,
	})
	local orb = ball(Vector3.new(2.4, 2.4, 2.4), trail.color or Color3.fromRGB(255, 0, 255), {
		Name = "TrailOrb" .. i, Material = Enum.Material.Neon,
		Position = standPos + Vector3.new(0, 4.6, 0),
		Parent = mapFolder,
	})
	makeLabel(orb, 2.6, trail.name, trail.color or Color3.fromRGB(255, 120, 255), 17, 90)
	makeLabel(orb, 1.6, formatNum(trail.cost) .. " Wins  |  +" .. (trail.bonus * 100) .. "% speed gain", Color3.fromRGB(190, 255, 190), 13, 70)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Buy"
	prompt.ObjectText = trail.name
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = orb
	trailPrompts[i] = { prompt = prompt, orb = orb }
end
makeLabel(newPart({
	Name = "ShopSign", Size = Vector3.new(0.5, 0.5, 0.5), Transparency = 1,
	CanCollide = false, CanQuery = false,
	Position = Vector3.new(0, OBBY_Y + 12, 60), Parent = mapFolder,
}), 0, "TRAIL SHOP - trails multiply your speed gain forever!", Color3.fromRGB(216, 160, 255), 20, 250)

--==============================================================================
-- ANGRY BRAINROT BLOBS (they patrol the later stages)
--==============================================================================

local function buildChaser()
	local model = Instance.new("Model")
	model.Name = "Angry Brainrot"
	local root = newPart({
		Name = "Root", Size = Vector3.new(0.4, 0.4, 0.4),
		Transparency = 1, CanCollide = false, CanQuery = false,
		Position = Vector3.new(0, 0.2, 0),
	})
	root.Parent = model
	model.PrimaryPart = root

	local hue = rng:NextNumber(0, 0.12) -- angry reds and oranges
	local bodyColor = Color3.fromHSV(hue, 0.75, 0.95)
	local body = ball(Vector3.new(3.4, 3.6, 3), bodyColor, { Name = "Body", Position = Vector3.new(0, 2.2, 0) })
	body.CanCollide = false
	body.Parent = model
	for _, x in ipairs({ -0.65, 0.65 }) do
		local eye = ball(Vector3.new(0.8, 0.8, 0.45), Color3.new(1, 1, 1), { Name = "Eye", Position = Vector3.new(x, 3, -1.3) })
		eye.CanCollide = false
		eye.Parent = model
		local pupil = ball(Vector3.new(0.4, 0.4, 0.25), Color3.new(0, 0, 0), { Name = "Pupil", Position = Vector3.new(x, 3, -1.5) })
		pupil.CanCollide = false
		pupil.Parent = model
		local brow = newPart({ Name = "Brow", Size = Vector3.new(0.9, 0.22, 0.2), Color = Color3.fromRGB(40, 25, 30) })
		brow.CFrame = CFrame.new(x, 3.6, -1.35) * CFrame.Angles(0, 0, math.rad(x < 0 and -20 or 20))
		brow.CanCollide = false
		brow.Parent = model
	end
	local mouth = ball(Vector3.new(1.1, 0.7, 0.3), Color3.fromRGB(60, 25, 30), { Name = "Mouth", Position = Vector3.new(0, 2.2, -1.45) })
	mouth.CanCollide = false
	mouth.Parent = model
	for _, x in ipairs({ -0.8, 0.8 }) do
		local foot = ball(Vector3.new(1, 0.6, 1.3), bodyColor, { Name = "Foot", Position = Vector3.new(x, 0.3, 0) })
		foot.CanCollide = false
		foot.Parent = model
	end
	return model
end

--==============================================================================
-- THE KEYBOARD STAGES
--==============================================================================

local KEY_PHRASES = {
	"PLUSONESPEED", "RUNFASTER", "CANDYKEYS", "BRAINROT",
	"ZOOMZOOM", "SKIBIDI", "TOOFAST", "GOLDENRUN",
}

local SAFE_ZONES = {}  -- { index, pos, size } -- zone 0 is the plaza
local WINS_PADS = {}   -- { pos, stage, reward }
local STAGE_CHASERS = {} -- { model, center, range, z, speed, phase }

table.insert(SAFE_ZONES, { index = 0, pos = Vector3.new(0, OBBY_Y, PLAZA_DEPTH / 2), size = Vector3.new(64, 0, PLAZA_DEPTH) })

local cursorZ = PLAZA_DEPTH + 10
local laneOffsets = { -7, 0, 7 }

for stage = 1, STAGE_COUNT do
	local keyCount = 6 + stage
	local gap = 2.5 + 0.45 * stage
	local phrase = KEY_PHRASES[(stage - 1) % #KEY_PHRASES + 1]
	local lane = 2 -- start each stage in the middle lane

	for k = 1, keyCount do
		-- drift one lane at most per key, so jumps are always possible
		lane = math.clamp(lane + rng:NextInteger(-1, 1), 1, 3)
		local x = laneOffsets[lane]
		local z = cursorZ + (k - 1) * (8 + gap)
		local hue = ((stage * 7 + k * 3) % 20) / 20

		newPart({
			Name = "Key", Size = Vector3.new(8, 2.8, 8),
			Position = Vector3.new(x, OBBY_Y - 1.4 - 0.35, z),
			Color = Color3.fromHSV(hue, 0.35, 1),
			Parent = mapFolder,
		})
		local keyTop = newPart({
			Name = "KeyTop", Size = Vector3.new(6.8, 0.7, 6.8),
			Position = Vector3.new(x, OBBY_Y - 0.35, z),
			Color = Color3.fromHSV(hue, 0.18, 1),
			Parent = mapFolder,
		})
		-- the letter printed on the keycap
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		local letter = Instance.new("TextLabel")
		letter.Size = UDim2.new(1, 0, 1, 0)
		letter.Rotation = 180
		letter.Text = phrase:sub((k - 1) % #phrase + 1, (k - 1) % #phrase + 1)
		styleText(letter, 100, Color3.fromRGB(120, 100, 140))
		letter.TextScaled = true
		letter.Parent = gui
		gui.Parent = keyTop
	end

	local stageEndZ = cursorZ + (keyCount - 1) * (8 + gap)

	-- Angry brainrots patrol the later stages, sweeping across the keys.
	if stage == 4 or stage == 6 or stage == 8 then
		for c = 1, 2 do
			local chaser = buildChaser()
			local z = cursorZ + (stageEndZ - cursorZ) * (c / 3)
			chaser.Parent = mapFolder
			table.insert(STAGE_CHASERS, {
				model = chaser, center = 0, range = 12, z = z,
				speed = 0.9 + 0.25 * stage / 4, phase = c * 2.1 + stage,
			})
		end
	end

	-- Safe zone at the end of the stage, with its glowing WINS pad.
	local zoneZ = stageEndZ + gap + 8 + 13
	newPart({
		Name = "SafeZone" .. stage, Size = Vector3.new(34, 1.2, 26),
		Position = Vector3.new(0, OBBY_Y - 0.6, zoneZ),
		Color = Color3.fromRGB(196, 255, 200),
		Parent = mapFolder,
	})
	local reward = stage * stage
	local pad = tube("Y", 0.5, 8, Color3.fromRGB(255, 230, 60), {
		Name = "WinsPad" .. stage, Material = Enum.Material.Neon,
		Position = Vector3.new(0, OBBY_Y + 0.25, zoneZ),
		Parent = mapFolder,
	})
	makeLabel(pad, 3, "+" .. reward .. " WINS", Color3.fromRGB(255, 230, 60), 22, 160)
	table.insert(WINS_PADS, { pos = pad.Position, stage = stage, reward = reward })
	table.insert(SAFE_ZONES, { index = stage, pos = Vector3.new(0, OBBY_Y, zoneZ), size = Vector3.new(34, 0, 26) })

	local sign = tube("Y", 5, 0.8, Color3.fromRGB(255, 200, 80), {
		Name = "StageSign", Position = Vector3.new(13, OBBY_Y + 2.5, zoneZ + 8), Parent = mapFolder,
	})
	makeLabel(sign, 4, stage < STAGE_COUNT and ("STAGE " .. stage + 1 .. "  -->") or "THE GOLDEN BRAINROT AWAITS...",
		Color3.fromRGB(255, 244, 200), 20, 160)

	cursorZ = zoneZ + 13 + 10
end

--==============================================================================
-- THE GOLDEN BRAINROT -- the prize at the very end of the keyboard
--==============================================================================

local goldenZ = cursorZ + 10
newPart({
	Name = "GoldenPlatform", Size = Vector3.new(44, 1.2, 40),
	Position = Vector3.new(0, OBBY_Y - 0.6, goldenZ),
	Color = Color3.fromRGB(255, 236, 170),
	Parent = mapFolder,
})
tube("Y", 2, 10, Color3.fromRGB(255, 255, 255), {
	Name = "GoldenPedestal", Position = Vector3.new(0, OBBY_Y + 1, goldenZ + 8), Parent = mapFolder,
})
local golden = ball(Vector3.new(5, 5.4, 4.6), Color3.fromRGB(255, 200, 60), {
	Name = "GoldenBrainrot", Material = Enum.Material.Metal,
	Position = Vector3.new(0, OBBY_Y + 4.8, goldenZ + 8),
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
makeLabel(golden, 3.4, "+" .. GOLDEN_BONUS .. " Wins, every " .. math.floor(GOLDEN_COOLDOWN / 60) .. " min!", Color3.fromRGB(255, 244, 200), 15, 200)
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

table.insert(SAFE_ZONES, { index = STAGE_COUNT + 1, pos = Vector3.new(0, OBBY_Y, goldenZ), size = Vector3.new(44, 0, 40) })

-- Tip signs on the plaza.
local function tipSign(position, text, color)
	local post = tube("Y", 5, 0.8, Color3.fromRGB(255, 200, 80), {
		Name = "TipPost", Position = position + Vector3.new(0, 2.5, 0), Parent = mapFolder,
	})
	makeLabel(post, 4, text, color or Color3.fromRGB(255, 255, 255), 20, 140)
end

tipSign(Vector3.new(-10, OBBY_Y, 34), "Every step you take = +1 Speed. Just RUN!", Color3.fromRGB(140, 255, 160))
tipSign(Vector3.new(10, OBBY_Y, 44), "Fall off? You teleport back - your speed is safe!", Color3.fromRGB(255, 220, 120))
tipSign(Vector3.new(-10, OBBY_Y, 54), "Fast enough and you can RUN over the gaps!", Color3.fromRGB(255, 160, 220))

-- Puffy clouds floating around the keyboard.
for _, spot in ipairs({
	Vector3.new(-70, 45, 100), Vector3.new(75, 52, 350), Vector3.new(-80, 48, 620),
	Vector3.new(70, 55, 900), Vector3.new(-75, 50, 1150), Vector3.new(60, 47, 1350),
}) do
	for i, offset in ipairs({
		Vector3.new(0, 0, 0), Vector3.new(7, -1, 2), Vector3.new(-7, -1, -1), Vector3.new(2, 2.5, -2),
	}) do
		ball(Vector3.new(14 - i, 8 - i * 0.5, 12 - i), Color3.fromRGB(255, 255, 255), {
			Name = "Cloud", Position = spot + offset, CanCollide = false, Parent = mapFolder,
		})
	end
end

--==============================================================================
-- GAME STATE
--==============================================================================

local playerData = {} -- [player] = { speed, rebirths, trailIndex, checkpoint,
                      --   distAcc, lastPos, padCooldowns, goldenAt, lastHit,
                      --   loaded, loadFailed, trail, overheadLabel }

local function getStat(player, name)
	local stats = player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild(name)
end

local function rebirthLevelNeeded(rebirths)
	local nextIndex = rebirths + 1
	if nextIndex <= #REBIRTH_LEVELS then
		return REBIRTH_LEVELS[nextIndex]
	end
	local level = REBIRTH_LEVELS[#REBIRTH_LEVELS]
	for _ = #REBIRTH_LEVELS + 1, nextIndex do
		level = math.ceil(level * 1.5)
	end
	return level
end

local function gainMultiplier(data)
	local mult = 1 + REBIRTH_BONUS * data.rebirths
	if data.trailIndex > 0 then
		mult *= (1 + TRAILS[data.trailIndex].bonus)
	end
	return mult
end

local function playerLevel(data)
	return math.floor(data.speed / LEVEL_SIZE)
end

--==============================================================================
-- SPEED & TRAILS
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

	-- The glowing trail (enabled once a trail is owned).
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

	-- The over-head speed tag everyone can see.
	local head = char:FindFirstChild("Head") or hrp
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 200, 0, 34)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 220
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Text = ""
	styleText(label, 20, Color3.fromRGB(255, 213, 79))
	label.Parent = gui
	gui.Parent = head
	data.overheadLabel = label

	data.lastPos = nil -- fresh character: don't count the spawn jump as steps
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
	if not color then -- RAINBOW: cycle every hue
		color = Color3.fromHSV(os.clock() * 0.5 % 1, 0.8, 1)
	end
	trail.Color = ColorSequence.new(color)
end

--==============================================================================
-- HUD
--==============================================================================

local function makeHud(player)
	local gui = player:FindFirstChild("PlayerGui")
	if not gui then return end
	local old = gui:FindFirstChild("SpeedHud")
	if old then old:Destroy() end

	local screen = Instance.new("ScreenGui")
	screen.Name = "SpeedHud"
	screen.ResetOnSpawn = false

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 300, 0, 92)
	frame.Position = UDim2.new(0.5, -150, 1, -112)
	frame.BackgroundColor3 = Color3.fromRGB(35, 28, 48)
	frame.BackgroundTransparency = 0.15
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 213, 79)
	stroke.Thickness = 3
	stroke.Parent = frame

	local speedLabel = Instance.new("TextLabel")
	speedLabel.Name = "SpeedText"
	speedLabel.Size = UDim2.new(1, -16, 0.44, 0)
	speedLabel.Position = UDim2.new(0, 8, 0, 2)
	speedLabel.Text = "SPEED: 0"
	styleText(speedLabel, 30, Color3.fromRGB(255, 213, 79))
	speedLabel.Parent = frame

	local winsLabel = Instance.new("TextLabel")
	winsLabel.Name = "WinsText"
	winsLabel.Size = UDim2.new(1, -16, 0.26, 0)
	winsLabel.Position = UDim2.new(0, 8, 0.46, 0)
	winsLabel.Text = ""
	styleText(winsLabel, 17, Color3.fromRGB(140, 255, 140))
	winsLabel.Parent = frame

	local rebirthLabel = Instance.new("TextLabel")
	rebirthLabel.Name = "RebirthText"
	rebirthLabel.Size = UDim2.new(1, -16, 0.26, 0)
	rebirthLabel.Position = UDim2.new(0, 8, 0.72, 0)
	rebirthLabel.Text = ""
	styleText(rebirthLabel, 15, Color3.fromRGB(255, 180, 230))
	rebirthLabel.Parent = frame

	frame.Parent = screen
	screen.Parent = gui
end

local function updateHud(player)
	local data = playerData[player]
	local gui = player:FindFirstChild("PlayerGui")
	local screen = gui and gui:FindFirstChild("SpeedHud")
	if not data or not screen then return end
	local frame = screen:FindFirstChildOfClass("Frame")
	if not frame then return end
	local mult = gainMultiplier(data)
	frame.SpeedText.Text = "SPEED: " .. formatNum(data.speed) .. "  (+" .. string.format("%.2g", SPEED_PER_STEP * mult) .. "/step)"
	local wins = getStat(player, "Wins")
	frame.WinsText.Text = "WINS: " .. formatNum(wins and wins.Value or 0)
		.. "   LEVEL: " .. playerLevel(data)
		.. (data.trailIndex > 0 and ("   " .. TRAILS[data.trailIndex].name) or "")
	local needed = rebirthLevelNeeded(data.rebirths)
	if playerLevel(data) >= needed then
		frame.RebirthText.Text = "REBIRTH READY! Go to the statue!"
	else
		frame.RebirthText.Text = "Rebirth " .. data.rebirths .. " (x" .. (1 + REBIRTH_BONUS * data.rebirths)
			.. ")  |  next at Level " .. needed
	end
end

--==============================================================================
-- SAVING (safe to leave on -- if saving isn't available it just skips)
--==============================================================================

local saveStore = nil
if SAVE_PROGRESS then
	pcall(function()
		saveStore = DataStoreService:GetDataStore("PlusOneSpeed_v1")
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
			speed = data.speed, wins = wins.Value,
			rebirths = data.rebirths, trailIndex = data.trailIndex,
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
		speed = 0, rebirths = 0, trailIndex = 0, checkpoint = 1,
		distAcc = 0, lastPos = nil, padCooldowns = {}, goldenAt = 0,
		lastHit = 0, loaded = false, loadFailed = false,
	}

	local function onCharacter(char)
		setupCharacterExtras(player, char)
		applySpeed(player)
		updateTrail(player)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then task.spawn(onCharacter, player.Character) end

	makeHud(player)

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
			local wins = getStat(player, "Wins")
			if wins then wins.Value = saved.wins or 0 end
			local rebirthStat = getStat(player, "Rebirths")
			if rebirthStat then rebirthStat.Value = data.rebirths end
			applySpeed(player)
			updateTrail(player)
		end
	end
	updateHud(player)
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
-- REBIRTH & SHOPS
--==============================================================================

rebirthInfoLabel.Text = "Level " .. REBIRTH_LEVELS[1] .. " to start  |  each rebirth = +" .. REBIRTH_BONUS .. "x speed gain"

rebirthPrompt.Triggered:Connect(function(player)
	local data = playerData[player]
	if not data then return end
	local needed = rebirthLevelNeeded(data.rebirths)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if playerLevel(data) < needed then
		if hrp then
			cashPopup(hrp.Position + Vector3.new(0, 4, 0), "Need Level " .. needed .. "!", Color3.fromRGB(255, 180, 180))
		end
		return
	end
	data.rebirths += 1
	data.speed = 0
	data.distAcc = 0
	applySpeed(player)
	local rebirthStat = getStat(player, "Rebirths")
	if rebirthStat then rebirthStat.Value = data.rebirths end
	if hrp then
		cashPopup(hrp.Position + Vector3.new(0, 4, 0), "REBIRTH " .. data.rebirths .. "!", Color3.fromRGB(255, 160, 220))
	end
	announce(player.Name .. " rebirthed! They now gain x" .. (1 + REBIRTH_BONUS * data.rebirths) .. " speed per step!",
		Color3.fromRGB(255, 160, 220))
	updateHud(player)
end)

for i, stand in ipairs(trailPrompts) do
	stand.prompt.Triggered:Connect(function(player)
		local data = playerData[player]
		local wins = getStat(player, "Wins")
		if not data or not wins then return end
		local trail = TRAILS[i]
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if data.trailIndex >= i then
			if hrp then cashPopup(hrp.Position + Vector3.new(0, 4, 0), "Already owned!", Color3.fromRGB(255, 220, 140)) end
			return
		end
		if wins.Value < trail.cost then
			if hrp then cashPopup(hrp.Position + Vector3.new(0, 4, 0), "Need " .. formatNum(trail.cost) .. " Wins!", Color3.fromRGB(255, 180, 180)) end
			return
		end
		wins.Value -= trail.cost
		data.trailIndex = i
		updateTrail(player)
		if hrp then cashPopup(hrp.Position + Vector3.new(0, 4, 0), trail.name .. "!", trail.color or Color3.fromRGB(255, 120, 255)) end
		if i >= 4 then
			announce(player.Name .. " bought the " .. trail.name .. "! (+" .. (trail.bonus * 100) .. "% speed gain)",
				trail.color or Color3.fromRGB(255, 120, 255))
		end
		updateHud(player)
	end)
end

goldenPrompt.Triggered:Connect(function(player)
	local data = playerData[player]
	local wins = getStat(player, "Wins")
	if not data or not wins then return end
	local now = os.clock()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if now - data.goldenAt < GOLDEN_COOLDOWN then
		local wait = math.ceil((GOLDEN_COOLDOWN - (now - data.goldenAt)) / 60)
		if hrp then cashPopup(hrp.Position + Vector3.new(0, 4, 0), "Come back in ~" .. wait .. " min!", Color3.fromRGB(255, 220, 140)) end
		return
	end
	data.goldenAt = now
	wins.Value += GOLDEN_BONUS
	if hrp then cashPopup(hrp.Position + Vector3.new(0, 5, 0), "+" .. GOLDEN_BONUS .. " WINS!", Color3.fromRGB(255, 230, 60)) end
	announce(player.Name .. " reached the GOLDEN BRAINROT! +" .. GOLDEN_BONUS .. " Wins!", Color3.fromRGB(255, 220, 90))
	updateHud(player)
end)

--==============================================================================
-- MAIN LOOPS
--==============================================================================

-- Once a second: treadmill gains, HUD, overhead tags, rainbow trails.
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local data = playerData[player]
			if data then
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if hrp then
					local offset = hrp.Position - TREADMILL_POS
					if math.abs(offset.X) < 5.5 and math.abs(offset.Z) < 7.5 and math.abs(offset.Y) < 8 then
						data.speed += TREADMILL_GAIN * gainMultiplier(data)
						applySpeed(player)
					end
				end
				if data.overheadLabel and data.overheadLabel.Parent then
					data.overheadLabel.Text = math.floor(data.speed) .. " SPEED"
						.. (data.rebirths > 0 and ("  |  R" .. data.rebirths) or "")
				end
				updateTrail(player)
				updateHud(player)
			end
		end
	end
end)

-- Every frame: count steps, catch fallers, track checkpoints, pay wins
-- pads, and move the angry brainrots.
local padTimer = 0
RunService.Heartbeat:Connect(function(dt)
	local clockNow = os.clock()

	-- Patrolling brainrots sweep side to side across the keys.
	for _, chaser in ipairs(STAGE_CHASERS) do
		local x = chaser.center + math.sin(clockNow * chaser.speed + chaser.phase) * chaser.range
		local nextX = chaser.center + math.sin(clockNow * chaser.speed + chaser.phase + 0.05) * chaser.range
		local hop = math.abs(math.sin(clockNow * 7 + chaser.phase)) * 0.5
		chaser.model:PivotTo(CFrame.lookAt(
			Vector3.new(x, OBBY_Y + hop, chaser.z),
			Vector3.new(nextX >= x and nextX + 0.1 or nextX - 0.1, OBBY_Y + hop, chaser.z)))
	end

	padTimer += dt
	local checkPads = padTimer >= 0.1
	if checkPads then padTimer = 0 end

	for _, player in ipairs(Players:GetPlayers()) do
		local data = playerData[player]
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if data and hrp then
			local pos = hrp.Position

			-- STEP COUNTING: every STEP_LENGTH studs walked = +1 step.
			if data.lastPos then
				local delta = Vector3.new(pos.X - data.lastPos.X, 0, pos.Z - data.lastPos.Z).Magnitude
				if delta < 30 then -- ignore teleports
					data.distAcc += delta
					if data.distAcc >= STEP_LENGTH then
						local steps = math.floor(data.distAcc / STEP_LENGTH)
						data.distAcc -= steps * STEP_LENGTH
						data.speed += steps * SPEED_PER_STEP * gainMultiplier(data)
						applySpeed(player)
					end
				end
			end
			data.lastPos = pos

			-- FELL OFF: back to your latest safe zone (speed is untouched).
			if pos.Y < -4 then
				local zone = SAFE_ZONES[data.checkpoint] or SAFE_ZONES[1]
				local target = zone.index == 0 and SPAWN_POS or (zone.pos + Vector3.new(0, 4, 0))
				char:PivotTo(CFrame.new(target))
				hrp.AssemblyLinearVelocity = Vector3.zero
				data.lastPos = nil
			end

			-- CHECKPOINTS: standing in a safe zone remembers it.
			if checkPads then
				for zoneIndex, zone in ipairs(SAFE_ZONES) do
					local offset = pos - zone.pos
					if math.abs(offset.X) < zone.size.X / 2 and math.abs(offset.Z) < zone.size.Z / 2
						and offset.Y > -4 and offset.Y < 14 then
						data.checkpoint = zoneIndex
					end
				end

				-- WINS PADS: stand on one to collect (short cooldown each).
				for padIndex, pad in ipairs(WINS_PADS) do
					local offset = pos - pad.pos
					if math.abs(offset.X) < 4.5 and math.abs(offset.Z) < 4.5 and offset.Y > -2 and offset.Y < 10 then
						local lastClaim = data.padCooldowns[padIndex] or -math.huge
						if clockNow - lastClaim >= WINS_COOLDOWN then
							data.padCooldowns[padIndex] = clockNow
							local wins = getStat(player, "Wins")
							if wins then wins.Value += pad.reward end
							cashPopup(pos + Vector3.new(0, 5, 0), "+" .. pad.reward .. " WINS!", Color3.fromRGB(255, 230, 60))
							updateHud(player)
						end
					end
				end

				-- ANGRY BRAINROTS knock you around (and probably off).
				if clockNow - data.lastHit > 2 then
					for _, chaser in ipairs(STAGE_CHASERS) do
						local chaserPos = chaser.model.PrimaryPart.Position
						local delta = pos - chaserPos
						if math.abs(delta.Y) < 8 and Vector3.new(delta.X, 0, delta.Z).Magnitude < 4.5 then
							data.lastHit = clockNow
							local flat = Vector3.new(delta.X, 0, delta.Z)
							local pushDirection = flat.Magnitude > 0.05 and flat.Unit or Vector3.new(0, 0, -1)
							hrp.AssemblyLinearVelocity = pushDirection * 70 + Vector3.new(0, 40, 0)
							cashPopup(pos + Vector3.new(0, 5, 0), "BONK!", Color3.fromRGB(255, 130, 130))
							break
						end
					end
				end
			end
		end
	end
end)

print("Plus One Speed loaded! Run!")
