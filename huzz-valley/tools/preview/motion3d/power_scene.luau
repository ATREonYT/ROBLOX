-- The round abilities (owner Oct 19: "make simple lingo ... just make it simple"; "runner abilities (invisible, glitchy,
-- body double"; "bear trap you throw the beartrap infront of you with a small animation"; "give the rush to a person
-- only having the girl"), filmed offline by running the game's own HuzzClient/Gameplay/PowerEffects and Burst on real
-- Lune instances: this file sends it the server's "Power" messages, moves a runner (blue) and a catcher (red) with
-- Shared/RunMotion (the run, and the throw pose from the HuzzCast* attributes PowerEffects sets), makes what the
-- server would make (the shield bubble, the rush trail, the Bear Trap from Shared/BearTrap) and reads every part,
-- light, trail and billboard back each frame. Each part is its own short shot (the film cuts between them):
--    0.4 s Shield         2.2 s Invisible (4 s; drawn as the other players see it: faint, a slow shimmer, and back;
--                         POWER_ME=1 films it as the runner sees it, with the big bubble)
--    7.2 s Glitchy        8.8 s Body Double (the copy runs off into the distance and puffs)
--   12.6 s Speed Boost (only while carrying the girl; she isn't drawn)
--   14.0 s Bear Trap (the Love Trap's heart disc): thrown ahead with the throw pose, arcs, lands, arms; the runner runs
--          into it and it springs
--   17.8 s Slow Wave
--   Oct 20 ("make them well made"): 20.0 s Banana Peel (dropped behind, the chasing catcher slips: stars),
--   23.2 s Smoke Bomb (the catcher walks in slowed and loses the runner), 29.4 s Radar (the runner glows where they
--   stand; drawn white, pink in the game), 34.8 s Lasso (the rope catches the runner and pulls them in a little).
--   The Shield's end (ShieldEnd) is shown at 1.7 s, 6 s early.
-- The renderer lights everything evenly and draws wedges as boxes, so this shows shapes, colours and timing, not
-- Roblox's light levels. Studio is the real check (the decoy is a real clone of the character there).
-- sh video.sh power_scene.luau out.mp4   (MOTION3D_KEEP=<dir> keeps a still of each ability at its peak:
-- tools/preview/powers_vs_og.py <dir> makes the sheet)
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local CFrame, Vector3, Color3, Instance = roblox.CFrame, roblox.Vector3, roblox.Color3, roblox.Instance
local Rig = require("./rig")
local Scene = require("./scene")
local Env = require("./env")
local Sim = require("./aura_sim")
local hex = Sim.hex

local SRC = Env.src
local SHARED = SRC .. "/ReplicatedStorage/Shared/"
local GAMEPLAY = SRC .. "/StarterPlayer/StarterPlayerScripts/HuzzClient/Gameplay/"
local scene = Scene.new()
local FPS, DT = 30, 1 / 30
local LENGTH = 37.6
-- POWER_FROM / POWER_TO (seconds): draw only that part (everything still runs from 0, so the effects are the same);
-- e.g. POWER_FROM=34.6 for the Lasso alone
local DRAW_FROM, DRAW_TO = tonumber(process.env.POWER_FROM or "") or 0, tonumber(process.env.POWER_TO or "") or LENGTH

-- ---------------------------------------------------------------------------------------------------------------
-- A small Roblox for the module: a DataModel, a camera, players, a fake clock for task.delay and os.clock
local game = Instance.new("DataModel")
local Workspace = game:GetService("Workspace")
local camera = Instance.new("Camera")
camera.Parent = Workspace
Workspace.CurrentCamera = camera
local clock = 0
roblox.implementMethod("Workspace", "GetServerTimeNow", function() return clock end)
roblox.implementMethod("Workspace", "Raycast", function() return nil end) -- (a flat open field)
roblox.implementMethod("ParticleEmitter", "Emit", function() end) -- (sparks: not drawn in this film)
roblox.implementMethod("Instance", "WaitForChild", function(self, n) return self:FindFirstChild(n) end)

local timers = {} -- { at, fn, args }
local fakeTask = {
	delay = function(s, fn, ...) table.insert(timers, { at = clock + (s or 0), fn = fn, args = table.pack(...) }) end,
	spawn = function(fn, ...) fn(...) end,
	defer = function(fn, ...) table.insert(timers, { at = clock, fn = fn, args = table.pack(...) }) end,
	wait = function() return 0 end,
}
local function runTimers()
	local due = {}
	for i = #timers, 1, -1 do
		if timers[i].at <= clock + 1e-6 then table.insert(due, 1, table.remove(timers, i)) end
	end
	for _, t in due do t.fn(table.unpack(t.args, 1, t.args.n)) end
end
-- every Heartbeat connection (Burst's loop, the invisibility fades, a Body Double's run), with Disconnect
local beats = {}
local function connect(_, fn)
	local c = { fn = fn }
	c.Disconnect = function() c.off = true end
	table.insert(beats, c)
	return c
end

-- The characters: real Parts copied from the rigs every frame (PowerEffects ghosts and clones them, and fades them)
local function rgb(s) return Color3.fromRGB(tonumber(s:sub(2, 3), 16), tonumber(s:sub(4, 5), 16), tonumber(s:sub(6, 7), 16)) end
local function body(name, rig)
	local character = Instance.new("Model")
	character.Name = name
	for n, p in rig.parts do
		local part = Instance.new("Part")
		part.Name = n
		part.Size = p.Size
		part.Color = rgb(p.Color)
		part.Transparency = if p.hidden then 1 else 0
		part.Parent = character
	end
	character.Parent = Workspace
	return character, character:FindFirstChild("HumanoidRootPart")
end
local function syncBody(character, rig)
	for n, p in rig.parts do
		local part = character:FindFirstChild(n)
		if part then
			part.CFrame = p.CFrame
			part.Position = p.CFrame.Position -- (Lune keeps Position apart from CFrame)
		end
	end
end
local function named(rig)
	rig.byName = {}
	for _, m in rig.motors do rig.byName[m.Name] = m end
	return rig
end
local RUNNER_ID, CATCHER_ID = 1, 2
local RUNNER_LOOK = { shirt = "#3d7be0", pants = "#262a36" }
local runnerRig = named(scene:addRig(Rig.r15("Runner", RUNNER_LOOK)))
local catcherRig = named(scene:addRig(Rig.r15("Catcher", { shirt = "#e0473d", pants = "#2a2026" })))
local decoyRig = named(Rig.r15("Decoy", RUNNER_LOOK)) -- (drawn while the Body Double runs)
local SERVER_PINK = Color3.fromRGB(255, 110, 190) -- (HuzzServer/PowerService PINK: the bubble, the rush trail, the trap's glow)
local runnerChar, runnerRoot = body("Runner", runnerRig)
local catcherChar, catcherRoot = body("Catcher", catcherRig)
local byId = {
	[RUNNER_ID] = { UserId = RUNNER_ID, Character = runnerChar },
	[CATCHER_ID] = { UserId = CATCHER_ID, Character = catcherChar },
}
local roundHandler
local services = {
	-- (the viewer is a third player: everything is drawn as the other players see it)
	Players = {
		LocalPlayer = { UserId = tonumber(process.env.POWER_ME or "") or 99 }, -- (99: a third player watching)
		GetPlayerByUserId = function(_, id) return byId[id] end,
		GetPlayers = function() return { byId[RUNNER_ID], byId[CATCHER_ID] } end,
	},
	RunService = { Heartbeat = { Connect = connect } },
	Workspace = Workspace,
}
local Net = { get = function() return { OnClientEvent = { Connect = function(_, fn) roundHandler = fn end } } end }

-- module loading: our modules by token, game services by proxy
local loaded = {}
local function token(path) return { __path = path } end
local load
local function req(t)
	if type(t) == "table" and t.__value ~= nil then return t.__value end
	return load(t.__path)
end
local function lookAt(eye, at)
	local look = (at - eye).Unit
	local right = look:Cross(Vector3.new(0, 1, 0))
	right = if right.Magnitude > 1e-4 then right.Unit else Vector3.new(1, 0, 0)
	return CFrame.fromMatrix(eye, right, right:Cross(look))
end
local env = {
	game = { GetService = function(_, n) return services[n] or game:GetService(n) end },
	require = req, typeof = typeof, task = fakeTask, math = math, table = table, string = string, warn = print,
	print = print, pcall = pcall, type = type, tostring = tostring, tonumber = tonumber, pairs = pairs, ipairs = ipairs,
	setmetatable = setmetatable, error = error, select = select, next = next, Instance = Instance, Font = roblox.Font,
	os = { clock = function() return clock end, time = os.time },
	RaycastParams = { new = function() return {} end },
	CFrame = setmetatable({ lookAt = lookAt }, { __index = roblox.CFrame }),
}
for _, k in { "Vector3", "Vector2", "Color3", "UDim", "UDim2", "Enum", "NumberRange", "NumberSequence", "ColorSequence", "NumberSequenceKeypoint", "ColorSequenceKeypoint" } do
	env[k] = roblox[k]
end
local Shared = {
	Net = { __value = Net },
	Config = { Powers = token(SHARED .. "Config/Powers.lua") },
	BearTrap = token(SHARED .. "BearTrap.lua"),
	BananaPeel = token(SHARED .. "BananaPeel.lua"),
}
Shared.WaitForChild = function(self, n) return self[n] end
services.ReplicatedStorage = { WaitForChild = function(_, n) return if n == "Shared" then Shared else nil end }
local Gameplay = { Sfx = { __value = { play = function() end } }, Burst = token(GAMEPLAY .. "Burst.lua"), Ghosts = token(GAMEPLAY .. "Ghosts.lua") }
function load(path)
	if loaded[path] then return loaded[path] end
	local e = table.clone(env)
	e.script = { Parent = Gameplay }
	local result = luau.load(fs.readFile(path), { debugName = path, environment = e })()
	loaded[path] = result
	return result
end
local Powers = load(SHARED .. "Config/Powers.lua")
local BearTrap = load(SHARED .. "BearTrap.lua")
local BananaPeel = load(SHARED .. "BananaPeel.lua")
local Look = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/Look.lua")
local RunMotion = Env.load("huzz-valley/src/ReplicatedStorage/Shared/RunMotion.lua")
load(GAMEPLAY .. "PowerEffects.lua").start()
assert(roundHandler, "PowerEffects didn't listen to the Round remote")
local FX = Powers.Fx
local function wind(name) return (FX[name].WindUp or FX.WindUp) + FX.Flash end

-- what the server makes (HuzzServer/PowerService), copied small
local function folder(name)
	local f = Workspace:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = Workspace
	end
	return f
end
local bubble
local function serverShield()
	bubble = Instance.new("Part")
	bubble.Name, bubble.Shape, bubble.Size, bubble.Material, bubble.Color = "HuzzShield", roblox.Enum.PartType.Ball, Vector3.new(7, 7, 7), roblox.Enum.Material.ForceField, SERVER_PINK
	bubble.CFrame = runnerRoot.CFrame
	bubble.Position = runnerRoot.CFrame.Position
	bubble.Parent = folder("HuzzShields")
end
local trail
local function serverTrail()
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 1.2, 0), Vector3.new(0, -1.6, 0)
	a0.Parent, a1.Parent = runnerRoot, runnerRoot
	trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1, trail.Lifetime = a0, a1, 0.35
	trail.Color = roblox.ColorSequence.new(SERVER_PINK, Color3.new(1, 1, 1))
	trail.Transparency = roblox.NumberSequence.new(0.35, 1)
	trail.Parent = runnerRoot
end
-- the Bear Trap: lands Flight after the throw (the server inserts it then), arms Arm later, snaps on the runner
local TRAP = Powers.BearTrap
local CATCHER_AT = Vector3.new(8, 0, -2)
local TRAP_DIR = Vector3.new(-1, 0, 0)
local TRAP_AT = CATCHER_AT + TRAP_DIR * TRAP.Throw
local trap -- { model, armAt }
local function serverTrapThrow(t)
	fakeTask.delay(TRAP.Flight, function()
		local model = BearTrap.build(SERVER_PINK)
		BearTrap.pose(model, CFrame.new(TRAP_AT) * CFrame.Angles(0, math.atan2(-TRAP_DIR.X, -TRAP_DIR.Z), 0), 0)
		model.Parent = folder("HuzzTraps")
		trap = { model = model, armAt = t + TRAP.Flight + TRAP.Arm }
		fakeTask.delay(TRAP.Arm, function() BearTrap.arm(model, true) end)
	end)
end

-- (Oct 20) the Banana Peel: lands behind the runner after the toss, arms Arm later; the first catcher on it slips
local PEEL = Powers.BananaPeel
local peel -- { model, at, armAt }
local slipAt, slipUntil = nil, nil
local function serverPeel(t)
	local dir = Vector3.new(-1, 0, 0) -- (the runner runs off to -X)
	local spot = runnerRoot.Position - dir * PEEL.Back
	local land = FX.BananaPeel.WindUp + FX.Flash + 0.3 -- (HuzzServer/PowerService USE.BananaPeel)
	local floorAt = Vector3.new(spot.X, 0, spot.Z)
	peel = { at = floorAt, armAt = t + land + PEEL.Arm }
	roundHandler("Power", { name = "BananaPeel", id = RUNNER_ID, at = floorAt, dir = dir, land = land })
	fakeTask.delay(land, function()
		local model = BananaPeel.build()
		BananaPeel.pose(model, CFrame.new(floorAt) * CFrame.Angles(0, math.atan2(-dir.X, -dir.Z), 0))
		BananaPeel.arm(model, false)
		model.Parent = folder("HuzzTraps")
		peel.model = model
		fakeTask.delay(PEEL.Arm, function() BananaPeel.arm(model, true) end)
	end)
end
-- (Oct 20) Radar: each runner in Range glows when the sweep reaches them
local function serverRadar()
	roundHandler("Power", { name = "Radar", id = CATCHER_ID, range = Powers.Radar.Range, sweep = Powers.Radar.Sweep })
	local d = (runnerRoot.Position - catcherRoot.Position).Magnitude
	fakeTask.delay(FX.Radar.WindUp + FX.Flash + Powers.Radar.Sweep * d / Powers.Radar.Range, function()
		runnerChar:SetAttribute("SpottedUntil", clock + Powers.Radar.Lasts)
	end)
end
-- (Oct 20) the Lasso: the rope leaves after the wind-up at Speed; the step below finds the runner
local LASSO = Powers.Lasso
local rope -- { t0 }
local lassoAt, lassoDist = nil, 0
local function serverLasso(t)
	rope = { t0 = t + FX.Lasso.WindUp + FX.Flash }
	roundHandler("Power", { name = "Lasso", id = CATCHER_ID, dir = TRAP_DIR, range = LASSO.Range, speed = LASSO.Speed })
end

-- ---------------------------------------------------------------------------------------------------------------
-- The shots. The runner: where it stands, which way it faces, how fast it runs, per moment (the film cuts between
-- shots, so a shot may start somewhere new).
local Y = Rig.REST_HEIGHT
local function at(x, z) return Vector3.new(x, 0, z) end
local CAM = Vector3.new(0, 1, 1).Unit
local SHOTS = {
	{ from = 0, name = "Shield", runner = function() return at(-6, 2), Vector3.new(0, 0, 1), 0 end },
	{ from = 1.9, name = "Invisible", runner = function(t)
		local k = math.clamp(t - 2.6, 0, 4.2)
		return at(-4 - 1.5 * k, 2), Vector3.new(-1, 0, 0), if t > 2.6 and t < 6.8 then 1.5 else 0
	end },
	{ from = 6.9, name = "Glitchy", runner = function(t)
		local go = 7.2 + wind("Glitchy") - FX.Flash -- (the ghosts and the push start after WindUp)
		local k = math.clamp((t - go) / Powers.Glitchy.Time, 0, 1)
		return at(-10 + Powers.Glitchy.Distance * k, 2), Vector3.new(1, 0, 0), if k > 0 and k < 1 then Powers.Glitchy.Distance / Powers.Glitchy.Time else 0
	end },
	{ from = 8.6, name = "Body Double", runner = function(t)
		local k = math.clamp(t - 9.3, 0, 3)
		local dir = Vector3.new(0.6, 0, 1).Unit
		return at(-1, 2) + dir * 3 * k, if t > 9.2 then dir else Vector3.new(0, 0, 1), if t > 9.3 then 3 else 0
	end },
	{ from = 12.4, name = "Speed Boost", runner = function(t)
		-- (running at 16; the boost adds Boost after the wind-up)
		local k = math.clamp(t - 12.6, 0, 1.2)
		local w = wind("SpeedBoost")
		local speed = if t > 12.6 + w then 16 + Powers.SpeedBoost.Boost elseif t > 12.6 then 16 else 0
		return at(-12 + 16 * k + Powers.SpeedBoost.Boost * math.max(0, k - w), 5), Vector3.new(1, 0, 0), speed
	end },
	{ from = 13.8, name = "Bear Trap", runner = nil }, -- (moved below: it stops when the trap snaps)
	{ from = 17.7, name = "Slow Wave", runner = nil },
	-- (Oct 20) the runner drops a peel behind while running off; the catcher chasing slips on it
	{ from = 19.8, name = "Banana Peel", runner = function(t)
		local x = math.max(-7, 3 - 8 * math.max(0, t - 19.8))
		return at(x, 0), Vector3.new(-1, 0, 0), if x > -7 then 8 else 0
	end, catcher = function(t)
		if slipAt then return slipAt, Vector3.new(-1, 0, 0), 0 end
		local x = 12 - 10 * math.max(0, t - 20.5)
		return at(x, 0), Vector3.new(-1, 0, 0), if t > 20.5 then 10 else 0
	end },
	-- the cloud hides the runner's name tag; the catcher walks in, slowed, and loses them as they slip away
	{ from = 23.0, name = "Smoke Bomb", runner = function(t)
		local x = math.max(-8, -1 - 3 * math.max(0, t - 25.6))
		return at(x, 0), if t > 25.5 then Vector3.new(-1, 0, 0) else Vector3.new(0, 0, 1), if t > 25.6 and x > -8 then 3 else 0
	end, catcher = function(t)
		local tt = math.max(0, t - 23.9)
		local x, speed = 12 - 8 * tt, 8
		if x < 7 then x, speed = 7 - 8 * Powers.SmokeBomb.Slow * (tt - 5 / 8), 8 * Powers.SmokeBomb.Slow end
		if x <= 1.5 then x, speed = 1.5, 0 end
		return at(x, 0), Vector3.new(-1, 0, 0), if t > 23.9 then speed else 0
	end },
	-- the catcher pings; the runner glows where they stand (only shows them)
	{ from = 29.2, name = "Radar", runner = function() return at(-6, 2), Vector3.new(0, 0, 1), 0 end },
	-- the rope flies straight ahead, catches the runner and pulls them in a little; they run off again
	{ from = 34.6, name = "Lasso", runner = function(t)
		if not lassoAt then return at(-6, -2), Vector3.new(0, 0, 1), 0 end
		local k = math.clamp((t - lassoAt) / LASSO.PullTime, 0, 1)
		local x = -6 + lassoDist * (1 - (1 - k) ^ 3)
		local free = lassoAt + LASSO.PullTime + LASSO.Hold
		if t > free then return at(x - 12 * (t - free), -2), Vector3.new(-1, 0, 0), 12 end
		return at(x, -2), Vector3.new(1, 0, 0), 0
	end },
}
local EVENTS = {
	{ 0.4, function() serverShield(); roundHandler("Power", { name = "Shield", id = RUNNER_ID }) end },
	{ 1.7, function() -- (the film ends it early: 6 s in a game)
		bubble:Destroy(); bubble = nil
		roundHandler("Power", { name = "ShieldEnd", id = RUNNER_ID, at = runnerRoot.Position })
	end },
	{ 2.2, function()
		local from = clock + FX.Invisible.WindUp -- (HuzzServer/PowerService: from the end of the wind-up)
		runnerChar:SetAttribute("InvisibleFrom", from)
		runnerChar:SetAttribute("InvisibleUntil", from + Powers.Invisible.Lasts)
		roundHandler("Power", { name = "Invisible", id = RUNNER_ID, lasts = Powers.Invisible.Lasts })
	end },
	{ 7.2, function() roundHandler("Power", { name = "Glitchy", id = RUNNER_ID, at = runnerRoot.Position, dir = Vector3.new(1, 0, 0) }) end },
	{ 8.8, function()
		roundHandler("Power", { name = "BodyDouble", id = RUNNER_ID, at = runnerRoot.Position, dir = Vector3.new(-0.45, 0, -1).Unit, speed = 16, lasts = Powers.BodyDouble.Lasts })
	end },
	{ 12.6, function() serverTrail(); roundHandler("Power", { name = "SpeedBoost", id = RUNNER_ID }) end },
	{ 14.0, function()
		serverTrapThrow(14.0)
		roundHandler("Power", { name = "BearTrap", id = CATCHER_ID, at = TRAP_AT, dir = TRAP_DIR, flight = TRAP.Flight })
	end },
	{ 17.8, function() roundHandler("Power", { name = "SlowWave", id = CATCHER_ID, radius = Powers.SlowWave.Radius }) end },
	{ 19.8, function() catcherChar:SetAttribute("HuzzCastAt", nil); runnerChar:SetAttribute("SpottedUntil", nil) end },
	{ 20.0, function() serverPeel(20.0) end },
	{ 23.2, function()
		roundHandler("Power", { name = "SmokeBomb", id = RUNNER_ID, at = Vector3.new(-1, 0, 0), radius = Powers.SmokeBomb.Radius, lasts = Powers.SmokeBomb.Lasts })
	end },
	{ 29.4, function() serverRadar() end },
	{ 34.8, function() serverLasso(34.8) end },
}
-- a still of each ability at its peak (MOTION3D_KEEP), for powers_vs_og.py (in its NAMES order)
local STILL_AT = { 0.4 + wind("Shield") + 0.12, 2.2 + wind("Invisible") + 0.15, 7.2 + wind("Glitchy") + 0.06, 8.8 + wind("BodyDouble") + 0.35,
	12.6 + wind("SpeedBoost") + 0.15, 14.0 + TRAP.Flight + 0.12, 15.95, 17.8 + wind("SlowWave") + 0.2,
	20.0 + wind("BananaPeel") + 0.5, 21.4, 23.2 + wind("SmokeBomb") + 1.4, 30.3, 35.5 }

-- ---------------------------------------------------------------------------------------------------------------
-- Reading the instances back
local function r3(v) return math.floor(v * 1000 + 0.5) / 1000 end
local function v3(p) return { r3(p.X), r3(p.Y), r3(p.Z) } end
local function nsample(ns, t)
	local k = ns.Keypoints
	for i = 1, #k - 1 do
		if t <= k[i + 1].Time then
			return k[i].Value + (k[i + 1].Value - k[i].Value) * (t - k[i].Time) / math.max(k[i + 1].Time - k[i].Time, 1e-6)
		end
	end
	return k[#k].Value
end
local boxes = {}
local function ltm(p)
	local okL, v = pcall(function() return p.LocalTransparencyModifier end) -- (unset in Lune until written)
	return if okL then v else 0
end
local function drawParts(container, sprites, lights)
	local E = roblox.Enum
	for _, p in container:GetDescendants() do
		if p:IsA("BasePart") and not p:FindFirstAncestor("HuzzBodyDouble") then
			local alpha = (1 - p.Transparency) * (1 - ltm(p))
			local box = boxes[p]
			if not box then
				box = scene:addBox(p.CFrame, p.Size, "#ffffff")
				boxes[p] = box
			end
			box.Hidden = alpha < 0.01 or not p:IsDescendantOf(game)
			if not box.Hidden then
				box.CFrame, box.Size, box.Color = p.CFrame, p.Size, hex(p.Color)
				local okS, shape = pcall(function() return p.Shape end) -- (a WedgePart has none: drawn as a box)
				shape = if okS then shape else nil
				box.Shape = if shape == E.PartType.Ball then "ball" elseif shape == E.PartType.Cylinder then "cyl" else nil
				if p.Material == E.Material.ForceField then
					box.Add, box.Alpha, box.Neon = true, alpha * 0.3, true
				elseif p.Material == E.Material.Neon then
					box.Add, box.Alpha, box.Neon = nil, alpha, true
					local big = math.max(p.Size.X, p.Size.Y, p.Size.Z)
					table.insert(sprites, { p = v3(p.CFrame.Position), s = r3(math.min(big, 3) * 1.6), c = hex(p.Color), a = r3(alpha * 0.35), t = "Glow", add = true })
				else
					box.Add, box.Alpha, box.Neon = nil, alpha, nil
				end
			end
			for _, l in p:GetChildren() do
				if l:IsA("PointLight") and l.Brightness > 0.05 and #lights < 4 then
					table.insert(lights, { p = v3(p.CFrame.Position), c = hex(l.Color), b = r3(l.Brightness * 0.5), r = l.Range })
				end
			end
		end
	end
end
local function drawLabels(container, labels)
	for _, g in container:GetDescendants() do
		if g:IsA("BillboardGui") and g.Enabled then
			local part = g.Parent
			local text = g:FindFirstChildOfClass("TextLabel")
			if part and part:IsA("BasePart") and text and text.TextTransparency < 0.99 then
				local p = part.CFrame.Position + g.StudsOffsetWorldSpace
				local stroke = text:FindFirstChildOfClass("UIStroke")
				table.insert(labels, { p = v3(p), text = text.Text, h = r3(g.Size.Y.Scale * 0.8), c = hex(text.TextColor3), o = if stroke then hex(stroke.Color) else nil, a = r3(1 - text.TextTransparency) })
			end
		end
	end
end
local history = {}
local function drawTrail(tr, now, ribbons)
	if not (tr and tr.Parent) then return end
	local p0 = (tr.Attachment0.Parent.CFrame * tr.Attachment0.CFrame).Position
	local p1 = (tr.Attachment1.Parent.CFrame * tr.Attachment1.CFrame).Position
	table.insert(history, 1, { p0 = p0, p1 = p1, t = now })
	while #history > 0 and now - history[#history].t > tr.Lifetime do table.remove(history) end
	if #history < 2 then return end
	local pts, w, a = {}, {}, {}
	for _, k in history do
		local s = math.clamp((now - k.t) / tr.Lifetime, 0, 1)
		table.insert(pts, v3((k.p0 + k.p1) / 2))
		table.insert(w, r3((k.p0 - k.p1).Magnitude))
		table.insert(a, r3(1 - nsample(tr.Transparency, s)))
	end
	table.insert(ribbons, { pts = pts, w = w, a = a, c = hex(SERVER_PINK), add = true })
end

-- ---------------------------------------------------------------------------------------------------------------
local B = Look.ColorCorrection
local grades = { { b = B.Brightness, c = B.Contrast, s = B.Saturation, tint = hex(B.TintColor) } }
local bloom = { i = Look.Bloom.Intensity, size = Look.Bloom.Size, th = Look.Bloom.Threshold }
local stills = {}
local total = math.floor(LENGTH * FPS)
local nextEvent = 1
local runRec, catchRec, decoyRec = RunMotion.new(runnerRig), RunMotion.new(catcherRig), RunMotion.new(decoyRig)
local decoyIn = false
local snapped = nil -- the moment the trap caught the runner
local trapRun = { from = at(-13, -2), go = 15.1, speed = 10 }
local stuckAt = nil
for f = 0, total - 1 do
	local t = f * DT
	clock = t
	while EVENTS[nextEvent] and t >= EVENTS[nextEvent][1] - 1e-6 do
		EVENTS[nextEvent][2]()
		nextEvent += 1
	end
	runTimers()
	-- this moment's shot
	local shot = SHOTS[1]
	for _, s in SHOTS do
		if t >= s.from then shot = s end
	end
	local pos, facing, speed
	if shot.runner then
		pos, facing, speed = shot.runner(t)
	elseif shot.name == "Bear Trap" then
		-- the runner runs at the trap; it snaps when armed and they're inside Radius (PowerService.step's rule)
		if stuckAt then
			pos, speed = stuckAt, 0
		else
			pos = trapRun.from + Vector3.new(1, 0, 0) * trapRun.speed * math.max(0, t - trapRun.go)
			speed = if t > trapRun.go then trapRun.speed else 0
			local d = pos - TRAP_AT
			if trap and t >= trap.armAt and Vector3.new(d.X, 0, d.Z).Magnitude <= TRAP.Radius then
				stuckAt, snapped = pos, t
				trap.model:Destroy()
				roundHandler("Power", { name = "TrapSprung", id = RUNNER_ID, by = CATCHER_ID, at = pos, yaw = math.atan2(-TRAP_DIR.X, -TRAP_DIR.Z), hold = TRAP.Hold })
			end
		end
		facing = Vector3.new(1, 0, 0)
	else
		pos, facing, speed = stuckAt or at(-5, -2), Vector3.new(1, 0, 0), 0
	end
	local castAt, castLen = runnerChar:GetAttribute("HuzzCastAt"), runnerChar:GetAttribute("HuzzCastLen")
	runnerRig.root.CFrame = Rig.lookAt(pos + Vector3.new(0, Y, 0), pos + Vector3.new(0, Y, 0) + facing)
	RunMotion.step(runRec, DT, speed, true, shot.name == "Speed Boost", nil, nil, castAt and (t - castAt), castLen, runnerChar:GetAttribute("HuzzCastKind"))
	local cPos, cFace, cSpeed = CATCHER_AT, TRAP_DIR, 0
	if shot.catcher then cPos, cFace, cSpeed = shot.catcher(t) end
	local cAt, cLen = catcherChar:GetAttribute("HuzzCastAt"), catcherChar:GetAttribute("HuzzCastLen")
	catcherRig.root.CFrame = Rig.lookAt(cPos + Vector3.new(0, Y, 0), cPos + Vector3.new(0, Y, 0) + cFace)
	RunMotion.step(catchRec, DT, cSpeed, true, false, nil, nil, cAt and (t - cAt), cLen, catcherChar:GetAttribute("HuzzCastKind"))
	Rig.fk(runnerRig)
	Rig.fk(catcherRig)
	syncBody(runnerChar, runnerRig)
	syncBody(catcherChar, catcherRig)
	if bubble then bubble.CFrame = runnerRoot.CFrame; bubble.Position = runnerRoot.Position end
	if trail and t > 13.8 then trail:Destroy(); trail = nil end
	-- the peel: the first catcher on it once armed slips (PowerService stepPeels)
	if peel and peel.model and not slipAt and t >= peel.armAt then
		local d = catcherRoot.Position - peel.at
		if Vector3.new(d.X, 0, d.Z).Magnitude <= PEEL.Radius then
			slipAt, slipUntil = cPos, t + PEEL.Slip
			catcherChar:SetAttribute("SlipUntil", slipUntil)
			roundHandler("Power", { name = "PeelSlip", id = CATCHER_ID, by = RUNNER_ID, at = Vector3.new(cPos.X, 0, cPos.Z), slip = PEEL.Slip })
			peel.model:Destroy()
			peel = nil
		end
	end
	-- the rope: its tip flies from the catcher at Speed and takes the first runner it reaches (PowerService stepRopes)
	if rope and t >= rope.t0 then
		local tip = LASSO.Speed * (t - rope.t0)
		local along = (catcherRoot.Position - runnerRoot.Position).Magnitude
		if along <= tip + 0.5 then
			lassoAt, lassoDist = t, math.clamp(along - LASSO.MinGap, 0, LASSO.Pull)
			roundHandler("Power", { name = "LassoHit", id = CATCHER_ID, target = RUNNER_ID, at = runnerRoot.Position, toward = catcherRoot.Position,
				dist = lassoDist, time = LASSO.PullTime, blocked = false })
			rope = nil
		end
	end
	-- the Body Double: PowerEffects moves its clone's root; the film draws a rig there, running
	local home = Workspace:FindFirstChild("HuzzBursts")
	local copy = home and home:FindFirstChild("HuzzBodyDouble")
	local copyRoot = copy and copy:FindFirstChild("HumanoidRootPart")
	if copyRoot then
		copyRoot.Position = copyRoot.CFrame.Position
		decoyRig.root.CFrame = copyRoot.CFrame
		RunMotion.step(decoyRec, DT, 16, true, false)
		Rig.fk(decoyRig)
		-- (its pink Highlight drawn as a soft white fill: the renderer has no coloured Highlight or outline)
		local hl = copy:FindFirstChild("HuzzDoubleGlow")
		decoyRig.look = { Alpha = 1 - ltm(copyRoot), Emit = if hl then 0.6 * (1 - hl.FillTransparency) else nil }
		if not decoyIn then scene:addRig(decoyRig); decoyIn = true end
	elseif decoyIn then
		for i, r in scene.rigs do
			if r == decoyRig then table.remove(scene.rigs, i) break end
		end
		decoyIn = false
	end
	for _, c in beats do
		if not c.off then c.fn(DT) end
	end
	-- invisibility: PowerEffects fades the character's parts (LocalTransparencyModifier); draw the rig at that
	local fade = ltm(runnerChar:FindFirstChild("UpperTorso"))
	local spot = runnerChar:FindFirstChild("HuzzSpotted")
	runnerRig.look = if spot then { Emit = 0.7 * (1 - spot.FillTransparency) } elseif fade > 0.001 then { Alpha = 1 - fade } else nil

	local sprites, ribbons, lights, labels = {}, {}, {}, {}
	for _, b in boxes do b.Hidden = true end -- (a part the module destroyed isn't listed any more: hide its box)
	for _, name in { "HuzzBursts", "HuzzShields", "HuzzTraps" } do
		local c = Workspace:FindFirstChild(name)
		if c then
			drawParts(c, sprites, lights)
			drawLabels(c, labels)
		end
	end
	drawTrail(trail, t, ribbons)

	-- camera: one wide view of the field; it follows the Body Double off into the distance
	local camPos, camLook = Vector3.new(-2, 8, 17), Vector3.new(-2, 2.2, -1)
	if shot.name == "Body Double" and copyRoot then
		local d = copyRoot.CFrame.Position
		camLook = Vector3.new(-2, 2.2, -1):Lerp(Vector3.new(d.X, 2.2, d.Z), 0.45)
	elseif shot.name == "Bear Trap" or shot.name == "Slow Wave" or shot.name == "Radar" or shot.name == "Lasso" then
		camPos, camLook = Vector3.new(0, 8, 16), Vector3.new(0, 2, -2)
	elseif shot.name == "Banana Peel" or shot.name == "Smoke Bomb" then
		camPos, camLook = Vector3.new(2, 8, 17), Vector3.new(2, 2, -1)
	end
	camera.CFrame = CFrame.new(camPos)
	for _, s in STILL_AT do
		if DRAW_FROM == 0 and t >= s - DT / 2 and t < s + DT / 2 - 1e-6 then table.insert(stills, f) end -- (stills only for the whole film)
	end
	local caption = string.format("%.2f s  %s%s", t, string.upper(shot.name),
		if shot.name == "Invisible" then (if process.env.POWER_ME == "1" then "  (your own screen)" else "  (as others see you)")
		elseif shot.name == "Shield" and t >= 1.7 then "  (ends: 6 s later in a game)"
		elseif shot.name == "Bear Trap" and snapped and t < snapped + TRAP.Hold then "  STUCK!"
		elseif shot.name == "Banana Peel" and slipUntil and t < slipUntil then "  SLIP!"
		elseif shot.name == "Radar" then "  (glow drawn white here; pink in the game)"
		elseif shot.name == "Lasso" and lassoAt and t < lassoAt + LASSO.PullTime + LASSO.Hold then "  YOINK!"
		else "")
	if t >= DRAW_FROM - 1e-6 and t < DRAW_TO then scene:frame(camPos, camLook, {
		sprites = sprites, ribbons = ribbons, lights = lights, labels = labels, grades = grades, bloom = bloom, caption = caption,
		fov = 70,
	}) end
end
assert(snapped, "the runner never ran into the trap")
assert(slipAt, "the catcher never slipped on the peel")
assert(lassoAt, "the lasso never caught the runner")
scene:save(nil, FPS, 1280, 720, { sky = "#8cc4f2", ground = "#d7914a", grid = false, stills = stills })
print("stills at frames " .. table.concat(stills, ",") .. string.format("; trap snapped at %.2f s", snapped))
