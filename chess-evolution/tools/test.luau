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
check("Pawn+Marble = 2", Config.Gain("PawnMill", "Marble") == 2)
check("Knight+Marble = 4", Config.Gain("KnightSprint", "Marble") == 4)
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
	local s = logBadges("Stage1", 2, "2 taps/s")
	check("Pawn: 2 taps/s wins", s.outcome == "win", s.outcome)
	check("Pawn: 2 taps/s wins in ~8-10 s", s.t >= 7.5 and s.t <= 10.5, s.t)
	local idle, log = logBadges("Stage1", 0, "idle")
	check("Pawn: idle loses", idle.outcome == "lose", idle.outcome)
	local a, b, c = has(log, "Inaccuracy"), has(log, "Mistake"), has(log, "Blunder")
	check("Pawn idle: ?! then ? then ?? before defeat", a and b and c and a < b and b < c and c < idle.t, `{a} {b} {c} end {idle.t}`)
	for _, stage in { "Stage2", "Stage3" } do
		local w = logBadges(stage, 2.5, "2.5 taps/s")
		check(`{stage}: 2.5 taps/s wins`, w.outcome == "win", w.outcome)
		local i2, l2 = logBadges(stage, 0, "idle")
		check(`{stage}: idle loses through all three bands`, i2.outcome == "lose" and has(l2, "Inaccuracy") and has(l2, "Mistake") and has(l2, "Blunder"))
		local slow = logBadges(stage, 1, "1 tap/s")
		check(`{stage}: 1 tap/s is not enough`, slow.outcome ~= "win", slow.outcome)
	end
	check("Stage2 harder than Stage1", Battle.Simulate(Config.Stages.Stage2.fight, 2, 0.1).t > s.t)
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
	check("train: far from deck rejected", not Core.Tap(core, data, s, { kind = "train", station = "PawnMill" }, far))
	check("train: Knight locked before Stage 2", not Core.Tap(core, data, s, { kind = "train", station = "KnightSprint" }, near))
	check("train: unbuilt station rejected", not Core.Tap(core, data, s, { kind = "train", station = "RookRig" }, near))
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
		if i % 10 == 0 then
			Core.Tap(core, data, s, { kind = "battle", battle = battle.id }, near)
		end
		result = Core.StepBattle(core, data, s, 0.05)
		if result then
			break
		end
	end
	check("battle: 2 taps/s wins", result and result.outcome == "win", result and result.outcome)
	check("battle: 10 wins first clear", data.Wins == 10 and result.reward == 10, data.Wins)
	check("battle: power kept", data.Power == powerBefore)
	-- replay: no second payout
	clock += 1
	ok, battle = Core.Challenge(core, data, s, "Stage1", near)
	for i = 1, 400 do
		clock += 0.05
		if i % 8 == 0 then
			Core.Tap(core, data, s, { kind = "battle", battle = battle.id }, near)
		end
		result = Core.StepBattle(core, data, s, 0.05)
		if result then
			break
		end
	end
	check("replay: practice win pays nothing", result.outcome == "win" and result.reward == 0 and data.Wins == 10, data.Wins)
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
	check("defeat: keeps power and wins", data.Power == powerBefore and data.Wins == 10)
	-- shop
	check("buy: unknown set rejected", not Core.Buy(core, data, "Nope"))
	check("buy: coming-soon set never sold", not Core.Buy(core, data, "Jade"))
	check("equip: unowned rejected", not Core.Equip(core, data, "Marble"))
	ok = Core.Buy(core, data, "Marble")
	check("buy: Marble for 8 wins", ok and data.Wins == 2 and data.Sets.Marble == true, data.Wins)
	check("buy: twice rejected", not Core.Buy(core, data, "Marble") and data.Wins == 2)
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
	for i = 1, 400 do
		clock += 0.05
		if i % 6 == 0 then
			Core.Tap(core, data, s, { kind = "battle", battle = battle.id }, near)
		end
		result = Core.StepBattle(core, data, s, 0.05)
		if result then
			break
		end
	end
	check("Stage 2 win pays 20", result.outcome == "win" and result.reward == 20, result and result.outcome)
	check("Knight Sprint unlocked", result.unlocked == "KnightSprint")
	clock += 1
	okTap, amount = Core.Tap(core, data, s, { kind = "train", station = "KnightSprint" }, near)
	check("Marble on Knight Sprint = +4", okTap and amount == 4, amount)
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
end

print(`[test] {passed} passed, {failed} failed`)
if failed > 0 then
	process.exit(1)
end
