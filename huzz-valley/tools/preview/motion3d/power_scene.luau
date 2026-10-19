-- The round abilities (owner Oct 19: "make simple lingo ... just make it simple"; "runner abilities (invisible, glitchy,
-- body double"; "bear trap you throw the beartrap infront of you with a small animation"; "give the rush to a person
-- only having the girl"), filmed offline by running the game's own HuzzClient/Gameplay/PowerEffects and Burst on real
-- Lune instances: this file sends it the server's "Power" messages, moves a runner (blue) and a catcher (red) with
-- Shared/RunMotion (the run, and the throw pose from the HuzzCast* attributes PowerEffects sets), makes what the
-- server would make (the shield bubble, the rush trail, the Bear Trap from Shared/BearTrap) and reads every part,
-- light, trail and billboard back each frame. Each part is its own short shot (the film cuts between them):
--    0.4 s Shield         2.2 s Invisible (4 s; drawn as the other players see it: faint, a slow shimmer)
--    6.4 s Glitchy        8.0 s Body Double (the copy runs off into the distance and puffs)
--   11.8 s Speed Boost (only while carrying the girl; she isn't drawn)
--   13.2 s Bear Trap: thrown ahead with the throw pose, arcs, lands, arms; the runner runs into it and it snaps shut
--   17.0 s Slow Wave
-- The renderer lights everything evenly and draws wedges as boxes, so this shows shapes, colours and timing, not
-- Roblox's light levels. Studio is the real check (the decoy is a real clone of the character there).
-- sh video.sh power_scene.luau out.mp4   (MOTION3D_KEEP=<dir> keeps a still of each ability at its peak:
-- tools/preview/powers_vs_og.py <dir> makes the sheet)
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
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
local LENGTH = 18.8

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
		LocalPlayer = { UserId = 99 },
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
}
Shared.WaitForChild = function(self, n) return self[n] end
services.ReplicatedStorage = { WaitForChild = function(_, n) return if n == "Shared" then Shared else nil end }
local Gameplay = { Sfx = { __value = { play = function() end } }, Burst = token(GAMEPLAY .. "Burst.lua") }
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
	bubble.Name, bubble.Shape, bubble.Size, bubble.Material, bubble.Color = "HuzzShield", roblox.Enum.PartType.Ball, Vector3.new(7, 7, 7), roblox.Enum.Material.ForceField, Powers.Shield.Accent
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
	trail.Color = roblox.ColorSequence.new(Powers.SpeedBoost.Accent, Color3.new(1, 1, 1))
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
		local model = BearTrap.build(TRAP.Accent)
		BearTrap.pose(model, CFrame.new(TRAP_AT) * CFrame.Angles(0, math.atan2(-TRAP_DIR.X, -TRAP_DIR.Z), 0), 0)
		model.Parent = folder("HuzzTraps")
		trap = { model = model, armAt = t + TRAP.Flight + TRAP.Arm }
		fakeTask.delay(TRAP.Arm, function() BearTrap.arm(model, true) end)
	end)
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
		local k = math.clamp(t - 2.6, 0, 3.6)
		return at(-4 - 1.5 * k, 2), Vector3.new(-1, 0, 0), if t > 2.6 and t < 6.2 then 1.5 else 0
	end },
	{ from = 6.1, name = "Glitchy", runner = function(t)
		local go = 6.4 + wind("Glitchy") - FX.Flash -- (the ghosts and the push start after WindUp)
		local k = math.clamp((t - go) / Powers.Glitchy.Time, 0, 1)
		return at(-10 + Powers.Glitchy.Distance * k, 2), Vector3.new(1, 0, 0), if k > 0 and k < 1 then Powers.Glitchy.Distance / Powers.Glitchy.Time else 0
	end },
	{ from = 7.8, name = "Body Double", runner = function(t)
		local k = math.clamp(t - 8.5, 0, 3)
		local dir = Vector3.new(0.6, 0, 1).Unit
		return at(-1, 2) + dir * 3 * k, if t > 8.4 then dir else Vector3.new(0, 0, 1), if t > 8.5 then 3 else 0
	end },
	{ from = 11.6, name = "Speed Boost", runner = function(t)
		-- (running at 16; the boost adds Boost after the wind-up)
		local k = math.clamp(t - 11.8, 0, 1.2)
		local w = wind("SpeedBoost")
		local speed = if t > 11.8 + w then 16 + Powers.SpeedBoost.Boost elseif t > 11.8 then 16 else 0
		return at(-12 + 16 * k + Powers.SpeedBoost.Boost * math.max(0, k - w), 5), Vector3.new(1, 0, 0), speed
	end },
	{ from = 13.0, name = "Bear Trap", runner = nil }, -- (moved below: it stops when the trap snaps)
	{ from = 16.9, name = "Slow Wave", runner = nil },
}
local EVENTS = {
	{ 0.4, function() serverShield(); roundHandler("Power", { name = "Shield", id = RUNNER_ID }) end },
	{ 2.2, function()
		runnerChar:SetAttribute("InvisibleUntil", clock + Powers.Invisible.Lasts)
		roundHandler("Power", { name = "Invisible", id = RUNNER_ID, lasts = Powers.Invisible.Lasts })
	end },
	{ 6.4, function() roundHandler("Power", { name = "Glitchy", id = RUNNER_ID, at = runnerRoot.Position, dir = Vector3.new(1, 0, 0) }) end },
	{ 8.0, function()
		roundHandler("Power", { name = "BodyDouble", id = RUNNER_ID, at = runnerRoot.Position, dir = Vector3.new(-0.45, 0, -1).Unit, speed = 16, lasts = Powers.BodyDouble.Lasts })
	end },
	{ 11.8, function() serverTrail(); roundHandler("Power", { name = "SpeedBoost", id = RUNNER_ID }) end },
	{ 13.2, function()
		serverTrapThrow(13.2)
		roundHandler("Power", { name = "BearTrap", id = CATCHER_ID, at = TRAP_AT, dir = TRAP_DIR, flight = TRAP.Flight })
	end },
	{ 17.0, function() roundHandler("Power", { name = "SlowWave", id = CATCHER_ID, radius = Powers.SlowWave.Radius }) end },
}
-- a still of each ability at its peak (MOTION3D_KEEP), for powers_vs_og.py
local STILL_AT = { 0.4 + wind("Shield") + 0.12, 3.6, 6.4 + wind("Glitchy") + 0.06, 8.0 + wind("BodyDouble") + 0.9, 11.8 + wind("SpeedBoost") + 0.15, 13.2 + 0.45, 15.15, 17.0 + wind("SlowWave") + 0.2 }

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
	table.insert(ribbons, { pts = pts, w = w, a = a, c = hex(Powers.SpeedBoost.Accent), add = true })
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
local trapRun = { from = at(-13, -2), go = 14.3, speed = 10 }
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
	local cAt, cLen = catcherChar:GetAttribute("HuzzCastAt"), catcherChar:GetAttribute("HuzzCastLen")
	catcherRig.root.CFrame = Rig.lookAt(CATCHER_AT + Vector3.new(0, Y, 0), CATCHER_AT + Vector3.new(0, Y, 0) + TRAP_DIR)
	RunMotion.step(catchRec, DT, 0, true, false, nil, nil, cAt and (t - cAt), cLen, catcherChar:GetAttribute("HuzzCastKind"))
	Rig.fk(runnerRig)
	Rig.fk(catcherRig)
	syncBody(runnerChar, runnerRig)
	syncBody(catcherChar, catcherRig)
	if bubble then bubble.CFrame = runnerRoot.CFrame; bubble.Position = runnerRoot.Position end
	if bubble and t > 1.7 then bubble:Destroy(); bubble = nil end
	if trail and t > 13.0 then trail:Destroy(); trail = nil end
	-- the Body Double: PowerEffects moves its clone's root; the film draws a rig there, running
	local home = Workspace:FindFirstChild("HuzzBursts")
	local copy = home and home:FindFirstChild("HuzzBodyDouble")
	local copyRoot = copy and copy:FindFirstChild("HumanoidRootPart")
	if copyRoot then
		copyRoot.Position = copyRoot.CFrame.Position
		decoyRig.root.CFrame = copyRoot.CFrame
		RunMotion.step(decoyRec, DT, 16, true, false)
		Rig.fk(decoyRig)
		decoyRig.look = { Alpha = 1 - ltm(copyRoot) }
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
	runnerRig.look = if fade > 0.001 then { Alpha = 1 - fade } else nil

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
	elseif shot.name == "Bear Trap" or shot.name == "Slow Wave" then
		camPos, camLook = Vector3.new(0, 8, 16), Vector3.new(0, 2, -2)
	end
	camera.CFrame = CFrame.new(camPos)
	for _, s in STILL_AT do
		if t >= s - DT / 2 and t < s + DT / 2 - 1e-6 then table.insert(stills, f) end
	end
	local caption = string.format("%.2f s  %s%s", t, string.upper(shot.name),
		if shot.name == "Invisible" then "  (as others see you)" elseif snapped and t < snapped + TRAP.Hold then "  STUCK!" else "")
	scene:frame(camPos, camLook, {
		sprites = sprites, ribbons = ribbons, lights = lights, labels = labels, grades = grades, bloom = bloom, caption = caption,
		fov = 70,
	})
end
assert(snapped, "the runner never ran into the trap")
scene:save(nil, FPS, 1280, 720, { sky = "#8cc4f2", ground = "#d7914a", grid = false, stills = stills })
print("stills at frames " .. table.concat(stills, ",") .. string.format("; trap snapped at %.2f s", snapped))
