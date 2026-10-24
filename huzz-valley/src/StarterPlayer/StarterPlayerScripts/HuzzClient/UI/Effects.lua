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

-- A slow rock from side to side (a crate in the Shop, owner Oct 20 20:34: "animate the ui more"): `degrees` each way
-- (default 3) over `seconds` per swing (default 1.4), on the picture's own Rotation. Calm: it stands still.
function Effects.rock(inst: GuiObject, opts: { degrees: number?, seconds: number?, delay: number? }?)
	local o = opts or {}
	local d = o.degrees or 3
	inst.Rotation = -d
	local tween = TweenService:Create(inst, TweenInfo.new(o.seconds or 1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, o.delay or 0), { Rotation = d })
	track(inst, tween, function()
		tween:Cancel()
		inst.Rotation = 0
	end, function()
		inst.Rotation = -d
		tween:Play()
	end)
end

-- Little bits of a knife's element floating up over a card's picture (owner, Oct 19: "better knife animations ... in
-- the gamepass sections"): `count` small shapes in `colour` (shape "petal": soft ovals, "diamond": sparkles or ice,
-- "dot": embers or moon dust), each rising `rise` px over 2.6 to 3.8 s while it fades, staggered, again and again.
-- Plain frames (no picture to upload), saved into StarterGui like the rest, hidden until the loop starts. `area`: the
-- box they float in (offsets inside `target`). Calm: a few at a time, nothing flashes.
function Effects.motes(target: GuiObject, opts: { colour: Color3, shape: string?, count: number?, area: Rect, rise: number?, z: number?, seed: number? })
	local o = opts
	local n = o.count or 6
	local area = o.area
	local seed = o.seed or 1
	local made = {}
	for i = 1, n do
		-- the same spots every build (so the saved twins match): a little hash of i and the seed
		local h = ((i * 7919 + seed * 104729) % 1000) / 1000
		local h2 = ((i * 3571 + seed * 1299709) % 1000) / 1000
		local shape = o.shape or "dot"
		local w, hgt = 4, 4
		if shape == "petal" then w, hgt = 8, 5 elseif shape == "diamond" then w, hgt = 6, 6 elseif h2 > 0.6 then w, hgt = 4, 4 else w, hgt = 5, 5 end
		local x = math.floor(area.Min.X + h * (area.Width - w))
		local y0 = math.floor(area.Max.Y - 8 - h2 * area.Height * 0.4)
		local mote = new("Frame", {
			Name = "Mote" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y0), Size = UDim2.fromOffset(w, hgt),
			BackgroundColor3 = o.colour, BackgroundTransparency = 1, BorderSizePixel = 0, Active = false, Visible = false,
			Rotation = if shape == "diamond" then 45 elseif shape == "petal" then math.floor(h * 90) - 45 else 0,
			ZIndex = o.z or (target.ZIndex + 1), Parent = target,
		}, if shape == "diamond" then {} else { Kit.corner(4) })
		local rise = o.rise or math.floor(area.Height * 0.55)
		local seconds = 2.6 + h2 * 1.2
		local drift = math.floor((h - 0.5) * 16)
		local tween = TweenService:Create(mote, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, -1, false, 0.4 + h * 1.4), {
			Position = UDim2.fromOffset(x + drift, y0 - rise), BackgroundTransparency = 1,
			Rotation = mote.Rotation + (if shape == "petal" then 120 else 0),
		})
		local startRot = mote.Rotation
		track(mote, tween, function()
			tween:Cancel()
			mote.Visible = false
		end, function()
			mote.Position, mote.Rotation, mote.BackgroundTransparency, mote.Visible = UDim2.fromOffset(x, y0), startRot, 0.15, true
			task.delay(h2 * 2, function()
				if not calm and mote.Parent then tween:Play() end
			end)
		end)
		table.insert(made, mote)
	end
	return made
end

-- A soft glow in a knife's colour that slowly swells and settles over a card's picture (one breath about every 5 s,
-- never brighter than 0.78 see-through: a glow, not a flash).
function Effects.pulse(target: GuiObject, opts: { colour: Color3, size: UDim2?, position: UDim2?, corner: number?, z: number? })
	local o = opts
	local glow = new("Frame", {
		Name = "Pulse", Position = o.position or UDim2.fromOffset(0, 0), Size = o.size or UDim2.fromScale(1, 1),
		BackgroundColor3 = o.colour, BackgroundTransparency = 1, BorderSizePixel = 0, Active = false, Visible = false,
		ZIndex = o.z or (target.ZIndex + 1), Parent = target,
	}, {
		Kit.corner(o.corner or 0),
		new("UIGradient", { Name = "Soft", Rotation = 90, Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, 0.55), NumberSequenceKeypoint.new(0.7, 0.4), NumberSequenceKeypoint.new(1, 1),
		}) }),
	})
	local tween = TweenService:Create(glow, TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.78 })
	track(glow, tween, function()
		tween:Cancel()
		glow.BackgroundTransparency, glow.Visible = 1, false
	end, function()
		glow.BackgroundTransparency, glow.Visible = 1, true
		tween:Play()
	end)
	return glow
end

-- A card lifts a little (to 104 %) while the mouse is over it, and settles back when it leaves.
function Effects.lift(card: GuiObject, scale: number?)
	local s = new("UIScale", { Name = "Lift", Scale = 1, Parent = card })
	local up = TweenService:Create(s, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = scale or 1.04 })
	local down = TweenService:Create(s, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
	pcall(function()
		card.MouseEnter:Connect(function() if not calm then up:Play() end end)
		card.MouseLeave:Connect(function() down:Play() end)
	end)
	return s
end

return Effects
