--!strict
-- The heads-up display, laid out like the reference screenshots:
--
--   ┌──────────────────────────────────────────────────────────┐
--   │            [ stage banner: STAGE 2 · 3/7 beaten ]        │
--   │ [shop]                                                   │
--   │ [wardrobe]                                               │
--   │ [pets]                                                   │
--   │ [restructure]                                            │
--   │ ⚡ 1.2K                                                   │
--   │ 🏆 240              [ objective: Beat 4 more Temps ]     │
--   │ 🤝 2                                                     │
--   └──────────────────────────────────────────────────────────┘
--
-- Currencies stack in the bottom-left as icon pills, the current objective
-- sits bottom-centre, and the buttons run down the left edge.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent:WaitForChild("Theme"))
local Icons = require(script.Parent:WaitForChild("Icons"))
local StateController = require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("StateController"))

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Format"))
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

local stageStateRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StageState") :: RemoteEvent

local Hud = {}

local trove = Trove.new()
local gui: ScreenGui? = nil

-- Live display values, eased toward their true value so counters roll.
local shownPower = 0
local powerLabel: TextLabel? = nil
local winsLabel: TextLabel? = nil
local petsLabel: TextLabel? = nil
local perClickLabel: TextLabel? = nil
local objectiveLabel: TextLabel? = nil
local bannerLabel: TextLabel? = nil
local bannerSub: TextLabel? = nil

local stageProgress: { [number]: { Kills: number, Needed: number } } = {}
local clearedStages: { [number]: boolean } = {}

-- ── Building blocks ─────────────────────────────────────────────────────────

-- A currency pill: round icon on the left, big number on the right. This is
-- the shape the reference HUD uses in its bottom-left corner.
local function currencyPill(parent: Frame, order: number, iconName: string, tint: Color3): TextLabel
	local row = Instance.new("Frame")
	row.Name = "Pill" .. order
	row.BackgroundColor3 = Theme.Colors.Panel
	row.BackgroundTransparency = 0.12
	row.BorderSizePixel = 0
	row.Size = UDim2.fromOffset(190, 46)
	row.LayoutOrder = order
	row.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Theme.Radius)
	corner.Parent = row

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.PanelDark
	stroke.Thickness = Theme.StrokeThickness
	stroke.Parent = row

	local badge = Instance.new("Frame")
	badge.BackgroundColor3 = tint
	badge.BorderSizePixel = 0
	badge.Position = UDim2.fromOffset(4, 4)
	badge.Size = UDim2.fromOffset(38, 38)
	badge.Parent = row
	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(1, 0)
	badgeCorner.Parent = badge
	local badgeStroke = Instance.new("UIStroke")
	badgeStroke.Color = Theme.Colors.PanelDark
	badgeStroke.Thickness = Theme.StrokeThickness
	badgeStroke.Parent = badge

	-- Drawn, not emoji: platform glyph sets differ and several ignore tinting.
	local iconHolder = Instance.new("Frame")
	iconHolder.BackgroundTransparency = 1
	iconHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	iconHolder.Position = UDim2.fromScale(0.5, 0.5)
	iconHolder.Size = UDim2.fromScale(0.66, 0.66)
	iconHolder.Parent = badge
	Icons.create(iconHolder, iconName, Theme.Colors.Text, Theme.Colors.Ink)

	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.BackgroundTransparency = 1
	value.Position = UDim2.fromOffset(50, 0)
	value.Size = UDim2.new(1, -60, 1, 0)
	value.Font = Enum.Font.FredokaOne
	value.Text = "0"
	value.TextColor3 = Theme.Colors.Text
	value.TextScaled = true
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.TextStrokeTransparency = 0.4
	value.Parent = row

	local sizeLimit = Instance.new("UITextSizeConstraint")
	sizeLimit.MaxTextSize = 30
	sizeLimit.Parent = value

	return value
end

-- ── Objective text ──────────────────────────────────────────────────────────

-- Which stage is the player standing in, judged by world position: the hub is
-- around x=0 and each stage sits further east.
local function currentStageNumber(): number
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not (root and root:IsA("BasePart")) then
		return 0
	end
	local x = root.Position.X
	local best, bestDistance = 0, math.huge
	for _, stage in Stages.List do
		local distance = math.abs(x - stage.Origin[1])
		if distance < bestDistance then
			best, bestDistance = stage.Number, distance
		end
	end
	return best
end

-- The single most useful sentence we can put on screen right now.
local function objectiveText(state: any): string
	local stageNumber = currentStageNumber()
	if stageNumber == 0 then
		if state and state.Wins and state.Wins >= 5 then
			return "Spend your Wins at the Wardrobe, then head east"
		end
		return "Hit a training bag, then follow the arrows east"
	end
	local stage = Stages.byNumber(stageNumber)
	if not stage then
		return "Follow the arrows"
	end
	if clearedStages[stageNumber] then
		return ("Stage %d cleared — touch a WINS pad, or push east"):format(stageNumber)
	end
	local progress = stageProgress[stageNumber]
	local killed = if progress then progress.Kills else 0
	local needed = stage.EnemyCount
	return ("Defeat %d more %s"):format(math.max(needed - killed, 0), stage.EnemyName .. "s")
end

local function bannerText(): (string, string)
	local stageNumber = currentStageNumber()
	if stageNumber == 0 then
		local stage = Stages.get("Hub")
		return "HQ PLAZA", if stage then stage.Blurb else ""
	end
	local stage = Stages.byNumber(stageNumber)
	if not stage then
		return "", ""
	end
	local progress = stageProgress[stageNumber]
	local killed = if progress then progress.Kills else 0
	local status = if clearedStages[stageNumber]
		then "CLEARED ✔"
		else ("%d / %d defeated"):format(killed, stage.EnemyCount)
	return ("STAGE %d · %s"):format(stage.Number, stage.DisplayName:upper()),
		("%s   ·   Recommended Power: %s"):format(status, Format.abbreviate(stage.RecommendedPower))
end

-- ── Lifecycle ───────────────────────────────────────────────────────────────

function Hud:Init()
	local screen = Theme.screenGui("Hud", 1, trove, true)
	gui = screen

	-- Bottom-left currency stack.
	local stack = Instance.new("Frame")
	stack.Name = "Currencies"
	stack.BackgroundTransparency = 1
	stack.AnchorPoint = Vector2.new(0, 1)
	stack.Position = UDim2.new(0, 18, 1, -18)
	stack.Size = UDim2.fromOffset(200, 168)
	stack.Parent = screen

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = stack

	powerLabel = currencyPill(stack, 1, "Bolt", Theme.Colors.Gold)
	winsLabel = currencyPill(stack, 2, "Trophy", Theme.Colors.Green)
	petsLabel = currencyPill(stack, 3, "People", Color3.fromRGB(120, 150, 255))

	-- Per-click readout under the stack.
	-- Rate readout, in a pill so it stays legible over any world behind it.
	local ratePill = Instance.new("Frame")
	ratePill.Name = "RatePill"
	ratePill.AnchorPoint = Vector2.new(0, 1)
	ratePill.Position = UDim2.new(0, 18, 1, -186)
	ratePill.Size = UDim2.fromOffset(268, 34)
	ratePill.BackgroundColor3 = Theme.Colors.Panel
	ratePill.BackgroundTransparency = 0.12
	ratePill.BorderSizePixel = 0
	ratePill.Parent = screen
	Theme.corner(ratePill, true)
	Theme.stroke(ratePill, Theme.Colors.PanelDark)
	Theme.padding(ratePill, 6)

	local perClick = Instance.new("TextLabel")
	perClick.Name = "PerClick"
	perClick.BackgroundTransparency = 1
	perClick.Size = UDim2.fromScale(1, 1)
	perClick.Font = Enum.Font.GothamBold
	perClick.Text = ""
	perClick.TextColor3 = Theme.Colors.Text
	perClick.TextScaled = true
	perClick.TextXAlignment = Enum.TextXAlignment.Left
	perClick.Parent = ratePill
	local perClickLimit = Instance.new("UITextSizeConstraint")
	perClickLimit.MaxTextSize = 18
	perClickLimit.Parent = perClick
	local perClickStroke = Instance.new("UIStroke")
	perClickStroke.Color = Theme.Colors.Ink
	perClickStroke.Thickness = Theme.StrokeThickness
	perClickStroke.Transparency = Theme.StrokeTransparency
	perClickStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	perClickStroke.Parent = perClick
	perClickLabel = perClick
	Theme.autoScale(ratePill, trove)

	-- Top-centre stage banner.
	local banner = Instance.new("Frame")
	banner.Name = "StageBanner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 12)
	banner.Size = UDim2.fromOffset(460, 66)
	banner.BackgroundColor3 = Theme.Colors.Panel
	banner.BackgroundTransparency = 0.15
	banner.BorderSizePixel = 0
	banner.Parent = screen
	local bannerCorner = Instance.new("UICorner")
	bannerCorner.CornerRadius = UDim.new(0, Theme.Radius)
	bannerCorner.Parent = banner
	local bannerStroke = Instance.new("UIStroke")
	bannerStroke.Color = Theme.Colors.Gold
	bannerStroke.Thickness = Theme.StrokeThickness
	bannerStroke.Parent = banner

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0, 0.08)
	title.Size = UDim2.fromScale(1, 0.5)
	title.Font = Enum.Font.FredokaOne
	title.Text = "HQ PLAZA"
	title.TextColor3 = Theme.Colors.Gold
	title.TextScaled = true
	title.TextStrokeTransparency = 0.4
	title.Parent = banner
	bannerLabel = title

	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromScale(0, 0.56)
	sub.Size = UDim2.fromScale(1, 0.36)
	sub.Font = Enum.Font.GothamBold
	sub.Text = ""
	sub.TextColor3 = Theme.Colors.TextDim
	sub.TextScaled = true
	sub.Parent = banner
	local subLimit = Instance.new("UITextSizeConstraint")
	subLimit.MaxTextSize = 17
	subLimit.Parent = sub
	bannerSub = sub

	-- Bottom-centre objective, the tutorial banner from the screenshots.
	local objective = Instance.new("Frame")
	objective.Name = "Objective"
	objective.AnchorPoint = Vector2.new(0.5, 1)
	objective.Position = UDim2.new(0.5, 0, 1, -22)
	objective.Size = UDim2.fromOffset(430, 54)
	objective.BackgroundColor3 = Color3.fromRGB(56, 132, 220)
	objective.BorderSizePixel = 0
	objective.Parent = screen
	local objectiveCorner = Instance.new("UICorner")
	objectiveCorner.CornerRadius = UDim.new(0, Theme.Radius)
	objectiveCorner.Parent = objective
	local objectiveStroke = Instance.new("UIStroke")
	objectiveStroke.Color = Color3.fromRGB(22, 44, 88)
	objectiveStroke.Thickness = Theme.StrokeThickness
	objectiveStroke.Parent = objective
	local objectiveGradient = Instance.new("UIGradient")
	objectiveGradient.Color = ColorSequence.new(Color3.fromRGB(88, 168, 246), Color3.fromRGB(40, 106, 196))
	objectiveGradient.Rotation = 90
	objectiveGradient.Parent = objective

	local objectiveText_ = Instance.new("TextLabel")
	objectiveText_.BackgroundTransparency = 1
	objectiveText_.Size = UDim2.fromScale(1, 1)
	objectiveText_.Font = Enum.Font.FredokaOne
	objectiveText_.Text = ""
	objectiveText_.TextColor3 = Theme.Colors.Text
	objectiveText_.TextScaled = true
	objectiveText_.TextStrokeTransparency = 0.35
	objectiveText_.Parent = objective
	local objectiveLimit = Instance.new("UITextSizeConstraint")
	objectiveLimit.MaxTextSize = 24
	objectiveLimit.Parent = objectiveText_
	objectiveLabel = objectiveText_

	Theme.autoScale(stack, trove)
	Theme.autoScale(banner, trove)
	Theme.autoScale(objective, trove)
end

function Hud:Start()
	-- Side buttons open the panels. Required late so the panels have loaded.
	local uiFolder = script.Parent
	local ShopUi = require(uiFolder:WaitForChild("ShopUi"))
	local InternUi = require(uiFolder:WaitForChild("InternUi"))
	local RestructureUi = require(uiFolder:WaitForChild("RestructureUi"))

	local screen = gui
	if not screen then
		return
	end

	local buttons = Instance.new("Frame")
	buttons.Name = "SideButtons"
	buttons.BackgroundTransparency = 1
	buttons.AnchorPoint = Vector2.new(0, 0.5)
	buttons.Position = UDim2.new(0, 16, 0.5, 0)
	buttons.Size = UDim2.fromOffset(74, 320)
	buttons.Parent = screen

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = buttons

	type SideButton = { Icon: string, Open: () -> () }
	local entries: { SideButton } = {
		{ Icon = "Briefcase", Open = function() ShopUi.toggle() end },
		{ Icon = "Coffee", Open = function() InternUi.toggle() end },
		{ Icon = "Chart", Open = function() RestructureUi.toggle() end },
	}
	for index, entry in entries do
		local button = Theme.button({
			Text = "",
			Variant = "primary",
			Size = UDim2.fromOffset(70, 70),
			Parent = buttons,
			LayoutOrder = index,
			OnClick = entry.Open,
		})
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.fromScale(0.5, 0.5)
		holder.Size = UDim2.fromScale(0.56, 0.56)
		holder.Parent = button
		Icons.create(holder, entry.Icon, Theme.Colors.TextOnGold, Theme.Colors.Panel)
	end
	Theme.autoScale(buttons, trove)

	-- Stage progress arrives on the same remote the enemies use.
	trove:Connect(stageStateRemote.OnClientEvent, function(payload: any)
		if type(payload) ~= "table" then
			return
		end
		if payload.Progress then
			table.clear(stageProgress)
			for _, row in payload.Progress do
				stageProgress[row.Stage] = { Kills = row.Kills, Needed = row.Needed }
			end
		end
		if payload.Cleared then
			table.clear(clearedStages)
			for _, stageNumber in payload.Cleared do
				clearedStages[stageNumber] = true
			end
		end
	end)

	-- One refresh loop drives every readout: counters roll toward their real
	-- value, and the banner/objective follow whichever stage you are stood in.
	trove:Add(RunService.RenderStepped:Connect(function(dt: number)
		local state = StateController.Get()
		if not state then
			return
		end
		shownPower += (state.Productivity - shownPower) * math.min(1, dt * 6)
		if math.abs(state.Productivity - shownPower) < 0.5 then
			shownPower = state.Productivity
		end
		if powerLabel then
			powerLabel.Text = Format.abbreviate(shownPower)
		end
		if winsLabel then
			winsLabel.Text = Format.abbreviate(state.Wins)
		end
		if petsLabel then
			petsLabel.Text = ("%d/%d"):format(#state.EquippedInterns, state.InternSlots)
		end
		if perClickLabel then
			perClickLabel.Text = ("+%s per click  ·  +%s/sec"):format(
				Format.abbreviate(state.ClickIncome),
				Format.abbreviate(state.IdlePerSecond)
			)
		end
		if objectiveLabel then
			objectiveLabel.Text = objectiveText(state)
		end
		local title, sub = bannerText()
		if bannerLabel then
			bannerLabel.Text = title
		end
		if bannerSub then
			bannerSub.Text = sub
		end
	end))
end

return Hud
