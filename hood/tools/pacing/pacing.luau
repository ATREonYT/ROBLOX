-- World 1's pacing: how long a player takes to beat each stage and each rebirth, from the real rules and numbers
-- (Config/Balance, Guns, Skins, Shoes, Shared/ShotRules, RebirthRules, EnemyRules, PadRules). A harness snippet:
--   lune run hood/tools/checks/harness_unit.luau hood/src - "$(cat hood/tools/pacing/pacing.luau)"
-- (tune.luau finds the numbers that hit the owner's targets: see its header.)
-- Prints a table per player kind and "WORLD1 <minutes>" lines: the minute the boss yard (the last stage) falls.
-- The owner's target (Oct 27): World 1 in 25-30 minutes for a focused free player; later worlds longer.
-- The model (a simple, honest player; no Robux):
--   * trains in the best open lane (AutoRate x AutoValue shots a second, x lane x rebirth x gun x shoes);
--   * runs the stages as far as Power reaches (a stage needs its Recommended Power), fighting each crew at 3 shots
--     a second (each shot deals your Power and pays a x1-lane shot; at least one shot a goon), walking 64 studs a
--     stage plus a second, and takes the last pad;
--   * runs whenever Power reaches a stage it has never beaten, and rebirths as soon as it can (one run first, to cash
--     out its furthest stage);
--   * buys the best gun it can afford after every run, and spends what's left over on the best Cash shoe box
--     (equipping its 3 best pairs).
-- `patient` only runs to cash out before a rebirth (and for the boss yard); `casual` plays like `focused` but loses
-- 35 % of the time (walking about, menus, idling).
local RS = game:GetService('ReplicatedStorage')
local Shared = RS.Shared
local Balance = require(Shared.Config.Balance)
local Guns = require(Shared.Config.Guns)
local Skins = require(Shared.Config.Skins)
local Shoes = require(Shared.Config.Shoes)
local ShotRules = require(Shared.ShotRules)
local RebirthRules = require(Shared.RebirthRules)
local EnemyRules = require(Shared.EnemyRules)
local PadRules = require(Shared.PadRules)

local STAGES = #Balance.StagePower
local KIND_OF = { G = 'Goon', R = 'Runner', B = 'Bruiser', X = 'Boss' }

-- Total HP of a stage's crew.
local function crewHp(stage)
	local hp = 0
	for _, kind in EnemyRules.Lineups[stage] do
		local id = KIND_OF[kind] or kind
		hp += EnemyRules.maxHp(stage, id)
	end
	return hp
end

local function bestLane(r, boost)
	local best = 1
	for _, g in Skins.Stations do
		if not g.Pass and (g.Rebirths or 0) <= r and g.Multiplier > best then best = g.Multiplier end
	end
	return best * (boost or 1)
end

local function cashBoxes()
	local list = {}
	for _, b in Shoes.boxesForWorld(1) do if b.Price then table.insert(list, b) end end
	return list
end

-- (Oct 27, World 2) opts.sp / opts.pad: another world's StagePower and PadCash (default World 1's); opts.boost: that
-- world's lane multiplier boost; opts.from: a finished run's result to carry on from (Power, rebirths, Cash, guns and
-- shoes carry over; the new world's stages start fresh). A crew's HP scales with its stage's Power.
function simulate(opts) -- (global: tune.luau, appended to this snippet, calls it)
	local rng = Random.new(opts.seed or 1)
	local waste = opts.waste or 0
	local SP = opts.sp or Balance.StagePower
	local PAD = opts.pad or Balance.PadCash
	local from = opts.from
	local t, power, r, cash, gun = 0, 0, 0, 0, 1
	if from then t, power, r, cash, gun = from.t, from.power, from.rebirths, from.cash, from.gun end
	local gunMult = Guns.List[gun].Multiplier
	local owned = from and table.clone(from.owned) or {}
	local shoeMult = 1
	local best = 0 -- the furthest stage ever beaten
	local stageAt, rebirthAt, gunAt = {}, {}, {}
	local boxes = cashBoxes()
	local function slow(dt) return dt / (1 - waste) end
	local function reach(p)
		local k = 0
		for s = 1, STAGES do
			if p >= SP[s] then k = s else break end
		end
		return k
	end
	local function equipBest()
		table.sort(owned, function(a, b) return a > b end)
		local sum = 0
		for i = 1, math.min(Shoes.MaxEquipped, #owned) do sum += owned[i] end
		shoeMult = 1 + sum / 100
	end
	local function shop()
		for i = gun + 1, #Guns.List do
			if Guns.List[i].Cost <= cash then
				cash -= Guns.List[i].Cost
				gun, gunMult = i, Guns.List[i].Multiplier
				gunAt[i] = t
			end
		end
		-- leftover Cash: the best box it can afford, while the next gun is still out of reach
		local nextGun = Guns.List[gun + 1]
		local keep = nextGun and nextGun.Cost * 0.5 or 0
		for _ = 1, 50 do
			local pick
			for _, b in boxes do if b.Price <= cash - keep then pick = b end end
			if not pick then break end
			cash -= pick.Price
			if opts.expected then
				-- (tuning: every box gives its average pair, so the numbers don't jump with luck)
				local avg = 0
				for i, id in pick.Shoes do avg += pick.Chances[i] / 100 * Shoes.ById[id].Bonus end
				table.insert(owned, avg)
			else
				local roll, acc = rng:NextNumber(0, 100), 0
				for i, id in pick.Shoes do
					acc += pick.Chances[i]
					if roll <= acc then table.insert(owned, Shoes.ById[id].Bonus) break end
				end
			end
			t += slow(4) -- the box opening
		end
		equipBest()
	end
	local function run(k)
		t += slow(10) -- spawn to the Stage 1 gate (straight ahead of spawn)
		local walk = RebirthRules.walkSpeed(r)
		for s = 1, k do
			local dmg = EnemyRules.damage(power) * 3 -- per second
			-- (at least one shot a goon, 3 a second, however strong you are)
			local fight = math.max(#EnemyRules.Lineups[s] / 3, crewHp(s) * SP[s] / Balance.StagePower[s] / dmg)
			local shots = fight * 3
			power += shots * ShotRules.pay(ShotRules.perShot(1, r, 1), gunMult, shoeMult)
			t += slow(fight + 64 / walk + 1)
			if not stageAt[s] then stageAt[s] = t end
		end
		cash += PAD[k] or PadRules.reward(k, false)
		t += slow(8) -- back home
		best = math.max(best, k)
		shop()
	end
	while t < (opts.limit or 6 * 3600) do
		local need = RebirthRules.need(r)
		if power >= need then
			local k = reach(power)
			if k > 0 and not (opts.skipRun and best >= STAGES) then run(k) end -- (skipRun: past the world, just train)
			power, r = 0, r + 1
			rebirthAt[r] = t
			t += slow(5)
			if opts.stopAt and r >= opts.stopAt then break end
		else
			local k = reach(power)
			if k > best and (not opts.patient or k >= STAGES) then
				run(k)
				if stageAt[STAGES] and not opts.stopAt then break end
			else
				local rate = ShotRules.AutoRate * ShotRules.pay(ShotRules.perShot(bestLane(r, opts.boost), r, opts.pass or 1), gunMult, shoeMult) * ShotRules.AutoValue
				-- train until a new stage, or the rebirth, comes in reach
				local target = best >= STAGES and need or math.min(need, SP[best + 1])
				local dt = math.max(1, (math.max(target, power + 1) - power) / rate)
				dt = math.min(dt, 30)
				power += rate * dt
				t += slow(dt)
			end
		end
	end
	equipBest()
	return { stageAt = stageAt, rebirthAt = rebirthAt, gunAt = gunAt, gun = gun, shoes = shoeMult, rebirths = r, t = t, power = power, cash = cash, owned = owned }
end

local function minutes(s) return s and string.format('%5.1f', s / 60) or '    -' end
function report() -- (global: tune.luau prints one with its numbers)
local lines = {}
for _, kind in { { name = 'focused', waste = 0 }, { name = 'patient', waste = 0, patient = true }, { name = 'casual', waste = 0.35 } } do
	local sum, n = 0, 0
	local first
	for seed = 1, 5 do
		local res = simulate({ seed = seed, waste = kind.waste, patient = kind.patient })
		first = first or res
		if res.stageAt[STAGES] then sum += res.stageAt[STAGES]; n += 1 end
	end
	table.insert(lines, ('== %s player (seed 1; minutes)'):format(kind.name))
	local row = {}
	for s = 1, STAGES do table.insert(row, ('S%d %s'):format(s, minutes(first.stageAt[s]))) end
	table.insert(lines, table.concat(row, ' |'))
	row = {}
	for i = 1, math.min(first.rebirths, 12) do table.insert(row, ('R%d %s'):format(i, minutes(first.rebirthAt[i]))) end
	table.insert(lines, table.concat(row, ' |'))
	row = {}
	for i = 2, #Guns.List do table.insert(row, ('%s %s'):format(Guns.List[i].Id, minutes(first.gunAt[i]))) end
	table.insert(lines, 'guns: ' .. table.concat(row, ' |'))
	table.insert(lines, ('shoes at the end x%.2f'):format(first.shoes))
	table.insert(lines, ('WORLD1 %s %s min (average of %d runs)'):format(kind.name, n > 0 and string.format('%.1f', sum / n / 60) or 'not reached', n))
end
-- After the world: rebirths up to LAST_REBIRTH (the owner, Oct 27: "more rebirths, up to like 50 ... we need them to
-- stay in the game for longer"), for the focused and the casual player.
local LAST = LAST_REBIRTH or 50
for _, kind in { { name = 'focused', waste = 0 }, { name = 'casual', waste = 0.35 } } do
	local res = simulate({ seed = 1, waste = kind.waste, stopAt = LAST, limit = 40 * 3600 })
	local row = {}
	for i = 10, LAST, 5 do table.insert(row, ('R%d %s h'):format(i, res.rebirthAt[i] and string.format('%.1f', res.rebirthAt[i] / 3600) or '-')) end
	table.insert(lines, ('after the world, %s: %s'):format(kind.name, table.concat(row, ' |')))
	row = {}
	for i = 2, #Guns.List do table.insert(row, ('%s %s'):format(Guns.List[i].Id, minutes(res.gunAt[i]))) end
	table.insert(lines, '  guns (min): ' .. table.concat(row, ' |'))
end
-- (Oct 27, the owner: "3 hours, but with game passes it will be way quicker") The real way to 50: World 1, then World 2
-- to its boss (about rebirth 24), then training in World 2's ranges (LaneBoost 2, no more runs) to 50, free and with the
-- 2x Power pass (pass = 2). The training part is measured from rebirth 24 in a train-only player; the total adds the
-- focused World 1 and World 2 times above.
for _, v in { { name = 'free', pass = 1 }, { name = '2x Power pass', pass = 2 } } do
	local res = simulate({ seed = 1, waste = 0, stopAt = LAST, limit = 40 * 3600, skipRun = true, boost = (Balance.Worlds and Balance.Worlds[2] and Balance.Worlds[2].LaneBoost) or 2, pass = v.pass })
	local from, to = res.rebirthAt[24], res.rebirthAt[LAST]
	if from and to then table.insert(lines, ('train 24 -> %d in World 2, %s: %.0f min'):format(LAST, v.name, (to - from) / 60)) end
end
-- World 2 (Oct 27): carries on from World 1's boss with World 2's numbers (globals W2_SP, W2_PAD, W2_BOOST, else
-- Balance.Worlds[2]); its boss at about 40 minutes more is the owner's "later worlds longer".
local W2 = Balance.Worlds and Balance.Worlds[2]
local sp2, pad2, boost2 = W2_SP, W2_PAD or (W2 and W2.PadCash), W2_BOOST or (W2 and W2.LaneBoost)
if not sp2 and W2 then -- (World 2 runs at Scale x World 1's numbers on both sides: the sim plays it in World 1's units)
	sp2 = {}
	for i, v in W2.StagePower do sp2[i] = v / (W2.Scale or 1) end
end
if sp2 and pad2 then
	for _, kind in { { name = 'focused', waste = 0 }, { name = 'patient', waste = 0, patient = true }, { name = 'casual', waste = 0.35 } } do
		local one = simulate({ seed = 1, waste = kind.waste, patient = kind.patient })
		local two = simulate({ seed = 1, waste = kind.waste, patient = kind.patient, from = one, sp = sp2, pad = pad2, boost = boost2, limit = one.t + 4 * 3600 })
		local row = {}
		for s = 1, STAGES do table.insert(row, ('S%d %s'):format(s, two.stageAt[s] and string.format('%4.1f', (two.stageAt[s] - one.t) / 60) or '   -')) end
		table.insert(lines, ('== World 2, %s (minutes after World 1, entered at %.1f min, rebirth %d)'):format(kind.name, one.t / 60, one.rebirths))
		table.insert(lines, table.concat(row, ' |'))
		local at, rb = two.stageAt[STAGES], one.rebirths
		for i, when in two.rebirthAt do if at and when <= at and i > rb then rb = i end end
		table.insert(lines, ('WORLD2 %s %s min, rebirth %d at its boss'):format(kind.name, at and string.format('%.1f', (at - one.t) / 60) or 'not reached', rb))
	end
end
print(table.concat(lines, '\n'))
end
if PACING_REPORT ~= false then report() end
