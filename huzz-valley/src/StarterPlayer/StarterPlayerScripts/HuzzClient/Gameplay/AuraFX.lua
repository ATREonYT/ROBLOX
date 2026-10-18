--[[
	Builds a girl's effects (Shared/AuraLook data) on a character or a model, on this screen only (every
	client builds them for everyone it can see, so nothing heavy goes over the network):
	  - ParticleEmitters on Attachments at her hands / body / head / feet, or from the floor pool's area ("Ground");
	  - the girls' layers (AuraLook.girl, Oct 18: "they just float there, they dont have good graphics"), none of
	    which wait for an uploaded picture:
	      a light pool + crisp rings flat on the floor under her feet (a thin part with a SurfaceGui of round
	      Frames and UIStrokes; it follows her feet, swells as she breathes, a highlight runs round the ring),
	      a ring running out over the floor on each beat, flame tongues hugging her from behind (Beams drawn behind
	      her body: ZOffset pushes them away from the camera, so they never cover her face), orbiting lights
	      (small neon balls with Trails), trails on her feet and hands only while she moves, a halo (Secret);
	  - a PointLight, and crescent slashes (two Beams each: a bright core over a dark edge, bent into an arc
	    with CurveSize, swept round and faded every frame by step()); the girls' slashes come on the beat.
	Per frame nothing new is made: positions are set as Vector3s, sizes as numbers; the rest is built once.
	Her own parts are never touched, and our parts live in Workspace.HuzzAuraFX (not in her model, so her
	bounding box, which GirlService and the Secret cutscene measure, doesn't change). While the Secret cutscene
	flies her (her HuzzRevealing attribute) the floor layers hide.
	AuraFX.attach(model, spec, opts) -> handle { step(dt), setEnabled(on), destroy() }. Not started on its own:
	Gameplay/Auras uses it. opts.lite (other players' and the round's girls): fewer particles, flames and orbs, no
	white cores, no light. opts.ground = false: no floor layers (the girl being carried).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AuraLook = require(Shared.AuraLook)
local FxTexture = require(Shared.FxTexture) -- (our pictures once uploaded; Roblox's stand-ins until then)

local AuraFX = {}

local WHITE = Color3.new(1, 1, 1)
local UP = Vector3.new(0, 1, 0)

-- A part's position as a Vector3 (no new CFrame each frame in the game). The offline harness (Lune) can't read
-- or write .Position on parts, so there it goes through CFrame.
local POSITION_OK = pcall(function() return Instance.new("Part").Position end)
local function getPos(p: BasePart): Vector3
	return if POSITION_OK then p.Position else p.CFrame.Position
end
local function setPos(p: BasePart, v: Vector3)
	if POSITION_OK then p.Position = v else p.CFrame = CFrame.new(v) end
end

local function colorSeq(list)
	local keys = {}
	for _, k in list do
		table.insert(keys, ColorSequenceKeypoint.new(k[1], k[2]))
	end
	return ColorSequence.new(keys)
end

local function numberSeq(list, mult)
	local keys = {}
	for _, k in list do
		table.insert(keys, NumberSequenceKeypoint.new(k[1], k[2] * (mult or 1), (k[3] or 0) * (mult or 1)))
	end
	return NumberSequence.new(keys)
end

local function find(model, ...)
	for _, name in { ... } do
		local p = model:FindFirstChild(name, true)
		if p and p:IsA("BasePart") then
			return p
		end
	end
	return nil
end

-- Where each anchor is on this model: a part and an offset (R15 and R6 both).
local function anchor(model, at, scale)
	if at == "RightHand" then
		local hand = find(model, "RightHand")
		if hand then return hand, CFrame.identity end
		local arm = find(model, "Right Arm")
		return arm, CFrame.new(0, -(arm and arm.Size.Y or 2) * 0.45, 0)
	elseif at == "LeftHand" then
		local hand = find(model, "LeftHand")
		if hand then return hand, CFrame.identity end
		local arm = find(model, "Left Arm")
		return arm, CFrame.new(0, -(arm and arm.Size.Y or 2) * 0.45, 0)
	elseif at == "Head" then
		return find(model, "Head"), CFrame.identity
	elseif at == "Feet" or at == "Ground" then
		local root = find(model, "HumanoidRootPart", "LowerTorso", "Torso")
		return root, CFrame.new(0, -2.6 * scale, 0)
	end
	return find(model, "UpperTorso", "Torso", "HumanoidRootPart"), CFrame.identity
end

-- Our own parts (floor pool, rings, orbiting lights) live here, outside her model.
local function fxFolder()
	local f = Workspace:FindFirstChild("HuzzAuraFX")
	if not f then
		f = Instance.new("Folder")
		f.Name = "HuzzAuraFX"
		f.Parent = Workspace
	end
	return f
end

local function plainPart(name, size)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Massless = true
	p.Transparency = 1
	p.Size = size
	p.Material = Enum.Material.SmoothPlastic
	return p
end

-- A flat round picture made of Frames on a SurfaceGui: it scales with its part, so a swell is just a new size.
local function surface(part, face, brightness)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "HuzzAuraGui"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(256, 256)
	gui.LightInfluence = 0
	gui.Brightness = brightness
	gui.AlwaysOnTop = false
	gui.ClipsDescendants = false
	gui.Parent = part
	return gui
end
local function circle(parent, scale, color, transparency)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromScale(scale, scale)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency
	f.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = f
	f.Parent = parent
	return f
end
local function ring(parent, scale, color, transparency, thickness)
	local f = circle(parent, scale, color, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = transparency
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = f
	return f, stroke
end

-- An attachment frame whose X axis points along d (a Beam bends along its attachments' X axes).
local function xFrame(d)
	local side = Vector3.new(-d.Z, 0, d.X)
	if side.Magnitude < 0.01 then
		side = Vector3.new(0, 0, 1)
	end
	return CFrame.fromMatrix(Vector3.zero, d, side.Unit:Cross(d).Unit)
end

-- How far below her root her feet are, and how far above it her head's top is (body parts only).
local function measure(model, root, scale)
	local low, high = math.huge, -math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root and d.Name ~= "HumanoidRootPart" and not d:FindFirstAncestorOfClass("Accessory") then
			local y, h = getPos(d).Y, d.Size.Y / 2
			low, high = math.min(low, y - h), math.max(high, y + h)
		end
	end
	local ry = getPos(root).Y
	local drop = if low < math.huge and ry - low > 0.2 * scale then ry - low else 2.6 * scale
	local top = if high > -math.huge and high - ry > 0.2 * scale then high - ry else 2.2 * scale
	return drop, top
end

function AuraFX.attach(model, spec, opts)
	local lite = opts and opts.lite == true
	local wantGround = not (opts and opts.ground == false)
	local scale = spec.scale or 1
	-- The big showcase girl over the map (scale > 1.5) glows far less (owner: "too much light shining down"): her
	-- light stays small and soft, and her effects add less light (bloom makes bright particles flare).
	local big = scale > 1.5
	local glow = if big then 0.45 else 1
	local made = {}
	local emitters = {}
	local groundEmitters = {}
	local strideEmitters = {}
	local beats = {}
	local burst = nil
	local function keep(inst)
		table.insert(made, inst)
		return inst
	end
	local folder = fxFolder()
	local root = find(model, "HumanoidRootPart", "LowerTorso", "Torso")
	local body = anchor(model, "Body", scale)
	local head = find(model, "Head")
	local drop, top = 2.6 * scale, 2.2 * scale
	if root then
		drop, top = measure(model, root, scale)
	end
	local feet = {}
	for _, pair in { { "LeftFoot", "Left Leg" }, { "RightFoot", "Right Leg" } } do
		local f = find(model, pair[1], pair[2])
		if f then table.insert(feet, f) end
	end

	-- The floor pool and its rings (a thin part with a SurfaceGui on top), and the ring that runs out on the beat.
	local G = if wantGround and root then spec.ground else nil
	local pool, poolGui, runner, shock, shockGui, shockStroke = nil, nil, nil, nil, nil, nil
	local poolRadius = 0
	if G then
		poolRadius = G.radius * scale
		local stand = model:FindFirstChild("StandTop") -- (the prize's stand, GirlService.showcase: the pool lights its top)
		if stand and stand:IsA("BasePart") then
			poolRadius = math.min(poolRadius, stand.Size.Z / 2 * 1.1)
		end
		local d = poolRadius * 2
		pool = keep(plainPart("HuzzAuraPool", Vector3.new(d, 0.05, d)))
		pool.CFrame = CFrame.new(getPos(root) - Vector3.new(0, drop - 0.04, 0))
		poolGui = surface(pool, Enum.NormalId.Top, 1.4 * glow)
		local white, main, deep = G.colors[1], G.colors[2], G.colors[3]
		if G.pool then
			local sizes = { 1, 0.7, 0.42 }
			local tones = { deep:Lerp(main, 0.5), main, white }
			for i, tr in G.pool do
				circle(poolGui, sizes[i] * 0.9, tones[i], tr)
			end
		end
		if G.ring then
			local _, stroke = ring(poolGui, 0.88, main, G.ring, 7)
			if G.runner then -- a highlight running round the ring (the gradient turns; white into her colours)
				stroke.Color = WHITE -- (the gradient's colours show as they are)
				runner = Instance.new("UIGradient")
				runner.Color = colorSeq({ { 0, WHITE }, { 0.3, main }, { 0.7, G.accent or main }, { 1, WHITE } })
				runner.Transparency = numberSeq({ { 0, 0 }, { 0.35, 0.55 }, { 0.65, 0.55 }, { 1, 0 } })
				runner.Parent = stroke
			end
		end
		if G.inner then
			ring(poolGui, 0.6, white, math.min(1, (G.ring or 0.4) + 0.3), 3)
		end
		pool.Parent = folder
		if spec.beat and spec.beat.shock then
			shock = keep(plainPart("HuzzAuraShock", Vector3.new(d, 0.05, d)))
			shock.CFrame = pool.CFrame
			shockGui = surface(shock, Enum.NormalId.Top, 1.6 * glow)
			local _, stroke = ring(shockGui, 0.96, white:Lerp(main, 0.4), 1, 10)
			shockStroke = stroke
			shockGui.Enabled = false
			shock.Parent = folder
		end
	end

	for _, e in spec.emitters do
		local skip = lite and (string.sub(e.name, 1, 4) == "Core" or string.sub(e.name, 1, 5) == "Shard")
		-- Shapes that only work as our own pictures (a magic circle, a ring, a halo, lightning) wait for the upload:
		-- Roblox's stand-in sparkle would lie under you as a big blob.
		if (e.orient == "Flat" or e.texture == "Bolt") and not FxTexture.ready(e.texture) then skip = true end
		local onGround = e.at == "Ground" and pool ~= nil
		local part, offset = anchor(model, e.at, scale)
		if (part or onGround) and not skip then
			local p = Instance.new("ParticleEmitter")
			p.Name = e.name
			if e.flip then FxTexture.flipbook(p, e.texture, e.flip, e.fps) else p.Texture = FxTexture.get(e.texture) end
			p.Color = colorSeq(e.colors)
			p.LightEmission = e.light * glow
			p.LightInfluence = if e.light > 0.5 then 0 else 1
			p.Rate = e.rate * (if lite then 0.5 else 1)
			p.Lifetime = NumberRange.new(e.life[1], e.life[2])
			p.Speed = NumberRange.new(e.speed[1] * scale, e.speed[2] * scale)
			p.SpreadAngle = Vector2.new(e.spread, e.spread)
			p.Size = numberSeq(e.size, scale)
			p.Transparency = numberSeq(e.alpha)
			p.Acceleration = Vector3.new(e.accel[1], e.accel[2], e.accel[3]) * scale
			p.Drag = e.drag or 0
			p.Rotation = NumberRange.new(e.rot[1], e.rot[2])
			p.RotSpeed = NumberRange.new(e.spin[1], e.spin[2])
			p.ZOffset = (e.z or 0) * scale
			p.VelocityInheritance = e.inherit or 0
			p.Brightness = e.bright or 1
			if e.squash then p.Squash = numberSeq(e.squash) end
			if e.locked then p.LockedToPart = true end
			if e.orient == "Flat" then
				-- lies flat on the ground (or level over the head): a sigil or a halo (docs/vfx-guide.md 2.1)
				p.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
				p.EmissionDirection = Enum.NormalId.Top
				p.Speed = NumberRange.new(0.01)
				p.SpreadAngle = Vector2.zero
				p.Acceleration = Vector3.zero
				p.LockedToPart = true
			elseif e.orient == "Streak" then
				p.Orientation = Enum.ParticleOrientation.VelocityParallel
			end
			if e.every then -- bursts on a beat (step) instead of a steady rate
				p.Rate = 0
				table.insert(beats, { emitter = p, every = e.every, count = e.count or 1, next = math.random() * e.every })
			elseif e.stride then -- puffs as she walks (step counts the studs)
				p.Rate = 0
				table.insert(strideEmitters, { emitter = p, stride = e.stride * scale, count = e.count or 1 })
			end
			if e.name == "Burst" then
				burst = p
			end
			if onGround then
				-- from the floor pool's area, going up (a ParticleEmitter in a part fills the part's box)
				p.EmissionDirection = Enum.NormalId.Top
				p.Parent = pool
				table.insert(groundEmitters, p)
			else
				local att = keep(Instance.new("Attachment"))
				att.Name = "HuzzAura" .. e.name
				att.CFrame = offset * CFrame.new(0, (e.offset or 0) * scale, 0)
				att.Parent = part
				p.Parent = att
			end
			table.insert(emitters, p)
		end
	end

	local light = nil
	if spec.light and body and not lite then
		light = keep(Instance.new("PointLight"))
		light.Name = "HuzzAuraLight"
		light.Color = spec.light.color
		light.Brightness = spec.light.brightness * (if big then 0.3 else 1)
		light.Range = if big then math.min(spec.light.range * 1.3, 10) else spec.light.range * scale
		light.Shadows = false
		light.Parent = body
	end
	local lightBase = light and light.Brightness or 0

	-- Flame tongues hugging her from behind: Beams from her feet to over her head, bent outward (AuraLook.flameAt).
	local flames = {}
	local F = if root then spec.flames else nil
	if F then
		local white, main, accent, deep = F.colors[1], F.colors[2], F.colors[3], F.colors[4] or F.colors[2]
		local soft = FxTexture.ready("BeamGlow") -- (soft edges once the owner's beam picture is uploaded)
		local outerAlpha = numberSeq({ { 0, 1 }, { 0.15, 0.4 }, { 0.5, 0.45 }, { 0.85, 0.7 }, { 1, 1 } })
		local coreAlpha = numberSeq({ { 0, 1 }, { 0.15, 0.35 }, { 0.6, 0.5 }, { 1, 1 } })
		local function tongues(core)
			local n = if core then F.core else F.count
			if lite then n = if core then 0 else math.ceil(n / 2) end
			for i = 1, n do
				local d0, d1 = AuraLook.flameDirs(F, i, core)
				local a0, a1 = keep(Instance.new("Attachment")), keep(Instance.new("Attachment"))
				a0.Name, a1.Name = "HuzzFlameA" .. i, "HuzzFlameB" .. i
				a0.CFrame, a1.CFrame = xFrame(d0), xFrame(d1)
				a0.Parent, a1.Parent = root, root
				local b = keep(Instance.new("Beam"))
				b.Name = if core then "HuzzFlameCore" .. i else "HuzzFlame" .. i
				b.Attachment0, b.Attachment1 = a0, a1
				local tone = if i % 2 == 0 then accent else main
				b.Color = if core then colorSeq({ { 0, WHITE }, { 1, white } })
					else colorSeq({ { 0, tone:Lerp(WHITE, 0.25) }, { 0.55, tone }, { 1, tone:Lerp(deep, 0.45) } })
				b.Transparency = if core then coreAlpha else outerAlpha
				b.LightEmission = (if core then 1 else 0.35) * glow -- (her colour stays her colour in daylight)
				b.LightInfluence = 0
				b.Brightness = 1.2
				b.FaceCamera = true
				b.Segments = 14
				-- behind her body from every side (pushed away from the camera past her far side)
				b.ZOffset = -(F.radius * (F.behind or (if core then 1.2 else 1.5))) * scale
				if soft then
					b.Texture = FxTexture.get("BeamGlow")
					b.TextureMode = Enum.TextureMode.Stretch
					b.TextureLength = 1
				end
				b.Parent = root
				table.insert(flames, { a0 = a0, a1 = a1, beam = b, i = i, core = core })
			end
		end
		tongues(false)
		tongues(true)
	end

	-- Orbiting lights: small neon balls with a trail behind each (AuraLook.orbitAt).
	local orbs = {}
	local O = spec.orbs
	if O and body then
		local count = if lite then math.max(1, math.floor(O.count / 2)) else O.count
		for i = 1, count do
			local colors = if O.colors2 and i % 2 == 0 then O.colors2 else O.colors
			local s = (if O.ball then O.size else O.size * 0.25) * scale -- (older looks give the glow's size)
			local ball = keep(plainPart("HuzzOrb" .. i, Vector3.new(s, s, s)))
			ball.Shape = Enum.PartType.Ball
			ball.Material = Enum.Material.Neon
			ball.Color = colors[2]:Lerp(WHITE, 0.55)
			ball.Transparency = 0
			ball.CFrame = CFrame.new(getPos(body))
			local topA, bottomA = keep(Instance.new("Attachment")), keep(Instance.new("Attachment"))
			topA.Name, bottomA.Name = "HuzzOrbTop" .. i, "HuzzOrbBottom" .. i
			topA.Position, bottomA.Position = Vector3.new(0, s * 0.45, 0), Vector3.new(0, -s * 0.45, 0)
			topA.Parent, bottomA.Parent = ball, ball
			local trail = keep(Instance.new("Trail"))
			trail.Name = "HuzzOrbTrail" .. i
			trail.Attachment0, trail.Attachment1 = topA, bottomA
			if FxTexture.ready("Streak") then -- (a plain glowing ribbon until our streak picture is uploaded)
				trail.Texture = FxTexture.get("Streak")
				trail.TextureMode = Enum.TextureMode.Stretch
			end
			trail.Color = colorSeq({ { 0, WHITE }, { 0.25, colors[2] }, { 1, colors[3] } })
			trail.Transparency = numberSeq({ { 0, 0.1 }, { 1, 1 } })
			trail.WidthScale = numberSeq({ { 0, 1 }, { 1, 0 } })
			trail.Lifetime = O.trail or 0.35
			trail.LightEmission, trail.LightInfluence = glow, 0
			trail.FaceCamera = true
			trail.Parent = ball
			ball.Parent = folder
			table.insert(orbs, { ball = ball, trail = trail, i = i })
		end
	end

	-- Trails on her feet and hands, on only while she moves.
	local wakes = {}
	local W = spec.wake
	if W and root then
		local function wake(part, low, high, life, name)
			if not part then return end
			local a0, a1 = keep(Instance.new("Attachment")), keep(Instance.new("Attachment"))
			a0.Name, a1.Name = "HuzzWakeA" .. name, "HuzzWakeB" .. name
			a0.Position, a1.Position = Vector3.new(0, low, 0), Vector3.new(0, high, 0)
			a0.Parent, a1.Parent = part, part
			local t = keep(Instance.new("Trail"))
			t.Name = "HuzzWake" .. name
			t.Attachment0, t.Attachment1 = a0, a1
			t.Color = colorSeq({ { 0, W.colors[1] }, { 0.3, W.colors[2] }, { 1, W.colors[3] } })
			t.Transparency = numberSeq({ { 0, 0.35 }, { 1, 1 } })
			t.WidthScale = numberSeq({ { 0, 1 }, { 1, 0 } })
			t.Lifetime = life
			t.MinLength = 0.05
			t.LightEmission, t.LightInfluence = 0.8 * glow, 0
			t.FaceCamera = true
			t.Enabled = false
			t.Parent = part
			table.insert(wakes, t)
		end
		if W.feet then
			for i, f in feet do
				local bottom = -f.Size.Y / 2
				wake(f, bottom + 0.05 * scale, bottom + 0.4 * scale, 0.35, "Foot" .. i)
			end
		end
		if W.hands and not lite then
			for _, hand in { "RightHand", "LeftHand" } do
				local part, offset = anchor(model, hand, scale)
				if part then
					local y = offset.Position.Y
					wake(part, y - 0.25 * scale, y + 0.25 * scale, 0.25, hand)
				end
			end
		end
	end

	-- Secret: a thin halo level over her head (drawn on both faces, so it reads from below too).
	local halo = nil
	if spec.halo and head then
		local d = spec.halo.radius * 2 * scale
		halo = keep(plainPart("HuzzAuraHalo", Vector3.new(d, 0.05, d)))
		halo.CFrame = CFrame.new(getPos(head))
		for _, face in { Enum.NormalId.Top, Enum.NormalId.Bottom } do
			local gui = surface(halo, face, 1.6 * glow)
			ring(gui, 0.9, spec.halo.colors[2], 0.1, 14)
			ring(gui, 0.9, spec.halo.colors[1], 0.3, 5)
		end
		halo.Parent = folder
	end

	-- Crescent slashes: a small pool, reused. Each is two halves (start-middle, middle-end) so it's thick in the
	-- middle and sharp at both ends; each half is a bright core drawn over a wider dark edge.
	local slashes, clock, spawnAt, seed = {}, 0, 0, math.random(1, 100000)
	local S = spec.slashes
	if S and body then
		local count = math.ceil(S.rate * (if lite then 0.5 else 1) * S.life) + 2
		for i = 1, count do
			local atts = {}
			for j, tag in { "A", "M", "B" } do
				local a = keep(Instance.new("Attachment"))
				a.Name = "HuzzSlash" .. i .. tag
				a.Parent = body
				atts[j] = a
			end
			local beams = {}
			for half = 1, 2 do
				for _, layer in { { "Edge", S.edge, 0, 1.7, 0 }, { "Core", S.core, 0.6, 1, 0.05 } } do
					local b = keep(Instance.new("Beam"))
					b.Name = "HuzzSlash" .. layer[1] .. half
					b.Attachment0, b.Attachment1 = atts[half], atts[half + 1]
					b.Color = ColorSequence.new(layer[2])
					b.LightEmission = layer[3] * glow
					b.LightInfluence = if layer[3] > 0 then 0 else 1
					b.ZOffset = layer[5] -- (the core always on top of its dark edge)
					b.FaceCamera = true
					b.Segments = 12
					b.Enabled = false
					b.Parent = body
					table.insert(beams, { beam = b, widthMult = layer[4], half = half, edge = layer[1] == "Edge" })
				end
			end
			slashes[i] = { atts = atts, beams = beams, born = -1, seed = 0 }
		end
	end
	local rate = if S then S.rate * (if lite then 0.5 else 1) else 0
	local function spawnSlash()
		for _, s in slashes do
			if s.born < 0 then
				seed += 1
				s.born, s.seed = clock, seed
				return
			end
		end
	end

	local function frame(pos, tangent)
		local side = tangent:Cross(UP)
		side = if side.Magnitude > 0.01 then side.Unit else Vector3.new(1, 0, 0)
		return CFrame.fromMatrix(pos, tangent, side:Cross(tangent))
	end

	local B = spec.beat
	local phase = math.random() * (if B then B.every else 3) -- (girls side by side don't pulse together)
	local lastU = if B then (phase % B.every) else 0
	local lastPos = root and getPos(root)
	local groundY = root and (getPos(root).Y - drop) or 0
	local speed, frameNo = 0, 0
	local groundOn = true
	local moving = false

	local handle = { enabled = true }
	local function showGround(on)
		if groundOn == on then return end
		groundOn = on
		if poolGui then poolGui.Enabled = on end
		for _, p in groundEmitters do p.Enabled = on end
		if not on and shockGui then shockGui.Enabled = false end
	end

	function handle.step(dt)
		if not (body and body.Parent and handle.enabled) then
			return
		end
		clock += dt
		frameNo += 1
		for _, b in beats do
			if clock >= b.next then
				b.next = clock + b.every
				b.emitter:Emit(b.count)
			end
		end
		-- how fast she moves (her root, flat), for the trails and the puffs at her feet
		local rootPos = root and getPos(root)
		if rootPos and lastPos then
			local flat = Vector3.new(rootPos.X - lastPos.X, 0, rootPos.Z - lastPos.Z).Magnitude
			if flat > 8 * scale then flat = 0 end -- (a teleport, not a step)
			speed += (flat / dt - speed) * math.min(1, dt * 8)
			for _, s in strideEmitters do
				s.acc = (s.acc or 0) + flat
				if s.acc >= s.stride then
					s.acc = 0
					if groundOn then s.emitter:Emit(s.count) end
				end
			end
		end
		lastPos = rootPos
		local nowMoving = if moving then speed > 1.2 * scale else speed > 2.5 * scale
		if nowMoving ~= moving then
			moving = nowMoving
			for _, t in wakes do t.Enabled = moving end
		end
		-- the beat: anticipation, flare, ring out over the floor, sparkles (and a slash on Mythic up)
		local energy, shockT, breathe = AuraLook.beatAt(B, clock + phase)
		if B then
			local u = (clock + phase) % B.every
			if u < lastU then
				if burst then burst:Emit(if lite then math.ceil(B.burst / 2) else B.burst) end
				if S and S.onBeat then spawnSlash() end
			end
			lastU = u
		end
		if light then
			light.Brightness = lightBase * (0.8 + 0.2 * energy)
		end
		-- the floor layers follow her feet (the lower foot; rising slowly, so a hop doesn't lift the pool)
		if pool and rootPos then
			if frameNo % 15 == 1 then
				showGround(model:GetAttribute("HuzzRevealing") ~= true)
			end
			local y = rootPos.Y - drop
			if #feet > 0 then
				y = math.huge
				for _, f in feet do
					y = math.min(y, getPos(f).Y - f.Size.Y / 2)
				end
			end
			if math.abs(y - groundY) > 4 * scale or y < groundY then
				groundY = y
			else
				groundY += (y - groundY) * math.min(1, dt * 3)
			end
			local at = Vector3.new(rootPos.X, groundY + 0.04 * scale, rootPos.Z)
			local d = poolRadius * 2 * (1 + G.breathe * breathe) * (0.92 + 0.08 * energy)
			pool.Size = Vector3.new(d, 0.05, d)
			setPos(pool, at)
			if runner then
				runner.Rotation = (clock * G.spin) % 360
			end
			if shock and groundOn then
				local gui = shockGui
				if shockT >= 0 then
					local k = 1 - (1 - shockT) ^ 3
					local sd = poolRadius * 2 * (0.9 + 1.5 * k)
					setPos(shock, at + Vector3.new(0, 0.01, 0))
					shock.Size = Vector3.new(sd, 0.05, sd)
					shockStroke.Transparency = 0.15 + 0.85 * shockT
					shockStroke.Thickness = 10 * (1 - 0.6 * shockT)
					gui.Enabled = true
				elseif gui.Enabled then
					gui.Enabled = false
				end
			end
		end
		if halo and head then
			setPos(halo, getPos(head) + Vector3.new(0, head.Size.Y / 2 + 0.35 * scale + 0.05 * scale * breathe, 0))
		end
		if F then
			for _, f in flames do
				local p0, p1, c0, c1, w0, w1 = AuraLook.flameAt(F, f.i, f.core, clock, energy, phase)
				f.a0.Position = Vector3.new(p0.X * scale, -drop + 0.08 * scale, p0.Z * scale)
				f.a1.Position = Vector3.new(p1.X * scale, top + (p1.Y - 2.2) * scale, p1.Z * scale)
				local beam = f.beam
				beam.CurveSize0, beam.CurveSize1 = c0 * scale, c1 * scale
				beam.Width0, beam.Width1 = w0 * scale, w1 * scale
			end
		end
		if O and body then
			local c = getPos(body)
			for _, o in orbs do
				setPos(o.ball, c + AuraLook.orbitAt(O, o.i, #orbs, clock) * scale)
			end
		end
		if not S then
			return
		end
		if not S.onBeat and clock >= spawnAt then
			spawnAt = clock + (0.6 + math.random() * 0.8) / rate
			spawnSlash()
		end
		for _, s in slashes do
			if s.born >= 0 then
				local age = clock - s.born
				if age > S.life then
					s.born = -1
					for _, b in s.beams do
						b.beam.Enabled = false
					end
				else
					local p0, pm, p1, t0, tm, t1, curve, alpha, width =
						AuraLook.slash(S, s.seed, age, getPos(body), scale)
					s.atts[1].WorldCFrame = frame(p0, t0)
					s.atts[2].WorldCFrame = frame(pm, tm)
					s.atts[3].WorldCFrame = frame(p1, t1)
					for _, b in s.beams do
						local beam = b.beam
						beam.CurveSize0, beam.CurveSize1 = curve, curve
						local w = width * b.widthMult
						-- sharp at the outer ends, thick where the halves meet
						beam.Width0 = if b.half == 1 then 0 else w
						beam.Width1 = if b.half == 1 then w else 0
						local a = math.clamp(alpha + (if b.edge then 0.15 else 0), 0, 1)
						beam.Transparency = NumberSequence.new(a)
						beam.Enabled = true
					end
				end
			end
		end
	end
	function handle.setEnabled(on)
		if handle.enabled == on then
			return
		end
		handle.enabled = on
		for _, p in emitters do
			p.Enabled = on
		end
		for _, p in groundEmitters do
			p.Enabled = on and groundOn
		end
		if light then
			light.Enabled = on
		end
		for _, o in orbs do
			o.trail.Enabled = on
			o.ball.Transparency = if on then 0 else 1
		end
		for _, f in flames do
			f.beam.Enabled = on
		end
		for _, t in wakes do
			t.Enabled = on and moving
		end
		if halo then
			for _, g in halo:GetChildren() do
				if g:IsA("SurfaceGui") then g.Enabled = on end
			end
		end
		if poolGui then
			poolGui.Enabled = on and groundOn
		end
		if shockGui then
			shockGui.Enabled = false
		end
		if not on then
			for _, s in slashes do
				s.born = -1
				for _, b in s.beams do
					b.beam.Enabled = false
				end
			end
		end
	end
	function handle.destroy()
		for _, inst in made do
			inst:Destroy()
		end
		table.clear(made)
		table.clear(slashes)
		table.clear(orbs)
		table.clear(flames)
		table.clear(wakes)
		table.clear(beats)
		S, O, F, G = nil, nil, nil, nil
		pool, shock, halo = nil, nil, nil
	end
	return handle
end

return AuraFX
