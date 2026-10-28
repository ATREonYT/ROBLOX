-- GuideArrow (Oct 28, the owner after playing in Studio: "the arrow isn't good ... make the arrows float ... more
-- cartoony"): the one guide arrow's look and its pure rules, drawn by HoodClient/GoalGuide for the tutorial's steps
-- and for every goal after it (one colour, one style, from spawn to the end of the first loop: research pattern 9).
--   * A chunky, toy-like 3D arrow pointing down, like the +1 games': a bright gold body (a block shaft over a two-wedge
--     head, a whole stud deep), a light cap on its top and a lip along the head's top edge, a soft white shine down the
--     shaft's face, and a thick near-black outline (an ink plate a little bigger behind it, which the camera always
--     sees around it since the arrow turns to face you, plus a Highlight outline in the real game).
--   * It FLOATS over the target with a smooth eased bob and breathes (a gentle pulse in size), grows with the distance
--     so it reads from across the hall, and keeps clear of walls and ceilings (GuideArrow.clear).
--   * The EDGE pointer: while the arrow is off screen, a round badge at the screen's edge with a gold chevron points
--     the way (GuideArrow.edge).
-- Every number is studs at scale 1 unless it says px. Pure functions (motion, scaleFor, layout, clear, edge) are unit
-- tested in UnitTest/Cases/GuideArrow_Test; build / lay / setAlpha make and move the client's local parts.
local GuideArrow = {}

local C = Color3.fromRGB
GuideArrow.Colors = {
	Fill = C(255, 200, 36), -- the body: a warm, loud gold (the HUD's gold tone)
	Top = C(255, 238, 150), -- the cap and the head's lip: the light falling on its top
	Shine = C(255, 251, 226), -- the soft streak down the shaft
	Ink = C(26, 18, 8), -- the outline: a warm near-black, like the UI's ink
}
GuideArrow.Size = {
	HeadW = 1.85, -- half the head's width
	HeadH = 2.05, -- the head's height (tip to its top edge)
	ShaftW = 1.55, ShaftH = 2.2, -- the shaft over it
	Depth = 1.0, -- how deep the whole arrow is (chunky, not a sign)
	Ink = 0.26, -- the outline's width around the silhouette
	InkDepth = 0.3, -- the ink plate's own depth (it sits right behind the body)
}
GuideArrow.Up = 6.5 -- the tip's height over the target's floor point (clear of the stations' own labels)
GuideArrow.Bob = { Amp = 0.55, Period = 1.4 } -- studs up and down; seconds a cycle (an eased sine: soft at both ends)
GuideArrow.Pulse = { Amp = 0.06, Period = 1.4, Lag = 0.25 } -- a share of its size; it swells just after the top of the bob
GuideArrow.Grow = { From = 1, To = 1.8, Near = 18, Far = 70 } -- its scale over the distance to you
GuideArrow.Clear = { Ceiling = 1.0, Wall = 0.7, Lowest = 2.5 } -- studs kept from a ceiling and a wall; the tip never under Lowest
GuideArrow.Edge = { Margin = 74, Size = 66, Push = 7, Period = 0.9, OnScreenPad = 24 } -- px

---------------------------------------------------------------------------------------------- pure rules
-- The bob (studs) and the size factor at time t (seconds); still = ReducedMotion (no bob, no pulse).
function GuideArrow.motion(t, still)
	if still or type(t) ~= 'number' or t ~= t then return 0, 1 end
	local B, P = GuideArrow.Bob, GuideArrow.Pulse
	local bob = B.Amp * math.sin(t * 2 * math.pi / B.Period)
	local pulse = 1 + P.Amp * math.sin((t - P.Lag) * 2 * math.pi / P.Period)
	return bob, pulse
end
-- Its scale for a flat distance to you: 1 near, growing to Grow.To far away (so it reads across the hall).
function GuideArrow.scaleFor(dist)
	local G = GuideArrow.Grow
	if type(dist) ~= 'number' or dist ~= dist then return G.From end
	local u = math.clamp((dist - G.Near) / (G.Far - G.Near), 0, 1)
	return G.From + (G.To - G.From) * u
end
-- The arrow's height at scale k: the tip to the top of the shaft.
function GuideArrow.height(k)
	local S = GuideArrow.Size
	return (S.HeadH + S.ShaftH) * (k or 1)
end
-- The parts' places in the arrow's own frame (x right, y up, z toward the viewer; the tip at the origin) at scale k:
-- { [name] = { Kind = 'Block' | 'Wedge', Pos = Vector3, Size = Vector3, Side = -1 | 1 (a wedge's half) } }.
-- A wedge half is laid with its right angle at the top of the centre line (GuideArrow.lay turns it).
function GuideArrow.layout(k)
	k = k or 1
	local S = GuideArrow.Size
	local V = Vector3.new
	local D, E = S.Depth, S.Ink
	local back = -(D / 2 + S.InkDepth / 2) -- (the ink plate's centre: right behind the body)
	local hw, hh = S.HeadW, S.HeadH
	local rimW, rimH = hw + 1.5 * E, hh + 2.56 * E -- (the head grown by E all round: its tip 1.56 E lower)
	local shaftY = hh + S.ShaftH / 2
	local out = {
		ArrowShaft = { Kind = 'Block', Pos = V(0, shaftY, 0), Size = V(S.ShaftW, S.ShaftH, D) },
		ArrowHeadL = { Kind = 'Wedge', Side = -1, Pos = V(-hw / 2, hh / 2, 0), Size = V(D, hh, hw) },
		ArrowHeadR = { Kind = 'Wedge', Side = 1, Pos = V(hw / 2, hh / 2, 0), Size = V(D, hh, hw) },
		ArrowCap = { Kind = 'Block', Pos = V(0, hh + S.ShaftH - 0.1, 0), Size = V(S.ShaftW + 0.02, 0.24, D + 0.04) },
		ArrowLip = { Kind = 'Block', Pos = V(0, hh - 0.1, 0), Size = V(2 * hw - 0.1, 0.22, D + 0.04) },
		ArrowShine = { Kind = 'Block', Pos = V(-S.ShaftW * 0.27, shaftY + 0.12, D / 2 + 0.02), Size = V(0.26, S.ShaftH * 0.62, 0.04) },
		ArrowBackShaft = { Kind = 'Block', Pos = V(0, shaftY + E * 0.5, back), Size = V(S.ShaftW + 2 * E, S.ShaftH + E, S.InkDepth) },
		ArrowBackL = { Kind = 'Wedge', Side = -1, Pos = V(-rimW / 2, -1.56 * E + rimH / 2, back), Size = V(S.InkDepth, rimH, rimW) },
		ArrowBackR = { Kind = 'Wedge', Side = 1, Pos = V(rimW / 2, -1.56 * E + rimH / 2, back), Size = V(S.InkDepth, rimH, rimW) },
	}
	for _, p in out do p.Pos, p.Size = p.Pos * k, p.Size * k end
	return out
end
-- Where the arrow may float over a target's floor point `at`, keeping clear of what is around it. cast(origin, dir)
-- returns the distance to the first solid thing along dir (a unit vector times a length) or nil for none; face is the
-- flat unit vector toward the viewer. Returns the tip's point (Vector3).
--   * A ceiling or an overhang over it brings it down (never under Clear.Lowest over the floor).
--   * A wall (or a sign) beside its body, left, right, in front or behind, pushes it away.
function GuideArrow.clear(at, k, face, cast)
	k = k or 1
	local up = Vector3.new(0, 1, 0)
	local h = GuideArrow.height(k)
	local tipY = GuideArrow.Up
	if type(cast) ~= 'function' then return at + up * tipY end
	local roof = cast(at + up * 0.5, up * (tipY + h + 2))
	if type(roof) == 'number' then
		tipY = math.max(GuideArrow.Clear.Lowest, math.min(tipY, roof + 0.5 - h - GuideArrow.Clear.Ceiling))
	end
	local tip = at + up * tipY
	face = (typeof(face) == 'Vector3' and face.Magnitude > 0.01) and Vector3.new(face.X, 0, face.Z).Unit or Vector3.new(0, 0, 1)
	local right = up:Cross(face).Unit
	local mid = tip + up * (h * 0.6)
	local side = GuideArrow.Size.HeadW * k + GuideArrow.Clear.Wall
	local deep = GuideArrow.Size.Depth * k + GuideArrow.Clear.Wall
	local shift = Vector3.zero
	for _, r in { { right, side }, { -right, side }, { face, deep }, { -face, deep } } do
		local d = cast(mid, r[1] * r[2])
		if type(d) == 'number' and d < r[2] then shift -= r[1] * (r[2] - d) end
	end
	return tip + shift
end
-- Where a world point lands on a `view` sized screen (px) seen from camCF with a vertical field of view fov
-- (degrees), like Camera:WorldToViewportPoint (which the offline harness lacks): x, y in px and z the depth, negative
-- behind the camera (where x, y come out mirrored, as Roblox's do).
function GuideArrow.project(camCF, fov, view, point)
	if typeof(camCF) ~= 'CFrame' or typeof(view) ~= 'Vector2' or typeof(point) ~= 'Vector3' then return nil end
	local p = camCF:PointToObjectSpace(point)
	local depth = -p.Z
	if math.abs(depth) < 0.01 then depth = -0.01 end
	local f = (view.Y / 2) / math.tan(math.rad(math.clamp(fov or 70, 1, 120)) / 2)
	return Vector3.new(view.X / 2 + p.X / depth * f, view.Y / 2 - p.Y / depth * f, depth)
end
-- The edge pointer for a world point seen at `sp` (WorldToViewportPoint's x, y; z <= 0 when it is behind you) on a
-- `view` sized screen (px). Returns nil while the point is well on screen, else { X, Y, Angle (degrees, 0 = pointing
-- right, clockwise) }: on the screen's edge (Edge.Margin in from it) on the line from the centre toward the point.
function GuideArrow.edge(sp, view, margin)
	if typeof(sp) ~= 'Vector3' or typeof(view) ~= 'Vector2' or view.X < 2 or view.Y < 2 then return nil end
	local E = GuideArrow.Edge
	margin = margin or E.Margin
	local behind = sp.Z <= 0
	local pad = E.OnScreenPad
	if not behind and sp.X >= pad and sp.X <= view.X - pad and sp.Y >= pad and sp.Y <= view.Y - pad then return nil end
	local cx, cy = view.X / 2, view.Y / 2
	local dx, dy = sp.X - cx, sp.Y - cy
	if behind then dx, dy = -dx, -dy end -- (behind you the projection is mirrored)
	if behind and math.abs(dy) < 1 and math.abs(dx) < 1 then dx, dy = 0, 1 end
	if behind then dy = math.max(dy, math.abs(dx) * 0.35) end -- (behind you: it points down and round, the way to turn)
	if math.abs(dx) < 1e-6 and math.abs(dy) < 1e-6 then dx = 1 end
	local hx, hy = math.max(1, cx - margin), math.max(1, cy - margin)
	local t = math.min(hx / math.max(math.abs(dx), 1e-6), hy / math.max(math.abs(dy), 1e-6))
	return { X = cx + dx * t, Y = cy + dy * t, Angle = math.deg(math.atan2(dy, dx)) }
end

---------------------------------------------------------------------------------------------- the parts (client)
-- Makes the arrow's parts in `parent` (a Model: its Highlight outlines them). Returns { [name] = part }.
function GuideArrow.build(parent)
	local col = GuideArrow.Colors
	local parts = {}
	for name, spec in GuideArrow.layout(1) do
		local p = Instance.new(spec.Kind == 'Wedge' and 'WedgePart' or 'Part')
		p.Name = name
		p.Anchored, p.CanCollide, p.CastShadow = true, false, false
		pcall(function() p.CanQuery, p.CanTouch = false, false end)
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Size = spec.Size
		local ink = name:sub(1, 9) == 'ArrowBack'
		p.Color = ink and col.Ink or (name == 'ArrowCap' or name == 'ArrowLip') and col.Top or name == 'ArrowShine' and col.Shine or col.Fill
		p.Transparency = 1
		p.Parent = parent
		parts[name] = p
	end
	return parts
end
-- Lays the arrow with its tip at `tip`, facing `face` (a flat unit vector toward the camera), at scale k.
local UP = Vector3.new(0, 1, 0)
function GuideArrow.lay(parts, tip, face, k)
	local right = UP:Cross(face).Unit
	local frame = CFrame.fromMatrix(tip, right, UP, face) -- (the arrow's own frame: x right, y up, z toward you)
	for name, spec in GuideArrow.layout(k) do
		local p = parts[name]
		if p then
			local at = frame:PointToWorldSpace(spec.Pos)
			if p.Size ~= spec.Size then p.Size = spec.Size end
			if spec.Kind == 'Wedge' then
				-- (a wedge's right angle sits at its local (-Y, +Z) corner: local +Y points down to the tip, local +Z
				-- toward the centre line, so the right angle is at the top of the centre line)
				local y, z = -UP, right * -spec.Side
				p.CFrame = CFrame.fromMatrix(at, y:Cross(z), y, z)
			else
				p.CFrame = CFrame.fromMatrix(at, right, UP)
			end
		end
	end
end
-- Shows the arrow at opacity a (0..1); the shine stays soft. Returns the opacity it set (rounded to 5 % steps).
function GuideArrow.setAlpha(parts, a, last)
	a = math.floor(math.clamp(a, 0, 1) * 20 + 0.5) / 20
	if a == last then return a end
	for name, p in parts do
		p.Transparency = 1 - a * (name == 'ArrowShine' and 0.8 or 1)
	end
	return a
end

return GuideArrow
