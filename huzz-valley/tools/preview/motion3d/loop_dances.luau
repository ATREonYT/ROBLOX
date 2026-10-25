-- Makes looped dances wrap round without a jump (owner, Oct 25 15:02: "please fix the orange swing dance, its bugging
-- alot"). His Orange Justice ends 42 degrees away from where it starts (Left Arm 42, Right Arm 36, legs 10-13), so every
-- 6.35 s the arms snapped back. The fix is the usual loop crossfade: the loop is cut a little early, at the moment
-- that best matches the start, and the first X seconds are blended from "carrying on past the cut" into the real
-- start, so the end runs straight into the beginning. Timing, height and every other keyframe stay as they were.
--   lune run huzz-valley/tools/preview/motion3d/loop_dances.luau <in.rbxm> <out.rbxm> [Name,Name]  (from the repo root)
-- Default names: the looped dances whose seam is over SEAM degrees. His pack's file is private: never commit it.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local IN, OUT, NAMES = process.args[1], process.args[2], process.args[3]
assert(IN and OUT, "usage: loop_dances.luau <in.rbxm> <out.rbxm> [Name,Name]")
local SEAM = 25 -- degrees: a looped dance whose last frame is further than this from its first gets fixed
local X = 0.3 -- seconds of crossfade at the start
local SEARCH = 0.6 -- seconds before the end where the cut may go (no more of the dance is lost than this)

local only
if NAMES then
	only = {}
	for n in NAMES:gmatch("[^,]+") do only["Dance_" .. n] = true end
end

local function ang(a, b)
	local _, an = a:ToObjectSpace(b):ToAxisAngle()
	an = math.abs(an) % (2 * math.pi)
	return math.deg(math.min(an, 2 * math.pi - an))
end

local function framesOf(seq)
	local kfs = {}
	for _, k in seq:GetChildren() do
		if k.ClassName == "Keyframe" then table.insert(kfs, k) end
	end
	table.sort(kfs, function(a, b) return a.Time < b.Time end)
	local out = {}
	for i, k in kfs do
		local poses = {}
		for _, p in k:GetDescendants() do
			if p.ClassName == "Pose" then poses[p.Name] = p end
		end
		out[i] = { kf = k, t = k.Time, poses = poses }
	end
	return out
end

local function gap(a, b)
	local worst = 0
	for n, p in a.poses do
		local q = b.poses[n]
		if q then worst = math.max(worst, ang(p.CFrame, q.CFrame) + (p.CFrame.Position - q.CFrame.Position).Magnitude * 30) end
	end
	return worst
end

local model = roblox.deserializeModel(fs.readFile(IN))
for _, seq in model[1]:GetChildren() do
	if seq.ClassName == "KeyframeSequence" and seq.Name:find("^Dance_") and seq.Loop and (not only or only[seq.Name]) then
		local F = framesOf(seq)
		local len = F[#F].t
		local before = gap(F[#F], F[1])
		if #F > 20 and (only or before > SEAM) then
			-- keyframes are evenly spaced (1/60 or 1/30 s): work in keyframe steps
			local step = (len - F[1].t) / (#F - 1)
			local n = math.max(1, math.floor(X / step + 0.5))
			-- the cut: the keyframe c whose next n keyframes best match the first n (pose and direction of travel)
			local best, bestScore = nil, math.huge
			for c = #F - n, math.max(n + 2, #F - math.floor(SEARCH / step)), -1 do
				local score = 0
				for u = 0, n do score += gap(F[c + u], F[1 + u]) end
				if score < bestScore then best, bestScore = c, score end
			end
			-- blend: new(u) = carry-on(c + u) -> start(u), smoothstep over the n keyframes
			for u = 0, n - 1 do
				local a = u / n
				local w = a * a * (3 - 2 * a)
				for name, p in F[1 + u].poses do
					local q = F[best + u].poses[name]
					if q then p.CFrame = q.CFrame:Lerp(p.CFrame, w) end
				end
			end
			-- the loop now ends at the cut, whose pose is the new first frame
			for i = best + 1, #F do F[i].kf.Parent = nil end
			local G = framesOf(seq)
			print(string.format("%-22s seam %3.0f -> %3.0f, length %.2f -> %.2f s (%d keyframes blended)",
				seq.Name:sub(7), before, gap(G[#G], G[1]), len, G[#G].t, n))
		end
	end
end
fs.writeFile(OUT, roblox.serializeModel(model))
print("wrote " .. OUT)
