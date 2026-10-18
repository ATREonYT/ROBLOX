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

-- Owner, Oct 18: "not have a swinging animations ... you go like in and under the map, just make them lay on the
-- floor and look like their dead". The run keeps playing under a downed body (hip bob, crouch, leg swing): every
-- joint must be ours, so the body is perfectly still and nothing dips under the floor (feet at y = 0).
do
	local function lowest(r)
		local y = math.huge
		for _, b in Rig.boxes(r) do
			local c, h = b.CFrame, b.Size / 2
			local reach = math.abs(c.RightVector.Y) * h.X + math.abs(c.UpVector.Y) * h.Y + math.abs(c.LookVector.Y) * h.Z
			y = math.min(y, c.Position.Y - reach)
		end
		return y
	end
	local r2 = Rig.r15("Q")
	local rec2 = DownMotion.new(r2.motors)
	local first, moved, low = nil, 0, math.huge
	for f = 0, 40 do
		local t = 1 + f / 30
		for _, m in r2.motors do -- a swinging run pose this frame (what the Animator writes)
			local a = math.sin(t * 9 + #m.Name) * 0.8
			m.Transform = CFrame.new(0, -0.6 * math.abs(a), 0) * CFrame.Angles(a, a * 0.3, 0)
		end
		r2.root.CFrame = DownMotion.rootCFrame(feet, height, t)
		DownMotion.step(rec2, t)
		Rig.fk(r2)
		local pos = {}
		for name, part in r2.parts do pos[name] = part.CFrame.Position end
		if first then
			for name, p in pos do moved = math.max(moved, (p - first[name]).Magnitude) end
		else
			first = pos
		end
		low = math.min(low, lowest(r2))
	end
	print(string.format("  lying still: parts move %.3f studs over 1.3 s of a swinging run; lowest point %.2f (floor 0)", moved, low))
	check(moved < 0.01, "a downed body lies perfectly still while the run animation keeps playing")
	check(low > -0.08, "nothing of a downed body dips under the floor")
end

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
