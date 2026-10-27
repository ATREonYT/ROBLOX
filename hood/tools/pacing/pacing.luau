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

local function bestLane(r)
	local best = 1
	for _, g in Skins.Stations do
		if not g.Pass and (g.Rebirths or 0) <= r and g.Multiplier > best then best = g.Multiplier end
	end
	return best
end

local function cashBoxes()
	local list = {}
	for _, b in Shoes.boxesForWorld(1) do if b.Price then table.insert(list, b) end end
	return list
end

function simulate(opts) -- (global: tune.luau, appended to this snippet, calls it)
	local rng = Random.new(opts.seed or 1)
	local waste = opts.waste or 0
	local t, power, r, cash, gun = 0, 0, 0, 0, 1
	local gunMult = Guns.List[1].Multiplier
	local owned = {}
	local shoeMult = 1
	local best = 0 -- the furthest stage ever beaten
	local stageAt, rebirthAt, gunAt = {}, {}, {}
	local boxes = cashBoxes()
	local function slow(dt) return dt / (1 - waste) end
	local function reach(p)
		local k = 0
		for s = 1, STAGES do
			if p >= Balance.StagePower[s] then k = s else break end
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
			local fight = math.max(#EnemyRules.Lineups[s] / 3, crewHp(s) / dmg)
			local shots = fight * 3
			power += shots * ShotRules.pay(ShotRules.perShot(1, r, 1), gunMult, shoeMult)
			t += slow(fight + 64 / walk + 1)
			if not stageAt[s] then stageAt[s] = t end
		end
		cash += PadRules.reward(k, false)
		t += slow(8) -- back home
		best = math.max(best, k)
		shop()
	end
	while t < (opts.limit or 6 * 3600) do
		local need = RebirthRules.need(r)
		if power >= need then
			local k = reach(power)
			if k > 0 then run(k) end
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
				local rate = ShotRules.AutoRate * ShotRules.pay(ShotRules.perShot(bestLane(r), r, 1), gunMult, shoeMult) * ShotRules.AutoValue
				-- train until a new stage, or the rebirth, comes in reach
				local target = best >= STAGES and need or math.min(need, Balance.StagePower[best + 1])
				local dt = math.max(1, (math.max(target, power + 1) - power) / rate)
				dt = math.min(dt, 30)
				power += rate * dt
				t += slow(dt)
			end
		end
	end
	return { stageAt = stageAt, rebirthAt = rebirthAt, gunAt = gunAt, gun = gun, shoes = shoeMult, rebirths = r }
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
print(table.concat(lines, '\n'))
end
if PACING_REPORT ~= false then report() end
