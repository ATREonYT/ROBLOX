-- Puts every dance's feet on the floor (owner, Oct 23 20:07: "fix the dances so they look appropriate ... make sure
-- they look good and are on par"). Measured on a plain R6 body with the root at standing height (dance_audit.luau):
-- 26 of the 38 dances pushed the legs into the floor in their crouches (OrangeSwing 0.9 studs, Breakdance 1.5), and
-- two floated (Untouchable lay 1.8 studs up in the air, SurfsUp rode 0.9 up). The fix moves only the body's height,
-- keyframe by keyframe, on the Torso pose (the root joint): a dance that floats the whole time comes down until its
-- lowest moment touches the floor; then at any keyframe where a block is under the floor the body goes up just
-- enough. Jumps, turns, arms, legs and timing are left exactly as they were. Run it once on each file:
--   lune run huzz-valley/tools/preview/motion3d/ground_dances.luau <in.rbxm> <out.rbxm>   (from the repo root)
-- His pack's file is private: never commit it (huzz-valley/CLAUDE.md).
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local KFS = require("./kfs")

local IN, OUT = process.args[1], process.args[2]
assert(IN and OUT, "usage: ground_dances.luau <in.rbxm> <out.rbxm>")
local FLOAT = 0.3 -- studs: a dance whose lowest moment is higher than this floats (comes down to the floor)
local TOUCH = 0.02 -- studs: the floor's thickness allowed (a hair under reads as standing on it)

local model = roblox.deserializeModel(fs.readFile(IN))
local folder = model[1]
local probe = Rig.r6("Probe")
local rootJoint
for _, m in probe.motors do if m.Part1.Name == "Torso" then rootJoint = m end end
local up = rootJoint.C0.Rotation:Inverse() -- (world up in the root joint's Transform space)

local function lowestAt(anim, t, lift)
	for _, m in probe.motors do m.Transform = CFrame.identity end
	KFS.apply(anim, probe, t)
	rootJoint.Transform = CFrame.new(up * Vector3.new(0, lift, 0)) * rootJoint.Transform
	probe.root.CFrame = CFrame.new(0, 3, 0)
	Rig.fk(probe)
	local low = math.huge
	for _, n in { "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" } do
		local p = probe.parts[n]
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

for _, seq in folder:GetChildren() do
	if seq.ClassName == "KeyframeSequence" and seq.Name:find("^Dance_") then
		local anim = KFS.load(seq)
		local frames = {}
		for _, kf in seq:GetChildren() do
			if kf.ClassName == "Keyframe" then table.insert(frames, kf) end
		end
		local lows, minLow = {}, math.huge
		for i, kf in frames do
			lows[i] = lowestAt(anim, kf.Time, 0)
			minLow = math.min(minLow, lows[i])
		end
		local drop = if minLow > FLOAT then minLow else 0
		local moved, most = 0, 0
		for i, kf in frames do
			local low = lows[i] - drop
			local offset = math.max(0, -TOUCH - low) - drop
			if math.abs(offset) > 1e-4 then
				local torso = kf:FindFirstChild("Torso", true)
				if torso and torso.ClassName == "Pose" then
					torso.CFrame = CFrame.new(up * Vector3.new(0, offset, 0)) * torso.CFrame
					moved += 1
					most = math.max(most, math.abs(offset))
				end
			end
		end
		-- Between keyframes the body can still dip under (two eased keyframes on either side of a deep crouch): sample
		-- every 1/60 s and lift the keyframes on both sides of any dip, a few rounds until nothing is under.
		table.sort(frames, function(a, b) return a.Time < b.Time end)
		for _ = 1, 6 do
			local again = KFS.load(seq)
			local need = {}
			local t, i = 0, 1
			while t <= again.length do
				while frames[i + 1] and frames[i + 1].Time <= t do i += 1 end
				local low = lowestAt(again, t, 0)
				if low < -TOUCH then
					for _, k in { i, i + 1 } do
						if frames[k] then need[k] = math.max(need[k] or 0, -TOUCH - low) end
					end
				end
				t += 1 / 60
			end
			if not next(need) then break end
			for k, lift in need do
				local torso = frames[k]:FindFirstChild("Torso", true)
				if torso and torso.ClassName == "Pose" then
					torso.CFrame = CFrame.new(up * Vector3.new(0, lift, 0)) * torso.CFrame
					most = math.max(most, lift)
				end
			end
		end
		if moved > 0 then
			print(string.format("%-22s %4d of %4d keyframes moved (most %.2f studs%s)", seq.Name:sub(7), moved, #frames, most, if drop > 0 then string.format(", down %.2f: it floated", drop) else ""))
		end
	end
end
fs.writeFile(OUT, roblox.serializeModel(model))
print("wrote " .. OUT)
