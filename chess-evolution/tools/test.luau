--!nonstrict
-- +1 Chess Evolution: offline checks (no Studio needed).
--   cd chess-evolution && lune run tools/test.luau
-- Proves the config numbers, the battle meter tuning, the badge rules and the
-- server rules (Core) the prompts ask for. A clean run does NOT prove Studio works.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local cache = {}
local function load(path)
	if cache[path] then
		return cache[path]
	end
	local env = setmetatable({ Color3 = roblox.Color3, Vector3 = roblox.Vector3, CFrame = roblox.CFrame }, { __index = getfenv() })
	local result = luau.load(fs.readFile(path), { debugName = path, environment = env })()
	cache[path] = result
	return result
end

local Config = load("src/Config/ChessConfig.luau")
local Battle = load("src/Shared/Battle.luau")
local Badges = load("src/Shared/Badges.luau")
local Core = load("src/Server/Core.luau")
Core.Inject(Battle, Badges)

local passed, failed = 0, 0
local function check(name, cond, detail)
	if cond then
		passed += 1
	else
		failed += 1
		print(`FAIL {name}{if detail ~= nil then ": " .. tostring(detail) else ""}`)
	end
end
local VERBOSE = process.env.VERBOSE == "1"

-- 1. Config gains ----------------------------------------------------------
check("Pawn+Wooden = 1", Config.Gain("PawnMill", "Wooden") == 1)
-- Nov 8: sets no longer multiply treadmills; a tap anywhere pays the set's multiplier
check("Pawn treadmill ignores the set = 1", Config.Gain("PawnMill", "Marble") == 1)
check("Knight treadmill = 2", Config.Gain("KnightSprint", "Marble") == 2)
check("Marble tap = 2", Config.TapGain("Marble") == 2)
check("Marble costs 8", Config.Sets.Marble.price == 8)
check("stage 1 = 25 power, 10 wins", Config.Stages.Stage1.power == 25 and Config.Stages.Stage1.reward == 10)
check("stage 2 = 90 power, 20 wins", Config.Stages.Stage2.power == 90 and Config.Stages.Stage2.reward == 20)
check("stage 3 = 220 power, 40 wins", Config.Stages.Stage3.power == 220 and Config.Stages.Stage3.reward == 40)

-- 2. Battle tuning ----------------------------------------------------------
local function logBadges(stage, tps, label, extra)
	local fight = Config.Stages[stage].fight
	local state, samples = Battle.Simulate(fight, tps, 0.1)
	local log = Badges.Run(Config.Badges, fight.grace, samples, state.outcome)
	local keys = {}
	for _, e in log do
		table.insert(keys, `{e[2]}@{string.format("%.1f", e[1])}`)
	end
	if VERBOSE then
		print(`[{stage} {label}] {state.outcome} at {string.format("%.1f", state.t)}s  {table.concat(keys, " ")}`)
	end
	return state, log, keys
end
local function has(log, key)
	for _, e in log do
		if e[2] == key then
			return e[1]
		end
	end
	return nil
end

do
	-- Nov 8 (Alex: "more intense"): the rival pushes back hard; stop tapping and the bar slides away fast
	local s = logBadges("Stage1", 4, "4 taps/s")
	check("Pawn: 4 taps/s wins", s.outcome == "win", s.outcome)
	check("Pawn: 4 taps/s wins in ~7.5-9.5 s", s.t >= 7.5 and s.t <= 9.5, s.t)
	check("Pawn: 2 taps/s is not enough", logBadges("Stage1", 2, "2 taps/s").outcome ~= "win")
	local idle, log = logBadges("Stage1", 0, "idle")
	check("Pawn: idle loses", idle.outcome == "lose", idle.outcome)
	check("Pawn: idle loses inside 6 s (the bar visibly slides)", idle.t <= 6, idle.t)
	local a, b, c = has(log, "Inaccuracy"), has(log, "Mistake"), has(log, "Blunder")
	check("Pawn idle: ?! then ? then ?? before defeat", a and b and c and a < b and b < c and c < idle.t, `{a} {b} {c} end {idle.t}`)
	for _, stage in { "Stage2", "Stage3" } do
		local w = logBadges(stage, 5, "5 taps/s")
		check(`{stage}: 5 taps/s wins`, w.outcome == "win", w.outcome)
		local i2, l2 = logBadges(stage, 0, "idle")
		check(`{stage}: idle loses through all three bands`, i2.outcome == "lose" and has(l2, "Inaccuracy") and has(l2, "Mistake") and has(l2, "Blunder"))
		local slow = logBadges(stage, 2.5, "2.5 taps/s")
		check(`{stage}: 2.5 taps/s is not enough`, slow.outcome ~= "win", slow.outcome)
	end
	check("Stage2 harder than Stage1", Battle.Simulate(Config.Stages.Stage2.fight, 4, 0.1).t > s.t)
	-- later rivals: beatable at a steady 5-5.5 taps/s, never by tapping slowly
	for _, row in { { "Stage4", 5, 3.5 }, { "Stage5", 5, 4 }, { "Stage6", 5.5, 4 }, { "Stage7", 5.5, 4.5 } } do
		local w = logBadges(row[1], row[2], `{row[2]} taps/s`)
		check(`{row[1]}: {row[2]} taps/s wins`, w.outcome == "win", `{w.outcome} {w.t}`)
		local slow = logBadges(row[1], row[3], `{row[3]} taps/s`)
		check(`{row[1]}: {row[3]} taps/s is not enough`, slow.outcome ~= "win", `{slow.outcome} {slow.t}`)
		check(`{row[1]}: winnable inside the 6/s tap cap`, logBadges(row[1], 6, "6 taps/s").outcome == "win")
	end
	-- Elo advantage (Alex, Nov 8): smooth, and 2x the rival's Elo makes the fight easy
	local f1 = Config.Stages.Stage1.fight
	check("ease: at his Elo the fight is unchanged", Config.DuelFight(f1, 25, 25).perTap == f1.perTap)
	check("ease: 2x Elo, 2 taps/s wins", Battle.Simulate(Config.DuelFight(f1, 50, 25), 2, 0.1).outcome == "win")
	check("ease: 1x Elo, 2 taps/s loses", Battle.Simulate(Config.DuelFight(f1, 25, 25), 2, 0.1).outcome ~= "win")
	check("ease: 1.5x Elo is between 1x and 2x", (function()
		local a, m, b = Config.DuelFight(f1, 25, 25).perTap, Config.DuelFight(f1, 37.5, 25).perTap, Config.DuelFight(f1, 50, 25).perTap
		return a < m and m < b
	end)())
	check("ease: stops at 4x", Config.DuelFight(f1, 1000, 25).perTap == Config.DuelFight(f1, 100, 25).perTap)
	local boss = Config.Stages.Stage7
	check("ease: boss at 2x Elo, 3 taps/s wins", Battle.Simulate(Config.DuelFight(boss.fight, boss.power * 2, boss.power), 3, 0.1).outcome == "win")
	check("every stage has a named opponent", (function()
		for _, id in Config.StageOrder do
			local o = Config.Stages[id].opponent
			if not (o and o.name and o.title) then return false end
		end
		return true
	end)())
end

-- 3. Badge scenarios (scripted meter paths) ---------------------------------
local function path(points, dt)
	-- linear interpolation through { t, meter } points
	local samples = {}
	local t = 0
	local i = 1
	while t <= points[#points][1] + 1e-9 do
		while points[i + 1] and t > points[i + 1][1] do
			i += 1
		end
		local a, b = points[i], points[i + 1] or points[i]
		local f = if b[1] > a[1] then (t - a[1]) / (b[1] - a[1]) else 0
		table.insert(samples, { t, a[2] + (b[2] - a[2]) * f })
		t += dt or 0.1
	end
	return samples
end
local cfg = Config.Badges
do -- normal win: routine only, capped
	local log = Badges.Run(cfg, 1, path({ { 0, 50 }, { 1, 54 }, { 9, 100 } }), "win")
	local routine = 0
	for _, e in log do
		check("normal win has no warnings", e[2] ~= "Inaccuracy" and e[2] ~= "Mistake" and e[2] ~= "Blunder", e[2])
		if e[2] == "Good" or e[2] == "Excellent" or e[2] == "Best" then
			routine += 1
		end
	end
	check("normal win: 1-2 routine ratings", routine >= 1 and routine <= cfg.routineCap, routine)
	check("normal win: no Brilliant", not has(log, "Brilliant"))
end
do -- short pause and recovery: one ?! and no repeat
	local log = Badges.Run(cfg, 1, path({ { 0, 50 }, { 3, 50 }, { 5, 37 }, { 6, 37 }, { 7, 52 }, { 10, 70 }, { 13, 100 } }), "win")
	local count = 0
	for _, e in log do
		if e[2] == "Inaccuracy" then
			count += 1
		end
	end
	check("pause: exactly one ?!", count == 1, count)
	check("pause: no ? or ??", not has(log, "Mistake") and not has(log, "Blunder"))
end
do -- hovering on the 40 line does not flicker
	local pts = { { 0, 50 }, { 2, 41 } }
	for k = 1, 20 do
		table.insert(pts, { 2 + k * 0.2, if k % 2 == 0 then 41 else 39 })
	end
	table.insert(pts, { 7, 44 })
	local log = Badges.Run(cfg, 1, path(pts, 0.05), nil)
	local count = 0
	for _, e in log do
		if e[2] == "Inaccuracy" then
			count += 1
		end
	end
	check("hover at 40: at most one ?!", count <= 1, count)
end
do -- deep comeback win: warnings, Great, Brilliant
	local log = Badges.Run(cfg, 1, path({ { 0, 50 }, { 2, 48 }, { 6, 18 }, { 7.5, 18 }, { 10, 62 }, { 11, 66 }, { 13, 100 } }), "win")
	check("comeback: ?! shown", has(log, "Inaccuracy"))
	check("comeback: Great shown", has(log, "Great"))
	check("comeback: Brilliant on the win", has(log, "Brilliant"))
end
do -- failed recovery: Miss, and no second ?? on defeat
	local log = Badges.Run(cfg, 1, path({ { 0, 50 }, { 2, 46 }, { 5, 30 }, { 7, 47 }, { 9, 30 }, { 11, 8 }, { 12, 6 }, { 13, 0 } }), "lose")
	check("failed recovery: Miss", has(log, "Miss"))
	local blunders = 0
	for _, e in log do
		if e[2] == "Blunder" then
			blunders += 1
		end
	end
	check("failed recovery: ?? once", blunders == 1, blunders)
end
do -- fast drop: discards older warnings, shows the deepest
	local log = Badges.Run(cfg, 1, path({ { 0, 50 }, { 2, 50 }, { 2.4, 8 }, { 4, 8 } }), nil)
	check("fast drop: ?? shown", has(log, "Blunder"))
	check("fast drop: older ?! discarded", not has(log, "Inaccuracy"))
end

-- 4. Server rules (Core) ------------------------------------------------------
do
	local clock = 0
	local core = Core.new(Config, function()
		return clock
	end)
	local data = Core.NewData(Config)
	local s = Core.NewSession()
	local near = function()
		return true
	end
	local far = function()
		return false
	end
	-- train on Pawn Mill
	local gained = 0
	for i = 1, 25 do
		clock += 0.5
		local ok, amount = Core.Tap(core, data, s, { kind = "train", station = "PawnMill" }, near)
		if ok then
			gained += amount
		end
	end
	check("train: 25 taps = 25 power", data.Power == 25, data.Power)
	-- rate cap
	local accepted = 0
	for i = 1, 30 do
		clock += 0.01
		if Core.Tap(core, data, s, { kind = "train", station = "PawnMill" }, near) then
			accepted += 1
		end
	end
	check("rate cap: burst only", accepted <= Config.Input.tapBurst + 2, accepted)
	clock += 2
	check("tap anywhere: far from any treadmill still pays", (Core.Tap(core, data, s, { kind = "train", station = "Tap" }, far)))
	clock += 2
	check("treadmill: Knight Sprint locked before a rebirth", not Core.TreadmillGain(core, data, s, "KnightSprint"))
	-- locked gate
	local ok, code = Core.Challenge(core, data, s, "Stage2", near)
	check("gate: Stage 2 locked before Stage 1", not ok and code == "Locked", code)
	ok, code = Core.Challenge(core, data, s, "Stage1", far)
	check("challenge: too far", not ok and code == "TooFar", code)
	-- win stage 1
	local battle
	ok, battle = Core.Challenge(core, data, s, "Stage1", near)
	check("challenge: Stage 1 starts", ok, battle)
	local powerBefore = data.Power
	check("challenge: second challenge rejected while fighting", not Core.Challenge(core, data, s, "Stage1", near))
	check("stale battle tap rejected", not Core.Tap(core, data, s, { kind = "battle", battle = "nope" }, near))
	local result
	for i = 1, 400 do
		clock += 0.05
		if i % 4 == 0 then
			Core.Tap(core, data, s, { kind = "battle", battle = battle.id }, near)
		end
		result = Core.StepBattle(core, data, s, 0.05)
		if result then
			break
		end
	end
	check("battle: 5 taps/s wins", result and result.outcome == "win", result and result.outcome)
	check("battle: 10 wins first clear", data.Wins == 10 and result.reward == 10, data.Wins)
	check("battle: power kept", data.Power == powerBefore)
	-- replay: every win pays (the reference's Wins counter), but unlocks only once
	clock += 1
	ok, battle = Core.Challenge(core, data, s, "Stage1", near)
	for i = 1, 400 do
		clock += 0.05
		if i % 4 == 0 then
			Core.Tap(core, data, s, { kind = "battle", battle = battle.id }, near)
		end
		result = Core.StepBattle(core, data, s, 0.05)
		if result then
			break
		end
	end
	check("replay: win pays again", result.outcome == "win" and result.reward == 10 and data.Wins == 20, data.Wins)
	check("replay: no second unlock", result.unlocked == nil and not result.firstClear)
	-- defeat keeps progress
	clock += 1
	ok, battle = Core.Challenge(core, data, s, "Stage1", near)
	for i = 1, 400 do
		clock += 0.05
		result = Core.StepBattle(core, data, s, 0.05)
		if result then
			break
		end
	end
	check("defeat: lose with no taps", result.outcome == "lose")
	check("defeat: keeps power and wins", data.Power == powerBefore and data.Wins == 20)
	-- shop
	check("buy: unknown set rejected", not Core.Buy(core, data, "Nope"))
	check("buy: coming-soon set never sold", not Core.Buy(core, data, "Gold"))
	check("equip: unowned rejected", not Core.Equip(core, data, "Marble"))
	ok = Core.Buy(core, data, "Marble")
	check("buy: Marble for 8 wins", ok and data.Wins == 12 and data.Sets.Marble == true, data.Wins)
	check("buy: twice rejected", not Core.Buy(core, data, "Marble") and data.Wins == 12)
	check("equip: Marble", Core.Equip(core, data, "Marble") and data.Equipped == "Marble")
	clock += 1
	local okTap, amount = Core.Tap(core, data, s, { kind = "train", station = "PawnMill" }, near)
	check("Marble on Pawn Mill = +2", okTap and amount == 2, amount)
	-- leaving the deck ends training
	Core.Leave(core, s, "walked")
	check("leave: training cleared", s.station == nil)
	-- Knight unlock after Stage 2
	data.Power = 500
	data.Cleared.Stage2 = nil
	ok, battle = Core.Challenge(core, data, s, "Stage2", near)
	check("Stage 2 opens after Stage 1", ok)
	-- Nov 8: the 3-2-1-GO intro: taps do not count and the rival does not push until it ends
	local okWait, codeWait = Core.Tap(core, data, s, { kind = "battle", battle = battle.id }, near)
	check("duel intro: taps wait for GO", not okWait and codeWait == "Wait", codeWait)
	Core.StepBattle(core, data, s, (Config.DuelIntro or 0) - 0.1)
	check("duel intro: no pressure before GO", battle.state.meter == 50 and battle.state.t == 0, battle.state.meter)
	for i = 1, 400 do
		clock += 0.05
		if i % 4 == 0 then
			Core.Tap(core, data, s, { kind = "battle", battle = battle.id }, near)
		end
		result = Core.StepBattle(core, data, s, 0.05)
		if result then
			break
		end
	end
	check("Stage 2 win pays 20", result.outcome == "win" and result.reward == 20, result and result.outcome)
	check("Stage 2 first clear flagged", result.firstClear == true)
	clock += 1
	okTap, amount = Core.Tap(core, data, s, { kind = "train", station = "Tap" }, near)
	check("Marble tap anywhere = +2", okTap and amount == 2, amount)
	-- cleanup mid-battle (death / reset / leave)
	clock += 1
	ok, battle = Core.Challenge(core, data, s, "Stage1", near)
	Core.Leave(core, s, "died")
	check("cleanup: battle cleared on death", s.battle == nil)
	check("cleanup: stale tap after cleanup rejected", not Core.Tap(core, data, s, { kind = "battle", battle = battle.id }, near))
	-- Power requirement
	local fresh = Core.NewData(Config)
	local s2 = Core.NewSession()
	ok, code = Core.Challenge(core, fresh, s2, "Stage1", near)
	check("challenge: needs 25 power", not ok and code == "NeedPower", code)

	-- Promotion (rebirth) -------------------------------------------------
	local pd = Core.NewData(Config)
	local ps = Core.NewSession()
	local cp, cw = Config.PromotionCost(0)
	check("promote: first costs 400 Power / 20 Wins", cp == 400 and cw == 20, `{cp}/{cw}`)
	local p1, w1 = Config.PromotionCost(1)
	local p2 = Config.PromotionCost(2)
	check("promote: cost grows x3.2", p1 == 4000 and w1 == 150 and p2 == 12800, `{p1}/{p2}`)
	pd.Power, pd.Wins = 399, 20
	ok, code = Core.Promote(core, pd, ps)
	check("promote: needs Power", not ok and code == "NeedPower", code)
	pd.Power, pd.Wins = 400, 19
	ok, code = Core.Promote(core, pd, ps)
	check("promote: needs Wins", not ok and code == "NeedWins", code)
	pd.Wins = 25
	pd.Sets.Marble = true
	pd.Cleared.Stage1 = true
	ok = Core.Promote(core, pd, ps)
	check("promote: resets Power and Wins, keeps sets and stages", ok and pd.Power == 0 and pd.Wins == 0 and pd.Promotions == 1 and pd.Sets.Marble and pd.Cleared.Stage1)
	clock += 1
	local okT, amt = Core.Tap(core, pd, ps, { kind = "train", station = "PawnMill" }, near)
	check("promote: +50% Power per tap", okT and amt == 1.5, amt)
	ps.passes.DoublePower = true
	clock += 1
	okT, amt = Core.Tap(core, pd, ps, { kind = "train", station = "PawnMill" }, near)
	check("pass: 2x Power multiplies on top", okT and amt == 3, amt)
	check("wins mult: 1 promotion + 2x Wins = 2.5", Config.WinsMult(1, { DoubleWins = true }) == 2.5)
	local lv, prog = Config.Level(0, 0)
	local lvTop = Config.Level(400, 0)
	check("level bar: starts at 1, ends at 20", lv == 1 and prog == 0 and lvTop == 20, `{lv} {lvTop}`)
	local _, lvMid = nil, Config.Level(200, 0)
	check("level bar: halfway power is past level 10", lvMid > 10, lvMid)

	-- Daily rewards
	local dd = Core.NewData(Config)
	local day = 20000 * 86400
	ok, res = Core.ClaimDaily(core, dd, day + 100)
	check("daily: day 1 pays 15", ok and res.wins == 15 and res.tile == 1 and dd.Wins == 15, res)
	check("daily: twice the same day rejected", not Core.ClaimDaily(core, dd, day + 5000))
	ok, res = Core.ClaimDaily(core, dd, day + 86400 * 3)
	check("daily: a missed day pauses, never wipes (day 2 next)", ok and res.tile == 2, res and res.tile)

	-- Playtime gifts
	local gs = Core.NewSession()
	gs.joinedAt = 0
	ok, code = Core.ClaimGift(core, dd, gs, 1, 60)
	check("gift: not before its minutes", not ok and code == "NotYet", code)
	ok = Core.ClaimGift(core, dd, gs, 1, 121)
	check("gift: claim after 2 min", ok)
	check("gift: once per session", not Core.ClaimGift(core, dd, gs, 1, 500))

	-- Codes
	local before = dd.Wins
	ok = Core.Redeem(core, dd, " checkmate ")
	check("code: case and spaces ignored", ok and dd.Wins == before + 25)
	ok, code = Core.Redeem(core, dd, "CHECKMATE")
	check("code: once per player", not ok and code == "Used", code)
	ok, code = Core.Redeem(core, dd, "FREEROBUX")
	check("code: unknown rejected", not ok and code == "BadCode", code)

	-- Kid-safe: passes without a real id never prompt (Coming soon)
	for key, pass in Config.Passes do
		check(`pass {key}: has a price and a plain name`, pass.price > 0 and not string.find(string.upper(pass.name), "VIP"))
	end
end

print(`[test] {passed} passed, {failed} failed`)
if failed > 0 then
	process.exit(1)
end
