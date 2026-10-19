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

--[[ A hit the catcher's screen saw, checked by the server (owner, Oct 19: "make the player to player interactions
	pinpoint precise ... so people dont die and start compalining"). What counts is exactly what that screen showed:
	claim.seen = the runner's root as the catcher's screen drew it, claim.mine = the catcher's own root then. The
	server only checks it was really possible:
	  - seen lies on the runner's real path over the last T.MaxRewind seconds (runnerPath, from HuzzServer/HitHistory),
	    within T.SeenSlack studs (a screen draws a body between the network's snapshots of that path);
	  - mine lies on the catcher's own path within T.MineSlack;
	  - the knife's box from mine (along `along`, else the way mine faces) touches the runner's body at seen.
	So a lagging screen's fair hit counts, and nobody is caught where no screen ever showed them, nor where they were
	more than MaxRewind seconds ago. Returns (ok, why) for the notes and the spec. ]]
function TouchHit.verify(claim, runnerPath: { CFrame }, catcherPath: { CFrame }, shape, knife, along: Vector3?, T): (boolean, string)
	if type(claim) ~= "table" or typeof(claim.seen) ~= "CFrame" or typeof(claim.mine) ~= "CFrame" then
		return false, "bad claim"
	end
	local seen, mine = claim.seen, claim.mine
	if seen.Position ~= seen.Position or mine.Position ~= mine.Position then
		return false, "bad claim" -- (NaN)
	end
	if #runnerPath == 0 or TouchHit.pathDistance(seen.Position, runnerPath) > T.SeenSlack then
		return false, "runner never there"
	end
	if #catcherPath == 0 or TouchHit.pathDistance(mine.Position, catcherPath) > T.MineSlack then
		return false, "catcher never there"
	end
	local boxCF, boxSize = TouchHit.reachBox(mine, along, knife.Reach, knife.Width)
	if not TouchHit.touches(boxCF, boxSize, seen, shape, T.Tolerance) then
		return false, "no touch"
	end
	return true, "hit"
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
