-- lune run tests/MoveGuard.spec.luau   (from huzz-valley/)
-- HuzzServer/MoveGuard (owner, Oct 21: "make the game not client sided, but server sided also"): a run at top
-- speed, a huss, a dive, a fall and a screen that froze and caught up all pass; a speed hack and a jump across the
-- map are caught.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3

local ROOT = if fs.isDir("huzz-valley") then "huzz-valley/" else ""
local M = luau.load(fs.readFile(ROOT .. "src/ServerScriptService/HuzzServer/MoveGuard.lua"), { debugName = "MoveGuard",
	environment = { Vector3 = Vector3, math = math } })()

local passed, failed = 0, 0
local function check(name, cond)
	if cond then passed += 1 else failed += 1; print("FAIL " .. name) end
end

-- a run: `speed` studs a second for `time` seconds, looked at every 0.25 s; extra(t) adds studs along the way
local function run(speed, time, top, extra)
	local rec, caught = nil, false
	for i = 0, time / 0.25 do
		local t = i * 0.25
		local x = speed * t + (if extra then extra(t) else 0)
		local far
		rec, far = M.look(rec, Vector3.new(x, 0, 0), t, top)
		caught = caught or far
	end
	return caught
end
check("a run at top speed passes", not run(28, 10, 28))
check("a run with a huss (15 studs) and a dive (19) passes", not run(28, 10, 28, function(t) return (if t >= 2 then 15 else 0) + (if t >= 2.25 then 19 else 0) end))
check("a fall straight down passes", not (select(2, M.look({ at = Vector3.new(0, 100, 0), t = 0 }, Vector3.new(2, -50, 0), 0.25, 28))))
check("a screen that froze 1.5 s then caught up passes", not (select(2, M.look({ at = Vector3.new(0, 0, 0), t = 0 }, Vector3.new(42, 0, 0), 1.5, 28))))
check("a speed hack (80 studs a second at top speed 28) is caught", run(80, 4, 28)) -- (60 until the Oct 24 lag fix loosened it)
check("a run at a Speed Boost's top (36) with a huss and a dive passes", not run(36, 10, 36, function(t) return (if t >= 3 then 15 else 0) + (if t >= 3.5 then 19 else 0) end))
check("a jump across the map (300 studs) is caught", (select(2, M.look({ at = Vector3.new(0, 0, 0), t = 0 }, Vector3.new(300, 0, 0), 0.25, 28))))
-- release check (Oct 22): held still by the server (top 0) and no huss or dive just accepted (SMALL_BURST)
local S = M.SMALL_BURST
check("held still (a trap): a small drift passes", not (select(2, M.look({ at = Vector3.new(0, 0, 0), t = 0 }, Vector3.new(5, 0, 0), 2, 0, S))))
check("held still (a trap): walking 40 studs out is caught", (select(2, M.look({ at = Vector3.new(0, 0, 0), t = 0 }, Vector3.new(40, 0, 0), 2, 0, S))))
check("a 45-stud blink with no huss or dive is caught", (select(2, M.look({ at = Vector3.new(0, 0, 0), t = 0 }, Vector3.new(45, 0, 0), 0.25, 28, S))))
check("a huss the server refused (15 studs) still passes", not (select(2, M.look({ at = Vector3.new(0, 0, 0), t = 0 }, Vector3.new(22, 0, 0), 0.25, 28, S))))
-- owner, Oct 22 18:53 (the dive "teleports you back to the middle"): a catcher running at 30, then a dive (21 studs
-- in 0.38 s) whose stun holds them at speed 0 (top 0) while the run before it is still inside the window
do
	local rec, caught = nil, false
	for i = 0, 12 do
		local t = i * 0.25
		local x = 30 * math.min(t, 1.75) + (if t >= 2 then 21 else if t > 1.75 then 21 * (t - 1.75) / 0.38 else 0)
		local far
		rec, far = M.look(rec, Vector3.new(x, 0, 0), t, if t > 1.75 and t < 2.6 then 0 else 30, M.BURST)
		caught = caught or far
	end
	check("a catcher's run and then a dive (stunned at speed 0 after) passes", not caught)
end
local kept = M.look({ at = Vector3.new(1, 0, 2), t = 0 }, Vector3.new(300, 0, 0), 0.25, 28)
check("caught: the spot to go back to is the last good one", kept.at == Vector3.new(1, 0, 2))

print(string.format("MoveGuard: %d passed, %d failed", passed, failed))
if failed > 0 then error("MoveGuard spec failed") end
