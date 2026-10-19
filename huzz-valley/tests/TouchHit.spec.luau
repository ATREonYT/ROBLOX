-- lune run tests/TouchHit.spec.luau
-- Player to player touch on the real bodies (Shared/TouchHit; owner, Oct 19: "make the player to player touch WAY MORE
-- accurate"). A standard R15 runner (the preview rig's parts) stands in front of a catcher:
--   - the knife's box (Config/Round Stab Reach x Width) hits a runner whose chest is within the knife's reach, and
--     misses one a stud past it, one beside the catcher's shoulder, and one behind;
--   - hats, hair and the knife on the back never count (only limbs, torso and head);
--   - the old rules hit from much further (the server took any claim within Range + Slack = 11.5 studs, the bot hit
--     from 5 studs all round, the catcher's screen box was 5.5 x 4 and counted accessories): printed for the notes;
--   - the overlap test agrees with a brute-force point check on turned boxes;
--   - a runner who crossed the box a moment ago counts when the server looks back that far (lag), not otherwise.
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Env = require("../tools/preview/motion3d/env")
local Rig = require("../tools/preview/motion3d/rig")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local TouchHit = Env.load(SHARED .. "TouchHit.lua")
local Round = Env.load(SHARED .. "Config/Round.lua")
local S, L, T = Round.Stab, Round.Lunge, Round.Touch

local failed, passed = 0, 0
local function check(ok, what)
	if ok then passed += 1 else failed += 1; print("FAIL " .. what) end
end

-- A runner's body: the preview's standard R15 rig standing at `at`, turned `yaw` radians.
local function body(at: Vector3, yaw: number?)
	local rig = Rig.r15("R")
	rig.root.CFrame = CFrame.new(at.X, Rig.REST_HEIGHT, at.Z) * CFrame.Angles(0, yaw or 0, 0)
	Rig.fk(rig)
	local parts = {}
	for name, p in rig.parts do
		table.insert(parts, { Name = name, CFrame = p.CFrame, Size = p.Size })
	end
	return rig.root.CFrame, parts
end

local catcher = CFrame.new(0, Rig.REST_HEIGHT, 0) -- facing -Z
local boxCF, boxSize = TouchHit.reachBox(catcher, nil, S.Reach, S.Width)
local function hits(at: Vector3, yaw: number?, extra)
	local rootCF, parts = body(at, yaw)
	for _, e in extra or {} do table.insert(parts, e) end
	local shape = assert(TouchHit.shape(rootCF, parts))
	return TouchHit.touches(boxCF, boxSize, rootCF, shape, T.Tolerance)
end

-- The runner's chest is 0.5 in front of their root (a standard torso is 1 deep): reach is from the catcher's middle.
local reachRoot = S.Reach + 0.5 -- root to root at the very tip
check(hits(Vector3.new(0, 0, -(reachRoot - 0.3))), "a runner just inside the knife's reach is hit")
check(not hits(Vector3.new(0, 0, -(reachRoot + T.Tolerance + 0.6))), "a stud past the tip is a miss")
check(hits(Vector3.new(1.2, 0, -3)), "a runner a little to the side, in front, is hit")
check(not hits(Vector3.new(3.4 + S.Width / 2, 0, -2)), "a runner off beside the catcher's shoulder is a miss")
check(not hits(Vector3.new(0, 0, 3)), "a runner behind the catcher is a miss")
check(not hits(Vector3.new(0, 0, -(reachRoot + 2))), "the old screen box's reach (5.5 + accessories) is a miss now")
-- a hat a stud above and a wide accessory sticking out toward the catcher: they don't count
local far = Vector3.new(0, 0, -(reachRoot + 1.5))
local rootFar = body(far)
local wings = { Name = "Handle", CFrame = rootFar * CFrame.new(0, 1, 1.6), Size = Vector3.new(6, 4, 3) }
check(not hits(far, 0, { wings }), "big wings or hair reaching into the box don't count (only the body does)")
check(TouchHit.isBody("LeftHand") and TouchHit.isBody("Torso") and not TouchHit.isBody("Handle") and not TouchHit.isBody("HumanoidRootPart"),
	"body parts are limbs, torso and head (R15 and R6); never a Handle or the root")

-- The leap's box points along the leap (sideways leaps hit to that side).
local sideCF, sideSize = TouchHit.reachBox(catcher, Vector3.new(1, 0, 0), L.Reach, L.Width)
local sideRoot, sideParts = body(Vector3.new(4.5, 0, 0))
check(TouchHit.touches(sideCF, sideSize, sideRoot, assert(TouchHit.shape(sideRoot, sideParts)), T.Tolerance), "a sideways leap's box hits to that side")
check(not TouchHit.touches(boxCF, boxSize, sideRoot, assert(TouchHit.shape(sideRoot, sideParts)), T.Tolerance), "and the forward box doesn't")

-- The overlap test against brute force: random turned boxes, compared with sampling points of one inside the other.
math.randomseed(5)
local rng = { NextNumber = function(_, a, b) return a + (b - a) * math.random() end }
local agree, total = 0, 0
local function inside(cf, size, p)
	local q = cf:PointToObjectSpace(p)
	return math.abs(q.X) <= size.X / 2 and math.abs(q.Y) <= size.Y / 2 and math.abs(q.Z) <= size.Z / 2
end
for _ = 1, 300 do
	local a = CFrame.new(rng:NextNumber(-2, 2), rng:NextNumber(-2, 2), rng:NextNumber(-2, 2)) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6))
	local b = CFrame.new(rng:NextNumber(-2, 2), rng:NextNumber(-2, 2), rng:NextNumber(-2, 2)) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6))
	local sa, sb = Vector3.new(rng:NextNumber(0.5, 2), rng:NextNumber(0.5, 2), rng:NextNumber(0.5, 2)), Vector3.new(rng:NextNumber(0.5, 2), rng:NextNumber(0.5, 2), rng:NextNumber(0.5, 2))
	local found = false
	for _ = 1, 4000 do
		local p = b * Vector3.new(rng:NextNumber(-0.5, 0.5) * sb.X, rng:NextNumber(-0.5, 0.5) * sb.Y, rng:NextNumber(-0.5, 0.5) * sb.Z)
		if inside(a, sa, p) then found = true break end
	end
	local sat = TouchHit.overlap(a, sa, b, sb)
	total += 1
	-- (sampling can miss a sliver of overlap, never invent one)
	if sat == found or (sat and not found) then agree += 1 end
	if found and not sat then print("  overlap said apart, a point was inside both") end
end
check(agree == total, string.format("the overlap test never calls touching boxes apart (%d/%d)", agree, total))

-- Lag: the runner crossed the box 0.15 s ago and has run on 4 studs since.
local pastRoot, pastParts = body(Vector3.new(0, 0, -3.5))
local nowRoot = pastRoot * CFrame.new(4.2, 0, 0)
local shape = assert(TouchHit.shape(pastRoot, pastParts))
local function anyTouch(list)
	for _, at in list do
		if TouchHit.touches(boxCF, boxSize, at, shape, T.Tolerance) then return true end
	end
	return false
end
check(anyTouch({ pastRoot, nowRoot }), "a runner the catcher's screen showed in the box counts when the server looks back that far")
check(not anyTouch({ nowRoot }), "but not from where they are now (no look back = no catch)")
check(T.MaxRewind <= 0.4 and T.Smoothing <= 0.15 and T.Tolerance <= 0.5, "the look back is capped (0.35 s) and the give is small (half a stud)")

-- Pinpoint (owner, Oct 19: "make the player to player interactions pinpoint precise"): the server judges what the
-- catcher's screen showed (TouchHit.verify), tied to one moment of its own history, the knife pointing the way the
-- server has the catcher facing, the reach capped (a critic's cheat test: the first version reached 9 to 12 studs).
do
	-- a path of { t, cf } samples from `from` to `to` over the last `seconds` (now = 1)
	local function path(from: Vector3, to: Vector3, seconds: number?)
		local out, n = {}, 12
		for i = 0, n do
			local p = from:Lerp(to, i / n)
			table.insert(out, { t = 1 - (seconds or 0.3) * (1 - i / n), cf = CFrame.new(p.X, Rig.REST_HEIGHT, p.Z) })
		end
		return out
	end
	local still = { { t = 0.7, cf = catcher }, { t = 1, cf = catcher } }
	local _, parts = body(Vector3.zero)
	local shape = assert(TouchHit.shape(CFrame.new(0, Rig.REST_HEIGHT, 0), parts))
	local function judge(claim, runner, extra)
		local ctx = { runner = runner, catcher = still, now = 1, back = 0.3, shape = shape, knife = S, face = catcher.LookVector }
		for k, v in extra or {} do ctx[k] = v end
		return TouchHit.verify(claim, ctx, T)
	end
	-- the runner ran past in front of the catcher over the last 0.3 s; the catcher stood still
	local across = path(Vector3.new(-6, 0, -3.5), Vector3.new(6, 0, -3.5))
	local seen = CFrame.new(0.5, Rig.REST_HEIGHT, -3.5)
	local ok, why = judge({ seen = seen, mine = catcher }, across)
	check(ok, "a hit the screen showed, on the runner's real path: counts (" .. why .. ")")
	ok, why = judge({ seen = seen * CFrame.Angles(0, math.rad(90), 0), mine = catcher }, across)
	check(ok, "the runner's turn comes from the server, so a turned claim changes nothing (" .. why .. ")")
	ok, why = judge({ seen = CFrame.new(0.5, Rig.REST_HEIGHT, -1.2), mine = catcher }, across)
	check(not ok and why == "runner never there", "a runner 2.3 studs off anywhere they really were: no (" .. why .. ")")
	ok, why = judge({ seen = seen, mine = catcher * CFrame.new(0, 0, -3) }, across)
	check(not ok and why == "catcher never there", "a catcher claiming to stand 3 studs closer than he is: no (" .. why .. ")")
	ok, why = judge({ seen = CFrame.new(0, Rig.REST_HEIGHT, -9), mine = catcher }, path(Vector3.new(-6, 0, -9), Vector3.new(6, 0, -9)))
	check(not ok and why == "no touch", "a runner the knife can't reach on the screen either: no (" .. why .. ")")
	ok, why = judge({ seen = "x", mine = catcher }, across)
	check(not ok and why == "bad claim", "rubbish from a client is refused")
	local nan = 0 / 0
	ok = judge({ seen = CFrame.new(nan, nan, nan), mine = catcher }, across)
	check(not ok, "and so is NaN")
	-- the critic's cheats
	local behindPath = path(Vector3.new(-6, 0, 3.5), Vector3.new(6, 0, 3.5))
	local behind = CFrame.new(0.5, Rig.REST_HEIGHT, 3.5)
	ok, why = judge({ seen = behind, mine = catcher * CFrame.Angles(0, math.pi, 0) }, behindPath)
	check(not ok, "a catcher claiming to face backward can't stab the runner behind him (" .. why .. ")")
	ok, why = judge({ seen = seen, mine = catcher * CFrame.Angles(0, math.rad(30), 0) }, across)
	check(ok, "a claimed facing within FaceSlack of the server's is fine (" .. why .. ")")
	local farStill = { { t = 0.7, cf = CFrame.new(0, Rig.REST_HEIGHT, -7) }, { t = 1, cf = CFrame.new(0, Rig.REST_HEIGHT, -7) } }
	ok, why = judge({ seen = CFrame.new(0, Rig.REST_HEIGHT, -7), mine = catcher }, farStill)
	check(not ok, "a runner standing 7 studs ahead is out of an honest reach (" .. why .. ")")
	ok, why = judge({ seen = CFrame.new(0, Rig.REST_HEIGHT, -5.6), mine = CFrame.new(0, Rig.REST_HEIGHT, -1.4) }, farStill)
	check(not ok and why == "too far", "and a claim moving both bodies 1.4 studs closer can't reach him (" .. why .. ")")
	-- one moment: the runner crossed 0.3 s ago; a low-ping screen can't have shown that
	local crossedEarly = path(Vector3.new(-6, 0, -3.5), Vector3.new(6, 0, -3.5), 0.3)
	for _, s in crossedEarly do s.t -= 0.25 end
	table.insert(crossedEarly, { t = 1, cf = crossedEarly[#crossedEarly].cf })
	ok, why = judge({ seen = CFrame.new(-6, Rig.REST_HEIGHT, -3.5) * CFrame.new(0, 0, 0), mine = catcher }, crossedEarly, { back = 0.15 })
	check(not ok and why == "runner never there", "a runner where they were 0.55 s ago, from a low-ping screen: no (" .. why .. ")")
	-- a dive: the catcher's screen is a packet ahead of the server at 72 studs/s
	local diving = { { t = 0.9, cf = CFrame.new(0, Rig.REST_HEIGHT, 7.2) }, { t = 1, cf = catcher } }
	local ahead = catcher * CFrame.new(0, 0, -2.4)
	local diveSeen = CFrame.new(0, Rig.REST_HEIGHT, -6.5)
	local diveRunner = { { t = 0.7, cf = diveSeen }, { t = 1, cf = diveSeen } }
	ok, why = judge({ seen = diveSeen, mine = ahead }, diveRunner,
		{ catcher = diving, knife = L, along = Vector3.new(0, 0, -1), vel = Vector3.new(0, 0, -72) })
	check(ok, "a fair dive hit with the screen 2.4 studs ahead of the server counts (" .. why .. ")")
	ok, why = judge({ seen = diveSeen, mine = ahead }, diveRunner,
		{ catcher = diving, knife = L, along = Vector3.new(0, 0, -1), vel = Vector3.zero })
	check(not ok, "but not from a catcher standing still (" .. why .. ")")
	check(math.abs(TouchHit.pathDistance(Vector3.new(0, Rig.REST_HEIGHT, -2), { across[1].cf, across[#across].cf }) - 1.5) < 1e-4,
		"the distance to a path is to its nearest piece")
	check(math.abs(TouchHit.lookBack(0.05, T) - 0.2) < 1e-6 and TouchHit.lookBack(2, T) == T.MaxRewind,
		"the look back follows the catcher's ping, capped at MaxRewind")
	check(T.SeenSlack <= 2 and T.MineSlack <= 2 and T.CapSlack <= 1 and T.FaceSlack <= 45 and T.MaxRewind <= 0.4,
		"the give is small: 2 studs off the real paths, 1 stud past an honest reach, 45 degrees of facing, 0.4 s back at most")
end

-- For the notes: how close bodies must be, then and now (straight ahead, studs between the two bodies' fronts).
local gapNow = S.Reach + T.Tolerance - 0.5
print(string.format("  touch: the knife reaches %.1f studs past the catcher's chest now (screen box was 5.5 from the middle with accessories; the server took 11.5 root to root, the bot 5 all round)", gapNow))

print(`TouchHit: {passed} ok, {failed} failed`)
if failed > 0 then
	error("TouchHit spec failed")
end
