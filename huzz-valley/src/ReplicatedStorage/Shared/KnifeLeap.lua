--[[
	Which way a catcher's Space leap goes (owner, Oct 18: "make it so that when you press space to huss with the knife
	it leaps forward/sideways to catch the person"). Pure maths (spec: tests/KnifeLeap.spec.luau).
	  - the way you're steering: W = forward, A / D = sideways (like the runners' huss), W + A = forward-left;
	  - never backwards: holding S drops the back part (S alone = forward, S + D = right);
	  - nothing held = forward (the way you face).
	look: the body's facing; move: Humanoid.MoveDirection (world, already camera-relative). Both flattened.
]]
local KnifeLeap = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function KnifeLeap.direction(look: Vector3, move: Vector3): Vector3?
	local f = flat(look)
	if f.Magnitude < 1e-3 then
		return nil
	end
	f = f.Unit
	local m = flat(move)
	if m.Magnitude > 0.2 then
		local back = m:Dot(f)
		if back < 0 then
			m -= f * back -- (drop the backward part: never leap back)
		end
		if m.Magnitude > 0.2 then
			return m.Unit
		end
	end
	return f
end

return KnifeLeap
