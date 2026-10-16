-- The start-of-round camera (Shared/CinematicShot, the same maths as HuzzClient/Gameplay/Cinematic), filmed:
-- 0-3.5 s Lineup (behind the line, looking across), 3.5-6.3 s the sweep along the front of the line while the gold
-- marker hops between runners and lands on the picked one, 6.3-9 s zoom on their face while they choose,
-- 9-11.6 s Chosen (push in), then the camera glides back behind "you" (the runner second from the left) and the
-- Hero runs across alone while everyone waits. The gold square stands in for the gold highlight.
-- sh video.sh intro_scene.luau out.mp4
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local Shot = Env.load(SHARED .. "CinematicShot.lua")
local RunMotion = Env.load(SHARED .. "RunMotion.lua")
local Round = Env.load(SHARED .. "Config/Round.lua")

local FPS, DT = 30, 1 / 30
local LINEUP, ROULETTE, CHOOSE, SHOW = Round.LineupTime, Round.Pick.Roulette, 2.7, Round.Pick.ShowTime
local T_PICK = LINEUP
local T_CHOSEN = T_PICK + ROULETTE + CHOOSE
local T_BACK = T_CHOSEN + SHOW
local SECONDS = T_BACK + 4

local scene = Scene.new()
-- the field, the safe line, the far line
scene:addBox(CFrame.new(0, -0.1, -30), Vector3.new(90, 0.2, 80), "#3fae55")
scene:addBox(CFrame.new(0, 0.02, 0), Vector3.new(40, 0.06, 0.6), "#ffffff")
scene:addBox(CFrame.new(0, 0.02, -60), Vector3.new(40, 0.06, 0.6), "#ffffff")
local line = Rig.lookAt(Vector3.new(0, 0, 0), Vector3.new(0, 0, -1)) -- looking across the field (-Z)

local SHIRTS = { "#2f6fe0", "#8bd15a", "#1b1b22", "#f0f0f0", "#e07a2a", "#7c4ad8" }
local runners = {}
for i = 1, 6 do
	local rig = scene:addRig(Rig.r15("Runner" .. i, { shirt = SHIRTS[i], pants = "#262a36" }))
	local x = (i - 3.5) * Round.Map.LineupGap
	local at = (line * CFrame.new(x, 0, 2.5)).Position
	rig.root.CFrame = Rig.lookAt(at + Vector3.new(0, Rig.REST_HEIGHT, 0), at + Vector3.new(0, Rig.REST_HEIGHT, -1))
	Rig.fk(rig)
	table.insert(runners, { rig = rig, x = x, pos = at, speed = 0, rec = RunMotion.new(rig) })
end
local catcher = scene:addRig(Rig.r15("Catcher", { shirt = "#d83a3a", pants = "#2a1c1c" }))
catcher.root.CFrame = Rig.lookAt(Vector3.new(0, Rig.REST_HEIGHT, -32), Vector3.new(0, Rig.REST_HEIGHT, 0))
Rig.fk(catcher)
local marker = scene:addBox(CFrame.new(0, -50, 0), Vector3.new(3, 0.12, 3), "#ffd646")

-- left to right as the camera sees the line from the front (as Cinematic sorts them)
local order = table.clone(runners)
table.sort(order, function(a, b) return a.x > b.x end)
local PICKED = 4 -- (the server picks at random)
local picked = order[PICKED]
local me = runners[2]

local function headOf(r)
	return r.rig.parts.Head.CFrame
end

-- the camera, as the game moves it: each new shot is reached with Shot.transition, then the shot moves it
local eye, look = Shot.behind(me.rig.root.CFrame, headOf(me).Position)
local key, fromEye, fromLook, moveStart = nil, eye, look, 0
for f = 0, math.floor(SECONDS * FPS) - 1 do
	local t = f * DT
	local k, te, tl
	if t < T_PICK then
		k = "Lineup"
		te, tl = Shot.lineup(line, t, LINEUP)
	elseif t < T_PICK + ROULETTE then
		k = "Sweep"
		te, tl = Shot.sweep(line, 12, t - T_PICK, ROULETTE)
		local index = Shot.hopIndex(t - T_PICK, ROULETTE, #order, PICKED)
		marker.CFrame = CFrame.new(order[index].pos + Vector3.new(0, 0.05, 0))
	elseif t < T_BACK then
		k = if t >= T_CHOSEN then "Chosen" else "Face"
		te, tl = Shot.face(line, headOf(picked), t >= T_CHOSEN)
		marker.CFrame = CFrame.new(picked.pos + Vector3.new(0, 0.05, 0))
	else
		-- the hand-back (0.8 s, up and over), then the camera behind you; the Hero runs alone
		k = "Back"
		marker.CFrame = CFrame.new(0, -50, 0)
		picked.speed += (24 - picked.speed) * math.min(1, DT * 4)
		picked.pos += Vector3.new(0, 0, -picked.speed * DT)
		local p = picked.pos + Vector3.new(0, Rig.REST_HEIGHT, 0)
		picked.rig.root.CFrame = Rig.lookAt(p, p + Vector3.new(0, 0, -1))
		RunMotion.step(picked.rec, DT, picked.speed, true, false)
		Rig.fk(picked.rig)
		te, tl = Shot.behind(me.rig.root.CFrame, headOf(me).Position)
	end
	if k ~= key then
		key, fromEye, fromLook, moveStart = k, eye, look, t
	end
	local span = if k == "Back" then 0.8 else Shot.TransitionTime
	local a = (t - moveStart) / span
	if a < 1 then
		eye, look = Shot.transition(fromEye, fromLook, te, tl, a)
	else
		eye, look = te, tl
	end
	scene:frame(eye, look)
end
scene:save(nil, FPS, 1280, 720)
