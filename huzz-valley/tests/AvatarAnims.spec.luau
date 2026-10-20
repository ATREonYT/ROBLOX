-- lune run tests/AvatarAnims.spec.luau
-- Your own body is never stiff (owner, Oct 20: "also the user animations isnt there", his avatar standing in the rest
-- pose in Studio). The real Gameplay files (AvatarAnimations, Locomotion, PlayerMoves, Frame, HeadAim) and the real
-- Shared/AnimationLibrary run on a fake Studio, one way of failing at a time:
--   works         the pack's Studio copies load and play: Locomotion drives, Roblox's Animate is off;
--   never loads   the tracks load without an error but never get a length (what his screenshot looks like);
--   never moves   they get a length but the body never moves;
--   no register   KeyframeSequenceProvider refuses the copies (no IDs at all);
--   load throws   Animator:LoadAnimation errors;
--   step fails    the walk blend errors every frame;
--   attach throws something in the set-up errors;
--   no Animate    a character without Roblox's Animate script, and the tracks never load;
--   R6            an R6 avatar;
--   limbs swapped Roblox swaps in the avatar's own limbs (new Motor6Ds) after Locomotion attached: the pack still
--                 counts as playing (critic, Oct 20: the six joints were looked up once, so the old ones never moved).
-- After 5 s each must leave the body moving (the pack on the Animator, or Roblox's Animate on with the pack drawn by
-- hand by PlayerMoves), and print exactly one [HuzzAnim] line saying which. The fake Animator writes a pose on the
-- knees for the pack's tracks and on the elbows for Roblox's Animate, so the test can tell who animates.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Env = require("../tools/preview/motion3d/env")

local failed, passed = 0, 0
local function check(ok, what)
	if ok then passed += 1 else failed += 1; print("FAIL " .. what) end
end

local lib = roblox.Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile(Env.root .. "/huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do inst.Parent = lib end
local raw = lib:FindFirstChild("HuzzAnimations")
local girlMoves = roblox.Instance.new("Folder")
for _, n in { "Idle", "Walk", "Run" } do raw:FindFirstChild(n):Clone().Parent = girlMoves end

local realGet = Env.game.GetService
local SharedNode = realGet(Env.game, "ReplicatedStorage"):WaitForChild("Shared")
local GAMEPLAY = Env.root .. "/huzz-valley/src/StarterPlayer/StarterPlayerScripts/HuzzClient/Gameplay/"
local LIBRARY = Env.root .. "/huzz-valley/src/ReplicatedStorage/Shared/AnimationLibrary.lua"
local KNEES = { RightKnee = true, LeftKnee = true }
local ELBOWS = { RightElbow = true, LeftElbow = true }
local LIVE = { "RightHip", "LeftHip", "RightKnee", "LeftKnee", "RightElbow", "LeftElbow" }

local function signal()
	local fns = {}
	return { fns = fns, Connect = function(_, fn) table.insert(fns, fn); return { Disconnect = function() end } end }
end

local function scenario(name, opts)
	local clock, logs = 0, {}
	local RunService = { PreSimulation = signal(), Heartbeat = signal(), IsStudio = function() return true end,
		IsServer = function() return false end }
	-- the character: a fake R15 (or R6) body with Motor6Ds, a Humanoid, an Animator and Roblox's Animate
	local attrs, parts, motors = {}, {}, {}
	local character = { Name = "Me", Parent = "Workspace" }
	local function part(n, size)
		local p = { Name = n, Size = size, CFrame = CFrame.identity, kids = {}, Parent = character }
		function p.GetChildren() return p.kids end
		function p.FindFirstChild(_, k) for _, c in p.kids do if c.Name == k then return c end end return nil end
		function p.IsA(_, c) return c == "BasePart" end
		parts[n] = p
		return p
	end
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1))
	root.CFrame, root.Anchored, root.AssemblyLinearVelocity = CFrame.new(0, 3, 0), false, Vector3.zero
	for n, size in { LowerTorso = Vector3.new(2, 0.4, 1), UpperTorso = Vector3.new(2, 1.6, 1), Head = Vector3.new(1.2, 1.2, 1.2) } do part(n, size) end
	for _, s in { "Left", "Right" } do
		for _, n in { "UpperArm", "LowerArm", "UpperLeg", "LowerLeg" } do part(s .. n, Vector3.new(1, 1.2, 1)) end
		part(s .. "Hand", Vector3.new(1, 0.3, 1))
		part(s .. "Foot", Vector3.new(1, 0.3, 1))
	end
	local function joint(n, p0, p1, c0, c1)
		local j = { Name = n, Part0 = parts[p0], Part1 = parts[p1], C0 = c0, C1 = c1, Transform = CFrame.identity, Parent = parts[p1] }
		function j.IsA(_, cls) return cls == "Motor6D" end
		table.insert(parts[p1].kids, j)
		motors[n] = j
	end
	local v = CFrame.new
	joint("Root", "HumanoidRootPart", "LowerTorso", v(0, -0.2, 0), CFrame.identity)
	joint("Waist", "LowerTorso", "UpperTorso", v(0, 0.2, 0), v(0, -0.8, 0))
	joint("Neck", "UpperTorso", "Head", v(0, 0.8, 0), v(0, -0.6, 0))
	for _, s in { "Left", "Right" } do
		local x = if s == "Right" then 1 else -1
		joint(s .. "Shoulder", "UpperTorso", s .. "UpperArm", v(x, 0.55, 0), v(-x * 0.5, 0.4, 0))
		joint(s .. "Elbow", s .. "UpperArm", s .. "LowerArm", v(0, -0.5, 0), v(0, 0.5, 0))
		joint(s .. "Wrist", s .. "LowerArm", s .. "Hand", v(0, -0.55, 0), v(0, 0.15, 0))
		joint(s .. "Hip", "LowerTorso", s .. "UpperLeg", v(x * 0.5, -0.2, 0), v(0, 0.6, 0))
		joint(s .. "Knee", s .. "UpperLeg", s .. "LowerLeg", v(0, -0.6, 0), v(0, 0.6, 0))
		joint(s .. "Ankle", s .. "LowerLeg", s .. "Foot", v(0, -0.6, 0), v(0, 0.15, 0))
	end
	-- Roblox swapping in the avatar's own limbs after the body appears: new parts with new Motor6Ds for the hips,
	-- knees and elbows (the old joints are left behind and never move again)
	local function swapLimbs()
		for _, s in { "Left", "Right" } do
			for _, n in { "UpperLeg", "LowerLeg", "LowerArm" } do
				local old = parts[s .. n]
				for _, k in old.kids do k.Transform = CFrame.identity end
				old.Parent = nil
				part(s .. n, Vector3.new(1, 1.2, 1))
			end
			local x = if s == "Right" then 1 else -1
			joint(s .. "Elbow", s .. "UpperArm", s .. "LowerArm", v(0, -0.5, 0), v(0, 0.5, 0))
			joint(s .. "Wrist", s .. "LowerArm", s .. "Hand", v(0, -0.55, 0), v(0, 0.15, 0))
			joint(s .. "Hip", "LowerTorso", s .. "UpperLeg", v(x * 0.5, -0.2, 0), v(0, 0.6, 0))
			joint(s .. "Knee", s .. "UpperLeg", s .. "LowerLeg", v(0, -0.6, 0), v(0, 0.6, 0))
			joint(s .. "Ankle", s .. "LowerLeg", s .. "Foot", v(0, -0.6, 0), v(0, 0.15, 0))
		end
	end
	local animate = if opts.noAnimate then nil else { Name = "Animate", Disabled = false, IsA = function(_, c) return c == "LocalScript" end }
	local tracks = {}
	local animator = {
		LoadAnimation = function(_, a)
			if opts.loadThrows then error("LoadAnimation failed") end
			local t = { Animation = a, Priority = nil, Looped = true, Length = if opts.loads then 1.2 else 0, TimePosition = 0,
				WeightCurrent = 0, playing = false }
			function t.Play(self, _, w) self.playing = true; self.WeightCurrent = w or 1 end
			function t.Stop(self) self.playing = false; self.WeightCurrent = 0 end
			function t.AdjustWeight(self, w) self.WeightCurrent = w end
			function t.AdjustSpeed() end
			table.insert(tracks, t)
			return t
		end,
		GetPlayingAnimationTracks = function()
			local out = {}
			for _, t in tracks do if t.playing then table.insert(out, t) end end
			return out
		end,
	}
	local humanoid = {
		RigType = if opts.r6 then roblox.Enum.HumanoidRigType.R6 else roblox.Enum.HumanoidRigType.R15,
		HipHeight = 2, Sit = false, Health = 100,
		FindFirstChildOfClass = function(_, c) return if c == "Animator" then animator else nil end,
		WaitForChild = function(_, c) return if c == "Animator" then animator else nil end,
	}
	local stepping = false
	function humanoid.GetState()
		if opts.stepFails and stepping then error("blend broke") end
		return roblox.Enum.HumanoidStateType.Running
	end
	if opts.attachThrows then
		setmetatable(humanoid, { __index = function(_, k) if k == "RootPart" then error("no root for you") end return nil end })
	else
		humanoid.RootPart = root
	end
	function character.FindFirstChild(_, n) if n == "Animate" then return animate end return parts[n] end
	function character.WaitForChild(self, n) if n == "Humanoid" then return humanoid end return self:FindFirstChild(n) end
	function character.FindFirstChildOfClass(_, c) return if c == "Humanoid" then humanoid else nil end
	function character.GetAttribute(_, k) return attrs[k] end
	function character.SetAttribute(_, k, val) attrs[k] = val end

	local me = { Name = "Me", UserId = 1, Character = character, GetAttribute = function() return nil end,
		CharacterAdded = signal() }
	local Players = { LocalPlayer = me, PlayerRemoving = signal(), GetPlayers = function() return { me } end }
	local Workspace = { CurrentCamera = nil, GetServerTimeNow = function() return clock end,
		WaitForChild = function() return { GetChildren = function() return {} end } end }
	local KSP = { RegisterKeyframeSequence = function(_, seq)
		if opts.noRegister then error("RegisterKeyframeSequence refused") end
		return "rbxassetid://temp-" .. seq.Name
	end }
	local ReplicatedStorage = {
		WaitForChild = function(_, n) if n == "Shared" then return SharedNode end if n == "HuzzAnimations" then return raw end return nil end,
		FindFirstChild = function(_, n) if n == "HuzzGirlMoves" then return girlMoves end if n == "HuzzAnimations" then return raw end return nil end,
	}
	local mocks = { RunService = RunService, Players = Players, Workspace = Workspace, ReplicatedStorage = ReplicatedStorage,
		CollectionService = { GetTagged = function() return {} end }, KeyframeSequenceProvider = KSP,
		UserInputService = { MouseEnabled = false } }
	Env.game.GetService = function(self, n) return mocks[n] or realGet(self, n) end

	local function baseEnv()
		local env = {
			game = Env.game, typeof = typeof, task = { spawn = function(f, ...) f(...) end, defer = function() end,
				delay = function() end, wait = function() end },
			math = math, table = table, string = string, os = { clock = function() return clock end },
			warn = function(...) table.insert(logs, table.concat({ ... }, " ")) end,
			print = function(...) table.insert(logs, table.concat({ ... }, " ")) end,
			pcall = pcall, type = type, next = next, pairs = pairs, ipairs = ipairs, tostring = tostring,
			setmetatable = setmetatable, error = error, select = select,
			Instance = { new = function(c) return { ClassName = c } end },
		}
		for _, k in { "CFrame", "Vector3", "Vector2", "Color3", "Enum" } do env[k] = roblox[k] end
		return env
	end
	-- the library loaded fresh each time (it remembers its IDs)
	local library = nil
	local function loadLibrary()
		if library then return library end
		local env = baseEnv()
		env.script = SharedNode:WaitForChild("AnimationLibrary")
		env.require = function(x) return Env.load(x:GetFullName() .. ".lua") end
		library = luau.load(fs.readFile(LIBRARY), { debugName = "AnimationLibrary", environment = env })()
		return library
	end
	local loaded = {}
	local function loadGameplay(n)
		if loaded[n] then return loaded[n] end
		local parent = setmetatable({}, { __index = function(_, k) return { __gameplay = k } end })
		local env = baseEnv()
		env.script = { Parent = parent, Name = n }
		env.require = function(x)
			local g = type(x) == "table" and rawget(x, "__gameplay")
			if g then return loadGameplay(g) end
			local p = x:GetFullName()
			if string.match(p, "AnimationLibrary$") then return loadLibrary() end
			return Env.load(p .. ".lua")
		end
		loaded[n] = luau.load(fs.readFile(GAMEPLAY .. n .. ".lua"), { debugName = n, environment = env })()
		return loaded[n]
	end

	local AvatarAnimations = loadGameplay("AvatarAnimations")
	local PlayerMoves = loadGameplay("PlayerMoves")
	local Locomotion = loadGameplay("Locomotion")
	local okA, errA = pcall(AvatarAnimations.start)
	local okP, errP = pcall(PlayerMoves.start)
	check(okA and okP, name .. ": starts (" .. tostring(errA) .. ", " .. tostring(errP) .. ")")
	stepping = true

	-- the frames: the fake Animator first (the pack's tracks bend the knees, Roblox's Animate the elbows), then ours
	local errors, source = 0, {}
	local function frame()
		clock += 1 / 60
		for _, m in motors do m.Transform = CFrame.identity end
		if opts.moves ~= false then
			for _, t in tracks do
				if t.playing and t.Length > 0 and t.WeightCurrent > 0.5 then
					for k in KNEES do motors[k].Transform = CFrame.Angles(0.3, 0, 0) end
				end
			end
		end
		if animate and not animate.Disabled then
			for k in ELBOWS do motors[k].Transform = CFrame.Angles(0.25, 0, 0) end
		end
		for _, fn in RunService.PreSimulation.fns do
			local ok = pcall(fn, 1 / 60)
			if not ok then errors += 1 end
		end
	end
	for i = 1, 60 * 5 do
		if opts.swapAt == i then swapLimbs() end
		frame()
	end
	local moving = false
	for _, n in LIVE do
		local _, a = motors[n].Transform:ToAxisAngle()
		if math.abs(a) > math.rad(0.5) then moving = true end
	end
	local anims = {}
	for _, l in logs do if string.find(l, "[HuzzAnim]", 1, true) then table.insert(anims, l) end end
	return {
		moving = moving, drives = Locomotion.drives(character), handDrawn = PlayerMoves.drives(character),
		animateOn = animate ~= nil and not animate.Disabled, logs = anims, errors = errors,
	}
end

local cases = {
	{ "works", { loads = true } },
	{ "never loads", { loads = false } },
	{ "never moves", { loads = true, moves = false } },
	{ "no register", { loads = true, noRegister = true } },
	{ "load throws", { loads = true, loadThrows = true } },
	{ "step fails", { loads = true, stepFails = true } },
	{ "attach throws", { loads = true, attachThrows = true } },
	{ "no Animate", { loads = false, noAnimate = true } },
	{ "R6", { loads = true, r6 = true } },
	{ "limbs swapped", { loads = true, swapAt = 1 } },
}
print("What Output shows for your own moves, case by case:")
for _, c in cases do
	local name, opts = c[1], c[2]
	local r = scenario(name, opts)
	for i, l in r.logs do print(string.format("  %-13s %s", if i == 1 then name else "", l)) end
	check(r.moving, name .. ": the body moves after 5 s (never stiff)")
	-- (one line; a blend that breaks after the pack started says so on a second)
	check(#r.logs == (if name == "step fails" then 2 else 1), name .. ": one [HuzzAnim] line per change (" .. #r.logs .. ")")
	if name == "step fails" then
		check(string.find(r.logs[2] or "", "failed 30 frames", 1, true) ~= nil, "step fails: Output says the blend kept failing")
	end
	if name == "works" or name == "limbs swapped" then
		check(r.drives and not r.animateOn and not r.handDrawn, name .. ": the pack plays on your Animator, Roblox's Animate off")
		check(r.logs[1] and string.find(r.logs[1], "your moves", 1, true) ~= nil, name .. ": Output says the pack plays")
	elseif name == "R6" then
		check(not r.drives and r.animateOn and not r.handDrawn, "R6: Roblox's own walk, nothing drawn over it")
	else
		check(not r.drives and r.handDrawn, name .. ": Locomotion let go and PlayerMoves draws the pack by hand")
		check(r.animateOn or name == "no Animate", name .. ": Roblox's Animate is back on")
	end
end

print(string.format("AvatarAnims: %d ok, %d failed", passed, failed))
if failed > 0 then
	error("AvatarAnims spec failed")
end
