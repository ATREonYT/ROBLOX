--!strict
-- The Coffee Machine (intern gacha) panel: hire on the left, published odds
-- always in view (§7 — odds are a legal requirement, never hidden behind a
-- click), inventory grid with equip toggles on the right. The roll reveal is
-- pure theatre driven by the server's InternRollResult — the client never
-- rolls anything.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))
local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Format"))
local Balance = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Balance"))
local Interns = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Interns"))
local StateController = require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("StateController"))
local SoundController = require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("SoundController"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestHireIntern = remotes:WaitForChild("RequestHireIntern") :: RemoteEvent
local requestEquipIntern = remotes:WaitForChild("RequestEquipIntern") :: RemoteEvent
local internRollResult = remotes:WaitForChild("InternRollResult") :: RemoteEvent

local PANEL_NAME = "Interns"
local PANEL_SIZE = UDim2.fromOffset(980, 560)
local LEFT_WIDTH = 330

type RollPayload = {
	InternId: string,
	Uid: string,
	Rarity: string,
}

local InternUi = {}

local trove = Trove.new()
local panel: Theme.Panel? = nil
local machineFrame: Frame? = nil
local machineScale: UIScale? = nil
local cupFrame: Frame? = nil
local hireButton: TextButton? = nil
local slotsLabel: TextLabel? = nil
local gridFrame: ScrollingFrame? = nil
local revealOverlay: Frame? = nil
local lastInventoryKey: string? = nil
-- Reveal animations are chained task.delays; the generation counter lets a
-- second roll cleanly steal the stage from a still-running first one.
local rollGen = 0

-- The rarity maps are keyed by the Rarity singleton union, which the old
-- solver refuses to index with cross-module values (it widens the exported
-- singletons to plain string). Escaping through `any` once, here, keeps every
-- lookup site clean.
local rarityColors = Interns.RarityColors :: any
local rarityOdds = Interns.RarityOdds :: any

local function rarityColor(rarity: string): Color3
	local rgb = rarityColors[rarity] :: { number }?
	if not rgb then
		return Theme.Colors.TextDim -- unknown rarity: fail grey, not loudly
	end
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function inventoryKeyFor(state: StateController.ClientState): string
	local parts = table.create(#state.Interns + #state.EquippedInterns + 2)
	for _, intern in state.Interns do
		table.insert(parts, intern.Uid)
	end
	for _, uid in state.EquippedInterns do
		table.insert(parts, uid)
	end
	table.insert(parts, tostring(state.InternSlots))
	return table.concat(parts, "|")
end

-- ── Coffee machine art (Frames only — no image assets anywhere) ─────────────

local function buildMachine(parent: Frame)
	local machine = Instance.new("Frame")
	machine.Name = "Machine"
	machine.BackgroundTransparency = 1
	machine.AnchorPoint = Vector2.new(0.5, 0)
	machine.Position = UDim2.new(0.5, 0, 0, 4)
	machine.Size = UDim2.fromOffset(240, 232)
	machineFrame = machine

	local scale = Instance.new("UIScale")
	scale.Parent = machine
	machineScale = scale

	local tank = Instance.new("Frame")
	tank.Name = "Tank"
	tank.BackgroundColor3 = Theme.Colors.PanelDark
	tank.BorderSizePixel = 0
	tank.AnchorPoint = Vector2.new(0.5, 0)
	tank.Position = UDim2.new(0.5, 0, 0, 0)
	tank.Size = UDim2.fromOffset(150, 42)
	local tankCorner = Instance.new("UICorner")
	tankCorner.CornerRadius = UDim.new(0, Theme.Radius)
	tankCorner.Parent = tank
	tank.Parent = machine

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundColor3 = Theme.Colors.PanelLight
	body.BorderSizePixel = 0
	body.AnchorPoint = Vector2.new(0.5, 0)
	body.Position = UDim2.new(0.5, 0, 0, 36)
	body.Size = UDim2.fromOffset(210, 150)
	local bodyCorner = Instance.new("UICorner")
	bodyCorner.CornerRadius = UDim.new(0, Theme.Radius)
	bodyCorner.Parent = body
	local bodyStroke = Instance.new("UIStroke")
	bodyStroke.Thickness = Theme.StrokeThickness
	bodyStroke.Color = Theme.Colors.PanelDark
	bodyStroke.Parent = body
	body.Parent = machine

	local trim = Instance.new("Frame")
	trim.Name = "Trim"
	trim.BackgroundColor3 = Theme.Colors.Gold
	trim.BorderSizePixel = 0
	trim.Position = UDim2.new(0, 8, 0, 10)
	trim.Size = UDim2.new(1, -16, 0, 8)
	local trimCorner = Instance.new("UICorner")
	trimCorner.CornerRadius = UDim.new(0, Theme.Radius)
	trimCorner.Parent = trim
	trim.Parent = body

	local screen = Instance.new("Frame")
	screen.Name = "Screen"
	screen.BackgroundColor3 = Theme.Colors.Shadow
	screen.BorderSizePixel = 0
	screen.Position = UDim2.new(0, 16, 0, 30)
	screen.Size = UDim2.fromOffset(70, 40)
	local screenCorner = Instance.new("UICorner")
	screenCorner.CornerRadius = UDim.new(0, Theme.Radius)
	screenCorner.Parent = screen
	Theme.text({
		Text = "☕",
		Parent = screen,
		Size = UDim2.fromScale(1, 1),
		TextSize = 22,
	})
	screen.Parent = body

	-- Group head + spout: where the cup appears from during a roll.
	local group = Instance.new("Frame")
	group.Name = "GroupHead"
	group.BackgroundColor3 = Theme.Colors.PanelDark
	group.BorderSizePixel = 0
	group.AnchorPoint = Vector2.new(0.5, 0)
	group.Position = UDim2.new(0.5, 30, 1, -36)
	group.Size = UDim2.fromOffset(64, 26)
	local groupCorner = Instance.new("UICorner")
	groupCorner.CornerRadius = UDim.new(0, Theme.Radius)
	groupCorner.Parent = group
	group.Parent = body

	local spout = Instance.new("Frame")
	spout.Name = "Spout"
	spout.BackgroundColor3 = Theme.Colors.Shadow
	spout.BorderSizePixel = 0
	spout.AnchorPoint = Vector2.new(0.5, 0)
	spout.Position = UDim2.new(0.5, 30, 1, -12)
	spout.Size = UDim2.fromOffset(16, 14)
	spout.Parent = body

	local tray = Instance.new("Frame")
	tray.Name = "Tray"
	tray.BackgroundColor3 = Theme.Colors.PanelDark
	tray.BorderSizePixel = 0
	tray.AnchorPoint = Vector2.new(0.5, 1)
	tray.Position = UDim2.new(0.5, 0, 1, 0)
	tray.Size = UDim2.fromOffset(232, 22)
	local trayCorner = Instance.new("UICorner")
	trayCorner.CornerRadius = UDim.new(0, Theme.Radius)
	trayCorner.Parent = tray
	tray.Parent = machine

	local cup = Instance.new("Frame")
	cup.Name = "Cup"
	cup.BackgroundColor3 = Theme.Colors.Text
	cup.BorderSizePixel = 0
	cup.AnchorPoint = Vector2.new(0.5, 1)
	cup.Position = UDim2.new(0.5, 30, 1, -60)
	cup.Size = UDim2.fromOffset(40, 34)
	cup.Visible = false
	local cupCorner = Instance.new("UICorner")
	cupCorner.CornerRadius = UDim.new(0, Theme.Radius)
	cupCorner.Parent = cup
	local handle = Instance.new("Frame")
	handle.Name = "Handle"
	handle.BackgroundTransparency = 1
	handle.Position = UDim2.new(1, -2, 0, 8)
	handle.Size = UDim2.fromOffset(12, 18)
	local handleStroke = Instance.new("UIStroke")
	handleStroke.Thickness = Theme.StrokeThickness
	handleStroke.Color = Theme.Colors.Text
	handleStroke.Parent = handle
	local handleCorner = Instance.new("UICorner")
	handleCorner.CornerRadius = UDim.new(0, Theme.Radius)
	handleCorner.Parent = handle
	handle.Parent = cup
	cup.Parent = machine
	cupFrame = cup

	machine.Parent = parent
end

local function buildOddsTable(parent: Frame)
	local card = Theme.card({
		Parent = parent,
		Size = UDim2.new(1, 0, 0, 168),
		Position = UDim2.new(0, 0, 1, -168),
		Name = "OddsTable",
	})
	Theme.text({
		Text = "HIRE ODDS (published)",
		Parent = card,
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.new(0, 8, 0, 4),
		Font = Theme.BodyBoldFont,
		TextSize = 12,
		Color = Theme.Colors.TextDim,
	})
	for index, rarity in Interns.RarityOrder do
		local y = 26 + (index - 1) * 27
		local dot = Instance.new("Frame")
		dot.Name = "Dot" .. rarity
		dot.BackgroundColor3 = rarityColor(rarity)
		dot.BorderSizePixel = 0
		dot.Position = UDim2.new(0, 12, 0, y + 7)
		dot.Size = UDim2.fromOffset(12, 12)
		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(0.5, 0)
		dotCorner.Parent = dot
		dot.Parent = card
		Theme.text({
			Text = rarity,
			Parent = card,
			Size = UDim2.new(1, -110, 0, 26),
			Position = UDim2.new(0, 32, 0, y),
			TextSize = 14,
			XAlign = Enum.TextXAlignment.Left,
		})
		Theme.text({
			Text = ("%d%%"):format((rarityOdds[rarity] :: number?) or 0),
			Parent = card,
			Size = UDim2.fromOffset(60, 26),
			Position = UDim2.new(1, -70, 0, y),
			Font = Theme.DisplayFont,
			TextSize = 15,
			Color = rarityColor(rarity),
			XAlign = Enum.TextXAlignment.Right,
		})
	end
end

-- ── Inventory grid ──────────────────────────────────────────────────────────

local function buildInternCard(parent: Instance, state: StateController.ClientState, owned: { Uid: string, Id: string }, order: number)
	local def = Interns.get(owned.Id)
	if not def then
		return -- roster entry removed in an update; skip rather than crash
	end
	local equipped = table.find(state.EquippedInterns, owned.Uid) ~= nil
	local color = rarityColor(def.Rarity)

	local card = Theme.button({
		Text = "",
		Variant = "ghost",
		Size = UDim2.fromOffset(148, 178),
		Parent = parent,
		LayoutOrder = order,
		Name = "Intern" .. owned.Uid,
		Silent = true, -- equip/deny below decides the sound
		OnClick = function()
			local latest = StateController.Get()
			if not latest then
				return
			end
			local nowEquipped = table.find(latest.EquippedInterns, owned.Uid) ~= nil
			if not nowEquipped and #latest.EquippedInterns >= latest.InternSlots then
				local slots = slotsLabel
				if slots then
					Theme.deny(slots) -- point the "no" at the slot counter
				end
				return
			end
			SoundController.play("Click")
			requestEquipIntern:FireServer(owned.Uid, not nowEquipped)
		end,
	})
	local stroke = card:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if equipped then color else Theme.Colors.PanelDark
	end

	local band = Instance.new("Frame")
	band.Name = "RarityBand"
	band.BackgroundColor3 = color
	band.BorderSizePixel = 0
	band.Size = UDim2.new(1, 0, 0, 26)
	local bandCorner = Instance.new("UICorner")
	bandCorner.CornerRadius = UDim.new(0, Theme.Radius)
	bandCorner.Parent = band
	Theme.text({
		Text = def.Rarity,
		Parent = band,
		Size = UDim2.fromScale(1, 1),
		Font = Theme.BodyBoldFont,
		TextSize = 12,
		Color = Theme.Colors.TextOnGold,
	})
	band.Parent = card

	Theme.text({
		Text = def.Name,
		Parent = card,
		Size = UDim2.new(1, -12, 0, 40),
		Position = UDim2.new(0, 6, 0, 30),
		Font = Theme.DisplayFont,
		TextSize = 16,
		Wrapped = true,
	})
	Theme.text({
		Text = "+" .. Format.abbreviate(def.PerSecond) .. "/s 💼",
		Parent = card,
		Size = UDim2.new(1, -12, 0, 22),
		Position = UDim2.new(0, 6, 0, 74),
		Font = Theme.DisplayFont,
		TextSize = 16,
		Color = Theme.Colors.Gold,
		StrokePx = 2,
	})
	if def.Special then
		-- The Consultant's Restructure perk is the whole reason to chase
		-- Legendary — it gets its own callout, not a buried tooltip.
		Theme.text({
			Text = ("⭐ Keeps %d%% Productivity through Restructure"):format(Balance.ConsultantKeepFraction * 100),
			Parent = card,
			Size = UDim2.new(1, -10, 0, 40),
			Position = UDim2.new(0, 5, 0, 98),
			TextSize = 10,
			Color = Theme.Colors.Gold,
			Wrapped = true,
		})
	end

	local chip = Instance.new("Frame")
	chip.Name = "EquipChip"
	chip.BackgroundColor3 = if equipped then Theme.Colors.Green else Theme.Colors.PanelDark
	chip.BorderSizePixel = 0
	chip.AnchorPoint = Vector2.new(0.5, 1)
	chip.Position = UDim2.new(0.5, 0, 1, -8)
	chip.Size = UDim2.fromOffset(116, 26)
	local chipCorner = Instance.new("UICorner")
	chipCorner.CornerRadius = UDim.new(0, Theme.Radius)
	chipCorner.Parent = chip
	Theme.text({
		Text = if equipped then "EQUIPPED ✓" else "TAP TO EQUIP",
		Parent = chip,
		Size = UDim2.fromScale(1, 1),
		Font = Theme.BodyBoldFont,
		TextSize = 11,
		Color = if equipped then Theme.Colors.TextOnGold else Theme.Colors.TextDim,
	})
	chip.Parent = card
end

local function rebuildInventory(state: StateController.ClientState)
	local grid = gridFrame
	if not grid then
		return
	end
	lastInventoryKey = inventoryKeyFor(state)

	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local slots = slotsLabel
	if slots then
		slots.Text = ("%d/%d equipped"):format(#state.EquippedInterns, state.InternSlots)
	end

	-- Best interns first: rarity descending, then output descending — the
	-- grid doubles as a "what should I equip" answer.
	local sorted = table.clone(state.Interns)
	local rarityRank: { [string]: number } = {}
	for index, rarity in Interns.RarityOrder do
		rarityRank[rarity] = index
	end
	table.sort(sorted, function(a, b)
		local defA, defB = Interns.get(a.Id), Interns.get(b.Id)
		local rankA = if defA then rarityRank[defA.Rarity] or 0 else 0
		local rankB = if defB then rarityRank[defB.Rarity] or 0 else 0
		if rankA ~= rankB then
			return rankA > rankB
		end
		local perA = if defA then defA.PerSecond else 0
		local perB = if defB then defB.PerSecond else 0
		return perA > perB
	end)

	if #sorted == 0 then
		Theme.text({
			Text = "Nobody on the payroll yet.\nThe coffee machine is hiring →",
			Parent = grid,
			Size = UDim2.new(1, -20, 0, 80),
			Position = UDim2.new(0, 10, 0, 30),
			TextSize = 16,
			Color = Theme.Colors.TextDim,
			Wrapped = true,
		})
		return
	end

	for order, owned in sorted do
		buildInternCard(grid, state, owned, order)
	end
end

local function refreshHireButton(state: StateController.ClientState)
	local button = hireButton
	if not button then
		return
	end
	local affordable = state.Wins >= Balance.CoffeeMachineCost
	button.BackgroundColor3 = if affordable then Theme.Colors.Gold else Theme.Colors.PanelLight
	button.TextColor3 = if affordable then Theme.Colors.TextOnGold else Theme.Colors.TextDim
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if affordable then Theme.Colors.GoldDark else Theme.Colors.PanelDark
	end
end

-- ── Roll reveal ─────────────────────────────────────────────────────────────

local function playReveal(payload: RollPayload)
	local overlay = revealOverlay
	local machine = machineFrame
	local scale = machineScale
	local cup = cupFrame
	local def = Interns.get(payload.InternId)
	if not (overlay and machine and scale and cup and def) then
		return
	end

	rollGen += 1
	local gen = rollGen
	local color = rarityColor(def.Rarity)

	-- Fresh stage every roll: whatever a previous reveal left behind goes.
	for _, child in overlay:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	overlay.Visible = false
	cup.Visible = false

	-- 1) The machine earns its keep: squash-and-stretch rumble.
	machine.Rotation = -4
	Theme.play(machine, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 4, true), { Rotation = 4 })
	Theme.play(scale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 2, true), { Scale = 1.06 })
	task.delay(0.72, function()
		if rollGen ~= gen then
			return
		end
		machine.Rotation = 0
		scale.Scale = 1

		-- 2) A fresh cup slides out of the group head onto the tray.
		SoundController.play("InternHired")
		cup.Visible = true
		cup.Position = UDim2.new(0.5, 30, 1, -60)
		Theme.play(cup, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 30, 1, -22),
		})
	end)

	-- 3) The intern card flips in over the whole panel.
	task.delay(1.05, function()
		if rollGen ~= gen then
			return
		end
		overlay.Visible = true

		local burst = Instance.new("Frame")
		burst.Name = "Burst"
		burst.BackgroundColor3 = color
		burst.BackgroundTransparency = 0.35
		burst.BorderSizePixel = 0
		burst.AnchorPoint = Vector2.new(0.5, 0.5)
		burst.Position = UDim2.fromScale(0.5, 0.5)
		burst.Size = UDim2.fromOffset(40, 40)
		burst.ZIndex = 2
		local burstCorner = Instance.new("UICorner")
		burstCorner.CornerRadius = UDim.new(0.5, 0)
		burstCorner.Parent = burst
		burst.Parent = overlay
		Theme.play(burst, TweenInfo.new(0.55, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(560, 560),
			BackgroundTransparency = 1,
		})

		local cardHolder = Instance.new("Frame")
		cardHolder.Name = "RevealCard"
		cardHolder.BackgroundTransparency = 1
		cardHolder.AnchorPoint = Vector2.new(0.5, 0.5)
		cardHolder.Position = UDim2.fromScale(0.5, 0.5)
		cardHolder.Size = UDim2.fromOffset(260, 330)
		cardHolder.Rotation = -16
		cardHolder.ZIndex = 3
		local holderScale = Instance.new("UIScale")
		holderScale.Scale = 0.25
		holderScale.Parent = cardHolder

		local card = Theme.card({
			Parent = cardHolder,
			Size = UDim2.fromScale(1, 1),
			Name = "Card",
			ZIndex = 3,
		})
		local cardStroke = card:FindFirstChildOfClass("UIStroke")
		if cardStroke then
			cardStroke.Color = color
			cardStroke.Thickness = Theme.StrokeThickness
		end
		local band = Instance.new("Frame")
		band.BackgroundColor3 = color
		band.BorderSizePixel = 0
		band.Size = UDim2.new(1, 0, 0, 42)
		band.ZIndex = 3
		local bandCorner = Instance.new("UICorner")
		bandCorner.CornerRadius = UDim.new(0, Theme.Radius)
		bandCorner.Parent = band
		Theme.text({
			Text = def.Rarity .. "!",
			Parent = band,
			Size = UDim2.fromScale(1, 1),
			Font = Theme.DisplayFont,
			TextSize = 20,
			Color = Theme.Colors.TextOnGold,
			ZIndex = 3,
		})
		band.Parent = card
		Theme.text({
			Text = "🧑‍💼",
			Parent = card,
			Size = UDim2.new(1, 0, 0, 70),
			Position = UDim2.new(0, 0, 0, 52),
			TextSize = 54,
			ZIndex = 3,
		})
		Theme.title({
			Text = def.Name,
			Parent = card,
			Size = UDim2.new(1, -16, 0, 56),
			Position = UDim2.new(0, 8, 0, 124),
			TextSize = 22,
			Color = Theme.Colors.Text,
			ZIndex = 3,
		})
		Theme.text({
			Text = "+" .. Format.abbreviate(def.PerSecond) .. "/s 💼",
			Parent = card,
			Size = UDim2.new(1, 0, 0, 28),
			Position = UDim2.new(0, 0, 0, 182),
			Font = Theme.DisplayFont,
			TextSize = 22,
			Color = Theme.Colors.Gold,
			StrokePx = 2,
			ZIndex = 3,
		})
		Theme.text({
			Text = def.Blurb,
			Parent = card,
			Size = UDim2.new(1, -24, 0, 60),
			Position = UDim2.new(0, 12, 0, 216),
			TextSize = 13,
			Color = Theme.Colors.TextDim,
			Wrapped = true,
			ZIndex = 3,
		})
		if def.Special then
			Theme.text({
				Text = ("⭐ Keeps %d%% Productivity through Restructure"):format(Balance.ConsultantKeepFraction * 100),
				Parent = card,
				Size = UDim2.new(1, -20, 0, 36),
				Position = UDim2.new(0, 10, 1, -44),
				TextSize = 12,
				Color = Theme.Colors.Gold,
				Wrapped = true,
				ZIndex = 3,
			})
		end
		cardHolder.Parent = overlay

		Theme.play(holderScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		Theme.play(cardHolder, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 0 })

		-- Epic and Legendary get the full confetti treatment; commons stay
		-- quick so mass-rolling never feels slow.
		if def.Rarity == "Epic" or def.Rarity == "Legendary" then
			Theme.confettiBurst(overlay, 30, { color, Theme.Colors.Gold, Theme.Colors.Text })
		end

		task.delay(1.75, function()
			if rollGen ~= gen then
				return
			end
			Theme.play(holderScale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
			task.delay(0.24, function()
				if rollGen ~= gen then
					return
				end
				overlay.Visible = false
				cup.Visible = false
			end)
		end)
	end)
end

-- ── Panel assembly ──────────────────────────────────────────────────────────

local function isOpen(): boolean
	return Theme.currentPanel() == PANEL_NAME
end

function InternUi.open()
	local handle = panel
	if not handle or isOpen() then
		return
	end
	local state = StateController.Get()
	if state then
		rebuildInventory(state)
		refreshHireButton(state)
	end
	Theme.openExclusive(handle)
end

function InternUi.toggle()
	if isOpen() then
		Theme.closeExclusive(PANEL_NAME)
	else
		InternUi.open()
	end
end

function InternUi:Init()
	local gui = Theme.screenGui("InternUi", 5, trove)
	local newPanel = Theme.panel({
		Name = PANEL_NAME,
		Title = "COFFEE MACHINE ☕",
		Size = PANEL_SIZE,
		Parent = gui,
		Trove = trove,
	})
	panel = newPanel

	local left = Instance.new("Frame")
	left.Name = "HireSide"
	left.BackgroundTransparency = 1
	left.Size = UDim2.new(0, LEFT_WIDTH, 1, 0)
	left.Parent = newPanel.Body

	buildMachine(left)

	hireButton = Theme.button({
		Text = ("HIRE — %s 🏆"):format(Format.abbreviate(Balance.CoffeeMachineCost)),
		Variant = "primary",
		Size = UDim2.new(1, -20, 0, 58),
		Position = UDim2.new(0, 10, 0, 244),
		TextSize = 23,
		Parent = left,
		Name = "HireButton",
		OnClick = function()
			local state = StateController.Get()
			if state and state.Wins >= Balance.CoffeeMachineCost then
				requestHireIntern:FireServer()
			else
				local machine = machineFrame
				if machine then
					Theme.deny(machine)
				end
			end
		end,
	})

	buildOddsTable(left)

	local right = Instance.new("Frame")
	right.Name = "InventorySide"
	right.BackgroundTransparency = 1
	right.Position = UDim2.new(0, LEFT_WIDTH + 14, 0, 0)
	right.Size = UDim2.new(1, -(LEFT_WIDTH + 14), 1, 0)
	right.Parent = newPanel.Body

	Theme.title({
		Text = "YOUR INTERNS",
		Parent = right,
		Size = UDim2.new(1, -140, 0, 28),
		Position = UDim2.new(0, 4, 0, 0),
		TextSize = 20,
		Color = Theme.Colors.Text,
		XAlign = Enum.TextXAlignment.Left,
	})
	slotsLabel = Theme.text({
		Text = "0/0 equipped",
		Parent = right,
		Size = UDim2.fromOffset(140, 28),
		Position = UDim2.new(1, -144, 0, 0),
		Font = Theme.DisplayFont,
		TextSize = 17,
		Color = Theme.Colors.Gold,
		XAlign = Enum.TextXAlignment.Right,
		StrokePx = 2,
	})

	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Position = UDim2.new(0, 0, 0, 34)
	grid.Size = UDim2.new(1, 0, 1, -34)
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.ScrollBarThickness = Theme.StrokeThickness
	grid.ScrollBarImageColor3 = Theme.Colors.Gold
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(148, 178)
	gridLayout.CellPadding = UDim2.fromOffset(8, 8)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid
	grid.Parent = right
	gridFrame = grid

	-- Reveal overlay sits above the whole panel surface so the card reads as
	-- a moment, not one more widget in the layout.
	local overlay = Instance.new("Frame")
	overlay.Name = "RevealOverlay"
	overlay.BackgroundColor3 = Theme.Colors.Shadow
	overlay.BackgroundTransparency = 0.35
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Visible = false
	overlay.ZIndex = 3
	local overlayCorner = Instance.new("UICorner")
	overlayCorner.CornerRadius = UDim.new(0, Theme.Radius)
	overlayCorner.Parent = overlay
	overlay.Parent = newPanel.Anim
	revealOverlay = overlay
end

function InternUi:Start()
	-- Cast: sleitnick Signal's typed Connect doesn't unify with Trove's
	-- SignalLike under the old solver; the runtime shapes match fine.
	trove:Connect(StateController.Changed :: any, function(state: StateController.ClientState)
		refreshHireButton(state)
		if isOpen() and inventoryKeyFor(state) ~= lastInventoryKey then
			rebuildInventory(state)
		end
	end)
	trove:Connect(internRollResult.OnClientEvent, function(payload: RollPayload)
		-- A hire can come from the world prompt while the panel is shut;
		-- the reveal only makes sense with the machine on screen.
		if not isOpen() then
			InternUi.open()
		end
		playReveal(payload)
	end)
end

return InternUi
