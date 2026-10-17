-- Simulates one Shared/AuraLook spec on a motion3d rig the way HuzzClient/Gameplay/AuraFX builds it in the game, and
-- turns it into render.mjs sprites, ribbons and lights. Used by aura_scene.luau and worn_scene.luau.
-- What it copies from AuraFX (keep the two in step):
--   * emitters: rate (or `every` = a burst of `count` on a beat), life, speed within `spread` of straight up,
--     accel, drag, rotation + RotSpeed, ZOffset (`z`), VelocityInheritance, `offset` studs up from the anchor;
--   * flipbook sheets (`flip`, layouts read from Shared/FxTexture.SHEETS): OneShot = the frame by age / life,
--     Random = one random frame per particle, else a 16 fps loop;
--   * orient = "Flat": a level quad locked to the anchor (sigils, rings, halos) turning with RotSpeed;
--     orient = "Streak": stretched along its flight; squash; Brightness (`bright`); additive when light >= 0.5;
--   * orbs: glow dots circling the body (a short glow stream each) with a camera-facing Streak trail (0.35 s);
--   * crescent slashes (AuraLook.slash) and the PointLight.
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

-- Where an emitter sits on a rig (as AuraFX's anchors).
function Sim.anchorPos(rig, at, scale)
	local P = rig.parts
	if at == "RightHand" then return P.RightHand.CFrame.Position end
	if at == "LeftHand" then return P.LeftHand.CFrame.Position end
	if at == "Head" then return P.Head.CFrame.Position end
	if at == "Feet" then return rig.root.CFrame.Position - Vector3.new(0, 2.6 * scale, 0) end
	return P.UpperTorso.CFrame.Position
end
local anchorPos = Sim.anchorPos

-- opts.inherit: the rig really moves (the player), so VelocityInheritance applies; opts.AuraLook for the slashes.
function Sim.new(rig, spec, opts)
	opts = opts or {}
	local sys = {
		rig = rig, spec = spec, particles = {}, acc = {}, beats = {}, slashes = {}, clock = 0, nextSlash = 0,
		seed = rng:NextInteger(1, 1e5), on = true, inherit = opts.inherit, AuraLook = opts.AuraLook, orbs = {},
	}
	for i, e in spec.emitters do
		if e.every then sys.beats[i] = rng:NextNumber() * e.every end
	end
	local O = spec.orbs
	if O then
		for i = 1, O.count do
			table.insert(sys.orbs, { phase = (i - 1) / O.count * math.pi * 2, tilt = (i % 2 * 2 - 1) * math.rad(O.tilt or 0), trail = {}, acc = 0 })
		end
		-- the dot: AuraFX's "Dot" ParticleEmitter (Glow, 40 a second, 0.12-0.18 s, Brightness 2)
		sys.dot = {
			name = "OrbDot", texture = "Glow", colors = { { 0, Color3.new(1, 1, 1) }, { 1, O.colors[2] } }, light = 1, bright = 2,
			size = { { 0, O.size }, { 1, O.size * 0.4 } }, alpha = { { 0, 0.1 }, { 1, 1 } }, accel = { 0, 0, 0 },
		}
	end
	return sys
end

local function spawn(sys, e, scale, rigVel)
	local p = anchorPos(sys.rig, e.at, scale) + Vector3.new(0, (e.offset or 0) * scale, 0)
	local v
	if e.orient == "Flat" then
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
	local c = anchorPos(sys.rig, "Body", scale)
	local a = sys.clock * O.speed + o.phase
	local flat = Vector3.new(math.cos(a), 0, math.sin(a)) * O.radius * scale
	local ct, st = math.cos(o.tilt), math.sin(o.tilt) -- CFrame.Angles(tilt, 0, 0): a turn about X
	local tilted = Vector3.new(flat.X, flat.Y * ct - flat.Z * st, flat.Y * st + flat.Z * ct)
	return c + tilted + Vector3.new(0, (O.height or 0.3) + math.sin(sys.clock * 2 * math.pi * 1.3 + o.phase) * (O.bob or 0.4), 0) * scale
end

function Sim.step(sys, dt)
	local spec, scale = sys.spec, sys.spec.scale or 1
	sys.clock += dt
	local here = sys.rig.root.CFrame.Position
	local rigVel = if sys.lastAt and sys.inherit then (here - sys.lastAt) / dt else Vector3.zero
	sys.lastAt = here
	if sys.on then
		for i, e in spec.emitters do
			if e.every then
				if sys.clock >= sys.beats[i] then
					sys.beats[i] = sys.clock + e.every
					for _ = 1, e.count or 1 do spawn(sys, e, scale, rigVel) end
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
		if S and sys.clock >= sys.nextSlash then
			sys.nextSlash = sys.clock + (0.6 + rng:NextNumber() * 0.8) / S.rate
			sys.seed += 1
			table.insert(sys.slashes, { born = sys.clock, seed = sys.seed })
		end
		for _, o in sys.orbs do
			local pos = orbPos(sys, o)
			table.insert(o.trail, 1, { p = pos, t = sys.clock })
			o.acc += 40 * dt
			while o.acc >= 1 do
				o.acc -= 1
				table.insert(sys.particles, { e = sys.dot, p = pos, v = Vector3.zero, age = 0, life = 0.12 + rng:NextNumber() * 0.06, rot = 0, spin = 0 })
			end
		end
	end
	for _, o in sys.orbs do -- the trail keeps 0.35 s of points
		while #o.trail > 0 and sys.clock - o.trail[#o.trail].t > (spec.orbs.trail or 0.35) do
			table.remove(o.trail)
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

-- Appends this frame's sprites, ribbons and lights (lights optional). cam: the camera position (for ZOffset).
function Sim.draw(sys, cam, sprites, ribbons, lights)
	local spec, scale = sys.spec, sys.spec.scale or 1
	for _, q in sys.particles do
		local e = q.e
		local t = q.age / q.life
		local at = if q.locked then anchorPos(sys.rig, e.at, scale) + q.rel else q.p
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
			p = { r3(at.X), r3(at.Y), r3(at.Z) }, s = r3(sample(e.size, t) * scale), c = hex(sample(e.colors, t)),
			a = r3(math.clamp(1 - sample(e.alpha, t), 0, 1)), t = e.texture, r = r3(q.rot), add = e.light >= 0.5,
			b = if e.bright and e.bright ~= 1 then e.bright else nil, g = g or nil, f = frame,
			flat = if e.orient == "Flat" then true else nil, sq = sq,
			v = if e.orient == "Streak" then { r3(q.v.X), r3(q.v.Y), r3(q.v.Z) } else nil,
		})
	end
	-- orb trails: camera-facing Streak ribbons, white at the orb, her colour, then the deep tone, fading and narrowing
	local O = spec.orbs
	if O then
		local life = O.trail or 0.35
		local W = 0.32 * scale
		for _, o in sys.orbs do
			if #o.trail >= 2 then
				local pts, w, a, cs = {}, {}, {}, {}
				for _, k in o.trail do
					local u = math.clamp((sys.clock - k.t) / life, 0, 1)
					table.insert(pts, { r3(k.p.X), r3(k.p.Y), r3(k.p.Z) })
					table.insert(w, r3(W * (1 - u)))
					table.insert(a, r3(1 - (0.1 + 0.9 * u)))
					local c = if u < 0.25 then Color3.new(1, 1, 1):Lerp(O.colors[2], u / 0.25) else O.colors[2]:Lerp(O.colors[3], (u - 0.25) / 0.75)
					table.insert(cs, hex(c))
				end
				table.insert(ribbons, { pts = pts, w = w, a = a, c = cs[1], cs = cs, add = true, t = "Streak" })
			end
		end
	end
	if lights and spec.light and sys.on then
		local p = anchorPos(sys.rig, spec.light.at or "Body", scale)
		table.insert(lights, { p = { r3(p.X), r3(p.Y), r3(p.Z) }, c = hex(spec.light.color), b = spec.light.brightness, r = spec.light.range * scale })
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
						table.insert(pts, { r3(b.X), r3(b.Y), r3(b.Z) })
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
