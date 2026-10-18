-- The owner's knives (Oct 18) on real rigs, placed exactly as the game places them (Shared/KnifeLook's back and hand
-- mounts, the Handle frame tools/knives/setup_knives.lua builds), with the game's own StabMotion and KnifeLeap.
--   KNIFE_MODE=stills: frame 0 four knives on the back from behind (Huss Valley's 5.0 s skins shot), frames 1-3 the
--     slash's hold (0.15 s in) from the front, one knife each (HV's 43.47 s hold). Keep them with MOTION3D_KEEP=<dir>.
--   KNIFE_MODE=clip (default): running, Space + D at 0.8 s (a sideways leap, the slash plays in it), Space at 2.4 s
--     (forward), then the sideways leap again at 1/4 speed. The tinted slash trail is a ribbon from the blade's tip.
-- Needs the meshes: python3 -I tools/knives/knife_meshes.py <file>, then KNIFE_MESHES=<file>.
-- sh video.sh knife_scene.luau out.mp4
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local KFS = require("./kfs")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local Mix = Env.load(SHARED .. "LocomotionMix.lua")
local CarryMath = Env.load(SHARED .. "CarryMath.lua")
local StabMotion = Env.load(SHARED .. "StabMotion.lua")
local KnifeLook = Env.load(SHARED .. "KnifeLook.lua")
local KnifeLeap = Env.load(SHARED .. "KnifeLeap.lua")
local RunMotion = Env.load(SHARED .. "RunMotion.lua")
local Round = Env.load(SHARED .. "Config/Round.lua")

local MODE = process.env.KNIFE_MODE or "clip"
local MESHES = process.env.KNIFE_MESHES or error("set KNIFE_MESHES (python3 -I tools/knives/knife_meshes.py <file>)")
local baked = {}
for _, k in serde.decode("json", fs.readFile("huzz-valley/tools/knives/knives.json")) do baked[k.key] = k end

local lib = roblox.Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile("huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do inst.Parent = lib end
local A = {}
for _, name in { "Idle", "Walk", "Run" } do A[name] = KFS.load(lib:FindFirstChild(name, true)) end

-- .glb axes (blade +Y, thickness Z) into the Handle's (blade +Y, thickness X), origin at the grip's middle.
local TURN = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, -1), Vector3.new(0, 1, 0), Vector3.new(1, 0, 0))
local function knifeAt(key, handleCF)
	local k = baked[key]
	local per = k.studs / k.length
	local cf = handleCF * CFrame.new(0, -k.grip * per, 0) * TURN
	local c = { cf:GetComponents() }
	return { m = key, p = { c[1], c[2], c[3] }, r = { c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12] }, s = per },
		handleCF * Vector3.new(0, (k.tip - k.grip) * per, 0), handleCF * Vector3.new(0, (0 - k.grip) * per, 0)
end
local function inHand(rig)
	local hand = rig.parts.RightHand
	return hand.CFrame * KnifeLook.handC0(Vector3.new(0, -hand.Size.Y / 2 + 0.1, 0)) -- (KnifeService.give, no Grip on the hand)
end
local function onBack(rig)
	local torso = rig.parts.LowerTorso
	return torso.CFrame * KnifeLook.backC0(torso.Name, torso.Size)
end
local function glowLight(key, at)
	local fx, k = KnifeLook.fx(baked[key].rarity), baked[key]
	if not fx.glow or not k.glow then return nil end
	return { p = { at.X, at.Y, at.Z }, c = "#" .. k.glow, b = fx.glow.brightness * 0.5, r = fx.glow.range } -- (render.mjs's light is an imitation and reads about twice Studio's: halved here)
end

local function pose(rig, mix, t)
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

local function studs(scene, x0, x1, z0, z1)
	for i = z0, z1 do
		for j = x0, x1 do
			scene:addBox(CFrame.new(j * 4, 0.03, i * 4), Vector3.new(0.4, 0.06, 0.4), "#b9a06a")
		end
	end
end

local scene = Scene.new()
local SHIRTS = { { "#1f2230", "#2b2f3a" }, { "#3a7a3a", "#20242c" }, { "#e0e0e6", "#2b2f3a" }, { "#d8892a", "#3a4050" } }

if MODE == "stills" then
	studs(scene, -6, 6, -3, 3)
	studs(scene, 6, 26, -3, 3)
	-- frame 0: four on the back, idle, seen from behind at belt height
	local backKeys = { "RustyShiv", "CandyKnife", "SolarReaper", "AbyssEclipse" }
	local backRigs = {}
	for i, key in backKeys do
		local rig = scene:addRig(Rig.r15("Back" .. i, { shirt = SHIRTS[i][1], pants = SHIRTS[i][2] }))
		rig.root.CFrame = CFrame.new((i - 2.5) * 4.2, Rig.REST_HEIGHT, 0)
		local mix = Mix.new()
		Mix.step(mix, 1, { speed = 0, state = "ground", lengths = { Walk = A.Walk.length, Run = A.Run.length } })
		pose(rig, mix, 0.4 + i * 0.3)
		Rig.fk(rig)
		backRigs[i] = { rig = rig, key = key }
	end
	-- frames 1-3: the slash's hold, one knife each, far apart so only one is in shot
	local holdKeys = { "CandyKnife", "MoonlitKnife", "SpinKnife" }
	local holdRigs = {}
	for i, key in holdKeys do
		local rig = scene:addRig(Rig.r15("Hold" .. i, { shirt = "#e0453a", pants = "#2b2f3a" }))
		rig.root.CFrame = CFrame.new(30 + i * 40, Rig.REST_HEIGHT, 0)
		holdRigs[i] = { rig = rig, key = key }
	end
	local function holdPose(on)
		for i, h in holdRigs do
			local mix = Mix.new()
			Mix.step(mix, 1, { speed = 0, state = "ground", lengths = { Walk = A.Walk.length, Run = A.Run.length } })
			pose(h.rig, mix, 0.6)
			if on then
				local rec = StabMotion.new(CarryMath.rig(h.rig), h.rig.root)
				StabMotion.play(rec, 0)
				StabMotion.step(rec, 0.15)
			end
			Rig.fk(h.rig)
		end
	end
	holdPose(true)
	local meshes, lights = {}, {}
	for _, b in backRigs do
		local m = knifeAt(b.key, onBack(b.rig))
		table.insert(meshes, m)
	end
	for _, b in backRigs do
		local _, tip, base = knifeAt(b.key, onBack(b.rig))
		if KnifeLook.fx(baked[b.key].rarity).back then
			local l = glowLight(b.key, base:Lerp(tip, 0.5))
			if l then table.insert(lights, l) end
		end
	end
	for _, h in holdRigs do table.insert(meshes, (knifeAt(h.key, inHand(h.rig)))) end
	scene:frame(Vector3.new(0, 3.2, 10.5), Vector3.new(0, 2.2, 0), { meshes = meshes, lights = lights, fov = 48 })
	for i, h in holdRigs do
		local at = h.rig.root.CFrame.Position
		local hl = {}
		local _, tip, base = knifeAt(h.key, inHand(h.rig))
		local l = glowLight(h.key, base:Lerp(tip, 0.5))
		if l then table.insert(hl, l) end
		scene:frame(at + Vector3.new(-2.5, 4, -19), at + Vector3.new(0.9, 2.6, 0), { meshes = meshes, lights = hl, fov = 40 })
	end
	scene:save(nil, 30, 1280, 720, { stills = { 0, 1, 2, 3 }, meshFile = MESHES })
	return
end

-- the clip: running with the knife out, a sideways leap, a forward leap, the sideways leap slowed down
local KEY = "VoidFang"
local k = baked[KEY]
studs(scene, -6, 8, -40, 14)
local catcher = scene:addRig(Rig.r15("Catcher", { shirt = "#e0453a", pants = "#2b2f3a" }))
local stab = StabMotion.new(CarryMath.rig(catcher), catcher.root)
local runner = scene:addRig(Rig.r15("Runner", { shirt = "#4a7be0", pants = "#2b2f3a" }))

local FPS, DT, SUB = 30, 1 / 30, 4
local L = Round.Lunge
local fx = KnifeLook.fx(k.rarity)
local trailC = if fx.trailTint then "#" .. (k.glow or "ffffff") else "#ffffff"
local trailA = if fx.trailTint then KnifeLook.TRAIL.Tinted[1] else KnifeLook.TRAIL.Plain[1]
local function run(seconds, leaps, slowFrom, slowTo, captionFor)
	local mix = Mix.new()
	local pos, vy, y, speed, idleT, clock = Vector3.new(0, 0, 12), 0, 0, 0, 0, 0
	local leapAt, leapDir, trail = nil, nil, {}
	local look = Vector3.new(0, 0, -1)
	local nextLeap = 1
	runner.root.CFrame = CFrame.new(0, -50, 0)
	Rig.fk(runner)
	local camAt, camLook
	for f = 0, seconds * FPS - 1 do
		local t = f * DT
		local slow = slowFrom and t >= slowFrom and t < slowTo
		local h = (if slow then DT / 4 else DT) / SUB
		for _ = 1, SUB do
			clock += h
			local leap = leaps[nextLeap]
			if leap and clock >= leap.at then
				nextLeap += 1
				leapAt, leapDir = clock, KnifeLeap.direction(look, leap.move)
				vy = L.Up
				StabMotion.play(stab, clock, true)
				-- the runner this leap reaches (stands where the hit box will be)
				local reach = 0
				for s = 0, L.Time, 1 / 120 do reach += RunMotion.pushSpeed(L, s) / 120 end
				runner.root.CFrame = CFrame.lookAt(pos + leapDir * (reach + 1.5) + Vector3.new(0, Rig.REST_HEIGHT, 0), pos + Vector3.new(0, Rig.REST_HEIGHT, 0))
				Rig.fk(runner)
			end
			local push = leapAt and RunMotion.pushSpeed(L, clock - leapAt)
			if push then
				pos += leapDir * push * h
				speed = 28
			else
				speed += (28 - speed) * (1 - math.exp(-h * 10))
				pos += look * speed * h
			end
			vy -= 196.2 * h
			y = math.max(0, y + vy * h)
			if y == 0 then vy = 0 end
			if leapAt then
				local d = catcher.root.CFrame:VectorToObjectSpace(if push then leapDir else look)
				StabMotion.setDive(stab, d)
			end
			Mix.step(mix, h, { speed = speed, state = "ground", lengths = { Walk = A.Walk.length, Run = A.Run.length } })
			idleT += h
			pose(catcher, mix, idleT)
			StabMotion.step(stab, clock)
			catcher.root.CFrame = CFrame.new(pos + Vector3.new(0, Rig.REST_HEIGHT + y, 0))
			Rig.fk(catcher)
			local _, tip = knifeAt(KEY, inHand(catcher))
			if leapAt and StabMotion.trailOn(stab, clock) then
				table.insert(trail, { p = tip, at = clock })
			end
			while trail[1] and clock - trail[1].at > KnifeLook.TRAIL.Lifetime do table.remove(trail, 1) end
		end
		local meshes = { (knifeAt(KEY, inHand(catcher))) }
		local _, tip, base = knifeAt(KEY, inHand(catcher))
		local ribbons = {}
		if #trail >= 2 then
			local pts, w, a = {}, {}, {}
			for i, q in trail do
				local age = (clock - q.at) / KnifeLook.TRAIL.Lifetime
				table.insert(pts, { q.p.X, q.p.Y, q.p.Z })
				table.insert(w, 0.35 * (1 - age) + 0.05)
				table.insert(a, (1 - trailA) * (1 - age))
			end
			table.insert(ribbons, { pts = pts, w = w, a = a, c = trailC, add = true })
		end
		local lights = {}
		local l = glowLight(KEY, base:Lerp(tip, 0.5))
		if l then table.insert(lights, l) end
		-- a camera that trails behind and to the left, slow enough that the leap reads against the floor
		local focus = pos + Vector3.new(4, 2.4, -3)
		local k = 1 - math.exp(-(if slow then DT / 4 else DT) * 6)
		camLook = if camLook then camLook:Lerp(focus, k) else focus
		camAt = camLook + Vector3.new(-4, 3.6, 11)
		scene:frame(camAt, camLook, { meshes = meshes, ribbons = ribbons, lights = lights, caption = captionFor(t, slow, clock - (leapAt or -9)) })
	end
end
run(5.6, {
	{ at = 0.8, move = Vector3.new(1, 0, 0) },
	{ at = 2.4, move = Vector3.new(0, 0, -1) },
	{ at = 3.6, move = Vector3.new(1, 0, 0) },
}, 3.5, 5.6, function(t, slow, since)
	local what = if t < 2.2 then "Space + D: leap sideways" elseif t < 3.5 then "Space: leap forward" else "Space + D, 1/4 speed"
	local label = if since >= 0 and since <= 0.72 then string.format("  %.2f s", since) else ""
	return what .. label
end)
scene:save(nil, FPS, 1280, 720, { meshFile = MESHES })
