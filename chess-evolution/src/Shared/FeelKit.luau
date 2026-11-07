--!strict
-- +1 Chess Evolution: the shared "feel" pieces from the vault (Build Playbooks 09, 11, 13, 14, 27, 29, 30).
--   Build(gui)                 -- adds the Level chip, Level Up line, confetti layer and Moment layer (saved in ChessHUD.rbxm)
--   FeelKit.Level(power)       -- fallback display level when Config.Level is missing: (level, progress 0..1)
--   local feel = FeelKit.new(gui, { tween, reduced })
--   feel:SetLevel(level, progress, first)   -- bar fill 0.25 s Quad; a level-up bumps, fires ~30 confetti 0.1 s later, "Level Up! [xN]"
--   feel:Popup(adornee, "+5", "power"|"wins")  -- pooled billboard, rises 2 studs over 0.5 s Back
--   feel:Reveal({ GuiObject }, animate)      -- pop-in 0.6 -> 1, 0.25 s Back, staggered 0.06 s (note 14 §4)
--   FeelKit.Moment(gui, "L", text)            -- big moment: dim 40 %, rays, confetti, ONE white flash, centre text
-- Juice is sized to the event (note 06 §2, 27 C21): XS taps get no particles or camera punch;
-- S level-ups get confetti; L moments get the full chain. Reduced effects keeps every word and number.

local FeelKit = {}
FeelKit.__index = FeelKit

local INK = Color3.fromRGB(28, 26, 40)
local WHITE = Color3.new(1, 1, 1)
local GREEN = Color3.fromRGB(70, 210, 80)
local GOLD = Color3.fromRGB(255, 196, 40)
local FONT = Font.fromEnum(Enum.Font.FredokaOne)
local CONFETTI = {
	Color3.fromRGB(255, 196, 40), Color3.fromRGB(70, 210, 80), Color3.fromRGB(40, 200, 240),
	Color3.fromRGB(240, 70, 70), Color3.fromRGB(170, 80, 240), Color3.fromRGB(255, 120, 230),
}

-- Display-only levels (note 13 §2B): ~20 per promotion, about one per second of early training.
FeelKit.LevelSizes = { 10, 10, 10, 12, 14, 15, 17, 19, 22 }
FeelKit.LevelGrowth = 1.13
FeelKit.LevelCap = 20

function FeelKit.Level(power: number): (number, number)
	local level, need, base = 1, 0, 0
	for i = 1, FeelKit.LevelCap - 1 do
		need = FeelKit.LevelSizes[i] or math.floor((FeelKit.LevelSizes[#FeelKit.LevelSizes] :: number) * FeelKit.LevelGrowth ^ (i - #FeelKit.LevelSizes) + 0.5)
		if power < base + need then
			return level, (power - base) / need
		end
		base += need
		level += 1
	end
	return FeelKit.LevelCap, 1
end

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

-- Builds the parts once (HudBuilder calls this, so they are saved in StarterGui).
function FeelKit.Build(gui: ScreenGui)
	local G = gui :: any
	local progress = G.Bottom:FindFirstChild("Progress")
	if progress and not progress:FindFirstChild("Level") then
		-- Level chip: a small green square left of the Power bar (the reference's "+1" box spot)
		local chip = new("Frame", { Name = "Level", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0, -12, 0.5, 0), Size = UDim2.fromOffset(40, 38) }, progress)
		new("UIScale", { Name = "Press" }, chip)
		local lip = new("Frame", { Name = "Lip", BackgroundColor3 = GREEN:Lerp(INK, 0.45), Position = UDim2.fromOffset(0, 4), Size = UDim2.fromScale(1, 1), ZIndex = 1 }, chip)
		new("UICorner", { CornerRadius = UDim.new(0, 10) }, lip)
		new("UIStroke", { Thickness = 3, Color = INK }, lip)
		local face = new("Frame", { Name = "Face", BackgroundColor3 = GREEN, Size = UDim2.fromScale(1, 1), ZIndex = 2, ClipsDescendants = false }, chip)
		new("UICorner", { CornerRadius = UDim.new(0, 10) }, face)
		new("UIStroke", { Thickness = 3, Color = INK }, face)
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, WHITE), ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 190, 190)) }) }, face)
		-- one line ("Lv 3") so it stays above the 12 px phone floor at the 0.557 phone scale
		text(face, "Value", { Text = "+1", TextSize = 24, Size = UDim2.fromScale(1, 1), ZIndex = 4 }, 2.5)
		-- thin fill strip inside the bottom edge
		local track = new("Frame", { Name = "Track", Visible = false, BackgroundColor3 = INK, BackgroundTransparency = 0.35, Position = UDim2.new(0, 6, 1, -9), Size = UDim2.new(1, -12, 0, 5), ZIndex = 3 }, face)
		new("UICorner", { CornerRadius = UDim.new(0, 3) }, track)
		local fill = new("Frame", { Name = "Fill", BackgroundColor3 = Color3.fromRGB(255, 240, 120), Size = UDim2.fromScale(0, 1), ZIndex = 4 }, track)
		new("UICorner", { CornerRadius = UDim.new(0, 3) }, fill)
		-- "Level Up! [x2]" pops above the chip
		local up = text(progress, "LevelUp", { Text = "Level Up!", TextSize = 30, TextColor3 = Color3.fromRGB(255, 240, 120), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, -72, 0, -4), Size = UDim2.fromOffset(240, 34), TextXAlignment = Enum.TextXAlignment.Left, Visible = false, ZIndex = 8 }, 3)
		new("UIScale", { Name = "Pop" }, up)
	end
	if not G:FindFirstChild("Confetti") then
		new("Frame", { Name = "Confetti", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 60 }, gui)
	end
	if not G:FindFirstChild("Moment") then
		local m = new("Frame", { Name = "Moment", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 55 }, gui)
		new("Frame", { Name = "Dim", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6, Size = UDim2.fromScale(1, 1), ZIndex = 55 }, m)
		local rays = new("Frame", { Name = "Rays", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(900, 900), ZIndex = 56 }, m)
		for i = 0, 11 do
			local r = new("Frame", { Name = "Ray", BackgroundColor3 = Color3.fromRGB(255, 236, 150), BackgroundTransparency = 0.55, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 46, 1, 0), Rotation = i * 15, ZIndex = 56 }, rays)
			new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }, r)
		end
		local title = text(m, "Title", { Text = "PROMOTED!", TextSize = 72, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(900, 90), TextColor3 = Color3.fromRGB(255, 230, 90), ZIndex = 58 }, 6)
		new("UIScale", { Name = "Pop" }, title)
		new("Frame", { Name = "Flash", BackgroundColor3 = WHITE, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 59 }, m)
	end
end

-- Runtime -----------------------------------------------------------------------------

function FeelKit.new(gui: ScreenGui, deps: any)
	FeelKit.Build(gui)
	local self = setmetatable({}, FeelKit) :: any
	self.gui = gui
	self.deps = deps
	self.level = nil
	self.pops = {}
	self.popNext = 1
	self.confetti = {}
	self.confettiNext = 1
	local layer = (gui :: any).Confetti
	for i = 1, 36 do
		local c = new("Frame", { Name = "C" .. i, BackgroundColor3 = CONFETTI[(i - 1) % #CONFETTI + 1], BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(9, 14), Visible = false, ZIndex = 60 }, layer)
		self.confetti[i] = c
	end
	return self
end

-- ~n pieces burst up from a screen point, then fall and fade (pooled, no new instances).
function FeelKit:Burst(at: Vector2, n: number)
	if self.deps.reduced() then
		return
	end
	local layer = (self.gui :: any).Confetti :: Frame
	local origin = layer.AbsolutePosition
	for _ = 1, n do
		local c = self.confetti[self.confettiNext]
		self.confettiNext = self.confettiNext % #self.confetti + 1
		local x, y = at.X - origin.X, at.Y - origin.Y
		c.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
		c.Rotation = math.random(0, 180)
		c.BackgroundTransparency = 0
		c.Visible = true
		local dx = math.random(-140, 140)
		local up = math.random(70, 170)
		self.deps.tween(c, 0.35, { Position = UDim2.fromOffset(math.floor(x + dx * 0.6), math.floor(y - up)), Rotation = c.Rotation + 180 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.delay(0.35, function()
			self.deps.tween(c, 0.6, { Position = UDim2.fromOffset(math.floor(x + dx), math.floor(y - up + 160)), Rotation = c.Rotation + 220, BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end)
	end
end

function FeelKit:SetLevel(level: number, progress: number, first: boolean?)
	local chip = (self.gui :: any).Bottom.Progress:FindFirstChild("Level")
	if not chip then
		return
	end
	local bar = (self.gui :: any).Bottom.Progress.Bar
	bar.Label.Text = `Level {level}`
	local fill = bar.Fill
	local gained = if self.level then level - self.level else 0
	self.level = level
	if first or gained <= 0 then
		self.deps.tween(fill, 0.25, { Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1) })
		return
	end
	-- level-up: the bar jumps (full, then the new progress), confetti 0.1 s later, the line pops
	fill.Size = UDim2.fromScale(1, 1)
	task.delay(0.1, function()
		fill.Size = UDim2.fromScale(0, 1)
		self.deps.tween(fill, 0.25, { Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1) })
		local p = chip.Face.AbsolutePosition + chip.Face.AbsoluteSize / 2
		self:Burst(p, 30)
	end)
	local sc = chip.Press :: UIScale
	sc.Scale = if self.deps.reduced() then 1 else 1.15
	self.deps.tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	local up = (self.gui :: any).Bottom.Progress.LevelUp :: TextLabel
	up.Text = if gained > 1 then `Level Up! [x{gained}]` else "Level Up!"
	up.Visible = true
	up.TextTransparency = 0;
	(up:FindFirstChild("Outline") :: UIStroke).Transparency = 0
	local pop = up:FindFirstChild("Pop") :: UIScale
	pop.Scale = 0.6
	self.deps.tween(pop, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	self.upToken = (self.upToken or 0) + 1
	local token = self.upToken
	task.delay(0.9, function()
		if self.upToken == token then
			self.deps.tween(up, 0.3, { TextTransparency = 1 })
			self.deps.tween(up:FindFirstChild("Outline") :: UIStroke, 0.3, { Transparency = 1 })
		end
	end)
end

-- "+N" over the head: pooled billboards that rise 2 studs over 0.5 s Back and fade.
local POP_COLOR = { power = Color3.fromRGB(140, 255, 120), wins = Color3.fromRGB(255, 214, 70) }
function FeelKit:Popup(adornee: BasePart?, label: string, kind: string)
	if not adornee then
		return
	end
	local pool = self.pops
	if #pool < 8 then
		local bb = new("BillboardGui", { Name = "Gain", Size = UDim2.fromOffset(160, 44), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 80, Enabled = false }, nil)
		text(bb, "Text", { TextSize = 32, Size = UDim2.fromScale(1, 1) }, 3)
		bb.Parent = adornee
		table.insert(pool, bb)
	end
	local bb = pool[self.popNext] or pool[#pool]
	self.popNext = self.popNext % 8 + 1
	bb.Adornee = adornee
	bb.Parent = adornee
	local t = bb.Text :: TextLabel
	t.Text = label
	t.TextColor3 = POP_COLOR[kind] or WHITE
	t.TextTransparency = 0;
	(t:FindFirstChild("Outline") :: UIStroke).Transparency = 0
	local x = (math.random() - 0.5) * 1.2
	bb.StudsOffset = Vector3.new(x, 2.4, 0)
	bb.Enabled = true
	self.deps.tween(bb, 0.5, { StudsOffset = Vector3.new(x, 4.4, 0) }, Enum.EasingStyle.Back)
	task.delay(0.45, function()
		self.deps.tween(t, 0.25, { TextTransparency = 1 })
		self.deps.tween(t:FindFirstChild("Outline") :: UIStroke, 0.25, { Transparency = 1 })
	end)
end

-- Pop-in for newly revealed HUD parts: 0.6 -> 1, 0.25 s Back, 0.06 s apart.
function FeelKit:Reveal(items: { GuiObject }, animate: boolean)
	for i, item in items do
		if not item.Visible then
			item.Visible = true
			local sc = (item:FindFirstChild("Press") or item:FindFirstChild("Reveal")) :: UIScale?
			if not sc then
				sc = new("UIScale", { Name = "Reveal" }, item)
			end
			if animate and not self.deps.reduced() then
				(sc :: UIScale).Scale = 0.6
				local s = sc :: UIScale
				task.delay((i - 1) * 0.06, function()
					self.deps.tween(s, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
				end)
			end
		end
	end
end

-- The L moment chain (note 06 §2, 14 §4-5): dim to 40 %, rays turn, the title slams in,
-- confetti bursts, and ONE white flash (0.22 s in, 0.45 s held, 0.3 s out). Done in about 2.6 s.
-- size: "L" (full chain) or "M" (no dim, no flash). Reduced effects: dim + title only.
function FeelKit.Moment(gui: ScreenGui, size: string, label: string, deps: any?)
	FeelKit.Build(gui)
	local TweenService = game:GetService("TweenService")
	local function tw(inst: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?)
		local x = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad), props)
		x:Play()
		return x
	end
	local d = deps or FeelKit.Default
	local reduced = d and d.reduced and d.reduced() or false
	local m = (gui :: any).Moment
	m.Visible = true
	m.Dim.BackgroundTransparency = 1
	m.Title.Text = label
	m.Title.TextTransparency = 0;
	(m.Title:FindFirstChild("Outline") :: UIStroke).Transparency = 0
	m.Rays.Visible = size == "L" and not reduced
	m.Flash.BackgroundTransparency = 1
	if size == "L" then
		tw(m.Dim, 0.3, { BackgroundTransparency = 0.6 }) -- 40 % dim
	end
	m.Title.Pop.Scale = if reduced then 1 else 1.6
	tw(m.Title.Pop, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	if m.Rays.Visible then
		m.Rays.Rotation = 0
		tw(m.Rays, 2.4, { Rotation = 60 }, Enum.EasingStyle.Linear)
	end
	if size == "L" and not reduced then
		local f = m.Flash
		tw(f, 0.22, { BackgroundTransparency = 0.35 })
		task.delay(0.22 + 0.45, function()
			tw(f, 0.3, { BackgroundTransparency = 1 })
		end)
		local kit = (deps and deps.feel) or (FeelKit.Default and FeelKit.Default.feel)
		if kit then
			local c = (gui :: any).AbsoluteSize / 2
			kit:Burst(Vector2.new(c.X, c.Y * 0.9), 36)
		end
	end
	local token = (m:GetAttribute("Token") or 0) + 1
	m:SetAttribute("Token", token)
	task.delay(2.2, function()
		if m:GetAttribute("Token") ~= token then
			return
		end
		tw(m.Dim, 0.3, { BackgroundTransparency = 1 })
		tw(m.Title, 0.3, { TextTransparency = 1 })
		tw(m.Title:FindFirstChild("Outline") :: UIStroke, 0.3, { Transparency = 1 })
		task.delay(0.32, function()
			if m:GetAttribute("Token") == token then
				m.Visible = false
			end
		end)
	end)
end

return FeelKit
