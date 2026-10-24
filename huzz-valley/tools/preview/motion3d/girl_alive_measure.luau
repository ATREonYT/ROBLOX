-- How much a girl visibly moves, in numbers (owner Oct 20: "it doesnt seem fixed"; his clip: the prize girl over
-- the field "doesn't move at all"). Runs the game's own motion code on a stock R6 girl at 60 fps and prints, per
-- joint, how far it swings (peak to peak, degrees) in a 2 s window (his clip's length) and over 20 s, for:
--   showcase: the big girl over the map (CarryAnimator: GirlMoves.idle + GirlMotion.look + GirlMotion.showcase);
--   showcase-before: the same before Oct 20 (the Idle and a slow head drift only);
--   prize: GirlMotion.idle (the scripted fallback, with a player near);
--   held: GirlMotion.carried (calm, standing carrier).
-- lune run huzz-valley/tools/preview/motion3d/girl_alive_measure.luau   (repo root)
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Env = require("./env")
local Rig = require("./rig")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local GirlMoves = Env.load(SHARED .. "GirlMoves.lua")
local GirlMotion = Env.load(SHARED .. "GirlMotion.lua")

local lib = roblox.Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile(Env.root .. "/huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do
	inst.Parent = lib
end
local anims = assert(GirlMoves.load(lib:FindFirstChild("HuzzAnimations")))

local function angle(a, b)
	local _, ang = (a:Inverse() * b):ToAxisAngle()
	return math.deg(math.abs(ang))
end

local M = {}

-- Peak-to-peak swing of each joint (largest angle between any two frames' Transforms) over [from, to] seconds.
function M.run(kind: string, seconds: number, step)
	local rig = Rig.r6("G")
	local J = GirlMotion.joints(rig.motors)
	local s = GirlMotion.new(7)
	local pack = GirlMoves.new(anims, 3)
	local dt = 1 / 60
	local frames = {}
	for i = 1, math.floor(seconds * 60) do
		local t = i * dt
		Rig.fk(rig)
		if step then
			step(rig, J, s, pack, dt, t)
		elseif kind == "showcase" then
			-- (as CarryAnimator since Oct 20: watching a player below, feet swinging, a wave and a kick now and then;
			-- "showcase-before" = the Idle and a head drift only, as before)
			GirlMoves.idle(pack, J, dt, GirlMotion.look(s, J, dt, t, { target = Vector3.new(6, -34, -20), distance = 40 }))
			GirlMotion.showcase(s, J, dt, t)
		elseif kind == "showcase-before" then
			GirlMoves.idle(pack, J, dt, GirlMotion.look(s, J, dt, t, {}))
		elseif kind == "prize" then
			GirlMotion.idle(s, J, dt, t, { target = Vector3.new(0, 4, -10), distance = 10 })
		elseif kind == "held" then
			GirlMotion.carried(s, J, dt, t, { accel = Vector3.zero, forward = Vector3.new(0, 0, -1), mood = "Calm", moodAge = 99, step = 0, amount = 0 })
		end
		local f = {}
		for key, m in J do
			f[key] = m.Transform
		end
		frames[i] = f
	end
	return frames
end

function M.swing(frames, from: number, to: number)
	local out = {}
	local a, b = math.max(1, math.floor(from * 60)), math.min(#frames, math.floor(to * 60))
	for key in frames[a] do
		-- (pairwise over a coarse grid: enough for a peak-to-peak number)
		local best = 0
		for i = a, b, 6 do
			for j = i + 6, b, 6 do
				best = math.max(best, angle(frames[i][key], frames[j][key]))
			end
		end
		out[key] = best
	end
	return out
end

local function show(name, frames)
	local keys = { "Neck", "LShoulder", "RShoulder", "LHip", "RHip", "Root" }
	local worst2, line2, line20 = math.huge, {}, {}
	-- the quietest 2 s window anywhere in the 20 s (what a 2 s clip can catch)
	for start = 0, 18, 1 do
		local w = M.swing(frames, start, start + 2)
		local biggest = 0
		for _, k in keys do biggest = math.max(biggest, w[k] or 0) end
		if biggest < worst2 then
			worst2 = biggest
			line2 = {}
			for _, k in keys do table.insert(line2, string.format("%s %.1f", k, w[k] or 0)) end
		end
	end
	local jump = 0 -- the biggest turn of any joint from one frame to the next (calm: under 6°)
	for i = 2, #frames do
		for k, cf in frames[i] do jump = math.max(jump, angle(frames[i - 1][k], cf)) end
	end
	local all = M.swing(frames, 0, 20)
	for _, k in keys do table.insert(line20, string.format("%s %.1f", k, all[k] or 0)) end
	print(string.format("%-9s quietest 2 s: biggest joint swing %.1f° (%s)", name, worst2, table.concat(line2, ", ")))
	print(string.format("%-9s over 20 s: %s; biggest frame step %.1f°", "", table.concat(line20, ", "), jump))
	return worst2
end

M.show = show
if not _G.GIRL_ALIVE_LIB then
	for _, kind in { "showcase-before", "showcase", "prize", "held" } do
		show(kind, M.run(kind, 20))
	end
end
return M
