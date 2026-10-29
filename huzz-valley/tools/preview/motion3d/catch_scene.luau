-- A catch in a round, start to finish (owner Oct 19: "give them a good vfx, make them have good animations, the
-- leaping, the killing ... take your time"; players read "catch"): a catcher holding the Inferno Knife (Dragon's
-- Maw, his mesh, its real in-hand size) chases a runner, presses Space (the lunge, Config/Round.Lunge, the leap's
-- hit box Reach/Width as Gameplay/HitCheck), the knife lands, the runner goes down (Shared/DownMotion), the catcher
-- lands and runs on. Then the catch again at 1/4 speed.
-- The game's own code: Shared/StabMotion (the slash and the leap's body), Shared/DownMotion, Shared/KnifeLook (the
-- element trail, ARC, the burst, CATCH: the hit read), Config/Round. The client effects (Gameplay/Actions, Juice,
-- RoundHud) are drawn the way those files make them.
--   CATCH_OLD=1: the version before knife pass 2 (Oct 19): copy the old StabMotion.lua and DownMotion.lua (git show
--     e6f5b68:<path>) to Shared/StabMotionOld.lua and DownMotionOld.lua first, and delete them after; the old effects
--     (Juice's red spark shower, no red fill, no lunge streak), the old hop (Up 18) and no slide.
--   CATCH_DIVE_OLD=1: the dive before Oct 20 15:13 (2 s lying dazed with stars, no belly slide): copy it first,
--     git show ef3df24:huzz-valley/src/ReplicatedStorage/Shared/StabMotion.lua > Shared/StabMotionOld.lua with its
--     STUN_END line set to 0.38 + 2 (it reads the stun from Config/Round), and delete it after. Film:
--     docs/previews/dive-oct20.mp4 (owner: "right now its like a ragdoll, make it straight to the point");
--     CATCH_DIVE_NEW=1 labels the new side NOW.
--   CATCH_VIEW=catcher (default: the catcher's own follow camera, 12 back, 14 degrees down), runner (the caught
--     runner's camera: the catcher leaps in past it) or side (a low side view: the body line of the leap and the fall).
-- KNIFE_MESHES=<file> CATCH_VIEW=side sh video.sh catch_scene.luau out.mp4
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local CFrame, Vector3, Color3 = roblox.CFrame, roblox.Vector3, roblox.Color3
local Rig = require("./rig")
local Scene = require("./scene")
local KFS = require("./kfs")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local OLD = process.env.CATCH_OLD == "1"
local DIVE_OLD = process.env.CATCH_DIVE_OLD == "1"
local VIEW = process.env.CATCH_VIEW or "catcher"
local Mix = Env.load(SHARED .. "LocomotionMix.lua")
local CarryMath = Env.load(SHARED .. "CarryMath.lua")
local StabMotion = Env.load(SHARED .. (if OLD or DIVE_OLD then "StabMotionOld.lua" else "StabMotion.lua"))
local DownMotion = Env.load(SHARED .. (if OLD then "DownMotionOld.lua" else "DownMotion.lua"))
local KnifeLook = Env.load(SHARED .. "KnifeLook.lua")
local RunMotion = Env.load(SHARED .. "RunMotion.lua")
local Round = Env.load(SHARED .. "Config/Round.lua")
local CATCH = (not OLD) and KnifeLook.CATCH or nil
local MESHES = process.env.KNIFE_MESHES or error("set KNIFE_MESHES (python3 -I tools/knives/knife_meshes.py <file>)")
local rad = math.rad

local function hex(c) return string.format("#%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end
local function fromHex(h) return Color3.fromRGB(tonumber(h:sub(2, 3), 16), tonumber(h:sub(4, 5), 16), tonumber(h:sub(6, 7), 16)) end
local seedN = 4242
local function rnd() seedN = (seedN * 1103515245 + 12345) % 2147483648; return seedN / 2147483648 end
local function range(a, b) return a + (b - a) * rnd() end

local baked = {}
for _, k in serde.decode("json", fs.readFile("huzz-valley/tools/knives/knives.json")) do baked[k.key] = k end
local lib = roblox.Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile("huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do inst.Parent = lib end
local A = {}
for _, name in { "Idle", "Walk", "Run" } do A[name] = KFS.load(lib:FindFirstChild(name, true)) end

local KEY = "DragonsMaw"
local el = KnifeLook.element(KEY)
local TURN = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, -1), Vector3.new(0, 1, 0), Vector3.new(1, 0, 0))
local function knifeAt(handleCF)
	local k = baked[KEY]
	local per = k.studs / k.length
	local cf = handleCF * CFrame.new(0, -k.grip * per, 0) * TURN
	local c = { cf:GetComponents() }
	return { m = KEY, p = { c[1], c[2], c[3] }, r = { c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12] }, s = per },
		handleCF * Vector3.new(0, (k.tip - k.grip) * per, 0), handleCF * Vector3.new(0, (0 - k.grip) * per, 0)
end
local function inHand(rig)
	local hand = rig.parts.RightHand
	local k = baked[KEY]
	return hand.CFrame * KnifeLook.handC0(Vector3.new(0, -hand.Size.Y / 2 + 0.1, 0), (k.tip - k.grip) * k.studs / k.length) -- (KnifeService.reachOf)
end
local function pose(rig, mix, t)
	for _, m in rig.motors do m.Transform = CFrame.identity end
	local total = 0
	local function layer(anim, at, w)
		if w <= 1e-4 then return end
		total += w
		KFS.apply(anim, rig, at, w / total)
	end
	layer(A.Idle, t, mix.weights.Idle)
	layer(A.Walk, mix.times.Walk, mix.weights.Walk)
	layer(A.Run, mix.times.Run, mix.weights.Run)
end

local scene = Scene.new()
for i = -3, 3 do
	for j = -24, 6 do scene:addBox(CFrame.new(i * 4, 0.03, j * 4), Vector3.new(3.8, 0.06, 3.8), if (i + j) % 2 == 0 then "#c08a4a" else "#b07c40") end
end
local catcher = scene:addRig(Rig.r15("Catcher", { shirt = "#1d1f27", pants = "#16171c" }))
local runner = scene:addRig(Rig.r15("Runner", { shirt = "#3a6fd8", pants = "#2b2f3a" }))
local runnerColours = {}
for n, p in runner.parts do runnerColours[n] = p.Color end
local stab = StabMotion.new(CarryMath.rig(catcher), catcher.root)

local FPS, DT, SUB = 30, 1 / 30, 4
local L = table.clone(Round.Lunge)
if OLD then L.Up = 18 end -- (the hop before this pass)
if DIVE_OLD then L.Stun, L.Slide = 2, 0 end -- (the dive before Oct 20 15:13: 2 s on the floor, a dead stop)
local SLIDE = if OLD then 0 else (Round.Knockdown.Slide or 0)
local CATCHER_SPEED, RUNNER_SPEED = 30, 26
local LUNGE_AT, HIT_DELAY = 0.9, 0.05 -- (the server's Caught arrives ~a frame or two later in Studio)
local SLOW_FROM, SLOW_TO, REPLAY = 4.6, 8.2, 0.82 -- after the full-speed run (the dive, the 2 s stun, getting up), the catch again from REPLAY at 1/4 speed
local RED = Color3.fromRGB(255, 45, 45)
local RX = 2.8 -- the runner, this far to the catcher's right (inside the leap's 4-stud box)

local state
local function reset()
	state = {
		clock = 0, cz = 11, rz = 0, cy = 0, vy = 0, cspeed = CATCHER_SPEED, leapAt = nil, hitAt = nil, downAt = nil, feet = nil,
		cmix = Mix.new(), rmix = Mix.new(), down = nil, history = {}, particles = {}, acc = {}, arcStart = nil, streak = {},
		shakeUntil = -1, idle = 0, flashAt = nil, cut = nil,
	}
	for _, m in stab.written do end
	StabMotion.release(stab)
	stab.start = -math.huge
	for n, p in runner.parts do p.Color = runnerColours[n] end
end
reset()

local function spawnParticles(list, n, at, o)
	for _ = 1, n do
		local d = Vector3.new(range(-1, 1), range(-1, 1), range(-1, 1))
		if d.Magnitude < 0.05 then d = Vector3.new(0, 1, 0) end
		d = d.Unit
		if o.up then d = (d + Vector3.new(0, o.up, 0)).Unit end
		table.insert(list, { p = at(), v = d * range(o.speed[1], o.speed[2]), age = 0, life = range(o.life[1], o.life[2]), o = o, rot = range(0, 360) })
	end
end

local function sim(h)
	local s = state
	s.clock += h
	local c = s.clock
	-- the leap: Space at LUNGE_AT (forward), the hop and the push (Gameplay/Dash)
	if not s.leapAt and c >= LUNGE_AT then
		s.leapAt = c
		s.vy = L.Up
		StabMotion.play(stab, c, true)
		if OLD then -- (the old lunge slashed at take-off)
			s.arcStart = c + KnifeLook.ARC.At
			s.burstPending = math.ceil(el.burst * 0.5)
		end
	end
	local push = s.leapAt and RunMotion.lungeSpeed(L, c - s.leapAt) -- (the push, then the belly slide: Gameplay/Dash)
	-- the dive's stun (Oct 19: PowerService.stun, speed 0 from StunAfter for Stun seconds; StabMotion keeps the body
	-- lying dazed, then it gets up)
	local since = s.leapAt and (c - s.leapAt) or -1
	s.stunned = (not OLD) and L.Stun ~= nil and since >= L.StunAfter and since < L.StunAfter + L.Stun
	local cv = if push then push elseif s.stunned then 0 else s.cspeed
	s.cz -= cv * h
	s.vy -= 196.2 * h
	s.cy = math.max(0, s.cy + s.vy * h)
	if s.cy == 0 then s.vy = 0 end
	-- the runner runs straight on until the catch lands (the server anchors them: DownMotion from there)
	if not s.downAt then s.rz -= RUNNER_SPEED * h end
	-- the hit (Gameplay/HitCheck: the runner's body inside Reach ahead along the leap, Width across, in HitWindow)
	if s.leapAt and not s.hitAt and c - s.leapAt <= L.HitWindow then
		local ahead = s.cz - s.rz
		if ahead <= L.Reach + 0.5 and ahead > -0.5 then
			s.hitAt = c
			if not OLD then StabMotion.slash(stab, c) end -- (Gameplay/Dash: the catcher's screen found the runner)
		end
	end
	if s.hitAt and not s.downAt and c >= s.hitAt + HIT_DELAY then
		s.downAt = c
		s.feet = CFrame.new(RX, 0, s.rz)
		s.down = DownMotion.new(runner.motors)
		s.flashAt = c
		s.shakeUntil = c + 0.25
		if OLD then
			s.sparks = true
		end
	end
	-- poses
	Mix.step(s.cmix, h, { speed = if push then 28 else cv, state = "ground", lengths = { Walk = A.Walk.length, Run = A.Run.length } })
	Mix.step(s.rmix, h, { speed = RUNNER_SPEED, state = "ground", lengths = { Walk = A.Walk.length, Run = A.Run.length } })
	s.idle += h
	pose(catcher, s.cmix, s.idle)
	if s.leapAt then StabMotion.setDive(stab, Vector3.new(0, 0, -1)) end
	catcher.root.CFrame = CFrame.new(0, Rig.REST_HEIGHT + s.cy, s.cz)
	Rig.fk(catcher)
	StabMotion.step(stab, c)
	Rig.fk(catcher)
	-- the slash's arc and burst when the slash starts (Gameplay/Actions: at the hit, else LEAP.SlashBy)
	local slashAt = (not OLD) and s.leapAt and StabMotion.slashStart(stab, c)
	if slashAt and not s.slashFx then
		s.slashFx = true
		s.arcStart = slashAt + KnifeLook.ARC.At
		s.burstPending = math.ceil(el.burst * 0.5)
	end
	pose(runner, s.rmix, s.idle + 0.3)
	if s.downAt then
		runner.root.CFrame = DownMotion.rootCFrame(s.feet, Rig.REST_HEIGHT, c - s.downAt, if OLD then nil else SLIDE)
		DownMotion.step(s.down, c - s.downAt)
	else
		runner.root.CFrame = CFrame.new(RX, Rig.REST_HEIGHT, s.rz)
	end
	Rig.fk(runner)
	-- the knife's trail (KnifeService: element colours, ElementLifetime, tapered)
	local _, tip, base = knifeAt(inHand(catcher))
	if StabMotion.trailOn(stab, c) then
		table.insert(s.history, { t = c, base = base:Lerp(tip, 0.25), tip = tip })
	end
	-- the lunge streak (new): a soft ribbon from the body while the push lasts
	if CATCH and CATCH.Streak and push then
		local chest = catcher.parts.UpperTorso.CFrame
		table.insert(s.streak, { t = c, a = chest * Vector3.new(0, CATCH.Streak.Top, 0), b = chest * Vector3.new(0, CATCH.Streak.Bottom, 0) })
	end
	-- element particles: steady (hand rate), the burst at the slash, the old red sparks at the catch
	for i, spec in el.emit do
		s.acc[i] = (s.acc[i] or 0) + KnifeLook.elementRate(spec, "hand") * h
		while s.acc[i] >= 1 do
			s.acc[i] -= 1
			spawnParticles(s.particles, 1, function() return base:Lerp(tip, range(0.1, 1)) end,
				{ speed = spec.speed, life = spec.life, size = spec.size, c0 = spec.colours[1], c1 = spec.colours[2], tex = if spec.texture == "Flame" then "flame" else "spark",
					accel = Vector3.new(spec.accel and spec.accel[1] or 0, spec.accel and spec.accel[2] or 0, spec.accel and spec.accel[3] or 0), shrink = spec.shrink, drag = 1.5 })
		end
	end
	if s.burstPending then
		spawnParticles(s.particles, s.burstPending, function() return base:Lerp(tip, range(0.2, 1)) end,
			{ speed = { 4, 8 }, life = { 0.5, 0.9 }, size = el.emit[1].size * 1.1, c0 = el.emit[1].colours[1], c1 = el.emit[1].colours[2], tex = "flame", accel = Vector3.new(0, -1, 0), shrink = true, drag = 4 })
		s.burstPending = nil
	end
	if s.sparks then
		local at = runner.root.CFrame.Position
		spawnParticles(s.particles, 30, function() return at end,
			{ speed = { 10, 20 }, life = { 0.35, 0.6 }, size = 0.45, c0 = Color3.new(1, 1, 1), c1 = RED, tex = "spark", accel = Vector3.new(0, -24, 0), shrink = true, drag = 3, up = 0.6 })
		s.sparks = nil
	end
	if CATCH and s.downAt and not s.hitFx then
		s.hitFx = true
		local at = runner.parts.UpperTorso.CFrame.Position
		local kc = el.trail[1]
		spawnParticles(s.particles, CATCH.Burst.Count, function() return at end,
			{ speed = CATCH.Burst.Speed, life = CATCH.Burst.Life, size = CATCH.Burst.Size, c0 = Color3.new(1, 1, 1), c1 = kc, tex = "spark", accel = Vector3.new(0, -8, 0), shrink = true, drag = 5 })
		s.cut = { at = c, cf = runner.parts.UpperTorso.CFrame }
	end
	for _, q in s.particles do
		q.age += h
		q.v = (q.v + (q.o.accel or Vector3.zero) * h) * math.exp(-(q.o.drag or 2) * h)
		q.p += q.v * h
	end
	local keep = {}
	for _, q in s.particles do if q.age < q.life then table.insert(keep, q) end end
	s.particles = keep
	-- the red fill on the caught runner (new: KnifeLook.CATCH.Fill, a Highlight in RoundHud's colours)
	if CATCH and s.flashAt then
		local tr = KnifeLook.catchFill(c - s.flashAt, true)
		for n, p in runner.parts do p.Color = hex(fromHex(runnerColours[n]):Lerp(RED, 1 - tr)) end
	end
end

local function frameFx()
	local s = state
	local c = s.clock
	local sprites, ribbons, meshes = {}, {}, {}
	local mesh, tip, base = knifeAt(inHand(catcher))
	table.insert(meshes, mesh)
	-- stunned: three stars circling over the head (Gameplay/PowerEffects; drawn with the Aura star picture here)
	if s.stunned and L.Stun >= 1 then -- (none for a stun under 1 s, as Gameplay/PowerEffects)
		local head = catcher.parts.Head.CFrame.Position
		for i = 1, 3 do
			local a = c * 2 * math.pi / 1.4 + (i - 1) * 2 * math.pi / 3
			local p = head + Vector3.new(math.cos(a) * 1.1, 1.3 + 0.15 * math.sin(a * 2), math.sin(a) * 1.1)
			table.insert(sprites, { p = { p.X, p.Y, p.Z }, s = 0.8, c = "#ffe25c", a = 1, t = "aura-star" })
		end
	end
	local life = KnifeLook.TRAIL.ElementLifetime
	local keep = {}
	for _, e in s.history do if c - e.t <= life then table.insert(keep, e) end end
	s.history = keep
	if #keep >= 2 then
		for i = 1, 4 do
			local u = (i - 0.5) / 4
			local pts, w, a, cs = {}, {}, {}, {}
			for n = #keep, 1, -1 do
				local e = keep[n]
				local p = e.base:Lerp(e.tip, u)
				local age = (c - e.t) / life
				table.insert(pts, { p.X, p.Y, p.Z })
				table.insert(w, (e.tip - e.base).Magnitude / 4 * 1.15 * (1 - 0.65 * age))
				table.insert(a, 0.8 * (1 - age) * (0.35 + 0.65 * u))
				table.insert(cs, if age < 0.35 then hex(el.trail[1]) else hex(el.trail[2]))
			end
			table.insert(ribbons, { pts = pts, w = w, a = a, c = hex(el.trail[1]), cs = cs, add = true })
		end
	end
	-- the slash arc (KnifeLook.ARC on the catcher's root)
	if s.arcStart then
		local Ar = KnifeLook.ARC
		local fade = KnifeLook.arcFade(c - s.arcStart)
		if fade < 1 then
			local root = catcher.root.CFrame
			local p0, p3 = root * Ar.From, root * Ar.To
			local p1 = p0 + root:VectorToWorldSpace(Vector3.new(1, 0, 0)) * Ar.Curve
			local p2 = p3 - root:VectorToWorldSpace(Vector3.new(0, 0, 1)) * Ar.Curve
			local pts, w, a = {}, {}, {}
			for i = 0, 20 do
				local u = i / 20
				local v = 1 - u
				local p = p0 * (v * v * v) + p1 * (3 * v * v * u) + p2 * (3 * v * u * u) + p3 * (u * u * u)
				table.insert(pts, { p.X, p.Y, p.Z })
				table.insert(w, Ar.Width[1] + (Ar.Width[2] - Ar.Width[1]) * u)
				local tr = if u < 0.5 then 1 + (fade - 1) * (u / 0.5) else fade + (math.min(1, fade + 0.3) - fade) * ((u - 0.5) / 0.5)
				table.insert(a, 1 - tr)
			end
			table.insert(ribbons, { pts = pts, w = w, a = a, c = hex(el.trail[1]:Lerp(Color3.new(1, 1, 1), 0.3)), add = true })
		end
	end
	-- the lunge streak
	if CATCH and CATCH.Streak then
		local St = CATCH.Streak
		local keepS = {}
		for _, e in s.streak do if c - e.t <= St.Life then table.insert(keepS, e) end end
		s.streak = keepS
		if #keepS >= 2 then
			-- (a Trail between the two attachments: white where it leaves the body, the knife's colour as it ages)
			local pts, w, a, cs = {}, {}, {}, {}
			for n = #keepS, 1, -1 do
				local e = keepS[n]
				local age = (c - e.t) / St.Life
				local p = e.a:Lerp(e.b, 0.5)
				table.insert(pts, { p.X, p.Y, p.Z })
				table.insert(w, (e.a - e.b).Magnitude)
				table.insert(a, 1 - (St.Transparency[1] + (St.Transparency[2] - St.Transparency[1]) * age))
				table.insert(cs, hex(Color3.new(1, 1, 1):Lerp(el.trail[1], age)))
			end
			table.insert(ribbons, { pts = pts, w = w, a = a, c = "#ffffff", cs = cs, add = true })
		end
	end
	-- the cut mark across the caught runner (new)
	if CATCH and s.cut then
		local Cu = CATCH.Cut
		local age = c - s.cut.at
		if age < Cu.Life then
			local k = age / Cu.Life
			local cf = runner.parts.UpperTorso.CFrame -- (Gameplay/Juice: a Beam on their UpperTorso, so it falls with them)
			local pts, w, a = {}, {}, {}
			for i = 0, 12 do
				local u = i / 12
				local p = cf * Vector3.new(-Cu.Length / 2 + Cu.Length * u, (0.5 - u) * Cu.Length * 0.45, 0.58) -- (across the back)
				table.insert(pts, { p.X, p.Y, p.Z })
				table.insert(w, Cu.Width * math.sin(math.pi * u) * (1 - 0.4 * k))
				table.insert(a, (1 - k) * (if u < math.min(1, k * 4 + 0.2) then 1 else 0))
			end
			table.insert(ribbons, { pts = pts, w = w, a = a, c = hex(el.trail[1]:Lerp(Color3.new(1, 1, 1), 0.55)), add = true })
		end
	end
	for _, q in s.particles do
		local k = q.age / q.life
		local size = (q.o.size or 0.4) * (if q.o.shrink then 1 - k else 1)
		table.insert(sprites, { p = { q.p.X, q.p.Y, q.p.Z }, s = size * 1.3, c = hex(q.o.c0:Lerp(q.o.c1, k)), a = 0.9 * (1 - k), t = q.o.tex, r = q.rot, add = true })
	end
	return sprites, ribbons, meshes
end

local scene_t, camAt, camLook = 0, nil, nil
local TOTAL = SLOW_TO + 0.9
local replayed = false
for f = 0, math.floor(TOTAL * FPS) - 1 do
	local t = f * DT
	local slow = t >= SLOW_FROM and t < SLOW_TO
	if slow and not replayed then
		replayed = true
		reset()
		for _ = 1, math.floor(REPLAY / (DT / SUB) + 0.5) do sim(DT / SUB) end
		camAt, camLook = nil, nil
	end
	local h = (if slow then DT / 4 else DT) / SUB
	for _ = 1, SUB do sim(h) end
	local sprites, ribbons, meshes = frameFx()
	local s = state
	local cpos = catcher.root.CFrame.Position
	local eye, focus
	if VIEW == "side" then
		focus = Vector3.new(0.8, 2.0, (cpos.Z + s.rz) / 2 - 1)
		eye = focus + Vector3.new(15, 3.2, 2)
	elseif VIEW == "runner" then -- the caught runner's own camera: behind them, so the catcher leaps in past it
		local rpos = runner.root.CFrame.Position
		focus = Vector3.new(RX, 3.6, (if s.feet then s.feet.Position.Z else rpos.Z))
		eye = focus + Vector3.new(-1.2, 12 * math.sin(rad(14)) + 0.4, 12 * math.cos(rad(14)))
	else -- the catcher's camera: behind and over the shoulder, 12 back and 14 degrees down
		focus = Vector3.new(0, cpos.Y + 1.5 - s.cy * 0.6, cpos.Z)
		eye = focus + Vector3.new(1.2, 12 * math.sin(rad(14)) + 0.4, 12 * math.cos(rad(14)))
	end
	local k = 1 - math.exp(-(if slow then DT / 4 else DT) * 14)
	camLook = if camLook then camLook:Lerp(focus, k) else focus
	camAt = if camAt then camAt:Lerp(eye, k) else eye
	local shakeAt = camAt
	if VIEW ~= "side" and s.clock < s.shakeUntil then -- Juice: shake(0.4, 0.25) for the catcher
		local left = (s.shakeUntil - s.clock) / 0.25
		shakeAt = camAt + Vector3.new(range(-1, 1), range(-1, 1), 0) * 0.4 * left
	end
	local since = if s.leapAt then s.clock - s.leapAt else -1
	local cap = (if OLD then "BEFORE  " elseif DIVE_OLD then "BEFORE (2 s down)  " elseif process.env.CATCH_DIVE_NEW then "NOW  " else "AFTER  ") .. (if slow then "1/4 speed" else "full speed")
		.. (if since >= 0 and since <= 1.2 then string.format("   leap %.2f s", since) else "")
		.. (if s.hitAt and s.clock >= s.hitAt then "   caught" else "") .. (if s.stunned then "   STUNNED" else "")
	scene:frame(shakeAt, camLook, { sprites = sprites, ribbons = ribbons, meshes = meshes, caption = cap, fov = 70 })
end
local keepDir = process.env.MOTION3D_KEEP
local stills = {}
for _, tt in { 1.1, 1.3, 2.0, 3.0, 3.5, 3.9, 4.4 } do table.insert(stills, math.floor(tt * FPS)) end
scene:save(nil, FPS, 960, 540, { sky = "#8fc8f0", ground = "#b07c40", grid = false, meshFile = MESHES, stills = if keepDir then stills else nil })
