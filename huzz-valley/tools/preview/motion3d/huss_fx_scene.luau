-- The premium huss (owner, Oct 22 16:00: "can you please make the huss look better and more premium"), on an R6
-- body like the game's: his R6 run (HuzzAnimations R6Run), his Dash Right / Left blended in for the huss as
-- Gameplay/R6Huss draws it, the eased sideways push (Shared/RunMotion.pushSpeed), the speed lines
-- (Shared/RunMotion.hussLines, Gameplay/Feel) and the new afterimages (Config/Run.Dash.Ghosts: see-through glowing
-- copies of the body left along the move, fading out), filmed with the round camera (Shared/CinematicShot).
-- Runs at full speed; husses right at 0.8 s, left at 2.0 s.  OLD=1: the huss before (thin white lines, no copies).
-- sh video.sh huss_fx_scene.luau out.mp4   (repo root)
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local KFS = require("./kfs")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local Run = Env.load(SHARED .. "Config/Run.lua")
local Round = Env.load(SHARED .. "Config/Round.lua")
local RunMotion = Env.load(SHARED .. "RunMotion.lua")
local HussPose = Env.load(SHARED .. "R6HussPose.lua")
local Shot = Env.load(SHARED .. "CinematicShot.lua")
local OLD = process.env.OLD ~= nil
local PACK = process.env.PACK ~= nil -- (his pack's Dash Left / Right, as the huss was 14:37 to 17:21)

local lib = roblox.Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile("huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do inst.Parent = lib end
local run = KFS.load(lib:FindFirstChild("R6Run", true))
local dashes = { [1] = KFS.load(lib:FindFirstChild("R6DashRight", true)), [-1] = KFS.load(lib:FindFirstChild("R6DashLeft", true)) }

local scene = Scene.new()
local rig = scene:addRig(Rig.r6("Me", { shirt = "#26262e", pants = "#3a4a6a", skin = "#e9c29a", hair = "#1a1414" }))
for i = -4, 40 do
	for _, x in { -18, -12, -6, 0, 6, 12, 18 } do
		scene:addBox(CFrame.new(x, 0.03, -i * 4), Vector3.new(0.5, 0.06, 0.5), "#6f9a52")
	end
end

local FPS, DT = 30, 1 / 30
local D, GH, LINES = Run.Dash, Run.Dash.Ghosts, Run.Dash.Lines
local width = if OLD then 0.09 else LINES.Width
local speed = Round.Speeds.Runner
local pos = Vector3.zero
local look, right = Vector3.new(0, 0, -1), Vector3.new(1, 0, 0)
local DASHES = { [0.8] = 1, [2.0] = -1 }
local dash, push = nil, nil
local ghosts = {} -- { boxes, at }
for f = 0, 3.2 * FPS - 1 do
	local t = f * DT
	for at, side in DASHES do
		if math.abs(t - at) < DT / 2 then
			dash = { at = t, side = side, made = 1 }
			push = { at = t, dir = right * side }
		end
	end
	local vel = look * speed
	if push then
		local v = RunMotion.pushSpeed(Round.Dash, t - push.at)
		if v then vel += push.dir * v else push = nil end
	end
	pos += vel * DT
	rig.root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
	KFS.apply(run, rig, t % run.length)
	-- the huss: the game's huss pose for R6 blended over the run (Gameplay/R6Huss, Shared/R6HussPose)
	local age = if dash then t - dash.at else nil
	if age and age < D.Length then
		local w = math.min(math.clamp(age / D.In, 0, 1), math.clamp((D.Length - age) / D.Out, 0, 1))
		w = w * w * (3 - 2 * w)
		if PACK then
			KFS.apply(dashes[dash.side], rig, math.min(age, dashes[dash.side].length), w)
		else
			local hold = math.max(D.Length - D.Out - D.In, 1e-3)
			local u = math.clamp((age - D.In) / hold, 0, 1)
			local motors = {}
			for _, m in rig.motors do motors[m.Part1.Name] = m end
			HussPose.pose(motors, dash.side, 1 - D.Settle * (1 - u * u * (3 - 2 * u)), w)
		end
	end
	Rig.fk(rig)
	-- the afterimages: a copy every Every seconds of the push, fading out where it was left (Gameplay/Feel)
	if not OLD and dash and dash.made <= GH.Count and age >= dash.made * GH.Every - 1e-6 then
		local copy = {}
		for _, b in Rig.boxes(rig) do
			table.insert(copy, scene:addBox(b.CFrame, b.Size, string.format("#%02x%02x%02x", GH.Color.R * 255, GH.Color.G * 255, GH.Color.B * 255)))
		end
		table.insert(ghosts, { boxes = copy, at = t, from = GH.From + (1 - GH.From) * 0.12 * (dash.made - 1) })
		dash.made += 1
	end
	for _, g in ghosts do
		local u = math.clamp((t - g.at) / GH.Life, 0, 1)
		local alpha = (1 - g.from) * (1 - u) ^ 2 -- (Quad out, as the tween)
		for _, b in g.boxes do
			b.Neon, b.Alpha, b.Hidden = true, alpha, alpha <= 0.01
		end
	end
	-- the speed lines
	local ribbons = {}
	local lines = if dash then RunMotion.hussLines(rig.root.CFrame, right * dash.side, t - dash.at) else nil
	for _, l in lines or {} do
		table.insert(ribbons, { pts = { { l.from.X, l.from.Y, l.from.Z }, { l.to.X, l.to.Y, l.to.Z } },
			w = { width, width * (if OLD then 0.7 else 0.5) }, a = { l.alpha, l.alpha * 0.25 }, c = if OLD then "#ffffff" else "#d8f0ff" })
	end
	local focus = rig.root.CFrame.Position + Vector3.new(0, Shot.FocusHeight, 0) + right * 1.75
	local eye, at = Shot.behind(look, focus)
	scene:frame(eye, at, { ribbons = ribbons, fov = 72 })
end
scene:save(nil, FPS, 960, 540, { sky = "#9fd3f7", ground = "#3fbf4f" })
