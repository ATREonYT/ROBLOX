-- Lobby leaderboards and avatar stands: the value text like Huss Valley's boards ("LEVEL 402", "2611" + trophy,
-- "231.1K COINS"), the order (biggest first, one row per player, cut to 50), each save's numbers, the default spots,
-- the calm turn (limit, dead zone, critically damped ease), the face colour under the game's grade and the Halloween
-- touches, and the stand rules: a purchase opens only for a real Game Pass ID of a pass the game already grants, a stand
-- shows only a knife its pass gives, and his own place's grey blocks are found
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

-- the turn (owner, Oct 18: "make the leaderboards move smoothly, right now they move very weirdly")
local yaw = Rules.yawTo(0, 0, 0, -10)
check("facing -Z is yaw 0", math.abs(yaw) < 1e-9)
check("facing +X", math.abs(Rules.yawTo(0, 0, 10, 0) - (-math.pi / 2)) < 1e-9)
local cur = 0
cur = Rules.turn(cur, 1, 1 / 30, 2.2)
check("the plain catch-up still eases", cur > 0 and cur < 0.2)
local wrap = Rules.turn(3.0, -3.0, 1 / 30, 2.2)
check("short way round", wrap > 3.0 or wrap < -3.1)

local rad, deg = math.rad, math.deg
local MAX, BEHIND = rad(Config.TurnMax), rad(Config.TurnBehind)
check("a turn limit between 60 and 80 degrees (never edge-on, never spins)", Config.TurnMax >= 60 and Config.TurnMax <= 80)
check("boards in the other lobbies stay still (range and its ease under 150; the lobbies are 600+ apart)", Config.TurnRange + (Config.TurnFade or 0) <= 150)
check("no dead zone or slow spring left (owner: follow me in real time)", Config.DeadZone == nil and Config.TurnOmega == nil and Config.Follow == nil)
-- a board at the origin placed facing -Z (yaw 0); the boards use aimSmooth (Oct 19: no jumps)
local FADE = Config.TurnFade
check("an ease-home band past the range (no jump at its edge)", type(FADE) == "number" and FADE >= 10)
local function aimAt(x, z, lo, hi) return Rules.aimSmooth(0, 0, 0, x, z, MAX, BEHIND, Config.TurnRange, FADE, lo, hi) end
check("you straight in front: faces you", math.abs(aimAt(0, -20)) < 1e-9)
check("you 30 degrees to the side: follows", math.abs(deg(aimAt(-20 * math.sin(rad(30)), -20 * math.cos(rad(30)))) - 30) < 1e-6)
check("you 60 degrees round: still follows", math.abs(deg(aimAt(-20 * math.sin(rad(60)), -20 * math.cos(rad(60)))) - 60) < 1e-6)
check("you level with its edge (90): stops at the limit, not edge-on", math.abs(deg(aimAt(-20, 0))) <= Config.TurnMax + 1e-6)
check("you straight behind it: it looks home (old code spun 180)", math.abs(aimAt(0, 20)) < 1e-9)
check("you far away: home", math.abs(aimAt(0, -(Config.TurnRange + FADE + 1))) < 1e-9)
check("standing inside it: home (no divide by zero)", aimAt(0.2, 0.2) == 0)
check("the MOST CATCHES board turns to the spawn (114 studs off)", Config.TurnRange >= 114)
-- no jumps: walking a slow circle round it 20 studs out, and walking away through the range's edge, the aim never
-- moves more than a few degrees between two spots a tenth of a stud apart (the old aim jumped 75 at 120 degrees round
-- and at the range's edge, so standing on those lines it flicked back and forth)
do
	local worst, prev = 0, nil
	for i = 0, 7200 do
		local a = rad(i * 0.05) -- (0.05 degrees = 0.017 studs a step at 20 studs)
		local y = aimAt(-20 * math.sin(a), -20 * math.cos(a))
		if prev then worst = math.max(worst, math.abs(Rules.wrap(y - prev))) end
		prev = y
	end
	check(string.format("round it in a circle: no jumps (biggest step %.2f deg)", deg(worst)), deg(worst) < 0.5)
	local old = 0
	for i = 0, 7200 do
		local a, b = rad(i * 0.05), rad((i + 1) * 0.05)
		local y1 = Rules.aim(0, 0, 0, -20 * math.sin(a), -20 * math.cos(a), MAX, BEHIND, Config.TurnRange)
		local y2 = Rules.aim(0, 0, 0, -20 * math.sin(b), -20 * math.cos(b), MAX, BEHIND, Config.TurnRange)
		old = math.max(old, math.abs(Rules.wrap(y2 - y1)))
	end
	check(string.format("(the old aim did jump: %.0f deg)", deg(old)), deg(old) > 30)
	worst, prev = 0, nil
	for i = 0, 2000 do
		local d = 60 + i * 0.05
		local y = aimAt(-d * math.sin(rad(50)), -d * math.cos(rad(50)))
		if prev then worst = math.max(worst, math.abs(Rules.wrap(y - prev))) end
		prev = y
	end
	check(string.format("walking out of range: eases home, no jump (biggest step %.2f deg)", deg(worst)), deg(worst) < 0.5)
end
-- standing on the old flick line (120 degrees round) and bobbing a little: the board stays put
do
	local y, lo, hi = aimAt(-20 * math.sin(rad(120)), -20 * math.cos(rad(120))), math.huge, -math.huge
	for f = 1, 300 do
		local a = rad(120 + math.sin(f * 0.7) * 0.6)
		local want = aimAt(-20 * math.sin(a), -20 * math.cos(a))
		y = Rules.turn(y, want, 1 / 60, Config.TurnRate)
		if f > 30 then lo, hi = math.min(lo, y), math.max(hi, y) end
	end
	check(string.format("on the 120 degree line, bobbing: still (moves %.2f deg)", deg(hi - lo)), deg(hi - lo) < 1)
end
-- his build close behind it (the terrace boards): it turns only as far as it has room, each way
do
	local lo, hi = Rules.room(0, MAX, rad(3), function(yaw) return yaw < -rad(10) end)
	check(string.format("room: stops before the slope on one side (%.0f deg)", deg(lo)), math.abs(deg(lo) - 9) < 1e-6)
	check("room: the full turn on the free side", math.abs(hi - MAX) < 1e-9)
	local y = aimAt(20 * math.sin(rad(40)), -20 * math.cos(rad(40)), lo, hi) -- you 40 degrees round on the slope side
	check(string.format("with room 9 deg that way it turns 9, not 40 (%.1f)", deg(y)), math.abs(deg(y) + 9) < 1e-6)
	local y2 = aimAt(-20 * math.sin(rad(40)), -20 * math.cos(rad(40)), lo, hi)
	check("and the full 40 the other way", math.abs(deg(y2) - 40) < 1e-6)
	local nlo, nhi = Rules.room(0, MAX, rad(3), function() return false end)
	check("room: nothing near, the whole limit both ways", math.abs(nlo - MAX) < 1e-9 and math.abs(nhi - MAX) < 1e-9)
end
-- walking past the front at a run: it keeps facing you as you go (the old one lagged up to seconds behind), at 30 and 60 fps
for _, fps in { 30, 60 } do
	local y, worst, most, flips, lastStep = 0, 0, 0, 0, 0
	for f = 1, 4 * fps do -- 4 s, running left to right 12 studs in front at 16 studs/s
		local x = -32 + f * (16 / fps)
		local want = aimAt(x, -12)
		local before = y
		y = Rules.turn(y, want, 1 / fps, Config.TurnRate)
		local step = y - before
		if f > fps / 2 and step * lastStep < 0 then flips += 1 end -- (after it has caught up with you at the start)
		if step ~= 0 then lastStep = step end
		if f > fps / 6 then worst = math.max(worst, math.abs(Rules.wrap(y - want))) end
		most = math.max(most, math.abs(y))
	end
	check(string.format("running past at %d fps: never more than 5 degrees behind you (%.1f)", fps, deg(worst)), deg(worst) < 5)
	check(string.format("running past at %d fps: never past the limit", fps), deg(most) <= Config.TurnMax + 0.01)
	check(string.format("running past at %d fps: turns one way only, no jitter (%d reversals)", fps, flips), flips == 0)
end
-- a jump home (you walked behind it) is a quick swing, not a one-frame snap
do
	local y = Rules.turn(rad(70), 0, 1 / 60, Config.TurnRate)
	check("swinging home: not in one frame", deg(y) > 40)
	for _ = 1, 30 do y = Rules.turn(y, 0, 1 / 60, Config.TurnRate) end
	check("swinging home: done within half a second", deg(math.abs(y)) < 1)
end

-- the look: one muted slate slab like Huss Valley's in daylight (his Oct 19 screenshot; not magenta rows on a purple header), big outlined text
do
	local Look = require("../src/ReplicatedStorage/Shared/LeaderboardLook")
	local lookSrc = fs.readFile("src/ReplicatedStorage/Shared/Config/Look.lua")
	local cc = string.match(lookSrc, "ColorCorrection%s*=%s*(%b{})")
	local sat = tonumber(string.match(cc, "Saturation%s*=%s*(%-?[%d%.]+)"))
	local con = tonumber(string.match(cc, "Contrast%s*=%s*(%-?[%d%.]+)"))
	local exp = tonumber(string.match(lookSrc, "ExposureCompensation%s*=%s*(%-?[%d%.]+)"))
	local onScreen = Look.graded(Look.Colors.Face, sat, con, exp)
	local far = 0
	for i = 1, 3 do far = math.max(far, math.abs(onScreen[i] - Look.Colors.Target[i])) end
	check(string.format("the face on screen (%d, %d, %d) is the reference's slab within 6 (Config/Look's grade undone)", onScreen[1], onScreen[2], onScreen[3]), far <= 6)
	-- the old problem, under the grade it happened with (Oct 18: Saturation 0.4, Contrast 0.16, Exposure -0.05)
	local old = Look.graded({ 122, 75, 95 }, 0.4, 0.16, -0.05)
	check("the old rows' colour went magenta under the Oct 18 grade (green under 60): the test can see the old problem", old[2] < 60)
	local function chroma(c) return math.max(c[1], c[2], c[3]) - math.min(c[1], c[2], c[3]) end
	check("muted, like the reference (colourfulness under 55 on screen)", chroma(onScreen) < 55)
	check("the slab isn't see-through any more (the sky turned the header purple)", Look.SlabTransparency == 0)
	-- built with the real Roblox types (Lune): the face paints its own backdrop, rows sit on it, text is outlined
	local api = { Instance = roblox.Instance, UDim2 = roblox.UDim2, UDim = roblox.UDim, Color3 = roblox.Color3, Vector2 = roblox.Vector2,
		Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Enum = roblox.Enum, Font = roblox.Font }
	local model = Look.model(api, Config.Boards[1], roblox.CFrame.new(0, 0, 0), Config.Size, Config.Lift, Config.Subtitle, Config.Shown, true)
	local board = model:FindFirstChild("Board")
	local face = board and board:FindFirstChild("LeaderboardFace")
	local canvas = face and face:FindFirstChild("Canvas")
	local back = canvas and canvas:FindFirstChild("Backdrop")
	check("an opaque backdrop in the face colour under everything", back ~= nil and back.BackgroundTransparency == 0 and back.ZIndex == 0)
	check("studs drawn on it, one a stud (50 px)", back ~= nil and back:FindFirstChild("Studs") ~= nil and back.Studs.TileSize == roblox.UDim2.fromOffset(50, 50))
	check("the face is unlit (same colour in sun, shade or night)", face ~= nil and face.LightInfluence == 0)
	local row1 = canvas and canvas.List:FindFirstChild("Row1")
	check("rows nearly the slab's colour (no separate pink band)", row1 ~= nil and row1.BackgroundTransparency >= 0.15 and math.abs(row1.BackgroundColor3.G * 255 - Look.Colors.Face[2]) < 15)
	check("names outlined", row1 ~= nil and row1.PlayerName:FindFirstChild("Outline") ~= nil)
	check("title big like theirs (cap 33 of 900 / 0.64)", canvas ~= nil and canvas.Title.TextSize >= 50 and canvas.Title:FindFirstChild("Outline") ~= nil)
	check("top names as big as theirs", row1 ~= nil and row1.PlayerName.Fit.MaxTextSize >= 50)
	-- Halloween touches: welded to the slab (they turn with it), calm (no emitters, no scripts), lights small
	local deco = board and board:FindFirstChild("Halloween")
	check("pumpkin and candle on the slab", deco ~= nil and deco:FindFirstChild("Pumpkin") ~= nil and deco:FindFirstChild("Candle") ~= nil)
	local welded, loose, calm = 0, 0, true
	for _, d in (deco and deco:GetDescendants() or {}) do
		if d:IsA("BasePart") then
			if not d.Anchored and d:FindFirstChildOfClass("WeldConstraint") then welded += 1 else loose += 1 end
		end
		if d:IsA("ParticleEmitter") or d:IsA("Script") or d:IsA("LocalScript") then calm = false end
		if d:IsA("PointLight") and (d.Brightness > 1 or d.Range > 10) then calm = false end
	end
	check("every Halloween piece welded to the slab, not anchored", welded > 0 and loose == 0)
	check("Halloween stays calm (no particles, no scripts, soft lights)", calm)
	check("a faint web in the corner", back ~= nil and back:FindFirstChild("Web") ~= nil and back.Web.ImageTransparency >= 0.3)
end

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

-- the stands' knives (owner: "gamepasses shown with the character of the person playing, equipped with some exclusive
-- knifes"; Oct 18: each knife is its own Game Pass): only the knife the stand's pass gives
do
	local Env = require("../tools/preview/motion3d/env")
	local CoinShop = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/CoinShop.lua")
	local k1 = Stand.knife("HunterKnifePass", nil, CoinShop.Items, 1)
	eq("the Hunter Knife pass shows Crimson Requiem", k1, "CrimsonRequiem")
	eq("its only knife, whatever the turn", Stand.knife("HunterKnifePass", nil, CoinShop.Items, 3), "CrimsonRequiem")
	local typed = Stand.knife("FrostKnifePass", "frostbound oath", CoinShop.Items, 1)
	eq("a typed knife (any spelling) of that pass", typed, "FrostboundOath")
	local refused, why = Stand.knife("FrostKnifePass", "CelestialSeraph", CoinShop.Items, 1)
	check("a typed knife the pass doesn't give is refused (says why)", refused == "FrostboundOath" and why ~= nil)
	local coin, why2 = Stand.knife("HunterKnifePass", "AbyssEclipse", CoinShop.Items, 1)
	check("a coin knife never stands in for a pass's", coin ~= "AbyssEclipse" and why2 ~= nil)
	eq("no pass: no knife", (Stand.knife(nil, "CelestialSeraph", CoinShop.Items, 1)), nil)
	eq("VIP gives no knife now", (Stand.knife("VIP", nil, CoinShop.Items, 1)), nil)
	-- which pass each stand sells (Stand.assign): the five once each in his card order, then again
	local picks = Stand.assign({ { Pass = "VIP" }, { Pass = "VIP" }, { Pass = "VIP" }, { Pass = "DancePack" }, { Pass = "DancePack" }, { Pass = "DancePack" } }, CoinShop.Items)
	local order = {}
	for i, p in picks do order[i] = p.Pass end
	eq("six stands: the five in card order, then Hunter again", table.concat(order, ","), "HunterKnifePass,MoonlitKnifePass,SunriseKnifePass,InfernoKnifePass,FrostKnifePass,HunterKnifePass")
	local allOwn = true
	for _, p in picks do if CoinShop.get(p.Knife).Pass ~= p.Pass then allOwn = false end end
	check("each stand holds its own pass's knife", allOwn)
	picks = Stand.assign({ { Pass = "FrostKnifePass" }, { Knife = "dragon's maw" }, {} }, CoinShop.Items)
	eq("a stand on a knife pass keeps it", picks[1].Pass, "FrostKnifePass")
	eq("a typed knife picks its pass", picks[2].Pass, "InfernoKnifePass")
	eq("the rest take a knife not shown yet", picks[3].Pass, "HunterKnifePass")
	local withKnife = Stand.resolve({ Pass = "HunterKnifePass" }, Products, CoinShop.get(k1))
	eq("the sign is the card's name", withKnife.Title, "HUNTER KNIFE")
	eq("the sign names the knife", withKnife.Subtitle, "EXCLUSIVE KNIFE: CRIMSON REQUIEM")
	eq("no price on it until he sets one (Price 0)", withKnife.Price, nil)
	eq("still SOON (no Game Pass ID yet)", withKnife.Status, "Soon")
	check("a knife on the sign never opens a purchase by itself", not Stand.canPrompt(withKnife, false))
end

-- his own place (synced by Rojo, nothing renamed): the stands must still be found (the old code only knew blocks
-- named "AvatarStand", which only our place build made, so his game had none). Since his new lobby (Oct 18) the
-- stands go on its round pads (tests/LobbyLayout.spec); this fallback for places without pads still finds his old
-- islands' grey blocks (Maps > Spawn).
if fs.isFile("places/HUSSANIME.rbxl") then
	local place = roblox.deserializePlace(fs.readFile("places/HUSSANIME.rbxl"))
	local ws = place:GetService("Workspace")
	local wheels, parts, named = {}, {}, 0
	for _, d in ws:GetDescendants() do
		local n = string.lower(d.Name)
		if string.sub(string.gsub(n, "[%s_%-]", ""), 1, 11) == "avatarstand" then named += 1 end
		if d:IsA("Model") and string.find(n, "spin") and string.find(n, "wheel") then
			local lo, hi, sum, count = math.huge, -math.huge, roblox.Vector3.new(0, 0, 0), 0
			for _, p in d:GetDescendants() do
				if p:IsA("BasePart") then
					local q = p.CFrame.Position
					lo, hi, sum, count = math.min(lo, q.Y), math.max(hi, q.Y), sum + q, count + 1
				end
			end
			if count > 0 and hi - lo > 5 then
				local c = sum / count
				table.insert(wheels, { X = c.X, Y = c.Y, Z = c.Z })
			end
		elseif d.ClassName == "Part" and d.Name == "Part" then
			local q, sz = d.CFrame.Position, d.Size
			table.insert(parts, { ref = d, Name = d.Name, Class = d.ClassName, X = q.X, Y = q.Y, Z = q.Z, SX = sz.X, SY = sz.Y, SZ = sz.Z })
		end
	end
	eq("his place has no block named AvatarStand (why the stands didn't show)", named, 0)
	local found = Stand.findBlocks(wheels, parts)
	eq("his six grey blocks are found beside the 3 big spin wheels", #found, 6)
	local vip, dance = 0, 0
	for _, b in found do
		if b.Pass == "VIP" then vip += 1 elseif b.Pass == "DancePack" then dance += 1 end
	end
	check("three VIP and three Dance Pack stands", vip == 3 and dance == 3)
end

print(string.format("Leaderboards spec: %d passed, %d failed", passed, failed))
if failed > 0 then error("Leaderboards spec failed") end
