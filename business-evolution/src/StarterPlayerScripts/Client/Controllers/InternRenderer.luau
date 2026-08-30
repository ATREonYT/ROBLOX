--!strict
-- InternRenderer — the mini blocky figures trailing behind every player who
-- has interns equipped. Other players' interns are not in this client's
-- ClientState, so the source of truth is the "EquippedInternIds" character
-- attribute InternService stamps (comma-joined def ids, in equip order).
--
-- Everything is client-side cosmetics: anchored massless parts CFramed
-- directly every frame. No Humanoids, no physics, no replication.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))
local Interns = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Interns"))

local ATTRIBUTE_NAME = "EquippedInternIds"

-- Hard display cap per player: even if the attribute somehow carries more
-- (slot gamepasses stack server-side), seven-plus followers per player turns
-- a busy hub into soup.
local MAX_PER_PLAYER = 6

-- Formation: slots fan across a half-circle behind the owner.
local FOLLOW_RADIUS = 3.6
local SLOT_SPACING = math.rad(28)

local SMOOTHING = 7 -- exponential chase stiffness
local MAX_SPEED = 46 -- studs/s ceiling so a sprinting owner is chased, not glued
local TELEPORT_DISTANCE = 90 -- beyond this the owner elevator'd away; just snap
local ROOT_TO_GROUND = 2.9 -- HumanoidRootPart centre → floor, R15-ish
local BOB_SPEED = 3.2
local SPAWN_POP_SECONDS = 0.45

local SKIN_COLOR = Color3.fromRGB(255, 205, 148)
local TROUSER_COLOR = Color3.fromRGB(60, 60, 70)
local LANYARD_COLOR = Color3.fromRGB(200, 60, 60)

type FigurePartDef = {
	Part: Part,
	Offset: Vector3, -- from the figure root (feet centre)
	BaseSize: Vector3,
}

type InternVisual = {
	Model: Model,
	PartDefs: { FigurePartDef },
	Position: Vector3, -- feet centre, chased toward the formation slot
	Yaw: number,
	Phase: number, -- personal bob offset so a squad never bounces in sync
	SpawnedAt: number,
	LastScale: number,
}

type OwnerEntry = {
	Character: Model,
	Root: BasePart?,
	Visuals: { InternVisual },
	CharTrove: Trove.Trove,
}

local InternRenderer = {}

local trove = Trove.new()
local rng = Random.new()
local folder: Folder? = nil
local owners: { [Player]: OwnerEntry } = {}
local playerTroves: { [Player]: Trove.Trove } = {}

local function elasticOut(alpha: number): number
	if alpha <= 0 then
		return 0
	end
	if alpha >= 1 then
		return 1
	end
	return 2 ^ (-10 * alpha) * math.sin((alpha * 10 - 0.75) * (2 * math.pi / 3)) + 1
end

-- ── Figure construction ─────────────────────────────────────────────────────

-- Interns must never intercept a click aimed at a rival, so CanQuery stays
-- off on every part.
local function figurePart(parent: Instance, name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function buildNameTag(head: Part, name: string, rarityColor: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Adornee = head
	gui.Size = UDim2.fromScale(3.4, 0.9)
	gui.ExtentsOffsetWorldSpace = Vector3.new(0, 1.4, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 70

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = name
	label.TextColor3 = rarityColor
	label.TextScaled = true
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 2
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	label.Parent = gui

	gui.Parent = head
end

local function buildIntern(def: Interns.InternDef, spawnPosition: Vector3): InternVisual?
	local parentFolder = folder
	if not parentFolder then
		return nil
	end
	local rgb = Interns.RarityColors[def.Rarity]
	local rarityColor = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	-- Slight lightening keeps dark rarity tints (Common grey) readable as a
	-- shirt rather than a shadow.
	local shirtColor = rarityColor:Lerp(Color3.new(1, 1, 1), 0.15)

	local model = Instance.new("Model")
	model.Name = "Intern_" .. def.Id

	local visual: InternVisual = {
		Model = model,
		PartDefs = {},
		Position = spawnPosition,
		Yaw = 0,
		Phase = rng:NextNumber(0, math.pi * 2),
		SpawnedAt = os.clock(),
		LastScale = 0,
	}

	local function add(name: string, size: Vector3, offset: Vector3, color: Color3): Part
		local part = figurePart(model, name, size, color)
		table.insert(visual.PartDefs, { Part = part, Offset = offset, BaseSize = size })
		return part
	end

	add("LeftLeg", Vector3.new(0.22, 0.42, 0.26), Vector3.new(-0.14, 0.21, 0), TROUSER_COLOR)
	add("RightLeg", Vector3.new(0.22, 0.42, 0.26), Vector3.new(0.14, 0.21, 0), TROUSER_COLOR)
	add("Torso", Vector3.new(0.64, 0.56, 0.4), Vector3.new(0, 0.7, 0), shirtColor)
	add("LeftArm", Vector3.new(0.17, 0.5, 0.22), Vector3.new(-0.44, 0.72, 0), shirtColor)
	add("RightArm", Vector3.new(0.17, 0.5, 0.22), Vector3.new(0.44, 0.72, 0), shirtColor)
	local head = add("Head", Vector3.new(0.52, 0.52, 0.52), Vector3.new(0, 1.24, 0), SKIN_COLOR)
	-- Front of the figure is -Z, so chest accessories sit at negative Z.
	add("Lanyard", Vector3.new(0.3, 0.34, 0.03), Vector3.new(0, 0.85, -0.21), LANYARD_COLOR)
	add("Badge", Vector3.new(0.2, 0.24, 0.04), Vector3.new(0.05, 0.68, -0.22), Color3.fromRGB(245, 245, 245))

	if def.Id == "Consultant" then
		-- The Legendary earns their look: shades and a billable-hours briefcase.
		add("Sunglasses", Vector3.new(0.46, 0.11, 0.06), Vector3.new(0, 1.3, -0.27), Color3.fromRGB(20, 20, 24))
		add("Briefcase", Vector3.new(0.4, 0.3, 0.12), Vector3.new(0.5, 0.35, 0), Color3.fromRGB(87, 58, 36))
	end

	buildNameTag(head, def.Name, rarityColor)
	model.Parent = parentFolder
	return visual
end

-- ── Per-owner bookkeeping ───────────────────────────────────────────────────

local function clearVisuals(entry: OwnerEntry)
	for _, visual in entry.Visuals do
		visual.Model:Destroy()
	end
	table.clear(entry.Visuals)
end

local function rebuildVisuals(entry: OwnerEntry)
	clearVisuals(entry)
	local raw = entry.Character:GetAttribute(ATTRIBUTE_NAME)
	if typeof(raw) ~= "string" or raw == "" then
		return
	end
	local spawnPosition = entry.Character:GetPivot().Position - Vector3.new(0, ROOT_TO_GROUND, 0)
	for index, id in string.split(raw, ",") do
		if index > MAX_PER_PLAYER then
			break
		end
		local def = Interns.get(id)
		if def then
			local visual = buildIntern(def, spawnPosition)
			if visual then
				table.insert(entry.Visuals, visual)
			end
		end
	end
end

local function unwatchCharacter(player: Player)
	local entry = owners[player]
	if not entry then
		return
	end
	owners[player] = nil
	clearVisuals(entry)
	entry.CharTrove:Destroy()
end

local function watchCharacter(player: Player, character: Model, playerTrove: Trove.Trove)
	-- A respawn can race CharacterRemoving; make sure the old entry is gone.
	unwatchCharacter(player)

	-- Cast: the old Luau solver can't prove two instantiations of Trove's
	-- generic-method type are identical; the value really is a Trove.
	local charTrove = playerTrove:Extend() :: any
	local entry: OwnerEntry = {
		Character = character,
		Root = nil,
		Visuals = {},
		CharTrove = charTrove,
	}
	owners[player] = entry

	charTrove:Connect(character:GetAttributeChangedSignal(ATTRIBUTE_NAME), function()
		rebuildVisuals(entry)
	end)
	rebuildVisuals(entry)
end

local function watchPlayer(player: Player)
	if playerTroves[player] then
		return
	end
	local playerTrove = trove:Extend() :: any
	playerTroves[player] = playerTrove

	playerTrove:Connect(player.CharacterAdded, function(character: Model)
		watchCharacter(player, character, playerTrove)
	end)
	playerTrove:Connect(player.CharacterRemoving, function()
		-- Interns despawn WITH the owner — a headless squad standing around
		-- a death spot reads as a bug.
		unwatchCharacter(player)
	end)
	local character = player.Character
	if character then
		watchCharacter(player, character, playerTrove)
	end
end

local function unwatchPlayer(player: Player)
	unwatchCharacter(player)
	local playerTrove = playerTroves[player]
	if playerTrove then
		playerTroves[player] = nil
		playerTrove:Destroy()
	end
end

-- ── Movement ────────────────────────────────────────────────────────────────

local function slotOffset(index: number, count: number): Vector3
	-- Centred fan straight behind the owner (+Z local is behind).
	local angle = math.pi + (index - (count + 1) / 2) * SLOT_SPACING
	return Vector3.new(math.sin(angle) * FOLLOW_RADIUS, 0, -math.cos(angle) * FOLLOW_RADIUS)
end

local function stampFigure(visual: InternVisual, cf: CFrame, scale: number)
	-- Resizing is the expensive half of a stamp; it only happens during the
	-- spawn pop, after which scale sits at exactly 1 forever.
	local resize = math.abs(scale - visual.LastScale) > 0.001
	if resize then
		visual.LastScale = scale
	end
	for _, def in visual.PartDefs do
		def.Part.CFrame = cf * CFrame.new(def.Offset * scale)
		if resize then
			def.Part.Size = def.BaseSize * scale
		end
	end
end

local function updateIntern(visual: InternVisual, index: number, count: number, root: BasePart, dt: number, now: number)
	local rootCf = root.CFrame
	local slotTarget = (rootCf * CFrame.new(slotOffset(index, count))).Position
	-- Feet track the owner's floor height, not the tilt of their root part.
	local target = Vector3.new(slotTarget.X, rootCf.Position.Y - ROOT_TO_GROUND, slotTarget.Z)

	local toTarget = target - visual.Position
	local distance = toTarget.Magnitude
	if distance > TELEPORT_DISTANCE then
		visual.Position = target
	elseif distance > 0.001 then
		-- Exponential chase for the smooth trail, with a hard speed cap so a
		-- teleport-adjacent sprint doesn't whip the squad through walls.
		local step = distance * (1 - math.exp(-dt * SMOOTHING))
		step = math.min(step, MAX_SPEED * dt)
		visual.Position += toTarget.Unit * step
	end

	-- Face wherever the owner faces, eased so turns wash through the squad.
	local look = rootCf.LookVector
	local desiredYaw = math.atan2(-look.X, -look.Z)
	local yawDelta = (desiredYaw - visual.Yaw + math.pi) % (math.pi * 2) - math.pi
	visual.Yaw += yawDelta * math.min(dt * 10, 1)

	local wobble = math.sin(now * BOB_SPEED + visual.Phase)
	local age = now - visual.SpawnedAt
	local scale = if age >= SPAWN_POP_SECONDS
		then 1
		else math.max(elasticOut(age / SPAWN_POP_SECONDS), 0.05)

	local cf = CFrame.new(visual.Position + Vector3.new(0, 0.14 + wobble * 0.12, 0))
		* CFrame.Angles(0, visual.Yaw + wobble * 0.07, 0)
	stampFigure(visual, cf, scale)
end

-- Beyond this range an intern squad is a few pixels tall, so the per-frame
-- formation math buys nothing. Matches the culling other renderers use.
local CULL_DISTANCE = 200

local function onRenderStepped(dt: number)
	local now = os.clock()
	local camera = workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	for _, entry in owners do
		local root = entry.Root
		if not (root and root.Parent) then
			local candidate = entry.Character:FindFirstChild("HumanoidRootPart")
			root = if candidate and candidate:IsA("BasePart") then candidate else nil
			entry.Root = root
		end
		if not root then
			continue -- character still assembling; next frame will find it
		end
		local far = (root.Position - eye).Magnitude > CULL_DISTANCE
		local count = #entry.Visuals
		for index, visual in entry.Visuals do
			if far then
				-- Park the squad on its slot instead of animating it. Snapping
				-- rather than smoothing means that when the owner comes back
				-- into view the interns are already in formation, not chasing
				-- across the floor from wherever they were left.
				local rootCf = root.CFrame
				local slot = (rootCf * CFrame.new(slotOffset(index, count))).Position
				visual.Position = Vector3.new(slot.X, rootCf.Position.Y - ROOT_TO_GROUND, slot.Z)
			else
				updateIntern(visual, index, count, root, dt, now)
			end
		end
	end
end

-- ── Lifecycle ───────────────────────────────────────────────────────────────

function InternRenderer:Init()
	local container = Instance.new("Folder")
	container.Name = "InternVisuals"
	container.Parent = workspace
	trove:Add(container)
	folder = container
end

function InternRenderer:Start()
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	trove:Connect(Players.PlayerAdded, watchPlayer)
	trove:Connect(Players.PlayerRemoving, unwatchPlayer)
	trove:Connect(RunService.RenderStepped, onRenderStepped)
end

return InternRenderer
