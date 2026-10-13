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

-- Hover/press feedback for a button. colors() returns the fill for "Idle", "Hover" and "Pressed" right now
-- (it can change when the button's state changes). The button's size never changes, so layouts don't shift.
function Motion.bindButton(btn: GuiButton, colors: (string) -> Color3?)
	local hovered, pressed = false, false
	local function refresh()
		local c = colors(pressed and "Pressed" or hovered and "Hover" or "Idle")
		if c then Motion.tween(btn, "fill", Theme.Motion.Hover, { BackgroundColor3 = c }) end
	end
	btn.MouseEnter:Connect(function() hovered = true; refresh() end)
	btn.MouseLeave:Connect(function()
		hovered, pressed = false, false
		refresh()
		Motion.tween(scaleOf(btn), "press", Theme.Motion.Press, { Scale = 1 })
	end)
	btn.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA then
			pressed = true
			refresh()
			if not Motion.reduced then Motion.tween(scaleOf(btn), "press", Theme.Motion.Press, { Scale = 0.97 }) end
		end
	end)
	btn.InputEnded:Connect(function()
		pressed = false
		refresh()
		Motion.tween(scaleOf(btn), "press", Theme.Motion.Press, { Scale = 1 })
	end)
	return refresh
end

-- Window open: fade in, scale 0.98 -> 1, rise 6 px. `group` is the window's CanvasGroup, `scale` its open UIScale.
function Motion.open(group: CanvasGroup, scale: UIScale, basePos: UDim2)
	group.Visible = true
	if Motion.reduced then
		group.GroupTransparency, scale.Scale, group.Position = 0, 1, basePos
		return
	end
	group.GroupTransparency, scale.Scale = 1, 0.98
	group.Position = basePos + UDim2.fromOffset(0, 6)
	Motion.tween(group, "fade", Theme.Motion.Open, { GroupTransparency = 0, Position = basePos })
	Motion.tween(scale, "open", Theme.Motion.Open, { Scale = 1 })
end

function Motion.close(group: CanvasGroup, done: () -> ())
	local t = Motion.tween(group, "fade", Theme.Motion.Close, { GroupTransparency = 1 })
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
