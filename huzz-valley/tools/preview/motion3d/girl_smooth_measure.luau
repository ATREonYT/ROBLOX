-- How smooth the girls' walk is, in numbers (owner Oct 18: "make the walking animation normal for the girls, right
-- now its so choppy"). Runs the game's own FollowMotion + GirlMoves on a small R6 companion following a leader at
-- 60 fps and prints, per speed: the biggest frame-to-frame joint turn and its jerk (the change in turn speed from one
-- frame to the next: a smooth swing has a small one, a pop a big one), the body's up/down and forward/back jerk,
-- and how much a foot on the ground jitters up and down (heights are for a standard 5.25-stud girl).
-- lune run huzz-valley/tools/preview/motion3d/girl_smooth_measure.luau   (repo root)
-- Oct 18 numbers (full run, small companion): before 43.7°/frame turns with 24°/frame² jerks and a 0.78-stud body
-- lurch jerk; after the fix ~23°/frame, ~8°/frame², 0.04 (tests/GirlMoves.spec checks the limits).
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Env = require("./env")
local Rig = require("./rig")
local process = require("@lune/process")
-- GIRL_SHARED=<folder>/ measures another copy of Shared (e.g. the code before a change: git archive <commit>
-- huzz-valley/src/ReplicatedStorage/Shared | tar -x -C /tmp/before, then GIRL_SHARED=/tmp/before/huzz-valley/src/ReplicatedStorage/Shared/)
local SHARED = process.env.GIRL_SHARED or "huzz-valley/src/ReplicatedStorage/Shared/"
local GirlMoves = Env.load(SHARED .. "GirlMoves.lua")
local FollowMotion = Env.load(SHARED .. "FollowMotion.lua")
local Companion = Env.load(SHARED .. "Config/GirlMotion.lua").Companion

local lib = roblox.Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile(Env.root .. "/huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do
	inst.Parent = lib
end
local anims = assert(GirlMoves.load(lib:FindFirstChild("HuzzAnimations")))

local M = {}
M.anims = anims

local function angle(a, b)
	local _, ang = (a:Inverse() * b):ToAxisAngle()
	return math.abs(ang)
end

-- Runs `seconds` at `fps` with the leader at `speed`. opts.jitter (0-1): the leader's position steps unevenly
-- frame to frame (as when the screen's frames and physics steps don't line up).
function M.run(speed: number, opts)
	opts = opts or {}
	local fps = opts.fps or 60
	local dt = 1 / fps
	local k = opts.k or (2.8 / 5.25)
	local rig = Rig.r6("G")
	Rig.scale(rig, k)
	local rec = FollowMotion.new({ root = rig.root, motors = rig.motors, rootHeight = 3 * k, seed = 1, moves = anims, config = opts.config or Companion })
	local leader = CFrame.new(0, 3, 0)
	local prev, prevD = {}, {}
	local out = { turn = 0, jerk = 0, joint = "", bodyJerkY = 0, bodyJerkZ = 0, footJitter = 0, worstAt = 0 }
	local hist = {}
	local lastFeet
	local seconds = opts.seconds or 6
	for f = 0, math.floor(seconds * fps) do
		local step = speed * dt
		if opts.jitter and opts.jitter > 0 then
			step *= if f % 2 == 0 then 1 - opts.jitter else 1 + opts.jitter
		end
		leader = leader * CFrame.new(0, 0, -step)
		FollowMotion.step(rec, dt, f * dt, leader, function() return 0 end, leader.Position + Vector3.new(0, 1.5, 0))
		Rig.fk(rig)
		local t = f * dt
		local settle = t > 2
		for _, m in rig.motors do
			local p = prev[m]
			if p then
				local d = angle(p, m.Transform)
				if settle then
					if d > out.turn then out.turn = d end
					if prevD[m] then
						local j = math.abs(d - prevD[m])
						if j > out.jerk then out.jerk, out.joint, out.worstAt = j, m.Name, t end
					end
				end
				prevD[m] = d
			end
			prev[m] = m.Transform
		end
		-- the torso relative to her root (k-normalised): up/down and forward/back
		local rel = rig.root.CFrame:Inverse() * rig.parts.Torso.CFrame
		table.insert(hist, rel.Position / k)
		local n = #hist
		if settle and n >= 3 then
			local a, b, c = hist[n - 2], hist[n - 1], hist[n]
			out.bodyJerkY = math.max(out.bodyJerkY, math.abs(c.Y - 2 * b.Y + a.Y))
			out.bodyJerkZ = math.max(out.bodyJerkZ, math.abs(c.Z - 2 * b.Z + a.Z))
		end
		-- each foot's height while it's on or near the ground (a foot that hops or shakes while planted)
		local ys = {}
		for _, name in { "Left Leg", "Right Leg" } do
			local p = rig.parts[name]
			ys[name] = (p.CFrame * CFrame.new(0, -p.Size.Y / 2, 0)).Position.Y / k
		end
		if settle and lastFeet and lastFeet[2] then
			for name, y in ys do
				local y1, y2 = lastFeet[1][name], lastFeet[2][name]
				if math.max(y, y1, y2) < 0.15 then
					out.footJitter = math.max(out.footJitter, math.abs(y - 2 * y1 + y2))
				end
			end
		end
		lastFeet = { ys, lastFeet and lastFeet[1] }
	end
	out.turn, out.jerk = math.deg(out.turn), math.deg(out.jerk)
	out.weights = rec.pack and rec.pack.mix.weights
	out.rec = rec
	return out
end

M.SPEEDS = { 4, 8, 14, 22, 28 }

function M.report(label, opts)
	print(label)
	for _, v in M.SPEEDS do
		local r = M.run(v, opts)
		print(string.format("  leader %2d studs/s: biggest turn %5.1f°/frame, jerk %5.1f°/frame² (%s @%.2fs), body jerk up %.3f fwd %.3f, planted-foot jerk %.3f",
			v, r.turn, r.jerk, r.joint, r.worstAt, r.bodyJerkY, r.bodyJerkZ, r.footJitter))
	end
end

if not _G.NO_MAIN then
	M.report("60 fps, smooth leader")
	M.report("60 fps, leader stepping unevenly (30% jitter)", { jitter = 0.3 })
end

return M
