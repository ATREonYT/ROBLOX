--!strict
-- CoinBay's market (Desk Computer Empire §6). Server only, on purpose: the whole market is a pure function of
-- real time (UTC), so every server shows the same coins and prices, but a client that could read this code
-- would see the future. Clients only get the past (CoinService streams it).
--
-- Shape (tuned with tools/tests/coin_sim.py, numbers in Config/Coins):
--   * a new coin every Coins.LaunchEvery seconds (coin n launches at n * LaunchEvery)
--   * launch pump (1.6-3.2x in the first 25-75 s, the bonding curve filling), then a dip, then its fate:
--       rug  : climbs again, the dev sells, -98% in seconds         (most likely when dev % and top-10 % are high)
--       fade : bleeds out from the launch pump
--       pump : second leg to 1.6-3.6x the launch level, then bleeds
--       run  : 5-15x the launch level, then gives most of it back
--       moon : 40-120x the launch level, then "listed" for the rest of the day
--   * each UTC day has a mood (bull / crab / bear) that tilts every fate
-- Sim results (buy and hold 20 min): aping everything loses ~25%; low-risk coins bought after the dip with a
-- 2x take-profit and a 0.7 stop make +10-18%. Reading the signals is the skill.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Coins = require(ReplicatedStorage.MTL.Config.Coins)

local CoinMarket = {}

local M32 = 4294967296

local function mul32(a: number, b: number): number
	local alo = a % 65536
	local ahi = (a - alo) / 65536
	return (((ahi * b) % 65536) * 65536 + alo * b) % M32
end

local function mix(x: number): number
	x = x % M32
	x = bit32.bxor(x, bit32.rshift(x, 16))
	x = mul32(x, 0x45d9f3b)
	x = bit32.bxor(x, bit32.rshift(x, 16))
	x = mul32(x, 0x45d9f3b)
	x = bit32.bxor(x, bit32.rshift(x, 16))
	return x
end

-- Deterministic 0..1 from (n, salt). Same as hash() in tools/tests/coin_sim.py.
local function h(n: number, salt: number): number
	local lo = n % M32
	local hi = math.floor(n / M32)
	local a = mix(bit32.bxor(lo, mul32(salt, 0x9E3779B1)))
	return mix(bit32.bxor(bit32.bxor(a, 0x5bd1e995), hi % M32)) / M32
end
CoinMarket.hash = h

export type Coin = {
	n: number,
	id: string, -- "C<n>"
	ticker: string,
	name: string,
	color: Color3,
	glyph: string,
	launchAt: number, -- unix seconds
	endAt: number, -- delisted after this (price frozen near zero, or listed until the day ends)
	dev: number, -- dev wallet % at launch
	top10: number, -- top-10 holders %
	risk: number, -- 0..1 from dev + top10 (what a careful trader reads)
	buzz: number, -- 0..100 "Clipz buzz"
	fate: string, -- server only, never sent
	launch: number, -- launch pump peak (x launch price)
	t0: number, -- seconds to the launch pump peak
	dip: number,
	peak: number,
	tp: number, -- seconds from launch to the fate's peak (the rug moment for rugs)
	basePrice: number, -- $ at launch
}

local cache: { [number]: Coin } = {}

function CoinMarket.mood(day: number): string
	local r = h(day, 7)
	local m = Coins.Moods
	if r < m.Bull then
		return "Bull"
	elseif r < m.Bull + m.Crab then
		return "Crab"
	end
	return "Bear"
end

function CoinMarket.dayOf(t: number): number
	return math.floor(t / 86400)
end

local FATES = { "rug", "fade", "pump", "run", "moon" }

function CoinMarket.coin(n: number): Coin
	local hit = cache[n]
	if hit then
		return hit
	end
	local F = Coins.Fate
	local dev = 2 + h(n, 1) * 28
	local top10 = 15 + h(n, 2) * 55
	local risk = 0.5 * (dev - 2) / 28 + 0.5 * (top10 - 15) / 55
	local w = {
		rug = F.Rug[1] + F.Rug[2] * risk,
		fade = F.Fade,
		pump = math.max(0.02, F.Pump[1] - F.Pump[2] * risk),
		run = math.max(0.005, F.Run[1] - F.Run[2] * risk),
		moon = math.max(0.001, F.Moon[1] - F.Moon[2] * risk),
	}
	local launchAt = n * Coins.LaunchEvery
	local mood = CoinMarket.mood(CoinMarket.dayOf(launchAt))
	if mood == "Bull" then
		w.pump *= Coins.BullBoost
		w.run *= Coins.BullBoost
		w.moon *= Coins.BullBoost
	elseif mood == "Bear" then
		w.rug *= Coins.BearRug
	end
	local total = w.rug + w.fade + w.pump + w.run + w.moon
	local u = h(n, 3) * total
	local fate = "moon"
	for _, k in FATES do
		local wk = (w :: any)[k]
		if u < wk then
			fate = k
			break
		end
		u -= wk
	end
	local a, b, e = h(n, 4), h(n, 5), h(n, 6)
	local launch = 1.6 + e * 1.6
	local t0 = 25 + h(n, 8) * 50
	local peak, tp, life
	if fate == "rug" then
		peak, tp = launch * (1.0 + a * 0.8), t0 + 60 + b * 300
		life = tp + 60
	elseif fate == "fade" then
		peak, tp, life = launch, t0, 900
	elseif fate == "pump" then
		peak, tp, life = launch * (1.6 + a * 2.0), t0 + 120 + b * 300, 1500
	elseif fate == "run" then
		peak, tp, life = launch * (5 + a * 10), t0 + 400 + b * 700, 2700
	else
		peak, tp = launch * (40 + a * 80), t0 + 1200 + b * 1200
		life = (CoinMarket.dayOf(launchAt) + 1) * 86400 - launchAt -- listed until the UTC day ends
	end
	local names = Coins.Names
	local idx = 1 + math.floor(h(n, 20) * #names)
	local entry = names[idx]
	local suffix = Coins.Suffixes[1 + math.floor(h(n, 21) * #Coins.Suffixes)]
	local ticker = entry[1] .. (if h(n, 22) < 0.35 then suffix else "")
	local palette = Coins.Colors
	local c: Coin = {
		n = n,
		id = "C" .. tostring(n),
		ticker = string.sub(ticker, 1, 10),
		name = entry[2],
		color = palette[1 + math.floor(h(n, 23) * #palette)],
		glyph = Coins.Glyphs[1 + math.floor(h(n, 24) * #Coins.Glyphs)],
		launchAt = launchAt,
		endAt = launchAt + life,
		dev = math.floor(dev * 10) / 10,
		top10 = math.floor(top10 * 10) / 10,
		risk = risk,
		buzz = math.floor(h(n, 25) * 60 + (if fate == "pump" or fate == "run" or fate == "moon" then 40 * h(n, 26) else 15 * h(n, 26))),
		fate = fate,
		launch = launch,
		t0 = t0,
		dip = launch * (0.55 + 0.25 * h(n, 9)),
		peak = peak,
		tp = tp,
		basePrice = Coins.BasePrice * (0.5 + h(n, 27)),
	}
	cache[n] = c
	return c
end

-- Price multiple (x launch price) s seconds after launch, before noise.
local function baseAt(c: Coin, s: number): number
	if s <= 0 then
		return 1
	end
	if s <= c.t0 then
		return 1 + (c.launch - 1) * (s / c.t0) ^ 1.4
	end
	if c.fate == "fade" then
		return math.max(0.06, c.launch * math.exp(-(s - c.t0) / 200))
	end
	if s <= c.tp then
		local x = (s - c.t0) / (c.tp - c.t0)
		if x < 0.25 then
			return c.launch + (c.dip - c.launch) * math.min(1, x * 4)
		end
		return c.dip + (c.peak - c.dip) * ((x - 0.25) / 0.75) ^ 1.5
	end
	local d = s - c.tp
	if c.fate == "rug" then
		return if d < 1 then c.peak else math.max(0.02, c.peak * math.exp(-d / 2))
	elseif c.fate == "pump" then
		return c.peak * (0.3 + 0.7 * math.exp(-d / 400))
	elseif c.fate == "run" then
		return c.peak * (0.25 + 0.75 * math.exp(-d / 600))
	end
	return c.peak * (0.45 + 0.55 * math.exp(-d / 1800))
end

-- $ price at unix time t (nil before launch). Candle-level noise is fixed per 10 s; sub-noise wiggles inside.
function CoinMarket.price(c: Coin, t: number, sub: number?): number?
	local s = t - c.launchAt
	if s < 0 then
		return nil
	end
	s = math.min(s, c.endAt - c.launchAt)
	local k = math.floor(s / 10)
	local noise = math.exp(0.08 * (h(c.n * 977 + k, 11) - 0.5) * 2 + 0.04 * (h(c.n * 131 + math.floor(k / 3), 12) - 0.5) * 2)
	if sub then
		noise *= math.exp(0.03 * (h(c.n * 7919 + k * 8 + sub, 13) - 0.5) * 2)
	end
	return c.basePrice * baseAt(c, s) * noise
end

-- One 10-second candle {o, h, l, c} starting at unix time t (t on a 10 s boundary from launch).
-- maxT (usually "now") stops the live candle from showing the next few seconds.
function CoinMarket.candle(c: Coin, t: number, maxT: number?): { number }
	local pts = {}
	for j = 0, 4 do
		local at = t + j * 2.5
		if maxT and at > maxT then
			break
		end
		local p = CoinMarket.price(c, at, if j == 0 or j == 4 then nil else j)
		if p then
			table.insert(pts, p)
		end
	end
	if #pts == 0 then
		return { 0, 0, 0, 0 }
	end
	local hi, lo = pts[1], pts[1]
	for _, p in pts do
		hi = math.max(hi, p)
		lo = math.min(lo, p)
	end
	return { pts[1], hi, lo, pts[#pts] }
end

-- What a trader can see at time t (no fate, no future).
function CoinMarket.signals(c: Coin, t: number): { [string]: any }
	local s = t - c.launchAt
	local growth = if c.fate == "rug" or c.fate == "fade" then 260 else 420
	if c.fate == "run" or c.fate == "moon" then
		growth = 900
	end
	local holders = math.floor(12 + growth * (1 - math.exp(-math.max(0, s) / 150)) + 30 * h(c.n * 53 + math.floor(s / 30), 14))
	local dev = c.dev
	local devActive = false
	if c.fate == "rug" then
		if s >= c.tp then
			dev = 0
			holders = math.floor(holders * 0.4)
		elseif s >= c.tp - Coins.DevWarnSeconds then
			dev = c.dev * 0.5 -- the tell: the dev wallet starts splitting into fresh wallets
			devActive = true
		end
		if s >= c.tp - 30 then
			holders = math.floor(12 + growth * (1 - math.exp(-(c.tp - 30) / 150))) -- holders stall before a rug
		end
	end
	local curve = math.clamp(s / (c.t0 * 3), 0, 1)
	return {
		holders = holders,
		dev = math.floor(dev * 10) / 10,
		devActive = devActive,
		top10 = c.top10,
		buzz = c.buzz,
		curve = math.floor(curve * 100),
		listed = c.fate == "moon" and s > c.tp,
		dead = t >= c.endAt or (c.fate == "rug" and s > c.tp + 5),
	}
end

-- Coins a trader can see at time t: everything launched in the last Coins.Visible window that isn't long dead,
-- plus today's listed moons. Newest first.
function CoinMarket.live(t: number): { Coin }
	local out = {}
	local now = math.floor(t / Coins.LaunchEvery)
	local back = math.floor(Coins.VisibleSeconds / Coins.LaunchEvery)
	for n = now, now - back, -1 do
		local c = CoinMarket.coin(n)
		if t < c.endAt + Coins.ShowDeadFor then
			table.insert(out, c)
		end
	end
	-- listed moons from earlier today (rare: ~1 in 160 coins)
	local dayStart = CoinMarket.dayOf(t) * 86400
	for n = math.floor(dayStart / Coins.LaunchEvery), now - back - 1 do
		local c = CoinMarket.coin(n)
		if c.fate == "moon" and t - c.launchAt > c.tp then
			table.insert(out, c)
		end
	end
	return out
end

-- Blue chips: a daily random walk (deterministic per day), smooth inside the day.
function CoinMarket.chipPrice(chip: { [string]: any }, t: number): number
	local day = CoinMarket.dayOf(t)
	local function dayClose(d: number): number
		local p = chip.start
		local from = Coins.ChipEpochDay
		local steps = math.clamp(d - from, 0, 3650)
		-- cheap: walk from a checkpoint every 64 days so this never loops more than 64 times
		local cp = from + math.floor(steps / 64) * 64
		p = chip.start * math.exp((h(cp, chip.salt + 1) - 0.5) * 0.4 + 0.004 * (cp - from) * (chip.drift or 0))
		for dd = cp + 1, from + steps do
			local mv = (h(dd, chip.salt) - 0.5) * 2 * chip.vol
			if CoinMarket.mood(dd) == "Bull" then
				mv += chip.vol * 0.25
			elseif CoinMarket.mood(dd) == "Bear" then
				mv -= chip.vol * 0.25
			end
			p *= 1 + mv
		end
		return p
	end
	local a, b = dayClose(day - 1), dayClose(day)
	local x = (t - day * 86400) / 86400
	local k = math.floor((t % 86400) / 60)
	local wig = 1 + 0.004 * (h(day * 1440 + k, chip.salt + 2) - 0.5) * 2
	return (a + (b - a) * x) * wig
end

return CoinMarket
