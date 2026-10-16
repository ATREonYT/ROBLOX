--!strict
-- Every player setting: its default and the values it may take. The server rejects anything else.
-- Social choices are enforced by SettingsService.allows(); features that show inventories or send invites must call it.
local Settings = {}

Settings.Choices = { "Everyone", "Friends", "Nobody" }

Settings.Defaults = {
	-- Audio (0-100)
	MasterVolume = 80,
	MusicVolume = 60,
	EffectsVolume = 80,
	MuteUnfocused = true,
	-- Controls (KeyCode names)
	MenuKey = "M",
	ShowKeyHints = false, -- off by default: the lobby reference shows no key badges
	-- Social
	InventoryVisibility = "Friends",
	InviteRequests = "Friends",
	CompanionEffects = true,
	ReducedMotion = false,
}

-- Keys the game or Roblox already uses, so a binding can't take them.
Settings.ReservedKeys = {
	W = true, A = true, S = true, D = true, Space = true, Escape = true, Tab = true, Slash = true, Backquote = true,
	Up = true, Down = true, Left = true, Right = true, I = true, O = true, LeftShift = true, RightShift = true,
	Return = true, Backspace = true, F9 = true, F10 = true, F11 = true, F12 = true,
	Q = true, E = true, H = true, -- the powers and the huss
}
Settings.KeyFields = { "MenuKey" }

local function isVolume(v) return type(v) == "number" and v == v and v >= 0 and v <= 100 end
local function isBool(v) return type(v) == "boolean" end
local function isChoice(v) return type(v) == "string" and table.find(Settings.Choices, v) ~= nil end

local VALID: { [string]: (any) -> boolean } = {
	MasterVolume = isVolume, MusicVolume = isVolume, EffectsVolume = isVolume, MuteUnfocused = isBool,
	ShowKeyHints = isBool, InventoryVisibility = isChoice, InviteRequests = isChoice, CompanionEffects = isBool,
	ReducedMotion = isBool,
	MenuKey = function(v)
		if type(v) ~= "string" or Settings.ReservedKeys[v] then return false end
		return (pcall(function() return (Enum.KeyCode :: any)[v] end))
	end,
}

-- Returns the cleaned value, or nil and a reason.
function Settings.validate(key: string, value: any, current: { [string]: any }?): (any, string?)
	local check = VALID[key]
	if not check then return nil, "Unknown setting." end
	if type(value) == "number" then value = math.floor(value + 0.5) end
	if not check(value) then return nil, "That value isn't allowed." end
	if current and table.find(Settings.KeyFields, key) then
		for _, other in Settings.KeyFields do
			if other ~= key and current[other] == value then return nil, "That key is already used." end
		end
	end
	return value
end

return Settings
