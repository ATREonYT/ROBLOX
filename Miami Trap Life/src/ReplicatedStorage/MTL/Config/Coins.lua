--!strict
-- CoinBay: the meme coin market on the desk PC (vault: Research/Desk Computer Empire.md §6).
-- The market itself is server-only (ServerScriptService/MTL/Services/CoinMarket). Numbers tuned with
-- tools/tests/coin_sim.py: aping everything loses ~25%, reading the signals makes +10-18% a coin.
local C = Color3.fromRGB

local Coins = {}

Coins.Level = 8 -- CoinBay unlocks (Liberty OS)
Coins.LaunchEvery = 360 -- seconds between new coins (same on every server: real UTC time)
Coins.VisibleSeconds = 50 * 60 -- coins launched in the last 50 min show in the list
Coins.ShowDeadFor = 120 -- a dead coin stays listed this long (so you see the rug candle)
Coins.BasePrice = 0.00004 -- $ per coin at launch (x 0.5-1.5)
Coins.CandleSeconds = 10
Coins.ChartCandles = 72 -- 12 minutes of candles on the chart
Coins.DevWarnSeconds = 15 -- the dev wallet goes "active" this long before a rug (the tell)
Coins.Fee = 0.01 -- per trade (buy and sell)
Coins.MinTrade = 10 -- $

-- Fate weights: base + slope * risk (risk 0..1 from dev % and top-10 %).
Coins.Fate = {
	Rug = { 0.25, 0.55 }, -- base, + slope
	Fade = 0.30,
	Pump = { 0.28, 0.22 }, -- base, - slope
	Run = { 0.09, 0.08 },
	Moon = { 0.012, 0.011 },
}
-- Each UTC day's mood (shares add to 1).
Coins.Moods = { Bull = 0.30, Crab = 0.45, Bear = 0.25 }
Coins.BullBoost = 1.4 -- pump/run/moon weights on a bull day
Coins.BearRug = 1.3 -- rug weight on a bear day
Coins.MoodLines = { -- the VBX News / Mail hint each day
	Bull = "Analysts: degen season is back. Everything's pumping.",
	Crab = "Markets flat. Traders say pick your coins carefully.",
	Bear = "Bloodbath on CoinBay. Rugs everywhere, be careful out there.",
}

-- How much you can hold in ONE coin (at cost), by level. Keeps the economy sane.
Coins.MaxPosition = {
	{ level = 8, cap = 1000 },
	{ level = 12, cap = 5000 },
	{ level = 18, cap = 20000 },
	{ level = 25, cap = 75000 },
	{ level = 40, cap = 250000 },
}
Coins.MaxOpen = 5 -- coins held at once

-- XP (EconomyService.addXP, so 2x XP applies)
Coins.XP = { Trade = 5, Gain5x = 50, Gain20x = 150, Escaped = 200, FirstTrade = 60 }

-- Blue chips: steadier coins, a daily random walk (vol = max daily move).
Coins.ChipEpochDay = 20393 -- 2025-11-02 UTC
Coins.Chips = {
	{ id = "LBTY", ticker = "LBTY", name = "Liberty Index", start = 12.5, vol = 0.04, salt = 101, drift = 0.3, color = C(96, 170, 255), glyph = "L" },
	{ id = "VBX", ticker = "VBX", name = "Vice Bay Exchange", start = 3.2, vol = 0.07, salt = 211, drift = 0.1, color = C(240, 192, 72), glyph = "V" },
	{ id = "GTEETH", ticker = "GTEETH", name = "Gold Teeth", start = 0.85, vol = 0.12, salt = 307, drift = 0, color = C(255, 214, 90), glyph = "G" },
}

-- Name pool: { ticker, name }. Hood/Miami memes, nothing about drugs or real people.
Coins.Names = {
	{ "PATEL", "Patel's Tab" },
	{ "BIGBACK", "Big Back" },
	{ "SKRRT", "Skrrt Coin" },
	{ "CANALRAT", "Canal Rat" },
	{ "MANGO", "Mango Soda" },
	{ "OPP", "Opp Pack" },
	{ "DRIP", "Drip Inu" },
	{ "FLAMINGO", "Flamingo" },
	{ "GATOR", "Gator Money" },
	{ "BODEGA", "Bodega Cat" },
	{ "RIZZ", "Rizz" },
	{ "SHMONEY", "Shmoney" },
	{ "PALM", "Palm Tree" },
	{ "TRAPCAT", "Trap Cat" },
	{ "BUSSIN", "Bussin" },
	{ "LOWRIDER", "Lowrider" },
	{ "CUBANO", "Cubano" },
	{ "SWERVE", "Swerve" },
	{ "NOCAP", "No Cap" },
	{ "CORNER", "Corner Store" },
	{ "MOPJOB", "Mop Job" },
	{ "VALET", "Valet Key" },
	{ "GRILLZ", "Grillz" },
	{ "SUDZ", "Sudz" },
	{ "IBIS", "Ibis Coin" },
	{ "HURRICANE", "Hurricane" },
	{ "CHANCLA", "La Chancla" },
	{ "KEV", "Kev Knows" },
	{ "CROC", "Crocs Up" },
	{ "SAUCE", "Sauce" },
}
Coins.Suffixes = { "INU", "AI", "X", "MOON", "PEPE", "2" }
Coins.Glyphs = { "$", "★", "♦", "♛", "✦", "⚡", "☀", "♠" }
Coins.Colors = {
	C(255, 72, 104),
	C(96, 170, 255),
	C(92, 196, 104),
	C(240, 192, 72),
	C(180, 110, 255),
	C(255, 140, 60),
	C(60, 210, 200),
}

return Coins
