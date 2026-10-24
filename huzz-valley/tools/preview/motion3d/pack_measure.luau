-- Measures the owner's pack Walk and Run on a standard R15 body (Rig.r15): loop length, how far the planted foot
-- travels back per loop (so the speed at which 1x playback keeps the feet planted), steps a second, where the
-- right foot is furthest forward (the loop's phase), the bob and the arm swing. The numbers behind Config/Run.Loco.
-- Run from the repo root: lune run huzz-valley/tools/preview/motion3d/pack_measure.luau
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local KFS = require("./kfs")

local lib = roblox.Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile("huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do inst.Parent = lib end
local folder = lib:FindFirstChild("HuzzAnimations")
local rig = Rig.r15("M")
local N = 240
for _, name in { "Walk", "Run", "Idle" } do
	local anim = KFS.load(folder:FindFirstChild(name))
	local feet = {}
	for i = 0, N do
		local t = i / N * anim.length
		for _, m in rig.motors do m.Transform = CFrame.identity end
		KFS.apply(anim, rig, t)
		rig.root.CFrame = CFrame.new(0, Rig.REST_HEIGHT, 0)
		Rig.fk(rig)
		local function sole(p) return rig.parts[p].CFrame * Vector3.new(0, -0.15, 0) end
		feet[i] = { l = sole("LeftFoot"), r = sole("RightFoot"), hip = rig.parts.LowerTorso.CFrame.Position, rArm = rig.parts.RightHand.CFrame.Position }
	end
	local back, fwdR, fwdRAt, minY, maxY, hipMin, hipMax, armMin, armMax = 0, math.huge, 0, math.huge, -math.huge, math.huge, -math.huge, math.huge, -math.huge
	local swaps, prevSide = 0, nil
	local speeds = {}
	for i = 0, N - 1 do
		local a, b = feet[i], feet[i + 1]
		local side = if a.l.Y < a.r.Y then "l" else "r"
		local sideB = if b.l.Y < b.r.Y then "l" else "r"
		if prevSide and side ~= prevSide then swaps += 1 end
		prevSide = side
		if side == sideB then
			local dz = b[side].Z - a[side].Z
			back += math.max(dz, 0)
			table.insert(speeds, dz / (anim.length / N))
		end
		if a.r.Z < fwdR then fwdR, fwdRAt = a.r.Z, i / N end
		minY = math.min(minY, a.l.Y, a.r.Y); maxY = math.max(maxY, a.l.Y, a.r.Y)
		hipMin = math.min(hipMin, a.hip.Y); hipMax = math.max(hipMax, a.hip.Y)
		armMin = math.min(armMin, a.rArm.Z); armMax = math.max(armMax, a.rArm.Z)
	end
	table.sort(speeds)
	local med = speeds[math.floor(#speeds / 2) + 1] or 0
	local zmin, zmax = math.huge, -math.huge
	for i = 0, N do zmin = math.min(zmin, feet[i].l.Z, feet[i].r.Z); zmax = math.max(zmax, feet[i].l.Z, feet[i].r.Z) end
	print(string.format("%s: length %.3f s; planted foot goes back %.2f studs a loop -> feet planted at 1x = %.2f studs/s (median %.2f); %d foot swaps (%.2f steps/s at 1x); right foot most forward at phase %.3f; feet lift %.2f; hips bob %.2f; hand swing %.2f; foot reach %.2f",
		name, anim.length, back, back / anim.length, med, swaps, swaps / anim.length, fwdRAt, maxY - minY, hipMax - hipMin, armMax - armMin, zmax - zmin))
end
