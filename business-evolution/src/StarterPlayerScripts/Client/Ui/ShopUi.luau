--!strict
-- The Gear Shop: three upgrade ladders side by side plus the gamepass strip.
-- Pure view — every price comes from Config/Gear and every owned tier from the
-- server's ClientState, so the shop can never disagree with the economy.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))
local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Format"))
local Gear = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Gear"))
local Monetization = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Monetization"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local StateController = require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("StateController"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local requestPurchaseGear = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestPurchaseGear") :: RemoteEvent

local PANEL_NAME = "Shop"
local PANEL_SIZE = UDim2.fromOffset(960, 560)
local PASS_STRIP_HEIGHT = 96

local LADDER_ICONS: { [string]: string } = {
	Keyboard = "⌨️",
	Chair = "🪑",
	Coffee = "☕",
}

local ShopUi = {}

local trove = Trove.new()
local panel: Theme.Panel? = nil
local columnsFrame: Frame? = nil
local winsLabel: Theme.CurrencyLabel? = nil
-- Cheap diff: the shop only rebuilds when something it draws actually changed,
-- because Wins ticks on every rival defeat and a rebuild per tick would churn.
local lastRenderKey: string? = nil

local function renderKeyFor(state: StateController.ClientState): string
	return ("%d:%d:%d:%d"):format(state.Gear.Keyboard, state.Gear.Chair, state.Gear.Coffee, state.Wins)
end

-- GearOwned is a sealed struct, so ladder ids map to fields explicitly instead
-- of dynamic indexing (which strict mode rightly refuses).
local function ownedFor(gear: Types.GearOwned, ladderId: string): number
	if ladderId == "Keyboard" then
		return gear.Keyboard
	elseif ladderId == "Chair" then
		return gear.Chair
	elseif ladderId == "Coffee" then
		return gear.Coffee
	end
	return 0
end

local function tierEffectText(ladderId: string, value: number): string
	if ladderId == "Keyboard" then
		return ("×%s Productivity per click"):format(tostring(value))
	elseif ladderId == "Chair" then
		return ("+%s Productivity/s while idle"):format(Format.abbreviate(value))
	end
	-- Coffee stores a cooldown multiplier; players think in "% faster".
	return ("-%d%% click cooldown"):format(math.floor((1 - value) * 100 + 0.5))
end

local function buildColumn(parent: Frame, state: StateController.ClientState, ladder: Gear.Ladder, order: number)
	local owned = ownedFor(state.Gear, ladder.Id)

	local column = Theme.card({
		Parent = parent,
		Size = UDim2.new(1 / 3, -10, 1, 0),
		LayoutOrder = order,
		Name = ladder.Id,
	})
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = column

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = column

	Theme.title({
		Text = (LADDER_ICONS[ladder.Id] or "🧰") .. " " .. ladder.DisplayName,
		Parent = column,
		Size = UDim2.new(1, 0, 0, 36),
		TextSize = 24,
		Color = Theme.Colors.Text,
		LayoutOrder = 1,
	})
	Theme.text({
		Text = ladder.Effect,
		Parent = column,
		Size = UDim2.new(1, 0, 0, 30),
		TextSize = 13,
		Color = Theme.Colors.TextDim,
		Wrapped = true,
		LayoutOrder = 2,
	})

	-- Tier pips: filled gold per owned tier, hollow for the rest — progress at
	-- a glance without reading a single number.
	local pipsRow = Instance.new("Frame")
	pipsRow.Name = "Pips"
	pipsRow.BackgroundTransparency = 1
	pipsRow.Size = UDim2.new(1, 0, 0, 20)
	pipsRow.LayoutOrder = 3
	local pipsLayout = Instance.new("UIListLayout")
	pipsLayout.FillDirection = Enum.FillDirection.Horizontal
	pipsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	pipsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	pipsLayout.Padding = UDim.new(0, 6)
	pipsLayout.Parent = pipsRow
	for tierIndex = 1, #ladder.Tiers do
		local pip = Instance.new("Frame")
		pip.Name = "Pip" .. tierIndex
		pip.Size = UDim2.fromOffset(16, 16)
		pip.BorderSizePixel = 0
		pip.BackgroundColor3 = if tierIndex <= owned then Theme.Colors.Gold else Theme.Colors.PanelDark
		local pipCorner = Instance.new("UICorner")
		pipCorner.CornerRadius = UDim.new(0.5, 0)
		pipCorner.Parent = pip
		pip.Parent = pipsRow
	end
	pipsRow.Parent = column

	local currentTier = ladder.Tiers[owned]
	Theme.text({
		Text = if currentTier then ("Owned: %s (%d/%d)"):format(currentTier.Name, owned, #ladder.Tiers) else "Owned: none yet",
		Parent = column,
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 13,
		Color = Theme.Colors.TextDim,
		LayoutOrder = 4,
	})

	local nextCard = Theme.card({
		Parent = column,
		Size = UDim2.new(1, 0, 0, 208),
		LayoutOrder = 5,
		Color = Theme.Colors.Panel,
		Name = "NextTier",
	})

	local nextTier = ladder.Tiers[owned + 1]
	local cost = Gear.nextTierCost(ladder.Id, owned)
	if nextTier == nil or cost == nil then
		Theme.title({
			Text = "👑",
			Parent = nextCard,
			Size = UDim2.new(1, 0, 0, 56),
			Position = UDim2.new(0, 0, 0, 40),
			TextSize = 44,
		})
		Theme.title({
			Text = "FULLY UPGRADED",
			Parent = nextCard,
			Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.new(0, 0, 0, 104),
			TextSize = 20,
		})
		return
	end

	local affordable = state.Wins >= cost

	Theme.title({
		Text = "NEXT: " .. nextTier.Name,
		Parent = nextCard,
		Size = UDim2.new(1, -16, 0, 26),
		Position = UDim2.new(0, 8, 0, 10),
		TextSize = 19,
	})
	Theme.text({
		Text = tierEffectText(ladder.Id, nextTier.Value),
		Parent = nextCard,
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.new(0, 8, 0, 40),
		TextSize = 14,
	})
	Theme.text({
		Text = Format.abbreviate(cost) .. " 🏆",
		Parent = nextCard,
		Size = UDim2.new(1, -16, 0, 30),
		Position = UDim2.new(0, 8, 0, 68),
		Font = Theme.DisplayFont,
		TextSize = 24,
		Color = if affordable then Theme.Colors.Green else Theme.Colors.Red,
		StrokePx = 2,
	})

	local buyButton = Theme.button({
		Text = "BUY",
		Variant = "primary",
		Size = UDim2.new(1, -24, 0, 56),
		Position = UDim2.new(0, 12, 1, -68),
		TextSize = 24,
		Parent = nextCard,
		Name = "Buy" .. ladder.Id,
		OnClick = function()
			-- Recheck against the LATEST snapshot: the one captured at build
			-- time may predate a purchase in another column.
			local latest = StateController.Get()
			local latestCost = Gear.nextTierCost(ladder.Id, if latest then ownedFor(latest.Gear, ladder.Id) else owned)
			if latest and latestCost and latest.Wins >= latestCost then
				requestPurchaseGear:FireServer(ladder.Id)
			else
				Theme.deny(nextCard)
			end
		end,
	})
	if not affordable then
		-- Greyed, not hidden: seeing the next goal is what drives the grind.
		buyButton.BackgroundColor3 = Theme.Colors.PanelLight
		buyButton.TextColor3 = Theme.Colors.TextDim
		local stroke = buyButton:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = Theme.Colors.PanelDark
		end
	end
end

local function rebuild(state: StateController.ClientState)
	local columns = columnsFrame
	if not columns then
		return
	end
	lastRenderKey = renderKeyFor(state)
	for _, child in columns:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for order, ladder in Gear.Ladders do
		buildColumn(columns, state, ladder, order)
	end
end

local function buildPassStrip(parent: Frame)
	local visiblePasses: { Monetization.PassDef } = {}
	for _, pass in Monetization.Passes do
		-- Id 0 means "not created on the website yet" — showing it would sell
		-- a purchase that cannot be prompted.
		if pass.Id ~= 0 then
			table.insert(visiblePasses, pass)
		end
	end
	if #visiblePasses == 0 then
		local columns = columnsFrame
		if columns then
			columns.Size = UDim2.new(1, 0, 1, 0) -- reclaim the empty strip
		end
		return
	end

	local strip = Instance.new("ScrollingFrame")
	strip.Name = "PassStrip"
	strip.BackgroundTransparency = 1
	strip.BorderSizePixel = 0
	strip.AnchorPoint = Vector2.new(0, 1)
	strip.Position = UDim2.new(0, 0, 1, 0)
	strip.Size = UDim2.new(1, 0, 0, PASS_STRIP_HEIGHT - 8)
	strip.CanvasSize = UDim2.new()
	strip.AutomaticCanvasSize = Enum.AutomaticSize.X
	strip.ScrollingDirection = Enum.ScrollingDirection.X
	strip.ScrollBarThickness = Theme.StrokeThickness
	strip.ScrollBarImageColor3 = Theme.Colors.Gold
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.Parent = strip

	for order, pass in visiblePasses do
		local card = Theme.button({
			Text = "",
			Variant = "ghost",
			Size = UDim2.fromOffset(230, 72),
			Parent = strip,
			LayoutOrder = order,
			Name = "Pass" .. pass.Key,
			OnClick = function()
				MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, pass.Id)
			end,
		})
		Theme.title({
			Text = pass.Name,
			Parent = card,
			Size = UDim2.new(1, -12, 0, 26),
			Position = UDim2.new(0, 6, 0, 8),
			TextSize = 17,
		})
		Theme.text({
			Text = ("R$ %d"):format(pass.Price),
			Parent = card,
			Size = UDim2.new(1, -12, 0, 22),
			Position = UDim2.new(0, 6, 0, 38),
			Font = Theme.DisplayFont,
			TextSize = 16,
			Color = Theme.Colors.Green,
		})
	end
	strip.Parent = parent
end

local function isOpen(): boolean
	return Theme.currentPanel() == PANEL_NAME
end

function ShopUi.open()
	local handle = panel
	if not handle or isOpen() then
		return
	end
	local state = StateController.Get()
	if state then
		rebuild(state)
		local wins = winsLabel
		if wins then
			wins.Set(state.Wins)
		end
	end
	Theme.openExclusive(handle)
end

function ShopUi.toggle()
	if isOpen() then
		Theme.closeExclusive(PANEL_NAME)
	else
		ShopUi.open()
	end
end

function ShopUi:Init()
	local gui = Theme.screenGui("ShopUi", 5, trove)
	local newPanel = Theme.panel({
		Name = PANEL_NAME,
		Title = "GEAR SHOP 💼",
		Size = PANEL_SIZE,
		Parent = gui,
		Trove = trove,
	})
	panel = newPanel

	winsLabel = Theme.currencyLabel({
		Icon = "🏆",
		Parent = newPanel.Body.Parent, -- surface, so it sits beside the title
		Size = UDim2.fromOffset(150, 40),
		Position = UDim2.new(1, -214, 0, 12),
		TextSize = 20,
		Format = Format.abbreviate,
	})

	local columns = Instance.new("Frame")
	columns.Name = "Columns"
	columns.BackgroundTransparency = 1
	columns.Size = UDim2.new(1, 0, 1, -PASS_STRIP_HEIGHT)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 14)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = columns
	columns.Parent = newPanel.Body
	columnsFrame = columns

	buildPassStrip(newPanel.Body)
end

function ShopUi:Start()
	-- Cast: sleitnick Signal's typed Connect doesn't unify with Trove's
	-- SignalLike under the old solver; the runtime shapes match fine.
	trove:Connect(StateController.Changed :: any, function(state: StateController.ClientState)
		local wins = winsLabel
		if wins then
			wins.Set(state.Wins)
		end
		-- Only rebuild while the player is actually looking; open() rebuilds
		-- fresh anyway, so a closed shop can stay stale for free.
		if isOpen() and renderKeyFor(state) ~= lastRenderKey then
			rebuild(state)
		end
	end)
end

return ShopUi
