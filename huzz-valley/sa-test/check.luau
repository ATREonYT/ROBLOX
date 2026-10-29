-- Offline checks for the Server Authority test place (no Studio). Run from the repo root:
--   lune run huzz-valley/sa-test/check.luau
-- It runs HussSim's own step code with the game's real numbers: the huss and dive distances, the shared cooldown,
-- one press = one huss, the catch window, and that replaying the same buttons from a saved state gives the same
-- answer (what Roblox does when it corrects your screen). Then it checks the rules the docs say break silently.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Vector3, Vector2 = roblox.Vector3, roblox.Vector2

local function loadModule(path, env)
	return luau.load(fs.readFile(path), { debugName = path, environment = env })()
end
local R = { Vector3 = Vector3, Vector2 = Vector2, Color3 = roblox.Color3, CFrame = roblox.CFrame, Enum = roblox.Enum,
	UDim2 = roblox.UDim2, NumberRange = roblox.NumberRange, ColorSequence = roblox.ColorSequence }
local Round = loadModule("huzz-valley/src/ReplicatedStorage/Shared/Config/Round.lua", R)
local Run = loadModule("huzz-valley/src/ReplicatedStorage/Shared/Config/Run.lua", R)
local stubFolder = {
	WaitForChild = function(_, name)
		return if name == "Round" then Round elseif name == "Run" then Run else nil
	end,
}
local stubGame = {
	GetService = function(_, name)
		if name == "ReplicatedStorage" then
			return { WaitForChild = function() return stubFolder end }
		end
		return {}
	end,
}
local SRC = "huzz-valley/sa-test/src/HussSim.luau"
local Sim = loadModule(SRC, {
	game = stubGame, require = function(x) return x end, Vector3 = Vector3, Vector2 = Vector2, Enum = roblox.Enum,
})

local passed, failed = 0, 0
local function check(ok, what)
	if ok then passed += 1 else failed += 1; print("FAIL " .. what) end
end

local DT = 1 / 60
local LOOK = Vector3.new(0, 0, -1) -- the camera looks along -Z: right is +X
local function input(t)
	return { huss = t.huss or false, dive = t.dive or false, steer = t.steer or Vector2.zero, look = LOOK, speed = t.speed or 0 }
end
-- a body that goes exactly where the push says (the Humanoid holds still when nothing pushes)
local function travel(s, presses, seconds)
	local pos, vel = Vector3.zero, Vector3.zero
	for i = 1, math.floor(seconds / DT + 0.5) do
		Sim.ownerStep(s, input(presses(i) or {}), DT)
		local push = Sim.drive(s, vel)
		vel = push or Vector3.zero
		pos += vel * DT
	end
	return pos
end

-- the huss: ~12 studs to the side on your screen, none forward
local s = Sim.fresh()
local moved = travel(s, function(i) return if i == 1 then { huss = true, steer = Vector2.new(1, 0) } else nil end, 1)
check(math.abs(moved.X - 12) < 1.2 and math.abs(moved.Z) < 0.01, string.format("huss: 12 studs right (got %.2f, %.2f)", moved.X, moved.Z))
s = Sim.fresh()
moved = travel(s, function(i) return if i == 1 then { huss = true, steer = Vector2.new(-1, 0) } else nil end, 1)
check(moved.X < -10.8, "huss: A goes left")
moved = travel(s, function(i) return if i == 1 then { huss = true } else nil end, 1.5)
check(moved.Magnitude < 1e-6, "huss: the 2 s cooldown holds a second press")
moved = travel(s, function(i) return if i == 1 then { huss = true } else nil end, 1)
check(moved.X < -10.8, "huss: with no A or D it goes the side you went last")
s = Sim.fresh()
moved = travel(s, function() return { huss = true } end, 4)
check(math.abs(moved.X) < 13.5, "huss: holding Space is one huss, not one every 2 s")

-- the dive: forward, about 19 studs plus the belly slide, and an upward hop on its first step only
s = Sim.fresh()
moved = travel(s, function(i) return if i == 1 then { dive = true } else nil end, 1)
check(moved.Z < -19 and moved.Z > -25 and math.abs(moved.X) < 0.01, string.format("dive: ~19-23 studs forward (got %.2f)", -moved.Z))
s = Sim.fresh()
Sim.ownerStep(s, input({ dive = true }), DT)
local _, kick = Sim.drive(s, Vector3.zero)
Sim.ownerStep(s, input({ dive = true }), DT)
local _, kick2 = Sim.drive(s, Vector3.zero)
check(kick == Round.Lunge.Up and kick2 == nil, "dive: one hop at the start")

-- the catch
local d, v = Sim.fresh(), Sim.fresh()
d.DiveAge = 0.1
check(Sim.catches(d, Vector3.zero, v, Vector3.new(0, 0, -4)), "catch: in reach during the dive")
check(not Sim.catches(d, Vector3.zero, v, Vector3.new(0, 0, -6)), "catch: out of reach misses")
d.DiveAge = Round.Lunge.HitWindow + 0.01
check(not Sim.catches(d, Vector3.zero, v, Vector3.new(0, 0, -4)), "catch: after the hit window misses")
d.DiveAge, v.Down = 0.1, 1
check(not Sim.catches(d, Vector3.zero, v, Vector3.new(0, 0, -4)), "catch: someone already down can't be caught again")
local push, _, walk = Sim.drive(v, Vector3.new(20, 0, 0))
check(push == Vector3.zero and walk == 0, "caught: held still")
travel(v, function() return nil end, Sim.DOWN_TIME)
check(v.Down == 0, "caught: up again after DOWN_TIME")
s = Sim.fresh(); s.Down = 1
moved = travel(s, function(i) return if i == 1 then { huss = true } else nil end, 0.5)
check(moved.Magnitude < 1e-6, "caught: no huss while down")

-- the run build-up: 16 to the runner's 28 over 1 s of moving
check(Sim.walkSpeed(0) == Run.StartSpeed and Sim.walkSpeed(1) == Round.Speeds.Runner, "build-up: 16 to 28")
s = Sim.fresh()
for _ = 1, 30 do Sim.ownerStep(s, input({ speed = 10 }), DT) end
check(math.abs(s.Held - 0.5) < 1e-6, "build-up: counts while moving")
Sim.ownerStep(s, input({ speed = 0 }), DT)
check(s.Held == 0, "build-up: starts again after stopping")

-- a correction replays the same buttons from a saved state: the answer must be identical
local script = function(i)
	if i == 3 then return { huss = true, steer = Vector2.new(1, 0) } end
	if i == 150 then return { dive = true } end
	return { speed = 12 }
end
local a = Sim.fresh()
for i = 1, 100 do Sim.ownerStep(a, input(script(i) or {}), DT) end
local saved = table.clone(a)
for i = 101, 300 do Sim.ownerStep(a, input(script(i) or {}), DT) end
local b = saved
for i = 101, 300 do Sim.ownerStep(b, input(script(i) or {}), DT) end
local same = true
for k, x in a do if b[k] ~= x then same = false; print("  differs: " .. k) end end
check(same, "replay: same buttons from a saved state give the same state")

-- the rules that fail without an error (cakeman docs/reference/rules.md)
local src = fs.readFile(SRC)
local body = src:match("RunService:BindToSimulation%(function.-end, Enum%.StepFrequency%.Hz60%)")
check(body ~= nil, "the simulation runs at 60 a second (the default is 30)")
for _, banned in { "os%.clock", "tick%(", "os%.time", "math%.random", "Instance%.new", "task%.wait", ":Play%(", "CurrentCamera", "UserInputService" } do
	check(not src:find(banned), "nothing in the simulation uses " .. banned:gsub("%%", ""))
end
local count = 0
for k in Sim.START do
	count += 1
	check(#k <= 50, "attribute name short enough: " .. k)
end
check(count <= 64, "attributes within Roblox's first 64")
local server = fs.readFile("huzz-valley/sa-test/src/SATestServer.server.luau")
local client = fs.readFile("huzz-valley/sa-test/src/SATestClient.client.luau")
check(server:find("HussSim.Initialize%(%)") and client:find("HussSim.Initialize%(%)"), "the simulation starts on both the server and your screen")
check(server:find("ctx.Parent = player"), "the buttons live under the Player (or they never reach the server)")
for _, name in { "Steer", "Huss", "Dive", "CameraDir" } do
	check(server:find('"' .. name .. '"') and src:find('"' .. name .. '"'), "button named on both sides: " .. name)
end

-- the place file
local place = roblox.deserializePlace(fs.readFile("huzz-valley/places/ServerAuthorityTest.rbxl"))
local ws = place:GetService("Workspace")
check(ws.AuthorityMode == roblox.Enum.AuthorityMode.Server, "place: AuthorityMode Server")
check(ws.StreamingEnabled == true and ws.SignalBehavior == roblox.Enum.SignalBehavior.Deferred, "place: streaming on, deferred signals")
check(place:GetService("ReplicatedStorage"):FindFirstChild("HussSim") ~= nil, "place: HussSim in ReplicatedStorage")
check(place:GetService("StarterGui"):FindFirstChild("SATest") ~= nil, "place: the status line in StarterGui")

print(`SATest: {passed} ok, {failed} failed`)
if failed > 0 then error("SATest checks failed") end
