--!strict
-- RivalRenderer — the visible body of every rival, built entirely on this
-- client. The server replicates pure state (RivalState Full/Delta) and this
-- controller turns it into blocky office workers: workload billboards, a
-- procedural typing idle, damage flinches, and the defeat gag — a swivel
-- chair appears, the rival slumps into it and spins away down the aisle.
--
-- Everything here is cosmetic; damage is validated server-side. These models
-- exist only to LOOK right and to carry the "RivalModel" tag + "RivalId"
-- attribute that ClickController raycasts and PopupController anchors to.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))
local Rivals = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Rivals"))
local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Format"))
local SoundController = require(script.Parent:WaitForChild("SoundController"))
local CameraFx = require(script.Parent:WaitForChild("CameraFx"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local rivalStateRemote = remotes:WaitForChild("RivalState") :: RemoteEvent

-- Rivals beyond this radius keep their billboards fresh but skip pose
-- animation entirely — six floors of typing arms would be pure waste.
local ANIMATE_RADIUS_STUDS = 200
local QUARTER_PASS_SECONDS = 0.25

local BOSS_SCALE = 2.5
local BOSS_LINE_RADIUS_STUDS = 25

-- Where the body bends when leaning; also the seat reference for the gag.
local HIP_HEIGHT = 2

local FLINCH_SECONDS = 0.45
local SLUMP_SECONDS = 0.35
local SLIDE_SECONDS = 1.4
local SLIDE_STUDS = 40
local SLIDE_SPINS = math.pi * 6 -- three full turns, decaying with the slide
local FADE_START_ALPHA = 0.55 -- fade begins this far into the slide
local RESPAWN_POP_SECONDS = 0.55

local ARM_TYPING_BASE = math.rad(-58) -- forearms reach toward an unseen desk
local ARM_TYPING_SWING = math.rad(9)
local TYPING_SPEED = 9

local SKIN_COLOR = Color3.fromRGB(255, 205, 148)
local TROUSER_COLOR = Color3.fromRGB(58, 60, 72)
local BOSS_TIE_COLOR = Color3.fromRGB(206, 44, 44)
local BAR_GREEN = Color3.fromRGB(88, 200, 92)
local BAR_ORANGE = Color3.fromRGB(245, 166, 50)
local BAR_RED = Color3.fromRGB(228, 70, 60)
local PANEL_DARK = Color3.fromRGB(43, 47, 58)
local GOLD = Color3.fromRGB(255, 196, 40)

-- Wire shapes, exactly as RivalService sends them (CONTRACTS.md).
type WireRival = {
	Id: string,
	DefIndex: number,
	Cf: { number }, -- 12 raw CFrame components
	Remaining: number,
	RespawnAt: number,
}
type WireDelta = {
	Id: string,
	Remaining: number,
	RespawnAt: number,
}
type RivalStateMsg = {
	Full: { WireRival }?,
	Delta: { WireDelta }?,
}

type StaticVisual = {
	Part: Part,
	Offset: Vector3, -- from the figure root (feet centre), build-scale baked in
	AboveHips: boolean, -- whether the lean pivot applies
	BaseSize: Vector3,
}
type LimbVisual = {
	Part: Part,
	Pivot: Vector3, -- shoulder/hip point the limb rotates around
	HalfLength: number,
	BaseSize: Vector3,
}
type Pose = {
	Scale: number, -- uniform (respawn pop)
	Squash: number, -- vertical squash, <1 compresses + bulges outward
	Lean: number, -- upper-body pitch at the hips
	ArmPitchL: number,
	ArmPitchR: number,
	LegPitch: number,
	YOffset: number,
}

type RivalVisual = {
	Id: string,
	BaseCf: CFrame,
	MaxWorkload: number,
	Remaining: number,
	ShownRemaining: number, -- lerped display value so the bar drains smoothly
	RespawnAt: number,
	IsBoss: boolean,
	BuildScale: number,
	HipHeight: number,
	Model: Model,
	Statics: { StaticVisual },
	Arms: { LimbVisual }, -- [1] left, [2] right
	Legs: { LimbVisual },
	AllParts: { BasePart },
	WorkGui: BillboardGui,
	BarFill: Frame,
	RemainingLabel: TextLabel,
	BubbleGui: BillboardGui?, -- boss speech bubble
	BubbleScale: UIScale?,
	BubbleShown: boolean,
	OooGui: BillboardGui,
	OooCountdown: TextLabel,
	Emitter: ParticleEmitter,
	Near: boolean,
	Dead: boolean,
	Animating: boolean, -- a defeat/respawn coroutine owns the pose right now
	Destroyed: boolean, -- set on Full rebuild so stale coroutines self-abort
	Phase: number, -- random offset so rivals never type in unison
	FlinchAt: number,
	LastSy: number, -- cached scale factors so parts resize only when needed
	LastSxz: number,
}

local RivalRenderer = {}

local trove = Trove.new()
local rng = Random.new()
local folder: Folder? = nil
local visuals: { [string]: RivalVisual } = {}
-- Chairs pooled per build scale (bosses need a 2.5x throne to slump into).
local chairPools: { [number]: { Model } } = {}
local quarterAccumulator = 0

-- ── Small math helpers (manual easings; TweenService can't drive our poses) ──

local function quadOut(alpha: number): number
	return 1 - (1 - alpha) * (1 - alpha)
end

local function quartOut(alpha: number): number
	local inverse = 1 - alpha
	return 1 - inverse * inverse * inverse * inverse
end

local function backOut(alpha: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	local shifted = alpha - 1
	return 1 + c3 * shifted * shifted * shifted + c1 * shifted * shifted
end

local function elasticOut(alpha: number): number
	if alpha <= 0 then
		return 0
	end
	if alpha >= 1 then
		return 1
	end
	return 2 ^ (-10 * alpha) * math.sin((alpha * 10 - 0.75) * (2 * math.pi / 3)) + 1
end

local function cfFromComponents(components: { number }): CFrame
	-- Spelled out because CFrame.new's 12-number overload wants exact arity.
	return CFrame.new(
		components[1], components[2], components[3],
		components[4], components[5], components[6],
		components[7], components[8], components[9],
		components[10], components[11], components[12]
	)
end

-- ── Part + billboard construction ───────────────────────────────────────────

-- Body parts must stay raycast-visible (CanQuery) — they ARE the click target.
local function bodyPart(parent: Instance, name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function makeLabel(parent: Instance, text: string, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 2.5
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	label.Parent = parent
	return label
end

-- Two-segment ramp: green fades to orange over the top half, orange to red
-- over the bottom — the "almost beaten" read a plain lerp would mush out.
local function barColor(fraction: number): Color3
	if fraction > 0.5 then
		return BAR_ORANGE:Lerp(BAR_GREEN, (fraction - 0.5) * 2)
	end
	return BAR_RED:Lerp(BAR_ORANGE, fraction * 2)
end

local function buildWorkloadBillboard(visual: RivalVisual, head: Part, title: string, bossName: string?)
	local isBoss = visual.IsBoss
	local gui = Instance.new("BillboardGui")
	gui.Name = "Workload"
	gui.Adornee = head
	-- Boss gets the fat marquee treatment: bigger board, hoisted high, visible
	-- from across the wing so the destination reads before the walk.
	gui.Size = if isBoss then UDim2.fromScale(13, 3.6) else UDim2.fromScale(7.5, 2.3)
	gui.ExtentsOffsetWorldSpace = Vector3.new(0, if isBoss then 2.2 else 1.6, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = if isBoss then 400 else 220

	if isBoss and bossName then
		local name = makeLabel(gui, bossName, GOLD)
		name.Size = UDim2.fromScale(1, 0.38)
		local subtitle = makeLabel(gui, title, Color3.fromRGB(235, 235, 235))
		subtitle.Position = UDim2.fromScale(0, 0.38)
		subtitle.Size = UDim2.fromScale(1, 0.2)
	else
		local name = makeLabel(gui, title, Color3.fromRGB(255, 255, 255))
		name.Size = UDim2.fromScale(1, 0.5)
	end

	local barBg = Instance.new("Frame")
	barBg.AnchorPoint = Vector2.new(0.5, 1)
	barBg.Position = UDim2.fromScale(0.5, 1)
	barBg.Size = UDim2.fromScale(1, if isBoss then 0.36 else 0.42)
	barBg.BackgroundColor3 = PANEL_DARK
	barBg.BorderSizePixel = 0
	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0.5, 0) -- full pill = the chunky read
	bgCorner.Parent = barBg
	local bgStroke = Instance.new("UIStroke")
	bgStroke.Color = Color3.fromRGB(0, 0, 0)
	bgStroke.Thickness = 2.5
	bgStroke.Parent = barBg
	barBg.Parent = gui

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = BAR_GREEN
	fill.BorderSizePixel = 0
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0.5, 0)
	fillCorner.Parent = fill
	fill.Parent = barBg

	local remainingLabel = makeLabel(barBg, "", Color3.fromRGB(255, 255, 255))
	remainingLabel.Size = UDim2.fromScale(1, 1)
	remainingLabel.ZIndex = 3

	gui.Parent = head
	visual.WorkGui = gui
	visual.BarFill = fill
	visual.RemainingLabel = remainingLabel
end

local function buildBossBubble(visual: RivalVisual, head: Part, line: string)
	local gui = Instance.new("BillboardGui")
	gui.Name = "BossLine"
	gui.Adornee = head
	gui.Size = UDim2.fromScale(11, 3)
	-- Stacked above the workload board so name, bar and quip never overlap.
	gui.ExtentsOffsetWorldSpace = Vector3.new(0, 3.6, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Enabled = false

	local bubble = Instance.new("Frame")
	bubble.AnchorPoint = Vector2.new(0.5, 0.5)
	bubble.Position = UDim2.fromScale(0.5, 0.42)
	bubble.Size = UDim2.fromScale(1, 0.78)
	bubble.BackgroundColor3 = Color3.fromRGB(250, 250, 250)
	bubble.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.35, 0)
	corner.Parent = bubble
	bubble.Parent = gui

	-- The little diamond tail is what makes it read "speech", not "sign".
	local tail = Instance.new("Frame")
	tail.AnchorPoint = Vector2.new(0.5, 0.5)
	tail.Position = UDim2.fromScale(0.5, 1)
	tail.Size = UDim2.fromScale(0.055, 0.24)
	tail.Rotation = 45
	tail.BackgroundColor3 = Color3.fromRGB(250, 250, 250)
	tail.BorderSizePixel = 0
	tail.Parent = bubble

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(0.92, 0.76)
	text.AnchorPoint = Vector2.new(0.5, 0.5)
	text.Position = UDim2.fromScale(0.5, 0.5)
	text.Font = Enum.Font.FredokaOne
	text.Text = "“" .. line .. "”"
	text.TextColor3 = Color3.fromRGB(40, 42, 52)
	text.TextScaled = true
	text.TextWrapped = true
	text.Parent = bubble

	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = bubble

	gui.Parent = head
	visual.BubbleGui = gui
	visual.BubbleScale = scale
end

local function buildOooSign(visual: RivalVisual, anchor: Part)
	local gui = Instance.new("BillboardGui")
	gui.Name = "OutOfOffice"
	gui.Adornee = anchor
	gui.Size = UDim2.fromScale(6.8, 2.1)
	gui.LightInfluence = 0
	gui.MaxDistance = 200
	gui.Enabled = false

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = PANEL_DARK
	panel.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 2
	stroke.Parent = panel
	panel.Parent = gui

	local heading = makeLabel(panel, "OUT OF OFFICE", GOLD)
	heading.Size = UDim2.fromScale(0.92, 0.5)
	heading.AnchorPoint = Vector2.new(0.5, 0)
	heading.Position = UDim2.fromScale(0.5, 0.05)

	local countdown = makeLabel(panel, "", Color3.fromRGB(235, 235, 235))
	countdown.Size = UDim2.fromScale(0.92, 0.34)
	countdown.AnchorPoint = Vector2.new(0.5, 0)
	countdown.Position = UDim2.fromScale(0.5, 0.56)

	gui.Parent = anchor
	visual.OooGui = gui
	visual.OooCountdown = countdown
end

local function buildPaperEmitter(torso: Part): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "PaperBurst"
	-- Default particle texture only — asset ids from the Toolbox are banned,
	-- and white square-ish confetti reads as flying paperwork just fine.
	emitter.Enabled = false
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Speed = NumberRange.new(9, 16)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rotation = NumberRange.new(-180, 180)
	emitter.RotSpeed = NumberRange.new(-260, 260)
	emitter.Acceleration = Vector3.new(0, -28, 0)
	emitter.Color = ColorSequence.new(Color3.fromRGB(246, 246, 240))
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0.5),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = torso
	return emitter
end

-- ── Pose engine ─────────────────────────────────────────────────────────────

local function applyPose(visual: RivalVisual, baseCf: CFrame, pose: Pose)
	local sy = pose.Scale * pose.Squash
	-- Squash conserves apparent volume: what leaves the height goes to width.
	local sxz = pose.Scale * (1 + (1 - pose.Squash) * 0.6)

	-- Resizing is much dearer than re-CFraming, so only do it when the scale
	-- factors actually moved (idle frames never resize).
	local resize = math.abs(sy - visual.LastSy) > 0.003 or math.abs(sxz - visual.LastSxz) > 0.003
	if resize then
		visual.LastSy = sy
		visual.LastSxz = sxz
	end

	local rootCf = baseCf * CFrame.new(0, pose.YOffset, 0)
	local hipY = visual.HipHeight * sy
	local hipVec = Vector3.new(0, hipY, 0)
	local leanCf = rootCf * CFrame.new(0, hipY, 0) * CFrame.Angles(pose.Lean, 0, 0)

	for _, static in visual.Statics do
		local offset = Vector3.new(static.Offset.X * sxz, static.Offset.Y * sy, static.Offset.Z * sxz)
		if static.AboveHips then
			static.Part.CFrame = leanCf * CFrame.new(offset - hipVec)
		else
			static.Part.CFrame = rootCf * CFrame.new(offset)
		end
		if resize then
			static.Part.Size = Vector3.new(static.BaseSize.X * sxz, static.BaseSize.Y * sy, static.BaseSize.Z * sxz)
		end
	end

	for side, arm in visual.Arms do
		local pitch = if side == 1 then pose.ArmPitchL else pose.ArmPitchR
		local pivot = Vector3.new(arm.Pivot.X * sxz, arm.Pivot.Y * sy, arm.Pivot.Z * sxz)
		arm.Part.CFrame = leanCf
			* CFrame.new(pivot - hipVec)
			* CFrame.Angles(pitch, 0, 0)
			* CFrame.new(0, -arm.HalfLength * sy, 0)
		if resize then
			arm.Part.Size = Vector3.new(arm.BaseSize.X * sxz, arm.BaseSize.Y * sy, arm.BaseSize.Z * sxz)
		end
	end

	for _, leg in visual.Legs do
		local pivot = Vector3.new(leg.Pivot.X * sxz, leg.Pivot.Y * sy, leg.Pivot.Z * sxz)
		leg.Part.CFrame = rootCf
			* CFrame.new(pivot)
			* CFrame.Angles(pose.LegPitch, 0, 0)
			* CFrame.new(0, -leg.HalfLength * sy, 0)
		if resize then
			leg.Part.Size = Vector3.new(leg.BaseSize.X * sxz, leg.BaseSize.Y * sy, leg.BaseSize.Z * sxz)
		end
	end
end

local function standingPose(): Pose
	return {
		Scale = 1,
		Squash = 1,
		Lean = math.rad(5),
		ArmPitchL = ARM_TYPING_BASE,
		ArmPitchR = ARM_TYPING_BASE,
		LegPitch = 0,
		YOffset = 0,
	}
end

-- Recent hits compress the body then let it spring back past neutral — the
-- decaying cosine gives squash-and-stretch without any tween bookkeeping.
local function squashFromFlinch(visual: RivalVisual, now: number): number
	local age = now - visual.FlinchAt
	if age < 0 or age >= FLINCH_SECONDS then
		return 1
	end
	return 1 - 0.2 * math.exp(-age * 7) * math.cos(age * 24)
end

local function animateIdle(visual: RivalVisual, now: number)
	local wave = now * TYPING_SPEED + visual.Phase
	applyPose(visual, visual.BaseCf, {
		Scale = 1,
		Squash = squashFromFlinch(visual, now),
		Lean = math.rad(5) + math.sin(now * 1.7 + visual.Phase) * math.rad(2),
		ArmPitchL = ARM_TYPING_BASE + math.sin(wave) * ARM_TYPING_SWING,
		ArmPitchR = ARM_TYPING_BASE + math.sin(wave + math.pi) * ARM_TYPING_SWING,
		LegPitch = 0,
		YOffset = math.sin(now * 2.1 + visual.Phase) * 0.06,
	})
end

-- ── Bar + billboard updates ─────────────────────────────────────────────────

local function updateBar(visual: RivalVisual)
	local fraction = 0
	if visual.MaxWorkload > 0 then
		fraction = math.clamp(visual.ShownRemaining / visual.MaxWorkload, 0, 1)
	end
	visual.BarFill.Size = UDim2.fromScale(math.max(fraction, 0.03), 1)
	visual.BarFill.BackgroundColor3 = barColor(fraction)
	visual.RemainingLabel.Text = Format.abbreviate(visual.ShownRemaining)
end

local function setBubbleShown(visual: RivalVisual, shown: boolean)
	visual.BubbleShown = shown
	local gui = visual.BubbleGui
	local scale = visual.BubbleScale
	if not (gui and scale) then
		return
	end
	if shown then
		gui.Enabled = true
		TweenService:Create(
			scale,
			TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
	else
		TweenService:Create(
			scale,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = 0 }
		):Play()
		task.delay(0.2, function()
			-- Only disable if nothing re-showed the bubble during the tween.
			if not visual.BubbleShown then
				gui.Enabled = false
			end
		end)
	end
end

local function setBodyTransparency(visual: RivalVisual, transparency: number)
	for _, part in visual.AllParts do
		part.Transparency = transparency
	end
end

-- ── The swivel chair ────────────────────────────────────────────────────────

local function buildChair(scale: number): Model
	local chair = Instance.new("Model")
	chair.Name = "GagChair"

	local function chairPart(size: Vector3, cf: CFrame, color: Color3): Part
		local part = Instance.new("Part")
		part.Size = size * scale
		part.CFrame = cf
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		-- The chair must never eat a click aimed at a rival behind it.
		part.CanQuery = false
		part.CastShadow = false
		part.Massless = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = chair
		return part
	end

	local dark = Color3.fromRGB(48, 48, 56)
	local frameColor = Color3.fromRGB(88, 90, 100)
	-- Cylinder axes run along X, so a 90° Z roll stands them upright.
	local upright = CFrame.Angles(0, 0, math.rad(90))

	local base = chairPart(Vector3.new(0.25, 2.4, 2.4), CFrame.new(0, 0.12 * scale, 0) * upright, frameColor)
	base.Shape = Enum.PartType.Cylinder
	local pole = chairPart(Vector3.new(1.2, 0.3, 0.3), CFrame.new(0, 0.8 * scale, 0) * upright, frameColor)
	pole.Shape = Enum.PartType.Cylinder
	chairPart(Vector3.new(2.0, 0.35, 2.0), CFrame.new(0, 1.5 * scale, 0), dark)
	chairPart(Vector3.new(1.9, 2.3, 0.35), CFrame.new(0, 2.6 * scale, 0.95 * scale), dark)
	for _, x in { -1.05, 1.05 } do
		chairPart(Vector3.new(0.25, 0.5, 1.2), CFrame.new(x * scale, 1.95 * scale, 0.15 * scale), frameColor)
	end

	-- Pivot at the floor under the seat, so PivotTo(spot) plants it exactly
	-- where the rival was standing.
	chair.WorldPivot = CFrame.new(0, 0, 0)
	return chair
end

local function acquireChair(scale: number): Model
	local pool = chairPools[scale]
	if not pool then
		pool = {}
		chairPools[scale] = pool
	end
	local chair = table.remove(pool) or buildChair(scale)
	chair.Parent = folder
	return chair
end

local function releaseChair(chair: Model, scale: number, wasDestroyed: boolean)
	if wasDestroyed then
		-- A Full rebuild wiped the folder mid-gag; this chair is already dead.
		chair:Destroy()
		return
	end
	for _, part in chair:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = 0
		end
	end
	chair.Parent = nil
	table.insert(chairPools[scale], chair)
end

-- ── Defeat + respawn sequences ──────────────────────────────────────────────

-- Coroutines both here and in the respawn pop take exclusive ownership of the
-- pose; the idle loop checks Animating and stays away until they finish.
local function claimPose(visual: RivalVisual): boolean
	while visual.Animating do
		if visual.Destroyed then
			return false
		end
		RunService.Heartbeat:Wait()
	end
	if visual.Destroyed then
		return false
	end
	visual.Animating = true
	return true
end

local function lerp(a: number, b: number, alpha: number): number
	return a + (b - a) * alpha
end

local function runDefeatGag(visual: RivalVisual)
	if not claimPose(visual) then
		return
	end
	local scale = visual.BuildScale
	local baseCf = visual.BaseCf
	visual.WorkGui.Enabled = false
	setBubbleShown(visual, false)

	SoundController.playAt(if visual.IsBoss then "BossDefeated" else "RivalDefeated", baseCf.Position)
	visual.Emitter:Emit(if visual.IsBoss then 70 else 30)
	if visual.IsBoss and visual.Near then
		CameraFx.shake(0.45)
	end

	local chair = acquireChair(scale)
	local chairParts: { BasePart } = {}
	for _, part in chair:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(chairParts, part)
		end
	end

	-- Pose targets for the slump. Hips drop from standing height to just
	-- above the seat; legs kick forward; arms give up entirely.
	local seatDrop = -0.3 * scale
	local stand = standingPose()

	-- Phase 1: chair pops up from the floor (Back overshoot) while the rival
	-- collapses into it (Quad).
	local elapsed = 0
	while elapsed < SLUMP_SECONDS do
		if visual.Destroyed then
			releaseChair(chair, scale, true)
			return
		end
		local alpha = quadOut(math.clamp(elapsed / SLUMP_SECONDS, 0, 1))
		chair:PivotTo(baseCf * CFrame.new(0, -1.2 * scale * (1 - backOut(math.clamp(elapsed / SLUMP_SECONDS, 0, 1))), 0))
		applyPose(visual, baseCf, {
			Scale = 1,
			Squash = 1,
			Lean = lerp(stand.Lean, math.rad(-24), alpha),
			ArmPitchL = lerp(stand.ArmPitchL, math.rad(-10), alpha),
			ArmPitchR = lerp(stand.ArmPitchR, math.rad(-12), alpha),
			LegPitch = lerp(0, math.rad(-74), alpha),
			YOffset = lerp(0, seatDrop, alpha),
		})
		elapsed += RunService.Heartbeat:Wait()
	end

	-- Phase 2: the ride. Quart-out front-loads the speed so it launches hard
	-- and coasts to a stop 40 studs down the aisle, spinning all the way.
	local slideDir = baseCf.RightVector
	local slumped: Pose = {
		Scale = 1,
		Squash = 1,
		Lean = math.rad(-24),
		ArmPitchL = math.rad(-10),
		ArmPitchR = math.rad(-12),
		LegPitch = math.rad(-74),
		YOffset = seatDrop,
	}
	elapsed = 0
	while elapsed < SLIDE_SECONDS do
		if visual.Destroyed then
			releaseChair(chair, scale, true)
			return
		end
		local alpha = quartOut(math.clamp(elapsed / SLIDE_SECONDS, 0, 1))
		local rideCf = (baseCf + slideDir * (alpha * SLIDE_STUDS)) * CFrame.Angles(0, alpha * SLIDE_SPINS, 0)
		chair:PivotTo(rideCf)
		applyPose(visual, rideCf, slumped)
		if alpha > FADE_START_ALPHA then
			local fade = quadOut((alpha - FADE_START_ALPHA) / (1 - FADE_START_ALPHA))
			setBodyTransparency(visual, fade)
			for _, part in chairParts do
				part.Transparency = fade
			end
		end
		elapsed += RunService.Heartbeat:Wait()
	end

	if visual.Destroyed then
		releaseChair(chair, scale, true)
		return
	end
	releaseChair(chair, scale, false)
	setBodyTransparency(visual, 1)
	if visual.Dead then
		visual.OooGui.Enabled = true
	end
	visual.Animating = false
end

local function runRespawnPop(visual: RivalVisual)
	if not claimPose(visual) then
		return
	end
	visual.OooGui.Enabled = false
	setBodyTransparency(visual, 0)
	visual.WorkGui.Enabled = true

	local elapsed = 0
	while elapsed < RESPAWN_POP_SECONDS do
		if visual.Destroyed then
			return
		end
		local alpha = math.clamp(elapsed / RESPAWN_POP_SECONDS, 0, 1)
		local pose = standingPose()
		-- Elastic overshoot: they snap back to their desk like nothing happened.
		pose.Scale = math.max(elasticOut(alpha), 0.05)
		applyPose(visual, visual.BaseCf, pose)
		elapsed += RunService.Heartbeat:Wait()
	end

	if visual.Destroyed then
		return
	end
	applyPose(visual, visual.BaseCf, standingPose())
	visual.Animating = false
end

-- ── Building one rival ──────────────────────────────────────────────────────

-- Shirt/tie colours keyed off DefIndex with the golden-ratio hue walk, so
-- every rung of the ladder is a distinct, stable colour on every floor.
local function shirtColorFor(defIndex: number): (Color3, Color3)
	local hue = (defIndex * 0.618034) % 1
	local shirt = Color3.fromHSV(hue, 0.55, 0.9)
	local tie = Color3.fromHSV((hue + 0.5) % 1, 0.75, 0.55)
	return shirt, tie
end

local function buildVisual(entry: WireRival): RivalVisual?
	local parentFolder = folder
	if not parentFolder then
		return nil
	end
	local floorId, defIndex = Rivals.parse(entry.Id)
	local def = if floorId and defIndex then Rivals.get(floorId, defIndex) else nil
	if not def then
		-- A rival we can't identify has no title, workload max or boss flag;
		-- better one missing body than a crash for everyone.
		warn(`[RivalRenderer] unknown rival id "{entry.Id}" — skipping`)
		return nil
	end

	local isBoss = def.IsBoss == true
	local scale = if isBoss then BOSS_SCALE else 1
	local baseCf = cfFromComponents(entry.Cf)
	local shirt, tie = shirtColorFor(entry.DefIndex)
	if isBoss then
		tie = BOSS_TIE_COLOR
	end

	local model = Instance.new("Model")
	model.Name = if isBoss and def.BossName then def.BossName else def.Title
	CollectionService:AddTag(model, "RivalModel")
	model:SetAttribute("RivalId", entry.Id)

	local visual: RivalVisual = {
		Id = entry.Id,
		BaseCf = baseCf,
		MaxWorkload = def.Workload,
		Remaining = entry.Remaining,
		ShownRemaining = entry.Remaining,
		RespawnAt = entry.RespawnAt,
		IsBoss = isBoss,
		BuildScale = scale,
		HipHeight = HIP_HEIGHT * scale,
		Model = model,
		Statics = {},
		Arms = {},
		Legs = {},
		AllParts = {},
		WorkGui = nil :: any, -- assigned by buildWorkloadBillboard below
		BarFill = nil :: any,
		RemainingLabel = nil :: any,
		BubbleGui = nil,
		BubbleScale = nil,
		BubbleShown = false,
		OooGui = nil :: any, -- assigned by buildOooSign below
		OooCountdown = nil :: any,
		Emitter = nil :: any, -- assigned right after the torso exists
		Near = false,
		Dead = false,
		Animating = false,
		Destroyed = false,
		Phase = rng:NextNumber(0, math.pi * 2),
		FlinchAt = -math.huge,
		LastSy = 0,
		LastSxz = 0,
	}

	local function addStatic(name: string, size: Vector3, offset: Vector3, color: Color3, aboveHips: boolean): Part
		local part = bodyPart(model, name, size * scale, color)
		table.insert(visual.Statics, {
			Part = part,
			Offset = offset * scale,
			AboveHips = aboveHips,
			BaseSize = part.Size,
		})
		table.insert(visual.AllParts, part)
		return part
	end

	local function addLimb(list: { LimbVisual }, name: string, size: Vector3, pivot: Vector3, halfLength: number, color: Color3)
		local part = bodyPart(model, name, size * scale, color)
		table.insert(list, {
			Part = part,
			Pivot = pivot * scale,
			HalfLength = halfLength * scale,
			BaseSize = part.Size,
		})
		table.insert(visual.AllParts, part)
	end

	local torso = addStatic("Torso", Vector3.new(1.9, 2, 1.05), Vector3.new(0, 3, 0), shirt, true)
	local head = addStatic("Head", Vector3.new(1.35, 1.35, 1.35), Vector3.new(0, 4.7, 0), SKIN_COLOR, true)
	addStatic("Tie", Vector3.new(0.42, 1.15, 0.14), Vector3.new(0, 3.35, -0.6), tie, true)
	if isBoss then
		-- Shoulder-pad menace: the silhouette says "final form of middle
		-- management" before the name tag is even readable.
		addStatic("LeftPad", Vector3.new(1.25, 0.55, 1.25), Vector3.new(-1.35, 4.15, 0), shirt, true)
		addStatic("RightPad", Vector3.new(1.25, 0.55, 1.25), Vector3.new(1.35, 4.15, 0), shirt, true)
	end
	addLimb(visual.Arms, "LeftArm", Vector3.new(0.72, 1.8, 0.72), Vector3.new(-1.3, 3.8, 0), 0.9, shirt)
	addLimb(visual.Arms, "RightArm", Vector3.new(0.72, 1.8, 0.72), Vector3.new(1.3, 3.8, 0), 0.9, shirt)
	addLimb(visual.Legs, "LeftLeg", Vector3.new(0.85, 2, 0.85), Vector3.new(-0.5, 2, 0), 1, TROUSER_COLOR)
	addLimb(visual.Legs, "RightLeg", Vector3.new(0.85, 2, 0.85), Vector3.new(0.5, 2, 0), 1, TROUSER_COLOR)

	visual.Emitter = buildPaperEmitter(torso)

	-- The sign anchor survives the gag (the body slides 40 studs away and
	-- fades), so the OUT OF OFFICE countdown stays planted at the desk.
	local anchor = Instance.new("Part")
	anchor.Name = "SignAnchor"
	anchor.Size = Vector3.one
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor.CFrame = baseCf * CFrame.new(0, 2.6 * scale, 0)
	anchor.Parent = model

	buildWorkloadBillboard(visual, head, def.Title, def.BossName)
	local bossLine = def.BossLine
	if isBoss and bossLine then
		-- Only bosses monologue; everyone else's bubble would be dead weight.
		buildBossBubble(visual, head, bossLine)
	end
	buildOooSign(visual, anchor)

	model.Parent = parentFolder
	applyPose(visual, baseCf, standingPose())
	updateBar(visual)

	-- Joined mid-respawn-timer: skip the gag, start in the waiting state.
	if entry.Remaining <= 0 then
		visual.Dead = true
		visual.ShownRemaining = 0
		setBodyTransparency(visual, 1)
		visual.WorkGui.Enabled = false
		visual.OooGui.Enabled = true
	end

	return visual
end

-- ── Server message handling ─────────────────────────────────────────────────

local function clearAll()
	for _, visual in visuals do
		-- Flag first: in-flight gag coroutines check this every frame and
		-- self-abort instead of posing parts the folder wipe destroys.
		visual.Destroyed = true
	end
	table.clear(visuals)
	local parentFolder = folder
	if parentFolder then
		parentFolder:ClearAllChildren()
	end
end

local function processFull(entries: { WireRival })
	clearAll()
	for _, entry in entries do
		local visual = buildVisual(entry)
		if visual then
			visuals[entry.Id] = visual
		end
	end
end

local function applyDelta(delta: WireDelta)
	local visual = visuals[delta.Id]
	if not visual then
		return -- Full for this floor hasn't landed yet; it will carry this state
	end
	local previous = visual.Remaining
	visual.Remaining = delta.Remaining
	visual.RespawnAt = delta.RespawnAt

	if delta.Remaining <= 0 and not visual.Dead then
		visual.Dead = true
		visual.ShownRemaining = 0
		task.spawn(runDefeatGag, visual)
	elseif delta.Remaining > 0 and visual.Dead then
		visual.Dead = false
		-- Snap the bar full: a respawn that visibly "drains up" reads as damage.
		visual.ShownRemaining = delta.Remaining
		updateBar(visual)
		task.spawn(runRespawnPop, visual)
	elseif delta.Remaining < previous then
		visual.FlinchAt = os.clock()
		if visual.Near then
			visual.Emitter:Emit(4)
		end
	end
end

-- ── The two loops ───────────────────────────────────────────────────────────

-- Every 0.25s: distance flags, respawn countdowns and boss-bubble proximity.
-- None of this needs frame precision, so it stays off the hot path.
local function runQuarterPass()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPosition = camera.CFrame.Position
	local characterPosition = cameraPosition
	local character = Players.LocalPlayer.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			characterPosition = root.Position
		end
	end
	local serverNow = workspace:GetServerTimeNow()

	for _, visual in visuals do
		local position = visual.BaseCf.Position
		visual.Near = (position - cameraPosition).Magnitude <= ANIMATE_RADIUS_STUDS

		if visual.Dead and visual.RespawnAt > 0 then
			local secondsLeft = math.max(0, math.ceil(visual.RespawnAt - serverNow))
			visual.OooCountdown.Text = "back in " .. Format.duration(secondsLeft)
		end

		if visual.BubbleScale then
			-- Bubble proximity is measured from the CHARACTER, not the camera:
			-- the boss talks to the person who walked up, not to a zoomed lens.
			local shouldShow = not visual.Dead
				and (position - characterPosition).Magnitude <= BOSS_LINE_RADIUS_STUDS
			if shouldShow ~= visual.BubbleShown then
				setBubbleShown(visual, shouldShow)
			end
		end
	end
end

local function onHeartbeat(dt: number)
	local now = os.clock()
	for _, visual in visuals do
		-- Bars interpolate for EVERY rival, near or far — a stale bar on
		-- re-approach would contradict what the server already told us.
		local shown = visual.ShownRemaining
		local target = visual.Remaining
		if shown ~= target then
			local difference = target - shown
			if math.abs(difference) < math.max(1, visual.MaxWorkload * 0.002) then
				visual.ShownRemaining = target
			else
				visual.ShownRemaining = shown + difference * math.min(dt * 9, 1)
			end
			updateBar(visual)
		end

		if visual.Near and not visual.Dead and not visual.Animating then
			animateIdle(visual, now)
		end
	end

	quarterAccumulator += dt
	if quarterAccumulator >= QUARTER_PASS_SECONDS then
		quarterAccumulator = 0
		runQuarterPass()
	end
end

-- ── Lifecycle ───────────────────────────────────────────────────────────────

function RivalRenderer:Init()
	local container = Instance.new("Folder")
	container.Name = "RivalVisuals"
	container.Parent = workspace
	trove:Add(container)
	folder = container
end

function RivalRenderer:Start()
	trove:Connect(rivalStateRemote.OnClientEvent, function(msg: RivalStateMsg)
		if msg.Full then
			processFull(msg.Full)
		end
		if msg.Delta then
			for _, delta in msg.Delta do
				applyDelta(delta)
			end
		end
	end)
	trove:Connect(RunService.Heartbeat, onHeartbeat)
end

return RivalRenderer
