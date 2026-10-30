-- Measures each dance's own tempo, so its music can be picked to fit the steps (owner, Oct 19: "find the sounds we
-- can use for all of the dances ... logically select the best sounds/songs possible"; docs/sound-picks.md).
-- For each Dance_<Id> in ServerStorage/HuzzAnimations.rbxm it samples the hands, feet, head and torso 60 times a
-- second over the whole loop, adds up how fast they move (the "energy" of the dance), and finds the strongest
-- repeat in that energy between 0.3 and 1.3 s (autocorrelation). Steps land on beats, so that repeat is a beat
-- (or two); it prints it as BPM folded into 85-170 (the range dance music lives in), plus how busy the dance is.
-- From the repo root: lune run huzz-valley/tools/preview/motion3d/dance_tempo.luau
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local CFrame = roblox.CFrame
local Rig = require("./rig")
local KFS = require("./kfs")

local folder = roblox.deserializeModel(fs.readFile("huzz-valley/src/ServerStorage/HuzzAnimations.rbxm"))[1]
local names = {}
for _, seq in folder:GetChildren() do
	if seq.Name:find("^Dance_") then table.insert(names, seq.Name) end
end
table.sort(names)

local PARTS = { "LeftHand", "RightHand", "LeftFoot", "RightFoot", "Head", "UpperTorso" }
local RATE = 60
local probe = Rig.r15("Probe")
probe.root.CFrame = CFrame.new(0, Rig.REST_HEIGHT, 0)

local function where()
	local out = {}
	for _, n in PARTS do out[n] = probe.root.CFrame:PointToObjectSpace(probe.parts[n].CFrame.Position) end
	return out
end

print(string.format("%-20s %6s %7s %6s %6s  %s", "dance", "loop s", "beats", "BPM", "busy", "strength"))
for _, name in names do
	local anim = KFS.load(folder:FindFirstChild(name))
	local n = math.max(2, math.floor(anim.length * RATE))
	local energy, last = {}, nil
	for i = 0, n - 1 do
		KFS.apply(anim, probe, i / RATE)
		Rig.fk(probe)
		local p = where()
		local e = 0
		if last then
			for _, k in PARTS do e += (p[k] - last[k]).Magnitude * RATE end
		end
		energy[i + 1] = e
		last = p
	end
	energy[1] = energy[2] or 0
	local mean = 0
	for _, e in energy do mean += e end
	mean /= #energy
	local x = {}
	for i, e in energy do x[i] = e - mean end
	-- autocorrelation (circular: the dance loops)
	local function ac(lag)
		local s, z = 0, 0
		for i = 1, #x do
			local j = (i - 1 + lag) % #x + 1
			s += x[i] * x[j]
			z += x[i] * x[i]
		end
		return if z > 0 then s / z else 0
	end
	-- A loop is a whole number of beats, so the beat candidates are loop / k (k = 1, 2, 3 ...) that land in
	-- 85-170 BPM; each is scored by how well the energy repeats at one beat and at two beats.
	local function acAt(sec)
		return ac(math.max(1, math.floor(sec * RATE + 0.5)))
	end
	local best, bestBpm, bestK = -math.huge, 0, 0
	for k = 1, 64 do
		local bpm = 60 * k / anim.length
		if bpm >= 85 and bpm <= 170 then
			local beat = anim.length / k
			local v = acAt(beat) + 0.5 * acAt(2 * beat)
			if v > best then best, bestBpm, bestK = v, bpm, k end
		end
	end
	print(string.format("%-20s %6.2f %7d %6.0f %6.1f  %.2f", name:sub(7), anim.length, bestK, bestBpm, mean, best))
end
