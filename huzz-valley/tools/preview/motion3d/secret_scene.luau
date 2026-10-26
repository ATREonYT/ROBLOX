-- The Secret girl's arrival cutscene, filmed offline by running the game's own code: HuzzClient/Gameplay/SecretReveal
-- (M.start and M.build, unchanged) drives real Lune instances (parts, beams, trails, emitters, the impact-frame
-- ScreenGui, the Highlight, the colour grade, the camera), and this file only reads them back each frame and draws
-- them: beams as curved camera-facing strips (Bezier from the attachments' axes and CurveSize, Wrap/Stretch texture),
-- trails from their attachments' history, every ParticleEmitter simulated from its own properties (Rate, Emit,
-- TimeScale, Shape, SpreadAngle, Speed, Drag, Acceleration, Squash, flipbooks, LockedToPart, orientation), the
-- grade as Roblox's ColorCorrection maths over the whole picture (the game's Config/Look grade too). As if every
-- effect picture were uploaded (FxTexture.ready = true). Bloom is faked with a soft glow on Neon parts.
-- The girl is a pink R6 stand-in at the showcase's 3x size, placed by the server's maths (GirlService.showcase);
-- "you" stand 80 studs away (the camera eases back to your own view at the end). ~1 s before and after.
-- sh video.sh secret_scene.luau out.mp4   (MOTION3D_KEEP=<dir> keeps the contact-sheet beats; SECRET_NOTEX=1 films
-- today's Studio look with nothing uploaded; her name card and the dip to black are drawn too)
-- DIVINE=1 films the Divine girl's cutscene instead (HuzzClient/Gameplay/DivineReveal, picked by the same play()):
-- DIVINE=1 SECRET_NOTEX=1 sh video.sh secret_scene.luau divine.mp4
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")
local process = require("@lune/process")
local CFrame, Vector3, Color3, Instance = roblox.CFrame, roblox.Vector3, roblox.Color3, roblox.Instance
local DIVINE = process.env.DIVINE == "1"
local FOLDER = if DIVINE then "HuzzDivineReveal" else "HuzzSecretReveal"
local NAME_GUI = if DIVINE then "HuzzDivineName" else "HuzzSecretName"
local GRADE = if DIVINE then "HuzzDivineGrade" else "HuzzSecretGrade"
local Rig = require("./rig")
local Scene = require("./scene")
local Env = require("./env")
local Sim = require("./aura_sim") -- (hex, the flipbook layouts, a seeded rng)
local hex, rng = Sim.hex, Sim.rng

local SRC = Env.src
local scene = Scene.new()
local FPS, DT = 30, 1 / 30
local PRE, POST = 1, 1

-- ---------------------------------------------------------------------------------------------------------------
-- A small stand-in for the bits of Roblox the module touches (proxies for services, real Lune instances for parts)
local game = Instance.new("DataModel")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local terrain = Instance.new("Terrain")
terrain.Parent = Workspace
local camera = Instance.new("Camera")
camera.Parent = Workspace
Workspace.CurrentCamera = camera

local AT = 1000 -- RevealAt (server time)
local clock = AT - PRE
roblox.implementMethod("Workspace", "GetServerTimeNow", function() return clock end)

local emits = {} -- emitter -> pending :Emit counts
roblox.implementMethod("ParticleEmitter", "Emit", function(self, n)
	emits[self] = (emits[self] or 0) + (n or 16)
end)
local function signal() return { Connect = function() return { Disconnect = function() end } end, Wait = function() end } end
roblox.implementMethod("Instance", "GetAttributeChangedSignal", function() return signal() end)

-- the girl's model: one box the size of her body; PivotTo/GetBoundingBox as Roblox's (pivot = her root part)
local girl = Rig.r6("Secret", { shirt = "#ff7ac8", pants = "#b04a9a", hair = "#ffd1ec", skin = "#ffe0ec" })
Rig.scale(girl, 3)
local function bounds(rig)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), -Vector3.new(math.huge, math.huge, math.huge)
	for _, p in rig.parts do
		if not p.hidden then
			local c = rig.root.CFrame:PointToObjectSpace(p.CFrame.Position)
			lo, hi = lo:Min(c - p.Size / 2), hi:Max(c + p.Size / 2)
		end
	end
	for _, d in rig.decor do
		local c = rig.root.CFrame:PointToObjectSpace((d.part.CFrame * d.offset).Position)
		lo, hi = lo:Min(c - d.Size / 2), hi:Max(c + d.Size / 2)
	end
	return (lo + hi) / 2, hi - lo
end
local centreOff, bodySize = bounds(girl) -- (centre in her root's frame)
local model = Instance.new("Model")
model.Name = "SecretGirl"
model.Parent = Workspace
local pivot = CFrame.identity
roblox.implementMethod("Model", "GetBoundingBox", function() return pivot * CFrame.new(centreOff), bodySize end)
roblox.implementMethod("Model", "GetPivot", function() return pivot end)
roblox.implementMethod("Model", "PivotTo", function(_, cf) pivot = cf end)

Lighting.ClockTime = 14.2 -- (Config/Look's early afternoon; set below from Look too)
local Round = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/Round.lua")
local S = Round.Showcase
-- GirlService.showcase: her box's bottom sits Showcase.Height over the floor (floor = y 0 here)
pivot = CFrame.new(Vector3.new(0, S.Height + bodySize.Y / 2, 0) - centreOff)
model:SetAttribute("Base", pivot)
model:SetAttribute("RevealAt", AT)
model:SetAttribute("GirlName", if DIVINE then "Celeste" else "C.C.") -- (GirlService.showcase sets her name; C.C. is one of the two Secret girls; Celeste a stand-in name)
if DIVINE then model:SetAttribute("RevealKind", "Divine") end

-- "you": 80 studs from the spot, your camera behind you looking at the middle of the map
local DIR = Vector3.new(0.35, 0, 1).Unit
local you = Rig.r15("You", { shirt = "#3d7be0", pants = "#262a36" })
local youAt = DIR * 80
you.root.CFrame = Rig.lookAt(youAt + Vector3.new(0, Rig.REST_HEIGHT, 0), Vector3.new(0, Rig.REST_HEIGHT, 0))
Rig.fk(you)
local youCam = Rig.lookAt(youAt + DIR * 14 + Vector3.new(0, 9, 0), Vector3.new(0, 10, 0))
camera.CFrame = youCam
camera.FieldOfView = 70

-- module loading: game services by proxy, our modules by token
local player = Instance.new("Player")
local playerGui = Instance.new("PlayerGui")
playerGui.Parent = player
roblox.implementMethod("Instance", "WaitForChild", function(self, n) return self:FindFirstChild(n) end)
local root = Instance.new("Part") -- (your root part, for the camera's direction)
root.Name = "HumanoidRootPart"
root.CFrame = CFrame.new(youAt + Vector3.new(0, 3, 0))
root.Position = root.CFrame.Position -- (Lune keeps Position apart from CFrame)
local character = Instance.new("Model")
root.Parent = character
local bound -- the RenderStepped callback the game binds
-- The module's own steady clock (os.clock) runs on the film's time, not this computer's: otherwise a heavy frame
-- here would skip the cutscene ahead (the Divine one ran 1.4x fast). It ticks with the waits before the cutscene
-- starts, then frame by frame from the moment the game binds its camera.
local simClock, simAtBind = 0, 0
local services = {
	Players = { LocalPlayer = player },
	RunService = {
		RenderStepped = signal(),
		BindToRenderStep = function(_, _, _, fn) bound = fn; simAtBind = simClock end,
		UnbindFromRenderStep = function() bound = nil end,
	},
	CollectionService = {
		GetInstanceAddedSignal = function() return signal() end,
		GetTagged = function() return { model } end,
	},
	Workspace = Workspace, Lighting = Lighting,
}
local Random = {}
Random.__index = Random
function Random.new(seed)
	return setmetatable({ s = (math.floor(seed or 1) % 2147483647 + 2147483647) % 2147483647 + 1 }, Random)
end
function Random:_next()
	self.s = (self.s * 48271) % 2147483647
	return self.s / 2147483647
end
function Random:NextNumber(a, b) a = a or 0; b = b or 1; return a + (b - a) * self:_next() end
function Random:NextInteger(a, b) return math.floor(a + (b - a + 1) * self:_next()) end

local loaded = {}
local function token(path) return { __path = path } end
local load
local function req(t)
	if type(t) == "table" and t.__value ~= nil then return t.__value end
	return load(t.__path)
end
local env = {
	game = { GetService = function(_, n) return services[n] or game:GetService(n) end },
	require = req, typeof = typeof, task = task, math = math, table = table, string = string, warn = print,
	print = print, pcall = pcall, type = type, tostring = tostring, tonumber = tonumber, pairs = pairs, ipairs = ipairs,
	setmetatable = setmetatable, error = error, select = select, Random = Random,
	os = setmetatable({ clock = function() return simClock end }, { __index = os }),
}
local guis = {} -- (every ScreenGui the module makes, by name: the impact frame, her name card, the dip to black)
env.Instance = { new = function(cls, ...)
	local i = Instance.new(cls, ...)
	if cls == "ScreenGui" then table.insert(guis, i) end
	return i
end }
env.Font = roblox.Font
-- (Lune 0.10.5's CFrame.lookAt faces the opposite way: the game gets Roblox's maths, as Rig.lookAt)
local function lookAt(eye, at, up)
	up = up or Vector3.new(0, 1, 0)
	local look = (at - eye).Unit
	local right = look:Cross(up)
	right = if right.Magnitude > 1e-4 then right.Unit else Vector3.new(1, 0, 0)
	return CFrame.fromMatrix(eye, right, right:Cross(look))
end
env.CFrame = setmetatable({ lookAt = lookAt }, { __index = roblox.CFrame })
for _, k in { "Vector3", "Vector2", "Color3", "UDim", "UDim2", "Enum", "NumberRange", "NumberSequence", "ColorSequence", "NumberSequenceKeypoint", "ColorSequenceKeypoint" } do
	env[k] = roblox[k]
end
-- every effect picture as if uploaded: "Fx/<Name>" -> "rbxfx://<Name>"; SECRET_NOTEX=1 films today's Studio look
-- instead (nothing uploaded: beams are plain layers, particles Roblox's built-in sparkle, drawn as soft dots)
local noTex = process.env.SECRET_NOTEX == "1"
local ImageIds = setmetatable({}, { __index = function(_, key)
	local n = string.match(key, "^Fx/(.+)$")
	return if n and not noTex then "rbxfx://" .. n else nil
end })
local SHARED = SRC .. "/ReplicatedStorage/Shared/"
local Shared = {
	SecretReveal = token(SHARED .. "SecretReveal.lua"), DivineReveal = token(SHARED .. "DivineReveal.lua"), FxTexture = token(SHARED .. "FxTexture.lua"),
	Config = { Round = token(SHARED .. "Config/Round.lua"), ImageIds = { __value = ImageIds } },
}
Shared.WaitForChild = function(self, n) return self[n] end
services.ReplicatedStorage = { WaitForChild = function(_, n) return if n == "Shared" then Shared else nil end }
local Motion = { reduced = process.env.SECRET_CALM == "1" }
local client = {
	UI = { Motion = { __value = Motion } },
	Gameplay = { Sfx = { __value = { play = function() end, beat = function() end } },
		DivineReveal = token(SRC .. "/StarterPlayer/StarterPlayerScripts/HuzzClient/Gameplay/DivineReveal.lua") },
}
client.UI.WaitForChild = function(self, n) return self[n] end
client.WaitForChild = function(self, n) return self[n] end
client.Gameplay.Parent = client
function load(path)
	if loaded[path] then return loaded[path] end
	local e = table.clone(env)
	e.script = if string.find(path, "Gameplay/") then { Parent = client.Gameplay } else { Parent = Shared }
	local result = luau.load(fs.readFile(path), { debugName = path, environment = e })()
	loaded[path] = result
	return result
end
local Reveal = load(SHARED .. (if DIVINE then "DivineReveal.lua" else "SecretReveal.lua"))
local Look = load(SHARED .. "Config/Look.lua")
-- the game's Lighting as HuzzServer/LookService leaves it (the cutscene changes it and must put it back)
for key, v in Look.Lighting do pcall(function() (Lighting :: any)[key] = v end) end
for cls, props in { ColorCorrectionEffect = Look.ColorCorrection, BloomEffect = Look.Bloom, SunRaysEffect = Look.SunRays, Atmosphere = Look.Atmosphere } do
	local inst = Instance.new(cls)
	inst.Name = "Huzz" .. cls
	for key, v in props do pcall(function() (inst :: any)[key] = v end) end
	inst.Parent = Lighting
end
local M = load(SRC .. "/StarterPlayer/StarterPlayerScripts/HuzzClient/Gameplay/SecretReveal.lua")


-- ---------------------------------------------------------------------------------------------------------------
-- Reading the instances back
local function texName(id)
	return if type(id) == "string" then string.match(id, "^rbxfx://(.+)$") else nil
end
local function r3(v) return math.floor(v * 1000 + 0.5) / 1000 end
local function v3(p) return { r3(p.X), r3(p.Y), r3(p.Z) } end
local function nsample(ns, t)
	local k = ns.Keypoints
	for i = 1, #k - 1 do
		if t <= k[i + 1].Time then
			local f = (t - k[i].Time) / math.max(k[i + 1].Time - k[i].Time, 1e-6)
			return k[i].Value + (k[i + 1].Value - k[i].Value) * f
		end
	end
	return k[#k].Value
end
local function csample(cs, t)
	local k = cs.Keypoints
	for i = 1, #k - 1 do
		if t <= k[i + 1].Time then
			local f = (t - k[i].Time) / math.max(k[i + 1].Time - k[i].Time, 1e-6)
			return k[i].Value:Lerp(k[i + 1].Value, f)
		end
	end
	return k[#k].Value
end
local function worldCF(a)
	local ok, cf = pcall(function() return a.WorldCFrame end)
	if ok and cf then return cf end
	local ok2, p = pcall(function() return a.WorldPosition end)
	return if ok2 and p then CFrame.new(p) else CFrame.identity
end
local function folderOf() return Workspace:FindFirstChild(FOLDER) end

-- Beam: cubic Bezier from Attachment0 along its X axis by CurveSize0 to Attachment1 (against its X axis)
local function drawBeam(b, now, ribbons)
	if b.Width0 <= 0.001 and b.Width1 <= 0.001 then return end
	local c0, c1 = worldCF(b.Attachment0), worldCF(b.Attachment1)
	local P0, P3 = c0.Position, c1.Position
	local P1, P2 = P0 + c0.RightVector * b.CurveSize0, P3 - c1.RightVector * b.CurveSize1
	local n = math.max(b.Segments, 1)
	local pts, w, a, cs, u = {}, {}, {}, {}, {}
	local len, last = 0, P0
	local wrap = b.TextureMode == roblox.Enum.TextureMode.Wrap
	for i = 0, n do
		local s = i / n
		local p = P0 * (1 - s) ^ 3 + P1 * 3 * (1 - s) ^ 2 * s + P2 * 3 * (1 - s) * s ^ 2 + P3 * s ^ 3
		len += (p - last).Magnitude
		last = p
		table.insert(pts, v3(p))
		table.insert(w, r3(b.Width0 + (b.Width1 - b.Width0) * s))
		table.insert(a, r3(1 - nsample(b.Transparency, s)))
		table.insert(cs, hex(csample(b.Color, s)))
		table.insert(u, if wrap then r3(len / b.TextureLength - now * b.TextureSpeed) else r3(s - now * b.TextureSpeed))
	end
	table.insert(ribbons, { pts = pts, w = w, a = a, c = cs[1], cs = cs, add = b.LightEmission >= 0.5, t = texName(b.Texture), u = u })
end

-- Trails: each keeps its attachments' recent positions
local trails = {}
local function stepTrail(tr, now)
	local h = trails[tr] or {}
	trails[tr] = h
	local p0, p1 = worldCF(tr.Attachment0).Position, worldCF(tr.Attachment1).Position
	table.insert(h, 1, { p0 = p0, p1 = p1, t = now })
	while #h > 0 and now - h[#h].t > tr.Lifetime do table.remove(h) end
end
local function drawTrail(tr, now, ribbons)
	local h = trails[tr]
	if not h or #h < 2 then return end
	local pts, w, a, cs = {}, {}, {}, {}
	for _, k in h do
		local s = math.clamp((now - k.t) / tr.Lifetime, 0, 1)
		table.insert(pts, v3((k.p0 + k.p1) / 2))
		table.insert(w, r3((k.p0 - k.p1).Magnitude * nsample(tr.WidthScale, s)))
		table.insert(a, r3(1 - nsample(tr.Transparency, s)))
		table.insert(cs, hex(csample(tr.Color, s)))
	end
	table.insert(ribbons, { pts = pts, w = w, a = a, c = cs[1], cs = cs, add = tr.LightEmission >= 0.5, t = texName(select(2, pcall(function() return tr.Texture end))) })
end

-- ParticleEmitters, simulated from their own properties
local systems = {}
local function randRange(r) return r.Min + rng:NextNumber() * (r.Max - r.Min) end
local function spawnParticle(e, sys, part)
	local cf, size = part.CFrame, part.Size
	local E = roblox.Enum
	local NORMALS = { Top = Vector3.new(0, 1, 0), Bottom = Vector3.new(0, -1, 0), Front = Vector3.new(0, 0, -1), Back = Vector3.new(0, 0, 1), Right = Vector3.new(1, 0, 0), Left = Vector3.new(-1, 0, 0) }
	local up = cf:VectorToWorldSpace(NORMALS[e.EmissionDirection.Name])
	local p, dir
	if e.Shape == E.ParticleEmitterShape.Sphere then
		local d = Vector3.new(rng:NextNumber() * 2 - 1, rng:NextNumber() * 2 - 1, rng:NextNumber() * 2 - 1)
		d = if d.Magnitude > 0.01 then d.Unit else Vector3.new(0, 1, 0)
		local r = if e.ShapeStyle == E.ParticleEmitterShapeStyle.Surface then 1 else rng:NextNumber() ^ (1 / 3)
		p = cf.Position + Vector3.new(d.X * size.X, d.Y * size.Y, d.Z * size.Z) / 2 * r
		dir = if e.ShapeInOut == E.ParticleEmitterShapeInOut.Inward then -d else d
	elseif e.Shape == E.ParticleEmitterShape.Disc then
		local a = rng:NextNumber() * math.pi * 2 * e.ShapePartial
		local r = if e.ShapeStyle == E.ParticleEmitterShapeStyle.Surface then 1 else math.sqrt(rng:NextNumber())
		p = cf.Position + (cf.RightVector * math.cos(a) * size.X + cf.LookVector * math.sin(a) * size.Z) / 2 * r
		dir = up
	else
		p = cf * Vector3.new((rng:NextNumber() - 0.5) * size.X, (rng:NextNumber() - 0.5) * size.Y, (rng:NextNumber() - 0.5) * size.Z)
		dir = up
	end
	-- SpreadAngle: a random turn within +-X and +-Y degrees about the two axes across the direction
	local sx, sy = math.rad(e.SpreadAngle.X), math.rad(e.SpreadAngle.Y)
	if sx > 0 or sy > 0 then
		local ax = dir:Cross(Vector3.new(0.3, 0.1, 0.9)).Unit
		local ay = dir:Cross(ax).Unit
		dir = CFrame.fromAxisAngle(ax, (rng:NextNumber() * 2 - 1) * sx):VectorToWorldSpace(dir)
		dir = CFrame.fromAxisAngle(ay, (rng:NextNumber() * 2 - 1) * sy):VectorToWorldSpace(dir)
	end
	local g = Sim.SHEETS[texName(e.Texture) or ""]
	local layoutOn = e.FlipbookLayout ~= roblox.Enum.ParticleFlipbookLayout.None
	table.insert(sys.particles, {
		p = p, rel = cf:PointToObjectSpace(p), v = dir * randRange(e.Speed), age = 0, life = randRange(e.Lifetime),
		rot = randRange(e.Rotation), spin = randRange(e.RotSpeed),
		frame = if g and layoutOn then rng:NextInteger(0, g * g - 1) else nil,
		fps = if g and layoutOn then randRange(e.FlipbookFramerate) else nil,
	})
end
local function stepEmitter(e, dt)
	local sys = systems[e]
	if not sys then
		sys = { particles = {}, acc = 0 }
		systems[e] = sys
	end
	local part = e.Parent
	local sdt = dt * e.TimeScale
	if e.Enabled and e.Rate > 0 then
		sys.acc += e.Rate * sdt
		while sys.acc >= 1 do
			sys.acc -= 1
			spawnParticle(e, sys, part)
		end
	end
	for _ = 1, emits[e] or 0 do spawnParticle(e, sys, part) end
	emits[e] = nil
	local alive = {}
	local halve = 0.5 ^ (e.Drag * sdt)
	for _, q in sys.particles do
		q.age += sdt
		if q.age < q.life then
			q.v += e.Acceleration * sdt
			q.v *= halve
			q.p += q.v * sdt
			q.rel += part.CFrame:VectorToObjectSpace(q.v * sdt)
			q.rot += q.spin * sdt
			table.insert(alive, q)
		end
	end
	sys.particles = alive
end
local function drawEmitter(e, cam, sprites)
	local sys = systems[e]
	if not sys then return end
	local E = roblox.Enum
	local name = texName(e.Texture)
	local g = Sim.SHEETS[name or ""]
	if e.FlipbookLayout == E.ParticleFlipbookLayout.None then g = nil end
	for _, q in sys.particles do
		local s = q.age / q.life
		local at = if e.LockedToPart then e.Parent.CFrame * q.rel else q.p
		if e.ZOffset ~= 0 then at += (cam - at).Unit * e.ZOffset end
		local frame
		if g then
			local n = g * g
			if e.FlipbookMode == E.ParticleFlipbookMode.OneShot then
				frame = math.min(n - 1, math.floor(s * n))
			elseif e.FlipbookStartRandom and (q.fps or 0) == 0 then
				frame = q.frame
			else
				frame = (math.floor(q.age * (q.fps or 0)) + (if e.FlipbookStartRandom then q.frame else 0)) % n
			end
		end
		local orient = e.Orientation
		local flat = orient == E.ParticleOrientation.VelocityPerpendicular and math.abs(q.v.Unit.Y) > 0.7
		table.insert(sprites, {
			p = v3(at), s = r3(nsample(e.Size, s)), c = hex(csample(e.Color, s)), a = r3(math.clamp(1 - nsample(e.Transparency, s), 0, 1)),
			t = name, r = r3(q.rot), add = e.LightEmission >= 0.5, b = if e.Brightness ~= 1 then e.Brightness else nil,
			g = g, f = frame, flat = if flat then true else nil, sq = r3(nsample(e.Squash, s)),
			v = if orient == E.ParticleOrientation.VelocityParallel then v3(q.v) else nil,
		})
	end
end

-- parts: Neon glows (a soft halo stands in for Roblox's bloom), ForceField is a faint additive shell
local function drawParts(folder, boxes, sprites)
	local E = roblox.Enum
	for _, p in folder:GetChildren() do
		if p:IsA("BasePart") and p.Transparency < 0.99 then
			local alpha = 1 - p.Transparency
			local ball = p.Shape == E.PartType.Ball
			local box = boxes[p]
			if not box then
				box = scene:addBox(p.CFrame, p.Size, "#ffffff")
				boxes[p] = box
			end
			box.CFrame, box.Size, box.Color, box.Hidden = p.CFrame, p.Size, hex(p.Color), false
			box.Shape = if ball then "ball" elseif p.Shape == E.PartType.Cylinder then "cyl" else nil
			if p.Material == E.Material.ForceField then
				box.Add, box.Alpha, box.Neon = true, alpha * 0.3, true
			elseif p.Material == E.Material.Neon then
				box.Add, box.Alpha, box.Neon = nil, alpha, true
				local big = math.max(p.Size.X, p.Size.Y, p.Size.Z)
				table.insert(sprites, { p = v3(p.CFrame.Position), s = r3(big * 2), c = hex(p.Color), a = r3(alpha * 0.55), t = "Glow", add = true })
			else
				box.Add, box.Alpha, box.Neon = nil, alpha, nil
			end
		elseif boxes[p] then
			boxes[p].Hidden = true
		end
	end
end

-- the module's ScreenGuis, drawn over the picture (not graded, like Roblox's): the impact frame, her name card (frames
-- and text laid out from their scale sizes on the 1280 x 720 screen, a UIScale about the card's middle, TextScaled
-- under its UITextSizeConstraint) and the dip to black
local function guiNamed(name)
	for _, g in guis do
		local ok, n = pcall(function() return g.Name end) -- (destroyed after the cleanup)
		if ok and n == name then return g end
	end
	return nil
end
local function overlayOf()
	local out = { rects = {}, texts = {} }
	local any = false
	local frameGui = guiNamed("HuzzImpactFrame")
	if frameGui and frameGui.Enabled then
		local paper = frameGui:FindFirstChildOfClass("Frame")
		local burst = paper:FindFirstChildOfClass("Frame")
		local lines, fade = {}, nil
		for _, l in burst:GetChildren() do
			if l:IsA("Frame") then
				table.insert(lines, { a = l.Rotation, w = l.Size.X.Offset, len = l.Size.Y.Offset, x = l.Position.X.Offset, y = l.Position.Y.Offset, c = hex(l.BackgroundColor3) })
				if not fade then
					local gr = l:FindFirstChildOfClass("UIGradient")
					fade = {}
					for _, k in gr.Transparency.Keypoints do table.insert(fade, { k.Time, k.Value }) end
				end
			end
		end
		out.bg, out.lines, out.fade = hex(paper.BackgroundColor3), lines, fade
		any = true
	end
	-- the Divine one's vignette: full-screen frames, each a black fading inwards (a UIGradient at Rotation 0 or 90)
	local vig = guiNamed("HuzzDivineVignette")
	if vig and vig.Enabled then
		for _, f in vig:GetChildren() do
			if f:IsA("Frame") and f.BackgroundTransparency < 0.99 then
				local gr = f:FindFirstChildOfClass("UIGradient")
				local fade = {}
				for _, k in gr.Transparency.Keypoints do table.insert(fade, { k.Time, k.Value }) end
				table.insert(out.rects, { x = r3(f.Position.X.Scale * 1280), y = r3(f.Position.Y.Scale * 720), w = r3(f.Size.X.Scale * 1280), h = r3(f.Size.Y.Scale * 720),
					c = hex(f.BackgroundColor3), a = r3(1 - f.BackgroundTransparency), fade = fade, vfade = gr.Rotation == 90 or nil })
				any = true
			end
		end
	end
	local nameGui = guiNamed(NAME_GUI)
	if nameGui and nameGui.Enabled then
		local card = nameGui:FindFirstChild("Card")
		local SW, SH = 1280, 720
		local cw, ch = card.Size.X.Scale * SW, card.Size.Y.Scale * SH
		local cx, cy = card.Position.X.Scale * SW, card.Position.Y.Scale * SH
		local pop = card:FindFirstChildOfClass("UIScale")
		local sc = if pop then pop.Scale else 1
		local function box(g)
			local w = (g.Size.X.Scale * cw + g.Size.X.Offset) * sc
			local h = (g.Size.Y.Scale * ch + g.Size.Y.Offset) * sc
			local x = cx + (g.Position.X.Scale * cw - cw / 2) * sc
			local y = cy + (g.Position.Y.Scale * ch - ch / 2) * sc
			return x - g.AnchorPoint.X * w, y - g.AnchorPoint.Y * h, w, h
		end
		for _, g in card:GetChildren() do
			if g:IsA("TextLabel") and g.TextTransparency < 0.99 then
				local x, y, w, h = box(g)
				local limit = g:FindFirstChildOfClass("UITextSizeConstraint")
				local stroke = g:FindFirstChildOfClass("UIStroke")
				local okF, italic = pcall(function() return g.FontFace.Style == roblox.Enum.FontStyle.Italic end)
				local okW, weight = pcall(function() return g.FontFace.Weight.Value end)
				local gg = g:FindFirstChildOfClass("UIGradient") -- (a gold gradient across the text, slid by its Offset)
				local stops
				if gg then
					stops = {}
					for i = 0, 24 do table.insert(stops, { r3(i / 24), hex(csample(gg.Color, math.clamp(i / 24 - gg.Offset.X, 0, 1))) }) end
				end
				table.insert(out.texts, { g = stops, text = g.Text, x = r3(x), y = r3(y), w = r3(w), h = r3(h), c = hex(g.TextColor3), a = r3(1 - g.TextTransparency),
					max = if limit then limit.MaxTextSize * sc else nil, o = if stroke then hex(stroke.Color) else nil,
					ow = if stroke then stroke.Thickness * sc else nil, italic = okF and italic or nil, weight = if okW then weight else 700 })
				any = true
			elseif g:IsA("Frame") and g.BackgroundTransparency < 0.99 then
				local x, y, w, h = box(g)
				local gr = g:FindFirstChildOfClass("UIGradient")
				local fade
				if gr then
					fade = {}
					for _, k in gr.Transparency.Keypoints do table.insert(fade, { k.Time, k.Value }) end
				end
				table.insert(out.rects, { x = r3(x), y = r3(y), w = r3(w), h = r3(h), c = hex(g.BackgroundColor3), a = r3(1 - g.BackgroundTransparency), fade = fade })
				any = true
			end
		end
	end
	local dip = guiNamed("HuzzRevealDip")
	if dip and dip.Parent then
		local black = dip:FindFirstChildOfClass("Frame")
		if black and black.BackgroundTransparency < 0.99 then
			out.dim = r3(1 - black.BackgroundTransparency)
			out.dimc = hex(black.BackgroundColor3)
			any = true
		end
	end
	return if any then out else nil
end

-- ---------------------------------------------------------------------------------------------------------------
scene:addRig(girl)
scene:addRig(you)
girl.look = {}
local B = Look.ColorCorrection
local baseGrade = { b = B.Brightness, c = B.Contrast, s = B.Saturation, tint = hex(B.TintColor) }
local boxes = {}
local stills = {}
-- the contact-sheet beats (tools/preview/secret_vs_ref.py pairs them with the reference)
local STILL_AT = if DIVINE then { 0.2, 0.8, 1.4, 2.0, 2.5, 2.9, 3.2, 3.6, 4.1, 4.6, 5.0, 5.3, 5.9, 6.6, 7.3, 7.9, 8.3, 9.0, 9.8, 10.5 }
	else { 0.3, 0.7, 1.15, 1.6, 1.95, 2.45, 2.75, 3.1, 3.46, 3.6, 4.1, 4.75, 5.6, 6.2, 6.55, 7.2, 7.65, 7.95, 8.8 }
local total = math.floor((Reveal.LENGTH + PRE + POST) * FPS)
player.Character = character
M.start()
-- (lets the deferred play() run: it builds the effects and binds the camera; our model has no parts, so play()
-- first waits its 2 s for them to stream in)
local waitFrom = os.clock()
repeat task.wait(0.05); simClock += 0.05 until bound or os.clock() - waitFrom > 4
assert(bound and guiNamed(if DIVINE then NAME_GUI else "HuzzImpactFrame"), "the cutscene didn't start")
local lastOverlayErr

for f = 0, total - 1 do
	local t = f * DT - PRE
	clock = AT + t
	simClock = simAtBind + t + PRE
	if t >= 0 and bound then bound() end
	if t < 0 then
		model:PivotTo(model:GetAttribute("Base") * CFrame.new(0, -2000, 0)) -- (hidden until the cutscene's first frame)
	end
	girl.root.CFrame = pivot
	Rig.fk(girl)
	local folder = folderOf()
	local sprites, ribbons, lights = {}, {}, {}
	local camPos = camera.CFrame.Position
	if folder then
		for _, d in folder:GetDescendants() do
			if d:IsA("ParticleEmitter") then stepEmitter(d, DT) end
			if d:IsA("Trail") then stepTrail(d, t) end
		end
		for _, d in folder:GetDescendants() do
			if d:IsA("ParticleEmitter") then drawEmitter(d, camPos, sprites) end
			if d:IsA("Trail") then drawTrail(d, t, ribbons) end
		end
		drawParts(folder, boxes, sprites)
		local hl = folder:FindFirstChildOfClass("Highlight")
		girl.look.Emit = if hl then 1 - hl.FillTransparency else nil
	else
		for _, b in boxes do b.Hidden = true end
		girl.look.Emit = nil
	end
	for _, b in terrain:GetChildren() do
		if b:IsA("Beam") then drawBeam(b, t, ribbons) end
	end
	local grades = { baseGrade }
	local cc = Lighting:FindFirstChild(GRADE) -- (Look's own grade is baseGrade)
	if cc then table.insert(grades, { b = cc.Brightness, c = cc.Contrast, s = cc.Saturation, tint = hex(cc.TintColor) }) end
	local okO, overlay = pcall(overlayOf) -- (gone after the cleanup)
	if not okO then
		if f == 0 or overlay ~= lastOverlayErr then print("overlay error: " .. tostring(overlay)) end
		lastOverlayErr = overlay
		overlay = nil
	end
	if folder then
		local orb = folder:FindFirstChild("Core")
		if orb and orb.Transparency < 1 then
			table.insert(lights, { p = v3(orb.CFrame.Position), c = "#d8c8ff", b = 0.6 + orb.Size.X * 0.2, r = 40 })
		end
		-- the module's PointLights (her key and rim lights, the beams' light on the floor), up to the renderer's 4
		for _, d in folder:GetDescendants() do
			if d:IsA("PointLight") and d.Enabled and d.Brightness > 0.01 and #lights < 4 then
				table.insert(lights, { p = v3(d.Parent.CFrame.Position), c = hex(d.Color), b = r3(d.Brightness), r = r3(d.Range) })
			end
		end
	end
	for _, s in STILL_AT do
		if f == math.floor((s + PRE) * FPS + 0.5) then table.insert(stills, f) end -- (by frame number: float steps missed some)
	end
	-- the sky (an IMITATION of Roblox's: the day cycle from Lighting.ClockTime, dark navy at night and warm at dawn;
	-- the Atmosphere's Color, Haze and Density tint the horizon and the sky and bring the fog in; Sky.StarCount
	-- gives the stars; OutdoorAmbient lights the ground at night)
	local clockNow = Lighting.ClockTime
	local elev = math.sin((clockNow - 6) / 12 * math.pi) -- (the sun's height: 1 at noon, -1 at midnight)
	local day = math.clamp(elev * 3 + 0.2, 0, 1)
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	local haze = if atmo then math.clamp(atmo.Haze / 2.4, 0, 1) * math.clamp(atmo.Density / 0.42, 0, 1) else 0
	local aCol = if atmo then atmo.Color else Color3.new(0.6, 0.7, 0.9)
	local function scale(c, x) return Color3.new(c.R * x, c.G * x, c.B * x) end
	local zen = Color3.fromRGB(9, 11, 34):Lerp(scale(aCol, 0.32), 0.65 * haze)
	local hor = Color3.fromRGB(18, 22, 58):Lerp(scale(aCol, 0.62), 0.85 * haze)
	zen = zen:Lerp(Color3.fromRGB(110, 170, 235), day)
	hor = hor:Lerp(Color3.fromRGB(199, 225, 255), day)
	hor = hor:Lerp(Color3.fromRGB(235, 150, 120), math.clamp(1 - math.abs(elev - 0.08) / 0.18, 0, 1) * 0.6)
	local skyInst = Lighting:FindFirstChildOfClass("Sky")
	local starCount = if skyInst then skyInst.StarCount else 3000
	local okA, outdoor = pcall(function() return Lighting.OutdoorAmbient end)
	local amb = (if okA then outdoor else Color3.fromRGB(138, 140, 156)):Lerp(Color3.fromRGB(223, 240, 255), day)
	local env = { sky = hex(zen), horizon = hex(hor), dim = 0.2 + 0.8 * day, amb = hex(amb), stars = r3((1 - day) * starCount / 5000 * 0.9),
		fog = { 40, 520 - 340 * haze * (1 - day) } }
	local bl = Lighting:FindFirstChildOfClass("BloomEffect")
	local bloom = if bl then { i = r3(bl.Intensity), size = r3(bl.Size), th = r3(bl.Threshold) } else nil
	local cf = camera.CFrame
	scene:frame(cf.Position, cf.Position + cf.LookVector * 10, {
		sprites = sprites, ribbons = ribbons, lights = lights, fov = camera.FieldOfView, grades = grades, overlay = overlay,
		caption = string.format("%.2f s", t), env = env, bloom = bloom,
	})
end
scene:save(nil, FPS, 1280, 720, { sky = "#9fd0f5", ground = "#5aa64c", grid = false, stills = stills })
print("stills at frames " .. table.concat(stills, ","))
