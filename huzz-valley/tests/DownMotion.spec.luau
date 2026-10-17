-- lune run tests/DownMotion.spec.luau
-- Knocked down and getting up (Shared/DownMotion, Gameplay/Knockdown): when the server stands a revived player
-- straight up, the body doesn't pop: the first frame of getting up looks like the last frame lying down, and it
-- eases to standing in DownMotion.RISE seconds, then the joints are the animation's again.
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Env = require("../tools/preview/motion3d/env")
local Rig = require("../tools/preview/motion3d/rig")
local DownMotion = Env.load("huzz-valley/src/ReplicatedStorage/Shared/DownMotion.lua")

local failed, passed = 0, 0
local function check(ok, what)
	if ok then passed += 1 else failed += 1; print("FAIL " .. what) end
end

local rig = Rig.r15("P")
local height = Rig.REST_HEIGHT
local feet = CFrame.new(5, 0, 2) -- facing -Z
local rec = DownMotion.new(rig.motors)
-- lying (as Gameplay/Knockdown does every frame)
for _, m in rig.motors do m.Transform = CFrame.identity end
rig.root.CFrame = DownMotion.rootCFrame(feet, height, 3)
DownMotion.step(rec, 3)
Rig.fk(rig)
local lying = rig.parts.UpperTorso.CFrame
local lyingHead = rig.parts.Head.CFrame.Position
check(math.abs(lying.UpVector.Y) < 0.2, "lying flat")

-- the server stands them up: root straight up at the feet; first frame of getting up
rig.root.CFrame = feet * CFrame.new(0, height, 0)
for _, m in rig.motors do m.Transform = CFrame.identity end -- (the animation's pose this frame)
DownMotion.rise(rec, 0, height)
Rig.fk(rig)
local first = rig.parts.UpperTorso.CFrame
print(string.format("  head moves %.2f studs between the last frame down and the first frame up", (rig.parts.Head.CFrame.Position - lyingHead).Magnitude))
check((rig.parts.Head.CFrame.Position - lyingHead).Magnitude < 0.3, "no pop: the first frame up matches the last frame down")
check(first.UpVector:Dot(lying.UpVector) > 0.98, "no pop: the body keeps its lying angle on the first frame")

-- half way: partly up; at the end: standing, joints handed back
for _, m in rig.motors do m.Transform = CFrame.identity end
DownMotion.rise(rec, DownMotion.RISE / 2, height)
Rig.fk(rig)
local mid = rig.parts.UpperTorso.CFrame.UpVector.Y
check(mid > 0.3 and mid < 0.95, string.format("half way up (%.2f)", mid))
for _, m in rig.motors do m.Transform = CFrame.identity end
local going = DownMotion.rise(rec, DownMotion.RISE + 0.01, height)
check(not going, "getting up ends after RISE")
DownMotion.release(rec)
Rig.fk(rig)
check(rig.parts.UpperTorso.CFrame.UpVector.Y > 0.99, "standing at the end")

print(`DownMotion: {passed} ok, {failed} failed`)
if failed > 0 then error("DownMotion spec failed") end
