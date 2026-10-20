-- The 3D crate opening's maths (Shared/CrateMotion; owner, Oct 20: "make the opening animations look appropriate";
-- 07:51: "feel more premium ... remove [the circle]"; 15:13: "make the case opening animation way, way better, right
-- now its so vague ... remove so much glow from the crates, and then make it feel premium"): about 3 to 3.5 s to the
-- knife; three heavy hops, a latch, the lid flung open with a bounce, never past its limit; the knife out, a three
-- quarter turn to its profile, a sharp stop, big on the screen; one rarity colour that fades in (never a flash); a
-- fixed camera with a slow push-in and no wobble; the name lands with a short punch. Pure, no place file
-- (tests/CrateModels.spec checks it on his crates). lune run tests/CrateMotion.spec.luau   (from huzz-valley/)
local process = require("@lune/process")
local Color3 = require("@lune/roblox").Color3
local M = require("../src/ReplicatedStorage/Shared/CrateMotion")

local passed, failed = 0, 0
local function check(name, ok)
	if ok then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local T = M.T
local DONE = T.Rise + T.RiseLen -- the knife has stopped

-- 1. the timeline: short, in order
check(string.format("the knife is out and stopped in about 3 to 3.5 s (%.2f), its name right after (%.2f)", DONE, T.Reveal),
	DONE >= 2.9 and DONE <= 3.5 and T.Reveal >= DONE and T.Reveal <= DONE + 0.15)
local inOrder = #T.Hops == 3
for i, at in T.Hops do
	if at <= 0 or (i > 1 and at < T.Hops[i - 1] + T.HopLen) then inOrder = false end
end
check("three hops, one after another, all before the latch", inOrder and T.Hops[3] + T.HopLen < T.Crack)
check("the latch pops, a held beat, then it opens; the knife only once the lid is moving", T.Open >= T.Crack + T.CrackLen + 0.25
	and T.Rise > T.Open and T.Rise < T.Open + T.OpenLen)
check("a thud as each hop lands", #M.Lands == 3 and M.Lands[1] > T.Hops[1] and M.Lands[3] < T.Crack)

-- 2. the lid: shut, popped a little and held, then flung open with a bounce, never past its limit or below shut
check("shut until the latch pops", M.lid(T.Crack - 0.01) == 0)
local crackA, crackB = M.lid(T.Crack + T.CrackLen), M.lid(T.Open - 0.01)
check(string.format("it cracks a few degrees and holds (%.1f deg)", math.deg(crackA)), crackA > math.rad(4) and crackA < math.rad(12) and math.abs(crackA - crackB) < 1e-3)
local lo, hi, hiAt = math.huge, -math.huge, 0
for t = -0.5, T.Reveal + 3, 1 / 240 do
	local a = M.lid(t)
	lo = math.min(lo, a)
	if a > hi then hi, hiAt = a, t end
end
check(string.format("never below shut (%.2f)", lo), lo >= 0)
check(string.format("a bounce past open, at most 10%% (%.0f of %.0f deg)", math.deg(hi), math.deg(M.LidOpen)), hi > M.LidOpen * 1.03 and hi <= M.LidOpen * 1.1)
check(string.format("flung: past open within 0.4 s (%.2f s)", hiAt - T.Open), hiAt - T.Open < 0.4)
local half = M.lid(T.Open + 0.12)
check(string.format("fast: well open 0.12 s in (%.0f deg)", math.deg(half)), half > M.LidOpen * 0.4)
check("open less than 120 degrees (it swings back, never round)", M.LidOpen < math.rad(120))
check("rests exactly open once settled", math.abs(M.lid(T.Open + T.OpenLen) - M.LidOpen) < 1e-6 and math.abs(M.lid(T.Reveal + 5) - M.LidOpen) < 1e-6)
local jump = 0
for t = T.Open, T.Open + T.OpenLen + 0.1, 1 / 60 do jump = math.max(jump, math.abs(M.lid(t + 1 / 60) - M.lid(t))) end
check(string.format("no snap at the end (largest step a frame %.1f deg)", math.deg(jump)), jump < math.rad(25))

-- 3. the hops: heavier each time, still between them, still from the latch, never in reduced motion
local most, peak = 0, { 0, 0, 0 }
for t = 0, T.Crack, 1 / 240 do
	local s = M.shake(t)
	most = math.max(most, math.abs(s.roll), math.abs(s.tilt))
	for i, at in T.Hops do if t >= at and t < at + T.HopLen then peak[i] = math.max(peak[i], s.lift) end end
end
check(string.format("tips under 12 degrees (%.1f)", math.deg(most)), most < math.rad(12) and most > math.rad(2))
check(string.format("each hop higher (%.3f, %.3f, %.3f)", peak[1], peak[2], peak[3]), peak[1] > 0.01 and peak[2] > peak[1] and peak[3] > peak[2] and peak[3] < 0.15)
local between = M.shake((T.Hops[1] + T.HopLen + T.Hops[2]) / 2)
check("still between hops (weight, not a rattle)", between.roll == 0 and between.tilt == 0 and between.lift == 0)
local held = M.shake((T.Crack + T.Open) / 2)
check("still while the latch is popped", held.roll == 0 and held.lift == 0)
local kick = M.shake(T.Open + 0.15)
check("the lid's weight rocks it back a touch", kick.tilt > 0 and kick.tilt < math.rad(4))
local calm = true
for t = 0, T.Reveal, 0.05 do local s = M.shake(t, true); if s.roll ~= 0 or s.tilt ~= 0 or s.lift ~= 0 then calm = false end end
check("reduced motion: never moves", calm)

-- 4. the knife: out, a three quarter turn to its profile, a sharp stop, big and in front
check("hidden until it comes out", not M.knife(T.Rise - 0.01).seen and M.knife(T.Rise).seen)
local k = M.knife(DONE)
check("ends at its show spot, full size, its profile facing you", math.abs(k.up - 1) < 1e-6 and math.abs(k.fwd - 1) < 1e-6
	and math.abs(k.scale - 1) < 1e-6 and math.abs(k.spin) < 1e-6 and math.abs(k.tilt - M.Knife.Lean) < 1e-6)
local k0 = M.knife(T.Rise)
check("starts edge-on, small, inside", math.abs(math.abs(k0.spin) - 2 * math.pi * 0.75) < 1e-6 and k0.scale < 0.6 and math.abs(k0.up) < 1e-9 and k0.fwd == 0)
check("comes towards you only once it is out of the crate", M.knife(T.Rise + T.RiseLen * 0.2).fwd < 1e-6 and M.knife(T.Rise + T.RiseLen * 0.2).up > 0.5)
local over, fastest, prevSpin = 0, 0, M.knife(T.Rise).spin
for t = T.Rise, DONE, 1 / 120 do
	local kp = M.knife(t)
	over = math.max(over, kp.up)
	fastest = math.max(fastest, math.abs(kp.spin - prevSpin) * 120)
	prevSpin = kp.spin
end
check(string.format("a sharp stop: just past its spot and back (%.3f)", over), over > 1.01 and over < 1.06)
check(string.format("turns at most 2.5 turns a second (%.1f)", fastest / (2 * math.pi)), fastest / (2 * math.pi) < 2.5)
local bobLo, bobHi = math.huge, -math.huge
for t = T.Reveal, T.Reveal + 6, 0.05 do local kp = M.knife(t); bobLo, bobHi = math.min(bobLo, kp.up), math.max(bobHi, kp.up) end
check(string.format("then hovers with a tiny bob (%.3f)", bobHi - bobLo), bobHi - bobLo > 0.005 and bobHi - bobLo < 0.04)
check("leans into a diagonal (15 to 30 deg)", M.Knife.Lean > math.rad(15) and M.Knife.Lean < math.rad(30))
local kc = M.knife(T.Rise, true)
check("reduced motion: the knife is simply there", kc.seen and kc.up == 1 and kc.fwd == 1 and kc.scale == 1)
local y0, z0 = M.knifeSpot(M.knife(T.Rise))
local y1, z1 = M.knifeSpot(k)
check("it starts inside the crate and ends over it, in front", y0 < 0.5 and y1 > 1 and z0 == 0 and z1 > 0.3)

-- 5. the fixed shot: a slow push-in, no wobble; the knife big and the crate clear of the words
local prev, smooth, mono = M.push(0), true, true
for t = 0, T.Reveal + 2, 1 / 60 do
	local p = M.push(t)
	if p < prev - 1e-9 then mono = false end
	if math.abs((M.push(t + 1 / 60) - p) - (p - prev)) > 0.002 then smooth = false end
	prev = p
end
check("the camera only pushes in, smoothly (no wobble)", mono and smooth and M.push(0) == 1)
check(string.format("a subtle push-in (%.0f%%), still after the reveal", (M.push(T.Reveal) - 1) * 100), M.push(T.Reveal) > 1.03 and M.push(T.Reveal) <= 1.1
	and M.push(T.Reveal + 3) == M.push(T.Reveal))
local h, depth = 2.6, 2.2 -- (a crate about his Beast Chest's size)
local lookY, eyeY, eyeZ = M.camera(h, 1)
local cx, cy = M.project(lookY, eyeY, eyeZ, 0, lookY, 0, 16 / 9)
check("it looks where it aims", math.abs(cx - 0.5) < 1e-6 and math.abs(cy - 0.5) < 1e-6)
local _, bottom = M.project(lookY, eyeY, eyeZ, 0, 0, 0, 16 / 9)
local _, top = M.project(lookY, eyeY, eyeZ, 0, h, 0, 16 / 9)
check(string.format("the crate sits low, clear of the name under it (bottom %.0f px of 720)", bottom * 720), bottom * 720 < 425 and bottom * 720 > 360 and top < bottom)
local lookE, eyeYE, eyeZE = M.camera(h, M.push(T.Reveal))
local ky, kz = M.knifeSpot(k)
local half2 = h * M.Knife.Len / 2
local _, tipY = M.project(lookE, eyeYE, eyeZE, 0, h * ky + half2 * math.cos(M.Knife.Lean), -depth * kz, 16 / 9)
local _, endY = M.project(lookE, eyeYE, eyeZE, 0, h * ky - half2 * math.cos(M.Knife.Lean), -depth * kz, 16 / 9)
check(string.format("the knife is big (%.0f px tall of 720) and stays on the screen (tip at %.0f)", (endY - tipY) * 720, tipY * 720), (endY - tipY) * 720 > 230 and tipY > 0.04)

-- 6. one light from inside, one colour cue, nothing flashes
check("the light inside shows through the gap and is gone once it is open", M.spill(T.Crack - 0.01) == 0
	and M.spill(T.Open - 0.01) > 0.99 and M.spill(T.Open + 0.5) == 0 and M.spill(T.Reveal) == 0)
local tintStep, tintMono, prevT = 0, true, M.tint(0)
for t = 0, T.Reveal + 2, 1 / 60 do
	local v = M.tint(t)
	tintStep = math.max(tintStep, math.abs(v - prevT))
	if v < prevT then tintMono = false end
	prevT = v
end
check("the backdrop takes the rarity colour as it opens", M.tint(T.Open - 0.01) == 0 and M.tint(T.Open + T.TintLen) == 1)
check(string.format("a fade, never a flash (at most %.2f a frame, only up)", tintStep), tintMono and tintStep < 0.1)
local spillUp = 0
local was = 0
for t = 0, T.Reveal + 2, 1 / 60 do
	local v = M.spill(t)
	if v > 0.5 and was <= 0.5 then spillUp += 1 end
	was = v
end
check("the light inside comes up once (no flashing)", spillUp == 1)
check("the crate falls into shadow as the knife comes out", M.dim(T.Rise) == 0 and M.dim(T.Reveal) > 0.99 and M.Dim > 0.3 and M.Dim < 0.8)
check("the light rim comes up with the knife", M.rim(T.Rise - 0.1) == 0 and M.rim(T.Reveal) > 0.99)
local dark, gold = Color3.fromHex("0e0a16"), Color3.fromHex("fff2c0")
check("a black blade (Void Fang) is dark and gets a wider rim, a light one does not", M.isDark(dark) and not M.isDark(gold) and not M.isDark(nil)
	and M.rimWidth(dark) > M.rimWidth(gold) and M.rimWidth(dark) < 0.03)

-- 7. the name lands with a short punch
local s0, a0 = M.punch(T.Reveal - 0.01, T.Reveal)
local s1, a1 = M.punch(T.Reveal + M.PunchLen, T.Reveal)
local sMin = math.huge
for t = T.Reveal, T.Reveal + M.PunchLen, 1 / 240 do sMin = math.min(sMin, (M.punch(t, T.Reveal))) end
check("hidden before it lands", a0 == 0 and s0 == M.PunchFrom)
check(string.format("lands big and settles to its size in %.2f s (a hair under at most: %.3f)", M.PunchLen, sMin), M.PunchFrom > 1.1 and M.PunchFrom < 1.5
	and math.abs(s1 - 1) < 1e-6 and a1 == 1 and sMin > 0.97 and M.PunchLen <= 0.3)
check("reduced motion: the words are simply there", select(1, M.punch(T.Reveal + 0.01, T.Reveal, true)) == 1)

-- 8. his knives' aura ring and shards are hidden (owner, 07:51: "remove it")
check("aura parts are told apart", M.isAura("aura_ring_30") and M.isAura("aura_shard_31") and not M.isAura("blade_28") and not M.isAura("guard_gem_14"))

print(string.format("CrateMotion: %d passed, %d failed", passed, failed))
if failed > 0 then process.exit(1) end
