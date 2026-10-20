-- The 3D crate opening's maths (Shared/CrateMotion; owner, Oct 20: "make the opening animations look appropriate"):
-- the timeline runs in order, the lid never swings past its limit or below shut, the build-up stays kid-gentle, the
-- knife ends at its show spot facing you. Pure, no place file (tests/CrateModels.spec checks it on his crates).
-- lune run tests/CrateMotion.spec.luau   (from huzz-valley/)
local process = require("@lune/process")
local Color3 = require("@lune/roblox").Color3
local M = require("../src/ReplicatedStorage/Shared/CrateMotion")

local passed, failed = 0, 0
local function check(name, ok)
	if ok then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local T = M.T

-- 1. the timeline, in order
check("build-up, then the knife, then the reveal", T.Build > 0 and T.Rise > T.Build and T.Rise + T.RiseLen <= T.Reveal + 1e-9)
check("the lid has opened before the knife is up", T.Build + T.OpenLen <= T.Rise + T.RiseLen)
local inOrder = true
for i, at in M.Ticks do
	if at <= 0 or at >= T.Build or (i > 1 and at <= M.Ticks[i - 1]) then inOrder = false end
end
check("every knock is during the build-up, one after another", inOrder)

-- 2. the lid: shut, then open to LidOpen, never past its limit (a small overshoot only) or below shut
local lo, hi = math.huge, -math.huge
for t = -0.5, T.Reveal + 3, 1 / 120 do
	local a = M.lid(t)
	lo, hi = math.min(lo, a), math.max(hi, a)
end
check(string.format("never below shut (%.2f)", lo), lo >= 0)
check(string.format("overshoots at most 15%% past open (%.0f of %.0f deg)", math.deg(hi), math.deg(M.LidOpen)), hi <= M.LidOpen * 1.15)
check("open less than 120 degrees (it swings back, never round)", M.LidOpen < math.rad(120))
check("rests exactly open once settled", math.abs(M.lid(T.Build + T.OpenLen) - M.LidOpen) < 1e-6 and math.abs(M.lid(T.Reveal + 5) - M.LidOpen) < 1e-6)

-- 3. the build-up: gentle (under 15 deg), still once open, never in reduced motion
local most = 0
for t = 0, T.Build, 1 / 120 do most = math.max(most, math.abs(M.shake(t).roll), math.abs(M.shake(t).tilt)) end
check(string.format("rocks under 15 degrees (%.1f)", math.deg(most)), most < math.rad(15))
check("still once open", M.shake(T.Build + T.OpenLen).roll == 0)
local calm = true
for t = 0, T.Reveal, 0.05 do local s = M.shake(t, true); if s.roll ~= 0 or s.tilt ~= 0 or s.lift ~= 0 then calm = false end end
check("reduced motion: never shakes", calm)

-- 4. the knife
check("hidden until it rises", not M.knife(T.Rise - 0.01).seen and M.knife(T.Rise).seen)
local k = M.knife(T.Rise + T.RiseLen)
check("ends at its show spot, full size, facing you", math.abs(k.up - 1) < 1e-6 and math.abs(k.scale - 1) < 1e-6 and math.abs(k.spin - 2 * math.pi * M.Spins) < 1e-6)
local kc = M.knife(T.Rise, true)
check("reduced motion: the knife is simply there", kc.seen and math.abs(kc.up - 1) < 1e-6)

-- 5. the light behind the knife: a dark knife gets a nearly white one, never there before the knife
local purple, white = Color3.fromRGB(170, 90, 255), Color3.new(1, 1, 1)
local darkMix, darkA = M.backlight(T.Reveal, Color3.fromHex("1a1a22"))
local goldMix = M.backlight(T.Reveal, Color3.fromHex("e8c040"))
local darkCol, goldCol = purple:Lerp(white, darkMix), purple:Lerp(white, goldMix)
check(string.format("a black blade (Hollow Moon) gets a nearly white light (%.2f)", M.luminance(darkCol)), M.isDark(Color3.fromHex("1a1a22")) and M.luminance(darkCol) > 0.8)
check("a bright knife keeps its rarity's colour", not M.isDark(Color3.fromHex("e8c040")) and M.luminance(goldCol) < M.luminance(darkCol))
local _, before = M.backlight(T.Rise - 0.1, nil)
check("no light before the knife rises, shown by the reveal", before == 1 and darkA < 0.3)
local _, _, discDark = M.backlight(T.Reveal, Color3.fromHex("1a1a22"))
local _, _, discGold = M.backlight(T.Reveal, Color3.fromHex("e8c040"))
check("a dark knife's big light turns pale too, a bright knife's keeps its colour", discDark >= 0.5 and discGold == 0)

print(string.format("CrateMotion: %d passed, %d failed", passed, failed))
if failed > 0 then process.exit(1) end
