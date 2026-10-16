--[[
	The start-of-round camera shots (Huss Valley's intro, owner's call) as pure maths, so the offline video
	(tools/preview/motion3d/intro_scene.luau) films exactly what HuzzClient/Gameplay/Cinematic does in game.
	Every shot returns (eye, look): where the camera stands and the point it looks at (Vector3s).
	`line` is the runners' line (RoundService LineCF): on the floor at the line's middle, looking across the
	field (so its -Z is the field, +Z is behind the runners, X runs along the line).
]]
local Shot = {}

function Shot.smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

function Shot.ease(x) -- fast out, soft landing
	x = math.clamp(x, 0, 1)
	return 1 - (1 - x) ^ 3
end

-- Lineup: behind and above the runners, looking across the field, drifting slowly forward.
function Shot.lineup(line, t, duration)
	local drift = 2 * Shot.smooth(t / duration)
	return (line * CFrame.new(0, 9 - drift, 18 - drift * 2)).Position, (line * CFrame.new(0, 2, -40)).Position
end

-- Picking, first part: in front of the line, sliding along it (left to right as the camera sees it).
function Shot.sweep(line, half, t, duration)
	local x = half - 2 * half * Shot.smooth(t / duration)
	return (line * CFrame.new(x * 0.8, 4.5, -12)).Position, (line * CFrame.new(x * 0.4, 3, 2.5)).Position
end

-- The roulette: hop times that slow down, the last one exactly at `total`.
function Shot.hops(total)
	local times, t = {}, 0
	while true do
		local f = t / total
		t += 0.055 + 0.32 * f * f
		if t >= total then
			break
		end
		table.insert(times, t)
	end
	table.insert(times, total)
	return times
end

-- Which runner the highlight is on at time t (1..count), landing on `final` at the last hop; and how many hops so far.
function Shot.hopIndex(t, total, count, final)
	local times = Shot.hops(total)
	local n = 0
	for _, h in times do
		if h <= t then
			n += 1
		end
	end
	return ((final - 1 - (#times - n)) % count) + 1, n
end

-- Picking, second part, and Chosen: a medium shot of the picked runner from the front (their upper body, a
-- neighbour either side, as in the reference). head: their Head CFrame. chosen: once they've picked, closer.
function Shot.face(line, head, chosen)
	local face = head.LookVector
	face = Vector3.new(face.X, 0, face.Z)
	face = if face.Magnitude > 0.01 then face.Unit else -line.LookVector
	local dist = if chosen then 8.5 else 11
	return head.Position + face * dist + Vector3.new(0, 1.4, 0), head.Position - Vector3.new(0, 1.3, 0)
end

-- Moving from one shot to the next over `a` (0..1): eased, and lifted up and over in between so the camera
-- never flies through the runners.
function Shot.transition(fromEye, fromLook, toEye, toLook, a)
	local s = Shot.smooth(a)
	local lift = math.clamp((toEye - fromEye).Magnitude * 0.3, 0, 12) * math.sin(math.pi * s)
	return fromEye:Lerp(toEye, s) + Vector3.new(0, lift, 0), fromLook:Lerp(toLook, s)
end
Shot.TransitionTime = 0.9

-- The hand-back: behind and above your own character, looking the way you face.
function Shot.behind(root, headPosition)
	local back = root.LookVector
	return headPosition - back * 11 + Vector3.new(0, 3.5, 0), headPosition + back * 6
end

return Shot
