--!strict
-- WorldFxController — ambient life for CollectionService-tagged props. The
-- map kit (and AppearanceService for OrbitRibbon) tags instances; this
-- controller is the only thing that animates them, all from ONE RenderStepped
-- loop with a slow cull pass so a six-floor tower of monitors costs almost
-- nothing when it's off-screen.
--
-- Tags handled: SpinY, FlickerLight, GlowScreen, IdleBob, OrbitRibbon,
-- WaterShimmer, TickerSign.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")

local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))
local Floors = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Floors"))

local CULL_RADIUS_STUDS = 150
local CULL_PASS_SECONDS = 0.25

local ORBIT_RADIUS = 2
local ORBIT_SPEED = 1.6 -- radians/s

local TICKER_TEXT_COLOR = Color3.fromRGB(255, 196, 40)
local TICKER_BACKDROP_COLOR = Color3.fromRGB(16, 18, 24)

-- The stock ticker of a company that measures everything and learns nothing.
local HEADLINES = {
	"SYNERGY ▲ 12%",
	"MONDAYS ▼ 98%",
	"COFFEE ▲ 340%",
	"PAPERCLIP FUTURES ▲ 7%",
	"MORALE — FLAT",
	"MEETINGS THAT COULD'VE BEEN EMAILS ▲ 61%",
	"STAPLER INDEX ▲ 4%",
	"PRINTER UPTIME ▼ 63%",
	"LUNCH THEFT ▲ 9%",
	"KPI OF KPIS ▲ 200%",
}

type FlickerState = {
	Part: BasePart,
	Light: Light?,
	OriginalColor: Color3,
	DimColor: Color3,
	NeverCull: boolean, -- the Mailroom's mood light animates no matter what
	Active: boolean,
	BurstEndsAt: number, -- 0 = not currently bursting
	NextBurstAt: number,
	NextToggleAt: number,
	IsOn: boolean,
}

type GlowState = {
	Part: BasePart,
	Hue: number,
	Saturation: number,
	Value: number,
	Phase: number,
	NextBlipAt: number,
	BlipUntil: number,
}

type BobState = {
	Part: BasePart,
	OriginalCf: CFrame,
	Phase: number,
}

type OrbitState = {
	Ribbon: BasePart,
	Ghost: BasePart, -- our anchored clone that actually orbits
	Torso: BasePart?,
	Phase: number,
	YOffset: number,
	Active: boolean,
}

type ShimmerState = {
	Part: BasePart,
	OriginalColor: Color3,
	OriginalTransparency: number,
	Phase: number,
}

type TickerState = {
	Part: BasePart,
	Gui: SurfaceGui,
	LabelA: TextLabel,
	LabelB: TextLabel,
	TextWidth: number,
	OffsetX: number,
	Speed: number, -- pixels/s, scaled to the sign's height
}

local WorldFxController = {}

local trove = Trove.new()
local rng = Random.new()
local ghostFolder: Folder? = nil

local flickers: { [BasePart]: FlickerState } = {}
local glows: { [BasePart]: GlowState } = {}
local bobs: { [BasePart]: BobState } = {}
local orbits: { [BasePart]: OrbitState } = {}
local shimmers: { [BasePart]: ShimmerState } = {}
local tickers: { [BasePart]: TickerState } = {}

-- Rebuilt by the cull pass; the frame loop only ever touches these.
local activeFlickers: { FlickerState } = {}
local activeGlows: { GlowState } = {}
local activeBobs: { BobState } = {}
local activeShimmers: { ShimmerState } = {}
local activeTickers: { TickerState } = {}

local cullAccumulator = CULL_PASS_SECONDS -- run the first pass immediately

-- ── Shared helpers ──────────────────────────────────────────────────────────

local function watchTag(tagName: string, onAdded: (Instance) -> (), onRemoved: (Instance) -> ())
	trove:Connect(CollectionService:GetInstanceAddedSignal(tagName), onAdded)
	trove:Connect(CollectionService:GetInstanceRemovedSignal(tagName), onRemoved)
	for _, instance in CollectionService:GetTagged(tagName) do
		onAdded(instance)
	end
end

-- Floors stack vertically at well-separated origins, so the nearest origin Y
-- identifies which floor a prop belongs to without any folder-name coupling.
local function isOnMailroomFloor(position: Vector3): boolean
	local nearestId: string? = nil
	local nearestDistance = math.huge
	for _, floor in Floors.List do
		local distance = math.abs(position.Y - floor.Origin[2])
		if distance < nearestDistance then
			nearestDistance = distance
			nearestId = floor.Id
		end
	end
	return nearestId == "Mailroom"
end

-- ── FlickerLight ────────────────────────────────────────────────────────────

local function setFlickerOn(state: FlickerState, on: boolean)
	state.IsOn = on
	-- Neon↔SmoothPlastic is the whole illusion: Neon ignores lighting, so a
	-- transparency fade would still glow. The material swap actually goes dark.
	state.Part.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
	state.Part.Color = if on then state.OriginalColor else state.DimColor
	local light = state.Light
	if light then
		light.Enabled = on
	end
end

local function updateFlicker(state: FlickerState, now: number)
	if state.BurstEndsAt == 0 then
		if now >= state.NextBurstAt then
			state.BurstEndsAt = now + rng:NextNumber(0.25, 0.9)
			state.NextToggleAt = now
		end
		return
	end
	if now >= state.BurstEndsAt then
		-- Bursts always end lit; a light that settles off would just read as
		-- broken geometry, not a dying fluorescent.
		state.BurstEndsAt = 0
		state.NextBurstAt = now + rng:NextNumber(2.5, 8)
		setFlickerOn(state, true)
	elseif now >= state.NextToggleAt then
		state.NextToggleAt = now + rng:NextNumber(0.03, 0.1)
		setFlickerOn(state, not state.IsOn)
	end
end

local function addFlicker(instance: Instance)
	if not instance:IsA("BasePart") or flickers[instance] then
		return
	end
	local color = instance.Color
	flickers[instance] = {
		Part = instance,
		Light = instance:FindFirstChildWhichIsA("Light"),
		OriginalColor = color,
		DimColor = Color3.new(color.R * 0.3, color.G * 0.3, color.B * 0.3),
		NeverCull = isOnMailroomFloor(instance.Position),
		Active = false,
		BurstEndsAt = 0,
		NextBurstAt = os.clock() + rng:NextNumber(0.5, 4),
		NextToggleAt = 0,
		IsOn = true,
	}
end

local function removeFlicker(instance: Instance)
	local state = flickers[instance :: any]
	if not state then
		return
	end
	flickers[instance :: any] = nil
	setFlickerOn(state, true)
end

-- ── GlowScreen ──────────────────────────────────────────────────────────────

local function updateGlow(state: GlowState, now: number)
	if now < state.BlipUntil then
		-- The "typing" blip: a brief washed-out flash, like a window of text
		-- scrolling past.
		state.Part.Color = Color3.fromHSV(
			state.Hue,
			state.Saturation * 0.4,
			math.min(state.Value * 1.25 + 0.15, 1)
		)
		return
	end
	if now >= state.NextBlipAt then
		state.BlipUntil = now + 0.07
		state.NextBlipAt = now + rng:NextNumber(0.8, 4)
	end
	local hue = (state.Hue + math.sin(now * 0.11 + state.Phase) * 0.05) % 1
	local value = state.Value * (0.9 + 0.1 * math.sin(now * 1.3 + state.Phase))
	state.Part.Color = Color3.fromHSV(hue, state.Saturation, math.clamp(value, 0, 1))
end

local function addGlow(instance: Instance)
	if not instance:IsA("BasePart") or glows[instance] then
		return
	end
	local hue, saturation, value = Color3.toHSV(instance.Color)
	glows[instance] = {
		Part = instance,
		Hue = hue,
		Saturation = saturation,
		Value = value,
		Phase = rng:NextNumber(0, math.pi * 2),
		NextBlipAt = os.clock() + rng:NextNumber(0.5, 3),
		BlipUntil = 0,
	}
end

local function removeGlow(instance: Instance)
	local state = glows[instance :: any]
	if not state then
		return
	end
	glows[instance :: any] = nil
	state.Part.Color = Color3.fromHSV(state.Hue, state.Saturation, state.Value)
end

-- ── IdleBob ─────────────────────────────────────────────────────────────────

local function updateBob(state: BobState, now: number)
	state.Part.CFrame = (state.OriginalCf * CFrame.Angles(0, math.sin(now * 0.9 + state.Phase) * 0.1, 0))
		+ Vector3.new(0, math.sin(now * 1.8 + state.Phase) * 0.28, 0)
end

local function addBob(instance: Instance)
	if not instance:IsA("BasePart") or bobs[instance] then
		return
	end
	bobs[instance] = {
		Part = instance,
		-- First sight IS the rest pose; the server never moves these again.
		OriginalCf = instance.CFrame,
		Phase = rng:NextNumber(0, math.pi * 2),
	}
end

local function removeBob(instance: Instance)
	local state = bobs[instance :: any]
	if not state then
		return
	end
	bobs[instance :: any] = nil
	state.Part.CFrame = state.OriginalCf
end

-- ── OrbitRibbon ─────────────────────────────────────────────────────────────

-- The server WELDS ribbons to the torso (they must follow the character when
-- we cull them). A welded part can't be CFramed without dragging the whole
-- character, so near the camera we hide the welded original and orbit our own
-- anchored ghost instead; culled, we swap back and the weld does the work.
local function setOrbitActive(state: OrbitState, active: boolean)
	state.Active = active
	state.Ribbon.LocalTransparencyModifier = if active then 1 else 0
	state.Ghost.Transparency = if active then 0 else 1
end

-- R15 and R6 rigs name the chest differently; cache whichever exists and
-- refetch only when the cached part left the character (respawn).
local function resolveTorso(state: OrbitState): BasePart?
	local cached = state.Torso
	if cached and cached.Parent then
		return cached
	end
	local character = state.Ribbon.Parent
	if not character then
		return nil
	end
	local found = character:FindFirstChild("UpperTorso")
		or character:FindFirstChild("Torso")
		or character:FindFirstChild("HumanoidRootPart")
	if found and found:IsA("BasePart") then
		state.Torso = found
		return found
	end
	return nil
end

local function updateOrbit(state: OrbitState, now: number)
	local torso = resolveTorso(state)
	if not torso then
		return
	end
	local angle = now * ORBIT_SPEED + state.Phase
	state.Ghost.CFrame = torso.CFrame
		* CFrame.Angles(0, angle, 0)
		* CFrame.new(0, state.YOffset + math.sin(now * 2 + state.Phase) * 0.25, -ORBIT_RADIUS)
end

local function addOrbit(instance: Instance)
	if not instance:IsA("BasePart") or orbits[instance] then
		return
	end
	local parentFolder = ghostFolder
	if not parentFolder then
		return
	end

	local ghost = Instance.new("Part")
	ghost.Name = "OrbitRibbonGhost"
	ghost.Size = instance.Size
	ghost.Color = instance.Color
	ghost.Material = instance.Material
	ghost.Transparency = 1
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.CanTouch = false
	ghost.CanQuery = false
	ghost.CastShadow = false
	ghost.Massless = true
	ghost.Parent = parentFolder

	-- AppearanceService names ribbons "...OrbitRibbon1..3"; the index spreads
	-- the three of them evenly around the orbit and staggers their heights.
	local index = tonumber(instance.Name:match("(%d+)$")) or rng:NextInteger(1, 3)
	orbits[instance] = {
		Ribbon = instance,
		Ghost = ghost,
		Torso = nil,
		Phase = (index - 1) * (2 * math.pi / 3),
		YOffset = (index - 2) * 0.5,
		Active = false,
	}
end

local function removeOrbit(instance: Instance)
	local state = orbits[instance :: any]
	if not state then
		return
	end
	orbits[instance :: any] = nil
	state.Ghost:Destroy()
	state.Ribbon.LocalTransparencyModifier = 0
end

-- ── WorldSign culling ───────────────────────────────────────────────────────
-- ART Part 11 caps VISIBLE BillboardGuis at 25 on mobile / 60 on desktop. The
-- world has far more signs than that, so keep the nearest N enabled and switch
-- the rest off. Cheap: runs on the existing slow cull pass, not per frame.

local signAnchors: { [BasePart]: BillboardGui } = {}

local SIGN_BUDGET = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then 22 else 55

local function addSign(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local billboard = instance:FindFirstChildOfClass("BillboardGui")
	if billboard then
		signAnchors[instance] = billboard
	end
end

local function removeSign(instance: Instance)
	if instance:IsA("BasePart") then
		signAnchors[instance] = nil
	end
end

local function cullSigns(eye: Vector3)
	-- Collect, sort by distance, enable the closest few.
	local ranked: { { Anchor: BasePart, Gui: BillboardGui, Distance: number } } = {}
	for anchor, billboard in signAnchors do
		if anchor.Parent == nil then
			signAnchors[anchor] = nil
			continue
		end
		table.insert(ranked, {
			Anchor = anchor,
			Gui = billboard,
			Distance = (anchor.Position - eye).Magnitude,
		})
	end
	table.sort(ranked, function(a, b)
		return a.Distance < b.Distance
	end)
	for index, entry in ranked do
		entry.Gui.Enabled = index <= SIGN_BUDGET and entry.Distance <= entry.Gui.MaxDistance
	end
end

-- ── SpinY ───────────────────────────────────────────────────────────────────
-- Continuous Y rotation for the Landmark's logo. The whole point of the
-- Landmark is that it is never still (ART 4.2 / audit tell #37).

local spinning: { [Model]: { Origin: CFrame, Speed: number } } = {}

local function addSpin(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local pivot = instance:GetPivot()
	local speed = instance:GetAttribute("SpinSpeed")
	spinning[instance] = {
		Origin = pivot,
		Speed = if typeof(speed) == "number" then speed else 0.4,
	}
end

local function removeSpin(instance: Instance)
	if instance:IsA("Model") then
		spinning[instance] = nil
	end
end

local function stepSpin(now: number)
	for model, entry in spinning do
		if model.Parent == nil then
			spinning[model] = nil
			continue
		end
		model:PivotTo(entry.Origin * CFrame.Angles(0, now * entry.Speed * math.pi * 2, 0))
	end
end

-- ── WaterShimmer ────────────────────────────────────────────────────────────

local function updateShimmer(state: ShimmerState, now: number)
	state.Part.Transparency = math.clamp(
		state.OriginalTransparency + 0.05 + math.sin(now * 1.3 + state.Phase) * 0.07,
		0,
		1
	)
	state.Part.Color = state.OriginalColor:Lerp(
		Color3.new(1, 1, 1),
		0.12 + 0.12 * math.sin(now * 0.8 + state.Phase)
	)
end

local function addShimmer(instance: Instance)
	if not instance:IsA("BasePart") or shimmers[instance] then
		return
	end
	shimmers[instance] = {
		Part = instance,
		OriginalColor = instance.Color,
		OriginalTransparency = instance.Transparency,
		Phase = rng:NextNumber(0, math.pi * 2),
	}
end

local function removeShimmer(instance: Instance)
	local state = shimmers[instance :: any]
	if not state then
		return
	end
	shimmers[instance :: any] = nil
	state.Part.Color = state.OriginalColor
	state.Part.Transparency = state.OriginalTransparency
end

-- ── TickerSign ──────────────────────────────────────────────────────────────

local function updateTicker(state: TickerState, dt: number)
	state.OffsetX -= state.Speed * dt
	if state.OffsetX <= -state.TextWidth then
		state.OffsetX += state.TextWidth
	end
	state.LabelA.Position = UDim2.new(0, state.OffsetX, 0, 0)
	state.LabelB.Position = UDim2.new(0, state.OffsetX + state.TextWidth, 0, 0)
end

local function addTicker(instance: Instance)
	if not instance:IsA("BasePart") or tickers[instance] then
		return
	end

	-- Each sign starts its loop at a different headline so a wall of tickers
	-- doesn't read like one broken copy-paste.
	local startAt = rng:NextInteger(1, #HEADLINES)
	local ordered: { string } = {}
	for i = 1, #HEADLINES do
		table.insert(ordered, HEADLINES[(startAt + i - 2) % #HEADLINES + 1])
	end
	local text = table.concat(ordered, "   ·   ") .. "   ·   "

	local pixelsPerStud = 40
	local heightPixels = math.max(instance.Size.Y * pixelsPerStud, 24)
	local textSize = math.max(14, math.floor(heightPixels * 0.6))
	local textWidth = TextService:GetTextSize(
		text,
		textSize,
		Enum.Font.FredokaOne,
		Vector2.new(100000, heightPixels)
	).X + 8

	local gui = Instance.new("SurfaceGui")
	gui.Name = "TickerGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud
	gui.LightInfluence = 0

	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = TICKER_BACKDROP_COLOR
	backdrop.BorderSizePixel = 0
	backdrop.ClipsDescendants = true
	backdrop.Parent = gui

	local function makeScrollLabel(): TextLabel
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(0, textWidth, 1, 0)
		label.Font = Enum.Font.FredokaOne
		label.Text = text
		label.TextColor3 = TICKER_TEXT_COLOR
		label.TextSize = textSize
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.Parent = backdrop
		return label
	end

	-- Two copies leapfrog each other for a seamless wrap: when copy A scrolls
	-- fully off, the offset resets and B is standing exactly where A was.
	local labelA = makeScrollLabel()
	local labelB = makeScrollLabel()

	gui.Parent = instance
	tickers[instance] = {
		Part = instance,
		Gui = gui,
		LabelA = labelA,
		LabelB = labelB,
		TextWidth = textWidth,
		OffsetX = 0,
		Speed = heightPixels * 1.4,
	}
end

local function removeTicker(instance: Instance)
	local state = tickers[instance :: any]
	if not state then
		return
	end
	tickers[instance :: any] = nil
	state.Gui:Destroy()
end

-- ── Cull pass + frame loop ──────────────────────────────────────────────────

local function runCullPass(cameraPosition: Vector3)
	local function near(part: BasePart): boolean
		return part.Parent ~= nil
			and part:IsDescendantOf(workspace)
			and (part.Position - cameraPosition).Magnitude <= CULL_RADIUS_STUDS
	end

	table.clear(activeFlickers)
	for _, state in flickers do
		local isActive = state.NeverCull or near(state.Part)
		if state.Active and not isActive then
			-- Never leave a culled light frozen dark mid-burst.
			state.BurstEndsAt = 0
			setFlickerOn(state, true)
		end
		state.Active = isActive
		if isActive then
			table.insert(activeFlickers, state)
		end
	end

	table.clear(activeGlows)
	for _, state in glows do
		if near(state.Part) then
			table.insert(activeGlows, state)
		end
	end

	table.clear(activeBobs)
	for _, state in bobs do
		if near(state.Part) then
			table.insert(activeBobs, state)
		end
	end

	for _, state in orbits do
		local isActive = state.Ribbon.Parent ~= nil and near(state.Ribbon)
		if isActive ~= state.Active then
			setOrbitActive(state, isActive)
		end
	end

	table.clear(activeShimmers)
	for _, state in shimmers do
		if near(state.Part) then
			table.insert(activeShimmers, state)
		end
	end

	table.clear(activeTickers)
	for _, state in tickers do
		if near(state.Part) then
			table.insert(activeTickers, state)
		end
	end
end

local function onRenderStepped(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	cullAccumulator += dt
	if cullAccumulator >= CULL_PASS_SECONDS then
		cullAccumulator = 0
		runCullPass(camera.CFrame.Position)
		cullSigns(camera.CFrame.Position)
	end

	local now = os.clock()
	-- The Landmark spins regardless of distance: it is the thing you navigate
	-- by, so it must never be caught standing still.
	stepSpin(now)
	for _, state in activeFlickers do
		updateFlicker(state, now)
	end
	for _, state in activeGlows do
		updateGlow(state, now)
	end
	for _, state in activeBobs do
		updateBob(state, now)
	end
	for _, state in orbits do
		-- Orbits iterate the full map (it's tiny — 3 ribbons per Band-5
		-- player) because active swapping already happened in the cull pass.
		if state.Active then
			updateOrbit(state, now)
		end
	end
	for _, state in activeShimmers do
		updateShimmer(state, now)
	end
	for _, state in activeTickers do
		updateTicker(state, dt)
	end
end

-- ── Lifecycle ───────────────────────────────────────────────────────────────

function WorldFxController:Init()
	local container = Instance.new("Folder")
	container.Name = "WorldFxGhosts"
	container.Parent = workspace
	trove:Add(container)
	ghostFolder = container
end

function WorldFxController:Start()
	watchTag("WorldSign", addSign, removeSign)
	watchTag("SpinY", addSpin, removeSpin)
	watchTag("FlickerLight", addFlicker, removeFlicker)
	watchTag("GlowScreen", addGlow, removeGlow)
	watchTag("IdleBob", addBob, removeBob)
	watchTag("OrbitRibbon", addOrbit, removeOrbit)
	watchTag("WaterShimmer", addShimmer, removeShimmer)
	watchTag("TickerSign", addTicker, removeTicker)
	trove:Connect(RunService.RenderStepped, onRenderStepped)
end

return WorldFxController
