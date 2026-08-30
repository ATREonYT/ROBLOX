--!strict
-- The corporate glow-up. Each rank Band (Config/Ranks) maps to a server-built
-- look: suit colors painted straight onto R15 body parts plus procedural props
-- welded on. Server-side on purpose — every player must SEE everyone else's
-- seniority, and clients can't be trusted to dress themselves.
--
-- Every instance this service adds is named "RankProp_..." so a re-apply can
-- strip the previous look with one name sweep, whatever band it was.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(ServerScriptService.Server.Data.DataService)
local Ranks = require(ReplicatedStorage.Shared.Config.Ranks)
local Trove = require(ReplicatedStorage.Packages.Trove)

local PROP_PREFIX = "RankProp_"
local GOLD = Color3.fromRGB(255, 196, 40) -- matches the UI gold (#FFC428)

-- Jacket covers UpperTorso + arms, trousers the LowerTorso. Hands and Head are
-- left alone below Band 5 so skin tone survives the suit.
local JACKET_PARTS = { "UpperTorso", "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm" }
local TROUSER_PARTS = { "LowerTorso" }
-- Chairman is "gold everything": legs and hands too. Head still keeps skin —
-- a gold face reads as a different character, not a promoted one.
local GOLD_EXTRA_PARTS =
	{ "LeftHand", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }

type SuitColors = { Jacket: Color3, Trousers: Color3 }
local SUIT_BY_BAND: { [number]: SuitColors } = {
	-- Band 1 deliberately absent: interns wear their own clothes.
	[2] = { Jacket = Color3.fromRGB(126, 130, 140), Trousers = Color3.fromRGB(98, 102, 112) }, -- off-the-rack grey
	[3] = { Jacket = Color3.fromRGB(47, 58, 94), Trousers = Color3.fromRGB(36, 45, 74) }, -- tailored navy
	[4] = { Jacket = Color3.fromRGB(40, 40, 48), Trousers = Color3.fromRGB(30, 30, 38) }, -- sharp charcoal
	[5] = { Jacket = GOLD, Trousers = Color3.fromRGB(222, 168, 30) }, -- chairman gold
}

type AuraSpec = { Rate: number, Color: Color3, Size: number, LightEmission: number }
local AURA_BY_BAND: { [number]: AuraSpec } = {
	[3] = { Rate = 0.5, Color = Color3.fromRGB(255, 255, 255), Size = 0.22, LightEmission = 0.4 },
	[4] = { Rate = 2, Color = GOLD, Size = 0.3, LightEmission = 0.7 },
	[5] = { Rate = 4, Color = GOLD, Size = 0.38, LightEmission = 0.9 },
}

local AppearanceService = {}

local trove = Trove.new()
-- One child trove per loaded player holds their character connections, so a
-- leaver's connections die without touching anyone else's.
local playerTroves: { [Player]: Trove.Trove } = {}
-- Body colors captured before the first repaint, so a Restructure back down to
-- Band 1 can undress the player without waiting for a respawn.
local originalColors: { [Model]: { [string]: Color3 } } = {}

-- Every part name any band may paint, for snapshot/restore.
local ALL_PAINTABLE: { string } = {}
for _, list in { JACKET_PARTS, TROUSER_PARTS, GOLD_EXTRA_PARTS } do
	for _, partName in list do
		table.insert(ALL_PAINTABLE, partName)
	end
end

local function findPart(character: Model, name: string): BasePart?
	local child = character:FindFirstChild(name)
	return if child and child:IsA("BasePart") then child else nil
end

local function snapshotColors(character: Model)
	if originalColors[character] then
		return -- only the pre-suit colors are worth keeping
	end
	local saved: { [string]: Color3 } = {}
	for _, partName in ALL_PAINTABLE do
		local part = findPart(character, partName)
		if part then
			saved[partName] = part.Color
		end
	end
	originalColors[character] = saved
end

local function restoreOriginalColors(character: Model)
	local saved = originalColors[character]
	if not saved then
		return
	end
	for partName, color in saved do
		local part = findPart(character, partName)
		if part then
			part.Color = color
		end
	end
end

local function paintParts(character: Model, partNames: { string }, color: Color3)
	for _, partName in partNames do
		local part = findPart(character, partName)
		if part then
			part.Color = color
		end
	end
end

local function applySuit(character: Model, band: number)
	local suit = SUIT_BY_BAND[band]
	if not suit then
		-- Band 1: your own clothes — undo any paint left by a pre-Restructure
		-- band. (A destroyed Shirt only comes back on respawn; acceptable.)
		restoreOriginalColors(character)
		return
	end
	snapshotColors(character)
	-- Shirt textures paint over part colors, so the shirt goes. Pants may stay
	-- below Band 5 because those bands never repaint the legs.
	for _, child in character:GetChildren() do
		if child:IsA("Shirt") or child:IsA("ShirtGraphic") or (band >= 5 and child:IsA("Pants")) then
			child:Destroy()
		end
	end
	paintParts(character, JACKET_PARTS, suit.Jacket)
	paintParts(character, TROUSER_PARTS, suit.Trousers)
	if band >= 5 then
		paintParts(character, GOLD_EXTRA_PARTS, GOLD)
	end
end

-- Base prop part: inert to physics and clicks, so props can never block a
-- raycast at a rival or add drag to the character.
local function makeProp(name: string, size: Vector3, color: Color3): Part
	local prop = Instance.new("Part")
	prop.Name = PROP_PREFIX .. name
	prop.Size = size
	prop.Color = color
	prop.Material = Enum.Material.SmoothPlastic
	prop.CanCollide = false
	prop.CanQuery = false
	prop.CanTouch = false
	prop.Massless = true
	prop.CastShadow = false
	prop.TopSurface = Enum.SurfaceType.Smooth
	prop.BottomSurface = Enum.SurfaceType.Smooth
	return prop
end

local function weldProp(prop: BasePart, anchor: BasePart, offset: CFrame)
	-- CFrame must be right before the WeldConstraint locks in the relative
	-- transform, or the prop welds wherever it happened to spawn.
	prop.CFrame = anchor.CFrame * offset
	prop.Parent = anchor.Parent
	local weld = Instance.new("WeldConstraint")
	weld.Name = PROP_PREFIX .. "Weld"
	weld.Part0 = anchor
	weld.Part1 = prop
	weld.Parent = prop
end

-- Band 1: a lanyard that isn't even yours, and a box of someone else's files.
local function buildBand1(_character: Model, torso: BasePart)
	local strap = makeProp("LanyardStrap", Vector3.new(0.35, 1.4, 0.12), Color3.fromRGB(196, 40, 40))
	weldProp(strap, torso, CFrame.new(0, 0.35, -0.55) * CFrame.Angles(0, 0, math.rad(6)))
	local badge = makeProp("LanyardBadge", Vector3.new(0.85, 1.05, 0.14), Color3.fromRGB(240, 240, 240))
	weldProp(badge, torso, CFrame.new(0.06, -0.45, -0.58) * CFrame.Angles(0, 0, math.rad(3)))
	local box = makeProp("CardboardBox", Vector3.new(2.2, 1.4, 1.6), Color3.fromRGB(190, 149, 100))
	weldProp(box, torso, CFrame.new(0, -0.9, -1.55))
	local tape = makeProp("BoxTape", Vector3.new(0.5, 0.06, 1.62), Color3.fromRGB(150, 111, 66))
	weldProp(tape, torso, CFrame.new(0, -0.17, -1.55))
end

-- Band 2: clipboard in the left hand, oversized mug in the right.
local function buildBand2(character: Model, torso: BasePart)
	local leftHand = findPart(character, "LeftHand") or torso
	local rightHand = findPart(character, "RightHand") or torso
	local board = makeProp("Clipboard", Vector3.new(1.15, 1.5, 0.12), Color3.fromRGB(150, 105, 62))
	weldProp(board, leftHand, CFrame.new(0, 0.2, -0.4) * CFrame.Angles(math.rad(15), 0, 0))
	local paper = makeProp("ClipboardPaper", Vector3.new(0.95, 1.25, 0.13), Color3.fromRGB(245, 245, 245))
	weldProp(paper, leftHand, CFrame.new(0, 0.16, -0.44) * CFrame.Angles(math.rad(15), 0, 0))
	local mug = makeProp("Mug", Vector3.new(0.8, 0.7, 0.7), Color3.fromRGB(235, 235, 235))
	-- Cylinders extend along X, so a 90° Z roll stands the mug upright.
	mug.Shape = Enum.PartType.Cylinder
	weldProp(mug, rightHand, CFrame.new(0, -0.1, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local handle = makeProp("MugHandle", Vector3.new(0.14, 0.4, 0.14), Color3.fromRGB(235, 235, 235))
	weldProp(handle, rightHand, CFrame.new(0.42, -0.1, 0))
end

-- Band 3: a leather briefcase hanging from the right hand.
local function buildBand3(character: Model, torso: BasePart)
	local rightHand = findPart(character, "RightHand") or torso
	local case = makeProp("Briefcase", Vector3.new(1.7, 1.2, 0.5), Color3.fromRGB(87, 58, 36))
	weldProp(case, rightHand, CFrame.new(0, -1.15, 0))
	local handleBar = makeProp("BriefcaseHandle", Vector3.new(0.7, 0.18, 0.18), Color3.fromRGB(60, 40, 24))
	weldProp(handleBar, rightHand, CFrame.new(0, -0.45, 0))
	local trim = makeProp("BriefcaseTrim", Vector3.new(1.72, 0.12, 0.52), GOLD)
	weldProp(trim, rightHand, CFrame.new(0, -1.0, 0))
end

-- Band 4: a tablet hovering at the shoulder, screen always on.
local function buildBand4(_character: Model, torso: BasePart)
	local slabOffset = CFrame.new(1.9, 0.5, -0.6) * CFrame.Angles(0, math.rad(-25), math.rad(8))
	local slab = makeProp("Tablet", Vector3.new(1.5, 2, 0.14), Color3.fromRGB(30, 30, 34))
	weldProp(slab, torso, slabOffset)
	local screen = makeProp("TabletScreen", Vector3.new(1.3, 1.8, 0.16), Color3.fromRGB(120, 220, 255))
	screen.Material = Enum.Material.Neon
	weldProp(screen, torso, slabOffset)
end

-- Band 5: three golden ticker ribbons parked around the torso. The client's
-- WorldFxController animates the orbit; the welds just keep them following the
-- character when that animation is culled by distance.
local function buildBand5(_character: Model, torso: BasePart)
	for index = 1, 3 do
		local ribbon = makeProp("OrbitRibbon" .. index, Vector3.new(2.4, 0.3, 0.08), GOLD)
		ribbon.Material = Enum.Material.Neon
		local angle = (index - 1) * (2 * math.pi / 3)
		weldProp(ribbon, torso, CFrame.Angles(0, angle, 0) * CFrame.new(0, (index - 2) * 0.5, -2))
		CollectionService:AddTag(ribbon, "OrbitRibbon")
	end
end

local bandBuilders: { [number]: (character: Model, torso: BasePart) -> () } = {
	[1] = buildBand1,
	[2] = buildBand2,
	[3] = buildBand3,
	[4] = buildBand4,
	[5] = buildBand5,
}

local function buildAura(torso: BasePart, band: number)
	local spec = AURA_BY_BAND[band]
	if not spec then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = PROP_PREFIX .. "AuraAttachment"
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = PROP_PREFIX .. "AuraEmitter"
	emitter.Rate = spec.Rate
	emitter.Color = ColorSequence.new(spec.Color)
	emitter.LightEmission = spec.LightEmission
	emitter.Lifetime = NumberRange.new(0.9, 1.5)
	emitter.Speed = NumberRange.new(0.6, 1.2)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-40, 40)
	-- Grow-in then shrink-out so sparkles never pop into or out of existence.
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, spec.Size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	-- No Texture set on purpose: the engine's default sparkle keeps this
	-- project free of external asset ids.
	emitter.Parent = attachment
	attachment.Parent = torso
end

local function stripLook(character: Model)
	for _, descendant in character:GetDescendants() do
		if string.find(descendant.Name, PROP_PREFIX, 1, true) == 1 then
			descendant:Destroy()
		end
	end
end

-- Public: (re)dress a player to match their current rank. Safe to call any
-- time; quietly does nothing while the profile or character isn't ready — the
-- next CharacterAdded/PlayerLoaded pass will catch them up.
function AppearanceService.applyFor(player: Player)
	local data = DataService.get(player)
	local character = player.Character
	if not data or not character or character.Parent == nil then
		return
	end
	local rankDef = Ranks.List[data.Rank]
	-- UpperTorso anchors everything; the root part is the R6/odd-rig fallback.
	local torso = findPart(character, "UpperTorso") or findPart(character, "HumanoidRootPart")
	if not rankDef or not torso then
		return
	end
	stripLook(character)
	applySuit(character, rankDef.Band)
	local builder = bandBuilders[rankDef.Band]
	if builder then
		builder(character, torso)
	end
	buildAura(torso, rankDef.Band)
end

local function watchPlayer(player: Player)
	if playerTroves[player] then
		return
	end
	local playerTrove = trove:Extend()
	-- Cast: the old Luau solver can't prove two instantiations of Trove's
	-- generic-method type are identical; the value really is a Trove.
	playerTroves[player] = playerTrove :: any

	playerTrove:Connect(player.CharacterAdded, function(character: Model)
		task.spawn(function()
			-- Limbs stream in after CharacterAdded fires; wait (bounded) for
			-- the anchor part before dressing, or every weld would miss.
			character:WaitForChild("UpperTorso", 10)
			if character.Parent then
				AppearanceService.applyFor(player)
			end
		end)
	end)
	playerTrove:Connect(player.CharacterRemoving, function(character: Model)
		-- Snapshots are per character model; a fresh spawn has fresh colors.
		originalColors[character] = nil
	end)

	if player.Character then
		AppearanceService.applyFor(player)
	end
end

local function unwatchPlayer(player: Player)
	local playerTrove = playerTroves[player]
	if playerTrove then
		playerTroves[player] = nil
		playerTrove:Destroy()
	end
	local character = player.Character
	if character then
		originalColors[character] = nil
	end
end

function AppearanceService:Init()
	-- All wiring happens in Start; nothing here may touch other services.
end

function AppearanceService:Start()
	-- Casts: DataService's Signals are unparameterized Signal.new() values,
	-- which the solver can't match against Trove's SignalLike shape.
	trove:Connect(DataService.PlayerLoaded :: any, function(player: Player)
		watchPlayer(player)
	end)
	trove:Connect(DataService.PlayerUnloading :: any, function(player: Player)
		unwatchPlayer(player)
	end)
end

return AppearanceService
