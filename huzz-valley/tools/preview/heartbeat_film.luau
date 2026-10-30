-- The heartbeat's red edge glow, frame by frame (Gameplay/Heartbeat's own maths and its RenderStepped loop, copied
-- step for step): a catcher walks in from 36 studs to 6, waits, then backs off to 40. Prints JSON lines
-- { t, d (studs), alpha (the edge's opacity), beat (true on a beat) } at 30 fps for heartbeat_film.py.
-- From huzz-valley/: lune run tools/preview/heartbeat_film.luau > <frames.jsonl>
local serde = require("@lune/serde")
local Env = require("./motion3d/env")
local Heartbeat = Env.load("huzz-valley/src/StarterPlayer/StarterPlayerScripts/HuzzClient/Gameplay/Heartbeat.lua")

local FPS = 30
local dt = 1 / FPS
local function distance(t)
	if t < 1 then return 36 end
	if t < 7 then return 36 - 30 * (t - 1) / 6 end -- (walks in)
	if t < 9 then return 6 end -- (right next to you)
	return math.min(40, 6 + 17 * (t - 9)) -- (backs off)
end
local k, beatAge, nextBeat = 0, 0, 0
for f = 0, 12 * FPS - 1 do
	local t = f * dt
	local d = distance(t)
	local target = Heartbeat.level(d)
	k += (target - k) * (1 - math.exp(-dt * 5))
	local alpha, beat = 0, false
	if k < 0.01 then
		beatAge, nextBeat = 0, 0
	else
		beatAge += dt
		nextBeat -= dt
		if nextBeat <= 0 then
			beatAge = 0
			nextBeat = 1 / Heartbeat.rate(k)
			beat = true
		end
		alpha = Heartbeat.glow(k, beatAge)
	end
	print(serde.encode("json", { t = t, d = d, alpha = alpha, beat = beat, edge = Heartbeat.Edge, color = { 215, 24, 48 } }))
end
