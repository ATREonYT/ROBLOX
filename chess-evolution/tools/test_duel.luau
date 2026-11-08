--!nonstrict
-- +1 Chess Evolution: offline checks for the duel layer and the badge art (no Studio needed).
--   cd chess-evolution && lune run tools/build_place.luau && lune run tools/test_duel.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local modules = {}
local env
local function loadModule(path, name)
	if modules[name] then
		return modules[name]
	end
	local stub = { Parent = { WaitForChild = function(_, child)
		return { __module = child }
	end } }
	local e = setmetatable({ script = stub }, { __index = env })
	modules[name] = luau.load(fs.readFile(path), { debugName = name, environment = e, injectGlobals = false })()
	return modules[name]
end
env = setmetatable({
	Instance = roblox.Instance, Enum = roblox.Enum, Font = roblox.Font, Color3 = roblox.Color3, ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, NumberSequence = roblox.NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	UDim = roblox.UDim, UDim2 = roblox.UDim2, Vector2 = roblox.Vector2, Vector3 = roblox.Vector3, CFrame = roblox.CFrame,
	require = function(s)
		return loadModule(`src/Shared/{s.__module}.luau`, s.__module)
	end,
}, { __index = getfenv() })
local Config = luau.load(fs.readFile("src/Config/ChessConfig.luau"), { environment = env })()
local BadgeArt = loadModule("src/Shared/BadgeArt.luau", "BadgeArt")
local DuelHud = loadModule("src/Shared/DuelHud.luau", "DuelHud")
local Preview = loadModule("src/Shared/BadgePreview.luau", "BadgePreview")
local Battle = loadModule("src/Shared/Battle.luau", "Battle")
local Badges = loadModule("src/Shared/Badges.luau", "Badges")

local passed, failed = 0, 0
local function check(name, cond, detail)
	if cond then
		passed += 1
	else
		failed += 1
		print(`FAIL {name}{if detail ~= nil then ": " .. tostring(detail) else ""}`)
	end
end

-- 1. The saved HUD (StarterGui) carries the duel parts, so the owner sees them in Studio.
local hud = roblox.deserializeModel(fs.readFile("src/StarterGui/ChessHUD.rbxm"))[1]
local bottom = hud:FindFirstChild("Bottom")
for _, path in { { "Duel", "YouCard" }, { "Duel", "RivalCard" }, { "Duel", "Vs", "Tag" }, { "Combo" }, { "Meter", "Bar", "Sparks" } } do
	local node = bottom
	for _, n in path do
		node = node and node:FindFirstChild(n)
	end
	check(`saved HUD has Bottom.{table.concat(path, ".")}`, node ~= nil)
end
check("saved HUD has DangerEdges", hud:FindFirstChild("DangerEdges") ~= nil)
check("duel parts start hidden", not bottom.Duel.Visible and not bottom.Combo.Visible and not hud.DangerEdges.Visible)
check("badge slot is drawn art", bottom.Badge.Disc:FindFirstChild("Art") ~= nil)

-- 2. Every badge has a look and paints (shape or glyph), and the preview lists them all.
local count = 0
for key, look in Config.BadgeLook do
	count += 1
	local disc = roblox.Instance.new("Frame")
	disc.Size = roblox.UDim2.fromOffset(66, 66)
	local ok, err = pcall(BadgeArt.Paint, disc, key, look)
	check(`{key} paints`, ok, err)
	local art = disc:FindFirstChild("Art")
	check(`{key} has a symbol`, art and #art:GetChildren() >= 3)
	check(`{key} is in the preview order`, table.find(BadgeArt.Order, key) ~= nil)
end
check("11 badges", count == 11 and #BadgeArt.Order == 11, count)
check("Forced is preview-only (no live encounter yet)", BadgeArt.Live.Forced == nil)

-- 3. The preview's five fights: the no-input loss shows ?! then ? then ?? before defeat.
local lines = Preview.Scenarios(Config, Battle, Badges)
check("five scenario lines", #lines == 5, #lines)
local idle = lines[2]
local a, b, c = string.find(idle, "Inaccuracy"), string.find(idle, "Mistake"), string.find(idle, "Blunder")
check("no-input loss: ?! then ? then ??", a and b and c and a < b and b < c, idle)
check("deep comeback: Brilliant", string.find(lines[4], "Brilliant") ~= nil, lines[4])
check("failed recovery: Miss", string.find(lines[5], "Miss") ~= nil, lines[5])
for _, l in lines do
	if process.args[1] == "-v" then
		print(l)
	end
end

-- 4. Kid-safe motion: the danger edges breathe slower than one flash per second.
check("danger edges: under one flash per second", DuelHud.Tuning.edgeBreath >= 1, DuelHud.Tuning.edgeBreath)
check("danger edges match the Mistake line", DuelHud.Tuning.dangerAt == Config.Badges.danger[2].enter)

-- 5. Vault feel pieces (FeelKit): saved in the HUD, levels sized like note 13 §2B.
local FeelKit = loadModule("src/Shared/FeelKit.luau", "FeelKit")
check("saved HUD has the Level chip", bottom.Progress:FindFirstChild("Level") ~= nil and bottom.Progress:FindFirstChild("LevelUp") ~= nil)
check("saved HUD has Moment and Confetti layers", hud:FindFirstChild("Moment") ~= nil and hud:FindFirstChild("Confetti") ~= nil)
check("Moment starts hidden", not hud.Moment.Visible)
check("level 1 at 0 Power", (FeelKit.Level(0)) == 1)
check("level 2 at 10 Power", (FeelKit.Level(10)) == 2)
check("level 4 at 30 Power (10, 10, 10)", (FeelKit.Level(30)) == 4)
check("level 5 at 42 Power (then 12)", (FeelKit.Level(42)) == 5)
check("levels cap at 20", (FeelKit.Level(1e9)) == 20)
local lv, pr = FeelKit.Level(15)
check("half way through level 2", lv == 2 and math.abs(pr - 0.5) < 1e-9, `{lv} {pr}`)
-- a level up every second or so: at the Pawn Mill's capped 6 taps/s, the first 9 levels take under 2.5 s each
local base, ok = 0, true
for i = 1, 9 do
	local need = FeelKit.LevelSizes[i]
	if need / 6 > 4 then
		ok = false
	end
	base += need
end
check("early levels arrive within a few seconds of training", ok)

print(`[test_duel] {passed} passed, {failed} failed`)
if failed > 0 then
	process.exit(1)
end
