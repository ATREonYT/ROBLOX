--[[
	Small world effects shared by Gameplay/PowerEffects, Juice and AuraStars, all built from plain parts so they look
	right before any effect picture is uploaded (owner: "make the usage of items smoother ... make it feel like the
	references"; docs/feel-study.md gaps 13 and 15):
	  ring    a thin glowing ring (a white core with a soft coloured glow) that grows or shrinks, made of short neon
	          pieces: a real ring, not the flat filled disc a Cylinder part gives
	  orb     a glowing ball (white core in a coloured glow, with a soft light) that follows a point
	  pop     a word or number ("+5", "CHARM WAVE") that pops up in the world, rises and fades
	  sparks  a one-off burst of particles
	  flashOk at most one bright frame a second on this screen (kid-safe), whoever causes it
	One Heartbeat loop runs every live effect (Burst.step; the offline film calls it itself). Not started on its own.
]]
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Burst = {}

Burst.WHITE = Color3.fromRGB(255, 255, 255)
Burst.PINK = Color3.fromRGB(255, 140, 230)
Burst.PURPLE = Color3.fromRGB(155, 77, 255)
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local clock = 0 -- seconds since the first effect (advanced by step, so the film and the game agree)
local live = {} -- { age, life, step(age, k), done() }
local hooked = false
local folder: Folder? = nil

local function home(): Folder
	if not (folder and folder.Parent) then
		local f = Instance.new("Folder")
		f.Name = "HuzzBursts"
		f.Parent = Workspace
		folder = f
	end
	return folder :: Folder
end
Burst.home = home

function Burst.step(dt: number)
	clock += dt
	for i = #live, 1, -1 do
		local fx = live[i]
		fx.age += dt
		local ok = pcall(fx.step, fx.age, math.clamp(fx.age / fx.life, 0, 1))
		if not ok or fx.age >= fx.life then
			table.remove(live, i)
			pcall(fx.done)
		end
	end
end

-- Runs step(age, k) every frame for `life` seconds (k goes 0 to 1), then done().
function Burst.run(life: number, step: (number, number) -> (), done: (() -> ())?)
	if not hooked then
		hooked = true
		RunService.Heartbeat:Connect(Burst.step)
	end
	table.insert(live, { age = 0, life = math.max(life, 1 / 60), step = step, done = done or function() end })
end

-- One bright frame a second at most, for the whole screen (kid-safe: never more than one flash a second).
local lastFlash = -10
function Burst.flashOk(): boolean
	if clock - lastFlash < 1 then
		return false
	end
	lastFlash = clock
	return true
end

function Burst.ease(k: number, style: string?): number
	if style == "in" then return k * k end
	if style == "quart" then return 1 - (1 - k) ^ 4 end
	if style == "back" then
		local c = 1.70158
		return 1 + (c + 1) * (k - 1) ^ 3 + c * (k - 1) ^ 2
	end
	return 1 - (1 - k) ^ 2 -- quad out
end

local function piece(color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	if shape then p.Shape = shape end
	p.Parent = home()
	return p
end
Burst.piece = piece

-- Moves many parts in one call (Workspace:BulkMoveTo: far cheaper than a CFrame write per part). Falls back to
-- setting each CFrame where BulkMoveTo is missing (the offline harness) or fails.
local bulkOk = true
local function bulkMove(parts: { BasePart }, cfs: { CFrame })
	if bulkOk then
		local ok = pcall(function()
			(Workspace :: any):BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end)
		if ok then return end
		bulkOk = false
	end
	for i, p in parts do
		p.CFrame = cfs[i]
	end
end
Burst.bulkMove = bulkMove

--[[
	A glowing ring in the XZ plane of `cf` (a flat CFrame lies on the floor; turn it to stand it up).
	o: r0, r1 (radius from, to), time, ease ("quad" | "quart" | "back" | "in"), width (the white core, studs),
	glow (the coloured glow round it), haze (optional: a wide faint purple edge under it, for the big ones), color (the glow's colour; it fades to o.edge, purple by default),
	fade (the last share of its life it fades over, default 0.45), segs, follow (a function k -> a new cf each frame).
	The core goes from white to the glow colour as it ends (white core -> pink -> purple).
]]
function Burst.ring(cf: CFrame, o: { [string]: any })
	local segs = o.segs or 24
	local cores, glows, hazes = {}, {}, {}
	for i = 1, segs do
		cores[i] = piece(Burst.WHITE)
		glows[i] = piece(o.color or Burst.PINK)
		if o.haze then hazes[i] = piece(o.edge or Burst.PURPLE) end
	end
	local color, edge = o.color or Burst.PINK, o.edge or Burst.PURPLE
	local moveParts, moveTo = {}, {} -- (every piece of this ring moves in one Workspace:BulkMoveTo a frame)
	local width, glowW = o.width or 0.18, o.glow or 0.7
	local fade = o.fade or 0.45
	local height = o.height or 0.12
	local function place(at: CFrame, k: number)
		local r = o.r0 + (o.r1 - o.r0) * Burst.ease(k, o.ease)
		r = math.max(r, 0.05)
		local len = 2 * math.pi * r / segs * 1.12
		local f = if k > 1 - fade then (k - (1 - fade)) / fade else 0 -- 0 -> 1 over the fade
		local coreColor = Burst.WHITE:Lerp(color, math.clamp(k * 1.6, 0, 1) * 0.7 + f * 0.3)
		local glowColor = color:Lerp(edge, f)
		local n = 0
		for i = 1, segs do
			local a = (i - 0.5) / segs * math.pi * 2
			local seg = at * CFrame.Angles(0, -a, 0) * CFrame.new(r, 0, 0) -- X out from the centre, Z along the ring
			n += 1
			moveParts[n], moveTo[n] = cores[i], seg
			n += 1
			moveParts[n], moveTo[n] = glows[i], seg
			cores[i].Size = Vector3.new(width, height, len)
			glows[i].Size = Vector3.new(glowW, height * 0.6, len)
			cores[i].Color, glows[i].Color = coreColor, glowColor
			cores[i].Transparency = (o.alpha or 0) + (1 - (o.alpha or 0)) * f
			glows[i].Transparency = 0.55 + 0.45 * f
			local h = hazes[i]
			if h then
				n += 1
				moveParts[n], moveTo[n] = h, seg * CFrame.new(0, -height * 0.4, 0)
				h.Size = Vector3.new(o.haze, height * 0.3, len)
				h.Transparency = 0.8 + 0.2 * f
			end
		end
		bulkMove(moveParts, moveTo)
	end
	place(cf, 0)
	Burst.run(o.time or 0.5, function(_, k)
		place(if o.follow then o.follow(k) else cf, k)
	end, function()
		for i = 1, segs do
			cores[i]:Destroy()
			glows[i]:Destroy()
			if hazes[i] then hazes[i]:Destroy() end
		end
	end)
end

--[[
	A glowing ball: a white core inside a coloured glow, with a soft PointLight. o: at (a function k -> its
	position each frame), time, size (a function k -> core size in studs), glowScale (glow size / core size),
	color, light (a function k -> Brightness), alpha (a function k -> glow transparency).
	Returns the core part (so a caller can make it bright for one frame).
]]
function Burst.orb(o: { [string]: any }): Part
	local core = piece(Burst.WHITE, Enum.PartType.Ball)
	local glow = piece(o.color or Burst.PINK, Enum.PartType.Ball)
	glow.Transparency = 0.6
	local light = Instance.new("PointLight")
	light.Color = o.color or Burst.PINK
	light.Range = o.range or 10
	light.Shadows = false
	light.Brightness = 0
	light.Parent = core
	local function place(k: number)
		local at = o.at(k)
		local s = math.max(o.size(k), 0.02)
		core.CFrame, glow.CFrame = CFrame.new(at), CFrame.new(at)
		core.Size = Vector3.one * s
		glow.Size = Vector3.one * s * (o.glowScale or 2.2)
		glow.Transparency = if o.alpha then o.alpha(k) else 0.6
		core.Transparency = if o.coreAlpha then o.coreAlpha(k) else 0
		light.Brightness = if o.light then o.light(k) else 1
	end
	place(0)
	Burst.run(o.time, function(_, k) place(k) end, function()
		core:Destroy()
		glow:Destroy()
	end)
	return core
end

--[[
	Text in the world: pops in (0.2 s Back, 0.7x to 1x), rises and fades. o: rise (studs), time, height (studs: the
	text's size), font weight, outline colour. HV's pickups: "+1" in the gem's colour.
]]
function Burst.pop(at: Vector3, text: string, color: Color3, o: { [string]: any }?)
	local opts = o or {}
	local holder = Instance.new("Part")
	holder.Name = "HuzzPop"
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch, holder.Transparency = true, false, false, false, 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(at)
	holder.Parent = home()
	local h = opts.height or 1.6
	local w = h * math.max(2, #text * 0.62)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(w * 0.7, 0, h * 0.7, 0)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = opts.onTop == true
	gui.MaxDistance = opts.maxDistance or 120
	gui.Parent = holder
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", opts.weight or Enum.FontWeight.Heavy)
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = opts.stroke or 2.5
	stroke.Color = opts.outline or Color3.fromRGB(20, 14, 40)
	stroke.Parent = label
	local life, rise = opts.time or 0.9, opts.rise or 2.4
	Burst.run(life, function(age, k)
		local pop = math.clamp(age / 0.2, 0, 1)
		local s = 0.7 + 0.3 * Burst.ease(pop, "back")
		gui.Size = UDim2.new(w * s, 0, h * s, 0)
		gui.StudsOffsetWorldSpace = Vector3.new(0, rise * Burst.ease(k), 0)
		local f = math.clamp((k - 0.62) / 0.38, 0, 1)
		label.TextTransparency, stroke.Transparency = f, f
	end, function() holder:Destroy() end)
end

--[[
	A one-off burst of particles at a spot. o: texture, glow (LightEmission), life, speed, spread, gravity, drag,
	size (NumberSequence).
]]
function Burst.sparks(at: Vector3, colors: { Color3 }, count: number, o: { [string]: any }?)
	local opts = o or {}
	local holder = Instance.new("Part")
	holder.Name = "HuzzSparks"
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch, holder.Transparency = true, false, false, false, 1
	holder.Size = Vector3.one
	holder.CFrame = CFrame.new(at)
	holder.Parent = home()
	for _, c in colors do
		local e = Instance.new("ParticleEmitter")
		e.Texture = opts.texture or SPARK
		e.Color = ColorSequence.new(Burst.WHITE, c)
		e.LightEmission = opts.glow or 0.6
		e.Rate = 0
		e.Lifetime = opts.life or NumberRange.new(0.5, 0.9)
		e.Speed = opts.speed or NumberRange.new(8, 14)
		e.SpreadAngle = opts.spread or Vector2.new(180, 180)
		e.EmissionDirection = Enum.NormalId.Top
		e.Acceleration = opts.gravity or Vector3.new(0, -12, 0)
		e.Drag = opts.drag or 3
		e.RotSpeed = NumberRange.new(-200, 200)
		e.Rotation = NumberRange.new(0, 360)
		e.Size = opts.size or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) })
		e.Parent = holder
		e:Emit(math.max(1, math.floor(count / #colors)))
	end
	task.delay(2.2, function() holder:Destroy() end)
end

return Burst
