-- Motion for UIKit pieces: press/hover feel, popups, count-ups, shine sweeps, toasts, wobbles. Client only.
-- Timings come from the UI research (research_notes/.../ui_visual_design.md, motion table):
--   hover 0.12-0.15 s Quad Out to 1.05 | press 0.06-0.10 s to 0.94 with the body dropping onto its lip
--   release overshoot to 1.06 then settle, Back Out | popup open 0.22-0.30 s Back Out from 0.8 | close 0.12-0.18 s Quad In
-- One owner per property: every helper here tweens its own UIScale/props and cancels its previous tween.
local TweenService = game:GetService('TweenService')

local Motion = {}
Motion.Time = { hover = 0.13, press = 0.07, release = 0.2, open = 0.26, close = 0.15, pop = 0.15 }

local running = setmetatable({}, { __mode = 'k' })
-- Tween inst's props, replacing any tween this module started on the same instance.
local function tween(inst, time, style, dir, props)
	local old = running[inst]
	if old then old:Cancel() end
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	running[inst] = t
	t:Play()
	return t
end
Motion.tween = tween

local function scaleOf(gui)
	local s = gui:FindFirstChild('MotionScale')
	if not s then
		s = Instance.new('UIScale')
		s.Name = 'MotionScale'
		s.Parent = gui
	end
	return s
end
Motion.scaleOf = scaleOf

-- Press feel for a Kit.button holder. onClick runs on Activated (mouse, touch and gamepad).
function Motion.button(holder, onClick)
	local hit, body = holder:FindFirstChild('Hit'), holder:FindFirstChild('Body')
	local lip = holder:GetAttribute('Lip') or 6
	local s = scaleOf(holder)
	local up, down = UDim2.new(), UDim2.fromOffset(0, lip - 1)
	local hovering, pressed = false, false
	local function settle()
		if pressed then return end
		tween(s, Motion.Time.hover, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Scale = hovering and 1.05 or 1 })
	end
	hit.MouseEnter:Connect(function() hovering = true; settle() end)
	hit.MouseLeave:Connect(function()
		hovering = false
		if pressed then
			pressed = false
			tween(body, Motion.Time.release, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Position = up })
		end
		settle()
	end)
	hit.MouseButton1Down:Connect(function()
		pressed = true
		tween(body, Motion.Time.press, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Position = down })
		tween(s, Motion.Time.press, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Scale = 0.94 })
	end)
	hit.MouseButton1Up:Connect(function()
		if not pressed then return end
		pressed = false
		tween(body, Motion.Time.release, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Position = up })
		-- Overshoot, then settle back to the hover/rest size.
		local t = tween(s, Motion.Time.release * 0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Scale = 1.07 })
		t.Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed then
				tween(s, Motion.Time.release, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = hovering and 1.05 or 1 })
			end
		end)
	end)
	if onClick then hit.Activated:Connect(onClick) end
	return hit
end

-- Popup in: backdrop fades to its dim level while the panel springs up from 0.8.
function Motion.open(overlay, panel, dim)
	overlay.Visible = true
	overlay.BackgroundTransparency = 1
	tween(overlay, Motion.Time.open * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { BackgroundTransparency = dim or 0.5 })
	local s = scaleOf(panel)
	s.Scale = 0.8
	return tween(s, Motion.Time.open, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })
end
function Motion.close(overlay, panel, onClosed)
	tween(overlay, Motion.Time.close, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { BackgroundTransparency = 1 })
	local t = tween(scaleOf(panel), Motion.Time.close, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { Scale = 0.85 })
	t.Completed:Once(function()
		overlay.Visible = false
		if onClosed then onClosed() end
	end)
	return t
end

-- A quick scale pop (currency icon when the number changes, a card when selected).
function Motion.pop(gui, amount)
	local s = scaleOf(gui)
	local t = tween(s, Motion.Time.pop * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Scale = 1 + (amount or 0.22) })
	t.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed then tween(s, Motion.Time.pop * 1.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 }) end
	end)
end

-- Tick a label's number from one value to another; format(n) builds the text (UIKit.short by default).
local counters = setmetatable({}, { __mode = 'k' })
function Motion.countTo(label, from, to, duration, format)
	format = format or function(n) return tostring(math.floor(n + 0.5)) end
	local v = counters[label]
	if not v then
		v = Instance.new('NumberValue')
		v.Changed:Connect(function(n) label.Text = format(n) end)
		counters[label] = v
	end
	v.Value = from
	return tween(v, duration or 0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, { Value = to })
end

-- A diagonal light band sweeping across gui every `every` seconds (primary buttons, Legendary+ cards only).
function Motion.shine(gui, every, radius)
	local band = Instance.new('Frame')
	band.Name = 'Shine'
	band.BackgroundColor3 = Color3.new(1, 1, 1)
	band.BorderSizePixel = 0
	band.Size = UDim2.fromScale(1, 1)
	band.ZIndex = gui.ZIndex + 1
	local c = Instance.new('UICorner')
	c.CornerRadius = radius or UDim.new(0, 12)
	c.Parent = band
	local g = Instance.new('UIGradient')
	g.Rotation = 25
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, 0.45),
		NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1),
	})
	g.Offset = Vector2.new(-1, 0)
	g.Parent = band
	band.Parent = gui
	local alive = true
	task.spawn(function()
		while alive and band.Parent do
			g.Offset = Vector2.new(-1, 0)
			TweenService:Create(g, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Offset = Vector2.new(1, 0) }):Play()
			task.wait(every or 3.5)
		end
	end)
	return function() alive = false; band:Destroy() end
end

-- Slide a toast in from above, hold, slide out and destroy it.
function Motion.toast(toast, hold)
	local target = toast.Position
	toast.Position = target - UDim2.fromOffset(0, 24)
	local s = scaleOf(toast)
	s.Scale = 0.85
	tween(toast, 0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Position = target })
	tween(s, 0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })
	task.delay(hold or 2.5, function()
		if not toast.Parent then return end
		local t = tween(toast, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { Position = target - UDim2.fromOffset(0, 24) })
		tween(s, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { Scale = 0.8 })
		t.Completed:Once(function() toast:Destroy() end)
	end)
end

-- Looping idle motion: a notification badge wobbles, a tutorial arrow bobs.
function Motion.wobble(gui, degrees, period)
	local t = TweenService:Create(gui, TweenInfo.new((period or 0.9) / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = degrees or 8 })
	gui.Rotation = -(degrees or 8)
	t:Play()
	return t
end
function Motion.bob(gui, pixels, period)
	local base = gui.Position
	local t = TweenService:Create(gui, TweenInfo.new((period or 0.7) / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = base - UDim2.fromOffset(0, pixels or 10) })
	t:Play()
	return t
end

return Motion
