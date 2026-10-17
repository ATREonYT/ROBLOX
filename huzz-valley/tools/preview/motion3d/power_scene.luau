-- The four round powers in a row, then the prize girl on her stand, filmed offline by running the game's own
-- HuzzClient/Gameplay/PowerEffects (and Gameplay/Burst, unchanged) on real Lune instances: this file sends it the
-- server's "Power" messages, moves a runner (blue) and a catcher (red), makes what the server would make (the
-- shield bubble, the rush trail, the trap) and reads every part, light, trail and billboard back each frame.
--   0.5 s Heart Shield (runner)   1.8 s Rizz Rush (runner runs)   3.3 s Love Trap (catcher)   4.6 s Charm Wave (catcher)
--   6.4 s the prize girl over the map: first the old look (no stand, no lights, white name, gold stars), then the
--   new one (HuzzServer/GirlService.showcase: stand with a glowing band, key / rim / stand lights, her name big in
--   her rarity colour). The girl is a pink R6 stand-in at 3x (the stand's numbers are GirlService's, copied here).
-- The renderer lights everything evenly, so this shows shapes, colours and timing, not Roblox's light levels.
-- sh video.sh power_scene.luau out.mp4   (POWER_STILLS=1 with MOTION3D_KEEP=<dir> keeps a still of each power's peak)
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
local POWERS_END, SHOW_OLD, LENGTH = 6.2, 9.0, 12.4

-- ---------------------------------------------------------------------------------------------------------------
-- A small Roblox for the module: a DataModel, a camera, players, a fake clock for task.delay
local game = Instance.new("DataModel")
local Workspace = game:GetService("Workspace")
local camera = Instance.new("Camera")
camera.Parent = Workspace
Workspace.CurrentCamera = camera
local clock = 0
roblox.implementMethod("Workspace", "GetServerTimeNow", function() return clock end)
roblox.implementMethod("Instance", "WaitForChild", function(self, n) return self:FindFirstChild(n) end)
local function signal() return { Connect = function() return { Disconnect = function() end } end } end

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

local function body(name, at)
	local character = Instance.new("Model")
	character.Name = name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = at
	root.Position = at.Position
	root.Parent = character
	character.Parent = Workspace
	return character, root
end
local RUNNER_ID, CATCHER_ID = 1, 2
local runnerRig = scene:addRig(Rig.r15("Runner", { shirt = "#3d7be0", pants = "#262a36" }))
local catcherRig = scene:addRig(Rig.r15("Catcher", { shirt = "#e0473d", pants = "#2a2026" }))
local runnerStart = Vector3.new(-9, Rig.REST_HEIGHT, 0)
local catcherAt = Vector3.new(8, Rig.REST_HEIGHT, -2)
local runnerChar, runnerRoot = body("Runner", Rig.lookAt(runnerStart, runnerStart + Vector3.new(0, 0, -1)))
local catcherChar, catcherRoot = body("Catcher", Rig.lookAt(catcherAt, catcherAt + Vector3.new(-1, 0, 0.3)))
local byId = {
	[RUNNER_ID] = { UserId = RUNNER_ID, Character = runnerChar },
	[CATCHER_ID] = { UserId = CATCHER_ID, Character = catcherChar },
}
local heartbeat
local roundHandler
local services = {
	Players = { LocalPlayer = { UserId = 99 }, GetPlayerByUserId = function(_, id) return byId[id] end },
	RunService = { Heartbeat = { Connect = function(_, fn) heartbeat = fn end } },
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
	setmetatable = setmetatable, error = error, select = select, Instance = Instance, Font = roblox.Font,
	CFrame = setmetatable({ lookAt = lookAt }, { __index = roblox.CFrame }),
}
for _, k in { "Vector3", "Vector2", "Color3", "UDim", "UDim2", "Enum", "NumberRange", "NumberSequence", "ColorSequence", "NumberSequenceKeypoint", "ColorSequenceKeypoint" } do
	env[k] = roblox[k]
end
local Shared = { Net = { __value = Net }, Config = { Powers = token(SHARED .. "Config/Powers.lua") } }
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
local Look = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/Look.lua")
local Round = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/Round.lua")
load(GAMEPLAY .. "PowerEffects.lua").start()
assert(roundHandler, "PowerEffects didn't listen to the Round remote")

-- what the server makes (HuzzServer/PowerService), copied small
local PINK = Color3.fromRGB(255, 110, 190)
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
	bubble.Name, bubble.Shape, bubble.Size, bubble.Material, bubble.Color = "HuzzShield", roblox.Enum.PartType.Ball, Vector3.new(7, 7, 7), roblox.Enum.Material.ForceField, PINK
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
	trail.Color = roblox.ColorSequence.new(PINK, Color3.new(1, 1, 1))
	trail.Transparency = roblox.NumberSequence.new(0.35, 1)
	trail.LightEmission = 0.5
	trail.Parent = runnerRoot
end
local trapAt
local function serverTrap()
	trapAt = Vector3.new(catcherAt.X - 1, 0, catcherAt.Z + 0.5)
	local model = Instance.new("Model")
	model.Name = "LoveTrap"
	local R = Powers.LoveTrap.Radius
	local function piece(size, color, transparency, offset, neon)
		local p = Instance.new("Part")
		p.Shape, p.Size, p.Color, p.Transparency = roblox.Enum.PartType.Cylinder, size, color, transparency
		p.Material = if neon then roblox.Enum.Material.Neon else roblox.Enum.Material.SmoothPlastic
		p.CFrame = CFrame.new(trapAt + Vector3.new(0, offset, 0)) * CFrame.Angles(0, 0, math.rad(90))
		p.Parent = model
	end
	piece(Vector3.new(0.2, R * 2, R * 2), Color3.fromRGB(120, 20, 70), 0.1, 0.1)
	piece(Vector3.new(0.24, R * 2 - 0.8, R * 2 - 0.8), PINK, 0.25, 0.12, true)
	local sign = Instance.new("Part")
	sign.Name, sign.Transparency, sign.Size = "Sign", 1, Vector3.new(0.2, 0.2, 0.2)
	sign.CFrame = CFrame.new(trapAt + Vector3.new(0, 1.2, 0))
	sign.Position = sign.CFrame.Position
	sign.Parent = model
	local gui = Instance.new("BillboardGui")
	gui.Size = roblox.UDim2.new(2.2, 0, 2.2, 0)
	gui.Parent = sign
	local heart = Instance.new("TextLabel")
	heart.Text = "💘"
	heart.Parent = gui
	model.Parent = folder("HuzzTraps")
end

local EVENTS = {
	{ 0.5, function() serverShield(); roundHandler("Power", { name = "HeartShield", id = RUNNER_ID }) end },
	{ 1.8, function() serverTrail(); roundHandler("Power", { name = "RizzRush", id = RUNNER_ID }) end },
	{ 3.3, function() serverTrap(); roundHandler("Power", { name = "LoveTrap", id = CATCHER_ID, at = trapAt }) end },
	{ 4.6, function() roundHandler("Power", { name = "CharmWave", id = CATCHER_ID, radius = Powers.CharmWave.Radius }) end },
}
local STILL_AT = { 0.5 + 0.15 + 0.05 + 0.12, 1.8 + 0.15 + 0.05 + 0.15, 3.3 + 0.25 + 0.05 + 0.12, 4.6 + 0.25 + 0.05 + 0.2, 7.5, 11 }

-- ---------------------------------------------------------------------------------------------------------------
-- The prize girl over the map (GirlService.showcase), as a stand-in
local girl = Rig.r6("Prize", { shirt = "#7a4ad8", pants = "#3b2a6a", hair = "#ffd1ec", skin = "#ffe0ec" })
Rig.scale(girl, 3)
local RARITY = Round.Rarities[5] -- Legendary
local order = 5
local SHOW = Vector3.new(0, Round.Showcase.Height, -60)
local girlHeight = 15 -- (her body box at 3x: 5 studs x 3)
local size = Vector3.new(6, girlHeight, 3)
local radius = math.clamp(size.Z * 0.6, 1.2, math.min(size.X * 0.42, size.Z / 2 + 0.9))
local standTop = scene:addBox(CFrame.identity, Vector3.new(0.5, radius * 2, radius * 2), "#221a42")
local standBand = scene:addBox(CFrame.identity, Vector3.new(0.18, radius * 2 + 0.24, radius * 2 + 0.24), hex(RARITY.Color))
standTop.Shape, standBand.Shape, standBand.Neon = "cyl", "cyl", true

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
local function drawParts(container, sprites, lights)
	local E = roblox.Enum
	for _, p in container:GetDescendants() do
		if p:IsA("BasePart") then
			local okL, ltm = pcall(function() return p.LocalTransparencyModifier end) -- (unset in Lune until written)
			local alpha = (1 - p.Transparency) * (1 - (if okL then ltm else 0))
			local box = boxes[p]
			if not box then
				box = scene:addBox(p.CFrame, p.Size, "#ffffff")
				boxes[p] = box
			end
			box.Hidden = alpha < 0.01 or not p:IsDescendantOf(game)
			if not box.Hidden then
				box.CFrame, box.Size, box.Color = p.CFrame, p.Size, hex(p.Color)
				box.Shape = if p.Shape == E.PartType.Ball then "ball" elseif p.Shape == E.PartType.Cylinder then "cyl" else nil
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
local HEARTS = { ["💖"] = true, ["💘"] = true, ["💞"] = true }
local function drawLabels(container, labels, sprites)
	for _, g in container:GetDescendants() do
		if g:IsA("BillboardGui") and g.Enabled then
			local part = g.Parent
			local text = g:FindFirstChildOfClass("TextLabel")
			if part and part:IsA("BasePart") and text and text.TextTransparency < 0.99 then
				local at = part.CFrame.Position + g.StudsOffsetWorldSpace
				local a = 1 - text.TextTransparency
				if HEARTS[text.Text] then
					table.insert(sprites, { p = v3(at), s = r3(g.Size.Y.Scale), c = "#ff5aa8", a = r3(a), t = "heart" })
				else
					local stroke = text:FindFirstChildOfClass("UIStroke")
					table.insert(labels, { p = v3(at), text = text.Text, h = r3(g.Size.Y.Scale * 0.8), c = hex(text.TextColor3), o = if stroke then hex(stroke.Color) else nil, a = r3(a) })
				end
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
	table.insert(ribbons, { pts = pts, w = w, a = a, c = "#ff6ebe", add = true })
end

-- ---------------------------------------------------------------------------------------------------------------
local B = Look.ColorCorrection
local grades = { { b = B.Brightness, c = B.Contrast, s = B.Saturation, tint = hex(B.TintColor) } }
local bloom = { i = Look.Bloom.Intensity, size = Look.Bloom.Size, th = Look.Bloom.Threshold }
local stills = {}
local total = math.floor(LENGTH * FPS)
local nextEvent = 1
for f = 0, total - 1 do
	local t = f * DT
	clock = t
	while EVENTS[nextEvent] and t >= EVENTS[nextEvent][1] - 1e-6 do
		EVENTS[nextEvent][2]()
		nextEvent += 1
	end
	runTimers()
	-- the runner turns to face the run and dashes across during the rush
	local runFrom, runTo = 1.8, 3.1
	local k = math.clamp((t - runFrom) / (runTo - runFrom), 0, 1)
	local runnerPos = runnerStart + Vector3.new(12 * (1 - (1 - k) ^ 2), 0, 0)
	local facing = if t >= runFrom - 0.2 then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
	runnerRig.root.CFrame = Rig.lookAt(runnerPos, runnerPos + facing)
	runnerRoot.CFrame = runnerRig.root.CFrame
	runnerRoot.Position = runnerRoot.CFrame.Position -- (Lune keeps Position apart from CFrame)
	catcherRig.root.CFrame = Rig.lookAt(catcherAt, catcherAt + Vector3.new(-1, 0, 0.3))
	catcherRoot.CFrame = catcherRig.root.CFrame
	catcherRoot.Position = catcherRoot.CFrame.Position
	if bubble then bubble.CFrame = runnerRoot.CFrame; bubble.Position = runnerRoot.Position end
	if bubble and t > 1.6 then bubble:Destroy(); bubble = nil end
	Rig.fk(runnerRig)
	Rig.fk(catcherRig)
	if heartbeat then heartbeat(DT) end

	local sprites, ribbons, lights, labels = {}, {}, {}, {}
	for _, b in boxes do b.Hidden = true end -- (a part the module destroyed isn't listed any more: hide its box)
	for _, name in { "HuzzBursts", "HuzzShields", "HuzzTraps" } do
		local c = Workspace:FindFirstChild(name)
		if c then
			drawParts(c, sprites, lights)
			drawLabels(c, labels, sprites)
		end
	end
	drawTrail(trail, t, ribbons)

	-- the prize girl: hidden during the powers; then the old look, then the new one
	local showing = t >= POWERS_END
	local new = t >= SHOW_OLD
	local base = CFrame.new(SHOW + Vector3.new(0, girlHeight / 2, 0))
	local pose = base * CFrame.new(0, math.sin(t * 1.1) * Round.Showcase.Bob, 0) * CFrame.Angles(0, (t * Round.Showcase.Spin + 2.6) % (2 * math.pi), 0)
	-- (her root sits 1/4 of her height under her middle in a stand-in R6 at 3x: put her feet on the stand)
	girl.root.CFrame = pose * CFrame.new(0, -girlHeight / 2 + 9, 0)
	Rig.fk(girl)
	local feet = pose * CFrame.new(0, -girlHeight / 2, 0)
	local flat = CFrame.Angles(0, 0, math.rad(90))
	standTop.CFrame, standBand.CFrame = feet * CFrame.new(0, -0.27, 0) * flat, feet * CFrame.new(0, -0.3, 0) * flat
	standTop.Hidden, standBand.Hidden = not new, not new
	local girlIn = false
	for _, r in scene.rigs do if r == girl then girlIn = true end end
	if showing and not girlIn then scene:addRig(girl) end
	if showing then
		local nameAt = pose.Position + Vector3.new(0, girlHeight / 2 + 3 * 1.6, 0)
		if new then
			-- GirlService.showcase's title: name big in her rarity colour, rarity + stars in white under it. Its board
			-- is 7.2 studs tall plus 44 px (the pixel floor), worked out here for the camera's distance
			local dist = (nameAt - camera.CFrame.Position).Magnitude
			local studsPerPx = 2 * dist * math.tan(math.rad(35)) / 720
			local board = 3 * 2.4 + 44 * studsPerPx
			nameAt = pose.Position + Vector3.new(0, girlHeight / 2 + 3 * 0.5 + board / 2, 0) -- (SizeOffset 0.5: its bottom over her head)
			table.insert(labels, { p = v3(nameAt + Vector3.new(0, board * 0.18, 0)), text = string.upper("Mikasa"), h = r3(board * 0.62 * 0.75), c = hex(RARITY.Color), o = "#141228" })
			table.insert(labels, { p = v3(nameAt - Vector3.new(0, board * 0.3, 0)), text = "LEGENDARY  " .. string.rep("★", order), h = r3(board * 0.32 * 0.75), c = "#ffffff", o = "#141228" })
			table.insert(lights, { p = v3((feet * CFrame.new(0, 0.2, 0)).Position), c = hex(RARITY.Color:Lerp(Color3.new(1, 1, 1), 0.55)), b = 0.7, r = girlHeight * 0.9 })
			table.insert(lights, { p = v3((pose * CFrame.new(0, 1.8, -(1.5 + 4.5))).Position), c = "#fff4ec", b = 0.65, r = girlHeight * 0.75 })
			table.insert(lights, { p = v3((pose * CFrame.new(0, 3, 6)).Position), c = hex(RARITY.Color:Lerp(Color3.new(1, 1, 1), 0.3)), b = 0.55, r = girlHeight * 0.75 })
			table.insert(sprites, { p = v3((feet * CFrame.new(0, -0.3, 0)).Position), s = r3(radius * 3.2), c = hex(RARITY.Color), a = 0.35, t = "Glow", add = true })
		else
			-- the old rating board: gold stars, white name, rarity in colour (smaller)
			table.insert(labels, { p = v3(nameAt + Vector3.new(0, 1.6, 0)), text = string.rep("★", order) .. string.rep("☆", 7 - order), h = 1.2, c = "#ffd65c", o = "#141228" })
			table.insert(labels, { p = v3(nameAt), text = "Mikasa", h = 1.9, c = "#ffffff", o = "#141228" })
			table.insert(labels, { p = v3(nameAt - Vector3.new(0, 1.5, 0)), text = "LEGENDARY", h = 1.2, c = hex(RARITY.Color), o = "#141228" })
		end
	end

	-- camera: wide on the powers, then from the field looking up at her (as in the owner's recording at 18 s)
	local camPos, camLook, caption
	if not showing then
		camPos, camLook = Vector3.new(0, 7.5, 16.5), Vector3.new(0, 2.2, -1)
		caption = string.format("%.2f s  powers", t)
	else
		local s = math.clamp((t - POWERS_END) / (LENGTH - POWERS_END), 0, 1)
		camPos = Vector3.new(-8 + 10 * s, 6, -14 + 6 * s)
		camLook = SHOW + Vector3.new(0, girlHeight * 0.55, 0)
		caption = if new then "after: stand, lights, title" else "before: the old look"
	end
	camera.CFrame = CFrame.new(camPos)
	for _, s in STILL_AT do
		if t >= s - DT / 2 and t < s + DT / 2 - 1e-6 then table.insert(stills, f) end
	end
	scene:frame(camPos, camLook, {
		sprites = sprites, ribbons = ribbons, lights = lights, labels = labels, grades = grades, bloom = bloom, caption = caption,
		fov = 70,
	})
end
scene:save(nil, FPS, 1280, 720, { sky = "#8cc4f2", ground = "#d7914a", grid = false, stills = stills })
print("stills at frames " .. table.concat(stills, ","))
