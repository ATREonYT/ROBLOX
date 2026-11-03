--!strict
-- Pure rules for the crime loop (no Instances): dirty cash maths, washing, heat decay, police hit chance, payouts.
-- Used by CrimeService / PoliceService on the server and by the HUD on the client. Tested in Studio with
-- CrimeRules.selfTest() (prints "[MTL CrimeRules] ok").
local CrimeRules = {}

local function clamp(x: number, a: number, b: number): number
	return math.max(a, math.min(b, x))
end

-- Round to whole dollars.
local function whole(x: number): number
	return math.floor(x + 0.5)
end

---------------------------------------------------------------- dirty cash

-- How much a downed player drops, and how much they keep. Small bags drop nothing.
function CrimeRules.dropSplit(dirty: number, share: number, minDrop: number): (number, number)
	dirty = math.max(0, math.floor(dirty))
	local drop = math.floor(dirty * clamp(share, 0, 1))
	if drop < minDrop then
		return 0, dirty
	end
	return drop, dirty - drop
end

-- Adding to the bag, capped. Returns (newDirty, actuallyAdded).
function CrimeRules.addDirty(dirty: number, amount: number, max: number): (number, number)
	if amount ~= amount or amount <= 0 then
		return dirty, 0
	end
	local new = math.min(max, dirty + math.floor(amount))
	return new, new - dirty
end

---------------------------------------------------------------- washing

function CrimeRules.washCut(level: number, cfg: any): number
	return if level >= cfg.CutLowLevel then cfg.CutLow else cfg.Cut
end

-- Seconds the wash takes for this much dirty cash.
function CrimeRules.washSeconds(dirty: number, cfg: any): number
	return clamp(dirty / cfg.PerSecond, cfg.MinSeconds, cfg.MaxSeconds)
end

-- (clean paid out, the house's cut)
function CrimeRules.washPayout(dirty: number, cut: number): (number, number)
	dirty = math.max(0, math.floor(dirty))
	local clean = math.floor(dirty * (1 - clamp(cut, 0, 1)))
	return clean, dirty - clean
end

---------------------------------------------------------------- heat

-- Seconds without being seen before one star drops, at `stars`.
function CrimeRules.loseSeconds(stars: number, cfg: any): number
	if stars <= 0 then
		return math.huge
	end
	return cfg.LoseSeconds[clamp(stars, 1, #cfg.LoseSeconds)]
end

-- Heat only goes up from a crime (never randomly) and never above Max. Returns the new stars.
function CrimeRules.raise(current: number, wanted: number, max: number): number
	return clamp(math.max(current, wanted), 0, max)
end

-- One tick of decay. unseenFor = seconds since police last saw you. Returns (stars, unseenFor) after the tick.
function CrimeRules.decay(stars: number, unseenFor: number, cfg: any): (number, number)
	if stars > 0 and unseenFor >= CrimeRules.loseSeconds(stars, cfg) then
		return stars - 1, 0
	end
	return stars, unseenFor
end

---------------------------------------------------------------- police

-- Chance an officer's shot hits: falls off with distance, halved while the target moves fast.
function CrimeRules.hitChance(dist: number, targetSpeed: number, cfg: any): number
	local t = clamp((dist - 10) / math.max(1, cfg.ShootRange - 10), 0, 1)
	local chance = cfg.HitChanceNear + (cfg.HitChanceFar - cfg.HitChanceNear) * t
	if targetSpeed > 14 then
		chance *= cfg.MovingPenalty
	end
	if dist > cfg.ShootRange then
		return 0
	end
	return clamp(chance, 0, 1)
end

-- Per-star lookups that clamp to the table's ends.
function CrimeRules.perStar(list: { number }, stars: number): number
	return list[clamp(math.floor(stars), 1, #list)]
end

-- Units wanted on a target right now.
function CrimeRules.unitsFor(stars: number, cfg: any): number
	if stars <= 0 then
		return 0
	end
	return cfg.UnitsPerStar[clamp(stars, 1, #cfg.UnitsPerStar)]
end

---------------------------------------------------------------- payouts

-- A list of stack values (one per cash stack), rolled with `rng` (Random) inside the config ranges.
function CrimeRules.rollStacks(rng: Random, countRange: { number }, valueRange: { number }): { number }
	local n = rng:NextInteger(countRange[1], countRange[2])
	local out = {}
	for i = 1, n do
		-- round to $5 so the numbers look like money
		out[i] = math.floor(rng:NextInteger(valueRange[1], valueRange[2]) / 5) * 5
	end
	return out
end

function CrimeRules.roll(rng: Random, range: { number }): number
	return math.floor(rng:NextInteger(range[1], range[2]) / 5) * 5
end

-- Car boost pay after damage.
function CrimeRules.boostPay(hits: number, cfg: any): number
	return math.max(cfg.minPay, cfg.pay - hits * cfg.damageCost)
end

-- Split a heist take evenly; the leftover dollars go to the first crew member.
function CrimeRules.split(total: number, n: number): { number }
	n = math.max(1, n)
	local each = math.floor(total / n)
	local out = {}
	for i = 1, n do
		out[i] = each
	end
	out[1] += total - each * n
	return out
end

---------------------------------------------------------------- cooldowns

-- os.time() when `id` is ready, from a table of finished-at times. 0 = ready now.
function CrimeRules.readyAt(lastAt: number?, cooldown: number): number
	if not lastAt or lastAt <= 0 then
		return 0
	end
	return lastAt + cooldown
end

function CrimeRules.isReady(lastAt: number?, cooldown: number, now: number): boolean
	return now >= CrimeRules.readyAt(lastAt, cooldown)
end

-- Soonest-ready time among several targets (the Money app's one number per method).
function CrimeRules.soonest(times: { [string]: number }, ids: { string }, cooldown: number): number
	local best = math.huge
	for _, id in ids do
		best = math.min(best, CrimeRules.readyAt(times[id], cooldown))
	end
	return if best == math.huge then 0 else best
end

-- "2:05" style countdown text.
function CrimeRules.clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function CrimeRules.money(n: number): string
	local s = tostring(math.floor(math.abs(n)))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return (if n < 0 then "-$" else "$") .. out
end

---------------------------------------------------------------- self test

function CrimeRules.selfTest(): boolean
	local function eq(a: any, b: any, what: string)
		assert(a == b, "[MTL CrimeRules] " .. what .. ": got " .. tostring(a) .. ", want " .. tostring(b))
	end
	local d, k = CrimeRules.dropSplit(1000, 0.5, 50)
	eq(d, 500, "drop half")
	eq(k, 500, "keep half")
	d, k = CrimeRules.dropSplit(80, 0.5, 50)
	eq(d, 0, "small bag drops nothing")
	eq(k, 80, "small bag kept")
	local nd, added = CrimeRules.addDirty(249000, 5000, 250000)
	eq(nd, 250000, "cap")
	eq(added, 1000, "cap added")
	local clean, cut = CrimeRules.washPayout(1000, 0.15)
	eq(clean, 850, "wash clean")
	eq(cut, 150, "wash cut")
	local wcfg = { PerSecond = 400, MinSeconds = 3, MaxSeconds = 25, Cut = 0.15, CutLow = 0.1, CutLowLevel = 15 }
	eq(CrimeRules.washSeconds(100, wcfg), 3, "wash min")
	eq(CrimeRules.washSeconds(4000, wcfg), 10, "wash 4k")
	eq(CrimeRules.washSeconds(1e6, wcfg), 25, "wash max")
	eq(CrimeRules.washCut(16, wcfg), 0.1, "low cut")
	local hcfg = { LoseSeconds = { 18, 26, 34 } }
	local s, u = CrimeRules.decay(2, 26, hcfg)
	eq(s, 1, "decay star")
	eq(u, 0, "decay resets")
	s, u = CrimeRules.decay(2, 10, hcfg)
	eq(s, 2, "no decay yet")
	eq(CrimeRules.raise(1, 3, 3), 3, "raise")
	eq(CrimeRules.raise(3, 1, 3), 3, "never lowers")
	local pcfg = { ShootRange = 90, HitChanceNear = 0.55, HitChanceFar = 0.12, MovingPenalty = 0.5, UnitsPerStar = { 1, 2, 3 } }
	eq(CrimeRules.hitChance(10, 0, pcfg), 0.55, "near")
	eq(CrimeRules.hitChance(100, 0, pcfg), 0, "out of range")
	eq(CrimeRules.hitChance(10, 20, pcfg), 0.275, "moving")
	eq(CrimeRules.unitsFor(0, pcfg), 0, "no units")
	eq(CrimeRules.unitsFor(3, pcfg), 3, "3 units")
	local sp = CrimeRules.split(1001, 3)
	eq(sp[1], 335, "split first")
	eq(sp[2], 333, "split rest")
	eq(CrimeRules.boostPay(3, { pay = 1400, damageCost = 70, minPay = 500 }), 1190, "boost pay")
	eq(CrimeRules.boostPay(50, { pay = 1400, damageCost = 70, minPay = 500 }), 500, "boost floor")
	eq(CrimeRules.readyAt(nil, 60), 0, "never done = ready")
	eq(CrimeRules.isReady(100, 60, 150), false, "cooling")
	eq(CrimeRules.isReady(100, 60, 160), true, "ready")
	eq(CrimeRules.soonest({ A = 100, B = 50 }, { "A", "B", "C" }, 60), 0, "C never done -> 0")
	eq(CrimeRules.soonest({ A = 100, B = 50 }, { "A", "B" }, 60), 110, "soonest")
	eq(CrimeRules.money(12345), "$12,345", "money")
	eq(CrimeRules.money(500), "$500", "money small")
	eq(CrimeRules.clock(125), "2:05", "clock")
	local stacks = CrimeRules.rollStacks(Random.new(1), { 4, 6 }, { 90, 140 })
	assert(#stacks >= 4 and #stacks <= 6, "[MTL CrimeRules] stack count")
	for _, v in stacks do
		assert(v >= 90 and v <= 140 and v % 5 == 0, "[MTL CrimeRules] stack value " .. v)
	end
	print("[MTL CrimeRules] ok")
	return true
end

return CrimeRules
