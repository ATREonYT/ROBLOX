-- lune run tests/RoundRules.spec.luau
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
-- players 1..n; player 1 catches round 1
local function game(n, maxRounds, pickup)
	local ids = {}
	for i = 1, n do
		table.insert(ids, i)
	end
	local s = Rules.newGame(ids, 1, { random = first, maxRounds = maxRounds, pickup = pickup or "FirstAcross" })
	Rules.startRound(s)
	return s
end

test("first across takes the girl", function()
	local s = game(4)
	local ev = Rules.reachSafe(s, 3)
	local m = has(ev, "GirlMoved")
	eq(m.to, 3, "to")
	eq(m.from, nil, "from")
	eq(s.holder, 3)
	eq(has(Rules.reachSafe(s, 2), "GirlMoved"), nil, "second across moves nothing")
end)

test("tagged runners catch next round, safe ones run", function()
	local s = game(4)
	Rules.reachSafe(s, 2)
	Rules.tag(s, 1, 3)
	Rules.reachSafe(s, 4)
	eq(Rules.isRoundOver(s), true)
	Rules.endRound(s, false)
	Rules.startRound(s)
	eq(s.roles[3], "Catcher")
	eq(s.roles[1], "Catcher")
	eq(s.status[2], "Active")
	eq(s.status[4], "Active")
	eq(s.round, 2)
end)

test("first across next round takes her from the holder", function()
	local s = game(4)
	Rules.reachSafe(s, 2)
	Rules.reachSafe(s, 3)
	Rules.reachSafe(s, 4)
	Rules.endRound(s, false)
	Rules.startRound(s)
	local m = has(Rules.reachSafe(s, 4), "GirlMoved")
	eq(m.from, 2)
	eq(m.to, 4)
end)

test("holder first across keeps her", function()
	local s = game(3)
	Rules.reachSafe(s, 2)
	Rules.reachSafe(s, 3)
	Rules.endRound(s, false)
	Rules.startRound(s)
	eq(has(Rules.reachSafe(s, 2), "GirlMoved"), nil)
	eq(s.holder, 2)
end)

test("catcher tags holder: steals her, rescue makes next round final, crossing wins", function()
	local s = game(4)
	Rules.reachSafe(s, 2) -- 2 holds
	Rules.reachSafe(s, 3)
	Rules.reachSafe(s, 4)
	Rules.endRound(s, false)
	Rules.startRound(s) -- round 2: runners 2,3,4
	local ev = Rules.tag(s, 1, 2)
	eq(has(ev, "GirlMoved").to, 1, "thief")
	eq(s.phase, "Stolen")
	eq(Rules.tag(s, 1, 2)[1], nil, "can't tag twice")
	ev = Rules.reachSafe(s, 3)
	eq(has(ev, "GirlMoved").to, 3, "rescued")
	eq(s.phase, "FinalNext")
	Rules.reachSafe(s, 4)
	Rules.endRound(s, false)
	ev = Rules.startRound(s)
	eq(has(ev, "FinalRound").runner, 3)
	eq(Rules.reachSafe(s, 4)[2], nil, "others crossing changes nothing")
	ev = Rules.reachSafe(s, 3)
	eq(has(ev, "Win").winner, 3)
	eq(s.over, true)
end)

test("final round: holder caught, the tagger wins", function()
	local s = game(4)
	Rules.reachSafe(s, 2)
	Rules.reachSafe(s, 3)
	Rules.reachSafe(s, 4)
	Rules.endRound(s, false)
	Rules.startRound(s)
	Rules.tag(s, 1, 2) -- 1 steals
	Rules.reachSafe(s, 3) -- 3 rescues
	Rules.reachSafe(s, 4)
	Rules.endRound(s, false)
	Rules.startRound(s) -- final; catchers 1 and 2
	local ev = Rules.tag(s, 2, 3)
	eq(has(ev, "Win").winner, 2)
end)

test("final round: holder runs out of time, the thief wins", function()
	local s = game(3)
	Rules.reachSafe(s, 2)
	Rules.reachSafe(s, 3)
	Rules.endRound(s, false)
	Rules.startRound(s)
	Rules.tag(s, 1, 2)
	Rules.reachSafe(s, 3)
	Rules.endRound(s, false)
	Rules.startRound(s)
	local ev = Rules.endRound(s, true)
	eq(has(ev, "Win").winner, 1)
end)

test("stolen and nobody crosses: the thief wins", function()
	local s = game(3)
	Rules.reachSafe(s, 2)
	Rules.reachSafe(s, 3)
	Rules.endRound(s, false)
	Rules.startRound(s)
	Rules.tag(s, 1, 2)
	Rules.tag(s, 1, 3)
	local ev = Rules.endRound(s, false)
	eq(has(ev, "Win").winner, 1)
end)

test("everyone caught in round 1: nobody wins", function()
	local s = game(3)
	Rules.tag(s, 1, 2)
	Rules.tag(s, 1, 3)
	local ev = Rules.endRound(s, false)
	local w = has(ev, "Win")
	eq(w ~= nil, true, "game over")
	eq(w.winner, nil)
end)

test("holder alone among runners: final round", function()
	local s = game(3)
	Rules.reachSafe(s, 2)
	Rules.tag(s, 1, 3)
	Rules.endRound(s, false)
	local ev = Rules.startRound(s)
	eq(has(ev, "FinalRound").runner, 2)
	eq(has(Rules.reachSafe(s, 2), "Win").winner, 2)
end)

test("lone holder after a takeover runs a final round", function()
	local s = game(3)
	Rules.reachSafe(s, 2)
	Rules.reachSafe(s, 3)
	Rules.endRound(s, false)
	Rules.startRound(s)
	Rules.reachSafe(s, 3) -- 3 takes her
	Rules.endRound(s, false)
	Rules.startRound(s) -- round 3: runner 3 alone and holder => final
	eq(s.phase, "Final")
end)

test("runner dying with the girl in an open round drops her", function()
	local s = game(4)
	Rules.reachSafe(s, 2)
	Rules.reachSafe(s, 3)
	Rules.reachSafe(s, 4)
	Rules.endRound(s, false)
	Rules.startRound(s)
	local ev = Rules.tag(s, nil, 2)
	eq(has(ev, "GirlMoved").to, nil)
	eq(s.phase, "Open")
	eq(has(Rules.reachSafe(s, 4), "GirlMoved").to, 4, "next across picks her up")
end)

test("solo test: cross, then cross again to win", function()
	local s = Rules.newGame({ 7 }, nil, { random = first, pickup = "FirstAcross" })
	Rules.startRound(s)
	Rules.reachSafe(s, 7)
	Rules.endRound(s, false)
	local ev = Rules.startRound(s)
	eq(has(ev, "FinalRound").runner, 7)
	eq(has(Rules.reachSafe(s, 7), "Win").winner, 7)
end)

test("solo test: time out in the final round, nobody wins", function()
	local s = Rules.newGame({ 7 }, nil, { random = first, pickup = "FirstAcross" })
	Rules.startRound(s)
	Rules.reachSafe(s, 7)
	Rules.endRound(s, false)
	Rules.startRound(s)
	local w = has(Rules.endRound(s, true), "Win")
	eq(w.winner, nil)
	eq(s.over, true)
end)

test("catcher leaves: a non-holder runner becomes catcher", function()
	local s = game(4)
	Rules.reachSafe(s, 2)
	Rules.reachSafe(s, 3)
	Rules.reachSafe(s, 4)
	Rules.endRound(s, false)
	Rules.removePlayer(s, 1)
	local ev = Rules.startRound(s)
	eq(has(ev, "NewCatcher").id, 3)
	eq(s.roles[2], "Runner", "holder keeps running")
end)

test("thief leaves: another catcher inherits her", function()
	local s = game(4)
	Rules.tag(s, 1, 4) -- 4 catches next round
	Rules.reachSafe(s, 2)
	Rules.reachSafe(s, 3)
	Rules.endRound(s, false)
	Rules.startRound(s)
	Rules.tag(s, 1, 2)
	local ev = Rules.removePlayer(s, 1)
	eq(has(ev, "GirlMoved").to, 4, "the other catcher")
	eq(s.thief, 4)
end)

test("holder leaves during final: catchers win", function()
	local s = game(3)
	Rules.reachSafe(s, 2)
	Rules.tag(s, 1, 3)
	Rules.endRound(s, false)
	Rules.startRound(s) -- final for 2
	local ev = Rules.removePlayer(s, 2)
	eq(has(ev, "Win").winner, 1)
end)

test("max rounds: the holder wins", function()
	local s = game(3, 1)
	Rules.reachSafe(s, 2)
	Rules.reachSafe(s, 3)
	eq(has(Rules.endRound(s, false), "Win").winner, 2)
end)

test("no tagging from non-catchers or of safe runners", function()
	local s = game(3)
	eq(#Rules.tag(s, 2, 3), 0)
	Rules.reachSafe(s, 3)
	eq(#Rules.tag(s, 1, 3), 0)
end)

-- Pickup "Grab": she waits in the middle and the first runner to reach her grabs her.
test("grab: crossing without her takes nothing; first runner to reach her grabs her", function()
	local s = game(4, nil, "Grab")
	eq(has(Rules.reachSafe(s, 4), "GirlMoved"), nil, "crossing empty-handed moves nothing")
	eq(#Rules.grab(s, 1), 0, "catchers can't grab")
	eq(#Rules.grab(s, 4), 0, "safe runners can't grab")
	local m = has(Rules.grab(s, 2), "GirlMoved")
	eq(m.to, 2)
	eq(m.reason, "Grabbed")
	eq(#Rules.grab(s, 3), 0, "she's taken")
	Rules.reachSafe(s, 2)
	Rules.reachSafe(s, 3)
	Rules.endRound(s, false)
	Rules.startRound(s)
	eq(has(Rules.reachSafe(s, 3), "GirlMoved"), nil, "first across doesn't take her from her holder")
	eq(s.holder, 2)
end)

test("grab: tag steals her, first across rescues, final round as before", function()
	local s = game(3, nil, "Grab")
	Rules.grab(s, 2)
	Rules.tag(s, 1, 2)
	eq(s.phase, "Stolen")
	eq(has(Rules.reachSafe(s, 3), "GirlMoved").reason, "Rescued")
	Rules.endRound(s, false)
	local ev = Rules.startRound(s)
	eq(has(ev, "FinalRound").runner, 3)
end)

test("grab: dropped by the clock, she waits to be grabbed again", function()
	local s = game(4, nil, "Grab")
	Rules.grab(s, 2)
	Rules.reachSafe(s, 3)
	Rules.reachSafe(s, 4)
	Rules.endRound(s, true) -- 2 timed out holding her
	eq(s.holder, nil)
	Rules.startRound(s)
	eq(has(Rules.grab(s, 3), "GirlMoved").to, 3)
end)

test("grab: solo grabs, crosses, crosses back to win", function()
	local s = Rules.newGame({ 7 }, nil, { random = first, pickup = "Grab" })
	Rules.startRound(s)
	Rules.grab(s, 7)
	Rules.reachSafe(s, 7)
	Rules.endRound(s, false)
	eq(has(Rules.startRound(s), "FinalRound").runner, 7)
	eq(has(Rules.reachSafe(s, 7), "Win").winner, 7)
end)

test("heroes: a chicken across first doesn't get her, the first hero does", function()
	local s = Rules.newGame({ 1, 2, 3 }, 1, { random = first, heroes = true })
	Rules.startRound(s)
	Rules.setHero(s, 3, true)
	eq(has(Rules.reachSafe(s, 2), "GirlMoved"), nil)
	eq(has(Rules.reachSafe(s, 3), "GirlMoved").to, 3)
end)

test("heroes: no hero across, the first chicken gets her at the end of the round", function()
	local s = Rules.newGame({ 1, 2, 3 }, 1, { random = first, heroes = true })
	Rules.startRound(s)
	Rules.setHero(s, 3, true)
	Rules.reachSafe(s, 2) -- chicken
	Rules.tag(s, 1, 3) -- the hero is caught
	local ev = Rules.endRound(s, false)
	local moved = has(ev, "GirlMoved")
	eq(moved.to, 2)
	eq(moved.reason, "NoHero")
end)

test("heroes: her holder is always a hero; a stolen girl goes to a chicken if no hero crosses", function()
	local s = Rules.newGame({ 1, 2, 3, 4 }, 1, { random = first, heroes = true })
	Rules.startRound(s)
	Rules.setHero(s, 2, true)
	Rules.reachSafe(s, 2)
	Rules.reachSafe(s, 3)
	Rules.tag(s, 1, 4)
	Rules.endRound(s, false)
	Rules.startRound(s)
	eq(s.hero[2], true) -- holding her makes 2 a hero
	Rules.tag(s, 1, 2) -- 1 steals her
	eq(s.phase, "Stolen")
	Rules.reachSafe(s, 3) -- a chicken
	local ev = Rules.endRound(s, false)
	eq(has(ev, "GirlMoved").reason, "NoHeroRescue")
	eq(s.phase, "FinalNext")
end)

print(`{passed} passed, {failed} failed`)
if failed > 0 then
	error("tests failed")
end
