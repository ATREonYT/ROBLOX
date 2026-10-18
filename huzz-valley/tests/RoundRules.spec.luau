-- lune run tests/RoundRules.spec.luau
-- The Huss Valley loop with the girl (Shared/RoundRules): pick, Hero solo, rescue, 3 in a row, the girl.
local Rules = require("../src/ReplicatedStorage/Shared/RoundRules")

local passed, failed = 0, 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name .. ": " .. tostring(err))
	end
end
local function eq(a, b, what)
	if a ~= b then
		error(`{what or "value"}: expected {tostring(b)}, got {tostring(a)}`, 2)
	end
end
local function has(events, kind)
	for _, e in events do
		if e.type == kind then
			return e
		end
	end
	return nil
end
local first = function()
	return 1
end
-- players 1..n; player 1 is the lead catcher
local function game(n, opts)
	local ids = {}
	for i = 1, n do
		table.insert(ids, i)
	end
	opts = opts or {}
	opts.random = opts.random or first
	local s = Rules.newGame(ids, 1, opts)
	Rules.startRound(s)
	return s
end
local function allSafe(s)
	for id, st in s.status do
		if st == "Active" then
			Rules.reachSafe(s, id)
		end
	end
end

test("roles: one lead catcher, the rest run, all Active", function()
	local s = game(4)
	eq(s.roles[1], "Catcher")
	eq(s.roles[2], "Runner")
	eq(s.status[3], "Active")
	eq(s.status[1], nil, "catchers have no status")
	eq(s.lead, 1)
end)

test("pick: one Active runner is picked, once a round", function()
	local s = game(4)
	local e = Rules.pickRunner(s)
	eq(has(e, "Picked").id, 2)
	eq(#Rules.pickRunner(s), 0, "second pick")
end)

test("only the picked runner chooses, once", function()
	local s = game(4)
	Rules.pickRunner(s)
	eq(#Rules.choose(s, 3, true), 0, "not picked")
	local e = Rules.choose(s, 2, true)
	eq(has(e, "Choice").hero, true)
	eq(s.hero, 2)
	eq(#Rules.choose(s, 2, false), 0, "already chosen")
end)

test("no answer in time = a random pick", function()
	local s = game(3, { random = function(n) return n end }) -- picks the last runner, then Chicken (2 of 2)
	Rules.pickRunner(s)
	eq(s.picked, 3)
	local e = Rules.choose(s, 3, nil)
	eq(has(e, "Choice").hero, false)
	eq(s.choice, "Chicken")
	eq(s.hero, nil)
end)

test("Hero survives the solo crossing: gets the girl from the sky", function()
	local s = game(4)
	Rules.pickRunner(s)
	Rules.choose(s, 2, true)
	local e = Rules.reachSafe(s, 2)
	eq(has(e, "HeroResult").survived, true)
	local g = has(e, "GirlMoved")
	eq(g.to, 2)
	eq(g.reason, "Hero")
	eq(s.holder, 2)
	eq(s.lastHero, 2)
end)

test("Hero caught on the solo run: downed, no girl", function()
	local s = game(4)
	Rules.pickRunner(s)
	Rules.choose(s, 2, true)
	local e = Rules.tag(s, 1, 2)
	eq(has(e, "HeroResult").survived, false)
	eq(s.status[2], "Downed")
	eq(s.holder, nil)
	eq(has(e, "GirlMoved"), nil)
end)

test("Chicken: crossing first gives nothing", function()
	local s = game(4)
	Rules.pickRunner(s)
	Rules.choose(s, 2, false)
	local e = Rules.reachSafe(s, 2)
	eq(has(e, "GirlMoved"), nil)
	eq(s.holder, nil)
end)

test("a Hero who timed out runs with everyone: no Hero reward, but first across still wins her", function()
	local s = game(4)
	Rules.pickRunner(s)
	Rules.choose(s, 2, true)
	Rules.heroTimeout(s)
	local e = Rules.reachSafe(s, 3)
	eq(has(e, "HeroResult"), nil)
	eq(has(e, "GirlMoved").reason, "First")
	eq(s.holder, 3)
end)

test("Chicken: the first OTHER runner across wins her (owner: 'still the first person to reach the safe zone gets the girl')", function()
	local s = game(4)
	Rules.pickRunner(s)
	Rules.choose(s, 2, false)
	local e = Rules.reachSafe(s, 3)
	local m = has(e, "GirlMoved")
	eq(m and m.reason, "First")
	eq(m and m.to, 3)
	eq(s.holder, 3)
	eq(has(Rules.reachSafe(s, 4), "GirlMoved"), nil, "only the first one")
	eq(s.holder, 3)
end)

test("Chicken: the chooser crossing first is skipped, the next runner across wins her", function()
	local s = game(4)
	Rules.pickRunner(s)
	Rules.choose(s, 2, false)
	Rules.reachSafe(s, 2)
	eq(s.holder, nil)
	Rules.reachSafe(s, 4)
	eq(s.holder, 4)
end)

test("Hero caught: the first runner across wins her instead", function()
	local s = game(4)
	Rules.pickRunner(s)
	Rules.choose(s, 2, true)
	Rules.tag(s, 1, 2)
	eq(s.holder, nil)
	Rules.reachSafe(s, 3)
	eq(s.holder, 3)
end)

test("first across doesn't take her from a catcher who stole her", function()
	local s = game(4)
	Rules.pickRunner(s)
	Rules.choose(s, 2, true)
	Rules.reachSafe(s, 2) -- the Hero wins her
	for _, id in { 3, 4 } do Rules.reachSafe(s, id) end
	Rules.endRound(s)
	Rules.startRound(s)
	Rules.tag(s, 1, 2) -- stolen
	eq(s.holder, 1)
	Rules.pickRunner(s)
	Rules.choose(s, s.picked, false)
	for _, id in { 3, 4 } do Rules.reachSafe(s, id) end
	eq(s.holder, 1)
end)

test("stabbing her carrier steals her; the next surviving Hero takes her back", function()
	local s = game(4)
	Rules.pickRunner(s)
	Rules.choose(s, 2, true)
	Rules.reachSafe(s, 2)
	allSafe(s)
	Rules.endRound(s)
	Rules.startRound(s)
	local e = Rules.tag(s, 1, 2)
	local g = has(e, "GirlMoved")
	eq(g.to, 1)
	eq(g.reason, "Stolen")
	eq(s.holder, 1)
	-- runner 3 is a Hero and makes it: she leaves the catcher for him
	s.picked = nil
	s.choice = nil
	Rules.pickRunner(s)
	eq(s.picked, 3)
	Rules.choose(s, 3, true)
	local e2 = Rules.reachSafe(s, 3)
	eq(has(e2, "GirlMoved").from, 1)
	eq(s.holder, 3)
end)

test("rescue: an Active runner helps a downed one up", function()
	local s = game(4)
	Rules.tag(s, 1, 2)
	local e = Rules.rescue(s, 3, 2)
	eq(has(e, "Rescued").by, 3)
	eq(s.status[2], "Active")
end)

test("one second chance: rescued once, caught again = final, no second rescue", function()
	local s = game(4)
	local e1 = Rules.tag(s, 1, 2)
	eq(has(e1, "Caught").final, false, "first catch isn't final")
	eq(has(Rules.rescue(s, 3, 2), "Rescued").by, 3)
	local e2 = Rules.tag(s, 1, 2)
	eq(has(e2, "Caught").final, true, "second catch is final")
	eq(#Rules.rescue(s, 3, 2), 0, "no second rescue")
	eq(s.status[2], "Downed")
end)

test("rescue: not by the safe, the downed or a catcher", function()
	local s = game(5)
	Rules.tag(s, 1, 2)
	Rules.tag(s, 1, 3)
	Rules.reachSafe(s, 4)
	eq(#Rules.rescue(s, 4, 2), 0, "safe runner")
	eq(#Rules.rescue(s, 3, 2), 0, "downed runner")
	eq(#Rules.rescue(s, 1, 2), 0, "catcher")
	eq(#Rules.rescue(s, 5, 5), 0, "self")
	eq(s.status[2], "Downed")
end)

test("round over only when nobody is still running", function()
	local s = game(4)
	Rules.tag(s, 1, 2)
	eq(Rules.isRoundOver(s), false)
	Rules.reachSafe(s, 3)
	Rules.reachSafe(s, 4)
	eq(Rules.isRoundOver(s), true)
end)

test("everyone across: the streak grows", function()
	local s = game(3)
	allSafe(s)
	local e = Rules.endRound(s)
	eq(has(e, "Streak").count, 1)
	eq(s.streak, 1)
end)

test("anyone down: the streak resets and they join the catchers", function()
	local s = game(4)
	allSafe(s)
	Rules.endRound(s)
	Rules.startRound(s)
	Rules.tag(s, 1, 4)
	Rules.reachSafe(s, 2)
	Rules.reachSafe(s, 3)
	local e = Rules.endRound(s)
	eq(has(e, "StreakLost").count, 1)
	eq(has(e, "JoinCatchers").ids[1], 4)
	eq(s.streak, 0)
	Rules.startRound(s)
	eq(s.roles[4], "Catcher")
	eq(s.roles[2], "Runner")
end)

test("a rescued runner doesn't break the streak", function()
	local s = game(4)
	Rules.tag(s, 1, 2)
	Rules.rescue(s, 3, 2)
	allSafe(s)
	local e = Rules.endRound(s)
	eq(has(e, "Streak").count, 1)
end)

test("runners still out at the timeout are caught", function()
	local s = game(3)
	Rules.reachSafe(s, 2)
	local e = Rules.endRound(s, true)
	eq(has(e, "Caught").id, 3)
	eq(has(e, "Caught").by, nil)
	eq(s.status[3], "Downed")
	eq(s.streak, 0)
end)

test("3 full crossings in a row: runners win; the Hero with her keeps her", function()
	local s = game(3)
	Rules.pickRunner(s)
	Rules.choose(s, 2, true)
	Rules.reachSafe(s, 2)
	for _ = 1, 3 do
		allSafe(s)
		local e = Rules.endRound(s)
		if s.over then
			local w = has(e, "Win")
			eq(w.team, "Runners")
			eq(w.winner, 2)
			eq(w.reason, "Crossed")
			return
		end
		Rules.startRound(s)
	end
	error("runners should have won after 3")
end)

test("runners win with nobody holding her: the last Hero, else a runner who made it", function()
	local s = game(3, { crossings = 1 })
	allSafe(s)
	local e = Rules.endRound(s)
	local w = has(e, "Win")
	eq(w.team, "Runners")
	eq(s.roles[w.winner], "Runner")
end)

test("Chicken gets nothing: a runner who chose Chicken isn't handed her at the end", function()
	local s = game(3, { crossings = 1 })
	Rules.pickRunner(s)
	local chicken = s.picked
	Rules.choose(s, chicken, false)
	allSafe(s)
	local w = has(Rules.endRound(s), "Win")
	eq(w.team, "Runners")
	eq(w.winner ~= chicken, true, "the other runner gets her, not the one who chose Chicken")
	eq(s.roles[w.winner], "Runner")
end)

test("Chicken gets nothing: alone, choosing Chicken means nobody wins her", function()
	local s = game(2, { crossings = 1 })
	Rules.pickRunner(s)
	Rules.choose(s, 2, false)
	allSafe(s)
	local w = has(Rules.endRound(s), "Win")
	eq(w.team, "Runners")
	eq(w.winner, nil)
end)

test("Chicken gets nothing, but one Hero run keeps the claim: Hero earlier, Chicken later still wins her", function()
	local s = game(2, { crossings = 1 })
	Rules.pickRunner(s)
	Rules.choose(s, 2, true) -- an earlier round: went Hero
	s.choice, s.hero, s.picked, s.lastHero = nil, nil, 2, nil
	Rules.choose(s, 2, false) -- this round: Chicken
	allSafe(s)
	local w = has(Rules.endRound(s), "Win")
	eq(w.winner, 2)
end)

test("a random pick for a runner who didn't answer isn't a Chicken choice", function()
	local s = game(2, { crossings = 1, random = function(n) return math.min(n, 2) end }) -- (random 2 = Chicken)
	Rules.pickRunner(s)
	Rules.choose(s, s.picked, nil)
	eq(s.choice, "Chicken")
	allSafe(s)
	local w = has(Rules.endRound(s), "Win")
	eq(w.winner, 2)
end)

test("all runners caught: catchers win; the lead catcher takes her", function()
	local s = game(3)
	Rules.tag(s, 1, 2)
	Rules.tag(s, 1, 3)
	local e = Rules.endRound(s)
	local w = has(e, "Win")
	eq(w.team, "Catchers")
	eq(w.winner, 1)
	eq(w.reason, "AllCaught")
end)

test("catchers win holding her: the thief keeps her", function()
	local s = game(4)
	Rules.pickRunner(s)
	Rules.choose(s, 2, true)
	Rules.reachSafe(s, 2) -- 2 has her
	allSafe(s)
	Rules.endRound(s)
	Rules.startRound(s)
	-- 1 is lead; runner 4 joins the catchers next round and is the one who steals her
	Rules.tag(s, 1, 4)
	Rules.reachSafe(s, 2)
	Rules.reachSafe(s, 3)
	Rules.endRound(s)
	Rules.startRound(s)
	eq(s.roles[4], "Catcher")
	Rules.tag(s, 4, 2)
	eq(s.holder, 4)
	Rules.tag(s, 1, 3)
	local e = Rules.endRound(s)
	local w = has(e, "Win")
	eq(w.team, "Catchers")
	eq(w.winner, 4)
end)

test("max rounds: catchers win", function()
	local s = game(3, { maxRounds = 1 })
	Rules.tag(s, 1, 2)
	Rules.reachSafe(s, 3)
	local e = Rules.endRound(s)
	eq(has(e, "Win").reason, "MaxRounds")
	eq(has(e, "Win").team, "Catchers")
end)

test("no catchers left: a runner (not her carrier) takes over", function()
	local s = game(4)
	Rules.removePlayer(s, 1)
	allSafe(s)
	Rules.endRound(s)
	local e = Rules.startRound(s)
	local nc = has(e, "NewCatcher")
	eq(nc ~= nil, true)
	eq(s.roles[nc.id], "Catcher")
end)

test("solo: no catcher, three crossings win", function()
	local s = game(1)
	eq(s.roles[1], "Catcher") -- (game() makes 1 the catcher: use a fresh solo game)
	local solo = Rules.newGame({ 7 }, nil, { random = first })
	Rules.startRound(solo)
	for _ = 1, 3 do
		Rules.pickRunner(solo)
		Rules.choose(solo, 7, true)
		Rules.reachSafe(solo, 7)
		Rules.endRound(solo)
		if solo.over then break end
		Rules.startRound(solo)
	end
	eq(solo.over, true)
	eq(solo.team, "Runners")
	eq(solo.winner, 7)
end)

test("her carrier leaves: she goes back up", function()
	local s = game(4)
	Rules.pickRunner(s)
	Rules.choose(s, 2, true)
	Rules.reachSafe(s, 2)
	local e = Rules.removePlayer(s, 2)
	eq(has(e, "GirlMoved").reason, "Dropped")
	eq(s.holder, nil)
end)

test("a thief leaves: another catcher inherits her", function()
	local s = game(5)
	s.roles[5] = "Catcher"
	s.status[5] = nil
	Rules.pickRunner(s)
	Rules.choose(s, 2, true)
	Rules.reachSafe(s, 2)
	allSafe(s)
	Rules.endRound(s)
	Rules.startRound(s)
	Rules.tag(s, 1, 2)
	local e = Rules.removePlayer(s, 1)
	eq(has(e, "GirlMoved").reason, "Reassigned")
	eq(s.holder, 5)
end)

test("the picked runner leaving clears the pick", function()
	local s = game(4)
	Rules.pickRunner(s)
	Rules.removePlayer(s, 2)
	eq(s.picked, nil)
end)

test("nothing happens after the game is over", function()
	local s = game(2)
	Rules.tag(s, 1, 2)
	Rules.endRound(s)
	eq(s.over, true)
	eq(#Rules.startRound(s), 0)
	eq(#Rules.tag(s, 1, 2), 0)
	eq(#Rules.reachSafe(s, 2), 0)
end)

test("stalling: only when every runner still to cross is in the start zone", function()
	local s = game(4) -- runners 2, 3, 4
	eq(Rules.stalling(s, {}), false, "nobody in the start")
	eq(Rules.stalling(s, { [2] = true, [3] = true }), false, "one runner is out on the field")
	eq(Rules.stalling(s, { [2] = true, [3] = true, [4] = true }), true, "all three wait in the start")
	Rules.reachSafe(s, 3)
	Rules.tag(s, 1, 4)
	eq(Rules.stalling(s, { [2] = true }), true, "the last one still to cross waits (safe and downed don't count)")
	Rules.reachSafe(s, 2)
	eq(Rules.stalling(s, { [2] = true }), false, "nobody left to cross")
end)

test("stalling: a Hero's solo run only looks at the Hero", function()
	local s = game(4)
	Rules.pickRunner(s)
	Rules.choose(s, s.picked, true)
	local hero = s.hero
	eq(Rules.stalling(s, { [hero] = true }, hero), true, "the Hero stays in the start")
	local walked = { [2] = true, [3] = true, [4] = true }
	walked[hero] = nil
	eq(Rules.stalling(s, walked, hero), false, "the Hero went (the others wait on the line)")
end)

test("last runner: the only runner still out, else nil", function()
	local s = game(4)
	eq(Rules.lastRunner(s), nil, "three still out")
	Rules.reachSafe(s, 2)
	eq(Rules.lastRunner(s), nil, "two still out")
	Rules.tag(s, 1, 3)
	eq(Rules.lastRunner(s), 4, "runner 4 is the last one out")
	Rules.rescue(s, 4, 3)
	eq(Rules.lastRunner(s), nil, "a rescue brings a second runner back")
	Rules.reachSafe(s, 3)
	Rules.reachSafe(s, 4)
	eq(Rules.lastRunner(s), nil, "nobody left")
end)

print(`RoundRules: {passed} passed, {failed} failed`)
if failed > 0 then
	error("RoundRules tests failed")
end
