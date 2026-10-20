-- The 3D crate opening's maths (Shared/CrateMotion; owner, Oct 20: "make the opening animations look appropriate";
-- 07:51: "feel more premium ... remove [the circle] ... add s nice animation for the knife when it starts rising up"):
-- the timeline runs in order (crack, pause, open, a slow rise, one glint, the reveal), the lid never swings past its
-- limit or below shut, the build-up stays kid-gentle, the knife makes one slow turn and ends facing you, the motes
-- drift one at a time (never a burst), nothing flashes. Pure, no place file (tests/CrateModels.spec checks it on his
-- crates). lune run tests/CrateMotion.spec.luau   (from huzz-valley/)
local process = require("@lune/process")
local Color3 = require("@lune/roblox").Color3
local M = require("../src/ReplicatedStorage/Shared/CrateMotion")

local passed, failed = 0, 0
local function check(name, ok)
	if ok then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local T = M.T

-- 1. the timeline, in order
check("build-up, crack, a pause, open, rise, glint, reveal", T.Build > 0 and T.Crack >= T.Build and T.Open >= T.Crack + T.CrackLen + 0.2
	and T.Rise > T.Open and T.Glint < T.Rise + T.RiseLen and T.Glint + T.GlintLen > T.Rise + T.RiseLen and T.Reveal >= T.Rise + T.RiseLen)
check("the lid is well open before the knife is out", T.Open + T.OpenLen <= T.Rise + T.RiseLen * 0.5)
local inOrder = true
for i, at in M.Ticks do
	if at <= 0 or at >= T.Build or (i > 1 and at <= M.Ticks[i - 1]) then inOrder = false end
end
check("every knock is during the build-up, one after another", inOrder)

-- 2. the lid: shut, cracked a little (held), then open to LidOpen, never past its limit or below shut
check("shut until it cracks", M.lid(T.Crack - 0.01) == 0)
local crackA, crackB = M.lid(T.Crack + T.CrackLen), M.lid(T.Open - 0.01)
check(string.format("it cracks a few degrees and holds (%.1f deg)", math.deg(crackA)), crackA > math.rad(4) and crackA < math.rad(15) and math.abs(crackA - crackB) < 1e-3)
local lo, hi = math.huge, -math.huge
for t = -0.5, T.Reveal + 3, 1 / 120 do
	local a = M.lid(t)
	lo, hi = math.min(lo, a), math.max(hi, a)
end
check(string.format("never below shut (%.2f)", lo), lo >= 0)
check(string.format("a soft overshoot, at most 10%% past open (%.0f of %.0f deg)", math.deg(hi), math.deg(M.LidOpen)), hi > M.LidOpen and hi <= M.LidOpen * 1.1)
check("open less than 120 degrees (it swings back, never round)", M.LidOpen < math.rad(120))
check("rests exactly open once settled", math.abs(M.lid(T.Open + T.OpenLen) - M.LidOpen) < 1e-6 and math.abs(M.lid(T.Reveal + 5) - M.LidOpen) < 1e-6)

-- 3. the build-up: gentle (under 12 deg), still from the pause on, never in reduced motion
local most = 0
for t = 0, T.Build, 1 / 120 do most = math.max(most, math.abs(M.shake(t).roll), math.abs(M.shake(t).tilt)) end
check(string.format("rocks under 12 degrees (%.1f)", math.deg(most)), most < math.rad(12))
check("still during the pause after the crack", M.shake(T.Crack + 0.2).roll == 0 and M.shake(T.Open).roll == 0)
local calm = true
for t = 0, T.Reveal, 0.05 do local s = M.shake(t, true); if s.roll ~= 0 or s.tilt ~= 0 or s.lift ~= 0 then calm = false end end
check("reduced motion: never shakes", calm)

-- 4. the knife: slow, one turn, ends facing you, hovers gently
check("hidden until it rises", not M.knife(T.Rise - 0.01).seen and M.knife(T.Rise).seen)
local k = M.knife(T.Rise + T.RiseLen)
check("ends at its show spot, full size, facing you after one turn", math.abs(k.up - 1) < 1e-6 and math.abs(k.scale - 1) < 1e-6 and math.abs(k.spin - 2 * math.pi) < 1e-6 and M.Turns == 1)
local half = M.knife(T.Rise + T.RiseLen * 0.5)
check(string.format("a strong ease-out: most of the way up by half time (%.2f)", half.up), half.up > 0.8 and half.up < 1)
local fastest, prevSpin, prevUp, mono = 0, 0, 0, true
for t = T.Rise, T.Rise + T.RiseLen, 1 / 60 do
	local kp = M.knife(t)
	fastest = math.max(fastest, (kp.spin - prevSpin) * 60)
	if t > T.Rise and kp.up < prevUp - 1e-9 then mono = false end
	prevSpin, prevUp = kp.spin, kp.up
end
check(string.format("turns slowly (at most %.1f turns a second)", fastest / (2 * math.pi)), fastest / (2 * math.pi) < 2)
check("rises without dipping back", mono)
local bobLo, bobHi = math.huge, -math.huge
for t = T.Reveal, T.Reveal + 6, 0.05 do local kp = M.knife(t); bobLo, bobHi = math.min(bobLo, kp.up), math.max(bobHi, kp.up) end
check(string.format("hovers with a small bob (%.3f)", bobHi - bobLo), bobHi - bobLo > 0.01 and bobHi - bobLo < 0.06)
check("leans a little (5 to 20 deg)", k.tilt > math.rad(5) and k.tilt < math.rad(20))
local kc = M.knife(T.Rise, true)
check("reduced motion: the knife is simply there", kc.seen and math.abs(kc.up - 1) < 1e-6)

-- 5. light, not shapes: the glow spills at the crack; one glint; motes one at a time; the camera eases in
local _, mixBefore = M.glow(T.Crack - 0.01)
local _, mixAfter = M.glow(T.Crack + 0.3)
check("the rarity colour spills out as it cracks", mixBefore == 0 and mixAfter > 0.99)
check("the lit layer shows while it is cracked and is gone 0.4 s after it opens", M.spill(T.Crack - 0.01) == 0
	and M.spill(T.Open - 0.01) > 0.99 and M.spill(T.Open + M.SpillFade) == 0 and M.spill(T.Reveal) == 0)
local windows, was = 0, false
for t = 0, T.Reveal + 10, 1 / 120 do
	local _, a = M.glint(t)
	if a > 0 and not was then windows += 1 end
	was = a > 0
end
local _, glintTop = M.glint(T.Glint + T.GlintLen / 2)
check(string.format("one glint, once (%d)", windows), windows == 1 and glintTop <= 1)
check("no glint in reduced motion", select(2, M.glint(T.Glint + 0.2, true)) == 0)
local most2, burst = 0, false
for t = 0, T.Reveal + 8, 1 / 30 do
	local m = M.motes(t)
	most2 = math.max(most2, #m)
	for _, q in m do if q.alpha > 1 or q.size > 0.05 then burst = true end end
end
check(string.format("a few small motes at most (%d at once)", most2), most2 >= 1 and most2 <= M.Motes and not burst)
check("no motes before it cracks, none in reduced motion", #M.motes(T.Crack) == 0 and #M.motes(T.Reveal, true) == 0)
local m1, m2 = M.motes(T.Crack + 0.6), M.motes(T.Crack + 0.9)
check("the first mote drifts up", m1[1] ~= nil and m2[1] ~= nil and m2[1].y > m1[1].y)
check("the camera eases in a touch as it rises", M.push(T.Rise) == 1 and M.push(T.Reveal) > 1.05 and M.push(T.Reveal) <= 1.1 and M.push(T.Reveal, true) == 1)

-- 6. a dark knife gets a soft light behind its blade; the rest get none
local dark, gold = Color3.fromHex("1a1a22"), Color3.fromHex("e8c040")
check("a black blade (Hollow Moon) is dark, a gold one is not", M.isDark(dark) and not M.isDark(gold) and not M.isDark(nil))
check("the light behind a dark blade fades in as it rises, strong and nearly white", M.rimLight(T.Rise - 0.1, dark) == 0 and M.rimLight(T.Reveal, dark) > 0.85
	and M.rimLight(T.Reveal, dark) <= 1 and M.RimWhite >= 0.85 and M.rimLight(T.Reveal, gold) == 0)
check("the view brightens a little as the knife hovers, more for a dark blade", M.viewLift(T.Rise, dark) == 0 and M.viewLift(T.Reveal, dark) > 0.99
	and M.viewLift(T.Reveal, gold) > 0.2 and M.viewLift(T.Reveal, gold) < 0.5)

print(string.format("CrateMotion: %d passed, %d failed", passed, failed))
if failed > 0 then process.exit(1) end
