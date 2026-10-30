-- lune run tests/R6Knife.spec.luau  (Shared/StabMotion on R6 bodies; owner, Oct 22 18:53-18:55: "make the animations for
-- swinging the knives"; "make the jumping animation way better")
-- On a stock R6 body standing on the floor (facing -Z): the swing winds up high and cuts down across the front; the dive tips the body flat along the floor, arms ahead, nothing under the floor, and
-- hands every joint back when it's over.
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Env = require("../tools/preview/motion3d/env")
local Rig = require("../tools/preview/motion3d/rig")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local CarryMath = Env.load(SHARED .. "CarryMath.lua")
local StabMotion = Env.load(SHARED .. "StabMotion.lua")
local Round = Env.load(SHARED .. "Config/Round.lua")

local failed, passed = 0, 0
local function check(ok, what)
	if ok then passed += 1 else failed += 1; print("FAIL " .. what) end
end

local function body()
	local rig = Rig.r6("K")
	rig.root.CFrame = CFrame.new(0, 3, 0)
	return rig, StabMotion.new(CarryMath.rig(rig), rig.root)
end
local function at(rig, rec, t)
	for _, m in rig.motors do m.Transform = CFrame.identity end
	StabMotion.slashStart(rec, t)
	StabMotion.step(rec, t)
	Rig.fk(rig)
	return rig.parts
end
local function lowest(P)
	local low = math.huge
	for _, name in { "Torso", "Right Arm", "Left Arm", "Right Leg", "Left Leg" } do
		local p = P[name]
		local h = p.Size / 2
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					low = math.min(low, (p.CFrame * Vector3.new(h.X * x, h.Y * y, h.Z * z)).Y)
				end
			end
		end
	end
	return low
end
local function armDir(P, name) return -P[name].CFrame.UpVector end

-- the swing (Oct 23 20:07 "make more of a swing to it"): wound up high over the right shoulder with the body coiled
-- right, then cut down across the front to the low left with the body turned into it, free arm pulled back
do
	local rig, rec = body()
	StabMotion.play(rec, 0, false)
	local P = at(rig, rec, 0.2 * Round.Stab.Time)
	local knife = armDir(P, "Right Arm")
	check(knife.Y > 0.6, string.format("swing: wound up, the knife arm high (%.2f, %.2f, %.2f)", knife.X, knife.Y, knife.Z))
	check(P.Torso.CFrame.LookVector.X > 0.25, string.format("swing: wound up, the body coiled to the right (%.2f)", P.Torso.CFrame.LookVector.X))
	P = at(rig, rec, 0.36 * Round.Stab.Time)
	knife = armDir(P, "Right Arm")
	check(knife.X < -0.2 and knife.Y < 0, string.format("swing: cut across to the low left (%.2f, %.2f, %.2f)", knife.X, knife.Y, knife.Z))
	check(P.Torso.CFrame.LookVector.X < -0.2, string.format("swing: the body turned into the cut (%.2f)", P.Torso.CFrame.LookVector.X))
	check(armDir(P, "Left Arm").Z > 0, "swing: the free arm pulled back")
	local low = math.huge
	for i = 0, 12 do low = math.min(low, lowest(at(rig, rec, i / 12 * Round.Stab.Time))) end
	check(low > -0.1, string.format("swing: nothing under the floor (lowest %.2f)", low))
	P = at(rig, rec, Round.Stab.Time + 0.1)
	check(rig.parts["Right Arm"].CFrame.UpVector.Y > 0.99, "swing: over, the arm is the animation's again")
end

-- the dive: flat on the floor at the landing, arms ahead, never under the floor; standing again at the end
do
	local rig, rec = body()
	StabMotion.play(rec, 0, true)
	local low = math.huge
	for i = 0, 26 do
		local P = at(rig, rec, i / 30)
		low = math.min(low, lowest(P))
	end
	check(low > -0.1, string.format("dive: nothing goes under the floor (a hair while the arms blend in; lowest %.2f)", low))
	local P = at(rig, rec, 0.36)
	local up = P.Torso.CFrame.UpVector
	check(up.Z < -0.9, string.format("dive: the body lies along the way it dived (%.2f)", up.Z))
	check(math.abs(lowest(P)) < 0.1, string.format("dive: lying on the floor (lowest %.2f)", lowest(P)))
	check(armDir(P, "Left Arm").Z < -0.6, "dive: the arms reach ahead")
	P = at(rig, rec, 0.2)
	check(P.Torso.CFrame.Position.Y > 0.6, "dive: up off the floor in the spring")
	P = at(rig, rec, StabMotion.LEAP.Up + 0.05)
	check(P.Torso.CFrame.UpVector.Y > 0.99 and math.abs(P.Torso.CFrame.Position.Y - 3) < 0.01, "dive: standing again at the end")
end

-- a sideways dive (right) tips the body to the right
do
	local rig, rec = body()
	StabMotion.play(rec, 0, true)
	StabMotion.setDive(rec, Vector3.new(1, 0, 0))
	local P = at(rig, rec, 0.36)
	check(P.Torso.CFrame.UpVector.X > 0.9, string.format("dive right: the body lies to the right (%.2f)", P.Torso.CFrame.UpVector.X))
end

print(string.format("R6Knife: %d ok, %d failed", passed, failed))
if failed > 0 then error("R6Knife spec failed") end
