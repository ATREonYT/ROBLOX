-- How far apart two screens are, and what the server's catch rules make of it (owner, Oct 19: "make the player to
-- player interactions pinpoint precise. For example make them all be in the same spots on everyones screen ... so
-- people dont die and start compalining"). A model of Roblox's network, not Roblox itself:
--   - a runner zigzags at 28 studs/s with a huss now and then; a catcher chases at 30 and swings the moment the
--     runner's body is inside the knife's reach ON THE CATCHER'S SCREEN (Gameplay/HitCheck);
--   - each client owns its own body and sends it 30 times a second; a packet takes half that player's ping
--     (+ up to 10 ms jitter) to the server, and the server's copy takes half the other player's ping on to them;
--   - a screen draws other bodies Interp seconds behind the newest packet, blending between packets (Roblox's
--     interpolation; ~0.05 s is a guess: Roblox doesn't publish it);
--   - the server keeps 60 samples a second of where it has each body (HuzzServer/HitHistory).
-- Then it compares the server rules on every hit the catcher's screen saw:
--   OLD (Oct 19 batch 1; still the fallback and what old clients get): the box from where the server has the catcher
--       NOW, against the runner anywhere in the last ping/2 + 0.1 s, re-checked for 0.25 s after the claim arrives;
--   claim (Shared/TouchHit.verify): the box from where the catcher's screen had itself, against the runner where
--       that screen showed them, tied to one moment of the server's own history and capped (Config/Round.Touch);
--   NOW (RoundService.screenHit): the claim, or the OLD test when the claim fails.
-- Dive rows: the catcher chases at a dive's 72 studs/s the whole time, the knife along the dive (the worst case for
-- "the catcher's screen is a packet ahead of the server").
-- Then the cheat test: a catcher sending any claim he likes (how far can he reach? can he stab behind him?).
-- And how far the runner really was, on their own screen, from where the catcher's screen showed them at the swing
-- (the "I wasn't even near him" gap no rule can remove: it comes from the network).
-- lune run huzz-valley/tools/sim/touch_lag.luau   (repo root)
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Env = require("../preview/motion3d/env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local TouchHit = Env.load(SHARED .. "TouchHit.lua")
local Round = Env.load(SHARED .. "Config/Round.lua")
local S, T = Round.Stab, Round.Touch
-- Roblox's CFrame.lookAt, flat (Lune 0.10.5's faces the other way along Z: round_sim.luau has the same helper).
local function lookAt(pos, target)
	local d = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
	if d.Magnitude < 1e-4 then
		return CFrame.new(pos)
	end
	return CFrame.new(pos) * CFrame.Angles(0, math.atan2(-d.X, -d.Z), 0)
end

local SEND, INTERP, SIM = 1 / 30, 0.05, 1 / 240

local seed = 12345
local function rand()
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end

-- One body's true path, sampled every SIM step: { t, cf }.
local function runnerPath(seconds)
	local out, pos, heading, nextTurn, hussUntil, hussDir = {}, Vector3.new(0, 3, 0), 0, 0.5, -1, nil
	local t = 0
	local turned = false
	while t <= seconds do
		turned = false
		if t >= nextTurn then
			turned = true
			heading += (rand() - 0.5) * 2.2
			nextTurn = t + 0.3 + rand() * 0.6
			if rand() < 0.25 then
				hussUntil, hussDir = t + 0.28, (if rand() < 0.5 then 1 else -1)
			end
		end
		local fwd = Vector3.new(math.sin(heading), 0, -math.cos(heading))
		local v = fwd * 28
		if t < hussUntil then
			local right = Vector3.new(-fwd.Z, 0, fwd.X) * hussDir
			local u = 1 - (hussUntil - t) / 0.28
			v += right * (16 + (120 - 16) * (1 - u) ^ 3)
		end
		pos += v * SIM
		-- (goal: the speed the keys ask for, Humanoid.MoveDirection x WalkSpeed; input: a key changed this step)
		table.insert(out, { t = t, cf = lookAt(pos, pos + fwd), vel = v, goal = fwd * 28, input = turned })
		t += SIM
	end
	return out
end

-- STAMP=1 (Gameplay/MotionStamps, Oct 23): each client also sends its own body's moment (server time, where, how fast,
-- the speed its keys ask for) 20 times a second and at once when a key changes; the server passes it straight on.
-- The other screen draws the body where that moment says it is now: from the stamp, moved on by exactly the time since
-- it was sent (both clocks are the server's), heading for the keys' speed (Shared/MotionStamps.predict).
local MotionStamps = Env.load(SHARED .. "MotionStamps.lua")
local function stampsOf(path, up, down, seconds)
	local out, last = {}, -1
	for i, s in path do
		if s.t - last >= MotionStamps.Config.Every or (s.input and s.t - last >= MotionStamps.Config.MinGap) then
			last = s.t
			local jitter = rand() * 0.01
			table.insert(out, { sent = s.t, arrives = s.t + up + down + jitter, p = s.cf.Position, v = s.vel, g = s.goal, push = false })
		end
	end
	return out
end
local function newestStamp(st, t)
	local best = nil
	for _, s in st do
		if s.arrives <= t then best = s else break end
	end
	return best
end

local function trueAt(path, t)
	local i = math.clamp(math.floor(t / SIM) + 1, 1, #path)
	return path[i].cf
end

-- The packets a client sends of its own body: { sent, arrives (at the server), cf, vel }.
local function packets(path, oneWay, seconds)
	local out = {}
	local t = 0
	while t <= seconds do
		local a, b = trueAt(path, t - SIM), trueAt(path, t)
		table.insert(out, { sent = t, arrives = t + oneWay + rand() * 0.01, cf = b, vel = (b.Position - a.Position) / SIM })
		t += SEND
	end
	return out
end

-- The newest packet the server has at time t.
local function serverPk(pk, t)
	local best = pk[1]
	for _, p in pk do
		if p.arrives <= t then best = p else break end
	end
	return best
end
local function serverAt(pk, t)
	return serverPk(pk, t).cf
end

-- Where another client's screen draws that body at time t: the server's copy reaches it `down` later, and it is drawn
-- INTERP behind the newest copy, blended between copies.
local function drawnAt(pk, t, down)
	local at = t - down - INTERP
	local prev = nil
	for _, p in pk do
		if p.arrives > at then
			if not prev then return p.cf end
			local k = math.clamp((at - prev.arrives) / math.max(p.arrives - prev.arrives, 1e-4), 0, 1)
			return prev.cf:Lerp(p.cf, k)
		end
		prev = p
	end
	return prev.cf
end

-- AHEAD=1 (Gameplay/OthersAhead, Oct 22): the screen draws others ahead along their movement by its half ping +
-- Round.Ahead.Interp (capped); the movement is what the drawn body did over the last ~1/Smooth s (the eased offset).
local AHEAD = require("@lune/process").env.AHEAD == "1"
local A = Round.Ahead
local STAMP = require("@lune/process").env.STAMP == "1"
local function drawnSeen(pk, t, myPing, st)
	local cf = drawnAt(pk, t, myPing / 2)
	if STAMP and st then
		local s = newestStamp(st, t)
		if s then
			local want = MotionStamps.predict(s, t - s.sent) - cf.Position
			local off = MotionStamps.limit(Vector3.new(want.X, 0, want.Z))
			return cf + off, off
		end
	end
	if not AHEAD then return cf, Vector3.zero end
	local w = 1 / A.Smooth
	local v = (cf.Position - drawnAt(pk, t - w, myPing / 2).Position) / w
	local flat = Vector3.new(v.X, 0, v.Z)
	if flat.Magnitude < 0.5 or flat.Magnitude > A.MaxSpeed then return cf, Vector3.zero end
	local off = flat * math.clamp(myPing / 2 + A.Interp, 0, A.MaxLead)
	if off.Magnitude > A.MaxStuds then off = off.Unit * A.MaxStuds end
	return cf + off, off
end

-- The server's history (HuzzServer/HitHistory): samples every 1/60 s of where it has the body, as { t, cf }.
local function history(pk, seconds)
	local out = {}
	local t = 0
	while t <= seconds do
		table.insert(out, { t = t, cf = serverAt(pk, t) })
		t += 1 / 60
	end
	return out
end
-- HitHistory.samples: the samples from `from` to `to`, and where the server has the body at `to`.
local function samples(hist, pk, from, to)
	local out = {}
	for _, h in hist do
		if h.t >= from - 1 / 60 and h.t <= to then table.insert(out, h) end
	end
	table.insert(out, { t = to, cf = serverAt(pk, to) })
	return out
end

local shape = TouchHit.standIn(CFrame.identity)

-- OLD (the server's own test, still the fallback and what old clients get): the box from where the server has the
-- catcher, against the runner anywhere in the last ping/2 + Smoothing, re-checked for 0.25 s after the claim arrives.
local function serverTest(cPk, rHist, catcherPing, arrive, knife, along)
	local back = math.clamp(catcherPing / 2 + T.Smoothing, 0, T.MaxRewind)
	local at = arrive
	while at <= arrive + 0.25 do
		local cNow = serverAt(cPk, at)
		local b, sz = TouchHit.reachBox(cNow, along, knife.Reach, knife.Width)
		for _, h in rHist do
			if h.t >= at - back and h.t <= at and TouchHit.touches(b, sz, h.cf, shape, T.Tolerance) then
				return true, h.cf
			end
		end
		at += 0.03
	end
	return false
end

-- speed: how fast the catcher chases (72 = a dive's speed the whole time, the worst case for "the catcher's screen
-- is a packet ahead of the server"); knife: Config/Round Stab or Lunge (a lunge's box points along the dive).
local function scenario(name, runnerPing, catcherPing, n, speed, knife)
	local seconds = 40
	local hits, oldOk, claimOk, newOk, newWhy = 0, 0, 0, 0, {}
	local gaps, oldPlace = {}, {}
	local trials = 0
	while hits < n and trials < 400 do
		trials += 1
		local rPath = runnerPath(seconds)
		local rPk = packets(rPath, runnerPing / 2, seconds)
		local rSt = stampsOf(rPath, runnerPing / 2, catcherPing / 2, seconds)
		-- the catcher chases where its screen shows the runner, facing them
		local cPath, cpos = {}, trueAt(rPath, 0).Position + Vector3.new(8, 0, 8)
		local t = 0
		while t <= seconds do
			local target = drawnSeen(rPk, t, catcherPing, rSt).Position
			local d = Vector3.new(target.X - cpos.X, 0, target.Z - cpos.Z)
			if d.Magnitude > 0.5 then cpos += d.Unit * math.min(speed * SIM, d.Magnitude - 0.5) end
			table.insert(cPath, { t = t, cf = lookAt(cpos, target) })
			t += SIM
		end
		local cPk = packets(cPath, catcherPing / 2, seconds)
		local rHist, cHist = history(rPk, seconds), history(cPk, seconds)
		-- the catcher's screen: swing at the first touch after 1 s, then once a second
		local nextSwing = 1
		t = 1
		while t < seconds - 1 and hits < n do
			if t >= nextSwing then
				local mine = trueAt(cPath, t)
				local seen, ahead = drawnSeen(rPk, t, catcherPing, rSt)
				local along = if knife == Round.Lunge then mine.LookVector else nil
				local box, size = TouchHit.reachBox(mine, along, knife.Reach, knife.Width)
				if TouchHit.touches(box, size, seen, shape, 0) then
					hits += 1
					nextSwing = t + 1
					local arrive = t + catcherPing / 2 + rand() * 0.01
					local okOld, place = serverTest(cPk, rHist, catcherPing, arrive, knife, along)
					if okOld then
						oldOk += 1
						table.insert(oldPlace, (place.Position - seen.Position).Magnitude)
					end
					-- NOW (RoundService.screenHit): the screen's claim; if it fails, the server's own test
					local back = TouchHit.lookBack(catcherPing, T)
					local newest = serverPk(cPk, arrive)
					local rS = samples(rHist, rPk, arrive - T.Keep, arrive)
					if STAMP then
						-- (the server's newest stamp of the runner moved on to the claim's moment: RoundService.screenHit)
						local up = nil -- (the newest the server has: it left the runner half their ping ago)
						for _, x in rSt do if x.sent + runnerPing / 2 <= arrive then up = x else break end end
						if up then
							table.insert(rS, { t = arrive, cf = CFrame.new(MotionStamps.predict(up, t - up.sent)) * rS[#rS].cf.Rotation })
						end
					end
					local ok, why = TouchHit.verify({ seen = seen - ahead, mine = mine, ahead = ahead }, {
						runner = rS,
						catcher = samples(cHist, cPk, arrive - T.Keep, arrive),
						now = arrive, back = back, shape = shape, knife = knife, along = along,
						face = newest.cf.LookVector, vel = newest.vel,
					}, T)
					if ok then claimOk += 1 end
					if ok or okOld then newOk += 1 end
					newWhy[why] = (newWhy[why] or 0) + 1
					-- the gap on the runner's own screen at the swing
					local real = trueAt(rPath, t).Position
					table.insert(gaps, Vector3.new(real.X - seen.Position.X, 0, real.Z - seen.Position.Z).Magnitude)
				end
			end
			t += 1 / 60
		end
	end
	table.sort(gaps)
	table.sort(oldPlace)
	local function mean(list)
		local sum = 0
		for _, v in list do sum += v end
		return if #list > 0 then sum / #list else 0
	end
	local function p95(list) return list[math.max(1, math.floor(#list * 0.95))] or 0 end
	local whys = {}
	for k, v in newWhy do if k ~= "hit" then table.insert(whys, k .. " " .. v) end end
	table.sort(whys)
	local function pct(x) return math.floor(100 * x / hits + 0.5) end
	print(string.format("%-28s hits %3d | OLD %3d%% (%.1f studs off, p95 %.1f) | claim %3d%%%s | NOW %3d%% | runner's screen %.1f studs (p95 %.1f)",
		name, hits, pct(oldOk), mean(oldPlace), p95(oldPlace), pct(claimOk),
		if #whys > 0 then " (" .. table.concat(whys, ", ") .. ")" else "", pct(newOk), mean(gaps), p95(gaps)))
	return { old = oldOk / hits, claim = claimOk / hits, new = newOk / hits, gap = mean(gaps), gap95 = p95(gaps) }
end

-- A cheating catcher (the critic's test, Oct 19): standing still, the runner standing still straight ahead, he
-- sends any claim he likes: himself moved up to 3 studs toward the runner, the runner moved up to 3 studs toward
-- him, the runner turned side-on, his facing pointed at them. How far away can the runner be and still be caught?
-- And can he stab someone behind him? `judge(claim, runnerSamples, catcherSamples, now, back)` is the rule.
local function cheatReach(judge, knife)
	local catcher = CFrame.new(0, 3, 0) -- facing -Z
	local function caught(D, honest)
		local runner = CFrame.new(0, 3, -D)
		local rS, cS = { { t = 0, cf = runner }, { t = 1, cf = runner } }, { { t = 0, cf = catcher }, { t = 1, cf = catcher } }
		if honest then
			return judge({ seen = runner, mine = catcher }, rS, cS, 1, 0.15)
		end
		for s1 = 0, 3, 0.25 do
			for s2 = 0, 3, 0.25 do
				for _, turn in { 0, 90 } do
					local seen = CFrame.new(0, 3, -D + s2) * CFrame.Angles(0, math.rad(turn), 0)
					local mine = CFrame.new(0, 3, -s1)
					if judge({ seen = seen, mine = mine }, rS, cS, 1, 0.15) then
						return true
					end
				end
			end
		end
		return false
	end
	local honest, cheat = 0, 0
	for D = 3, 16, 0.05 do
		if caught(D, true) then honest = D end
		if caught(D, false) then cheat = D end
	end
	local behind = CFrame.new(0, 3, 3)
	local back = judge({ seen = behind, mine = lookAt(catcher.Position, behind.Position) },
		{ { t = 0, cf = behind }, { t = 1, cf = behind } }, { { t = 0, cf = catcher }, { t = 1, cf = catcher } }, 1, 0.15)
	return honest, cheat, back
end

local function newJudge(knife)
	return function(claim, rS, cS, now, back)
		return (TouchHit.verify(claim, { runner = rS, catcher = cS, now = now, back = back, shape = shape, knife = knife,
			face = cS[#cS].cf.LookVector, vel = Vector3.zero }, T))
	end
end

print(if STAMP then "STAMP: others drawn where their own stamps say they are now (Shared/MotionStamps)"
	elseif AHEAD then "AHEAD: others drawn ahead (Gameplay/OthersAhead)" else "others drawn where Roblox has them (no lead)")
print(string.format("touch lag model: packets %d/s, drawn %.2f s behind, server history 60/s; Touch: MaxRewind %.2f, SeenSlack %.1f, MineSlack %.1f, Lead %.2f, FaceSlack %d, CapSlack %.1f, Tolerance %.1f",
	math.floor(1 / SEND + 0.5), INTERP, T.MaxRewind, T.SeenSlack, T.MineSlack, T.Lead, T.FaceSlack, T.CapSlack, T.Tolerance))
local results = {}
for _, sc in {
	{ "both 50 ms", 0.05, 0.05 }, { "both 100 ms", 0.1, 0.1 }, { "both 200 ms", 0.2, 0.2 },
	{ "runner 250, catcher 60", 0.25, 0.06 }, { "runner 60, catcher 250", 0.06, 0.25 }, { "catcher 400 ms", 0.08, 0.4 },
	{ "dive at 72, both 50 ms", 0.05, 0.05, 72, Round.Lunge }, { "dive at 72, both 100 ms", 0.1, 0.1, 72, Round.Lunge },
	{ "dive at 72, both 200 ms", 0.2, 0.2, 72, Round.Lunge },
} do
	results[sc[1]] = scenario(sc[1], sc[2], sc[3], 120, sc[4] or 30, sc[5] or S)
end
local honest, cheat, behind = cheatReach(newJudge(S), S)
print(string.format("cheat test (stab): honest reach %.2f studs, a cheater's claim reaches %.2f (+%.2f); behind him: %s",
	honest, cheat, cheat - honest, if behind then "CAUGHT" else "refused"))
results.cheat = { honest = honest, cheat = cheat, behind = behind }
results.cheatReach = cheatReach
return results
