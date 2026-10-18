-- Lobby leaderboards and avatar stands: the value text like Huss Valley's boards ("LEVEL 402", "2611" + trophy,
-- "231.1K COINS"), the order (biggest first, one row per player, cut to 50), each save's numbers, the default spots,
-- the slow turn, and the stand rule: a purchase opens only for a real Game Pass ID of a pass the game already grants
-- ("coming soon" otherwise).  lune run tests/Leaderboards.spec.luau   (from huzz-valley/)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Rules = require("../src/ReplicatedStorage/Shared/LeaderboardRules")
local Stand = require("../src/ReplicatedStorage/Shared/AvatarStandRules")
local Config = require("../src/ReplicatedStorage/Shared/Config/Leaderboards")
local function loadProducts(patch)
	local src = fs.readFile("src/ReplicatedStorage/Shared/Config/Products.lua")
	if patch then src = patch(src) end
	return luau.load(src, { debugName = "Products", environment = { Color3 = roblox.Color3 } })()
end
local Products = loadProducts()

local passed, failed = 0, 0
local function check(name, cond)
	if cond then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local function eq(name, got, want)
	check(name .. " (got " .. tostring(got) .. ")", got == want)
end

-- numbers
eq("0", Rules.compact(0), "0")
eq("874", Rules.compact(874), "874")
eq("999", Rules.compact(999), "999")
eq("1000", Rules.compact(1000), "1.0K")
eq("33.5K", Rules.compact(33512), "33.5K")
eq("231.1K never rounds up", Rules.compact(231199), "231.1K")
eq("999999", Rules.compact(999999), "999.9K")
eq("2.4M", Rules.compact(2400000), "2.4M")
eq("negative", Rules.compact(-5), "0")
local byStat = {}
for _, def in Config.Boards do byStat[def.Stat] = def end
local level, wins, catches = byStat.Level, byStat.Wins, byStat.Catches
eq("level", (Rules.format(level, 402)), "LEVEL 402")
local t, icon = Rules.format(wins, 2611)
eq("wins text", t, "2611")
eq("wins trophy", icon, "RewardsTrophy")
eq("catches", (Rules.format(catches, 30512)), "30.5K CATCHES")
eq("catches small", (Rules.format(catches, 874)), "874 CATCHES")
eq("unit board has no icon", select(2, Rules.format(catches, 5)), nil)

-- order
local saved = { { u = 1, n = "a", v = 50 }, { u = 2, n = "b", v = 80 }, { u = 3, n = "", v = 80 } }
local here = { { u = 1, n = "a", v = 70 }, { u = 3, n = "c", v = 10 }, { u = 4, n = "d", v = 0 } }
local r = Rules.rank({ here, saved }, 50)
eq("one row per player", #r, 4)
eq("biggest first", r[1].v, 80)
eq("tie: first seen wins (3 was in the live list first)", r[1].u, 3)
eq("tie order", r[2].u, 2)
eq("live value beats an older saved one", r[3].u, 1)
eq("live value kept", r[3].v, 70)
eq("a known name fills a blank one", r[1].n, "c")
eq("zero rows still show (never empty)", r[4].u, 4)
local many = {}
for i = 1, 80 do table.insert(many, { u = i, n = "p" .. i, v = i }) end
local top = Rules.rank({ many }, Config.Top)
eq("cut to 50", #top, 50)
eq("top is the biggest", top[1].u, 80)
eq("50th", top[50].u, 31)
check("bad rows dropped", #Rules.rank({ { { u = "x", v = 1 }, { u = 5, v = 0 / 0 }, { u = 6, v = -1 } } }, 50) == 0)

-- numbers from a save
local v = Rules.values({ XP = 905, Stats = { Wins = 3, Catches = 12 }, Characters = { a = 1, b = 2, c = 3 } }, 300)
eq("level from XP", v.Level, 4)
eq("wins", v.Wins, 3)
eq("catches", v.Catches, 12)
eq("rescues missing = 0", v.Rescues, 0)
eq("girls counted", v.Girls, 3)
eq("new save is level 1", Rules.values({}, 300).Level, 1)
check("every board has a value", (function()
	for _, def in Config.Boards do if v[def.Stat] == nil then return false end end
	return true
end)())

-- default spots: inside the floor, apart, along the back edge
local spots = Rules.defaultSpots(100, 100, #Config.Boards)
eq("five spots", #spots, 5)
check("spots inside the floor", math.abs(spots[1].X) + Config.Size.X / 2 <= 50 and spots[1].Z + 2 <= 50)
check("spots don't overlap", spots[2].X - spots[1].X >= Config.Size.X + 1)
check("behind the spawn (z +25)", spots[1].Z > 25 + 10)

local two = Rules.defaultSpots(100, 100, 2)
check("two spots clear the hoop behind the spawn", math.abs(two[1].X) - Config.Size.X / 2 > 6.5 and math.abs(two[2].X) - Config.Size.X / 2 > 6.5)
check("two spots inside the floor", math.abs(two[2].X) + Config.Size.X / 2 <= 50)

-- the turn
local yaw = Rules.yawTo(0, 0, 0, -10)
check("facing -Z is yaw 0", math.abs(yaw) < 1e-9)
check("facing +X", math.abs(Rules.yawTo(0, 0, 10, 0) - (-math.pi / 2)) < 1e-9)
local cur = 0
cur = Rules.turn(cur, 1, 1 / 30, Config.TurnRate)
check("turns a little each frame (lag)", cur > 0 and cur < 0.2)
for _ = 1, 300 do cur = Rules.turn(cur, 1, 1 / 30, Config.TurnRate) end
check("catches up", math.abs(cur - 1) < 0.01)
local wrap = Rules.turn(3.0, -3.0, 1 / 30, Config.TurnRate)
check("short way round", wrap > 3.0 or wrap < -3.1)

-- avatar stands: "Coming soon unless a real Id of a pass the game grants"
local s = Stand.resolve({ Pass = "VIP" }, Products)
eq("VIP has Id 0 today: soon", s.Status, "Soon")
check("soon never prompts", not Stand.canPrompt(s, false))
eq("soon button shows price", (Stand.button(s, false)), "199 · SOON")
eq("title from the pass", s.Title, "VIP")
eq("default tag", s.Tag, "GAME PASS")
s = Stand.resolve({ Pass = "DancePack" }, Products)
eq("Dance Pack gives nothing yet", s.Status, "Soon")
s = Stand.resolve({ Pass = "123456789" }, Products)
eq("an ID that isn't one of our passes: soon", s.Status, "Soon")
check("unknown ID never prompts", not Stand.canPrompt(s, false))
eq("unknown ID, no price: COMING SOON", (Stand.button(s, false)), "COMING SOON")
s = Stand.resolve({}, Products)
eq("no Pass: soon", s.Status, "Soon")
s = Stand.resolve({ Pass = "Coins500" }, Products)
eq("a developer product isn't a pass", s.Status, "Soon")
-- with a real ID pasted for VIP (and VIP on sale), it's for sale, by key or by number
local Live = loadProducts(function(src)
	return (src:gsub('Key = "VIP", Kind = "Pass", Name = "VIP", Blurb = "VIP chat tag\\nand name tag.",\n%s*Id = 0', function(m) return (m:gsub("Id = 0$", "Id = 98765")) end))
end)
check("patched VIP id", Live.get("VIP").Id == 98765)
s = Stand.resolve({ Pass = "VIP", Title = "vip pass", Subtitle = "Chat tag" }, Live)
eq("real ID + on sale: ready", s.Status, "Ready")
eq("id", s.Id, 98765)
check("ready prompts", Stand.canPrompt(s, false))
check("owned never prompts", not Stand.canPrompt(s, true))
eq("owned button", (Stand.button(s, true)), "OWNED")
eq("ready button", (Stand.button(s, false, 1799)), "1,799 · VIEW")
eq("typed title in caps", s.Title, "VIP PASS")
eq("typed subtitle", s.Subtitle, "CHAT TAG")
s = Stand.resolve({ Pass = 98765 }, Live)
eq("by number too", s.Status, "Ready")
eq("number finds the key", s.Key, "VIP")
check("no timer or scarcity words", (function()
	for _, word in { "LIMITED", "ENDS", "LEFT", "HURRY" } do
		local x = Stand.resolve({ Pass = "VIP" }, Live)
		if string.find(x.Tag .. x.Title .. x.Subtitle, word) then return false end
	end
	return true
end)())

print(string.format("Leaderboards spec: %d passed, %d failed", passed, failed))
if failed > 0 then error("Leaderboards spec failed") end
