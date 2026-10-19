-- lune run tests/Heartbeat.spec.luau
-- The heartbeat (Gameplay/Heartbeat, owner Oct 19: "add a heartbeat effect when someone gets closer"): the red edge
-- glow grows as a catcher comes closer, and stays kid-safe: never more than one swell a second (the root CLAUDE.md:
-- "at most 1 flash per second"), never a full-screen colour.
local Env = require("../tools/preview/motion3d/env")
local Heartbeat = Env.load("huzz-valley/src/StarterPlayer/StarterPlayerScripts/HuzzClient/Gameplay/Heartbeat.lua")

local failed, passed = 0, 0
local function check(ok, what)
	if ok then passed += 1 else failed += 1; print("FAIL " .. what) end
end

-- Distance to level: nothing far away, full up close, and it only grows as they come in.
check(Heartbeat.level(nil) == 0, "no catcher: no glow")
check(Heartbeat.level(Heartbeat.Far + 1) == 0, "beyond Far: nothing")
check(Heartbeat.level(Heartbeat.Near) == 1 and Heartbeat.level(1) == 1, "inside Near: full")
local last = -1
local grows = true
for d = Heartbeat.Far + 5, 0, -0.5 do
	local k = Heartbeat.level(d)
	if k < last then grows = false end
	last = k
end
check(grows, "the glow only grows as a catcher comes closer")

-- Never more than one beat a second, at any level.
local fastest = 0
for k = 0, 1, 0.05 do
	fastest = math.max(fastest, Heartbeat.rate(k))
end
check(fastest <= 1, string.format("at most 1 beat a second (fastest %.2f)", fastest))
check(Heartbeat.rate(0) < Heartbeat.rate(1), "a little faster when closer")

-- Run the beat for 20 s at full strength, as the module does (age resets each 1/rate s): count swells (a rise after a
-- fall) and the strongest the edge ever gets.
local dt = 1 / 60
local age, t = 0, 0
local swells, peak, prev, rising = 0, 0, 0, false
while t < 20 do
	local g = Heartbeat.glow(1, age)
	if g > prev + 1e-6 and not rising then
		swells += 1
		rising = true
	elseif g < prev - 1e-6 then
		rising = false
	end
	peak = math.max(peak, g)
	prev = g
	t += dt
	age += dt
	if age >= 1 / Heartbeat.rate(1) then age = 0 end
end
check(swells <= 20, string.format("at most one swell a second (%d in 20 s)", swells))
check(peak <= 0.6, string.format("the edge never goes solid (strongest %.2f)", peak))
check(Heartbeat.glow(0, 0.1) == 0, "no glow at level 0")
check(Heartbeat.Edge <= 0.25, "the glow stays at the edges (the middle of the screen stays clear)")

print(string.format("Heartbeat: %d ok, %d failed", passed, failed))
if failed > 0 then error("Heartbeat spec failed") end
