--!strict
-- CoinBay's server half (Liberty OS app "CoinBay"). Registered by DeskService; every action re-checked here.
--   market            -> { now, mood, moodLine, coins = {...}, chips = {...}, pos = {...}, cap, open, maxOpen }
--   chart { id }      -> { id, candles = {{o,h,l,c}...}, start, signals }
--   watch { id? }     -> subscribes to 2 s ticks (DeskService.push "CoinBay") while seated
--   buy { id, usd }   -> spends clean cash, fee 1%, cap per coin by level, max 5 open positions
--   sell { id, frac } -> sells a share of the position into clean cash (fee 1%)
-- Save: Coins = { Pos = { [id] = { qty, cost, at } }, Stats = { Trades, Best, Escaped, Realised } }
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Coins = require(ReplicatedStorage.MTL.Config.Coins)
local OSRules = require(ReplicatedStorage.MTL.Rules.OSRules)
local CoinMarket = require(script.Parent.CoinMarket)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local CoinService = {}

local Desk: any = nil
local watching: { [Player]: string | boolean } = {}

local chipById: { [string]: any } = {}
for _, c in Coins.Chips do
	chipById[c.id] = c
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function save(player: Player): any?
	local d = DataService.get(player)
	if not d then
		return nil
	end
	d.Coins = d.Coins or {}
	d.Coins.Pos = d.Coins.Pos or {}
	d.Coins.Stats = d.Coins.Stats or { Trades = 0, Best = 0, Escaped = 0, Realised = 0 }
	return d
end

-- Resolves an id to a price getter. Meme coins are "C<n>", chips by their id.
local function priceOf(id: string, t: number): (number?, any?)
	local chip = chipById[id]
	if chip then
		return CoinMarket.chipPrice(chip, t), nil
	end
	local n = tonumber(string.match(id, "^C(%d+)$"))
	if not n then
		return nil, nil
	end
	local c = CoinMarket.coin(n)
	return CoinMarket.price(c, t), c
end

local function publicCoin(c: any, t: number): any
	local p = CoinMarket.price(c, t) or 0
	local sig = CoinMarket.signals(c, t)
	local spark = {}
	local s0 = math.floor((t - c.launchAt) / 10) * 10
	for i = 11, 0, -1 do
		local ts = c.launchAt + s0 - i * 10
		if ts >= c.launchAt then
			table.insert(spark, CoinMarket.price(c, ts) or 0)
		end
	end
	return {
		id = c.id,
		ticker = c.ticker,
		name = c.name,
		color = c.color,
		glyph = c.glyph,
		launchAt = c.launchAt,
		price = p,
		start = c.basePrice,
		spark = spark,
		signals = sig,
	}
end

local function capFor(d: any): number
	return OSRules.coinCap(d.Level or 1, Coins.MaxPosition)
end

local function positions(d: any, t: number): any
	local out = {}
	for id, pos in d.Coins.Pos do
		local p, c = priceOf(id, t)
		p = p or 0
		table.insert(out, {
			id = id,
			ticker = if c then c.ticker else (chipById[id] and chipById[id].ticker or id),
			qty = pos.qty,
			cost = pos.cost,
			value = pos.qty * p,
			price = p,
		})
	end
	return out
end

local function openCount(d: any): number
	local n = 0
	for _ in d.Coins.Pos do
		n += 1
	end
	return n
end

local function market(player: Player): any
	local d = save(player)
	if not d then
		return { ok = false, err = "Still loading" }
	end
	local t = now()
	local list = {}
	for _, c in CoinMarket.live(t) do
		table.insert(list, publicCoin(c, t))
	end
	-- coins you still hold stay visible even after they drop off the list
	for id in d.Coins.Pos do
		local n = tonumber(string.match(id, "^C(%d+)$"))
		if n then
			local seen = false
			for _, x in list do
				if x.id == id then
					seen = true
				end
			end
			if not seen then
				table.insert(list, publicCoin(CoinMarket.coin(n), t))
			end
		end
	end
	local chips = {}
	for _, chip in Coins.Chips do
		local p = CoinMarket.chipPrice(chip, t)
		local y = CoinMarket.chipPrice(chip, t - 86400)
		table.insert(chips, { id = chip.id, ticker = chip.ticker, name = chip.name, color = chip.color, glyph = chip.glyph, price = p, day = p / y - 1 })
	end
	local mood = CoinMarket.mood(CoinMarket.dayOf(t))
	return {
		ok = true,
		now = t,
		mood = mood,
		moodLine = Coins.MoodLines[mood],
		coins = list,
		chips = chips,
		pos = positions(d, t),
		cap = capFor(d),
		open = openCount(d),
		maxOpen = Coins.MaxOpen,
		cash = d.Cash,
		fee = Coins.Fee,
	}
end

local function chart(id: string): any
	local t = now()
	local chip = chipById[id]
	if chip then
		-- chips: one candle per 10 minutes over the last 12 hours
		local candles = {}
		local t0 = math.floor(t / 600) * 600 - 71 * 600
		for i = 0, 71 do
			local a = t0 + i * 600
			local o = CoinMarket.chipPrice(chip, a)
			local c = CoinMarket.chipPrice(chip, math.min(t, a + 600))
			local m1 = CoinMarket.chipPrice(chip, a + 200)
			local m2 = CoinMarket.chipPrice(chip, a + 400)
			table.insert(candles, { o, math.max(o, c, m1, m2), math.min(o, c, m1, m2), c })
		end
		return { ok = true, id = id, candles = candles, step = 600 }
	end
	local n = tonumber(string.match(id, "^C(%d+)$"))
	if not n then
		return { ok = false, err = "Unknown coin" }
	end
	local c = CoinMarket.coin(n)
	local s = math.floor((math.min(t, c.endAt) - c.launchAt) / Coins.CandleSeconds)
	local first = math.max(0, s - Coins.ChartCandles + 1)
	local candles = {}
	for k = first, s do
		table.insert(candles, CoinMarket.candle(c, c.launchAt + k * Coins.CandleSeconds, t))
	end
	return { ok = true, id = id, candles = candles, step = Coins.CandleSeconds, coin = publicCoin(c, t) }
end

local function buy(player: Player, args: any): any
	local d = save(player)
	if not d or type(args) ~= "table" then
		return { ok = false, err = "Bad request" }
	end
	local id = tostring(args.id)
	local usd = math.floor(tonumber(args.usd) or 0)
	if usd < Coins.MinTrade then
		return { ok = false, err = "Minimum trade is $" .. Coins.MinTrade }
	end
	local t = now()
	local p, c = priceOf(id, t)
	if not p or p <= 0 then
		return { ok = false, err = "Can't trade that" }
	end
	if c then
		local sig = CoinMarket.signals(c, t)
		if sig.dead or t < c.launchAt then
			return { ok = false, err = "Trading closed on " .. c.ticker }
		end
	end
	local pos = d.Coins.Pos[id]
	if not pos and openCount(d) >= Coins.MaxOpen then
		return { ok = false, err = "Max " .. Coins.MaxOpen .. " coins at once. Sell one first." }
	end
	local cap = capFor(d)
	local held = if pos then pos.cost else 0
	if held + usd > cap then
		return { ok = false, err = "Your limit is $" .. cap .. " per coin at Level " .. (d.Level or 1) }
	end
	if not EconomyService.spend(player, usd, "CoinBuy") then
		return { ok = false, err = "Not enough cash" }
	end
	local qty = usd * (1 - Coins.Fee) / p
	if pos then
		pos.qty += qty
		pos.cost += usd
	else
		d.Coins.Pos[id] = { qty = qty, cost = usd, at = t }
	end
	d.Coins.Stats.Trades += 1
	local xp = Coins.XP.Trade
	if d.Coins.Stats.Trades == 1 then
		xp += Coins.XP.FirstTrade
	end
	EconomyService.addXP(player, xp, "CoinTrade")
	DataService.push(player)
	return { ok = true, qty = qty, price = p, market = market(player) }
end

local function sell(player: Player, args: any): any
	local d = save(player)
	if not d or type(args) ~= "table" then
		return { ok = false, err = "Bad request" }
	end
	local id = tostring(args.id)
	local pos = d.Coins.Pos[id]
	if not pos then
		return { ok = false, err = "You don't hold that" }
	end
	local frac = math.clamp(tonumber(args.frac) or 1, 0.01, 1)
	local t = now()
	local p, c = priceOf(id, t)
	p = p or 0
	local qty = pos.qty * frac
	local costShare = pos.cost * frac
	local proceeds = math.floor(qty * (p :: number) * (1 - Coins.Fee))
	pos.qty -= qty
	pos.cost -= costShare
	if frac >= 0.999 or pos.qty <= 0 then
		d.Coins.Pos[id] = nil
	end
	if proceeds > 0 then
		EconomyService.addCash(player, proceeds, "CoinSell", false)
	end
	local mult = if costShare > 0 then proceeds / costShare else 0
	d.Coins.Stats.Trades += 1
	d.Coins.Stats.Realised += proceeds - costShare
	d.Coins.Stats.Best = math.max(d.Coins.Stats.Best or 0, mult)
	local xp = Coins.XP.Trade
	local tag = nil
	if mult >= 20 then
		xp += Coins.XP.Gain20x
		tag = "20x"
	elseif mult >= 5 then
		xp += Coins.XP.Gain5x
		tag = "5x"
	end
	-- sold a rug coin in the warning window (the dev wallet was moving): "caught the top"
	if c and c.fate == "rug" then
		local s = t - c.launchAt
		if s >= c.tp - Coins.DevWarnSeconds and s < c.tp then
			xp += Coins.XP.Escaped
			d.Coins.Stats.Escaped += 1
			tag = "escaped"
		end
	end
	EconomyService.addXP(player, xp, "CoinTrade")
	DataService.push(player)
	return { ok = true, proceeds = proceeds, mult = mult, tag = tag, market = market(player) }
end

function CoinService.handle(player: Player, action: string, args: any): any
	if action == "market" then
		return market(player)
	elseif action == "chart" then
		return chart(type(args) == "table" and tostring(args.id) or "")
	elseif action == "watch" then
		watching[player] = if type(args) == "table" and type(args.id) == "string" then args.id else true
		return { ok = true }
	elseif action == "unwatch" then
		watching[player] = nil
		return { ok = true }
	elseif action == "buy" then
		return buy(player, args)
	elseif action == "sell" then
		return sell(player, args)
	end
	return { ok = false, err = "Unknown action" }
end

function CoinService.onStand(player: Player)
	watching[player] = nil
end

-- Today's mood line (the flat's TV news and PropertyController read this).
function CoinService.moodLine(): string
	local m = CoinMarket.mood(CoinMarket.dayOf(now()))
	return Coins.MoodLines[m]
end

function CoinService.init(desk: any)
	Desk = desk
	Players.PlayerRemoving:Connect(function(p)
		watching[p] = nil
	end)
	-- 2 s ticks to whoever has CoinBay open: prices for the list + the newest candle of the watched coin
	task.spawn(function()
		while true do
			task.wait(2)
			if next(watching) == nil then
				continue
			end
			local t = now()
			local tick = {}
			for _, c in CoinMarket.live(t) do
				tick[c.id] = { price = CoinMarket.price(c, t) or 0, signals = CoinMarket.signals(c, t) }
			end
			for _, chip in Coins.Chips do
				tick[chip.id] = { price = CoinMarket.chipPrice(chip, t) }
			end
			for p, w in watching do
				if not Desk.isSeated(p) then
					watching[p] = nil
					continue
				end
				local msg: any = { t = t, prices = tick }
				if type(w) == "string" then
					local n = tonumber(string.match(w, "^C(%d+)$"))
					if n then
						local c = CoinMarket.coin(n)
						local k = math.floor((math.min(t, c.endAt) - c.launchAt) / Coins.CandleSeconds)
						msg.candle = { id = w, k = k, c = CoinMarket.candle(c, c.launchAt + k * Coins.CandleSeconds, t) }
					end
				end
				Desk.push(p, "CoinBay", msg)
			end
		end
	end)
end

return CoinService
