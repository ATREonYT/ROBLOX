--[[
	Player to player touch, measured on the real bodies (owner, Oct 19: "make the player to player touch WAY MORE
	accurate"). A catch counts only when the knife's reach overlaps one of the runner's own body parts:
	  - the reach is a box in front of the catcher (or along their leap): from their middle out to Reach studs,
	    Width across, body tall (Config/Round Stab / Lunge Reach and Width);
	  - the body is the runner's limbs, torso and head (R15 or R6), never hats, hair, wings or the knife on their
	    back (those used to count, and some are huge);
	  - the two boxes must overlap, give or take Config/Round.Touch.Tolerance (the separating-axis test).
	The catcher's screen (Gameplay/HitCheck), the server (RoundService.stabNear, with HuzzServer/HitHistory for lag)
	and the spec (tests/TouchHit.spec.luau) all use this one rule. Pure maths: no Instances are made here.
	verify(): the server's check of a hit the catcher's screen saw, on exactly where that screen showed both bodies
	(Oct 19 "pinpoint precise"; measured with tools/sim/touch_lag.luau).
]]
local TouchHit = {}

-- The body parts that count, by name (R15 and R6). Anything else on a character (accessory handles, the worn knife,
-- effects) never counts.
TouchHit.BODY = {
	Head = true, UpperTorso = true, LowerTorso = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
	RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
	RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
	Torso = true, ["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true,
}

function TouchHit.isBody(name: string): boolean
	return TouchHit.BODY[name] == true
end

-- The knife's reach: a box from the catcher's middle out along `dir` (flat; default: where the root faces) to
-- `reach` studs, `width` across, `height` tall (default 7: from under the feet to over the head of a standard body),
-- centred on the root's height. Returns the box's CFrame and size.
function TouchHit.reachBox(rootCF: CFrame, dir: Vector3?, reach: number, width: number, height: number?): (CFrame, Vector3)
	local way = dir or rootCF.LookVector
	local flat = Vector3.new(way.X, 0, way.Z)
	if flat.Magnitude < 1e-3 then
		local look = rootCF.LookVector
		flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 1e-3 then
			flat = Vector3.new(0, 0, -1)
		end
	end
	flat = flat.Unit
	local right = Vector3.new(-flat.Z, 0, flat.X)
	local at = rootCF.Position + flat * (reach / 2)
	-- (columns: right, up, back: a CFrame looking along `flat`)
	local cf = CFrame.fromMatrix(at, right, Vector3.new(0, 1, 0), -flat)
	return cf, Vector3.new(width, height or 7, reach)
end

local function axes(cf: CFrame)
	return { cf.RightVector, cf.UpVector, -cf.LookVector }
end

-- Do two boxes overlap (or come within `tolerance` studs of it)? The separating-axis test: two boxes are apart only
-- if some axis (one of their 6 face normals or 9 edge crossings) puts a gap between their shadows.
function TouchHit.overlap(aCF: CFrame, aSize: Vector3, bCF: CFrame, bSize: Vector3, tolerance: number?): boolean
	local tol = tolerance or 0
	local A, B = axes(aCF), axes(bCF)
	local ha = { aSize.X / 2 + tol, aSize.Y / 2 + tol, aSize.Z / 2 + tol }
	local hb = { bSize.X / 2, bSize.Y / 2, bSize.Z / 2 }
	local d = bCF.Position - aCF.Position
	local function apart(L: Vector3): boolean
		local m = L.Magnitude
		if m < 1e-6 then
			return false -- (parallel edges: no new axis)
		end
		L = L / m
		local ra = math.abs(A[1]:Dot(L)) * ha[1] + math.abs(A[2]:Dot(L)) * ha[2] + math.abs(A[3]:Dot(L)) * ha[3]
		local rb = math.abs(B[1]:Dot(L)) * hb[1] + math.abs(B[2]:Dot(L)) * hb[2] + math.abs(B[3]:Dot(L)) * hb[3]
		return math.abs(d:Dot(L)) > ra + rb
	end
	for i = 1, 3 do
		if apart(A[i]) or apart(B[i]) then
			return false
		end
	end
	for i = 1, 3 do
		for j = 1, 3 do
			if apart(A[i]:Cross(B[j])) then
				return false
			end
		end
	end
	return true
end

-- A body standing at rootCF when its parts can't be read (a stand-in body: the simulation, a body still loading):
-- one box the size of a standard R15 body, feet on the floor under the root.
function TouchHit.standIn(rootCF: CFrame): { { cf: CFrame, size: Vector3 } }
	return { { cf = rootCF * CFrame.new(0, -0.35, 0), size = Vector3.new(2, 5.3, 1) } }
end

-- The body's parts as { cf, size } relative to its root (from the parts as they are now); `parts` is a list of
-- { Name, CFrame, Size } (BaseParts or tables). Nil when none of them is a body part.
function TouchHit.shape(rootCF: CFrame, parts: { any }): { { cf: CFrame, size: Vector3 } }?
	local out = {}
	local inv = rootCF:Inverse()
	for _, p in parts do
		-- (a real Instance must be a part before .Size can be read: a Humanoid has none)
		local isPart = typeof(p) ~= "Instance" or p:IsA("BasePart")
		if TouchHit.isBody(p.Name) and isPart and typeof(p.Size) == "Vector3" and typeof(p.CFrame) == "CFrame" then
			table.insert(out, { cf = inv * p.CFrame, size = p.Size })
		end
	end
	return if #out > 0 then out else nil
end

-- How far a point is from a path of CFrames (the closest point on the straight pieces between them), in studs.
function TouchHit.pathDistance(p: Vector3, path: { CFrame }): number
	local best = math.huge
	for i = 1, #path do
		local a = path[i].Position
		local b = if i < #path then path[i + 1].Position else a
		local ab = b - a
		local len2 = ab:Dot(ab)
		local k = if len2 > 1e-9 then math.clamp((p - a):Dot(ab) / len2, 0, 1) else 0
		best = math.min(best, (a + ab * k - p).Magnitude)
	end
	return best
end

-- The point of a body's server path (samples { t, cf }, oldest first) closest to `p`, no earlier than time `from`:
-- (distance, the body's CFrame there, its time); nil when the path has nothing that late.
function TouchHit.closest(path, p: Vector3, from: number): (number, CFrame?, number?)
	local best, at, atT = math.huge, nil, nil
	for i = 1, #path do
		local a = path[i]
		local b = path[i + 1] or a
		if b.t >= from then
			local ab = b.cf.Position - a.cf.Position
			local len2 = ab:Dot(ab)
			local k = if len2 > 1e-9 then math.clamp((p - a.cf.Position):Dot(ab) / len2, 0, 1) else 0
			if a.t + (b.t - a.t) * k < from then
				k = math.clamp((from - a.t) / math.max(b.t - a.t, 1e-6), 0, 1)
			end
			local cf = a.cf:Lerp(b.cf, k)
			local d = (cf.Position - p).Magnitude
			if d < best then
				best, at, atT = d, cf, a.t + (b.t - a.t) * k
			end
		end
	end
	return best, at, atT
end

-- How far back a catcher's screen shows the runners: the server's copy reaches them half a round trip late, is drawn
-- a little later still (Roblox's smoothing), and their claim takes the other half back. `ping` is
-- Player:GetNetworkPing() (taken as the round trip; + 0.05 s in case it is one way), capped at T.MaxRewind.
function TouchHit.lookBack(ping: number, T): number
	return math.clamp(ping + T.Smoothing + 0.05, 0, T.MaxRewind)
end

--[[ A hit the catcher's screen saw, checked by the server (owner, Oct 19: "make the player to player interactions
	pinpoint precise ... so people dont die and start compalining"). What counts is what that screen showed:
	claim.seen = the runner's root as the catcher's screen drew it, claim.mine = the catcher's own root then. Every
	number in the claim comes from a client, so the server ties it to its own history (a critic's cheat test, Oct 19:
	the first version let a cheater stab behind him and reach 9 to 12 studs):
	  - ONE moment for the runner: the point on the runner's server path (ctx.runner, { t, cf } samples) closest to
	    seen, no further back than ctx.back seconds (the catcher's own round trip plus Roblox's smoothing, at most
	    T.MaxRewind) and within T.SeenSlack studs. The runner's body is turned as the server had it then (seen's own
	    turn is ignored);
	  - the catcher is where they are now: mine within T.MineSlack of the catcher's last T.MineBack seconds on the
	    server, or of where they will be T.Lead seconds on at their speed (a client is a packet ahead of the server:
	    a dive moves 72 studs/s);
	  - the knife points the way the server has the catcher facing (ctx.face), or along the leap (ctx.along); a
	    claimed facing is used only within T.FaceSlack degrees of that;
	  - the screen's touch: the knife's box from mine touches the runner's body at seen (T.Tolerance);
	  - the cap: the same box from the server's own catcher (now, or T.Lead on) touches the runner's body where the
	    server had it at that moment, give or take T.Tolerance + T.CapSlack. So no claim reaches further than an
	    honest one by more than CapSlack studs.
	  - claim.ahead (optional, Oct 22): the screen drew the runner that far ahead of seen (Gameplay/OthersAhead): see
	    below; the moment moves on along the runner's real path, never past it.
	ctx = { runner, catcher, now, back, shape, knife, along?, face?, vel? }. Returns (ok, why). ]]
function TouchHit.verify(claim, ctx, T): (boolean, string)
	if type(claim) ~= "table" or typeof(claim.seen) ~= "CFrame" or typeof(claim.mine) ~= "CFrame" then
		return false, "bad claim"
	end
	local seen, mine = claim.seen.Position, claim.mine.Position
	if seen ~= seen or mine ~= mine or claim.mine.LookVector ~= claim.mine.LookVector then
		return false, "bad claim" -- (NaN)
	end
	local runner, catcher, now = ctx.runner, ctx.catcher, ctx.now
	if #runner == 0 or #catcher == 0 then
		return false, "no history"
	end
	-- the runner's one moment: the closest point to seen on their path over the last `back` seconds
	local from = now - math.min(ctx.back, T.MaxRewind)
	local best, at, atT = TouchHit.closest(runner, seen, from)
	if not at or best > T.SeenSlack then
		return false, "runner never there"
	end
	-- Drawn ahead (Gameplay/OthersAhead, Oct 22: the screen draws others ahead along their movement, about where we
	-- have them now; claim.ahead = how far, seen = their root as Roblox had it there). The runner's moment moves on to
	-- the point of their real path after `at` closest to where the screen drew them, and the touch is tested where it
	-- drew them; if that guess went off their path (a sharp turn), where they really were. Never further than
	-- T.AheadMax studs, and always a point of our own history, so it can't reach anywhere the runner never went.
	local drawn = seen
	local ahead = claim.ahead
	if typeof(ahead) == "Vector3" and ahead == ahead then
		local flat = Vector3.new(ahead.X, 0, ahead.Z)
		if flat.Magnitude > (T.AheadMax or 0) then
			flat = if flat.Magnitude > 1e-6 then flat.Unit * (T.AheadMax or 0) else Vector3.zero
		end
		if flat.Magnitude > 0.05 then
			local want = seen + flat
			local d2, at2 = TouchHit.closest(runner, want, atT)
			if at2 then
				at = at2
				drawn = if d2 <= T.SeenSlack then want else at2.Position
			end
		end
	end
	-- the catcher now (the server's newest), and a packet on at their speed
	local latest = catcher[#catcher].cf
	local lead = latest + (ctx.vel or Vector3.zero) * T.Lead
	local path = {}
	for _, s in catcher do
		if s.t >= now - T.MineBack then
			table.insert(path, s.cf)
		end
	end
	table.insert(path, latest)
	table.insert(path, lead)
	if TouchHit.pathDistance(mine, path) > T.MineSlack then
		return false, "catcher never there"
	end
	-- which way the knife points: along the leap, or the claimed facing within FaceSlack of the server's
	local dir = ctx.along
	if not dir then
		local face = ctx.face or latest.LookVector
		local f = Vector3.new(face.X, 0, face.Z)
		local c = Vector3.new(claim.mine.LookVector.X, 0, claim.mine.LookVector.Z)
		if f.Magnitude < 1e-3 then
			f = Vector3.new(0, 0, -1)
		end
		dir = f.Unit
		if c.Magnitude > 1e-3 then
			local a0, a1 = math.atan2(-f.X, -f.Z), math.atan2(-c.X, -c.Z)
			local d = (a1 - a0 + math.pi) % (2 * math.pi) - math.pi
			local lim = math.rad(T.FaceSlack)
			local a = a0 + math.clamp(d, -lim, lim)
			dir = Vector3.new(-math.sin(a), 0, -math.cos(a))
		end
	end
	-- the screen's touch, with the runner turned as the server had them
	local seenCF = CFrame.new(drawn) * at.Rotation
	local boxCF, boxSize = TouchHit.reachBox(CFrame.new(mine), dir, ctx.knife.Reach, ctx.knife.Width)
	if not TouchHit.touches(boxCF, boxSize, seenCF, ctx.shape, T.Tolerance) then
		return false, "no touch"
	end
	-- the cap: from the server's own catcher, to the runner where the server had them at that moment
	for _, c in { latest, lead } do
		local capCF, capSize = TouchHit.reachBox(CFrame.new(c.Position), dir, ctx.knife.Reach, ctx.knife.Width)
		if TouchHit.touches(capCF, capSize, at, ctx.shape, T.Tolerance + T.CapSlack) then
			return true, "hit"
		end
	end
	return false, "too far"
end

-- Does the reach box touch a body whose shape (TouchHit.shape, relative to its root) stands at rootCF?
function TouchHit.touches(boxCF: CFrame, boxSize: Vector3, rootCF: CFrame, shape: { { cf: CFrame, size: Vector3 } }, tolerance: number?): boolean
	for _, p in shape do
		if TouchHit.overlap(boxCF, boxSize, rootCF * p.cf, p.size, tolerance) then
			return true
		end
	end
	return false
end

return TouchHit
