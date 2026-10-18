-- Simulates one Shared/AuraLook spec on a motion3d rig the way HuzzClient/Gameplay/AuraFX builds it in the game, and
-- turns it into render.mjs sprites, ribbons and lights. Used by aura_scene.luau and worn_scene.luau.
-- What it copies from AuraFX (keep the two in step):
--   * emitters: rate (or `every` = a burst of `count` on a beat), life, speed within `spread` of straight up,
--     accel, drag, rotation + RotSpeed, ZOffset (`z`), VelocityInheritance, `offset` studs up from the anchor;
--   * flipbook sheets (`flip`, layouts read from Shared/FxTexture.SHEETS): OneShot = the frame by age / life,
--     Random = one random frame per particle, else a 16 fps loop;
--   * orient = "Flat": a level quad locked to the anchor (sigils, rings, halos) turning with RotSpeed;
--     orient = "Streak": stretched along its flight; squash; Brightness (`bright`); additive when light >= 0.5;
--   * orbs: small neon balls circling the body (AuraLook.orbitAt) with a camera-facing trail;
--   * crescent slashes (AuraLook.slash; the girls' only on the beat) and the PointLight;
--   * the girls' layers (AuraLook.girl): the floor pool and rings following her lower foot (SurfaceGui circles,
--     drawn as render.mjs '@disc' / '@ring' / '@runner' flat pictures), the ring out over the floor and the
--     sparkle burst on the beat (AuraLook.beatAt), flame tongues (Beam Beziers from AuraLook.flameAt, pushed
--     behind her like ZOffset), "Ground" emitters from the pool's square, `stride` puffs, foot/hand trails
--     while she moves, the Secret halo.
-- Pictures are ours from assets/fx (as if the owner had uploaded them).
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Vector3, Color3 = roblox.Vector3, roblox.Color3
local Env = require("./env")

local Sim = {}

-- Flipbook layouts, read from the game's FxTexture so they never drift apart.
Sim.SHEETS = {}
do
	local src = fs.readFile(Env.src .. "/ReplicatedStorage/Shared/FxTexture.lua")
	for name, g in string.gmatch(src, "(%w+)%s*=%s*Enum%.ParticleFlipbookLayout%.Grid(%d)x%d") do
		Sim.SHEETS[name] = tonumber(g)
	end
end

-- (Lune has no Random: a small seeded one)
local state = 7
local rng = {}
function rng:NextNumber()
	state = (state * 1103515245 + 12345) % 2147483648
	return state / 2147483648
end
function rng:NextInteger(a, b)
	return a + math.floor(self:NextNumber() * (b - a + 1))
end
Sim.rng = rng

function Sim.hex(c)
	return string.format("#%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
local hex = Sim.hex

function Sim.sample(seq, t)
	for i = 1, #seq - 1 do
		local a, b = seq[i], seq[i + 1]
		if t <= b[1] then
			local f = if b[1] > a[1] then (t - a[1]) / (b[1] - a[1]) else 0
			if typeof(a[2]) == "Color3" then
				return a[2]:Lerp(b[2], f)
			end
			return a[2] + (b[2] - a[2]) * f
		end
	end
	return seq[#seq][2]
end
local sample = Sim.sample

-- Where an emitter sits on a rig (as AuraFX's anchors). "Ground": a random point on the floor pool's square.
function Sim.anchorPos(rig, at, scale, sys)
	local P = rig.parts
	if at == "RightHand" then return P.RightHand.CFrame.Position end
	if at == "LeftHand" then return P.LeftHand.CFrame.Position end
	if at == "Head" then return P.Head.CFrame.Position end
	if at == "Ground" and sys and sys.poolAt then
		local r = sys.poolRadius
		return sys.poolAt + Vector3.new((rng:NextNumber() * 2 - 1) * r, 0, (rng:NextNumber() * 2 - 1) * r)
	end
	if at == "Feet" or at == "Ground" then return rig.root.CFrame.Position - Vector3.new(0, 2.6 * scale, 0) end
	return P.UpperTorso.CFrame.Position
end
local anchorPos = Sim.anchorPos

-- As AuraFX's measure(): how far below the root her feet are and how far above it her head's top is.
local function measure(rig, scale)
	local low, high = math.huge, -math.huge
	local ry = rig.root.CFrame.Position.Y
	for name, p in rig.parts do
		if not p.hidden and name ~= "HumanoidRootPart" and p ~= rig.root then
			local y, h = p.CFrame.Position.Y, p.Size.Y / 2
			low, high = math.min(low, y - h), math.max(high, y + h)
		end
	end
	local drop = if low < math.huge and ry - low > 0.2 * scale then ry - low else 2.6 * scale
	local top = if high > -math.huge and high - ry > 0.2 * scale then high - ry else 2.2 * scale
	return drop, top
end
local function feetY(rig)
	local y = math.huge
	for _, n in { "LeftFoot", "RightFoot" } do
		local f = rig.parts[n]
		if f then y = math.min(y, f.CFrame.Position.Y - f.Size.Y / 2) end
	end
	return y
end

-- opts.inherit: the rig really moves (the player), so VelocityInheritance applies; opts.AuraLook for the slashes
-- and the girls' layers (beat, flames, orbits); opts.ground = false: no floor layers (as AuraFX).
function Sim.new(rig, spec, opts)
	opts = opts or {}
	local scale = spec.scale or 1
	local sys = {
		rig = rig, spec = spec, particles = {}, acc = {}, beats = {}, slashes = {}, clock = 0, nextSlash = 0,
		seed = rng:NextInteger(1, 1e5), on = true, inherit = opts.inherit, AuraLook = opts.AuraLook, orbs = {},
		strides = {}, wakes = {}, moving = false, speed = 0,
	}
	sys.drop, sys.top = measure(rig, scale)
	sys.phase = rng:NextNumber() * (if spec.beat then spec.beat.every else 3)
	sys.lastU = if spec.beat then sys.phase % spec.beat.every else 0
	if spec.ground and opts.ground ~= false then
		sys.poolRadius = spec.ground.radius * scale
		if opts.standRadius then sys.poolRadius = math.min(sys.poolRadius, opts.standRadius * 1.1) end
		sys.groundY = rig.root.CFrame.Position.Y - sys.drop
	end
	for i, e in spec.emitters do
		if e.every then sys.beats[i] = rng:NextNumber() * e.every end
	end
	local O = spec.orbs
	if O then
		local n = O.count
		for i = 1, n do
			table.insert(sys.orbs, { i = i, n = n, trail = {}, colors = if O.colors2 and i % 2 == 0 then O.colors2 else O.colors })
		end
	end
	if spec.wake then
		local function wake(name, life, w)
			table.insert(sys.wakes, { part = name, life = life, w = w, pts = {} })
		end
		if spec.wake.feet then
			wake("LeftFoot", 0.35, 0.35 * scale)
			wake("RightFoot", 0.35, 0.35 * scale)
		end
		if spec.wake.hands then
			wake("RightHand", 0.25, 0.5 * scale)
			wake("LeftHand", 0.25, 0.5 * scale)
		end
	end
	return sys
end

local function spawn(sys, e, scale, rigVel)
	local p = anchorPos(sys.rig, e.at, scale, sys) + Vector3.new(0, (e.offset or 0) * scale, 0)
	local v
	if e.orient == "Flat" or e.locked then
		v = Vector3.zero
	else
		-- a direction within `spread` degrees of straight up
		local yaw = rng:NextNumber() * math.pi * 2
		local tilt = math.rad(e.spread) * math.sqrt(rng:NextNumber())
		local dir = Vector3.new(math.sin(tilt) * math.cos(yaw), math.cos(tilt), math.sin(tilt) * math.sin(yaw))
		v = dir * (e.speed[1] + rng:NextNumber() * (e.speed[2] - e.speed[1])) * scale + rigVel * (e.inherit or 0)
	end
	local g = e.flip and Sim.SHEETS[e.texture]
	table.insert(sys.particles, {
		e = e, p = p, v = v, age = 0, life = e.life[1] + rng:NextNumber() * (e.life[2] - e.life[1]),
		rot = e.rot[1] + rng:NextNumber() * (e.rot[2] - e.rot[1]), spin = e.spin[1] + rng:NextNumber() * (e.spin[2] - e.spin[1]),
		frame = if g then rng:NextInteger(0, g * g - 1) else nil,
		locked = e.orient == "Flat" or e.locked,
		rel = if e.orient == "Flat" or e.locked then Vector3.new(0, (e.offset or 0) * scale, 0) else nil,
	})
end

local function orbPos(sys, o)
	local O, scale = sys.spec.orbs, sys.spec.scale or 1
	return anchorPos(sys.rig, "Body", scale) + sys.AuraLook.orbitAt(O, o.i, o.n, sys.clock) * scale
end

local function wakePoint(sys, w)
	local part = sys.rig.parts[w.part]
	if not part then return nil end
	local c = part.CFrame
	if w.part == "LeftFoot" or w.part == "RightFoot" then
		return c.Position - Vector3.new(0, part.Size.Y / 2 - 0.22 * (sys.spec.scale or 1), 0)
	end
	return c.Position
end

function Sim.step(sys, dt)
	local spec, scale = sys.spec, sys.spec.scale or 1
	sys.clock += dt
	local here = sys.rig.root.CFrame.Position
	local rigVel = if sys.lastAt and sys.inherit then (here - sys.lastAt) / dt else Vector3.zero
	local flat = if sys.lastAt then Vector3.new(here.X - sys.lastAt.X, 0, here.Z - sys.lastAt.Z).Magnitude else 0
	sys.lastAt = here
	sys.speed += (flat / dt - sys.speed) * math.min(1, dt * 8)
	sys.moving = if sys.moving then sys.speed > 1.2 * scale else sys.speed > 2.5 * scale
	-- the beat (as AuraFX): energy for the flames and the pool, the ring out over the floor, sparkles, a slash
	local B = spec.beat
	local energy, shock, breathe = 1, -1, 0
	if sys.AuraLook and spec.ground then
		energy, shock, breathe = sys.AuraLook.beatAt(B, sys.clock + sys.phase)
	end
	sys.energy, sys.shock, sys.breathe = energy, shock, breathe
	local fired = false
	if B then
		local u = (sys.clock + sys.phase) % B.every
		fired = u < sys.lastU
		sys.lastU = u
	end
	-- the floor pool follows her feet (the lower foot; rising slowly)
	if sys.poolRadius then
		local y = feetY(sys.rig)
		if y == math.huge then y = here.Y - sys.drop end
		if math.abs(y - sys.groundY) > 4 * scale or y < sys.groundY then sys.groundY = y else sys.groundY += (y - sys.groundY) * math.min(1, dt * 3) end
		sys.poolAt = Vector3.new(here.X, sys.groundY + 0.04 * scale, here.Z)
	end
	if sys.on then
		for i, e in spec.emitters do
			if e.every then
				if sys.clock >= sys.beats[i] then
					sys.beats[i] = sys.clock + e.every
					for _ = 1, e.count or 1 do spawn(sys, e, scale, rigVel) end
				end
			elseif e.stride then
				sys.strides[i] = (sys.strides[i] or 0) + flat
				if sys.strides[i] >= e.stride * scale then
					sys.strides[i] = 0
					for _ = 1, e.count or 1 do spawn(sys, e, scale, rigVel) end
				end
			elseif e.name == "Burst" and B then
				if fired then
					for _ = 1, B.burst do spawn(sys, e, scale, rigVel) end
				end
			else
				sys.acc[i] = (sys.acc[i] or 0) + e.rate * dt
				while sys.acc[i] >= 1 do
					sys.acc[i] -= 1
					spawn(sys, e, scale, rigVel)
				end
			end
		end
		local S = spec.slashes
		if S and S.onBeat then
			if fired then
				sys.seed += 1
				table.insert(sys.slashes, { born = sys.clock, seed = sys.seed })
			end
		elseif S and sys.clock >= sys.nextSlash then
			sys.nextSlash = sys.clock + (0.6 + rng:NextNumber() * 0.8) / S.rate
			sys.seed += 1
			table.insert(sys.slashes, { born = sys.clock, seed = sys.seed })
		end
		for _, o in sys.orbs do
			table.insert(o.trail, 1, { p = orbPos(sys, o), t = sys.clock })
		end
		for _, w in sys.wakes do
			if sys.moving then
				local p = wakePoint(sys, w)
				if p then table.insert(w.pts, 1, { p = p, t = sys.clock }) end
			end
		end
	end
	for _, o in sys.orbs do -- the trail keeps its lifetime of points
		while #o.trail > 0 and sys.clock - o.trail[#o.trail].t > (spec.orbs.trail or 0.35) do
			table.remove(o.trail)
		end
	end
	for _, w in sys.wakes do
		while #w.pts > 0 and sys.clock - w.pts[#w.pts].t > w.life do
			table.remove(w.pts)
		end
	end
	local alive = {}
	for _, q in sys.particles do
		q.age += dt
		if q.age < q.life then
			if not q.locked then
				local a = q.e.accel
				q.v += Vector3.new(a[1], a[2], a[3]) * scale * dt
				q.v *= math.max(0, 1 - (q.e.drag or 0) * dt)
				q.p += q.v * dt
			end
			q.rot += q.spin * dt
			table.insert(alive, q)
		end
	end
	sys.particles = alive
end

function Sim.alive(sys)
	if sys.on or #sys.particles > 0 or #sys.slashes > 0 then return true end
	for _, o in sys.orbs do
		if #o.trail > 0 then return true end
	end
	return false
end

local function r3(v) return math.floor(v * 1000 + 0.5) / 1000 end
local function v3(p) return { r3(p.X), r3(p.Y), r3(p.Z) } end

-- A trail of timed points as a fading, narrowing ribbon: white at the head, her colour, then the deep tone.
local function trailRibbon(ribbons, clock, list, life, width, colors, alpha0)
	if #list < 2 then return end
	local pts, w, a, cs = {}, {}, {}, {}
	for _, k in list do
		local u = math.clamp((clock - k.t) / life, 0, 1)
		table.insert(pts, v3(k.p))
		table.insert(w, r3(width * (1 - u)))
		table.insert(a, r3(1 - (alpha0 + (1 - alpha0) * u)))
		local c = if u < 0.25 then colors[1]:Lerp(colors[2], u / 0.25) else colors[2]:Lerp(colors[3], (u - 0.25) / 0.75)
		table.insert(cs, hex(c))
	end
	table.insert(ribbons, { pts = pts, w = w, a = a, c = cs[1], cs = cs, add = true })
end

-- Appends this frame's sprites, ribbons and lights (lights optional). cam: the camera position (for ZOffset).
function Sim.draw(sys, cam, sprites, ribbons, lights)
	local spec, scale = sys.spec, sys.spec.scale or 1
	local big = scale > 1.5
	local glow = if big then 0.45 else 1
	local on = sys.on
	-- the floor pool and rings (SurfaceGui circles: drawn flat, Brightness 1.4)
	local G = spec.ground
	if G and sys.poolAt and on then
		local d = sys.poolRadius * 2 * (1 + G.breathe * sys.breathe) * (0.92 + 0.08 * sys.energy)
		local at = v3(sys.poolAt)
		local function flatPic(t, size, color, alpha, b, r, add)
			table.insert(sprites, { p = at, s = r3(size), c = hex(color), a = r3(alpha), t = t, flat = true, b = b, r = r, add = add })
		end
		local white, main, deep = G.colors[1], G.colors[2], G.colors[3]
		if G.pool then
			local sizes = { 1, 0.7, 0.42 }
			local tones = { deep:Lerp(main, 0.5), main, white }
			for i, tr in G.pool do flatPic("@disc", sizes[i] * 0.9 * d, tones[i], 1 - tr, 1.4 * glow) end
		end
		local function px(width, frac) return math.max(1, math.floor(width * 256 / (256 * frac + width) + 0.5)) end
		if G.ring then
			local frac = 0.88
			if G.runner then
				-- (a white stroke under a gradient white -> her colours -> white: her colour in the middle, two white ends)
				flatPic("@ring" .. px(7, frac), (frac + 7 / 256) * d, main, (1 - G.ring) * 0.45, 1.4 * glow)
				flatPic("@runner" .. px(7, frac), (frac + 7 / 256) * d, Color3.new(1, 1, 1), 1 - G.ring, 1.4 * glow, (sys.clock * G.spin) % 360)
			else
				flatPic("@ring" .. px(7, frac), (frac + 7 / 256) * d, main, 1 - G.ring, 1.4 * glow)
			end
		end
		if G.inner then
			flatPic("@ring" .. px(3, 0.6), (0.6 + 3 / 256) * d, white, 1 - math.min(1, (G.ring or 0.4) + 0.3), 1.4 * glow)
		end
		if spec.beat and spec.beat.shock and sys.shock >= 0 then
			local k = 1 - (1 - sys.shock) ^ 3
			local sd = sys.poolRadius * 2 * (0.9 + 1.5 * k)
			local thick = 10 * (1 - 0.6 * sys.shock)
			flatPic("@ring" .. px(thick, 0.96), (0.96 + thick / 256) * sd, white:Lerp(main, 0.4), 1 - (0.15 + 0.85 * sys.shock), 1.6 * glow)
		end
	end
	-- the halo over her head (Secret)
	if spec.halo and on then
		local head = sys.rig.parts.Head
		local p = head.CFrame.Position + Vector3.new(0, head.Size.Y / 2 + 0.35 * scale + 0.05 * scale * sys.breathe, 0)
		local d = spec.halo.radius * 2 * scale
		table.insert(sprites, { p = v3(p), s = r3((0.9 + 14 / 256) * d), c = hex(spec.halo.colors[2]), a = 0.9, t = "@ring16", flat = true, b = 1.6 * glow })
		table.insert(sprites, { p = v3(p), s = r3((0.9 + 5 / 256) * d), c = hex(spec.halo.colors[1]), a = 0.7, t = "@ring6", flat = true, b = 1.6 * glow })
	end
	for _, q in sys.particles do
		local e = q.e
		local t = q.age / q.life
		local at = if q.locked then anchorPos(sys.rig, e.at, scale, nil) + q.rel else q.p
		if (e.z or 0) ~= 0 then
			at += (cam - at).Unit * e.z * scale -- ZOffset: drawn that much closer to the camera
		end
		local g = e.flip and Sim.SHEETS[e.texture]
		local frame = nil
		if g then
			local n = g * g
			if e.flip == "OneShot" then
				frame = math.min(n - 1, math.floor(t * n))
			elseif e.flip == "Random" then
				frame = q.frame
			else
				frame = math.floor(q.age * (e.fps or 16)) % n
			end
		end
		local sq = if e.squash then sample(e.squash, t) else nil
		table.insert(sprites, {
			p = v3(at), s = r3(sample(e.size, t) * scale), c = hex(sample(e.colors, t)),
			a = r3(math.clamp(1 - sample(e.alpha, t), 0, 1)), t = e.texture, r = r3(q.rot), add = e.light >= 0.5,
			b = if e.bright and e.bright ~= 1 then e.bright else nil, g = g or nil, f = frame,
			flat = if e.orient == "Flat" then true else nil, sq = sq,
			v = if e.orient == "Streak" then v3(q.v) else nil,
		})
	end
	-- flame tongues (Beams from her feet to over her head, bent along their attachments' X axes, pushed behind her)
	local F = spec.flames
	if F and on and sys.AuraLook then
		local root = sys.rig.root.CFrame
		local white, main, accent, deep = F.colors[1], F.colors[2], F.colors[3], F.colors[4] or F.colors[2]
		local outerA = { { 0, 1 }, { 0.15, 0.4 }, { 0.5, 0.45 }, { 0.85, 0.7 }, { 1, 1 } }
		local coreA = { { 0, 1 }, { 0.15, 0.35 }, { 0.6, 0.5 }, { 1, 1 } }
		for _, core in { false, true } do
			local n = if core then F.core else F.count
			for i = 1, n do
				local d0, d1 = sys.AuraLook.flameDirs(F, i, core)
				local p0, p1, c0, c1, w0, w1 = sys.AuraLook.flameAt(F, i, core, sys.clock, sys.energy, sys.phase)
				local A = root:PointToWorldSpace(Vector3.new(p0.X * scale, -sys.drop + 0.08 * scale, p0.Z * scale))
				local Bp = root:PointToWorldSpace(Vector3.new(p1.X * scale, sys.top + (p1.Y - 2.2) * scale, p1.Z * scale))
				local P1 = A + root:VectorToWorldSpace(d0) * c0 * scale
				local P2 = Bp - root:VectorToWorldSpace(d1) * c1 * scale
				local z = F.radius * (F.behind or (if core then 1.2 else 1.5)) * scale
				local tone = if i % 2 == 0 then accent else main
				local pts, w, a, cs = {}, {}, {}, {}
				for k = 0, 14 do
					local u = k / 14
					local b = A * (1 - u) ^ 3 + P1 * 3 * (1 - u) ^ 2 * u + P2 * 3 * (1 - u) * u ^ 2 + Bp * u ^ 3
					b -= (cam - b).Unit * z -- ZOffset negative: away from the camera, behind her body
					table.insert(pts, v3(b))
					table.insert(w, r3((w0 + (w1 - w0) * u) * scale))
					table.insert(a, r3((1 - sample(if core then coreA else outerA, u)) * (if core then 1 else 0.9)))
					local c = if core then Color3.new(1, 1, 1):Lerp(white, u) elseif u < 0.55 then tone:Lerp(Color3.new(1, 1, 1), 0.25):Lerp(tone, u / 0.55) else tone:Lerp(tone:Lerp(deep, 0.45), (u - 0.55) / 0.45)
					table.insert(cs, hex(c))
				end
				table.insert(ribbons, { pts = pts, w = w, a = a, c = cs[1], cs = cs, add = core }) -- (LightEmission 1 core, 0.35 outer)
			end
		end
	end
	-- orbiting lights: a small neon ball (a bright disc and a soft glow) with a trail
	local O = spec.orbs
	if O then
		local s = (if O.ball then O.size else O.size * 0.25) * scale
		for _, o in sys.orbs do
			trailRibbon(ribbons, sys.clock, o.trail, O.trail or 0.35, s * 0.9, { Color3.new(1, 1, 1), o.colors[2], o.colors[3] }, 0.1)
			if on and o.trail[1] then
				local p = v3(o.trail[1].p)
				table.insert(sprites, { p = p, s = r3(s * 3.2), c = hex(o.colors[2]), a = 0.55 * glow, t = "Glow", add = true })
				table.insert(sprites, { p = p, s = r3(s), c = hex(o.colors[2]:Lerp(Color3.new(1, 1, 1), 0.55)), a = 1, t = "@disc", b = 1.3 })
			end
		end
	end
	-- trails on her feet and hands while she moves
	if spec.wake then
		local W = spec.wake
		for _, w in sys.wakes do
			trailRibbon(ribbons, sys.clock, w.pts, w.life, w.w, W.colors, 0.35)
		end
	end
	if lights and spec.light and on then
		local p = anchorPos(sys.rig, spec.light.at or "Body", scale)
		local bright = spec.light.brightness * (if big then 0.3 else 1) * (if spec.ground then 0.8 + 0.2 * sys.energy else 1)
		local range = if big then math.min(spec.light.range * 1.3, 10) else spec.light.range * scale
		table.insert(lights, { p = v3(p), c = hex(spec.light.color), b = bright, r = range })
	end
	local S = spec.slashes
	if not S then
		return
	end
	local keep = {}
	for _, sl in sys.slashes do
		local age = sys.clock - sl.born
		if age <= S.life then
			table.insert(keep, sl)
			local centre = anchorPos(sys.rig, "Body", scale)
			local p0, pm, p1, t0, tm, t1, curve, alpha, width = sys.AuraLook.slash(S, sl.seed, age, centre, scale)
			for _, layer in { { S.edge, 1.7, 0.15, false }, { S.core, 1, 0, true } } do
				local pts, w, a = {}, {}, {}
				for half = 1, 2 do
					local A, B = if half == 1 then p0 else pm, if half == 1 then pm else p1
					local tA, tB = if half == 1 then t0 else tm, if half == 1 then tm else t1
					local c0, c1 = A + tA * curve, B - tB * curve
					for k = (if half == 1 then 0 else 1), 8 do
						local u = k / 8
						local b = A * (1 - u) ^ 3 + c0 * 3 * (1 - u) ^ 2 * u + c1 * 3 * (1 - u) * u ^ 2 + B * u ^ 3
						table.insert(pts, v3(b))
						table.insert(w, r3(width * layer[2] * (if half == 1 then u else 1 - u)))
						table.insert(a, r3(math.clamp(1 - (alpha + layer[3]), 0, 1)))
					end
				end
				table.insert(ribbons, { pts = pts, w = w, a = a, c = hex(layer[1]), add = layer[4] })
			end
		end
	end
	sys.slashes = keep
end

return Sim
