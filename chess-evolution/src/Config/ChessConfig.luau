--!strict
-- +1 Chess Evolution: shared config (ReplicatedStorage/ChessConfig).
-- Every rate, requirement, reward, price and fight number lives here.
-- IDs (station, stage, set keys) are saved in player data: NEVER rename them.

local Config = {}

Config.PlayerData = {
	storeName = "ChessEvolution_PlayerData_v1", -- never rename after launch
	schemaVersion = 1,
	-- Studio: saves stay in server memory and reset on Stop (repo rule).
	-- Set false (and turn on Studio Access to API Services) to test real saves.
	studioResetsProgress = true,
	migrations = {},
}

-- Server input checks ------------------------------------------------------
Config.Input = {
	-- Accepted taps: a token bucket. ~6 per second, a small burst for network jitter.
	tapsPerSecond = 6,
	tapBurst = 4,
	-- Extra distance (studs) allowed on top of every zone for lag.
	distanceSlack = 3,
}

-- Treadmills ---------------------------------------------------------------
-- order: display order. unlock: nil = free; { stage = "Stage2" } = clear that stage.
-- built = false: a locked display only (model shown, never usable yet).
Config.Stations = {
	PawnMill = { order = 1, name = "Pawn Mill", basePower = 1, built = true, row = "front" },
	KnightSprint = { order = 2, name = "Knight Sprint", basePower = 2, built = true, row = "front", unlock = { stage = "Stage2" } },
	BishopRun = { order = 3, name = "Bishop Run", basePower = 5, built = true, row = "front", unlock = { stage = "Stage3" } },
	RookRig = { order = 4, name = "Rook Rig", basePower = 12, built = true, row = "front", unlock = { stage = "Stage4" } },
	QueenDash = { order = 5, name = "Queen Dash", basePower = 30, built = true, row = "rear", unlock = { stage = "Stage5" } },
	KingsEndgame = { order = 6, name = "King's Endgame", basePower = 80, built = true, row = "rear", unlock = { stage = "Stage6" } },
	CastleClimb = { order = 7, name = "Castle Climb", basePower = 200, built = true, row = "rear", unlock = { stage = "Stage7" } },
	GrandmasterGlide = { order = 8, name = "Grandmaster Glide", basePower = 500, built = false, row = "rear" },
}

-- Chess Sets (equipment) -----------------------------------------------------
-- price in Wins. available = false: a padlocked "Coming soon" display, never sold.
Config.Sets = {
	Wooden = { order = 1, name = "Wooden Set", multiplier = 1, price = 0, available = true, color = Color3.fromRGB(196, 140, 84), accent = Color3.fromRGB(255, 196, 120), fx = "none" },
	Marble = { order = 2, name = "Marble Set", multiplier = 2, price = 8, available = true, color = Color3.fromRGB(236, 240, 246), accent = Color3.fromRGB(70, 230, 255), fx = "halo" },
	Jade = { order = 3, name = "Jade Set", multiplier = 4, price = 60, available = true, color = Color3.fromRGB(70, 200, 120), accent = Color3.fromRGB(120, 255, 160), fx = "leaf" },
	Ruby = { order = 4, name = "Ruby Set", multiplier = 8, price = 250, available = true, color = Color3.fromRGB(220, 40, 70), accent = Color3.fromRGB(255, 90, 110), fx = "flare" },
	Sapphire = { order = 5, name = "Sapphire Set", multiplier = 16, price = 600, available = true, color = Color3.fromRGB(40, 90, 230), accent = Color3.fromRGB(110, 160, 255), fx = "spark" },
	Gold = { order = 6, name = "Gold Set", multiplier = 32, price = 3000, available = false, color = Color3.fromRGB(255, 196, 40), accent = Color3.fromRGB(255, 220, 90), fx = "orbit" },
	Obsidian = { order = 7, name = "Obsidian Set", multiplier = 64, price = 10000, available = false, color = Color3.fromRGB(40, 30, 60), accent = Color3.fromRGB(170, 90, 255), fx = "aura" },
	Crystal = { order = 9, name = "Crystal Set", multiplier = 256, price = 120000, available = false, color = Color3.fromRGB(200, 240, 255), accent = Color3.fromRGB(120, 230, 255), fx = "spark" },
	Cosmic = { order = 10, name = "Cosmic Set", multiplier = 512, price = 400000, available = false, color = Color3.fromRGB(40, 30, 110), accent = Color3.fromRGB(120, 90, 255), fx = "aura" },
	Champion = { order = 11, name = "Champion Set", multiplier = 1024, price = 1500000, available = false, color = Color3.fromRGB(255, 215, 90), accent = Color3.fromRGB(255, 120, 60), fx = "crown" },
	Royal = { order = 8, name = "Royal Set", multiplier = 128, price = 40000, available = false, color = Color3.fromRGB(150, 60, 220), accent = Color3.fromRGB(255, 120, 230), fx = "crown" },
}
Config.DefaultSet = "Wooden"

-- Stages (Board Run) -------------------------------------------------------
-- fight: perTap = meter per accepted tap; grace = seconds with no pressure;
-- phases = { { untilT, perSecond } ... } rival pressure; timeout = seconds.
-- An earlier stage must be cleared before a later one opens (gate).
Config.Stages = {
	Stage1 = {
		order = 1, name = "Pawn Pete", rival = "Pawn", rivalId = "PawnPete", power = 25, reward = 10, color = Color3.fromRGB(255, 70, 70),
		opponent = { name = "Pawn Pete", title = "Park Player" },
		fight = { perTap = 4, grace = 1, timeout = 16, phases = { { untilT = 9, perSecond = 2.5 }, { untilT = 16, perSecond = 5 } } },
	},
	Stage2 = {
		order = 2, name = "Knight Nadia", rival = "Knight", rivalId = "KnightNadia", power = 90, reward = 20, color = Color3.fromRGB(60, 140, 255), unlocks = "KnightSprint",
		opponent = { name = "Knight Nadia", title = "Club Player" },
		fight = { perTap = 4, grace = 1, timeout = 16, phases = { { untilT = 9, perSecond = 3 }, { untilT = 16, perSecond = 6 } } },
	},
	Stage3 = {
		order = 3, name = "Rook Rocco", rival = "Rook", rivalId = "RookRocco", power = 220, reward = 40, color = Color3.fromRGB(255, 190, 40), unlocks = "BishopRun",
		opponent = { name = "Rook Rocco", title = "Tournament Player" },
		fight = { perTap = 4, grace = 1, timeout = 16, phases = { { untilT = 9, perSecond = 3.2 }, { untilT = 16, perSecond = 6.5 } } },
	},
	Stage4 = {
		order = 4, name = "Bishop Bea", rival = "Bishop", rivalId = "BishopBea", power = 5000, reward = 70, color = Color3.fromRGB(170, 80, 240), unlocks = "RookRig",
		opponent = { name = "Bishop Bea", title = "Candidate Master" },
		fight = { perTap = 4, grace = 1, timeout = 16, phases = { { untilT = 9, perSecond = 9 }, { untilT = 16, perSecond = 12 } } },
	},
	Stage5 = {
		order = 5, name = "Queen Quinn", rival = "Queen", rivalId = "QueenQuinn", power = 15000, reward = 120, color = Color3.fromRGB(255, 120, 200), unlocks = "QueenDash",
		opponent = { name = "Queen Quinn", title = "International Master" },
		fight = { perTap = 4, grace = 1, timeout = 16, phases = { { untilT = 9, perSecond = 10 }, { untilT = 16, perSecond = 13 } } },
	},
	Stage6 = {
		order = 6, name = "King Kai", rival = "King", rivalId = "KingKai", power = 50000, reward = 200, color = Color3.fromRGB(60, 220, 200), unlocks = "KingsEndgame",
		opponent = { name = "King Kai", title = "Grandmaster" },
		fight = { perTap = 4, grace = 1, timeout = 16, phases = { { untilT = 9, perSecond = 11 }, { untilT = 16, perSecond = 13.5 } } },
	},
	Stage7 = {
		order = 7, name = "Grandmaster Orion", rival = "King", rivalId = "GrandmasterOrion", power = 250000, reward = 500, color = Color3.fromRGB(255, 200, 40), unlocks = "CastleClimb", boss = true,
		opponent = { name = "Grandmaster Orion", title = "World Champion" },
		fight = { perTap = 4, grace = 1, timeout = 20, phases = { { untilT = 10, perSecond = 12.5 }, { untilT = 20, perSecond = 15 } } },
	},
}
Config.FutureStages = 3
-- Rival animation ids (assets/RivalAnims.rbxm). 0 until Alex publishes them (right-click > Save to Roblox).
-- Studio plays the KeyframeSequences directly; the live game needs these ids.
Config.AnimIds = { Idle = 0, Tap = 0, Victory = 0, Defeat = 0 } -- extra gates drawn past the "Coming soon" line, for depth

-- Battle badges (chess-review style ratings). One place for every threshold.
-- Meter: 100 = player wins, 0 = player loses.
Config.Badges = {
	dwell = 0.7, -- seconds continuously inside a band before it counts
	openingQuiet = 1.5, -- no warnings before this time
	danger = {
		{ key = "Inaccuracy", enter = 40, leave = 46 },
		{ key = "Mistake", enter = 25, leave = 31 },
		{ key = "Blunder", enter = 10, leave = 16 },
	},
	resetAt = 47, -- a sustained recovery to here resets the warning sequence
	resetDwell = 1.0,
	-- routine ratings: meter gain over each window after the grace period
	window = 2.5,
	good = 6,
	excellent = 11,
	best = 16,
	routineCap = 2,
	greatDeficit = 35,
	greatLead = 60,
	brilliantDip = 25,
	missRecover = 15, -- climb this far off the low...
	missDrop = 12, -- ...then fall back this far before taking the lead (> 50)
	-- display priority (higher wins; lower requests are dropped while one shows)
	priority = {
		Brilliant = 5, Great = 4, Blunder = 3, Mistake = 3, Inaccuracy = 3, Miss = 3,
		Book = 2, Forced = 2, Best = 1, Excellent = 1, Good = 1,
	},
	hold = { default = 1.1, Brilliant = 1.8, Great = 1.4 },
}

-- Badge looks: glyph, label and colour. Original shapes, drawn by the client.
Config.BadgeLook = {
	Book = { glyph = "B", label = "Book", color = Color3.fromRGB(200, 160, 110), shape = "book" },
	Forced = { glyph = ">", label = "Forced", color = Color3.fromRGB(110, 125, 145), shape = "arrow" },
	Good = { glyph = "+", label = "Good", color = Color3.fromRGB(140, 200, 120), shape = "check" },
	Excellent = { glyph = "++", label = "Excellent", color = Color3.fromRGB(90, 210, 90), shape = "check2" },
	Best = { glyph = "*", label = "Best", color = Color3.fromRGB(40, 180, 70), shape = "star" },
	Great = { glyph = "!", label = "Great", color = Color3.fromRGB(70, 130, 255), shape = "circle" },
	Brilliant = { glyph = "!!", label = "Brilliant", color = Color3.fromRGB(30, 215, 200), shape = "circle" },
	Inaccuracy = { glyph = "?!", label = "Inaccuracy", color = Color3.fromRGB(250, 205, 50), shape = "circle" },
	Mistake = { glyph = "?", label = "Mistake", color = Color3.fromRGB(255, 140, 40), shape = "circle" },
	Miss = { glyph = "x", label = "Miss", color = Color3.fromRGB(225, 130, 90), shape = "target" },
	Blunder = { glyph = "??", label = "Blunder", color = Color3.fromRGB(235, 50, 50), shape = "circle" },
}

-- First-session guide: advances only on real server-confirmed actions.
Config.Guide = {
	{ key = "Train", text = "Walk onto the Pawn Mill and tap TRAIN", until_ = "power25" },
	{ key = "Challenge", text = "Go to Stage 1 and Challenge the Pawn Rival", until_ = "clearStage1" },
	{ key = "Buy", text = "Buy the Marble Set in Chess Sets", until_ = "ownMarble" },
	{ key = "Equip", text = "Equip Marble, then train for +2 per tap!", until_ = "equipMarble" },
	{ key = "Promote", text = "Fill the bar and tap PROMOTE for +50% Power forever", until_ = "promoted" },
}

-- Sounds: 0 until the owner uploads ours (tools/sfx). Never invent IDs.
Config.Sounds = {
	Tap = 0, Gain = 0, Capture = 0, Win = 0, Lose = 0, Chime = 0, Brilliant = 0, Warn = 0, Click = 0, Music = 0,
}

-- Promotion (this game's rebirth: a pawn that reaches the end becomes a queen) ----
-- Blueprint - Plus One Evolution §4 and note 12 §3: first one by ~90 s, cost x3.2 each time,
-- +50% Power and +25% Wins per promotion. Resets Power and Wins; sets, cleared stages and
-- unlocked treadmills stay.
Config.Promotion = {
	first = { power = 400, wins = 20 },
	base = { power = 4000, wins = 150 },
	growth = 3.2,
	powerBonus = 0.5,
	winsBonus = 0.25,
	levels = 20, -- display-only level bar per promotion (note 13 §2B): about one level a second
	levelCurve = 1.3,
}

-- Game passes. id 0 = not made yet: the shop shows the price and "Coming soon" and never
-- prompts (repo rule). Alex makes each pass on the Creator Dashboard and pastes its id here.
-- Plain names only (no "VIP", note 09).
Config.Passes = {
	DoublePower = { order = 1, id = 0, price = 399, name = "2x Power", text = "Every tap gives double Power" },
	DoubleWins = { order = 2, id = 0, price = 399, name = "2x Wins", text = "Every duel win pays double" },
	AutoTrain = { order = 3, id = 0, price = 199, name = "Auto Train", text = "Trains for you while you stand on a treadmill" },
}
Config.AutoTrainRate = 4 -- taps per second, under the hand cap of 6

-- Daily rewards: 7 tiles by UTC day. A missed day pauses the streak, never wipes it
-- (Brief - Game Design §5). Wins scale with promotions so they stay worth claiming.
Config.Daily = { 15, 25, 40, 60, 90, 130, 250 }

-- Playtime gifts (this session): minutes -> Wins. Note 20 rule 10, exit hook.
Config.Playtime = {
	{ min = 2, wins = 5 }, { min = 5, wins = 10 }, { min = 10, wins = 20 }, { min = 15, wins = 30 },
	{ min = 25, wins = 50 }, { min = 40, wins = 80 }, { min = 60, wins = 140 }, { min = 90, wins = 250 },
}

-- Codes (upper case). Each works once per player.
Config.Codes = {
	CHECKMATE = { wins = 25, text = "+25 Wins" },
	PROMOTE = { wins = 50, text = "+50 Wins" },
	CASTLE = { wins = 100, text = "+100 Wins" },
}

-- Leaderboard board by spawn (top 10 by Wins, refresh every 60 s).
Config.Leaderboard = { storeName = "ChessEvolution_TopWins_v1", refresh = 60, size = 10 }

-- Helpers -------------------------------------------------------------------
local function sortedKeys(map: { [string]: any }): { string }
	local keys = {}
	for key in map do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return map[a].order < map[b].order
	end)
	return keys
end
Config.StationOrder = sortedKeys(Config.Stations)
Config.SetOrder = sortedKeys(Config.Sets)
Config.StageOrder = sortedKeys(Config.Stages)

-- Power per tap for a station with a set: base x multiplier.
function Config.Gain(stationId: string, setId: string): number
	local station = Config.Stations[stationId]
	local set = Config.Sets[setId] or Config.Sets[Config.DefaultSet]
	return if station then station.basePower * set.multiplier else 0
end

-- Promotion cost after n promotions.
function Config.PromotionCost(n: number): (number, number)
	local p = Config.Promotion
	if n <= 0 then
		return p.first.power, p.first.wins
	end
	local k = p.growth ^ (n - 1)
	return math.floor(p.base.power * k), math.floor(p.base.wins * k)
end

-- Multipliers. Additive inside a source, multiplied across sources (note 12 §4).
function Config.PowerMult(promotions: number, passes: { [string]: boolean }?): number
	return (1 + Config.Promotion.powerBonus * promotions) * (if passes and passes.DoublePower then 2 else 1)
end
function Config.WinsMult(promotions: number, passes: { [string]: boolean }?): number
	return (1 + Config.Promotion.winsBonus * promotions) * (if passes and passes.DoubleWins then 2 else 1)
end

-- Display-only level from Power toward the next promotion: returns level, progress 0..1.
function Config.Level(power: number, promotions: number): (number, number)
	local p = Config.Promotion
	local goal = Config.PromotionCost(promotions)
	local function at(l: number): number
		return goal * (l / p.levels) ^ p.levelCurve
	end
	local l = 0
	while l < p.levels and power >= at(l + 1) do
		l += 1
	end
	if l >= p.levels then
		return p.levels, 1
	end
	return l + 1, math.clamp((power - at(l)) / (at(l + 1) - at(l)), 0, 1)
end

-- Rival pressure (meter per second) at time t.
function Config.Pressure(fight: any, t: number): number
	if t < fight.grace then
		return 0
	end
	for _, phase in fight.phases do
		if t < phase.untilT then
			return phase.perSecond
		end
	end
	return fight.phases[#fight.phases].perSecond
end

-- The stage that must be cleared before stageId opens, or nil.
function Config.PreviousStage(stageId: string): string?
	local order = Config.Stages[stageId].order
	for _, id in Config.StageOrder do
		if Config.Stages[id].order == order - 1 then
			return id
		end
	end
	return nil
end

return Config
