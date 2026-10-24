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
		t += 0.17 + 0.3 * f * f -- (never faster than about 6 a second; the glow is an outline while it hops)
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
Shot.PushTime = 0.6 -- seconds the camera takes to zoom in once they've chosen (Gameplay/Cinematic eases it)
function Shot.face(line, head, chosen)
	local face = head.LookVector
	face = Vector3.new(face.X, 0, face.Z)
	face = if face.Magnitude > 0.01 then face.Unit else -line.LookVector
	local dist = if chosen then 8.5 else 11
	return head.Position + face * dist + Vector3.new(0, 1.4, 0), head.Position - Vector3.new(0, 1.3, 0)
end

-- Quart in-out: the swing between shots (Huss Valley's: one quick swing, then the shot holds).
function Shot.swing(x)
	x = math.clamp(x, 0, 1)
	return if x < 0.5 then 8 * x ^ 4 else 1 - (2 - 2 * x) ^ 4 / 2
end

-- Moving from one shot to the next over `a` (0..1), Huss Valley's way (docs/feel-study.md gap 4): one quick
-- swing that goes ROUND and OVER, never through. The eye orbits the point between the two looks (so it swings round
-- the runners instead of diving through them, and never ends up straight above them looking down), rises with the
-- distance, and with `clearY` (the height of the runners' heads) it is at least 4 studs over heads mid-swing.
-- The look point glides between the two. Walls and the floor: Gameplay/Cinematic pulls the eye in front of them.
function Shot.transition(fromEye, fromLook, toEye, toLook, a, clearY)
	local s = Shot.swing(a)
	local look = fromLook:Lerp(toLook, s)
	local pivot = fromLook:Lerp(toLook, 0.5)
	local f, t = fromEye - pivot, toEye - pivot
	local rf, rt = Vector3.new(f.X, 0, f.Z).Magnitude, Vector3.new(t.X, 0, t.Z).Magnitude
	local eye
	if rf > 1 and rt > 1 then
		local af, at = math.atan2(f.Z, f.X), math.atan2(t.Z, t.X)
		local d = (at - af + math.pi) % (2 * math.pi) - math.pi -- (the short way round)
		local ang, r = af + d * s, rf + (rt - rf) * s
		eye = pivot + Vector3.new(math.cos(ang) * r, f.Y + (t.Y - f.Y) * s, math.sin(ang) * r)
	else
		eye = fromEye:Lerp(toEye, s)
	end
	local dist = (toEye - fromEye).Magnitude
	local arc = math.sin(math.pi * s)
	local y = eye.Y + math.clamp(dist * 0.3, 0, 12) * arc
	if clearY and dist > 6 then
		local base = fromEye.Y + (toEye.Y - fromEye.Y) * s
		y = math.max(y, base + math.max(0, clearY + 4 - base) * arc)
	end
	return Vector3.new(eye.X, y, eye.Z), look
end
Shot.TransitionTime = 0.25 -- seconds (HV 0.2 to 0.3; was 0.9, a slow drift)
Shot.HandBackTime = 0.3 -- the swing back behind you

-- Your own camera in a round, as Huss Valley frames it (gap 5: you're about a third of the screen tall, the horizon
-- ~30% from the top): Gameplay/Cinematic hands back exactly here, then caps the zoom.
Shot.RoundZoom = 12 -- studs from the focus (the lobby sits further back)
Shot.RoundPitch = 14 -- degrees looking down (at FOV 70 that puts the horizon ~32% from the top)
Shot.RoundMaxZoom = 22 -- how far you can scroll out in a round
Shot.FocusHeight = 1.5 -- Roblox's camera looks at this point over the root part (R15)

-- The hand-back: where Roblox's own camera will sit once it takes over: RoundZoom behind `focus` (your root part +
-- FocusHeight, plus the shift-lock offset), looking `facing` (the way the round runs) RoundPitch degrees down.
function Shot.behind(facing, focus)
	local flat = Vector3.new(facing.X, 0, facing.Z).Unit
	local p = math.rad(Shot.RoundPitch)
	local dir = flat * math.cos(p) - Vector3.new(0, math.sin(p), 0)
	return focus - dir * Shot.RoundZoom, focus
end

return Shot
