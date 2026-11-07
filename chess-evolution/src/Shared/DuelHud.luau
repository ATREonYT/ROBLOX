--!strict
-- +1 Chess Evolution: the 1v1 clicking-duel layer on top of the battle meter.
-- Both sides read at a glance: YOU (green, left) vs the rival (red, right), each with a portrait,
-- a name and a taps-per-second readout. The leader's card lifts and wears a gold LEAD tag.
-- Taps pop a combo counter ("x12 POPPING OFF!") and throw sparks off the clash point; the
-- rival "clicks" at the rate its pressure implies, so you can see them pushing back.
-- Danger (meter 25 or lower) breathes red screen edges, slower than once per second.
-- Reduced effects: no sparks, no shake, no breathing; every number and label stays.
--
-- Build (offline, saved in ChessHUD.rbxm):  DuelHud.Build(bottom, gui)
-- Runtime (client):
--   local duel = DuelHud.new(gui, { tween = tween, reduced = reduced, message = message })
--   duel:Start({ playerName, userId, rivalName, rivalTitle, rivalColor, rivalModel?, perTap })
--   duel:Tap()                                  -- every local press during the fight
--   duel:Update(dt, display, pressure, elapsed) -- every frame (display: 0-100, 100 = you win)
--   duel:Stop()
-- Pure presentation: it never decides the meter, the outcome or a badge.

local DuelHud = {}
DuelHud.__index = DuelHud

local INK = Color3.fromRGB(28, 26, 40)
local WHITE = Color3.new(1, 1, 1)
local GREEN = Color3.fromRGB(70, 210, 80)
local RED = Color3.fromRGB(240, 70, 70)
local GOLD = Color3.fromRGB(255, 196, 40)
local FONT = Font.fromEnum(Enum.Font.FredokaOne)

-- One place for the duel's feel numbers.
DuelHud.Tuning = {
	comboGap = 0.6, -- seconds without a tap before the combo ends
	comboShow = 3, -- combo appears from this many taps
	comboWords = { { 35, "UNSTOPPABLE!", Color3.fromRGB(255, 120, 230) }, { 20, "POPPING OFF!", Color3.fromRGB(255, 150, 50) }, { 10, "NICE!", Color3.fromRGB(255, 230, 90) } },
	rateWindow = 1.0, -- taps/s is measured over this many seconds
	rivalVisualCap = 8, -- at most this many rival "clicks" drawn per second
	dangerAt = 25, -- red screen edges at or below this meter value
	edgeBreath = 1.25, -- seconds per breathing cycle (kid-safe: under one flash per second)
	sparkPool = 14,
}

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function text(parent: Instance, name: string, props: { [string]: any }, strokeT: number?): TextLabel
	local t = new("TextLabel", { Name = name, BackgroundTransparency = 1, FontFace = FONT, TextColor3 = WHITE, TextSize = 22, Text = "" }, nil)
	for k, v in props do
		(t :: any)[k] = v
	end
	new("UIStroke", { Thickness = strokeT or 2.5, Color = INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Name = "Outline" }, t)
	t.Parent = parent
	return t
end

local function shade(parent: Instance)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, WHITE),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(235, 235, 235)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 190, 190)),
		}),
	}, parent)
end

-- A player card: portrait, name, sub line, taps/s, LEAD tag. side = "You" | "Rival".
local function card(parent: Instance, side: string, color: Color3): Frame
	local right = side == "Rival"
	local holder = new("Frame", {
		Name = side .. "Card",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(if right then 1 else 0, 0),
		Position = UDim2.fromScale(if right then 1 else 0, 0),
		Size = UDim2.new(0.5, -46, 1, 0),
	}, parent)
	new("UIScale", { Name = "Lift" }, holder)
	local shadow = new("Frame", { Name = "Shadow", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 4), ZIndex = 1 }, holder)
	new("UICorner", { CornerRadius = UDim.new(0, 14) }, shadow)
	local face = new("Frame", { Name = "Face", BackgroundColor3 = Color3.fromRGB(44, 46, 66), Size = UDim2.fromScale(1, 1), ZIndex = 2 }, holder)
	new("UICorner", { CornerRadius = UDim.new(0, 14) }, face)
	new("UIStroke", { Name = "Edge", Thickness = 3, Color = INK }, face)
	-- coloured side band behind the portrait
	local band = new("Frame", {
		Name = "Band",
		BackgroundColor3 = color,
		AnchorPoint = Vector2.new(if right then 1 else 0, 0),
		Position = UDim2.fromScale(if right then 1 else 0, 0),
		Size = UDim2.new(0, 64, 1, 0),
		ZIndex = 3,
	}, face)
	new("UICorner", { CornerRadius = UDim.new(0, 14) }, band)
	shade(band)
	local portrait = new("Frame", {
		Name = "Portrait",
		BackgroundColor3 = color:Lerp(WHITE, 0.25),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(if right then 1 else 0, if right then -32 else 32, 0.5, 0),
		Size = UDim2.fromOffset(52, 52),
		ZIndex = 4,
	}, face)
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, portrait)
	new("UIStroke", { Thickness = 3, Color = INK }, portrait)
	new("UIScale", { Name = "Bounce" }, portrait)
	text(portrait, "Initials", { Text = if right then "R" else "Y", TextSize = 30, Size = UDim2.fromScale(1, 1), ZIndex = 5 }, 3)
	new("ImageLabel", { Name = "Head", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 6, Image = "" }, portrait)
	new("ViewportFrame", { Name = "View", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 6, Visible = false, Ambient = Color3.fromRGB(200, 200, 210), LightDirection = Vector3.new(-1, -2, -1.5) }, portrait)
	local xa = if right then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
	local textX = if right then 0 else 72
	text(face, "NameText", { Text = if right then "RIVAL" else "YOU", TextSize = 24, TextXAlignment = xa, Position = UDim2.fromOffset(textX + (if right then 8 else 0), 4), Size = UDim2.new(1, -80, 0, 28), ZIndex = 4, TextTruncate = Enum.TextTruncate.AtEnd }, 3)
	text(face, "Sub", { Text = "", TextSize = 16, TextXAlignment = xa, TextColor3 = Color3.fromRGB(205, 210, 230), Position = UDim2.fromOffset(if right then 78 else textX, 32), Size = UDim2.new(1, -150, 0, 20), ZIndex = 4, TextTruncate = Enum.TextTruncate.AtEnd }, 2)
	-- taps per second, on the inner side (towards VS)
	text(face, "Rate", {
		Text = "0/s",
		TextSize = 22,
		TextColor3 = color:Lerp(WHITE, 0.45),
		TextXAlignment = if right then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(if right then 0 else 1, 1),
		Position = UDim2.new(if right then 0 else 1, if right then 10 else -10, 1, -4),
		Size = UDim2.fromOffset(70, 24),
		ZIndex = 4,
	}, 2.5)
	-- LEAD tag on the top edge, hidden until this side leads
	local lead = new("Frame", {
		Name = "Lead",
		BackgroundColor3 = GOLD,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(if right then 1 else 0, if right then -40 else 40, 0, 0), -- over the portrait, clear of the badge slot
		Size = UDim2.fromOffset(66, 24),
		ZIndex = 7,
		Visible = false,
	}, holder)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, lead)
	new("UIStroke", { Thickness = 3, Color = INK }, lead)
	shade(lead)
	text(lead, "Label", { Text = "LEAD", TextSize = 18, Size = UDim2.fromScale(1, 1), ZIndex = 8 }, 2)
	return holder
end

-- Builds the duel parts (hidden) into the HUD. Called by HudBuilder.Build, so they are saved in
-- ChessHUD.rbxm and the owner can see and edit them in Studio.
function DuelHud.Build(bottom: Frame, gui: ScreenGui)
	if bottom:FindFirstChild("Duel") then
		return
	end
	-- VS strip where the Power counter sits outside a fight
	local duel = new("Frame", { Name = "Duel", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(0, 0), Visible = false }, bottom)
	card(duel, "You", GREEN)
	card(duel, "Rival", RED)
	local vs = new("Frame", { Name = "Vs", BackgroundColor3 = RED, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(74, 56), Rotation = -4, ZIndex = 6 }, duel)
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, vs)
	new("UIStroke", { Thickness = 4, Color = INK }, vs)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, GOLD), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 120, 40)) }),
	}, vs)
	new("UIScale", { Name = "Thump" }, vs)
	text(vs, "Label", { Text = "VS", TextSize = 36, Size = UDim2.fromScale(1, 1), ZIndex = 7 }, 3.5)

	-- Combo: left of the meter, at its height (the right side has "Keep clicking!")
	local combo = new("Frame", { Name = "Combo", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0, -12, 0, 94), Size = UDim2.fromOffset(170, 70), Visible = false }, bottom)
	new("UIScale", { Name = "Pop" }, combo)
	text(combo, "Count", { Text = "x12", TextSize = 44, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(1, 0, 0, 46), ZIndex = 8 }, 4)
	text(combo, "Word", { Text = "POPPING OFF!", TextSize = 20, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(255, 150, 50), Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 24), ZIndex = 8 }, 2.5)

	-- Spark layer above the meter bar (sparks are pooled at runtime)
	local meter = bottom:FindFirstChild("Meter")
	local bar = meter and meter:FindFirstChild("Bar")
	if bar then
		new("Frame", { Name = "Sparks", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 9 }, bar)
	end

	-- Danger edges: four gradient strips around the screen
	local edges = new("Frame", { Name = "DangerEdges", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 0 }, gui)
	local specs = {
		{ "Top", UDim2.fromScale(1, 0.16), UDim2.fromScale(0, 0), 90 },
		{ "Bottom", UDim2.fromScale(1, 0.16), UDim2.fromScale(0, 0.84), 270 },
		{ "Left", UDim2.fromScale(0.1, 1), UDim2.fromScale(0, 0), 0 },
		{ "Right", UDim2.fromScale(0.1, 1), UDim2.fromScale(0.9, 0), 180 },
	}
	for _, s in specs do
		local f = new("Frame", { Name = s[1], BackgroundColor3 = Color3.fromRGB(230, 30, 40), BorderSizePixel = 0, Size = s[2], Position = s[3], ZIndex = 0 }, edges)
		new("UIGradient", { Rotation = s[4], Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }) }, f)
	end
end

-- Runtime -----------------------------------------------------------------------------

export type Deps = { tween: (Instance, number, { [string]: any }, Enum.EasingStyle?, Enum.EasingDirection?) -> any, reduced: () -> boolean, message: ((string, Color3?) -> ())? }

function DuelHud.new(gui: ScreenGui, deps: Deps)
	local G = gui :: any
	local bottom = G.Bottom
	if not bottom:FindFirstChild("Duel") then
		DuelHud.Build(bottom, gui) -- an older saved ChessHUD without the duel parts
	end
	local self = setmetatable({}, DuelHud) :: any
	self.deps = deps
	self.gui = gui
	self.bottom = bottom
	self.duel = bottom.Duel
	self.combo = bottom.Combo
	self.bar = bottom.Meter.Bar
	self.edges = G.DangerEdges
	self.active = false
	self.sparks = {}
	self.sparkNext = 1
	local layer = self.bar:FindFirstChild("Sparks")
	for i = 1, DuelHud.Tuning.sparkPool do
		local s = new("Frame", { Name = "S" .. i, BackgroundColor3 = WHITE, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(8, 8), Rotation = 45, Visible = false, ZIndex = 9 }, layer)
		new("UIStroke", { Thickness = 2, Color = INK }, s)
		self.sparks[i] = s
	end
	return self
end

function DuelHud:Start(info: any)
	self.active = true
	self.taps = {}
	self.comboCount = 0
	self.lastTap = -math.huge
	self.rivalAcc = 0
	self.rivalTimes = {}
	self.leader = nil
	self.clock = 0
	self.perTap = info.perTap or 4
	local you, rival = self.duel.YouCard, self.duel.RivalCard
	you.Face.NameText.Text = info.playerName or "YOU"
	you.Face.Sub.Text = "You"
	local head = you.Face.Portrait.Head :: ImageLabel
	head.Image = if info.userId and info.userId > 0 then `rbxthumb://type=AvatarHeadShot&id={info.userId}&w=150&h=150` else ""
	you.Face.Portrait.Initials.Text = string.upper(string.sub(info.playerName or "Y", 1, 1))
	rival.Face.NameText.Text = info.rivalName or "RIVAL"
	rival.Face.Sub.Text = info.rivalTitle or ""
	rival.Face.Band.BackgroundColor3 = info.rivalColor or RED
	rival.Face.Portrait.BackgroundColor3 = (info.rivalColor or RED):Lerp(WHITE, 0.25)
	rival.Face.Portrait.Initials.Text = string.upper(string.sub(info.rivalName or "R", 1, 1))
	-- a live 3D portrait of the rival (their character or piece) when one is given
	local view = rival.Face.Portrait.View :: ViewportFrame
	view:ClearAllChildren()
	view.Visible = false
	if info.rivalModel then
		local ok = pcall(function()
			local copy = (info.rivalModel :: Model):Clone()
			for _, d in copy:GetDescendants() do
				if d:IsA("Script") or d:IsA("LocalScript") then
					d:Destroy()
				end
			end
			copy.Parent = view
			local cf, size = copy:GetBoundingBox()
			local look = cf.Position + Vector3.new(0, size.Y * 0.32, 0) -- head height
			local cam = Instance.new("Camera")
			cam.FieldOfView = 30
			cam.CFrame = CFrame.lookAt(look + cf.LookVector * (size.Y * 0.9) + Vector3.new(0, size.Y * 0.05, 0), look)
			cam.Parent = view
			view.CurrentCamera = cam
		end)
		view.Visible = ok
	end
	you.Lead.Visible, rival.Lead.Visible = false, false
	you.Lift.Scale, rival.Lift.Scale = 1, 1
	self.combo.Visible = false
	self.edges.Visible = false
	self.duel.Visible = true
	-- entrance: cards slide in from the sides, VS thumps
	if not self.deps.reduced() then
		you.Position = UDim2.new(0, -60, 0, 0)
		rival.Position = UDim2.new(1, 60, 0, 0)
		self.deps.tween(you, 0.28, { Position = UDim2.fromScale(0, 0) }, Enum.EasingStyle.Back)
		self.deps.tween(rival, 0.28, { Position = UDim2.fromScale(1, 0) }, Enum.EasingStyle.Back)
		self.duel.Vs.Thump.Scale = 1.8
		self.deps.tween(self.duel.Vs.Thump, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end
end

function DuelHud:Stop()
	self.active = false
	self.duel.Visible = false
	self.combo.Visible = false
	self.edges.Visible = false
	for _, s in self.sparks do
		s.Visible = false
	end
end

-- A spark from the clash point. dir = 1 flies right (your push), -1 flies left (the rival's).
function DuelHud:_spark(frac: number, dir: number, color: Color3)
	if self.deps.reduced() then
		return
	end
	local s = self.sparks[self.sparkNext]
	self.sparkNext = self.sparkNext % #self.sparks + 1
	local x0 = frac
	s.BackgroundColor3 = color
	s.BackgroundTransparency = 0
	s.Position = UDim2.fromScale(x0, 0.5)
	s.Size = UDim2.fromOffset(10, 10)
	s.Visible = true
	local dy = (math.random() - 0.5) * 1.6
	self.deps.tween(s, 0.32, {
		Position = UDim2.new(x0, dir * (24 + math.random() * 26), 0.5 + dy, 0),
		Size = UDim2.fromOffset(3, 3),
		BackgroundTransparency = 1,
		Rotation = 45 + dir * 90,
	}, Enum.EasingStyle.Quad)
end

function DuelHud:Tap()
	if not self.active then
		return
	end
	local now = self.clock
	table.insert(self.taps, now)
	if now - self.lastTap > DuelHud.Tuning.comboGap then
		self.comboCount = 0
	end
	self.lastTap = now
	self.comboCount += 1
	local n = self.comboCount
	local tune = DuelHud.Tuning
	if n >= tune.comboShow then
		local combo = self.combo
		combo.Visible = true
		combo.Count.Text = `x{n}`
		local word, color = "", WHITE
		for _, w in tune.comboWords do
			if n >= w[1] then
				word, color = w[2], w[3]
				break
			end
		end
		combo.Word.Text = word
		combo.Word.TextColor3 = color
		combo.Count.TextColor3 = WHITE:Lerp(color, 0.6)
		-- one running pop, retargeted (never stacked)
		combo.Pop.Scale = if self.deps.reduced() then 1 else 1.22
		self.deps.tween(combo.Pop, 0.14, { Scale = 1 }, Enum.EasingStyle.Quad)
	end
	-- the player's portrait bounces, sparks fly toward the rival
	local p = self.duel.YouCard.Face.Portrait.Bounce
	p.Scale = if self.deps.reduced() then 1 else 1.12
	self.deps.tween(p, 0.12, { Scale = 1 })
	self:_spark(self.frac or 0.5, 1, Color3.fromRGB(150, 255, 140))
	self:_spark(self.frac or 0.5, 1, WHITE)
end

local function rate(times: { number }, now: number, window: number): number
	local i = 1
	while times[i] and times[i] < now - window do
		i += 1
	end
	if i > 1 then
		table.move(times, i, #times, 1)
		for k = #times - i + 2, #times do
			times[k] = nil
		end
	end
	return #times / window
end

-- display: the meter shown (0-100); pressure: the rival's meter per second right now.
function DuelHud:Update(dt: number, display: number, pressure: number, elapsed: number)
	if not self.active then
		return
	end
	self.clock += dt
	local now = self.clock
	local tune = DuelHud.Tuning
	local frac = display / 100
	self.frac = frac
	local you, rival = self.duel.YouCard, self.duel.RivalCard
	-- taps per second, both sides (the rival "clicks" at pressure / perTap)
	you.Face.Rate.Text = string.format("%d/s", math.floor(rate(self.taps, now, tune.rateWindow) + 0.5))
	local rivalRate = if self.perTap > 0 then pressure / self.perTap else 0
	rival.Face.Rate.Text = string.format("%d/s", math.floor(rivalRate + 0.5))
	self.rivalAcc += math.min(rivalRate, tune.rivalVisualCap) * dt
	if self.rivalAcc >= 1 then
		self.rivalAcc -= math.floor(self.rivalAcc)
		local b = rival.Face.Portrait.Bounce
		b.Scale = if self.deps.reduced() then 1 else 1.12
		self.deps.tween(b, 0.12, { Scale = 1 })
		self:_spark(frac, -1, Color3.fromRGB(255, 120, 110))
	end
	-- combo ends after a pause
	if self.combo.Visible and now - self.lastTap > tune.comboGap then
		self.combo.Visible = false
	end
	-- leader: lift + gold tag + gold edge (a tie at 50 keeps the last leader)
	local leader = if display > 50.5 then "You" elseif display < 49.5 then "Rival" else self.leader
	if leader ~= self.leader then
		self.leader = leader
		for _, c in { you, rival } do
			local on = c.Name == (leader or "") .. "Card"
			c.Lead.Visible = on
			self.deps.tween(c.Lift, 0.18, { Scale = if on then 1.06 else 0.96 }, Enum.EasingStyle.Back)
			c.Face.Edge.Color = if on then GOLD else INK
			c.Face.Edge.Thickness = if on then 4 else 3
		end
		if elapsed > 1 and self.deps.message then
			if leader == "You" then
				self.deps.message("You take the lead!", Color3.fromRGB(150, 255, 140))
			end
		end
		if not self.deps.reduced() then
			self.duel.Vs.Thump.Scale = 1.25
			self.deps.tween(self.duel.Vs.Thump, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end
	-- danger edges: slow breathing below dangerAt (static when effects are reduced)
	local danger = display <= tune.dangerAt and elapsed > 1.5
	self.edges.Visible = danger
	if danger then
		-- the HUD's UIScale shrinks everything under the ScreenGui: undo it so the edges hug the screen
		local sc = self.gui:FindFirstChild("Scale") :: UIScale?
		local k = if sc and sc.Scale > 0 then 1 / sc.Scale else 1
		self.edges.Size = UDim2.fromScale(k, k)
		local a = if self.deps.reduced() then 0.5 else 0.35 + 0.35 * (0.5 + 0.5 * math.cos(now * 2 * math.pi / tune.edgeBreath))
		for _, e in self.edges:GetChildren() do
			(e :: Frame).BackgroundTransparency = a
		end
	end
end

-- Offline / Studio preview: pose the duel as if mid-fight (no tweens, no services).
function DuelHud.Pose(gui: ScreenGui, pose: any)
	local G = gui :: any
	local bottom = G.Bottom
	DuelHud.Build(bottom, gui)
	local duel = bottom.Duel
	duel.Visible = true
	bottom.Power.Visible = false
	bottom.Progress.Visible = false
	bottom.Meter.Visible = true
	local frac = pose.meter / 100
	bottom.Meter.Bar.Fill.Size = UDim2.fromScale(math.max(frac, 0.02), 1)
	bottom.Meter.Bar.Knob.Position = UDim2.fromScale(frac, 0.5)
	bottom.Meter.Bar.Rival.Text = string.upper(pose.rivalName)
	bottom.Meter.Timer.Text = tostring(pose.timer or 12)
	bottom.Meter.Hint.Visible = pose.meter < 40
	duel.YouCard.Face.NameText.Text = pose.playerName
	duel.YouCard.Face.Sub.Text = "You"
	duel.YouCard.Face.Rate.Text = `{pose.youRate}/s`
	duel.YouCard.Face.Portrait.Initials.Text = string.upper(string.sub(pose.playerName, 1, 1))
	duel.RivalCard.Face.NameText.Text = pose.rivalName
	duel.RivalCard.Face.Sub.Text = pose.rivalTitle
	duel.RivalCard.Face.Rate.Text = `{pose.rivalRate}/s`
	duel.RivalCard.Face.Portrait.Initials.Text = string.upper(string.sub(pose.rivalName, 1, 1))
	if pose.rivalColor then
		duel.RivalCard.Face.Band.BackgroundColor3 = pose.rivalColor
		duel.RivalCard.Face.Portrait.BackgroundColor3 = pose.rivalColor:Lerp(WHITE, 0.25)
	end
	local leader = if pose.meter > 50 then duel.YouCard else duel.RivalCard
	leader.Lead.Visible = true
	leader.Face.Edge.Color = GOLD
	leader.Face.Edge.Thickness = 4
	if pose.combo and pose.combo >= DuelHud.Tuning.comboShow then
		bottom.Combo.Visible = true
		bottom.Combo.Count.Text = `x{pose.combo}`
		for _, w in DuelHud.Tuning.comboWords do
			if pose.combo >= w[1] then
				bottom.Combo.Word.Text = w[2]
				bottom.Combo.Word.TextColor3 = w[3]
				break
			end
		end
	end
	G.DangerEdges.Visible = pose.meter <= DuelHud.Tuning.dangerAt
end

return DuelHud
