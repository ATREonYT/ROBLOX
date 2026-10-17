-- The auras you wear (Shared/AuraLook.worn: Blossom Aura, Legendary, Mythic and Secret rewards) and a Secret girl's
-- Player look, simulated with the game's own numbers (aura_sim.luau copies Gameplay/AuraFX) and our own pictures
-- from assets/fx as if uploaded, so the owner can judge the look before uploading anything. Filmed 3/4 from the
-- front in an evening light so the glow reads; each shot ~4 s: he jogs a little, then stands.
-- sh worn_video.sh   (writes docs/previews/worn-auras.mp4 and the still docs/previews/worn-auras.png)
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local Env = require("./env")
local Sim = require("./aura_sim")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local AuraLook = Env.load(SHARED .. "AuraLook.lua")
local Looks = Env.load(SHARED .. "Config/GirlLooks.lua")

local FPS, DT = 30, 1 / 30
local rad, sin, cos = math.rad, math.sin, math.cos
local SHOTS = {
	{ key = "BlossomAura", label = "Blossom Aura (Shop)" },
	{ key = "AuraLegend", label = "Legendary aura" },
	{ key = "AuraMythic", label = "Mythic aura" },
	{ key = "AuraSecret", label = "Secret aura", moving = true }, -- (a second still while he jogs)
	{ girl = "CAC_R6_ixKatsu_358858", rarity = "Secret", label = "Secret girl equipped (Megumin, Flame)" },
}
local EACH = 4
local JOG = { 0.15, 1.8 } -- seconds into each shot he jogs between
local SPEED = 10
local PREWARM = 2 -- seconds simulated before each shot starts (the aura is already on, as in the game)

local function walkAnim(rig, phase, amount) -- (as aura_scene)
	local M = rig.byName
	local swing = rad(32) * sin(phase) * amount
	M.RightHip.Transform = CFrame.Angles(swing, 0, 0)
	M.LeftHip.Transform = CFrame.Angles(-swing, 0, 0)
	M.RightKnee.Transform = CFrame.Angles(-rad(50) * math.max(0, -sin(phase)) * amount, 0, 0)
	M.LeftKnee.Transform = CFrame.Angles(-rad(50) * math.max(0, sin(phase)) * amount, 0, 0)
	M.RightShoulder.Transform = CFrame.Angles(-swing * 0.9, 0, 0)
	M.LeftShoulder.Transform = CFrame.Angles(swing * 0.9, 0, 0)
	M.RightElbow.Transform = CFrame.Angles(rad(20) * amount, 0, 0)
	M.LeftElbow.Transform = CFrame.Angles(rad(20) * amount, 0, 0)
	M.Root.Transform = CFrame.new(0, -2.7 * (1 - cos(swing)) + 0.12 * math.abs(sin(phase)) * amount, 0)
end

local scene = Scene.new()
local player = scene:addRig(Rig.r15("Player", { shirt = "#1d1f2a", pants = "#16171f", hair = "#3a5bd0" }))
player.byName = {}
for _, m in player.motors do player.byName[m.Name] = m end
for z = 8, -120, -5 do -- stepping stones, so you can see him move
	scene:addBox(CFrame.new(-3.2, 0.05, z), Vector3.new(1.4, 0.1, 1.4), "#3a4466")
	scene:addBox(CFrame.new(5.6, 0.05, z - 2.5), Vector3.new(1.4, 0.1, 1.4), "#3a4466")
end

local P = { pos = Vector3.zero, speed = 0, phase = 0 }
local FWD = Vector3.new(0, 0, -1)
local function pose()
	walkAnim(player, P.phase, math.min(1, P.speed / 12))
	local rootAt = P.pos + Vector3.new(0, Rig.REST_HEIGHT, 0)
	player.root.CFrame = Rig.lookAt(rootAt, rootAt + FWD)
	Rig.fk(player)
end
pose()

local sys = nil
local stills, labels = {}, {}
local best = {} -- per still slot: { score, frame }
local f = 0
for i, shot in SHOTS do
	local spec = if shot.key then AuraLook.worn(shot.key) else AuraLook.build(AuraLook.lookFor(Looks, shot.girl, nil), shot.rarity, "Player")
	assert(spec, "no aura for " .. tostring(shot.key))
	sys = Sim.new(player, spec, { AuraLook = AuraLook, inherit = true })
	for _ = 1, PREWARM * FPS do Sim.step(sys, DT) end
	local slots = { { from = 2.1, to = 3.95, label = shot.label } }
	if shot.moving then table.insert(slots, { from = 0.9, to = 1.7, label = shot.label .. ", running" }) end
	for _, s in slots do s.score, s.frame = -1, nil end
	for k = 0, EACH * FPS - 1 do
		local t = k * DT
		local target = if t >= JOG[1] and t < JOG[2] then SPEED else 0
		P.speed += (target - P.speed) * math.min(1, DT * 6)
		if P.speed < 0.05 then P.speed = 0 end
		P.pos += FWD * P.speed * DT
		P.phase += P.speed * DT * 2 * math.pi / 5
		pose()
		local cam = P.pos + Vector3.new(6.6, 3.4, -7.4)
		Sim.step(sys, DT)
		local sprites, ribbons, lights = {}, {}, {}
		Sim.draw(sys, cam, sprites, ribbons, lights)
		scene:frame(cam, P.pos + Vector3.new(0, 2.5, 0), { sprites = sprites, ribbons = ribbons, lights = lights, caption = shot.label .. (if P.speed > 2 then ", running" else "") })
		-- the best frame for the still: busy, with a pulse ring part-way out and a slash mid-swing if this aura has them
		local score = #sprites
		for _, q in sys.particles do
			if q.e.name == "Pulse" and q.age / q.life > 0.12 and q.age / q.life < 0.4 then score += 60 end
		end
		for _, sl in sys.slashes do
			local age = sys.clock - sl.born
			if age > 0.15 and age < 0.35 then score += 30 end
		end
		for _, s in slots do
			if t >= s.from and t <= s.to and score > s.score then s.score, s.frame = score, f end
		end
		f += 1
	end
	for _, s in slots do
		table.insert(stills, s.frame)
		table.insert(labels, { frame = s.frame, label = s.label })
	end
end
local dir = process.env.MOTION3D_DIR or "."
fs.writeFile(dir .. "/stills.json", serde.encode("json", labels))
scene:save(nil, FPS, 960, 540, { sky = "#1b2340", ground = "#2a3350", grid = false, dim = 0.35, stills = stills })
