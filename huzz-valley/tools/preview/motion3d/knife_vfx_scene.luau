-- The knife effects (owner, Oct 20: "make the vfx for some swords way better and more detailed, make them better for
-- more high end ones"; "check out the references provided from Huss valley ... Make them fit and logically connected
-- to the skin of the sword"), filmed from the game's own code: the real HuzzServer/KnifeService builds each knife
-- (template / display) and Shared/KnifeFx puts its effects on, then this file runs every ParticleEmitter it made
-- (rate, life, speed, Box / inward Sphere shapes, acceleration, drag, size and see-through over life, spin, squash,
-- locked or loose, attachments on the gem and tip) and draws them with his meshes.
-- Roblox's built-in pictures are drawn with ours that look like them (sparkles_main = assets/fx star-flare,
-- fire_main = flame, smoke_main = glow): shapes and colours read right, the exact look is Studio's.
--   MODE=sheet (default): 8 knives across the tiers, each in a body's hand (still 2i-2, about 3.5 studs away) and as
--     the lobby stands' big copy (still 2i-1), then Celestial Seraph worn on the back from behind (the last still,
--     framed like Huss Valley's MELON5MAN in docs/previews/knife-vfx-hv-reference.jpg);
--     python3 -I huzz-valley/tools/preview/motion3d/knife_vfx_sheet.py <dir> makes docs/previews/knife-vfx-sheet.jpg
--     and docs/previews/knife-vfx-vs-hv.jpg.
--   MODE=film: three top knives (Dragon's Maw, Frostbound Oath, Abyss Eclipse) in hand, slashing every 2 s (staggered)
--     with their trail and slash sparkles, 6 s at 30 fps: docs/previews/knife-vfx.mp4.
-- From the repo root: KNIFE_MESHES=<python3 -I huzz-valley/tools/knives/knife_meshes.py file> MOTION3D_KEEP=<dir> \
--   sh huzz-valley/tools/preview/motion3d/video.sh huzz-valley/tools/preview/motion3d/knife_vfx_scene.luau out.mp4
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local CFrame, Vector3, Color3, Instance = roblox.CFrame, roblox.Vector3, roblox.Color3, roblox.Instance
local Rig = require("./rig")
local Scene = require("./scene")
local KFS = require("./kfs")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local ROOT = "huzz-valley/"
local CoinShop = Env.load(SHARED .. "Config/CoinShop.lua")
local KnifeLook = Env.load(SHARED .. "KnifeLook.lua")
local Mix = Env.load(SHARED .. "LocomotionMix.lua")

local MODE = process.env.MODE or "sheet"
local MESHES = process.env.KNIFE_MESHES or error("set KNIFE_MESHES (python3 -I tools/knives/knife_meshes.py <file>)")
local baked = {}
for _, k in serde.decode("json", fs.readFile(ROOT .. "tools/knives/knives.json")) do baked[k.key] = k end

-- the real KnifeService and KnifeFx (as tests/KnifeWear.spec loads them)
local game = Instance.new("DataModel")
local ServerStorage = game:GetService("ServerStorage")
roblox.deserializeModel(fs.readFile(ROOT .. "assets/knives/HuzzKnives.rbxm"))[1].Parent = ServerStorage
local FxTexture = { get = function() return "" end, flipbook = function() end, ready = function() return false end }
local shared = { KnifeLook = KnifeLook, FxTexture = FxTexture, KnifeShapes = Env.load(SHARED .. "KnifeShapes.lua") }
local fakeRS = { Shared = { KnifeLook = "KnifeLook", FxTexture = "FxTexture", KnifeShapes = "KnifeShapes", KnifeFx = "KnifeFx" } }
local env = {
	game = { GetService = function(_, name) return if name == "ServerStorage" then ServerStorage else fakeRS end },
	require = function(x) return shared[x] or error("no module " .. tostring(x)) end,
	warn = function() end,
	Instance = Instance, CFrame = CFrame, Vector3 = Vector3, Vector2 = roblox.Vector2, Color3 = Color3, Enum = roblox.Enum,
	NumberRange = roblox.NumberRange, NumberSequence = roblox.NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequence = roblox.ColorSequence, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
}
local fxEnv = table.clone(env)
fxEnv.script = { Parent = { KnifeLook = "KnifeLook" } }
shared.KnifeFx = luau.load(fs.readFile(ROOT .. "src/ReplicatedStorage/Shared/KnifeFx.lua"), { debugName = "KnifeFx", environment = fxEnv })()
local KnifeService = luau.load(fs.readFile(ROOT .. "src/ServerScriptService/HuzzServer/KnifeService.lua"), { debugName = "KnifeService", environment = env })()
local KnifeFx = shared.KnifeFx

local lib = Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile(ROOT .. "src/ServerStorage/HuzzAnimations.rbxm")) do inst.Parent = lib end
local Idle = KFS.load(lib:FindFirstChild("Idle", true))

local seedN = 4242
local function rnd() seedN = (seedN * 1103515245 + 12345) % 2147483648; return seedN / 2147483648 end
local function range(a, b) return a + (b - a) * rnd() end
local function hex(c) return string.format("#%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end
local WHITE = Color3.new(1, 1, 1)
local TEX = { sparkles_main = "star-flare", fire_main = "flame", smoke_main = "glow" }

-- .glb axes (blade +Y, thickness Z) into the Handle's (blade +Y, thickness X), origin at the grip (knife_wear_scene).
local TURN = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, -1), Vector3.new(0, 1, 0), Vector3.new(1, 0, 0))
local function meshAt(key, handleCF, scale)
	local k = baked[key]
	local per = k.studs / k.length * scale
	local c = { (handleCF * CFrame.new(0, -k.grip * per, 0) * TURN):GetComponents() }
	return { m = key, p = { c[1], c[2], c[3] }, r = { c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12] }, s = per }
end

local function sample(seq, t)
	local kp = seq.Keypoints
	for i = 1, #kp - 1 do
		if t <= kp[i + 1].Time then
			local a = (t - kp[i].Time) / math.max(kp[i + 1].Time - kp[i].Time, 1e-6)
			return kp[i].Value + (kp[i + 1].Value - kp[i].Value) * a
		end
	end
	return kp[#kp].Value
end
local function sampleColour(seq, t)
	local kp = seq.Keypoints
	for i = 1, #kp - 1 do
		if t <= kp[i + 1].Time then
			return kp[i].Value:Lerp(kp[i + 1].Value, (t - kp[i].Time) / math.max(kp[i + 1].Time - kp[i].Time, 1e-6))
		end
	end
	return kp[#kp].Value
end

-- A knife with its effects, ready to simulate: every emitter's place in the Handle's space.
local function knife(key, where)
	local skin = CoinShop.get(key)
	local model = if where == "stand" then KnifeService.display(skin) else KnifeService.template(skin)
	if where ~= "stand" then KnifeFx.add(model, skin, where) end
	local handle = model:FindFirstChild("Handle", true)
	local h = handle.CFrame
	local function localOf(inst)
		if inst:IsA("Attachment") then return h:ToObjectSpace(inst.Parent.CFrame) * inst.CFrame, nil end
		return h:ToObjectSpace(inst.CFrame), inst.Size
	end
	local list, light = {}, nil
	for _, d in model:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			local cf, size = localOf(d.Parent)
			local shape = "point"
			if size then
				local ok, s = pcall(function() return d.Shape end)
				local ok2, io = pcall(function() return d.ShapeInOut end)
				shape = if ok and s == roblox.Enum.ParticleEmitterShape.Sphere and ok2 and io == roblox.Enum.ParticleEmitterShapeInOut.Inward then "inward" else "box"
			end
			local tex = string.match(d.Texture, "particles/([%w_]+)%.") or "smoke_main"
			table.insert(list, { e = d, cf = cf, size = size, shape = shape, tex = TEX[tex] or "glow", acc = rnd(), parts = {},
				burst = d.Name == "KnifeBurst" })
		elseif d:IsA("PointLight") then
			light = { cf = localOf(d.Parent), l = d }
		end
	end
	local tip = model:FindFirstChild("TrailTip", true)
	local reach = KnifeService.reachOf(model, handle) or 2
	local k = model:GetAttribute("Scale") or 1
	return { key = key, skin = skin, model = model, emit = list, light = light, reach = reach, scale = k,
		trail = KnifeLook.trailLook(skin, KnifeLook.element(key)), history = {}, burst = model:GetAttribute("Burst") or 0,
		tipLocal = if tip then (localOf(tip)).Position else Vector3.new(0, reach, 0) }
end

local function spawn(em, world, handleCF, n)
	local e = em.e
	for _ = 1, n do
		local localP, v
		if em.shape == "box" then
			localP = em.cf * Vector3.new(range(-0.5, 0.5) * em.size.X, range(-0.5, 0.5) * em.size.Y, range(-0.5, 0.5) * em.size.Z)
		elseif em.shape == "inward" then
			local d = Vector3.new(range(-1, 1), range(-1, 1), range(-1, 1))
			d = if d.Magnitude > 1e-3 then d.Unit else Vector3.new(0, 1, 0)
			localP = em.cf * Vector3.new(d.X * em.size.X / 2, d.Y * em.size.Y / 2, d.Z * em.size.Z / 2)
		else
			localP = em.cf.Position
		end
		local speed = range(e.Speed.Min, e.Speed.Max)
		if em.shape == "inward" then
			v = (em.cf.Position - localP).Unit * speed
		else
			local d = Vector3.new(range(-1, 1), range(-1, 1), range(-1, 1))
			v = (if d.Magnitude > 1e-3 then d.Unit else Vector3.new(0, 1, 0)) * speed
		end
		local p = { age = 0, life = range(e.Lifetime.Min, e.Lifetime.Max), rot = range(e.Rotation.Min, e.Rotation.Max),
			spin = range(e.RotSpeed.Min, e.RotSpeed.Max) }
		if e.LockedToPart then
			p.lp, p.lv = localP, v
		else
			p.p = handleCF * localP
			p.v = handleCF:VectorToWorldSpace(v)
		end
		table.insert(em.parts, p)
	end
end

local function step(K, handleCF, dt, sprites, lights, emitAll)
	for _, em in K.emit do
		local e = em.e
		if not em.burst and e.Enabled then
			em.acc += e.Rate * dt
			while em.acc >= 1 do em.acc -= 1; spawn(em, nil, handleCF, 1) end
		end
		if emitAll and em.burst then spawn(em, nil, handleCF, emitAll) end
		local keep = {}
		local drag = 2 ^ (-e.Drag * dt)
		for _, p in em.parts do
			p.age += dt
			if p.age < p.life then
				local a = p.age / p.life
				local pos
				if p.lp then
					p.lv = (p.lv + handleCF:VectorToObjectSpace(e.Acceleration) * dt) * drag
					p.lp += p.lv * dt
					pos = handleCF * p.lp
				else
					p.v = (p.v + e.Acceleration * dt) * drag
					p.p += p.v * dt
					pos = p.p
				end
				p.rot += p.spin * dt
				local size, tr = sample(e.Size, a), sample(e.Transparency, a)
				local sq = sample(e.Squash, a)
				if size > 0.005 and tr < 0.995 then
					table.insert(sprites, { p = { pos.X, pos.Y, pos.Z }, s = size, c = hex(sampleColour(e.Color, a)), a = 1 - tr,
						t = em.tex, r = p.rot, add = e.LightEmission >= 0.5 or nil, sq = if math.abs(sq) > 0.01 then sq else nil })
				end
				table.insert(keep, p)
			end
		end
		em.parts = keep
	end
	if K.light then
		local at = handleCF * K.light.cf.Position
		table.insert(lights, { p = { at.X, at.Y, at.Z }, c = hex(K.light.l.Color), b = K.light.l.Brightness * 0.5, r = K.light.l.Range })
	end
end

local scene = Scene.new()
local FPS = 30
local dt = 1 / FPS

if MODE == "film" then
	local KEYS = { "DragonsMaw", "FrostboundOath", "AbyssEclipse" }
	scene:addBox(CFrame.new(0, -0.05, 0), Vector3.new(30, 0.1, 10), "#2a2a36")
	local list = {}
	for i, key in KEYS do list[i] = { K = knife(key, "hand"), x = (i - 2) * 3.2, phase = (i - 1) * 0.6 } end
	-- the swing (knife_fx_scene's): at rest tilted 25 degrees; every 2 s a cut from +70 to -110 degrees in 0.18 s
	local function angle(t)
		local u = t % 2
		if u < 0.18 then return math.rad(70 - 180 * (u / 0.18)) end
		if u < 0.68 then local a = (u - 0.18) / 0.5; a = a * a * (3 - 2 * a); return math.rad(-110 + 85 * a) end
		if u < 1.7 then return math.rad(-25) end
		local a = (u - 1.7) / 0.3; a = a * a * (3 - 2 * a)
		return math.rad(-25 + 95 * a)
	end
	local function handleAt(s, t) return CFrame.new(s.x, 2.2, 0) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(angle(t + s.phase), 0, 0) end
	local SUB = 4
	local WARM = 2
	for f = -WARM * FPS, 6 * FPS - 1 do
		local t = f / FPS
		local meshes, sprites, ribbons, lights = {}, {}, {}, {}
		for _, s in list do
			local K = s.K
			local u = (t + s.phase) % 2
			local cutNow = u < dt + 1e-6 -- (the slash starts: Actions throws half of Burst)
			for q = SUB - 1, 0, -1 do
				local tt = t - q / (FPS * SUB)
				if (tt + s.phase) % 2 < 0.2 then
					local h = handleAt(s, tt)
					table.insert(K.history, { t = tt, base = h * Vector3.new(0, K.reach * 0.3, 0), tip = h * K.tipLocal })
				end
			end
			local h = handleAt(s, t)
			step(K, h, dt, sprites, lights, if cutNow and K.burst > 0 then math.ceil(K.burst * 0.5) else nil)
			table.insert(meshes, meshAt(K.key, h, 1))
			local T = KnifeLook.TRAIL
			local life = if KnifeLook.element(K.key) then T.ElementLifetime else T.Lifetime
			local keep = {}
			for _, e in K.history do if t - e.t <= life then table.insert(keep, e) end end
			K.history = keep
			if #keep >= 2 then
				local c0, c1 = hex(K.trail.colours[1]), hex(K.trail.colours[2])
				for band = 1, 4 do
					local uu = (band - 0.5) / 4
					local pts, w, a, cs = {}, {}, {}, {}
					for n = #keep, 1, -1 do
						local e = keep[n]
						local p = e.base:Lerp(e.tip, uu)
						local age = (t - e.t) / life
						table.insert(pts, { p.X, p.Y, p.Z })
						table.insert(w, (e.tip - e.base).Magnitude / 4 * 1.1)
						table.insert(a, (1 - (K.trail.transparency[1] + (K.trail.transparency[2] - K.trail.transparency[1]) * age)) * (0.4 + 0.6 * uu))
						table.insert(cs, if age < 0.5 then c0 else c1)
					end
					table.insert(ribbons, { pts = pts, w = w, a = a, c = c0, cs = cs, add = K.trail.light > 0.5 })
				end
			end
		end
		if f >= 0 then
			scene:frame(Vector3.new(0, 3.2, 7.5), Vector3.new(0, 2.4, 0), { meshes = meshes, sprites = sprites, ribbons = ribbons,
				lights = lights, fov = 55, caption = string.format("%.2f s   Dragon's Maw (fire) | Frostbound Oath (ice) | Abyss Eclipse (void): in hand, a slash every 2 s", t) })
		end
	end
	scene:save(nil, FPS, 1280, 720, { sky = "#1d2333", ground = "#2a2a36", grid = false, meshFile = MESHES, stills = { 20, 75, 130 } })
	return
end

-- MODE=sheet
local KEYS = { "RustyShiv", "CandyKnife", "StormKunai", "BloodMoonTanto", "SolarReaper", "VoidFang", "AbyssEclipse", "CelestialSeraph" }
local GAP = 14
local rigs, shots = {}, {}
for i, key in KEYS do
	local x = (i - 4.5) * GAP
	local rig = scene:addRig(Rig.r15("Body" .. i, { shirt = "#3a4660", pants = "#20242c" }))
	rig.root.CFrame = CFrame.new(x, Rig.REST_HEIGHT, 0)
	local mix = Mix.new()
	Mix.step(mix, 1, { speed = 0, state = "ground", lengths = { Walk = 1, Run = 1 } })
	KFS.apply(Idle, rig, 0.5 + i * 0.4, 1)
	Rig.fk(rig)
	local hand = rig.parts.RightHand
	local held = knife(key, "hand")
	local handleCF = hand.CFrame * KnifeLook.handC0(Vector3.new(0, -hand.Size.Y / 2 + 0.1, 0), held.reach)
	local stand = knife(key, "stand")
	local standCF = CFrame.new(x + 5, 3.4, 0) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(-20))
	table.insert(shots, { key = key, held = held, handleCF = handleCF, stand = stand, standCF = standCF })
end
-- Celestial Seraph worn on the back, for the side by side with Huss Valley's MELON5MAN
local wornRig = scene:addRig(Rig.r15("Worn", { shirt = "#2e7d32", pants = "#20242c" }))
local WX = 8 * GAP
wornRig.root.CFrame = CFrame.new(WX, Rig.REST_HEIGHT, 0)
KFS.apply(Idle, wornRig, 0.7, 1)
Rig.fk(wornRig)
local worn = knife("CelestialSeraph", "back")
local wornShape = KnifeService.shapeOf(worn.model)
local wear = KnifeLook.wearOf(CoinShop.get("CelestialSeraph").Wear, wornShape)
local torso = wornRig.parts[KnifeLook.mountPart(wear, false)]
local wornCF = torso.CFrame * KnifeLook.wornC0(wear, torso.Name, torso.Size, wornShape)

local WARM = 3
local stills, frameN = {}, 0
local function tick(sprites, lights)
	for _, s in shots do
		step(s.held, s.handleCF, dt, sprites, lights)
		step(s.stand, s.standCF, dt, sprites, lights)
	end
	step(worn, wornCF, dt, sprites, lights)
end
local function meshesNow()
	local m = {}
	for _, s in shots do
		table.insert(m, meshAt(s.key, s.handleCF, 1))
		table.insert(m, meshAt(s.key, s.standCF, s.stand.scale))
	end
	table.insert(m, meshAt("CelestialSeraph", wornCF, 1))
	return m
end
for _ = 1, WARM * FPS do tick({}, {}) end
local function shoot(eye, at, caption, fov)
	for _ = 1, 4 do tick({}, {}) end -- (a little time between stills)
	local sprites, lights = {}, {}
	tick(sprites, lights)
	scene:frame(eye, at, { meshes = meshesNow(), sprites = sprites, lights = lights, fov = fov or 50, caption = caption })
	table.insert(stills, frameN)
	frameN += 1
end
for _, s in shots do
	local mid = s.handleCF * Vector3.new(0, s.held.reach * 0.45, 0)
	shoot(mid + Vector3.new(1.4, 0.5, -3.2), mid, s.key .. " in hand")
	local smid = s.standCF * Vector3.new(0, s.stand.reach * 0.45, 0)
	shoot(smid + Vector3.new(0, 0.4, -6.2), smid, s.key .. " on a stand")
end
local wmid = wornCF * Vector3.new(0, 0.6, 0)
shoot(wmid + Vector3.new(0.2, 0.9, 3.4), wmid + Vector3.new(0, -0.1, 0), "Celestial Seraph worn", 45)
scene:save(nil, FPS, 960, 720, { sky = "#8cc4f2", ground = "#3f8f4a", grid = false, meshFile = MESHES, stills = stills })
print("stills " .. table.concat(stills, ","))
