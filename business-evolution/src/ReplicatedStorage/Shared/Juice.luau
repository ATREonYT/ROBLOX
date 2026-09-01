--!strict
-- Juice — THE motion module. Every tween in the game comes from here, so
-- durations and easing are consistent and tunable in one place.
--
-- House rules (enforced by the helpers, not by discipline):
--   * Nothing linear. Quad or Back, always EasingDirection.Out.
--   * Nothing longer than 0.6s.
--   * Idle loops get a randomised phase so nothing moves in unison —
--     synchronised bobbing looks worse than no bobbing at all.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Juice = {}

-- ── The timing table. Change a feel here, it changes everywhere. ───────────
Juice.Timing = {
	HoverIn = { Time = 0.12, Style = Enum.EasingStyle.Quad },
	HoverOut = { Time = 0.18, Style = Enum.EasingStyle.Quad },
	PressDown = { Time = 0.05, Style = Enum.EasingStyle.Quad },
	ReleasePop = { Time = 0.22, Style = Enum.EasingStyle.Back },
	ScalePunch = { Time = 0.20, Style = Enum.EasingStyle.Back }, -- 1 -> 1.08 -> 1
	PanelOpen = { Time = 0.18, Style = Enum.EasingStyle.Back },
	PanelClose = { Time = 0.15, Style = Enum.EasingStyle.Quad },
	LabelFade = { Time = 0.15, Style = Enum.EasingStyle.Quad }, -- proximity labels
	ClickPopup = { Time = 0.50, Style = Enum.EasingStyle.Quad }, -- "+1" rise and fade
	CountUp = { Time = 0.45, Style = Enum.EasingStyle.Quad },
	IdleFloat = { Time = 2.0, Style = Enum.EasingStyle.Sine }, -- the only looping one
}

Juice.IdleFloatStuds = 0.4
Juice.PunchScale = 1.08
Juice.ClickPopupRisePixels = 50

local MAX_DURATION = 0.6

-- Build a TweenInfo from the table above. Out direction is not optional.
export type TweenOverrides = { Time: number?, Repeat: number?, Reverses: boolean?, Delay: number? }

function Juice.info(name: string, overrides: TweenOverrides?): TweenInfo
	local entry = Juice.Timing[name]
	assert(entry, ("Juice: no timing named %q"):format(name))
	local opts: TweenOverrides = overrides or {}
	local duration = math.min(opts.Time or entry.Time, if name == "IdleFloat" then math.huge else MAX_DURATION)
	return TweenInfo.new(
		duration,
		entry.Style,
		Enum.EasingDirection.Out,
		opts.Repeat or 0,
		opts.Reverses or false,
		opts.Delay or 0
	)
end

-- Play a tween, cancelling whatever was previously running on that instance.
-- Not cancelling is the single most common Roblox UI bug: fast hover in/out
-- leaves a button stuck mid-tween.
local running: { [Instance]: Tween } = {}

function Juice.play(instance: Instance, infoName: string, properties: { [string]: any }, overrides: TweenOverrides?): Tween
	local previous = running[instance]
	if previous then
		previous:Cancel()
	end
	local tween = TweenService:Create(instance, Juice.info(infoName, overrides), properties)
	running[instance] = tween
	tween.Completed:Once(function()
		if running[instance] == tween then
			running[instance] = nil
		end
	end)
	tween:Play()
	return tween
end

-- ── Idle float ─────────────────────────────────────────────────────────────
-- Purchasable items bob 0.4 studs over 2s, sine, reversing. The phase offset
-- is derived from the instance so two items never rise together, and it is
-- stable across rejoins rather than random per session.

local floaters: { [BasePart]: { Origin: CFrame, Phase: number, Spin: number } } = {}

function Juice.addFloat(part: BasePart, spinsPerSecond: number?)
	-- Deterministic phase from the part's position: neighbours differ, and the
	-- same object always picks the same offset.
	local seed = part.Position.X * 12.9898 + part.Position.Z * 78.233
	local phase = (math.sin(seed) * 43758.5453) % 1
	floaters[part] = {
		Origin = part.CFrame,
		Phase = phase * math.pi * 2,
		Spin = spinsPerSecond or 0,
	}
end

function Juice.removeFloat(part: BasePart)
	floaters[part] = nil
end

-- Drive every floater from ONE loop. Call once, from a client controller.
function Juice.startFloatLoop(): RBXScriptConnection
	local period = Juice.Timing.IdleFloat.Time
	return RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for part, entry in floaters do
			if part.Parent == nil then
				floaters[part] = nil
				continue
			end
			local wave = math.sin(now * (math.pi * 2 / period) + entry.Phase)
			local offset = CFrame.new(0, wave * Juice.IdleFloatStuds, 0)
			local spin = if entry.Spin ~= 0 then CFrame.Angles(0, now * entry.Spin * math.pi * 2, 0) else CFrame.identity
			part.CFrame = entry.Origin * offset * spin
		end
	end)
end

-- ── Scale punch (purchase feedback) ────────────────────────────────────────
-- 1 -> 1.08 -> 1 over 0.2s. Works on a UIScale or on a model's PrimaryPart.

function Juice.punchUi(scale: UIScale)
	scale.Scale = 1
	local tween = TweenService:Create(
		scale,
		TweenInfo.new(Juice.Timing.ScalePunch.Time / 2, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, true),
		{ Scale = Juice.PunchScale }
	)
	tween:Play()
end

-- World-space equivalent: briefly grow a prop around its own centre.
function Juice.punchPart(part: BasePart)
	local base = part.Size
	local tween = TweenService:Create(
		part,
		TweenInfo.new(Juice.Timing.ScalePunch.Time / 2, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, true),
		{ Size = base * Juice.PunchScale }
	)
	tween:Play()
end

-- ── Panel open / close ─────────────────────────────────────────────────────
-- Scale 0.9 -> 1 plus a fade, over 0.18s. Nothing appears instantly.

function Juice.openPanel(frame: GuiObject, scale: UIScale)
	frame.Visible = true
	scale.Scale = 0.9
	Juice.play(scale, "PanelOpen", { Scale = 1 })
	if frame:IsA("CanvasGroup") then
		frame.GroupTransparency = 1
		Juice.play(frame, "PanelOpen", { GroupTransparency = 0 })
	end
end

function Juice.closePanel(frame: GuiObject, scale: UIScale)
	local tween = Juice.play(scale, "PanelClose", { Scale = 0.9 })
	if frame:IsA("CanvasGroup") then
		Juice.play(frame, "PanelClose", { GroupTransparency = 1 })
	end
	tween.Completed:Once(function()
		frame.Visible = false
	end)
end

-- ── Fade helper for the proximity labels ───────────────────────────────────
-- Never snap Visible: tween the transparency and only then disable.

function Juice.fadeLabel(label: TextLabel, visible: boolean)
	local target = if visible then 0 else 1
	Juice.play(label, "LabelFade", { TextTransparency = target, TextStrokeTransparency = if visible then 0.2 else 1 })
end

return Juice
