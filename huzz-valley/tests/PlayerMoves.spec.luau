-- lune run tests/PlayerMoves.spec.luau
-- Gameplay/PlayerMoves and Gameplay/RunAnimator, the real files, on fake players (Lune can't hold a Motor6D's
-- Transform, so the bodies are plain tables shaped like Roblox's): the pack is played by hand on another player's
-- R15 body and on yours (Locomotion isn't playing it here), their thigh swings through a stride as their body moves
-- with bursty network positions, RunAnimator then draws only the huss on them (a huss still poses the body), a
-- dance fades the pack out and hands the joints back, an R6 body is left alone, a body that leaves is dropped, and
-- nothing runs before the pack's folder exists.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Env = require("../tools/preview/motion3d/env")

local failed, passed = 0, 0
local function check(ok, what)
	if ok then passed += 1 else failed += 1; print("FAIL " .. what) end
end

-- Fake services.
local clock = 0
local function signal()
	local fns = {}
	return { fns = fns, Connect = function(_, fn) table.insert(fns, fn); return { Disconnect = function() end } end }
end
local RunService = { PreSimulation = signal(), Heartbeat = signal(), IsStudio = function() return false end }
local players = {}
local Players = { LocalPlayer = nil, PlayerRemoving = signal(), GetPlayers = function() return players end }
local carried = { GetChildren = function() return {} end }
local Workspace = {
	CurrentCamera = nil,
	GetServerTimeNow = function() return clock end,
	WaitForChild = function(_, n) assert(n == "HuzzCarried"); return carried end,
}
local CollectionService = { GetTagged = function() return {} end }
local lib = roblox.Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile(Env.root .. "/huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do inst.Parent = lib end
local girlMoves = nil -- ReplicatedStorage.HuzzGirlMoves, once "Bootstrap" has made it
local SharedNode = Env.game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ReplicatedStorage = {
	WaitForChild = function(_, n) assert(n == "Shared"); return SharedNode end,
	FindFirstChild = function(_, n) if n == "HuzzGirlMoves" then return girlMoves end return nil end,
}
local mocks = { RunService = RunService, Players = Players, Workspace = Workspace, CollectionService = CollectionService, ReplicatedStorage = ReplicatedStorage }
local realGet = Env.game.GetService
Env.game.GetService = function(self, name) return mocks[name] or realGet(self, name) end

-- The Gameplay files, loaded with these services (os.clock = the fake clock).
local GAMEPLAY = Env.root .. "/huzz-valley/src/StarterPlayer/StarterPlayerScripts/HuzzClient/Gameplay/"
local loaded = {}
local function loadGameplay(name)
	if loaded[name] then return loaded[name] end
	local parent = setmetatable({}, { __index = function(_, k) return { __gameplay = k } end })
	local env = {
		script = { Parent = parent, Name = name }, game = Env.game, typeof = typeof, task = { spawn = function(f, ...) f(...) end, defer = function() end },
		math = math, table = table, string = string, os = { clock = function() return clock end }, warn = function(...) print("[warn]", ...) end,
		pcall = pcall, type = type, next = next, pairs = pairs, ipairs = ipairs, tostring = tostring, setmetatable = setmetatable, error = error, print = print,
	}
	for _, k in { "CFrame", "Vector3", "Vector2", "Color3", "Enum" } do env[k] = roblox[k] end
	env.require = function(x)
		local g = type(x) == "table" and rawget(x, "__gameplay")
		if g then return loadGameplay(g) end
		local p = x:GetFullName()
		return Env.load(p .. ".lua")
	end
	local m = luau.load(fs.readFile(GAMEPLAY .. name .. ".lua"), { debugName = name, environment = env })()
	loaded[name] = m
	return m
end

-- A fake R15 body (the preview rig's joints), plain tables: parts, Motor6Ds with Transform, a Humanoid.
local function body(name, at, rigType)
	local attrs = {}
	local character = { Name = name, Parent = "Workspace" }
	local parts = {}
	local function part(n, size)
		local p = { Name = n, Size = size, CFrame = CFrame.identity, kids = {}, Parent = character }
		function p.GetChildren() return p.kids end
		function p.FindFirstChild(_, k) for _, c in p.kids do if c.Name == k then return c end end return nil end
		parts[n] = p
		return p
	end
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1))
	root.CFrame, root.Anchored, root.AssemblyLinearVelocity = CFrame.new(at), false, Vector3.zero
	for n, size in { LowerTorso = Vector3.new(2, 0.4, 1), UpperTorso = Vector3.new(2, 1.6, 1), Head = Vector3.new(1.2, 1.2, 1.2) } do part(n, size) end
	for _, s in { "Left", "Right" } do
		for _, n in { "UpperArm", "LowerArm", "UpperLeg", "LowerLeg" } do part(s .. n, Vector3.new(1, 1.2, 1)) end
		part(s .. "Hand", Vector3.new(1, 0.3, 1))
		part(s .. "Foot", Vector3.new(1, 0.3, 1))
	end
	local motors = {}
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
	local animator = { GetPlayingAnimationTracks = function() return {} end }
	local humanoid = {
		RigType = rigType or roblox.Enum.HumanoidRigType.R15, HipHeight = 2, Sit = false, Health = 100,
		GetState = function() return roblox.Enum.HumanoidStateType.Running end,
		FindFirstChildOfClass = function(_, c) return if c == "Animator" then animator else nil end,
	}
	function character.FindFirstChild(_, n) return parts[n] end
	function character.FindFirstChildOfClass(_, c) return if c == "Humanoid" then humanoid else nil end
	function character.GetAttribute(_, k) return attrs[k] end
	function character.SetAttribute(_, k, val) attrs[k] = val end
	return { character = character, root = root, motors = motors, humanoid = humanoid }
end

local me = { Name = "Me", UserId = 1 }
local other = { Name = "Other", UserId = 2 }
local r6 = { Name = "Blocky", UserId = 3 }
Players.LocalPlayer = me
players = { me, other, r6 }
local mine, theirs, blocky = body("Me", Vector3.new(0, 3, 0)), body("Other", Vector3.new(10, 3, 0)), body("Blocky", Vector3.new(20, 3, 0), roblox.Enum.HumanoidRigType.R6)
me.Character, other.Character, r6.Character = mine.character, theirs.character, blocky.character

local PlayerMoves = loadGameplay("PlayerMoves")
local okStart, err = pcall(PlayerMoves.start)
check(okStart, "PlayerMoves starts: " .. tostring(err))
local okRun, err2 = pcall(loadGameplay("RunAnimator").start)
check(okRun, "RunAnimator starts: " .. tostring(err2))

local errors = 0
local function frames(n, each)
	for _ = 1, n do
		clock += 1 / 60
		if each then each() end
		for _, fn in RunService.PreSimulation.fns do
			local ok, e = pcall(fn, 1 / 60)
			if not ok then errors += 1; if errors < 4 then print("frame error: " .. tostring(e)) end end
		end
	end
end
local hip = theirs.motors.RightHip
frames(10)
check(not PlayerMoves.drives(theirs.character) and hip.Transform == CFrame.identity, "before the pack's folder arrives nothing is drawn by hand")
local folder = roblox.Instance.new("Folder")
for _, n in { "Idle", "Walk", "Run" } do lib:FindFirstChild("HuzzAnimations"):FindFirstChild(n):Clone().Parent = folder end
girlMoves = folder
clock += 3 -- (GirlMoves.find asks again every 2 s)
frames(30)
check(PlayerMoves.drives(theirs.character), "the other player is drawn by PlayerMoves")
check(PlayerMoves.drives(mine.character), "so is yours (Locomotion isn't playing the pack here)")
check(not PlayerMoves.drives(blocky.character), "an R6 body is left alone")
check(hip.Transform ~= CFrame.identity, "the idle poses their hips")

-- running at ~20 studs/s with bursty network updates: their thigh swings through whole strides
local seen, shown, hold, k = {}, theirs.root.CFrame, 0, 0
local truePos = theirs.root.CFrame
frames(90, function()
	k += 1
	truePos = truePos * CFrame.new(0, 0, -20 / 60)
	if hold > 0 then hold -= 1 else shown = truePos; hold = k % 3 end
	theirs.root.CFrame = shown
	table.insert(seen, (hip.Transform:ToEulerAnglesXYZ()))
end)
local lo, hi = math.huge, -math.huge
for i = 45, #seen do lo, hi = math.min(lo, seen[i]), math.max(hi, seen[i]) end
check(math.deg(hi - lo) > 60, string.format("running, their thigh swings through a stride (%.0f to %.0f degrees)", math.deg(lo), math.deg(hi)))
-- a huss: RunAnimator's pose goes over the pack (the waist leans into it), then the pack is back
local waist = theirs.motors.Waist
local before = waist.Transform
theirs.character:SetAttribute("DashAt", clock)
theirs.character:SetAttribute("DashDir", Vector3.new(1, 0, 0))
frames(10, function() theirs.root.CFrame = theirs.root.CFrame * CFrame.new(0, 0, -20 / 60) end)
local _, _, roll = waist.Transform:ToEulerAnglesXYZ()
check(math.abs(math.deg(roll)) > 5, string.format("a huss still leans their body over the pack (waist roll %.0f degrees)", math.deg(roll)))
theirs.character:SetAttribute("DashAt", nil)
frames(30)
check(waist.Transform ~= before, "and the pack walks on after it")
-- a dance: the pack fades out and the dance's own pose shows
theirs.character:SetAttribute("HuzzDance", "Test")
frames(30, function() hip.Transform = CFrame.Angles(0.5, 0, 0) end) -- (the dance, as their Animator would write it)
check(math.abs(hip.Transform:ToEulerAnglesXYZ() - 0.5) < 1e-3, "dancing: the pack lets the dance show")
theirs.character:SetAttribute("HuzzDance", nil)
frames(20)
local mid = hip.Transform
frames(10)
-- (the pack's own hip pitch can sit near the dance's 0.5 by chance with a random idle phase, so check the pack is
-- moving the hip again rather than comparing to 0.5)
check(hip.Transform ~= mid and math.abs(hip.Transform:ToEulerAnglesXYZ() - 0.5) > 1e-3, "after the dance the pack is back")
-- leaving: dropped
theirs.character.Parent = nil
other.Character = nil
frames(3)
check(not PlayerMoves.drives(theirs.character), "a body that left is dropped")
check(errors == 0, "no frame step failed")

print(`PlayerMoves: {passed} ok, {failed} failed`)
if failed > 0 then
	error("PlayerMoves spec failed")
end
