-- UnboxKit (brief 27, REVEAL): the toolkit and the stage of the box-opening cinematic (Shared/UnboxCinematic).
--   Kit.M          maths: easing, analytic springs (the same curve every frame, so a skip or the film tool lands on it),
--                  hashed randomness, noise
--   Kit.Make       anchored, untouchable, shadowless parts, attachments, lights, beams, emitters (house textures via
--                  HoodVFX.applyTexture: the uploaded sheet when there is one, else a Roblox built-in)
--   Kit.Actor      a rigid model posed by ONE BulkMoveTo per frame, with per-axis squash and stretch about its pivot
--   Kit.Bits       parts as particles: debris, shards, coins, confetti, splats... (analytic flights with a bounce)
--   Kit.Ring       an energy ring from four quarter-arc Beams (CurveSize = 0.5523 r); Kit.PartRing: a ring of neon parts
--   Kit.Stage      "The Drop Pad": a hood rooftop built far from the map for one opening and destroyed after it
-- Nothing here keeps state between openings: every instance goes under the job's folder.
local Kit = {}

local V3, CF, ANG = Vector3.new, CFrame.new, CFrame.Angles
local C3 = Color3.fromRGB
local NR = NumberRange.new
local WHITE = Color3.new(1, 1, 1)
local PI = math.pi

local HoodVFX, Fonts
do
	local node = script.Parent:FindFirstChild('HoodVFX')
	if node then
		local ok, m = pcall(require, node)
		HoodVFX = ok and type(m) == 'table' and m or nil
	end
	-- (brief 28: the game's one family; the posters' words and the sign in its Title weight)
	local fnode = script.Parent:FindFirstChild('Fonts')
	if fnode then
		local ok, m = pcall(require, fnode)
		Fonts = ok and type(m) == 'table' and m or nil
	end
end
local function titleFace(l)
	if Fonts and Fonts.Title then l.FontFace = Fonts.Title else l.Font = Enum.Font.GothamBlack end
end

---------------------------------------------------------------------------------------------- maths
local M = {}
Kit.M = M
function M.c01(x) return math.clamp(x, 0, 1) end
function M.lerp(a, b, t) return a + (b - a) * t end
function M.smooth(t) t = M.c01(t) return t * t * (3 - 2 * t) end
function M.out(t, p) t = M.c01(t) return 1 - (1 - t) ^ (p or 3) end
function M.inn(t, p) t = M.c01(t) return t ^ (p or 2) end
function M.inout(t) t = M.c01(t) return t < 0.5 and 4 * t * t * t or 1 - (-2 * t + 2) ^ 3 / 2 end
function M.sineInOut(t) t = M.c01(t) return -(math.cos(PI * t) - 1) / 2 end
function M.back(t, s)
	t = M.c01(t)
	s = s or 1.70158
	return 1 + (s + 1) * (t - 1) ^ 3 + s * (t - 1) ^ 2
end
-- 0 -> 1 -> 0 over [a, a + len]
function M.bump(t, a, len) local u = (t - a) / len return (u > 0 and u < 1) and math.sin(u * PI) or 0 end
-- a damped spring released from 1 toward 0 (f Hz, damping ratio z): 1 at tau 0, overshoots past 0, settles
function M.spring(tau, f, z)
	if tau <= 0 then return 1 end
	local w = 2 * PI * f
	local q = math.sqrt(1 - z * z)
	local wd = w * q
	return math.exp(-z * w * tau) * (math.cos(wd * tau) + z / q * math.sin(wd * tau))
end
-- a damped spring kicked from rest (an impulse): 0 at tau 0, peaks at 1, rings down
function M.kick(tau, f, z)
	if tau <= 0 then return 0 end
	local w = 2 * PI * f
	local q = math.sqrt(1 - z * z)
	local wd = w * q
	local tp = math.atan(q / z) / wd
	local peak = math.exp(-z * w * tp) * math.sin(wd * tp)
	return math.exp(-z * w * tau) * math.sin(wd * tau) / peak
end
-- a hashed 0..1 (deterministic: the same opening looks the same in the film tool and in game)
function M.hash(i, j)
	local x = math.sin(i * 127.1 + (j or 0) * 311.7) * 43758.5453
	return x - math.floor(x)
end
function M.range(r, i, j)
	if type(r) == 'number' then return r end
	return r[1] + (r[2] - r[1]) * M.hash(i, j)
end
-- smooth noise in -1..1 (math.noise is 0 at integers: a fractional seed)
function M.noise(seed, x) return math.clamp(math.noise(seed + 0.37, x + 0.11) * 2, -1, 1) end
function M.hsv(t, i) return Color3.fromHSV((t * 0.3 + (i or 0) * 0.137) % 1, 0.6, 1) end

function Kit.seq(colors)
	if #colors == 1 then return ColorSequence.new(colors[1]) end
	local k = {}
	for i, c in colors do table.insert(k, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c)) end
	return ColorSequence.new(k)
end
function Kit.nseq(points)
	local k = {}
	for _, p in points do table.insert(k, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0)) end
	return NumberSequence.new(k)
end

---------------------------------------------------------------------------------------------- instances
local SURF = { 'TopSurface', 'BottomSurface', 'FrontSurface', 'BackSurface', 'LeftSurface', 'RightSurface' }
local Make = {}
Kit.Make = Make
function Make.part(parent, name, size, cf, color, material, props)
	local p = Instance.new((props and props.Class) or 'Part')
	p.Name = name
	p.Anchored = true
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color or WHITE
	p.Material = material or Enum.Material.SmoothPlastic
	for _, f in SURF do (p :: any)[f] = Enum.SurfaceType.Smooth end
	if props then
		for k, v in props do
			if k ~= 'Class' then (p :: any)[k] = v end
		end
	end
	p.Parent = parent
	return p
end
-- a cylinder standing up (its axis along the frame's Y)
function Make.disc(parent, name, h, d, cf, color, material, props)
	local p = Make.part(parent, name, V3(h, d, d), cf * ANG(0, 0, PI / 2), color, material, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end
function Make.ball(parent, name, d, cf, color, material, props)
	local p = Make.part(parent, name, V3(d, d, d), cf, color, material, props)
	p.Shape = Enum.PartType.Ball
	return p
end
function Make.blob(parent, name, size, cf, color, material, props)
	local p = Make.part(parent, name, size, cf, color, material, props)
	local mesh = Instance.new('SpecialMesh')
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end
function Make.attach(parent, name, cf)
	local a = Instance.new('Attachment')
	a.Name = name
	a.CFrame = cf or CFrame.identity
	a.Parent = parent
	return a
end
function Make.light(parent, color, brightness, range)
	local l = Instance.new('PointLight')
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = parent
	return l
end
-- A FaceCamera Beam between two attachments (rings, rays, pillars, the comet's tail). Untextured: a flat ribbon.
function Make.beam(parent, a0, a1, color, width0, width1, transparency, emission, props)
	local b = Instance.new('Beam')
	b.Attachment0, b.Attachment1 = a0, a1
	b.Color = typeof(color) == 'ColorSequence' and color or ColorSequence.new(color)
	b.Width0, b.Width1 = width0, width1
	b.Transparency = typeof(transparency) == 'NumberSequence' and transparency or NumberSequence.new(transparency or 0)
	b.LightEmission = emission or 1
	b.LightInfluence = 0
	b.FaceCamera = true
	b.Segments = 12
	b.Texture = ''
	if props then
		for k, v in props do
			if k ~= 'Tex' then (b :: any)[k] = v end
		end
		-- props.Tex: a house sheet stretched along the beam (pillars, rays, tails: soft sides instead of a flat ribbon)
		if props.Tex then
			b.Texture = 'rbxasset://textures/glow.png'
			b:SetAttribute('PreviewTexture', props.Tex)
			if HoodVFX and type(HoodVFX.applyTexture) == 'function' then pcall(HoodVFX.applyTexture, b, props.Tex) end
			b.TextureMode, b.TextureLength = Enum.TextureMode.Stretch, 1
		end
	end
	b.Parent = parent
	return b
end
-- Built-in textures (what the game draws until the house sheets are uploaded) and the house names they stand for.
Kit.TEX = {
	spark = 'rbxasset://textures/particles/sparkles_main.dds', glow = 'rbxasset://textures/glow.png',
	smoke = 'rbxasset://textures/particles/smoke_main.dds', fire = 'rbxasset://textures/particles/fire_main.dds',
	ring = 'rbxasset://textures/particles/explosion01_shockwave_main.dds', square = 'rbxasset://textures/particles/SquareParticle.png',
}
local HOUSE = { spark = 'glitter', glow = 'softglow', smoke = 'mist', ring = 'ring', fire = 'flame' }
local PREVIEW = { spark = 'sparkle', glow = 'glow', smoke = 'smoke', fire = 'flame1', ring = 'ring', square = 'confetti' }
-- A ParticleEmitter, off, parented to `host` (an attachment or a part). o: Kit.Make.emitter's settings.
function Make.emitter(host, name, tex, color, o)
	local e = Instance.new('ParticleEmitter')
	e.Name = name
	e.Enabled = false
	e.Texture = Kit.TEX[tex] or Kit.TEX.spark
	e:SetAttribute('PreviewTexture', PREVIEW[tex] or 'sparkle')
	e.LightInfluence = o.lightInfluence or 0
	e.LightEmission = o.emission or 1
	e.Color = typeof(color) == 'ColorSequence' and color or ColorSequence.new(color)
	e.Lifetime = NR(o.life[1], o.life[2])
	e.Speed = NR(o.speed[1], o.speed[2])
	e.Drag = o.drag or 0
	e.Acceleration = o.accel or Vector3.zero
	e.SpreadAngle = o.spread or Vector2.new(180, 180)
	e.Rotation = o.rotation or NR(0, 360)
	e.RotSpeed = o.rotSpeed or NR(-90, 90)
	e.Size = o.size
	e.Transparency = o.transparency
	e.ZOffset = o.zoffset or 0
	if o.brightness then e.Brightness = o.brightness end
	if o.orientation then e.Orientation = o.orientation end
	if o.squash then e.Squash = o.squash end
	if o.direction then e.EmissionDirection = o.direction end
	e.Rate = o.rate or 0 -- (bursts only Emit: a Rate of 0 keeps them out of the continuous budget)
	if o.shape then
		e.Shape = o.shape
		e.ShapeStyle = o.shapeStyle or Enum.ParticleEmitterShapeStyle.Volume
		e.ShapeInOut = o.shapeInOut or Enum.ParticleEmitterShapeInOut.Outward
	end
	-- the house sheet when uploaded (HoodVFX keeps the built-in otherwise, and tags PreviewTexture)
	if HoodVFX and HOUSE[tex] and type(HoodVFX.applyTexture) == 'function' and not o.builtin then
		local ok = pcall(HoodVFX.applyTexture, e, HOUSE[tex], { fade = 1 })
		if ok and e.Texture == '' then e.Texture = Kit.TEX[tex] end
		e:SetAttribute('PreviewTexture', PREVIEW[tex] or 'sparkle')
	end
	e.Parent = host
	return e
end

---------------------------------------------------------------------------------------------- actors
-- A rigid model posed with one BulkMoveTo: every part's CFrame relative to a pivot, its Size, and how its local axes map
-- onto the pivot's (so a per-axis scale about the pivot reads as squash and stretch). Sizes are written only while a
-- scale is on, and once more to put them back; an unchanged pose writes nothing.
local hasBulk = nil
local function bulk(parts, cfs)
	if #parts == 0 then return end
	if hasBulk == nil then hasBulk = pcall(function() workspace:BulkMoveTo({}, {}, Enum.BulkMoveMode.FireCFrameChanged) end) end
	if hasBulk then
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	else
		for i, p in parts do p.CFrame = cfs[i] end
	end
end
Kit.bulk = bulk
local Actor = {}
Actor.__index = Actor
Kit.Actor = Actor
function Actor.new(list, pivot)
	local self = setmetatable({ parts = {}, rel = {}, size = {}, shape = {}, ax = {}, cfs = {}, scaled = false, trans = {}, color = {} }, Actor)
	local inv = pivot:Inverse()
	for _, p in list do
		table.insert(self.parts, p)
		local rel = inv * p.CFrame
		table.insert(self.rel, rel)
		table.insert(self.size, p.Size)
		table.insert(self.trans, p.Transparency)
		table.insert(self.color, p.Color)
		local shape = 'block'
		if p:IsA('Part') then
			if p.Shape == Enum.PartType.Ball then shape = 'ball' elseif p.Shape == Enum.PartType.Cylinder then shape = 'cyl' end
		end
		table.insert(self.shape, shape)
		local r = rel.Rotation
		table.insert(self.ax, { r.RightVector, r.UpVector, -r.LookVector })
	end
	return self
end
local function axisScale(a, sx, sy, sz)
	local x, y, z = math.abs(a.X), math.abs(a.Y), math.abs(a.Z)
	return (x * sx + y * sy + z * sz) / math.max(1e-6, x + y + z)
end
function Actor:pose(cf, sx, sy, sz)
	sx = sx or 1
	sy = sy or sx
	sz = sz or sx
	local last = self.last
	if last and last[1] == cf and last[2] == sx and last[3] == sy and last[4] == sz then return end
	self.last = { cf, sx, sy, sz }
	local cfs = self.cfs
	for i, r in self.rel do
		local p = r.Position
		cfs[i] = cf * CF(p.X * sx, p.Y * sy, p.Z * sz) * r.Rotation
	end
	bulk(self.parts, cfs)
	local on = math.abs(sx - 1) + math.abs(sy - 1) + math.abs(sz - 1) > 0.004
	local key = on and (sx * 1e6 + sy * 1e3 + sz) or -1
	if (on or self.scaled) and key ~= self.sizeKey then
		self.sizeKey = key
		for i, p in self.parts do
			local s0 = self.size[i]
			if on then
				local a = self.ax[i]
				local kx, ky, kz = axisScale(a[1], sx, sy, sz), axisScale(a[2], sx, sy, sz), axisScale(a[3], sx, sy, sz)
				local shape = self.shape[i]
				if shape == 'ball' then
					local k = (kx + ky + kz) / 3
					kx, ky, kz = k, k, k
				elseif shape == 'cyl' then
					local k = (ky + kz) / 2
					ky, kz = k, k
				end
				p.Size = V3(math.max(0.01, s0.X * kx), math.max(0.01, s0.Y * ky), math.max(0.01, s0.Z * kz))
			else
				p.Size = s0
			end
		end
		self.scaled = on
	end
end
-- Fade the actor: 0 = as built, 1 = gone (writes only on change).
function Actor:fade(a)
	a = M.c01(a)
	if self.alpha == a then return end
	self.alpha = a
	for i, p in self.parts do
		local t0 = self.trans[i]
		p.Transparency = t0 >= 1 and 1 or M.lerp(t0, 1, a)
	end
end
-- Tint the actor toward a colour (a silhouette): 0 = its own colours, 1 = all `color` (writes only on change).
function Actor:tint(color, a)
	a = M.c01(a)
	if self.tintA == a then return end
	self.tintA = a
	for i, p in self.parts do p.Color = self.color[i]:Lerp(color, a) end
end

---------------------------------------------------------------------------------------------- bits (parts as particles)
-- spec: { kind, n, colors, t0, at (CFrame), speed {min,max} (or vx/vy ranges), up 0..1, size, grav, life, stick,
-- material, neon, rain = radius, spread = seconds of stagger, hz {min,max} horizontal speed, vz {min,max} vertical }
-- Kinds: cube, rock, shard, coin, drop, splat (lands flat and stays), sprinkle, candy, ember (rises), star, feather,
-- rect and strip (confetti). Heavy kinds fly ballistically with one bounce; light kinds flutter down at a terminal speed.
local FLUTTER = { rect = true, strip = true, feather = true, ember = true }
local Bits = {}
Bits.__index = Bits
Kit.Bits = Bits
function Bits.new(folder, park, floorAt)
	return setmetatable({ list = {}, folder = folder, park = park, floorAt = floorAt, parts = {}, cfs = {}, used = {} }, Bits)
end
function Bits:spawn(spec, cat, cap)
	local n = math.floor(spec.n + 0.5)
	if cat and cap then
		local used = self.used[cat] or 0
		n = math.min(n, cap - used)
		self.used[cat] = used + math.max(0, n)
	end
	if n <= 0 then return end
	local kind = spec.kind or 'cube'
	local base = spec.at.Position
	local camDir = spec.away
	for i = 1, n do
		local seed = #self.list + i * 1.37 + spec.t0 * 3.1
		local col = spec.colors[(i - 1) % #spec.colors + 1]
		local s = (spec.size or 0.5) * M.lerp(0.75, 1.25, M.hash(seed, 1))
		local size, shape, mat, mesh = V3(s, s, s), nil, Enum.Material.SmoothPlastic, false
		if kind == 'shard' then size = V3(s * 0.32, s * 1.5, s * 0.55); mat = spec.neon and Enum.Material.Neon or Enum.Material.Glass
		elseif kind == 'coin' then size = V3(s * 0.16, s, s); shape = 'cyl'; mat = Enum.Material.Foil
		elseif kind == 'drop' or kind == 'splat' or kind == 'candy' then shape = 'ball'
		elseif kind == 'sprinkle' then size = V3(s * 1.2, s * 0.3, s * 0.3); shape = 'cyl'
		elseif kind == 'ember' or kind == 'star' then mat = Enum.Material.Neon; if kind == 'star' then size = V3(s, s, s * 0.3) end
		elseif kind == 'feather' then size = V3(s * 0.4, s * 1.3, s * 0.12); mesh = true
		elseif kind == 'rect' then size = V3(s * 0.8, s * 0.06, s * 0.5)
		elseif kind == 'strip' then size = V3(s * 1.4, s * 0.06, s * 0.22)
		end
		if spec.material then mat = Enum.Material[spec.material] or mat end
		if spec.neon and kind ~= 'shard' then mat = Enum.Material.Neon end
		local p = Make.part(self.folder, 'Bit_' .. kind, size, self.park, col, mat, spec.transparency and { Transparency = spec.transparency } or nil)
		if shape == 'ball' then p.Shape = Enum.PartType.Ball elseif shape == 'cyl' then p.Shape = Enum.PartType.Cylinder end
		if mesh then
			local m = Instance.new('SpecialMesh')
			m.MeshType = Enum.MeshType.Sphere
			m.Parent = p
		end
		-- (spec.accept(b): a test of the piece's whole flight; a refused piece is re-rolled (a new direction, speed, puff and
		-- drift; the same look) up to spec.tries times, and dropped if none passes)
		local b
		for try = 0, spec.accept and (spec.tries or 5) or 0 do
			local sd = seed + try * 7.31
			local a = M.hash(sd, 2) * 2 * PI
			if spec.dir then a = math.atan2(spec.dir.Z, spec.dir.X) + (M.hash(sd, 2) - 0.5) * (spec.cone or 0.8) end
			local v
			if spec.hz then
				-- debris: a horizontal speed in a random direction and a vertical launch
				local h = M.range(spec.hz, sd, 3)
				v = V3(math.cos(a) * h, M.range(spec.vz, sd, 4), math.sin(a) * h)
			else
				local up = spec.up or 0.6
				local spd = M.range(spec.speed or { 8, 12 }, sd, 3)
				v = V3(math.cos(a) * (1 - up * 0.7), up + M.hash(sd, 4) * 0.3, math.sin(a) * (1 - up * 0.7)).Unit * spd
			end
			-- pieces aimed at the camera fly sideways instead, so the shot stays readable
			if camDir then
				local flat = V3(v.X, 0, v.Z)
				if flat.Magnitude > 0.1 and flat.Unit:Dot(camDir) > 0.5 then v = V3(v.X - camDir.X * flat.Magnitude * 1.2, v.Y, v.Z - camDir.Z * flat.Magnitude * 1.2) end
			end
			-- (spec.ring: born on a circle of that radius round `at`, on the side it flies to: chunks from a box's rim;
			-- spec.box: born anywhere in a box of these half-sizes round `at` (a confetti cannon's mouth))
			local rim = spec.ring and V3(math.cos(a), 0, math.sin(a)) * spec.ring or Vector3.zero
			if spec.box then
				rim += V3((M.hash(sd, 21) - 0.5) * 2 * spec.box.X, (M.hash(sd, 22) - 0.5) * 2 * spec.box.Y, (M.hash(sd, 23) - 0.5) * 2 * spec.box.Z)
			end
			-- (spec.bursts: the pieces leave in that many puffs, spec.burstGap apart, instead of one)
			local t0 = spec.t0 + M.hash(sd, 5) * (spec.spread or 0.03)
			if spec.bursts then t0 = spec.t0 + math.floor(M.hash(sd, 24) * spec.bursts) * (spec.burstGap or 0.07) + M.hash(sd, 5) * 0.02 end
			b = {
				part = p, kind = kind, t0 = t0, p0 = base + rim + V3(0, M.hash(sd, 6) * 0.4, 0),
				v0 = v, grav = spec.grav or (FLUTTER[kind] and 16 or 60),
				-- (paper: each piece its own drag and a small sideways drift, so a burst spreads instead of moving as one)
				drag = FLUTTER[kind] and (kind == 'ember' and 0.5 or M.lerp(spec.dragMin or 0.4, spec.dragMax or 0.4, M.hash(sd, 25))) or 0,
				wind = spec.drift and V3((M.hash(sd, 26) - 0.5) * 2 * spec.drift, 0, (M.hash(sd, 27) - 0.5) * spec.drift) or nil,
				axis = V3(M.hash(sd, 7) - 0.5, M.hash(sd, 8) - 0.5, M.hash(sd, 9) - 0.5).Unit, w = M.lerp(spec.spinMin or 3, spec.spinMax or 9.5, M.hash(sd, 10)),
				life = spec.life or (kind == 'splat' and 99 or FLUTTER[kind] and 2.6 or 2.0), size = size, r = math.min(size.X, size.Y, size.Z) * 0.5,
				stick = spec.stick or kind == 'splat', phase = M.hash(sd, 11) * 6, bounce = spec.bounce or 0.35, fade = spec.fadeOut,
			}
			if spec.rain then
				b.p0 = base + V3(M.lerp(-1, 1, M.hash(sd, 12)) * spec.rain, M.hash(sd, 16) * 4, M.lerp(-1, 1, M.hash(sd, 13)) * spec.rain * 0.6)
				b.v0 = V3(0, -M.range(spec.speed or { 2, 6 }, sd, 14), 0)
				b.t0 = spec.t0 + M.hash(sd, 15) * (spec.spread or 1.2)
			end
			if not spec.accept or spec.accept(b) then break end
			b = nil
		end
		if b then table.insert(self.list, b) else p:Destroy() end
	end
end
local function landAt(p0, v, g, y)
	local h = p0.Y - y
	if h < 0 then return 0 end
	return (v.Y + math.sqrt(math.max(0, v.Y * v.Y + 2 * g * h))) / g
end
function Bits:pose(b, tau)
	if b.drag > 0 then
		local tc = b.drag
		local vt = V3(0, -b.grav * tc, 0)
		local e = math.exp(-tau / tc)
		local p = b.p0 + vt * tau + (b.v0 - vt) * tc * (1 - e)
		if b.wind then p += b.wind * tau end
		local wob = (b.kind == 'ember') and 0.25 or 1
		p += V3(math.sin(tau * 5.5 + b.phase) * 0.4 * wob, 0, math.cos(tau * 4.3 + b.phase) * 0.4 * wob)
		local y0 = self.floorAt(p)
		if p.Y < y0 + b.r then
			return V3(p.X, y0 + b.r, p.Z), CFrame.Angles(0, b.phase, 0), true
		end
		-- paper flutter: a fast flip about its long axis and a slow tumble
		return p, CFrame.fromAxisAngle(b.axis, tau * b.w * 0.5) * CFrame.Angles(tau * 14 + b.phase, 0, 0), false
	end
	local g = b.grav
	local gv = V3(0, -g, 0)
	local y = self.floorAt(b.p0 + V3(b.v0.X, 0, b.v0.Z) * 0.5)
	local t1 = landAt(b.p0, b.v0, g, y + b.r)
	local q = b.p0 + b.v0 * t1 + gv * 0.5 * t1 * t1
	local y2 = self.floorAt(q)
	if math.abs(y2 - y) > 0.05 then
		y = y2
		t1 = landAt(b.p0, b.v0, g, y + b.r)
	end
	if tau < t1 then return b.p0 + b.v0 * tau + gv * 0.5 * tau * tau, CFrame.fromAxisAngle(b.axis, tau * b.w), false end
	local land = b.p0 + b.v0 * t1 + gv * 0.5 * t1 * t1
	land = V3(land.X, y + b.r, land.Z)
	local spin = CFrame.fromAxisAngle(b.axis, t1 * b.w)
	if b.stick then return land, spin, true, true end
	local v1 = b.v0 + gv * t1
	local vb = V3(v1.X * 0.6, -v1.Y * b.bounce, v1.Z * 0.6)
	local t2 = 2 * vb.Y / g
	local tb = tau - t1
	local flat = (b.kind == 'coin') and (CFrame.Angles(0, b.phase, 0) * CFrame.Angles(0, 0, PI / 2)) or
		((b.kind == 'cube' or b.kind == 'rock') and CFrame.Angles(0, b.phase, 0) or spin)
	if tb < t2 then return land + vb * tb + gv * 0.5 * tb * tb, CFrame.fromAxisAngle(b.axis, (t1 + tb * 0.6) * b.w), false end
	return land + V3(vb.X, 0, vb.Z) * t2, flat, true
end
function Bits:step(t)
	local parts, cfs = self.parts, self.cfs
	table.clear(parts)
	table.clear(cfs)
	for _, b in self.list do
		local tau = t - b.t0
		local cf = self.park
		local live = tau >= 0 and tau < b.life + 0.25
		if not live and b.parked then continue end
		b.parked = not live
		if live then
			local pos, rot, landed, stuck = self:pose(b, tau)
			cf = CF(pos) * rot
			if stuck and b.kind == 'splat' and not b.flat then
				b.flat = true
				b.part.Shape = Enum.PartType.Cylinder
				b.part.Size = V3(0.06, b.size.X * 2.2, b.size.X * 2.2)
			end
			if b.flat then cf = CF(pos.X, pos.Y - b.r + 0.05, pos.Z) * CFrame.Angles(0, 0, PI / 2) * CFrame.Angles(b.phase, 0, 0) end
			local shrink = M.c01((tau - b.life) / 0.25)
			if shrink > 0 and not b.flat then
				b.part.Size = b.size * (1 - shrink)
				b.shrunk = true
			elseif b.shrunk and shrink <= 0 then
				b.part.Size = b.size
				b.shrunk = false
			end
			if b.kind == 'ember' and landed then cf = self.park end
		end
		table.insert(parts, b.part)
		table.insert(cfs, cf)
	end
	bulk(parts, cfs)
end
function Bits:count() return #self.list end

---------------------------------------------------------------------------------------------- rings
-- An energy ring of four quarter arcs (a hard core ribbon and a soft glow ribbon each), with a comet look: the head
-- arc bright, the next two fading. Ring:pose(cf, radius, alpha, theta, width) every frame. `solid`: the core is drawn
-- in its own colour (no light emission), so a saturated ring stays saturated over a bright sky; its glow is fainter.
local Ring = {}
Ring.__index = Ring
Kit.Ring = Ring
function Ring.new(anchor, name, color, coreW, glowW, full, solid)
	local self = setmetatable({ anchor = anchor, atts = {}, beams = {}, coreW = coreW, glowW = glowW, color = color }, Ring)
	for i = 1, 4 do self.atts[i] = Make.attach(anchor, name .. 'A' .. i) end
	-- a comet ring (three arcs, bright head to a faded tail) or, `full`, a whole even circle (a shockwave's edge)
	local tr = {
		{ { 0, 0 }, { 1, 0.08 } }, { { 0, 0.08 }, { 1, 0.4 } }, { { 0, 0.4 }, { 0.8, 0.85 }, { 1, 1 } },
	}
	if full then tr = { { { 0, 0 }, { 1, 0 } }, { { 0, 0 }, { 1, 0 } }, { { 0, 0 }, { 1, 0 } }, { { 0, 0 }, { 1, 0 } } } end
	for i = 1, #tr do
		local a0, a1 = self.atts[i], self.atts[i % 4 + 1]
		local core = Make.beam(anchor, a0, a1, color:Lerp(WHITE, 0.4), coreW, coreW, Kit.nseq(tr[i]), solid and 0 or 1, { Segments = 16 })
		local glowT = {}
		for _, k in tr[i] do table.insert(glowT, { k[1], M.lerp(solid and 0.72 or 0.55, 1, k[2]) }) end
		local glow = Make.beam(anchor, a0, a1, color, glowW, glowW, Kit.nseq(glowT), 1, { Segments = 16 })
		core.Name, glow.Name = name .. 'Core' .. i, name .. 'Glow' .. i
		core.Enabled, glow.Enabled = false, false
		table.insert(self.beams, { core, glow })
	end
	return self
end
function Ring:setColor(color, flat)
	if self.color == color and self.flat == flat then return end
	self.color, self.flat = color, flat
	for _, b in self.beams do
		b[1].Color = ColorSequence.new(flat and color or color:Lerp(WHITE, 0.4))
		b[2].Color = ColorSequence.new(color)
	end
end
function Ring:pose(cf, radius, alpha, theta, width)
	local acf = self.anchor.CFrame:Inverse()
	local k = 0.5523 * radius
	for i = 1, 4 do
		local a = theta + (i - 1) * PI / 2
		local pos = cf * V3(math.cos(a) * radius, 0, math.sin(a) * radius)
		local tangent = cf:VectorToWorldSpace(V3(-math.sin(a), 0, math.cos(a)))
		local up = cf.UpVector
		self.atts[i].CFrame = acf * CFrame.fromMatrix(pos, tangent, up, tangent:Cross(up))
	end
	local vis = alpha > 0.01 and radius > 0.05
	local w = (width or 1) * alpha
	for _, b in self.beams do
		local core, glow = b[1], b[2]
		if core.Enabled ~= vis then core.Enabled = vis; glow.Enabled = vis end
		if vis then
			core.CurveSize0, core.CurveSize1, glow.CurveSize0, glow.CurveSize1 = k, k, k, k
			core.Width0, core.Width1 = self.coreW * w, self.coreW * w
			glow.Width0, glow.Width1 = self.glowW * w, self.glowW * w
		end
	end
end
-- A flat ring of n neon segments (the slam's shockwave rim, a halo, a warp ring of radial streaks).
local PartRing = {}
PartRing.__index = PartRing
Kit.PartRing = PartRing
function PartRing.new(folder, park, name, n, thick, color, material)
	local self = setmetatable({ parts = {}, n = n, thick = thick, cfs = {}, park = park, len = 1 }, PartRing)
	for i = 1, n do self.parts[i] = Make.part(folder, name, V3(1, thick, thick), park, color, material or Enum.Material.Neon) end
	return self
end
function PartRing:pose(cf, radius, alpha, spin, radial)
	local cfs = self.cfs
	local vis = alpha > 0.01 and radius > 0.05
	local len = 2 * radius * math.tan(PI / self.n) * 1.06
	for i in self.parts do
		local a = (i - 1) * 2 * PI / self.n + (spin or 0)
		if not vis then
			cfs[i] = self.park
		elseif radial then
			cfs[i] = cf * CFrame.Angles(0, -a, 0) * CF(radius, 0, 0)
		else
			cfs[i] = cf * CFrame.Angles(0, -a, 0) * CF(0, 0, radius)
		end
	end
	bulk(self.parts, cfs)
	if vis then
		local tr = M.c01(1 - alpha)
		local th = self.thick * (radial and 1 or M.lerp(0.4, 1, alpha))
		local size = radial and V3(radius * 0.42 * self.len, th, th) or V3(len, th, th * 1.6)
		for _, p in self.parts do
			if p.Transparency ~= tr then p.Transparency = tr end
			if (p.Size - size).Magnitude > 0.01 then p.Size = size end
		end
	end
end
function PartRing:color(c)
	for _, p in self.parts do
		if p.Color ~= c then p.Color = c end
	end
end

---------------------------------------------------------------------------------------------- the stage: "The Drop Pad"
-- A rooftop of our own: a tiled concrete deck, a round landing pad with a painted "+1" target and a neon rim, a brick
-- back wall with graffiti panels and a "+1 DROP" sign, two street lamps framing the shot (the key lights), two speaker
-- stacks that bump on impacts, a chain-link fence, a water tower, and a skyline of blocky towers with lit windows far
-- out (the Atmosphere hazes it by day; it reads at night). ~200 parts, all anchored and untouchable.
local Stage = {}
Kit.Stage = Stage
function Stage.build(job)
	local P, th = job.P, job.P.theme
	local folder, O, G = job.folder, job.O, P.G
	local R = P.padR
	local function w(x, y, z) return O * CF(x, y, z) end
	local deckW = math.max(48, R * 2 + 30)
	local deck = Color3.fromRGB(70, 72, 82)
	Make.part(folder, 'Deck', V3(deckW, 1, deckW), w(0, -0.5, deckW * 0.18), deck, Enum.Material.Concrete, { CastShadow = true })
	-- tile seams
	for i = -4, 4 do
		local x = i * deckW / 9
		Make.part(folder, 'Seam', V3(0.14, 0.03, deckW), w(x, 0.01, deckW * 0.18), C3(52, 54, 62), Enum.Material.SmoothPlastic)
		Make.part(folder, 'Seam', V3(deckW, 0.03, 0.14), w(0, 0.01, deckW * 0.18 + x), C3(52, 54, 62), Enum.Material.SmoothPlastic)
	end
	-- the landing pad: a low disc, a neon lip, the painted "+1" target
	local padTop = 0.22
	job.padRim = Make.disc(folder, 'PadRim', 0.16, R * 2 + 0.7, w(0, 0.08, 0), th.Rim, Enum.Material.Neon)
	Make.disc(folder, 'Pad', padTop, R * 2, w(0, padTop / 2, 0), C3(48, 50, 60), Enum.Material.SmoothPlastic, { CastShadow = true })
	local tc = C3(232, 232, 240)
	local ring = PartRing.new(folder, job.park, 'TargetRing', math.clamp(math.floor(R * 4.5), 24, 64), 0.035, tc:Lerp(th.Rim, 0.35), Enum.Material.SmoothPlastic)
	ring:pose(w(0, padTop + 0.02, 0), R * 0.78, 1, 0)
	for _, p in ring.parts do p.Size = V3(p.Size.X, 0.035, 0.3) end
	local mark = w(0, padTop + 0.02, R * 0.42) * ANG(0, PI, 0)
	local u = R * 0.13
	Make.part(folder, 'Plus', V3(u * 1.6, 0.035, u * 0.42), mark * CF(-u * 0.9, 0, 0), tc, Enum.Material.SmoothPlastic)
	Make.part(folder, 'Plus', V3(u * 0.42, 0.035, u * 1.6), mark * CF(-u * 0.9, 0, 0), tc, Enum.Material.SmoothPlastic)
	Make.part(folder, 'One', V3(u * 0.42, 0.035, u * 2), mark * CF(u * 0.9, 0, 0), tc, Enum.Material.SmoothPlastic)
	Make.part(folder, 'One', V3(u * 0.6, 0.035, u * 0.38), mark * CF(u * 0.62, 0, u * 0.82) * ANG(0, 0.5, 0), tc, Enum.Material.SmoothPlastic)
	job.padTop = O.Y + padTop
	job.deckY = O.Y
	-- a riser for the back row of a Buy 8
	if P.riser then
		Make.part(folder, 'Riser', V3(P.riser.w, P.riser.h, P.riser.d), w(0, P.riser.h / 2, P.riser.z), C3(58, 60, 70), Enum.Material.Concrete, { CastShadow = true })
		job.riser = P.riser
	end
	-- the back wall: brick, graffiti panels in the theme's colours, the "+1 DROP" sign
	local wz = R + 9 * G
	local wallH, wallW = 12 * G, math.max(P.n == 1 and 44 * G or 30 * G, R * 2 + 16)
	Make.part(folder, 'Wall', V3(wallW, wallH, 1.2), w(0, wallH / 2, wz), th.Wall or C3(104, 78, 82), Enum.Material.Brick, { CastShadow = true })
	Make.part(folder, 'WallCap', V3(wallW + 0.6, 0.5, 1.6), w(0, wallH + 0.25, wz), C3(70, 66, 74), Enum.Material.Concrete)
	local cols = { th.Color, th.Accent, th.Third, C3(255, 214, 60), C3(70, 210, 230) }
	local face = wz - 0.65
	-- the posters: painted (cash boxes), crystal glass (Exclusive: hologram panels) or gold foil (Gold, Grail)
	local style = th.Poster or 'paint'
	if style == 'gold' then cols = { C3(255, 200, 70), C3(240, 170, 40), th.Accent, C3(255, 226, 140), th.Color } end
	job.posterParts, job.posterLabels, job.wordParts = {}, {}, {}
	-- (each side's posters as a group, so Stage.framePosters can slide them once the camera is planned)
	local groups = { { parts = {} }, { parts = {} } }
	job.posterGroups, job.wallInfo = groups, { wz = wz, h = wallH, w = wallW, face = face }
	local px, pd = 0, math.min(wallW * 0.36, 11 * G)
	local function group(x, part) table.insert(groups[x < px and 1 or 2].parts, part) end
	local function panel(x, y, sx, sy, rot, c)
		local mat = style == 'glass' and Enum.Material.Glass or style == 'gold' and Enum.Material.Foil or Enum.Material.SmoothPlastic
		local p = Make.part(folder, 'Graffiti', V3(sx, sy, 0.08), w(x, y, face) * ANG(0, 0, rot), c, mat, style == 'glass' and { Transparency = 0.3, Reflectance = 0.2 } or nil)
		table.insert(job.posterParts, p)
		group(x, p)
		if style == 'glass' then
			-- a neon frame round each hologram panel
			for _, e in { { 0, sy / 2, sx, 0.12 }, { 0, -sy / 2, sx, 0.12 }, { -sx / 2, 0, 0.12, sy }, { sx / 2, 0, 0.12, sy } } do
				local edge = Make.part(folder, 'PanelEdge', V3(e[3], e[4], 0.1), p.CFrame * CF(e[1], e[2], -0.05), c:Lerp(WHITE, 0.4), Enum.Material.Neon)
				table.insert(job.posterParts, edge)
				group(x, edge)
			end
		end
	end
	-- (a single's posters sit either side of where the hero shot looks at the wall, so they frame the pair there)
	if P.n == 1 then
		local yaw = P.premium and math.rad(-10) or math.rad(15)
		px = -math.tan(yaw) * wz
	end
	panel(px - pd, wallH * 0.42, 6 * G, 3.2 * G, 0.12, cols[1])
	panel(px - pd * 0.83, wallH * 0.62, 4.2 * G, 1.2 * G, -0.08, cols[4])
	panel(px + pd * 0.92, wallH * 0.38, 5.4 * G, 3.6 * G, -0.16, cols[2])
	panel(px + pd * 0.7, wallH * 0.66, 3 * G, 1.4 * G, 0.2, cols[5])
	panel(px - pd * 0.33, wallH * 0.25, 2.6 * G, 1 * G, 0.3, cols[3])
	for k = 0, 4 do
		local x = px - pd - 2.4 * G + k * 1.15 * G
		local drip = Make.part(folder, 'Drip', V3(0.32 * G, (0.8 + M.hash(k, 3) * 1.6) * G, 0.08), w(x, wallH * 0.42 - 1.8 * G - M.hash(k, 3) * 0.7 * G, face), cols[1], Enum.Material.SmoothPlastic)
		table.insert(job.posterParts, drip)
		group(px - pd, drip)
	end
	-- tags painted on the two big panels (SurfaceGuis: our own words, in the hood's chunky letters)
	local function tag(x, y, rot, text, size, c)
		local p = Make.part(folder, 'Tag', V3(size.X, size.Y, 0.05), w(x, y, face - 0.08) * ANG(0, 0, rot), c, Enum.Material.SmoothPlastic, { Transparency = 0.999 })
		local g = Instance.new('SurfaceGui')
		g.Name = 'TagText'
		g.Face = Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 30
		g.LightInfluence = 0.6
		local l = Instance.new('TextLabel')
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		titleFace(l)
		l.Text = text
		l.TextScaled = true
		l.TextColor3 = c
		local st = Instance.new('UIStroke')
		st.Color = Fonts and Fonts.Outline and Fonts.Outline.Color or Color3.fromRGB(6, 6, 8)
		st.Thickness = 4
		st.LineJoinMode = Enum.LineJoinMode.Round
		st.Parent = l
		l.Parent = g
		g.Parent = p
		table.insert(job.posterLabels, { l, st })
		table.insert(job.wordParts, p)
		group(x, p)
		groups[x < px and 1 or 2].word = p
	end
	local words = th.Tags or { 'HOOD', 'KICKS' }
	tag(px - pd, wallH * 0.42, 0.12, words[2], V3(5.4 * G, 2.4 * G, 0), WHITE)
	tag(px + pd * 0.92, wallH * 0.38, -0.16, words[1], V3(4.8 * G, 2.6 * G, 0), Color3.fromRGB(255, 240, 120))
	-- the sign on top of the wall
	local signW, signH = 13 * G, 3.2 * G
	-- (off to the right of the wall top, so the reveal's banner never sits on it)
	local sx0 = -math.min(wallW * 0.27, wallW / 2 - signW / 2 - 0.5)
	local sign = Make.part(folder, 'Sign', V3(signW, signH, 0.5), w(sx0, wallH + 0.5 + signH / 2 + 0.6, wz), C3(26, 24, 34), Enum.Material.SmoothPlastic)
	job.signParts = { sign,
		Make.part(folder, 'SignPost', V3(0.4, 1.4, 0.4), w(sx0 - signW * 0.3, wallH + 0.9, wz), C3(40, 40, 48), Enum.Material.Metal),
		Make.part(folder, 'SignPost', V3(0.4, 1.4, 0.4), w(sx0 + signW * 0.3, wallH + 0.9, wz), C3(40, 40, 48), Enum.Material.Metal) }
	local sy = wallH + 0.5 + signH / 2 + 0.6
	job.signNeon = {}
	for _, e in { { 0, signH / 2, signW + 0.3, 0.22 }, { 0, -signH / 2, signW + 0.3, 0.22 }, { -signW / 2, 0, 0.22, signH }, { signW / 2, 0, 0.22, signH } } do
		table.insert(job.signNeon, Make.part(folder, 'SignNeon', V3(e[3], e[4], 0.2), w(sx0 + e[1], sy + e[2], wz - 0.3), th.Rim, Enum.Material.Neon))
	end
	local g = Instance.new('SurfaceGui')
	g.Name = 'SignText'
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.LightInfluence = 0
	local l = Instance.new('TextLabel')
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Position = UDim2.fromScale(0, 0)
	titleFace(l)
	l.Text = '+1 DROP'
	l.TextScaled = true
	l.TextColor3 = th.Rim:Lerp(WHITE, 0.45)
	local st = Instance.new('UIStroke')
	st.Color = th.Rim:Lerp(Color3.new(0, 0, 0), 0.5)
	st.Thickness = 3
	st.Parent = l
	l.Parent = g
	g.Parent = sign
	job.signText, job.signStroke = l, st
	-- street lamps framing the shot (front left and right), leaning in: the key lights
	job.lamps = {}
	for _, sx in { -1, 1 } do
		local base = w(sx * (R + 6.5 * G), 0, -R * 0.35)
		local lamp = Instance.new('Model')
		lamp.Name = 'Lamp'
		lamp.Parent = folder
		local hgt = 12 * G
		Make.disc(lamp, 'LampBase', 0.6, 1.4, base * CF(0, 0.3, 0), C3(40, 42, 50), Enum.Material.Metal)
		Make.disc(lamp, 'Pole', hgt, 0.5, base * CF(0, hgt / 2, 0), C3(46, 48, 58), Enum.Material.Metal, { CastShadow = true })
		Make.part(lamp, 'Arm', V3(3.6, 0.32, 0.32), base * CF(-sx * 1.7, hgt - 0.1, 0), C3(46, 48, 58), Enum.Material.Metal)
		Make.part(lamp, 'Hood', V3(1.8, 0.45, 1.1), base * CF(-sx * 3.3, hgt - 0.25, 0), C3(40, 42, 50), Enum.Material.Metal)
		local head = Make.part(lamp, 'Head', V3(1.4, 0.18, 0.85), base * CF(-sx * 3.3, hgt - 0.55, 0), C3(255, 206, 140), Enum.Material.Neon)
		local light = Make.light(head, C3(255, 214, 160), 1.6, 22)
		table.insert(job.lamps, { head = head, light = light, color = head.Color })
	end
	-- speaker stacks behind the lamps (they bump on impacts)
	job.speakers = {}
	for _, sx in { -1, 1 } do
		local base = w(sx * (R + 8.5 * G), 0, R * 0.35 + 1)
		local parts = {}
		for k = 0, 1 do
			local cy = 1.5 * G + k * 3 * G
			table.insert(parts, Make.part(folder, 'Speaker', V3(3 * G, 2.9 * G, 2.4 * G), base * CF(0, cy, 0) * ANG(0, sx * 0.35, 0), C3(30, 30, 36), Enum.Material.SmoothPlastic, { CastShadow = true }))
			table.insert(parts, Make.disc(folder, 'Cone', 0.12, 1.9 * G, base * CF(0, cy, 0) * ANG(0, sx * 0.35, 0) * CF(0, 0, -1.22 * G) * ANG(PI / 2, 0, 0), C3(70, 72, 80), Enum.Material.SmoothPlastic))
			table.insert(parts, Make.disc(folder, 'ConeRing', 0.1, 0.7 * G, base * CF(0, cy, 0) * ANG(0, sx * 0.35, 0) * CF(0, 0, -1.3 * G) * ANG(PI / 2, 0, 0), th.Rim, Enum.Material.Neon))
		end
		table.insert(job.speakers, { actor = Actor.new(parts, base), base = base })
	end
	-- the fence along both sides of the deck, and a water tower behind the wall
	local fz0, fz1 = -deckW * 0.3, wz + 2
	for _, sx in { -1, 1 } do
		local x = sx * (deckW / 2 - 0.5)
		for k = 0, 5 do
			local z = M.lerp(fz0, fz1, k / 5)
			Make.part(folder, 'FencePost', V3(0.25, 5 * G, 0.25), w(x, 2.5 * G, z), C3(110, 114, 124), Enum.Material.Metal)
		end
		for _, y in { 1.2 * G, 4.8 * G } do
			Make.part(folder, 'FenceRail', V3(0.18, 0.18, fz1 - fz0), w(x, y, (fz0 + fz1) / 2), C3(120, 124, 134), Enum.Material.Metal)
		end
		Make.part(folder, 'FenceMesh', V3(0.06, 3.6 * G, fz1 - fz0), w(x, 3 * G, (fz0 + fz1) / 2), C3(150, 156, 168), Enum.Material.ForceField, { Transparency = 0.6 })
	end
	local tw = w(wallW * 0.42, 0, wz + 9 * G)
	for _, e in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
		Make.part(folder, 'TowerLeg', V3(0.5, wallH + 4 * G, 0.5), tw * CF(e[1] * 2.6 * G, (wallH + 4 * G) / 2, e[2] * 2.6 * G), C3(84, 64, 54), Enum.Material.Wood)
	end
	Make.disc(folder, 'Tank', 6 * G, 7.4 * G, tw * CF(0, wallH + 4 * G + 3 * G, 0), C3(132, 96, 74), Enum.Material.WoodPlanks, { CastShadow = true })
	Make.blob(folder, 'TankRoof', V3(8 * G, 3 * G, 8 * G), tw * CF(0, wallH + 4 * G + 6 * G, 0), C3(96, 72, 60), Enum.Material.SmoothPlastic)
	-- the skyline far out (a half ring behind the stage)
	local sky = Instance.new('Model')
	sky.Name = 'Skyline'
	sky.Parent = folder
	for i = 1, 24 do
		local a = math.rad(-82 + (i - 1) * 7.1 + (M.hash(i, 1) - 0.5) * 3)
		local dist = 150 + M.hash(i, 2) * 140
		local wd = 26 + M.hash(i, 3) * 30
		local ht = 50 + M.hash(i, 4) * 80 + (i % 5 == 0 and 50 or 0)
		local cf = w(math.sin(a) * dist, -30 + ht / 2, math.cos(a) * dist + deckW * 0.2) * ANG(0, a + PI, 0)
		Make.part(sky, 'Tower', V3(wd, ht, 22), cf, C3(44, 44, 62):Lerp(C3(70, 66, 92), M.hash(i, 5)), Enum.Material.SmoothPlastic)
		for f = 1, 3 do
			if M.hash(i, 10 + f) > 0.3 then
				local wc = (M.hash(i, 20 + f) > 0.45) and C3(255, 206, 130) or C3(130, 214, 255)
				Make.part(sky, 'Windows', V3(wd * M.lerp(0.35, 0.75, M.hash(i, 30 + f)), 2.2, 0.4), cf * CF(0, -ht / 2 + 30 + f * ht / 4.2, -11.1), wc, Enum.Material.Neon)
			end
		end
	end
	-- the anchor for attachments, beams and point emitters; the box's own light
	job.anchor = Make.part(folder, 'FxAnchor', V3(0.2, 0.2, 0.2), w(0, 0, 0), WHITE, nil, { Transparency = 1 })
	job.boxGlow = Make.part(folder, 'BoxLight', V3(0.2, 0.2, 0.2), w(0, 3, 0), WHITE, nil, { Transparency = 1 })
	job.boxLight = Make.light(job.boxGlow, WHITE, 0, 16)
	-- volumes for the ambient emitters
	job.volumes = {}
	for name, v in { back = { V3(wallW, 10, 6), w(0, wallH + 6, wz - 4) }, sky = { V3(70, 6, 40), w(0, 30 * G, 6) }, floor = { V3(R * 2.4, 0.4, R * 2.4), w(0, 0.5, 0) }, around = { V3(R * 1.7, 7 * G, R * 1.7), w(0, 4.5 * G, 0) } } do
		job.volumes[name] = Make.part(folder, 'Volume_' .. name, v[1], v[2], WHITE, nil, { Transparency = 1 })
	end
	return job
end
-- Once the camera is planned: each side's posters slide along the wall (and up or down) so that, as the hero frame sees
-- it, the side's word sits beside the pair at mid-height, clear of the pair (pairU: its half-width in the frame's
-- -1..1 units) and inside the frame's outer lanes (|u| > 0.8, where the confetti flies); they stay on the wall.
function Stage.framePosters(job, cf, fov, aspect, pairU)
	local wall = job.wallInfo
	if not job.posterGroups or not wall then return end
	local O = job.O
	local ty = math.tan(math.rad(fov / 2))
	local tx = ty * aspect
	local nW = O:VectorToWorldSpace(V3(0, 0, 1))
	local eye = cf.Position
	for _, g in job.posterGroups do
		local wp = g.word
		if not wp then continue end
		local q = cf:PointToObjectSpace(wp.CFrame.Position)
		if q.Z > -1 then continue end
		local side = q.X < 0 and -1 or 1
		local halfU = (wp.Size.X * 0.5) / (-q.Z * tx)
		local u = side * math.clamp(pairU + halfU + 0.05, 0.42, 0.8 - halfU)
		local dirW = cf:VectorToWorldSpace(V3(u * tx, 0.02 * ty, -1))
		local hit = eye + dirW * ((wp.CFrame.Position - eye):Dot(nW) / dirW:Dot(nW))
		local d = O:VectorToObjectSpace(hit - wp.CFrame.Position)
		local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
		for _, p in g.parts do
			local c = O:PointToObjectSpace(p.CFrame.Position)
			local r = math.max(p.Size.X, p.Size.Y) * 0.5
			x0, x1, y0, y1 = math.min(x0, c.X - r), math.max(x1, c.X + r), math.min(y0, c.Y - r), math.max(y1, c.Y + r)
		end
		local dx = math.clamp(d.X, -wall.w / 2 + 0.4 - x0, wall.w / 2 - 0.4 - x1)
		local dy = math.clamp(d.Y, 0.6 - y0, wall.h - 0.4 - y1)
		local shift = O:VectorToWorldSpace(V3(dx, dy, 0))
		for _, p in g.parts do p.CFrame += shift end
	end
end
-- Where a falling bit stops: the pad (inside its radius), the riser, else the deck.
function Stage.floorAt(job)
	return function(p)
		local q = job.O:PointToObjectSpace(p)
		local r = job.riser
		if r and math.abs(q.X) <= r.w / 2 and math.abs(q.Z - r.z) <= r.d / 2 then return job.deckY + r.h end
		if Vector2.new(q.X, q.Z).Magnitude <= job.P.padR then return job.padTop end
		return job.deckY
	end
end

return Kit
