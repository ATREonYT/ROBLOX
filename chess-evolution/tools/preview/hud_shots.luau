--!nonstrict
-- +1 Chess Evolution: offline pictures of the battle HUD and the badge preview.
--   cd chess-evolution && lune run tools/preview/hud_shots.luau [out dir]
--   SW=1280 SH=720 node ../hood/tools/preview/ui/shoot.js <out dir>/desktop
--   SW=1515 SH=700 NOTCH=84 node ../hood/tools/preview/ui/shoot.js <out dir>/phone   (an 844x390 phone at the HUD scale 0.557; shrink the PNGs to 844x390)
-- Builds the real ChessHUD (HudBuilder) and poses a fight with DuelHud.Pose, then dumps each
-- ScreenGui with hood's dump.luau for hood's HTML renderer. A layout sketch, not Roblox:
-- 3D views (piece icons) show as dashed boxes and the world behind is a flat stand-in.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")
local Instance = roblox.Instance

local out = process.args[1] or "tools/preview/out"
local modules = {}
local env
local function loadModule(path, name)
	if modules[name] then
		return modules[name]
	end
	local scriptStub = { Parent = { WaitForChild = function(_, child)
		return { __module = child }
	end } }
	local e = setmetatable({ script = scriptStub }, { __index = env })
	local result = luau.load(fs.readFile(path), { debugName = name, environment = e, injectGlobals = false })()
	modules[name] = result
	return result
end
env = setmetatable({
	Instance = Instance, Enum = roblox.Enum, Font = roblox.Font, Color3 = roblox.Color3, ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, NumberSequence = roblox.NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	NumberRange = roblox.NumberRange, UDim = roblox.UDim, UDim2 = roblox.UDim2, Vector2 = roblox.Vector2, Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Rect = roblox.Rect,
	require = function(stub)
		return loadModule(`src/Shared/{stub.__module}.luau`, stub.__module)
	end,
}, { __index = getfenv() })
local config = luau.load(fs.readFile("src/Config/ChessConfig.luau"), { debugName = "ChessConfig", environment = env })()
local Hud = loadModule("src/Shared/HudBuilder.luau", "HudBuilder")
local DuelHud = loadModule("src/Shared/DuelHud.luau", "DuelHud")
local BadgeArt = loadModule("src/Shared/BadgeArt.luau", "BadgeArt")
local Preview = loadModule("src/Shared/BadgePreview.luau", "BadgePreview")

-- hood's dumper, without its packed-image loader
local dumpSrc = fs.readFile("../hood/tools/preview/ui/dump.luau")
dumpSrc = string.gsub(dumpSrc, "local PackedLoader = require%b()", "local PackedLoader = { showing = function() return false end, meta = function() return nil end }")
local denv = setmetatable({ __fs = fs, __serde = serde, game = {} }, { __index = env })
local uiDump = luau.load(dumpSrc .. "\nreturn __uiDump", { debugName = "dump", environment = denv, injectGlobals = false })()

local function hudFor(phone)
	local gui = Hud.Build(config)
	if phone then
		-- what ChessClient.layout() does on a touch phone of this size
		-- (shoot at 844x390 / scale, then shrink: the renderer ignores the ScreenGui's UIScale)
		local k = math.clamp(math.min(844 / 1250, 390 / 700), 0.5, 1)
		gui.MainButton.Size = roblox.UDim2.fromOffset(220, 120)
		gui.MainButton.Position = roblox.UDim2.new(1, -18, 1, -math.floor(150 / k))
		gui.KeyHint.Visible = false
		gui.Rail.Visible = false
	end
	gui.MainButton.Face.Label.Text = "CLICK TO WIN"
	gui.MainButton.Face.Label.TextSize = 36
	gui.MainButton.Face.Sub.Text = "Tap fast!"
	gui.MainButton.Face.BackgroundColor3 = Hud.Colors.red
	return gui
end
local function badge(gui, key)
	local b = gui.Bottom.Badge
	b.Visible = true
	BadgeArt.Paint(b.Disc, key, config.BadgeLook[key])
	b.Label.Text = config.BadgeLook[key].label
	b.Label.TextColor3 = config.BadgeLook[key].color:Lerp(roblox.Color3.new(1, 1, 1), 0.35)
end
local scenes = {
	{ "battle_winning", { meter = 74, combo = 24, youRate = 6, rivalRate = 1, timer = 9 }, "Best" },
	{ "battle_danger", { meter = 18, combo = 0, youRate = 2, rivalRate = 2, timer = 5 }, "Mistake" },
	{ "battle_comeback", { meter = 63, combo = 38, youRate = 6, rivalRate = 2, timer = 4 }, "Great" },
}
for _, kind in { "desktop", "phone" } do
	fs.writeDir(`{out}/{kind}`)
	for _, s in scenes do
		local gui = hudFor(kind == "phone")
		local pose = s[2]
		pose.playerName, pose.rivalName, pose.rivalTitle, pose.rivalColor = "atredev", "Pawn Pete", "Club rival", config.Stages.Stage1.color
		DuelHud.Pose(gui, pose)
		badge(gui, s[3])
		uiDump(gui, `{out}/{kind}/hud_{s[1]}.json`)
	end
	uiDump(Preview.Build(config), `{out}/{kind}/badges.json`)
end
print(`[shots] dumped to {out}/desktop and {out}/phone`)
