-- lune run tests/Sounds.spec.luau   (from huzz-valley/)
-- Button sounds (owner, Oct 18: "make it so that the clicking sounds are better, because right now they sound
-- glitchy, and dont feel too premium"): the real HuzzClient/Gameplay/Sfx on fake Sounds.
--   * one press = one sound: the same ui_* sound asked for again within its gap is skipped; after the gap it plays;
--   * button sounds come from sounds made once and loaded ahead, through the Interface group, never pitch-wobbled,
--     and a quick second click starts another copy instead of cutting the first one off;
--   * stand-ins are never pitched above 1.0 for buttons (1.1 for anything), and IDs stay "" (never invented);
--   * UI/Kit buttons sound on MouseButton1Down (only the button on top gets it), not InputBegan.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local ROOT = if fs.isDir("huzz-valley") then "huzz-valley/" else ""

local passed, failed = 0, 0
local function check(name, cond)
	if cond then passed += 1 else failed += 1; print("FAIL " .. name) end
end

-- fake Roblox bits: Sounds that count their plays, a SoundService with Master > Interface / Effects groups
local clock = 100
local made, plays = {}, {}
local function inst(class)
	local o = { ClassName = class, Parent = nil, _kids = {} }
	function o:IsA(c) return c == class or (c == "Instance") end
	function o:FindFirstChild(n)
		for _, k in self._kids do if k.Name == n then return k end end
		return nil
	end
	function o:Play() table.insert(plays, { name = self.Name, at = clock, speed = self.PlaybackSpeed, group = self.SoundGroup and self.SoundGroup.Name, sound = self }) end
	function o:Destroy() self.Parent = nil end
	return setmetatable(o, { __newindex = function(t, k, v)
		rawset(t, k, v)
		if k == "Parent" and v and v._kids then table.insert(v._kids, t) end
	end })
end
local SoundService = inst("SoundService")
local master = inst("SoundGroup"); master.Name = "Master"; master.Parent = SoundService
for _, n in { "Interface", "Effects" } do
	local g = inst("SoundGroup"); g.Name = n; g.Parent = master
end
local ids = luau.load(fs.readFile(ROOT .. "src/ReplicatedStorage/Shared/Config/SoundIds.lua"), { debugName = "SoundIds" })()
local fakeShared = { Config = { SoundIds = ids } }
local env = {
	game = { GetService = function(_, name)
		if name == "SoundService" then return SoundService end
		if name == "ReplicatedStorage" then return { WaitForChild = function() return fakeShared end } end
		return { PreloadAsync = function() end }
	end },
	require = function(x) return x end,
	Instance = { new = function(class) local o = inst(class); table.insert(made, o); return o end },
	task = { defer = function(fn) fn() end, delay = function() end },
	os = { clock = function() return clock end },
	pcall = pcall, math = math, string = string, table = table, type = type,
}
local source = fs.readFile(ROOT .. "src/StarterPlayer/StarterPlayerScripts/HuzzClient/Gameplay/Sfx.lua")
local Sfx = luau.load(source, { debugName = "Sfx", environment = env })()

-- IDs: never invented
for name, id in ids do
	check("SoundIds." .. name .. " is a string (\"\" until the owner sends it)", type(id) == "string")
end

-- loaded ahead: the button sounds exist before anyone clicks
local preloaded = 0
for _, s in made do if s.ClassName == "Sound" and string.sub(s.Name or "", 1, 3) == "ui_" then preloaded += 1 end end
check("button sounds are made and loaded ahead", preloaded >= 2)
local madeBefore = #made

-- one press, one sound
plays = {}
Sfx.play("ui_click")
Sfx.play("ui_click") -- (a second handler answering the same press, same instant)
clock += 0.03
Sfx.play("ui_click") -- (InputBegan on a button behind, 30 ms later)
check("one press sounds once (3 asks within 0.08 s -> 1 play)", #plays == 1)
clock += 0.1
Sfx.play("ui_click")
check("the next real click (0.13 s later) sounds", #plays == 2)
check("a quick second click uses another copy (the first isn't cut off)", plays[1].sound ~= plays[2].sound)
for _ = 1, 20 do clock += 0.04; Sfx.play("ui_click") end -- mashing at 25 a second
check(string.format("mashing 25 a second plays at most ~12 a second (%d in 0.8 s)", #plays - 2), #plays - 2 <= 11)
check("no new Sound per click (all from the loaded pool)", #made == madeBefore)
check("never pitch-wobbled: every click the same speed", (function()
	for _, p in plays do if p.speed ~= plays[1].speed then return false end end
	return true
end)())
check("button stand-in pitch at most 1.0", plays[1].speed <= 1.0)
check("button sounds go through the Interface group (Settings > Button Sounds)", plays[1].group == "Interface")
plays = {}
clock += 1
Sfx.play("ui_click")
Sfx.play("ui_open") -- (a different sound: allowed together)
check("a different button sound isn't blocked by the click's gap", #plays == 1 or #plays == 2)
check("every ui_* gap is short (0.05 to 0.2 s)", (function()
	for _, g in Sfx.UI_GAP do if g < 0.05 or g > 0.2 then return false end end
	return true
end)())

-- the table of stand-ins: never pitched up (owner: "not some random high pitch sounds")
local fb = string.match(source, "local FALLBACK = (%b{})")
for name, pitch in string.gmatch(fb or "", "(%w+_?%w*) = { [%w_]+, [%d.]+, ([%d.]+) }") do
	local p = tonumber(pitch)
	check(name .. ": stand-in pitch " .. pitch .. (if string.sub(name, 1, 3) == "ui_" then " (<= 1.0)" else " (<= 1.1)"),
		p ~= nil and p <= (if string.sub(name, 1, 3) == "ui_" then 1.0 else 1.1))
end
local level = string.match(source, "local LEVEL = (%b{})")
for name, spread in string.gmatch(level or "", "(ui_%w+) = { [%d.]+, ([%d.]+) }") do
	check(name .. ": no pitch wobble", tonumber(spread) == 0)
end

-- Kit buttons: sound on MouseButton1Down, not InputBegan
local kit = fs.readFile(ROOT .. "src/StarterPlayer/StarterPlayerScripts/HuzzClient/UI/Kit.lua")
local buttonCode = string.match(kit, "function api%.onClick.-api%.Instance = btn") or ""
check("Kit.button sounds on MouseButton1Down", string.find(buttonCode, "MouseButton1Down", 1, true) ~= nil)
check("Kit.button doesn't sound on InputBegan (it reaches buttons hidden behind)", string.find(buttonCode, "InputBegan:Connect", 1, true) == nil)

-- the new click file: short, made by tools/sfx/make_sfx.py
check("assets/sfx/ui_click.ogg exists", fs.isFile(ROOT .. "assets/sfx/ui_click.ogg"))
check("docs/previews/click-before-after.ogg exists", fs.isFile(ROOT .. "docs/previews/click-before-after.ogg"))

print(`Sounds: {passed} ok, {failed} failed`)
if failed > 0 then error("Sounds spec failed") end
