-- Living UI (owner: "make the ui have more effects, like shining, spinning, whatever, because plain ui looks bad ...
-- like in the game pass sections, in the ui in general"). Three small loops, each a repeating tween Roblox runs by itself:
--   shine(target)  a soft white streak sweeps across a button or card, then rests (at least 3 s apart: no flashing);
--   rays(parent)   light rays turn slowly behind a featured picture (Shop icon, the Spin wheel);
--   spin / breathe a picture turns, or a tag gently grows and shrinks, to draw the eye (the free spin).
-- The parts are built by Kit like everything else (so they are saved into StarterGui and reused by name), but they are
-- hidden (Visible off, so they never get in the way of clicking things in Studio) until the loop starts at runtime.
-- Reduced Motion stops every loop and hides the shine and rays. Nothing here may sit inside a CanvasGroup window: a
-- CanvasGroup redraws its whole picture whenever a child moves (the old lag), so those windows are built Flat.
local TweenService = game:GetService("TweenService")
local Kit = require(script.Parent.Kit)
local new = Kit.new

local Effects = {}

-- Every running loop: { tween, stop, play }. A plain list (never keyed by Instance); entries leave when their part goes.
local loops = {}
local calm = false

local function track(inst: Instance, tween: Tween, onStop: () -> (), onPlay: () -> ())
	local entry = { tween = tween, stop = onStop, play = onPlay }
	table.insert(loops, entry)
	if calm then onStop() else onPlay() end
	inst.Destroying:Connect(function()
		tween:Cancel()
		local i = table.find(loops, entry)
		if i then table.remove(loops, i) end
	end)
end

-- Reduced Motion on: every loop stops and its streak or rays hide. Off: they start again.
function Effects.setCalm(on: boolean)
	if on == calm then return end
	calm = on
	for _, e in loops do
		if on then e.stop() else e.play() end
	end
end

-- A soft white streak that sweeps across `target` every `every` seconds (default 4). The streak is a white frame the
-- size of the target with the target's corner, shown only along a moving gradient band, so it stays inside rounded
-- corners without clipping. `delay` staggers rows so they don't all shine together.
function Effects.shine(target: GuiObject, opts: { every: number?, delay: number?, corner: number?, strength: number?, z: number? }?)
	local o = opts or {}
	local peak = 1 - (o.strength or 0.45) -- (0.55 see-through at the brightest point)
	local streak = new("Frame", {
		Name = "Shine", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0, Visible = false, -- hidden until the loop runs
		BorderSizePixel = 0, Active = false, ZIndex = o.z or (target.ZIndex + 1), Parent = target,
	}, {
		Kit.corner(o.corner or 0),
		new("UIGradient", {
			Name = "Band", Rotation = 20, Offset = Vector2.new(-1, 0),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 1), NumberSequenceKeypoint.new(0.47, 0.85),
				NumberSequenceKeypoint.new(0.5, peak), NumberSequenceKeypoint.new(0.53, 0.85), NumberSequenceKeypoint.new(0.6, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	local band = streak:FindFirstChild("Band") :: UIGradient
	band.Offset = Vector2.new(-1, 0)
	local rest = math.max(3, o.every or 4) - 0.9
	local tween = TweenService:Create(band, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, rest), { Offset = Vector2.new(1, 0) })
	track(streak, tween, function()
		tween:Cancel()
		band.Offset = Vector2.new(-1, 0)
		streak.Visible = false
	end, function()
		streak.BackgroundTransparency, streak.Visible = 0, true
		band.Offset = Vector2.new(-1, 0)
		task.delay(o.delay or 0, function()
			if not calm and streak.Parent then tween:Play() end
		end)
	end)
	return streak
end

-- Light rays turning slowly behind a picture: one turn every `seconds` (default 14). `size` is the rays' width in
-- pixels, centred on `centre` inside `parent`; give it a ZIndex below the picture's.
function Effects.rays(parent: GuiObject, centre: UDim2, size: number, opts: { color: Color3?, transparency: number?, seconds: number?, z: number?, name: string? }?)
	local o = opts or {}
	local img = Kit.art("LightRays", {
		Name = o.name or "Rays", AnchorPoint = Vector2.new(0.5, 0.5), Position = centre, Size = UDim2.fromOffset(size, size),
		ScaleType = Enum.ScaleType.Stretch, ImageColor3 = o.color or Color3.new(1, 1, 1),
		ImageTransparency = 1, Visible = false, -- shown when the loop starts
		ZIndex = o.z or parent.ZIndex, Parent = parent,
	})
	local shown = o.transparency or 0.45
	img.Rotation = 0
	local tween = TweenService:Create(img, TweenInfo.new(o.seconds or 14, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 })
	track(img, tween, function()
		tween:Cancel()
		img.ImageTransparency, img.Rotation = 1, 0
	end, function()
		img.ImageTransparency, img.Visible = shown, true
		tween:Play()
	end)
	return img
end

-- A picture that turns round and round (one turn every `seconds`) while `on()` says so; checked once a second.
function Effects.spin(img: GuiObject, seconds: number, on: () -> boolean)
	local tween = TweenService:Create(img, TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 })
	local playing = false
	local function set(go: boolean)
		if go == playing then return end
		playing = go
		if go then
			img.Rotation = 0
			tween:Play()
		else
			tween:Cancel()
			img.Rotation = 0
		end
	end
	track(img, tween, function() set(false) end, function() set(on()) end)
	task.spawn(function()
		while img.Parent do
			set(not calm and on())
			task.wait(1)
		end
	end)
end

-- A slow grow-and-shrink (to 108 %, about once every 1.6 s) for a tag or badge that wants attention.
function Effects.breathe(inst: GuiObject, opts: { scale: number?, seconds: number? }?)
	local o = opts or {}
	local s = new("UIScale", { Name = "Breathe", Scale = 1, Parent = inst })
	local tween = TweenService:Create(s, TweenInfo.new(o.seconds or 0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = o.scale or 1.08 })
	track(s, tween, function()
		tween:Cancel()
		s.Scale = 1
	end, function()
		tween:Play()
	end)
	return s
end

return Effects
