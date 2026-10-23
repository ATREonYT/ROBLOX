-- lune run tests/MotionStamps.spec.luau   (from huzz-valley/)
-- Shared/MotionStamps and HuzzServer/MotionRelay.check (owner, Oct 23 08:36: "make the desync the most precise it can
-- be"): a stamp moved on by the time since it was taken (standing, running on, a turn eased in like a Humanoid, a
-- push carried only PushFor, never past MaxAge), the drawn offset capped (flat, MaxStuds, a teleport: none), a broken
-- stamp refused, and the server's check (where it says near its own copy, no faster than the body's WalkSpeed or a
-- dive, taken within the last second, the body alive and free).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3

local ROOT = if fs.isDir("huzz-valley") then "huzz-valley/" else ""
local MS = luau.load(fs.readFile(ROOT .. "src/ReplicatedStorage/Shared/MotionStamps.lua"), { debugName = "MotionStamps", environment = { Vector3 = Vector3 } })()
local C = MS.Config
local fakeRS = { WaitForChild = function() return { MotionStamps = MS } end }
local Relay = luau.load(fs.readFile(ROOT .. "src/ServerScriptService/HuzzServer/MotionRelay.lua"), { debugName = "MotionRelay",
	environment = { Vector3 = Vector3, game = { GetService = function() return fakeRS end }, require = function(x) return x end } })()

local passed, failed = 0, 0
local function check(name, cond)
	if cond then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local function near(a, b, eps) return (a - b).Magnitude < (eps or 0.01) end
local Z = Vector3.zero
local function st(p, v, g, push) return MS.read(100, p, v, g, push) end

-- predict
local still = st(Vector3.new(1, 3, 2), Z, Z)
check("standing still stays put", near(MS.predict(still, 0.3), Vector3.new(1, 3, 2)))
local run = st(Z, Vector3.new(24, 0, 0), Vector3.new(24, 0, 0))
check("running on: speed x time", near(MS.predict(run, 0.2), Vector3.new(4.8, 0, 0)))
check("never further than MaxAge", near(MS.predict(run, 5), Vector3.new(24 * C.MaxAge, 0, 0)))
check("a time before the stamp counts as none", near(MS.predict(run, -1), Z))
local turn = st(Z, Vector3.new(24, 0, 0), Vector3.new(0, 0, -24))
local a = MS.predict(turn, 0.3)
local k = C.K
local carry = 24 * (1 - math.exp(-k * 0.3)) / k
check(string.format("a turn: carried on %.2f the old way, then the new way", a.X), math.abs(a.X - carry) < 1e-3 and a.Z < -4)
check("a turn eases in (a Humanoid isn't instant)", a.X > 1 and a.X < 24 * 0.3)
local stop = st(Z, Vector3.new(24, 0, 0), Z)
check("letting go: slows to a stop within a couple of studs", MS.predict(stop, 0.6).X < 2.1 and MS.predict(stop, 0.6).X > 1.5)
local push = st(Z, Vector3.new(60, 0, 0), Vector3.new(24, 0, 0), true)
check("a push keeps its speed only PushFor", near(MS.predict(push, 0.3), Vector3.new(60 * C.PushFor + 24 * (0.3 - C.PushFor), 0, 0)))
check("up and down: the stamp's height", MS.predict(st(Vector3.new(0, 7, 0), Vector3.new(0, 50, 0), Vector3.new(0, 9, 0)), 0.2).Y == 7)

local pull = st(Z, Vector3.new(23, 0, 0), Vector3.new(-16, 0, 0), C.PullFor)
check("a lasso's pull isn't steered by the keys for PullFor", near(MS.predict(pull, 0.25), Vector3.new(23 * 0.25, 0, 0)))

-- limit
check("a huss gets more room (cap grows with speed, up to PushStuds)", MS.cap(120) == C.PushStuds and MS.cap(24) == C.MaxStuds
	and math.abs(MS.limit(Vector3.new(24, 0, 0), 120).Magnitude - 24) < 1e-6)
check("a huss's gap isn't taken for a teleport", MS.limit(Vector3.new(20, 0, 0), 120) ~= Z)
check("the offset is flat", near(MS.limit(Vector3.new(3, 9, 0)), Vector3.new(3, 0, 0)))
check("capped at MaxStuds", math.abs(MS.limit(Vector3.new(0, 0, 12)).Magnitude - C.MaxStuds) < 1e-6)
check("a teleport: none", MS.limit(Vector3.new(100, 0, 0)) == Z)
check("not a number: none", MS.limit(Vector3.new(0 / 0, 0, 0)) == Z)

-- read
check("a good stamp reads", MS.read(1, Z, Z, Z, nil) ~= nil and MS.read(1, Z, Z, Z, nil).push == 0)
check("a broken time is refused", MS.read(0 / 0, Z, Z, Z) == nil and MS.read("1", Z, Z, Z) == nil)
check("a broken vector is refused", MS.read(1, Vector3.new(0 / 0, 0, 0), Z, Z) == nil and MS.read(1, Z, 5, Z) == nil)
check("push is a hold time: true = PushFor, never past PullFor, junk = 0", MS.read(1, Z, Z, Z, "yes").push == 0
	and MS.read(1, Z, Z, Z, true).push == C.PushFor and MS.read(1, Z, Z, Z, 9).push == C.PullFor and MS.read(1, Z, Z, Z, 0 / 0).push == 0)

-- MotionRelay.check (the server's own copy of the body)
local root = { Position = Vector3.new(0, 3, 0), Anchored = false, AssemblyLinearVelocity = Vector3.new(24, 0, 0) }
local hum = { Health = 100, WalkSpeed = 24 }
local function good(over)
	local s = MS.read(100, Vector3.new(2.4, 3, 0), Vector3.new(24, 0, 0), Vector3.new(24, 0, 0), false)
	for key, val in over or {} do s[key] = val end
	return s
end
check("an honest stamp passes", Relay.check(good(), root, hum, 100.05, 0.1))
check("a huss's first stamp passes though our copy hasn't sped up (200 ms ping)", Relay.check(good({ p = Vector3.new(12, 3, 0),
	v = Vector3.new(110, 0, 0), push = C.PushFor }), { Position = root.Position, Anchored = false, AssemblyLinearVelocity = Vector3.new(16, 0, 0) }, hum, 100.1, 0.2))
check("faster than the walk without a push: refused", not Relay.check(good({ v = Vector3.new(60, 0, 0) }), root, hum, 100, 0.1))
check("no stamp: refused", not Relay.check(nil, root, hum, 100))
check("taken over 0.6 s ago: refused", not Relay.check(good(), root, hum, 100.7))
check("from the future: refused", not Relay.check(good(), root, hum, 98.5))
check("far from the server's copy: refused", not Relay.check(good({ p = Vector3.new(14, 3, 0) }), root, hum, 100))
check("keys faster than its WalkSpeed: refused", not Relay.check(good({ g = Vector3.new(40, 0, 0) }), root, hum, 100))
check("faster than any huss even pushed: refused", not Relay.check(good({ v = Vector3.new(200, 0, 0), push = C.PushFor }), root, hum, 100))
check("a dead body: refused", not Relay.check(good(), root, { Health = 0, WalkSpeed = 24 }, 100))
root.Anchored = true
check("a body held in place (caught, carried): refused", not Relay.check(good(), root, hum, 100))

print(string.format("MotionStamps: %d ok, %d failed", passed, failed))
if failed > 0 then error("MotionStamps spec failed") end
