--!strict
-- The always-on HUD: big Productivity counter top-centre (animated count-up —
-- a number that snaps reads as a bug in this genre), rank + progress beneath,
-- Wins top-right, the genre-standard left button stack, and the income readout
-- at the bottom. Also routes the world's ProximityPrompts into the panels.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))
local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Format"))
local Balance = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Balance"))
local Ranks = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Ranks"))
local StateController = require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("StateController"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local ShopUi = require(script.Parent:WaitForChild("ShopUi"))
local InternUi = require(script.Parent:WaitForChild("InternUi"))
local RestructureUi = require(script.Parent:WaitForChild("RestructureUi"))

-- Exponential approach rate for the count-up: ~90% of any gap closes in a
-- third of a second — fast enough to feel live, slow enough to see it move.
local COUNT_UP_SHARPNESS = 7
local COUNT_SNAP_EPSILON = 0.5

type PanelModule = {
	open: () -> (),
	toggle: () -> (),
}

local Hud = {}

local trove = Trove.new()
local productivityLabel: TextLabel? = nil
local rankTitleLabel: TextLabel? = nil
local nextRankLabel: TextLabel? = nil
local rankBar: Theme.ProgressBar? = nil
local winsLabel: Theme.CurrencyLabel? = nil
local incomeLabel: TextLabel? = nil
local restructureHolderScale: UIScale? = nil
local restructureButton: TextButton? = nil
local pulseTween: Tween? = nil

-- The displayed number chases the real one every frame instead of jumping.
local displayedProductivity = 0
local targetProductivity = 0
local shownText = ""

local PROMPT_TO_PANEL: { [string]: PanelModule } = {
	OpenShop = ShopUi,
	OpenCoffee = InternUi,
	OpenHr = RestructureUi,
}

-- ── Per-frame count-up ──────────────────────────────────────────────────────

local function stepCountUp(dt: number)
	local gap = targetProductivity - displayedProductivity
	if gap ~= 0 then
		-- Frame-rate independent exponential chase; snaps only when the
		-- remaining gap is invisible at display precision.
		displayedProductivity += gap * (1 - math.exp(-COUNT_UP_SHARPNESS * dt))
		if math.abs(targetProductivity - displayedProductivity) < COUNT_SNAP_EPSILON then
			displayedProductivity = targetProductivity
		end
	end
	local label = productivityLabel
	if label then
		local text = "💼 " .. Format.abbreviate(displayedProductivity)
		if text ~= shownText then
			shownText = text
			label.Text = text
		end
	end
end

-- ── Rank row ────────────────────────────────────────────────────────────────

local function updateRank(state: StateController.ClientState)
	local rankDef = Ranks.List[state.Rank]
	local title = rankTitleLabel
	if title and rankDef then
		title.Text = rankDef.Name
	end

	local bar = rankBar
	local nextLabel = nextRankLabel
	local nextAt = state.NextRankAt
	-- math.huge marks the rank cap; the bar pins full instead of dividing by ∞.
	if nextAt == math.huge or nextAt ~= nextAt then
		if bar then
			bar.Set(1)
		end
		if nextLabel then
			nextLabel.Text = "Top of the ladder! 👑"
		end
		return
	end
	local currentRequirement = if rankDef then rankDef.Requirement else 0
	local span = math.max(nextAt - currentRequirement, 1)
	if bar then
		bar.Set(math.clamp((state.Productivity - currentRequirement) / span, 0, 1))
	end
	if nextLabel then
		local nextDef = Ranks.List[state.Rank + 1]
		nextLabel.Text = ("Next: %s at %s 💼"):format(if nextDef then nextDef.Name else "?", Format.abbreviate(nextAt))
	end
end

-- ── Restructure pulse ───────────────────────────────────────────────────────

local function setRestructurePulse(on: boolean)
	local holderScale = restructureHolderScale
	local button = restructureButton
	if not holderScale or not button then
		return
	end
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if on then
		if pulseTween then
			return -- already pulsing; restarting resets the phase visibly
		end
		button.BackgroundColor3 = Theme.Colors.Gold
		button.TextColor3 = Theme.Colors.TextOnGold
		if stroke then
			stroke.Color = Theme.Colors.GoldDark
		end
		-- Infinite reversing breathe on the wrapper scale (the button's own
		-- UIScale belongs to hover/press juice).
		local tween = Theme.play(
			holderScale,
			TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, true),
			{ Scale = 1.07 }
		)
		pulseTween = tween
	else
		if pulseTween then
			pulseTween:Cancel()
			pulseTween = nil
		end
		holderScale.Scale = 1
		button.BackgroundColor3 = Theme.Colors.PanelLight
		button.TextColor3 = Theme.Colors.Text
		if stroke then
			stroke.Color = Theme.Colors.PanelDark
		end
	end
end

-- ── State intake ────────────────────────────────────────────────────────────

local function onState(state: StateController.ClientState)
	targetProductivity = state.Productivity
	updateRank(state)
	local wins = winsLabel
	if wins then
		wins.Set(state.Wins)
	end
	local income = incomeLabel
	if income then
		income.Text = ("+%s per click · +%s/s idle"):format(
			Format.abbreviate(state.ClickIncome),
			Format.abbreviate(state.IdlePerSecond)
		)
	end
	setRestructurePulse(state.Rank >= Balance.RestructureMinRank and state.Productivity >= state.RestructureCost)
end

-- ── Building ────────────────────────────────────────────────────────────────

local function buildTopCentre(gui: ScreenGui)
	local cluster = Instance.new("Frame")
	cluster.Name = "TopCentre"
	cluster.BackgroundTransparency = 1
	cluster.AnchorPoint = Vector2.new(0.5, 0)
	cluster.Position = UDim2.new(0.5, 0, 0, 4)
	cluster.Size = UDim2.fromOffset(420, 132)
	Theme.autoScale(cluster, trove)

	productivityLabel = Theme.text({
		Text = "💼 0",
		Parent = cluster,
		Size = UDim2.new(1, 0, 0, 52),
		Font = Theme.DisplayFont,
		TextSize = 44,
		Color = Theme.Colors.Gold,
		StrokePx = 4,
		Name = "Productivity",
	})
	rankTitleLabel = Theme.text({
		Text = "…",
		Parent = cluster,
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.new(0, 0, 0, 54),
		Font = Theme.DisplayFont,
		TextSize = 20,
		StrokePx = 3,
		Name = "RankTitle",
	})
	rankBar = Theme.progressBar({
		Parent = cluster,
		Size = UDim2.fromOffset(320, 14),
		Position = UDim2.new(0.5, 0, 0, 84),
		AnchorPoint = Vector2.new(0.5, 0),
	})
	nextRankLabel = Theme.text({
		Text = "",
		Parent = cluster,
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 0, 102),
		TextSize = 12,
		Color = Theme.Colors.TextDim,
		StrokePx = 2,
		Name = "NextRank",
	})

	cluster.Parent = gui
end

local function buildWins(gui: ScreenGui)
	local label = Theme.currencyLabel({
		Icon = "🏆",
		Size = UDim2.fromOffset(176, 46),
		Position = UDim2.new(1, -12, 0, 8),
		AnchorPoint = Vector2.new(1, 0),
		TextSize = 22,
		Format = Format.abbreviate,
	})
	Theme.autoScale(label.Root, trove)
	label.Root.Parent = gui
	winsLabel = label
end

local function buildLeftStack(gui: ScreenGui)
	local stack = Instance.new("Frame")
	stack.Name = "LeftStack"
	stack.BackgroundTransparency = 1
	stack.AnchorPoint = Vector2.new(0, 0.5)
	stack.Position = UDim2.new(0, 10, 0.5, 0)
	stack.Size = UDim2.fromOffset(168, 4 * 72 + 3 * 10)
	Theme.autoScale(stack, trove)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = stack

	-- Each button sits in a wrapper Frame whose UIScale we own: the
	-- restructure pulse (and any future badge bounce) must not fight the
	-- hover/press UIScale inside Theme.button.
	local function makeStackButton(order: number, text: string, onClick: () -> ()): (TextButton, UIScale)
		local holder = Instance.new("Frame")
		holder.Name = text
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.new(1, 0, 0, 72)
		holder.LayoutOrder = order
		local holderScale = Instance.new("UIScale")
		holderScale.Parent = holder
		local button = Theme.button({
			Text = text,
			Variant = "ghost",
			Size = UDim2.fromScale(1, 1),
			TextSize = 22,
			Parent = holder,
			OnClick = onClick,
		})
		holder.Parent = stack
		return button, holderScale
	end

	makeStackButton(1, "💼 Shop", ShopUi.toggle)
	makeStackButton(2, "☕ Interns", InternUi.toggle)
	local button, holderScale = makeStackButton(4, "📉 Restructure", RestructureUi.toggle)
	restructureButton = button
	restructureHolderScale = holderScale

	stack.Parent = gui
end

local function buildIncomeReadout(gui: ScreenGui)
	local holder = Instance.new("Frame")
	holder.Name = "IncomeReadout"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -8)
	holder.Size = UDim2.fromOffset(380, 30)
	Theme.autoScale(holder, trove)

	incomeLabel = Theme.text({
		Text = "+1 per click",
		Parent = holder,
		Size = UDim2.fromScale(1, 1),
		Font = Theme.DisplayFont,
		TextSize = 19,
		StrokePx = 3,
		Name = "Income",
	})
	holder.Parent = gui
end

-- ── Lifecycle ───────────────────────────────────────────────────────────────

function Hud:Init()
	local gui = Theme.screenGui("Hud", 1, trove)
	buildTopCentre(gui)
	buildWins(gui)
	buildLeftStack(gui)
	buildIncomeReadout(gui)
end

function Hud:Start()
	-- Cast: sleitnick Signal's typed Connect doesn't unify with Trove's
	-- SignalLike under the old solver; the runtime shapes match fine.
	trove:Connect(StateController.Changed :: any, onState)
	task.spawn(function()
		-- First paint: seed the count-up at the real value so joining doesn't
		-- roll up from zero like a fake slot machine.
		local state = StateController.await()
		displayedProductivity = state.Productivity
		onState(state)
	end)

	trove:Connect(RunService.Heartbeat, stepCountUp)

	-- World prompts (shop kiosk, coffee machine, HR desk, elevator bank) open
	-- the same panels as the button stack.
	trove:Connect(ProximityPromptService.PromptTriggered, function(prompt: ProximityPrompt, player: Player)
		if player ~= Players.LocalPlayer then
			return
		end
		local target = PROMPT_TO_PANEL[prompt.Name]
		if target then
			target.open()
		end
	end)
end

return Hud
