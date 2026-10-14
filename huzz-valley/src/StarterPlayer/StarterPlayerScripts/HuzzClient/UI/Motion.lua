-- Small, calm motion (design/IMPLEMENTATION-PROMPT.md §12): hover lighten, press squish, window fade + scale.
-- One tween per (object, channel): a new one cancels the old, so fast clicking never leaves things half-way.
-- Reduced Motion (a setting) turns movement and scaling off; fades become instant.
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)

local Motion = {}
Motion.reduced = false

local running: { [Instance]: { [string]: Tween } } = setmetatable({}, { __mode = "k" }) :: any

function Motion.tween(inst: Instance, channel: string, time: number, props: { [string]: any }, style: Enum.EasingStyle?)
	running[inst] = running[inst] or {}
	local old = running[inst][channel]
	if old then old:Cancel() end
	if Motion.reduced or time <= 0 then
		for k, v in props do (inst :: any)[k] = v end
		running[inst][channel] = nil
		return nil
	end
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	running[inst][channel] = t
	t:Play()
	return t
end

local function scaleOf(inst: GuiObject): UIScale
	local s = inst:FindFirstChild("PressScale") :: UIScale?
	if not s then
		s = Instance.new("UIScale")
		s.Name = "PressScale"
		s.Parent = inst
	end
	return s :: UIScale
end

-- Hover/press feedback for a button: fill eases lighter on hover and the button lifts a little (1.04); pressing
-- squishes it (0.92) and releasing springs it back with a small overshoot. The button's layout box never changes
-- (it's a UIScale around the button's centre), so nothing next to it moves. colors(state) gives the fill for
-- "Idle", "Hover" and "Pressed".
local SPRING = Enum.EasingStyle.Back
function Motion.bindButton(btn: GuiButton, colors: (string) -> Color3?)
	local hovered, pressed = false, false
	local function refresh()
		local c = colors(pressed and "Pressed" or hovered and "Hover" or "Idle")
		if c then Motion.tween(btn, "fill", Theme.Motion.Hover, { BackgroundColor3 = c }) end
	end
	local function size(target: number, time: number, style: Enum.EasingStyle?)
		if Motion.reduced or btn:GetAttribute("Disabled") then target = 1 end
		Motion.tween(scaleOf(btn), "press", time, { Scale = target }, style)
	end
	btn.MouseEnter:Connect(function()
		hovered = true
		refresh()
		if not pressed then size(1.04, Theme.Motion.Hover) end
	end)
	btn.MouseLeave:Connect(function()
		hovered, pressed = false, false
		refresh()
		size(1, Theme.Motion.Hover)
	end)
	btn.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA then
			pressed = true
			refresh()
			size(0.92, Theme.Motion.Press)
		end
	end)
	btn.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if not pressed or not (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA) then return end
		pressed = false
		refresh()
		size(hovered and 1.04 or 1, Theme.Motion.Release, SPRING) -- springs back past its size, then settles
	end)
	return refresh
end

-- A quick "pop" on something that just changed (a price that became OWNED, a selected tab): 1 -> 1.08 -> 1.
function Motion.pop(inst: GuiObject)
	if Motion.reduced then return end
	local s = scaleOf(inst)
	s.Scale = 1.08
	Motion.tween(s, "press", Theme.Motion.Release, { Scale = 1 }, SPRING)
end

-- Items slide up into place one after another (window open, tab switch). Each item's own Position is the target.
function Motion.stagger(items: { GuiObject })
	for i, item in items do
		local target = item:GetAttribute("HomePosition") or item.Position
		item:SetAttribute("HomePosition", target)
		if Motion.reduced then
			item.Position = target
		else
			item.Position = target + UDim2.fromOffset(0, 14)
			task.delay((i - 1) * Theme.Motion.Stagger, function()
				if not item.Parent then return end -- a tab switch removed it meanwhile
				Motion.tween(item, "slide", Theme.Motion.Slide, { Position = target }, Enum.EasingStyle.Quint)
			end)
		end
	end
end

-- Window open: fades in while growing from 0.8 with a soft overshoot, rising 16 px. `group` is the window's
-- CanvasGroup (anchored at its centre), `scale` its open UIScale.
function Motion.open(group: CanvasGroup, scale: UIScale, basePos: UDim2)
	group.Visible = true
	if Motion.reduced then
		group.GroupTransparency, scale.Scale, group.Position = 0, 1, basePos
		return
	end
	group.GroupTransparency, scale.Scale = 1, 0.8
	group.Position = basePos + UDim2.fromOffset(0, 16)
	Motion.tween(group, "fade", Theme.Motion.Open * 0.6, { GroupTransparency = 0 }, Enum.EasingStyle.Sine)
	Motion.tween(group, "move", Theme.Motion.Open, { Position = basePos }, Enum.EasingStyle.Quint)
	Motion.tween(scale, "open", Theme.Motion.Open, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Window close: shrinks to 0.9 and fades out quickly, then hides.
function Motion.close(group: CanvasGroup, scale: UIScale?, done: () -> ())
	if scale and not Motion.reduced then Motion.tween(scale, "open", Theme.Motion.Close, { Scale = 0.9 }, Enum.EasingStyle.Quad) end
	local t = Motion.tween(group, "fade", Theme.Motion.Close, { GroupTransparency = 1 }, Enum.EasingStyle.Quad)
	if not t then
		group.Visible = false
		done()
		return
	end
	t.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			group.Visible = false
			done()
		end
	end)
end

return Motion
