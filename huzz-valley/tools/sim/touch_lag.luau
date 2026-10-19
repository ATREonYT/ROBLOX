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
--   OLD (Oct 19 batch 1): the box from where the server has the catcher NOW, against the runner anywhere in the last
--       ping/2 + 0.1 s, re-checked for 0.25 s after the claim arrives;
--   NEW (Shared/TouchHit.verify): the box from where the catcher's screen had itself, against the runner where that
--       screen showed them, if both lie on the server's real paths (Config/Round.Touch).
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
	while t <= seconds do
		if t >= nextTurn then
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
		table.insert(out, { t = t, cf = CFrame.lookAt(pos, pos + fwd) })
		t += SIM
	end
	return out
end

local function trueAt(path, t)
	local i = math.clamp(math.floor(t / SIM) + 1, 1, #path)
	return path[i].cf
end

-- The packets a client sends of its own body: { sent, arrives (at the server), cf }.
local function packets(path, oneWay, seconds)
	local out = {}
	local t = 0
	while t <= seconds do
		table.insert(out, { sent = t, arrives = t + oneWay + rand() * 0.01, cf = trueAt(path, t) })
		t += SEND
	end
	return out
end

-- Where the server has a body at time t (the newest packet that has arrived).
local function serverAt(pk, t)
	local best = pk[1].cf
	for _, p in pk do
		if p.arrives <= t then best = p.cf else break end
	end
	return best
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

-- The server's history (HitHistory): samples every 1/60 s of where it has the body, as { t, cf }.
local function history(pk, seconds)
	local out = {}
	local t = 0
	while t <= seconds do
		table.insert(out, { t = t, cf = serverAt(pk, t) })
		t += 1 / 60
	end
	return out
end
local function between(hist, from, to)
	local out = {}
	for _, h in hist do
		if h.t >= from and h.t <= to then table.insert(out, h.cf) end
	end
	return out
end

local shape = TouchHit.standIn(CFrame.identity)

local function scenario(name, runnerPing, catcherPing, n)
	local seconds = 40
	local hits, oldOk, newOk, newWhy = 0, 0, 0, {}
	local gaps, oldPlace = {}, {}
	local trials = 0
	while hits < n and trials < 400 do
		trials += 1
		local rPath = runnerPath(seconds)
		local rPk = packets(rPath, runnerPing / 2, seconds)
		-- the catcher chases where its screen shows the runner, 30 studs/s, facing them
		local cPath, cpos = {}, trueAt(rPath, 0).Position + Vector3.new(8, 0, 8)
		local t = 0
		while t <= seconds do
			local target = drawnAt(rPk, t, catcherPing / 2).Position
			local d = Vector3.new(target.X - cpos.X, 0, target.Z - cpos.Z)
			if d.Magnitude > 0.5 then cpos += d.Unit * math.min(30 * SIM, d.Magnitude - 0.5) end
			table.insert(cPath, { t = t, cf = CFrame.lookAt(cpos, Vector3.new(target.X, cpos.Y, target.Z)) })
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
				local seen = drawnAt(rPk, t, catcherPing / 2)
				local box, size = TouchHit.reachBox(mine, nil, S.Reach, S.Width)
				if TouchHit.touches(box, size, seen, shape, 0) then
					hits += 1
					nextSwing = t + 1
					local arrive = t + catcherPing / 2 + rand() * 0.01
					-- OLD: from the server's catcher now, the runner anywhere in the last ping/2 + 0.1, for 0.25 s
					local back = math.clamp(catcherPing / 2 + 0.1, 0, 0.3)
					local okOld, at = false, arrive
					while at <= arrive + 0.25 and not okOld do
						local cNow = serverAt(cPk, at)
						local b, sz = TouchHit.reachBox(cNow, nil, S.Reach, S.Width)
						for _, h in rHist do
							if h.t >= at - back and h.t <= at and TouchHit.touches(b, sz, h.cf, shape, T.Tolerance) then
								okOld = true
								table.insert(oldPlace, (h.cf.Position - seen.Position).Magnitude)
								break
							end
						end
						at += 0.03
					end
					if okOld then oldOk += 1 end
					-- NEW: exactly what the screen showed, if the server's paths agree
					local ok, why = TouchHit.verify({ seen = seen, mine = mine },
						between(rHist, arrive - T.MaxRewind, arrive), between(cHist, arrive - T.MaxRewind, arrive),
						shape, S, nil, T)
					if ok then newOk += 1 end
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
	print(string.format("%-22s screen hits %3d | OLD counts %3d%% (where: %.1f studs off the screen's, p95 %.1f) | NEW counts %3d%%%s | runner's own screen: %.1f studs away (p95 %.1f)",
		name, hits, math.floor(100 * oldOk / hits + 0.5), mean(oldPlace), p95(oldPlace), math.floor(100 * newOk / hits + 0.5),
		if #whys > 0 then " (" .. table.concat(whys, ", ") .. ")" else "", mean(gaps), p95(gaps)))
	return { old = oldOk / hits, new = newOk / hits, gap = mean(gaps), gap95 = p95(gaps) }
end

print(string.format("touch lag model: packets %d/s, drawn %.2f s behind, server history 60/s; Touch: MaxRewind %.2f, SeenSlack %.1f, MineSlack %.1f, Tolerance %.1f",
	math.floor(1 / SEND + 0.5), INTERP, T.MaxRewind, T.SeenSlack or -1, T.MineSlack or -1, T.Tolerance))
local results = {}
for _, sc in {
	{ "both 50 ms", 0.05, 0.05 }, { "both 100 ms", 0.1, 0.1 }, { "both 200 ms", 0.2, 0.2 },
	{ "runner 250, catcher 60", 0.25, 0.06 }, { "runner 60, catcher 250", 0.06, 0.25 }, { "catcher 400 ms", 0.08, 0.4 },
} do
	results[sc[1]] = scenario(sc[1], sc[2], sc[3], 120)
end
return results
