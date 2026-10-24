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
local r6Moves = nil -- ReplicatedStorage.HuzzR6Moves (his R6 pack), likewise
local SharedNode = Env.game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ReplicatedStorage = {
	WaitForChild = function(_, n) assert(n == "Shared"); return SharedNode end,
	FindFirstChild = function(_, n) if n == "HuzzGirlMoves" then return girlMoves end if n == "HuzzR6Moves" then return r6Moves end return nil end,
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
local function body(name, at, rigType, newer)
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
		local j = { Name = n, ClassName = "Motor6D", Part0 = parts[p0], Part1 = parts[p1], C0 = c0, C1 = c1, Transform = CFrame.identity, Parent = parts[p1] }
		function j.IsA(_, cls) return cls == "Motor6D" end
		if newer then -- Roblox's newer joints (his own avatar): an AnimationConstraint between two attachments
			j = { Name = n, ClassName = "AnimationConstraint", Attachment0 = { CFrame = c0, Parent = parts[p0] },
				Attachment1 = { CFrame = c1, Parent = parts[p1] }, Transform = CFrame.identity, Parent = parts[p1] }
			function j.IsA(_, cls) return cls == "AnimationConstraint" or cls == "Constraint" end
		end
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
		RigType = rigType or roblox.Enum.HumanoidRigType.R15, HipHeight = 2, Sit = false, Health = 100, MoveDirection = Vector3.zero,
		GetState = function() return roblox.Enum.HumanoidStateType.Running end,
		FindFirstChildOfClass = function(_, c) return if c == "Animator" then animator else nil end,
	}
	function character.FindFirstChild(_, n) return parts[n] end
	function character.GetDescendants()
		local all = {}
		for _, p in parts do
			table.insert(all, p)
			for _, k in p.kids do table.insert(all, k) end
		end
		return all
	end
	function character.FindFirstChildOfClass(_, c) return if c == "Humanoid" then humanoid else nil end
	function character.GetAttribute(_, k) return attrs[k] end
	function character.SetAttribute(_, k, val) attrs[k] = val end
	return { character = character, root = root, motors = motors, humanoid = humanoid }
end

local function noAttr() return nil end
local me = { Name = "Me", UserId = 1, GetAttribute = noAttr }
local other = { Name = "Other", UserId = 2, GetAttribute = noAttr }
local r6 = { Name = "Blocky", UserId = 3, GetAttribute = noAttr }
local newer = { Name = "Newer", UserId = 4, GetAttribute = noAttr }
Players.LocalPlayer = me
players = { me, other, r6, newer }
local mine, theirs, blocky = body("Me", Vector3.new(0, 3, 0)), body("Other", Vector3.new(10, 3, 0)), body("Blocky", Vector3.new(20, 3, 0), roblox.Enum.HumanoidRigType.R6)
me.Character, other.Character, r6.Character = mine.character, theirs.character, blocky.character
local fresh = body("Newer", Vector3.new(-10, 3, 0), nil, true)
newer.Character = fresh.character

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
theirs.root.AssemblyLinearVelocity = Vector3.new(0, 0, -20) -- (a replicated runner says it runs, between updates too)
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
-- (the pack's own hip pitch can sit near the dance's fixed 0.5 by chance with a random idle phase, so only check
-- the pack is moving the hip again: a dance still holding it would leave it frozen)
check(hip.Transform ~= mid, "after the dance the pack is back")
-- their head follows their mouse (owner, Oct 19 19:48): their screen sends the turn, the server puts it on their
-- character (HuzzLook, degrees), and here it springs to it (Gameplay/HeadAim, HuzzServer/HeadLookService)
do
	local neckM, waistM = theirs.motors.Neck, theirs.motors.Waist
	local function angle(a: CFrame, b: CFrame): number
		local _, t = (a:Inverse() * b):ToAxisAngle()
		return math.deg(math.abs(t))
	end
	frames(30)
	local neck0, waist0 = neckM.Transform, waistM.Transform
	theirs.character:SetAttribute("HuzzLook", roblox.Vector2.new(-50, 15))
	local biggest, last = 0, neckM.Transform
	frames(45, function()
		biggest = math.max(biggest, angle(last, neckM.Transform))
		last = neckM.Transform
	end)
	check(angle(neck0, neckM.Transform) > 12 and angle(waist0, waistM.Transform) > 15,
		string.format("their head and chest turn to where their mouse points (neck %.0f, chest %.0f degrees)",
			angle(neck0, neckM.Transform), angle(waist0, waistM.Transform)))
	check(biggest < 10, string.format("smoothly: at most %.1f degrees a frame at 60 fps", biggest))
	print(string.format("  another player's head from their mouse (-50, +15 sent): neck %.0f, chest %.0f degrees, at most %.1f a frame",
		angle(neck0, neckM.Transform), angle(waist0, waistM.Transform), biggest))
	theirs.character:SetAttribute("HuzzLook", nil)
	frames(60)
	check(angle(neck0, neckM.Transform) < 6, "and back when it goes")
	-- the same on an avatar with Roblox's newer joints (owner, Oct 21: "the body and the head move seperatley, the
	-- head from the mouse"): his avatar has no Motor6D, so this body was skipped and its head never turned
	local fNeck, fWaist = fresh.motors.Neck, fresh.motors.Waist
	local fNeck0, fWaist0 = fNeck.Transform, fWaist.Transform
	fresh.character:SetAttribute("HuzzLook", roblox.Vector2.new(-50, 15))
	frames(45)
	check(angle(fNeck0, fNeck.Transform) > 12 and angle(fWaist0, fWaist.Transform) > 15,
		string.format("newer joints: the head and chest turn to the mouse too (neck %.0f, chest %.0f degrees)",
			angle(fNeck0, fNeck.Transform), angle(fWaist0, fWaist.Transform)))
	fresh.character:SetAttribute("HuzzLook", nil)
	frames(60)
end
-- their halt (owner, Oct 20 07:55: "they move a little forward as a sort of \"hault\""): their key goes (MoveDirection
-- reaches every screen) while their body still slides from 28 to a stand (Shared/Halt): the feet plant and skid
-- instead of running on. The same slide with the key still held (a control) keeps stepping.
do
	local RunMotion = Env.load("huzz-valley/src/ReplicatedStorage/Shared/RunMotion.lua")
	local function slide(keyHeld, mode)
		local pos = theirs.root.CFrame
		theirs.humanoid.MoveDirection = Vector3.new(0, 0, -1)
		theirs.root.AssemblyLinearVelocity = Vector3.new(0, 0, -28)
		frames(60, function()
			pos = pos * CFrame.new(0, 0, -28 / 60)
			theirs.root.CFrame = pos
		end)
		if not keyHeld then theirs.humanoid.MoveDirection = Vector3.zero end
		if mode == "huss" then theirs.character:SetAttribute("DashAt", clock) end -- (a huss with no key held: a phone)
		local cfg, t, n, seen, travel, last = RunMotion.haltPush(28), 0, 0, false, 0, nil
		frames(24, function()
			t += 1 / 60
			local v = RunMotion.pushSpeed(cfg, t) or 0
			if mode then v = 28 end -- (the huss or the fall keeps it moving fast, no key held)
			local down = if mode == "fall" then -20 else 0
			theirs.root.AssemblyLinearVelocity = Vector3.new(0, down, -v)
			pos = pos * CFrame.new(0, down / 60, -v / 60)
			theirs.root.CFrame = pos
			seen = seen or PlayerMoves.halting(theirs.character)
			n += 1
			if n >= 6 and v > 0.05 then
				-- (from 0.1 s, while the ground still slides) the thigh's travel: running on swings it to and fro; the
				-- halt holds it in the braced stance
				local a = math.deg((hip.Transform:ToEulerAnglesXYZ()))
				if last then
					local d = a - last
					travel += math.abs(d)
				end
				last = a
			end
		end)
		theirs.humanoid.MoveDirection = Vector3.zero
		theirs.root.AssemblyLinearVelocity = Vector3.zero
		theirs.character:SetAttribute("DashAt", nil)
		if mode == "fall" then
			pos = pos * CFrame.new(0, 24 * 20 / 60, 0) -- (back up on the floor)
			theirs.root.CFrame = pos
		end
		frames(60)
		return travel, seen
	end
	local halted, seenHalt = slide(false)
	local held = slide(true)
	print(string.format("  another player's halt: their thigh travels %.0f degrees through the skid (key still held: %.0f)", halted, held))
	check(seenHalt, "their key goes while they still slide at a run: this screen shows their halt")
	check(halted < held * 0.5, "their halt: the feet plant and skid (the thigh travels far less than running on)")
	-- never a halt mid huss with no key held (a phone), nor falling (critic, Oct 20)
	local _, hussHalt = slide(false, "huss")
	local _, fallHalt = slide(false, "fall")
	check(not hussHalt, "a huss with no key held is no halt on other screens")
	check(not fallHalt, "nor is a fall (moving fast through the air with no key)")
end
-- An R6 body (the game is R6 since Oct 22) gets his R6 pack drawn by hand, and the game's huss pose on a huss
-- (Gameplay/R6Huss). His pack is paid and stays out of the public repo: without it, the R6 body is left alone.
do
	local raw = lib:FindFirstChild("HuzzAnimations")
	local okHuss, errH = pcall(loadGameplay("R6Huss").start)
	check(okHuss, "R6Huss starts: " .. tostring(errH))
	-- a real R6 body: Torso, Head, arms and legs, its joints in the Torso
	local attrs, parts, motors = {}, {}, {}
	local character = { Name = "Blocky6", Parent = "Workspace" }
	local function part(n, size)
		local p = { Name = n, Size = size, CFrame = CFrame.identity, kids = {}, Parent = character }
		function p.GetChildren() return p.kids end
		function p.FindFirstChild(_, k) for _, c in p.kids do if c.Name == k then return c end end return nil end
		function p.IsA(_, c) return c == "BasePart" end
		parts[n] = p
		return p
	end
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1))
	root.CFrame, root.Anchored, root.AssemblyLinearVelocity = CFrame.new(30, 3, 0), false, Vector3.zero
	part("Torso", Vector3.new(2, 2, 1)); part("Head", Vector3.new(2, 1, 1))
	for _, n in { "Right Arm", "Left Arm", "Right Leg", "Left Leg" } do part(n, Vector3.new(1, 2, 1)) end
	local function joint(n, p0, p1, c0, c1, home)
		local j = { Name = n, ClassName = "Motor6D", Part0 = parts[p0], Part1 = parts[p1], C0 = c0, C1 = c1, Transform = CFrame.identity, Parent = parts[home] }
		function j.IsA(_, cls) return cls == "Motor6D" end
		table.insert(parts[home].kids, j)
		motors[n] = j
	end
	local v = CFrame.new
	joint("RootJoint", "HumanoidRootPart", "Torso", CFrame.identity, CFrame.identity, "HumanoidRootPart")
	joint("Neck", "Torso", "Head", v(0, 1, 0), v(0, -0.5, 0), "Torso")
	joint("Right Shoulder", "Torso", "Right Arm", v(1, 0.5, 0), v(-0.5, 0.5, 0), "Torso")
	joint("Left Shoulder", "Torso", "Left Arm", v(-1, 0.5, 0), v(0.5, 0.5, 0), "Torso")
	joint("Right Hip", "Torso", "Right Leg", v(1, -1, 0), v(0.5, 1, 0), "Torso")
	joint("Left Hip", "Torso", "Left Leg", v(-1, -1, 0), v(-0.5, 1, 0), "Torso")
	local animator = { GetPlayingAnimationTracks = function() return {} end }
	local humanoid = {
		RigType = roblox.Enum.HumanoidRigType.R6, HipHeight = 0, Sit = false, Health = 100, MoveDirection = Vector3.zero,
		GetState = function() return roblox.Enum.HumanoidStateType.Running end,
		FindFirstChildOfClass = function(_, c) return if c == "Animator" then animator else nil end,
	}
	function character.FindFirstChild(_, n) return parts[n] end
	function character.GetDescendants()
		local all = {}
		for _, p in parts do
			table.insert(all, p)
			for _, k in p.kids do table.insert(all, k) end
		end
		return all
	end
	function character.FindFirstChildOfClass(_, c) return if c == "Humanoid" then humanoid else nil end
	function character.GetAttribute(_, k) return attrs[k] end
	function character.SetAttribute(_, k, val) attrs[k] = val end
	r6.Character = character
	local rhip = motors["Right Hip"]
	if raw:FindFirstChild("R6Walk") then
		local f = roblox.Instance.new("Folder")
		for _, n in { "R6Idle", "R6Walk", "R6Run", "R6DashLeft", "R6DashRight" } do raw:FindFirstChild(n):Clone().Parent = f end
		r6Moves = f
		clock += 3
		frames(20)
		check(PlayerMoves.drives(character), "an R6 body is drawn with his R6 pack")
		local pos = root.CFrame
		root.AssemblyLinearVelocity = Vector3.new(0, 0, -22)
		frames(90, function()
			pos = pos * CFrame.new(0, 0, -22 / 60)
			root.CFrame = pos
		end)
		-- (R6 hips swing about their own frame's axis: the angle's travel through the run counts)
		local travel = 0
		local prev = nil
		frames(40, function()
			pos = pos * CFrame.new(0, 0, -22 / 60)
			root.CFrame = pos
			local _, a = rhip.Transform:ToAxisAngle()
			if prev then travel += math.abs(a - prev) end
			prev = a
		end)
		check(math.deg(travel) > 60, string.format("running, the R6 leg swings through his run (%.0f degrees of travel)", math.deg(travel)))
		-- a huss to the right: the huss pose goes over the run, then the run is back
		local runPose = rhip.Transform
		attrs.DashAt, attrs.DashDir = clock, Vector3.new(1, 0, 0)
		frames(12, function() pos = pos * CFrame.new(0, 0, -22 / 60); root.CFrame = pos end)
		local shown = rhip.Transform
		attrs.DashAt = nil
		local _, a1 = shown:ToAxisAngle()
		check(shown ~= runPose, string.format("a huss poses the R6 body (Shared/R6HussPose; hip at %.0f degrees)", math.deg(a1)))
	else
		frames(10)
		check(not PlayerMoves.drives(character), "R6 (his pack not here): left to Roblox's own R6 walk")
	end
	r6.Character = nil
end

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
