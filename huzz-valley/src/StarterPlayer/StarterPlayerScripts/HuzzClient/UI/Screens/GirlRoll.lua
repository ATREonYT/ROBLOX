-- The girl roller (after the map vote): a strip of girl names in a kit window at the top of the screen. It spins
-- fast, slows down and stops on this game's girl, then her card lights up in her rarity colour. Every name on the
-- strip is a real, fairly drawn girl (the server builds the strip with Shared/GirlRoll), and the bottom row shows
-- each rarity's real chance. Shown while the Round remote's RollData attribute holds a roll (JSON, so players who
-- join mid-roll see it too); it's not a menu, so the game carries on behind it and it closes when the roll is over.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Config = require(Shared.Config.Round)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Scale = require(UI.Scale)

local C = Theme.Colors
local new = Kit.new

local GirlRoll = {}

local W, H = 701, 200
local WELL = { X = 14, Y = 57, W = 673, H = 96 } -- the dark strip the names pass through (window coords)
local CELL = { W = 118, H = 78, Gap = 8 }
local PITCH = CELL.W + CELL.Gap
local ODDS_Y = 172
local GOLD = C.Progress
local SCREEN_TOP = 6

local rarityColor = {}
for _, r in Config.Rarities do
	rarityColor[r.Name] = r.Color
end
local function colorOf(rarity: string): Color3
	local c = rarityColor[rarity] or Color3.new(1, 1, 1)
	-- Secret is near-black: on the navy cards it reads as a white rim on black.
	return if (c.R + c.G + c.B) < 0.4 then Color3.new(1, 1, 1) else c
end

local function cell(parent: Instance, i: number, girl: { name: string, rarity: string }): Frame
	local color = colorOf(girl.rarity)
	local secret = girl.rarity == "Secret"
	local f = Instance.new("Frame")
	f.Name = "Cell" .. i
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset((i - 1) * PITCH + CELL.W / 2, WELL.H / 2)
	f.Size = UDim2.fromOffset(CELL.W, CELL.H)
	f.BackgroundColor3 = if secret then Color3.fromRGB(14, 14, 20) else C.Row
	f.BorderSizePixel = 0
	f:SetAttribute("RuntimeOnly", true)
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
	local rim = Instance.new("UIStroke")
	rim.Name = "Rim"
	rim.Color = C.RowBorder:Lerp(color, 0.35)
	rim.Thickness = 1.5
	rim.Parent = f
	Instance.new("UIScale", f).Name = "Pop"
	-- A glow of her rarity colour rising from the bottom, and a solid band along it.
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.Size = UDim2.fromScale(1, 1)
	glow.BackgroundColor3 = color
	glow.BorderSizePixel = 0
	glow.Parent = f
	Instance.new("UICorner", glow).CornerRadius = UDim.new(0, 6)
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 0.88), NumberSequenceKeypoint.new(1, if secret then 0.7 else 0.5),
	})
	fade.Parent = glow
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.AnchorPoint = Vector2.new(0.5, 1)
	band.Position = UDim2.new(0.5, 0, 1, -4)
	band.Size = UDim2.new(1, -16, 0, 4)
	band.BackgroundColor3 = color
	band.BorderSizePixel = 0
	band.Parent = f
	Instance.new("UICorner", band).CornerRadius = UDim.new(0, 2)
	local name = Instance.new("TextLabel")
	name.Name = "GirlName"
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(6, 8)
	name.Size = UDim2.new(1, -12, 0, 38)
	name.FontFace = Theme.Fonts.Name
	name.Text = girl.name
	name.TextColor3 = C.Text
	name.TextScaled = true
	name.TextWrapped = true
	name.Parent = f
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = 19
	cap.Parent = name
	local rarity = Instance.new("TextLabel")
	rarity.Name = "Rarity"
	rarity.BackgroundTransparency = 1
	rarity.Position = UDim2.fromOffset(6, 48)
	rarity.Size = UDim2.new(1, -12, 0, 16)
	rarity.FontFace = Theme.Fonts.Tab
	rarity.Text = string.upper(girl.rarity)
	rarity.TextColor3 = color
	rarity.TextSize = 14
	rarity.Parent = f
	local rarityStroke = Instance.new("UIStroke")
	rarityStroke.Color, rarityStroke.Thickness = C.TextShadow, 1
	rarityStroke.Parent = rarity
	f.Parent = parent
	return f
end

function GirlRoll.build(parent: Instance)
	local window = Kit.window({
		Name = "GirlRoll", Title = "TODAY'S GIRL", Icon = "TierCrown", Width = W, Height = H, TitleSize = 24, TitleX = 63,
		TitleWidth = 182, StudsTo = W - 236, Parent = parent, OnClose = function() GirlRoll.hide() end,
	})
	local holder, group = window.Holder, window.Group
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, SCREEN_TOP)
	local fit = holder:FindFirstChild("FitScale") :: UIScale
	Scale.bind(fit, function() return Scale.window(W, H) * 0.78 end) -- a banner, a bit smaller than a menu window

	-- "ROLLING..." then the winner's rarity, in a navy pill in the header (like the vote's timer).
	local pill = new("Frame", {
		Name = "Status", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -46, 0.5, 0), Size = UDim2.fromOffset(170, 30),
		BackgroundColor3 = C.Pill, BorderSizePixel = 0, Parent = window.Header,
	}, { Kit.corner(6) })
	Kit.attach(Kit.stroke(C.PillRim, 1.5), pill)
	local status = Kit.text({
		Name = "Text", Text = "ROLLING...", FontFace = Theme.Fonts.Button, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1), Parent = pill,
	})

	-- The well: a dark groove the cards slide through, faded at both ends, with a gold pointer in the middle.
	local panel = window.Body.Parent :: Instance
	local well = new("Frame", {
		Name = "Well", Position = UDim2.fromOffset(WELL.X, WELL.Y), Size = UDim2.fromOffset(WELL.W, WELL.H),
		BackgroundColor3 = C.Groove, BorderSizePixel = 0, ClipsDescendants = true, Parent = panel,
	})
	Kit.attach(Kit.stroke(C.RowBorder, 1.5), well)
	local track = new("Frame", { Name = "Track", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = well })
	for side, x in { Left = 0, Right = 1 } do
		local edge = new("Frame", {
			Name = "Fade" .. side, AnchorPoint = Vector2.new(x, 0), Position = UDim2.fromScale(x, 0), Size = UDim2.new(0, 70, 1, 0),
			BackgroundColor3 = C.Groove, BorderSizePixel = 0, ZIndex = 3, Parent = well,
		})
		new("UIGradient", {
			Name = "Fade",
			Transparency = NumberSequence.new(if x == 0 then 0 else 1, if x == 0 then 1 else 0),
			Parent = edge,
		})
	end
	local mid = WELL.X + WELL.W / 2
	for name, y in { PointerTop = WELL.Y, PointerBottom = WELL.Y + WELL.H } do
		local tri = new("Frame", {
			Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(mid, y), Size = UDim2.fromOffset(17, 17),
			Rotation = 45, BackgroundColor3 = GOLD, BorderSizePixel = 0, ZIndex = 5, Parent = panel,
		})
		Kit.attach(Kit.stroke(C.SelectedRim, 1.5), tri)
	end

	-- Each rarity's real chance, centred along the bottom.
	local odds = new("Frame", {
		Name = "Odds", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(W / 2, ODDS_Y), Size = UDim2.fromOffset(W - 40, 22),
		BackgroundTransparency = 1, Parent = panel,
	}, { Kit.list(Enum.FillDirection.Horizontal, 11, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })

	local current = nil -- the roll being shown
	local landed = false
	local cells = {}

	local function clear()
		for _, c in track:GetChildren() do
			if c:GetAttribute("RuntimeOnly") then c:Destroy() end
		end
		for _, c in odds:GetChildren() do
			if c:GetAttribute("RuntimeOnly") then c:Destroy() end
		end
		cells = {}
	end

	-- Where the strip is at server time t: cell 3 under the pointer at the start, the winner at the end,
	-- slowing down like a real spinner (ease-out). The stop lands a little off-centre, the same on every screen.
	local function offsetAt(roll, t)
		local p = math.clamp((t - roll.start) / roll.spin, 0, 1)
		local e = 1 - (1 - p) ^ 4
		local nudge = ((roll.start * 7.31) % 1 - 0.5) * CELL.W * 0.5
		local from, to = 2 * PITCH, (roll.stop - 1) * PITCH + nudge
		return from + (to - from) * e, p
	end

	function GirlRoll.render(t: number)
		local roll = current
		if not roll then return end
		local x, p = offsetAt(roll, t)
		track.Position = UDim2.fromOffset(math.floor(WELL.W / 2 - CELL.W / 2 - x + 0.5), 0)
		-- The card under the pointer swells a little as it passes.
		for i, f in cells do
			local d = math.abs((i - 1) * PITCH - x) / PITCH
			local pop = f:FindFirstChild("Pop") :: UIScale
			if pop and not (landed and i == roll.stop) then
				pop.Scale = 1 + 0.06 * math.max(0, 1 - d)
			end
		end
		if p >= 1 and not landed then
			landed = true
			local win = cells[roll.stop]
			local girl = roll.cells[roll.stop]
			local color = colorOf(girl.rarity)
			status.Text = string.upper(girl.rarity) .. "!"
			if win then
				local rim = win:FindFirstChild("Rim") :: UIStroke
				rim.Color, rim.Thickness = color, 3
				win.ZIndex = 2
				local pop = win:FindFirstChild("Pop") :: UIScale
				pop.Scale = 1.16
				TweenService:Create(pop, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.1 }):Play()
			end
		end
	end

	function GirlRoll.show(roll)
		current, landed = roll, false
		clear()
		for i, girl in roll.cells do
			cells[i] = cell(track, i, girl)
		end
		for i, o in roll.odds or {} do
			local color = colorOf(o.name)
			local chance = if o.chance >= 10 then string.format("%d%%", math.floor(o.chance + 0.5))
				elseif o.chance >= 1 then string.format("%.1f%%", o.chance) else string.format("%.2f%%", o.chance)
			-- "COMMON 50%": the rarity in its colour, then its chance (two labels side by side).
			local item = Instance.new("Frame")
			item.Name = "Odds" .. i
			item.LayoutOrder = i
			item.BackgroundTransparency = 1
			-- Widths measured for these fonts at 13 px (the preview can't auto-size).
			local nameW, chanceW = math.ceil(#o.name * 7.8) + 2, math.ceil(#chance * 8) + 2
			item.Size = UDim2.fromOffset(nameW + 4 + chanceW, 20)
			item:SetAttribute("RuntimeOnly", true)
			local row = Instance.new("UIListLayout")
			row.FillDirection = Enum.FillDirection.Horizontal
			row.Padding = UDim.new(0, 4)
			row.VerticalAlignment = Enum.VerticalAlignment.Center
			row.SortOrder = Enum.SortOrder.LayoutOrder
			row.Parent = item
			for j, part in { { string.upper(o.name), color, Theme.Fonts.Tab }, { chance, C.SubText, Theme.Fonts.Label } } do
				local label = Instance.new("TextLabel")
				label.Name = if j == 1 then "Rarity" else "Chance"
				label.LayoutOrder = j
				label.BackgroundTransparency = 1
				label.Size = UDim2.fromOffset(if j == 1 then nameW else chanceW, 20)
				label.FontFace = part[3]
				label.TextSize = 13
				label.TextColor3 = part[2]
				label.Text = part[1]
				label.Parent = item
			end
			item.Parent = odds
		end
		status.Text = "ROLLING..."
		GirlRoll.render(Workspace:GetServerTimeNow())
		holder.Visible, group.Visible = true, true
		holder.Position = UDim2.new(0.5, 0, 0, -2 * H - 20)
		TweenService:Create(holder, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, SCREEN_TOP) }):Play()
	end

	function GirlRoll.hide()
		if not holder.Visible then return end
		current = nil
		local t = TweenService:Create(holder, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0, -2 * H - 20) })
		t.Completed:Connect(function()
			if current == nil then
				holder.Visible = false
				clear()
			end
		end)
		t:Play()
	end

	local round = Net.get("Round") :: RemoteEvent
	local function onRoll()
		local raw = round:GetAttribute("RollData")
		local ok, roll = pcall(HttpService.JSONDecode, HttpService, if type(raw) == "string" and raw ~= "" then raw else "null")
		if ok and type(roll) == "table" and roll.cells then
			GirlRoll.show(roll)
		else
			GirlRoll.hide()
		end
	end
	round:GetAttributeChangedSignal("RollData"):Connect(onRoll)
	round:GetAttributeChangedSignal("Stage"):Connect(function()
		local stage = round:GetAttribute("Stage")
		if stage ~= "Rolling" and stage ~= nil then GirlRoll.hide() end
	end)
	task.defer(onRoll)
	RunService.RenderStepped:Connect(function()
		if current then GirlRoll.render(Workspace:GetServerTimeNow()) end
	end)
	holder.Visible = false
	return window
end

return GirlRoll
