-- The girl roller (after the map vote), owner's design: a small kit window at the top of the screen with a reel
-- that runs from top to bottom like a slot machine. Each row shows the girl's real model (a live picture of her
-- copy in ReplicatedStorage.HuzzGirls), her name, her rarity and that rarity's real chance. It slows down and
-- stops with this game's girl in the gold middle slot, which then lights up in her rarity colour.
-- Every row is a fair draw (the server builds the reel with Shared/GirlRoll). Shown while the Round remote's
-- RollData attribute holds a roll (JSON, so players who join mid-roll see it too); it isn't a menu, so the game
-- carries on behind it, and it closes when the roll is over.
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

local W, H, HEADER = 320, 254, 40
local REEL = { X = 10, Y = HEADER + 10, W = 300, H = 192 } -- three rows show; the middle one is the pick
local ROW = { H = 58, Gap = 6 }
local PITCH = ROW.H + ROW.Gap
local MID_Y = REEL.H / 2 - ROW.H / 2 -- top of the middle slot, in reel coordinates
local GOLD = C.Progress
local SCREEN_TOP = 6
local LOAD_ROWS = 2.6 -- rows this far from the middle get their model; further ones drop it

local rarityColor = {}
for _, r in Config.Rarities do
	rarityColor[r.Name] = r.Color
end
local function colorOf(rarity: string): Color3
	local c = rarityColor[rarity] or Color3.new(1, 1, 1)
	return if (c.R + c.G + c.B) < 0.4 then Color3.new(1, 1, 1) else c -- Secret (near-black) shows as white
end

local function chanceText(chance: number?): string
	if not chance then return "" end
	return if chance >= 10 then string.format("%d%%", math.floor(chance + 0.5))
		elseif chance >= 1 then string.format("%.1f%%", chance) else string.format("%.2f%%", chance)
end

local function label(props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	for k, v in props do (l :: any)[k] = v end
	return l
end

-- Her portrait: head and shoulders, from the front.
local function frame(viewport: ViewportFrame, model: Model)
	local head = model:FindFirstChild("Head", true) :: BasePart?
	local cam = viewport.CurrentCamera or Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = viewport
	viewport.CurrentCamera = cam
	if head then
		local at = head.Position - Vector3.new(0, 0.45, 0)
		local look = head.CFrame.LookVector
		cam.CFrame = CFrame.lookAt(at + look * 6.2 + Vector3.new(0, 0.5, 0), at)
	else
		local cf, size = model:GetBoundingBox()
		cam.CFrame = CFrame.lookAt(cf.Position + cf.LookVector * size.Magnitude * 1.6, cf.Position)
	end
end

local function row(parent: Instance, i: number, girl: { name: string, rarity: string, key: string? }, chance: number?)
	local color = colorOf(girl.rarity)
	local secret = girl.rarity == "Secret"
	local f = Instance.new("Frame")
	f.Name = "Row" .. i
	-- Anchored at its centre so the pop grows evenly, and inset so its rim isn't clipped by the reel.
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(REEL.W / 2, MID_Y + ROW.H / 2 - (i - 1) * PITCH)
	f.Size = UDim2.fromOffset(REEL.W - 12, ROW.H)
	f.BackgroundColor3 = if secret then Color3.fromRGB(14, 14, 20) else C.Row
	f.BorderSizePixel = 0
	f:SetAttribute("RuntimeOnly", true)
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
	local rim = Instance.new("UIStroke")
	rim.Name = "Rim"
	rim.Color = C.RowBorder:Lerp(color, 0.3)
	rim.Thickness = 1.5
	rim.Parent = f
	-- Her rarity colour washes in from the left behind her picture.
	local wash = Instance.new("Frame")
	wash.Name = "Wash"
	wash.Size = UDim2.fromScale(1, 1)
	wash.BackgroundColor3 = color
	wash.BorderSizePixel = 0
	wash.Parent = f
	Instance.new("UICorner", wash).CornerRadius = UDim.new(0, 6)
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if secret then 0.55 else 0.45), NumberSequenceKeypoint.new(0.4, 0.9), NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = wash
	local pic = Instance.new("ViewportFrame")
	pic.Name = "Picture"
	pic.Position = UDim2.fromOffset(5, 4)
	pic.Size = UDim2.fromOffset(ROW.H - 8, ROW.H - 8)
	pic.BackgroundColor3 = C.IconCell
	pic.BackgroundTransparency = 0.2
	pic.Ambient = Color3.fromRGB(190, 190, 205)
	pic.LightColor = Color3.fromRGB(255, 250, 240)
	pic.LightDirection = Vector3.new(-0.4, -1, -0.8)
	pic.Parent = f
	Instance.new("UICorner", pic).CornerRadius = UDim.new(0, 5)
	local x = ROW.H + 4
	label({
		Name = "GirlName", Position = UDim2.fromOffset(x, 6), Size = UDim2.new(1, -x - 8, 0, 22), FontFace = Theme.Fonts.Name,
		Text = girl.name, TextColor3 = C.Text, TextSize = 17, TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = f,
	})
	-- The rarity in a coloured pill, then its chance.
	local rarityText = string.upper(girl.rarity)
	local pillW = math.ceil(#rarityText * 7.6) + 14
	local pill = Instance.new("Frame")
	pill.Name = "RarityPill"
	pill.Position = UDim2.fromOffset(x, 32)
	pill.Size = UDim2.fromOffset(pillW, 19)
	pill.BackgroundColor3 = if secret then Color3.fromRGB(10, 10, 14) else color
	pill.BorderSizePixel = 0
	pill.Parent = f
	Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 5)
	if secret then
		local s = Instance.new("UIStroke")
		s.Color, s.Thickness = Color3.new(1, 1, 1), 1
		s.Parent = pill
	end
	local dark = (color.R * 0.3 + color.G * 0.59 + color.B * 0.11) > 0.62
	label({
		Name = "Rarity", Size = UDim2.fromScale(1, 1), FontFace = Theme.Fonts.Tab, Text = rarityText, TextSize = 13,
		TextColor3 = if dark and not secret then C.DarkText else Color3.new(1, 1, 1), Parent = pill,
	})
	label({
		Name = "Chance", Position = UDim2.fromOffset(x + pillW + 6, 32), Size = UDim2.fromOffset(60, 19), FontFace = Theme.Fonts.Label,
		Text = chanceText(chance), TextSize = 13, TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Left, Parent = f,
	})
	Instance.new("UIScale", f).Name = "Pop"
	f.Parent = parent
	return { frame = f, picture = pic, key = girl.key, loaded = false }
end

function GirlRoll.build(parent: Instance)
	local window = Kit.window({
		Name = "GirlRoll", Title = "TODAY'S GIRL", Icon = "TierCrown", Width = W, Height = H, HeaderHeight = HEADER,
		TitleSize = 19, TitleX = 46, TitleWidth = 146, StudsTo = W - 50, CloseSize = Vector2.new(26, 26),
		Flat = true, -- the portraits are ViewportFrames: keep them out of a CanvasGroup
		Parent = parent, OnClose = function() GirlRoll.hide() end,
	})
	local holder, group = window.Holder, window.Group
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, SCREEN_TOP)
	Scale.bind(holder:FindFirstChild("FitScale") :: UIScale, function() return Scale.window(W, H) * 0.62 end) -- small, as asked

	local panel = window.Body.Parent :: Instance
	local reel = new("Frame", {
		Name = "Reel", Position = UDim2.fromOffset(REEL.X, REEL.Y), Size = UDim2.fromOffset(REEL.W, REEL.H),
		BackgroundColor3 = C.Groove, BorderSizePixel = 0, ClipsDescendants = true, Parent = panel,
	})
	local track = new("Frame", { Name = "Track", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = reel })
	-- The reel fades out at the top and bottom, so rows slide in and out of view.
	for side, y in { Top = 0, Bottom = 1 } do
		local edge = new("Frame", {
			Name = "Fade" .. side, AnchorPoint = Vector2.new(0, y), Position = UDim2.fromScale(0, y), Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = C.Groove, BorderSizePixel = 0, ZIndex = 3, Parent = reel,
		})
		new("UIGradient", {
			Name = "Fade", Rotation = 90, Transparency = NumberSequence.new(if y == 0 then 0 else 1, if y == 0 then 1 else 0), Parent = edge,
		})
	end
	-- The gold middle slot: a rim round the middle row and a pointer on each side.
	local slotY = REEL.Y + MID_Y
	local slot = new("Frame", {
		Name = "Slot", Position = UDim2.fromOffset(REEL.X + 3, slotY - 3), Size = UDim2.fromOffset(REEL.W - 6, ROW.H + 6),
		BackgroundTransparency = 1, ZIndex = 5, Parent = panel,
	}, { Kit.corner(8) })
	local slotRim = Kit.attach(Kit.stroke(GOLD, 2.5), slot) :: UIStroke
	for name, x in { PointerLeft = REEL.X + 3, PointerRight = REEL.X + REEL.W - 3 } do
		local tri = new("Frame", {
			Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, slotY + ROW.H / 2), Size = UDim2.fromOffset(12, 12),
			Rotation = 45, BackgroundColor3 = GOLD, BorderSizePixel = 0, ZIndex = 6, Parent = panel,
		})
		Kit.attach(Kit.stroke(C.SelectedRim, 1.5), tri)
	end

	local current = nil
	local landed = false
	local rows = {}
	local girls = ReplicatedStorage:FindFirstChild("HuzzGirls")

	local function clear()
		for _, c in track:GetChildren() do
			if c:GetAttribute("RuntimeOnly") then c:Destroy() end
		end
		rows = {}
	end

	-- Her model goes into the row's picture only while the row is near the window.
	local function setLoaded(r, on: boolean)
		if r.loaded == on then return end
		if on then
			girls = girls or ReplicatedStorage:FindFirstChild("HuzzGirls")
			local source = girls and r.key and girls:FindFirstChild(r.key)
			if source then -- (not there yet = try again next frame)
				r.loaded = true
				local copy = source:Clone()
				copy.Parent = r.picture
				frame(r.picture, copy)
			end
		else
			r.loaded = false
			for _, c in r.picture:GetChildren() do
				if c:IsA("Model") then c:Destroy() end
			end
		end
	end

	-- How far the reel has run at server time t (in px): the row after the first in the slot at the start,
	-- the winner at the end, slowing down like a real reel (ease-out), with a tiny overshoot settle.
	local function offsetAt(roll, t)
		local p = math.clamp((t - roll.start) / roll.spin, 0, 1)
		local e = 1 - (1 - p) ^ 4
		local from, to = 2 * PITCH, (roll.stop - 1) * PITCH
		return from + (to - from) * e, p
	end

	function GirlRoll.render(t: number)
		local roll = current
		if not roll then return end
		local y, p = offsetAt(roll, t)
		track.Position = UDim2.fromOffset(0, math.floor(y + 0.5))
		for i, r in rows do
			local rowsAway = math.abs((i - 1) * PITCH - y) / PITCH
			setLoaded(r, rowsAway <= LOAD_ROWS)
			local pop = r.frame:FindFirstChild("Pop") :: UIScale
			if pop and not (landed and i == roll.stop) then
				pop.Scale = 1 + 0.04 * math.max(0, 1 - rowsAway)
			end
		end
		if p >= 1 and not landed then
			landed = true
			local win = rows[roll.stop]
			local color = colorOf(roll.cells[roll.stop].rarity)
			slotRim.Color = color
			if win then
				local rim = win.frame:FindFirstChild("Rim") :: UIStroke
				rim.Color, rim.Thickness = color, 2.5
				local pop = win.frame:FindFirstChild("Pop") :: UIScale
				pop.Scale = 1.1
				TweenService:Create(pop, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.03 }):Play()
			end
		end
	end

	function GirlRoll.show(roll)
		current, landed = roll, false
		clear()
		slotRim.Color = GOLD
		local chances = {}
		for _, o in roll.odds or {} do chances[o.name] = o.chance end
		for i, girl in roll.cells do
			rows[i] = row(track, i, girl, chances[girl.rarity])
		end
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
		local ok, roll = pcall(function()
			return if type(raw) == "string" and raw ~= "" then HttpService:JSONDecode(raw) else nil
		end)
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
	RunService.RenderStepped:Connect(function()
		if current then GirlRoll.render(Workspace:GetServerTimeNow()) end
	end)
	holder.Visible = false
	task.defer(onRoll)
	return window
end

return GirlRoll
