--!strict
-- The prestige loop: shows what a Restructure costs, what survives it, and
-- runs the severance-card pick that follows. The server decides everything —
-- this file only asks (RequestRestructure/RequestSeverance) and celebrates.
-- The card overlay also auto-opens whenever PendingSeverance is non-empty so a
-- player who disconnected mid-pick gets their cards back on rejoin.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))
local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Format"))
local Balance = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Balance"))
local Ranks = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Ranks"))
local Severance = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Severance"))
local StateController = require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("StateController"))
local SoundController = require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("SoundController"))
local CameraFx = require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("CameraFx"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestRestructure = remotes:WaitForChild("RequestRestructure") :: RemoteEvent
local requestSeverance = remotes:WaitForChild("RequestSeverance") :: RemoteEvent
local fxRemote = remotes:WaitForChild("Fx") :: RemoteEvent

local PANEL_NAME = "Restructure"
local PANEL_SIZE = UDim2.fromOffset(800, 560)
local PAPER_COUNT = 26
local STORM_SECONDS = 1.1

type FxPayload = {
	Kind: string,
	UserId: number?,
}

local RestructureUi = {}

local trove = Trove.new()
local rng = Random.new()
local panel: Theme.Panel? = nil
local costLabel: TextLabel? = nil
local progressBar: Theme.ProgressBar? = nil
local bonusLabel: TextLabel? = nil
local restructureButton: TextButton? = nil
local requirementLabel: TextLabel? = nil
local confirmOverlay: Frame? = nil
local cardsOverlay: Frame? = nil
local cardsRow: Frame? = nil
local storming = false
local celebrating = false
-- Which PendingSeverance offer is currently displayed, so the same state
-- echoing back from the server doesn't re-deal the cards mid-hover.
local shownPendingKey = ""

local function isAffordable(state: StateController.ClientState): boolean
	return state.Rank >= Balance.RestructureMinRank and state.Productivity >= state.RestructureCost
end

-- ── Panel refresh ───────────────────────────────────────────────────────────

local function refreshPanel(state: StateController.ClientState)
	local cost = costLabel
	if cost then
		cost.Text = ("%s / %s 💼"):format(Format.abbreviate(state.Productivity), Format.abbreviate(state.RestructureCost))
	end
	local bar = progressBar
	if bar then
		local denominator = math.max(state.RestructureCost, 1)
		bar.Set(math.clamp(state.Productivity / denominator, 0, 1))
	end
	local bonus = bonusLabel
	if bonus then
		local totalPercent = state.Restructures * Balance.RestructureBonusPerOwned * 100
		bonus.Text = ("Each Restructure: +%d%% Productivity forever · You own %d (+%d%%)"):format(
			Balance.RestructureBonusPerOwned * 100,
			state.Restructures,
			totalPercent
		)
	end

	local affordable = isAffordable(state)
	local button = restructureButton
	if button then
		button.BackgroundColor3 = if affordable then Theme.Colors.Red else Theme.Colors.PanelLight
		button.TextColor3 = if affordable then Theme.Colors.Text else Theme.Colors.TextDim
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if affordable then Theme.Colors.RedDark else Theme.Colors.PanelDark
		end
	end
	local requirement = requirementLabel
	if requirement then
		if state.Rank < Balance.RestructureMinRank then
			local neededRank = Ranks.List[Balance.RestructureMinRank]
			requirement.Text = ("Requires rank: %s"):format(if neededRank then neededRank.Name else "?")
			requirement.TextColor3 = Theme.Colors.TextDim
		elseif not affordable then
			requirement.Text = ("Need %s more Productivity"):format(Format.abbreviate(state.RestructureCost - state.Productivity))
			requirement.TextColor3 = Theme.Colors.TextDim
		else
			requirement.Text = "Ready. The shareholders are waiting."
			requirement.TextColor3 = Theme.Colors.Green
		end
	end
end

-- ── Keep / reset checklists ─────────────────────────────────────────────────

local function buildChecklist(parent: Frame, xScale: number, titleText: string, titleColor: Color3, mark: string, rows: { string })
	local card = Theme.card({
		Parent = parent,
		Size = UDim2.new(0.5, -6, 1, 0),
		Position = UDim2.fromScale(xScale, 0),
		Name = titleText,
	})
	Theme.title({
		Text = titleText,
		Parent = card,
		Size = UDim2.new(1, -16, 0, 30),
		Position = UDim2.new(0, 8, 0, 6),
		TextSize = 19,
		Color = titleColor,
	})
	for index, rowText in rows do
		Theme.text({
			Text = mark .. "  " .. rowText,
			Parent = card,
			Size = UDim2.new(1, -20, 0, 24),
			Position = UDim2.new(0, 12, 0, 34 + (index - 1) * 26),
			TextSize = 14,
			Color = titleColor,
			XAlign = Enum.TextXAlignment.Left,
		})
	end
end

-- ── Confirm dialog ──────────────────────────────────────────────────────────

local function buildConfirm(parent: Frame)
	local overlay = Instance.new("Frame")
	overlay.Name = "ConfirmOverlay"
	overlay.BackgroundColor3 = Theme.Colors.Shadow
	overlay.BackgroundTransparency = 0.4
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Visible = false
	overlay.ZIndex = 4
	local overlayCorner = Instance.new("UICorner")
	overlayCorner.CornerRadius = UDim.new(0, 16)
	overlayCorner.Parent = overlay

	local dialog = Theme.card({
		Parent = overlay,
		Size = UDim2.fromOffset(400, 220),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Name = "ConfirmDialog",
		ZIndex = 4,
	})
	Theme.title({
		Text = "Really restructure?",
		Parent = dialog,
		Size = UDim2.new(1, -20, 0, 36),
		Position = UDim2.new(0, 10, 0, 14),
		TextSize = 24,
		Color = Theme.Colors.Text,
		ZIndex = 4,
	})
	Theme.text({
		Text = "Productivity and Rank reset to zero.\nEverything else stays. Forever bonus applies.",
		Parent = dialog,
		Size = UDim2.new(1, -32, 0, 48),
		Position = UDim2.new(0, 16, 0, 56),
		TextSize = 14,
		Color = Theme.Colors.TextDim,
		Wrapped = true,
		ZIndex = 4,
	})
	Theme.button({
		Text = "CANCEL",
		Variant = "ghost",
		Size = UDim2.fromOffset(160, 56),
		Position = UDim2.new(0.5, -84, 1, -70),
		AnchorPoint = Vector2.new(0.5, 0),
		TextSize = 18,
		Parent = dialog,
		ZIndex = 4,
		OnClick = function()
			overlay.Visible = false
		end,
	})
	Theme.button({
		Text = "RESTRUCTURE",
		Variant = "danger",
		Size = UDim2.fromOffset(180, 56),
		Position = UDim2.new(0.5, 96, 1, -70),
		AnchorPoint = Vector2.new(0.5, 0),
		TextSize = 18,
		Parent = dialog,
		ZIndex = 4,
		OnClick = function()
			overlay.Visible = false
			requestRestructure:FireServer()
		end,
	})

	overlay.Parent = parent
	confirmOverlay = overlay
end

-- ── Severance cards ─────────────────────────────────────────────────────────

local function hideCards()
	local overlay = cardsOverlay
	if overlay then
		overlay.Visible = false
	end
	celebrating = false
	shownPendingKey = ""
end

local function showCards(pendingIds: { string })
	local overlay = cardsOverlay
	local row = cardsRow
	if not (overlay and row) then
		return
	end
	local key = table.concat(pendingIds, ",")
	if overlay.Visible and key == shownPendingKey then
		return
	end
	shownPendingKey = key
	celebrating = false

	for _, child in row:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	overlay.Visible = true
	local picked = false

	for index, perkId in pendingIds do
		local perk = Severance.get(perkId)
		if not perk then
			continue
		end

		-- Holder owns the deal-in scale so it never fights the button's own
		-- hover/press UIScale.
		local holder = Instance.new("Frame")
		holder.Name = "Offer" .. perkId
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromOffset(210, 280)
		holder.LayoutOrder = index
		local holderScale = Instance.new("UIScale")
		holderScale.Scale = 0
		holderScale.Parent = holder

		local card = Theme.button({
			Text = "",
			Variant = "ghost",
			Size = UDim2.fromScale(1, 1),
			Parent = holder,
			Name = "Perk" .. perkId,
			OnClick = function()
				if picked then
					return
				end
				picked = true
				celebrating = true
				requestSeverance:FireServer(perkId)

				-- Winner takes the stage, the rejects clock out.
				Theme.play(holderScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.12 })
				Theme.confettiBurst(holder, 24)
				for _, sibling in row:GetChildren() do
					if sibling:IsA("Frame") and sibling ~= holder then
						local siblingScale = sibling:FindFirstChildOfClass("UIScale")
						if siblingScale then
							Theme.play(siblingScale, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
						end
					end
				end
				task.delay(1.0, hideCards)
			end,
		})
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = Theme.Colors.Gold
		end
		Theme.text({
			Text = perk.Icon,
			Parent = card,
			Size = UDim2.new(1, 0, 0, 80),
			Position = UDim2.new(0, 0, 0, 20),
			TextSize = 56,
		})
		Theme.title({
			Text = perk.Name,
			Parent = card,
			Size = UDim2.new(1, -16, 0, 52),
			Position = UDim2.new(0, 8, 0, 104),
			TextSize = 20,
		})
		Theme.text({
			Text = perk.Description,
			Parent = card,
			Size = UDim2.new(1, -24, 0, 80),
			Position = UDim2.new(0, 12, 0, 160),
			TextSize = 14,
			Color = Theme.Colors.TextDim,
			Wrapped = true,
		})
		Theme.text({
			Text = "PICK ME",
			Parent = card,
			Size = UDim2.new(1, 0, 0, 22),
			Position = UDim2.new(0, 0, 1, -30),
			Font = Theme.BodyBoldFont,
			TextSize = 13,
			Color = Theme.Colors.Gold,
		})
		holder.Parent = row

		-- Staggered deal: each card lands 0.12s after the previous one.
		task.delay(0.1 + (index - 1) * 0.12, function()
			if holder.Parent then
				Theme.play(holderScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			end
		end)
	end
end

-- ── Paper storm (Fx Restructure for the local player) ───────────────────────

local function paperStorm()
	local overlay = cardsOverlay
	if not overlay then
		return
	end
	storming = true
	SoundController.play("Restructure")
	CameraFx.shake(0.6)

	-- The storm rains on its own full-screen layer so it can fly over
	-- whatever panel state the player was in.
	local stormFrame = Instance.new("Frame")
	stormFrame.Name = "PaperStorm"
	stormFrame.BackgroundTransparency = 1
	stormFrame.Size = UDim2.fromScale(1, 1)
	stormFrame.ZIndex = 6
	stormFrame.Parent = overlay.Parent

	for _ = 1, PAPER_COUNT do
		task.delay(rng:NextNumber(0, 0.35), function()
			if not stormFrame.Parent then
				return
			end
			local paper = Instance.new("Frame")
			paper.Name = "Paper"
			-- Off-white sheets, not confetti: this is paperwork raining down.
			paper.BackgroundColor3 = Color3.fromRGB(240, 238, 228)
			paper.BorderSizePixel = 0
			paper.Size = UDim2.fromOffset(rng:NextInteger(18, 30), rng:NextInteger(24, 38))
			paper.Rotation = rng:NextNumber(0, 360)
			paper.ZIndex = 6
			local x = rng:NextNumber(0.02, 0.98)
			paper.Position = UDim2.fromScale(x, -0.1)
			paper.Parent = stormFrame
			Theme.play(paper, TweenInfo.new(rng:NextNumber(0.7, STORM_SECONDS), Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromScale(x + rng:NextNumber(-0.15, 0.15), 1.1),
				Rotation = paper.Rotation + rng:NextNumber(-360, 360),
			})
		end)
	end

	task.delay(STORM_SECONDS + 0.45, function()
		stormFrame:Destroy()
		storming = false
		-- Cards ride in right behind the storm. If the state snapshot with the
		-- offer hasn't replicated yet, the Changed watcher picks it up instead.
		local state = StateController.Get()
		if state and #state.PendingSeverance > 0 then
			showCards(state.PendingSeverance)
		end
	end)
end

-- ── Public API + lifecycle ──────────────────────────────────────────────────

local function isOpen(): boolean
	return Theme.currentPanel() == PANEL_NAME
end

function RestructureUi.open()
	local handle = panel
	if not handle or isOpen() then
		return
	end
	local state = StateController.Get()
	if state then
		refreshPanel(state)
	end
	Theme.openExclusive(handle)
end

function RestructureUi.toggle()
	if isOpen() then
		Theme.closeExclusive(PANEL_NAME)
	else
		RestructureUi.open()
	end
end

function RestructureUi:Init()
	-- IgnoreGuiInset so the paper storm and card overlay cover the full
	-- screen, topbar included.
	local gui = Theme.screenGui("RestructureUi", 5, trove, true)
	local newPanel = Theme.panel({
		Name = PANEL_NAME,
		Title = "RESTRUCTURE 📉",
		Size = PANEL_SIZE,
		Parent = gui,
		Trove = trove,
	})
	panel = newPanel
	local body = newPanel.Body

	Theme.text({
		Text = "Trade this run's grind for a permanent head start.",
		Parent = body,
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 15,
		Color = Theme.Colors.TextDim,
	})

	costLabel = Theme.text({
		Text = "0 / 0 💼",
		Parent = body,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0, 26),
		Font = Theme.DisplayFont,
		TextSize = 24,
		Color = Theme.Colors.Gold,
		StrokePx = 2,
	})
	progressBar = Theme.progressBar({
		Parent = body,
		Size = UDim2.new(1, -80, 0, 18),
		Position = UDim2.new(0, 40, 0, 62),
	})
	bonusLabel = Theme.text({
		Text = "",
		Parent = body,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 0, 88),
		TextSize = 13,
		Color = Theme.Colors.TextDim,
	})

	local lists = Instance.new("Frame")
	lists.Name = "Checklists"
	lists.BackgroundTransparency = 1
	lists.Position = UDim2.new(0, 0, 0, 118)
	lists.Size = UDim2.new(1, 0, 0, 200)
	lists.Parent = body
	buildChecklist(lists, 0, "YOU KEEP ✓", Theme.Colors.Green, "✓", {
		"🏆 Wins",
		"⌨️ Gear tiers",
		"☕ Interns",
		"🛗 Floor & boss progress",
		"🪂 Severance perks",
	})
	buildChecklist(lists, 0.5, "RESET ✗", Theme.Colors.Red, "✗", {
		"💼 Productivity → 0",
		"👔 Rank → back to the bottom",
	})
	-- The reset column is short; use the space to sell the upside instead of
	-- leaving scary red emptiness.
	Theme.text({
		Text = ("…and you come back stronger: +%d%% Productivity forever, plus one Severance perk of your choice."):format(
			Balance.RestructureBonusPerOwned * 100
		),
		Parent = lists,
		Size = UDim2.new(0.5, -30, 0, 90),
		Position = UDim2.new(0.5, 12, 0, 96),
		TextSize = 13,
		Color = Theme.Colors.TextDim,
		Wrapped = true,
	})

	restructureButton = Theme.button({
		Text = "RESTRUCTURE 📉",
		Variant = "danger",
		Size = UDim2.fromOffset(320, 64),
		Position = UDim2.new(0.5, 0, 1, -92),
		AnchorPoint = Vector2.new(0.5, 0),
		TextSize = 26,
		Parent = body,
		Name = "RestructureButton",
		OnClick = function()
			local state = StateController.Get()
			local overlay = confirmOverlay
			if state and isAffordable(state) and overlay then
				overlay.Visible = true
			else
				local button = restructureButton
				if button then
					Theme.deny(button)
				end
			end
		end,
	})
	requirementLabel = Theme.text({
		Text = "",
		Parent = body,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 1, -22),
		TextSize = 13,
		Color = Theme.Colors.TextDim,
	})

	buildConfirm(newPanel.Anim)

	-- Full-screen severance overlay lives outside the panel: the pick must be
	-- possible even while the panel itself is closed (rejoin case).
	local overlay = Instance.new("Frame")
	overlay.Name = "SeveranceOverlay"
	overlay.BackgroundColor3 = Theme.Colors.Shadow
	overlay.BackgroundTransparency = 0.3
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Visible = false
	overlay.ZIndex = 5
	overlay.Parent = gui
	cardsOverlay = overlay

	local overlayCenter = Instance.new("Frame")
	overlayCenter.Name = "Center"
	overlayCenter.BackgroundTransparency = 1
	overlayCenter.AnchorPoint = Vector2.new(0.5, 0.5)
	overlayCenter.Position = UDim2.fromScale(0.5, 0.5)
	overlayCenter.Size = UDim2.fromOffset(720, 420)
	overlayCenter.ZIndex = 5
	Theme.autoScale(overlayCenter, trove, Vector2.new(720, 420))
	overlayCenter.Parent = overlay

	Theme.title({
		Text = "SEVERANCE PACKAGE 🪂",
		Parent = overlayCenter,
		Size = UDim2.new(1, 0, 0, 44),
		TextSize = 34,
		StrokePx = 3,
	})
	Theme.text({
		Text = "Pick one. It's permanent.",
		Parent = overlayCenter,
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.new(0, 0, 0, 46),
		TextSize = 15,
		Color = Theme.Colors.TextDim,
	})

	local row = Instance.new("Frame")
	row.Name = "Cards"
	row.BackgroundTransparency = 1
	row.Position = UDim2.new(0, 0, 0, 90)
	row.Size = UDim2.new(1, 0, 0, 290)
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout.Padding = UDim.new(0, 20)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = row
	row.Parent = overlayCenter
	cardsRow = row
end

function RestructureUi:Start()
	-- Cast: sleitnick Signal's typed Connect doesn't unify with Trove's
	-- SignalLike under the old solver; the runtime shapes match fine.
	trove:Connect(StateController.Changed :: any, function(state: StateController.ClientState)
		refreshPanel(state)
		if #state.PendingSeverance > 0 then
			-- Deal (or re-deal after rejoin) unless the storm is about to do
			-- it with better timing.
			if not storming and not celebrating then
				showCards(state.PendingSeverance)
			end
		elseif not celebrating then
			hideCards()
		end
	end)

	trove:Connect(fxRemote.OnClientEvent, function(payload: FxPayload)
		if payload.Kind == "Restructure" and payload.UserId == Players.LocalPlayer.UserId then
			Theme.closeExclusive(PANEL_NAME)
			paperStorm()
		end
	end)

	-- Rejoin safety: the first snapshot may already carry an unpicked offer.
	task.spawn(function()
		local state = StateController.await()
		refreshPanel(state)
		if #state.PendingSeverance > 0 then
			showCards(state.PendingSeverance)
		end
	end)
end

return RestructureUi
