--!strict
-- The elevator panel: one row per floor with the same gate check the server
-- runs (Floors.canEnter), so the greyed-out reason on screen is exactly why
-- the server would refuse. Riding plays a full-screen doors-closing transition
-- that hides the teleport snap — the doors ARE the loading screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))
local Floors = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Floors"))
local StateController = require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("StateController"))
local SoundController = require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("SoundController"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local requestTeleport = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestTeleport") :: RemoteEvent

local PANEL_NAME = "Elevator"
local PANEL_SIZE = UDim2.fromOffset(640, 560)
local ROW_HEIGHT = 84
-- Doors close (0.32s), the world swaps behind them, doors reopen.
local DOORS_CLOSE_SECONDS = 0.32
local DOORS_HOLD_SECONDS = 0.8
local DOORS_OPEN_SECONDS = 0.45
-- A character further than this from every floor origin is mid-fall between
-- floors; floors are stacked 512+ studs apart so this can never be ambiguous.
local FLOOR_MATCH_STUDS = 250

local ElevatorUi = {}

local trove = Trove.new()
local panel: Theme.Panel? = nil
local rowsFrame: ScrollingFrame? = nil
local doorsOverlay: Frame? = nil
local doorLeft: Frame? = nil
local doorRight: Frame? = nil
local doorsLabel: TextLabel? = nil
local transitioning = false
local lastRenderKey: string? = nil

-- The server tracks the authoritative floor; the client infers its own from
-- altitude purely to draw the "YOU ARE HERE" highlight.
local function currentFloorId(): string?
	local character = Players.LocalPlayer.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	local y = root.Position.Y
	local bestId: string? = nil
	local bestDistance = FLOOR_MATCH_STUDS
	for _, floor in Floors.List do
		local distance = math.abs(y - floor.Origin[2])
		if distance < bestDistance then
			bestDistance = distance
			bestId = floor.Id
		end
	end
	return bestId
end

-- A floor opens either by meeting its gate or by owning that floor's skip
-- gamepass. The server re-checks both on every teleport; this just keeps the
-- UI from locking a floor the player actually paid for.
local function canRide(state: StateController.ClientState, floorId: string): (boolean, string?)
	local allowed, reason = Floors.canEnter(floorId, state.Rank, state.Restructures, state.BossesDefeated)
	if allowed then
		return true, nil
	end
	if state.OwnedSkips and state.OwnedSkips[floorId] then
		return true, nil
	end
	return false, reason
end

local function skipKeyFor(state: StateController.ClientState): string
	local owned: { string } = {}
	local skips: { [string]: boolean } = state.OwnedSkips or {}
	for floorId in skips do
		table.insert(owned, floorId)
	end
	table.sort(owned) -- stable order so the key only changes on real changes
	return table.concat(owned, ",")
end

local function renderKeyFor(state: StateController.ClientState): string
	-- Skip ownership is part of the key: buying a pass mid-session must
	-- re-render the list, or the floor stays visually locked.
	return ("%d:%d:%d:%s:%s"):format(
		state.Rank,
		state.Restructures,
		#state.BossesDefeated,
		currentFloorId() or "?",
		skipKeyFor(state)
	)
end

-- ── Door transition ─────────────────────────────────────────────────────────

local function ride(floor: Floors.Floor)
	local overlay = doorsOverlay
	local left = doorLeft
	local right = doorRight
	local label = doorsLabel
	if transitioning or not (overlay and left and right and label) then
		return
	end
	transitioning = true
	Theme.closeExclusive(PANEL_NAME)

	label.Text = ("▼  %s — %s  ▼"):format(floor.FloorLabel, floor.DisplayName)
	overlay.Visible = true
	left.Position = UDim2.fromScale(-0.6, 0)
	right.Position = UDim2.fromScale(1.1, 0)
	SoundController.play("Teleport")
	-- Back easing overshoots PAST closed — the doors bump together and settle,
	-- which is what sells them as heavy metal doors. The 10% overlap between
	-- the two panels keeps the overshoot gap-free.
	local closeInfo = TweenInfo.new(DOORS_CLOSE_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	Theme.play(left, closeInfo, { Position = UDim2.fromScale(0, 0) })
	Theme.play(right, closeInfo, { Position = UDim2.fromScale(0.45, 0) })

	task.delay(DOORS_CLOSE_SECONDS + 0.05, function()
		-- Fire only once the screen is covered so the player never sees the
		-- teleport pop.
		requestTeleport:FireServer(floor.Id)
	end)

	task.delay(DOORS_CLOSE_SECONDS + 0.05 + DOORS_HOLD_SECONDS, function()
		local openInfo = TweenInfo.new(DOORS_OPEN_SECONDS, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		Theme.play(left, openInfo, { Position = UDim2.fromScale(-0.6, 0) })
		Theme.play(right, openInfo, { Position = UDim2.fromScale(1.1, 0) })
		task.delay(DOORS_OPEN_SECONDS + 0.05, function()
			overlay.Visible = false
			transitioning = false
		end)
	end)
end

-- ── Floor rows ──────────────────────────────────────────────────────────────

local function buildRow(parent: ScrollingFrame, state: StateController.ClientState, floor: Floors.Floor, order: number, hereId: string?)
	local allowed, reason = canRide(state, floor.Id)
	local isHere = hereId == floor.Id

	-- Forward-declared so the click handler can wobble its own row (a local
	-- defined in the same statement would not be captured by the closure).
	local row: TextButton? = nil
	row = Theme.button({
		Text = "",
		Variant = "ghost",
		Size = UDim2.new(1, -12, 0, ROW_HEIGHT),
		Parent = parent,
		LayoutOrder = order,
		Name = "Floor" .. floor.Id,
		Silent = true,
		OnClick = function()
			local latest = StateController.Get()
			if not latest then
				return
			end
			local nowAllowed = canRide(latest, floor.Id)
			if not nowAllowed or currentFloorId() == floor.Id then
				if row then
					Theme.deny(row)
				end
				return
			end
			SoundController.play("Click")
			ride(floor)
		end,
	})
	local rowButton = row :: TextButton

	-- Gold floor-number square, like the button panel in a real lift.
	local square = Instance.new("Frame")
	square.Name = "LabelSquare"
	square.BackgroundColor3 = if allowed then Theme.Colors.Gold else Theme.Colors.PanelDark
	square.BorderSizePixel = 0
	square.Position = UDim2.new(0, 10, 0.5, 0)
	square.AnchorPoint = Vector2.new(0, 0.5)
	square.Size = UDim2.fromOffset(60, 60)
	local squareCorner = Instance.new("UICorner")
	squareCorner.CornerRadius = UDim.new(0, 12)
	squareCorner.Parent = square
	Theme.text({
		Text = floor.FloorLabel,
		Parent = square,
		Size = UDim2.fromScale(1, 1),
		Font = Theme.DisplayFont,
		TextSize = 24,
		Color = if allowed then Theme.Colors.TextOnGold else Theme.Colors.TextDim,
	})
	square.Parent = rowButton

	Theme.text({
		Text = floor.DisplayName,
		Parent = rowButton,
		Size = UDim2.new(1, -220, 0, 26),
		Position = UDim2.new(0, 82, 0, 12),
		Font = Theme.DisplayFont,
		TextSize = 20,
		Color = if allowed then Theme.Colors.Text else Theme.Colors.TextDim,
		XAlign = Enum.TextXAlignment.Left,
	})
	Theme.text({
		Text = floor.Tagline,
		Parent = rowButton,
		Size = UDim2.new(1, -220, 0, 20),
		Position = UDim2.new(0, 82, 0, 42),
		TextSize = 13,
		Color = Theme.Colors.TextDim,
		XAlign = Enum.TextXAlignment.Left,
	})

	if isHere then
		local stroke = rowButton:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = Theme.Colors.Gold
		end
		local chip = Instance.new("Frame")
		chip.Name = "HereChip"
		chip.BackgroundColor3 = Theme.Colors.Gold
		chip.BorderSizePixel = 0
		chip.AnchorPoint = Vector2.new(1, 0.5)
		chip.Position = UDim2.new(1, -12, 0.5, 0)
		chip.Size = UDim2.fromOffset(120, 30)
		local chipCorner = Instance.new("UICorner")
		chipCorner.CornerRadius = UDim.new(0, 15)
		chipCorner.Parent = chip
		Theme.text({
			Text = "YOU ARE HERE",
			Parent = chip,
			Size = UDim2.fromScale(1, 1),
			Font = Theme.BodyBoldFont,
			TextSize = 11,
			Color = Theme.Colors.TextOnGold,
		})
		chip.Parent = rowButton
	elseif not allowed then
		rowButton.BackgroundTransparency = 0.5
		Theme.text({
			Text = "🔒 " .. (reason or "Locked"),
			Parent = rowButton,
			Size = UDim2.fromOffset(150, 40),
			Position = UDim2.new(1, -160, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			TextSize = 12,
			Color = Theme.Colors.Red,
			Wrapped = true,
			XAlign = Enum.TextXAlignment.Right,
		})
	else
		Theme.text({
			Text = "▶",
			Parent = rowButton,
			Size = UDim2.fromOffset(30, 30),
			Position = UDim2.new(1, -40, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Font = Theme.DisplayFont,
			TextSize = 20,
			Color = Theme.Colors.Green,
		})
	end
end

local function rebuild(state: StateController.ClientState)
	local rows = rowsFrame
	if not rows then
		return
	end
	lastRenderKey = renderKeyFor(state)
	for _, child in rows:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local hereId = currentFloorId()
	for order, floor in Floors.List do
		buildRow(rows, state, floor, order, hereId)
	end
end

-- ── Public API + lifecycle ──────────────────────────────────────────────────

local function isOpen(): boolean
	return Theme.currentPanel() == PANEL_NAME
end

function ElevatorUi.open()
	local handle = panel
	if not handle or isOpen() then
		return
	end
	local state = StateController.Get()
	if state then
		rebuild(state)
	end
	Theme.openExclusive(handle)
end

function ElevatorUi.toggle()
	if isOpen() then
		Theme.closeExclusive(PANEL_NAME)
	else
		ElevatorUi.open()
	end
end

function ElevatorUi:Init()
	-- IgnoreGuiInset: the door transition must cover the topbar strip too.
	local gui = Theme.screenGui("ElevatorUi", 5, trove, true)
	local newPanel = Theme.panel({
		Name = PANEL_NAME,
		Title = "ELEVATOR 🛗",
		Size = PANEL_SIZE,
		Parent = gui,
		Trove = trove,
	})
	panel = newPanel

	local rows = Instance.new("ScrollingFrame")
	rows.Name = "FloorRows"
	rows.BackgroundTransparency = 1
	rows.BorderSizePixel = 0
	rows.Size = UDim2.fromScale(1, 1)
	rows.CanvasSize = UDim2.new()
	rows.AutomaticCanvasSize = Enum.AutomaticSize.Y
	rows.ScrollingDirection = Enum.ScrollingDirection.Y
	rows.ScrollBarThickness = 6
	rows.ScrollBarImageColor3 = Theme.Colors.Gold
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = rows
	rows.Parent = newPanel.Body
	rowsFrame = rows

	-- Doors overlay: two navy panels with a gold seam, above everything in
	-- this gui (popups at DisplayOrder 100 still float over — acceptable).
	local overlay = Instance.new("Frame")
	overlay.Name = "DoorsOverlay"
	overlay.BackgroundTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Visible = false
	overlay.ZIndex = 10
	overlay.Parent = gui
	doorsOverlay = overlay

	local function makeDoor(name: string, seamOnRight: boolean): Frame
		local door = Instance.new("Frame")
		door.Name = name
		door.BackgroundColor3 = Theme.Colors.Panel
		door.BorderSizePixel = 0
		door.Size = UDim2.fromScale(0.55, 1)
		door.ZIndex = 10
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 0
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 194, 210)),
		})
		gradient.Parent = door
		local seam = Instance.new("Frame")
		seam.Name = "Seam"
		seam.BackgroundColor3 = Theme.Colors.Gold
		seam.BorderSizePixel = 0
		seam.Size = UDim2.new(0, 6, 1, 0)
		seam.Position = if seamOnRight then UDim2.new(1, -6, 0, 0) else UDim2.new(0, 0, 0, 0)
		seam.ZIndex = 11
		seam.Parent = door
		door.Parent = overlay
		return door
	end
	doorLeft = makeDoor("LeftDoor", true)
	doorRight = makeDoor("RightDoor", false)

	doorsLabel = Theme.text({
		Text = "",
		Parent = overlay,
		Size = UDim2.new(1, 0, 0, 50),
		Position = UDim2.new(0, 0, 0.42, 0),
		Font = Theme.DisplayFont,
		TextSize = 30,
		Color = Theme.Colors.Gold,
		StrokePx = 3,
		ZIndex = 12,
	})
end

function ElevatorUi:Start()
	-- Cast: sleitnick Signal's typed Connect doesn't unify with Trove's
	-- SignalLike under the old solver; the runtime shapes match fine.
	trove:Connect(StateController.Changed :: any, function(state: StateController.ClientState)
		if isOpen() and renderKeyFor(state) ~= lastRenderKey then
			rebuild(state)
		end
	end)
end

return ElevatorUi
