-- The R6 run at speed (owner, Oct 22 13:24: "make the game r6, and use these animations that i sent from the
-- movement ... also add some effects when you are running and make it feel more intense"), filmed like his clip
-- (design/owner-oct22/video-1616): the camera close behind and above. His Stylized Walk, then his Stylized Run 2 (from
-- HuzzAnimations: tools/anim/extract_anims.luau), with Gameplay/SpeedFX: thin white streaks off the hands, elbows,
-- knees and feet (Trails, Config/Run.SpeedFX.Trails), the blue glow round the left, right and top of the screen, and the wider
-- camera at full speed (Feel). Walk 0-1.2 s at 12 studs/s, build up over 1 s (Config/Run.Ramp) to 24, run to 5 s.
-- sh video.sh r6_speed_scene.luau out.mp4   (repo root)
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local KFS = require("./kfs")
local Env = require("./env")
local Run = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/Run.lua")
local FX = Run.SpeedFX

local lib = roblox.Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile("huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do inst.Parent = lib end
local walk = KFS.load(lib:FindFirstChild("R6Walk", true))
local run = KFS.load(lib:FindFirstChild("R6Run", true))

local scene = Scene.new()
local rig = scene:addRig(Rig.r6("Me", { shirt = "#26262e", pants = "#3a4a6a", skin = "#e9c29a", hair = "#1a1414" }))
-- the field: white yard lines across, and posts down both sides (so the speed reads)
for z = 0, -260, -10 do scene:addBox(CFrame.new(0, 0.02, z), Vector3.new(40, 0.04, 0.5), "#f4f4f4") end
for z = 0, -260, -14 do
	scene:addBox(CFrame.new(-9, 0.8, z), Vector3.new(0.6, 1.6, 0.6), "#3f8f4a")
	scene:addBox(CFrame.new(10, 0.6, z - 7), Vector3.new(0.6, 1.2, 0.6), "#2e6e3a")
end
-- the streak points (Gameplay/SpeedFX POINTS_R6): a part and a point on it
local POINTS = {
	{ "Right Leg", Vector3.new(0, -0.9, 0) }, { "Left Leg", Vector3.new(0, -0.9, 0) },
	{ "Right Leg", Vector3.new(0, 0, 0.35) }, { "Left Leg", Vector3.new(0, 0, 0.35) },
	{ "Right Arm", Vector3.new(0, -0.9, 0) }, { "Left Arm", Vector3.new(0, -0.9, 0) },
	{ "Right Arm", Vector3.new(0, 0, 0.35) }, { "Left Arm", Vector3.new(0, 0, 0.35) },
}
local hist = {}
for i in POINTS do hist[i] = {} end

local SECONDS, FPS = 5, 30
local z, fov = 0, 0
local walkT, runT = 0, 0
for f = 0, SECONDS * FPS - 1 do
	local t = f / FPS
	local dt = 1 / FPS
	local speed = if t < 1.2 then 12 else math.min(24, 16 + 8 * (t - 1.2) / Run.Ramp)
	z -= speed * dt
	local sprint = math.clamp((speed - Run.From) / math.max(24 - Run.From, 4), 0, 1)
	-- the pack, as Locomotion blends it (LocoR6: walk under RunAt, the run over it, rates by speed)
	local L = Run.LocoR6
	local runW = math.clamp((speed - L.WalkAt) / (L.RunAt - L.WalkAt), 0, 1)
	walkT += dt * math.clamp(speed / 8, L.WalkRate[1], L.WalkRate[2])
	runT += dt * math.clamp(speed / 18, L.RunRate[1], L.RunRate[2])
	rig.root.CFrame = CFrame.new(0, L.RootHeight, z) * CFrame.Angles(0, 0, 0)
	KFS.apply(walk, rig, walkT % walk.length)
	KFS.apply(run, rig, runT % run.length, runW)
	Rig.fk(rig)
	-- the streaks: on near flat out, each point's last Life seconds as a thin strip tapering away
	local on = sprint >= FX.From
	local ribbons = {}
	for i, pt in POINTS do
		local part = rig.parts[pt[1]]
		local h = hist[i]
		if on then table.insert(h, 1, { t = t, p = (part.CFrame * CFrame.new(pt[2])).Position }) end
		while #h > 0 and t - h[#h].t > FX.Trails.Life do table.remove(h) end
		if #h >= 2 then
			local pts, w, a = {}, {}, {}
			for _, e in h do
				local age = (t - e.t) / FX.Trails.Life
				table.insert(pts, { e.p.X, e.p.Y, e.p.Z })
				table.insert(w, FX.Trails.Width * (1 - age))
				table.insert(a, (1 - FX.Trails.See) * (1 - age))
			end
			table.insert(ribbons, { pts = pts, w = w, a = a, c = "#ffffff" })
		end
	end
	-- the glow (eased like SpeedFX) and the camera (Feel: 2 + SpeedFX.Fov degrees at flat out)
	local want = math.clamp((sprint - FX.From) / (1 - FX.From), 0, 1)
	fov += (want - fov) * (1 - math.exp(-dt * (if want > fov then 4 else 3)))
	local gl = fov * FX.Glow.Strength
	local c = FX.Glow.Color
	local hex = string.format("#%02x%02x%02x", c.R * 255, c.G * 255, c.B * 255)
	local fade = { { 0, 0 }, { 0.4, 0.55 }, { 1, 1 } }
	local rfade = { { 0, 1 }, { 0.6, 0.55 }, { 1, 0 } }
	local E = FX.Glow.Edge
	local overlay = if gl > 0.005 then { rects = {
		{ x = 0, y = 0, w = 1280 * E, h = 720, c = hex, a = gl, fade = fade },
		{ x = 1280 * (1 - E), y = 0, w = 1280 * E, h = 720, c = hex, a = gl, fade = rfade },
		{ x = 0, y = 0, w = 1280, h = 720 * E * 1.4, c = hex, a = gl, fade = fade, vfade = true },
	} } else nil
	local pos = Vector3.new(0, 6.2, z + 8)
	scene:frame(pos, Vector3.new(0, 2.6, z - 8), {
		ribbons = ribbons, overlay = overlay, fov = 70 + fov * (2 + FX.Fov),
		caption = string.format("OURS  %.1f s  %d studs/s", t, math.floor(speed + 0.5)),
	})
end
scene:save(nil, FPS, 1280, 720, { sky = "#5aa0e6", ground = "#3f9a45", grid = false })
