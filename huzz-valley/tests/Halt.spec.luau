-- lune run tests/Halt.spec.luau
-- Gameplay/Sprint and Shared/Halt, the real files, on a fake body with Roblox-like ground physics (owner, Oct 20 07:55:
-- "Make acceleration 1 second long and after they randomly stop after fully running they move a little forward as a
-- sort of "hault" like in the game Huss valley"): holding W builds from 16 to the top in 1 s; letting go from a full
-- run carries the body on ~2.3 studs over ~0.25 s with HuzzHalt set (the legs plant); a lobby tap, a short dash, a
-- jump-off or a body in the air never halts; a new key, a huss, being frozen or downed ends it at once; turning round
-- is never a halt; the push is gone afterwards. Walls and the server's view are Roblox physics: Studio only.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Vector3, Vector2 = roblox.Vector3, roblox.Vector2
local Env = require("../tools/preview/motion3d/env")

local failed, passed = 0, 0
local function check(ok, what)
	if ok then passed += 1 else failed += 1; print("FAIL " .. what) end
end

-- Fake services and a fake clock.
local clock = 0
local function signal()
	local fns = {}
	return { fns = fns, Connect = function(_, fn)
		table.insert(fns, fn)
		local c = { Connected = true }
		function c.Disconnect() c.Connected = false; table.remove(fns, table.find(fns, fn) or 0) end
		return c
	end }
end
local RunService = { Heartbeat = signal() }
local mocks = { RunService = RunService }
local realGet = Env.game.GetService
Env.game.GetService = function(self, name) return mocks[name] or realGet(self, name) end

-- Fake instances: just enough for Shared/Halt's Attachment + LinearVelocity.
local function newInstance(class)
	local inst = { ClassName = class, Children = {}, destroyed = false }
	return setmetatable(inst, {
		__index = function(t, k)
			if k == "Destroy" then
				return function(self)
					self.destroyed = true
					rawset(self, "ParentRef", nil)
				end
			end
			if k == "Parent" then return rawget(t, "ParentRef") end
			return nil
		end,
		__newindex = function(t, k, v)
			if k == "Parent" then rawset(t, "ParentRef", v); if v and v.Children then table.insert(v.Children, t) end; return end
			rawset(t, k, v)
		end,
	})
end
local Instance = { new = newInstance }

-- The body: a root with children (the halt's Attachment), a Humanoid, a character with attributes.
local attrs, hattrs = {}, {}
local root = { Children = {}, Position = Vector3.new(0, 3, 0), AssemblyLinearVelocity = Vector3.zero, Anchored = false, Parent = true }
function root.FindFirstChild(self, name)
	for _, c in self.Children do
		if not c.destroyed and c.Name == name and c.Parent == self then return c end
	end
	return nil
end
local humanoid = {
	WalkSpeed = 16, MoveDirection = Vector3.zero, FloorMaterial = roblox.Enum.Material.Plastic, Sit = false,
	PlatformStand = false, RootPart = root, Parent = true,
}
function humanoid.GetAttribute(_, k) return hattrs[k] end
local character = { Parent = true }
function character.FindFirstChildOfClass(_, c) return if c == "Humanoid" then humanoid else nil end
function character.GetAttribute(_, k) return attrs[k] end
function character.SetAttribute(_, k, v) attrs[k] = v end
local player = { Character = character, CharacterAdded = signal() }
function player.SetAttribute() end
local Players = { LocalPlayer = player }
mocks.Players = Players
local SharedNode = Env.game:GetService("ReplicatedStorage"):WaitForChild("Shared")
mocks.ReplicatedStorage = { WaitForChild = function(_, n) assert(n == "Shared"); return SharedNode end }

-- Shared modules: Halt with the fake Instance and clock, the rest as they are.
local function loadWith(path)
	local env = {
		script = { Parent = SharedNode }, game = Env.game, typeof = typeof, math = math, table = table, string = string,
		pcall = pcall, type = type, os = { clock = function() return clock end }, Instance = Instance,
		require = function(x) return Env.load(x:GetFullName() .. ".lua") end,
	}
	for _, k in { "CFrame", "Vector3", "Vector2", "Enum" } do env[k] = roblox[k] end
	return luau.load(fs.readFile(path), { debugName = path, environment = env })()
end
local Halt = loadWith(Env.root .. "/huzz-valley/src/ReplicatedStorage/Shared/Halt.lua")
local RunMotion = Env.load("huzz-valley/src/ReplicatedStorage/Shared/RunMotion.lua")
local Run = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/Run.lua")
local Round = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/Round.lua")

local env = {
	game = Env.game, typeof = typeof, math = math, table = table, string = string, pcall = pcall, type = type,
	os = { clock = function() return clock end }, print = print,
	require = function(x)
		local p = x:GetFullName()
		if string.match(p, "/Shared/Halt$") then return Halt end
		return Env.load(p .. ".lua")
	end,
}
for _, k in { "CFrame", "Vector3", "Vector2", "Enum" } do env[k] = roblox[k] end
local Sprint = luau.load(fs.readFile(Env.root .. "/huzz-valley/src/StarterPlayer/StarterPlayerScripts/HuzzClient/Gameplay/Sprint.lua"),
	{ debugName = "Sprint", environment = env })()
Sprint.start()

-- One 60 fps frame: Roblox's ground physics (a Humanoid on the floor moves at once at MoveDirection x WalkSpeed and
-- stops at once without a key; a LinearVelocity in the plane wins over it), then Heartbeat.
local DT = 1 / 60
local function haltPush()
	local a = root:FindFirstChild(Halt.NAME)
	if not a then return nil end
	for _, c in a.Children do
		if c.ClassName == "LinearVelocity" and not c.destroyed then return c end
	end
	return nil
end
local errors = 0
local shove: Vector3? = nil -- (one frame moved by something else: a huss's tail, a dive, a shove)
local function frame(move: Vector3?)
	clock += DT
	if move then humanoid.MoveDirection = move end
	local lv = haltPush()
	local v
	if shove then
		v, shove = shove, nil
	elseif lv and lv.PlaneVelocity then
		v = Vector3.new(lv.PlaneVelocity.X, 0, lv.PlaneVelocity.Y)
	else
		v = humanoid.MoveDirection * humanoid.WalkSpeed
	end
	root.AssemblyLinearVelocity = v
	root.Position += v * DT
	for _, fn in table.clone(RunService.Heartbeat.fns) do
		local ok, e = pcall(fn, DT)
		if not ok then errors += 1; if errors < 4 then print("frame error: " .. tostring(e)) end end
	end
end
local function frames(n, move)
	for _ = 1, n do frame(move) end
end
local W, S, D, NONE = Vector3.new(0, 0, -1), Vector3.new(0, 0, 1), Vector3.new(1, 0, 0), Vector3.zero

-- standing still first (the spawn's feet-first hold lets go on the floor)
hattrs.HuzzSpeed = Round.Speeds.Runner
frames(30, NONE)

-- 1. the build-up: from 16 to 28 in 1 s, 75% of the way at 0.5 s
local at = {}
for i = 1, 72 do
	frame(W)
	at[i] = humanoid.WalkSpeed
end
print(string.format("  build-up: %.1f at 0.1 s, %.1f at 0.5 s, %.1f at 0.75 s, %.1f at 1.0 s, %.1f at 1.2 s", at[6], at[30], at[45], at[60], at[72]))
check(at[1] < 17 and math.abs(at[30] - 25) < 0.6 and at[60] > 27.9 and at[72] > 27.99, "W: 16 at once, ~25 at 0.5 s, 28 at 1 s (the owner's 1 second)")

-- 2. let go from a full run: the halt
local from = root.Position
frame(NONE)
check(attrs.HuzzHalt == true and haltPush() ~= nil, "letting go at full speed starts the halt (HuzzHalt on, the push on the body)")
local endedAt = nil
for i = 1, 40 do
	frame(NONE)
	if not endedAt and attrs.HuzzHalt == nil then endedAt = (i + 1) * DT end
end
local slid = (root.Position - from).Magnitude
print(string.format("  halt from 28: %.2f studs, over %.2f s", slid, endedAt or -1))
check(slid >= 1.5 and slid <= 2.8, string.format("the body carries on ~2 to 2.5 studs (%.2f)", slid))
check(endedAt and endedAt >= 0.22 and endedAt <= 0.3, string.format("over ~0.25 s (%.2f)", endedAt or -1))
check(haltPush() == nil and root.AssemblyLinearVelocity.Magnitude < 1e-6, "then the push is gone and the body stands")

-- 3. a lobby tap never halts
hattrs.HuzzSpeed = Round.Speeds.Lobby
frames(20, NONE)
frames(12, W)
from = root.Position
frame(NONE)
check(attrs.HuzzHalt == nil and haltPush() == nil, "a 0.2 s tap in the lobby: no halt")
frames(10, NONE)
check((root.Position - from).Magnitude < 1e-6, "it just stops")

-- 4. a short dash in a round never halts
hattrs.HuzzSpeed = Round.Speeds.Runner
frames(20, NONE)
frames(18, W)
frame(NONE)
check(attrs.HuzzHalt == nil, "a 0.3 s dash in a round: no halt (not at full speed yet)")
frames(20, NONE)

-- a full run, then let go, then something ends the halt
local function haltThen(what, each)
	frames(20, NONE)
	frames(70, W)
	frame(NONE)
	local started = attrs.HuzzHalt == true
	local f = 0
	repeat
		f += 1
		each(f)
		frame(nil)
	until attrs.HuzzHalt == nil or f > 30
	return started, f
end

-- 5. a new key ends it at once
local started, f = haltThen("key", function(k) if k == 3 then humanoid.MoveDirection = D end end)
check(started and f == 3 and haltPush() == nil, string.format("pressing D mid-halt ends it that frame (%d)", f))
frame(nil) -- (the push set on the last frame still moves this one: one frame, as in Roblox)
local v = root.AssemblyLinearVelocity
check(v.X > 1 and math.abs(v.Z) < 1e-6, "and from the next frame you run the new way")
humanoid.MoveDirection = NONE
-- 6. frozen (HuzzSpeed 0: a Hero run, the line-up) ends it
started, f = haltThen("frozen", function(k) if k == 2 then hattrs.HuzzSpeed = 0 end end)
check(started and f == 2, string.format("frozen mid-halt: it ends (%d)", f))
hattrs.HuzzSpeed = Round.Speeds.Runner
frames(5, NONE)
-- 7. downed ends it
started, f = haltThen("downed", function(k) if k == 2 then attrs.DownedAt = clock end end)
check(started and f == 2, string.format("downed mid-halt: it ends (%d)", f))
attrs.DownedAt = nil
-- 8. a huss ends it (Gameplay/Dash's push takes over)
local dash = newInstance("Attachment")
dash.Name = "HuzzDash"
started, f = haltThen("huss", function(k) if k == 2 then dash.Parent = root end end)
check(started and f == 2, string.format("a huss mid-halt: it ends (%d)", f))
dash:Destroy()
-- 9. leaving the floor ends it, and a let-go in the air is no halt
started, f = haltThen("air", function(k) if k == 2 then humanoid.FloorMaterial = roblox.Enum.Material.Air end end)
check(started and f == 2, string.format("off the floor mid-halt: it ends (%d)", f))
frames(20, W)
frame(NONE)
check(attrs.HuzzHalt == nil, "letting go in the air: no halt")
humanoid.FloorMaterial = roblox.Enum.Material.Plastic
-- 11. let go right after something shoved you faster than you run (a huss's tail, a dive, a push): the slide
-- starts from your top speed, never the shove's (critic, Oct 20: it slid 5 to 7 studs)
frames(20, NONE)
frames(70, W)
shove = Vector3.new(0, 0, -60)
frame(W)
from = root.Position
frames(30, NONE)
local shoved = (root.Position - from).Magnitude
print(string.format("  halt right after a 60 studs/s shove: %.2f studs", shoved))
check(shoved <= 2.8, string.format("a halt after a shove slides no further than from your top speed (%.2f)", shoved))
-- 10. turning round (W, one empty frame, S): the halt is over the frame S comes, the body goes back the other way
frames(20, NONE)
frames(70, W)
from = root.Position
frame(NONE)
frames(10, S)
check(attrs.HuzzHalt == nil and haltPush() == nil and root.AssemblyLinearVelocity.Z > 1, "turning round: S takes over at once, no halt left")
check((root.Position - from).Z > -1, "and at most one frame of carry the old way")
check(errors == 0, "no frame step failed")

print(`Halt: {passed} ok, {failed} failed`)
if failed > 0 then
	error("Halt spec failed")
end
