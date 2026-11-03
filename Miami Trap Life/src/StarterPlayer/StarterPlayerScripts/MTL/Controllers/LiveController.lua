--!strict
-- Live events on the HUD (Quality pass, Benchmark Gap List 2.7, 2.8, 2.10). Server side: AirdropService,
-- DailyCacheService, PawnService (all talk through Net LiveState).
--   chips (top right, under the level ring):
--     🍀 2x JOB PAY 14:32       while Bea's luck is on (player attribute MTL_JobBoostUntil, unix time)
--     📦 SUPPLY DROP 0:42       a drop is coming (then "LANDED", until someone opens it)
--   the pawn card: what Liberty Pawn & Thrift pays for each thing you carry, one SELL button per row. Closes
--   when you walk off, press Esc / B, or tap CLOSE.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.MTL.Net)
local Theme = require(ReplicatedStorage.MTL.UI.Theme)
local Live = require(ReplicatedStorage.MTL.Config.Live)
local UIState = require(script.Parent.UIState)

local LiveController = {}

local player = Players.LocalPlayer
local C = Theme.Colors
local F = Theme.Fonts

local gui: ScreenGui
local chips: Frame
local boostChip: Frame
local dropChip: Frame
local card: CanvasGroup? = nil
local drop: { phase: string, endsAt: number, label: string }? = nil

local function corner(p: Instance, r: UDim?)
	local c = Instance.new("UICorner")
	c.CornerRadius = r or UDim.new(1, 0)
	c.Parent = p
end

local function stroke(p: Instance, t: number?)
	local s = Instance.new("UIStroke")
	s.Color = C.Stroke
	s.Transparency = t or C.StrokeTransparency
	s.Thickness = 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
end

local function label(parent: Instance, name: string, text: string, font: Font, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Text = text
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = color
	l.AutomaticSize = Enum.AutomaticSize.XY
	l.Parent = parent
	return l
end

local function chip(name: string, icon: string, accent: Color3, order: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = C.Glass
	f.BackgroundTransparency = C.GlassTransparency
	f.AutomaticSize = Enum.AutomaticSize.X
	f.Size = UDim2.fromOffset(0, 30)
	f.LayoutOrder = order
	f.Visible = false
	corner(f)
	stroke(f)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = f
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 6)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = f
	local i = label(f, "Icon", icon, F.Body, 16, C.Text)
	i.LayoutOrder = 1
	local t = label(f, "Title", "", F.Display, 13, accent)
	t.LayoutOrder = 2
	local v = label(f, "Value", "", F.Mono, 13, C.Text)
	v.LayoutOrder = 3
	f.Parent = chips
	return f
end

local function fmt(sec: number): string
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

local function pop(f: GuiObject)
	local s = f:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	s.Parent = f
	s.Scale = 0.6
	TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

---------------------------------------------------------------- pawn card
local function closeCard()
	if card then
		local c = card
		card = nil
		UIState.pop("Pawn")
		TweenService:Create(c, TweenInfo.new(0.15), { GroupTransparency = 1 }):Play()
		task.delay(0.16, function()
			c:Destroy()
		end)
	end
end

local function openCard(msg: any)
	local fresh = card == nil
	if card then
		card:Destroy()
	else
		UIState.push("Pawn", { hidePhone = true })
	end
	local g = Instance.new("CanvasGroup")
	g.Name = "PawnCard"
	g.AnchorPoint = Vector2.new(0.5, 0.5)
	g.Position = UDim2.fromScale(0.5, 0.52)
	g.Size = UDim2.fromOffset(380, 0)
	g.AutomaticSize = Enum.AutomaticSize.Y
	g.BackgroundColor3 = C.Glass
	g.BackgroundTransparency = 0.06
	g.GroupTransparency = if fresh then 1 else 0
	corner(g, Theme.Corner)
	stroke(g, 0.8)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 16)
	pad.PaddingBottom = UDim.new(0, 16)
	pad.PaddingLeft = UDim.new(0, 18)
	pad.PaddingRight = UDim.new(0, 18)
	pad.Parent = g
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = g
	local head = label(g, "Head", "🏷️  " .. string.upper(msg.title or "Pawn"), F.Display, 18, C.Gold)
	head.LayoutOrder = 1
	local sub = label(g, "Sub", "Clean cash, no questions. We pay less than the back door.", F.Body, 13, C.TextDim)
	sub.LayoutOrder = 2
	sub.TextWrapped = true
	sub.AutomaticSize = Enum.AutomaticSize.Y
	sub.Size = UDim2.new(1, 0, 0, 0)
	sub.TextXAlignment = Enum.TextXAlignment.Left
	local any = false
	for i, r in msg.rows or {} do
		local row = Instance.new("Frame")
		row.Name = "Row_" .. tostring(r.id)
		row.LayoutOrder = 10 + i
		row.Size = UDim2.new(1, 0, 0, 58)
		row.BackgroundColor3 = Theme.Phone.Card
		row.BackgroundTransparency = 0.1
		corner(row, Theme.CornerSmall)
		local t = label(row, "Title", r.title, F.Bold, 15, C.Text)
		t.Position = UDim2.fromOffset(12, 8)
		local b = label(row, "Blurb", if r.other then r.other else r.blurb, F.Body, 12, C.TextDim)
		b.Position = UDim2.fromOffset(12, 30)
		local btn = Instance.new("TextButton")
		btn.Name = "Sell"
		btn.AnchorPoint = Vector2.new(1, 0.5)
		btn.Position = UDim2.new(1, -10, 0.5, 0)
		btn.Size = UDim2.fromOffset(110, 36)
		btn.AutoButtonColor = true
		btn.FontFace = F.Display
		btn.TextSize = 14
		corner(btn, Theme.CornerSmall)
		if r.pays > 0 then
			any = true
			btn.Text = "SELL $" .. r.pays
			btn.BackgroundColor3 = C.Accent
			btn.TextColor3 = Color3.fromRGB(10, 30, 22)
			btn.Activated:Connect(function()
				btn.Active = false
				btn.Text = "..."
				Net.get("PawnAction"):FireServer({ type = "sell", id = r.id })
			end)
		else
			btn.Text = "NONE"
			btn.BackgroundColor3 = Theme.Phone.CardHover
			btn.TextColor3 = C.TextDim
			btn.Active = false
			btn.AutoButtonColor = false
		end
		btn.Parent = row
		row.Parent = g
	end
	if not any then
		local e = label(g, "Empty", "Nothing to sell yet. Goods from house licks sell here.", F.Body, 13, C.TextDim)
		e.LayoutOrder = 50
	end
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.LayoutOrder = 99
	close.Size = UDim2.new(1, 0, 0, 34)
	close.Text = "CLOSE"
	close.FontFace = F.Bold
	close.TextSize = 13
	close.TextColor3 = C.Text
	close.BackgroundColor3 = Theme.Phone.CardHover
	corner(close, Theme.CornerSmall)
	close.Activated:Connect(closeCard)
	close.Parent = g
	g.Parent = gui
	card = g
	if fresh then
		TweenService:Create(g, TweenInfo.new(0.18), { GroupTransparency = 0 }):Play()
		pop(g)
	end
end

---------------------------------------------------------------- events
local function onLive(msg: any)
	if type(msg) ~= "table" then
		return
	end
	if msg.type == "airdrop" then
		if msg.phase == "incoming" then
			drop = { phase = "incoming", endsAt = os.clock() + (msg.seconds or 60), label = msg.label or "" }
			dropChip.Visible = true
			pop(dropChip)
		elseif msg.phase == "landed" then
			drop = { phase = "landed", endsAt = 0, label = msg.label or (drop and drop.label) or "" }
			dropChip.Visible = true
		elseif msg.phase == "opened" or msg.phase == "gone" then
			drop = nil
			dropChip.Visible = false
		end
	elseif msg.type == "pawn" then
		openCard(msg)
	end
end

function LiveController.init()
	local pg = player:WaitForChild("PlayerGui")
	gui = Instance.new("ScreenGui")
	gui.Name = "MTL_Live"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Parent = pg
	chips = Instance.new("Frame")
	chips.Name = "Chips"
	chips.AnchorPoint = Vector2.new(1, 0)
	chips.Position = UDim2.new(1, -16, 0, 176)
	chips.Size = UDim2.fromOffset(300, 80)
	chips.BackgroundTransparency = 1
	local v = Instance.new("UIListLayout")
	v.HorizontalAlignment = Enum.HorizontalAlignment.Right
	v.Padding = UDim.new(0, 6)
	v.SortOrder = Enum.SortOrder.LayoutOrder
	v.Parent = chips
	chips.Parent = gui
	boostChip = chip("Boost", "🍀", Color3.fromRGB(150, 230, 140), 1)
	dropChip = chip("Drop", "📦", Color3.fromRGB(255, 140, 110), 2)
	;(boostChip :: any).Title.Text = "2x JOB PAY"
	;(dropChip :: any).Title.Text = "SUPPLY DROP"

	Net.get("LiveState").OnClientEvent:Connect(onLive)
	player:GetAttributeChangedSignal("MTL_JobBoostUntil"):Connect(function()
		if player:GetAttribute("MTL_JobBoostUntil") then
			boostChip.Visible = true
			pop(boostChip)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if card and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
			closeCard()
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		local hidden = UIState.get().hideHUD == true
		chips.Visible = not hidden
		-- boost
		local untilT = player:GetAttribute("MTL_JobBoostUntil")
		local left = if type(untilT) == "number" then untilT - workspace:GetServerTimeNow() else 0
		boostChip.Visible = left > 0
		if left > 0 then
			local boostChipValue: TextLabel = (boostChip :: any).Value
			boostChipValue.Text = fmt(left)
		end
		-- drop
		if drop then
			if drop.phase == "incoming" then
				local s = drop.endsAt - os.clock()
				local dropChipValue: TextLabel = (dropChip :: any).Value
				dropChipValue.Text = if s > 0 then fmt(s) else "LANDING"
			else
				local dropChipValue: TextLabel = (dropChip :: any).Value
				dropChipValue.Text = "LANDED"
			end
		end
		-- the pawn card closes when you walk away from the counter
		if card then
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not hrp or (hrp.Position - Live.Pawn.at).Magnitude > 18 then
				closeCard()
			end
		end
	end)
end

return LiveController
