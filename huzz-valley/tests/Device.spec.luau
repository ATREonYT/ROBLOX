-- lune run tests/Device.spec.luau   (from huzz-valley/)
-- UI/Device (owner, Oct 21: "make the buttons make sense for these devices, make them not use pc terms"): each
-- control is named for what you play with: keys on a keyboard, a PlayStation's own buttons, an Xbox's, and on a
-- phone or iPad the on-screen button (never a key).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local ROOT = if fs.isDir("huzz-valley") then "huzz-valley/" else ""
local passed, failed = 0, 0
local function check(name, c) if c then passed += 1 else failed += 1; print("FAIL " .. name) end end

local function load(last, cross, touch, keys, pad)
	local uis = {
		GetLastInputType = function() return last end,
		GetStringForKeyCode = function() return if cross then "ButtonCross" else "ButtonA" end,
		TouchEnabled = touch, KeyboardEnabled = keys, GamepadEnabled = pad,
	}
	local Enum = { UserInputType = { Touch = { Name = "Touch" }, Keyboard = { Name = "Keyboard" } }, KeyCode = { ButtonA = {} } }
	return luau.load(fs.readFile(ROOT .. "src/StarterPlayer/StarterPlayerScripts/HuzzClient/UI/Device.lua"), {
		debugName = "Device", environment = { game = { GetService = function() return uis end }, Enum = Enum } })()
end

local phone = load({ Name = "Touch" }, false, true, false, false)
check("a phone is touch", phone.kind() == "touch")
for _, a in { "Stab", "Dash", "Abilities", "Dance" } do
	local w = phone.word(a) or ""
	check("no key on a phone: " .. a .. " = " .. w, not string.find(w, "Space") and not string.find(w, "Click") and w ~= "Q E" and w ~= "G")
end
local ps = load({ Name = "Gamepad1" }, true, false, false, true)
check("a PlayStation is a pad", ps.kind() == "pad" and ps.playStation())
check("PlayStation names", ps.word("Stab") == "R2" and ps.word("Dash") == "Cross" and ps.word("Ability1") == "L1")
local xbox = load({ Name = "Gamepad1" }, false, false, false, true)
check("Xbox names", xbox.word("Stab") == "RT" and xbox.word("Dash") == "A" and xbox.word("Ability2") == "RB")
local pc = load({ Name = "MouseButton1" }, false, false, true, false)
check("a PC says its keys", pc.kind() == "keys" and pc.word("Stab") == "Click" and pc.word("Dash") == "Space")
local console = load(nil, true, false, false, true)
check("a console before any press is a pad", console.kind() == "pad")
local ipad = load(nil, false, true, false, false)
check("an iPad before any touch is touch", ipad.kind() == "touch")

print(string.format("Device: %d passed, %d failed", passed, failed))
if failed > 0 then error("Device spec failed") end
