-- Daily quests (Shared/DailyRules, Config/DailyQuests; owner, Oct 19: "add easy quests as in this photo and make new
-- ones everyday then recycle them"). Run from huzz-valley/ or the repo root: lune run tests/DailyRules.spec.luau
local Env = require("../tools/preview/motion3d/env")
local DailyRules = Env.load("huzz-valley/src/ReplicatedStorage/Shared/DailyRules.lua")
local DailyQuests = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/DailyQuests.lua")
local Progression = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/Progression.lua")

local passed, failed = 0, 0
local function check(name, cond)
	if cond then passed += 1 else failed += 1; print("FAIL " .. name) end
end

local DAY, SLOT = DailyQuests.DayLength, DailyQuests.SlotLength
local T0 = 20380 * DAY + 5 * 3600 -- a morning (05:00 UTC)

-- the config: easy, real stats, rewards that exist
for _, list in { DailyQuests.Daily, DailyQuests.Spin } do
	for _, q in list do
		check(q.Id .. " counts a real stat", table.find(Progression.Stats, q.Stat) ~= nil)
		check(q.Id .. " is easy (small target)", q.Target >= 1 and q.Target <= 30)
		check(q.Id .. " has a reward", q.Reward and (q.Reward.Kind == "Coins" or q.Reward.Kind == "Aura" or q.Reward.Kind == "Spin") and q.Reward.Amount > 0)
	end
end
for _, q in DailyQuests.Spin do check(q.Id .. " gives a spin", q.Reward.Kind == "Spin") end

-- each day: two different-stat quests, the same for everyone, new from yesterday; the pool comes round again
local seen, sameAsYesterday, prev = {}, 0, nil
for d = 20000, 20089 do
	local p = DailyRules.picks(d)
	check("day " .. d .. ": two quests", #p == 2)
	local a, b = DailyQuests.get(p[1]), DailyQuests.get(p[2])
	check("day " .. d .. ": different stats", a and b and a.Stat ~= b.Stat)
	check("day " .. d .. ": the same picks every time", DailyRules.picks(d)[1] == p[1] and DailyRules.picks(d)[2] == p[2])
	if prev and (p[1] == prev[1] or p[1] == prev[2] or p[2] == prev[1] or p[2] == prev[2]) then sameAsYesterday += 1 end
	for _, id in p do seen[id] = true end
	prev = p
end
local n = 0
for _ in seen do n += 1 end
check(`every daily quest comes round in 90 days ({n} of {#DailyQuests.Daily})`, n == #DailyQuests.Daily)
check(`a day never repeats yesterday's quests ({sameAsYesterday})`, sameAsYesterday == 0)
-- the spin quest: never the same twice in a row, all of them in turn
local spinSeen, repeats, sameStat = {}, 0, 0
for s = 1000, 1239 do
	local id = DailyRules.slotPick(s)
	spinSeen[id] = true
	if DailyRules.slotPick(s + 1) == id then repeats += 1 end
	local day = (s * SLOT) // DAY
	for _, did in DailyRules.picks(day) do
		if DailyQuests.get(did).Stat == DailyQuests.get(id).Stat then sameStat += 1 end
	end
end
check(`the spin quest never counts the same thing as that day's quests ({sameStat})`, sameStat == 0)
local m = 0
for _ in spinSeen do m += 1 end
check(`every spin quest comes round ({m})`, m == #DailyQuests.Spin)
check("the spin quest changes every slot", repeats == 0)

-- clocks: the reset is midnight UTC, the spin quest every 2 hours
check("resets in 19 h at 05:00 UTC", DailyRules.resetIn(T0) == 19 * 3600)
check("next spin quest in 1 h at 05:00", DailyRules.slotIn(T0) == 3600)
check("clock text", DailyRules.clock(9 * 3600 + 28 * 60 + 5) == "9h 28m" and DailyRules.clock(28 * 60) == "28m" and DailyRules.clock(45) == "45s")

-- progress: only its own stat, capped, only from when it appears; claim once; new day = new quests at 0
local st = DailyRules.roll(nil, T0)
local d1 = DailyQuests.get(st.Q.D1.Id)
check("starts at 0", st.Q.D1.Have == 0 and st.Q.D2.Have == 0 and st.Q.S.Have == 0)
local other = "Steals"
DailyRules.add(st, other, 5, T0)
check("another stat moves nothing", st.Q.D1.Have == 0)
local r, why = DailyRules.claim(st, "D1", T0)
check("can't claim before it's done", r == nil and why == "Not finished yet.")
DailyRules.add(st, d1.Stat, d1.Target + 50, T0 + 10)
check("progress is capped at the target", st.Q.D1.Have == d1.Target)
r = DailyRules.claim(st, "D1", T0 + 20)
check("claim gives the reward", r ~= nil and r.Kind == d1.Reward.Kind and r.Amount == d1.Reward.Amount)
r, why = DailyRules.claim(st, "D1", T0 + 30)
check("only once", r == nil and why == "Already claimed.")
check("unknown key refused", (DailyRules.claim(st, "D9", T0)) == nil)
local view = DailyRules.view(st, T0 + DAY)
local d1v
for _, v in view do if v.key == "D1" then d1v = v end end
check("the window lists the spin quest first (his picture d)", view[1].key == "S")
check("tomorrow's view shows new quests at 0", d1v and d1v.have == 0 and d1v.done == false and d1v.quest.Id == DailyRules.picks(DailyRules.day(T0 + DAY))[1])
check("the view doesn't change the save", st.Q.D1.Done == true and st.Day == DailyRules.day(T0))
local spinId = st.Q.S.Id
DailyRules.roll(st, T0 + SLOT)
check("a new slot changes only the spin quest", st.Q.S.Id ~= spinId and st.Q.D1.Done == true)
DailyRules.roll(st, T0 + DAY)
check("a new day resets the daily quests", st.Q.D1.Done == false and st.Q.D1.Have == 0)
-- the HUD dot
local s2 = DailyRules.roll(nil, T0)
check("nothing ready at first", DailyRules.ready(s2, T0) == 0)
local sq = DailyQuests.get(s2.Q.S.Id)
DailyRules.add(s2, sq.Stat, sq.Target, T0)
check("one ready when the spin quest is done", DailyRules.ready(s2, T0) >= 1)

-- every saved quest counter goes through ProgressService.addStat, which also moves the daily quests (RoundService and
-- the Aura stars wrote Stats themselves, so no game event reached the daily quests: critic, Oct 19)
local fs = require("@lune/fs")
local function scan(dir)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			scan(path)
		elseif string.match(name, "%.lua$") and name ~= "ProgressService.lua" then
			local src = fs.readFile(path)
			check(name .. " writes no quest counter itself", not string.find(src, "Stats%[[^%]]+%]%s*=") and not string.find(src, "Stats%.%a+%s*=%s*%("))
		end
	end
end
local here = if fs.isDir("src") then "src" else "huzz-valley/src"
scan(here .. "/ServerScriptService")

print(string.format("DailyRules: %d passed, %d failed", passed, failed))
if failed > 0 then error("DailyRules spec failed") end
