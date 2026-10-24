--[[
	The Combine machine's merge, as a timeline (owner, Oct 20 14:57: "make a nice merging animation. Keep it smooth and
	tidy. and not too long"). Pure maths, no Instances: Gameplay/CombineMachine moves the game's parts with it on every
	screen, and tools/preview/motion3d/combine_scene.luau films the same numbers offline.
	  0.0 - 0.8   the two copies appear on his two pads (a soft puff) and float up and in to the ring
	  0.8 - 2.0   they circle each other in front of his ring, faster and closer, while the machine charges: the ring
	              turns faster, his glowing trim brightens, motes are pulled in
	  2.0         the merge: ONE soft burst in the new grade's colour (kid-safe: one flash, never repeated)
	  2.05 - 2.9  the new girl rises out of it in her grade, turning once to face you
	  2.9 - 3.6   she floats there (the window shows her name and grade)
	  3.6 - 4.0   she sinks into his altar and the machine settles back to its idle
	Tap to skip: Gameplay/CombineMachine jumps to the end.
	frame (where things are on his machine, in world space; Gameplay/CombineMachine finds them by his part names):
	  ring   the middle of his summon ring        front  flat unit vector out of the machine (toward his stairs)
	  padA, padB  the tops of his two pads         altar  the top of his altar (the lotus)
	  height the girls' height (Config/Combine.Merge.Height)
	at(t, frame) returns { a, b, result = { show, cf (her feet, facing) }, ring (spin x), glow (0..1), inward (bool),
	burst (nil or { size, transparency, k }), flash (0..1), camera = { eye, look } }.
]]
local Config = require(script.Parent.Config.Combine)

local CombineMotion = {}

local RISE_END = 0.8
local MERGE_AT = 2.0
local REVEAL_START = MERGE_AT + 0.05
CombineMotion.RISE_END = RISE_END
CombineMotion.MERGE_AT = MERGE_AT
CombineMotion.REVEAL_END = 2.9
CombineMotion.HOLD_END = 3.6
CombineMotion.LENGTH = 4.0
CombineMotion.FLASHES = { MERGE_AT } -- (one, kid-safe: at most one flash a second)
-- When each sound starts (Config/Combine.Sounds names)
CombineMotion.CUES = { { at = 0, sound = "Charge" }, { at = MERGE_AT, sound = "Merge" }, { at = MERGE_AT + 0.08, sound = "Reveal" } }

local M = Config.Merge
local UP = Vector3.new(0, 1, 0)

local function clamp01(x: number): number return math.clamp(x, 0, 1) end
local function smooth(x: number): number x = clamp01(x); return x * x * (3 - 2 * x) end
local function outCubic(x: number): number x = clamp01(x); return 1 - (1 - x) ^ 3 end
local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-4 then f.Unit else Vector3.new(0, 0, 1)
end

-- A girl's feet at `pos`, looking along `facing` turned by `yaw` radians round the vertical.
local function stand(pos: Vector3, facing: Vector3, yaw: number): CFrame
	return CFrame.lookAt(pos, pos + facing) * CFrame.Angles(0, yaw, 0)
end

-- The middle the two circle round: a little in front of his ring (so they don't pass through its blade).
function CombineMotion.centre(frame): Vector3
	return frame.ring + flat(frame.front) * 0.9
end

function CombineMotion.at(t: number, frame)
	local h = frame.height or M.Height
	local front = flat(frame.front)
	local side = flat(frame.padA - frame.padB)
	local centre = CombineMotion.centre(frame)
	local feetMid = centre - UP * (h / 2) -- (feet of a girl whose middle is at the ring's middle)
	local out = { a = { show = false }, b = { show = false }, result = { show = false }, ring = 1, glow = 0, inward = false, flash = 0 }

	-- the two copies
	if t < MERGE_AT then
		for i, who in { out.a, out.b } do
			local pad = if i == 1 then frame.padA else frame.padB
			local s = if i == 1 then 1 else -1
			local start = feetMid + side * (M.Orbit * s)
			if t < RISE_END then
				local u = smooth(t / RISE_END)
				local pos = pad:Lerp(start, u) + UP * (math.sin(math.pi * u) * 0.8)
				who.show, who.cf = true, stand(pos, front, s * 0.6 * u) -- (a quarter turn in toward each other)
			else
				local u = (t - RISE_END) / (MERGE_AT - RISE_END)
				local turn = 2 * math.pi * (0.9 * u + 1.6 * u * u) -- (faster and faster: about 2.5 turns)
				local r = M.Orbit * (1 - u) ^ 1.4
				local base = math.atan2(side.Z, side.X) + (if i == 1 then 0 else math.pi) + turn
				local pos = feetMid + Vector3.new(math.cos(base), 0, math.sin(base)) * r + UP * (0.3 * u)
				who.show, who.cf = true, stand(pos, front, s * 0.6 + turn)
			end
		end
	end

	-- the machine charging, then settling
	if t < MERGE_AT then
		local u = clamp01((t - RISE_END * 0.5) / (MERGE_AT - RISE_END * 0.5))
		out.ring = 1 + (M.ChargeSpeed - 1) * u * u
		out.glow = u ^ 1.5
		out.inward = t > 0.5
	else
		local after = t - MERGE_AT
		out.ring = 1 + (M.ChargeSpeed - 1) * math.exp(-after * 4)
		out.glow = clamp01(1 - after / (CombineMotion.HOLD_END - MERGE_AT))
	end

	-- the one burst
	local B = M.Burst
	if t >= MERGE_AT and t < MERGE_AT + B.Time then
		local k = (t - MERGE_AT) / B.Time
		out.burst = { size = 0.6 + (B.Size - 0.6) * outCubic(k), transparency = 0.15 + 0.85 * smooth(k), k = k }
		out.flash = (1 - k) ^ 2
	end

	-- the new girl
	if t >= REVEAL_START and t < CombineMotion.LENGTH then
		local pos, yaw
		if t < CombineMotion.REVEAL_END then
			local v = outCubic((t - REVEAL_START) / (CombineMotion.REVEAL_END - REVEAL_START))
			pos = feetMid + UP * (-0.5 + 0.5 * v)
			yaw = 2 * math.pi * (1 - v) -- (one turn, ending face on)
		elseif t < CombineMotion.HOLD_END then
			pos = feetMid + UP * (0.08 * math.sin((t - CombineMotion.REVEAL_END) * 2 * math.pi / 1.4))
			yaw = 0
		else
			local w = smooth((t - CombineMotion.HOLD_END) / (CombineMotion.LENGTH - CombineMotion.HOLD_END))
			pos = feetMid:Lerp(frame.altar, w)
			yaw = 0
		end
		out.result.show, out.result.cf = true, stand(pos, front, yaw)
	end

	-- the camera (only the player who merges): in front of the machine, easing in while it charges
	local Cam = M.Camera
	local dist = Cam.Back + (Cam.In - Cam.Back) * smooth(t / MERGE_AT) + 0.5 * smooth((t - MERGE_AT) / 2)
	local swing = Cam.Side * (1 - smooth(t / CombineMotion.LENGTH)) - 0.04
	local c, s = math.cos(swing), math.sin(swing)
	local dir = Vector3.new(front.X * c + front.Z * s, 0, -front.X * s + front.Z * c)
	out.camera = { eye = centre + dir * dist + UP * Cam.Up, look = centre + UP * 0.2 }
	return out
end

return CombineMotion
