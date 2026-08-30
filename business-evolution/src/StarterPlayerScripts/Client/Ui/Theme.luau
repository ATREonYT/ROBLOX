--!strict
-- The design system every UI module draws from. One place owns the palette,
-- the fonts, the button juice and the open/close choreography so the whole
-- game feels like one product instead of seven agents' opinions. It also owns
-- the "only one panel open at a time" registry — panels never talk to each
-- other directly, they just go through openExclusive.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))
local SoundController = require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("SoundController"))

-- The UI is authored in pixels at this reference size, then a UIScale shrinks
-- whole clusters on small screens. Scaling clusters (not individual paddings)
-- keeps every ratio intact on phones, which is where most players are.
local DESIGN_WIDTH = 1280
local DESIGN_HEIGHT = 780
-- Floor on the shrink so HUD buttons stay thumb-sized on the smallest phones.
local MIN_UI_SCALE = 0.68
-- Panels may never cover more than this fraction of either screen axis, so the
-- world (and the Roblox topbar) always stays reachable behind them.
local MAX_PANEL_FRACTION = 0.85

local PANEL_CORNER_PX = 16
local PANEL_STROKE_PX = 3
local SHADOW_OFFSET_PX = 7
local SHADOW_SHOWN_TRANSPARENCY = 0.45

local Theme = {}

Theme.Colors = {
	Panel = Color3.fromRGB(35, 39, 53), -- #232735 deep navy
	PanelLight = Color3.fromRGB(46, 51, 69), -- #2E3345
	PanelDark = Color3.fromRGB(24, 27, 38), -- strokes / wells
	Shadow = Color3.fromRGB(14, 16, 24),
	Gold = Color3.fromRGB(255, 196, 40), -- #FFC428
	GoldDark = Color3.fromRGB(186, 132, 8), -- stroke under gold surfaces
	Green = Color3.fromRGB(88, 200, 92), -- #58C85C
	Red = Color3.fromRGB(232, 81, 78), -- #E8514E
	RedDark = Color3.fromRGB(150, 40, 38),
	Text = Color3.fromRGB(255, 255, 255),
	TextDim = Color3.fromRGB(184, 189, 204), -- #B8BDCC
	TextOnGold = Color3.fromRGB(43, 33, 8), -- dark ink so gold buttons stay readable
}

-- FredokaOne for anything display-sized, Gotham for body copy. Roblox has no
-- tabular-figures toggle, so counters are centre-anchored — the number grows
-- symmetrically instead of shoving its neighbours around.
Theme.DisplayFont = Enum.Font.FredokaOne
Theme.BodyFont = Enum.Font.Gotham
Theme.BodyBoldFont = Enum.Font.GothamBold

-- Easing presets so every module obeys the same motion rules:
-- Back/Elastic in, Quad/Quart out, Linear never (pure alpha fades excepted).
Theme.EnterInfo = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
Theme.EnterSlowInfo = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
Theme.ElasticInfo = TweenInfo.new(0.85, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
Theme.ExitInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Theme.ExitSlowInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
Theme.FadeInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local rng = Random.new()

-- ── Small shared builders ───────────────────────────────────────────────────

function Theme.play(instance: Instance, info: TweenInfo, props: { [string]: any }): Tween
	local tween = TweenService:Create(instance, info, props)
	tween:Play()
	return tween
end

local function applyCorner(instance: Instance, radiusPx: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radiusPx)
	corner.Parent = instance
end

local function applyStroke(instance: Instance, thickness: number, color: Color3): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness
	stroke.Color = color
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = instance
	return stroke
end

export type TextOpts = {
	Text: string,
	Parent: Instance?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	TextSize: number?,
	Color: Color3?,
	Font: Enum.Font?,
	Wrapped: boolean?,
	XAlign: Enum.TextXAlignment?,
	YAlign: Enum.TextYAlignment?,
	LayoutOrder: number?,
	Name: string?,
	StrokePx: number?, -- black text outline; 0/nil = none
	ZIndex: number?,
}

-- One label builder instead of forty hand-rolled TextLabels: the fastest way
-- to keep font/colour drift out of seven UI files.
function Theme.text(opts: TextOpts): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = opts.Name or "Text"
	label.BackgroundTransparency = 1
	label.Text = opts.Text
	label.Font = opts.Font or Theme.BodyFont
	label.TextSize = opts.TextSize or 16
	label.TextColor3 = opts.Color or Theme.Colors.Text
	label.TextWrapped = opts.Wrapped == true
	label.TextXAlignment = opts.XAlign or Enum.TextXAlignment.Center
	label.TextYAlignment = opts.YAlign or Enum.TextYAlignment.Center
	label.Size = opts.Size or UDim2.fromOffset(100, 24)
	if opts.Position then
		label.Position = opts.Position
	end
	if opts.AnchorPoint then
		label.AnchorPoint = opts.AnchorPoint
	end
	if opts.LayoutOrder then
		label.LayoutOrder = opts.LayoutOrder
	end
	if opts.ZIndex then
		label.ZIndex = opts.ZIndex
	end
	local strokePx = opts.StrokePx
	if strokePx and strokePx > 0 then
		local stroke = applyStroke(label, strokePx, Color3.fromRGB(0, 0, 0))
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	end
	label.Parent = opts.Parent
	return label
end

function Theme.title(opts: TextOpts): TextLabel
	local merged = table.clone(opts)
	merged.Font = merged.Font or Theme.DisplayFont
	merged.TextSize = merged.TextSize or 28
	merged.Color = merged.Color or Theme.Colors.Gold
	merged.StrokePx = merged.StrokePx or 2
	return Theme.text(merged)
end

-- ── Responsive scaling ──────────────────────────────────────────────────────

-- Attaches a UIScale to one top-level cluster (a HUD corner, a panel root) and
-- keeps it sized to the viewport. Scaling per-cluster instead of per-ScreenGui
-- is deliberate: each cluster shrinks toward its own AnchorPoint, so edge HUD
-- stays glued to its edge instead of drifting toward the screen origin.
-- `trove` is typed `any`: Trove's exported generic type fails luau's exact
-- table-field equality across module boundaries (old-solver quirk), and every
-- caller hands us a real Trove anyway.
function Theme.autoScale(element: GuiObject, trove: any, fitSize: Vector2?): UIScale
	local scale = Instance.new("UIScale")
	scale.Parent = element

	local function update()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		if viewport.X < 2 or viewport.Y < 2 then
			return -- camera not sized yet; the property signal will re-fire
		end
		local factor = math.clamp(
			math.min(viewport.X / DESIGN_WIDTH, viewport.Y / DESIGN_HEIGHT),
			MIN_UI_SCALE,
			1
		)
		if fitSize and fitSize.X > 0 and fitSize.Y > 0 then
			-- Panels get a second cap: never larger than 85% of the viewport,
			-- even if that dips below the HUD's minimum scale.
			factor = math.min(
				factor,
				viewport.X * MAX_PANEL_FRACTION / fitSize.X,
				viewport.Y * MAX_PANEL_FRACTION / fitSize.Y
			)
		end
		scale.Scale = factor
	end

	update()
	local camera = workspace.CurrentCamera
	if camera then
		trove:Connect(camera:GetPropertyChangedSignal("ViewportSize"), update)
	end
	trove:Connect(workspace:GetPropertyChangedSignal("CurrentCamera"), function()
		local newCamera = workspace.CurrentCamera
		if newCamera then
			trove:Connect(newCamera:GetPropertyChangedSignal("ViewportSize"), update)
			update()
		end
	end)
	return scale
end

-- One ScreenGui per module, DisplayOrder managed here so layering is decided
-- in exactly one file: Hud 1, panels 5, RankUpFx 10 (popups sit at 100).
function Theme.screenGui(name: string, displayOrder: number, trove: any, ignoreInset: boolean?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.DisplayOrder = displayOrder
	gui.IgnoreGuiInset = ignoreInset == true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	trove:Add(gui)
	return gui
end

-- ── Buttons ─────────────────────────────────────────────────────────────────

type VariantStyle = {
	Background: Color3,
	Text: Color3,
	Stroke: Color3,
	BackgroundTransparency: number,
}

local BUTTON_VARIANTS: { [string]: VariantStyle } = {
	primary = {
		Background = Theme.Colors.Gold,
		Text = Theme.Colors.TextOnGold,
		Stroke = Theme.Colors.GoldDark,
		BackgroundTransparency = 0,
	},
	danger = {
		Background = Theme.Colors.Red,
		Text = Theme.Colors.Text,
		Stroke = Theme.Colors.RedDark,
		BackgroundTransparency = 0,
	},
	ghost = {
		Background = Theme.Colors.PanelLight,
		Text = Theme.Colors.Text,
		Stroke = Theme.Colors.PanelDark,
		BackgroundTransparency = 0.12,
	},
}

export type ButtonOpts = {
	Text: string,
	Variant: ("primary" | "danger" | "ghost")?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	TextSize: number?,
	Parent: Instance?,
	Name: string?,
	Silent: boolean?, -- suppress the click sound (locked rows play Error instead)
	ZIndex: number?,
	OnClick: (() -> ())?,
}

-- THE button. Squash 0.92 over 0.06s, Back-overshoot to 1.0 over 0.18s,
-- hover-grow 1.05, click sound. Custom clickable cards pass Text = "" and
-- parent their own children into the returned TextButton, so even fancy cards
-- inherit the exact same feel.
function Theme.button(opts: ButtonOpts): TextButton
	local style = BUTTON_VARIANTS[opts.Variant or "primary"]

	local button = Instance.new("TextButton")
	button.Name = opts.Name or "Button"
	button.AutoButtonColor = false -- the scale animation IS the feedback
	button.Text = opts.Text
	button.Font = Theme.DisplayFont
	button.TextSize = opts.TextSize or 22
	button.TextColor3 = style.Text
	button.BackgroundColor3 = style.Background
	button.BackgroundTransparency = style.BackgroundTransparency
	button.Size = opts.Size or UDim2.fromOffset(200, 56)
	if opts.Position then
		button.Position = opts.Position
	end
	if opts.AnchorPoint then
		button.AnchorPoint = opts.AnchorPoint
	end
	if opts.LayoutOrder then
		button.LayoutOrder = opts.LayoutOrder
	end
	if opts.ZIndex then
		button.ZIndex = opts.ZIndex
	end
	applyCorner(button, 12)
	applyStroke(button, PANEL_STROKE_PX, style.Stroke)

	local scale = Instance.new("UIScale")
	scale.Name = "JuiceScale"
	scale.Parent = button

	-- Rebuilt UIs destroy buttons freely, so each button carries its own tiny
	-- trove that cleans itself on Destroying — no central registry to leak.
	local buttonTrove = Trove.new()
	local hovering = false

	local function restingScale(): number
		return if hovering then 1.05 else 1
	end

	buttonTrove:Connect(button.MouseEnter, function()
		hovering = true
		Theme.play(scale, Theme.EnterInfo, { Scale = 1.05 })
	end)
	buttonTrove:Connect(button.MouseLeave, function()
		hovering = false
		Theme.play(scale, Theme.ExitInfo, { Scale = 1 })
	end)
	buttonTrove:Connect(button.Activated, function()
		if opts.Silent ~= true then
			SoundController.play("Click")
		end
		Theme.play(scale, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.92 })
		task.delay(0.06, function()
			Theme.play(
				scale,
				TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = restingScale() }
			)
		end)
		local onClick = opts.OnClick
		if onClick then
			onClick()
		end
	end)
	buttonTrove:Connect(button.Destroying, function()
		buttonTrove:Destroy()
	end)

	button.Parent = opts.Parent
	return button
end

-- Angry no-wiggle for clicks that can't succeed (locked floors, empty wallet).
-- Reverses = true so the object always lands exactly where it started.
function Theme.deny(target: GuiObject)
	SoundController.play("Error")
	Theme.play(
		target,
		TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 3, true),
		{ Rotation = 4 }
	)
end

-- ── Panels ──────────────────────────────────────────────────────────────────

type FadeItem = {
	Object: Instance,
	Property: string,
	Shown: number,
	Hidden: number,
}

export type Panel = {
	Name: string,
	Root: Frame, -- positioned/scaled wrapper; stays put
	Anim: Frame, -- what open/close scales
	Body: Frame, -- put your content here
	Scale: UIScale,
	Fade: { FadeItem },
}

export type PanelOpts = {
	Name: string, -- key in the exclusive-panel registry
	Title: string?,
	Size: UDim2?, -- offset-based; also drives the ≤85%-viewport fit cap
	Parent: Instance,
	Trove: any, -- the caller's Trove (typed loosely; see autoScale's note)
	HideClose: boolean?,
}

-- Guards delayed hide callbacks: a close scheduled before a re-open must not
-- blank the freshly opened panel.
local function bumpAnimGen(instance: Instance): number
	local gen = (instance:GetAttribute("AnimGen") :: number? or 0) + 1
	instance:SetAttribute("AnimGen", gen)
	return gen
end

function Theme.open(panel: Panel)
	bumpAnimGen(panel.Anim)
	panel.Root.Visible = true
	SoundController.play("UiOpen")
	panel.Scale.Scale = 0.85
	Theme.play(panel.Scale, Theme.EnterInfo, { Scale = 1 })
	for _, item in panel.Fade do
		-- Start from fully hidden every time so a rapid close→open cannot
		-- leave a half-faded frame behind.
		(item.Object :: any)[item.Property] = item.Hidden
		Theme.play(item.Object, Theme.FadeInfo, { [item.Property] = item.Shown })
	end
end

function Theme.close(panel: Panel)
	local gen = bumpAnimGen(panel.Anim)
	Theme.play(panel.Scale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.88 })
	for _, item in panel.Fade do
		Theme.play(item.Object, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { [item.Property] = item.Hidden })
	end
	task.delay(0.16, function()
		if (panel.Anim:GetAttribute("AnimGen") :: number?) == gen then
			panel.Root.Visible = false
		end
	end)
end

-- The exclusivity registry. Exactly one panel may be open; opening another
-- closes the first, so panels can never stack into an unreadable pile.
local currentPanelName: string? = nil
local currentPanelHandle: Panel? = nil

function Theme.currentPanel(): string?
	return currentPanelName
end

function Theme.openExclusive(panel: Panel)
	if currentPanelName == panel.Name then
		return -- already front and centre; re-playing the entrance looks buggy
	end
	local previous = currentPanelHandle
	if previous then
		Theme.close(previous)
	end
	currentPanelName = panel.Name
	currentPanelHandle = panel
	Theme.open(panel)
end

-- Pass a name to close only if that panel is the open one; pass nothing to
-- close whatever is open.
function Theme.closeExclusive(name: string?)
	if currentPanelName == nil then
		return
	end
	if name ~= nil and name ~= currentPanelName then
		return
	end
	local handle = currentPanelHandle
	currentPanelName = nil
	currentPanelHandle = nil
	if handle then
		Theme.close(handle)
	end
end

-- Rounded 16px panel, thick stroke, subtle top-light gradient, drop shadow via
-- an offset dark frame. The Anim/Root split exists because Root carries the
-- responsive UIScale and Anim carries the open/close UIScale — two UIScales on
-- one instance would fight.
function Theme.panel(opts: PanelOpts): Panel
	local size = opts.Size or UDim2.fromOffset(920, 520)

	local root = Instance.new("Frame")
	root.Name = opts.Name .. "Panel"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = size
	root.Visible = false

	local fitSize: Vector2? = nil
	if size.X.Offset > 0 and size.Y.Offset > 0 then
		fitSize = Vector2.new(size.X.Offset, size.Y.Offset)
	end
	Theme.autoScale(root, opts.Trove, fitSize)

	local anim = Instance.new("Frame")
	anim.Name = "Anim"
	anim.BackgroundTransparency = 1
	anim.Size = UDim2.fromScale(1, 1)
	anim.Parent = root

	local animScale = Instance.new("UIScale")
	animScale.Parent = anim

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.BackgroundColor3 = Theme.Colors.Shadow
	shadow.BackgroundTransparency = SHADOW_SHOWN_TRANSPARENCY
	shadow.BorderSizePixel = 0
	shadow.Position = UDim2.fromOffset(0, SHADOW_OFFSET_PX)
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.ZIndex = 1
	applyCorner(shadow, PANEL_CORNER_PX)
	shadow.Parent = anim

	local surface = Instance.new("Frame")
	surface.Name = "Surface"
	surface.BackgroundColor3 = Theme.Colors.Panel
	surface.BorderSizePixel = 0
	surface.Size = UDim2.fromScale(1, 1)
	surface.ZIndex = 2
	applyCorner(surface, PANEL_CORNER_PX)
	local stroke = applyStroke(surface, PANEL_STROKE_PX, Theme.Colors.PanelDark)
	surface.Parent = anim

	-- White-multiplied gradient: a whisper of top light so big flat panels
	-- don't read as dead rectangles.
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 212, 224)),
	})
	gradient.Parent = surface

	local hasTitle = opts.Title ~= nil
	if hasTitle then
		Theme.title({
			Text = opts.Title :: string,
			Parent = surface,
			Size = UDim2.new(1, -128, 0, 44),
			Position = UDim2.new(0, 64, 0, 10),
			TextSize = 30,
		})
	end

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	if hasTitle then
		body.Position = UDim2.new(0, 16, 0, 60)
		body.Size = UDim2.new(1, -32, 1, -76)
	else
		body.Position = UDim2.new(0, 16, 0, 16)
		body.Size = UDim2.new(1, -32, 1, -32)
	end
	body.Parent = surface

	local panel: Panel = {
		Name = opts.Name,
		Root = root,
		Anim = anim,
		Body = body,
		Scale = animScale,
		Fade = {
			{ Object = surface, Property = "BackgroundTransparency", Shown = 0, Hidden = 1 },
			{ Object = stroke, Property = "Transparency", Shown = 0, Hidden = 1 },
			{ Object = shadow, Property = "BackgroundTransparency", Shown = SHADOW_SHOWN_TRANSPARENCY, Hidden = 1 },
		},
	}

	if opts.HideClose ~= true then
		-- Every panel gets an explicit ✕: on mobile there is no Esc key.
		Theme.button({
			Text = "✕",
			Variant = "ghost",
			Size = UDim2.fromOffset(44, 44),
			Position = UDim2.new(1, -54, 0, 10),
			TextSize = 24,
			Parent = surface,
			Name = "CloseButton",
			OnClick = function()
				Theme.closeExclusive(opts.Name)
			end,
		})
	end

	root.Parent = opts.Parent
	return panel
end

-- ── Widgets ─────────────────────────────────────────────────────────────────

export type CardOpts = {
	Parent: Instance?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Color: Color3?,
	Name: string?,
	ZIndex: number?,
}

-- Lighter inset card for content inside panels (tier offers, intern cards…).
function Theme.card(opts: CardOpts): Frame
	local card = Instance.new("Frame")
	card.Name = opts.Name or "Card"
	card.BackgroundColor3 = opts.Color or Theme.Colors.PanelLight
	card.BorderSizePixel = 0
	card.Size = opts.Size or UDim2.fromOffset(200, 120)
	if opts.Position then
		card.Position = opts.Position
	end
	if opts.AnchorPoint then
		card.AnchorPoint = opts.AnchorPoint
	end
	if opts.LayoutOrder then
		card.LayoutOrder = opts.LayoutOrder
	end
	if opts.ZIndex then
		card.ZIndex = opts.ZIndex
	end
	applyCorner(card, 12)
	applyStroke(card, 2, Theme.Colors.PanelDark)
	card.Parent = opts.Parent
	return card
end

export type CurrencyLabel = {
	Root: Frame,
	Label: TextLabel,
	Set: (value: number) -> (),
}

export type CurrencyOpts = {
	Icon: string,
	Parent: Instance?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	TextSize: number?,
	Color: Color3?,
	LayoutOrder: number?,
	Format: (value: number) -> string,
}

-- Dark pill with an emoji icon and a value that pops when it changes. The
-- formatter is injected (always Format.abbreviate for currency, per contract)
-- so Theme itself never grows an opinion about number display.
function Theme.currencyLabel(opts: CurrencyOpts): CurrencyLabel
	local root = Instance.new("Frame")
	root.Name = "Currency" .. opts.Icon
	root.BackgroundColor3 = Theme.Colors.Panel
	root.BackgroundTransparency = 0.2
	root.BorderSizePixel = 0
	root.Size = opts.Size or UDim2.fromOffset(172, 46)
	if opts.Position then
		root.Position = opts.Position
	end
	if opts.AnchorPoint then
		root.AnchorPoint = opts.AnchorPoint
	end
	if opts.LayoutOrder then
		root.LayoutOrder = opts.LayoutOrder
	end
	applyCorner(root, 23)
	applyStroke(root, 2, Theme.Colors.PanelDark)

	Theme.text({
		Text = opts.Icon,
		Parent = root,
		Size = UDim2.fromOffset(38, 38),
		Position = UDim2.new(0, 6, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		TextSize = 24,
	})

	local value = Theme.text({
		Text = "0",
		Parent = root,
		Size = UDim2.new(1, -52, 1, 0),
		Position = UDim2.new(0, 46, 0, 0),
		Font = Theme.DisplayFont,
		TextSize = opts.TextSize or 22,
		Color = opts.Color or Theme.Colors.Gold,
		XAlign = Enum.TextXAlignment.Left,
		StrokePx = 2,
	})

	local popScale = Instance.new("UIScale")
	popScale.Parent = value

	local lastValue: number? = nil
	local function set(newValue: number)
		if lastValue ~= nil and newValue == lastValue then
			return
		end
		value.Text = opts.Format(newValue)
		if lastValue ~= nil then
			-- Pop only on change, not on the first paint after join.
			popScale.Scale = 1.22
			Theme.play(popScale, Theme.EnterInfo, { Scale = 1 })
		end
		lastValue = newValue
	end

	root.Parent = opts.Parent
	return { Root = root, Label = value, Set = set }
end

export type ProgressBar = {
	Root: Frame,
	Fill: Frame,
	Label: TextLabel,
	Set: (alpha: number, instant: boolean?) -> (),
}

export type ProgressBarOpts = {
	Parent: Instance?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	FillColor: Color3?,
}

-- Rounded track + springy fill. Growth overshoots with Back (feels like a
-- spring landing), shrink slides out with Quad — matching the motion rules.
function Theme.progressBar(opts: ProgressBarOpts): ProgressBar
	local root = Instance.new("Frame")
	root.Name = "ProgressBar"
	root.BackgroundColor3 = Theme.Colors.PanelDark
	root.BorderSizePixel = 0
	root.Size = opts.Size or UDim2.fromOffset(300, 16)
	if opts.Position then
		root.Position = opts.Position
	end
	if opts.AnchorPoint then
		root.AnchorPoint = opts.AnchorPoint
	end
	if opts.LayoutOrder then
		root.LayoutOrder = opts.LayoutOrder
	end
	applyCorner(root, 999)
	applyStroke(root, 2, Theme.Colors.Shadow)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = opts.FillColor or Theme.Colors.Gold
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	applyCorner(fill, 999)
	local fillGradient = Instance.new("UIGradient")
	fillGradient.Rotation = 90
	fillGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(198, 198, 205)),
	})
	fillGradient.Parent = fill
	fill.Parent = root

	local label = Theme.text({
		Text = "",
		Parent = root,
		Size = UDim2.fromScale(1, 1),
		Font = Theme.BodyBoldFont,
		TextSize = 12,
		StrokePx = 2,
		ZIndex = 3,
	})

	local lastAlpha = 0
	local function set(alpha: number, instant: boolean?)
		alpha = math.clamp(alpha, 0, 1)
		-- Below ~3% a pill-cornered fill renders as a smeared dot, so hide the
		-- sliver entirely rather than draw it wrong.
		local visualAlpha = if alpha < 0.03 then 0 else alpha
		local target = UDim2.fromScale(visualAlpha, 1)
		if instant then
			fill.Size = target
		else
			local growing = alpha >= lastAlpha
			local info = if growing
				then TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
				else TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			Theme.play(fill, info, { Size = target })
		end
		lastAlpha = alpha
	end

	root.Parent = opts.Parent
	return { Root = root, Fill = fill, Label = label, Set = set }
end

export type TabRow = {
	Root: Frame,
	Select: (index: number) -> (),
}

export type TabRowOpts = {
	Parent: Instance?,
	Tabs: { string },
	OnSelect: (index: number) -> (),
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
}

function Theme.tabRow(opts: TabRowOpts): TabRow
	local root = Instance.new("Frame")
	root.Name = "TabRow"
	root.BackgroundTransparency = 1
	root.Size = opts.Size or UDim2.new(1, 0, 0, 48)
	if opts.Position then
		root.Position = opts.Position
	end
	if opts.AnchorPoint then
		root.AnchorPoint = opts.AnchorPoint
	end

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = root

	local buttons: { TextButton } = {}
	local selected = 0

	local function restyle()
		for index, tabButton in buttons do
			local active = index == selected
			tabButton.BackgroundColor3 = if active then Theme.Colors.Gold else Theme.Colors.PanelLight
			tabButton.BackgroundTransparency = if active then 0 else 0.12
			tabButton.TextColor3 = if active then Theme.Colors.TextOnGold else Theme.Colors.Text
		end
	end

	local select: (index: number) -> ()

	for index, name in opts.Tabs do
		local tabButton = Theme.button({
			Text = name,
			Variant = "ghost",
			Size = UDim2.fromOffset(math.max(120, 22 * #name), 44),
			Parent = root,
			LayoutOrder = index,
			OnClick = function()
				select(index)
			end,
		})
		table.insert(buttons, tabButton)
	end

	select = function(index: number)
		if index == selected then
			return
		end
		selected = index
		restyle()
		opts.OnSelect(index)
	end

	-- First tab starts active without firing OnSelect (callers build their
	-- default view themselves; a surprise callback during construction is
	-- a classic ordering bug).
	selected = 1
	restyle()

	root.Parent = opts.Parent
	return { Root = root, Select = select }
end

-- ── Confetti (shared by intern reveals, severance picks and rank-ups) ───────

local DEFAULT_CONFETTI_COLORS: { Color3 } = {
	Theme.Colors.Gold,
	Color3.fromRGB(255, 228, 138),
	Theme.Colors.Text,
	Theme.Colors.Green,
}

local function makeConfettiPiece(parent: GuiObject, colors: { Color3 }): Frame
	local piece = Instance.new("Frame")
	piece.Name = "Confetti"
	piece.BackgroundColor3 = colors[rng:NextInteger(1, #colors)]
	piece.BorderSizePixel = 0
	piece.Size = UDim2.fromOffset(rng:NextInteger(7, 13), rng:NextInteger(12, 20))
	piece.Rotation = rng:NextNumber(0, 360)
	piece.ZIndex = 50
	applyCorner(piece, 3)
	piece.Parent = parent
	return piece
end

-- Radial burst from the centre of `parent` — the "you got a thing" moment.
function Theme.confettiBurst(parent: GuiObject, count: number, colors: { Color3 }?)
	local palette = colors or DEFAULT_CONFETTI_COLORS
	for _ = 1, count do
		local piece = makeConfettiPiece(parent, palette)
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = UDim2.fromScale(0.5, 0.5)
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(90, 240)
		local flightSeconds = rng:NextNumber(0.5, 0.85)
		Theme.play(piece, TweenInfo.new(flightSeconds, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, math.cos(angle) * distance, 0.5, math.sin(angle) * distance),
			Rotation = piece.Rotation + rng:NextNumber(-360, 360),
		})
		-- Transparency is a pure alpha fade, where Quad is fine.
		Theme.play(piece, TweenInfo.new(flightSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
		})
		Debris:AddItem(piece, flightSeconds + 0.1)
	end
end

-- Full-height rain for the big ceremonies (rank-up, restructure).
function Theme.confettiRain(parent: GuiObject, count: number, colors: { Color3 }?)
	local palette = colors or DEFAULT_CONFETTI_COLORS
	for _ = 1, count do
		task.delay(rng:NextNumber(0, 0.45), function()
			if not parent.Parent then
				return -- ceremony gui got torn down while we waited
			end
			local piece = makeConfettiPiece(parent, palette)
			local x = rng:NextNumber(0.02, 0.98)
			piece.Position = UDim2.fromScale(x, -0.06)
			local fallSeconds = rng:NextNumber(1.1, 1.9)
			-- Quad-In fall reads as gravity: slow release, fast landing.
			Theme.play(piece, TweenInfo.new(fallSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromScale(x + rng:NextNumber(-0.08, 0.08), 1.06),
				Rotation = piece.Rotation + rng:NextNumber(120, 540),
			})
			Debris:AddItem(piece, fallSeconds + 0.1)
		end)
	end
end

-- Main.client drives everything through Init/Start; Theme has no setup of its
-- own but keeps the shape so the bootstrap can treat all modules the same.
function Theme:Init() end
function Theme:Start() end

return Theme
