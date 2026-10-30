-- What this player plays with, and what to call each control on it (owner, Oct 21: "make the game well made for the
-- iPad, phone, and PlayStation ... make the buttons make sense for these devices, make them not use pc terms like
-- keyboard buttons"). Device.kind() is "touch" (phone, iPad), "pad" (PlayStation, Xbox, a controller on a PC) or
-- "keys" (keyboard and mouse), from the last thing they pressed (it changes the moment they switch). Device.word(action)
-- is that control's name on it: on a PlayStation its own buttons (Cross, R2, L1: words, as Roblox's fonts may not draw the symbols), on an Xbox its own (A, RT, LB), on a
-- touch screen the on-screen button's name (never a key). Device.changed(fn) calls fn whenever the kind changes.
local UserInputService = game:GetService("UserInputService")

local Device = {}

-- Each action: keyboard, PlayStation, Xbox, touch.
local WORDS = {
	Stab = { "Click", "R2", "RT", "STAB" },
	Dash = { "Space", "Cross", "A", "the dash bar" },
	Ability1 = { "Q", "L1", "LB", "the ability buttons" },
	Ability2 = { "E", "R1", "RB", "the ability buttons" },
	Abilities = { "Q E", "L1 R1", "LB RB", "the ability buttons" },
	Dance = { "G", "Triangle", "Y", "DANCE" },
	Back = { "Esc", "Circle", "B", "X" },
	Pick = { "1 2", "L1 R1", "LB RB", "tap one" },
	FreeMouse = { "Alt", nil, nil, nil }, -- (only a mouse has a cursor to free)
}

local function lastKind(): string?
	local ok, t = pcall(function() return UserInputService:GetLastInputType() end)
	if not ok or not t then return nil end
	if t == Enum.UserInputType.Touch then return "touch" end
	if string.sub(t.Name, 1, 7) == "Gamepad" then return "pad" end
	if t == Enum.UserInputType.Keyboard or string.sub(t.Name, 1, 5) == "Mouse" then return "keys" end
	return nil
end

function Device.kind(): string
	local k = lastKind()
	if k then return k end
	local okT, touch = pcall(function() return UserInputService.TouchEnabled end)
	local okK, keys = pcall(function() return UserInputService.KeyboardEnabled end)
	local okP, pad = pcall(function() return UserInputService.GamepadEnabled end)
	if okT and touch and not (okK and keys) then return "touch" end
	if okP and pad and not (okK and keys) then return "pad" end
	return "keys"
end

-- A PlayStation controller (Roblox names its bottom button "ButtonCross" there).
function Device.playStation(): boolean
	local ok, s = pcall(function() return UserInputService:GetStringForKeyCode(Enum.KeyCode.ButtonA) end)
	return ok and type(s) == "string" and string.find(s, "Cross", 1, true) ~= nil
end

function Device.word(action: string, kind: string?): string?
	local w = WORDS[action]
	if not w then return nil end
	local k = kind or Device.kind()
	if k == "touch" then return w[4] end
	if k == "pad" then return if Device.playStation() then w[2] else w[3] end
	return w[1]
end

function Device.changed(fn: (string) -> ())
	local was = Device.kind()
	pcall(function()
		UserInputService.LastInputTypeChanged:Connect(function()
			local now = Device.kind()
			if now ~= was then
				was = now
				fn(now)
			end
		end)
	end)
end

return Device
